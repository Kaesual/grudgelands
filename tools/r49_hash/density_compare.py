#!/usr/bin/env python3
"""Round 49 lane HASH: compare two tools/r49_hash/density.lua outputs.

    python3 -I tools/r49_hash/density_compare.py BEFORE.txt AFTER.txt

Chunks are grouped by their label before "#" (a biome's chunks together).
It also reads the "surface_count id=<chunk> <name>=<n> ..." lines the mgprof
probe (tools/mgprof/grug_probe_mgprof) logs for the surface chunks of an
engine boot, so two server logs compare the same way.
Prints per group the planned decoration candidates per row (before, after),
and the written nodes per kind: trees (trunks and wood shapes), leaves,
gathering sources and ground cover (the other names whose count differs;
terrain other stages write is the same in both runs). Ends with the totals
over every chunk.
"""
import sys
from collections import defaultdict


def read(path):
    candidates = defaultdict(lambda: defaultdict(int))
    counts = defaultdict(lambda: defaultdict(int))
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if "surface_count id=" in line:
                parts = line.split("surface_count id=", 1)[1].split()
                for item in parts[1:]:
                    name, _, n = item.rpartition("=")
                    counts[parts[0]][name] += int(n)
                continue
            parts = line.split()
            if len(parts) == 4 and parts[0] in ("candidates", "count"):
                target = candidates if parts[0] == "candidates" else counts
                target[parts[1]][parts[2]] += int(parts[3])
    return candidates, counts


def kind(name):
    if name.startswith("grug_gathering:") or name.endswith("_source"):
        return "gathering"
    if "leaves" in name or "needles" in name or "hanging_moss" in name:
        return "leaves"
    if (name.endswith("tree") or name.endswith("_trunk") or "_quarter" in name or
            name.endswith("_base") or name.endswith("_branch") or name.endswith("_twig") or
            name.endswith("_stem") or name == "default:apple"):
        return "tree"
    return "cover"


def ratio(a, b):
    return f"{b / a:.2f}" if a else "-"


def main():
    before_c, before_n = read(sys.argv[1])
    after_c, after_n = read(sys.argv[2])
    groups = defaultdict(lambda: [defaultdict(lambda: [0, 0]), defaultdict(lambda: [0, 0])])
    for chunk in sorted(set(before_n) | set(after_n)):
        group = chunk.split("#")[0]
        for source, side in ((before_c, 0), (after_c, 1)):
            for row, n in source.get(chunk, {}).items():
                groups[group][0][row][side] += n
        names = set(before_n.get(chunk, {})) | set(after_n.get(chunk, {}))
        for name in names:
            a, b = before_n.get(chunk, {}).get(name, 0), after_n.get(chunk, {}).get(name, 0)
            k = kind(name)
            if k == "cover" and a == b:
                continue
            if name == "air":
                continue
            groups[group][1][k][0] += a
            groups[group][1][k][1] += b
    total_c = defaultdict(lambda: [0, 0])
    total_n = defaultdict(lambda: [0, 0])
    for group in sorted(groups):
        rows, kinds = groups[group]
        print(f"## {group}")
        print("  candidates per row          before   after")
        for row in sorted(rows):
            a, b = rows[row]
            total_c[row][0] += a
            total_c[row][1] += b
            print(f"    {row:28s} {a:6d} {b:6d}  {ratio(a, b)}")
        print("  written nodes per kind      before   after")
        for k in sorted(kinds):
            a, b = kinds[k]
            total_n[k][0] += a
            total_n[k][1] += b
            print(f"    {k:28s} {a:6d} {b:6d}  {ratio(a, b)}")
    print("## all chunks")
    a = sum(v[0] for v in total_c.values())
    b = sum(v[1] for v in total_c.values())
    print(f"  candidates, every row        {a:6d} {b:6d}  {ratio(a, b)}")
    for k in sorted(total_n):
        a, b = total_n[k]
        print(f"  nodes: {k:22s} {a:6d} {b:6d}  {ratio(a, b)}")


if __name__ == "__main__":
    main()
