#!/usr/bin/env python3
"""Placeholder cloak textures for grug_achievements (Round 33 lane C3).

Simple generated art, CC0 1.0 like every other own-art generator of this
project, in each cloak's palette from GPT-6 Astra's proposals
(cloak_palettes.json next to this file): cloth in the base colour, lining in
the shadow colour, a plain emblem block in the motif colour and one hem
stripe per tier. Astra's painted cloaks replace these files. The
format is the one tools/r33_c3/gen_cloak_model.py documents: 32x32 RGBA,
columns 0-15 the outer face seen from behind (shoulder at the top), columns
16-31 the lining seen from the front; the outer face's border pixels are also
the cloak's edges.

    python3 tools/r33_c3/gen_cloak_textures.py

Requires Pillow. Deterministic (seed 20261004): a re-run reproduces every PNG.
"""
import json
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


PALETTES = Path(__file__).with_name("cloak_palettes.json")


def emblem(img, colour, trim):
    """A plain 6x8 block with a 1-px trim frame, centred on the upper back."""
    for y in range(7, 15):
        for x in range(5, 11):
            edge = x in (5, 10) or y in (7, 14)
            put(img, x, y, trim if edge else colour)


def hem_stripes(img, count, colour):
    for index in range(count):
        y = 29 - 2 * index
        for x in range(1, 15):
            put(img, x, y, colour)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    rows = [{"id": "plain_grey", "palette": ["#7c7c78", "#5a5a56"]}] + \
        json.loads(PALETTES.read_text())
    wanted = set()
    for row in rows:
        palette = [hex_rgb(c) for c in row["palette"]]
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        cloth(img, rng, 0, palette[0])
        cloth(img, rng, 16, palette[1], folds=False)
        if len(palette) > 2:
            emblem(img, palette[2], palette[-1])
            tier = int(row["id"].rsplit("_", 1)[1])
            hem_stripes(img, tier, palette[-1])
        name = "grug_achievements_cloak_%s.png" % row["id"]
        wanted.add(name)
        img.save(OUT / name)
    for stale in OUT.glob("grug_achievements_cloak_*.png"):
        if stale.name not in wanted:
            stale.unlink()
            print("removed", stale.relative_to(REPO))
    print("wrote %d cloak textures to %s" % (len(wanted), OUT.relative_to(REPO)))


if __name__ == "__main__":
    main()
