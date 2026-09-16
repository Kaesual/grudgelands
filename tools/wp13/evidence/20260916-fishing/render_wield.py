#!/usr/bin/env python3
"""Draw a held sprite where the engine actually puts it (WP13 wave 3).

This lane cannot open a client, and "the axe blades point the wrong way" is a
picture.  So: the wield attachment is read out of the REAL
`mods/PLAYER/grug_visuals/wield_geometry.lua` (through luajit, so no number is
transcribed), every pixel of the sprite is mapped through the same
bone/attachment maths `tools/wp13/wield_transform_kat.lua` checks, and the
result is drawn ORTHOGRAPHICALLY from the character's left -- which is exact
rather than approximate, because the sprite's plane IS the model y-z plane the
arm swings in.

The body behind it is a schematic drawn from `character.b3d`'s own model
numbers (shoulder joint at y 11.55, arm reaching 5.25 units past it, head and
torso spans); the WEAPON is not schematic at all.

Each row is one pose, each column one point of the chop: the arm hanging, and
then raised 45, 90 and 114 degrees -- the last being the peak of the mesh's
`mine` frames, measured in the fixture.

Run from the repository root:

    python3 tools/wp13/evidence/20260916-fishing/render_wield.py <outdir>
"""

import json
import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))

# Read the shipped transform rather than a copy of it.
LUA_DUMP = r'''
local repo = "%s"
rawset(_G, "grug_visuals", {})
dofile(repo .. "/mods/PLAYER/grug_visuals/wield_geometry.lua")
local g = rawget(_G, "grug_visuals")
local out = {}
for _, pose in ipairs({"tool", "edge_down", "upright"}) do
	local w = g.wield_transform(1, g.POSE[pose])
	out[#out + 1] = string.format(
		'"%%s": {"pos": [%%.6f, %%.6f, %%.6f], "rot": [%%.6f, %%.6f, %%.6f], "size": %%.6f, "hand": %%.6f}',
		pose, w.pos.x, w.pos.y, w.pos.z, w.rot.x, w.rot.y, w.rot.z,
		w.size.x, w.hand.y)
end
io.write("{" .. table.concat(out, ", ") .. "}")
'''

# character.b3d, the same readings wield_geometry.lua's sections 2 and 4 quote.
SHOULDER = (3.15, 11.55, 0.0)
ARM_REACH = 5.25
BODY_TOP = 12.6
BODY_BOTTOM = 6.3
HEAD_TOP = 16.8

MINE_PEAK = 114.1
RAISES = [(0, "arm hanging"), (45, "raised 45"), (90, "raised 90"),
          (MINE_PEAK, "mine peak %.0f" % MINE_PEAK)]

SCALE = 22          # screen pixels per model unit
PAD = 14
INK = (26, 28, 32, 255)
BODY = (198, 202, 210, 255)
HAND = (214, 92, 60, 255)


def rot_x(deg):
    a = math.radians(deg)
    return ((1, 0, 0), (0, math.cos(a), -math.sin(a)),
            (0, math.sin(a), math.cos(a)))


def rot_y(deg):
    a = math.radians(deg)
    return ((math.cos(a), 0, math.sin(a)), (0, 1, 0),
            (-math.sin(a), 0, math.cos(a)))


def rot_z(deg):
    a = math.radians(deg)
    return ((math.cos(a), -math.sin(a), 0), (math.sin(a), math.cos(a), 0),
            (0, 0, 1))


def mul(a, b):
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3))
                       for c in range(3)) for r in range(3))


def apply(m, v):
    return tuple(sum(m[r][c] * v[c] for c in range(3)) for r in range(3))


# The bone's rest frame: Ry(180) * Rx(180) = diag(-1, -1, 1).
ARM_REST = ((-1, 0, 0), (0, -1, 0), (0, 0, 1))


def transform(repo):
    text = subprocess.check_output(
        ["luajit", "-e", LUA_DUMP % repo], env=dict(os.environ, LC_ALL="C"))
    return json.loads(text.decode("ascii"))


def sprite_world(path, wield, raise_deg):
    """Every opaque sprite pixel as a (y, z, colour) in model coordinates."""
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    size = image.size[0]
    edge = 40 * wield["size"] / 2
    attach = mul(mul(rot_z(wield["rot"][2]), rot_y(wield["rot"][1])),
                 rot_x(wield["rot"][0]))
    frame = ARM_REST if raise_deg == 0 else mul(ARM_REST, rot_x(raise_deg))
    out = []
    for v in range(size):
        for u in range(size):
            colour = pixels[u, v]
            if colour[3] < 32:
                continue
            for du, dv in ((0.0, 0.0), (0.5, 0.0), (0.0, 0.5), (0.5, 0.5)):
                local = (((u + du) / size - 0.5) * edge,
                         (0.5 - (v + dv) / size) * edge, 0.0)
                turned = apply(attach, local)
                bone = (wield["pos"][0] + turned[0],
                        wield["pos"][1] + turned[1],
                        wield["pos"][2] + turned[2])
                model = apply(frame, bone)
                out.append((SHOULDER[1] + model[1], SHOULDER[2] + model[2],
                            colour))
    return out


def hand_world(wield, raise_deg):
    frame = ARM_REST if raise_deg == 0 else mul(ARM_REST, rot_x(raise_deg))
    model = apply(frame, (0.0, wield["hand"], 0.0))
    return SHOULDER[1] + model[1], SHOULDER[2] + model[2]


