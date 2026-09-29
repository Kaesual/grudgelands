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
* grug_map_minimap_ring.png -- 256x256 frame of the round minimap: a dark rim
  with a light inner edge and an "N" plate at the top (north up).

Usage: python3 tools/r27_minimap/render_icons.py
"""
import math
from pathlib import Path

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
    """A chevron pointing outward; frame 0 points up (screen), clockwise."""
    a = frame * math.tau / 16
    s = 128
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    pts = []
    for x, y in [(0, -11), (9, 7), (0, 2), (-9, 7)]:
        # rotate clockwise on screen (y down)
        pts.append(((16 + x * math.cos(a) - y * math.sin(a)) * 4,
                    (16 + x * math.sin(a) + y * math.cos(a)) * 4))
    d.polygon(pts, fill=CYAN)
    d.line(pts + [pts[0]], fill="#19150f", width=7, joint="curve")
    return im.resize((32, 32), Image.Resampling.LANCZOS)


# The N plate, drawn as pixel strokes on the supersampled canvas.
N_GLYPH = [
    "k...k",
    "kk..k",
    "k.k.k",
    "k..kk",
    "k...k",
]


def ring():
    ss = 4
    s = 256 * ss
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    band = 6 * ss
    d.ellipse((0, 0, s - 1, s - 1), outline=(30, 24, 18, 255), width=band)
    d.ellipse((band - ss, band - ss, s - band + ss, s - band + ss),
              outline=(196, 170, 118, 255), width=ss)
    d.ellipse((ss, ss, s - ss, s - ss), outline=(70, 56, 40, 255), width=ss)
    c = s / 2
    d.polygon([(c - 12 * ss, 0), (c + 12 * ss, 0), (c + 9 * ss, 15 * ss), (c - 9 * ss, 15 * ss)],
              fill=(30, 24, 18, 255))
    px = 2 * ss
    x0, y0 = c - 2.5 * px, 2.5 * ss
    for j, row in enumerate(N_GLYPH):
        for i, ch in enumerate(row):
            if ch == "k":
                d.rectangle((x0 + i * px, y0 + j * px, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1),
                            fill=(236, 220, 180, 255))
    return im.resize((256, 256), Image.Resampling.LANCZOS)


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
        rim_arrow(frame).save(OUT / f"grug_map_rim_cyan_{frame:02d}.png")
    ring().save(OUT / "grug_map_minimap_ring.png")
    print("quest=4 innkeeper home rim=16 ring written to", OUT)


if __name__ == "__main__":
    main()
