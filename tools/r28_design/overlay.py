#!/usr/bin/env python3
"""Round 28 design overlay: draws a design's spawn areas, leaders and quest
hubs on top of the zone atlas maps, so zone designs can be approved visually
and reviewers see the geography.

For every zone with a zones/<zone>.spawns.json (or .quests.json) in the
design directory it reads the atlas map docs/planning/round28/zones/maps/
<zone>.png (same pixel scale and axes: 1 px = 1 node, north up) and writes
<out>/<zone>.design.png with
  * every spawn area's shape (circle, ring, band; `zone` and the fallback
    area hatched lightly), coloured by clock: day yellow, night blue, both
    purple; the fill covers only the zone's own land (areas are clipped to
    their zone in game), the outline shows the whole shape;
  * a label "<n> area_id L lo-hi: species" per area, camp areas with a tent;
  * leaders as skulls with name and level;
  * the hubs' quest givers ("!") with their names and lines;
  * a side panel: legend, every area with its numbers, leaders, hubs.

Anchors resolve like validate.py and B1's spawn_areas.lua: an atlas anchor
id, a settlement key, a slot (`start`, `capital`, `village_1`, ...) or
`zone` (the zone hub), plus `offset` [x, z] in world axes. A band spans
`side` along +x and `forward` along the zone's front axis (`front.axis` of
the atlas: +z on Elandor, -z on Kragmar), both from anchor + offset.

With --grid (the sampler output of tools/r28_zone_atlas/sample.lua, see the
README) each area also gets geometry numbers from the real world sample:
share of the shape on the zone's own land, on water and in other zones,
protected ground (towns, village boxes, road corridors) and the ground its
hosts admit; questionable cases are flagged with "!" (stdout and panel).
Without it the zone mask for the fill comes from the atlas map's colours.

Usage:
  overlay.py --out DIR [--design DIR] [--atlas DIR] [--grid DIR] [--zone ZONE ...]

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

# The atlas map frame (build_atlas.render_zone and sample.lua as run.sh calls
# it): grid origin and step, 64-node margin around the zone's land extent,
# canvas margins around the map.
GRID_MIN_X, GRID_MIN_Z, GRID_STEP = -3600, -3200, 4
GRID_COLS, GRID_ROWS = 1800, 1600
FRAME_MARGIN = 64
LEFT, TOP, RIGHT, BOTTOM = 70, 70, 330, 60
MIN_CANVAS_H = 760
PANEL_W = 600

CLOCK_RGB = {"day": (240, 190, 0), "night": (40, 95, 235), "both": (160, 50, 205)}
CLOCK_TEXT = {"day": (130, 95, 0), "night": (20, 55, 170), "both": (110, 25, 150)}
FILL_ALPHA = 0.30
HATCH_ALPHA = 0.35
FLAG_RGB = (200, 0, 0)

# Flag thresholds (guides for reviewers, not rules).
MIN_OWN_LAND = 0.5      # share of the shape on the zone's own land
MAX_PROTECTED = 0.3     # share of the own land that is protected ground
SHORE_REACH = 2         # grid cells (8 nodes) from sea for "shore" sand


# --------------------------------------------------------------------------
# frame
# --------------------------------------------------------------------------

class Frame:
    """The atlas map's world window and the world -> pixel transform."""

    def __init__(self, extent, min_x=GRID_MIN_X, min_z=GRID_MIN_Z, step=GRID_STEP,
                 cols=GRID_COLS, rows=GRID_ROWS):
        x0, x1 = extent["min_x"] - FRAME_MARGIN, extent["max_x"] + FRAME_MARGIN
        z0, z1 = extent["min_z"] - FRAME_MARGIN, extent["max_z"] + FRAME_MARGIN
        self.c0, self.c1 = max(0, (x0 - min_x) // step), min(cols - 1, (x1 - min_x) // step)
        self.r0, self.r1 = max(0, (z0 - min_z) // step), min(rows - 1, (z1 - min_z) // step)
        self.step = step
        self.x0, self.x1 = min_x + self.c0 * step, min_x + self.c1 * step
        self.z0, self.z1 = min_z + self.r0 * step, min_z + self.r1 * step
        self.w = (self.c1 - self.c0 + 1) * step
        self.h = (self.r1 - self.r0 + 1) * step
        self.canvas = (self.w + LEFT + RIGHT, max(self.h + TOP + BOTTOM, MIN_CANVAS_H))

    def px(self, x, z):
        """Map-local pixel of a world point."""
        return (x - self.x0) + self.step / 2.0, (self.z1 - z) + self.step / 2.0

    def world_grid(self):
        """World x, z of every map pixel (arrays of the map's shape)."""
        jj, ii = np.meshgrid(np.arange(self.w), np.arange(self.h))
        return self.x0 + jj - self.step / 2.0, self.z1 - ii + self.step / 2.0

    def sub(self, arr):
        return arr[self.r0:self.r1 + 1, self.c0:self.c1 + 1]

    def to_px(self, cells):
        """A grid-cell mask of the frame -> map pixel mask (as render_zone)."""
        return np.flipud(cells).repeat(self.step, 0).repeat(self.step, 1)


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def shape_mask(area, X, Z):
    """Boolean mask of an area's shape over world coordinates X, Z
    (spawn_areas.lua SA.in_shape). None for an unknown shape."""
    shape = area["shape"]
    kind = shape.get("kind")
    if kind == "zone":
        return np.ones(X.shape, dtype=bool)
    dx, dz = X - area["cx"], Z - area["cz"]
    if kind == "circle":
        return dx * dx + dz * dz <= shape["r"] ** 2
    if kind == "ring":
        d2 = dx * dx + dz * dz
        return (d2 >= shape["r"][0] ** 2) & (d2 <= shape["r"][1] ** 2)
    if kind == "band":
        forward = area["sign"] * dz
        return ((forward >= shape["forward"][0]) & (forward <= shape["forward"][1]) &
                (dx >= shape["side"][0]) & (dx <= shape["side"][1]))
    return None


def shape_ok(shape):
    def pair(v):
        return isinstance(v, list) and len(v) == 2 and all(isinstance(n, (int, float)) for n in v)
    if not isinstance(shape, dict):
        return False
    kind = shape.get("kind")
    if kind == "zone":
        return True
    if kind == "circle":
        return isinstance(shape.get("r"), (int, float)) and shape["r"] > 0
    if kind == "ring":
        return pair(shape.get("r"))
    if kind == "band":
        return pair(shape.get("forward")) and pair(shape.get("side"))
    return False


def label_point(area, frame, zone_px):
    """Where an area's label hangs: the circle/ring centre, the band's
    centre, the zone's land centroid for `zone`."""
    shape = area["shape"]
    if shape["kind"] in ("circle", "ring"):
        return frame.px(area["cx"], area["cz"])
    if shape["kind"] == "band":
        f = sum(shape["forward"]) / 2.0
        s = sum(shape["side"]) / 2.0
        return frame.px(area["cx"] + s, area["cz"] + area["sign"] * f)
    rr, cc = np.nonzero(zone_px)
    if len(rr) == 0:
        return frame.w / 2.0, frame.h / 2.0
    return float(cc.mean()), float(rr.mean())


# --------------------------------------------------------------------------
# world sample (optional)
# --------------------------------------------------------------------------

class World:
    """Grid classes inside one zone's frame (sample.lua output)."""

    def __init__(self, G, frame, num, zone_json):
        self.frame = frame
        sub = frame.sub
        self.X, self.Z = sub(G.X), sub(G.Z)
        land = sub(G.land)
        self.water = sub(G.sea) | sub(G.inland)
        self.own = land & (sub(G.zone) == num)
        self.other = land & ~self.own
        self.biome = sub(G.biome)
        self.biome_names = [C.biome_id(b) for b in G.meta["biomes"]]
        # Round 28 ruling 3 (grug_mobs.protected_spawn_surface): start towns
        # and capital cities, road corridors, village boxes; camps and other
        # POIs are not protected.
        town = sub(G.prot) == 1
        road = np.zeros(self.own.shape, dtype=bool)
        step = frame.step
        for r in G.meta["roads"]:
            reach = r["half_width"] + 1
            pts = [(x, z) for x, z in r["points"]
                   if frame.x0 - 16 <= x <= frame.x1 + 16 and frame.z0 - 16 <= z <= frame.z1 + 16]
            for x, z in pts:
                c = int(round((x - frame.x0) / step))
                rr = int(round((z - frame.z0) / step))
                k = int(math.ceil(reach / step))
                for dr in range(-k, k + 1):
                    for dc in range(-k, k + 1):
                        a, b = rr + dr, c + dc
                        if 0 <= a < road.shape[0] and 0 <= b < road.shape[1] and \
                                math.hypot(self.X[a, b] - x, self.Z[a, b] - z) <= max(reach, step / 2.0):
                            road[a, b] = True
        boxes = np.zeros(self.own.shape, dtype=bool)
        for b in (zone_json.get("protected") or {}).get("settlement_boxes") or []:
            if b.get("kind") != "village":
                continue
            boxes |= ((self.X >= b["min_x"]) & (self.X <= b["max_x"]) &
                      (self.Z >= b["min_z"]) & (self.Z <= b["max_z"]))
        self.road = road & land
        self.protected = (town | road | boxes) & land
        sand = land & (sub(G.coast) == 1)
        near_water = BA.dilate_square(sub(G.sea) | (sub(G.inland) & (sub(G.h) <= 1)), SHORE_REACH)
        self.shore = sand & near_water

    def cell_class(self, x, z):
        r = int(round((z - self.frame.z0) / self.frame.step))
        c = int(round((x - self.frame.x0) / self.frame.step))
        if not (0 <= r < self.own.shape[0] and 0 <= c < self.own.shape[1]):
            return "outside the map"
        if self.water[r, c]:
            return "water"
        if self.other[r, c]:
            return "another zone"
        if not self.own[r, c]:
            return "outside the zone"
        if self.road[r, c]:
            return "road"
        if self.protected[r, c]:
            return "protected ground"
        return None

    def area_stats(self, area):
        mask = shape_mask(area, self.X, self.Z)
        n = int(mask.sum())
        if n == 0:
            return {"cells": 0, "flags": ["shape covers no ground sample"]}
        own = mask & self.own
        hosts = area.get("hosts") or {}
        biomes = [C.biome_id(b) for b in hosts.get("biomes") or ["any"]]
        host = own & ~self.protected
        if "any" not in biomes:
            ok = np.zeros(own.shape, dtype=bool)
            for i, name in enumerate(self.biome_names):
                if name in biomes:
                    ok |= self.biome == i + 1
            host &= ok
        if hosts.get("shore"):
            host &= self.shore
        st = {
            "cells": n,
            "own": own.sum() / float(n),
            "water": (mask & self.water).sum() / float(n),
            "other": (mask & self.other).sum() / float(n),
            "protected": (own & self.protected).sum() / float(max(1, own.sum())),
            "road": int((own & self.road).sum()),
            "host_nodes": int(host.sum()) * self.frame.step ** 2,
            "host": host,
            "flags": [],
        }
        flags = st["flags"]
        kind = area["shape"]["kind"]
        if kind in ("circle", "ring") or area.get("camp"):
            where = self.cell_class(area["cx"], area["cz"])
            if where and kind == "circle":
                flags.append("centre on %s" % where)
        # A shore area straddles the coast by intent; its host test below
        # tells whether it holds any shore at all.
        if kind != "zone" and not hosts.get("shore") and st["own"] < MIN_OWN_LAND:
            flags.append("only %d%% of the shape on the zone's land (water %d%%, other zones %d%%)"
                         % (100 * st["own"], 100 * st["water"], 100 * st["other"]))
        if st["protected"] > MAX_PROTECTED:
            flags.append("%d%% of its land is protected ground" % (100 * st["protected"]))
        if area.get("camp") and st["road"]:
            flags.append("camp circle crosses a road corridor (%d nodes2)" % (st["road"] * self.frame.step ** 2))
        if st["host_nodes"] == 0:
            flags.append("no ground its hosts admit (%s%s)" % (
                ", ".join(biomes), ", shore" if hosts.get("shore") else ""))
        return st


# --------------------------------------------------------------------------
# drawing helpers
# --------------------------------------------------------------------------

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


def draw_skull(d, x, y, s=8):
    d.ellipse([x - s, y - s, x + s, y + s * 0.8], fill=(250, 250, 245), outline=(0, 0, 0), width=2)
    d.rectangle([x - s * 0.55, y + s * 0.5, x + s * 0.55, y + s * 1.2], fill=(250, 250, 245), outline=(0, 0, 0))
    for ex in (-0.4, 0.4):
        d.ellipse([x + ex * s - 2.5, y - 2.5, x + ex * s + 2.5, y + 2.5], fill=(0, 0, 0))
    d.line([(x, y + s * 0.6), (x, y + s * 1.2)], fill=(0, 0, 0))


def draw_tent(d, x, y, s=7):
    d.polygon([(x, y - s), (x - s, y + s * 0.8), (x + s, y + s * 0.8)], fill=(150, 90, 40), outline=(0, 0, 0))
    d.line([(x, y - s), (x, y + s * 0.8)], fill=(0, 0, 0))


def draw_giver(d, x, y, fnt):
    d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 225, 0), outline=(0, 0, 0), width=2)
    d.text((x - 2, y - 8), "!", font=fnt, fill=(0, 0, 0))


