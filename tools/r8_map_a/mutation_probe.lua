-- Runs one R8-MAP-A KAT boundary against a temporary mutated source tree.

local root, rule = assert(arg[1]), assert(arg[2])
if rule == "run_stability" then
	local _, coast_factory = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/height.lua")
	local coast = coast_factory("0")
	assert(coast.run_key(2, 1, -44, "sea_ordinary") ==
		"2/1/-44/sea_ordinary", "run identity lost its stable class")
	return
end
dofile(root .. "/tools/r8_map_a/writer_kat.lua")(root)
