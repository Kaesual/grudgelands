#!/usr/bin/env python3
"""Round 50 lane PTOOL: the pre-reset pass on PostgreSQL.

Runs inside localhost/grudgelands-r43-it:trixie (started by run.sh), with
Round 43 IT's helpers (tools/r43_it/pg_test.py: a throwaway cluster in the
container, a role whose password only a PGPASSFILE carries, the engine's
player, auth and mod storage tables). The map table is the engine's too
(database-postgresql.cpp lines 162-175). The Flatpak Luanti has no
PostgreSQL, so the tables are seeded from the engine-written SQLite world
tools/r50_ptool/world (every map row byte for byte, every mod storage row).

Worlds (only world.mt names the data):
  all_pg    the map and all three backends on PostgreSQL
  platform  the map, player and auth on PostgreSQL, mod storage in SQLite
            (the hosting platform's layout)
  shipped   all on PostgreSQL, for the shipped command line
The pass runs in-process on a copy of the SQLite world and on all_pg and
platform with one clock: every recovered entry, pack_seq and the marker
must be equal on all three. The shipped command line (PGPASSFILE) proves
--check --map-reset, a pass, the pending-marker refusal; the map's rows are
unchanged after everything, and the reader's session refuses a write.

Writes WORK/pg_results.json; exit 0 when every check passed.

Usage: python3 tools/r50_ptool/pg_test.py WORK
"""

import hashlib
import io
import json
import os
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import pg_test as pg  # noqa: E402  (tools/r43_it/pg_test.py; reads sys.argv[1])
from migration import cli, mapblock  # noqa: E402

WORK = pg.WORK
WORLD = HERE / "world"
check = pg.check
BLOCKS_DDL = ("CREATE TABLE blocks (posX smallint NOT NULL, posY smallint NOT NULL, "
              "posZ smallint NOT NULL, data BYTEA, PRIMARY KEY (posX,posY,posZ));")
NOW = None


def make_world(name, db, mod_storage_pg):
    world = WORK / "worlds" / name
    world.mkdir(parents=True)
    info = pg.conninfo(db)
    lines = ["gameid = grudgelands", "backend = postgresql", "pgsql_connection = " + info,
             "player_backend = postgresql", "pgsql_player_connection = " + info,
             "auth_backend = postgresql", "pgsql_auth_connection = " + info]
    if mod_storage_pg:
        lines += ["mod_storage_backend = postgresql", "pgsql_mod_storage_connection = " + info]
    else:
        lines += ["mod_storage_backend = sqlite3"]
        shutil.copy(WORLD / "mod_storage.sqlite", world / "mod_storage.sqlite")
    (world / "world.mt").write_text("\n".join(lines) + "\n")
    source_map = sqlite3.connect(WORLD / "map.sqlite")
    source_store = sqlite3.connect(WORLD / "mod_storage.sqlite")
    with pg.connect(db) as conn:
        for statement in (pg.DDL if mod_storage_pg else pg.DDL[:-1]) + [BLOCKS_DDL]:
            conn.execute(statement)
        with conn.cursor() as cur:
            cur.executemany("INSERT INTO blocks (posX, posY, posZ, data) VALUES (%s, %s, %s, %s)",
                            source_map.execute("SELECT x, y, z, data FROM blocks").fetchall())
            if mod_storage_pg:
                cur.executemany("INSERT INTO mod_storage VALUES (%s, %s, %s)", [
                    (m, bytes(k), bytes(v)) for m, k, v in
                    source_store.execute("SELECT modname, key, value FROM entries")])
    return world


def map_digest(db):
    with pg.connect(db) as conn:
        rows = conn.execute("SELECT posx, posy, posz, data FROM blocks "
                            "ORDER BY posx, posy, posz").fetchall()
    digest = hashlib.sha256()
    for x, y, z, data in rows:
        digest.update(b"%d,%d,%d:" % (x, y, z) + bytes(data))
    return len(rows), digest.hexdigest()


def storage_rows(world, db=None):
    """grug_housing's and grug_core's rows: (modname, key, value)."""
    if db:
        with pg.connect(db) as conn:
            rows = conn.execute("SELECT modname, key, value FROM mod_storage").fetchall()
    else:
        conn = sqlite3.connect(Path(world, "mod_storage.sqlite"))
        rows = conn.execute("SELECT modname, key, value FROM entries").fetchall()
        conn.close()
    return sorted((m, bytes(k).decode(), bytes(v).decode()) for m, k, v in rows
                  if m in ("grug_housing", "grug_core"))


def in_process(world):
    out, err = io.StringIO(), io.StringIO()
    saved, cli.clock = cli.clock, lambda: NOW
    try:
        code = cli.main(["--world", str(world), "--map-reset"], stdout=out, stderr=err)
    finally:
        cli.clock = saved
    events = [json.loads(line) for line in out.getvalue().splitlines()]
    if code != 0:
        print(err.getvalue()[-2000:])
    return code, events


