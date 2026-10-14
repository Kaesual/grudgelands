-- Round 48 lane HUD portable test (LuaJIT): the minimap's side elements,
-- the daytime band and the mail icon (round plan §4.1, sell plan §3.6).
--
--   luajit tools/r48_hud/portable_test.lua [repo]
--
-- Loads the REAL grug_core hud_layout.lua, grug_map minimap_view.lua and
-- minimap.lua (on a fake engine without a world map base: the minimap is
-- unavailable), the grug_ambience track data and the clock constants of
-- grug_core atmosphere.lua. The minimap-shown runtime (beside the bezel,
-- hiding and showing it) is tools/r27_minimap block H. Checks:
--   D  the band's position: 04:30 is 0, 19:29 29, 19:30 30, 00:00 35, 04:29
--      39; a simulated world clock at its two speeds gives one position per
--      30 real seconds over the whole day, never backwards;
--   M  the mail icon per unread count: none for 0, 1-9, 9+ above;
--   L  placement over desktop and web windows at GUI scaling 1 and 2 (the
--      user's variant A of follow-up lane HUD2): one row, band then mail
--      icon, both drawn exactly as high (as the client truncates them) and
--      vertically centred; the band 75 % of lane HUD's width at 4:1; shown,
--      the row left of the bezel with its top on the bezel's top; hidden,
--      the row right-aligned in the corner and "Now playing" below it,
--      inside the minimap's box; the gaps; none overlaps another or the
--      quest tracker;
--   R  runtime with the minimap unavailable: the side elements are drawn and
--      updated (the globalstep no longer returns at once), the band sends one
--      hud_change per position and nothing in between, a clock jump shows
--      within the 5 s tick, a count told before the join is kept, the mail
--      icon's slot stays reserved at 0 letters, the mail icon is drawn as
--      high as the band, a resize places everything again;
--   F  the generated images (40 band, 10 mail, the "+" digit) and their
--      LICENSE-media rows.
-- Prints "R48 HUD PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local function read(path)
	local file = io.open(repo .. path, "rb")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

rawset(_G, "grug_core", {})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local layout = grug_core.hud_layout
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")

-- The clock constants as atmosphere.lua sets them.
local atmosphere = read("/mods/CORE/grug_core/atmosphere.lua") or ""
local function constant(name)
	return tonumber(atmosphere:match("grug_core%." .. name .. " = ([%d%.]+)"))
end
local START, FINISH = constant("DAY_PHASE_START"), constant("DAY_PHASE_END")
local DAY_SPEED, NIGHT_SPEED = constant("DAY_TIME_SPEED"), constant("NIGHT_TIME_SPEED")
check(START == 0.1875 and FINISH == 0.8125 and DAY_SPEED == 60 and NIGHT_SPEED == 108,
	"D atmosphere.lua's day phase and clock speeds read")
grug_core.DAY_PHASE_START, grug_core.DAY_PHASE_END = START, FINISH

-- ---------------------------------------------------------------------------
-- D  the band's position
-- ---------------------------------------------------------------------------
do
	local function at(h, m) return (h * 60 + m) / 1440 end
	local function pos(t) return V.daytime_position(t, START, FINISH) end
	check(pos(at(4, 30)) == 0, "D 04:30 is 0 (" .. pos(at(4, 30)) .. ")")
	check(pos(at(19, 29)) == 29, "D 19:29 is 29 (" .. pos(at(19, 29)) .. ")")
	check(pos(at(19, 30)) == 30, "D 19:30 is 30 (" .. pos(at(19, 30)) .. ")")
	-- Midnight is halfway through the 300 s night: 900 + 150 s.
	check(pos(at(0, 0)) == 35, "D 00:00 is 35 (" .. pos(at(0, 0)) .. ")")
	check(pos(at(4, 29)) == 39, "D 04:29 is 39 (" .. pos(at(4, 29)) .. ")")
	check(pos(at(12, 0)) == 15 and pos(1) == 35 and pos(0.999999) == 34,
		"D noon 15, midnight's wrap is seamless")
	-- The engine's clock: speed x real seconds of game time, at the day
	-- speed in the day phase and the night speed outside it
	-- (atmosphere.lua): `t` real seconds after 04:30 the clock shows
	-- clock(t). One position per 30 real seconds, 40 in 1200 s.
	local day_s = (FINISH - START) * 86400 / DAY_SPEED
	local night_s = (1 - (FINISH - START)) * 86400 / NIGHT_SPEED
	check(day_s == 900 and night_s == 300, "D the day phase is 900 s, the night 300 s")
	local function clock(t)
		if t < day_s then return START + t * DAY_SPEED / 86400 end
		return (FINISH + (t - day_s) * NIGHT_SPEED / 86400) % 1
	end
	local exact, backwards, last = true, 0, nil
	for t = 0, 1199.5, 0.5 do
		local p = pos(clock(t))
		if p ~= math.floor(t / 30) then
			exact = false
			print(("D at %.1f s: position %d, expected %d"):format(t, p, math.floor(t / 30)))
		end
		if last and p < last then backwards = backwards + 1 end
		last = p
	end
	check(exact, "D the clock at its two speeds: one position per 30 real seconds")
	check(backwards == 0 and pos(clock(1200)) == 0,
		"D never backwards; after 1200 s the next day starts at 0")
	local seen = {}
	for i = 0, 1439 do seen[pos(i / 1440)] = true end
	local all = true
	for p = 0, 39 do all = all and seen[p] end
	check(all and not seen[40] and not seen[-1], "D every minute of the day maps into 0..39")
	check(V.daytime_texture(0) == "grug_map_daytime_00.png" and
		V.daytime_texture(39) == "grug_map_daytime_39.png", "D the image names")
end

-- ---------------------------------------------------------------------------
-- M  the mail icon per count
-- ---------------------------------------------------------------------------
do
	check(V.mail_texture(0) == "" and V.mail_texture(nil) == "" and V.mail_texture(-2) == "",
		"M no unread letter: no icon")
	local digits = true
	for n = 1, 9 do digits = digits and V.mail_texture(n) == ("grug_map_mail_%d.png"):format(n) end
	check(digits, "M 1-9 show their digit")
	check(V.mail_texture(10) == "grug_map_mail_9p.png" and V.mail_texture(250) ==
		"grug_map_mail_9p.png", "M ten and more show 9+")
end

-- ---------------------------------------------------------------------------
-- L  placement
-- ---------------------------------------------------------------------------
local v = V.new({quality = "normal", width = 1080, height = 960, tiles = {}},
	{min_x = -3500, max_x = 3500, min_z = -3111, max_z = 3111})
local D = dofile(repo .. "/mods/CORE/grug_ambience/data.lua")
local function rect(x, y, w, h) return {x = x, y = y, w = w, h = h} end
local function overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
-- The quest tracker (grug_quests hud.lua): text right-aligned at the right
-- edge minus 20 HUD px, vertically centred, `lines` lines of about 20 GUI
-- px, at most side_text_width characters of about 9 GUI px. The lines it
-- can show without reaching into the minimap's box (hud_layout.lua's
-- clearance note), at most ten.
local function tracker(window, box)
	local hud, gui = window.real_hud_scaling, window.real_gui_scaling
	local W, H = window.size.x, window.size.y
	local lines = math.min(10, math.floor((H / 2 - (box.center_y + box.size / 2)) / (10 * gui)))
	local w = layout.side_text_width(window) * 9 * gui
	return rect(W - 20 * hud - w, H / 2 - lines * 10 * gui, w, lines * 20 * gui), lines
