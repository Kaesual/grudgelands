#!/usr/bin/env python3
"""Tests of the pre-reset pass (tools/migration/mapblock.py, pack.py and
`--map-reset` in cli.py; Round 50 lane PTOOL).

Run from the repository root:
  python3 -m unittest discover -s tools/r50_ptool -p 'test_*.py'
Locally (Python 3.14: compression.zstd) and in the platform runner's
environment (Debian trixie, Python 3.13 with python3-zstandard; run.sh).

tools/r50_ptool/world/ is a world the engine wrote (make_world.sh with the
probe grug_probe_r50_ptool, the map trimmed to the claims' block boxes by
trim.py): two claims of grug_housing's own model, the containers the probe
placed, and the probe's record of every placed container's lists
(r50_ptool_probe.json.gz, ItemStack:to_string per slot) - the ground truth
the decoder and the packed entries are held to.
"""

import gzip
import hashlib
import io
import json
import math
import re
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools"))
sys.dont_write_bytecode = True

from migration import cli, codec, mapblock, pack  # noqa: E402
from migration.codec import ItemStack  # noqa: E402

WORLD = HERE / "world"
RECORD = json.loads(gzip.decompress((WORLD / "r50_ptool_probe.json.gz").read_bytes()))
CLAIMS = {c["id"]: c for c in RECORD["claims"]}
# The pass's clock: an hour after the claims' last fuel (claim 1 has 21.5
# lumps from its activation, so 21.36 remain: 22 charcoal; claim 2 has 5
# lumps, 4.86 remain: 5).
NOW = min(c["paid_until"] for c in RECORD["claims"]) - 5 * pack.LUMP_SECONDS + 3600
OUTSIDE = {(1051, 150, 1000), (1010, -101, 1000)}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).exists() else None


def key(pos):
    return (pos["x"], pos["y"], pos["z"]) if isinstance(pos, dict) else tuple(pos)


def same_stack(a, b):
    """Two item strings hold the same stack (meta order is the engine's
    unordered_map's)."""
    if not a or not b:
        return (a or "") == (b or "")
    x, y = ItemStack.parse(a), ItemStack.parse(b)
    return (x.name, x.count, x.wear, x.meta) == (y.name, y.count, y.wear, y.meta)


def recorded_lists(container):
    """The probe's lists; core.write_json writes an empty list as null."""
    return {name: stacks or [] for name, stacks in container["lists"].items()}


class PassCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.world = Path(self._tmp.name, "world")
        shutil.copytree(WORLD, self.world)
        (self.world / "r50_ptool_probe.json.gz").unlink()
        self.clock, cli.clock = cli.clock, lambda: NOW

    def tearDown(self):
        cli.clock = self.clock
        self._tmp.cleanup()

    def run_tool(self, *args, world=None, steps=None):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main(["--world", str(world or self.world), *args], test_steps=steps,
                        stdout=out, stderr=err)
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def storage(self, world=None):
        conn = sqlite3.connect(Path(world or self.world, "mod_storage.sqlite"))
        try:
            return {(m, k.decode()): v.decode() for m, k, v in
                    conn.execute("SELECT modname, key, value FROM entries")}
        finally:
            conn.close()

    def set_storage(self, modname, key, value, world=None):
        conn = sqlite3.connect(Path(world or self.world, "mod_storage.sqlite"))
        with conn:
            if value is None:
                conn.execute("DELETE FROM entries WHERE modname = ? AND key = ?",
                             (modname, key.encode()))
            else:
                conn.execute("REPLACE INTO entries VALUES (?, ?, ?)",
                             (modname, key.encode(), value.encode()))
        conn.close()

    def recovered(self, world=None):
        return {k: v for (m, k), v in self.storage(world).items()
                if m == "grug_housing" and k.startswith("recovered:")}

    def hashes(self, world=None):
        world = Path(world or self.world)
        return {name: sha(world / name) for name in ("map.sqlite", "mod_storage.sqlite")}


