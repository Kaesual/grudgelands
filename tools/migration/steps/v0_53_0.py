"""Step 0.53.0 (Round 53, the new classes): the talents reset with a full
refund, the stored talent windows cleared, the retired skills removed, and a
character marker for the one chat line (docs/planning/round53-plan.md
section 4 INTEG, rulings K10 and K11, section 8 Q3 and Q4).

0.53.0 replaces the talent engine: the meta key `grug_classes:talents` keeps
its name but holds the talent graph's `<tree>_<name>` ids, and every talent
id of 0.52.1 is gone or means something else. Three skills are retired.
For every character, offline ones included:

1. the player meta `grug_classes:talents` (the spent ranks; points are
   counted from the level, so deleting it refunds every point),
   `grug_classes:respec_used` (the next respec is free again, Q3), every
   `grug_classes:talent_ready:<id>` (the old talent windows' cooldowns),
   `grug_classes:unbroken_ready` and `grug_classes:untouchable_ready` are
   deleted;
2. every stack of the retired skills `grug_abilities:cinderfall`,
   `grug_abilities:glacial_ward` and `grug_abilities:pinning_shot` leaves
   every list: the shown hotbar (`main`), the other layout
   (`grug_hotbar_store`), a stray copy in `main[9..]` or a bag. A skill is a
   bound item (grug_skills/bound_items.lua): no node or detached inventory
   and no letter takes it, and a dropped one is deleted, so the player's
   lists are the only place it can be. Every other stack keeps its slot,
   count, wear and meta;
3. the character marker `grug_core:migrate:0.53.0`; the game's handler
   (grug_core/migrations.lua) sends one chat line at the next join to a
   character with a class, "Your talent points have been reset.".

Nothing else: the skills the new kits lock or swap are registered, and the
game's join (grug_abilities normalize_kit) takes them off or swaps them in
place. The Priest's Smite is not moved into Strike's slot (Q4). A
character's inventory is written only when a retired skill was removed, and
a meta key only when it was set.

The names are the 0.52.1 game's, frozen here (a pushed step never changes):
the meta keys of grug_classes (talents.lua, talents_ui.lua,
talent_windows.lua, scout.lua) and the three item names
(grug_abilities.register_ability). tools/r53_ms/e2e.py builds a 0.52.1
world with each of them.
"""

from migration.codec import ItemStack

TALENT_KEYS = (
    "grug_classes:talents",
    "grug_classes:respec_used",
    "grug_classes:unbroken_ready",
    "grug_classes:untouchable_ready",
)
WINDOW_PREFIX = "grug_classes:talent_ready:"
RETIRED = frozenset((
    "grug_abilities:cinderfall",
    "grug_abilities:glacial_ward",
    "grug_abilities:pinning_shot",
))


def cleared_keys(meta):
    """The player meta keys the step deletes, of those `meta` holds."""
    return sorted(key for key, value in meta.items() if value != "" and (
        key in TALENT_KEYS or key.startswith(WINDOW_PREFIX)))


def remove_retired(lists):
    """Empties every retired skill's stack in every list; returns how many
    went."""
    count = 0
    for inv in lists.values():
        for slot, stack in enumerate(inv.items):
            if not stack.is_empty() and stack.name in RETIRED:
                inv.items[slot] = ItemStack("", 0)
                count += 1
    return count


def migrate(world):
    for name in world.characters():
        for key in cleared_keys(world.get_meta(name)):
            world.set_meta(name, key, "")
        lists = world.get_inventory(name)
        if remove_retired(lists) > 0:
            world.set_inventory(name, lists)
        world.mark_character(name)
