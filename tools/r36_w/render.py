#!/usr/bin/env python3
"""Round 36 lane W: before/after pictures of the decor pass.

Builds the compositions of two checkouts (BEFORE: e.g. an export of main,
AFTER: this repository) and draws, per item, one picture: the textured
isometric view before and after side by side (tools/wp13/render_blueprint.py
through lane P's `iso`), the top-down plans small underneath.

    python3 tools/r36_w/render.py OUT_DIR --before DIR [--items FILE]
        [--only KEY,...]

An item is a POI key of the settlement roster (built through
tools/r36_p/dump.lua, so it passes `r7_settlement.prepare` and lane P's
exactness check in both trees), or a WP13 piece:

    start:<name>[:x1,z1,x2,z2]        a start composition, optionally a region
    plot:<capital>:<plot id>[,...]     capital plots side by side
    ...@N                              cut away every cell above y = N

Writes OUT_DIR/img/<item>.webp and OUT_DIR/items.json. Needs Pillow (WebP)
and luajit.
"""
import argparse
import importlib.util
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


p_render = load_module("r36_p_render", os.path.join(REPO, "tools", "r36_p", "render.py"))
rb = p_render.rb
r31 = p_render.r31

BACKGROUND = p_render.BACKGROUND
HALF_W, MAIN_H = 800, 760
PLAN_W, PLAN_H = 380, 300

# Pot plants the static tile scanner misses (loop-registered in
# grug_decor/xdecor.lua).
POTS = ["rose", "tulip", "tulip_black", "chrysanthemum_green", "dandelion_white",
        "dandelion_yellow", "geranium", "viola"]


def bank():
    b = rb.TextureBank(rb.DEFAULT_TILES)
    for name, (tiles, shape) in p_render.EXTRA_NODES.items():
        b.nodes[name] = {"tiles": tiles, "drawtype": "normal", "shape": shape}
    for pot in POTS:
        b.nodes["grug_decor:xdecor_potted_" + pot] = {
            "tiles": ["grug_decor_xdecor_xdecor_%s_pot.png" % pot],
            "drawtype": "normal", "shape": "plant"}
    return b


DUMP_WP13 = r"""
local repo, kind, a, b = arg[1], arg[2], arg[3], arg[4]
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local bp
if kind == "start" then
	bp = dofile(wp40 .. "/r7_" .. a .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
else
	local kit = dofile(wp40 .. "/r7_capital_blueprint.lua").kit(a)
	for _, p in ipairs(kit.plots) do if p.id == b then bp = p.build() end end
	assert(bp, "no plot " .. tostring(b))
end
for _, c in ipairs(bp.cells) do
	if c.name ~= "air" then
		io.write(c.x, "\t", c.y, "\t", c.z, "\t", c.name, "\t", c.param2 or 0, "\n")
	end
end
"""


def run_dump(tree, work):
    os.makedirs(work, exist_ok=True)
    if not os.path.exists(os.path.join(work, "index.tsv")):
        subprocess.run(["luajit", os.path.join(tree, "tools", "r36_p", "dump.lua"), tree, work],
                       check=True, capture_output=True, text=True)
    return work


def wp13_cells(tree, kind, a, b, script):
    out = subprocess.run(["luajit", script, tree, kind, a, b or "-"], check=True,
                         capture_output=True, text=True).stdout
    return rb.parse_tsv(out.splitlines())


def crop(cells, region):
    if not region:
        return cells
    x1, z1, x2, z2 = region
    return [c for c in cells if x1 <= c[0] <= x2 and z1 <= c[2] <= z2]


def cut_above(cells, ymax):
    if ymax is None:
        return cells
    return [c for c in cells if c[1] <= ymax]


