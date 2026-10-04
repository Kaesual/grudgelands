#!/usr/bin/env python3
"""Stage-1 cloak textures for grug_achievements (Round 33 lane C3).

Simple generated art, CC0 1.0 like every other own-art generator of this
project; GPT-6 Astra's painted cloaks replace these files in stage 2. The
format is the one tools/r33_c3/gen_cloak_model.py documents: 32x32 RGBA,
columns 0-15 the outer face seen from behind (shoulder at the top), columns
16-31 the lining seen from the front; the outer face's border pixels are also
the cloak's edges.

    python3 tools/r33_c3/gen_cloak_textures.py

Requires Pillow. Deterministic (seed 20261004): a re-run reproduces every PNG.
"""
import random
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "mods/PLAYER/grug_achievements/textures"
SEED = 20261004


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, factor):
    return tuple(max(0, min(255, int(round(c * factor)))) for c in rgb)


def cloth(img, rng, x0, base, folds=True):
    """A 16x32 wool panel at column x0: noise, soft folds, collar and hem."""
    for y in range(32):
        for x in range(16):
            factor = 1.0 + rng.uniform(-0.05, 0.05)
            if folds and x in (4, 11):
                factor *= 0.88
            if folds and x in (5, 12):
                factor *= 1.06
            if y < 2:
                factor *= 0.78          # the collar
            elif y == 31:
                factor *= 0.80          # the hem
            if x in (0, 15):
                factor *= 0.85          # the edges
            img.putpixel((x0 + x, y), shade(base, factor) + (255,))


def put(img, x, y, rgb):
    img.putpixel((x, y), tuple(rgb) + (255,))


def crown(img):
    gold, dark, gem = hex_rgb("#e0b23a"), hex_rgb("#9a7218"), hex_rgb("#c8323a")
    rows = ["#...##...#",
            "##..##..##",
            "##########",
            "#o##o##o##",
            "##########",
            ".########."]
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch == "#":
                put(img, 3 + dx, 9 + dy, gold if dy < 3 else shade(gold, 0.92))
            elif ch == "o":
                put(img, 3 + dx, 9 + dy, gem)
    for dx in range(1, 9):
        put(img, 3 + dx, 15, dark)


def crossed_swords(img):
    blade, edge = hex_rgb("#d8dce2"), hex_rgb("#8a9098")
    guard, grip = hex_rgb("#d6a83a"), hex_rgb("#5a3a1c")
    for i in range(10):
        put(img, 3 + i, 6 + i, blade)        # tip top-left, grip bottom-right
        put(img, 12 - i, 6 + i, blade)       # tip top-right, grip bottom-left
        if i < 8:
            put(img, 4 + i, 6 + i, edge)
            put(img, 11 - i, 6 + i, edge)
    for x, y in ((12, 15), (13, 14), (11, 16), (3, 15), (2, 14), (4, 16)):
        put(img, x, y, guard)                # crossguards
    for x, y in ((13, 17), (14, 18), (2, 17), (1, 18)):
        put(img, x, y, grip)


SCALE = ["BBBB",
         "BLBB",
         "DBBD",
         ".DD."]


def scales(img, rng, base):
    """Overlapping scales, rounded edge down; upper rows lie over lower ones."""
    light, dark = shade(base, 1.35), shade(base, 0.62)
    rows = list(range(2, 31, 3))
    for row_index in reversed(range(len(rows))):
        top = rows[row_index]
        offset = 2 if row_index % 2 else 0
        for left in range(-offset, 16, 4):
            for dy, line in enumerate(SCALE):
                for dx, ch in enumerate(line):
                    x, y = left + dx, top + dy
                    if ch == "." or not (1 <= x <= 14 and 2 <= y <= 30):
                        continue
                    colour = {"B": shade(base, 1.0 + rng.uniform(-0.04, 0.04)),
                              "L": light, "D": dark}[ch]
                    put(img, x, y, colour)


CLOAKS = {
    "grey": dict(base="#7c7c78", lining="#5a5a56"),
    "hunter": dict(base="#2c4a26", lining="#3d3020"),
    "kingslayer": dict(base="#5b1f3a", lining="#3a1426", motif=crown),
    "wyvernslayer": dict(base="#2f6e34", lining="#1f3a20", motif="scales"),
    "dragonslayer": dict(base="#2d508f", lining="#1c2c4a", motif="scales"),
    "honored": dict(base="#7a1616", lining="#4a1010", motif=crossed_swords),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    for name, spec in CLOAKS.items():
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        cloth(img, rng, 0, hex_rgb(spec["base"]))
        cloth(img, rng, 16, hex_rgb(spec["lining"]), folds=False)
        motif = spec.get("motif")
        if motif == "scales":
            scales(img, rng, hex_rgb(spec["base"]))
        elif motif:
            motif(img)
        path = OUT / ("grug_achievements_cloak_%s.png" % name)
        img.save(path)
        print("wrote", path.relative_to(REPO))


if __name__ == "__main__":
    main()
