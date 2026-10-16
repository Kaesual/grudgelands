"""The map, read-only: opening the map database and decoding its blocks
(Round 50, the pre-reset pass; upgrade contract section 5).

The map database comes from `world.mt` like the engine's
(reference_projects/luanti/src/servermap.cpp lines 70-79 and 620-666):
`backend` (missing: `sqlite3`), and for `postgresql` the connection string
`pgsql_connection`; `readonly_backend` and every other backend are refused.

SQLite: `map.sqlite` in the world directory (database-sqlite3.cpp line
212), opened read-only (`mode=ro`). Two table layouts
(database-sqlite3.cpp lines 226-267): `blocks(x, y, z, data)` since engine
5.12, `blocks(pos, data)` before, where `pos` is z * 2^24 + y * 2^12 + x
(database.cpp lines 15-29). PostgreSQL: `blocks(posX, posY, posZ, data)`
(database-postgresql.cpp lines 162-175), read in a read-only session
(`SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY`), so not even a
mistake could write. The
tool never writes, deletes or alters a map row.

A block row (servermap.cpp lines 686-718: one version byte, then the
block) is decoded for map format 29, the only one an engine since 5.5
writes (serialization.h lines 54-64: SER_FMT_VER_HIGHEST_WRITE 29;
servermap.cpp line 690 saves every block in it). The layout, mapblock.cpp
MapBlock::deSerialize lines 502-650 (written by serialize, lines 388-497),
all of it after the version byte one zstd frame (serialization.cpp
decompressZstd lines 234-277), integers big-endian (util/serialize.h):

  u8 flags, u16 lighting_complete, u32 timestamp
  name-id mapping (nameidmapping.cpp lines 19-33): u8 version 0, u16 count,
      count x (u16 id, u16 length + name)
  u8 content_width (1 or 2), u8 params_width (2)
  4096 x content_width bytes param0, 4096 param1, 4096 param2
      (mapnode.cpp deSerializeBulk lines 612-660), index (z * 16 + y) * 16 + x
  node metadata (nodemetadata.cpp NodeMetadataList::deSerialize lines
      137-183): u8 version (0: none; 1 or 2), u16 count, count x (u16
      position (z * 16 + y) * 16 + x, then NodeMetadata::deSerialize lines
      43-58: u32 count of (u16 length + name, u32 length + value, and from
      version 2 a u8 private flag), then the inventory as text)
  static objects (staticobject.cpp lines 27-35 and 89-109): u8 version,
      u16 count, count x (u8 type, 3 x s32 position, u16 length + data)
  node timers (nodetimer.cpp lines 59-99): u8 data length 10, u16 count,
      count x (u16 position, s32 timeout, s32 elapsed)

The inventory text (inventory.cpp Inventory::deSerialize lines 952-1000,
InventoryList::deSerialize lines 557-605, written by lines 535-555 and
937-950): `List <name> <size>` lines, each followed by `Width <n>`, one
`Item <item string>` or `Empty` line per slot and `EndInventoryList`, then
`EndInventory`. The item string is kept exactly as stored. The decoder reads
every part and requires the block to end exactly after the node timers.

zstd: `compression.zstd` (Python 3.14) or else `zstandard` (Debian
python3-zstandard), imported only when a block is decoded.
"""

import sqlite3
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

from .world import Refusal

BLOCK = 16
NODES = BLOCK * BLOCK * BLOCK
FORMAT = 29
MAP_FILE = "map.sqlite"


class BlockError(ValueError):
    """A block the decoder cannot read."""


# ---------------------------------------------------------------------------
# zstd
# ---------------------------------------------------------------------------

_decompress = None


def zstd():
    """The zstd decompressor of one frame without a content size; Refusal
    when neither module is there."""
    global _decompress
    if _decompress is None:
        try:
            from compression import zstd as module  # Python 3.14
            _decompress = module.decompress
        except ImportError:
            try:
                import zstandard
            except ImportError:
                raise Refusal("backend", "reading map blocks needs zstd: Python 3.14 or "
                              "the zstandard module (Debian: python3-zstandard)") from None

            def _decompress(data):
                return zstandard.ZstdDecompressor().decompressobj().decompress(data)
    return _decompress