def side_by_side(images, gap=24):
    w = sum(i.width for i in images) + gap * (len(images) - 1)
    h = max(i.height for i in images)
    out = Image.new("RGB", (w, h), BACKGROUND)
    x = 0
    for i in images:
        out.paste(i, (x, (h - i.height) // 2))
        x += i.width + gap
    return out


def picture(before, after, sockets, b, work, view="sw"):
    """Before | after large, the two plans small underneath."""
    top = r31.TopColours(b)
    imgs = [p_render.iso(cells, b, view, HALF_W, MAIN_H)[0] for cells in (before, after)]
    plans = [p_render.plan(cells, sockets, top, PLAN_W, PLAN_H, work) for cells in (before, after)]
    width = max(HALF_W * 2 + 40, 1)
    row_h = max(i.height for i in imgs)
    plan_h = max(p.height for p in plans)
    out = Image.new("RGB", (width, row_h + plan_h + 16), BACKGROUND)
    for k, img in enumerate(imgs):
        cx = k * (HALF_W + 40)
        out.paste(img, (cx + (HALF_W - img.width) // 2, (row_h - img.height) // 2))
        p = plans[k]
        out.paste(p, (cx + (HALF_W - p.width) // 2, row_h + 16))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--before", required=True, help="checkout to compare against")
    ap.add_argument("--items", help="file with one item per line")
    ap.add_argument("--only", help="comma list of items")
    ap.add_argument("--work", default=None)
    ap.add_argument("--quality", type=int, default=86)
    opts = ap.parse_args()
    items = []
    if opts.items:
        with open(opts.items, encoding="utf-8") as fh:
            items = [l.strip() for l in fh if l.strip() and not l.startswith("#")]
    if opts.only:
        items += opts.only.split(";")
    work = opts.work or tempfile.mkdtemp(prefix="r36_w_")
    os.makedirs(work, exist_ok=True)
    os.makedirs(os.path.join(opts.out, "img"), exist_ok=True)
    script = os.path.join(work, "dump_wp13.lua")
    with open(script, "w", encoding="utf-8") as fh:
        fh.write(DUMP_WP13)
    b = bank()
    poi_dirs = None
    meta = []
    for item in items:
        ymax = None
        if "@" in item:
            item, cut = item.split("@")
            ymax = int(cut)
        parts = item.split(":")
        name = item.replace(":", "_").replace(",", "_")
        if parts[0] == "start":
            region = [int(v) for v in parts[2].split(",")] if len(parts) > 2 else None
            cells = [cut_above(crop(wp13_cells(t, "start", parts[1], None, script), region), ymax)
                     for t in (opts.before, REPO)]
            img = picture(cells[0], cells[1], [], b, work)
        elif parts[0] == "plot":
            rows = []
            for plot in parts[2].split(","):
                cells = [cut_above(wp13_cells(t, "plot", parts[1], plot, script), ymax)
                         for t in (opts.before, REPO)]
                rows.append(cells)
            # the plots in a row, before above after
            befores = side_by_side([p_render.iso(c[0], b, "sw", 520, 520)[0] for c in rows])
            afters = side_by_side([p_render.iso(c[1], b, "sw", 520, 520)[0] for c in rows])
            img = Image.new("RGB", (max(befores.width, afters.width),
                                    befores.height + afters.height + 30), BACKGROUND)
            img.paste(befores, (0, 0))
            img.paste(afters, (0, befores.height + 30))
        else:
            if poi_dirs is None:
                poi_dirs = (run_dump(opts.before, os.path.join(work, "before")),
                            run_dump(REPO, os.path.join(work, "after")))
            cells = [rb.load_cells(os.path.join(d, "%s__game.tsv" % item)) for d in poi_dirs]
            sockets = [dict(zip(("id", "role", "group", "x", "y", "z", "dir_x", "dir_z"), s))
                       for s in p_render.read_tsv(os.path.join(poi_dirs[1], item + ".sockets.tsv"))]
            img = picture(cells[0], cells[1], sockets, b, work)
        if ymax is not None:
            name += "_cut%d" % ymax
        rel = "img/%s.webp" % name
        img.save(os.path.join(opts.out, rel), "WEBP", quality=opts.quality, method=6)
        meta.append({"item": item, "image": rel, "size": [img.width, img.height]})
        sys.stderr.write("%-40s %dx%d\n" % (item, img.width, img.height))
    with open(os.path.join(opts.out, "items.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=1)
    if b.warnings:
        for msg, count in b.warnings.most_common(10):
            sys.stderr.write("texture warning: %s (x%d)\n" % (msg, count))
    return 0


if __name__ == "__main__":
    sys.exit(main())
