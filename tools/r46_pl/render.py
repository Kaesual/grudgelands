#!/usr/bin/env python3
"""Round 46 lane PL: pictures and facts of one seed's POI placement
(tools/r46_pl/overview.lua) for the user's review page.

    python3 tools/r46_pl/render.py PREFIX OUT_DIR NAME [--title TEXT]
                                    [--short TEXT] [--caption TEXT]

PREFIX is overview.lua's OUT_PREFIX (its .zones.tsv, .rivers.tsv,
.anchors.tsv and, when present, .roads.tsv; the design note's prototype
wrote the same files without roads). Writes to OUT_DIR:
  NAME_map.png     the whole map, about 1200 px wide: zones (thin darker
                   borders), inland water and rivers, the fixed anchors as
                   white outlines, every placed POI as its kind's glyph,
                   relaxed rows ringed in red with their step;
  NAME_accord.png, NAME_throng.png, NAME_front.png
                   2x crops (Highcourt and its neighbours, Gor Drazhak and
                   its neighbours, the front with both fortresses and the
                   two middle Battlegrounds zones), POIs numbered by anchor;
  NAME_facts.md    relaxed rows, the smallest PvP spacing, fortress and war
                   camp positions, the smallest distance of a placed POI to a
                   start town and to a capital;
  NAME_anchors.tsv a copy of the anchor rows (the key to the numbers).
Roads and trails are drawn when the roads file is there. Needs Pillow.
"""
import argparse
import colorsys
import math
import os
import re
import shutil

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
EXTENT = (-3600, -3200, 3600, 3200)      # x0, z0, x1, z1 of the full map
CROPS = {
    "accord": ("Accord capital region", "Highcourt and its neighbours.", (-1000, -2300, 1000, -700)),
    "throng": ("Throng capital region", "Gor Drazhak and its neighbours.", (-1000, 700, 1000, 2300)),
    "front": ("The front", "Both fortresses (Ashenward March, Bannerbreak Mesa) and the war camps "
              "of the Broken Causeway and the Shattered Line.", (-1500, -850, 1500, 850)),
}
MAP_WIDTH = 1200
CAPTION = ("Roads (light) and trails (thin) as routed after placement; the capitals' "
           "streets are not drawn.")

# kind -> (legend name, shape, fill colour)
KINDS = {
    "village": ("Village", "square", (255, 255, 255)),
    "outpost": ("Outpost", "tri_up", (70, 150, 255)),
    "bandit_home": ("Bandit camp", "cross", (235, 40, 40)),
    "bandit_frontier": ("Bandit camp", "cross", (235, 40, 40)),
    "mirefolk": ("Mirefolk camp", "diamond", (40, 210, 120)),
    "mine": ("Mine", "tri_down", (205, 125, 50)),
    "clash": ("Clash site", "plus", (255, 175, 0)),
    "rare_route": ("Rare den", "circle_small", (190, 90, 255)),
    "pvp_fortress": ("Fortress", "square_big", (255, 240, 0)),
    "pvp_camp_low": ("War camp (lower)", "circle", (255, 150, 205)),
    "pvp_camp_high": ("War camp (higher)", "circle", (215, 30, 150)),
}
FIXED_NAMES = {"start": "Start town (fixed)", "capital": "Capital (fixed)",
               "dragon": "Dragon arena (fixed)", "apex_mine": "Apex mine (fixed)",
               "clash": "Rift site (fixed clash site)"}


def font(size, bold=True):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    for path in ("/usr/share/fonts/dejavu-sans-fonts/" + name, name):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


def zone_rows():
    text = open(os.path.join(REPO, "mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"),
                encoding="utf-8").read()
    return {int(m.group(1)): m.group(3) for m in re.finditer(r'zone\((\d+),"(\w+)","([^"]+)"', text)}


def zone_colour(n):
    if n == 0:
        return (28, 48, 78)
    base = 0.58 if n <= 16 else (0.02 if n <= 32 else 0.13)
    h = (base + (n * 0.037) % 0.08) % 1.0
    s = 0.22 if n > 32 else 0.30
    v = 0.50 + (n % 4) * 0.06
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def load_roads(prefix):
    roads = []
    if os.path.exists(prefix + ".roads.tsv"):
        for line in open(prefix + ".roads.tsv"):
            parts = line.rstrip("\n").split("\t")
            roads.append((parts[1], [tuple(int(v) for v in p.split()) for p in parts[2:]]))
    return roads


def draw_roads(img, view, roads):
    d = ImageDraw.Draw(img)
    big = view.scale > 0.3
    for kind, pts in roads:
        xy = [view.px(x, z) for x, z in pts]
        if len(xy) < 2:
            continue
        if kind == "trail":
            d.line(xy, fill=(200, 180, 140), width=2 if big else 1)
        else:
            d.line(xy, fill=(245, 225, 170), width=3 if big else 2)


