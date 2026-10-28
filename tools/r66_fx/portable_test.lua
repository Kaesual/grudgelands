-- Round 66 lane FX portable test (LuaJIT): the priest's symbols
-- (round66-plan.md §2 ruling 6 and the coordinator default "Symbols", §4 FX,
-- §6; the user's picks of 2026-10-28). Through the REAL
-- grug_core/particles.lua and particle_effects.lua on a fake engine:
--   H  Smite's hammer: one textured single particle (size 7) at the target,
--      straight down from 3.2 m, landing in 0.15 s with the face of its
--      head at the ring's height; no fade; then the gold ring of eight,
--      deferred by the fall; 9 particles (13 before, the five-mote beam
--      gone);
--   W  Final Word's hammer (size 12) falls from the column's 7 m in the
--      column spawner's 0.1 s and lands at the column's foot; the column
--      and the ring burst as before; 46 particles as before;
--   B  Censure's book (size 16) replaces the falling seal: same delay and
--      fall timing over heights and delays (r541_glow F checks the times),
--      straight down; the warning and the impact rings unchanged; 1 particle;
--   L  the textures reach the engine untinted (the bare file name, no
--      `^[multiply`), added (blend "add") with glow 14, without an alpha
--      tween; `color` and frame.color never reach a textured particle;
--   T  both textures ship as 64 x 64 RGBA PNGs with a LICENSE-media.md row;
--   D  the damage stays instant: Smite's and Final Word's casts play the
--      effect and deal the damage in the same call, with no timer.
-- The catalogue cards (tools/r52_pfx) are compared with the registry by
-- tools/r53_hooks (P) and tools/r52_pfx/check_limits.lua.
--
--   luajit tools/r66_fx/portable_test.lua [repo]
-- Prints "R66 FX PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label, tolerance)
	return check(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local f = io.open(ROOT .. "/" .. path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local calls, timers = {}, {}
core = {
	settings = {get = function() return nil end},
	log = function() end,
	yaw_to_dir = function() return {x = 1, y = 0, z = 0} end,
	add_particlespawner = function(def) calls[#calls + 1] = {kind = "spawner", def = def} end,
	add_particle = function(def) calls[#calls + 1] = {kind = "single", def = def} end,
	after = function(seconds, fn, ...) timers[#timers + 1] = {seconds = seconds, fn = fn, args = {...}} end,
}
vector = {
	new = function(x, y, z) return {x = x, y = y, z = z} end,
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end,
	multiply = function(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end,
	offset = function(a, x, y, z) return {x = a.x + x, y = a.y + y, z = a.z + z} end,
}
grug_core = {}
dofile(ROOT .. "/mods/CORE/grug_core/particles.lua")
dofile(ROOT .. "/mods/CORE/grug_core/particle_effects.lua")
local P = grug_core.particles

local HAMMER, BOOK = "grug_core_fx_hammer.png", "grug_core_fx_book.png"
-- The face of the hammer's head under the particle's centre, in metres per
-- size unit: the texture's lowest opaque row ends 26 of 64 pixels under the
-- middle (size 1 = 0.1 m), so 0.0406; the catalogue rounds it to 0.04.
local FACE = 0.04

local function total(list)
	local n = 0
	for _, e in ipairs(list) do n = n + e.n end
	return n
end

-- A falling symbol: one single particle with its texture, straight down.
local function symbol(e, tex, size, label)
	eq(e.kind, "single", label .. ": a single particle")
	eq(e.n, 1, label .. ": one particle")
	eq(e.tex, tex, label .. ": the texture")
	eq(e.color, nil, label .. ": no tint")
	check(e.mote == nil, label .. ": not on the mote")
	eq(e.at, "target", label .. ": at the target")
	eq(e.size[1], size, label .. ": size " .. size)
	eq(e.size[2], size, label .. ": one size")
	eq(e.fade, false, label .. ": no fade, it lands whole")
	eq(e.blend, "add", label .. ": added")
	eq(e.glow, 14, label .. ": glow 14")
	eq(e.exp[1], e.exp[2], label .. ": one lifetime")
	check(e.shape[1] == "box" and e.shape[2][1] == 0 and e.shape[2][3] == 0
		and e.shape[3][2] == e.shape[2][2], label .. ": one point over the target")
	check(e.vel[1][1] == 0 and e.vel[1][3] == 0 and e.vel[2][1] == 0 and e.vel[2][3] == 0
		and e.vel[1][2] == e.vel[2][2] and e.vel[1][2] < 0, label .. ": straight down")
end

------------------------------------------------------------------------------
-- H: Smite.
------------------------------------------------------------------------------
local smite = P.registered("smite_hit")
do
	eq(#smite, 2, "H Smite: the hammer and the ring")
	local hammer, ring = smite[1], smite[2]
	symbol(hammer, HAMMER, 7, "H Smite's hammer")
	near(hammer.shape[2][2], 3.2, "H it starts at the old beam's 3.2 m")
	near(hammer.exp[1], 0.15, "H it lands in 0.15 s")
	near(hammer.shape[2][2] + hammer.vel[1][2] * hammer.exp[1] - FACE * 7, ring.shape[2][2],
		"H the face of its head lands at the ring's height", 0.001)
	eq(ring.n, 8, "H the ring of eight")
	eq(ring.color, "#ffb800", "H the gold ring")
	check(ring.shape[1] == "disc" and ring.shape[4] == true and ring.shape[3] == 0.3,
		"H the exact ring at the feet as before")
	near(ring.after, hammer.exp[1], "H the ring springs out as the hammer lands")
	eq(total(smite), 9, "H Smite: 9 particles (13 before)")
	check(P.check(smite) == nil, "H Smite keeps the budget rules")
	for _, e in ipairs(smite) do
		eq(e.kind, "single", "H Smite plays single particles only (the basic attack)")
	end
end

------------------------------------------------------------------------------
-- W: Final Word.
------------------------------------------------------------------------------
do
	local word = P.registered("final_word")
	eq(#word, 3, "W Final Word: the column, the ring and the hammer")
	local column, ring, hammer = word[1], word[2], word[3]
	eq(column.kind, "spawner", "W the column is a spawner")
	check(column.shape[1] == "line" and column.shape[2][2] == 7 and column.shape[3][2] == 0.2,
		"W the column from 7 m to 0.2 m as before")
	eq(column.n, 25, "W the column gave one mote to the hammer (26 -> 25)")
	check(ring.kind == "spawner" and ring.n == 20 and ring.time == 0.05 and ring.after == nil,
		"W the ring bursts as before")
	symbol(hammer, HAMMER, 12, "W Final Word's hammer")
	near(hammer.shape[2][2], column.shape[2][2], "W it starts at the column's top")
	near(hammer.exp[1], column.time, "W it falls in the column's time")
	near(hammer.shape[2][2] + hammer.vel[1][2] * hammer.exp[1] - FACE * 12, column.shape[3][2],
		"W the face of its head lands at the column's foot", 0.001)
	eq(hammer.after, nil, "W it starts with the column")
	check(hammer.size[1] > smite[1].size[1], "W the large hammer, Smite's the small one")
	eq(total(word), 46, "W Final Word: 46 particles as before")
	check(P.check(word) == nil, "W Final Word keeps the budget rules")
end

------------------------------------------------------------------------------
-- B: Censure.
------------------------------------------------------------------------------
do
	for _, life in ipairs({0.75, 1.5}) do
		for _, height in ipairs({1.5, 6, 12}) do
			local list = P.registered("censure_fall")({time = life, height = height, reach = 3})
			local label = ("B the book at %g m, delay %g"):format(height, life)
			eq(#list, 1, label .. ": the one fall")
			symbol(list[1], BOOK, 16, label)
			local fall = math.min(life, height / 12)
			near(list[1].exp[1], fall, label .. ": the fall time as before")
			near(list[1].after, life - fall, label .. ": the late start as before")
			near(list[1].shape[2][2], height, label .. ": from the fall height")
		end
	end
	local warning = P.registered("censure_warning")({reach = 3, time = 0.75})
	check(#warning == 1 and warning[1].n == 20 and warning[1].color == "#ffb800",
		"B the gold warning ring unchanged")
	local impact = P.registered("censure_impact")
	check(#impact == 1 and impact[1].n == 32 and impact[1].color == "#ffb800"
		and impact[1].radial == "reach", "B the impact ring unchanged")
end

------------------------------------------------------------------------------
-- L: what reaches the engine.
------------------------------------------------------------------------------
do
	local TARGET = vector.new(10, 5, -3)
	local function texture_ok(def, tex, label)
		local t = def and def.texture
		check(type(t) == "table" and t.name == tex and t.blend == "add" and t.alpha_tween == nil,
			label .. ": the bare texture, added, no alpha tween")
		eq(def and def.glow, 14, label .. ": glow 14")
	end
	calls, timers = {}, {}
	P.play("smite_hit", {target = TARGET, color = "#123456"})
	eq(#calls, 1, "L Smite: the hammer at once")
	eq(#timers, 1, "L Smite: the ring through one timer")
	near(timers[1] and timers[1].seconds, 0.15, "L ... after the fall")
	local h = calls[1] and calls[1].def
	texture_ok(h, HAMMER, "L Smite's hammer (frame.color passed)")
	near(h and h.size, 7, "L size 7")
	near(h and h.pos.y, 5 + 3.2, "L from 3.2 m over the target")
	near(h and h.velocity.x, 0, "L straight down (x)")
	near(h and h.velocity.z, 0, "L straight down (z)")
	near(h and h.expirationtime, 0.15, "L it lives the fall")
	if timers[1] then
		timers[1].fn(unpack(timers[1].args))
	end
	eq(#calls, 9, "L Smite: the ring of eight after the fall")
	check(calls[2] and calls[2].def.texture.name:find("grug_core_mote.png", 1, true) == 1,
		"L the ring stays motes")

	calls, timers = {}, {}
	P.play("final_word", {target = TARGET})
	eq(#calls, 3, "L Final Word: two spawners and the hammer")
	eq(#timers, 0, "L Final Word: nothing deferred")
	local w = calls[3] and calls[3].kind == "single" and calls[3].def
	texture_ok(w, HAMMER, "L Final Word's hammer")
	near(w and w.size, 12, "L size 12")

	calls, timers = {}, {}
	P.play("censure_fall", {target = TARGET, time = 0.75, height = 6, color = "#123456"})
	eq(#timers, 1, "L Censure: the late book through one timer")
	if timers[1] then
		timers[1].fn(unpack(timers[1].args))
	end
	local b = calls[1] and calls[1].def
	texture_ok(b, BOOK, "L Censure's book (frame.color passed)")
	near(b and b.size, 16, "L size 16")
end

------------------------------------------------------------------------------
-- T: the textures and their licence rows.
------------------------------------------------------------------------------
do
	local license = read("mods/CORE/grug_core/LICENSE-media.md") or ""
	for _, name in ipairs({HAMMER, BOOK}) do
		local data = read("mods/CORE/grug_core/textures/" .. name)
		if check(data ~= nil, "T " .. name .. " ships") then
			local function u32(at)
				local a, b, c, d = data:byte(at, at + 3)
				return ((a * 256 + b) * 256 + c) * 256 + d
			end
			check(data:sub(2, 4) == "PNG" and u32(17) == 64 and u32(21) == 64,
				"T " .. name .. " is a 64 x 64 PNG")
			check(data:byte(25) == 8 and data:byte(26) == 6, "T " .. name .. " is 8-bit RGBA")
		end
		check(license:find("- `" .. name .. "`", 1, true) ~= nil, "T " .. name .. " has its licence row")
	end
	check(license:find("CC0-1.0", 1, true) ~= nil and license:find("GPT-6 Astra", 1, true) ~= nil,
		"T the rows name the author and the licence")
end

------------------------------------------------------------------------------
-- D: the damage stays instant.
------------------------------------------------------------------------------
do
	local kit = read("mods/PLAYER/grug_abilities/kits_priest.lua") or ""
	for _, case in ipairs({{"smite_hit", "smite"}, {"final_word", "final_word"}}) do
		local at = kit:find('fx("' .. case[1] .. '", {target = target:get_pos()})', 1, true)
		local after = at and kit:sub(at, at + 300)
		check(after and after:find("grug_core.deal_ability_damage", 1, true) ~= nil
			and not after:find("core.after", 1, true),
			"D " .. case[2] .. ": the effect and the damage in the same call")
	end
end

if failures == 0 then
	print(("R66 FX PORTABLE PASS checks=%d"):format(checks))
else
	error(("R66 FX PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
