-- Round 84 lane MAP portable test (LuaJIT; docs/planning/round84-plan.md §4
-- MAP, default 15): the announcements icon under the letter icon. The map
-- window's layers (ruling 13: none changes zoom or scroll) are checked
-- through the window's events in tools/r44_mq; the minimap's runtime
-- elements in tools/r48_hud (block R) and tools/r27_minimap (block H); the
-- feed line in tools/r48_mail (block C).
--
-- Loads the REAL grug_core hud_layout.lua, grug_map minimap_view.lua and
-- grug_mail model.lua. Checks:
--   A  the announcements icon per count: none for 0, 1-9, 9+ above;
--   L  placement over desktop and web windows at GUI scaling 1 and 2: with
--      unread letters the icon under the mail icon, left-aligned with it,
--      `gap` HUD px below the row; without, in the mail icon's place
--      (follow-up 1); at the mail icon's scale (the client draws the size
--      laid out), apart from the mail icon, the band and the quest tracker;
--      shown, left of the bezel; hidden, inside the minimap's box with "Now
--      playing" (every shipped track) right-aligned just below the icons
--      that show, one or two;
--   C  the counts apart: unread letters (expired ones not), unread
--      broadcasts, their sum as before;
--   F  the ten images (87 x 29, the count's left as on the mail icon),
--      their LICENSE-media rows, the badge they are built from.
--
--   luajit tools/r84_map/portable_test.lua [repo]
-- Prints "R84 MAP PORTABLE PASS checks=<n>" or the failures (an error).
local repo = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
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
local S = V.SIDE

-- ---------------------------------------------------------------------------
-- A  the texture per count
-- ---------------------------------------------------------------------------
do
	check(V.announce_texture(0) == "" and V.announce_texture(nil) == "" and
		V.announce_texture(-1) == "", "A no unread announcement: no icon")
	local digits = true
	for n = 1, 9 do
		digits = digits and V.announce_texture(n) == ("grug_map_announce_%d.png"):format(n)
	end
	check(digits, "A 1-9 show their digit")
	check(V.announce_texture(10) == "grug_map_announce_9p.png" and
		V.announce_texture(99) == "grug_map_announce_9p.png", "A ten and more show 9+")
end

-- ---------------------------------------------------------------------------
-- L  placement
-- ---------------------------------------------------------------------------
local function rect(x, y, w, h) return {x = x, y = y, w = w, h = h} end
local function overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
-- The quest tracker as tools/r48_hud models it.
local function tracker(window, box)
	local hud, gui = window.real_hud_scaling, window.real_gui_scaling
	local W, H = window.size.x, window.size.y
	local lines = math.min(10, math.floor((H / 2 - (box.center_y + box.size / 2)) / (10 * gui)))
	local w = layout.side_text_width(window) * 9 * gui
	return rect(W - 20 * hud - w, H / 2 - lines * 10 * gui, w, lines * 20 * gui)
end
do
	local v = V.new({quality = "normal", width = 1080, height = 960, tiles = {}},
		{min_x = -3500, max_x = 3500, min_z = -3111, max_z = 3111})
	local D = dofile(repo .. "/mods/CORE/grug_ambience/data.lua")
	local WINDOWS = {
		{1280, 720, 1, 1}, {1920, 1080, 1, 1}, {1280, 720, 1, 2}, {1920, 1080, 1, 2},
		{1280, 720, 2, 2}, {1920, 1080, 2, 2}, {1366, 768, 1, 1}, {1024, 600, 1, 1},
	}
	for _, w in ipairs(WINDOWS) do
		local window = {size = {x = w[1], y = w[2]}, real_hud_scaling = w[3],
			real_gui_scaling = w[4]}
		local label = ("%dx%d hud %g gui %g"):format(w[1], w[2], w[3], w[4])
		local box = layout.minimap_box(window)
		local frame = V.frame(v, box)
		local quest = tracker(window, box)
		local gap = S.gap * box.hud
		local function stack_checks(L, mode)
			local a, m = L.announce, L.mail
			-- the client's drawn size at minimap.lua's exact() scale
			local scale = (a.w + 0.25) / (S.announce_w * box.hud)
			local mscale = (m.w + 0.25) / (S.mail_w * box.hud)
			check(a and math.floor(S.announce_w * scale * box.hud) == a.w and
				math.floor(S.announce_h * scale * box.hud) == a.h and scale == mscale,
				("L %s %s: drawn %dx%d at the mail icon's scale"):format(label, mode, a.w, a.h))
			check(a.x == m.x and math.abs(a.y - (m.y + m.h) - gap) <= 1,
				("L %s %s: under the mail icon, left-aligned, %d px below"):format(label, mode,
					a.y - (m.y + m.h)))
			local ar = rect(a.x, a.y, a.w, a.h)
			check(not overlap(ar, rect(m.x, m.y, m.w, m.h)) and
				not overlap(ar, rect(L.band.x, L.band.y, L.band.w, L.band.h)) and
				not overlap(ar, quest) and a.x >= 0,
				"L " .. label .. " " .. mode .. ": apart from the mail icon, the band and the tracker")
			return ar
		end
		local L = V.side_layout(box, frame)
		local H = V.side_layout(box, nil)
		local bx, by = box.center_x - box.size / 2, box.center_y - box.size / 2
		local left = frame.center_x - frame.diameter / 2
		for _, M in ipairs({{L = L, mode = "shown"}, {L = H, mode = "hidden"}}) do
			local ar = stack_checks(M.L, M.mode)
			-- Follow-up 1 (the user, 2026-11-21): with no unread letter the
			-- icon moves up into the mail icon's place.
			local m, band = M.L.mail, M.L.band
			local top = V.side_stack(M.L, 0, 2)
			local tr = rect(top.x, top.y, top.w, top.h)
			check(V.side_stack(M.L, 3, 2) == M.L.announce and top == M.L.announce_top and
				top.x == m.x and top.y == m.y and top.w == ar.w and top.h == ar.h and
				not overlap(tr, rect(band.x, band.y, band.w, band.h)) and not overlap(tr, quest),
				"L " .. label .. " " .. M.mode .. ": announcements only, in the mail icon's place")
			if M.mode == "shown" then
				check(ar.x + ar.w <= left and ar.y + ar.h <= frame.center_y + frame.diameter / 2 and
					tr.x + tr.w <= left and select(2, V.side_stack(L, 3, 2)) == nil,
					"L " .. label .. " shown: left of the bezel, within its height")
			end
			M.lowest = {letters = m.y + m.h, announcements = tr.y + tr.h, both = ar.y + ar.h}
			M.icons = {letters = {3, 0}, announcements = {0, 2}, both = {3, 2}}
			if M.mode == "hidden" then
				local inside, below, deepest = true, true, 0
				for case, counts in pairs(M.icons) do
					local _, ptop = V.side_stack(H, counts[1], counts[2])
					for _, track in pairs(D.tracks) do
						local g = V.now_playing_corner(box, H.playing_right, ptop, track.title,
							track.artist)
						local playing = rect(g.x, g.y, g.w, g.h)
						for _, r in ipairs({ar, tr, playing}) do
							inside = inside and r.y >= by - 0.5 and r.y + r.h <= by + box.size + 0.5 and
								r.x + r.w <= bx + box.size + 0.5 and r.x >= 0 and not overlap(r, quest)
						end
						local bottom = M.lowest[case]
						below = below and playing.y >= bottom + gap - 1 and
							playing.y <= bottom + gap + 2 * box.hud and
							(case ~= "both" or not overlap(ar, playing)) and not overlap(tr, playing) and
							math.abs(playing.x + playing.w - (bx + box.size)) <= 0.5
						deepest = math.max(deepest, playing.y + playing.h - by)
					end
				end
				check(inside, ("L %s hidden: the icons and Now playing inside the box (%d of %d px)"):
					format(label, deepest, box.size))
				check(below, "L " .. label .. " hidden: Now playing right-aligned just below " ..
					"the icons that show (one or two)")
			end
		end
		if w[1] == 1920 and w[3] == 1 and w[4] == 1 then
			print(("L 1080p: announcements %dx%d, %d px under the mail icon; hidden Now playing top %d (one icon) / %d (two)"):
				format(H.announce.w, H.announce.h, H.announce.y - (H.mail.y + H.mail.h), H.playing_top,
					H.playing_top_two))
		end
	end
end

-- ---------------------------------------------------------------------------
-- C  the counts apart (grug_mail model.lua)
-- ---------------------------------------------------------------------------
do
	local M = dofile(repo .. "/mods/PLAYER/grug_mail/model.lua")
	local NOW, DAY = 1800000000, 86400
	local box = {letters = {
		{id = 1, read = false, time = NOW - DAY},
		{id = 2, read = true, time = NOW - DAY},
		{id = 3, read = false, time = NOW - 31 * DAY}, -- expired
		{id = 4, read = false, time = NOW},
	}}
	local broadcasts = {{id = 7, time = NOW - DAY}, {id = 8, time = NOW}, {id = 9, time = NOW - 40 * DAY}}
	check(M.unread_letters(box, NOW) == 2, "C two unread letters (read and expired ones not)")
	check(M.unread_broadcasts(broadcasts, {[8] = true}, NOW) == 1, "C one unread broadcast")
	check(M.unread(box, broadcasts, {[8] = true}, NOW) == 3, "C together as before")
	check(M.unread_letters({letters = {}}, NOW) == 0, "C an empty box")
end

-- ---------------------------------------------------------------------------
-- F  the images and their rows
-- ---------------------------------------------------------------------------
do
	local function decode(path)
		local png = read(path)
		if not png or png:sub(13, 16) ~= "IHDR" then return nil end
		local function be(i)
			return ((png:byte(i) * 256 + png:byte(i + 1)) * 256 + png:byte(i + 2)) * 256 +
				png:byte(i + 3)
		end
		return be(17), be(21)
	end
	local TEX = "/mods/PLAYER/grug_map/textures/"
	local rows = read("/mods/PLAYER/grug_map/LICENSE-media.md") or ""
	local bad, unlisted = {}, {}
	for n = 1, 10 do
		local name = V.announce_texture(n)
		local w, h = decode(TEX .. name)
		if w ~= S.announce_w or h ~= S.announce_h then bad[#bad + 1] = name end
		if not rows:find("| `textures/" .. name .. "` |", 1, true) then unlisted[#unlisted + 1] = name end
	end
	check(#bad == 0, "F ten images at 87 x 29: " .. table.concat(bad, " "))
	check(#unlisted == 0, "F a LICENSE-media row each: " .. table.concat(unlisted, " "))
	check(S.announce_w == S.mail_w, "F as wide as the mail icon (the counts line up)")
	local bw, bh = decode("/mods/PLAYER/grug_mail/textures/grug_mail_admin_badge.png")
	check(bw == 32 and bh == 32, "F the announcement badge the images are built from")
	local gen = read("/tools/r48_hud/gen_hud_textures.py") or ""
	check(gen:find("grug_mail_admin_badge.png", 1, true) and
		gen:find('"grug_map_announce_*.png"', 1, true), "F the generator builds and owns them")
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	error(("R84 MAP PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R84 MAP PORTABLE PASS checks=" .. checks)
