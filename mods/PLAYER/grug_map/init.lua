grug_map = {}

local modpath = core.get_modpath(core.get_current_modname())
grug_map.atlas = dofile(modpath .. "/atlas.lua")
dofile(modpath .. "/minimap.lua")
dofile(modpath .. "/providers.lua")
dofile(modpath .. "/page.lua")
