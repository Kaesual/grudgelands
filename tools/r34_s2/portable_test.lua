-- Round 34 Lane S2 portable test (LuaJIT): ambience beds, calls, forge and
-- fire loops, the music scheduler and its on-demand delivery.
--
--   luajit tools/r34_s2/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua and data.lua, and init.lua on a
-- fake engine (every data name shipped, so the runtime paths run). Round 35
-- made music a capital feature: its scheduler, the either-music-or-bed rule
-- and the music settings are checked in tools/r35_m. Checks here:
--   B  bed selection by state (underwater, underground and deep, sea and
--      stream water, night beds, non-mood presets keep the bed), the
--      fallback to a shipped bed, the two-pass hysteresis, town gain;
--   C  calls by mood and time of day;
--   T  the town flag of grug_map's location resolver;
--   E  fire and water emitters: the nearest per kind; none at forges and anvils;
--   P  settings: /music and /ambience words, volumes;
--   R  runtime on a fake engine: one pass per player per 2 s in eight
--      slots; a bed loop to the player only, crossfaded at night and under
--      water; emitters started and faded; no music outside a capital; the
--      ambience settings through the Help page fields and the chat command;
--   F  files: data integrity (every rotation track, bed key and call);
--      every shipped .ogg of the mod is on tools/r34_s2/approved.txt; once
--      that list exists, every name in data.lua is shipped.
-- Prints "R34 S2 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local MOD = repo .. "/mods/CORE/grug_ambience"
local R = dofile(MOD .. "/rules.lua")
local D = dofile(MOD .. "/data.lua")

