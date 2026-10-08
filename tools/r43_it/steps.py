"""The test-only migration steps on the tool's side (Round 43 lane IT). Never
declared: tools/r43_it/tool_run.py hands them to the tool through its Python
test hook. Their online handlers are in grug_test_migrations.lua (same
versions). Every step works on the data API (tools/migration/data.py).

  0.41.1  offline only: the character "hero" (when the world has it) gets the
          player meta it:offline, an apple stack with item meta in main slot
          1 and the fly privilege; the probe's mod storage gets "offline"
          and loses "delete_me"
  0.41.2  world online work: grug_core migrate_world:0.41.2
  0.41.3  character online work for "hero" (not "bystander")
  0.41.4  a second character marker for "hero"
  0.41.5  with a map reset: the probe's "offline_reset" and world online work

Failure cases (PostgreSQL run, pg_test.py), each used under a free version:
  fail    writes on every backend, then raises: everything rolls back, exit 1
  rename  renames an auth entry through the raw connection: the tool's rule
          check rolls back, exit 1
"""

from types import SimpleNamespace

from migration.codec import ItemStack

HERO = "hero"
PROBE_MOD = "grug_probe_r43_it"
APPLE = ItemStack("default:apple", 7, 0, {
    "description": "Migrated apple\n\"0.41.1\"", "grug_it": "offline"})


def _v0_41_1(world):
    if HERO in world.characters():
        world.set_meta(HERO, "it:offline", "0.41.1")
        lists = world.get_inventory(HERO)
        lists["main"].items[0] = APPLE
        world.set_inventory(HERO, lists)
        entry = world.get_auth(HERO)
        world.set_privileges(HERO, entry.privileges + ["fly"])
    store = world.storage(PROBE_MOD)
    store.set("offline", "0.41.1")
    store.delete("delete_me")


def _v0_41_2(world):
    world.mark_world("w-0.41.2")


def _v0_41_3(world):
    world.mark_character(HERO, "c-0.41.3")


def _v0_41_4(world):
    world.mark_character(HERO, "c-0.41.4")


def _v0_41_5(world):
    world.storage(PROBE_MOD).set("offline_reset", "0.41.5")
    world.mark_world("w-0.41.5")


def _fail(world):
    world.set_meta(HERO, "it:fail", "written")
    world.set_privileges(HERO, ["shout"])
    world.storage(PROBE_MOD).set("fail", "written")
    world.mark_world()
    raise RuntimeError("the IT failure step raises after writing")


def _rename(world):
    world.raw("auth").execute("UPDATE auth SET name = 'renamed' WHERE name = 'bystander'")


STEPS = {
    "0.41.1": SimpleNamespace(migrate=_v0_41_1),
    "0.41.2": SimpleNamespace(migrate=_v0_41_2),
    "0.41.3": SimpleNamespace(migrate=_v0_41_3),
    "0.41.4": SimpleNamespace(migrate=_v0_41_4),
    "0.41.5": SimpleNamespace(migrate=_v0_41_5),
    "fail": SimpleNamespace(migrate=_fail),
    "rename": SimpleNamespace(migrate=_rename),
}
