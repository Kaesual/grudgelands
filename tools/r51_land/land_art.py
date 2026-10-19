#!/usr/bin/env python3
"""Round 51 ARTL, passes 1 and 3: original pixel work, GPT-6 Astra, CC0-1.0.

Run with python3 -I tools/r51_land/land_art.py (installed Pillow only).
New art starts on blank canvases; existing pixels are read only for previews.
No writes to swamp/, mods/, the viewer or any other generator. The comparison
sheets include attributed CC BY-SA media; their licence is recorded in README.
"""

import argparse
import io
from pathlib import Path
from statistics import mean
import hashlib
import json
import re
import runpy

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT = ROOT / "mods/BASE/default/textures"
NODES = ROOT / "mods/ITEMS/grug_nodes/textures"
SWAMP = HERE / "swamp"
NEAREST = Image.Resampling.NEAREST
# Reuse the CC0 material-field helpers, without running that script's main.
HELPERS = runpy.run_path(str(HERE / "swamp_art.py"))
material, paint = HELPERS["material"], HELPERS["paint"]
FONT = runpy.run_path(str(ROOT / "tools/r47_art/swamp/generate.py"))["FONT_ROWS"]
FONT = dict(FONT, **{"_": "000/000/000/000/111", "=": "000/111/000/111/000"})


def rgba(hexcode):
    return tuple(bytes.fromhex(hexcode)) + (255,)


def pixels(image):
    return list(image.get_flattened_data())


def opened(path):
    with Image.open(path) as image:
        return image.convert("RGBA")


def field(seed, palette, size=32, weights=(.18, .43, .34, .05)):
    return paint(material(seed, size, weights), palette)


def wrapped_stamp(canvas, sprite, x, y):
    """Every drawn pixel wraps, including alpha. No edge-copying or filtering."""
    for sy in range(sprite.height):
        for sx in range(sprite.width):
            p = sprite.getpixel((sx, sy))
            if p[3]:
                canvas.putpixel(((x + sx) % canvas.width, (y + sy) % canvas.height), p)


def sprite(rows, palette):
    assert len({len(r) for r in rows}) == 1
    out = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                out.putpixel((x, y), rgba(palette[key]))
    return out


def turned(image, quarter_turns):
    for _ in range(quarter_turns % 4):
        image = image.transpose(Image.Transpose.ROTATE_90)
    return image


def ground_art():
    out = {}
    out["swamp_moss_top_32"] = field(51110,
        ["303e2c", "374733", "3e5038", "485c40", "526647"],
        weights=(.10, .26, .60, .04))
    side = field(51111, ["292d24", "303529", "373c2e", "3f4333", "484b39"], 16)
    cap = field(51112, ["303e2c", "374733", "3e5038", "485c40", "526647"], 16,
                (.10, .26, .60, .04))
    for x, depth in enumerate([4, 5, 5, 4, 3, 3, 4, 6, 6, 5, 4, 4, 3, 4, 5, 4]):
        for y in range(depth):
            side.putpixel((x, y), cap.getpixel((x, y)))
        side.putpixel((x, depth), rgba("303c2b"))
    out["swamp_moss_side"] = side

    # Silver-ivory stays in the current side's colour family. Leaves are the
    # material, not high-contrast stamps: six loose nests and scattered folds.
    silver = field(51120, ["b0b7a0", "b7bea7", "bec5ae", "c4cbb5", "cad0bb"],
                   weights=(.15, .50, .31, .04))
    leaf = sprite(["..a.", ".abb", "abc.", ".c.."],
                  {"a": "cbd3bd", "b": "d2d8c5", "c": "b1b99f"})
    folded = sprite(["..a.", ".abb", "abc.", ".c.."],
                    {"a": "cad1bc", "b": "aeb89c", "c": "b8c0a7"})
    for cx, cy, pattern, offsets in [
            (1, 2, 0, [(0, 0), (3, 1), (0, 4)]),
            (19, 1, 1, [(0, 0), (3, -1)]),
            (10, 10, 3, [(0, 0), (-2, 3), (3, 2)]),
            (28, 16, 2, [(0, 0), (2, 4), (-2, 2)]),
            (4, 24, 1, [(0, 0), (4, 1)]),
            (20, 26, 3, [(0, 0), (-2, 4), (3, 3)])]:
        for i, (dx, dy) in enumerate(offsets):
            wrapped_stamp(silver, turned(leaf if i % 2 == 0 else folded, pattern + i),
                          cx + dx, cy + dy)
    out["silver_litter_top_32"] = silver

    out["blight_dirt_32"] = field(51130,
        ["4e435d", "554a64", "5d516b", "655973", "6c607a"],
        weights=(.22, .48, .25, .05))
    bone = field(51131, ["878479", "918e82", "9b988b", "a5a293", "afac9d"])
    # Weathered fragments belong to the ground, without a skeleton motif.
    for x, y, rot in [(1, 6, 0), (20, 2, 1), (11, 21, 2), (28, 25, 3)]:
        wrapped_stamp(bone, turned(sprite(["ab.", ".bc"],
            {"a": "b4b0a0", "b": "aaa696", "c": "999487"}), rot), x, y)
    out["bone_litter_top_32"] = bone
    out["mesa_clay_32"] = field(51132,
        ["945337", "9d593c", "a66041", "af6848", "b87150"],
        weights=(.19, .50, .27, .04))
    canopy = field(51133, ["193a2d", "1e4032", "244837", "2c503d", "345844"],
                   weights=(.13, .37, .46, .04))
    for x, y, rot in [(0, 5, 0), (16, 1, 2), (24, 15, 3), (10, 21, 1), (28, 30, 2)]:
        wrapped_stamp(canopy, turned(sprite(["..ab.", ".abbc", "abbc.", ".bc.."],
            {"a": "2d5140", "b": "335a46", "c": "244536"}), rot), x, y)
    out["canopy_litter_top_32"] = canopy

    # Strata come from placement, never horizontal lines baked into the tile.
    bands = {
        "ochre": ["aa804c", "b08852", "b8915a", "c09962", "c6a169"],
        "sienna": ["7f4737", "894e3d", "935643", "9c5e4b", "a56652"],
        "chalk": ["b4a18a", "bcaa92", "c4b29a", "ccbaa2", "d3c2ab"],
        "umber": ["75604f", "7e6856", "87715e", "907a66", "98816d"],
    }
    for i, (name, palette) in enumerate(bands.items()):
        out["clay_band_" + name + "_32"] = field(51140 + i, palette,
            weights=(.20, .49, .27, .04))
    out["sand_32"] = field(51150,
        ["ccbf98", "d0c49e", "d5caa6", "d9cfad", "ddd4b3"],
        weights=(.50, .37, .10, .03))
    return out


