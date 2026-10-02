-- Round 28 Lane S2-core portable test (LuaJIT): the recipe format
-- extensions of spawn_regions_core.lua.
--
--   luajit tools/r28_s2/portable_test.lua [REPO]
--
-- A. Camp POIs from the real world model: core.zone_pois over the shipped
--    anchor source and the settlement roster's names gives, for every zone,
--    exactly the camps the zone atlas (docs/planning/round28/zones) lists, so
--    the game and the validator (which reads the atlas) agree.
-- B. The parser: `from` by anchor list or border, `to` core, a one-belt
--    recipe without `to` (and `from`), camp sites on POIs (type, name,
--    ambiguity, guard posts, apart, a leader's camp without a belt, two
--    camps on one POI; every camp states its belt).
-- C. The builder on a synthetic world: border sources (d_from 0 on the
--    border cells), progress toward the exit, `to` core (the top belt is
--    the cells farthest from every source), one belt, anchor lists, camps on
--    POIs (centre, cells within the camp radius, the stated belt and its
--    levels, the POI cell's own belt in the stats and a warning when it lies
--    more than one belt away, generated camps kept apart, a leader at the
--    POI).
-- Prints "R28 S2 PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local CORE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")

local function read(path)
	local f = assert(io.open(path, "rb"))
	local t = f:read("*a")
	f:close()
	return t
end

