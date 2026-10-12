-- Round 46 lane PL portable test (LuaJIT): seed-dependent POI placement
-- (`wp40/placement.lua`, `placement_rules.lua`) on the real world of one
-- seed (42, built through `world_assembly.lua` as main builds it).
--
--   luajit tools/r46_pl/portable_test.lua [REPO]
--
-- D  determinism: two separate assemblies place the same text; the text
--    round-trips through parse and serialize; the world's source carries
--    exactly the parsed positions; fixed anchors keep their authored ones.
-- N  the split: a fresh height session on the placed source lays out the
--    same inland water and the same natural ground as the placement
--    session on the fixed anchors (no loop through the moving POIs).
-- R  every rule on every placed anchor: in its zone on land (fitting
--    square), dry core and the river guard (F3), relief under the core at
--    most 40, fitting squares 16 apart and 128 from the towns' squares,
--    the kind's spacing (PvP POIs at least 120), the fortress side and the
--    war camps' half, levels and boat gap, the middle-road corridor, the
--    band on step 1, and no last resort on this seed.
-- L  the last resort: a rule no spot can meet (relief below zero) gives
--    every clash site a dry-core place (step 7) and no error; a placed
--    anchor of a kind without rules is refused.
-- U  an underground reservation row: its claim exclusion, its protected
--    floor (placement minus its depth) and its cave rule over its whole
--    width, never the plants on its ground.
-- Z  the zones session answers every placed anchor at its placed position,
--    and the activation roster builds (6 capitals, 24 outposts, 12 camps).
-- C  the layout cache stores and returns the placement section.
-- Prints "R46 PL PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local SEED = "42"
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local floor, abs, max = math.floor, math.abs, math.max
local t0 = os.clock()

local function assembly() return dofile(dir .. "/world_assembly.lua")(dir, sha) end
local A = assembly()
local W = A.world(SEED, nil, {protection = A.square_cities(120), keep_placement_session = true})
local source = W.place()
local P, R = A.placement, A.placement.rules
local text = W.placement_text

-- D
do
	local A2 = assembly()
	local W2 = A2.world(SEED)
	W2.place()
	check(W2.placement_text == text, "D two assemblies place the same text")
	local positions = P.parse(text, A.source)
	check(P.serialize(A.source, positions) == text, "D the text round-trips")
	local placed = 0
	for index, a in ipairs(source.anchors) do
		local authored = A.source.anchors[index]
		if authored.placement_mode == "placed" then
			placed = placed + 1
			local p = positions[a.id]
			check(authored.position == nil and a.position.x == p.x and a.position.z == p.z,
				"D " .. a.id .. " at its parsed position, none authored")
		else
			check(a == authored and a.position ~= nil, "D fixed " .. a.id .. " unchanged")
		end
	end
	check(placed == 98, "D 98 placed anchors")
	check(not pcall(P.parse, text:gsub("\n[^\n]+\n$", "\n"), A.source), "D a truncated text is refused")
end

-- N
local hs, hh = W.placement_session.horizontal, W.placement_session.height
do
	local fresh = {module = dofile(dir .. "/water_layout.lua")(A.terrain_data.water),
		authored = dofile(dir .. "/water_authored.lua")(A.terrain_data.water)}
	local horizontal = W.horizontal_factory({source = source, schemas = A.schemas,
		canonical = A.canonical, deterministic = A.deterministic, raw_sha256 = sha}).new(SEED)
	local height = dofile(dir .. "/height.lua")({source = source, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = sha, horizontal_session = horizontal,
		terrain_field = A.terrain_field, water = fresh,
		start_grounds = A.start_grounds}).new_runtime(SEED)
	check(height.water_layout_text() == hh.water_layout_text(),
		"N the placed source lays out the same water")
	for _, a in ipairs(source.anchors) do
		if a.placement_mode == "placed" then
			for _, o in ipairs({{0, 0}, {37, -21}, {-64, 50}}) do
				local x, z = a.position.x + o[1], a.position.z + o[2]
				check(height.natural_height_at(x, z) == hh.natural_height_at(x, z),
					"N natural ground at " .. a.id)
			end
		end
	end
end