def hatch(shape):
    h, w = shape
    jj, ii = np.meshgrid(np.arange(w), np.arange(h))
    return (jj + ii) % 18 < 2


def blend(rgb, mask, col, alpha):
    rgb[mask] = rgb[mask] * (1 - alpha) + np.array(col, dtype=float) * alpha


def outline(d, area, frame, inset, col):
    shape = area["shape"]
    kind = shape["kind"]
    widths = ((6, (0, 0, 0)), (3, col))
    if kind in ("circle", "ring"):
        cx, cy = frame.px(area["cx"], area["cz"])
        radii = [shape["r"]] if kind == "circle" else list(shape["r"])
        for r in radii:
            r = r - inset
            if r <= 2:
                continue
            for w, c in widths:
                d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=w)
    elif kind == "band":
        xs = [area["cx"] + s for s in shape["side"]]
        zs = [area["cz"] + area["sign"] * f for f in shape["forward"]]
        (ax, ay), (bx, by) = frame.px(min(xs), max(zs)), frame.px(max(xs), min(zs))
        for w, c in widths:
            d.rectangle([ax + inset, ay + inset, bx - inset, by - inset], outline=c, width=w)
        ox, oy = frame.px(area["cx"], area["cz"])
        d.line([(ox - 6, oy), (ox + 6, oy)], fill=(0, 0, 0), width=2)
        d.line([(ox, oy - 6), (ox, oy + 6)], fill=(0, 0, 0), width=2)


