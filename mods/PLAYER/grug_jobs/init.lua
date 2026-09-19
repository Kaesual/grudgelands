-- Profession framework: registrations, persistent player progression, recipe
-- books, station gates and settlement trainers.

grug_jobs = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/registry.lua")
dofile(modpath .. "/state.lua")
dofile(modpath .. "/ui.lua")
dofile(modpath .. "/stations.lua")
local station_factory = dofile(modpath .. "/station_nodes.lua")
station_factory.install_jobs(grug_jobs)
dofile(modpath .. "/trainers.lua")
