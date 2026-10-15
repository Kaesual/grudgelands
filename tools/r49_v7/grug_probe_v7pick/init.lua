-- Round 49 lane V7 engine probe (disposable, never shipped): picks one
-- mountain-heavy and one ridge-heavy ordinary land chunk column of the world
-- seed from native v7's own noise, without generating anything, logs the
-- candidates and shuts the server down.
--
-- v7 terrain (mapgen_v7.cpp generateTerrain, Luanti 5.17) is evaluated per
-- sample point with the engine's ValueNoise (world seed + noiseparams seed,
-- the same seed the mapgen uses):
-- * base level: terrain_base/alt with the per-point persistence of
--   terrain_persist, blended by height_select (baseTerrainLevelFromMap);
-- * mountain stone: np_mountain(x,y,z) - (y - mount_zero_level) /
--   max(np_mount_height(x,z), 1) >= 0 (getMountainTerrainFromMap);
-- * river channel (ridges): |np_ridge_uwater| * 2 <= 0.2 and
--   np_ridge(x,y,z) * max(y - wl, 0) / 7 + (0.2 - |uw| * 2) *
--   (y - wl + 17) / 2.5 >= 0.6 (getRiverChannelFromMap), from wl - 16 up.
-- Our surface is the planner's column tuple (terrain, water).
--
-- Metrics per chunk column (sampled points, y step STEP; voxel estimates are
-- scaled to the 6400 columns):
-- * mnt_above: mountain stone above our surface and above v7's base level --
--   what the writer clears today and `nomountains` removes;
-- * mnt_below: mountain stone between v7's base level and our terrain -- rock
--   the writer keeps today and must fill under `nomountains`;
-- * ridge_below: river channel voxels below our terrain and below v7's stone
--   top -- void (water at or below water level, air above) the writer fills
--   today and `noridges` removes.
-- "Ordinary" as in tools/mgprof: every one of the 6400 columns is land with
-- no river, functional ground, hard foundation, road or hard protection.

local PREFIX = "[v7pick] "
local core_source -- the planner source, set by pick()
local function log(message) core.log("action", PREFIX .. message) end
local STEP = 8 -- y step of the coarse mountain scan
local TOP = 880 -- above the highest possible mountain stone (round23 doc: ~872)

local function noise_params(name, default)
	local np = core.get_mapgen_setting_noiseparams(name)
	if type(np) ~= "table" then
		log("noiseparams " .. name .. " unavailable; engine default used")
		np = default
	end
	return np
end

-- Engine defaults (mapgen_v7.cpp MapgenV7Params) as a fallback only.
local function v3(x, y, z) return {x = x, y = y, z = z} end
local NP = {}
local function setup()
	NP.base = noise_params("mgv7_np_terrain_base", {offset = 4, scale = 70,
		spread = v3(600, 600, 600), seed = 82341, octaves = 5, persistence = 0.6,
		lacunarity = 2})
	NP.alt = noise_params("mgv7_np_terrain_alt", {offset = 4, scale = 25,
		spread = v3(600, 600, 600), seed = 5934, octaves = 5, persistence = 0.6,
		lacunarity = 2})
	NP.persist = noise_params("mgv7_np_terrain_persist", {offset = 0.6,
		scale = 0.1, spread = v3(2000, 2000, 2000), seed = 539, octaves = 3,
		persistence = 0.6, lacunarity = 2})
	NP.select = noise_params("mgv7_np_height_select", {offset = -8, scale = 16,
		spread = v3(500, 500, 500), seed = 4213, octaves = 6, persistence = 0.7,
		lacunarity = 2})
	NP.mount_height = noise_params("mgv7_np_mount_height", {offset = 256,
		scale = 112, spread = v3(1000, 1000, 1000), seed = 72449, octaves = 3,
		persistence = 0.6, lacunarity = 2})
	NP.uwater = noise_params("mgv7_np_ridge_uwater", {offset = 0, scale = 1,
		spread = v3(1000, 1000, 1000), seed = 85039, octaves = 5,
		persistence = 0.6, lacunarity = 2})
	NP.mountain = noise_params("mgv7_np_mountain", {offset = -0.6, scale = 1,
		spread = v3(250, 350, 250), seed = 5333, octaves = 5, persistence = 0.63,
		lacunarity = 2})
	NP.ridge = noise_params("mgv7_np_ridge", {offset = 0, scale = 1,
		spread = v3(100, 100, 100), seed = 6467, octaves = 4, persistence = 0.75,
		lacunarity = 2})
	for _, key in ipairs({"base", "alt", "persist", "select", "mount_height",
			"uwater", "mountain", "ridge"}) do
		local np = NP[key]
		log(("np %s offset=%s scale=%s spread=%s,%s,%s seed=%s octaves=%s persist=%s flags=%s")
			:format(key, tostring(np.offset), tostring(np.scale), tostring(np.spread.x),
			tostring(np.spread.y), tostring(np.spread.z), tostring(np.seed),
			tostring(np.octaves), tostring(np.persistence or np.persist),
			tostring(np.flags)))
	end
