#!/usr/bin/env python3
"""Round 44 lane MB: the baked map layer's art as Lua data.

The engine has core.encode_png but no PNG decoder, so the map renderer
(mods/PLAYER/grug_map/bake.lua) reads its icons and its pixel font from a
generated Lua file instead of the PNGs: mods/PLAYER/grug_map/baked_art.lua.
This script decodes the PNGs (standard library only: zlib and the PNG
filters; every colour type, bit depths 1-8, palette transparency) and writes
that file; --check regenerates it in memory and exits 1 when the committed
file differs (stale art or a hand edit).

  python3 tools/r44_mb/gen_baked_art.py [--art DIR] [--check]

DIR (default mods/PLAYER/grug_map/art) holds, per kind in KINDS,
baked_<kind>.png (16 x 16, the world map) and baked_<kind>_mini.png (6 x 6,
the minimap), plus the font: font.png, one row of white glyphs under a top
row with a red mark at each glyph's first column, each glyph followed by one
fully transparent column, and font.txt, the characters in sheet order on
its first line.

The file records `art_version` and `font_version`, digests of the source
files and of this script, which enter the map's cache key: new art or a
new font re-renders every world's map at its next start.
"""
import argparse
import hashlib
import os
import struct
import sys
import zlib

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_ART = "mods/PLAYER/grug_map/art"
OUTPUT = "mods/PLAYER/grug_map/baked_art.lua"
KINDS = ["start", "capital", "village", "outpost", "fortress", "war_camp", "bandit",
         "mirefolk", "mine", "clash", "rare_den", "king", "dragon"]
