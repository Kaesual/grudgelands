#!/usr/bin/env python3
"""Generate the crosshair and bow-draw ring textures (playtest-fix Lane B).

Writes into mods/PLAYER/grug_abilities/textures/:

  crosshair.png, object_crosshair.png
      The engine's own crosshair media (src/client/hud.cpp drawCrosshair).
      Both files are byte-identical, so the native "pointing at an object"
      switch is invisible; all target feedback comes from the server overlay.
      White on a soft dark outline with a transparent background: the engine
      multiplies the image by the client's crosshair_color (default white) and
      draws it at integer scale floor(hud_scaling * display density).
      The server overlay tints this same image with `^[multiply:<colour>`
      (grug_abilities/crosshair.lua), so there is no separate state sprite.

  grug_abilities_draw_ring_00.png .. _15.png, grug_abilities_draw_ring_full.png
      The bow draw power ring around the crosshair. Frame k shows the arc
      filled to k/16 clockwise from the top over a faint full-circle track;
      the full frame is a thicker gold ring.

All sprites have odd sizes, so a single centre pixel sits on the screen centre
exactly like the engine crosshair (both centre with an integer half size).
Run from anywhere: python3 tools/pt_fixes/lane_b/gen_crosshair_textures.py
Own work, CC0 (see mods/PLAYER/grug_abilities/LICENSE-media.md).
"""

import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "mods", "PLAYER",
                                    "grug_abilities", "textures"))

# --- Crosshair -------------------------------------------------------------
CROSS_SIZE = 21            # odd: centre pixel at (10, 10)
ARM_FROM, ARM_TO = 3, 7    # arm pixels at these distances from the centre
CENTRE_DOT = True
CORE = (255, 255, 255, 255)
OUTLINE = (0, 0, 0, 150)   # 1 px soft dark outline around every core pixel

# --- Draw ring -------------------------------------------------------------
RING_SIZE = 35             # odd; the ring lies outside the 20 px ready ring
RING_FRAMES = 16
RING_R_IN, RING_R_OUT = 13.0, 15.0          # filled band (pixels)
TRACK = (0, 0, 0, 80)                       # unfilled part of the circle
FILL = (240, 232, 214, 235)                 # warm white while drawing
FULL = (255, 196, 58, 255)                  # gold when fully drawn
FULL_R_IN, FULL_R_OUT = 12.5, 15.5          # the full frame is thicker
SUPERSAMPLE = 4


def crosshair():
    img = Image.new("RGBA", (CROSS_SIZE, CROSS_SIZE), (0, 0, 0, 0))
    c = CROSS_SIZE // 2
    core_px = set()
    for d in range(ARM_FROM, ARM_TO + 1):
        core_px.update({(c + d, c), (c - d, c), (c, c + d), (c, c - d)})
    if CENTRE_DOT:
        core_px.add((c, c))
    for (x, y) in core_px:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in core_px:
                    img.putpixel(p, OUTLINE)
    for p in core_px:
        img.putpixel(p, CORE)
    return img


def ring(fraction, full=False):
    """Supersampled arc; `fraction` of the circle filled clockwise from 12."""
    s = SUPERSAMPLE
    size = RING_SIZE * s
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    centre = size / 2.0
    r_in, r_out = (FULL_R_IN, FULL_R_OUT) if full else (RING_R_IN, RING_R_OUT)
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5) - centre
            dy = (y + 0.5) - centre
            r = math.hypot(dx, dy) / s
            if r < r_in or r > r_out:
                continue
            if full:
                px[x, y] = FULL
                continue
            # Clockwise angle from the top, 0..1.
            angle = (math.atan2(dx, -dy) / (2 * math.pi)) % 1.0
            px[x, y] = FILL if angle < fraction else TRACK
    return img.resize((RING_SIZE, RING_SIZE), Image.LANCZOS)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, os.path.join(HERE, "..", "..", "..")),
          img.size)


def main():
    cross = crosshair()
    save(cross, "crosshair.png")
    save(cross, "object_crosshair.png")
    for k in range(RING_FRAMES):
        save(ring(k / RING_FRAMES), "grug_abilities_draw_ring_%02d.png" % k)
    save(ring(1.0, full=True), "grug_abilities_draw_ring_full.png")


if __name__ == "__main__":
    main()
