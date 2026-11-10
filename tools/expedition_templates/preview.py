#!/usr/bin/env python3
"""Render the written Expedition files as plans and sections (Pillow only; Round 72
STYLE, Round 73 TOOLS).

  python3 tools/expedition_templates/preview.py [--out DIR] [--name NAME ...] [--file PATH ...]

No source is built or imported: the pictures show what the game reads. For each
Expedition: a plan of the relief (the floor's height, shaded; stairs with a dark edge on
their low side) and of the light at eye height (0, below 4, 4 and up; sources dotted);
ambush zones outlined, lava, critters and particle boxes marked; per room a sheet with
both plans and two sections; and a sheet with a section across every stair run.

Rooms: ROOMS below, one entry per Expedition (a wave 2 lane edits only its own). An
Expedition without an entry gets one sheet per encounter room, round its markers, and
one round the arrival and the chest.
"""
import argparse
import sys
from pathlib import Path
from types import SimpleNamespace

from PIL import Image, ImageColor, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import light  # noqa: E402
import registry  # noqa: E402
from template import read_back  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / "mods/PLAYER/grug_expeditions/templates"
# Per Expedition: (label, (x0, z0, x1, z1), cut x, cut z). The floor comes from the file.
ROOMS = {
    # Round 73 SEAM: every room and passage, in route order.
    "stilled_seam": [
        ("0 Arrival", (8, 8, 34, 34), 20, 20),
        ("P1 Refuge to cart bay", (26, 10, 54, 34), 40, 20),
        ("1 Cart bay", (46, 12, 82, 42), 60, 28),
        ("P2 Haulage drift (ambush)", (66, 10, 102, 30), 86, 20),
        ("2 Prop room", (96, 10, 124, 42), 108, 28),
        ("D Drift to the sorting bays (ambush)", (96, 36, 120, 68), 108, 51),
        ("3c Sorting bay c", (94, 60, 122, 88), 108, 74),
        ("S Side way past the rock screen", (90, 76, 112, 108), 99, 92),
        ("3d Sorting bay d", (94, 98, 122, 122), 108, 110),
        ("P3 Bay d to the working face", (76, 98, 104, 116), 90, 107),
        ("4 Working face", (50, 90, 84, 122), 68, 108),
        ("P4 The door to the store", (28, 98, 58, 116), 44, 108),
        ("5 Store", (4, 84, 34, 122), 20, 108)],
    "second_shift": [
        ("0 Arrival", (96, 8, 120, 32), 107, 24),
        ("P01 Arrival cut", (76, 10, 100, 30), 89, 20),
        ("1 Timekeeper's office", (48, 8, 80, 40), 60, 36),
        ("P12 Trap gallery", (30, 10, 52, 28), 39, 20),
        ("2 Marking floor", (8, 8, 32, 40), 19, 26),
        ("P23 Grain drift, ambush", (18, 38, 36, 66), 27, 51),
        ("3 Wage hall, bay c", (8, 64, 32, 96), 20, 74),
        ("3 Wage hall, bay d", (8, 88, 32, 120), 16, 104),
        ("P34 Pay drift, ambush", (30, 74, 64, 111), 38, 93),
        ("4 Audit court", (48, 88, 80, 120), 63, 104),
        ("P45 Door cut", (78, 99, 98, 114), 90, 108),
        ("5 Store", (96, 88, 120, 120), 107, 104)],
    "last_mint": [
        ("0 Arrival", (6, 94, 34, 122), 20, 106),
        ("0-1 Passage to the bins", (28, 96, 58, 118), 45, 107),
        ("1 Salvage bins", (48, 88, 80, 120), 64, 104),
        ("1-2 The flue run (ambush a2) and its lava fall", (64, 76, 104, 96), 81, 86),
        ("2 Furnace room", (94, 88, 122, 118), 108, 101),
        ("2-L Passage to the lake", (98, 74, 118, 96), 109, 85),
        ("L Lava crossing", (96, 40, 120, 80), 108, 60),
        ("L-3 Passage to the cooling room", (98, 22, 118, 46), 108, 33),
        ("3 Cooling room", (94, 6, 122, 30), 108, 14),
        ("3-4 The drift (ambush a1)", (76, 12, 100, 66), 88, 38),
        ("4 Press vestibule", (48, 46, 80, 74), 64, 60),
        ("4-5 Passage to the press floor", (54, 34, 74, 54), 64, 44),
        ("5 Press floor", (46, 6, 82, 40), 64, 24),
        ("5-6 The reward door", (26, 10, 54, 30), 44, 20),
        ("6 Store", (6, 6, 34, 42), 20, 23)],
}
COLORS = {
    "stone": "#777e83", "cobble": "#989187", "mossycobble": "#6f8a5c", "gravel": "#a69885",
    "stonebrick": "#a6a7a3", "stone_block": "#dad6c5", "wood": "#af8252",
    "pine_wood": "#d4aa70", "tree": "#71513a", "darkage_reinforced_wood": "#594132",
    "darkage_basalt_brick": "#3c3c46", "darkage_slate_tile": "#677c88", "obsidianbrick": "#2b2633",
    "iron_block": "#575d67", "steel_block": "#a7bec9", "lava_source": "#f06c2e", "lava_flowing": "#f39a4a",
    "stone_with_anthracite": "#dfbb61", "stone_with_jade": "#56bd9c",
    "waystone": "#5ea5c6", "reward_chest": "#e2aa4e", "reward_door": "#c26960",
    "cottages_table": "#aa7751", "cottages_bench": "#987052", "cottages_barrel": "#815d40",
    "mine_rail": "#b1a186", "mine_cart": "#646970", "sign_wall_wood": "#d8b786",
    "xdecor_lantern_hanging": "#ffd57d", "torch_wall": "#ffbd67", "xdecor_rope": "#ae956c",
    "xdecor_candle": "#fff0b0", "moss_carpet": "#5f8f3e", "lichen_carpet": "#8fa060",
    "lichen_carpet_b": "#9a9a5a", "xdecor_cobweb": "#e8e8e8", "air": "#efe9da",
}
LIGHT_ZONES = ((0, "#141418"), (1, "#2c3e7a"), (4, "#d9b45a"))  # 0, below 4, 4 and up
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT = ImageFont.truetype(FONT_PATH, 16)
SMALL = ImageFont.truetype(FONT_PATH, 12)
TITLE = ImageFont.truetype(FONT_PATH, 25)
INK = "#29343b"
# Stair quarters at param2 0 (relief.py HIGH), turned by facedir.
HIGH = {"normal": ((-1, 1), (1, 1)), "inner": ((-1, 1), (1, 1), (-1, -1)), "outer": ((-1, 1),)}


