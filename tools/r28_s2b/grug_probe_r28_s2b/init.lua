-- Disposable engine probe (Round 28 Lane S2b). Never shipped:
-- tools/r28_s2b/run.sh stages it through tools/luanti_headless.sh together
-- with tools/r24_density_xp/probe_player_shim.patch (mobs_redo's add_mob
-- accepts the stationary probe point as a player in range).
--
-- Blight ground keeps a zombie leader through the day: with the SHIPPED Nhal
-- Veyr recipe, Mortuary-Clerk Hush (a zombie leader, catalogue: "actual
-- blight dirt at the fixed spot is mandatory so this solo climax survives
-- daylight") is spawned by the real leader tick at noon, then held at noon
-- for HOLD seconds:
--   * the node under the leader is grug_nodes:blight_dirt and its
--     light_damage is 0 (spawn_regions.sunproof_on_blight);
--   * its health is at hp_max after the hold;
--   * a control zombie added beside it on the same ground without the
--     region spawner keeps the base zombie's daylight burn and loses health.
-- RESULT PASS / FAIL.

local P = "[r28_s2b_probe] "
local ZONE = "kragmar_nhal_veyr"
local ROLE = "mortuary_clerk_hush"
local HOLD = 40
local SR = grug_mobs.spawn_regions

local failures = {}
local function log(msg) core.log("action", P .. msg) end
local function fail(msg)
	failures[#failures + 1] = msg
	log("CHECK FAIL " .. msg)
end

local function finish()
	log((#failures == 0 and "RESULT PASS" or "RESULT FAIL") .. " failures=" .. #failures)
	core.request_shutdown("r28 s2b probe done", false, 0)
end

local function find_leader()
	for _, object in ipairs(core.get_objects_inside_radius(SR.probe_spot, 64)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_leader and ent.name == "grug_mobs:" .. ROLE then
			return ent
		end
	end
	return nil
end

local function hold(leader, control)
	local hp0 = leader.health
	local c0 = control and control.health
	for s = 5, HOLD, 5 do
		core.after(s, function() core.set_timeofday(0.5) end)
	end
	core.after(HOLD, function()
		local pos = leader.object and leader.object:get_pos()
		if not pos then
			fail("the leader is gone after " .. HOLD .. " s of noon")
			return finish()
		end
		log(("after %d s at noon: leader health %s / %s (was %s), light %s"):format(HOLD,
			tostring(leader.health), tostring(leader.hp_max), tostring(hp0),
			tostring(core.get_node_light({x = pos.x, y = pos.y + 1, z = pos.z}))))
		if not leader.hp_max or leader.health < leader.hp_max then fail("the leader lost health in daylight") end
		local cpos = control and control.object and control.object:get_pos()
		log(("control zombie: health %s (was %s)%s"):format(tostring(cpos and control.health),
			tostring(c0), cpos and "" or ", burnt away"))
		if cpos and control.health >= c0 then
			fail("the control zombie did not burn: the probe saw no daylight")
		end
		finish()
	end)
end

local function start(spot)
	core.set_timeofday(0.5)
	local fake = {pos = {x = spot.x + 40, y = spot.y + 1, z = spot.z}}
	function fake:get_pos() return self.pos end
	mobs._grug_probe_players = {fake.pos}
	SR.players = function() return {fake} end
	SR.leader_tick(core.get_gametime() + 1, {fake})
	local leader = find_leader()
	if not leader then
		fail("no leader spawned at its spot")
		return finish()
	end
	local pos = leader.object:get_pos()
	local below = core.get_node({x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5) - 1,
		z = math.floor(pos.z + 0.5)}).name
	log(("leader %s at (%d, %d, %d) on %s, level %s, light_damage %s, health %s"):format(
		leader.name, math.floor(pos.x), math.floor(pos.y), math.floor(pos.z), below, tostring(leader._grug_level or leader._grug_spawn_level),
		tostring(leader.light_damage), tostring(leader.health)))
	if below ~= SR.BLIGHT_GROUND then fail("the leader's spot is not blight dirt (" .. below .. ")") end
	if leader.light_damage ~= 0 then fail("the leader on blight keeps its daylight burn") end
	-- The control: a plain zombie sub-type beside it, not set by the spawner.
	local control = grug_mobs.add_mob({x = pos.x + 3, y = pos.y, z = pos.z},
		{name = "grug_mobs:stubborn_zombie", ignore_count = true})
	if control then
		log(("control zombie light_damage %s, health %s"):format(tostring(control.light_damage),
			tostring(control.health)))
	else
		fail("no control zombie")
	end
	hold(leader, control)
end

core.after(2, function()
	local map = SR.map(ZONE)
	local spot
	for _, s in ipairs(map and map.leaders or {}) do
		if s.role == ROLE then spot = s end
	end
	if not spot then
		fail("no spot for " .. ROLE)
		return finish()
	end
	spot.y = grug_zones.terrain_height_at(spot.x, spot.z)
	SR.probe_spot = {x = spot.x, y = spot.y, z = spot.z}
	log(("spot %s (%d, %d, %d), level %d"):format(ROLE, spot.x, spot.y, spot.z, spot.level))
	local minp = {x = spot.x - 64, y = spot.y - 32, z = spot.z - 64}
	local maxp = {x = spot.x + 63, y = spot.y + 47, z = spot.z + 63}
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
			for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining == 0 then
			core.after(2, function() start(spot) end)
		end
	end)
end)
