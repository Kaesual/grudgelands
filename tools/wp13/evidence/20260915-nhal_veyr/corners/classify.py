"""Where did the curtain move? Every changed cell, classified by its column.

A CORNER CELL is one whose column is within the corner's own influence: the
clamp raises exactly one column of a run and the re-sweep carries the raise out
by one node per column, so the reach is `datum - raw` columns. The bound checked
here is the generous, structural one: the column lies within `REACH` = 40 of a
corner column of its own run's axis (+-256 for a z-run, +-252 for an x-run),
i.e. inside the look-around window the corner clamp is allowed to influence.
Anything outside that is a cell the corner commit had no business moving.

WHAT IT PRINTS, and why not a range. The first version printed `columns
min..max`, which for a run that moved at both of its corners reads
`-252..252` -- a five-hundred-column spread, and the reviewer of 2026-09-16 and
the coordinator both had to go and check it was not one. It prints the COUNT of
distinct columns, the WORST DISTANCE from a corner column, and the columns
themselves (contracted into runs), which are the three numbers the question
actually wants.
"""
import collections
import glob
import os
import sys

REACH = 40
CORNER_OF = {
    "wall_west": 256, "wall_east": 256,      # z-runs: corners at z = +-256
    "wall_south": 252, "wall_north": 252,    # x-runs: corners at x = +-252
}
AXIS_OF = {"wall_west": "z", "wall_east": "z",
           "wall_south": "x", "wall_north": "x"}


def spans(values):
    """Contract a sorted set of columns into `a..b` runs, for reading."""
    out, start, prev = [], None, None
    for v in sorted(values):
        if start is None:
            start, prev = v, v
        elif v == prev + 1:
            prev = v
        else:
            out.append((start, prev))
            start, prev = v, v
    if start is not None:
        out.append((start, prev))
    return " ".join("%d" % a if a == b else "%d..%d" % (a, b) for a, b in out)


for path in sorted(glob.glob(sys.argv[1] + "/diff-*.txt")):
    name = os.path.basename(path)[5:-4]
    outside = []
    by_run = collections.Counter()
    columns = collections.defaultdict(set)
    worst = {}
    lines = 0
    for line in open(path):
        if not line[:1] in "<>":
            continue
        lines += 1
        parts = line[2:].rstrip("\n").split("\t")
        if len(parts) < 6:
            continue
        run, x, y, z = parts[0], int(parts[1]), int(parts[2]), int(parts[3])
        p = z if AXIS_OF[run] == "z" else x
        c = CORNER_OF[run]
        d = min(abs(p - c), abs(p + c))
        by_run[run] += 1
        columns[run].add(p)
        if d > worst.get(run, -1):
            worst[run] = d
        if d > REACH:
            outside.append((run, x, y, z, p, d))
    print("%-34s changed=%d" % (name, lines))
    for run in sorted(by_run):
        print("    %-11s cells=%-5d columns=%-3d worst distance from a corner=%-3d %s"
              % (run, by_run[run], len(columns[run]), worst[run],
                 spans(columns[run])))
    if outside:
        print("    OUTSIDE ANY CORNER WINDOW: %d" % len(outside))
        for row in outside[:10]:
            print("      ", row)
    else:
        print("    every changed cell is inside a corner's look-around window "
              "(REACH = %d)" % REACH)
