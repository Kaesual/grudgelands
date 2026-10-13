"""Step 0.47.0 (Round 47 lane OR, the pick level scale shifted by one): a
character marker for the online part, nothing else.

Round 47 gave every pick new tool capabilities (Iron behind the Bronze pick,
round47-plan.md rulings 6 and 7): Wood and Stone maxlevel 0, a metal pick of
tier t maxlevel t, new times and a `grug_pick_level` capability. A crafted
gathering tool keeps a copy of its definition's capabilities in its item
meta (`tool_capabilities`), a broken one the copy for the repair
(`_grug_repair_caps`); both hold the 0.46.0 scale. Rebuilding them needs the
new definitions, which only the game has, so the work is online: every
character, offline ones included, gets the marker `grug_core:migrate:0.47.0`
and the game's handler (grug_core/migrations.lua) rebuilds the copies at the
next join, in every list of the player's inventory. Nothing else is written.

Player inventories only: tools in node inventories (chests, stations) and
dropped ones are map-bound and go with the 0.47.0 map reset.
"""


def migrate(world):
    for name in world.characters():
        world.mark_character(name)
