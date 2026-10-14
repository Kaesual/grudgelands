#!/usr/bin/env python3
"""Placeholder art for the mailbox window (Round 48 lane MAIL).

Writes the two window badges under their final names until lane ARTM
replaces them with the user's picks (round plan §3.7):

  mods/PLAYER/grug_mail/textures/grug_mail_admin_badge.png  gold shield
  mods/PLAYER/grug_mail/textures/grug_mail_npc_seal.png     red wax seal

Both are 32 x 32 RGBA, drawn from simple shapes (own work, CC0).
  python3 tools/r48_mail/gen_placeholders.py [--check]
--check exits 1 when a file differs from what this script writes.
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_mail/textures"
SIZE = 32


def png(pixels):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def shield_inside(x, y):
    """The shield outline of the wireframes: flat top, straight sides, a
    rounded point at the bottom (pixel centres, 32 x 32)."""
    cx = 15.5
    if y < 3 or y > 29:
        return False
    if y < 17:
        return abs(x - cx) <= 12
    half = 12 * (29 - y) / 12
    return abs(x - cx) <= half


def admin_badge():
    gold, fill, clear = (216, 176, 74, 255), (58, 48, 24, 255), (0, 0, 0, 0)
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            if not shield_inside(x, y):
                row.append(clear)
            elif not (shield_inside(x - 2, y) and shield_inside(x + 2, y) and
                      shield_inside(x, y - 2) and shield_inside(x, y + 2)):
                row.append(gold)
            else:
                row.append(fill)
        rows.append(row)
    # A check mark inside, as in the wireframe's banner.
    for x, y in ((10, 16), (11, 17), (12, 18), (13, 19), (14, 18), (15, 17), (16, 16),
                 (17, 15), (18, 14), (19, 13), (20, 12), (21, 11)):
        for dy in (0, 1):
            rows[y + dy][x] = gold
    return rows


def npc_seal():
    rim, wax, mark, clear = (208, 122, 98, 255), (143, 59, 43, 255), (208, 122, 98, 255), (0, 0, 0, 0)
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            d = ((x - 15.5) ** 2 + (y - 15.5) ** 2) ** 0.5
            if d > 14:
                row.append(clear)
            elif d > 12:
                row.append(rim)
            elif 5 < d < 6.5:
                row.append(mark)
            else:
                row.append(wax)
        rows.append(row)
    return rows


FILES = {
    "grug_mail_admin_badge.png": admin_badge,
    "grug_mail_npc_seal.png": npc_seal,
}


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for name, draw in FILES.items():
        data = png(draw())
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            print("wrote", path.relative_to(ROOT))
    if stale:
        print("stale:", ", ".join(stale))
        return 1
    if check:
        print("placeholders current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