GREEN = {"s": "344d31", "g": "49643b", "l": "67834b", "v": "819352"}


def lichen_art():
    """Sparse crusts on exposed rock, with three small colonies per node.

    Lobed edges and occasional holes describe growth, without raised highlights,
    metallic sparkles, a filled ground layer, or a rectangular carpet outline.
    """
    sage = {"a": "929987", "b": "a7ad9c", "c": "7e8576"}
    grey = {"a": "a5a79b", "b": "b5b7a9", "c": "92978a"}
    ochre = {"a": "a39c84", "b": "afa68c", "c": "918c76"}
    rosettes = [
        sprite([".ab..", "abbca", "bc.cb", ".bca.", "..a.."], sage),
        sprite(["..a..", ".abb.", "abcba", ".b.b.", "..a.."], grey),
        sprite([".ab.", "abca", ".cb.", "..a."], sage),
    ]
    out = {}
    for suffix, placements, flecks in [
            ("", [(0, 1, 1, 0), (1, 10, 5, 1), (2, 4, 11, 2)],
             [(10, 1, "a"), (13, 12, "b"), (12, 13, "a")]),
            ("_b", [(1, 6, 0, 3), (0, 0, 7, 1), (2, 10, 10, 0)],
             [(2, 2, "a"), (3, 3, "b"), (7, 14, "a")])]:
        image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for which, x, y, rotation in placements:
            wrapped_stamp(image, turned(rosettes[which], rotation), x, y)
        # Only three dull ochre flecks: a minority among grey-green crusts.
        for x, y, color in flecks:
            image.putpixel((x, y), rgba(ochre[color]))
        out["lichen_carpet_top" + suffix] = image
    return out


def flower(stems, blooms, colors, leaves):
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    for points in stems:
        draw.line(points, fill=rgba(GREEN["s"]), width=1)
    for x, y, flip in leaves:
        leaf = sprite(["ll..", ".lgs", "..s."], GREEN)
        if flip:
            leaf = leaf.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        wrapped_stamp(out, leaf, x, y)
    for rows, x, y in blooms:
        wrapped_stamp(out, sprite(rows, colors), x, y)
    return out