def short_levels(levels):
    return "L%d–%d" % tuple(levels) if levels[0] != levels[1] else "L%d" % levels[0]


def kilo(n):
    return "%.1fk" % (n / 1000.0) if n >= 1000 else str(n)


def pct(v):
    return "%d%%" % round(100 * v)


# --------------------------------------------------------------------------
# one zone
# --------------------------------------------------------------------------

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


def render(zone, design, atlas, atlas_dir, grid, out_dir):
    zone_json = json.load(open(atlas_dir / ("%s.json" % zone)))
    info = atlas.zones[zone]
    if grid is not None:
        frame = Frame(zone_json["extent"], grid.min_x, grid.min_z, grid.step, grid.cols, grid.rows)
    else:
        frame = Frame(zone_json["extent"])
    base = Image.open(atlas_dir / "maps" / ("%s.png" % zone)).convert("RGB")
    if base.size != frame.canvas:
        raise C.LoadError("%s: atlas map is %dx%d, the frame says %dx%d (atlas rebuilt with another grid?)"
                          % (zone, base.size[0], base.size[1], frame.canvas[0], frame.canvas[1]))
    src = np.asarray(base.crop((LEFT, TOP, LEFT + frame.w, TOP + frame.h))).astype(float)
    world = World(grid, frame, zone_json["numeric_id"], zone_json) if grid is not None else None
    if world is not None:
        zone_px = frame.to_px(world.own)
    else:
        # The zone's own land is tinted by its level colours; water is blue,
        # other zones grey.
        r, b = src[..., 0], src[..., 2]
        zone_px = (r - b > 30) & (r > 120)
    X, Z = frame.world_grid()

    # Muted base so the overlay stands out.
    gray = src.mean(axis=2, keepdims=True)
    rgb = (src * 0.45 + gray * 0.55) * 0.85 + 255 * 0.15

    spawns = design.spawns.get(zone) or {}
    sign = info["front_sign"]
    areas, problems = [], []
    for i, row in enumerate(a for a in spawns.get("areas") or [] if isinstance(a, dict)):
        area = dict(row)
        area["n"] = i + 1
        area["flags"] = []
        pos = atlas.position(zone, row.get("anchor"))
        offset = row.get("offset") if isinstance(row.get("offset"), list) and len(row.get("offset")) == 2 else [0, 0]
        if not shape_ok(row.get("shape")):
            area["flags"].append("shape not drawable")
        if pos is None:
            area["flags"].append("anchor %r unresolved" % row.get("anchor"))
        if area["flags"]:
            area["drawn"] = False
            areas.append(area)
            continue
        area["drawn"] = True
        area["cx"], area["cz"], area["sign"] = pos[0] + offset[0], pos[1] + offset[1], sign
        if area.get("clock") not in CLOCK_RGB:
            area["clock"] = "both"
        areas.append(area)

    # Fills (clipped to the zone's land), hatching for `zone` and the fallback.
    hatched = hatch(zone_px.shape)
    for area in areas:
        if not area["drawn"]:
            continue
        mask = shape_mask(area, X, Z) & zone_px
        col = CLOCK_RGB[area["clock"]]
        if area["shape"]["kind"] == "zone" or area.get("fallback"):
            blend(rgb, mask & hatched, col, HATCH_ALPHA)
        else:
            blend(rgb, mask, col, FILL_ALPHA)
        if world is not None:
            area["stats"] = world.area_stats(area)
            area["flags"] += area["stats"]["flags"]

    mapimg = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    md = ImageDraw.Draw(mapimg)
    seen = {}
    for area in areas:
        if not area["drawn"] or area["shape"]["kind"] == "zone":
            continue
        key = (area["cx"], area["cz"], json.dumps(area["shape"], sort_keys=True))
        inset = 5 * seen.get(key, 0)
        seen[key] = seen.get(key, 0) + 1
        outline(md, area, frame, inset, CLOCK_RGB[area["clock"]])

    W0, H0 = frame.canvas
    lines = panel_lines(zone, zone_json, design, atlas, areas, spawns, world, problems)
    panel_h = 90 + 16 * len(lines)
    canvas = Image.new("RGB", (W0 + PANEL_W, max(H0, panel_h)), (250, 250, 247))
    canvas.paste(base, (0, 0))
    canvas.paste(mapimg, (LEFT, TOP))
    d = ImageDraw.Draw(canvas)
    d.rectangle([LEFT, TOP, LEFT + frame.w, TOP + frame.h], outline=(0, 0, 0), width=1)
    fs, fb = BA.font(12), BA.font(13, True)
    placer = Placer(d, (LEFT, TOP, LEFT + frame.w, TOP + frame.h))

    def P(x, z):
        px, py = frame.px(x, z)
        return LEFT + px, TOP + py

    def inside(x, y):
        return LEFT <= x <= LEFT + frame.w and TOP <= y <= TOP + frame.h

    # Markers first (labels avoid them): camps, leaders, givers.
    for area in areas:
        if area["drawn"] and area.get("camp"):
            x, y = P(area["cx"], area["cz"])
            if inside(x, y):
                draw_tent(d, x, y)
                placer.block((x - 8, y - 8, x + 8, y + 8))
    leader_marks = []
    sub = design.subtype_map()
    for leader in spawns.get("leaders") or []:
        if not isinstance(leader, dict):
            continue
        pos = atlas.position(zone, leader.get("anchor"))
        off = leader.get("offset") if isinstance(leader.get("offset"), list) else [0, 0]
        name = (sub.get(leader.get("role")) or {}).get("display") or leader.get("role")
        if pos is None:
            continue
        lx, lz = pos[0] + off[0], pos[1] + off[1]
        x, y = P(lx, lz)
        if inside(x, y):
            draw_skull(d, x, y)
            placer.block((x - 9, y - 9, x + 9, y + 11))
            leader_marks.append((x, y, "%s L%s" % (name, leader.get("level"))))
    giver_marks = []
    npcs, sockets = zone_quest_givers(zone_json)
    for hub in (design.quests.get(zone) or {}).get("hubs") or []:
        hub_anchor = atlas.resolve_anchor(zone, hub.get("anchor"))
        for giver in hub.get("givers") or []:
            npc = giver.get("npc")
            where = None
            if isinstance(giver.get("new"), dict):
                xz = sockets.get((hub_anchor, giver["new"].get("socket")))
                if xz:
                    where = (xz[0], xz[1], giver["new"].get("name") or npc)
            else:
                where = npcs.get(npc)
            if where is None:
                continue
            x, y = P(where[0], where[1])
            if inside(x, y):
                draw_giver(d, x, y, fb)
                placer.block((x - 8, y - 8, x + 8, y + 8))
                giver_marks.append((x, y, "! %s: %s" % (where[2], ", ".join(giver.get("lines") or []))))

    for x, y, text in leader_marks:
        placer.place(x, y, text, fb, (0, 0, 0), near=12)
    for x, y, text in giver_marks:
        placer.place(x, y, text, fb, (90, 60, 0), near=10)
    for area in areas:
        if not area["drawn"]:
            continue
        lx, ly = label_point(area, frame, zone_px)
        x, y = LEFT + lx, TOP + ly
        if not inside(x, y):
            continue
        text = "%d %s %s: %s" % (area["n"], area["id"], short_levels(area["levels"]),
                                 ", ".join(sp.get("role", "?") for sp in area.get("species") or []))
        if area.get("camp"):
            text += " [camp %s]" % area["camp"].get("slots")
        if area.get("fallback"):
            text += " (fallback)"
        if not placer.place(x, y, text, fs, CLOCK_TEXT[area["clock"]], near=4):
            BA.text_halo(d, (x - 4, y - 7), str(area["n"]), fb, fill=CLOCK_TEXT[area["clock"]])

    draw_panel(d, W0 + 10, lines, fs, fb, zone_json, info)
    out = out_dir / ("%s.design.png" % zone)
    BA.save_png(canvas, out)
    return out, areas, problems


