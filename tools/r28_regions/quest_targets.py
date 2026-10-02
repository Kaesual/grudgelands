#!/usr/bin/env python3
"""Round 28 Lane W1: kill quests against the spawn regions of every seed.

A legacy kill objective names mobs (and a zone, else the quest file's
zone). In a zone with a spawn recipe only the recipe's roles appear on the
surface, and a kind spawns only where it forms a region, which depends on
the seed. This check reads every quest file, the shipped recipes and the
rendered region stats of each seed (docs/planning/round28/regions/<short>/
seed_<s>.md, tools/r28_regions/run.sh) and sorts every kill objective
without an area:

  ok              a target role stands on every seed: a leader of the zone,
                  a camp with a region, or a kind with a region whose day or
                  night roster holds it (that clock is noted when only one);
  ACCEPTED        no target is in the recipe at all (no kind, camp or
                  leader): the game logs it as W-recipe-target at load; the
                  targets live elsewhere or the quest is legacy filler;
  MISSING         a target is in the recipe, but on some seed none of its
                  kinds or camps forms a region: the quest has no targets on
                  that seed. Exit status 1.

A stats file whose kinds and camps differ from the recipe's is stale (re-run
tools/r28_regions/run.sh): exit status 2.

Usage: quest_targets.py [--seeds "42 7 2026"] [--root DIR] [--verbose]
"""
import argparse
import glob
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPAWNS = REPO / "mods/ENTITIES/grug_mobs/data/zones"
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
ROOT = REPO / "docs/planning/round28/regions"
# Guards stand at their guard posts, never in a recipe's regions (the
# game's V.LEGACY_GUARDS / validate.py LEGACY_GUARD_TARGETS).
GUARD = re.compile(r"^guard_")


def short_name(zone):
    """tools/r28_regions/run.sh short_name."""
    rest = zone.split("_", 1)[1]
    first = rest.split("_", 1)[0]
    return rest if len(first) <= 3 else first


def bare(name):
    return name.split(":", 1)[1] if name.startswith("grug_mobs:") else name


def recipe_units(recipe):
    """{unit id: {"day": set, "night": set}} for kinds and camps, and the
    set of leader roles."""
    units = {}
    for belt in recipe.get("belts") or []:
        kinds = belt.get("kinds") or {}
        open_kind = kinds.get("open") or {}
        for _, kind in kinds.items():
            clocks = {}
            for clock in ("day", "night"):
                roster = kind.get(clock)
                if roster == "open":
                    roster = open_kind.get(clock)
                clocks[clock] = {row["role"] for row in roster or []}
            units[kind["id"]] = clocks
    for camp in recipe.get("camps") or []:
        roles = {row["role"] for row in camp.get("roster") or []}
        units[camp["id"]] = {"day": roles, "night": set(roles)}
    leaders = {row["role"] for row in recipe.get("leaders") or []}
    return units, leaders


ROW = re.compile(r"^\| [^|]*\(`([a-z0-9_]+)`\) \|")


def stats_regions(path):
    """{unit id: region count} from a region stats file (kinds and camps)."""
    out = {}
    for line in Path(path).read_text().splitlines():
        m = ROW.match(line)
        if m:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            out[m.group(1)] = int(cells[5])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--seeds", default="42 7 2026")
    ap.add_argument("--root", default=str(ROOT))
    ap.add_argument("--verbose", action="store_true", help="also list the objectives that are ok")
    args = ap.parse_args()
    seeds = args.seeds.split()

    recipes, stats, stale = {}, {}, []
    for path in sorted(SPAWNS.glob("*.spawns.json")):
        data = json.loads(path.read_text())
        if not data.get("recipe"):
            continue
        zone = data["zone"]
        recipes[zone] = recipe_units(data["recipe"])
        for seed in seeds:
            sp = Path(args.root) / short_name(zone) / ("seed_%s.md" % seed)
            if not sp.exists():
                stale.append("%s seed %s: no stats file %s" % (zone, seed, sp))
                continue
            counts = stats_regions(sp)
            if set(counts) != set(recipes[zone][0]):
                stale.append("%s seed %s: stats kinds %s differ from the recipe's %s" % (
                    zone, seed, sorted(set(counts) ^ set(recipes[zone][0])), sp))
            stats[(zone, seed)] = counts
    if stale:
        print("STALE region stats (re-run tools/r28_regions/run.sh):")
        for s in stale:
            print("  " + s)
        return 2

    ok, accepted, missing = [], [], []
    for qpath in sorted(QUESTS.glob("*.json")):
        data = json.loads(qpath.read_text())
        file_zone = qpath.name.split(".", 1)[0]
        for quest in data.get("quests", data) if isinstance(data, dict) else data:
            for n, obj in enumerate(quest.get("objectives") or [], 1):
                if obj.get("type") != "kill" or obj.get("area"):
                    continue
                zone = obj.get("zone") if isinstance(obj.get("zone"), str) else file_zone
                if zone not in recipes:
                    continue
                roles = {bare(m) for m in obj.get("mobs") or []}
                where = "%s obj %d (%s in %s)" % (quest["id"], n, ", ".join(sorted(roles)), zone)
                if any(GUARD.match(r) for r in roles):
                    continue
                units, leaders = recipes[zone]
                if roles & leaders:
                    ok.append(where + ": a leader")
                    continue
                holding = {u: c for u, c in units.items() if roles & (c["day"] | c["night"])}
                if not holding:
                    accepted.append(where)
                    continue
                gaps, clocks_seen = [], set()
                for seed in seeds:
                    counts = stats[(zone, seed)]
                    present = set()
                    for u, c in holding.items():
                        if counts.get(u, 0) > 0:
                            for clock in ("day", "night"):
                                if roles & c[clock]:
                                    present.add(clock)
                    if not present:
                        gaps.append(seed)
                    clocks_seen |= present
                if gaps:
                    missing.append("%s: no region on seed %s (kinds/camps %s)" % (
                        where, ", ".join(gaps), ", ".join(sorted(holding))))
                else:
                    note = "" if clocks_seen == {"day", "night"} else " (%s only)" % "/".join(sorted(clocks_seen))
                    ok.append(where + note)

    print("Legacy kill objectives against the spawn regions of seeds %s" % ", ".join(seeds))
    print("  ok: %d, accepted (recipe never spawns a target): %d, MISSING on some seed: %d" % (
        len(ok), len(accepted), len(missing)))
    if missing:
        print("MISSING (a target is in the recipe but forms no region on that seed):")
        for m in missing:
            print("  " + m)
    print("Accepted, always absent (W-recipe-target; the targets are not in the zone's recipe):")
    for a in accepted:
        print("  " + a)
    if args.verbose:
        print("ok:")
        for o in ok:
            print("  " + o)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
