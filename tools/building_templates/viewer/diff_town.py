#!/usr/bin/env python3
"""Diff a hand-rebuilt start town against its blueprint.

    python3 tools/building_templates/viewer/diff_town.py dawnmere \\
        --baseline world/town_exports/dawnmere-baseline.tsv \\
        --after world/town_exports/dawnmere-designer.tsv \\
        --json /tmp/dawnmere-diff.json

Both exports come from the dev-only ``grug_town_workshop`` world mod
(``/town_export``): ``baseline`` is written when the workshop world is
prepared, before anyone builds; ``after`` once the town has been reworked.
The tool

1. places the blueprint in the world: the anchor x/z is in the export, the
   height (and, for safety, the quarter turn) is the one under which the
   blueprint matches the baseline best;
2. diffs ``after`` against ``baseline`` cell by cell, so only hand-made
   changes show, not what mapgen fitted differently from the blueprint;
3. moves what the world does on its own (crops growing, doors opening,
   apples, covered grass; see ``classify``) into a separate ``noise`` list,
   with positions, instead of dropping it;
4. reports every change in blueprint-local coordinates with the building
   whose landmark box holds it.

Without ``--after`` it reports how far the baseline already differs from the
blueprint (mapgen fitting), which is also the check after porting: a world
built from the changed blueprint, exported as its own baseline, should match
the designer's ``after`` export.
"""

import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_viewer  # noqa: E402

NODES_JSON = build_viewer.NODES_JSON


def load_export(path):
    meta, cells = {}, {}
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if f[0].startswith("#"):
                meta[f[0][1:]] = f[1:]
            elif len(f) >= 5:
                cells[(int(f[0]), int(f[1]), int(f[2]))] = (f[3], int(f[4]))
    meta["anchor"] = [int(v) for v in meta["anchor"]]
    meta["window"] = [int(v) for v in meta["window"]]
    meta["surface"] = int(meta["surface"][0])
    return meta, cells


def turn(x, z, r):
    """Blueprint-local (x, z) turned by r quarter turns (0..3)."""
    for _ in range(r):
        x, z = z, -x
    return x, z


def untrun(x, z, r):
    return turn(x, z, (4 - r) % 4)


def place(blueprint_cells, export_meta, export_cells):
    """Best (dy, r): world = anchor + turn(local, r), world_y = local_y + dy."""
    ax, az = export_meta["anchor"]
    win = export_meta["window"]
    # Structure only: ground layers match at any height on flat ground.
    sample = [c for c in blueprint_cells if c[1] >= 1][::3]
    best = None
    for r in range(4):
        for dy in range(win[1] + 2, win[4] - 2):
            hits = 0
            for x, y, z, name, _ in sample:
                wx, wz = turn(x, z, r)
                got = export_cells.get((ax + wx, y + dy, az + wz))
                if got and got[0] == name:
                    hits += 1
            if best is None or hits > best[0]:
                best = (hits, dy, r)
    hits, dy, r = best
    return {"dy": dy, "turns": r, "score": hits / max(1, len(sample))}


# -- noise ----------------------------------------------------------------
# What the world changes on its own, so a hand edit never looks like it:
#   - a crop growing a stage (both names in group `plant`, same stem);
#   - a door opening or closing (_a <-> _c, _b <-> _d; _a <-> _b turns the
#     hinge and is an edit), a gate opening (_closed <-> _open);
#   - a furnace lighting (furnace <-> furnace_active);
#   - an apple picked or regrown on a tree (param2 0; one placed by hand has
#     param2 1), with `apple_mark`, the airlike regrowth marker, read as air;
#   - grass under a newly placed block turning to dirt ("Grass covered");
#     grass spread itself is switched off in towns (default/functions.lua),
#     so dirt -> grass is always a hand edit;
#   - flowing water and soil getting wet next to it.

GROWTH = re.compile(r"^(.*?)_(\d+)$")
DOOR_TOGGLE = re.compile(r"^(doors:.*?)_([abcd])$")
GATE = re.compile(r"^(doors:gate_.*?)_(open|closed)$")
TOGGLES = [{"default:furnace", "default:furnace_active"},
           {"grug_farming:soil", "grug_farming:soil_wet"}]
COVERED = {"default:dirt", "default:dry_dirt"}


def in_group(registry, name, group):
    return bool(((registry.get(name) or {}).get("groups") or {}).get(group))