def panel_lines(zone, zone_json, design, atlas, areas, spawns, world, problems):
    """(kind, text, colour) rows of the side panel."""
    rows = []
    sub = design.subtype_map()

    def add(text, col=(0, 0, 0), kind="text", indent=0):
        for k, part in enumerate(textwrap.wrap(text, 84 - indent) or [""]):
            rows.append((kind if k == 0 else "text", ("  " * indent if k == 0 else "  " * (indent + 1)) + part, col))

    rows.append(("head", "Areas", (0, 0, 0)))
    for area in areas:
        clock = area.get("clock") if area.get("clock") in CLOCK_RGB else "both"
        shape = area.get("shape") or {}
        kind = shape.get("kind")
        geo = {"circle": "circle r%s" % shape.get("r"), "ring": "ring r%s" % shape.get("r"),
               "band": "band fwd %s side %s" % (shape.get("forward"), shape.get("side")),
               "zone": "whole zone"}.get(kind, "?")
        species = ", ".join("%s×%s" % (sp.get("role"), sp.get("weight")) for sp in area.get("species") or [])
        hosts = area.get("hosts") or {}
        host = "/".join(hosts.get("biomes") or ["?"]) + (" +shore" if hosts.get("shore") else "")
        extra = []
        if area.get("camp"):
            extra.append("camp %s slots" % area["camp"].get("slots"))
        if area.get("fallback"):
            extra.append("fallback")
        if area.get("cap"):
            extra.append("cap %s" % area["cap"])
        add("%d %s · %s · %s · %s @%s%s" % (area["n"], area.get("id"), clock, short_levels(area.get("levels") or [0, 0]),
                                           geo, area.get("anchor"),
                                           " %+d,%+d" % tuple(area["offset"]) if area.get("offset") and any(area["offset"]) else ""),
            CLOCK_TEXT[clock], kind="swatch:" + clock)
        add("%s · hosts %s%s" % (species, host, " · " + ", ".join(extra) if extra else ""), (60, 60, 60), indent=1)
        st = area.get("stats")
        if st and st.get("cells"):
            add("zone land %s · water %s · other zones %s · protected %s · spawnable ~%s nodes²"
                % (pct(st["own"]), pct(st["water"]), pct(st["other"]), pct(st["protected"]), kilo(st["host_nodes"])),
                (60, 60, 60), indent=1)
        for flag in area.get("flags") or []:
            add("! " + flag, FLAG_RGB, indent=1)
            problems.append("area %s: %s" % (area.get("id"), flag))
    rows.append(("gap", "", None))
    rows.append(("head", "Leaders", (0, 0, 0)))
    for leader in spawns.get("leaders") or []:
        if not isinstance(leader, dict):
            continue
        name = (sub.get(leader.get("role")) or {}).get("display") or leader.get("role")
        pos = atlas.position(zone, leader.get("anchor"))
        off = leader.get("offset") if isinstance(leader.get("offset"), list) else [0, 0]
        add("%s (%s) L%s · respawn %s s · @%s %+d,%+d" % (name, leader.get("role"), leader.get("level"),
                                                         leader.get("respawn"), leader.get("anchor"), off[0], off[1]),
            kind="skull")
        flag = None
        if pos is None:
            flag = "anchor %r unresolved" % leader.get("anchor")
        elif world is not None:
            where = world.cell_class(pos[0] + off[0], pos[1] + off[1])
            if where:
                flag = "stands on %s" % where
        if flag:
            add("! " + flag, FLAG_RGB, indent=1)
            problems.append("leader %s: %s" % (leader.get("role"), flag))
    rows.append(("gap", "", None))
    rows.append(("head", "Quest hubs", (0, 0, 0)))
    npcs, sockets = zone_quest_givers(zone_json)
    for hub in (design.quests.get(zone) or {}).get("hubs") or []:
        add("%s @%s" % (hub.get("id"), hub.get("anchor")))
        hub_anchor = atlas.resolve_anchor(zone, hub.get("anchor"))
        for giver in hub.get("givers") or []:
            npc = giver.get("npc")
            if isinstance(giver.get("new"), dict):
                name = "%s (new, socket %s)" % (giver["new"].get("name"), giver["new"].get("socket"))
                found = (hub_anchor, giver["new"].get("socket")) in sockets
            else:
                name = (npcs.get(npc) or (0, 0, npc))[2]
                found = npc in npcs
            add("%s (%s): %s" % (name, npc, ", ".join(giver.get("lines") or [])), kind="giver", indent=1)
            if not found:
                add("! not found among this zone's quest NPCs in the atlas", FLAG_RGB, indent=2)
                problems.append("giver %s: not in the atlas zone" % npc)
    if world is None:
        rows.append(("gap", "", None))
        add("(no --grid: no geometry numbers; fill mask from the map colours)", (90, 90, 90))
    return rows


