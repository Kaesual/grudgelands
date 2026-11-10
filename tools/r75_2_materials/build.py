#!/usr/bin/env python3
"""Build the labelled actual-texture Round 75.2 material gallery."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VIEWER = ROOT / "tools/building_templates/viewer"
sys.path.insert(0, str(VIEWER))
import build_viewer  # noqa: E402
import audit  # noqa: E402


def lua_quote(value: str) -> str:
    return json.dumps(value)


def scene_text(names: list[str], columns: int) -> str:
    spacing = 3
    rows = math.ceil(len(names) / columns)
    cells = []
    landmarks = []
    for index, name in enumerate(names):
        x = index % columns * spacing
        z = index // columns * spacing
        key = name.split(":", 1)[1]
        cells.append(f'  {{x={x},y=1,z={z},name={lua_quote(name)},param2=0}},')
        cells.append(f'  {{x={x},y=0,z={z},name="default:stonebrick",param2=0}},')
        landmarks.append(
            f'  [{lua_quote(key)}]={{min={{x={x},y=1,z={z}}},max={{x={x},y=1,z={z}}}}},')
    max_x = max(0, (columns - 1) * spacing)
    max_z = max(0, (rows - 1) * spacing)
    return "\n".join([
        "return {",
        f" bounds={{min={{x=-2,y=0,z=-2}},max={{x={max_x + 2},y=3,z={max_z + 2}}}}},",
        " landmarks={", *landmarks, " },", " cells={", *cells, " },", "}", "",
    ])


def write(path: Path, content: str, check: bool) -> None:
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if check:
        if old != content:
            raise SystemExit(f"stale generated file: {path.relative_to(ROOT)}")
    elif old != content:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    nodes_path = ROOT / "tools/building_templates/nodes.json"
    nodes = json.loads(nodes_path.read_text(encoding="utf-8"))["nodes"]
    groups = audit.inventory(ROOT, nodes)
    new_city = {"grug_decor:city_" + name.split(":", 1)[1]
                for name in groups["furnishings"] + groups["paintings"]}
    scenes = [
        ("reported_four.lua", [
            "grug_decor:alchemy_set", "grug_decor:writing_set",
            "grug_decor:scroll_bundle", "grug_decor:tool_board",
        ], 4),
        ("furnishings.lua", groups["furnishings"], 10),
        ("paintings_displays.lua", groups["paintings"] + groups["displays"], 6),
        ("city_round75.lua", [name for name in groups["city"] if name in new_city], 10),
        ("city_existing.lua", [name for name in groups["city"] if name not in new_city], 8),
    ]
    scene_dir = HERE / "scenes"
    for filename, names, columns in scenes:
        write(scene_dir / filename, scene_text(names, columns), args.check)

    output = HERE / "index.html"
    if args.check:
        before = output.read_bytes() if output.exists() else None
        temporary = HERE / ".index.check.html"
        target = temporary
    else:
        target = output
    rc = build_viewer.main([
        *(str(scene_dir / filename) for filename, _, _ in scenes),
        "--standalone", "--title", "Round 75.2 Decoration Materials",
        "-o", str(target),
    ])
    if rc:
        return rc
    if args.check:
        current = target.read_bytes()
        target.unlink()
        if before != current:
            raise SystemExit("stale generated file: tools/r75_2_materials/index.html")
    print(f"R75.2 MATERIAL GALLERY {'CURRENT' if args.check else 'BUILT'} " +
          " ".join(f"{filename[:-4]}={len(names)}" for filename, names, _ in scenes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
