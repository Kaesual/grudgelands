-- The one scenario, on test_vault at level 20 in its closed trap gallery: the floor
-- trap's ring, hit, mark and rearm; the wall's fireball, its burst on the player and
-- the stone; a rabbit on a trap and in a line, never noticed. `SHOT <name>` lines are
-- run.sh's cue for a screenshot.
local E = grug_expeditions
local TR = E.traps
local us = core.get_us_time

return function(lib, player)
	grug_xp.set_xp(player, grug_xp.xp_for_level(20))
	local plays = {}
	local play = grug_core.particles.play
	grug_core.particles.play = function(id, frame)
		if id:find("^expedition_") and id ~= "expedition_fireball_tail" then
			plays[#plays + 1] = {id = id, t = us() / 1e6, pos = frame.target}
		end
		return play(id, frame)
	end
	local changes = {}
	core.register_on_player_hpchange(function(p, change, reason)
		if reason and reason.custom_type == grug_core.ARMOR_APPLIED_CUSTOM_TYPE then
			changes[#changes + 1] = {t = us() / 1e6, change = change, pos = p:get_pos()}
		end
	end, false)
	local function plays_of(id, since)
		local out = {}
		for _, row in ipairs(plays) do
			if row.id == id and row.t >= (since or 0) then out[#out + 1] = row end
		end
		return out
	end

	local run = assert(E.create(player, "test_vault", 0))
	lib.wait_for(function() return run.state == "ready" end, 90)
	lib.check(run.state == "ready" and run.level == 20, "ready at level 20")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
	core.load_area(run.minp, vector.add(run.minp, 47))
	local chosen = TR.chosen(run)
	local floor1, wall1
	for _, row in ipairs(chosen.floor) do
		lib.logf("floor %s at %s", row.group, core.pos_to_string(vector.subtract(row.cell, run.minp)))
		if row.group == "f1" then floor1 = row.cell end
	end
	for _, row in ipairs(chosen.wall) do
		lib.logf("wall %s at %s %s", row.group, core.pos_to_string(vector.subtract(row.muzzle, run.minp)),
			row.axis)
		if row.group == "w1" then wall1 = row end
	end
	local function rel(x, y, z) return {x = run.minp.x + x, y = run.minp.y + y, z = run.minp.z + z} end
	local function stand(pos, yaw)
		player:set_pos({x = pos.x, y = pos.y - 0.49, z = pos.z})
		if yaw then
			player:set_look_horizontal(yaw)
			player:set_look_vertical(0.35)
		end
	end
	local EAST, WEST, NORTH = 3 * math.pi / 2, math.pi / 2, 0
	local expected = grug_core.apply_player_armor(player, TR.damage(20), 20)
	lib.logf("damage %d before armor, %d after; hp %d of %d", TR.damage(20), expected,
		player:get_hp(), player:get_properties().hp_max)

	-- A rabbit on the trap fires nothing.
	local rabbit = core.add_entity(vector.offset(floor1, 0, -0.5, 0), "grug_mobs:rabbit")
	local function pin(pos)
		if rabbit and rabbit:get_pos() then
			rabbit:set_pos(pos)
			rabbit:set_velocity({x = 0, y = 0, z = 0})
		end
	end
	stand(rel(10, 5, 26), NORTH)
	local t0 = us() / 1e6
	lib.wait_for(function() pin(vector.offset(floor1, 0, -0.5, 0)); return false end, 3)
	lib.check(rabbit ~= nil and rabbit:get_pos() ~= nil, "a rabbit stands on the trap")
	lib.check(#plays_of("expedition_trap_warning", t0) == 0, "a rabbit on a trap fires nothing")

	-- The ring: on the trap, then back to look at it.
	local side = floor1.x - run.minp.x < 11 and 1 or -1
	local watch = vector.offset(floor1, -4 * side, 0, 0)
	stand(watch, side == 1 and EAST or WEST)
	lib.wait(0.5)
	t0 = us() / 1e6
	stand(floor1)
	lib.wait_for(function() return #plays_of("expedition_trap_warning", t0) > 0 end, 2)
	local ring = plays_of("expedition_trap_warning", t0)[1]
	lib.check(ring ~= nil, "treading on it starts the ring")
	stand(watch, side == 1 and EAST or WEST)
	lib.wait(0.4)
	lib.log("SHOT ring")
	local hp = player:get_hp()
	lib.wait_for(function() return #plays_of("expedition_trap_hit", t0) > 0 end, 3)
	local hit = plays_of("expedition_trap_hit", t0)[1]
	lib.check(hit and math.abs(hit.t - ring.t - TR.WARNING) < 0.25,
		("the hit %.2f s after the ring"):format(hit and hit.t - ring.t or -1))
	lib.wait(0.2)
	lib.check(player:get_hp() == hp, "4 nodes away, no damage")
	lib.check(core.get_node(floor1).name == "grug_expeditions:trap_mark", "the mark after the first hit")

	-- The damage, and the rearm: stand on it until it fires again.
	stand(floor1, side == 1 and EAST or WEST)
	local got
	for try = 1, 3 do
		local since = us() / 1e6
		lib.wait_for(function() return #plays_of("expedition_trap_hit", since) > 0 end, 13)
		local second = plays_of("expedition_trap_hit", since)[1]
		local warn = plays_of("expedition_trap_warning", since)[1]
		lib.check(second ~= nil and warn ~= nil, "it fires again, try " .. try)
		if try == 1 and warn then
			lib.check(math.abs(warn.t - hit.t - TR.REARM) < 0.35,
				("the second ring %.2f s after the first hit"):format(warn.t - hit.t))
		end
		lib.wait(0.1)
		local change = changes[#changes]
		if change and change.t >= since and change.change < 0 then
			got = -change.change
			break
		end
		lib.logf("try %d: dodged or no change", try)
	end
	lib.check(got == expected, ("the hit on the trap: %s, expected %d"):format(tostring(got), expected))

	-- The wall: a rabbit in w1's line, the player beside it; the ball passes the rabbit
	-- and stops at the stone.
	player:set_hp(player:get_properties().hp_max)
	local mid = rel(12, 5, 34)
	local rabbit_hp = rabbit and rabbit:get_luaentity() and rabbit:get_luaentity().health
	stand(rel(12, 5, 30), wall1.axis == "+x" and WEST or EAST)
	local ball
	lib.wait_for(function()
		pin(vector.offset(mid, 0, -0.5, 0))
		for object in core.objects_inside_radius(wall1.muzzle, 2) do
			local ent = object:get_luaentity()
			if ent and ent.name == "grug_expeditions:trap_fireball" then ball = object end
		end
		return ball ~= nil
	end, 10)
	lib.check(ball ~= nil, "w1 shoots")
	local launched = us() / 1e6
	local shot, last = false, nil
	lib.wait_for(function()
		pin(vector.offset(mid, 0, -0.5, 0))
		local pos = ball:get_pos()
		if pos then last = pos end
		if not shot and us() / 1e6 - launched > 0.7 then
			shot = true
			lib.logf("SHOT fireball at %s", core.pos_to_string(vector.subtract(pos, run.minp)))
		end
		return pos == nil
	end, 5)
	local flown = (us() / 1e6 - launched) * TR.SPEED
	-- The gallery is x 4..19: the stone's face at 19.5 or 3.5, less the ball's radius.
	local stop = wall1.axis == "+x" and 19.5 - 0.4 or 3.5 + 0.4
	lib.check(last and math.abs(last.x - run.minp.x - stop) < 1.2,
		("the stone stops it at x %.2f (face %.1f), %.1f nodes flown"):format(
			last and last.x - run.minp.x or -1, stop, flown))
	lib.check(rabbit and rabbit:get_pos() ~= nil and rabbit:get_luaentity().health == rabbit_hp,
		"the rabbit in the line is untouched")

	-- The player in w2's line: the burst.
	stand(rel(12, 5, 42), WEST)
	local before = #changes
	local here = player:get_pos()
	lib.wait_for(function() return #changes > before end, 6)
	local burst = plays_of("expedition_fireball_burst", launched)
	lib.check(#changes > before and -changes[#changes].change == expected,
		("the fireball's burst: %s"):format(changes[#changes] and tostring(-changes[#changes].change) or "none"))
	lib.check(#burst > 0, "a burst played")
	lib.wait(0.5)
	lib.check(vector.distance(player:get_pos(), here) < 0.05, "no knockback")

	-- The end takes it all.
	E.end_run(run, "empty")
	lib.wait(0.5)
	lib.check(TR.chosen(run) == nil, "the run's traps are gone")
	local left = 0
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent.name == "grug_expeditions:trap_fireball" then left = left + 1 end
	end
	lib.check(left == 0, "no fireball left")
end
