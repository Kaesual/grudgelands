-- Round 47 lane SW: the swamp's shallow pools (tools/r47_sw/DESIGN.md "The
-- pool rule on real terrain"; plan ruling 23 with the user's rule for
-- slopes: a pool never makes flowing water, gentle ground is levelled by at
-- most one node, steep ground gets no pool, towns, POIs and protected ground
-- are never touched).
--
-- Pure Lua 5.1 / LuaJIT, no engine calls: every answer is a function of the
-- world seed and the planner source's analytic column values (heights,
-- biome, water, claims, surface caves), so a column decides the same in
-- every mapchunk and both environments. Read by the surface selector
-- (r6_content.lua: pool columns keep plain mud with a deeper filler, the
-- ground beside a pool turns to mottled mud), the decoration planner
-- (r6_planner.lua: no decoration roots in a pool column), the writer's
-- surface skin (r6_settlement.lua: no skin opening at a pool or beside one)
-- and the swamp pass (swamp_writer.lua), which writes the water.
--
--   local pools = dofile(wp40 .. "/swamp_pools.lua")(full_seed, planner_source)
--   pools.at(x, z)     -> level, depth, ground y of a kept pool column, else nil
--   pools.guard(x, z)  -> true on a kept pool column and its 8 neighbours
--   pools.near(x, z)   -> true within 2 (square) of a kept pool column
--   pools.hash(x, z, salt) -> a mixed integer in [0, 16777213) for the
--                         swamp pass's plant rolls
--
-- The rule, per column (DESIGN.md):
--   1. candidate: a dry swamp land column whose pool noise lies below POOL,
--      its 8 neighbours dry swamp land too, none of the 9 under a claim
--      exclusion (static exclusions: towns, capitals, POI cores and
--      margins, protected ground), a road or water overlay, a functional
--      surface, a hard foundation, a coast material or a surface cave, and
--      no water column (sea, lake, river) within 2 (square);
--   2. gentle or steep: the ground tops of the 5 x 5 window round it differ
--      by at most RELIEF (1); else no pool;
--   3. level: the window's lowest ground top. The water top lies there; a
--      column one higher loses its top node (levelling, at most one node,
--      only in the pool column);
--   4. no flow: a candidate is kept only if no 8-neighbour candidate has a
--      lower level (else its water would spill into that neighbour's air).
--      A dropped column keeps its ground, at least as high as every
--      neighbour's level (each neighbour's window holds it), so one pass
--      decides;
--   5. 2 deep where the deep noise lies below DEEP and all four side
--      neighbours are kept with the same level.
return function(full_seed, planner_source)
	local floor = math.floor
	if type(full_seed) ~= "string" or full_seed == "" or type(planner_source) ~= "table" then
		error("swamp pools: construction seam differs", 0)
	end
	for _, name in ipairs({"column_values_at", "overlay_exclusion_at",
			"static_exclusion_values_at", "surface_cave_run_at", "coast_material_at"}) do
		if type(planner_source[name]) ~= "function" then
			error("swamp pools: planner source lacks " .. name, 0)
		end
	end
	local column_values_at = planner_source.column_values_at

	local M = {}
	M.POOL, M.DEEP, M.RELIEF, M.MIN_LEVEL = 370, 290, 1, 2
	M.WINDOW = 2   -- the window's reach (5 x 5) and the distance kept from other water

	local phase = 0
	for index = 1, #full_seed do
		phase = (phase * 131 + string.byte(full_seed, index)) % 65521
	end
	-- Integer mixing on a lattice (the kind r6_content.lua's scenery noise
	-- uses); every product stays below 2^53.
	local function mix(x, z, salt)
		local value = (x * 374761 + z * 668265 + phase * 69069 + salt) % 16777213
		value = (value * value) % 16777213
		return (value * 48271) % 16777213
	end
	function M.hash(x, z, salt)
		local a = mix(x * 37 + z * 11, x * 7 - z * 29, salt)
		return mix(a % 4093, floor(a / 4093) % 4093 + x * 53 - z * 17, salt + 157)
	end
	local function lattice(x, z, salt) return floor(mix(x, z, salt) * 1024 / 16777213) end
	local function weight(offset, period)
		local t = floor(offset * 1024 / period)
		return floor(t * t * (3072 - 2 * t) / 1048576)
	end
	local function lerp(a, b, t) return a + floor((b - a) * t / 1024) end
	local function noise(x, z, period, salt)
		local ix, iz = floor(x / period), floor(z / period)
		local tx, tz = weight(x - ix * period, period), weight(z - iz * period, period)
		return lerp(lerp(lattice(ix, iz, salt), lattice(ix + 1, iz, salt), tx),
			lerp(lattice(ix, iz + 1, salt), lattice(ix + 1, iz + 1, salt), tx), tz)
	end
	-- Two octaves: a broad shape with a finer edge.
	local function pool_noise(x, z)
		return floor((2 * noise(x, z, 11, 4711) + noise(x, z, 6, 4723)) / 3)
	end

	-- Direct-mapped memos (a pure function of (x, z), as the surface
	-- selector's steep class).
	local SLOTS = 65536
	local function memo()
		local mx, mz, mv = {}, {}, {}
		return function(x, z, compute)
			local slot = (x * 40503 + z) % SLOTS
			if mx[slot] == x and mz[slot] == z then return mv[slot] end
			local value = compute(x, z)
			mx[slot], mz[slot], mv[slot] = x, z, value
			return value
		end
	end
	local plain_memo, level_memo, kept_memo, guard_memo, near_memo =
		memo(), memo(), memo(), memo(), memo()

	-- A dry swamp land column fit to hold or border a pool: its ground y,
	-- else false.
	local function plain(x, z)
		return plain_memo(x, z, function()
			local water_class, _, _, biome, _, terrain_y, water_y, river_id, _,
				functional_kind, _, _, _, _, _, _, _, _, _, hard_foundation =
					column_values_at(x, z)
			if water_class ~= "land" or biome ~= "grug_swamp" or water_y ~= nil or
					river_id ~= nil or functional_kind ~= nil or hard_foundation or
					planner_source.overlay_exclusion_at(x, z) ~= nil or
					planner_source.static_exclusion_values_at(x, z) ~= nil or
					planner_source.coast_material_at(x, z) ~= nil then
				return false
			end
			local cave_low = planner_source.surface_cave_run_at(x, z)
			if cave_low ~= nil then return false end
			return terrain_y
		end)
	end

	-- The candidate's level (rules 1-3), else false.
	local function level(x, z)
		return level_memo(x, z, function()
			if pool_noise(x, z) >= M.POOL or not plain(x, z) then return false end
			local low, high
			for dz = -M.WINDOW, M.WINDOW do
				for dx = -M.WINDOW, M.WINDOW do
					local near = dx >= -1 and dx <= 1 and dz >= -1 and dz <= 1
					local y
					if near then
						y = plain(x + dx, z + dz)
						if not y then return false end
					else
						local water_class, _, _, _, _, terrain_y, water_y =
							column_values_at(x + dx, z + dz)
						if water_class ~= "land" or water_y ~= nil then return false end
						y = terrain_y
					end
					if not low or y < low then low = y end
					if not high or y > high then high = y end
				end
			end
			if high - low > M.RELIEF or low < M.MIN_LEVEL then return false end
			return low
		end)
	end

	-- Rule 4: kept, with its level.
	local function kept(x, z)
		return kept_memo(x, z, function()
			local L = level(x, z)
			if not L then return false end
			for dz = -1, 1 do
				for dx = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local other = level(x + dx, z + dz)
						if other and other < L then return false end
					end
				end
			end
			return L
		end)
	end

	function M.at(x, z)
		local L = kept(x, z)
		if not L then return nil end
		local depth = 1
		if noise(x, z, 9, 4733) < M.DEEP then
			depth = 2
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				if kept(x + d[1], z + d[2]) ~= L then depth = 1 break end
			end
		end
		return L, depth, plain(x, z)
	end

	-- Whether any candidate lies within `reach` (square): the memoised
	-- levels, so `near` skips the kept tests where no pool can be.
	local function any_candidate(x, z, reach)
		for dz = -reach, reach do
			for dx = -reach, reach do
				if level(x + dx, z + dz) then return true end
			end
		end
		return false
	end

	function M.guard(x, z)
		return guard_memo(x, z, function()
			for dz = -1, 1 do
				for dx = -1, 1 do
					if kept(x + dx, z + dz) then return true end
				end
			end
			return false
		end)
	end

	function M.near(x, z)
		return near_memo(x, z, function()
			if not any_candidate(x, z, 2) then return false end
			for dz = -2, 2 do
				for dx = -2, 2 do
					if kept(x + dx, z + dz) then return true end
				end
			end
			return false
		end)
	end
	return M
end
