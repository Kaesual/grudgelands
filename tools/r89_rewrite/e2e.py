#!/usr/bin/env python3
"""Round 89 lane REWRITE: the end-to-end test of the migration step 0.89.0 and
the two-boot proof of the arena halls' box rewrite (round89-plan.md §3 "The
hall rewrite", upgrade contract §5.9). It reuses Round 43 IT's harness
(tools/r43_it/it.py) and follows Round 69's camp test (tools/r69_camp/e2e.py).

"Old" is the game at a commit (OLD, default the round's base at 0.88.0),
exported with git archive; "new" is a copy of this working tree, its
game.conf raised to 0.89.0 when it is still below (a test-only patch until
lane D sets the version). With TEST_TEMPLATES=1 the copy's two hall
templates are swapped for visibly different test-only ones (test_template
below), so old and new differ before the real templates exist; the
repository's templates are never touched.

  boot S   the old game on a new world, seed 42: one hall with its ring
           generated, one straddling a mapchunk border on one side only (if
           the seed gives one); old metadata and a node timer on a box cell;
           the old design's cells of both boxes; "visitor" joins; dump. Then
           the visitor's row is given the Accord's hall stone as discovered
           (the exact text a discovery stores) and the Accord as faction
  boot R   the new game without the tool: refused, nothing written
  tool     --check, the migration, --check: only the world marker
  boot C   the new game: killed (SIGKILL) once the first hall's write line is
           in the log, polled every 0.2 s. Between the halls, deterministic
           since Round 89 HALLS' rerun: in the crash phase the probe holds
           every emerge asked for after that line (the second hall's never
           calls back; hall_rewrite.lua looks core.emerge_area up at each
           call), so the server waits there until the kill, one hall
           written, and the key stays. (The TEST_TEMPLATES receipt of
           2026-11-28, before the hold, shows both halls written ahead of
           the kill, the second emerge taking 0.2 s.)
  boot Z   the next start finishes the job, with "visitor" joining during it;
           both halls with their ring emerged; the stones; dump
  boot N   a new world of the same seed, the new game: no job, no marker, no
           key; the same; dump
  compare  every box cell of the migrated world equals the new world's (name
           and param2; the light of the box's air and of the ring too), the
           ring equals the old world's where that existed and the new world's
           everywhere; old and new design differ in both halls (on a mapchunk
           border where a box crosses one); metadata and timers gone from the
           boxes, the ring's kept; the stones as in the new world; no box node
           needs an initialisation
  boot A   the pending key written again, and one written cell reverted after
           the job's last write: the read-back finds it, a second pass mends
           it, and the repeat leaves the same bytes
  boot M   a copy of the old world through the tool's --map-reset, the map
           emptied, the reset raised: starts, no job, the marker gone

Usage: tools/r89_rewrite/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
Environment: OLD=<commit> (default 023f420d), TEST_TEMPLATES=1, KEEP=1.
"""

import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)

OLD = os.environ.get("OLD", "023f420d")   # round89's base: main at 0.88.0 plus the plan
NEW_VERSION = "0.89.0"
TEST_TEMPLATES = os.environ.get("TEST_TEMPLATES") == "1"
PROBE = HERE / "grug_probe_r89_rewrite"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern +
                              r"|\[r89_rewrite_probe\]|\[grug_mapgen\] (arena hall|the arena halls)")
check = it.check
PENDING = "hall_rewrite"
MARKER = "migrate_world:" + NEW_VERSION
HALLS = ("accord", "throng")
BOX_CELLS = 21 * 19 * 31
TEMPLATES = Path("mods/MAPGEN/grug_mapgen/building_templates/templates")
GAME_FILES = ["game.conf", "mods", "minetest.conf", "settingtypes.txt", "menu"]
TOOL_FILES = ["tools/luanti_headless.sh", "tools/migrate.py", "tools/migration",
              "tools/web_data"]


def parsed(version):
    return tuple(int(part) for part in version.split("."))


def version_of(tree):
    match = re.search(r"^version\s*=\s*(\S+)", (tree / "game.conf").read_text(), re.M)
    return match and match.group(1)


