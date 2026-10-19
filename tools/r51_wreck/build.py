#!/usr/bin/env python3
"""Build the shipwreck preview page (Round 51 lane WRECK, design step).

    python3 -I tools/r51_wreck/build.py           # write wreck.html and wreck_local.html
    python3 -I tools/r51_wreck/build.py --check   # fail if wreck.html is stale

Inlines page.html, notes.js, view.js, the shape files (tools/r51_wreck/shapes,
written by shapes.py) and the textures as data: URIs: ARTS's wreck and
seagrass textures from tools/r51_sea, the repo's default sand, water, mossy
cobble and the player skin. wreck.html is the page content only (the
publisher wraps it); wreck_local.html is the same wrapped in a document, to
open from file:// (not committed). Run from anywhere.
"""
import argparse
import base64
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import shapes  # noqa: E402  (this folder's shape generator)

THREE_BASE = "https://cdn.jsdelivr.net/npm/three@0.147.0"
SEA = "tools/r51_sea/"
DEFAULT = "mods/BASE/default/textures/"
TEXTURES = {name: SEA + name + ".png" for name in (
    "wreck_planks", "wreck_planks_algae", "wreck_log", "wreck_log_top", "wreck_mast", "wreck_rope",
    "wreck_sail", "wreck_algae", "seagrass_1", "seagrass_2", "seagrass_3")}
TEXTURES.update({name: DEFAULT + name + ".png" for name in ("default_sand", "default_water", "default_mossycobble")})
TEXTURES["character"] = "mods/BASE/player_api/models/character.png"


def data_uri(path):
    with open(path, "rb") as handle:
        return "data:image/png;base64," + base64.b64encode(handle.read()).decode()


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def build(three_base):
    textures = {}
    for name, rel in sorted(TEXTURES.items()):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            raise SystemExit("missing texture " + rel)
        textures[name] = data_uri(path)
    files = dict(shapes.outputs())
    for name, data in files.items():
        on_disk = os.path.join(HERE, "shapes", name)
        if not os.path.exists(on_disk) or read(on_disk) != shapes.render(data):
            raise SystemExit("shapes/" + name + " is stale: run shapes.py")
    data = {
        "shapes": [files[n + ".json"] for n in ("hull", "bow", "stern", "debris")],
        "nodes": files["nodes.json"]["nodes"],
        "textures": textures,
    }
    page = read(os.path.join(HERE, "page.html"))
    page = page.replace("%THREE_BASE%", three_base)
    page = page.replace("/*DATA*/", "var WRECK = " + json.dumps(data, sort_keys=True, separators=(",", ":")) + ";")
    page = page.replace("/*NOTES*/", read(os.path.join(HERE, "notes.js")))
    page = page.replace("/*VIEW*/", read(os.path.join(HERE, "view.js")))
    return page


def wrapped(page):
    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n' +
            page + '</body>\n</html>\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--three-base", default=THREE_BASE)
    parser.add_argument("--out", default=os.path.join(HERE, "wreck.html"))
    args = parser.parse_args()
    page = build(args.three_base)
    if args.check:
        if not os.path.exists(args.out) or read(args.out) != page:
            print("wreck.html is stale: run build.py")
            return 1
        print("wreck.html is current")
        return 0
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(page)
    local = os.path.join(os.path.dirname(args.out), "wreck_local.html")
    with open(local, "w", encoding="utf-8") as handle:
        handle.write(wrapped(page))
    print("wrote", os.path.relpath(args.out), len(page), "bytes, and", os.path.relpath(local))
    return 0


if __name__ == "__main__":
    sys.exit(main())
