#!/usr/bin/env python3
"""Round 43 lane IT: the migration tool against a throwaway PostgreSQL.

Runs inside localhost/grudgelands-r43-it:trixie (Containerfile; started by
it.py), as the container's root, with no network: it starts Debian's
PostgreSQL cluster inside the container, creates a role whose password only
a PGPASSFILE carries, and runs the tool (tools/r43_it/tool_run.py, the test
steps of steps.py) on Debian's python3 with python3-psycopg.

The flatpak Luanti build has no PostgreSQL (no USE_POSTGRESQL, see
it.py), so no engine writes these tables: they are created with the
engine's own statements (reference_projects/luanti/src/database/
database-postgresql.cpp: player 313-362, auth 636-651, mod storage
806-812) and seeded from the engine-written SQLite world of the end-to-end
run, taken right before its tool run (WORK/pre_tool). The tool's result on
PostgreSQL is then compared row for row with its result on that SQLite world
(WORK/post_tool), which the engine loaded and the game checked.

Worlds (only world.mt names the data, as the engine reads it):
  empty     all three backends on PostgreSQL, the tables without a row
  all_pg    all three on PostgreSQL, seeded
  platform  player and auth on PostgreSQL, mod storage in SQLite (the hosting
            platform's layout), seeded
Writes WORK/pg_results.json and WORK/pg_events/<case>.jsonl; exit 0 when
every check passed.

Usage: python3 tools/r43_it/pg_test.py WORK
"""

import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

import psycopg

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
WORK = Path(sys.argv[1])
ROLE, PASSWORD = "grug_it", "it-secret"
STEPS = "0.41.1,0.41.2,0.41.3,0.41.4"
# The declared steps lie above the test steps and run with them (it.py).
DECLARED = json.loads((REPO / "tools" / "web_data" / "upgrade.json").read_text())["migrate"]
DUE = sorted(STEPS.split(",") + DECLARED, key=lambda v: tuple(int(p) for p in v.split(".")))
results = []

DDL = [
    # database-postgresql.cpp PlayerDatabasePostgreSQL::createDatabase
    "CREATE TABLE player ("
    "name VARCHAR(60) NOT NULL,"
    "pitch NUMERIC(15, 7) NOT NULL,"
    "yaw NUMERIC(15, 7) NOT NULL,"
    "posX NUMERIC(15, 7) NOT NULL,"
    "posY NUMERIC(15, 7) NOT NULL,"
    "posZ NUMERIC(15, 7) NOT NULL,"
    "hp INT NOT NULL,"
    "breath INT NOT NULL,"
    "creation_date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),"
    "modification_date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),"
    "PRIMARY KEY (name)"
    ");",
    "CREATE TABLE player_inventories ("
    "player VARCHAR(60) NOT NULL,"
    "inv_id INT NOT NULL,"
    "inv_width INT NOT NULL,"
    "inv_name TEXT NOT NULL DEFAULT '',"
    "inv_size INT NOT NULL,"
    "PRIMARY KEY(player, inv_id),"
    "CONSTRAINT player_inventories_fkey FOREIGN KEY (player) REFERENCES "
    "player (name) ON DELETE CASCADE"
    ");",
    "CREATE TABLE player_inventory_items ("
    "player VARCHAR(60) NOT NULL,"
    "inv_id INT NOT NULL,"
    "slot_id INT NOT NULL,"
    "item TEXT NOT NULL DEFAULT '',"
    "PRIMARY KEY(player, inv_id, slot_id),"
    "CONSTRAINT player_inventory_items_fkey FOREIGN KEY (player) REFERENCES "
    "player (name) ON DELETE CASCADE"
    ");",
    "CREATE TABLE player_metadata ("
    "player VARCHAR(60) NOT NULL,"
    "attr VARCHAR(256) NOT NULL,"
    "value TEXT,"
    "PRIMARY KEY(player, attr),"
    "CONSTRAINT player_metadata_fkey FOREIGN KEY (player) REFERENCES "
    "player (name) ON DELETE CASCADE"
    ");",
    # AuthDatabasePostgreSQL::createDatabase
    "CREATE TABLE auth ("
    "id SERIAL,"
    "name TEXT UNIQUE,"
    "password TEXT,"
    "last_login INT NOT NULL DEFAULT 0,"
    "PRIMARY KEY (id)"
    ");",
    "CREATE TABLE user_privileges ("
    "id INT,"
    "privilege TEXT,"
    "PRIMARY KEY (id, privilege),"
    "CONSTRAINT fk_id FOREIGN KEY (id) REFERENCES auth (id) ON DELETE CASCADE"
    ");",
    # ModStorageDatabasePostgreSQL::createDatabase
    "CREATE TABLE mod_storage ("
    "modname TEXT NOT NULL,"
    "key BYTEA NOT NULL,"
    "value BYTEA NOT NULL,"
    "PRIMARY KEY (modname, key)"
    ");",
]


