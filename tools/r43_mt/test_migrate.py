#!/usr/bin/env python3
"""Tests of the migration tool (tools/migrate.py, tools/migration/).

Run from the repository root:
  python3 -m unittest discover -s tools/r43_mt -p 'test_*.py'
The target is Debian trixie's Python 3.13 with python3-psycopg and
python3-zstandard (tools/r43_mt/container_test.sh); nothing here needs a
database server.

tools/r43_mt/world/ is a world the engine wrote (tools/r43_mt/make_world.sh
with the probe tools/r43_mt/grug_probe_r43_mt): its strings are the codecs'
ground truth, the values below are the probe's. Steps here are test-only
steps, run through the tool's test hook (cli.main's `test_steps`), never
declared.
"""

import hashlib
import io
import json
import math
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools"))

from migration import cli, codec, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402
from migration.data import InventoryList  # noqa: E402

WORLD = HERE / "world"
TARGET = cli.read_checkout(None)[0]
LONG = "a string long enough to be referenced"
SERIAL = {
    "list": [1, 2, 3, "four", True, False],
    "nested": {"neg": -7, "small": 0.1, "big": 1e300, "tiny": 5e-324,
               "maxint": 9007199254740991, "xp": 3456.75, "level": 12,
               "flags": {"pvp": True, "afk": False}, "name": "Brakka",
               "list": ["a", "b", {"deep": [1, 2]}]},
    "keys": {"end": 1, True: "yes", "_ok": 3, "1": "string one", "a-b": 2,
             -1: "neg", 10: "ten", 1.5: "x"},
    "mixed": {1: 1, 2: 2, "n": 3},
    "string": 'quote" back\\ nl\n cr\r nul\x00 bell\x07 tab\t del\x7f utf8 Gr\u00fc\u00dfe '
              "high\udcff end",
    "number": 42,
    "empty": {},
}
MAIN = {
    0: ItemStack("default:dirt", 99),
    1: ItemStack("grug_materials:pick_steel", 1, 1200),
    2: ItemStack("default:sword_steel", 1, 65535, {
        "description": 'Blade of the Accord\n\u00dcbung "q"',
        "grug_ench": 'return {{tier=2,stat="str"},{tier=1,stat="crit"}}',
        "bell": "a\x07b\tc"}),
    3: ItemStack("default:apple", 5, 0, {"grug_quality": "fine"}),
    4: ItemStack("grug_probe:odd name", 3),
    31: ItemStack("default:torch"),
}
QUESTS = {"active": ["q_wolves", "q_herbs"], "progress": {"q_wolves": {"kills": 3}},
          "tracked": ["q_wolves"], "completed": {"q_first": 1234999, "q_intro": 1234567}}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).exists() else None


class Step:
    """A test-only step from a function."""

    def __init__(self, fn):
        self.migrate = fn


class WorldCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(WORLD, self.world)

    def tearDown(self):
        self._tmp.cleanup()

    def run_tool(self, *args, steps=None):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], test_steps=steps,
                        stdout=out, stderr=err)
        events = [json.loads(line) for line in out.getvalue().splitlines()]
        return code, events, err.getvalue()

    def sql(self, name, statement, params=()):
        conn = sqlite3.connect(self.world / name)
        try:
            with conn:
                return conn.execute(statement, params).fetchall()
        finally:
            conn.close()

    def storage(self, mod, key):
        rows = self.sql("mod_storage.sqlite", "SELECT value FROM entries WHERE modname = ? "
                        "AND key = ?", (mod, key.encode()))
        return rows[0][0].decode() if rows else None

    def meta(self, name, key):
        rows = self.sql("players.sqlite", "SELECT value FROM player_metadata WHERE "
                        "player = ? AND metadata = ?", (name, key))
        return rows[0][0] if rows else None

    def hashes(self):
        if not self.world.is_dir():
            return {}
        return {p.name: sha(p) for p in sorted(self.world.iterdir())}

    def assertResult(self, events, name, code, expected_code):
        self.assertEqual(code, expected_code, events)
        self.assertEqual(events[0]["event"], "start")
        self.assertEqual(events[-1]["event"], name, events)


# ---------------------------------------------------------------------------
# Codecs against the engine's own output
# ---------------------------------------------------------------------------

class SerializeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        conn = sqlite3.connect(WORLD / "mod_storage.sqlite")
        cls.store = {(m, codec.to_str(k)): codec.to_str(v) for m, k, v in
                     conn.execute("SELECT modname, key, value FROM entries")}
        conn.close()
        conn = sqlite3.connect(WORLD / "players.sqlite")
        cls.meta = dict(conn.execute("SELECT metadata, value FROM player_metadata "
                                     "WHERE player = 'oldhero'"))
        conn.close()

    def probe(self, key):
        return self.store[("grug_probe_r43_mt", key)]

    def test_values(self):
        for name, expected in SERIAL.items():
            with self.subTest(name):
                self.assertEqual(codec.deserialize(self.probe("ser:" + name)), expected)

    def test_exact_round_trip(self):
        # Every engine string without references comes back byte for byte.
        for name in SERIAL:
            with self.subTest(name):
                text = self.probe("ser:" + name)
                self.assertEqual(codec.serialize(codec.deserialize(text)), text)
        prep = self.store[("grug_core", "world_preparation")]
        self.assertEqual(codec.serialize(codec.deserialize(prep)), prep)

    def test_special_numbers(self):
        value = codec.deserialize(self.probe("ser:special"))
        self.assertEqual((value["inf"], value["ninf"]), (math.inf, -math.inf))
        self.assertTrue(math.isnan(value["nan"]))
        self.assertEqual(codec.serialize(value), self.probe("ser:special"))

    def test_references(self):
        value = codec.deserialize(self.probe("ser:refs"))
        self.assertEqual(value, {"a": LONG, "b": LONG, "c": {"x": 1, "y": -2.5},
                                 "d": {"x": 1, "y": -2.5}, "e": [LONG, LONG]})
        self.assertIs(value["c"], value["d"])
        self.assertEqual(codec.deserialize(codec.serialize(value)), value)
        cycle = codec.deserialize(self.probe("ser:cycle"))
        self.assertEqual(cycle["name"], "loop")
        self.assertIs(cycle["self"], cycle)
        with self.assertRaises(codec.CodecError):
            codec.serialize(cycle)
        quests = self.meta["grug_quests:state"]
        self.assertTrue(quests.startswith("local _={};_[1]="))
        self.assertEqual(codec.deserialize(quests), QUESTS)

    def test_language(self):
        # Spacing, separators, quotes and escapes other engines and versions write.
        self.assertEqual(codec.deserialize('return { ["a b"] = 1 ; [2]=-inf, \'x\\65\' }'),
                         {"a b": 1, 2: -math.inf, 1: "xA"})
        self.assertEqual(codec.deserialize("return 0x10"), 16)
        self.assertEqual(codec.deserialize("return nil"), None)
        self.assertEqual(codec.deserialize('return "a\\\r\nb"'), "a\nb")
        self.assertEqual(codec.deserialize("return {[1]=1,[2]=2}"), [1, 2])
        for bad in ("return loadstring(\"x\")", "return {", "x = 1", "return 1 2",
                    'return "\\q"', "return {[{}]=1}", "return {[1]=1,[true]=2}"):
            with self.subTest(bad), self.assertRaises(codec.CodecError):
                codec.deserialize(bad)

    def test_serialize_shapes(self):
        self.assertEqual(codec.serialize({"b": [1, None and 0 or 2], "end": None, 3: "x"}),
                         'return {b={1,2},[3]="x"}')
        self.assertEqual(codec.serialize("\x01" + "9"), 'return "\\0019"')
        for bad in (2 ** 60, [None], {(1,): 1}, object()):
            with self.subTest(bad), self.assertRaises(codec.CodecError):
                codec.serialize(bad)

    @unittest.skipUnless(shutil.which("luajit") and os.environ.get("R43_SERIALIZE_LUA"),
                         "needs luajit and R43_SERIALIZE_LUA=<luanti>/builtin/common/serialize.lua")
    def test_engine_reads_ours(self):
        # The engine's core.deserialize under LuaJIT reads what the tool writes.
        values = list(SERIAL.values()) + [QUESTS, {"x": [1.5, -0.0, 1e-300, "\n\r\x00"]}]
        # One value per line, hex-encoded both ways.
        script = (
            "core = {log = function() end}\n"
            "dofile(os.getenv('R43_SERIALIZE_LUA'))\n"
            "for line in io.lines() do\n"
            "  local text = line:gsub('%x%x', function(h) return string.char(tonumber(h, 16)) end)\n"
            "  local value, err = core.deserialize(text)\n"
            "  assert(err == nil, err)\n"
            "  io.write((core.serialize(value):gsub('.', function(c)\n"
            "    return ('%02x'):format(c:byte()) end)), '\\n')\n"
            "end\n")
        lines = [codec.to_bytes(codec.serialize(v)).hex() for v in values]
        result = subprocess.run(["luajit", "-e", script], input="\n".join(lines) + "\n",
                                capture_output=True, text=True, check=True)
        back = [codec.deserialize(bytes.fromhex(line)) for line in result.stdout.split()]
        self.assertEqual(back, values)


