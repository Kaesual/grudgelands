"""Opening a world the way the engine does (contract R4).

Only `world.mt` locates the data (reference_projects/luanti/src/settings.cpp
Settings::parseConfigLines lines 202-238 and parseConfigObject lines
984-1008: `name = value` lines, `#` comments, `{` groups, `\"\"\"` multiline
values). The three backends a step can reach, each `sqlite3` or
`postgresql`; a missing key is the engine's `files` default
(src/serverenvironment.cpp lines 207-251, src/server.cpp lines 4409-4416)
and, like leveldb or any other name, refused:

  player       `player_backend`,      `pgsql_player_connection`
  auth         `auth_backend`,        `pgsql_auth_connection`
  mod storage  `mod_storage_backend`, `pgsql_mod_storage_connection`

SQLite (src/database/database-sqlite3.cpp): `players.sqlite` (line 355),
`auth.sqlite` (line 648) and `mod_storage.sqlite` (line 811) in the world
directory, opened read-write without create (`mode=rw`), with foreign keys on
as the engine does (line 144). The engine creates a file at its first use
(lines 108-138): a world nobody ever joined has no `players.sqlite` and no
`auth.sqlite`. The tool creates nothing, so such a backend counts as empty
(no characters, no auth entries) and is left alone; a missing
`mod_storage.sqlite`, where the world version lives, is refused.

PostgreSQL (src/database/database-postgresql.cpp): the connection string is
handed to libpq as it stands (lines 50-58); libpq's environment applies, so
the password may come from PGPASSFILE. psycopg 3 is imported only here.

Table layouts: exactly the columns the engine creates (SQLite lines 387-431,
670-686, 832-838; PostgreSQL lines 313-362, 636-651, 806-812); anything else
is refused. The tool never writes world.mt and never creates, alters or
drops a table.
"""

import sqlite3
import sys
from pathlib import Path

from . import codec

KINDS = ("player", "auth", "mod_storage")
WORLD_MT_KEYS = {
    "player": ("player_backend", "pgsql_player_connection"),
    "auth": ("auth_backend", "pgsql_auth_connection"),
    "mod_storage": ("mod_storage_backend", "pgsql_mod_storage_connection"),
}
SQLITE_FILES = {"player": "players.sqlite", "auth": "auth.sqlite",
                "mod_storage": "mod_storage.sqlite"}

# Table -> columns, per engine. PostgreSQL folds unquoted names to lower case.
_PLAYER = {
    "player": ("name", "pitch", "yaw", "posX", "posY", "posZ", "hp", "breath",
               "creation_date", "modification_date"),
    "player_inventories": ("player", "inv_id", "inv_width", "inv_name", "inv_size"),
    "player_inventory_items": ("player", "inv_id", "slot_id", "item"),
}
LAYOUTS = {
    "sqlite3": {
        "player": dict(_PLAYER, player_metadata=("player", "metadata", "value")),
        "auth": {"auth": ("id", "name", "password", "last_login"),
                 "user_privileges": ("id", "privilege")},
        "mod_storage": {"entries": ("modname", "key", "value")},
    },
    "postgresql": {
        "player": dict(_PLAYER, player_metadata=("player", "attr", "value")),
        "auth": {"auth": ("id", "name", "password", "last_login"),
                 "user_privileges": ("id", "privilege")},
        "mod_storage": {"mod_storage": ("modname", "key", "value")},
    },
}
SQLITE_BUSY_TIMEOUT = 5.0
PG_LOCK_TIMEOUT = "5s"


class Refusal(Exception):
    """Refused before anything was written: exit 2."""

    def __init__(self, reason, message):
        super().__init__(message)
        self.reason = reason
        self.message = message


def read_world_mt(path):
    """The engine's Settings parser, for the keys at the top level."""
    try:
        lines = Path(path).read_bytes().decode("utf-8", "surrogateescape").split("\n")
    except OSError as err:
        raise Refusal("world_mt", "cannot read %s: %s" % (path, err.strerror)) from None
    settings = {}
    index = 0

    def skip_group(index):
        depth = 1
        while index < len(lines):
            line = lines[index].strip()
            index += 1
            if line == "}":
                depth -= 1
                if depth == 0:
                    return index
            elif "=" in line and line.split("=", 1)[1].strip() == "{":
                depth += 1
        raise Refusal("world_mt", "%s: a group is not closed" % path)

    while index < len(lines):
        line = lines[index].strip()
        index += 1
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = (part.strip() for part in line.split("=", 1))
        if value == "{":
            index = skip_group(index)
        elif value == '"""':
            body = []
            while index < len(lines) and lines[index].rstrip("\r") != '"""':
                body.append(lines[index])
                index += 1
            index += 1
            settings[name] = "\n".join(body)
        else:
            settings[name] = value
    return settings


