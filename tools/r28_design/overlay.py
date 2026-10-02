#!/usr/bin/env python3
"""Round 28 design overlay: draws a design's quest hubs and givers on top of
the zone atlas maps, with a side panel summarizing the zone's spawn recipe,
so reviewers see where quests are given.

Spawn regions are no longer hand-placed: a zone's spawn recipe (rules, no
coordinates) becomes a region map only for a given world seed. Those images
come from the region renderer tools/r28_regions/run.sh (the game's own
spawn_regions_core.lua), not from this tool.

For every zone with a zones/<zone>.spawns.json or .quests.json in the
design directory it reads the atlas map docs/planning/round28/zones/maps/
<zone>.png (1 px = 1 node, north up) and writes <out>/<zone>.design.png with
  * the hubs' quest givers ("!") with their names and lines (new givers at
    their free quest socket);
  * a side panel: the recipe (from, to, belts with their kinds and levels,
    camps, leaders with their computed level, critters) and the hubs with
    their givers; givers the atlas does not know are flagged.

Usage:
  overlay.py --out DIR [--design DIR] [--atlas DIR] [--zone ZONE ...]

Python 3 + numpy + Pillow (the atlas builder's dependencies).
"""
import argparse
import json
import math
import sys
import textwrap
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "r28_zone_atlas"))
import r28common as C  # noqa: E402
import build_atlas as BA  # noqa: E402

DEFAULT_ATLAS = C.REPO / "docs" / "planning" / "round28" / "zones"

# The atlas map frame (build_atlas.render_zone as run.sh calls it): grid
# origin and step, 64-node margin around the zone's land extent, canvas
# margins around the map.
GRID_MIN_X, GRID_MIN_Z, GRID_STEP = -3600, -3200, 4
GRID_COLS, GRID_ROWS = 1800, 1600
FRAME_MARGIN = 64
LEFT, TOP, RIGHT, BOTTOM = 70, 70, 330, 60
MIN_CANVAS_H = 760
PANEL_W = 600
FLAG_RGB = (200, 0, 0)


class Frame:
    """The atlas map's world window and the world -> pixel transform."""

    def __init__(self, extent, min_x=GRID_MIN_X, min_z=GRID_MIN_Z, step=GRID_STEP,
                 cols=GRID_COLS, rows=GRID_ROWS):
        x0, x1 = extent["min_x"] - FRAME_MARGIN, extent["max_x"] + FRAME_MARGIN
        z0, z1 = extent["min_z"] - FRAME_MARGIN, extent["max_z"] + FRAME_MARGIN
        c0, c1 = max(0, (x0 - min_x) // step), min(cols - 1, (x1 - min_x) // step)
        r0, r1 = max(0, (z0 - min_z) // step), min(rows - 1, (z1 - min_z) // step)
        self.step = step
        self.x0, self.z1 = min_x + c0 * step, min_z + r1 * step
        self.w = (c1 - c0 + 1) * step
        self.h = (r1 - r0 + 1) * step
        self.canvas = (self.w + LEFT + RIGHT, max(self.h + TOP + BOTTOM, MIN_CANVAS_H))

    def px(self, x, z):
        """Map-local pixel of a world point."""
        return (x - self.x0) + self.step / 2.0, (self.z1 - z) + self.step / 2.0


class Placer:
    """Label placement around a point, avoiding earlier labels and markers;
    a label pushed away from its point gets a thin leader line."""

    def __init__(self, d, bounds):
        self.d, self.bounds, self.boxes = d, bounds, []

    def block(self, box):
        self.boxes.append(box)

    def free(self, box):
        x0, y0, x1, y1 = self.bounds
        if box[0] < x0 or box[1] < y0 or box[2] > x1 or box[3] > y1:
            return False
        return all(box[2] < b[0] or box[0] > b[2] or box[3] < b[1] or box[1] > b[3] for b in self.boxes)

    def place(self, x, y, text, fnt, fill, near=8):
        tw, th = self.d.textbbox((0, 0), text, font=fnt)[2:]
        for dist in (near, near + 14, near + 32, near + 56, near + 90, near + 130, near + 180):
            for k in range(12):
                ang = math.radians(k * 30)
                ca, sa = math.cos(ang), math.sin(ang)
                ax, ay = x + dist * ca, y + dist * sa
                bx = ax if ca > 0.3 else ax - tw if ca < -0.3 else ax - tw / 2.0
                by = ay if sa > 0.3 else ay - th if sa < -0.3 else ay - th / 2.0
                box = (bx - 2, by - 2, bx + tw + 2, by + th + 2)
                if not self.free(box):
                    continue
                self.boxes.append(box)
                if dist > near + 14:
                    self.d.line([(x, y), (min(max(x, box[0]), box[2]), min(max(y, box[1]), box[3]))],
                                fill=(60, 60, 60), width=1)
                BA.text_halo(self.d, (bx, by), text, fnt, fill=fill)
                return True
        return False


def draw_giver(d, x, y, fnt):
    d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 225, 0), outline=(0, 0, 0), width=2)
    d.text((x - 2, y - 8), "!", font=fnt, fill=(0, 0, 0))


