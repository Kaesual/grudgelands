#!/usr/bin/env python3
"""Round 27 minimap art: original, deterministic, no imported assets (CC0 like
the other grug_map marker icons, see mods/PLAYER/grug_map/LICENSE-media.md).

* grug_map_quest_{available,locked,ready,active}.png -- 16x16 pixel art: the
  Map tab's quest symbols ("!" available/locked, "?" ready/active; gold when
  ready or available, grey otherwise) on a round dark badge;
* grug_map_innkeeper.png (a tankard), grug_map_home.png (a gold-roofed house)
  -- 16x16 pixel art with the heading markers' outline colour;
* grug_map_rim_cyan_00..15.png -- 32x32 rim arrows for party members outside
  the minimap, drawn like tools/r15_map/render_headings.py; frame 0 points up
  (north), frames turn clockwise by 22.5 degrees;
* grug_map_minimap_bezel.png -- 256x256 opaque frame of the gliding minimap
  ("pewter"): a warm grey-bronze band round a hole of BEZEL_HOLE of the
  radius, fine light inner edge, dot marks at E/S/W and a small N (north up).

Usage: python3 tools/r27_minimap/render_icons.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_map/textures"
OUTLINE = (25, 21, 15, 255)
CYAN = "#55e1ff"


def pixel_icon(grid, palette):
    im = Image.new("RGBA", (16, 16))
    for y, row in enumerate(grid):
        assert len(row) == 16, row
        for x, ch in enumerate(row):
            im.putpixel((x, y), palette.get(ch, (0, 0, 0, 0)))
    return im


BADGE = [
    ".....oooooo.....",
    "...oobbbbbboo...",
    "..obbbbbbbbbbo..",
    ".obbbbbbbbbbbbo.",
    ".obbbbbbbbbbbbo.",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    "obbbbbbbbbbbbbbo",
    ".obbbbbbbbbbbbo.",
    ".obbbbbbbbbbbbo.",
    "..obbbbbbbbbbo..",
    "...oobbbbbboo...",
    ".....oooooo.....",
]
EXCLAIM = [
    "................",
    "................",
    "......kggk......",
    "......kgGk......",
    "......kgGk......",
    "......kgGk......",
    "......kgGk......",
    "......kgGk......",
    "......kggk......",
    ".......kk.......",
    "......kggk......",
    "......kggk......",
    ".......kk.......",
    "................",
    "................",
    "................",
]
QUESTION = [
    "................",
    "................",
    ".....kkkkk......",
    "....kgGGGgk.....",
    "....kgkkkggk....",
    ".....k...kgk....",
    ".........kgk....",
    "........kgk.....",
    ".......kgk......",
    ".......kgk......",
    "........k.......",
    ".......kgk......",
    ".......kgk......",
    "........k.......",
    "................",
    "................",
]


def quest(glyph, fill, light):
    palette = {"o": OUTLINE, "b": (43, 33, 24, 235), "k": OUTLINE,
               "g": fill, "G": light}
    grid = []
    for base_row, glyph_row in zip(BADGE, glyph):
        grid.append("".join(g if g != "." else b for b, g in zip(base_row, glyph_row)))
    return pixel_icon(grid, palette)


INNKEEPER = [
    "................",
    "...oooooooo.....",
    "..oWWWWWWWWo....",
    "..oWWWWWWWWo....",
    "..obbbbbbbboooo.",
    "..obyyyyyybo..o.",
    "..obyYyyyybo..o.",
    "..obyYyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyyboooo.",
    "..obyyyyyybo....",
    "..obbbbbbbbo....",
    "...oooooooo.....",
    "................",
    "................",
]
HOME = [
    ".......oo.......",
    "......oGGo......",
    ".....oGGGGo.....",
    "....oGGGGGGo....",
    "...oGGGGGGGGo...",
    "..oGGGGGGGGGGo..",
    ".oooooooooooooo.",
    "..owwwwwwwwwwo..",
    "..owwwwoowwwwo..",
    "..owwwoyyowwwo..",
    "..owwwoyyowwwo..",
    "..owwwoyyowwwo..",
    "..owwwoyyowwwo..",
    "..oooooooooooo..",
    "................",
    "................",
]


def rim_arrow(frame):
    """A chevron pointing outward; frame 0 points up (screen), clockwise.
    From tip to back it spans 21 of the texture's 32 px (outline included,
    RIM_EXTENT in minimap.lua), so the minimap can size it to fill the ring;
    even the diagonal frames stay inside the texture."""
    a = frame * math.tau / 16
    s = 128
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    pts = []
    for x, y in [(0, -9.5), (10, 9.5), (0, 5), (-10, 9.5)]:
        # rotate clockwise on screen (y down)
        pts.append(((16 + x * math.cos(a) - y * math.sin(a)) * 4,
                    (16 + x * math.sin(a) + y * math.cos(a)) * 4))
    d.polygon(pts, fill=CYAN)
    d.line(pts + [pts[0]], fill="#19150f", width=9, joint="curve")
    return im.resize((32, 32), Image.Resampling.LANCZOS)


# The N plate, drawn as pixel strokes on the supersampled canvas.
N_GLYPH = [
    "k...k",
    "kk..k",
    "k.k.k",
    "k..kk",
    "k...k",
]


# Hole radius over outer radius and the radius (over the outer one) up to
# which the art is fully opaque; must equal V.BEZEL_HOLE and V.BEZEL_OPAQUE
# in mods/PLAYER/grug_map/minimap_view.lua.
BEZEL_HOLE = 0.83
BEZEL_OPAQUE = 0.975


def bezel():
    """The gliding minimap's frame, "pewter" (chosen by the user, Round 27):
    a warm grey-bronze band, almost flat with a very soft bevel lit from the
    top-left, a fine light inner edge, a slightly darker outer edge, dot
    marks at E, S and W and a small N. No pure black anywhere; opaque from
    the hole to BEZEL_OPAQUE of the radius (checked in main)."""
    ss = 4
    n = 256 * ss
    ys, xs = np.mgrid[0:n, 0:n]
    c = n / 2
    dx, dy = (xs + 0.5 - c) / ss, (ys + 0.5 - c) / ss
    r, th = np.hypot(dx, dy), np.arctan2(dy, dx)
    outer, hole = 127.6, BEZEL_HOLE * 128
    t = (r - hole) / (outer - hole)
    inside = (r >= hole) & (r <= outer)
    # a convex band: its outer slope faces the light at the top-left, its
    # inner slope at the bottom-right
    facing = np.cos(th - math.atan2(-1, -1))
    shade = (1 + 0.10 * (t - 0.5) * 2 * facing) * (0.94 + 0.08 * np.sin(np.pi * np.clip(t, 0, 1)))
    rgb = np.array([86, 78, 66], float)[None, None, :] * shade[..., None]
    rgb[(r >= hole) & (r < hole + 0.9)] = (182, 170, 148)
    rgb[(r > outer - 0.9) & (r <= outer)] = (62, 56, 47)
    alpha = np.where(inside, 255, 0)
    data = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    img = Image.fromarray(data, "RGBA").resize((256, 256), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(img)
    band_mid = 128 - (128 - BEZEL_HOLE * 128) / 2
    for ang in (90, 180, 270):  # E, S, W (0 is north, clockwise)
        a = math.radians(ang)
        x, y = 128 + band_mid * math.sin(a), 128 - band_mid * math.cos(a)
        # opaque: ImageDraw replaces pixels, it does not blend
        d.ellipse((x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=(160, 150, 130, 255))
    scale = 1.4
    x0, y0 = 128 - 2.5 * scale, 128 - band_mid - 2.5 * scale
    for j, row in enumerate(N_GLYPH):
        for i, ch in enumerate(row):
            if ch == "k":
                d.rectangle((x0 + i * scale, y0 + j * scale, x0 + (i + 1) * scale - 0.01,
                             y0 + (j + 1) * scale - 0.01), fill=(214, 204, 184, 255))
    return img


def main():
    gold, gold_light = (255, 215, 0, 255), (255, 240, 150, 255)
    grey, grey_light = (192, 192, 192, 255), (228, 228, 228, 255)
    quest(EXCLAIM, gold, gold_light).save(OUT / "grug_map_quest_available.png")
    quest(EXCLAIM, grey, grey_light).save(OUT / "grug_map_quest_locked.png")
    quest(QUESTION, gold, gold_light).save(OUT / "grug_map_quest_ready.png")
    quest(QUESTION, grey, grey_light).save(OUT / "grug_map_quest_active.png")
    pixel_icon(INNKEEPER, {"o": OUTLINE, "W": (250, 246, 232, 255), "b": (140, 96, 52, 255),
                           "y": (238, 176, 48, 255), "Y": (255, 222, 120, 255)}
               ).save(OUT / "grug_map_innkeeper.png")
    pixel_icon(HOME, {"o": OUTLINE, "G": (255, 211, 79, 255), "w": (245, 236, 214, 255),
                      "y": (176, 64, 44, 255)}).save(OUT / "grug_map_home.png")
    for frame in range(16):
        arrow = rim_arrow(frame)
        # never clipped: the texture's border stays (almost) transparent
        for i in range(32):
            for x, y in ((i, 0), (i, 31), (0, i), (31, i)):
                assert arrow.getpixel((x, y))[3] <= 8, ("rim arrow clipped", frame, x, y)
        arrow.save(OUT / f"grug_map_rim_cyan_{frame:02d}.png")
    art = bezel()
    # the band is opaque (alpha >= 250 of 255) from just outside the hole to
    # BEZEL_OPAQUE
    for step in range(720):
        a = step * math.tau / 720
        for r in (BEZEL_HOLE * 128 + 3, (BEZEL_HOLE + BEZEL_OPAQUE) * 64, BEZEL_OPAQUE * 128):
            x, y = 128 + r * math.cos(a), 128 + r * math.sin(a)
            alpha = art.getpixel((min(255, int(x)), min(255, int(y))))[3]
            assert alpha >= 250, ("bezel not opaque", r, a, alpha)
    art.save(OUT / "grug_map_minimap_bezel.png")
    print("quest=4 innkeeper home rim=16 bezel written to", OUT)


if __name__ == "__main__":
    main()
