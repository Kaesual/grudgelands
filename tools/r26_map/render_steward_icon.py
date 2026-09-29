#!/usr/bin/env python3
"""Housing Steward map marker: original 16x16 pixel art (house and key).

Drawn from the character grid below; no imported image assets. The output is
deterministic CC0 art like the other 16x16 map marker icons (the Fallen Crown
of tools/r8_mob1/gen_boss_art.py).

Usage: python3 tools/r26_map/render_steward_icon.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_map/textures/grug_map_housing_steward.png"

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (25, 21, 15, 255),      # outline (the heading markers' outline)
    "r": (176, 64, 44, 255),     # roof
    "R": (214, 104, 70, 255),    # roof highlight
    "w": (236, 220, 180, 255),   # wall
    "d": (112, 72, 38, 255),     # door
    "b": (120, 176, 214, 255),   # window
    "g": (232, 184, 58, 255),    # key gold
    "G": (255, 228, 124, 255),   # key highlight
}

# A cottage on the left, a gold key on the right, both outlined so the icon
# reads on sea and on land.
GRID = [
    "....o...........",
    "...oRo..........",
    "..oRrro....ooo..",
    ".oRrrrro..oGggo.",
    "oRrrrrrrooggoggo",
    "ooooooooooggoggo",
    ".owwwwwo.oggoggo",
    ".owbwbwo..ogggo.",
    ".owwwwwo...ogo..",
    ".owwwwwo...ogo..",
    ".owdddwo...oggo.",
    ".owdddwo...ogo..",
    ".owdddwo...oggo.",
    ".owdddwo...ogo..",
    ".ooooooo...ooo..",
    "................",
]


def render():
    assert len(GRID) == 16 and all(len(row) == 16 for row in GRID)
    image = Image.new("RGBA", (16, 16))
    px = image.load()
    for y, row in enumerate(GRID):
        for x, cell in enumerate(row):
            px[x, y] = PALETTE[cell]
    return image


def main():
    render().save(OUT, optimize=True)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
