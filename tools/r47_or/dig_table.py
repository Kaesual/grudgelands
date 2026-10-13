#!/usr/bin/env python3
"""Round 47 lane OR: the before/after dig-time table of two dig matrices.

    python3 tools/r47_or/dig_table.py BEFORE.tsv AFTER.tsv

Both are written by tools/r47_or/run_dig.sh (the engine's own
core.get_dig_params for every pick, axe and shovel over every node a tool
digs or that carries a level). Prints the node levels that changed, one row
per node class (level, cracky, grug_resource, grug_stratum, grug_loose) with
the eight picks' times before -> after and the class's nodes, and every
(tool, node) pair whose time or diggability differs. Exits 0.
"""
import sys

PICKS = ["wood", "stone", "bronze", "iron", "steel", "silversteel",
         "embersteel", "abyssal_steel"]


def load(path):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    header = lines[0].split("\t")
    rows = {}
    for line in lines[1:]:
        cells = line.split("\t")
        rows[cells[0]] = dict(zip(header, cells))
    return header, rows


def main():
    header, before = load(sys.argv[1])
    _, after = load(sys.argv[2])
    tools = header[7:]
    print("Dig matrix before -> after (engine core.get_dig_params, seconds; "
          "'-' = the tool's own capabilities cannot dig it)")
    print()
    print("Node levels that changed:")
    for name in sorted(set(before) | set(after)):
        old = before.get(name, {}).get("level", "absent")
        new = after.get(name, {}).get("level", "absent")
        if old != new:
            print(f"  {name}: level {old} -> {new}")
    print()
    print("Picks by node class (" + ", ".join(PICKS) + "):")
    classes = {}
    for name in sorted(after):
        row = after[name]
        key = (row["level"], row["cracky"], row["grug_resource"],
               row["grug_stratum"], row["grug_loose"])
        cells = []
        for pick in PICKS:
            column = "grug_materials:pick_" + pick
            old = before.get(name, {}).get(column, "absent")
            cells.append(f"{old}->{row[column]}" if old != row[column] else old)
        classes.setdefault((key, tuple(cells)), []).append(name)
    for (key, cells), names in sorted(classes.items()):
        label = "level %s cracky %s resource %s stratum %s loose %s" % key
        shown = ", ".join(names[:6]) + (f" (+{len(names) - 6} more)" if len(names) > 6 else "")
        print(f"  [{label}] {len(names)} node(s): {shown}")
        print("      " + " | ".join(cells))
    print()
    differing = []
    for name in sorted(set(before) & set(after)):
        for tool in tools:
            old, new = before[name].get(tool), after[name].get(tool)
            if old != new and not (old not in (None, "-") and new not in (None, "-")
                                   and abs(float(old) - float(new)) < 0.0005):
                differing.append(f"  {name} x {tool}: {old} -> {new}")
    print(f"Pairs that differ ({len(differing)} of "
          f"{len(set(before) & set(after)) * len(tools)}):")
    print("\n".join(differing) if differing else "  none")
    only = sorted(set(before) ^ set(after))
    if only:
        print("Nodes in one matrix only: " + ", ".join(only))


if __name__ == "__main__":
    main()
