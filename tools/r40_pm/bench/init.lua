-- Round 40 PM: the Lua cost of a boss or mob effect at its moment, before and
-- after the particle helper (a disposable probe, never shipped). "before" is
-- the base's own code (boss_dragons.lua burst / the rings / the trail,
-- telegraph.lua's wind-up, oerkki.lua's arrival, copied verbatim from
-- a8b3f51e; "none" where the base showed nothing), "after" is
-- grug_core.particles.play with the shipped catalogue, both in one run. With
-- no client connected the engine sends nothing, so this is the Lua call and
-- the engine's table parse only (plan §3.4: the send cost is the model's).
--   PROBE=tools/r40_pm/bench ~/projects/grudgelands-orchestration/r40/engine_run.sh ...
local REPS, ROUNDS = 2000, 3

-- The base code (boss_dragons.lua, telegraph.lua, oerkki.lua at a8b3f51e).
local function burst(pos, amount, texture, glow, radius, height, time)
	radius = radius or 3
	height = height or 4
	core.add_particlespawner({
		amount = amount,
		time = time or 0.5,
		pos = {min = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
			max = {x = pos.x + radius, y = pos.y + height, z = pos.z + radius}},
		vel = {min = {x = -3, y = 0.5, z = -3},
			max = {x = 3, y = 5, z = 3}},
		exptime = {min = 0.4, max = 1.6},
		size = {min = 2, max = 6},
		texture = texture,
		glow = glow or 0,
	})
end
local GUST_TEXTURE = "default_item_smoke.png^[colorize:#d8eef4:150"
local function gust_ring(pos)
	for index = 0, 39 do
		local angle = index * math.pi * 2 / 40
		core.add_particle({
			pos = {x = pos.x + math.cos(angle) * 8, y = pos.y + 0.2,
				z = pos.z + math.sin(angle) * 8},
			velocity = {x = 0, y = 0.3, z = 0},
			expirationtime = 1.25,
			size = 4,
			texture = GUST_TEXTURE,
			glow = 6,
		})
	end
end
local function trail_mote(pos)
	core.add_particle({
		pos = pos,
		velocity = {x = 0, y = 0, z = 0},
		expirationtime = 0.35,
		size = 4,
		texture = "grug_mobs_rock.png^[colorize:#b8f4ff:220",
		glow = 10,
	})
end
local function windup_particles(pos)
	core.add_particlespawner({
		amount = 24,
		time = 0.4,
		pos = {min = vector.offset(pos, -0.7, 0.2, -0.7),
			max = vector.offset(pos, 0.7, 1.8, 0.7)},
		vel = {min = vector.new(-0.5, 1, -0.5), max = vector.new(0.5, 3, 0.5)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 2.5, max = 4},
		texture = "default_item_smoke.png^[multiply:#ff5a1e",
		glow = 8,
	})
end
local function oerkki_arrival(dest)
	core.add_particlespawner({
		amount = 12, time = 0.2,
		pos = {min = vector.offset(dest, -0.4, 0, -0.4),
			max = vector.offset(dest, 0.4, 1.4, 0.4)},
		exptime = {min = 0.2, max = 0.5}, size = {min = 1, max = 2},
		texture = "default_item_smoke.png^[multiply:#7030a0", glow = 4,
	})
end

local POS = vector.new(100, 20, 100)
local DEST = vector.new(103, 20, 100)
local DIR = vector.new(1, 0, 0)
local function play(id, frame) return function() grug_core.particles.play(id, frame) end end
local none = function() end

-- name, before, after (one occurrence each).
local CASES = {
	{"lightning_strike", function() burst(POS, 96, "grug_mobs_rock.png^[colorize:#fff27a:230", 14,
		2, 8, 0.25) end, play("lightning_strike", {target = POS})},
	{"gust_windup", function() gust_ring(POS) end,
		play("gust_windup", {target = POS, reach = 8, time = 1.25})},
	{"gust_release", function() burst(POS, 96, GUST_TEXTURE, 3, 8, 3, 0.4) end,
		play("gust_release", {target = POS, reach = 8})},
	{"dive_slam", function() burst(POS, 120, "default_item_smoke.png^[colorize:#ffd24a:190", 8,
		7, 5, 0.3) end, play("dive_slam", {target = POS, reach = 7})},
	{"enrage", function() burst(POS, 180, "default_item_smoke.png^[colorize:#ff341f:210", 12,
		7, 10, 0.8) end, play("enrage", {target = POS})},
	{"breath_trail_per_bolt", function() for _ = 1, 18 do trail_mote(POS) end end,
		function() for _ = 1, 12 do grug_core.particles.play("breath_trail",
			{caster = POS, color = "#8ee8ff"}) end end},
	{"shatter_windup_ring", none, play("king_windup_ring", {target = POS, reach = 6, time = 2})},
	{"shatter_burst", none, play("king_shatter", {target = POS, reach = 6})},
	{"elite_windup", function() windup_particles(POS) end, play("elite_windup", {caster = POS})},
	{"elite_cone", none, play("elite_cone", {caster = POS, dir = DIR, reach = 3})},
	{"web", none, play("web", {target = POS})},
	{"oerkki_blink", function() oerkki_arrival(DEST) end,
		play("oerkki_blink", {caster = POS, target = DEST})},
}

local function time_of(fn)
	local t0 = core.get_us_time()
	for _ = 1, REPS do fn() end
	return (core.get_us_time() - t0) / REPS
end

local function measure(round)
	local before, after = {}, {}
	for _, case in ipairs(CASES) do
		before[#before + 1] = ("%s=%.3f"):format(case[1], time_of(case[2]))
		after[#after + 1] = ("%s=%.3f"):format(case[1], time_of(case[3]))
	end
	core.log("action", "R40PM round " .. round .. " before us " .. table.concat(before, " "))
	core.log("action", "R40PM round " .. round .. " after us " .. table.concat(after, " "))
end

core.after(3, function()
	for round = 1, ROUNDS do measure(round) end
	core.log("action", "R40PM done")
	core.request_shutdown("r40 pm bench done", false, 0)
end)