def check(name, ok, detail=""):
    results.append({"name": name, "ok": bool(ok), "detail": detail})
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
    return ok


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def start_postgres():
    version = sorted(os.listdir("/etc/postgresql"))[-1]
    run("pg_ctlcluster", version, "main", "start")
    psql = ["runuser", "-u", "postgres", "--", "psql", "-v", "ON_ERROR_STOP=1", "-q", "-c"]
    run(*psql, "CREATE ROLE %s LOGIN PASSWORD '%s'" % (ROLE, PASSWORD))
    for db in ("grug_it_empty", "grug_it_all", "grug_it_platform"):
        run(*psql, "CREATE DATABASE %s OWNER %s" % (db, ROLE))
    passfile = Path("/tmp/it.pgpass")
    passfile.write_text("127.0.0.1:5432:*:%s:%s\n" % (ROLE, PASSWORD))
    passfile.chmod(0o600)
    os.environ["PGPASSFILE"] = str(passfile)  # this script's own connections
    Path("/tmp/it.nopass").write_text("")
    Path("/tmp/it.nopass").chmod(0o600)
    server = run("runuser", "-u", "postgres", "--", "psql", "-tAc", "SHOW server_version").stdout
    return version, server.strip()


def conninfo(db):
    # No password: libpq takes it from PGPASSFILE.
    return "host=127.0.0.1 port=5432 user=%s dbname=%s" % (ROLE, db)


def connect(db):
    return psycopg.connect(conninfo(db), autocommit=True)


def make_world(name, db, mod_storage_pg):
    world = Path("/tmp/worlds") / name
    world.mkdir(parents=True)
    lines = ["gameid = grudgelands", "backend = sqlite3",
             "player_backend = postgresql", "pgsql_player_connection = " + conninfo(db),
             "auth_backend = postgresql", "pgsql_auth_connection = " + conninfo(db)]
    if mod_storage_pg:
        lines += ["mod_storage_backend = postgresql",
                  "pgsql_mod_storage_connection = " + conninfo(db)]
    else:
        lines += ["mod_storage_backend = sqlite3"]
        shutil.copy(WORK / "pre_tool" / "mod_storage.sqlite", world / "mod_storage.sqlite")
    (world / "world.mt").write_text("\n".join(lines) + "\n")
    with connect(db) as conn:
        for statement in DDL if mod_storage_pg else DDL[:-1]:
            conn.execute(statement)
    return world


