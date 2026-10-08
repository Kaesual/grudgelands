"""The data API a step works with (contract R5): characters, auth, mod
storage, the online-work markers and the raw connections.

A step receives one `World` and runs inside one write transaction per
backend; the tool commits them after the step (player, auth, then mod
storage with the world version) or rolls every one back when the step
raises. Strings are `str` (see codec: undecodable bytes survive through
`surrogateescape`); an empty string written to player meta or mod storage
deletes the key, as in the game.

What a step can never do, checked after it ran and before anything is
committed: create, rename or delete a character or an auth entry, or change
a table's layout, even through a raw connection. The world version record is
the tool's own.

The engine's statements this module mirrors are in
reference_projects/luanti/src/database/database-sqlite3.cpp (player lines
436-467, auth lines 690-704, mod storage lines 842-855) and
database-postgresql.cpp (player lines 371-424, auth lines 665-676, mod storage
lines 817-848). Positions are stored in the engine's internal units, a tenth
of a node (src/constants.h line 61 `BS`; script/lua_api/l_object.cpp
ObjectRef::l_get_pos divides by it); the API speaks nodes like `get_pos`.
"""

from dataclasses import dataclass, field

from . import codec
from .codec import ItemStack

BS = 10.0
RECORD_MOD = "grug_core"
RECORD_KEY = "world_version"
WORLD_MARKER = "migrate_world:%s"        # grug_core mod storage
CHARACTER_MARKER = "grug_core:migrate:%s"  # player meta
COUNT_KEYS = ("characters", "player_meta", "inventories", "positions",
              "privileges", "mod_storage", "markers")


def _storage_table(store):
    return "entries" if store.engine == "sqlite3" else "mod_storage"


class StepError(Exception):
    """A step broke a rule of the data API."""


@dataclass
class InventoryList:
    """One inventory list: `items` holds one ItemStack per slot."""

    width: int = 0
    items: list = field(default_factory=list)

    @classmethod
    def empty(cls, size, width=0):
        return cls(width, [ItemStack("", 0) for _ in range(size)])

    @property
    def size(self):
        return len(self.items)


@dataclass
class AuthEntry:
    id: int
    name: str
    password: str
    last_login: int
    privileges: list


class ModStorage:
    """One mod's storage (core.get_mod_storage of that mod)."""

    def __init__(self, world, modname):
        self._world = world
        self.modname = modname

    def get(self, key, default=None):
        row = self._world._store.execute(
            "SELECT value FROM %s WHERE modname = ? AND key = ?" % _storage_table(self._world._store),
            (self.modname, codec.to_bytes(key))).fetchone()
        return default if row is None else codec.to_str(bytes(row[0]))

    def items(self):
        rows = self._world._store.execute(
            "SELECT key, value FROM %s WHERE modname = ?" % _storage_table(self._world._store), (self.modname,))
        return {codec.to_str(bytes(k)): codec.to_str(bytes(v)) for k, v in rows}

    def keys(self):
        return list(self.items())

    def set(self, key, value):
        """Writes `value` (a str); "" deletes the key like the game."""
        self._world._guard_storage(self.modname, key)
        storage_write(self._world._store, self.modname, key, value)
        self._world._count("mod_storage")

    def delete(self, key):
        self.set(key, "")


