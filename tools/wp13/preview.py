#!/usr/bin/env python3
"""Render the authored blueprint TSV as a schematic isometric overview.

Uses symbolic material colours, not engine textures or lighting. Input rows:
x TAB y TAB z TAB node_name TAB param2. Requires Pillow, no game runtime.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("cells", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
cells = {}
for line in args.cells.read_text().splitlines():
    x, y, z, name, param2 = line.split("\t")
    if name != "air":
        cells[int(x), int(y), int(z)] = name


def colour(name):
    if "torch" in name:
        return (239, 182, 72)
    if "glass" in name:
        return (141, 199, 211)
    if "pine_tree" in name or "fence" in name:
        return (93, 68, 49)
    if "needles" in name or "fern" in name or "grass" in name:
        return (81, 122, 62)
    if "dirt" in name:
        return (116, 94, 60)
    if "pine" in name:
        return (164, 120, 76)
    if "cobble" in name:
        return (121, 123, 112)
    return (155, 157, 149)


def project(x, y, z):
    return (1100 + (x - z) * 8, 620 + (x + z) * 4 - y * 10)


im = Image.new("RGB", (2200, 1250), (234, 236, 220))
draw = ImageDraw.Draw(im)
draw.polygon([project(x, -0.6, z) for x, z in
              [(-48, -38), (45, -38), (45, 70), (-48, 70)]], fill=(109, 137, 84))
for (x, y, z), name in sorted(cells.items(), key=lambda row: (sum(row[0]), row[0])):
    c = colour(name)
    h = 0.5 if "slab_" in name else 1
    a, b = x - 0.5, x + 0.5
    d, e = z - 0.5, z + 0.5
    low, high = y - 0.5, y - 0.5 + h
    faces = [
        ((1, 0, 0), [(b, low, d), (b, low, e), (b, high, e), (b, high, d)], 0.72),
        ((0, 0, 1), [(a, low, e), (b, low, e), (b, high, e), (a, high, e)], 0.86),
        ((0, 1, 0), [(a, high, d), (b, high, d), (b, high, e), (a, high, e)], 1.08),
    ]
    for offset, vertices, shade in faces:
        if tuple(v + o for v, o in zip((x, y, z), offset)) in cells:
            continue
        fill = tuple(min(255, round(value * shade)) for value in c)
        draw.polygon([project(*v) for v in vertices], fill=fill)
draw.text((30, 25), "Hearthpine Vale | WP13 architectural preview", fill=(34, 41, 32))
draw.text((30, 46), "Symbolic colours; final textures, vegetation and lighting are provided by Luanti.",
          fill=(65, 70, 56))
im.save(args.output)