def seed(db, source, mod_storage_pg):
    """Copies the engine-written SQLite rows into the engine's tables."""
    players = sqlite3.connect(source / "players.sqlite")
    auth = sqlite3.connect(source / "auth.sqlite")
    with connect(db) as conn:
        for row in players.execute("SELECT name, pitch, yaw, posX, posY, posZ, hp, breath "
                                   "FROM player"):
            conn.execute("INSERT INTO player (name, pitch, yaw, posX, posY, posZ, hp, breath) "
                         "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)", row)
        for row in players.execute("SELECT player, inv_id, inv_width, inv_name, inv_size "
                                   "FROM player_inventories"):
            conn.execute("INSERT INTO player_inventories VALUES (%s, %s, %s, %s, %s)", row)
        for row in players.execute("SELECT player, inv_id, slot_id, item "
                                   "FROM player_inventory_items"):
            conn.execute("INSERT INTO player_inventory_items VALUES (%s, %s, %s, %s)", row)
        for row in players.execute("SELECT player, metadata, value FROM player_metadata"):
            conn.execute("INSERT INTO player_metadata (player, attr, value) "
                         "VALUES (%s, %s, %s)", row)
        for row in auth.execute("SELECT id, name, password, last_login FROM auth"):
            conn.execute("INSERT INTO auth (id, name, password, last_login) "
                         "VALUES (%s, %s, %s, %s)", row)
        conn.execute("SELECT setval(pg_get_serial_sequence('auth', 'id'), "
                     "(SELECT MAX(id) FROM auth))")
        for row in auth.execute("SELECT id, privilege FROM user_privileges"):
            conn.execute("INSERT INTO user_privileges VALUES (%s, %s)", row)
        if mod_storage_pg:
            store = sqlite3.connect(source / "mod_storage.sqlite")
            for modname, key, value in store.execute("SELECT modname, key, value FROM entries"):
                conn.execute("INSERT INTO mod_storage VALUES (%s, %s, %s)",
                             (modname, _b(key), _b(value)))


def _b(value):
    return value.encode("utf-8", "surrogateescape") if isinstance(value, str) else bytes(value)


def _pos(value):
    return round(float(value), 4)


def dump_sqlite(source):
    """The rows a step can change, normalized: an SQLite world."""
    players = sqlite3.connect(source / "players.sqlite")
    auth = sqlite3.connect(source / "auth.sqlite")
    store = sqlite3.connect(source / "mod_storage.sqlite")
    return _dump(players, auth, store, "metadata", "entries")


def dump_pg(db, mod_storage_source=None):
    conn = connect(db)
    store = sqlite3.connect(mod_storage_source) if mod_storage_source else conn
    table = "entries" if mod_storage_source else "mod_storage"
    return _dump(conn, conn, store, "attr", table)


def _dump(players, auth, store, meta_column, store_table):
    q = lambda c, s: [tuple(r) for r in c.execute(s).fetchall()]  # noqa: E731
    return {
        "player": sorted((n, _pos(p), _pos(y), _pos(x), _pos(yy), _pos(z), int(h), int(b))
                         for n, p, y, x, yy, z, h, b in q(
                             players, "SELECT name, pitch, yaw, posX, posY, posZ, hp, breath "
                             "FROM player")),
        "meta": sorted(q(players, "SELECT player, %s, value FROM player_metadata" % meta_column)),
        "inventories": sorted(q(players, "SELECT player, inv_id, inv_width, inv_name, inv_size "
                                         "FROM player_inventories")),
        "items": sorted(q(players, "SELECT player, inv_id, slot_id, item "
                                   "FROM player_inventory_items")),
        "auth": sorted(q(auth, "SELECT id, name, password, last_login FROM auth")),
        "privileges": sorted(q(auth, "SELECT id, privilege FROM user_privileges")),
        "storage": sorted((m, _b(k).hex(), _b(v).hex()) for m, k, v in q(
            store, "SELECT modname, key, value FROM %s" % store_table)),
    }


def diff(a, b):
    out = []
    for part in a:
        extra = sorted(set(map(repr, a[part])) - set(map(repr, b[part])))
        missing = sorted(set(map(repr, b[part])) - set(map(repr, a[part])))
        if extra or missing:
            out.append("%s: only left %s, only right %s" % (part, extra[:3], missing[:3]))
    return "; ".join(out)


def tool(case, world, steps, check_mode=False, passfile="/tmp/it.pgpass"):
    cmd = ["python3", "tools/r43_it/tool_run.py", steps, "--world", str(world)]
    if check_mode:
        cmd.append("--check")
    env = dict(os.environ, PGPASSFILE=passfile, PGCONNECT_TIMEOUT="5")
    started = time.monotonic()
    proc = subprocess.run(cmd, cwd=REPO, env=env, capture_output=True, text=True)
    events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
    (WORK / "pg_events").mkdir(exist_ok=True)
    (WORK / "pg_events" / (case + ".jsonl")).write_text(proc.stdout)
    if proc.returncode not in (0, 1, 2) or not events:
        print(proc.stderr)
    return proc.returncode, events, round(time.monotonic() - started, 1)