def stair_shape(node):
    for shape, prefix in (("inner", "stairs:stair_inner_"), ("outer", "stairs:stair_outer_"),
                          ("normal", "stairs:stair_")):
        if node.startswith(prefix):
            return shape
    return None


def high_quarters(shape, p):
    out = set()
    for qx, qz in HIGH[shape]:
        for _ in range(p % 4):
            qx, qz = qz, -qx
        out.add((qx, qz))
    return out


class Written:
    """A written file: its cells, palette, head lines, the floor's height map and the light."""

    def __init__(self, path):
        head, self.cells, self.param2 = read_back(path.read_bytes())
        self.name = path.stem
        self.palette = [s[5:] for s in head if s.startswith("node ")]
        self.sx, self.sy, self.sz = next(tuple(map(int, s.split()[1:])) for s in head if s.startswith("size "))
        self.walk = [registry.walkable(n) for n in self.palette]
        self.liquid = [registry.liquid(n) for n in self.palette]
        self.stair = [stair_shape(n) for n in self.palette]
        self.marks, self.ambush, self.particles = [], [], []
        waits = {line.split()[3] for line in head if line.startswith("ambush ")}
        for line in head:
            p = line.split()
            if p[0] == "encounter":
                # Same offsets as encounters.lua; all authored members, not only anchors.
                tag = "x" if p[1] in waits else {"boss": "B", "critter": "cr"}.get(p[4], p[1][-1])
                for dx, dz in [(0, 0), (3, 0), (-3, 0), (0, 3)][:int(p[3]) if p[4] != "critter" else 1]:
                    self.marks.append((int(p[5]) + dx, int(p[7]) + dz, tag))
            elif p[0] == "place" and p[1] in ("arrival", "chest", "start_waystone", "end_waystone"):
                self.marks.append((int(p[2]), int(p[4]), {"arrival": "A", "chest": "C"}.get(p[1], "W")))
            elif p[0] == "ambush":
                self.ambush.append((p[1], int(p[4]), int(p[6]), int(p[7]), int(p[8])))
            elif p[0] == "particles":
                self.particles.append((p[1], int(p[2]), int(p[4]), int(p[5]), int(p[7])))
        self.heights = {}
        for z in range(self.sz):
            for x in range(self.sx):
                for y in range(1, self.sy - 1):
                    below = self.id(x, y - 1, z)
                    if self.walk[below] and not self.walk[self.id(x, y, z)] and not self.liquid[self.id(x, y, z)] \
                            and not self.walk[self.id(x, y + 1, z)] and (self.stair[below] or self.full(below)):
                        self.heights[x, z] = y
                        break
        shape = SimpleNamespace(sx=self.sx, sy=self.sy, sz=self.sz)
        self.levels = light.levels(shape, self.cells, self.palette)
        own = [registry.light(n) and not registry.liquid(n) for n in self.palette]
        plane = self.sx * self.sy
        self.sources = {(i % self.sx, i // plane) for i, node in enumerate(self.cells) if own[node]}

    def full(self, node_id):
        d = registry.definition(self.palette[node_id])
        return d.get("drawtype", "normal") == "normal" or self.palette[node_id] == "grug_expeditions:reward_door"

    def index(self, x, y, z):
        return z * self.sy * self.sx + y * self.sx + x

    def id(self, x, y, z):
        return self.cells[self.index(x, y, z)]

    def get(self, x, y, z):
        return self.palette[self.id(x, y, z)]

    def light_at(self, x, z):
        h = self.heights[x, z]
        return self.levels[self.index(x, min(h + 1, self.sy - 1), z)]


def color(node):
    key = node.split(":")[-1]
    for prefix in ("stair_inner_", "stair_outer_", "stair_"):
        if key.startswith(prefix):
            key = key[len(prefix):]
    return ImageColor.getrgb(COLORS.get(key, "#bf99bd"))


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k))) for c in rgb)


