#!/usr/bin/env python3
"""Round 38 lane I: fixture of check_rules.py on tiny proposals.

    python3 tools/r38_names/test_rules.py [REPO]

Builds the real inventory model (without the text scan), names the slots of
two neighbouring zones (Stillgrave Hollow and Mournfen) with a clean
proposal, then breaks one rule at a time and expects exactly that rule's
line. Exit status 1 on a failure. Python 3 standard library only.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_rules  # noqa: E402
import inventory  # noqa: E402

FAILS = []


def expect(cond, what):
    if not cond:
        FAILS.append(what)
        print("FAIL: " + what)


def clean_names(model, zones):
    """One rule-abiding name per slot of `zones`: a distinct two-word name
    per (zone, role), so every name has one band ... except roles spread
    over several bands, which get one name per band."""
    out = {}
    for s in model.slots:
        if s["zone"] not in zones:
            continue
        stem = "".join(p.capitalize() for p in s["role"].split("_"))[:12]
        zone = s["zone"].split("_")[1].capitalize()
        name = "%s %s%d" % (zone, stem, s["levels"][0])
        # digits keep names apart; no signal word, two words
        out[s["key"]] = (name, False, "fixture", "fixture")
    return out


def run(model, entries, partial=True):
    problems, notes = check_rules.check(model, entries, partial=partial)
    return problems, notes


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else str(inventory.REPO)
    model = inventory.build(repo, surfaces=False)
    zones = {"kragmar_stillgrave_hollow", "kragmar_mournfen"}
    base = clean_names(model, zones)
    problems, _ = run(model, base)
    expect(problems == [], "a clean two-zone proposal passes (got %s)" % problems[:3])

    def broken(key, name, keep=False):
        entries = dict(base)
        entries[key] = (name, keep, "fixture", "fixture")
        return run(model, entries)[0]

    sg = "kragmar_stillgrave_hollow"
    # R1: a normal mob with three words; a named leader may have three.
    p = broken(sg + "/small_boar/L3-4", "Grey Furrow Hog")
    expect(len(p) == 1 and p[0].startswith("R1 "), "R1 three words on a normal mob: %s" % p)
    p = broken(sg + "/grave_robber_chief/L10-10", "Borrow the Digger")
    expect(p == [], "R1 three words on a named leader pass: %s" % p)
    p = broken(sg + "/grave_robber_chief/L10-10", "Borrow the Grave Digger")
    expect(len(p) == 1 and p[0].startswith("R1 "), "R1 four words on a named leader: %s" % p)
    # R2: a signal word, in any case.
    p = broken(sg + "/large_rat/L3-4", "large Barrowrat")
    expect(len(p) == 1 and p[0].startswith("R2 "), "R2 signal word: %s" % p)
    # R3: Piglet only on the *_hunt_01 start pigs.
    p = broken(sg + "/small_boar/L1-2", "Grave Piglet")
    expect(p == [], "R3 Piglet on the hunt_01 pigs passes: %s" % p)
    p = broken(sg + "/small_boar/L3-4", "Grave Piglet")
    expect(len(p) == 1 and p[0].startswith("R3 "), "R3 Piglet elsewhere: %s" % p)
    # R4: one name on L1-2 and L5-7 leaves a gap; on L1-2 and L3-4 it joins.
    entries = dict(base)
    entries[sg + "/small_boar/L1-2"] = ("Grave Hog", False, "fixture", "fixture")
    entries[sg + "/small_boar/L3-4"] = ("Grave Hog", False, "fixture", "fixture")
    expect(run(model, entries)[0] == [], "R4 adjacent bands in one tier pass")
    entries[sg + "/aggressive_boar/L5-7"] = ("Grave Hog", False, "fixture", "fixture")
    entries[sg + "/small_boar/L3-4"] = ("Furrow Hog", False, "fixture", "fixture")
    p = run(model, entries)[0]
    expect(len(p) == 1 and p[0].startswith("R4 ") and "gap" in p[0], "R4 gap: %s" % p)
    # R4 across zones: Stillgrave L8-10 and Mournfen L11-13 are two tiers.
    mf = [s["key"] for s in model.slots if s["zone"] == "kragmar_mournfen" and s["levels"][0] == 11]
    entries = dict(base)
    entries[sg + "/aggressive_boar/L8-10"] = ("Grave Hog", False, "fixture", "fixture")
    entries[mf[0]] = ("Grave Hog", False, "fixture", "fixture")
    p = run(model, entries)[0]
    expect(len(p) == 1 and p[0].startswith("R4 ") and "T1,T2" in p[0], "R4 two tiers across zones: %s" % p)
    # R4 does not bind the world/ slots (the user, plan §6 items 9 and 10):
    # a faction guard (L20-60) and an underground cast keep one name each.
    world = {s["key"]: (s["name"], True, "fixture", "fixture") for s in model.slots}
    guard = [s["key"] for s in model.slots if s["key"].startswith("world/guard_")]
    expect(guard and all(len(model.slot_by_key[k]["drop_tiers"]) > 1 for k in guard),
           "the faction guards span several tiers: %s" % guard)
    expect(not [x for x in run(model, world)[0] if x.startswith("R4 ") and "world/" in x],
           "R4 exempts the world/ slots")
    # R4 effective tier (the user's ruling, plan §6 item 11): a capital's L20-23
    # slot counts as T3, so it joins L24-27 but not a L18-20 slot.
    hc, gm = "elandor_highcourt", "elandor_goldmead_vale"
    cap = clean_names(model, {hc, gm})
    low = [s["key"] for s in model.slots if s["zone"] == gm and s["levels"][1] == 20 and s["source"] == "recipe"]
    entries = dict(cap)
    entries[hc + "/moss_antler_stag/L20-23"] = ("Court Hart", False, "fixture", "fixture")
    entries[hc + "/moss_antler_stag/L24-27"] = ("Court Hart", False, "fixture", "fixture")
    p, notes = run(model, entries)
    expect(p == [], "R4 capital L20-23 joins L24-27 (T3): %s" % p)
    expect(any("moss_antler_stag/L20-23" in n and "counts as T3" in n for n in notes),
           "R4 note flags the L20-23 slot itself")
    entries[low[0]] = ("Court Hart", False, "fixture", "fixture")
    p = run(model, entries)[0]
    expect(len(p) == 1 and p[0].startswith("R4 ") and "T2,T3" in p[0], "R4 L20-23 with a L..20 slot: %s" % p)

    # R4 gap exemption (coordinator's ruling, lane C): the Rift Spawn's point
    # slots (L52, 56, 59, 60, all T6) share one name without a gap problem;
    # the exemption holds only while every slot bearing the name is a rift
    # spawn row.
    gs, ss = "front_gravesalt_escarpment", "front_stormscale_summit"
    rift = clean_names(model, {gs, ss})
    rift_keys = sorted(k for k in rift if model.slot_by_key[k]["role"] == "rift_spawn")
    expect(len(rift_keys) == 4, "four rift spawn slots in Gravesalt and Stormscale: %s" % rift_keys)
    for k in rift_keys:
        rift[k] = ("Rift Spawn", False, "fixture", "fixture")
    p = run(model, rift)[0]
    expect(p == [], "R4 Rift Spawn over L52, 56, 59, 60 passes: %s" % p)
    other = [s["key"] for s in model.slots if s["zone"] == gs and s["role"] != "rift_spawn"
             and s["levels"] == [58, 60]]
    rift[other[0]] = ("Rift Spawn", False, "fixture", "fixture")
    p = run(model, rift)[0]
    expect(len(p) == 2 and all(x.startswith("R4 ") and "gap" in x for x in p),
           "R4 Rift Spawn on another role loses the exemption (gaps 53-55, 57): %s" % p)

    # --world-pending: every zone slot named, the world/ slots missing.
    zoned = clean_names(model, {s["zone"] for s in model.slots if s["zone"]})
    world = [s for s in model.slots if s["zone"] is None]
    expect(world and run(model, zoned, partial=False)[0] and
           len(run(model, zoned, partial=False)[0]) == len(world),
           "full mode lists every unnamed world/ slot")
    p = check_rules.check(model, zoned, world_pending=True)[0]
    expect(p == [], "--world-pending: all zone slots named pass: %s" % p[:3])
    del zoned[sg + "/hare/L1-1"]
    p = check_rules.check(model, zoned, world_pending=True)[0]
    expect(len(p) == 1 and "not named" in p[0], "--world-pending: a missing zone slot: %s" % p)

    # R0: unknown key, a missing slot, a keep with another name, no reason.
    p = broken(sg + "/no_such_role/L1-2", "Grave Hog")
    expect(len(p) == 1 and "unknown slot key" in p[0], "R0 unknown key: %s" % p)
    entries = dict(base)
    del entries[sg + "/hare/L1-1"]
    p = run(model, entries)[0]
    expect(len(p) == 1 and "not named" in p[0], "R0 missing slot: %s" % p)
    p = broken(sg + "/hare/L1-1", "Grave Hare", keep=True)
    expect(len(p) == 1 and "keep, but name" in p[0], "R0 keep with another name: %s" % p)
    entries = dict(base)
    entries[sg + "/hare/L1-1"] = (None, True, "", "fixture")
    p = run(model, entries)[0]
    expect(len(p) == 1 and "no reason" in p[0], "R0 keep without a reason: %s" % p)
    # Without --partial every slot of the world must be named.
    p = run(model, base, partial=False)[0]
    expect(len(p) == len(model.slots) - len(base), "full mode lists every unnamed slot")

    # The command line: files, a twice-named slot, exit status.
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for zone in sorted(zones):
            slots = {k: {"name": v[0], "reason": v[2]} for k, v in base.items() if k.startswith(zone + "/")}
            path = Path(tmp) / (zone + ".json")
            path.write_text(json.dumps({"zone": zone, "lane": "fixture", "slots": slots}), encoding="utf-8")
            files.append(str(path))
        cmd = [sys.executable, str(HERE / "check_rules.py"), "--repo", repo, "--partial"]
        ok = subprocess.run(cmd + files, capture_output=True, text=True)
        expect(ok.returncode == 0, "CLI: clean files exit 0 (%s)" % ok.stdout.strip()[-200:])
        dup = Path(tmp) / "dup.json"
        key = sg + "/hare/L1-1"
        dup.write_text(json.dumps({"zone": sg, "slots": {key: {"keep": True, "reason": "x"}}}), encoding="utf-8")
        bad = subprocess.run(cmd + files + [str(dup)], capture_output=True, text=True)
        expect(bad.returncode == 1 and "named twice" in bad.stdout, "CLI: a twice-named slot exits 1")
        today = subprocess.run([sys.executable, str(HERE / "check_rules.py"), "--repo", repo, "--today",
                                "--quiet-notes"], capture_output=True, text=True)
        expect(today.returncode == 1 and today.stdout.startswith("R"), "CLI: today's names break rules")
    print("test_rules: %d failure%s" % (len(FAILS), "" if len(FAILS) == 1 else "s"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
