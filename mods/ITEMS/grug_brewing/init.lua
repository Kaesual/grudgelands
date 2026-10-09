-- Low-level brewing station: Alchemy's proximity station (Round 45, spec
-- ruling 27; an alchemy job needs one nearby). Alchemy owns the recipes and
-- player authority; this mod stays below mapgen so capital blueprints may
-- name the node.

grug_brewing = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/node.lua")
