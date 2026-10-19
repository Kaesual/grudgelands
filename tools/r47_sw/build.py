#!/usr/bin/env python3
"""Build the swamp concept page (Round 47 lane SW) and the land viewer
(Round 51 lane VIEW).

    python3 -I tools/r47_sw/build.py           # write swamp.html and land.html
    python3 -I tools/r47_sw/build.py --check   # fail if either is stale
    python3 -I tools/r47_sw/build.py --art-dir DIR --out FILE
    python3 -I tools/r47_sw/build.py --local FILE   # also a wrapped land page for file://

land.html is page content only (no doctype, html, head or body: the
publisher wraps it); --local writes a copy wrapped in a document, for
opening from file:// (not committed). It inlines land_page.html, patch.js,
land.js, mesh.js, land_view.js, the tree concept's shapes.js and
treegen.js, the zone data read from the mapgen sources (surface and
decoration rows, the fertile palettes, the schematics, the gathering
sources), the props of tools/r51_land/props and every texture it names.

Inlines page.html, patch.js, view.js, the tree concept's shapes.js and
treegen.js (tools/r46_tree/concept), the repo's textures (as data: URIs)
and the ART lane's swamp proposals found in --art-dir (default: the artist
lane's tools/r47_art/swamp in this checkout once merged, else the artist's
worktree next to this one; none found is fine, the page then offers only
the stand-ins) into one page that works from file://.
Run from anywhere; paths are relative to the repository root.
"""
import argparse
import base64
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
TREE = os.path.join(ROOT, "tools", "r46_tree", "concept")
sys.path.insert(0, TREE)
from mts import read_mts  # noqa: E402

THREE_BASE = "https://cdn.jsdelivr.net/npm/three@0.147.0"

DEFAULT_TEX = "mods/BASE/default/textures/"
TEXTURES = {
    name: DEFAULT_TEX + name + ".png" for name in (
        "default_dirt", "default_grass", "default_grass_side", "default_moss", "default_moss_side",
        "default_water", "default_papyrus", "default_marram_grass_3", "default_junglegrass",
        "default_grass_3", "default_grass_4", "default_grass_5", "default_fern_1", "default_fern_2",
        "default_fern_3", "default_dry_shrub", "default_leaves", "default_jungleleaves")
}
TEXTURES["grug_nodes_mud"] = "mods/ITEMS/grug_nodes/textures/grug_nodes_mud.png"
TEXTURES["grug_mapgen_waterlily"] = "mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waterlily.png"
TEXTURES["grug_trees_gravewood_tree"] = "mods/ITEMS/grug_trees/textures/grug_trees_gravewood_tree.png"
TEXTURES["grug_trees_gravewood_tree_top"] = "mods/ITEMS/grug_trees/textures/grug_trees_gravewood_tree_top.png"
TEXTURES["character"] = "mods/BASE/player_api/models/character.png"

# The ART lane's proposals (tools/r47_art/swamp, CC0, provenance in
# tools/r47_art/LICENSE-media.md); before that branch is merged, its worktree.
ART_FILES = ("mud_dry_top", "mud_dry_side", "mud_mottled_top", "mud_mottled_side", "wet_grass_top",
             "wet_grass_side", "moss_carpet_top", "reeds", "cattails", "hanging_moss", "swamp_leaves")
ART_DIRS = [os.path.join(ROOT, "tools", "r47_art", "swamp"),
            os.path.join(ROOT, "..", "r47-art", "tools", "r47_art", "swamp")]
ART_DIR = next((d for d in ART_DIRS if os.path.isdir(d)), ART_DIRS[0])

# The texture lab's proposals (Round 51 concept, tools/r51_land/swamp_calm.py),
# inlined as lab_<file> when present.
LAB_DIR = os.path.join(ROOT, "tools", "r51_land", "swamp")


def data_uri(path):
    with open(path, "rb") as handle:
        return "data:image/png;base64," + base64.b64encode(handle.read()).decode()


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def build(three_base, art_dir):
    textures = {}
    for name, rel in sorted(TEXTURES.items()):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            raise SystemExit("missing texture " + rel)
        textures[name] = data_uri(path)
    art = []
    for name in ART_FILES:
        path = os.path.join(art_dir, name + ".png")
        if os.path.exists(path):
            textures["art_" + name] = data_uri(path)
            art.append(name)
    if os.path.isdir(LAB_DIR):
        for name in sorted(os.listdir(LAB_DIR)):
            if name.endswith(".png") and not name.startswith("preview"):
                textures["lab_" + name[:-4]] = data_uri(os.path.join(LAB_DIR, name))
    data = ("var TEXTURES = " + json.dumps(textures, indent=0, sort_keys=True) + ";\n" +
            "var ART_SET = " + json.dumps(art) + ";")
    page = read(os.path.join(HERE, "page.html"))
    page = page.replace("%THREE_BASE%", three_base)
    page = page.replace("/*DATA*/", data)
    page = page.replace("/*SHAPES*/", read(os.path.join(TREE, "shapes.js")))
    page = page.replace("/*TREEGEN*/", read(os.path.join(TREE, "treegen.js")))
    page = page.replace("/*PATCH*/", read(os.path.join(HERE, "patch.js")))
    page = page.replace("/*MESH*/", read(os.path.join(HERE, "mesh.js")))
    page = page.replace("/*VIEW*/", read(os.path.join(HERE, "view.js")))
    return page, art