SIZES = {"": 16, "_mini": 6}
# Palette symbols of the icon rows ('"' and '\\' left out, so a row is a
# plain Lua string); the first is the transparent pixel when there is one.
ALPHABET = (".#abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            "+*=%&$@!?/|<>()[]{}~^:;_")


def decode_png(data):
    """(width, height, rows of (r, g, b, a)) of a non-interlaced PNG."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, palette, trns = 8, b"", None, None
    while pos < len(data):
        length, = struct.unpack(">I", data[pos:pos + 4])
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if interlace:
                raise ValueError("interlaced PNG")
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bits = channels * depth
    stride = (width * bits + 7) // 8
    step = max(1, bits // 8)
    raw = zlib.decompress(idat)
    rows, previous, offset = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[offset], bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        for i in range(stride):
            left = line[i - step] if i >= step else 0
            up = previous[i]
            corner = previous[i - step] if i >= step else 0
            if kind == 1:
                line[i] = (line[i] + left) & 255
            elif kind == 2:
                line[i] = (line[i] + up) & 255
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                pred = left if pa <= pb and pa <= pc else (up if pb <= pc else corner)
                line[i] = (line[i] + pred) & 255
        previous = line
        samples = []
        if depth == 8:
            samples = list(line)
        elif depth == 16:
            samples = [line[i] for i in range(0, len(line), 2)]
        else:
            per = 8 // depth
            for byte in line:
                for k in range(per):
                    samples.append((byte >> (8 - depth * (k + 1))) & ((1 << depth) - 1))
        row = []
        for x in range(width):
            s = samples[x * channels:(x + 1) * channels]
            if ctype == 3:
                index = s[0]
                r, g, b = palette[index]
                a = trns[index] if trns and index < len(trns) else 255
            else:
                scale = 255 // ((1 << min(depth, 8)) - 1) if depth < 8 else 1
                if ctype == 0:
                    r = g = b = s[0] * scale
                    a = 255
                elif ctype == 4:
                    r = g = b = s[0] * scale
                    a = s[1] * scale
                elif ctype == 2:
                    r, g, b = s
                    a = 255
                else:
                    r, g, b, a = s
            row.append((r, g, b, a) if a > 0 else (0, 0, 0, 0))
        rows.append(row)
    return width, height, rows


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def icon_lua(name, width, height, rows):
    colours = []
    if any(p[3] == 0 for row in rows for p in row):
        colours.append((0, 0, 0, 0))
    for row in rows:
        for p in row:
            if p not in colours:
                colours.append(p)
    wide = len(colours) > len(ALPHABET)
    if wide and len(colours) > len(ALPHABET) * len(ALPHABET):
        raise ValueError("%s: too many colours (%d)" % (name, len(colours)))

    def symbol(index):
        if not wide:
            return ALPHABET[index]
        return ALPHABET[index // len(ALPHABET)] + ALPHABET[index % len(ALPHABET)]

    code = {colour: symbol(i) for i, colour in enumerate(colours)}
    lines = ["\t\t%s = {w = %d, h = %d," % (name, width, height),
             "\t\t\tpalette = {%s}," % ", ".join(
                 '[%s] = "%02x%02x%02x%02x"' % ((lua_string(code[c]),) + c) for c in colours),
             "\t\t\trows = {"]
    for row in rows:
        lines.append("\t\t\t\t%s," % lua_string("".join(code[p] for p in row)))
    lines.append("\t\t\t}},")
    return lines


def font_lua(png, text):
    width, height, rows = decode_png(png)
    chars = text.split("\n")[0]
    if not chars:
        raise ValueError("font.txt: no characters")
    marks = [x for x in range(width)
             if rows[0][x][3] > 128 and rows[0][x][0] > 200 and rows[0][x][1] < 60 and
             rows[0][x][2] < 60]
    if len(marks) != len(chars):
        raise ValueError("font.png has %d glyph marks, font.txt %d characters" %
                         (len(marks), len(chars)))
    if len(set(chars)) != len(chars):
        raise ValueError("font.txt repeats a character")

    def blank(x):
        return all(rows[y][x][3] < 128 for y in range(1, height))

    lines = ["\tfont = {height = %d, glyphs = {" % (height - 1)]
    for index, char in enumerate(chars):
        start = marks[index]
        end = marks[index + 1] - 1 if index + 1 < len(marks) else (
            width - 1 if blank(width - 1) else width)
        if end <= start:
            raise ValueError("glyph %r has no columns" % char)
        glyph = ["".join("#" if rows[y][x][3] >= 128 else "." for x in range(start, end))
                 for y in range(1, height)]
        lines.append("\t\t[%s] = {%s}," % (lua_string(char), ", ".join(lua_string(r) for r in glyph)))
    lines.append("\t}},")
    return lines


def build(art):
    folder = os.path.join(REPO, art)
    script = open(os.path.abspath(__file__), "rb").read()
    art_hash, icons = hashlib.sha256(script), []
    for kind in KINDS:
        for suffix, size in SIZES.items():
            name = "baked_%s%s.png" % (kind, suffix)
            data = open(os.path.join(folder, name), "rb").read()
            art_hash.update(name.encode() + b"\0" + data)
            width, height, rows = decode_png(data)
            if (width, height) != (size, size):
                raise ValueError("%s is %dx%d, expected %dx%d" % (name, width, height, size, size))
            icons.extend(icon_lua(kind + suffix, width, height, rows))
    font_png = open(os.path.join(folder, "font.png"), "rb").read()
    font_txt = open(os.path.join(folder, "font.txt"), "rb").read()
    font_hash = hashlib.sha256(script + font_png + b"\0" + font_txt)
    command = "tools/r44_mb/gen_baked_art.py" + ("" if art == DEFAULT_ART else " --art " + art)
    lines = ["-- GENERATED by %s; do not edit." % command,
             "-- The baked map layer's icons and pixel font (bake.lua), decoded from",
             "-- the PNGs in %s; `--check` tells a stale copy." % art,
             "return {",
             '\tart_version = "%s",' % art_hash.hexdigest()[:16],
              '\tfont_version = "%s",' % font_hash.hexdigest()[:16],
              "\ticons = {"]
    lines += icons
    lines.append("\t},")
    lines += font_lua(font_png, font_txt.decode("utf-8"))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--art", default=DEFAULT_ART, help="art folder, repository-relative")
    parser.add_argument("--check", action="store_true", help="compare, do not write")
    args = parser.parse_args()
    text = build(args.art.rstrip("/"))
    path = os.path.join(REPO, OUTPUT)
    if args.check:
        current = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        if current != text:
            print("%s is stale: run tools/r44_mb/gen_baked_art.py --art %s" % (OUTPUT, args.art))
            return 1
        print("%s is current (%s)" % (OUTPUT, args.art))
        return 0
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("wrote %s from %s" % (OUTPUT, args.art))
    return 0


if __name__ == "__main__":
    sys.exit(main())