def load(prefix):
    cells = {}
    for line in open(prefix + ".zones.tsv"):
        x, z, n, wet = (int(v) for v in line.split("\t"))
        cells[(x, z)] = (n, wet)
    rivers = []
    for line in open(prefix + ".rivers.tsv"):
        parts = line.rstrip("\n").split("\t")
        rivers.append([tuple(int(v) for v in p.split()) for p in parts[1:]])
    anchors = []
    for line in open(prefix + ".anchors.tsv"):
        f = line.rstrip("\n").split("\t")
        anchors.append({"id": f[0], "kind": f[1], "slot": f[2], "x": int(f[3]), "z": int(f[4]),
                        "zone": int(f[5]), "step": f[6], "count": int(f[7]),
                        "level": int(f[8]), "half": int(f[9]), "label": f[10]})
    return cells, rivers, anchors


class View:
    """World rectangle -> image pixels at `scale` pixels per node."""

    def __init__(self, rect, scale, top):
        self.x0, self.z0, self.x1, self.z1 = rect
        self.scale, self.top = scale, top

    def px(self, x, z):
        return ((x - self.x0) * self.scale, self.top + (self.z1 - z) * self.scale)

    def size(self):
        return (int((self.x1 - self.x0) * self.scale), int((self.z1 - self.z0) * self.scale))


def draw_terrain(img, view, cells, rivers, zones=None):
    step = 16
    d = ImageDraw.Draw(img)
    for (x, z), (n, wet) in cells.items():
        if not (view.x0 <= x < view.x1 and view.z0 <= z < view.z1):
            continue
        u, v = view.px(x, z + step)
        colour = (40, 90, 170) if wet else zone_colour(n)
        if n and not wet:
            right, up = cells.get((x + step, z)), cells.get((x, z + step))
            if (right and right[0] and right[0] != n) or (up and up[0] and up[0] != n):
                colour = tuple(int(c * 0.6) for c in colour)
        e = step * view.scale
        d.rectangle([u, v, u + e, v + e], fill=colour)
    width = 1 if view.scale < 0.3 else 2
    for run in rivers:
        pts = [view.px(x, z) for x, z in run]
        if len(pts) > 1:
            d.line(pts, fill=(40, 90, 170), width=width)
    if zones:
        # zone names at the mean of their visible cells
        sums = {}
        for (x, z), (n, wet) in cells.items():
            if n and view.x0 <= x < view.x1 and view.z0 <= z < view.z1:
                s = sums.setdefault(n, [0, 0, 0])
                s[0] += x
                s[1] += z
                s[2] += 1
        f = font(13, False)
        for n, (sx, sz, c) in sorted(sums.items()):
            if c < 150:
                continue
            u, v = view.px(sx / c, sz / c)
            text = zones.get(n, str(n))
            w = d.textlength(text, font=f)
            d.text((u - w / 2, v - 30), text, font=f, fill=(235, 235, 235),
                   stroke_width=2, stroke_fill=(20, 20, 20))


def glyph(d, shape, u, v, r, fill, outline=(0, 0, 0), hollow=False):
    fc = None if hollow else fill
    oc = fill if hollow else outline
    w = 2 if hollow else 1
    if shape in ("square", "square_big"):
        r = r * 1.3 if shape == "square_big" else r
        d.rectangle([u - r, v - r, u + r, v + r], fill=fc, outline=oc, width=w)
    elif shape == "tri_up":
        d.polygon([(u, v - r * 1.2), (u - r, v + r * 0.8), (u + r, v + r * 0.8)], fill=fc, outline=oc)
    elif shape == "tri_down":
        d.polygon([(u, v + r * 1.2), (u - r, v - r * 0.8), (u + r, v - r * 0.8)], fill=fc, outline=oc)
    elif shape == "diamond":
        d.polygon([(u, v - r * 1.2), (u + r * 1.2, v), (u, v + r * 1.2), (u - r * 1.2, v)],
                  fill=fc, outline=oc)
    elif shape == "cross":
        t = max(2, int(r / 2))
        d.line([u - r, v - r, u + r, v + r], fill=(0, 0, 0), width=t + 2)
        d.line([u - r, v + r, u + r, v - r], fill=(0, 0, 0), width=t + 2)
        d.line([u - r, v - r, u + r, v + r], fill=fill, width=t)
        d.line([u - r, v + r, u + r, v - r], fill=fill, width=t)
    elif shape == "plus":
        t = max(2, int(r / 2))
        if hollow:
            d.line([u - r, v, u + r, v], fill=fill, width=t)
            d.line([u, v - r, u, v + r], fill=fill, width=t)
            d.ellipse([u - r - 2, v - r - 2, u + r + 2, v + r + 2], outline=fill, width=2)
        else:
            d.line([u - r - 1, v, u + r + 1, v], fill=(0, 0, 0), width=t + 2)
            d.line([u, v - r - 1, u, v + r + 1], fill=(0, 0, 0), width=t + 2)
            d.line([u - r, v, u + r, v], fill=fill, width=t)
            d.line([u, v - r, u, v + r], fill=fill, width=t)
    elif shape == "circle_small":
        r = r * 0.75
        d.ellipse([u - r, v - r, u + r, v + r], fill=fc, outline=oc, width=w)
    else:
        d.ellipse([u - r, v - r, u + r, v + r], fill=fc, outline=oc, width=w)