-- A seeded stand-in for math.random(a, b).
local function seeded(seed)
	local state = seed
	return function(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		if not a then return state / 2147483648 end
		return a + state % (b - a + 1)
	end
end

local function all_available()
	local set = {}
	for _, names in pairs(D.beds) do
		for _, n in ipairs(names) do set[n] = true end
	end
	for _, call in pairs(D.calls) do set[call.sound] = true end
	for _, e in pairs(D.emitters) do set[e.sound] = true end
	return set
end
local AVAILABLE = all_available()

-- ---------------------------------------------------------------------------
-- B  beds: the rules on a several-zone test table, then the shipped pilot
-- ---------------------------------------------------------------------------
local TD = {gains = D.gains,
	beds = {human = {"h1"}, night = {"n1"}, elf = {"e1", "e2", "e3"}, dwarf = {"d1"},
		undead = {"u1"}, ocean = {"s1"}, sea = {"s1"}, stream = {"st1"}, underwater = {"w1"},
		underground = {"c1"}, underground_deep = {"c2"}},
	region = {human = {day = "human", night = "night"}, elf = {day = "elf", night = "night"},
		dwarf = {day = "dwarf"}, undead = {day = "undead"}, ocean = {day = "ocean"}},
	calls = {owl = {sound = "o", time = "night", moods = {human = true, elf = true}},
		crow = {sound = "c", time = "day", moods = {undead = true}},
		thunder = {sound = "t", time = "any", moods = {dragon_island = true}}},
}
local TA = {}
for _, names in pairs(TD.beds) do for _, n in ipairs(names) do TA[n] = true end end
for _, call in pairs(TD.calls) do TA[call.sound] = true end
do
	local function keys(s) return R.bed_keys(TD, s) end
	local function first(s) return R.pick_bed(TD, keys(s), TA) end
	check(first({mood = "human", underwater = true, water = "sea"}) == "underwater",
		"B underwater beats everything")
	check(first({mood = "underground", night = true}) == "underground", "B underground, no night")
	check(first({mood = "underground", deep = true}) == "underground_deep", "B deep underground")
	check(first({mood = "human", water = "sea"}) == "sea", "B sea near the player")
	check(first({mood = "elf", water = "stream", night = true}) == "stream", "B stream beats night")
	check(first({mood = "human", night = true}) == "night", "B night bed")
	check(first({mood = "human"}) == "human", "B day bed")
	check(first({mood = "dwarf", night = true}) == "dwarf", "B a region without a night row keeps its bed")
	check(first({mood = "ocean"}) == "ocean", "B open ocean")
	check(first({mood = "orc"}) == false, "B a mood without a region row: silence")
	check(R.bed_keys(TD, {mood = nil}) == nil, "B non-mood preset keeps the bed")
	check(first({mood = nil, water = "sea"}) == "sea", "B non-mood preset still hears the sea")
	local some = {}
	for k, v in pairs(TA) do some[k] = v end
	some.n1, some.c2 = nil, nil
	check(R.pick_bed(TD, keys({mood = "elf", night = true}), some) == "elf",
		"B no night file: the day bed")
	check(R.pick_bed(TD, keys({mood = "underground", deep = true}), some) == "underground",
		"B no deep file: the cave bed")
	check(R.pick_bed(TD, keys({mood = "human", underwater = true}), {}) == false,
		"B nothing shipped: silence")
	local ok = true
	for seed = 1, 20 do
		if R.bed_sound(TD, "elf", {e2 = true}, seeded(seed)) ~= "e2" then ok = false end
	end
	check(ok, "B variant picked among shipped names only")
	local b = {seen = 0}
	check(R.bed_should_change(b, "human") == true, "B first bed starts at once")
	b.key = "human"
	check(R.bed_should_change(b, "stream") == false, "B one pass of stream: wait")
	check(R.bed_should_change(b, "human") == false, "B back to human: stays")
	check(R.bed_should_change(b, "stream") == false and R.bed_should_change(b, "stream") == true,
		"B two passes of stream: change")
	b.key = "stream"
	check(R.bed_should_change(b, "underwater", true) == true, "B diving changes at once")
	b.key = "underwater"
	check(R.bed_should_change(b, "stream", false) == true, "B surfacing changes at once")
	b.key = "human"
	check(R.bed_should_change(b, false, true) == true and b.underwater == true,
		"B diving into silence changes at once")
	check(math.abs(R.bed_gain(D, 100, true) - D.gains.bed * D.gains.town_bed) < 1e-9 and
		math.abs(R.bed_gain(D, 50, false) - D.gains.bed * 0.5) < 1e-9, "B gain: volume and town")

	-- the shipped beds (round34-plan.md §2.2a): one row per zone, night beds
	-- for four regions, the deep cave bed only below deep_y
	local function real(s) return R.pick_bed(D, R.bed_keys(D, s), AVAILABLE) end
	local day = {human = "human", elf = "elf", troll = "troll", orc = "orc", dwarf = "dwarf",
		undead = "undead", battlegrounds = "battlegrounds", dragon_island = "dragon_island",
		ocean = "ocean"}
	local night = {human = "night", elf = "night", troll = "night", orc = "night", dwarf = "dwarf",
		undead = "undead", battlegrounds = "battlegrounds", dragon_island = "dragon_island",
		ocean = "ocean"}
	for m, key in pairs(day) do
		check(real({mood = m}) == key, "B day bed for " .. m)
		check(real({mood = m, night = true}) == night[m], "B night bed for " .. m)
	end
	check(real({mood = "underground"}) == "underground" and
		real({mood = "underground", night = true}) == "underground", "B caves: the cave beds")
	check(real({mood = "underground", deep = true}) == "underground_deep", "B deep: the crystal cave")
	local deep_only = true
	for _, n in ipairs(D.beds.underground) do
		if n == "grug_ambience_underground_crystal" then deep_only = false end
	end
	check(deep_only and #D.beds.underground_deep == 1, "B the crystal cave plays only deep down")
	check(real({mood = "elf", water = "sea"}) == "sea" and real({mood = "elf", water = "stream"}) == "elf",
		"B sea water near the player: the sea bed; no stream bed")
	check(real({mood = "human", underwater = true}) == false, "B under water: silent")
	check(D.gains.bed == 0.2, "B every bed at gain 0.2")
end

-- ---------------------------------------------------------------------------
-- C  calls
-- ---------------------------------------------------------------------------
do
	local function ids(s) return table.concat(R.eligible_calls(TD, s, TA), ",") end
	check(ids({mood = "human", night = true}) == "owl", "C night call by mood")
	check(ids({mood = "human", night = false}) == "", "C day: none")
	check(ids({mood = "undead", night = false}) == "crow", "C day call by mood")
	check(ids({mood = "human", night = true, underwater = true}) == "", "C none under water")
	check(ids({mood = "underground", night = true}) == "", "C none underground")
	check(table.concat(R.eligible_calls(TD, {mood = "human", night = true}, {}), ",") == "",
		"C no shipped file: no call")
	local function real(s) return table.concat(R.eligible_calls(D, s, AVAILABLE), ",") end
	check(real({mood = "dragon_island"}) == "thunder" and real({mood = "dragon_island", night = true}) == "thunder",
		"C pilot: thunder on the dragon islands, day and night")
	local others = ""
	for _, m in ipairs({"human", "elf", "troll", "orc", "dwarf", "undead", "battlegrounds", "ocean"}) do
		others = others .. real({mood = m}) .. real({mood = m, night = true})
	end
	check(others == "", "C pilot: no other call anywhere")
	local lo, hi = math.huge, -math.huge
	for seed = 1, 200 do
		local d = R.next_call_delay(D, seeded(seed))
		lo, hi = math.min(lo, d), math.max(hi, d)
	end
	check(lo >= 90 and hi <= 240, "C thunder is rare: 90-240 s apart")
end

-- ---------------------------------------------------------------------------
-- T  the town seam of the location resolver (grug_map/location_view.lua)
-- ---------------------------------------------------------------------------
do
	local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
	local resolve = L.resolver({zone_at = function() return "zone_a" end,
		names = {zone_a = "Zone A"}, reach = 50,
		towns = {{name = "Dawnmere", x = 0, z = 0, footprint = "fp1"}},
		footprint_at = function(x, z) return (math.abs(x) < 20 and math.abs(z) < 20) and "fp1" or nil end})
	local text, town = resolve(5, 5)
	check(text == "Dawnmere" and town == true, "T inside a town: its name and true")
	text, town = resolve(30, 30)
	check(text == "Zone A" and not town, "T outside: the zone, not a town")
end

-- ---------------------------------------------------------------------------
-- E  emitters
-- ---------------------------------------------------------------------------
do
	local limits = {forge = 2, fire = 2, water = 2}
	local hears = {forge = 16, fire = 10, water = 14}
	local key = function(p) return p.x .. "," .. p.y .. "," .. p.z end
	local found = {
		["grug_jobs:forge"] = {{x = 10, y = 0, z = 0}},
		["grug_decor:cottages_anvil"] = {{x = 3, y = 0, z = 0}, {x = 6, y = 0, z = 0}},
		["default:furnace_active"] = {{x = 0, y = 0, z = 2}, {x = 0, y = 0, z = 9},
			{x = 0, y = 0, z = 5}},
		["grug_decor:xdecor_cauldron"] = {{x = 0, y = 0, z = 1}},
		["default:stone"] = {{x = 1, y = 0, z = 0}},
		["default:water_source"] = {{x = 0, y = 0, z = -1}},
	}
	local function text(rows)
		local t = {}
		for _, row in ipairs(rows) do t[#t + 1] = row.kind .. "@" .. row.pos.x .. "," .. row.pos.z end
		return table.concat(t, " ")
	end
	local rows = R.choose_emitters(found, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {}, key)
	-- Round 45 PT8: forges and anvils have no loop any more (their sound plays
	-- at a job's start, tools/r45_pt8).
	check(text(rows) == "fire@0,2 fire@0,5",
		"E the nearest two per kind; forges, anvils, sources, cold cauldrons and other nodes ignored: " ..
		text(rows))
	check(D.emitter_nodes["grug_jobs:forge"] == nil and D.emitter_nodes["grug_decor:cottages_anvil"] == nil
		and D.emitters.forge == nil, "E no loop at forges and anvils (Round 45 PT8)")
	rows = R.choose_emitters({["default:furnace_active"] = {{x = 11, y = 0, z = 0}},
		["default:water_flowing"] = {{x = 11, y = 0, z = 0}}}, D.emitter_nodes, {x = 0, y = 0, z = 0},
		limits, hears, {}, key)
	check(text(rows) == "water@11,0", "E a node beyond its kind's hearing distance is no candidate")
	-- flowing water along a river: a playing loop stays while among the nearest 2 * limit
	local river = {["default:water_flowing"] = {}}
	for x = 1, 8 do table.insert(river["default:water_flowing"], {x = x, y = 0, z = 0}) end
	rows = R.choose_emitters(river, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {["3,0,0"] = true}, key)
	check(text(rows) == "water@1,0 water@3,0", "E a playing loop near enough stays: " .. text(rows))
	rows = R.choose_emitters(river, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {["6,0,0"] = true}, key)
	check(text(rows) == "water@1,0 water@2,0", "E a playing loop too far behind is replaced: " .. text(rows))
	-- a river bank with hundreds of flowing nodes: the same choice as a full sort
	local many, brute = {["default:water_flowing"] = {}}, {}
	local r = seeded(11)
	for i = 1, 300 do
		local p = {x = r(-12, 12), y = r(-5, 5), z = r(-12, 12)}
		table.insert(many["default:water_flowing"], p)
		brute[#brute + 1] = p
	end
	table.sort(brute, function(a, b)
		local da, db = a.x * a.x + a.y * a.y + a.z * a.z, b.x * b.x + b.y * b.y + b.z * b.z
		if da ~= db then return da < db end
		if a.x ~= b.x then return a.x < b.x end
		if a.y ~= b.y then return a.y < b.y end
		return a.z < b.z
	end)
	rows = R.choose_emitters(many, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {}, key)
	check(#rows == 2 and rows[1].pos == brute[1] and rows[2].pos == brute[2],
		"E 300 flowing nodes: the two nearest, as a full sort")
	rows = R.choose_emitters(many, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears,
		{[key(brute[4])] = true}, key)
	check(#rows == 2 and rows[1].pos == brute[1] and rows[2].pos == brute[4],
		"E 300 flowing nodes: the fourth nearest still playing stays")
	check(D.emitter_nodes["default:water_source"] == nil and D.emitter_nodes["default:river_water_source"] == nil,
		"E never a water source")
end

-- ---------------------------------------------------------------------------
-- P  settings
-- ---------------------------------------------------------------------------
do
	local function same(a, b)
		return a ~= nil and a.on == b.on and a.volume == b.volume
	end
	check(same(R.parse_command(""), {}), "P status")
	check(same(R.parse_command(" ON "), {on = true}), "P on")
	check(same(R.parse_command("off"), {on = false}), "P off")
	check(same(R.parse_command("50"), {on = true, volume = 50}), "P 50")
	check(same(R.parse_command("50%"), {on = true, volume = 50}), "P 50%")
	check(same(R.parse_command("0"), {on = false, volume = 0}), "P 0 is off")
	check(same(R.parse_command("250"), {on = true, volume = 100}), "P clamps to 100")
	check(R.parse_command("loud") == nil and R.parse_command("-5") == nil, "P bad words")
	check(R.clamp_volume("x") == nil and R.clamp_volume(49.6) == 50, "P clamp")
	check(R.audible(true, 1) and not R.audible(true, 0) and not R.audible(false, 80), "P audible")
end

-- ---------------------------------------------------------------------------
-- R  runtime on a fake engine
-- ---------------------------------------------------------------------------
do
	local us = 0
	local steps, joins, leaves, loaded, commands = {}, {}, {}, {}, {}
	local players = {}
	local sounds, fades, pushes = {}, {}, {}
	local next_handle = 0
	local node_at = {} -- "x,y,z" -> content id
	local found_nodes = {}
	local finds = 0
	local searched
	local timeofday = 0.5
	local shipped = {}
	for name in pairs(AVAILABLE) do shipped[#shipped + 1] = name .. ".ogg" end
	shipped[#shipped + 1] = "grug_ambience_call_thunder.1.ogg"
	local music = {}
	for _, track in pairs(D.tracks) do music[#music + 1] = track.file end
	local CID = {["default:water_source"] = 10, ["default:water_flowing"] = 11,
		["default:river_water_source"] = 12, ["default:river_water_flowing"] = 13}
	local fake_core = {
		get_current_modname = function() return "grug_ambience" end,
		get_modpath = function() return MOD end,
		get_dir_list = function(path)
			if path:find("/sounds$") then return shipped end
			if path:find("/music$") then return music end
			return {}
		end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_chatcommand = function(name, def) commands[name] = def end,
		get_player_by_name = function(name) return players[name] end,
		get_us_time = function() return us end,
		get_timeofday = function() return timeofday end,
		registered_nodes = {
			["default:water_source"] = {liquidtype = "source"},
			["default:water_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:water_source"},
			["default:river_water_source"] = {liquidtype = "source"},
			["default:river_water_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:river_water_source"},
			["grug_test:bog_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:river_water_source"},
			["default:lava_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:lava_source"},
			["grug_jobs:forge"] = {}, ["grug_decor:cottages_anvil"] = {},
			["default:furnace_active"] = {}, ["grug_nodes:camp_fire"] = {}},
		get_content_id = function(name) return CID[name] end,
		get_node_raw = function(x, y, z) return node_at[x .. "," .. y .. "," .. z] or 0 end,
		find_nodes_in_area = function(minp, maxp, names, grouped)
			finds = finds + 1
			assert(grouped == true)
			searched = names
			local wanted = {}
			for _, n in ipairs(names) do wanted[n] = true end
			local out = {}
			for name, list in pairs(found_nodes) do
				if wanted[name] then
				for _, p in ipairs(list) do
					if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
							p.z >= minp.z and p.z <= maxp.z then
						out[name] = out[name] or {}
						table.insert(out[name], p)
					end
				end
				end
			end
			return out
		end,
		hash_node_position = function(p) return p.x * 1000000 + p.y * 1000 + p.z end,
		sound_play = function(spec, params, ephemeral)
			next_handle = next_handle + 1
			sounds[#sounds + 1] = {spec = spec, params = params, ephemeral = ephemeral,
				handle = next_handle}
			return next_handle
		end,
		sound_fade = function(handle, step, gain)
			fades[#fades + 1] = {handle = handle, step = step, gain = gain}
		end,
		dynamic_add_media = function(options, callback)
			pushes[#pushes + 1] = {options = options, callback = callback}
			return true
		end,
		formspec_escape = function(text) return text end,
		log = function() end,
	}
	rawset(_G, "core", fake_core)
	local mood = {}
	local in_town = {}
	rawset(_G, "grug_core", {
		atmosphere_moods = {human = true, elf = true, dwarf = true, undead = true, orc = true,
			troll = true, battlegrounds = true, dragon_island = true, ocean = true,
			underground = true},
		get_atmosphere = function(name) return mood[name] end,
		is_day_phase = function(t) return t >= 0.1875 and t <= 0.8125 end,
	})
	rawset(_G, "grug_map", {location = {in_town = function(name) return in_town[name] == true end,
		capital_of = function() return nil end}})
	dofile(MOD .. "/init.lua")
	for _, fn in ipairs(loaded) do fn() end
	local A = rawget(_G, "grug_ambience")

	local function new_player(name, pos)
		local store = {}
		local meta = {}
		function meta:get(k) return store[k] end
		function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
		function meta:set_int(k, v) store[k] = tostring(v) end
		local p = {_pos = pos, _store = store}
		function p:get_player_name() return name end
		function p:get_pos() return {x = self._pos.x, y = self._pos.y, z = self._pos.z} end
		function p:get_meta() return meta end
		players[name] = p
		for _, fn in ipairs(joins) do fn(p) end
		return p
	end
	local function run(seconds)
		for _ = 1, math.floor(seconds / 0.25 + 0.5) do
			us = us + 250000
			for _, fn in ipairs(steps) do fn(0.25) end
		end
	end
	local function plays_to(name, filter)
		local list = {}
		for _, s in ipairs(sounds) do
			if s.params.to_player == name and (not filter or filter(s)) then list[#list + 1] = s end
		end
		return list
	end
	local function is_bed(s) return s.params.loop and not s.params.pos end

	-- slots: eight players, each evaluated once per 2 s
	local before = A.stats.passes
	for i = 1, 8 do
		local name = "slot" .. i
		mood[name] = "human"
		new_player(name, {x = 1000 * i, y = 10, z = 0})
	end
	local per_step = {}
	for _ = 1, 8 do
		local p0 = A.stats.passes
		us = us + 250000
		for _, fn in ipairs(steps) do fn(0.25) end
		per_step[#per_step + 1] = A.stats.passes - p0
	end
	check(A.stats.passes - before == 8 and table.concat(per_step, ",") == "1,1,1,1,1,1,1,1",
		"R one player per slot, each once per 2 s: " .. table.concat(per_step, ","))
	for i = 1, 8 do
		players["slot" .. i] = nil
		for _, fn in ipairs(leaves) do fn({get_player_name = function() return "slot" .. i end}) end
	end

	-- one player: day bed, night crossfade, water, underwater
	sounds, fades, pushes = {}, {}, {}
	mood.ana = "human"
	local ana = new_player("ana", {x = 0, y = 10, z = 0})
	local joined_us = us
	run(2)
	local beds = plays_to("ana", is_bed)
	check(#beds == 1 and beds[1].spec.name:find("^grug_ambience_human_") and
		beds[1].params.to_player == "ana" and beds[1].ephemeral == false,
		"R day bed loops to the player only")
	local day_handle = beds[1] and beds[1].handle
	timeofday = 0.95
	run(2)
	check(#plays_to("ana", is_bed) == 1, "R night: one pass is not enough (hysteresis)")
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds == 2 and beds[2].spec.name:find("^grug_ambience_night_"), "R night bed after two passes")
	local faded = false
	for _, f in ipairs(fades) do
		if f.handle == day_handle and f.gain == 0 then faded = true end
	end
	check(faded, "R the day bed fades out (crossfade)")
	-- under water: the eye node is water; no underwater bed ships, so silence
	node_at["0,12,0"] = 10
	fades = {}
	local count = #plays_to("ana", is_bed)
	run(2)
	local night_off = false
	for _, f in ipairs(fades) do if f.handle == beds[2].handle and f.gain == 0 then night_off = true end end
	check(night_off and #plays_to("ana", is_bed) == count, "R under water: the bed stops at once, silence")
	node_at["0,12,0"] = nil
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds == count + 1 and beds[#beds].spec.name:find("^grug_ambience_night_") ~= nil,
		"R surfacing: the night bed again")
	-- at night the elf zone shares the night bed: nothing restarts; the
	-- dwarf zone keeps its own bed at night: a crossfade after two passes
	mood.ana = "elf"
	fades = {}
	run(4)
	check(#fades == 0 and #plays_to("ana", is_bed) == count + 1,
		"R into an elf zone at night: the same night bed goes on")
	mood.ana = "dwarf"
	run(4)
	beds = plays_to("ana", is_bed)
	check(#fades >= 1 and fades[#fades].gain == 0 and #beds == count + 2 and
		(beds[#beds].spec.name == "grug_ambience_orc_wind" or
			beds[#beds].spec.name == "grug_ambience_dwarf_storm"),
		"R into a dwarf zone at night: a crossfade to the dwarf bed")
	mood.ana = "human"
	timeofday = 0.5
	run(4)

	-- town: the bed fades to the town gain
	in_town.ana = true
	fades = {}
	run(4)
	local town_fade = false
	for _, f in ipairs(fades) do
		if math.abs(f.gain - D.gains.bed * D.gains.town_bed) < 1e-9 then town_fade = true end
	end
	check(town_fade, "R in town the bed is quieter")
	in_town.ana = nil

	-- emitters: an anvil, a furnace and flowing water near the player, a
	-- forge far away, a water source next to the player (never a loop; since
	-- Round 45 PT8 neither the anvil nor the forge)
	found_nodes = {["grug_decor:cottages_anvil"] = {{x = 4, y = 10, z = 0}},
		["default:furnace_active"] = {{x = 0, y = 10, z = 5}},
		["grug_jobs:forge"] = {{x = 60, y = 10, z = 0}},
		["default:water_source"] = {{x = 1, y = 9, z = 0}},
		["default:river_water_flowing"] = {{x = -3, y = 9, z = 0}},
		["grug_test:bog_flowing"] = {{x = -6, y = 9, z = 0}, {x = -9, y = 9, z = 0}},
		["default:lava_flowing"] = {{x = 2, y = 9, z = 2}}}
	local f0 = finds
	run(2)
	check(finds - f0 == 1, "R one node search per pass")
	local want = {}
	for _, n in ipairs(searched) do want[n] = true end
	check(want["default:water_flowing"] and want["grug_test:bog_flowing"] and
		not want["default:water_source"] and not want["default:river_water_source"] and
		not want["default:lava_flowing"], "R searched: flowing water of any registered kind, never a source")
	local loops = plays_to("ana", function(s) return s.params.loop and s.params.pos end)
	local names = {}
	for _, s in ipairs(loops) do names[#names + 1] = s.spec.name .. "@" .. s.params.pos.x end
	table.sort(names)
	check(table.concat(names, " ") == "grug_ambience_fire@0 " ..
		"grug_ambience_stream_pond@-3 grug_ambience_stream_pond@-6" and
		loops[1].params.to_player == "ana", "R fire and flowing-water loops, none at the anvil: " ..
		table.concat(names, " "))
	run(2)
	check(#plays_to("ana", function(s) return s.params.loop and s.params.pos end) == 3,
		"R running loops are not restarted")
	found_nodes = {}
	fades = {}
	run(2)
	local loop_fades = 0
	for _, f in ipairs(fades) do if f.gain == 0 then loop_fades = loop_fades + 1 end end
	check(loop_fades == 3, "R loops fade out when out of reach")

	-- no music outside a capital (Round 35; the music runtime: tools/r35_m)
	run(600)
	check(#pushes == 0, "R no music push outside a capital in 10 min")
	-- "on" after a volume of 0 is never silent
	commands.ambience.func("ana", "0")
	A.handle_settings_fields(ana, {grug_ambience_ambience = "true"})
	check(A.get(ana, "ambience").on and A.get(ana, "ambience").volume == R.DEFAULT_VOLUME.ambience,
		"R the ambience checkbox after 0 restores the default volume")
	run(2)
	-- ambience off: the bed fades, nothing new plays
	fades, sounds = {}, {}
	commands.ambience.func("ana", "off")
	local bed_off = false
	for _, f in ipairs(fades) do if f.gain == 0 then bed_off = true end end
	run(600)
	check(bed_off and #plays_to("ana", function(s) return s.spec.name:find("^grug_ambience_") end) == 0,
		"R ambience off: bed stops, no bed, call or loop for 10 min")
	commands.ambience.func("ana", "on")
	run(2)
	check(#plays_to("ana", is_bed) == 1, "R ambience on: the bed returns at once")
	-- calls: none in the human region, rare thunder on a dragon island
	timeofday = 0.95
	sounds = {}
	run(1800)
	check(#plays_to("ana", function(s) return s.ephemeral end) == 0, "R no calls in the human region")
	mood.ana = "dragon_island"
	run(1800)
	local calls = plays_to("ana", function(s) return s.ephemeral end)
	local spread_ok = #calls >= 6 and #calls <= 22
	for _, s in ipairs(calls) do
		if not s.params.pos or s.spec.name ~= "grug_ambience_call_thunder" then spread_ok = false end
	end
	check(spread_ok, "R thunder on a dragon island: positional, minutes apart (" .. #calls .. " in 30 min)")
	players.ana = nil
	for _, fn in ipairs(leaves) do fn(ana) end
end

-- ---------------------------------------------------------------------------
-- F  files and data integrity
-- ---------------------------------------------------------------------------
do
	for capital, rotation in pairs(D.rotations) do
		for _, id in ipairs(rotation) do
			check(D.tracks[id] ~= nil, "F rotation " .. capital .. " track " .. id)
		end
	end
	for mood, row in pairs(D.region) do
		check(D.beds[row.day] ~= nil and (row.night == nil or D.beds[row.night] ~= nil),
			"F region " .. mood .. " beds exist")
	end
	for id, call in pairs(D.calls) do
		check(call.distance[1] >= 8 and call.distance[2] >= call.distance[1], "F call " .. id .. " distance")
	end
	check(D.call_gap[1] >= 5, "F calls never more often than every few seconds")
	for _, name in pairs(D.emitter_nodes) do check(D.emitters[name] ~= nil, "F emitter kind " .. name) end

	-- shipped files
	local function ls(path)
		local handle, out = io.popen('ls "' .. path .. '" 2>/dev/null'), {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end
	local oggs = {}
	for _, dir in ipairs({"sounds", "music"}) do
		for _, file in ipairs(ls(MOD .. "/" .. dir)) do
			if file:match("%.ogg$") then oggs[#oggs + 1] = file end
		end
	end
	for _, file in ipairs(ls(repo .. "/menu")) do
		if file:match("%.ogg$") then oggs[#oggs + 1] = file end
	end
	local approved = {}
	local list = io.open(repo .. "/tools/r34_s2/approved.txt")
	if list then
		for line in list:lines() do
			local file = line:match("^%s*([^,%s#][^,%s]*)")
			if file then approved[file] = true end
		end
		list:close()
	end
	for _, file in ipairs(oggs) do
		check(approved[file] == true, "F shipped file not approved: " .. file)
	end
	if list then
		local shipped = {}
		for _, file in ipairs(oggs) do
			shipped[(file:match("^(.-)%.%d%.ogg$") or file:match("^(.-)%.ogg$"))] = true
		end
		for name in pairs(AVAILABLE) do
			check(shipped[name] == true, "F data name not shipped: " .. name)
		end
		for id, track in pairs(D.tracks) do
			check(shipped[track.file:match("^(.-)%.ogg$")] == true, "F track not shipped: " .. id)
		end
	end
	local menu = io.open(repo .. "/menu/theme.ogg", "rb")
	local twin = io.open(MOD .. "/music/grug_music_fantasy_orchestral_theme.ogg", "rb")
	if menu and twin then
		check(menu:read("*a") == twin:read("*a"), "F menu/theme.ogg is the same cut as the M6 track")
	end
	if menu then menu:close() end
	if twin then twin:close() end
	print(("R34 S2 files: %d shipped .ogg, approved list %s"):format(#oggs,
		list and "present" or "absent (phase 1: no file may ship)"))
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	print(("R34 S2 PORTABLE FAIL %d/%d"):format(#failures, checks))
	os.exit(1)
end
print("R34 S2 PORTABLE PASS checks=" .. checks)
