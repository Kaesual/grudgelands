#!/usr/bin/env python3
"""Render a look-at sheet of the dual furnace's faces, for the user.

Top row: the vendored furnace front next to the re-skinned dual front, both
at 8x nearest-neighbour, so the two mouths are visible as pixels rather than
as a claim. Bottom row: the eight frames of the active strip.

    python3 tools/wp26/render_dual_furnace.py [OUT.png]
"""

import os
import sys

from PIL import Image, ImageDraw

DEFAULT_OUT = os.path.join("tools", "wp26", "evidence", "20260916",
                           "dual_furnace_faces.png")
SCALE = 8
PAD = 10
LABEL = 14
BG = (28, 28, 32)
FG = (226, 226, 230)


def load(path):
    return Image.open(path).convert("RGBA")


def scaled(image, box=None):
    if box:
        image = image.crop(box)
    return image.resize((image.width * SCALE, image.height * SCALE),
                        Image.NEAREST)


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    base = os.path.join("mods", "BASE", "default", "textures")
    mine = os.path.join("mods", "ITEMS", "grug_smelting", "textures")

    original = scaled(load(os.path.join(base, "default_furnace_front.png")))
    ported = scaled(load(os.path.join(
        mine, "grug_smelting_dual_furnace_front.png")))
    side = scaled(load(os.path.join(base, "default_furnace_side.png")))
    top = scaled(load(os.path.join(base, "default_furnace_top.png")))

    active = load(os.path.join(
        mine, "grug_smelting_dual_furnace_front_active.png"))
    frames = [scaled(active, (0, f * 16, 16, f * 16 + 16)) for f in range(8)]

    tile = original.width
    top_row = [("default:furnace", original), ("dual furnace", ported),
               ("side (shared)", side), ("top (shared)", top)]
    width = PAD + len(top_row) * (tile + PAD)
    frame_width = PAD + len(frames) * (tile + PAD)
    width = max(width, frame_width)
    height = PAD + LABEL + tile + PAD + LABEL + tile + PAD

    sheet = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(sheet)

    x, y = PAD, PAD
    for name, image in top_row:
        draw.text((x, y), name, fill=FG)
        sheet.paste(image, (x, y + LABEL))
        x += tile + PAD

    y = PAD + LABEL + tile + PAD
    draw.text((PAD, y), "dual furnace, active (8 animation frames, 1.5 s)",
              fill=FG)
    x = PAD
    for image in frames:
        sheet.paste(image, (x, y + LABEL))
        x += tile + PAD

    directory = os.path.dirname(out_path)
    if directory and not os.path.isdir(directory):
        os.makedirs(directory)
    sheet.save(out_path)
    print("%s written (%dx%d)" % (out_path, sheet.width, sheet.height))


if __name__ == "__main__":
    main()
