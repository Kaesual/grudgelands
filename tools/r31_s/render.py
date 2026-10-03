#!/usr/bin/env python3
"""Round 31 lane S: preview pictures of the PvP fortress and camp blueprints.

Builds every composition through tools/r31_s/dump.lua (LuaJIT) and draws, per
composition, a top-down plan (the top cell of every column in its texture's
mean colour, shaded by height, sockets as numbered dots) plus the textured
isometric view and an isometric cut-away of tools/wp13/render_blueprint.py.

    python3 tools/r31_s/render.py OUT_DIR

Writes OUT_DIR/<name>_{plan,iso,cut}.png and OUT_DIR/index.json (sockets,
footprint and node counts per composition), which build_page.py turns into the
preview page. Needs Pillow and luajit.
"""
import argparse
import importlib.util
import json
import os
import subprocess
import sys
from types import SimpleNamespace

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location(
    "render_blueprint", os.path.join(REPO, "tools", "wp13", "render_blueprint.py"))
rb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rb)

RACES = [("human", "accord"), ("dwarf", "accord"), ("elf", "accord"),
         ("orc", "throng"), ("undead", "throng"), ("troll", "throng")]
COMPOSITIONS = ([("fortress_" + f, "pvp_fortress", f, "-") for f in ("accord", "throng")] +
                [("camp_low_" + r, "pvp_camp_low", f, r) for r, f in RACES] +
                [("camp_high_" + r, "pvp_camp_high", f, r) for r, f in RACES])

# Socket dot colours by role (and guard group).
ROLE_COLOURS = {
    "gate": (230, 60, 50), "inner": (240, 150, 40), "camp": (240, 150, 40),
    "general": (170, 60, 220), "bodyguard": (200, 120, 240),
    "captain": (170, 60, 220), "quest": (250, 220, 40),
    "vendor": (60, 200, 90), "waypoint": (40, 200, 230),
}


def socket_colour(role, group):
    if role == "guard_post":
        return ROLE_COLOURS.get(group, (240, 150, 40))
    return ROLE_COLOURS.get(role, (255, 255, 255))


