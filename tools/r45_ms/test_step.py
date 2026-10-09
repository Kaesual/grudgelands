#!/usr/bin/env python3
"""Unit tests of the migration step 0.45.0 (tools/migration/steps/v0_45_0.py)
through the shipped tool, without an engine: the mixtures deleted from every
list, the craft grid moved into empty slots in the give helper's order with
leftovers kept and an empty grid stored with size 0, the 0.44.0 item level
pinned only on gear without one, the dead craft preview and discovery meta,
the marker for every character, the counts, the record and the frozen
tables. The end-to-end test with real 0.44.0 and 0.45.0 boots is
tools/r45_ms/e2e.py.

Run from the repository root (also in the debian:trixie container, see
tools/r45_ms/run.sh):
  python3 -m unittest discover -s tools/r45_ms -p 'test_*.py'
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

# The tool as the 0.45.0 checkout runs it (game.conf 0.45.0, the steps
# 0.44.0 and 0.45.0 declared), so later declared steps leave this test alone.
_CHECKOUT = tempfile.TemporaryDirectory()
cli.GAME_CONF = Path(_CHECKOUT.name, "game.conf")
cli.GAME_CONF.write_text("version = 0.45.0\n")
cli.DECLARATION = Path(_CHECKOUT.name, "upgrade.json")
cli.DECLARATION.write_text(json.dumps({"schema": 2, "version": "0.45.0",
                                       "map_reset": ["0.40.1"], "new_server": [],
                                       "migrate": ["0.44.0", "0.45.0"]}))
STEP = cli._load_step("0.45.0", cli.STEPS / "v0_45_0.py")
MARKER = "grug_core:migrate:0.45.0"


def S(name, count=1, wear=0, **meta):
    return ItemStack(name, count, wear, dict(meta))


def pinned(stack, ilvl, req):
    return ItemStack(stack.name, stack.count, stack.wear,
                     dict(stack.meta, grug_ilvl=str(ilvl), grug_req_level=str(req)))


MIX = S("grug_alchemy:mixture_potion_healing_t1", 3)
MIX2 = S("grug_alchemy:mixture_elixir_vigor_t4")
SWORD = S("grug_gear:sword_bronze")                       # T1, unmodified
BROKEN = S("grug_gear:sword_bronze", 1, 65535, _grug_repair_caps="caps")
STAFF = S("grug_gear:staff_iron", grug_ilvl="10", grug_req_level="10", grug_quality="1",
          description="crafted")                         # crafted at 0.44
ROLLED = S("grug_gear:dagger_steel", grug_ilvl="25", grug_req_level="25",
           grug_ench="x", grug_quality="2")              # rolled or upgraded
ZERO = S("grug_gear:wand_silversteel", grug_ilvl="0", description="old text")
OWNREQ = S("grug_gear:chest_metal_iron", grug_req_level="5")
CHEST = S("grug_gear:chest_metal_iron")
ROBE = S("grug_gear:chest_cloth_silk")                   # T5 cloth
AXE = S("grug_gear:greataxe_bronze")
TRINKET = S("grug_gear:manawell_t3")
RING = S("grug_gear:battlebeat_t1", grug_ilvl="3", grug_req_level="1", grug_ench="y")
SHIELD = S("grug_gear:shield_silversteel")
BOOK = S("grug_gear:spellbook_abyssal_steel", 1, 0, description="Book")
NOTGEAR = S("grug_materials:pick_steel", 1, 1200)
SKILL = S("grug_abilities:strike")
FILL = S("default:dirt", 99)
BAG = S("grug_inventory:bag_small")
CRAFTS = [S("default:torch", 5), S("default:cobble", 4), S("default:stick", 6),
          S("default:paper", 2), S("default:book"), S("default:dirt", 2)]


def hero_lists():
    """oldhero before the step: list -> (size, width, {slot: stack})."""
    main = {0: SKILL, 2: MIX, 8: SWORD, 9: STAFF, 10: ROLLED, 11: ZERO, 12: OWNREQ,
            13: BROKEN, 14: NOTGEAR}
    for slot in (3, 4, 5, 6, 7):
        main[slot] = SKILL
    for slot in range(15, 31):
        main[slot] = FILL
    bag = {0: MIX2, 1: ROBE}
    for slot in range(2, 7):
        bag[slot] = FILL
    craft = {0: MIX, 1: AXE, 2: CRAFTS[0], 3: CRAFTS[1], 5: CRAFTS[2], 6: CRAFTS[3],
             7: CRAFTS[4], 8: CRAFTS[5]}
    return {
        "main": (32, 8, main),
        "craft": (9, 3, craft),
        "craftpreview": (1, 0, {0: S("default:torch", 4)}),
        "craftresult": (1, 0, {}),
        "grug_bag1": (1, 0, {0: BAG}),
        "grug_bag1_content": (8, 0, bag),
        "grug_bag2": (1, 0, {}),
        "grug_bag2_content": (8, 0, {}),          # stale, no bag: never a target
        "grug_bag3": (1, 0, {0: S("grug_inventory:bag_medium")}),
        "grug_bag3_content": (4, 0, {0: FILL, 1: FILL, 2: FILL, 3: FILL}),  # full
        "grug_weapon": (1, 0, {0: SWORD}),
        "grug_chest": (1, 0, {0: CHEST}),
        "grug_offhand": (1, 0, {0: BOOK}),
        "grug_trinket1": (1, 0, {0: TRINKET}),
        "grug_trinket2": (1, 0, {0: RING}),
        "grug_shift": (1, 0, {0: SHIELD}),
        "grug_potion_belt": (4, 0, {1: MIX}),
        "grug_quiver_content": (5, 0, {0: S("grug_gear:arrow", 50)}),
    }


def hero_expected():
    lists = {k: (size, width, dict(stacks)) for k, (size, width, stacks) in hero_lists().items()}
    main, bag, craft = lists["main"][2], lists["grug_bag1_content"][2], lists["craft"][2]
    del main[2], bag[0], craft[0]
    del lists["grug_potion_belt"][2][1]
    del lists["craftpreview"][2][0]
    # The give order's empty slots: main[32], bag 1 slots 1 and 8, hotbar 2
    # and 3 (the mixtures went first); bag 2 has no bag, bag 3 is full.
    main[31], bag[0], bag[7], main[1], main[2] = (pinned(AXE, 3, 1), CRAFTS[0], CRAFTS[1],
                                                   CRAFTS[2], CRAFTS[3])
    for slot in (1, 2, 3, 5, 6):
        del craft[slot]
    main[8] = pinned(SWORD, 3, 1)
    main[11] = pinned(ZERO, 30, 30)                         # "0" is no item level
    main[12] = ItemStack(OWNREQ.name, 1, 0, dict(OWNREQ.meta, grug_ilvl="10"))
    main[13] = pinned(BROKEN, 3, 1)
    bag[1] = pinned(ROBE, 40, 40)
    lists["grug_weapon"][2][0] = pinned(SWORD, 3, 1)
    lists["grug_chest"][2][0] = pinned(CHEST, 10, 10)
    lists["grug_offhand"][2][0] = pinned(BOOK, 50, 50)
    lists["grug_trinket1"][2][0] = pinned(TRINKET, 20, 20)
    lists["grug_shift"][2][0] = pinned(SHIELD, 30, 30)
    return lists


class StepTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(REPO / "tools" / "r43_mt" / "world", self.world)
        self.write(self.setup)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, fn, version="0.44.0"):
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

    @staticmethod
    def build(spec):
        lists = {}
        for name, (size, width, stacks) in spec.items():
            inv = InventoryList.empty(size, width)
            for slot, stack in stacks.items():
                inv.items[slot] = stack
            lists[name] = inv
        return lists

    def setup(self, world):
        world.set_inventory("oldhero", self.build(hero_lists()))
        world.set_meta("oldhero", STEP.SEEN_ITEMS, "return {}")
        world.set_inventory("newbie", self.build({
            "main": (32, 8, {0: SKILL, 9: S("default:apple", 2)}),
            "craft": (9, 3, {}),
            "craftpreview": (1, 0, {}),
        }))

    def read(self, fn):
        backends = worldmod.open_world(str(self.world))
        try:
            return fn(data.World(backends, "read"))
        finally:
            worldmod.close_world(backends)

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def assert_lists(self, lists, expected):
        self.assertEqual(list(lists), list(expected), "every list kept, in order")
        for name, (size, width, stacks) in expected.items():
            inv = lists[name]
            self.assertEqual((inv.size, inv.width), (size, width), name)
            got = {slot: s for slot, s in enumerate(inv.items) if not s.is_empty()}
            self.assertEqual(got, stacks, name)

    def test_tables(self):
        gear = STEP.GEAR
        self.assertEqual(len(gear), 156, "36 weapons, 6 shields, 6 spellbooks, 72 armour, "
                                          "36 trinkets")
        self.assertEqual(gear["grug_gear:sword_bronze"], (3, 1))
        self.assertEqual(gear["grug_gear:bow_iron"], (10, 10))
        self.assertEqual(gear["grug_gear:head_metal_steel"], (20, 20))
        self.assertEqual(gear["grug_gear:feet_leather_scaled"], (30, 30))
        self.assertEqual(gear["grug_gear:legs_cloth_silk"], (40, 40))
        self.assertEqual(gear["grug_gear:spellbook_abyssal_steel"], (50, 50))
        self.assertEqual(gear["grug_gear:manawell_t1"], (3, 1))
        self.assertEqual(gear["grug_gear:reclaimers_mark_t6"], (50, 50))
        self.assertNotIn("grug_gear:arrow", gear)
        self.assertEqual(sorted(set(gear.values())), list(STEP.BRACKETS))
        self.assertEqual(STEP.BAG_SLOTS["grug_inventory:bag_great"], 32)

    def test_meta_int(self):
        def value(text):
            return STEP.meta_int(S("x", **({"k": text} if text is not None else {})), "k")
        cases = {None: 0, "": 0, "0": 0, "3": 3, " 7x": 7, "-2": -2, "abc": 0, "+4": 4,
                 "\t12": 12}
        self.assertEqual({k: value(k) for k in cases}, cases)

    def test_migrates(self):
        code, events, err = self.run_tool("--check")
        self.assertEqual((code, events[-1]["world_version"], events[-1]["due"]),
                         (0, "0.44.0", ["0.45.0"]), err)
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events], ["start", "step_start", "step_done",
                                                         "done"])
        self.assertEqual((events[1]["step"], events[1]["from"]), ("0.45.0", "0.44.0"))
        self.assertEqual(events[2]["counts"], {"characters": 2, "player_meta": 1,
                                               "inventories": 2, "positions": 0,
                                               "privileges": 0, "mod_storage": 0,
                                               "markers": 2})
        lists = self.read(lambda w: w.get_inventory("oldhero"))
        self.assert_lists(lists, hero_expected())
        newbie = self.read(lambda w: w.get_inventory("newbie"))
        self.assertEqual(newbie["craft"].size, 0, "an empty craft grid is stored with size 0")
        self.assertEqual(newbie["main"].items[9], S("default:apple", 2))
        for name in ("oldhero", "newbie"):
            meta = self.read(lambda w, n=name: w.get_meta(n))
            self.assertEqual(meta.get(MARKER), "1", name)
            self.assertNotIn(STEP.SEEN_ITEMS, meta, name)
        self.assertEqual(self.read(lambda w: w.get_meta("oldhero")).get("number"), "42")
        self.assertEqual(self.read(lambda w: w.storage("grug_core").get("world_version")),
                         "0.45.0")
        code, events, _ = self.run_tool()
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_rerun_changes_nothing(self):
        """The step on its own result writes no inventory (every pin is
        there, nothing left to move)."""
        self.assertEqual(self.run_tool()[0], 0)
        before = self.rows()
        counts = {}

        def again(world):
            STEP.migrate(world)
            counts.update(world.counts)
        self.write(again, "0.45.0")
        self.assertEqual(counts["inventories"], 0)
        self.assertEqual(self.rows(), before)

    def test_unknown_bag_and_no_room(self):
        """A bag item the 0.44.0 game did not know takes nothing; with no
        empty slot everything stays in the grid, which keeps its size."""
        spec = {
            "main": (32, 8, {slot: FILL for slot in range(32)}),
            "craft": (9, 3, {4: SWORD}),
            "grug_bag1": (1, 0, {0: S("grug_inventory:bag_mystery")}),
            "grug_bag1_content": (8, 0, {}),
        }
        self.write(lambda w: w.set_inventory("oldhero", self.build(spec)))
        self.assertEqual(self.run_tool()[0], 0)
        lists = self.read(lambda w: w.get_inventory("oldhero"))
        self.assertEqual(lists["craft"].size, 9)
        self.assertEqual(lists["craft"].items[4], pinned(SWORD, 3, 1), "pinned in the grid too")
        self.assertTrue(all(s.is_empty() for s in lists["grug_bag1_content"].items))

    def test_from_the_baseline(self):
        """A world without a record (0.41.0) crosses both steps."""
        conn = sqlite3.connect(self.world / "mod_storage.sqlite")
        with conn:
            conn.execute("DELETE FROM entries WHERE modname = 'grug_core' AND key = ?",
                         (b"world_version",))
        conn.close()
        code, events, err = self.run_tool()
        self.assertEqual((code, events[1]["from"], events[-1]["applied"]),
                         (0, "0.41.0", ["0.44.0", "0.45.0"]), err)

    def rows(self):
        conn = sqlite3.connect(self.world / "players.sqlite")
        try:
            return conn.execute("SELECT player, inv_id, slot_id, item FROM "
                                "player_inventory_items ORDER BY 1, 2, 3").fetchall()
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
