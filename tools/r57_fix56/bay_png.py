#!/usr/bin/env python3
"""Round 57 lane FIX56: draw the text grids of bay_scan.lua as PNG images.

    python3 tools/r57_fix56/bay_png.py GRID_DIR

One PNG next to each grid (the gameplay classes after the fix): land grey,
bay and other planned water light blue, the coastal belt teal, the open sea
navy, channels purple; the columns the fix moved from belt to bay water
yellow, no-fly sea within 24 nodes of bay water landward of the mouth red.
+z is up.
"""
import pathlib
import sys

from PIL import Image

COLOURS = {
    ".": (150, 150, 140), "b": (120, 190, 240), "s": (40, 140, 150), "o": (20, 30, 90),
    "c": (120, 60, 160), "S": (230, 30, 30), "B": (255, 255, 0),
}


def main():
    folder = pathlib.Path(sys.argv[1])
    for path in sorted(folder.glob("*.txt")):
        lines = path.read_text().splitlines()
        _, _, _, width, height = (int(v) for v in lines[0].split())
        image = Image.new("RGB", (width, height))
        pixels = image.load()
        for row, line in enumerate(lines[1:1 + height]):
            for col, ch in enumerate(line):
                pixels[col, row] = COLOURS.get(ch, (255, 0, 255))
        image.save(path.with_suffix(".png"))
        print(path.with_suffix(".png"))


if __name__ == "__main__":
    main()
