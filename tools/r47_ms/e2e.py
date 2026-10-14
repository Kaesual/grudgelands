#!/usr/bin/env python3
"""Round 47 lane OR: the end-to-end test of the migration step 0.47.0
(tools/migration/steps/v0_47_0.py and its join part in
grug_core/migrations.lua; contract R8, round workflow section 3 "Migration
steps"). It reuses Round 43 IT's harness (tools/r43_it/it.py: boots, the
database dumps and the PASS table; client.py for the joins).

  export   the 0.45.1 commit (OLD below, origin/main: the production
           server's version) through `git archive`: its game and launcher
  boot S   the 0.45.1 game on a new world (SQLite player, auth and mod
           storage): "miner" and "sleeper" join and the probe
           (grug_probe_r47_ms) builds them with crafted, broken and plain
           gathering tools in every kind of player list (see its header)
  boot R   this checkout's game on the 0.45.1 world without the tool:
           refused by the guard naming the step 0.47.0, nothing written
  tool     the tool in the platform runner's environment (Debian trixie,
           python3 3.13; tools/r43_it/Containerfile): --check, the
           migration, --check again; only the markers and the record change
  boot A   this checkout's game on the migrated world: miner joins (sleeper
           stays offline); the probe records every tool as loaded (before
           grug_core's runner: the old copies, an Iron pick that cannot dig
           T2 rock) and as the join left it (every copy rebuilt as a craft
           now makes it, the old dig times kept)

Before lane D declares 0.47.0 (tools/web_data/upgrade.json and game.conf),
the new game runs as 0.47.0 through a disposable patch of the staged
game.conf and the tool through tools/r47_ms/tool_run.py with that
declaration ("pre-declaration" in the output); once both are in the
checkout, the shipped tools/migrate.py and the unpatched game run.

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r47_ms/evidence) and exits 0 only when
every check passed.

Usage: tools/r47_ms/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import difflib
import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)
from migration import data, world as worldmod  # noqa: E402

OLD = "0e6b3061"           # origin/main at 0.45.1, what production runs
OLD_VERSION = "0.45.1"
NEW_VERSION = "0.47.0"
DECLARATION = json.loads((REPO / "tools" / "web_data" / "upgrade.json").read_text())
PRE = it.GAME != NEW_VERSION or NEW_VERSION not in DECLARATION["migrate"]
PROBE = HERE / "grug_probe_r47_ms"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r47_ms_probe\]")
check = it.check
CHARACTERS = ("miner", "sleeper")
MARKER = "grug_core:migrate:0.47.0"
# The old scale's dig time of an Iron pick on Stone (Round 46: 0.425 s).
IRON_ON_STONE = 0.425


def state(world):
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        return {name: {"inv": {k: [s.to_string() for s in v.items]
                               for k, v in api.get_inventory(name).items()},
                       "meta": api.get_meta(name)} for name in api.characters()}
    finally:
        worldmod.close_world(backends)


def export_old(run):
    target = run.root / "v0_45_1"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.45.1 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def pre_declaration(run):
    """The 0.47.0 declaration and a game.conf patch for the staged new game."""
    folder = run.root / "declaration"
    folder.mkdir()
    (folder / "game.conf").write_text("version = %s\n" % NEW_VERSION)
    decl = dict(DECLARATION, version=NEW_VERSION,
                migrate=DECLARATION["migrate"] + [NEW_VERSION],
                map_reset=DECLARATION["map_reset"] + [NEW_VERSION])
    (folder / "upgrade.json").write_text(json.dumps(decl))
    conf = (REPO / "game.conf").read_text().splitlines(keepends=True)
    bumped = [re.sub(r"^version\s*=.*", "version = " + NEW_VERSION, line) for line in conf]
    patch = run.work / "patch_version.diff"
    patch.write_text("".join(difflib.unified_diff(conf, bumped, "a/game.conf", "b/game.conf")))
    run.patches["hook"] = patch
    return folder


def tool(run, case, world, folder, check_mode=False):
    args = ["python3", "tools/r47_ms/tool_run.py", str(folder)] if folder else \
        ["python3", "tools/migrate.py"]
    args += ["--world", str(world)] + (["--check"] if check_mode else [])
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


def near(value, wanted):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and \
        abs(value - wanted) < 0.001


def tool_at(entry, slot):
    return ((entry or {}).get("tools") or {}).get(slot) or {}


MINER = {  # slot -> (item, new maxlevel, digs Iron Ore under the new scale)
    "main[1]": ("grug_materials:pick_iron", 2, True),
    "main[2]": ("grug_materials:pick_bronze", 1, True),
    "main[3]": ("grug_materials:pick_wood", 0, False),
    "main[10]": ("grug_materials:axe_steel", None, False),
    "main[11]": ("grug_materials:pick_iron", 2, True),
    "grug_bag1_content[2]": ("grug_materials:pick_iron", 2, True),
    "grug_craft_out[1]": ("grug_materials:pick_bronze", 1, True),
}


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)
    folder = pre_declaration(run) if PRE else None
    known = [] if PRE else None
    print("mode: %s" % ("pre-declaration (game.conf patched to %s, the tool with the "
                        "0.47.0 declaration)" % NEW_VERSION if PRE else "declared"), flush=True)

    # Boot S: the 0.45.1 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.45.1", joins=CHARACTERS)
    obs = s.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    check("setup", "boot S (0.45.1): a new world, miner and sleeper joined, were built and left",
          s.rc == 0 and obs.get("leaves") == 2 and sorted(joins) == sorted(CHARACTERS)
          and all((joins.get(n) or {}).get("built_ok") for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s %s" % (s.rc, s.joins, json.dumps(
              [(joins.get(n) or {}).get("build_error") for n in CHARACTERS])))
    built = (joins.get("miner") or {}).get("settled") or {}
    iron = tool_at(built, "main[1]")
    check("setup", "0.45.1: a crafted Iron pick stores its copy (maxlevel 1), digs T2 rock "
                   "and Stone in %.3f s" % IRON_ON_STONE,
          iron.get("stored") and iron.get("maxlevel") == 1 and iron.get("dig", {}).get("t2_stone")
          and near(iron.get("dig", {}).get("stone"), IRON_ON_STONE), json.dumps(iron))
    stored = [slot for slot in MINER if tool_at(built, slot).get("stored")
              or tool_at(built, slot).get("kept")]
    check("setup", "0.45.1: every crafted tool carries a copy, the broken one the repair's "
                   "(%d stacks), the plain Stone pick none" % len(MINER),
          sorted(stored) == sorted(MINER) and tool_at(built, "main[11]").get("kept")
          and tool_at(built, "main[11]").get("wear") == 65535
          and not tool_at(built, "main[12]").get("stored"), json.dumps(stored))
    before = state(w)
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % NEW_VERSION, known=known)
    check("guard", "boot R (%s): the 0.45.1 world without the tool is refused, naming the "
                   "step 0.47.0 and the command line" % NEW_VERSION,
          it.refused_with(r, "This world is at version %s and needs the migration step %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, NEW_VERSION, NEW_VERSION),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool.
    rc, ev = tool(run, "check_before", w, folder, check_mode=True)
    done = it.last(ev)
    check("tool", "--check: world %s, due [%s], nothing written" % (OLD_VERSION, NEW_VERSION),
          rc == 0 and done.get("world_version") == OLD_VERSION
          and done.get("due") == [NEW_VERSION] and it.dump(w) == dump_before,
          "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = tool(run, "migrate", w, folder)
    kinds = [e.get("event") for e in ev]
    step_done = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: start, step_start, step_done, done; exit 0",
          rc == 0 and kinds == ["start", "step_start", "step_done", "done"]
          and it.last(ev).get("applied") == [NEW_VERSION], "exit %d %s" % (rc, kinds))
    check("tool", "step 0.47.0 wrote two markers and nothing else",
          step_done.get("step") == NEW_VERSION and step_done.get("counts") == {
              "characters": 2, "player_meta": 0, "inventories": 0, "positions": 0,
              "privileges": 0, "mod_storage": 0, "markers": 2}, json.dumps(step_done))
    after = state(w)
    check("step", "both characters carry the marker; inventories and the other meta "
                  "unchanged; the record is %s" % NEW_VERSION,
          all(after[n]["meta"].get(MARKER) == "1" and after[n]["inv"] == before[n]["inv"]
              and {k: v for k, v in after[n]["meta"].items() if k != MARKER}
              == before[n]["meta"] for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == NEW_VERSION)
    dump_after = it.dump(w)
    it.world_diff(run, "tool_0.47.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    check("step", "nothing else changed: the two meta rows and the record",
          changed and all(re.match(r"'meta' \| '(miner|sleeper)' \|", line)
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = tool(run, "check_after", w, folder, check_mode=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % NEW_VERSION,
          rc == 0 and done.get("world_version") == NEW_VERSION and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % NEW_VERSION, known=known, joins=("miner",))
    obs = a.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    miner = joins.get("miner") or {}
    loaded, settled = miner.get("loaded") or {}, miner.get("settled") or {}
    check("boot", "boot A (%s): starts from %s; miner joined with the marker and left"
          % (NEW_VERSION, NEW_VERSION),
          a.rc == 0 and (obs.get("load") or {}).get("from") == NEW_VERSION
          and obs.get("leaves") == 1 and loaded.get("marker") == "1",
          "rc %d %s %s" % (a.rc, json.dumps(obs.get("load")), a.joins))
    old_iron = tool_at(loaded, "main[1]")
    check("boot", "as loaded (before the runner): the old copy (maxlevel 1) cannot dig T2 "
                  "rock (level 2 now): what the step repairs",
          old_iron.get("maxlevel") == 1 and old_iron.get("dig", {}).get("t2_stone") is False,
          json.dumps(old_iron))
    bad = []
    # Round 47 CR: the crafting overflow (grug_craft_out) moves into the
    # inventory when there is room, at the join too, so the output area's
    # rebuilt pick is found in the one slot that holds a tool only after it.
    moved = [k for k in (settled.get("tools") or {}) if k not in (loaded.get("tools") or {})]
    for slot, (item, maxlevel, iron_ore) in MINER.items():
        f = tool_at(settled, slot)
        if slot.startswith("grug_craft_out[") and not f and len(moved) == 1:
            f = tool_at(settled, moved[0])
        if f.get("item") != item or not f.get("as_crafted_now") or not f.get("definition") or \
                (maxlevel is not None and f.get("maxlevel") != maxlevel) or \
                bool(f.get("dig", {}).get("iron_ore")) != iron_ore:
            bad.append("%s %s" % (slot, json.dumps(f)[:200]))
    check("boot", "after the join: every stored copy rebuilt as a craft makes it now "
                  "(the new maxlevels; Iron Ore by Bronze and Iron, not by Wood), in main, "
                  "the hotbar, the bag and the output area", not bad, json.dumps(bad[:4]))
    iron = tool_at(settled, "main[1]")
    check("boot", "after the join: the Iron pick digs T2 rock again and Stone in %.3f s, as "
                  "before the step" % IRON_ON_STONE,
          iron.get("dig", {}).get("t2_stone") and near(iron.get("dig", {}).get("stone"),
                                                       IRON_ON_STONE), json.dumps(iron))
    broken = tool_at(settled, "main[11]")
    check("boot", "the broken Iron pick stays broken; its repair copy is the new one",
          broken.get("wear") == 65535 and broken.get("kept") and broken.get("maxlevel") == 2
          and broken.get("as_crafted_now"), json.dumps(broken))
    plain = tool_at(settled, "main[12]")
    check("boot", "the plain Stone pick gets no copy and, like every Stone pick now, does not "
                  "dig Iron Ore", plain.get("stored") is False and plain.get("kept") is False
          and plain.get("dig", {}).get("iron_ore") is False, json.dumps(plain))
    sword_then, sword_now = tool_at(loaded, "main[13]"), tool_at(settled, "main[13]")
    check("boot", "the crafted Iron Sword's capabilities are not touched",
          sword_then.get("stored") and sword_then.get("caps_text") == sword_now.get("caps_text"))
    check("boot", "the marker is cleared at the join", settled.get("marker") == "")
    final = state(w)
    check("boot", "saved after boot A: miner's marker gone; sleeper (offline) keeps its marker "
                  "and its inventory",
          MARKER not in final["miner"]["meta"] and final["sleeper"]["meta"].get(MARKER) == "1"
          and final["sleeper"]["inv"] == after["sleeper"]["inv"])


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
        table = ["%-4s  %-6s %s" % ("PASS" if ok else "FAIL", group, name)
                 for group, name, ok, _ in results]
        failed = [r for r in results if not r[2]]
        summary = "%d checks, %d failed (%s)" % (len(results), len(failed),
                                                 "pre-declaration" if PRE else "declared")
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