class JsonTest(unittest.TestCase):
    def test_engine_json(self):
        conn = sqlite3.connect(WORLD / "mod_storage.sqlite")
        text = codec.to_str(conn.execute("SELECT value FROM entries WHERE key = ?",
                                         (b"json:obj",)).fetchone()[0])
        conn.close()
        value = codec.parse_json(text)
        self.assertEqual(value, {"level": 12, "name": "Brakka", "nested": {"ok": True},
                                 "ratio": 0.5, "tags": ["a", "b"],
                                 "text": 'line\nnext "q" \u00fc'})
        self.assertEqual(codec.write_json(value), text)
        conn = sqlite3.connect(WORLD / "players.sqlite")
        appearance = conn.execute("SELECT value FROM player_metadata WHERE "
                                  "metadata = 'grug_visuals:appearance'").fetchone()[0]
        conn.close()
        self.assertEqual(codec.write_json(codec.parse_json(appearance)), appearance)


class ItemStringTest(unittest.TestCase):
    def test_engine_items(self):
        conn = sqlite3.connect(WORLD / "players.sqlite")
        rows = conn.execute("SELECT inv_id, slot_id, item FROM player_inventory_items "
                            "WHERE player = 'oldhero' AND item != ''").fetchall()
        conn.close()
        expected = {(0, slot): stack for slot, stack in MAIN.items()}
        expected[(1, 4)] = ItemStack("default:stick", 4)
        self.assertEqual({(i, s): ItemStack.parse(item) for i, s, item in rows}, expected)
        for _, _, item in rows:
            with self.subTest(item):
                self.assertEqual(ItemStack.parse(item).to_string(), item)

    def test_forms(self):
        self.assertEqual(ItemStack.parse(""), ItemStack("", 0))
        self.assertEqual(ItemStack.parse("default:dirt 0"), ItemStack("", 0))
        self.assertEqual(ItemStack.parse("default:dirt 3 0 plain"),
                         ItemStack("default:dirt", 3, 0, {"": "plain"}))
        self.assertEqual(ItemStack("a:b", 1, 0, {"k": "v w"}).to_string(),
                         'a:b 1 0 "\\u0001k\\u0002v w\\u0003"')
        self.assertEqual(ItemStack("a:b", 1, 0, {"k\x01": "v\x03"}).to_string(),
                         'a:b 1 0 "\\u0001k\\u0002v\\u0003"')
        self.assertEqual(ItemStack("a:\u00e4").to_string(), '"a:\u00e4"')
        self.assertEqual(ItemStack("", 5).to_string(), "")
        for bad in ('"a"x', "MaterialItem2 1 2", '"open'):
            with self.subTest(bad), self.assertRaises((codec.CodecError, ValueError)):
                ItemStack.parse(bad)


# ---------------------------------------------------------------------------
# Opening a world and refusing one
# ---------------------------------------------------------------------------

