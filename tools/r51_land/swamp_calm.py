#!/usr/bin/env python3
"""Calmer swamp ground proposals and a continuous hanging-moss strand.

    python3 -I tools/r51_land/swamp_calm.py     # writes tools/r51_land/swamp/*.png

The Round 47 ART textures (tools/r47_art/swamp/generate.py) repeat visibly:
their grain is 68 % a 4 x 4 coarse field spread over the whole six-colour
palette, plus stamped pockets, so every 16 x 16 tile carries one strong
motif. These proposals keep ART's palettes but
  * weight the coarse field less and use the middle of the palette (calm),
  * drop the stamped pockets or shrink them to one muted spot,
  * offer 32 x 32 versions meant for align_style = "world", scale = 2
    (one texture spans 2 x 2 nodes, same 16 px per node).
The hanging-moss strand continues the end piece's top row through the
whole node, so stacked moss reads as one hanging curtain that ends in the
existing tapered piece.
"""
import os
from random import Random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "swamp")
CLEAR = (0, 0, 0, 0)


def rgba(value):
    return tuple(bytes.fromhex(value.lstrip("#"))) + (255,)


def field(seed, size, cell, coarse_weight):
    """A periodic field on a size x size torus: bilinear coarse cells plus paired grain."""
    rng = Random(seed)
    n = size // cell
    coarse = [[rng.random() for _ in range(n)] for _ in range(n)]
    fine = [[rng.random() for _ in range(size)] for _ in range(size)]
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            gx, gy = x // cell, y // cell
            u, v = x % cell / cell, y % cell / cell
            a = coarse[gy][gx] * (1 - u) + coarse[gy][(gx + 1) % n] * u
            b = coarse[(gy + 1) % n][gx] * (1 - u) + coarse[(gy + 1) % n][(gx + 1) % n] * u
            # isotropic grain: the pixel and its four neighbours (ART's
            # horizontal pairs read as streaks once the coarse field is weak)
            nb = (fine[y][(x + 1) % size] + fine[y][x - 1] + fine[(y + 1) % size][x] + fine[y - 1][x]) / 4
            g = fine[y][x] * 0.6 + nb * 0.4
            row.append((a * (1 - v) + b * v) * coarse_weight + g * (1 - coarse_weight))
        out.append(row)
    return out


def paint(values, colors):
    """Rank-map the field onto the palette: equal shares per colour, so the
    contrast is the palette's, never the noise's."""
    size = len(values)
    flat = sorted(v for row in values for v in row)
    palette = [rgba(c) for c in colors]
    out = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            rank = flat.index(values[y][x]) / len(flat)
            out.putpixel((x, y), palette[min(len(palette) - 1, int(rank * len(palette)))])
    return out


def stamp(img, x, y, rows, palette):
    size = img.size[0]
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ".":
                img.putpixel(((x + dx) % size, (y + dy) % size), palette[ch])


# ART's palettes (tools/r47_art/swamp/generate.py), outer extremes dropped
GRASS = ["28482a", "31532d", "395e31", "446a37"]
WET = ["3a3e2d", "454633", "50513b", "5b5840"]
WET_SIDE = ["323629", "3b3f2e", "464633", "50503a"]
PUDDLE = {"s": rgba("343a2c"), "w": rgba("2c362e"), "r": rgba("34443a")}
SOIL = {"s": rgba("3b3f2e"), "m": rgba("484936")}
TIP = {"h": rgba("4f7540")}


def wet_grass(size, seed):
    img = paint(field(seed, size, size // 4, 0.35), GRASS)
    rng = Random(seed + 1)
    for _ in range(size * size // 64):          # a few lighter blade tips
        stamp(img, rng.randrange(size), rng.randrange(size), ["h"], TIP)
    if size == 32:                              # one small muddy opening per 2 x 2 nodes
        stamp(img, 21, 9, [".s", "sm", ".s"], SOIL)
    return img


def wet_mud(size, seed):
    img = paint(field(seed, size, size // 4, 0.25 if size == 16 else 0.35), WET)
    if size == 16:
        stamp(img, 9, 6, [".s.", "swr", ".s."], PUDDLE)
    else:
        stamp(img, 6, 20, [".ss.", "swrs", ".ss."], PUDDLE)
        stamp(img, 23, 5, [".s.", "swr", ".s."], PUDDLE)
    return img


def wet_side(seed):
    return paint(field(seed, 16, 4, 0.30), WET_SIDE)


def grass_side(cap, side):
    out = side.copy()
    depths = [3, 4, 3, 3, 4, 5, 4, 3, 3, 4, 4, 5, 4, 3, 3, 3]
    for x, d in enumerate(depths):
        for y in range(d):
            out.putpixel((x, y), cap.getpixel((x, y)))
        out.putpixel((x, d), rgba("2c3d27"))
    return out


# The end piece's top row (tools/r47_art/swamp/generate.py "hanging") is
# ".ms..msm..ms.ms."; the strand starts and ends with exactly that row, so
# strand over strand and strand over end piece join without a gap.
STRAND = [
    ".ms..msm..ms.ms.",
    ".m...m.s..m..ms.",
    ".ms..m.m..hs.m..",
    "..m..h.m...m.s..",
    ".hm..m..s..m.m..",
    ".m...s..m..h.m..",
    ".m..hm..m..m..m.",
    ".s...m.hm..m..m.",
    ".m...m..s.ms..h.",
    ".mh..s..m.m...m.",
    "..m..m..m.m..sm.",
    "..m..h.ms.m..m..",
    ".sm..m.m..h..m..",
    ".m...m.m..m..m..",
    ".ms..s.m..ms.ms.",
    ".ms..msm..ms.ms.",
]
SHADE = {"s": rgba("4c5e48"), "m": rgba("7b8968"), "h": rgba("a2ab82")}


def moss_strand():
    assert len(STRAND) == 16 and all(len(r) == 16 for r in STRAND)
    out = Image.new("RGBA", (16, 16), CLEAR)
    for y, row in enumerate(STRAND):
        for x, ch in enumerate(row):
            if ch != ".":
                out.putpixel((x, y), SHADE[ch])
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    side = wet_side(51003)
    grass16 = wet_grass(16, 51001)
    files = {
        "wet_grass_top_calm": grass16,
        "wet_grass_top_calm32": wet_grass(32, 51011),
        "wet_grass_side_calm": grass_side(grass16, side),
        "mud_mottled_top_calm": wet_mud(16, 51002),
        "mud_mottled_top_calm32": wet_mud(32, 51012),
        "mud_mottled_side_calm": side,
        "hanging_moss_strand": moss_strand(),
    }
    for name, img in files.items():
        img.save(os.path.join(OUT, name + ".png"))
        print("wrote", os.path.relpath(os.path.join(OUT, name + ".png")))


if __name__ == "__main__":
    main()
