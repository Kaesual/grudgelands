#!/usr/bin/env python3
"""The placeholder music-note icon of the "Now playing" box (0.45.1 lane MU).

A PLACEHOLDER until the user picks the art (fix plan row 11): a plain eighth
note in the location line's cream (#f0e6c8) with a dark outline, 32x32 RGBA,
drawn from three shapes (a tilted oval head, a stem, a flag) with 4x4
supersampling. The pick replaces the file and keeps its name.

    python3 tools/r451_mu/gen_note_placeholder.py [--check]

Writes mods/CORE/grug_ambience/textures/grug_ambience_note.png; --check exits
1 when the shipped file differs from what this script draws. Standard library
only.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

SIZE, SS = 32, 4
FILL = (0xF0, 0xE6, 0xC8)
OUTLINE = (0x1A, 0x16, 0x10)
OUT = Path(__file__).resolve().parents[2] / "mods/CORE/grug_ambience/textures/grug_ambience_note.png"


def inside(x, y):
    """Whether the point (x, y) in pixel units lies in the note."""
    # The head: an oval tilted by -20 degrees, centred low left.
    cx, cy, a, b, t = 11.5, 23.5, 6.2, 4.4, math.radians(-20)
    dx, dy = x - cx, y - cy
    u = dx * math.cos(t) + dy * math.sin(t)
    v = -dx * math.sin(t) + dy * math.cos(t)
    if (u / a) ** 2 + (v / b) ** 2 <= 1:
        return True
    # The stem: up from the head's right side.
    if 15.6 <= x <= 18.0 and 4.0 <= y <= 22.5:
        return True
    # The flag: a band curving down and right from the stem's top.
    if 17.0 <= x <= 26.0 and 4.0 <= y <= 19.0:
        s = (x - 17.0) / 9.0
        top = 4.0 + 9.0 * s * s + 4.0 * s
        return top <= y <= top + 4.2 - 1.6 * s
    return False


def coverage():
    grid = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            hits = 0
            for sy in range(SS):
                for sx in range(SS):
                    if inside(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS):
                        hits += 1
            row.append(hits / (SS * SS))
        grid.append(row)
    return grid


def render():
    fill = coverage()
    pixels = bytearray()
    for y in range(SIZE):
        pixels.append(0)
        for x in range(SIZE):
            # The outline: the strongest fill within one pixel around.
            near = 0.0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if 0 <= x + dx < SIZE and 0 <= y + dy < SIZE:
                        near = max(near, fill[y + dy][x + dx])
            f = fill[y][x]
            alpha = max(f, near)
            if alpha <= 0:
                pixels += bytes(4)
                continue
            mix = f / alpha
            rgb = [round(OUTLINE[i] + (FILL[i] - OUTLINE[i]) * mix) for i in range(3)]
            pixels += bytes(rgb + [round(alpha * 255)])
    return pixels


def png(raw):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    data = png(render())
    if "--check" in sys.argv:
        ok = OUT.exists() and OUT.read_bytes() == data
        print("note placeholder " + ("OK" if ok else "DIFFERS"))
        return 0 if ok else 1
    OUT.write_bytes(data)
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
