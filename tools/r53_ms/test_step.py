#!/usr/bin/env python3
"""Unit tests of the migration step 0.53.0 (tools/migration/steps/v0_53_0.py)
through the shipped tool, without an engine: a 0.52.1 world crosses exactly
the step 0.53.0; the stored talents, the used respec and every stored
talent window are deleted, the three retired skills leave every list (the
shown hotbar, the other layout, main[9..], a bag), everything else stays
(other meta, other stacks with count, wear and meta, a look-alike key, a
non-retired skill), every character gets the marker and the record is
0.53.0; a character without any of it gets only the marker (no inventory
write); a rerun of the step writes the markers only. The end-to-end test
with real 0.52.1 and new-game boots is tools/r53_ms/e2e.py; the join part's
fixture tools/r53_ms/portable_test.lua.

Run from the repository root (also in the debian:trixie container, see
tools/r53_ms/run.sh):
  python3 -m unittest discover -s tools/r53_ms -p 'test_*.py'
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

# The tool as the 0.53.0 checkout runs it (game.conf 0.53.0, the steps up to
# 0.53.0 declared), so later declared steps leave this test alone.
_CHECKOUT = tempfile.TemporaryDirectory()
cli.GAME_CONF = Path(_CHECKOUT.name, "game.conf")
cli.GAME_CONF.write_text("version = 0.53.0\n")
cli.DECLARATION = Path(_CHECKOUT.name, "upgrade.json")
cli.DECLARATION.write_text(json.dumps({
    "schema": 3, "version": "0.53.0",
    "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"],
    "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"],
    "map_reset_pass": "0.50.0"}))
MARKER = "grug_core:migrate:0.53.0"
CLEARED = {
    "grug_classes:talents": "ironbound=3,whitehot=1,cinderfall=1",
    "grug_classes:respec_used": "1",
    "grug_classes:talent_ready:whitehot": "1792000000",
    "grug_classes:talent_ready:ruination": "1792000100",
    "grug_classes:unbroken_ready": "1792000200",
    "grug_classes:untouchable_ready": "1792000300",
}
KEPT = {
    "grug_classes:class": "mage",
    "grug_classes:race": "human",
    "grug_abilities:initial_kit_given": "1",
    "grug_classes:talents_note": "a look-alike key stays",
    "grug_inventory:hotbar_layout": "A",
}


def S(name, count=1, wear=0, **meta):
    return ItemStack(name, count, wear, dict(meta))


class StepTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(REPO / "tools" / "r43_mt" / "world", self.world)
        self.write(self.setup, "0.52.1")

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
        # oldhero: a 0.52.1 Mage with spent talents, stored windows, the used
        # respec and the retired skills on both layouts, in main[9..] and in
        # a bag. newbie keeps the engine's world as it is.
        for key, value in {**CLEARED, **KEPT}.items():
            world.set_meta("oldhero", key, value)
        main = InventoryList.empty(32, 8)
        main.items[0] = S("grug_abilities:strike", wear=3, grug_skin="x")
        main.items[1] = S("grug_abilities:cinderfall", description="Cinderfall")
        main.items[2] = S("grug_abilities:ice_nova")
        main.items[9] = S("grug_abilities:glacial_ward")
        main.items[12] = S("default:apple", 7)
        store = InventoryList.empty(8, 0)
        store.items[0] = S("grug_abilities:pinning_shot")
        store.items[3] = S("grug_abilities:fireball")
        bag = InventoryList.empty(1, 0)
        bag.items[0] = S("grug_inventory:bag_small")
        content = InventoryList.empty(4, 0)
        content.items[1] = S("grug_abilities:cinderfall")
        content.items[2] = S("default:torch", 20, 0, owner="oldhero")
        world.set_inventory("oldhero", {"main": main, "grug_hotbar_store": store,
                                        "grug_bag1": bag, "grug_bag1_content": content})

    def read(self, fn):
        backends = worldmod.open_world(str(self.world))
        try:
            return fn(data.World(backends, "read"))
        finally:
            worldmod.close_world(backends)

    def rows(self, player):
        conn = sqlite3.connect(self.world / "players.sqlite")
        try:
            return conn.execute("SELECT * FROM player_inventory_items WHERE player = ? "
                                "ORDER BY 1, 2, 3", (player,)).fetchall()
        finally:
            conn.close()

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def test_migrates(self):
        code, events, err = self.run_tool("--check")
        self.assertEqual((code, events[-1]["world_version"], events[-1]["due"]),
                         (0, "0.52.1", ["0.53.0"]), err)
        inv_before = self.read(lambda w: w.get_inventory("oldhero"))
        meta_before = self.read(lambda w: w.get_meta("oldhero"))
        newbie_meta = self.read(lambda w: w.get_meta("newbie"))
        newbie_items = self.rows("newbie")
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events], ["start", "step_start", "step_done",
                                                         "done"])
        self.assertEqual((events[1]["step"], events[1]["from"]), ("0.53.0", "0.52.1"))
        self.assertEqual(events[2]["counts"], {"characters": 2, "player_meta": len(CLEARED),
                                               "inventories": 1, "positions": 0,
                                               "privileges": 0, "mod_storage": 0,
                                               "markers": 2})
        meta = self.read(lambda w: w.get_meta("oldhero"))
        self.assertEqual(meta.get(MARKER), "1")
        self.assertEqual({k: v for k, v in meta.items() if k != MARKER},
                         {k: v for k, v in meta_before.items() if k not in CLEARED},
                         "the talent keys gone, every other key kept")
        for key, value in KEPT.items():
            self.assertEqual(meta.get(key), value, key)
        inv = self.read(lambda w: w.get_inventory("oldhero"))
        gone = {("main", 1), ("main", 9), ("grug_hotbar_store", 0), ("grug_bag1_content", 1)}
        for list_name, before in inv_before.items():
            self.assertEqual((inv[list_name].size, inv[list_name].width),
                             (before.size, before.width), list_name)
            for slot, stack in enumerate(before.items):
                got = inv[list_name].items[slot]
                if (list_name, slot) in gone:
                    self.assertTrue(stack.name.startswith("grug_abilities:"))
                    self.assertTrue(got.is_empty(), (list_name, slot))
                else:
                    self.assertEqual(got.to_string(), stack.to_string(), (list_name, slot))
        self.assertEqual(inv["main"].items[0].to_string(),
                         S("grug_abilities:strike", wear=3, grug_skin="x").to_string())
        self.assertEqual(inv["grug_hotbar_store"].items[3].name, "grug_abilities:fireball")
        newbie = self.read(lambda w: w.get_meta("newbie"))
        self.assertEqual({k: v for k, v in newbie.items() if k != MARKER}, newbie_meta)
        self.assertEqual(newbie.get(MARKER), "1")
        self.assertEqual(self.rows("newbie"), newbie_items, "newbie's inventory not written")
        self.assertEqual(self.read(lambda w: w.storage("grug_core").get("world_version")),
                         "0.53.0")
        code, events, _ = self.run_tool()
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_rerun_writes_the_markers_only(self):
        self.assertEqual(self.run_tool()[0], 0)
        items = self.rows("oldhero")
        step = cli._load_step("0.53.0", cli.STEPS / "v0_53_0.py")
        counts = {}

        def again(world):
            step.migrate(world)
            counts.update(world.counts)
        self.write(again, "0.53.0")
        self.assertEqual((counts["inventories"], counts["player_meta"], counts["markers"]),
                         (0, 0, 2))
        self.assertEqual(self.rows("oldhero"), items)

    def test_empty_values_are_not_written(self):
        # An empty meta value is no key (the game deletes it): nothing to do.
        step = cli._load_step("0.53.0", cli.STEPS / "v0_53_0.py")
        self.assertEqual(step.cleared_keys({"grug_classes:talents": "",
                                            "grug_classes:talent_ready:x": "5",
                                            "grug_classes:talent_readyx": "5",
                                            "grug_classes:class": "mage"}),
                         ["grug_classes:talent_ready:x"])


if __name__ == "__main__":
    unittest.main()