# ---------------------------------------------------------------------------
# The decoder
# ---------------------------------------------------------------------------

@dataclass
class InvList:
    """One node inventory list: `items` holds one item string per slot, ""
    for an empty one, exactly as stored."""

    name: str
    width: int = 0
    items: list = field(default_factory=list)


@dataclass
class NodeMeta:
    """The metadata of one node: its string fields (name -> value, bytes
    decoded as the tool's str), the private ones and its inventory lists
    in stored order."""

    fields: dict = field(default_factory=dict)
    private: set = field(default_factory=set)
    lists: list = field(default_factory=list)

    def has_items(self):
        return any(item for inv in self.lists for item in inv.items)


@dataclass
class Block:
    """A decoded block: the node names by content id, param0 per node
    index and the node metadata by index."""

    names: dict
    param0: list
    meta: dict

    def name_at(self, index):
        return self.names.get(self.param0[index])


def _text(data):
    return data.decode("utf-8", "surrogateescape")


class _Reader:
    def __init__(self, data):
        self.data = data
        self.pos = 0

    def take(self, size):
        end = self.pos + size
        if end > len(self.data):
            raise BlockError("the block ends early (byte %d of %d)" % (self.pos, len(self.data)))
        chunk = self.data[self.pos:end]
        self.pos = end
        return chunk

    def u8(self):
        return self.take(1)[0]

    def u16(self):
        return struct.unpack(">H", self.take(2))[0]

    def u32(self):
        return struct.unpack(">I", self.take(4))[0]

    def string16(self):
        return self.take(self.u16())

    def string32(self):
        return self.take(self.u32())

    def line(self):
        """std::getline up to '\\n' (the newline consumed)."""
        end = self.data.find(b"\n", self.pos)
        if end < 0:
            raise BlockError("the inventory text ends without EndInventory")
        text = self.data[self.pos:end]
        self.pos = end + 1
        return text


def _inventory(reader):
    """Inventory::deSerialize: the lists in stored order."""
    lists = []
    while True:
        line = reader.line()
        word, _, rest = line.partition(b" ")
        if word in (b"EndInventory", b"end"):
            return lists
        if word == b"List":
            name, _, size = rest.partition(b" ")
            try:
                size = int(size.split()[0]) if size.split() else 0
            except ValueError:
                raise BlockError("a list size is no number: %r" % line[:80]) from None
            inv = InvList(_text(name), 0, [""] * size)
            _inventory_list(reader, inv)
            lists.append(inv)
        # KeepList and anything else: ignored, as the engine does.


def _inventory_list(reader, inv):
    """InventoryList::deSerialize."""
    slot = 0
    while True:
        line = reader.line()
        word, _, rest = line.partition(b" ")
        if word in (b"EndInventoryList", b"end"):
            return
        if word == b"Width":
            try:
                inv.width = int(rest.split()[0])
            except (ValueError, IndexError):
                raise BlockError("incorrect width property") from None
        elif word in (b"Item", b"Empty", b"Keep"):
            if slot >= len(inv.items):
                raise BlockError("too many items in list %s" % inv.name)
            if word == b"Item":
                inv.items[slot] = _text(rest)
            slot += 1


