-- Round 34 Lane S2 portable test (LuaJIT): ambience beds, calls, forge and
-- fire loops, the music scheduler and its on-demand delivery.
--
--   luajit tools/r34_s2/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua and data.lua, and init.lua on a
-- fake engine (every data name shipped, so the runtime paths run). Checks:
--   S  scheduler: the first track 30-90 s after joining; the next file
--      pushed during the pause, before it plays; a playing track is never
--      cut on a group change; the pause after a track is 3-8 min; the pick
--      is redone once from the new pool when the group changed; music off
--      stops the track and every push, on again resumes; a lost push is
--      given up; the last track is not repeated;
--   B  bed selection by state (underwater, underground and deep, sea and
--      stream water, night beds, non-mood presets keep the bed), the
--      fallback to a shipped bed, the two-pass hysteresis, town gain;
--   C  calls by mood and time of day;
--   T  the town flag of grug_map's location resolver;
--   E  forge and fire emitters: the nearest per kind;
--   P  settings: /music and /ambience words, volumes;
--   R  runtime on a fake engine: one pass per player per 2 s in eight
--      slots; a bed loop to the player only, crossfaded at night and under
--      water; emitters started and faded; music pushed with
--      dynamic_add_media (to_player, not ephemeral, client cache) from
--      music/, played in the callback; music off: no pushes for an hour;
--      the Help page fields and the chat command;
--   F  files: data integrity (every pool track, bed key, call and mood);
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
-- S  scheduler
-- ---------------------------------------------------------------------------
do
	local lo, hi = math.huge, -math.huge
	for seed = 1, 200 do
		local m = R.music_new(D, 1000, true, seeded(seed))
		local delay = m.start_at - 1000
		lo, hi = math.min(lo, delay), math.max(hi, delay)
	end
	check(lo >= 30 and hi <= 90 and hi - lo > 40, "S first track 30-90 s after join")

	local pool = {"memories_of_stone", "achaidh_cheide"}
	local rand = seeded(7)
	local m = R.music_new(D, 0, true, rand)
	local start = m.start_at
	local pushed, played
	for t = 0, start + 10, 2 do
		local action, track = R.music_step(m, D, t, pool, rand)
		if action == "push" then
			check(not pushed, "S one push before the first track")
			pushed = {t = t, track = track}
		elseif action == "play" then
			played = {t = t, track = track}
		end
		if pushed and not m.delivered[pushed.track] and t >= pushed.t + 4 then
			local a2, t2 = R.music_delivered(m, D, pushed.track, t)
			check(a2 == nil, "S delivery before the pause ends does not play")
			check(t2 == nil, "S no track returned early")
		end
	end
	check(pushed and pushed.t >= start - D.music.push_lead - 2 and pushed.t < start,
		"S the file is pushed during the pause, before it plays")
	check(played and played.track == pushed.track and played.t >= start and played.t < start + 2,
		"S the pushed track plays when the pause ends")
	-- never cut: a group change while playing changes nothing
	local ends = m.ends_at
	check(ends == played.t + D.tracks[played.track].seconds, "S track end from its length")
	local cut = false
	for t = played.t + 2, ends - 2, 2 do
		if R.music_step(m, D, t, {"forest_walk"}, rand) ~= nil then cut = true end
	end
	check(not cut and m.phase == "play", "S a group change never cuts the running track")
	R.music_step(m, D, ends, {"forest_walk"}, rand)
	local pause = m.start_at - ends
	check(m.phase == "wait" and pause >= 180 and pause <= 480, "S a 3-8 min pause after a track")
	-- the next pick comes from the new pool, pushed before it plays
	local action, track = R.music_step(m, D, m.start_at - D.music.push_lead, {"forest_walk"}, rand)
	check(action == "push" and track == "forest_walk", "S next track from the new pool")
	check(R.music_step(m, D, m.start_at, {"forest_walk"}, rand) == nil,
		"S waits for the delivery at the start time")
	action, track = R.music_delivered(m, D, "forest_walk", m.start_at + 1)
	check(action == "play" and track == "forest_walk", "S plays in the push callback")

	-- pause ranges over many seeds
	local plo, phi = math.huge, -math.huge
	for seed = 1, 200 do
		local mm = R.music_new(D, 0, true, seeded(seed))
		mm.phase, mm.ends_at = "play", 10
		R.music_step(mm, D, 10, pool, seeded(seed + 1))
		plo, phi = math.min(plo, mm.start_at - 10), math.max(phi, mm.start_at - 10)
	end
	check(plo >= 180 and phi <= 480 and phi - plo > 200, "S pause range 180-480 s")

	-- re-pick once at the start when the group changed during the pause
	local r = seeded(3)
	local mm = R.music_new(D, 0, true, r)
	mm.delivered = {memories_of_stone = true, achaidh_cheide = true, forest_walk = true}
	local a1 = R.music_step(mm, D, mm.start_at - 30, {"memories_of_stone"}, r)
	check(a1 == nil and mm.track == "memories_of_stone", "S delivered pick needs no push")
	local a2, t2 = R.music_step(mm, D, mm.start_at, {"forest_walk"}, r)
	check(a2 == "play" and t2 == "forest_walk", "S pick redone from the new pool at the start")

	-- the last track is not repeated
	local repeats = 0
	for seed = 1, 50 do
		local q = R.music_new(D, 0, true, seeded(seed))
		q.last = "memories_of_stone"
		q.delivered = {memories_of_stone = true, achaidh_cheide = true}
		local _, t = R.music_step(q, D, q.start_at, pool, seeded(seed))
		if t == "memories_of_stone" then repeats = repeats + 1 end
	end
	check(repeats == 0, "S the last track is not picked again")

	-- music off: stop, and no push for an hour; on again: resumes soon
	local o = R.music_new(D, 0, true, r)
	o.delivered = {memories_of_stone = true}
	R.music_step(o, D, o.start_at, {"memories_of_stone"}, r)
	check(o.phase == "play", "S off test: playing")
	check(R.music_set_on(o, D, false, o.start_at + 5, r) == "stop", "S off stops the track")
	local any = false
	for t = o.start_at + 6, o.start_at + 3600, 2 do
		if R.music_step(o, D, t, {"achaidh_cheide"}, r) ~= nil then any = true end
	end
	check(not any, "S music off: no push and no play for an hour")
	local t_on = o.start_at + 3600
	check(R.music_set_on(o, D, true, t_on, r) == nil, "S on returns no action")
	check(o.start_at - t_on >= 5 and o.start_at - t_on <= 15, "S on again: next track after 5-15 s")
	local a3 = R.music_step(o, D, o.start_at - 1, {"achaidh_cheide"}, r)
	check(a3 == "push", "S on again: pushes again")
	check(R.music_set_on(o, D, false, o.start_at, r) == nil and o.pushing == nil,
		"S off while a push waits: forgotten, nothing to stop")
	check(R.music_delivered(o, D, "achaidh_cheide", o.start_at + 1) == nil,
		"S a late delivery while off plays nothing")

	-- a lost push is given up and a new pause starts
	local g = R.music_new(D, 0, true, r)
	R.music_step(g, D, g.start_at - 10, {"soliloquy"}, r)
	check(g.pushing == "soliloquy", "S lost push: pushing")
	R.music_step(g, D, g.push_at + D.music.push_timeout + 1, {"soliloquy"}, r)
	check(g.track == nil and g.pushing == nil and g.start_at > g.push_at + 100,
		"S lost push given up, new pause")
	-- an empty pool retries later
	local e = R.music_new(D, 0, true, r)
	check(R.music_step(e, D, e.start_at, {}, r) == nil and e.start_at >= D.music.empty_retry,
		"S empty pool: nothing, retry later")
	-- a refused push
	local f = R.music_new(D, 0, true, r)
	local refused_at = f.start_at - 5
	R.music_step(f, D, refused_at, {"soliloquy"}, r)
	R.music_push_failed(f, D, refused_at, r)
	check(f.track == nil and f.pushing == nil and f.start_at >= refused_at + 180,
		"S refused push forgotten, a new pause")