def shipped(world, *args):
    env = dict(os.environ, PGPASSFILE="/tmp/it.pgpass", PGCONNECT_TIMEOUT="5")
    proc = subprocess.run(["python3", "tools/migrate.py", "--world", str(world), *args],
                          cwd=REPO, env=env, capture_output=True, text=True)
    events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
    if proc.returncode not in (0, 2):
        print(proc.stderr[-2000:])
    return proc.returncode, events


def main():
    global NOW
    record = json.loads(__import__("gzip").decompress(
        (WORLD / "r50_ptool_probe.json.gz").read_bytes()))
    NOW = min(c["paid_until"] for c in record["claims"]) - 5 * 26160 + 3600
    version, server = pg.start_postgres()
    check("postgres started", True, "cluster %s, server %s" % (version, server))

    reference = WORK / "worlds" / "sqlite"
    shutil.copytree(WORLD, reference)
    rc, events = in_process(reference)
    want = storage_rows(reference)
    check("the SQLite reference pass", rc == 0 and events[2]["counts"]["containers"] == 11,
          json.dumps(events[2].get("counts")))

    all_pg = make_world("all_pg", "grug_it_all", True)
    platform = make_world("platform", "grug_it_platform", False)
    shipped_world = make_world("shipped", "grug_it_empty", True)
    before = {db: map_digest(db) for db in ("grug_it_all", "grug_it_platform", "grug_it_empty")}
    check("the map seeded: every row of the SQLite world", all(
        n == 763 for n, _ in before.values()), json.dumps(before))

    rc, events = in_process(all_pg)
    got = storage_rows(all_pg, "grug_it_all")
    check("all on PostgreSQL: the pass reads the map and writes the same rows as SQLite",
          rc == 0 and got == want and events[-1]["backends"] == {
              "player": "postgresql", "auth": "postgresql", "mod_storage": "postgresql",
              "map": "postgresql"},
          "exit %d, %d rows vs %d" % (rc, len(got), len(want)))
    rc, events = in_process(platform)
    got = storage_rows(platform)
    check("platform layout (map, player, auth on PostgreSQL, mod storage SQLite): the same rows",
          rc == 0 and got == want and events[-1]["backends"]["map"] == "postgresql"
          and events[-1]["backends"]["mod_storage"] == "sqlite3",
          "exit %d, %d rows vs %d" % (rc, len(got), len(want)))
    recovered = [r for r in want if r[1].startswith("recovered:")]
    check("the entries compared", len(recovered) == 13, "%d entries" % len(recovered))

    rc, events = shipped(shipped_world, "--check", "--map-reset")
    done = events[-1] if events else {}
    check("shipped --check --map-reset: one block selected and decoded, write check rolled back",
          rc == 0 and done.get("map_checked") == 1 and done.get("map_reset") is True
          and done.get("write_checked") == ["player", "auth", "mod_storage"],
          "exit %d %s" % (rc, json.dumps(done)))
    rc, events = shipped(shipped_world, "--map-reset")
    packed = next((e for e in events if e.get("event") == "pack_done"), {})
    check("shipped --map-reset: packed, exit 0, done with map_reset",
          rc == 0 and packed.get("counts", {}).get("containers") == 11
          and packed["counts"]["blocks_read"] == 763 and events[-1].get("map_reset") is True
          and events[-1].get("applied") == [],
          "exit %d %s" % (rc, json.dumps(packed.get("counts"))))
    rc, events = shipped(shipped_world, "--map-reset")
    check("shipped --map-reset again before the game loaded: refused (pack_pending)",
          rc == 2 and events[-1].get("reason") == "pack_pending",
          "exit %d %s" % (rc, json.dumps(events[-1] if events else None)))

    after = {db: map_digest(db) for db in before}
    check("the map rows are unchanged on every database", after == before, json.dumps(after))
    reader = mapblock.open_map(all_pg, {"backend": "postgresql",
                                        "pgsql_connection": pg.conninfo("grug_it_all")})
    try:
        reader.conn.execute("DELETE FROM blocks")
        refused = False
    except Exception as err:  # psycopg.errors.ReadOnlySqlTransaction
        refused = type(err).__name__
    finally:
        reader.close()
    check("the map reader's session refuses a write", refused == "ReadOnlySqlTransaction",
          str(refused))
    (WORK / "pg_results.json").write_text(json.dumps(pg.results, indent=1) + "\n")
    return 0 if all(r["ok"] for r in pg.results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:
        check("pg run", False, "%s: %s" % (type(err).__name__, err))
        (WORK / "pg_results.json").write_text(json.dumps(pg.results, indent=1) + "\n")
        raise
