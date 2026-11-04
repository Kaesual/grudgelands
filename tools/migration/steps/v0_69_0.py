"""Step 0.69.0 (Round 69 lane CAMP, the camps under construction): a world
marker for the online part, nothing else.

The six camps under construction (`grug_mapgen`, kind `camp_construction`)
get their new composition without a map reset (round69-plan.md rulings 4 and
5). A step never reads the map (contract section 5.2), so the rewrite is
online work: the marker `migrate_world:0.69.0` makes the game's handler
(grug_core/migrations.lua) record the job at the next load, and
grug_mapgen/camp_rewrite.lua rewrites each camp's box after the load.
"""


def migrate(world):
    world.mark_world()
