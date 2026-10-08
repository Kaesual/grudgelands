#!/usr/bin/env python3
"""Round 43 lane IT: the world-migration path end to end (the platform's
migration contract R1 and R8; docs/planning/round43-plan.md section 4.3).

Real engine boots (tools/luanti_headless.sh, the probe grug_probe_r43_it),
real joins (client.py), the tool where the platform runs it (Debian trixie's
python3 in the container localhost/grudgelands-r43-it:trixie, tool_run.py
with the test steps of steps.py), and the game's test hook naming the same
steps (grug_test_migrations.lua, setting grug_test_migrations = true through
a disposable patch of the staged game). One run directory
/tmp/grudgelands-headless.*, removed at the end (KEEP=1 keeps it).

World 1 (SQLite player, auth and mod storage):
  genesis  world.mt without mod storage; the engine's --migrate-mod-storage
           sqlite3 creates the empty mod_storage.sqlite (and sets the key):
           the tool calls the world new and writes nothing
  boot A   a new world (steps known): stamped at once; "hero" and
           "bystander" join for the first time (characters, auth)
  then     the record is deleted: a world from before 0.43 (0.41.0)
  boot B   steps 0.41.1-0.41.4 lie between: refused, nothing written
  tool     --check, then the four steps (offline writes, world marker, two
           character markers for hero)
  boot C   the world marker at load, hero's two markers in step order at
           its join, bystander untouched, the record bumped to the game's
  reset    the record set to 0.41.4, map.sqlite deleted, the tool runs step
           0.41.5, grug_reset_world raised
  boot J   the map reset and the step's world part after the clears
World 2 (no character ever joins):
  boot D   a new world, stamped; then the record is deleted
  tool     --check: existing (0.41.0), step 0.41.1 due
  boot E   refused (an existing world, not a new one)
  tool     step 0.41.1; boot F starts and bumps the record
  boot G   a record newer than the game (its next minor version): refused;
           the tool refuses too
  boot H   a malformed record: refused; the tool refuses too
PostgreSQL: pg_test.py in the container, on world 1's rows before and after
its tool run.

Prints a PASS/FAIL table, writes it with trimmed evidence to the evidence
directory and exits 0 only when every check passed.

Usage: python3 tools/r43_it/it.py EVIDENCE_DIR   (run.sh; through the
round's process queue, one slot: engine boots and containers run one at a
time)
"""

import difflib
import json
import os
import re
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(HERE)]

import client  # noqa: E402
import steps as it_steps  # noqa: E402
from migration.codec import ItemStack  # noqa: E402

LAUNCHER = REPO / "tools" / "luanti_headless.sh"
PROBE = HERE / "grug_probe_r43_it"
IMAGE = "localhost/grudgelands-r43-it:trixie"
BOOT_TIMEOUT = 290
DUE4 = ["0.41.1", "0.41.2", "0.41.3", "0.41.4"]
ALL5 = DUE4 + ["0.41.5"]
GAME = re.search(r"^version\s*=\s*(\S+)", (REPO / "game.conf").read_text(), re.M).group(1)

results = []


class Run:
    def __init__(self, evidence):
        self.evidence = evidence
        self.root = Path(tempfile.mkdtemp(prefix="grudgelands-headless.", dir="/tmp"))
        self.work = self.root / "work"
        self.work.mkdir()
        self.port = free_port()
        self.patches = {}


def check(group, name, ok, detail=""):
    results.append((group, name, bool(ok), detail))
    print("%s  [%s] %s%s" % ("PASS" if ok else "FAIL", group, name,
                             (" -- " + detail) if detail and not ok else ""), flush=True)
    return ok


def free_port():
    for _ in range(50):
        port = 30000 + int.from_bytes(os.urandom(2), "big") % 10000
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise RuntimeError("no free UDP port")


# -- worlds and databases -------------------------------------------------

