#!/usr/bin/env python3
"""Round 51 TERRAIN T4: compare two dumps of tools/r51_t4/compare.lua.

    python3 tools/r51_t4/diff_dumps.py BEFORE AFTER

Prints whether the layout digests agree, then per chunk every node change
(before -> after, with its count), the ground height check (the highest
solid ground node of every column, plants, air and water skipped, must not
move) and the surface shares of the branch: the swamp's moss tops, the clay
band columns among the badlands' columns, the ice among the snowy crags'
snowblock tops and the pebbles among the dry coast sand, and the seabed
under water by node. Exits 1 when a layout line differs, a ground height
moves or a change outside the expected pairs shows.
"""
import sys
from collections import Counter

BANDS = {"grug_nodes:clay_band_ochre", "grug_nodes:clay_band_sienna",
         "grug_nodes:clay_band_chalk", "grug_nodes:clay_band_umber"}
# Expected changes: the swamp's moss, the bands over the badlands' face
# (stone, its strata and mesa clay), the ice and its lost snow, the pebbles,
# and the plants the new tops no longer host (dry shrubs and the cactus on a
# band top, snow on ice).
BAND_FROM = {"grug_nodes:mesa_clay", "default:stone", "grug_materials:basalt",
             "default:gravel", "default:dirt", "default:dry_dirt"}
PLANTS = {"default:dry_shrub", "default:cactus", "default:snow"}


def expected(before, after):
    if before == "grug_nodes:dirt_with_moss" and after == "grug_nodes:swamp_moss":
        return True
    if before in BAND_FROM and (after in BANDS or after == "grug_nodes:mesa_clay"):
        return True
    if before == "default:snowblock" and after == "default:ice":
        return True
    if before == "default:sand" and after == "default:gravel":
        return True
    if before in PLANTS and after == "air":
        return True
    # low plants: the decoration rows follow the new tops (a host lost or
    # gained, the cell's thinning order), a change the summary counts
    if (before == "air") != (after == "air") and not solid(before if after == "air" else after):
        return True
    return False


def solid(name):
    return name not in ("air", "ignore") and "water" not in name and \
        name not in PLANTS and not name.startswith("default:grass") and \
        not name.startswith("default:fern") and not name.startswith("default:dry_grass") and \
        name not in ("default:junglegrass", "grug_nodes:moss_carpet", "grug_nodes:reeds",
                     "grug_nodes:cattails", "grug_mapgen:freshwater_waterlily")


def load(path):
    layout, chunks, chunk = [], [], None
    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("# chunk "):
                chunk = {"head": line[8:].split(" hash=")[0], "biome": {}, "col": {}}
                chunks.append(chunk)
            elif line.startswith("# "):
                continue
            elif line.startswith("B "):
                _, x, z, biome = line.split(" ")
                chunk["biome"][(int(x), int(z))] = biome
            elif line.startswith("C "):
                parts = line.split(" ")
                x, z, y0 = int(parts[1]), int(parts[2]), int(parts[3])
                nodes = []
                for run in parts[4:]:
                    name, count = run.rsplit("*", 1)
                    nodes.extend([name] * int(count))
                chunk["col"][(x, z)] = (y0, nodes)
            else:
                layout.append(line)
    return layout, chunks


def top(y0, nodes):
    for i in range(len(nodes) - 1, -1, -1):
        if solid(nodes[i]):
            return y0 + i, nodes[i], i
    return None, None, None


def main():
    lb, cb = load(sys.argv[1])
    la, ca = load(sys.argv[2])
    bad = False
    differ = sum(1 for x, y in zip(lb, la) if x != y) + abs(len(lb) - len(la))
    print(f"layout: {len(lb)} lines, {differ} differ")
    bad = bad or differ > 0
    for before, after in zip(cb, ca):
        print(f"\nchunk {before['head']}")
        if before["head"] != after["head"]:
            print("  chunk differs:", after["head"])
            bad = True
            continue
        pairs, moved, columns = Counter(), 0, 0
        shares = Counter()
        bed = Counter()
        for key, (y0, nb) in before["col"].items():
            _, na = after["col"][key]
            columns += 1
            for b, a in zip(nb, na):
                if b != a:
                    pairs[(b, a)] += 1
            hb, tb, ib = top(y0, nb)
            ha, ta, _ = top(y0, na)
            if hb != ha:
                moved += 1
            if tb is None:
                continue
            biome = before["biome"][key]
            wet = ib + 1 < len(nb) and "water" in nb[ib + 1]
            if wet:
                bed[ta] += 1
                continue
            if biome == "grug_swamp":
                shares["swamp tops"] += 1
                shares["swamp moss tops"] += ta == "grug_nodes:swamp_moss"
                shares["swamp old moss tops"] += ta == "grug_nodes:dirt_with_moss"
            if biome in ("grug_badlands", "grug_badlands_east"):
                shares["badlands columns"] += 1
                banded = any(n in BANDS for n in na)
                shares["badlands banded columns"] += banded
                shares["badlands band tops"] += ta in BANDS
            if biome == "grug_crags_snowy" and tb == "default:snowblock":
                shares["snowy snowblock tops"] += 1
                shares["snowy ice tops"] += ta == "default:ice"
            if tb == "default:sand":
                shares["dry sand tops"] += 1
                shares["dry sand to gravel"] += ta == "default:gravel"
        print(f"  columns {columns}, ground height moved in {moved}")
        bad = bad or moved > 0
        for (b, a), n in sorted(pairs.items(), key=lambda item: -item[1]):
            flag = "" if expected(b, a) else "   UNEXPECTED"
            bad = bad or flag != ""
            print(f"  {n:7d}  {b} -> {a}{flag}")
        for name in sorted(shares):
            print(f"  share  {name}: {shares[name]}")
        if bed:
            total = sum(bed.values())
            print("  bed under water: " + ", ".join(
                f"{n} {c / total:.0%}" for n, c in bed.most_common()))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
