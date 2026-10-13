#!/usr/bin/env python3
"""Original Anthracite pixel art by GPT-6 Astra, 2026-10-13, CC0-1.0.

Run: python3 tools/r47_art/anthracite/generate.py
Requires Python 3 and Pillow. All new art is painted from the grids below;
no downloads, sampled source colours, recolouring or traced flame frames.
The stick coordinates are the existing texture/UV interface, in pixels.
Existing art is read only by comparisons(). Labels reuse our CC0 swamp font.
"""

from pathlib import Path
from runpy import run_path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NEAREST = Image.Resampling.NEAREST
CLEAR = (0, 0, 0, 0)
label = run_path(str(HERE.parent / "swamp/generate.py"))["label"]


def rgba(hex_color):
    return tuple(bytes.fromhex(hex_color)) + (255,)


# Small isolated cold reflections on predominantly black fracture faces.
MINERAL = {
    "n": "080c11", "d": "10171e", "s": "1b2833", "m": "30434f",
    "r": "526b79", "h": "889faa", "g": "bed0d4",
}
FIRE = {
    "a": "df862e", "o": "f5ad3f", "y": "ffda73", "c": "fff0ae",
    "w": "fffce5", "b": "518eb8", "i": "8bc8df",
}
WOOD = {"d": "28231e", "m": "3c3429", "l": "60503a", "r": "746047"}


def paint(image, rows, colors, x=0, y=0):
    for dy, row in enumerate(rows):
        for dx, key in enumerate(row):
            if key != ".":
                image.putpixel((x + dx, y + dy), rgba(colors[key]))


def blank():
    return Image.new("RGBA", (16, 16), CLEAR)


def lump():
    out = blank()
    # Unequal chipped planes with two broken, curved fracture ridges.
    paint(out, [
        "................",
        "................",
        "......nnn.......",
        "....nhrmdnn.....",
        "...nrgmsdddnn...",
        "..nrmsddnnssdn..",
        "..nmsddnmsdsdn..",
        "..nsddnhrmddnn..",
        "...ndnrmsddsdn..",
        "...nnmsdddsdn...",
        "....ndddssdn....",
        ".....nssddn.....",
        "......nnnn......",
        "................",
        "................",
        "................",
    ], MINERAL)
    return out


def ore():
    out = blank()
    # Four original uneven lenses, with ample transparent host rock between.
    paint(out, [".nnn.", "nrhsn", "nmddn", ".nnn."], MINERAL, 1, 1)
    paint(out, [".nn.", "nrsn", "nddn", ".nn."], MINERAL, 11, 2)
    paint(out, ["..nnn..", ".nhrsdn", "nrmsddn", "ndddnn.", ".nnn..."], MINERAL, 5, 7)
    paint(out, [".nnn.", "nrmsn", "nddn.", ".nn.."], MINERAL, 0, 11)
    return out


# Six-by-six hand-authored fire frames. The base remains at columns 2/3,
# row 5; successive tips move at most one pixel, including frame 15 -> 0.
# Warm outer tongues, a broad pale core, and a one-pixel-thin blue base.
FLAMES = [
    ["......", "...a..", "..oy..", "..ywo.", ".oywyo", "..bi.."],
    ["...a..", "...o..", "..oy..", "..cwo.", ".oywya", "..ib.."],
    ["...o..", "...ya.", "...yo.", "..cwy.", ".oywyo", "..ib.."],
    ["....a.", "...oy.", "...cy.", "..ywy.", ".ocwyo", "..bi.."],
    ["......", "....a.", "...yo.", "..owc.", ".oywyo", "..bi.."],
    ["......", "...a..", "...yo.", "..ywc.", ".oywya", "..ib.."],
    ["......", "...o..", "..ay..", ".oywy.", "..ywyo", "..ib.."],
    ["...a..", "..ao..", "..oy..", ".oywc.", ".oywyo", "..bi.."],
    ["..a...", "..o...", "..yo..", ".owcy.", ".oywyo", "..bi.."],
    ["..o...", "..ya..", ".oy...", ".cwyo.", ".oywya", "..ib.."],
    [".a....", "..y...", ".oyo..", ".ywy..", ".oywyo", "..ib.."],
    ["......", ".ao...", ".oy...", ".ywc..", ".ocwyo", "..bi.."],
    ["......", "..a...", "..yo..", ".owc..", ".oywyo", "..bi.."],
    ["......", "..o...", "..yo..", "..wyo.", ".oywya", "..ib.."],
    ["..a...", "..oa..", "..yo..", "..wcy.", ".oywyo", "..ib.."],
    ["......", "..ao..", "..oy..", "..cwo.", ".oywyo", "..bi.."],
]

