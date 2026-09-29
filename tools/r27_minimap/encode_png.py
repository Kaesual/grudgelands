#!/usr/bin/env python3
"""Round 27 Lane M: RGBA dump -> PNG exactly as Luanti's core.encode_png.

    python3 tools/r27_minimap/encode_png.py <dir> NAME [NAME ...]

Reads <dir>/NAME.rgba and <dir>/NAME.txt (width height seconds) written by
render_base.lua and writes <dir>/NAME.png the way src/util/png.cpp (5.17)
encodes: an all-opaque image reduced to RGB (grey if R = G = B everywhere),
8 bit, every scanline with filter byte 0, one zlib stream at level 9 (base.lua
passes compression 9). The file size is therefore the size the
client downloads.
"""
import struct
import sys
import zlib


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main():
    folder = sys.argv[1]
    for name in sys.argv[2:]:
        with open(f"{folder}/{name}.txt") as meta:
            width, height = (int(v) for v in meta.read().split()[:2])
        with open(f"{folder}/{name}.rgba", "rb") as raw:
            data = raw.read()
        assert len(data) == width * height * 4, name
        color_type, pixel = 6, 4
        if all(a == 255 for a in data[3::4]):
            r, g, b = data[0::4], data[1::4], data[2::4]
            if r == g == b:
                data, color_type, pixel = bytes(r), 0, 1
            else:
                rgb = bytearray(width * height * 3)
                rgb[0::3], rgb[1::3], rgb[2::3] = r, g, b
                data, color_type, pixel = bytes(rgb), 2, 3
        stride = width * pixel
        scan = b"".join(b"\0" + data[row * stride:(row + 1) * stride] for row in range(height))
        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(scan, 9))
               + chunk(b"IEND", b""))
        with open(f"{folder}/{name}.png", "wb") as out:
            out.write(png)
        print(f"{name}.png {width}x{height} {len(png)} bytes")


if __name__ == "__main__":
    main()
