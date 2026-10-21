#!/usr/bin/env python3
"""Original CC0 armor inventory art. Deterministic Python + Pillow only.

Run from any directory: python3 -B art/drop-01/src/paint.py
Writes only 72 reference-palette icons and notes.md in each of p1 and p2.
The picked tier map is read, never modified. No source artwork is sampled.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GAME = Path.home() / "projects/grudgelands"
PICKED = GAME / "tools/r54_art/art"
# r54_art adaptation (Round 55 lane ICONS): assemble.py passes --art <dir of the picked tiers.json>.
if "--art" in sys.argv:
    PICKED = Path(sys.argv[sys.argv.index("--art") + 1])
LINES = ("metal", "leather", "cloth")
SLOTS = ("head", "chest", "legs", "feet")
# h/l/m/d/e/o: material, s/t: leather, A/a: prefix, B/b: suffix.
HEX = dict(zip("hlmdeostAaBbG", (
    "F0F0F0", "C8C8C8", "A0A0A0", "787878", "505050", "282828",
    "A07850", "6E5034", "E07070", "B04848", "70A0E0", "4870B0", "FFC040")))
COLORS = {k: tuple(bytes.fromhex(v)) + (255,) for k, v in HEX.items()}


class Icon:
    """Integer polygons; one outer edge, flat hand-placed interior masses."""
    def __init__(self, points, base="m"):
        self.im = Image.new("RGBA", (16, 16))
        mask = Image.new("1", (16, 16))
        ImageDraw.Draw(mask).polygon(points, fill=1)
        self.inside = set()
        for y in range(16):
            for x in range(16):
                if not mask.getpixel((x, y)):
                    continue
                edge = any(not (0 <= x+dx < 16 and 0 <= y+dy < 16)
                           or not mask.getpixel((x+dx, y+dy))
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                self.im.putpixel((x, y), COLORS["o" if edge else base])
                if not edge:
                    self.inside.add((x, y))

    def paint(self, kind, coords, color):
        mask = Image.new("1", (16, 16))
        getattr(ImageDraw.Draw(mask), kind)(coords, fill=1)
        for x, y in self.inside:
            if mask.getpixel((x, y)):
                self.im.putpixel((x, y), COLORS[color])
        return self

    def rect(self, x0, y0, x1, y1, c):
        return self.paint("rectangle", (x0, y0, x1, y1), c)

    def poly(self, points, c):
        return self.paint("polygon", points, c)

    def line(self, points, c):
        return self.paint("line", points, c)

    def dot(self, x, y, c):
        return self.rect(x, y, x, y, c)

    def cut(self, points):
        ImageDraw.Draw(self.im).polygon(points, fill=(0, 0, 0, 0))
        for y in range(16):
            for x in range(16):
                if self.im.getpixel((x, y))[3] == 0:
                    self.inside.discard((x, y))
        return self


def front_head(line, t):
    if line == "metal":
        # A broad cap with an open nasal, then a single shut visor.
        crown = 2 if t <= 2 else 1
        f = Icon([(4, crown), (11, crown), (14, 4), (14, 12), (12, 14),
                  (3, 14), (1, 12), (1, 4)])
        f.rect(2, 2, 13, 5, "l").rect(4, 2, 9, 2, "h")
        f.rect(12, 5, 13, 12, "d")
        f.rect(2, 6, 13, 12, "A").rect(11, 7, 13, 12, "a")
        if t <= 4:
            f.cut([(4, 7), (11, 7), (11, 11), (10, 12), (5, 12), (4, 11)])
            # The nasal is deliberately two pixels wide at native size.
            ImageDraw.Draw(f.im).rectangle((7, 6, 8, 8), fill=COLORS["l"])
            if t >= 2:
                f.rect(2, 7, 3, 11, "m").rect(12, 7, 13, 11, "d")
            if t >= 3:
                f.rect(2, 10, 3, 12, "l").rect(12, 10, 13, 12, "m")
            if t >= 4:
                f.rect(4, 3, 11, 3, "h")
        else:
            f.rect(2, 6, 13, 10, "m").rect(3, 7, 12, 7, "o")
            f.rect(3, 8, 11, 8, "l")
            f.rect(3, 11, 12, 12, "A")
            if t == 6:
                f.rect(7, 2, 8, 10, "l").rect(7, 3, 8, 4, "B")
        f.rect(6, 4, 9, 4, "B")
        if t == 6:
            f.rect(5, 3, 10, 3, "B")
        return f
    if line == "leather":
        # Tapered sewn hood, with no shoulder drape: distinct from cloth.
        f = Icon([(5, 1), (10, 1), (13, 4), (13, 10), (11, 13),
                  (8, 14), (6, 14), (3, 12), (2, 9), (2, 4)])
        f.poly([(4, 3), (6, 2), (10, 2), (11, 4), (4, 5)], "l")
        f.rect(11, 5, 12, 11, "d")
        f.poly([(4, 5), (10, 5), (11, 6), (11, 11), (9, 12), (5, 11)], "A")
        f.cut([(5, 6), (9, 6), (10, 7), (10, 10), (8, 11), (5, 10)])
        if t >= 2:
            f.rect(4, 4, 10, 4, "s")
        if t >= 3:
            f.rect(3, 6, 3, 10, "s").rect(4, 11, 5, 11, "s")
        if t >= 4:
            f.rect(4, 3, 10, 4, "l").rect(3, 5, 4, 8, "m")
        if t >= 5:
            f.line([(4, 3), (6, 4), (8, 3), (10, 4)], "m")
        if t == 6:
            # The selected final hood has a hide dust wrap below the eyes.
            ImageDraw.Draw(f.im).rectangle((5, 9, 10, 10), fill=COLORS["m"])
            ImageDraw.Draw(f.im).rectangle((5, 11, 9, 11), fill=COLORS["A"])
        f.rect(6, 12, 8, 12, "B")
        return f
    # A pointed soft hood broadens into a short shoulder cowl.
    f = Icon([(7, 1), (9, 2), (12, 4), (12, 10), (14, 13),
              (12, 14), (3, 14), (1, 13), (3, 10), (3, 4)])
    f.poly([(7, 2), (10, 4), (9, 6), (4, 7), (4, 4)], "l")
    f.poly([(10, 5), (11, 6), (11, 10), (13, 13), (9, 13)], "d")
    f.poly([(5, 5), (9, 5), (10, 6), (10, 10), (8, 12), (5, 11), (4, 9)], "A")
    f.cut([(6, 6), (8, 6), (9, 7), (9, 9), (8, 10), (6, 10), (5, 9), (5, 7)])
    f.rect(6, 12, 8, 12, "B")
    if t >= 2:
        f.rect(4, 11, 5, 12, "A")
    if t >= 3:
        f.rect(5, 13, 10, 13, "A")
    if t >= 4:
        f.rect(6, 12, 9, 12, "B")
    if t >= 5:
        f.rect(5, 12, 10, 12, "B")
    if t == 6:
        f.line([(6, 4), (7, 3), (8, 4)], "B")
    return f


def front_chest(line, t):
    if line == "metal":
        # Connected shoulders, no floating hand/bracer fragments.
        shoulder = 2 if t == 1 else 1
        shoulder_y = 3 if t <= 3 else 2
        f = Icon([(shoulder, shoulder_y), (5, 1), (6, 3), (9, 3), (10, 1),
                  (15-shoulder, shoulder_y), (15-shoulder, 7 if t < 3 else 10),
                  (12, 10 if t >= 3 else 7), (11, 14), (4, 14),
                  (3, 10 if t >= 3 else 7), (shoulder, 7 if t < 3 else 10)])
        f.rect(2, 3, 13, 5, "l").rect(3, 3, 5, 3, "h")
        f.poly([(9, 6), (12, 6), (11, 12), (9, 12)], "d")
        f.rect(5, 3, 10, 4, "A").rect(5, 12, 10, 13, "A")
        if t >= 2:
            f.rect(4, 11, 11, 11, "s")
            f.rect(2, 4, 4, 6, "l").rect(11, 4, 13, 6, "m")
        if t >= 3:
            f.rect(2, 8, 3, 9, "l").rect(12, 8, 13, 9, "m")
        if t >= 4:
            f.rect(2, 3, 4, 4, "h").rect(11, 3, 13, 4, "l")
        if t >= 5:
            f.rect(5, 7, 10, 8, "l")
        if t == 6:
            f.rect(2, 4, 2, 8, "l").rect(13, 4, 13, 8, "m")
            f.rect(7, 5, 8, 10, "l")
        f.rect(6, 11, 9, 11, "B")
        return f
    if line == "leather":
        y = 8 if t < 3 else 10
        if t < 3:
            points = [(3, 1), (5, 1), (6, 3), (9, 3), (10, 1), (12, 1),
                      (13, 4), (12, 6), (12, 13), (10, 14), (5, 14),
                      (3, 13), (3, 6), (2, 4)]
        else:
            points = [(2 if t < 5 else 1, 3), (5, 1), (6, 3), (9, 3), (10, 1),
                      (13 if t < 5 else 14, 3), (14, 5), (13, y), (11, y),
                      (12, 13), (10, 14), (5, 14), (3, 13), (4, y), (2, y), (1, 5)]
        f = Icon(points)
        f.poly([(3, 3), (5, 2), (10, 3), (10, 5), (4, 6)], "l")
        f.rect(10, 6, 12, 13, "d")
        f.rect(6, 3, 9, 5, "A").rect(5, 12, 10, 13, "A")
        if t >= 2:
            f.rect(4, 11, 11, 11, "s")
        if t >= 3:
            f.rect(2, 8, 3, 9, "A").rect(12, 8, 13, 9, "a")
        if t == 4:
            f.rect(5, 6, 10, 9, "m").rect(5, 6, 10, 6, "l")
        if t >= 5:
            # One large scalloped yoke is the shorthand for the scale field.
            f.poly([(3, 3), (5, 3), (7, 5), (9, 3), (12, 3),
                    (12, 5), (10, 6), (8, 5), (6, 6), (3, 5)], "l")
        if t == 6:
            f.poly([(4, 10), (7, 11), (11, 10), (10, 12), (5, 12)], "l")
        # A single continuous hide sling, with one connected clasp.
        f.poly([(10, 3), (11, 4), (5, 11), (4, 10)], "t" if t < 5 else "s")
        f.rect(7, 6, 8, 7, "B")
        return f
    f = Icon([(5, 1), (6, 3), (9, 3), (10, 1), (12, 3), (14, 8),
              (14, 10), (11, 10), (11, 12), (12, 14), (3, 14),
              (4, 12), (4, 10), (1, 10), (1, 8), (3, 3)])
    f.poly([(4, 3), (5, 2), (6, 5), (5, 10), (2, 9)], "l")
    f.poly([(10, 3), (12, 5), (13, 9), (10, 12), (9, 12)], "d")
    f.rect(6, 3, 9, 13, "A").rect(9, 6, 9, 13, "a")
    if t >= 2:
        f.rect(4, 11, 11, 11, "A")
    if t >= 3:
        f.rect(2, 9, 3, 9, "A").rect(12, 9, 13, 9, "a")
    if t >= 4:
        f.rect(6, 5, 9, 5, "B")
    if t >= 5:
        f.rect(5, 13, 10, 13, "B")
    if t == 6:
        f.line([(6, 7), (7, 8), (8, 8), (9, 7)], "B")
    f.rect(6, 5, 8, 5, "B")
    return f


def front_legs(line, t):
    if line == "cloth" and t >= 3:
        f = Icon([(5, 1), (10, 1), (11, 5), (14, 14), (1, 14), (4, 5)])
        f.poly([(5, 2), (7, 2), (5, 13), (3, 13)], "l")
        f.poly([(10, 3), (10, 7), (13, 13), (10, 13)], "d")
        f.rect(7, 2, 9, 13, "A").rect(9, 6, 9, 13, "a")
        f.rect(6, 12, 9, 12, "B")
        if t >= 4:
            f.rect(5, 12, 10, 12, "B")
        if t >= 5:
            f.rect(3, 12, 12, 12, "B")
        if t == 6:
            f.line([(7, 7), (8, 8), (9, 7)], "B")
        return f
    if line == "metal" and t >= 5:
        f = Icon([(3, 1), (12, 1), (13, 4), (13, 14), (9, 14),
                  (9, 12), (6, 12), (6, 14), (2, 14), (2, 4)])
        f.rect(3, 2, 12, 8, "m").rect(3, 3, 12, 4, "l")
        f.rect(11, 5, 12, 11, "d")
        f.rect(4, 9, 11, 11, "A").rect(10, 9, 11, 11, "a")
        f.rect(4, 12, 5, 13, "l").rect(10, 12, 11, 13, "m")
        if t == 6:
            # Picked T6 has a vertical tabard instead of the T5 plated apron.
            f.rect(6, 4, 9, 11, "A").rect(9, 5, 9, 11, "a")
            f.rect(4, 5, 5, 9, "l")
        f.rect(6, 2, 9, 2, "B")
        return f
    if line == "leather" and t == 6:
        f = Icon([(4, 1), (11, 1), (13, 5), (13, 13), (11, 14),
                  (9, 14), (9, 12), (6, 12), (6, 14), (3, 14), (2, 12), (2, 5)])
        f.rect(3, 3, 12, 7, "m").rect(4, 3, 11, 4, "l")
        f.line([(4, 6), (6, 7), (8, 6), (10, 7), (11, 6)], "l")
        f.rect(4, 8, 11, 11, "A").rect(10, 8, 11, 11, "a")
        f.rect(6, 2, 9, 2, "B")
        return f
    # Three separate cuts: straight plate, narrow hide, gathered soft trousers.
    if line == "metal":
        points = [(3, 1), (12, 1), (13, 2), (13, 13), (12, 14), (9, 14),
                  (9, 8), (6, 8), (6, 14), (3, 14), (2, 13), (2, 2)]
    elif line == "leather":
        points = [(4, 1), (11, 1), (12, 4), (11, 14), (9, 14),
                  (8, 8), (7, 8), (6, 14), (4, 14), (3, 4)]
        if t >= 3:
            points = [(4, 1), (11, 1), (13, 4), (13, 13), (10, 14),
                      (9, 14), (8, 8), (7, 8), (6, 14), (3, 14), (2, 4)]
    else:
        points = [(4, 1), (11, 1), (13, 4), (13, 8), (11, 10), (11, 14),
                  (9, 14), (8, 8), (7, 8), (6, 14), (4, 14), (4, 10), (2, 8), (2, 4)]
    f = Icon(points)
    f.rect(3, 2, 12, 4, "A").rect(11, 2, 12, 4, "a")
    f.poly([(3, 5), (6, 5), (5, 12), (3, 12)], "l")
    f.rect(10, 5, 11, 12, "m").rect(11, 7, 12, 13, "d")
    if line == "metal":
        if t >= 2:
            f.rect(4, 5, 5, 5, "h")
        if t >= 3:
            f.rect(3, 10, 5, 11, "l").rect(10, 10, 12, 11, "l")
        if t >= 4:
            f.rect(3, 10, 5, 10, "h").rect(10, 10, 12, 10, "h")
    elif line == "leather":
        if t == 1:
            f.rect(3, 5, 12, 9, "A").rect(10, 6, 12, 9, "a")
            f.rect(4, 10, 5, 11, "m").rect(10, 10, 11, 11, "m")
        if t >= 2:
            f.rect(4, 5, 5, 9, "m").rect(10, 5, 11, 9, "m")
        if t >= 3:
            # Rear coat tails run beside, rather than across, the trouser gap.
            f.rect(3, 5, 3, 12, "s").rect(11, 5, 12, 12, "m")
            f.rect(12, 5, 12, 12, "s")
        if t >= 4:
            f.rect(4, 6, 5, 6, "l").rect(10, 6, 11, 6, "l")
        if t >= 5:
            f.rect(3, 10, 5, 11, "l").rect(10, 10, 12, 11, "m")
    else:
        f.poly([(3, 5), (5, 5), (5, 12), (4, 10), (3, 8)], "l")
        f.poly([(10, 5), (12, 5), (11, 8), (10, 12)], "m")
        if t == 2:
            f.rect(3, 12, 5, 12, "A").rect(10, 12, 12, 12, "a")
    f.rect(6, 3, 9, 3, "B")
    return f


def front_feet(line, t):
    # A full-height side profile; material controls the shaft and toe contour.
    if line == "metal":
        pts = [(3, 1), (10, 1), (10, 9), (14, 11), (14, 14), (2, 14), (2, 11), (3, 9)]
    elif line == "leather":
        pts = [(2, 1), (10, 1), (10, 4), (9, 5), (9, 9), (13, 11),
               (14, 13), (13, 14), (2, 14), (1, 12), (3, 9), (3, 5), (2, 4)]
    else:
        pts = [(4, 2), (10, 2), (10, 4), (9, 5), (9, 8), (12, 10),
               (14, 11), (14, 13), (12, 14), (2, 14), (1, 13), (2, 11), (4, 8)]
    f = Icon(pts)
    f.rect(3, 2, 9, 3, "A").rect(8, 2, 9, 3, "a")
    f.poly([(4, 4), (6, 4), (6, 10), (10, 12), (3, 12), (4, 9)], "l")
    f.rect(8, 5, 9, 9, "d").rect(3, 13, 13, 13, "d")
    f.rect(6, 6, 8, 6, "B")
    if line == "metal":
        f.rect(4, 4, 6, 4, "h")
        if t >= 2:
            f.rect(7, 7, 8, 9, "m")
        if t >= 3:
            f.rect(4, 10, 9, 10, "l")
        if t >= 4:
            f.rect(10, 11, 13, 11, "h").rect(10, 12, 13, 12, "l")
        if t >= 5:
            f.rect(6, 6, 8, 7, "B")
        if t == 6:
            f.rect(6, 4, 6, 10, "l")
    elif line == "leather":
        f.rect(7, 5, 8, 10, "s")
        if t >= 2:
            f.rect(3, 4, 9, 4, "s")
        if t >= 3:
            f.rect(3, 4, 9, 5, "l")
        if t >= 4:
            f.rect(4, 10, 9, 11, "m")
        if t >= 5:
            f.line([(6, 8), (7, 9), (8, 8)], "l")
        if t == 6:
            f.rect(6, 6, 8, 7, "B")
        else:
            f.rect(6, 6, 8, 6, "B")
    else:
        f.rect(5, 4, 8, 4, "A")
        if t <= 2:
            f.rect(4, 5, 8, 10, "s")
            f.rect(6, 6, 8, 6, "B")
        if t >= 2:
            f.rect(4, 4, 8, 4, "A")
        if t >= 3:
            f.poly([(5, 4), (7, 4), (6, 9), (4, 10)], "l")
            f.rect(6, 6, 8, 6, "B")
        if t >= 4:
            f.rect(5, 11, 9, 11, "B")
        if t >= 5:
            f.rect(5, 11, 11, 11, "B")
        if t == 6:
            f.line([(5, 6), (6, 7), (7, 6)], "B")
    return f


def turned_head(line, t):
    if line == "metal":
        f = Icon([(5, 1), (10, 1), (13, 3), (14, 6), (13, 7), (13, 12),
                  (10, 14), (3, 13), (1, 10), (1, 5), (3, 2)])
        # Large lit shell on the left; the face looks to the right.
        f.poly([(4, 2), (9, 2), (11, 4), (10, 7), (2, 6)], "l")
        f.line([(4, 2), (8, 2)], "h")
        f.poly([(2, 7), (6, 8), (6, 12), (3, 12)], "m")
        f.poly([(7, 6), (12, 5), (12, 12), (9, 13), (6, 12)], "A")
        if t < 5:
            f.cut([(9, 7), (13, 7), (13, 10), (10, 11), (9, 10)])
            if t >= 2:
                f.rect(7, 8, 8, 11, "m")
            if t >= 3:
                f.rect(7, 8, 8, 10, "l")
            if t >= 4:
                f.line([(3, 4), (5, 3), (9, 3)], "h")
        else:
            f.poly([(8, 6), (13, 5), (13, 11), (10, 12), (8, 10)], "m")
            f.line([(8, 7), (12, 6)], "o")
            f.line([(8, 8), (12, 7)], "l")
            if t == 6:
                f.line([(10, 3), (11, 4), (11, 11)], "l")
        f.rect(6, 5, 7, 6, "B")
        if t == 6:
            f.rect(6, 4, 8, 4, "B")
        return f
    if line == "leather":
        f = Icon([(5, 1), (9, 1), (12, 3), (14, 6), (12, 8),
                  (12, 12), (9, 14), (5, 13), (2, 10), (1, 6), (3, 3)])
        f.poly([(5, 2), (8, 2), (11, 4), (8, 7), (2, 7), (3, 4)], "l")
        f.poly([(8, 5), (11, 4), (13, 6), (11, 8), (11, 11), (9, 13), (7, 11)], "A")
        f.cut([(10, 6), (12, 6), (11, 8), (11, 10), (9, 11), (9, 7)])
        f.line([(4, 4), (4, 8), (5, 10)], "s")
        if t >= 2:
            f.rect(6, 11, 7, 12, "s")
        if t >= 3:
            f.line([(8, 4), (11, 4), (12, 5)], "s")
        if t >= 4:
            f.poly([(4, 3), (7, 2), (10, 4), (8, 5), (4, 5)], "l")
        if t >= 5:
            f.line([(4, 4), (6, 5), (8, 4), (10, 5)], "m")
        if t == 6:
            ImageDraw.Draw(f.im).polygon([(9, 9), (11, 8), (11, 10), (9, 11)], fill=COLORS["m"])
        f.rect(6, 11, 7, 12, "B")
        return f
    f = Icon([(6, 1), (9, 2), (12, 4), (13, 6), (12, 7), (11, 10),
              (14, 13), (11, 14), (3, 14), (1, 12), (3, 9), (2, 6), (4, 3)])
    f.poly([(6, 2), (9, 3), (10, 5), (7, 8), (3, 8), (3, 5)], "l")
    f.poly([(7, 5), (11, 5), (12, 6), (10, 11), (8, 12), (6, 10)], "A")
    f.cut([(9, 6), (11, 6), (10, 9), (8, 10), (8, 7)])
    f.poly([(3, 10), (5, 9), (8, 12), (12, 13), (4, 13)], "m")
    f.line([(5, 10), (8, 12), (10, 12)], "A")
    f.rect(7, 12, 9, 12, "B")
    if t >= 2:
        f.rect(4, 12, 6, 12, "l")
    if t >= 3:
        f.line([(4, 11), (7, 13), (10, 13)], "A")
    if t >= 4:
        f.rect(6, 12, 9, 12, "B")
    if t >= 5:
        f.line([(5, 11), (7, 12), (10, 12)], "B")
    if t == 6:
        f.line([(5, 4), (6, 3), (7, 4)], "B")
    return f


def turned_chest(line, t):
    if line == "metal":
        left = 2 if t == 1 else 1
        shoulder_y = 3 if t < 4 else 2
        f = Icon([(left, 4), (4, 2), (6, 2), (7, 4), (9, 4), (10, 2), (12, 2),
                  (14, shoulder_y), (14, 8 if t < 3 else 10), (12, 10), (12, 13),
                  (5, 14), (3, 12), (3, 8), (left, 7)])
        f.poly([(3, 4), (6, 3), (9, 5), (8, 9), (4, 10)], "l")
        f.poly([(9, 5), (13, 4), (12, 11), (9, 12)], "m")
        f.rect(12, 7, 13, 10, "d")
        f.poly([(6, 3), (7, 4), (10, 3), (10, 4), (8, 5), (6, 4)], "A")
        f.poly([(4, 11), (8, 12), (11, 11), (11, 12), (6, 13), (4, 12)], "A")
        if t >= 2:
            f.rect(2, 4, 4, 5, "l").rect(12, 3, 13, 4, "l")
        if t >= 3:
            f.rect(2, 5, 4, 5, "h").rect(12, 8, 13, 9, "m")
        if t >= 4:
            f.rect(2, 4, 4, 4, "h").rect(12, 3, 13, 3, "h")
        if t >= 5:
            f.line([(4, 9), (8, 10), (11, 9)], "l")
        if t == 6:
            f.line([(8, 5), (8, 11)], "h")
        f.rect(7, 11, 9, 11, "B")
        return f
    if line == "leather":
        if t < 3:
            points = [(3, 3), (5, 2), (6, 2), (7, 4), (9, 4), (10, 2), (12, 2),
                      (13, 4), (12, 6), (12, 12), (10, 14), (4, 14),
                      (3, 12), (3, 6), (2, 5)]
        else:
            points = [(2, 4), (4, 2), (6, 2), (7, 4), (9, 4), (10, 2), (12, 2),
                      (14, 3 if t >= 5 else 5), (13, 11), (11, 10), (12, 13),
                      (5, 14), (3, 12), (3, 9), (1, 8)]
        f = Icon(points)
        f.poly([(3, 4), (6, 3), (10, 5), (7, 7), (4, 8)], "l")
        f.poly([(10, 4), (12, 4), (12, 10), (10, 12), (8, 12)], "d")
        f.poly([(6, 3), (7, 4), (10, 3), (9, 6), (7, 6)], "A")
        f.poly([(4, 12), (8, 12), (10, 11), (11, 12), (6, 13)], "A")
        if t >= 2:
            f.line([(4, 11), (8, 11), (11, 10)], "s")
        if t >= 3:
            f.rect(2, 7, 3, 8, "A").rect(12, 9, 13, 10, "a")
        if t >= 4:
            f.poly([(5, 6), (9, 6), (9, 9), (5, 10)], "m")
        if t >= 5:
            f.poly([(3, 4), (5, 3), (7, 5), (9, 4), (12, 3), (12, 5),
                    (10, 6), (8, 5), (6, 6), (4, 5)], "l")
        if t == 6:
            f.line([(4, 10), (6, 11), (8, 10), (10, 11)], "l")
        f.poly([(11, 3), (12, 4), (5, 12), (4, 11)], "t" if t < 5 else "s")
        f.rect(7, 7, 8, 8, "B")
        return f
    f = Icon([(5, 2), (7, 4), (9, 4), (11, 2), (13, 4), (14, 10),
              (11, 11), (12, 13), (5, 14), (3, 13), (4, 10), (1, 9), (2, 5)])
    f.poly([(4, 3), (6, 3), (7, 6), (4, 10), (2, 8)], "l")
    f.poly([(10, 4), (12, 5), (13, 9), (10, 12), (9, 11)], "d")
    # Center stole follows the turned torso; it is not an added diagonal sash.
    f.poly([(7, 3), (9, 3), (10, 6), (8, 13), (5, 13), (7, 7)], "A")
    f.line([(9, 6), (7, 13)], "a")
    if t >= 2:
        f.line([(4, 11), (7, 12), (10, 11)], "A")
    if t >= 3:
        f.line([(2, 8), (4, 9)], "A").rect(12, 9, 13, 9, "a")
    if t >= 4:
        f.line([(7, 5), (9, 5), (9, 6)], "B")
    if t >= 5:
        f.rect(5, 12, 8, 12, "B")
    if t == 6:
        f.line([(6, 8), (7, 9), (8, 8)], "B")
    f.rect(7, 5, 9, 5, "B")
    return f


def turned_legs(line, t):
    if line == "cloth" and t >= 3:
        f = Icon([(6, 1), (8, 1), (11, 2), (11, 6), (14, 13), (10, 14), (1, 13), (4, 6)])
        f.poly([(6, 2), (8, 3), (6, 12), (2, 12)], "l")
        f.poly([(10, 3), (10, 7), (13, 12), (10, 13), (8, 12)], "d")
        f.poly([(8, 3), (10, 3), (9, 8), (8, 13), (5, 12)], "A")
        f.line([(9, 7), (7, 12)], "a")
        f.rect(5, 11, 8, 11, "B")
        if t >= 4:
            f.line([(4, 11), (7, 12), (9, 11)], "B")
        if t >= 5:
            f.line([(3, 11), (7, 12), (11, 11)], "B")
        if t == 6:
            f.line([(7, 6), (8, 7), (9, 6)], "B")
        return f
    if (line == "metal" and t >= 5) or (line == "leather" and t == 6):
        f = Icon([(4, 1), (7, 1), (11, 2), (13, 5), (13, 13), (10, 14),
                  (8, 13), (8, 12), (6, 14), (2, 13), (2, 5)])
        f.poly([(4, 3), (8, 4), (7, 8), (3, 8)], "l")
        f.poly([(9, 3), (11, 3), (12, 11), (9, 12)], "d")
        f.poly([(3, 8), (7, 9), (11, 8), (11, 11), (7, 12), (3, 11)], "A")
        if line == "metal" and t == 6:
            f.poly([(7, 4), (9, 4), (10, 10), (7, 11), (5, 10)], "A")
        if line == "leather":
            f.line([(3, 6), (5, 7), (7, 6), (9, 7), (11, 6)], "l")
        f.rect(6, 3, 8, 3, "B")
        return f
    # Staggered hems, three material cuts, and an unmistakable trouser gap.
    if line == "metal":
        points = [(4, 1), (7, 1), (12, 2), (13, 5), (12, 13), (9, 13),
                  (8, 8), (7, 8), (6, 14), (2, 14), (2, 5)]
    elif line == "leather":
        points = [(5, 1), (7, 1), (11, 2), (12, 5), (11, 13), (9, 13),
                  (8, 8), (7, 9), (6, 14), (3, 14), (3, 5)]
        if t >= 3:
            points = [(4, 1), (7, 1), (11, 2), (13, 5), (13, 13), (10, 14),
                      (9, 13), (8, 8), (7, 9), (6, 14), (2, 14), (2, 5)]
    else:
        points = [(5, 1), (8, 1), (11, 2), (13, 4), (13, 7), (11, 9), (11, 13),
                  (9, 13), (8, 8), (7, 9), (6, 14), (3, 14), (3, 10), (1, 7), (2, 4)]
    f = Icon(points)
    f.poly([(3, 3), (6, 2), (11, 3), (12, 5), (3, 5)], "A")
    f.poly([(3, 5), (7, 5), (5, 13), (3, 13)], "l")
    f.rect(10, 6, 11, 11, "m").rect(11, 7, 12, 12, "d")
    if line == "metal":
        if t >= 2:
            f.rect(3, 5, 5, 5, "h")
        if t >= 3:
            f.rect(3, 10, 5, 11, "l").rect(10, 9, 11, 10, "l")
        if t >= 4:
            f.rect(3, 10, 5, 10, "h").rect(10, 9, 11, 9, "h")
    elif line == "leather":
        if t == 1:
            f.rect(3, 5, 6, 9, "A").rect(10, 5, 11, 8, "a")
        if t >= 2:
            f.rect(4, 6, 5, 9, "m")
        if t >= 3:
            f.rect(11, 5, 12, 11, "s")
        if t >= 4:
            f.rect(3, 6, 5, 6, "l")
        if t >= 5:
            f.rect(3, 10, 5, 11, "l").rect(10, 9, 11, 10, "l")
    else:
        f.rect(3, 5, 4, 11, "l")
        if t == 2:
            f.rect(3, 12, 5, 12, "A").rect(10, 11, 11, 11, "a")
    f.rect(6, 3, 8, 3, "B")
    return f


def turned_feet(line, t):
    if line == "metal":
        pts = [(4, 1), (8, 1), (11, 2), (11, 9), (13, 11), (13, 13),
               (9, 14), (2, 13), (2, 11), (4, 8)]
    elif line == "leather":
        pts = [(3, 1), (7, 1), (11, 2), (12, 4), (10, 5), (10, 9), (12, 11),
               (12, 13), (8, 14), (2, 13), (1, 11), (4, 8), (4, 5), (3, 4)]
    else:
        pts = [(5, 1), (8, 1), (11, 2), (11, 4), (10, 5), (9, 8), (12, 10),
               (13, 12), (10, 14), (3, 14), (1, 12), (1, 10), (4, 7)]
    f = Icon(pts)
    f.poly([(4, 2), (10, 3), (10, 4), (5, 4)], "A")
    f.poly([(5, 5), (8, 5), (7, 9), (10, 12), (3, 12), (3, 10)], "l")
    f.poly([(9, 5), (10, 5), (10, 9), (12, 11), (11, 12), (8, 9)], "d")
    f.rect(6, 6, 8, 6, "B")
    if line == "metal":
        f.rect(5, 5, 7, 5, "h")
        if t >= 2:
            f.rect(7, 8, 8, 9, "m")
        if t >= 3:
            f.line([(3, 10), (7, 10), (9, 11)], "l")
        if t >= 4:
            f.rect(3, 11, 8, 11, "h")
        if t >= 5:
            f.rect(6, 6, 8, 7, "B")
        if t == 6:
            f.line([(7, 4), (7, 9), (9, 10)], "l")
    elif line == "leather":
        f.line([(5, 5), (5, 8), (3, 10)], "s")
        if t >= 2:
            f.line([(4, 4), (9, 5)], "s")
        if t >= 3:
            f.line([(4, 4), (9, 5)], "l")
        if t >= 4:
            f.rect(4, 10, 8, 10, "m")
        if t >= 5:
            f.line([(6, 8), (7, 9), (8, 8)], "l")
        if t == 6:
            f.rect(6, 6, 8, 7, "B")
    else:
        f.rect(5, 4, 9, 4, "A")
        if t <= 2:
            f.rect(5, 5, 8, 9, "s").rect(6, 6, 8, 6, "B")
        if t >= 2:
            f.line([(5, 4), (9, 5)], "A")
        if t >= 3:
            f.line([(6, 5), (5, 9), (3, 10)], "l")
            f.rect(6, 6, 8, 6, "B")
        if t >= 4:
            f.rect(4, 11, 7, 11, "B")
        if t >= 5:
            f.rect(3, 11, 9, 11, "B")
        if t == 6:
            f.line([(6, 6), (7, 7), (8, 6)], "B")
    return f


IDEAS = {
    "p1": "Cut-paper heraldry: broad frontal armor and a side-profile boot turn each slot into a compact emblem. Plate is square and bevelled, hide tapers around its sling and sewn hood, and cloth opens into bell sleeves and a draped cowl. Later tiers enlarge one plate, binding or hem instead of accumulating little seams.",
    "p2": "Equipment in the hand: the helmet, torso, legs and boot all turn slightly to the right, with a broad lit face and one quiet return plane. Staggered hems and an open side of the hood make the silhouette do more of the drawing. Rank grows through a larger connected clasp or bound edge, with the picked final aprons and tabards kept intact.",
}
STEPS = {
    "metal/head": "T1 open cap and coif; T2 cheek plates; T3 longer cheeks; T4 broad crown light; T5 one closed visor; T6 raised central keel and brow fitting.",
    "metal/chest": "T1 plain cuirass; T2 connected shoulder plates; T3 deeper arm coverage; T4 brighter reinforced shoulders; T5 broad belly plate; T6 central keel and shoulder finish.",
    "metal/legs": "T1 paired thigh plates; T2 brighter upper edge; T3 knee cops; T4 pale cop tops; T5 broad armored apron over lining; T6 vertical textile tabard between plate rails.",
    "metal/feet": "T1 open cuff and plain greave; T2 fuller instep; T3 broad ankle plane; T4 bright toe cap; T5 enlarged fitting; T6 keeled shin.",
    "leather/head": "T1 lined pointed hood; T2 binding; T3 extended sewn edge; T4 broad hide brow; T5 one scalloped crown fold; T6 lower-face dust wrap.",
    "leather/chest": "T1 hide jerkin and one diagonal sling; T2 belt; T3 cuffed sleeves; T4 smooth hardened insert; T5 one scalloped shoulder yoke; T6 second broad scale edge near the hem.",
    "leather/legs": "T1 patched cloth trousers; T2 hide thigh patches; T3 rear-tail binding beside the legs; T4 reinforced patch tops; T5 knee caps; T6 scalloped upper skirt and long textile lining.",
    "leather/feet": "T1 sewn boot; T2 bound cuff; T3 turned cuff; T4 reinforced instep; T5 one folded hide insert; T6 larger clasp.",
    "cloth/head": "T1 soft hood and cowl; T2 fuller fold; T3 extended lining; T4 wider clasp; T5 continuous short clasp band; T6 one crown stitch.",
    "cloth/chest": "T1 bell sleeves and central stole; T2 sash; T3 bound cuffs; T4 wider stole bar; T5 lower stole trim; T6 one branching stitch.",
    "cloth/legs": "T1 simple trousers; T2 bound trouser hems; T3 long robe and continuous stole; T4 wider hem motif; T5 full lower braid; T6 one branching stitch above it.",
    "cloth/feet": "T1 hide-wrapped soft boot; T2 bound cuff; T3 cloth upper with a single fold; T4 toe embroidery; T5 wider embroidery; T6 one branching stitch.",
}


def main():
    tiers = json.loads((PICKED / "tiers.json").read_text())
    for prop, painters in (("p1", (front_head, front_chest, front_legs, front_feet)),
                           ("p2", (turned_head, turned_chest, turned_legs, turned_feet))):
        expected = set()
        for line in LINES:
            for t in range(1, 7):
                for slot, painter in zip(SLOTS, painters):
                    variant = tiers[line][f"T{t}"]["icon"][slot]
                    assert variant == "abcdef"[t-1], (line, t, slot, variant)
                    path = ROOT / prop / line / "icons" / f"{slot}_{variant}.png"
                    expected.add(path)
                    path.parent.mkdir(parents=True, exist_ok=True)
                    im = painter(line, t).im
                    pixels = [im.getpixel((x, y)) for y in range(16) for x in range(16)]
                    assert im.size == (16, 16)
                    assert set(pixels) <= set(COLORS.values()) | {(0, 0, 0, 0)}
                    for zone, minimum in (("Aa", 6), ("Bb", 3)):
                        n = sum(p in (COLORS[zone[0]], COLORS[zone[1]]) for p in pixels)
                        assert n >= minimum, (prop, line, slot, t, zone, n)
                    im.save(path, compress_level=9)
        assert len(expected) == 72
        assert set((ROOT / prop).rglob("*.png")) == expected
        notes = [IDEAS[prop], ""]
        notes += [f"- {line} {slot}: {STEPS[f'{line}/{slot}']}" for line in LINES for slot in SLOTS]
        notes += ["", "Zone A is the lining, cuff or stole; zone B is one clasp or a small connected trim. All artwork is original and dedicated to CC0.", ""]
        (ROOT / prop / "notes.md").write_text("\n".join(notes))
    print("Painted 144 original icons and two notes files.")


if __name__ == "__main__":
    main()