# The ceiling sheet has its own compact curl, with the flame against the
# right and lower edge of the head. Its tip stays in the original y=4..9
# envelope, including the narrow two-pixel end at y=9.
CEILING_FLAMES = [
    ["....", ".a..", ".iyo", "bwc.", "oy..", ".a.."],
    ["....", ".o..", ".iyc", "bwyo", "oy..", ".a.."],
    [".a..", ".y..", ".iyc", "bwyo", ".yo.", ".a.."],
    [".a..", ".yo.", ".iyc", "bwyo", ".yo.", "...."],
    ["....", ".oy.", ".iyc", "bwco", ".yo.", "...."],
    ["....", "..a.", ".iyo", "bwcy", ".yo.", ".a.."],
    ["....", "....", ".iya", "bwc.", "oyo.", ".o.."],
    ["....", "....", ".iyo", "bwc.", "oyo.", "ao.."],
    ["....", "....", ".iy.", "bwco", "oy..", "oa.."],
    ["....", "....", ".ic.", "bwyo", "oy..", "a..."],
    ["....", ".a..", ".ic.", "bwya", "cy..", "a..."],
    ["....", ".o..", ".iy.", "bwyo", "cy..", "...."],
    [".a..", ".o..", ".iy.", "bwco", "oy..", "...."],
    [".a..", ".y..", ".iyo", "bwc.", "oy..", "...."],
    ["....", ".y..", ".iyo", "bwco", ".y..", ".a.."],
    ["....", ".o..", ".iyo", "bwco", "oy..", ".a.."],
]


def torch_frame(orientation, phase):
    out = blank()
    flame = FLAMES[phase]
    if orientation == "floor":
        # Mesh shaft: x=[7,8], y=[6,15]. Cap UV: x=[7,8], y=[6,7].
        paint(out, ["dl", "mr", "dl", "ml", "dl", "ml", "dm"], WOOD, 7, 9)
        paint(out, ["mh", "nd", "rm"], MINERAL, 7, 6)
        paint(out, flame, FIRE, 5, 0)
    elif orientation == "ceiling":
        # Original ceiling sheet's bent shaft, from (5,0) to (7,6).
        paint(out, ["m..", "ld.", ".m.", ".l.", ".md"], WOOD, 5, 0)
        paint(out, ["sn", "hr"], MINERAL, 6, 5)
        paint(out, CEILING_FLAMES[phase], FIRE, 7, 4)
    elif orientation == "wall":
        # Original diagonal sheet's shaft remains at the same pixel sites.
        paint(out, [".ml.", ".dl.", "..ml", "..dl", "...ml"], WOOD, 11, 7)
        paint(out, ["l", "d"], WOOD, 15, 12)
        paint(out, ["mh", "nd", "r."], MINERAL, 11, 5)
        # Slightly shorter tongue to leave the diagonal head at y=5 exposed.
        paint(out, flame[1:], FIRE, 8, 0)
    else:
        raise ValueError(orientation)
    return out


ORIENTATIONS = [
    ("floor", "anthracite_torch_on_floor_animated", "default_torch_on_floor_animated.png"),
    ("ceiling", "anthracite_torch_on_ceiling_animated", "default_torch_on_ceiling_animated.png"),
    ("wall", "anthracite_torch_animated", "default_torch_animated.png"),
]


