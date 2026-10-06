#!/usr/bin/env python3
"""Round 38: the quest-name guarantee, proved statically from the data.

The property (round38-mob-names-plan.md section 2.1): for every kill
objective and every quest drop, every mob that bears the name the quest names
counts -- whatever its level, wherever it is, wherever it spawned -- and no
mob of another name counts. Item objectives name items; their mobs are
guidance (plan section 6.7) and are not checked here.

The game (Round 38 lane B1) counts a kill by the name the mob shows:
grug_quests labels.lua Q.target_names resolves an objective's roles and area
once at load into the names of the slots they SELECT, state.lua mob_counts
compares the mob's name with them, and every mob takes its name from
data/names.json by (source, zone, level) (grug_mobs names.lua). So the
label and what counts are one list by construction; what can still break,
and what this tool proves over every slot of lane I's model
(tools/r38_names/inventory.py) and every quest:

  E-names-file     names.json misses a slot, names an unknown one, or a key
                   is malformed; a slot's runtime source differs from its key
  E-name-lookup    two names overlap in level in one (source, scope): the
                   runtime lookup could not decide
  E-no-bearer      a role of an objective selects no slot (it could never
                   be credited; the game's load check E-no-name)
  E-critter-name   a counted name is also a critter's
  E-garrison-name  a PvP garrison objective's name is borne outside the
                   garrisons too (a town or post guard would count)
  W-two-names      one role is shown under two names ("A or B")
  W-level-fit      the counted name's levels leave quest level +-3 (the log
                   shows them; the load check keeps its error on the
                   selection)
  W-text-name      the title and text never say a counted name (a {name:}
                   placeholder of a leader and {captain:} count as saying it)
  I-now-counts     same-named slots beyond the selection now count (the
                   Round 37 kill-credit bug, fixed)

    python3 tools/r38_names/guarantee.py            # summary
    python3 tools/r38_names/guarantee.py -v         # every finding
    python3 tools/r38_names/guarantee.py --check    # exit 1 on an E- finding
    python3 tools/r38_names/guarantee.py --out DIR  # findings.tsv, summary.json
    python3 tools/r38_names/guarantee.py --self-test

Python 3 standard library only.
"""
import argparse
import collections
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import inventory  # noqa: E402

NAMES = "mods/ENTITIES/grug_mobs/data/names.json"
LEVEL_SLACK = 3  # grug_quests validate.lua V.LEVEL_SLACK
KEY = re.compile(r"^([\w]+)/([\w.\-]+)/L(\d+)-(\d+)$")


def pvp_individual(slot):
    """A PvP captain, war commander or General: named in pvp_names.json."""
    source = slot["key"].split("/")[1]
    return slot["source"] == "pvp_garrison" and (
        ".captain-" in source or source.endswith(".commander") or source.endswith(".general"))


def runtime_source(slot):
    """The source the game looks a mob of this slot up by (names.lua): a
    rare's and a garrison post's key, else the entity role."""
    source = slot["key"].split("/")[1]
    if slot["source"] in ("rare", "pvp_garrison"):
        return source
    return slot["entity"].split(":", 1)[1]


def check_names_file(model, names):
    """E-names-file and E-name-lookup over data/names.json."""
    out = []
    rows = collections.defaultdict(list)
    for key, name in sorted(names.items()):
        m = KEY.match(key)
        if not m or int(m.group(3)) > int(m.group(4)):
            out.append(("E-names-file", None, "%s is not a slot key" % key))
            continue
        if not isinstance(name, str) or not name.strip():
            out.append(("E-names-file", None, "%s has no name" % key))
            continue
        scope, source, lo, hi = m.group(1), m.group(2), int(m.group(3)), int(m.group(4))
        for other in rows[(source, scope)]:
            if other[2] != name and other[0] <= hi and lo <= other[1]:
                out.append(("E-name-lookup", None, "%s %r overlaps %s %r in level" % (key, name, other[3], other[2])))
        rows[(source, scope)].append((lo, hi, name, key))
        if key not in model.slot_by_key:
            out.append(("E-names-file", None, "%s is no slot of the inventory" % key))
    for s in model.slots:
        if pvp_individual(s):
            continue
        if s["key"] not in names:
            out.append(("E-names-file", None, "slot %s has no name in %s" % (s["key"], NAMES)))
        elif runtime_source(s) != s["key"].split("/")[1]:
            out.append(("E-names-file", None, "slot %s: the game looks its mobs up as %r" % (
                s["key"], runtime_source(s))))
    return out


