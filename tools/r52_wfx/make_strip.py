#!/usr/bin/env python3
"""Write the WFX probe's throwaway test strip (Python standard library).

Eight vertical 16 x 16 frames, 16 x 128 RGBA, each a solid 6 x 6 block of
its own colour at the top right (a diagonal sprite's tip), transparent
elsewhere. Animated, the weapon shows ONE block whose colour changes; the
definition's animation not applied, the whole strip squashes onto the
weapon as eight thin stripes. Never shipped: tools/r52_wfx/capture.sh writes
it into its temporary copy of the probe mod.

Usage: make_strip.py OUT.png
"""
import struct
import sys
import zlib

COLOURS = [(255, 0, 0), (255, 140, 0), (255, 255, 0), (0, 255, 0),
           (0, 255, 255), (0, 64, 255), (255, 0, 255), (255, 255, 255)]


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main():
    rows = []
    for frame, (r, g, b) in enumerate(COLOURS):
        for y in range(16):
            row = bytearray(b"\x00")
            for x in range(16):
                inside = x >= 10 and y < 6
                row += bytes((r, g, b, 255) if inside else (0, 0, 0, 0))
            rows.append(bytes(row))
    raw = b"".join(rows)
    png = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16 * len(COLOURS), 8, 6, 0, 0, 0)) +
           chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(sys.argv[1], "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    main()
