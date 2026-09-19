-- Profession framework: registrations, persistent player progression, recipe
-- books, station gates and settlement trainers.

grug_jobs = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/registry.lua")
dofile(modpath .. "/state.lua")
dofile(modpath .. "/discovery.lua")
dofile(modpath .. "/ui.lua")
dofile(modpath .. "/stations.lua")
dofile(modpath .. "/trainers.lua")