def decode(data):
    """A block row (the version byte first) as a Block. BlockError when it
    is not format 29 or does not decode exactly."""
    if not data:
        raise BlockError("an empty block row")
    version = data[0]
    if version != FORMAT:
        raise BlockError("map block format %d (the tool reads %d only)" % (version, FORMAT))
    try:
        raw = zstd()(bytes(data[1:]))
    except Refusal:
        raise
    except Exception as err:
        raise BlockError("zstd: %s" % err) from None
    reader = _Reader(raw)
    reader.u8()                     # flags
    reader.u16()                    # lighting_complete
    reader.u32()                    # timestamp
    if reader.u8() != 0:
        raise BlockError("unsupported NameIdMapping version")
    names = {}
    for _ in range(reader.u16()):
        content = reader.u16()
        names[content] = _text(reader.string16())
    content_width, params_width = reader.u8(), reader.u8()
    if content_width not in (1, 2) or params_width != 2:
        raise BlockError("invalid content_width %d or params_width %d"
                         % (content_width, params_width))
    bulk = reader.take(NODES * content_width)
    if content_width == 2:
        param0 = list(struct.unpack(">%dH" % NODES, bulk))
    else:
        param0 = list(bulk)
    reader.take(NODES)              # param1
    param2 = reader.take(NODES)
    if content_width == 1:
        # mapnode.cpp lines 640-650: the old 8-bit ids above 0x7F.
        param0 = [(p << 4) | (param2[i] >> 4) if p > 0x7F else p
                  for i, p in enumerate(param0)]
    meta = {}
    meta_version = reader.u8()
    if meta_version > 2:
        raise BlockError("node metadata version %d not supported" % meta_version)
    if meta_version:
        for _ in range(reader.u16()):
            index = reader.u16()
            node = NodeMeta()
            for _ in range(reader.u32()):
                name = _text(reader.string16())
                node.fields[name] = _text(reader.string32())
                if meta_version >= 2 and reader.u8() == 1:
                    node.private.add(name)
            node.lists = _inventory(reader)
            if index >= NODES:
                raise BlockError("node metadata at index %d" % index)
            meta.setdefault(index, node)  # the engine keeps the first one
    reader.u8()                     # static objects: version
    for _ in range(reader.u16()):
        reader.take(1 + 12)
        reader.string16()
    if reader.u8() != 10:
        raise BlockError("unsupported NodeTimer data length")
    reader.take(10 * reader.u16())
    if reader.pos != len(raw):
        raise BlockError("%d bytes after the node timers" % (len(raw) - reader.pos))
    return Block(names, param0, meta)


def node_index(x, y, z):
    """The index of a node within its block, from its offsets 0..15."""
    return (z * BLOCK + y) * BLOCK + x


