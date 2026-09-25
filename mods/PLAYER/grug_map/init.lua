grug_map = {}

local modpath = core.get_modpath(core.get_current_modname())
grug_map.atlas = dofile(modpath .. "/atlas.lua")
grug_map.atlas.set_base_texture(
	dofile(modpath .. "/base.lua").install(grug_map.atlas.view()))
dofile(modpath .. "/minimap.lua")
dofile(modpath .. "/providers.lua")
dofile(modpath .. "/page.lua")
