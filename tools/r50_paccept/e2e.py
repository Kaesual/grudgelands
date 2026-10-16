#!/usr/bin/env python3
"""Round 50 lane PACCEPT: the map-reset packing end to end
(docs/planning/round50-plan.md section 4 PACCEPT, rulings 4-10, the platform
agreement; docs/technical/upgrade-contract.md sections 1, 3.5 and 5).

  boot S   the real 0.48.1 game (a checkout at 1ef11b5e, OLD_GAME, its own
           tools/luanti_headless.sh) on a new SQLite world; keeper, neighbor
           and drifter join; the probe (grug_probe_r50_paccept, header)
           builds keeper's and neighbor's claims and containers and writes
           the receipt at the shutdown; the record must say 0.48.1
  SQLite   on a copy: the shipped tool in the platform runner's image
           (tools/r43_it/Containerfile: Debian trixie, python3 3.13,
           python3-zstandard): --check --map-reset (nothing written), then
           --world <dir> --map-reset; the map rows, players and auth
           unchanged, only new mod storage keys; every entry equals the
           receipt; then the map emptied (DELETE FROM blocks, the map rows
           only) and grug_reset_world raised above the world's record
  PG       tools/r50_paccept/pg_pass.py in the same image: the 0.48.1 rows
           in PostgreSQL in the platform's layout (map, player, auth;
           mod storage SQLite), the tool, TRUNCATE public.blocks; the
           Flatpak engine has no PostgreSQL, so its boots take the pass's
           mod_storage.sqlite with the 0.48.1 player and auth files (the
           pass proved those rows unchanged) and an emptied map
  boot A   per backend, this checkout's 0.50.0 game with the raised counter
           (a disposable patch of the staged minetest.conf, which
           luanti_headless.sh copies into server.conf): the first-start
           clean-up (the probe's own item removed), the marker deleted;
           keeper, neighbor and drifter join: notices for keeper and
           neighbor only; keeper's new draft stone shows no Belongings, the
           activated one does; every entry taken, every packed container
           placed and read back equal to the receipt; the charcoal equals
           ceil((paid_until - pass time) / LUMP_SECONDS)
  boot B   the same world again: nothing changes at the load; keeper's
           placed containers still equal the receipt; neighbor's flow

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r50_paccept/evidence) and exits 0 only when
every check passed. FIXTURE=<dir> also packages the 0.48.1 world for the
platform (README, receipt, world archive, PostgreSQL dump).

Usage: tools/r50_paccept/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import difflib
import hashlib
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import client  # noqa: E402  (tools/r43_it/client.py)
import it  # noqa: E402  (tools/r43_it/it.py)
from migration import codec  # noqa: E402

OLD_GAME = Path(os.environ.get("OLD_GAME", str(REPO.parent / "r50-v0481")))
OLD_VERSION = "0.48.1"
NEW_VERSION = it.GAME
PROBE = HERE / "grug_probe_r50_paccept"
IMAGE = it.IMAGE
LUMP_SECONDS = 26160
RADIUS, MIN_Y = 50, -100
PACKED = "grug_housing:packed_container"
CHARCOAL = "grug_smelting:charcoal"
RELIC = "grug_probe_r50_paccept:relic"
NOTICE = "Belongings from the old map wait in your Claim Stone."
PROBE_FILES = ("paccept_plan.json", "paccept_ready", "paccept_obs.json", "paccept_receipt.json")
BOOT_TIMEOUT = 290
check = it.check
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern +
                              r"|\[r50_paccept_probe\]|\[grug_housing\] (map reset|.* unpacked)")
numbers = {}


def sanitize(text):
    return re.sub(r"/tmp/grudgelands-headless\.\w+", "<run>", text)


# -- boots --------------------------------------------------------------------

def reset_patch(run, value):
    """A disposable patch of the staged minetest.conf: the platform's raised
    grug_reset_world (luanti_headless.sh copies the file into server.conf)."""
    path = run.work / ("reset_%d.diff" % value)
    if not path.exists():
        old = (REPO / "minetest.conf").read_text().splitlines(keepends=True)
        new = old + ["\n", "# Round 50 PACCEPT: the platform raises this for a map reset.\n",
                     "grug_reset_world = %d\n" % value]
        path.write_text("".join(difflib.unified_diff(old, new, "a/minetest.conf",
                                                     "b/minetest.conf")))
    return path


class Boot:
    pass


def boot(run, world, phase, launcher, plan, joins=(), reset=None):
    """One engine run of `world` with the probe. `joins`: (name, stay) in
    order, joined once the probe signals its sites ready."""
    plan = dict(plan, joins=[name for name, _ in joins])
    (world / "paccept_plan.json").write_text(json.dumps(plan))
    for name in ("paccept_obs.json", "paccept_ready"):
        if (world / name).exists():
            (world / name).unlink()
    env = dict(os.environ, ROOT=str(run.root), PORT=str(run.port), SEED="42",
               PROBE=str(PROBE), LC_ALL="C")
    env.pop("KEEP", None)
    env.pop("GAME_PATCH", None)
    if reset is not None:
        env["GAME_PATCH"] = str(reset_patch(run, reset))
    before = it.server_logs(run.root)
    out = run.work / ("launcher_%s.txt" % phase)
    started = time.monotonic()
    result = Boot()
    result.joins = []
    with open(out, "w") as handle:
        proc = subprocess.Popen([str(launcher), str(BOOT_TIMEOUT), "--world", str(world)],
                                env=env, stdout=handle, stderr=subprocess.STDOUT)
        if joins:
            deadline = time.monotonic() + BOOT_TIMEOUT - 40
            while proc.poll() is None and not (world / "paccept_ready").exists() \
                    and time.monotonic() < deadline:
                time.sleep(1)
            result.ready_after = round(time.monotonic() - started)
            for name, stay in joins if (world / "paccept_ready").exists() else ():
                try:
                    result.joins.append(client.join(run.port, name, stay=stay))
                except client.JoinError as err:
                    result.joins.append("JOIN FAILED: %s" % err)
        result.rc = proc.wait()
    result.seconds = round(time.monotonic() - started)
    new = sorted(it.server_logs(run.root) - before)
    result.log = new[0].read_text(errors="replace") if new else ""
    result.console = ""
    obs_file = world / "paccept_obs.json"
    result.obs = json.loads(obs_file.read_text()) if obs_file.exists() else None
    conf = run.root / "server.conf"
    result.server_conf = conf.read_text() if conf.exists() else ""
    it.keep_evidence(run, phase, result, out)
    print("boot %s: exit %d, %d s, joins %s" % (phase, result.rc, result.seconds, result.joins),
          flush=True)
    return result


# -- the tool -----------------------------------------------------------------

def tool(run, case, world, *args):
    """The shipped tool in the runner's image, timed inside the container."""
    script = ('s=$(date +%s%N); python3 tools/migrate.py "$@"; rc=$?; e=$(date +%s%N); '
              'echo "paccept_wall_ns $((e - s))" >&2; exit $rc')
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-e", "PYTHONDONTWRITEBYTECODE=1",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), IMAGE, "sh", "-c", script, "sh", "--world", str(world), *args]
    before = time.time()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    after = time.time()
    events = []
    for line in proc.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    wall = re.search(r"paccept_wall_ns (\d+)", proc.stderr)
    folder = run.evidence / "tool"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / ("%s.jsonl" % case)).write_text(sanitize(proc.stdout))
    (folder / ("%s.txt" % case)).write_text(sanitize(proc.stderr))
    return {"rc": proc.returncode, "events": events, "stderr": proc.stderr,
            "clock": [before, after], "wall": int(wall.group(1)) / 1e9 if wall else None}