def write_world_mt(world, mod_storage):
    lines = ["gameid = grudgelands", "backend = sqlite3", "player_backend = sqlite3",
             "auth_backend = sqlite3"]
    if mod_storage:
        lines.append("mod_storage_backend = sqlite3")
    world.mkdir(parents=True, exist_ok=True)
    (world / "world.mt").write_text("\n".join(lines) + "\n")


def db(world, name, write=False):
    path = world / name
    if not path.exists():
        return None
    uri = path.as_uri() + ("?mode=rw" if write else "?mode=ro")
    conn = sqlite3.connect(uri, uri=True, isolation_level=None)
    conn.text_factory = bytes
    return conn


def _s(value):
    return value.decode("utf-8", "surrogateescape") if isinstance(value, bytes) else value


def storage(world, mod):
    conn = db(world, "mod_storage.sqlite")
    if conn is None:
        return {}
    with conn:
        return {_s(k): _s(v) for k, v in conn.execute(
            "SELECT key, value FROM entries WHERE modname = ?", (mod,))}


def set_record(world, value):
    """Test setup with the server stopped: the world at an earlier version
    (None deletes the record: a world from before 0.43)."""
    conn = db(world, "mod_storage.sqlite", write=True)
    with conn:
        conn.execute("DELETE FROM entries WHERE modname = 'grug_core' AND key = ?",
                     (b"world_version",))
        if value is not None:
            conn.execute("INSERT INTO entries VALUES ('grug_core', ?, ?)",
                         (b"world_version", value.encode()))
    conn.close()


def player_meta(world, name):
    conn = db(world, "players.sqlite")
    if conn is None:
        return {}
    with conn:
        return {_s(k): _s(v) for k, v in conn.execute(
            "SELECT metadata, value FROM player_metadata WHERE player = ?", (name,))}


def characters(world):
    conn = db(world, "players.sqlite")
    if conn is None:
        return []
    with conn:
        return sorted(_s(r[0]) for r in conn.execute("SELECT name FROM player"))


def main_slot(world, name, slot=0):
    conn = db(world, "players.sqlite")
    with conn:
        row = conn.execute(
            "SELECT i.item FROM player_inventory_items i JOIN player_inventories l "
            "ON l.player = i.player AND l.inv_id = i.inv_id "
            "WHERE i.player = ? AND l.inv_name = 'main' AND i.slot_id = ?",
            (name, slot)).fetchone()
    return _s(row[0]) if row else None


def privileges(world, name):
    conn = db(world, "auth.sqlite")
    with conn:
        return sorted(_s(r[0]) for r in conn.execute(
            "SELECT p.privilege FROM user_privileges p JOIN auth a ON a.id = p.id "
            "WHERE a.name = ?", (name,)))


def dump(world):
    """Every row a step or the game can change, one line each (long values
    cut): the world diffs of the evidence and the 'nothing written' checks."""
    lines = []

    def cut(value):
        text = repr(_s(value))
        return text if len(text) <= 90 else text[:80] + "...(%d)" % len(text)

    for name, query in (
            ("mod_storage.sqlite", "SELECT 'storage', modname, key, value FROM entries"),
            ("players.sqlite", "SELECT 'player', name, posX || ',' || posY || ',' || posZ, "
                               "hp FROM player"),
            ("players.sqlite", "SELECT 'meta', player, metadata, value FROM player_metadata"),
            ("players.sqlite", "SELECT 'item', player, inv_id || ':' || slot_id, item "
                               "FROM player_inventory_items WHERE item != ''"),
            ("auth.sqlite", "SELECT 'auth', a.name, a.password, p.privilege FROM auth a "
                            "LEFT JOIN user_privileges p ON p.id = a.id")):
        conn = db(world, name)
        if conn is None:
            continue
        with conn:
            for row in conn.execute(query):
                lines.append(" | ".join(cut(v) for v in row))
    return sorted(lines)


def same_item(text, stack):
    try:
        got = ItemStack.parse(text or "")
    except ValueError:
        return False
    return (got.name, got.count, got.wear, got.meta) == (stack.name, stack.count, stack.wear,
                                                          stack.meta)


