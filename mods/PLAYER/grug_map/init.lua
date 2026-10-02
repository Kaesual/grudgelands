grug_map = {}

local modpath = core.get_modpath(core.get_current_modname())
grug_map.atlas = dofile(modpath .. "/atlas.lua")
grug_map.base = dofile(modpath .. "/base.lua")
local installed = grug_map.base.install(grug_map.atlas.view())
grug_map.atlas.set_base_texture(installed.texture)
-- A rendered base leaves its garbage; collected now, it does not add to the
-- region build's peak memory (Round 30 P3).
collectgarbage("collect")
dofile(modpath .. "/minimap.lua")
grug_map.minimap.install(installed)
dofile(modpath .. "/providers.lua")
dofile(modpath .. "/page.lua")
-- After page.lua (its layout places the zone markers) and providers.lua.
dofile(modpath .. "/location.lua")