class OpenTest(WorldCase):
    def write_mt(self, text):
        (self.world / "world.mt").write_text(text)

    def refused(self, reason, *args):
        before = self.hashes()
        code, events, _ = self.run_tool(*args)
        self.assertResult(events, "refusal", code, 2)
        self.assertEqual(events[-1]["reason"], reason, events)
        self.assertEqual(self.hashes(), before)
        return events[-1]

    def test_world_mt(self):
        (self.world / "world.mt").unlink()
        self.refused("world_mt", "--check")
        self.world = self.world / "nowhere"
        self.refused("world_mt")

    def test_backends(self):
        base = "gameid = grudgelands\nplayer_backend = sqlite3\nauth_backend = sqlite3\n"
        self.write_mt(base)  # no mod_storage_backend: the engine's files default
        self.assertIn("files", self.refused("backend", "--check")["message"])
        self.write_mt(base + "mod_storage_backend = leveldb\n")
        self.refused("backend")
        self.write_mt(base + "mod_storage_backend = postgresql\n")
        self.refused("world_mt")
        self.write_mt(base + "mod_storage_backend = sqlite3\nnested = {\na = b\n")
        self.refused("world_mt")

    def test_postgresql_without_server(self):
        self.write_mt("player_backend = postgresql\nauth_backend = sqlite3\n"
                      "mod_storage_backend = sqlite3\npgsql_player_connection = "
                      "host=/nonexistent-r43-mt dbname=none connect_timeout=1\n")
        try:
            import psycopg  # noqa: F401
            reason = "connection"
        except ImportError:
            reason = "backend"
        self.refused(reason, "--check")

    def test_world_mt_syntax(self):
        self.write_mt('# comment\n  gameid=grudgelands  \ngroup = {\nplayer_backend = files\n'
                      'inner = {\n}\n}\nmotd = """\nplayer_backend = files\n"""\n'
                      "player_backend = sqlite3\nauth_backend = sqlite3\n"
                      "mod_storage_backend=sqlite3\ngarbage line\n")
        code, events, _ = self.run_tool("--check")
        self.assertResult(events, "done", code, 0)

    def test_layout(self):
        self.sql("mod_storage.sqlite", "ALTER TABLE entries ADD COLUMN extra TEXT")
        self.refused("layout", "--check")
        shutil.copy(WORLD / "mod_storage.sqlite", self.world)
        self.sql("auth.sqlite", "DROP TABLE user_privileges")
        self.refused("layout")

    def test_mod_storage_missing(self):
        (self.world / "mod_storage.sqlite").unlink()
        self.refused("database_missing", "--check")
        self.assertFalse((self.world / "mod_storage.sqlite").exists())

    def test_never_joined(self):
        # The engine creates players.sqlite and auth.sqlite at the first
        # join; the tool reads their absence as empty and creates nothing.
        (self.world / "players.sqlite").unlink()
        (self.world / "auth.sqlite").unlink()
        seen = []
        code, events, _ = self.run_tool(steps={TARGET: Step(
            lambda w: seen.append((w.characters(), w.auth_names(), w.raw("player"))))})
        self.assertResult(events, "done", code, 0)
        self.assertEqual(seen, [([], [], None)])
        self.assertEqual(events[-1]["backends"],
                         {"player": "absent", "auth": "absent", "mod_storage": "sqlite3"})
        self.assertFalse((self.world / "players.sqlite").exists())
        self.assertFalse((self.world / "auth.sqlite").exists())

    def test_record(self):
        self.sql("mod_storage.sqlite", "INSERT INTO entries VALUES ('grug_core', ?, ?)",
                 (b"world_version", b"0.42"))
        self.refused("record", "--check")
        self.sql("mod_storage.sqlite", "UPDATE entries SET value = ? WHERE key = ?",
                 (b"99.0.0", b"world_version"))
        message = self.refused("world_newer", "--check")["message"]
        self.assertIn("99.0.0", message)
        self.assertIn(TARGET, message)

    def test_usage(self):
        code, events, _ = self.run_tool("--step", "0.42.0")
        self.assertEqual((code, events[-1]["reason"]), (2, "usage"))

    def test_read_only(self):
        if os.geteuid() == 0:
            self.skipTest("root writes read-only files")
        os.chmod(self.world / "auth.sqlite", 0o444)
        self.refused("write_access", "--check")


class LockTest(WorldCase):
    def setUp(self):
        super().setUp()
        self._timeout = worldmod.SQLITE_BUSY_TIMEOUT
        worldmod.SQLITE_BUSY_TIMEOUT = 0.2
        self.holder = sqlite3.connect(self.world / "players.sqlite", isolation_level=None)
        self.holder.execute("BEGIN IMMEDIATE")

    def tearDown(self):
        self.holder.execute("ROLLBACK")
        self.holder.close()
        worldmod.SQLITE_BUSY_TIMEOUT = self._timeout
        super().tearDown()

    def test_check(self):
        code, events, _ = self.run_tool("--check")
        self.assertResult(events, "refusal", code, 2)
        self.assertEqual(events[-1]["reason"], "lock")

    def test_first_step(self):
        before = self.hashes()
        code, events, _ = self.run_tool(steps={TARGET: Step(lambda w: None)})
        self.assertResult(events, "refusal", code, 2)
        self.assertEqual(events[-1]["reason"], "lock")
        self.assertEqual(self.hashes(), before)


# ---------------------------------------------------------------------------
# Check mode, the command line, exit codes and events
# ---------------------------------------------------------------------------