def text_says(quest, name, leader_names, captain_names):
    """Whether the title or text says `name` (or a simple plural); a {name:}
    placeholder says its leader's name, {captain:} its camp's captains'."""
    text = " ".join(str(quest.get(k) or "") for k in ("title", "text"))

    def fill(m):
        kind, ref = m.group(1), m.group(2).split("/")[-1]
        found = (captain_names if kind == "captain" else leader_names).get(ref)
        return " ".join(sorted(found)) if found else m.group(0)
    text = re.sub(r"\{(name|captain):([a-z0-9_/]+)\}", fill, text).lower()
    last = name.split()[-1]
    stem = name[:len(name) - len(last)]
    forms = {last, last + "s", last + "es", last + "'s"}
    if last.endswith("y"):
        forms.add(last[:-1] + "ies")
    if last.endswith("f"):
        forms.add(last[:-1] + "ves")
    if last.endswith("man"):
        forms.add(last[:-3] + "men")
    return any(re.search(r"(?<![a-z])%s(?![a-z])" % re.escape((stem + f).lower()), text) for f in forms)


def quests_by_id(model):
    out = {}
    for rel in sorted({o["file"] for o in model.objectives}):
        for q in model.repo.json(rel)["quests"]:
            out[q["id"]] = q
    return out


def check_objectives(model):
    out = []
    by_name = collections.defaultdict(list)
    for s in model.slots:
        by_name[s["name"]].append(s)
    leader_names = collections.defaultdict(set)
    captain_names = collections.defaultdict(set)
    for s in model.slots:
        source = s["key"].split("/")[1]
        if s["source"] == "leader":
            leader_names[s["role"]].add(s["name"])
        if ".captain-" in source:
            captain_names[source.split(".")[0]].add(s["name"])
    quests = quests_by_id(model)
    for o in model.objectives:
        if o["relation"] != "counts":
            continue
        where = "%s %s %s" % (o["file"].rsplit("/", 1)[-1], o["quest"], o["path"])
        quest = quests[o["quest"]]
        selected = [model.slot_by_key[k] for k in o["selected"]]
        names = sorted({s["name"] for s in selected})
        for role in o["roles"]:
            mine = [s for s in selected if s["role"] == role]
            if not mine:
                out.append(("E-no-bearer", where, "%s selects no slot (the game refuses to load: E-no-name)"
                            % role))
                continue
            groups = {s["key"].split("/")[1].split(".captain-")[0] if ".captain-" in s["key"] else s["name"]
                      for s in mine}
            if len(groups) > 1:
                out.append(("W-two-names", where, "%s is shown as %s" % (role, o["labels"][role])))
        counted = [s for n in names for s in by_name[n]]
        for s in counted:
            if s["tier"] == "critter" or s["disposition"] == "critter":
                out.append(("E-critter-name", where, "%r is also the critter %s" % (s["name"], s["key"])))
        if selected and all(s["source"] == "pvp_garrison" for s in selected):
            for s in counted:
                if s["source"] != "pvp_garrison":
                    out.append(("E-garrison-name", where, "%r is also borne by %s (%s)" % (
                        s["name"], s["key"], s["source"])))
        level = quest.get("level")
        if counted and isinstance(level, int):
            lo = min(s["levels"][0] for s in counted)
            hi = max(s["levels"][1] for s in counted)
            if lo < level - LEVEL_SLACK or hi > level + LEVEL_SLACK:
                out.append(("W-level-fit", where, "%s met at L%d-%d, quest level %d+-%d" % (
                    " / ".join(names), lo, hi, level, LEVEL_SLACK)))
        groups = collections.defaultdict(set)
        for s in selected:
            source = s["key"].split("/")[1]
            groups[source.split(".captain-")[0] if ".captain-" in source else s["name"]].add(s["name"])
        for group, members in sorted(groups.items()):
            if not any(text_says(quest, n, leader_names, captain_names) for n in members):
                out.append(("W-text-name", where, "title and text never say %s%s" % (
                    " / ".join(repr(n) for n in sorted(members)),
                    " (one per world: write {captain:%s})" % group if len(members) > 1 else "")))
        extra = sorted({s["key"] for s in counted} - set(o["selected"]))
        if extra:
            out.append(("I-now-counts", where, "%d more same-named slot(s) count: %s" % (
                len(extra), ", ".join(extra[:4]) + (" ..." if len(extra) > 4 else ""))))
    return out


def run(model, names):
    return check_names_file(model, names) + check_objectives(model)