class World:
    """The world as one step sees it. `version` is the step's version."""

    def __init__(self, backends, version):
        self.version = version
        self._backends = backends
        self._player = backends["player"]
        self._auth = backends["auth"]
        self._store = backends["mod_storage"]
        self.counts = dict.fromkeys(COUNT_KEYS, 0)
        self._touched = set()
        self._names = set(self._list_characters())

    # -- bookkeeping --------------------------------------------------------

    def _count(self, key, character=None):
        self.counts[key] += 1
        if character is not None and character not in self._touched:
            self._touched.add(character)
            self.counts["characters"] += 1

    def _character(self, name):
        if name not in self._names:
            raise StepError("no character %r (a step cannot create one)" % name)

    def _guard_storage(self, modname, key):
        if modname == RECORD_MOD and key == RECORD_KEY:
            raise StepError("the world version is written by the tool")

    def _text(self, value):
        """A text parameter: SQLite stores the exact bytes as TEXT."""
        if self._player.engine == "sqlite3":
            return codec.to_bytes(value)
        return value

    def _meta_column(self):
        return "metadata" if self._player.engine == "sqlite3" else "attr"

    def _list_characters(self):
        if not self._player.present:
            return []
        return sorted(row[0] for row in self._player.execute("SELECT name FROM player"))

    def _list_auth(self):
        if not self._auth.present:
            return []
        return sorted(row[0] for row in self._auth.execute("SELECT name FROM auth"))

    # -- characters ---------------------------------------------------------

    def characters(self):
        """Every character (a row of the player backend), offline or not."""
        return sorted(self._names)

    def get_meta(self, name):
        """The character's player meta: key -> string."""
        self._character(name)
        rows = self._player.execute(
            "SELECT %s, value FROM player_metadata WHERE player = ?" % self._meta_column(),
            (name,))
        return {key: value or "" for key, value in rows}

    def set_meta(self, name, key, value):
        """Writes one player meta key; "" deletes it like the game."""
        self._character(name)
        self._meta_write(name, key, value)
        self._count("player_meta", name)

    def _meta_write(self, name, key, value):
        player, column = self._player, self._meta_column()
        cast = "CAST(? AS TEXT)" if player.engine == "sqlite3" else "?"
        player.execute("DELETE FROM player_metadata WHERE player = ? AND %s = %s"
                       % (column, cast), (name, self._text(key)))
        if value != "":
            player.execute("INSERT INTO player_metadata (player, %s, value) VALUES (?, %s, %s)"
                           % (column, cast, cast), (name, self._text(key), self._text(value)))

    def get_inventory(self, name):
        """The character's inventory: list name -> InventoryList, in the
        stored order (engine: slots beyond a list's size are ignored)."""
        self._character(name)
        lists = {}
        rows = self._player.execute(
            "SELECT inv_id, inv_width, inv_name, inv_size FROM player_inventories "
            "WHERE player = ? ORDER BY inv_id", (name,)).fetchall()
        for inv_id, width, list_name, size in rows:
            inv = InventoryList.empty(int(size), int(width))
            for slot, item in self._player.execute(
                    "SELECT slot_id, item FROM player_inventory_items "
                    "WHERE player = ? AND inv_id = ?", (name, inv_id)):
                if item and 0 <= int(slot) < inv.size:
                    inv.items[int(slot)] = ItemStack.parse(item)
            lists[list_name] = inv
        return lists

    def set_inventory(self, name, lists):
        """Replaces the character's whole inventory with `lists` (list name
        -> InventoryList), as the engine saves it."""
        self._character(name)
        player = self._player
        player.execute("DELETE FROM player_inventory_items WHERE player = ?", (name,))
        player.execute("DELETE FROM player_inventories WHERE player = ?", (name,))
        cast = "CAST(? AS TEXT)" if player.engine == "sqlite3" else "?"
        for inv_id, (list_name, inv) in enumerate(lists.items()):
            player.execute("INSERT INTO player_inventories (player, inv_id, inv_width, "
                           "inv_name, inv_size) VALUES (?, ?, ?, %s, ?)" % cast,
                           (name, inv_id, int(inv.width), self._text(list_name), inv.size))
            for slot, stack in enumerate(inv.items):
                player.execute("INSERT INTO player_inventory_items (player, inv_id, "
                               "slot_id, item) VALUES (?, ?, ?, %s)" % cast,
                               (name, inv_id, slot, self._text(stack.to_string())))
        self._count("inventories", name)

    def get_position(self, name):
        """The character's position in nodes, (x, y, z)."""
        self._character(name)
        row = self._player.execute(
            "SELECT posX, posY, posZ FROM player WHERE name = ?", (name,)).fetchone()
        return tuple(float(value) / BS for value in row)

    def set_position(self, name, pos):
        self._character(name)
        x, y, z = (float(value) * BS for value in pos)
        self._player.execute("UPDATE player SET posX = ?, posY = ?, posZ = ? WHERE name = ?",
                             (x, y, z, name))
        self._count("positions", name)

    # -- auth ---------------------------------------------------------------

    def auth_names(self):
        return self._list_auth()

    def get_auth(self, name):
        """The auth entry of `name` with its privileges, or None."""
        if not self._auth.present:
            return None
        row = self._auth.execute(
            "SELECT id, name, password, last_login FROM auth WHERE name = ?", (name,)).fetchone()
        if row is None:
            return None
        privileges = sorted(r[0] for r in self._auth.execute(
            "SELECT privilege FROM user_privileges WHERE id = ?", (row[0],)))
        return AuthEntry(int(row[0]), row[1], row[2] or "", int(row[3]), privileges)

    def set_privileges(self, name, privileges):
        """Replaces the privileges of an existing auth entry."""
        entry = self.get_auth(name)
        if entry is None:
            raise StepError("no auth entry %r (a step cannot create one)" % name)
        self._auth.execute("DELETE FROM user_privileges WHERE id = ?", (entry.id,))
        for privilege in sorted(set(privileges)):
            self._auth.execute("INSERT INTO user_privileges (id, privilege) VALUES (?, ?)",
                               (entry.id, privilege))
        self._count("privileges")

    # -- mod storage --------------------------------------------------------

    def mods(self):
        """The mods with mod storage."""
        return sorted(row[0] for row in self._store.execute(
            "SELECT DISTINCT modname FROM %s" % _storage_table(self._store)))

    def storage(self, modname):
        return ModStorage(self, modname)

    # -- online work (plan section 3) ----------------------------------------

    def mark_world(self, value="1"):
        """Leaves this step's world part for the game's next load:
        grug_core mod storage `migrate_world:<version>`."""
        storage_write(self._store, RECORD_MOD, WORLD_MARKER % self.version, value)
        self._count("markers")

    def mark_character(self, name, value="1"):
        """Leaves this step's part for `name`'s next join: player meta
        `grug_core:migrate:<version>`."""
        self._character(name)
        self._meta_write(name, CHARACTER_MARKER % self.version, value)
        self._count("markers", name)

    # -- the escape hatch ---------------------------------------------------

    def raw(self, kind):
        """The raw DB-API connection of "player", "auth" or "mod_storage"
        (sqlite3 or psycopg), inside the step's transaction; None for an
        SQLite backend whose file does not exist."""
        return self._backends[kind].conn

    def engine(self, kind):
        """"sqlite3" or "postgresql"."""
        return self._backends[kind].engine

    # -- the tool's checks ----------------------------------------------------

    def snapshot(self):
        """What a step may not change: names and layouts."""
        return {
            "characters": self._list_characters(),
            "auth": self._list_auth(),
            "schemas": {kind: b.schema() for kind, b in self._backends.items() if b.present},
        }


