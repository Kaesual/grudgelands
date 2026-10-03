-- Round 31 lane M: the PvP POI anchors on real worlds (LuaJIT).
--
--   luajit tools/r31_m/spacing_check.lua [REPO] [SEED ...]
--
-- The anchors themselves (seed-independent, checked once):
--   1. anchors 101..118 are the catalogue's rows in order (zone, slot,
--      template = kind);
--   2. no two PvP POIs (fortresses and camps, either faction) stand closer
--      than SPACING (120) nodes, centre to centre (pvp-plan ruling 21);
--   3. every PvP anchor's fitting square keeps 16 nodes off every other
--      anchor's fitting square (a capital's 532 reserved square, a start's
--      152 town square), and 128 nodes off a boat path's mainland end.
-- Per SEED (default: the six quest-lane seeds 42 7 2026 1234 99999 314159)
-- the world with its roads is built as main builds it
-- (tools/r25_road_poi/world.lua) and:
--   4. the zone field passes its self-check at full warp (no fallback);
--   5. every road of the network routes;
--   6. every PvP anchor stands in its own zone: its fitting square lies in
--      the zone and on land (the zone field's own keypoint test), its core
--      is dry (no lake or river) and fitted flat;
--   7. no road or trail surface comes within ROAD_GAP (6) nodes of what a
--      PvP POI builds (its blueprint box, `r7_settlement.BOUNDS`);
--   8. each fortress stands beside the middle road (Highcourt - Gor
--      Drazhak): the road passes within NEAR (48) nodes of its walls;
--   9. each camp's centre lies within its level band (`camp_levels`) give or
--      take one level (a rough fit; the strict hits are reported);
--  10. the world protection covers each PvP POI's blueprint box plus the
--      10-node margin (kind "fortress" or "camp" 10 nodes out, nothing
--      else 12 nodes out on at least two sides away from roads).
-- Prints per seed each POI's fitted height, its level (camps) or the middle
-- road's distance (fortresses) and the strict level hits, then
-- "R31 M SPACING PASS checks=<n>", or raises.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"42", "7", "2026", "1234", "99999", "314159"} end
local SPACING, ANCHOR_GAP, BOAT_GAP, ROAD_GAP, NEAR = 120, 16, 128, 6, 48
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(dir .. "/source/simple_map.lua")
local catalog = dofile(dir .. "/r31_pvp_catalog.lua")
_G.core = _G.core or {}
local BOUNDS = dofile(dir .. "/r7_settlement.lua").BOUNDS
local prof, zone_by_id = {}, {}
for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
for _, z in ipairs(source.zones) do zone_by_id[z.id] = z end

