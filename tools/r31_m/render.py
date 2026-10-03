#!/usr/bin/env python3
"""Round 31 lane M: preview pictures of the placed PvP POIs.

    python3 tools/r31_m/render.py OUT_DIR --overview PREFIX... --engine DIR...

--overview PREFIX: the files tools/r31_m/overview.lua wrote (zones, roads,
anchors of one seed); draws OUT_DIR/overview_<seed>.png, the front with its
zones, roads and every anchor, the 18 PvP POIs numbered in catalogue order.
--engine DIR: an output folder of tools/r31_m/engine.sh; for every
r31m_<key>.cells.tsv in it draws OUT_DIR/<key>_iso.png (the real nodes round
the POI, textured, from the south-west) and OUT_DIR/<key>_plan.png (the top
node of every column shaded by height, the building core, the protected box
with its 10-node margin and the sockets). Needs Pillow; textures through
tools/wp13/render_blueprint.py.
"""
import argparse
import colorsys
import importlib.util
import os
import sys
from types import SimpleNamespace

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location(
    "render_blueprint", os.path.join(REPO, "tools", "wp13", "render_blueprint.py"))
rb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rb)
spec = importlib.util.spec_from_file_location("s_render", os.path.join(REPO, "tools", "r31_s", "render.py"))
srender = importlib.util.module_from_spec(spec)
spec.loader.exec_module(srender)

# building core and blueprint box half sizes (source/simple_map.lua,
# r7_settlement.BOUNDS)
CORE = {"fortress": 32, "camp_low": 12, "camp_high": 14}
BOX = {"fortress": 24, "camp_low": 11, "camp_high": 13}
MARGIN = 10


