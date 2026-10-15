-- Round 49 lane PROT portable fixture (LuaJIT): the protection depth under
-- towns and the preparation bottom for high massifs
-- (mapgen-native-plan.md §4.4, rulings 6 and 8).
--
--   luajit tools/r49_prot/portable_test.lua REPO
--
-- 1. The protection depth: one constant (`source.protection_depth_below_
--    placement`, the value measured by measure_depth.lua) in both hard
--    recipes, and every consumer of one world (seed 4242424242, the
--    capitals stood in by squares, no roads) answers from it: the session's
--    floor, the hard footprints (territory, "town", the capital guard
--    level), the functional outpost and bandit columns, the claim-exclusion
--    floors of the anchor envelopes (cave and surface writers, renewal), the
--    P8 resource floor, and a town column's hard foundation.
-- 2. The preparation bottom (`preparation_plan.lua` M.FILL_FLOOR): the fill
--    floor is the mapgen's authored floor; a high tile reaches down to the
--    chunk -112..-33, an ordinary tile keeps its bottom, and the change
--    starts exactly where the window's lowest surface envelope reaches y 144.
local repo = assert(arg[1], "usage: portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- 1. Protection depth
-- ---------------------------------------------------------------------------
-- 30 (the name-tag hide distance, grug_core/tag_carrier.lua) + the deepest
-- standing place in a town below its placement height (34, measure_depth.lua
-- over the quick fleet's 100 seeds) + a margin of at least 10, rounded up to
-- the next ten.
local EXPECTED_DEPTH = 80
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local source = dofile(dir .. "/source/simple_map.lua")
local DEPTH = source.protection_depth_below_placement
check(DEPTH == EXPECTED_DEPTH, "protection depth " .. tostring(DEPTH))
local recipes = 0
for _, recipe in ipairs(source.hard_protection_recipes) do
	check(recipe.depth_below_placement == DEPTH, recipe.id .. " carries the depth")
	recipes = recipes + 1
end
check(recipes == 2, "two hard recipes")
do
	-- The R7 manifest takes the same constant (functional anchor columns).
	local file = assert(io.open(dir .. "/r7_runtime.lua", "rb"))
	local text = file:read("*a")
	file:close()
	check(text:find("protection_depth_below_placement = " ..
		"source.protection_depth_below_placement", 1, true) ~= nil,
		"the runtime hands the constant to the R7 manifest")
end

local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
local W = A.world("4242424242", nil, {roads = false, protection = A.square_cities(120)})
local S, P = W.zones().new_with_planner_source_runtime("4242424242", 1)
local roster = dofile(dir .. "/r7_anchor_roster.lua")(W.source, S, P, sha)
local O = dofile(dir .. "/r7_zone_overlay.lua")(S, roster)
check(S.protection_floor_y(40) == 40 - DEPTH, "session floor")

local starts, capitals = 0, 0
for index = 1, 12 do
	local a = W.source.anchors[index]
	local zone = W.source.zones[a.zone_numeric_id]
	local y = S.anchor(zone.id, a.slot_id).y
	local floor = y - DEPTH
	local x, z = a.position.x, a.position.z
	local at, under = {x = x, y = floor, z = z}, {x = x, y = floor - 1, z = z}
	check(O.territory_rule_at(at) == "hard_protected" and
		O.territory_rule_at(under) ~= "hard_protected", a.id .. " territory floor")
	check(O.hard_protection_kind_at(at) == "town" and
		O.hard_protection_kind_at(under) == nil, a.id .. " town floor (spawn refusal)")
	-- (lane ORE retires the P8 resource floor in the same round)
	if P.ore_floor_at then check(P.ore_floor_at(x, z) == floor, a.id .. " P8 resource floor") end
	check(P.protected_floor_at(x, z) <= floor, a.id .. " cave and surface floor")
	local hard = select(20, P.column_values_at(x, z))
	check(hard == true, a.id .. " hard foundation")
	if a.slot_id == "capital" then
		capitals = capitals + 1
		check(S.guard_level_at(at) == 60 and S.guard_level_at(under) ~= 60,
			a.id .. " capital guard level floor")
	else
		starts = starts + 1
	end
end
check(starts == 6 and capitals == 6, "six starts and six capitals")

-- The functional outpost and bandit columns (R7 overlay).
local functional = 0
for _, row in ipairs(roster.rows) do
	if row.family == "outpost" or row.family == "bandit" then
		functional = functional + 1
		local floor = row.y - DEPTH
		check(O.territory_rule_at({x = row.x, y = floor, z = row.z}) == "hard_protected" and
			O.territory_rule_at({x = row.x, y = floor - 1, z = row.z}) ~= "hard_protected",
			row.id .. " functional column floor")
	end
end
check(functional == 36, "36 functional columns")

-- The claim-exclusion floor of an anchor envelope outside every town: a
-- village's or POI's centre holds at most its own anchor's floor.
local envelopes = 0
for index = 13, #W.source.anchors do
	local a = W.source.anchors[index]
	local zone = W.source.zones[a.zone_numeric_id]
	local record = S.anchor(zone.id, a.slot_id)
	if record and O.territory_rule_at({x = a.position.x, y = 30000,
			z = a.position.z}) ~= "hard_protected" then
		local floor = P.protected_floor_at(a.position.x, a.position.z)
		check(floor ~= nil and floor <= record.y - DEPTH, a.id .. " envelope floor")
		envelopes = envelopes + 1
	end
end
check(envelopes > 0, "anchor envelopes outside the towns")

-- ---------------------------------------------------------------------------
-- 2. Preparation bottom
-- ---------------------------------------------------------------------------
local plan = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
do
	local file = assert(io.open(dir .. "/mapgen_manifest.lua", "rb"))
	local text = file:read("*a")
	file:close()
	check(tonumber(text:match("\n%s*authored_floor = (%-?%d+),")) == plan.FILL_FLOOR,
		"the fill floor is the mapgen's authored floor")
end
check(plan.FILL_FLOOR == -37, "fill floor -37")
local ids = {}
for i = 1, 6 do ids[i] = {race_id = "race" .. i, anchor = {x = 0, y = 0, z = 0}} end
local SMALL = {x_min = -400, x_max = 400, z_min = -400, z_max = 400}
local function bottom(height, tx, tz)
	-- the selection of tile (tx, tz) over flat land at `height` (a column's
	-- envelope is height - 1 .. height + 3)
	local p = plan.new("full", {x = 5, y = 5, z = 5}, ids,
		{generate_distance = 10, flight_ceiling = 600, bounds = SMALL})
	local src = {identity = "r49-prot",
		tile_bounds = function() return 1, math.huge, -math.huge end,
		column_bounds = function() return height - 1, height + 3 end}
	p.cursor = tz * p.counts.x + tx
	local scanner = plan.scanner(p, p.cursor + 1)
	while not plan.select(p, scanner) do plan.scan(p, scanner, src, 65536) end
	return p.selection.y_min, p.selection.y_max
end
-- An ordinary tile: flat 20 -> 19 - 176 = -157 -> chunk -192 (unchanged).
local low, high = bottom(20, 5, 5)
check(low == -192 and high == 768, "ordinary tile keeps -192")
-- A high massif: flat 300 -> 123 before, now the fill floor -> chunk -112.
low, high = bottom(300, 5, 5)
check(low == -112 and high == 768, "high tile reaches the fill-floor chunk")
-- The boundary: an envelope low of 143 (surface 144) gives -33 -> -112
-- either way; 144 (surface 145) gave -32 -> chunk -32 and now -112.
check(bottom(144, 5, 5) == -112, "surface 144: already the fill-floor chunk")
check(bottom(145, 5, 5) == -112, "surface 145: lowered to the fill-floor chunk")
check(plan.align(145 - 1 - 176, 5) == -32, "surface 145 alone would start at -32")
-- A start envelope still reaches its own lower bottom.
do
	local p = plan.new("full", {x = 5, y = 5, z = 5}, {
		{race_id = "a", anchor = {x = 0, y = -200, z = 0}},
		{race_id = "b", anchor = {x = 0, y = 0, z = 0}},
		{race_id = "c", anchor = {x = 0, y = 0, z = 0}},
		{race_id = "d", anchor = {x = 0, y = 0, z = 0}},
		{race_id = "e", anchor = {x = 0, y = 0, z = 0}},
		{race_id = "f", anchor = {x = 0, y = 0, z = 0}}},
		{generate_distance = 10, flight_ceiling = 600, bounds = SMALL})
	local src = {identity = "r49-prot",
		tile_bounds = function() return 1, math.huge, -math.huge end,
		column_bounds = function() return 299, 303 end}
	-- the tile holding x 0, z 0
	local tx = math.floor((0 - p.bounds.min.x) / 80)
	local tz = math.floor((0 - p.bounds.min.z) / 80)
	p.cursor = tz * p.counts.x + tx
	local scanner = plan.scanner(p, p.cursor + 1)
	while not plan.select(p, scanner) do plan.scan(p, scanner, src, 65536) end
	check(p.selection.y_min == plan.align(-200 + 1 - 24, 5), "start envelope bottom kept")
end

print(("R49 PROT FIXTURE PASS checks=%d"):format(checks))
