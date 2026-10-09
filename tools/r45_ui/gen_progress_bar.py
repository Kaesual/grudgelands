#!/usr/bin/env python3
"""Round 45 lane UI: the crafting job's progress bar, one vertically stacked
texture for animated_image[] (round45-plan.md §3, ui-crafting-rework-plan.md
§4.5). Generated, not drawn art; original, CC0-1.0 like the other generated
grug textures (mods/PLAYER/grug_jobs/LICENSE-media.md).

FILL frames show the bar filling one inner pixel per frame (frame 0 empty,
frame FILL - 1 one pixel short), then FILL / 2 identical full frames: the
lag buffer, so a late end resend still shows a full bar instead of
restarting (the animation lasts 1.5 x the job time and is full at 2/3 of
it). The engine draws frame i from rows i * FRAME_H .. (i + 1) * FRAME_H - 1
(guiAnimatedImage.cpp).

Python 3 standard library only (zlib, struct): no installed tools needed.

Usage: python3 tools/r45_ui/gen_progress_bar.py [--check]
  --check  compares the committed PNG's pixels with the generated ones
           (decoded, so another zlib build cannot fail it) and exits 1 on a
           difference.
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_jobs/textures/grug_jobs_progress_bar.png"

FILL = 64                 # fill frames; grug_jobs/ui.lua BAR_FILL_FRAMES
FRAMES = FILL + FILL // 2  # 96; grug_jobs/ui.lua BAR_FRAMES
INNER_W, INNER_H = FILL, 5  # one inner column per fill frame
FRAME_W, FRAME_H = INNER_W + 2, INNER_H + 2

BORDER = (20, 20, 20, 255)
EMPTY = (58, 58, 58, 255)
EMPTY_SHADE = (48, 48, 48, 255)     # the empty bar's lower row
FILL_TOP = (126, 214, 120, 255)     # light top row of the filled part
FILL_MID = (76, 175, 80, 255)
FILL_LOW = (52, 135, 58, 255)       # dark bottom row


def frame_rows(filled):
    """The FRAME_H rows of one frame with `filled` inner columns filled."""
    rows = []
    for y in range(FRAME_H):
        row = []
        for x in range(FRAME_W):
            if y in (0, FRAME_H - 1) or x in (0, FRAME_W - 1):
                row.append(BORDER)
                continue
            inner_y = y - 1
            if x - 1 < filled:
                row.append(FILL_TOP if inner_y == 0 else
                           FILL_LOW if inner_y == INNER_H - 1 else FILL_MID)
            else:
                row.append(EMPTY_SHADE if inner_y == INNER_H - 1 else EMPTY)
        rows.append(row)
    return rows


def image_rows():
    rows = []
    for frame in range(FRAMES):
        rows.extend(frame_rows(min(frame, FILL)))
    return rows


def raw_bytes(rows):
    """Filter type 0 per scanline, RGBA 8 bit."""
    out = bytearray()
    for row in rows:
        out.append(0)
        for pixel in row:
            out.extend(pixel)
    return bytes(out)


def png(rows):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + \
            struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    width, height = len(rows[0]), len(rows)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(raw_bytes(rows), 9)) +
            chunk(b"IEND", b""))


def decoded(path):
    """(width, height, filter-0 scanline bytes) of a PNG this script wrote."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, width, height, idat = 8, None, None, b""
    while pos < len(data):
        length, = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height = struct.unpack(">II", body[:8])
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    return width, height, zlib.decompress(idat)


def main():
    rows = image_rows()
    if "--check" in sys.argv[1:]:
        try:
            width, height, raw = decoded(OUT)
        except (OSError, ValueError, zlib.error) as error:
            print(f"FAIL {OUT}: {error}")
            return 1
        if (width, height) != (FRAME_W, FRAME_H * FRAMES) or raw != raw_bytes(rows):
            print(f"FAIL {OUT} differs from the generator; rerun without --check")
            return 1
        print(f"OK {OUT.name} {width}x{height}, {FRAMES} frames")
        return 0
    OUT.write_bytes(png(rows))
    print(f"wrote {OUT} {FRAME_W}x{FRAME_H * FRAMES}, {FRAMES} frames")
    return 0


if __name__ == "__main__":
    sys.exit(main())
