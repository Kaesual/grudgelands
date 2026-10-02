#!/usr/bin/env python3
"""Quest targets against the spawn regions of every seed (Round 28 Lane W1,
new quest format: Round 29 Lane T).

A quest's targets spawn only where its zone's recipe forms them, which
depends on the seed. This check reads every quest file, the shipped recipes
and the rendered region stats of each seed (docs/planning/round28/regions/
<short>/seed_<s>.md, tools/r28_regions/run.sh) and checks every target of
the Round 28 quest format on every seed:

  * a kill objective, an item objective naming its source `roles`, and a
    quest drop: with an `area` (`<zone>/<kind|camp>`, a bare id is the
    file's zone) that kind or camp forms a region; without one, every role
    is a leader that is placed, or stands in a kind or camp of the file's
    zone that forms a region;
  * every placeholder target of the title and text ({name:T},
    {dir_from_giver:T}, {dir_of:P:T}, {zone_area:T}): the kind or camp
    forms a region, the leader (any zone) is placed; else the text reads
    "in <zone>" without a direction on that seed.

The clock a target is met at comes from the kind's or camp's day and night
rosters; an objective met at one clock only is noted with it (--verbose),
and a quest whose text names the other clock only ("after dark" for a day
role) is listed under CLOCK. A target that is missing on some seed is
MISSING: exit status 1.

Legacy kill objectives (entity `mobs`, optional `zone` filter, Round 28's
split older quests) are sorted as before: ok, ACCEPTED when the recipe never
spawns a target (the game's W-recipe-target), MISSING. The legacy path is
the block marked LEGACY below; once no quest file ships a `mobs` objective
(the report says so), delete that block and the lines that call it.

A stats file whose kinds and camps differ from the recipe's is stale (re-run
tools/r28_regions/run.sh): exit status 2.

Usage: quest_targets.py [--seeds "42 7 2026"] [--root DIR] [--quests DIR]
                        [--spawns DIR] [--verbose]
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPAWNS = REPO / "mods/ENTITIES/grug_mobs/data/zones"
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
ROOT = REPO / "docs/planning/round28/regions"
CLOCKS = ("day", "night")


def short_name(zone):
    """tools/r28_regions/run.sh short_name."""
    rest = zone.split("_", 1)[1]
    first = rest.split("_", 1)[0]
    return rest if len(first) <= 3 else first


def recipe_units(recipe):
    """{unit id: {"day": set, "night": set}} for kinds and camps, and the
    set of leader roles."""
    units = {}
    for belt in recipe.get("belts") or []:
        kinds = belt.get("kinds") or {}
        open_kind = kinds.get("open") or {}
        for _, kind in kinds.items():
            clocks = {}
            for clock in CLOCKS:
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
LEADER = re.compile(r"^- Leader .*\(`([a-z0-9_]+)`\) at \(")


def read_stats(path):
    """({unit id: region count}, {placed leader role}) from a region stats
    file."""
    counts, leaders = {}, set()
    for line in Path(path).read_text().splitlines():
        m = ROW.match(line)
        if m:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            counts[m.group(1)] = int(cells[5])
        m = LEADER.match(line)
        if m:
            leaders.add(m.group(1))
    return counts, leaders


# Placeholders of a title or text (grug_quests/labels.lua): the last
# argument is the target, a bare id of the file's zone, `zone_id/id`, or a
# leader role of any zone.
PLACEHOLDER = re.compile(r"\{(name|dir_from_giver|zone_area|dir_of):([a-z0-9_:/]+)\}")
# The clock a quest text names (only when it names one clock).
CLOCK_WORDS = {
    "night": re.compile(r"\b(night|nights|nightly|after dark|dark hours|moonlight|nocturnal)\b", re.I),
    "day": re.compile(r"\b(by day|daylight|daytime|in the day|during the day|by daylight|sunlit hours)\b", re.I),
}


class World:
    def __init__(self, spawns, root, seeds):
        self.seeds = seeds
        self.recipes, self.stats, self.stale = {}, {}, []
        self.leader_zone = {}
        for path in sorted(Path(spawns).glob("*.spawns.json")):
            data = json.loads(path.read_text())
            if not data.get("recipe"):
                continue
            zone = data["zone"]
            self.recipes[zone] = recipe_units(data["recipe"])
            for role in self.recipes[zone][1]:
                self.leader_zone[role] = zone
            for seed in seeds:
                sp = Path(root) / short_name(zone) / ("seed_%s.md" % seed)
                if not sp.exists():
                    self.stale.append("%s seed %s: no stats file %s" % (zone, seed, sp))
                    continue
                counts, placed = read_stats(sp)
                if set(counts) != set(self.recipes[zone][0]):
                    self.stale.append("%s seed %s: stats kinds %s differ from the recipe's %s" % (
                        zone, seed, sorted(set(counts) ^ set(self.recipes[zone][0])), sp))
                self.stats[(zone, seed)] = (counts, placed)

    def formed(self, zone, unit, seed):
        return self.stats[(zone, seed)][0].get(unit, 0) > 0

    def placed(self, role, seed):
        return role in self.stats[(self.leader_zone[role], seed)][1]

    def unit_target(self, zone, unit, roles):
        """(gaps, clocks, problem) for `roles` in one kind or camp: the seeds
        it forms no region on, the clocks the roles are met at there."""
        units = self.recipes.get(zone, ({}, set()))[0]
        if unit not in units:
            return [], set(), "%s is no kind or camp of %s's recipe" % (unit, zone)
        clocks = {c for c in CLOCKS if not roles or roles & units[unit][c]}
        gaps = [s for s in self.seeds if not self.formed(zone, unit, s)]
        return gaps, clocks, None

    def role_target(self, zone, role):
        """(gaps, clocks, problem) for one role without an area: a placed
        leader, else the kinds and camps of `zone` that host it."""
        if role in self.leader_zone:
            return [s for s in self.seeds if not self.placed(role, s)], set(CLOCKS), None
        units = self.recipes.get(zone, ({}, set()))[0]
        holding = {u: c for u, c in units.items() if role in c["day"] | c["night"]}
        if not holding:
            return [], set(), "%s is no leader and not in %s's recipe (name its area)" % (role, zone)
        gaps, clocks = [], set()
        for seed in self.seeds:
            present = {c for u, cl in holding.items() if self.formed(zone, u, seed) for c in CLOCKS if role in cl[c]}
            if not present:
                gaps.append(seed)
            clocks |= present
        return gaps, clocks, None

    def placeholder_target(self, zone, ref):
        """(gaps, problem) for a placeholder target."""
        qualified, _, rest = ref.rpartition("/")
        if rest in self.leader_zone and (not qualified or qualified == self.leader_zone[rest]):
            return [s for s in self.seeds if not self.placed(rest, s)], None
        gaps, _, problem = self.unit_target(qualified or zone, rest, set())
        return gaps, problem


def area_ref(area, zone):
    """`zone/id` of an objective's area (a bare id is the file's zone)."""
    return area.split("/", 1) if "/" in area else (zone, area)


def text_clock(quest):
    text = "%s %s" % (quest.get("title") or "", quest.get("text") or "")
    named = {c for c, rx in CLOCK_WORDS.items() if rx.search(text)}
    return named.pop() if len(named) == 1 else None


# LEGACY: Round 28's split older quests (entity `mobs`, optional `zone`
# filter). Delete this block, its call in main() and the "accepted" lines
# once the report shows no legacy objective.
GUARD = re.compile(r"^guard_")  # guards stand at their posts, never in a region


def legacy_kill(world, obj, file_zone, where, out):
    zone = obj.get("zone") if isinstance(obj.get("zone"), str) else file_zone
    if zone not in world.recipes:
        return
    roles = {m.split(":", 1)[1] if m.startswith("grug_mobs:") else m for m in obj.get("mobs") or []}
    where = "%s (%s in %s)" % (where, ", ".join(sorted(roles)), zone)
    if any(GUARD.match(r) for r in roles):
        return
    units, leaders = world.recipes[zone]
    if roles & leaders:
        out["ok"].append(where + ": a leader")
        return
    holding = {u: c for u, c in units.items() if roles & (c["day"] | c["night"])}
    if not holding:
        out["accepted"].append(where)
        return
    gaps = [s for s in world.seeds
            if not any(world.formed(zone, u, s) for u in holding)]
    if gaps:
        out["missing"].append("%s: no region on seed %s (kinds/camps %s)" % (
            where, ", ".join(gaps), ", ".join(sorted(holding))))
    else:
        out["ok"].append(where)
# END LEGACY


def check_quest(world, quest, file_zone, new, legacy):
    qid = quest.get("id", "?")
    clocks_met = set()
    sources = []
    for n, obj in enumerate(quest.get("objectives") or [], 1):
        if obj.get("mobs") is not None:
            if obj.get("type") == "kill" and not obj.get("area"):
                legacy["seen"] += 1
                legacy_kill(world, obj, file_zone, "%s obj %d" % (qid, n), legacy)
            continue
        if obj.get("type") in ("kill", "item") and obj.get("roles"):
            sources.append(("obj %d" % n, obj))
    for n, drop in enumerate(quest.get("quest_drops") or [], 1):
        if drop.get("roles"):
            sources.append(("quest drop %d" % n, drop))
    for label, row in sources:
        roles = set(row["roles"])
        where = "%s %s (%s)" % (qid, label, ", ".join(sorted(roles)))
        if row.get("area"):
            zone, unit = area_ref(row["area"], file_zone)
            where += " in %s/%s" % (zone, unit)
            parts = [world.unit_target(zone, unit, roles)]
        else:
            parts = [world.role_target(file_zone, role) for role in sorted(roles)]
        gaps = sorted({s for g, _, _ in parts for s in g}, key=world.seeds.index)
        problems = [p for _, _, p in parts if p]
        clocks = set(CLOCKS)
        for _, c, p in parts:
            if not p:
                clocks &= c
        if problems:
            new["missing"].append("%s: %s" % (where, "; ".join(problems)))
        elif gaps:
            new["missing"].append("%s: no region or leader spot on seed %s" % (where, ", ".join(gaps)))
        else:
            clocks_met |= clocks
            note = "" if clocks == set(CLOCKS) else " (%s only)" % "/".join(sorted(clocks))
            new["ok"].append(where + note)
    for key in ("title", "text"):
        for kind, args in PLACEHOLDER.findall(quest.get(key) or ""):
            ref = args.split(":")[-1]
            where = "%s %s {%s:%s}" % (qid, key, kind, args)
            gaps, problem = world.placeholder_target(file_zone, ref)
            if problem:
                new["missing"].append("%s: %s" % (where, problem))
            elif gaps:
                new["missing"].append("%s: no region or leader spot on seed %s (no direction there)" % (
                    where, ", ".join(gaps)))
            else:
                new["ok"].append(where)
    said = text_clock(quest)
    if said and clocks_met and said not in clocks_met:
        new["clock"].append("%s: the text names the %s, its targets are met at %s only" % (
            qid, said, "/".join(sorted(clocks_met))))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--seeds", default="42 7 2026")
    ap.add_argument("--root", default=str(ROOT), help="region stats (tools/r28_regions/run.sh --out)")
    ap.add_argument("--quests", default=str(QUESTS), help="quest files (default: the game's)")
    ap.add_argument("--spawns", default=str(SPAWNS), help="spawn recipes (default: the game's)")
    ap.add_argument("--verbose", action="store_true", help="also list the targets that are ok")
    args = ap.parse_args()
    seeds = args.seeds.split()

    world = World(args.spawns, args.root, seeds)
    if world.stale:
        print("STALE region stats (re-run tools/r28_regions/run.sh):")
        for s in world.stale:
            print("  " + s)
        return 2

    new = {"ok": [], "missing": [], "clock": []}
    legacy = {"ok": [], "accepted": [], "missing": [], "seen": 0}
    for qpath in sorted(Path(args.quests).glob("*.json")):
        data = json.loads(qpath.read_text())
        file_zone = qpath.name.split(".", 1)[0]
        for quest in data.get("quests") or []:
            check_quest(world, quest, file_zone, new, legacy)

    missing = new["missing"] + legacy["missing"]
    print("Quest targets against the spawn regions of seeds %s" % ", ".join(seeds))
    print("  targets: ok %d, MISSING on some seed %d, CLOCK %d" % (
        len(new["ok"]), len(new["missing"]), len(new["clock"])))
    if legacy["seen"]:
        print("  legacy kill objectives: ok %d, accepted (recipe never spawns a target) %d, MISSING %d" % (
            len(legacy["ok"]), len(legacy["accepted"]), len(legacy["missing"])))
    else:
        print("  no legacy kill objective left: delete the LEGACY block of quest_targets.py")
    if missing:
        print("MISSING (no region or leader spot on that seed, or no such target):")
        for m in missing:
            print("  " + m)
    if new["clock"]:
        print("CLOCK (the text names a clock its targets are not met at):")
        for c in new["clock"]:
            print("  " + c)
    if legacy["accepted"]:
        print("Accepted legacy objectives, always absent (W-recipe-target; the targets are not in the zone's recipe):")
        for a in legacy["accepted"]:
            print("  " + a)
    if args.verbose:
        print("ok:")
        for o in new["ok"] + legacy["ok"]:
            print("  " + o)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
