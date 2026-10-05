#!/usr/bin/env python3
"""Round 36 lane P: review pictures of every POI.

Builds every POI through tools/r36_p/dump.lua (LuaJIT; the settlement roster
as the game walks it) and draws, per POI, ONE picture holding four views:

  * the in-game look: the textured isometric view of tools/wp13/
    render_blueprint.py, camera over the gate side for the PvP POIs;
  * a top-down plan (tools/r31_s/render.py `plan`: cut 3 nodes above the
    ground, roofs off, sockets as numbered dots), north (+z) up;
  * the same composition in two other palettes: for the Round 14 and Round 20
    POIs the two races whose materials differ most from its own (mean colour
    distance of the top textures, cell by cell over the composition), for a
    PvP camp the two other races of its faction (the world seed rolls one of
    the three), for a fortress the other faction's materials (it has no race
    palette); a dragon arena has none.

    python3 tools/r36_p/render.py OUT_DIR [--work DIR] [--luajit luajit]

Writes OUT_DIR/img/<key>.webp, the review page OUT_DIR/index.html (page.py)
and WORK/pois.json (the POI rows, the picture's size and each view's
rectangle in it; `page.py OUT_DIR WORK/pois.json` rebuilds the page alone).
Needs Pillow (with WebP) and luajit.
"""
import argparse
import importlib.util
import json
import math
import os
import subprocess
import sys
import tempfile
from types import SimpleNamespace