def textures():
    result = {"anthracite_lump": lump(), "mineral_anthracite": ore(),
              "anthracite_torch_on_floor": torch_frame("floor", 2)}
    for orientation, name, _ in ORIENTATIONS:
        sheet = Image.new("RGBA", (16, 256), CLEAR)
        for phase in range(16):
            sheet.paste(torch_frame(orientation, phase), (0, phase * 16))
        result[name] = sheet
    return result


def show(canvas, tile, x, y, scale):
    canvas.alpha_composite(tile.resize((tile.width * scale, tile.height * scale), NEAREST), (x, y))


BACKGROUNDS = [("e3dfd3", "27303a", "bcbcb6"), ("202731", "e5e1d4", "485562")]


def panel(canvas, column, title):
    bg, ink, line = BACKGROUNDS[column]
    width = canvas.width // 2
    x = column * width
    ImageDraw.Draw(canvas).rectangle((x, 0, x + width - 1, canvas.height - 1), fill=rgba(bg))
    label(canvas, x + 24, 20, title, rgba(ink), 3)
    label(canvas, x + 24, 48, "R47 ART / GPT-6 ASTRA / ORIGINALS CC0", rgba(ink))
    label(canvas, x + 24, 72, "LIGHT BACKGROUND" if column == 0 else "DARK BACKGROUND", rgba(ink))
    return x, rgba(ink), rgba(line)


def pair(canvas, x, y, title, coal, anthracite, ink):
    label(canvas, x, y, title, ink)
    for index, (name, tile) in enumerate([("COAL", coal), ("ANTHRACITE", anthracite)]):
        xx = x + index * 228
        label(canvas, xx, y + 24, name, ink)
        show(canvas, tile, xx + 8, y + 90, 1)
        show(canvas, tile, xx + 48, y + 44, 8)
        label(canvas, xx + 8, y + 180, "1X", ink)
        label(canvas, xx + 96, y + 180, "8X", ink)


def preview(assets, refs, rocks):
    # Includes the COMPLETE 16x256 strips at both 1x and 8x on both grounds.
    canvas = Image.new("RGBA", (1920, 3376))
    for column in range(2):
        x, ink, line = panel(canvas, column, "GRUDGELANDS / ANTHRACITE")
        pair(canvas, x + 24, 108, "LUMP / SHARP COLD FRACTURES", refs["lump"], assets["anthracite_lump"], ink)
        pair(canvas, x + 500, 108, "TORCH / INVENTORY AND WIELD", refs["inventory"], assets["anthracite_torch_on_floor"], ink)
        pair(canvas, x + 24, 324, "ORE / TRANSPARENT OVERLAY", refs["ore"], assets["mineral_anthracite"], ink)
        for rock_index, (rock_name, rock) in enumerate(rocks):
            xx, yy = (x + 500, 324) if rock_index == 0 else (x + 24 + (rock_index - 1) * 476, 540)
            pair(canvas, xx, yy, "ORE / " + rock_name,
                 Image.alpha_composite(rock, refs["ore"]),
                 Image.alpha_composite(rock, assets["mineral_anthracite"]), ink)
        label(canvas, x + 24, 764, "FLOOR FLAME / FRAMES 00 04 08 12 / 8X", ink)
        for row, (name, sheet) in enumerate([("COAL", refs["floor"]), ("ANTHRACITE", assets[ORIENTATIONS[0][1]])]):
            label(canvas, x + 24, 822 + row * 158, name, ink)
            for j, phase in enumerate([0, 4, 8, 12]):
                show(canvas, sheet.crop((0, phase * 16, 16, phase * 16 + 16)), x + 168 + j * 190, 796 + row * 158, 8)
        ImageDraw.Draw(canvas).line((x + 24, 1126, x + 934, 1126), fill=line)
        label(canvas, x + 24, 1142, "COMPLETE SHEETS / 16 FRAMES / NO REPACKING", ink)
        label(canvas, x + 24, 1164, "EACH COLUMN HAS THE FULL 1X STRIP AND THE FULL 8X STRIP", ink)
        for orientation_index, (orientation, asset_name, _) in enumerate(ORIENTATIONS):
            for side, (short, sheet) in enumerate([("COAL", refs[orientation]), ("AN", assets[asset_name])]):
                xx = x + 24 + (orientation_index * 2 + side) * 152
                label(canvas, xx, 1200, orientation.upper() + "/" + short, ink)
                show(canvas, sheet, xx, 2112, 1)
                show(canvas, sheet, xx + 20, 1216, 8)
                label(canvas, xx, 2390, "1X", ink, 1)
                label(canvas, xx + 68, 3276, "8X", ink)
        label(canvas, x + 24, 3306, "PREVIEW CC BY-SA 3.0 / CREDITS IN LICENSE-MEDIA.MD", ink)
        label(canvas, x + 24, 3328, "NEAREST NEIGHBOUR / VIEW AT 100 PERCENT FOR NATIVE PIXELS", ink)
        label(canvas, x + 24, 3350, "TORCH LOOP 3.3 S / CURRENT MESHES ALL USE THE FLOOR SHEET", ink)
    return canvas


