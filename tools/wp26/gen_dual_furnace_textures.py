#!/usr/bin/env python3
"""Generate the dual furnace's two front textures (WP26, task card T1).

The port takes LotT's *code* only: `lottblocks` media is CC BY-SA 3.0 and the
card forbids copying it (`docs/research/wp26-task-card.md` §2). So the front
faces are re-skinned here from the vendored minetest_game furnace fronts,
exactly the way `tools/wp13/gen_weapon_ladder.py` re-skins the vendored tool
sprites: the result is a derivative of CC BY-SA 3.0 art and stays under that
licence (`mods/ITEMS/grug_smelting/LICENSE-media.md`).

The re-skin is one geometric edit and no new colour: a two-pixel stone pillar
is set into the upper mouth of the furnace front, splitting the one arch into
the two the node's two material slots stand for. The pillar's two columns are
copied from the SAME row's own inner arch edges (x = 12 and x = 3), so the new
openings get the original artwork's edge shading rather than an invented ramp.
The lower fire chamber -- the animated part of the active strip -- is not
touched, so the eight frames keep their fire animation unchanged.

Run from the repository root:

    python3 tools/wp26/gen_dual_furnace_textures.py

Exits non-zero when a source texture is missing or when an already generated
file would change (`--check`); without `--check` it writes the files.
"""

import argparse
import os
import sys

from PIL import Image

SOURCE_DIR = os.path.join("mods", "BASE", "default", "textures")
TARGET_DIR = os.path.join("mods", "ITEMS", "grug_smelting", "textures")

# The mouth of the vendored 16x16 furnace front. Rows 3..6 are the arch; row 7
# is its bottom lip and rows 9..12 are the fire chamber, both left alone.
ARCH_ROWS = (3, 4, 5, 6)
# The pillar columns, and the column each one copies its colour from.
PILLAR = ((7, 12), (8, 3))

JOBS = (
    ("default_furnace_front.png", "grug_smelting_dual_furnace_front.png"),
    ("default_furnace_front_active.png",
     "grug_smelting_dual_furnace_front_active.png"),
)


def split_arch(image):
    """Return a copy of `image` with a stone pillar in every 16x16 frame."""
    out = image.convert("RGBA").copy()
    px = out.load()
    width, height = out.size
    if width != 16 or height % 16 != 0:
        raise SystemExit("unexpected source size %dx%d" % (width, height))
    for frame in range(height // 16):
        top = frame * 16
        for row in ARCH_ROWS:
            y = top + row
            # Read both sources BEFORE writing: the pillar columns are inside
            # the arch and the sources are outside it, but reading first keeps
            # the transform independent of column order.
            colours = [px[source, y] for _, source in PILLAR]
            for (column, _), colour in zip(PILLAR, colours):
                px[column, y] = colour
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="fail instead of writing when a file would change")
    args = parser.parse_args()

    if not os.path.isdir(TARGET_DIR):
        os.makedirs(TARGET_DIR)

    drift = 0
    for source_name, target_name in JOBS:
        source_path = os.path.join(SOURCE_DIR, source_name)
        target_path = os.path.join(TARGET_DIR, target_name)
        if not os.path.exists(source_path):
            raise SystemExit("missing source texture: " + source_path)
        generated = split_arch(Image.open(source_path))
        if os.path.exists(target_path):
            existing = Image.open(target_path).convert("RGBA")
            same = (existing.size == generated.size and
                    existing.tobytes() == generated.tobytes())
            if same:
                print("%s unchanged (%dx%d)" %
                      (target_name, generated.size[0], generated.size[1]))
                continue
            if args.check:
                print("DRIFT: %s differs from its generator" % target_name)
                drift += 1
                continue
        generated.save(target_path)
        print("%s written (%dx%d)" %
              (target_name, generated.size[0], generated.size[1]))

    # The self-check the card's gate 7 rests on: the openings really are two,
    # and the fire chamber really is untouched.
    front = Image.open(os.path.join(SOURCE_DIR,
                                    "default_furnace_front.png")).convert("RGBA")
    made = split_arch(front)
    before, after = front.load(), made.load()
    for row in ARCH_ROWS:
        runs_before = count_runs(before, row)
        runs_after = count_runs(after, row)
        print("row %d: %d dark run(s) -> %d" % (row, runs_before, runs_after))
        if runs_before != 1 or runs_after != 2:
            print("SELF-CHECK FAIL: row %d is not one arch split into two" % row)
            drift += 1
    for row in range(8, 16):
        for x in range(16):
            if before[x, row] != after[x, row]:
                print("SELF-CHECK FAIL: the fire chamber changed at %d,%d" %
                      (x, row))
                drift += 1
    if drift:
        sys.exit(1)
    print("dual furnace textures OK")


def count_runs(px, row):
    """Number of maximal dark runs in one pixel row (a dark run is an opening)."""
    runs, inside = 0, False
    for x in range(16):
        r, g, b, _ = px[x, row]
        dark = r + g + b < 40
        if dark and not inside:
            runs += 1
        inside = dark
    return runs


if __name__ == "__main__":
    main()