end
do
	local WINDOWS = {
		{1280, 720, 1, 1}, {1920, 1080, 1, 1}, {1280, 720, 1, 2}, {1920, 1080, 1, 2},
		{1280, 720, 2, 2}, {1920, 1080, 2, 2},
		-- browser windows of the web build
		{1366, 768, 1, 1}, {1024, 600, 1, 1},
	}
	for _, w in ipairs(WINDOWS) do
		local window = {size = {x = w[1], y = w[2]}, real_hud_scaling = w[3],
			real_gui_scaling = w[4]}
		local label = ("%dx%d hud %g gui %g"):format(w[1], w[2], w[3], w[4])
		local box = layout.minimap_box(window)
		local frame = V.frame(v, box)
		local quest, lines = tracker(window, box)
		local S = V.SIDE
		-- the client's drawn size of a tw x th texture at exact()'s scale for
		-- w px (minimap.lua: (w + 0.25) / (tw x hud), truncated, hud.cpp)
		local function drawn(w, tw, th)
			local scale = (w + 0.25) / (tw * box.hud)
			return math.floor(tw * scale * box.hud), math.floor(th * scale * box.hud)
		end
		local gap, row_gap = S.gap * box.hud, S.row_gap * box.hud
		local function row_checks(L, mode)
			local mw, mh = drawn(L.mail.w, S.mail_w, S.mail_h)
			local bw, bh = drawn(L.band.w, S.band_w, S.band_h)
			check(mw == L.mail.w and mh == L.mail.h and bw == L.band.w and bh == L.band.h,
				("L %s %s: the client draws the sizes laid out (mail %dx%d, band %dx%d)"):format(
					label, mode, mw, mh, bw, bh))
			check(L.mail.h == L.band.h and L.mail.y == L.band.y,
				("L %s %s: mail and band equally high (%d px), vertically centred"):format(label,
					mode, L.mail.h))
			check(L.band.x + L.band.w <= L.mail.x and
				math.abs(L.mail.x - (L.band.x + L.band.w) - row_gap) <= 1,
				("L %s %s: band left of the mail icon, %d px apart"):format(label, mode,
					L.mail.x - (L.band.x + L.band.w)))
			local today = math.floor(box.size * 0.45 + 0.5) -- lane HUD's band width
			local aspect = L.band.w / L.band.h
			check(math.abs(L.band.w - 0.75 * today) <= 1 and aspect >= 3.8 and aspect <= 4.2,
				("L %s %s: band %d x %d, 75 %% of %d px, %.2f : 1"):format(label, mode, L.band.w,
					L.band.h, today, aspect))
			check(math.abs(L.mail.w / L.mail.h - S.mail_w / S.mail_h) < 0.05, "L " .. label ..
				" " .. mode .. ": the mail icon keeps its image's aspect")
		end
		-- shown
		local L = V.side_layout(box, frame)
		row_checks(L, "shown")
		local mail = rect(L.mail.x, L.mail.y, L.mail.w, L.mail.h)
		local band = rect(L.band.x, L.band.y, L.band.w, L.band.h)
		local left, top = frame.center_x - frame.diameter / 2, frame.center_y - frame.diameter / 2
		check(mail.x + mail.w <= left and math.abs(left - (mail.x + mail.w) - gap) <= 1 and
			band.x >= 0, ("L %s shown: the row left of the bezel, %d px from it"):format(label,
				left - (mail.x + mail.w)))
		check(math.abs(mail.y - top) <= 0.5 and math.abs(band.y - top) <= 0.5,
			"L " .. label .. " shown: the row's top on the bezel's top")
		check(not overlap(mail, band), "L " .. label .. " shown: mail and band apart")
		local line_top = frame.center_y + frame.diameter / 2 + 4 * frame.hud
		local clear = true
		for _, track in pairs(D.tracks) do
			local g = V.now_playing_box(frame, line_top, track.title, track.artist)
			local playing = rect(g.x, g.y, g.w, g.h)
			clear = clear and not overlap(playing, mail) and not overlap(playing, band)
		end
		check(clear, "L " .. label .. " shown: Now playing clear of mail and band")
		check(lines >= 1 and not overlap(mail, quest) and not overlap(band, quest),
			"L " .. label .. " shown: clear of the quest tracker (" .. lines .. " lines)")
		-- hidden
		local H = V.side_layout(box, nil)
		row_checks(H, "hidden")
		mail = rect(H.mail.x, H.mail.y, H.mail.w, H.mail.h)
		band = rect(H.band.x, H.band.y, H.band.w, H.band.h)
		check(mail.w == L.mail.w and band.w == L.band.w, "L " .. label .. " the same sizes in both modes")
		local bx, by = box.center_x - box.size / 2, box.center_y - box.size / 2
		local inside, apart, quest_clear, below = true, true, true, true
		local deepest = 0
		for _, track in pairs(D.tracks) do
			local g = V.now_playing_corner(box, H.playing_right, H.playing_top, track.title,
				track.artist)
			local playing = rect(g.x, g.y, g.w, g.h)
			for _, r in ipairs({mail, band, playing}) do
				-- inside the box's height and right edge; a wide box may grow
				-- past its left edge, as under the bezel
				inside = inside and r.y >= by - 0.5 and r.y + r.h <= by + box.size + 0.5 and
					r.x + r.w <= bx + box.size + 0.5 and r.x >= 0
				quest_clear = quest_clear and not overlap(r, quest)
			end
			apart = apart and not overlap(mail, band) and not overlap(mail, playing) and
				not overlap(band, playing)
			below = below and math.abs(playing.y - (mail.y + mail.h) - gap) <= 1 and
				math.abs(playing.x + playing.w - (bx + box.size)) <= 0.5
			deepest = math.max(deepest, playing.y + playing.h - by)
		end
		check(inside, ("L %s hidden: the row and Now playing inside the box (%d of %d px)"):format(
			label, deepest, box.size))
		check(apart, "L " .. label .. " hidden: mail, band and Now playing apart")
		check(below, "L " .. label .. " hidden: Now playing right-aligned just below the row")
		check(quest_clear, "L " .. label .. " hidden: clear of the quest tracker")
		check(math.abs(mail.x + mail.w - (bx + box.size)) <= 0.5 and math.abs(mail.y - by) <= 0.5,
			"L " .. label .. " hidden: the row right-aligned in the top-right corner")
		if w[1] == 1920 and w[3] == 1 and w[4] == 1 then
			print(("L 1080p: band %dx%d, mail %dx%d, gaps %d / %d px, hidden Now playing top %d"):
				format(L.band.w, L.band.h, L.mail.w, L.mail.h, row_gap, gap, H.playing_top))
		end
		check(V.now_playing_height(window.real_gui_scaling) ==
			V.now_playing_box(frame, line_top, "a", "b").h, "L " .. label .. " the box height")
	end
