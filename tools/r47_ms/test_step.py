#!/usr/bin/env python3
"""Unit tests of the migration step 0.47.0 (tools/migration/steps/v0_47_0.py)
through the shipped tool, without an engine: a 0.45.1 world (the production
server's version) crosses exactly the step 0.47.0, every character gets the
marker and nothing else is written (no inventory, no other meta, the record
0.47.0); a rerun of the step writes the same marker only. The end-to-end test
with real 0.45.1 and new-game boots is tools/r47_ms/e2e.py; the join part's
fixture tools/r47_ms/portable_test.lua.

Run from the repository root (also in the debian:trixie container, see
tools/r47_ms/run.sh):
  python3 -m unittest discover -s tools/r47_ms -p 'test_*.py'
The world is a copy of the engine-written tools/r43_mt/world (characters
"oldhero" and "newbie").
"""

import io
import json
import shutil
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools"))

from migration import cli, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402
from migration.data import InventoryList  # noqa: E402

# The tool as the 0.47.0 checkout runs it (game.conf 0.47.0, the steps
# 0.44.0, 0.45.0 and 0.47.0 declared; lane D writes the real declaration), so
# later declared steps leave this test alone.
_CHECKOUT = tempfile.TemporaryDirectory()
cli.GAME_CONF = Path(_CHECKOUT.name, "game.conf")
cli.GAME_CONF.write_text("version = 0.47.0\n")
cli.DECLARATION = Path(_CHECKOUT.name, "upgrade.json")
cli.DECLARATION.write_text(json.dumps({"schema": 2, "version": "0.47.0",
                                       "map_reset": ["0.40.1", "0.46.0", "0.47.0"],
                                       "new_server": [], "migrate": ["0.44.0", "0.45.0",
                                                                     "0.47.0"]}))
MARKER = "grug_core:migrate:0.47.0"
OLD_CAPS = "return {groupcaps = {cracky = {maxlevel = 1}}}"


def S(name, count=1, wear=0, **meta):
    return ItemStack(name, count, wear, dict(meta))


class StepTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(REPO / "tools" / "r43_mt" / "world", self.world)
        self.write(self.setup, "0.45.1")

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, fn, version):
        backends = worldmod.open_world(str(self.world))
        try:
            for backend in backends.values():
                if backend.present:
                    backend.begin()
            fn(data.World(backends, version))
            data.write_record(backends, version)
            for backend in backends.values():
                if backend.present:
                    backend.commit()
        finally:
            worldmod.close_world(backends)

    def setup(self, world):
        main = InventoryList.empty(32, 8)
        main.items[1] = S("grug_materials:pick_iron", 1, 1200, tool_capabilities=OLD_CAPS)
        main.items[9] = S("grug_materials:pick_bronze", 1, 65535, _grug_repair_caps=OLD_CAPS)
        world.set_inventory("oldhero", {"main": main})

    def read(self, fn):
        backends = worldmod.open_world(str(self.world))
        try:
            return fn(data.World(backends, "read"))
        finally:
            worldmod.close_world(backends)

    def rows(self, table):
        conn = sqlite3.connect(self.world / "players.sqlite")
        try:
            return conn.execute("SELECT * FROM %s ORDER BY 1, 2, 3" % table).fetchall()
        finally:
            conn.close()

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def test_migrates(self):
        code, events, err = self.run_tool("--check")
        self.assertEqual((code, events[-1]["world_version"], events[-1]["due"]),
                         (0, "0.45.1", ["0.47.0"]), err)
        items_before = self.rows("player_inventory_items")
        meta_before = {n: self.read(lambda w, n=n: w.get_meta(n)) for n in ("oldhero", "newbie")}
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events], ["start", "step_start", "step_done",
                                                         "done"])
        self.assertEqual((events[1]["step"], events[1]["from"]), ("0.47.0", "0.45.1"))
        self.assertEqual(events[2]["counts"], {"characters": 2, "player_meta": 0,
                                               "inventories": 0, "positions": 0,
                                               "privileges": 0, "mod_storage": 0,
                                               "markers": 2})
        self.assertEqual(self.rows("player_inventory_items"), items_before,
                         "no inventory written: the copies are rebuilt at the join")
        for name in ("oldhero", "newbie"):
            meta = self.read(lambda w, n=name: w.get_meta(n))
            self.assertEqual(meta.get(MARKER), "1", name)
            self.assertEqual({k: v for k, v in meta.items() if k != MARKER},
                             meta_before[name], name)
        self.assertEqual(self.read(lambda w: w.storage("grug_core").get("world_version")),
                         "0.47.0")
        code, events, _ = self.run_tool()
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_rerun_writes_the_marker_only(self):
        self.assertEqual(self.run_tool()[0], 0)
        items = self.rows("player_inventory_items")
        step = cli._load_step("0.47.0", cli.STEPS / "v0_47_0.py")
        counts = {}

        def again(world):
            step.migrate(world)
            counts.update(world.counts)
        self.write(again, "0.47.0")
        self.assertEqual((counts["inventories"], counts["player_meta"], counts["markers"]),
                         (0, 0, 2))
        self.assertEqual(self.rows("player_inventory_items"), items)


if __name__ == "__main__":
    unittest.main()
