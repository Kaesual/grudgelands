"""Decode real mapblocks from grwasd/map.sqlite (SELECT only) and compare the
surface node_top against the model's prediction."""
import sys, sqlite3, io, struct, random
import numpy as np
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model
from model import (load_biomes, terrain_height, column_cap, calc_biome, SEED,
                   np_heat, np_humidity, np_heat_bl, np_hum_bl, WATER_LEVEL,
                   X_HALF, Z_MIN, Z_MAX)
from noiselib import fractal2d

try:
    import zstandard as zstd
    def dec(b): return zstd.ZstdDecompressor().decompressobj().decompress(b)
except ImportError:
    zstd = None

DB = "/home/jan/.var/app/org.luanti.luanti/.minetest/worlds/grwasd/map.sqlite"


def decode_block(blob):
    """Return (param0 array shape (4096,), id->name dict) or None."""
    ver = blob[0]
    if ver < 29:
        return None
    import zstandard
    d = zstandard.ZstdDecompressor().stream_reader(io.BytesIO(blob[1:]))
    raw = d.read(1 << 22)
    f = io.BytesIO(raw)
    flags = f.read(1)[0]
    lighting = struct.unpack(">H", f.read(2))[0]
    timestamp = struct.unpack(">I", f.read(4))[0]
    nimv = f.read(1)[0]
    n = struct.unpack(">H", f.read(2))[0]
    names = {}
    for _ in range(n):
        i = struct.unpack(">H", f.read(2))[0]
        ln = struct.unpack(">H", f.read(2))[0]
        names[i] = f.read(ln).decode()
    cw = f.read(1)[0]
    pw = f.read(1)[0]
    assert cw == 2 and pw == 2, (cw, pw)
    p0 = np.frombuffer(f.read(8192), dtype=">u2").astype(np.int32)
    return p0, names, bool(flags & 0x08)


