#!/usr/bin/env python3
"""Round 24 Lane C art: tier rocks, decorative rocks, ore and gem overlays.

Rulings 16-17 and the decorative rocks of ruling 8
(`docs/planning/round24-mining-underground-mobs-plan.md`).

* Tier rocks T2..T6 (`grug_materials_t<N>_stone.png`) are `default_stone.png`
  "compressed by depth": darker per tier, a slight cool tint, a slightly
  stronger pixel contrast so the pattern survives the darkening, and a
  hairline-crack overlay that gets denser with depth (every tier keeps the
  cracks of the tier above and adds new ones). Derivatives of minetest_game's
  CC BY-SA 3.0 stone.
* Decorative rocks (`grug_materials_slate/basalt/granite.png`) are colour
  graded copies of three VoxeLibre rock textures (deepslate, basalt side,
  granite), pulled toward our palette so they sit next to `default_stone`.
* Ore/gem overlays (`grug_materials_mineral_<key>.png`) are transparent 16x16
  overlays drawn over `default_stone.png` at runtime, exactly like the
  vendored `default_mineral_*.png`. Gems (and the crystal resources) use the
  mineral motif of a VoxeLibre gem ore, cut out of its own stone background
  and re-coloured through a per-gem ramp; the rim pixels VoxeLibre draws
  around the gem are re-mapped onto `default_stone`'s own grey palette.
  Silver stays in the minetest_game streak language of the other metal ores
  (a re-arranged, relief-shaded streak mask), so metal ores and gems read as
  two families and silver cannot be mistaken for quartz, which takes the
  VoxeLibre quartz-fleck motif.

Run from anywhere (paths resolve from this file):

    python3 tools/r24_art/build_rock_ore_textures.py [--voxelibre DIR]
    python3 tools/r24_art/build_rock_ore_textures.py --check
    python3 tools/r24_art/build_rock_ore_textures.py --renders

`--voxelibre` defaults to `reference_projects/VoxeLibre` of this checkout
(a git worktree may have that directory empty: pass the main checkout's).
Every VoxeLibre and minetest_game input is pinned by SHA-256; a mismatch
aborts. `--check` regenerates in memory and fails if a stored texture's
pixels would change. `--renders` also writes the comparison sheets to
`docs/research/round24-art/`.
"""

import argparse
import colorsys
import hashlib
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MTG = ROOT / "mods/BASE/default/textures"
OUT = ROOT / "mods/ITEMS/grug_materials/textures"
RENDERS = ROOT / "docs/research/round24-art"

# Inputs, pinned by SHA-256. VoxeLibre files live in its top-level
# `textures/` (checkout = submodule pin 2373982f19f9b5d89cd2e3146ad7749876319e15);
# minetest_game files are the vendored `mods/BASE/default/textures` (b5243f3).
VL_SOURCES = {
    # VoxeLibre's stone: only used to cut the gem motifs out of it
    "default_stone.png":
        "f741bae514fa506fed3daf9977e629509c730431afe06d9d144c027cc8c17352",
    "mcl_core_diamond_ore.png":
        "5d37d2e90dad49c0287fe100a61eeeb25fab6ba2739cc59f49e82b81aa014ae3",
    "mcl_core_emerald_ore.png":
        "b5a1e8c173611ee121802706fca49c59e6f17bd48d87ca6da785da97c52e3da6",
    "mcl_core_lapis_ore.png":
        "38f6dc82f086f976327adb7e245568312f50de4050ae5feb23f3e3ba7e87c9ef",
    "mcl_core_redstone_ore.png":
        "fa25b6a4dc97772e1ddc7ea626109c2687e19ad68cfc48778dbf068ef6b6bf16",
    "mcl_nether_quartz_ore.png":
        "0ef26d623b10f3a49eceb9006a7c8a9e7f7fdda22d5afd95b763b2188def541f",
    "mcl_deepslate.png":
        "e08d318e0b40fbfe8d2fc87b15e947c8c41bc9e0531e179242309dfac32085f3",
    "mcl_blackstone_basalt_side.png":
        "4773e854c52a2bcfdd52dceff0f1944dfcc2a614a19ba505c76cccd19f4bf1a0",
    "mcl_core_granite.png":
        "f235447993f09c26bb1a285ed643df185157d504ea0b53ea7b813a928df0888f",
}
MTG_SOURCES = {
    "default_stone.png":
        "0803a6cd3e8a07ec5d7885735800ee9578a3fa9019d4deb8838290a744e2318a",
    "default_mineral_iron.png":
        "ebfc0d78f5a7c71bc74787b5a6bce043ccbee0fe80c67c212c5b9c03bee8e523",
}


