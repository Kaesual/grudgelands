#!/usr/bin/env python3
"""Round 44 lane MS: the end-to-end test of the migration step 0.44.0
(tools/migration/steps/v0_44_0.py; contract R8, round workflow section 3
"Migration steps"). It reuses Round 43 IT's harness (tools/r43_it/it.py:
boots, the container tool runs, the database dumps and the PASS table;
client.py for the joins).

  export   the 0.43.0 commit (OLD below) through `git archive` into the run
           directory: its game and its headless launcher
  boot S   the 0.43.0 game on a new world (SQLite player, auth and mod
           storage): "rider" and "walker" join, the probe
           (grug_probe_r44_ms) builds them: rider owns riding tiers 1-2 and
           the boat and carries skills on the hotbar, in main[9..] and in a
           bag, mount items on the hotbar, in main[9..], in a bag and in the
           craft grid, between ordinary items; walker carries nothing of the
           step's. The probe also lists the 0.43.0 registrations, against
           which the step's frozen names are checked.
  boot R   this checkout's game on the 0.43.0 world without the tool:
           refused by the guard, nothing written
  tool     the shipped command line in the platform runner's environment
           (Debian trixie, python3 3.13; tools/r43_it/Containerfile):
           --check, the migration, --check again
  copy     a copy of the world migrated by step 0.44.0 alone (the tool
           in-process, pinned to the 0.44.0 checkout): the exact checks of
           the step read it, since the shipped run also runs the later
           declared steps (0.45.0 on; Round 45 lane MS)
  chain    the shipped run crosses 0.44.0 and 0.45.0 at once; a second copy
           without a record (0.41.0, the production server's version) gets
           the same rows from one in-process run of this checkout's tool
  boot A   this checkout's game on the migrated world: rider and walker join
           again; the probe records the inventory as loaded (before
           grug_core's runner) and as the game's join left it, and the owned
           mounts
Every database row the step could change is compared before and after.

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r44_ms/evidence) and exits 0 only when
every check passed.

Usage: tools/r44_ms/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import io
import json
from collections import Counter
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)
from migration import cli, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402

STEP = cli._load_step("0.44.0", cli.STEPS / "v0_44_0.py")
OLD = "9dc2fad5"           # main at 0.43.0, pushed (origin/main)
OLD_VERSION = "0.43.0"
GAME = it.GAME
DECLARED = json.loads((REPO / "tools" / "web_data" / "upgrade.json").read_text())["migrate"]
DUE = [v for v in DECLARED if cli.parse_version(v) > cli.parse_version(OLD_VERSION)]
PROBE = HERE / "grug_probe_r44_ms"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r44_ms_probe\]")
check = it.check


# -- reading the world (the server stopped) ----------------------------------

def state(world):
    """Every character's inventory (list -> [item strings]) and player meta,
    read through the tool's data API."""
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        out = {}
        for name in api.characters():
            out[name] = {
                "inv": {k: [s.to_string() for s in v.items]
                        for k, v in api.get_inventory(name).items()},
                "meta": api.get_meta(name),
            }
        return out
    finally:
        worldmod.close_world(backends)


def name_of(text):
    return ItemStack.parse(text).name if text else ""


def offenders(inv):
    """(list, 1-based slot, item) of every stack the 0.44.0 rules forbid."""
    out = []
    for listname, stacks in inv.items():
        for i, text in enumerate(stacks):
            name = name_of(text)
            if name in STEP.MOUNT_ITEMS or (name.startswith(STEP.SKILL_PREFIX) and not (
                    listname == "main" and i < STEP.HOTBAR)):
                out.append((listname, i + 1, name))
    return out


def same(a, b):
    """Two item strings hold the same stack."""
    if not a or not b:
        return (a or "") == (b or "")
    x, y = ItemStack.parse(a), ItemStack.parse(b)
    return (x.name, x.count, x.wear, x.meta) == (y.name, y.count, y.wear, y.meta)


