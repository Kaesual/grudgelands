#!/usr/bin/env python3
"""Unit tests of the migration step 0.67.0 (tools/migration/steps/v0_67_0.py)
through the shipped tool, without an engine: a 0.66.1 world crosses exactly
the step 0.67.0; every metal rod becomes ceil(N / 2) bars of its metal in
place, in every store the step covers:

- every list of a character's inventory (main, a bag, the hotbar store, the
  crafting overflow, the mail attachment list), offline characters alike;
- the `consumed` stacks of the running job (`grug_jobs:job`) and of the
  waiting ones (`grug_jobs:queue`);
- `grug_housing`'s `recovered:*` entries (a plain rod stack and a packed
  container the game has not cleaned, its `lists` in item meta) and the
  `packed:*` content keys (sparse slot tables);
- `grug_mail`'s mailboxes (`box:<name>`, the letters' attachments).

Everything else stays: other stacks with count, wear and meta, other meta
keys and storage keys, the sent copies and tickets (names only), a value
without a rod is not written; no marker; the record is 0.67.0; a rerun of
the step writes nothing. The end-to-end test with real 0.66.1 and
new-game boots is tools/r67_craft/e2e.py.

Run from the repository root (also in the debian:trixie container, see
tools/r67_craft/run.sh):
  python3 -m unittest discover -s tools/r67_craft -p 'test_*.py'
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

from migration import cli, codec, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402
from migration.data import InventoryList  # noqa: E402

# The tool as the 0.67.0 checkout runs it (game.conf 0.67.0, the steps up to
# 0.67.0 declared), so later declared steps leave this test alone.
_CHECKOUT = tempfile.TemporaryDirectory()
cli.GAME_CONF = Path(_CHECKOUT.name, "game.conf")
cli.GAME_CONF.write_text("version = 0.67.0\n")
cli.DECLARATION = Path(_CHECKOUT.name, "upgrade.json")
cli.DECLARATION.write_text(json.dumps({
    "schema": 3, "version": "0.67.0",
    "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0", "0.58.0",
                  "0.59.0", "0.60.0", "0.61.0", "0.62.0", "0.63.0"],
    "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0", "0.67.0"],
    "map_reset_pass": "0.50.0"}))
ROD = "grug_professions:metal_rod_"
BAR = "grug_materials:%s_bar"


def S(name, count=1, wear=0, **meta):
    return ItemStack(name, count, wear, dict(meta))


def job(consumed, **fields):
    record = {"kind": "recipe", "recipe": "grug_gear:sword_iron|x", "quantity": 1,
              "consumed": consumed, "start": 1790000000.5, "finish": 1790000003.5}
    record.update(fields)
    return record


# The 0.66.1 state of oldhero and the storage rows, and what 0.67.0 expects.
JOB = job(["grug_materials:iron_bar 2", ROD + "iron 3"])
QUEUE = [job([ROD + "steel 4", "default:stick"]), job(["default:stick 2"], recipe="t:x")]
PACKED_LISTS = {"main": ["", ROD + "embersteel 7", "default:apple 3"]}
PACKED_CONTENT = {"main": {1: ROD + "bronze 1", 5: "default:torch 10"}, "src": {}}
BOX = {"letters": [
    {"id": 7, "kind": "player", "from": "newbie", "subject": "rods", "body": "here",
     "time": 1790000000, "read": False, "reported": False,
     "items": [ROD + "silversteel 5", "default:apple 2"]},
    {"id": 8, "kind": "npc", "from": "Lost and Found", "subject": "x", "body": "y",
     "time": 1790000001, "read": True, "reported": False, "items": []},
]}
SENT = [{"id": 7, "to": "newbie", "subject": "rods", "body": "here", "time": 1790000000,
         "postage": 35, "attachments": ["Silversteel Rod x5"]}]


class StepTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(REPO / "tools" / "r43_mt" / "world", self.world)
        self.write(self.setup, "0.66.1")

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
        main.items[0] = S("grug_gear:sword_iron", 1, 120, grug_ilvl="10")
        main.items[9] = S(ROD + "iron", 5)
        main.items[10] = S(ROD + "abyssal_steel", 1)
        main.items[11] = S("grug_materials:iron_bar", 7)
        bag = InventoryList.empty(1, 0)
        bag.items[0] = S("grug_inventory:bag_small")
        content = InventoryList.empty(4, 0)
        content.items[2] = S(ROD + "bronze", 99)
        store = InventoryList.empty(8, 0)
        store.items[1] = S(ROD + "steel", 2)
        out = InventoryList.empty(4, 0)
        out.items[0] = S(ROD + "embersteel", 4)
        mail_out = InventoryList.empty(4, 0)
        mail_out.items[3] = S(ROD + "silversteel", 6)
        world.set_inventory("oldhero", {"main": main, "grug_bag1": bag,
                                        "grug_bag1_content": content,
                                        "grug_hotbar_store": store, "grug_craft_out": out,
                                        "grug_mail_out": mail_out})
        world.set_meta("oldhero", "grug_jobs:job", codec.serialize(JOB))
        world.set_meta("oldhero", "grug_jobs:queue", codec.serialize(QUEUE))
        world.set_meta("oldhero", "grug_jobs:favorites", codec.serialize([ROD + "iron|x"]))
        world.set_meta("newbie", "grug_jobs:job", codec.serialize(job(["default:stick 2"])))
        housing = world.storage("grug_housing")
        housing.set("recovered:oldhero:1:1", S(ROD + "iron", 9).to_string())
        housing.set("recovered:oldhero:1:2", S("grug_housing:packed_container", 1, 0,
                                               node="default:chest",
                                               lists=codec.serialize(PACKED_LISTS),
                                               seq="1").to_string())
        housing.set("recovered:oldhero:1:3", S("grug_housing:packed_container", 1, 0,
                                               ref="packed:oldhero:1:3", node="default:chest",
                                               seq="1", description="Packed Chest").to_string())
        housing.set("packed:oldhero:1:3", codec.serialize(PACKED_CONTENT))
        housing.set("recovered:oldhero:1:4", "grug_smelting:charcoal 12")
        housing.set("pack_seq", "1")
        mail = world.storage("grug_mail")
        mail.set("box:oldhero", codec.serialize(BOX))
        mail.set("sent:newbie", codec.serialize(SENT))
        mail.set("box:newbie", codec.serialize({"letters": []}))

    def read(self, fn):
        backends = worldmod.open_world(str(self.world))
        try:
            return fn(data.World(backends, "read"))
        finally:
            worldmod.close_world(backends)

    def rows(self, table, where=""):
        name = "mod_storage.sqlite" if table == "entries" else "players.sqlite"
        conn = sqlite3.connect(self.world / name)
        try:
            return conn.execute("SELECT * FROM %s %s ORDER BY 1, 2" % (table, where)).fetchall()
        finally:
            conn.close()

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(self.world), *args], stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def test_migrates(self):
        code, events, err = self.run_tool("--check")
        self.assertEqual((code, events[-1]["world_version"], events[-1]["due"]),
                         (0, "0.66.1", ["0.67.0"]), err)
        inv_before = self.read(lambda w: w.get_inventory("oldhero"))
        newbie_items = self.rows("player_inventory_items", "WHERE player = 'newbie'")
        newbie_meta = self.read(lambda w: w.get_meta("newbie"))
        storage_before = dict(self.read(lambda w: {
            mod: w.storage(mod).items() for mod in w.mods()}))
        code, events, err = self.run_tool()
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events], ["start", "step_start", "step_done",
                                                         "done"])
        self.assertEqual((events[1]["step"], events[1]["from"]), ("0.67.0", "0.66.1"))
        self.assertEqual(events[2]["counts"], {"characters": 1, "player_meta": 2,
                                               "inventories": 1, "positions": 0,
                                               "privileges": 0, "mod_storage": 4,
                                               "markers": 0})
        # Inventories: each rod stack in place as ceil(N / 2) bars.
        want = {("main", 9): S(BAR % "iron", 3), ("main", 10): S(BAR % "abyssal_steel", 1),
                ("grug_bag1_content", 2): S(BAR % "bronze", 50),
                ("grug_hotbar_store", 1): S(BAR % "steel", 1),
                ("grug_craft_out", 0): S(BAR % "embersteel", 2),
                ("grug_mail_out", 3): S(BAR % "silversteel", 3)}
        inv = self.read(lambda w: w.get_inventory("oldhero"))
        for list_name, before in inv_before.items():
            self.assertEqual((inv[list_name].size, inv[list_name].width),
                             (before.size, before.width), list_name)
            for slot, stack in enumerate(before.items):
                expected = want.get((list_name, slot), stack)
                self.assertEqual(inv[list_name].items[slot].to_string(), expected.to_string(),
                                 (list_name, slot))
        self.assertEqual(self.rows("player_inventory_items", "WHERE player = 'newbie'"),
                         newbie_items, "newbie's inventory not written")
        # The jobs' consumed stacks.
        meta = self.read(lambda w: w.get_meta("oldhero"))
        running = codec.deserialize(meta["grug_jobs:job"])
        self.assertEqual(running["consumed"], ["grug_materials:iron_bar 2", BAR % "iron" + " 2"])
        self.assertEqual({k: v for k, v in running.items() if k != "consumed"},
                         {k: v for k, v in JOB.items() if k != "consumed"})
        waiting = codec.deserialize(meta["grug_jobs:queue"])
        self.assertEqual([entry["consumed"] for entry in waiting],
                         [[BAR % "steel" + " 2", "default:stick"], ["default:stick 2"]])
        self.assertEqual(meta["grug_jobs:favorites"], codec.serialize([ROD + "iron|x"]),
                         "favourites are left to the game (they read as outputs)")
        self.assertNotIn("grug_core:migrate:0.67.0", meta, "no marker")
        self.assertEqual(self.read(lambda w: w.get_meta("newbie")), newbie_meta)
        # grug_housing.
        housing = self.read(lambda w: w.storage("grug_housing").items())
        self.assertEqual(housing["recovered:oldhero:1:1"], BAR % "iron" + " 5")
        packed = ItemStack.parse(housing["recovered:oldhero:1:2"])
        self.assertEqual((packed.name, packed.meta["node"], packed.meta["seq"]),
                         ("grug_housing:packed_container", "default:chest", "1"))
        self.assertEqual(codec.deserialize(packed.meta["lists"]),
                         {"main": ["", BAR % "embersteel" + " 4", "default:apple 3"]})
        self.assertEqual(housing["recovered:oldhero:1:3"],
                         storage_before["grug_housing"]["recovered:oldhero:1:3"])
        content = codec.deserialize(housing["packed:oldhero:1:3"])
        self.assertEqual(content["main"], {1: BAR % "bronze", 5: "default:torch 10"})
        for key in ("recovered:oldhero:1:4", "pack_seq"):
            self.assertEqual(housing[key], storage_before["grug_housing"][key], key)
        # grug_mail.
        mail = self.read(lambda w: w.storage("grug_mail").items())
        box = codec.deserialize(mail["box:oldhero"])
        self.assertEqual(box["letters"][0]["items"], [BAR % "silversteel" + " 3",
                                                      "default:apple 2"])
        self.assertEqual({k: v for k, v in box["letters"][0].items() if k != "items"},
                         {k: v for k, v in BOX["letters"][0].items() if k != "items"})
        # (the codec reads an empty table as a dict)
        self.assertEqual(box["letters"][1], dict(BOX["letters"][1], items={}))
        for key in ("sent:newbie", "box:newbie"):
            self.assertEqual(mail[key], storage_before["grug_mail"][key], key)
        self.assertEqual(self.read(lambda w: w.storage("grug_core").get("world_version")),
                         "0.67.0")
        code, events, _ = self.run_tool()
        self.assertEqual((code, events[-1]["due"], events[-1]["applied"]), (0, [], []))

    def test_rerun_writes_nothing(self):
        self.assertEqual(self.run_tool()[0], 0)
        players = self.rows("player_inventory_items")
        storage = self.rows("entries")
        step = cli._load_step("0.67.0", cli.STEPS / "v0_67_0.py")
        counts = {}

        def again(world):
            step.migrate(world)
            counts.update(world.counts)
        self.write(again, "0.67.0")
        self.assertEqual((counts["inventories"], counts["player_meta"], counts["mod_storage"],
                          counts["markers"]), (0, 0, 0, 0))
        self.assertEqual(self.rows("player_inventory_items"), players)
        self.assertEqual([r for r in self.rows("entries") if r[1] != b"world_version"],
                         [r for r in storage if r[1] != b"world_version"])

    def test_refund_rules(self):
        step = cli._load_step("0.67.0", cli.STEPS / "v0_67_0.py")
        for count, bars in ((1, 1), (2, 1), (3, 2), (99, 50)):
            self.assertEqual(step.refund_string(ROD + "iron %d" % count),
                             (BAR % "iron") + ("" if bars == 1 else " %d" % bars))
        self.assertEqual(step.refund_string(ROD + "steel"), BAR % "steel")
        self.assertIsNone(step.refund_string("grug_materials:iron_bar 3"))
        self.assertIsNone(step.refund_string(""))
        self.assertIsNone(step.refund_string(ROD + "unknown 3"), "only the six metals")
        self.assertEqual(sorted(step.BAR_OF.values()),
                         sorted(BAR % m for m in ("bronze", "iron", "steel", "silversteel",
                                                  "embersteel", "abyssal_steel")))
        self.assertIsNone(step.refund_serialized("", step.refund_jobs))
        self.assertIsNone(step.refund_serialized("not lua", step.refund_jobs),
                          "an unreadable value is left alone")


if __name__ == "__main__":
    unittest.main()
