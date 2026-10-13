#!/usr/bin/env python3
"""Original 16x16 swamp pixel art by GPT-6 Astra, CC0-1.0.

Run: python3 tools/r47_art/swamp/generate.py
Uses the already installed Pillow 12.3.0. No network, asset downloads,
external fonts, antialiasing, or source-image sampling for the new textures.
Existing mud and papyrus are opened only when assembling the comparison.
"""

from pathlib import Path
from random import Random

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NEAREST = Image.Resampling.NEAREST
CLEAR = (0, 0, 0, 0)


def rgba(value):
    return tuple(bytes.fromhex(value.lstrip("#"))) + (255,)


def periodic_field(seed):
    """Authored material grain on a torus; no independently treated edges."""
    rng = Random(seed)
    coarse = [[rng.random() for _ in range(4)] for _ in range(4)]
    fine = [[rng.random() for _ in range(16)] for _ in range(16)]
    result = []
    for y in range(16):
        row = []
        for x in range(16):
            gx, gy = x // 4, y // 4
            u, v = x % 4 / 4, y % 4 / 4
            a = coarse[gy][gx] * (1 - u) + coarse[gy][(gx + 1) % 4] * u
            b = coarse[(gy + 1) % 4][gx] * (1 - u)
            b += coarse[(gy + 1) % 4][(gx + 1) % 4] * u
            # Short paired grains avoid both smooth gradients and white noise.
            grain = (fine[y][x] + fine[y][(x + 1) % 16]) / 2
            row.append((a * (1 - v) + b * v) * 0.68 + grain * 0.32)
        result.append(row)
    return result


def grain(seed, colors):
    palette = [rgba(c) for c in colors]
    field = periodic_field(seed)
    out = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            t = max(0, min(0.999, (field[y][x] - 0.20) / 0.61))
            out.putpixel((x, y), palette[int(t * len(palette))])
    return out


def stamp(out, x, y, rows, palette):
    """Paint an original pixel cluster, wrapping in both tile directions."""
    for dy, row in enumerate(rows):
        for dx, char in enumerate(row):
            if char != ".":
                out.putpixel(((x + dx) % 16, (y + dy) % 16), palette[char])


def plants(rows, palette):
    if len(rows) != 16 or any(len(row) != 16 for row in rows):
        raise ValueError("Plant grids must be 16 x 16")
    out = Image.new("RGBA", (16, 16), CLEAR)
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char != ".":
                out.putpixel((x, y), rgba(palette[char]))
    return out