def font(size):
    try:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def zone_colour(n):
    if n == 0:
        return (28, 48, 78)
    if n <= 16:
        base = 0.58      # Elandor: blue-green
    elif n <= 32:
        base = 0.02      # Kragmar: red-orange
    else:
        base = 0.13      # the front: sand
    h = (base + (n * 0.037) % 0.08) % 1.0
    s = 0.25 if n > 32 else 0.35
    v = 0.62 + (n % 4) * 0.06
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def overview(prefix, out_png, scale=2):
    zones = {}
    for line in open(prefix + ".zones.tsv", encoding="utf-8"):
        x, z, n, wet = (int(v) for v in line.split("\t"))
        zones[(x, z)] = (n, wet)
    xs = sorted({k[0] for k in zones})
    zs = sorted({k[1] for k in zones})
    step = xs[1] - xs[0]
    w, h = len(xs) * scale, len(zs) * scale
    img = Image.new("RGB", (w, h))
    px = img.load()

    def to_px(x, z):
        return (x - xs[0]) / step * scale, (zs[-1] - z) / step * scale

    for (x, z), (n, wet) in zones.items():
        c = (70, 120, 190) if wet else zone_colour(n)
        # zone borders darker
        right = zones.get((x + step, z), (n, 0))[0]
        up = zones.get((x, z + step), (n, 0))[0]
        if n and (right != n or up != n):
            c = tuple(int(v * 0.55) for v in c)
        X, Z = to_px(x, z)
        for i in range(scale):
            for j in range(scale):
                px[int(X) + i, int(Z) + j] = c
    draw = ImageDraw.Draw(img)
    for line in open(prefix + ".roads.tsv", encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        kind = parts[1]
        pts = [to_px(*map(int, p.split())) for p in parts[2:]]
        if len(pts) > 1:
            draw.line(pts, fill=(235, 225, 200) if kind != "trail" else (190, 175, 150),
                      width=3 if kind == "primary" else (2 if kind != "trail" else 1))
    f = font(13)
    pvp = []
    for line in open(prefix + ".anchors.tsv", encoding="utf-8"):
        aid, template, slot, x, z, zn = line.rstrip("\n").split("\t")
        x, z = int(x), int(z)
        X, Z = to_px(x, z)
        if template.startswith("pvp_"):
            pvp.append((aid, template, slot, X, Z))
        elif slot not in ("capital", "start"):
            draw.ellipse((X - 2, Z - 2, X + 2, Z + 2), fill=(40, 40, 40))
        else:
            draw.rectangle((X - 4, Z - 4, X + 4, Z + 4), outline=(20, 20, 20), width=2)
    for index, (aid, template, slot, X, Z) in enumerate(pvp, 1):
        accord = slot.startswith("pvp_accord") or (template == "pvp_fortress" and Z > h / 2)
        col = (40, 90, 230) if accord else (215, 40, 40)
        r = 9 if template == "pvp_fortress" else 7
        if template == "pvp_fortress":
            draw.rectangle((X - r, Z - r, X + r, Z + r), fill=col, outline=(255, 255, 255), width=2)
        elif template == "pvp_camp_high":
            draw.ellipse((X - r, Z - r, X + r, Z + r), fill=col, outline=(255, 255, 255), width=2)
        else:
            draw.ellipse((X - r, Z - r, X + r, Z + r), fill=(250, 250, 250), outline=col, width=3)
        label = str(index)
        tw, th = draw.textbbox((0, 0), label, font=f)[2:]
        draw.text((X + r + 2, Z - th / 2 - 2), label, fill=(0, 0, 0), font=f,
                  stroke_width=2, stroke_fill=(255, 255, 255))
    img.save(out_png, optimize=True)


def kind_of(key):
    if "fortress" in key:
        return "fortress"
    return "camp_high" if key.endswith("_high") else "camp_low"


def plan(cells, sockets, top, kind, path, scale):
    columns = {}
    for x, y, z, name, _p2 in cells:
        best = columns.get((x, z))
        if best is None or y > best[0]:
            columns[(x, z)] = (y, name)
    xs = [k[0] for k in columns]
    zs = [k[1] for k in columns]
    minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
    ys = [v[0] for v in columns.values()]
    lo, hi = min(ys), max(ys)
    span = max(8, hi - lo)
    img = Image.new("RGB", ((maxx - minx + 1) * scale, (maxz - minz + 1) * scale), (24, 26, 30))
    draw = ImageDraw.Draw(img)

    def box(x, z):
        px = (x - minx) * scale
        pz = (maxz - z) * scale
        return px, pz, px + scale - 1, pz + scale - 1

    for (x, z), (y, name) in columns.items():
        c = top.get(name)
        shade = 0.55 + 0.45 * (y - lo) / span
        draw.rectangle(box(x, z), fill=tuple(min(255, int(v * shade)) for v in c))
    for (x, z), (y, _n) in columns.items():
        x0, z0, x1, z1 = box(x, z)
        for dx, dz, line in ((1, 0, (x1, z0, x1, z1)), (0, -1, (x0, z1, x1, z1))):
            other = columns.get((x + dx, z + dz))
            if other and abs(other[0] - y) >= 2:
                draw.line(line, fill=(15, 15, 18), width=max(1, scale // 6))

    def square(half_lo, half_hi, colour, width, dash=False):
        x0, z0 = box(-half_lo, half_hi)[:2]
        x1, z1 = box(half_hi, -half_lo)[2:]
        if not dash:
            draw.rectangle((x0, z0, x1, z1), outline=colour, width=width)
            return
        for a, b in (((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)),
                     ((x0, z1), (x0, z0))):
            n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) / (scale * 2)) or 1
            for i in range(0, n, 2):
                p = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
                q = (a[0] + (b[0] - a[0]) * (i + 1) / n, a[1] + (b[1] - a[1]) * (i + 1) / n)
                draw.line((p, q), fill=colour, width=width)

    core, bx = CORE[kind], BOX[kind]
    square(core, core - 1, (250, 250, 250), max(1, scale // 4))
    square(bx + MARGIN, bx + MARGIN, (255, 70, 200), max(2, scale // 3), dash=True)
    f = font(max(9, int(scale * 0.7)))
    radius = scale * 0.7
    for index, s in enumerate(sockets, 1):
        x, z = int(s["x"]), int(s["z"])
        x0, z0, x1, z1 = box(x, z)
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        col = srender.socket_colour(s["role"], s["group"])
        draw.ellipse((cx - radius, cz - radius, cx + radius, cz + radius),
                     fill=col, outline=(0, 0, 0), width=max(1, scale // 10))
    img.save(path, optimize=True)
    return lo, hi


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--overview", nargs="*", default=[])
    ap.add_argument("--engine", nargs="*", default=[])
    opts = ap.parse_args()
    os.makedirs(opts.out, exist_ok=True)
    for prefix in opts.overview:
        seed = os.path.basename(prefix).lstrip("s")
        overview(prefix, os.path.join(opts.out, "overview_%s.png" % seed))
        sys.stderr.write("overview %s\n" % seed)
    bank = rb.TextureBank(rb.DEFAULT_TILES)
    bank.nodes["grug_mapgen:waystone"] = {
        "tiles": ["grug_mapgen_waystone_top.png", "grug_mapgen_waystone_top.png",
                  "grug_mapgen_waystone.png"], "drawtype": "normal", "shape": "cube"}
    top = srender.TopColours(bank)
    for d in opts.engine:
        for name in sorted(os.listdir(d)):
            if not name.endswith(".cells.tsv"):
                continue
            key = name[len("r31m_"):-len(".cells.tsv")]
            kind = kind_of(key)
            cells = rb.load_cells(os.path.join(d, name))
            sockets = [dict(zip(("id", "role", "group", "x", "y", "z", "dir_x", "dir_z"), row))
                       for row in srender.load_tsv(os.path.join(d, "r31m_%s.sockets.tsv" % key))]
            lo, hi = plan(cells, sockets, top, kind, os.path.join(opts.out, key + "_plan.png"),
                          8 if kind == "fortress" else 12)
            # the iso view: the POI and 16 nodes round its box
            reach = BOX[kind] + 16
            near = [c for c in cells if abs(c[0]) <= reach and abs(c[2]) <= reach]
            args = SimpleNamespace(view="sw", ymax=None, ymin=None, region=None,
                                   scale=10 if kind == "fortress" else 14, max_pixels=1800,
                                   light=False, background="#181a1e")
            img, _stats = rb.render(near, bank, args)
            img.convert("RGB").save(os.path.join(opts.out, key + "_iso.png"), optimize=True)
            sys.stderr.write("%s: %d cells, ground y %d..%d relative\n" % (key, len(cells), lo, hi))
    return 0


if __name__ == "__main__":
    sys.exit(main())