def arm_tip_world(raise_deg):
    frame = ARM_REST if raise_deg == 0 else mul(ARM_REST, rot_x(raise_deg))
    model = apply(frame, (0.0, ARM_REACH, 0.0))
    return SHOULDER[1] + model[1], SHOULDER[2] + model[2]


def draw_cell(sprite_path, wield, raise_deg, box):
    """One panel: the schematic body, the arm, and the exact sprite."""
    width, height = box
    cell = Image.new("RGBA", (width, height), (250, 250, 248, 255))
    pen = ImageDraw.Draw(cell)

    # Model (y, z) -> pixel. z (forward) runs right, y (up) runs up.
    z_lo, z_hi = -6.0, 13.0
    y_lo, y_hi = -1.0, 18.0

    def pt(y, z):
        x = PAD + (z - z_lo) / (z_hi - z_lo) * (width - 2 * PAD)
        yy = height - PAD - (y - y_lo) / (y_hi - y_lo) * (height - 2 * PAD)
        return x, yy

    # ground line
    pen.line([pt(0, z_lo), pt(0, z_hi)], fill=(214, 216, 220, 255), width=1)

    # schematic torso + head, seen from the side
    pen.rectangle([pt(BODY_TOP, -1.2), pt(BODY_BOTTOM, 1.2)], fill=BODY)
    pen.rectangle([pt(HEAD_TOP, -1.6), pt(BODY_TOP, 1.6)], fill=BODY)
    pen.rectangle([pt(BODY_BOTTOM, -1.0), pt(0.0, 1.0)], fill=BODY)
    # the face is +z, so mark which way the character looks
    pen.line([pt(15.4, 1.6), pt(15.4, 2.6)], fill=INK, width=2)

    # the arm
    shoulder = pt(SHOULDER[1], SHOULDER[2])
    tip = pt(*arm_tip_world(raise_deg))
    pen.line([shoulder, tip], fill=INK, width=4)

    # the sprite, exactly where the engine puts it
    dot = max(1.0, SCALE * 40 * wield["size"] / 2 / 16 * 0.75)
    for y, z, colour in sprite_world(sprite_path, wield, raise_deg):
        x0, y0 = pt(y, z)
        pen.rectangle([x0 - dot / 2, y0 - dot / 2, x0 + dot / 2, y0 + dot / 2],
                      fill=colour)

    # the fist, on top, so the grip is visible
    hx, hy = pt(*hand_world(wield, raise_deg))
    pen.ellipse([hx - 3, hy - 3, hx + 3, hy + 3], outline=HAND, width=2)
    return cell


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    poses = transform(REPO)

    def tex(*parts):
        return os.path.join(REPO, *parts)

    AXE = tex("mods", "BASE", "default", "textures",
              "default_tool_stoneaxe.png")
    GREATAXE = tex("mods", "ITEMS", "grug_gear", "textures",
                   "grug_gear_item_greataxe_steel.png")
    SWORD = tex("mods", "ITEMS", "grug_gear", "textures",
                "grug_gear_item_sword_steel.png")
    ROD = tex("mods", "ITEMS", "grug_fishing", "textures",
              "grug_fishing_rod.png")
    STICK = tex("mods", "BASE", "default", "textures", "default_stick.png")

    # name -> the rows of its sheet: (caption, sprite, pose)
    SHEETS = [
        ("axe", "default:axe_stone -- what a Dur Brannoc resident carves with",
         [("BEFORE  default:axe_stone, pose=tool", AXE, "tool"),
          ("AFTER   default:axe_stone, pose=edge_down", AXE, "edge_down")]),
        ("greataxe", "grug_gear:greataxe_steel -- the weapon-slot axe",
         [("BEFORE  pose=tool", GREATAXE, "tool"),
          ("AFTER   pose=edge_down", GREATAXE, "edge_down")]),
        ("rod", "the angler's hand",
         [("BEFORE  default:stick, pose=upright (centre in the fist)",
           STICK, "upright"),
          ("AFTER   grug_fishing:rod, pose=tool (grip in the fist)",
           ROD, "tool")]),
        ("sword", "grug_gear:sword_steel -- unchanged, and measurably so",
         [("pose=tool (shipped)", SWORD, "tool"),
          ("pose=edge_down (not used; 100%% silhouette overlap)",
           SWORD, "edge_down")]),
    ]

    cell_w, cell_h = 220, 240
    written = []
    for name, subtitle, rows in SHEETS:
        sheet = Image.new(
            "RGBA",
            (cell_w * len(RAISES), (cell_h + 26) * len(rows) + 20),
            (255, 255, 255, 255))
        pen = ImageDraw.Draw(sheet)
        for r, (caption, path, pose) in enumerate(rows):
            top = r * (cell_h + 26)
            rot = ",".join("%g" % v for v in poses[pose]["rot"])
            pen.text((8, top + 6), "%s  rot %s" % (caption, rot),
                     fill=(20, 20, 20, 255))
            for c, (raise_deg, arm) in enumerate(RAISES):
                cell = draw_cell(path, poses[pose], raise_deg,
                                 (cell_w, cell_h))
                sheet.paste(cell, (c * cell_w, top + 22))
                pen.text((c * cell_w + 8, top + 22 + cell_h - 14), arm,
                         fill=(60, 60, 60, 255))
        pen.text((8, sheet.size[1] - 16),
                 "%s -- side view from the character's left; the character "
                 "faces right (+z). Fist ringed." % subtitle,
                 fill=(60, 60, 60, 255))
        target = os.path.join(outdir, "wield-%s.png" % name)
        sheet.save(target)
        written.append(target)
    for target in written:
        print(target)


if __name__ == "__main__":
    main()
