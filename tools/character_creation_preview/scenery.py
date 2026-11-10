#!/usr/bin/env python3
"""Build saved character backdrops using the shared building-template renderer.

The six scene JSON files are the editable source: placements, camera, palette,
props and vegetation. Existing shipped templates are read, never modified.
This produces an offline scene viewer and a recipe/input receipt. Render PNGs
with render-scenes.mjs, then run build.py to embed them in the layout study.
Tools only; no world generation, gameplay state or engine process is changed.
"""
import hashlib
import json
import math
from pathlib import Path
import random
import re
import subprocess
import sys
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VIEWER = ROOT / "tools/building_templates/viewer"
sys.path.insert(0, str(VIEWER))
import build_viewer as V
import build_gallery as G
import templates as T


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def load_trees(specs):
    keys = sorted({f"{tree['species']}:{tree['seed']}" for spec in specs for tree in spec['trees']})
    result = subprocess.run(['luajit', str(HERE / 'export-trees.lua'), str(ROOT), *keys],
                            check=True, capture_output=True, text=True)
    trees = {key: [] for key in keys}
    for line in result.stdout.splitlines():
        key, x, y, z, name, param2, root = line.split('\t')
        trees[key].append((int(x), int(y), int(z), name, int(param2), root == '1'))
    assert all(trees.values()), 'empty generated tree'
    return trees


