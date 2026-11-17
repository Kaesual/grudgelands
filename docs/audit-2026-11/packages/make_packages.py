#!/usr/bin/env python3
"""Cuts the game's Lua (mods/) into the audit's review packages.

Usage: python3 make_packages.py <repo root> <output dir>
First matching rule wins. Writes <pkg>.txt (lines, path) and prints a summary.
"""
import re
import subprocess
import sys
from collections import defaultdict

root, out = sys.argv[1], sys.argv[2]
W40 = r"mods/MAPGEN/grug_mapgen/wp40/"
MOB = r"mods/ENTITIES/grug_mobs/"
P = r"mods/PLAYER/"
I = r"mods/ITEMS/"

RULES = [
    ("VEND", [r"mods/BASE/", r"mods/ENTITIES/mobs/"]),
    ("M1", [W40 + r"(height|terrain_|zone_field|zones|simple_map|source/|index128|map_adapter|deterministic|canonical|counting_allocator)"]),
    ("M2", [W40 + r"(water_|road_|treegen|tree_templates|vegetation_density|habitat_registry|seabed|swamp_|air_chunks|wayposts|wreck_)"]),
    ("M3", [W40 + r"(r6|kit_templates|placement|planner\.lua|r5\.lua)"]),
    ("M4", [W40 + r"(r7_|capital_|city_decor_catalog|arena_|guild_rooms|r\d+_.*blueprint|r58_)"]),
    ("M5", [W40, r"mods/MAPGEN/grug_mapgen/[^/]+\.lua$"]),
    ("W1", [r"mods/MAPGEN/grug_mapgen/wp13/(dressing|parts|palette|decor_kit|templates|city_green|city_edge|layout|capital_services|gate_watch|plot_approach|precinct_ring|dwarf_dressing|troll_palette)\.lua$"]),
    ("W2", [r"mods/MAPGEN/"]),
    ("MOB2", [MOB + r"(spawn_|camps|rares|start_|night_families|capital_displays|pvp_garrison|dawn)"]),
    ("MOB1", [MOB + r"(init|aggro|verbs|routes|patrol|separation|swimmer|flight|roam_avoid|liveness|idle_health|disposition|density|levels|subtypes|guard|npc_doors|door_click|target_frame|telegraph|env_damage|room|names|voices|items|map_reset|zero_asset_variants)"]),
    ("MOB3", [MOB]),
    ("E1", [r"mods/ENTITIES/"]),
    ("C1", [r"mods/CORE/grug_core/"]),
    ("X1", [r"mods/CORE/"]),
    ("C2", [P + r"grug_abilities/"]),
    ("C3", [P + r"(grug_classes|grug_skills|grug_xp|grug_pvp|grug_factions)/"]),
    ("P1", [P + r"(grug_map|grug_visuals|grug_displays|grug_quickbar|grug_keys)/"]),
    ("P2", [P + r"(grug_jobs|grug_guild|grug_achievements)/"]),
    ("P3", [P + r"(grug_inventory|grug_quests|grug_trinkets|grug_money)/"]),
    ("P4", [P + r"(grug_expeditions|grug_housing|grug_home|grug_mounts)/"]),
    ("P5", [P]),
    ("I1", [I + r"(grug_decor|grug_materials|grug_nodes|grug_trees|grug_signs|grug_farming)/"]),
    ("I2", [I]),
]

files = subprocess.run(["git", "-C", root, "ls-files", "mods"], capture_output=True, text=True, check=True).stdout.split("\n")
pk = defaultdict(list)
for f in files:
    if not f.endswith(".lua"):
        continue
    with open(f"{root}/{f}", "rb") as fh:
        n = fh.read().count(b"\n")
    for name, pats in RULES:
        if any(re.match(p, f) for p in pats):
            pk[name].append((n, f))
            break
    else:
        pk["UNASSIGNED"].append((n, f))
for name, rows in pk.items():
    rows.sort(reverse=True)
    with open(f"{out}/{name}.txt", "w") as fh:
        fh.write(f"# package {name}: {len(rows)} files, {sum(n for n, _ in rows)} lines\n")
        for n, f in rows:
            fh.write(f"{n}\t{f}\n")
    print(f"{name}\t{len(rows)} files\t{sum(n for n, _ in rows)} lines")