class CheckTest(WorldCase):
    def test_check_changes_nothing(self):
        before = self.hashes()
        code, events, err = self.run_tool("--check")
        self.assertResult(events, "done", code, 0)
        done = events[-1]
        self.assertEqual((done["mode"], done["world_version"], done["record"],
                          done["new_world"], done["target"], done["due"]),
                         ("check", "0.41.0", None, False, TARGET, []))
        self.assertEqual(done["write_checked"], ["player", "auth", "mod_storage"])
        self.assertEqual(self.hashes(), before)
        self.assertIn("world version 0.41.0", err)

    def test_check_reports_due(self):
        steps = {"0.41.5": Step(lambda w: None), TARGET: Step(lambda w: None)}
        code, events, _ = self.run_tool("--check", steps=steps)
        self.assertEqual(events[-1]["due"], ["0.41.5", TARGET])
        self.assertNotIn("step_start", [e["event"] for e in events])

    def test_command_line(self):
        result = subprocess.run([sys.executable, str(REPO / "tools" / "migrate.py"),
                                 "--world", str(self.world), "--check"],
                                capture_output=True, text=True, cwd=REPO)
        lines = result.stdout.splitlines()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([json.loads(line)["event"] for line in lines], ["start", "done"])
        self.assertIn("migrate:", result.stderr)
        help_text = subprocess.run([sys.executable, str(REPO / "tools" / "migrate.py"),
                                    "--help"], capture_output=True, text=True).stdout
        self.assertIn("cannot detect a running server", " ".join(help_text.split()))
        # A SQLite world never loads psycopg.
        probe = ("import sys; sys.path.insert(0, %r); from migration.cli import main; "
                 "import io; main(['--world', %r, '--check'], stdout=io.StringIO(), "
                 "stderr=io.StringIO()); print('psycopg' in sys.modules)"
                 % (str(REPO / "tools"), str(self.world)))
        result = subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True)
        self.assertEqual(result.stdout.strip(), "False", result.stderr)


# ---------------------------------------------------------------------------
# Steps through the test hook
# ---------------------------------------------------------------------------

def offline_step(world):
    meta = world.get_meta("oldhero")
    state = codec.deserialize(meta["grug_quests:state"])
    state["active"].append("q_new")
    world.set_meta("oldhero", "grug_quests:state", codec.serialize(state))
    world.set_meta("oldhero", "number", "")
    world.set_meta("oldhero", "fresh", "new\tvalue \u00e4\udcff")
    inv = world.get_inventory("oldhero")
    inv["main"].items[0].count = 50
    inv["main"].items[5] = ItemStack("default:mese", 2, 0, {"note": "a b\n"})
    inv["bag"] = InventoryList.empty(4, 2)
    world.set_inventory("oldhero", inv)
    x, y, z = world.get_position("newbie")
    world.set_position("newbie", (x + 1, y, z - 2.5))
    world.set_privileges("newbie", world.get_auth("newbie").privileges + ["fly"])
    probe = world.storage("grug_probe_r43_mt")
    probe.set("added", "v\x00w")
    probe.delete("int")
    prep = codec.deserialize(world.storage("grug_core").get("world_preparation"))
    prep["cursor"] = 5
    world.storage("grug_core").set("world_preparation", codec.serialize(prep))


def marker_step(world):
    world.mark_world()
    for name in world.characters():
        if "q_new" in world.get_meta(name).get("grug_quests:state", ""):
            world.mark_character(name)