def plant_art():
    out = {}
    vine_palette = {"s": "424631", "r": "686247", "a": "355135", "b": "4c7042", "c": "6f8a4c"}
    strand = sprite([
        ".......sr.......", ".......sr.......", "....bc.sr.......", "...bbcasr.......",
        "....ba.sr.......", ".....asr........", "......sr........", "......sr.ab.....",
        "......srabbc....", ".......srbc.....", ".......sra......", ".......sr.......",
        "...cb..sr.......", "...bbasr........", "....a..sr.......", ".......sr......."], vine_palette)
    end = sprite([
        ".......sr.......", ".......sr.......", ".......sr.ab....", ".......srabbc...",
        "........srbc....", "........sra.....", ".....bc.sr......", "....bbcasr......",
        ".....ba.sr......", "......asr.......", ".......sr.......", ".......s........",
        "......sr........", "......s.........", "................", "................"], vine_palette)
    out.update(liana_strand=strand, liana_end=end)

    out["flower_ruby_fan"] = flower(
        [[(7, 15), (7, 10), (5, 7)], [(7, 13), (10, 10)]],
        [(["a.a.a", "abbba", ".bcb.", "..d.."], 3, 5),
         (["a.a", "bcb", ".d."], 9, 8)],
        {"a": "c84448", "b": "a32d41", "c": "e4a55d", "d": "6b3840"},
        [(3, 12, False), (8, 11, True)])
    out["flower_ember_star"] = flower(
        [[(8, 15), (8, 10), (10, 7)], [(8, 13), (4, 10)]],
        [(["..a..", "babab", ".aca.", "babab", "..b.."], 8, 4),
         ([".a.", "bcb", ".b."], 3, 8)],
        {"a": "e69538", "b": "c65c2b", "c": "82412d"},
        [(4, 12, False), (9, 11, True)])
    out["flower_violet_fan"] = flower(
        [[(7, 15), (6, 10), (6, 7)], [(7, 13), (11, 9)]],
        [(["a.a.a", "abbba", ".bcb.", "..d.."], 4, 4),
         (["a.a", "bcb", ".d."], 10, 7)],
        {"a": "a875bd", "b": "805095", "c": "d8b56e", "d": "513d68"},
        [(2, 12, False), (9, 12, True)])
    out["flower_blush_star"] = flower(
        [[(6, 15), (6, 10), (5, 8)], [(6, 14), (11, 11)]],
        [(["..a..", "abcba", ".bdb.", "acbca", "..b.."], 3, 5),
         ([".a.", "bdb", ".b."], 10, 9)],
        {"a": "e2c5c2", "b": "d2a8b1", "c": "ebd4cf", "d": "a68a61"},
        [(2, 12, False), (8, 12, True)])
    out["flower_lilac_bells"] = flower(
        [[(8, 15), (8, 6), (5, 5)], [(8, 8), (11, 7)]],
        [([".s.", ".a.", "bab", "b.b"], 3, 5),
         ([".s.", ".a.", "bab", "b.b"], 10, 7)],
        {"s": GREEN["s"], "a": "aa9dbb", "b": "c9bdd6"},
        [(3, 12, False), (9, 12, True)])
    out["flower_cream_cups"] = flower(
        [[(7, 15), (7, 12), (4, 10)], [(7, 13), (10, 8)]],
        [(["a.a", "bcb", ".b."], 3, 8),
         (["a.a.a", ".bcb.", "..b.."], 8, 6)],
        {"a": "e1d9bf", "b": "c6bda0", "c": "b49e79"},
        [(3, 13, False), (9, 12, True)])

    dry = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    twig = sprite(["s...", ".s..", "..ss"], {"s": "796346"})
    for x, y, turn in [(0, 1, 1), (6, 6, 2), (12, 10, 3), (2, 12, 0)]:
        wrapped_stamp(dry, turned(twig, turn), x, y)
    for i, (x, y, turn) in enumerate([(0, 0, 0), (6, 1, 1), (12, 2, 3), (3, 5, 1),
                                     (10, 7, 2), (0, 10, 0), (6, 12, 3), (13, 13, 1)]):
        colors = {"a": "c4ac64", "b": "b29a55", "c": "8e7948"}
        if i % 3 == 0:
            colors = {"a": "d0b970", "b": "bba05a", "c": "9c824a"}
        wrapped_stamp(dry, turned(sprite([".a..", "abb.", ".bcc", "..c."], colors), turn), x, y)
    out["withered_bush_leaves"] = dry

    jungle = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for i, (x, y, turn) in enumerate([(0, 0, 0), (7, -2, 1), (11, 4, 2),
                                     (3, 6, 3), (8, 11, 0), (-2, 11, 1)]):
        colors = {"a": "2d5537", "b": "3e7144", "c": "5b8650", "d": "274630"}
        if i % 2:
            colors = {"a": "345d38", "b": "527f48", "c": "719456", "d": "2b4c32"}
        leaf = sprite(["..a...", ".abba.", "abcbba", "abcbbd", ".bcbd.", "..cd..", "..d..."], colors)
        wrapped_stamp(jungle, turned(leaf, turn), x, y)
    out["jungle_bush_leaves"] = jungle

    # Two dull organic colours in contiguous lobes, no metallic points or ore veins.
    crust = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    shape = material(51160, 16, (.08, .20, .68, .04))
    color = material(51161, 16, (.14, .27, .55, .04))
    for y in range(16):
        for x in range(16):
            v = shape[y][x]
            if v < -.45:
                continue
            orange = color[y][x] > .12
            colors = (["9c7b58", "b28d62", "c29c70"] if orange else
                      ["787b70", "909388", "a5a699"])
            crust.putpixel((x, y), rgba(colors[0 if v < -.1 else 1 if v < .75 else 2]))
    out["lichen_carpet_top"] = crust

    out["alpine_cushion"] = sprite([
        "................", "................", "................", "................",
        "................", "................", "................", "................",
        "................", ".....a....a.....", "...aba.a.aba....", "....abcacba.....",
        "..acbccbccbca...", "...bcbdbdbcb....", "....bdddddb.....", "......ddd......."],
        {"a": "a0a991", "b": "798773", "c": "5b6d59", "d": "475341"})
    out["alpine_windshrub"] = sprite([
        "................", "................", "................", "................",
        "................", "................", "................", "................",
        "................", "...aa......aa...", "...bbc..a..bb...", ".....scbbc.s....",
        "..aa..ss.ssa....", "..bbc..ssbbc....", "....ssssss......", ".......ss......."],
        {"a": "899b89", "b": "607a69", "c": "49624f", "s": "6c6250"})
    return out


