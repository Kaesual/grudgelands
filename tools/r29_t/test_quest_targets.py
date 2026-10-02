#!/usr/bin/env python3
"""Round 29 Lane T: tools/r28_regions/quest_targets.py on a small fixture.

Two recipe zones (Alpha with two kinds, a camp and its chief; Beta with one
kind and a leader picked in it), their region stats on two seeds and one
quest file, and checks the report: area kinds and camps, a kind that forms
no region on one seed, an unknown area, a role not in its area, a leader
given an area, leaders of the file's zone and of another zone, item sources
and quest drops, roles without an area (any listed role counts), placeholder
targets, the clock note and CLOCK, the legacy path and the tool with it
removed as its comment says, and the exit status (1 MISSING, 2 stale stats,
0 clean).

Usage (repo root): python3 tools/r29_t/test_quest_targets.py
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "r28_regions/quest_targets.py"
failures = checks = 0


def check(ok, label):
    global failures, checks
    checks += 1
    if not ok:
        failures += 1
        print("FAIL " + label)


def roster(*roles):
    return [{"role": r, "weight": 1} for r in roles]


RECIPES = {
    "elandor_alpha_fields": {
        "belts": [{"id": "b1", "share": 100, "levels": [1, 10], "kinds": {
            "open": {"id": "meadows", "name": "Meadows", "day": roster("small_boar"),
                     "night": roster("large_rat"), "density": "normal"},
            "forest": {"id": "copse", "name": "Copse", "day": "open", "night": roster("zombie"),
                       "density": "normal"}}}],
        "camps": [{"id": "camp", "name": "Camp", "belt": "b1", "roster": roster("bandit")}],
        "leaders": [{"role": "chief", "at": {"camp": "camp"}, "respawn": 300}],
    },
    "elandor_beta_wood": {
        "belts": [{"id": "b1", "share": 100, "levels": [1, 10], "kinds": {
            "open": {"id": "oakwood", "name": "Oakwood", "day": roster("wolf"), "night": roster("wolf"),
                     "density": "normal"}}}],
        "leaders": [{"role": "elder_wolf", "at": {"kind": "oakwood", "pick": "farthest_from_roads"},
                     "respawn": 300}],
    },
}
# Regions per seed (1, 2) and the leaders placed.
STATS = {
    ("alpha", "1"): ({"meadows": 3, "copse": 2, "camp": 1}, ["chief"]),
    ("alpha", "2"): ({"meadows": 3, "copse": 0, "camp": 1}, ["chief"]),
    ("beta", "1"): ({"oakwood": 1}, ["elder_wolf"]),
    ("beta", "2"): ({"oakwood": 1}, []),
}


def kill(roles, area=None):
    row = {"type": "kill", "roles": roles, "count": 1}
    if area:
        row["area"] = area
    return row


def quest(qid, objectives, text="Go.", **extra):
    row = {"id": qid, "title": qid, "text": text, "objectives": objectives}
    row.update(extra)
    return row


QUESTS = [
    quest("q_kind", [kill(["small_boar"], "elandor_alpha_fields/meadows")], "Boars {zone_area:meadows} by day."),
    quest("q_bare_area", [kill(["large_rat"], "meadows")], "Rats come out after nightfall; do your daytime work first."),
    quest("q_clock", [kill(["small_boar"], "meadows")], "Boars root there after dark."),
    quest("q_gap", [kill(["zombie"], "copse")]),
    quest("q_unknown", [kill(["small_boar"], "nowhere")]),
    quest("q_leader", [kill(["chief"])], "{dir_from_giver:chief} the chief waits."),
    quest("q_xleader", [kill(["elder_wolf"])], "The wolves den {dir_of:alpha:elandor_beta_wood/oakwood}."),
    quest("q_sources", [{"type": "item", "item": "x:purse", "count": 1, "roles": ["bandit"], "area": "camp"}],
          quest_drops=[{"item": "x:tusk", "roles": ["small_boar"], "area": "meadows", "chance": 2}]),
    quest("q_noarea", [kill(["small_boar"])]),
    quest("q_noarea_other", [kill(["wolf"])]),
    quest("q_text_gap", [{"type": "talk", "npc": "someone"}], "The copse lies {dir_from_giver:copse}."),
    quest("q_name_unknown", [{"type": "item", "item": "x:log", "count": 1}], "The {name:castle} burns."),
    quest("q_not_in_area", [kill(["large_rat", "zombie"], "meadows")]),
    quest("q_leader_area", [kill(["chief"], "camp")]),
    quest("q_any_role", [kill(["small_boar", "large_rat"])]),
    quest("q_any_role_mixed", [kill(["small_boar", "wolf"])]),
    quest("q_mobs_area", [{"type": "kill", "mobs": ["grug_mobs:small_boar"], "area": "meadows", "count": 1}]),
    quest("q_legacy", [{"type": "kill", "mobs": ["grug_mobs:deer"], "count": 1}], line="legacy"),
]


def write_world(root, quests, stats=STATS):
    spawns, regions, qdir = root / "spawns", root / "regions", root / "quests"
    for d in (spawns, regions, qdir):
        d.mkdir(parents=True, exist_ok=True)
    for zone, recipe in RECIPES.items():
        (spawns / (zone + ".spawns.json")).write_text(json.dumps({"zone": zone, "recipe": recipe}))
    for (short, seed), (counts, leaders) in stats.items():
        lines = ["# stats", "", "| Kind | Belt | Type | Density | Land share | Regions | Day | Night |",
                 "|---|---|---|---|---|---|---|---|"]
        for unit, n in counts.items():
            lines.append("| %s (`%s`) | 1 | open | normal | 1.0 %% | %d | - | - |" % (unit.title(), unit, n))
        lines += ["", "## Camps and leaders", ""]
        for role in leaders:
            lines.append("- Leader %s (`%s`) at (1, 2), level 10, respawn 300 s." % (role.title(), role))
        (regions / short).mkdir(exist_ok=True)
        (regions / short / ("seed_%s.md" % seed)).write_text("\n".join(lines) + "\n")
    (qdir / "elandor_alpha_fields.quests.json").write_text(json.dumps({"zone": "elandor_alpha_fields",
                                                                        "quests": quests}))
    return ["--spawns", str(spawns), "--root", str(regions), "--quests", str(qdir), "--seeds", "1 2"]


def run(args, verbose=True):
    done = subprocess.run([sys.executable, str(TOOL)] + args + (["--verbose"] if verbose else []),
                          capture_output=True, text=True)
    return done.returncode, done.stdout


def line_with(out, *parts):
    return next((l for l in out.splitlines() if all(p in l for p in parts)), None)


with tempfile.TemporaryDirectory() as tmp:
    code, out = run(write_world(Path(tmp) / "all", QUESTS))
    check(code == 1, "MISSING targets: exit status 1 (got %d)" % code)
    for parts, label in [
        (("q_kind obj 1", "in elandor_alpha_fields/meadows (day only)"), "a qualified area kind, its clock noted"),
        (("q_kind text {zone_area:meadows}",), "a placeholder target that forms"),
        (("q_bare_area obj 1", "in elandor_alpha_fields/meadows (night only)"), "a bare area is the file's zone"),
        (("q_leader obj 1 (chief)",), "a placed leader of the zone"),
        (("q_leader text {dir_from_giver:chief}",), "a leader as a placeholder target"),
        (("q_sources obj 1 (bandit) in elandor_alpha_fields/camp",), "an item objective's source area"),
        (("q_sources quest drop 1 (small_boar)",), "a quest drop's source area"),
        (("q_noarea obj 1 (small_boar) (day only)",), "a role without an area in the file zone's kinds"),
        (("q_any_role obj 1 (large_rat, small_boar)",), "two roles without an area, day and night"),
        (("q_any_role_mixed obj 1 (small_boar, wolf) (day only)",), "any listed role counts without an area"),
        (("q_xleader text {dir_of:alpha:elandor_beta_wood/oakwood}",), "a kind of another zone"),
    ]:
        row = line_with(out, *parts)
        check(row is not None and not row.lstrip().startswith("MISSING"), label + ": ok")
    missing = out.split("MISSING (", 1)[1].split("\nCLOCK", 1)[0] if "MISSING (" in out else ""
    for parts, label in [
        (("q_gap obj 1", "on seed 2"), "a kind without a region on seed 2"),
        (("q_unknown obj 1", "nowhere is no kind or camp"), "an unknown area"),
        (("q_xleader obj 1 (elder_wolf)", "on seed 2"), "a leader of another zone not placed on seed 2"),
        (("q_noarea_other obj 1 (wolf)", "not in elandor_alpha_fields's recipe"), "a role the file zone never spawns"),
        (("q_text_gap text {dir_from_giver:copse}", "on seed 2 (no direction there)"),
         "a placeholder target without a region on seed 2"),
        (("q_name_unknown text {name:castle}", "castle is no kind or camp"), "an unknown placeholder target"),
        (("q_not_in_area obj 1", "zombie does not spawn in elandor_alpha_fields/meadows"), "a role not in the area"),
        (("q_leader_area obj 1", "chief is a leader at a fixed spot, not in an area"), "a leader given an area"),
        (("q_mobs_area obj 1", "names entities (`mobs`)"), "a `mobs` objective the legacy path does not take"),
    ]:
        check(line_with(missing, *parts) is not None, label + ": MISSING")
    check("Accepted" not in (line_with(out, "chief") or ""), "a leader is never accepted")
    clock = out.split("CLOCK (", 1)[1].split("\nAccepted", 1)[0] if "CLOCK (" in out else ""
    check(line_with(clock, "q_clock", "names the night", "day only") is not None, "CLOCK: a night text on day boars")
    check(line_with(clock, "q_kind") is None and line_with(clock, "q_bare_area") is None, "CLOCK: matching texts pass")
    check(line_with(out, "legacy kill objectives: ok 0, accepted", "1, MISSING 0") is not None, "legacy counts")
    check(line_with(out, "q_legacy obj 1 (deer in elandor_alpha_fields)") is not None, "legacy target accepted")
    check(line_with(out, "q_any_role obj 1", "only)") is None, "a day and a night role: no clock note")
    check(line_with(missing, "q_not_in_area", "large_rat does not spawn") is None, "a role in the area is no problem")

    # The legacy path removed as its comment says: the block and every line
    # tagged `# LEGACY`. The result runs, and a `mobs` objective is MISSING.
    source = TOOL.read_text()
    head, rest = source.split("# LEGACY: Round 28", 1)
    source = head + rest.split("# END LEGACY\n", 1)[1]
    source = "\n".join(l for l in source.splitlines() if not l.endswith("# LEGACY")) + "\n"
    check("LEGACY" not in source.split('"""', 2)[2], "nothing of the legacy path is left")
    stripped = Path(tmp) / "quest_targets_without_legacy.py"
    stripped.write_text(source)
    args = write_world(Path(tmp) / "legacy", [QUESTS[0], QUESTS[-1]])
    done = subprocess.run([sys.executable, str(stripped)] + args, capture_output=True, text=True)
    check(done.returncode == 1 and line_with(done.stdout, "q_legacy obj 1", "names entities (`mobs`)") is not None,
          "without the legacy path a `mobs` objective is MISSING: " + done.stdout + done.stderr)

    good = [q for q in QUESTS if q["id"] in ("q_kind", "q_bare_area", "q_leader", "q_sources", "q_noarea")]
    code, out = run(write_world(Path(tmp) / "good", good), verbose=False)
    check(code == 0, "every target forms: exit status 0 (got %d)" % code)
    check("no legacy kill objective left: delete the LEGACY block" in out, "the report says when the legacy path is unused")
    check(line_with(out, "targets: ok 8, MISSING on some seed 0, CLOCK 0") is not None,
          "counts of a clean run: " + out.splitlines()[1])

    stale = dict(STATS)
    stale[("alpha", "2")] = ({"meadows": 3, "camp": 1}, ["chief"])
    code, out = run(write_world(Path(tmp) / "stale", good, stale), verbose=False)
    check(code == 2 and "STALE" in out, "stats without a recipe kind: exit status 2")

print("%d checks, %d failures" % (checks, failures))
if failures:
    sys.exit(1)
print("R29 T QUEST TARGETS PASS checks=%d" % checks)
