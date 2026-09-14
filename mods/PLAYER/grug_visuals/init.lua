-- Character visuals (docs/design/character_visuals.md, contract
-- docs/research/wp13-character-visuals-contract.md).
--
-- One global table, two files: `compose.lua` is the pure composition every
-- humanoid on `character.b3d` goes through, `apply.lua` is the engine side
-- (player hooks, the attached wield entity, the entity applier the mob mods
-- call).
grug_visuals = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/compose.lua")
dofile(modpath .. "/apply.lua")
