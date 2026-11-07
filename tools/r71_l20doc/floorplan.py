#!/usr/bin/env python3
"""Draw the proposed level-20 Expedition; no game data is read or written.

Run from any directory. Requires Python 3 and Pillow for the PNG;
--grid prints the same geometry as a small text grid using only the stdlib.
The coordinates are drawing guides, not a measured or buildable template.
"""

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/planning/round71-l20-floorplan.png"
EXTENT = 128
SCALE = 8
ORIGIN = (56, 170)

# Rectangles use exclusive upper bounds, in proposed node coordinates.
ROOMS = (
    ("0", "ARRIVAL", (8, 8, 32, 32), "#D1E2DD"),
    ("1", "CART BAY", (48, 8, 80, 40), "#E6DCC8"),
    ("2", "PROP ROOM", (96, 8, 120, 40), "#E6DCC8"),
    ("3", "SORTING FLOOR", (96, 64, 120, 120), "#E6DCC8"),
    ("4", "WORKING FACE", (48, 88, 80, 120), "#E9C8BB"),
    ("5", "STORE", (8, 88, 32, 120), "#D1E2DD"),
)
CORRIDORS = (
    (32, 16, 48, 24),
    (80, 16, 96, 24),
    (104, 40, 112, 64),
    (80, 104, 96, 112),
    (32, 104, 48, 112),
)
SCREEN = (104, 88, 120, 96)
ROOM_MARKS = (("0", 12, 12), ("1", 52, 12), ("2", 100, 12),
              ("3", 100, 68), ("4", 52, 92), ("5", 12, 92))
FEATURES = (
    ("S", 20, 28),
    ("a", 60, 28), ("g", 76, 36),
    ("b", 108, 28), ("j", 116, 36),
    ("c", 108, 76), ("d", 108, 108),
    ("B", 68, 108), ("D", 44, 108),
    ("C", 20, 108), ("E", 20, 116),
    ("g", 12, 100), ("g", 20, 100), ("g", 28, 100),
    ("g", 12, 116), ("j", 28, 108), ("j", 28, 116),
)


def inside(x, z, rectangle):
    x0, z0, x1, z1 = rectangle
    return x0 <= x < x1 and z0 <= z < z1