end

local N = {}
local persist_noise = {}
local function noise_with_persist(key, persist)
	-- quantized to 1e-3; the base level error stays well below a node
	local q = math.floor(persist * 1000 + 0.5)
	local cache = persist_noise[key]
	if not cache then cache = {} persist_noise[key] = cache end
	local n = cache[q]
	if not n then
		local np = table.copy(NP[key])
		np.persistence, np.persist = q / 1000, nil
		n = core.get_value_noise(np)
		cache[q] = n
	end
	return n
end

local water_level, zero_level
local p2, p3 = {x = 0, y = 0}, {x = 0, y = 0, z = 0}
local function base_level(x, z)
	p2.x, p2.y = x, z
	local hselect = math.max(0, math.min(1, N.select:get_2d(p2)))
	local persist = N.persist:get_2d(p2)
	local hb = noise_with_persist("base", persist):get_2d(p2)
	local ha = noise_with_persist("alt", persist):get_2d(p2)
	if ha > hb then return ha end
	return hb * hselect + ha * (1 - hselect)
end
local function mountain_at(x, y, z, mount_h)
	p3.x, p3.y, p3.z = x, y, z
	return N.mountain:get_3d(p3) - (y - zero_level) / mount_h >= 0
end
local function channel_at(x, y, z, uw)
	local altitude = y - water_level
	if altitude < -16 then return false end
	p3.x, p3.y, p3.z = x, y, z
	local nridge = N.ridge:get_3d(p3) * math.max(altitude, 0) / 7
	return nridge + (0.2 - uw) * (altitude + 17) / 2.5 >= 0.6
end

-- One sample point: our tuple and v7's terrain; returns mnt_above, mnt_below,
-- ridge_below (in y-step units already multiplied out), the highest mountain
-- stone, the base level and our surface.
local function sample(source, x, z, step)
	local _, _, _, _, _, terrain_y, water_y = source.column_values_at(x, z)
	local cap = water_y and math.max(terrain_y, water_y) or terrain_y
	local base = math.floor(base_level(x, z))
	p2.x, p2.y = x, z
	local mount_h = math.max(N.mount_height:get_2d(p2), 1)
	local above, below, top = 0, 0, -math.huge
	for y = math.max(cap + 1, base + 1), TOP, step do
		if mountain_at(x, y, z, mount_h) then
			above = above + step
			if y > top then top = y end
		end
	end
	for y = base + 1, terrain_y - 1, step do
		if mountain_at(x, y, z, mount_h) then below = below + step end
	end
	local ridge = 0
	local uw = math.abs(N.uwater:get_2d(p2)) * 2
	if uw <= 0.2 then
		-- v7 stone top at this point, roughly: the base level (mountain stone
		-- above it is counted in steps only)
		local high = math.min(terrain_y - 1, base)
		for y = water_level - 16, high do
			if channel_at(x, y, z, uw) then ridge = ridge + 1 end
		end
	end
	return above, below, ridge, top, base, terrain_y
end

local function road_free_land(source, x, z)
	local water_class, _, _, _, _, _, _, river_id, _, functional_kind =
		source.column_values_at(x, z)
	return water_class == "land" and river_id == nil and functional_kind == nil
end

-- The full 6400-column ordinariness check (same rule as tools/mgprof).
local function ordinary(source, x0, z0)
	local tmin, tmax = math.huge, -math.huge
	for z = z0, z0 + 79 do
		for x = x0, x0 + 79 do
			local water_class, _, _, _, _, terrain_y, _, river_id, _,
				functional_kind, _, _, _, _, _, _, _, _, _, hard_foundation =
					source.column_values_at(x, z)
			if water_class ~= "land" or river_id ~= nil or functional_kind ~= nil or
					hard_foundation or source.road_column_at(x, z) ~= nil or
					grug_zones.hard_protection_kind_at({x = x, y = terrain_y, z = z}) then
				return false
			end
			if terrain_y < tmin then tmin = terrain_y end
			if terrain_y > tmax then tmax = terrain_y end
		end
	end
	return true, tmin, tmax
end

local function zone_biome(source, x, z)
	local _, _, zone_id, biome = source.column_values_at(x, z)
	return tostring(zone_id), tostring(biome)
end

