#!/usr/bin/env python3
"""Round 44 lane MB: the baked map layer's art as Lua data.

The engine has core.encode_png but no PNG decoder, so the map renderer
(mods/PLAYER/grug_map/bake.lua) reads its icons and its pixel font from a
generated Lua file instead of the PNGs: mods/PLAYER/grug_map/baked_art.lua.
This script decodes the PNGs (standard library only: zlib and the PNG
filters; every colour type, bit depths 1-16, palette transparency and the
grey/RGB transparency key) and writes
that file; --check regenerates it in memory and exits 1 when the committed
file differs (stale art or a hand edit); --self-test decodes small PNGs of
every transparency form. tools/check_fresh_server.py runs both.

  python3 tools/r44_mb/gen_baked_art.py [--art DIR] [--check | --self-test]

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
        # raw samples at full precision: the tRNS colour key (grey and RGB)
        # compares against them, before any scaling to 8 bits
        if depth == 8:
            samples = list(line)
        elif depth == 16:
            samples = [line[i] * 256 + line[i + 1] for i in range(0, len(line), 2)]
        else:
            samples, per = [], 8 // depth
            for byte in line:
                for k in range(per):
                    samples.append((byte >> (8 - depth * (k + 1))) & ((1 << depth) - 1))
        key = None
        if trns and ctype in (0, 2):
            key = tuple(trns[i] * 256 + trns[i + 1] for i in range(0, len(trns) - 1, 2))

        def to8(value):
            if depth == 16:
                return value >> 8
            return value * (255 // ((1 << depth) - 1)) if depth < 8 else value

        row = []
        for x in range(width):
            s = samples[x * channels:(x + 1) * channels]
            if ctype == 3:
                index = s[0]
                r, g, b = palette[index]
                a = trns[index] if trns and index < len(trns) else 255
            elif ctype == 0:
                r = g = b = to8(s[0])
                a = 0 if key == tuple(s) else 255
            elif ctype == 4:
                r = g = b = to8(s[0])
                a = to8(s[1])
            elif ctype == 2:
                r, g, b = (to8(v) for v in s)
                a = 0 if key == tuple(s) else 255
            else:
                r, g, b, a = (to8(v) for v in s)
            row.append((r, g, b, a) if a > 0 else (0, 0, 0, 0))
        rows.append(row)
    return width, height, rows


def encode_png(width, height, ctype, depth, rows, trns=None, palette=None):
    """A PNG of raw sample rows (lists of ints per pixel channel, filter 0):
    the self-test's input."""
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)

    raw = b""
    for row in rows:
        line = bytearray()
        if depth == 16:
            for value in row:
                line += struct.pack(">H", value)
        elif depth == 8:
            line += bytes(row)
        else:
            per, byte, count = 8 // depth, 0, 0
            for value in row:
                byte = (byte << depth) | value
                count += 1
                if count == per:
                    line.append(byte)
                    byte, count = 0, 0
            if count:
                line.append(byte << (depth * (per - count)))
        raw += b"\x00" + bytes(line)
    data = (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, ctype, 0, 0, 0)))
    if palette:
        data += chunk(b"PLTE", b"".join(bytes(c) for c in palette))
    if trns is not None:
        data += chunk(b"tRNS", trns)
    return data + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def self_test():
    """Decodes small PNGs of every transparency form; returns failures."""
    clear = (0, 0, 0, 0)
    cases = [
        ("RGB 8-bit colour key", encode_png(2, 1, 2, 8, [[10, 20, 30, 40, 50, 60]],
                                           trns=struct.pack(">HHH", 10, 20, 30)),
         [[clear, (40, 50, 60, 255)]]),
        ("RGB 16-bit colour key", encode_png(2, 1, 2, 16, [[0x0a01, 0x1402, 0x1e03, 0x0a01, 0x1402, 0x1e04]],
                                            trns=struct.pack(">HHH", 0x0a01, 0x1402, 0x1e03)),
         [[clear, (10, 20, 30, 255)]]),
        ("grey 8-bit colour key", encode_png(2, 1, 0, 8, [[7, 200]], trns=struct.pack(">H", 7)),
         [[clear, (200, 200, 200, 255)]]),
        ("grey 1-bit colour key", encode_png(3, 1, 0, 1, [[1, 0, 1]], trns=struct.pack(">H", 0)),
         [[(255, 255, 255, 255), clear, (255, 255, 255, 255)]]),
        ("grey 16-bit colour key", encode_png(2, 1, 0, 16, [[0x8001, 0x8000]], trns=struct.pack(">H", 0x8000)),
         [[(128, 128, 128, 255), clear]]),
        ("RGB without key", encode_png(1, 1, 2, 8, [[1, 2, 3]]), [[(1, 2, 3, 255)]]),
        ("palette 4-bit with alpha", encode_png(2, 1, 3, 4, [[0, 1]], trns=bytes([0]),
                                               palette=[(9, 9, 9), (200, 100, 50)]),
         [[clear, (200, 100, 50, 255)]]),
        ("grey+alpha 8-bit", encode_png(1, 1, 4, 8, [[90, 128]]), [[(90, 90, 90, 128)]]),
        ("RGBA 8-bit", encode_png(1, 1, 6, 8, [[1, 2, 3, 0]]), [[clear]]),
    ]
    failures = []
    for label, data, want in cases:
        got = decode_png(data)[2]
        if got != want:
            failures.append("%s: got %r, expected %r" % (label, got, want))
    return failures


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
    parser.add_argument("--self-test", action="store_true", help="test the PNG decoder only")
    args = parser.parse_args()
    if args.self_test:
        failures = self_test()
        for failure in failures:
            print("FAIL " + failure)
        print("decoder self-test: %s" % ("FAIL" if failures else "PASS"))
        return 1 if failures else 0
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
