#!/usr/bin/env python3
"""The third-person still frame of each overlay family (Python standard library).

The wield mesh draws a pixel only at alpha >= 128 (object_shader with
TILE_MATERIAL_BASIC: USE_DISCARD_REF, `base.a < 0.5` discarded), so a
family's still is the frame with the most such pixels summed over its shipped
strips (ties: the earlier frame). Prints each family's count per frame and
the still; `--check` compares with the `still` values of
grug_abilities.WEAPON_FX_ANIMATION in grug_abilities/init.lua and exits 1 on
a difference. Also prints how many effect pixels the alpha test drops.

Usage (repo root): python3 tools/r52_wfx/still_frames.py [--check]
"""
import glob
import os
import re
import struct
import sys
import zlib

MOD = os.path.join("mods", "PLAYER", "grug_abilities")


def rgba_rows(path):
    data = open(path, "rb").read()
    pos, idat = 8, b""
    width = height = colour = 0
    while pos < len(data):
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        pos += 12 + size
        if kind == b"IHDR":
            width, height, depth, colour = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and colour == 6 and body[12] == 0, path + ": 8-bit RGBA only"
        elif kind == b"IDAT":
            idat += body
    raw, stride, rows, prev, at = zlib.decompress(idat), width * 4, [], bytearray(width * 4), 0
    for _ in range(height):
        kind, line = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return width, height, rows


def main():
    families, dropped, drawn = {}, 0, 0
    for path in sorted(glob.glob(os.path.join(MOD, "textures", "grug_abilities_fx_*.png"))):
        family = os.path.basename(path)[len("grug_abilities_fx_"):].split("_")[0]
        width, height, rows = rgba_rows(path)
        counts = []
        for frame in range(height // width):
            shown = 0
            for y in range(frame * width, (frame + 1) * width):
                for x in range(width):
                    alpha = rows[y][x * 4 + 3]
                    if alpha >= 128:
                        shown += 1
                    elif alpha > 0:
                        dropped += 1
            drawn += shown
            counts.append(shown)
        total = families.setdefault(family, [0] * len(counts))
        for frame, shown in enumerate(counts):
            total[frame] += shown
    stills = {}
    for family in sorted(families):
        total = families[family]
        stills[family] = max(range(len(total)), key=lambda f: (total[f], -f))
        print("%-10s %s still %d" % (family, total, stills[family]))
    print("effect pixels drawn (alpha >= 128): %d, dropped by the alpha test: %d" % (drawn, dropped))
    if "--check" in sys.argv:
        source = open(os.path.join(MOD, "init.lua")).read()
        shipped = dict((f, int(s)) for f, s in re.findall(r"\n\t(\w+) = {frames = \d+, frame_length = [\d.]+, still = (\d+)}", source))
        if shipped != stills:
            print("MISMATCH init.lua %s, strips %s" % (shipped, stills))
            sys.exit(1)
        print("still frames match init.lua")


if __name__ == "__main__":
    main()
