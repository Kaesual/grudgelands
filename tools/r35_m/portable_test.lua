-- Round 35 Lane M portable test (LuaJIT): music only in the capitals
-- (round35-plan.md §2.8).
--
--   luajit tools/r35_m/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua, data.lua and init.lua (the latter
-- on a fake engine) and grug_map's location_view.lua and location.lua (on
-- fakes). Checks:
--   M  scheduler: entering a capital starts its rotation (push, play on
--      delivery, at once when the file is there); a start town and the wild
--      push and play nothing; leaving stops the track; the pause between
--      tracks; the next track pushed while the current one plays; the
--      rotation order; a lost or refused push; music off: no push, no play;
--   B  either music or the bed: the bed is silent while music has the
--      player's ear and changes at once when music starts or ends;
--   L  which capital a player counts as in: the city's settlement key, none
--      in a start town or the wild, the border hysteresis; the real
--      location.lua tells a capital from a start town by its anchor slot;
--   R  runtime on a fake engine: a start town gets no music and the town
--      bed; entering a capital pushes a track of its rotation and silences
--      the bed in the same pass; music off fades the track out and brings
--      the bed back; leaving fades the music out; default volume 35 %, the
--      Help dropdown in 5 % steps, /music help;
--   D  data: one rotation for each of the six capitals, every track known
--      and shipped, Master of the Feast in none, no region pools, the Help
--      text.
-- Prints "R35 M PORTABLE PASS checks=<n>" or the failures.
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

local ROT = {"fantasy_orchestral_theme", "town_theme", "village_consort", "minstrel_guild"}
local function index_of(list, value)
	for i = 1, #list do if list[i] == value then return i end end
end

