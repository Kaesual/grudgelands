-- Round 74 lane HUD: portable fixture for the action clock's cover and the
-- waiting cast's marker on the hotbar (round74-plan.md §4 HUD; classes.md
-- "The cooldown overlay"). tools/run_fixtures.sh picks it up.
--
--   A  the arithmetic: the clock cover's steps and textures (every
--      FRAMES / CLOCK_FRAMES-th cooldown frame), the marker
--   B  the overlay (the real cooldown_hud.lua) with a stand-in warrior and
--      fake clocks: a swing covers the free cast skills at the next pass,
--      never a swing skill and never a number; it clears in CLOCK_FRAMES
--      steps; a running cooldown keeps its own cover and number; a cast
--      interval longer than the clock covers its own slot longer; a
--      cleared clock clears the cover; the elements stay in place through
--      a held fight (textures change, nothing is added again) and go
--      LINGER seconds after the last block; the waiting cast's marker
--      over the cover and alone, gone when the wait ends
--   C  the seams in the real init.lua and input.lua (source checks; the
--      accessor's behaviour is tools/r74_cast section W)
--   N  HUD writes per second per player in a held melee fight, 8 skill
--      slots: today (no cover) and with the cover at 2, 3, 4, 6 and 8
--      steps, for the dagger, the sword and the two-hander (printed)
--
--   luajit tools/r74_hud/portable_test.lua <repo>

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
local floor = math.floor

------------------------------------------------------------------------------
-- A: arithmetic
------------------------------------------------------------------------------
eq(M.CLOCK_FRAMES, 4, "A four clock steps")
eq(M.FRAMES % M.CLOCK_FRAMES, 0, "A the clock steps are whole cooldown frames")
for _, d in ipairs({0.7, 1, 1.4}) do
	eq(M.clock_frame(0, d), 0, "A step 0 at the start of " .. d .. " s")
	eq(M.clock_frame(d * 0.26, d), 1, "A step 1 after a quarter of " .. d .. " s")
	eq(M.clock_frame(d * 0.5, d), 2, "A step 2 half way through " .. d .. " s")
	eq(M.clock_frame(d * 0.99, d), 3, "A the last step just before the end of " .. d .. " s")
	eq(M.clock_frame(d * 3, d), 3, "A clamped after the end")
end
eq(M.clock_frame(1, 0), 3, "A a zero duration shows the last step")
eq(M.clock_texture(0), "grug_abilities_cd_pie_00.png", "A step 0: frame 0, the cooldown's look")
eq(M.clock_texture(1), "grug_abilities_cd_pie_18.png", "A step 1: frame 18")
eq(M.clock_texture(3), "grug_abilities_cd_pie_54.png", "A step 3: frame 54")
check(M.CLOCK_OPACITY == 255, "A the clock cover looks like the cooldown's (user, 2026-11-10)")
do
	local alone = M.marker_texture("")
	check(alone:find("^%[fill:96x96:#00000000%^") ~= nil, "A the marker alone starts on a clear square")
	local over = M.marker_texture(M.clock_texture(2))
	check(over:find(M.clock_texture(2), 1, true) == 1, "A the marker is drawn over the cover")
	-- Every fill stays inside the PIE_PX square and the four make one frame.
	local px, area = 0, 0
	for w, h, x, y in over:gmatch("%[fill:(%d+)x(%d+):(%d+),(%d+):") do
		w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)
		check(x + w <= M.PIE_PX and y + h <= M.PIE_PX, "A a marker fill inside the square")
		px, area = px + 1, area + w * h
	end
	eq(px, 4, "A four edges")
	local inner = M.PIE_PX - 2 * M.MARKER_PX
	eq(area, M.PIE_PX * M.PIE_PX - inner * inner, "A the edges cover the frame exactly once")
end

