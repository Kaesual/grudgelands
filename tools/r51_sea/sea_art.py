#!/usr/bin/env python3
"""Original Round 51 sea pixel art, GPT-6 Astra, CC0-1.0.

python3 -I tools/r51_sea/sea_art.py [--check]
Only the comparison renderer reads existing texture pixels. All resizing
uses nearest neighbours; no external fonts, downloads or engine needed.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT = ROOT / "mods/BASE/default/textures"
CLEAR = (0, 0, 0, 0)
NEAREST = Image.Resampling.NEAREST
BLOCKS = {"wreck_planks", "wreck_planks_algae", "wreck_log", "wreck_log_top"}


def color(hex_value):
    return tuple(bytes.fromhex(hex_value)) + (255,)


def sprite(rows, palette):
    assert len(rows) == 16 and all(len(row) == 16 for row in rows)
    out = Image.new("RGBA", (16, 16), CLEAR)
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char != ".":
                out.putpixel((x, y), color(palette[char]))
    return out


def stamp(out, x, y, rows, palette):
    """Small authored grain clusters, wrapped at the block boundaries."""
    for dy, row in enumerate(rows):
        for dx, char in enumerate(row):
            if char != ".":
                out.putpixel(((x + dx) % 16, (y + dy) % 16), color(palette[char]))


def textures():
    grass = {"s": "48583a", "m": "6c7e4a", "l": "8f9d62", "h": "b0b67c"}
    assets = {}
    # Separate roots and one-pixel tips: a low grassy bed, without a kelp stem.
    assets["seagrass_1"] = sprite([
        "................", "................", "................", "................",
        "....l...........", ".....l.....h....", ".....lm....l....", "..l...l...lm....",
        "...l..lm..l.....", "...lm..l.lm..l..", ".l..l..l.l..lm..", "..l.lm.l.m..l...",
        "...l.m.lsm.lm...", "...l.m.msm.l....", "....msmssm.m....", "....ssssssss....",
    ], grass)
    assets["seagrass_2"] = sprite([
        "................", "................", "................", "................",
        "................", "................", "...........h....", "...l......l.....",
        "....l....lm.....", ".....l...l...l..", "..l..lm..m..l...", "...l..l..m.lm...",
        ".l..l.lm.m.l....", "..l..msm.mlm....", "...l.msmssm.....", "....sssssss.....",
    ], grass)
    assets["seagrass_3"] = sprite([
        "................", "................", "................", "................",
        "................", ".......h........", "...l...l........", "....l..lm...l...",
        "....lm..l..l....", ".....l..l.lm....", "..l..lm.l.l...l.", "...l..m.l.m..l..",
        "....l.m.lsm.l...", "....l.m.msm.m...", ".....msmssmm....", ".....sssssss....",
    ], grass)

    wood = {"s": "3b4139", "d": "514e40", "m": "655e4c", "h": "7c7059", "l": "96866a"}
    planks = Image.new("RGBA", (16, 16))
    board_rows = ["hhmmmmmmhhhhmmmm", "mmmmddmmmmmmmmmm", "ddmmmmmmmmmddmmm", "ssssssssssssssss"]
    # Four boards with offset butt joints and long, subdued wet grain.
    for y in range(16):
        for x in range(16):
            char = board_rows[y % 4][(x + (y // 4) * 5) % 16]
            planks.putpixel((x, y), color(wood[char]))
    for board, joint in enumerate([3, 11, 6, 14]):
        for y in range(board * 4, board * 4 + 3):
            planks.putpixel((joint, y), color(wood["d"]))
        planks.putpixel((joint, board * 4 + 1), color(wood["s"]))
    stamp(planks, 6, 1, ["ddh", "mdm"], wood)
    stamp(planks, 12, 9, ["hdm", ".dd"], wood)
    assets["wreck_planks"] = planks

    algae_wood = planks.copy()
    film = {"d": "3d4e3b", "m": "56694a", "l": "74845a", "h": "899264"}
    stamp(algae_wood, 14, 13, ["..dm..", ".dmlmd", "dmlhmd", "dmmlm.", ".dm...", "..d..."], film)
    stamp(algae_wood, 7, 4, [".dd...", "dmlm..", ".dmlmd", "..dm.."], film)
    stamp(algae_wood, 3, 9, ["dm.", "mlm", ".dd"], film)
    assets["wreck_planks_algae"] = algae_wood

    log = Image.new("RGBA", (16, 16))
    timber = {"d": "3c423b", "s": "4c4c40", "m": "625e4b", "l": "7c725b", "h": "8d8065"}
    columns = "ssmlsmdmlsmlsmmd"
    for y in range(16):
        for x in range(16):
            log.putpixel((x, y), color(timber[columns[x]]))
    for x, y in [(1, 2), (5, 10), (10, 4), (14, 12)]:
        stamp(log, x, y, [".l", "ml", "ms", "ds", "ds", ".s"], timber)
    assets["wreck_log"] = log
    # A hewn square end with dull growth rings and two radial splits.
    top = Image.new("RGBA", (16, 16))
    rings = ["s", "d", "m", "l", "m", "s", "l", "m"]
    for y in range(16):
        for x in range(16):
            edge = min(x, y, 15 - x, 15 - y)
            char = rings[edge]
            if edge in (2, 4, 6) and (x + y * 3) % 7 == 0:
                char = "l"
            top.putpixel((x, y), color(timber[char]))
    stamp(top, 0, 2, ["dd.....", ".dd....", "..dd...", "...d...", "....d.."], timber)
    stamp(top, 9, 11, ["d..", "d..", ".d.", ".d.", "..d"], timber)
    assets["wreck_log_top"] = top

    mast = Image.new("RGBA", (16, 16), CLEAR)
    for y in range(16):
        for x, c in enumerate(["41463d", "8a7d62", "70664f", "4f5042"], 6):
            mast.putpixel((x, y), color(c))
    for y in range(4, 10):
        mast.putpixel((8, y), color("645f4c"))
    for y in range(8, 13):
        mast.putpixel((7, y), color("80755d"))
    # No rope bands, fittings or end cap: every sixteen rows must join.
    assets["wreck_mast"] = mast

    assets["wreck_rope"] = sprite([
        "................", "................", "................", "................",
        "....h...........", "....lm..........", ".....lm.........", "......m.........",
        ".....shhhs......", "....hlmmmlh.....", "...hlm...mlh....", "...lm.shs.ml....",
        "...ml.lml.lm....", "....mlhhlml.....", ".....smmms.lm...", "......sss...l.l.",
    ], {"s": "514d3a", "m": "897851", "l": "b29c6a", "h": "c6b17c"})
    assets["wreck_sail"] = sprite([
        "................", "................", "................", "....s...........",
        "...shhll........", "...sllhhll......", "...smlllhlmm....", "...sml..lmhlm...",
        "...smh..mlml....", "...smlmlmlm.....", "...smmhml.m.....", "...s.lmlm.m.....",
        "...s.lmm..m.....", "...s..m...m.....", "...s..m.........", "...s............",
    ], {"s": "575342", "m": "8c8970", "l": "b2ae8e", "h": "cec7a6"})
    assets["wreck_algae"] = sprite([
        "................", "................", "................", "................",
        "................", "................", ".....l..........", ".....lm...h.....",
        "..l..ml...lm....", "..lm..m..ml.....", "...ml.ml.ms..l..", "....m.lm.ms.lm..",
        "..lmmsmmsm.ml...", "...mlmmmsm.m....", "....smmssmm.....", ".....ssssss.....",
    ], {"s": "354e3d", "m": "507354", "l": "7b9561", "h": "9cac75"})
    return assets


# Original pixel lettering; lowercase filenames remain case-sensitive.
GLYPHS = {
    "A": "010/101/111/101/101", "B": "110/101/110/101/110", "C": "011/100/100/100/011",
    "D": "110/101/101/101/110", "E": "111/100/110/100/111", "F": "111/100/110/100/100",
    "G": "011/100/101/101/011", "H": "101/101/111/101/101", "I": "111/010/010/010/111",
    "J": "001/001/001/101/010", "K": "101/101/110/101/101", "L": "100/100/100/100/111",
    "M": "101/111/111/101/101", "N": "101/111/111/111/101", "O": "010/101/101/101/010",
    "P": "110/101/110/100/100", "Q": "010/101/101/111/011", "R": "110/101/110/101/101",
    "S": "011/100/010/001/110", "T": "111/010/010/010/010", "U": "101/101/101/101/111",
    "V": "101/101/101/101/010", "W": "101/101/111/111/101", "X": "101/101/010/101/101",
    "Y": "101/101/010/010/010", "Z": "111/001/010/100/111",
    "a": "000/011/101/101/011", "b": "100/110/101/101/110", "c": "000/011/100/100/011",
    "d": "001/011/101/101/011", "e": "000/010/111/100/011", "f": "011/010/111/010/010",
    "g": "000/011/101/011/001/110", "h": "100/110/101/101/101", "i": "010/000/010/010/010",
    "j": "001/000/001/001/101/010", "k": "100/101/110/110/101", "l": "110/010/010/010/011",
    "m": "000/111/111/101/101", "n": "000/110/101/101/101", "o": "000/010/101/101/010",
    "p": "000/110/101/110/100/100", "q": "000/011/101/011/001/001", "r": "000/101/110/100/100",
    "s": "000/011/100/001/110", "t": "010/111/010/010/011", "u": "000/101/101/101/011",
    "v": "000/101/101/101/010", "w": "000/101/101/111/111", "x": "000/101/010/010/101",
    "y": "000/101/101/011/001/110", "z": "000/111/001/100/111",
    "0": "111/101/101/101/111", "1": "010/110/010/010/111", "2": "110/001/010/100/111",
    "3": "110/001/010/001/110", "4": "101/101/111/001/001", "5": "111/100/110/001/110",
    "6": "011/100/110/101/010", "7": "111/001/010/010/010", "8": "010/101/010/101/010",
    "9": "010/101/011/001/110", " ": "000/000/000/000/000", "/": "001/001/010/100/100",
    "-": "000/000/111/000/000", "_": "000/000/000/000/111", ".": "000/000/000/000/010",
    ":": "000/010/000/010/000", "+": "000/010/111/010/000", "=": "000/111/000/111/000",
}


def label(canvas, x, y, text, ink="d9dfcf", scale=2):
    d = ImageDraw.Draw(canvas)
    for char in text:
        for dy, row in enumerate(GLYPHS[char].split("/")):
            for dx, bit in enumerate(row):
                if bit == "1":
                    px, py = x + dx * scale, y + dy * scale
                    d.rectangle((px, py, px + scale - 1, py + scale - 1), fill=color(ink))
        x += 4 * scale


def show(canvas, im, x, y, scale=1):
    canvas.alpha_composite(im.resize((im.width * scale, im.height * scale), NEAREST), (x, y))


def tiled(im, columns, rows):
    result = Image.new("RGBA", (columns * 16, rows * 16), CLEAR)
    for y in range(rows):
        for x in range(columns):
            result.alpha_composite(im, (x * 16, y * 16))
    return result


def reference(name):
    with Image.open(DEFAULT / (name + ".png")) as im:
        return im.convert("RGBA")


def water_color():
    pixels = list(reference("default_water").get_flattened_data())
    return tuple(round(sum(p[c] for p in pixels) / len(pixels)) for c in range(3))


def submerged(im, depth, water):
    """An explicit art comparison, not an engine lighting/fog simulation."""
    mix, light = {4: (0.15, 0.92), 10: (0.30, 0.76), 20: (0.46, 0.57)}[depth]
    out = im.copy()
    out.putdata([
        tuple(round((p[c] * (1 - mix) + water[c] * mix) * light) for c in range(3)) + (p[3],)
        for p in im.get_flattened_data()
    ])
    return out


def meadow(assets):
    scene = Image.new("RGBA", (112, 48), color("314b47"))
    scene.alpha_composite(tiled(reference("default_sand"), 7, 1), (0, 32))
    for i, x in enumerate([0, 12, 25, 36, 48]):
        scene.alpha_composite(assets["seagrass_" + str(i % 3 + 1)], (x, 16))
    scene.alpha_composite(tiled(reference("default_kelp"), 1, 2), (64, 0))
    scene.alpha_composite(tiled(reference("default_kelp"), 1, 2), (79, 0))
    scene.alpha_composite(reference("default_coral_green"), (94, 16))
    return scene


def mast_scene(assets, height, breaches, water):
    scene = Image.new("RGBA", (88, 224), color("d9ddce"))
    bottom = 208
    surface = bottom - (height - 3) * 16 if breaches else 7
    d = ImageDraw.Draw(scene)
    d.rectangle((0, surface, 87, 223), fill=color("334f58"))
    scene.alpha_composite(tiled(assets["wreck_mast"], 1, height), (36, bottom - height * 16))
    scene.alpha_composite(tiled(assets["wreck_planks"], 3, 1), (20, bottom))
    for y in range(surface, 224):
        depth = 4 if y - surface < 64 else 10 if y - surface < 160 else 20
        scene.paste(submerged(scene.crop((0, y, 88, y + 1)), depth, water), (0, y))
    d.line((0, surface, 87, surface), fill=color("779da2"))
    return scene


def preview(assets):
    canvas = Image.new("RGBA", (1440, 2240), color("18282e"))
    d = ImageDraw.Draw(canvas)
    label(canvas, 32, 28, "GRUDGELANDS / THE SEA", scale=5)
    label(canvas, 34, 73, "ROUND 51 / ARTS / 11 ORIGINAL 16x16 RGBA TEXTURES", scale=2)
    label(canvas, 34, 98, "CC0 ASSETS / NEAREST NEIGHBOUR / BINARY ALPHA / FULL BLOCKS + ROOTED EXTENSIONS", "9aafa4", 2)
    ideas = ["FINE UPRIGHT BLADES", "LOW SWEPT MEADOW", "OPEN FAN OF BLADES", "SOAKED SHIP BOARDS",
             "PATCHY ALGAE FILM", "WEATHERED KEEL TIMBER", "DULL CUT END + SPLITS", "NARROW POLE / VERTICAL REPEAT",
             "COILED ROPE + FRAYED END", "TORN CLOTH ON A BROKEN PEG", "LOW BRANCHING WOOD ALGAE"]
    for index, (name, im) in enumerate(assets.items()):
        x, y = 32 + index % 3 * 464, 136 + index // 3 * 174
        d.rectangle((x, y, x + 447, y + 155), fill=color("26383c"))
        for shift, bg, ink in [(0, "deded0", "3c4c43"), (220, "111f26", "c8d4c3")]:
            d.rectangle((x + 8 + shift, y + 8, x + 219 + shift, y + 110), fill=color(bg))
            show(canvas, im, x + 34 + shift, y + 40)
            show(canvas, im, x + 94 + shift, y + 14, 4)
            label(canvas, x + 32 + shift, y + 91, "1x", ink)
            label(canvas, x + 114 + shift, y + 91, "4x", ink)
        label(canvas, x + 12, y + 120, name + ".png")
        label(canvas, x + 12, y + 140, ideas[index], "9aafa4", 1)

    # Default end-grain comparison makes the optional timber choice reviewable.
    x, y = 960, 658
    label(canvas, x + 12, y + 8, "TIMBER RECOMMENDATION", scale=2)
    for i, name in enumerate(["default_tree", "default_tree_top"]):
        show(canvas, reference(name), x + 20 + i * 216, y + 36, 4)
        label(canvas, x + 14 + i * 216, y + 114, name + ".png", scale=1)
    label(canvas, x + 12, y + 138, "USE THE DULL WRECK LOG + END", "9aafa4", 2)

    label(canvas, 32, 858, "01 / SEAGRASS MEADOW ON SAND / BESIDE KELP + CORAL", scale=3)
    label(canvas, 32, 886, "ILLUSTRATIVE DEPTH TINTS FROM default_water.png / NOT ENGINE LIGHTING", "9aafa4", 2)
    water = water_color()
    for i, depth in enumerate([4, 10, 20]):
        x = 32 + i * 464
        show(canvas, submerged(meadow(assets), depth, water), x, 920, 4)
        label(canvas, x, 1126, "DEPTH " + str(depth) + " / 4x", scale=2)
        label(canvas, x, 1150, "seagrass_1.png / seagrass_2.png / seagrass_3.png", scale=2)
        label(canvas, x, 1170, "default_sand.png / default_kelp.png / default_coral_green.png", "9aafa4", 1)

    label(canvas, 32, 1214, "02 / BLOCK WALLS + DECKS / NO TRANSPARENT WOOD", scale=3)
    for i, name in enumerate(["wreck_planks", "wreck_planks_algae"]):
        x = 32 + i * 696
        d.rectangle((x, 1250, x + 679, 1546), fill=color("26383c"))
        show(canvas, tiled(assets[name], 4, 2), x + 16, 1280, 3)
        label(canvas, x + 16, 1390, name + ".png", scale=2)
        label(canvas, x + 16, 1414, "WALL / 4x2 NODES / 3x", "9aafa4", 2)
        show(canvas, tiled(assets[name], 4, 3), x + 252, 1256, 3)
        label(canvas, x + 252, 1414, "DECK / TOP VIEW / 4x3", "9aafa4", 2)
        show(canvas, submerged(tiled(assets[name], 4, 1), 10, water), x + 16, 1450, 3)
        label(canvas, x + 252, 1468, "DEPTH 10 / 3x", "9aafa4", 2)
        show(canvas, tiled(assets["wreck_log"], 1, 2), x + 484, 1272, 3)
        show(canvas, assets["wreck_log_top"], x + 548, 1272, 3)
        label(canvas, x + 476, 1390, "wreck_log.png", scale=1)
        label(canvas, x + 476, 1406, "wreck_log_top.png", scale=1)
        label(canvas, x + 476, 1430, "KEEL + RIBS", "9aafa4", 2)
        label(canvas, x + 16, 1524, name + ".png", "9aafa4", 1)

    label(canvas, 32, 1582, "03 / MAST REPEATS", scale=3)
    label(canvas, 32, 1612, "6 + 12 NODES / 2x / THREE NODES ABOVE THE SURFACE ON RIGHT", "9aafa4", 2)
    for i, (height, breaches) in enumerate([(6, False), (12, False), (6, True), (12, True)]):
        x = 32 + i * 208
        show(canvas, mast_scene(assets, height, breaches, water), x, 1644, 2)
        label(canvas, x, 2108, "wreck_mast.png", scale=2)
        label(canvas, x, 2132, str(height) + " HIGH / " + ("AIR" if breaches else "WATER"), "9aafa4", 2)

    label(canvas, 900, 1582, "04 / ROOTED DETAILS", scale=3)
    label(canvas, 900, 1612, "ONE NODE ABOVE A FULL PLANK BASE / 4x", "9aafa4", 2)
    for i, name in enumerate(["wreck_rope", "wreck_sail", "wreck_algae"]):
        x = 912 + i * 166
        for row, bg in enumerate(["deded0", "111f26"]):
            tile = Image.new("RGBA", (24, 32), color(bg))
            tile.alpha_composite(assets["wreck_planks"], (4, 16))
            tile.alpha_composite(assets[name], (4, 0))
            show(canvas, tile if row == 0 else submerged(tile, 10, water), x, 1670 + row * 200, 4)
            label(canvas, x, 1812 + row * 200, name + ".png", scale=2)
        label(canvas, x, 2044, "DEPTH 10", "9aafa4", 2)
    label(canvas, 900, 2108, "FRONT VIEW / ART COMPARISON", scale=2)
    label(canvas, 900, 2132, "GAME PREVIEW BELONGS TO WRECK", "9aafa4", 2)
    d.line((32, 2172, 1408, 2172), fill=color("536b69"))
    label(canvas, 32, 2190, "NEW TEXTURES / GPT-6 ASTRA / CC0-1.0", scale=2)
    label(canvas, 32, 2214, "COMPARISON / CC BY-SA 3.0 / DEFAULT ART: VANESSAE + TOBYPLOWY + TOPYWO + CISOUN / SOURCES IN LICENSE-media.md", "9aafa4", 2)
    return canvas


def validate(assets):
    for name, im in assets.items():
        if im.size != (16, 16) or im.mode != "RGBA":
            raise ValueError(name + ": expected 16x16 RGBA")
        pixels = list(im.get_flattened_data())
        alphas = {p[3] for p in pixels}
        if alphas != ({255} if name in BLOCKS else {0, 255}):
            raise ValueError(name + ": incorrect opacity")
        if any(p[3] == 0 and p != CLEAR for p in pixels):
            raise ValueError(name + ": hidden RGB in transparent pixels")
        print(name + ".png: 16x16 RGBA; " + str(sum(p[3] == 255 for p in pixels)) + "/256 opaque")
    mast = assets["wreck_mast"]
    if mast.crop((0, 0, 16, 1)).tobytes() != mast.crop((0, 15, 16, 16)).tobytes():
        raise ValueError("mast: vertical boundary differs")
    if any([x for x in range(16) if mast.getpixel((x, y))[3]] != [6, 7, 8, 9] for y in range(16)):
        raise ValueError("mast: expected a continuous centred four-pixel pole")
    print("mast: top/bottom RGBA identical; four opaque centred columns in all 16 rows")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated pixels with files; write nothing")
    args = parser.parse_args()
    assets = textures()
    validate(assets)
    outputs = {**assets, "preview": preview(assets)}
    for name, expected in outputs.items():
        path = HERE / (name + ".png")
        if args.check:
            with Image.open(path) as actual:
                if actual.mode != expected.mode or actual.size != expected.size or actual.tobytes() != expected.tobytes():
                    raise ValueError(str(path) + ": differs from generator")
        else:
            expected.save(path, compress_level=9)
    print(("Checked" if args.check else "Wrote") + " 11 textures and preview.png")


if __name__ == "__main__":
    main()
