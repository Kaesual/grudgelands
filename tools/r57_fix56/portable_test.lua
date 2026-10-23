-- Round 57 lane FIX56 portable test (LuaJIT): bays are not ocean (ruling
-- 23, docs/design/mounts.md §4.1).
--
--   luajit tools/r57_fix56/portable_test.lua [repo]
--
-- Builds the zones session of three seeds (two fleet seeds and the user's
-- world "test") as the runtime does
-- (wp40/world_assembly.lua, without the capitals; about 10 s per seed) and
-- asks the REAL flight rule (grug_mounts flight.lua column_flight_state)
-- with that session as grug_zones. Checks, per seed:
--   S  bay shore columns (found by tools/r57_fix56/bay_scan.lua): the
--      coastal belt along a bay's shore outside the bay's body. Generation
--      is unchanged (the horizontal class and the planner's column tuple
--      still say coastal_shelf, no bay id); the gameplay class is
--      planned_water, the water query "bay" with the owning zone; the zone's
--      own faction may fly there, the other one not ("enemy").
--   O  an open-sea column: deep_ocean, "ocean" for both factions.
--   C  bay-mouth caps: columns inside a bay's body past its mouth cut
--      (zone_field bay_at names the bay, the class is not planned water and
--      no bay shore): "ocean" for both factions.
-- The third seed is the user's world "test" with the example of ruling 23,
-- (-609, -2285) in Goldmead Vale.
-- Prints "R57 FIX56 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local SEEDS = {
	{seed = "12345",
		shore = {{-1220, -1840, "elandor_whitebridge_shire", "accord"},
			{-692, -2040, "elandor_goldmead_vale", "accord"},
			{1596, 3152, "kragmar_kapok_cradle", "throng"}},
		open = {0, -3900}, caps = {{-955, -2950, 1}, {930, 3080, 4}}},
	-- the user's world "test" (Round 57 ruling 23): the example column
	-- (-609, 9, -2285), Goldmead Vale, was belt and no-fly up to 0.56
	{seed = "476085000009918749",
		shore = {{-609, -2285, "elandor_goldmead_vale", "accord"}},
		open = {0, -3900}, caps = {{-955, -3150, 1}, {930, 3200, 4}}},
	{seed = "6866842473207",
		shore = {{-932, -1936, "elandor_whitebridge_shire", "accord"}},
		open = {0, -3900}, caps = {{-955, -2950, 1}, {930, 2950, 4}}},
}

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
rawset(_G, "core", rawget(_G, "core") or {})
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local A = dofile(dir .. "/world_assembly.lua")(dir, common.new_sha256())
local zones_holder = {}
rawset(_G, "grug_zones", setmetatable({}, {__index = function(_, key)
	return zones_holder.session[key]
end}))
rawset(_G, "grug_mounts", {})
dofile(repo .. "/mods/PLAYER/grug_mounts/flight.lua")
local mounts = grug_mounts
local OTHER = {accord = "throng", throng = "accord"}

for _, row in ipairs(SEEDS) do
	local seed = row.seed
	local W = A.world(seed)
	local session, planner_source = W.zones().new_with_planner_source_runtime(seed, 1)
	zones_holder.session = session
	local source = W.place()
	local horizontal = W.horizontal_factory({source = source, schemas = A.schemas,
		canonical = A.canonical, deterministic = A.deterministic,
		raw_sha256 = common.new_sha256()}).new(seed)
	local field = dofile(dir .. "/zone_field.lua").new_checked(seed, source, source.zone_field)
	for _, c in ipairs(row.shore) do
		local x, z, zone, faction = c[1], c[2], c[3], c[4]
		local at = ("S %s (%d,%d)"):format(seed, x, z)
		local class, _, _, bay_id = horizontal.classification_values_at(x, z)
		eq(class, "coastal_shelf", at .. ": generation class")
		eq(bay_id, nil, at .. ": no bay id in generation")
		eq((planner_source.column_values_at(x, z)), "coastal_shelf",
			at .. ": the planner's column tuple")
		check(horizontal.bay_shore_at(x, z) ~= nil, at .. ": a bay's shore")
		eq(session.water_class_at(x, z), "planned_water", at .. ": gameplay class")
		local query, query_zone = session.water_query_at(x, z)
		eq(query, "bay", at .. ": water query")
		eq(query_zone, zone, at .. ": water query zone")
		eq(session.id_at(x, z), zone, at .. ": zone")
		local legal, why = mounts.column_flight_state(faction, x, z)
		eq(legal, true, at .. ": " .. faction .. " flies")
		eq(why, nil, at .. ": no reason")
		legal, why = mounts.column_flight_state(OTHER[faction], x, z)
		eq(legal, false, at .. ": " .. OTHER[faction] .. " does not")
		eq(why, "enemy", at .. ": " .. OTHER[faction] .. "'s reason")
	end
	do
		local x, z = row.open[1], row.open[2]
		local at = ("O %s (%d,%d)"):format(seed, x, z)
		eq(session.water_class_at(x, z), "deep_ocean", at .. ": class")
		for _, faction in ipairs({"accord", "throng"}) do
			local legal, why = mounts.column_flight_state(faction, x, z)
			eq(legal, false, at .. ": " .. faction .. " may not fly")
			eq(why, "ocean", at .. ": " .. faction .. "'s reason")
		end
	end
	for _, c in ipairs(row.caps) do
		local x, z, bay = c[1], c[2], c[3]
		local at = ("C %s (%d,%d)"):format(seed, x, z)
		eq((field.bay_at(x, z)), bay, at .. ": inside the bay's body")
		local class = session.water_class_at(x, z)
		check(class ~= "planned_water" and class ~= "land", at .. ": sea class (got " ..
			tostring(class) .. ")")
		eq(horizontal.bay_shore_at(x, z), nil, at .. ": past the mouth, no bay shore")
		for _, faction in ipairs({"accord", "throng"}) do
			local legal, why = mounts.column_flight_state(faction, x, z)
			eq(legal, false, at .. ": " .. faction .. " may not fly")
			eq(why, "ocean", at .. ": " .. faction .. "'s reason")
		end
	end
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	error(("R57 FIX56 PORTABLE FAIL %d of %d"):format(#failures, checks), 0)
end
print("R57 FIX56 PORTABLE PASS checks=" .. checks)
