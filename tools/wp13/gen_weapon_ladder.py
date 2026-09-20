#!/usr/bin/env python3
"""Generate the one weapon/tool sprite ladder of Grudgelands (WP13, round 2).

ONE sprite convention for everything a character can hold: 16x16, the long
axis on the image's anti-diagonal, grip at the BOTTOM-LEFT and business end at
the TOP-RIGHT -- minetest_game's own tool convention, because the four
`default` tool families already use it and the player asked for that look.
Because the convention is one, the wield transform in
`mods/PLAYER/grug_visuals/wield_geometry.lua` is one too: every sprite below
puts its grip on the image anti-diagonal at pixel (3.4, 12.6), which is where
that file expects the fist.

Three sources feed the ladder, in decreasing order of borrowing:

1. `default_tool_steelsword.png`, `..._steelpick.png`, `..._steelaxe.png` and
   `..._steelshovel.png` are the SHAPE for sword, pick, axe and shovel. Every
   metal tier is that shape with its grey ramp mapped through a per-material
   lookup; the wooden handle pixels are copied unchanged.

   That mapping is not an invention: minetest_game's own bronze sword IS the
   steel sword with exactly such a table applied (verified pixel by pixel --
   `check_bronze_matches_upstream` below reproduces `default_tool_bronzesword.png`
   byte for byte and the script fails if it ever stops doing so).

2. Dagger, greataxe and staff have no upstream shape, so they are authored
   here as ASCII maps in the same convention and the same six-step grey ramp.

3. The starter staff is the staff map run through a WOOD ramp, so the
   below-ladder caster starter reads like the below-ladder `default:sword_wood`.

Licence: everything produced from source 1 or 2 is a derivative of
minetest_game's CC BY-SA 3.0 tool art (the ramp mapping of a borrowed shape,
and authored shapes that reuse its palette), so the whole output is CC BY-SA
3.0 -- see the LICENSE-media.md tables this script's rows are mirrored into.

Usage (from the repository root):

    python3 tools/wp13/gen_weapon_ladder.py            # write the PNGs
    python3 tools/wp13/gen_weapon_ladder.py --sheet <dir>   # + a review sheet

Deterministic: re-running it reproduces every byte.
"""

import os
import sys

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_TEX = os.path.join(REPO, "mods", "BASE", "default", "textures")
GEAR_TEX = os.path.join(REPO, "mods", "ITEMS", "grug_gear", "textures")
MATERIAL_TEX = os.path.join(REPO, "mods", "ITEMS", "grug_materials", "textures")

# The six grey steps minetest_game's sword uses. Every material ramp names
# exactly these, and anything in between (the pick/axe/shovel use more greys)
# is linearly interpolated.
ANCHORS = (104, 147, 166, 220, 234, 255)

# Wood, unchanged for every metal tier: a bronze sword and an abyssal steel
# sword have the same handle, exactly as the upstream ladder does.
WOOD = {
    "a": (57, 39, 18),
    "b": (79, 53, 13),
    "c": (108, 73, 19),
}

# key -> label -> the six anchor colours, dark to light.
MATERIALS = [
    ("bronze", "Bronze", [
        (127, 54, 3), (150, 78, 15), (173, 95, 27),
        (225, 119, 48), (255, 135, 61), (255, 159, 114)]),
    # Deliberately DARKER and duller than Steel across the whole ramp, not a
    # warmer version of it: at 16 px a hue difference of a few percent is
    # invisible and Iron read as Steel (round-2 review).
    ("iron", "Iron", [
        (62, 60, 58), (88, 85, 82), (104, 100, 96),
        (134, 129, 124), (150, 145, 139), (176, 170, 164)]),
    ("steel", "Steel", [
        (104, 104, 104), (147, 147, 147), (166, 166, 166),
        (220, 220, 220), (234, 234, 234), (255, 255, 255)]),
    ("silversteel", "Silversteel", [
		(112, 118, 124), (151, 158, 166), (174, 181, 189),
		(220, 226, 232), (236, 241, 246), (253, 255, 255)]),
    # Dark red-orange BODY with a bright ember core, rather than the even warm
    # orange it had: that ramp sat on top of Bronze's and the two tiers were
    # hard to tell apart (round-2 review). The bottom four steps are nearly
    # black-red, so the two bright steps read as heat inside the metal.
    ("embersteel", "Embersteel", [
        (40, 16, 16), (74, 24, 18), (110, 34, 20),
        (170, 52, 22), (246, 126, 30), (255, 226, 130)]),
    ("abyssal_steel", "Abyssal Steel", [
        (46, 36, 62), (72, 58, 94), (90, 74, 116),
        (136, 116, 166), (164, 144, 194), (212, 196, 234)]),
]

# The below-ladder starter staff. Not a metal: the "metal" steps of the staff
# map (its head and its two bands) become carved wood.
STARTER_WOOD = ("wood", "Wooden", [
    (62, 36, 16), (85, 57, 14), (101, 68, 22),
    (134, 96, 44), (150, 110, 56), (176, 136, 80)])

MATERIAL_BY_KEY = dict((key, (label, stops)) for key, label, stops in MATERIALS)


