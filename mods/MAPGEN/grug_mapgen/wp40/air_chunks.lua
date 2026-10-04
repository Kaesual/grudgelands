-- Round 23 (WP48) air-chunk fast path, emerge environment.
--
-- A generated chunk is left exactly as native v7 made it when both hold:
--
-- 1. Native v7 placed nothing but air in the owner chunk. The engine
--    heightmap of the chunk (Mapgen::updateHeightmap, filled right after v7's
--    terrain pass) has no walkable node inside [minp.y, maxp.y] in any
--    column, and the chunk lies above water_level. Above water level v7's
--    terrain pass writes only stone (walkable) or air; floatlands are off
--    (mgv7_spflags); caves, caverns and dungeons return early above the
--    highest stone (MapgenBasic::generateCaves*/generateDungeons) and only
--    carve; the native ores replace stone; the game registers no Lua biomes
--    or decorations (default/mapgen.lua GRUG PATCH). So the owner holds only
--    air.
-- 2. The chunk lies more than MARGIN nodes above everything the writer can
--    place there: the preparation surface/content envelope
--    (preparation_source.lua) of the owner columns and their decoded content
--    reach (terrain, water, functional surfaces, waterfalls, road decks and
--    rails and the tallest decoded template) and the fitted
--    settlement, POI and anchor boxes over the owner.
--
-- Under both, the writer's final owner content equals its native input: the
-- planner clears above the surface cap to air, which the owner already is,
-- and no successor writes that high. The R6 transaction then returns
-- "noop_equal_content" before any VoxelManip setter, light or liquid call
-- (r6_settlement.lua), so skipping it yields the same content, param2 and
-- light for the chunk and its shell. Round 23 measured this equality on real
-- chunks (docs/research/round23-full-column-preparation.md).
--
-- Underground chunks have no such fast path: natural resources sample every
-- depth of land (world_zones.md §11), cave plants grow in native caves at
-- -500..-100 and below -701, and strata reach 40 nodes down.
return function(bounds_source, water_level)
	assert(type(bounds_source) == "table" and
		type(bounds_source.tile_bounds) == "function" and
		type(bounds_source.column_bounds) == "function",
		"air chunks need the writer's surface envelope")
	assert(type(water_level) == "number", "air chunks need the water level")
	local MARGIN = 16 -- one mapblock between the envelope and the chunk
	local MEMO = 64 -- recent owner columns (a chunk column is generated together)
	local memo, keys, slot = {}, {}, 0
	local function writer_top(minp, maxp)
		local key = minp.x .. ":" .. minp.z .. ":" .. maxp.x .. ":" .. maxp.z
		local top = memo[key]
		if top then return top end
		local radius, _, box_top = bounds_source.tile_bounds(minp, maxp)
		assert(type(radius) == "number" and radius >= 1 and radius % 1 == 0,
			"air chunk content reach differs")
		top = box_top
		for z = minp.z - radius, maxp.z + radius do
			for x = minp.x - radius, maxp.x + radius do
				local _, high = bounds_source.column_bounds(x, z)
				if high > top then top = high end
			end
		end
		slot = slot % MEMO + 1
		if keys[slot] then memo[keys[slot]] = nil end
		keys[slot], memo[key] = key, top
		return top
	end
	local M = {}
	-- get_heightmap() returns the engine heightmap of the current chunk.
	function M.untouched(minp, maxp, get_heightmap)
		if minp.y <= water_level then return false end
		local heightmap = get_heightmap()
		local columns = (maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)
		if type(heightmap) ~= "table" or #heightmap ~= columns then return false end
		local low = minp.y
		for index = 1, columns do
			if heightmap[index] >= low then return false end
		end
		return low > writer_top(minp, maxp) + MARGIN
	end
	return M
end
