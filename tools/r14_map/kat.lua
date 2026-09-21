local repo = assert(arg[1], "repository root required")
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local source = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

local world = atlas.view("world")
assert(world.min_x == source.extent.min_x and world.max_x == source.extent.max_x and
	world.min_z == source.extent.min_z and world.max_z == source.extent.max_z)
local x, y = assert(atlas.world_to_screen(world, {x = -3600, z = 3200},
	10, 20, 720, 640))
assert(x == 10 and y == 20)
x, y = assert(atlas.world_to_screen(world, {x = 3600, z = -3200},
	10, 20, 720, 640))
assert(x == 730 and y == 660)
assert(atlas.world_to_screen(world, {x = 3601, z = 0}, 0, 0, 1, 1) == nil)

atlas.register_marker_provider("kat_a", function(player)
	assert(player == "player-token")
	return {{id = "b", label = "B", position = {x = 2, z = 3}}}
end)
atlas.register_marker_provider("kat_b", function()
	return {{id = "a", label = "A", detail = "detail", kind = "quest",
		position = {x = -2, y = 4, z = -3}}}
end)
local markers = atlas.collect_markers("player-token")
assert(#markers == 2 and markers[1].id == "kat_a:b" and
	markers[2].id == "kat_b:a" and markers[2].detail == "detail" and
	markers[2].position.y == 4)
local views = atlas.views()
assert(#views == 7 and views[1].id == "world" and views[7].id == "troll")
assert(atlas.contains(atlas.view("human"), {x = 0, z = -2000}))
assert(not atlas.contains(atlas.view("human"), {x = 1800, z = -2000}))
print("r14_map_kat_v1\tsource=ok\tviews=7\tmarkers=2\ttransform=ok")