def same_lists(a, b, lists=None):
    names = lists if lists is not None else sorted(set(a) | set(b))
    bad = []
    for listname in names:
        x, y = a.get(listname, []), b.get(listname, [])
        if len(x) != len(y):
            bad.append("%s: size %d vs %d" % (listname, len(x), len(y)))
            continue
        bad += ["%s[%d]: %r vs %r" % (listname, i + 1, p[:60], q[:60])
                for i, (p, q) in enumerate(zip(x, y)) if not same(p, q)]
    return bad


def probe_lists(observed):
    return {k: v.get("stacks") or [] for k, v in (observed or {}).items()}


def step_only(run, w):
    """A copy of the world migrated by step 0.44.0 alone: the tool in-process,
    pinned to the 0.44.0 checkout (game.conf 0.44.0, the declaration's
    migrate list ["0.44.0"]), as tools/r44_ms/test_step.py runs it. The later
    declared steps (0.45.0 on) run in the shipped run too, so this copy is
    what the exact checks of step 0.44.0 read (Round 45 lane MS)."""
    copy = run.work / "w_0.44.0_only"
    it.snapshot(w, copy)
    conf, decl = run.work / "game_0.44.0.conf", run.work / "upgrade_0.44.0.json"
    conf.write_text("version = 0.44.0\n")
    decl.write_text(json.dumps({"schema": 2, "version": "0.44.0", "map_reset": ["0.40.1"],
                                "new_server": [], "migrate": ["0.44.0"]}))
    saved = cli.GAME_CONF, cli.DECLARATION
    cli.GAME_CONF, cli.DECLARATION = conf, decl
    out, err = io.StringIO(), io.StringIO()
    try:
        rc = cli.main(["--world", str(copy)], stdout=out, stderr=err)
    finally:
        cli.GAME_CONF, cli.DECLARATION = saved
    events = [json.loads(line) for line in out.getvalue().splitlines()]
    return rc, events, copy


# -- the scenario -------------------------------------------------------------

