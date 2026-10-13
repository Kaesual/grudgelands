#!/usr/bin/env python3
"""Pack one hand-placed tree and repository textures into the standalone viewer."""

import argparse
import base64
from collections import Counter
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

# Each character is one deliberately placed node, x = -3..4, z = -3..4.
# Read rows from -z to +z; the layers run from the ground upward.
# Digits are the quarter's facedir. B = branch, t = twig, # = leaf, a = apple.
# No randomness, ellipsoids, canopy fill, or inferred wood placement.
BASE = """
........
........
........
...03...
...12...
........
........
........
"""
LAYERS = [BASE, BASE, BASE, BASE, """
........
...a....
....B...
..BBB...
.a..B...
......a.
........
........
""", """
........
...##...
.#..B#a.
#BB.....
.#..BB#.
.....##.
.....#..
........
""", """
...##...
.######.
.t##B##.
tB###t##
#t###Bt#
.##.#t##
....#t#.
.....a..
""", """
..####..
.###t##.
###tt###
#t###t##
######t#
#######.
..###t#.
....##..
""", """
...##...
..#####.
.##t###.
.#######
.######.
..#####.
...##...
........
""", """
........
...###..
..#####.
..####..
...##...
........
........
........
"""]


def connected(h):
    return {
        "type": "connected", "core": [-h, -h, -h, h, h, h],
        "arms": {
            "top": [-h, h, -h, h, 8, h],
            "bottom": [-h, -8, -h, h, -h, h],
            "front": [-h, -h, -8, h, h, -h],
            "back": [-h, -h, h, h, h, 8],
            "left": [-8, -h, -h, -h, h, h],
            "right": [h, -h, -h, 8, h, h],
        },
    }


SHAPES = {
    "quarter": {"type": "fixed", "boxes": [
        [-8, -8, 4, -4, 8, 8],
        [-4, -8, -4, 4, 8, 8],
        [4, -8, -8, 8, 8, 8],
    ]},
    "branch": connected(5),
    "twig": connected(2),
}


def authored_nodes():
    nodes = []
    kinds = {"B": "branch", "t": "twig", "#": "leaves", "a": "fruit"}
    for y, layer in enumerate(LAYERS):
        rows = layer.strip().splitlines()
        assert len(rows) == 8 and all(len(row) == 8 for row in rows)
        for zi, row in enumerate(rows):
            for xi, c in enumerate(row):
                if c == ".":
                    continue
                assert c in "0123Bt#a"
                nodes.append({"x": xi - 3, "y": y, "z": zi - 3,
                              "kind": "quarter" if c.isdigit() else kinds[c],
                              "rot": int(c) if c.isdigit() else 0})
    return nodes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare without writing")
    args = parser.parse_args()
    nodes = authored_nodes()
    texture_dir = ROOT / "mods/BASE/default/textures"
    textures = {}
    for key, filename in {"bark": "default_tree.png", "end": "default_tree_top.png",
                          "leaf": "default_leaves.png", "apple": "default_apple.png",
                          "grass": "default_grass.png"}.items():
        textures[key] = "data:image/png;base64," + base64.b64encode(
            (texture_dir / filename).read_bytes()).decode("ascii")
    html = (HERE / "apple.template.html").read_text()
    for key, value in {"NODES": nodes, "SHAPES": SHAPES, "TEXTURES": textures}.items():
        assert html.count("@@" + key + "@@") == 1
        html = html.replace("@@" + key + "@@", json.dumps(value, separators=(",", ":")))
    outputs = {"apple.html": html, "apple-nodes.json": json.dumps(nodes, indent=2) + "\n"}
    for name, content in outputs.items():
        path = HERE / name
        if args.check:
            assert path.read_text() == content, f"Stale {name}; run build.py"
        else:
            path.write_text(content)
    print(("PASS" if args.check else "Built") + ": " + str(len(nodes)) + " nodes; "
          + json.dumps(dict(sorted(Counter(n["kind"] for n in nodes).items()))))


if __name__ == "__main__":
    main()