def event(events, kind):
    return next((e for e in events if e.get("event") == kind), {})


# -- worlds -------------------------------------------------------------------

def map_digest(world):
    conn = sqlite3.connect((world / "map.sqlite").as_uri() + "?mode=ro", uri=True)
    rows = conn.execute("SELECT x, y, z, data FROM blocks ORDER BY x, y, z").fetchall()
    conn.close()
    digest = hashlib.sha256()
    for x, y, z, data in rows:
        digest.update(b"%d,%d,%d:" % (x, y, z) + bytes(data))
    return len(rows), digest.hexdigest()


def empty_map(world):
    """The platform's emptying on SQLite: the map rows only."""
    conn = sqlite3.connect(world / "map.sqlite")
    with conn:
        removed = conn.execute("DELETE FROM blocks").rowcount
    conn.execute("VACUUM")
    left = conn.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    conn.close()
    return removed, left


def lua_list(value):
    """A core.deserialize'd array (a dict with int keys, or a list)."""
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        top = max((k for k in value if isinstance(k, int)), default=0)
        return [value.get(i, "") for i in range(1, top + 1)]
    return []


def norm(item):
    stack = codec.ItemStack.parse(item or "")
    if stack.is_empty():
        return None
    return (stack.name, stack.count, stack.wear, json.dumps(stack.meta, sort_keys=True))


def norm_lists(lists, drop=()):
    out = {}
    for name, stacks in (lists or {}).items():
        values = [norm(s) for s in lua_list(stacks)]
        values = [None if v and v[0] in drop else v for v in values]
        while values and values[-1] is None:
            values.pop()
        if any(values):
            out[name] = values
    return out


def in_claim(pos, claims):
    for c in claims:
        center = c["center"]
        if abs(pos["x"] - center["x"]) <= RADIUS and abs(pos["z"] - center["z"]) <= RADIUS \
                and pos["y"] >= MIN_Y:
            return c
    return None


def expected(receipt):
    """The containers in the claim areas per owner: those holding an item
    (packed with their contents) and the empty ones; and the outside ones."""
    packed, empty, outside = {}, {}, []
    for c in receipt["containers"]:
        claim = in_claim(c["pos"], receipt["claims"])
        if not claim:
            outside.append(c)
        elif norm_lists(c["lists"]):
            packed.setdefault(claim["owner"], []).append(c)
        else:
            empty.setdefault(claim["owner"], []).append(c)
    return packed, empty, outside