def same_door(bn, an):
    mb, ma = DOOR_TOGGLE.match(bn), DOOR_TOGGLE.match(an)
    if mb and ma and mb.group(1) == ma.group(1):
        return {mb.group(2), ma.group(2)} in ({"a", "c"}, {"b", "d"})
    mb, ma = GATE.match(bn), GATE.match(an)
    return bool(mb and ma and mb.group(1) == ma.group(1))


def covered(registry, above):
    """The "Grass covered" ABM's test for the node above, after the edit."""
    if above is None or above[0] == "air":
        return False
    d = registry.get(above[0]) or {}
    return d.get("paramtype") != "light" or d.get("liquidtype", "none") != "none"


def classify(before, after, registry, above_after=None):
    """'added', 'removed', 'replaced', 'turned', 'noise' or None (equal)."""
    bn, bp = before if before else ("air", 0)
    an, ap = after if after else ("air", 0)
    if bn == "default:apple_mark":
        bn, bp = "air", 0
    if an == "default:apple_mark":
        an, ap = "air", 0
    if bn == an:
        if bp == ap:
            return None
        p2type = (registry.get(bn) or {}).get("paramtype2", "none")
        if p2type in ("none", "light", "flowingliquid", "leveled", "glasslikeliquidlevel",
                      "degrotate", "meshoptions", "color"):
            return None
        return "turned"
    gb, ga = GROWTH.match(bn), GROWTH.match(an)
    if (gb and ga and gb.group(1) == ga.group(1) and
            in_group(registry, bn, "plant") and in_group(registry, an, "plant")):
        return "noise"
    if same_door(bn, an) or {bn, an} in TOGGLES:
        return "noise"
    if "default:apple" in (bn, an) and "air" in (bn, an):
        if (bp if bn == "default:apple" else ap) == 0:
            return "noise"
    if an in COVERED and in_group(registry, bn, "spreading_dirt_type") and \
            covered(registry, above_after):
        return "noise"
    if bn.endswith("_flowing") or an.endswith("_flowing"):
        # Spreading water; a wall that gave way to it is still an edit.
        liquid = lambda n: n == "air" or (registry.get(n) or {}).get("liquidtype", "none") != "none"
        if liquid(bn) and liquid(an):
            return "noise"
    if bn == "air":
        return "added"
    if an == "air":
        return "removed"
    return "replaced"


# The bounds contract every start-town blueprint keeps (r7_*_blueprint.lua):
# local x/z [-63, 63], y [-2, 24]. A change outside it cannot be ported as is.
CONTRACT = (-63, -2, -63, 63, 24, 63)


# -- report ---------------------------------------------------------------

def building_of(boxes, x, y, z):
    best, vol = None, None
    for key, x1, y1, z1, x2, y2, z2 in boxes:
        if key in ("main_street", "gate_passage"):
            continue
        if x1 <= x <= x2 and y1 <= y <= y2 and z1 <= z <= z2:
            v = (x2 - x1 + 1) * (y2 - y1 + 1) * (z2 - z1 + 1)
            if vol is None or v < vol:
                best, vol = key, v
    return best or "open_ground"


