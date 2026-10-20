-- The skill effects' look pass portable test (LuaJIT; the user's pick on
-- 2026-10-21 on the R52 particle page: "glowing and vivid" for every skill
-- effect, Smite as a small Final Word, faster Meteor and Censure falls).
--
--   luajit tools/r541_glow/portable_test.lua [repo]
--
--   H  the REAL grug_core/particles.lua on a fake engine: `mote` puts the
--      tint (and frame.color) on grug_core_mote.png, `blend = "add"` reaches
--      the texture table of a spawner and of single particles with and
--      without fade, a plain fade-less emitter keeps the bare texture string,
--      `after` defers the emitter through core.after with the same frame,
--      check() refuses a bad blend or after;
--   C  the REAL catalogue: every skill effect of tools/r52_pfx (each card's
--      id, evaluated with its sample frame) tints the mote and adds with glow
--      14, except the plain dust, earth, wood, smoke and mist colours and the
--      blood; every other registered effect (bosses, mobs, crits, the absorb
--      soak, the level-up, the area defaults; the user, 2026-10-21) tints the
--      mote too, its lights add with glow 14 and its dust, smoke, wind,
--      webs, leaves and splashes stay plain, while the material textures
--      (blood, rock, bubbles, opaque snow, the rift spawn's smoke, dust and wind)
--      keep their look; the
--      four readiness windows and the three arrow trails carry the vivid
--      tints;
--   F  meteor_fall and censure_fall over heights and delays: they start
--      late (after + life = the delay), fall at 14 and 12 m/s (slower only
--      when the delay is shorter than the fall), do not fade and land on the
--      anchor;
--   S  smite_hit is a small Final Word: a beam of single particles shooting
--      down and a ring, lower, fewer and narrower than Final Word's;
--   T  grug_core_mote.png ships as an 8 x 8 PNG with its licence entry.
-- Prints "R541 GLOW PORTABLE PASS checks=<n>" or the failures (exit 1).

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

------------------------------------------------------------------------------
-- The fake engine and the real helper and catalogue.
------------------------------------------------------------------------------
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
local ORIGIN = vector.new(0, 0, 0)

------------------------------------------------------------------------------
-- H: the helper's new fields.
------------------------------------------------------------------------------
do
	local function single(def)
		def.kind, def.n = "single", 1
		def.shape = def.shape or {"box", {0, 0, 0}, {0, 0, 0}}
		def.exp, def.size = def.exp or {0.5, 0.5}, {2, 2}
		return def
	end
	P.register("t541_mote_add", {single({color = "#123456", mote = true, blend = "add"})})
	P.register("t541_mote_still", {single({color = "#123456", mote = true, blend = "add", fade = false})})
	P.register("t541_smoke_still", {single({color = "#123456", fade = false})})
	P.register("t541_alpha_still", {single({color = "#123456", fade = false, blend = "alpha"})})
	P.register("t541_spawner", {{kind = "spawner", n = 4, time = 0.2, color = "#123456", mote = true,
		blend = "add", shape = {"box", {0, 0, 0}, {1, 1, 1}}, exp = {0.3, 0.3}, size = {2, 2}}})
	P.register("t541_after", {single({color = "#abcdef", mote = true, after = 0.5,
		shape = {"box", {1, 2, 0}, {1, 2, 0}}})})

	calls = {}
	P.play("t541_mote_add", {caster = ORIGIN})
	local t = calls[1] and calls[1].def.texture
	check(type(t) == "table", "H a faded add emitter's texture is a table")
	eq(t and t.name, "grug_core_mote.png^[multiply:#123456", "H mote: the tint goes on the white mote")
	eq(t and t.blend, "add", "H the blend reaches the single particle")
	check(t and t.alpha_tween and t.alpha_tween[1] == 1 and t.alpha_tween[2] == 0,
		"H the fade stays with the blend")
	calls = {}
	P.play("t541_mote_add", {caster = ORIGIN, color = "#fedcba"})
	t = calls[1] and calls[1].def.texture
	eq(t and t.name, "grug_core_mote.png^[multiply:#fedcba", "H frame.color tints the mote")

	calls = {}
	P.play("t541_mote_still", {caster = ORIGIN})
	t = calls[1] and calls[1].def.texture
	check(type(t) == "table" and t.blend == "add" and t.alpha_tween == nil,
		"H a fade-less add emitter: a table with the blend and no fade")
	calls = {}
	P.play("t541_smoke_still", {caster = ORIGIN})
	eq(calls[1] and calls[1].def.texture, "default_item_smoke.png^[multiply:#123456",
		"H a plain fade-less emitter keeps the bare smoke texture string")
	calls = {}
	P.play("t541_alpha_still", {caster = ORIGIN})
	eq(calls[1] and calls[1].def.texture, "default_item_smoke.png^[multiply:#123456",
		"H blend alpha is the default (bare string)")
	calls = {}
	P.play("t541_spawner", {caster = ORIGIN})
	t = calls[1] and calls[1].kind == "spawner" and calls[1].def.texture
	check(t and t.blend == "add" and t.name:find("grug_core_mote.png", 1, true) == 1,
		"H the blend and the mote reach a spawner")

	calls, timers = {}, {}
	local frame = {caster = vector.new(10, 0, 0)}
	P.play("t541_after", frame)
	eq(#calls, 0, "H after: nothing plays at once")
	eq(#timers, 1, "H after: one timer")
	near(timers[1] and timers[1].seconds, 0.5, "H after: the timer waits the emitter's after")
	if timers[1] then
		frame.caster = vector.new(99, 99, 99) -- a later change of the frame table's position
		timers[1].fn(unpack(timers[1].args))
	end
	local pos = calls[1] and calls[1].def.pos
	check(pos and pos.x == 11 and pos.y == 2, "H after: the deferred particle keeps the anchor of the cast")

	local bad = {
		{blend = "screen"}, {after = -0.1}, {after = 3.5}, {after = "soon"},
	}
	for _, extra in ipairs(bad) do
		local def = single({color = "#123456"})
		for k, v in pairs(extra) do def[k] = v end
		check(P.check({def}) ~= nil, "H check refuses " .. next(extra) .. " = " .. tostring(extra[next(extra)]))
	end
	for _, after in ipairs({0, 3}) do
		check(P.check({single({color = "#123456", after = after})}) == nil, "H check accepts after = " .. after)
	end
end

------------------------------------------------------------------------------
-- C: the catalogue.
------------------------------------------------------------------------------
local MATTE = {["#3a2a22"] = true, ["#8fd3ff"] = true, ["#b8a27a"] = true, ["#c8a878"] = true,
	["#b89a68"] = true, ["#5a4a9a"] = true}
do
	local cards = dofile(ROOT .. "/tools/r52_pfx/emitters.lua")
	local skill = {}
	for _, card in ipairs(cards) do
		if card.id ~= "" then
			skill[card.id] = skill[card.id] or card.sample
		end
	end
	local function list_of(id, sample)
		local effect = P.registered(id)
		return type(effect) == "function" and effect(sample or {}) or effect
	end
	local skill_n = 0
	for id, sample in pairs(skill) do
		skill_n = skill_n + 1
		for i, e in ipairs(list_of(id, sample) or {}) do
			local label = "C " .. id .. " emitter " .. i
			if e.tex and e.tex:find("^mobs_blood") then
				check(e.blend == nil and not e.mote, label .. ": blood keeps its look")
			elseif e.tex then
				check(e.blend == "add" and e.glow == 14, label .. ": the texture adds, glow 14")
			else
				check(e.mote == true, label .. ": the tint is on the mote")
				if MATTE[e.color] then
					check(e.blend == nil, label .. ": " .. e.color .. " stays plain")
				else
					check(e.blend == "add" and e.glow == 14, label .. ": " .. e.color .. " adds, glow 14")
				end
			end
		end
	end
	check(skill_n >= 50, "C the skill effects found (" .. skill_n .. ")")

	-- The other effects: which ones light up (at least one added emitter) and
	-- which stay plain throughout.
	local LIT = {}
	for _, id in ipairs({"crit", "absorb", "level_up", "area_fall", "area_impact", "king_cleave_windup",
			"king_cleave", "king_aura", "king_resolve", "elite_windup", "elite_cone", "breath_windup",
			"breath_burst_scorch", "breath_trail", "dragon_patch_scorch", "lightning_ring", "lightning_strike", "dive_windup", "dive_slam", "enrage",
			"dragon_return", "depth_windup", "depth_burst", "oerkki_blink", "wisp_blink", "hex_bottle"}) do
		LIT[id] = true
	end
	local MATERIAL = {"^mobs_blood", "^grug_mobs_rock%.png$", "^mobs_bubble", "#d8eef4", "^default_snow",
		"^mobs_tnt_smoke"}
	local function material(tex)
		for _, pattern in ipairs(MATERIAL) do
			if tex:find(pattern) then return true end
		end
		return false
	end
	local others = 0
	for id in read("mods/CORE/grug_core/particle_effects.lua"):gmatch('\nregister%("([%w_]+)"') do
		if not skill[id] then
			others = others + 1
			local adds = 0
			for i, e in ipairs(list_of(id) or {}) do
				local label = "C " .. id .. " emitter " .. i
				if e.tex then
					if material(e.tex) then
						check(e.blend == nil, label .. ": the material texture keeps its look")
					else
						check(e.blend == "add" and e.glow == 14, label .. ": the coloured light adds, glow 14")
					end
				else
					check(e.mote == true, label .. ": the tint is on the mote")
				end
				if e.blend == "add" then
					adds = adds + 1
					eq(e.glow, 14, label .. ": an added emitter glows 14")
				end
			end
			if LIT[id] then
				check(adds > 0, "C " .. id .. " lights up")
			else
				eq(adds, 0, "C " .. id .. " stays plain")
			end
		end
	end
	check(others >= 40, "C the other effects found (" .. others .. ")")

	local PROC = grug_core.PROC_COLORS
	eq(PROC.cold_shock, "#4cc3ff", "C Cold Shock's window: vivid frost")
	eq(PROC.retort, "#9cbce6", "C Retort's window: vivid steel")
	eq(PROC.clear_conscience, "#ffe680", "C Clear Conscience's window: vivid ivory")
	eq(PROC.follow_the_line, "#98e03a", "C Follow the Line's window: vivid green")
	local scout = read("mods/PLAYER/grug_abilities/scout.lua") or ""
	for shot, color in pairs({true_draw = "#ffe680", snare_shot = "#5cd03a", split_shot = "#98e03a"}) do
		check(scout:find(shot .. ' = {effect = "skill_arrow", color = "' .. color .. '"}', 1, true) ~= nil,
			"C the " .. shot .. " trail is " .. color)
	end
end

------------------------------------------------------------------------------
-- F: the faster falls.
------------------------------------------------------------------------------
do
	local SPEED = {meteor_fall = 14, censure_fall = 12}
	for id, speed in pairs(SPEED) do
		for _, life in ipairs({0.75, 1.5}) do
			for _, height in ipairs({1.5, 4, 6, 10, 12}) do
				local list = P.registered(id)({time = life, height = height, reach = 3})
				local label = ("F %s height %g delay %g: "):format(id, height, life)
				local fall = math.min(life, height / speed)
				local head = list[1]
				check(P.check(list) == nil, label .. "passes the budget check")
				near(head.after + head.exp[1], life, label .. "it lands with the delay")
				near(head.exp[1], fall, label .. "it falls for min(delay, height / speed)")
				near(-head.vel[1][2], height / fall, label .. "its vertical speed", 0.002)
				check(-head.vel[1][2] >= math.min(speed, height / life) - 0.002,
					label .. "never slower than " .. speed .. " m/s unless the delay is shorter")
				eq(head.fade, false, label .. "no fade")
				local p = head.shape[2]
				near(p[1] + head.vel[1][1] * head.exp[1], 0, label .. "lands on the anchor (x)", 0.01)
				near(p[2] + head.vel[1][2] * head.exp[1], 0, label .. "lands on the anchor (y)", 0.01)
			end
		end
	end
	-- The old falls spread over the whole delay: 6.7 and 8 m/s at the samples.
	local meteor = P.registered("meteor_fall")({time = 1.5, height = 10})
	check(-meteor[1].vel[1][2] > 2 * 10 / 1.5 - 0.01, "F Meteor at 10 m: more than twice as fast as before")
	local seal = P.registered("censure_fall")({time = 0.75, height = 6})
	check(-seal[1].vel[1][2] >= 1.5 * 6 / 0.75 - 0.01, "F Censure at 6 m: half again as fast as before")
end

------------------------------------------------------------------------------
-- S: Smite, a small Final Word.
------------------------------------------------------------------------------
do
	local smite, word = P.registered("smite_hit"), P.registered("final_word")
	local n = 0
	for _, e in ipairs(smite) do
		eq(e.kind, "single", "S Smite plays single particles (the basic attack)")
		n = n + e.n
	end
	eq(n, 13, "S Smite: 13 particles")
	local beam, ring = smite[1], smite[2]
	eq(beam.shape[1], "line", "S the beam is a line")
	check(beam.vel[1][2] < 0, "S the beam shoots down")
	check(beam.shape[2][2] < word[1].shape[2][2], "S the beam starts lower than Final Word's column")
	check(beam.shape[3][2] + beam.vel[1][2] * beam.exp[2] > -0.1, "S the beam stops at the ground")
	check(ring.shape[1] == "disc" and ring.shape[4] == true, "S the ring is an exact ring")
	check(ring.n < word[2].n, "S fewer ring motes than Final Word")
	check(ring.shape[3] + ring.radial[2] * ring.exp[2] < word[2].shape[3] + word[2].radial[1] * word[2].exp[1],
		"S the ring stays inside Final Word's")
	check(beam.n + ring.n < word[1].n + word[2].n, "S fewer particles than Final Word")
end

------------------------------------------------------------------------------
-- T: the mote texture and its licence entry.
------------------------------------------------------------------------------
do
	local data = read("mods/CORE/grug_core/textures/grug_core_mote.png")
	if check(data ~= nil, "T grug_core_mote.png ships") then
		local function u32(at)
			local a, b, c, d = data:byte(at, at + 3)
			return ((a * 256 + b) * 256 + c) * 256 + d
		end
		check(data:sub(2, 4) == "PNG" and u32(17) == 8 and u32(21) == 8, "T it is an 8 x 8 PNG")
	end
	local license = read("mods/CORE/grug_core/LICENSE-media.md") or ""
	check(license:find("`grug_core_mote.png`", 1, true) ~= nil, "T it has a licence entry")
end

if failures == 0 then
	print(("R541 GLOW PORTABLE PASS checks=%d"):format(checks))
else
	error(("R541 GLOW PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
