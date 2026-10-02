-- Round 28 Lane S1 portable test (LuaJIT): rule-based spawn regions.
--
--   luajit tools/r28_s1/portable_test.lua [REPO]
--
-- A. The pure builder (mods/ENTITIES/grug_mobs/spawn_regions_core.lua) on a
--    synthetic world, through the real query adapter (core.queries):
--    determinism, every land cell in exactly one region, belt shares and a
--    belt's max_from, adjacent regions at most one belt apart, terrain types
--    (shore, bank, swamp, forest, highland) and the explicit parent rule,
--    region sizes, camp rules, leaders (camp centre, farthest from roads,
--    level at the top), the region at a coast fringe, recipe errors (shares,
--    open entry, ids, rosters, levels never meeting, leader flag, references,
--    unknown keys), compass words and the describe phrasings (of / from /
--    zone, near, heart).
-- B. The game module (spawn_regions.lua with the real spawn_policy.lua,
--    density.lua, camps.lua and roam_avoid.lua under stubs) with the SHIPPED
--    Dawnmere recipe on the same synthetic world: a zone without a recipe
--    keeps its palette, the spawner end to end (kind tag, spawn clock, level
--    in the role's range, roster by clock, shore host for crabs, protected
--    ground, light), the drift band (aggressive refused, neutral allowed),
--    density classes (sparse / normal / dense shares of the budget, refill),
--    recipe camps (first fill, respawn window, levels, radius), leaders
--    (spot, level, never saved, 24-node clearance, 300 s after a kill), the
--    level overlay, the quest seams (get_area, area_roles, zone_area_ids,
--    leader), describe and direction. The leader's 1.15 size and 2x HP are
--    checked with the real registration in tools/r28_b2/portable_test.lua;
--    here levels.lua's HP factor.
-- Prints "R28 S1 PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
local CORE = dofile(MOBS .. "/spawn_regions_core.lua")

local function read(path)
	local f = assert(io.open(path, "rb"))
	local t = f:read("*a")
	f:close()
	return t
end

-- ---------------------------------------------------------------------------
-- The synthetic world (both parts)
-- ---------------------------------------------------------------------------
-- Zone DAWN: x in [-640, 640), z in [-2880, -2240) (40 x 20 cells). North of
-- it Goldmead (land). South (z < -2880): open sea, nobody's. West (x < -640):
-- bay water the zone owns. East (x >= 640): open sea. A lake (inland water)
-- at x -320..-289, z -2700..-2601. Swamp west of x = -400, a forest at
-- x 300..499, z -2500..-2301, a hill round (-200, -2350). A road from the
-- town north to Goldmead; the start town is a 128-node hard-protected pad.
local DAWN, GOLD = "elandor_dawnmere_fields", "elandor_goldmead_vale"
local START = {x = 0, y = 20, z = -2550}
local W = {}
function W.zone_at(x, z)
	if z >= -2240 and z < -1800 and x >= -640 and x < 640 then return GOLD end
	if z < -2880 or x >= 640 then return nil end
	if x < -640 and x >= -800 and z >= -2880 and z < -2240 then return DAWN end
	if x >= -640 and z >= -2880 and z < -2240 then return DAWN end
	return nil
end
function W.water_class_at(x, z)
	if z < -2880 or x >= 640 then return "deep_ocean" end
	if x < -640 then return "planned_water" end
	if x >= -320 and x < -288 and z >= -2700 and z < -2600 then return "planned_water" end
	return "land"
end
function W.inland(x, z)
	return x >= -320 and x < -288 and z >= -2700 and z < -2600
end
function W.biome_at(x, z)
	if x < -400 then return "grug_swamp" end
	if x >= 300 and x < 500 and z >= -2500 and z < -2300 then return "grug_deep_forest" end
	return "grug_meadows"
end
function W.height_at(x, z)
	local dx, dz = x + 200, z + 2350
	if dx * dx + dz * dz < 80 * 80 then return 70 end
	return 20
end
function W.protection(pos)
	if math.abs(pos.x - START.x) <= 64 and math.abs(pos.z - START.z) <= 64 then return "town" end
	return nil
end
local ROADS = {{kind = "road", points = {{x = 0, z = -2550}, {x = 0, z = -2400},
	{x = 0, z = -2240}, {x = 0, z = -1900}}}}
local SOURCE = {zones = {{id = DAWN, numeric_id = 6}, {id = GOLD, numeric_id = 7}},
	anchors = {{id = "anchor_002", zone_numeric_id = 6, slot_id = "start"}}}
local ZONES = {
	id_at = W.zone_at,
	water_class_at = W.water_class_at,
	terrain_height_at = W.height_at,
	biome_at = W.biome_at,
	hard_protection_kind_at = W.protection,
	anchor = function(zone, slot)
		if zone == DAWN and slot == "start" then
			return {x = START.x, y = START.y, z = START.z, id = "anchor_002"}
		end
		return nil
	end,
	get = function(zone)
		if zone == DAWN then
			return {hub = {x = 0, z = -2550}, level_min = 1, level_max = 10,
				display_name = "Dawnmere Fields", macro_region = "elandor_mainland"}
		end
		if zone == GOLD then
			return {hub = {x = 0, z = -2050}, level_min = 11, level_max = 20,
				display_name = "Goldmead Vale", macro_region = "elandor_mainland"}
		end
		return nil
	end,
	mob_level_at = function() return 5 end,
	surface_mob_level_at = function() return 5 end,
}
local function column_values_at(x, z)
	local river = W.inland(x, z) and "lake:test" or nil
	return W.water_class_at(x, z), nil, nil, nil, nil, W.height_at(x, z), nil, river
end

-- The catalogue's levels and leader flags (the real file).
local CATALOGUE = {}
do
	local data = json.parse(read(MOBS .. "/data/subtypes.json"))
	if not data[1] then data = data.subtypes end
	for _, row in ipairs(data) do CATALOGUE[row.role] = row end
end
local CTX = {band = {1, 10},
	role_levels = function(role) return CATALOGUE[role] and CATALOGUE[role].levels end,
	leader = function(role) return CATALOGUE[role] ~= nil and CATALOGUE[role].leader == true end}