-- Metrics over an n x n sample grid of one chunk column (voxels, scaled).
local function measure(source, x0, z0, n, step)
	local a, b, r, top, bmin, bmax, tmin, tmax = 0, 0, 0, -math.huge, math.huge,
		-math.huge, math.huge, -math.huge
	local pitch = 80 / n
	for iz = 0, n - 1 do
		for ix = 0, n - 1 do
			local x = x0 + math.floor((ix + 0.5) * pitch)
			local z = z0 + math.floor((iz + 0.5) * pitch)
			local sa, sb, sr, st, base, terrain = sample(source, x, z, step)
			a, b, r = a + sa, b + sb, r + sr
			if st > top then top = st end
			if base < bmin then bmin = base end
			if base > bmax then bmax = base end
			if terrain < tmin then tmin = terrain end
			if terrain > tmax then tmax = terrain end
		end
	end
	local scale = 6400 / (n * n)
	return {above = a * scale, below = b * scale, ridge = r * scale, top = top,
		bmin = bmin, bmax = bmax, tmin = tmin, tmax = tmax}
end

local function describe(tag, x0, z0, m, extra)
	local zone, biome = zone_biome(core_source, x0 + 40, z0 + 40)
	log(("%s x %d..%d z %d..%d zone %s biome %s: our terrain %d..%d, v7 base %d..%d, " ..
		"mountain top %s, mnt_above %.0f, mnt_below %.0f, ridge_below %.0f%s"):format(tag,
		x0, x0 + 79, z0, z0 + 79, zone, biome, m.tmin, m.tmax, m.bmin, m.bmax,
		m.top > -math.huge and tostring(m.top) or "none", m.above, m.below, m.ridge,
		extra or ""))
end

local function pick()
	local t0 = core.get_us_time()
	local source = grug_mapgen.wp40.planner_source
	core_source = source
	water_level = tonumber(core.get_mapgen_setting("water_level")) or 1
	zero_level = tonumber(core.get_mapgen_setting("mgv7_mount_zero_level")) or 0
	log(("spflags=%s water_level=%d mount_zero_level=%d"):format(
		tostring(core.get_mapgen_setting("mgv7_spflags")), water_level, zero_level))
	setup()
	N.select = core.get_value_noise(NP.select)
	N.persist = core.get_value_noise(NP.persist)
	N.mount_height = core.get_value_noise(NP.mount_height)
	N.uwater = core.get_value_noise(NP.uwater)
	N.mountain = core.get_value_noise(NP.mountain)
	N.ridge = core.get_value_noise(NP.ridge)
	-- Stage 1: every chunk column in the world rectangle whose 5 x 5 sample is
	-- road-free land; 3 x 3 noise sample, y step STEP.
	local rows, screened = {}, 0
	for z0 = -3152, 3088, 80 do
		for x0 = -3552, 3488, 80 do
			local ok = true
			for dz = 0, 4 do
				for dx = 0, 4 do
					if ok and not road_free_land(source, x0 + dx * 19 + 2, z0 + dz * 19 + 2) then
						ok = false
					end
				end
			end
			if ok then
				screened = screened + 1
				local m = measure(source, x0, z0, 3, STEP)
				rows[#rows + 1] = {x = x0, z = z0, m = m}
			end
		end
	end
	log(("stage 1: %d land chunk columns sampled in %.1f s"):format(screened,
		(core.get_us_time() - t0) / 1e6))
	local function best(key, label)
		table.sort(rows, function(p, q)
			if p.m[key] ~= q.m[key] then return p.m[key] > q.m[key] end
			if p.x ~= q.x then return p.x < q.x end
			return p.z < q.z
		end)
		local chosen, checked = nil, 0
		for index = 1, math.min(25, #rows) do
			local row = rows[index]
			local ok, tmin, tmax = ordinary(source, row.x, row.z)
			checked = checked + 1
			local fine = measure(source, row.x, row.z, 8, 2)
			describe(("%s rank %d"):format(label, index), row.x, row.z, fine,
				ok and (" ordinary, full terrain %d..%d"):format(tmin, tmax) or
				" NOT ordinary")
			if ok and not chosen then chosen = {row.x, row.z, fine, tmin, tmax} end
			if chosen and checked >= 8 then break end
		end
		return chosen
	end
	local mountain = best("above", "mountain")
	local ridge = best("ridge", "ridge")
	-- The corpus columns for reference.
	describe("corpus A", 368, -2352, measure(source, 368, -2352, 8, 2))
	describe("corpus B", 528, -2192, measure(source, 528, -2192, 8, 2))
	for _, entry in ipairs({{"MOUNTAIN", mountain}, {"RIDGE", ridge}}) do
		local c = entry[2]
		if c then
			log(("PICK %s x0=%d z0=%d terrain %d..%d mountain top %s"):format(entry[1],
				c[1], c[2], c[4], c[5], tostring(c[3].top)))
		else
			log("PICK " .. entry[1] .. " none")
		end
	end
	log(("done in %.1f s"):format((core.get_us_time() - t0) / 1e6))
	core.request_shutdown("v7pick done", false, 0)
end

core.after(3, function()
	local ok, err = pcall(pick)
	if not ok then
		log("FAILED " .. tostring(err))
		core.request_shutdown("v7pick failed", false, 0)
	end
end)