def gif(assets, refs):
    frames = []
    for phase in range(16):
        canvas = Image.new("RGBA", (960, 720))
        for column in range(2):
            x, ink, _ = panel(canvas, column, "ANTHRACITE / FIRE")
            for row, (orientation, name, _) in enumerate(ORIENTATIONS):
                y = 108 + row * 192
                label(canvas, x + 24, y, orientation.upper() + " / 8X", ink)
                for side, (title, sheet) in enumerate([("COAL", refs[orientation]), ("ANTHRACITE", assets[name])]):
                    xx = x + 40 + side * 228
                    label(canvas, xx, y + 20, title, ink)
                    show(canvas, sheet.crop((0, phase * 16, 16, phase * 16 + 16)), xx, y + 40, 8)
            label(canvas, x + 24, 696, "3.3 S / COMPARISON CC BY-SA 3.0", ink)
        frames.append(canvas.convert("RGB"))
    # One palette shared by all frames avoids palette changes during playback.
    # Quantize artwork only so large plain panels do not dominate the palette.
    palette_source = Image.new("RGB", (128, 256), "#e3dfd3")
    for i, (_, name, _) in enumerate(ORIENTATIONS):
        palette_source.paste(refs[ORIENTATIONS[i][0]].convert("RGB"), (i * 32, 0))
        palette_source.paste(assets[name].convert("RGB"), (i * 32 + 16, 0))
    for i, colors in enumerate(BACKGROUNDS):
        for j, color in enumerate(colors):
            ImageDraw.Draw(palette_source).rectangle((96, i * 96 + j * 32, 127, i * 96 + j * 32 + 31), fill="#" + color)
    palette = palette_source.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    # GIF centiseconds distribute 3.3 seconds over 16 frames (200/210 ms).
    durations = [(330 * (i + 1) // 16 - 330 * i // 16) * 10 for i in range(16)]
    indexed[0].save(HERE / "torch-compare.gif", save_all=True, append_images=indexed[1:],
                    duration=durations, loop=0, optimize=False, disposal=2)


def comparisons(assets):
    directory = ROOT / "mods/BASE/default/textures"
    refs = {key: Image.open(directory / file).convert("RGBA") for key, file in [
        ("lump", "default_coal_lump.png"), ("ore", "default_mineral_coal.png"),
        ("inventory", "default_torch_on_floor.png"),
    ] + [(orientation, file) for orientation, _, file in ORIENTATIONS]}
    rocks = [("STONE", Image.open(directory / "default_stone.png").convert("RGBA"))]
    for tier in (3, 6):
        path = ROOT / f"mods/ITEMS/grug_materials/textures/grug_materials_t{tier}_stone.png"
        rocks.append((f"T{tier} DEEP ROCK", Image.open(path).convert("RGBA")))
    preview(assets, refs, rocks).save(HERE / "preview.png", compress_level=9)
    gif(assets, refs)


def main():
    assets = textures()
    for name, texture in assets.items():
        texture.save(HERE / (name + ".png"), compress_level=9)
    comparisons(assets)
    print("Wrote six original RGBA textures, preview.png and torch-compare.gif")


if __name__ == "__main__":
    main()
