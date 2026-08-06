-- Post-generation pass for the two things the biome system cannot express:
--
--  * the CONTINENT OCEAN MASK (docs/design/world.md §1/§2b): the world is two
--    separate continents mirrored at z = 0, everything else is ocean —
--    "the terrain generates, but it MUST be water, no islands". v7 happily
--    grows land outside the continent rectangles, so this pass caps the
--    surface of every column near or outside a rectangle edge and floods
--    what it cut. The shoreline is soft: a 2D noise insets the rectangle by
--    0..150 nodes, and because the inset is clamped at 0 it only ever moves
--    the coast INWARD — the 200-node strait of §1 (|z| < 100 is water) is
--    guaranteed by construction, never by luck of the noise.
--
--  * the RACE CAPITAL PLATFORMS: a walkable, guaranteed flat platform at all
--    six race capitals (grug_core.capitals) — placeholder until WP13 ships
--    real capital structures. The capitals sit at z = ±900, deep inside the
--    safe core, so the mask never reaches them.
--
-- (The old east-west mountain wall at |x| = 2000 is gone: the continent
-- redesign replaces walls with ocean.)

local X_HALF = grug_core.CONTINENT_X_HALF
local Z_MIN = grug_core.CONTINENT_Z_MIN
local Z_MAX = grug_core.CONTINENT_Z_MAX
local CAMP_HALF = grug_core.CAMP_HALF
local CLEAR_HEIGHT = grug_core.CAMP_CLEAR_HEIGHT
local SKIRT_DEPTH = 16 -- platform base reaches this far below the surface

-- Sea level of the active mapgen (v7 default 1); the whole mask profile is
-- expressed relative to it.
local WATER_LEVEL = tonumber(core.get_mapgen_setting("water_level")) or 1

--
-- Continent ocean mask
--

local TAPER = 60 -- width of the shore -> inland ramp
local INSET_MAX = 150 -- the coast noise pulls the shoreline in by 0..150
local SHORE_DROP = 5 -- surface cap right at the shoreline: W - 5
local TAPER_RISE = 50 -- cap gained across the taper band (quadratic ease)
local SHELF_DEPTH = 10 -- seabed drops this much across SHELF_WIDTH
local SHELF_WIDTH = 60 -- ... and is flat further out (v7 takes over)
local BEACH_DEPTH = 3 -- sand layers put on a newly exposed top
-- Decorations (trees) were already placed when this pass runs and reach at
-- most this far above the mapgen heightmap; carving stops there, so a
-- mapchunk high above the terrain costs nothing.
local DECO_MARGIN = 32

-- Inland-signed distance to the NEARER continent rectangle: positive inside,
-- negative outside, in nodes. Only three edges can be the nearest one for a
-- given continent — the flank (|x| = X_HALF), the strait-facing front
-- (|z| = Z_MIN) and the back (|z| = Z_MAX) — and since the two rectangles
-- are mirrored at z = 0, evaluating them on |z| yields the max over both
-- (the far continent is never the nearer one). Pure arithmetic: exposed so
-- it can be exercised without the engine.
local function continent_distance(x, z)
	local ax = x >= 0 and x or -x
	local az = z >= 0 and z or -z
	local d = X_HALF - ax -- flank
	local front = az - Z_MIN
	if front < d then
		d = front
	end
	local back = Z_MAX - az
	if back < d then
		d = back
	end
	return d
end
grug_mapgen.continent_distance = continent_distance

