#!/usr/bin/env python3
"""Build the building template gallery as one self-contained HTML page.

    python3 tools/building_templates/viewer/build_gallery.py -o /tmp/gallery.html
    python3 tools/building_templates/viewer/build_gallery.py --fixtures --standalone -o /tmp/g.html

Every template of ``mods/MAPGEN/grug_mapgen/building_templates/templates``
once, in a 3D grid grouped by town (or race), labelled, with its "used N×
in …" list from the layouts and rosters; a click opens one template alone
(orbit, walk, noclip, a layer cut, its points). Roles are resolved through
the game's palettes (``wp13/palette.lua`` and ``troll_palette.lua``, read by
``palettes.lua`` under LuaJIT) for the race the page selects, or as each
template is placed; orientation as format doc §3.2 says; panes settled with
the port of ``parts.resolve_panes`` (``templates.py``, tested by
``test_templates.py``).

Until the freeze has written the real templates, or with ``--fixtures``, the
page shows the hand-written fixtures under ``fixtures/``. Unresolved
textures, meshes, unknown nodes and cells that do not resolve go to stderr.
"""

import argparse
import base64
import json
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_viewer  # noqa: E402
import templates as T  # noqa: E402

REPO = build_viewer.REPO
REAL_DIR = os.path.join(REPO, "mods", "MAPGEN", "grug_mapgen", "building_templates")
FIXTURE_DIR = os.path.join(HERE, "fixtures")
PAGE = os.path.join(HERE, "gallery.html")
RACE_LABELS = {"dwarf": "Dwarf", "human": "Human", "elf": "Elf",
               "orc": "Orc", "troll": "Troll", "undead": "Undead"}
RACE_ORDER = ["human", "dwarf", "elf", "orc", "troll", "undead"]


def title(town):
    return town.replace("_", " ").title()