end

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

	-- the shipped pilot (round34-plan.md §2.2a): the human region only
	local function real(s) return R.pick_bed(D, R.bed_keys(D, s), AVAILABLE) end
	check(real({mood = "human"}) == "human" and real({mood = "human", night = true}) == "night",
		"B pilot: human day and night")
	local silent = true
	for _, m in ipairs({"elf", "troll", "orc", "dwarf", "undead", "battlegrounds",
			"dragon_island", "ocean", "underground"}) do
		if real({mood = m}) ~= false or real({mood = m, night = true}) ~= false then silent = false end
	end
	check(silent, "B pilot: every other mood is silent")
	check(real({mood = "human", underwater = true}) == false and
		real({mood = "underground", deep = true}) == false, "B pilot: under water and caves silent")
	check(real({mood = "human", water = "sea"}) == "human", "B pilot: no sea or stream bed")
	check(D.gains.bed <= 0.3, "B pilot: the bed starts well below the page level")
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
	check(text(rows) == "fire@0,2 fire@0,5 forge@3,0 forge@6,0",
		"E the nearest two per kind, sources, cold cauldrons and other nodes ignored: " .. text(rows))
	rows = R.choose_emitters({["default:furnace_active"] = {{x = 11, y = 0, z = 0}},
		["grug_jobs:forge"] = {{x = 11, y = 0, z = 0}}}, D.emitter_nodes, {x = 0, y = 0, z = 0},
		limits, hears, {}, key)
	check(text(rows) == "forge@11,0", "E a node beyond its kind's hearing distance is no candidate")
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
	rawset(_G, "grug_map", {location = {in_town = function(name) return in_town[name] == true end}})
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
	check(#beds == count + 1 and beds[#beds].spec.name == "grug_ambience_night_forest",
		"R surfacing: the night bed again")
	-- another region: no bed this round
	mood.ana = "elf"
	fades = {}
	run(4)
	check(#fades >= 1 and fades[#fades].gain == 0 and #plays_to("ana", is_bed) == count + 1,
		"R an elf zone: the human bed fades, nothing else starts")
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

	-- emitters: an anvil, a cauldron and flowing water near the player, a
	-- forge far away, a water source next to the player (never a loop)
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
	check(table.concat(names, " ") == "grug_ambience_fire@0 grug_ambience_forge@4 " ..
		"grug_ambience_stream_pond@-3 grug_ambience_stream_pond@-6" and
		loops[1].params.to_player == "ana", "R forge, fire and flowing-water loops: " .. table.concat(names, " "))
	run(2)
	check(#plays_to("ana", function(s) return s.params.loop and s.params.pos end) == 4,
		"R running loops are not restarted")
	found_nodes = {}
	fades = {}
	run(2)
	local loop_fades = 0
	for _, f in ipairs(fades) do if f.gain == 0 then loop_fades = loop_fades + 1 end end
	check(loop_fades == 4, "R loops fade out when out of reach")

	-- music: first push (during the first 90 s), delivery, play
	sounds = {}
	run(math.max(0, 92 - (us - joined_us) / 1e6))
	check(#pushes == 1, "R one push before the first track (" .. #pushes .. ")")
	local push = pushes[1]
	check(push and push.options.to_player == "ana" and push.options.ephemeral == false and
		push.options.client_cache == true and push.options.filepath:find("/music/grug_music_") ~= nil,
		"R push: to the player, not ephemeral, client cache, from music/")
	local track_file = push and push.options.filepath:match("([^/]+)%.ogg$")
	check(#plays_to("ana", function(s) return s.spec.name == track_file end) == 0,
		"R nothing plays before the delivery")
	push.callback("ana")
	local music_plays = plays_to("ana", function(s) return s.spec.name == track_file end)
	check(#music_plays == 1 and not music_plays[1].params.loop, "R plays in the push callback")
	-- volume change fades the playing track
	fades = {}
	commands.music.func("ana", "50")
	check(#fades == 1 and math.abs(fades[1].gain - D.gains.music * 0.5) < 1e-9,
		"R /music 50 fades the track to half")
	-- music off: the track fades out, no pushes for an hour
	fades = {}
	local ok, msg = commands.music.func("ana", "off")
	check(ok and msg:find("off") and #fades == 1 and fades[1].gain == 0, "R /music off stops the track")
	check(ana._store["grug_ambience:music_off"] == "1", "R music off stored in player meta")
	pushes = {}
	run(3600)
	check(#pushes == 0, "R music off: no push for an hour")
	-- Help page: switch it on with the checkbox
	local changed = A.handle_settings_fields(ana, {grug_ambience_music = "true",
		grug_ambience_music_volume = "6", grug_ambience_ambience_volume = "11"})
	check(changed and A.get(ana, "music").on and A.get(ana, "music").volume == 50,
		"R Help checkbox switches music on, unchanged dropdown does nothing")
	run(20)
	check(#pushes == 1, "R music on again: the next track is pushed within 20 s")
	local fs = A.settings_formspec(ana, 0.2, 1.0)
	check(fs:find("checkbox%[[^]]*grug_ambience_music;Music;true%]") ~= nil and
		fs:find("grug_ambience_music_volume;[^;]*;6;true%]") ~= nil,
		"R Help controls show the current state")
	-- "on" after a volume of 0 is never silent
	commands.music.func("ana", "0")
	check(not A.get(ana, "music").on and A.get(ana, "music").volume == 0, "R /music 0 switches off")
	commands.music.func("ana", "on")
	check(A.get(ana, "music").on and A.get(ana, "music").volume == R.DEFAULT_VOLUME,
		"R /music on after 0 restores the default volume")
	commands.ambience.func("ana", "0")
	A.handle_settings_fields(ana, {grug_ambience_ambience = "true"})
	check(A.get(ana, "ambience").on and A.get(ana, "ambience").volume == R.DEFAULT_VOLUME,
		"R the ambience checkbox after 0 restores the default volume")
	commands.music.func("ana", "50")
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
	-- leave: state gone, later callback harmless
	players.ana = nil
	for _, fn in ipairs(leaves) do fn(ana) end
	local ok2 = pcall(push.callback, "ana")
	check(ok2, "R a callback after leaving does nothing")
end

-- ---------------------------------------------------------------------------
-- F  files and data integrity
-- ---------------------------------------------------------------------------
do
	for group, pool in pairs(D.pools) do
		for _, id in ipairs(pool) do check(D.tracks[id] ~= nil, "F pool " .. group .. " track " .. id) end
	end
	for mood, row in pairs(D.region) do
		check(D.beds[row.day] ~= nil and (row.night == nil or D.beds[row.night] ~= nil),
			"F region " .. mood .. " beds exist")
	end
	-- every atmosphere mood has a bed row and a music group
	local zones = io.open(repo .. "/mods/CORE/grug_core/atmosphere_zones.lua"):read("*a")
	local moods = 0
	for m in zones:gmatch('\nmood%("([%w_]+)"') do
		moods = moods + 1
		check(D.music_groups[m] ~= nil, "F mood " .. m .. " has a music group")
	end
	check(moods == 10, "F ten atmosphere moods found (" .. moods .. ")")
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
