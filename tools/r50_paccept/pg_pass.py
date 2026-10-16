#!/usr/bin/env python3
"""Round 50 lane PACCEPT: the pre-reset pass on PostgreSQL, the platform's
way (tools/r50_paccept/e2e.py starts it in the runner's image).

Runs inside localhost/grudgelands-r43-it:trixie (Debian trixie's python3
3.13, python3-psycopg, python3-zstandard, PostgreSQL) with Round 43 IT's
helpers (tools/r43_it/pg_test.py: a throwaway cluster, a role whose password
only a PGPASSFILE carries, the engine's player and auth tables) and the
engine's map table (database-postgresql.cpp, as tools/r50_ptool/pg_test.py).
The Flatpak Luanti has no PostgreSQL, so the tables are seeded from the
world the real 0.48.1 game wrote (SOURCE, SQLite): every map row byte for
byte, every player and auth row. Mod storage stays SQLite: the platform's
layout (map, player and auth on PostgreSQL, mod storage in SQLite).

  seed     the tables, then pg_dump (custom format, --no-owner --no-acl) of
           the seeded database: the platform fixture's PostgreSQL part
  tool     the shipped command line with PGPASSFILE, timed: --check
           --map-reset, then --world <dir> --map-reset
  empty    as the platform does: TRUNCATE public.blocks, as the world's role
Checks that the map, player and auth rows are unchanged by the tool and the
map is empty afterwards. Writes WORK/pg_pass.json (events, times, checks),
WORK/pg_events/<case>.jsonl and .txt, WORK/w_pg/ (world.mt and the
mod_storage.sqlite the pass wrote) and WORK/platform.dump.

Usage: python3 tools/r50_paccept/pg_pass.py WORK SOURCE
"""

import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools" / "r43_it")]

import pg_test as pg  # noqa: E402  (tools/r43_it/pg_test.py; reads sys.argv[1])

WORK = pg.WORK
SOURCE = Path(sys.argv[2])
DB = "grug_it_platform"
BLOCKS_DDL = ("CREATE TABLE blocks (posX smallint NOT NULL, posY smallint NOT NULL, "
              "posZ smallint NOT NULL, data BYTEA, PRIMARY KEY (posX,posY,posZ));")
check = pg.check
out = {"events": {}, "times": {}}


def map_digest():
    with pg.connect(DB) as conn:
        rows = conn.execute("SELECT posx, posy, posz, data FROM blocks "
                            "ORDER BY posx, posy, posz").fetchall()
    digest = hashlib.sha256()
    for x, y, z, data in rows:
        digest.update(b"%d,%d,%d:" % (x, y, z) + bytes(data))
    return len(rows), digest.hexdigest()


def players_auth():
    dump = pg.dump_pg(DB, mod_storage_source=WORLD / "mod_storage.sqlite")
    return {k: v for k, v in dump.items() if k != "storage"}


def shipped(case, *args):
    env = dict(os.environ, PGPASSFILE="/tmp/it.pgpass", PGCONNECT_TIMEOUT="5")
    before = time.time()
    started = time.monotonic()
    proc = subprocess.run(["python3", "tools/migrate.py", "--world", str(WORLD), *args],
                          cwd=REPO, env=env, capture_output=True, text=True)
    wall = round(time.monotonic() - started, 3)
    after = time.time()
    events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
    folder = WORK / "pg_events"
    folder.mkdir(exist_ok=True)
    (folder / (case + ".jsonl")).write_text(proc.stdout)
    (folder / (case + ".txt")).write_text(proc.stderr)
    out["events"][case] = events
    out["times"][case] = {"wall": wall, "clock": [before, after], "exit": proc.returncode}
    return proc.returncode, events