def make_scene(spec, palettes, registry, trees):
    cells = {}
    rng = random.Random(spec["seed"])
    heights = {}
    footprints = []

    def route_at(z):
        knots = spec["route"]
        if z < knots[0][0] or z > knots[-1][0]:
            return 0, 0
        for (za, xa, wa), (zb, xb, wb) in zip(knots, knots[1:]):
            if za <= z <= zb:
                t = (z - za) / (zb - za)
                return xa + (xb - xa) * t, wa + (wb - wa) * t
        return knots[-1][1], knots[-1][2]

    def put(x, y, z, name, p2=0, empty=False):
        assert name in registry, name
        if empty:
            cells.setdefault((x, y, z), (name, p2))
        else:
            cells[x, y, z] = (name, p2)

    def fill(a, b, name, p2=0, empty=False):
        for x in range(a[0], b[0] + 1):
            for y in range(a[1], b[1] + 1):
                for z in range(a[2], b[2] + 1):
                    put(x, y, z, name, p2, empty)

    # A bounded, authored stage; no gameplay terrain generator or seed fleet.
    for x in range(-42, 43):
        for z in range(-22, 83):
            rim = max(0, abs(x) - 23) * .28 + max(0, z - 45) * .24
            h = max(0, math.floor(rim * (1 + .22 * math.sin(x * .17 + z * .13))))
            heights[x, z] = h
            for y in range(-2, h):
                put(x, y, z, spec["soil"])
            center, width = route_at(z)
            is_path = abs(x - center) < width
            top = spec["path"] if is_path else spec["ground"]
            if spec["race"] == "dwarf" and h > 3:
                top = "default:stone"
            put(x, h, z, top)

    templates_used = {}
    for place in spec["buildings"]:
        path = ROOT / "mods/MAPGEN/grug_mapgen/building_templates/templates" / (place["template"] + ".tpl")
        template = T.parse_template(str(path))
        town = place["template"].split("_")[0]
        layout_path = ROOT / "mods/MAPGEN/grug_mapgen/building_templates/layouts" / (town + ".layout")
        layout = T.parse_layout(str(layout_path))
        placement = next(p for p in layout.places if p["template"] == place["template"])
        binding = G.placement_binding(palettes, layout, placement)
        stamp, bad = T.resolved_cells(template, T.resolve(template, palettes, binding), palettes)
        assert not bad, bad
        xs, ys, zs = zip(*stamp)
        cx, cz = (min(xs) + max(xs)) // 2, (min(zs) + max(zs)) // 2
        px, py, pz = place["at"]
        footprint = [px + min(xs) - cx, pz + min(zs) - cz, px + max(xs) - cx, pz + max(zs) - cz]
        footprints.append(footprint)
        for (x, y, z), (name, p2) in stamp.items():
            at = (px + x - cx, py + y, pz + z - cz)
            if name == "air":
                if at[1] > 0:
                    cells.pop(at, None)
            elif registry.get(name, {}).get("drawtype") != "airlike":
                put(*at, name, p2)
        templates_used[place["template"]] = hashlib.sha256(path.read_bytes()).hexdigest()
        templates_used[town + ".layout"] = hashlib.sha256(layout_path.read_bytes()).hexdigest()

    for prop in spec["props"]:
        kind = prop["kind"]
        if kind == "node":
            put(*prop["at"], prop["node"], prop.get("param2", 0))
        elif kind == "blocks":
            fill(prop["from"], prop["to"], prop["node"], prop.get("param2", 0))
        elif kind == "patch":
            x, z = prop["at"]
            rx, rz = prop["radius"]
            for xx in range(x - rx, x + rx + 1):
                for zz in range(z - rz, z + rz + 1):
                    if ((xx - x) / rx) ** 2 + ((zz - z) / rz) ** 2 <= 1:
                        h = heights[xx, zz]
                        if cells.get((xx, h, zz), (None,))[0] == spec["ground"]:
                            put(xx, h, zz, prop["node"])
        elif kind == "wall":
            fill(prop["from"], prop["to"], spec["stone"])
            for x, y, z in (prop["from"], prop["to"]):
                put(x, y + 1, z, spec["stone"])
        elif kind == "water":
            x0, _, z0 = prop["from"]
            x1, _, z1 = prop["to"]
            for x in range(x0, x1 + 1):
                for z in range(z0, z1 + 1):
                    if any(a <= x <= c and b <= z <= d for a, b, c, d in footprints):
                        continue
                    put(x, 0, z, "default:river_water_source")
        elif kind == "deck":
            fill(prop["from"], prop["to"], "default:junglewood")
            x0, y, z0 = prop["from"]
            x1, _, z1 = prop["to"]
            for x in (x0, x1):
                for z in range(z0, z1 + 1, 5):
                    fill((x, 0, z), (x, y, z), "default:jungletree")
                fill((x, y + 1, z0), (x, y + 1, z1), "default:fence_junglewood")
        elif kind == "graves":
            x, y, z = prop["at"]
            for i, node in enumerate(("grug_nodes:gravestone_stele", "grug_nodes:gravestone_fallen", "grug_nodes:gravestone_cross")):
                put(x + (i % 2) * 2, y, z + i * 3, node)
        else:
            raise ValueError(kind)

    for tree in spec["trees"]:
        x, y, z = tree["at"]
        y += heights[x, z] + 1  # Generator y=0 is the first node above ground.
        stamp = trees[f"{tree['species']}:{tree['seed']}"]
        # Authored positions must support the generator's flat-ground roots.
        # Fail instead of clipping a tree against a building or another tree.
        for dx, dy, dz, name, p2, root in stamp:
            at = (x + dx, y + dy, z + dz)
            existing = cells.get(at)
            if root:
                assert heights[x + dx, z + dz] == y - 1, (spec['race'], tree, 'root terrain')
                support = cells.get((x + dx, y - 1, z + dz), (None,))[0]
                groups = registry.get(support, {}).get('groups', {})
                assert groups.get('soil') or groups.get('sand') or support == 'default:gravel', (spec['race'], tree, 'root support', support)
                assert not existing, (spec['race'], tree, at, 'root collision', existing)
            if existing and not root:
                leafy = lambda n: registry[n].get('drawtype') in ('allfaces_optional', 'plantlike')
                assert leafy(name) or leafy(existing[0]), (spec['race'], tree, at, name, existing)
                if leafy(name):
                    continue
            put(*at, name, p2)

    for _ in range(spec.get("plant_count", 380)):
        x, z = rng.randint(-33, 33), rng.randint(-8, 64)
        h = heights[x, z]
        if cells.get((x, h, z), (None,))[0] != spec["ground"]:
            continue
        if any(a - 1 <= x <= c + 1 and b - 1 <= z <= d + 1 for a, b, c, d in footprints):
            continue
        put(x, h + 1, z, rng.choice(spec["plants"]), empty=True)

    # Keep a clear standing point at the intended character position.
    floor = 1 if spec["race"] == "troll" else 0
    assert all((x, y, z) not in cells for x in (-1, 0, 1) for y in range(floor + 1, floor + 5) for z in (-1, 0, 1))
    if "portrait" in spec:
        x, y, z = spec["portrait"]["feet"]
        # The reference figure stands on the top face of a real scene node.
        assert y == math.floor(y) + .5
        assert (round(x), math.floor(y), round(z)) in cells
        assert all((xx, yy, zz) not in cells
                   for xx in range(math.floor(x - .5), math.ceil(x + .5) + 1)
                   for yy in range(math.floor(y) + 1, math.ceil(y + 1.68 * spec["portrait"]["stature"]) + 1)
                   for zz in range(math.floor(z - .5), math.ceil(z + .5) + 1))
    return cells, templates_used


