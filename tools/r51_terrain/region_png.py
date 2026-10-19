#!/usr/bin/env python3
"""Round 51 TERRAIN T2: images from a region_dump.lua raster.

    python3 tools/r51_terrain/region_png.py DUMP PREFIX

Writes PREFIX<n>-class.png (land green; inland and bay water light blue, the
belt or shelf middle blue, the open sea dark, a channel violet; water shaded
by depth) and PREFIX<n>-depth.png (land green; water at most 12 deep light,
13-22 middle, deeper dark; a channel 9-11 deep green), one pair per region.
"""
import struct
import sys
import zlib


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


CLASS = {"land": (110, 150, 80), "planned_water": (110, 190, 225),
         "coastal_shelf": (60, 130, 190), "deep_ocean": (25, 45, 95),
         "immutable_dragon_channel": (150, 90, 190)}


def class_color(cls, depth):
    base = CLASS.get(cls, (255, 0, 0))
    if cls == "land":
        return base
    k = min(1.0, max(0.4, 1 - depth / 45.0))
    return tuple(int(v * k) for v in base)


def depth_color(cls, depth):
    if cls == "land":
        return CLASS["land"]
    if cls == "immutable_dragon_channel" and 9 <= depth <= 11:
        return (90, 200, 130)
    if depth <= 12:
        return (120, 200, 230)
    if depth <= 22:
        return (50, 110, 180)
    return (20, 40, 90)


def main():
    regions, current = [], None
    with open(sys.argv[1]) as handle:
        for line in handle:
            if line.startswith("# region"):
                current = {"hdr": [int(v) for v in line.split()[2:]], "cols": []}
                regions.append(current)
                continue
            fields = line.split()
            current["cols"].append((fields[2], 1 - int(fields[4])))
    for n, region in enumerate(regions):
        x0, _, x1, _, step = region["hdr"]
        width = (x1 - x0) // step + 1
        height = len(region["cols"]) // width
        for name, color in (("class", class_color), ("depth", depth_color)):
            rows = []
            for j in range(height):
                row = []
                for i in range(width):
                    row.extend(color(*region["cols"][j * width + i]))
                rows.append(row)
            path = f"{sys.argv[2]}{n}-{name}.png"
            write_png(path, width, height, rows)
            print(path, width, height)


if __name__ == "__main__":
    main()