from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def load_module(name, rel):
    spec = importlib.util.spec_from_file_location(name, os.path.join(REPO, rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


rb = load_module("render_blueprint", "tools/wp13/render_blueprint.py")
r31 = load_module("r31_s_render", "tools/r31_s/render.py")
page = load_module("r36_p_page", "tools/r36_p/page.py")

BACKGROUND = "#181a1e"
WIDTH = 1200          # picture width; the main view fills it
MAIN_MAX_H = 900
SMALL_W, SMALL_MAX_H = WIDTH // 3, 360
PLAN_CUT = 3

# Nodes the static tile scanner does not reach (mods/MAPGEN/grug_mapgen:
# poi_displays.lua, world_nodes.lua and the waystone).
EXTRA_NODES = {
    "grug_mapgen:waystone": (["grug_mapgen_waystone_top.png", "grug_mapgen_waystone_top.png",
                              "grug_mapgen_waystone.png"], "cube"),
    "grug_mapgen:poi_display_dwarf": (["default_copper_block.png"], "cube"),
    "grug_mapgen:poi_display_human": (["default_brick.png"], "cube"),
    "grug_mapgen:poi_display_elf": (["default_meselamp.png^[colorize:#ff7a2e:25"], "cube"),
    "grug_mapgen:poi_display_undead": (["default_stone_brick.png"], "cube"),
    "grug_mapgen:poi_display_orc": (["default_desert_cobble.png"], "cube"),
    "grug_mapgen:poi_display_troll": (["default_clay.png"], "cube"),
    "grug_mapgen:arena_thin_ice": (["default_ice.png^[colorize:#eafcff:120^[opacity:210"], "glass"),
    "grug_mapgen:arena_ice_water": (["default_water.png^[colorize:#bdf2ff:110^[opacity:170"], "glass"),
    "grug_mapgen:arena_frost_stone": (["default_stone.png^[colorize:#a9c7e3:150"], "cube"),
    "grug_mapgen:arena_ember": (["default_lava.png^[colorize:#ff6a10:70"], "nodebox"),
    "grug_mapgen:arena_basalt": (["default_stone.png^[colorize:#2a2626:190"], "cube"),
    # loop-registered in grug_nodes/init.lua and grug_decor/xdecor.lua
    "grug_nodes:dirt_with_canopy_litter": (["grug_nodes_canopy_litter.png", "default_dirt.png",
                                            "default_dirt.png^grug_nodes_canopy_litter_side.png"], "cube"),
    "grug_decor:xdecor_potted_chrysanthemum_green": (
        ["grug_decor_xdecor_xdecor_chrysanthemum_green_pot.png"], "plant"),
}

# The gate side of a PvP composition (local -z at turn 0, turned with it) and
# the camera corner that looks at it.
GATE_VIEW = {0: "sw", 1: "sw", 2: "nw", 3: "se"}


def read_tsv(path):
    with open(path, encoding="utf-8") as fh:
        return [line.rstrip("\n").split("\t") for line in fh if line.strip()]


def iso(cells, bank, view, max_w, max_h):
    """The isometric view at the largest integer scale that fits."""
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    zs = [c[2] for c in cells]
    span = (max(xs) - min(xs)) + (max(zs) - min(zs)) + 4
    height = max(ys) - min(ys) + 2
    scale = max(1, int(1.5 * min(max_w / span, max_h / (span / 2.0 + height))))
    bg = Image.new("RGB", (1, 1), BACKGROUND).getpixel((0, 0))
    while True:
        args = SimpleNamespace(view=view, ymax=None, ymin=None, region=None, scale=scale,
                               max_pixels=100000, light=False, background=BACKGROUND)
        img, stats = rb.render(cells, bank, args)
        img = img.convert("RGB")
        # crop the renderer's empty margin (its box reserves the full height)
        box = ImageChops.difference(img, Image.new("RGB", img.size, bg)).getbbox()
        if box:
            pad = max(2, scale // 2)
            img = img.crop((max(0, box[0] - pad), max(0, box[1] - pad),
                            min(img.width, box[2] + pad), min(img.height, box[3] + pad)))
        if (img.width <= max_w and img.height <= max_h) or scale == 1:
            stats["scale"] = scale
            return img, stats
        scale -= 1


def plan(cells, sockets, top, max_w, max_h, work):
    spanx = max(c[0] for c in cells) - min(c[0] for c in cells) + 1
    spanz = max(c[2] for c in cells) - min(c[2] for c in cells) + 1
    scale = max(2, min(max_w // spanx, max_h // spanz))
    path = os.path.join(work, "_plan.png")
    r31.plan(cells, sockets, top, path, scale, PLAN_CUT)
    img = Image.open(path).convert("RGB")
    img.load()
    return img


def palette_distance(top, own, alt):
    """Mean RGB distance of the top-texture colours, cell by cell."""
    by_pos = {(c[0], c[1], c[2]): c[3] for c in alt}
    total, n = 0.0, 0
    for x, y, z, name, _p2 in own:
        other = by_pos.get((x, y, z))
        if other is None or other == name:
            n += 1
            continue
        a, b = top.get(name), top.get(other)
        total += math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))
        n += 1
    return total / max(1, n)


def compose(main, smalls):
    """One picture: the main view on top, up to three small views below.
    Returns the image and the rectangles [x, y, w, h] of every view."""
    row_h = max([s.height for s in smalls] or [0])
    img = Image.new("RGB", (WIDTH, main.height + row_h), BACKGROUND)
    mx = (WIDTH - main.width) // 2
    img.paste(main, (mx, 0))
    rects = [[0, 0, WIDTH, main.height]]
    for i, s in enumerate(smalls):
        cx = i * SMALL_W
        img.paste(s, (cx + (SMALL_W - s.width) // 2, main.height + (row_h - s.height) // 2))
        rects.append([cx, main.height, SMALL_W, row_h])
    return img, rects


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--work", default=None, help="dump directory (default: a temp dir)")
    ap.add_argument("--luajit", default="luajit")
    ap.add_argument("--quality", type=int, default=88, help="WebP quality")
    ap.add_argument("--only", default=None, help="comma list of POI keys (testing)")
    opts = ap.parse_args()
    work = opts.work or tempfile.mkdtemp(prefix="r36_p_")
    os.makedirs(work, exist_ok=True)
    os.makedirs(os.path.join(opts.out, "img"), exist_ok=True)
    proc = subprocess.run([opts.luajit, os.path.join(HERE, "dump.lua"), REPO, work],
                          check=True, capture_output=True, text=True)
    sys.stderr.write(proc.stdout)

    bank = rb.TextureBank(rb.DEFAULT_TILES)
    for name, (tiles, shape) in EXTRA_NODES.items():
        bank.nodes[name] = {"tiles": tiles, "drawtype": "normal", "shape": shape}
    top = r31.TopColours(bank)

    rows = read_tsv(os.path.join(work, "index.tsv"))
    fields, rows = rows[0], [dict(zip(rows[0], r)) for r in rows[1:]]
    only = set(opts.only.split(",")) if opts.only else None
    pois, flat = [], set()
    for row in rows:
        key = row["key"]
        if only and key not in only:
            continue
        variants = row["variants"].split(",")
        cells = {v: rb.load_cells(os.path.join(work, "%s__%s.tsv" % (key, v))) for v in variants}
        sockets = [dict(zip(("id", "role", "group", "x", "y", "z", "dir_x", "dir_z"), s))
                   for s in read_tsv(os.path.join(work, key + ".sockets.tsv"))]
        group = row["group"]
        alts = [v for v in variants if v != "game"]
        distances = {v: round(palette_distance(top, cells["game"], cells[v]), 1) for v in alts}
        if group.startswith("pvp_"):
            chosen = alts
        else:
            chosen = sorted(alts, key=lambda v: -distances[v])[:2]
        view = GATE_VIEW[int(row["turns"])] if group.startswith("pvp_") else "sw"
        main_img, stats = iso(cells["game"], bank, view, WIDTH, MAIN_MAX_H)
        flat.update(stats["flat"])
        smalls = [plan(cells["game"], sockets, top, SMALL_W - 8, SMALL_MAX_H, work)]
        for v in chosen:
            img, st = iso(cells[v], bank, view, SMALL_W - 8, SMALL_MAX_H)
            flat.update(st["flat"])
            smalls.append(img)
        picture, rects = compose(main_img, smalls)
        rel = "img/%s.webp" % key
        picture.save(os.path.join(opts.out, rel), "WEBP", quality=opts.quality, method=6)
        poi = {f: row[f] for f in fields if f != "variants"}
        for f in ("level_min", "level_max", "numeric_id", "x", "z", "turns"):
            poi[f] = int(poi[f])
        poi.update({
            "image": rel, "size": [picture.width, picture.height],
            "main": rects[0], "plan": rects[1],
            "alts": [{"palette": v[4:], "rect": r} for v, r in zip(chosen, rects[2:])],
            "distances": {v[4:]: d for v, d in distances.items()},
            "cells": sum(1 for c in cells["game"] if c[3] != "air"),
            "sockets": [{"id": s["id"], "role": s["role"]} for s in sockets],
            "view": view, "scale": stats["scale"],
        })
        pois.append(poi)
        sys.stderr.write("%-44s %-16s %5d cells, view %s, alts %s\n"
                         % (key, group, poi["cells"], view, ",".join(chosen) or "-"))
    with open(os.path.join(work, "pois.json"), "w", encoding="utf-8") as fh:
        json.dump(pois, fh, indent=1, sort_keys=True)
    if not only:
        page.write(opts.out, pois)
    if flat:
        sys.stderr.write("UNRESOLVED (flat colour): %s\n" % ", ".join(sorted(flat)))
    for msg, count in bank.warnings.most_common(20):
        sys.stderr.write("texture warning: %s (x%d)\n" % (msg, count))
    sys.stderr.write("%d POIs\n" % len(pois))
    return 0


if __name__ == "__main__":
    sys.exit(main())