def short_levels(levels):
    if not levels:
        return "L?"
    return "L%d–%d" % tuple(levels) if levels[0] != levels[1] else "L%d" % levels[0]


def zone_quest_givers(zone_json):
    """npc id -> (x, z, name), and (anchor id, socket) -> (x, z) of free
    quest sockets, from the atlas zone record."""
    npcs, sockets = {}, {}
    for s in zone_json.get("settlements") or []:
        for n in s.get("npcs") or []:
            if n.get("role") != "quest":
                continue
            if n.get("npc_id"):
                npcs[n["npc_id"]] = (n["x"], n["z"], n.get("npc_name") or n["npc_id"])
            elif n.get("socket"):
                sockets[(s.get("anchor_id"), n["socket"])] = (n["x"], n["z"])
    return npcs, sockets


def hub_givers(zone, design, atlas, zone_json):
    """[(hub, giver, (x, z, name) or None)] of the zone's quests file."""
    npcs, sockets = zone_quest_givers(zone_json)
    out = []
    hubs = (design.quests.get(zone) or {}).get("hubs") if isinstance(design.quests.get(zone), dict) else None
    for hub in hubs or []:
        if not isinstance(hub, dict):
            continue
        hub_anchor = atlas.resolve_anchor(zone, hub.get("anchor"))
        for giver in hub.get("givers") or []:
            if not isinstance(giver, dict):
                continue
            where = None
            if isinstance(giver.get("new"), dict):
                xz = sockets.get((hub_anchor, giver["new"].get("socket")))
                if xz:
                    where = (xz[0], xz[1], giver["new"].get("name") or giver.get("npc"))
            else:
                where = npcs.get(giver.get("npc"))
            out.append((hub, giver, where))
    return out


def render(zone, design, atlas, atlas_dir, out_dir):
    zone_json = json.load(open(atlas_dir / ("%s.json" % zone)))
    frame = Frame(zone_json["extent"])
    base = Image.open(atlas_dir / "maps" / ("%s.png" % zone)).convert("RGB")
    if base.size != frame.canvas:
        raise C.LoadError("%s: atlas map is %dx%d, the frame says %dx%d (atlas rebuilt with another grid?)"
                          % (zone, base.size[0], base.size[1], frame.canvas[0], frame.canvas[1]))
    # Muted map so the givers stand out.
    src = np.asarray(base.crop((LEFT, TOP, LEFT + frame.w, TOP + frame.h))).astype(float)
    gray = src.mean(axis=2, keepdims=True)
    rgb = (src * 0.45 + gray * 0.55) * 0.85 + 255 * 0.15
    mapimg = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")

    problems = []
    givers = hub_givers(zone, design, atlas, zone_json)
    lines = panel_lines(zone, design, givers, problems)
    W0, H0 = frame.canvas
    panel_h = 90 + 16 * len(lines)
    canvas = Image.new("RGB", (W0 + PANEL_W, max(H0, panel_h)), (250, 250, 247))
    canvas.paste(base, (0, 0))
    canvas.paste(mapimg, (LEFT, TOP))
    d = ImageDraw.Draw(canvas)
    d.rectangle([LEFT, TOP, LEFT + frame.w, TOP + frame.h], outline=(0, 0, 0), width=1)
    fs, fb = BA.font(12), BA.font(13, True)
    placer = Placer(d, (LEFT, TOP, LEFT + frame.w, TOP + frame.h))
    marks = []
    for hub, giver, where in givers:
        if where is None:
            continue
        px, py = frame.px(where[0], where[1])
        x, y = LEFT + px, TOP + py
        if LEFT <= x <= LEFT + frame.w and TOP <= y <= TOP + frame.h:
            draw_giver(d, x, y, fb)
            placer.block((x - 8, y - 8, x + 8, y + 8))
            marks.append((x, y, "! %s: %s" % (where[2], ", ".join(giver.get("lines") or []))))
    for x, y, text in marks:
        placer.place(x, y, text, fb, (90, 60, 0), near=10)
    draw_panel(d, W0 + 10, lines, fs, fb, zone_json)
    out = out_dir / ("%s.design.png" % zone)
    BA.save_png(canvas, out)
    return out, problems


