-- Round 28 Lane S2c portable test (LuaJIT): the gameplay level bands of
-- grug_core/zone_bands.lua and the six front and island spawn recipes.
--
--   luajit tools/r28_s2c/portable_test.lua [REPO] [SEED]
--
-- A. zone_bands.apply sets Gravesalt Escarpment and The Skyglass Canopy to
--    51-60 and The Broken Causeway to 41-50 (Round 28 W1) on a record copy,
--    leaves every other zone alone and passes nil. The mapgen source keeps
--    its bands 51-59 and 31-40 (the world must not change).
-- B. grug_zones for real: the R7 authority (zone_authority.lua) installed on
--    the analytic world of SEED (default 42, tools/r25_road_poi/world.lua as
--    bench.lua does). get and at serve the gameplay band for the three
--    zones and the mapgen band for every other zone; the session's own
--    records keep the mapgen band, and the analytic level field
--    (surface_mob_level_at, which places plants, resources and P9G content)
--    stays inside it there and reaches its top.
-- C. The shipped recipes of the six zones parse with the game's own
--    spawn_regions_core.lua against the catalogue and the gameplay band; the
--    Gravesalt, Skyglass and Causeway recipes are refused under the mapgen
--    band.
-- D. Leaders on every seed (synthetic world): a kind without a region falls
--    back to the belt's open kind, then to the belt's largest region; two
--    leaders of one kind stand LEADER_SPACING apart; the level stays.
-- E. Every shipped recipe on the real world of seed 7: every leader stands
--    inside its belt and adjacent regions (eight neighbours) are at most one
--    belt apart; Engine Nine stands on Shattered Line at L50.
-- Prints "R28 S2C PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local seed = arg[2] or "42"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- zone -> {mapgen band, gameplay band}
local RAISED = {
	front_gravesalt_escarpment = {{51, 59}, {51, 60}},
	front_skyglass_canopy = {{51, 59}, {51, 60}},
	front_broken_causeway = {{31, 40}, {41, 50}},
}
local ZONES = {"front_broken_causeway", "front_shattered_line",
	"front_gravesalt_escarpment", "front_skyglass_canopy",
	"front_stormscale_summit", "front_wyrmglass_crown"}

local bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

-- ---------------------------------------------------------------------------
-- A. zone_bands.apply
-- ---------------------------------------------------------------------------
do
	local n = 0
	for _ in pairs(bands.bands) do n = n + 1 end
	check(n == 3, "A: exactly three gameplay bands")
	for _, row in ipairs(source.zones) do
		local copy = {id = row.id, level_min = row.level_min, level_max = row.level_max}
		check(bands.apply(copy) == copy, "A: apply returns the record " .. row.id)
		local raised = RAISED[row.id]
		if raised then
			check(row.level_min == raised[1][1] and row.level_max == raised[1][2],
				"A: the mapgen source keeps its band for " .. row.id)
			check(copy.level_min == raised[2][1] and copy.level_max == raised[2][2],
				"A: the gameplay band for " .. row.id)
		else
			check(copy.level_min == row.level_min and copy.level_max == row.level_max,
				"A: unchanged " .. row.id)
		end
		local keyed = bands.apply({level_min = row.level_min, level_max = row.level_max}, row.id)
		check(keyed.level_max == (raised and raised[2][2] or row.level_max),
			"A: apply by zone id " .. row.id)
	end
	check(bands.apply(nil) == nil, "A: nil stays nil")
	check(bands.apply({id = "front_gravesalt_escarpment"}, "elandor_dawnmere_fields").level_max == nil,
		"A: an explicit zone id wins over record.id")
end

