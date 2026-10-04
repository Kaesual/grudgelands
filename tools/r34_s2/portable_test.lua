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
-- B  beds
-- ---------------------------------------------------------------------------
do
	local function keys(s) return R.bed_keys(D, s) end
	local function first(s) return R.pick_bed(D, keys(s), AVAILABLE) end
	check(first({mood = "human", underwater = true, water = "sea"}) == "underwater",
		"B underwater beats everything")
	check(first({mood = "underground", night = true}) == "underground", "B underground, no night")
	check(first({mood = "underground", deep = true}) == "underground_deep", "B deep underground")
	check(first({mood = "human", water = "sea"}) == "sea", "B sea near the player")
	check(first({mood = "elf", water = "stream", night = true}) == "stream", "B stream beats night")
	check(first({mood = "human", night = true}) == "night", "B human night bed")
	check(first({mood = "human"}) == "human", "B human day bed")
	check(first({mood = "dwarf", night = true}) == "dwarf", "B dwarf keeps its bed at night")
	check(first({mood = "undead", night = true}) == "undead", "B undead keeps its bed at night")
	check(first({mood = "ocean"}) == "ocean", "B open ocean")
	check(R.bed_keys(D, {mood = nil}) == nil, "B non-mood preset keeps the bed")
	check(first({mood = nil, water = "sea"}) == "sea", "B non-mood preset still hears the sea")
	-- fallback to a shipped bed
	local some = {}
	for k, v in pairs(AVAILABLE) do some[k] = v end
	for _, n in ipairs(D.beds.night) do some[n] = nil end
	for _, n in ipairs(D.beds.underground_deep) do some[n] = nil end
	check(R.pick_bed(D, keys({mood = "elf", night = true}), some) == "elf",
		"B no night file: the day bed")
	check(R.pick_bed(D, keys({mood = "underground", deep = true}), some) == "underground",
		"B no deep file: the cave bed")
	check(R.pick_bed(D, keys({mood = "human", underwater = true}), {}) == false,
		"B nothing shipped: silence")
	-- random variant only among shipped names
	local only = {grug_ambience_elf_forest = true}
	local ok = true
	for seed = 1, 20 do
		if R.bed_sound(D, "elf", only, seeded(seed)) ~= "grug_ambience_elf_forest" then ok = false end
	end
	check(ok, "B variant picked among shipped names only")
	-- hysteresis
	local b = {seen = 0}
	check(R.bed_should_change(b, "human") == true, "B first bed starts at once")
	b.key = "human"
	check(R.bed_should_change(b, "stream") == false, "B one pass of stream: wait")
	check(R.bed_should_change(b, "human") == false, "B back to human: stays")
	check(R.bed_should_change(b, "stream") == false and R.bed_should_change(b, "stream") == true,
		"B two passes of stream: change")
	b.key = "stream"
	check(R.bed_should_change(b, "underwater") == true, "B diving changes at once")
	b.key = "underwater"
	check(R.bed_should_change(b, "stream") == true, "B surfacing changes at once")
	check(math.abs(R.bed_gain(D, 100, true) - D.gains.bed * D.gains.town_bed) < 1e-9 and
		math.abs(R.bed_gain(D, 50, false) - D.gains.bed * 0.5) < 1e-9, "B gain: volume and town")
end

