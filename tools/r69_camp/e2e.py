#!/usr/bin/env python3
"""Round 69 lane CAMP: the end-to-end test of the migration step 0.69.0 and
the two-boot proof of the camp box rewrite (round69-plan.md rulings 4 to 6).
It reuses Round 43 IT's harness (tools/r43_it/it.py).

  boot S   the 0.68.0 game on a new world, seed 42: one camp with its ring
           generated, one straddling a mapchunk border on one side only, four
           untouched; old metadata and a node timer on a box cell; dump
  boot R   this checkout's game without the tool: refused, nothing written
  tool     --check, the migration, --check: only the world marker
  boot C   this checkout's game: killed (SIGKILL) right after the first camp
  boot Z   the next start finishes the job, with a player joining during it;
           every camp with its ring emerged; dump
  boot N   a new world of the same seed, this checkout's game: no job, no
           marker, no key; every camp with its ring emerged; dump
  compare  every box cell of the migrated world equals the new world's (name
           and param2; light counted), the ring's equal the 0.68.0 world's
           where that existed and the new world's everywhere; metadata and
           timers gone from the boxes, the ring's kept; sockets and
           protection as in 0.68.0
  boot A   the pending key written again: a repeat leaves the same bytes
  boot M   a copy of the 0.68.0 world through the tool's --map-reset, the map
           emptied, the reset raised: starts, no job, the marker gone

Usage: tools/r69_camp/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import json
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

OLD = "e4837b6e"           # main at 0.68.0 plus the Round 69 plan (the base)
OLD_VERSION = "0.68.0"
NEW_VERSION = "0.69.0"
PROBE = HERE / "grug_probe_r69_camp"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern +
                              r"|\[r69_camp_probe\]|\[grug_mapgen\] (camp site|the camp sites)")
check = it.check
LAUNCHER = REPO / "tools" / "luanti_headless.sh"
RING = 8
PENDING = "camp_rewrite"
MARKER = "migrate_world:" + NEW_VERSION


def export_old(run):
    target = run.root / "v0_68_0"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.68.0 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def tool(run, case, world, *flags):
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), it.IMAGE, "python3", "tools/migrate.py", "--world", str(world),
           *flags]
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
    """camp id -> {box, outer, anchor, cells: {(x, y, z): (name, param2, light)},
    meta: set, timers: set}."""
    camps, camp = {}, None
    text = (world / ("r69_dump_%s.txt" % phase)).read_text()
    for line in text.splitlines():
        word, _, rest = line.partition(" ")
        if word == "camp":
            parts = rest.split()
            n = [int(v) for v in parts[1:]]
            camp = camps[parts[0]] = {"low": n[:3], "high": n[3:6], "anchor": n[6:9]}
        elif word == "palette":
            camp["names"] = rest.split()
        elif word == "cells":
            (x0, y0, z0), (x1, y1, z1) = camp["low"], camp["high"]
            tokens = rest.split()
            at, cells = 0, {}
            for z in range(z0, z1 + 1):
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        n, p2, light = tokens[at].split(":")
                        cells[(x, y, z)] = (camp["names"][int(n) - 1], int(p2), int(light))
                        at += 1
            camp["cells"] = cells
        elif word in ("meta", "timers"):
            camp[word] = {tuple(int(v) for v in p.split(",")) for p in rest.split()}
    return camps


def in_box(camp, pos):
    x, y, z = pos
    ax, ay, az = camp["anchor"]
    return abs(x - ax) <= 11 and abs(z - az) <= 11 and ay <= y <= ay + 9


def diff(a, b, cells, light=False):
    width = 3 if light else 2
    return [p for p in cells if a["cells"][p][:width] != b["cells"][p][:width]]


def kill_after_first_write(run, stop):
    pattern = "^luanti.bin --server --gameid grudgelands --world %s/" % run.root
    before = it.server_logs(run.root)
    while not stop.is_set():
        for log in it.server_logs(run.root) - before:
            if "[grug_mapgen] camp site" in log.read_text(errors="replace"):
                subprocess.run(["pkill", "-KILL", "-f", pattern])
                return
        time.sleep(0.2)


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_%s" % OLD_VERSION)
    obs_old = s.obs or {}
    check("setup", "boot S (0.68.0): a new world, the camps emerged as planned",
          s.rc == 0 and obs_old.get("finish") == "setup" and
          it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d %s" % (s.rc, json.dumps({k: v for k, v in obs_old.items() if k != "camps"})))
    old = load_dump(w, "setup_%s" % OLD_VERSION)
    full, partial = obs_old["full"], obs_old["partial"]
    untouched = sorted(set(old) - {full, partial})
    def ignored(camp):
        return sum(1 for p, c in camp["cells"].items() if in_box(camp, p) and c[0] == "ignore")
    check("setup", "%s whole, %s partly (%d of 5290 cells missing), %d camps untouched" %
          (full, partial, ignored(old[partial]), len(untouched)),
          ignored(old[full]) == 0 and 0 < ignored(old[partial]) < 5290 and
          all(ignored(old[c]) == 5290 for c in untouched) and len(untouched) == 4)
    check("setup", "the old design stands: wool in the whole camp's box",
          any(c[0].startswith("wool:") for p, c in old[full]["cells"].items()
              if in_box(old[full], p)))
    dump_before = it.dump(w)
    reset_world = run.root / "w_reset"
    shutil.copytree(w, reset_world)

    # Boot R.
    it.LAUNCHER = LAUNCHER
    r = it.boot(run, w, "refused_%s" % NEW_VERSION)
    check("guard", "boot R: the 0.68.0 world without the tool is refused, naming the step",
          it.refused_with(r, "This world is at version %s and needs the migration step %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, NEW_VERSION, NEW_VERSION),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool.
    rc, ev = tool(run, "check_before", w, "--check")
    done = it.last(ev)
    check("tool", "--check: world %s, due [%s], nothing written" % (OLD_VERSION, NEW_VERSION),
          rc == 0 and done.get("world_version") == OLD_VERSION
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

    # Boot C: killed during the job.
    stop = threading.Event()
    killer = threading.Thread(target=kill_after_first_write, args=(run, stop))
    killer.start()
    c = it.boot(run, w, "crash")
    stop.set()
    killer.join()
    rewritten = re.findall(r"\[grug_mapgen\] camp site (\S+) rewritten", c.log)
    core_store = it.storage(w, "grug_core")
    check("crash", "boot C: killed after %d camp(s) were written; the world is left pending"
                   " or marked" % len(rewritten),
          len(rewritten) >= 1 and len(rewritten) < 6 and
          (it.storage(w, "grug_mapgen").get(PENDING) or core_store.get(MARKER)),
          json.dumps({"rc": c.rc, "rewritten": rewritten, "marker": core_store.get(MARKER),
                      "pending": it.storage(w, "grug_mapgen").get(PENDING)}))

    # Boot Z: the job ends, with a join during it.
    z = it.boot(run, w, "resume", joins=("visitor",))
    obs = z.obs or {}
    times = re.findall(r"camp site (\S+) rewritten: (\d+) cells, emerge ([\d.]+) s, "
                       r"write ([\d.]+) ms", z.log)
    (run.evidence / "times.txt").write_text("\n".join(" ".join(t) for t in times) + "\n")
    check("resume", "boot Z: the next start finishes all six while a player joins",
          z.rc == 0 and obs.get("finish") == "resume" and len(times) == 6 and
          obs.get("leaves") == 1 and "the camp sites' rewrite is done" in z.log,
          "rc %d joins %s %s" % (z.rc, z.joins, json.dumps(times)))
    check("resume", "the marker and the pending key are gone, the record is %s" % NEW_VERSION,
          not it.storage(w, "grug_mapgen").get(PENDING) and
          not it.storage(w, "grug_core").get(MARKER) and
          it.storage(w, "grug_core").get("world_version") == NEW_VERSION)
    new = load_dump(w, "resume")

    # Boot N: a new world of the same seed.
    n_world = run.root / "fresh"
    it.write_world_mt(n_world, mod_storage=True)
    n = it.boot(run, n_world, "fresh", extra_args=())
    obs_new = n.obs or {}
    check("fresh", "boot N: a new world, no migration crossed, no job, no marker, no key",
          n.rc == 0 and obs_new.get("finish") == "fresh" and
          (obs_new.get("load") or {}).get("new_world") is True and
          not re.search(r"camp site \S+ rewritten", n.log) and
          PENDING not in it.storage(n_world, "grug_mapgen") and
          MARKER not in it.storage(n_world, "grug_core"),
          "rc %d %s" % (n.rc, json.dumps(obs_new.get("load"))))
    fresh = load_dump(n_world, "fresh")

    # Wallwright needs nothing initialised: the live registrations of a new
    # world's box nodes, not the design's word.
    facts = obs_new.get("box_nodes") or {}
    active = {n: f for n, f in facts.items()
              if f["on_construct"] or f["on_timer"] or f["after_place"] or f["lbm"]}
    (run.evidence / "box_nodes.json").write_text(json.dumps(facts, indent=1, sort_keys=True))
    check("proof", "no box node of any camp has on_construct, on_timer, after_place or an LBM "
                   "(%d node types)" % len(facts), len(facts) > 20 and not active,
          json.dumps(active))

    # The comparison.
    box_names = {c for p, c in new[full]["cells"].items() if in_box(new[full], p)}
    check("proof", "the new design stands in the whole camp: no wool, the Round 63 materials",
          not any(c[0].startswith("wool:") for c in box_names) and
          any(c[0].startswith("grug_mapgen:camp_stockade_") for c in box_names))
    lines = []
    for camp in sorted(new):
        a, b, o = new[camp], fresh[camp], old[camp]
        box = [p for p in a["cells"] if in_box(a, p)]
        ring = [p for p in a["cells"] if not in_box(a, p)]
        wrong = diff(a, b, box)
        ring_fresh = diff(a, b, ring)
        had = [p for p in ring if o["cells"][p][0] != "ignore"]
        ring_old = diff(a, o, had)
        light_box = len(diff(a, b, box, light=True))
        light_ring = len(diff(a, b, ring, light=True))
        status = "whole" if camp == full else "partly" if camp == partial else "untouched"
        # A raw param1 byte may differ on a node: an opaque node's holds no
        # light, a lantern's day bank reads 15 or 14. Open air never differs.
        light_air = [p for p in diff(a, b, box, light=True) if a["cells"][p][0] == "air"]
        lines.append("%s (%s): box %d cells, %d differ from the new world, light %d; ring %d "
                     "cells, %d differ from the new world, light %d; %d kept from 0.68.0, %d "
                     "differ" % (camp, status, len(box), len(wrong), light_box, len(ring),
                                 len(ring_fresh), light_ring, len(had), len(ring_old)))
        check("proof", "%s (%s): every box cell equals the new world's" % (camp, status),
              len(box) == 5290 and not wrong, json.dumps(wrong[:6]))
        check("proof", "%s: the light of the box's air and of the ring equals the new world's"
              % camp, not light_air and not light_ring,
              json.dumps([light_air[:6], light_ring]))
        check("proof", "%s: the ring equals the new world's" % camp, not ring_fresh,
              json.dumps([(p, a["cells"][p], b["cells"][p]) for p in ring_fresh[:6]]))
        check("proof", "%s: the ring equals the 0.68.0 world's where that existed" % camp,
              not ring_old, json.dumps([(p, a["cells"][p], o["cells"][p]) for p in ring_old[:6]]))
    (run.evidence / "digest.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)
    wn = new[full]
    inside = tuple(obs_old["old_meta"][k] for k in "xyz")
    ring_meta = tuple(obs_old["ring_meta"][k] for k in "xyz")
    root = (wn["anchor"][0], wn["anchor"][1] + 1, wn["anchor"][2])
    check("proof", "old metadata and the timer left the box, the anchor root's stays",
          inside in old[full]["meta"] and inside in old[full]["timers"] and
          inside not in wn["meta"] and inside not in wn["timers"] and
          not [p for p in wn["meta"] if in_box(wn, p) and p != root],
          json.dumps(sorted(wn["meta"])[:8]))
    check("proof", "the ring's metadata stays", ring_meta in wn["meta"])
    check("proof", "the sockets and the protection answer as in 0.68.0",
          obs.get("camps") == obs_old.get("camps") == obs_new.get("camps"))
    sample = obs_old["camps"][full]["protection"]
    (run.evidence / "protection.txt").write_text(json.dumps(sample, indent=1, sort_keys=True))
    check("proof", "protection: war_camp reaches 10 beyond the box in x and z, and 10 below "
                   "and 10 above it",
          all(sample[k].get("feature") == "war_camp" and sample[k].get("protected") is True
              for k in ("inside", "corner", "low", "high")) and
          not sample["beyond"].get("feature") and not sample["below"].get("feature") and
          not sample["above"].get("feature"), json.dumps(sample))

    # Boot A: a repeat.
    conn = sqlite3.connect(w / "mod_storage.sqlite")
    conn.execute("INSERT OR REPLACE INTO entries (modname, key, value) VALUES (?, ?, ?)",
                 ("grug_mapgen", PENDING.encode(), b"1"))
    conn.commit()
    conn.close()
    a = it.boot(run, w, "repeat")
    again = load_dump(w, "repeat")
    same = all(diff(again[c], new[c], list(new[c]["cells"])) == [] for c in new)
    check("repeat", "boot A: the job again changes no node",
          a.rc == 0 and len(re.findall(r"camp site \S+ rewritten", a.log)) == 6 and same,
          "rc %d" % a.rc)

    # Boot M: 0.69.0 and a map reset together.
    rc, ev = tool(run, "map_reset", reset_world, "--map-reset")
    check("reset", "the tool's --map-reset runs the step", rc == 0 and
          it.last(ev).get("map_reset") is True and it.last(ev).get("applied") == [NEW_VERSION],
          "exit %d %s" % (rc, json.dumps(it.last(ev))))
    conn = sqlite3.connect(reset_world / "map.sqlite")
    conn.execute("DELETE FROM blocks")
    conn.commit()
    conn.close()
    m = it.boot(run, reset_world, "reset", known=[], reset=True)
    check("reset", "boot M: 0.69.0 with a map reset starts; no job, the marker gone, no key",
          m.rc == 0 and (m.obs or {}).get("finish") == "reset" and
          not re.search(r"camp site \S+ rewritten", m.log) and
          not it.storage(reset_world, "grug_mapgen").get(PENDING) and
          not it.storage(reset_world, "grug_core").get(MARKER),
          "rc %d" % m.rc)


def main(argv):
    evidence = Path(argv[0] if argv else HERE / "evidence").resolve()
    if evidence.exists():
        shutil.rmtree(evidence)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d" % (run.root, run.port), flush=True)
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
