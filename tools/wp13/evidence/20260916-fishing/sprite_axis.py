#!/usr/bin/env python3
"""Measure every held sprite against its own long axis (WP13 wave 3).

The wield convention (`mods/PLAYER/grug_visuals/wield_geometry.lua`) puts a
held item's long axis on the image's ANTI-DIAGONAL through the grip pixel
(3.4, 12.6), and section 7's roll about that axis maps the image's up-left side
to model UP.  Two numbers follow from that and nothing else in the repository
measures them:

  * GRIP -- is the fist's pixel opaque?  A sprite that is not drawn in the
    convention has nothing under the hand, which is the "the rod sits in the
    middle of the hand" defect of playtest round 5.
  * MIRROR -- how much of the silhouette survives being mirrored about that
    axis.  Mirroring about the long axis IS the 180-degree roll section 10
    adds, so 100 % means the roll cannot be seen on this sprite and a low
    number means it decides which way the head points.

Run from the repository root:

    python3 tools/wp13/evidence/20260916-fishing/sprite_axis.py
"""

import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))

GRIP_U, GRIP_V = 3.4, 12.6
ROOT_HALF = 0.5 ** 0.5
ALPHA = 32

DEFAULT_TEX = os.path.join(REPO, "mods", "BASE", "default", "textures")
GEAR_TEX = os.path.join(REPO, "mods", "ITEMS", "grug_gear", "textures")
FISHING_TEX = os.path.join(REPO, "mods", "ITEMS", "grug_fishing", "textures")
MATERIALS_TEX = os.path.join(REPO, "mods", "ITEMS", "grug_materials",
                             "textures")

MATERIALS = ("bronze", "iron", "steel", "silversteel", "embersteel",
             "abyssal_steel")

# The four tiers `grug_materials/tools.lua` adds on top of `default`'s ladder.
# They are the THIRD axe family and they carry `axe = 1`, so they take the
# rolled pose too -- which is exactly why they have to be measured here and not
# assumed to match `default`'s by shared ancestry.
DEEP_TIERS = ("iron", "silversteel", "embersteel", "abyssal_steel")


def held_sprites():
    """Every sprite a character can be shown holding, with its wield pose."""
    rows = []
    for metal in ("wood", "stone", "bronze", "steel", "mese", "diamond"):
        rows.append(("default:sword_" + metal, "tool",
                     os.path.join(DEFAULT_TEX,
                                  "default_tool_%ssword.png" % metal)))
        rows.append(("default:pick_" + metal, "tool",
                     os.path.join(DEFAULT_TEX,
                                  "default_tool_%spick.png" % metal)))
        rows.append(("default:shovel_" + metal, "tool",
                     os.path.join(DEFAULT_TEX,
                                  "default_tool_%sshovel.png" % metal)))
        rows.append(("default:axe_" + metal, "EDGE_DOWN",
                     os.path.join(DEFAULT_TEX,
                                  "default_tool_%saxe.png" % metal)))
    for tier in DEEP_TIERS:
        rows.append(("grug_materials:pick_" + tier, "tool",
                     os.path.join(MATERIALS_TEX,
                                  "grug_materials_tool_%spick.png" % tier)))
        rows.append(("grug_materials:shovel_" + tier, "tool",
                     os.path.join(MATERIALS_TEX,
                                  "grug_materials_tool_%sshovel.png" % tier)))
        rows.append(("grug_materials:axe_" + tier, "EDGE_DOWN",
                     os.path.join(MATERIALS_TEX,
                                  "grug_materials_tool_%saxe.png" % tier)))
    for family, pose in (("sword", "tool"), ("dagger", "tool"),
                         ("staff", "tool"), ("greataxe", "EDGE_DOWN")):
        for metal in MATERIALS:
            rows.append(("grug_gear:%s_%s" % (family, metal), pose,
                         os.path.join(GEAR_TEX,
                                      "grug_gear_item_%s_%s.png"
                                      % (family, metal))))
    rows.append(("grug_gear:staff_wood", "tool",
                 os.path.join(GEAR_TEX, "grug_gear_item_staff_wood.png")))
    rows.append(("grug_fishing:rod", "tool",
                 os.path.join(FISHING_TEX, "grug_fishing_rod.png")))
    # Not a diagonal sprite and not claimed to be: the stick is what an angler
    # used to hold, and it is here as the contrast case.
    rows.append(("default:stick (upright pose)", "upright",
                 os.path.join(DEFAULT_TEX, "default_stick.png")))
    return rows


def measure(path):
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    size, height = image.size
    if size != height:
        raise SystemExit("%s is not square" % path)
    on = set()
    offset_sum = 0.0
    for y in range(size):
        for x in range(size):
            if pixels[x, y][3] < ALPHA:
                continue
            on.add((x, y))
            du, dv = (x + 0.5) - GRIP_U, (y + 0.5) - GRIP_V
            offset_sum += (-du - dv) * ROOT_HALF
    mirrored = set((size - 1 - y, size - 1 - x) for (x, y) in on)
    overlap = 100.0 * len(on & mirrored) / len(on | mirrored)
    grip = pixels[int(GRIP_U), int(GRIP_V)][3] >= ALPHA
    return {
        "opaque": len(on),
        "centroid": offset_sum / len(on),
        "overlap": overlap,
        "moved": len(on - mirrored),
        "grip": grip,
    }


def main():
    print("%-34s %-9s %6s %8s %8s %6s %s"
          % ("item", "pose", "opaque", "centroid", "mirror%", "moved", "grip"))
    complaints = 0
    total_rows = 0
    invariant = 0
    for name, pose, path in held_sprites():
        if not os.path.exists(path):
            print("%-34s %-9s MISSING %s" % (name, pose, path))
            complaints += 1
            continue
        row = measure(path)
        total_rows += 1
        if row["moved"] == 0:
            invariant += 1
        print("%-34s %-9s %6d %+8.2f %8.1f %6d %s"
              % (name, pose, row["opaque"], row["centroid"], row["overlap"],
                 row["moved"], "yes" if row["grip"] else "NO"))
        if pose != "upright" and not row["grip"]:
            print("    ^ no opaque pixel under the fist -- not in the "
                  "diagonal convention")
            complaints += 1
        # The rule the wield pose encodes: a sprite the roll cannot move is a
        # `tool` and the choice is free; one it CAN move has a side, so say
        # which way that side ends up in the world.  Only the axe families are
        # rolled, because only an axe's off-axis half is a cutting edge that
        # has to lead the swing -- a staff's knob and a rod's line do not.
        if pose == "tool" and row["moved"] > 0:
            print("    - off-axis by %d pixels; in the tool pose its mass "
                  "rides %s (deliberate: %s)"
                  % (row["moved"], "up" if row["centroid"] > 0 else "down",
                     "a knob, not an edge" if row["centroid"] > 0
                     else "the line has to hang down"))
        if pose == "EDGE_DOWN" and row["overlap"] > 99.9:
            print("    ^ symmetric about its long axis, so the rolled pose "
                  "buys nothing")
            complaints += 1
    # COUNTED, never hand-counted: the review of 2026-09-16 found the note
    # quoting "26 sprites" for what was then 31 rows.
    print("rows: %d   invariant under the roll (100.0%%): %d   moved by it: %d"
          % (total_rows, invariant, total_rows - invariant))
    print("complaints: %d" % complaints)
    return 1 if complaints else 0


if __name__ == "__main__":
    sys.exit(main())
