-- The one scenario, on test_vault at level 20 (Round 73 lane GAME). Questions: the
-- written lava fall under the lava hold; the particles to the run's player alone;
-- critters out of combat and without drops; a player and a mob on the stairs, inner and
-- outer included; a mob chasing at a basin's edge and one pushed in; the ambush not on a
-- respawn or a trip, once per run, from each way across (one run per way). `SHOT <name>`
-- lines are run.sh's cue for a screenshot.
local E = grug_expeditions
local TR = E.traps
local us = core.get_us_time

return function(lib, player)
	local NAME = lib.NAME
	grug_xp.set_xp(player, grug_xp.xp_for_level(20))
	local hp_max = player:get_properties().hp_max
	-- The player stays alive through the mobs' hits, except where the probe kills it.
	local keep_alive = true
	core.register_globalstep(function()
		local p = core.get_player_by_name(NAME)
		if keep_alive and p and p:get_hp() > 0 then p:set_hp(hp_max) end
	end)
	local springs = {}
	local spring_room = E._spring_room
	E._spring_room = function(run, room, p)
		springs[#springs + 1] = {run = run.id, room = room, t = us() / 1e6, pos = p:get_pos()}
		lib.logf("SPRING run %d room %s at %s", run.id, room,
			core.pos_to_string(vector.subtract(p:get_pos(), run.minp), 1))
		if #springs == 1 then lib.log("SHOT ambush") end
		return spring_room(run, room, p)
	end
	local spawners = {}
	local add_spawner = core.add_particlespawner
	core.add_particlespawner = function(def)
		local id = add_spawner(def)
		if def.time == 0 then
			spawners[#spawners + 1] = {id = id, name = def.playername, amount = def.amount,
				life = def.exptime and def.exptime.max}
		end
		return id
	end
	local dust = 0
	local play = grug_core.particles.play
	grug_core.particles.play = function(id, frame)
		if id == "expedition_ambush_dust" then dust = dust + 1 end
		return play(id, frame)
	end

	local run
	local function rel(x, y, z) return {x = run.minp.x + x, y = run.minp.y + y, z = run.minp.z + z} end
	local function stand(pos, yaw, pitch)
		player:set_pos({x = pos.x, y = pos.y - 0.49, z = pos.z})
		-- Players take no set_velocity: a push is taken back by its opposite.
		local v = player:get_velocity()
		if v and vector.length(v) > 0.01 then player:add_velocity(vector.multiply(v, -1)) end
		if yaw then
			player:set_look_horizontal(yaw)
			player:set_look_vertical(pitch or 0.2)
		end
	end
	local EAST, WEST, NORTH, SOUTH = 3 * math.pi / 2, math.pi / 2, 0, math.pi
	local function objects(filter)
		local out = {}
		for object in core.objects_in_area(run.minp, vector.add(run.minp, 47)) do
			local ent = not object:is_player() and object:get_luaentity()
			if ent and filter(ent) then out[#out + 1] = object end
		end
		return out
	end
	local function new_run(label)
		local t0 = us()
		run = assert(E.create(player, "test_vault", 0))
		lib.wait_for(function() return run.state == "ready" end, 60)
		local ready_s = (us() - t0) / 1e6
		lib.wait_for(function() return not grug_core.in_combat(player) and player:get_hp() > 0 end, 10)
		local ok, why = E.enter(player, "highcourt")
		if not ok then lib.logf("enter refused: %s", tostring(why)) end
		lib.wait_for(function() return E.run_inside(player) == run end, 30)
		core.load_area(run.minp, vector.add(run.minp, 47))
		lib.logf("RUN %s id %d slot %d ready %.1f s, inside %.1f s", label, run.id, run.slot, ready_s,
			(us() - t0) / 1e6)
		return E.run_inside(player) == run
	end
	local function end_run()
		E.end_run(run, "finished")
		lib.wait_for(function() return E.run_inside(player) == nil end, 20)
		lib.wait(0.5)
	end
	local function in_lava(object)
		local p = object:get_pos()
		if not p then return false end
		local node = core.get_node({x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)})
		return core.get_item_group(node.name, "lava") > 0
	end
	-- An Expedition mob outside the packs: the chase of mobs_redo and grug_nav alone.
	local function test_mob(pos)
		local object = core.add_entity(pos, "grug_mobs:zombie", core.serialize({
			_grug_spawn_level = 20, _grug_expedition = run.id, _grug_authored = true, lifetimer = 30000}))
		return object
	end
	local function lava_cells()
		local cells = {{45, 9, 8}, {44, 9, 8}, {44, 8, 8}, {44, 7, 8}, {44, 6, 8}, {44, 5, 8},
			{44, 4, 8}, {43, 4, 8}, {43, 4, 9}, {42, 4, 8}, {42, 4, 9}}
		local out = {}
		for _, c in ipairs(cells) do
			local node = core.get_node(rel(c[1], c[2], c[3]))
			out[#out + 1] = ("%d,%d,%d=%s/%d"):format(c[1], c[2], c[3],
				node.name:gsub("^default:lava_", ""), node.param2)
		end
		return table.concat(out, " ")
	end
	local function barriers()
		return #core.find_nodes_in_area(rel(38, 3, 3), rel(46, 11, 13), {grug_core.WATER_BARRIER})
	end

	-- ---- Run 1: everything but the other ways across ---------------------------------
	lib.check(new_run("walk"), "run 1 inside")
	local written = lava_cells()
	lib.logf("LAVA written %s", written)

	-- Particles: one endless spawner, to this player alone.
	lib.check(E.ambience.count(run, NAME) == 1, "one ambient spawner for the run's player")
	for _, row in ipairs(spawners) do
		lib.logf("spawner %s to %s, %d/s x %.1f s", tostring(row.id), tostring(row.name), row.amount, row.life)
		lib.check(row.name == NAME and row.amount * row.life <= 24, "the spawner is the player's, within 24")
	end
	stand(rel(12, 5, 5), WEST - 0.5, 0.1)
	lib.wait(2.5)
	lib.log("SHOT dust")
	lib.wait(0.5)

	-- Critters: placed outside the packs, scenery.
	lib.wait_for(function() return #objects(function(e) return e._grug_scenery end) >= 2 end, 5)
	local critters = objects(function(e) return e._grug_scenery end)
	lib.check(#critters == 2, "two critters placed: " .. #critters)
	for _, object in ipairs(critters) do
		local ent = object:get_luaentity()
		lib.check(ent._grug_expedition == run.id and not ent._grug_pack and ent.lava_damage == 0,
			ent.name .. ": an Expedition mob, no pack, immune to lava")
	end
	local crawler = objects(function(e) return e.name == "grug_mobs:cave_crawler" end)[1]
	if crawler then
		stand(vector.offset(crawler:get_pos(), -1.5, 0.5, 0), EAST)
		crawler:punch(player, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 0}})
		lib.wait(0.3)
		lib.check(not grug_core.in_combat(player), "hitting a critter starts no fight")
		local xp = grug_xp.get_xp(player)
		local at = crawler:get_pos()
		crawler:punch(player, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 50}})
		lib.wait(1.5)
		local items = 0
		for object in core.objects_inside_radius(at, 4) do
			local ent = object:get_luaentity()
			if ent and ent.name == "__builtin:item" then items = items + 1 end
		end
		lib.check(crawler:get_pos() == nil, "the crawler is dead")
		lib.check(items == 0, "it dropped nothing: " .. items)
		lib.check(grug_xp.get_xp(player) == xp, "no XP for it")
		lib.check(not grug_core.in_combat(player), "and no fight after it")
	end

	-- The hall's packs and the boss go, so the tests below meet only their own mobs.
	lib.wait_for(function() return #objects(function(e) return e._grug_pack end) >= 4 end, 5)
	for _, object in ipairs(objects(function(e) return e._grug_pack end)) do
		object:punch(player, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 100000}})
	end
	lib.wait_for(function() return #objects(function(e) return e._grug_pack end) == 0 end, 5)
	lib.check(#objects(function(e) return e._grug_pack end) == 0, "the hall is empty")
	lib.wait_for(function() return not grug_core.in_combat(player) end, 6)

	-- A player on the stairs, pushed: a normal, an outer and an inner stair.
	local function push(label, from, vel, want_y)
		stand(from, nil)
		lib.wait(0.6)
		player:add_velocity(vel)
		lib.wait(1.5)
		local p = player:get_pos()
		lib.logf("PLAYER %s: from %s to %s", label, core.pos_to_string(from),
			core.pos_to_string(vector.subtract(p, run.minp), 2))
		lib.check(math.abs(p.y - run.minp.y - want_y) < 0.2, "a player walks the " .. label)
	end
	push("normal stair up", rel(23.8, 5, 5.5), {x = 4.5, y = 0, z = 0}, 5.5)
	push("normal stair down", rel(27.5, 6, 5.5), {x = -4.5, y = 0, z = 0}, 4.5)
	push("outer stair up", rel(23.9, 5, 11.1), {x = 3.2, y = 0, z = -3.2}, 5.5)
	push("inner stair up", rel(29.6, 5, 8.6), {x = -3, y = 0, z = -3}, 5.5)

	-- A mob after the player over the stairs: the stair types its feet stood on.
	local function chase(label, mob_at, player_at, seconds)
		stand(player_at, nil)
		local mob = test_mob(mob_at)
		local seen = {}
		local top = false
		lib.wait_for(function()
			local p = mob:get_pos()
			if not p then return true end
			local below = core.get_node({x = math.floor(p.x + 0.5), y = math.floor(p.y - 0.3 + 0.5),
				z = math.floor(p.z + 0.5)}).name
			if below:find("^stairs:") then seen[below:gsub("stairs:stair_", ""):gsub("_stonebrick", "")] = true end
			if p.y - run.minp.y > 5.3 then top = true end
			stand(player_at, nil)
			return false
		end, seconds)
		local list = {}
		for name in pairs(seen) do list[#list + 1] = name end
		table.sort(list)
		lib.logf("MOB %s: stood on %s, reached the top %s", label, table.concat(list, ","), tostring(top))
		lib.check(top, "a mob climbs the rise: " .. label)
		mob:remove()
		return seen
	end
	local types = {}
	for _, row in ipairs({
		{"west", rel(24, 5, 9), rel(27.5, 6, 5.5)},
		{"arm end", rel(26.5, 5, 13), rel(26.5, 6, 8.5)},
		{"inner corner", rel(31, 5, 10), rel(27, 6, 6)},
		{"east", rel(33, 5, 5), rel(26.5, 6, 5)},
	}) do
		for name in pairs(chase(row[1], row[2], row[3], 6)) do types[name] = true end
	end
	lib.check(types[""] ~= nil or types["stonebrick"] ~= nil or next(types) ~= nil, "mobs stood on stairs")
	lib.logf("STAIRS the mobs stood on: normal %s, outer %s, inner %s", tostring(types[""] or types["stonebrick"] or false),
		tostring(types["outer"] or false), tostring(types["inner"] or false))

	-- The basin: a mob chasing at its edge, a mob pushed in.
	stand(rel(42, 5, 10.3), SOUTH)
	local chaser = test_mob(rel(42, 5, 5))
	local stepped_in, closest = false, 99
	lib.wait_for(function()
		if not chaser:get_pos() then return true end
		if in_lava(chaser) then stepped_in = true end
		closest = math.min(closest, vector.distance(chaser:get_pos(), player:get_pos()))
		stand(rel(42, 5, 10.3), nil)
		return false
	end, 8)
	lib.logf("BASIN chase: in lava %s, came within %.1f", tostring(stepped_in), closest)
	lib.check(not stepped_in, "a mob chasing at the basin's edge never steps in")
	stand(rel(40, 5, 12), EAST - 0.75, 0.25)
	lib.log("SHOT fall")
	lib.wait(0.6)
	local ent = chaser:get_luaentity()
	local hp = ent and ent.health
	chaser:set_pos(rel(43, 3.5, 8))
	chaser:set_velocity({x = 0, y = 0, z = 0})
	lib.wait(0.5)
	local was_in = in_lava(chaser)
	local out_after = lib.wait_for(function() return chaser:get_pos() and not in_lava(chaser) end, 10)
	ent = chaser:get_luaentity()
	lib.logf("BASIN push: in lava %s, out after %s s, health %s -> %s", tostring(was_in), tostring(out_after),
		tostring(hp), tostring(ent and ent.health))
	lib.check(was_in and ent and ent.health == hp, "pushed in: no damage")
	lib.check(out_after ~= nil, "and it walks out")
	chaser:remove()

	-- The ambush: a respawn and a trip do not spring it.
	stand(rel(17, 5, 19), WEST)
	lib.wait(0.5)
	keep_alive = false
	player:set_hp(0)
	lib.wait(0.5)
	if player:get_hp() <= 0 then player:respawn() end
	lib.wait_for(function() return player:get_hp() > 0 end, 10)
	keep_alive = true
	lib.wait(1)
	lib.logf("respawned at %s", core.pos_to_string(vector.round(vector.subtract(player:get_pos(), run.minp))))
	stand(rel(17, 5, 19), WEST)
	lib.wait(0.5)
	lib.wait_for(function() return not grug_core.in_combat(player) end, 6)
	local left = E.leave(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 20)
	lib.check(left and E.run_inside(player) == nil, "out on a trip")
	E.enter(player, "highcourt")
	lib.wait_for(function() return E.run_inside(player) == run end, 30)
	lib.check(#springs == 0, "a respawn and a trip spring nothing")

	-- A walk across: it springs once, the pack in the alcoves, the dust its cue.
	local function walk_across(from_x, to_x, z, speed, dy, yaw)
		stand(rel(from_x, 5 + (dy or 0), z), yaw or (from_x < to_x and EAST or WEST), 0)
		lib.wait(0.3)
		local x = from_x
		local dir = to_x > from_x and 1 or -1
		local last = us()
		lib.wait_for(function()
			local now = us()
			x = x + dir * speed * (now - last) / 1e6
			last = now
			stand(rel(x, 5 + (dy or 0), z), nil)
			return (to_x - x) * dir <= 0
		end, 10)
	end
	local before = #springs
	-- Facing the north alcove while walking past it: the screenshot at the spring.
	walk_across(7, 17, 19, 4, 0, NORTH - 0.3)
	lib.check(#springs == before + 1, "a walk across springs it")
	lib.wait(1)
	local zombies = objects(function(e) return e._grug_pack and e.name == "grug_mobs:zombie" end)
	lib.check(#zombies == 2 and dust >= 2, ("two zombies from the alcoves (%d), the dust burst (%d)"):format(#zombies, dust))
	lib.check(grug_core.in_combat(player), "the pack took the player at once")
	-- A wipe: the player dies; the pack waits in its alcoves; crossing again spawns nothing.
	keep_alive = false
	player:set_hp(0)
	lib.wait(0.5)
	if player:get_hp() <= 0 then player:respawn() end
	lib.wait_for(function() return player:get_hp() > 0 end, 10)
	keep_alive = true
	lib.wait(6)
	local homes = {}
	for _, object in ipairs(objects(function(e) return e._grug_pack and e.name == "grug_mobs:zombie" end)) do
		homes[#homes + 1] = core.pos_to_string(vector.round(vector.subtract(object:get_pos(), run.minp)))
	end
	lib.logf("after the wipe the zombies stand at %s", table.concat(homes, " "))
	walk_across(17, 7, 19, 4)
	lib.wait(1)
	local count = #objects(function(e) return e._grug_pack and e.name == "grug_mobs:zombie" end)
	lib.check(#springs == before + 1 and count == 2, "crossing again after the wipe: no spring, still two: " .. count)

	-- The lava fall, after a nudge that queues its liquids.
	lib.logf("LAVA after the run %s", lava_cells())
	lib.check(lava_cells() == written, "the written lava fall is unchanged")
	core.set_node(rel(43, 7, 8), {name = "air"})
	core.set_node(rel(42, 5, 8), {name = "air"})
	lib.wait(4)
	local nudged = lava_cells()
	lib.logf("LAVA after a nudge %s; barriers %d", nudged, barriers())
	lib.check(nudged == written, "and after a nudge that wakes its flow")
	lib.check(E.ambience.count(run, NAME) == 1, "the spawner still there inside")
	end_run()
	lib.check(E.ambience.count(run, NAME) == 0, "gone with the run")

	-- ---- Runs 2..6: one way across each ----------------------------------------------
	local ways = {
		{"blink", function()
			stand(rel(8, 5, 19), EAST, 0)
			lib.wait(0.4)
			stand(rel(17.5, 5, 19), nil)
			lib.wait(0.6)
		end},
		{"knockback", function()
			stand(rel(8.5, 5, 19), EAST, 0)
			lib.wait(0.6)
			player:add_velocity({x = 12, y = 2, z = 0})
			lib.wait(1.5)
			lib.logf("knocked to %s", core.pos_to_string(vector.subtract(player:get_pos(), run.minp), 1))
		end},
		{"charge", function() walk_across(5, 19, 19.6, 24) end},
		{"sprint", function() walk_across(7, 17, 18.4, 5.6) end},
		{"jump", function()
			stand(rel(9.6, 5, 19), EAST, 0)
			lib.wait(0.4)
			local t0 = us()
			lib.wait_for(function()
				local t = (us() - t0) / 1e6
				stand(rel(9.6 + 5 * t, 5 + math.max(0, 6.5 * t - 9.8 * t * t / 2 * 1.3), 19), nil)
				return t > 1
			end, 3)
		end},
	}
	for _, way in ipairs(ways) do
		if not new_run(way[1]) then break end
		before = #springs
		way[2]()
		lib.wait(0.5)
		lib.check(#springs == before + 1, "a " .. way[1] .. " across springs it")
		end_run()
	end
	lib.logf("springs %d, dust plays %d", #springs, dust)
end
