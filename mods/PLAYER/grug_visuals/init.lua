-- Character visuals (docs/design/character_visuals.md, contract
-- docs/research/wp13-character-visuals-contract.md).
--
-- One global table, five files: `looks.lua` holds the body-feature layers a
-- look is drawn from (round31-plan.md §2.1), `compose.lua` is the pure
-- composition every humanoid on `character.b3d` goes through,
-- `wield_geometry.lua` is the hand attachment derived from the mesh's own bone
-- tree (engine-free, so a fixture can read the same numbers), `apply.lua` is
-- the engine side (player hooks, the stored look, the attached wield entity,
-- the entity applier the mob mods call) and `creation.lua` the look step of
-- character creation.
grug_visuals = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/looks.lua")
dofile(modpath .. "/compose.lua")
dofile(modpath .. "/wield_geometry.lua")
dofile(modpath .. "/apply.lua")
dofile(modpath .. "/creation.lua")