# --------------------------------------------------------------------------
# helpers

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path, want, mismatches):
    got = sha256(path)
    if got != want:
        mismatches.append("%s: sha256 %s, pinned %s" % (path, got, want))
    return Image.open(path).convert("RGBA")


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def clamp(v):
    return max(0, min(255, int(round(v))))


def nearest(palette, target_l):
    return min(palette, key=lambda c: abs(lum(c) - target_l))


# --------------------------------------------------------------------------
# tier rocks (ruling 16)

# tier -> (brightness factor, tint strength 0..1, crack count)
TIERS = {
    2: (0.935, 0.2, 2),
    3: (0.86, 0.4, 4),
    4: (0.785, 0.6, 6),
    5: (0.71, 0.8, 8),
    6: (0.635, 1.0, 10),
}
# full-strength cool tint as per-channel multipliers
COOL = (0.93, 0.98, 1.06)
CONTRAST = 0.35   # extra contrast at T6, scaled with tint strength
CRACK_DARK = 0.68  # crack pixel = shaded pixel * this
CRACK_LIGHT = 1.10  # lit lip one pixel above a crack (T4 and deeper)


def crack_paths(count, seed=2424):
    """Deterministic hairline cracks, mostly horizontal (pressure layering).

    Tile-seamless: coordinates wrap. Crack i is identical in every tier that
    has at least i+1 cracks, so deeper tiers add cracks to the shallower ones.
    """
    rng = random.Random(seed)
    paths = []
    for _ in range(count):
        x, y = rng.randrange(16), rng.randrange(16)
        dx = rng.choice((-1, 1))
        length = rng.randint(3, 6)
        pts = [(x, y)]
        for _ in range(length - 1):
            x = (x + dx) % 16
            if rng.random() < 0.35:
                y = (y + rng.choice((-1, 1))) % 16
            pts.append((x, y))
        paths.append(pts)
    return paths


def tier_rock(stone, tier):
    bright, tint, cracks = TIERS[tier]
    src = stone.load()
    mean = sum(lum(src[x, y]) for x in range(16) for y in range(16)) / 256
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    k = 1 + CONTRAST * tint
    mult = tuple(1 + (m - 1) * tint for m in COOL)
    for y in range(16):
        for x in range(16):
            r, g, b, _ = src[x, y]
            out = []
            for c, m in zip((r, g, b), mult):
                c = mean + (c - mean) * k  # contrast around the mean
                out.append(c * bright * m)
            px[x, y] = tuple(clamp(c) for c in out) + (255,)
    base = im.copy().load()
    crack_set = set()
    for path in crack_paths(10)[:cracks]:
        crack_set.update(path)
    for (x, y) in crack_set:
        px[x, y] = tuple(clamp(c * CRACK_DARK) for c in base[x, y][:3]) + (255,)
    if tier >= 4:
        for (x, y) in crack_set:
            above = (x, (y - 1) % 16)
            if above not in crack_set:
                px[above] = tuple(clamp(c * CRACK_LIGHT)
                                  for c in base[above][:3]) + (255,)
    return im


# --------------------------------------------------------------------------
# decorative rocks (ruling 8)

# name -> (VoxeLibre source, target mean colour, contrast factor)
DECOR = {
    "slate": ("mcl_deepslate.png", "#56606b", 1.1),
    "basalt": ("mcl_blackstone_basalt_side.png", "#3b3a3d", 1.0),
    "granite": ("mcl_core_granite.png", "#94705f", 1.0),
}


def grade(src, target, contrast):
    """Move `src`'s mean colour to `target`, keeping its luminance pattern."""
    target = hexrgb(target)
    s = src.load()
    pix = [s[x, y] for y in range(16) for x in range(16)]
    mean = [sum(p[i] for p in pix) / 256 for i in range(3)]
    mean_l = lum(mean)
    tgt_l = lum(target)
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    for y in range(16):
        for x in range(16):
            p = s[x, y]
            # relative luminance deviation of this pixel, applied to target
            dl = (lum(p) - mean_l) * contrast * (tgt_l / mean_l)
            # keep a little of the source's own hue variation
            chroma = [(p[i] - mean[i]) - (lum(p) - mean_l) for i in range(3)]
            px[x, y] = tuple(clamp(target[i] + dl + 0.5 * chroma[i])
                             for i in range(3)) + (255,)
    return im