def textures():
    dry = grain(47011, ["51503b", "5b5941", "646149", "6c6850", "767157", "80795e"])
    for x, y in [(1, 2), (8, 5), (13, 10), (4, 13)]:
        stamp(dry, x, y, ["hh.", ".ss"], {"h": rgba("817a5d"), "s": rgba("55533e")})
    dry_side = grain(47012, ["393b2c", "454432", "514c37", "5b533d", "655d45", "70664a"])

    wet_side = grain(47013, ["282e23", "323629", "3b3f2e", "464633", "50503a", "5b573f"])
    wet = grain(47014, ["303527", "3a3e2d", "454633", "50513b", "5b5840", "686249"])
    water = {"s": rgba("232e28"), "w": rgba("2a3b33"), "r": rgba("3c5144"), "h": rgba("53644f")}
    # Three unequal pools, including a pool that continues across the left edge.
    stamp(wet, 14, 5, [".sss..", "swwrss", "swwwhs", ".swws.", "..ss.."], water)
    stamp(wet, 7, 1, [".sss.", "swrhs", ".sws.", "..s.."], water)
    stamp(wet, 10, 12, [".ss.", "swrh", ".ss."], water)

    grass_colors = ["203b23", "28482a", "31532d", "395e31", "446a37", "52753d"]
    grass = grain(47015, grass_colors)
    soil = {"s": rgba("34382a"), "m": rgba("484936"), "h": rgba("5a563c")}
    for x, y, rows in [
        (14, 3, [".ss.", "smms", ".shs"]),
        (6, 9, [".ss..", "smmhs", ".sms.", "..s.."]),
        (3, 0, ["sm", ".s"]),
    ]:
        stamp(grass, x, y, rows, soil)
    for x, y in [(2, 7), (8, 3), (12, 9), (1, 13), (10, 15)]:
        stamp(grass, x, y, [".h", "ms"], {"h": rgba("567b41"), "m": rgba("446a37"), "s": rgba("28482a")})
    grass_side = wet_side.copy()
    # Same green cap at every block, with a ragged horizontal root fringe.
    depths = [4, 5, 4, 3, 4, 6, 5, 4, 3, 4, 5, 6, 4, 3, 4, 4]
    for x, depth in enumerate(depths):
        for y in range(depth):
            grass_side.putpixel((x, y), grass.getpixel((x, y)))
        grass_side.putpixel((x, depth), rgba("293a25"))
    for x, y in [(1, 6), (5, 8), (10, 7), (14, 6)]:
        grass_side.putpixel((x, y), rgba("53563a"))

    moss = grain(47016, ["444f2e", "536039", "626e42", "72804c", "839056", "94a164"])
    # Cushion edges and holes are an independently seeded periodic mask.
    mask = periodic_field(47017)
    for y in range(16):
        for x in range(16):
            if mask[y][x] < 0.33:
                moss.putpixel((x, y), CLEAR)
            elif mask[y][x] < 0.36:
                moss.putpixel((x, y), rgba("4a5733"))

    reeds = plants([
        ".......h........",
        "..m....m........",
        "..h....m....h...",
        "..m....s....m...",
        "..m.h..m....m...",
        "..m..m.m..h.m...",
        "..s..m.m...mm...",
        ".hm...mm...sm.h.",
        "..mm..sm...mmh..",
        "...m...m..mm....",
        "...m.h.m..sm....",
        ".h.m..mm..mm....",
        "..mm..sm..ms.h..",
        "...m...m..m.m...",
        "...s...m..mms...",
        "...s...s..ss....",
    ], {"s": "465741", "m": "718469", "h": "96a380"})

    cattails = plants([
        ".......t........",
        ".......bs.......",
        "..t....hs.......",
        "..bs...bs.......",
        "..hs...m....t...",
        "..bs...m....bs..",
        "..m....m....hs..",
        "..m....m....bs..",
        "..m.h..m....m...",
        ".lm..l.m..l.m...",
        "..ml..lm..mlm.l.",
        "..ml..mm..smlm..",
        "...m.lsm..mml...",
        "...ml.mm..mm....",
        "...ms.sm..mm....",
        "...ss.sm..ss....",
    ], {"t": "ad9464", "b": "775235", "h": "936a42", "s": "493e29", "m": "627b49", "l": "87935d"})

    hanging = plants([
        ".ms..msm..ms.ms.",
        ".mshm.ms.hms.m..",
        ".sm..mhsm.ms.mh.",
        "..m..msm...m.sm.",
        ".hm..ms.h..mh.m.",
        "..ms..m.m..ms.m.",
        "..m.h.m.mh.m..m.",
        "..m.m.m..m.m..h.",
        "..h.m.sm.m.hm...",
        "....m..m.m..m...",
        "....mh.m.h..m...",
        "....m..mh...h...",
        "....h..m........",
        ".......m........",
        ".......h........",
        "................",
    ], {"s": "4c5e48", "m": "7b8968", "h": "a2ab82"})

    return [
        ("mud_dry_top", dry, "DRY MUD / TOP", "XY"),
        ("mud_dry_side", dry_side, "DRY MUD / SIDE", "XY"),
        ("mud_mottled_top", wet, "MOTTLED MUD / TOP", "XY"),
        ("mud_mottled_side", wet_side, "MOTTLED MUD / SIDE", "XY"),
        ("wet_grass_top", grass, "WET GRASS / TOP", "XY"),
        ("wet_grass_side", grass_side, "WET GRASS / SIDE", "X"),
        ("moss_carpet_top", moss, "MOSS CARPET / TOP", "XY"),
        ("reeds", reeds, "REEDS", ""),
        ("cattails", cattails, "CATTAILS", ""),
        ("hanging_moss", hanging, "HANGING MOSS", ""),
    ]


# An original 3x5 block font for the review labels; no font file is embedded.
FONT_ROWS = {
    "A": "010/101/111/101/101", "B": "110/101/110/101/110",
    "C": "011/100/100/100/011", "D": "110/101/101/101/110",
    "E": "111/100/110/100/111", "F": "111/100/110/100/100",
    "G": "011/100/101/101/011", "H": "101/101/111/101/101",
    "I": "111/010/010/010/111", "J": "001/001/001/101/010",
    "K": "101/101/110/101/101", "L": "100/100/100/100/111",
    "M": "101/111/111/101/101", "N": "101/111/111/111/101",
    "O": "010/101/101/101/010", "P": "110/101/110/100/100",
    "Q": "010/101/101/111/011", "R": "110/101/110/101/101",
    "S": "011/100/010/001/110", "T": "111/010/010/010/010",
    "U": "101/101/101/101/111", "V": "101/101/101/101/010",
    "W": "101/101/111/111/101", "X": "101/101/010/101/101",
    "Y": "101/101/010/010/010", "Z": "111/001/010/100/111",
    "0": "111/101/101/101/111", "1": "010/110/010/010/111",
    "2": "110/001/010/100/111", "3": "110/001/010/001/110",
    "4": "101/101/111/001/001", "5": "111/100/110/001/110",
    "6": "011/100/111/101/111", "7": "111/001/010/010/010",
    "8": "111/101/111/101/111", "9": "111/101/111/001/110",
    " ": "000/000/000/000/000", "/": "001/001/010/100/100",
    "-": "000/000/111/000/000", ".": "000/000/000/000/010",
    ":": "000/010/000/010/000", "+": "000/010/111/010/000",
}