def load_tsv(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            rows.append(line.rstrip("\n").split("\t"))
    return rows


class TopColours:
    """Mean colour of a node's top tile, through the wp13 texture bank."""

    def __init__(self, bank):
        self.bank = bank
        self.factory = rb.SpriteFactory(bank, 16, 0)
        self.cache = {}

    def get(self, name):
        if name in self.cache:
            return self.cache[name]
        tiles = self.factory.tiles_for(name)
        img = self.factory.face_image(name, rb.FACE_TOP, tiles) if tiles else None
        colour = None
        if img is not None:
            raw = img.convert("RGBA").tobytes()
            px = [raw[i:i + 4] for i in range(0, len(raw), 4) if raw[i + 3] > 0]
            if px:
                colour = tuple(sum(p[i] for p in px) // len(px) for i in range(3))
        if colour is None:
            colour = rb.flat_color_for(name)[:3]
        self.cache[name] = colour
        return colour


def plan(cells, sockets, top, path, scale, cut=3):
    """Floor plan cut at `cut` nodes above the ground (roofs left off, walls,
    tents and furniture in place): +x right, -z (the gate side at turn 0) at
    the bottom."""
    columns = {}
    for x, y, z, name, _p2 in cells:
        if name == "air" or y > cut:
            continue
        best = columns.get((x, z))
        if best is None or y > best[0]:
            columns[(x, z)] = (y, name)
    xs = [k[0] for k in columns]
    zs = [k[1] for k in columns]
    minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
    ymax = cut
    w, h = (maxx - minx + 1) * scale, (maxz - minz + 1) * scale
    img = Image.new("RGB", (w, h), (24, 26, 30))
    draw = ImageDraw.Draw(img)

    def box(x, z):
        px = (x - minx) * scale
        pz = (maxz - z) * scale
        return px, pz, px + scale - 1, pz + scale - 1

    for (x, z), (y, name) in columns.items():
        c = top.get(name)
        shade = 0.62 + 0.38 * y / ymax
        draw.rectangle(box(x, z), fill=tuple(min(255, int(v * shade)) for v in c))
    # height steps as dark edges, so walls, roofs and tents read as outlines
    for (x, z), (y, _n) in columns.items():
        x0, z0, x1, z1 = box(x, z)
        for dx, dz, line in ((1, 0, (x1, z0, x1, z1)), (0, -1, (x0, z1, x1, z1))):
            other = columns.get((x + dx, z + dz))
            if other and abs(other[0] - y) >= 1 and max(other[0], y) >= 2:
                draw.line(line, fill=(15, 15, 18), width=max(1, scale // 8))
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", max(9, int(scale * 0.62)))
    except OSError:
        font = ImageFont.load_default()
    radius = scale * 0.62
    for index, s in enumerate(sockets, 1):
        x, z = int(s["x"]), int(s["z"])
        x0, z0, x1, z1 = box(x, z)
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        col = socket_colour(s["role"], s["group"])
        draw.ellipse((cx - radius, cz - radius, cx + radius, cz + radius),
                     fill=col, outline=(0, 0, 0), width=max(1, scale // 10))
        label = str(index)
        tw, th = draw.textbbox((0, 0), label, font=font)[2:]
        draw.text((cx - tw / 2, cz - th / 2 - 1), label, fill=(0, 0, 0), font=font)
        # facing tick
        dx, dz = int(s["dir_x"]), int(s["dir_z"])
        draw.line((cx + dx * radius, cz - dz * radius, cx + dx * radius * 1.7,
                   cz - dz * radius * 1.7), fill=(0, 0, 0), width=max(2, scale // 6))
    img.save(path)
    return (maxx - minx + 1, maxz - minz + 1)


def iso(cells, bank, path, scale, view, ymax=None):
    args = SimpleNamespace(view=view, ymax=ymax, ymin=None, region=None, scale=scale,
                           max_pixels=2400, light=False, background="#181a1e")
    img, _stats = rb.render(cells, bank, args)
    img.convert("RGB").save(path, optimize=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--luajit", default="luajit")
    opts = ap.parse_args()
    os.makedirs(opts.out, exist_ok=True)
    bank = rb.TextureBank(rb.DEFAULT_TILES)
    # The waystone is a nodebox the static scanner does not reach.
    bank.nodes["grug_mapgen:waystone"] = {
        "tiles": ["grug_mapgen_waystone_top.png", "grug_mapgen_waystone_top.png",
                  "grug_mapgen_waystone.png"], "drawtype": "normal", "shape": "cube"}
    top = TopColours(bank)
    index = {}
    for name, kind, faction, race in COMPOSITIONS:
        stem = os.path.join(opts.out, name)
        subprocess.run([opts.luajit, os.path.join(HERE, "dump.lua"), REPO, kind, faction,
                        race, "0", stem], check=True, stdout=subprocess.DEVNULL)
        cells = rb.load_cells(stem + ".cells.tsv")
        sockets = [dict(zip(("id", "role", "group", "x", "y", "z", "dir_x", "dir_z"), row))
                   for row in load_tsv(stem + ".sockets.tsv")]
        fortress = kind == "pvp_fortress"
        footprint = plan(cells, sockets, top, stem + "_plan.png", 14 if fortress else 22)
        iso(cells, bank, stem + "_iso.png", 12 if fortress else 16, "sw")
        iso(cells, bank, stem + "_cut.png", 12 if fortress else 16, "sw",
            ymax=4 if fortress else 2)
        os.remove(stem + ".cells.tsv")
        os.remove(stem + ".sockets.tsv")
        index[name] = {"kind": kind, "faction": faction, "race": race,
                       "footprint": footprint, "height": max(c[1] for c in cells),
                       "solid_cells": sum(1 for c in cells if c[3] != "air"),
                       "sockets": sockets}
        sys.stderr.write("%s: %dx%d, %d sockets\n" % (name, footprint[0], footprint[1],
                                                      len(sockets)))
    # The bandit-camp reference at the camps' scale.
    ref = rb.load_cells_from_lua(os.path.join(
        REPO, "mods/MAPGEN/grug_mapgen/wp40/r7_goldmead_bandit_camp_blueprint.lua"))
    iso(ref, bank, os.path.join(opts.out, "bandit_goldmead_iso.png"), 16, "sw")
    with open(os.path.join(opts.out, "index.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=1, sort_keys=True)
    if bank.warnings:
        for msg, count in bank.warnings.most_common(20):
            sys.stderr.write("texture warning: %s (x%d)\n" % (msg, count))
    return 0


if __name__ == "__main__":
    sys.exit(main())
