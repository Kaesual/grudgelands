#!/usr/bin/env python3
"""Round 51 TERRAIN T1: summarise two dumps of tools/r51_terrain/compare.lua.

    python3 tools/r51_terrain/diff_dumps.py BEFORE AFTER

Per section: lines that differ. For the chunks, which chunks differ (the
"straddle" chunks hold ring columns and are expected to). For the terrain
field's floats: how many columns differ, the largest difference of the
surface height and of the zone character channels on land (positive coast
distance) and at sea, and whether any surface height changes its integer
floor (the node the world writes). Exits 1 when a layout, column or
non-straddle chunk line differs or a floor changes.
"""
import math
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
    for name in ("layout", "columns"):
        a, b = before[name], after[name]
        differ = sum(1 for x, y in zip(a, b) if x != y) + abs(len(a) - len(b))
        print(f"{name}: {len(a)} lines, {differ} differ")
        bad = bad or differ > 0
    changed = []
    for x, y in zip(before["chunks"], after["chunks"]):
        if x != y:
            changed.append(" ".join(x.split()[:5]))
            if "straddle" not in x:
                bad = True
    print(f"chunks: {len(before['chunks'])}, differ: {', '.join(changed) or 'none'}")
    rows = {}
    for line in before["field"]:
        f = line.split()
        rows[(f[0], f[1])] = f[2:]
    differ = flips = 0
    worst = {"land height": 0.0, "sea height": 0.0, "land channels": 0.0,
             "sea channels": 0.0, "coast": 0.0}
    for line in after["field"]:
        f = line.split()
        a, b = rows[(f[0], f[1])], f[2:]
        if a == b:
            continue
        differ += 1
        where = "land" if float(a[1]) > 0 else "sea"
        ha, hb = float(a[0]), float(b[0])
        worst[where + " height"] = max(worst[where + " height"], abs(ha - hb))
        worst["coast"] = max(worst["coast"], abs(float(a[1]) - float(b[1])))
        channels = max(abs(float(x) - float(y)) for x, y in zip(a[2:], b[2:]))
        worst[where + " channels"] = max(worst[where + " channels"], channels)
        if math.floor(ha) != math.floor(hb):
            flips += 1
    print(f"field: {len(rows)} columns, {differ} differ; largest differences: " +
          ", ".join(f"{k} {v:.3g}" for k, v in worst.items()) +
          f"; integer floor changes: {flips}")
    bad = bad or flips > 0 or worst["coast"] > 0
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
