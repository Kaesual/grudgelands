#!/usr/bin/env python3
"""Round 40 lane CD: the cooldown overlay's textures (plan §2.1, §2.13).

Writes into mods/PLAYER/grug_abilities/textures/:
  grug_abilities_cd_pie_00.png .. _71.png  72 cover frames, 96 x 96 px, two
      colours (50 % black, clear). Frame k covers what is still to run after
      k/72 of the cooldown: the cover clears clockwise from twelve o'clock
      like a clock hand, one frame per 5 degrees (ruling §2.1). It covers the
      whole square (pick P1).
  grug_abilities_cd_digit_0.png .. _9.png, grug_abilities_cd_digit_m.png
      the image digits (pick N3): the 5 x 7 glyphs of the accepted preview
      page, white with a black outline one glyph cell wide, CELL px per cell,
      so a glyph is 7 x 9 cells (28 x 36 px). The overlay places them
      ADVANCE cells apart and scales a cell to a whole number of screen
      pixels (grug_abilities/cooldown_math.lua; its GLYPH_* constants match
      the ones here).

Python 3 standard library only; the output is byte-for-byte deterministic.
To change the look, edit FONT, CELL, COVER or PIE and rerun; the fixture
tools/r40_cd/portable_test.lua checks the sizes against cooldown_math.lua.

  python3 tools/r40_cd/gen_cooldown_textures.py          write the files
  python3 tools/r40_cd/gen_cooldown_textures.py --check  exit 1 if any differs
"""
import math
import struct
import sys
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "mods/PLAYER/grug_abilities/textures"
PREFIX = "grug_abilities_cd_"
FRAMES = 72
PIE = 96
CELL = 4
OUTLINE = 1  # in glyph cells
COVER = (0, 0, 0, 128)
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

# The glyphs of the Round 40 V1 preview page, on which the user picked N3.
FONT = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "m": ["00000", "00000", "11010", "10101", "10101", "10101", "10101"],
}


def png(width, height, pixels):
    """pixels: rows of RGBA tuples. Filter 0 per row, fixed zlib level."""
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def pie(frame):
    cleared = 2 * math.pi * frame / FRAMES
    c = PIE / 2
    rows = []
    for y in range(PIE):
        row = []
        for x in range(PIE):
            # Clockwise from twelve o'clock, screen y pointing down.
            a = math.atan2(x + 0.5 - c, c - (y + 0.5)) % (2 * math.pi)
            row.append(COVER if a >= cleared else CLEAR)
        rows.append(row)
    return png(PIE, PIE, rows)


def glyph(rows):
    gw, gh = len(rows[0]) + 2 * OUTLINE, len(rows) + 2 * OUTLINE
    on = [[False] * gw for _ in range(gh)]
    for gy, line in enumerate(rows):
        for gx, ch in enumerate(line):
            on[OUTLINE + gy][OUTLINE + gx] = ch == "1"
    cells = []
    for y in range(gh):
        row = []
        for x in range(gw):
            if on[y][x]:
                row.append(WHITE)
                continue
            near = any(on[yy][xx]
                       for yy in range(max(0, y - OUTLINE), min(gh, y + OUTLINE + 1))
                       for xx in range(max(0, x - OUTLINE), min(gw, x + OUTLINE + 1)))
            row.append(BLACK if near else CLEAR)
        cells.append(row)
    pixels = []
    for row in cells:
        line = [px for px in row for _ in range(CELL)]
        pixels.extend([line] * CELL)
    return png(gw * CELL, gh * CELL, pixels)


def files():
    out = {}
    for k in range(FRAMES):
        out["%spie_%02d.png" % (PREFIX, k)] = pie(k)
    for ch, rows in FONT.items():
        out["%sdigit_%s.png" % (PREFIX, ch)] = glyph(rows)
    return out


def main():
    check = "--check" in sys.argv[1:]
    bad = 0
    produced = files()
    for name, data in sorted(produced.items()):
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != data:
                print("differs: %s" % path)
                bad += 1
        else:
            path.write_bytes(data)
    # No stale file of an older set (a removed glyph, a smaller FRAMES).
    for path in sorted(OUT.glob(PREFIX + "*.png")):
        if path.name not in produced:
            if check:
                print("not generated: %s" % path)
                bad += 1
            else:
                path.unlink()
    if check:
        print("gen_cooldown_textures --check: %s" % ("FAIL" if bad else "PASS"))
        return 1 if bad else 0
    print("wrote %d files to %s" % (len(produced), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