def base_node(node):
    """The node an item of `node` places (a lit furnace drops a furnace)."""
    return {"default:furnace_active": "default:furnace"}.get(node, node)


def empty_items(empty, owner):
    """The plain node items ruling 13 gives back for owner's empty
    containers: {item name: count}."""
    out = {}
    for c in empty.get(owner, []):
        out[base_node(c["node"])] = out.get(base_node(c["node"]), 0) + 1
    return out


def charcoal_range(claim, clock):
    """ceil((paid_until - t) / LUMP_SECONDS) for t in the tool run's clock."""
    return {max(0, math.ceil((claim["paid_until"] - t) / LUMP_SECONDS)) for t in
            (int(clock[0]), int(clock[1]))}


def recovered(world):
    return {k: v for k, v in it.storage(world, "grug_housing").items()
            if k.startswith("recovered:") or k == "pack_seq"}


def entries_match(rows, receipt, seq=1):
    """Every recovered entry against the receipt: (ok, detail, per owner)."""
    packed, empty, _ = expected(receipt)
    nodes = {base_node(c["node"]) for c in receipt["containers"]}
    problems, per_owner, charcoal, plain = [], {}, {}, {}
    for key in sorted(rows):
        m = re.fullmatch(r"recovered:([^:]+):(\d+):(\d+)", key)
        if not m:
            continue
        owner = m.group(1)
        stack = codec.ItemStack.parse(rows[key])
        per_owner.setdefault(owner, []).append(key)
        if stack.name == CHARCOAL:
            charcoal[owner] = charcoal.get(owner, 0) + stack.count
            continue
        if stack.name in nodes and stack.name != PACKED:
            # Ruling 13: an empty container comes back as its plain node item.
            plain.setdefault(owner, {})
            plain[owner][stack.name] = plain[owner].get(stack.name, 0) + stack.count
            continue
        if stack.name != PACKED or stack.meta.get("seq") != str(seq):
            problems.append("%s: %s" % (key, stack.name))
            continue
        lists = codec.deserialize(stack.meta.get("lists", ""))
        got = norm_lists({k: v for k, v in lists.items()})
        hit = [c for c in packed.get(owner, []) if c["node"] == stack.meta.get("node")
               and norm_lists(c["lists"]) == got and not c.get("_used")]
        if hit:
            hit[0]["_used"] = True
        else:
            problems.append("%s: no receipt container (%s)" % (key, stack.meta.get("node")))
    missing = [c["id"] for cs in packed.values() for c in cs if not c.pop("_used", False)]
    if missing:
        problems.append("not packed: %s" % missing)
    # Empty containers: not packed at all (0.50.0 as first built), or all of
    # them as plain node items (ruling 13); never a part of them.
    mode = "plain" if plain else "skipped"
    if plain and plain != {o: empty_items(empty, o) for o in empty}:
        problems.append("empty containers as plain items %s, expected %s" % (
            plain, {o: empty_items(empty, o) for o in empty}))
    numbers["empty_mode"] = mode
    return not problems, "; ".join(problems), per_owner, charcoal


# -- the scenario ---------------------------------------------------------------

