#!/usr/bin/env python3
"""Build the swamp concept page (Round 47 lane SW).

    python3 -I tools/r47_sw/build.py           # write tools/r47_sw/swamp.html
    python3 -I tools/r47_sw/build.py --check   # fail if stale
    python3 -I tools/r47_sw/build.py --art-dir DIR --out FILE

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
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
TREE = os.path.join(ROOT, "tools", "r46_tree", "concept")

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
    data = ("var TEXTURES = " + json.dumps(textures, indent=0, sort_keys=True) + ";\n" +
            "var ART_SET = " + json.dumps(art) + ";")
    page = read(os.path.join(HERE, "page.html"))
    page = page.replace("%THREE_BASE%", three_base)
    page = page.replace("/*DATA*/", data)
    page = page.replace("/*SHAPES*/", read(os.path.join(TREE, "shapes.js")))
    page = page.replace("/*TREEGEN*/", read(os.path.join(TREE, "treegen.js")))
    page = page.replace("/*PATCH*/", read(os.path.join(HERE, "patch.js")))
    page = page.replace("/*VIEW*/", read(os.path.join(HERE, "view.js")))
    return page, art


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--three-base", default=THREE_BASE)
    parser.add_argument("--out", default=os.path.join(HERE, "swamp.html"))
    parser.add_argument("--art-dir", default=ART_DIR, help="where the ART lane's swamp textures are looked for")
    args = parser.parse_args()
    page, art = build(args.three_base, args.art_dir)
    if args.check:
        with open(args.out, encoding="utf-8") as handle:
            if handle.read() != page:
                print("swamp.html is stale: run build.py")
                return 1
        print("swamp.html is current (%d ART textures)" % len(art))
        return 0
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote", os.path.relpath(args.out), len(page), "bytes,", len(art), "ART textures from",
          os.path.relpath(args.art_dir) if art else "nowhere")
    return 0


if __name__ == "__main__":
    sys.exit(main())
