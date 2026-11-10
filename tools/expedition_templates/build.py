#!/usr/bin/env python3
"""Writes the Expedition templates from sources/*.py (Round 71 lane FRAME).

  tools/expedition_templates/build.py           write every template
  tools/expedition_templates/build.py --check   every file matches its source

Edit the source, not the file. --check compares the head, the unpacked cells and the
unpacked walk grid (Round 74, walkgrid.py), so another zlib build does not count as a
change. Both refuse a template whose grid fails walkgrid.problems.
"""
import importlib.util
import json
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "mods/PLAYER/grug_expeditions/templates"
sys.path.insert(0, str(HERE))
import registry  # noqa: E402
import template as tpl  # noqa: E402
import walkgrid  # noqa: E402


def load_registry():
    data = json.loads((ROOT / "tools/building_templates/nodes.json").read_text())
    return data["nodes"] if "nodes" in data else data


def build_all():
    nodes = load_registry()

    def walkable(node):
        if node == "air":
            return False
        if node in tpl.OWN_NODES:
            return True
        if node not in nodes:
            raise SystemExit(f"unknown node {node}")
        return nodes[node].get("walkable", True)

    result = []
    for source in sorted((HERE / "sources").glob("*.py")):
        spec = importlib.util.spec_from_file_location(source.stem, source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        template = module.build()
        problems = template.problems(walkable)
        if problems:
            raise SystemExit(f"{source.name}: " + "; ".join(problems))
        grid = walkgrid.build(template, registry.definition)
        problems = walkgrid.problems(template, grid, registry.definition)
        if problems:
            raise SystemExit(f"{source.name}: the walk grid: " + "; ".join(problems[:12]))
        result.append((template, grid))
    return result


def main():
    check = "--check" in sys.argv[1:]
    failed = 0
    for template, grid in build_all():
        path = OUT / f"{template.name}.exp"
        blob = template.to_bytes(grid)
        if check:
            old = path.read_bytes() if path.exists() else None
            stale = old is None or tpl.read_back(old)[1:] != tpl.read_back(blob)[1:] \
                or tpl.read_back(old)[0][:-1] != tpl.read_back(blob)[0][:-1]
            if not stale:
                packed = tpl.read_grid(old)
                stale = packed is None or zlib.decompress(packed) != zlib.decompress(tpl.read_grid(blob))
            if stale:
                print(f"STALE {path.name}")
                failed = 1
            else:
                print(f"OK {path.name} {len(blob)} bytes; grid {walkgrid.notes(grid)}")
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_bytes(blob)
            print(f"wrote {path.name}: {len(blob)} bytes, {len(template.palette)} nodes; grid {walkgrid.notes(grid)}")
    return failed


if __name__ == "__main__":
    sys.exit(main())