# -- engine boots -----------------------------------------------------------

def game_patch(run, extra):
    """A disposable patch of the staged game's minetest.conf (never the
    repository's): the test hook, and the map reset when asked."""
    if extra in run.patches:
        return run.patches[extra]
    old = (REPO / "minetest.conf").read_text().splitlines(keepends=True)
    new = old + ["\n", "# Round 43 IT only: the game's test hook for undeclared steps.\n",
                 "grug_test_migrations = true\n"]
    if extra == "reset":
        new += ["# The platform raises this for a map reset.\n", "grug_reset_world = 1\n"]
    path = run.work / ("patch_%s.diff" % extra)
    path.write_text("".join(difflib.unified_diff(old, new, "a/minetest.conf",
                                                 "b/minetest.conf")))
    run.patches[extra] = path
    return path


def server_logs(root):
    return {p for p in root.glob("server*.log") if re.fullmatch(r"server(\.\d+)?\.log", p.name)}


class Boot:
    pass


def boot(run, world, phase, known=None, joins=(), seed_storage=False, reset=False,
         extra_args=(), timeout=BOOT_TIMEOUT):
    """One engine run of `world`. `known`: the test steps the game knows
    (None: the hook stays off). Returns a Boot with rc, log, obs, joins."""
    plan = {"phase": phase, "joins": list(joins), "steps": known or [],
            "seed_storage": seed_storage}
    (world / "r43_it_plan.json").write_text(json.dumps(plan))
    obs_file = world / "r43_it_obs.json"
    if obs_file.exists():
        obs_file.unlink()
    env = dict(os.environ, ROOT=str(run.root), PORT=str(run.port), SEED="42",
               PROBE=str(PROBE), LC_ALL="C")
    env.pop("KEEP", None)
    if known is not None:
        shutil.copy(HERE / "grug_test_migrations.lua", world / "grug_test_migrations.lua")
        env["GAME_PATCH"] = str(game_patch(run, "reset" if reset else "hook"))
    before = server_logs(run.root)
    out = run.work / ("launcher_%s.txt" % phase)
    started = time.monotonic()
    with open(out, "w") as handle:
        proc = subprocess.Popen([str(LAUNCHER), str(timeout), "--world", str(world),
                                 *extra_args], env=env, stdout=handle,
                                stderr=subprocess.STDOUT)
        result = Boot()
        result.joins = []
        if joins:
            listening = False
            while proc.poll() is None and not listening:
                time.sleep(1)
                for log in server_logs(run.root) - before:
                    listening = "listening on" in log.read_text(errors="replace")
            for name in joins if listening else ():
                try:
                    result.joins.append(client.join(run.port, name, stay=4.0))
                except client.JoinError as err:
                    result.joins.append("JOIN FAILED: %s" % err)
        result.rc = proc.wait()
    result.seconds = round(time.monotonic() - started)
    new = sorted(server_logs(run.root) - before)
    result.log = result.console = ""
    if new:
        console = new[0].with_name(new[0].name[:-len(".log")] + ".console.log")
        result.log = new[0].read_text(errors="replace")
        result.console = console.read_text(errors="replace") if console.exists() else ""
    result.obs = json.loads(obs_file.read_text()) if obs_file.exists() else None
    keep_evidence(run, phase, result, out)
    return result


EVIDENCE_LINE = re.compile(r"\[grug_core\] (world version|migration|map reset|This world|the world)"
                           r"|\[r43_it_probe\]|ERROR|ModError|joins game|leaves game|listening on"
                           r"|Successfully migrated|world\.mt updated|not supported")


