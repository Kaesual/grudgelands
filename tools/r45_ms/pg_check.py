#!/usr/bin/env python3
"""Round 45 lane MS: step 0.45.0's own writes on PostgreSQL.

Runs inside localhost/grudgelands-r43-it:trixie (started by e2e.py), as
Round 43 IT's pg_test.py does and with its helpers (a throwaway cluster in
the container, a role whose password only a PGPASSFILE carries, the
engine's table statements, seeding from an engine-written SQLite world).
The seed is the 0.44.0 world of tools/r45_ms/e2e.py right before its tool
run (WORK/pre_tool): a craft grid that fits and one that does not, plain
gear of several tiers (a T2 Iron Chestplate, a T2 Iron Bow in the grid, a
T2 Iron Sword in craftresult), mixtures in four lists and
grug_jobs:seen_items. The shipped command line migrates it on PostgreSQL
(all three backends) and in the platform's layout (player and auth on
PostgreSQL, mod storage in SQLite); every row must equal the SQLite world
after the same run (WORK/post_tool), which the game then loaded and
checked. Explicit checks name the step's writes: the grid stored with
size 0, the pin, the mixtures gone, the meta key deleted, the markers.

Writes WORK/pg_results.json and WORK/pg_events/<case>.jsonl; exit 0 when
every check passed.

Usage: python3 tools/r45_ms/pg_check.py WORK
"""

import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import pg_test as pg  # noqa: E402  (tools/r43_it/pg_test.py; reads sys.argv[1])
from migration.codec import ItemStack  # noqa: E402

WORK = pg.WORK
check = pg.check
COUNTS = {"characters": 3, "player_meta": 2, "inventories": 3, "positions": 0,
          "privileges": 0, "mod_storage": 0, "markers": 3}


def shipped(case, world):
    """The platform's command line, from the repository root."""
    env = dict(os.environ, PGPASSFILE="/tmp/it.pgpass", PGCONNECT_TIMEOUT="5")
    proc = subprocess.run(["python3", "tools/migrate.py", "--world", str(world)], cwd=REPO,
                          env=env, capture_output=True, text=True)
    events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
    (WORK / "pg_events").mkdir(exist_ok=True)
    (WORK / "pg_events" / (case + ".jsonl")).write_text(proc.stdout)
    if proc.returncode != 0:
        print(proc.stderr[-2000:])
    return proc.returncode, events


def step_writes(db, label):
    """The step's writes as PostgreSQL holds them."""
    with pg.connect(db) as conn:
        sizes = dict(((p, n), s) for p, n, s in conn.execute(
            "SELECT player, inv_name, inv_size FROM player_inventories "
            "WHERE inv_name IN ('craft', 'craftresult')").fetchall())
        items = conn.execute("SELECT player, i.inv_id, slot_id, item, inv_name FROM "
                             "player_inventory_items i JOIN player_inventories l USING "
                             "(player, inv_id) WHERE item != ''").fetchall()
        meta = conn.execute("SELECT player, attr, value FROM player_metadata WHERE attr IN "
                            "('grug_jobs:seen_items', 'grug_core:migrate:0.45.0')").fetchall()
    stacks = {(p, n, s): ItemStack.parse(t) for p, _, s, t, n in items}
    mixtures = [k for k, v in stacks.items() if v.name.startswith("grug_alchemy:mixture_")]
    chest = stacks.get(("smith", "grug_chest", 0))
    bow = stacks.get(("scribe", "main", 9))
    sword = stacks.get(("scribe", "main", 11))
    check("%s: the grids of scribe and sleeper stored with size 0, smith's kept at 9 with its "
          "leftovers; scribe's craftresult kept at 1, empty" % label,
          sizes.get(("scribe", "craft")) == 0 and sizes.get(("sleeper", "craft")) == 0
          and sizes.get(("smith", "craft")) == 9 and sizes.get(("scribe", "craftresult")) == 1
          and not any(k[:2] == ("scribe", "craftresult") for k in stacks),
          json.dumps({"%s %s" % k: v for k, v in sizes.items()}))
    check("%s: plain T2 gear pinned at 10 / 10 (smith's equipped Iron Chestplate, scribe's "
          "Iron Bow from the grid and Iron Sword from craftresult)" % label,
          all(s is not None and s.meta.get("grug_ilvl") == "10"
              and s.meta.get("grug_req_level") == "10" for s in (chest, bow, sword))
          and bow.name == "grug_gear:bow_iron" and sword.name == "grug_gear:sword_iron",
          json.dumps([s and s.to_string()[:60] for s in (chest, bow, sword)]))
    check("%s: no mixture left in any list" % label, not mixtures, json.dumps(mixtures))
    seen = [p for p, a, _ in meta if a == "grug_jobs:seen_items"]
    marked = sorted(p for p, a, v in meta if a == "grug_core:migrate:0.45.0" and v == "1")
    check("%s: grug_jobs:seen_items deleted, the marker on all three" % label,
          not seen and marked == ["scribe", "sleeper", "smith"], json.dumps(meta))


def main():
    pg_version, server = pg.start_postgres()
    check("postgres started", True, "cluster %s, server %s" % (pg_version, server))
    pre, post = pg.dump_sqlite(WORK / "pre_tool"), pg.dump_sqlite(WORK / "post_tool")
    world = pg.make_world("all_pg", "grug_it_all", True)
    pg.seed("grug_it_all", WORK / "pre_tool", True)
    seeded = pg.dump_pg("grug_it_all")
    check("pg seeding: rows equal the 0.44.0 SQLite world (a grid stack, plain T2 gear, "
          "mixtures, seen-items)", seeded == pre
          and any(attr == "grug_jobs:seen_items" for _, attr, _ in seeded["meta"])
          and any("mixture_" in item for *_, item in seeded["items"]), pg.diff(seeded, pre))
    rc, ev = shipped("all_migrate", world)
    done = pg.last(ev)
    step = next((e for e in ev if e.get("event") == "step_done"), {})
    check("pg migrate (all on PostgreSQL): step 0.45.0 from 0.44.0 with the SQLite run's counts",
          rc == 0 and done.get("applied") == ["0.45.0"] and step.get("counts") == COUNTS
          and done.get("backends") == {"player": "postgresql", "auth": "postgresql",
                                       "mod_storage": "postgresql"},
          "exit %d %s %s" % (rc, json.dumps(step), json.dumps(done)))
    result = pg.dump_pg("grug_it_all")
    check("pg migrate: every row equals the SQLite world after the same run", result == post,
          pg.diff(result, post))
    step_writes("grug_it_all", "pg")

    world = pg.make_world("platform", "grug_it_platform", False)
    pg.seed("grug_it_platform", WORK / "pre_tool", False)
    rc, ev = shipped("platform_migrate", world)
    result = pg.dump_pg("grug_it_platform", world / "mod_storage.sqlite")
    check("platform layout (player and auth on PostgreSQL, mod storage SQLite): every row "
          "equals the SQLite world after the same run",
          rc == 0 and pg.last(ev).get("applied") == ["0.45.0"] and result == post,
          "exit %d; %s" % (rc, pg.diff(result, post)))
    step_writes("grug_it_platform", "platform")
    (WORK / "pg_results.json").write_text(json.dumps(pg.results, indent=1) + "\n")
    return 0 if all(r["ok"] for r in pg.results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:  # the harness shows this as one failed check
        check("pg run", False, "%s: %s" % (type(err).__name__, err))
        (WORK / "pg_results.json").write_text(json.dumps(pg.results, indent=1) + "\n")
        raise
