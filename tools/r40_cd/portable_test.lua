-- Round 40 lane CD: portable fixture for the cooldown overlay
-- (grug_abilities/cooldown_math.lua and cooldown_hud.lua; plan §2.1, §2.9,
-- §2.13). tools/run_fixtures.sh picks it up.
--
--   A  the number (§2.1) and the frame (72, fixed by the angle step)
--   B  the textures: every glyph a number can need exists, sizes match the
--      constants (tools/r40_cd/gen_cooldown_textures.py)
--   C  the slot geometry against an emulation of the engine's own pixel
--      arithmetic (hud.cpp): cover and number land on every slot at several
--      scalings, item counts and the two-row split
--   D  the overlay with a stand-in player: shown at once, writes only on a
--      visible change, slots tracked when a skill moves, leaves the hotbar
--      or comes back, the item count and the window change, expiry and an
--      early end, charges alike
--   E  the pass: only active players, spread over passes, ~0.1 s cadence
--   F  the wear bar is gone from grug_abilities (no second display path)
--
--   luajit tools/r40_cd/portable_test.lua <repo>

local repo = arg[1] or "."
local MODDIR = repo .. "/mods/PLAYER/grug_abilities/"

local failures, checks = 0, 0
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. msg)
	end
	return ok
end
local function eq(a, b, msg)
	return check(a == b, ("%s (got %s, want %s)"):format(msg, tostring(a), tostring(b)))
end

local M = dofile(MODDIR .. "cooldown_math.lua")
local floor, trunc = math.floor, M.trunc

------------------------------------------------------------------------------
-- A: number and frame
------------------------------------------------------------------------------
for _, c in ipairs({
	{300, "5m"}, {241, "5m"}, {240.5, "5m"}, {240, "4m"}, {121, "3m"},
	{120, "2m"}, {61, "2m"}, {60.5, "2m"}, {60, "60"}, {59.2, "60"},
	{10, "10"}, {9.99, "10"}, {1, "1"}, {0.01, "1"}, {0, ""}, {-1, ""},
}) do
	eq(M.text(c[1]), c[2], "A text(" .. c[1] .. ")")
end
eq(M.FRAMES, 72, "A 72 frames (5 degree steps)")
for _, d in ipairs({2, 6, 10, 300}) do
	eq(M.frame(0, d), 0, "A frame 0 at the start of " .. d .. " s")
	eq(M.frame(d / 2, d), 36, "A half way is frame 36 for " .. d .. " s")
	eq(M.frame(d * 0.9999, d), 71, "A the last frame just before the end of " .. d .. " s")
	eq(M.frame(d * 2, d), 71, "A clamped after the end of " .. d .. " s")
end
eq(M.frame(1, 0), 71, "A a zero duration shows the last frame")
eq(M.pie_texture(7), "grug_abilities_cd_pie_07.png", "A pie texture name")