def panel_lines(zone, design, givers, problems):
    """(kind, text, colour) rows of the side panel."""
    rows = []
    sub = design.subtype_map()

    def add(text, col=(0, 0, 0), kind="text", indent=0):
        for k, part in enumerate(textwrap.wrap(text, 84 - indent) or [""]):
            rows.append((kind if k == 0 else "text", ("  " * indent if k == 0 else "  " * (indent + 1)) + part, col))

    rows.append(("head", "Spawn recipe", (0, 0, 0)))
    data = design.spawns.get(zone)
    parsed, errors = design.recipe(zone)
    if parsed is None:
        if isinstance(data, dict) and isinstance(data.get("palette"), dict):
            add("no recipe: today's palette (%s)" % ", ".join(map(str, data["palette"].get("families") or [])),
                (90, 90, 90))
        else:
            add("no recipe", (90, 90, 90))
    else:
        frm, dst = parsed["from"] or {}, parsed["to"] or {}
        entry = ", ".join(frm.get("anchor") or []) or (
            "the border with %s" % ", ".join(frm["border"]) if frm.get("border") else "?")
        if dst.get("core"):
            add("from %s to the zone's core" % entry)
        elif dst.get("border"):
            add("from %s to the border with %s" % (entry, ", ".join(dst["border"])))
        else:
            add("one belt (no progression)")
        areas = design.areas(zone)
        for belt in parsed["belts"]:
            add("belt %s · %s%% · %s%s" % (belt["id"], belt["share"], short_levels(belt["levels"]),
                                           " · max_from %s" % belt["max_from"] if belt["max_from"] else ""))
            for t, kind in belt["kinds"].items():
                area = areas[kind["id"]]
                add("%s %s (%s) %s, %s: %s" % (t, kind["id"], kind["name"], short_levels(area["levels"]),
                                               kind["density"], C.species_text(area)), (60, 60, 60), indent=1)
        for camp in parsed["camps"]:
            area = areas[camp["id"]]
            site = camp.get("site")
            where = " · on %s" % site["name"] if isinstance(site, dict) and site.get("name") else ""
            belt = camp["belt"] or "of the POI (per seed)"
            add("camp %s (%s)%s · belt %s · %s · %s slots: %s" % (camp["id"], camp["name"], where, belt,
                                                                 short_levels(area["levels"]), camp["slots"],
                                                                 C.species_text(area)))
        for role, leader in sorted(design.leaders(zone).items()):
            name = (sub.get(role) or {}).get("display") or role
            at = leader["at"] or {}
            spot = "camp %s" % at["camp"] if "camp" in at else "kind %s (%s)" % (at.get("kind"), at.get("pick"))
            add("leader %s (%s) L%s · respawn %s s · at %s" % (name, role, leader["level"], leader["respawn"], spot))
        if parsed["critters"]:
            add("critters: %s" % ", ".join(parsed["critters"]), (60, 60, 60))
        for err in errors:
            add("! " + err, FLAG_RGB, indent=1)
            problems.append("recipe %s" % err)
        add("regions per seed: tools/r28_regions/run.sh %s" % zone, (90, 90, 90))
    rows.append(("gap", "", None))
    rows.append(("head", "Quest hubs", (0, 0, 0)))
    last_hub = None
    for hub, giver, where in givers:
        if hub is not last_hub:
            add("%s @%s" % (hub.get("id"), hub.get("anchor")))
            last_hub = hub
        npc = giver.get("npc")
        if isinstance(giver.get("new"), dict):
            name = "%s (new, socket %s)" % (giver["new"].get("name"), giver["new"].get("socket"))
        else:
            name = where[2] if where else npc
        add("%s (%s): %s" % (name, npc, ", ".join(giver.get("lines") or [])), kind="giver", indent=1)
        if where is None:
            add("! not found among this zone's quest NPCs in the atlas", FLAG_RGB, indent=2)
            problems.append("giver %s: not in the atlas zone" % npc)
    return rows


def draw_panel(d, x0, rows, fs, fb, zone_json):
    y = 12
    d.text((x0, y), "Design overlay · %s" % zone_json["name"], font=BA.font(16, True), fill=(0, 0, 0))
    y += 24
    draw_giver(d, x0 + 7, y + 7, fb)
    d.text((x0 + 20, y), "quest giver: lines", font=fs, fill=(0, 0, 0))
    y += 26
    for kind, text, col in rows:
        if kind == "gap":
            y += 6
            continue
        if kind == "head":
            d.text((x0, y), text, font=fb, fill=col)
            y += 18
            continue
        d.text((x0, y), text, font=fs, fill=col)
        y += 16


def parse(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN), help="design directory (default: the repo's)")
    ap.add_argument("--atlas", default=str(DEFAULT_ATLAS), help="zone atlas directory with maps/ (default: the repo's)")
    ap.add_argument("--zone", action="append", help="only this zone (repeatable)")
    ap.add_argument("--out", required=True, help="output directory for <zone>.design.png")
    return ap.parse_args(argv)


def main(argv):
    args = parse(argv)
    design = C.Design(args.design)
    for err in design.errors:
        print("error: %s" % err, file=sys.stderr)
    atlas_dir = Path(args.atlas)
    atlas = C.Atlas(atlas_dir)
    zones = args.zone or sorted(set(design.spawns) | set(design.quests))
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    status = 0
    for zone in zones:
        if zone not in atlas.zones:
            print("%s: not in the atlas, skipped" % zone, file=sys.stderr)
            status = 1
            continue
        try:
            path, problems = render(zone, design, atlas, atlas_dir, out_dir)
        except C.LoadError as err:
            print("error: %s" % err, file=sys.stderr)
            status = 1
            continue
        print("%s -> %s" % (zone, path))
        for problem in problems:
            print("  ! %s" % problem)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
