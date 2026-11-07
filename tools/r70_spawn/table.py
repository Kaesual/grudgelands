#!/usr/bin/env python3
"""The census table of Round 70 lane SPAWN (tools/r70_spawn/census.lua).

  python3 tools/r70_spawn/table.py LABEL=FILE[,FILE...] [LABEL=FILE ...]

Each LABEL is one run (a seed before or after); its FILEs are the parts of
that run, added up. Prints per source the eligible columns and written nodes
of each run, the nodes outside the renewal habitat (0 wanted), then each
run's written nodes per zone.
"""
import sys
from collections import defaultdict


def read(files):
    rows = defaultdict(lambda: defaultdict(lambda: [0, 0, 0]))
    for path in files:
        with open(path) as handle:
            for line in handle:
                source, zone, *values = line.split()
                for index, value in enumerate(values):
                    rows[source][zone][index] += int(value)
    return rows


def main():
    runs = {}
    for argument in sys.argv[1:]:
        label, files = argument.split("=", 1)
        runs[label] = read(files.split(","))
    sources = sorted({source for rows in runs.values() for source in rows})
    print("| Source | " + " | ".join(f"{label} eligible | {label} written" for label in runs) +
          " | outside |")
    print("|---|" + "---:|---:|" * len(runs) + "---:|")
    for source in sources:
        cells, outside = [], 0
        for rows in runs.values():
            zones = rows[source].values()
            cells += [str(sum(row[0] for row in zones)), str(sum(row[1] for row in zones))]
            outside += sum(row[2] for row in zones)
        print(f"| {source} | " + " | ".join(cells) + f" | {outside} |")
    print()
    for label, rows in runs.items():
        print(label)
        for source in sources:
            zones = sorted(rows[source].items(), key=lambda item: -item[1][1])
            shares = ", ".join(f"{zone} {row[1]}/{row[0]}" for zone, row in zones if row[1] or row[0] > 200)
            print(f"  {source}: {shares}")


if __name__ == "__main__":
    main()
