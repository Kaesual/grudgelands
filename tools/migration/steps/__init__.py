"""Migration steps, one file per declared `migrate` version:
`v<major>_<minor>_<patch>.py` migrates a world of the previous version to
that version (contract R2). A step module exports

    def migrate(world):  # world: migration.data.World
        ...

and nothing else is required. It runs inside one write transaction per
backend; the tool records the step's version afterwards. Online work is left
with `world.mark_world()` (the game's next load) and
`world.mark_character(name)` (that character's next join). A pushed step is
never changed; a fix is a later step. The baseline rule: a step relies only
on what the previous step or map reset left plus what the versions between
write without a load, never on an earlier step's online work being done.
"""
