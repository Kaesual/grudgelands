-- Disposable engine probe (Round 25 Lane G, ruling 24). Never shipped:
-- tools/r25_spawn_guard/run.sh stages it through tools/luanti_headless.sh
-- together with tools/r24_density_xp/probe_player_shim.patch (mobs_redo
-- count_mobs accepts the stationary probe points below as players in range).
--
-- Seed 4242424242, Moonfall Wood (the Round 24 density probe's spawn-rich
-- level-25 point). A 224 x 112 node window is force-loaded; its west half
-- holds ONE faked active claim (grug_housing.claim_at / is_active are
-- replaced here; the claim is x/z ±50 around CLAIM, from y -100 up). Two
-- stationary probe players stand at the claim centre and in the free east
-- half. Every grug_mobs entity the engine adds is recorded with its spawn
-- position (a core.add_entity wrapper), then:
--   * active window (night, ACTIVE_S): no hostile spawn inside the claim,
--     hostile spawns outside, and refused attempts seen by claim_at;
--   * expired window (night, EXPIRED_S): the same claim unfuelled, reported
--     (hostile spawns may appear inside again).
-- Hostile = the claim role: grug_mobs.spawn_role_hostile and not type npc.

local P = "[r25_spawn_guard_probe] "
local ACTIVE_S, EXPIRED_S = 120, 45
local CENTER = {x = 2400, z = -1600}
local CLAIM = {x = 2344, z = -1600}
local RADIUS, MIN_Y = 50, -100
local HALF_X, HALF_Z = 112, 56

local function log(msg) core.log("action", P .. msg) end

local claim_active = true
local fake_claim = {id = 1, owner = "probe", center = {x = CLAIM.x, y = 0, z = CLAIM.z},
	placed_at = os.time(), paid_until = os.time() + 86400}
local lookups, hits_active, hits_expired = 0, 0, 0

local function in_claim(pos)
	return pos.y >= MIN_Y and math.abs(pos.x - CLAIM.x) <= RADIUS and
		math.abs(pos.z - CLAIM.z) <= RADIUS
end

grug_housing.claim_at = function(pos)
	lookups = lookups + 1
	if in_claim(pos) then
		if claim_active then hits_active = hits_active + 1
		else hits_expired = hits_expired + 1 end
		return fake_claim
	end
	return nil
end
grug_housing.is_active = function(claim)
	return claim_active and claim == fake_claim
end

local function hostile(name)
	local def = core.registered_entities[name]
	return grug_mobs.spawn_role_hostile(name) and def and def.type ~= "npc"
end

-- phase -> {inside = {hostile, other}, outside = {hostile, other}, names}
local tally = {}
local phase

local add_entity = core.add_entity
core.add_entity = function(pos, name, ...)
	local object = add_entity(pos, name, ...)
	if object and phase and type(name) == "string" and mobs.spawning_mobs[name] then
		local t = tally[phase]
		local side = in_claim(pos) and "inside" or "outside"
		local kind = hostile(name) and "hostile" or "other"
		t[side][kind] = t[side][kind] + 1
		local key = side .. ":" .. name:gsub("^grug_mobs:", "")
		t.names[key] = (t.names[key] or 0) + 1
		if side == "inside" and kind == "hostile" then
			log(("%s hostile spawn INSIDE the claim: %s at %s"):format(phase, name,
				core.pos_to_string(vector.round(pos))))
		end
	end
	return object
end

local function start_phase(name)
	phase = name
	tally[name] = {inside = {hostile = 0, other = 0}, outside = {hostile = 0, other = 0},
		names = {}, lookups0 = lookups}
end

local function report(name)
	local t = tally[name]
	local keys = {}
	for key, count in pairs(t.names) do keys[#keys + 1] = key .. "=" .. count end
	table.sort(keys)
	log(("%s spawns inside: hostile=%d other=%d; outside: hostile=%d other=%d; " ..
		"claim lookups=%d [%s]"):format(name, t.inside.hostile, t.inside.other,
		t.outside.hostile, t.outside.other, lookups - t.lookups0, table.concat(keys, " ")))
end

local function census(label)
	local center = {x = CENTER.x, y = 40, z = CENTER.z}
	local inside, outside = 0, 0
	for _, object in ipairs(core.get_objects_inside_radius(center, 200)) do
		local ent = object:get_luaentity()
		local pos = object:get_pos()
		if ent and ent.name and mobs.spawning_mobs[ent.name] and hostile(ent.name) and pos then
			if in_claim(pos) then inside = inside + 1 else outside = outside + 1 end
		end
	end
	log(("census %s hostile present inside=%d (walk-ins allowed) outside=%d"):format(
		label, inside, outside))
end

local function hold_night(seconds)
	for s = 0, seconds, 15 do
		core.after(s, function() core.set_timeofday(0.0) end)
	end
end

local function run(h)
	mobs._grug_probe_players = {
		{x = CLAIM.x, y = h + 2, z = CLAIM.z},
		{x = CENTER.x + 56, y = h + 2, z = CENTER.z},
	}
	log(("claim centre zone=%s level=%s; free point zone=%s level=%s; h=%d"):format(
		tostring(grug_zones.id_at(CLAIM.x, CLAIM.z)),
		tostring(grug_zones.mob_level_at({x = CLAIM.x, y = h, z = CLAIM.z})),
		tostring(grug_zones.id_at(CENTER.x + 56, CENTER.z)),
		tostring(grug_zones.mob_level_at({x = CENTER.x + 56, y = h, z = CENTER.z})), h))
	hold_night(ACTIVE_S + EXPIRED_S)
	start_phase("active")
	hits_active = 0
	core.after(ACTIVE_S / 2, function() census("active@" .. (ACTIVE_S / 2)) end)
	core.after(ACTIVE_S, function()
		census("active@" .. ACTIVE_S)
		report("active")
		claim_active = false
		start_phase("expired")
		core.after(EXPIRED_S, function()
			report("expired")
			local a, e = tally.active, tally.expired
			log(("refused hostile attempts in the active claim=%d; lookups in the " ..
				"expired claim=%d"):format(hits_active, hits_expired))
			local ok = a.inside.hostile == 0 and a.outside.hostile > 0 and hits_active > 0
			log(("expired claim: hostile spawns inside=%d (informational)"):format(
				e.inside.hostile))
			log(ok and "RESULT PASS" or "RESULT FAIL")
			core.request_shutdown("r25 spawn guard probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local h = 44
	local ok, value = pcall(grug_zones.terrain_height_at, CLAIM.x, CLAIM.z)
	if ok and type(value) == "number" then h = math.floor(value) end
	local minp = {x = CENTER.x - HALF_X, y = h - 32, z = CENTER.z - HALF_Z}
	local maxp = {x = CENTER.x + HALF_X - 1, y = h + 47, z = CENTER.z + HALF_Z - 1}
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
			for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	local t0 = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining == 0 then
			log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
			core.after(1, function() run(h) end)
		end
	end)
end)