------------------------------------------------------------------------------
-- The stand-in engine and player (tools/r40_cd's)
------------------------------------------------------------------------------
local now_us = 0
local step_fn
core = {
	get_us_time = function() return now_us end,
	get_player_window_information = function()
		return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	end,
	register_globalstep = function(fn) step_fn = fn end,
	register_on_player_inventory_action = function() end,
	register_on_leaveplayer = function() end,
}
-- The warrior's bar: three swing skills, five casts.
local BAR = {"strike", "mighty_blow", "hamstring", "charge", "taunt", "bellow",
	"ruination", "hold_ground"}
local CAST = {charge = true, taunt = true, bellow = true, ruination = true, hold_ground = true}
-- The fake clocks (init.lua's cast_clock and cast_intervals) and the wait.
local clock = {cast = 0, interval = {}, waiting = nil}
local H = dofile(MODDIR .. "cooldown_hud.lua")({
	math = M,
	ability_of = function(name)
		local id = name:match("^grug_abilities:(.+)$")
		if not id then return nil end
		return id, CAST[id] == true
	end,
	cast_block = function(_, key)
		local u = clock.cast
		local i = clock.interval[key]
		if i and i > u then u = i end
		return u
	end,
	waiting = function() return clock.waiting end,
})

local function new_player(name)
	local p = {name = name, main = {}, huds = {}, next_id = 0,
		writes = {add = 0, change = 0, remove = 0}}
	for i = 1, 32 do p.main[i] = "" end
	for i, id in ipairs(BAR) do p.main[i] = "grug_abilities:" .. id end
	p.main[9] = "default:torch"
	local inv = {
		get_size = function(_, list) return list == "main" and 32 or 0 end,
		get_stack = function(_, list, i)
			local item = list == "main" and p.main[i] or ""
			return {get_name = function() return item end}
		end,
	}
	function p:get_player_name() return self.name end
	function p:get_inventory() return inv end
	function p:hud_get_hotbar_itemcount() return 8 end
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
local LAYOUT = M.layout(core.get_player_window_information(), 8)
-- slot -> {pie = cover texture, num = number texture, n = elements} by offset
local function view(p)
	local out, n = {}, 0
	for slot = 1, 8 do out[slot] = {pie = nil, num = nil} end
	for _, def in pairs(p.huds) do
		n = n + 1
		for slot, L in ipairs(LAYOUT.slots) do
			if def.z_index == H.Z_COVER and def.offset.x == L.cover.x and def.offset.y == L.cover.y then
				out[slot].pie = def.text
			elseif def.z_index == H.Z_NUMBER and def.offset.x == L.centre.x and def.offset.y == L.centre.y then
				out[slot].num = def.text
			end
		end
	end
	return out, n
end
local function at(s) now_us = floor(s * 1e6 + 0.5) end
local function pass(p) return H.update(p, now_us) end
local SLOT = {}
for i, id in ipairs(BAR) do SLOT[id] = i end

------------------------------------------------------------------------------
-- B: the overlay
------------------------------------------------------------------------------
do
	local p = new_player("b")
	at(100)
	-- A swing at 100 s with a 1 s weapon: casts held back until 101 s.
	clock.cast = now_us + 1e6
	H.block(p, clock.cast)
	eq(H.active_count(), 1, "B a block brings the player into the pass")
	eq(writes(p), 0, "B ...and is only recorded (the pass draws)")
	at(100.05) pass(p)
	local v, n = view(p)
	for _, id in ipairs(BAR) do
		if CAST[id] then
			eq(v[SLOT[id]].pie, M.clock_texture(0), "B the free cast " .. id .. " is covered, step 0")
			eq(v[SLOT[id]].num, "", "B ...without a number (" .. id .. ")")
		else
			eq(v[SLOT[id]].pie, nil, "B the swing skill " .. id .. " shows nothing")
		end
	end
	eq(n, 10, "B five covered slots, two elements each")
	-- Clearing: started at the swing (100 s), not at the first pass.
	at(100.26) pass(p)
	eq(view(p)[SLOT.taunt].pie, M.clock_texture(1), "B a quarter in: step 1")
	local w0 = writes(p)
	at(100.36) pass(p)
	eq(writes(p), w0, "B the same step: no write")
	at(100.76) pass(p)
	eq(view(p)[SLOT.taunt].pie, M.clock_texture(3), "B three quarters in: step 3")
	-- A cooldown takes precedence (Charge cast: 10 s).
	H.track(p, "charge", {expiry = now_us + 10e6, duration = 10})
	v = view(p)
	eq(v[SLOT.charge].pie, M.pie_texture(0), "B a running cooldown keeps its dark cover")
	eq(v[SLOT.charge].num, M.digit_texture("10"), "B ...and its number")
	eq(v[SLOT.taunt].pie, M.clock_texture(3), "B the others keep the clock's cover")
	-- The clock runs out: blanked in place (a held fight swings again soon).
	at(101.05) pass(p)
	v, n = view(p)
	eq(v[SLOT.taunt].pie, "", "B the clock ran out: the cover is blank")
	eq(n, 10, "B ...but the elements stay")
	eq(v[SLOT.charge].num, M.digit_texture("10"), "B the cooldown runs on")
	-- The next swing: textures change, nothing is added.
	local adds = p.writes.add
	clock.cast = now_us + 1e6
	H.block(p, clock.cast)
	at(101.1) pass(p)
	eq(view(p)[SLOT.taunt].pie, M.clock_texture(0), "B the next swing covers again")
	eq(p.writes.add, adds, "B ...in the same elements")
	-- A cast interval longer than the clock (a Fiery Spark-like key).
	clock.interval.bellow = now_us + 4e6
	H.block(p, clock.interval.bellow)
	at(101.6) pass(p)
	at(102.2) pass(p)
	v = view(p)
	eq(v[SLOT.taunt].pie, "", "B the clock ran out on Taunt")
	eq(v[SLOT.bellow].pie, M.clock_texture(1), "B Bellow's own interval still covers it")
	-- The clock cleared (death, respawn): gone at the next pass.
	clock.cast, clock.interval = now_us + 1e6, {}
	H.block(p, clock.cast)
	at(102.3) pass(p)
	check(view(p)[SLOT.taunt].pie ~= "", "B covered again")
	clock.cast = 0
	at(102.4) pass(p)
	eq(view(p)[SLOT.taunt].pie, "", "B a cleared clock clears the cover")
	-- The waiting cast: the marker over the cover, then alone.
	clock.cast = now_us + 1e6
	H.block(p, clock.cast)
	clock.waiting = "ruination"
	at(102.5) pass(p)
	eq(view(p)[SLOT.ruination].pie, M.marker_texture(M.clock_texture(0)),
		"B the waiting cast: its marker over the clock's cover")
	eq(view(p)[SLOT.taunt].pie, M.clock_texture(0), "B ...on its slot only")
	at(103.5) pass(p)
	eq(view(p)[SLOT.ruination].pie, M.marker_texture(""), "B the clock ran out, still waiting: the marker alone")
	clock.waiting = nil
	at(103.6) pass(p)
	eq(view(p)[SLOT.ruination].pie, "", "B the wait ended: the marker is gone")
	-- LINGER after the last block (Bellow's interval, until 105.1): every
	-- clock element goes; the cooldown (Charge, until 110.76) keeps its pair.
	at(105.1 + H.LINGER - 0.1) pass(p)
	_, n = view(p)
	eq(n, 10, "B just before LINGER is over the elements stay")
	at(105.1 + H.LINGER + 0.1) pass(p)
	v, n = view(p)
	eq(n, 2, "B LINGER after the last block only the cooldown's pair is left")
	eq(v[SLOT.charge].num ~= nil and v[SLOT.charge].num ~= "", true, "B ...with its number")
	at(111) pass(p)
	_, n = view(p)
	eq(n, 0, "B every timer and block over: no element left")
	eq(H.active_count(), 0, "B the player left the pass")
	eq(p.writes.add, p.writes.remove, "B every added element was removed")
	-- A wait keeps the player in the pass without a block or a timer.
	clock.waiting = "hold_ground"
	clock.cast = now_us + 0.3e6
	H.block(p, clock.cast)
	at(111 + 0.3 + H.LINGER + 1) pass(p)
	eq(view(p)[SLOT.hold_ground].pie, M.marker_texture(""), "B a long wait keeps its marker")
	eq(H.active_count(), 1, "B ...and the player in the pass")
	clock.waiting = nil
	pass(p)
	eq(H.active_count(), 0, "B the wait over: out of the pass")
	-- A block that has already ended records nothing.
	H.block(p, now_us)
	eq(H.active_count(), 0, "B an ended block is not tracked")
	-- Through the globalstep: a block shows within one pass of 0.1 s.
	clock.cast = now_us + 1e6
	H.block(p, clock.cast)
	step_fn(0.1)
	eq(view(p)[SLOT.taunt].pie, M.clock_texture(0), "B the globalstep's pass draws the block")
	H.forget("b")
	clock.cast = 0
end

------------------------------------------------------------------------------
-- C: the seams
------------------------------------------------------------------------------
do
	local function read(path)
		local f = assert(io.open(path))
		local s = f:read("*a")
		f:close()
		return s
	end
	local init = read(MODDIR .. "init.lua")
	check(init:find("cast_clock%[name%] = math%.max%(cast_clock%[name%] or 0,\n" ..
		"\t\tcore%.get_us_time%(%) %+ %(seconds %- late%) %* 1e6%)\n" ..
		"\tcooldown_hud%.block%(player, cast_clock%[name%]%)") ~= nil,
		"C occupy_casts reports the block (every swing and cast)")
	check(init:find("cast_intervals%[name%]%[def%.cooldown_key%] = now %+ %(seconds %- late%) %* 1e6\n" ..
		"\tcooldown_hud%.block%(player, cast_intervals%[name%]%[def%.cooldown_key%]%)") ~= nil,
		"C arm_cast_interval reports the block")
	check(init:find('return def.cooldown_key, def.kind == "cast"', 1, true) ~= nil,
		"C ability_of names the casts")
	check(init:find("cast_block = function(player, key)", 1, true) ~= nil,
		"C the read-only clock seam")
	check(init:find("grug_abilities.input.waiting(player)", 1, true) ~= nil,
		"C the waiting seam reads input.lua's accessor")
	local input = read(MODDIR .. "input.lua")
	check(input:find("function M.waiting(player)", 1, true) ~= nil, "C input.lua's accessor")
end

------------------------------------------------------------------------------
-- N: HUD writes in a held melee fight (numbers, printed)
------------------------------------------------------------------------------
-- One player, the warrior's bar above, Strike held on a mob for 60 s:
-- swings on the swing clock at 0.09 s engine steps (init.lua attempt_swing:
-- the carried lateness, at most 0.1 s and half the interval), each swing
-- holding casts back until the next swing is due; Charge cast every 12 s
-- (its 10 s cooldown) and Hamstring proccing every 10 s (its 8 s charge),
-- as today's running timers. The overlay runs through its own globalstep.
local function fight(weapon, frames, cover)
	M.CLOCK_FRAMES = frames
	local p = new_player("n")
	clock.cast, clock.interval, clock.waiting = 0, {}, nil
	now_us = 1000e6
	local next_due, acc, t0 = 0, 0, now_us
	local start_writes, last_charge, last_ham
	local seconds, warm = 60, 2
	while now_us - t0 < (seconds + warm) * 1e6 do
		now_us = now_us + 90000
		if now_us >= next_due then
			local late = 0
			if next_due > 0 then
				late = math.min((now_us - next_due) / 1e6, 0.1, weapon * 0.5)
			end
			next_due = now_us + (weapon - late) * 1e6
			-- Today: no clock seam and no report (the overlay of 0.73.1).
			if cover then
				if next_due > clock.cast then clock.cast = next_due end
				H.block(p, clock.cast)
			end
		end
		if not last_charge or now_us - last_charge >= 12e6 then
			last_charge = now_us
			H.track(p, "charge", {expiry = now_us + 10e6, duration = 10})
		end
		if not last_ham or now_us - last_ham >= 10e6 then
			last_ham = now_us
			H.track(p, "hamstring", {expiry = now_us + 8e6, duration = 8})
		end
		step_fn(0.09)
		if not start_writes and now_us - t0 >= warm * 1e6 then start_writes = writes(p) end
	end
	local total = writes(p) - start_writes
	local _, elements = view(p)
	H.forget("n")
	M.CLOCK_FRAMES = 4
	return total / seconds, elements
end
do
	local rows = {}
	for _, weapon in ipairs({0.7, 1.0, 1.4}) do
		local today = fight(weapon, 4, false)
		local line = ("N weapon %.1f s: today %.1f writes/s"):format(weapon, today)
		for _, frames in ipairs({2, 3, 4, 6, 8}) do
			local w, el = fight(weapon, frames, true)
			line = line .. ("; %d steps %.1f"):format(frames, w)
			if frames == 4 then rows[#rows + 1] = {weapon = weapon, today = today, four = w, el = el} end
		end
		print(line)
	end
	for _, r in ipairs(rows) do
		-- Four free casts plus Charge between its cooldowns, a step each per
		-- swing: well above today, bounded by the 0.1 s pass.
		check(r.four > r.today, "N the cover adds writes at " .. r.weapon .. " s")
		check(r.four < r.today + 10 * 5 * 1.1, "N ...at most a pass per slot at " .. r.weapon .. " s")
		eq(r.el, 12, "N the elements stay in place in the fight (the six slots that show anything)")
	end
end

if failures > 0 then
	error(("R74 HUD PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R74 HUD PORTABLE PASS %d checks"):format(checks))