class StepTest(WorldCase):
    def test_offline_and_markers(self):
        mt = sha(self.world / "world.mt")
        code, events, _ = self.run_tool(steps={"0.41.5": Step(offline_step),
                                               TARGET: Step(marker_step)})
        self.assertResult(events, "done", code, 0)
        self.assertEqual([(e["event"], e.get("step"), e.get("from")) for e in events[1:-1]],
                         [("step_start", "0.41.5", "0.41.0"), ("step_done", "0.41.5", None),
                          ("step_start", TARGET, "0.41.5"), ("step_done", TARGET, None)])
        self.assertEqual(events[2]["counts"], {
            "characters": 2, "player_meta": 3, "inventories": 1, "positions": 1,
            "privileges": 1, "mod_storage": 3, "markers": 0})
        self.assertEqual(events[4]["counts"]["markers"], 2)
        self.assertEqual(events[-1]["applied"], ["0.41.5", TARGET])
        self.assertEqual(self.storage("grug_core", "world_version"), TARGET)
        self.assertEqual(sha(self.world / "world.mt"), mt)
        # The rows as the engine would read them.
        self.assertEqual(codec.deserialize(self.meta("oldhero", "grug_quests:state"))["active"],
                         ["q_wolves", "q_herbs", "q_new"])
        self.assertIsNone(self.meta("oldhero", "number"))
        raw = self.sql("players.sqlite", "SELECT CAST(value AS BLOB), typeof(value) FROM "
                       "player_metadata WHERE metadata = 'fresh'")
        self.assertEqual(raw, [("new\tvalue \u00e4".encode() + b"\xff", "text")])
        items = dict(((i, s), item) for i, s, item in self.sql(
            "players.sqlite", "SELECT inv_id, slot_id, item FROM player_inventory_items "
            "WHERE player = 'oldhero'"))
        self.assertEqual(items[(0, 0)], "default:dirt 50")
        self.assertEqual(items[(0, 5)], 'default:mese 2 0 "\\u0001note\\u0002a b\\n\\u0003"')
        self.assertEqual(items[(0, 2)], ItemStack(**vars(MAIN[2])).to_string())
        self.assertEqual(len(items), 32 + 9 + 4)
        self.assertEqual(self.sql("players.sqlite", "SELECT inv_id, inv_name, inv_size, "
                                  "inv_width FROM player_inventories WHERE player = "
                                  "'oldhero' ORDER BY inv_id"),
                         [(0, "main", 32, 8), (1, "craft", 9, 3), (2, "bag", 4, 2)])
        self.assertEqual(self.sql("players.sqlite", "SELECT posX, posY, posZ FROM player "
                                  "WHERE name = 'newbie'"), [(10.0, 105.0, -25.0)])
        self.assertEqual(sorted(r[0] for r in self.sql(
            "auth.sqlite", "SELECT privilege FROM user_privileges WHERE id = 2")),
            ["fly", "interact"])
        self.assertEqual(self.sql("mod_storage.sqlite", "SELECT value FROM entries WHERE "
                                  "key = ?", (b"added",)), [(b"v\x00w",)])
        self.assertEqual(self.storage("grug_probe_r43_mt", "int"), None)
        self.assertEqual(codec.deserialize(self.storage("grug_core", "world_preparation"))
                         ["cursor"], 5)
        # Markers: the world part and the affected character only.
        self.assertEqual(self.storage("grug_core", "migrate_world:" + TARGET), "1")
        self.assertEqual(self.meta("oldhero", "grug_core:migrate:" + TARGET), "1")
        self.assertIsNone(self.meta("newbie", "grug_core:migrate:" + TARGET))
        # Nothing is due any more.
        code, events, _ = self.run_tool(steps={"0.41.5": Step(offline_step),
                                               TARGET: Step(marker_step)})
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_api_reads(self):
        seen = {}

        def look(world):
            seen["characters"] = world.characters()
            seen["auth"] = world.auth_names()
            seen["meta"] = world.get_meta("oldhero")
            seen["inv"] = world.get_inventory("oldhero")
            seen["pos"] = world.get_position("oldhero")
            seen["entry"] = world.get_auth("oldhero")
            seen["mods"] = world.mods()
            seen["probe"] = world.storage("grug_probe_r43_mt").items()
            seen["engine"] = world.engine("player")
        self.run_tool(steps={TARGET: Step(look)})
        self.assertEqual(seen["characters"], ["newbie", "oldhero"])
        self.assertEqual(seen["auth"], ["authonly", "newbie", "oldhero"])
        self.assertEqual(codec.deserialize(seen["meta"]["grug_quests:state"]), QUESTS)
        self.assertEqual(seen["meta"]["grug_classes:race"], "human")
        self.assertEqual(list(seen["inv"]), ["main", "craft"])
        self.assertEqual({i: s for i, s in enumerate(seen["inv"]["main"].items)
                          if not s.is_empty()}, MAIN)
        self.assertEqual(seen["inv"]["craft"].width, 3)
        self.assertEqual(seen["pos"], (100.05, 20.5, -30.025))
        self.assertEqual((seen["entry"].privileges, seen["entry"].last_login),
                         (["fly", "interact", "shout"], -1))
        self.assertEqual(seen["mods"], ["grug_core", "grug_probe_r43_mt"])
        self.assertEqual(codec.to_bytes(seen["probe"]["raw:binary"]),
                         b"\x00\x01\x02\x1f \x7f\x80\xff end")
        self.assertEqual(seen["probe"]["key with spaces\n\udcff"], "odd key")
        self.assertEqual((seen["probe"]["int"], seen["probe"]["float"]), ("7", "0.25"))
        self.assertEqual(seen["engine"], "sqlite3")

    def test_failing_step_rolls_back(self):
        def broken(world):
            world.set_meta("oldhero", "number", "changed")
            raise RuntimeError("boom")
        code, events, err = self.run_tool(steps={"0.41.5": Step(lambda w: w.storage(
            "grug_probe_r43_mt").set("first", "yes")), TARGET: Step(broken)})
        self.assertResult(events, "failed", code, 1)
        self.assertEqual((events[-1]["step"], events[-1]["reason"]), (TARGET, "step"))
        self.assertIn("boom", err)
        self.assertEqual(self.storage("grug_core", "world_version"), "0.41.5")
        self.assertEqual(self.storage("grug_probe_r43_mt", "first"), "yes")
        self.assertEqual(self.meta("oldhero", "number"), "42")

    def test_failed_event_with_undecodable_bytes(self):
        # A stored value that is no UTF-8 in the error text: the event is
        # still written (JSON escapes the surrogate) and the exit code is 1.
        def broken(world):
            raise ValueError(world.storage("grug_probe_r43_mt").get("raw:binary"))
        out = io.BytesIO()
        stdout = io.TextIOWrapper(out, encoding="utf-8")
        code = cli.main(["--world", str(self.world)], test_steps={TARGET: Step(broken)},
                        stdout=stdout, stderr=io.StringIO())
        stdout.flush()
        events = [json.loads(line) for line in out.getvalue().decode("utf-8").splitlines()]
        self.assertEqual((code, events[-1]["event"], events[-1]["reason"]), (1, "failed", "step"))
        self.assertIn("\udcff", events[-1]["message"])

    def test_first_step_failure_is_exit_1(self):
        code, events, _ = self.run_tool(steps={TARGET: Step(lambda w: 1 / 0)})
        self.assertResult(events, "failed", code, 1)
        self.assertIsNone(self.storage("grug_core", "world_version"))

    def test_limits(self):
        def create(world):
            world.raw("player").execute("INSERT INTO player (name, pitch, yaw, posX, posY, "
                                        "posZ, hp, breath) VALUES ('ghost',0,0,0,0,0,20,10)")

        def rename(world):
            world.raw("auth").execute("UPDATE auth SET name = 'other' WHERE name = 'authonly'")

        def layout(world):
            world.raw("mod_storage").execute("CREATE TABLE extra (x)")
        cases = [create, rename, layout,
                 lambda w: w.set_meta("ghost", "k", "v"),
                 lambda w: w.mark_character("authonly"),
                 lambda w: w.set_privileges("ghost", ["fly"]),
                 lambda w: w.storage("grug_core").set("world_version", "9.9.9")]
        for fn in cases:
            with self.subTest(fn):
                before = self.hashes()
                code, events, _ = self.run_tool(steps={TARGET: Step(fn)})
                self.assertResult(events, "failed", code, 1)
                self.assertEqual(events[-1]["reason"], "rule")
                self.assertEqual(self.hashes(), before)

    def test_hook_rules(self):
        for version in ("99.0.0", "x"):
            code, events, _ = self.run_tool(steps={version: Step(lambda w: None)})
            self.assertEqual((code, events[-1]["reason"]), (2, "checkout"))
        code, events, _ = self.run_tool(steps={TARGET: object()})
        self.assertEqual((code, events[-1]["reason"]), (2, "checkout"))

    def test_record_decides(self):
        self.sql("mod_storage.sqlite", "INSERT INTO entries VALUES ('grug_core', ?, ?)",
                 (b"world_version", b"0.41.5"))
        ran = []
        code, events, _ = self.run_tool(steps={"0.41.5": Step(lambda w: ran.append(1)),
                                               TARGET: Step(lambda w: ran.append(2))})
        self.assertEqual((code, ran, events[-1]["record"]), (0, [2], "0.41.5"))

    def test_new_world(self):
        # Nothing of an earlier start: an empty mod storage, no player
        # database (a platform may create auth entries before the start).
        self.sql("mod_storage.sqlite", "DELETE FROM entries")
        (self.world / "players.sqlite").unlink()
        before = self.hashes()
        code, events, err = self.run_tool(steps={TARGET: Step(lambda w: 1 / 0)})
        self.assertResult(events, "done", code, 0)
        self.assertEqual((events[-1]["new_world"], events[-1]["world_version"],
                          events[-1]["due"]), (True, None, []))
        self.assertEqual(self.hashes(), before)

    def test_new_world_is_the_games(self):
        # Each trace the game's rule (grug_core/world_version.lua) counts
        # makes the world existing for the tool too.
        self.sql("mod_storage.sqlite", "DELETE FROM entries")
        self.sql("players.sqlite", "DELETE FROM player")
        traces = [lambda: None,  # an empty players.sqlite
                  lambda: (self.world / "players.sqlite").unlink()
                  or (self.world / "players").mkdir(),
                  lambda: (self.world / "players").rmdir()
                  or (self.world / "env_meta.txt").write_text("game_time = 1\n")]
        for trace in traces:
            trace()
            with self.subTest(sorted(p.name for p in self.world.iterdir())):
                code, events, _ = self.run_tool("--check")
                self.assertEqual((code, events[-1]["new_world"], events[-1]["world_version"]),
                                 (0, False, "0.41.0"))

    def test_existing_world_without_characters(self):
        # Saved state but no character: existing, at the baseline.
        self.sql("players.sqlite", "DELETE FROM player")
        code, events, _ = self.run_tool(steps={TARGET: Step(lambda w: None)})
        self.assertEqual((code, events[-1]["new_world"], events[-1]["world_version"],
                          events[-1]["applied"]), (0, False, "0.41.0", [TARGET]))