# --------------------------------------------------------------------------
# ore and gem overlays (ruling 17)

# key -> (motif, five-stop ramp dark..highlight)
GEMS = {
    # G1 gems: VoxeLibre emerald cut (one big faceted stone)
    "citrine": ("emerald", ("#5a3806", "#a0690c", "#d9a21b", "#f5cd4e", "#fff3b8")),
    "garnet": ("emerald", ("#34040e", "#660c1c", "#951827", "#c43e4e", "#f09aa6")),
    "jade": ("emerald", ("#0c3520", "#1b643c", "#35955e", "#67c48c", "#c9f2d6")),
    # G2 gems: VoxeLibre diamond cut (cluster with facets)
    "diamond": ("diamond", ("#3f6f8a", "#6aa6c6", "#a6dcf2", "#e0f6ff", "#ffffff")),
    "sapphire": ("diamond", ("#0b1d58", "#163896", "#2459c8", "#5c8ce8", "#c4d8ff")),
    "ruby": ("diamond", ("#4e0412", "#8c0f22", "#cc1f3a", "#ee5c72", "#ffc6ce")),
    # crystal resources
    "emberglass": ("redstone", ("#5c1504", "#a8390b", "#f0701f", "#ffac45", "#fff1a0")),
    "abyssal_crystal": ("lapis", ("#1a0b33", "#36206a", "#5a3aa2", "#9674de", "#e2d0ff")),
    "quartz": ("quartz", ("#8d8480", "#bdb3ae", "#ddd5d0", "#f1ece8", "#ffffff")),
}
MOTIF_SOURCES = {
    "diamond": "mcl_core_diamond_ore.png",
    "emerald": "mcl_core_emerald_ore.png",
    "lapis": "mcl_core_lapis_ore.png",
    "redstone": "mcl_core_redstone_ore.png",
    "quartz": "mcl_nether_quartz_ore.png",
}
RIM_DIFF = 24      # min per-pixel |ore - stone| sum to count as motif
RIM_SAT, RIM_VAL = 0.30, 0.58  # greyish and not bright -> rim, else mineral


def extract_motif(ore, vl_stone, kind):
    """-> {(x, y): ("rim", luminance ratio) | ("mineral", luminance)}"""
    o, s = ore.load(), vl_stone.load()
    motif = {}
    if kind == "quartz":
        # sits on netherrack, not stone: take the pale flecks only
        for y in range(16):
            for x in range(16):
                h, sat, v = colorsys.rgb_to_hsv(*(c / 255 for c in o[x, y][:3]))
                if sat < 0.45 and v > 0.5:
                    motif[(x, y)] = ("mineral", lum(o[x, y]))
        return motif
    stone_mean = sum(lum(s[x, y]) for x in range(16) for y in range(16)) / 256
    for y in range(16):
        for x in range(16):
            p, q = o[x, y], s[x, y]
            if sum(abs(p[i] - q[i]) for i in range(3)) < RIM_DIFF:
                continue
            h, sat, v = colorsys.rgb_to_hsv(*(c / 255 for c in p[:3]))
            if sat < RIM_SAT and v < RIM_VAL:
                motif[(x, y)] = ("rim", lum(p) / stone_mean)
            else:
                motif[(x, y)] = ("mineral", lum(p))
    return motif


def paint_motif(motif, ramp, our_stone, add_shadow=False):
    ramp = [hexrgb(c) for c in ramp]
    st = our_stone.load()
    palette = sorted({st[x, y][:3] for x in range(16) for y in range(16)},
                     key=lum)
    # two darker steps so rims can go below the stone's darkest grey
    darkest = palette[0]
    palette = [tuple(clamp(c * f) for c in darkest) for f in (0.72, 0.85)] + palette
    our_mean = sum(lum(st[x, y]) for x in range(16) for y in range(16)) / 256
    minerals = [v for (kind, v) in motif.values() if kind == "mineral"]
    lo, hi = min(minerals), max(minerals)
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    for (x, y), (kind, v) in motif.items():
        if kind == "rim":
            px[x, y] = nearest(palette, v * our_mean) + (255,)
        else:
            t = (v - lo) / (hi - lo) if hi > lo else 1.0
            px[x, y] = ramp[int(round(t * (len(ramp) - 1)))] + (255,)
    if add_shadow:
        # quartz flecks have no rim upstream: drop a one-pixel shadow down-right
        for (x, y), (kind, _) in list(motif.items()):
            for sx, sy in ((x + 1, y + 1), (x, y + 1)):
                if 0 <= sx < 16 and 0 <= sy < 16 and (sx, sy) not in motif \
                        and px[sx, sy][3] == 0:
                    px[sx, sy] = palette[1] + (255,)
    return im


