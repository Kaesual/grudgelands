#!/usr/bin/env python3
"""Round 28 Lane S1: draw the spawn regions of one zone and seed.

Reads <dump>/<zone>_<seed>.json and .bin (tools/r28_regions/regions.lua) and
writes <out>/seed_<seed>.png and <out>/seed_<seed>.md:
  * the base map: hill-shaded terrain, sea, rivers and lakes, other zones
    greyed, roads, the zone's places;
  * the regions coloured by kind (one hue per terrain type, darker with each
    belt), thin borders between regions, thick borders between belts, each
    region labelled with its level range;
  * camps (tent) and leaders (skull) with their names;
  * a legend: per belt its level range and share of land, per kind its day
    and night roster with levels, density and share;
  * the stats file: shares per belt and kind, region sizes, camp and leader
    checks, the describe phrases and the patch directions.

Usage: render.py --dump DIR --zone ZONE --seed SEED --out DIR
Python 3 + numpy + Pillow (the atlas builder's dependencies).
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_DIR = Path("/usr/share/fonts/dejavu-sans-fonts")
LEFT, TOP, BOTTOM, PANEL = 20, 64, 24, 640

TYPE_LIGHT_DARK = {
    "open": ((228, 236, 168), (104, 138, 40)),
    "shore": ((250, 222, 160), (196, 118, 32)),
    "forest": ((150, 200, 140), (24, 84, 40)),
    "swamp": ((176, 214, 206), (40, 110, 104)),
    "bank": ((190, 220, 240), (40, 100, 160)),
    "highland": ((214, 200, 186), (120, 90, 70)),
}
CAMP_RGB = (214, 50, 40)
WATER_RGB = {2: (63, 116, 160), 3: (90, 150, 196)}
OTHER_LAND = (205, 205, 200)
TYPES = ["shore", "bank", "swamp", "forest", "highland", "open"]


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(str(FONT_DIR / name), size)
    except OSError:
        return ImageFont.load_default()


def kind_color(kind, nbelts):
    light, dark = TYPE_LIGHT_DARK.get(kind["type"], TYPE_LIGHT_DARK["open"])
    t = (kind["belt"] - 1) / max(1, nbelts - 1)
    return tuple(int(light[i] + (dark[i] - light[i]) * t) for i in range(3))


def text_halo(d, xy, text, fnt, fill=(0, 0, 0), halo=(255, 255, 255)):
    x, y = xy
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((x + dx, y + dy), text, font=fnt, fill=halo)
    d.text((x, y), text, font=fnt, fill=fill)


def draw_tent(d, x, y, s=9):
    d.polygon([(x, y - s), (x - s, y + s * 0.8), (x + s, y + s * 0.8)], fill=CAMP_RGB, outline=(0, 0, 0))
    d.line([(x, y - s), (x, y + s * 0.8)], fill=(0, 0, 0), width=1)


def draw_skull(d, x, y, s=8):
    d.ellipse([x - s, y - s, x + s, y + s * 0.6], fill=(245, 245, 235), outline=(0, 0, 0), width=2)
    d.rectangle([x - s * 0.5, y + s * 0.4, x + s * 0.5, y + s], fill=(245, 245, 235), outline=(0, 0, 0))
    d.ellipse([x - s * 0.55, y - s * 0.35, x - s * 0.1, y + s * 0.1], fill=(0, 0, 0))
    d.ellipse([x + s * 0.1, y - s * 0.35, x + s * 0.55, y + s * 0.1], fill=(0, 0, 0))


def levels_text(lv):
    return "L%d" % lv[0] if lv[0] == lv[1] else "L%d-%d" % (lv[0], lv[1])


def entry_text(doc):
    """Where the levels start: the `from` place, or the border it enters by."""
    if doc.get("from"):
        return doc["from"]["name"]
    if doc.get("from_border"):
        return "the %s border" % ", ".join(doc["from_border"])
    return "?"


def route_text(doc):
    """"from Dawnmere to the elandor_goldmead_vale border", "... to the
    zone's core", or "one belt" (a recipe without `to`)."""
    if doc.get("to_core"):
        return "from %s to the zone's core" % entry_text(doc)
    if doc.get("to"):
        return "from %s to the %s border" % (entry_text(doc), ", ".join(doc["to"]))
    return "one belt"