def main():
    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
    # Column stacks: pick block columns (x,z) that lie on the continents and
    # whose whole y-range is present, so the surface is inside what we read.
    rows = con.execute("SELECT x, y, z FROM blocks").fetchall()
    bycol = {}
    for x, y, z in rows:
        bycol.setdefault((x, z), []).append(y)
    cols = [(k, sorted(v)) for k, v in bycol.items()
            if abs(k[0] * 16) <= X_HALF and Z_MIN <= abs(k[1] * 16) <= Z_MAX - 16]
    rng = random.Random(7)
    rng.shuffle(cols)
    print("block columns on the continents: %d" % len(cols))

    B = load_biomes("/tmp/claude-1000/-home-jan-projects-grudgelands/"
                    "91ecbd76-d170-44c2-bdbc-709677e54187/scratchpad/biomes.csv")
    NAMES = [b["name"] for b in B]
    TOPS = [b["node_top"] for b in B]

    samples = []          # (x, z, real_top_name, real_top_y)
    LIQ = {"default:water_source", "default:water_flowing",
           "default:river_water_source", "default:river_water_flowing"}
    AIRY = {"air", "ignore"} | LIQ

    ncol = 0
    for (bx, bz), ys in cols:
        if ncol >= 220:
            break
        ys = sorted(ys, reverse=True)
        if not ys or ys[0] < 2:
            continue
        ncol += 1
        cache = {}
        def blk(y):
            if y not in cache:
                r = con.execute("SELECT data FROM blocks WHERE x=? AND y=? AND z=?",
                                (bx, y, bz)).fetchone()
                cache[y] = decode_block(r[0]) if r else None
            return cache[y]
        for lx in range(0, 16, 4):
            for lz in range(0, 16, 4):
                gx = bx * 16 + lx
                gz = bz * 16 + lz
                found = None
                for y in ys:
                    r = blk(y)
                    if r is None:
                        continue
                    p0, names, gen = r
                    for ly in range(15, -1, -1):
                        nm = names.get(int(p0[lz * 256 + ly * 16 + lx]), "?")
                        if nm not in AIRY:
                            found = (nm, y * 16 + ly)
                            break
                    if found:
                        break
                if found:
                    samples.append((gx, gz, found[0], found[1]))
    print("surface samples: %d from %d block columns" % (len(samples), ncol))

    X = np.array([s[0] for s in samples], dtype=np.int32)
    Z = np.array([s[1] for s in samples], dtype=np.int32)
    RY = np.array([s[3] for s in samples], dtype=np.int32)
    RN = [s[2] for s in samples]

    Xf, Zf = X.astype(np.float32), Z.astype(np.float32)
    heat = fractal2d(np_heat, Xf, Zf, SEED) + fractal2d(np_heat_bl, Xf, Zf, SEED)
    hum = fractal2d(np_humidity, Xf, Zf, SEED) + fractal2d(np_hum_bl, Xf, Zf, SEED)
    h = terrain_height(Xf, Zf)
    cap, has = column_cap(X, Z)
    eff = np.where(has, np.minimum(h, cap), h)
    bid = calc_biome(B, heat, hum, X, Z, h)

    # predicted visible top: sand where the mask cut at/below beach level,
    # else the biome's node_top (geometry.lua column_cap + the sand re-dress
    # in ocean_mask_mapgen.lua; both were structures.lua before WP36).
    carved = has & (h > cap)
    pred = []
    for i in range(len(X)):
        if carved[i] and cap[i] <= WATER_LEVEL + 3:
            pred.append("default:sand")
        else:
            pred.append(TOPS[bid[i]] if bid[i] >= 0 else "?")

    # ---- agreement ----
    dy = RY - eff
    print("\nHEIGHT: predicted eff. surface vs real top-solid y")
    print("  exact %.1f%%   |dy|<=1 %.1f%%   |dy|<=2 %.1f%%   |dy|<=4 %.1f%%   mean dy %+.2f  sd %.2f"
          % (100 * (dy == 0).mean(), 100 * (np.abs(dy) <= 1).mean(),
             100 * (np.abs(dy) <= 2).mean(), 100 * (np.abs(dy) <= 4).mean(),
             dy.mean(), dy.std()))

    ok = np.array([pred[i] == RN[i] for i in range(len(X))])
    print("\nNODE_TOP: predicted vs real, all %d samples: %.1f%% agree" % (len(X), 100 * ok.mean()))
    # restrict to columns where the height model is right (a wrong y can flip
    # beach/swamp/land eligibility, which is a height error not a biome error)
    m = np.abs(dy) <= 1
    print("  on the %d samples with |dy|<=1: %.1f%% agree" % (m.sum(), 100 * ok[m].mean()))
    # decoration nodes (leaves/tree/snow/etc) are not node_top at all
    from collections import Counter
    bad = Counter()
    for i in range(len(X)):
        if not ok[i]:
            bad[(pred[i], RN[i])] += 1
    print("\n  top mismatches (predicted -> real):")
    for (p, r), c in bad.most_common(15):
        print("    %-42s -> %-42s %4d" % (p, r, c))

    # ignore samples whose real top is a decoration/plant/structure node
    DECO = lambda n: any(k in n for k in ("leaves", "tree", "grass", "shrub",
                                          "flower", "plant", "papyrus", "cactus",
                                          "cobble", "stair", "wood", "torch",
                                          "banner", "chest", "fence", "sapling",
                                          "vine", "bush", "moss", "snow", "ice",
                                          "log", "mushroom", "fungus"))
    keep = np.array([not DECO(RN[i]) for i in range(len(X))]) & m
    print("\n  excluding deco/structure tops: %d samples, %.1f%% agree"
          % (keep.sum(), 100 * ok[keep].mean()))
    bad2 = Counter()
    for i in range(len(X)):
        if keep[i] and not ok[i]:
            bad2[(pred[i], RN[i])] += 1
    for (p, r), c in bad2.most_common(10):
        print("    %-42s -> %-42s %4d" % (p, r, c))

    # rainforest-litter check specifically
    real_rain = np.array([RN[i] == "default:dirt_with_rainforest_litter" for i in range(len(X))])
    pred_rain = np.array([pred[i] == "default:dirt_with_rainforest_litter" for i in range(len(X))])
    thr = Z > 0
    print("\n  rainforest litter on Throng samples: real %.1f%% / predicted %.1f%% (n=%d)"
          % (100 * real_rain[thr & keep].mean(), 100 * pred_rain[thr & keep].mean(),
             (thr & keep).sum()))


main()
