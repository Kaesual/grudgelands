#!/usr/bin/env python3
"""Original swamp leaves by GPT-6 Astra, 2026-10-13, CC0-1.0.

Run: python3 tools/r47_art/swamp/generate_leaves.py
Requires Python 3 and Pillow. The new texture is drawn from the original
clusters below on a blank canvas; no source pixels or downloads are used.
Existing art is opened only for the comparison sheet, which is CC BY-SA 3.0.
Labels reuse the original CC0 font in the sibling generate.py.
"""

from pathlib import Path
from runpy import run_path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NEAREST = Image.Resampling.NEAREST
CLEAR = (0, 0, 0, 0)
label = run_path(str(HERE / "generate.py"))["label"]


def rgba(value):
    return tuple(bytes.fromhex(value)) + (255,)


# Dark olive shadows, subdued yellow-green faces and a few tired brown tips.
PALETTE = {
    "d": "303727", "s": "424b31", "m": "58603c",
    "l": "6b7147", "h": "808357", "t": "767149",
}

# Unequal, differently turned leaf groups. Corner and edge groups wrap onto
# the opposite side, so neither the mask nor the shading has a tile border.
CLUSTERS = [
    (14, 14, [".lm...", "lmms..", "mmsd.l", "sd..lm", "...hms", "..lmsd"]),
    (6, 1, [".hmm..", "hlmls.", ".mssds", "..d.lm", "...lms", "....sd"]),
    (1, 6, ["..hl..", ".lmms.", "tmssds", ".sd.lm", "...lms", "..msd."]),
    (10, 8, ["..lm..", "hlmms.", ".msdsl", "..s.lm", ".lmms.", "..sd.."]),
    (5, 13, [".l..", "hlms", "lmss", ".ds.", ".lm.", "..sd"]),
    (14, 4, [".hlm", "lmss", "m.d.", "s..."]),
    (7, 8, ["lm", "sd"]),
    (10, 15, ["lm.", "msd"]),
    (14, 11, ["..l.", ".lms", "lmss", ".sd."]),
    (6, 5, ["lm.", "mss", ".ms", "..d"]),
    (9, 12, [".lm", "mss", ".ds"]),
    (3, 3, [".lt", "mss", ".d."]),
]


def leaves():
    out = Image.new("RGBA", (16, 16), CLEAR)
    for x, y, rows in CLUSTERS:
        for dy, row in enumerate(rows):
            for dx, key in enumerate(row):
                if key != ".":
                    out.putpixel(((x + dx) % 16, (y + dy) % 16), rgba(PALETTE[key]))
    return out


def repeat(tile, columns, rows):
    out = Image.new("RGBA", (tile.width * columns, tile.height * rows), CLEAR)
    for y in range(rows):
        for x in range(columns):
            out.paste(tile, (x * tile.width, y * tile.height))
    return out


def show(canvas, tile, x, y, scale):
    canvas.alpha_composite(tile.resize((tile.width * scale, tile.height * scale), NEAREST), (x, y))