FIXED_SHAPE = {"start": "square", "capital": "square_big", "dragon": "circle",
               "apex_mine": "tri_up", "clash": "plus"}


def draw_anchors(img, view, anchors, r, numbers=False):
    d = ImageDraw.Draw(img)
    small = font(max(10, int(r * 1.6)))
    for a in anchors:
        u, v = view.px(a["x"], a["z"])
        if not (0 <= u <= img.size[0] and view.top <= v <= img.size[1]):
            continue
        if a["step"] == "fixed":
            kind = a["slot"] if a["slot"] in ("start", "capital") else a["kind"]
            shape = FIXED_SHAPE.get(kind, "circle")
            size = r * (2.2 if kind == "capital" else 1.6 if kind == "start" else 1.3)
            glyph(d, shape, u, v, size, (255, 255, 255), hollow=True)
            if numbers:
                d.text((u + size + 3, v - size - 2), a["label"], font=small, fill=(255, 255, 255),
                       stroke_width=2, stroke_fill=(0, 0, 0))
            continue
        name, shape, colour = KINDS.get(a["kind"], ("?", "circle", (255, 255, 255)))
        glyph(d, shape, u, v, r, colour)
        relaxed = a["step"] not in ("1", "today")
        if relaxed:
            rr = r * 2.0
            d.ellipse([u - rr, v - rr, u + rr, v + rr], outline=(255, 30, 30), width=2)
            d.text((u + rr, v + rr - 4), a["step"], font=small, fill=(255, 60, 60),
                   stroke_width=2, stroke_fill=(0, 0, 0))
        if numbers:
            d.text((u + r + 2, v - r - 4), a["id"][-3:].lstrip("0"), font=small,
                   fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))