def main():
    global WORLD
    version, server = pg.start_postgres()
    check("postgres started", True, "cluster %s, server %s" % (version, server))
    WORLD = WORK / "w_pg"
    WORLD.mkdir(parents=True)
    info = pg.conninfo(DB)
    (WORLD / "world.mt").write_text("\n".join([
        "gameid = grudgelands", "backend = postgresql", "pgsql_connection = " + info,
        "player_backend = postgresql", "pgsql_player_connection = " + info,
        "auth_backend = postgresql", "pgsql_auth_connection = " + info,
        "mod_storage_backend = sqlite3"]) + "\n")
    shutil.copy(SOURCE / "mod_storage.sqlite", WORLD / "mod_storage.sqlite")

    # Seed: the engine's tables, the rows the 0.48.1 game wrote.
    with pg.connect(DB) as conn:
        for statement in pg.DDL[:-1] + [BLOCKS_DDL]:
            conn.execute(statement)
    pg.seed(DB, SOURCE, False)
    source_map = sqlite3.connect(SOURCE / "map.sqlite")
    rows = source_map.execute("SELECT x, y, z, data FROM blocks").fetchall()
    with pg.connect(DB) as conn, conn.cursor() as cur:
        cur.executemany("INSERT INTO blocks (posX, posY, posZ, data) VALUES (%s, %s, %s, %s)",
                        rows)
    want = pg._dump(sqlite3.connect(SOURCE / "players.sqlite"),
                    sqlite3.connect(SOURCE / "auth.sqlite"),
                    sqlite3.connect(SOURCE / "mod_storage.sqlite"), "metadata", "entries")
    seeded = players_auth()
    check("seeded: every player and auth row of the 0.48.1 world",
          seeded == {k: v for k, v in want.items() if k != "storage"},
          pg.diff(seeded, {k: v for k, v in want.items() if k != "storage"}))
    before_map = map_digest()
    check("seeded: every map row of the 0.48.1 world", before_map[0] == len(rows),
          "%d rows" % before_map[0])
    out["map_rows"] = before_map[0]

    # The fixture's PostgreSQL part: the seeded database as the platform's
    # backup takes it (custom format, no owner, no ACL).
    env = dict(os.environ, PGPASSFILE="/tmp/it.pgpass")
    dump = WORK / "platform.dump"
    base = ["pg_dump", "-h", "127.0.0.1", "-U", pg.ROLE, "-d", DB, "-Fc", "--no-owner",
            "--no-acl", "-f", str(dump)]
    proc = subprocess.run(base[:-2] + ["-Z", "zstd"] + base[-2:], env=env,
                          capture_output=True, text=True)
    out["dump_compression"] = "zstd"
    if proc.returncode != 0:
        proc = subprocess.run(base, env=env, capture_output=True, text=True)
        out["dump_compression"] = "default"
    check("pg_dump of the seeded database", proc.returncode == 0 and dump.exists(),
          proc.stderr[-300:])

    # The tool, as the platform runs it.
    rc, events = shipped("check", "--check", "--map-reset")
    done = events[-1] if events else {}
    check("--check --map-reset: one block read and decoded, exit 0",
          rc == 0 and done.get("map_checked") == 1 and done.get("map_reset") is True,
          "exit %d %s" % (rc, json.dumps(done)))
    rc, events = shipped("pass", "--map-reset")
    done = events[-1] if events else {}
    check("--map-reset: exit 0 with done map_reset true",
          rc == 0 and done.get("event") == "done" and done.get("map_reset") is True,
          "exit %d %s" % (rc, json.dumps(done)))
    check("the map rows are unchanged by the tool", map_digest() == before_map)
    check("the player and auth rows are unchanged by the tool", players_auth() == seeded,
          pg.diff(players_auth(), seeded))

    # Empty the map as the platform does: TRUNCATE as the world's own role.
    with pg.connect(DB) as conn:
        conn.execute("TRUNCATE TABLE public.blocks")
        left = conn.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    check("TRUNCATE public.blocks: the map is empty", left == 0, "%d rows" % left)
    check("the player and auth rows survive the emptying", players_auth() == seeded)
    out["results"] = pg.results
    (WORK / "pg_pass.json").write_text(json.dumps(out, indent=1) + "\n")
    return 0 if all(r["ok"] for r in pg.results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:
        check("pg pass", False, "%s: %s" % (type(err).__name__, err))
        out["results"] = pg.results
        (WORK / "pg_pass.json").write_text(json.dumps(out, indent=1) + "\n")
        raise
