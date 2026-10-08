#!/usr/bin/env python3
"""Round 44 AR: original, AI-assisted pixel art by GPT-6 Astra, CC0-1.0.

Python 3 + Pillow; no downloads, image service, external fonts or randomness.
Every mark is authored at its native resolution. The 6x6 miniatures have
independent pixel grids. Existing icons appear only as labelled sheet references.

Run from anywhere: python3 tools/r44_ar/paint_art.py
  Default: paint all A/B/C proposals and their sheets (never overwrite picks).
  --install: also copy the user's picks (PICKS) to the final art/texture paths.
  --check: compare proposals and sheets with the generator without writing.
  --check --install: also verify the final files against the picks.
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MAP = ROOT / "mods/PLAYER/grug_map"
TRAINERS = (
    "weaponsmith", "armorsmith", "tailor", "leatherworker", "woodcarver",
    "goldsmith", "alchemist", "cooking",
)
KINDS = (
    "start", "capital", "village", "outpost", "fortress", "war_camp",
    "bandit", "mirefolk", "mine", "clash", "rare_den", "king", "dragon",
)
CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-.,"
NEAREST = Image.Resampling.NEAREST
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
# The user's picks (pick page, 2026-10-08): variant A everywhere, font C.
# A baked kind's full and miniature image, and font.png with font.txt, go
# together under one key.
PICKS = {"font": "C"}
DEFAULT_PICK = "A"


def pick_key(name):
    if name.startswith("baked_"):
        return name.removesuffix(".png").removesuffix("_mini")
    return name.removesuffix(".png")


TITLES = {"A": "BRONZE AND EMBER", "B": "SLATE AND SILVER", "C": "INK AND PARCHMENT"}

# Each family has its own material palette, not faction colours.
PALETTES = {
    "A": dict(ink="#241E1C", shade="#604331", wood="#AE7244", roof="#B85F3F",
              wall="#D7BD8A", light="#FFE5AB", metal="#A9BBC0", edge="#8D714B",
              plate="#382E28", gold="#E6B64D", red="#D7463C", green="#73B877"),
    "B": dict(ink="#17262C", shade="#38505A", wood="#8A8170", roof="#628E8A",
              wall="#B3C9C8", light="#ECF5DF", metal="#D6E7E3", edge="#738F96",
              plate="#293B45", gold="#D9CB8A", red="#ED746A", green="#9BC6A0"),
    "C": dict(ink="#302327", shade="#714332", wood="#B88441", roof="#BA873D",
              wall="#E8C990", light="#FFF0C1", metal="#E8D7B2", edge="#AF8551",
              plate="#E4C58A", gold="#EFC565", red="#AD393D", green="#427B6A"),
}


def canvas(size=(16, 16), colour=CLEAR):
    return Image.new("RGBA", size, colour)


def grid(rows, palette):
    if isinstance(rows, str):
        rows = rows.split("/")
    assert len({len(row) for row in rows}) == 1, rows
    im = canvas((len(rows[0]), len(rows)))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), ImageColor.getcolor(palette[ch], "RGBA"))
    return im


def outline(im, colour):
    """One native pixel around the authored silhouette; no smoothing."""
    alpha = im.getchannel("A")
    edge = canvas(im.size, colour)
    edge.putalpha(alpha.filter(ImageFilter.MaxFilter(3)))
    result = canvas(im.size)
    result.alpha_composite(edge)
    result.alpha_composite(im)
    return result


def trainer(variant, kind):
    p = PALETTES[variant]
    im = canvas()
    d = ImageDraw.Draw(im)
    if variant == "A":
        d.polygon([(3, 1), (12, 1), (14, 3), (14, 12), (12, 14),
                   (3, 14), (1, 12), (1, 3)], fill=p["ink"])
        d.polygon([(3, 2), (12, 2), (13, 3), (13, 12), (12, 13),
                   (3, 13), (2, 12), (2, 3)], fill=p["edge"])
        d.rectangle((3, 3, 12, 12), fill=p["plate"])
        d.point((3, 2), fill=p["light"])
    elif variant == "B":
        d.ellipse((0, 0, 15, 15), fill=p["ink"])
        d.ellipse((1, 1, 14, 14), fill=p["edge"])
        d.ellipse((2, 2, 13, 13), fill=p["plate"])
        d.line((5, 1, 9, 1), fill=p["light"])
    else:
        d.polygon([(3, 1), (12, 1), (12, 2), (14, 2), (14, 12),
                   (12, 12), (12, 14), (3, 14), (3, 13), (1, 13), (1, 3),
                   (3, 3)], fill=p["ink"])
        d.rectangle((3, 2, 11, 13), fill=p["plate"])
        d.rectangle((2, 4, 13, 11), fill=p["plate"])
        d.line((3, 2, 11, 2), fill=p["light"])
        d.point((12, 11), fill=p["edge"])
    # Emblems are authored separately so the common rim stays intact.
    e = canvas()
    q = ImageDraw.Draw(e)
    steel = p["metal"] if variant != "C" else p["shade"]
    bright = p["light"] if variant != "C" else p["ink"]
    if kind == "weaponsmith":
        if variant == "A":  # Upright blade, brass guard, wrapped grip.
            q.polygon([(7, 3), (8, 3), (9, 5), (9, 8), (6, 8), (6, 5)], fill=steel)
            q.line((7, 3, 7, 8), fill=bright)
            q.line((5, 9, 10, 9), fill=p["gold"])
            q.line((7, 10, 7, 12), fill=p["wood"])
            q.point((8, 12), fill=p["gold"])
        elif variant == "B":  # Broad axe with an off-centre haft.
            q.line((7, 3, 7, 12), fill=p["wood"], width=2)
            q.polygon([(8, 3), (11, 3), (12, 4), (12, 7), (11, 8), (8, 7)], fill=steel)
            q.line((11, 4, 11, 7), fill=bright)
            q.line((4, 4, 6, 4), fill=steel)
        else:  # Heavy forging hammer.
            q.line((8, 6, 6, 12), fill=p["shade"], width=2)
            q.polygon([(4, 3), (10, 3), (12, 5), (11, 7), (5, 5)], fill=p["ink"])
            q.line((5, 3, 10, 4), fill=p["roof"])
    elif kind == "armorsmith":
        if variant == "A":
            q.polygon([(4, 4), (6, 3), (6, 5), (9, 5), (9, 3), (11, 4),
                       (11, 7), (10, 8), (10, 12), (5, 12), (5, 8), (4, 7)], fill=steel)
            q.line((6, 6, 6, 10), fill=bright)
            q.line((8, 6, 8, 11), fill=p["shade"])
            q.line((5, 12, 10, 12), fill=p["gold"])
        elif variant == "B":
            q.polygon([(5, 4), (9, 3), (11, 5), (11, 11), (8, 12),
                       (4, 10), (4, 6)], fill=steel)
            q.line((6, 4, 6, 9), fill=bright)
            q.line((8, 7, 11, 7), fill=p["ink"])
            q.line((8, 8, 8, 11), fill=p["shade"])
        else:
            q.polygon([(4, 3), (11, 3), (11, 8), (10, 10), (7, 12),
                       (4, 9)], fill=p["ink"])
            q.polygon([(5, 4), (10, 4), (10, 8), (7, 11), (5, 8)], fill=p["roof"])
            q.line((7, 4, 7, 10), fill=p["light"])
    elif kind == "tailor":
        if variant == "A":
            q.line((5, 4, 10, 10), fill=steel, width=2)
            q.line((10, 3, 5, 10), fill=bright)
            q.rectangle((3, 9, 6, 12), outline=p["gold"])
            q.rectangle((9, 9, 12, 12), outline=p["gold"])
            q.point((7, 7), fill=p["gold"])
        elif variant == "B":
            q.rectangle((4, 5, 8, 11), fill=p["roof"])
            q.line((3, 4, 9, 4), fill=bright)
            q.line((3, 12, 9, 12), fill=bright)
            q.line((4, 7, 8, 7), fill=p["green"])
            q.line((4, 9, 8, 9), fill=p["green"])
            q.line((11, 3, 9, 10), fill=steel)
            q.point((11, 4), fill=p["ink"])
        else:
            q.polygon([(5, 3), (6, 4), (9, 4), (10, 3), (12, 5), (11, 7),
                       (10, 6), (10, 12), (5, 12), (5, 6), (4, 7), (3, 5)], fill=p["green"])
            q.line((6, 6, 6, 10), fill=p["light"])
            q.line((7, 4, 8, 4), fill=p["ink"])
    elif kind == "leatherworker":
        if variant == "A":
            q.polygon([(4, 3), (6, 4), (9, 4), (11, 3), (12, 5), (10, 7),
                       (10, 9), (12, 11), (10, 12), (8, 11), (6, 12),
                       (3, 11), (5, 8), (5, 6), (3, 5)], fill=p["wood"])
            q.line((6, 5, 9, 5), fill=p["light"])
            q.line((7, 7, 7, 10), fill=p["shade"])
        elif variant == "B":
            q.polygon([(5, 3), (9, 3), (9, 8), (12, 9), (12, 11),
                       (4, 11), (4, 8), (5, 8)], fill=p["wood"])
            q.line((5, 4, 8, 4), fill=p["gold"])
            q.line((5, 6, 6, 8), fill=bright)
            q.line((4, 12, 12, 12), fill=steel)
        else:
            q.polygon([(5, 3), (10, 3), (9, 6), (11, 8), (11, 11),
                       (9, 12), (5, 12), (3, 10), (4, 7), (6, 6)], fill=p["shade"])
            q.line((5, 6, 10, 6), fill=p["red"])
            q.line((5, 8, 5, 10), fill=p["light"])
            q.point((9, 10), fill=p["roof"])
    elif kind == "woodcarver":
        if variant == "A":
            q.rectangle((4, 8, 11, 11), fill=p["wood"])
            q.line((5, 9, 10, 9), fill=p["light"])
            q.line((4, 5, 11, 5), fill=steel, width=2)
            q.line((3, 5, 3, 8), fill=p["gold"], width=2)
            q.line((11, 5, 11, 8), fill=p["gold"], width=2)
        elif variant == "B":
            q.line((4, 11, 10, 5), fill=steel, width=2)
            q.polygon([(9, 3), (11, 3), (12, 4), (9, 7), (7, 5)], fill=p["wood"])
            q.line((9, 4, 11, 4), fill=p["gold"])
            q.line([(6, 12), (10, 12), (11, 10), (10, 9)], fill=p["gold"])
        else:
            q.polygon([(3, 9), (11, 9), (12, 8), (12, 11), (3, 11)], fill=p["shade"])
            q.line((3, 12, 12, 12), fill=p["ink"])
            q.line((6, 8, 8, 5), fill=p["ink"], width=2)
            q.rectangle((3, 6, 5, 8), outline=p["shade"])
            q.line([(9, 6), (11, 5), (11, 3), (9, 3)], fill=p["green"])
    elif kind == "goldsmith":
        if variant == "A":
            q.polygon([(5, 4), (10, 4), (12, 7), (7, 12), (3, 7)], fill=p["gold"])
            q.line((4, 7, 11, 7), fill=p["light"])
            q.line([(7, 5), (6, 7), (7, 10), (9, 7), (8, 5)], fill=p["shade"])
            q.point((5, 5), fill=bright)
        elif variant == "B":
            q.ellipse((4, 6, 11, 12), outline=p["gold"], width=2)
            q.polygon([(5, 4), (7, 2), (10, 4), (7, 7)], fill=p["roof"])
            q.line((6, 4, 8, 4), fill=bright)
        else:
            q.line([(4, 3), (4, 5), (7, 8), (10, 5), (10, 3)], fill=p["shade"])
            q.polygon([(7, 6), (10, 9), (7, 12), (4, 9)], fill=p["ink"])
            q.polygon([(7, 7), (9, 9), (7, 11), (5, 9)], fill=p["red"])
            q.point((7, 8), fill=p["light"])
    elif kind == "alchemist":
        if variant == "A":
            q.rectangle((6, 3, 9, 4), fill=p["gold"])
            q.polygon([(6, 5), (9, 5), (9, 7), (12, 10), (11, 12),
                       (4, 12), (3, 10), (6, 7)], fill=steel)
            q.polygon([(6, 8), (9, 8), (10, 10), (10, 11), (5, 11), (5, 10)], fill=p["green"])
            q.point((5, 9), fill=bright)
        elif variant == "B":
            q.line([(7, 3), (10, 3), (12, 5), (12, 7)], fill=steel)
            q.line((7, 3, 7, 6), fill=steel, width=2)
            q.ellipse((3, 6, 10, 12), fill=steel)
            q.rectangle((5, 9, 8, 11), fill=p["green"])
            q.point((4, 8), fill=bright)
            q.point((12, 9), fill=p["green"])
        else:
            q.line((8, 7, 11, 3), fill=p["shade"], width=2)
            q.polygon([(3, 7), (12, 7), (10, 11), (5, 11)], fill=p["green"])
            q.line((3, 7, 12, 7), fill=p["ink"])
            q.line((5, 12, 10, 12), fill=p["ink"])
            q.point((5, 5), fill=p["green"])
    elif kind == "cooking":
        if variant == "A":
            q.rectangle((3, 7, 12, 9), outline=p["gold"])
            q.polygon([(4, 6), (11, 6), (11, 10), (9, 12), (6, 12), (4, 10)], fill=steel)
            q.line((4, 6, 11, 6), fill=bright)
            q.line((5, 7, 5, 9), fill=bright)
            q.point((6, 13), fill=p["wood"])
            q.point((9, 13), fill=p["wood"])
            q.line([(6, 4), (7, 3), (7, 2)], fill=p["light"])
            q.point((9, 4), fill=p["light"])
        elif variant == "B":
            q.line((10, 3, 9, 8), fill=p["gold"], width=2)
            q.ellipse((7, 7, 10, 9), fill=p["gold"])
            q.polygon([(3, 8), (12, 8), (11, 11), (9, 12), (6, 12), (4, 10)], fill=steel)
            q.line((4, 8, 11, 8), fill=bright)
            q.point((5, 5), fill=p["light"])
        else:
            q.polygon([(3, 8), (12, 8), (10, 11), (5, 11)], fill=p["shade"])
            q.line((3, 8, 12, 8), fill=p["ink"])
            q.line((5, 12, 10, 12), fill=p["ink"])
            q.line([(5, 6), (4, 5), (5, 3)], fill=p["red"])
            q.line([(9, 6), (8, 5), (9, 3)], fill=p["red"])
    im.alpha_composite(e)
    return im


def baked(variant, kind):
    """13 different silhouettes per style, painted in a 14x14 safe area."""
    p = PALETTES[variant]
    im = canvas()
    d = ImageDraw.Draw(im)
    ink, wall, roof, light = (p[k] for k in ("ink", "wall", "roof", "light"))
    b, c = variant == "B", variant == "C"

    def house(x, y, w=7, h=7):
        mid = x + w // 2
        d.rectangle((x + 1, y + 3, x + w - 2, y + h), fill=wall)
        d.polygon([(x, y + 3), (mid, y), (x + w - 1, y + 3)], fill=roof)
        d.line((x + 1, y + 3, mid, y + 1), fill=light)
        d.rectangle((mid, y + h - 2, mid + 1, y + h), fill=ink)

    def tower(x, y, w=4, h=8):
        d.rectangle((x, y + 1, x + w - 1, y + h), fill=wall)
        for xx in range(x, x + w, 2):
            d.point((xx, y), fill=wall)
        d.line((x, y + 2, x, y + h - 1), fill=light)
        d.point((x + w // 2, y + 4), fill=ink)

    if kind == "start":
        if not b and not c:
            d.rectangle((10, 3, 11, 7), fill=p["shade"])
            house(2, 4, 12, 9)
            d.rectangle((5, 9, 6, 10), fill=p["gold"])
        elif b:
            d.rectangle((4, 6, 11, 13), fill=wall)
            d.polygon([(2, 7), (3, 5), (5, 3), (10, 3), (12, 5), (13, 7)], fill=roof)
            d.line([(3, 6), (5, 4), (9, 4)], fill=light)
            d.rectangle((6, 9, 9, 13), fill=ink)
            d.point((7, 9), fill=p["gold"])
        else:
            house(3, 5, 10, 8)
            d.rectangle((7, 1, 8, 3), fill=p["gold"])
            d.point((4, 3), fill=p["gold"])
            d.point((11, 3), fill=p["gold"])
            d.point((5, 10), fill=light)
    elif kind == "capital":
        if not b and not c:
            tower(2, 6, 4, 7)
            tower(10, 6, 4, 7)
            d.rectangle((6, 4, 9, 13), fill=wall)
            d.polygon([(5, 4), (7, 1), (10, 4)], fill=roof)
            d.polygon([(1, 7), (3, 4), (6, 7)], fill=roof)
            d.polygon([(9, 7), (11, 4), (14, 7)], fill=roof)
            d.rectangle((7, 10, 8, 13), fill=ink)
            d.line((6, 5, 6, 8), fill=light)
        elif b:
            tower(1, 5, 4, 8)
            tower(11, 5, 4, 8)
            tower(6, 2, 4, 10)
            d.rectangle((4, 9, 11, 13), fill=wall)
            d.rectangle((6, 11, 9, 13), fill=ink)
            d.line((4, 9, 11, 9), fill=roof)
        else:
            tower(2, 5, 3, 8)
            tower(11, 5, 3, 8)
            d.rectangle((5, 7, 10, 13), fill=wall)
            d.rectangle((7, 10, 8, 13), fill=ink)
            d.line((7, 1, 7, 6), fill=light)
            d.polygon([(8, 1), (11, 2), (8, 3)], fill=roof)
            d.line((3, 6, 3, 8), fill=roof)
            d.line((12, 6, 12, 8), fill=roof)
    elif kind == "village":
        if not b and not c:
            house(1, 6, 8, 7)
            house(8, 4, 7, 9)
        elif b:
            house(1, 3, 8, 8)
            house(7, 6, 8, 7)
            d.line((4, 7, 4, 8), fill=roof)
            d.line((10, 10, 10, 11), fill=roof)
        else:
            house(5, 2, 7, 6)
            house(1, 7, 7, 6)
            house(8, 7, 7, 6)
    elif kind == "outpost":
        if not b and not c:
            d.line((4, 7, 3, 13), fill=p["wood"], width=2)
            d.line((10, 7, 11, 13), fill=p["wood"], width=2)
            d.line((5, 10, 10, 10), fill=p["wood"])
            d.rectangle((3, 4, 12, 7), fill=wall)
            d.polygon([(2, 4), (7, 1), (13, 4)], fill=roof)
            d.line((4, 6, 11, 6), fill=ink)
        elif b:
            tower(4, 3, 8, 10)
            d.rectangle((6, 10, 8, 13), fill=ink)
            d.line((4, 7, 11, 7), fill=roof)
        else:
            tower(4, 6, 7, 7)
            d.line((6, 2, 6, 6), fill=wall)
            d.polygon([(7, 2), (12, 2), (10, 4), (7, 4)], fill=roof)
            d.line((7, 9, 7, 11), fill=ink)
    elif kind == "fortress":
        if not b and not c:
            tower(1, 3, 5, 10)
            tower(10, 3, 5, 10)
            d.rectangle((5, 7, 10, 13), fill=p["shade"])
            d.line((5, 8, 10, 8), fill=wall)
            d.rectangle((7, 10, 8, 13), fill=ink)
        elif b:
            d.polygon([(2, 4), (13, 4), (13, 10), (10, 13), (5, 13), (2, 10)], fill=p["shade"])
            tower(3, 2, 4, 8)
            tower(9, 2, 4, 8)
            d.rectangle((6, 6, 9, 11), fill=wall)
            d.rectangle((7, 9, 8, 12), fill=ink)
        else:
            d.polygon([(1, 5), (4, 5), (4, 3), (6, 3), (6, 5),
                       (9, 5), (9, 3), (11, 3), (11, 5), (14, 5),
                       (14, 12), (11, 14), (4, 14), (1, 12)], fill=wall)
            d.line((2, 7, 13, 7), fill=p["shade"])
            d.rectangle((6, 9, 9, 14), fill=ink)
            d.line((3, 9, 3, 11), fill=roof)
            d.line((12, 9, 12, 11), fill=roof)
    elif kind == "war_camp":
        if not b and not c:
            d.polygon([(1, 12), (5, 5), (10, 12)], fill=wall)
            d.polygon([(7, 13), (11, 6), (14, 13)], fill=roof)
            d.polygon([(4, 12), (5, 8), (7, 12)], fill=ink)
            d.line((10, 1, 10, 6), fill=p["wood"])
            d.line((11, 2, 13, 2), fill=p["gold"])
        elif b:
            d.rectangle((3, 8, 12, 13), fill=wall)
            d.polygon([(1, 8), (7, 2), (14, 8)], fill=roof)
            d.line((7, 3, 7, 7), fill=light)
            d.polygon([(5, 13), (7, 8), (10, 13)], fill=ink)
        else:
            d.line((3, 13, 11, 2), fill=wall)
            d.line((12, 13, 4, 2), fill=wall)
            d.line((7, 2, 7, 13), fill=p["shade"], width=2)
            d.polygon([(8, 3), (13, 3), (11, 5), (13, 7), (8, 7)], fill=roof)
            d.line((7, 2, 7, 8), fill=light)
    elif kind == "bandit":
        if not b and not c:
            d.polygon([(1, 13), (7, 4), (14, 13)], fill=p["red"])
            d.polygon([(5, 13), (7, 7), (10, 13)], fill=ink)
            d.line((3, 2, 11, 7), fill=wall)
            d.line((11, 2, 3, 7), fill=wall)
            d.point((7, 5), fill=light)
        elif b:
            d.line((7, 3, 7, 14), fill=p["wood"], width=2)
            d.polygon([(4, 2), (10, 2), (12, 4), (11, 8), (9, 8),
                       (9, 10), (5, 10), (5, 8), (3, 7), (3, 4)], fill=p["red"])
            d.rectangle((4, 5, 6, 6), fill=ink)
            d.rectangle((9, 5, 10, 6), fill=ink)
            d.line((6, 9, 8, 9), fill=light)
        else:
            d.line((2, 3, 13, 13), fill=p["red"], width=2)
            d.line((13, 3, 2, 13), fill=p["red"], width=2)
            d.rectangle((4, 3, 11, 8), fill=wall)
            d.rectangle((6, 8, 9, 10), fill=wall)
            d.point((5, 6), fill=ink)
            d.point((10, 6), fill=ink)
            d.point((7, 8), fill=ink)
    elif kind == "mirefolk":
        if not b and not c:
            d.line((2, 4, 2, 13), fill=p["green"])
            d.line((13, 3, 13, 13), fill=p["green"])
            d.polygon([(3, 8), (7, 3), (12, 8)], fill=p["green"])
            d.rectangle((4, 8, 11, 13), fill=p["shade"])
            d.line((5, 9, 6, 9), fill=p["red"])
            d.line((9, 9, 10, 9), fill=p["red"])
            d.line((7, 12, 8, 12), fill=ink)
        elif b:
            d.polygon([(2, 4), (5, 3), (7, 5), (10, 3), (13, 4),
                       (12, 11), (8, 14), (4, 11)], fill=p["green"])
            d.rectangle((3, 6, 5, 7), fill=p["red"])
            d.rectangle((10, 6, 12, 7), fill=p["red"])
            d.line((5, 10, 10, 10), fill=ink)
            d.point((6, 10), fill=light)
            d.point((9, 10), fill=light)
        else:
            d.polygon([(3, 2), (5, 7), (7, 3), (8, 7), (12, 2), (12, 9),
                       (10, 12), (7, 14), (4, 11), (3, 8)], fill=p["green"])
            d.line((4, 8, 6, 9), fill=p["red"])
            d.line((9, 9, 11, 8), fill=p["red"])
            d.point((7, 11), fill=light)
    elif kind == "mine":
        if not b and not c:
            d.polygon([(2, 13), (2, 6), (5, 3), (10, 3), (13, 6), (13, 13)], fill=p["shade"])
            d.rectangle((4, 6, 11, 13), fill=p["wood"])
            d.rectangle((6, 8, 9, 13), fill=ink)
            d.line((4, 6, 11, 6), fill=light)
            d.line((4, 14, 6, 11), fill=p["metal"])
            d.line((11, 14, 9, 11), fill=p["metal"])
        elif b:
            d.polygon([(2, 11), (2, 6), (5, 2), (10, 2), (13, 6), (13, 11)], fill=p["shade"])
            d.line([(4, 9), (4, 5), (10, 5), (10, 9)], fill=p["wood"], width=2)
            d.rectangle((4, 9, 12, 12), fill=p["metal"])
            d.line((5, 9, 11, 9), fill=p["gold"])
            d.point((5, 14), fill=wall)
            d.point((11, 14), fill=wall)
        else:
            d.line((4, 13, 10, 4), fill=wall, width=2)
            d.line([(2, 5), (5, 2), (8, 2), (12, 5)], fill=roof, width=2)
            d.polygon([(10, 10), (12, 8), (14, 10), (12, 13)], fill=p["green"])
            d.point((12, 9), fill=light)
    elif kind == "clash":
        if not b and not c:
            d.line((3, 3, 12, 12), fill=p["metal"], width=2)
            d.line((12, 3, 3, 12), fill=wall, width=2)
            d.line((2, 9, 6, 13), fill=p["gold"])
            d.line((9, 13, 13, 9), fill=p["gold"])
            d.point((3, 3), fill=light)
        elif b:
            d.polygon([(4, 3), (11, 3), (11, 8), (8, 13), (4, 9)], fill=wall)
            d.line([(8, 3), (6, 6), (9, 7), (7, 10)], fill=ink)
            d.line((2, 12, 13, 2), fill=p["metal"])
            d.line((1, 10, 4, 13), fill=p["gold"])
        else:
            d.rectangle((3, 4, 5, 13), fill=wall)
            d.rectangle((9, 7, 12, 13), fill=wall)
            d.line((2, 3, 6, 3), fill=roof)
            d.line((8, 6, 13, 6), fill=roof)
            d.line((2, 14, 13, 14), fill=p["shade"])
            d.line((2, 11, 12, 1), fill=p["red"], width=2)
    elif kind == "rare_den":
        if not b and not c:
            d.polygon([(2, 13), (2, 7), (5, 3), (10, 3), (13, 7), (13, 13)], fill=p["shade"])
            d.polygon([(5, 13), (5, 8), (7, 6), (9, 7), (10, 13)], fill=ink)
            d.line((5, 9, 6, 9), fill=p["gold"])
            d.line((9, 9, 10, 9), fill=p["gold"])
            d.point((4, 5), fill=wall)
        elif b:
            d.polygon([(4, 13), (3, 10), (5, 8), (10, 8), (12, 10), (11, 13)], fill=p["gold"])
            d.rectangle((2, 5, 4, 7), fill=p["gold"])
            d.rectangle((6, 2, 8, 5), fill=light)
            d.rectangle((10, 4, 12, 6), fill=p["gold"])
            d.point((6, 10), fill=light)
        else:
            d.polygon([(1, 13), (4, 5), (7, 2), (10, 5), (14, 13)], fill=wall)
            d.polygon([(4, 13), (5, 8), (8, 6), (11, 13)], fill=ink)
            d.point((6, 10), fill=p["red"])
            d.point((9, 10), fill=p["red"])
            d.line((4, 5, 5, 5), fill=light)
    elif kind == "king":
        if not b and not c:
            d.polygon([(2, 4), (5, 7), (7, 2), (10, 7), (13, 4),
                       (12, 12), (3, 12)], fill=p["gold"])
            d.line((3, 11, 12, 11), fill=light)
            d.point((7, 7), fill=p["red"])
            d.point((4, 9), fill=light)
            d.point((11, 9), fill=light)
        elif b:
            d.polygon([(2, 5), (4, 3), (6, 6), (8, 2), (10, 6), (12, 3),
                       (14, 5), (12, 12), (4, 12)], fill=p["gold"])
            d.line((4, 11, 12, 11), fill=light)
            d.point((7, 8), fill=roof)
            d.point((10, 8), fill=roof)
        else:
            d.line((7, 6, 7, 14), fill=wall, width=2)
            d.polygon([(3, 2), (5, 4), (7, 1), (10, 4), (12, 2),
                       (11, 8), (4, 8)], fill=roof)
            d.line((4, 7, 11, 7), fill=light)
            d.line((5, 13, 10, 13), fill=p["gold"])
    elif kind == "dragon":
        if not b and not c:
            d.polygon([(3, 2), (7, 4), (11, 2), (10, 6), (13, 7),
                       (14, 10), (10, 11), (9, 14), (4, 14), (6, 10),
                       (3, 7)], fill=roof)
            d.line((4, 3, 5, 5), fill=light)
            d.line((9, 3, 9, 4), fill=light)
            d.point((9, 7), fill=p["gold"])
            d.line((11, 10, 13, 10), fill=ink)
            d.point((11, 11), fill=light)
        elif b:
            d.polygon([(1, 3), (5, 5), (6, 8), (7, 4), (9, 4), (10, 8),
                       (12, 5), (14, 3), (14, 11), (11, 9), (9, 12),
                       (8, 14), (6, 11), (4, 9), (1, 11)], fill=roof)
            d.line((2, 5, 4, 7), fill=wall)
            d.line((13, 5, 11, 7), fill=wall)
            d.point((7, 5), fill=p["red"])
            d.line((8, 8, 8, 11), fill=light)
        else:
            d.polygon([(3, 2), (6, 4), (10, 2), (9, 6), (13, 7), (13, 10),
                       (9, 10), (6, 13), (2, 11), (2, 8), (4, 10), (6, 9),
                       (4, 7)], fill=wall)
            d.line((4, 3, 5, 5), fill=roof)
            d.point((9, 7), fill=p["red"])
            d.line((10, 10, 12, 10), fill=p["shade"])
            d.point((11, 11), fill=light)
    return outline(im, ink)


# Native 6x6 paintings: '.' transparent, 'o' outline, material letters.
# A miniature is a semantic abbreviation, never a resized world-map icon.
MINIS = {
    "A": {
        "start": "..oo../.orro./orrrro/owwwwo/owowwo/.oooo.",
        "capital": ".o.o../ororo./owwwwo/owowwo/owowwo/oooooo",
        "village": ".o..o./orooro/oworwo/owowwo/oooooo/......",
        "outpost": "..oo../.orro./owwwwo/oooooo/.owwo./.o..o.",
        "fortress": "oo..oo/owoowo/owwwwo/owowwo/owowwo/oooooo",
        "war_camp": "..o.../.owo../owwwo./owooro/oooowo/...ooo",
        "bandit": "o....o/.otto./.ottto/ototto/oooooo/......",
        "mirefolk": ".oggo./oggggo/otggto/oggggo/.oggo./..oo..",
        "mine": ".oooo./owwwwo/owoo wo/owoowo/owoowo/oo..oo".replace(" ", ""),
        "clash": "ow..wo/wwooww/.owwo./.owwo./ow..wo/o....o",
        "rare_den": ".oooo./osssso/osssso/oyssyo/osssso/oooooo",
        "king": "o.oo.o/yoyyoy/oyyyyo/oyyyyo/owwwwo/.oooo.",
        "dragon": "o..o../oro ro./orrrro/.oryro/.orro./orooo.".replace(" ", ""),
    },
    "B": {
        "start": ".oooo./orrrro/owwwwo/owowwo/owowwo/.oooo.",
        "capital": "..oo../oowwoo/owwwwo/owwowo/owwowo/oooooo",
        "village": ".oo.../orr oo./oworr o/ooowwo/..oooo/......".replace(" ", ""),
        "outpost": ".o..o./oww wo./owwwwo/.owwo./.owwo./.oooo.".replace(" ", ""),
        "fortress": ".o..o./oww wwo/owowwo/owowwo/.owwo./..oo..".replace(" ", ""),
        "war_camp": "..o.../.oro../orrro./owwowo/owowwo/oooooo",
        "bandit": ".oooo./otttto/ototto/.otto./..oo../..oo..",
        "mirefolk": "oo..oo/ogg ggo/otggto/ogg ggo/.oggo./..oo..".replace(" ", ""),
        "mine": ".oooo./osssso/owoowo/owwwwo/.oooo./.o..o.",
        "clash": ".....o/.ooowo/owowo./owo wo./.owo../..o...".replace(" ", ""),
        "rare_den": "..oo../oowwoo/oyoo yo/oo y yoo/oyyyyo/.oooo.".replace(" ", ""),
        "king": ".o.o.o/oyoyoy/oyyyyo/oyyyyo/owwwwo/.oooo.",
        "dragon": "o....o/oro oro/orro ro/orrrro/oo yroo/..oo..".replace(" ", ""),
    },
    "C": {
        "start": "..oo../..yy../.orro./owwwwo/owowwo/oooooo",
        "capital": "..oyyo/..oo../oowwoo/owwwwo/owowwo/oooooo",
        "village": "..oo../.orro./oowwoo/oworwo/owowwo/oooooo",
        "outpost": "..oyyo/..oy o./.owo../owwwwo/owowwo/.oooo.".replace(" ", ""),
        "fortress": "o.oo.o/owwwwo/owwwwo/owowwo/owowwo/.oooo.",
        "war_camp": "..oyyo/o.oyyo/.owoo./.owwo./ow..wo/o....o",
        "bandit": "t.oo.t/.owwo./owowwo/.owwo./.otto./t....t",
        "mirefolk": "o.o..o/ogoggo/oggggo/otggto/.oggo./..oo..",
        "mine": ".oooo./owwwwo/..owo./.owo o./owo yyo/oo..o.".replace(" ", ""),
        "clash": "o...to/wo.to./woowwo/woowwo/woowwo/oooooo",
        "rare_den": "..oo../.owwo./owwwwo/owttwo/owoo wo/oooooo".replace(" ", ""),
        "king": "o.oo.o/oyyyyo/owwwwo/.oooo./..ww../.owwo.",
        "dragon": "o..o../owowo./owwwwo/.owtwo/oww oo./.ooo..".replace(" ", ""),
    },
}


def miniature(variant, kind):
    p = PALETTES[variant]
    return grid(MINIS[variant][kind], dict(o=p["ink"], w=p["wall"],
                r=p["roof"], y=p["gold"], t=p["red"], g=p["green"], s=p["shade"]))


# Original letter grids, not rasterizations of an installed font.
# A: open, lightly serifed atlas capitals; B: compact square sans;
# C: wide, incised capitals with clipped diagonals and wedge terminals.
FONT_A = {
    "A": "..#../.#.#./#...#/#####/#...#/#...#/#...#",
    "B": "####./.#..#/.#..#/.###./.#..#/.#..#/####.",
    "C": ".####/#...#/#..../#..../#..../#...#/.###.",
    "D": "####./.#..#/.#..#/.#..#/.#..#/.#..#/####.",
    "E": "#####/.#..#/.#.../.###./.#.../.#..#/#####",
    "F": "#####/.#..#/.#.../.###./.#.../.#.../###..",
    "G": ".###./#...#/#..../#.###/#...#/#...#/.###.",
    "H": "#...#/#...#/#...#/#####/#...#/#...#/#...#",
    "I": "###/.#./.#./.#./.#./.#./###",
    "J": ".###/..#./..#./..#./..#./#.#./.#..",
    "K": "#...#/#..#./#.#../##.../#.#../#..#./#...#",
    "L": "###../.#.../.#.../.#.../.#.../.#..#/#####",
    "M": "#.....#/##...##/#.#.#.#/#..#..#/#.....#/#.....#/#.....#",
    "N": "#...#/##..#/#.#.#/#..##/#...#/#...#/#...#",
    "O": ".###./#...#/#...#/#...#/#...#/#...#/.###.",
    "P": "####./.#..#/.#..#/.###./.#.../.#.../###..",
    "Q": ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",
    "R": "####./.#..#/.#..#/.###./.#.#./.#..#/##..#",
    "S": ".####/#...#/#..../.###./....#/#...#/####.",
    "T": "#####/#.#.#/..#../..#../..#../..#../.###.",
    "U": "#...#/#...#/#...#/#...#/#...#/#...#/.###.",
    "V": "#...#/#...#/#...#/#...#/.#.#./.#.#./..#..",
    "W": "#.....#/#.....#/#.....#/#..#..#/#.#.#.#/##...##/#.....#",
    "X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
    "Y": "#...#/#...#/.#.#./..#../..#../..#../.###.",
    "Z": "#####/#...#/...#./..#../.#.../#...#/#####",
    "0": ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",
    "1": ".#./##./.#./.#./.#./.#./###",
    "2": ".###./#...#/....#/...#./..#../.#.../#####",
    "3": "####./....#/....#/.###./....#/....#/####.",
    "4": "...#./..##./.#.#./#..#./#####/...#./...#.",
    "5": "#####/#..../#..../####./....#/#...#/.###.",
    "6": ".###./#..../#..../####./#...#/#...#/.###.",
    "7": "#####/#...#/...#./..#../..#../..#../..#..",
    "8": ".###./#...#/#...#/.###./#...#/#...#/.###.",
    "9": ".###./#...#/#...#/.####/....#/....#/.###.",
    " ": ".../.../.../.../.../.../...",
    "'": ".#/##/#./../../../..",
    "-": ".../.../.../###/.../.../...",
    ".": "../../../../../##/##",
    ",": "../../../../.#/.#/#.",
}
FONT_B = {
    "A": ".##./#..#/#..#/####/#..#/#..#/#..#",
    "B": "###./#..#/#..#/###./#..#/#..#/###.",
    "C": ".###/#.../#.../#.../#.../#.../.###",
    "D": "###./#..#/#..#/#..#/#..#/#..#/###.",
    "E": "####/#.../#.../###./#.../#.../####",
    "F": "####/#.../#.../###./#.../#.../#...",
    "G": ".###/#.../#.../#.##/#..#/#..#/.###",
    "H": "#..#/#..#/#..#/####/#..#/#..#/#..#",
    "I": "#/#/#/#/#/#/#",
    "J": "..# /..# /..# /..# /..# /#.# /.#. ".replace(" ", ""),
    "K": "#..#/#..#/#.#./##../#.#./#..#/#..#",
    "L": "#.../#.../#.../#.../#.../#.../####",
    "M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
    "N": "#..#/##.#/##.#/#.##/#.##/#..#/#..#",
    "O": ".##./#..#/#..#/#..#/#..#/#..#/.##.",
    "P": "###./#..#/#..#/###./#.../#.../#...",
    "Q": ".##./#..#/#..#/#..#/#.##/#..#/.###",
    "R": "###./#..#/#..#/###./#.#./#..#/#..#",
    "S": ".###/#.../#.../.##./...#/...#/###.",
    "T": "#####/..#../..#../..#../..#../..#../..#..",
    "U": "#..#/#..#/#..#/#..#/#..#/#..#/.##.",
    "V": "#...#/#...#/#...#/#...#/.#.#./.#.#./..#..",
    "W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
    "X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
    "Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
    "Z": "####/...#/..#./.##./.#../#.../####",
    "0": ".##./#..#/#.##/##.#/#..#/#..#/.##.",
    "1": ".#/##/.#/.#/.#/.#/.#",
    "2": "###./...#/...#/.##./#.../#.../####",
    "3": "###./...#/...#/.##./...#/...#/###.",
    "4": "#..#/#..#/#..#/####/...#/...#/...#",
    "5": "####/#.../#.../###./...#/...#/###.",
    "6": ".###/#.../#.../###./#..#/#..#/.##.",
    "7": "####/...#/..#./..#./.#../.#../.#..",
    "8": ".##./#..#/#..#/.##./#..#/#..#/.##.",
    "9": ".##./#..#/#..#/.###/...#/...#/###.",
    " ": "../../../../../../..",
    "'": "#/#/././././.",
    "-": ".../.../.../###/.../.../...",
    ".": "././././././#",
    ",": "../../../../../.#/#.",
}
FONT_C = {
    "A": ".###./##.##/#...#/#...#/#####/#...#/#...#",
    "B": "####./##..#/##..#/####./##..#/##..#/####.",
    "C": ".###./##..#/##.../##.../##.../##..#/.###.",
    "D": "####./##..#/##..#/##..#/##..#/##..#/####.",
    "E": "#####/##.../##.../####./##.../##.../#####",
    "F": "#####/##.../##.../####./##.../##.../##...",
    "G": ".###./##..#/##.../##.##/##..#/##..#/.####",
    "H": "#...#/#...#/#...#/#####/#...#/#...#/#...#",
    "I": "####/.##./.##./.##./.##./.##./####",
    "J": "..###/...##/...##/...##/...##/#..##/.###.",
    "K": "#...#/#..##/#.##./###../#.##./#..##/#...#",
    "L": "##.../##.../##.../##.../##.../##..#/#####",
    "M": "##...##/###.###/#.###.#/#..#..#/#.....#/#.....#/#.....#",
    "N": "##..#/###.#/#.###/#..##/#...#/#...#/#...#",
    "O": ".###./##..#/#...#/#...#/#...#/#..##/.###.",
    "P": "####./##..#/##..#/####./##.../##.../##...",
    "Q": ".###./##..#/#...#/#...#/#.#.#/#..##/.####",
    "R": "####./##..#/##..#/####./##.#./##..#/##..#",
    "S": ".####/##.../##.../.###./...##/...##/####.",
    "T": "######/..##../..##../..##../..##../..##../..##..",
    "U": "#...#/#...#/#...#/#...#/#...#/##..#/.###.",
    "V": "#...#/#...#/#...#/##.##/.###./..#../..#..",
    "W": "#.....#/#.....#/#.....#/#..#..#/#.###.#/###.###/##...##",
    "X": "#...#/##.##/.###./..#../.###./##.##/#...#",
    "Y": "#....#/#....#/.#..#./..##../..##../..##../..##..",
    "Z": "#####/...##/..##./.###./.##../##.../#####",
    "0": ".###./##..#/#..##/#.#.#/##..#/#..##/.###.",
    "1": ".##./###./.##./.##./.##./.##./####",
    "2": ".###./#..##/...##/..##./.##../##.../#####",
    "3": "####./...##/...##/.###./...##/...##/####.",
    "4": "...##/..###/.#.##/#..##/#####/...##/...##",
    "5": "#####/##.../##.../####./...##/...##/####.",
    "6": ".####/##.../##.../####./##..#/##..#/.###.",
    "7": "#####/...##/..##./..##./.##../.##../.##..",
    "8": ".###./##..#/##..#/.###./#..##/#..##/.###.",
    "9": ".###./##..#/##..#/.####/...##/...##/####.",
    " ": ".../.../.../.../.../.../...",
    "'": "##/##/.#/../../../..",
    "-": "..../..../..../####/..../..../....",
    ".": "../../../../../##/##",
    ",": "../../../../##/.#/#.",
}
FONTS = {"A": FONT_A, "B": FONT_B, "C": FONT_C}


def glyphs(variant):
    return {ch: grid(rows, {"#": "#FFFFFF"}) for ch, rows in FONTS[variant].items()}


def font_sheet(variant):
    letters = glyphs(variant)
    im = canvas((sum(letters[ch].width + 1 for ch in CHARSET), 8))
    x = 0
    for ch in CHARSET:
        im.putpixel((x, 0), (255, 0, 0, 255))
        im.alpha_composite(letters[ch], (x, 1))
        x += letters[ch].width + 1
    return im


def lettering(text, variant="B", scale=1, colour=WHITE, halo=False):
    letters = glyphs(variant)
    # Sheet typography uses the original capitals as small caps. Extra caption
    # punctuation is authored here and never added to the game font's charset.
    extras = {"_": "..../..../..../..../..../..../####",
              "/": "...#/...#/..#./..#./.#../#.../#...",
              ":": "./#/././#/./.", "+": ".../.#./.#./###/.#./.#./...",
              "(": "..#/.#./#../#../#../.#./..#",
              ")": "#../.#./..#/..#/..#/.#./#.."}
    letters.update({ch: grid(rows, {"#": "#FFFFFF"}) for ch, rows in extras.items()})
    text = text.upper()
    im = canvas((max(1, sum(letters[ch].width + 1 for ch in text) - 1), 7))
    x = 0
    for ch in text:
        g = letters[ch]
        tinted = canvas(g.size, colour)
        tinted.putalpha(g.getchannel("A"))
        im.alpha_composite(tinted, (x, 0))
        x += g.width + 1
    if halo:
        padded = canvas((im.width + 2, 9))
        padded.alpha_composite(im, (1, 1))
        im = outline(padded, "#191D22")
    return im.resize((im.width * scale, im.height * scale), NEAREST)


def crosshair(variant):
    im = canvas()
    d = ImageDraw.Draw(im)
    red = {"A": "#EB4F42", "B": "#FF766C", "C": "#D93843"}[variant]
    if variant == "A":
        d.ellipse((3, 3, 12, 12), outline=red)
        for line in [(7, 1, 7, 5), (8, 10, 8, 14), (1, 8, 5, 8), (10, 7, 14, 7)]:
            d.line(line, fill=red)
    elif variant == "B":
        for line in [[(2, 6), (2, 2), (6, 2)], [(9, 2), (13, 2), (13, 6)],
                     [(2, 9), (2, 13), (6, 13)], [(9, 13), (13, 13), (13, 9)]]:
            d.line(line, fill=red)
        d.line((7, 5, 7, 10), fill=red)
        d.line((5, 7, 10, 7), fill=red)
    else:
        for line in [[(1, 5), (4, 7), (1, 9)], [(5, 1), (7, 4), (9, 1)],
                     [(14, 6), (11, 8), (14, 10)], [(6, 14), (8, 11), (10, 14)]]:
            d.line(line, fill=red)
        d.rectangle((7, 7, 8, 8), fill=red)
    return outline(im, "#321F25")


def ring(variant):
    im = canvas((32, 32))
    if variant in "AB":
        d = ImageDraw.Draw(im)
        d.ellipse((1, 1, 30, 30), outline=WHITE, width=1 if variant == "A" else 2)
    else:
        # A soft three-pixel rim; RGB stays pure white for arbitrary tinting.
        # Analytic alpha at native pixels, not a filtered or resized source.
        for y in range(32):
            for x in range(32):
                radius = math.hypot(x - 15.5, y - 15.5)
                distance = abs(radius - 13.5)
                a = 255 if distance <= 0.7 else 144 if distance <= 1.25 else 48 if distance <= 1.8 else 0
                if a:
                    im.putpixel((x, y), (255, 255, 255, a))
    return im


def terrain(size, kind):
    """Four deliberately quiet, authored map-colour patches for inspection."""
    colours = {
        "GREEN": ("#6B864D", "#789254", "#5D7845"),
        "SAND": ("#CEB77C", "#DDC68B", "#C1A96F"),
        "SNOW": ("#D8E3DE", "#EDF0E4", "#C6D6D4"),
        "SEA": ("#426C83", "#4B7C91", "#386177"),
    }[kind]
    im = canvas(size, colours[0])
    d = ImageDraw.Draw(im)
    w, h = size
    d.polygon([(0, h // 3), (w // 3, h // 3), (w // 3, h // 5),
               (w, h // 5), (w, h // 2), (w // 2, h // 2),
               (w // 2, 2 * h // 3), (0, 2 * h // 3)], fill=colours[1])
    d.polygon([(0, h - 9), (w // 3, h - 9), (w // 3, h - 15),
               (w - 7, h - 15), (w - 7, h - 5), (w, h - 5),
               (w, h), (0, h)], fill=colours[2])
    return im


def contact_sheet(variant, assets):
    sheet = canvas((1440, 1860), "#171F27")
    d = ImageDraw.Draw(sheet)

    def caption(text, x, y, scale=1, colour="#AFBCC5"):
        sheet.alpha_composite(lettering(text, scale=scale, colour=colour), (x, y))

    def sprite(im, x, y, width):
        sheet.alpha_composite(im.resize((width, round(im.height * width / im.width)), NEAREST), (x, y))

    def panel(x, y, w, h):
        d.rectangle((x, y, x + w - 1, y + h - 1), fill="#26313A")
        d.line((x, y, x + w - 1, y), fill="#47565F")

    caption("GRUDGELANDS / ROUND 44 / ART PROPOSALS", 24, 20, 2, "#D2B887")
    caption(f"{variant} - {TITLES[variant]}", 24, 51, 4, "#F4EBD6")
    caption("ORIGINAL PIXEL ART / NATIVE PIXELS / NEAREST-NEIGHBOUR PREVIEWS / USER PICK PENDING", 24, 94, 1)
    caption("01 / PROFESSION TRAINERS", 24, 124, 2, "#F4EBD6")
    caption("EACH CARD: NEW 4X + 2.67X / EXISTING WAYPOINT + STEWARD AT 2.67X", 660, 127, 1)
    waypoint = Image.open(MAP / "textures/grug_map_waypoint.png").convert("RGBA")
    steward = Image.open(MAP / "textures/grug_map_housing_steward.png").convert("RGBA")
    for i, kind in enumerate(TRAINERS):
        x, y = 24 + i % 4 * 350, 157 + i // 4 * 144
        panel(x, y, 338, 131)
        name = f"grug_map_trainer_{kind}.png"
        caption(name, x + 10, y + 12)
        im = assets[name]
        sprite(im, x + 16, y + 35, 64)
        sprite(im, x + 108, y + 51, 43)
        sprite(waypoint, x + 187, y + 51, 43)
        sprite(steward, x + 264, y + 51, 43)
        caption("4X", x + 42, y + 113)
        caption("2.67X", x + 113, y + 113)
        caption("WAYPOINT", x + 189, y + 113)
        caption("STEWARD", x + 270, y + 113)

    caption("02 / BAKED MAP SYMBOLS", 24, 467, 2, "#F4EBD6")
    caption("WORLD + MINI 4X / PATCHES: WORLD 2X AND NATIVE MINI 3X", 690, 470)
    for i, kind in enumerate(KINDS):
        x, y = 24 + i % 4 * 350, 502 + i // 4 * 200
        panel(x, y, 338, 185)
        name, mini = f"baked_{kind}.png", f"baked_{kind}_mini.png"
        caption(name, x + 10, y + 12)
        sprite(assets[name], x + 17, y + 42, 64)
        sprite(assets[mini], x + 106, y + 80, 24)
        caption("4X", x + 43, y + 122)
        caption("4X", x + 112, y + 122)
        for j, ground in enumerate(("GREEN", "SAND", "SNOW", "SEA")):
            tx, ty = x + 146 + j * 46, y + 34
            patch = terrain((44, 89), ground)
            patch.alpha_composite(assets[name].resize((32, 32), NEAREST), (6, 7))
            patch.alpha_composite(assets[mini].resize((18, 18), NEAREST), (13, 58))
            sheet.alpha_composite(patch, (tx, ty))
            caption(ground, tx + 4, ty + 95)
        caption(mini, x + 10, y + 150)
        caption("SEPARATELY PAINTED 6X6 MINIATURE", x + 10, y + 167, colour="#7E969D")

    # Empty cells beside the last baked symbol hold same-scale references.
    panel(374, 1102, 1038, 185)
    caption("EXISTING MAP ICONS / 4X / COMPARISON ONLY", 390, 1117, 2)
    references = ["waypoint", "home", "housing_steward", "crownbinder",
                  "quest_available", "quest_active", "quest_ready"]
    for i, name in enumerate(references):
        im = Image.open(MAP / f"textures/grug_map_{name}.png").convert("RGBA")
        x = 395 + i * 143
        sprite(im, x + 23, 1154, 64)
        caption(name, x, 1235)
    caption("THESE REFERENCE PIXELS ARE NOT INCLUDED IN THE NEW ASSETS", 392, 1264)

    caption("03 / REGION LETTERING", 24, 1320, 2, "#F4EBD6")
    panel(24, 1353, 1388, 210)
    caption("FONT.PNG / 4X / RED START MARKERS ABOVE SEVEN GLYPH ROWS", 40, 1368)
    sprite(assets["font.png"], 40, 1391, assets["font.png"].width * 4)
    caption("FONT.TXT: " + CHARSET, 40, 1438)
    sample = lettering("THE CONTESTED FRONT", variant, 3, halo=True)
    patch = terrain((sample.width + 30, 49), "GREEN")
    patch.alpha_composite(sample, (15, 11))
    sheet.alpha_composite(patch, (40, 1462))
    caption("3X / PURE WHITE + DARK HALO", 40 + patch.width + 20, 1482)
    sheet.alpha_composite(lettering("DWARVEN LANDS", variant, 2, halo=True), (40, 1533))
    sheet.alpha_composite(lettering("WYRMGLASS CROWN", variant, 2, halo=True), (460, 1533))
    sheet.alpha_composite(lettering("STORMSCALE SUMMIT", variant, 2, halo=True), (890, 1533))

    caption("04 / QUEST TARGET MARKS", 24, 1595, 2, "#F4EBD6")
    panel(24, 1628, 1388, 205)
    caption("GRUG_MAP_CROSSHAIR.PNG / 4X", 40, 1645)
    sprite(assets["grug_map_crosshair.png"], 95, 1683, 64)
    caption("GRUG_MAP_RING.PNG / 4X", 280, 1645)
    sprite(assets["grug_map_ring.png"], 316, 1672, 128)
    for i, ground in enumerate(("GREEN", "SAND", "SNOW", "SEA")):
        patch = terrain((182, 127), ground)
        # Both marks are shown in their actual colours; the right ring is an
        # explicitly labelled tint/opacity preview, not another deliverable.
        mark = assets["grug_map_crosshair.png"].resize((32, 32), NEAREST)
        patch.alpha_composite(mark, (13, 47))
        tint = canvas((32, 32), "#E85856")
        tint.putalpha(assets["grug_map_ring.png"].getchannel("A").point(lambda a: a * 2 // 3))
        patch.alpha_composite(tint.resize((96, 96), NEAREST), (74, 15))
        sheet.alpha_composite(patch, (580 + i * 199, 1672))
        caption(ground, 587 + i * 199, 1809)
    caption("PATCHES: RED CROSSHAIR 2X / RING 3X TINTED RED AT 67 PERCENT OPACITY", 580, 1645)
    caption("A / B / C ARE PROPOSALS. FINAL PATHS CURRENTLY HOLD A. CC0 1.0 / GPT-6 ASTRA / PYTHON + PILLOW", 24, 1845)
    return sheet


def build(variant):
    assets = {f"grug_map_trainer_{k}.png": trainer(variant, k) for k in TRAINERS}
    for kind in KINDS:
        assets[f"baked_{kind}.png"] = baked(variant, kind)
        assets[f"baked_{kind}_mini.png"] = miniature(variant, kind)
    assets["font.png"] = font_sheet(variant)
    assets["grug_map_crosshair.png"] = crosshair(variant)
    assets["grug_map_ring.png"] = ring(variant)
    return assets


def validate(variant, assets):
    assert len(assets) == 37
    for name, im in assets.items():
        expected = (6, 6) if "_mini.png" in name else (32, 32) if name == "grug_map_ring.png" else (16, 16)
        if name == "font.png":
            expected = (sum(len(FONTS[variant][ch].split("/")[0]) + 1 for ch in CHARSET), 8)
        assert im.mode == "RGBA" and im.size == expected, (variant, name, im.mode, im.size, expected)
        assert im.getchannel("A").getextrema() == (0, 255), (variant, name, "transparent/opaque pixels")
        assert all(a or (r, g, b) == (0, 0, 0) for r, g, b, a in pixels(im)), (variant, name, "hidden RGB")
        if name != "grug_map_ring.png":
            assert set(im.getchannel("A").tobytes()) <= {0, 255}, (variant, name, "binary alpha")
    font = assets["font.png"]
    starts = [x for x in range(font.width) if font.getpixel((x, 0)) == (255, 0, 0, 255)]
    assert len(starts) == len(CHARSET) == 41
    for i, ch in enumerate(CHARSET):
        rows = FONTS[variant][ch].split("/")
        assert len(rows) == 7 and len({len(r) for r in rows}) == 1, (variant, repr(ch), rows)
        end = starts[i + 1] if i + 1 < len(starts) else font.width
        assert end - starts[i] == len(rows[0]) + 1
        assert all(font.getpixel((end - 1, y)) == CLEAR for y in range(8))
        glyph = font.crop((starts[i], 1, end - 1, 8))
        assert set(pixels(glyph)) <= {WHITE, CLEAR}
        if ch.isalnum():
            assert glyph.getbbox()[1] == 0 and glyph.getbbox()[3] == 7, (variant, ch, "cap height")
    assert all((r, g, b) == (255, 255, 255) for r, g, b, a in pixels(assets["grug_map_ring.png"]) if a)
    assert assets["grug_map_ring.png"].getpixel((16, 16)) == CLEAR


def pixels(im):
    return (im.getpixel((x, y)) for y in range(im.height) for x in range(im.width))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    failures = []
    count = 0

    def output(path, value):
        nonlocal count
        count += 1
        if args.check:
            if not path.is_file():
                failures.append(f"missing: {path.relative_to(ROOT)}")
            elif isinstance(value, str):
                if path.read_bytes() != value.encode("ascii"):
                    failures.append(f"text mismatch: {path.relative_to(ROOT)}")
            else:
                with Image.open(path) as actual:
                    if actual.mode != value.mode or actual.size != value.size or actual.tobytes() != value.tobytes():
                        failures.append(f"pixel/format mismatch: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(value, str):
                path.write_bytes(value.encode("ascii"))
            else:
                value.save(path, optimize=False)

    sets = {}
    for variant in "ABC":
        assets = build(variant)
        validate(variant, assets)
        sets[variant] = assets
        for name, im in assets.items():
            output(HERE / "variants" / variant / name, im)
        output(HERE / "variants" / variant / "font.txt", CHARSET + "\n")
        output(HERE / "variants" / variant / "sheet.png", contact_sheet(variant, assets))
        print(f"{variant}: 37 RGBA assets, font {assets['font.png'].width}x8, 1440x1860 sheet")
    if args.install:
        for name in sets["A"]:
            im = sets[PICKS.get(pick_key(name), DEFAULT_PICK)][name]
            folder = "textures" if name.startswith("grug_map_") else "art"
            output(MAP / folder / name, im)
        output(MAP / "art/font.txt", CHARSET + "\n")
    for name in sets["A"]:
        # Every requested file gets three actual choices, even the white ring.
        assert len({(sets[v][name].size, sets[v][name].tobytes()) for v in "ABC"}) == 3, name
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{'Verified' if args.check else 'Wrote'} {count} files; all asset format checks passed.")


if __name__ == "__main__":
    main()