def diff(town, baseline_path, after_path=None, lua=None):
    lua = lua or build_viewer.find_lua()
    path = os.path.join(build_viewer.BLUEPRINT_DIR, "r7_%s_blueprint.lua" % town)
    bounds, boxes, points, bp_cells = build_viewer.export(lua, path)
    with open(NODES_JSON, "r", encoding="utf-8") as fh:
        reg = json.load(fh)
    registry, aliases = reg["nodes"], reg.get("aliases", {})

    bmeta, bcells = load_export(baseline_path)
    placement = place(bp_cells, bmeta, bcells)
    ax, az = bmeta["anchor"]
    dy, r = placement["dy"], placement["turns"]

    def to_local(wx, wy, wz):
        lx, lz = untrun(wx - ax, wz - az, r)
        return lx, wy - dy, lz

    def to_world(lx, ly, lz):
        wx, wz = turn(lx, lz, r)
        return ax + wx, ly + dy, az + wz

    result = {"town": town, "placement": placement, "anchor": [ax, az],
              "bounds": bounds, "baseline": os.path.basename(baseline_path)}

    if after_path is None:
        # Baseline against the blueprint: what mapgen placed differently.
        counts = collections.Counter()
        for x, y, z, name, p2 in bp_cells:
            got = bcells.get(to_world(x, y, z))
            real = aliases.get(name, name)
            if got is None:
                counts["missing"] += 1
            elif got[0] != real:
                counts["different"] += 1
            else:
                counts["same"] += 1
        result["blueprint_vs_baseline"] = dict(counts)
        return result

    ameta, acells = load_export(after_path)
    if ameta["anchor"] != bmeta["anchor"]:
        sys.exit("baseline and after exports name different anchors")
    result["after"] = os.path.basename(after_path)
    win = [max(a, b) for a, b in zip(bmeta["window"][:3], ameta["window"][:3])] + \
          [min(a, b) for a, b in zip(bmeta["window"][3:], ameta["window"][3:])]
    inside = lambda pos: all(win[k] <= pos[k] <= win[k + 3] for k in range(3))
    if ameta["window"] != bmeta["window"]:
        result["window_warning"] = (
            "the exports cover different windows (%s vs %s); only their overlap was "
            "compared; %d nodes of the baseline and %d of the after export lie outside "
            "it" % (bmeta["window"], ameta["window"], sum(not inside(p) for p in bcells),
                    sum(not inside(p) for p in acells)))
    changes, noise, noise_list = [], collections.Counter(), []
    for pos in set(bcells) | set(acells):
        if not inside(pos):
            continue
        before, after = bcells.get(pos), acells.get(pos)
        above = acells.get((pos[0], pos[1] + 1, pos[2]))
        kind = classify(before, after, registry, above)
        if kind is None:
            continue
        lx, ly, lz = to_local(*pos)
        b4 = list(before) if before else ["air", 0]
        af = list(after) if after else ["air", 0]
        if kind == "noise":
            noise["%s -> %s" % (b4[0], af[0])] += 1
            noise_list.append({"x": lx, "y": ly, "z": lz, "before": b4, "after": af})
            continue
        changes.append({
            "x": lx, "y": ly, "z": lz, "kind": kind, "before": b4, "after": af,
            "building": building_of(boxes, lx, ly, lz),
            "inside_blueprint": all(CONTRACT[k] <= (lx, ly, lz)[k] <= CONTRACT[k + 3]
                                    for k in range(3)),
        })
    changes.sort(key=lambda c: (c["building"], c["y"], c["z"], c["x"]))
    result["changes"] = changes
    result["noise"] = dict(noise.most_common())
    result["noise_cells"] = sorted(noise_list, key=lambda c: (c["y"], c["z"], c["x"]))
    return result


def summary(result):
    out = []
    p = result["placement"]
    out.append("%s: blueprint placed at anchor %s, y offset %d, %d quarter turns "
               "(%.0f%% of sampled structure matches the baseline)" % (
                   result["town"], result["anchor"], p["dy"], p["turns"], 100 * p["score"]))
    if "changes" not in result:
        c = result["blueprint_vs_baseline"]
        out.append("blueprint vs baseline: %d same, %d different, %d missing" % (
            c.get("same", 0), c.get("different", 0), c.get("missing", 0)))
        return "\n".join(out)
    changes = result["changes"]
    if result.get("window_warning"):
        out.append("WARNING: " + result["window_warning"])
    out.append("%d changed nodes (%d outside the blueprint bounds), %d noise" % (
        len(changes), sum(not c["inside_blueprint"] for c in changes),
        sum(result["noise"].values())))
    by_building = collections.defaultdict(list)
    for c in changes:
        by_building[c["building"]].append(c)
    for building in sorted(by_building, key=lambda b: -len(by_building[b])):
        items = by_building[building]
        kinds = collections.Counter(c["kind"] for c in items)
        out.append("\n%s: %d (%s)" % (building, len(items),
                                     ", ".join("%s %d" % kv for kv in sorted(kinds.items()))))
        swaps = collections.Counter("%s -> %s" % (c["before"][0], c["after"][0]) for c in items)
        for swap, n in swaps.most_common(8):
            out.append("    %4d  %s" % (n, swap))
        if len(swaps) > 8:
            out.append("          ... %d more kinds of change" % (len(swaps) - 8))
    if result["noise"]:
        out.append("\nnoise (left out): " + ", ".join(
            "%s x%d" % kv for kv in list(result["noise"].items())[:8]))
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("town", help="start-town key, e.g. dawnmere")
    ap.add_argument("--baseline", required=True, help="export written before building")
    ap.add_argument("--after", help="export written after building")
    ap.add_argument("--json", help="write the full diff as JSON")
    args = ap.parse_args(argv)
    result = diff(args.town, args.baseline, args.after)
    print(summary(result))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
