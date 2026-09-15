#!/usr/bin/env python3
"""Draw where a WP40 route reaches a capital, before and after the gate ruling.

    python3 render_gate_approach.py BEFORE.tsv AFTER.tsv -o OUT.png \
        --centre -1800,-1500 --labels before,after --title "Dur Brannoc, seed ..."

Input is `feature_map.lua`'s TSV: one row per column with the WP40 functional
kind, the functional feature, the terrain height and a water flag. The picture
is a PLAN, one pixel block per column, coloured by WHO OWNS the column:

  * the capital's own fitting  -- the city's ground;
  * a route                    -- a long-distance road;
  * a POI spur                 -- a short local road;
  * water;
  * everything else            -- open country, shaded by height so the
                                 terraces stay readable.

Over it: the 512-node build envelope, the curtain wall's four gate passages
(13 nodes wide, centred on the avenue), and the four gate points themselves.
The question the picture answers is whether a road crosses the envelope edge
anywhere OTHER than at a gate.

Requires Pillow. No game runtime.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("fields", type=Path, nargs="+")
parser.add_argument("-o", "--output", type=Path, required=True)
parser.add_argument("--centre", required=True, help="anchor x,z")
parser.add_argument("--labels", default="")
parser.add_argument("--title", default="")
parser.add_argument("--scale", type=int, default=1)
args = parser.parse_args()

ANCHOR_X, ANCHOR_Z = (int(v) for v in args.centre.split(","))
HALF = 256
PASSAGE = 6          # the gate passage runs from -6 to +6 on the avenue axis
BG = (24, 24, 28)
INK = (236, 236, 240)
COL_FIT = (86, 96, 116)
COL_ROUTE = (232, 138, 58)
COL_SPUR = (156, 118, 70)
COL_WATER = (52, 96, 148)
COL_GATE = (248, 226, 120)
COL_ENVELOPE = (150, 150, 160)


def load(path):
    rows = {}
    heights = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("x\t"):
            continue
        x, z, kind, feature, terrain, wet = line.split("\t")
        rows[int(x), int(z)] = (kind, feature, int(terrain), wet == "1")
        heights.append(int(terrain))
    return rows, min(heights), max(heights)


fields = [load(path) for path in args.fields]
labels = [label for label in args.labels.split(",") if label]
while len(labels) < len(fields):
    labels.append(args.fields[len(labels)].stem)

xs = sorted({x for rows, _, _ in fields for x, _ in rows})
zs = sorted({z for rows, _, _ in fields for _, z in rows})
width, depth = len(xs), len(zs)
scale = args.scale
pad, gap, header, footer = 16, 24, 40 if args.title else 18, 30
panel_w, panel_h = width * scale, depth * scale
image = Image.new("RGB",
                  (pad * 2 + panel_w * len(fields) + gap * (len(fields) - 1),
                   pad * 2 + header + panel_h + footer), BG)
draw = ImageDraw.Draw(image)
if args.title:
    draw.text((pad, pad), args.title, fill=INK)

low = min(field[1] for field in fields)
high = max(field[2] for field in fields)
span = max(1, high - low)

for index, (rows, _, _) in enumerate(fields):
    ox = pad + index * (panel_w + gap)
    oy = pad + header
    for zi, z in enumerate(zs):
        for xi, x in enumerate(xs):
            cell = rows.get((x, z))
            if cell is None:
                continue
            kind, feature, terrain, wet = cell
            if wet:
                colour = COL_WATER
            elif feature.startswith("route_"):
                colour = COL_ROUTE
            elif feature.startswith("poi_spur_"):
                colour = COL_SPUR
            elif feature.startswith("anchor_"):
                colour = COL_FIT
            else:
                shade = 40 + int(110 * (terrain - low) / span)
                colour = (shade, shade + 6, shade - 4 if shade > 4 else 0)
            # z grows north; draw north UP, so the row index is flipped.
            px, py = ox + xi * scale, oy + (depth - 1 - zi) * scale
            if scale == 1:
                image.putpixel((px, py), colour)
            else:
                draw.rectangle([px, py, px + scale - 1, py + scale - 1], colour)

    def to_pixel(x, z):
        return (ox + (x - xs[0]) * scale, oy + (zs[-1] - z) * scale)

    # The 512 envelope.
    a = to_pixel(ANCHOR_X - HALF, ANCHOR_Z + HALF)
    b = to_pixel(ANCHOR_X + HALF, ANCHOR_Z - HALF)
    draw.rectangle([a[0], a[1], b[0], b[1]], outline=COL_ENVELOPE)
    # The four gate passages, and the gate point in the middle of each.
    for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        gx, gz = ANCHOR_X + dx * HALF, ANCHOR_Z + dz * HALF
        if dx:
            start, end = to_pixel(gx, gz + PASSAGE), to_pixel(gx, gz - PASSAGE)
        else:
            start, end = to_pixel(gx - PASSAGE, gz), to_pixel(gx + PASSAGE, gz)
        draw.line([start, end], fill=COL_GATE, width=max(1, scale))
    draw.text((ox, oy + panel_h + 6), labels[index], fill=INK)

legend = ("orange route   brown POI spur   slate capital fitting   "
          "blue water   yellow gate passage   grey 512 envelope")
draw.text((pad, image.height - 16), legend, fill=INK)
args.output.parent.mkdir(parents=True, exist_ok=True)
image.save(args.output)
print("wrote", args.output, image.size)
