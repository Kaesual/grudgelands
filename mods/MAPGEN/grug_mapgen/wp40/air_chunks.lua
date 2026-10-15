-- Untouched chunks, emerge environment: the two cases in which the R7
-- writer's transaction provably changes nothing in a generated chunk, so
-- r7_mapgen.lua does not run it and the chunk keeps exactly what native v7
-- made. Both tests read only the writer's own envelope (preparation_source.lua:
-- the surface/content height of a column, the fitted settlement, POI and
-- anchor boxes) and, for air, the engine heightmap; neither plans.
--
-- Under either, the writer's final owner content equals its native input and
-- the R6 transaction returns "noop_equal_content" before any VoxelManip
-- setter, light or liquid call (r6_settlement.lua; it compares the owner
-- only, and every writer refuses a write outside the owner), so skipping it
-- yields the same content, param2 and light for the chunk and its shell.
--
-- AIR ABOVE (Round 23, WP48; `untouched`). Both hold:
--
-- 1. Native v7 placed nothing but air in the owner chunk. The engine
--    heightmap of the chunk (Mapgen::updateHeightmap, filled right after v7's
--    terrain pass) has no walkable node inside [minp.y, maxp.y] in any
--    column, and the chunk lies above water_level. Above water level v7's
--    terrain pass writes only stone (walkable) or air; floatlands are off
--    (mgv7_spflags); caves, caverns and dungeons return early above the
--    highest stone (MapgenBasic::generateCaves*/generateDungeons) and only
--    carve; the native ores replace stone; the game registers no Lua biomes
--    (default/mapgen.lua GRUG PATCH) and its only decorations, the native
--    cave plants (Round 49), lie far below water level. So the owner holds
--    only air. The heightmap is the one exact proof of that: v7's own
--    terrain can rise above our surface where our land lies lower (since
--    Round 49 `nomountains` only its 2-D base height, still a separate noise
--    from ours), which the writer would clear, so no envelope of ours can
--    replace it.
-- 2. The chunk lies more than MARGIN nodes above everything the writer can
--    place there: the preparation surface/content envelope of the owner
--    columns and their decoded content reach (terrain, water, functional
--    surfaces, waterfalls, road decks and rails and the tallest decoded
--    template) and the fitted settlement, POI and anchor boxes over the owner.
--    The boxes and the owner's own columns are read first (Round 49): one of
--    them reaching the chunk decides without the reach ring, whose columns
--    are mostly not the planner's and cost the most to answer.
--
-- The planner clears above the surface cap to air, which the owner already
-- is, and no successor writes that high. Round 23 measured this equality on
-- real chunks (docs/research/round23-full-column-preparation.md).
--
-- ROCK BELOW (Round 49, lane SKIP; `below`). The owner lies more than MARGIN
-- nodes below everything the writer can place in it, whatever v7 made there:
--
-- * The authored floor, y AUTHORED_FLOOR = -37 (pinned by the R5 manifest,
--   mapgen_manifest.lua, and checked by planner.lua): the R5 planner refuses
--   a run that begins below it and a column whose ground lies below it, so
--   the R5 runs (terrain fill, foundation and grading fill, seals, water,
--   clears) start at -37 at the lowest. The passes after R5 keep to it too:
--   the P7 fillers and the R9 skin write only on R5 runs or from
--   max(-37, ground - 3), the R8 strata and the R24 layers clip at
--   floor_y = -37, the P8 fill ores visit only R5 fill runs, and the R8 cave
--   mouth (off by default) carves only a lumen whose lowest point is at or
--   above -37 (zones.lua).
-- * The surface writers build up from a column's ground, water or road
--   height, and every such ground lies at or above -37 (the planner's column
--   rule): P9 decorations root on ground at y >= 1 and lie wholly in their
--   owner; P9G gathering sources and world content stand on the ground or
--   the water; roads write their deck, pillars and walls from the road or
--   ground level up; swamp pools reach at most two nodes below the lowest
--   ground round them; the dragon arenas dress their floor. MARGIN covers
--   those few nodes.
-- * The exact owned volumes -- settlement and POI blueprints, capital plots
--   with their collars and approaches, capital city edges, anchor roots --
--   write only inside their fitted boxes, the same boxes as test 2 above
--   (`tile_bounds`' bottom over the owner).
--
-- Nothing else writes underground since Round 49: ores, gems and cave
-- plants are native v7 rows (r7_native.lua), and an underground reservation
-- (Round 46) is a claim exclusion only (no shipped anchor declares one).
-- With the chunk grid at -32 + 80k every chunk from y -113 down is skipped
-- unless a box reaches within MARGIN of its top; the chunk -112..-33 holds
-- the fill floor and always runs.
return function(bounds_source, water_level)
	assert(type(bounds_source) == "table" and
		type(bounds_source.tile_bounds) == "function" and
		type(bounds_source.column_bounds) == "function",
		"air chunks need the writer's surface envelope")
	assert(type(water_level) == "number", "air chunks need the water level")
	local MARGIN = 16 -- one mapblock between the envelope and the chunk
	local AUTHORED_FLOOR = -37 -- the R5 manifest's authored_floor
	local MEMO = 64 -- recent owner columns (a chunk column is generated together)
	-- memo[key] = {top, complete}: the highest writer height found over the
	-- footprint; `complete` once the owner and the whole reach ring are read.
	local memo, keys, slot = {}, {}, 0
	local function remember(key, top, complete)
		local entry = memo[key]
		if entry then
			entry[1], entry[2] = top, complete
			return
		end
		slot = slot % MEMO + 1
		if keys[slot] then memo[keys[slot]] = nil end
		keys[slot], memo[key] = key, {top, complete}
	end
	-- Whether something the writer may place reaches `limit` or higher over
	-- the owner columns of [minp, maxp]: the boxes first, then the owner's
	-- columns, then the ring of the content reach round them; the first
	-- height at or above `limit` decides.
	local function writer_reaches(minp, maxp, limit)
		local key = minp.x .. ":" .. minp.z .. ":" .. maxp.x .. ":" .. maxp.z
		local entry = memo[key]
		if entry then
			if entry[1] >= limit then return true end
			if entry[2] then return false end
		end
		local radius, _, top = bounds_source.tile_bounds(minp, maxp)
		assert(type(radius) == "number" and radius >= 1 and radius % 1 == 0,
			"air chunk content reach differs")
		local column_bounds = bounds_source.column_bounds
		if top < limit then
			for z = minp.z, maxp.z do
				for x = minp.x, maxp.x do
					local _, high = column_bounds(x, z)
					if high > top then top = high end
				end
				if top >= limit then break end
			end
		end
		if top < limit then
			for z = minp.z - radius, maxp.z + radius do
				if z < minp.z or z > maxp.z then
					for x = minp.x - radius, maxp.x + radius do
						local _, high = column_bounds(x, z)
						if high > top then top = high end
					end
				else
					for x = minp.x - radius, minp.x - 1 do
						local _, high = column_bounds(x, z)
						if high > top then top = high end
					end
					for x = maxp.x + 1, maxp.x + radius do
						local _, high = column_bounds(x, z)
						if high > top then top = high end
					end
				end
				if top >= limit then break end
			end
			remember(key, top, top < limit)
		else
			remember(key, top, false)
		end
		return top >= limit
	end
	local M = {}
	-- Air above. get_heightmap() returns the engine heightmap of the current
	-- chunk.
	function M.untouched(minp, maxp, get_heightmap)
		if minp.y <= water_level then return false end
		local heightmap = get_heightmap()
		local columns = (maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)
		if type(heightmap) ~= "table" or #heightmap ~= columns then return false end
		local low = minp.y
		for index = 1, columns do
			if heightmap[index] >= low then return false end
		end
		return not writer_reaches(minp, maxp, low - MARGIN)
	end
	-- Rock below: no plan, no heightmap; the box bottom only when the chunk
	-- already lies below the authored floor.
	function M.below(minp, maxp)
		if maxp.y + MARGIN >= AUTHORED_FLOOR then return false end
		local _, bottom = bounds_source.tile_bounds(minp, maxp)
		return maxp.y + MARGIN < bottom
	end
	M.AUTHORED_FLOOR, M.MARGIN = AUTHORED_FLOOR, MARGIN
	return M
end
