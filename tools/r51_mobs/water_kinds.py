#!/usr/bin/env python3
"""Round 51 lane MOBS, step M2: the water kinds of the zone spawn recipes.

    python3 tools/r51_mobs/water_kinds.py           # write the recipes
    python3 tools/r51_mobs/water_kinds.py --check   # exit 1 when stale

The water bands (grug_mobs/spawn_regions_core.lua M.WATER_TYPES) as kinds
of every belt of a zone that holds the family's water, from the accepted
NAMES draft (tools/r51_names/draft.json):

  sea_shallows  the tortoise, where the draft gives the zone sea shore (S10:
                near land only mobs that follow a player ashore)
  sea_deep      the stingray, where it gives the zone belt or channel water
                (a pure swimmer, away from land)
  lake          the frog (main, weight 3) and the tortoise (minor, weight 1)
                where it gives the zone lakes and rivers (S15: the tortoise
                at lakes, not rivers)
  river         the frog
The frog only in belts from its `from_level` (design.json: no frogs in the
L1-2 home belts). A belt's role of a family is the family's sub-type of the
belt's drop tier: the tier holding most of the belt's levels, the higher on
a tie (tools/r38_names/check_rules.py effective_tier), so an L18-20 belt
takes the T2 role and an L20-23 belt the T3 role. A family with no sub-type
for a belt's tier (the stingray in tier 5) gives that belt no kind.

Every belt of such a zone gets the kinds, not only the belts the draft's
survey saw the water beside: a water column takes the belt of its level
(spawn_regions_core.lua M.water_kind), which need not be the belt of the
land cells next to it. Every draft zone slot is therefore a slot of the
game; a slot the draft lacks bears the same name (one name per role).

The kinds are written into each recipe file's text after the belt's land
kinds, in the files' own layout; a rerun replaces them. Python 3 standard
library only.
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ZONES = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "zones"
SUBTYPES = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "subtypes.json"
DRAFT = REPO / "tools" / "r51_names" / "draft.json"
DESIGN = REPO / "tools" / "r51_names" / "design.json"
CATALOGUE = REPO / "docs" / "planning" / "round28" / "mobs" / "catalogue.json"

WATER_TYPES = ("sea_shallows", "sea_deep", "lake", "river")
LABELS = {"sea_shallows": "Shallows", "sea_deep": "Coastal Waters", "lake": "Lakes",
          "river": "Rivers"}
TIER_LEVELS = {1: [1, 10], 2: [11, 20], 3: [20, 30], 4: [31, 40], 5: [41, 50], 6: [51, 60]}
DENSITY = "sparse"


def drop_tier(level):
    return max(1, min(6, (level - 1) // 10 + 1))


def belt_tier(lo, hi):
    count = defaultdict(int)
    for level in range(lo, hi + 1):
        count[drop_tier(level)] += 1
    return max(count, key=lambda t: (count[t], t))


def family_roles():
    out = defaultdict(dict)
    for row in json.loads(SUBTYPES.read_text(encoding="utf-8")):
        if row["family"] in ("tortoise", "frog", "stingray"):
            out[row["family"]][tuple(row["levels"])] = row["role"]
    return out


def role_for(roles, family, levels):
    tier = TIER_LEVELS[belt_tier(*levels)]
    role = roles[family].get(tuple(tier))
    if role and tier[0] <= levels[0] and levels[1] <= tier[1]:
        return role
    return None


def zone_habitats():
    draft = json.loads(DRAFT.read_text(encoding="utf-8"))
    out = defaultdict(set)
    for slot in draft["slots"].values():
        for h in slot["habitats"]:
            out[(slot["zone"], slot["family"])].add(h)
    return out


def from_levels():
    design = json.loads(DESIGN.read_text(encoding="utf-8"))
    return {f["id"]: f.get("from_level", 1) for f in design["families"]}


def zone_names():
    meta = json.loads(CATALOGUE.read_text(encoding="utf-8"))["meta"]["zones"]
    return {zid: row["name"] for zid, row in meta.items()}


def kinds_of(zone, belt, roles, habitats, start):
    """{type: (day roster, night roster)} for one belt."""
    lv = belt["levels"]
    def role(family):
        if lv[1] < start.get(family, 1):
            return None
        return role_for(roles, family, lv)
    out = {}
    tortoise, frog, ray = role("tortoise"), role("frog"), role("stingray")
    h_t, h_f, h_s = habitats[(zone, "tortoise")], habitats[(zone, "frog")], habitats[(zone, "stingray")]
    if tortoise and "shore" in h_t:
        out["sea_shallows"] = [(tortoise, 1)]
    if ray and (h_s & {"belt", "channel"}):
        out["sea_deep"] = [(ray, 1)]
    lake = []
    if frog and "freshwater" in h_f:
        lake.append((frog, 3))
    if tortoise and "freshwater" in h_t:
        lake.append((tortoise, 1))
    if lake:
        out["lake"] = lake if len(lake) == 2 else [(lake[0][0], 1)]
    if frog and "freshwater" in h_f:
        out["river"] = [(frog, 1)]
    return out


def roster_text(roster):
    return "[" + ", ".join('{"role": "%s", "weight": %d}' % (r, w) for r, w in roster) + "]"


def kind_text(zone_name, belt_id, t, roster):
    return ('          "%s": {"id": "%s_%s", "name": "%s %s",\n'
            '            "day": %s,\n'
            '            "night": %s, "density": "%s"}') % (
        t, t, belt_id, zone_name, LABELS[t], roster_text(roster), roster_text(roster), DENSITY)


def matching_brace(text, start):
    """Index of the brace closing the one at `start` (strings skipped)."""
    depth, i, in_str = 0, start, False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("water_kinds: unbalanced braces")


WATER_ENTRY = re.compile(r',\n          "(?:%s)": \{.*?"density": "\w+"\}' % "|".join(WATER_TYPES), re.S)


def rewrite(path, roles, habitats, start, names):
    text = path.read_text(encoding="utf-8")
    text = WATER_ENTRY.sub("", text)  # a rerun replaces the old water kinds
    data = json.loads(text)
    zone = data["zone"]
    if "recipe" not in data:
        return text, 0
    added = 0
    pos = 0
    for belt in data["recipe"]["belts"]:
        at = text.index('"id": "%s"' % belt["id"], pos)
        k = text.index('"kinds": {', at) + len('"kinds": ')
        end = matching_brace(text, k)
        kinds = kinds_of(zone, belt, roles, habitats, start)
        entries = [kind_text(names[zone], belt["id"], t, kinds[t]) for t in WATER_TYPES if t in kinds]
        if entries:
            # the closing brace sits on its own line: insert before that line
            line_start = text.rindex("\n", 0, end)
            text = text[:line_start] + ",\n" + ",\n".join(entries) + text[line_start:]
            added += len(entries)
        pos = text.index('"kinds": {', at) + 1
    json.loads(text)  # still valid JSON
    return text, added


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 when a recipe is stale")
    args = ap.parse_args(argv)
    roles, habitats, start, names = family_roles(), zone_habitats(), from_levels(), zone_names()
    stale, total = [], 0
    for path in sorted(ZONES.glob("*.spawns.json")):
        new, added = rewrite(path, roles, habitats, start, names)
        total += added
        if new != path.read_text(encoding="utf-8"):
            stale.append(path.name)
            if not args.check:
                path.write_text(new, encoding="utf-8")
    if args.check:
        if stale:
            print("water_kinds: stale %s (rerun tools/r51_mobs/water_kinds.py)" % ", ".join(stale))
            return 1
        print("water_kinds: the recipes are current (%d water kinds)" % total)
        return 0
    print("water_kinds: %d water kinds, %d files written" % (total, len(stale)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