end

-- ---------------------------------------------------------------------------
-- R  runtime with the minimap unavailable
-- ---------------------------------------------------------------------------
do
	local joins, leaves, steps = {}, {}, {}
	local players, windows = {}, {}
	local tod = 0.5
	rawset(_G, "core", {
		get_current_modname = function() return "grug_map" end,
		get_modpath = function(mod)
			local roots = {grug_map = "/mods/PLAYER/grug_map",
				grug_ambience = "/mods/CORE/grug_ambience"}
			return roots[mod] and repo .. roots[mod] or nil
		end,
		get_modnames = function() return {"grug_ambience", "grug_map"} end,
		get_us_time = function() return 0 end,
		get_timeofday = function() return tod end,
		log = function() end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(players) do list[#list + 1] = p end
			return list
		end,
		get_player_by_name = function(name) return players[name] end,
		get_player_window_information = function(name) return windows[name] end,
	})
	rawset(_G, "grug_map", {atlas = {}})
	rawset(_G, "grug_parties", {register_on_change = function() end})
	rawset(_G, "grug_quests", {register_on_markers_changed = function() end})
	rawset(_G, "grug_factions", {register_on_faction_chosen = function() end})
	dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
	local minimap = grug_map.minimap
	check(not minimap.available(), "R no world map base: the minimap is unavailable")

	local meta = {}
	local me = {name = "me", huds = {}, next_id = 0, changes = {}}
	function me:get_player_name() return self.name end
	function me:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, value) meta[k] = value end}
	end
	function me:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, value in pairs(def) do copy[k] = value end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function me:hud_change(id, stat, value)
		self.huds[id][stat] = value
		self.changes[#self.changes + 1] = {id = id, stat = stat, value = value}
	end
	function me:hud_remove(id) self.huds[id] = nil end
	function me:hud_set_flags() end
	function me:set_minimap_modes() end
	windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	local function step(seconds)
		for _ = 1, math.floor(seconds / 0.25 + 0.5) do
			for _, fn in ipairs(steps) do fn(0.25) end
		end
	end
	local function find(pattern)
		for id, def in pairs(me.huds) do
			if type(def.text) == "string" and def.text:find(pattern) then
				local w = windows.me.size
				return def, id, def.position.x * w.x, def.position.y * w.y
			end
		end
	end

	-- A count told before this mod's join callback (another mod's join ran
	-- first) is kept.
	minimap.set_mail_count("me", 3)
	players.me = me
	for _, fn in ipairs(joins) do fn(me) end
	step(0.25)
	local box = layout.minimap_box(windows.me)
	local H = V.side_layout(box, nil)
	local band, band_id, bx, by = find("^grug_map_daytime_")
	local mail, _, mx, my = find("^grug_map_mail_")
	check(band and band.text == "grug_map_daytime_15.png" and math.abs(bx - H.band.x) < 0.5 and
		math.abs(by - H.band.y) < 0.5, "R unavailable: the band in the corner, noon's position")
	check(mail and mail.text == "grug_map_mail_3.png" and math.abs(mx - H.mail.x) < 0.5 and
		math.abs(my - H.mail.y) < 0.5, "R unavailable: the mail icon told before the join")
	local compass = false
	for _, def in pairs(me.huds) do compass = compass or def.type == "compass" end
	check(not compass, "R unavailable: no minimap element")

	-- One simulated world day at the clock's real speeds: the band sends
	-- one text change per position and nothing else.
	local before = #me.changes
	local seen = {}
	tod = START
	step(5.25) -- the next 5 s tick shows 04:30
	local first = band.text
	local idle_other = 0
	for _ = 1, 1200 * 4 do
		local speed = (tod >= START and tod < FINISH) and DAY_SPEED or NIGHT_SPEED
		tod = (tod + speed / 86400 * 0.25) % 1
		step(0.25)
		seen[band.text] = true
	end
	local band_changes, other = 0, 0
	for i = before + 1, #me.changes do
		local c = me.changes[i]
		if c.id == band_id and c.stat == "text" then band_changes = band_changes + 1
		else other = other + 1 end
	end
	local distinct = 0
	for _ in pairs(seen) do distinct = distinct + 1 end
	check(first == "grug_map_daytime_00.png", "R 04:30 shows position 0 (" .. tostring(first) .. ")")
	-- (the step back to 0 after 1200 s shows on the tick after the loop)
	check(band_changes == 40 and other == idle_other and distinct == 40,
		("R a whole day: %d band changes (the jump to 04:30 and 39 steps), %d other, " ..
			"%d images"):format(band_changes, other, distinct))

	-- A clock jump (/time) shows within the 5 s tick.
	before = #me.changes
	tod = (19 * 60 + 45) / 1440
	local waited = 0
	while band.text ~= ("grug_map_daytime_%02d.png"):format(V.daytime_position(tod, START,
			FINISH)) and waited < 10 do
		step(0.25)
		waited = waited + 0.25
	end
	check(waited <= 5 and #me.changes - before == 1, ("R /time 19:45: shown after %.2f s, " ..
		"one hud_change"):format(waited))

	-- "Now playing" in the corner below the band; mail 12 -> 9+; 0 hides.
	local track = {title = "A Dragon's Lullaby", artist = "Scott Buckley"}
	minimap.set_now_playing("me", track)
	local fill, _, fx, fy = find("^%[fill:")
	local g = V.now_playing_corner(box, H.playing_right, H.playing_top, track.title, track.artist)
	check(fill and math.abs(fx - g.x) < 0.5 and math.abs(fy - g.y) < 0.5 and fy >= by + H.band.h,
		"R unavailable: Now playing in the corner below the band")
	-- the client draws the mail icon exactly as high as the band
	local function height(def, tw, th)
		return math.floor(th * def.scale.y * windows.me.real_hud_scaling),
			math.floor(tw * def.scale.x * windows.me.real_hud_scaling)
	end
	local mh, mw = height(mail, V.SIDE.mail_w, V.SIDE.mail_h)
	local bh, bw = height(band, V.SIDE.band_w, V.SIDE.band_h)
	check(mh == bh and mh == H.mail.h and mw == H.mail.w and bw == H.band.w,
		("R the mail icon drawn %dx%d, the band %dx%d: equally high"):format(mw, mh, bw, bh))
	minimap.set_mail_count("me", 12)
	check(mail.text == "grug_map_mail_9p.png", "R twelve letters: 9+")
	local _, _, bx0, by0 = find("^grug_map_daytime_")
	minimap.set_mail_count("me", 0)
	local _, _, bx1, by1 = find("^grug_map_daytime_")
	check(mail.text == "" and bx1 == bx0 and by1 == by0 and math.abs(bx1 - H.band.x) < 0.5,
		"R no letters: the icon is hidden, its slot kept (the band does not move)")
	minimap.set_mail_count("me", 2)
	-- A resize places everything again (positions are window fractions).
	windows.me = {size = {x = 1280, y = 720}, real_hud_scaling = 1, real_gui_scaling = 2}
	step(0.5)
	box = layout.minimap_box(windows.me)
	H = V.side_layout(box, nil)
	local _, _, mx2, my2 = find("^grug_map_mail_2")
	local _, _, bx2, by2 = find("^grug_map_daytime_")
	g = V.now_playing_corner(box, H.playing_right, H.playing_top, track.title, track.artist)
	local _, _, fx2, fy2 = find("^%[fill:")
	check(mx2 and math.abs(mx2 - H.mail.x) < 0.5 and math.abs(my2 - H.mail.y) < 0.5 and
		math.abs(bx2 - H.band.x) < 0.5 and math.abs(by2 - H.band.y) < 0.5 and
		math.abs(fx2 - g.x) < 0.5 and math.abs(fy2 - g.y) < 0.5,
		"R a resize (720p, GUI scaling 2) places the three again")
	-- The switch has nothing to hide here; the side elements stay.
	minimap.set_enabled(me, false)
	step(0.5)
	check(find("^grug_map_daytime_") and find("^grug_map_mail_2"), "R hidden and unavailable: they stay")
	for _, fn in ipairs(leaves) do fn(me) end
	players.me = nil
	minimap.set_mail_count("me", 5)
	step(1)
	check(true, "R a count told after leaving is ignored without an error")
