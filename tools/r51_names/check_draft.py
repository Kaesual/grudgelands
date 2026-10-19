#!/usr/bin/env python3
"""Round 51 lane NAMES: the Round 38 name gates over the draft.

    python3 tools/r51_names/check_draft.py [--draft tools/r51_names/draft.json]

The gates (tools/r38_names/check_rules.py --shipped, guarantee.py --check,
tools/r38_b1/gen_names.py --check) read the inventory of the shipped game,
where the draft's slots do not exist yet. This adapter builds that
inventory (tools/r38_names/inventory.py), adds the draft's slots to it as
the inventory would read them once the MOBS lane ships them (a zone slot
as a recipe slot of its role, a world slot as a water authority's), and
runs on today's names plus the draft's:

  check_rules  rules R0-R4 (words, signal words, Piglet, one level stretch
               within one drop tier per name over every zone using it)
  guarantee    E-names-file and E-name-lookup over names.json plus the
               draft (what gen_names.py would write; no quest targets a
               water mob yet, so no objective check changes)
  clash        a draft name that today's game already gives a mob of
               another family, or that a critter and a non-critter share

Exit 1 on any problem. Python 3 standard library only.
"""
import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools" / "r38_names"))
import check_rules  # noqa: E402
import guarantee  # noqa: E402
import inventory  # noqa: E402

DRAFT = HERE / "draft.json"


def add_draft_slots(model, draft):
    # A slot the game already ships (the MOBS lane's world slots since step
    # M1, its zone slots from step M2) is the inventory's own; only the rest
    # is added.
    for key, s in sorted(draft["slots"].items()):
        if key in model.slot_by_key:
            continue
        model.add_slot({
            "key": key, "zone": s["zone"], "source": "recipe", "name": s["name"],
            "name_source": "r51 draft", "name_where": "tools/r51_names/draft.json",
            "entity": "grug_mobs:" + s["role"], "role": s["role"], "family": s["family"], "base": s["base"],
            "tier": s["tier"], "authored_tier": s["tier"], "leader": False, "disposition": s["disposition"],
            "size": 1.0, "drops": s["family"], "role_levels": list(s["levels"]), "levels": list(s["levels"]),
            "clocks": ["day", "night"]})
    for w in draft["world"]:
        if w["status"] != "new" or w["key"] in model.slot_by_key:
            continue
        model.add_slot({
            "key": w["key"], "zone": None, "source": "water", "name": w["name"],
            "name_source": "r51 draft", "name_where": "tools/r51_names/draft.json",
            "entity": w["entity"], "role": w["entity"].split(":", 1)[1], "family": w["family"],
            "base": w["entity"], "tier": w["tier"], "authored_tier": w["tier"], "leader": False,
            "disposition": "critter" if w["tier"] == "critter" else "aggressive", "size": 1.0, "drops": None,
            "role_levels": [w["level"], w["level"]], "levels": [w["level"], w["level"]], "clocks": ["any"]})


def draft_names(draft):
    out = {k: s["name"] for k, s in draft["slots"].items()}
    for w in draft["world"]:
        if w["status"] == "new":
            out[w["key"]] = w["name"]
    return out


def run(draft):
    model = inventory.build(REPO, surfaces=False)
    today = check_rules.today_entries(model)
    today_slots = list(model.slots)
    add_draft_slots(model, draft)
    new = draft_names(draft)
    entries = dict(today)
    for key, name in new.items():
        entries[key] = (name, False, "r51 draft", "tools/r51_names/draft.json")
    problems, notes = check_rules.check(model, entries)
    notes = [n for n in notes if any(k in n for k in new)]

    names = json.loads((REPO / guarantee.NAMES).read_text(encoding="utf-8"))["names"]
    names = dict(names, **new)
    found = guarantee.check_names_file(model, names)
    g_errors = ["%s %s" % (code, detail) for code, _, detail in found if code.startswith("E-")]

    clash = []
    by_name = {}
    for s in today_slots:
        by_name.setdefault(s["name"].lower(), []).append(s)
    draft_family = {}
    for key, name in new.items():
        s = model.slot_by_key[key]
        draft_family.setdefault(name.lower(), set()).add((s["family"], s["tier"] == "critter"))
        for other in by_name.get(name.lower(), []):
            if other["family"] != s["family"]:
                clash.append("clash %s: %r is today's name of %s (family %s)" % (key, name, other["key"],
                                                                                  other["family"]))
                break
    for lname, fams in sorted(draft_family.items()):
        if len({f for f, _ in fams}) > 1:
            clash.append("clash %r: two draft families share it (%s)" % (lname, ", ".join(sorted(f for f, _ in fams))))
        if len({c for _, c in fams}) > 1:
            clash.append("clash %r: a critter and a non-critter share it" % lname)
    total = len(problems) + len(g_errors) + len(clash)
    summary = ("PASS: check_rules R0-R4 0 problems over %d slots (%d of them the draft's), guarantee 0 E- findings, "
               "0 name clashes" % (len(entries), len(new)) if not total else
               "FAIL: %d check_rules problems, %d guarantee E- findings, %d clashes" % (
                   len(problems), len(g_errors), len(clash)))
    return {"summary": summary, "ok": total == 0, "check_rules": problems, "notes": notes,
            "guarantee": g_errors, "clash": clash, "slots_checked": len(entries), "draft_slots": len(new)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--draft", default=str(DRAFT))
    args = ap.parse_args(argv)
    draft = json.loads(Path(args.draft).read_text(encoding="utf-8"))
    res = run(draft)
    for line in res["check_rules"] + res["guarantee"] + res["clash"]:
        print(line)
    for line in res["notes"]:
        print(line)
    print(res["summary"])
    return 0 if res["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