def self_test():
    """Synthetic cases over a tiny model: each must raise exactly its codes."""
    class Fake:
        pass

    def model(slots, objectives, quests):
        m = Fake()
        m.slots = slots
        m.slot_by_key = {s["key"]: s for s in slots}
        m.objectives = objectives
        m.repo = Fake()
        m.repo.json = lambda rel: {"quests": quests}
        return m

    def slot(key, name, source="recipe", tier="normal", tags=(), role=None):
        lo, hi = (int(x) for x in key.rsplit("/L", 1)[1].split("-"))
        role = role or key.split("/")[1].split(".")[0]
        return {"key": key, "name": name, "source": source, "tier": tier, "disposition": "aggressive",
                "entity": "grug_mobs:" + role, "role": role, "levels": [lo, hi], "tags": list(tags)}

    def obj(roles, selected, labels):
        return {"file": "q.json", "quest": "q", "path": "objectives[0]", "relation": "counts",
                "roles": roles, "selected": selected, "labels": labels}

    quest = [{"id": "q", "level": 2, "title": "Pigs", "text": "Defeat pigs."}]
    a, b = "z/pig/L1-2", "z/pig/L3-4"
    cases = [
        ("one name over two bands: the other band counts too", [slot(a, "Pig"), slot(b, "Pig")],
         {a: "Pig", b: "Pig"}, [obj(["pig"], [a], {"pig": "Pig"})], set(), {"I-now-counts"}),
        ("overlapping names", [slot(a, "Pig"), slot(b, "Hog")], {a: "Pig", "z/pig/L2-3": "Hog"},
         [obj(["pig"], [a], {"pig": "Pig"})], {"E-names-file", "E-name-lookup"}, None),
        ("nothing selected", [slot(a, "Pig")], {a: "Pig"}, [obj(["pig"], [], {"pig": "pig"})],
         {"E-no-bearer"}, None),
        ("a critter shares the name", [slot(a, "Pig"), slot("z/hare/L1-1", "Pig", "critter", "critter")],
         {a: "Pig", "z/hare/L1-1": "Pig"}, [obj(["pig"], [a], {"pig": "Pig"})], {"E-critter-name"}, None),
        ("a town guard shares a garrison's name",
         [slot("f/camp.guard/L41-43", "Guard", "pvp_garrison", role="guard"),
          slot("world/guard/L20-60", "Guard", "guard")],
         {"f/camp.guard/L41-43": "Guard", "world/guard/L20-60": "Guard"},
         [obj(["guard"], ["f/camp.guard/L41-43"], {"guard": "Guard"})], {"E-garrison-name"}, None),
    ]
    # The selector itself (inventory.runtime_fallback, labels.lua): a role
    # met only in other zones under two names selects nothing.
    import inventory as inv
    two = [slot("x/bear/L5-6", "Bear"), slot("y/bear/L5-6", "Old Bear")]
    one = [slot("x/bear/L5-6", "Bear"), slot("y/bear/L5-6", "Bear")]
    cases.append(("a role of other zones under two names selects nothing", two,
                  {s["key"]: s["name"] for s in two},
                  [obj(["bear"], [s["key"] for s in inv.runtime_fallback(two, "z")], {"bear": "bear"})],
                  {"E-no-bearer"}, None))
    cases.append(("...under one name selects its slots", one, {s["key"]: s["name"] for s in one},
                  [obj(["bear"], [s["key"] for s in inv.runtime_fallback(one, "z")], {"bear": "Bear"})],
                  set(), None))
    failed = 0
    for label, slots, names, objectives, want, want_all in cases:
        m = model(slots, objectives, quest)
        found = run(m, names)
        got = {code for code, _, _ in found if code.startswith("E-")}
        got_all = {code for code, _, _ in found}
        ok = got == want and (want_all is None or got_all == want_all)
        failed += not ok
        print("%s %s%s" % ("ok  " if ok else "FAIL", label, "" if ok else ": %s" % sorted(got_all)))
    return 1 if failed else 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 on an E- finding")
    ap.add_argument("--out", help="write findings.tsv and summary.json here")
    ap.add_argument("-v", "--verbose", action="store_true", help="print every finding")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    model = inventory.build(REPO, surfaces=False)
    names = json.loads((REPO / NAMES).read_text(encoding="utf-8"))["names"]
    found = run(model, names)
    counts = collections.Counter(code for code, _, _ in found)
    objs = collections.defaultdict(set)
    for code, where, _ in found:
        if where:
            objs[code].add(where)
    counting = [o for o in model.objectives if o["relation"] == "counts"]
    print("guarantee: %d slots, %d names in %s, %d objectives that count kills (%s)" % (
        len(model.slots), len(names), NAMES, len(counting),
        ", ".join("%s %d" % kv for kv in sorted(collections.Counter(o["kind"] for o in counting).items()))))
    for code in sorted(counts):
        print("  %-16s %5d findings in %4d objectives" % (code, counts[code], len(objs.get(code, ()))))
    errors = sum(n for code, n in counts.items() if code.startswith("E-"))
    print("guarantee: %s" % ("PASS (no E- finding)" if not errors else "FAIL (%d E- findings)" % errors))
    if args.verbose:
        for code, where, detail in found:
            print("%-16s %s: %s" % (code, where or "-", detail))
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "findings.tsv"), "w", encoding="utf-8") as h:
            for code, where, detail in found:
                h.write("%s\t%s\t%s\n" % (code, where or "-", detail))
        with open(os.path.join(args.out, "summary.json"), "w", encoding="utf-8") as h:
            json.dump({"findings": dict(sorted(counts.items())),
                       "objectives": {k: len(v) for k, v in sorted(objs.items())}}, h, indent=1, sort_keys=True)
            h.write("\n")
    return 1 if (args.check and errors) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