class Backend:
    """One of the three backends: its engine, its connection (None when an
    SQLite file does not exist yet) and its SQL dialect."""

    def __init__(self, kind, engine, conn, where):
        self.kind = kind
        self.engine = engine
        self.conn = conn
        self.where = where
        self.tables = LAYOUTS[engine][kind]

    @property
    def present(self):
        return self.conn is not None

    def sql(self, statement):
        return statement.replace("?", "%s") if self.engine == "postgresql" else statement

    def execute(self, statement, params=()):
        return self.conn.execute(self.sql(statement), params)

    def begin(self):
        """Opens the write transaction: SQLite takes its write lock now
        (BEGIN IMMEDIATE); PostgreSQL waits at most PG_LOCK_TIMEOUT for a
        row lock."""
        if self.engine == "sqlite3":
            self.conn.execute("BEGIN IMMEDIATE")
        else:
            self.conn.execute("BEGIN")
            self.conn.execute("SET LOCAL lock_timeout = '%s'" % PG_LOCK_TIMEOUT)

    def commit(self):
        self.conn.execute("COMMIT")

    def rollback(self):
        self.conn.execute("ROLLBACK")

    def layout(self):
        """Table -> sorted column names, for the tables of this backend."""
        found = {}
        if self.engine == "sqlite3":
            for table in self.tables:
                columns = [row[1] for row in self.conn.execute(
                    "SELECT * FROM pragma_table_info(?)", (table,))]
                if columns:
                    found[table] = sorted(columns)
        else:
            rows = self.conn.execute(
                "SELECT table_name, column_name FROM information_schema.columns "
                "WHERE table_schema = ANY (current_schemas(false)) "
                "AND table_name = ANY (%s)", (list(self.tables),))
            for table, column in rows:
                found.setdefault(table, []).append(column)
            found = {table: sorted(columns) for table, columns in found.items()}
        return found

    def schema(self):
        """Every table, index and column of the backend's database: what a
        step may not change."""
        if self.engine == "sqlite3":
            return sorted(self.conn.execute(
                "SELECT type, name, tbl_name, sql FROM sqlite_master"))
        return sorted(self.conn.execute(
            "SELECT table_name, column_name, data_type FROM information_schema.columns "
            "WHERE table_schema = ANY (current_schemas(false))"))

    def check_layout(self):
        expected = {table: sorted(c.lower() if self.engine == "postgresql" else c
                                  for c in columns)
                    for table, columns in self.tables.items()}
        found = self.layout()
        for table, columns in expected.items():
            if table not in found:
                raise Refusal("layout", "%s backend (%s): table %s is missing"
                              % (self.kind, self.where, table))
            if found[table] != columns:
                raise Refusal("layout", "%s backend (%s): table %s has the columns %s, "
                              "the engine's layout is %s"
                              % (self.kind, self.where, table, ", ".join(found[table]),
                                 ", ".join(columns)))

    def close(self):
        if self.conn is not None:
            self.conn.close()
            self.conn = None


def _open_sqlite(kind, world_dir):
    path = Path(world_dir, SQLITE_FILES[kind])
    if not path.is_file():
        if kind == "mod_storage":
            raise Refusal("database_missing", "%s does not exist: this world never "
                          "started with SQLite mod storage" % path)
        return Backend(kind, "sqlite3", None, str(path))
    try:
        conn = sqlite3.connect(path.absolute().as_uri() + "?mode=rw", uri=True,
                               isolation_level=None, timeout=SQLITE_BUSY_TIMEOUT)
        conn.text_factory = codec.to_str
        conn.execute("PRAGMA foreign_keys = ON")
    except sqlite3.Error as err:
        raise Refusal("connection", "cannot open %s: %s" % (path, err)) from None
    return Backend(kind, "sqlite3", conn, str(path))


def _open_postgresql(kind, conninfo):
    if not conninfo:
        raise Refusal("world_mt", "world.mt names postgresql for the %s backend "
                      "but no %s" % (kind, WORLD_MT_KEYS[kind][1]))
    try:
        import psycopg
    except ImportError:
        raise Refusal("backend", "a PostgreSQL world needs psycopg 3 "
                      "(Debian: python3-psycopg)") from None
    try:
        conn = psycopg.connect(conninfo, autocommit=True)
    except psycopg.Error as err:
        raise Refusal("connection", "%s backend: cannot connect: %s"
                      % (kind, str(err).strip())) from None
    return Backend(kind, "postgresql", conn, WORLD_MT_KEYS[kind][1])


def open_world(world_dir):
    """The three backends of the world in `world_dir`, layouts checked."""
    world_dir = Path(world_dir)
    if not world_dir.is_dir():
        raise Refusal("world_mt", "%s is not a directory" % world_dir)
    settings = read_world_mt(world_dir / "world.mt")
    backends = {}
    try:
        for kind in KINDS:
            backend_key, conn_key = WORLD_MT_KEYS[kind]
            engine = settings.get(backend_key, "files")
            if engine == "sqlite3":
                backend = _open_sqlite(kind, world_dir)
            elif engine == "postgresql":
                backend = _open_postgresql(kind, settings.get(conn_key, ""))
            else:
                raise Refusal("backend", "%s = %s is not supported (sqlite3 or "
                              "postgresql; a missing key means files)"
                              % (backend_key, engine))
            backends[kind] = backend
            if backend.present:
                try:
                    backend.check_layout()
                except (sqlite3.Error, _pg_error()) as err:
                    raise Refusal("connection", "%s backend: %s" % (kind, err)) from None
    except Refusal:
        close_world(backends)
        raise
    return backends


def close_world(backends):
    for backend in backends.values():
        try:
            backend.close()
        except Exception:
            pass


def _pg_error():
    """psycopg's base error when psycopg is loaded, else a never-raised type."""
    module = sys.modules.get("psycopg")
    return module.Error if module else _Never


class _Never(Exception):
    pass


def db_errors():
    return (sqlite3.Error, _pg_error())
