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
--    The cap rises across a 150-node ramp to ~115 nodes above sea level and
--    is then dropped entirely (columns further inland are never even looked
--    at), so the mask shapes the coast and leaves the hinterland to v7. What
--    it does cut it re-dresses: sand at beach level, otherwise the column's
--    own biome surface, so a shaved coastal hill stays walkable land.
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

local TAPER = 150 -- width of the shore -> inland ramp; beyond it: no cap
local INSET_MAX = 150 -- the coast noise pulls the shoreline in by 0..150
local SHORE_DROP = 5 -- surface cap right at the shoreline: W - 5
local TAPER_RISE = 119 -- cap gained across the taper band (quadratic ease)
local SHELF_DEPTH = 10 -- seabed drops this much across SHELF_WIDTH
local SHELF_WIDTH = 60 -- ... and is flat further out (v7 takes over)
local BEACH_DEPTH = 3 -- sand layers put on a newly exposed beach top
local FILLER_DEPTH = 2 -- filler layers under a re-dressed biome top
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
-- coast noise inset), or nil for "no cap at all" from TAPER inland — the
-- mask shapes the coast, it must never flatten the hinterland.
-- Seaward of the shoreline the cap is the ocean floor profile: a shelf from
-- ~5 below sea level at the beach to ~15 below out at SHELF_WIDTH (deeper is
-- pointless — v7's own seabed is below that anyway). Inland it rises
-- quadratically to ~W+114 across the ramp, so the last nodes before the
-- water sit at beach level and only real mountains near the shore get cut.
-- Strictly a function of (x, z): vertically stacked mapchunks of the same
-- column MUST agree on the cap, so nothing chunk-local (heightmap!) may
-- enter here.
local function surface_cap(s)
	if s >= TAPER then
		return nil
	end
	if s <= 0 then
		local away = -s
		if away > SHELF_WIDTH then
			away = SHELF_WIDTH
		end
		return math.floor(WATER_LEVEL - SHORE_DROP - 1 -
			away / SHELF_WIDTH * SHELF_DEPTH)
	end
	local t = s / TAPER -- 0 < t < 1, the s >= TAPER case returned above
	return math.floor(WATER_LEVEL - SHORE_DROP + t * t * TAPER_RISE)
end
grug_mapgen.surface_cap = surface_cap

-- Flat part of the shelf: everything from SHELF_WIDTH seaward shares one cap,
-- so the open sea needs no coast noise at all.
local SEA_FLOOR_CAP = surface_cap(-SHELF_WIDTH)

-- Deepest y the mask can ever carve (deepest shelf cap + 1).
-- Everything below is pure underground: such mapchunks are skipped outright,
-- so caves stay caves no matter how far out at sea they are. (The beach
-- re-surfacing reaches BEACH_DEPTH lower, but it only ever runs in a chunk
-- that carved something, i.e. one that is above this line.)
local MASK_MIN_Y = SEA_FLOOR_CAP + 1

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

-- Reused across mapchunks: vm:get_data() without a buffer allocates a fresh
-- ~11 MB table for every masked chunk.
local vm_data = {}

local c_air = core.get_content_id("air")
local c_ignore = core.get_content_id("ignore")
local c_cobble = core.get_content_id("default:cobble")
local c_sand = core.get_content_id("default:sand")
local c_water = core.get_content_id("default:water_source")

-- Content the re-dressing must not overwrite (it only ever replaces the
-- solid material it just exposed).
local not_solid = {
	[c_air] = true,
	[c_ignore] = true,
	[c_water] = true,
	[core.get_content_id("default:water_flowing")] = true,
	[core.get_content_id("default:river_water_source")] = true,
	[core.get_content_id("default:river_water_flowing")] = true,
}

-- Surface layers of a biome, by biome id, for re-dressing a cut top above
-- beach level: node_top (depth_top layers) over node_filler (FILLER_DEPTH
-- layers). Without it a shaved coastal hill would end in bare stone — not
-- walkable-looking, no mob spawn surface, no decorations. Resolved lazily
-- and cached: registered_biomes and content ids are fixed once mapgen runs.
-- false = "this biome cannot be re-dressed" (leave the cut material).
local biome_surface = {}
local function biome_surface_at(id)
	local surf = biome_surface[id]
	if surf == nil then
		surf = false
		local name = id and core.get_biome_name(id)
		local def = name and core.registered_biomes[name]
		if def and def.node_top and core.registered_nodes[def.node_top] then
			local filler = def.node_filler
			surf = {
				top = core.get_content_id(def.node_top),
				top_depth = def.depth_top or 1,
				filler = (filler and core.registered_nodes[filler]) and
					core.get_content_id(filler) or nil,
			}
		end
		biome_surface[id] = surf
	end
	return surf or nil
end

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
--   d   = continent_distance(x, z)
--   cap = SEA_FLOOR_CAP                       for d <= -SHELF_WIDTH
--         surface_cap(d - coast_inset(x, z))  otherwise; nil (column
--                                             untouched) from TAPER inland
--   carve when the mapgen heightmap h exceeds cap: water_source for
--   y <= water level, air above, from cap+1 up to the top of the column,
--   then re-dress the exposed top (sand at beach level, else the column's
--   biome surface).
-- h is clamped by the engine when the real surface lies outside the chunk's
-- y range (maxp.y if the ground continues above it, -MAX_MAP_GENERATION_LIMIT
-- if the column holds no walkable node at all), and `h > cap` happens to be
-- the correct decision in every one of those cases: ground above -> carve the
-- whole chunk, nothing walkable -> nothing to carve. h decides only WHETHER a
-- column is cut, never WHERE — the cut height is (x, z)-deterministic, so
-- vertically stacked mapchunks of one column cut at exactly the same y.
-- Returns true if any water was placed (the caller then updates liquids).
local function build_ocean_mask(data, area, minp, maxp)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return false
	end
	local biomemap = core.get_mapgen_object("biomemap")
	local width = maxp.x - minp.x + 1
	local ystride = area.ystride
	local band = TAPER + INSET_MAX
	local wrote_water = false
	for z = minp.z, maxp.z do
		local row = (z - minp.z) * width
		for x = minp.x, maxp.x do
			local d = continent_distance(x, z)
			if d < band then
				local cap
				if d <= -SHELF_WIDTH then
					cap = SEA_FLOOR_CAP -- flat shelf: no noise lookup needed
				else
					cap = surface_cap(d - coast_inset(x, z))
				end
				local i2d = row + (x - minp.x) + 1
				local h = heightmap[i2d]
				-- `cap <= maxp.y` (not <): when the cap sits exactly on the
				-- chunk's top edge the carve ranges come out empty, but the
				-- re-dress below must still run in THIS chunk -- the chunk
				-- above starts at cap+1 and can never write the top layers.
				if cap and h and h > cap and cap <= maxp.y then
					local y1 = math.max(cap + 1, minp.y)
					local y2 = math.min(maxp.y, h + DECO_MARGIN)
					local wet = math.min(y2, WATER_LEVEL)
					if wet >= y1 then
						local idx = area:index(x, y1, z)
						for _ = y1, wet do
							data[idx] = c_water
							idx = idx + ystride
						end
						wrote_water = true
					end
					local dry = math.max(y1, WATER_LEVEL + 1)
					if y2 >= dry then
						local idx = area:index(x, dry, z)
						for _ = dry, y2 do
							data[idx] = c_air
							idx = idx + ystride
						end
					end
					-- Re-dress the exposed top: sand where the cut ends at
					-- beach/seabed level, otherwise the biome's own surface
					-- (a shaved coastal hill must stay walkable land, not a
					-- bare stone plateau).
					local top, top_depth, filler, layers
					if cap <= WATER_LEVEL + 3 then
						top, top_depth, layers = c_sand, BEACH_DEPTH, BEACH_DEPTH
					else
						local surf = biomemap and biome_surface_at(biomemap[i2d])
						if surf then
							top, top_depth = surf.top, surf.top_depth
							filler = surf.filler
							layers = top_depth + (filler and FILLER_DEPTH or 0)
						end
					end
					if top then
						local sy1 = math.max(cap - layers + 1, minp.y)
						local idx = area:index(x, cap, z)
						for y = cap, sy1, -1 do
							if not not_solid[data[idx]] then
								data[idx] = (cap - y) < top_depth and top or filler
							end
							idx = idx - ystride
						end
					end
				end
			end
		end
	end
	return wrote_water
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
	-- Reused buffer: a fresh get_data() table is ~11 MB of garbage per chunk.
	local data = vm:get_data(vm_data)

	local wrote_water = false
	if need_mask then
		wrote_water = build_ocean_mask(data, area, minp, maxp)
	end
	for _, camp in ipairs(camps) do
		build_camp(data, area, minp, maxp, camp)
	end

	vm:set_data(data)
	if wrote_water then
		-- Without this the water we placed never starts flowing: coastal
		-- caves and cut-open hollows keep standing water walls.
		vm:update_liquids()
	end
	vm:calc_lighting()
	vm:write_to_map()
end)
