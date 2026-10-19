#!/usr/bin/env python3
"""Round 51 TERRAIN T3: an image from a seabed_render.lua raster.

    python3 tools/r51_terrain/seabed_png.py RASTER OUT.png

Land green; bare seabed in blue, darker with depth; seagrass light green,
kelp dark olive, coral pink.
"""
import struct
import sys
import zlib

COLORS = {"land": (110, 150, 80), "seagrass": (120, 220, 90),
          "kelp": (60, 90, 30), "coral": (240, 110, 160)}


def main():
    with open(sys.argv[1]) as handle:
        width, height = (int(v) for v in handle.readline().split())
        cells = [line.split() for line in handle]
    raw = b""
    for j in range(height):
        row = bytearray(b"\x00")
        for i in range(width):
            kind, depth = cells[j * width + i]
            if kind == "bare":
                k = max(0.3, 1 - int(depth) / 30)
                row += bytes((int(40 * k), int(120 * k), int(210 * k)))
            else:
                row += bytes(COLORS[kind])
        raw += bytes(row)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    with open(sys.argv[2], "wb") as out:
        out.write(b"\x89PNG\r\n\x1a\n" +
                  chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                  chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    main()