# silver: minetest_game streak language, own arrangement and relief
SILVER_RAMP = ("#7d8a9c", "#a9b8ca", "#d2deeb", "#f4f8ff")  # dark..specular
SILVER_SHADOW = ("#2e3440", 120)  # translucent shade under each streak


def silver_overlay(mtg_iron):
    """Iron's streak overlay mirrored left-right and re-shaded cold silver.

    The mirror keeps silver out of the exact streak layout coal, copper, tin,
    iron and gold share; the shade line under each streak gives it a metallic
    relief the flat tin streaks do not have.
    """
    src = mtg_iron.load()
    pix = {(15 - x, y): src[x, y] for y in range(16) for x in range(16)
           if src[x, y][3] > 0}
    lums = [lum(p) for p in pix.values()]
    lo, hi = min(lums), max(lums)
    ramp = [hexrgb(c) for c in SILVER_RAMP]
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    for (x, y), p in pix.items():
        t = (lum(p) - lo) / (hi - lo) if hi > lo else 1.0
        px[x, y] = ramp[int(round(t * (len(ramp) - 1)))] + (255,)
    shade, alpha = hexrgb(SILVER_SHADOW[0]), SILVER_SHADOW[1]
    for (x, y) in pix:
        if y + 1 < 16 and (x, y + 1) not in pix:
            px[x, y + 1] = shade + (alpha,)
    return im


# --------------------------------------------------------------------------
# build

def build(vl_dir):
    bad = []
    mtg = {n: load(MTG / n, h, bad) for n, h in MTG_SOURCES.items()}
    vl = {n: load(vl_dir / n, h, bad) for n, h in VL_SOURCES.items()}
    if bad:
        sys.exit("pinned source changed:\n  " + "\n  ".join(bad))
    mtg_stone = mtg["default_stone.png"]
    mtg_iron = mtg["default_mineral_iron.png"]

    out = {}
    for tier in TIERS:
        out["grug_materials_t%d_stone.png" % tier] = tier_rock(mtg_stone, tier)
    for name, (src, target, contrast) in DECOR.items():
        out["grug_materials_%s.png" % name] = grade(
            vl[src].crop((0, 0, 16, 16)), target, contrast)
    motifs = {k: extract_motif(vl[f], vl["default_stone.png"], k)
              for k, f in MOTIF_SOURCES.items()}
    for key, (motif, ramp) in GEMS.items():
        out["grug_materials_mineral_%s.png" % key] = paint_motif(
            motifs[motif], ramp, mtg_stone, add_shadow=(motif == "quartz"))
    out["grug_materials_mineral_silver.png"] = silver_overlay(mtg_iron)
    return out, mtg_stone


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voxelibre", type=Path,
                    default=ROOT / "reference_projects/VoxeLibre")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--renders", action="store_true")
    args = ap.parse_args()
    vl_dir = args.voxelibre / "textures"
    if not (vl_dir / "mcl_core_diamond_ore.png").exists():
        sys.exit("VoxeLibre textures not found in %s (use --voxelibre)" % vl_dir)
    out, mtg_stone = build(vl_dir)
    bad = []
    for name, im in sorted(out.items()):
        path = OUT / name
        if args.check:
            if not path.exists() or \
                    Image.open(path).convert("RGBA").tobytes() != im.tobytes():
                bad.append(name)
        else:
            im.save(path, optimize=True)
    if bad:
        sys.exit("would change: " + ", ".join(bad))
    print("%s %d textures" % ("checked" if args.check else "wrote", len(out)))
    if args.renders:
        import render_sheets
        render_sheets.render_all(out, mtg_stone, MTG, RENDERS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