def keep_evidence(run, phase, result, launcher_out):
    folder = run.evidence / "boots"
    folder.mkdir(parents=True, exist_ok=True)
    lines = [line for line in result.log.splitlines() if EVIDENCE_LINE.search(line)]
    lines = [re.sub(r"/tmp/grudgelands-headless\.\w+", "<run>", line) for line in lines[:60]]
    text = "launcher: %s\nseconds: %d, exit %d\njoins: %s\n--- log lines\n%s\n" % (
        launcher_out.read_text().splitlines()[0] if launcher_out.read_text() else "-",
        result.seconds, result.rc, result.joins, "\n".join(lines))
    (folder / ("%s.txt" % phase)).write_text(re.sub(r"/tmp/grudgelands-headless\.\w+",
                                                    "<run>", text))
    if result.obs is not None:
        (folder / ("%s.obs.json" % phase)).write_text(re.sub(
            r"/tmp/grudgelands-headless\.\w+", "<run>", json.dumps(result.obs, indent=1)) + "\n")


def refused_with(result, *pieces):
    # The engine's log continues a long error message on a new "ERROR[Main]: " line.
    text = result.log.replace("\nERROR[Main]: ", "")
    return result.rc != 0 and "listening on" not in text and all(p in text for p in pieces)


# -- the tool ---------------------------------------------------------------

def tool(run, case, world, spec, check_mode=False, shipped=False):
    """The tool in the runner's environment (Debian trixie, python3 3.13), on
    the world directory mounted at its own path, without network."""
    args = ["python3", "tools/migrate.py"] if shipped else \
        ["python3", "tools/r43_it/tool_run.py", spec]
    args += ["--world", str(world)] + (["--check"] if check_mode else [])
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), IMAGE] + args
    proc = subprocess.run(cmd, capture_output=True, text=True)
    events = []
    for line in proc.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    folder = run.evidence / "tool"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / ("%s.jsonl" % case)).write_text(
        re.sub(r"/tmp/grudgelands-headless\.\w+", "<run>", proc.stdout))
    if proc.returncode not in (0, 1, 2) or not events:
        print(proc.stderr[-2000:])
    return proc.returncode, events


def last(events):
    return events[-1] if events else {}


def world_diff(run, name, before, after):
    folder = run.evidence / "diffs"
    folder.mkdir(parents=True, exist_ok=True)
    text = "".join(difflib.unified_diff([l + "\n" for l in before], [l + "\n" for l in after],
                                        "before", "after", n=0))
    (folder / ("%s.diff" % name)).write_text(text or "(no change)\n")


def snapshot(world, target):
    target.mkdir(parents=True)
    for name in ("world.mt", "players.sqlite", "auth.sqlite", "mod_storage.sqlite"):
        shutil.copy(world / name, target / name)


# -- the scenarios ----------------------------------------------------------