def load_palettes(lua, names):
    """The game's palettes plus the parts predicates for `names`."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as fh:
        fh.write("\n".join(sorted(names)) + "\n")
        path = fh.name
    try:
        proc = subprocess.run(
            [lua, os.path.join(HERE, "palettes.lua"), "palettes", path],
            cwd=REPO, capture_output=True, text=True)
    finally:
        os.unlink(path)
    if proc.returncode != 0:
        sys.exit("palettes.lua failed:\n%s" % proc.stderr)
    return json.loads(proc.stdout)


def read_sources(base):
    tdir, ldir = os.path.join(base, "templates"), os.path.join(base, "layouts")
    tpls = []
    for name in sorted(os.listdir(tdir)):
        if name.endswith(".tpl"):
            tpls.append(T.parse_template(os.path.join(tdir, name)))
    lays = []
    if os.path.isdir(ldir):
        files = sorted(os.listdir(ldir))
        for ext in (".layout", ".roster"):
            for name in files:
                if name.endswith(ext):
                    lays.append(T.parse_layout(os.path.join(ldir, name)))
    return tpls, lays


def placement_binding(pal, lay, rec):
    """{"main": palette, <channel>: palette} for one placement or use line."""
    def named(name):
        if name not in lay.palettes:
            raise T.FormatError(lay.path, rec["line"], "unknown palette %s" % name)
        race, overrides = lay.palettes[name]
        return pal.bind(race, overrides)
    race = lay.race or "human"
    binding = {"main": named(rec["main"]) if rec.get("main") else pal.bind(race)}
    for channel, name in rec["channels"].items():
        binding[channel] = named(name)
    return binding


def pack_template_cells(tpl, key_index):
    data = bytearray()
    order = []
    for (x, y, z), key in sorted(tpl.cells.items(), key=lambda kv: (kv[0][1], kv[0][2], kv[0][0])):
        if key in (T.FORCE_AIR, T.UNCHANGED):
            continue
        order.append((x, y, z))
        data += struct.pack("<hhhH", x, y, z, key_index[key])
    return order, base64.b64encode(bytes(data)).decode("ascii")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--out", required=True, help="output HTML file")
    ap.add_argument("--fixtures", action="store_true",
                    help="show the fixture templates (fixtures/) instead of the game's")
    ap.add_argument("--source", help="a directory with templates/ and layouts/")
    ap.add_argument("--title", default="Grudgelands Building Templates")
    ap.add_argument("--standalone", action="store_true",
                    help="wrap in a full HTML document for opening the file locally")
    args = ap.parse_args(argv)

    base = args.source or (FIXTURE_DIR if args.fixtures else REAL_DIR)
    if not args.source and not args.fixtures and not os.path.isdir(os.path.join(base, "templates")):
        sys.stderr.write("no templates in %s yet; showing the fixtures\n" % os.path.relpath(base, REPO))
        base = FIXTURE_DIR
    tpls, lays = read_sources(base)
    if not tpls:
        sys.exit("no templates in %s" % base)
    by_name = {t.name: t for t in tpls}

    with open(build_viewer.NODES_JSON, "r", encoding="utf-8") as fh:
        reg = json.load(fh)
    registry, aliases = reg["nodes"], reg.get("aliases", {})

    # Every name the predicates may be asked about.
    lua = build_viewer.find_lua()
    first = load_palettes(lua, ["air"])
    names = set(registry) | set(aliases)
    for roles in list(first["races"].values()) + list(first["troll_overrides"].values()):
        names.update(roles.values())
    for lay in lays:
        for _, overrides in lay.palettes.values():
            names.update(overrides.values())
    for tpl in tpls:
        for entry in tpl.legend.values():
            if entry["kind"] == "node":
                names.add(entry["name"])
    for roles in list(first["races"].values()) + list(first["troll_overrides"].values()):
        for fam, suffixes in first["families"].items():
            if roles.get(fam):
                names.update(roles[fam] + s for s in suffixes)
    pal = T.Palettes(load_palettes(lua, names))

    # Uses: every placement and roster line, in file order.
    uses = {t.name: [] for t in tpls}
    for lay in lays:
        recs = lay.places if lay.kind == "layout" else lay.uses
        for rec in recs:
            if rec["template"] not in by_name:
                sys.stderr.write("%s:%d: unknown template %s\n" % (
                    os.path.relpath(lay.path, REPO), rec["line"], rec["template"]))
                continue
            uses[rec["template"]].append((lay, rec, rec.get("count", 1)))

    # The preview bindings the page offers.
    races = [r for r in RACE_ORDER if r in pal.races] + sorted(r for r in pal.races if r not in RACE_ORDER)
    shared = [(r, RACE_LABELS.get(r, title(r)), {"main": pal.bind(r)}) for r in races]
    for key in sorted(pal.extra):
        shared.append(("troll+" + key.lower(), "Troll + Kezamba %s" % key.lower(),
                       {"main": pal.bind("troll", pal.extra[key])}))

    textures, meshes, type_index, type_names = build_viewer.Textures(), {}, {}, []

    def type_of(name):
        if name == "air":
            return -1
        if name not in type_index:
            type_index[name] = len(type_names)
            type_names.append(name)
        return type_index[name]

    out_templates, problems = [], []
    for tpl in tpls:
        keys = list(tpl.legend_order)
        key_index = {k: i for i, k in enumerate(keys)}
        order, packed = pack_template_cells(tpl, key_index)
        cell_at = {pos: i for i, pos in enumerate(order)}
        tuse = uses[tpl.name]
        if tuse:
            lay, rec, _ = tuse[0]
            placed = placement_binding(pal, lay, rec)
            placed_label = "as in %s" % title(lay.town) + (
                " (%s)" % rec["id"] if rec.get("id") else "")
            town, race = lay.town, lay.race or placed["main"]["race"]
        else:
            race = tpl.races[0] if tpl.races else "human"
            placed = {"main": pal.bind(race)}
            placed_label = "unused; %s palette" % race
            town = None
        res, fix, bad = {}, {}, {}
        for bkey, _, binding in [("placed", None, placed)] + shared:
            resolution = T.resolve(tpl, pal, binding)
            rlist = []
            for k in keys:
                r = resolution[k]
                if isinstance(r, tuple):
                    rlist.append([type_of(r[0]), r[1]])
                else:
                    rlist.append([-1, 0])
            cells, unresolved = T.resolved_cells(tpl, resolution, pal)
            fixes = []
            for pos, (name, p2) in cells.items():
                key = tpl.cells[pos]
                r = resolution.get(key)
                if pos in cell_at and r != (name, p2):
                    fixes.append([cell_at[pos], type_of(name), p2])
            res[bkey], fix[bkey] = rlist, sorted(fixes)
            if unresolved:
                reasons = sorted(set(unresolved.values()))
                bad[bkey] = [len(unresolved), reasons[0]]
                if bkey == "placed":
                    problems.append("%s: %d cells do not resolve as placed: %s" % (
                        tpl.name, len(unresolved), "; ".join(reasons)))
        used = {}
        for lay, rec, n in tuse:
            used[lay.town] = used.get(lay.town, 0) + n
        out_templates.append({
            "name": tpl.name, "town": town, "race": race,
            "pivot": list(tpl.pivot), "origin": list(tpl.origin), "size": list(tpl.size),
            "races": tpl.races, "meta": tpl.meta, "cell": tpl.cell,
            "count": len(order), "cells": packed,
            "legend": ["%s  %s" % (k, tpl.legend[k]["text"]) for k in keys],
            "res": res, "fix": fix, "bad": bad, "placed": placed_label,
            "points": [[p["group"], p["x"], p["y"], p["z"], p["face"], p["text"]]
                       for p in tpl.points],
            "used": [[title(t), n] for t, n in used.items()],
            "source": os.path.relpath(tpl.path, REPO),
        })

    types, report = build_viewer.build_types(type_names, registry, aliases, textures, meshes)
    towns = []
    for lay in lays:
        if lay.town not in [t[0] for t in towns]:
            towns.append((lay.town, title(lay.town), lay.race))
    payload = {
        "templates": out_templates,
        "towns": towns,
        "bindings": [["placed", "As placed"]] + [[k, label] for k, label, _ in shared],
        "types": types,
        "textures": textures.images,
        "meshes": {k: v for k, v in meshes.items() if v is not None},
        "source": os.path.relpath(base, REPO),
    }
    build_viewer.write_page(args.out, PAGE, args.title, payload, args.standalone)

    sys.stderr.write("templates: %d (%d cells) from %s, layouts and rosters: %d\n" % (
        len(out_templates), sum(t["count"] for t in out_templates),
        os.path.relpath(base, REPO), len(lays)))
    sys.stderr.write("node types: %d, textures: %d, meshes: %d, size: %.2f MB\n" % (
        len(types), len(textures.images), len(payload["meshes"]),
        os.path.getsize(args.out) / 1e6))
    for line in problems:
        sys.stderr.write(line + "\n")
    for name, why in sorted(report["skipped"].items()):
        sys.stderr.write("not drawn: %s (%s)\n" % (name, why))
    for mesh in sorted(report["missing_mesh"]):
        sys.stderr.write("mesh not found, drawn as cube: %s\n" % mesh)
    for spec in sorted(textures.missing):
        sys.stderr.write("texture missing: %s\n" % spec)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except T.FormatError as e:
        sys.exit("template error: %s" % e)
