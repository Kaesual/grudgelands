#!/usr/bin/env python3
"""Round 51 TERRAIN T2: "no land moves" between two dumps of compare.lua.

    python3 tools/r51_terrain/diff_land.py BEFORE AFTER

T2 changes the sea on purpose (the water classes, the belt's floor, the
channels), so this compares the land: the layout section (placement,
water, roads, capitals, settlements) must be identical, no column may turn
from land to water or back, and every land column must read the same
(zone, biome, height, levels, territory and PvP rule). For the water columns
it prints the class changes (before -> after, counted) and how many depths
changed. Exits 1 when the layout or any land column differs.
"""
import collections
import sys


def load(path):
    sections, name = {}, None
    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("# "):
                name = line[2:]
                sections[name] = []
            else:
                sections[name].append(line)
    return sections


def main():
    before, after = load(sys.argv[1]), load(sys.argv[2])
    bad = False
    layout = sum(1 for a, b in zip(before["layout"], after["layout"]) if a != b)
    layout += abs(len(before["layout"]) - len(after["layout"]))
    print(f"layout: {len(before['layout'])} lines, {layout} differ")
    bad = bad or layout > 0
    flips = land_differ = land = 0
    examples = []
    classes = collections.Counter()
    depth_changed = 0
    for a, b in zip(before["columns"], after["columns"]):
        fa, fb = a.split(), b.split()
        if fa[:2] != fb[:2]:
            print("column lists differ")
            return 1
        if (fa[2] == "land") != (fb[2] == "land"):
            flips += 1
            if len(examples) < 5:
                examples.append(f"{fa[0]},{fa[1]} {fa[2]}->{fb[2]}")
        elif fa[2] == "land":
            land += 1
            if fa != fb:
                land_differ += 1
                if len(examples) < 5:
                    examples.append(f"land {a} -> {b}")
        else:
            if fa[2] != fb[2]:
                classes[(fa[2], fb[2])] += 1
            if fa[5] != fb[5]:
                depth_changed += 1
    print(f"land columns: {land}, differ: {land_differ}; land/water flips: {flips}")
    for example in examples:
        print("  " + example)
    print(f"water columns whose floor changed: {depth_changed}")
    for (a, b), n in sorted(classes.items(), key=lambda item: -item[1]):
        print(f"  water class {a} -> {b}: {n}")
    bad = bad or flips > 0 or land_differ > 0
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
