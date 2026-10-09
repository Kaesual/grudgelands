"""Step 0.45.0 (Round 45, the crafting rework): mixtures deleted, the engine
craft grid emptied, the old item level pinned on unmodified gear, and a
character marker for the online part (docs/planning/round45-plan.md section
4.7, ui-crafting-rework-plan.md section 6).

0.45.0 has no engine crafting (the `craft` list goes), alchemy makes finished
potions (the mixtures are inert and deleted here, ruling 2) and gear moves to
the item level ladder 1/11/21/... (its definitions changed: an unmodified
item would read the new level). For every character, offline ones included,
in this order:

1. every stack named `grug_alchemy:mixture_*` leaves every list;
2. the stacks of the `craft` list move, in craft slot order, into EMPTY slots
   of main[9..], then the equipped bags' content lists (bag slot order, only
   slots the bag holds), then the hotbar (main[1..8]) -- the give helper's
   order; only empty slots, since the tool cannot read stack_max. An empty
   `craft` is stored with size 0 (the engine re-creates it with 9 slots at
   every load and keeps a stored size, round45-plan.md section 4.2); what
   does not fit stays in `craft` for the online part (ruling 6);
3. every gear stack of the 0.44.0 game (GEAR below: weapons, shields,
   spellbooks, armour, trinkets) WITHOUT an item level of its own (meta
   `grug_ilvl` missing or not above 0, the game's MetaDataRef:get_int rule)
   gets the 0.44.0 definition's item level as `grug_ilvl` and, unless it has
   a positive `grug_req_level` already, its requirement as `grug_req_level`,
   in every list. Crafted, rolled, upgraded and crowned gear carries both
   already and is never touched;
4. the dead `craftpreview` stack is cleared and the player meta
   `grug_jobs:seen_items` (the retired recipe discovery) is deleted;
5. the character marker `grug_core:migrate:0.45.0` is set for every
   character; the game's handler (grug_core/migrations.lua) hands
   craft leftovers over, refreshes the tool capabilities of weapons whose
   damage no longer matches their item level (unmodified first-tier
   weapons) and rebuilds the gear tooltips at the next join.

A character's inventory is written only when something changed. Player
inventories only: gear and mixtures in node inventories on the map follow
the new definitions (accepted, spec section 6).

The tables are the 0.44.0 game's, frozen here (a pushed step never changes):
the gear names from grug_gear.MATERIALS, the weapon families, the armour lines
and slots and the trinket identities, each bracket's (_grug_ilvl,
_grug_req_level) from grug_gear.BRACKETS and bracket_required_level (the first
bracket required level 1); the bag sizes from grug_inventory/bags.lua.
tools/r45_ms/e2e.py checks GEAR, BAG_SLOTS and the mixture prefix against the
registrations of a running 0.44.0 game.
"""

import re

from migration.codec import ItemStack

HOTBAR = 8
CRAFT = "craft"
CRAFTPREVIEW = "craftpreview"
MAIN = "main"
BAG_COUNT = 4
MIXTURE_PREFIX = "grug_alchemy:mixture_"
SEEN_ITEMS = "grug_jobs:seen_items"
ILVL, REQ = "grug_ilvl", "grug_req_level"

# The bag items of grug_inventory/bags.lua and their `bagslots`.
BAG_SLOTS = {
    "grug_inventory:bag_small": 8,
    "grug_inventory:bag_medium": 16,
    "grug_inventory:bag_large": 24,
    "grug_inventory:bag_great": 32,
    "grug_inventory:bag_leather_pouch": 8,
    "grug_inventory:bag_leather_satchel": 16,
    "grug_inventory:bag_leather_pack": 24,
    "grug_inventory:bag_leather_rucksack": 32,
}

# 0.44.0's brackets: (_grug_ilvl, _grug_req_level) of every gear item.
BRACKETS = ((3, 1), (10, 10), (20, 20), (30, 30), (40, 40), (50, 50))
METALS = ("bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel")
CLOTH = ("patch", "woven", "heavy", "silkweave", "silk", "stormweave")
LEATHER = ("light", "cured", "heavy", "scaled", "sleek", "nightscale")
WEAPONS = ("sword", "dagger", "greataxe", "staff", "wand", "bow")
ARMOR_SLOTS = ("head", "chest", "legs", "feet")
TRINKETS = ("manawell", "last_light", "battlebeat", "apothecary_loop", "mercy_seal",
            "reclaimers_mark")