def export_old(run):
    target = run.root / "v0_43_0"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.43.0 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S: the 0.43.0 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.43.0", joins=("rider", "walker"))
    obs = s.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    rider_layout = (joins.get("rider") or {}).get("layout") or {}
    walker_layout = (joins.get("walker") or {}).get("layout") or {}
    check("setup", "boot S (0.43.0): a new world, rider and walker joined, were built and left",
          s.rc == 0 and obs.get("leaves") == 2 and sorted(joins) == ["rider", "walker"]
          and rider_layout.get("entries") and walker_layout.get("entries")
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s layout %s" % (s.rc, s.joins, json.dumps(
              [rider_layout.get("error"), walker_layout.get("error")])))
    if not rider_layout.get("entries"):
        return

    reg = obs.get("registrations") or {}
    groups, prefixed = reg.get("groups") or {}, reg.get("prefixed") or {}
    abilities, mounts = set(groups.get("grug_ability", [])), set(groups.get("grug_mount", []))
    check("names", "0.43.0: the items in group grug_mount are the step's six mount items",
          mounts == set(STEP.MOUNT_ITEMS), json.dumps(sorted(mounts)))
    check("names", "0.43.0: the items under grug_mounts: are those six too",
          set(prefixed.get("grug_mounts:", [])) == set(STEP.MOUNT_ITEMS),
          json.dumps(prefixed.get("grug_mounts:")))
    check("names", "0.43.0: group grug_ability is exactly the items under grug_abilities: "
                   "(the step's skill rule)",
          abilities and abilities == set(prefixed.get("grug_abilities:", [])),
          "%d in the group, %d by name" % (len(abilities),
                                           len(prefixed.get("grug_abilities:", []))))
    check("names", "0.43.0: group grug_bound_skill is skills plus mount items, no alias "
                   "under either prefix",
          set(groups.get("grug_bound_skill", [])) == abilities | mounts
          and not reg.get("aliases"), json.dumps(reg.get("aliases")))
    check("names", "0.43.0: the hotbar has the step's %d slots" % STEP.HOTBAR,
          (joins.get("rider") or {}).get("hotbar_itemcount") == STEP.HOTBAR,
          str((joins.get("rider") or {}).get("hotbar_itemcount")))

    before = state(w)
    rider = before.get("rider", {}).get("inv", {})
    entries = rider_layout["entries"]
    misplaced = ["%s[%d] %s" % (e["list"], e["slot"], e["item"]) for e in entries
                 if name_of((rider.get(e["list"]) or [""] * e["slot"])[e["slot"] - 1])
                 != e["item"]]
    removes = [e for e in entries if e["role"] == "remove"]
    lists = sorted({e["list"] for e in removes})
    check("setup", "saved: rider carries every placed stack (%d to remove, in %s)"
          % (len(removes), ", ".join(lists)),
          not misplaced and "main" in lists and "craft" in lists
          and "grug_bag1_content" in lists, json.dumps(misplaced))
    check("setup", "saved: rider owns riding tiers 1-2 and the boat (purchase record)",
          before["rider"]["meta"].get("grug_mounts:land_tier") == "2"
          and before["rider"]["meta"].get("grug_mounts:water_tier") == "5")
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % GAME)
    names = ", ".join(DUE)
    check("guard", "boot R (%s): the 0.43.0 world without the tool is refused, naming the "
                   "step and the command line" % GAME,
          it.refused_with(r, "This world is at version %s and needs the migration step%s %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, "s" if len(DUE) > 1 else "", names, GAME),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool, as the platform runs it.
    rc, ev = it.tool(run, "check_before", w, "-", check_mode=True, shipped=True)
    done = it.last(ev)
    check("tool", "--check: world %s, due %s, write access on all three backends, nothing "
                  "written" % (OLD_VERSION, names),
          rc == 0 and done.get("world_version") == OLD_VERSION and done.get("due") == DUE
          and done.get("write_checked") == ["player", "auth", "mod_storage"]
          and it.dump(w) == dump_before, "exit %d %s" % (rc, json.dumps(done)))
    rc44, ev44, w44 = step_only(run, w)
    # The production path: a world without a record (0.41.0) on a copy,
    # the whole chain in one run of this checkout's tool (in-process).
    w41 = run.work / "w_from_0.41.0"
    it.snapshot(w, w41)
    it.set_record(w41, None)
    out41 = io.StringIO()
    rc41 = cli.main(["--world", str(w41)], stdout=out41, stderr=io.StringIO())
    ev41 = [json.loads(line) for line in out41.getvalue().splitlines()]
    only = next((e for e in ev44 if e.get("event") == "step_done"), {})
    check("tool", "step 0.44.0 alone (the tool pinned to the 0.44.0 checkout, on a copy): "
                  "exit 0, the copy at 0.44.0",
          rc44 == 0 and it.last(ev44).get("applied") == ["0.44.0"]
          and it.storage(w44, "grug_core").get("world_version") == "0.44.0",
          "exit %d %s" % (rc44, json.dumps(it.last(ev44))))
    rc, ev = it.tool(run, "migrate", w, "-", shipped=True)
    kinds = [e.get("event") for e in ev]
    first = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: the events start, step_start/step_done per due step, done; exit 0",
          rc == 0 and kinds == ["start"] + ["step_start", "step_done"] * len(DUE) + ["done"]
          and it.last(ev).get("applied") == DUE
          and next(e for e in ev if e.get("event") == "step_start").get("from") == OLD_VERSION,
          "exit %d %s" % (rc, kinds))
    check("tool", "step 0.44.0 wrote one character's inventory and nothing else",
          first.get("step") == "0.44.0" and first.get("counts") == {
              "characters": 1, "player_meta": 0, "inventories": 1, "positions": 0,
              "privileges": 0, "mod_storage": 0, "markers": 0}
          and only.get("counts") == first.get("counts"), json.dumps([first, only]))
    check("tool", "the record is %s" % DUE[-1],
          it.storage(w, "grug_core").get("world_version") == DUE[-1])
    applied = it.last(ev).get("applied") or []
    chain = state(w)
    rider_gear = [t for stacks in chain.get("rider", {}).get("inv", {}).values() for t in stacks
                  if name_of(t).startswith("grug_gear:") and name_of(t) != "grug_gear:arrow"]
    check("chain", "the 0.43.0 world crosses 0.44.0 and 0.45.0 in one shipped run: 0.45.0's "
                   "marker on both characters, rider's grid stored empty with size 0, its "
                   "gear pinned",
          applied[:2] == ["0.44.0", "0.45.0"]
          and all(chain[n]["meta"].get("grug_core:migrate:0.45.0") == "1"
                  for n in ("rider", "walker"))
          and chain["rider"]["inv"].get("craft") == []
          and rider_gear and all(ItemStack.parse(t).meta.get("grug_ilvl") for t in rider_gear),
          json.dumps({"applied": applied, "gear": [t[:50] for t in rider_gear]}))
    check("chain", "a copy without a record (0.41.0, the production server's version): one "
                   "run of this checkout's tool applies 0.44.0 and 0.45.0 from 0.41.0 and leaves "
                   "the same rows as the shipped run from 0.43.0",
          rc41 == 0 and it.last(ev41).get("applied")[:2] == ["0.44.0", "0.45.0"]
          and next(e for e in ev41 if e.get("event") == "step_start").get("from") == "0.41.0"
          and it.dump(w41) == it.dump(w),
          "exit %d %s" % (rc41, json.dumps(it.last(ev41))))
    after = state(w)
    after44 = state(w44)
    expected = {k: list(v) for k, v in rider.items()}
    for e in removes:
        expected[e["list"]][e["slot"] - 1] = ""
    got44 = after44.get("rider", {}).get("inv", {})
    got = after.get("rider", {}).get("inv", {})
    check("step", "rider (0.44.0 alone): exactly the %d placed stacks to remove are gone, every "
                  "other slot of every list unchanged" % len(removes),
          not same_lists(expected, got44), json.dumps(same_lists(expected, got44)[:6]))
    check("step", "rider (0.44.0 alone, and after every due step): no mount item in any list, "
                  "no skill outside main[1..8]",
          not offenders(got44) and not offenders(got) and offenders(rider),
          json.dumps([offenders(got44), offenders(got)]))
    check("step", "rider and walker (0.44.0 alone): player meta unchanged (the purchase record "
                  "kept)", all(after44[n]["meta"] == before[n]["meta"] for n in ("rider", "walker")))
    check("step", "rider and walker after every due step: the purchase record kept",
          all(after[n]["meta"].get(k) == before[n]["meta"].get(k) for n in ("rider", "walker")
              for k in ("grug_mounts:land_tier", "grug_mounts:water_tier")))
    dump_after = it.dump(w44)
    it.world_diff(run, "tool_0.44.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    check("step", "0.44.0 alone changed nothing else: only rider's item rows and the record "
                  "(walker's rows, positions, auth, other mod storage untouched)",
          changed and all(line.startswith("'item' | 'rider' |")
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = it.tool(run, "check_after", w, "-", check_mode=True, shipped=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % DUE[-1],
          rc == 0 and done.get("world_version") == DUE[-1] and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % GAME, joins=("rider", "walker"))
    obs = a.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    load = obs.get("load") or {}
    check("boot", "boot A (%s): starts from %s with nothing due; rider and walker joined and "
                  "left" % (GAME, DUE[-1]),
          a.rc == 0 and load.get("from") == DUE[-1] and load.get("new_world") is False
          and obs.get("leaves") == 2 and sorted(joins) == ["rider", "walker"]
          and it.storage(w, "grug_core").get("world_version") == GAME,
          "rc %d load %s joins %s" % (a.rc, json.dumps(load), a.joins))
    hero = joins.get("rider") or {}
    loaded = probe_lists(hero.get("loaded"))
    check("boot", "rider's join: the engine loaded the migrated inventory",
          not same_lists(got, loaded, sorted(got)), json.dumps(same_lists(got, loaded,
                                                                          sorted(got))[:6]))
    settled = probe_lists(hero.get("settled"))
    keeps = [e for e in entries if e["role"] == "keep"]
    # Every stack held after the join (name, count, wear): a later declared
    # step may move a kept stack (0.45.0 empties the craft grid).
    held = Counter()
    for stacks in settled.values():
        for text in stacks:
            if text:
                x = ItemStack.parse(text)
                held[(x.name, x.count, x.wear)] += 1
    lost = []
    for e in keeps:
        # The join refreshes a skill's meta and a tool's description; the
        # loaded check above compares every stack in full.
        if e["item"].startswith(STEP.SKILL_PREFIX):
            text = (settled.get(e["list"]) or [""] * e["slot"])[e["slot"] - 1]
            ok = name_of(text) == e["item"]
        else:
            y = ItemStack.parse(got44[e["list"]][e["slot"] - 1])
            ok = held[(y.name, y.count, y.wear)] > 0
            held[(y.name, y.count, y.wear)] -= 1
            text = y.to_string()
        if not ok:
            lost.append("%s[%d] %s: %r" % (e["list"], e["slot"], e["item"], text[:60]))
    check("boot", "rider after the game's join: no mount item, no skill outside the hotbar; "
                  "the hotbar skills in place and every other kept stack held (name, count, "
                  "wear)",
          settled and not offenders(settled) and not lost,
          json.dumps({"offenders": offenders(settled), "lost": lost}))
    owned = hero.get("mounts") or {}
    check("boot", "rider's mounts in the quickbar: owned tiers 1, 2 and 5 from the purchase "
                  "record, one quickbar button each",
          owned.get("owned") == [1, 2, 5] and owned.get("quickbar") == [1, 2, 5],
          json.dumps(owned))
    walker = joins.get("walker") or {}
    wl = probe_lists(walker.get("settled"))
    check("boot", "walker after the game's join: its hotbar skill and its apple in place",
          name_of((wl.get("main") or [""])[0]) == "grug_abilities:strike"
          and same((wl.get("main") or [""] * 9)[8], after["walker"]["inv"]["main"][8]),
          json.dumps((wl.get("main") or [])[:9]))
    reg = obs.get("registrations") or {}
    groups = reg.get("groups") or {}
    check("names", "%s: every item in group grug_ability is still under grug_abilities: "
                   "(the hotbar skills the step keeps are the game's skills)" % GAME,
          groups.get("grug_ability") and all(n.startswith(STEP.SKILL_PREFIX)
                                             for n in groups["grug_ability"])
          and reg.get("hotbar_size") == STEP.HOTBAR,
          json.dumps({"hotbar_size": reg.get("hotbar_size")}))
    final = state(w)
    check("chain", "saved after boot A: the 0.45.0 join part ran for both (markers gone)",
          all("grug_core:migrate:0.45.0" not in final[n]["meta"] for n in ("rider", "walker")))
    check("boot", "saved after boot A: no mount item and no skill outside the hotbar for "
                  "either character",
          not any(offenders(final[n]["inv"]) for n in ("rider", "walker")),
          json.dumps({n: offenders(final[n]["inv"]) for n in final}))


def main(argv):
    evidence = Path(argv[0]).resolve() if argv else HERE / "evidence"
    if evidence.exists():
        subprocess.run(["rm", "-rf", "--", str(evidence)], check=True)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, game %s, due %s" % (run.root, run.port, GAME, DUE),
          flush=True)
    try:
        try:
            scenario(run)
        except Exception as err:
            check("harness", "scenario", False, "%s: %s" % (type(err).__name__, err))
            raise
    finally:
        results = it.results
        table = ["%-4s  %-6s %s" % ("PASS" if ok else "FAIL", group, name)
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