def test_template(text):
    """A visibly different hall from a template, the box and the points kept:
    from layer 2 up, some air becomes obsidian and some solids become air, in
    a pattern over every column (a mapchunk border through the box then has
    changed cells on both sides); below layer 8 the rows 13 to 17 (the
    waystone's marker stack, the arrival and the muster cells) stay, and the
    floor and the layer above it everywhere."""
    out, layer, row, legend = [], None, 0, False
    for line in text.split("\n"):
        match = re.match(r"^layer (\d+)$", line)
        if line == "legend":
            legend = True
        elif legend and line == "end":
            out.append("J node default:obsidian_block")
            legend = False
        elif match:
            layer, row = int(match.group(1)), 0
        elif line == "points":
            layer = None
        elif layer is not None and line.startswith("|"):
            cells = list(line[1:-1])
            if layer >= 8 or (layer >= 2 and not 13 <= row <= 17):
                for x, cell in enumerate(cells):
                    if cell == "." and (x + 2 * row + layer) % 6 == 0:
                        cells[x] = "J"
                    elif cell not in ". " and (2 * x + row + layer) % 5 == 0:
                        cells[x] = "."
            line = "|" + "".join(cells) + "|"
            row += 1
        out.append(line)
    return "\n".join(out)


def export_old(run):
    target = run.root / "old"
    target.mkdir()
    archive = subprocess.run(["git", "-C", str(REPO), "archive", OLD, *GAME_FILES,
                              "tools/luanti_headless.sh"], capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = version_of(target)
    check("setup", "the old game %s exported (%s, below %s)" % (OLD, version, NEW_VERSION),
          version and parsed(version) < parsed(NEW_VERSION), str(version))
    return target, version


def stage_new(run):
    target = run.root / "new"
    for name in GAME_FILES + TOOL_FILES:
        source, dest = REPO / name, target / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, dest, ignore=shutil.ignore_patterns("__pycache__"))
        else:
            shutil.copy2(source, dest)
    notes = []
    version = version_of(target)
    if parsed(version) < parsed(NEW_VERSION):
        conf = target / "game.conf"
        conf.write_text(re.sub(r"^version\s*=.*$", "version = " + NEW_VERSION,
                               conf.read_text(), count=1, flags=re.M))
        notes.append("game.conf %s raised to %s (test only)" % (version, NEW_VERSION))
    if TEST_TEMPLATES:
        for hall in HALLS:
            path = target / TEMPLATES / ("breach_%s.tpl" % hall)
            path.write_text(test_template(path.read_text()))
        notes.append("test-only hall templates")
    check("setup", "the new game staged from the working tree at %s%s" % (
        version_of(target), (": " + "; ".join(notes)) if notes else ""),
          version_of(target) == NEW_VERSION)
    return target


def tool(run, case, world, *flags):
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-e", "PYTHONDONTWRITEBYTECODE=1", "-v", "%s:%s" % (run.root, run.root),
           "-w", str(run.root / "new"), it.IMAGE, "python3", "tools/migrate.py", "--world",
           str(world), *flags]
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


def load_dump(world, phase):
    """hall id -> {low, high, min, max, cells: {(x, y, z): (name, param2, light)},
    meta: set, timers: set, design: {(x, y, z): (name, param2)}}."""
    halls, hall = {}, None
    for line in (world / ("r89_dump_%s.txt" % phase)).read_text().splitlines():
        word, _, rest = line.partition(" ")
        if word == "hall":
            parts = rest.split()
            n = [int(v) for v in parts[1:]]
            hall = halls[parts[0]] = {"low": n[:3], "high": n[3:6], "min": n[6:9], "max": n[9:12]}
        elif word == "palette":
            hall["names"] = rest.split()
        elif word == "cells":
            (x0, y0, z0), (x1, y1, z1) = hall["low"], hall["high"]
            tokens, at, cells = rest.split(), 0, {}
            for z in range(z0, z1 + 1):
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        n, p2, light = tokens[at].split(":")
                        cells[(x, y, z)] = (hall["names"][int(n) - 1], int(p2), int(light))
                        at += 1
            hall["cells"] = cells
        elif word in ("meta", "timers"):
            hall[word] = {tuple(int(v) for v in p.split(",")) for p in rest.split()}
        elif word == "design":
            (x0, y0, z0), (x1, y1, z1) = hall["min"], hall["max"]
            tokens, at, design = rest.split(), 0, {}
            for z in range(z0, z1 + 1):
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        name, p2 = tokens[at].rsplit(":", 1)
                        design[(x, y, z)] = (name, int(p2))
                        at += 1
            hall["design"] = design
    return halls