def legend(img, top, r):
    d = ImageDraw.Draw(img)
    f = font(14, False)
    seen, items = set(), []
    for kind, (name, shape, colour) in KINDS.items():
        if name not in seen:
            seen.add(name)
            items.append((name, shape, colour, False))
    for kind, name in FIXED_NAMES.items():
        items.append((name, FIXED_SHAPE[kind], (255, 255, 255), True))
    items.append(("Relaxed row (red ring, step)", "ring", (255, 30, 30), False))
    cols, col_w, row_h = 4, img.size[0] // 4, 24
    for i, (name, shape, colour, hollow) in enumerate(items):
        u = 16 + (i % cols) * col_w
        v = top + 14 + (i // cols) * row_h
        if shape == "ring":
            d.ellipse([u - 9, v - 9, u + 9, v + 9], outline=colour, width=2)
        else:
            glyph(d, shape, u, v, r, colour, hollow=hollow)
        d.text((u + 16, v - 9), name, font=f, fill=(230, 230, 230))
    return top + 14 + ((len(items) + cols - 1) // cols) * row_h


HEAD = 74


def header(d, width, title, subtitle):
    """Title and a subtitle wrapped onto at most two lines."""
    d.rectangle([0, 0, width, HEAD], fill=(16, 22, 34))
    d.text((12, 6), title, font=font(18), fill=(255, 255, 255))
    f = font(13, False)
    lines, line = [], ""
    for word in subtitle.split():
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) > width - 24 and line:
            lines.append(line)
            line = word
        else:
            line = trial
    lines.append(line)
    for i, text in enumerate(lines[:2]):
        d.text((12, 32 + i * 18), text, font=f, fill=(200, 200, 200))


def render_map(cells, rivers, anchors, path, title, roads=()):
    scale = MAP_WIDTH / (EXTENT[2] - EXTENT[0])
    view = View(EXTENT, scale, HEAD)
    w, h = view.size()
    img = Image.new("RGB", (w, h + HEAD + 150), (16, 22, 34))
    draw_terrain(img, view, cells, rivers)
    draw_roads(img, view, roads)
    draw_anchors(img, view, anchors, 4.5)
    d = ImageDraw.Draw(img)
    header(d, w, title, CAPTION + " White outlines: fixed anchors. Zone borders darker.")
    bottom = legend(img, h + HEAD + 4, 6)
    img.crop((0, 0, w, bottom + 6)).save(path)


def render_crop(cells, rivers, anchors, zones, path, title, detail, rect, roads=()):
    scale = 2 * MAP_WIDTH / (EXTENT[2] - EXTENT[0])
    view = View(rect, scale, HEAD)
    w, h = view.size()
    img = Image.new("RGB", (w, h + HEAD), (16, 22, 34))
    draw_terrain(img, view, cells, rivers, zones)
    draw_roads(img, view, roads)
    draw_anchors(img, view, anchors, 7, numbers=True)
    header(ImageDraw.Draw(img), w, title, detail + " 2x crop; numbers are anchor numbers "
           "(see the anchors file). " + CAPTION)
    img.save(path)


def facts(anchors, zones, path, title):
    placed = [a for a in anchors if a["step"] != "fixed"]
    starts = [a for a in anchors if a["slot"] == "start"]
    caps = [a for a in anchors if a["slot"] == "capital"]

    def gap(a, b):
        return max(abs(a["x"] - b["x"]), abs(a["z"] - b["z"])) - a["half"] - b["half"]

    def dist(a, b):
        return math.hypot(a["x"] - b["x"], a["z"] - b["z"])

    def name(a):
        return "%s %s (%s, %s)" % (a["id"], a["label"], a["kind"], zones.get(a["zone"], a["zone"]))

    out = ["# %s" % title, "", CAPTION, ""]
    relaxed = [a for a in placed if a["step"] not in ("1", "today")]
    out.append("Placed rows: %d; relaxed: %d." % (len(placed), len(relaxed)))
    out.append("")
    if relaxed:
        out += ["## Relaxed rows", "", "| Anchor | Label | Kind | Zone | Step |", "|---|---|---|---|---:|"]
        for a in relaxed:
            out.append("| %s | %s | %s | %s | %s |" % (a["id"], a["label"], a["kind"],
                                                      zones.get(a["zone"]), a["step"]))
        out.append("")
    pvp = [a for a in placed if a["kind"].startswith("pvp_")]
    best = None
    for i, a in enumerate(pvp):
        for b in pvp[i + 1:]:
            if best is None or dist(a, b) < best[0]:
                best = (dist(a, b), a, b)
    if best:
        out += ["## Smallest PvP spacing", "",
                "%.0f nodes (centre to centre) between %s and %s." % (best[0], name(best[1]),
                                                                     name(best[2])), ""]
    out += ["## Fortresses and war camps", "",
            "| Anchor | Label | Zone | x | z | Level at centre | Step |",
            "|---|---|---|---:|---:|---:|---:|"]
    for a in pvp:
        out.append("| %s | %s | %s | %d | %d | %d | %s |" % (a["id"], a["label"], zones.get(a["zone"]),
                                                          a["x"], a["z"], a["level"], a["step"]))
    out.append("")
    out += ["## Nearest placed POI to a start town and to a capital", "",
            "Gap: between the POI's fitting square and the start's 152 town square or the "
            "capital's 532 reserved square (the rule keeps at least 128).", ""]
    for label, group in (("Start town", starts), ("Capital", caps)):
        g = min(((gap(a, b), a, b) for a in placed for b in group), key=lambda t: t[0])
        c = min(((dist(a, b), a, b) for a in placed for b in group), key=lambda t: t[0])
        out.append("- %s, smallest gap: %d nodes, %s to %s." % (label, g[0], name(g[1]), g[2]["label"]))
        out.append("- %s, smallest centre distance: %.0f nodes, %s to %s." % (label, c[0], name(c[1]),
                                                                            c[2]["label"]))
    out.append("")
    open(path, "w", encoding="utf-8").write("\n".join(out))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("prefix")
    p.add_argument("out_dir")
    p.add_argument("name")
    p.add_argument("--title", default=None)
    p.add_argument("--short", default=None, help="the crops' title prefix")
    p.add_argument("--caption", default=None, help="replaces the roads caption")
    args = p.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)
    global CAPTION
    if args.caption:
        CAPTION = args.caption
    cells, rivers, anchors = load(args.prefix)
    roads = load_roads(args.prefix)
    zones = zone_rows()
    title = args.title or args.name
    base = os.path.join(args.out_dir, args.name)
    render_map(cells, rivers, anchors, base + "_map.png", title, roads)
    for key, (label, detail, rect) in CROPS.items():
        render_crop(cells, rivers, anchors, zones, base + "_%s.png" % key,
                    "%s: %s" % (args.short or title, label), detail, rect, roads)
    facts(anchors, zones, base + "_facts.md", title)
    shutil.copyfile(args.prefix + ".anchors.tsv", base + "_anchors.tsv")


if __name__ == "__main__":
    main()