# ---------------------------------------------------------------- land viewer

LAND_ART = os.path.join(ROOT, "tools", "r51_land")
LAND_ART_DIRS = ("swamp", "grounds", "plants")   # every PNG in these joins the texture lab
MANIFEST = "mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua"
R6_CONTENT = "mods/MAPGEN/grug_mapgen/wp40/r6_content.lua"
CATALOG = "mods/ITEMS/grug_gathering/catalog.lua"
SCHEMATICS = "mods/BASE/default/schematics/"
# grug_gathering/presentation.lua: crops show their stage-4 crop look in the
# wild (grug_nodes/crop_visual.lua, visual_scale 1.15), three have a world
# sprite of their own
CROP_LOOK = ("corn", "melon", "mushroom", "potato")
WORLD_SPRITE = ("gravemoss", "sunleaf", "wild_cocoa")
# the reused sources that are plants (catalog REUSE)
REUSE_PLANTS = [{"key": "blueberry", "name": "Blueberries", "biomes": ["grug_pine_hills"],
                 "image": "default_blueberry_bush_leaves.png^default_blueberry_overlay.png", "scale": 1}]


def lua_block(text, name):
    start = text.index("local " + name + " = [[") + len("local " + name + " = [[")
    return text[start:text.index("]]", start)].strip().splitlines()


def land_rows():
    text = read_root(MANIFEST)
    surfaces = {}
    for line in lua_block(text, "SURFACE_ROWS"):
        f = line.split("|")
        surfaces[f[0]] = {"top": f[1], "filler": f[2], "filler_depth": int(f[3]), "shore": f[4], "bed": f[5], "dust": f[6]}
    rows = []
    for index, line in enumerate(lua_block(text, "DECORATION_ROWS")):
        f = line.split("|")
        rows.append({"id": f[0], "biomes": f[1].split(";"), "kind": f[2], "asset": f[3], "host": f[4],
                     "num": int(f[5]), "den": int(f[6]), "rules": f[7].split(";"), "settlement": f[8],
                     "salt": 1000 + index * 17})
    return surfaces, rows


def land_palettes():
    text = read_root(R6_CONTENT)
    start = text.index("local fertile_palettes = {")
    block = text[start:text.index("\n\t}", start)]
    out = {}
    for name, values in re.findall(r"(grug_[a-z_]+) = \{([^}]*)\}", block):
        out[name] = re.findall(r'"([^"]+)"', values)
    return out


def land_schematics(rows):
    names = sorted({r["asset"][:-4] for r in rows if r["asset"].endswith(".mts")} |
                   {"bush", "acacia_bush", "papyrus_on_dirt"})
    out = {}
    for name in names:
        data = read_mts(os.path.join(ROOT, SCHEMATICS + name + ".mts"))
        cells = [{"x": c["x"], "y": c["y"], "z": c["z"], "name": c["name"], "prob": c["prob"], "param2": c["param2"]}
                 for c in data["cells"]]
        out[name] = {"size": list(data["size"]), "base": min(c["y"] for c in cells), "cells": cells}
    return out


def land_gathering():
    text = read_root(CATALOG)
    block = text[text.index("local P9G = {"):text.index("local REUSE = {")]
    out = []
    for chunk in block.split("\tp9g(")[1:]:
        strings = re.findall(r'"([^"]*)"', chunk)
        key, name = strings[1], strings[2]
        biomes = set(re.findall(r'host\("(grug_[a-z_]+)"', chunk))
        if "swamp_hosts(" in chunk or "extended_hosts(" in chunk:
            biomes.add("grug_swamp")
        if "ALL_DRY_HOSTS" in chunk:
            # every dry host, but only beside the sea (its shore predicate): the beach
            biomes.add("grug_beach")
        image, scale = [v for v in strings if ".png" in v][-1], 1
        if key in CROP_LOOK:
            image, scale = "grug_farming_" + key + "_4.png", 1.15
        elif key in WORLD_SPRITE:
            image = "grug_gathering_" + key + "_plant.png"
        out.append({"key": key, "name": name, "biomes": sorted(biomes), "image": image, "scale": scale})
    return out + REUSE_PLANTS


