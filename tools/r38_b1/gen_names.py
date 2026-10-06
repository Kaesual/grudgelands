#!/usr/bin/env python3
"""Round 38 lane B1: write mods/ENTITIES/grug_mobs/data/names.json.

One name per slot key of tools/r38_names/inventory.py, the game's single
source of mob names (grug_mobs names.lua). Left out: the PvP garrison
individuals whose names live in data/pvp_names.json (captains per race,
war commanders, Generals); the game writes those at placement.

    python3 tools/r38_b1/gen_names.py                    # today's names
    python3 tools/r38_b1/gen_names.py --proposals DIR..  # picks over today's
    python3 tools/r38_b1/gen_names.py --check            # exit 1 when stale

`--proposals` takes lane I's proposal format (inventory README "Proposal
format": per zone {"slots": {key: {"name"} | {"keep": true}}}), files or
directories of them; a key no slot has is an error (KEY_MOVES maps keys a
later ruling moved). With `--check` it also proves that every slot shows
its proposal's name, the PvP captains, commanders and Generals included
(their names live in pvp_names.json). Python 3 standard
library only; deterministic output.
"""
import argparse
import re
import glob
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "r38_names"))
import inventory  # noqa: E402

OUT = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "names.json"
# The sub-type catalogue and its design copy: each sub-type's `display` (the
# fallback before its level is known) is its lowest slot's name, so no stale
# name stays in the data (Round 38 lane B2).
CATALOGUES = [REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "subtypes.json",
              REPO / "docs" / "planning" / "round28" / "design" / "catalog" / "subtypes.json"]
NOTES = ("Round 38: every mob name, one per slot key <scope>/<source>/L<lo>-<hi> "
         "(tools/r38_names/inventory.py). Written by tools/r38_b1/gen_names.py; the PvP "
         "captains, war commanders and Generals keep their names in pvp_names.json.")


def pvp_individual(slot):
    source = slot["key"].split("/")[1]
    return slot["source"] == "pvp_garrison" and (
        ".captain-" in source or source.endswith(".commander") or source.endswith(".general"))


# Slot keys a ruling moved after the proposals were written: the whelps are
# level 60 since the user's ruling of 2026-10-06 (plan §6 item 12).
KEY_MOVES = {
    "front_stormscale_summit/storm_whelp/L20-20": "front_stormscale_summit/storm_whelp/L60-60",
    "front_wyrmglass_crown/ice_whelp/L20-20": "front_wyrmglass_crown/ice_whelp/L60-60",
}


def proposal_files(paths):
    out = []
    for p in paths:
        if os.path.isdir(p):
            out += sorted(glob.glob(os.path.join(p, "**", "*.json"), recursive=True))
        else:
            out.append(p)
    return out


def build(proposals=()):
    model = inventory.build(REPO, surfaces=False)
    names = {s["key"]: s["name"] for s in model.slots if not pvp_individual(s)}
    errors = []
    for key, name in sorted(read_proposals(proposals, errors).items()):
        if key not in model.slot_by_key:
            errors.append("%s is no slot" % key)
        elif key in names and name is not None:
            names[key] = name
    return {"notes": NOTES, "names": dict(sorted(names.items()))}, errors


def read_proposals(proposals, errors):
    """{slot key: name (None: keep today's)} over the proposal files, with
    KEY_MOVES applied."""
    out = {}
    for path in proposal_files(proposals):
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        for key, row in (data.get("slots") or {}).items():
            key = KEY_MOVES.get(key, key)
            if key in out:
                errors.append("%s: %s is named twice" % (path, key))
            out[key] = None if row.get("keep") else row["name"]
    return out


def shown_differs(proposals):
    """Every slot whose shown name (the inventory over the shipped data:
    names.json, pvp_names.json for the captains, commanders and Generals)
    is not its proposal's name; [] when every name is as accepted."""
    errors = []
    wanted = read_proposals(proposals, errors)
    model = inventory.build(REPO, surfaces=False)
    for slot in model.slots:
        if slot["key"] in wanted and wanted[slot["key"]] is not None and wanted[slot["key"]] != slot["name"]:
            errors.append("%s shows %r, accepted %r" % (slot["key"], slot["name"], wanted[slot["key"]]))
    return errors


def displays(names):
    """{role: the name of its lowest slot (levels, then key)} over names."""
    best = {}
    for key, name in names.items():
        scope, source, band = key.split("/")
        lo, hi = (int(x) for x in band[1:].split("-"))
        row = (lo, hi, key, name)
        if source not in best or row < best[source]:
            best[source] = row
    return {source: row[3] for source, row in best.items()}


def synced_catalogue(text, wanted):
    """The catalogue text with every listed sub-type's display set to
    `wanted[role]` (only the display value changes)."""
    def fix(m):
        role, display = m.group(1), m.group(3)
        new = wanted.get(role, display)
        return m.group(0)[:m.start(3) - m.start(0)] + json.dumps(new, ensure_ascii=False)[1:-1] + \
            m.group(0)[m.end(3) - m.start(0):]
    return re.sub(r'"role": "(\w+)",(.*?)"display": "((?:[^"\\]|\\.)*)"', fix, text, flags=re.S)


def render(data):
    return json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--proposals", nargs="*", default=[])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args(argv)
    data, errors = build(args.proposals)
    for e in errors:
        print(e, file=sys.stderr)
    if errors:
        return 1
    text = render(data)
    wanted = displays(data["names"])
    catalogues = {path: synced_catalogue(path.read_text(encoding="utf-8"), wanted) for path in CATALOGUES}
    if args.check:
        stale = [str(path) for path, new in catalogues.items() if new != path.read_text(encoding="utf-8")]
        if stale:
            print("gen_names: a sub-type display differs from its lowest slot's name in %s" % ", ".join(stale))
            return 1
        have = Path(args.out).read_text(encoding="utf-8") if Path(args.out).exists() else ""
        if have != text:
            print("gen_names: %s is stale (rebuild with tools/r38_b1/gen_names.py)" % args.out)
            return 1
        differs = shown_differs(args.proposals) if args.proposals else []
        for line in differs:
            print(line)
        if differs:
            return 1
        print("gen_names: %s is current (%d names)%s" % (args.out, len(data["names"]),
              "; every slot shows its proposal's name" if args.proposals else ""))
        return 0
    Path(args.out).write_text(text, encoding="utf-8")
    for path, new in catalogues.items():
        path.write_text(new, encoding="utf-8")
    print("gen_names: wrote %d names to %s" % (len(data["names"]), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