def relief_plan(t, bounds, base):
    """The floor coloured by height round `base` (lighter up, darker down); rock dark."""
    x0, z0, x1, z1 = bounds
    im = Image.new("RGB", (x1 - x0, z1 - z0))
    for z in range(z0, z1):
        for x in range(x0, x1):
            if (x, z) in t.heights:
                h = t.heights[x, z]
                rgb = shade(color(t.get(x, h - 1, z)), 1 + 0.16 * (h - base))
                top = t.get(x, h, z)
                if top != "air" and not registry.walkable(top) and not registry.light(top):
                    rgb = color(top)
            else:
                rgb = (49, 57, 62)
                for y in range(t.sy - 1, 0, -1):
                    node = t.get(x, y, z)
                    if node.startswith("default:lava"):
                        rgb = color(node)
                        break
                for y in range(min(t.sy - 1, base + 1), 0, -1):
                    if t.get(x, y, z).endswith(("stone_with_anthracite", "stone_with_jade")):
                        rgb = color(t.get(x, y, z))
            im.putpixel((x - x0, z - z0), rgb)
    return im


def light_plan(t, bounds):
    x0, z0, x1, z1 = bounds
    im = Image.new("RGB", (x1 - x0, z1 - z0), (49, 57, 62))
    for (x, z) in t.heights:
        if x0 <= x < x1 and z0 <= z < z1:
            v = t.light_at(x, z)
            rgb = next(ImageColor.getrgb(c) for lo, c in reversed(LIGHT_ZONES) if v >= lo)
            if v >= 4:
                rgb = shade(rgb, 0.7 + 0.03 * v)
            im.putpixel((x - x0, z - z0), rgb)
    return im