-- ---------------------------------------------------------------------------
-- B. grug_zones for real
-- ---------------------------------------------------------------------------
local W
do
	local t0 = os.clock()
	W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
	local S = W.session
	local sha_hex = function(bytes) return W.common.hex(W.sha(bytes)) end
	_G.core = {sha256 = sha_hex, is_protected = function() return false end,
		check_player_privs = function() return false end, log = function() end}
	_G.grug_zones = nil
	_G.grug_core = {get_player_faction = function() return "accord" end, zone_bands = bands}
	assert(loadfile(repo .. "/mods/CORE/grug_core/zone_authority.lua"))()
	grug_core.install_zone_authority(S, dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_consumer_payload.lua")(W.source, sha_hex), W.protection)
	print(("  world of seed %s built and authority installed in %.1f s"):format(seed, os.clock() - t0))

	for _, row in ipairs(source.zones) do
		local record = grug_zones.get(row.id)
		local own = S.get(row.id)
		check(own.level_min == row.level_min and own.level_max == row.level_max,
			"B: the session keeps the mapgen band for " .. row.id)
		local raised = RAISED[row.id]
		check(record.level_min == (raised and raised[2][1] or row.level_min), "B: level_min " .. row.id)
		check(record.level_max == (raised and raised[2][2] or row.level_max), "B: level_max " .. row.id)
		check(grug_zones.get(row.id) ~= record, "B: get hands out a fresh copy " .. row.id)
		-- at(): the hub of each zone (owned by the zone on every seed where the
		-- hub is land; skip a hub that is not).
		local at = grug_zones.at({x = row.hub.x, y = 10, z = row.hub.z})
		if at and at.id == row.id then
			check(at.level_max == record.level_max, "B: at serves the gameplay band " .. row.id)
		end
	end
	check(grug_zones.get("no_such_zone") == nil, "B: an unknown zone is nil")
	local copy = grug_zones.get("front_gravesalt_escarpment")
	copy.level_max = 99
	check(grug_zones.get("front_gravesalt_escarpment").level_max == 60, "B: copies are independent")
	check(S.get("front_gravesalt_escarpment").level_max == 59, "B: the session record is untouched")

	-- The analytic level field of the three zones stays the mapgen's band.
	for zone, raised in pairs(RAISED) do
		local lo, hi, n = 99, 0, 0
		local hub = S.get(zone).hub
		for x = hub.x - 700, hub.x + 700, 24 do
			for z = -360, 360, 24 do
				if grug_zones.id_at(x, z) == zone and grug_zones.water_class_at(x, z) == "land" then
					local level = grug_zones.surface_mob_level_at(x, z)
					lo, hi, n = math.min(lo, level), math.max(hi, level), n + 1
				end
			end
		end
		check(n > 200, "B: enough land samples in " .. zone)
		check(lo >= raised[1][1] and hi == raised[1][2],
			("B: the analytic field of %s stays L%d-%d"):format(zone, lo, hi))
	end
end

-- ---------------------------------------------------------------------------
-- C. The six shipped recipes
-- ---------------------------------------------------------------------------
do
	local CORE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local f = assert(io.open(path, "rb"))
		local t = f:read("*a")
		f:close()
		return t
	end
	local catalogue = {}
	for _, row in ipairs(json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))) do
		catalogue[row.role] = row
	end
	local function ctx(band)
		return {band = band,
			role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
			leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
			pois = function(id) return CORE.zone_pois(W.source, id) end}
	end
	for _, zone in ipairs(ZONES) do
		local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json"))
		check(data.zone == zone and data.recipe ~= nil, "C: recipe file " .. zone)
		local record = grug_zones.get(zone)
		local band = {record.level_min, record.level_max}
		local ok, recipe = pcall(CORE.parse_recipe, zone, data.recipe, ctx(band))
		check(ok, "C: " .. zone .. " parses: " .. tostring(recipe))
		check(recipe.belts[#recipe.belts].levels[2] == band[2], "C: last belt ends at the band top " .. zone)
		for _, kind in ipairs(recipe.kinds) do
			for role in pairs(kind.roles) do
				check(catalogue[role] ~= nil, "C: catalogue role " .. role .. " in " .. zone)
			end
		end
		for _, leader in ipairs(recipe.leaders) do
			check(leader.level == catalogue[leader.role].levels[2],
				"C: leader " .. leader.role .. " at its catalogue level")
		end
		if RAISED[zone] then
			local refused = pcall(CORE.parse_recipe, zone, data.recipe, ctx(RAISED[zone][1]))
			check(not refused, "C: " .. zone .. " is refused under its mapgen band")
		end
	end
end

-- ---------------------------------------------------------------------------
-- D. Leaders on every seed, on a synthetic world (the builder)
-- ---------------------------------------------------------------------------
-- Zone A: x in [-640, 640), z in [-640, 0) (40 x 20 cells), between land
-- zones C (south, the entry) and B (north, the exit); no roads. Two belts by
-- rows. `north_biome` is the biome of the northern three quarters (the
-- whole top belt and some of the first).
local CORE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local SA, SB, SC = "zone_a", "zone_b", "zone_c"
local function synthetic(north_biome)
	local function zone_at(x, z)
		if x < -640 or x >= 640 then return nil end
		if z >= 0 and z < 320 then return SB end
		if z >= -640 and z < 0 then return SA end
		if z >= -960 and z < -640 then return SC end
		return nil
	end
	local zones = {
		id_at = zone_at,
		water_class_at = function(x, z) return zone_at(x, z) and "land" or "deep_ocean" end,
		terrain_height_at = function() return 20 end,
		biome_at = function(x, z) return z >= -480 and north_biome or "grug_meadows" end,
		hard_protection_kind_at = function() return nil end,
		anchor = function() return nil end,
		get = function(zone)
			if zone == SA then return {hub = {x = 0, z = -320}, level_min = 11, level_max = 20} end
			return nil
		end,
	}
	local source = {zones = {{id = SA, numeric_id = 1}, {id = SB, numeric_id = 2},
		{id = SC, numeric_id = 3}}, anchors = {}}
	return CORE.queries({zones = zones, road_polylines = {}, source = source,
		column_values_at = function() return "land" end})
end
local LEVELS = {low = {11, 14}, high = {15, 20}, chief = {18, 20}, warden = {20, 20}}
local LEADERS = {chief = true, warden = true}
local SCTX = {band = {11, 20},
	role_levels = function(role) return LEVELS[role] end,
	leader = function(role) return LEADERS[role] == true end}
local function skind(id, role, density)
	return {id = id, name = id, day = {{role = role, weight = 1}},
		night = {{role = role, weight = 1}}, density = density or "normal"}
end
local function srecipe(top_kinds, leaders)
	return {from = {border = SC}, to = {border = SB}, belts = {
		{id = "low", share = 50, levels = {11, 14}, kinds = {open = skind("low_open", "low")}},
		{id = "high", share = 50, levels = {15, 20}, kinds = top_kinds}},
		leaders = leaders}
end
local function sbuild(q, recipe)
	return CORE.build(SA, q, CORE.parse_recipe(SA, recipe, SCTX))
end
do
	-- The kind has no region (no forest anywhere): the belt's open kind.
	local q = synthetic("grug_meadows")
	local m = sbuild(q, srecipe({open = skind("high_open", "high"), forest = skind("high_wood", "high")},
		{{role = "chief", at = {kind = "high_wood", pick = "farthest_from_roads"}, respawn = 300}}))
	local l = m.leaders[1]
	check(#m.problems == 0 and l and l.fallback == "high_open" and l.region.kind.id == "high_open" and
		l.region.belt == 2 and l.level == 20, "D: a kind without a region falls back to the belt's open kind")
	check(CORE.stats(m).leaders[1].fallback == "high_open", "D: stats name the fallback")
	-- Neither the kind nor the open kind has a region (the top belt is swamp
	-- and its sea edges a shore kind): the belt's largest region.
	q = synthetic("grug_swamp")
	m = sbuild(q, srecipe({open = skind("high_open", "high"), swamp = skind("high_fen", "high", "sparse"),
		shore = skind("high_strand", "high", "dense"), forest = skind("high_wood", "high")},
		{{role = "chief", at = {kind = "high_wood", pick = "farthest_from_roads"}, respawn = 300}}))
	l = m.leaders[1]
	local largest
	for _, r in ipairs(m.regions) do
		if r.belt == 2 and (not largest or r.size > largest.size) then largest = r end
	end
	check(#m.problems == 0 and l and l.fallback == "high_fen" and l.region == largest and l.level == 20,
		"D: then the belt's largest region")
	-- Two leaders on one kind: the second keeps the spacing, both stand.
	q = synthetic("grug_meadows")
	m = sbuild(q, srecipe({open = skind("high_open", "high")}, {
		{role = "chief", at = {kind = "high_open", pick = "farthest_from_roads"}, respawn = 300},
		{role = "warden", at = {kind = "high_open", pick = "farthest_from_roads"}, respawn = 300}}))
	local a, b = m.leaders[1], m.leaders[2]
	local dx, dz = a and b and a.x - b.x or 0, a and b and a.z - b.z or 0
	check(#m.problems == 0 and a and b and a.role == "chief" and b.role == "warden" and
		a.fallback == nil and b.fallback == nil and dx * dx + dz * dz >= CORE.LEADER_SPACING * CORE.LEADER_SPACING and
		a.level == 20 and b.level == 20, "D: two leaders of one kind stand LEADER_SPACING apart")
	-- One leader alone takes the same cell as before (the best of the
	-- kind's largest region).
	local m1 = sbuild(q, srecipe({open = skind("high_open", "high")}, {
		{role = "chief", at = {kind = "high_open", pick = "farthest_from_roads"}, respawn = 300}}))
	check(m1.leaders[1].x == a.x and m1.leaders[1].z == a.z, "D: the first leader keeps its cell")
end

-- ---------------------------------------------------------------------------
-- E. Every shipped recipe on the real world of seed 7: every leader stands
--    and adjacent regions (eight neighbours) are at most one belt apart
--    (Shattered Line seed 7 had a two-belt step and no spot for Engine Nine).
-- ---------------------------------------------------------------------------
do
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local f = assert(io.open(path, "rb"))
		local t = f:read("*a")
		f:close()
		return t
	end
	local catalogue = {}
	for _, row in ipairs(json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))) do
		catalogue[row.role] = row
	end
	local t0 = os.clock()
	local W7 = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, "7")
	local S7 = W7.session
	local q = CORE.queries({zones = S7, column_values_at = W7.planner_source.column_values_at,
		road_polylines = W7.wp40.road_polylines, source = W7.source})
	local n, engine_nine = 0, nil
	for _, row in ipairs(source.zones) do
		local f = io.open(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. row.id .. ".spawns.json", "rb")
		local data = json.parse(f:read("*a"))
		f:close()
		if data.recipe then
			local record = bands.apply(S7.get(row.id))
			local recipe = CORE.parse_recipe(row.id, data.recipe, {band = {record.level_min, record.level_max},
				role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
				leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
				pois = function(id) return CORE.zone_pois(W7.source, id) end})
			local m = CORE.build(row.id, q, recipe)
			local st = CORE.stats(m)
			check(st.max_belt_jump <= 1, "E: " .. row.id .. " adjacent regions within one belt (" ..
				st.max_belt_jump .. ")")
			check(#m.leaders == #recipe.leaders, "E: every leader of " .. row.id .. " stands")
			for _, l in ipairs(m.leaders) do
				check(l.level >= recipe.belts[l.region.belt].levels[1] and
					l.level <= recipe.belts[l.region.belt].levels[2], "E: " .. l.role .. " inside its belt")
				if l.role == "siege_engine_nine" then engine_nine = l end
			end
			n = n + 1
		end
	end
	check(n >= 7, "E: the shipped recipes (" .. n .. ")")
	-- (Since the border rule (Round 28 W1) the Shattered Line rises toward
	-- The Skyglass Canopy and Engine Nine finds its own kind on seed 7; the
	-- fallback chain is part D's.)
	check(engine_nine and engine_nine.level == 50, "E: Engine Nine stands on Shattered Line seed 7 (L50, " ..
		tostring(engine_nine and engine_nine.fallback or "own kind") .. ")")
	print(("  seed 7: %d recipes built and checked in %.1f s"):format(n, os.clock() - t0))
end

print(("R28 S2C PORTABLE PASS checks=%d"):format(checks))