def gravewood_leaves(source):
    """Preview the registered default_leaves.png^[colorize:#858585:210.

    Engine source: reference_projects/luanti/src/client/imagesource.cpp,
    apply_colorize, and irr/include/SColor.h, SColor::getInterpolated.
    Opaque channels round to nearest after blending 210/255 grey into them;
    transparent texels remain transparent. Neither input has partial alpha.
    """
    out = source.copy()
    for y in range(source.height):
        for x in range(source.width):
            pixel = source.getpixel((x, y))
            if pixel[3]:
                rgb = tuple((channel * 45 + 133 * 210 + 127) // 255 for channel in pixel[:3])
                out.putpixel((x, y), rgb + (255,))
    return out


def leaf_pad(tile, bark, moss):
    """Front view: a 3x2 leaf pad, a two-node trunk and hanging moss."""
    out = Image.new("RGBA", (48, 64), CLEAR)
    out.paste(repeat(tile, 3, 2), (0, 0))
    out.alpha_composite(repeat(bark, 1, 2), (16, 32))
    for x in (0, 16, 32):
        out.alpha_composite(moss, (x, 32))
    return out


def preview(tile):
    def read(path):
        with Image.open(ROOT / path) as source:
            return source.convert("RGBA")

    jungle = read("mods/BASE/default/textures/default_jungleleaves.png")
    grey = gravewood_leaves(read("mods/BASE/default/textures/default_leaves.png"))
    bark = read("mods/ITEMS/grug_trees/textures/grug_trees_gravewood_tree.png")
    moss = read("tools/r47_art/swamp/hanging_moss.png")
    carpet = read("tools/r47_art/swamp/moss_carpet_top.png")
    grass = read("tools/r47_art/swamp/wet_grass_top.png")
    width, column, height = 1360, 680, 1360
    out = Image.new("RGBA", (width, height), CLEAR)
    draw = ImageDraw.Draw(out)
    for c, bg, ink, rule in [
        (0, "e0ddd0", "30392d", "b8b9a9"),
        (1, "222b28", "d2d4bf", "4b5750"),
    ]:
        x0 = c * column
        draw.rectangle((x0, 0, x0 + column - 1, height - 1), fill=rgba(bg))

        def text(x, y, words, scale=2):
            label(out, x0 + x, y, words, rgba(ink), scale)

        def divider(y):
            draw.line((x0 + 24, y, x0 + column - 25, y), fill=rgba(rule))

        text(24, 22, "GRUDGELANDS / SWAMP LEAVES", 3)
        text(24, 54, "R47 ART / GPT-6 ASTRA / OLIVE")
        text(24, 76, "LIGHT BACKGROUND" if c == 0 else "DARK BACKGROUND")
        divider(100)
        text(24, 116, "SWAMP LEAVES / 16X16 RGBA / CC0")
        show(out, tile, x0 + 24, 198, 1)
        show(out, tile, x0 + 80, 148, 8)
        show(out, repeat(tile, 4, 4), x0 + 348, 148, 3)
        text(24, 292, "1X")
        text(128, 292, "8X")
        text(348, 356, "4X4 TILES / 3X")
        text(24, 330, "ALL FACES / CUTOUT")
        text(24, 352, "REPEATS ON BOTH AXES")

        divider(386)
        text(24, 402, "FOLIAGE COMPARISON / 1X AND 8X")
        for i, (name, ref) in enumerate([
            ("JUNGLE LEAVES", jungle), ("GRAVEWOOD LEAVES", grey), ("HANGING MOSS", moss),
        ]):
            x = 24 + i * 220
            text(x, 434, name)
            show(out, ref, x0 + x, 522, 1)
            show(out, ref, x0 + x + 40, 464, 8)
            text(x, 608, "1X")
            text(x + 88, 608, "8X")
        text(24, 638, "GRAVEWOOD / GREY 858585 AT 210 OF 255")

        divider(672)
        text(24, 688, "NEIGHBOUR PALETTE / 8X")
        for i, (name, ref) in enumerate([
            ("GRAVEWOOD BARK", bark), ("MOSS CARPET", carpet), ("WET GRASS", grass),
        ]):
            x = 24 + i * 220
            text(x, 716, name)
            show(out, ref, x0 + x + 40, 742, 8)

        divider(896)
        text(24, 912, "FRONT VIEW / 3X2 LEAF NODES / 6X")
        show(out, leaf_pad(tile, bark, moss), x0 + 24, 944, 6)
        text(344, 960, "3X2 LEAF PAD")
        text(344, 982, "EXACT TILE REPEAT")
        text(344, 1148, "HANGING MOSS")
        text(344, 1170, "OVER DARK BARK")
        text(344, 1252, "COMPARISON / CC BY-SA 3.0", 1)
        text(344, 1274, "CREDITS / LICENSE-MEDIA.MD", 1)
        text(344, 1296, "NEAREST / NO FILTERING")
        text(24, 1340, "TEXTURE + GENERATOR / ORIGINAL CC0 WORK")
    return out


def main():
    tile = leaves()
    tile.save(HERE / "swamp_leaves.png", compress_level=9)
    preview(tile).save(HERE / "preview-leaves.png", compress_level=9)
    print("Wrote swamp_leaves.png (16x16 RGBA) and preview-leaves.png (1360x1360 RGBA)")


if __name__ == "__main__":
    main()
