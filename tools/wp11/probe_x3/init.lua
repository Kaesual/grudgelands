-- Isolated native-engine behavior probe. Only engine-facing player/object,
-- clock and ray adapters are synthetic: talent parsing, cast/swing dispatch,
-- projectile callbacks, damage settlement, statuses, movement and repair are
-- the production modules loaded by the game. No user world/player is touched.
local path = core.get_modpath(core.get_current_modname())
-- The bounded combat probe never generates the six startup mapgen areas.
grug_core.request_starts_preload = function() end
core.register_on_mods_loaded(function()
	core.after(0, function() dofile(path .. "/scenarios.lua") end)
end)