def read_record(backends):
    """grug_core's `world_version`, or None."""
    store = backends["mod_storage"]
    row = store.execute("SELECT value FROM %s WHERE modname = ? AND key = ?"
                        % _storage_table(store),
                        (RECORD_MOD, codec.to_bytes(RECORD_KEY))).fetchone()
    return None if row is None else codec.to_str(bytes(row[0]))


def storage_write(store, modname, key, value):
    """Writes one mod-storage key of the backend `store`; "" deletes it."""
    table = _storage_table(store)
    params = (modname, codec.to_bytes(key))
    if value == "":
        store.execute("DELETE FROM %s WHERE modname = ? AND key = ?" % table, params)
    elif store.engine == "sqlite3":
        store.execute("REPLACE INTO entries (modname, key, value) VALUES (?, ?, ?)",
                      params + (codec.to_bytes(value),))
    else:
        store.execute("INSERT INTO mod_storage (modname, key, value) VALUES (?, ?, ?) "
                      "ON CONFLICT (modname, key) DO UPDATE SET value = EXCLUDED.value",
                      params + (codec.to_bytes(value),))


def write_record(backends, version):
    storage_write(backends["mod_storage"], RECORD_MOD, RECORD_KEY, version)


def is_new_world(backends):
    """The tool's new-world rule: no character (no row of the player
    backend) and no mod-storage entry of any mod. Stricter than any game
    rule that looks at characters and mod storage, so a world new to the
    tool is new to the game too."""
    player, store = backends["player"], backends["mod_storage"]
    if player.present and player.execute("SELECT 1 FROM player LIMIT 1").fetchone():
        return False
    return store.execute("SELECT 1 FROM %s LIMIT 1"
                         % _storage_table(store)).fetchone() is None
