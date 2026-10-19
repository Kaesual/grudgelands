-- Round 52 lane AMB portable test (LuaJIT): ambience by biome and height
-- (round52-ambience-plan.md §1, §2, §3.2).
--
--   luajit tools/r52_amb/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua and data.lua, and
-- grug_core/atmosphere_zones.lua on a fake engine with a stand-in zone
-- authority. The runtime of the layers (sounds, fades, the probe on fake
-- nodes, the debug line) is checked in tools/r34_s2 block R. Checks:
--   G  group lookup: every biome of the world's surface rows
--      (wp40/r7_r6_manifest.lua SURFACE_ROWS) in the group of §2, and every
--      group with its bed row;
--   K  the sound key: zone overrides before the biome, the ocean where no
--      zone owns the column, keep in the underground mood;
--   L  the layer curves at the ruling points (-15, +10, +60, +30, +100, -4,
--      -16), the caps, the peak wind only near the surface;
--   S  a layer's steps: start only at 3 %, the dead band, the 0.01 floor and
--      the stop after three passes there, a key change;
--   V  the cave verdict with its two-pass hysteresis and the probe's reuse;
--   A  the atmosphere on a fake engine: the depth below the surface (the
--      terrain, the water surface over water, sea level over the ownerless
--      deep ocean), the column memo (the same column asks the authority
--      nothing), the underground band (in at 20, out below 16) and the
--      ocean rule;
--   C  calls by sound key and time, the surface level and the wolves'
--      biome sub-group (the rows of §3.2 step 8 on a test table, since
--      their files come with the user's approval);
--   P  the /ambience debug word.
-- Prints "R52 AMB PORTABLE PASS checks=<n>" or the failures (exit 1).
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end

local MOD = repo .. "/mods/CORE/grug_ambience"
local R = dofile(MOD .. "/rules.lua")
local D = dofile(MOD .. "/data.lua")

-- ---------------------------------------------------------------------------
-- G  group lookup
-- ---------------------------------------------------------------------------
do
	local manifest = io.open(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua"):read("*a")
	local rows = manifest:match("local SURFACE_ROWS = %[%[\n(.-)%]%]")
	local biomes = {}
	for id in (rows or ""):gmatch("([%w_]+)|[^\n]*") do biomes[#biomes + 1] = id end
	check(#biomes == 16, "G the world has 16 surface biomes (" .. #biomes .. ")")
	local WANT = {
		grug_meadows = "temperate", grug_deep_forest = "temperate", grug_elf_forest = "temperate",
		grug_pine_hills = "temperate", grug_savanna = "savanna", grug_deep_jungle = "jungle",
		grug_jungle_fringe = "jungle", grug_jungle_edge = "jungle", grug_badlands = "badlands",
		grug_badlands_east = "badlands", grug_swamp = "swamp", grug_crags = "crags",
		grug_crags_snowy = "crags_snowy", grug_blight = "blight", grug_bone_forest = "blight",
		grug_beach = "beach",
	}
	for _, id in ipairs(biomes) do
		check(D.groups[id] ~= nil and D.groups[id] == WANT[id],
			"G " .. id .. " -> " .. tostring(D.groups[id]) .. " (§2: " .. tostring(WANT[id]) .. ")")
	end
	local count = 0
	for id, group in pairs(D.groups) do
		count = count + 1
		check(D.region[group] ~= nil, "G group " .. group .. " has a bed row")
		check(id:sub(1, 5) == "grug_", "G keyed by the full biome id: " .. id)
	end
	check(count == 16, "G no group for a biome the world does not have")
	for mood in pairs(D.overrides) do check(D.region[mood] ~= nil, "G override " .. mood .. " has a row") end
end

-- ---------------------------------------------------------------------------
-- K  the sound key
-- ---------------------------------------------------------------------------
do
	check(R.sound_key(D, "human", true, "grug_pine_hills") == "temperate", "K pine hills: temperate")
	check(R.sound_key(D, "orc", true, "grug_meadows") == "temperate",
		"K the biome, not the race zone (ruling 1)")
	check(R.sound_key(D, "battlegrounds", true, "grug_savanna") == "battlegrounds" and
		R.sound_key(D, "dragon_island", true, "grug_beach") == "dragon_island" and
		R.sound_key(D, "ocean", true, nil) == "ocean", "K zone overrides by mood")
	check(R.sound_key(D, nil, true, nil) == "ocean", "K no zone owns the column: the ocean, also with the atmosphere off")
	check(R.sound_key(D, "underground", true, "grug_meadows") == nil, "K underground mood: keep")
	check(R.sound_key(D, "default", false, nil) == nil, "K no authority yet: keep")
end

-- ---------------------------------------------------------------------------
-- L  the layer curves (ruling 7)
-- ---------------------------------------------------------------------------
do
	local function at(depth, y, cave) return R.layer_levels(D, depth, y or 9, cave) end
	local _, s, w, c
	s = at(0) check(near(s, 1), "L surface 100 % at 0")
	s = at(15) check(near(s, 0), "L surface 0 % at -15")
	s = at(7.5) check(near(s, 0.5), "L surface 50 % at -7.5 (linear)")
	s = at(-10) check(near(s, 1), "L surface 100 % up to +10")
	s = at(-35) check(near(s, 0.5), "L surface 50 % at +35")
	s = at(-60) check(near(s, 0), "L surface 0 % at +60")
	s = at(-200) check(near(s, 0), "L surface 0 % far above")
	s = at(40) check(near(s, 0), "L surface 0 % deep down")
	_, w = at(-30) check(near(w, 0), "L wind 0 % at +30")
	_, w = at(-65) check(near(w, 0.25), "L wind 25 % at +65")
	_, w = at(-100) check(near(w, 0.5), "L wind full = 50 % at +100")
	_, w = at(-300) check(near(w, 0.5), "L wind stays at 50 % above")
	_, _, c = at(4, 9, true) check(near(c, 0), "L cave 0 % at -4")
	_, _, c = at(10, 9, true) check(near(c, 0.2), "L cave 20 % at -10")
	_, _, c = at(16, 9, true) check(near(c, 0.4), "L cave full = 40 % at -16")
	_, _, c = at(80, 9, true) check(near(c, 0.4), "L cave 40 % deeper")
	_, _, c = at(16, 9, false) check(c == 0, "L no cave bed in a dug tunnel")
	s, w, c = R.layer_levels(D, nil, 9, true)
	check(s == 1 and w == 0 and c == 0, "L depth unknown: the surface alone")
	local P = D.layers.peak
	check(P.level == 0.25 and P.ramp == 15 and P.max_depth == 4, "L peak wind: 25 %, over 15 nodes, near the surface")
	_, w = at(0, P.y) check(near(w, 0), "L peak wind 0 at its start")
	_, w = at(0, P.y + P.ramp) check(near(w, 0.25), "L peak wind 25 % at the peak top")
	_, w = at(-2, P.y + 100) check(near(w, 0.25), "L peak wind capped at 25 %")
	_, w = at(4, P.y + P.ramp) check(near(w, 0.25), "L peak wind 4 nodes into the ground")
	_, w = at(5, P.y + P.ramp) check(near(w, 0), "L no peak wind in a tunnel inside the mountain")
	_, w = at(-90, P.y + P.ramp) check(near(w, (90 - 30) / 70 * 0.5), "L the higher of the two winds")
end

-- ---------------------------------------------------------------------------
-- S  a layer's steps (§3.2 steps 4 and 11)
-- ---------------------------------------------------------------------------
do
	local l = {playing = false, level = 0, base = 0, idle = 0}
	check(R.layer_step(l, "wind", 0.02, 0.2) == nil and not l.playing, "S no start below 3 %")
	check(R.layer_step(l, false, 0.5, 0.2) == nil, "S no start without a bed")
	check(R.layer_step(l, "wind", 0.03, 0.2) == "start" and l.playing and near(l.level, 0.03),
		"S a start at 3 %")
	check(R.layer_step(l, "wind", 0.05, 0.2) == nil and near(l.level, 0.03), "S 2 % more: the dead band")
	check(R.layer_step(l, "wind", 0.06, 0.2) == "fade" and near(l.level, 0.06), "S 3 % more: a fade")
	check(R.layer_step(l, "wind", 0.06, 0.1) == "fade" and l.base == 0.1, "S a new base gain: a fade")
	check(R.layer_step(l, "wind", 0, 0.1) == "fade" and l.level == R.LEVEL_FLOOR and l.idle == 1,
		"S level 0: fade to the floor, keep the sound")
	check(R.layer_step(l, "wind", 0, 0.1) == nil and l.idle == 2, "S a second pass at 0: nothing")
	check(R.layer_step(l, "wind", 0, 0.1) == "stop" and not l.playing, "S the third pass at 0: stop")
	check(R.layer_step(l, "wind", 0, 0.1) == nil, "S stopped stays quiet")
	-- hovering at the threshold: back above 0 before the third pass keeps it
	R.layer_step(l, "wind", 0.1, 0.1)
	R.layer_step(l, "wind", 0, 0.1)
	R.layer_step(l, "wind", 0, 0.1)
	check(R.layer_step(l, "wind", 0.005, 0.1) == nil and l.playing and l.idle == 0,
		"S back above 0 within two passes: the same sound, no restart")
	R.layer_step(l, "wind", 0.02, 0.1)
	check(l.playing and l.level == R.LEVEL_FLOOR, "S a small level keeps the floor")
	check(R.layer_step(l, "wind", 0.2, 0.1) == "fade" and near(l.level, 0.2), "S and rises from it")
	-- a target that falls to 0 from just above the floor still fades to it
	local m = {playing = true, key = "cave", level = 0.02, base = 0.2, idle = 0}
	check(R.layer_step(m, "cave", 0, 0.2) == "fade" and m.level == R.LEVEL_FLOOR, "S 0 always reaches the floor")
	-- a key change: switch at a level, stop without one
	local k = {playing = true, key = "cave", level = 0.4, base = 0.2, idle = 0}
	check(R.layer_step(k, "cave_deep", 0.4, 0.2) == "switch" and k.key == "cave_deep" and k.playing,
		"S another bed: switch")
	check(R.layer_step(k, false, 0.4, 0.2) == "stop" and not k.playing and k.key == false,
		"S no bed (under water, music): stop at once")
	check(R.layer_step(k, "cave", 0.4, 0.2) == "start", "S back: a new sound")
	check(R.LEVEL_STEP == 0.03 and R.LEVEL_FLOOR == 0.01 and R.FLOOR_PASSES == 3, "S the plan's numbers")
end

-- ---------------------------------------------------------------------------
-- V  the cave verdict and the probe's reuse
-- ---------------------------------------------------------------------------
do
	local T = D.cave.threshold
	local c = {seen = 0}
	check(R.cave_step(c, T + 0.1, T) == false, "V one open pass: not yet a cave")
	check(R.cave_step(c, T + 0.1, T) == true, "V two open passes: a cave")
	check(R.cave_step(c, T - 0.1, T) == true, "V one closed pass: still a cave")
	check(R.cave_step(c, T + 0.1, T) == true and c.seen == 0, "V the closed pass forgotten")
	R.cave_step(c, 0, T)
	check(R.cave_step(c, 0, T) == false, "V two closed passes: a tunnel")
	check(R.cave_step(c, T, T) == false and R.cave_step(c, T, T) == true, "V the threshold itself counts as open")
	local p = {age = 0}
	check(R.probe_due(p, {x = 0, y = -10, z = 0}), "V the first probe runs")
	check(not R.probe_due(p, {x = 1, y = -10, z = 1}), "V moved 1.4 nodes: reuse")
	check(not R.probe_due(p, {x = 1, y = -10, z = 1}), "V a second pass in place: reuse")
	check(R.probe_due(p, {x = 1, y = -10, z = 1}), "V the third pass: probe again")
	check(R.probe_due(p, {x = 1, y = -12, z = 1}), "V moved 2 nodes: probe at once")
	-- the deep cave bed's band round y -500 (review item, file step)
	check(D.deep_y == -500 and D.deep_band == 2, "V the deep bed below -500, band 2")
	check(R.deep_cave(D, nil, -501) == false and R.deep_cave(D, nil, -502.5) == true,
		"V into the deep bed only below -502")
	check(R.deep_cave(D, true, -499) == true and R.deep_cave(D, true, -497.5) == false,
		"V out of it only above -498")
	local flips, deep = 0, false
	for _, y in ipairs({-499, -501, -500, -501.5, -499.5, -500.5, -501}) do
		local now = R.deep_cave(D, deep, y)
		if now ~= deep then flips = flips + 1 end
		deep = now
	end
	check(flips == 0, "V a cave floor at -500 never swaps the beds")
	local cells = #D.cave.grid_xz * #D.cave.grid_xz * #D.cave.grid_y
	check(cells == 75 and D.cave.min_depth == 4, "V a 5 x 3 x 5 grid (75 reads), only below 4 nodes")
end

-- ---------------------------------------------------------------------------
-- A  the atmosphere on a fake engine
-- ---------------------------------------------------------------------------
do
	local steps, joins, leaves, loaded = {}, {}, {}, {}
	local players = {}
	local applied = {}
	local queries = {terrain = 0, water = 0, id = 0, biome = 0}
	-- The stand-in world: x < 0 meadows at y 20; x in [0, 100) a lake over
	-- a bed at y -3 with its surface at y 2; x >= 100 the deep ocean (no
	-- owner, floor y -40); z >= 1000 a coastal belt over a shelf at y 3
	-- (water depth 1 - 3 <= 0); every column with z >= 500 lies 3 nodes
	-- higher for each 10 nodes of x (rolling ground).
	local function terrain(x, z)
		if z >= 1000 then return 3 end
		if x >= 100 then return -40 end
		if x >= 0 then return -3 end
		if z >= 500 then return 20 + math.floor(-x / 10) * 3 end
		return 20
	end
	local zones = {
		terrain_height_at = function(x, z) queries.terrain = queries.terrain + 1 return terrain(x, z) end,
		water_query_at = function(x, z)
			queries.water = queries.water + 1
			if z >= 1000 then return "belt", "zone_a", 10, 30, 1 - terrain(x, z), false end
			if x >= 100 then return "open_sea", nil, nil, 500, 1 - terrain(x, z), true end
			if x >= 0 then return "lake", "zone_a", 5, nil, 5, false end
			return nil
		end,
		id_at = function(x, z)
			queries.id = queries.id + 1
			if x >= 100 and z < 1000 then return nil end
			return "zone_a"
		end,
		biome_at = function(x, z)
			queries.biome = queries.biome + 1
			if x >= 100 and z < 1000 then return nil end
			return "grug_meadows"
		end,
		get = function() return {race_region = "human", level_min = 1, level_max = 10} end,
	}
	local installed = false
	local saved_core, saved_grug_core, saved_zones = rawget(_G, "core"), rawget(_G, "grug_core"),
		rawget(_G, "grug_zones")
	local us = 0
	rawset(_G, "core", {
		settings = {get_bool = function(_, _, default) return default end},
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		get_player_by_name = function(name) return players[name] end,
		get_us_time = function() us = us + 1 return us end,
		log = function() end,
	})
	rawset(_G, "grug_zones", zones)
	rawset(_G, "grug_core", {
		atmosphere_presets = {default = {}},
		ATMOSPHERE_DEFAULT = "default",
		atmosphere_enabled = true,
		zone_authority_installed = function() return installed end,
		set_atmosphere = function(player, key) applied[player:get_player_name()] = key return true end,
	})
	dofile(repo .. "/mods/CORE/grug_core/atmosphere_zones.lua")
	local G = rawget(_G, "grug_core")
	local depth_at = G.depth_below_surface
	check(type(depth_at) == "function" and depth_at({x = 0, y = 0, z = 0}, "ana") == nil,
		"A no depth before the zone authority exists")
	installed = true
	local function queried()
		return queries.terrain + queries.water + queries.id + queries.biome
	end
	local d, col = depth_at({x = -50, y = 20.5, z = 0}, "ana")
	check(d == 0 and col.biome == "grug_meadows" and col.zone_id == "zone_a" and col.ref == 20,
		"A standing on the meadow: depth 0, its biome and zone")
	local q = queried()
	d = depth_at({x = -50.3, y = 5.5, z = 0.2}, "ana")
	check(d == 15 and queried() == q, "A the same column, 15 down: no zone query (memo)")
	d = depth_at({x = -50, y = 120, z = 0}, "bo")
	check(d == -99.5 and queried() == q + 4, "A another player in the column: one computation")
	d = depth_at({x = -51, y = 20.5, z = 0}, "ana")
	check(d == 0 and queried() == q + 8, "A a new column: its four queries once")
	d, col = depth_at({x = 50, y = 1.5, z = 0}, "ana")
	check(d == 1 and col.ref == 2, "A over a lake: the water surface is the reference")
	d, col = depth_at({x = 500, y = 1.5, z = 0}, "ana")
	check(d == 0 and col.ref == 1 and col.zone_id == nil and col.biome == nil,
		"A over the deep ocean: sea level, no zone, no biome")
	d, col = depth_at({x = 50, y = 3.5, z = 2000}, "ana")
	check(d == 0 and col.ref == 3, "A a high shelf (water depth <= 0): the terrain")
	check(G.depth_stats.calls >= 7 and G.depth_stats.hits >= 1, "A the memo's figures")
	for _, fn in ipairs(leaves) do fn({get_player_name = function() return "ana" end}) end

	-- the driver: the underground band along a level tunnel under rolling
	-- ground (z >= 500), the ocean rule
	local pos = {x = -1, y = 20.5, z = 600}
	local ana = {}
	function ana:get_player_name() return "ana" end
	function ana:get_pos() return {x = pos.x, y = pos.y, z = pos.z} end
	function ana:is_player() return true end
	players.ana = ana
	for _, fn in ipairs(joins) do fn(ana) end
	local function pass()
		for _ = 1, 8 do for _, fn in ipairs(steps) do fn(0.25) end end
		return applied.ana
	end
	check(applied.ana == "human", "A joined on the meadow: the zone's mood")
	pos.y = 20.5 - 20
	check(pass() == "human", "A 20 below: not yet underground")
	pos.y = 20.5 - 20.5
	check(pass() == "underground", "A more than 20 below: underground")
	-- a level tunnel at y 2 under ground rising 3 nodes every 10 nodes:
	-- depth 18.5 at x -1..-10, 21.5 at -11..-20, 24.5 at -21..-30; an
	-- absolute switch at 20 would flip at every step between -5 and -12
	pos.x, pos.y = -12, 2
	check(pass() == "underground", "A 21.5 below in the tunnel: underground")
	local flips, last = 0, applied.ana
	for _, x in ipairs({-5, -12, -25, -12, -5, -1, -5, -12}) do
		pos.x = x
		local mood = pass()
		if mood ~= last then flips, last = flips + 1, mood end
	end
	check(flips == 0 and last == "underground", "A along a level tunnel (18.5 to 24.5 below) the mood holds")
	pos.x = -1
	pos.y = 20.5 - 16
	check(pass() == "underground", "A 16 below: still underground (the band)")
	pos.y = 20.5 - 15.9
	check(pass() == "human", "A less than 16 below: back to the zone")
	pos.x, pos.y = 500, -60
	check(pass() == "ocean", "A the deep ocean: the ocean mood at every depth")
	for _, fn in ipairs(leaves) do fn(ana) end
	rawset(_G, "core", saved_core)
	rawset(_G, "grug_core", saved_grug_core)
	rawset(_G, "grug_zones", saved_zones)
end

-- ---------------------------------------------------------------------------
-- C  calls (the rows of §3.2 step 8 on a test table)
-- ---------------------------------------------------------------------------
do
	local TD = {calls = {
		crow = {sound = "crow", time = "day", keys = {battlegrounds = true, blight = true},
			distance = {24, 40}, surface = 0.5},
		hawk = {sound = "hawk", time = "day", keys = {crags = true, badlands = true},
			distance = {24, 40}, surface = 0.5},
		owl = {sound = "owl", time = "night", keys = {temperate = true}, distance = {24, 40}, surface = 0.5},
		wolf = {sound = "wolf", time = "night", keys = {crags = true}, biomes = {grug_pine_hills = true},
			distance = {24, 40}, surface = 0.5},
		thunder = D.calls.thunder,
	}}
	local A = {crow = true, hawk = true, owl = true, wolf = true, grug_ambience_call_thunder = true}
	local function ids(s)
		if s.surface == nil then s.surface = 1 end
		return table.concat(R.eligible_calls(TD, s, A), ",")
	end
	check(ids({key = "battlegrounds"}) == "crow" and ids({key = "blight"}) == "crow", "C crows by day")
	check(ids({key = "crags"}) == "hawk" and ids({key = "badlands"}) == "hawk", "C hawks by day")
	check(ids({key = "temperate", biome = "grug_meadows", night = true}) == "owl", "C owls at night")
	check(ids({key = "temperate", biome = "grug_pine_hills", night = true}) == "owl,wolf" and
		ids({key = "crags", biome = "grug_crags", night = true}) == "wolf",
		"C wolves at night in the crags and the pine hills (the biome sub-group)")
	check(ids({key = "temperate", biome = "grug_pine_hills"}) == "", "C no wolf by day")
	check(ids({key = "dragon_island", surface = 0}) == "thunder" and
		ids({key = "dragon_island", night = true, surface = 0}) == "thunder", "C thunder unchanged")
	check(ids({key = "crags", surface = 0.5}) == "hawk" and ids({key = "crags", surface = 0.49}) == "",
		"C animal calls only while the surface layer is at 50 % or more")
	check(ids({key = "crags", underground = true}) == "" and ids({key = "crags", underwater = true}) == "",
		"C none underground or under water")
	check(D.calls.thunder.distance[1] == 40 and D.calls.thunder.distance[2] == 56 and
		D.calls.thunder.keys.dragon_island and D.calls.thunder.surface == nil,
		"C thunder keeps 40-56 nodes and its rule")
	check(D.call_gap[1] == 90 and D.call_gap[2] == 240, "C the gap stays 90-240 s")
end

-- ---------------------------------------------------------------------------
-- P  the debug word
-- ---------------------------------------------------------------------------
do
	local c = R.parse_command(" Debug ")
	check(c and c.debug == true and c.on == nil and c.volume == nil, "P debug")
	check(R.parse_command("debugx") == nil and R.parse_command("50").volume == 50, "P other words unchanged")
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	print(("R52 AMB PORTABLE FAIL %d/%d"):format(#failures, checks))
	os.exit(1)
end
print("R52 AMB PORTABLE PASS checks=" .. checks)
