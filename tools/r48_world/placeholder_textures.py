#!/usr/bin/env python3
"""Round 48 lane WORLD: the PLACEHOLDER textures of the mailbox node
(`grug_mapgen:mailbox`, mods/MAPGEN/grug_mapgen/world_nodes.lua) under their
final file names, until lane ARTM's picked art replaces them (mail plan
§4.5). Generated, not drawn art; original, CC0-1.0.

The node is a one-node nodebox: a post (x and z within +-1/16, y -1/2..0)
under a box (x within +-1/4, z within +-5/16, y 0..1/2). A nodebox face shows
the part of its tile that lies under it, so the upper half of every side
tile (rows 0..7) is the box and the lower half (rows 8..15) the post:

  top    the lid (the box covers columns 4..11 by rows 3..12);
  side   red box sides over a wooden post;
  front  the -z face: the box front with a dark letter slot over the post.

Python 3 standard library only (zlib, struct).

Usage: python3 tools/r48_world/placeholder_textures.py
"""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/MAPGEN/grug_mapgen/textures"

RED = (168, 44, 38, 255)
RED_LIGHT = (204, 78, 62, 255)
RED_DARK = (104, 26, 24, 255)
SLOT = (24, 16, 14, 255)
WOOD = (122, 86, 50, 255)
WOOD_DARK = (88, 60, 34, 255)


def tile(paint):
    return [[paint(x, y) for x in range(16)] for y in range(16)]


def post(x, y):
    return WOOD_DARK if x in (6, 9) else WOOD


def top(x, y):
    if x in (4, 11) or y in (3, 12):
        return RED_DARK
    return RED_LIGHT if x in (7, 8) else RED


def side(x, y):
    if y >= 8:
        return post(x, y)
    if y == 0:
        return RED_LIGHT
    if y == 7:
        return RED_DARK
    return RED


def front(x, y):
    if y >= 8:
        return post(x, y)
    if x in (4, 11) or y in (0, 7):
        return RED_DARK
    if y in (2, 3) and 6 <= x <= 9:
        return SLOT
    return RED


def png(rows):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + \
            struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)
    header = struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    for name, paint in (("top", top), ("side", side), ("front", front)):
        path = OUT / ("grug_mapgen_mailbox_" + name + ".png")
        path.write_bytes(png(tile(paint)))
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
