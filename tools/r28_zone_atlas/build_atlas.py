#!/usr/bin/env python3
"""Round 28 Lane C0: build the zone facts atlas (Markdown, JSON, PNG maps).

Inputs (see run.sh):
  --grid DIR    output of sample.lua (meta.json + grid_<band>.bin)
  --probe FILE  output of probe.sh (probe.json)
  --out DIR     docs/planning/round28/zones

Writes <out>/index.md, <out>/<zone_id>.md, <out>/<zone_id>.json,
<out>/maps/<zone_id>.png and <out>/maps/world.png. Pure numpy + Pillow.
"""
import argparse
import collections
import glob
import heapq
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_DIR = "/usr/share/fonts/dejavu-sans-fonts"


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, name), size)
    except OSError:
        return ImageFont.load_default()


# --------------------------------------------------------------------------
# static game facts (seed-independent; from the source files named)
# --------------------------------------------------------------------------

# Race tracks (simple_map.lua zone rows, plan Section C3).
TRACKS = {
    "dwarf": ["elandor_hearthpine_vale", "elandor_copperfell_foothills", "elandor_dur_brannoc",
              "elandor_frostbarrow_shelf", "elandor_stormvault_heights"],
    "human": ["elandor_dawnmere_fields", "elandor_goldmead_vale", "elandor_highcourt",
              "elandor_whitebridge_shire", "elandor_ashenward_march"],
    "elf": ["elandor_silverleaf_glades", "elandor_starbough_vale", "elandor_lethariel",
            "elandor_lorindor", "elandor_moonfall_wood", "elandor_glassroot_wilds"],
    "undead": ["kragmar_stillgrave_hollow", "kragmar_mournfen", "kragmar_nhal_veyr",
               "kragmar_ossuary_reach", "kragmar_blackwind_rise"],
    "orc": ["kragmar_sunscar_flats", "kragmar_redtusk_savanna", "kragmar_gor_drazhak",
            "kragmar_speargrass_reach", "kragmar_bannerbreak_mesa"],
    "troll": ["kragmar_kapok_cradle", "kragmar_raincall_basin", "kragmar_kezamba",
              "kragmar_whispering_reedlands", "kragmar_totemwater_reach",
              "kragmar_thunderroot_wilds"],
}

ANCHOR_KIND_TEXT = {
    "start": "start town", "capital_dwarf": "capital", "capital_human": "capital",
    "capital_elf": "capital", "capital_undead": "capital", "capital_orc": "capital",
    "capital_troll": "capital", "village": "village", "outpost": "outpost", "mine": "mine",
    "bandit_home": "bandit camp", "bandit_frontier": "bandit hideout", "mirefolk": "mirefolk camp",
    "clash": "clash site", "dragon": "dragon arena", "apex_mine": "apex mine camp",
    "rare_route": "rare route",
}

MARKER = {  # kind group -> (shape, fill)
    "start": ("star", (255, 200, 0)), "capital": ("square", (120, 60, 160)),
    "village": ("circle", (40, 150, 60)), "outpost": ("triangle", (40, 100, 200)),
    "mine": ("diamond", (130, 80, 40)), "bandit": ("x", (200, 30, 30)),
    "mirefolk": ("x", (0, 140, 140)), "clash": ("plus", (230, 110, 0)),
    "dragon": ("triangle", (20, 20, 20)), "apex": ("diamond", (90, 90, 90)),
    "rare": ("circle", (230, 60, 160)), "hub": ("ring", (0, 0, 0)),
}


def marker_group(kind):
    if kind.startswith("capital"):
        return "capital"
    return {"start": "start", "village": "village", "outpost": "outpost", "mine": "mine",
            "bandit_home": "bandit", "bandit_frontier": "bandit", "mirefolk": "mirefolk",
            "clash": "clash", "dragon": "dragon", "apex_mine": "apex",
            "rare_route": "rare"}.get(kind, "hub")


SOCKET_ROLE_TEXT = {
    "quest": "quest giver", "vendor": "vendor", "trainer": "profession trainer",
    "innkeeper": "innkeeper (respawn bind)", "riding_trainer": "riding trainer",
    "housing_manager": "housing steward", "king": "king", "public_station": "public station",
    "mount_display": "mount display", "gear_display": "gear display",
}

# Top node of each logical biome (r7_r6_manifest.lua SURFACE_ROWS).
BIOME_TOP = {
    "grug_badlands": "grug_nodes:mesa_clay", "grug_badlands_east": "grug_nodes:mesa_clay",
    "grug_beach": "default:sand", "grug_blight": "grug_nodes:blight_dirt",
    "grug_bone_forest": "grug_nodes:dirt_with_bone_litter", "grug_crags": "default:gravel",
    "grug_crags_snowy": "default:snowblock", "grug_deep_forest": "grug_nodes:dirt_with_forest_litter",
    "grug_deep_jungle": "grug_nodes:dirt_with_canopy_litter",
    "grug_elf_forest": "grug_nodes:dirt_with_silver_litter",
    "grug_jungle_edge": "default:dirt_with_rainforest_litter",
    "grug_jungle_fringe": "grug_nodes:dirt_with_canopy_litter", "grug_meadows": "default:dirt_with_grass",
    "grug_pine_hills": "default:dirt_with_coniferous_litter",
    "grug_savanna": "default:dry_dirt_with_dry_grass", "grug_swamp": "grug_nodes:mud",
}

# Zones whose palette has `war` or `mountain` (spawn_policy.lua): there the
# skeleton archer's own check admits every host node of its rows.
WAR_OR_MOUNTAIN_ZONES = {
    "elandor_frostbarrow_shelf", "elandor_stormvault_heights", "elandor_ashenward_march",
    "kragmar_speargrass_reach", "kragmar_bannerbreak_mesa", "front_wyrmglass_crown",
    "front_gravesalt_escarpment", "front_broken_causeway", "front_shattered_line",
    "front_skyglass_canopy", "front_stormscale_summit",
}

WATER_NAMES = {1: "deep_ocean", 2: "coastal_shelf", 3: "bay_water", 4: "land",
               5: "dragon_channel", 6: "inland_water"}


# --------------------------------------------------------------------------
# grid helpers
# --------------------------------------------------------------------------

class Grid:
    def __init__(self, directory):
        self.meta = json.load(open(os.path.join(directory, "meta.json")))
        m = self.meta
        files = sorted(glob.glob(os.path.join(directory, "grid_*.bin")),
                       key=lambda p: int(p.rsplit("_", 1)[1].split(".")[0]))
        raw = np.concatenate([np.fromfile(f, dtype=np.uint8) for f in files])
        raw = raw.reshape(m["rows"], m["cols"], 8)
        self.step, self.min_x, self.min_z = m["step"], m["min_x"], m["min_z"]
        self.rows, self.cols = m["rows"], m["cols"]
        self.zone = raw[..., 0].copy()
        self.wc = raw[..., 1].copy()
        self.h = raw[..., 2:4].copy().view("<i2")[..., 0].astype(np.int32)
        self.level = raw[..., 4].copy()
        self.coast = raw[..., 5].copy()
        self.biome = raw[..., 6].copy()
        self.prot = raw[..., 7].copy()
        self.land = self.wc == 4
        self.sea = np.isin(self.wc, [1, 2, 3, 5])
        self.inland = self.wc == 6
        xs = self.min_x + np.arange(self.cols) * self.step
        zs = self.min_z + np.arange(self.rows) * self.step
        self.X, self.Z = np.meshgrid(xs, zs)

    def cell(self, x, z):
        c = int(round((x - self.min_x) / self.step))
        r = int(round((z - self.min_z) / self.step))
        return min(max(r, 0), self.rows - 1), min(max(c, 0), self.cols - 1)

    def at(self, arr, x, z):
        r, c = self.cell(x, z)
        return arr[r, c]


def shift_or(mask, offsets):
    out = mask.copy()
    rows, cols = mask.shape
    for dr, dc in offsets:
        src = mask[max(0, -dr):rows - max(0, dr), max(0, -dc):cols - max(0, dc)]
        out[max(0, dr):rows - max(0, -dr), max(0, dc):cols - max(0, -dc)] |= src
    return out


def dilate_disk(mask, radius):
    offs = [(dr, dc) for dr in range(-radius, radius + 1) for dc in range(-radius, radius + 1)
            if dr * dr + dc * dc <= radius * radius and (dr or dc)]
    return shift_or(mask, offs)


def dilate_square(mask, radius):
    m = shift_or(mask, [(0, d) for d in range(-radius, radius + 1) if d])
    return shift_or(m, [(d, 0) for d in range(-radius, radius + 1) if d])


def components(mask):
    """8-connected components of a boolean mask: list of (rows, cols) arrays."""
    seen = np.zeros(mask.shape, dtype=bool)
    out = []
    rr, cc = np.nonzero(mask)
    rows, cols = mask.shape
    for r0, c0 in zip(rr.tolist(), cc.tolist()):
        if seen[r0, c0]:
            continue
        stack, pr, pc = [(r0, c0)], [], []
        seen[r0, c0] = True
        while stack:
            r, c = stack.pop()
            pr.append(r)
            pc.append(c)
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < rows and 0 <= nc < cols and mask[nr, nc] and not seen[nr, nc]:
                        seen[nr, nc] = True
                        stack.append((nr, nc))
        out.append((np.array(pr), np.array(pc)))
    return out