def repeat(tile, w, h):
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, tile.height):
        for x in range(0, w, tile.width):
            out.paste(tile, (x, y))
    return out


def show(canvas, tile, x, y, scale=1):
    canvas.alpha_composite(tile.resize((tile.width * scale, tile.height * scale), NEAREST), (x, y))


def label(canvas, x, y, value, color, scale=2):
    # Original 3x5 CC0 glyphs, including a new underscore for filenames.
    draw = ImageDraw.Draw(canvas)
    for char in value.upper():
        for dy, row in enumerate(FONT[char].split("/")):
            for dx, bit in enumerate(row):
                if bit == "1":
                    xx, yy = x + dx * scale, y + dy * scale
                    draw.rectangle((xx, yy, xx + scale - 1, yy + scale - 1), fill=color)
        x += 4 * scale


THEMES = [("eee9dd", "373d35"), ("252d2b", "dddacb")]


def sheet(height, title, subtitle):
    out = Image.new("RGBA", (1600, height))
    for i, (bg, fg) in enumerate(THEMES):
        ImageDraw.Draw(out).rectangle((i * 800, 0, i * 800 + 799, height), fill=rgba(bg))
        label(out, i * 800 + 24, 22, title, rgba(fg))
        label(out, i * 800 + 24, 48, subtitle, rgba(fg), 1)
    return out


