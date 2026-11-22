#!/usr/bin/env python3
"""Round 86 lane ROADS: pictures of road cut walls for the user.

    python3 tools/r86_roads/render.py OUT DUMP PICDIR SEED [X,Z ...]

OUT: census.lua output with R86_ROADS_SECTIONS=1 (the "section" lines of each
rule); DUMP: its R86_ROADS_DUMP folder. Writes into PICDIR
  top-<seed>.png              the world (ground every 16 nodes, roads) with
                              the sections marked and numbered
  section-<seed>-<n>.png      per section (the listed X,Z or every one): a
                              local top view (final ground, road, side
                              columns, the section line) and the cross-
                              section at true scale (1 node across = 1 up):
                              nature's ground and the final ground of each
                              rule, the side zone's edge marked
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf'
FONT_B = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf'
SIDE = 24
COLOURS = {"nature": (40, 150, 40), "today": (0, 0, 0), "before": (0, 0, 0),
           "built": (30, 90, 230), "fade1": (30, 90, 230),
           "fade05": (230, 120, 0), "rock3": (160, 40, 160)}
LABELS = {"nature": "nature (no road)", "today": "today (2:1, wall at the edge)",
          "before": "before (0.85.0: 2:1, wall at the edge)",
          "built": "built (0.86.0: the cut meets the ground at the edge)",
          "fade1": "fade1 (depth <= distance to edge)",
          "fade05": "fade0.5 (depth <= half that)", "rock3": "rock 3 per node"}

out, dump, pics, seed = sys.argv[1:5]
wanted = sys.argv[5:]
os.makedirs(pics, exist_ok=True)
font = ImageFont.truetype(FONT, 14)
bold = ImageFont.truetype(FONT_B, 16)

sections = {}
order = []
for line in open(os.path.join(out, seed + ".txt")):
    p = line.split()
    if not p or p[0] != "section":
        continue
    d = dict(kv.split("=", 1) for kv in p[3:])
    if p[2] not in sections:
        sections[p[2]] = {"meta": d, "rules": {}}
        order.append(p[2])
    sections[p[2]]["rules"][p[1]] = [int(v) for v in d["f"].split(",")]
    sections[p[2]]["n"] = [int(v) for v in d["n"].split(",")]
chosen = wanted or order


def shade(h, step=1.0):
    gx = np.gradient(h, axis=1) / step
    gz = np.gradient(h, axis=0) / step
    light = (-gx - gz) / np.sqrt(gx * gx + gz * gz + 1)
    return np.clip(0.6 + 0.4 * light, 0, 1)


# the world top view
rows = np.loadtxt(os.path.join(dump, seed + "-coarse.tsv"))
xs, zs = np.unique(rows[:, 0]), np.unique(rows[:, 1])
H = rows[:, 2].reshape(len(zs), len(xs))
land = rows[:, 3].reshape(len(zs), len(xs)) > 0
S = 2
s = shade(H, 16)
v = np.clip((H - 0) / 300, 0, 1)
rgb = np.stack([150 + 80 * v, 170 + 50 * v, 120 + 80 * v], -1) * s[..., None]
rgb[~land] = (90, 130, 190)
img = Image.fromarray(np.flipud(rgb).astype(np.uint8)).resize((len(xs) * S, len(zs) * S))
draw = ImageDraw.Draw(img)
x0, z1 = xs[0], zs[-1]


def px(x, z):
    return (x - x0) / 16 * S, (z1 - z) / 16 * S


roads = {}
for line in open(os.path.join(dump, seed + "-roads.tsv")):
    rid, kind, x, z = line.split()
    roads.setdefault(rid, []).append(px(float(x), float(z)))
for pts in roads.values():
    if len(pts) > 1:
        draw.line(pts, fill=(120, 60, 20), width=1)
for n, key in enumerate(chosen, 1):
    x, z = (int(v) for v in key.split(","))
    cx, cy = px(x, z)
    draw.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), outline=(220, 0, 0), width=2)
    draw.text((cx + 8, cy - 8), str(n), font=bold, fill=(220, 0, 0))
draw.text((8, 8), f"seed {seed}: roads (brown), the sections (red, numbered); north up",
          font=bold, fill=(0, 0, 0))
img.save(os.path.join(pics, f"top-{seed}.png"))

# per section
for n, key in enumerate(chosen, 1):
    sec = sections[key]
    x, z = (int(v) for v in key.split(","))
    loc = np.loadtxt(os.path.join(dump, f"{seed}-local-{x}_{z}.tsv"))
    with open(os.path.join(dump, f"{seed}-local-{x}_{z}.tsv")) as f:
        head = f.readline().split()
    lx0, lz0, lx1, lz1 = (int(v) for v in head[2:6])
    side = int(np.sqrt(len(loc)))
    fy = loc[:, 2].reshape(side, side)
    code = loc[:, 3].reshape(side, side)
    s = shade(fy)
    v = (fy - fy.min()) / max(1, fy.max() - fy.min())
    rgb = np.stack([150 + 90 * v, 170 + 70 * v, 120 + 90 * v], -1) * s[..., None]
    rgb[code == 1] = (120, 120, 120)
    rgb[code == 2] = rgb[code == 2] * 0.5 + np.array([200, 160, 90]) * 0.5
    T = 4
    top = Image.fromarray(np.flipud(rgb).astype(np.uint8)).resize((side * T, side * T),
                                                                    Image.NEAREST)
    td = ImageDraw.Draw(top)
    bx, bz = x - side // 2, z + side // 2

    def tp(px_, pz_):
        return (px_ - bx + 0.5) * T, (bz - pz_ + 0.5) * T
    td.line([tp(lx0, lz0), tp(lx1, lz1)], fill=(220, 0, 0), width=2)
    cx, cy = tp(x, z)
    td.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline=(220, 0, 0), width=2)
    # the cross-section at true scale
    nat = sec["n"]
    series = [("nature", nat)] + [(r, sec["rules"][r]) for r in
                                  ("before", "today", "built", "fade1", "fade05", "rock3")
                                  if r in sec["rules"]]
    lo = min(min(vals) for _, vals in series) - 3
    hi = max(max(vals) for _, vals in series) + 3
    width = len(nat)
    scale = max(4, min(14, 820 / (hi - lo)))
    pw, ph = int(width * scale) + 60, int((hi - lo) * scale) + 40
    W = max(top.width + 30 + max(pw, 380), 1000)
    Hh = max(top.height, ph) + 175
    pic = Image.new("RGB", (W, Hh), (255, 255, 255))
    pic.paste(top, (10, 130))
    d = ImageDraw.Draw(pic)
    m = sec["meta"]
    steps = ", ".join(f"{name} {max(abs(v[i + 1] - v[i]) for i in range(len(v) - 1))}"
                      for name, v in series)
    d.text((10, 6), f"seed {seed}, section {n} at {x},{z} (road {m['road']}); largest step: "
           f"{steps}", font=bold, fill=(0, 0, 0))
    d.text((480, 34), f"road {float(m['depth']):.0f} below nature at its centre line;", font=font,
           fill=(0, 0, 0))
    d.text((480, 52), f"nature {float(m['rise']):.0f} above the road at the side zone's edge",
           font=font, fill=(0, 0, 0))
    ox, oy = top.width + 40, 130

    def cp(e, y):
        return ox + e * scale, oy + (hi - y) * scale
    for y in range((int(lo) + 9) // 10 * 10, int(hi) + 1, 10):
        d.line([cp(0, y), cp(width - 1, y)], fill=(225, 225, 225))
        d.text((ox - 34, cp(0, y)[1] - 8), str(y), font=font, fill=(110, 110, 110))
    d.line([cp(SIDE, lo), cp(SIDE, hi)], fill=(200, 0, 0))
    d.text((cp(SIDE, hi)[0] + 3, oy), "side zone's edge", font=font, fill=(200, 0, 0))
    for name, vals in series:
        pts = [cp(e, y) for e, y in enumerate(vals)]
        # voxel steps: each column flat across its node
        step = []
        for e, y in enumerate(vals):
            step += [cp(e - 0.5 if e else 0, y), cp(e + 0.5, y)]
        d.line(step, fill=COLOURS[name], width=3 if name in ("nature", "today", "before") else 2)
    d.text((ox, oy + ph - 12), "distance from the road's edge (nodes); 1 node across = 1 node up",
           font=font, fill=(0, 0, 0))
    for e in range(0, width, 6):
        d.text((cp(e, lo)[0] - 4, oy + ph - 30), str(e), font=font, fill=(110, 110, 110))
    ly = 34
    for name, _ in series:
        d.line([(10, ly + 8), (40, ly + 8)], fill=COLOURS[name], width=3)
        d.text((46, ly), LABELS[name], font=font, fill=(0, 0, 0))
        ly += 18
    d.text((10, Hh - 30), "top view: final ground (built), road grey, cut and fill columns tan, "
           "the section red", font=font, fill=(0, 0, 0))
    pic.save(os.path.join(pics, f"section-{seed}-{n}.png"))
print(f"{seed}: top view and {len(chosen)} sections")
