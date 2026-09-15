#!/usr/bin/env python3
"""Draw a capital's terraces from a field TSV: the plateau from above, and a
block section through the anchor a reader can count the steps in.

    python3 tools/wp13/render_terraces.py FIELD.tsv -o OUT.png
    python3 tools/wp13/render_terraces.py BEFORE.tsv AFTER.tsv -o OUT.png \
        --labels before,after --section-from 40 --section-to 140

The field TSV is what `tools/wp13/run_highcourt.sh <out> field <seed>` and
`tools/wp13/run_capital.sh <out> <key> field <seed>` write, and what
`tools/wp13/highcourt_plots.lua` reads: one row per z, the pure final height of
every column of the envelope and a land flag per column.

WHY A SEPARATE PICTURE. `render_blueprint.py` draws NODES, which is the right
picture for a building and the wrong one for a plateau: at four pixels a node a
512-wide capital is a grey square whose terraces are invisible. This draws the
HEIGHT, and it draws the two things a terrace argument is about:

  * THE PLAN, coloured on a cycle whose period is the race's terrace step, so
    every plateau is one flat band of colour and every riser is the edge
    between two. A vertical riser is a single hard edge; a band of one-block
    ground steps is several edges a node apart, and the difference is visible
    without counting anything.
  * THE SECTION along z = 0, drawn as BLOCKS, one per node, so the steps can be
    counted. Two fields are drawn as two strips one above the other, which is
    the before/after picture.

Water is drawn in its own blue: a terrace argument that silently includes a
river bed is the mistake that once put two district plots in the water.

Only Python 3 + Pillow are required.
"""

from __future__ import annotations

import argparse
import sys

from PIL import Image, ImageDraw

WATER = (46, 78, 132)
GROUND = [(76, 92, 60), (96, 114, 72), (120, 138, 86), (146, 162, 104),
          (172, 186, 126), (198, 208, 152), (222, 228, 184), (238, 242, 214)]
STEP_EDGE = (28, 30, 26)


def read_field(path):
    reach = None
    heights = {}
    land = {}
    with open(path) as handle:
        for line in handle:
            if line.startswith("#"):
                if "reach=" in line:
                    reach = int(line.split("reach=")[1].split()[0])
                continue
            line = line.rstrip("\n")
            if not line:
                continue
            z, numbers, flags = line.split("\t")
            z = int(z)
            heights[z] = [int(v) for v in numbers.split()]
            land[z] = flags
    if reach is None:
        raise SystemExit("%s has no reach header" % path)
    return reach, heights, land


def plan(draw, field, ox, oy, scale, window, period):
    reach, heights, land = field
    lo = None
    for z in range(-window, window + 1):
        row, flags = heights[z], land[z]
        for x in range(-window, window + 1):
            if flags[x + reach] == "1":
                y = row[x + reach]
                lo = y if lo is None or y < lo else lo
    lo = 0 if lo is None else lo
    for z in range(-window, window + 1):
        row, flags = heights[z], land[z]
        for x in range(-window, window + 1):
            if flags[x + reach] != "1":
                colour = WATER
            else:
                colour = GROUND[((row[x + reach] - lo) // period) % len(GROUND)]
            px = ox + (x + window) * scale
            py = oy + (z + window) * scale
            draw.rectangle([px, py, px + scale - 1, py + scale - 1], fill=colour)


WALL = (214, 72, 64)


def section(draw, field, ox, oy, height_px, x0, x1, node_px, period):
    """One strip of blocks, one block per node, floor drawn down to the strip.

    A column whose neighbour along the section is more than ONE node up is
    outlined in red: that is a step the player cannot climb, and counting the
    red edges before and after is the whole argument.
    """
    reach, heights, land = field
    row, flags = heights[0], land[0]
    values = [row[x + reach] for x in range(x0, x1 + 1)]
    wet = [flags[x + reach] != "1" for x in range(x0, x1 + 1)]
    lo, hi = min(values), max(values)
    rows = hi - lo + 1
    cell = max(1, min(node_px, height_px // max(1, rows)))
    walls = 0
    for index, y in enumerate(values):
        px = ox + index * node_px
        top = oy + height_px - (y - lo + 1) * cell
        colour = WATER if wet[index] else GROUND[((y - lo) // period) %
                                                 len(GROUND)]
        draw.rectangle([px, top, px + node_px - 1, oy + height_px - 1],
                       fill=colour)
        climb = 0
        if index > 0:
            climb = max(climb, values[index - 1] - y)
        if index + 1 < len(values):
            climb = max(climb, values[index + 1] - y)
        edge = WALL if climb > 1 else STEP_EDGE
        if climb > 1:
            walls += 1
        draw.rectangle([px, top, px + node_px - 1, top + max(0, cell - 1)],
                       outline=edge)
    return lo, hi, cell, walls


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("fields", nargs="+")
    parser.add_argument("-o", "--out", required=True)
    parser.add_argument("--window", type=int, default=250)
    parser.add_argument("--scale", type=int, default=2)
    parser.add_argument("--step", type=int, default=2,
                        help="the race terrace step; the plan's colour period")
    parser.add_argument("--section-from", type=int, default=40)
    parser.add_argument("--section-to", type=int, default=160)
    parser.add_argument("--node-px", type=int, default=8)
    parser.add_argument("--title", default="")
    parser.add_argument("--labels", default="")
    args = parser.parse_args(argv)

    fields = [read_field(path) for path in args.fields]
    window = min(args.window, min(f[0] for f in fields))
    labels = [s.strip() for s in args.labels.split(",")] if args.labels else \
        list(args.fields)
    side = (2 * window + 1) * args.scale
    gap = 16
    columns = args.section_to - args.section_from + 1
    strip_w = columns * args.node_px
    strip_h = 150
    width = max(len(fields) * side + (len(fields) - 1) * gap, strip_w) + 8
    height = side + 20 + len(fields) * (strip_h + 18) + 22
    image = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(image)

    for index, field in enumerate(fields):
        ox = index * (side + gap) + 4
        plan(draw, field, ox, 0, args.scale, window, args.step)
        draw.text((ox + 4, side + 4), "plan  %s" % labels[index],
                  fill=(220, 220, 220))
    top = side + 20
    for index, field in enumerate(fields):
        lo, hi, cell, walls = section(draw, field, 4, top + 14, strip_h,
                                      args.section_from, args.section_to,
                                      args.node_px, args.step)
        draw.text((4, top),
                  "section z=0  x %d..%d  %s  y %d..%d  (%d px/node)  "
                  "%d unclimbable column(s), outlined red"
                  % (args.section_from, args.section_to, labels[index], lo, hi,
                     cell, walls), fill=(220, 220, 220))
        top += strip_h + 18
    if args.title:
        draw.text((4, height - 14), args.title, fill=(200, 200, 200))
    image.save(args.out)
    print("%s  %dx%d" % (args.out, width, height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
