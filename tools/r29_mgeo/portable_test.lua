-- Round 29 Lane M-geo portable test (LuaJIT): the middle road and the moved
-- anchors on real worlds.
--
--   luajit tools/r29_mgeo/portable_test.lua [REPO] [SEED ...]
--
-- Per SEED (default 42 7 2026) the world with its roads is built as main
-- builds it (tools/r25_road_poi/world.lua: zones, roster, height, road
-- layout, every POI blueprint prepared against its catalogue row) and:
--   1. no road of the network failed to route (stats.failed is unset);
--   2. one primary road joins Highcourt and Gor Drazhak, crosses z = 0 at
--      |x| < 150 and stays within |x| < 300 between the two capitals' edges;
--   3. Coalbrand Yard and Sunderstrap Camp stand at |x| >= 80, and every
--      anchor of the source stands in its own zone on land (the zone field's
--      self-check, observed through the session).
-- 4. A generated camp on a steep belt (once, seed 42, the world as the
--    region tools build it): no block of Blackwind Rise's belt l34_37 meets
--    the slope rule, so the bandit hideout takes the flattest block that
--    meets every other rule (score 0, slope at most HIGH_SLOPE) and its
--    leader stands at the camp.
-- The Battlegrounds width itself is measured by zone_check.lua next to this
-- file. Prints "R29 MGEO PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"42", "7", "2026"} end
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local world = dofile(repo .. "/tools/r25_road_poi/world.lua")
for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local W = world(repo, seed)
	local S, source, built = W.session, W.source, W.built
	check(built and built.stats, "built layout with stats, seed " .. seed)
	check(not built.stats.failed, ("every road routes, seed %s (failed %s)"):format(seed,
		tostring(built.stats.failed)))

	-- 2. the middle road
	local hc = S.anchor("elandor_highcourt", "capital")
	local gd = S.anchor("kragmar_gor_drazhak", "capital")
	check(hc and gd, "both capital anchors, seed " .. seed)
	local road
	for _, r in ipairs(built.roads) do
		if (r.a == hc.id and r.b == gd.id) or (r.a == gd.id and r.b == hc.id) then road = r end
	end
	check(road ~= nil, "a road joins Highcourt and Gor Drazhak, seed " .. seed)
	check(road.kind == "primary", "the middle road is primary, seed " .. seed)
	local cross, max_x = nil, 0
	for i = 2, #road.X do
		local z1, z2 = road.Z[i - 1], road.Z[i]
		if (z1 <= 0) ~= (z2 <= 0) then cross = cross or road.X[i] end
		-- between the capitals' 532-node squares
		if math.abs(road.Z[i]) < 1500 - 266 then max_x = math.max(max_x, math.abs(road.X[i])) end
	end
	check(cross and math.abs(cross) < 150, ("the middle road crosses z = 0 at |x| < 150, seed %s (x %s)")
		:format(seed, tostring(cross)))
	check(max_x < 300, ("the middle road stays within |x| < 300, seed %s (%.0f)"):format(seed, max_x))

	-- 3. anchors
	for _, slot in ipairs({{"elandor_ashenward_march", "bandit_1"}, {"kragmar_bannerbreak_mesa", "bandit_1"}}) do
		local a = S.anchor(slot[1], slot[2])
		check(a and math.abs(a.x) >= 80, "camp off the middle at |x| >= 80: " .. slot[1])
	end
	for _, a in ipairs(source.anchors) do
		local zone = source.zones[a.zone_numeric_id].id
		local x, z = a.position.x, a.position.z
		check(S.id_at(x, z) == zone and S.water_class_at(x, z) == "land",
			("anchor %s in %s on land, seed %s"):format(a.id, zone, seed))
	end
	print(("  seed %s: middle road %d nodes, crosses z = 0 at x = %.0f, max |x| %.0f (%.1f s)")
		:format(seed, #road.X, cross, max_x, os.clock() - t0))
end
do
	local t0 = os.clock()
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
	local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, "42")
	local zone = "kragmar_blackwind_rise"
	local q = CORE.queries({zones = W.session, column_values_at = W.planner_source.column_values_at,
		road_polylines = W.wp40.road_polylines, source = W.source})
	local record = W.session.get(zone)
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json"))
	local recipe = CORE.parse_recipe(zone, data.recipe, {band = {record.level_min, record.level_max},
		role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
		leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
		pois = function(id) return CORE.zone_pois(W.source, id) end})
	local m = CORE.build(zone, q, recipe)
	local hideout
	for _, unit in ipairs(m.camps) do
		if unit.id == "bandit_hideout" then hideout = unit end
	end
	check(hideout ~= nil and hideout.score == 0, "the hideout stands on the flattest block (score 0)")
	check(hideout.slope > CORE.CAMP_SLOPE and hideout.slope <= CORE.HIGH_SLOPE,
		("its slope %.3f lies between CAMP_SLOPE and HIGH_SLOPE"):format(hideout.slope))
	check(#m.problems == 0, "no problem in " .. zone .. ": " .. table.concat(m.problems, "; "))
	local leader
	for _, l in ipairs(m.leaders) do
		if l.role == "grave_broker_mute" then leader = l end
	end
	check(leader and leader.level == 37, "the hideout's leader stands")
	print(("  steep camp: %s at %d,%d (%.1f s)"):format(hideout.id, hideout.x, hideout.z, os.clock() - t0))
end
print(("R29 MGEO PORTABLE PASS checks=%d"):format(checks))