def land_props():
    """tools/r51_land/props/<id>/prop.json (the prop format, README)."""
    root = os.path.join(LAND_ART, "props")
    out = {}
    if not os.path.isdir(root):
        return out
    for prop in sorted(os.listdir(root)):
        path = os.path.join(root, prop, "prop.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        tiles = ["props/" + prop + "/" + t for t in data["tiles"]]
        out[prop] = {"name": data.get("name", prop), "drop": data.get("drop", ""), "tiles": tiles,
                     "boxes": data["boxes"], "alpha": data.get("alpha", ""), "rotate": data.get("rotate", True)}
    return out


def read_root(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as handle:
        return handle.read()


_MOD_PNG = None


def mod_png(name):
    """A texture of the game by file name (searched under mods/)."""
    global _MOD_PNG
    if _MOD_PNG is None:
        _MOD_PNG = {}
        for top, _dirs, files in os.walk(os.path.join(ROOT, "mods")):
            for f in files:
                if f.endswith(".png"):
                    _MOD_PNG.setdefault(f, os.path.join(top, f))
    return _MOD_PNG.get(name)


def land_textures(texts):
    """Every texture named in the sources and data, plus the lab's art."""
    names = set()
    for text in texts:
        names |= set(re.findall(r"[A-Za-z0-9_/]+\.png", text))
    for sub in LAND_ART_DIRS:
        folder = os.path.join(LAND_ART, sub)
        if os.path.isdir(folder):
            names |= {sub + "/" + f for f in os.listdir(folder) if f.endswith(".png") and not f.startswith("preview")}
    out = {}
    for name in sorted(names):
        if "/" in name:
            path = os.path.join(LAND_ART, name)
        else:
            path = mod_png(name)
        if not path or not os.path.exists(path):
            raise SystemExit("missing texture " + name)
        out[name[:-4]] = data_uri(path)
    out["character"] = data_uri(os.path.join(ROOT, TEXTURES["character"]))
    return out


def build_land(three_base):
    surfaces, rows = land_rows()
    data = {"surfaces": surfaces, "rows": rows, "palettes": land_palettes(), "schematics": land_schematics(rows),
            "gathering": land_gathering(), "props": land_props()}
    data_json = json.dumps(data, separators=(",", ":"), sort_keys=True)
    sources = {name: read(os.path.join(HERE, name)) for name in ("land.js", "land_view.js")}
    textures = land_textures([data_json] + list(sources.values()))
    page = read(os.path.join(HERE, "land_page.html"))
    page = page.replace("%THREE_BASE%", three_base)
    page = page.replace("/*DATA*/", "var TEXTURES = " + json.dumps(textures, indent=0, sort_keys=True) + ";\n" +
                        "var LAND_DATA = " + data_json + ";")
    page = page.replace("/*SHAPES*/", read(os.path.join(TREE, "shapes.js")))
    page = page.replace("/*TREEGEN*/", read(os.path.join(TREE, "treegen.js")))
    page = page.replace("/*PATCH*/", read(os.path.join(HERE, "patch.js")))
    page = page.replace("/*MESH*/", read(os.path.join(HERE, "mesh.js")))
    page = page.replace("/*LAND*/", sources["land.js"])
    page = page.replace("/*LANDVIEW*/", sources["land_view.js"])
    return page


def wrapped(page):
    title = re.search(r"<title>(.*?)</title>", page).group(1)
    return ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>" + title +
            "</title>\n</head>\n<body>\n" + page + "\n</body>\n</html>\n")


def check_or_write(path, page, check):
    name = os.path.basename(path)
    if check:
        with open(path, encoding="utf-8") as handle:
            if handle.read() != page:
                print(name + " is stale: run build.py")
                return 1
        print(name + " is current (%d bytes)" % len(page))
        return 0
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote", os.path.relpath(path), len(page), "bytes")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--three-base", default=THREE_BASE)
    parser.add_argument("--out", default=os.path.join(HERE, "swamp.html"))
    parser.add_argument("--land-out", default=os.path.join(HERE, "land.html"))
    parser.add_argument("--local", help="also write the land page wrapped in a document here (for file://)")
    parser.add_argument("--art-dir", default=ART_DIR, help="where the ART lane's swamp textures are looked for")
    args = parser.parse_args()
    page, art = build(args.three_base, args.art_dir)
    land = build_land(args.three_base)
    if len(land.encode("utf-8")) > 16 * 1024 * 1024:
        raise SystemExit("land.html is over 16 MB")
    status = check_or_write(args.out, page, args.check)
    status = check_or_write(args.land_out, land, args.check) or status
    if not args.check:
        print(len(art), "ART textures from", os.path.relpath(args.art_dir) if art else "nowhere")
    if args.local:
        with open(args.local, "w", encoding="utf-8") as handle:
            handle.write(wrapped(land))
        print("wrote", args.local)
    return status


if __name__ == "__main__":
    sys.exit(main())