def main():
    registry_file = ROOT / "tools/building_templates/nodes.json"
    reg = json.loads(registry_file.read_text())
    palettes = T.Palettes(G.load_palettes("luajit", set(reg["nodes"]) | set(reg.get("aliases", {}))))
    textures, meshes, names, indices, scenes, receipts = V.Textures(), {}, [], {}, {}, {}
    # The engine supplies blank.png; use the project's identical empty RGBA
    # tile when rendering offline (bed faces inside the existing templates).
    source_texture = textures.bank.texture
    def texture(name):
        if name == "blank.png":
            image = Image.open(ROOT / "mods/ENTITIES/grug_mobs/textures/grug_mobs_blank.png").convert("RGBA")
            assert image.getchannel("A").getextrema() == (0, 0)
            return image
        return source_texture(name)
    textures.bank.texture = texture
    specs = [json.loads(path.read_text()) for path in sorted((HERE / "scenes").glob("*.json"))]
    trees = load_trees(specs)
    # Keep authored portrait sizes aligned with the actual game race scalars.
    source = (ROOT / "mods/PLAYER/grug_visuals/compose.lua").read_text()
    statures = {race: float(value) for race, value in re.findall(
        r"(\w+)\s*=\s*\{stature\s*=\s*([0-9.]+)\}", source)}
    for spec in specs:
        assert spec["portrait"]["stature"] == statures[spec["race"]], spec["race"]
        assert spec["portrait"]["units_per_pixel"] == .0525
        cells, template_hashes = make_scene(spec, palettes, reg["nodes"], trees)
        raw = [(*pos, *node) for pos, node in sorted(cells.items())]
        scenes[spec["race"]] = V.pack_cells({"spec": spec}, raw, indices, names)
        receipts[spec["race"]] = {"templates": template_hashes, "cells": len(cells), "recipe": digest(spec)}
    types, report = V.build_types(names, reg["nodes"], reg.get("aliases", {}), textures, meshes)
    assert not report["skipped"] and not report["missing_mesh"] and not textures.missing, (report, textures.missing)
    body = json.loads((ROOT / "tools/r54_armor/data/catalog.json").read_text())["body"]
    payload = {"scenes": scenes, "types": types, "textures": textures.images, "meshes": meshes, "body": body}
    shared = {"types": types, "textures": textures.images, "meshes": meshes,
              "renderer": hashlib.sha256((VIEWER / "renderer.js").read_bytes()).hexdigest(),
              "page": hashlib.sha256((HERE / "scenes.html.in").read_bytes()).hexdigest(),
              "three": hashlib.sha256((ROOT / "tools/r54_armor/vendor/three.min.js").read_bytes()).hexdigest(),
              "orbit": hashlib.sha256((ROOT / "tools/r69_camp_art/orbit.js").read_bytes()).hexdigest(),
              "adapter": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "tree_sources": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in (HERE / 'export-trees.lua',
                                            ROOT / 'mods/MAPGEN/grug_mapgen/wp40/treegen.lua',
                                            ROOT / 'mods/MAPGEN/grug_mapgen/wp40/tree_templates.lua')},
              "capture": hashlib.sha256((HERE / "render-scenes.mjs").read_bytes()).hexdigest(),
              "portrait": hashlib.sha256((HERE / "portrait.js").read_bytes()).hexdigest(), "body": body}
    for race, scene in scenes.items():
        scene["digest"] = digest({"scene": scene, "shared": shared})
        receipts[race]["render_input"] = scene["digest"]
    page = V.inline_renderer((HERE / "scenes.html.in").read_text())
    page = page.replace("__PORTRAIT__", (HERE / "portrait.js").read_text())
    # Same offline Three.js revision adapter as the castle/camp preview tools.
    page = page.replace("t.colorSpace = THREE.SRGBColorSpace;", "t.encoding = THREE.sRGBEncoding;")
    page = page.replace("renderer.outputColorSpace = THREE.SRGBColorSpace;", "renderer.outputEncoding = THREE.sRGBEncoding;")
    for token, path in {"__THREE__": ROOT / "tools/r54_armor/vendor/three.min.js",
                        "__ORBIT__": ROOT / "tools/r69_camp_art/orbit.js",
                        "__LICENSE__": ROOT / "tools/r69_camp_art/THREE-LICENSE.txt"}.items():
        page = page.replace(token, path.read_text().replace("</", "<\\/"))
    page = page.replace("__PAYLOAD__", json.dumps(payload, separators=(",", ":")).replace("</", "<\\/"))
    (HERE / "scenes.html").write_text(page)
    (HERE / "scene-build.json").write_text(json.dumps(receipts, indent=2) + "\n")
    print(json.dumps({"scenes": {r: v["cells"] for r, v in receipts.items()}, "node_types": len(types), "textures": len(textures.images), "missing": 0}))


if __name__ == "__main__":
    main()
