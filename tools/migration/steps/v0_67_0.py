"""Step 0.67.0 (Round 67, the playtest's crafting notes): the metal rods
leave the game; every rod a world still holds is refunded as bars of its
metal, two rods for one bar, rounded up (docs/planning/round67-plan.md
ruling 13 and the coordinator default "Metal rods in saved state"),
offline only.

0.67.0 no longer registers the six `grug_professions:metal_rod_<metal>`
items (their recipes and the rod variants of sword, dagger and greataxe
went with them). A stack of N rods becomes ceil(N / 2) bars of the same
metal (`grug_materials:<metal>_bar`), in place: same slot or position,
the rod stack's wear and meta dropped (rods are plain craft items). It
covers every store the upgrade contract lists for a removed item
(docs/technical/upgrade-contract.md section 1 and section 3.5), offline
characters included:

1. every list of every character's inventory (`main`, the hotbars, the
   bags' content lists, the crafting overflow `grug_craft_out`, the mail
   attachment list `grug_mail_out` and every other list);
2. the `consumed` stacks of the running craft job (player meta
   `grug_jobs:job`, one core.serialize'd table) and of every waiting one
   (`grug_jobs:queue`, a core.serialize'd list): a job that took rods
   gives bars back when it ends (a job whose recipe is gone returns its
   consumed stacks; grug_jobs/jobs.lua);
3. `grug_housing`'s mod storage: every `recovered:*` entry (one item
   string; a packed container the game has not cleaned yet carries its
   contents in its item meta `lists`, a core.serialize'd table of list
   name -> item strings by slot) and every `packed:*` content key (the
   same table, which the clean-up moved out of the item);
4. `grug_mail`'s mod storage: the item strings of every letter's
   attachments in every `box:<name>` (`letters[].items`). Sent copies,
   tickets and reports hold display names only and are not touched.

Rods in node inventories on the map stay unknown items: a step never
reads the map (contract section 5.2), and the map is not reset. A cleaned
packed container's tooltip text, written once by the game from its
contents, keeps naming the rods its stored contents no longer hold (text
only). Every other stack, key and value stays as it is, and a value is
written only when a rod was in it. No online work, no marker.

The names are the 0.66.1 game's, frozen here (a pushed step never
changes): grug_professions/base_recipes.lua registered the rods as
`grug_professions:metal_rod_<metal>` for the six metals below, each bar
`grug_materials:<metal>_bar` (grug_professions/base_recipes.lua `tiers`);
the job keys of grug_jobs/jobs.lua, the storage keys of
grug_housing/recovered.lua and packed.lua and of grug_mail/store.lua.
tools/r67_craft/e2e.py builds a 0.66.1 world with rods in each store.
"""

import math

from migration import codec
from migration.codec import ItemStack

METALS = ("bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel")
BAR_OF = {"grug_professions:metal_rod_%s" % metal: "grug_materials:%s_bar" % metal
          for metal in METALS}
JOB_KEY = "grug_jobs:job"
QUEUE_KEY = "grug_jobs:queue"
PACKED_ITEM = "grug_housing:packed_container"


def refund(stack):
    """The bars a rod stack becomes, or None for any other stack."""
    bar = BAR_OF.get(stack.name)
    if bar is None or stack.is_empty():
        return None
    return ItemStack(bar, math.ceil(stack.count / 2))


def refund_string(text):
    """An item string with a rod stack refunded, or None when unchanged
    (another item, an empty or unreadable string)."""
    if not isinstance(text, str) or text.split(" ", 1)[0].strip('"') not in BAR_OF:
        return None
    try:
        bars = refund(ItemStack.parse(text))
    except (codec.CodecError, ValueError):
        return None
    return bars.to_string() if bars is not None else None


def refund_inventory(lists):
    """Refunds every rod stack of an inventory in place; returns how many."""
    count = 0
    for inv in lists.values():
        for slot, stack in enumerate(inv.items):
            bars = refund(stack)
            if bars is not None:
                inv.items[slot] = bars
                count += 1
    return count


def refund_sequence(values):
    """Refunds the rod item strings of a list or a {slot: string} table in
    place; returns how many."""
    count = 0
    keys = range(len(values)) if isinstance(values, list) else list(values)
    for key in keys:
        new = refund_string(values[key])
        if new is not None:
            values[key] = new
            count += 1
    return count


def refund_lists(lists):
    """A packed container's lists ({list name: item strings by slot}),
    refunded in place; returns how many."""
    count = 0
    if isinstance(lists, dict):
        for values in lists.values():
            if isinstance(values, (list, dict)):
                count += refund_sequence(values)
    return count


def refund_serialized(text, walk):
    """A core.serialize'd value with `walk(value) -> count` applied: the new
    text, or None when nothing changed or it does not decode."""
    if not text:
        return None
    try:
        value = codec.deserialize(text)
    except codec.CodecError:
        return None
    if walk(value) == 0:
        return None
    return codec.serialize(value)


def refund_jobs(value):
    """A job record or a list of them: the rods in `consumed`."""
    records = value if isinstance(value, list) else [value]
    count = 0
    for record in records:
        if isinstance(record, dict) and isinstance(record.get("consumed"), (list, dict)):
            count += refund_sequence(record["consumed"])
    return count


def refund_box(box):
    """A mailbox: the rods in every letter's attachments."""
    count = 0
    letters = box.get("letters") if isinstance(box, dict) else None
    for letter in letters if isinstance(letters, (list, dict)) else []:
        if isinstance(letters, dict):
            letter = letters[letter]
        if isinstance(letter, dict) and isinstance(letter.get("items"), (list, dict)):
            count += refund_sequence(letter["items"])
    return count


def refund_entry(text):
    """A `recovered:*` entry: a rod stack, or a packed container whose
    uncleaned `lists` hold rods. The new item string, or None."""
    new = refund_string(text)
    if new is not None:
        return new
    if not isinstance(text, str) or not text.startswith(PACKED_ITEM):
        return None
    try:
        stack = ItemStack.parse(text)
    except (codec.CodecError, ValueError):
        return None
    lists = refund_serialized(stack.meta.get("lists", ""), refund_lists)
    if lists is None:
        return None
    stack.meta["lists"] = lists
    return stack.to_string()


def migrate(world):
    for name in world.characters():
        lists = world.get_inventory(name)
        if refund_inventory(lists) > 0:
            world.set_inventory(name, lists)
        meta = world.get_meta(name)
        for key in (JOB_KEY, QUEUE_KEY):
            new = refund_serialized(meta.get(key, ""), refund_jobs)
            if new is not None:
                world.set_meta(name, key, new)
    housing = world.storage("grug_housing")
    for key, value in sorted(housing.items().items()):
        if key.startswith("recovered:"):
            new = refund_entry(value)
        elif key.startswith("packed:"):
            new = refund_serialized(value, refund_lists)
        else:
            new = None
        if new is not None:
            housing.set(key, new)
    mail = world.storage("grug_mail")
    for key, value in sorted(mail.items().items()):
        if key.startswith("box:"):
            new = refund_serialized(value, refund_box)
            if new is not None:
                mail.set(key, new)