class DecoderTest(unittest.TestCase):
    def test_every_block_decodes(self):
        conn = sqlite3.connect(WORLD / "map.sqlite")
        rows = conn.execute("SELECT x, y, z, data FROM blocks").fetchall()
        conn.close()
        self.assertGreater(len(rows), 700)
        for x, y, z, data in rows:
            self.assertEqual(data[0], 29)
            block = mapblock.decode(data)
            self.assertEqual(len(block.param0), 4096, (x, y, z))
            self.assertTrue(all(p in block.names for p in set(block.param0)), (x, y, z))

    def test_containers_as_placed(self):
        """Every node the probe filled, decoded from the engine's block: the
        node name, every list, every slot."""
        conn = sqlite3.connect(WORLD / "map.sqlite")
        exact = 0
        for container in RECORD["containers"]:
            x, y, z = key(container["pos"])
            bx, by, bz = x // 16, y // 16, z // 16
            data = conn.execute("SELECT data FROM blocks WHERE x = ? AND y = ? AND z = ?",
                                (bx, by, bz)).fetchone()[0]
            block = mapblock.decode(data)
            index = mapblock.node_index(x - bx * 16, y - by * 16, z - bz * 16)
            self.assertEqual(block.name_at(index), container["node"])
            meta = block.meta[index]
            lists = {inv.name: inv.items for inv in meta.lists}
            want = recorded_lists(container)
            self.assertEqual(sorted(lists), sorted(want))
            for name, stacks in want.items():
                self.assertEqual(len(lists[name]), len(stacks))
                for a, b in zip(lists[name], stacks):
                    self.assertTrue(same_stack(a, b), (container["node"], name, a[:60], b[:60]))
                    exact += a == b
        conn.close()
        self.assertGreater(exact, 100)

    def test_node_fields(self):
        """String fields with their private flags: the furnace's workspace
        record (marked private) and the locked chest's owner."""
        conn = sqlite3.connect(WORLD / "map.sqlite")
        block = mapblock.decode(conn.execute(
            "SELECT data FROM blocks WHERE x = 62 AND y = 9 AND z = 62").fetchone()[0])
        conn.close()
        furnace = block.meta[mapblock.node_index(1004 - 992, 150 - 144, 1000 - 992)]
        locked = block.meta[mapblock.node_index(1003 - 992, 150 - 144, 1000 - 992)]
        self.assertIn("grug_jobs:workspace:builder", furnace.private)
        record = codec.deserialize(furnace.fields["grug_jobs:workspace:builder"])
        self.assertEqual(record["lists"]["src"], ["default:cobble 3"])
        self.assertEqual(locked.fields["owner"], "builder")
        self.assertNotIn("owner", locked.private)

    def test_refusals(self):
        conn = sqlite3.connect(WORLD / "map.sqlite")
        data = conn.execute("SELECT data FROM blocks LIMIT 1").fetchone()[0]
        conn.close()
        for bad, what in ((bytes([28]) + data[1:], "format 28"),
                          (data[:1] + data[1:-3], "truncated"),
                          (data[:1] + b"\x00" * 20, "no zstd frame"),
                          (b"", "empty")):
            with self.assertRaises(mapblock.BlockError, msg=what):
                mapblock.decode(bad)

    def test_inventory_text(self):
        reader = mapblock._Reader(b"List main 3\nWidth 0\nItem default:dirt 5\nEmpty\n"
                                  b"Item \"odd name\" 2\nEndInventoryList\n"
                                  b"List craft 0\nWidth 3\nEndInventoryList\nEndInventory\nX")
        lists = mapblock._inventory(reader)
        self.assertEqual([(i.name, i.width, i.items) for i in lists],
                         [("main", 0, ["default:dirt 5", "", '"odd name" 2']),
                          ("craft", 3, [])])
        self.assertEqual(reader.data[reader.pos:], b"X")
        with self.assertRaises(mapblock.BlockError):
            mapblock._inventory(mapblock._Reader(b"List main 1\nItem a\nItem b\n"))

    def test_old_key(self):
        for pos in ((0, 0, 0), (-1, -7, 5), (2047, -2048, -2048), (63, 9, -62)):
            self.assertEqual(mapblock._integer_as_block(mapblock._block_as_integer(*pos)), pos)