def build_old_world(run):
    conf = (OLD_GAME / "game.conf").read_text() if (OLD_GAME / "game.conf").exists() else ""
    version = re.search(r"^version\s*=\s*(\S+)", conf, re.M)
    head = subprocess.run(["git", "-C", str(OLD_GAME), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()
    check("setup", "the 0.48.1 game: %s at %s" % (OLD_GAME.name, head),
          version and version.group(1) == OLD_VERSION and head.startswith("1ef11b5e"),
          "%s %s" % (version and version.group(1), head))
    w0 = run.root / "w0481"
    it.write_world_mt(w0, mod_storage=True)
    joins = (("keeper", 14.0), ("neighbor", 6.0), ("drifter", 4.0))
    s = boot(run, w0, "S_setup_0.48.1", OLD_GAME / "tools" / "luanti_headless.sh",
             {"phase": "setup"}, joins=joins)
    obs = s.obs or {}
    built = {j["name"]: j.get("built") for j in obs.get("joins") or []}
    check("setup", "boot S (0.48.1): keeper, neighbor and drifter joined; both claims built",
          s.rc == 0 and obs.get("leaves") == 3 and built.get("keeper") is True
          and built.get("neighbor") is True and not obs.get("errors"),
          "rc %d joins %s errors %s" % (s.rc, s.joins, obs.get("errors")))
    record = it.storage(w0, "grug_core").get("world_version")
    check("setup", "the world's version record says 0.48.1", record == OLD_VERSION, record)
    check("setup", "three characters saved", it.characters(w0) == ["drifter", "keeper",
                                                                     "neighbor"],
          str(it.characters(w0)))
    receipt = json.loads((w0 / "paccept_receipt.json").read_text())
    for name in PROBE_FILES:
        if (w0 / name).exists():
            (w0 / name).unlink()
    (run.evidence / "receipt.json").write_text(json.dumps(receipt, indent=1,
                                                          ensure_ascii=False) + "\n")
    by_id = {c["id"]: c for c in receipt["containers"]}
    furnace = by_id.get("furnace", {})
    fl = furnace.get("lists") or {}
    check("setup", "the receipt: 11 containers, 2 claims (keeper and neighbor, both fuelled)",
          len(receipt["containers"]) == 11 and sorted(c["owner"] for c in receipt["claims"])
          == ["keeper", "neighbor"] and all(c["paid_until"] > time.time()
                                            for c in receipt["claims"]),
          json.dumps(receipt["claims"]))
    check("setup", "the furnace is lit at the save, with input, fuel and output",
          furnace.get("node") == "default:furnace_active" and any(fl.get("src") or [])
          and any(fl.get("fuel") or []) and any(fl.get("dst") or []),
          json.dumps({"node": furnace.get("node"), "lists": fl}))
    check("setup", "the locked chest belongs to keeper",
          by_id.get("locked_chest", {}).get("owner_meta") == "keeper")
    relic = by_id.get("relic_chest", {}).get("lists", {}).get("main", [""])[0]
    check("setup", "the probe's own item lies in a chest of keeper's claim",
          relic.startswith(RELIC), relic)
    packed, empty, outside = expected(receipt)
    check("setup", "in keeper's claim an empty chest and an empty furnace",
          sorted(c["id"] for c in empty.get("keeper", [])) == ["empty_chest", "empty_furnace"],
          str({o: [c["id"] for c in cs] for o, cs in empty.items()}))
    check("setup", "outside every claim: the outside chest",
          [c["id"] for c in outside] == ["outside_chest"], str([c["id"] for c in outside]))
    numbers["containers"] = {o: [c["id"] for c in cs] for o, cs in packed.items()}
    return w0, receipt


def check_pass(run, label, world, receipt, rc_check, rc_pass, dump_before, digest_before,
               map_backend):
    packed, empty, _ = expected(receipt)
    done = rc_check["events"][-1] if rc_check["events"] else {}
    check(label, "--check --map-reset: one block read and decoded, nothing due, exit 0",
          rc_check["rc"] == 0 and done.get("map_checked") == 1 and done.get("map_reset") is True
          and done.get("world_version") == OLD_VERSION and done.get("due") == [],
          "exit %d %s" % (rc_check["rc"], json.dumps(done)))
    kinds = [e.get("event") for e in rc_pass["events"]]
    done = rc_pass["events"][-1] if rc_pass["events"] else {}
    check(label, "--map-reset: start, pack_start, pack_done, done; exit 0",
          rc_pass["rc"] == 0 and kinds == ["start", "pack_start", "pack_done", "done"],
          "exit %d %s" % (rc_pass["rc"], kinds))
    check(label, "done: mode migrate, target %s, map_reset true, applied [], map backend %s"
          % (NEW_VERSION, map_backend),
          done.get("mode") == "migrate" and done.get("target") == NEW_VERSION
          and done.get("map_reset") is True and done.get("applied") == []
          and (done.get("backends") or {}).get("map") == map_backend, json.dumps(done))
    counts = event(rc_pass["events"], "pack_done").get("counts") or {}
    claims = {c["owner"]: c for c in receipt["claims"]}
    ranges = {o: charcoal_range(c, rc_pass["clock"]) for o, c in claims.items()}
    want_items = sum(len([s for s in v if s]) for cs in packed.values() for c in cs
                     for v in c["lists"].values())
    n_packed = sum(len(v) for v in packed.values())
    n_empty = sum(len(v) for v in empty.values())
    check(label, "pack_done counts: 2 claims, 2 players, %d containers (%d more if the empty "
          "ones count), %d items, charcoal rounded up" % (n_packed, n_empty, want_items),
          counts.get("claims") == 2 and counts.get("players") == 2
          and counts.get("containers") in (n_packed, n_packed + n_empty)
          and counts.get("items") == want_items
          and counts.get("charcoal") in {a + b for a in ranges["keeper"]
                                         for b in ranges["neighbor"]}, json.dumps(counts))
    rows = recovered(world)
    ok, detail, per_owner, charcoal = entries_match(rows, receipt)
    check(label, "every entry equals a receipt container of its owner; the outside chest is "
          "not packed", ok, detail)
    check(label, "charcoal per owner = ceil((paid_until - pass time) / LUMP_SECONDS)",
          all(charcoal.get(o, 0) in ranges[o] for o in claims),
          "%s vs %s" % (charcoal, {o: sorted(r) for o, r in ranges.items()}))
    check(label, "pack_seq 1", rows.get("pack_seq") == "1", rows.get("pack_seq"))
    if numbers.get("empty_mode") == "skipped":
        skipped = event(rc_pass["events"], "pack_done").get("empty") or {}
        check(label, "empty containers are not packed (pack_done 'empty': %d)" % n_empty,
              sum(skipped.values()) == n_empty if isinstance(skipped, dict) else False,
              json.dumps(skipped))
    return rows, per_owner, charcoal, counts


def run_backend(run, label, world, receipt, pass_info):
    """Boots A and B of the 0.50.0 game on a packed, emptied world."""
    rows_after_pass, per_owner, charcoal = pass_info
    record = int(it.storage(world, "grug_core").get("reset_world") or 0)
    raised = record + 1
    packed, empty, _ = expected(receipt)
    sites = {"keeper": receipt["sites"]["one"], "neighbor": receipt["sites"]["two"]}
    plan = {"phase": "accept", "receipt": receipt, "sites": sites}
    a = boot(run, world, "%s_A_0.50.0" % label, REPO / "tools" / "luanti_headless.sh",
             dict(plan, flow=["keeper"], lay_floor=True),
             joins=(("keeper", 20.0), ("neighbor", 4.0), ("drifter", 4.0)), reset=raised)
    obs = a.obs or {}
    check(label, "boot A (0.50.0, grug_reset_world %d in server.conf): ran clean, three joins"
          % raised, a.rc == 0 and obs.get("leaves") == 3 and not obs.get("errors")
          and ("grug_reset_world = %d" % raised) in a.server_conf,
          "rc %d joins %s errors %s" % (a.rc, a.joins, obs.get("errors")))
    log = a.log
    check(label, "the first-start clean-up ran: the probe's item removed, the pass ready",
          re.search(r"\[grug_housing\] map reset pass 1: recovered:keeper:1:\d+ lost unknown "
                    + re.escape(RELIC) + r" 2", log) is not None
          and re.search(r"\[grug_housing\] map reset pass 1: %d entries cleaned, 0 deleted, "
                        r"0 extra, 1 unknown items removed" % len(
                            [k for k in rows_after_pass if k != "pack_seq"]), log) is not None
          and "[grug_core] map reset pass 1: the packed containers are ready" in log,
          "\n".join(l for l in log.splitlines() if "map reset pass" in l))
    core = it.storage(world, "grug_core")
    check(label, "the marker is deleted; the world is 0.50.0 with reset record %d" % raised,
          not any(k.startswith("map_reset_pack:") for k in core)
          and core.get("world_version") == NEW_VERSION
          and core.get("reset_world") == str(raised), json.dumps(
              {k: v for k, v in core.items() if k in ("world_version", "reset_world")
               or k.startswith("map_reset_pack")}))
    joins = {j["name"]: j for j in obs.get("joins") or []}
    check(label, "every character was moved to its race start (the map reset's player "
          "part) before keeper's flow", all(
              "[grug_core] map reset %d: %s moved to the race start" % (raised, n) in log
              for n in ("keeper", "neighbor", "drifter"))
          and (joins.get("keeper") or {}).get("relocation_wait") is not None,
          json.dumps({n: j.get("relocation_wait") for n, j in joins.items()}))
    check(label, "join notices: keeper and neighbor once each, drifter none",
          (joins.get("keeper") or {}).get("notices") == [NOTICE]
          and (joins.get("neighbor") or {}).get("notices") == [NOTICE]
          and not (joins.get("drifter") or {}).get("notices"),
          json.dumps({n: j.get("notices") for n, j in joins.items()}))
    waiting = {n: len(per_owner.get(n, [])) for n in ("keeper", "neighbor", "drifter")}
    check(label, "waiting at the join: keeper %(keeper)d, neighbor %(neighbor)d, drifter 0"
          % waiting, all((joins.get(n) or {}).get("waiting_at_join") == waiting[n]
                         for n in waiting),
          json.dumps({n: j.get("waiting_at_join") for n, j in joins.items()}))
    flow_checks(run, label, "keeper", (joins.get("keeper") or {}).get("flow") or {},
                packed["keeper"], waiting["keeper"], charcoal.get("keeper", 0),
                empty_items(empty, "keeper"))
    after_a = recovered(world)
    check(label, "after boot A: keeper's entries are gone, neighbor's wait (cleaned, "
          "described)", not any(k.startswith("recovered:keeper:") for k in after_a)
          and len([k for k in after_a if k.startswith("recovered:neighbor:")])
          == waiting["neighbor"] and all(
              "Packed " in codec.ItemStack.parse(v).meta.get("description", "")
              for k, v in after_a.items() if k.startswith("recovered:neighbor:")
              and codec.ItemStack.parse(v).name == PACKED), json.dumps(sorted(after_a)))
    placed = [{"id": p.get("match"), "pos": p.get("pos")}
              for p in ((joins.get("keeper") or {}).get("flow") or {}).get("placed") or []]

    b = boot(run, world, "%s_B_0.50.0" % label, REPO / "tools" / "luanti_headless.sh",
             dict(plan, flow=["neighbor"], lay_floor=False, recheck=placed),
             joins=(("neighbor", 20.0), ("keeper", 4.0)), reset=raised)
    obs = b.obs or {}
    check(label, "boot B (the same world again): ran clean, two joins",
          b.rc == 0 and obs.get("leaves") == 2 and not obs.get("errors"),
          "rc %d joins %s errors %s" % (b.rc, b.joins, obs.get("errors")))
    at_load = {k: v for k, v in (obs.get("at_load") or {}).items()}
    check(label, "boot B's load changed nothing: no clean-up, no reset, the entries as "
          "boot A left them", at_load == after_a and "map reset pass" not in b.log
          and it.storage(world, "grug_core").get("reset_world") == str(raised),
          "%s vs %s" % (sorted(at_load), sorted(after_a)))
    recheck = obs.get("recheck") or []
    check(label, "keeper's placed containers are still there with the receipt's contents",
          len(recheck) == len(packed["keeper"]) and all(r.get("same") for r in recheck),
          json.dumps(recheck))
    joins = {j["name"]: j for j in obs.get("joins") or []}
    check(label, "boot B notices: neighbor once, keeper none (nothing waits for keeper)",
          (joins.get("neighbor") or {}).get("notices") == [NOTICE]
          and not (joins.get("keeper") or {}).get("notices"),
          json.dumps({n: j.get("notices") for n, j in joins.items()}))
    flow_checks(run, label, "neighbor", (joins.get("neighbor") or {}).get("flow") or {},
                packed["neighbor"], waiting["neighbor"], charcoal.get("neighbor", 0),
                empty_items(empty, "neighbor"))
    check(label, "nothing waits any more", not any(k.startswith("recovered:")
                                                   for k in recovered(world)),
          json.dumps(sorted(recovered(world))))
    return a, b


def flow_checks(run, label, name, flow, containers, waiting, charcoal, plain):
    folder = run.evidence / "flows"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / ("%s_%s.json" % (label, name))).write_text(json.dumps(flow, indent=1,
                                                                    ensure_ascii=False) + "\n")
    check(label, "%s: the new draft stone's form shows no Belongings, also after a tab click"
          % name, flow.get("draft") is True and flow.get("opened_draft") is True
          and flow.get("draft_form_shown") is True and flow.get("draft_belongings") is False
          and flow.get("draft_recovered_list") is False
          and flow.get("draft_belongings_after_tab") is False,
          json.dumps({k: flow.get(k) for k in ("draft", "opened_draft", "draft_form_shown",
                                               "draft_belongings", "draft_recovered_list",
                                               "draft_belongings_after_tab")}))
    check(label, "%s: activated through the form, the tab 'Belongings (%d)' and its list"
          % (name, waiting), flow.get("active") is True
          and flow.get("belongings_label") == "Belongings (%d)" % waiting
          and flow.get("belongings_list") is True,
          json.dumps({k: flow.get(k) for k in ("active", "tabs", "belongings_list")}))
    taken = flow.get("taken") or []
    check(label, "%s: all %d entries taken as the engine moves them; none left" % (name, waiting),
          len(taken) == waiting and all(t.get("main_slot") for t in taken)
          and flow.get("left") == 0,
          json.dumps([{k: t.get(k) for k in ("name", "allowed", "put", "main_slot")}
                      for t in taken]))
    descriptions = [t.get("description", "").split("\n")[0] for t in taken
                    if t.get("name") == PACKED]
    check(label, "%s: every packed item is described ('Packed <container>, N stacks')" % name,
          descriptions and all(re.match(r"Packed .+, (\d+ stacks|1 stack)$", d)
                               for d in descriptions), json.dumps(descriptions))
    check(label, "%s: a packed container's drop is refused (it stays)" % name,
          flow.get("drop_refused") is True)
    placed = flow.get("placed") or []
    by_id = {p.get("match"): p for p in placed}
    check(label, "%s: every packed container placed, consumed and restored with exactly the "
          "receipt's contents" % name,
          len(placed) == len(containers) and all(p.get("consumed") for p in placed)
          and not any(p.get("protected") for p in placed)
          and sorted(by_id) == sorted(c["id"] for c in containers),
          json.dumps([{k: p.get(k) for k in ("packed_node", "node", "match", "consumed",
                                              "protected", "lists")} for p in placed]))
    if "furnace" in by_id:
        p = by_id["furnace"]
        later = next((l for l in flow.get("later") or [] if l.get("id") == "furnace"), {})
        check(label, "%s: the lit furnace comes back unlit (default:furnace, no timer), still "
              "so 3 s later" % name, p.get("node") == "default:furnace" and p.get("timer") is False
              and later.get("node") == "default:furnace" and later.get("timer") is False,
              json.dumps([p, later]))
    if "locked_chest" in by_id:
        check(label, "%s: the locked chest is owned by its placer" % name,
              by_id["locked_chest"].get("owner") == name, by_id["locked_chest"].get("owner"))
    if "relic_chest" in by_id:
        removed = by_id["relic_chest"].get("removed") or []
        check(label, "%s: the chest with the unknown item comes back without it, the rest "
              "exact" % name, len(removed) == 1 and removed[0].startswith(RELIC), str(removed))
    check(label, "%s: every placed container unchanged 3 s later" % name,
          len(flow.get("later") or []) == len(placed)
          and all(l.get("same") for l in flow.get("later") or []), json.dumps(flow.get("later")))
    check(label, "%s: %d charcoal taken (the pass's count)" % (name, charcoal),
          flow.get("charcoal") == charcoal, str(flow.get("charcoal")))
    got = {}
    for t in taken:
        if t.get("name") not in (PACKED, CHARCOAL) and t.get("main_slot"):
            got[t["name"]] = got.get(t["name"], 0) + t.get("count", 0)
    want = plain if numbers.get("empty_mode") == "plain" else {}
    check(label, "%s: the empty containers as plain node items: %s" % (name, want or "none "
          "(not packed)"), got == want, json.dumps(got))
    check(label, "%s: with nothing waiting, the form has no Belongings tab" % name,
          flow.get("final_belongings") is False)


def sqlite_backend(run, w0, receipt):
    w = run.root / "w_sqlite"
    shutil.copytree(w0, w)
    dump_before, digest_before = it.dump(w), map_digest(w)
    c = tool(run, "sqlite_check", w, "--check", "--map-reset")
    check("sqlite", "--check --map-reset wrote nothing", it.dump(w) == dump_before
          and map_digest(w) == digest_before)
    p = tool(run, "sqlite_pass", w, "--map-reset")
    rows, per_owner, charcoal, counts = check_pass(run, "sqlite", w, receipt, c, p, dump_before,
                                                   digest_before, "sqlite3")
    dump_after = it.dump(w)
    it.world_diff(run, "sqlite_pass", dump_before, dump_after)
    removed = sorted(set(dump_before) - set(dump_after))
    added = sorted(set(dump_after) - set(dump_before))
    check("sqlite", "the pass only added mod storage keys (grug_housing recovered:* and "
          "pack_seq, grug_core map_reset_pack:1); map, players and auth unchanged",
          not removed and added and all(
              re.match(r"'storage' \| 'grug_housing' \| '(recovered:|pack_seq)", l)
              or l.startswith("'storage' | 'grug_core' | 'map_reset_pack:1' |") for l in added)
          and map_digest(w) == digest_before, json.dumps({"removed": removed[:4],
                                                          "added": added[:4]}))
    note_numbers("sqlite", p, counts)
    n, left = empty_map(w)
    check("sqlite", "the map emptied as the platform does (the map rows only): %d rows" % n,
          left == 0 and n == digest_before[0] and it.dump(w) == dump_after)
    return w, (rows, per_owner, charcoal)


def note_numbers(label, p, counts):
    done = event(p["events"], "pack_done")
    claims = re.findall(r"claim (\d+) \((\w+)\): (\d+) blocks, (\d+) container\(s\), ([\d.]+) s",
                        p["stderr"])
    numbers[label] = {"tool_wall_s": p["wall"], "pack_done_s": done.get("seconds"),
                      "counts": counts, "nodes": done.get("nodes"), "empty": done.get("empty"),
                      "claims": [{"id": int(i), "owner": o, "blocks": int(b),
                                  "containers": int(n), "seconds": float(s)}
                                 for i, o, b, n, s in claims]}


def pg_backend(run, w0, receipt, sqlite_rows):
    work = run.root / "pg"
    work.mkdir()
    source = run.root / "w_source"
    shutil.copytree(w0, source)
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-e", "PYTHONDONTWRITEBYTECODE=1",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), IMAGE, "python3", "tools/r50_paccept/pg_pass.py", str(work),
           str(source)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    (run.evidence / "pg_container.txt").write_text(sanitize(proc.stdout + proc.stderr[-3000:]))
    result = json.loads((work / "pg_pass.json").read_text()) if (work / "pg_pass.json").exists() \
        else {}
    for r in result.get("results") or []:
        check("pg", r["name"], r["ok"], r.get("detail", ""))
    check("pg", "the container part passed", proc.returncode == 0, proc.stderr[-500:])
    folder = run.evidence / "tool"
    for f in (work / "pg_events").glob("*"):
        (folder / ("pg_" + f.name)).write_text(sanitize(f.read_text()))
    events = result.get("events") or {}
    times = result.get("times") or {}
    c = {"rc": times.get("check", {}).get("exit"), "events": events.get("check") or []}
    p = {"rc": times.get("pass", {}).get("exit"), "events": events.get("pass") or [],
         "clock": times.get("pass", {}).get("clock") or [0, 0],
         "wall": times.get("pass", {}).get("wall"),
         "stderr": (work / "pg_events" / "pass.txt").read_text()
         if (work / "pg_events" / "pass.txt").exists() else ""}
    # The engine's boots: the pass's mod storage with the 0.48.1 player and
    # auth files (unchanged on PostgreSQL, checked above), the map emptied.
    w = run.root / "w_pg_boot"
    shutil.copytree(w0, w)
    shutil.copy(work / "w_pg" / "mod_storage.sqlite", w / "mod_storage.sqlite")
    rows, per_owner, charcoal, counts = check_pass(run, "pg", w, receipt, c, p, None, None,
                                                   "postgresql")
    check("pg", "the PostgreSQL pass wrote the same entries as the SQLite pass",
          rows == sqlite_rows, "%d vs %d rows" % (len(rows), len(sqlite_rows)))
    note_numbers("pg", p, counts)
    numbers["pg"]["map_rows"] = result.get("map_rows")
    n, left = empty_map(w)
    check("pg", "the boot world's map is empty (TRUNCATE on PostgreSQL; here the copy's "
          "rows deleted)", left == 0)
    run.pg_dump = work / "platform.dump"
    run.pg_dump_compression = result.get("dump_compression")
    return w, (rows, per_owner, charcoal)


def package_fixture(run, w0, receipt, target):
    target.mkdir(parents=True, exist_ok=True)
    archive = target / "world-0.48.1.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(w0, arcname="world-0.48.1")
    shutil.copy(run.evidence / "receipt.json", target / "receipt.json")
    if getattr(run, "pg_dump", None) and run.pg_dump.exists():
        shutil.copy(run.pg_dump, target / "platform-pg.dump")
    sq = numbers.get("sqlite") or {}
    packed, empty, outside = expected(receipt)
    claims = {c["owner"]: c for c in receipt["claims"]}
    lines = [
        "# Grudgelands 0.48.1 platform fixture (Round 50 PACCEPT)",
        "",
        "A world written by the real 0.48.1 game (commit 1ef11b5e) with Luanti 5.17,",
        "seed 42, built by `tools/r50_paccept/e2e.py` (probe `grug_probe_r50_paccept`).",
        "",
        "- `world-0.48.1.tar.gz`: the world folder as the 0.48.1 game left it at its",
        "  shutdown (SQLite throughout: map, players, auth, mod storage). The",
        "  world's version record (`grug_core` `world_version`) is `0.48.1`.",
        "- `platform-pg.dump`: the same map, player and auth rows in PostgreSQL,",
        "  the platform's layout (`pg_dump -Fc --no-owner --no-acl`, compression %s;"
        % getattr(run, "pg_dump_compression", "?"),
        "  the engine's tables of database-postgresql.cpp). Mod storage stays the",
        "  world folder's `mod_storage.sqlite`.",
        "- `receipt.json`: every container as the 0.48.1 game held it at the save",
        "  (node, lists as item strings, position, owner), the claims (centre,",
        "  `paid_until`), the sites.",
        "",
        "Players: keeper (claim %d, %d containers with items, %d empty), neighbor"
        % (claims["keeper"]["id"], len(packed.get("keeper", [])), len(empty.get("keeper", []))),
        "(claim %d, %d container), drifter (no claim). Outside every claim: %s."
        % (claims["neighbor"]["id"], len(packed.get("neighbor", [])),
           ", ".join(c["id"] for c in outside)),
        "keeper's lit furnace is `default:furnace_active` at the save; one chest holds",
        "`%s`, which 0.50.0 does not register (the first start drops it)." % RELIC,
        "",
        "Expected `--map-reset` pass with the 0.50.0 tool (measured on this world):",
        "",
        "    pack_done counts %s" % json.dumps(sq.get("counts")),
        "",
        "`charcoal` follows the clock: ceil((paid_until - now) / 26160) per claim,",
        "paid_until keeper %d, neighbor %d (Unix seconds)."
        % (claims["keeper"]["paid_until"], claims["neighbor"]["paid_until"]),
        "Blocks read per claim: %s." % ", ".join(
            "claim %d %d blocks" % (c["id"], c["blocks"]) for c in sq.get("claims") or []),
        "",
        "Then: empty the map (TRUNCATE public.blocks), raise grug_reset_world, start",
        "0.50.0. keeper and neighbor get the notice \"%s\"" % NOTICE,
        "at the join; their activated new Claim Stone shows the Belongings tab.",
    ]
    (target / "README.md").write_text("\n".join(lines) + "\n")
    sizes = {p.name: p.stat().st_size for p in target.iterdir() if p.is_file()}
    numbers["fixture"] = {"dir": str(target), "sizes": sizes,
                          "world_files": sorted(p.name for p in w0.iterdir())}
    return sizes


def scenario(run):
    w0, receipt = build_old_world(run)
    pristine = run.root / "w0481_pristine"
    shutil.copytree(w0, pristine)
    w_sqlite, sqlite_info = sqlite_backend(run, w0, receipt)
    w_pg, pg_info = pg_backend(run, pristine, receipt, sqlite_info[0])
    fixture = os.environ.get("FIXTURE")
    if fixture:
        package_fixture(run, pristine, receipt, Path(fixture))
    run_backend(run, "sqlite", w_sqlite, receipt, sqlite_info)
    run_backend(run, "pg", w_pg, receipt, pg_info)


def main(argv):
    evidence = Path(argv[0]) if argv else HERE / "evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, checkout game %s, old game %s" % (
        run.root, run.port, it.GAME, OLD_GAME), flush=True)
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
        summary = "%d checks, %d failed" % (len(results), len(failed))
        text = "\n".join(table + ["", summary] + ["FAIL %s: %s" % (r[1], r[3]) for r in failed])
        (evidence / "results.txt").write_text(sanitize(text) + "\n")
        (evidence / "numbers.json").write_text(json.dumps(numbers, indent=1) + "\n")
        print("\n" + text)
        if os.environ.get("KEEP") == "1":
            print("kept: %s" % run.root)
        else:
            shutil.rmtree(run.root, ignore_errors=True)
            shutil.rmtree("/tmp/grudgelands-headless-failed/" + run.root.name,
                          ignore_errors=True)
    return 0 if it.results and not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
