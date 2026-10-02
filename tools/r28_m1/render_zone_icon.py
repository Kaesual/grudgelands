#!/usr/bin/env python3
"""Round 28 Lane M1: the Map tab's zone marker, original and deterministic
(CC0 like the other grug_map marker icons, see
mods/PLAYER/grug_map/LICENSE-media.md).

* grug_map_zone.png -- 16x16 pixel art: a parchment swallowtail pennant with a
  dark red band on a dark pole, outlined like the other marker icons. A plain
  placeholder; a final icon may replace it.

Usage: python3 tools/r28_m1/render_zone_icon.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_map/textures"

ZONE = [
    "................",
    "....o...........",
    "....oooooooooo..",
    "....oWWWWWWWWo..",
    "....oWWWWWWWo...",
    "....oRRRRRRo....",
    "....oWWWWWWWo...",
    "....oWWWWWWWWo..",
    "....oooooooooo..",
    "....o...........",
    "....o...........",
    "....o...........",
    "....o...........",
    "...ooo..........",
    "................",
    "................",
]
PALETTE = {"o": (25, 21, 15, 255), "W": (243, 232, 200, 255),
           "R": (150, 44, 36, 255)}


def main():
    im = Image.new("RGBA", (16, 16))
    for y, row in enumerate(ZONE):
        assert len(row) == 16, row
        for x, ch in enumerate(row):
            im.putpixel((x, y), PALETTE.get(ch, (0, 0, 0, 0)))
    im.save(OUT / "grug_map_zone.png", optimize=True)


if __name__ == "__main__":
    main()
