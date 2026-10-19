#!/usr/bin/env python3
"""Original Round 51 SWART pixel work by GPT-6 Astra, CC0-1.0.

Run: python3 -I tools/r51_land/swamp_art.py
Requires Pillow. Writes four opaque textures and their comparison sheet.
The new artwork uses authored palettes and seeded, toroidal material fields;
source images are read only for the preview. No downloads or image filtering.
The comparison includes existing CC BY-SA 3.0 media; see README.md.
"""

from bisect import bisect_right
from math import sqrt
from pathlib import Path
from random import Random
import runpy

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / "swamp"
OLD = ROOT / "tools/r47_art/swamp"
DEFAULT = ROOT / "mods/BASE/default/textures"
NODES = ROOT / "mods/ITEMS/grug_nodes/textures"
NEAREST = Image.Resampling.NEAREST

# Narrow middle values; the old mud's mean is about RGB (54, 55, 42).
MUD = ["2b2e24", "303327", "36382a", "3b3c2e", "414132"]
DRY = ["5c5943", "636048", "6a664e", "716c52", "777158"]
# Less saturated than wet grass, a little greener than the olive moss carpet.
MOSS = ["465a33", "4c6238", "546b3d", "5d7544", "687e4b"]
# Independently drawn warm dirt, visually compatible with the existing bottom.
DIRT = ["453422", "533c26", "62452b", "715034", "805c3d"]


def rgba(value):
    return tuple(bytes.fromhex(value)) + (255,)


def noise(seed, size):
    rng = Random(seed)
    return [[rng.random() for _ in range(size)] for _ in range(size)]


def normalize(values):
    size = len(values)
    mean = sum(map(sum, values)) / (size * size)
    dev = sqrt(sum((v - mean) ** 2 for row in values for v in row) / (size * size))
    return [[(v - mean) / dev for v in row] for row in values]


def soften(values, passes=1):
    """Binomial field convolution, wrapping both axes; never blur a bitmap."""
    size = len(values)
    for _ in range(passes):
        values = [[sum(values[(y + dy) % size][(x + dx) % size] * wx * wy
                       for dy, wy in [(-1, 1), (0, 2), (1, 1)]
                       for dx, wx in [(-1, 1), (0, 2), (1, 1)]) / 16
                   for x in range(size)] for y in range(size)]
    return normalize(values)


def blend(*layers):
    size = len(layers[0][1])
    return [[sum(weight * values[y][x] for weight, values in layers)
             for x in range(size)] for y in range(size)]


def paint(values, colors, cuts=(0.09, 0.30, 0.70, 0.92)):
    """Spend most pixels on the middle tones, with no isolated dark holes."""
    size = len(values)
    order = sorted((v, x, y) for y, row in enumerate(values) for x, v in enumerate(row))
    palette = [rgba(c) for c in colors]
    out = Image.new("RGBA", (size, size))
    for rank, (_, x, y) in enumerate(order):
        out.putpixel((x, y), palette[bisect_right(cuts, rank / len(order))])
    return out


def material(seed, size, weights):
    """Fine grain, small aggregates, soft cushions, weak broad variation.

    Every field is isotropic. Mud therefore has no baked top edge, lighting
    direction, flow line or horizon when it is used on a vertical bank.
    """
    fine = noise(seed, size)
    layers = [normalize(fine), soften(fine),
              soften(noise(seed + 1, size), 4),
              soften(noise(seed + 2, size), 16)]
    return blend(*zip(weights, layers))


def textures():
    mud = paint(material(51101, 32, (0.23, 0.49, 0.20, 0.08)), MUD)
    dry = paint(material(51102, 32, (0.36, 0.38, 0.20, 0.06)), DRY)
    # Three quiet, broken crust edges: distinct shapes and orientations,
    # only middle palette colours, no repeated stamp or connected crack net.
    for x, y, color in [(4, 8, 1), (5, 8, 1), (5, 9, 3),
                        (22, 17, 1), (22, 18, 1), (23, 18, 3),
                        (13, 28, 3), (14, 28, 1), (15, 29, 1)]:
        dry.putpixel((x, y), rgba(DRY[color]))
    moss = paint(material(51103, 32, (0.14, 0.28, 0.52, 0.06)), MOSS)

    side = paint(material(51104, 16, (0.30, 0.44, 0.22, 0.04)), DIRT)
    cap = paint(material(51105, 16, (0.14, 0.28, 0.52, 0.06)), MOSS)
    depths = [4, 4, 5, 5, 4, 3, 3, 4, 5, 6, 5, 4, 3, 4, 5, 4]
    for x, depth in enumerate(depths):
        for y in range(depth):
            side.putpixel((x, y), cap.getpixel((x, y)))
        # A one-pixel root seam joins the irregular fringe to the brown soil.
        side.putpixel((x, depth), rgba("40472e"))
    for x, y in [(2, 6), (8, 6), (9, 7), (14, 6)]:
        side.putpixel((x, y), rgba("505034"))
    return {"mud_top_32": mud, "mud_dry_top_32": dry,
            "moss_soil_top_32": moss, "moss_soil_side": side}


