"""Step 0.89.0 (Round 89 lane REWRITE, the arena halls' stairs and
balconies): a world marker for the online part, nothing else.

The two halls of the arena Breach Road (`grug_mapgen`, round89-plan.md
rulings 3 and 5) get their new templates without a map reset. A step never
reads the map (contract section 5.2), so the rewrite is online work: the
marker `migrate_world:0.89.0` makes the game's handler
(grug_core/migrations.lua) record the job at the next load, and
grug_mapgen/hall_rewrite.lua rewrites each hall template's box after the
load.
"""


def migrate(world):
    world.mark_world()
