#!/usr/bin/env python3
"""Generates the Tortoise's ball of mud, grug_mobs_tortoise_mud.png (Round 84
WATER): a 16x16 projectile sprite.

Grudgelands project, **CC0 1.0** - original pixel art, NOT derived from any
vendored or third-party asset. Fully deterministic (no randomness), authored
as a 16x16 ASCII map plus a palette in the style of
tools/gen_mob_item_textures.py (whose full run would rewrite other files, so
this sprite has its own script).

Usage:
    python3 tools/r84_water/gen_mud_texture.py [outdir]

Default outdir: mods/ENTITIES/grug_mobs/textures
"""

import os
import sys

from PIL import Image

MUD = """
................
................
................
.....oooo.......
....ommmmoo.....
...omwhmmmmo....
..omhhmmmmmdo...
..ommmmmmmddo...
..ommmmmmdddo...
...ommmmdddo....
...oommdddoo....
.....odddo......
......odo.......
.......o........
................
................
"""

PALETTE = {"o": "#33261a", "m": "#6b5636", "d": "#4e3e27",
           "h": "#8f7a52", "w": "#c2b083"}


def rgba(hex_colour):
    h = hex_colour.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join("mods", "ENTITIES", "grug_mobs", "textures")
    if not os.path.isdir(outdir):
        raise SystemExit("no such directory: " + outdir)
    rows = MUD.strip("\n").split("\n")
    assert len(rows) == 16, "%d rows" % len(rows)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        assert len(row) == 16, "row %d has %d cols" % (y, len(row))
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = rgba(PALETTE[ch])
    path = os.path.join(outdir, "grug_mobs_tortoise_mud.png")
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
