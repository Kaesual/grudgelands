#!/usr/bin/env python3
"""Build the tree concept viewer (Round 46 lane TREE, step 2).

    python3 -I tools/r46_tree/concept/build.py           # write trees.html
    python3 -I tools/r46_tree/concept/build.py --check   # fail if stale
    python3 -I tools/r46_tree/concept/build.py --three-base URL --out FILE

Inlines page.html, shapes.js, treegen.js, viewer.js, the repo's textures (as
data: URIs), today's tree schematics (as node lists, for comparison) and the
jungle bark candidates found in --bark-dir (default: the artist lane's
worktree, ../r46-astree/tools/r46_tree/astra/bark; none found is fine) into
one page.
Run from anywhere; paths are relative to the repository root.
"""
import argparse
import base64
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from mts import read_mts  # noqa: E402

THREE_BASE = "https://cdn.jsdelivr.net/npm/three@0.147.0"

DEFAULT_TEX = "mods/BASE/default/textures/"
TEXTURES = {
    name: DEFAULT_TEX + name + ".png" for name in (
        "default_tree", "default_tree_top", "default_leaves", "default_apple",
        "default_jungletree", "default_jungletree_top", "default_jungleleaves",
        "default_acacia_tree", "default_acacia_tree_top", "default_acacia_leaves",
        "default_pine_tree", "default_pine_tree_top", "default_pine_needles",
        "default_aspen_tree", "default_aspen_tree_top", "default_aspen_leaves",
        "default_grass", "default_grass_side", "default_dirt", "default_dry_grass",
        "default_coniferous_litter")
}
for name in ("grug_trees_silverwood_tree", "grug_trees_silverwood_tree_top",
             "grug_trees_silverwood_leaves", "grug_trees_gravewood_tree",
             "grug_trees_gravewood_tree_top"):
    TEXTURES[name] = "mods/ITEMS/grug_trees/textures/" + name + ".png"
for name in ("grug_nodes_canopy_litter", "grug_nodes_forest_litter",
             "grug_nodes_silver_litter", "grug_nodes_blight_dirt"):
    TEXTURES[name] = "mods/BASE/grug_nodes/textures/" + name + ".png"
TEXTURES["character"] = "mods/BASE/player_api/models/character.png"

SCHEM = "mods/BASE/default/schematics/"
# species -> (schematic, buried layers, note)
TODAY = {
    "apple": (SCHEM + "apple_tree.mts", 0, "apple_tree.mts (meadows, deep and elf forest)"),
    "jungle": (SCHEM + "jungle_tree.mts", 0, "jungle_tree.mts"),
    "kapok": (SCHEM + "emergent_jungle_tree.mts", 4,
              "emergent_jungle_tree.mts, placed 4 nodes deep (buried logs not shown or counted)"),
    "acacia": (SCHEM + "acacia_tree.mts", 0, "acacia_tree.mts"),
    "pine": (SCHEM + "pine_tree.mts", 0, "pine_tree.mts (small_pine_tree.mts: 12 high, 9 logs, 55 needles)"),
    "aspen": (SCHEM + "aspen_tree.mts", 0, "aspen_tree.mts"),
    "silverwood": (SCHEM + "aspen_tree.mts", 0, "aspen_tree.mts with silverwood nodes"),
    "gravewood": ("mods/ITEMS/grug_trees/schematics/grug_gravewood_small.mts", 0,
                  "grug_gravewood_small.mts (blight; the tall one in bone forest: 23 logs, 8 leaves)"),
}


def find_texture(rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path):
        return path
    # grug_nodes may live in another mod group
    base = os.path.basename(rel)
    for top, _dirs, files in os.walk(os.path.join(ROOT, "mods")):
        if base in files:
            return os.path.join(top, base)
    raise SystemExit("missing texture " + rel)


def data_uri(path):
    with open(path, "rb") as handle:
        return "data:image/png;base64," + base64.b64encode(handle.read()).decode()


def kind_of(name):
    if name.endswith("_tree") or name.endswith(":tree") or name.endswith("jungletree"):
        return "trunk"
    if "leaves" in name or "needles" in name:
        return "leaves"
    if name == "default:apple":
        return "fruit"
    return None