-- ---------------------------------------------------------------------------
-- M  scheduler
-- ---------------------------------------------------------------------------
do
	local r = seeded(5)
	-- the wild and a start town (no capital): nothing for an hour
	local m = R.music_new(true)
	local any = false
	for t = 0, 3600, 2 do
		if R.music_step(m, D, t, nil, {}, r) ~= nil then any = true end
	end
	check(not any and not R.music_active(m), "M outside a capital: no push and no play for an hour")

	-- entering: the first track is pushed at once and plays on delivery
	local action, track = R.music_step(m, D, 4000, "highcourt", ROT, r)
	check(action == "push" and index_of(ROT, track) ~= nil, "M entering a capital pushes a rotation track")
	check(R.music_active(m), "M music has the player's ear in the capital")
	check(R.music_step(m, D, 4002, "highcourt", ROT, r) == nil, "M waits for the download")
	local a2, t2 = R.music_delivered(m, D, track, 4003)
	check(a2 == "play" and t2 == track, "M the first track plays when its download arrives")
	check(m.ends_at == 4003 + D.tracks[track].seconds, "M track end from its length")

	-- the next track pushed while this one plays, PUSH_LEAD before its end
	local pushed_at, next_track
	for t = 4005, m.ends_at - 1, 1 do
		local a, n = R.music_step(m, D, t, "highcourt", ROT, r)
		if a ~= nil then
			check(a == "push" and not pushed_at, "M only one push while a track plays")
			pushed_at, next_track = t, n
		end
	end
	check(pushed_at and pushed_at >= m.ends_at - D.music.push_lead and pushed_at <= m.ends_at -
		D.music.push_lead + 1, "M the next track is pushed push_lead s before the end")
	check(next_track == ROT[index_of(ROT, track) % #ROT + 1], "M the rotation order")
	R.music_delivered(m, D, next_track, pushed_at + 10)
	check(m.phase == "play", "M a delivery during the play changes nothing")
	-- the pause
	local ends = m.ends_at
	check(R.music_step(m, D, ends, "highcourt", ROT, r) == nil and m.phase == "wait",
		"M the track ends, the pause begins")
	check(R.music_step(m, D, ends + D.music.pause - 1, "highcourt", ROT, r) == nil,
		"M nothing during the pause")
	action, track = R.music_step(m, D, ends + D.music.pause, "highcourt", ROT, r)
	check(action == "play" and track == next_track, "M the next track plays after the pause")
	check(D.music.pause >= 3 and D.music.pause <= 8, "M pauses of about 5 s (" .. D.music.pause .. ")")

	-- leaving while a track plays: stop; then nothing outside
	check(R.music_step(m, D, ends + 30, nil, {}, r) == "stop", "M leaving stops the playing track")
	check(not R.music_active(m) and m.phase == "idle", "M outside: idle, the bed's turn")
	any = false
	for t = ends + 32, ends + 1000, 2 do
		if R.music_step(m, D, t, nil, {}, r) ~= nil then any = true end
	end
	check(not any, "M after leaving: no push, no play")

	-- re-entering with every file there: plays at once; the rotation cycles
	for _, id in ipairs(ROT) do m.delivered[id] = true end
	local played = {}
	local t = 10000
	action, track = R.music_step(m, D, t, "highcourt", ROT, r)
	check(action == "play", "M re-entering with the file there plays at once")
	played[#played + 1] = track
	local pushed = false
	while #played < 8 do
		t = t + 1
		local a, n = R.music_step(m, D, t, "highcourt", ROT, r)
		if a == "play" then played[#played + 1] = n end
		if a == "push" then pushed = true end
	end
	check(not pushed, "M every file there: no push")
	local cycle_ok = true
	for i = 2, #played do
		if index_of(ROT, played[i]) ~= index_of(ROT, played[i - 1]) % #ROT + 1 then cycle_ok = false end
	end
	check(cycle_ok, "M the rotation plays every track in turn: " .. table.concat(played, ","))

	-- the rotation starts at a random place
	local starts = {}
	for seed = 1, 40 do
		local q = R.music_new(true)
		local _, n = R.music_step(q, D, 0, "highcourt", ROT, seeded(seed))
		starts[n] = true
	end
	local count = 0
	for _ in pairs(starts) do count = count + 1 end
	check(count == #ROT, "M the first track varies with each entry")

	-- leaving while the first download is pending: a late delivery plays nothing
	local q = R.music_new(true)
	local _, n = R.music_step(q, D, 0, "kezamba", {"forest_walk", "the_great_sea"}, r)
	check(R.music_step(q, D, 4, nil, {}, r) == nil, "M leaving before the first track: nothing to stop")
	check(R.music_delivered(q, D, n, 6) == nil, "M a late delivery after leaving plays nothing")

	-- music off: stop, nothing for an hour in the capital; on: starts again
	local o = R.music_new(true)
	o.delivered = {forest_walk = true, the_great_sea = true}
	check(R.music_step(o, D, 0, "kezamba", {"forest_walk", "the_great_sea"}, r) == "play",
		"M off test: playing")
	check(R.music_set_on(o, false) == "stop", "M music off stops the track")
	check(not R.music_active(o), "M music off: the bed's turn")
	any = false
	for tt = 2, 3600, 2 do
		if R.music_step(o, D, tt, "kezamba", {"forest_walk", "the_great_sea"}, r) ~= nil then any = true end
	end
	check(not any, "M music off: no push and no play in a capital for an hour")
	check(R.music_set_on(o, true) == nil, "M on returns no action")
	check(R.music_step(o, D, 3602, "kezamba", {"forest_walk", "the_great_sea"}, r) == "play",
		"M music on in a capital: plays on the next pass")
	check(R.music_set_on(o, false) == "stop" and R.music_set_on(o, false) == nil,
		"M off twice: one stop")

	-- a lost push is given up and the rotation moves on
	local g = R.music_new(true)
	local _, first = R.music_step(g, D, 0, "nhal_veyr", {"katabasis_i", "permafrost"}, r)
	check(R.music_step(g, D, D.music.push_timeout, "nhal_veyr", {"katabasis_i", "permafrost"}, r) == nil,
		"M a push is waited for up to push_timeout")
	R.music_step(g, D, D.music.push_timeout + 2, "nhal_veyr", {"katabasis_i", "permafrost"}, r)
	local a3, other = R.music_step(g, D, D.music.push_timeout + 4, "nhal_veyr",
		{"katabasis_i", "permafrost"}, r)
	check(a3 == "push" and other ~= first, "M a lost push is given up, the next track pushed")
	-- a refused push holds every push for `retry` seconds
	local f = R.music_new(true)
	local _, refused = R.music_step(f, D, 0, "nhal_veyr", {"katabasis_i", "permafrost"}, r)
	R.music_push_failed(f, D, refused, 0)
	any = false
	for tt = 2, D.music.retry - 1, 2 do
		if R.music_step(f, D, tt, "nhal_veyr", {"katabasis_i", "permafrost"}, r) ~= nil then any = true end
	end
	local a4, after = R.music_step(f, D, D.music.retry, "nhal_veyr", {"katabasis_i", "permafrost"}, r)
	check(not any and a4 == "push" and after ~= refused, "M a refused push: a hold, then the next track")
	-- a capital without a shipped track counts as none (the bed plays)
	local e = R.music_new(true)
	check(R.music_step(e, D, 0, "lethariel", {}, r) == nil and not R.music_active(e),
		"M a capital with no shipped track: no music, the bed")
	-- music off at join: nothing
	local z = R.music_new(false)
	check(R.music_step(z, D, 0, "highcourt", ROT, r) == nil and not R.music_active(z),
		"M music off from the start: nothing in a capital")
end

-- ---------------------------------------------------------------------------
-- B  either music or the bed
-- ---------------------------------------------------------------------------
do
	check(R.bed_wanted("human", true) == false and R.bed_wanted(nil, true) == false,
		"B music plays: the bed is silent")
	check(R.bed_wanted("human", false) == "human" and R.bed_wanted(nil, false) == nil and
		R.bed_wanted(false, false) == false, "B no music: the bed as today")
	local b = {seen = 0, key = "human"}
	check(R.bed_should_change(b, false, false, true) == true, "B music starts: the bed goes at once")
	b.key = false
	check(R.bed_should_change(b, false, false, true) == false, "B music goes on: stays silent")
	check(R.bed_should_change(b, "human", false, false) == true, "B music ends: the bed returns at once")
	b.key = "human"
	check(R.bed_should_change(b, "night", false, false) == false and
		R.bed_should_change(b, "night", false, false) == true, "B other changes keep the two-pass rule")
end

-- ---------------------------------------------------------------------------
-- L  which capital a player counts as in
-- ---------------------------------------------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
-- A square start town round (0, 0) (|x|, |z| <= 40) and a square capital
-- city round (1000, 0) (|x - 1000|, |z| <= 100).
local function footprint_at(x, z)
	if math.abs(x) <= 40 and math.abs(z) <= 40 then return "hard:start" end
	if math.abs(x - 1000) <= 100 and math.abs(z) <= 100 then return "hard:capital" end
	return nil
end
local TOWNS = {{name = "Dawnmere", x = 0, z = 0, footprint = "hard:start"},
	{name = "Highcourt", x = 1000, z = 0, footprint = "hard:capital", capital = "highcourt"}}
do
	local resolve, town_at = L.resolver({zone_at = function() return "zone" end,
		names = {zone = "Zone"}, towns = TOWNS, reach = 266, footprint_at = footprint_at})
	local function at(prev, x, z)
		local _, _, here = resolve(x, z)
		return L.capital_at(town_at, prev, x, z, here)
	end
	local text, town, here = resolve(1000, 0)
	check(text == "Highcourt" and town == true and here.capital == "highcourt",
		"L resolve names the city and returns its row")
	text, town, here = resolve(0, 0)
	check(text == "Dawnmere" and town == true and here.capital == nil, "L a start town is no capital")
	check(at(nil, 1000, 50) == "highcourt", "L inside the city: its capital")
	check(at(nil, 10, 10) == nil, "L a start town: none")
	check(at(nil, 500, 500) == nil, "L the wild: none")
	check(at(nil, 1105, 0) == nil, "L entering needs a step into the city")
	check(at("highcourt", 1105, 0) == "highcourt", "L just outside, coming from inside: still in")
	check(at("highcourt", 1100 + L.CAPITAL_MARGIN + 2, 0) == nil, "L beyond the margin: out")
	check(at("highcourt", 1104, 104) == "highcourt", "L just outside a corner: still in")
	-- walking along the border, a few nodes in and out: no toggle
	local prev, changes = nil, 0
	for step = 0, 180 do
		local z = -90 + step
		local x = 1100 + ((step % 4 < 2) and -2 or 3)
		local now = at(prev, x, z)
		if step > 0 and now ~= prev then changes = changes + 1 end
		prev = now
	end
	check(changes == 0 and prev == "highcourt", "L walking along the border does not toggle")
	check(L.CAPITAL_MARGIN >= 4 and L.CAPITAL_MARGIN <= 16, "L a few nodes of hysteresis")
end

-- The real location.lua on fakes: the capital is told by its anchor slot.
do
	local now_us = 0
	local loaded, joins, steps, players = {}, {}, {}, {}
	local saved_core, saved_core_g, saved_zones, saved_home, saved_map =
		rawget(_G, "core"), rawget(_G, "grug_core"), rawget(_G, "grug_zones"),
		rawget(_G, "grug_home"), rawget(_G, "grug_map")
	rawset(_G, "core", {
		get_current_modname = function() return "grug_map" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
		get_us_time = function() return now_us end,
		get_worldpath = function() return "/nonexistent/grug_r35_m_world" end,
		safe_file_write = function() return false end,
		log = function() end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function() end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(players) do list[#list + 1] = p end
			return list
		end,
		get_player_by_name = function(name) return players[name] end,
		get_player_window_information = function() return nil end,
	})
	rawset(_G, "grug_core", {
		player_in_creation_stasis = function() return false end,
		FEED_COLOR = {notice = 0xf0e6c8},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function()
			return {{key = "dawnmere", display_name = "Dawnmere", slot = "start",
					anchor = {x = 0, y = 10, z = 0}},
				{key = "highcourt", display_name = "Highcourt", slot = "capital",
					anchor = {x = 1000, y = 10, z = 0}},
				{key = "goldmead_village", display_name = "Goldmead Village", slot = "village",
					anchor = {x = 500, y = 10, z = 500}}}
		end,
	})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	rawset(_G, "grug_zones", {
		id_at = function() return "zone" end,
		get = function() return {id = "zone", numeric_id = 1, display_name = "Zone",
			level_min = 1, level_max = 10} end,
		water_class_at = function() return "land" end,
		hard_footprint_in = function(x, z)
			local id = footprint_at(x, z)
			if id then return id, "town" end
			return nil
		end,
	})
	rawset(_G, "grug_home", {locations = function() return {} end})
	rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
	grug_map.atlas.set_base_texture("base.png")
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	local M = grug_map.location
	local p = {name = "ana", pos = {x = 0, y = 10, z = 0}, n = 0}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:hud_add() self.n = self.n + 1 return self.n end
	function p:hud_change() end
	players.ana = p
	for _, fn in ipairs(joins) do fn(p) end
	local function walk_to(x, z)
		p.pos = {x = x, y = 10, z = z}
		for _ = 1, 12 do
			now_us = now_us + 100000
			for _, fn in ipairs(steps) do fn(0.1) end
		end
	end
	walk_to(0, 0)
	check(M.in_town("ana") and M.capital_of("ana") == nil, "L location.lua: a start town is no capital")
	walk_to(1000, 0)
	check(M.in_town("ana") and M.capital_of("ana") == "highcourt",
		"L location.lua: the capital by its anchor slot and key")
	walk_to(1104, 0)
	check(not M.in_town("ana") and M.capital_of("ana") == "highcourt",
		"L location.lua: the hysteresis keeps the capital just outside")
	walk_to(1130, 0)
	check(M.capital_of("ana") == nil, "L location.lua: out beyond the margin")
	walk_to(500, 500)
	check(M.capital_of("ana") == nil and not M.in_town("ana"), "L location.lua: a village is neither")
	rawset(_G, "core", saved_core)
	rawset(_G, "grug_core", saved_core_g)
	rawset(_G, "grug_zones", saved_zones)
	rawset(_G, "grug_home", saved_home)
	rawset(_G, "grug_map", saved_map)
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
	local shipped = {}
	for _, names in pairs(D.beds) do
		for _, n in ipairs(names) do shipped[#shipped + 1] = n .. ".ogg" end
	end
	for _, e in pairs(D.emitters) do shipped[#shipped + 1] = e.sound .. ".ogg" end
	local music = {}
	for _, track in pairs(D.tracks) do music[#music + 1] = track.file end
	rawset(_G, "core", {
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
		get_timeofday = function() return 0.5 end,
		registered_nodes = {},
		get_content_id = function() return 0 end,
		get_node_raw = function() return 0 end,
		find_nodes_in_area = function() return {} end,
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
	})
	local in_town, capital = {}, {}
	rawset(_G, "grug_core", {
		atmosphere_moods = {human = true},
		get_atmosphere = function() return "human" end,
		is_day_phase = function() return true end,
	})
	rawset(_G, "grug_map", {location = {
		in_town = function(name) return in_town[name] == true end,
		capital_of = function(name) return capital[name] end}})
	dofile(MOD .. "/init.lua")
	for _, fn in ipairs(loaded) do fn() end
	local A = rawget(_G, "grug_ambience")

	local store = {}
	local meta = {}
	function meta:get(k) return store[k] end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) store[k] = tostring(v) end
	local ana = {}
	function ana:get_player_name() return "ana" end
	function ana:get_pos() return {x = 0, y = 10, z = 0} end
	function ana:get_meta() return meta end
	players.ana = ana
	for _, fn in ipairs(joins) do fn(ana) end
	local function run(seconds)
		for _ = 1, math.floor(seconds / 0.25 + 0.5) do
			us = us + 250000
			for _, fn in ipairs(steps) do fn(0.25) end
		end
	end
	local function filter(list, fn)
		local out = {}
		for _, s in ipairs(list) do if fn(s) then out[#out + 1] = s end end
		return out
	end
	local function is_bed(s) return s.params.loop and not s.params.pos end
	local function is_music(s) return s.spec.name:find("^grug_music_") ~= nil end
	local function fades_of(handle, gain)
		return filter(fades, function(f) return f.handle == handle and (gain == nil or f.gain == gain) end)
	end

	check(A.get(ana, "music").on and A.get(ana, "music").volume == 35, "R music defaults to on at 35 %")
	check(A.get(ana, "ambience").volume == 100, "R ambience stays at 100 %")

	-- a start town: the town bed, no music for 10 minutes
	in_town.ana = true
	run(600)
	local beds = filter(sounds, is_bed)
	check(#beds == 1 and math.abs(beds[1].spec.gain - D.gains.bed * D.gains.town_bed) < 1e-9,
		"R start town: the town bed")
	check(#pushes == 0 and #filter(sounds, is_music) == 0, "R start town: no music push or play")
	local bed_handle = beds[1].handle

	-- entering Highcourt: a push of its rotation, the bed fades in the same pass
	capital.ana = "highcourt"
	fades = {}
	run(2)
	check(#pushes == 1, "R entering a capital: one push within a pass (" .. #pushes .. ")")
	local push = pushes[1]
	local file = push and push.options.filepath:match("([^/]+)%.ogg$")
	local in_rotation = false
	for _, id in ipairs(D.rotations.highcourt) do
		if D.tracks[id].file == file .. ".ogg" then in_rotation = true end
	end
	check(in_rotation and push.options.to_player == "ana" and push.options.ephemeral == false and
		push.options.client_cache == true, "R the push: a Highcourt track, to the player, cached")
	check(#fades_of(bed_handle, 0) == 1, "R the bed fades out as music starts")
	push.callback("ana")
	local tracks = filter(sounds, is_music)
	check(#tracks == 1 and tracks[1].spec.name == file and not tracks[1].params.loop and
		math.abs(tracks[1].spec.gain - D.gains.music * 0.35) < 1e-9,
		"R the track plays on delivery at 35 % volume")
	local track_handle = tracks[1].handle
	run(20)
	check(#filter(sounds, is_bed) == 1, "R no bed while music plays")

	-- a volume change fades the playing track
	fades = {}
	commands.music.func("ana", "50")
	check(#fades == 1 and fades[1].handle == track_handle and
		math.abs(fades[1].gain - D.gains.music * 0.5) < 1e-9, "R /music 50 fades the track to half")
	-- music off: the track fades out, the town bed returns on the next pass
	fades = {}
	local ok, msg = commands.music.func("ana", "off")
	local off = fades_of(track_handle, 0)
	check(ok and msg:find("off") and #off == 1 and
		math.abs(off[1].step - D.gains.music * 0.5 / D.music.fade_out) < 1e-9,
		"R /music off fades the track out over fade_out s")
	check(store["grug_ambience:music_off"] == "1", "R music off stored in player meta")
	run(2)
	beds = filter(sounds, is_bed)
	check(#beds == 2 and math.abs(beds[2].spec.gain - D.gains.bed * D.gains.town_bed) < 1e-9,
		"R music off in a capital: the capital's bed plays again")
	pushes = {}
	run(600)
	check(#pushes == 0 and #filter(sounds, is_music) == 1, "R music off: no push, no play")

	-- music on again: the bed goes, a track plays (pushed first unless the
	-- rotation's random start is the one the player has)
	bed_handle = beds[2].handle
	fades = {}
	commands.music.func("ana", "on")
	run(2)
	check(#pushes <= 1, "R music on: at most one push")
	if pushes[1] then pushes[1].callback("ana") end
	tracks = filter(sounds, is_music)
	check(#fades_of(bed_handle, 0) == 1 and #tracks == 2, "R music on: the bed goes, music plays")
	track_handle = tracks[2].handle

	-- leaving the capital: the music fades out, the bed returns in the same pass
	capital.ana = nil
	in_town.ana = nil
	fades = {}
	run(2)
	beds = filter(sounds, is_bed)
	check(#fades_of(track_handle, 0) == 1 and #beds == 3 and
		math.abs(beds[3].spec.gain - D.gains.bed) < 1e-9, "R leaving: music fades, the bed returns")
	pushes = {}
	run(600)
	check(#pushes == 0 and #filter(sounds, is_music) == 2, "R outside: no music")

	-- settings: 5 % steps, an unchanged dropdown does nothing, /music on after 0
	commands.music.func("ana", "35")
	local fs = A.settings_formspec(ana, 0.2, 1.0)
	local items = fs:match("grug_ambience_music_volume;([^;]*);")
	local n_items = 0
	for _ in (items or ""):gmatch("[^,]+") do n_items = n_items + 1 end
	check(n_items == 21 and fs:find("grug_ambience_music_volume;[^;]*;8;true%]") ~= nil,
		"R Help: 21 volume steps, music shows 35 %")
	check(not A.handle_settings_fields(ana, {grug_ambience_music_volume = "8",
		grug_ambience_ambience_volume = "21"}), "R Help: an unchanged dropdown does nothing")
	commands.music.func("ana", "37")
	check(not A.handle_settings_fields(ana, {grug_ambience_music_volume = "8"}) and
		A.get(ana, "music").volume == 37, "R Help: a volume between steps stays on submit")
	check(A.handle_settings_fields(ana, {grug_ambience_music_volume = "11"}) and
		A.get(ana, "music").volume == 50, "R Help: a new step applies")
	commands.music.func("ana", "0")
	commands.music.func("ana", "on")
	check(A.get(ana, "music").on and A.get(ana, "music").volume == 35,
		"R /music on after 0 restores 35 %")
	check(commands.music.description:find("capitals") ~= nil and
		commands.music.description:find("35") ~= nil, "R /music help names the capitals and 35 %")

	-- leave: later callback harmless
	players.ana = nil
	for _, fn in ipairs(leaves) do fn(ana) end
	check(pcall(push.callback, "ana"), "R a callback after leaving does nothing")
end

-- ---------------------------------------------------------------------------
-- D  data
-- ---------------------------------------------------------------------------
do
	local text = io.open(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua"):read("*a")
	local capitals = {}
	for key in text:gmatch('key = "([%w_]+)", label = "[^"]*", race = "[%w_]+",%s*slot = "capital"') do
		capitals[#capitals + 1] = key
	end
	check(#capitals == 6, "D six capitals found in r7_settlement.lua (" .. #capitals .. ")")
	local rotations = 0
	for _ in pairs(D.rotations) do rotations = rotations + 1 end
	check(rotations == 6, "D one rotation per capital, nothing else")
	local feast = false
	for _, rotation in pairs(D.rotations) do
		for _, id in ipairs(rotation) do if id == "master_of_the_feast" then feast = true end end
	end
	check(not feast and D.tracks.master_of_the_feast ~= nil,
		"D Master of the Feast in no rotation, still in the game")
	local used = {}
	for _, key in ipairs(capitals) do
		local rotation = D.rotations[key]
		check(rotation and #rotation >= 2, "D capital " .. key .. " has a rotation")
		for _, id in ipairs(rotation or {}) do
			check(D.tracks[id] ~= nil, "D " .. key .. " track " .. id .. " known")
			used[id] = true
		end
	end
	local tracks = 0
	for id, track in pairs(D.tracks) do
		tracks = tracks + 1
		local f = io.open(MOD .. "/music/" .. track.file, "rb")
		check(f ~= nil, "D track " .. id .. " shipped")
		if f then f:close() end
	end
	check(tracks == 16, "D all 16 tracks stay in the game (" .. tracks .. ")")
	check(D.pools == nil and D.music_groups == nil, "D no region pools")
	local help = io.open(repo .. "/mods/PLAYER/grug_inventory/help.lua"):read("*a")
	check(help:find("Music plays only in the six capitals", 1, true) ~= nil and
		help:find("lands, the front and the sea", 1, true) == nil, "D the Help text: capitals only")
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	print(("R35 M PORTABLE FAIL %d/%d"):format(#failures, checks))
	os.exit(1)
end
print("R35 M PORTABLE PASS checks=" .. checks)