# ---------------------------------------------------------------------------
# The PostgreSQL dialect without a server: the data API's statements run on
# an SQLite stand-in with the engine's PostgreSQL table and column names.
# ---------------------------------------------------------------------------

PG_SCHEMA = """
CREATE TABLE player (name TEXT PRIMARY KEY, pitch NUMERIC, yaw NUMERIC, posx NUMERIC,
    posy NUMERIC, posz NUMERIC, hp INT, breath INT, creation_date TEXT,
    modification_date TEXT);
CREATE TABLE player_inventories (player TEXT, inv_id INT, inv_width INT, inv_name TEXT,
    inv_size INT, PRIMARY KEY (player, inv_id));
CREATE TABLE player_inventory_items (player TEXT, inv_id INT, slot_id INT, item TEXT,
    PRIMARY KEY (player, inv_id, slot_id));
CREATE TABLE player_metadata (player TEXT, attr TEXT, value TEXT, PRIMARY KEY (player, attr));
CREATE TABLE auth (id INTEGER PRIMARY KEY, name TEXT UNIQUE, password TEXT, last_login INT);
CREATE TABLE user_privileges (id INT, privilege TEXT, PRIMARY KEY (id, privilege));
CREATE TABLE mod_storage (modname TEXT, key BLOB, value BLOB, PRIMARY KEY (modname, key));
INSERT INTO player VALUES ('pg', 0, 0, 15, 25, 35, 20, 10, '', '');
INSERT INTO player_metadata VALUES ('pg', 'a', 'b');
INSERT INTO player_inventories VALUES ('pg', 0, 8, 'main', 2);
INSERT INTO player_inventory_items VALUES ('pg', 0, 0, 'default:dirt 3'), ('pg', 0, 1, '');
INSERT INTO auth VALUES (7, 'pg', 'x', 5);
INSERT INTO user_privileges VALUES (7, 'interact');
"""


