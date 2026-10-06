#!/usr/bin/env python3
"""Round 38 lane I: the hard name rules (round38-mob-names-plan.md §2.2,
rules 1-4) over a name proposal.

    python3 tools/r38_names/check_rules.py <proposal.json ...>
    python3 tools/r38_names/check_rules.py --partial <zone files ...>
    python3 tools/r38_names/check_rules.py --world-pending <all zone files>
    python3 tools/r38_names/check_rules.py --today      # today's names as the proposal

A proposal is one JSON file per zone (plus `world.json` for the slots
without a zone), each

    {"zone": "<zone id or world>", "lane": "Z3",
     "slots": {"<slot key>": {"name": "Forest Piglet", "reason": "..."},
               "<slot key>": {"keep": true, "reason": "..."}}}

`keep: true` keeps today's name (a `name` given with it must equal it).
Slot keys and today's names are the inventory's (inventory.py, README.md
next to its outputs); `today/<zone>.json` there is today's names in this
format, a template to copy.

Checked (one line per problem, exit 1 on any):
  R1  words: normal mobs, critters and guards at most 2, named mobs, elites
      and bosses at most 3 (words split on spaces; a hyphenated word is one)
  R2  no signal word (tools/r28_names' list: Small, Large, Braindead ...)
  R3  "Piglet" only on the start pigs the `*_hunt_01` quests target
  R4  per name (case-insensitive, across every zone using it): its slots'
      level bands join without a gap, and all its slots lie in one drop
      tier. A zone slot whose own band spans two tiers counts as the tier
      holding most of its levels, the higher on a tie (coordinator's default
      ruling: a capital's L20-23 slot is T3, so it may share a name with
      L24+ slots, never with L19 or lower); a world/ slot keeps every tier
      its levels touch (pending the user). Exempt from the gap test (not
      from the tier test): the names in GAP_EXEMPT, see there
  R0  every slot named exactly once, no unknown slot key, no empty name or
      reason; with --partial only the zones the given files touch must be
      complete; with --world-pending every zone slot must be named and the
      world/ slots may be missing (they are named after the zones)
Notes (no exit status): a Piglet slot without "Piglet", and every slot whose
own level band spans several drop tiers (with the tier rule 4 counts it as).
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import inventory  # noqa: E402

PIGLET = re.compile(r"\bpiglets?\b", re.IGNORECASE)

# Names exempt from rule 4's gap test, with the one role every slot bearing
# the name must have for the exemption to hold (the tier test still
# applies). Coordinator's ruling, Round 38 lane C: the Rift Spawn is one
# story-fixed creature (docs/planning/round36/story-bible.md 1.5) whose ABM
# rows (spawn_policy.lua RECIPE_ZONE_ROWS) spawn it at the region level, the
# middle of each belt: L52, 56, 59 and 60, all in drop tier 6. Its slots are
# points with gaps between them; one name over them is one creature, not a
# stretch with a hole in it.
GAP_EXEMPT = {"rift spawn": "rift_spawn"}


def piglet_slots(model):
    """The slots the `*_hunt_01` kill objectives target (the start pigs)."""
    out = set()
    for o in model.objectives:
        if o["quest"].endswith("_hunt_01") and o["kind"] == "kill":
            out.update(o["targets"])
    return out


def load_proposals(paths):
    """(entries, problems): entries = key -> (name or None, keep, reason, file)."""
    entries, problems = {}, []
    for path in paths:
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
        except (OSError, ValueError) as err:
            problems.append("R0 %s: unreadable proposal (%s)" % (path, err))
            continue
        slots = data.get("slots") if isinstance(data, dict) else None
        if not isinstance(slots, dict):
            problems.append("R0 %s: no \"slots\" object" % path)
            continue
        for key, entry in slots.items():
            if key in entries:
                problems.append("R0 %s: named twice (%s and %s)" % (key, entries[key][3], path))
                continue
            if not isinstance(entry, dict):
                problems.append("R0 %s: entry must be an object (%s)" % (key, path))
                continue
            keep = entry.get("keep") is True
            name = entry.get("name")
            reason = entry.get("reason")
            entries[key] = (name, keep, reason, str(path))
    return entries, problems


def check(model, entries, partial=False, world_pending=False):
    """(problems, notes) for a proposal (key -> (name, keep, reason, file)).
    partial: only the zones the entries touch must be complete;
    world_pending: the world/ slots may be missing."""
    problems, notes = [], []
    signal = model.signal
    pigs = piglet_slots(model)
    names = {}
    for key, (name, keep, reason, path) in sorted(entries.items()):
        slot = model.slot_by_key.get(key)
        if slot is None:
            problems.append("R0 %s: unknown slot key (%s)" % (key, path))
            continue
        if keep:
            if name is not None and name != slot["name"]:
                problems.append("R0 %s: keep, but name %r is not today's %r" % (key, name, slot["name"]))
            name = slot["name"]
        if not isinstance(name, str) or not name.strip() or name != " ".join(name.split()):
            problems.append("R0 %s: name must be a non-empty string without extra spaces (%r)" % (key, name))
            continue
        if not isinstance(reason, str) or not reason.strip():
            problems.append("R0 %s: %r has no reason" % (key, name))
        names[key] = name
    covered = {model.slot_by_key[k]["zone"] or "world" for k in names}
    for slot in model.slots:
        if slot["key"] in entries:
            continue
        if world_pending and slot["zone"] is None:
            continue
        if not partial or (slot["zone"] or "world") in covered:
            problems.append("R0 %s: not named (today %r)" % (slot["key"], slot["name"]))
    by_name = defaultdict(list)
    for key, name in sorted(names.items()):
        slot = model.slot_by_key[key]
        limit = inventory.TIER_WORDS[slot["tier"]]
        n = len(inventory.words(name))
        if n > limit:
            problems.append("R1 %s: %r has %d words, %s at most %d" % (key, name, n, slot["tier"], limit))
        sig = [t for t in inventory.tokens(name) if t.lower() in signal]
        if sig:
            problems.append("R2 %s: %r has the signal word%s %s" % (key, name, "s" if len(sig) > 1 else "",
                                                                     ", ".join(sig)))
        if PIGLET.search(name) and key not in pigs:
            problems.append("R3 %s: %r - Piglet is reserved for the start pigs of the *_hunt_01 quests" % (key, name))
        if key in pigs and not PIGLET.search(name):
            notes.append("note R3 %s: a start pig of a *_hunt_01 quest without \"Piglet\" (%r)" % (key, name))
        by_name[name.lower()].append(slot)
    for lname, slots in sorted(by_name.items()):
        bands = sorted({tuple(s["levels"]) for s in slots})
        shown = names[slots[0]["key"]]
        for s in slots:
            own = inventory.tiers_of(*s["levels"])
            if len(own) > 1:
                notes.append("note R4 %s: %r - the band L%d-%d spans drop tiers %s on its own%s" % (
                    s["key"], shown, s["levels"][0], s["levels"][1], ",".join("T%d" % t for t in own),
                    "" if s["zone"] is None else " (counts as T%d)" % effective_tier(s)))
        if len(bands) < 2:
            continue
        exempt = GAP_EXEMPT.get(lname)
        gap_test = not (exempt and all(s["role"] == exempt for s in slots))
        reach = bands[0][1]
        for lo, hi in bands[1:]:
            if gap_test and lo > reach + 1:
                problems.append("R4 %r: level gap L%d-L%d between its bands (%s)" % (
                    shown, reach + 1, lo - 1, band_list(bands, slots)))
            reach = max(reach, hi)
        tiers = sorted({t for s in slots for t in slot_tiers(s)})
        if len(tiers) > 1:
            problems.append("R4 %r: its bands span drop tiers %s (%s)" % (
                shown, ",".join("T%d" % t for t in tiers), band_list(bands, slots)))
    return problems, notes


def effective_tier(slot):
    """The drop tier rule 4 counts a slot as (the coordinator's default
    ruling, Round 38; the user may overrule it): the tier that holds most of
    the slot's levels, the higher one on a tie. A capital's L20-23 slot
    (one level T2, three T3) counts as T3."""
    levels = defaultdict(int)
    for level in range(slot["levels"][0], slot["levels"][1] + 1):
        levels[inventory.drop_tier(level)] += 1
    return max(levels, key=lambda t: (levels[t], t))


def slot_tiers(slot):
    """The tiers rule 4 sees for a slot: its effective tier; a world/ slot
    (no zone: underground casts, guards, unplaced sub-types) keeps every
    tier its levels touch, pending the user's ruling."""
    if slot["zone"] is None:
        return inventory.tiers_of(*slot["levels"])
    return [effective_tier(slot)]


