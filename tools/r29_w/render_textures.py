#!/usr/bin/env python3
"""Round 29 Lane W: first-version waystone and waypoint-marker art, original
and deterministic (CC0, like the other generated marker icons). The art lane
redraws them later under the same names.

* mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waystone.png -- 16x16 side of
  the standing stone: grey dressed stone with a glowing blue rune.
* mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waystone_top.png -- 16x16
  top/bottom: the same stone, a blue spark in the middle.
* mods/PLAYER/grug_map/textures/grug_map_waypoint.png -- 16x16 map/minimap
  marker: a dark-outlined grey standing stone with a blue rune.

Usage: python3 tools/r29_w/render_textures.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MAPGEN = ROOT / "mods/MAPGEN/grug_mapgen/textures"
MAP = ROOT / "mods/PLAYER/grug_map/textures"

STONE = [
    "ssssssssssssssss",
    "sllllllllllllllS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmBmmmmmmlS",
    "slmmmmmBBmmmmmlS",
    "slmmmmbBmbmmmmlS",
    "slmmmmmBBmmmmmlS",
    "slmmmmmBmmmmmmlS",
    "slmmmmmBmmmmmmlS",
    "slmmmmbBBbmmmmlS",
    "slmmmmmmmmmmmmlS",
    "sddddddddddddddS",
    "smmmmmmmmmmmmmmS",
    "slmmmmmmmmmmmmlS",
    "SSSSSSSSSSSSSSSS",
]
TOP = [
    "ssssssssssssssss",
    "sllllllllllllllS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmbbmmmmmlS",
    "slmmmmbBBbmmmmlS",
    "slmmmbBBBBbmmmlS",
    "slmmmbBBBBbmmmlS",
    "slmmmmbBBbmmmmlS",
    "slmmmmmbbmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "slmmmmmmmmmmmmlS",
    "sllllllllllllllS",
    "SSSSSSSSSSSSSSSS",
]
MARKER = [
    "................",
    "......oooo......",
    ".....ollllo.....",
    ".....olmmlo.....",
    ".....omBBmo.....",
    ".....omBmmo.....",
    ".....omBBmo.....",
    ".....omBmmo.....",
    ".....omBBmo.....",
    ".....ommmmo.....",
    ".....ommmmo.....",
    "....oddddddo....",
    "...oddddddddo...",
    "...oooooooooo...",
    "................",
    "................",
]
PALETTE = {
    "s": (92, 92, 98, 255), "S": (70, 70, 76, 255), "l": (168, 168, 172, 255),
    "m": (132, 132, 138, 255), "d": (104, 104, 110, 255),
    "B": (120, 200, 255, 255), "b": (70, 130, 190, 255),
    "o": (25, 21, 15, 255),
}


def draw(rows, path):
    im = Image.new("RGBA", (16, 16))
    for y, row in enumerate(rows):
        assert len(row) == 16, row
        for x, ch in enumerate(row):
            im.putpixel((x, y), PALETTE.get(ch, (0, 0, 0, 0)))
    im.save(path, optimize=True)


def main():
    draw(STONE, MAPGEN / "grug_mapgen_waystone.png")
    draw(TOP, MAPGEN / "grug_mapgen_waystone_top.png")
    draw(MARKER, MAP / "grug_map_waypoint.png")


if __name__ == "__main__":
    main()