def text_grid():
    floors = [room[2] for room in ROOMS] + list(CORRIDORS)
    grid = [
        ["." if any(inside(x, z, r) for r in floors)
         and not inside(x, z, SCREEN) else "#"
         for x in range(4, EXTENT, 8)]
        for z in range(4, EXTENT, 8)
    ]
    for symbol, x, z in ROOM_MARKS + FEATURES:
        grid[z // 8][x // 8] = symbol
    return "\n".join("".join(row) for row in grid)


def render():
    from PIL import Image, ImageDraw, ImageFont

    image = Image.new("RGB", (1570, 1330), "#F7F3EB")
    draw = ImageDraw.Draw(image)
    ink, muted, rock = "#253B40", "#59676A", "#536367"

    # Pillow's bundled font keeps generation independent of system fonts.
    def font(size):
        return ImageFont.load_default(size=size)

    def label(position, value, size=20, fill=ink, anchor=None):
        draw.text(position, value, font=font(size), fill=fill, anchor=anchor)

    def point(x, z):
        return ORIGIN[0] + x * SCALE, ORIGIN[1] + z * SCALE

    def box(rectangle, fill):
        x0, z0, x1, z1 = rectangle
        p0, p1 = point(x0, z0), point(x1, z1)
        draw.rectangle((p0, (p1[0] - 1, p1[1] - 1)), fill=fill)

    def marker(symbol, x, z):
        px, py = point(x, z)
        if symbol in "gj":
            fill = "#9C6A0C" if symbol == "g" else "#287D69"
            draw.polygon([(px, py - 15), (px + 15, py),
                          (px, py + 15), (px - 15, py)], fill=fill)
            label((px, py), symbol, 17, "white", "mm")
        elif symbol == "D":
            draw.rectangle((px - 7, py - 32, px + 7, py + 31), fill="#8E4333")
            label((px, py - 49), "D", 20, "#8E4333", "mm")
        else:
            fill = ("#247568" if symbol in "SE" else
                    "#9C6A0C" if symbol == "C" else "#8E4333")
            radius = 24 if symbol == "B" else 21
            draw.ellipse((px - radius, py - radius, px + radius, py + radius),
                         fill=fill)
            label((px, py), symbol, 23, "white", "mm")

    def arrow(start, end):
        x0, y0 = point(*start)
        x1, y1 = point(*end)
        draw.line((x0, y0, x1, y1), fill=ink, width=3)
        dx, dy = x1 - x0, y1 - y0
        length = (dx * dx + dy * dy) ** 0.5
        ux, uy = dx / length, dy / length
        draw.polygon([(x1, y1),
                      (x1 - ux * 12 - uy * 6, y1 - uy * 12 + ux * 6),
                      (x1 - ux * 12 + uy * 6, y1 - uy * 12 - ux * 6)], fill=ink)

    label((56, 32), "THE STILLED SEAM", 40)
    label((56, 87), "Level 20 Expedition  /  three players  /  one main floor", 24)
    label((56, 125), "PROPOSAL - for review and user approval before building", 19, muted)

    box((0, 0, EXTENT, EXTENT), rock)
    for rectangle in CORRIDORS:
        box(rectangle, "#E6DCC8")
    for _, _, rectangle, fill in ROOMS:
        box(rectangle, fill)
    box(SCREEN, rock)

    # Light guide grid; no overworld direction is implied by this drawing.
    for n in range(0, EXTENT + 1, 16):
        x, y = point(n, n)
        draw.line((x, ORIGIN[1], x, ORIGIN[1] + EXTENT * SCALE),
                  fill="#8A9592", width=1)
        draw.line((ORIGIN[0], y, ORIGIN[0] + EXTENT * SCALE, y),
                  fill="#8A9592", width=1)

    for number, name, rectangle, _ in ROOMS:
        x, y = point(rectangle[0] + 2, rectangle[1] + 2)
        label((x, y), f"{number}  {name}", 17)
    for symbol, x, z in FEATURES:
        marker(symbol, x, z)
    for start, end in (((34, 20), (46, 20)), ((82, 20), (94, 20)),
                       ((108, 43), (108, 61)), ((94, 108), (82, 108)),
                       ((42, 108), (34, 108))):
        arrow(start, end)

    # The rock between the two rows carries the route summary, outside play.
    label(point(8, 53), "FOLLOW THE WORKING", 23, "#FFFFFF")
    label(point(8, 60), "0 > 1 > 2 > 3 > 4 > 5", 28, "#FFFFFF")
    label(point(8, 68), "All walking surfaces at the same height.", 20, "#F0EADF")
    label(point(8, 74), "Solid hull and screen. Dig marked nodes only.", 20, "#F0EADF")

    sx = 1120
    label((sx, 177), "THE ROUTE", 26)
    paragraphs = (
        (226, "0  Arrival", ["S: start / death return", "Safe gathering space."]),
        (325, "1  Cart bay", ["a: 4 normal spiders", "First Gold beyond the pack."]),
        (424, "2  Prop room", ["b: 2 normal spiders", "+ 1 elite golem; one Jade."]),
        (523, "3  Sorting floor", ["c and d: each 3 normal spiders", "+ 1 elite golem.", "Rock screen keeps pulls apart."]),
        (650, "4  Working face", ["B: Flintback, alone", "D opens when Flintback dies."]),
        (749, "5  Store", ["C: personal chest; E: exit", "4 Gold + 2 Jade nodes."]),
    )
    for y, title, lines in paragraphs:
        label((sx, y), title, 23)
        for index, line in enumerate(lines):
            label((sx, y + 34 + index * 27), line, 19, muted)

    draw.line((sx, 865, 1514, 865), fill="#C4CBC5", width=2)
    label((sx, 890), "g  Gold     j  Jade", 23)
    label((sx, 927), "Eight shared T2 nodes in all.", 19, muted)
    label((sx, 960), "12 normal / 3 elite / 1 boss", 21)
    label((sx, 1000), "Chosen mob level: 20-29", 21)
    label((sx, 1040), "Target: 10-20 minutes", 21)
    label((sx, 1080), "No respawns, building or mounts.", 19, muted)
    label((sx, 1115), "Both waystones return to capital.", 19, muted)

    label((56, 1222), "128 x 128 nodes / height about 32 - unmeasured guide", 23)
    label((56, 1259), "Shorten links and service rooms first; keep room to fight and separate packs.", 19, muted)
    label((56, 1291), "Generated by tools/r71_l20doc/floorplan.py", 16, muted)
    image.save(OUTPUT, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grid", action="store_true", help="print the matching text grid only")
    args = parser.parse_args()
    if args.grid:
        print(text_grid())
    else:
        render()
        print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
