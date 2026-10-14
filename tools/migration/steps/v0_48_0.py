"""Step 0.48.0 (Round 48 lane BAGS, the bags at half size): a character
marker for the online part, nothing else.

Round 48 halved every bag (sell-fuel-daytime-plan.md rulings 7-8, section
3.7): 4 / 8 / 12 / 16 slots instead of 8 / 16 / 24 / 32. The game's join
callback sizes each bag's content list from its bag, and the engine's
set_size truncates, so a full bag would lose its second half. The new
layout needs the game's sort order and stack sizes, and the leftovers go
into letters through the game's mail, so the work is online: every
character, offline ones included, gets the marker `grug_core:migrate:0.48.0`
and the game's handler (grug_core/migrations.lua) sorts main[9..] and the
bags into the new sizes at the next join, before every other join callback,
and mails what no longer fits ("Lost and Found", four stacks per letter).
Nothing else is written.
"""


def migrate(world):
    for name in world.characters():
        world.mark_character(name)