def index_offsets(index):
    """(x, y, z) offsets 0..15 of a node index."""
    return index % BLOCK, (index // BLOCK) % BLOCK, index // (BLOCK * BLOCK)


# ---------------------------------------------------------------------------
# The map database
# ---------------------------------------------------------------------------

def _block_as_integer(x, y, z):
    return (z << 24) + (y << 12) + x


def _integer_as_block(i):
    i += 0x800800800
    return ((i & 0xFFF) - 0x800, ((i >> 12) & 0xFFF) - 0x800, ((i >> 24) & 0xFFF) - 0x800)


class MapReader:
    """The world's map database, read-only. `engine` "sqlite3" or
    "postgresql"; `present` is False for an SQLite map that does not exist."""

    def __init__(self, engine, conn, where, layout=None):
        self.engine = engine
        self.conn = conn
        self.where = where
        self.layout = layout      # SQLite: "xyz" or "pos"
        self.reads = 0

    @property
    def present(self):
        return self.conn is not None

    def blocks(self, low, high):
        """Every stored block (pos, data) with low <= pos <= high per axis
        (block coordinates), in x, z, y order."""
        if not self.present:
            return []
        (x0, y0, z0), (x1, y1, z1) = low, high
        if self.engine == "postgresql":
            rows = self.conn.execute(
                "SELECT posx, posy, posz, data FROM blocks WHERE posx BETWEEN %s AND %s "
                "AND posz BETWEEN %s AND %s AND posy BETWEEN %s AND %s "
                "ORDER BY posx, posz, posy", (x0, x1, z0, z1, y0, y1)).fetchall()
            found = [((int(x), int(y), int(z)), bytes(data)) for x, y, z, data in rows]
        elif self.layout == "xyz":
            rows = self.conn.execute(
                "SELECT x, y, z, data FROM blocks WHERE x BETWEEN ? AND ? "
                "AND z BETWEEN ? AND ? AND y BETWEEN ? AND ? ORDER BY x, z, y",
                (x0, x1, z0, z1, y0, y1)).fetchall()
            found = [((x, y, z), bytes(data)) for x, y, z, data in rows]
        else:
            # One key range per block row z: every key decoded, then the
            # rows inside the box read by key.
            keys = []
            for z in range(z0, z1 + 1):
                for (key,) in self.conn.execute(
                        "SELECT pos FROM blocks WHERE pos BETWEEN ? AND ?",
                        (_block_as_integer(-2048, y0, z), _block_as_integer(2047, y1, z))):
                    x, y, kz = _integer_as_block(key)
                    if x0 <= x <= x1 and y0 <= y <= y1 and kz == z:
                        keys.append(((x, y, kz), key))
            found = []
            for pos, key in sorted(keys):
                row = self.conn.execute("SELECT data FROM blocks WHERE pos = ?",
                                        (key,)).fetchone()
                if row is not None:
                    found.append((pos, bytes(row[0])))
            found.sort(key=lambda item: (item[0][0], item[0][2], item[0][1]))
        self.reads += len(found)
        return found

    def any_block(self):
        """One stored block (pos, data), or None for an empty map."""
        if not self.present:
            return None
        if self.engine == "postgresql":
            row = self.conn.execute(
                "SELECT posx, posy, posz, data FROM blocks LIMIT 1").fetchone()
            return row and ((int(row[0]), int(row[1]), int(row[2])), bytes(row[3]))
        if self.layout == "xyz":
            row = self.conn.execute("SELECT x, y, z, data FROM blocks LIMIT 1").fetchone()
            return row and ((row[0], row[1], row[2]), bytes(row[3]))
        row = self.conn.execute("SELECT pos, data FROM blocks LIMIT 1").fetchone()
        return row and (_integer_as_block(row[0]), bytes(row[1]))

    def close(self):
        if self.conn is not None:
            self.conn.close()
            self.conn = None


def _columns_sqlite(conn):
    return sorted(row[1] for row in conn.execute("SELECT * FROM pragma_table_info('blocks')"))


def open_map(world_dir, settings):
    """The map of the world in `world_dir` (`settings`: its world.mt)."""
    engine = settings.get("backend", "sqlite3")
    if "readonly_backend" in settings:
        raise Refusal("backend", "world.mt names a readonly_backend for the map, which the "
                      "tool does not read")
    if engine == "sqlite3":
        path = Path(world_dir, MAP_FILE)
        if not path.is_file():
            return MapReader("sqlite3", None, str(path))
        try:
            conn = sqlite3.connect(path.absolute().as_uri() + "?mode=ro", uri=True,
                                   isolation_level=None, timeout=5.0)
            columns = _columns_sqlite(conn)
        except sqlite3.Error as err:
            raise Refusal("connection", "cannot open %s: %s" % (path, err)) from None
        layouts = {("data", "x", "y", "z"): "xyz", ("data", "pos"): "pos"}
        layout = layouts.get(tuple(columns))
        if layout is None:
            conn.close()
            raise Refusal("layout", "map backend (%s): table blocks has the columns %s, not "
                          "an engine's layout" % (path, ", ".join(columns) or "none"))
        return MapReader("sqlite3", conn, str(path), layout)
    if engine == "postgresql":
        conninfo = settings.get("pgsql_connection", "")
        if not conninfo:
            raise Refusal("world_mt", "world.mt names postgresql for the map backend but no "
                          "pgsql_connection")
        try:
            import psycopg
        except ImportError:
            raise Refusal("backend", "a PostgreSQL world needs psycopg 3 "
                          "(Debian: python3-psycopg)") from None
        try:
            conn = psycopg.connect(conninfo, autocommit=True)
            conn.execute("SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY")
            columns = sorted(row[0] for row in conn.execute(
                "SELECT column_name FROM information_schema.columns WHERE table_schema = "
                "ANY (current_schemas(false)) AND table_name = 'blocks'"))
        except psycopg.Error as err:
            raise Refusal("connection", "map backend: cannot connect: %s"
                          % str(err).strip()) from None
        if columns != ["data", "posx", "posy", "posz"]:
            conn.close()
            raise Refusal("layout", "map backend (pgsql_connection): table blocks has the "
                          "columns %s, not the engine's layout" % (", ".join(columns) or "none"))
        return MapReader("postgresql", conn, "pgsql_connection")
    raise Refusal("backend", "backend = %s is not supported for the map (sqlite3 or "
                  "postgresql; a missing key means sqlite3)" % engine)


def map_errors():
    module = sys.modules.get("psycopg")
    return (sqlite3.Error, module.Error) if module else (sqlite3.Error,)
