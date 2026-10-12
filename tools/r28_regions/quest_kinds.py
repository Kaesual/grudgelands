#!/usr/bin/env python3
"""Set the `quest_target` flag of the spawn recipes' kinds (Round 46).

A kind that a quest's area or a title/text placeholder names
(quest_targets.quest_named_kinds) carries `"quest_target": true` in its
recipe row, so the region builder (grug_mobs/spawn_regions_core.lua, step 5)
gives it a region on every seed; no other kind carries it. This script
writes the flags into mods/ENTITIES/grug_mobs/data/zones/*.spawns.json by a
text edit of the kind's object (the files' hand layout stays), or with
--check only reports the kinds that differ (exit 1).

Usage: quest_kinds.py [--check] [--quests DIR] [--spawns DIR]
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import quest_targets as Q  # noqa: E402

FLAG = re.compile(r',\s*"quest_target":\s*true')


def object_end(text, start):
    """The index of the `}` closing the JSON object that opens at `start`."""
    depth, i, in_str = 0, start, False
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unclosed object at %d" % start)


def set_flags(path, zone_kinds, wanted):
    text = path.read_text()
    for kid in sorted(zone_kinds):
        hits = [m.start() for m in re.finditer(r'\{"id": "%s"' % re.escape(kid), text)]
        if len(hits) != 1:
            raise SystemExit("%s: kind %s found %d times" % (path, kid, len(hits)))
        start = hits[0]
        end = object_end(text, start)
        body = FLAG.sub("", text[start:end])
        if kid in wanted:
            body += ', "quest_target": true'
        text = text[:start] + body + text[end:]
    path.write_text(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--quests", default=str(Q.QUESTS))
    ap.add_argument("--spawns", default=str(Q.SPAWNS))
    args = ap.parse_args()
    named, flagged = Q.quest_named_kinds(args.quests, args.spawns)
    problems = Q.flag_problems(named, flagged)
    if args.check:
        for p in problems:
            print(p)
        print("quest_kinds: %d quest-named kinds, %d differ" % (
            sum(len(v) for v in named.values()), len(problems)))
        return 1 if problems else 0
    for path in sorted(Path(args.spawns).glob("*.spawns.json")):
        data = json.loads(path.read_text())
        recipe = data.get("recipe")
        if not recipe:
            continue
        zone = data["zone"]
        ids = {k["id"] for belt in recipe.get("belts") or [] for k in (belt.get("kinds") or {}).values()}
        set_flags(path, ids, named.get(zone, set()))
        json.loads(path.read_text())  # still valid JSON
    named, flagged = Q.quest_named_kinds(args.quests, args.spawns)
    left = Q.flag_problems(named, flagged)
    print("quest_kinds: %d quest-named kinds flagged, %d differ" % (
        sum(len(v) for v in named.values()), len(left)))
    return 1 if left else 0


if __name__ == "__main__":
    sys.exit(main())
