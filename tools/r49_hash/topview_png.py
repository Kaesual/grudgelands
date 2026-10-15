#!/usr/bin/env python3
"""Round 49 lane HASH: render a tools/r49_hash/topview.lua text grid as a PNG.

    python3 -I tools/r49_hash/topview_png.py VIEW.txt VIEW.png [SCALE]

One pixel block (SCALE, default 3) per node column: trunk brown, leaves
green, gathering source red, plant light green, water blue, ground grey.
"""
import struct
import sys
import zlib

COLOURS = {"T": (110, 70, 30), "L": (30, 120, 40), "G": (220, 40, 40),
           "P": (150, 210, 110), "W": (60, 100, 200), ".": (170, 170, 160),
           " ": (0, 0, 0)}


def main():
    source, target = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    with open(source, encoding="utf-8") as handle:
        lines = [line.rstrip("\n") for line in handle if not line.startswith("topview")]
    height, width = len(lines), max(len(line) for line in lines)
    raw = bytearray()
    for line in lines:
        row = bytearray()
        for x in range(width):
            row += bytes(COLOURS.get(line[x] if x < len(line) else " ", (255, 0, 255))) * scale
        for _ in range(scale):
            raw += b"\x00" + row

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", width * scale, height * scale, 8, 2, 0, 0, 0)) +
           chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    with open(target, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    main()
