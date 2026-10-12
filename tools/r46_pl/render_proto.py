#!/usr/bin/env python3
"""Round 46 lane PL, design note: a quick picture of one seed's prototype
placement (tools/r46_pl/place_proto.lua), the whole map.

    python3 tools/r46_pl/render_proto.py PREFIX OUT_PNG

Zones in muted colours (Elandor blue-green, Kragmar red-orange, the front
sand), inland water dark blue, every fixed anchor as a white square, every
placed anchor as a dot in its kind's colour with a thin line to where the
same anchor stands today (source/simple_map.lua), and a ring when the row
needed a relaxation step. Needs Pillow. Not the user's review page: the
build extends tools/r31_m/render.py for that.
"""
import colorsys
import os
import re
import sys

from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
KIND = {
    "village": (255, 255, 255), "outpost": (80, 160, 255), "bandit_home": (230, 40, 40),
    "bandit_frontier": (230, 40, 40), "mine": (140, 90, 40), "mirefolk": (40, 200, 120),
    "clash": (255, 160, 0), "rare_route": (200, 80, 255), "pvp_fortress": (255, 255, 0),
    "pvp_camp_low": (255, 120, 200), "pvp_camp_high": (255, 60, 160),
}


def zone_colour(n):
    if n == 0:
        return (28, 48, 78)
    base = 0.58 if n <= 16 else (0.02 if n <= 32 else 0.13)
    h = (base + (n * 0.037) % 0.08) % 1.0
    s = 0.25 if n > 32 else 0.35
    v = 0.55 + (n % 4) * 0.06
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def today():
    """{anchor id: (x, z)} of the fixed source rows today."""
    text = open(os.path.join(REPO, "mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"),
                encoding="utf-8").read()
    rows = re.findall(r'^\s*\{(\d+),"(\w+)","(\w+)","(\w+)",(\d+),(-?\d+),(-?\d+)\},', text, re.M)
    return {"anchor_%03d" % (i + 1): (int(r[5]), int(r[6])) for i, r in enumerate(rows)}


def main():
    prefix, out_png = sys.argv[1], sys.argv[2]
    cells = [tuple(int(v) for v in line.split("\t")) for line in open(prefix + ".zones.tsv")]
    xs = sorted({c[0] for c in cells})
    zs = sorted({c[1] for c in cells})
    step = xs[1] - xs[0]
    scale = 2
    w, h = len(xs) * scale, len(zs) * scale
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)

    def px(x, z):
        return ((x - xs[0]) / step * scale, (zs[-1] - z) / step * scale)

    for x, z, n, wet in cells:
        u, v = px(x, z)
        d.rectangle([u, v, u + scale - 1, v + scale - 1],
                    fill=(30, 70, 150) if wet else zone_colour(n))
    old = today()
    for line in open(prefix + ".anchors.tsv"):
        aid, kind, slot, x, z, zone, step_used, _ = line.rstrip("\n").split("\t")
        u, v = px(int(x), int(z))
        if step_used == "fixed":
            d.rectangle([u - 3, v - 3, u + 3, v + 3], outline=(255, 255, 255))
            continue
        if aid in old:
            ou, ov = px(*old[aid])
            d.line([ou, ov, u, v], fill=(0, 0, 0), width=1)
        colour = KIND.get(kind, (255, 255, 255))
        d.ellipse([u - 3, v - 3, u + 3, v + 3], fill=colour, outline=(0, 0, 0))
        if step_used != "1":
            d.ellipse([u - 6, v - 6, u + 6, v + 6], outline=(255, 0, 0))
    img.save(out_png)


if __name__ == "__main__":
    main()
