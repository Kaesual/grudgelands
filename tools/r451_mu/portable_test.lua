-- 0.45.1 lane MU portable test (LuaJIT): the "Now playing" box under the
-- minimap (fix plan row 11).
--
--   luajit tools/r451_mu/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua, data.lua and init.lua (the latter
-- on a fake engine whose grug_map minimap records what it is told), and
-- grug_core hud_layout.lua and grug_map minimap_view.lua. The minimap's own
-- drawing of the box is checked in tools/r27_minimap (block P). Checks:
--   D  data: every track has a title and an artist, the ones its
--      LICENSE-media.md row credits; the note icon (the user's pick) ships
--      with its row;
--   N  which track really plays (rules.lua now_playing) through the
--      scheduler: none while the first download is pending, the track while
--      it plays, none in the pause, the next one after it, none on leaving
--      and with music off;
--   G  geometry over desktop and web-sized windows and GUI scalings: the box
--      sits under the location line, never past the bezel's right edge or
--      the window's left edge, centred when it is narrower than the bezel,
--      and its width estimate holds every shipped title and artist as the
--      font measures them;
--   R  runtime on a fake engine: the minimap is told the track on its
--      start, nil in the pause, on leaving, with music off and at volume 0,
--      the next track after the pause, and nothing while nothing changes.
-- Prints "R451 MU PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local MOD = repo .. "/mods/CORE/grug_ambience"
local R = dofile(MOD .. "/rules.lua")
local D = dofile(MOD .. "/data.lua")

local function read(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

-- A seeded stand-in for math.random(a, b).
local function seeded(seed)
	local state = seed
	return function(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		if not a then return state / 2147483648 end
		return a + state % (b - a + 1)
	end
end

-- ---------------------------------------------------------------------------
-- D  data
-- ---------------------------------------------------------------------------
do
	local license = read(MOD .. "/LICENSE-media.md") or ""
	local credited = {}
	for file, title, author in license:gmatch("| `music/([^`]+)` | ([^|]-) | ([^|;]-)[;|]") do
		credited[file] = {title = title, artist = author:match("^(.-)%s*$")}
	end
	-- The one deliberate display title (the user, 0.45.1): shown shorter than
	-- the source credits it; LICENSE-media.md keeps the source's title.
	local DISPLAY = {town_theme = {credited = "Town Theme RPG", shown = "Town Theme"}}
	local count = 0
	for id, track in pairs(D.tracks) do
		count = count + 1
		local row = credited[track.file]
		check(type(track.title) == "string" and track.title ~= "" and
			type(track.artist) == "string" and track.artist ~= "",
			"D " .. id .. " has a title and an artist")
		local display = DISPLAY[id]
		local title_ok = row and (display and row.title == display.credited and
			track.title == display.shown or not display and row.title == track.title)
		check(title_ok and row.artist == track.artist,
			"D " .. id .. " as LICENSE-media.md credits it (" .. tostring(row and row.title) ..
			" / " .. tostring(row and row.artist) .. ")")
	end
	check(count == 16, "D all 16 tracks (" .. count .. ")")
	local png = read(MOD .. "/textures/grug_ambience_note.png")
	local w = png and #png >= 24 and png:sub(13, 16) == "IHDR" and
		((png:byte(17) * 256 + png:byte(18)) * 256 + png:byte(19)) * 256 + png:byte(20)
	check(w == 24, "D the note icon ships, 24 px")
	check(license:find("grug_ambience_note.png", 1, true) and
		license:find("GPT-6 Astra", 1, true) and license:find("r451_tx/paint_art.py", 1, true) and
		license:find("CC0-1.0", 1, true), "D the note icon's LICENSE-media row")
end

-- ---------------------------------------------------------------------------
-- N  which track really plays
-- ---------------------------------------------------------------------------
do
	local r = seeded(7)
	local ROT = D.rotations.highcourt
	local m = R.music_new(true)
	check(R.now_playing(m) == nil, "N nothing before a capital")
	local action, first = R.music_step(m, D, 0, "highcourt", ROT, r)
	check(action == "push" and R.now_playing(m) == nil, "N entering: none while the download is pending")
	R.music_delivered(m, D, first, 3)
	check(R.now_playing(m) == first, "N the track while it plays")
	-- the next track is pushed and arrives during the play
	local next_id
	for t = 4, m.ends_at - 1 do
		local a, n = R.music_step(m, D, t, "highcourt", ROT, r)
		if a == "push" then next_id = n; R.music_delivered(m, D, n, t + 1) end
	end
	check(next_id and R.now_playing(m) == first, "N still the first track at its last second")
	local ends = m.ends_at
	R.music_step(m, D, ends, "highcourt", ROT, r)
	check(R.now_playing(m) == nil, "N none in the pause")
	R.music_step(m, D, ends + D.music.pause, "highcourt", ROT, r)
	check(R.now_playing(m) == next_id, "N the next track after the pause")
	check(R.music_step(m, D, ends + D.music.pause + 2, nil, {}, r) == "stop" and
		R.now_playing(m) == nil, "N none on leaving (with the fade-out)")
	R.music_step(m, D, ends + 100, "highcourt", ROT, r)
	check(R.now_playing(m) ~= nil, "N back in the capital with the file there: plays at once")
	check(R.music_set_on(m, false) == "stop" and R.now_playing(m) == nil, "N none with music off")
	R.music_set_on(m, true)
	check(R.now_playing(m) == nil, "N music on: none until the next pass starts a track")
end

-- ---------------------------------------------------------------------------
-- G  geometry
-- ---------------------------------------------------------------------------
do
	rawset(_G, "grug_core", {})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	local layout = grug_core.hud_layout
	local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
	local P = V.NOW_PLAYING
	-- The minimap geometry of a normal-size base (as tools/r27_minimap).
	local v = V.new({quality = "normal", width = 1080, height = 960, tiles = {}},
		{min_x = -3500, max_x = 3500, min_z = -3111, max_z = 3111})
	-- Advance widths in em of every shipped title and artist in the HUD's
	-- default font, measured from reference_projects/luanti/fonts/
	-- Arimo-Regular.ttf (cmap and hmtx, no kerning; 0.45.1 lane MU).
	local MEASURED = {
		a_dragons_lullaby = {8.36, 6.06}, achaidh_cheide = {7.06, 6.89},
		fantasy_orchestral_theme = {11.84, 1.61}, folk_round = {5.11, 6.89},
		forest_walk = {5.33, 9.12}, katabasis_i = {4.95, 6.06},
		master_of_the_feast = {8.61, 6.89}, memories_of_stone = {8.61, 6.06},
		minstrel_guild = {6.11, 6.89}, permafrost = {4.89, 6.06},
		soliloquy = {4.06, 6.61}, teller_of_the_tales = {8.00, 6.89},
		thatched_villagers = {8.28, 6.89}, the_great_sea = {6.56, 6.06},
		town_theme = {5.84, 4.89}, village_consort = {6.78, 6.89},
	}
	local WINDOWS = {
		{x = 1280, y = 720, hud = 1, gui = 1}, {x = 1920, y = 1080, hud = 1, gui = 1},
		{x = 2560, y = 1440, hud = 2, gui = 2}, {x = 1920, y = 1080, hud = 1, gui = 1.5},
		-- browser windows of the web build
		{x = 1024, y = 600, hud = 1, gui = 1}, {x = 1366, y = 768, hud = 1, gui = 1},
		{x = 800, y = 600, hud = 1, gui = 1},
	}
	local widest = 0
	for _, w in ipairs(WINDOWS) do
		local frame = V.frame(v, layout.minimap_box({size = {x = w.x, y = w.y},
			real_hud_scaling = w.hud, real_gui_scaling = w.gui}))
		local label = ("%dx%d hud %g gui %g"):format(w.x, w.y, w.hud, w.gui)
		check(frame.gui == w.gui, "G " .. label .. ": the frame carries the GUI scaling")
		local line_top = frame.center_y + frame.diameter / 2 + 4 * frame.hud
		local right = frame.center_x + frame.diameter / 2
		local fits, under, inside, centred, holds = true, true, true, true, true
		for id, track in pairs(D.tracks) do
			local b = V.now_playing_box(frame, line_top, track.title, track.artist)
			if w.x == 1920 and w.gui == 1 then widest = math.max(widest, b.w) end
			under = under and b.y >= line_top + P.line * w.gui
			inside = inside and b.x + b.w <= right + 0.5 and b.x >= 0
			if b.w <= frame.diameter then
				centred = centred and math.abs(b.x + b.w / 2 - frame.center_x) <= 1
			end
			fits = fits and b.icon_x >= b.x and b.icon_y >= b.y and
				b.icon_y + b.icon <= b.y + b.h and b.text_x > b.icon_x + b.icon and
				b.text_y >= b.y and b.text_y + 2 * P.line_em * P.font * w.gui <= b.y + b.h + 1
			local m = MEASURED[id]
			local need = math.max(m[1], m[2]) * P.font * w.gui
			holds = holds and m and b.x + b.w - (b.text_x + need) >= 0
			if not holds then print("short: " .. label .. " " .. id) end
		end
		check(under, "G " .. label .. ": below the location line")
		check(inside, "G " .. label .. ": not past the bezel's right edge or the window's left")
		check(centred, "G " .. label .. ": centred under the bezel when narrower")
		check(fits, "G " .. label .. ": icon and two lines inside the box")
		check(holds, "G " .. label .. ": the width holds every title and artist")
	end
	check(widest <= 285, "G the widest box at 1080p is about 280 px (" .. widest .. ")")
end

-- ---------------------------------------------------------------------------
-- R  runtime on a fake engine
-- ---------------------------------------------------------------------------
do
	local us = 0
	local steps, joins, leaves, loaded, commands = {}, {}, {}, {}, {}
	local players = {}
	local pushes = {}
	local music = {}
	for _, track in pairs(D.tracks) do music[#music + 1] = track.file end
	rawset(_G, "core", {
		get_current_modname = function() return "grug_ambience" end,
		get_modpath = function() return MOD end,
		get_dir_list = function(path)
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
		sound_play = function() return 1 end,
		sound_fade = function() end,
		dynamic_add_media = function(options, callback)
			pushes[#pushes + 1] = {options = options, callback = callback}
			return true
		end,
		formspec_escape = function(text) return text end,
		log = function() end,
	})
	rawset(_G, "grug_core", {
		atmosphere_moods = {human = true},
		get_atmosphere = function() return "human" end,
		is_day_phase = function() return true end,
	})
	local capital = {}
	local told = {}
	rawset(_G, "grug_map", {
		location = {in_town = function(name) return capital[name] ~= nil end,
			capital_of = function(name) return capital[name] end},
		minimap = {set_now_playing = function(name, track)
			told[#told + 1] = {name = name, track = track}
		end},
	})
	dofile(MOD .. "/init.lua")
	for _, fn in ipairs(loaded) do fn() end

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
	local delivered = 0
	-- Steps the server; every push arrives one step after it was made.
	local function run(seconds)
		for _ = 1, math.floor(seconds / 0.25 + 0.5) do
			us = us + 250000
			for _, fn in ipairs(steps) do fn(0.25) end
			while delivered < #pushes do
				delivered = delivered + 1
				pushes[delivered].callback("ana")
			end
		end
	end
	local function title_of(entry)
		return entry and entry.track and entry.track.title
	end
	-- The track row of call `i` (false when there was no such call).
	local function told_at(i)
		return told[i] ~= nil and told[i].track
	end
	-- The id of a told track row (a row of the runtime's own data table).
	local function id_of(row)
		for id, track in pairs(grug_ambience.data.tracks) do
			if track == row then return id end
		end
	end

	run(60)
	check(#told == 0, "R outside a capital: the minimap is told nothing")
	capital.ana = "highcourt"
	run(2.25)
	check(#told == 1 and told[1].name == "ana" and told[1].track and
		told[1].track.title and told[1].track.artist,
		"R a track starts: the minimap is told its title and artist (" .. tostring(title_of(told[1])) .. ")")
	local first = id_of(told[1] and told[1].track)
	local in_rotation = false
	for _, id in ipairs(D.rotations.highcourt) do if id == first then in_rotation = true end end
	check(in_rotation, "R the told track is of the capital's rotation")
	-- the whole track: nothing told until its end (the next push included)
	local length = D.tracks[first].seconds
	run(length - 5)
	check(#told == 1, "R while the track plays nothing is told (" .. #told .. " calls)")
	run(5 + 2)
	check(#told == 2 and told_at(2) == nil, "R the track ends: hidden in the pause")
	run(D.music.pause + 2)
	local second = id_of(told[3] and told[3].track)
	check(#told == 3 and second and second ~= first, "R after the pause: the next track is told")
	run(20)
	check(#told == 3, "R nothing told while it plays on")
	-- music off and on
	commands.music.func("ana", "off")
	check(#told == 4 and told_at(4) == nil, "R /music off: hidden at once")
	run(120)
	check(#told == 4, "R music off: nothing told")
	commands.music.func("ana", "on")
	check(#told == 4, "R /music on: nothing until a track starts")
	run(2.25)
	check(#told == 5 and told_at(5), "R music on in the capital: the playing track is told")
	commands.music.func("ana", "50")
	check(#told == 5, "R a volume change tells nothing")
	commands.music.func("ana", "0")
	check(#told == 6 and told_at(6) == nil, "R volume 0: hidden")
	commands.music.func("ana", "35")
	run(2.25)
	check(#told == 7 and told_at(7), "R volume back: the track is told again")
	-- leaving the capital: hidden in the pass that fades the track out
	capital.ana = nil
	run(2.25)
	check(#told == 8 and told_at(8) == nil, "R leaving the capital: hidden")
	run(600)
	check(#told == 8, "R outside: nothing told for ten minutes")
	-- the pause between tracks while the next one's download is still pending
	capital.ana = "highcourt"
	run(2.25)
	check(#told == 9 and told_at(9), "R entering again: told")
	for _, fn in ipairs(leaves) do fn(ana) end
	players.ana = nil
	run(10)
	check(#told == 9, "R a player who left is told nothing")
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	error(("R451 MU PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R451 MU PORTABLE PASS checks=" .. checks)
