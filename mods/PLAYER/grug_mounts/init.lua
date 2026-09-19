-- Universal riding: persistent ownership, disposable runtime entities.

grug_mounts = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/catalog.lua")
dofile(modpath .. "/state.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/items.lua")
dofile(modpath .. "/trainer.lua")
