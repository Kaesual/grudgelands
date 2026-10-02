#!/usr/bin/env python3
"""Round 28 Lane W1: draw the world view of one seed.

Reads <dump>/world_<seed>.json and .bin (tools/r28_world/world.lua) and
writes <out>/<name>_seed_<seed>.png and .md:
  * every land cell coloured by its spawn region's level (the middle of the
    region's belt) on one blue ramp, 1 light to 60 dark; thin lines between
    belts inside a zone, each belt patch labelled with its levels;
  * zone borders coloured by the level fit across them (borders.lua): green
    fit (gap <= 1), yellow step (gap 2-5), red jump (gap > 5), magenta forced
    (the two zones' bands are more than 5 apart), grey where a side has no
    recipe;
  * capitals (diamond) and start towns (circle) with names, zone names with
    their bands;
  * a side panel: legend, border length per class, the red and yellow
    borders; the .md file lists every red, yellow and forced border with its
    zone pair, length and the level ranges on both sides.

Usage: render.py --dump DIR --seed SEED --out DIR --name current|proposed
Python 3 + numpy + Pillow.
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_DIR = Path("/usr/share/fonts/dejavu-sans-fonts")
ATLAS = Path(__file__).resolve().parents[2] / "docs" / "planning" / "round28" / "zones"
PX = 3            # pixels per raster sample (8 nodes): 8/3 nodes per pixel
LEFT, TOP, BOTTOM, PANEL = 16, 64, 16, 820

# The reference palette's sequential blue ramp (steps 100..700), levels 1..60.
RAMP = ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5",
        "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b"]
SEA = (218, 219, 220)
INLAND = (198, 200, 203)
UNMAPPED = (247, 244, 234)     # land no region covers (coast fringes, islets)
NO_RECIPE = (176, 174, 168)
INK = (11, 11, 11)
INK2 = (82, 81, 78)
CLASS_RGB = {
    "fit": (12, 163, 12),       # status good
    "step": (250, 178, 25),     # status warning
    "jump": (208, 59, 59),      # status critical
    "forced": (224, 56, 156),   # magenta: no recipe can close it
    "none": (137, 135, 129),
}
CLASS_TEXT = {
    "fit": "fit: gap <= 1 (ranges overlap or touch)",
    "step": "step: gap 2-5",
    "jump": "jump: gap > 5",
    "forced": "forced: the zones' bands lie > 5 apart",
    "none": "a side without recipe",
}
DRAW_ORDER = ["none", "fit", "forced", "step", "jump"]


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


RAMP_RGB = [hex_rgb(h) for h in RAMP]


def level_rgb(level):
    t = (min(60.0, max(1.0, level)) - 1.0) / 59.0 * (len(RAMP_RGB) - 1)
    a = int(t)
    b = min(a + 1, len(RAMP_RGB) - 1)
    f = t - a
    return tuple(int(round(RAMP_RGB[a][k] + (RAMP_RGB[b][k] - RAMP_RGB[a][k]) * f)) for k in range(3))


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(str(FONT_DIR / name), size)
    except OSError:
        return ImageFont.load_default()


def text_halo(d, xy, text, fnt, fill=INK, halo=(255, 255, 255)):
    x, y = xy
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((x + dx, y + dy), text, font=fnt, fill=halo)
    d.text((x, y), text, font=fnt, fill=fill)


def lv(lo, hi):
    return "L%d" % lo if lo == hi else "L%d-%d" % (lo, hi)


def border_groups(doc):
    """Edges grouped by zone pair (sorted ids), class and the level ranges on
    both sides: [{a, b, class, a_range, b_range, length}], longest first."""
    zones = doc["zones"]
    cell = doc["cell"]
    groups = defaultdict(int)
    for i, j, side, a, b, alo, ahi, blo, bhi, gap, band_gap, cls in doc["edges"]:
        za, zb = zones[a - 1]["id"], zones[b - 1]["id"]
        ra = (alo, ahi) if alo is not False else None
        rb = (blo, bhi) if blo is not False else None
        if zb < za:
            za, zb, ra, rb = zb, za, rb, ra
        groups[(za, zb, cls, ra, rb)] += cell
    out = [{"a": k[0], "b": k[1], "class": k[2], "a_range": k[3], "b_range": k[4], "length": n}
           for k, n in groups.items()]
    out.sort(key=lambda g: (-g["length"], g["a"], g["b"], str(g["a_range"]), str(g["b_range"])))
    return out


def pair_totals(doc):
    """{(a, b): {class: length}} per zone pair (sorted ids)."""
    zones = doc["zones"]
    out = defaultdict(lambda: defaultdict(int))
    for e in doc["edges"]:
        za, zb = sorted((zones[e[3] - 1]["id"], zones[e[4] - 1]["id"]))
        out[(za, zb)][e[11]] += doc["cell"]
    return out


def range_text(r):
    return lv(r[0], r[1]) if r else "no recipe"


def gap_of(g):
    if not g["a_range"] or not g["b_range"]:
        return None
    (alo, ahi), (blo, bhi) = g["a_range"], g["b_range"]
    return max(0, blo - ahi, alo - bhi)


def entry_text(zone):
    frm, to = zone.get("from") or {}, zone.get("to") or {}

    def names(v):
        return ", ".join([v] if isinstance(v, str) else v)
    parts = []
    if frm.get("anchor"):
        parts.append("anchor " + names(frm["anchor"]))
    if frm.get("border"):
        parts.append("border " + names(frm["border"]))
    src = " + ".join(parts) or "-"
    if to.get("core"):
        dst = "core"
    elif to.get("border"):
        dst = "border " + names(to["border"])
    else:
        dst = "-"
    return src, dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", required=True, help="current or proposed (file prefix and title)")
    args = ap.parse_args()
    dump = Path(args.dump)
    doc = json.load(open(dump / ("world_%s.json" % args.seed)))
    fr = doc["frame"]
    step, cols, rows = fr["step"], fr["cols"], fr["rows"]
    cell = doc["cell"]
    per = cell // step          # raster samples per cell side
    raw = np.fromfile(dump / ("world_%s.bin" % args.seed), dtype=np.uint8).reshape(rows, cols, 2)
    water = raw[..., 0]
    zidx = raw[..., 1].astype(np.int32)
    land = water == 1
    zones = doc["zones"]
    for z in zones:
        for key in ("cells", "belts", "regions", "leaders", "problems", "warnings"):
            if not z.get(key):
                z[key] = []

    # Per raster sample: the level (middle of the region's belt), the patch
    # key (zone, belt) and whether a recipe covers it.
    level = np.full((rows, cols), -1.0)
    patch = np.zeros((rows, cols), dtype=np.int32)
    norec = np.zeros((rows, cols), dtype=bool)
    ci0, cj0 = fr["x0"] // cell, fr["z0"] // cell
    for zn, z in enumerate(zones, start=1):
        for c in z["cells"]:
            r0, c0 = (c[1] - cj0) * per, (c[0] - ci0) * per
            if r0 < 0 or c0 < 0 or r0 >= rows or c0 >= cols:
                continue
            if z.get("recipe"):
                level[r0:r0 + per, c0:c0 + per] = (c[2] + c[3]) / 2.0
                patch[r0:r0 + per, c0:c0 + per] = zn * 100 + c[4]
            else:
                norec[r0:r0 + per, c0:c0 + per] = True
    rgb = np.zeros((rows, cols, 3), dtype=np.uint8)
    rgb[:] = SEA
    rgb[water == 3] = INLAND
    rgb[land] = UNMAPPED
    lut = np.array([level_rgb(1 + k * 0.5) for k in range(119)], dtype=np.uint8)
    have = land & (level >= 0)
    rgb[have] = lut[np.clip(((level[have] - 1) * 2).round().astype(int), 0, 118)]
    nr = land & norec
    hatch = ((np.add.outer(np.arange(rows), np.arange(cols)) // 2) % 4 == 0)
    rgb[nr] = NO_RECIPE
    rgb[nr & hatch] = (160, 158, 152)
    # Thin lines: between belts inside a zone (secondary ink), and the zone
    # outline at raster resolution (primary ink) where land meets land.
    belt_edge = np.zeros((rows, cols), dtype=bool)
    zone_edge = np.zeros((rows, cols), dtype=bool)
    zl = np.where(land, zidx, 0)
    for axis in (0, 1):
        pa = np.roll(patch, 1, axis=axis)
        za = np.roll(zl, 1, axis=axis)
        same_zone = (pa // 100) == (patch // 100)
        belt_edge |= (pa != patch) & (pa > 0) & (patch > 0) & same_zone
        zone_edge |= (za != zl) & (za > 0) & (zl > 0)
    rgb[belt_edge] = (rgb[belt_edge] * 0.55).astype(np.uint8)
    rgb[zone_edge] = INK2
    img_map = Image.fromarray(np.flipud(rgb)).resize((cols * PX, rows * PX), Image.NEAREST)
    W, H = cols * PX, rows * PX

    canvas = Image.new("RGB", (LEFT + W + PANEL, TOP + H + BOTTOM), (252, 252, 251))
    canvas.paste(img_map, (LEFT, TOP))
    d = ImageDraw.Draw(canvas)
    scale = PX / step

    def px(x, z):
        return LEFT + (x - fr["x0"]) * scale, TOP + (fr["z1"] - z) * scale

    # Border edges: a dark casing, then the class colour, worst on top.
    segs = defaultdict(list)
    for i, j, side, a, b, alo, ahi, blo, bhi, gap, band_gap, cls in doc["edges"]:
        if side == "e":
            p, q = px((i + 1) * cell, j * cell), px((i + 1) * cell, (j + 1) * cell)
        else:
            p, q = px(i * cell, (j + 1) * cell), px((i + 1) * cell, (j + 1) * cell)
        segs[cls].append((p, q))
    for cls in DRAW_ORDER:
        for p, q in segs[cls]:
            d.line([p, q], fill=INK, width=8)
    for cls in DRAW_ORDER:
        for p, q in segs[cls]:
            d.line([p, q], fill=CLASS_RGB[cls], width=6)

    f_tiny, f_small, f_bold, f_zone, f_title = (font(11), font(12), font(13, True), font(16, True),
                                                font(24, True))
    f_list, f_panel, f_head = font(13), font(14), font(15, True)
    # Labels avoid each other: the places first, then the zone names (moved
    # up or down from the zone's centre when they would cover a place), then
    # the belt labels (at the patch's cell nearest its centroid, or the next
    # nearest that is free; a patch with no free cell stays unlabelled).
    taken = []

    def free(box):
        return all(box[2] < t[0] or box[0] > t[2] or box[3] < t[1] or box[1] > t[3] for t in taken)

    def clamp_x(x, tw):
        return min(max(LEFT + 2, x), LEFT + W - tw - 2)

    for p in doc["places"]:
        x, y = px(p["x"], p["z"])
        if p["slot"] == "capital":
            d.polygon([(x, y - 9), (x + 9, y), (x, y + 9), (x - 9, y)], fill=(255, 255, 255),
                      outline=INK, width=2)
            d.polygon([(x, y - 4), (x + 4, y), (x, y + 4), (x - 4, y)], fill=INK)
        else:
            d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 255, 255), outline=INK, width=2)
        tw, th = d.textbbox((0, 0), p["name"], font=f_bold)[2:]
        tx = x + 12 if x + 12 + tw < LEFT + W - 2 else x - 12 - tw
        text_halo(d, (tx, y - th / 2 - 1), p["name"], f_bold)
        taken.append((min(x - 10, tx) - 2, y - 10, max(x + 10, tx + tw) + 2, y + 10))
    for z in zones:
        if not z["cells"]:
            continue
        mi = sum(c[0] for c in z["cells"]) / len(z["cells"])
        mj = sum(c[1] for c in z["cells"]) / len(z["cells"])
        best = min(z["cells"], key=lambda c: ((c[0] - mi) ** 2 + (c[1] - mj) ** 2, c[0], c[1]))
        cx, cy = px(best[0] * cell + cell / 2, best[1] * cell + cell / 2)
        name = z["name"] + ("" if z.get("recipe") else " (no recipe)")
        band = "zone %d-%d" % (z["band"][0], z["band"][1])
        w1, h1 = d.textbbox((0, 0), name, font=f_zone)[2:]
        w2 = d.textbbox((0, 0), band, font=f_small)[2]
        tw = max(w1, w2)
        th = h1 + 16
        for dy in (0, -40, 40, -80, 80, -120, 120):
            x = clamp_x(cx - tw / 2, tw)
            y = cy + dy - th / 2
            box = (x - 2, y - 2, x + tw + 2, y + th + 2)
            if free(box):
                break
        taken.append(box)
        text_halo(d, (clamp_x(cx - w1 / 2, w1), y), name, f_zone)
        text_halo(d, (clamp_x(cx - w2 / 2, w2), y + h1 + 2), band, f_small)
    for zn, z in enumerate(zones, start=1):
        if not z.get("recipe"):
            continue
        cells = {(c[0], c[1]): (c[4], c[2], c[3]) for c in z["cells"]}
        seen = set()
        for start in sorted(cells):
            if start in seen:
                continue
            belt = cells[start][0]
            comp, stack = [], [start]
            seen.add(start)
            while stack:
                cur = stack.pop()
                comp.append(cur)
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nb = (cur[0] + di, cur[1] + dj)
                    if nb in cells and nb not in seen and cells[nb][0] == belt:
                        seen.add(nb)
                        stack.append(nb)
            if len(comp) < 6:
                continue
            mi = sum(c[0] for c in comp) / len(comp)
            mj = sum(c[1] for c in comp) / len(comp)
            lo, hi = cells[comp[0]][1], cells[comp[0]][2]
            t = lv(lo, hi)
            tw, th = d.textbbox((0, 0), t, font=f_tiny)[2:]
            for c in sorted(comp, key=lambda c: ((c[0] - mi) ** 2 + (c[1] - mj) ** 2, c))[:40]:
                x, y = px(c[0] * cell + cell / 2, c[1] * cell + cell / 2)
                box = (x - tw / 2 - 2, y - th / 2 - 2, x + tw / 2 + 2, y + th / 2 + 2)
                if free(box):
                    taken.append(box)
                    text_halo(d, (x - tw / 2, y - th / 2), t, f_tiny)
                    break

    title = "Spawn levels across the mainland - seed %s - %s recipes" % (
        args.seed, "proposed (border rule)" if args.name == "proposed" else args.name)
    d.text((LEFT, 12), title, font=f_title, fill=INK)
    d.text((LEFT, 42), "north up; one belt cell = 32 nodes; the two dragon islands (one belt, L60, no land "
           "border) are left out", font=f_small, fill=INK2)

    # Side panel.
    totals = {c: 0 for c in CLASS_RGB}
    for e in doc["edges"]:
        totals[e[11]] += cell
    groups = border_groups(doc)
    x0 = LEFT + W + 24
    y = TOP
    d.text((x0, y), "Level of the spawn region (middle of its belt)", font=f_head, fill=INK)
    y += 26
    bar_w = PANEL - 60
    for k in range(bar_w):
        d.line([(x0 + k, y), (x0 + k, y + 20)], fill=level_rgb(1 + 59.0 * k / (bar_w - 1)))
    d.rectangle([x0, y, x0 + bar_w, y + 20], outline=INK2)
    for t in (1, 10, 20, 30, 40, 50, 60):
        tx = x0 + (t - 1) / 59.0 * (bar_w - 1)
        d.line([(tx, y + 20), (tx, y + 25)], fill=INK)
        tw = d.textbbox((0, 0), str(t), font=f_panel)[2]
        d.text((tx - tw / 2, y + 27), str(t), font=f_panel, fill=INK)
    y += 52
    for rgbc, t in ((NO_RECIPE, "zone without a recipe (today's palette)"),
                    (UNMAPPED, "land no region covers (coast fringes, islets)"),
                    (SEA, "sea"), (INLAND, "river or lake")):
        d.rectangle([x0, y, x0 + 22, y + 14], fill=rgbc, outline=INK2)
        d.text((x0 + 30, y), t, font=f_panel, fill=INK)
        y += 24
    y += 10
    classified = sum(totals.values()) or 1
    d.text((x0, y), "Zone borders: level fit across them", font=f_head, fill=INK)
    y += 26
    for cls in ("fit", "step", "jump", "forced", "none"):
        d.rectangle([x0, y + 4, x0 + 22, y + 10], fill=CLASS_RGB[cls], outline=INK)
        d.text((x0 + 30, y), "%s  %d nodes (%.0f %%)" % (CLASS_TEXT[cls], totals[cls],
                                                       100.0 * totals[cls] / classified),
               font=f_panel, fill=INK)
        y += 22
    d.text((x0, y + 2), "gap = distance between the two regions' level ranges", font=f_panel, fill=INK2)
    y += 24
    d.text((x0, y), "thin dark lines: belts inside a zone; labels: belt levels", font=f_panel, fill=INK2)
    y += 22
    d.ellipse([x0 + 5, y + 2, x0 + 15, y + 12], fill=(255, 255, 255), outline=INK, width=2)
    d.text((x0 + 30, y), "start town", font=f_panel, fill=INK)
    d.polygon([(x0 + 160, y), (x0 + 167, y + 7), (x0 + 160, y + 14), (x0 + 153, y + 7)],
              fill=(255, 255, 255), outline=INK, width=2)
    d.text((x0 + 175, y), "capital", font=f_panel, fill=INK)
    y += 30

    names = {z["id"]: z["name"] for z in zones}

    def listing(cls, heading, limit):
        nonlocal y
        rows_ = [g for g in groups if g["class"] == cls]
        d.text((x0, y), "%s (%d nodes)" % (heading, totals[cls]), font=f_head, fill=CLASS_RGB[cls]
               if cls != "step" else (150, 100, 0))
        y += 22
        if not rows_:
            d.text((x0 + 8, y), "none", font=f_panel, fill=INK2)
            y += 20
        for g in rows_[:limit]:
            t = "%4d  %s %s | %s %s" % (g["length"], names[g["a"]], range_text(g["a_range"]),
                                        names[g["b"]], range_text(g["b_range"]))
            d.text((x0 + 8, y), t, font=f_list, fill=INK)
            y += 18
        if len(rows_) > limit:
            d.text((x0 + 8, y), "+ %d more (see the .md file)" % (len(rows_) - limit), font=f_list,
                   fill=INK2)
            y += 18
        y += 10

    room = (TOP + H - y) // 18 - 12
    listing("jump", "Red borders: nodes, zone and range | zone and range", max(8, room * 3 // 5))
    room = (TOP + H - y) // 18 - 4
    listing("step", "Yellow borders", max(4, room))
    canvas.save(Path(args.out) / ("%s_seed_%s.png" % (args.name, args.seed)), optimize=True)

    # The stats file.
    md = []
    md.append("# Spawn levels across the mainland: seed %s, %s recipes\n" % (args.seed, args.name))
    src = ("the border rule's recipe copies (`border_rule.py --out`; a zone without a copy keeps its "
           "shipped file)" if doc.get("proposal") else "the shipped recipes")
    md.append("Built with `tools/r28_world/run.sh` from %s (one world build, every mainland zone's "
              "region map through the game's `spawn_regions_core.lua`). The two dragon islands are "
              "left out (one belt, L60, no land border). Border edges are sides shared by land cells "
              "(32 nodes each) of two zones; the gap is the distance between the two regions' level "
              "ranges.\n" % src)
    md.append("## Border length per class\n")
    md.append("| class | meaning | nodes | share |")
    md.append("|---|---|---:|---:|")
    for cls in ("fit", "step", "jump", "forced", "none"):
        md.append("| %s | %s | %d | %.1f %% |" % (cls, CLASS_TEXT[cls], totals[cls],
                                                100.0 * totals[cls] / classified))
    md.append("| total | | %d | |\n" % sum(totals.values()))

    def table(cls, heading):
        md.append("## %s\n" % heading)
        rows_ = [g for g in groups if g["class"] == cls]
        if not rows_:
            md.append("None.\n")
            return
        md.append("| nodes | zone | levels | zone | levels | gap |")
        md.append("|---:|---|---|---|---|---:|")
        for g in rows_:
            gap = gap_of(g)
            md.append("| %d | %s | %s | %s | %s | %s |" % (g["length"], names[g["a"]],
                                                          range_text(g["a_range"]), names[g["b"]],
                                                          range_text(g["b_range"]),
                                                          "-" if gap is None else gap))
        md.append("")

    table("jump", "Red borders (gap > 5)")
    table("step", "Yellow borders (gap 2-5)")
    table("forced", "Forced gaps (the bands lie more than 5 apart)")
    # The atlas (seed 42) neighbours, which the border rule knows.
    atlas_nb = set()
    for path in sorted(ATLAS.glob("*.json")):
        rec = json.loads(path.read_text())
        if isinstance(rec, dict) and "neighbors" in rec:
            for nb in rec["neighbors"]:
                atlas_nb.add(tuple(sorted((rec["id"], nb))))
    pairs = pair_totals(doc)
    md.append("## Per zone pair\n")
    md.append("| zone | zone | fit | step | jump | forced | none | atlas neighbours |")
    md.append("|---|---|---:|---:|---:|---:|---:|---|")
    for (a, b), t in sorted(pairs.items()):
        md.append("| %s | %s | %s | %s |" % (names[a], names[b], " | ".join(
            str(t.get(c, 0) or "") for c in ("fit", "step", "jump", "forced", "none")),
            "yes" if (a, b) in atlas_nb else "**no**"))
    md.append("")
    extra = sorted(p for p in pairs if p not in atlas_nb)
    md.append("## Zone pairs that touch on this seed but are not neighbours in the atlas\n")
    md.append("The atlas lists seed 42's neighbours, and the border rule names only those; a "
              "border below is neither entry nor exit in any recipe.\n")
    if extra:
        for a, b in extra:
            t = pairs[(a, b)]
            md.append("- %s | %s: %d nodes (%s)" % (names[a], names[b], sum(t.values()), ", ".join(
                "%s %d" % (c, t[c]) for c in ("fit", "step", "jump", "forced", "none") if t.get(c))))
    else:
        md.append("None.")
    md.append("")
    md.append("## Zones\n")
    md.append("| zone | band | from | to | recipe file | notes |")
    md.append("|---|---|---|---|---|---|")
    for z in zones:
        frm, dst = entry_text(z) if z.get("recipe") else ("-", "-")
        notes = []
        if z.get("error"):
            notes.append("FAILED: " + z["error"])
        elif not z.get("recipe"):
            notes.append("no recipe")
        notes += ["problem: " + p for p in z["problems"]]
        notes += ["warning: " + w for w in z["warnings"]]
        md.append("| %s | %d-%d | %s | %s | `%s` | %s |" % (z["name"], z["band"][0], z["band"][1], frm,
                                                          dst, z.get("source", ""),
                                                          "; ".join(notes).replace("|", "/")))
    md.append("")
    md.append("Cells two zones both claim (kept by the first): %d. Seconds: world %.1f, raster %.1f, "
              "regions %.1f.\n" % (doc["duplicates"], doc["seconds"]["world"], doc["seconds"]["raster"],
                                   doc["seconds"]["regions"]))
    (Path(args.out) / ("%s_seed_%s.md" % (args.name, args.seed))).write_text("\n".join(md))


if __name__ == "__main__":
    main()
