"""The corner step of a capital's curtain, read off the cell dump.

The walk at a column is the highest cell of the CENTRE lane that is solid with
air directly above it -- the same reading `nhal_veyr_kat.lua`'s `deck_of` and
`tools/wp13/capital_wall.lua` section 5 take. A z-run meets an x-run at the
z-run's own corner column (+-256); the x-run's walk stops four columns earlier
at +-252.
"""
import collections
import glob
import os
import sys

AT = 256
SIDE = 252
HALF = 3


def load(path):
    cells = collections.defaultdict(dict)
    for line in open(path):
        if line.startswith("#"):
            continue
        run, x, y, z, name = line.split("\t")[:5]
        cells[run][(int(x), int(y), int(z))] = name
    return cells


def deck(cells, run, at, axis, p):
    x, z = (p, at) if axis == "x" else (at, p)
    ys = [k[1] for k in cells[run] if k[0] == x and k[2] == z]
    if not ys:
        return None
    for y in sorted(ys, reverse=True):
        here = cells[run].get((x, y, z))
        above = cells[run].get((x, y + 1, z))
        if here != "air" and above == "air":
            return y
    return None


for path in sorted(glob.glob(sys.argv[1] + "/*-*.tsv")):
    base = os.path.basename(path)[:-4]
    cells = load(path)
    out = []
    for along, at in (("wall_west", -AT), ("wall_east", AT)):
        for across, across_at in (("wall_south", -AT), ("wall_north", AT)):
            turret = deck(cells, along, at, "z", across_at)
            arriving = deck(cells, across, across_at, "x",
                            at - (HALF + 1 if at > 0 else -(HALF + 1)))
            step = None if turret is None or arriving is None \
                else abs(turret - arriving)
            out.append("%s/%s %s-%s step=%s" % (
                along.split("_")[1], across.split("_")[1], turret, arriving,
                step))
    print("%-38s %s" % (base, "  ".join(out)))
