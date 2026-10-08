#!/usr/bin/env python3
"""Unit tests of the migration step 0.44.0 (tools/migration/steps/v0_44_0.py)
through the shipped tool, without an engine: the removal rules per list and
slot, what stays untouched, the counts, the record and that nothing is due
afterwards. The end-to-end test with real 0.43.0 and 0.44.0 boots is
tools/r44_ms/e2e.py.

Run from the repository root (also in the debian:trixie container, see
tools/r44_ms/run.sh):
  python3 -m unittest discover -s tools/r44_ms -p 'test_*.py'
The world is a copy of the engine-written tools/r43_mt/world (characters
"oldhero" and "newbie"); the inventories are written with the data API.
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

# The tool as the 0.44.0 checkout runs it (game.conf 0.44.0, the step its
# only migrate entry), so later declared steps leave this test alone.
_CHECKOUT = tempfile.TemporaryDirectory()
cli.GAME_CONF = Path(_CHECKOUT.name, "game.conf")
cli.GAME_CONF.write_text("version = 0.44.0\n")
cli.DECLARATION = Path(_CHECKOUT.name, "upgrade.json")
cli.DECLARATION.write_text(json.dumps({"schema": 2, "version": "0.44.0",
                                       "map_reset": ["0.40.1"], "new_server": [],
                                       "migrate": ["0.44.0"]}))
STEP = cli._load_step("0.44.0", cli.STEPS / "v0_44_0.py")
SKILL = ItemStack("grug_abilities:strike", 1, 0, {"description": "Strike"})
SKILL2 = ItemStack("grug_abilities:charge")
MOUNT = ItemStack("grug_mounts:apprentice_mount", 1, 0, {"grug_mounts:owner": "oldhero"})
BOAT = ItemStack("grug_mounts:boat", 1, 0, {"grug_mounts:owner": "oldhero"})
KEEP = {
    "apple": ItemStack("default:apple", 5, 0, {"grug_quality": "fine"}),
    "pick": ItemStack("grug_materials:pick_steel", 1, 1200),
    "bag": ItemStack("grug_inventory:bag_small"),
    "near": ItemStack("grug_abilities_x:strike"),       # another mod: kept
    "mountlike": ItemStack("grug_mounts:saddle_stand"),  # not a tier item: kept
}


def lists_for_hero():
    """oldhero's inventory before the step: list -> {slot: stack}."""
    return {
        "main": (32, {0: SKILL, 1: SKILL2, 2: MOUNT, 7: KEEP["apple"], 8: SKILL,
                      9: BOAT, 10: KEEP["pick"], 20: ItemStack("grug_abilities:retired_id"),
                      31: KEEP["near"]}),
        "craft": (9, {0: SKILL2, 4: ItemStack("grug_mounts:master_mount")}),
        "grug_bag1": (1, {0: KEEP["bag"]}),
        "grug_bag1_content": (8, {0: SKILL, 1: KEEP["mountlike"],
                                  3: ItemStack("grug_mounts:journeyman_mount")}),
        "grug_bag2_content": (0, {}),
        "grug_potion_belt": (4, {2: ItemStack("grug_abilities:heal")}),
    }


# What stays per list and slot (everything else is empty).
EXPECTED = {
    "main": {0: SKILL, 1: SKILL2, 7: KEEP["apple"], 10: KEEP["pick"], 31: KEEP["near"]},
    "craft": {},
    "grug_bag1": {0: KEEP["bag"]},
    "grug_bag1_content": {1: KEEP["mountlike"]},
    "grug_bag2_content": {},
    "grug_potion_belt": {},
}
REMOVED = 9


class StepTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(REPO / "tools" / "r43_mt" / "world", self.world)
        self.write(self.setup)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, fn, version="0.43.0"):
        """Test setup through the data API, committed, with the record."""
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
        lists = {}
        for name, (size, stacks) in lists_for_hero().items():
            inv = InventoryList.empty(size)
            for slot, stack in stacks.items():
                inv.items[slot] = stack
            lists[name] = inv
        world.set_inventory("oldhero", lists)
        world.set_meta("oldhero", "grug_mounts:land_tier", "2")
        world.set_meta("oldhero", "grug_mounts:water_tier", "5")

    def read(self, fn):
        backends = worldmod.open_world(str(self.world))
        try:
            return fn(data.World(backends, "read"))
        finally:
            worldmod.close_world(backends)

    def rows(self, name):
        conn = sqlite3.connect(self.world / "players.sqlite")
        try:
            return conn.execute("SELECT inv_id, slot_id, item FROM player_inventory_items "
                                "WHERE player = ? ORDER BY inv_id, slot_id", (name,)).fetchall()
        finally:
            conn.close()

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def test_rules(self):
        removed = STEP.removed
        self.assertFalse(removed("main", 7, "grug_abilities:strike"), "hotbar slot 8 keeps")
        self.assertTrue(removed("main", 8, "grug_abilities:strike"), "main slot 9 removes")
        self.assertTrue(removed("main", 0, "grug_mounts:boat"), "a mount item never stays")
        self.assertTrue(removed("grug_bag1_content", 0, "grug_abilities:strike"))
        self.assertFalse(removed("craft", 0, "default:apple"))
        self.assertEqual(sorted(STEP.MOUNT_ITEMS), sorted(
            "grug_mounts:" + n for n in ("apprentice_mount", "journeyman_mount", "expert_mount",
                                         "master_mount", "boat", "improved_boat")))

    def test_migrates(self):
        newbie_before = self.rows("newbie")
        meta_before = self.read(lambda w: w.get_meta("oldhero"))
        code, events, err = self.run_tool("--check")
        self.assertEqual((code, events[-1]["world_version"], events[-1]["due"]),
                         (0, "0.43.0", ["0.44.0"]), err)
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events], ["start", "step_start", "step_done",
                                                         "done"])
        self.assertEqual((events[1]["step"], events[1]["from"]), ("0.44.0", "0.43.0"))
        self.assertEqual(events[2]["counts"], {"characters": 1, "player_meta": 0,
                                               "inventories": 1, "positions": 0,
                                               "privileges": 0, "mod_storage": 0,
                                               "markers": 0})
        self.assertEqual(events[-1]["applied"], ["0.44.0"])
        lists = self.read(lambda w: w.get_inventory("oldhero"))
        self.assertEqual(list(lists), list(lists_for_hero()), "every list kept, in order")
        for name, (size, _) in lists_for_hero().items():
            inv = lists[name]
            self.assertEqual(inv.size, size, name)
            got = {slot: s for slot, s in enumerate(inv.items) if not s.is_empty()}
            self.assertEqual(got, EXPECTED[name], name)
        before = sum(len(stacks) for _, stacks in lists_for_hero().values())
        after = sum(len(stacks) for stacks in EXPECTED.values())
        self.assertEqual(before - after, REMOVED)
        self.assertEqual(self.read(lambda w: w.get_meta("oldhero")), meta_before,
                         "player meta (the purchase record) untouched")
        self.assertEqual(self.rows("newbie"), newbie_before, "nothing to remove: not written")
        self.assertEqual(self.read(lambda w: w.storage("grug_core").get("world_version")),
                         "0.44.0")
        code, events, _ = self.run_tool()
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_nothing_to_remove(self):
        self.write(lambda w: w.set_inventory("oldhero", {"main": InventoryList.empty(32)}))
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual(events[2]["counts"]["inventories"], 0)
        self.assertEqual(events[2]["counts"]["characters"], 0)

    def test_from_the_baseline(self):
        """A world without a record (0.41.0) crosses the step too."""
        conn = sqlite3.connect(self.world / "mod_storage.sqlite")
        with conn:
            conn.execute("DELETE FROM entries WHERE modname = 'grug_core' AND key = ?",
                         (b"world_version",))
        conn.close()
        code, events, err = self.run_tool()
        self.assertEqual((code, events[1]["from"], events[-1]["applied"]),
                         (0, "0.41.0", ["0.44.0"]), err)


if __name__ == "__main__":
    unittest.main()
