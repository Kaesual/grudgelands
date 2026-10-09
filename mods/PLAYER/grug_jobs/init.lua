-- Profession framework: the recipe registry, persistent player progression,
-- crafting jobs, station nodes and settlement trainers.

grug_jobs = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/registry.lua")
grug_jobs.register_basic_catalog(dofile(modpath .. "/basic_recipes.lua"))
dofile(modpath .. "/state.lua")
dofile(modpath .. "/jobs.lua")
dofile(modpath .. "/overview.lua")
dofile(modpath .. "/ui.lua")
dofile(modpath .. "/craft_box.lua")
dofile(modpath .. "/operation_jobs.lua")
dofile(modpath .. "/operation_box.lua")
dofile(modpath .. "/station_sounds.lua")
dofile(modpath .. "/craft_list.lua")
local station_factory = dofile(modpath .. "/station_nodes.lua")
station_factory.install_jobs(grug_jobs)
dofile(modpath .. "/trainers.lua")