-- ---------------------------------------------------------------------------
-- A. Camp POIs of the real world model against the zone atlas
-- ---------------------------------------------------------------------------
do
	_G.core = _G.core or {}
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(wp40 .. "/source/simple_map.lua")
	local labels = {}
	for _, row in ipairs(dofile(wp40 .. "/r7_settlement.lua").roster) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	local zones_checked, pois_seen = 0, 0
	for _, zone in ipairs(source.zones) do
		local path = repo .. "/docs/planning/round28/zones/" .. zone.id .. ".json"
		local f = io.open(path, "rb")
		if f then
			f:close()
			local atlas = json.parse(read(path))
			local want = {}
			for _, c in ipairs(atlas.camps or {}) do
				want[#want + 1] = ("%s|%s|%s"):format(c.anchor, c.type, c.name)
			end
			local got = {}
			for _, p in ipairs(CORE.zone_pois(source, zone.id, labels)) do
				got[#got + 1] = ("%s|%s|%s"):format(p.id, p.poi, p.name)
			end
			table.sort(want)
			table.sort(got)
			check(table.concat(want, ";") == table.concat(got, ";"),
				zone.id .. ": camp POIs match the atlas (" .. table.concat(got, ";") .. ")")
			zones_checked = zones_checked + 1
			pois_seen = pois_seen + #got
		end
	end
	check(zones_checked == 38, "38 zones in the atlas (" .. zones_checked .. ")")
	print(("A: %d zones, %d camp POIs match the atlas"):format(zones_checked, pois_seen))
end

-- ---------------------------------------------------------------------------
-- The synthetic world
-- ---------------------------------------------------------------------------
-- Zone A: x in [-640, 640), z in [-640, 0) (40 x 20 cells), flat meadow
-- land. North of it zone B (z in [0, 320)), south zone C (z in [-960,
-- -640)), both land; west and east of them open sea. Anchors of A: the
-- start, two bandit POIs and a guard post.
local A, B, C = "zone_a", "zone_b", "zone_c"
local function zone_at(x, z)
	if x < -640 or x >= 640 then return nil end
	if z >= 0 and z < 320 then return B end
	if z >= -640 and z < 0 then return A end
	if z >= -960 and z < -640 then return C end
	return nil
end
local ANCHORS = {
	{id = "anchor_001", slot = "start", template = "start", x = -400, z = -320},
	{id = "anchor_002", slot = "bandit_1", template = "bandit_home", x = 400, z = -500},
	{id = "anchor_003", slot = "bandit_2", template = "bandit_frontier", x = -500, z = -100},
	{id = "anchor_004", slot = "outpost_1", template = "outpost", x = 0, z = -600},
}
local LABELS = {anchor_002 = "Test Bandit Camp", anchor_003 = "Test Hideout",
	anchor_004 = "Test Post"}
local SOURCE = {zones = {{id = A, numeric_id = 1}, {id = B, numeric_id = 2}, {id = C, numeric_id = 3}},
	anchors = {}}
for _, a in ipairs(ANCHORS) do
	SOURCE.anchors[#SOURCE.anchors + 1] = {id = a.id, zone_numeric_id = 1, slot_id = a.slot,
		template_id = a.template}
end
local ZONES = {
	id_at = zone_at,
	water_class_at = function(x, z) return zone_at(x, z) and "land" or "deep_ocean" end,
	terrain_height_at = function() return 20 end,
	biome_at = function() return "grug_meadows" end,
	hard_protection_kind_at = function() return nil end,
	anchor = function(zone, slot)
		if zone ~= A then return nil end
		for _, a in ipairs(ANCHORS) do
			if a.slot == slot then return {x = a.x, y = 20, z = a.z, id = a.id} end
		end
		return nil
	end,
	get = function(zone)
		if zone == A then return {hub = {x = 0, z = -320}, level_min = 11, level_max = 20} end
		return nil
	end,
}
local Q = CORE.queries({zones = ZONES, road_polylines = {}, source = SOURCE,
	column_values_at = function(x, z) return "land" end})

local CATALOGUE = {
	-- levels as the catalogue gives them (roles outside it: unrestricted)
	lowling = {levels = {11, 14}}, highling = {levels = {15, 20}},
	raider = {levels = {17, 20}}, chief = {levels = {18, 20}, leader = true},
	gapling = {levels = {11, 11}}, topling = {levels = {13, 14}},
}
local function ctx()
	return {band = {11, 20},
		role_levels = function(role) return CATALOGUE[role] and CATALOGUE[role].levels end,
		leader = function(role) return CATALOGUE[role] ~= nil and CATALOGUE[role].leader == true end,
		pois = function(zone) return CORE.zone_pois(SOURCE, zone, LABELS) end}
end
local function roster(role) return {{role = role, weight = 1}} end
local function kind(id, role)
	return {open = {id = id, name = id, day = roster(role), night = roster(role), density = "normal"}}
end
local function two_belts()
	return {
		{id = "low", share = 50, levels = {11, 14}, kinds = kind("low_open", "lowling")},
		{id = "high", share = 50, levels = {15, 20}, kinds = kind("high_open", "highling")},
	}
end
local function deep_copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deep_copy(v) end
	return out
end
local function parse(recipe) return CORE.parse_recipe(A, recipe, ctx()) end
local function parse_fails(recipe, pattern, label)
	local ok, err = pcall(parse, recipe)
	check(not ok and tostring(err):find(pattern, 1, true) ~= nil,
		label .. " (got " .. tostring(ok and "no error" or err) .. ")")
end
local function bandit_camp(fields)
	local row = {id = "bandits", name = "Bandits", site = {poi = "bandit", name = "Test Bandit Camp"},
		belt = "high", roster = roster("raider"), slots = 5, respawn = {30, 60},
		min_player_distance = 16}
	for k, v in pairs(fields or {}) do
		if v == false then row[k] = nil else row[k] = v end
	end
	return row
end

-- ---------------------------------------------------------------------------
-- B. The parser
-- ---------------------------------------------------------------------------
local pois = CORE.zone_pois(SOURCE, A, LABELS)
check(#pois == 3 and pois[1].poi == "bandit" and pois[1].name == "Test Bandit Camp" and
	pois[2].poi == "bandit" and pois[3].poi == "guard post" and pois[3].name == "Test Post",
	"zone_pois: bandit_home and bandit_frontier are bandit POIs, outpost a guard post, names by label")
check(CORE.zone_pois(SOURCE, A, nil)[1].name == "anchor_002", "zone_pois: the anchor id without a label")

local base = {from = {border = C}, to = {border = B}, belts = two_belts()}
local r = parse(deep_copy(base))
check(r.from.border[1] == C and not r.from.anchors and r.to.border[1] == B, "from by border parses")
r = parse({from = {anchor = {"start", "anchor_003"}}, to = {core = true}, belts = two_belts()})
check(#r.from.anchors == 2 and r.from.anchors[2] == "anchor_003" and r.to.core == true,
	"from an anchor list, to core")
r = parse({from = {anchor = "start"}, to = {border = {B, C}}, belts = two_belts()})
check(r.from.anchors[1] == "start" and #r.to.border == 2, "a single anchor and a border list")
r = parse({belts = {{id = "all", share = 100, levels = {11, 20}, kinds = kind("all_open", "boar")}}})
check(r.from == nil and r.to == nil, "a one-belt recipe without from and to")
r = parse({from = {anchor = "start"}, belts = {{id = "all", share = 100, levels = {11, 20},
	kinds = kind("all_open", "boar")}}})
check(r.from.anchors[1] == "start" and r.to == nil, "a one-belt recipe without to")
parse_fails({from = {anchor = "start"}, belts = two_belts()}, "only a one-belt recipe may omit it",
	"two belts without to")
parse_fails({to = {core = true}, belts = two_belts()}, "from: needs", "to without from")
parse_fails({from = {anchor = "start", border = C}, to = {core = true}, belts = two_belts()},
	"from: needs", "from with an anchor and a border")
parse_fails({from = {border = A}, to = {core = true}, belts = two_belts()},
	"other zones' ids", "from border is the zone itself")
parse_fails({from = {border = C}, to = {border = C}, belts = two_belts()},
	"both the entry and the exit border", "entry border is the exit border")
parse_fails({from = {border = C}, to = {core = 1}, belts = two_belts()}, "core must be true",
	"to core not true")
parse_fails({from = {border = C}, to = {core = true, border = B}, belts = two_belts()}, "to: needs",
	"to with core and border")
parse_fails({from = {anchor = {}}, to = {core = true}, belts = two_belts()}, "anchor is a slot",
	"an empty anchor list")

local function with_camps(camps, leaders)
	local recipe = deep_copy(base)
	recipe.camps = camps
	recipe.leaders = leaders
	return recipe
end
r = parse(with_camps({bandit_camp()}))
check(r.camps[1].site.anchor == "anchor_002" and r.camps[1].belt.id == "high" and
	r.camps[1].levels_by_role.raider[1] == 17 and r.camps[1].levels_by_role.raider[2] == 20,
	"a camp on a named POI: its stated belt and the levels in it")
parse_fails(with_camps({bandit_camp({belt = false})}), "every camp states its belt",
	"a camp on a POI without a belt")
parse_fails(with_camps({bandit_camp({site = {poi = "bandit"}})}), "has 2 bandit POIs",
	"two bandit POIs without a name")
parse_fails(with_camps({bandit_camp({site = {poi = "bandit", name = "Nowhere"}})}),
	"no bandit POI named Nowhere", "an unknown POI name")
parse_fails(with_camps({bandit_camp({site = {poi = "mirefolk"}})}), "has no mirefolk POI",
	"a POI type the zone lacks")
parse_fails(with_camps({bandit_camp({site = {poi = "guard post"}})}), "not a mob camp POI",
	"a guard post is no mob camp")
parse_fails(with_camps({bandit_camp({site = {poi = "bandit", name = "Test Hideout", x = 1}})}),
	"unknown field x", "an unknown site field")
parse_fails(with_camps({bandit_camp({apart = 8})}), "apart places a generated site",
	"apart on a camp on a POI")
parse_fails(with_camps({bandit_camp(), bandit_camp({id = "more"})}), "already holds camp",
	"two camps on one POI")
parse_fails(with_camps({bandit_camp({site = "generate", apart = 4, belt = false})}),
	"every camp states its belt", "a generated camp without a belt")
parse_fails(with_camps({bandit_camp({roster = {{role = "topling", weight = 4},
	{role = "gapling", weight = 1}}, belt = "low"})}), "[cover]", "the camp cover rule on a POI camp")
r = parse(with_camps({bandit_camp()}, {{role = "chief", at = {camp = "bandits"}, respawn = 300}}))
check(r.leaders[1].level == 20, "a leader at a camp on a POI with a stated belt: its level is fixed")
parse_fails(with_camps({bandit_camp({belt = "low"})}), "never meets the belt",
	"a stated belt still checks the roles' levels")
print("B: parser")

-- ---------------------------------------------------------------------------
-- C. The builder
-- ---------------------------------------------------------------------------
local CELL = CORE.CELL
local function build(recipe)
	return CORE.build(A, Q, parse(recipe))
end
local function row_of(c) return c.j end -- z row: -20 (south) .. -1 (north)

-- Border sources and progress toward the exit.
local map = build(deep_copy(base))
check(#map.order == 800, "800 land cells (" .. #map.order .. ")")
local south, north = {}, {}
for _, c in ipairs(map.order) do
	if row_of(c) == -20 then south[#south + 1] = c end
	if row_of(c) == -1 then north[#north + 1] = c end
end
local ok_src, ok_belt = true, true
for _, c in ipairs(south) do
	if c.d_from ~= 0 then ok_src = false end
	if c.belt ~= 1 then ok_belt = false end
end
check(#map.from_cells == 40 and ok_src, "from border: the 40 cells along zone C have d_from 0")
check(ok_belt, "the entry row lies in the first belt")
local ok_top = true
for _, c in ipairs(north) do
	if c.belt ~= 2 or c.progress < 0.99 then ok_top = false end
end
check(ok_top, "the exit row (bordering B) lies in the last belt at progress 1")

-- `to` core from both borders: the middle is the top belt.
map = build({from = {border = {B, C}}, to = {core = true}, belts = two_belts()})
local max_low, min_high, far = -1, math.huge, nil
for _, c in ipairs(map.order) do
	if c.belt == 1 then max_low = math.max(max_low, c.d_from) end
	if c.belt == 2 then min_high = math.min(min_high, c.d_from) end
	if not far or c.d_from > far.d_from then far = c end
end
check(#map.from_cells == 80, "to core: both border rows are sources (" .. #map.from_cells .. ")")
check(min_high >= max_low and far.belt == 2, "to core: the top belt holds the cells farthest from every source")
check(far.j == -11 or far.j == -10, "to core: the farthest cells lie in the middle rows")

-- One belt, no from and no to: one belt everywhere.
map = build({belts = {{id = "all", share = 100, levels = {11, 20}, kinds = kind("all_open", "boar")}}})
local all_one = true
for _, c in ipairs(map.order) do
	if c.belt ~= 1 or c.progress ~= 0 then all_one = false end
end
check(all_one and #map.regions > 0, "one belt without from and to: every cell in it")

-- Anchor lists: every listed anchor is a source.
map = build({from = {anchor = {"start", "anchor_003"}}, to = {core = true}, belts = two_belts()})
local at = function(x, z) return map.cells[CORE.key(math.floor(x / CELL), math.floor(z / CELL))] end
check(at(-400, -320).d_from == 0 and at(-500, -100).d_from == 0 and #map.from_cells == 2,
	"from an anchor list: both anchors' cells have d_from 0")

-- Camps on POIs.
local function camp_unit(m, id)
	for _, unit in ipairs(m.camps) do
		if unit.id == id then return unit end
	end
	return nil
end
local function check_poi_camp(m, unit, belt_index, label)
	check(unit and unit.x == 400 and unit.z == -500, label .. ": centre at the POI")
	local inside, outside = 0, true
	for _, c in ipairs(m.order) do
		local dx = math.max(c.i * CELL - 400, 0, 400 - (c.i * CELL + CELL))
		local dz = math.max(c.j * CELL + 500, 0, -500 - (c.j * CELL + CELL))
		local near = math.sqrt(dx * dx + dz * dz) < CORE.CAMP_RADIUS
		if near then
			inside = inside + 1
			if c.region ~= unit.region or c.belt ~= belt_index then outside = false end
		elseif c.region == unit.region then
			outside = false
		end
	end
	check(inside > 0 and inside == unit.region.size and outside,
		label .. ": its region is the cells the camp radius reaches (" .. inside .. ")")
	check(m.region_at(400, -500) == unit.region and unit.region.camp == unit,
		label .. ": the POI's column lies in the camp region")
end
-- The POI (400, -500) sits in the southern half: on the low belt. The camp
-- states its belt; one belt away is fine.
map = build(with_camps({bandit_camp({roster = roster("highling")})}))
local unit = camp_unit(map, "bandits")
check(unit and unit.belt.id == "high" and unit.poi_belt.id == "low" and #map.warnings == 0,
	"a camp on a POI stands in its stated belt; the POI cell's own belt is kept")
check_poi_camp(map, unit, 2, "stated belt")
check(unit.levels_by_role.highling[1] == 15 and unit.levels[2] == 20 and unit.region.levels[2] == 20,
	"the stated belt's levels")
check(unit.tag == A .. "/bandits" and unit.is_camp and unit.rosters.day == unit.camp.roster,
	"the unit spawns in the camp's stead (tag, rosters, is_camp)")
local st = CORE.stats(map).camps[1]
check(st.poi == "Test Bandit Camp" and st.poi_belt == "low", "stats name the POI and its cell's belt")
-- More than one belt away: a warning (stats), the camp still stands.
local three = {
	{id = "low", share = 34, levels = {11, 14}, kinds = kind("low_open", "lowling")},
	{id = "mid", share = 33, levels = {15, 17}, kinds = kind("mid_open", "highling")},
	{id = "high", share = 33, levels = {18, 20}, kinds = kind("high_open", "highling")},
}
local function three_camps(belt)
	local recipe = with_camps({bandit_camp({belt = belt})})
	recipe.belts = deep_copy(three)
	return recipe
end
map = build(three_camps("high"))
unit = camp_unit(map, "bandits")
check(unit and unit.poi_belt.id == "low" and #map.warnings == 2 and
	map.warnings[1]:find("states belt high, its POI lies in belt low", 1, true) ~= nil and
	map.warnings[2]:find("more than one belt from the land beside its POI", 1, true) ~= nil and
	CORE.stats(map).warnings[1] == map.warnings[1] and #map.problems == 0,
	"two belts away: warnings (the stated belt, the step at the POI's cell), the camp stands (" ..
	tostring(map.warnings[1]) .. ")")
map = build(three_camps("mid"))
check(camp_unit(map, "bandits") and #map.warnings == 0, "one belt away: no warning")
-- A generated camp keeps `apart` from a camp on a POI.
local recipe = with_camps({bandit_camp({roster = roster("lowling"), belt = "low"}),
	{id = "gen", name = "Gen", belt = "low", roster = roster("lowling"), slots = 4,
		respawn = {30, 60}, min_player_distance = 16, apart = 30}})
map = build(recipe)
local poi_unit, gen = camp_unit(map, "bandits"), camp_unit(map, "gen")
check(poi_unit and gen and math.max(math.abs(gen.cell.i - poi_unit.cell.i),
	math.abs(gen.cell.j - poi_unit.cell.j)) >= 30, "a generated camp stays apart from a POI camp")
check(gen.region.size == 9 and gen.score ~= nil and poi_unit.score == nil,
	"the generated camp keeps its 3x3 block and score")
-- Two close POIs (Round 28 S2 review): each camp keeps its POI's own cell,
-- so both have a region; two POIs in one cell give a build problem, no crash.
local function close_world(mx, mz)
	local anchors = deep_copy(ANCHORS)
	anchors[#anchors + 1] = {id = "anchor_005", slot = "mirefolk", template = "mirefolk", x = mx, z = mz}
	local source = deep_copy(SOURCE)
	source.anchors[#source.anchors + 1] = {id = "anchor_005", zone_numeric_id = 1,
		slot_id = "mirefolk", template_id = "mirefolk"}
	local zones = {}
	for k, v in pairs(ZONES) do zones[k] = v end
	zones.anchor = function(zone, slot)
		if zone ~= A then return nil end
		for _, a in ipairs(anchors) do
			if a.slot == slot then return {x = a.x, y = 20, z = a.z, id = a.id} end
		end
		return nil
	end
	local q = CORE.queries({zones = zones, road_polylines = {}, source = source,
		column_values_at = function() return "land" end})
	local c = ctx()
	c.pois = function(zone) return CORE.zone_pois(source, zone, {anchor_002 = "Test Bandit Camp",
		anchor_003 = "Test Hideout", anchor_005 = "Test Fen"}) end
	local rec = with_camps({bandit_camp(), bandit_camp({id = "fen", site = {poi = "mirefolk"}})})
	return CORE.build(A, q, CORE.parse_recipe(A, rec, c))
end
map = close_world(420, -480) -- the next cell, inside the bandit camp's radius
local bandits, fen = camp_unit(map, "bandits"), camp_unit(map, "fen")
check(bandits and fen and fen.region and fen.region.size >= 1 and bandits.region.size >= 1 and
	map.region_at(420, -480) == fen.region and map.region_at(400, -500) == bandits.region,
	"two close POIs: each camp holds its POI's own cell")
map = close_world(405, -505) -- the same cell
check(camp_unit(map, "bandits") and not camp_unit(map, "fen") and #map.problems == 1 and
	map.problems[1]:find("shares its cell with camp bandits", 1, true) ~= nil,
	"two POIs in one cell: a build problem for the second (" .. tostring(map.problems[1]) .. ")")
-- A leader at the POI camp.
map = build(with_camps({bandit_camp()},
	{{role = "chief", at = {camp = "bandits"}, respawn = 300}}))
check(map.leaders[1].x == 400 and map.leaders[1].z == -500 and map.leaders[1].level == 20,
	"a leader at a POI camp stands at the POI at its fixed level")
print("C: builder")

print(("R28 S2 PORTABLE PASS checks=%d"):format(checks))