class FrozenTest(unittest.TestCase):
    def test_game_facts(self):
        """The constants pack.py freezes, held to the game's files."""
        registry = (REPO / "mods/PLAYER/grug_housing/registry.lua").read_text()
        for name, value in (("RADIUS", pack.RADIUS), ("MIN_Y", pack.MIN_Y),
                            ("LUMP_SECONDS", pack.LUMP_SECONDS)):
            self.assertRegex(registry, r"\n\tM\.%s = %d\b" % (name, value))
        self.assertIn('return table.concat({"v2", claim.owner, c.x, c.y, c.z, claim.placed_at,'
                      '\n\t\t\tclaim.activated_at, claim.paid_until, claim.expired_for,', registry)
        self.assertIn('if keys[index]:match("^claim:") then storage.set_string(keys[index], "")',
                      registry)
        api = (REPO / "mods/PLAYER/grug_housing/api.lua").read_text()
        self.assertIn('grug_housing.REFUND_ITEM = "%s"' % pack.CHARCOAL, api)
        self.assertIn('["%s"] = model.LUMP_SECONDS,' % pack.CHARCOAL, api)
        workspaces = (REPO / "mods/PLAYER/grug_jobs/workspaces.lua").read_text()
        self.assertIn('local PREFIX = "%s"' % pack.WORKSPACE_PREFIX, workspaces)
        self.assertIn("local record = {lists = {}, process = ctx.process}", workspaces)


