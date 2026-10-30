#!/usr/bin/env python3
"""Round 53 lane INTEG: the end-to-end test of the migration step 0.53.0
(tools/migration/steps/v0_53_0.py and its join part in
grug_core/migrations.lua; contract R8, round workflow section 3 "Migration
steps"). It reuses Round 43 IT's harness (tools/r43_it/it.py: boots, the
database dumps and the PASS table; client.py for the joins).

  export   the 0.52.1 commit (OLD below, origin/main: the production
           server's version) through `git archive`: its game and launcher
  boot S   the 0.52.1 game on a new world (SQLite player, auth and mod
           storage): warrior, mage, priest, scout, sleeper (a second Mage)
           and walker (no class) join and the probe (grug_probe_r53_ms)
           builds them: level 30, spent talents, the stored talent windows,
           the used free respec, the retired skills on the shown hotbar, on
           the other layout and in a bag (see the probe's header)
  keep     with GUI_WORLD=<dir>, that 0.52.1 world is copied there for the
           user's GUI test (round53-plan.md section 6; the characters log in
           with the password "it-<name>")
  boot R   this checkout's game on the 0.52.1 world without the tool:
           refused by the guard naming the step 0.53.0, nothing written
  tool     the shipped tool in the platform runner's environment (Debian
           trixie, python3 3.13; tools/r43_it/Containerfile): --check, the
           migration, --check again; exactly the talent keys, the retired
           skills, the markers and the record change
  boot A   this checkout's game on the migrated world: everyone but sleeper
           joins: one chat line "Your talent points have been reset." for
           each character with a class and none for walker, every point
           free, no retired skill and no locked skill on either hotbar, the
           Mage's and Priest's lower maximum HP with the current HP clamped
           to it; once the class lanes have merged (Fiery Spark registered)
           also the kit swaps of the game's join on both layouts
  boot B   mage joins again: no chat line, nothing changes

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r53_ms/evidence) and exits 0 only when
every check passed.

Usage: tools/r53_ms/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)
from migration import data, world as worldmod  # noqa: E402

OLD = "e4d5c9d5"           # origin/main at 0.52.1, what production runs
OLD_VERSION = "0.52.1"
NEW_VERSION = "0.53.0"
# Round 67: the later declared steps (0.67.0 on) run in the same tool run and
# start the world at their version; this step's own checks stay as they were
# (the pattern of tools/r48_bags/e2e.py).
DECLARED = json.loads((REPO / "tools" / "web_data" / "upgrade.json").read_text())["migrate"]
DUE = [v for v in DECLARED if tuple(map(int, v.split("."))) > (0, 52, 1)]
LAST = DUE[-1]
PROBE = HERE / "grug_probe_r53_ms"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r53_ms_probe\]")
check = it.check
CLASSED = ("warrior", "mage", "priest", "scout", "sleeper")
CHARACTERS = CLASSED + ("walker",)
ONLINE = ("warrior", "mage", "priest", "scout", "walker")
MARKER = "grug_core:migrate:0.53.0"
LINE = "Your talent points have been reset."
TALENT_KEYS = ("grug_classes:talents", "grug_classes:respec_used",
               "grug_classes:unbroken_ready", "grug_classes:untouchable_ready")
WINDOW_PREFIX = "grug_classes:talent_ready:"
RETIRED = ("grug_abilities:cinderfall", "grug_abilities:glacial_ward",
           "grug_abilities:pinning_shot")
# What the setup stores per class (the probe's WINDOWS and the respec).
STORED = {
    "warrior": {"grug_classes:talent_ready:ruination", "grug_classes:unbroken_ready"},
    "mage": {"grug_classes:talent_ready:whitehot"},
    "sleeper": {"grug_classes:talent_ready:whitehot"},
    "priest": {"grug_classes:talent_ready:last_word"},
    "scout": {"grug_classes:untouchable_ready"},
}
FACTOR = {"warrior": 1.2, "mage": 0.8, "priest": 0.8, "scout": 1.0}
OLD_FACTOR = {"warrior": 1.2, "mage": 0.9, "priest": 1.0, "scout": 1.0}


def state(world):
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        return {name: {"inv": {k: [s.to_string() for s in v.items]
                               for k, v in api.get_inventory(name).items()},
                       "meta": api.get_meta(name)} for name in api.characters()}
    finally:
        worldmod.close_world(backends)


def talent_keys(meta):
    return {k for k, v in meta.items() if v != "" and
            (k in TALENT_KEYS or k.startswith(WINDOW_PREFIX))}


def item_name(item):
    return item.split(" ", 1)[0] if item else ""


def retired_cells(inv):
    return [(lst, i) for lst, items in inv.items() for i, item in enumerate(items)
            if item_name(item) in RETIRED]


def export_old(run):
    target = run.root / "v0_52_1"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.52.1 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def tool(run, case, world, check_mode=False):
    args = ["python3", "tools/migrate.py", "--world", str(world)] + \
        (["--check"] if check_mode else [])
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), it.IMAGE] + args
    proc = subprocess.run(cmd, capture_output=True, text=True)
    events = []
    for line in proc.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    out = run.evidence / "tool"
    out.mkdir(parents=True, exist_ok=True)
    (out / ("%s.jsonl" % case)).write_text(
        re.sub(r"/tmp/grudgelands-headless\.\w+", "<run>", proc.stdout))
    if proc.returncode not in (0, 1, 2) or not events:
        print(proc.stderr[-2000:])
    return proc.returncode, events


def keep_world(world, target, spawns):
    """The 0.52.1 world for the user's GUI test, without the probe's files.
    The probe set each classed character's identity directly, so creation
    never moved it to its race start; the copy puts it there (`spawns`: name
    -> (x, y, z), grug_core.start_position, where the arrival puts it)."""
    target = Path(target).resolve()
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(world, target, ignore=shutil.ignore_patterns(
        "r43_it_plan.json", "r43_it_obs.json"))
    backends = worldmod.open_world(str(target))
    try:
        for backend in backends.values():
            if backend.present:
                backend.begin()
        api = data.World(backends, OLD_VERSION)
        for name, pos in spawns.items():
            api.set_position(name, pos)
        for backend in backends.values():
            if backend.present:
                backend.commit()
    finally:
        worldmod.close_world(backends)
    return target


def joins_of(boot):
    return {j.get("name"): j for j in (boot.obs or {}).get("joins") or []}


def lines(entry, text=None):
    got = [c.get("text") for c in entry.get("chat") or []]
    return got if text is None else [t for t in got if t == text]


def slot_of(layout, role):
    for cell in layout or []:
        if cell.get("role") == role:
            return cell.get("list"), cell.get("slot")
    return None, None


def at(lists, where):
    lst, slot = where
    items = (lists or {}).get(lst) or []
    return items[slot - 1] if slot and slot <= len(items) else None


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S: the 0.52.1 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.52.1", joins=CHARACTERS)
    obs = s.obs or {}
    setup = joins_of(s)
    check("setup", "boot S (0.52.1): a new world, all six characters joined, were built and "
                   "left",
          s.rc == 0 and obs.get("leaves") == len(CHARACTERS) and sorted(setup) ==
          sorted(CHARACTERS) and all((setup.get(n) or {}).get("built_ok") for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s %s" % (s.rc, s.joins, json.dumps(
              [((setup.get(n) or {}).get("build") or {}).get("error") for n in CHARACTERS])))
    built = {n: (setup.get(n) or {}).get("settled") or {} for n in CHARACTERS}
    layout = {n: ((setup.get(n) or {}).get("build") or {}).get("layout") or []
              for n in CHARACTERS}
    check("setup", "0.52.1 built the five classed characters at level 30 with talents "
                   "spent, at their race start",
          all(built[n].get("class") and built[n].get("level") == 30
              and (built[n].get("spent") or 0) > 0
              and ((setup[n].get("build") or {}).get("spawn")) for n in CLASSED),
          json.dumps({n: [built[n].get("class"), built[n].get("level"), built[n].get("spent")]
                      for n in CLASSED}))
    before = state(w)
    stored_ok = all(
        before[n]["meta"].get("grug_classes:talents", "") != ""
        and before[n]["meta"].get("grug_classes:respec_used") == "1"
        and STORED[n] <= talent_keys(before[n]["meta"]) for n in CLASSED) and \
        not talent_keys(before["walker"]["meta"])
    check("setup", "0.52.1 saved the spent talents, the used respec and the stored talent "
                   "windows of every classed character (none for walker)",
          stored_ok, json.dumps({n: sorted(talent_keys(before[n]["meta"])) for n in CHARACTERS}))
    placed = {n: sorted((c["list"], c["slot"] - 1) for c in layout[n] if c.get("role") ==
                        "remove") for n in CHARACTERS}
    check("setup", "0.52.1 saved the retired skills on the shown hotbar, on the other layout "
                   "and in a bag (mage, sleeper, scout: 8 stacks)",
          all(sorted(retired_cells(before[n]["inv"])) == placed[n] for n in CHARACTERS)
          and sum(len(placed[n]) for n in CHARACTERS) == 8
          and {lst for n in CHARACTERS for lst, _ in placed[n]} ==
          {"main", "grug_hotbar_store", "grug_bag1_content"},
          json.dumps({n: retired_cells(before[n]["inv"]) for n in CHARACTERS}))
    priest_lists = built["priest"].get("lists")
    check("setup", "0.52.1 saved the Priest holding both Strike and Smite on the shown hotbar",
          at(priest_lists, slot_of(layout["priest"], "strike_a")) == "grug_abilities:strike"
          and at(priest_lists, slot_of(layout["priest"], "smite_a")) == "grug_abilities:smite")
    if os.environ.get("GUI_WORLD"):
        spawns = {}
        for n in CLASSED:
            spawn = (setup[n].get("build") or {}).get("spawn") or {}
            if all(k in spawn for k in "xyz"):
                spawns[n] = (spawn["x"], spawn["y"], spawn["z"])
        kept = keep_world(w, os.environ["GUI_WORLD"], spawns)
        print("GUI world (0.52.1, before the tool): %s" % kept, flush=True)
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % NEW_VERSION)
    check("guard", "boot R (%s): the 0.52.1 world without the tool is refused, naming the "
                   "step%s %s and the command line" % (it.GAME, "s" if len(DUE) > 1 else "",
                                                       ", ".join(DUE)),
          it.refused_with(r, "This world is at version %s and needs the migration %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, it.steps_text(DUE), it.GAME),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool.
    rc, ev = tool(run, "check_before", w, check_mode=True)
    done = it.last(ev)
    check("tool", "--check: world %s, due %s, nothing written" % (OLD_VERSION, DUE),
          rc == 0 and done.get("world_version") == OLD_VERSION
          and done.get("due") == DUE and it.dump(w) == dump_before,
          "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = tool(run, "migrate", w)
    kinds = [e.get("event") for e in ev]
    step_done = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: start, step_start and step_done per due step, done; exit 0",
          rc == 0 and kinds == ["start"] + ["step_start", "step_done"] * len(DUE) + ["done"]
          and it.last(ev).get("applied") == DUE, "exit %d %s" % (rc, kinds))
    keys = sum(len(talent_keys(before[n]["meta"])) for n in CHARACTERS)
    check("tool", "step 0.53.0: six markers, %d meta deletions, three inventories" % keys,
          step_done.get("step") == NEW_VERSION and step_done.get("counts") == {
              "characters": 6, "player_meta": keys, "inventories": 3, "positions": 0,
              "privileges": 0, "mod_storage": 0, "markers": 6}, json.dumps(step_done))
    after = state(w)
    meta_ok = all(
        after[n]["meta"].get(MARKER) == "1" and not talent_keys(after[n]["meta"])
        and {k: v for k, v in after[n]["meta"].items() if k != MARKER}
        == {k: v for k, v in before[n]["meta"].items() if k not in talent_keys(before[n]["meta"])}
        for n in CHARACTERS)
    check("step", "player meta: the talents, the used respec and every stored talent window "
                  "gone, the marker on all six, nothing else changed", meta_ok)
    inv_ok = True
    for n in CHARACTERS:
        expected = {k: list(v) for k, v in before[n]["inv"].items()}
        for lst, slot in placed[n]:
            expected[lst][slot] = ""
        inv_ok = inv_ok and after[n]["inv"] == expected
    check("step", "inventories: exactly the eight retired skills gone (hotbar, other layout, "
                  "bag), every other stack as it was", inv_ok)
    check("step", "the record is %s" % LAST,
          it.storage(w, "grug_core").get("world_version") == LAST)
    dump_after = it.dump(w)
    it.world_diff(run, "tool_0.53.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    names = "|".join(CHARACTERS)
    check("step", "nothing else changed: the characters' meta and item rows and the record",
          changed and all(re.match(r"'(meta|item)' \| '(%s)' \|" % names, line)
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = tool(run, "check_after", w, check_mode=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % LAST,
          rc == 0 and done.get("world_version") == LAST and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % NEW_VERSION, joins=ONLINE)
    obs = a.obs or {}
    joined = joins_of(a)
    registered = obs.get("registered") or {}
    check("boot", "boot A (%s): starts from %s; five characters joined with the marker and "
                  "left" % (it.GAME, LAST),
          a.rc == 0 and (obs.get("load") or {}).get("from") == LAST
          and obs.get("leaves") == len(ONLINE) and sorted(joined) == sorted(ONLINE)
          and all(((joined[n].get("loaded") or {}).get("marker")) == "1" for n in ONLINE),
          "rc %d %s %s" % (a.rc, json.dumps(obs.get("load")), a.joins))
    settled = {n: (joined.get(n) or {}).get("settled") or {} for n in ONLINE}
    check("boot", "after the join: every marker cleared",
          all(settled[n].get("marker") == "" for n in ONLINE))
    check("chat", "each classed character got \"%s\" exactly once; walker did not" % LINE,
          all(len(lines(joined[n], LINE)) == 1 for n in ONLINE if n != "walker")
          and lines(joined["walker"], LINE) == [],
          json.dumps({n: lines(joined.get(n) or {}) for n in ONLINE})[:400])
    check("chat", "nothing more: no other chat line about talents or the migration",
          not any(t != LINE and re.search(r"talent|migrat|reset", t or "", re.I)
                  for n in ONLINE for t in lines(joined[n])),
          json.dumps({n: lines(joined.get(n) or {}) for n in ONLINE})[:400])
    points = {n: (built[n].get("spent") or 0) + (built[n].get("available") or 0)
              for n in ONLINE if n != "walker"}
    check("talents", "all points free: nothing spent, the level's 15 points available",
          all(settled[n].get("spent") == 0 and settled[n].get("available") == points[n] == 15
              for n in points), json.dumps({n: [settled[n].get("spent"),
                                                 settled[n].get("available")] for n in points}))
    check("talents", "no stored talent window or used respec after the join",
          all(not (talent_keys(settled[n].get("meta") or {}) - {"grug_classes:talents"})
              for n in ONLINE),
          json.dumps({n: sorted(talent_keys(settled[n].get("meta") or {})) for n in ONLINE}))
    check("kit", "no retired skill in any list after the join",
          not any(item in RETIRED for n in ONLINE
                  for items in (settled[n].get("lists") or {}).values() for item in items or []))
    check("kit", "every skill left on either hotbar is unlocked (locked ones gone)",
          all(s.get("unlocked") for n in ONLINE for s in settled[n].get("hotbars") or []),
          json.dumps({n: [s["id"] for s in settled[n].get("hotbars") or []
                          if not s.get("unlocked")] for n in ONLINE}))
    hp_ok, hp_detail = True, {}
    for n in ("warrior", "mage", "priest", "scout"):
        hp = settled[n].get("hp") or {}
        old = built[n].get("hp") or {}
        want = int(hp.get("base", 0) * FACTOR[n] + 0.5)
        ok = abs((hp.get("factor") or 0) - FACTOR[n]) < 1e-9 and hp.get("talent") == 0 \
            and hp.get("hp_max") == hp.get("final") == want and hp.get("hp") == hp.get("hp_max")
        if FACTOR[n] < OLD_FACTOR[n]:
            ok = ok and old.get("hp_max", 0) > want and old.get("hp") == old.get("hp_max")
        hp_ok = hp_ok and ok
        hp_detail[n] = [old.get("hp"), old.get("hp_max"), hp.get("hp"), hp.get("hp_max"), want]
    check("hp", "class factors 1.2 / 0.8 / 0.8 / 1.0: the Mage's and Priest's maximum lower "
                "than at 0.52.1 and their full HP clamped to it; maximum = base pool x factor",
          hp_ok, json.dumps(hp_detail))
    mage_lists = settled["mage"].get("lists")
    if registered.get("fiery_spark"):
        swaps = [(n, role, want) for n, role, want in (
            ("mage", "strike_a", "fiery_spark"), ("mage", "strike_b", "fiery_spark"),
            ("mage", "ice_nova_a", "ice_wave"), ("mage", "ice_nova_b", "ice_wave"),
            ("priest", "smite_a", "smite"))]
        got = {(n, role): at(settled[n].get("lists"), slot_of(layout[n], role))
               for n, role, _ in swaps}
        check("kit", "the game's join swapped the Mage's Strike for Fiery Spark and Ice Nova "
                     "for Ice Wave on layout A and B; the Priest keeps Smite",
              all(got[(n, role)] == "grug_abilities:" + want for n, role, want in swaps),
              json.dumps({"%s %s" % k: v for k, v in got.items()}))
        check("kit", "the Priest's Strike slot is empty (Smite held already; Q4 accepted)",
              at(settled["priest"].get("lists"), slot_of(layout["priest"], "strike_a")) == "")
    else:
        check("kit", "before the class lanes: the Mage's Strike and Ice Nova stay on A and B",
              at(mage_lists, slot_of(layout["mage"], "strike_a")) == "grug_abilities:strike"
              and at(mage_lists, slot_of(layout["mage"], "strike_b")) == "grug_abilities:strike"
              and at(mage_lists, slot_of(layout["mage"], "ice_nova_a")) ==
              "grug_abilities:ice_nova"
              and at(mage_lists, slot_of(layout["mage"], "ice_nova_b")) ==
              "grug_abilities:ice_nova")
    final = state(w)
    check("boot", "saved after boot A: the joined characters' markers gone; sleeper "
                  "(offline) keeps its marker and its migrated inventory",
          all(MARKER not in final[n]["meta"] for n in ONLINE)
          and final["sleeper"]["meta"].get(MARKER) == "1"
          and final["sleeper"]["inv"] == after["sleeper"]["inv"])

    # Boot B: a second join changes nothing.
    b = it.boot(run, w, "again_%s" % NEW_VERSION, joins=("mage",))
    again = joins_of(b).get("mage") or {}
    check("again", "boot B: mage joins again: no chat line about the reset, the lists as boot "
                   "A left them",
          b.rc == 0 and lines(again, LINE) == [] and
          (again.get("settled") or {}).get("lists") == mage_lists, "rc %d" % b.rc)


def main(argv):
    evidence = Path(argv[0]).resolve() if argv else HERE / "evidence"
    if evidence.exists():
        subprocess.run(["rm", "-rf", "--", str(evidence)], check=True)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, checkout game %s" % (run.root, run.port, it.GAME),
          flush=True)
    failed = []
    try:
        try:
            scenario(run)
        except Exception as err:
            check("harness", "scenario", False, "%s: %s" % (type(err).__name__, err))
            raise
    finally:
        results = it.results
        table = ["%-4s  %-7s %s" % ("PASS" if ok else "FAIL", group, name)
                 for group, name, ok, _ in results]
        failed = [r for r in results if not r[2]]
        summary = "%d checks, %d failed" % (len(results), len(failed))
        text = "\n".join(table + ["", summary] + ["FAIL %s: %s" % (r[1], r[3]) for r in failed])
        (evidence / "results.txt").write_text(text + "\n")
        print("\n" + text)
        if it.os.environ.get("KEEP") == "1":
            print("kept: %s" % run.root)
        else:
            it.shutil.rmtree(run.root, ignore_errors=True)
            it.shutil.rmtree("/tmp/grudgelands-headless-failed/" + run.root.name,
                             ignore_errors=True)
    return 0 if it.results and not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
