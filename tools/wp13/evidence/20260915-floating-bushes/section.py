#!/usr/bin/env python3
"""One vertical slice through the dumped dwarf ring, before against after.

Reads two render dumps (`x y z name param2`) of the SAME box and prints the
z row that carries a bush as two side-by-side columns of glyphs, so the one
node of air under a floating bush is readable without a renderer.
"""
import sys

GLYPH = [
    ("berries", "b"), ("bush_stem", "T"), ("bush_needles", "#"),
    ("bush_leaves", "#"), ("_tree", "|"), ("needles", "*"), ("leaves", "*"),
    ("grass_", ","), ("fern_", ","), ("dirt", "."), ("gravel", ":"),
    ("stone", "="), ("sand", "-"), ("snow", "~"),
]


def load(path):
    cells = {}
    for line in open(path):
        x, y, z, name, _p2 = line.rstrip("\n").split("\t")
        cells[int(x), int(y), int(z)] = name
    return cells


def glyph(name):
    if name is None:
        return " "
    for needle, mark in GLYPH:
        if needle in name:
            return mark
    return "?"


def render(cells, z, x0, x1, y0, y1):
    rows = []
    for y in range(y1, y0 - 1, -1):
        rows.append("%3d |%s|" % (y, "".join(
            glyph(cells.get((x, y, z))) for x in range(x0, x1 + 1))))
    return rows


before, after, z, x0, x1, y0, y1 = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:8])
b, a = load(before), load(after)
left, right = render(b, z, x0, x1, y0, y1), render(a, z, x0, x1, y0, y1)
print("z=%d, local x %d..%d, local y %d..%d" % (z, x0, x1, y0, y1))
print("T bush stem  # bush foliage  b blueberry  | trunk  * canopy"
      "  , grass/fern  . soil  : gravel  = stone")
print("%-*s   %s" % (len(left[0]), "BEFORE (main)", "AFTER (this lane)"))
for l, r in zip(left, right):
    print("%s   %s" % (l, r))
