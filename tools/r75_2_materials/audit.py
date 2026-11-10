#!/usr/bin/env python3
"""Audit Round 75 decoration materials from the real engine node dump."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VIEWER = ROOT / "tools/building_templates/viewer"
sys.path.insert(0, str(VIEWER))
import build_viewer  # noqa: E402
import texture_support  # noqa: E402

texture_support.install(build_viewer.render_blueprint)


VISUAL_FIELDS = (
    "drawtype", "tiles", "overlay_tiles", "special_tiles", "use_texture_alpha",
    "mesh", "node_box", "selection_box", "paramtype", "paramtype2",
    "visual_scale", "sunlight_propagates", "light_source", "walkable",
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def inventory(root: Path, nodes: dict[str, dict]) -> dict[str, list[str]]:
    decor = root / "mods/ITEMS/grug_decor"
    furnishings = re.findall(
        r'item = "(grug_decor:[a-z0-9_]+)"', read(decor / "furnishings_catalog.lua"))
    furnishings += ["grug_decor:display_armor", "grug_decor:display_weapon"]
    painting_ids = re.findall(
        r'id = "([a-z0-9_]+)"', read(decor / "paintings_catalog.lua"))
    paintings = ["grug_decor:painting_" + item_id for item_id in painting_ids]

    display_source = read(root / "mods/PLAYER/grug_displays/nodes.lua")
    displays = []
    for table_name in ("FRAME_IDS", "STAND_IDS"):
        body = re.search(r"local " + table_name + r" = \{(.*?)\n\}",
                         display_source, re.S)
        if not body:
            raise ValueError("missing display table " + table_name)
        displays.extend(re.findall(r'"([a-z0-9_]+:[a-z0-9_]+)"', body.group(1)))
    holder = re.search(r'M\.WEAPON_HOLDER = "([a-z0-9_]+:[a-z0-9_]+)"', display_source)
    if not holder:
        raise ValueError("missing display weapon holder")
    displays.append(holder.group(1))

    city = sorted(name for name in nodes if name.startswith("grug_decor:city_"))
    return {
        "furnishings": furnishings,
        "paintings": paintings,
        "displays": displays,
        "city": city,
    }


def source_for_city(name: str) -> str:
    return "grug_decor:" + name.removeprefix("grug_decor:city_")


def tile_spec(tile) -> str:
    if isinstance(tile, dict):
        return tile.get("name") or tile.get("image") or ""
    return tile or ""


def alpha_stats(image) -> dict[str, int]:
    histogram = image.getchannel("A").histogram()
    nonempty = [value for value, count in enumerate(histogram) if count]
    return {"min": nonempty[0], "max": nonempty[-1],
            "zero": histogram[0], "partial": sum(histogram[1:255])}


def unique_materials(path: Path) -> list[str]:
    if path.suffix != ".obj":
        return []
    out = []
    for material in re.findall(r"^usemtl\s+(\S+)", read(path), re.M):
        if material not in out:
            out.append(material)
    return out


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def run(root: Path, nodes_path: Path) -> tuple[dict, list[str]]:
    data = json.loads(read(nodes_path))
    nodes = data["nodes"]
    groups = inventory(root, nodes)
    errors: list[str] = []
    expected = {"furnishings": 58, "paintings": 16, "displays": 8, "city": 112}
    for group, count in expected.items():
        if len(groups[group]) != count:
            errors.append(f"{group}: expected {count} definitions, got {len(groups[group])}")
        if len(set(groups[group])) != len(groups[group]):
            errors.append(f"{group}: duplicate definition names")

    all_names = groups["furnishings"] + groups["paintings"] + groups["displays"] + groups["city"]
    if len(all_names) != 194:
        errors.append(f"scope: expected 194 rows, got {len(all_names)}")
    for name in all_names:
        if name not in nodes:
            errors.append(f"{name}: missing from engine node dump")

    bank = build_viewer.render_blueprint.TextureBank(
        build_viewer.render_blueprint.DEFAULT_TILES)
    records = {}
    checked_specs = {}
    mesh_records = {}
    for name in all_names:
        definition = nodes.get(name)
        if not definition:
            continue
        record = {"alpha_mode": definition.get("use_texture_alpha", "opaque"),
                  "textures": []}
        for index, tile in enumerate(definition.get("tiles") or []):
            spec = tile_spec(tile)
            image = bank.texture(spec)
            if image is None:
                errors.append(f"{name}: tile {index} is unresolved: {spec}")
                record["textures"].append({"spec": spec, "missing": True})
                continue
            stats = alpha_stats(image)
            record["textures"].append({"spec": spec, **stats})
            checked_specs[spec] = stats
        records[name] = record

        mesh = definition.get("mesh") if definition.get("drawtype") == "mesh" else None
        if mesh:
            buffers = build_viewer.load_mesh(mesh)
            tiles = definition.get("tiles") or []
            if buffers is None:
                errors.append(f"{name}: mesh is unresolved: {mesh}")
                continue
            if not buffers or any(not buffer for buffer in buffers):
                errors.append(f"{name}: mesh has an empty material group: {mesh}")
            if len(buffers) != len(tiles):
                errors.append(
                    f"{name}: mesh groups/tiles differ: {len(buffers)} != {len(tiles)} ({mesh})")
            model_path = build_viewer.find_model(mesh)
            materials = unique_materials(Path(model_path)) if model_path else []
            if mesh.startswith("grug_decor_furnish_") and materials != [
                    f"texture_slot_{index}" for index in range(len(tiles))]:
                errors.append(f"{name}: furnishing mesh material order differs: {materials}")
            if mesh.startswith("grug_decor_painting_") and materials != ["wood", "canvas"]:
                errors.append(f"{name}: painting mesh material order differs: {materials}")
            mesh_records[name] = {"mesh": mesh, "groups": len(buffers),
                                  "tiles": len(tiles), "materials": materials}

    heraldry = {"grug_decor:tapestry_accord", "grug_decor:tapestry_throng"}
    for name in groups["furnishings"]:
        definition = nodes.get(name, {})
        mode = definition.get("use_texture_alpha")
        if name in heraldry:
            if mode != "clip":
                errors.append(f"{name}: heraldry must keep intentional clip alpha")
            continue
        if mode != "opaque":
            errors.append(f"{name}: solid furnishing is not explicitly opaque")
        for tile in records.get(name, {}).get("textures", []):
            if not tile.get("missing") and (tile["min"] != 255 or tile["max"] != 255):
                errors.append(f"{name}: solid furnishing texture retains alpha: {tile['spec']}")

    for name in groups["paintings"]:
        definition = nodes.get(name, {})
        if definition.get("use_texture_alpha") != "opaque":
            errors.append(f"{name}: painting is not explicitly opaque")
        for tile in records.get(name, {}).get("textures", []):
            if not tile.get("missing") and tile["zero"]:
                errors.append(f"{name}: painting texture has zero-alpha pixels: {tile['spec']}")

    for name in groups["displays"]:
        definition = nodes.get(name, {})
        if definition.get("use_texture_alpha", "opaque") != "opaque":
            errors.append(f"{name}: solid functional display is not opaque")

    for warning, count in sorted(bank.warnings.items()):
        errors.append(f"texture resolver warning ({count}): {warning}")

    parity_fields = list(VISUAL_FIELDS)
    for city_name in groups["city"]:
        source_name = source_for_city(city_name)
        city = nodes.get(city_name)
        source = nodes.get(source_name)
        if not source:
            errors.append(f"{city_name}: source node is missing: {source_name}")
            continue
        if not city:
            continue
        for field in parity_fields:
            # City paintings deliberately use the one-node frame geometry, but
            # retain the source's complete material list and order.
            if city_name.startswith("grug_decor:city_painting_") and field in (
                    "mesh", "selection_box"):
                continue
            if canonical(city.get(field)) != canonical(source.get(field)):
                errors.append(f"{city_name}: visual field {field} differs from {source_name}")

    report = {
        "schema": 1,
        "nodes": str(nodes_path.relative_to(root) if nodes_path.is_relative_to(root) else nodes_path),
        "counts": {group: len(names) for group, names in groups.items()},
        "total": len(all_names),
        "unique_texture_specs": len(checked_specs),
        "texture_warnings": dict(sorted(bank.warnings.items())),
        "mesh_nodes": len(mesh_records),
        "errors": errors,
        "groups": groups,
        "materials": records,
        "meshes": mesh_records,
    }
    return report, errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--nodes", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.repo.resolve()
    nodes = (args.nodes or root / "tools/building_templates/nodes.json").resolve()
    report, errors = run(root, nodes)
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    if errors:
        for error in errors:
            print("FAIL " + error)
        print(f"R75.2 MATERIAL AUDIT FAIL errors={len(errors)} nodes={report['total']}")
        return 1
    print("R75.2 MATERIAL AUDIT PASS " +
          " ".join(f"{key}={value}" for key, value in report["counts"].items()) +
          f" total={report['total']} textures={report['unique_texture_specs']} " +
          f"mesh_nodes={report['mesh_nodes']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
