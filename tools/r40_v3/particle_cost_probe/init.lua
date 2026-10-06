-- Round 40 V3: measures the Lua-side cost of the particle API on a headless
-- server with no client connected (the per-receiver send cost needs a client
-- and is modelled on the page from the serialization format instead).
local N_SP, N_P = 2000, 5000
local function spawner_def(attract)
	local d = {
		amount = 24, time = 0.05,
		pos = {min = vector.new(-0.5, 10, -0.5), max = vector.new(0.5, 11, 0.5)},
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		acc = vector.new(0, -9, 0),
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = "default_item_smoke.png^[multiply:#ffe9a0",
		glow = 12,
	}
	if attract then
		d.attract = {kind = "point", strength = -12, origin = vector.new(0, 10, 0)}
		d.radius = {min = vector.new(0.3, 0, 0.3), max = vector.new(0.3, 0, 0.3), bias = 1}
	end
	return d
end
local function particle_def(i)
	return {
		pos = vector.new(i % 7, 10, 0), velocity = vector.new(0, 0, 0),
		expirationtime = 0.25, size = 2.5,
		texture = "default_item_smoke.png^[multiply:#ffe9a0", glow = 12,
	}
end
local function measure()
	local out = {}
	local t0 = core.get_us_time()
	for _ = 1, N_SP do local _d = spawner_def(false) end
	local t_tab = core.get_us_time() - t0
	local ids = {}
	t0 = core.get_us_time()
	for i = 1, N_SP do ids[i] = core.add_particlespawner(spawner_def(false)) end
	local t_sp = core.get_us_time() - t0
	for i = 1, N_SP do core.delete_particlespawner(ids[i]) end
	t0 = core.get_us_time()
	for i = 1, N_SP do ids[i] = core.add_particlespawner(spawner_def(true)) end
	local t_spa = core.get_us_time() - t0
	for i = 1, N_SP do core.delete_particlespawner(ids[i]) end
	t0 = core.get_us_time()
	for i = 1, N_P do local _d = particle_def(i) end
	local t_ptab = core.get_us_time() - t0
	t0 = core.get_us_time()
	for i = 1, N_P do core.add_particle(particle_def(i)) end
	local t_p = core.get_us_time() - t0
	out[#out + 1] = ("R40COST spawner_table_us=%.3f spawner_call_us=%.3f spawner_attract_call_us=%.3f"):format(
		t_tab / N_SP, t_sp / N_SP, t_spa / N_SP)
	out[#out + 1] = ("R40COST particle_table_us=%.3f particle_call_us=%.3f"):format(t_ptab / N_P, t_p / N_P)
	for _, l in ipairs(out) do core.log("action", l) end
end
core.after(3, function() for _ = 1, 3 do measure() end end)
