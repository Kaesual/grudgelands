#!/usr/bin/env python3
"""The civic lakes' core tables from the study's masks (tools/r70_design/data/lakes.json,
the real water function with the calm square at half 57, x and z local to the anchor).

  python3 tools/r70_cap/lake_table.py lethariel [--unshifted]   Lua rows of `MERE` inside the pad
  python3 tools/r70_cap/lake_table.py kezamba [--unshifted]     Lua rows of `LAGOON` (x runs per z)

Prints the rows to paste into wp13/lethariel.lua or wp13/kezamba_lagoon.lua.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PAD = 57


def main():
    capital = sys.argv[1]
    key = "unshifted" if "--unshifted" in sys.argv else "shifted"
    cells = json.loads((HERE.parent / "r70_design/data/lakes.json").read_text())[capital][key]
    rows = {}
    for x, z in cells:
        rows.setdefault(z, set()).add(x)
    if capital == "lethariel":
        items = []
        for z in sorted(r for r in rows if r <= PAD):
            inside = [x for x in rows[z] if abs(x) <= PAD]
            if inside:
                items.append("[%d] = {%d, %d}," % (z, min(inside), max(inside)))
        print("MERE_FIRST =", min(rows))
        line = "\t\t"
        for item in items:
            if len(line) + len(item) > 72:
                print(line.rstrip())
                line = "\t\t"
            line += item + " "
        print(line.rstrip())
        return
    for z in sorted(rows):
        xs = sorted(rows[z])
        runs, start, last = [], xs[0], xs[0]
        for x in xs[1:]:
            if x != last + 1:
                runs.append((start, last))
                start = x
            last = x
        runs.append((start, last))
        print("\t\t{%d, %s}," % (z, ", ".join("{%d, %d}" % run for run in runs)))


main()
