#!/usr/bin/env python3
"""Round 76 lane SOCIAL: draws the clan mark, a 16 px shield in the clan
chat's green (#7ee081) with a dark outline, for the Online Players rows.

    python3 tools/r76_social/clan_mark.py [repo]

Writes mods/PLAYER/grug_clans/textures/grug_clans_mark.png.
"""
import sys
from pathlib import Path

from PIL import Image

GREEN, LIGHT, OUTLINE = (0x7E, 0xE0, 0x81, 255), (0xB8, 0xF2, 0xB9, 255), (0x16, 0x33, 0x1B, 255)
# The shield's half width per row (centre 7.5): straight sides, then a point.
HALF = {1: 6, 2: 6, 3: 6, 4: 6, 5: 6, 6: 6, 7: 6, 8: 5.5, 9: 5, 10: 4, 11: 3, 12: 2, 13: 1, 14: 0.5}


def inside(x, y):
    half = HALF.get(y)
    return half is not None and abs(x + 0.5 - 8) <= half


def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(16):
        for x in range(16):
            if not inside(x, y):
                continue
            edge = any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            # A light band under the top edge, the rest flat green.
            pixels[x, y] = OUTLINE if edge else LIGHT if y == 2 else GREEN
    out = repo / "mods/PLAYER/grug_clans/textures/grug_clans_mark.png"
    image.save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    main()