def section(t, bounds, axis, fixed, bottom, top):
    """A cut across x (axis "x") or along z; two sub-pixels a node, so stairs show."""
    x0, z0, x1, z1 = bounds
    lo, hi = (x0 - 1, x1 + 1) if axis == "x" else (z0 - 1, z1 + 1)
    im = Image.new("RGB", (2 * (hi - lo), 2 * (top - bottom + 1)))
    for u in range(lo, hi):
        for y in range(bottom, top + 1):
            x, z = (u, fixed) if axis == "x" else (fixed, u)
            if not (0 <= x < t.sx and 0 <= z < t.sz):
                continue
            node = t.get(x, y, z)
            rgb = color(node)
            px, py = 2 * (u - lo), 2 * (top - y)
            shape = stair_shape(node)
            for sub_u in (0, 1):
                for sub_y in (0, 1):
                    cell = rgb
                    if shape and sub_y == 0:
                        q = -1 if sub_u == 0 else 1
                        high = high_quarters(shape, t.param2[t.index(x, y, z)] % 4)
                        up = any(((q, s) if axis == "x" else (s, q)) in high for s in (-1, 1))
                        cell = rgb if up else ImageColor.getrgb(COLORS["air"])
                    im.putpixel((px + sub_u, py + sub_y), cell)
    return im