end

-- ---------------------------------------------------------------------------
-- F  the generated images and their rows
-- ---------------------------------------------------------------------------
do
	local function size(path)
		local png = read(path)
		if not png or #png < 24 or png:sub(13, 16) ~= "IHDR" then return nil end
		local function be(i)
			return ((png:byte(i) * 256 + png:byte(i + 1)) * 256 + png:byte(i + 2)) * 256 +
				png:byte(i + 3)
		end
		return be(17), be(21)
	end
	local TEX = "/mods/PLAYER/grug_map/textures/"
	local bad = {}
	for p = 0, 39 do
		local w, h = size(TEX .. V.daytime_texture(p))
		if w ~= V.SIDE.band_w or h ~= V.SIDE.band_h then bad[#bad + 1] = V.daytime_texture(p) end
	end
	for n = 1, 10 do
		local w, h = size(TEX .. V.mail_texture(n))
		if w ~= V.SIDE.mail_w or h ~= V.SIDE.mail_h then bad[#bad + 1] = V.mail_texture(n) end
	end
	check(#bad == 0, "F 40 band and 10 mail images at their sizes: " .. table.concat(bad, " "))
	local pw, ph = size("/mods/PLAYER/grug_abilities/textures/grug_abilities_cd_digit_p.png")
	check(pw == 28 and ph == 36, "F the cooldown digits' \"+\" (28 x 36)")
	local rows = read("/mods/PLAYER/grug_map/LICENSE-media.md") or ""
	check(rows:find("grug_map_daytime_00.png", 1, true) and rows:find("grug_map_mail_9p.png", 1, true)
		and rows:find("tools/r48_hud/gen_hud_textures.py", 1, true), "F grug_map LICENSE-media rows")
	local abilities = read("/mods/PLAYER/grug_abilities/LICENSE-media.md") or ""
	check(abilities:find("grug_abilities_cd_digit_p.png", 1, true), "F the \"+\" digit's row")
	local parts = true
	for _, name in ipairs({"mail_icon.png", "sun.png", "moon.png", "frame.png", "marker.png",
			"palette.json"}) do
		parts = parts and read("/tools/r48_hud/parts/" .. name) ~= nil
	end
	check(parts, "F the generator's parts")
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	error(("R48 HUD PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R48 HUD PORTABLE PASS checks=" .. checks)