-- Highest y the terrain may keep at inland-signed distance s (after the
-- coast noise inset). Seaward of the shoreline it is the ocean floor
-- profile: a shelf from ~5 below sea level at the beach to ~15 below out at
-- SHELF_WIDTH (deeper is pointless — v7's own seabed is below that anyway).
-- Inland it rises quadratically, so the last nodes before the water sit at
-- beach level and the ramp only gets steep once it is safely inside.
local function surface_cap(s)
	if s <= 0 then
		local away = -s
		if away > SHELF_WIDTH then
			away = SHELF_WIDTH
		end
		return math.floor(WATER_LEVEL - SHORE_DROP - 1 -
			away / SHELF_WIDTH * SHELF_DEPTH)
	end
	local t = s / TAPER
	if t > 1 then
		t = 1
	end
	return math.floor(WATER_LEVEL - SHORE_DROP + t * t * TAPER_RISE)
end
grug_mapgen.surface_cap = surface_cap

-- Deepest y the mask can ever carve (deepest shelf cap + 1).
-- Everything below is pure underground: such mapchunks are skipped outright,
-- so caves stay caves no matter how far out at sea they are. (The beach
-- re-surfacing reaches BEACH_DEPTH lower, but it only ever runs in a chunk
-- that carved something, i.e. one that is above this line.)
local MASK_MIN_Y = surface_cap(-SHELF_WIDTH) + 1

-- core.get_perlin was renamed in 5.12; keep working on both.
local get_noise = core.get_value_noise or core.get_perlin

local coast_noise
local function coast_inset(x, z)
	coast_noise = coast_noise or get_noise({
		offset = 75, scale = 75,
		spread = {x = 300, y = 300, z = 300},
		seed = 91744, octaves = 3, persist = 0.55,
	})
	local inset = coast_noise:get_2d({x = x, y = z})
	if inset < 0 then
		return 0
	elseif inset > INSET_MAX then
		return INSET_MAX
	end
	return inset
end

local c_air = core.get_content_id("air")
local c_ignore = core.get_content_id("ignore")
local c_cobble = core.get_content_id("default:cobble")
local c_sand = core.get_content_id("default:sand")
local c_water = core.get_content_id("default:water_source")

-- Content the beach re-surfacing must not turn into sand (it only ever
-- replaces the solid material it just exposed).
local not_solid = {
	[c_air] = true,
	[c_ignore] = true,
	[c_water] = true,
	[core.get_content_id("default:water_flowing")] = true,
	[core.get_content_id("default:river_water_source")] = true,
	[core.get_content_id("default:river_water_flowing")] = true,
}

-- Chunk-level fast path: true only for mapchunks that can contain a coast
-- column at all. Pure arithmetic on the chunk box — no mapgen object is
-- fetched for the (vast majority) fully inland or deep chunks.
local function chunk_needs_mask(minp, maxp)
	if maxp.y < MASK_MIN_Y then
		return false -- pure underground: caves stay caves
	end
	local ax = math.max(math.abs(minp.x), math.abs(maxp.x))
	local az_far = math.max(math.abs(minp.z), math.abs(maxp.z))
	local az_near = 0
	if minp.z > 0 then
		az_near = minp.z
	elseif maxp.z < 0 then
		az_near = -maxp.z
	end
	-- Smallest continent_distance anywhere in the chunk box.
	local d = math.min(X_HALF - ax, az_near - Z_MIN, Z_MAX - az_far)
	return d < TAPER + INSET_MAX
end

-- Column rule (per x/z, run before the camps):
--   s   = continent_distance(x, z) - coast_inset(x, z)
--   cap = surface_cap(s)
--   carve when the mapgen heightmap h exceeds cap: water_source for
--   y <= water level, air above, from cap+1 up to the top of the column.
-- h is clamped by the engine when the real surface lies outside the chunk's
-- y range (maxp.y if the ground continues above it, -MAX_MAP_GENERATION_LIMIT
-- if the column holds no walkable node at all), and `h > cap` happens to be
-- the correct decision in every one of those cases: ground above -> carve the
-- whole chunk, nothing walkable -> nothing to carve.
local function build_ocean_mask(data, area, minp, maxp)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return
	end
	local width = maxp.x - minp.x + 1
	local ystride = area.ystride
	local band = TAPER + INSET_MAX
	for z = minp.z, maxp.z do
		local row = (z - minp.z) * width
		for x = minp.x, maxp.x do
			local d = continent_distance(x, z)
			if d < band then
				local cap = surface_cap(d - coast_inset(x, z))
				local h = heightmap[row + (x - minp.x) + 1]
				if h and h > cap and cap < maxp.y then
					local y1 = math.max(cap + 1, minp.y)
					local y2 = math.min(maxp.y, h + DECO_MARGIN)
					local wet = math.min(y2, WATER_LEVEL)
					if wet >= y1 then
						local idx = area:index(x, y1, z)
						for _ = y1, wet do
							data[idx] = c_water
							idx = idx + ystride
						end
					end
					local dry = math.max(y1, WATER_LEVEL + 1)
					if y2 >= dry then
						local idx = area:index(x, dry, z)
						for _ = dry, y2 do
							data[idx] = c_air
							idx = idx + ystride
						end
					end
					-- Re-surface the exposed top as beach/seabed sand. Only
					-- near water level: the rare high-t column keeps its own
					-- material (a cliff face, not a beach).
					if cap <= WATER_LEVEL + 3 then
						local sy1 = math.max(cap - BEACH_DEPTH + 1, minp.y)
						local sy2 = math.min(cap, maxp.y)
						if sy2 >= sy1 then
							local idx = area:index(x, sy1, z)
							for _ = sy1, sy2 do
								if not not_solid[data[idx]] then
									data[idx] = c_sand
								end
								idx = idx + ystride
							end
						end
					end
				end
			end
		end
	end
end

--
-- Race capital platforms
--

-- Terrain-adaptive platform height: the first mapchunk that touches a
-- capital measures the mapgen heightmap in a neighborhood around the capital
-- anchor and takes the MEDIAN — the platform sits at the typical local
-- terrain level. (The maximum put the platform on par with nearby peaks:
-- stepping off meant a deadly fall. The old fixed y buried it inside hills.
-- The median bounds both failure modes; remaining slope faces are climbable.)
-- The result is persisted per race via grug_core (decided once, never shifts).
local NEIGHBORHOOD = 40 -- Chebyshev radius sampled around the capital anchor
local PLATFORM_MIN_Y = grug_core.CAMP_PLATFORM_Y -- keeps it above water
local PLATFORM_MAX_Y = 100 -- sanity cap (find_surface scans from 120)

local function decide_platform_y(capital, minp, maxp)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return nil
	end
	local x1 = math.max(minp.x, capital.x - NEIGHBORHOOD)
	local x2 = math.min(maxp.x, capital.x + NEIGHBORHOOD)
	local z1 = math.max(minp.z, capital.z - NEIGHBORHOOD)
	local z2 = math.min(maxp.z, capital.z + NEIGHBORHOOD)
	local width = maxp.x - minp.x + 1
	local samples = {}
	for z = z1, z2 do
		local row = (z - minp.z) * width
		for x = x1, x2 do
			local h = heightmap[row + (x - minp.x) + 1]
			-- Values clamped to the chunk edge mean the real surface lies
			-- outside this chunk's y range — not usable for a decision.
			if h and h > minp.y and h < maxp.y then
				samples[#samples + 1] = h
			end
		end
	end
	if #samples == 0 then
		return nil
	end
	table.sort(samples)
	local median = samples[math.floor((#samples + 1) / 2)]
	return math.min(math.max(median, PLATFORM_MIN_Y), PLATFORM_MAX_Y)
end

local function build_camp(data, area, minp, maxp, camp)
	local x1 = math.max(minp.x, camp.x - CAMP_HALF)
	local x2 = math.min(maxp.x, camp.x + CAMP_HALF)
	local z1 = math.max(minp.z, camp.z - CAMP_HALF)
	local z2 = math.min(maxp.z, camp.z + CAMP_HALF)
	local base_y = math.max(minp.y, camp.y - SKIRT_DEPTH)
	local top_y = math.min(maxp.y, camp.y)
	local clear_y1 = math.max(minp.y, camp.y + 1)
	local clear_y2 = math.min(maxp.y, camp.y + CLEAR_HEIGHT)
	for x = x1, x2 do
		for z = z1, z2 do
			for y = base_y, top_y do
				data[area:index(x, y, z)] = c_cobble
			end
			for y = clear_y1, clear_y2 do
				data[area:index(x, y, z)] = c_air
			end
		end
	end
end

core.register_on_generated(function(minp, maxp, blockseed)
	local need_mask = chunk_needs_mask(minp, maxp)

	local camps = {}
	for race_id, capital in pairs(grug_core.capitals) do
		if maxp.x >= capital.x - CAMP_HALF and
				minp.x <= capital.x + CAMP_HALF and
				maxp.z >= capital.z - CAMP_HALF and
				minp.z <= capital.z + CAMP_HALF then
			local y = grug_core.get_camp_platform_y(race_id)
			if not y then
				y = decide_platform_y(capital, minp, maxp)
				if y then
					grug_core.set_camp_platform_y(race_id, y)
					core.log("action", ("[grug_mapgen] %s capital platform " ..
						"decided at y=%d"):format(race_id, y))
				end
			end
			-- No y yet (chunk fully above/below the surface): skip — the
			-- chunk that actually contains the surface decides and builds.
			if y and maxp.y >= y - SKIRT_DEPTH and
					minp.y <= y + CLEAR_HEIGHT then
				camps[#camps + 1] = {x = capital.x, y = y, z = capital.z}
			end
		end
	end

	if not need_mask and #camps == 0 then
		return
	end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()

	if need_mask then
		build_ocean_mask(data, area, minp, maxp)
	end
	for _, camp in ipairs(camps) do
		build_camp(data, area, minp, maxp, camp)
	end

	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map()
end)