-- 1-3: the anchors
check(#source.anchors == 100 + #catalog.rows, "118 anchors")
local pvp = {}
for i, row in ipairs(catalog.rows) do
	local a = source.anchors[100 + i]
	check(a.zone_numeric_id == zone_by_id[row.zone_id].numeric_id and a.slot_id == row.slot and
		a.template_id == row.kind, row.key .. ": anchor " .. (100 + i))
	pvp[i] = {row = row, anchor = a, x = a.position.x, z = a.position.z,
		core_half = prof[row.kind].building_core_width / 2,
		box_half = BOUNDS[row.kind].max.x,
		fit_half = prof[row.kind].fitting_width / 2}
end
local nearest = math.huge
for i = 1, #pvp do
	for j = i + 1, #pvp do
		local dx, dz = pvp[i].x - pvp[j].x, pvp[i].z - pvp[j].z
		local d = sqrt(dx * dx + dz * dz)
		nearest = min(nearest, d)
		check(d >= SPACING, ("%s and %s %.0f nodes apart"):format(pvp[i].row.key, pvp[j].row.key, d))
	end
end
for _, p in ipairs(pvp) do
	for _, a in ipairs(source.anchors) do
		if a ~= p.anchor then
			local half = prof[a.template_id].fitting_width / 2
			if a.slot_id == "capital" then half = 266 elseif a.slot_id == "start" then half = 76 end
			local gap = max(abs(a.position.x - p.x), abs(a.position.z - p.z)) - half - p.fit_half
			check(gap >= ANCHOR_GAP, ("%s keeps %d nodes off %s (%d)"):format(p.row.key, ANCHOR_GAP,
				a.id, gap))
		end
	end
	for _, b in ipairs(source.boat_paths) do
		local e = b.centreline[1]
		local dx, dz = e.x - p.x, e.z - p.z
		check(dx * dx + dz * dz >= BOAT_GAP * BOAT_GAP, p.row.key .. " keeps off " .. b.id)
	end
end
print(("anchors: 18 PvP POIs, nearest pair %.0f nodes"):format(nearest))

-- 4-10: the worlds
local log_lines = {}
_G.core = _G.core or {}
core.log = function(level, message) log_lines[#log_lines + 1] = {level, message} end
local world = dofile(repo .. "/tools/r25_road_poi/world.lua")
for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	log_lines = {}
	local W = world(repo, seed)
	local S, column = W.raw_session, W.planner_source.column_values_at
	local field_line
	for _, line in ipairs(log_lines) do
		if line[2]:find("zone field: warp scale", 1, true) then field_line = line end
	end
	check(field_line and field_line[1] == "action" and field_line[2]:find("warp scale 1.0", 1, true),
		"zone field at full warp, seed " .. seed .. " (" .. tostring(field_line and field_line[2]) .. ")")
	check(not W.built.stats.failed, "every road routes, seed " .. seed)
	local hc = S.anchor("elandor_highcourt", "capital")
	local gd = S.anchor("kragmar_gor_drazhak", "capital")
	local middle
	for _, r in ipairs(W.built.roads) do
		if (r.a == hc.id and r.b == gd.id) or (r.a == gd.id and r.b == hc.id) then middle = r end
	end
	check(middle, "middle road, seed " .. seed)
	local parts = {}
	local strict = 0
	for _, p in ipairs(pvp) do
		local row, label = p.row, p.row.key .. ", seed " .. seed
		local a = S.anchor(row.zone_id, row.slot)
		check(a and a.x == p.x and a.z == p.z, label .. ": session anchor")
		-- 6. zone, land, dry flat core
		for z = p.z - p.fit_half, p.z + p.fit_half - 1, 8 do
			for x = p.x - p.fit_half, p.x + p.fit_half - 1, 8 do
				check(S.id_at(x, z) == row.zone_id, ("%s: (%d,%d) in zone"):format(label, x, z))
			end
		end
		for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
			local x, z = p.x + c[1] * (p.fit_half - 1), p.z + c[2] * (p.fit_half - 1)
			check(S.water_class_at(x, z) ~= "deep_ocean" and S.water_class_at(x, z) ~= "coastal_shelf",
				label .. ": fitting corner on land")
		end
		for z = p.z - p.core_half, p.z + p.core_half - 1, 2 do
			for x = p.x - p.core_half, p.x + p.core_half - 1, 2 do
				local class, _, _, _, _, terrain_y = column(x, z)
				check(class == "land" and terrain_y == a.y,
					("%s: core (%d,%d) dry and flat (%s, %s vs %d)"):format(label, x, z,
						tostring(class), tostring(terrain_y), a.y))
			end
		end
		-- 7. roads keep off what the POI builds
		local near_middle = math.huge
		for _, r in ipairs(W.built.roads) do
			for i = 1, #r.X - 1 do
				local x1, z1, x2, z2 = r.X[i], r.Z[i], r.X[i + 1], r.Z[i + 1]
				local n = max(1, floor(sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1)) / 2))
				for k = 0, n do
					local x, z = x1 + (x2 - x1) * k / n, z1 + (z2 - z1) * k / n
					local dx = max(0, abs(x - p.x) - p.box_half)
					local dz = max(0, abs(z - p.z) - p.box_half)
					local d = sqrt(dx * dx + dz * dz) - (r.hw or 1.5)
					check(d >= ROAD_GAP, ("%s: road %s keeps %d off the POI (%.1f)"):format(label,
						tostring(r.id), ROAD_GAP, d))
					if r == middle then near_middle = min(near_middle, d) end
				end
			end
		end
		-- 8. fortress beside the middle road
		if row.kind == "pvp_fortress" then
			check(near_middle <= NEAR, ("%s: the middle road passes %.0f nodes off the walls"):format(
				label, near_middle))
		end
		-- 9. level band
		local level = S.surface_mob_level_at(p.x, p.z)
		if row.band then
			local zr = zone_by_id[row.zone_id]
			local lo, hi = catalog.camp_levels(zr.level_min, zr.level_max, row.band)
			check(level >= lo - 1 and level <= hi + 1, ("%s: level %d near %d-%d"):format(label,
				level, lo, hi))
			if level >= lo and level <= hi then strict = strict + 1 end
		end
		-- 10. protection with the margin
		local kind = row.kind == "pvp_fortress" and "fortress" or "camp"
		local kind_at = W.protection.kind_at
		check(kind_at(p.x, a.y + 1, p.z) == kind, label .. ": core protected as " .. kind)
		local edge = p.box_half
		local open_sides = 0
		for _, c in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x9, z9 = p.x + c[1] * (edge + 10), p.z + c[2] * (edge + 10)
			check(kind_at(x9, a.y + 1, z9) == kind, ("%s: protected 10 beyond the box (%d,%d)")
				:format(label, x9, z9))
			local k12 = kind_at(p.x + c[1] * (edge + 12), a.y + 1, p.z + c[2] * (edge + 12))
			check(k12 ~= kind, label .. ": the margin ends")
			if k12 == nil then open_sides = open_sides + 1 end
		end
		check(open_sides >= 2, label .. ": open ground beyond the margin")
		parts[#parts + 1] = ("%s y%d%s%s"):format(row.key:gsub("^pvp_", ""):gsub("_escarpment", "")
			:gsub("_causeway", ""):gsub("_line", ""):gsub("_canopy", ""), a.y,
			row.band and (" L" .. level) or "",
			row.kind == "pvp_fortress" and (" road+" .. floor(near_middle)) or "")
	end
	print(("seed %s: %.1f s, camps in band %d of 16; %s"):format(seed, os.clock() - t0, strict,
		table.concat(parts, ", ")))
end
print(("R31 M SPACING PASS checks=%d"):format(checks))