def last(events):
    return events[-1] if events else {}


def auth_sequence(db):
    with connect(db) as conn:
        return conn.execute("SELECT last_value, is_called FROM auth_id_seq").fetchone()


def main():
    pg_version, server = start_postgres()
    check("postgres started", True, "cluster %s, server %s" % (pg_version, server))
    import sqlite3 as _sqlite
    check("runner versions", sys.version_info[:2] == (3, 13), "python %s, psycopg %s, libpq %s, "
          "sqlite %s" % (sys.version.split()[0], psycopg.__version__, psycopg.pq.version(),
                         _sqlite.sqlite_version))

    # A world whose tables exist but hold nothing (a platform may create
    # them before the first start): new to the tool.
    empty = make_world("empty", "grug_it_empty", True)
    rc, ev, _ = tool("empty_check", empty, STEPS, check_mode=True)
    done = last(ev)
    check("pg empty tables: --check sees a new world", rc == 0 and done.get("new_world") is True
          and done.get("due") == [] and done.get("write_checked") == ["player", "auth", "mod_storage"],
          "exit %d, %s" % (rc, json.dumps(done)))
    rc, ev, _ = tool("empty_migrate", empty, STEPS)
    with connect("grug_it_empty") as conn:
        rows = conn.execute("SELECT COUNT(*) FROM mod_storage").fetchone()[0]
    check("pg empty tables: migrating writes nothing", rc == 0 and last(ev).get("applied") == []
          and rows == 0, "exit %d, mod_storage rows %d" % (rc, rows))

    # All three backends on PostgreSQL, seeded from the engine-written world.
    pre, post = dump_sqlite(WORK / "pre_tool"), dump_sqlite(WORK / "post_tool")
    world = make_world("all_pg", "grug_it_all", True)
    seed("grug_it_all", WORK / "pre_tool", True)
    seeded = dump_pg("grug_it_all")
    check("pg seeding: rows equal the SQLite world", seeded == pre, diff(seeded, pre))
    sequence = auth_sequence("grug_it_all")

    rc, ev, _ = tool("all_check", world, STEPS, check_mode=True)
    done = last(ev)
    check("pg --check: version, due steps, write access on all three",
          rc == 0 and done.get("world_version") == "0.41.0" and done.get("record") is None
          and done.get("new_world") is False and done.get("due") == DUE
          and done.get("write_checked") == ["player", "auth", "mod_storage"]
          and done.get("backends") == {"player": "postgresql", "auth": "postgresql",
                                       "mod_storage": "postgresql"},
          "exit %d, %s" % (rc, json.dumps(done)))
    after = dump_pg("grug_it_all")
    check("pg --check: its writes rolled back", after == pre and auth_sequence("grug_it_all")
          == sequence, diff(after, pre) or "auth_id_seq %s" % (sequence,))

    for table in ("mod_storage", "player"):
        locker = psycopg.connect(conninfo("grug_it_all"))
        locker.execute("LOCK TABLE %s IN SHARE MODE" % table)
        rc, ev, took = tool("lock_" + table, world, STEPS, check_mode=True)
        locker.rollback()
        locker.close()
        done = last(ev)
        check("pg --check: a lock held on %s is refused" % table,
              rc == 2 and done.get("event") == "refusal" and done.get("reason") == "lock",
              "exit %d after %.1f s, %s" % (rc, took, json.dumps(done)))
    check("pg after the lock refusals: unchanged", dump_pg("grug_it_all") == pre)

    rc, ev, _ = tool("no_password", world, STEPS, check_mode=True, passfile="/tmp/it.nopass")
    done = last(ev)
    check("pg: without the PGPASSFILE password the connection is refused",
          rc == 2 and done.get("reason") == "connection", "exit %d, %s" % (rc, json.dumps(done)))

    rc, ev, _ = tool("all_migrate", world, STEPS)
    done = last(ev)
    kinds = [e.get("event") for e in ev]
    check("pg migrate: the four test steps and the declared ones", rc == 0
          and done.get("applied") == DUE and kinds ==
          ["start"] + ["step_start", "step_done"] * len(DUE) + ["done"],
          "exit %d, events %s" % (rc, kinds))
    counts = {e["step"]: e["counts"] for e in ev if e.get("event") == "step_done"}
    check("pg migrate: step counts", counts.get("0.41.1", {}).get("inventories") == 1
          and counts.get("0.41.1", {}).get("privileges") == 1
          and counts.get("0.41.3", {}).get("markers") == 1, json.dumps(counts))
    result = dump_pg("grug_it_all")
    check("pg migrate: rows equal the SQLite world after the same steps", result == post,
          diff(result, post))
    with connect("grug_it_all") as conn:
        record = conn.execute("SELECT value FROM mod_storage WHERE modname = 'grug_core' "
                              "AND key = %s", (b"world_version",)).fetchone()
        marker = conn.execute("SELECT value FROM mod_storage WHERE modname = 'grug_core' "
                              "AND key = %s", (b"migrate_world:0.41.2",)).fetchone()
        char = conn.execute("SELECT attr, value FROM player_metadata WHERE player = 'hero' "
                            "AND attr LIKE 'grug_core:migrate:%%' ORDER BY attr").fetchall()
    check("pg migrate: record and markers", record and bytes(record[0]) == DUE[-1].encode()
          and marker and bytes(marker[0]) == b"w-0.41.2"
          and char == [("grug_core:migrate:0.41.3", "c-0.41.3"),
                       ("grug_core:migrate:0.41.4", "c-0.41.4")],
          "record %r, world marker %r, hero %r" % (record, marker, char))

    rc, ev, _ = tool("all_again", world, STEPS)
    check("pg migrate again: nothing due", rc == 0 and last(ev).get("applied") == [],
          "exit %d, %s" % (rc, json.dumps(last(ev))))

    # Test setup (the server stopped): the record back at 0.41.4, so the
    # failing test step 0.41.5 is due again before the declared ones.
    with connect("grug_it_all") as conn:
        conn.execute("UPDATE mod_storage SET value = %s WHERE modname = 'grug_core' "
                     "AND key = %s", (b"0.41.4", b"world_version"))
    before_fail = dump_pg("grug_it_all")
    for case, reason in (("fail", "step"), ("rename", "rule")):
        rc, ev, _ = tool("all_" + case, world, "0.41.5=" + case)
        done = last(ev)
        check("pg: a step that %s exits 1 and rolls every backend back" % (
            "raises after writing" if case == "fail" else "renames an auth entry"),
            rc == 1 and done.get("event") == "failed" and done.get("reason") == reason
            and dump_pg("grug_it_all") == before_fail,
            "exit %d, %s" % (rc, json.dumps(done)))

    # The platform's layout: player and auth on PostgreSQL, mod storage SQLite.
    world = make_world("platform", "grug_it_platform", False)
    seed("grug_it_platform", WORK / "pre_tool", False)
    rc, ev, _ = tool("platform_check", world, STEPS, check_mode=True)
    done = last(ev)
    check("platform layout --check", rc == 0 and done.get("due") == DUE
          and done.get("backends") == {"player": "postgresql", "auth": "postgresql",
                                       "mod_storage": "sqlite3"}
          and done.get("write_checked") == ["player", "auth", "mod_storage"],
          "exit %d, %s" % (rc, json.dumps(done)))
    rc, ev, _ = tool("platform_migrate", world, STEPS)
    result = dump_pg("grug_it_platform", world / "mod_storage.sqlite")
    check("platform layout migrate: rows equal the SQLite world after the same steps",
          rc == 0 and last(ev).get("applied") == DUE and result == post,
          "exit %d; %s" % (rc, diff(result, post)))

    (WORK / "pg_results.json").write_text(json.dumps(results, indent=1) + "\n")
    return 0 if all(r["ok"] for r in results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:  # the harness shows this as one failed check
        check("pg run", False, "%s: %s" % (type(err).__name__, err))
        (WORK / "pg_results.json").write_text(json.dumps(results, indent=1) + "\n")
        raise
