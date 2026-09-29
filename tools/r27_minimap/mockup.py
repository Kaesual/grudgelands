#!/usr/bin/env python3
"""Round 27 Lane M, Phase 1: minimap mockups at real HUD scale.

    python3 tools/r27_minimap/mockup.py <base_normal.png> <base_high.png> <out_dir>

Composites the planned HUD minimap exactly the way the client would draw it
with default settings, over a plain 1920x1080 frame (HUD scaling 1):

* the window is ~900 nodes, north up, 25 % of the window height (270 px) at
  the top right, 10 px from both edges -- the native minimap's box
  (builtin/game/hud.lua), so the quest list clearance is unchanged;
* the map texture is a crop of the base image snapped to a 16-base-pixel
  grid (ruling 9; `[combine`), made round with a `[mask` at crop resolution,
  and scaled to 270 px with NEAREST sampling: `gui_scaling_filter` defaults to
  false, and then Irrlicht draws 2D images with nearest min/mag filters
  (irr/src/CNullDriver.cpp InitMaterial2D). Normal is therefore pixel-doubled
  and high is decimated (450 -> 270 px);
* a ring, the player arrow (off-centre inside the snapped window), a party
  member inside, a party member outside as a rim arrow, and service markers
  are separate elements drawn at 1:1 on top (ruling 8/9).

Marker art is placeholder art for the mockup only, except the Housing Steward
and trainer book, which are the shipped 16x16 textures. Positions are
illustrative (Highcourt, the human capital at x 0, z -1500 on every seed).
Writes r27_minimap_mockup_{normal,high}.png and r27_minimap_mockup_compare.png.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BOUNDS = (-3600, 3600, -3200, 3200)  # min_x, max_x, min_z, max_z
SCREEN = (1920, 1080)
MAP_PX = SCREEN[1] * 25 // 100      # 270: the native minimap's size
EDGE = 10
WINDOW_NODES = 900
GRID = 16                          # snap grid in base pixels
SS = 4                             # supersampling for the anti-aliased art

PLAYER = {"pos": (-60, -1560), "yaw": math.radians(-40)}   # facing north-east
PARTY_IN = {"pos": (-250, -1350), "yaw": math.radians(150)}  # facing south-west
PARTY_OUT = {"pos": (1300, -1050), "yaw": 0.0}  # east, off the map
MARKERS = [  # (kind, x, z)
    ("quest", 30, -1470),
    ("steward", -25, -1435),
    ("trainer", 75, -1530),
    ("innkeeper", -120, -1515),
    ("home", -300, -1760),
]
GOLD, CYAN, OUTLINE = (255, 211, 79), (85, 225, 255), (25, 21, 15)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/google-noto/NotoSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def arrow(size, color, yaw):
    """A heading triangle like render_headings.py, authored at `size` px."""
    s = size * SS
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    k = s / 32
    pts = []
    for x, y in [(0, -12), (8, 10), (0, 6), (-8, 10)]:
        pts.append(((16 + x * math.cos(yaw) + y * math.sin(yaw)) * k,
                    (16 - x * math.sin(yaw) + y * math.cos(yaw)) * k))
    d.polygon(pts, fill=color)
    d.line(pts + [pts[0]], fill=OUTLINE, width=max(1, int(1.8 * k)), joint="curve")
    return im.resize((size, size), Image.LANCZOS)


def rim_arrow(size, color, angle):
    """A small outward-pointing triangle for a party member off the map."""
    s = size * SS
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    c = s / 2
    pts = []
    for r, a in [(0.46, 0), (0.42, 2.45), (0.42, -2.45)]:
        pts.append((c + r * s * math.cos(angle + a), c + r * s * math.sin(angle + a)))
    d.polygon(pts, fill=color)
    d.line(pts + [pts[0]], fill=OUTLINE, width=int(1.5 * SS), joint="curve")
    return im.resize((size, size), Image.LANCZOS)


def glyph_icon(text, fg, bg=(43, 33, 24, 230)):
    """Round dark badge with a gold glyph (quest '!' / '?'), 16 px."""
    s = 16 * SS
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    d.ellipse((SS, SS, s - SS, s - SS), fill=bg, outline=OUTLINE, width=SS)
    f = font(13 * SS)
    box = d.textbbox((0, 0), text, font=f)
    d.text(((s - (box[2] - box[0])) / 2 - box[0], (s - (box[3] - box[1])) / 2 - box[1]),
           text, font=f, fill=fg, stroke_width=SS, stroke_fill=OUTLINE)
    return im.resize((16, 16), Image.LANCZOS)


def pixel_icon(grid, palette):
    im = Image.new("RGBA", (16, 16))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            im.putpixel((x, y), palette.get(ch, (0, 0, 0, 0)))
    return im


INNKEEPER = pixel_icon([  # a tankard
    "................",
    "...oooooooo.....",
    "..oWWWWWWWWo....",
    "..oWWWWWWWWo....",
    "..obbbbbbbboooo.",
    "..obyyyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyybo..o.",
    "..obyyyyyyboooo.",
    "..obyyyyyybo....",
    "..obbbbbbbbo....",
    "...oooooooo.....",
    "................",
    "................"], {"o": OUTLINE + (255,), "W": (250, 246, 232, 255),
                          "b": (140, 96, 52, 255), "y": (238, 176, 48, 255)})
HOME = pixel_icon([  # a hearth house with a gold door
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
    "................"], {"o": OUTLINE + (255,), "G": (255, 211, 79, 255),
                          "w": (245, 236, 214, 255), "y": (176, 64, 44, 255)})


def icons():
    tex = ROOT / "mods/PLAYER"
    return {
        "quest": glyph_icon("!", GOLD),
        "steward": Image.open(tex / "grug_map/textures/grug_map_housing_steward.png").convert("RGBA"),
        "trainer": Image.open(tex / "grug_jobs/textures/grug_jobs_book.png").convert("RGBA"),
        "innkeeper": INNKEEPER,
        "home": HOME,
    }


def ring(size):
    """The frame: a dark rim with a light inner edge and a north tick."""
    s = size * SS
    im = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(im)
    w = 5 * SS
    d.ellipse((0, 0, s - 1, s - 1), outline=(30, 24, 18, 255), width=w)
    d.ellipse((w - SS, w - SS, s - w + SS, s - w + SS), outline=(196, 170, 118, 255), width=SS)
    # north: a small plate with an "N"
    c = s / 2
    d.polygon([(c - 11 * SS, 0), (c + 11 * SS, 0), (c + 8 * SS, 13 * SS), (c - 8 * SS, 13 * SS)],
              fill=(30, 24, 18, 255))
    f = font(11 * SS)
    box = d.textbbox((0, 0), "N", font=f)
    d.text((c - (box[2] - box[0]) / 2 - box[0], 1 * SS - box[1] + 0.5 * SS), "N", font=f,
           fill=(236, 220, 180, 255))
    return im.resize((size, size), Image.LANCZOS)


def minimap(base_path):
    base = Image.open(base_path).convert("RGBA")
    bw, bh = base.size
    npp = (BOUNDS[1] - BOUNDS[0]) / bw           # nodes per base pixel
    crop_px = round(WINDOW_NODES / npp)          # 135 normal, 450 high

    def to_px(x, z):
        return (x - BOUNDS[0]) / npp, (BOUNDS[3] - z) / npp

    px, pz = to_px(*PLAYER["pos"])
    # ruling 9: the window's top-left snaps to the GRID; the arrow moves.
    ox = int((px - crop_px / 2) // GRID * GRID)
    oz = int((pz - crop_px / 2) // GRID * GRID)
    crop = base.crop((ox, oz, ox + crop_px, oz + crop_px))
    # `[mask` at crop resolution: a white disc, alpha 255 inside, inset so
    # its stair-stepped edge stays under the ring (ring width 5 of 270 px)
    mask = Image.new("L", (crop_px * SS, crop_px * SS))
    inset = crop_px * SS * 3 / MAP_PX
    ImageDraw.Draw(mask).ellipse((inset, inset, crop_px * SS - 1 - inset, crop_px * SS - 1 - inset),
                                 fill=255)
    mask = mask.resize((crop_px, crop_px), Image.LANCZOS)
    crop.putalpha(Image.eval(mask, lambda a: 255 if a >= 128 else 0))  # AND of binary alpha
    shown = crop.resize((MAP_PX, MAP_PX), Image.NEAREST)            # HUD draw, nearest

    layer = Image.new("RGBA", (MAP_PX, MAP_PX))
    layer.alpha_composite(shown)
    scale = MAP_PX / (crop_px * npp)            # screen px per node
    cx = cy = MAP_PX / 2
    radius = MAP_PX / 2 - 6

    def screen(x, z):
        bx, bz = to_px(x, z)
        return (bx - ox) * npp * scale, (bz - oz) * npp * scale

    def put(im, x, y):
        layer.alpha_composite(im, (int(round(x - im.width / 2)), int(round(y - im.height / 2))))

    ic = icons()
    for kind, x, z in MARKERS:
        sx, sy = screen(x, z)
        if math.hypot(sx - cx, sy - cy) <= radius - 8:
            put(ic[kind], sx, sy)
    for member in (PARTY_IN, PARTY_OUT):
        sx, sy = screen(*member["pos"])
        dist = math.hypot(sx - cx, sy - cy)
        if dist <= radius - 10:
            put(arrow(20, CYAN, member["yaw"]), sx, sy)
        else:
            ang = math.atan2(sy - cy, sx - cx)
            rx, ry = cx + (radius - 9) * math.cos(ang), cy + (radius - 9) * math.sin(ang)
            put(rim_arrow(16, CYAN, ang), rx, ry)
    sx, sy = screen(*PLAYER["pos"])
    put(arrow(24, GOLD, PLAYER["yaw"]), sx, sy)
    layer.alpha_composite(ring(MAP_PX))
    return layer, crop_px, (ox, oz), npp


def frame(mm):
    w, h = SCREEN
    im = Image.new("RGBA", SCREEN)
    d = ImageDraw.Draw(im)
    for y in range(h):  # plain sky-to-ground stand-in for the game view
        t = y / h
        if t < 0.55:
            c = (int(120 + 60 * t), int(160 + 50 * t), int(205 + 20 * t))
        else:
            c = (int(92 - 30 * (t - .55)), int(112 - 30 * (t - .55)), int(70 - 20 * (t - .55)))
        d.line((0, y, w, y), fill=c + (255,))
    im.alpha_composite(mm, (w - EDGE - MAP_PX, EDGE))
    # the quest list anchor (hud_layout quest_list: right edge, mid-height)
    f = font(16)
    y0 = h // 2 - 30
    for i, line in enumerate(["Quest: The Stolen Ledger  1/3", "Quest: Wolves at the Mill  4/8"]):
        d.text((w - 20, y0 + i * 22), line, font=f, fill=(255, 255, 255), anchor="ra",
               stroke_width=2, stroke_fill=(0, 0, 0))
    return im.convert("RGB")


def main():
    normal, high, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    shots = {}
    for tag, path in (("normal", normal), ("high", high)):
        mm, crop_px, origin, npp = minimap(path)
        frame(mm).save(out / f"r27_minimap_mockup_{tag}.png")
        shots[tag] = (mm, crop_px, npp)
        print(f"{tag}: crop {crop_px}x{crop_px} base px ({npp:.2f} nodes/px) at {origin}, "
              f"texture {crop_px * crop_px * 4 / 1024:.0f} KiB")
    # side by side at real scale, then the same at 3x (nearest) for inspection
    pad, head = 16, 28
    sheet = Image.new("RGB", (2 * (MAP_PX * 3) + 3 * pad, head + MAP_PX + pad + head + MAP_PX * 3 + pad),
                      (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    f = font(16)
    for k, tag in enumerate(("normal", "high")):
        mm, crop_px, npp = shots[tag]
        x = pad + k * (MAP_PX * 3 + pad)
        d.text((x, 6), f"{tag}: {crop_px} px crop ({npp:.2f} nodes/px) -> 270 px, real size", font=f,
               fill=(235, 235, 235))
        sheet.paste(mm, (x, head), mm)
        d.text((x, head + MAP_PX + pad + 4), f"{tag}: the same, enlarged 3x", font=f, fill=(235, 235, 235))
        big = mm.resize((MAP_PX * 3, MAP_PX * 3), Image.NEAREST)
        sheet.paste(big, (x, head + MAP_PX + pad + head), big)
    sheet.save(out / "r27_minimap_mockup_compare.png")


if __name__ == "__main__":
    main()
