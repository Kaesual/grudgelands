#!/usr/bin/env python3
"""Tests of the gallery's template reader (templates.py).

    python3 tools/building_templates/viewer/test_templates.py

- the fixtures parse as written (box, legend, cells, points, layouts, roster);
- the resolver follows format doc §3.2 (families, optional roles and their
  fallback, race switches, the orientation rules, the roof channel);
- the pane port equals ``parts.resolve_panes`` (run through LuaJIT by
  ``palettes.lua panes``): on every fixture for every race palette, and on
  2000 random 5x5 pane neighbourhoods covering every branch.

Exits 1 on the first failure. Python 3 and LuaJIT; no engine.
"""

import json
import os
import random
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_gallery  # noqa: E402
import build_viewer  # noqa: E402
import templates as T  # noqa: E402

REPO = build_viewer.REPO
FIX = os.path.join(HERE, "fixtures")
CHECKS = [0]


def check(cond, what):
    CHECKS[0] += 1
    if not cond:
        sys.exit("FAIL: %s" % what)


def lua_panes(lua, cells):
    """parts.resolve_panes over {(x, y, z): (name, p2)} through LuaJIT."""
    text = "".join("%d %d %d %s %d\n" % (x, y, z, n, p) for (x, y, z), (n, p) in cells.items())
    proc = subprocess.run([lua, os.path.join(HERE, "palettes.lua"), "panes"],
                          cwd=REPO, input=text, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit("FAIL: palettes.lua panes: %s" % proc.stderr)
    out = {}
    for line in proc.stdout.splitlines():
        x, y, z, n, p = line.split()
        out[(int(x), int(y), int(z))] = (n, int(p))
    return out


def main():
    lua = build_viewer.find_lua()
    house = T.parse_template(os.path.join(FIX, "templates", "fixture_house.tpl"))
    shed = T.parse_template(os.path.join(FIX, "templates", "fixture_shed.tpl"))

    # -- parsing ------------------------------------------------------------
    check(house.size == (9, 8, 9) and house.origin == (-1, 0, -1) and house.pivot == (7, 7),
          "house header")
    check(len(house.cells) == 9 * 8 * 9, "house: every cell read")
    check(house.cells[(3, 1, 0)] == "d" and house.cells[(3, 2, 0)] == "h", "house: the door")
    check(house.cells[(-1, 0, -1)] == T.UNCHANGED and house.cells[(2, 1, 2)] == T.FORCE_AIR,
          "house: leave unchanged and force air")
    check(house.legend["d"]["o"] == ("facedir", 0) and house.legend["d"]["variant"] == "_a",
          "house: legend attributes")
    check(house.legend["r"]["choices"] == {"elf": "f", "*": "k"}, "house: race switch")
    socket = house.points[4]
    check(socket["group"] == "sockets" and socket["face"] == 1 and
          dict(socket["attrs"]) == {"id": "{id}_keeper", "tags": ["door", "work"],
                                    "note": "by the door"}, "house: point attributes")
    check(shed.cell == 2 and shed.cells[(1, 1, 0)] == "Dr" and shed.cells[(1, 1, 1)] == T.FORCE_AIR,
          "shed: two-character cells")
    vale = T.parse_layout(os.path.join(FIX, "layouts", "fixture_vale.layout"))
    check([p["id"] for p in vale.places] == ["north_house", "south_house", "shed"] and
          vale.places[1]["channels"] == {"roof": "slate"} and vale.places[2]["turns"] == 1,
          "layout: placements in stamp order")
    keep = T.parse_layout(os.path.join(FIX, "layouts", "fixture_keep.roster"))
    check(keep.uses[0]["count"] == 3 and keep.uses[0]["main"] == "keep", "roster: use line")
    with tempfile.TemporaryDirectory() as tmp:
        broken = open(os.path.join(FIX, "templates", "fixture_shed.tpl")).read()
        cases = [
            (broken.replace("|WwDrWw|", "|WwDrW|"), "row is not"),
            (broken.replace("Li role light_indoor", "L role light_indoor"), "is not 2 character"),
            (broken.replace("|WwLiWw|", "|WwXxWw|"), "undefined key"),
            (broken.replace("doors 1 1 0 face=0", "doors 1 9 0 face=0"), "outside the box"),
            (broken.replace("grudgelands-building-template 1", "grudgelands-building-template 2"), "expected"),
        ]
        for text, reason in cases:
            path = os.path.join(tmp, "fixture_shed.tpl")
            with open(path, "w") as fh:
                fh.write(text)
            try:
                T.parse_template(path)
                check(False, "a broken template parses (%s)" % reason)
            except T.FormatError as e:
                check(reason in e.reason and e.line > 0, "error names '%s': %s" % (reason, e))

    # Layouts and rosters: the magic, the town and race lines, the entries.
    with tempfile.TemporaryDirectory() as tmp:
        roster = open(os.path.join(FIX, "layouts", "fixture_keep.roster")).read()
        layout = open(os.path.join(FIX, "layouts", "fixture_vale.layout")).read()
        cases = [
            ("fixture_keep.roster", roster.replace("grudgelands-town-roster 1\n", ""), "expected"),
            ("fixture_keep.roster", roster.replace("grudgelands-town-roster 1", "grudgelands-town-layout 1"),
             "expected 'grudgelands-town-roster 1'"),
            ("fixture_keep.roster", roster.replace("race human\n", ""), "without a race line"),
            ("fixture_keep.roster", roster.replace("town fixture_keep\n", ""), "without a town line"),
            ("fixture_keep.roster", roster + "place a template=fixture_shed x=0 y=0 z=0 turns=0\n",
             "not 'place'"),
            ("fixture_vale.layout", layout + "use fixture_shed count=2\n", "not 'use'"),
            ("fixture_vale.layout", layout.replace("grudgelands-town-layout 1", "grudgelands-town-roster 1"),
             "expected 'grudgelands-town-layout 1'"),
        ]
        for name, text, reason in cases:
            path = os.path.join(tmp, name)
            with open(path, "w") as fh:
                fh.write(text)
            try:
                T.parse_layout(path)
                check(False, "a broken %s parses (%s)" % (name, reason))
            except T.FormatError as e:
                check(reason in e.reason and e.line > 0, "error names '%s': %s" % (reason, e))

    # Legend entries compare by their parsed form, not their spelling.
    with tempfile.TemporaryDirectory() as tmp:
        text = open(os.path.join(FIX, "templates", "fixture_house.tpl")).read()
        text = text.replace("d role door variant=_a o=facedir:0",
                            "d role door o=facedir:0 variant=_a\nD role door variant=_a o=facedir:0\n"
                            "e role door variant=_b o=facedir:0\nK role storage o=facedir:2\n"
                            "R race *=K elf=f")
        path = os.path.join(tmp, "fixture_house.tpl")
        with open(path, "w") as fh:
            fh.write(text)
        alt = T.parse_template(path)
        key = lambda k: T.entry_key(alt.legend[k], alt.legend)
        check(key("d") == key("D"), "attribute order is no difference")
        check(key("d") != key("e"), "another variant is a different entry")
        check(key("K") == key("k"), "another key for the same entry is equal")
        check(key("R") == key("r"), "a race switch over renamed keys is equal")
        check(T.entry_key(alt.legend["R"]) != T.entry_key(alt.legend["r"]),
              "without the legend, a switch compares its keys")

    # -- resolving ----------------------------------------------------------
    names = set()
    reg = json.load(open(build_viewer.NODES_JSON))
    names.update(reg["nodes"])
    first = build_gallery.load_palettes(lua, ["air"])
    for roles in first["races"].values():
        names.update(roles.values())
        for fam, suffixes in first["families"].items():
            if roles.get(fam):
                names.update(roles[fam] + s for s in suffixes)
    names.update(["grug_decor:darkage_slate_tile_slab", "grug_decor:darkage_slate_tile_stair"])
    pal = T.Palettes(build_gallery.load_palettes(lua, names))

    dwarf = {"main": pal.bind("dwarf")}
    r = T.resolve(house, pal, dwarf)
    check(r["d"] == ("doors:door_wood_a", 0), "door family member: %s" % (r["d"],))
    check(r["t"] == ("beds:bed_top", 0), "bed family member")
    check(r["T"] == ("default:torch_wall", 4), "fixed node keeps its orientation")
    check(r["W"] == (pal.races["dwarf"]["wall"], 0), "role of kind none writes 0")
    check(r["r"] == r["k"], "race switch falls to *")
    elf = T.resolve(house, pal, {"main": pal.bind("elf")})
    check(elf["r"] == elf["f"] and elf["f"][0] == pal.races["elf"]["flower"], "race switch picks elf")
    if pal.races["dwarf"].get("flower") is None:
        check(r["f"] == T.FORCE_AIR, "unbound optional role takes else=air")
    slate = {"main": pal.bind("dwarf"),
             "roof": pal.bind("dwarf", {"roof_stair": "grug_decor:darkage_slate_tile_stair"})}
    rs = T.resolve(house, pal, slate)
    check(rs["2"] == ("grug_decor:darkage_slate_tile_stair", 2) and rs["W"] == r["W"],
          "the roof channel resolves through its own palette")
    # Orientation rules on a scratch legend.
    scratch = T.Template("scratch.tpl")
    scratch.legend = {
        "a": {"kind": "node", "name": "default:torch_wall", "o": ("facedir", 1)},
        "b": {"kind": "node", "name": "default:dry_shrub"},
        "c": {"kind": "node", "name": "default:wood", "o": ("facedir", 2)},
        "e": {"kind": "node", "name": "xpanes:pane_flat", "o": ("facedir", 1)},
        "g": {"kind": "role", "name": "door"},
    }
    scratch.legend_order = list(scratch.legend)
    rr = T.resolve(scratch, pal, dwarf)
    check(isinstance(rr["a"], str) and "wallmounted" in rr["a"], "kind mismatch is an error")
    check(rr["b"] == ("default:dry_shrub", 4), "meshoptions keeps its pinned value")
    check(rr["c"] == ("default:wood", 0), "a node of kind none writes 0 whatever is stored")
    check(rr["e"] == ("xpanes:pane_flat", 3), "a flat pane's param2 is canonical")
    check(isinstance(rr["g"], str) and "variant" in rr["g"], "a family needs its variant")

    # An unknown race in a layout names the file and the line.
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "fixture_vale.layout")
        text = open(os.path.join(FIX, "layouts", "fixture_vale.layout")).read()
        with open(path, "w") as fh:
            fh.write(text.replace("palette slate race=dwarf", "palette slate race=gnome"))
        lay = T.parse_layout(path)
        try:
            build_gallery.placement_binding(pal, lay, lay.places[1])
            check(False, "an unknown palette race binds")
        except T.FormatError as e:
            check(e.path == path and e.line == lay.palette_lines["slate"] and "gnome" in e.reason,
                  "unknown race names file and line: %s" % e)

    # -- the pane port against parts.resolve_panes --------------------------
    for tpl in (house, shed):
        for race in sorted(pal.races):
            binding = {"main": pal.bind(race)}
            resolution = T.resolve(tpl, pal, binding)
            raw = {}
            for pos, key in tpl.cells.items():
                if key == T.UNCHANGED:
                    continue
                v = ("air", 0) if key == T.FORCE_AIR else resolution[key]
                if isinstance(v, tuple):
                    raw[pos] = v
            py = dict(raw)
            T.resolve_panes(py, pal)
            check(py == lua_panes(lua, raw), "%s/%s: pane port equals parts.resolve_panes" % (tpl.name, race))
    rng = random.Random(56)
    pool = [("xpanes:pane_flat", 0), ("xpanes:pane_flat", 3), ("xpanes:bar_flat", 0),
            ("xpanes:bar_flat", 3), ("xpanes:pane", 0), ("xpanes:obsidian_pane_flat", 0),
            ("default:wood", 0), ("default:stonebrick", 0), ("default:dirt", 0),
            ("default:glass", 0), ("air", 0)]
    raw = {}
    for y in range(2000):
        for x in range(5):
            for z in range(5):
                if rng.random() < 0.8:
                    raw[(x, y, z)] = rng.choice(pool)
    py = dict(raw)
    count = T.resolve_panes(py, pal)
    check(count > 10000, "the random grid has panes")
    check(py == lua_panes(lua, raw), "random grid: pane port equals parts.resolve_panes")
    shapes = {(n, p) for n, p in py.values() if "pane" in n or "bar" in n}
    check(("xpanes:pane", 0) in shapes and ("xpanes:pane_flat", 1) in shapes and
          ("xpanes:pane_flat", 3) in shapes, "every branch is reached")

    print("test_templates: %d checks passed" % CHECKS[0])


if __name__ == "__main__":
    main()
