-- Round 31 lane M: where can the PvP POIs stand? (LuaJIT, a report)
--
--   luajit tools/r31_m/candidates.lua REPO SEED OUT_FILE
--
-- Builds the world of SEED with its roads as main builds it
-- (tools/r25_road_poi/world.lua) and, for every row of the PvP catalogue
-- (`r31_pvp_catalog.lua`), tests fixed centres on an 8-node grid in the
-- row's zone. A centre passes when
--   * its fitting square plus the zone field's zone margin (24) lies in the
--     row's zone and on dry land (no sea, no lake, no river);
--   * its fitting square keeps 16 nodes off every other anchor's fitting
--     square (a capital's 532 reserved square, a start's 152 town square);
--   * no road of today's network has to bend: the 16-node routing cell
--     under every road point stays 8 nodes outside the round reserve the
--     router keeps free round a POI core (core / 2 + 10, `road_layout.lua`
--     inputs), and the road surface keeps 6 nodes off the blueprint box;
--   * a camp's centre and its core corners stand inside the camp's level
--     band (`r31_pvp_catalog.camp_levels`);
-- and reports the ground's relief under the core (highest minus lowest
-- terrain y, 2-node step) and, for a fortress, how far its walls stand
-- from the middle road (Highcourt - Gor Drazhak). One line per passing
-- centre: `key x z relief road_gap zone_out level_min level_max
-- level_centre wet`. `pick.lua` combines the seeds. ONLY=<key,...> limits
-- the search to some rows.
local repo, seed, out_file = arg[1], arg[2], arg[3]
assert(repo and seed and out_file, "usage: candidates.lua REPO SEED OUT_FILE")
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local catalog = dofile(dir .. "/r31_pvp_catalog.lua")
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
local S, source = W.raw_session, W.source
local column = W.planner_source.column_values_at
local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt

local prof = {}
for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
local zone_index, zone_row = {}, {}
for _, z in ipairs(source.zones) do zone_index[z.id] = z.numeric_id; zone_row[z.id] = z end

local GRID, ZONE_MARGIN, ANCHOR_GAP, ROAD_GAP = 8, 24, 16, 6
-- the blueprint boxes' half sizes (r7_settlement.BOUNDS)
local BOX_HALF = {pvp_fortress = 24, pvp_camp_low = 11, pvp_camp_high = 13}
local DOMAIN = {
	-- the fortresses on the Battlegrounds half of their zone (user ruling
	-- after the first preview: toward the contested middle)
	elandor_ashenward_march = {-448, 448, -760, -344},
	kragmar_bannerbreak_mesa = {-448, 448, 344, 760},
	front_gravesalt_escarpment = {-2560, -1360},
	front_broken_causeway = {-1376, -16},
	front_shattered_line = {16, 1376},
	front_skyglass_canopy = {1360, 2560},
}

-- rasters on the 8-node grid: zone id and dry land
local zone_cache, dry_cache = {}, {}
local function key(x, z) return x * 100000 + z end
local function zone_at(x, z)
	local k = key(x, z)
	local v = zone_cache[k]
	if v == nil then
		v = S.id_at(x, z) or false
		zone_cache[k] = v
	end
	return v
end
local function dry_at(x, z)
	local k = key(x, z)
	local v = dry_cache[k]
	if v == nil then
		-- 1 dry land, 2 inland water (rivers and lakes keep off a POI core,
		-- `water_layout.lua` pois), 3 sea
		local class = S.water_class_at(x, z)
		v = (class == "land" and select(1, column(x, z)) == "land") and 1 or
			(class == "land" or class == "planned_water") and 2 or 3
		dry_cache[k] = v
	end
	return v
end
local height_cache = {}
local function terrain_y(x, z)
	local k = key(x, z)
	local v = height_cache[k]
	if v == nil then
		v = select(6, column(x, z))
		height_cache[k] = v
	end
	return v
end