def today_tree(species):
    rel, buried, note = TODAY[species]
    data = read_mts(os.path.join(ROOT, rel))
    cells = []
    for cell in data["cells"]:
        kind = kind_of(cell["name"])
        if kind is None:
            continue
        cells.append((cell["x"], cell["y"] - buried, cell["z"], kind,
                      cell["param2"] % 24 if kind == "trunk" else 0))
    cells = [c for c in cells if c[1] >= 0]
    # the trunk base (lowest log) stands at x = 0, z = 0
    base = min((c for c in cells if c[3] == "trunk"), key=lambda c: (c[1], c[0], c[2]))
    logs0 = [c for c in cells if c[3] == "trunk" and c[1] == base[1]]
    bx = min(c[0] for c in logs0) + (max(c[0] for c in logs0) - min(c[0] for c in logs0) + 1) // 2
    bz = min(c[2] for c in logs0) + (max(c[2] for c in logs0) - min(c[2] for c in logs0) + 1) // 2
    nodes = [{"x": c[0] - bx, "y": c[1], "z": c[2] - bz, "kind": c[3], "rot": c[4]} for c in cells]
    nodes.sort(key=lambda n: (n["y"], n["x"], n["z"]))
    count = {"trunk": 0, "quarter": 0, "branch": 0, "twig": 0, "leaves": 0, "fruit": 0}
    for n in nodes:
        count[n["kind"]] += 1
    xs = [n["x"] for n in nodes]
    zs = [n["z"] for n in nodes]
    return {
        "nodes": nodes, "count": count, "wood": count["trunk"],
        "height": max(n["y"] for n in nodes) + 1,
        "width": max(xs) - min(xs) + 1, "depth": max(zs) - min(zs) + 1,
        "min": [min(xs), 0, min(zs)], "max": [max(xs), max(n["y"] for n in nodes), max(zs)],
        "note": note,
    }


BARK_DIR = os.path.join(ROOT, "..", "r46-astree", "tools", "r46_tree", "astra", "bark")


def jungle_barks(bark_dir):
    """Candidate jungle barks: jungle_bark_<id>.png (+ _top.png), sorted."""
    found = []
    if os.path.isdir(bark_dir):
        for name in sorted(os.listdir(bark_dir)):
            if name.startswith("jungle_bark_") and name.endswith(".png") and not name.endswith("_top.png"):
                found.append(name[len("jungle_bark_"):-len(".png")])
    return found


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as handle:
        return handle.read()


def build(three_base, bark_dir):
    textures = {name: data_uri(find_texture(rel)) for name, rel in sorted(TEXTURES.items())}
    barks = jungle_barks(bark_dir)
    for bark in barks:
        textures["jungle_bark_" + bark] = data_uri(os.path.join(bark_dir, "jungle_bark_" + bark + ".png"))
        top = os.path.join(bark_dir, "jungle_bark_" + bark + "_top.png")
        if os.path.exists(top):
            textures["jungle_bark_" + bark + "_top"] = data_uri(top)
    today = {sp: today_tree(sp) for sp in sorted(TODAY)}
    data = ("var TEXTURES = " + json.dumps(textures, indent=0, sort_keys=True) + ";\n" +
            "var TODAY = " + json.dumps(today, separators=(",", ":"), sort_keys=True) + ";\n" +
            "var JUNGLE_BARKS = " + json.dumps(barks) + ";")
    page = read("page.html")
    page = page.replace("%THREE_BASE%", three_base)
    page = page.replace("/*DATA*/", data)
    page = page.replace("/*SHAPES*/", read("shapes.js"))
    page = page.replace("/*TREEGEN*/", read("treegen.js"))
    page = page.replace("/*VIEWER*/", read("viewer.js"))
    return page


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--three-base", default=THREE_BASE)
    parser.add_argument("--out", default=os.path.join(HERE, "trees.html"))
    parser.add_argument("--bark-dir", default=BARK_DIR,
                        help="where the jungle bark candidates are looked for")
    args = parser.parse_args()
    page = build(args.three_base, args.bark_dir)
    if args.check:
        with open(args.out, encoding="utf-8") as handle:
            if handle.read() != page:
                print("trees.html is stale: run build.py")
                return 1
        print("trees.html is current")
        return 0
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote", os.path.relpath(args.out), len(page), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
