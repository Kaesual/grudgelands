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
directories of them; a key no slot has is an error. Python 3 standard
library only; deterministic output.
"""
import argparse
import glob
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "r38_names"))
sys.path.insert(0, str(REPO / "tools" / "r28_design"))
import inventory  # noqa: E402
import r28common  # noqa: E402

OUT = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "names.json"
NOTES = ("Round 38: every mob name, one per slot key <scope>/<source>/L<lo>-<hi> "
         "(tools/r38_names/inventory.py). Written by tools/r38_b1/gen_names.py; the PvP "
         "captains, war commanders and Generals keep their names in pvp_names.json.")


def pvp_individual(slot):
    source = slot["key"].split("/")[1]
    return slot["source"] == "pvp_garrison" and (
        ".captain-" in source or source.endswith(".commander") or source.endswith(".general"))


def interim_guard_names(model, names):
    """A PvP garrison's guards never share the settlement guards' name (the
    coordinator's ruling): until the naming lanes' picks arrive, a garrison
    guard slot that still bears it reads "<POI label> Guard"."""
    town = {s["name"] for s in model.slots if s["source"] == "guard"}
    labels = {key: poi["label"] for key, poi in r28common.pvp_pois().items()}
    for slot in model.slots:
        source = slot["key"].split("/")[1]
        if slot["source"] == "pvp_garrison" and source.endswith(".guard") and names.get(slot["key"]) in town:
            names[slot["key"]] = labels[source[:-len(".guard")]] + " Guard"


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
    interim_guard_names(model, names)
    errors = []
    for path in proposal_files(proposals):
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        for key, row in sorted((data.get("slots") or {}).items()):
            if key not in model.slot_by_key:
                errors.append("%s: %s is no slot" % (path, key))
            elif key in names and not row.get("keep"):
                names[key] = row["name"]
    return {"notes": NOTES, "names": dict(sorted(names.items()))}, errors


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
    if args.check:
        have = Path(args.out).read_text(encoding="utf-8") if Path(args.out).exists() else ""
        if have != text:
            print("gen_names: %s is stale (rebuild with tools/r38_b1/gen_names.py)" % args.out)
            return 1
        print("gen_names: %s is current (%d names)" % (args.out, len(data["names"])))
        return 0
    Path(args.out).write_text(text, encoding="utf-8")
    print("gen_names: wrote %d names to %s" % (len(data["names"]), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