-- other anchors' fitting squares
local squares = {}
for _, a in ipairs(source.anchors) do
	local p = prof[a.template_id]
	local half = p.fitting_width / 2
	if a.slot_id == "capital" then half = 266 elseif a.slot_id == "start" then half = 76 end
	squares[#squares + 1] = {a.position.x, a.position.z, half}
end
-- road points (every road and trail), densified to at most 4 nodes apart
local road_points = {}
local middle
local hc = S.anchor("elandor_highcourt", "capital")
local gd = S.anchor("kragmar_gor_drazhak", "capital")
for _, r in ipairs(W.built.roads) do
	local is_middle = (r.a == hc.id and r.b == gd.id) or (r.a == gd.id and r.b == hc.id)
	if is_middle then middle = {} end
	for i = 1, #r.X do
		local x1, z1 = r.X[i], r.Z[i]
		local x2, z2 = r.X[i + 1] or x1, r.Z[i + 1] or z1
		local n = max(1, floor(sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1)) / 4))
		for k = 0, n - 1 do
			local px, pz = x1 + (x2 - x1) * k / n, z1 + (z2 - z1) * k / n
			road_points[#road_points + 1] = {px, pz, r.hw or 3, is_middle, r.kind == "trail"}
			if is_middle then middle[#middle + 1] = {px, pz} end
		end
	end
end
assert(middle, "middle road, seed " .. seed)
-- road points in 64-node buckets
local BUCKET = 64
local buckets = {}
for _, q in ipairs(road_points) do
	local k = floor(q[1] / BUCKET) * 1000 + floor(q[2] / BUCKET)
	local list = buckets[k]
	if not list then list = {} buckets[k] = list end
	list[#list + 1] = q
end
local function roads_near(cx, cz, radius)
	local result = {}
	for bz = floor((cz - radius) / BUCKET), floor((cz + radius) / BUCKET) do
		for bx = floor((cx - radius) / BUCKET), floor((cx + radius) / BUCKET) do
			for _, q in ipairs(buckets[bx * 1000 + bz] or {}) do result[#result + 1] = q end
		end
	end
	return result
end

-- The Battlegrounds level field as `simple_map.lua` builds it (D20): each
-- zone's z extent (2 % / 98 % quantiles of its 16-node raster), levels
-- rising in three integer thirds from both edges toward the middle. Here it
-- is evaluated for the row's zone at any z, whoever owns the column today
-- (an anchor's footprint bulges its zone's border out to it).
local level_profile = {}
do
	local z_lists = {}
	for z = -704, 704, 16 do
		for x = -3600, 3600, 16 do
			local id = zone_at(x, z)
			if id and id:match("^front_") then
				local list = z_lists[id] or {}
				z_lists[id] = list
				list[#list + 1] = z
			end
		end
	end
	for id, list in pairs(z_lists) do
		table.sort(list)
		level_profile[id] = {lo = list[floor(#list * 0.02) + 1], hi = list[floor(#list * 0.98) + 1]}
	end
end
local function band_ranges(level_min, level_max)
	local count = level_max - level_min + 1
	local cut1, cut2 = floor(count / 3), floor(count * 2 / 3)
	return {{level_min, level_min + cut1 - 1}, {level_min + cut1, level_min + cut2 - 1},
		{level_min + cut2, level_max}}
end
local function zone_level(zid, z)
	local prof_z, row = level_profile[zid], zone_row[zid]
	local half = (prof_z.hi - prof_z.lo) / 2
	local t = 1 - abs(z - (prof_z.lo + half)) / half
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local ranges = band_ranges(row.level_min, row.level_max)
	local scaled = t * 3
	local band = scaled < 1 and 1 or (scaled < 2 and 2 or 3)
	local range = ranges[band]
	local count = range[2] - range[1] + 1
	local step = floor((scaled - (band - 1)) * count)
	if step >= count then step = count - 1 end
	return range[1] + step
end

local out = assert(io.open(out_file, "w"))
local passed = {}
-- ONLY=<key,key,...> limits the search to those catalogue rows
local only
if os.getenv("ONLY") then
	only = {}
	for key in os.getenv("ONLY"):gmatch("[^,]+") do only[key] = true end
end
local rows = {}
for _, row in ipairs(catalog.rows) do
	if not only or only[row.key] then rows[#rows + 1] = row end
end
for _, row in ipairs(rows) do
	local p = prof[row.kind]
	local core_half, fit_half = p.building_core_width / 2, p.fitting_width / 2
	local zid = row.zone_id
	local z_row = zone_row[zid]
	local d = DOMAIN[zid]
	local x0, x1, z0, z1 = d[1], d[2], d[3], d[4]
	if not z0 then
		if row.faction == "accord" then z0, z1 = -424, -16 else z0, z1 = 16, 424 end
	end
	local lo, hi
	if row.band then lo, hi = catalog.camp_levels(z_row.level_min, z_row.level_max, row.band) end
	-- the road router blocks every routing cell whose centre lies within
	-- core / 2 + 10 of a POI (`road_layout.lua` inputs, `round`): a road
	-- whose cells keep 8 more nodes off keeps its course
	local reserve = core_half + 10 + 8
	local box_half = BOX_HALF[row.kind]
	local count = 0
	for cz = z0, z1, GRID do
		for cx = x0, x1, GRID do
			local ok = true
			-- the core plus 8 nodes in the zone; the rest of the fitting square
			-- plus the zone margin is counted (the zone field bulges a border
			-- out to an anchor's footprint, `zone_field.lua` keypoints)
			local reach = fit_half + ZONE_MARGIN
			local sx0, sz0 = floor((cx - reach) / GRID) * GRID, floor((cz - reach) / GRID) * GRID
			local zone_out = 0
			for z = sz0, cz + reach, GRID do
				for x = sx0, cx + reach, GRID do
					if zone_at(x, z) ~= zid then
						zone_out = zone_out + 1
					end
				end
				if not ok then break end
			end
			if zone_at(floor(cx / GRID) * GRID, floor(cz / GRID) * GRID) ~= zid then ok = false end
			local wet = 0
			if ok then
				for z = sz0, cz + fit_half, GRID do
					for x = sx0, cx + fit_half, GRID do
						local class = dry_at(x, z)
						if class == 3 then ok = false break end
						if class == 2 then wet = wet + 1 end
					end
					if not ok then break end
				end
			end
			if ok then
				for _, q in ipairs(squares) do
					local gap = fit_half + q[3] + ANCHOR_GAP
					if abs(q[1] - cx) < gap and abs(q[2] - cz) < gap then ok = false break end
				end
			end
			if ok then
				for _, q in ipairs(roads_near(cx, cz, reserve + 24)) do
				-- a trail (routed last, to the nearest road) may route round a
				-- fortress; the roads may not
				if not (q[5] and row.kind == "pvp_fortress") then
					-- the 16-node routing cell the road runs through stays outside
					-- the router's round reserve (+ 8 for the smoothing)
					local gx, gz = floor(q[1] / 16 + 0.5) * 16, floor(q[2] / 16 + 0.5) * 16
					local dx, dz = gx - cx, gz - cz
					if dx * dx + dz * dz <= reserve * reserve then ok = false break end
					-- and the road surface keeps ROAD_GAP off the blueprint box
					local bx = max(0, abs(q[1] - cx) - box_half)
					local bz = max(0, abs(q[2] - cz) - box_half)
					if bx * bx + bz * bz < (ROAD_GAP + q[3]) * (ROAD_GAP + q[3]) then
						ok = false break
					end
				end
				end
			end
			local lv_min, lv_max, lv_centre = 0, 0, 0
			if ok and lo then
				lv_centre = zone_level(zid, cz)
				lv_min, lv_max = 999, -1
				for _, dz in ipairs({-core_half, 0, core_half}) do
					local level = zone_level(zid, cz + dz)
					lv_min, lv_max = min(lv_min, level), max(lv_max, level)
				end
			end
			if ok then
				local low, high
				for z = cz - core_half, cz + core_half - 1, 2 do
					for x = cx - core_half, cx + core_half - 1, 2 do
						local y = terrain_y(x, z)
						low = low and min(low, y) or y
						high = high and max(high, y) or y
					end
				end
				local road_gap = -1
				if row.kind == "pvp_fortress" then
					local best = math.huge
					for _, q in ipairs(middle) do
						-- from the walls (the blueprint box, half 24)
						local dx = max(0, abs(q[1] - cx) - 24)
						local dz = max(0, abs(q[2] - cz) - 24)
						best = min(best, sqrt(dx * dx + dz * dz))
					end
					road_gap = floor(best)
				end
				out:write(("%s %d %d %d %d %d %d %d %d %d\n"):format(row.key, cx, cz, high - low,
					road_gap, zone_out, lv_min, lv_max, lv_centre, wet))
				count = count + 1
			end
		end
	end
	passed[#passed + 1] = ("%s %d"):format(row.key, count)
end
out:close()
print(("seed %s: %s"):format(seed, table.concat(passed, ", ")))
