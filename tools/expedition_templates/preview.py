#!/usr/bin/env python3
"""Render the written Expedition files as plans and room sections (Pillow only).

python3 tools/expedition_templates/preview.py [--out style-previews]
No source is built or imported: the pictures show what the game actually reads.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

from template import read_back

ROOT = Path(__file__).resolve().parents[2]
# Room envelopes and useful cuts, in template coordinates; a cut may include a
# passage mouth. The floor footprint itself always comes from the written file.
ROOMS = {
    "stilled_seam": (5, [
        ("0 Arrival", (8, 8, 32, 32), 20, 20),
        ("1 Cart bay", (48, 8, 80, 40), 60, 28),
        ("2 Prop room", (96, 8, 120, 40), 108, 28),
        ("3 Sorting floor", (96, 64, 120, 120), 108, 74),
        ("4 Working face", (48, 88, 80, 120), 68, 108),
        ("5 Store", (8, 88, 32, 120), 20, 108)]),
    "second_shift": (8, [
        ("0 Arrival", (96, 8, 120, 32), 107, 24),
        ("1 Timekeeper's desk", (48, 8, 80, 40), 63, 20),
        ("2 Marking floor", (8, 8, 32, 40), 19, 28),
        ("3 Wage room", (8, 64, 32, 120), 20, 74),
        ("4 Audit court", (48, 88, 80, 120), 63, 104),
        ("5 Store", (96, 88, 120, 120), 107, 104)]),
    "last_mint": (32, [
        ("0 Arrival", (8, 96, 32, 120), 20, 104),
        ("1 Salvage bins", (48, 88, 80, 120), 64, 104),
        ("2 Furnace room", (96, 88, 120, 120), 108, 100),
        ("L Lava crossing", (96, 40, 120, 80), 108, 60),
        ("3 Cooling room", (96, 8, 120, 32), 108, 16),
        ("4 Press vestibule", (48, 48, 80, 72), 64, 60),
        ("5 Press floor", (48, 8, 80, 40), 64, 23),
        ("6 Store", (8, 8, 32, 40), 20, 23)]),
}
COLORS = {
    "stone": "#777e83", "cobble": "#989187", "gravel": "#a69885",
    "stonebrick": "#a6a7a3", "stone_block": "#dad6c5", "wood": "#af8252",
    "pine_wood": "#d4aa70", "tree": "#71513a", "darkage_reinforced_wood": "#594132",
    "darkage_basalt_brick": "#3c3c46", "darkage_slate_tile": "#677c88",
    "iron_block": "#575d67", "steel_block": "#a7bec9", "lava_source": "#f06c2e",
    "stone_with_anthracite": "#dfbb61", "stone_with_jade": "#56bd9c",
    "waystone": "#5ea5c6", "reward_chest": "#e2aa4e", "reward_door": "#c26960",
    "cottages_table": "#aa7751", "cottages_bench": "#987052", "cottages_barrel": "#815d40",
    "mine_rail": "#b1a186", "mine_cart": "#646970", "sign_wall_wood": "#d8b786",
    "xdecor_lantern_hanging": "#ffd57d", "torch_wall": "#ffbd67", "xdecor_rope": "#ae956c",
    "air": "#efe9da",
}
OPEN = {"air", "default:torch_wall", "grug_decor:xdecor_lantern_hanging",
        "grug_decor:xdecor_rope", "default:sign_wall_wood"}
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT = ImageFont.truetype(FONT_PATH, 16)
SMALL = ImageFont.truetype(FONT_PATH, 12)
TITLE = ImageFont.truetype(FONT_PATH, 25)


class Written:
    def __init__(self, path):
        head, self.cells, _ = read_back(path.read_bytes())
        self.palette = [s[5:] for s in head if s.startswith("node ")]
        self.sx, self.sy, self.sz = next(tuple(map(int, s.split()[1:])) for s in head if s.startswith("size "))
        self.marks = []
        for line in head:
            p = line.split()
            if p[0] == "encounter":
                # Same offsets as encounters.lua; all authored members, not only anchors.
                for dx, dz in [(0, 0), (3, 0), (-3, 0), (0, 3)][:int(p[3])]:
                    self.marks.append((int(p[5]) + dx, int(p[7]) + dz, "B" if p[1] == "boss" else p[1][-1]))
            elif p[0] == "place" and p[1] in ("arrival", "chest", "start_waystone", "end_waystone"):
                self.marks.append((int(p[2]), int(p[4]), {"arrival": "A", "chest": "C"}.get(p[1], "W")))

    def get(self, x, y, z):
        return self.palette[self.cells[z * self.sy * self.sx + y * self.sx + x]]


def color(node):
    return ImageColor.getrgb(COLORS.get(node.split(":")[-1], "#bf99bd"))


def plan(t, feet, bounds, ceiling=False):
    x0, z0, x1, z1 = bounds
    im = Image.new("RGB", (x1 - x0, z1 - z0))
    for z in range(z0, z1):
        for x in range(x0, x1):
            node = t.get(x, feet, z)
            if node in OPEN:
                if ceiling:
                    h = feet
                    while h < t.sy - 1 and t.get(x, h, z) in OPEN:
                        h += 1
                    # Dark blue is low, pale blue is tall; not simulated lighting.
                    shade = min(210, 55 + (h - feet) * 10)
                    rgb = (shade // 2, shade * 3 // 4, shade)
                else:
                    below = t.get(x, feet - 1, z)
                    rgb = (161, 63, 44) if below in OPEN else color(below)
            else:
                rgb = color(node)
                if node == "default:stone":
                    rgb = (49, 57, 62)
                mineral = t.get(x, feet + 1, z)
                if mineral.endswith(("stone_with_anthracite", "stone_with_jade")):
                    rgb = color(mineral)
            im.putpixel((x - x0, z - z0), rgb)
    return im


def section(t, bounds, axis, fixed, bottom, top):
    x0, z0, x1, z1 = bounds
    lo, hi = (x0 - 1, x1 + 1) if axis == "x" else (z0 - 1, z1 + 1)
    im = Image.new("RGB", (hi - lo, top - bottom + 1))
    for u in range(lo, hi):
        for y in range(bottom, top + 1):
            x, z = (u, fixed) if axis == "x" else (fixed, u)
            im.putpixel((u - lo, top - y), color(t.get(x, y, z)))
    return im


def panel(sheet, im, box, label):
    x, y, w, h = box
    draw = ImageDraw.Draw(sheet)
    draw.text((x, y), label, fill="#29343b", font=FONT)
    scale = min(w // im.width, (h - 30) // im.height)
    enlarged = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
    sheet.paste(enlarged, (x, y + 28))
    return x, y + 28, scale


def markers(draw, t, bounds, origin, scale):
    for x, z, label in t.marks:
        if bounds[0] <= x < bounds[2] and bounds[1] <= z < bounds[3]:
            px = origin[0] + (x - bounds[0] + .5) * scale
            pz = origin[1] + (z - bounds[1] + .5) * scale
            draw.ellipse((px - 6, pz - 6, px + 6, pz + 6), fill="#923f3d")
            draw.text((px + 7, pz - 8), label, font=SMALL, fill="#461c20")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "style-previews")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, (feet, rooms) in ROOMS.items():
        t = Written(ROOT / "mods/PLAYER/grug_expeditions/templates" / (name + ".exp"))
        title = "The " + name.replace("_", " ").title()
        overview = Image.new("RGB", (1100, 1200), "#f6f2e8")
        draw = ImageDraw.Draw(overview)
        draw.text((38, 25), title + " / written floor plan", font=TITLE, fill="#29343b")
        bounds = (0, 0, 128, 128)
        ox, oy, scale = panel(overview, plan(t, feet, bounds), (38, 68, 1024, 1060), f"First body row y={feet}; north at top; one square = one node")
        markers(draw, t, bounds, (ox, oy), scale)
        draw.text((38, 1145), "a-d packs | B boss | W waystone | C chest | A arrival | red-brown: lake void", font=FONT, fill="#29343b")
        overview.save(args.out / (name + '-plan.png'))
        contact = Image.new("RGB", (1200, 380 * ((len(rooms) + 2) // 3)), "#f6f2e8")
        for index, (label, bounds, cx, cz) in enumerate(rooms):
            sheet = Image.new("RGB", (1200, 1140), "#f6f2e8")
            draw = ImageDraw.Draw(sheet)
            draw.text((28, 20), title + " / " + label, font=TITLE, fill="#29343b")
            draw.text((28, 57), f"Written nodes; x {bounds[0]}..{bounds[2]-1}, z {bounds[1]}..{bounds[3]-1}. Sections include the solid hull.", font=FONT, fill="#29343b")
            ox, oy, scale = panel(sheet, plan(t, feet, bounds), (28, 94, 540, 440), f"Floor plan at y={feet}")
            markers(draw, t, bounds, (ox, oy), scale)
            panel(sheet, plan(t, feet, bounds, True), (620, 94, 540, 440), "Clear height: dark = low; pale = high")
            bottom = 0 if label.startswith('L ') else feet - 2
            top = min(t.sy - 1, 2 + max(y for z in range(bounds[1], bounds[3])
                      for x in range(bounds[0], bounds[2]) for y in range(feet, t.sy)
                      if t.get(x, y, z) in OPEN))
            panel(sheet, section(t, bounds, "x", cz, bottom, top), (28, 565, 540, 450), f"Across x at z={cz}; y={bottom}..{top}")
            panel(sheet, section(t, bounds, "z", cx, bottom, top), (620, 565, 540, 450), f"Along z at x={cx}; y={bottom}..{top}")
            draw.text((28, 1045), "Grey rock/masonry | brown timber | blue-grey metal | gold ore | green gem | amber lights", font=FONT, fill="#29343b")
            draw.text((28, 1075), "Geometry preview, not an engine render. Node boxes use whole-cell silhouettes; air is cream.", font=FONT, fill="#29343b")
            sheet.save(args.out / f"{name}-{index:02d}.png")
            contact.paste(sheet.resize((400, 380)), ((index % 3) * 400, (index // 3) * 380))
        contact.save(args.out / f"{name}-contact.png")
    count = sum(len(rooms) + 2 for _, rooms in ROOMS.values())
    print(f"{count} previews written to {args.out}")


if __name__ == "__main__":
    main()