def ramp(stops):
    """L (0..255 grey) -> RGB, piecewise linear through the six anchors."""
    def lookup(value):
        if value <= ANCHORS[0]:
            return stops[0]
        if value >= ANCHORS[-1]:
            return stops[-1]
        for index in range(len(ANCHORS) - 1):
            low, high = ANCHORS[index], ANCHORS[index + 1]
            if low <= value <= high:
                span = float(high - low)
                t = (value - low) / span if span else 0.0
                a, b = stops[index], stops[index + 1]
                return tuple(int(round(a[i] + (b[i] - a[i]) * t))
                             for i in range(3))
        return stops[-1]
    return lookup


#
# Authored shapes. '.' transparent, '1'..'6' the six grey anchors (recoloured
# per material), 'a'/'b'/'c' the three wood tones (never recoloured).
#
# Every map puts its grip on the anti-diagonal through pixel (3, 12) -- the
# same place minetest_game's sword, pick, axe and shovel put theirs, which is
# what makes ONE wield transform correct for all of them.
#

DAGGER = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "........26......",
    ".......2631.....",
    "......26341.....",
    "..22.26341......",
    "..2626341.......",
    "...a5341........",
    "...ca51.........",
    "..caba61........",
    ".aab..11........",
    "26a.............",
    "21..............",
]

GREATAXE = [
    "..............ca",
    ".............ca.",
    "......64444.ca..",
    ".....664444ca...",
    "....664442ca....",
    ".....6642ca.....",
    "......62ca......",
    ".......ca.......",
    "......ca........",
    ".....ca.........",
    "....ca..........",
    "...ca...........",
    "..ca............",
    ".ca.............",
    "ca..............",
    "c...............",
]

STAFF = [
    "............466.",
    "...........46664",
    "...........4664.",
    "...........ca...",
    "..........ca....",
    ".........ca.....",
    "........33......",
    ".......ca.......",
    "......ca........",
    ".....22.........",
    "....ca..........",
    "...ca...........",
    "..ca............",
    ".ca.............",
    "ca..............",
    "c...............",
]

AUTHORED = {"dagger": DAGGER, "greataxe": GREATAXE, "staff": STAFF}

# Family -> the upstream sprite whose shape it borrows.
BORROWED = {
    "sword": "default_tool_steelsword.png",
    "pick": "default_tool_steelpick.png",
    "axe": "default_tool_steelaxe.png",
    "shovel": "default_tool_steelshovel.png",
}


def load_source(filename):
    path = os.path.join(DEFAULT_TEX, filename)
    return Image.open(path).convert("RGBA")


def recolour(source, stops):
    """Map every GREY pixel of `source` through the ramp; keep the rest."""
    lookup = ramp(stops)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    src, dst = source.load(), out.load()
    for y in range(source.size[1]):
        for x in range(source.size[0]):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            if r == g == b:
                colour = lookup(r)
                dst[x, y] = (colour[0], colour[1], colour[2], a)
            else:
                dst[x, y] = (r, g, b, a)
    return out


def paint(rows, stops):
    """Render an authored ASCII map."""
    lookup = ramp(stops)
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = out.load()
    for y, row in enumerate(rows):
        if len(row) != 16:
            raise SystemExit("map row %d is %d characters, not 16" % (y, len(row)))
        for x, char in enumerate(row):
            if char == ".":
                continue
            if char in WOOD:
                colour = WOOD[char]
            elif char in "123456":
                colour = lookup(ANCHORS[int(char) - 1])
            else:
                raise SystemExit("unknown map character %r" % char)
            px[x, y] = (colour[0], colour[1], colour[2], 255)
    return out


def grip_is_covered(image):
    """The fist sits on pixel (3, 12); a sprite with nothing there floats."""
    return image.load()[3, 12][3] > 0


def check_bronze_matches_upstream(sword_bronze):
    """The strongest check available without a client: our bronze sword must
    be minetest_game's bronze sword, pixel for pixel. If that holds, the ramp
    machinery reproduces upstream's own recolouring exactly."""
    upstream = load_source("default_tool_bronzesword.png")
    ours, theirs = sword_bronze.load(), upstream.load()
    for y in range(16):
        for x in range(16):
            if ours[x, y] != theirs[x, y]:
                return "pixel (%d,%d): %s vs upstream %s" % (
                    x, y, ours[x, y], theirs[x, y])
    return None


def write_png(image, path):
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        os.makedirs(directory)
    image.save(path, "PNG", optimize=True)


