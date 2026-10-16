#!/usr/bin/env python3
"""0.49.1 lane ANIM: the furnace's fire and arrow as vertically stacked
frame strips for animated_image[] (fix-0.49.1-plan.md ruling 7, §4 ANIM).

Each frame is the picture the furnace forms drew before from the vendored
minetest_game textures with the engine's own modifiers, computed here the
way the engine computes them (imagesource.cpp: `[lowpart` blits rows
H * (100 - p) / 100 .. H - 1 of the overlay with blit_pixel's alpha rule,
`[transformR270` maps dst(x, y) to src(y, W - 1 - x)):

- fire  = default_furnace_fire_bg.png^[lowpart:p:default_furnace_fire_fg.png
- arrow = gui_furnace_arrow_bg.png^[lowpart:p:gui_furnace_arrow_fg.png^[transformR270

The fire's flame covers rows 1..15 of its 16 (row 0 is empty): FIRE_FILL
frames, one flame row less each, from the full flame (frame 0) to the
lowest flame (the bottom row only, frame FIRE_FILL - 1). The arrow's fill
covers rows 2..45 of its 49 (44 rows, about 2.2 px per frame): ARROW_FILL frames
from the empty arrow (frame 0) to one step short of full. Each strip then
holds as many buffer frames as fill frames, all showing its end picture
(the fire's lowest flame, never empty; the arrow full): the server only
notices an end at its next one-second tick, so the animation must hold its
end until the re-send (grug_inventory/furnace_progress.lua, which also
gives the buffer its minimum length). The engine draws frame i from rows
i * FRAME_H .. (i + 1) * FRAME_H - 1 (guiAnimatedImage.cpp).

The frames are derivatives of the minetest_game textures and keep their
licence, CC BY-SA 3.0 (fire: Neuromancer; arrow: BlockMen;
mods/PLAYER/grug_inventory/LICENSE-media.md).

Python 3 standard library only (zlib, struct): no installed tools needed.

Usage: python3 tools/r491_anim/gen_furnace_strips.py [--check]
  --check  compares the committed PNGs' pixels with the generated ones
           (decoded, so another zlib build cannot fail it) and exits 1 on a
           difference.
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "mods/BASE/default/textures"
TARGET = ROOT / "mods/PLAYER/grug_inventory/textures"

# grug_inventory/furnace_progress.lua FIRE / ARROW must match.
FIRE_FILL, FIRE_TOP, FIRE_BOTTOM = 15, 1, 15        # flame rows 1..15
# 20 fill frames keep the strip at 49 x 1960 px, under the 2048 px texture
# limit of some GPUs.
ARROW_FILL, ARROW_TOP, ARROW_BOTTOM = 20, 2, 45     # fill rows 2..45


def decode(path):
    """(width, height, rows of RGBA tuples) of a non-interlaced PNG:
    palette (1/2/4/8 bit, tRNS), RGB, grey and RGBA, 8 bit."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos, idat, palette, trns = 8, b"", b"", b""
    while pos < len(data):
        length, = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    if interlace:
        raise ValueError(f"{path}: interlaced PNG")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    if ctype != 3 and depth != 8:
        raise ValueError(f"{path}: unsupported bit depth {depth}")
    bpp = max(1, channels * depth // 8)
    stride = (width * channels * depth + 7) // 8
    raw = zlib.decompress(idat)
    lines, prev, at = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else
                                      b if pb <= pc else c)) & 255
        lines.append(line)
        prev = line
    rows = []
    for line in lines:
        row = []
        for x in range(width):
            if ctype == 3:
                bit = x * depth
                index = (line[bit // 8] >> (8 - depth - bit % 8)) & ((1 << depth) - 1)
                alpha = trns[index] if index < len(trns) else 255
                row.append((palette[3 * index], palette[3 * index + 1],
                            palette[3 * index + 2], alpha))
            elif ctype == 6:
                row.append(tuple(line[4 * x:4 * x + 4]))
            elif ctype == 2:
                row.append(tuple(line[3 * x:3 * x + 3]) + (255,))
            elif ctype == 4:
                row.append((line[2 * x],) * 3 + (line[2 * x + 1],))
            else:
                row.append((line[x],) * 3 + (255,))
        rows.append(row)
    return width, height, rows


def blit_pixel(src, dst):
    """The engine's blit_pixel (imagesource.cpp), non-overlay."""
    sa, da = src[3], dst[3]
    if sa == 0:
        return dst
    if sa == 255 or da == 0:
        return src
    rgb = tuple((dst[i] * (255 - sa) + src[i] * sa) // 255 for i in range(3))
    if da == 255:
        return rgb + (255,)
    return rgb + (da + (255 - da) * sa * sa // (255 * 255),)


def lowpart(base, over, first_row):
    """base^[lowpart: the overlay's rows first_row.. blitted onto base."""
    out = [list(row) for row in base]
    for y in range(first_row, len(over)):
        for x in range(len(over[y])):
            out[y][x] = blit_pixel(over[y][x], out[y][x])
    return out


def rotate270(rows):
    """[transformR270 (imageTransform: sx = dy, sy = (W - 1) - dx)."""
    width = len(rows)  # square images: dst width = src height
    return [[rows[width - 1 - dx][dy] for dx in range(width)]
            for dy in range(len(rows[0]))]


def fire_frames():
    _, _, bg = decode(SOURCE / "default_furnace_fire_bg.png")
    _, _, fg = decode(SOURCE / "default_furnace_fire_fg.png")
    flame = FIRE_BOTTOM - FIRE_TOP + 1
    frames = []
    for i in range(FIRE_FILL):
        # frame i: (FIRE_FILL - i) / FIRE_FILL of the flame left, at least one row
        rows = max(1, -(-flame * (FIRE_FILL - i) // FIRE_FILL))
        frames.append(lowpart(bg, fg, FIRE_BOTTOM + 1 - rows))
    return frames + [frames[-1]] * FIRE_FILL


def arrow_frames():
    _, _, bg = decode(SOURCE / "gui_furnace_arrow_bg.png")
    _, _, fg = decode(SOURCE / "gui_furnace_arrow_fg.png")
    fill = ARROW_BOTTOM - ARROW_TOP + 1
    frames = []
    for i in range(ARROW_FILL + 1):
        rows = fill * i // ARROW_FILL
        frames.append(rotate270(lowpart(bg, fg, ARROW_BOTTOM + 1 - rows) if rows else bg))
    return frames[:ARROW_FILL] + [frames[ARROW_FILL]] * ARROW_FILL


def strip(frames):
    return [row for frame in frames for row in frame]


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


OUTPUTS = {
    "grug_inventory_furnace_fire.png": fire_frames,
    "grug_inventory_furnace_arrow.png": arrow_frames,
}


def main():
    check = "--check" in sys.argv[1:]
    failed = False
    for name, build in OUTPUTS.items():
        frames = build()
        rows = strip(frames)
        out = TARGET / name
        size = f"{len(rows[0])}x{len(rows)}, {len(frames)} frames"
        if check:
            try:
                width, height, decoded = decode(out)
            except (OSError, ValueError, zlib.error) as error:
                print(f"FAIL {out}: {error}")
                failed = True
                continue
            if (width, height) != (len(rows[0]), len(rows)) or decoded != rows:
                print(f"FAIL {out} differs from the generator; rerun without --check")
                failed = True
                continue
            print(f"OK {name} {size}")
        else:
            out.write_bytes(png(rows))
            print(f"wrote {out} {size}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