def open_rgba(path):
    with Image.open(path) as image:
        return image.convert("RGBA")


def repeat(tile, width, height):
    out = Image.new("RGBA", (width, height))
    for y in range(height):
        for x in range(width):
            out.putpixel((x, y), tile.getpixel((x % tile.width, y % tile.height)))
    return out


def show(canvas, tile, x, y, scale=1):
    canvas.alpha_composite(tile.resize((tile.width * scale, tile.height * scale), NEAREST), (x, y))


def mixed_patch(assets, grass, wet):
    # Ground boundaries follow nodes; texels always follow world coordinates,
    # including odd-node crops of each 32 px tile, never restarted per patch.
    regions = [
        "MMMMMGGGGGGGGGGG", "MMMMMMGGGGGGGGGG",
        "MMMMMMMGGWWGGGGG", "MMMMMMGWWWWWGGGG",
        "MMMMDGGWWUUWWGGG", "MMDDDDWWWUUUWWGG",
        "DDDDDDWWUUUUWWGG", "DDDDDWWWUUUWWWGG",
        "DDDDDWWUUUUWWGGG", "DDDDWWUUUUWWGGGG",
        "DDDWWWUUUWWWGGGG", "DDWWWWUUWWWGGGGG",
    ]
    assert all(len(row) == 16 for row in regions)
    tiles = {"M": assets["moss_soil_top_32"], "D": assets["mud_dry_top_32"],
             "U": assets["mud_top_32"], "G": grass, "W": wet}
    out = Image.new("RGBA", (256, 192))
    for y in range(out.height):
        for x in range(out.width):
            tile = tiles[regions[y // 16][x // 16]]
            out.putpixel((x, y), tile.getpixel((x % 32, y % 32)))
    return out


def join_strip(top, side, bottom=None):
    """Flat face swatches to judge the colour at the cap/side/bottom join."""
    out = Image.new("RGBA", (64, 32 if bottom else 24))
    out.paste(repeat(top, 64, 32).crop((0, 24, 64, 32)), (0, 0))
    out.paste(repeat(side, 64, 16), (0, 8))
    if bottom:
        out.paste(repeat(bottom, 64, 8), (0, 24))
    return out


def preview(assets):
    # Reuse only our original CC0 pixel font, not an external font asset.
    label = runpy.run_path(str(OLD / "generate.py"))["label"]
    dirt = open_rgba(DEFAULT / "default_dirt.png")
    old_side = Image.alpha_composite(dirt, open_rgba(DEFAULT / "default_moss_side.png"))
    grass = open_rgba(OUT / "wet_grass_top_calm32.png")
    wet = open_rgba(OUT / "mud_mottled_top_calm32.png")
    dry_side = open_rgba(OLD / "mud_dry_side.png")
    carpet = open_rgba(OLD / "moss_carpet_top.png")
    rows = [
        ("MUD / ALL FACES", "mud_top_32", open_rgba(NODES / "grug_nodes_mud.png")),
        ("DRY MUD / TOP", "mud_dry_top_32", open_rgba(OLD / "mud_dry_top.png")),
        ("MOSS SOIL / TOP", "moss_soil_top_32", open_rgba(DEFAULT / "default_moss.png")),
        ("MOSS SOIL / SIDE", "moss_soil_side", old_side),
    ]
    panel, height = 800, 2104
    canvas = Image.new("RGBA", (panel * 2, height))
    draw = ImageDraw.Draw(canvas)
    mixed = mixed_patch(assets, grass, wet)
    for c, bg, ink, faint in [(0, "e0ddd0", "30392d", "b8b9a9"),
                               (1, "222b28", "d2d4bf", "4b5750")]:
        x0 = c * panel
        color = rgba(ink)
        draw.rectangle((x0, 0, x0 + panel - 1, height - 1), fill=rgba(bg))
        label(canvas, x0 + 24, 20, "GRUDGELANDS / SWAMP GROUND", color, 3)
        label(canvas, x0 + 24, 48, "R51 SWART / GPT-6 ASTRA", color)
        label(canvas, x0 + 24, 70, "2X2 NODES / 32X32 PIXELS / 16 PX PER NODE", color)
        label(canvas, x0 + 24, 92, "LIGHT BACKGROUND" if c == 0 else "DARK BACKGROUND", color)
        for i, (title, name, old) in enumerate(rows):
            tile = assets[name]
            y = 120 + i * 328
            draw.line((x0 + 24, y, x0 + panel - 25, y), fill=rgba(faint))
            label(canvas, x0 + 24, y + 12, title, color)
            label(canvas, x0 + 240, y + 34, "TODAY / 8X8 NODES", color, 1)
            label(canvas, x0 + 520, y + 34, "NEW / 8X8 NODES", color, 1)
            show(canvas, tile, x0 + 24, y + 72)
            show(canvas, tile, x0 + 80, y + 72, 4)
            label(canvas, x0 + 24, y + 216, "1X", color)
            label(canvas, x0 + 80, y + 216, "4X", color)
            label(canvas, x0 + 24, y + 246, "16X16 RGBA" if i == 3 else "32X32 RGBA", color, 1)
            label(canvas, x0 + 24, y + 262, "OPAQUE", color, 1)
            show(canvas, repeat(old, 128, 128), x0 + 240, y + 50, 2)
            show(canvas, repeat(tile, 128, 128), x0 + 520, y + 50, 2)
            label(canvas, x0 + 240, y + 314, "8X8 TILES / 2X", color, 1)
            label(canvas, x0 + 520, y + 314,
                  "8X8 TILES / 2X / X REPEAT ONLY" if i == 3 else "4X4 TILES / 2X", color, 1)

        y = 1448
        label(canvas, x0 + 24, y, "MIXED GROUND / 16X12 NODES / 2X", color)
        show(canvas, mixed, x0 + 24, y + 26, 2)
        legend = [("MOSS SOIL", assets["moss_soil_top_32"]),
                  ("WET GRASS", grass), ("WET MUD", wet),
                  ("PLAIN MUD", assets["mud_top_32"]),
                  ("DRY CRUST", assets["mud_dry_top_32"])]
        for i, (name, tile) in enumerate(legend):
            show(canvas, tile, x0 + 560, y + 26 + i * 76, 2)
            label(canvas, x0 + 636, y + 54 + i * 76, name, color, 1)

        y = 1880
        label(canvas, x0 + 24, y, "DRY / UNCHANGED SIDE", color, 1)
        show(canvas, join_strip(assets["mud_dry_top_32"], dry_side), x0 + 24, y + 18, 3)
        label(canvas, x0 + 250, y, "MOSS / SIDE / DIRT BOTTOM", color, 1)
        show(canvas, join_strip(assets["moss_soil_top_32"], assets["moss_soil_side"], dirt),
             x0 + 250, y + 18, 3)
        label(canvas, x0 + 490, y, "MOSS CARPET / REFERENCE", color, 1)
        show(canvas, carpet, x0 + 490, y + 18, 4)
        label(canvas, x0 + 24, 2002, "4 ORIGINAL TEXTURES + GENERATOR / CC0-1.0", color)
        label(canvas, x0 + 24, 2024, "COMPARISON / CC BY-SA 3.0 / CREDITS IN README.MD", color, 1)
        label(canvas, x0 + 24, 2044, "PARAMAT / RANDOM-GEEK / NEUROMANCER / GRUDGELANDS", color, 1)
        label(canvas, x0 + 24, 2064, "NEAREST NEIGHBOUR ONLY / OPEN AT 100 PER CENT FOR 1X", color, 1)
    return canvas


def main():
    assets = textures()
    assets["preview-32"] = preview(assets)
    OUT.mkdir(exist_ok=True)
    for name, img in assets.items():
        expected = (1600, 2104) if name == "preview-32" else (16, 16) if name == "moss_soil_side" else (32, 32)
        assert img.size == expected and img.mode == "RGBA"
        assert img.getchannel("A").getextrema() == (255, 255)
        path = OUT / (name + ".png")
        img.save(path)
        print(f"{path.relative_to(ROOT)}: {img.width}x{img.height} RGBA, opaque")


if __name__ == "__main__":
    main()