def roster_text(rows):
    total = sum(r["weight"] for r in rows)
    parts = []
    for r in rows:
        share = "" if len(rows) == 1 else " %d%%" % round(100.0 * r["weight"] / total)
        parts.append("%s %s%s" % (r["name"], levels_text(r["levels"]), share))
    return ", ".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--zone", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--kind-borders", action="store_true",
                    help="thin lines only between different kinds (regions of one kind that "
                         "touch read as one patch, labelled once)")
    args = ap.parse_args()
    dump = Path(args.dump)
    doc = json.load(open(dump / ("%s_%s.json" % (args.zone, args.seed))))
    # The Lua writer cannot tell an empty object from an empty list.
    for row in doc["kinds"] + doc["camps"] + doc["leaders"]:
        if not row.get("phrases"):
            row["phrases"] = {}
    if not doc.get("phrases"):
        doc["phrases"] = {}
    fr = doc["frame"]
    step, cols, rows = fr["step"], fr["cols"], fr["rows"]
    raw = np.fromfile(dump / ("%s_%s.bin" % (args.zone, args.seed)), dtype=np.uint8)
    raw = raw.reshape(rows, cols, 4)
    water = raw[..., 0]
    own = raw[..., 1] == 1
    h = raw[..., 2:4].copy().view("<i2")[..., 0].astype(float)
    land = water == 1

    # Base raster (z up: flip rows), one pixel per node.
    rgb = np.zeros((rows, cols, 3), dtype=float)
    rgb[:] = WATER_RGB[2]
    rgb[water == 3] = WATER_RGB[3]
    rgb[land] = OTHER_LAND
    gz, gx = np.gradient(h)
    shade = np.clip(1.0 + 0.10 * (-gx + gz) / step * 4, 0.7, 1.25)

    cell = doc["cell"]
    kinds = {k["id"]: k for k in doc["kinds"]}
    nbelts = len(doc["belts"])
    regions = {r["id"]: r for r in doc["regions"]}
    camp_ids = {c["id"] for c in doc["camps"]}
    # Cell -> region grid in raster pixels.
    reg = np.zeros((rows, cols), dtype=np.int32)
    belt = np.zeros((rows, cols), dtype=np.int32)
    per = cell // step
    for i, j, rid, b, _t in doc["cells"]:
        c0 = (i * cell - fr["x0"]) // step
        r0 = (j * cell - fr["z0"]) // step
        reg[r0:r0 + per, c0:c0 + per] = rid
        belt[r0:r0 + per, c0:c0 + per] = b
    for rid, r in regions.items():
        kid = r["kind"]
        col = CAMP_RGB if kid in camp_ids else kind_color(kinds[kid], nbelts)
        m = (reg == rid) & land & own
        rgb[m] = col
    rgb[land] *= shade[land][:, None]
    rgb = np.clip(rgb, 0, 255)
    # Borders: region edges thin dark (with --kind-borders only where the kind
    # changes), belt edges thick black.
    kind_index = {kid: n + 1 for n, kid in enumerate(sorted({r["kind"] for r in regions.values()}))}
    edge_src = reg
    if args.kind_borders:
        lut = np.zeros(max(regions) + 1, dtype=np.int32)
        for rid, r in regions.items():
            lut[rid] = kind_index[r["kind"]]
        edge_src = lut[reg]
    edge_r = np.zeros_like(own)
    edge_b = np.zeros_like(own)
    for axis in (0, 1):
        a = np.roll(edge_src, 1, axis=axis)
        bb = np.roll(belt, 1, axis=axis)
        both = (edge_src > 0) | (a > 0)
        edge_r |= (a != edge_src) & both
        edge_b |= (bb != belt) & (belt > 0) & (bb > 0)
    rgb[edge_r] = (70, 70, 70)
    eb = edge_b | np.roll(edge_b, 1, 0) | np.roll(edge_b, 1, 1)
    rgb[eb] = (0, 0, 0)
    img_map = Image.fromarray(np.flipud(rgb).astype(np.uint8)).resize((cols * step, rows * step), Image.NEAREST)
    W, H = cols * step, rows * step

    # Drawn on a tall canvas, cropped to the map or the legend, whichever ends lower.
    canvas = Image.new("RGB", (LEFT + W + PANEL, max(TOP + H + BOTTOM, 2400)), (255, 255, 255))
    canvas.paste(img_map, (LEFT, TOP))
    d = ImageDraw.Draw(canvas)

    def px(x, z):
        return LEFT + (x - fr["x0"]), TOP + (fr["z1"] - z)

    def map_label(x, y, text, fnt, fill, dx=0):
        """A label right of (x, y), moved left of it when it would leave the map."""
        tw = d.textbbox((0, 0), text, font=fnt)[2]
        if x + dx + tw > LEFT + W - 4:
            x = x - abs(dx) - tw - 28
        else:
            x = x + dx
        text_halo(d, (max(LEFT + 2, x), y), text, fnt, fill=fill)

    f_small, f_med, f_big, f_bold = font(11), font(13), font(20, True), font(13, True)
    # Roads.
    for road in doc["roads"]:
        pts = [px(p[0], p[1]) for p in road["points"]]
        if len(pts) > 1:
            d.line(pts, fill=(120, 80, 40), width=3 if road["kind"] == "road" else 2)
    # Region labels: level range at the centroid; with --kind-borders one
    # label per patch of touching regions of one kind (at its largest region).
    labelled = {r["id"] for r in doc["regions"]}
    if args.kind_borders:
        parent = {rid: rid for rid in regions}

        def find(rid):
            while parent[rid] != rid:
                parent[rid] = parent[parent[rid]]
                rid = parent[rid]
            return rid
        at = {(i, j): rid for i, j, rid, _b, _t in doc["cells"]}
        for (i, j), rid in at.items():
            for nb in (at.get((i + 1, j)), at.get((i, j + 1))):
                if nb and nb != rid and regions[nb]["kind"] == regions[rid]["kind"]:
                    parent[find(nb)] = find(rid)
        best = {}
        for rid, r in regions.items():
            root = find(rid)
            if root not in best or r["size"] > regions[best[root]]["size"]:
                best[root] = rid
        labelled = set(best.values())
    for r in doc["regions"]:
        if r["kind"] in camp_ids or r["id"] not in labelled:
            continue
        k = kinds[r["kind"]]
        x, y = px(r["x"], r["z"])
        t = levels_text(k["levels"])
        tw, th = d.textbbox((0, 0), t, font=f_small)[2:]
        text_halo(d, (x - tw / 2, y - th / 2), t, f_small)
    # Places.
    for p in doc["places"]:
        x, y = px(p["x"], p["z"])
        d.rectangle([x - 6, y - 6, x + 6, y + 6], fill=(255, 255, 255), outline=(0, 0, 0), width=2)
        map_label(x, y - 8, p["name"], f_bold, (0, 0, 0), dx=9)
    if doc.get("giver"):
        g = doc["giver"]
        x, y = px(g["x"], g["z"])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 215, 0), outline=(0, 0, 0))
    # Camps and leaders.
    for c in doc["camps"]:
        x, y = px(c["x"], c["z"])
        draw_tent(d, x - 14, y)
        map_label(x, y - 26, "%s (%s)" % (c["name"], levels_text(c["levels"])), f_bold, (150, 0, 0), dx=4)
    for l in doc["leaders"]:
        x, y = px(l["x"], l["z"])
        draw_skull(d, x + 10, y + 4)
        map_label(x, y - 4, "%s L%d" % (l["name"], l["level"]), f_bold, (120, 0, 0), dx=22)
    # Title.
    title = "%s: spawn regions, seed %s" % (doc["zone_name"], doc["seed"])
    d.text((LEFT, 10), title, font=f_big, fill=(0, 0, 0))
    st = doc["stats"]
    sub = ("%d land cells (32 x 32 nodes), %d regions, %s; "
           "thin lines: %s, thick: belts; labels: level range") % (
        st["cells"], st["regions"], route_text(doc),
        "between kinds" if args.kind_borders else "regions")
    d.text((LEFT, 38), sub, font=f_med, fill=(60, 60, 60))
    # Scale bar (100 nodes).
    sx, sy = LEFT + 10, TOP + H - 16
    d.rectangle([sx, sy, sx + 100, sy + 5], fill=(0, 0, 0))
    text_halo(d, (sx + 104, sy - 6), "100 nodes", f_small)
    text_halo(d, (LEFT + W - 30, TOP + 6), "N ^", f_bold)

    # Legend panel.
    x0 = LEFT + W + 16
    y = TOP
    belt_share = {b["id"]: b for b in st["belts"]}
    kind_share = {k["id"]: k for k in st["kinds"]}
    for b_index, b in enumerate(doc["belts"], start=1):
        sb = belt_share[b["id"]]
        cap = ", at most %d nodes from %s" % (b["max_from"], entry_text(doc)) if b.get("max_from") else ""
        d.text((x0, y), "Belt %s  %s  %.1f %% of land (planned %g %%%s)" % (
            b_index, levels_text(b["levels"]), 100 * sb["share"], b["share"], cap), font=f_bold, fill=(0, 0, 0))
        y += 18
        for k in doc["kinds"]:
            if k["belt"] != b_index:
                continue
            ks = kind_share.get(k["id"], {"share": 0, "regions": 0})
            d.rectangle([x0, y + 2, x0 + 14, y + 14], fill=kind_color(k, nbelts), outline=(0, 0, 0))
            d.text((x0 + 20, y), "%s  (%s, %s, %.1f %%, %d region%s)" % (
                k["name"], k["type"], k["density"], 100 * ks["share"], ks["regions"],
                "" if ks["regions"] == 1 else "s"), font=f_med, fill=(0, 0, 0))
            y += 16
            inh = k.get("inherits") or {}
            for clock in ("day", "night"):
                t = roster_text(k[clock]) + ("  (as open)" if inh.get(clock) else "")
                d.text((x0 + 30, y), "%s: %s" % (clock, t), font=f_small, fill=(50, 50, 50))
                y += 14
            y += 2
        y += 6
    for c in doc["camps"]:
        draw_tent(d, x0 + 8, y + 8, 7)
        name = "%s (on %s, belt %s, POI in %s)" % (c["name"], c["poi"], c["belt"], c["poi_belt"]) \
            if c.get("poi") else c["name"]
        d.text((x0 + 20, y), "%s: %s, %d slots, respawn %d-%d s" % (
            name, roster_text(c["roster"]), c["slots"], c["respawn"][0], c["respawn"][1]),
            font=f_med, fill=(0, 0, 0))
        y += 18
    for l in doc["leaders"]:
        draw_skull(d, x0 + 8, y + 8, 6)
        d.text((x0 + 20, y), "%s, level %d, respawn %d s" % (l["name"], l["level"], l["respawn"]),
               font=f_med, fill=(0, 0, 0))
        y += 18
    y += 8
    d.text((x0, y), "Directions (describe):", font=f_bold, fill=(0, 0, 0))
    y += 18
    for target, ph in doc["phrases"].items():
        for key in ("of", "from_giver", "zone"):
            if ph.get(key):
                d.text((x0 + 10, y), "%s: %s" % (target, ph[key]["phrase"]), font=f_small, fill=(40, 40, 40))
                y += 14
    y += 8
    sizes = st["sizes"]
    d.text((x0, y), "Region sizes (cells): min %d, median %d, max %d; belt jump max %d" % (
        sizes[0], sizes[len(sizes) // 2], sizes[-1], st["max_belt_jump"]), font=f_small, fill=(0, 0, 0))
    y += 14
    for p in st["problems"]:
        d.text((x0, y), "PROBLEM: " + p, font=f_bold, fill=(200, 0, 0))
        y += 16

    canvas = canvas.crop((0, 0, canvas.width, max(TOP + H + BOTTOM, y + 16)))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    png = out / ("seed_%s.png" % args.seed)
    canvas.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                    dither=Image.Dither.NONE).save(png, optimize=True)
    write_stats(doc, out / ("seed_%s.md" % args.seed))


def write_stats(doc, path):
    st = doc["stats"]
    lines = ["# %s spawn regions, seed %s" % (doc["zone_name"], doc["seed"]), ""]
    lines.append("Generated by `tools/r28_regions/run.sh` from the shipped recipe "
                 "(`mods/ENTITIES/grug_mobs/data/zones/%s.spawns.json`); image `seed_%s.png`." % (
                     doc["zone"], doc["seed"]))
    lines.append("")
    lines.append("Build: world %.1f s, region map %.2f s (CPU, LuaJIT, offline); the map holds about "
                 "%.0f KiB, the first build %.0f KiB with the planner's column cache it warms. "
                 "%d land cells, %d regions, %d islet cells, %d cells smoothed (belt step-down)." % (
                     doc["seconds"]["world"], doc["seconds"]["regions"], doc.get("map_kib", 0),
                     doc["build_kib"], st["cells"], st["regions"], st["islet_cells"],
                     doc["smoothed_cells"]))
    lines.append("")
    lines.append("## Belts")
    lines.append("")
    lines.append("| Belt | Levels | Planned | Land share |")
    lines.append("|---|---|---|---|")
    for b, sb in zip(doc["belts"], st["belts"]):
        lines.append("| %s | %s | %g %%%s | %.1f %% |" % (
            b["id"], levels_text(b["levels"]), b["share"],
            ", max %d nodes" % b["max_from"] if b.get("max_from") else "", 100 * sb["share"]))
    lines.append("")
    lines.append("## Kinds")
    lines.append("")
    lines.append("| Kind | Belt | Type | Density | Land share | Regions | Day | Night |")
    lines.append("|---|---|---|---|---|---|---|---|")
    ks = {k["id"]: k for k in st["kinds"]}
    for k in doc["kinds"]:
        s = ks.get(k["id"], {"share": 0, "regions": 0})
        lines.append("| %s (`%s`) | %d | %s | %s | %.1f %% | %d | %s | %s |" % (
            k["name"], k["id"], k["belt"], k["type"], k["density"], 100 * s["share"], s["regions"],
            roster_text(k["day"]), roster_text(k["night"])))
    for c in doc["camps"]:
        s = ks.get(c["id"], {"share": 0, "regions": 0})
        lines.append("| %s (`%s`) | camp | - | slots %d | %.1f %% | %d | %s | %s |" % (
            c["name"], c["id"], c["slots"], 100 * s["share"], s["regions"],
            roster_text(c["roster"]), roster_text(c["roster"])))
    lines.append("")
    sizes = st["sizes"]
    lines.append("## Region sizes")
    lines.append("")
    lines.append("Cells per region (32 x 32 nodes each), sorted: %s. Min %d, median %d, max %d; "
                 "largest belt difference between adjacent regions: %d." % (
                     " ".join(str(s) for s in sizes), sizes[0], sizes[len(sizes) // 2], sizes[-1],
                     st["max_belt_jump"]))
    lines.append("")
    lines.append("## Camps and leaders")
    lines.append("")
    for c in doc["camps"]:
        if c.get("poi"):
            lines.append("- Camp `%s` on the POI %s at (%d, %d): belt %s (the POI's cell lies in belt %s "
                         "on this seed), nearest road %.0f nodes, levels %s." % (
                             c["id"], c["poi"], c["x"], c["z"], c["belt"], c["poi_belt"], c["road"],
                             levels_text(c["levels"])))
            continue
        lines.append("- Camp `%s` at (%d, %d): score %.2f, nearest road %.0f nodes, levels %s." % (
            c["id"], c["x"], c["z"], c["score"], c["road"], levels_text(c["levels"])))
    for l in doc["leaders"]:
        lines.append("- Leader %s (`%s`) at (%d, %d), level %d, respawn %d s." % (
            l["name"], l["role"], l["x"], l["z"], l["level"], l["respawn"]))
    for p in st["problems"]:
        lines.append("- PROBLEM: %s" % p)
    for w in st.get("warnings") or []:
        lines.append("- WARNING: %s" % w)
    lines.append("")
    lines.append("## Directions")
    lines.append("")
    giver = doc.get("giver")
    ref = doc.get("from")
    lines.append("Reference place: %s; quest giver: %s." % (
        "%s at (%d, %d)" % (ref["name"], ref["x"], ref["z"]) if ref else "none (no `from` anchor)",
        "%s at (%d, %d)" % (giver["name"], giver["x"], giver["z"]) if giver else "none (no start town)"))
    lines.append("")
    lines.append("| Target | Of the place | From the giver | Within the zone |")
    lines.append("|---|---|---|---|")
    targets = [(c["name"], c["phrases"]) for c in doc["camps"]] + \
        [(l["name"], l["phrases"]) for l in doc["leaders"]] + \
        [(k["name"], k["phrases"]) for k in doc["kinds"]]
    for name, ph in targets:
        def cell(key):
            v = ph.get(key)
            return "%s (%d)" % (v["phrase"], v["distance"]) if v else "-"
        lines.append("| %s | %s | %s | %s |" % (name, cell("of"), cell("from_giver"), cell("zone")))
    lines.append("")
    lines.append("Distances in nodes (zone column: from the zone's land centre). A kind points at "
                 "its largest region.")
    lines.append("")
    lines.append("## Patches of one kind")
    lines.append("")
    if not doc["patches"]:
        lines.append("No kind has more than one region.")
    else:
        lines.append("| Kind | Direction used (largest) | Patches | Patches in another direction | "
                     "Their share of the kind |")
        lines.append("|---|---|---|---|---|")
        for p in doc["patches"]:
            dirs = ", ".join("%s (%d)" % (r["dir"], r["size"]) for r in p["regions"])
            lines.append("| %s | %s | %s | %d | %.0f %% |" % (
                p["kind"], p["chosen"], dirs, p["differ"], 100 * p["differ_share"]))
    lines.append("")
    path.write_text("\n".join(lines))


if __name__ == "__main__":
    main()