def label(canvas, x, y, text, color, scale=2):
    draw = ImageDraw.Draw(canvas)
    for char in text:
        for dy, row in enumerate(FONT_ROWS[char].split("/")):
            for dx, bit in enumerate(row):
                if bit == "1":
                    xx, yy = x + dx * scale, y + dy * scale
                    draw.rectangle((xx, yy, xx + scale - 1, yy + scale - 1), fill=color)
        x += 4 * scale


def show(canvas, tile, x, y, scale):
    canvas.alpha_composite(tile.resize((tile.width * scale, tile.height * scale), NEAREST), (x, y))


def preview(assets):
    references = [
        ("", Image.open(ROOT / "mods/ITEMS/grug_nodes/textures/grug_nodes_mud.png").convert("RGBA"), "TODAY / MUD", "XY"),
        ("", Image.open(ROOT / "mods/BASE/default/textures/default_papyrus.png").convert("RGBA"), "TODAY / PAPYRUS", ""),
    ]
    rows = references + assets
    width, column, header, row_height = 1040, 520, 104, 196
    height = header + len(rows) * row_height + 104
    canvas = Image.new("RGBA", (width, height), rgba("e0ddd0"))
    draw = ImageDraw.Draw(canvas)
    for c, bg, ink, faint in [(0, "e0ddd0", "30392d", "b8b9a9"), (1, "222b28", "d2d4bf", "4b5750")]:
        x0 = c * column
        draw.rectangle((x0, 0, x0 + column - 1, height - 1), fill=rgba(bg))
        label(canvas, x0 + 24, 20, "GRUDGELANDS / SWAMP", rgba(ink), 3)
        label(canvas, x0 + 24, 48, "R47 ART / GPT-6 ASTRA", rgba(ink))
        label(canvas, x0 + 24, 72, "LIGHT BACKGROUND" if c == 0 else "DARK BACKGROUND", rgba(ink))
        for i, (_, tile, title, tiling) in enumerate(rows):
            y0 = header + i * row_height
            draw.line((x0 + 24, y0, x0 + column - 25, y0), fill=rgba(faint))
            label(canvas, x0 + 24, y0 + 12, title, rgba(ink))
            show(canvas, tile, x0 + 24, y0 + 96, 1)
            show(canvas, tile, x0 + 80, y0 + 40, 8)
            label(canvas, x0 + 24, y0 + 178, "1X", rgba(ink))
            label(canvas, x0 + 128, y0 + 178, "8X", rgba(ink))
            if tiling:
                patch = Image.new("RGBA", (64, 64), CLEAR)
                for ty in range(4):
                    for tx in range(4):
                        patch.paste(tile, (tx * 16, ty * 16))
                show(canvas, patch, x0 + 292, y0 + 40, 2)
                label(canvas, x0 + 272, y0 + 178, "4X4 TILES / 2X", rgba(ink))
                if tiling == "X":
                    label(canvas, x0 + 280, y0 + 26, "HORIZONTAL REPEAT", rgba(ink), 1)
            else:
                label(canvas, x0 + 280, y0 + 88, "ALPHA CUTOUT", rgba(ink))
                label(canvas, x0 + 280, y0 + 108, "TOP ATTACHMENT" if "HANGING" in title else "PLANTLIKE", rgba(ink))
        y0 = height - 84
        label(canvas, x0 + 24, y0, "10 ORIGINAL 16X16 RGBA TEXTURES / CC0", rgba(ink))
        label(canvas, x0 + 24, y0 + 20, "COMPARISON / CC BY-SA 3.0", rgba(ink))
        label(canvas, x0 + 24, y0 + 40, "MUD + PAPYRUS CREDITS / LICENSE-MEDIA.MD", rgba(ink), 1)
        label(canvas, x0 + 24, y0 + 56, "NEAREST NEIGHBOUR / NO FILTERING", rgba(ink))
    return canvas


def main():
    assets = textures()
    for name, texture, _, _ in assets:
        texture.save(HERE / (name + ".png"), compress_level=9)
    preview(assets).save(HERE / "preview.png", compress_level=9)
    print("Wrote 10 original 16x16 RGBA textures and preview.png")


if __name__ == "__main__":
    main()