def build():
    """Return {path: Image} for everything this ladder ships."""
    produced = {}
    borrowed_sources = dict((family, load_source(name))
                            for family, name in BORROWED.items())

    for key, label, stops in MATERIALS:
        # Weapons live with grug_gear, one PNG per family and material.
        for family in ("sword", "dagger", "greataxe", "staff"):
            if family in AUTHORED:
                image = paint(AUTHORED[family], stops)
            else:
                image = recolour(borrowed_sources[family], stops)
            if not grip_is_covered(image):
                raise SystemExit("%s_%s has no pixel at the grip (3,12)"
                                 % (family, key))
            produced[os.path.join(
                GEAR_TEX, "grug_gear_item_%s_%s.png" % (family, key))] = image

    # The below-ladder caster starter.
    starter = paint(STAFF, STARTER_WOOD[2])
    produced[os.path.join(GEAR_TEX, "grug_gear_item_staff_wood.png")] = starter

    # Tools: `default` already ships wood/stone/bronze/steel, so only the four
    # metals it never had are generated here.
    for key, label, stops in MATERIALS:
        if key in ("bronze", "steel"):
            continue
        for family in ("pick", "axe", "shovel"):
            image = recolour(borrowed_sources[family], stops)
            if not grip_is_covered(image):
                raise SystemExit("%s_%s has no pixel at the grip (3,12)"
                                 % (family, key))
            produced[os.path.join(
                MATERIAL_TEX,
                "grug_materials_tool_%s%s.png" % (key, family))] = image
    return produced


SHEET_SCALE = 6
SHEET_PAD = 6
SHEET_LABEL = 12


def sheet(produced):
    """One review image: every weapon and tool of the ladder, labelled."""
    columns = [key for key, _, _ in MATERIALS] + ["wood"]
    rows = [
        ("Sword", GEAR_TEX, "grug_gear_item_sword_%s.png"),
        ("Dagger", GEAR_TEX, "grug_gear_item_dagger_%s.png"),
        ("Greataxe", GEAR_TEX, "grug_gear_item_greataxe_%s.png"),
        ("Staff", GEAR_TEX, "grug_gear_item_staff_%s.png"),
        ("Pickaxe", MATERIAL_TEX, "grug_materials_tool_%spick.png"),
        ("Axe", MATERIAL_TEX, "grug_materials_tool_%saxe.png"),
        ("Shovel", MATERIAL_TEX, "grug_materials_tool_%sshovel.png"),
    ]
    upstream = {
        ("Sword", "wood"): "default_tool_woodsword.png",
        ("Pickaxe", "bronze"): "default_tool_bronzepick.png",
        ("Pickaxe", "steel"): "default_tool_steelpick.png",
        ("Pickaxe", "wood"): "default_tool_woodpick.png",
        ("Axe", "bronze"): "default_tool_bronzeaxe.png",
        ("Axe", "steel"): "default_tool_steelaxe.png",
        ("Axe", "wood"): "default_tool_woodaxe.png",
        ("Shovel", "bronze"): "default_tool_bronzeshovel.png",
        ("Shovel", "steel"): "default_tool_steelshovel.png",
        ("Shovel", "wood"): "default_tool_woodshovel.png",
    }

    cell = 16 * SHEET_SCALE
    left = 70
    top = SHEET_LABEL + SHEET_PAD
    width = left + len(columns) * (cell + SHEET_PAD) + SHEET_PAD
    height = top + len(rows) * (cell + SHEET_PAD + SHEET_LABEL) + SHEET_PAD
    canvas = Image.new("RGBA", (width, height), (32, 32, 36, 255))
    draw = ImageDraw.Draw(canvas)

    for index, key in enumerate(columns):
        label = MATERIAL_BY_KEY[key][0] if key in MATERIAL_BY_KEY else "Wood/Stone"
        draw.text((left + index * (cell + SHEET_PAD), 2), label,
                  fill=(230, 230, 230, 255))

    for row_index, (family, directory, pattern) in enumerate(rows):
        y = top + row_index * (cell + SHEET_PAD + SHEET_LABEL)
        draw.text((4, y + cell // 2), family, fill=(230, 230, 230, 255))
        for col_index, key in enumerate(columns):
            x = left + col_index * (cell + SHEET_PAD)
            path = os.path.join(directory, pattern % key)
            note = ""
            if (family, key) in upstream:
                path = os.path.join(DEFAULT_TEX, upstream[(family, key)])
                note = "default"
            elif key == "wood" and family == "Staff":
                path = os.path.join(GEAR_TEX, "grug_gear_item_staff_wood.png")
                note = "starter"
            elif key == "wood":
                continue
            elif family == "Sword" and key in ("bronze", "steel"):
                note = ""
            if not os.path.exists(path):
                continue
            tile = Image.open(path).convert("RGBA").resize(
                (cell, cell), Image.NEAREST)
            canvas.alpha_composite(tile, (x, y))
            if note:
                draw.text((x, y + cell + 1), note, fill=(150, 150, 160, 255))
    return canvas


def main(argv):
    produced = build()
    failure = check_bronze_matches_upstream(
        produced[os.path.join(GEAR_TEX, "grug_gear_item_sword_bronze.png")])
    if failure:
        print("BRONZE CHECK FAILED: " + failure)
        return 1
    print("bronze sword reproduces default_tool_bronzesword.png exactly")
    for path, image in sorted(produced.items()):
        write_png(image, path)
    print("%d sprites written" % len(produced))

    if "--sheet" in argv:
        target = argv[argv.index("--sheet") + 1]
        if not os.path.isdir(target):
            os.makedirs(target)
        out = os.path.join(target, "weapon-ladder-sheet.png")
        sheet(produced).save(out, "PNG", optimize=True)
        print("sheet written to " + out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