------------------------------------------------------------------------------
-- B: textures
------------------------------------------------------------------------------
local function png_size(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local head = f:read(24)
	f:close()
	local function u32(s, i)
		local a, b, c, d = s:byte(i, i + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(head, 17), u32(head, 21)
end
local TEX = MODDIR .. "textures/"
for k = 0, M.FRAMES - 1 do
	local w, h = png_size(TEX .. M.pie_texture(k))
	if not check(w == M.PIE_PX and h == M.PIE_PX, "B pie frame " .. k .. " is " ..
			M.PIE_PX .. " px square") then break end
end
check(png_size(TEX .. ("grug_abilities_cd_pie_%02d.png"):format(M.FRAMES)) == nil,
	"B no frame beyond the last")
local glyphs = {}
for s = 1, 300 do
	local text = M.text(s)
	for i = 1, #text do glyphs[text:sub(i, i)] = true end
end
local count = 0
for ch in pairs(glyphs) do
	count = count + 1
	local w, h = png_size(TEX .. M.DIGIT:format(ch))
	eq(w, M.GLYPH_W * M.GLYPH_CELL, "B glyph " .. ch .. " width")
	eq(h, M.GLYPH_H * M.GLYPH_CELL, "B glyph " .. ch .. " height")
end
eq(count, 11, "B the numbers 1..300 s need eleven glyphs (0-9, m)")
eq(M.digit_texture("45"), "[combine:52x36:0,0=grug_abilities_cd_digit_4.png:" ..
	"24,0=grug_abilities_cd_digit_5.png", "B a two-glyph number is one [combine")
eq(M.digit_texture("7"), "[combine:28x36:0,0=grug_abilities_cd_digit_7.png", "B one glyph")
eq(M.digit_texture(""), "", "B no number, no texture")

------------------------------------------------------------------------------
-- C: geometry against the engine's arithmetic
------------------------------------------------------------------------------
-- The engine's own placement of one image element at position {0.5, 1}
-- (hud.cpp:496-506), in window pixels: top left x, y and the drawn size.
local function engine_image(W, H, sf, offset, scale, align, img_w, img_h)
	local dw, dh = trunc(img_w * scale * sf), trunc(img_h * scale * sf)
	local px, py = floor(0.5 * W + 0.5), floor(H + 0.5)
	return px + trunc(offset.x * sf) + trunc((align - 1) * dw / 2),
		py + trunc(offset.y * sf) + trunc((align - 1) * dh / 2), dw, dh
end

local cases = {
	{W = 1920, H = 1080, hud = 1, gui = 1, n = 8},
	{W = 1920, H = 1080, hud = 1.5, gui = 1.5, n = 8},  -- density 1.5 (gui_scaling 1)
	{W = 1280, H = 720, hud = 1.3, gui = 1, n = 8},
	{W = 1366, H = 768, hud = 2, gui = 1, n = 8},
	{W = 1024, H = 600, hud = 0.75, gui = 0.75, n = 8},
	{W = 1600, H = 900, hud = 1, gui = 1, n = 10},
	{W = 1600, H = 900, hud = 1.25, gui = 1, n = 6},
	{W = 400, H = 700, hud = 1, gui = 1, n = 8},          -- two rows
	{W = 800, H = 600, hud = 2, gui = 1, n = 8},          -- two rows
	{W = 801, H = 601, hud = 1.7, gui = 1, n = 9},        -- two rows, odd sizes
}
for _, c in ipairs(cases) do
	local label = ("C %dx%d hud %g gui %g n %d"):format(c.W, c.H, c.hud, c.gui, c.n)
	local info = {size = {x = c.W, y = c.H}, real_hud_scaling = c.hud, real_gui_scaling = c.gui}
	local lay = M.layout(info, c.n)
	local g = M.engine_slots({width = c.W, height = c.H, density = c.gui,
		hud_scaling = c.hud / c.gui, count = c.n})
	eq(#lay.slots, c.n, label .. ": one placement per slot")
	local bad = 0
	for i, L in ipairs(lay.slots) do
		local s = g.slots[i]
		local x, y, w, h = engine_image(c.W, c.H, c.hud, L.cover, L.cover_scale, 1,
			M.PIE_PX, M.PIE_PX)
		if x ~= s.x or y ~= s.y or w ~= g.size or h ~= g.size then
			bad = bad + 1
			print(("  %s slot %d: cover %d,%d %dx%d, slot %d,%d %d"):format(label, i,
				x, y, w, h, s.x, s.y, g.size))
		end
		for _, text in ipairs({"1", "60", "5m"}) do
			local tw = ((#text - 1) * M.GLYPH_ADVANCE + M.GLYPH_W) * M.GLYPH_CELL
			local dx, dy, dw, dh = engine_image(c.W, c.H, c.hud, L.centre, L.digit_scale, 0,
				tw, M.GLYPH_H * M.GLYPH_CELL)
			local cells = (#text - 1) * M.GLYPH_ADVANCE + M.GLYPH_W
			if dh ~= M.GLYPH_H * L.cell or dw ~= cells * L.cell
					or math.abs(dx + dw / 2 - (s.x + g.size / 2)) > 1
					or math.abs(dy + dh / 2 - (s.y + g.size / 2)) > 1
					or dx < s.x or dx + dw > s.x + g.size then
				bad = bad + 1
				print(("  %s slot %d %q: number %d,%d %dx%d"):format(label, i, text, dx, dy, dw, dh))
			end
		end
	end
	eq(bad, 0, label .. ": cover and number exactly on every slot")
end
do
	local one = M.layout({size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}, 8)
	local two = M.layout({size = {x = 400, y = 700}, real_hud_scaling = 1, real_gui_scaling = 1}, 8)
	eq(one.rows, 1, "C a wide window: one row")
	eq(two.rows, 2, "C a window narrower than the bar: two rows")
	check(two.slots[1].cover.y < two.slots[5].cover.y, "C the first half is the upper row")
	eq(one.slots[1].cell, 2, "C a glyph cell is 2 px on a 48 px slot")
	local plain = M.layout(nil, 8)
	eq(plain.key, "plain 8", "C no window information: the plain layout")
	-- At scaling 1 the plain layout is the exact one.
	for i = 1, 8 do
		local x, y = engine_image(1920, 1080, 1, plain.slots[i].cover, plain.slots[i].cover_scale,
			1, M.PIE_PX, M.PIE_PX)
		local g = M.engine_slots({width = 1920, height = 1080, density = 1, hud_scaling = 1, count = 8})
		check(x == g.slots[i].x and y == g.slots[i].y, "C plain slot " .. i .. " exact at scaling 1")
	end
	check(one.key ~= M.layout({size = {x = 1920, y = 1080}, real_hud_scaling = 1.5,
		real_gui_scaling = 1}, 8).key, "C the key changes with the scaling")
	check(one.key ~= M.layout({size = {x = 1920, y = 1080}, real_hud_scaling = 1,
		real_gui_scaling = 1}, 10).key, "C the key changes with the item count")
end

------------------------------------------------------------------------------
-- D: the overlay with a stand-in player
------------------------------------------------------------------------------
local now_us = 0
local step_fn, inv_action, leave_fn
core = {
	get_us_time = function() return now_us end,
	get_player_window_information = function() return nil end,
	register_globalstep = function(fn) step_fn = fn end,
	register_on_player_inventory_action = function(fn) inv_action = fn end,
	register_on_leaveplayer = function(fn) leave_fn = fn end,
}
local H = dofile(MODDIR .. "cooldown_hud.lua")({
	math = M,
	ability_of = function(name) return name:match("^grug_abilities:(.+)$") end,
})

local WINDOW = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
local windows = {}
H.window_info = function(name) return windows[name] end

local function new_player(name)
	local p = {name = name, main = {}, itemcount = 8, huds = {}, next_id = 0,
		writes = {add = 0, change = 0, remove = 0}}
	for i = 1, 32 do p.main[i] = "" end
	windows[name] = WINDOW
	local inv = {
		get_size = function(_, list) return list == "main" and 32 or 0 end,
		get_stack = function(_, list, i)
			local item = list == "main" and p.main[i] or ""
			return {get_name = function() return item end}
		end,
	}
	function p:get_player_name() return self.name end
	function p:get_inventory() return inv end
	function p:hud_get_hotbar_itemcount() return self.itemcount end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		self.writes.add = self.writes.add + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, stat, value)
		self.writes.change = self.writes.change + 1
		assert(self.huds[id], "hud_change on a removed element")
		self.huds[id][stat] = value
	end
	function p:hud_remove(id)
		self.writes.remove = self.writes.remove + 1
		assert(self.huds[id], "hud_remove twice")
		self.huds[id] = nil
	end
	return p
end
local function writes(p) return p.writes.add + p.writes.change + p.writes.remove end
local function covers(p) -- slot -> {pie, num} by element offset
	local layout = M.layout(windows[p.name], math.min(p.itemcount, 32))
	local out, n = {}, 0
	for _, def in pairs(p.huds) do
		for slot, L in ipairs(layout.slots) do
			if def.z_index == H.Z_COVER and def.offset.x == L.cover.x and def.offset.y == L.cover.y then
				out[slot] = out[slot] or {}
				out[slot].pie = def
			elseif def.z_index == H.Z_NUMBER and def.offset.x == L.centre.x and def.offset.y == L.centre.y then
				out[slot] = out[slot] or {}
				out[slot].num = def
			end
		end
		n = n + 1
	end
	return out, n
end
local function at(s) now_us = floor(s * 1e6 + 0.5) end
local function pass(p) return H.update(p, now_us) end

do
	local p = new_player("p")
	p.main[3] = "grug_abilities:smite"
	p.main[5] = "grug_abilities:hamstring"
	p.main[12] = "default:torch"
	at(100)
	local rec = {expiry = now_us + 10e6, duration = 10}
	H.track(p, "smite", rec)
	local shown, n = covers(p)
	eq(n, 2, "D a cast shows two elements at once")
	check(shown[3] and shown[3].pie and shown[3].num, "D on the skill's slot (3)")
	eq(shown[3] and shown[3].pie.text, "grug_abilities_cd_pie_00.png", "D fully covered first")
	eq(shown[3] and shown[3].num.text, M.digit_texture("10"), "D the number 10")
	eq(H.active_count(), 1, "D the player is active")

	local w0 = writes(p)
	at(100.1) pass(p)
	eq(writes(p), w0, "D 0.1 s later: same frame, same number, no write")
	at(100.2) pass(p)
	eq(writes(p) - w0, 1, "D frame 1 at 0.2 s of 10: one write")
	at(100.2) pass(p)
	eq(writes(p) - w0, 1, "D a repeated pass writes nothing")
	at(101.05) pass(p)
	eq(covers(p)[3].num.text, M.digit_texture("9"), "D 8.95 s left shows 9")

	-- A charge (Hamstring) alike, on its own slot.
	H.track(p, "hamstring", {expiry = now_us + 6e6, duration = 6})
	shown = covers(p)
	check(shown[5] and shown[5].pie, "D a charge covers its slot too")
	eq(shown[5] and shown[5].num.text, M.digit_texture("6"), "D the charge's number")

	-- Move Smite from slot 3 to slot 6 (an inventory action).
	p.main[3], p.main[6] = "", "grug_abilities:smite"
	inv_action(p)
	pass(p)
	shown, n = covers(p)
	check(not shown[3], "D moved: nothing left on slot 3")
	check(shown[6] and shown[6].pie and shown[6].num, "D moved: shown on slot 6")
	eq(n, 4, "D two skills, four elements")

	-- Swap two running skills: elements stay, their content follows.
	p.main[5], p.main[6] = "grug_abilities:smite", "grug_abilities:hamstring"
	inv_action(p)
	local before = writes(p)
	pass(p)
	shown = covers(p)
	eq(shown[6] and shown[6].num.text, M.digit_texture("6"), "D swapped: slot 6 shows Hamstring's number")
	eq(shown[5] and shown[5].num.text, M.digit_texture("9"), "D swapped: slot 5 shows Smite's number")
	check(writes(p) - before <= 4, "D a swap rewrites at most the two frames and numbers")

	-- Into a bag (outside the hotbar): nothing shows (§2.9).
	p.main[5], p.main[20] = "", "grug_abilities:smite"
	inv_action(p)
	pass(p)
	shown, n = covers(p)
	check(not shown[5], "D a skill in the main inventory past the hotbar shows nothing")
	eq(n, 2, "D only Hamstring left on the bar")
	-- Back into the hotbar without an inventory action (a Lua move): the
	-- periodic check finds it within LAYOUT_EVERY passes.
	p.main[20], p.main[1] = "", "grug_abilities:smite"
	local found
	for k = 1, H.LAYOUT_EVERY do
		at(101.05 + k * 0.1) pass(p)
		if covers(p)[1] then found = k break end
	end
	check(found ~= nil, "D a Lua move into the hotbar is found by the periodic check")

	-- The hotbar item count changes: the elements are re-placed.
	p.itemcount = 10
	for k = 1, H.LAYOUT_EVERY do at(102 + k * 0.1) pass(p) end
	shown, n = covers(p)
	check(shown[1] and shown[1].pie, "D item count 10: Smite re-placed on slot 1 of 10")
	eq(n, 4, "D item count 10: still four elements")
	p.itemcount = 8

	-- A narrow window (two rows).
	windows.p = {size = {x = 400, y = 700}, real_hud_scaling = 1, real_gui_scaling = 1}
	for k = 1, H.LAYOUT_EVERY do at(103 + k * 0.1) pass(p) end
	shown = covers(p)
	check(shown[1] and shown[1].pie, "D two rows: re-placed on slot 1 of the upper row")
	windows.p = WINDOW

	-- An early end (clear_cooldown sets expiry to now).
	rec.expiry = now_us
	for k = 1, H.LAYOUT_EVERY do at(104 + k * 0.1) pass(p) end
	shown, n = covers(p)
	check(not shown[1], "D an ended cooldown is removed on the next pass")
	-- Hamstring runs out at 107.05.
	at(107.1) pass(p)
	shown, n = covers(p)
	eq(n, 0, "D every timer over: no element left")
	eq(H.active_count(), 0, "D the player left the active set")
	eq(p.writes.add, p.writes.remove, "D every added element was removed")
end

-- A whole 300 s cooldown, a pass every 0.1 s: writes only on a visible change.
do
	local p = new_player("long")
	p.main[2] = "grug_abilities:sprint"
	at(1000)
	H.track(p, "sprint", {expiry = now_us + 300e6, duration = 300})
	local changes, passes = 0, 0
	for k = 1, 3001 do
		at(1000 + k * 0.1)
		local w = p.writes.change
		pass(p)
		passes = passes + 1
		changes = changes + (p.writes.change - w)
	end
	-- 71 frame changes; numbers 5m 4m 3m 2m then 60 .. 1: 63 changes.
	eq(changes, 71 + 63, "D 300 s: one write per frame and per number change, nothing else")
	eq(p.writes.add, 2, "D 300 s: the two elements added once")
	eq(p.writes.remove, 2, "D 300 s: removed once at the end")
end

-- A leave drops the state.
do
	local p = new_player("gone")
	p.main[1] = "grug_abilities:blink"
	H.track(p, "blink", {expiry = now_us + 5e6, duration = 5})
	eq(H.active_count(), 1, "D active before the leave")
	leave_fn(p)
	eq(H.active_count(), 0, "D a leave drops the player")
	check(H.state("gone") == nil, "D and its state")
	H.track(p, "blink", {expiry = now_us + 5e6, duration = 0})
	eq(H.active_count(), 0, "D a zero duration is never tracked")
end

------------------------------------------------------------------------------
-- E: the pass
------------------------------------------------------------------------------
do
	local players = {}
	for i = 1, 30 do
		local p = new_player("e" .. i)
		p.main[1] = "grug_abilities:smite"
		players[i] = p
		H.track(p, "smite", {expiry = now_us + 60e6, duration = 60})
	end
	local visits = {}
	local real = H.update
	H.update = function(p, now)
		visits[p.name] = (visits[p.name] or 0) + 1
		return real(p, now)
	end
	step_fn(0.1)
	local n = 0
	for _ in pairs(visits) do n = n + 1 end
	eq(n, H.PLAYERS_PER_PASS, "E one pass visits at most PLAYERS_PER_PASS players")
	step_fn(0.1)
	n = 0
	for _ in pairs(visits) do n = n + 1 end
	eq(n, 30, "E the next pass reaches the rest: every player within two passes")
	-- Cadence: nine server steps of 0.09 s.
	visits = {}
	H.PLAYERS_PER_PASS = 100
	local passes = 0
	for _ = 1, 10 do
		local before = visits.e1 or 0
		step_fn(0.09)
		if (visits.e1 or 0) > before then passes = passes + 1 end
	end
	check(passes >= 8, "E 0.09 s server steps: about one pass per 0.1 s (" .. passes .. " in 0.9 s)")
	H.update = real
	for i = 1, 30 do leave_fn(players[i]) end
	eq(H.active_count(), 0, "E all gone")
	visits = {}
	step_fn(0.2)
	eq(next(visits), nil, "E no active player: the pass visits nobody")
end

------------------------------------------------------------------------------
-- F: the wear bar is gone
------------------------------------------------------------------------------
do
	local f = assert(io.open(MODDIR .. "init.lua"))
	local src = f:read("*a")
	f:close()
	for _, needle in ipairs({"set_item_wear", "WEAR_STEPS", "set_wear_bar_params",
			"charge_fraction", "representation_wear", "grug_charge_bar"}) do
		check(not src:find(needle, 1, true), "F init.lua no longer has " .. needle)
	end
	check(src:find("cooldowns%[name%]%[def%.id%] = rec\n\tcooldown_hud%.track%(player, def%.id, rec%)") ~= nil,
		"F arm_cooldown hands its record to the overlay")
	check(src:find("charges%[name%]%[def%.id%] = rec\n\tcooldown_hud%.track%(player, def%.id, rec%)") ~= nil,
		"F reset_charge hands its record to the overlay")
end

if failures > 0 then
	error(("R40 CD PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R40 CD PORTABLE PASS %d checks"):format(checks))
