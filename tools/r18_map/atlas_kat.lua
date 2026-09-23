local repo = assert(arg[1], "repository root required")
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local source = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

local world = atlas.view("world")
assert(world.min_x == source.extent.min_x and world.max_x == source.extent.max_x)
assert(world.min_z == source.extent.min_z and world.max_z == source.extent.max_z)

local ids = {"dwarf", "human", "elf", "undead", "orc", "troll"}
local function regional_coverage(x, z)
	local count = 0
	for index = 1, #ids do
		if atlas.contains(atlas.view(ids[index]), {x = x, z = z}) then
			count = count + 1
		end
	end
	return count
end

-- Every cell and every world-border case belongs to the six-view union.
for x = world.min_x, world.max_x, 60 do
	for z = world.min_z, world.max_z, 80 do
		assert(regional_coverage(x, z) >= 1,
			("regional coverage hole at %d,%d"):format(x, z))
	end
end
local border_points = {
	{world.min_x, world.min_z}, {world.min_x, world.max_z},
	{world.max_x, world.min_z}, {world.max_x, world.max_z},
	{world.min_x, 0}, {world.max_x, 0}, {0, world.min_z}, {0, world.max_z},
}
for index = 1, #border_points do
	assert(regional_coverage(border_points[index][1], border_points[index][2]) >= 1)
end

-- Internal seams overlap; the middle/front is present in both rows.
assert(regional_coverage(-1200, -2000) == 2)
assert(regional_coverage(0, 0) == 2)
assert(regional_coverage(1200, 2000) == 2)

-- Whole 512 x 512 capital envelopes fit their intended regional view.
local capital_view = {
	capital_dwarf = "dwarf", capital_human = "human", capital_elf = "elf",
	capital_undead = "undead", capital_orc = "orc", capital_troll = "troll",
}
local capitals = 0
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	local id = capital_view[anchor.template_id]
	if id then
		capitals = capitals + 1
		local view = atlas.view(id)
		for _, dx in ipairs({-256, 256}) do
			for _, dz in ipairs({-256, 256}) do
				assert(atlas.contains(view, {x = anchor.position.x + dx,
					z = anchor.position.z + dz}))
			end
		end
	end
end
assert(capitals == 6)

-- Projection preserves click identity at corners and uses the exact view bounds.
for index = 1, #ids do
	local view = atlas.view(ids[index])
	local x, y = atlas.world_to_screen(view,
		{x = view.min_x, z = view.max_z}, 2, 3, 7, 11)
	assert(x == 2 and y == 3)
	x, y = atlas.world_to_screen(view,
		{x = view.max_x, z = view.min_z}, 2, 3, 7, 11)
	assert(x == 9 and y == 14)
	local marker_id = "fixture:" .. ids[index]
	assert(atlas.field_id(marker_id) == atlas.field_id(marker_id))
end

print("r18_map_atlas_kat_v1\tcoverage=ok\toverlap=ok\tcapitals=6\tprojection=ok")