class _PgStandIn:
    """psycopg's interface as the data API uses it, on SQLite."""

    def __init__(self, conn):
        self.conn = conn

    def execute(self, statement, params=()):
        assert "?" not in statement, statement
        return self.conn.execute(statement.replace("%s", "?"), params)


class PostgresDialectTest(unittest.TestCase):
    def test_data_api(self):
        conn = sqlite3.connect(":memory:")
        self.addCleanup(conn.close)
        conn.executescript(PG_SCHEMA)
        conn.text_factory = codec.to_str
        backends = {kind: worldmod.Backend(kind, "postgresql", _PgStandIn(conn), "stand-in")
                    for kind in worldmod.KINDS}
        self.assertIsNone(data.read_record(backends))
        empty_dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, empty_dir)
        self.assertFalse(data.is_new_world(backends, empty_dir))
        world = data.World(backends, "0.42.0")
        self.assertEqual(world.characters(), ["pg"])
        self.assertEqual(world.get_meta("pg"), {"a": "b"})
        self.assertEqual(world.get_position("pg"), (1.5, 2.5, 3.5))
        self.assertEqual(world.get_inventory("pg")["main"].items,
                         [ItemStack("default:dirt", 3), ItemStack("", 0)])
        world.set_meta("pg", "a", "c")
        world.mark_character("pg")
        world.set_inventory("pg", {"main": InventoryList(1, [ItemStack("x:y", 2)])})
        world.set_position("pg", (1, 2, 3))
        world.set_privileges("pg", ["fly"])
        world.storage("m").set("k", "v1")
        world.storage("m").set("k", "v2")
        world.mark_world()
        data.write_record(backends, "0.42.0")
        self.assertEqual(world.get_meta("pg"), {"a": "c", "grug_core:migrate:0.42.0": "1"})
        self.assertEqual(world.get_inventory("pg")["main"].items, [ItemStack("x:y", 2)])
        self.assertEqual(world.get_position("pg"), (1.0, 2.0, 3.0))
        self.assertEqual(world.get_auth("pg").privileges, ["fly"])
        self.assertEqual(world.storage("m").items(), {"k": "v2"})
        self.assertEqual(world.storage("grug_core").get("migrate_world:0.42.0"), "1")
        self.assertEqual(data.read_record(backends), "0.42.0")
        self.assertEqual(world.mods(), ["grug_core", "m"])

    def test_layouts(self):
        pg = worldmod.LAYOUTS["postgresql"]
        self.assertEqual(sorted(pg["player"]["player_metadata"]), ["attr", "player", "value"])
        self.assertIn("mod_storage", pg["mod_storage"])
        backend = worldmod.Backend("player", "postgresql", None, "x")
        self.assertEqual(backend.sql("a = ? AND b = ?"), "a = %s AND b = %s")


if __name__ == "__main__":
    unittest.main()