def in_box(hall, pos):
    return all(hall["min"][i] <= pos[i] <= hall["max"][i] for i in range(3))


def diff(a, b, cells, light=False):
    width = 3 if light else 2
    return [p for p in cells if a["cells"][p][:width] != b["cells"][p][:width]]


def chunk(v):
    return (v + 32) // 80


def kill_after_first_write(run, stop):
    pattern = "^luanti.bin --server --gameid grudgelands --world %s/" % run.root
    before = it.server_logs(run.root)
    while not stop.is_set():
        for log in it.server_logs(run.root) - before:
            if "[grug_mapgen] arena hall" in log.read_text(errors="replace"):
                subprocess.run(["pkill", "-KILL", "-f", pattern])
                return
        time.sleep(0.2)


def seed_visitor(world, waypoints):
    """With the server stopped: the visitor is a character of the Accord who
    discovered its hall's stone (the text a discovery stores)."""
    conn = sqlite3.connect(world / "players.sqlite")
    for key, value in (("grug_factions:faction", "accord"), ("grug_home:waypoints", waypoints)):
        conn.execute("DELETE FROM player_metadata WHERE player = 'visitor' AND metadata = ?",
                     (key,))
        conn.execute("INSERT INTO player_metadata (player, metadata, value) VALUES "
                     "('visitor', ?, ?)", (key, value))
    conn.commit()
    conn.close()


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)
    old_tree, old_version = export_old(run)
    new_tree = stage_new(run)

    # Boot S.
    it.LAUNCHER = old_tree / "tools" / "luanti_headless.sh"
    s = it.boot(run, w, "setup_%s" % old_version, joins=("visitor",))
    obs_old = s.obs or {}
    check("setup", "boot S (%s): a new world, a hall emerged as planned, the visitor joined"
          % old_version,
          s.rc == 0 and obs_old.get("finish") == "setup" and obs_old.get("leaves") == 1 and
          it.storage(w, "grug_core").get("world_version") == old_version,
          "rc %d %s" % (s.rc, json.dumps({k: v for k, v in obs_old.items()
                                          if k not in ("box_nodes", "halls")})))
    old = load_dump(w, "setup_%s" % old_version)
    full = obs_old["full"]

    def ignored(hall):
        return sum(1 for p, c in hall["cells"].items() if in_box(hall, p) and c[0] == "ignore")
    state = {h: "whole" if ignored(old[h]) == 0 else
             "untouched" if ignored(old[h]) == BOX_CELLS else "partly" for h in HALLS}
    straddles = {h: [a for a, v in sorted(obs_old["halls"][h]["straddles"].items()) if v]
                 for h in HALLS}
    check("setup", "the halls: %s; mapchunk borders crossed: %s" % (
        ", ".join("%s %s (%d of %d cells missing)" % (h, state[h], ignored(old[h]), BOX_CELLS)
                  for h in HALLS), json.dumps(straddles)),
          state[full] == "whole" and (obs_old.get("partial") is None or
                                      state[obs_old["partial"]] == "partly"))
    waypoints = obs_old["discovered"]["accord"]
    check("setup", "a discovery of the Accord's hall stone stores %r" % waypoints,
          "breach_road_accord" in waypoints.split())
    seed_visitor(w, waypoints)
    dump_before = it.dump(w)
    reset_world = run.root / "w_reset"
    shutil.copytree(w, reset_world)

    # Boot R.
    it.LAUNCHER = new_tree / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % NEW_VERSION)
    check("guard", "boot R: the %s world without the tool is refused, naming the step"
          % old_version,
          it.refused_with(r, "This world is at version %s and needs the migration step %s "
                             "before this game's version %s can start it"
                          % (old_version, NEW_VERSION, NEW_VERSION),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool.
    rc, ev = tool(run, "check_before", w, "--check")
    done = it.last(ev)
    check("tool", "--check: world %s, due [%s], nothing written" % (old_version, NEW_VERSION),
          rc == 0 and done.get("world_version") == old_version
          and done.get("due") == [NEW_VERSION] and it.dump(w) == dump_before,
          "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = tool(run, "migrate", w)
    step = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: exit 0, one marker, nothing else",
          rc == 0 and it.last(ev).get("applied") == [NEW_VERSION] and
          (step.get("counts") or {}).get("markers") == 1 and
          (step.get("counts") or {}).get("mod_storage") == 0, json.dumps(step))
    changed = sorted(set(dump_before) ^ set(it.dump(w)))
    check("tool", "only the marker and the record changed",
          len(changed) == 3 and all("'grug_core'" in line and
                                    ("world_version" in line or MARKER in line)
                                    for line in changed), json.dumps(changed))
    rc, ev = tool(run, "check_after", w, "--check")
    check("tool", "--check after: world %s, nothing due" % NEW_VERSION,
          rc == 0 and it.last(ev).get("world_version") == NEW_VERSION and
          it.last(ev).get("due") == [], json.dumps(it.last(ev)))

    # Boot C: killed during the job.
    stop = threading.Event()
    killer = threading.Thread(target=kill_after_first_write, args=(run, stop))
    killer.start()
    c = it.boot(run, w, "crash")
    stop.set()
    killer.join()
    rewritten = re.findall(r"\[grug_mapgen\] arena hall (\S+) rewritten", c.log)
    core_store = it.storage(w, "grug_core")
    check("crash", "boot C: killed between the halls, after %d hall(s) were written; the "
                   "world is left pending or marked" % len(rewritten),
          len(rewritten) == 1 and "holding an emerge after the first hall's write" in c.log and
          "every box read back" not in c.log and
          (it.storage(w, "grug_mapgen").get(PENDING) or core_store.get(MARKER)),
          json.dumps({"rc": c.rc, "rewritten": rewritten, "marker": core_store.get(MARKER),
                      "pending": it.storage(w, "grug_mapgen").get(PENDING)}))

    # Boot Z: the job ends, with a join during it.
    z = it.boot(run, w, "resume", joins=("visitor",))
    obs = z.obs or {}
    times = re.findall(r"arena hall (\S+) rewritten: (\d+) cells, emerge ([\d.]+) s, "
                       r"write ([\d.]+) ms", z.log)
    (run.evidence / "times.txt").write_text("\n".join(" ".join(t) for t in times) + "\n")
    check("resume", "boot Z: the next start finishes both halls while a player joins",
          z.rc == 0 and obs.get("finish") == "resume" and len(times) == 2 and
          all(int(t[1]) == BOX_CELLS for t in times) and obs.get("leaves") == 1 and
          "every box read back" in z.log,
          "rc %d joins %s %s" % (z.rc, z.joins, json.dumps(times)))
    check("resume", "the marker and the pending key are gone, the record is %s" % NEW_VERSION,
          not it.storage(w, "grug_mapgen").get(PENDING) and
          not it.storage(w, "grug_core").get(MARKER) and
          it.storage(w, "grug_core").get("world_version") == NEW_VERSION)
    known = obs.get("visitor_known") or []
    check("resume", "the visitor still has the Accord's hall stone: in the waystone list at the"
                    " join, and in the stored row after it",
          known and all("breach_road_accord" in k.split() for k in known) and
          it.player_meta(w, "visitor").get("grug_home:waypoints") == waypoints,
          json.dumps([known, it.player_meta(w, "visitor").get("grug_home:waypoints")]))
    new = load_dump(w, "resume")

    # Boot N: a new world of the same seed.
    n_world = run.root / "fresh"
    it.write_world_mt(n_world, mod_storage=True)
    n = it.boot(run, n_world, "fresh")
    obs_new = n.obs or {}
    check("fresh", "boot N: a new world, no migration crossed, no job, no marker, no key",
          n.rc == 0 and obs_new.get("finish") == "fresh" and
          (obs_new.get("load") or {}).get("new_world") is True and
          not re.search(r"arena hall \S+ rewritten", n.log) and
          PENDING not in it.storage(n_world, "grug_mapgen") and
          MARKER not in it.storage(n_world, "grug_core"),
          "rc %d %s" % (n.rc, json.dumps(obs_new.get("load"))))
    fresh = load_dump(n_world, "fresh")

    # The new design needs nothing initialised: the live registrations of a
    # new world's box nodes.
    facts = obs_new.get("box_nodes") or {}
    active = {k: f for k, f in facts.items()
              if f["on_construct"] or f["on_timer"] or f["after_place"] or f["lbm"]}
    (run.evidence / "box_nodes.json").write_text(json.dumps(facts, indent=1, sort_keys=True))
    check("proof", "no box node of either hall has on_construct, on_timer, after_place or an "
                   "LBM (%d node types)" % len(facts), len(facts) >= 5 and not active,
          json.dumps(active))

    # The stones.
    stones, stones_new = obs.get("stones") or {}, obs_new.get("stones") or {}
    (run.evidence / "stones.json").write_text(json.dumps(stones, indent=1, sort_keys=True))
    for h in HALLS:
        a, b = stones.get(h) or {}, stones_new.get(h) or {}
        arrival, layout = a.get("arrival") or {}, a.get("layout_arrival") or {}
        check("stones", "%s: the waystone on its cell, its arrival validated at the layout's "
                        "arrival, a right-click of its faction discovers it, no object in the box"
              % h, a.get("node") == "grug_mapgen:waystone" and a.get("cell") is True and
              arrival and round(arrival["x"]) == layout.get("x") and
              round(arrival["z"]) == layout.get("z") and
              ("breach_road_" + h) in a.get("discovered", "").split() and
              not a.get("objects"), json.dumps(a))   # (an empty list is JSON null)
        check("stones", "%s: the stone answers as in the new world" % h,
              {k: v for k, v in a.items() if k != "use"} ==
              {k: v for k, v in b.items() if k != "use"}, json.dumps([a, b]))

    # The comparison.
    lines = []
    for h in HALLS:
        a, b, o = new[h], fresh[h], old[h]
        box = [p for p in a["cells"] if in_box(a, p)]
        ring = [p for p in a["cells"] if not in_box(a, p)]
        wrong = diff(a, b, box)
        ring_fresh = diff(a, b, ring)
        had = [p for p in ring if o["cells"][p][0] != "ignore"]
        ring_old = diff(a, o, had)
        light_box = len(diff(a, b, box, light=True))
        light_ring = len(diff(a, b, ring, light=True))
        # A raw param1 byte may differ on a node: an opaque node's holds no
        # light, a lamp's day bank reads 15 or 14. Open air never differs.
        light_air = [p for p in diff(a, b, box, light=True) if a["cells"][p][0] == "air"]
        changed = [p for p in box if o["design"][p] != a["cells"][p][:2]]
        design_new = [p for p in box if b["design"][p] != b["cells"][p][:2]]
        lines.append("%s (%s): box %d cells, %d differ from the new world, light %d; ring %d "
                     "cells, %d differ from the new world, light %d; %d kept from %s, %d "
                     "differ; %d box cells changed from the old design"
                     % (h, state[h], len(box), len(wrong), light_box, len(ring),
                        len(ring_fresh), light_ring, len(had), old_version, len(ring_old),
                        len(changed)))
        check("proof", "%s (%s): every box cell equals the new world's" % (h, state[h]),
              len(box) == BOX_CELLS and not wrong, json.dumps(wrong[:6]))
        check("proof", "%s: the light of the box's air and of the ring equals the new world's"
              % h, not light_air and not light_ring, json.dumps([light_air[:6], light_ring]))
        check("proof", "%s: the ring equals the new world's" % h, not ring_fresh,
              json.dumps([(p, a["cells"][p], b["cells"][p]) for p in ring_fresh[:6]]))
        check("proof", "%s: the ring equals the %s world's where that existed" % (h, old_version),
              not ring_old, json.dumps([(p, a["cells"][p], o["cells"][p]) for p in ring_old[:6]]))
        check("proof", "%s: the new world's box is the new design (the probe's own reading of "
                       "the model)" % h, not design_new, json.dumps(design_new[:6]))
        check("proof", "%s: old and new design differ (%d cells)" % (h, len(changed)),
              len(changed) > 0)
        for axis in straddles[h]:
            i = "xyz".index(axis)
            border = -32 + 80 * chunk(a["max"][i])
            near = [p for p in changed if p[i] in (border - 1, border)]
            check("proof", "%s: changed cells on both sides of the mapchunk border %s = %d (%d)"
                  % (h, axis, border, len(near)),
                  any(p[i] == border - 1 for p in near) and any(p[i] == border for p in near))
    (run.evidence / "digest.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)
    wn = new[full]
    inside = tuple(obs_old["old_meta"][k] for k in "xyz")
    ring_meta = tuple(obs_old["ring_meta"][k] for k in "xyz")
    check("proof", "old metadata and the timer left the box; no metadata in either box",
          inside in old[full]["meta"] and inside in old[full]["timers"] and
          inside not in wn["meta"] and inside not in wn["timers"] and
          not [p for h in HALLS for p in new[h]["meta"] if in_box(new[h], p)],
          json.dumps(sorted(wn["meta"])[:8]))
    check("proof", "the ring's metadata stays", ring_meta in wn["meta"])

    # Boot A: a repeat.
    conn = sqlite3.connect(w / "mod_storage.sqlite")
    conn.execute("INSERT OR REPLACE INTO entries (modname, key, value) VALUES (?, ?, ?)",
                 ("grug_mapgen", PENDING.encode(), b"1"))
    conn.commit()
    conn.close()
    a = it.boot(run, w, "repeat")
    again = load_dump(w, "repeat")
    same = all(diff(again[h], new[h], list(new[h]["cells"])) == [] for h in HALLS)
    check("repeat", "boot A: the job again changes no node, and a cell reverted after the "
                    "last write is found by the read-back and written back",
          a.rc == 0 and same and (a.obs or {}).get("reverted") and
          len(re.findall(r"arena hall \S+ rewritten", a.log)) == 4 and
          "the arena halls' read-back found" in a.log and
          "every box read back" in a.log and not it.storage(w, "grug_mapgen").get(PENDING),
          "rc %d %s" % (a.rc, json.dumps((a.obs or {}).get("reverted"))))

    # Boot M: 0.89.0 and a map reset together.
    rc, ev = tool(run, "map_reset", reset_world, "--map-reset")
    check("reset", "the tool's --map-reset runs the step", rc == 0 and
          it.last(ev).get("map_reset") is True and it.last(ev).get("applied") == [NEW_VERSION],
          "exit %d %s" % (rc, json.dumps(it.last(ev))))
    conn = sqlite3.connect(reset_world / "map.sqlite")
    conn.execute("DELETE FROM blocks")
    conn.commit()
    conn.close()
    m = it.boot(run, reset_world, "reset", known=[], reset=True)
    check("reset", "boot M: %s with a map reset starts; no job, the marker gone, no key"
          % NEW_VERSION, m.rc == 0 and (m.obs or {}).get("finish") == "reset" and
          not re.search(r"arena hall \S+ rewritten", m.log) and
          not it.storage(reset_world, "grug_mapgen").get(PENDING) and
          not it.storage(reset_world, "grug_core").get(MARKER),
          "rc %d" % m.rc)


def main(argv):
    evidence = Path(argv[0] if argv else HERE / "evidence").resolve()
    if evidence.exists():
        shutil.rmtree(evidence)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, old %s, test templates %s" % (
        run.root, run.port, OLD, TEST_TEMPLATES), flush=True)
    started = time.monotonic()
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
        summary = "%d checks, %d failed, %d s" % (len(results), len(failed),
                                                   time.monotonic() - started)
        text = "\n".join(table + ["", summary] + ["FAIL %s: %s" % (r[1], r[3]) for r in failed])
        (evidence / "results.txt").write_text(text + "\n")
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
