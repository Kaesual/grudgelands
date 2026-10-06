-- Character visuals (docs/design/character_visuals.md, contract
-- docs/research/wp13-character-visuals-contract.md).
--
-- One global table, nine files: `looks.lua` holds the body-feature layers a
-- look is drawn from (round31-plan.md §2.1), `compose.lua` is the pure
-- composition every humanoid on `character.b3d` goes through, `enchant.lua`
-- the enchant-colour layers of worn armour (§2.2),
-- `wield_geometry.lua` is the hand attachment derived from the mesh's own bone
-- tree (engine-free, so a fixture can read the same numbers),
-- `appearance.lua` the stored appearance for tools outside the game and its
-- closed texture grammar (pure), `apply.lua` is
-- the engine side (player hooks, the stored look, the attached wield entity,
-- the entity applier the mob mods call, the pose clips' ranges), `poses.lua`
-- when a player plays a pose clip (Round 40), `head_look.lua` the head that
-- follows the look pitch (Round 40) and `creation.lua` the look panel of the
-- character-creation window.
grug_visuals = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/looks.lua")
dofile(modpath .. "/compose.lua")
dofile(modpath .. "/enchant.lua")
dofile(modpath .. "/wield_geometry.lua")
dofile(modpath .. "/appearance.lua")
dofile(modpath .. "/apply.lua")
dofile(modpath .. "/poses.lua")
dofile(modpath .. "/head_look.lua")
dofile(modpath .. "/creation.lua")