def world1(run):
    w1 = run.root / "w1"
    write_world_mt(w1, mod_storage=False)

    # Genesis: the engine creates the empty SQLite mod storage.
    g = boot(run, w1, "w1_genesis", extra_args=("--migrate-mod-storage", "sqlite3"), timeout=60)
    mt = (w1 / "world.mt").read_text()
    check("setup", "w1: the engine created an empty mod_storage.sqlite",
          (w1 / "mod_storage.sqlite").exists() and "mod_storage_backend = sqlite3" in mt
          and dump(w1) == [] and "Successfully migrated" in g.log + g.console, mt)

    # Goal 3: a world the game will call new is new to the tool.
    rc, ev = tool(run, "w1_new_check_shipped", w1, "-", check_mode=True, shipped=True)
    done = last(ev)
    check("new world", "tool (shipped command line) --check: an unstarted world is new",
          rc == 0 and done.get("new_world") is True and done.get("world_version") is None
          and done.get("due") == [] and done.get("write_checked") == ["mod_storage"],
          "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = tool(run, "w1_new_migrate", w1, ",".join(DUE4))
    check("new world", "tool with test steps on the new world: nothing due, nothing written",
          rc == 0 and last(ev).get("applied") == [] and dump(w1) == [],
          "exit %d %s" % (rc, json.dumps(last(ev))))

    # Boot A: the new world.
    a = boot(run, w1, "w1_A_new", known=DUE4, joins=("hero", "bystander"), seed_storage=True)
    obs = a.obs or {}
    check("setup", "boot A: the server ran and both characters joined and left",
          a.rc == 0 and len(obs.get("joins") or []) == 2 and obs.get("leaves") == 2
          and characters(w1) == ["bystander", "hero"], "rc %d joins %s" % (a.rc, a.joins))
    check("new world", "game: the same world is new at its first start",
          (obs.get("load") or {}).get("new_world") is True)
    check("guard", "a new world is stamped with the game's version",
          storage(w1, "grug_core").get("world_version") == GAME
          and ("world version %s recorded for a new world" % GAME) in a.log
          and (obs.get("load") or {}).get("from") == GAME,
          "record %r" % storage(w1, "grug_core").get("world_version"))
    check("steps", "grug_core's migration runner is the first join callback",
          "grug_core/world_version.lua" in (obs.get("first_join_callback") or ""),
          obs.get("first_join_callback", "?"))

    # A world from before 0.43: no record (= 0.41.0).
    set_record(w1, None)
    snapshot(w1, run.work / "pre_tool")
    before = dump(w1)
    b = boot(run, w1, "w1_B_refused", known=DUE4)
    check("guard", "a world crossing steps is refused (message names the steps and the tool)",
          refused_with(b, "This world is at version 0.41.0 and needs the migration steps "
                          "0.41.1, 0.41.2, 0.41.3, 0.41.4 before this game's version %s can "
                          "start it" % GAME,
                       "back up the world and run the tool from the game's repository root: "
                       "python3 tools/migrate.py --world %s" % w1),
          "rc %d" % b.rc)
    check("guard", "the refused start wrote nothing", dump(w1) == before)

    rc, ev = tool(run, "w1_check", w1, ",".join(DUE4), check_mode=True)
    done = last(ev)
    check("steps", "tool --check: 0.41.0 (no record), four steps due, write access on all three",
          rc == 0 and done.get("world_version") == "0.41.0" and done.get("record") is None
          and done.get("new_world") is False and done.get("due") == DUE4
          and done.get("write_checked") == ["player", "auth", "mod_storage"],
          "exit %d %s" % (rc, json.dumps(done)))
    check("steps", "tool --check wrote nothing", dump(w1) == before)
    rc, ev = tool(run, "w1_check_shipped", w1, "-", check_mode=True, shipped=True)
    check("steps", "tool (shipped command line, empty migrate list): nothing due",
          rc == 0 and last(ev).get("due") == [] and last(ev).get("world_version") == "0.41.0")

    rc, ev = tool(run, "w1_migrate", w1, ",".join(DUE4))
    kinds = [e.get("event") for e in ev]
    check("steps", "tool: the four test steps ran in order",
          rc == 0 and last(ev).get("applied") == DUE4 and kinds == ["start"] +
          ["step_start", "step_done"] * 4 + ["done"]
          and [e["step"] for e in ev if e.get("event") == "step_start"] == DUE4,
          "exit %d %s" % (rc, kinds))
    after = dump(w1)
    world_diff(run, "w1_tool_0.41.1-0.41.4", before, after)
    meta = player_meta(w1, "hero")
    store = storage(w1, "grug_probe_r43_it")
    check("steps", "tool: offline writes and markers are in the databases",
          storage(w1, "grug_core").get("world_version") == "0.41.4"
          and storage(w1, "grug_core").get("migrate_world:0.41.2") == "w-0.41.2"
          and meta.get("it:offline") == "0.41.1"
          and meta.get("grug_core:migrate:0.41.3") == "c-0.41.3"
          and meta.get("grug_core:migrate:0.41.4") == "c-0.41.4"
          and not any(k.startswith("grug_core:migrate:") for k in player_meta(w1, "bystander"))
          and store.get("offline") == "0.41.1" and "delete_me" not in store
          and store.get("keep") == "probe" and "fly" in privileges(w1, "hero")
          and same_item(main_slot(w1, "hero"), it_steps.APPLE),
          json.dumps({"meta": {k: v for k, v in meta.items() if k.startswith(("it:", "grug_core:m"))},
                      "store": store}))
    snapshot(w1, run.work / "post_tool")

    # Boot C: the online work.
    c = boot(run, w1, "w1_C_online", known=DUE4, joins=("hero", "bystander"))
    obs = c.obs or {}
    load = obs.get("load") or {}
    check("setup", "boot C: the server ran and both characters joined and left",
          c.rc == 0 and len(obs.get("joins") or []) == 2 and obs.get("leaves") == 2,
          "rc %d joins %s" % (c.rc, c.joins))
    check("guard", "a compatible move (0.41.4, no step between) starts and bumps the record",
          load.get("from") == "0.41.4" and load.get("new_world") is False
          and storage(w1, "grug_core").get("world_version") == GAME
          and ("world version %s recorded (was 0.41.4)" % GAME) in c.log)
    check("steps", "game: the hook's unordered test steps are in step order",
          load.get("steps") == DUE4, json.dumps(load.get("steps")))
    check("steps", "game: the offline mod-storage write and delete are seen at load",
          load.get("offline") == "0.41.1" and load.get("delete_me") == ""
          and load.get("keep") == "probe")
    world_log = (obs.get("mods_loaded") or {}).get("log") or []
    check("steps", "game: the world marker ran once at load with its value",
          [(e.get("kind"), e.get("step"), e.get("marker")) for e in world_log]
          == [("world", "0.41.2", "w-0.41.2")]
          and "migrate_world:0.41.2" not in storage(w1, "grug_core"), json.dumps(world_log))
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    hero, bystander = joins.get("hero") or {}, joins.get("bystander") or {}
    hero_log = [(e.get("step"), e.get("marker"), e.get("pending")) for e in hero.get("log") or []
                if e.get("kind") == "character" and e.get("name") == "hero"]
    check("steps", "game, hero's join: the two markers ran in step order, then were deleted",
          hero_log == [("0.41.3", "c-0.41.3", ["0.41.3", "0.41.4"]),
                       ("0.41.4", "c-0.41.4", ["0.41.4"])]
          and hero.get("order") == "0.41.3;0.41.4;" and (hero.get("markers") or []) == [],
          json.dumps(hero))
    check("steps", "game, hero's join: the offline meta, inventory and privilege are loaded",
          hero.get("offline") == "0.41.1" and hero.get("fly") is True
          and same_item(hero.get("main1"), it_steps.APPLE), json.dumps(hero))
    check("steps", "game, bystander's join: unaffected (no marker, no handler call)",
          bystander and (bystander.get("markers") or []) == [] and bystander.get("order") == ""
          and bystander.get("offline") == "" and not any(
              e.get("name") == "bystander" for e in bystander.get("log") or []),
          json.dumps(bystander))
    meta = player_meta(w1, "hero")
    check("steps", "after boot C: no marker left in the databases, the handlers' writes saved",
          not any(k.startswith("grug_core:migrate:") for k in meta)
          and meta.get("it:order") == "0.41.3;0.41.4;"
          and not any(k.startswith("migrate_world:") for k in storage(w1, "grug_core")),
          json.dumps({k: v for k, v in meta.items() if k.startswith(("it:", "grug_core:m"))}))

    # Map reset combined with a step, in the platform's order.
    set_record(w1, "0.41.4")
    for suffix in ("", "-journal", "-wal", "-shm"):
        path = w1 / ("map.sqlite" + suffix)
        if path.exists():
            path.unlink()
    before = dump(w1)
    rc, ev = tool(run, "w1_reset_migrate", w1, ",".join(ALL5))
    check("map reset", "on the emptied map the tool runs only the due step 0.41.5",
          rc == 0 and last(ev).get("applied") == ["0.41.5"]
          and storage(w1, "grug_core").get("world_version") == "0.41.5",
          "exit %d %s" % (rc, json.dumps(last(ev))))
    world_diff(run, "w1_tool_0.41.5", before, dump(w1))
    j = boot(run, w1, "w1_J_reset", known=ALL5, reset=True)
    obs = j.obs or {}
    load = obs.get("load") or {}
    world_log = (obs.get("mods_loaded") or {}).get("log") or []
    lines = j.log.splitlines()
    cleared = [i for i, line in enumerate(lines) if re.search(r"map reset 1: cleared", line)]
    worked = [i for i, line in enumerate(lines) if "migration 0.41.5: the world's online work"
              in line]
    check("map reset", "boot J started from 0.41.5 with the reset pending",
          j.rc == 0 and load.get("from") == "0.41.5" and load.get("reset_pending") is True
          and load.get("steps") == ALL5
          and load.get("reset_applied") == 1, "rc %d load %s" % (j.rc, json.dumps(load)))
    check("map reset", "the step's offline write and its world work (after every clear) are done",
          load.get("offline_reset") == "0.41.5"
          and [(e.get("step"), e.get("marker"), e.get("reset_applied")) for e in world_log]
          == [("0.41.5", "w-0.41.5", 1)]
          and cleared and worked and max(cleared) < min(worked)
          and "migrate_world:0.41.5" not in storage(w1, "grug_core"),
          json.dumps(world_log))
    core_store = storage(w1, "grug_core")
    check("map reset", "the map reset is done and the record is at the new version",
          core_store.get("reset_world") == "1" and core_store.get("world_version") == GAME
          and (w1 / "map.sqlite").exists() and "map reset 1 applied to the world" in j.log,
          "reset_world %r world_version %r" % (core_store.get("reset_world"),
                                              core_store.get("world_version")))


def world2(run):
    w2 = run.root / "w2"
    write_world_mt(w2, mod_storage=True)
    one = ["0.41.1"]
    d = boot(run, w2, "w2_D_new", known=one)
    check("setup", "boot D: a new world ran without any join",
          d.rc == 0 and (d.obs or {}).get("load", {}).get("new_world") is True
          and characters(w2) == [] and storage(w2, "grug_core").get("world_version") == GAME,
          "rc %d" % d.rc)

    # A world from before 0.43 that never had a character, with saved state.
    set_record(w2, None)
    before = dump(w2)
    rc, ev = tool(run, "w2_check", w2, "0.41.1", check_mode=True)
    done = last(ev)
    check("new world", "tool: a booted world without characters is existing (0.41.0, step due)",
          rc == 0 and done.get("new_world") is False and done.get("world_version") == "0.41.0"
          and done.get("due") == one, "exit %d %s" % (rc, json.dumps(done)))
    e = boot(run, w2, "w2_E_refused", known=one)
    check("guard", "an existing world without characters is not taken for new: refused",
          refused_with(e, "This world is at version 0.41.0 and needs the migration step 0.41.1 "
                          "before", "python3 tools/migrate.py --world %s" % w2),
          "rc %d" % e.rc)
    check("new world", "game: the same world is existing too (no deadlock: refused, not new)",
          refused_with(e, "needs the migration step 0.41.1") and dump(w2) == before)
    rc, ev = tool(run, "w2_migrate", w2, "0.41.1")
    check("new world", "tool: runs the step the game asked for",
          rc == 0 and last(ev).get("applied") == one
          and storage(w2, "grug_core").get("world_version") == "0.41.1",
          "exit %d %s" % (rc, json.dumps(last(ev))))
    f = boot(run, w2, "w2_F_after_tool", known=one)
    load = (f.obs or {}).get("load") or {}
    check("new world", "game: starts after the tool and bumps the record",
          f.rc == 0 and load.get("from") == "0.41.1" and load.get("offline") == "0.41.1"
          and storage(w2, "grug_core").get("world_version") == GAME, "rc %d" % f.rc)

    major, minor = (int(part) for part in GAME.split(".")[:2])
    newer = "%d.%d.0" % (major, minor + 1)
    set_record(w2, newer)
    before = dump(w2)
    g = boot(run, w2, "w2_G_newer", known=one)
    check("guard", "a newer world is refused (both versions, downgrade to the record)",
          refused_with(g, "This world is at version %s, newer than this game's version "
                          "%s; the server does not start: downgrade to %s to continue."
                       % (newer, GAME, newer)) and dump(w2) == before, "rc %d" % g.rc)
    rc, ev = tool(run, "w2_newer", w2, "-", check_mode=True)
    check("guard", "the tool refuses the newer world too (exit 2, world_newer)",
          rc == 2 and last(ev).get("reason") == "world_newer" and dump(w2) == before,
          "exit %d %s" % (rc, json.dumps(last(ev))))

    set_record(w2, "0.42")
    before = dump(w2)
    h = boot(run, w2, "w2_H_malformed", known=one)
    check("guard", "a malformed record is refused by the game",
          refused_with(h, "the world's version record \"0.42\" is no major.minor.patch version")
          and dump(w2) == before, "rc %d" % h.rc)
    rc, ev = tool(run, "w2_malformed", w2, "-", check_mode=True)
    check("guard", "a malformed record is refused by the tool too (exit 2, record)",
          rc == 2 and last(ev).get("reason") == "record" and dump(w2) == before,
          "exit %d %s" % (rc, json.dumps(last(ev))))


def postgresql(run):
    found = subprocess.run(
        ["flatpak", "run", "--command=sh", "org.luanti.luanti", "-c",
         "grep -a -c pgsql_player_connection /app/bin/luanti.bin || true"],
        capture_output=True, text=True).stdout.strip()
    check("postgresql", "the local Luanti build has no PostgreSQL backend (seeding route)",
          found == "0", "pgsql_player_connection in luanti.bin: %s" % found)
    proc = subprocess.run(
        ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
         "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.work, run.work),
         "-w", str(REPO), IMAGE, "python3", "tools/r43_it/pg_test.py", str(run.work)],
        capture_output=True, text=True)
    (run.evidence / "postgresql.txt").write_text(proc.stdout + proc.stderr[-3000:])
    events = run.work / "pg_events"
    if events.is_dir():
        shutil.copytree(events, run.evidence / "pg_events", dirs_exist_ok=True)
    try:
        pg = json.loads((run.work / "pg_results.json").read_text())
    except (OSError, ValueError):
        pg = []
    for item in pg:
        check("postgresql", item["name"], item["ok"], item["detail"])
    check("postgresql", "the PostgreSQL run finished", proc.returncode == 0 and pg,
          "exit %d" % proc.returncode)


def main(argv):
    evidence = Path(argv[0]).resolve()
    if evidence.exists():
        shutil.rmtree(evidence)
    evidence.mkdir(parents=True)
    run = Run(evidence)
    print("run directory %s, port %d, game %s" % (run.root, run.port, GAME), flush=True)
    try:
        for part in (world1, world2, postgresql):
            try:
                part(run)
            except Exception as err:
                check("harness", part.__name__, False, "%s: %s" % (type(err).__name__, err))
                raise
    finally:
        table = ["%-4s  %-11s %s" % ("PASS" if ok else "FAIL", group, name)
                 for group, name, ok, _ in results]
        failed = [r for r in results if not r[2]]
        summary = "%d checks, %d failed" % (len(results), len(failed))
        text = "\n".join(table + ["", summary] + ["FAIL %s: %s" % (r[1], r[3]) for r in failed])
        (evidence / "results.txt").write_text(text + "\n")
        print("\n" + text)
        if os.environ.get("KEEP") == "1":
            print("kept: %s" % run.root)
        else:
            shutil.rmtree(run.root, ignore_errors=True)
            shutil.rmtree("/tmp/grudgelands-headless-failed/" + run.root.name,
                          ignore_errors=True)
    return 0 if results and not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