def draw_panel(d, x0, rows, fs, fb, zone_json, info):
    y = 12
    d.text((x0, y), "Design overlay · %s" % zone_json["name"], font=BA.font(16, True), fill=(0, 0, 0))
    y += 24
    axis = "+z (north, up)" if info["front_sign"] > 0 else "-z (south, down)"
    d.text((x0, y), "band forward = %s · side = +x (east) · from anchor + offset (cross)" % axis,
           font=fs, fill=(60, 60, 60))
    y += 20
    # legend
    lx = x0
    for clock in ("day", "night", "both"):
        d.rectangle([lx, y, lx + 22, y + 12], fill=CLOCK_RGB[clock], outline=(0, 0, 0))
        d.text((lx + 28, y - 1), clock, font=fs, fill=(0, 0, 0))
        lx += 80
    for i in range(4):
        d.line([(lx + i * 6, y + 12), (lx + i * 6 + 8, y)], fill=CLOCK_RGB["both"], width=2)
    d.text((lx + 28, y - 1), "zone / fallback (hatched)", font=fs, fill=(0, 0, 0))
    y += 18
    lx = x0
    draw_tent(d, lx + 10, y + 7)
    d.text((lx + 22, y), "camp", font=fs, fill=(0, 0, 0))
    draw_skull(d, lx + 80, y + 6, s=6)
    d.text((lx + 92, y), "leader", font=fs, fill=(0, 0, 0))
    draw_giver(d, lx + 160, y + 7, fb)
    d.text((lx + 172, y), "quest giver: lines", font=fs, fill=(0, 0, 0))
    d.text((lx + 310, y), "fill = shape on the zone's land", font=fs, fill=(0, 0, 0))
    y += 26
    for kind, text, col in rows:
        if kind == "gap":
            y += 6
            continue
        if kind == "head":
            d.text((x0, y), text, font=fb, fill=col)
            y += 18
            continue
        tx = x0
        if kind.startswith("swatch:"):
            d.rectangle([x0, y + 1, x0 + 10, y + 11], fill=CLOCK_RGB[kind[7:]], outline=(0, 0, 0))
            tx += 14
        elif kind == "skull":
            draw_skull(d, x0 + 5, y + 5, s=5)
            tx += 14
        d.text((tx, y), text, font=fs, fill=col)
        y += 16


# --------------------------------------------------------------------------

def parse(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN), help="design directory (default: the repo's)")
    ap.add_argument("--atlas", default=str(DEFAULT_ATLAS), help="zone atlas directory with maps/ (default: the repo's)")
    ap.add_argument("--grid", help="sample.lua output (meta.json + grid_*.bin) for geometry numbers")
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
    grid = BA.Grid(args.grid) if args.grid else None
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
            path, areas, problems = render(zone, design, atlas, atlas_dir, grid, out_dir)
        except C.LoadError as err:
            print("error: %s" % err, file=sys.stderr)
            status = 1
            continue
        print("%s: %d areas -> %s" % (zone, len(areas), path))
        for problem in problems:
            print("  ! %s" % problem)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
