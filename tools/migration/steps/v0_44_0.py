"""Step 0.44.0 (Round 44, the UI rework): mount items and bound skills
outside the hotbar leave every character's inventory, offline only.

0.44.0 keeps skills on the hotbar only (main slots 1..8) and opens mounts
and boats from the quickbar, which reads the purchase record; mount items
are no longer handed out. Worlds of 0.43.0 still carry both, so for every
character, offline ones included:

- every mount item is removed from every list;
- every skill is removed from every list except main slots 1..8 (stored
  slots 0..7); a skill on the hotbar stays as it is, its refresh is the
  game's join (grug_abilities normalize_kit).

Nothing else changes: the purchased mounts stay recorded in player meta
(grug_mounts:land_tier, flight_tier, water_tier), every other stack keeps
its slot, count, wear and meta, and a removed skill waits in the Talents &
Skills catalog. A character's inventory is written only when something was
removed. No online work, no map part: 0.43.0 never lets a mount item or a
skill into a node or detached inventory (grug_skills/bound_items.lua guards
both) and deletes one that is dropped (their on_drop).

The names are the 0.43.0 game's, frozen here (a pushed step never changes):
a skill is any item of the mod grug_abilities (0.43.0 registers items there
only through grug_abilities.register_ability, as grug_abilities:<id> in the
groups grug_ability and grug_bound_skill), a mount item one of the six
grug_mounts tier items (grug_mounts/catalog.lua TIERS[].item, the group
grug_mount). tools/r44_ms/e2e.py checks both against the registrations of a
running 0.43.0 game.
"""

from migration.codec import ItemStack

HOTBAR = 8
SKILL_PREFIX = "grug_abilities:"
MOUNT_ITEMS = frozenset((
    "grug_mounts:apprentice_mount",
    "grug_mounts:journeyman_mount",
    "grug_mounts:expert_mount",
    "grug_mounts:master_mount",
    "grug_mounts:boat",
    "grug_mounts:improved_boat",
))


def removed(list_name, slot, name):
    """Whether the stack `name` in stored slot `slot` (0-based) of the list
    `list_name` goes."""
    if name in MOUNT_ITEMS:
        return True
    if name.startswith(SKILL_PREFIX):
        return not (list_name == "main" and slot < HOTBAR)
    return False


def migrate(world):
    for name in world.characters():
        lists = world.get_inventory(name)
        changed = False
        for list_name, inv in lists.items():
            for slot, stack in enumerate(inv.items):
                if not stack.is_empty() and removed(list_name, slot, stack.name):
                    inv.items[slot] = ItemStack("", 0)
                    changed = True
        if changed:
            world.set_inventory(name, lists)
