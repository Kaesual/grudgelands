-- Round 28 Lane S2c portable test (LuaJIT): the gameplay level bands of
-- grug_core/zone_bands.lua and the six front and island spawn recipes.
--
--   luajit tools/r28_s2c/portable_test.lua [REPO] [SEED]
--
-- A. zone_bands.apply sets Gravesalt Escarpment and The Skyglass Canopy to
--    51-60 on a record copy, leaves every other zone alone and passes nil.
--    The mapgen source keeps its band 51-59 (the world must not change).
-- B. grug_zones for real: the R7 authority (zone_authority.lua) installed on
--    the analytic world of SEED (default 42, tools/r25_road_poi/world.lua as
--    bench.lua does). get and at serve 51-60 for the two zones and the
--    mapgen band for every other zone; the session's own records still say
--    51-59, and the analytic level field (surface_mob_level_at, which places
--    plants, resources and P9G content) stays inside 51-59 there and reaches
--    59.
-- C. The shipped recipes of the six zones parse with the game's own
--    spawn_regions_core.lua against the catalogue and the gameplay band; the
--    Gravesalt and Skyglass recipes are refused under the mapgen band.
-- Prints "R28 S2C PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local seed = arg[2] or "42"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local RAISED = {front_gravesalt_escarpment = true, front_skyglass_canopy = true}
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
	check(n == 2, "A: exactly two gameplay bands")
	for _, row in ipairs(source.zones) do
		local copy = {id = row.id, level_min = row.level_min, level_max = row.level_max}
		check(bands.apply(copy) == copy, "A: apply returns the record " .. row.id)
		if RAISED[row.id] then
			check(row.level_min == 51 and row.level_max == 59,
				"A: the mapgen source keeps 51-59 for " .. row.id)
			check(copy.level_min == 51 and copy.level_max == 60, "A: 51-60 for " .. row.id)
		else
			check(copy.level_min == row.level_min and copy.level_max == row.level_max,
				"A: unchanged " .. row.id)
		end
		local keyed = bands.apply({level_min = row.level_min, level_max = row.level_max}, row.id)
		check(keyed.level_max == (RAISED[row.id] and 60 or row.level_max),
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
		check(record.level_min == row.level_min, "B: level_min " .. row.id)
		check(record.level_max == (RAISED[row.id] and 60 or row.level_max), "B: level_max " .. row.id)
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

	-- The analytic level field of the two zones stays the mapgen's 51-59.
	for zone in pairs(RAISED) do
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
		check(lo == 51 and hi == 59, ("B: the analytic field of %s stays L%d-%d"):format(zone, lo, hi))
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
			local refused = pcall(CORE.parse_recipe, zone, data.recipe, ctx({51, 59}))
			check(not refused, "C: " .. zone .. " is refused under the mapgen band 51-59")
		end
	end
end

print(("R28 S2C PORTABLE PASS checks=%d"):format(checks))