-- ---------------------------------------------------------------------------
-- C  calls
-- ---------------------------------------------------------------------------
do
	local function ids(s) return table.concat(R.eligible_calls(D, s, AVAILABLE), ",") end
	check(ids({mood = "human", night = true}) == "owl,wolf", "C human night: owl, wolf")
	check(ids({mood = "human", night = false}) == "", "C human day: none")
	check(ids({mood = "undead", night = false}) == "crow,crows", "C undead day: crows")
	check(ids({mood = "dwarf", night = false}) == "hawk", "C dwarf day: hawk")
	check(ids({mood = "dragon_island", night = true}) == "thunder" and
		ids({mood = "battlegrounds"}) == "thunder", "C thunder on the islands and the front")
	check(ids({mood = "human", night = true, underwater = true}) == "", "C none under water")
	check(ids({mood = "underground", night = true}) == "", "C none underground")
	check(table.concat(R.eligible_calls(D, {mood = "human", night = true}, {}), ",") == "",
		"C no shipped file: no call")
	local lo, hi = math.huge, -math.huge
	for seed = 1, 200 do
		local d = R.next_call_delay(D, seeded(seed))
		lo, hi = math.min(lo, d), math.max(hi, d)
	end
	check(lo >= 40 and hi <= 150, "C call gap 40-150 s")
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
	local found = {
		["grug_jobs:forge"] = {{x = 10, y = 0, z = 0}},
		["grug_decor:cottages_anvil"] = {{x = 3, y = 0, z = 0}, {x = 6, y = 0, z = 0}},
		["grug_decor:xdecor_cauldron"] = {{x = 0, y = 0, z = 2}, {x = 0, y = 0, z = 9},
			{x = 0, y = 0, z = 5}},
		["default:stone"] = {{x = 1, y = 0, z = 0}},
	}
	local rows = R.nearest_emitters(found, D.emitter_nodes, {x = 0, y = 0, z = 0}, 2)
	local text = {}
	for _, row in ipairs(rows) do text[#text + 1] = row.kind .. "@" .. row.pos.x .. "," .. row.pos.z end
	check(table.concat(text, " ") == "fire@0,2 fire@0,5 forge@3,0 forge@6,0",
		"E the nearest two per kind, unknown nodes ignored: " .. table.concat(text, " "))
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
		registered_nodes = {["default:water_source"] = {}, ["default:water_flowing"] = {},
			["default:river_water_source"] = {}, ["default:river_water_flowing"] = {}},
		get_content_id = function(name) return CID[name] end,
		get_node_raw = function(x, y, z) return node_at[x .. "," .. y .. "," .. z] or 0 end,
		find_nodes_in_area = function(minp, maxp, names, grouped)
			finds = finds + 1
			assert(grouped == true)
			local out = {}
			for name, list in pairs(found_nodes) do
				for _, p in ipairs(list) do
					if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
							p.z >= minp.z and p.z <= maxp.z then
						out[name] = out[name] or {}
						table.insert(out[name], p)
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
	-- under water: the eye node is water
	node_at["0,12,0"] = 10
	run(2)
	beds = plays_to("ana", is_bed)
	check(beds[#beds].spec.name == "grug_ambience_underwater", "R under water at once")
	node_at["0,12,0"] = nil
	-- a stream two nodes below, on the ring
	for _, o in ipairs({{3, 0}, {-3, 0}, {0, 3}, {0, -3}}) do node_at[o[1] .. ",8," .. o[2]] = 12 end
	run(4)
	beds = plays_to("ana", is_bed)
	check(beds[#beds].spec.name:find("^grug_ambience_stream_"), "R stream near the player")
	for k in pairs(node_at) do node_at[k] = nil end
	timeofday = 0.5

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

	-- emitters: an anvil and a cauldron near the player, a forge far away
	found_nodes = {["grug_decor:cottages_anvil"] = {{x = 4, y = 10, z = 0}},
		["grug_decor:xdecor_cauldron"] = {{x = 0, y = 10, z = 5}},
		["grug_jobs:forge"] = {{x = 60, y = 10, z = 0}}}
	local f0 = finds
	run(2)
	check(finds - f0 == 1, "R one node search per pass")
	local loops = plays_to("ana", function(s) return s.params.loop and s.params.pos end)
	local names = {}
	for _, s in ipairs(loops) do names[#names + 1] = s.spec.name end
	table.sort(names)
	check(table.concat(names, " ") == "grug_ambience_fire grug_ambience_forge" and
		loops[1].params.to_player == "ana", "R forge and fire loops at their nodes")
	run(2)
	check(#plays_to("ana", function(s) return s.params.loop and s.params.pos end) == 2,
		"R running loops are not restarted")
	found_nodes = {}
	fades = {}
	run(2)
	local loop_fades = 0
	for _, f in ipairs(fades) do if f.gain == 0 then loop_fades = loop_fades + 1 end end
	check(loop_fades == 2, "R loops fade out when out of reach")

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
	-- calls happen, at a distance, minutes apart
	timeofday = 0.95
	sounds = {}
	run(1800)
	local calls = plays_to("ana", function(s) return s.ephemeral end)
	local spread_ok = #calls >= 8 and #calls <= 50
	for _, s in ipairs(calls) do
		if not s.params.pos then spread_ok = false end
	end
	check(spread_ok, "R calls at night: positional, minutes apart (" .. #calls .. " in 30 min)")
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
	for _, key in ipairs({"underwater", "underground", "underground_deep", "sea", "stream"}) do
		check(D.beds[key] ~= nil, "F bed " .. key)
	end
	-- every atmosphere mood has a bed row and a music group
	local zones = io.open(repo .. "/mods/CORE/grug_core/atmosphere_zones.lua"):read("*a")
	local moods = 0
	for m in zones:gmatch('\nmood%("([%w_]+)"') do
		moods = moods + 1
		check(D.music_groups[m] ~= nil, "F mood " .. m .. " has a music group")
		check(m == "underground" or D.region[m] ~= nil, "F mood " .. m .. " has a region bed")
	end
	check(moods == 10, "F ten atmosphere moods found (" .. moods .. ")")
	for id, call in pairs(D.calls) do
		check(call.distance[1] >= 8 and call.hear > call.distance[2], "F call " .. id .. " heard at its distance")
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
		if file:match("%.ogg$") then oggs[#oggs + 1] = "menu/" .. file end
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
	print(("R34 S2 files: %d shipped .ogg, approved list %s"):format(#oggs,
		list and "present" or "absent (phase 1: no file may ship)"))
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	print(("R34 S2 PORTABLE FAIL %d/%d"):format(#failures, checks))
	os.exit(1)
end
print("R34 S2 PORTABLE PASS checks=" .. checks)