class PackTest(PassCase):
    def test_pass(self):
        before = self.storage()
        map_hash = sha(self.world / "map.sqlite")
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events],
                         ["start", "pack_start", "pack_done", "done"])
        start, done = events[1], events[-1]
        self.assertEqual((start["seq"], start["claims"]), (1, 2))
        packed = events[2]
        charcoal = sum(pack.charcoal_count(pack.Claim(c["id"], c["owner"], 0, 0, 0,
                                                      c["paid_until"]), NOW)
                       for c in RECORD["claims"])
        self.assertEqual(charcoal, 27)
        inside = [c for c in RECORD["containers"]
                  if key(c["pos"]) not in OUTSIDE]
        stacks = sum(1 for c in inside for s in recorded_lists(c).values() for i in s if i)
        self.assertEqual(packed["counts"], {
            "claims": 2, "players": 2, "containers": len(inside) + 1, "items": stacks + 3,
            "charcoal": 27, "blocks_read": 763})
        self.assertEqual(packed["nodes"], {
            "default:bookshelf": 1, "default:chest": 6, "default:chest_locked": 1,
            "default:furnace_active": 1, "vessels:shelf": 1, "workspace record": 1})
        self.assertEqual(packed["empty"], {"default:chest": 1})
        self.assertEqual(done["map_reset"], True)
        self.assertEqual((done["mode"], done["target"], done["applied"], done["pack_seq"]),
                         ("migrate", cli.read_checkout(None)[0], [], 1))
        self.assertEqual(done["backends"]["map"], "sqlite3")
        self.assertEqual(sha(self.world / "map.sqlite"), map_hash, "the map is never written")

        after = self.storage()
        added = {k: v for k, v in after.items() if k not in before}
        self.assertEqual(set(before.items()) - set(after.items()), set(), "only new keys")
        recovered = {k: v for (m, k), v in added.items() if k.startswith("recovered:")}
        self.assertEqual(set(added) - {("grug_housing", k) for k in recovered},
                         {("grug_housing", "pack_seq"), ("grug_core", "map_reset_pack:1")})
        self.assertEqual(after[("grug_housing", "pack_seq")], "1")
        builder = sorted((k for k in recovered if k.startswith("recovered:builder:1:")),
                         key=lambda k: int(k.rsplit(":", 1)[1]))
        self.assertEqual(builder, ["recovered:builder:1:%d" % n for n in range(1, 12)])
        self.assertEqual(recovered["recovered:builder:1:11"], "grug_smelting:charcoal 22")
        self.assertEqual(recovered["recovered:neighbor:1:2"], "grug_smelting:charcoal 5")

        # Every packed entry: exactly one placed container inside the area,
        # every slot the same stack.
        unmatched = list(inside)
        for name, text in sorted(recovered.items()):
            stack = ItemStack.parse(text)
            if stack.name == pack.CHARCOAL:
                continue
            self.assertEqual((stack.name, stack.count, stack.wear), (pack.PACKED_ITEM, 1, 0))
            self.assertEqual(stack.meta["seq"], "1")
            lists = codec.deserialize(stack.meta["lists"])
            if name == "recovered:builder:1:4":
                self.assertEqual(stack.meta["node"], "default:chest")
                self.assertEqual(lists, {"main": ["default:stone 1", "default:coal_lump 2",
                                                  "default:cobble 3"]})
                continue
            match = [c for c in unmatched if c["node"] == stack.meta["node"] and
                     sorted(recorded_lists(c)) == sorted(lists) and all(
                         len(lists[n]) == len(s) and all(map(same_stack, lists[n], s))
                         for n, s in recorded_lists(c).items())]
            self.assertEqual(len(match), 1, name)
            unmatched.remove(match[0])
            owner = name.split(":")[1]
            claim = CLAIMS[1 if owner == "builder" else 2]
            x, y, z = key(match[0]["pos"])
            self.assertTrue(abs(x - claim["center"]["x"]) <= 50 and
                            abs(z - claim["center"]["z"]) <= 50 and y >= -100)
        self.assertEqual(unmatched, [])

    def test_largest_entry(self):
        """The 32-slot chest of written books (10000 characters each)."""
        self.run_tool("--map-reset")
        sizes = sorted(len(v.encode()) for v in self.recovered().values())
        self.assertGreater(sizes[-1], 32 * 10000)
        print("\nlargest entry: %d bytes (a 32-slot chest of 10000-character books)"
              % sizes[-1], file=sys.stderr)

    def test_two_passes_append(self):
        self.assertEqual(self.run_tool("--map-reset")[0], 0)
        first = self.recovered()
        # The game's next load handles and deletes the marker.
        self.set_storage("grug_core", "map_reset_pack:1", None)
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        self.assertEqual(events[1]["seq"], 2)
        second = self.recovered()
        self.assertEqual({k: second[k] for k in first}, first, "earlier entries are kept")
        new = {k: v for k, v in second.items() if k not in first}
        self.assertEqual(sorted(new), sorted(k.replace(":1:", ":2:") for k in first))
        for name, text in new.items():
            stack = ItemStack.parse(text)
            if stack.name == pack.PACKED_ITEM:
                self.assertEqual(stack.meta["seq"], "2")
                old = ItemStack.parse(first[name.replace(":2:", ":1:")])
                self.assertEqual(stack.meta["lists"], old.meta["lists"])
        storage = self.storage()
        self.assertEqual(storage[("grug_housing", "pack_seq")], "2")
        self.assertIn(("grug_core", "map_reset_pack:2"), storage)

    def test_game_entries_kept(self):
        """The game's first-start clean-up adds `recovered:<p>:<seq>:<n>.<k>`
        keys (plan D6): opaque to the pass, kept, and the next pass appends."""
        self.assertEqual(self.run_tool("--map-reset")[0], 0)
        self.set_storage("grug_core", "map_reset_pack:1", None)
        extra = "recovered:builder:1:7.1"
        self.set_storage("grug_housing", extra, "grug_housing:packed_container")
        self.set_storage("grug_housing", "recovered:builder:1:2", None)  # taken
        before = self.recovered()
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        after = self.recovered()
        self.assertEqual({k: after[k] for k in before}, before)
        self.assertEqual(len(after) - len(before), 13)
        self.assertTrue(all(":2:" in k for k in set(after) - set(before)))

    def test_pending_marker_refused(self):
        self.assertEqual(self.run_tool("--map-reset")[0], 0)
        hashes = self.hashes()
        code, events, _ = self.run_tool("--map-reset")
        self.assertEqual((code, events[-1]["event"], events[-1]["reason"]),
                         (2, "refusal", "pack_pending"))
        self.assertEqual(self.hashes(), hashes)

    def test_restored_backup(self):
        """A pass on a restored backup gives the same result."""
        backup = Path(self._tmp.name, "backup")
        shutil.copytree(self.world, backup)
        self.assertEqual(self.run_tool("--map-reset")[0], 0)
        first = self.storage()
        shutil.rmtree(self.world)
        shutil.copytree(backup, self.world)
        self.assertEqual(self.run_tool("--map-reset")[0], 0)
        self.assertEqual(self.storage(), first)

    def test_baseline(self):
        for record, code in (("0.48.0", 2), ("0.41.0", 2), (None, 2), ("0.48.1", 0)):
            with self.subTest(record=record):
                world = Path(self._tmp.name, "w" + str(record))
                shutil.copytree(self.world, world)
                self.set_storage("grug_core", "world_version", record, world)
                hashes = self.hashes(world)
                result, events, _ = self.run_tool("--map-reset", world=world)
                self.assertEqual(result, code)
                if code == 2:
                    self.assertEqual(events[-1]["reason"], "pack_baseline")
                    self.assertEqual([e["event"] for e in events], ["start", "refusal"])
                    self.assertEqual(self.hashes(world), hashes)
                    self.assertEqual(self.run_tool("--check", "--map-reset",
                                                   world=world)[1][-1]["reason"],
                                     "pack_baseline")

    def test_steps_after_pass(self):
        """--map-reset packs first and then runs the due steps, in one run."""
        self.set_storage("grug_core", "world_version", "0.48.1")
        seen = []

        class Step:
            @staticmethod
            def migrate(world):
                seen.append(sorted(k for k in world.storage("grug_housing").keys()
                                   if k.startswith("recovered:")))
                world.storage("grug_probe").set("stepped", "1")

        code, events, err = self.run_tool("--map-reset", steps={"0.49.5": Step})
        self.assertEqual(code, 0, err)
        self.assertEqual([e["event"] for e in events],
                         ["start", "pack_start", "pack_done", "step_start", "step_done", "done"])
        self.assertEqual(events[-1]["applied"], ["0.49.5"])
        self.assertEqual(len(seen[0]), 13, "the step sees the committed pass")
        self.assertEqual(self.storage()[("grug_core", "world_version")], "0.49.5")

    def test_check(self):
        hashes = self.hashes()
        code, events, err = self.run_tool("--check", "--map-reset")
        self.assertEqual(code, 0, err)
        done = events[-1]
        self.assertEqual((done["map_checked"], done["map_reset"], done["write_checked"]),
                         (1, True, ["mod_storage"]))
        self.assertEqual(done["backends"]["map"], "sqlite3")
        self.assertEqual(self.hashes(), hashes)
        # Without --map-reset nothing changes in the output.
        code, events, _ = self.run_tool("--check")
        self.assertNotIn("map", events[-1]["backends"])
        self.assertNotIn("map_reset", events[-1])

    def test_bad_block_refused(self):
        conn = sqlite3.connect(self.world / "map.sqlite")
        with conn:
            data = conn.execute("SELECT data FROM blocks WHERE x = 62 AND y = 9 "
                                "AND z = 62").fetchone()[0]
            conn.execute("UPDATE blocks SET data = ? WHERE x = 62 AND y = 9 AND z = 62",
                         (bytes([28]) + data[1:],))
        conn.close()
        hashes = self.hashes()
        code, events, _ = self.run_tool("--map-reset")
        self.assertEqual((code, events[-1]["reason"]), (2, "map_block"))
        self.assertIn("format 28", events[-1]["message"])
        self.assertEqual(self.hashes(), hashes)

    def test_emptied_map_refused(self):
        conn = sqlite3.connect(self.world / "map.sqlite")
        with conn:
            conn.execute("DELETE FROM blocks")
        conn.close()
        code, events, _ = self.run_tool("--map-reset")
        self.assertEqual((code, events[-1]["reason"]), (2, "map_empty"))
        (self.world / "map.sqlite").unlink()
        code, events, _ = self.run_tool("--map-reset")
        self.assertEqual((code, events[-1]["reason"]), (2, "map_empty"))
        # No claims, no map: nothing to pack, still a pass.
        for k in ("claim:1", "claim:2"):
            self.set_storage("grug_housing", k, None)
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        self.assertEqual(events[-1]["backends"]["map"], "absent")
        self.assertEqual(events[2]["counts"]["claims"], 0)

    def test_claim_records(self):
        """A draft without fuel counts, a record that does not decode is
        skipped (the game drops it), a claim away from any block packs
        nothing."""
        self.set_storage("grug_housing", "claim:3",
                         "v2|drafter|5000|20|5000|%d|0|%d|%d|" % (NOW - 60, NOW - 60, NOW - 60))
        self.set_storage("grug_housing", "claim:4", "v1|old|1|2|3")
        self.set_storage("grug_housing", "claim:x", "v2|bad|1|2|3|4|5|6|7|")
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        self.assertIn("2 claim record(s) do not decode", err)
        counts = events[2]["counts"]
        self.assertEqual((counts["claims"], counts["players"], counts["charcoal"]), (3, 2, 27))
        self.assertFalse(any(k.startswith("recovered:drafter:") for k in self.recovered()))

    def test_old_sqlite_layout(self):
        """A map.sqlite created before engine 5.12: blocks(pos, data)."""
        self.run_tool("--map-reset")
        want = self.recovered()
        old = Path(self._tmp.name, "old")
        shutil.copytree(WORLD, old)
        conn = sqlite3.connect(old / "map.sqlite")
        with conn:
            rows = conn.execute("SELECT x, y, z, data FROM blocks").fetchall()
            conn.execute("DROP TABLE blocks")
            conn.execute("CREATE TABLE blocks (pos INT PRIMARY KEY, data BLOB)")
            conn.executemany("INSERT INTO blocks VALUES (?, ?)", [
                (mapblock._block_as_integer(x, y, z), d) for x, y, z, d in rows])
            # Blocks of other columns and rows nearby, outside the boxes.
            conn.executemany("INSERT INTO blocks VALUES (?, ?)", [
                (mapblock._block_as_integer(x, y, z), b"\x00") for x, y, z in
                ((58, 9, 62), (62, 9, 69), (100, 9, 62), (62, -8, 62))])
        conn.close()
        code, events, err = self.run_tool("--map-reset", world=old)
        self.assertEqual(code, 0, err)
        self.assertEqual(events[2]["counts"]["blocks_read"], 763)
        self.assertEqual(self.recovered(old), want)

    def test_backends(self):
        lines = [l for l in (self.world / "world.mt").read_text().splitlines()
                 if not l.startswith("backend =")]
        for extra, reason in (("backend = leveldb", "backend"),
                              ("readonly_backend = sqlite3", "backend"),
                              ("backend = postgresql", "world_mt")):
            with self.subTest(extra=extra):
                (self.world / "world.mt").write_text("\n".join(lines + [extra]) + "\n")
                code, events, _ = self.run_tool("--map-reset")
                self.assertEqual((code, events[-1]["reason"]), (2, reason))
        # A missing `backend` is the engine's sqlite3.
        (self.world / "world.mt").write_text("\n".join(lines) + "\n")
        code, events, err = self.run_tool("--map-reset")
        self.assertEqual(code, 0, err)
        self.assertEqual(events[-1]["backends"]["map"], "sqlite3")

    def test_readonly(self):
        reader = mapblock.open_map(self.world, {"backend": "sqlite3"})
        try:
            with self.assertRaises(sqlite3.OperationalError):
                reader.conn.execute("DELETE FROM blocks")
        finally:
            reader.close()

    def test_lock_refused(self):
        conn = sqlite3.connect(self.world / "mod_storage.sqlite", isolation_level=None)
        conn.execute("BEGIN IMMEDIATE")
        saved = cli.worldmod.SQLITE_BUSY_TIMEOUT
        try:
            cli.worldmod.SQLITE_BUSY_TIMEOUT = 0.1
            code, events, _ = self.run_tool("--map-reset")
        finally:
            cli.worldmod.SQLITE_BUSY_TIMEOUT = saved
            conn.execute("ROLLBACK")
            conn.close()
        self.assertEqual((code, events[-1]["reason"]), (2, "lock"))