def _gear():
    table = {}
    for tier, values in enumerate(BRACKETS, 1):
        metal = METALS[tier - 1]
        names = ["grug_gear:%s_%s" % (family, metal) for family in WEAPONS]
        names += ["grug_gear:shield_" + metal, "grug_gear:spellbook_" + metal]
        for line, grade in (("metal", metal), ("leather", LEATHER[tier - 1]),
                            ("cloth", CLOTH[tier - 1])):
            names += ["grug_gear:%s_%s_%s" % (slot, line, grade) for slot in ARMOR_SLOTS]
        names += ["grug_gear:%s_t%d" % (key, tier) for key in TRINKETS]
        for name in names:
            table[name] = values
    return table


GEAR = _gear()
_ATOI = re.compile(r"[ \t\n\v\f\r]*([+-]?[0-9]+)")


def meta_int(stack, key):
    """MetaDataRef:get_int: C atoi of the stored string, 0 when absent."""
    match = _ATOI.match(stack.meta.get(key, ""))
    return int(match.group(1)) if match else 0


def empty():
    return ItemStack("", 0)


def delete_mixtures(lists):
    count = 0
    for inv in lists.values():
        for slot, stack in enumerate(inv.items):
            if not stack.is_empty() and stack.name.startswith(MIXTURE_PREFIX):
                inv.items[slot] = empty()
                count += 1
    return count


def free_slots(lists):
    """The empty slots a craft stack may take, as (list, stored slot), in the
    give helper's order: main[9..], each equipped bag, the hotbar."""
    out = []
    main = lists.get(MAIN)
    if main is not None:
        out += [(MAIN, slot) for slot in range(HOTBAR, main.size)]
    for i in range(1, BAG_COUNT + 1):
        content_name = "grug_bag%d_content" % i
        bag, content = lists.get("grug_bag%d" % i), lists.get(content_name)
        if bag is None or content is None or bag.size < 1:
            continue
        # The join sizes the list by the bag (bags.lua): never past it.
        capacity = min(content.size, BAG_SLOTS.get(bag.items[0].name, 0))
        out += [(content_name, slot) for slot in range(capacity)]
    if main is not None:
        out += [(MAIN, slot) for slot in range(min(HOTBAR, main.size))]
    return [(name, slot) for name, slot in out if lists[name].items[slot].is_empty()]


def empty_craft(lists):
    """Moves the craft stacks into free slots; returns (moved, left)."""
    craft = lists.get(CRAFT)
    if craft is None:
        return 0, 0
    targets = free_slots(lists)
    moved = 0
    for slot, stack in enumerate(craft.items):
        if stack.is_empty() or not targets:
            continue
        name, target = targets.pop(0)
        lists[name].items[target] = stack
        craft.items[slot] = empty()
        moved += 1
    left = sum(1 for stack in craft.items if not stack.is_empty())
    return moved, left


def pin(stack):
    """Pins the 0.44.0 item level on an unmodified gear stack; True when
    it wrote."""
    values = GEAR.get(stack.name)
    if values is None or stack.is_empty() or meta_int(stack, ILVL) > 0:
        return False
    stack.meta[ILVL] = str(values[0])
    if meta_int(stack, REQ) <= 0:
        stack.meta[REQ] = str(values[1])
    return True


def migrate(world):
    for name in world.characters():
        lists = world.get_inventory(name)
        changed = delete_mixtures(lists) > 0
        moved, left = empty_craft(lists)
        changed = changed or moved > 0
        craft = lists.get(CRAFT)
        if craft is not None and left == 0 and craft.size > 0:
            craft.items = []
            changed = True
        preview = lists.get(CRAFTPREVIEW)
        if preview is not None:
            for slot, stack in enumerate(preview.items):
                if not stack.is_empty():
                    preview.items[slot] = empty()
                    changed = True
        for inv in lists.values():
            for stack in inv.items:
                changed = pin(stack) or changed
        if changed:
            world.set_inventory(name, lists)
        if world.get_meta(name).get(SEEN_ITEMS, "") != "":
            world.set_meta(name, SEEN_ITEMS, "")
        world.mark_character(name)
