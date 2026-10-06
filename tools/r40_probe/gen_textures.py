#!/usr/bin/env python3
"""Round 40 lane V4: the probe's own cooldown overlay textures (plan §3.1).

Writes into tools/r40_probe/textures/:
  grug_r40_probe_pie_00.png .. _71.png  72 pie frames, 96 x 96 px, two
      colours (50 % black, clear). Frame k covers what is still to run after
      k/72 of the cooldown: the cover clears clockwise from twelve o'clock
      like a clock hand (ruling §2.1, 5 degree steps).
  grug_r40_probe_digit_0.png .. _9.png, grug_r40_probe_digit_m.png
      image digits, 24 x 32 px: a 5 x 7 pixel font scaled 4x, white with a
      2 px black outline, so the number scales with the icon.

Python 3 standard library only; the output is byte-for-byte deterministic.
Lane CD writes the real generator later; this one only serves the probe.

  python3 tools/r40_probe/gen_textures.py          write the files
  python3 tools/r40_probe/gen_textures.py --check  exit 1 if any differs
"""
import math
import struct
import sys
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent / "textures"
FRAMES = 72
PIE = 96
SCALE = 4
OUTLINE = 2
COVER = (0, 0, 0, 128)
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

FONT = {
    "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"],
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
    w = len(rows[0]) * SCALE + 2 * OUTLINE
    h = len(rows) * SCALE + 2 * OUTLINE
    fill = [[False] * w for _ in range(h)]
    for gy, line in enumerate(rows):
        for gx, ch in enumerate(line):
            if ch == "#":
                for dy in range(SCALE):
                    for dx in range(SCALE):
                        fill[OUTLINE + gy * SCALE + dy][OUTLINE + gx * SCALE + dx] = True
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            if fill[y][x]:
                row.append(WHITE)
                continue
            near = any(fill[yy][xx]
                       for yy in range(max(0, y - OUTLINE), min(h, y + OUTLINE + 1))
                       for xx in range(max(0, x - OUTLINE), min(w, x + OUTLINE + 1)))
            row.append(BLACK if near else CLEAR)
        out.append(row)
    return png(w, h, out)


def files():
    out = {}
    for k in range(FRAMES):
        out["grug_r40_probe_pie_%02d.png" % k] = pie(k)
    for ch, rows in FONT.items():
        out["grug_r40_probe_digit_%s.png" % ch] = glyph(rows)
    return out


def main():
    check = "--check" in sys.argv[1:]
    bad = 0
    for name, data in sorted(files().items()):
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != data:
                print("differs: %s" % path)
                bad += 1
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    if check:
        print("gen_textures --check: %s" % ("FAIL" if bad else "PASS"))
        return 1 if bad else 0
    print("wrote %d files to %s" % (len(files()), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