-- ---------------------------------------------------------------------------
-- A. The builder
-- ---------------------------------------------------------------------------
local function roster(role, weight) return {{role = role, weight = weight or 1}} end
local function base_recipe()
	return {
		from = {anchor = "start"},
		to = {border = GOLD},
		belts = {
			{id = "ring", share = 10, levels = {1, 2}, max_from = 160, kinds = {
				open = {id = "home", name = "Home", day = roster("small_boar"),
					night = roster("large_rat"), density = "normal"}}},
			{id = "mid", share = 40, levels = {3, 4}, kinds = {
				open = {id = "meadow", name = "Meadow", day = roster("small_boar"),
					night = roster("large_rat"), density = "normal"},
				shore = {id = "beach", name = "Beach", day = roster("quiet_shore_crab"),
					night = roster("braindead_zombie"), density = "dense"},
				swamp = {id = "reeds", name = "Reeds", day = "open",
					night = roster("braindead_zombie"), density = "sparse"}}},
			{id = "far", share = 50, levels = {8, 10}, kinds = {
				open = {id = "border", name = "Border", day = roster("aggressive_boar"),
					night = roster("monstrous_rat"), density = "normal"},
				forest = {id = "woods", name = "Woods", day = roster("aggressive_boar"),
					night = roster("drowned_zombie"), density = "normal"}}},
		},
		camps = {{id = "camp", name = "Camp", belt = "far", roster = roster("confused_bandit"),
			slots = 6, respawn = {30, 60}, min_player_distance = 16, apart = 8}},
		leaders = {{role = "confused_bandit_chief", at = {camp = "camp"}, respawn = 300}},
		critters = {"rabbit"},
	}
end
local function deep_copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deep_copy(v) end
	return out
end
local Q = CORE.queries({zones = ZONES, column_values_at = column_values_at,
	road_polylines = ROADS, source = SOURCE})
check(Q.water_at(0, -2550) == "land" and Q.water_at(-700, -2550) == "sea" and
	Q.water_at(-300, -2650) == "inland" and Q.water_at(0, -3000) == "sea", "adapter water classes")
check(Q.biome_at(-500, -2500) == "swamp", "adapter strips the grug_ prefix")
local recipe = CORE.parse_recipe(DAWN, base_recipe(), CTX)
local map = CORE.build(DAWN, Q, recipe)
local map2 = CORE.build(DAWN, Q, CORE.parse_recipe(DAWN, base_recipe(), CTX))