def band_list(bands, slots):
    parts = []
    for b in bands:
        keys = sorted(s["key"] for s in slots if tuple(s["levels"]) == b)
        parts.append("L%d-%d: %s" % (b[0], b[1], keys[0] + (" +%d" % (len(keys) - 1) if len(keys) > 1 else "")))
    return "; ".join(parts)


def today_entries(model):
    return {s["key"]: (s["name"], True, "today's name", "today") for s in model.slots}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Round 38 hard name rules over a proposal.")
    ap.add_argument("files", nargs="*", help="proposal JSON files")
    ap.add_argument("--partial", action="store_true",
                    help="only the zones the given files touch must be complete")
    ap.add_argument("--world-pending", action="store_true",
                    help="every zone slot must be named; the world/ slots may be missing")
    ap.add_argument("--today", action="store_true", help="check today's names as a proposal")
    ap.add_argument("--repo", default=str(inventory.REPO))
    ap.add_argument("--quiet-notes", action="store_true", help="print problems only")
    args = ap.parse_args(argv)
    if not args.files and not args.today:
        ap.error("give proposal files or --today")
    model = inventory.build(args.repo, surfaces=False)
    if args.today:
        entries, load_problems = today_entries(model), []
    else:
        entries, load_problems = load_proposals(args.files)
    problems, notes = check(model, entries, partial=args.partial, world_pending=args.world_pending)
    problems = load_problems + problems
    for line in problems:
        print(line)
    if not args.quiet_notes:
        for line in notes:
            print(line)
    print("%d problem%s, %d note%s over %d named slot%s" % (
        len(problems), "" if len(problems) == 1 else "s", len(notes), "" if len(notes) == 1 else "s",
        len(entries), "" if len(entries) == 1 else "s"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
