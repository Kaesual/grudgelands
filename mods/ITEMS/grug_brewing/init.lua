-- Low-level brewing station. Alchemy owns the recipes and player authority;
-- this mod stays below mapgen so capital blueprints may name the node.

grug_brewing = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/node.lua")