-- Determinism: the same world and recipe give the same map.
local function fingerprint(m)
	local rows = {}
	for _, c in ipairs(m.order) do
		rows[#rows + 1] = ("%d,%d:%d:%d:%s:%s"):format(c.i, c.j, c.region.id, c.belt, c.type, c.kind.id)
	end
	for _, r in ipairs(m.regions) do rows[#rows + 1] = ("r%d:%s:%d"):format(r.id, r.kind.id, r.size) end
	for _, l in ipairs(m.leaders) do rows[#rows + 1] = ("L%s:%d,%d:%d"):format(l.role, l.x, l.z, l.level) end
	return table.concat(rows, ";")
end
check(fingerprint(map) == fingerprint(map2), "determinism: same world and recipe, same map")

-- Cells: 40 x 20 land cells (the lake and the bay are water; the bay is the
-- zone's own sea, so its cells are not land).
local land = 0
for x = -640, 608, 32 do
	for z = -2880, -2272, 32 do
		local water = 0
		for a = 0, 3 do for b = 0, 3 do
			if W.water_class_at(x + 4 + 8 * a, z + 4 + 8 * b) ~= "land" then water = water + 1 end
		end end
		if water <= 8 then land = land + 1 end
	end
end
check(#map.order == land, ("land cells %d (expected %d)"):format(#map.order, land))
local in_regions = 0
for _, r in ipairs(map.regions) do
	for _, c in ipairs(r.cells) do
		check(c.region == r and c.kind == r.kind, "a cell's region and kind agree")
		in_regions = in_regions + 1
	end
end
check(in_regions == #map.order, "every land cell lies in exactly one region")
for _, c in ipairs(map.order) do check(map.cells[CORE.key(c.i, c.j)] == c, "cell index") end

-- Belts.
local stats = CORE.stats(map)
local n = #map.order
check(stats.belts[1].cells <= math.floor(0.10 * n + 0.5), "ring at most its share")
for _, c in ipairs(map.order) do
	if c.belt == 1 then check(c.d_from * 32 <= 160 + 1e-9, "ring cells within max_from") end
end
check(math.abs(stats.belts[3].cells - 0.5 * n) <= 0.03 * n, "far belt near its 50 % (" ..
	stats.belts[3].cells .. " of " .. n .. ")")
check(stats.max_belt_jump <= 1, "adjacent regions at most one belt apart")
for _, c in ipairs(map.order) do
	for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1}}) do
		local nb = map.cells[CORE.key(c.i + o[1], c.j + o[2])]
		check(not nb or math.abs(nb.belt - c.belt) <= 1, "neighbour cells at most one belt apart")
	end
end
-- Progress rises from the town (0) toward the border (1).
local town = map.cells[CORE.key(0, math.floor(-2550 / 32))]
check(town and town.progress == 0 and town.belt == 1, "the town cell starts the ring")
local north = map.cells[CORE.key(0, math.floor(-2260 / 32))]
check(north and north.progress > 0.9 and north.belt == 3, "the border cell is in the last belt")

-- Types and the parent rule.
local function cell_at(x, z) return map.cells[CORE.key(math.floor(x / 32), math.floor(z / 32))] end
check(cell_at(0, -2870).type == "shore", "a cell on the south coast is shore")
check(cell_at(-630, -2500).type == "shore", "the bay coast is shore too")
check(cell_at(-340, -2650).type == "bank", "a cell beside the lake is bank")
check(cell_at(-500, -2400).type == "swamp", "swamp biome cell")
check(cell_at(400, -2400).type == "forest", "forest biome cell")
check(cell_at(-200, -2350).type == "highland", "the hill is highland")
check(cell_at(200, -2700).type == "open", "open ground")
local bank_cell = cell_at(-340, -2650)
check(bank_cell.kind == recipe.belts[bank_cell.belt].kinds.open or bank_cell.camp,
	"bank cell (no bank entry) gets its belt's open kind")
for _, c in ipairs(map.order) do
	local belt = recipe.belts[c.belt]
	if not c.camp then
		local own = belt.kinds[c.type]
		-- merged fragments carry their host region's kind
		check(c.kind == c.region.kind, "cell kind is its region's")
		if own == nil and c.kind.belt == belt then
			check(c.kind == belt.kinds.open or c.kind ~= own, "parent rule")
		end
	end
end
-- Inheritance by clock ("open").
local reeds = recipe.kind_by_id.reeds
check(reeds.rosters.day == recipe.kind_by_id.meadow.rosters.day and reeds.inherits.day and
	reeds.rosters.night.list[1].role == "braindead_zombie", "day \"open\" inherits the open roster")

-- Region sizes.
for _, r in ipairs(map.regions) do
	if not r.camp then
		check(r.size <= CORE.MAX_CELLS, "no region above the maximum (" .. r.size .. ")")
	end
end
local small = 0
for _, r in ipairs(map.regions) do
	if not r.camp and r.size < CORE.MIN_CELLS and r.kind.type ~= "shore" then small = small + 1 end
end
check(small == 0, "no non-shore fragment below the minimum")

-- Camp.
check(#map.camps == 1, "the camp is placed")
local camp = map.camps[1]
check(camp.cell.belt == 3, "camp in its belt")
check(camp.region.size == 9 and camp.region.kind == recipe.camp_by_id.camp, "camp region 3x3")
for a = -1, 1 do
	for b = -1, 1 do
		local c = map.cells[CORE.key(camp.cell.i + a, camp.cell.j + b)]
		check(c and c.camp == camp and c.prot == 0 and c.drift == 0 and c.road >= CORE.CAMP_ROAD_MIN,
			"camp block: land, unprotected, outside the drift band, 48+ from roads")
	end
end
check(math.abs(camp.x) >= 48, "camp away from the road")
-- Leaders: at the camp centre, level at the top of the camp's range.
check(#map.leaders == 1 and map.leaders[1].x == math.floor(camp.x) and map.leaders[1].z == math.floor(camp.z)
	and map.leaders[1].level == 10, "leader at the camp centre, level 10")
-- A leader picked farthest from roads in the largest region of a kind.
do
	local r = base_recipe()
	r.leaders[2] = {role = "confused_bandit_chief", at = {kind = "border", pick = "farthest_from_roads"},
		respawn = 300}
	check(not pcall(CORE.parse_recipe, DAWN, r, CTX), "a leader role is placed once")
	r.leaders = {{role = "confused_bandit_chief", at = {kind = "border", pick = "farthest_from_roads"},
		respawn = 300}}
	local m = CORE.build(DAWN, Q, CORE.parse_recipe(DAWN, r, CTX))
	local l = m.leaders[1]
	local largest
	for _, reg in ipairs(m.by_kind.border) do
		if not largest or reg.size > largest.size then largest = reg end
	end
	check(l.region == largest, "leader in the largest region of its kind")
	local best = 0
	for _, c in ipairs(largest.cells) do best = math.max(best, c.road) end
	local lc = m.cells[CORE.key(math.floor(l.x / 32), math.floor(l.z / 32))]
	check(lc.road == best and l.level == 10, "leader on the cell farthest from roads, top level")
end
-- No camp spot: reported, not fatal; the camp's leader still stands, in the
-- camp's belt (Round 28 S2c: a named leader stands on every seed).
do
	local r = base_recipe()
	-- A second camp that must keep 100 cells from the first finds no spot.
	r.camps[2] = deep_copy(r.camps[1])
	r.camps[2].id, r.camps[2].apart = "camp2", 100
	r.leaders = {{role = "confused_bandit_chief", at = {camp = "camp2"}, respawn = 300}}
	local m = CORE.build(DAWN, Q, CORE.parse_recipe(DAWN, r, CTX))
	local l = m.leaders[1]
	check(#m.camps == 1 and #m.problems == 1 and m.problems[1]:find("no valid camp cell for camp2", 1, true),
		"no valid camp cell is a reported problem")
	check(l and l.fallback == "border" and l.region.belt == 3 and l.level == 10,
		"the camp's leader falls back to its camp's belt")
end

-- The region at a point: its cell, else the nearest land cell around it.
check(map.region_at(0, -2700) == cell_at(0, -2700).region, "region at a land point")
check(map.region_at(-650, -2500) ~= nil, "a fringe point in a water cell takes its neighbour's region")
check(map.region_at(0, -3100) == nil, "open sea has no region")

-- Recipe errors.
local function refused(mutate, pattern, label)
	local r = base_recipe()
	mutate(r)
	local ok, err = pcall(CORE.parse_recipe, DAWN, r, CTX)
	check(not ok and tostring(err):find(pattern, 1, true), label .. " (" .. tostring(err) .. ")")
end
refused(function(r) r.belts[3].share = 40 end, "add up to 100", "shares must add up to 100")
refused(function(r) r.belts[2].kinds.open = nil end, "kinds.open", "every belt defines open")
refused(function(r) r.belts[2].kinds.cave = r.belts[2].kinds.shore end, "not a terrain type", "unknown type")
refused(function(r) r.belts[3].kinds.forest.id = "meadow" end, "used twice", "duplicate kind id")
refused(function(r) r.belts[2].kinds.open.day = {{role = "small_boar", weight = 2},
	{role = "large_rat", weight = 1}} end, "minor role", "minor role above 25 %")
refused(function(r) r.belts[2].kinds.open.day = {{role = "small_boar", weight = 8},
	{role = "large_rat", weight = 1}, {role = "small_fox", weight = 1}} end, "at most one minor",
	"three roles")
refused(function(r) r.belts[2].kinds.open.day = "open" end, "names the parent", "open kind cannot inherit")
refused(function(r) r.belts[2].kinds.open.night = nil end, "needs a night roster", "missing roster")
refused(function(r) r.belts[1].kinds.open.day = roster("aggressive_boar") end, "never meets",
	"empty level intersection")
refused(function(r) r.belts[3].levels = {8, 12} end, "leave the zone's band", "belt outside the band")
refused(function(r) r.belts[2].kinds.open.density = "packed" end, "density", "density class")
refused(function(r) r.leaders[1].role = "confused_bandit" end, "does not mark", "leader flag")
refused(function(r) r.leaders[1].at = {camp = "nowhere"} end, "not a camp", "unknown camp")
refused(function(r) r.leaders[1].at = {kind = "nope", pick = "farthest_from_roads"} end, "not a kind",
	"unknown kind")
refused(function(r) r.camps[1].belt = "outer" end, "not a belt", "camp belt reference")
refused(function(r) r.camps[1].id = "meadow" end, "unique among kinds and camps", "camp id clash")
refused(function(r) r.belts[1].radius = 3 end, "unknown field radius", "unknown key")
refused(function(r) r.to = {border = DAWN} end, "other zones", "border with itself")
-- Coverage: every kind covers its whole belt at each clock, a camp has no gap
-- and reaches its belt's top, the last belt ends at the zone band's top.
refused(function(r) r.belts[2].levels = {3, 6} end, "kinds.open.day: roles cover L3-4 of the belt's L3-6",
	"a roster that stops below the belt's top")
refused(function(r)
	r.belts[3].levels = {5, 10}
	r.belts[3].kinds.open.day = {{role = "small_fox", weight = 3}, {role = "confused_bandit", weight = 1}}
end, "roles cover L5-7, L9-10 of the belt's L5-10", "a gap inside the belt")
refused(function(r)
	r.belts[3].levels = {5, 10}
	r.belts[3].kinds.open.day = roster("aggressive_boar")
end, "kinds.open.night: roles cover L7-10 of the belt's L5-10", "a roster that starts above the belt's bottom")
refused(function(r)
	r.belts[3].levels = {5, 10}
	r.belts[3].kinds = {open = {id = "border", name = "Border", day = roster("aggressive_boar"),
		night = roster("aggressive_boar"), density = "normal"}}
	r.camps[1].roster = roster("small_fox")
end, "a camp has no gap and reaches its belt's top", "a camp below its belt's top")
refused(function(r) r.belts[3].levels = {8, 9} end, "the last belt ends at L9, the zone's band at L10",
	"the last belt ends below the band's top")
check(pcall(CORE.parse_recipe, DAWN, base_recipe(), CTX), "a camp may start above its belt's bottom (L9-10 in L8-10)")
do
	-- The shipped Dawnmere recipe covers every belt at both clocks.
	local shipped = json.parse(read(MOBS .. "/data/zones/" .. DAWN .. ".spawns.json"))
	local ok, err = pcall(CORE.parse_recipe, DAWN, shipped.recipe, CTX)
	check(ok, "the shipped Dawnmere recipe passes the cover rule: " .. tostring(err))
	local tide = ok and err.kind_by_id.tideflats
	check(tide and tide.levels[1] == 5 and tide.levels[2] == 7 and
		tide.levels_by_role.quiet_shore_crab[2] == 6 and tide.levels_by_role.giant_crab[1] == 7,
		"Tideflats by day: Small Crab 5-6 and Monstrous Crab 7")
	for _, id in ipairs({"borderlands", "wreck_coast", "darkwood", "fen"}) do
		local kind = ok and err.kind_by_id[id]
		check(kind and kind.levels[1] == 8 and kind.levels[2] == 10, id .. " covers L8-10")
	end
end
refused(function(r) r.from = nil end, "from", "from is required")
check(not pcall(CORE.build, DAWN, Q, CORE.parse_recipe(DAWN,
	(function() local r = base_recipe(); r.from = {anchor = "capital"}; return r end)(), CTX)),
	"a from anchor the zone lacks fails the build")
do
	local r = base_recipe()
	r.to = {border = "elandor_highcourt"}
	local ok, err = pcall(CORE.build, DAWN, Q, CORE.parse_recipe(DAWN, r, CTX))
	check(not ok and tostring(err):find("no land border", 1, true), "a border the zone does not have")
end
-- Levels: belt range x role range.
local meadow = recipe.kind_by_id.meadow
check(meadow.levels_by_role.small_boar[1] == 3 and meadow.levels_by_role.small_boar[2] == 4,
	"small boar 1-4 meets belt 3-4 at 3-4")
local beach = recipe.kind_by_id.beach
check(beach.levels_by_role.quiet_shore_crab[1] == 3 and beach.levels_by_role.quiet_shore_crab[2] == 4 and
	beach.levels[1] == 3 and beach.levels[2] == 4, "kind levels are the union over its roles")
check(recipe.camp_by_id.camp.levels[1] == 9 and recipe.camp_by_id.camp.levels[2] == 10, "camp levels 9-10")

-- Compass and describe.
check(CORE.compass(0, 0, 0, 10) == "north" and CORE.compass(0, 0, 10, 10) == "northeast" and
	CORE.compass(0, 0, 10, 0) == "east" and CORE.compass(0, 0, 10, -10) == "southeast" and
	CORE.compass(0, 0, 0, -10) == "south" and CORE.compass(0, 0, -10, -10) == "southwest" and
	CORE.compass(0, 0, -10, 0) == "west" and CORE.compass(0, 0, -10, 10) == "northwest",
	"eight compass words, +z north")
check(CORE.compass(0, 0, 3, 10) == "north" and CORE.compass(0, 0, 5, 10) == "northeast", "sector edges")
local town_ref = {x = 0, z = -2550, name = "Dawnmere"}
local d = CORE.describe(map, "camp", "of", town_ref)
check(d and d.phrase == d.dir .. " of Dawnmere" and d.phrase_key == "dir_of" and d.distance > CORE.NEAR,
	"describe of a place")
check(d.dir == CORE.compass(0, -2550, camp.x, camp.z), "the camp's direction from the town")
local f = CORE.describe(map, "confused_bandit_chief", "from", {x = 5, z = -2540})
check(f.phrase == f.dir .. " from here" and f.phrase_key == "dir_from_here", "describe from the giver")
local near = CORE.describe(map, "camp", "from", {x = camp.x + 10, z = camp.z})
check(near.phrase == "nearby" and near.dir == nil and near.phrase_key == "nearby", "nearby below NEAR")
local near_of = CORE.describe(map, "camp", "of", {x = camp.x, z = camp.z + 20, name = "Old Mill"})
check(near_of.phrase == "near Old Mill" and near_of.phrase_key == "near", "near a place")
local zone_phrase = CORE.describe(map, "camp", "zone", nil, "Dawnmere Fields")
check(zone_phrase.phrase == "in the " .. zone_phrase.dir .. " of Dawnmere Fields", "within the zone")
do
	-- A kind whose largest region sits on the zone's centre: "in the heart of".
	local fr = CORE.zone_frame(map)
	local fake = {order = map.order, leaders = {}, camps = {},
		by_kind = {mid = {{size = 9, x = fr.x + 5, z = fr.z - 5}}}, frame = fr}
	local h = CORE.describe(fake, "mid", "zone", nil, "Dawnmere Fields")
	check(h.phrase == "in the heart of Dawnmere Fields" and h.phrase_key == "zone_heart", "heart of the zone")
end
check(CORE.describe(map, "nothing", "zone") == nil, "unknown target")
-- A kind points at its largest region, in every phrasing.
do
	local largest
	for _, r in ipairs(map.by_kind.meadow) do
		if not largest or r.size > largest.size then largest = r end
	end
	local t = CORE.target_of(map, "meadow")
	check(t.region == largest and t.x == largest.x, "a kind's target is its largest region")
end
print(("A: %d land cells, %d regions, belts %d/%d/%d cells, camp at (%d, %d)"):format(n,
	#map.regions, stats.belts[1].cells, stats.belts[2].cells, stats.belts[3].cells, camp.x, camp.z))

-- ---------------------------------------------------------------------------
-- B. The game module with the shipped Dawnmere recipe
-- ---------------------------------------------------------------------------
local function noop() end
local G = {time = 0.5, now = 1000, objects = {}, players = {}, features = {}}
local function load_into(env, path)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	return chunk()
end
local GROUND_Y = 20
local function sand_at(x, z) return z < -2860 end
local env = setmetatable({}, {__index = _G})
env._G = env
local globalsteps, mods_loaded, overrides, storage_data = {}, {}, {}, {}
local DIR_FILES = {}
local overlay
env.core = {
	get_modpath = function(name)
		if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
		return MOBS
	end,
	get_current_modname = function() return "grug_mobs" end,
	get_dir_list = function() return DIR_FILES end,
	parse_json = json.parse,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	register_lbm = noop,
	override_item = function(name, def) overrides[name] = def end,
	settings = {get = function() return nil end, get_bool = function() return nil end},
	get_timeofday = function() return G.time end,
	get_gametime = function() return G.now end,
	get_us_time = function() return os.clock() * 1e6 end,
	registered_entities = {},
	registered_nodes = {["default:dirt_with_grass"] = {walkable = true},
		["default:sand"] = {walkable = true}, ["grug_nodes:blight_dirt"] = {walkable = true},
		air = {walkable = false}},
	get_item_group = function() return 0 end,
	find_nodes_in_area_under_air = function(minp, maxp)
		if GROUND_Y < minp.y or GROUND_Y > maxp.y then return {} end
		if W.water_class_at(minp.x, minp.z) ~= "land" then return {} end
		return {{x = minp.x, y = GROUND_Y, z = minp.z}}
	end,
	find_nodes_in_area = function(minp)
		-- sea water south of z = -2880 (shore crabs' host check)
		if minp.z <= -2880 then return {{x = minp.x, y = 0, z = minp.z}} end
		return {}
	end,
	get_node = function(pos)
		if pos.y <= GROUND_Y and G.blight and (G.blight == true or G.blight(pos.x, pos.z)) then
			return {name = "grug_nodes:blight_dirt"}
		end
		if pos.y <= GROUND_Y then return {name = sand_at(pos.x, pos.z) and "default:sand" or "default:dirt_with_grass"} end
		return {name = "air"}
	end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, obj in ipairs(G.objects) do
			local p = obj:get_pos()
			if p then
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				if dx * dx + dy * dy + dz * dz <= r * r then out[#out + 1] = obj end
			end
		end
		return out
	end,
	get_connected_players = function() return G.players end,
	get_natural_light = function() return 15 end,
	get_node_light = function(pos, tod)
		if G.light then return G.light end
		local t = tod or G.time
		return (t >= 0.1875 and t <= 0.8125) and 15 or 0
	end,
	log = function(level, msg) if level == "error" then G.last_error = msg end end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	get_meta = function() return {get_int = function() return 0 end, set_int = noop,
		get_string = function() return "" end, set_string = noop} end,
	get_node_timer = function() return {start = noop, is_started = function() return true end} end,
	set_node = noop,
	get_mod_storage = function() return nil end,
}
env.core.get_node_or_nil = env.core.get_node
local zones = {}
for k, v in pairs(ZONES) do zones[k] = v end
env.grug_zones = zones
env.grug_mapgen = {wp40 = {planner_source = {column_values_at = column_values_at},
	road_polylines = ROADS}}
env.grug_core = {
	start_identities = function()
		local out = {{anchor = START}}
		for i = 2, 6 do out[i] = {anchor = {x = 50000 + i * 1000, y = 10, z = 0}} end
		return out
	end,
	world_feature_at = function(pos)
		-- the road corridor: half width 2 + 1
		if math.abs(pos.x) <= 3 and pos.z >= -2550 and pos.z <= -1900 then return "road" end
		return nil
	end,
	DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	settlement_socket_anchor = function() return nil end,
	register_level_overlay = function(fn) overlay = fn end,
	zone_authority_installed = function() return true end,
}
env.mobs = {can_spawn = function(_, pos) return pos end}
env.vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end, round = function(p) return p end}
local DISP = {}
env.grug_mobs = {
	storage = {get_int = function(_, k) return storage_data[k] or 0 end,
		set_int = function(_, k, v) storage_data[k] = v end},
	settle_mob_death = function() G.settled = (G.settled or 0) + 1 end,
	disposition = function(name) return DISP[name] end,
	family_of = function(role)
		local row = CATALOGUE[role:match("^grug_mobs:(.+)$") or role]
		return row and row.family or role
	end,
	claim_refuses_spawn = function() return false end,
}
local function new_object(ent, pos)
	local obj = {props = {}, _pos = {x = pos.x, y = pos.y, z = pos.z}}
	function obj:get_pos() return not self._removed and self._pos or nil end
	function obj:get_luaentity() return not self._removed and ent or nil end
	function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function obj:get_properties() return self.props end
	return obj
end
local spawned = {}
env.grug_mobs.add_mob = function(pos, def)
	local ent = {name = def.name, health = 10}
	ent.object = new_object(ent, pos)
	G.objects[#G.objects + 1] = ent.object
	spawned[#spawned + 1] = ent
	return ent
end
env.grug_mobs.relevel = function(ent, level) ent._grug_spawn_level = level; ent._grug_level = level end
-- Registered roles: the recipe's, with their catalogue dispositions.
local data = json.parse(read(MOBS .. "/data/zones/" .. DAWN .. ".spawns.json"))
local function register(role)
	local row = CATALOGUE[role]
	local disp = row and row.disposition or (role == "rabbit" or role == "wild_turkey") and "critter" or "neutral"
	DISP["grug_mobs:" .. role] = disp
	env.core.registered_entities["grug_mobs:" .. role] = {_grug_disposition = disp}
end
for _, role in ipairs({"small_boar", "large_rat", "quiet_shore_crab", "braindead_zombie", "small_fox",
		"aggressive_boar", "rabid_rat", "giant_crab", "sluggish_zombie", "monstrous_rat", "drowned_zombie",
		"confused_bandit", "confused_bandit_chief", "rabbit", "wild_turkey", "boar", "fox"}) do
	register(role)
end
load_into(env, MOBS .. "/spawn_regions.lua")
load_into(env, MOBS .. "/spawn_policy.lua")
load_into(env, MOBS .. "/density.lua")
load_into(env, MOBS .. "/camps.lua")
load_into(env, MOBS .. "/roam_avoid.lua")
local GM = env.grug_mobs
local SR = GM.spawn_regions
for name, def in pairs(env.core.registered_entities) do
	GM.register_spawn_role(name, {clock = "day", type = def._grug_disposition == "aggressive" and "monster" or "animal",
		_grug_tier = def._grug_disposition == "critter" and "critter" or nil})
end
check(type(overlay) == "function", "the level overlay is registered with grug_core")

-- A zone without a recipe keeps its palette; the shipped recipe installs.
SR.install_zone(GOLD, {zone = GOLD, palette = {families = {"settled"}, boar = "grug_mobs:boar"}})
check(not SR.zone_has_recipe(GOLD) and SR.fallback_palettes()[GOLD].settled, "no recipe: today's palette")
SR.install_zone(DAWN, data)
for _, fn in ipairs(mods_loaded) do fn() end
check(SR.zone_has_recipe(DAWN) and SR.fallback_palettes()[DAWN] == nil, "recipe zone, no palette")
check(GM.spawn_policy_allows("grug_mobs:boar", {x = 200, y = GROUND_Y, z = -2700}) == false and
	GM.spawn_policy_allows("grug_mobs:rabbit", {x = 200, y = GROUND_Y, z = -2700}) == true,
	"ABM rows in a recipe zone: critters only")
check(not pcall(SR.install_zone, DAWN, {zone = DAWN, recipe = {belts = {}}}) and SR.zone_has_recipe(DAWN),
	"a broken recipe is refused and the zone keeps its data")

-- Seams for quests (static, no map build).
local hf = SR.get_area(DAWN, "home_fields")
check(hf and hf.tag == DAWN .. "/home_fields" and hf.levels[1] == 1 and hf.levels[2] == 2, "get_area kind")
local roles = SR.area_roles(DAWN, "pastures")
check(roles.small_fox and roles.aggressive_boar and roles.rabid_rat and not roles.small_boar, "area_roles day+night")
check(SR.get_area(DAWN, "bandit_camp").is_camp and SR.get_area(DAWN, "nope") == nil, "camp area, unknown area")
local ids = SR.zone_area_ids(DAWN)
check(#ids == 14 and ids[1] == "home_fields" and ids[14] == "bandit_camp", "zone_area_ids: 13 kinds + 1 camp")
local L = SR.leader("confused_bandit_chief")
check(L and L.zone == DAWN and L.level == 10 and L.respawn == 300 and L.pos == nil, "leader seam (static)")
check(SR.leader("small_boar") == nil, "no leader for a plain role")

-- The map builds lazily.
local M = SR.map(DAWN)
check(M and #M.regions > 0 and SR.build_stats[DAWN].cells == #M.order, "lazy build")
check(SR.map(DAWN) == M, "cached")
check(SR.map(GOLD) == nil, "no map without a recipe")
-- One level truth: the overlay answers the region's level.
local r0 = M.region_at(200, -2700)
check(overlay(200, -2700) == r0.level and SR.level_at(200, -2700) == r0.level, "overlay = region level")
check(overlay(0, -2100) == nil, "no overlay in a zone without a recipe")
local lp = SR.leader_pos("confused_bandit_chief")
check(lp and lp.x == M.leaders[1].x and lp.y == GROUND_Y, "leader_pos builds and answers")

-- The spawner end to end.
local function player_at(x, z)
	local p = {pos = {x = x, y = GROUND_Y + 1, z = z}}
	function p:get_pos() return self.pos end
	return p
end
local function clear()
	for _, obj in ipairs(G.objects) do obj._removed = true end
	G.objects, spawned = {}, {}
end
-- Find an open point of a kind (its largest region) away from roads.
local function point_of(kind_id)
	local best
	for _, reg in ipairs(M.by_kind[kind_id] or {}) do
		for _, c in ipairs(reg.cells) do
			if c.road >= 40 and c.drift == 0 and c.prot == 0 and (not best or c.road > best.road) then best = c end
		end
	end
	return best
end
local pc = point_of("borderlands")
check(pc, "a borderlands cell away from roads")
-- the attempt column: angle 0 (+x) at 24 nodes; stand the player 24 west of a cell centre
local P = player_at(pc.x - 24, pc.z)
G.time = 0.5
local outcome = SR.attempt(P.pos, {P}, "day", 0, 0)
check(outcome == "spawned", "a day spawn in the borderlands: " .. outcome)
local e = spawned[#spawned]
local unit = SR.area_by_tag(e._grug_area)
check(e._grug_area == DAWN .. "/" .. M.region_at(e.object:get_pos().x, e.object:get_pos().z).kind.id,
	"the tag names the kind of the region under the spot")
check(e._grug_spawn_clock == "day" and unit.rosters.day.list[1].role == e.name:sub(11), "day roster, clock")
local range = unit.levels_by_role[e.name:sub(11)]
check(e._grug_spawn_level >= range[1] and e._grug_spawn_level <= range[2], "level in the role's range")
G.time = 0.0
outcome = SR.attempt(P.pos, {P}, "night", 0, 0)
check(outcome == "spawned" and spawned[#spawned]._grug_spawn_clock == "night" and
	SR.area_by_tag(spawned[#spawned]._grug_area).rosters.night.list[1].role == spawned[#spawned].name:sub(11),
	"the night roster at night")
G.time = 0.5
clear()
-- Light: a day pick on a dark spot is refused; at night a hostile pick needs dark.
G.light = 8
check(SR.attempt(P.pos, {P}, "day", 0, 0) == "light", "day pick below light 10")
G.light = 9
G.time = 0.0
check(SR.attempt(P.pos, {P}, "night", 0, 0) == "light", "torch-lit ground refuses a hostile at night")
G.light, G.time = nil, 0.5
-- Players: 24 nodes from every player.
check(SR.attempt(P.pos, {P, player_at(pc.x + 10, pc.z)}, "day", 0, 0) == "player_near", "player clearance")
-- Protected ground: the start town.
local PT = player_at(-30, -2560)
check(SR.attempt(PT.pos, {PT}, "day", 0, 0) == "protected", "the start town refuses a spawn")
-- The drift band: an aggressive role near the road is refused, a neutral one is not.
do
	local road_cell
	for _, c in ipairs(M.order) do
		if c.x == 16 and c.z > -2400 and not c.camp and not road_cell and c.kind.rosters then
			road_cell = c
		end
	end
	check(road_cell, "a cell beside the road")
	-- stand the spawn spot 10 nodes east of the road (x = 10): player at x = -14
	local spot_x = 10
	local PD = player_at(spot_x - 24, road_cell.z)
	local region = M.region_at(spot_x, road_cell.z)
	local aggressive = GM.disposition("grug_mobs:" .. region.kind.rosters.day.list[1].role) == "aggressive"
	G.time = 0.0
	local night_aggr = GM.disposition("grug_mobs:" .. region.kind.rosters.night.list[1].role) == "aggressive"
	local o = SR.attempt(PD.pos, {PD}, "night", 0, 0)
	check(night_aggr and o == "drift", "aggressive night role refused in the drift band: " .. o)
	G.time = 0.5
	o = SR.attempt(PD.pos, {PD}, "day", 0, 0)
	check((aggressive and o == "drift") or (not aggressive and o == "spawned"),
		"day role near the road: neutral spawns, aggressive drifts (" .. o .. ")")
	check(SR.in_drift({x = 10, y = GROUND_Y + 1, z = road_cell.z}) and
		not SR.in_drift({x = 40, y = GROUND_Y + 1, z = road_cell.z}), "the drift band is 16 nodes")
	clear()
end
-- Shore crabs need their host: dry sand within 6 of sea water.
do
	local strand_cell
	for _, kid in ipairs({"strand", "tideflats", "wreck_coast"}) do
		for _, reg in ipairs(M.by_kind[kid] or {}) do
			for _, c in ipairs(reg.cells) do
				if not strand_cell and c.z < -2860 and c.drift == 0 and c.prot == 0 then strand_cell = c end
			end
		end
	end
	check(strand_cell, "a shore region on the south coast")
	local crab_role = strand_cell.kind.rosters.day.list[1].role
	check(GM.family_of(crab_role) == "crab", "the shore kind's day role is a crab")
	check(SR.shore_ok(crab_role, {x = 0, y = 2, z = -2875, node = "default:sand"}),
		"sand near the sea hosts a crab")
	check(not SR.shore_ok(crab_role, {x = 0, y = GROUND_Y, z = -2700, node = "default:dirt_with_grass"}),
		"grass is no crab host")
	check(SR.shore_ok("small_boar", {x = 0, y = GROUND_Y, z = -2700, node = "default:dirt_with_grass"}),
		"other roles need no shore")
end

-- Density classes: shares of the zone budget, never above it.
check(GM.density_budget(DAWN, "day") == 15 and GM.region_budget(DAWN, "day", "dense") == 15 and
	GM.region_budget(DAWN, "day", "normal") == 11 and GM.region_budget(DAWN, "day", "sparse") == 8,
	"day budgets dense 15, normal 11, sparse 8")
check(GM.region_budget(DAWN, "night", "dense") == 23 and GM.region_budget(DAWN, "night", "normal") == 17 and
	GM.region_budget(DAWN, "night", "sparse") == 12, "night budgets 23, 17, 12")
check(GM.area_density_decision(0, 0, 11, 11) and not GM.area_density_decision(11, 9, 11, 11) and
	GM.area_density_decision(20, 3, 11, 8) and not GM.area_density_decision(0, 8, 11, 8),
	"budget, refill floor and share")
do
	clear()
	-- Fill one point: a normal open region by day holds 11 of its single role.
	for _ = 1, 400 do SR.attempt(P.pos, {P}, "day", 0, 0) end
	local n_day = 0
	for _, s in ipairs(spawned) do if s._grug_spawn_clock == "day" then n_day = n_day + 1 end end
	check(n_day == 11, "a normal region holds 11 by day (" .. n_day .. ")")
	-- Night animals are not blocked by the day's.
	G.time = 0.0
	for _ = 1, 400 do SR.attempt(P.pos, {P}, "night", 0, 0) end
	local n_night = 0
	for _, s in ipairs(spawned) do if s._grug_spawn_clock == "night" then n_night = n_night + 1 end end
	check(n_night == 17, "and 17 at night beside the day's (" .. n_night .. ")")
	G.time = 0.5
	clear()
end

-- Camps.
do
	clear()
	local unit = M.camps[1]
	check(unit and #SR.camp_units() == 1 and SR.camp_units()[1] == unit, "camp unit of the built map")
	local PC = player_at(unit.x + 50, unit.z)
	G.now = 5000
	GM.region_camp_tick(G.now, {player_at(unit.x + 70, unit.z)}, "day")
	check(#spawned == 0, "first fill waits for a player within 64 nodes")
	GM.region_camp_tick(G.now, {PC}, "day")
	check(#spawned == 6, "first look fills all six slots (" .. #spawned .. ")")
	for _, m in ipairs(spawned) do
		local p = m.object:get_pos()
		local dx, dz = p.x - unit.x, p.z - unit.z
		check(m._grug_area == DAWN .. "/bandit_camp" and m.name == "grug_mobs:confused_bandit" and
			m._grug_spawn_level >= 9 and m._grug_spawn_level <= 10, "camp member tag, role, level 9-10")
		check(dx * dx + dz * dz <= 40 * 40 + 1, "inside the camp radius")
		local qx, qz = p.x - PC.pos.x, p.z - PC.pos.z
		check(qx * qx + qz * qz >= 16 * 16, "16 nodes from the player")
	end
	spawned[1].object._removed = true
	spawned[2].object._removed = true
	local before = #spawned
	GM.region_camp_tick(G.now + 5, {PC}, "day")
	check(#spawned == before, "no instant refill")
	GM.region_camp_tick(G.now + 29, {PC}, "day")
	check(#spawned == before, "not before 30 s")
	GM.region_camp_tick(G.now + 65, {PC}, "night")
	check(#spawned == before + 1, "first slot back within 60 s, at any clock")
	GM.region_camp_tick(G.now + 130, {PC}, "day")
	check(#spawned == before + 2, "second slot after another 30-60 s")
	-- An ambient attempt on camp ground is no pick.
	check(SR.attempt({x = unit.x - 24, y = GROUND_Y + 1, z = unit.z}, {player_at(unit.x - 24, unit.z)},
		"day", 0, 0) == "camp", "camp ground spawns through its slots only")
	clear()
	-- Round 28 S2 review: a camp on a POI keeps its members within 24 nodes
	-- of the POI, and an aggressive member never stands in the drift band.
	-- The same unit, moved beside the road (x = 0) as a POI camp.
	check(GM.disposition("grug_mobs:confused_bandit") == "aggressive", "camp members are aggressive")
	local saved = {x = unit.x, z = unit.z, site = unit.site, center_y = unit.center_y}
	unit.x, unit.z, unit.site, unit.center_y = 20, -2450, {name = "Test POI"}, nil
	local PP = player_at(unit.x + 40, unit.z)
	local t = G.now + 1000
	for _ = 1, 40 do
		t = t + 61
		GM.region_camp_tick(t, {PP}, "day")
	end
	check(#spawned == 6, "the POI camp refills its six slots (" .. #spawned .. ")")
	local drift_free, near = true, true
	for _, m in ipairs(spawned) do
		local p = m.object:get_pos()
		local dx, dz = p.x - unit.x, p.z - unit.z
		if dx * dx + dz * dz > 25 * 25 then near = false end -- spots are rounded to nodes
		if SR.in_drift(p) then drift_free = false end
	end
	check(near, "POI camp members stand within 24 nodes of the POI")
	check(drift_free, "no aggressive POI camp member in the drift band")
	unit.x, unit.z, unit.site, unit.center_y = saved.x, saved.z, saved.site, saved.center_y
	clear()
end

-- Leaders.
do
	clear()
	local spot = M.leaders[1]
	G.now = 10000
	SR.leader_tick(G.now, {player_at(spot.x + 10, spot.z)})
	check(#spawned == 0, "no leader within 24 nodes of a player")
	local PL = player_at(spot.x + 40, spot.z)
	SR.leader_tick(G.now, {PL})
	check(#spawned == 1, "leader spawned")
	local leader = spawned[1]
	check(leader.name == "grug_mobs:confused_bandit_chief" and leader._grug_leader and
		leader._grug_area == nil and leader._grug_spawn_level == 10, "leader flag, no tag, level 10")
	check(leader.object.props.static_save == false, "leader never saved")
	SR.leader_tick(G.now + 5, {PL})
	check(#spawned == 1, "alive: no second leader")
	leader.health = 0
	GM.settle_mob_death(leader)
	leader.object._removed = true
	check(G.settled == 1, "the death boundary still runs")
	SR.leader_tick(G.now + 100, {PL})
	check(#spawned == 1, "no respawn before 300 s")
	SR.leader_tick(G.now + 301, {PL})
	check(#spawned == 2, "respawn after 300 s")
	clear()
end

-- Blight ground (S2b): a zombie-family role or a leader set on blight dirt is
-- sunproof, as the legacy blight ABM makes its zombies; by day a mob that
-- burns spawns only where it is sunproof.
do
	clear()
	check(SR.sunproof_on_blight({}, "braindead_zombie", "default:dirt_with_grass", false) == false,
		"a zombie on grass keeps its daylight burn")
	check(SR.sunproof_on_blight({}, "small_boar", "grug_nodes:blight_dirt", false) == false,
		"a boar on blight is no zombie")
	local z = {light_damage = 2}
	check(SR.sunproof_on_blight(z, "braindead_zombie", "grug_nodes:blight_dirt", false) and
		z.light_damage == 0, "a zombie sub-type on blight is sunproof")
	local chief = {light_damage = 2}
	check(SR.sunproof_on_blight(chief, "confused_bandit_chief", "grug_nodes:blight_dirt", true) and
		chief.light_damage == 0, "any leader on blight is sunproof")
	local def = env.core.registered_entities["grug_mobs:braindead_zombie"]
	def.light_damage = 2
	local strand = SR.get_area(DAWN, "strand")
	local grass = {x = 300, y = GROUND_Y, z = -2700, node = "default:dirt_with_grass"}
	local blight = {x = 300, y = GROUND_Y, z = -2700, node = "grug_nodes:blight_dirt"}
	check(SR.spawn_mob(strand, "braindead_zombie", grass, "day") == nil and #spawned == 0,
		"by day no burning zombie off blight")
	local ent = SR.spawn_mob(strand, "braindead_zombie", blight, "day")
	check(ent and ent.light_damage == 0, "by day a zombie on blight spawns sunproof")
	ent = SR.spawn_mob(strand, "braindead_zombie", grass, "night")
	check(ent and ent.light_damage == nil, "at night a zombie off blight spawns as before")
	def.light_damage = nil
	clear()
	-- The leader tick: a leader whose spot is blight dirt survives the day.
	local spot = M.leaders[1]
	storage_data["leader_next:" .. spot.role] = 0
	G.blight = true
	SR.leader_tick(G.now + 1000, {player_at(spot.x + 40, spot.z)})
	G.blight = nil
	check(#spawned == 1 and spawned[1]._grug_leader and spawned[1].light_damage == 0,
		"a leader spawned on blight dirt is sunproof")
	spawned[1].object._removed = true
	clear()
	-- A zombie leader whose own column is not blight steps to the nearest
	-- blight column within 16 nodes; any other leader keeps its spot.
	local blight_east = function(x) return x >= spot.x + 8 end
	G.blight = blight_east
	storage_data["leader_next:" .. spot.role] = 0
	SR.leader_tick(G.now + 2000, {player_at(spot.x - 40, spot.z)})
	check(#spawned == 1 and spawned[1].object:get_pos().x == spot.x and spawned[1].light_damage == nil,
		"a bandit leader keeps its spot off blight and its daylight burn")
	spawned[1].object._removed = true
	clear()
	local saved_role = spot.role
	spot.role = "mortuary_clerk_hush"
	env.core.registered_entities["grug_mobs:mortuary_clerk_hush"] = {_grug_disposition = "aggressive"}
	storage_data["leader_next:mortuary_clerk_hush"] = 0
	SR.leader_tick(G.now + 3000, {player_at(spot.x - 40, spot.z)})
	local hush = spawned[1]
	check(hush and hush.object:get_pos().x == spot.x + 8 and hush.light_damage == 0,
		"a zombie leader stands on the nearest blight column, sunproof")
	if hush then hush.object._removed = true end
	G.blight = function() return false end
	storage_data["leader_next:mortuary_clerk_hush"] = 0
	clear()
	SR.leader_tick(G.now + 4000, {player_at(spot.x - 40, spot.z)})
	check(#spawned == 1 and spawned[1].object:get_pos().x == spot.x and spawned[1].light_damage == nil,
		"no blight in reach: the zombie leader keeps its spot")
	spawned[1].object._removed = true
	G.blight, spot.role = nil, saved_role
	env.core.registered_entities["grug_mobs:mortuary_clerk_hush"] = nil
	clear()
end

-- Directions through the game seam.
do
	local d1 = SR.describe(DAWN, "bandit_camp", "of", {x = 0, z = -2550, name = "Dawnmere"})
	local d2 = SR.describe(DAWN, "confused_bandit_chief", "from", {x = -11, z = -2542})
	local d3 = SR.describe(DAWN, "meadows", "zone")
	check(d1 and d1.phrase:find(" of Dawnmere$") and d2 and d2.phrase:find(" from here$") and
		d3 and d3.phrase:find("Dawnmere Fields$"), "describe in the game: of, from, zone")
	check(SR.direction(DAWN, "bandit_camp", {x = 0, z = -2550}) == d1.dir, "direction = describe's dir")
	check(SR.describe(GOLD, "x", "zone") == nil, "no map, no describe")
	check(SR.describe(DAWN, "bandit_camp", "of", "no_such_place") == nil, "unknown place")
end

-- levels.lua: a definition's HP factor (the leader's 2x) on top of level and tier.
do
	local LE = setmetatable({}, {__index = _G})
	LE._G = LE
	LE.core = {settings = {get = function() return nil end}, log = noop,
		get_us_time = function() return 0 end}
	LE.grug_zones = {guard_level_at = function() return 60 end}
	LE.grug_core = {mob_level_at = function() return 10 end, format_k = tostring,
		nearest_tag_player_d2 = function() return nil end, set_tag_carrier_text = noop,
		sync_tag_carrier_box = noop, mono_time = function() return 100 end}
	LE.grug_xp = {mob_xp = function(level) return 25 + 5 * level end, LEVEL_OFFSET = 5}
	LE.mobs = {scale_mob = noop}
	LE.math = setmetatable({round = function(x) return math.floor(x + 0.5) end}, {__index = math})
	LE.grug_mobs = {}
	load_into(LE, MOBS .. "/levels.lua")
	local LG = LE.grug_mobs
	LG.ensure_tag_carrier = noop
	LG.register_level_cfg("grug_mobs:plain", {})
	LG.register_level_cfg("grug_mobs:chief", {_grug_hp_scale = 2})
	local function fake(name)
		local self = {name = name}
		self.object = new_object(self, {x = 0, y = 0, z = 0})
		function self.object:set_armor_groups() end
		return self
	end
	local a, b = fake("grug_mobs:plain"), fake("grug_mobs:chief")
	LG.ensure_init(a)
	LG.ensure_init(b)
	check(a._grug_level == 10 and b._grug_level == 10, "both at the gameplay level 10")
	check(b.hp_max == 2 * a.hp_max and a.hp_max == LG.stats_for(10, "normal"), "HP x2 for a leader definition")
end

print(("B: %d regions, build %.0f ms; spawner, drift, density, camps, leaders, overlay, seams"):format(
	#M.regions, SR.build_stats[DAWN].ms))
print("R28 S1 PORTABLE PASS checks=" .. checks)