def mixed(tiles, rows):
    assert len({len(r) for r in rows}) == 1
    out = Image.new("RGBA", (len(rows[0]) * 16, len(rows) * 16))
    for y in range(out.height):
        for x in range(out.width):
            tile = tiles[rows[y // 16][x // 16]]
            out.putpixel((x, y), tile.getpixel((x % tile.width, y % tile.height)))
    return out


def ground_preview(art):
    old = {
        "swamp_moss_top_32": opened(DEFAULT / "default_moss.png"),
        "silver_litter_top_32": opened(NODES / "grug_nodes_silver_litter.png"),
        "blight_dirt_32": opened(NODES / "grug_nodes_blight_dirt.png"),
        "bone_litter_top_32": opened(NODES / "grug_nodes_bone_litter.png"),
        "mesa_clay_32": opened(NODES / "grug_nodes_mesa_clay.png"),
        "canopy_litter_top_32": opened(NODES / "grug_nodes_canopy_litter.png"),
        "sand_32": opened(DEFAULT / "default_sand.png"),
    }
    for name in art:
        if name.startswith("clay_band"):
            old[name] = old["mesa_clay_32"]
    rows = [name for name, tile in art.items() if tile.width == 32]
    start_mix = 80 + 298 * len(rows) + 180
    out = sheet(start_mix + 4 * 414 + 300, "R51 / LAND GROUNDS / ARTL PASS 1",
                "1X AND 4X SAMPLES / 8 X 8 NODE PATCHES AT 2X / NEAREST PIXELS")
    for i, name in enumerate(rows):
        y = 80 + i * 298
        for panel, (_, fg) in enumerate(THEMES):
            x = panel * 800 + 24
            show(out, art[name], x, y)
            show(out, art[name], x, y + 48, 4)
            label(out, x, y + 187, name + ".png", rgba(fg), 1)
            label(out, x, y + 205, "1X ABOVE / 4X BELOW", rgba(fg), 1)
            show(out, repeat(old[name], 128, 128), x + 202, y, 2)
            show(out, repeat(art[name], 128, 128), x + 478, y, 2)
            old_name = "TODAY / MESA CLAY" if name.startswith("clay_band") else "TODAY"
            if name.startswith("swamp_moss"):
                old_name = "TODAY / SHARED FOREST MOSS"
            label(out, x + 202, y + 266, old_name, rgba(fg), 1)
            label(out, x + 478, y + 266, name + ".png", rgba(fg), 1)
    y = start_mix - 172
    current_side = Image.alpha_composite(opened(DEFAULT / "default_dirt.png"),
                                        opened(NODES / "grug_nodes_silver_litter_side.png"))
    for panel, (_, fg) in enumerate(THEMES):
        x = panel * 800 + 24
        show(out, art["swamp_moss_side"], x, y)
        show(out, art["swamp_moss_side"], x + 32, y, 4)
        show(out, repeat(art["swamp_moss_side"], 128, 16), x + 202, y, 2)
        label(out, x, y + 78, "swamp_moss_side.png", rgba(fg), 1)
        label(out, x + 202, y + 42, "8 NODE HORIZONTAL SIDE / 2X", rgba(fg), 1)
        strip = Image.new("RGBA", (64, 32))
        strip.paste(repeat(art["silver_litter_top_32"], 64, 16), (0, 0))
        strip.paste(repeat(current_side, 64, 16), (0, 16))
        show(out, strip, x + 478, y, 2)
        label(out, x + 478, y + 76, "SILVER TOP / RETAINED SIDE", rgba(fg), 1)

    irregular = ["AAAAAAAABBBBBBBB", "AAAAAAABBBBBBBBB", "AAAAAAAABBBCCBBB",
                 "AAAAAABBBBCCCCBB", "AAAAABBBBCCCCCCB", "AAAAAABBBCCCCCBB",
                 "AAAAABBBBBCCCCBB", "AAABBBBBBBBCCBBB", "AABBBBBBBBBBBBBB", "AAABBBBBBBBBBBBB"]
    zones = [
        ("ELVES / SILVER LEAF CLUSTERS AND MUTED FOREST MOSS",
         {"A": art["silver_litter_top_32"], "B": opened(SWAMP / "moss_soil_top_32.png"),
          "C": opened(NODES / "grug_nodes_forest_litter.png")}, irregular,
         ["A silver_litter_top_32.png", "B moss_soil_top_32.png", "C grug_nodes_forest_litter.png"]),
        ("UNDEAD / COOL DIRT AND WEATHERED ASH LITTER",
         {"A": art["blight_dirt_32"], "B": art["bone_litter_top_32"],
          "C": opened(DEFAULT / "default_gravel.png")}, irregular,
         ["A blight_dirt_32.png", "B bone_litter_top_32.png", "C default_gravel.png"]),
        ("BADLANDS / SLOPE FACE / STRATA FOLLOW HEIGHT",
         {"M": art["mesa_clay_32"], "O": art["clay_band_ochre_32"],
          "S": art["clay_band_sienna_32"], "C": art["clay_band_chalk_32"],
          "U": art["clay_band_umber_32"]},
         ["MMMMMMMMMMMMMMMM", "MMMMMMMMMMMMMMMM", "OOOMMMMOOOOOOOOO", "OOOOOOOOOOOOOOOO",
          "CCCCCCCCCCCCCCCC", "SSSSSCCSSSSSSSSS", "SSSSSSSSSSSSSSSS", "MMMMMMMMMMMMMMMM",
          "UUUUMMMUUUUUUUUU", "UUUUUUUUUUUUUUUU"],
         ["M mesa_clay_32.png", "O clay_band_ochre_32.png", "C clay_band_chalk_32.png",
          "S clay_band_sienna_32.png", "U clay_band_umber_32.png"]),
        ("SWAMP / OWN MOSS BESIDE THE PICKED GROUNDS",
         {"A": art["swamp_moss_top_32"], "B": opened(SWAMP / "wet_grass_top_calm32.png"),
          "C": opened(SWAMP / "mud_mottled_top_calm32.png"), "D": opened(SWAMP / "mud_top_32.png"),
          "E": opened(SWAMP / "mud_dry_top_32.png")},
         ["AAAAAAAABBBBBBBB", "AAAAAAABBBBBBBBB", "AAAAAABBBBCCBBBB", "AAAAAABBBCCCCBBB",
          "AAAAABBBCCDDCCBB", "EEAABBBCCDDDCCBB", "EEEABBCCDDDDDCCB", "EEEEBBCCDDDDCCBB",
          "EEEEBBBCCDDCCBBB", "EEEBBBBBCCCCBBBB"],
         ["A swamp_moss_top_32.png", "B wet_grass_top_calm32.png", "C mud_mottled_top_calm32.png",
          "D mud_top_32.png", "E mud_dry_top_32.png"]),
    ]
    for i, (title, tiles, layout, legend) in enumerate(zones):
        patch = mixed(tiles, layout)
        if title.startswith("BADLANDS"):
            # Orthographic exposed face with a stepped slope silhouette. Bands
            # retain world height while the face climbs to the mesa's plateau.
            for column, height in enumerate([4, 3, 3, 2, 2, 1, 1, 0, 0, 0, 0, 1, 1, 2, 2, 3]):
                if height:
                    ImageDraw.Draw(patch).rectangle((column * 16, 0, column * 16 + 15, height * 16 - 1),
                                                    fill=(0, 0, 0, 0))
        for panel, (_, fg) in enumerate(THEMES):
            x, y = panel * 800 + 24, start_mix + i * 414
            label(out, x, y, title, rgba(fg), 1)
            show(out, patch, x, y + 22, 2)
            for j, line in enumerate(legend):
                label(out, x + 526, y + 36 + j * 22, line, rgba(fg), 1)
            label(out, x, y + 356, "16 X 10 NODES / CONTINUOUS WORLD PHASE / 2X", rgba(fg), 1)
    # Underwater is a labelled colour-context aid, not a claim about engine water.
    for panel, (_, fg) in enumerate(THEMES):
        x, y = panel * 800 + 24, start_mix + 4 * 414
        label(out, x, y, "SAND / DRY AND SIMPLE WATER COLOUR CONTEXT", rgba(fg), 1)
        for j, (name, tile) in enumerate([("DRY", art["sand_32"]),
                                         ("SHALLOW", art["sand_32"]), ("DEEPER", art["sand_32"])]):
            patch = repeat(tile, 96, 96)
            if j:
                patch = Image.alpha_composite(patch, Image.new("RGBA", patch.size,
                    (49, 100, 112, 65 if j == 1 else 120)))
            show(out, patch, x + 248 * j, y + 24, 2)
            label(out, x + 248 * j, y + 230, "sand_32.png / " + name, rgba(fg), 1)
    return out


def gathering():
    """Read catalog strings, then honour Round 48 world-sprite overrides.

    No Lua execution. The small parser fails on an unrecognised catalog row.
    Numeric colorize uses round-to-nearest SColor interpolation on nonzero alpha
    (Luanti imagesource.cpp apply_colorize; irr/include/SColor.h getInterpolated).
    """
    lookup = {p.name: p for p in (ROOT / "mods").rglob("*.png")}
    text = (ROOT / "mods/ITEMS/grug_gathering/catalog.lua").read_text()
    blocks = re.findall(r'\tp9g\("wp33_(\w+)_source_v1",(.*?)(?=\n\tp9g\(|\n})', text, re.S)
    result = {}
    for key, block in blocks:
        expressions = re.findall(r'"([^"\n]+\.png(?:\^\[colorize:#[0-9a-f]+:\d+)?)"', block)
        assert len(expressions) == 1, key
        expr = expressions[0]
        scale = 1.0
        if key in ("corn", "potato", "melon", "mushroom"):
            expr, scale = "grug_farming_" + key + "_4.png", 1.15
        elif key in ("sunleaf", "gravemoss", "wild_cocoa"):
            expr = "grug_gathering_" + key + "_plant.png"
        base, *modifier = expr.split("^[colorize:")
        image = opened(lookup[base])
        if modifier:
            color, amount = modifier[0].split(":")
            target, amount = rgba(color[1:]), int(amount)
            image.putdata([tuple((c * (255 - amount) + t * amount + 127) // 255
                                 for c, t in zip(p, target)) if p[3] else p
                           for p in pixels(image)])
        result[key] = (image, expr, scale)
    assert len(result) == 12
    return result


def standing(image, ground, bg, width=32, scale=1.0):
    out = Image.new("RGBA", (width, 32), rgba(bg))
    out.paste(repeat(ground, width, 12), (0, 20))
    image = image.resize((round(image.width * scale), round(image.height * scale)), NEAREST)
    out.alpha_composite(image, ((width - image.width) // 2, 20 - image.height))
    return out


def plant_preview(art, grounds, refs):
    # Each flower has its own adjacent complete biome-family gathering row.
    # Swamp neighbours and endgame sources are deliberately included as well.
    flowers = [n for n in art if n.startswith("flower")]
    atlas_height = 90 + 4 * 190
    comparison_top = atlas_height + 520
    out = sheet(comparison_top + len(flowers) * 230 + 860,
                "R51 / LAND PLANTS / ARTL PASS 1",
                "1X AND 4X / BINARY ALPHA / CURRENT WORLD GATHERING SPRITES")
    for panel, (bg, fg) in enumerate(THEMES):
        ox = panel * 800 + 24
        for i, (name, tile) in enumerate(art.items()):
            x, y = ox + (i % 4) * 190, 90 + (i // 4) * 190
            show(out, tile, x, y)
            show(out, tile, x + 28, y, 4)
            label(out, x, y + 76, name + ".png", rgba(fg), 1)
            label(out, x, y + 93, "1X / 4X", rgba(fg), 1)
            # A repeat also exposes alpha seams of the allfaces/carpet tiles.
            if name in ("withered_bush_leaves", "jungle_bush_leaves", "lichen_carpet_top"):
                show(out, repeat(tile, 32, 32), x + 108, y, 2)
                label(out, x + 104, y + 93, "2 X 2", rgba(fg), 1)

        y = atlas_height
        label(out, ox, y, "LIANA STACKS / 1 - 3 - 6 NODES TOTAL", rgba(fg), 1)
        for j, height in enumerate([1, 3, 6]):
            stack = Image.new("RGBA", (16, height * 16))
            for k in range(height - 1):
                stack.paste(art["liana_strand"], (0, k * 16))
            stack.paste(art["liana_end"], (0, (height - 1) * 16))
            x = ox + 34 + j * 180
            # Equal leaf-line attachment height, unscaled node pitch.
            show(out, repeat(art["jungle_bush_leaves"], 24, 8), x - 16, y + 24, 4)
            show(out, stack, x, y + 56, 4)
            label(out, x - 16, y + 448, "liana_strand.png", rgba(fg), 1)
            label(out, x - 16, y + 463, "liana_end.png", rgba(fg), 1)
        show(out, grounds["canopy_litter_top_32"], ox + 610, y + 320, 4)
        label(out, ox + 610, y + 463, "canopy_litter_top_32.png", rgba(fg), 1)

        for i, name in enumerate(flowers):
            tropical = i < 3
            keys = (["crimson_lotus", "sunleaf", "wild_cocoa", "melon", "mushroom", "stormkelp", "marshbloom"]
                    if tropical else ["sunleaf", "mushroom", "dragonweed", "marshbloom"])
            ground = grounds["canopy_litter_top_32" if tropical else "silver_litter_top_32"]
            y = comparison_top + i * 230
            label(out, ox, y, "JUNGLE / DECOR AND GATHERING" if tropical else
                  "ELF FORESTS / DECOR AND GATHERING", rgba(fg), 1)
            show(out, standing(art[name], ground, bg, 24), ox, y + 22, 4)
            label(out, ox, y + 158, name + ".png", rgba(fg), 1)
            for j, key in enumerate(keys):
                im, expr, scale = refs[key]
                x = ox + 124 + j * 88
                show(out, standing(im, ground, bg, 20, scale), x, y + 22, 4)
                label(out, x, y + 158, key, rgba(fg), 1)
                basename = expr.split("^[")[0]
                for line in range((len(basename) + 19) // 20):
                    label(out, x, y + 172 + line * 10, basename[line * 20:(line + 1) * 20], rgba(fg), 1)
            label(out, ox, y + 208, "EXACT COLOUR MODIFIERS AND WILD SCALES IN REGISTER BELOW", rgba(fg), 1)

        y = comparison_top + len(flowers) * 230
        label(out, ox, y, "BUSHES AND CRAGS / ZONE GROUND CONTEXT / 4X", rgba(fg), 1)
        others = [("withered_bush_leaves", grounds["mesa_clay_32"]),
                  ("jungle_bush_leaves", grounds["canopy_litter_top_32"]),
                  ("alpine_cushion", opened(DEFAULT / "default_gravel.png")),
                  ("alpine_windshrub", opened(DEFAULT / "default_snow.png"))]
        for j, (name, ground) in enumerate(others):
            x = ox + j * 190
            show(out, standing(art[name], ground, bg), x, y + 26, 4)
            label(out, x, y + 165, name + ".png", rgba(fg), 1)
        # Lichen as a carpet on stone and gravel, not a standing sprite.
        for j, ground in enumerate([opened(DEFAULT / "default_stone.png"), opened(DEFAULT / "default_gravel.png")]):
            patch = repeat(ground, 64, 32)
            patch.alpha_composite(repeat(art["lichen_carpet_top"], 32, 32), (16, 0))
            show(out, patch, ox + j * 300, y + 205, 4)
        label(out, ox, y + 345, "lichen_carpet_top.png / STONE AND GRAVEL / 4X", rgba(fg), 1)
        label(out, ox, y + 380, "CURRENT GATHERING SOURCE REGISTER / TEXTURE EXPRESSIONS", rgba(fg), 1)
        for j, (key, (im, expr, scale)) in enumerate(refs.items()):
            yy = y + 402 + j * 34
            show(out, im, ox, yy)
            label(out, ox + 42, yy + 2, key + " / " + expr.replace("^[colorize:#", " / COLORIZE "), rgba(fg), 1)
            if scale != 1:
                label(out, ox + 42, yy + 14, "WILD VISUAL SCALE 1.15 / DISPLAY ROUNDED TO NEAREST PIXEL", rgba(fg), 1)
    return out


def seam_report(image):
    """Compare wrap jumps with ordinary adjacent jumps; edges need not match.

    A periodic texture joins adjacent, different pixels, not duplicated border
    rows. Directional sides are assessed only horizontally; sprites don't tile.
    """
    def distance(a, b):
        # Compare premultiplied channels for transparent leaf/carpet textures.
        return sum(abs(a[i] * a[3] - b[i] * b[3]) / 255 for i in range(3)) / 3
    result = {}
    for axis in (0, 1):
        boundary, inside = [], []
        for y in range(image.height):
            for x in range(image.width):
                end = (x == image.width - 1) if axis == 0 else (y == image.height - 1)
                nxt = ((x + 1) % image.width, y) if axis == 0 else (x, (y + 1) % image.height)
                (boundary if end else inside).append(distance(image.getpixel((x, y)), image.getpixel(nxt)))
        result["xy"[axis]] = {"wrap_mean_rgb_jump": round(mean(boundary), 3),
                               "inside_mean_rgb_jump": round(mean(inside), 3)}
    return result


def validate(grounds, plants):
    records = {}
    tile_plants = {"withered_bush_leaves", "jungle_bush_leaves"} | {
        name for name in plants if name.startswith("lichen_carpet_top")}
    for folder, art in [("grounds", grounds), ("plants", plants)]:
        for name, expected in art.items():
            path = HERE / folder / (name + ".png")
            with Image.open(path) as image:
                size = 32 if name.endswith("_32") else 16
                assert image.mode == "RGBA" and image.size == (size, size), name
                assert image.tobytes() == expected.tobytes(), name
                alpha = {p[3] for p in pixels(image)}
                assert alpha == ({255} if folder == "grounds" else {0, 255}), (name, alpha)
                assert all(p == (0, 0, 0, 0) for p in pixels(image) if not p[3]), name
                record = {"size": list(image.size), "mode": image.mode, "alpha": sorted(alpha),
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                if name.startswith("lichen_carpet_top"):
                    record["opaque_pixels"] = sum(p[3] == 255 for p in pixels(image))
                    if not name.endswith("_v1"):
                        assert record["opaque_pixels"] < size * size / 4, name
                if folder == "grounds" or name in tile_plants:
                    record["seams"] = seam_report(image)
                    axes = [0] if name.endswith("_side") else [0, 1]
                    record["period"] = {}
                    for axis in axes:
                        period = next(d for d in range(1, size + 1) if size % d == 0 and all(
                            image.getpixel((x, y)) == image.getpixel(
                                ((x + d) % size, y) if axis == 0 else (x, (y + d) % size))
                            for y in range(size) for x in range(size)))
                        assert period == size, (name, axis, period)
                        record["period"]["xy"[axis]] = period
                records[str(path.relative_to(HERE))] = record
    strand, end = plants["liana_strand"], plants["liana_end"]
    assert strand.crop((0, 0, 16, 1)).tobytes() == strand.crop((0, 15, 16, 16)).tobytes()
    assert strand.crop((0, 0, 16, 1)).tobytes() == end.crop((0, 0, 16, 1)).tobytes()
    assert not end.getchannel("A").crop((0, 14, 16, 16)).getbbox()
    for name in ("preview-grounds.png", "preview-plants.png"):
        with Image.open(HERE / name) as image:
            assert image.mode == "RGBA" and image.getchannel("A").getextrema() == (255, 255)
            records[name] = {"size": list(image.size), "mode": image.mode,
                "sha256": hashlib.sha256((HERE / name).read_bytes()).hexdigest()}
    return {"classification": "compatible: art proposals only", "files": records,
            "liana_join": "strand top = strand bottom = end top; end tapers to alpha 0",
            "seam_method": "Toroidal fields and wrapped stamps; wrap jumps reported for visual audit. "
                           "Side y is directional. Plantlike silhouettes do not tile.",
            "preview_note": "Nearest-neighbour orthographic texture studies, not engine screenshots. "
                            "Crop visual_scale 1.15 is rounded to whole preview pixels. "
                            "Water context is a flat colour overlay; final appearance belongs to VIEW."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare every output without writing")
    args = parser.parse_args()
    grounds, original_plants = ground_art(), plant_art()
    plants = dict(original_plants)
    plants["lichen_carpet_top_v1"] = original_plants["lichen_carpet_top"]
    plants.update(lichen_art())
    outputs = {}
    for folder, art in [("grounds", grounds), ("plants", plants)]:
        for name, image in art.items():
            outputs[HERE / folder / (name + ".png")] = image
    # Preserve the historical pass-1 comparison; pass 3 has its own sheet.
    outputs[HERE / "preview-grounds.png"] = ground_preview(grounds)
    outputs[HERE / "preview-plants.png"] = plant_preview(original_plants, grounds, gathering())
    for path, image in outputs.items():
        stream = io.BytesIO()
        image.save(stream, format="PNG")
        if args.check:
            assert path.read_bytes() == stream.getvalue(), "Stale output: " + str(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(stream.getvalue())
    report = validate(grounds, plants)
    record = (json.dumps(report, indent=2) + "\n").encode("utf-8")
    path = HERE / "artl-checks.json"
    if args.check:
        assert path.read_bytes() == record, "Stale artl-checks.json"
    else:
        path.write_bytes(record)
    print(f"ARTL: {len(grounds)} grounds, {len(plants)} plants, two previews; size/mode/alpha/period/join checks passed.")


if __name__ == "__main__":
    main()