def panel(sheet, im, box, label):
    x, y, w, h = box
    ImageDraw.Draw(sheet).text((x, y), label, fill=INK, font=FONT)
    scale = max(1, min(w // im.width, (h - 30) // im.height))
    sheet.paste(im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST), (x, y + 28))
    return x, y + 28, scale


def overlay(draw, t, bounds, origin, scale, stairs=True):
    """Stairs' low edges, ambush zones, particle boxes, light sources and markers."""
    x0, z0, x1, z1 = bounds

    def px(x, z):
        return origin[0] + (x - x0) * scale, origin[1] + (z - z0) * scale
    if stairs and scale >= 4:
        for (x, z), h in t.heights.items():
            if not (x0 <= x < x1 and z0 <= z < z1):
                continue
            shape = stair_shape(t.get(x, h - 1, z))
            if shape:
                high = high_quarters(shape, t.param2[t.index(x, h - 1, z)] % 4)
                ax, az = px(x, z)
                half = scale / 2
                for qx, qz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                    if (qx, qz) not in high:
                        bx, bz = ax + (qx + 1) / 2 * half, az + (qz + 1) / 2 * half
                        draw.rectangle((bx, bz, bx + half - 1, bz + half - 1), fill="#3a3530")
    for group, ax0, az0, ax1, az1 in t.ambush:
        a, b = px(min(ax0, ax1), min(az0, az1)), px(max(ax0, ax1) + 1, max(az0, az1) + 1)
        draw.rectangle((a[0], a[1], b[0], b[1]), outline="#d23cc8", width=3)
        draw.text((a[0] + 3, a[1] + 2), "ambush " + group, font=SMALL, fill="#d23cc8")
    for style, bx0, bz0, bx1, bz1 in t.particles:
        a, b = px(min(bx0, bx1), min(bz0, bz1)), px(max(bx0, bx1) + 1, max(bz0, bz1) + 1)
        draw.rectangle((a[0], a[1], b[0], b[1]), outline="#2fb8c8", width=2)
        draw.text((a[0] + 2, b[1]), style, font=SMALL, fill="#1f7c87")
    for x, z in t.sources:
        if x0 <= x < x1 and z0 <= z < z1:
            cx, cz = px(x + .5, z + .5)
            r = max(2, scale // 4)
            draw.ellipse((cx - r, cz - r, cx + r, cz + r), fill="#fff6c8", outline="#6b5a1e")
    for x, z, label in t.marks:
        if x0 <= x < x1 and z0 <= z < z1:
            cx, cz = px(x + .5, z + .5)
            fill = "#3f8f3d" if label == "cr" else "#923f3d"
            draw.ellipse((cx - 6, cz - 6, cx + 6, cz + 6), fill=fill)
            draw.text((cx + 7, cz - 8), label, font=SMALL, fill="#461c20")


def stair_runs(t):
    """The stair runs: groups of touching stair cells, with their middle and the axis
    they climb along."""
    stairs = {(x, z): t.param2[t.index(x, h - 1, z)] % 4 for (x, z), h in t.heights.items()
              if stair_shape(t.get(x, h - 1, z))}
    seen, runs = set(), []
    for start in sorted(stairs):
        if start in seen:
            continue
        group, todo = [], [start]
        seen.add(start)
        while todo:
            c = todo.pop()
            group.append(c)
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                n = (c[0] + dx, c[1] + dz)
                if n in stairs and n not in seen:
                    seen.add(n)
                    todo.append(n)
        along_z = sum(1 for c in group if stairs[c] in (0, 2)) >= len(group) / 2
        mx = round(sum(c[0] for c in group) / len(group))
        mz = round(sum(c[1] for c in group) / len(group))
        cx, cz = min(group, key=lambda c: (c[0] - mx) ** 2 + (c[1] - mz) ** 2)
        runs.append((cx, cz, along_z, len(group)))
    return runs


def auto_rooms(t):
    rooms = {}
    for x, z, label in t.marks:
        rooms.setdefault(label, []).append((x, z))
    out = []
    for label, points in sorted(rooms.items()):
        xs, zs = [p[0] for p in points], [p[1] for p in points]
        b = (max(0, min(xs) - 12), max(0, min(zs) - 12), min(t.sx, max(xs) + 13), min(t.sz, max(zs) + 13))
        out.append((f"Markers {label}", b, (b[0] + b[2]) // 2, (b[1] + b[3]) // 2))
    return out


def render(t, rooms, out):
    title = "The " + t.name.replace("_", " ").title()
    floors = sorted(t.heights.values())
    base = floors[len(floors) // 2] if floors else 0
    legend = ("a-d packs | B boss | x ambush marker | cr critter | W waystone | C chest | A arrival | dots: lights | "
              "magenta: ambush | cyan: particles")
    overview = Image.new("RGB", (2200, 1240), "#f6f2e8")
    draw = ImageDraw.Draw(overview)
    draw.text((38, 22), title + " / written floor: relief and light", font=TITLE, fill=INK)
    bounds = (0, 0, t.sx, t.sz)
    side = min(1024, 1024 * 128 // max(t.sx, t.sz))
    o = panel(overview, relief_plan(t, bounds, base), (38, 66, side + 10, side + 40),
              f"Relief: the floor's height, lighter up, darker down from y {base}; stairs dark on their low side")
    overlay(draw, t, bounds, o[:2], o[2])
    o = panel(overview, light_plan(t, bounds), (1100, 66, side + 10, side + 40),
              "Light at eye height: black 0, blue below 4, amber 4 and up")
    overlay(draw, t, bounds, o[:2], o[2], stairs=False)
    draw.text((38, 1180), legend, font=FONT, fill=INK)
    overview.save(out / f"{t.name}-plan.png")
    sheets = []
    for index, (label, bounds, cx, cz) in enumerate(rooms):
        sheet = Image.new("RGB", (1200, 1140), "#f6f2e8")
        draw = ImageDraw.Draw(sheet)
        draw.text((28, 20), title + " / " + label, font=TITLE, fill=INK)
        draw.text((28, 57), f"Written nodes; x {bounds[0]}..{bounds[2]-1}, z {bounds[1]}..{bounds[3]-1}.",
                  font=FONT, fill=INK)
        o = panel(sheet, relief_plan(t, bounds, base), (28, 94, 540, 440), "Relief (height shading, stairs)")
        overlay(draw, t, bounds, o[:2], o[2])
        o = panel(sheet, light_plan(t, bounds), (620, 94, 540, 440), "Light at eye height: 0, below 4, 4+")
        overlay(draw, t, bounds, o[:2], o[2], stairs=False)
        inside = [h for (x, z), h in t.heights.items() if bounds[0] <= x < bounds[2] and bounds[1] <= z < bounds[3]]
        bottom = 0 if label.startswith("L ") else max(0, min(inside or [1]) - 3)
        top = min(t.sy - 1, max(inside or [1]) + 12)
        panel(sheet, section(t, bounds, "x", cz, bottom, top), (28, 565, 540, 450), f"Across x at z={cz}; y={bottom}..{top}")
        panel(sheet, section(t, bounds, "z", cx, bottom, top), (620, 565, 540, 450), f"Along z at x={cx}; y={bottom}..{top}")
        draw.text((28, 1045), legend, font=SMALL, fill=INK)
        draw.text((28, 1075), "Geometry preview, not an engine render. Sections cut stairs into half nodes; air is cream.",
                  font=FONT, fill=INK)
        sheet.save(out / f"{t.name}-{index:02d}.png")
        sheets.append(sheet)
    runs = stair_runs(t)
    if runs:
        cols = 3
        sheet = Image.new("RGB", (1200, 80 + 300 * ((len(runs) + cols - 1) // cols)), "#f6f2e8")
        draw = ImageDraw.Draw(sheet)
        draw.text((28, 20), title + f" / {len(runs)} stair runs, a section through each", font=TITLE, fill=INK)
        for i, (cx, cz, along_z, size) in enumerate(runs):
            h = t.heights[cx, cz]
            b = (max(0, cx - 12), max(0, cz - 12), min(t.sx, cx + 12), min(t.sz, cz + 12))
            im = section(t, b, "z", cx, max(0, h - 5), min(t.sy - 1, h + 6)) if along_z else \
                section(t, b, "x", cz, max(0, h - 5), min(t.sy - 1, h + 6))
            panel(sheet, im, (28 + 390 * (i % cols), 70 + 300 * (i // cols), 380, 290),
                  f"{size} stairs at {cx},{cz}, {'along z' if along_z else 'across x'}")
        sheet.save(out / f"{t.name}-stairs.png")
    if sheets:
        contact = Image.new("RGB", (1200, 380 * ((len(sheets) + 2) // 3)), "#f6f2e8")
        for index, sheet in enumerate(sheets):
            contact.paste(sheet.resize((400, 380)), ((index % 3) * 400, (index // 3) * 380))
        contact.save(out / f"{t.name}-contact.png")
    return len(sheets) + 1 + bool(runs)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=ROOT / "style-previews")
    parser.add_argument("--name", action="append", help="an Expedition's file name (default: every file)")
    parser.add_argument("--file", action="append", type=Path, help="any written .exp file")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    paths = [TEMPLATES / f"{name}.exp" for name in args.name or []] + (args.file or [])
    count = 0
    for path in paths or sorted(TEMPLATES.glob("*.exp")):
        t = Written(path)
        count += render(t, ROOMS.get(t.name) or auto_rooms(t), args.out)
    print(f"{count} previews written to {args.out}")


if __name__ == "__main__":
    main()
