#!/usr/bin/env python3
"""Summarize tools/r24_density_xp/run.sh probe logs as a Markdown table.

Usage: summarize.py BEFORE_PROBE.txt [...] -- AFTER_PROBE.txt [...]

Every probe file holds the census lines of one boot. For each area and clock
the table shows the budgeted mobs at the 120 s census (one value per boot) and
the mean over all 60/90/120 s censuses of all boots of that side.
"""
import re
import sys

LINE = re.compile(r"census (\w+) (day|night)@(\d+) (\w+) budgeted=(\d+)")
AREAS = ["hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar",
         "kapok", "moonfall", "redtusk"]


def read(paths):
    final, samples = {}, {}
    for path in paths:
        with open(path) as handle:
            for line in handle:
                match = LINE.search(line)
                if not match:
                    continue
                _, clock, second, area, count = match.groups()
                key = (area, clock)
                samples.setdefault(key, []).append(int(count))
                if second == "120":
                    final.setdefault(key, []).append(int(count))
    return final, samples


def main(argv):
    split = argv.index("--")
    before, after = read(argv[:split]), read(argv[split + 1:])
    print("| Area | Clock | Before @120 s | After @120 s | Before mean | After mean |")
    print("|---|---|---|---|---:|---:|")
    totals = {}
    for clock in ("day", "night"):
        for area in AREAS:
            key = (area, clock)
            cells = []
            for side in (before, after):
                cells.append(" / ".join(str(v) for v in side[0].get(key, [])))
            means = []
            for index, side in enumerate((before, after)):
                values = side[1].get(key, [])
                mean = sum(values) / len(values) if values else 0
                means.append(mean)
                totals[(clock, index)] = totals.get((clock, index), 0) + mean
            print(f"| {area} | {clock} | {cells[0]} | {cells[1]} | "
                  f"{means[0]:.1f} | {means[1]:.1f} |")
    for clock in ("day", "night"):
        print(f"| **sum** | {clock} | | | **{totals[(clock, 0)]:.1f}** | "
              f"**{totals[(clock, 1)]:.1f}** |")


if __name__ == "__main__":
    main(sys.argv[1:])