class EntryTest(unittest.TestCase):
    def test_charcoal(self):
        claim = pack.Claim(1, "a", 0, 0, 0, 1000)
        L = pack.LUMP_SECONDS
        self.assertEqual(pack.charcoal_count(claim, 1000), 0)
        self.assertEqual(pack.charcoal_count(claim, 2000), 0)
        self.assertEqual(pack.charcoal_count(claim, 999), 1)
        self.assertEqual(pack.charcoal_count(claim, 1000 - L), 1)
        self.assertEqual(pack.charcoal_count(claim, 999 - L), 2)
        scan = pack.ClaimScan(pack.Claim(1, "a", 0, 0, 0, 250 * L))
        entries, counts = pack.build([scan], 3, 0)
        self.assertEqual(entries, [("recovered:a:3:1", "grug_smelting:charcoal 99"),
                                   ("recovered:a:3:2", "grug_smelting:charcoal 99"),
                                   ("recovered:a:3:3", "grug_smelting:charcoal 52")])
        self.assertEqual(counts["charcoal"], 250)

    def test_packed_string(self):
        """The item string the game's ItemStack reads: the engine's quoting
        (codec), the lists as core.serialize writes them."""
        book = ItemStack("default:book_written", 1, 0, {
            "title": 'A "q" \\ ü', "text": "l1\nl2\t\x01x"}).to_string()
        container = pack.Container((0, 0, 0), "default:chest",
                                   {"main": [book, "", "default:dirt 5"], "z": []})
        text = pack.packed_string(container, 4)
        stack = ItemStack.parse(text)
        self.assertEqual(list(stack.meta), ["node", "lists", "seq"])
        self.assertTrue(text.startswith('grug_housing:packed_container 1 0 "\\u0001node'))
        self.assertNotIn("\n", text)
        lists = codec.deserialize(stack.meta["lists"])
        self.assertEqual(lists["main"], [book, "", "default:dirt 5"])
        self.assertIn(lists["z"], ([], {}))
        pack.verify([("k", text)], [pack.ClaimScan(None, 0, [container])], 4)

    def test_worst_case_size(self):
        """32 books of 10000 quote characters: every escaping layer doubles."""
        book = ItemStack("default:book_written", 1, 0, {"text": '"' * 10000}).to_string()
        text = pack.packed_string(pack.Container((0, 0, 0), "default:chest",
                                                 {"main": [book] * 32}), 1)
        print("\nworst case: %d bytes" % len(text.encode()), file=sys.stderr)
        self.assertLess(len(text), 32 * 10000 * 9)


if __name__ == "__main__":
    unittest.main()