-- R
local profile = {}
for _, p in ipairs(A.source.anchor_profiles) do profile[p.id] = p end
local pvp = dofile(dir .. "/r31_pvp_catalog.lua")
local zone_number = {}
for index, z in ipairs(A.source.zones) do zone_number[z.id] = index end
local pvp_row = {}
for _, row in ipairs(pvp.rows) do pvp_row[zone_number[row.zone_id] .. "/" .. row.slot] = row end
local corridor = {}
for _, id in ipairs(R.CORRIDOR.zones) do corridor[zone_number[id]] = true end
local water = dofile(dir .. "/water_layout.lua")(A.terrain_data.water)
local layout = water.deserialize(hh.water_layout_text())
local function half_of(a)
	if a.slot_id == "capital" then return 266 elseif a.slot_id == "start" then return 76 end
	return profile[a.template_id].fitting_width / 2
end
local BAND = {low = 1, mid = 2, high = 3}
do
	local steps, pvp_list = {}, {}
	for _, a in ipairs(source.anchors) do
		if a.placement_mode == "placed" then
			local rule = R.KINDS[a.template_id]
			local x, z, zone = a.position.x, a.position.z, a.zone_numeric_id
			local core = profile[a.template_id].building_core_width / 2
			local fit = half_of(a)
			check(a.placement_step >= 1 and a.placement_step <= #R.STEPS,
				"R " .. a.id .. " placed by a rule step")
			steps[a.placement_step] = (steps[a.placement_step] or 0) + 1
			for _, c in ipairs({{-fit, -fit}, {fit - 1, -fit}, {-fit, fit - 1}, {fit - 1, fit - 1},
					{0, 0}}) do
				local class, _, owner = hs.classification_values_at(x + c[1], z + c[2])
				check(class == "land" and owner == zone, "R " .. a.id .. " fitting square in its zone")
			end
			local lo, hi = math.huge, -math.huge
			for dz = -core, core - 1, 4 do
				for dx = -core, core - 1, 4 do
					check(hh.inland_water_at(x + dx, z + dz) == nil, "R " .. a.id .. " dry core")
					local y = hh.natural_height_at(x + dx, z + dz)
					lo, hi = math.min(lo, y), max(hi, y)
				end
			end
			check(hi - lo <= 40, "R " .. a.id .. " relief at most 40")
			check(water.wet_core(layout, {{x = x, z = z, r = core * 2 * 0.75}}) == nil,
				"R " .. a.id .. " the river guard (F3)")
			for _, b in ipairs(source.anchors) do
				if b ~= a then
					local gap = max(abs(a.position.x - b.position.x), abs(a.position.z - b.position.z)) -
						fit - half_of(b)
					local town = b.slot_id == "start" or b.slot_id == "capital"
					check(gap >= (town and R.TOWN_GAP or R.ANCHOR_GAP),
						("R %s %d from %s"):format(a.id, gap, b.id))
				end
			end
			if corridor[zone] then
				check(abs(x) >= max(R.CORRIDOR.min, core + R.CORRIDOR.reserve),
					"R " .. a.id .. " off the middle road's axis")
			end
			local prow = pvp_row[zone .. "/" .. a.slot_id]
			if rule.fortress then
				local d = prow.faction == "accord" and x or -x
				check(d >= rule.fortress.min and d <= rule.fortress.max, "R " .. a.id .. " fortress side")
			end
			if rule.camp then
				check((prow.faction == "accord") == (z < 0), "R " .. a.id .. " own half")
				for _, b in ipairs(A.source.boat_paths) do
					local e = b.centreline[1]
					check((x - e.x) * (x - e.x) + (z - e.z) * (z - e.z) >= R.BOAT_GAP * R.BOAT_GAP,
						"R " .. a.id .. " off the boat path's end")
				end
			end
			if rule.pvp then pvp_list[#pvp_list + 1] = a end
			if a.placement_step == 1 then
				local zr = A.source.zones[zone]
				local level = hs.zone_level_at(x, z, zone)
				if rule.camp then
					local lv_lo, lv_hi = pvp.camp_levels(zr.level_min, zr.level_max, prow.band)
					check(level >= lv_lo and level <= lv_hi, "R " .. a.id .. " camp levels")
				elseif zr.level_min ~= zr.level_max then
					local count = zr.level_max - zr.level_min + 1
					local c1, c2 = floor(count / 3), floor(count * 2 / 3)
					local third = level < zr.level_min + c1 and 1 or
						(level < zr.level_min + c2 and 2 or 3)
					check(third == BAND[a.band], "R " .. a.id .. " in its band")
				end
			end
		end
	end
	for i = 1, #pvp_list do
		for j = i + 1, #pvp_list do
			local a, b = pvp_list[i], pvp_list[j]
			local dx, dz = a.position.x - b.position.x, a.position.z - b.position.z
			check(dx * dx + dz * dz >= R.PVP_SPACING_MIN * R.PVP_SPACING_MIN,
				"R PvP spacing " .. a.id .. " " .. b.id)
		end
	end
	local parts = {}
	for step = 1, #R.STEPS do parts[#parts + 1] = step .. ":" .. (steps[step] or 0) end
	print("  steps on seed " .. SEED .. ": " .. table.concat(parts, " "))
end

-- L
do
	local saved = R.KINDS.clash.relief
	R.KINDS.clash.relief = -1
	local ok, positions, stats = pcall(P.place, SEED, A.source, hs, hh)
	R.KINDS.clash.relief = saved
	check(ok, "L an impossible rule is no error: " .. tostring(positions))
	local clashes = 0
	for _, a in ipairs(A.source.anchors) do
		if a.placement_mode == "placed" and a.template_id == "clash" then
			clashes = clashes + 1
			check(positions[a.id].step == R.LAST_RESORT, "L " .. a.id .. " takes the last resort")
		end
	end
	check(#stats.last_resort == clashes and #stats.wet == 0, "L the last resorts are reported")
	local odd = setmetatable({}, {__index = A.source})
	odd.anchors = {}
	for index, a in ipairs(A.source.anchors) do odd.anchors[index] = a end
	odd.anchors[#odd.anchors + 1] = {numeric_id = #odd.anchors + 1, id = "anchor_999",
		zone_numeric_id = 2, slot_id = "odd", template_id = "no_such_kind",
		placement_mode = "placed", band = "mid", pass = 2}
	check(not pcall(P.place, SEED, odd, hs, hh), "L a kind without rules is refused")
end

-- U and Z: the zones session on the world's source with one reservation
do
	local village
	for _, a in ipairs(source.anchors) do
		if not village and a.template_id == "village" then village = a end
	end
	village.underground = {width = 40, depth = 160}
	source.claim_exclusions = A.source.claim_exclusions_of(source.anchors)
	local under_id = ("exclude:anchor:%s:under"):format(village.id)
	local row
	for _, r in ipairs(source.claim_exclusions) do if r.id == under_id then row = r end end
	check(row and row.recipe_id == "exclude_underground_v1" and row.total_width == 40 and
		row.depth == 160, "U the reservation's claim exclusion")
	local session, planner = W.zones().new_with_planner_source_runtime(SEED, 1)
	local anchor = session.anchor(source.zones[village.zone_numeric_id].id, village.slot_id)
	local x, z = village.position.x, village.position.z
	check(planner.protected_floor_at(x, z) == anchor.y - 160, "U the floor is placement - depth")
	check(planner.protected_floor_at(x + 300, z + 300) ~= anchor.y - 160, "U only under the POI")
	-- 16 nodes off the centre: outside the 24-node core, inside the 40 square
	local _, cave_id = planner.static_exclusion_values_at(x + 16, z, "cave")
	check(cave_id == under_id, "U caves stay out of the whole width")
	local _, plant_id = planner.static_exclusion_values_at(x + 16, z, "vegetation")
	check(plant_id ~= under_id, "U plants still grow on its ground")
	for _, a in ipairs(source.anchors) do
		local got = session.anchor(source.zones[a.zone_numeric_id].id, a.slot_id)
		check(got and got.x == a.position.x and got.z == a.position.z, "Z " .. a.id .. " position")
	end
	local roster = dofile(dir .. "/r7_anchor_roster.lua")(source, session, planner, sha)
	local n = {capital = 0, outpost = 0, bandit = 0}
	for _, r in ipairs(roster.rows) do n[r.family] = n[r.family] + 1 end
	check(n.capital == 6 and n.outpost == 24 and n.bandit == 12, "Z the activation roster")
end

-- C
do
	local hex = function(bytes) return common.hex(sha(bytes)) end
	local cache = dofile(dir .. "/layout_cache.lua")({sha256 = hex, list_dir = function() return {} end,
		write = function() return true end, identity = function() return "x" end})
	local parts = cache.key(SEED, "digest", "settings", "interpreter")
	local texts = {placement = text, water = "W", road = "R", capital = "C"}
	local bytes = cache.encode(parts, texts, {seconds = {construction = 1, water = 2, roads = 3,
		capitals = 4, placement = 5}})
	local got = cache.decode(bytes, parts)
	check(got and got.placement == text and got.water == "W" and got.meta.seconds.placement == 5,
		"C the cache keeps the placement section")
	check(cache.FORMAT == "grug_world_layouts_v2", "C the format moved on")
end

print(("R46 PL PORTABLE PASS checks=%d (%.1f s)"):format(checks, os.clock() - t0))
