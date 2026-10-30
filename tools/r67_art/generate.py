#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Original pixel candidates and an offline review board. Python 3 + Pillow/numpy.

Run from any directory. Only tools/r67_art is written. --check compares the
complete generated package in memory, without rewriting it. Reference images
are copied solely for the review board; no candidate samples their pixels.
"""

import argparse
from html import escape
from html.parser import HTMLParser
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NEAREST = Image.Resampling.NEAREST
RACES = ("human", "dwarf", "elf", "orc", "troll", "undead")
CLASSES = ("warrior", "scout", "mage", "priest")
PARTS = ("top", "side", "front", "lock", "inside")
BG = "#181e28"
INK = "#13171e"
ACCORD = "#3f6fce"
THRONG = "#c41e3a"
OUTPUTS = {}


def rgb(value):
    return tuple(bytes.fromhex(value.lstrip("#")))


def emit(path, image):
    buf = BytesIO()
    image.save(buf, format="PNG", compress_level=9)
    OUTPUTS[path] = buf.getvalue()


def candidate(name, im):
    emit(f"candidates/{name}.png", im)
    emit(f"preview/{name}.png", im)
    return im


def portrait(race):
    """A: 32px hand-placed silhouettes, exported at 64px without smoothing."""
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    p = d.polygon
    r = d.rectangle
    l = d.line
    # Shared dark silhouette and restrained collar; race colour is on the face.
    p([(6, 29), (8, 25), (12, 23), (20, 23), (24, 25), (26, 29)], INK)
    p([(8, 28), (10, 26), (14, 24), (18, 24), (23, 26), (24, 28)], "#55545a")
    l([(12, 27), (15, 28), (19, 27)], ACCORD if race in RACES[:3] else THRONG, 2)

    if race == "human":
        p([(8, 7), (12, 4), (20, 4), (24, 8), (24, 17), (21, 23),
           (17, 26), (13, 25), (9, 20), (7, 16)], INK)
        r((7, 13, 24, 17), "#996d53")
        p([(10, 10), (14, 7), (21, 8), (22, 17), (20, 22), (17, 24),
           (13, 22), (10, 18)], "#c49468")
        p([(10, 11), (15, 8), (18, 9), (18, 19), (14, 21), (11, 18)], "#e0b08c")
        p([(9, 12), (8, 8), (12, 5), (20, 5), (23, 8), (22, 13),
           (19, 9), (16, 9), (12, 12)], "#4a3020")
        l([(10, 8), (13, 6), (19, 6)], "#806044", 2)
        l([(11, 14), (13, 14)], "#443528")
        l([(18, 14), (20, 14)], "#443528")
        l([(15, 16), (14, 18), (16, 18)], "#f0ceaa")
        l([(14, 21), (18, 21)], "#805947")

    elif race == "dwarf":
        p([(6, 8), (10, 5), (21, 5), (25, 9), (25, 20), (22, 27),
           (17, 30), (10, 28), (6, 23), (5, 14)], INK)
        p([(7, 10), (11, 7), (20, 7), (23, 10), (23, 19),
           (20, 23), (10, 22), (7, 18)], "#d8a07c")
        r((9, 10, 15, 17), "#ecc2a0")
        p([(7, 11), (7, 9), (11, 6), (20, 6), (24, 10), (23, 14),
           (20, 10), (11, 10), (8, 14)], "#70452e")
        l([(9, 9), (12, 7), (19, 7)], "#ab7143", 2)
        p([(7, 17), (11, 18), (13, 20), (18, 20), (21, 18), (24, 17),
           (23, 24), (20, 28), (16, 29), (10, 26), (7, 22)], "#9c5935")
        p([(8, 18), (11, 20), (14, 21), (14, 27), (10, 25), (8, 22)], "#c1834d")
        p([(18, 21), (22, 19), (21, 25), (18, 27)], "#73432e")
        l([(11, 13), (13, 13)], "#493d32", 2)
        l([(18, 13), (20, 13)], "#493d32", 2)
        r((14, 15, 17, 17), "#efc9a4")
        l([(12, 19), (15, 18), (19, 19)], "#633c2b", 2)
        r((14, 25, 16, 26), "#c9b27e")

    elif race == "elf":
        p([(8, 10), (11, 5), (19, 4), (23, 8), (24, 23), (20, 27),
           (11, 26), (8, 21)], INK)
        p([(10, 10), (11, 6), (19, 5), (22, 8), (23, 24),
           (19, 25), (11, 24)], "#948765")
        p([(1, 9), (10, 13), (11, 18), (7, 18), (3, 14)], INK)
        p([(30, 9), (22, 12), (21, 18), (25, 17), (28, 13)], INK)
        p([(3, 11), (10, 14), (10, 17), (6, 15)], "#dcc098")
        p([(28, 11), (22, 14), (22, 17), (26, 14)], "#bba888")
        p([(11, 10), (15, 8), (20, 10), (21, 18), (18, 23),
           (15, 25), (11, 21), (10, 17)], "#dcc098")
        p([(11, 10), (15, 9), (16, 13), (15, 22), (12, 20)], "#eedec8")
        p([(10, 13), (10, 9), (13, 6), (19, 6), (22, 10), (21, 13),
           (17, 9), (15, 9), (12, 12)], "#d3c596")
        l([(12, 8), (15, 6), (18, 6)], "#eee1b5")
        l([(11, 15), (13, 15)], "#476252")
        l([(18, 15), (20, 14)], "#476252")
        l([(14, 21), (17, 21)], "#8f7660")

    elif race == "orc":
        p([(5, 10), (10, 8), (11, 5), (20, 5), (23, 9), (27, 10),
           (26, 19), (23, 25), (19, 28), (12, 28), (7, 23)], INK)
        p([(6, 11), (11, 10), (21, 9), (25, 12), (23, 17),
           (24, 21), (21, 25), (12, 26), (8, 22), (8, 17)], "#567838")
        p([(10, 11), (14, 8), (20, 9), (21, 18), (18, 24),
           (11, 23), (9, 19)], "#6c9448")
        p([(11, 11), (14, 8), (18, 9), (16, 14), (10, 15)], "#8fa960")
        p([(12, 8), (12, 5), (15, 3), (19, 4), (21, 7), (20, 10),
           (17, 8)], "#38332b")
        l([(14, 5), (17, 4), (19, 6)], "#68604a")
        l([(9, 14), (13, 15)], "#303e28", 2)
        l([(18, 15), (22, 14)], "#303e28", 2)
        r((13, 17, 17, 19), "#8ba05b")
        l([(10, 22), (21, 22)], "#38492b", 2)
        p([(9, 19), (11, 22), (12, 24), (9, 23)], "#e5d9b2")
        p([(22, 19), (20, 22), (19, 24), (22, 23)], "#d1c6a1")

    elif race == "troll":
        p([(9, 12), (10, 6), (12, 1), (15, 4), (18, 1), (20, 5),
           (22, 3), (23, 12), (27, 11), (25, 19), (22, 24),
           (18, 28), (12, 26), (8, 21), (4, 12)], INK)
        p([(10, 11), (11, 7), (12, 3), (15, 6), (18, 3), (19, 8),
           (21, 6), (22, 12)], "#53647d")
        l([(12, 7), (13, 9), (17, 6)], "#8090a2", 2)
        p([(5, 13), (11, 15), (12, 20), (8, 18)], "#588c84")
        p([(26, 13), (21, 15), (20, 20), (24, 17)], "#42675f")
        p([(11, 12), (19, 11), (22, 15), (21, 21), (18, 26),
           (14, 25), (11, 21), (10, 17)], "#588c84")
        p([(12, 12), (16, 12), (17, 22), (14, 23), (12, 20)], "#7aa69b")
        l([(11, 15), (14, 16)], "#2f4b49", 2)
        l([(18, 16), (21, 15)], "#2f4b49", 2)
        p([(15, 16), (18, 21), (17, 23), (14, 21)], "#92b2a1")
        p([(6, 17), (7, 22), (11, 26), (14, 25), (10, 22), (8, 17)], INK)
        p([(25, 17), (24, 22), (20, 26), (17, 25), (21, 22), (23, 17)], INK)
        p([(7, 17), (9, 22), (13, 25), (10, 25), (7, 22)], "#e5d9b2")
        p([(24, 17), (22, 22), (18, 25), (21, 25), (24, 22)], "#d1c6a1")

    else:
        p([(9, 5), (20, 4), (24, 8), (24, 17), (21, 21),
           (21, 25), (17, 28), (11, 26), (10, 22), (7, 18), (7, 10)], INK)
        p([(10, 6), (19, 5), (23, 8), (23, 15), (20, 19),
           (20, 24), (17, 26), (12, 24), (11, 20), (8, 17), (8, 11)], "#aaa89c")
        p([(10, 7), (17, 6), (18, 11), (15, 14), (10, 18), (9, 14)], "#cdc9b4")
        p([(9, 13), (14, 13), (14, 17), (10, 17)], "#343c39")
        p([(18, 13), (22, 12), (21, 17), (18, 17)], "#343c39")
        r((11, 14, 12, 15), "#a5b78a")
        r((19, 14, 20, 15), "#a5b78a")
        p([(16, 16), (14, 20), (17, 20)], "#555d55")
        r((12, 22, 19, 23), "#42483f")
        for x in (12, 15, 18):
            r((x, 21, x + 1, 22), "#dfd8c2")
        l([(11, 8), (13, 9), (12, 11)], "#777d72")

    return im.resize((64, 64), NEAREST)


def profile(race):
    """B: neutral carved profile signs; eye/ear gaps remain broad at 16px."""
    im = Image.new("RGBA", (32, 32))
    mask = Image.new("L", (32, 32))
    d = ImageDraw.Draw(mask)
    outlines = {
        "human": [(7, 25), (11, 21), (9, 17), (8, 12), (10, 7), (14, 4),
                  (21, 5), (24, 9), (23, 12), (27, 16), (23, 17), (23, 21),
                  (19, 23), (19, 27), (9, 27)],
        "dwarf": [(5, 24), (8, 19), (7, 12), (10, 6), (18, 4), (23, 8),
                  (24, 12), (28, 16), (24, 18), (25, 23), (21, 29),
                  (15, 29), (10, 26)],
        "elf": [(7, 27), (10, 21), (6, 10), (2, 5), (13, 10), (12, 7),
                (17, 3), (22, 6), (24, 11), (24, 13), (28, 16), (24, 18),
                (23, 21), (19, 23), (19, 27)],
        "orc": [(5, 27), (9, 21), (6, 16), (7, 10), (12, 6), (13, 3),
                (19, 3), (21, 7), (24, 9), (24, 13), (28, 17), (25, 18),
                (28, 22), (25, 26), (18, 27)],
        "troll": [(6, 27), (10, 21), (6, 16), (3, 11), (10, 12), (9, 7),
                  (11, 2), (15, 6), (18, 1), (20, 6), (23, 3), (23, 10),
                  (24, 13), (29, 18), (25, 19), (23, 18), (23, 23),
                  (19, 26), (19, 28)],
        "undead": [(8, 27), (11, 22), (8, 18), (7, 12), (9, 6), (14, 3),
                   (21, 4), (25, 8), (24, 13), (27, 16), (23, 18),
                   (24, 22), (20, 25), (18, 25), (18, 28)],
    }
    d.polygon(outlines[race], fill=255)
    # Two stone shades, kept quiet beside the coloured class pictures.
    arr = np.zeros((32, 32, 4), dtype=np.uint8)
    for y in range(32):
        for x in range(32):
            if mask.getpixel((x, y)):
                c = "#d8cda7" if x + y < 33 else "#aea58d"
                arr[y, x] = (*rgb(c), 255)
    im = Image.fromarray(arr)
    d = ImageDraw.Draw(im)
    d.line([(18, 12), (21, 12)], fill=INK, width=2)
    if race == "human":
        d.line([(11, 10), (14, 7), (20, 7)], "#f1e4bb", 2)
        d.line([(14, 15), (14, 18)], INK, 2)
    elif race == "dwarf":
        d.line([(11, 18), (15, 20), (21, 19)], INK, 2)
        d.line([(13, 23), (17, 27)], "#e9dbb4", 2)
    elif race == "elf":
        d.line([(7, 9), (14, 15), (16, 14)], INK, 2)
        d.line([(16, 7), (18, 5), (21, 7)], "#f1e4bb", 2)
    elif race == "orc":
        d.line([(20, 22), (24, 22)], INK, 2)
        d.polygon([(23, 23), (24, 17), (27, 23)], "#f1e4bb")
        d.line([(10, 12), (13, 15)], INK, 2)
    elif race == "troll":
        d.line([(18, 24), (24, 23), (27, 20), (28, 16)], INK, 4)
        d.line([(18, 24), (24, 23), (27, 20), (28, 16)], "#f1e4bb", 2)
    else:
        d.rectangle((17, 11, 22, 15), INK)
        d.polygon([(24, 16), (22, 18), (25, 18)], INK)
        for x in (17, 20, 23):
            d.line([(x, 21), (x, 23)], INK)
    d.line([(10, 29), (19, 29)], ACCORD if race in RACES[:3] else THRONG, 2)
    return im.resize((64, 64), NEAREST)


# Steel's blue-grey and abyssal steel's violet follow the local material family.
# ores.lua uses #34404a:75 and #3a245d:135 for the two bars. The violet tool
# textures provide the lighter edge range; there is no emission or glow.
PALETTES = {
    "steel": dict(dark="#303b43", shade="#4a5861", mid="#7f9097",
                  light="#bdc9c8", edge="#e0e2d5", panel="#697b84"),
    "abyssal": dict(dark="#231b32", shade="#3a245d", mid="#66517f",
                    light="#ac99c3", edge="#d2c2e4", panel="#514062"),
}
WOOD = ("#75512e", "#805b33", "#90663a", "#9d7443", "#ad8350")


def wood():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            # Deliberately spaced horizontal grain; deterministic, no RNG.
            shade = (y // 3 + (x // 4 + y * 3) % 3) % len(WOOD)
            if y in (4, 10):
                shade = max(0, shade - 1)
            im.putpixel((x, y), (*rgb(WOOD[shade]), 255))
    return im


def metal_panel(tier):
    p = PALETTES[tier]
    im = Image.new("RGBA", (16, 16), p["panel"])
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, 14, 14), outline=p["mid"])
    d.line([(3, 3), (11, 3)], p["light"])
    d.line([(3, 4), (6, 4)], p["mid"])
    d.line([(4, 11), (12, 11)], p["shade"])
    d.line([(10, 12), (12, 12)], p["shade"])
    return im


def band(d, box, p, horizontal=False):
    x0, y0, x1, y1 = box
    d.rectangle(box, p["mid"])
    if horizontal:
        d.line([(x0, y0), (x1, y0)], p["light"])
        d.line([(x0, y1), (x1, y1)], p["dark"])
    else:
        d.line([(x0, y0), (x0, y1)], p["light"])
        d.line([(x1, y0), (x1, y1)], p["dark"])


def shell(tier, variant, top=False):
    p = PALETTES[tier]
    im = wood() if variant == "a" else metal_panel(tier)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 15), outline=p["dark"])
    if variant == "a":
        # Two continuous straps, wider on the final tier.
        span = 3 if tier == "steel" else 4
        band(d, (1, 1, span, 14), p)
        band(d, (15 - span, 1, 14, 14), p)
        for x in (2, 13):
            for y in (2, 13):
                d.point((x, y), p["edge"])
        if tier == "abyssal":
            for y in (1, 14):
                d.line([(2, y), (13, y)], p["mid"])
    else:
        band(d, (0, 0, 15, 2), p, True)
        band(d, (0, 13, 15, 15), p, True)
        band(d, (0, 0, 2, 15), p)
        band(d, (13, 0, 15, 15), p)
        for x in (1, 14):
            for y in (1, 14):
                d.point((x, y), p["edge"])
        if tier == "abyssal":
            # Chamfered shoulders interrupt the rectangle, readable at distance.
            for points in ([(2, 2), (5, 2), (2, 5)],
                           [(13, 2), (10, 2), (13, 5)],
                           [(2, 13), (5, 13), (2, 10)],
                           [(13, 13), (10, 13), (13, 10)]):
                d.polygon(points, p["mid"])
            if top:
                d.polygon([(7, 5), (10, 8), (7, 11), (4, 8)], p["shade"])
                d.line([(4, 8), (7, 5), (10, 8)], p["light"])
    return im


def chest(tier, variant, face):
    p = PALETTES[tier]
    if face == "inside":
        # The OBJ maps v .5..1 to the lid lining and v 0...5 to the floor.
        # These are two complete 16px squares, not a vertically stretched face.
        im = Image.new("RGBA", (16, 32), p["dark"])
        for offset in (0, 16):
            panel = wood() if variant == "a" else metal_panel(tier)
            arr = np.array(panel)
            # The original mesh puts the floor at the lip, so a nearly black
            # recess is essential: a bright floor would read as a solid tray.
            arr[:, :, :3] = (arr[:, :, :3].astype(float) *
                            (0.34 if offset == 0 else 0.12)).astype(np.uint8)
            panel = Image.fromarray(arr)
            d = ImageDraw.Draw(panel)
            d.rectangle((0, 0, 15, 15), outline=p["mid"])
            recess_edge = tuple(int(c * 0.45) for c in rgb(p["shade"]))
            d.line([(1, 14), (1, 1), (14, 1)], recess_edge)
            if offset == 0:
                for x in (3, 12):
                    d.line([(x, 3), (x, 12)], p["dark"])
            else:
                d.line([(2, 13), (13, 13)], recess_edge)
            im.paste(panel, (0, offset))
        return im
    im = shell(tier, variant, top=face == "top")
    d = ImageDraw.Draw(im)
    if face != "top":
        # The existing lid/body UV cut is exactly 5/16 from the top.
        d.line([(0, 4), (15, 4)], p["light"])
        d.line([(0, 5), (15, 5)], p["dark"])
    if face in ("front", "lock"):
        d.rectangle((6, 3, 9, 8), p["dark"])
        d.rectangle((7, 3, 8, 7), p["light"])
        d.point((7, 3), p["edge"])
        if face == "lock":
            # Shackle and padlock, not a plaque; the black keyhole is 2px wide.
            d.rectangle((5, 6, 10, 10), p["dark"])
            d.rectangle((6, 6, 9, 9), p["light"])
            d.line([(6, 6), (9, 6)], p["edge"])
            d.rectangle((7, 7, 8, 7), p["dark"])
            d.point((7, 8), p["dark"])
    return im


def shelf(tier, variant, vessels=False):
    p = PALETTES[tier]
    im = shell(tier, variant)
    d = ImageDraw.Draw(im)
    # Every shelf keeps two equally sized open bays and a continuous crossbar.
    for top in (2, 10):
        d.rectangle((2, top, 13, top + 4), "#29231f")
        if vessels:
            for x, height, shade in ((3, 4, "#aaa7b6"), (7, 3, "#9aaab0"),
                                     (11, 4, "#c1bbb3")):
                y = top + 4 - height
                d.rectangle((x, y, x + 1, y + 1), shade)
                d.rectangle((x - 1, y + 2, x + 2, top + 4), "#6d6877")
                d.line([(x, y + 2), (x, top + 3)], shade)
                d.point((x + 1, top + 4), "#454450")
        else:
            colors = ("#9a5448", "#779361", "#8a7397", "#b39d65", "#607f92")
            for i, x in enumerate((2, 4, 7, 9, 12)):
                h = (3, 4, 4, 2, 4)[i]
                c = colors[(i + (2 if top == 10 else 0)) % 5]
                d.rectangle((x, top + 5 - h, min(x + 1, 13), top + 4), c)
                d.point((x, top + 5 - h), "#c3b38c")
    band(d, (0, 7, 15, 9), p, True)
    # Clear metal rim on the front as well as the side; contents stay quiet.
    d.line([(0, 0), (15, 0)], p["light"])
    for x in (1, 14):
        d.line([(x, 1), (x, 14)], p["mid"])
        for y in (1, 8, 14):
            d.point((x, y), p["edge"])
    if tier == "abyssal" and variant == "b":
        for x in (2, 13):
            for y in (2, 6, 10, 14):
                d.point((x, y), p["light"])
    return im


def load_references():
    refs = {}
    for cl in CLASSES:
        refs[f"class_{cl}"] = ROOT / f"mods/PLAYER/grug_classes/textures/grug_class_{cl}.png"
    for faction in ("accord", "throng"):
        refs[f"faction_{faction}"] = ROOT / f"mods/PLAYER/grug_inventory/textures/grug_inventory_faction_{faction}.png"
    for part in PARTS:
        refs[f"wood_chest_{part}"] = ROOT / f"mods/BASE/default/textures/default_chest_{part}.png"
    refs["wood_bookshelf"] = ROOT / "mods/BASE/default/textures/default_bookshelf.png"
    refs["wood_vessels"] = ROOT / "mods/BASE/vessels/textures/vessels_shelf.png"
    refs["wood_shelf_side"] = ROOT / "mods/BASE/default/textures/default_wood.png"
    refs["abyssal_pick"] = ROOT / "mods/ITEMS/grug_materials/textures/grug_materials_tool_abyssal_steelpick.png"
    refs["steel_bar_base"] = ROOT / "mods/BASE/default/textures/default_steel_ingot.png"
    result = {}
    for name, path in refs.items():
        result[name] = Image.open(path).convert("RGBA")
        # Preserve the originals byte for byte in the preview directory.
        OUTPUTS[f"preview/ref_{name}.png"] = path.read_bytes()
    # Offline material swatches approximate the stated colourize operation.
    for tier, color, weight in (("steel", "#34404a", 75), ("abyssal", "#3a245d", 135)):
        arr = np.array(result["steel_bar_base"])
        arr[:, :, :3] = np.rint(arr[:, :, :3] * (1 - weight / 255)
                               + np.array(rgb(color)) * weight / 255).astype(np.uint8)
        result[f"{tier}_bar"] = Image.fromarray(arr)
        emit(f"preview/ref_{tier}_bar.png", result[f"{tier}_bar"])
    return result


def obj_faces():
    """Read the unchanged open chest; six OBJ groups match the six tile slots."""
    vertices, uv, faces = [], [], []
    slot = -1
    for line in (ROOT / "mods/BASE/default/models/chest_open.obj").read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "v":
            vertices.append([float(n) for n in fields[1:4]])
        elif fields[0] == "vt":
            uv.append([float(n) for n in fields[1:3]])
        elif fields[0] == "g":
            slot += 1
        elif fields[0] == "f":
            pairs = [tuple(int(n) - 1 for n in f.split("/")[:2]) for f in fields[1:]]
            faces.append((np.array([vertices[v] for v, _ in pairs]),
                          np.array([uv[t] for _, t in pairs]), slot))
    assert slot == 5, "Open chest material groups changed; review the mapping."
    return faces


def cube_faces():
    # Each quad is top-left, bottom-left, bottom-right, top-right on its texture.
    return [(np.array(v, dtype=float)[::-1], np.array([(0, 1), (0, 0), (1, 0), (1, 1)])[::-1], slot)
            for v, slot in [
                ([(-.5, .5, .5), (-.5, .5, -.5), (.5, .5, -.5), (.5, .5, .5)], 0),
                ([(.5, .5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (.5, .5, .5)], 2),
                ([(-.5, .5, -.5), (-.5, -.5, -.5), (.5, -.5, -.5), (.5, .5, -.5)], 4),
            ]]


def render_box(tiles, opened=False):
    """Small orthographic software rasterizer; nearest texels, real open OBJ UVs."""
    size = (240, 260)
    canvas = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    zbuf = np.full((size[1], size[0]), -np.inf)
    camera = np.array([.52, .48, -.71]); camera /= np.linalg.norm(camera)
    right = np.cross(camera, [0., 1., 0.]); right /= np.linalg.norm(right)
    up = np.cross(right, camera)
    light = np.array([-.35, .8, -.5]); light /= np.linalg.norm(light)
    for verts, uv, slot in obj_faces() if opened else cube_faces():
        normal = np.cross(verts[1] - verts[0], verts[2] - verts[0])
        normal /= np.linalg.norm(normal)
        # OBJ winding and these cube quads both face outwards.
        if normal @ camera <= 0:
            continue
        screen = np.column_stack((verts @ right * 143 + 120,
                                  -(verts @ up) * 143 + 164))
        depths = verts @ camera
        texture = np.array(tiles[slot])
        th, tw = texture.shape[:2]
        shade = .70 + .30 * max(0., normal @ light)
        for tri in ((0, 1, 2), (0, 2, 3)):
            a, b, c = screen[list(tri)]
            x0, y0 = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
            x1, y1 = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
            x0, y0 = max(0, x0), max(0, y0)
            x1, y1 = min(size[0] - 1, x1), min(size[1] - 1, y1)
            if x1 < x0 or y1 < y0:
                continue
            yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1]
            xx, yy = xx + .5, yy + .5
            det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(det) < 1e-9:
                continue
            wa = ((b[1] - c[1]) * (xx - c[0]) + (c[0] - b[0]) * (yy - c[1])) / det
            wb = ((c[1] - a[1]) * (xx - c[0]) + (a[0] - c[0]) * (yy - c[1])) / det
            wc = 1 - wa - wb
            depth = sum(w * depths[i] for w, i in zip((wa, wb, wc), tri))
            z = zbuf[y0:y1 + 1, x0:x1 + 1]
            visible = (wa >= -1e-7) & (wb >= -1e-7) & (wc >= -1e-7) & (depth > z)
            uvs = sum(w[:, :, None] * uv[i] for w, i in zip((wa, wb, wc), tri))
            tx = np.clip((uvs[:, :, 0] * tw).astype(int), 0, tw - 1)
            ty = np.clip(((1 - uvs[:, :, 1]) * th).astype(int), 0, th - 1)
            pixels = texture[ty, tx].copy()
            pixels[:, :, :3] = (pixels[:, :, :3].astype(float) * shade).astype(np.uint8)
            canvas[y0:y1 + 1, x0:x1 + 1][visible] = pixels[visible]
            z[visible] = depth[visible]
    return Image.fromarray(canvas)


def img(name, size, alt=None, height=None):
    return (f'<img src="{escape(name)}.png" width="{size}" height="{height or size}" '
            f'alt="{escape(alt or name)}" title="{escape(alt or name)}">')


CSS = """
:root{color-scheme:dark;--bg:#181e28;--panel:#212936;--line:#394556;--ink:#e6dfcf;--muted:#a9b4bf;--gold:#d6c69b}
*{box-sizing:border-box}body{margin:0;background:#11161e;color:var(--ink);font:15px/1.55 system-ui,sans-serif}
main{max-width:1380px;margin:auto;padding:42px 28px 80px}h1,h2,h3,p{margin:0 0 14px}h1{font-size:36px;line-height:1.2;letter-spacing:-1px}h2{font-size:25px;margin-top:46px}h3{font-size:19px}p{max-width:850px}.eyebrow{font-size:12px;letter-spacing:3px;color:var(--gold);text-transform:uppercase}
a{color:#bbd0ed}nav{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}.recommendation{background:#26332f;border-left:4px solid #9abb92;padding:20px 24px;margin:24px 0}.tag{color:#c4d9b9;font-size:12px;font-weight:700;letter-spacing:1px}.muted,small{color:var(--muted)}code{font-size:12px;overflow-wrap:anywhere}
section{scroll-margin-top:20px}.set{background:var(--bg);border:1px solid var(--line);padding:22px;margin:20px 0}.race-grid{display:grid;grid-template-columns:repeat(6,minmax(130px,1fr));gap:12px}.race-card{background:var(--panel);padding:16px 10px;text-align:center}.scales{display:flex;align-items:end;justify-content:center;gap:14px;min-height:101px}.scale{display:flex;flex-direction:column;align-items:center;gap:8px}.scale small{font-size:10px}.faction{font-size:11px;color:var(--muted);margin-bottom:10px}img{object-fit:contain;image-rendering:pixelated;vertical-align:middle}.family{display:flex;gap:24px;flex-wrap:wrap;margin-top:24px;padding-top:20px;border-top:1px solid var(--line)}.reference{text-align:center}.reference .scales{gap:9px}.reference p{margin:10px 0 0;font-size:12px}
.table-wrap{overflow:auto;background:var(--bg);border:1px solid var(--line);margin-top:18px}table{border-collapse:collapse;width:100%;min-width:540px}th,td{text-align:left;padding:10px 14px;border-bottom:1px solid #313b49}th{font-size:11px;text-transform:uppercase;letter-spacing:1px;color:var(--muted)}td.icon{width:62px}td.name{width:50%}tr:last-child td{border-bottom:0}
.comparison{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.object{background:var(--bg);border:1px solid var(--line);padding:16px;text-align:center}.object h3{font-size:17px}.object .render{width:min(100%,240px);height:auto}.distance{border-top:1px solid var(--line);padding-top:12px;display:flex;justify-content:center;align-items:center;gap:18px;font-size:12px;color:var(--muted)}.family-label{margin:24px 0 10px;font-size:12px;text-transform:uppercase;letter-spacing:2px;color:var(--gold)}
.texture-grid{display:grid;grid-template-columns:repeat(4,minmax(180px,1fr));gap:14px}.texture{background:var(--bg);border:1px solid var(--line);padding:14px}.texture p{font-size:13px;margin-bottom:10px}.texture .samples{display:flex;gap:18px;align-items:start;min-height:148px}.texture code{display:block;margin-top:12px;color:var(--muted)}details{margin-top:20px}summary{cursor:pointer;padding:14px 0;color:var(--gold)}.materials{display:flex;gap:24px;align-items:center;margin:20px 0}.note{border-left:2px solid var(--line);padding-left:16px;color:var(--muted);margin-top:22px}.choices{display:flex;gap:14px;flex-wrap:wrap}.choices span{padding:8px 14px;background:var(--panel);border:1px solid var(--line)}footer{margin-top:45px;color:var(--muted);font-size:12px}
@media(max-width:1000px){.race-grid{grid-template-columns:repeat(3,1fr)}.texture-grid{grid-template-columns:repeat(2,1fr)}}
@media(max-width:650px){main{padding:24px 14px}.comparison{grid-template-columns:1fr}.race-grid{grid-template-columns:repeat(2,1fr)}.texture-grid{grid-template-columns:1fr}h1{font-size:28px}.set{padding:14px}.scales{gap:10px}}
"""


def preview_page():
    page = ['<!doctype html><html lang="en"><meta charset="utf-8">',
            '<meta name="viewport" content="width=device-width,initial-scale=1">',
            '<title>Grudgelands · Round 67 · Art choices</title>',
            f'<style>{CSS}</style><body><main>',
            '<p class="eyebrow">Grudgelands / Round 67 / Art review</p>',
            '<h1>Faces in the crowd.<br>Materials that read at a glance.</h1>',
            '<p class="muted">Two race sets, two steel treatments and two abyssal treatments. '
            'All candidates are proposals; the wooden originals are shown for comparison.</p>',
            '<div class="recommendation"><p class="tag">RECOMMENDED COMBINATION</p>',
            '<h3>Race A · Steel A · Abyssal B</h3>',
            '<p>The coloured heads keep the six races distinct in a small row. '
            'Bright steel straps leave the wooden body visible at T3; complete violet plating '
            'gives T6 a stronger change in material and value.</p>',
            '<div class="choices"><span>Race A — coloured heads</span><span>Steel A — strapped wood</span>'
            '<span>Abyssal B — faceted plating</span></div></div>',
            '<nav><a href="#races">Race icons</a><a href="#containers">Container comparison</a>'
            '<a href="#textures">Flat textures</a><a href="#handoff">Handoff</a></nav>',
            '<section id="races"><h2>01 / Race icons</h2>',
            '<p class="muted">64 × 64 RGBA exports, drawn on a 32px grid. '
            'Each card shows 16, 32 and 64 CSS pixels at browser zoom 100%. '
            'Faction colour is confined to the collar or small base stroke.</p>']
    ideas = {"a": "Coloured heads use the face outline, beard, ears and tusks to distinguish each race.",
             "b": "Carved profile signs use a quiet ivory silhouette and broad cutouts beside the faction emblems."}
    for variant in ("a", "b"):
        page += [f'<div class="set"><h3>Set {variant.upper()} — {"Coloured heads" if variant == "a" else "Carved profiles"}</h3>',
                 f'<p>{ideas[variant]}</p><div class="race-grid">']
        for race in RACES:
            page += [f'<div class="race-card"><strong>{race.title()}</strong>',
                     f'<div class="faction">The {"Accord" if race in RACES[:3] else "Throng"}</div><div class="scales">']
            for size in (16, 32, 64):
                page.append(f'<div class="scale">{img(f"race_{race}_{variant}",size,race.title())}<small>{size}px</small></div>')
            page.append('</div></div>')
        page += ['</div><div class="family">']
        for name in [f"class_{cl}" for cl in CLASSES] + ["faction_accord", "faction_throng"]:
            title = name.split("_")[1].title()
            if name.startswith("faction"):
                title = "The " + title
            page.append('<div class="reference"><div class="scales">')
            for size in (16, 32, 64):
                page.append(f'<div class="scale">{img("ref_"+name,size,title)}<small>{size}px</small></div>')
            page.append(f'</div><p>{title} · existing</p></div>')
        page += ['</div><h3 style="margin-top:26px">Online Players — row study</h3>',
                 '<p class="muted">24px icons, with native hover labels. Names and levels below are mock data.</p>',
                 '<div class="table-wrap"><table><thead><tr><th>Faction</th><th>Name</th><th>Class</th><th>Race</th><th>Level</th></tr></thead><tbody>']
        for i, race in enumerate(RACES):
            faction = "accord" if i < 3 else "throng"
            cl = CLASSES[i % 4]
            name = ("Alden", "Branna", "Ilyra", "Garn", "Zeru", "Sable")[i]
            page.append(f'<tr><td class="icon">{img("ref_faction_"+faction,24,"The "+faction.title())}</td>'
                        f'<td class="name">{name}</td><td class="icon">{img("ref_class_"+cl,24,cl.title())}</td>'
                        f'<td class="icon">{img(f"race_{race}_{variant}",24,race.title())}</td><td>{(18,34,27,44,36,52)[i]}</td></tr>')
        page.append('</tbody></table></div></div>')
    page += ['</section><section id="containers"><h2>02 / Container tiers</h2>',
             '<p>Steel A / Abyssal A: broad metal straps and corners around visible timber. '
             'Steel B / Abyssal B: enclosed metal plating; the final tier has chamfered violet corners.</p>',
             '<div class="materials">'+img('ref_steel_bar',48,'Steel Bar — offline tint approximation')+
             img('ref_abyssal_bar',48,'Abyssal Steel Bar — offline tint approximation')+
             img('ref_abyssal_pick',48,'Existing Abyssal Steel Pick')+
             '<small>Material context: steel and abyssal bars (offline tint approximations), '
             'then the existing abyssal pick.</small></div>',
             '<p class="note">Offline projections, not engine captures. Closed containers use cubes; '
             'open chests use the existing chest_open.obj and its UVs. All views use the same camera '
             'and lighting. The small copy is a distance-reading aid, not a fixed in-game distance.</p>']
    for variant, heading in (("a", "A / Strapped timber"), ("b", "B / Enclosed plating"),
                             ("pick", "Recommended / Steel A + Abyssal B")):
        page.append(f'<h3 style="margin-top:30px">{heading}</h3>')
        for obj, title in (("chest", "Chest"), ("locked", "Locked chest"), ("bookshelf", "Bookshelf"),
                           ("vessels", "Vessels shelf"), ("open", "Open chest · inside and lid")):
            page.append(f'<p class="family-label">{title}</p><div class="comparison">')
            for tier, tier_name in (("wood", "Wooden · current"), ("steel", "Steel-Reinforced · T3"), ("abyssal", "Abyssal · T6")):
                v = ("a" if tier == "steel" else "b") if variant == "pick" else variant
                suffix = "" if tier == "wood" else "_" + v
                stem = f"view_{tier}_{obj}{suffix}"
                label = tier_name + ("" if tier == "wood" else f" · {v.upper()}")
                page.append(f'<div class="object"><h3>{label}</h3>'
                            f'<img class="render" src="{stem}.png" width="240" height="260" alt="{label} {title}">'
                            f'<div class="distance">{img(stem,60,label,height=65)}<span>Small view</span></div></div>')
            page.append('</div>')
    page += ['</section><section id="textures"><h2>03 / Texture sheets</h2>',
             '<p class="muted">Every tile at native size and 8× nearest-neighbour enlargement. '
             'The 16 × 32 inside is two 16 × 16 UV panels: lid above, floor below. '
             'All container candidates are fully opaque; race icons have transparent surrounds.</p>']
    for tier in ("wood", "steel", "abyssal"):
        for variant in (("",) if tier == "wood" else ("a", "b")):
            label = "Wooden originals" if tier == "wood" else f'{tier.title()} {variant.upper()}'
            page.append(f'<details open><summary>{label} · eight textures</summary><div class="texture-grid">')
            names = [(f"chest_{part}", f"Chest {part}") for part in PARTS]
            names += [("bookshelf", "Bookshelf front"), ("vessels", "Vessels shelf front"), ("shelf_side", "Shelf side / top")]
            for part, title in names:
                if tier == "wood":
                    stem = f"ref_wood_{part}"
                elif part.startswith("chest_"):
                    stem = f"chest_{tier}_{part[6:]}_{variant}"
                else:
                    stem = f"{part}_{tier}_{variant}"
                height = 32 if part == "chest_inside" else 16
                page.append(f'<div class="texture"><p>{title}</p><div class="samples">'
                            f'<div class="scale">{img(stem,16,title,height)}<small>1×</small></div>'
                            f'<div class="scale">{img(stem,128,title,height*8)}<small>8×</small></div></div>'
                            f'<code>{stem}.png</code></div>')
            page.append('</div></details>')
    page += ['</section><section id="handoff"><h2>04 / Handoff</h2>',
             '<p>Pick one race set and one treatment for each material tier. '
             'Each tier is a matching set of eight textures, shared by unlocked and locked chests '
             'and the two shelf types. A lock replaces only the front tile.</p>',
             '<p class="muted">Candidate files are in <code>../candidates/</code>. '
             'Regenerate with <code>python3 tools/r67_art/generate.py</code>; verify with '
             '<code>python3 tools/r67_art/generate.py --check</code>. '
             'The page and its images can be moved together and opened without a server.</p>',
             '<p class="note">Final acceptance: after the selected art is integrated, check all six races '
             'in Social on desktop and web; inspect each tier from nearby and several metres away; '
             'check the lock, lid seam and open interior, and rotate both shelf types.</p>',
             '</section><footer>Grudgelands · Round 67 ART · Original candidates drawn in Python. '
             'Existing class, faction and wooden textures are local comparison assets; their repository '
             'licence declarations remain applicable. No candidate is installed by this page.</footer>',
             '</main></body></html>']
    OUTPUTS["preview/index.html"] = "\n".join(page).encode()


def contact_sheets(icons, views, refs):
    font = ImageFont.load_default()
    im = Image.new("RGB", (1080, 470), BG)
    d = ImageDraw.Draw(im)
    d.text((22, 16), "RACE A / COLOURED HEADS - recommended", font=font, fill="#d8cda7")
    d.text((22, 228), "RACE B / CARVED PROFILES", font=font, fill="#d8cda7")
    for row, variant in enumerate(("a", "b")):
        for col, race in enumerate(RACES):
            x, y = 22 + col * 176, 48 + row * 212
            d.text((x, y), race.title(), font=font, fill="#e6dfcf")
            for offset, size in ((0, 16), (30, 32), (76, 64)):
                a = icons[f"race_{race}_{variant}"].resize((size, size), NEAREST)
                im.paste(a, (x + offset, y + 30 + 64 - size), a)
                d.text((x + offset, y + 102), str(size), font=font, fill="#a9b4bf")
    for i, key in enumerate([f"class_{c}" for c in CLASSES] + ["faction_accord", "faction_throng"]):
        a = refs[key].resize((32, 32), NEAREST)
        im.paste(a, (22 + i * 176, 422), a)
        d.text((64 + i * 176, 429), key.split("_")[1].title(), font=font, fill="#a9b4bf")
    emit("preview/race_contact.png", im)
    im = Image.new("RGB", (1200, 1160), BG)
    d = ImageDraw.Draw(im)
    headers = ("Wooden / current", "Steel A / straps", "Steel B / plate", "Abyssal A / straps", "Abyssal B / plate")
    keys = ("wood", "steel_a", "steel_b", "abyssal_a", "abyssal_b")
    for col, (key, title) in enumerate(zip(keys, headers)):
        d.text((col * 240 + 12, 16), title, font=font, fill="#d8cda7")
        for row, obj in enumerate(("chest", "locked", "bookshelf", "vessels", "open")):
            a = views[(key, obj)].resize((192, 208), NEAREST)
            im.paste(a, (col * 240 + 22, row * 220 + 28), a)
            d.text((col * 240 + 12, row * 220 + 228), obj.title(), font=font, fill="#a9b4bf")
    emit("preview/container_contact.png", im)


def build():
    refs = load_references()
    icons = {}
    textures = {}
    for race in RACES:
        for variant, draw in (("a", portrait), ("b", profile)):
            name = f"race_{race}_{variant}"
            icons[name] = candidate(name, draw(race))
    for tier in ("steel", "abyssal"):
        for variant in ("a", "b"):
            for face in PARTS:
                name = f"chest_{tier}_{face}_{variant}"
                textures[name] = candidate(name, chest(tier, variant, face))
            for part in ("bookshelf", "vessels", "shelf_side"):
                name = f"{part}_{tier}_{variant}"
                im = shell(tier, variant, top=True) if part == "shelf_side" else shelf(tier, variant, part == "vessels")
                textures[name] = candidate(name, im)
    views = {}
    for tier, variant in (("wood", ""), ("steel", "a"), ("steel", "b"), ("abyssal", "a"), ("abyssal", "b")):
        for obj in ("chest", "locked", "bookshelf", "vessels", "open"):
            if obj in ("chest", "locked", "open"):
                parts = ("top", "top", "side", "side", "lock" if obj == "locked" else "front", "inside")
                tiles = [refs[f"wood_chest_{part}"] if tier == "wood" else textures[f"chest_{tier}_{part}_{variant}"] for part in parts]
            else:
                side = refs["wood_shelf_side"] if tier == "wood" else textures[f"shelf_side_{tier}_{variant}"]
                front = refs[f"wood_{obj}"] if tier == "wood" else textures[f"{obj}_{tier}_{variant}"]
                tiles = [side, side, side, side, front, front]
            im = render_box(tiles, obj == "open")
            suffix = "_" + variant if variant else ""
            emit(f"preview/view_{tier}_{obj}{suffix}.png", im)
            views[(tier + suffix, obj)] = im
    preview_page()
    contact_sheets(icons, views, refs)


def validate():
    """Export checks, not game fixtures; run in both generation modes."""
    candidates = {name: data for name, data in OUTPUTS.items() if name.startswith("candidates/")}
    assert len(candidates) == 44
    for name, data in candidates.items():
        im = Image.open(BytesIO(data))
        race = Path(name).name.startswith("race_")
        expected = (64, 64) if race else (16, 32) if "_inside_" in name else (16, 16)
        assert im.size == expected and im.mode == "RGBA", name
        alpha = np.array(im)[:, :, 3]
        if race:
            assert set(np.unique(alpha)) == {0, 255}, name
            assert not (alpha[0].any() or alpha[-1].any() or alpha[:, 0].any() or alpha[:, -1].any()), name
        else:
            assert np.all(alpha == 255), name
        assert OUTPUTS[name.replace("candidates/", "preview/")] == data, name

    class LocalPage(HTMLParser):
        def handle_starttag(self, tag, attrs):
            assert tag not in ("script", "iframe"), tag
            for attr, value in attrs:
                if attr in ("src", "href") and not value.startswith("#"):
                    assert ":" not in value and not value.startswith("/"), value
                    assert "preview/" + value in OUTPUTS, value

    LocalPage().feed(OUTPUTS["preview/index.html"].decode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated PNGs and HTML without writing.")
    args = parser.parse_args()
    build()
    validate()
    drift = []
    for name, data in sorted(OUTPUTS.items()):
        path = HERE / name
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                drift.append(name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    expected = set(OUTPUTS)
    actual = {str(p.relative_to(HERE)) for folder in ("candidates", "preview")
              for p in (HERE / folder).rglob("*") if p.is_file()}
    extra = sorted(actual - expected)
    if drift or extra:
        for name in drift:
            print("MISSING OR DIFFERENT:", name)
        for name in extra:
            print("UNEXPECTED FILE:", name)
        raise SystemExit(1)
    print(f'{"Verified" if args.check else "Wrote"} {len(OUTPUTS)} files; 12 race icons, 32 container textures; preview/index.html')


if __name__ == "__main__":
    main()