def bearing(dx, dz):
    """Compass word for an offset (+z = north, +x = east)."""
    if dx == 0 and dz == 0:
        return "-"
    ang = math.degrees(math.atan2(dx, dz)) % 360
    names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return names[int((ang + 22.5) // 45) % 8]


def rdp(points, eps):
    if len(points) < 3:
        return points
    (x1, z1), (x2, z2) = points[0], points[-1]
    dx, dz = x2 - x1, z2 - z1
    norm = math.hypot(dx, dz) or 1.0
    best, idx = -1, 0
    for i in range(1, len(points) - 1):
        px, pz = points[i]
        d = abs(dz * (px - x1) - dx * (pz - z1)) / norm
        if d > best:
            best, idx = d, i
    if best > eps:
        return rdp(points[:idx + 1], eps)[:-1] + rdp(points[idx:], eps)
    return [points[0], points[-1]]


def plen(points):
    return sum(math.hypot(points[i + 1][0] - points[i][0], points[i + 1][1] - points[i][1])
               for i in range(len(points) - 1))


# --------------------------------------------------------------------------
# road graph (straight segments between centreline points, junctions joined)
# --------------------------------------------------------------------------

class RoadGraph:
    def __init__(self, roads):
        self.nodes, self.adj = [], []
        hashmap = collections.defaultdict(list)
        for road in roads:
            prev = None
            for x, z in road["points"]:
                i = len(self.nodes)
                self.nodes.append((x, z, road["id"]))
                self.adj.append([])
                if prev is not None:
                    d = math.hypot(x - self.nodes[prev][0], z - self.nodes[prev][1])
                    self.adj[i].append((prev, d))
                    self.adj[prev].append((i, d))
                prev = i
                hashmap[(x // 8, z // 8)].append(i)
        # junctions: points of different roads within 4 nodes
        for i, (x, z, rid) in enumerate(self.nodes):
            for hx in (x // 8 - 1, x // 8, x // 8 + 1):
                for hz in (z // 8 - 1, z // 8, z // 8 + 1):
                    for j in hashmap.get((hx, hz), ()):
                        if j > i and self.nodes[j][2] != rid:
                            d = math.hypot(x - self.nodes[j][0], z - self.nodes[j][1])
                            if d <= 4:
                                self.adj[i].append((j, d))
                                self.adj[j].append((i, d))
        self.hash = hashmap
        # a road that joins another ends at that road's edge, not on its
        # centreline: join both ends of every road to the nearest point of
        # another road within 12 nodes
        start = 0
        for road in roads:
            n = len(road["points"])
            for i in (start, start + n - 1):
                x, z, rid = self.nodes[i]
                best, bj = None, None
                for hx in (x // 8 - 2, x // 8 - 1, x // 8, x // 8 + 1, x // 8 + 2):
                    for hz in (z // 8 - 2, z // 8 - 1, z // 8, z // 8 + 1, z // 8 + 2):
                        for j in hashmap.get((hx, hz), ()):
                            if self.nodes[j][2] != rid:
                                d = math.hypot(x - self.nodes[j][0], z - self.nodes[j][1])
                                if d <= 12 and (best is None or d < best):
                                    best, bj = d, j
                if bj is not None:
                    self.adj[i].append((bj, best))
                    self.adj[bj].append((i, best))
            start += n

    def nearest(self, x, z, reach=120):
        best, bi = None, None
        for hx in range(int(x // 8) - reach // 8, int(x // 8) + reach // 8 + 1):
            for hz in range(int(z // 8) - reach // 8, int(z // 8) + reach // 8 + 1):
                for j in self.hash.get((hx, hz), ()):
                    d = math.hypot(x - self.nodes[j][0], z - self.nodes[j][1])
                    if best is None or d < best:
                        best, bi = d, j
        return bi, best

    def dijkstra(self, src):
        dist = {src: 0.0}
        heap = [(0.0, src)]
        while heap:
            d, i = heapq.heappop(heap)
            if d > dist.get(i, 1e18):
                continue
            for j, w in self.adj[i]:
                nd = d + w
                if nd < dist.get(j, 1e18):
                    dist[j] = nd
                    heapq.heappush(heap, (nd, j))
        return dist


# --------------------------------------------------------------------------
# main build
# --------------------------------------------------------------------------

def build(args):
    G = Grid(args.grid)
    meta = G.meta
    probe = json.load(open(args.probe))
    out = args.out
    os.makedirs(os.path.join(out, "maps"), exist_ok=True)
    seed = str(meta["seed"])
    assert str(probe["seed"]) == seed, "grid and probe seeds differ"

    zones = {z["id"]: z for z in meta["zones"]}
    zone_by_num = {z["numeric_id"]: z for z in meta["zones"]}
    anchors = meta["anchors"]
    anchor_by_id = {a["id"]: a for a in anchors}
    anchor_by_xz = {(a["x"], a["z"]): a for a in anchors}
    biome_names = meta["biomes"]

    # core.write_json writes empty tables as null
    for s in probe["settlements"]:
        s["sockets"] = s.get("sockets") or []
        s["counts"] = s.get("counts") or {}
    for z in probe["zones"]:
        for k in ("day_cast", "night_cast", "density_day", "density_night", "spawns", "level_histogram"):
            z[k] = z.get(k) or []
    for q in probe["quests"]:
        q["prerequisites"] = q.get("prerequisites") or []
        q["reward_items"] = q.get("reward_items") or []
    for r in probe["rares"]:
        r["route"] = r.get("route") or []
    for row in probe["spawn_rows"]:
        row["nodenames"] = row.get("nodenames") or []

    # settlements (probe) <-> anchors (sampler)
    settlements = probe["settlements"]
    for s in settlements:
        a = anchor_by_xz.get((s["anchor"]["x"], s["anchor"]["z"]))
        s["anchor_id"] = a["id"] if a else None
        s["zone_id"] = a["zone_id"] if a else None
        if a:
            a["settlement_key"] = s["key"]
            a["settlement_name"] = s["display_name"]
    settlement_by_key = {s["key"]: s for s in settlements}
    feature_box_by_key = {b["key"]: b for b in probe["feature_boxes"]}

    quest_npcs = {n["id"]: n for n in probe["quest_npcs"]}
    npc_by_socket = {(n["settlement"], n["socket"]): n for n in probe["quest_npcs"]}
    quests = probe["quests"]
    quests_by_giver = collections.defaultdict(list)
    for q in quests:
        quests_by_giver[q["npc"]].append(q)
    mobs = {m["name"]: m for m in probe["mobs"]}
    hosts = collections.defaultdict(set)   # surface spawn rows only
    for row in probe["spawn_rows"]:
        if row.get("max_y") is None or row["max_y"] >= 0:
            for n in row["nodenames"]:
                hosts[row["name"]].add(n)
    zone_probe = {z["id"]: z for z in probe["zones"]}
    camp_types = {c["id"]: c for c in probe["camp_types"]}

    def mob_name(name):
        m = mobs.get(name)
        return (m and m.get("description")) or name.split(":")[-1]

    # ---------------- rasters ----------------
    step = G.step
    road_mask = np.zeros(G.land.shape, dtype=bool)      # protected road ground (Ruling 1: hw+1)
    network_center = np.zeros(G.land.shape, dtype=bool)  # network road centre cells
    for road in meta["roads"]:
        reach = road["half_width"] + 1
        k = int(math.ceil(reach / step))
        for x, z in road["points"]:
            r, c = G.cell(x, z)
            if road["kind"] in ("primary", "secondary", "trail"):
                network_center[r, c] = True
            for dr in range(-k, k + 1):
                for dc in range(-k, k + 1):
                    cx = G.min_x + (c + dc) * step
                    cz = G.min_z + (r + dr) * step
                    if math.hypot(cx - x, cz - z) <= max(reach, step / 2):
                        rr, cc = r + dr, c + dc
                        if 0 <= rr < G.rows and 0 <= cc < G.cols:
                            road_mask[rr, cc] = True
    box_mask = np.zeros(G.land.shape, dtype=bool)
    village_mask = np.zeros(G.land.shape, dtype=bool)
    for b in probe["feature_boxes"]:
        r0, c0 = G.cell(b["min_x"], b["min_z"])
        r1, c1 = G.cell(b["max_x"], b["max_z"])
        box_mask[r0:r1 + 1, c0:c1 + 1] = True
        if b["kind"] == "village":
            village_mask[r0:r1 + 1, c0:c1 + 1] = True
    town_mask = G.prot == 1
    protected = (town_mask | road_mask | box_mask) & G.land
    drift_src = road_mask | town_mask | village_mask
    drift = dilate_disk(drift_src, 4) & G.land & ~protected   # <=16 nodes
    sand = G.land & (G.coast == 1)
    near_sea = dilate_square(G.sea, 15)                      # <=60 nodes from sea
    sea_beach = sand & near_sea
    bank_sand = sand & ~near_sea
    sea_edge = G.land & dilate_square(G.sea, 1)               # land cells touching sea
    other_zone_edge = {}
    gy, gx = np.gradient(G.h.astype(float))
    slope = np.hypot(gx, gy) / step                           # nodes per node

    # road graph and hub distances
    network_roads = [r for r in meta["roads"] if r["kind"] in ("primary", "secondary", "trail")]
    all_roads = meta["roads"]
    graph = RoadGraph(all_roads)
    hub_settlements = [s for s in settlements if s["anchor_id"] and any(
        k.get("role") in ("quest", "vendor", "trainer", "innkeeper") for k in s["sockets"])]
    attach = {}
    for s in settlements:
        i, d = graph.nearest(s["anchor"]["x"], s["anchor"]["z"])
        attach[s["key"]] = (i, d)
    road_dist = {}
    for s in hub_settlements:
        i, d0 = attach[s["key"]]
        if i is None or d0 > 120:
            continue
        dist = graph.dijkstra(i)
        for t in hub_settlements:
            j, d1 = attach[t["key"]]
            if j is not None and d1 <= 120 and j in dist and t["key"] != s["key"]:
                road_dist[(s["key"], t["key"])] = round(dist[j] + d0 + d1)

    def zone_land(zid):
        return G.land & (G.zone == zones[zid]["numeric_id"])

    nz_cache = {}

    def nearest_in(mask, x, z, cache=False):
        if cache and id(mask) in nz_cache:
            rr, cc = nz_cache[id(mask)]
        else:
            rr, cc = np.nonzero(mask)
            if cache:
                nz_cache[id(mask)] = (rr, cc)
        if len(rr) == 0:
            return None
        xs = G.min_x + cc * step
        zs = G.min_z + rr * step
        d = np.hypot(xs - x, zs - z)
        i = int(np.argmin(d))
        return {"distance": int(round(d[i])), "x": int(xs[i]), "z": int(zs[i]),
                "bearing": bearing(int(xs[i]) - x, int(zs[i]) - z)}

    def ray(zid, x, z, dx, dz, limit=3000):
        """Walk from (x, z) until the column leaves the zone's land (own rivers and
        lakes are crossed): distance and what is hit (other zone, sea or bay)."""
        num = zones[zid]["numeric_id"]
        for t in range(0, limit, 4):
            px, pz = x + dx * t, z + dz * t
            r, c = G.cell(px, pz)
            if not ((G.land[r, c] or G.inland[r, c]) and G.zone[r, c] == num):
                w = int(G.wc[r, c])
                if w == 4:
                    what = zone_by_num.get(int(G.zone[r, c]), {}).get("id", "?")
                else:
                    what = WATER_NAMES.get(w, "?")
                return {"distance": t, "hits": what}
        return {"distance": limit, "hits": "limit"}

    # ---------------- per zone ----------------
    zone_facts = {}
    for zid, z in zones.items():
        num = z["numeric_id"]
        zl = zone_land(zid)
        n_land = int(zl.sum())
        rr, cc = np.nonzero(zl)
        xs = G.min_x + cc * step
        zs = G.min_z + rr * step
        facts = {"id": zid, "numeric_id": num, "name": z["display_name"],
                 "faction": z["faction"], "race_region": z["race_region"],
                 "territory_rule": z["territory_rule"], "pvp_rule": z["pvp_rule"],
                 "level_min": z["level_min"], "level_max": z["level_max"],
                 "relief_profile": z["relief"], "hub": z["hub"],
                 "civic_no_hostiles": z["civic_no_hostiles"],
                 "neighbors": z["neighbors"], "biomes_authored": z["biomes"]}
        facts["extent"] = {"min_x": int(xs.min()), "max_x": int(xs.max()),
                           "min_z": int(zs.min()), "max_z": int(zs.max()),
                           "land_area_nodes2": n_land * step * step,
                           "centroid": {"x": int(xs.mean()), "z": int(zs.mean())}}
        # biomes measured
        bc = collections.Counter(G.biome[zl].tolist())
        facts["biomes_measured"] = [{"id": biome_names[b - 1], "share_pct": round(100 * n / n_land, 1)}
                                    for b, n in bc.most_common() if b > 0]
        # relief
        hh = G.h[zl] - 1
        sl = slope[zl]
        facts["relief"] = {
            "height_above_sea": {"min": int(hh.min()), "p10": int(np.percentile(hh, 10)),
                                 "median": int(np.median(hh)), "p90": int(np.percentile(hh, 90)),
                                 "max": int(hh.max())},
            "steep_share_pct": round(100 * float((sl > 1.0).mean()), 1),
            "cliff_share_pct": round(100 * float((sl > 2.0).mean()), 1)}
        # level field
        lv = G.level[zl]
        lc = collections.Counter(lv.tolist())
        facts["level_field"] = {
            "histogram_pct": {int(k): round(100 * v / n_land, 1) for k, v in sorted(lc.items()) if k},
            "min": int(lv[lv > 0].min()) if (lv > 0).any() else None,
            "max": int(lv.max())}
        # coast
        zsea_edge = sea_edge & (G.zone == num)
        zbeach = sea_beach & (G.zone == num)
        zbank = bank_sand & (G.zone == num)
        facts["coast"] = {
            "sea_coast_length_nodes": int(zsea_edge.sum()) * step,
            "sea_beach_sand_area_nodes2": int(zbeach.sum()) * step * step,
            "bank_sand_area_nodes2": int(zbank.sum()) * step * step,
            "inland_water_area_nodes2": int((G.inland & (G.zone == num)).sum()) * step * step,
            "bay_water_area_nodes2": int(((G.wc == 3) & (G.zone == num)).sum()) * step * step,
            "beaches": []}
        beaches = []
        for br, bcl in components(zbeach):
            if len(br) < 8:
                continue
            bx = G.min_x + bcl * step
            bz = G.min_z + br * step
            blv = G.level[br, bcl]
            beaches.append({"cells": len(br), "area_nodes2": len(br) * step * step,
                            "centroid": {"x": int(bx.mean()), "z": int(bz.mean())},
                            "box": {"min_x": int(bx.min()), "max_x": int(bx.max()),
                                    "min_z": int(bz.min()), "max_z": int(bz.max())},
                            "levels": [int(blv.min()), int(blv.max())]})
        beaches.sort(key=lambda b: -b["cells"])
        for i, b in enumerate(beaches[:12]):
            b["id"] = "B%d" % (i + 1)
            del b["cells"]
        facts["coast"]["beaches"] = beaches[:12]
        # protection and drift band
        facts["protected_share_pct"] = round(100 * float((protected & zl).sum()) / n_land, 1)
        facts["drift_band_share_pct"] = round(100 * float((drift & zl).sum()) / n_land, 1)
        # borders per neighbour
        borders = []
        zoneset = G.zone
        dil = dilate_square(zl, 1)
        for nid in z["neighbors"]:
            nm = G.land & (zoneset == zones[nid]["numeric_id"]) & dil
            if nm.any():
                br, bcl = np.nonzero(nm)
                borders.append({"zone": nid, "length_nodes": int(len(br)) * step,
                                "midpoint": {"x": int((G.min_x + bcl * step).mean()),
                                             "z": int((G.min_z + br * step).mean())}})
        facts["borders"] = borders
        zone_facts[zid] = facts

    # front direction per zone
    for zid, f in zone_facts.items():
        z = zones[zid]
        if z["macro_region"] == "elandor_mainland":
            f["front"] = {"axis": "+z", "text": "Battlegrounds lie north (+z); the home coast/ocean is south (-z)."}
        elif z["macro_region"] == "kragmar_mainland":
            f["front"] = {"axis": "-z", "text": "Battlegrounds lie south (-z); the home coast/ocean is north (+z)."}
        elif z["macro_region"] == "holy_grounds":
            f["front"] = {"axis": "z=0", "text": "Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north)."}
        else:
            f["front"] = {"axis": "island", "text": "Offshore dragon island, reached by boat from the Battlegrounds end zone (no land neighbours, no roads)."}

    # anchors per zone, with settlement and protected box
    for zid in zones:
        zone_facts[zid]["anchors"] = []
    for a in anchors:
        f = zone_facts[a["zone_id"]]
        row = {"id": a["id"], "slot": a["slot"], "kind": a["kind"],
               "kind_text": ANCHOR_KIND_TEXT.get(a["kind"], a["kind"]),
               "x": a["x"], "y": a["y"], "z": a["z"],
               "name": a.get("settlement_name") or a.get("label"),
               "settlement_key": a.get("settlement_key"),
               "level_at": int(G.at(G.level, a["x"], a["z"]))}
        fb = feature_box_by_key.get(a.get("settlement_key"))
        if fb:
            row["protected_box"] = {k: fb[k] for k in ("min_x", "max_x", "min_z", "max_z", "kind")}
        f["anchors"].append(row)

    # settlements, NPCs, quests per zone
    def quest_row(q):
        objs = []
        for o in q["objectives"]:
            if o["type"] == "kill":
                txt = "kill %d %s" % (o["count"], " or ".join(m.split(":")[-1] for m in o.get("mobs", [])))
                if o.get("zone"):
                    txt += " [in %s]" % o["zone"]
            elif o["type"] == "item":
                txt = "bring %d %s" % (o["count"], o["item"])
            else:
                npc = quest_npcs.get(o.get("npc"), {})
                txt = "talk to %s (%s)" % (npc.get("title", o.get("npc")), npc.get("settlement", "?"))
            objs.append(txt)
        return {"id": q["id"], "title": q["title"], "giver": q["npc"],
                "turnin": q["turnin_npc"], "min_level": q["min_level"], "xp": q["xp"],
                "copper": q["copper"], "prerequisites": q.get("prerequisites") or [],
                "objectives": objs, "objectives_raw": q["objectives"],
                "reward_items": q.get("reward_items") or [], "description": q["description"]}

    for zid in zones:
        zone_facts[zid]["settlements"] = []
        zone_facts[zid]["quests"] = []
    for s in settlements:
        if not s["zone_id"]:
            continue
        f = zone_facts[s["zone_id"]]
        npcs = []
        for k in s["sockets"]:
            role = k["role"]
            row = {"socket": k["id"], "role": role, "role_text": SOCKET_ROLE_TEXT.get(role, role),
                   "x": k["pos"]["x"], "y": k["pos"]["y"], "z": k["pos"]["z"]}
            if k.get("kind"):
                row["vendor_kind"] = k["kind"]
            if k.get("profession"):
                row["profession"] = k["profession"]
            if k.get("tag"):
                row["tag"] = k["tag"]
            qn = npc_by_socket.get((s["key"], k["id"]))
            if qn:
                row["npc_id"] = qn["id"]
                row["npc_name"] = qn["title"]
                row["quests"] = [q["id"] for q in quests_by_giver.get(qn["id"], [])]
            npcs.append(row)
        dists = []
        for t in hub_settlements:
            if t["key"] == s["key"]:
                continue
            straight = math.hypot(t["anchor"]["x"] - s["anchor"]["x"], t["anchor"]["z"] - s["anchor"]["z"])
            rd = road_dist.get((s["key"], t["key"]))
            dists.append({"to": t["key"], "name": t["display_name"], "zone": t["zone_id"],
                          "straight": int(round(straight)), "road": rd})
        # same faction first, then by road distance (straight where no road)
        own_faction = zones[s["zone_id"]]["faction"]
        dists.sort(key=lambda d: (zones[d["zone"]]["faction"] not in (own_faction, "contested"),
                                  d["road"] if d["road"] is not None else d["straight"] * 1.5))
        ax, az = s["anchor"]["x"], s["anchor"]["z"]
        zl = zone_land(s["zone_id"])
        other_land = G.land & (G.zone != zones[s["zone_id"]]["numeric_id"]) & (G.zone > 0)
        ri, rdd = attach[s["key"]]
        f["settlements"].append({
            "key": s["key"], "name": s["display_name"], "race": s["race_id"],
            "anchor_id": s["anchor_id"], "anchor": s["anchor"],
            "resident_counts": s["counts"], "npcs": npcs,
            "distances": {
                "nearest_other_zone_land": nearest_in(other_land, ax, az),
                "nearest_sea": nearest_in(G.sea, ax, az, True),
                "nearest_sea_beach_sand": nearest_in(sea_beach, ax, az, True),
                "nearest_road": {"distance": int(round(rdd))} if ri is not None else None,
                "to_zone_edge": {"north_+z": ray(s["zone_id"], ax, az, 0, 1),
                                 "south_-z": ray(s["zone_id"], ax, az, 0, -1),
                                 "east_+x": ray(s["zone_id"], ax, az, 1, 0),
                                 "west_-x": ray(s["zone_id"], ax, az, -1, 0)},
                "hubs": dists[:6]}})
        for k in s["sockets"]:
            qn = npc_by_socket.get((s["key"], k["id"]))
            if qn:
                for q in quests_by_giver.get(qn["id"], []):
                    row = quest_row(q)
                    row["giver_name"] = qn["title"]
                    row["giver_settlement"] = s["display_name"]
                    f["quests"].append(row)
    for f in zone_facts.values():
        f["quests"].sort(key=lambda q: (q["min_level"], q["id"]))

    # roads per zone
    for zid, f in zone_facts.items():
        num = zones[zid]["numeric_id"]
        rows_ = []
        streets = 0
        for road in all_roads:
            inside = []
            for x, z in road["points"]:
                r, c = G.cell(x, z)
                inside.append(bool(G.zone[r, c] == num and (G.land[r, c] or G.inland[r, c] or G.wc[r, c] == 3)))
            if not any(inside):
                continue
            if road["kind"] in ("avenue", "lane"):
                streets += 1
                continue
            pts = [tuple(p) for p, ins in zip(road["points"], inside) if ins]

            def end_name(e):
                if e in anchor_by_id:
                    a = anchor_by_id[e]
                    return "%s (%s, %s)" % (e, a.get("settlement_name") or a.get("label") or a["kind"], a["zone_id"])
                if e.startswith("road:"):
                    return "joins road %s" % e[5:]
                return e
            simp = rdp([tuple(p) for p in road["points"]], 12)
            rows_.append({"id": road["id"], "kind": road["kind"],
                          "from": end_name(road["a"]), "to": end_name(road["b"]),
                          "length_total": int(plen([tuple(p) for p in road["points"]])),
                          "length_in_zone": 2 * sum(inside),
                          "first_in_zone": list(pts[0]), "last_in_zone": list(pts[-1]),
                          "polyline_simplified": [list(p) for p in simp[:40]]})
        f["roads"] = rows_
        f["capital_street_count"] = streets

    # protected areas per zone
    capitals = {c["anchor_id"]: c for c in meta["capitals"]}
    for zid, f in zone_facts.items():
        prot = {}
        for a in f["anchors"]:
            if a["kind"] == "start":
                prot["start_town"] = {
                    "pad": {"min_x": a["x"] - 64, "max_x": a["x"] + 63, "min_z": a["z"] - 64, "max_z": a["z"] + 63},
                    "band_nodes": 12, "outer_box": {"min_x": a["x"] - 76, "max_x": a["x"] + 75,
                                                    "min_z": a["z"] - 76, "max_z": a["z"] + 75},
                    "note": "128-node pad plus a 12-node band (rounded corners); hard protected, no hostile spawns."}
            if a["kind"].startswith("capital_"):
                c = capitals.get(a["id"])
                if c:
                    prot["capital_city"] = {"box": c["city_box"], "area_nodes2": c["city_area"],
                                            "outline_kind": c["kind"], "gates": c["gates"],
                                            "zone_land_outside_city_pct": round(100 - 100 * c["city_area"] / max(1, f["extent"]["land_area_nodes2"]), 1)}
        prot["settlement_boxes"] = [dict(a["protected_box"], anchor=a["id"], name=a["name"])
                                    for a in f["anchors"] if a.get("protected_box")]
        prot["roads"] = "road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical"
        f["protected"] = prot

    # spawns per zone (probe), crabs/gulls from the grid
    for zid, f in zone_facts.items():
        zp = zone_probe.get(zid)
        num = zones[zid]["numeric_id"]
        spawns, no_host = [], []
        if zp:
            land_pts = max(1, zp["land_points"])
            for sp in zp["spawns"]:
                name = sp["name"]
                if name in ("grug_mobs:shore_crab", "grug_mobs:reef_lurker", "grug_mobs:gull"):
                    continue
                row = {"mob": name, "name": mob_name(name),
                       "disposition": mobs.get(name, {}).get("disposition"),
                       "hosts": sorted(hosts.get(name, []))}
                # the policy's points, kept only on biomes whose top node is
                # one of the species' surface host nodes
                host_set = hosts.get(name, set())
                if name == "grug_mobs:skeleton_archer" and zid not in WAR_OR_MOUNTAIN_ZONES:
                    # its own spawn check: outside a war or mountain palette
                    # only bone litter and blight dirt (skeleton_archer.lua)
                    host_set = {"grug_nodes:dirt_with_bone_litter", "grug_nodes:blight_dirt"}
                    row["hosts"] = sorted(host_set)
                for clock in ("day", "night"):
                    c = sp[clock]
                    n, lo, hi = 0, None, None
                    for b, bc in (c.get("biomes") or {}).items():
                        if BIOME_TOP.get(b) in host_set:
                            n += bc["count"]
                            if bc.get("min") is not None:
                                lo = bc["min"] if lo is None else min(lo, bc["min"])
                                hi = bc["max"] if hi is None else max(hi, bc["max"])
                    row[clock] = None if n == 0 else {
                        "share_pct": round(100 * n / land_pts, 1), "levels": [lo, hi],
                        "policy_share_pct": round(100 * c["count"] / land_pts, 1)}
                    if c["count"] and n == 0:
                        row.setdefault("policy_only", []).append(clock)
                if row["day"] or row["night"]:
                    spawns.append(row)
                elif row.get("policy_only"):
                    no_host.append(row["name"])
            zb = sea_beach & (G.zone == num)
            lv = G.level[zb]
            for name, cond in (("grug_mobs:shore_crab", lv < 45), ("grug_mobs:reef_lurker", lv >= 45)):
                n = int(cond.sum())
                if n:
                    spawns.append({"mob": name, "name": mob_name(name),
                                   "disposition": mobs.get(name, {}).get("disposition"),
                                   "hosts": ["default:sand (dry, within 6 nodes of water)"],
                                   "day": {"area_nodes2": n * step * step,
                                           "levels": [int(lv[cond].min()), int(lv[cond].max())]},
                                   "night": {"area_nodes2": n * step * step,
                                             "levels": [int(lv[cond].min()), int(lv[cond].max())]},
                                   "note": "measured on sea-beach sand from the grid (host node check)"})
            gull = G.land & (G.zone == num) & (G.biome == biome_names.index("grug_beach") + 1)
            if gull.any():
                spawns.append({"mob": "grug_mobs:gull", "name": mob_name("grug_mobs:gull"),
                               "disposition": "critter", "hosts": sorted(hosts.get("grug_mobs:gull", [])),
                               "day": {"area_nodes2": int(gull.sum()) * step * step}, "night": None,
                               "note": "logical beach biome only"})
            f["casts"] = {"day": zp["day_cast"], "night": zp["night_cast"],
                          "density_budget_day": zp["density_day"],
                          "density_budget_night": zp["density_night"]}
        f["spawns"] = sorted(spawns, key=lambda s: s["mob"])
        f["palette_without_host_ground"] = sorted(no_host)

    # camps, guards, rares
    for zid, f in zone_facts.items():
        camps = []
        for a in f["anchors"]:
            if a["kind"] in ("bandit_home", "bandit_frontier"):
                ct = camp_types["bandit"]
                camps.append({"anchor": a["id"], "name": a["name"], "x": a["x"], "z": a["z"],
                              "type": "bandit", "mobs": [ct["mob"], ct.get("variant")],
                              "count": [ct["count_min"], ct["count_max"]], "radius": ct["radius"],
                              "respawn_s": [ct["respawn_min"], ct["respawn_max"]],
                              "level_at_anchor": a["level_at"]})
            elif a["kind"] == "mirefolk":
                camps.append({"anchor": a["id"], "name": a["name"], "x": a["x"], "z": a["z"],
                              "type": "mirefolk", "note": "EMPTY today: no camp fire is placed (anchor roster lists only capital, outpost and bandit populations)",
                              "level_at_anchor": a["level_at"]})
            elif a["kind"] == "outpost":
                faction = "accord" if zones[zid]["macro_region"] == "elandor_mainland" else "throng"
                ct = camp_types["guard_" + faction]
                camps.append({"anchor": a["id"], "name": a["name"], "x": a["x"], "z": a["z"],
                              "type": "guard post", "mobs": [ct["mob"]],
                              "count": [ct["count_min"], ct["count_max"]],
                              "respawn_s": [ct["respawn_min"], ct["respawn_max"]],
                              "level_at_anchor": a["level_at"]})
        f["camps"] = camps
        f["rares"] = []
    for r in probe["rares"]:
        if not r["route"]:
            continue
        p = r["route"][0]
        num = int(G.at(G.zone, p["x"], p["z"]))
        z = zone_by_num.get(num)
        if z:
            zone_facts[z["id"]]["rares"].append({
                "id": r["id"], "name": r["name"], "mob": r["mob"], "biome_hint": r.get("biome_hint"),
                "respawn_s": [r["respawn_min"], r["respawn_max"]],
                "route": [[q["x"], q["y"], q["z"]] for q in r["route"]],
                "level_at": int(G.at(G.level, p["x"], p["z"]))})

    # track and role
    for race, track in TRACKS.items():
        for i, zid in enumerate(track):
            f = zone_facts[zid]
            f["race_track"] = race
            f["track_order"] = i + 1
    for zid, f in zone_facts.items():
        lvmin, lvmax = f["level_min"], f["level_max"]
        if zid.startswith("front_"):
            role = "dragon island (60)" if lvmin == 60 else "front zone"
        elif f["civic_no_hostiles"]:
            role = "capital zone"
        elif f["pvp_rule"] == "contested":
            role = "contested 31-40"
        elif lvmax == 10:
            role = "start zone"
        elif lvmax == 20:
            role = "home zone 11-20"
        else:
            role = "home zone 21-30"
        f["role"] = role

    # the start-zone gradient text
    for zid, f in zone_facts.items():
        if f["role"] == "start zone":
            a = next(a for a in f["anchors"] if a["kind"] == "start")
            f["level_rule"] = (
                "Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; "
                "beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and "
                "band 3 (L7-10) toward the front border (%s), reaching L10 at the border." % f["front"]["axis"])
            f["start_rings"] = {"anchor": [a["x"], a["z"]], "core_radius": 100, "band_radius": 150}
        elif f["role"] == "capital zone":
            f["level_rule"] = "Zone field (simple_map.lua zone_level_at); capital palettes are empty today, so no ambient mobs spawn anywhere in the zone."
        elif f["role"].startswith("dragon"):
            f["level_rule"] = "Flat level 60."
        else:
            f["level_rule"] = ("Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z "
                               "toward the front (or toward the zone middle for front zones); the start bands "
                               "(L1 <= 100, L2 <= 150 nodes) override near start anchors.")

    # ---------------- write per-zone files ----------------
    zone_order = sorted(zone_facts.values(), key=lambda f: f["numeric_id"])
    for f in zone_order:
        f["seed"] = seed
        f["map"] = "maps/%s.png" % f["id"]
        with open(os.path.join(out, f["id"] + ".json"), "w") as fh:
            json.dump(f, fh, indent=1, sort_keys=True)
        with open(os.path.join(out, f["id"] + ".md"), "w") as fh:
            fh.write(zone_markdown(f, zones, settlement_by_key))
        render_zone(G, f, meta, zones, zone_by_num, protected, drift, sea_beach, bank_sand,
                    os.path.join(out, "maps", f["id"] + ".png"))
        print("zone", f["id"])
    render_world(G, meta, zone_facts, zone_by_num, os.path.join(out, "maps", "world.png"))
    with open(os.path.join(out, "index.md"), "w") as fh:
        fh.write(index_markdown(zone_order, meta, probe, seed))


# --------------------------------------------------------------------------
# Markdown
# --------------------------------------------------------------------------

def fmt_levels(lv):
    if not lv or lv[0] is None:
        return "-"
    return "L%d" % lv[0] if lv[0] == lv[1] else "L%d-%d" % (lv[0], lv[1])


def spawn_cell(c):
    if not c:
        return "-"
    if "share_pct" in c:
        return "%s%% of land, %s" % (c["share_pct"], fmt_levels(c["levels"]))
    txt = "%d nodes²" % c["area_nodes2"]
    if c.get("levels"):
        txt += ", " + fmt_levels(c["levels"])
    return txt


def zone_markdown(f, zones, settlement_by_key):
    L = []
    w = L.append
    w("# %s (`%s`)\n" % (f["name"], f["id"]))
    w("Zone %d · %s · %s · race region **%s** · levels **%d-%d** · %s · relief `%s` · seed %s\n" % (
        f["numeric_id"], f["role"], f["faction"], f["race_region"], f["level_min"], f["level_max"],
        f["pvp_rule"], f["relief_profile"], f["seed"]))
    w("Map: [%s](%s). Machine-readable: [%s.json](%s.json). Coordinates are world nodes "
      "(x east, z north, y up).\n" % (f["map"], f["map"], f["id"], f["id"]))
    if f.get("race_track"):
        w("Race track (%s): step %d of the track %s.\n" % (
            f["race_track"], f["track_order"],
            " → ".join(zones[z]["display_name"] for z in TRACKS[f["race_track"]])))
    w("**Front:** %s\n" % f["front"]["text"])
    e = f["extent"]
    w("## Geometry\n")
    w("| Fact | Value |\n|---|---|")
    w("| Land extent | x %d..%d, z %d..%d (centroid %d, %d) |" % (e["min_x"], e["max_x"], e["min_z"], e["max_z"],
                                                             e["centroid"]["x"], e["centroid"]["z"]))
    w("| Land area | %d nodes² (≈ %.2f km²) |" % (e["land_area_nodes2"], e["land_area_nodes2"] / 1e6))
    w("| Hub point (authored) | %d, %d |" % (f["hub"]["x"], f["hub"]["z"]))
    rel = f["relief"]["height_above_sea"]
    w("| Height above sea | min %d, p10 %d, median %d, p90 %d, max %d |" % (
        rel["min"], rel["p10"], rel["median"], rel["p90"], rel["max"]))
    w("| Slope | %s%% steep (>1 node/node), %s%% cliff (>2) |" % (
        f["relief"]["steep_share_pct"], f["relief"]["cliff_share_pct"]))
    w("| Biomes (measured) | %s |" % ", ".join("%s %s%%" % (b["id"].replace("grug_", ""), b["share_pct"])
                                             for b in f["biomes_measured"]))
    w("| Neighbours (land border) | %s |" % (", ".join(
        "%s (%d nodes, mid %d,%d)" % (b["zone"], b["length_nodes"], b["midpoint"]["x"], b["midpoint"]["z"])
        for b in f["borders"]) or "none"))
    c = f["coast"]
    w("| Sea coast | %d nodes of coastline; sea-beach sand %d nodes²; lake/river-bank sand %d nodes² |" % (
        c["sea_coast_length_nodes"], c["sea_beach_sand_area_nodes2"], c["bank_sand_area_nodes2"]))
    w("| Water inside | bay %d nodes², rivers/lakes %d nodes² |" % (c["bay_water_area_nodes2"], c["inland_water_area_nodes2"]))
    w("| Protected / drift band | %s%% of land protected (towns, villages, camps/POIs, road corridors); "
      "%s%% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |" % (
          f["protected_share_pct"], f["drift_band_share_pct"]))
    w("")
    if c["beaches"]:
        w("**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**\n")
        w("| Id | Centre | Box | Area | Levels |\n|---|---|---|---|---|")
        for b in c["beaches"]:
            bx = b["box"]
            w("| %s | %d, %d | x %d..%d, z %d..%d | %d | %s |" % (
                b["id"], b["centroid"]["x"], b["centroid"]["z"], bx["min_x"], bx["max_x"], bx["min_z"],
                bx["max_z"], b["area_nodes2"], fmt_levels(b["levels"])))
        w("")
    w("## Levels\n")
    w(f["level_rule"] + "\n")
    hist = f["level_field"]["histogram_pct"]
    w("Share of land per level: " + ", ".join("L%s %s%%" % (k, v) for k, v in hist.items()) + "\n")
    w("## Anchors\n")
    w("| Id | Kind | Name | x | y | z | Level there | Protected box |\n|---|---|---|---|---|---|---|---|")
    for a in f["anchors"]:
        pb = a.get("protected_box")
        pbt = "%s x %d..%d, z %d..%d" % (pb["kind"], pb["min_x"], pb["max_x"], pb["min_z"], pb["max_z"]) if pb else "-"
        w("| %s | %s | %s | %d | %d | %d | %s | %s |" % (a["id"], a["kind_text"], a["name"] or "-", a["x"], a["y"],
                                                     a["z"], a["level_at"] or "-", pbt))
    w("")
    p = f["protected"]
    w("## Protected areas\n")
    if "start_town" in p:
        st = p["start_town"]
        w("- Start town: pad x %d..%d, z %d..%d plus a 12-node band (outer box x %d..%d, z %d..%d); "
          "hard protected, hostile spawns refused." % (
              st["pad"]["min_x"], st["pad"]["max_x"], st["pad"]["min_z"], st["pad"]["max_z"],
              st["outer_box"]["min_x"], st["outer_box"]["max_x"], st["outer_box"]["min_z"], st["outer_box"]["max_z"]))
    if "capital_city" in p:
        cc = p["capital_city"]
        b = cc["box"]
        w("- Capital city (seed-dependent outline): box x %d..%d, z %d..%d, area %d nodes²; %s%% of the zone's land "
          "lies outside the city. Gates: %s." % (
              b["min_x"], b["max_x"], b["min_z"], b["max_z"], cc["area_nodes2"], cc["zone_land_outside_city_pct"],
              ", ".join("%s %d,%d" % (g["name"], g["x"], g["z"]) for g in cc["gates"])))
    for sb in p["settlement_boxes"]:
        w("- %s %s (%s): x %d..%d, z %d..%d" % (sb["kind"], sb["name"], sb["anchor"], sb["min_x"], sb["max_x"],
                                              sb["min_z"], sb["max_z"]))
    w("- Roads: %s." % p["roads"])
    w("")
    w("## Hubs, NPCs and current quests\n")
    if not f["settlements"]:
        w("No settlement with NPCs in this zone.\n")
    for s in f["settlements"]:
        npcs = [n for n in s["npcs"] if n["role"] != "public_station"]
        if not npcs and not s["resident_counts"]:
            continue
        w("### %s (`%s`, %s) at %d, %d, %d\n" % (s["name"], s["key"], s["anchor_id"], s["anchor"]["x"],
                                                  s["anchor"]["y"], s["anchor"]["z"]))
        rc = s["resident_counts"]
        w("Residents/guards: %s.\n" % ", ".join("%s %d" % (k, v) for k, v in sorted(rc.items())))
        if npcs:
            w("| Socket | Role | Who / what | Position | Quests given |\n|---|---|---|---|---|")
            for n in npcs:
                who = n.get("npc_name") or n.get("vendor_kind") or n.get("profession") or ""
                if n["role"] == "quest" and not n.get("npc_name"):
                    who = "(free quest socket: no quest NPC bound)"
                if n.get("vendor_kind"):
                    who = "vendor kind: " + n["vendor_kind"]
                if n.get("profession"):
                    who = "trains: " + n["profession"]
                w("| %s | %s | %s | %d, %d, %d | %s |" % (
                    n["socket"], n["role_text"], who, n["x"], n["y"], n["z"],
                    ", ".join(n.get("quests", [])) or "-"))
            w("")
        stations = [n for n in s["npcs"] if n["role"] == "public_station"]
        if stations:
            w("Public stations: %s.\n" % ", ".join("%s (%s)" % (n["socket"], n.get("tag", "")) for n in stations))
        d = s["distances"]
        edge = d["to_zone_edge"]
        w("Distances: zone edge N %s (%s), S %s (%s), E %s (%s), W %s (%s); nearest other-zone land %s; "
          "sea %s; sea-beach sand %s; nearest road %s." % (
              edge["north_+z"]["distance"], edge["north_+z"]["hits"], edge["south_-z"]["distance"],
              edge["south_-z"]["hits"], edge["east_+x"]["distance"], edge["east_+x"]["hits"],
              edge["west_-x"]["distance"], edge["west_-x"]["hits"],
              dist_txt(d["nearest_other_zone_land"]), dist_txt(d["nearest_sea"]),
              dist_txt(d["nearest_sea_beach_sand"]),
              d["nearest_road"]["distance"] if d["nearest_road"] else "-"))
        w("Nearest hubs (straight / by road): " + "; ".join(
            "%s %d / %s" % (h["name"], h["straight"], h["road"] if h["road"] is not None else "no road")
            for h in d["hubs"][:5]) + ".\n")
    if f["quests"]:
        w("### Current quests (%d, given in this zone)\n" % len(f["quests"]))
        w("| Id | Title | Giver | Min L | Objectives | XP | Needs |\n|---|---|---|---|---|---|---|")
        for q in f["quests"]:
            w("| %s | %s | %s (%s) | %d | %s | %d | %s |" % (
                q["id"], q["title"], q["giver_name"], q["giver_settlement"], q["min_level"],
                "; ".join(q["objectives"]), q["xp"], ", ".join(q["prerequisites"]) or "-"))
        w("")
    else:
        w("No quest is given in this zone today.\n")
    w("## Current mob palette (before Round 28)\n")
    w("Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, "
      "kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach "
      "sand). Share = of the zone's dry land (not a density); levels = the level field there.\n")
    if f["spawns"]:
        w("| Mob | Name | Disposition | Day | Night | Host nodes |\n|---|---|---|---|---|---|")
        for s in f["spawns"]:
            w("| %s | %s | %s | %s | %s | %s |" % (
                s["mob"].split(":")[-1], s["name"], s.get("disposition") or "-", spawn_cell(s["day"]),
                spawn_cell(s["night"]), ", ".join(h.split(":")[-1] for h in s["hosts"][:6]) +
                (" …" if len(s["hosts"]) > 6 else "")))
        w("")
    else:
        w("Empty palette: no ambient surface mobs.\n")
    if f.get("palette_without_host_ground"):
        w("In the palette but no host ground in this zone: %s.\n" % ", ".join(f["palette_without_host_ground"]))
    if f["camps"]:
        w("**Camps and guard posts:**\n")
        for c in f["camps"]:
            if c["type"] == "mirefolk":
                w("- %s %s at %d, %d: mirefolk camp, %s (level there L%s)." % (
                    c["anchor"], c["name"], c["x"], c["z"], c["note"], c["level_at_anchor"]))
            else:
                w("- %s %s at %d, %d: %s, %s × %d-%d, respawn %d-%d s, level there L%s." % (
                    c["anchor"], c["name"], c["x"], c["z"], c["type"],
                    "/".join(m.split(":")[-1] for m in c["mobs"] if m), c["count"][0], c["count"][1],
                    c["respawn_s"][0], c["respawn_s"][1], c["level_at_anchor"]))
        w("")
    if f["rares"]:
        w("**Rares (knowledge rewards, not quest targets):** " + "; ".join(
            "%s (%s, %s, route %s, L%s, respawn %d-%d h)" % (
                r["name"], r["mob"].split(":")[-1], r["biome_hint"],
                " → ".join("%d,%d" % (p[0], p[2]) for p in r["route"]), r["level_at"],
                r["respawn_s"][0] // 3600, r["respawn_s"][1] // 3600) for r in f["rares"]) + "\n")
    w("## Roads and trails touching the zone\n")
    if f["roads"]:
        w("| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |\n|---|---|---|---|---|---|")
        for r in f["roads"]:
            w("| %d | %s | %s | %s | %d / %d | %d,%d → %d,%d |" % (
                r["id"], r["kind"], r["from"], r["to"], r["length_total"], r["length_in_zone"],
                r["first_in_zone"][0], r["first_in_zone"][1], r["last_in_zone"][0], r["last_in_zone"][1]))
        w("")
        w("Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).\n")
    else:
        w("No road or trail.\n")
    if f.get("capital_street_count"):
        w("Capital streets (avenues and lanes) inside the city: %d.\n" % f["capital_street_count"])
    return "\n".join(L) + "\n"


def dist_txt(d):
    if not d:
        return "-"
    return "%d %s" % (d["distance"], d["bearing"])


def index_markdown(zone_order, meta, probe, seed):
    L = []
    w = L.append
    w("# Round 28 zone facts atlas\n")
    w("Measured facts for the design round (plan "
      "[round28-questing-leveling-plan.md](../../round28-questing-leveling-plan.md), Sections B and C): "
      "geometry, anchors, hubs and NPCs, roads, protected areas, beaches, relief, the current mob palette and "
      "level field, and the current quests for all 38 zones. One Markdown file, one JSON file and one PNG map per "
      "zone; `maps/world.png` is the overview.\n")
    w("**Seed %s** (the project's standard evidence seed). Generated by `tools/r28_zone_atlas/run.sh` "
      "(portable LuaJIT sampling of the analytic world + one headless engine probe). Facts, not design.\n" % seed)
    w("## World axes\n")
    w("- x grows east, z grows **north** (maps: north up), y up. The world spans x -3600..3600, z -3200..3200; "
      "sea level is y = 1.")
    w("- **Accord (Elandor) is south (-z)**: start zones at z ≈ -2550, home zones 11-20 at z ≈ -2050, capitals "
      "and 21-30 zones at z ≈ -1500, contested 31-40 zones at z ≈ -700. Their front is **north (+z)**; their "
      "home ocean is south.")
    w("- **Throng (Kragmar) is north (+z)**, mirrored: start z ≈ 2550 → 2050 → 1500 → 700. Front **south (-z)**.")
    w("- **Battlegrounds**: one land band around **z = 0** (about -300..300), four zones west to east: Gravesalt "
      "Escarpment (51-59), The Broken Causeway (31-40), The Shattered Line (41-50), The Skyglass Canopy "
      "(51-59). The two dragon islands (60) lie offshore west (x ≈ -3150) and east (x ≈ 3150).")
    w("- Race columns: dwarf/undead x ≈ -1800, human/orc x ≈ 0, elf/troll x ≈ 1800; side zones at x ≈ ±900 "
      "and ±2400.\n")
    w("## What depends on the seed\n")
    w("- **Seed-independent:** zone list, names, level ranges, rules and biome palettes; hub points; every "
      "anchor's x/z (starts, capitals, villages, outposts, mines, camps, clash sites, dragons, apex mines, rare "
      "routes); POI names; start-town footprint (128-node pad + 12 band); start-band radii; NPC sockets of start "
      "towns and POIs relative to their anchor; quests, quest givers and mob palettes.")
    w("- **Seed-dependent (bounded):** zone borders and coastline (warped within ~150-300 nodes), terrain "
      "heights (anchor y), beaches, rivers and lakes, roads and trails, capital city outlines/gates/plots (and "
      "with them capital NPC positions), biome patches, and the level field near borders (the start-zone "
      "gradient measures the distance to the front border). Treat these as *shape* guidance: an area rule "
      "relative to an anchor, a beach host class or a road works on every seed; an absolute coordinate on a "
      "beach or a border does not.\n")
    w("## How to read a zone file\n")
    w("- `<zone_id>.md`: compact facts tables. Sections: Geometry (extent, area, relief, biomes, neighbours, "
      "coast, protected share and Ruling 2 drift band), Sea beaches (B1… with boxes), Levels (rule + measured "
      "histogram), Anchors (all POIs with ids and coordinates), Protected areas, Hubs/NPCs/quests (socket, "
      "role, NPC name, quests given; distances to zone edges, sea, beach sand, road and the nearest hubs by "
      "straight line and by road), Current mob palette (day/night share of land and level range), camps and "
      "rares, Roads and trails (endpoints, lengths, entry/exit points).")
    w("- `<zone_id>.json`: the same and more (simplified road polylines, raw quest objectives and texts, "
      "capital gates, settlement boxes, border midpoints).")
    w("- `maps/<zone_id>.png`: top-down map, **north up**, display scale **1 px = 1 node** (data sampled every 4 "
      "nodes), coordinates on the axes every 100 nodes, scale bar and north arrow. Land is tinted by the "
      "**current mob-level field** (legend: light = low, dark = high) with a thin line where the level steps; "
      "other zones are grey; sand is beige (sea beach) or pale (lake/river bank); water blue (dark = deep "
      "ocean). Red outline/hatch = protected ground (start town, capital city, village/camp/POI boxes); brown "
      "lines = roads (thick primary/secondary, thin dashed trails, grey capital streets); the whitish halo = the "
      "≤ 16-node drift band of Ruling 2. Markers: star start, square capital, circle village, triangle outpost, "
      "diamond mine, red X bandit camp, teal X mirefolk, orange + clash, pink dot rare route, black triangle "
      "dragon; B1… = sea beaches; dashed circles in start zones = the 100/150 start bands.\n")
    w("## Zones\n")
    w("| # | Id | Name | Role / track | Levels | Hub | Extent (x; z) | Biomes (measured, top 3) | POIs | Quests | Day palette | Night palette |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for f in zone_order:
        e = f["extent"]
        kinds = collections.Counter(a["kind_text"] for a in f["anchors"])
        pois = ", ".join("%d %s" % (n, k) for k, n in sorted(kinds.items()))
        day = sorted({s["name"] for s in f["spawns"] if s.get("day")})
        night = sorted({s["name"] for s in f["spawns"] if s.get("night") and s["mob"] not in ("grug_mobs:shore_crab", "grug_mobs:reef_lurker")})
        track = f["role"] + (" (%s)" % f["race_track"] if f.get("race_track") else "")
        w("| %d | [%s](%s.md) | %s | %s | %d-%d | %d, %d | %d..%d; %d..%d | %s | %s | %d | %s | %s |" % (
            f["numeric_id"], f["id"], f["id"], f["name"], track, f["level_min"], f["level_max"],
            f["hub"]["x"], f["hub"]["z"], e["min_x"], e["max_x"], e["min_z"], e["max_z"],
            ", ".join(b["id"].replace("grug_", "") for b in f["biomes_measured"][:3]), pois or "-",
            len(f["quests"]), ", ".join(day) or "-", ", ".join(night) or "-"))
    w("")
    w("## Race tracks\n")
    w("| Race | Start 1-10 | Home 11-20 | Capital | 21-30 | Contested 31-40 |\n|---|---|---|---|---|---|")
    for race, t in TRACKS.items():
        names = {z["id"]: z["display_name"] for z in meta["zones"]}
        w("| %s | %s | %s | %s | %s | %s |" % (race, names[t[0]], names[t[1]], names[t[2]],
                                              ", ".join(names[z] for z in t[3:-1]), names[t[-1]]))
    w("\nFront (shared): The Broken Causeway 31-40, The Shattered Line 41-50, Gravesalt Escarpment and The "
      "Skyglass Canopy 51-59, The Wyrmglass Crown and Stormscale Summit 60 (islands). Today the front zones and "
      "islands have no quest givers and no roads.\n")
    w("## Counts\n")
    w("- Quests registered today: %d; quest NPCs: %d; settlements with sockets: %d." % (
        len(probe["quests"]), len(probe["quest_npcs"]), len(probe["settlements"])))
    w("- Camp types: " + "; ".join("%s (%s, %d-%d, respawn %d-%d s)" % (
        c["id"], c["mob"].split(":")[-1], c["count_min"], c["count_max"], c["respawn_min"], c["respawn_max"])
        for c in probe["camp_types"]) + ".")
    w("- Rares: " + ", ".join("%s (%s)" % (r["name"], r["mob"].split(":")[-1]) for r in probe["rares"]) + ".\n")
    w("## Limits of these facts\n")
    w("- The mob palette is the spawn policy evaluated in the engine on a 24-node grid of dry land "
      "(`grug_mobs.spawn_allowed`, by day and by night), then kept only where the logical biome's top node "
      "is one of the species' surface host nodes (ABM node lists). Crabs are measured on sea-beach sand, "
      "gulls on the beach biome. The skeleton archer's own node check is applied by zone palette (outside "
      "war/mountain palettes only bone litter and blight dirt). Coast sand/gravel replacing the biome top "
      "near water and the start-town ground are not modelled. Shares are of the zone's dry land, not "
      "densities.")
    w("- Sand is the coast/bank material rule of `height.lua` on dry land, sampled every 4 nodes; vegetation "
      "and structures are not modelled.")
    w("- Road distances follow road and trail centrelines (joined where two roads come within 4 nodes) plus "
      "the straight hop from each settlement anchor to its nearest road point.")
    w("- Capital NPC positions and city outlines are for this seed only.\n")
    return "\n".join(L) + "\n"


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

LEVEL_STOPS = [(255, 247, 188), (254, 217, 118), (254, 153, 41), (217, 95, 14), (153, 52, 4), (90, 30, 60)]


def level_color(t):
    t = min(max(t, 0.0), 1.0) * (len(LEVEL_STOPS) - 1)
    i = min(int(t), len(LEVEL_STOPS) - 2)
    u = t - i
    a, b = LEVEL_STOPS[i], LEVEL_STOPS[i + 1]
    return tuple(int(a[k] + (b[k] - a[k]) * u) for k in range(3))


def hillshade(h):
    gz, gx = np.gradient(h.astype(float))
    # light from the north-west (image up-left): north is +z = +row
    shade = 1.0 + 0.06 * (-gx + gz)
    return np.clip(shade, 0.65, 1.25)


def base_rgb(G, sel_zone, zone_lo, zone_hi):
    rows, cols = G.zone.shape
    rgb = np.zeros((rows, cols, 3), dtype=float)
    water_colors = {1: (31, 59, 92), 2: (58, 106, 148), 3: (63, 116, 160), 5: (22, 48, 74), 6: (74, 134, 184)}
    for code, col in water_colors.items():
        rgb[G.wc == code] = col
    land = G.land
    rgb[land] = (196, 196, 190)
    if sel_zone is not None:
        sel = land & (G.zone == sel_zone)
        span = max(1, zone_hi - zone_lo)
        lut = np.array([level_color((l - zone_lo) / span) for l in range(256)], dtype=float)
        rgb[sel] = lut[G.level[sel]]
    shade = hillshade(G.h)
    rgb[land] *= shade[land][:, None]
    return np.clip(rgb, 0, 255)


def draw_marker(d, x, y, kind, size=7):
    shape, fill = MARKER.get(kind, MARKER["hub"])
    s = size
    outline = (0, 0, 0)
    if shape == "star":
        pts = []
        for i in range(10):
            ang = math.pi / 2 + i * math.pi / 5
            r = s * 1.5 if i % 2 == 0 else s * 0.6
            pts.append((x + r * math.cos(ang), y - r * math.sin(ang)))
        d.polygon(pts, fill=fill, outline=outline)
    elif shape == "square":
        d.rectangle([x - s, y - s, x + s, y + s], fill=fill, outline=outline, width=2)
    elif shape == "circle":
        d.ellipse([x - s * 0.8, y - s * 0.8, x + s * 0.8, y + s * 0.8], fill=fill, outline=outline)
    elif shape == "triangle":
        d.polygon([(x, y - s), (x - s, y + s * 0.8), (x + s, y + s * 0.8)], fill=fill, outline=outline)
    elif shape == "diamond":
        d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], fill=fill, outline=outline)
    elif shape == "x":
        d.line([(x - s, y - s), (x + s, y + s)], fill=fill, width=4)
        d.line([(x - s, y + s), (x + s, y - s)], fill=fill, width=4)
    elif shape == "plus":
        d.line([(x - s, y), (x + s, y)], fill=fill, width=4)
        d.line([(x, y - s), (x, y + s)], fill=fill, width=4)
    else:
        d.ellipse([x - s, y - s, x + s, y + s], outline=fill, width=2)


def save_png(img, path):
    """256-colour palette PNG (about a third of the RGB size in the repo)."""
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                 dither=Image.Dither.NONE).save(path, optimize=True)


def text_halo(d, xy, text, fnt, fill=(0, 0, 0), halo=(255, 255, 255)):
    x, y = xy
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((x + dx, y + dy), text, font=fnt, fill=halo)
    d.text((x, y), text, font=fnt, fill=fill)


class Labeler:
    def __init__(self, d, fnt, bounds):
        self.d, self.fnt, self.boxes, self.bounds = d, fnt, [], bounds

    def place(self, x, y, text, fill=(0, 0, 0), offset=10):
        tw, th = self.d.textbbox((0, 0), text, font=self.fnt)[2:]
        for ox, oy in ((offset, -th / 2), (-offset - tw, -th / 2), (-tw / 2, -offset - th),
                       (-tw / 2, offset), (offset, -th - 4), (offset, 4), (-offset - tw, 4), (-offset - tw, -th - 4)):
            bx0, by0 = x + ox, y + oy
            box = (bx0 - 2, by0 - 2, bx0 + tw + 2, by0 + th + 2)
            x0, y0, x1, y1 = self.bounds
            if box[0] < x0 or box[1] < y0 or box[2] > x1 or box[3] > y1:
                continue
            if any(not (box[2] < b[0] or box[0] > b[2] or box[3] < b[1] or box[1] > b[3]) for b in self.boxes):
                continue
            self.boxes.append(box)
            text_halo(self.d, (bx0, by0), text, self.fnt, fill=fill)
            return True
        return False


def render_zone(G, f, meta, zones, zone_by_num, protected, drift, sea_beach, bank_sand, path):
    step = G.step
    num = f["numeric_id"]
    e = f["extent"]
    margin = 64
    x0, x1 = e["min_x"] - margin, e["max_x"] + margin
    z0, z1 = e["min_z"] - margin, e["max_z"] + margin
    c0, c1 = max(0, (x0 - G.min_x) // step), min(G.cols - 1, (x1 - G.min_x) // step)
    r0, r1 = max(0, (z0 - G.min_z) // step), min(G.rows - 1, (z1 - G.min_z) // step)
    x0, x1 = G.min_x + c0 * step, G.min_x + c1 * step
    z0, z1 = G.min_z + r0 * step, G.min_z + r1 * step
    lo, hi = f["level_min"], f["level_max"]
    hist = f["level_field"]
    if hist["min"] is not None:
        lo, hi = min(lo, hist["min"]), max(hi, hist["max"])
    rgb = base_rgb(G, num, lo, hi)
    sub = rgb[r0:r1 + 1, c0:c1 + 1].copy()
    zone_sub = G.zone[r0:r1 + 1, c0:c1 + 1]
    land_sub = G.land[r0:r1 + 1, c0:c1 + 1]
    sel = land_sub & (zone_sub == num)
    beach = sea_beach[r0:r1 + 1, c0:c1 + 1]
    bank = bank_sand[r0:r1 + 1, c0:c1 + 1]
    sub[beach] = sub[beach] * 0.25 + np.array([240, 222, 160]) * 0.75
    sub[bank] = sub[bank] * 0.4 + np.array([228, 222, 190]) * 0.6
    dr = drift[r0:r1 + 1, c0:c1 + 1]
    sub[dr] = sub[dr] * 0.6 + 255 * 0.4
    pr = protected[r0:r1 + 1, c0:c1 + 1]
    sub[pr] = sub[pr] * 0.55 + np.array([230, 80, 80]) * 0.45
    # level contours (inside the zone) and the zone border
    lvl = G.level[r0:r1 + 1, c0:c1 + 1].astype(int)
    contour = np.zeros(sel.shape, dtype=bool)
    contour[:, 1:] |= sel[:, 1:] & sel[:, :-1] & (lvl[:, 1:] != lvl[:, :-1])
    contour[1:, :] |= sel[1:, :] & sel[:-1, :] & (lvl[1:, :] != lvl[:-1, :])
    sub[contour] *= 0.55
    border = np.zeros(sel.shape, dtype=bool)
    other = (zone_sub != num) & (zone_sub > 0)
    border[:, 1:] |= (sel[:, 1:] & other[:, :-1]) | (sel[:, :-1] & other[:, 1:])
    border[1:, :] |= (sel[1:, :] & other[:-1, :]) | (sel[:-1, :] & other[1:, :])
    img_small = np.flipud(sub).astype(np.uint8)
    scale = step  # 1 px = 1 node
    h_px, w_px = img_small.shape[0] * scale, img_small.shape[1] * scale
    mapimg = Image.fromarray(img_small, "RGB").resize((w_px, h_px), Image.NEAREST)
    # everything inside the frame is drawn on the map image (clipped there)
    d = ImageDraw.Draw(mapimg)

    def P(x, z):
        return (x - x0) + step / 2, (z1 - z) + step / 2

    # border pixels as a thick line
    br, bc = np.nonzero(np.flipud(border))
    for r, c in zip(br.tolist(), bc.tolist()):
        d.rectangle([c * scale, r * scale, c * scale + scale - 1, r * scale + scale - 1],
                    fill=(20, 20, 20))
    # start rings
    if f.get("start_rings"):
        ax, az = f["start_rings"]["anchor"]
        for rad in (100, 150):
            cx, cy = P(ax, az)
            for i in range(0, 360, 6):
                a0, a1 = math.radians(i), math.radians(i + 3)
                d.line([(cx + rad * math.cos(a0), cy + rad * math.sin(a0)),
                        (cx + rad * math.cos(a1), cy + rad * math.sin(a1))], fill=(60, 60, 60), width=2)
    # roads
    for road in meta["roads"]:
        pts = [P(x, z) for x, z in road["points"] if x0 - 50 <= x <= x1 + 50 and z0 - 50 <= z <= z1 + 50]
        if len(pts) < 2:
            continue
        kind = road["kind"]
        if kind in ("primary", "secondary"):
            d.line(pts, fill=(110, 70, 30), width=4 if kind == "primary" else 3)
        elif kind == "trail":
            for i in range(0, len(pts) - 1, 4):
                d.line(pts[i:i + 3], fill=(120, 80, 40), width=2)
        else:
            d.line(pts, fill=(90, 90, 90), width=1)
    # capital wall
    for cap in meta["capitals"]:
        if x0 <= cap["x"] <= x1 and z0 <= cap["z"] <= z1:
            pts = [P(x, z) for x, z in cap["wall"]] + [P(*cap["wall"][0])]
            d.line(pts, fill=(160, 20, 20), width=2)
    fs, fb, ft = font(12), font(13, True), font(18, True)
    lab = Labeler(d, fs, (0, 0, w_px, h_px))
    # level labels (median cell of each level, inside the zone)
    for lv in sorted(set(lvl[sel].tolist())):
        rr, cc = np.nonzero(sel & (lvl == lv))
        if len(rr) < 40:
            continue
        i = len(rr) // 2
        order = np.argsort(rr * 10000 + cc)
        rr0, cc0 = rr[order[i]], cc[order[i]]
        x, z = x0 + cc0 * step, z0 + rr0 * step
        px, py = P(x, z)
        lab.place(px, py, "L%d" % lv, fill=(80, 30, 0), offset=0)
    # beaches
    for b in f["coast"]["beaches"]:
        px, py = P(b["centroid"]["x"], b["centroid"]["z"])
        lab.place(px, py, b["id"], fill=(120, 90, 0), offset=0)
    # anchors of every zone inside the frame
    for a in meta["anchors"]:
        if not (x0 <= a["x"] <= x1 and z0 <= a["z"] <= z1):
            continue
        px, py = P(a["x"], a["z"])
        draw_marker(d, px, py, marker_group(a["kind"]))
        name = a.get("settlement_name") or a.get("label") or ANCHOR_KIND_TEXT.get(a["kind"], a["kind"])
        lab.place(px, py, "%s (%s)" % (name, a["id"][-3:]), fill=(0, 0, 0) if a["zone_id"] == f["id"] else (90, 90, 90))
    # service NPC sockets of this zone's settlements: quest givers yellow
    # (labelled where there is room), other services small white dots
    for s in f["settlements"]:
        for n in s["npcs"]:
            if n["role"] in ("public_station", "mount_display", "gear_display"):
                continue
            px, py = P(n["x"], n["z"])
            if n["role"] == "quest":
                d.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(255, 230, 0), outline=(0, 0, 0))
            else:
                d.ellipse([px - 2.5, py - 2.5, px + 2.5, py + 2.5], fill=(255, 255, 255), outline=(0, 0, 0))
    for s in f["settlements"]:
        for n in s["npcs"]:
            if n["role"] == "quest" and n.get("npc_name"):
                px, py = P(n["x"], n["z"])
                lab.place(px, py, "! " + n["npc_name"], fill=(90, 70, 0), offset=6)
    # rares route points
    for r in f["rares"]:
        for p in r["route"]:
            px, py = P(p[0], p[2])
            d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(230, 60, 160))
    # neighbour zone names
    for nb in zone_by_num.values():
        if nb["numeric_id"] == num:
            continue
        m = (zone_sub == nb["numeric_id"]) & land_sub
        if m.sum() > 200:
            rr, cc = np.nonzero(m)
            px, py = P(x0 + int(cc.mean()) * step, z0 + int(rr.mean()) * step)
            lab.place(px, py, "%s (%d-%d)" % (nb["display_name"], nb["level_min"], nb["level_max"]),
                      fill=(70, 70, 70), offset=0)
    # canvas: frame, axes, title and legend around the map
    left, top, right, bottom = 70, 70, 330, 60
    W, H = w_px + left + right, max(h_px + top + bottom, 760)
    canvas = Image.new("RGB", (W, H), (250, 250, 247))
    canvas.paste(mapimg, (left, top))
    d = ImageDraw.Draw(canvas)
    d.rectangle([left, top, left + w_px, top + h_px], outline=(0, 0, 0), width=1)

    def P(x, z):
        return left + (x - x0) + step / 2, top + (z1 - z) + step / 2

    # axes
    for x in range(int(math.ceil(x0 / 100.0)) * 100, x1 + 1, 100):
        px, _ = P(x, z1)
        d.line([(px, top + h_px), (px, top + h_px + 6)], fill=(0, 0, 0))
        d.text((px - 14, top + h_px + 8), str(x), font=fs, fill=(0, 0, 0))
    for z in range(int(math.ceil(z0 / 100.0)) * 100, z1 + 1, 100):
        _, py = P(x0, z)
        d.line([(left - 6, py), (left, py)], fill=(0, 0, 0))
        d.text((4, py - 7), str(z), font=fs, fill=(0, 0, 0))
    d.text((left + w_px // 2 - 20, top + h_px + 26), "x (east →)", font=fs, fill=(0, 0, 0))
    d.text((4, top - 20), "z (north ↑)", font=fs, fill=(0, 0, 0))
    # title
    d.text((left, 10), "%s  ·  %s  ·  L%d-%d  ·  %s" % (f["name"], f["id"], f["level_min"], f["level_max"], f["role"]),
           font=ft, fill=(0, 0, 0))
    d.text((left, 34), "seed %s · 1 px = 1 node (data every 4 nodes) · north up · front: %s" % (
        f["seed"], f["front"]["axis"]), font=fs, fill=(60, 60, 60))
    # legend
    lx = left + w_px + 20
    ly = top
    # north arrow
    d.polygon([(lx + 20, ly), (lx + 10, ly + 28), (lx + 20, ly + 22), (lx + 30, ly + 28)], fill=(0, 0, 0))
    d.text((lx + 15, ly + 30), "N", font=fb, fill=(0, 0, 0))
    # scale bar 100 nodes
    d.rectangle([lx + 60, ly + 14, lx + 160, ly + 20], fill=(0, 0, 0))
    d.rectangle([lx + 110, ly + 14, lx + 160, ly + 20], fill=(255, 255, 255), outline=(0, 0, 0))
    d.text((lx + 60, ly + 24), "0      50     100 nodes", font=fs, fill=(0, 0, 0))
    ly += 60
    d.text((lx, ly), "Mob level (current field)", font=fb, fill=(0, 0, 0))
    ly += 18
    span = max(1, hi - lo)
    levels = list(range(lo, hi + 1))
    if len(levels) > 12:
        levels = sorted(set([lo] + [lo + round(i * span / 10) for i in range(1, 10)] + [hi]))
    for l in levels:
        col = level_color((l - lo) / span)
        d.rectangle([lx, ly, lx + 22, ly + 12], fill=col, outline=(0, 0, 0))
        d.text((lx + 28, ly - 1), "L%d" % l, font=fs, fill=(0, 0, 0))
        ly += 15
    ly += 6
    items = [((240, 222, 160), "sea-beach sand"), ((228, 222, 190), "lake/river-bank sand"),
             ((196, 196, 190), "other zones"), ((58, 106, 148), "coastal shelf / bay"),
             ((31, 59, 92), "deep ocean"), ((74, 134, 184), "river / lake"),
             ((236, 160, 150), "protected ground"), ((240, 240, 236), "≤16 nodes drift band")]
    for col, txt in items:
        d.rectangle([lx, ly, lx + 22, ly + 12], fill=col, outline=(0, 0, 0))
        d.text((lx + 28, ly - 1), txt, font=fs, fill=(0, 0, 0))
        ly += 16
    d.line([(lx, ly + 6), (lx + 22, ly + 6)], fill=(20, 20, 20), width=4)
    d.text((lx + 28, ly), "zone border", font=fs, fill=(0, 0, 0))
    ly += 16
    d.line([(lx, ly + 6), (lx + 22, ly + 6)], fill=(110, 70, 30), width=4)
    d.text((lx + 28, ly), "road (primary/secondary)", font=fs, fill=(0, 0, 0))
    ly += 16
    d.line([(lx, ly + 6), (lx + 8, ly + 6)], fill=(120, 80, 40), width=2)
    d.line([(lx + 14, ly + 6), (lx + 22, ly + 6)], fill=(120, 80, 40), width=2)
    d.text((lx + 28, ly), "trail", font=fs, fill=(0, 0, 0))
    ly += 16
    d.line([(lx, ly + 6), (lx + 22, ly + 6)], fill=(90, 90, 90), width=1)
    d.text((lx + 28, ly), "capital street", font=fs, fill=(0, 0, 0))
    ly += 16
    d.line([(lx, ly + 6), (lx + 22, ly + 6)], fill=(160, 20, 20), width=2)
    d.text((lx + 28, ly), "capital wall", font=fs, fill=(0, 0, 0))
    ly += 20
    for kind, txt in (("start", "start town"), ("capital", "capital"), ("village", "village"),
                      ("outpost", "outpost"), ("mine", "mine"), ("bandit", "bandit camp/hideout"),
                      ("mirefolk", "mirefolk camp (empty)"), ("clash", "clash site"), ("rare", "rare route"),
                      ("dragon", "dragon"), ("apex", "apex mine")):
        draw_marker(d, lx + 11, ly + 7, kind, size=6)
        d.text((lx + 28, ly), txt, font=fs, fill=(0, 0, 0))
        ly += 17
    d.ellipse([lx + 7, ly + 3, lx + 15, ly + 11], fill=(255, 230, 0), outline=(0, 0, 0))
    d.text((lx + 28, ly), "quest giver (! name)", font=fs, fill=(0, 0, 0))
    ly += 17
    d.ellipse([lx + 8.5, ly + 4.5, lx + 13.5, ly + 9.5], fill=(255, 255, 255), outline=(0, 0, 0))
    d.text((lx + 28, ly), "other service NPC", font=fs, fill=(0, 0, 0))
    ly += 21
    d.text((lx, ly), "B1… sea beaches, L# level steps", font=fs, fill=(0, 0, 0))
    ly += 16
    if f.get("start_rings"):
        d.text((lx, ly), "dashed circles: start bands 100/150", font=fs, fill=(0, 0, 0))
    save_png(canvas, path)


def render_world(G, meta, zone_facts, zone_by_num, path):
    step = G.step
    rows, cols = G.zone.shape
    rgb = np.zeros((rows, cols, 3), dtype=float)
    water_colors = {1: (31, 59, 92), 2: (58, 106, 148), 3: (63, 116, 160), 5: (22, 48, 74), 6: (74, 134, 184)}
    for code, col in water_colors.items():
        rgb[G.wc == code] = col
    # zone tint by level band (tens) and faction
    lut = {}
    for num, z in zone_by_num.items():
        t = (z["level_min"] - 1) / 59.0
        base = np.array(level_color(t), dtype=float)
        if z["faction"] == "accord":
            base = base * 0.75 + np.array([120, 170, 230]) * 0.25
        elif z["faction"] == "throng":
            base = base * 0.75 + np.array([210, 90, 80]) * 0.25
        lut[num] = base
    for num, col in lut.items():
        m = G.land & (G.zone == num)
        rgb[m] = col
    sand = G.land & (G.coast == 1)
    rgb[sand] = rgb[sand] * 0.3 + np.array([240, 222, 160]) * 0.7
    shade = hillshade(G.h)
    rgb[G.land] *= shade[G.land][:, None]
    border = np.zeros(G.zone.shape, dtype=bool)
    zl = np.where(G.land, G.zone, 0)
    border[:, 1:] |= (zl[:, 1:] != zl[:, :-1]) & (zl[:, 1:] > 0) & (zl[:, :-1] > 0)
    border[1:, :] |= (zl[1:, :] != zl[:-1, :]) & (zl[1:, :] > 0) & (zl[:-1, :] > 0)
    rgb[border] = (20, 20, 20)
    prot = G.prot == 1
    rgb[prot] = rgb[prot] * 0.4 + np.array([220, 40, 40]) * 0.6
    img = Image.fromarray(np.flipud(np.clip(rgb, 0, 255)).astype(np.uint8), "RGB")
    left, top, right, bottom = 70, 60, 20, 50
    W, H = cols + left + right, rows + top + bottom
    canvas = Image.new("RGB", (W, H), (250, 250, 247))
    canvas.paste(img, (left, top))
    d = ImageDraw.Draw(canvas)

    def P(x, z):
        return left + (x - G.min_x) / step, top + rows - 1 - (z - G.min_z) / step

    for road in meta["roads"]:
        if road["kind"] in ("avenue", "lane"):
            continue
        pts = [P(x, z) for x, z in road["points"][::4]]
        if len(pts) >= 2:
            d.line(pts, fill=(90, 55, 20), width=2 if road["kind"] != "trail" else 1)
    fs, fb, ft = font(12), font(13, True), font(20, True)
    lab = Labeler(d, fs, (left, top, left + cols, top + rows))
    for a in meta["anchors"]:
        g = marker_group(a["kind"])
        if g in ("start", "capital", "village", "outpost", "mine", "bandit", "mirefolk", "dragon"):
            px, py = P(a["x"], a["z"])
            draw_marker(d, px, py, g, size=5 if g not in ("start", "capital") else 7)
    for f in zone_facts.values():
        px, py = P(f["extent"]["centroid"]["x"], f["extent"]["centroid"]["z"])
        if f["role"] == "capital zone" or f["role"] == "start zone":
            py += 22
        txt = "%s %d-%d" % (f["name"], f["level_min"], f["level_max"])
        tw = d.textbbox((0, 0), txt, font=fb)[2]
        text_halo(d, (px - tw / 2, py - 7), txt, fb)
    for x in range(-3600, 3601, 400):
        px, _ = P(x, 0)
        d.line([(px, top + rows), (px, top + rows + 6)], fill=(0, 0, 0))
        d.text((px - 16, top + rows + 8), str(x), font=fs, fill=(0, 0, 0))
    for z in range(-3200, 3201, 400):
        _, py = P(0, z)
        d.line([(left - 6, py), (left, py)], fill=(0, 0, 0))
        d.text((4, py - 7), str(z), font=fs, fill=(0, 0, 0))
    _, py0 = P(0, 0)
    d.line([(left, py0), (left + cols, py0)], fill=(255, 255, 255), width=1)
    d.text((left, 10), "Grudgelands world · seed %s · north up (+z) · 1 px = 4 nodes · Throng (Kragmar) north, Accord (Elandor) south, Battlegrounds band at z = 0"
           % meta["seed"], font=font(15, True), fill=(0, 0, 0))
    d.text((left, 32), "Zone tint = level band (light low → dark high), blue-ish Accord, red-ish Throng; red = start towns/capital cities; brown = roads/trails; beige = sand",
           font=fs, fill=(60, 60, 60))
    # north arrow + scale bar (500 nodes)
    nx, ny = left + cols - 60, top + 20
    d.polygon([(nx, ny), (nx - 10, ny + 28), (nx, ny + 22), (nx + 10, ny + 28)], fill=(255, 255, 255), outline=(0, 0, 0))
    d.text((nx - 5, ny + 30), "N", font=fb, fill=(255, 255, 255))
    sx, sy = left + 20, top + rows - 30
    d.rectangle([sx, sy, sx + 125, sy + 6], fill=(255, 255, 255), outline=(0, 0, 0))
    d.text((sx, sy + 8), "500 nodes", font=fb, fill=(255, 255, 255))
    save_png(canvas, path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", required=True)
    ap.add_argument("--probe", required=True)
    ap.add_argument("--out", required=True)
    build(ap.parse_args())
