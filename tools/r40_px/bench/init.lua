-- Round 40 PX: the Lua cost of a skill's effect on its cast path, before and
-- after the particle helper (a disposable probe, never shipped). The rest of
-- each cast path is unchanged by PX, so the effect calls are the difference.
-- A headless server has no player to cast with, so the probe calls what the
-- cast calls: "before" is the base's own code (kits.lua burst/beam,
-- combat.lua crit_particles, copied verbatim from 5e7539db), "after" is
-- grug_core.particles.play with the shipped catalogue. With no client
-- connected the engine sends nothing, so this is the Lua call and the
-- engine's table parse only (plan §3.4: the send cost is the model's).
--   PROBE=tools/r40_px/bench ~/projects/grudgelands-orchestration/r40/engine_run.sh ...
local REPS, ROUNDS = 2000, 3

-- The base code (kits.lua:142-174, combat.lua:1012-1024 at 5e7539db).
local function beam(user, target, texture)
	local from = user:get_pos()
	from.y = from.y + (user:get_properties().eye_height or 1.5)
	local to = vector.offset(target:get_pos(), 0, 1, 0)
	local dist = vector.distance(from, to)
	local steps = math.max(2, math.floor(dist * 2))
	local dir = vector.direction(from, to)
	for i = 1, steps do
		core.add_particle({
			pos = vector.add(from, vector.multiply(dir, i * dist / steps)),
			velocity = vector.new(0, 0, 0),
			expirationtime = 0.25,
			size = 2.5,
			texture = texture,
			glow = 12,
		})
	end
end

local function burst(pos, texture, amount)
	core.add_particlespawner({
		amount = amount or 12,
		time = 0.2,
		pos = {min = vector.offset(pos, -0.5, 0, -0.5),
			max = vector.offset(pos, 0.5, 1, 0.5)},
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = texture,
		glow = 10,
	})
end

local function crit_particles(pos)
	core.add_particlespawner({
		amount = 8,
		time = 0.15,
		pos = {min = vector.offset(pos, -0.4, 0.6, -0.4),
			max = vector.offset(pos, 0.4, 1.4, 0.4)},
		vel = {min = vector.new(-1, 1, -1), max = vector.new(1, 3, 1)},
		exptime = {min = 0.3, max = 0.6},
		size = {min = 2, max = 3},
		texture = "default_item_smoke.png^[multiply:#ffd100",
	})
end

-- Stand-ins for the caster and the target 6 m ahead (what beam reads).
local CASTER = vector.new(100, 20, 100)
local TARGET = vector.new(106, 20, 100)
local function object(pos)
	return {
		get_pos = function() return vector.copy(pos) end,
		get_properties = function() return {eye_height = 1.47} end,
	}
end
local user, target = object(CASTER), object(TARGET)
local DIR = vector.new(1, 0, 0)

-- What each cast calls at the effect, before and after.
local CASES = {
	{"ice_nova",
		function() burst(CASTER, "default_item_smoke.png^[multiply:#aaddff", 20) end,
		{"ice_nova", {caster = CASTER, reach = 5}}},
	{"smite",
		function()
			beam(user, target, "default_item_smoke.png^[multiply:#ffe9a0")
			burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0")
		end,
		{"smite", {caster = CASTER, target = TARGET, dir = DIR}}},
	{"mighty_blow",
		function() burst(TARGET, "mobs_blood.png", 6) end,
		{"mighty_blow", {caster = CASTER, target = TARGET, dir = DIR}}},
	{"fireball_impact", function() end, {"fireball", {target = TARGET}}},
	{"heal",
		function() burst(TARGET, "mobs_heart_particle.png", 8) end,
		{"heal", {target = TARGET}}},
	{"skill_arrow", function() end,
		{"skill_arrow", {from = vector.offset(CASTER, 0.3, 1.47, 0),
			to = vector.offset(CASTER, 25, 1.2, 0), time = 0.55, color = "#e9e4d0"}}},
	{"crit", function() crit_particles(TARGET) end, {"crit", {target = TARGET}}},
}

local function measure()
	local particles = grug_core.particles
	local mode = particles and "after" or "before"
	local parts = {}
	for _, case in ipairs(CASES) do
		local fn = case[2]
		if particles then
			local id, frame = case[3][1], case[3][2]
			fn = function() particles.play(id, frame) end
		end
		local t0 = core.get_us_time()
		for _ = 1, REPS do fn() end
		parts[#parts + 1] = ("%s=%.3f"):format(case[1], (core.get_us_time() - t0) / REPS)
	end
	core.log("action", "R40PX " .. mode .. " us_per_cast " .. table.concat(parts, " "))
end

core.after(3, function()
	for _ = 1, ROUNDS do measure() end
	core.log("action", "R40PX done")
	core.request_shutdown("r40 px bench done", false, 0)
end)
