-- Player-owned functional displays. Node metadata is the sole durable owner;
-- the render entities are unsaved projections recreated on mapblock load.
grug_displays = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/entities.lua")
dofile(modpath .. "/nodes.lua")
