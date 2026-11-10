-- The one scenario of Round 73 lane MINT, on the real template with every rule on: a run
-- at level 60 from create to the chest over the redesigned floor. Its questions (plan
-- section 6, wave2-common.md "Engine run"): a pack follows into the bins' sunken floor and
-- out of it again over the stairs; the armed ambush springs once when its zone is crossed
-- and its pack takes the player at once, the other stays quiet; Duewarden walks his arena's
-- relief and resets when the party leaves his hall; the written lava falls stay as written;
-- the critters are there. Round 72's lake jumps, lava death and the level 69 run are
-- unchanged code and template there and are not repeated (Round 72's evidence). Mobs are
-- killed by the probe, Duewarden by the character's own hits, for the kill credit. A
-- `BURST <name>` line is run.sh's cue for a screenshot.
local E = grug_expeditions
local QUEST, GIVER = "capital_last_mint", "r58_guild_leader_highcourt"
local HP = {normal = 2696, elite = 8088, boss = 113232}
-- Yaw: 0 looks toward +z, pi / 2 toward -x (the GAME probe's convention).
local PLUS_Z, MINUS_X, MINUS_Z, PLUS_X = 0, math.pi / 2, math.pi, 3 * math.pi / 2
-- The rooms the probe wakes and clears after the bins, in route order: where it stands.
local ROOMS = {{"pack_b", 108, 103}, {"pack_c", 108, 20}, {"pack_d", 64, 60}}
-- The ambush candidates (template lines `ambush`): the zone's walk, from, to, across.
local CROSS = {ambush_flue = {axis = "x", from = 75, to = 87, at = 86},
	ambush_drift = {axis = "z", from = 31, to = 45, at = 88}}

local function rel(run, x, y, z) return vector.add(run.minp, vector.new(x, y, z)) end

local function mobs_in(run, filter)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition and (not filter or filter(ent)) then out[#out + 1] = ent end
	end
	return out
end

local function boss_of(run)
	return mobs_in(run, function(e) return e._grug_boss_id ~= nil end)[1]
end

return function(lib, player)
	lib.keep_alive = player
	local springs = {}
	local spring_room = E._spring_room
	E._spring_room = function(run, room, p)
		springs[#springs + 1] = room
		lib.logf("SPRING room %s at %s", room, core.pos_to_string(vector.subtract(p:get_pos(), run.minp), 1))
		return spring_room(run, room, p)
	end
	local kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) kills[#kills + 1] = id end)
	local run
	-- The floor's feet at a cell: the first air over the floor, read from the world.
	local function feet(x, z)
		for y = 26, 40 do
			local below = core.registered_nodes[core.get_node(rel(run, x, y - 1, z)).name]
			local here = core.get_node(rel(run, x, y, z)).name
			if below and below.walkable ~= false and here == "air" then return y end
		end
		return 32
	end
	local function go(x, z, yaw, pitch)
		lib.check(player:get_hp() > 0, "the character lives")
		player:set_pos(rel(run, x, feet(x, z) - 0.49, z))
		if yaw then
			player:set_look_horizontal(yaw)
			player:set_look_vertical(pitch or 0.05)
		end
	end
	local function shot(name)
		lib.wait(3)
		lib.logf("BURST %s", name)
		lib.wait(1)
	end
	local function kill(filter)
		local n = 0
		for _, ent in ipairs(mobs_in(run, filter)) do
			if not ent._grug_scenery and not ent._grug_boss_id then
				local tier = ent._grug_tier
				lib.check(ent._grug_level == 60 and ent.hp_max == HP[tier],
					("%s %s at 60, HP %s"):format(ent.name, tostring(tier), tostring(ent.hp_max)))
				ent.health = 0
				ent:check_for_death({type = "unknown"})
				n = n + 1
			end
		end
		return n
	end
	local function lava_cells()
		local n = #core.find_nodes_in_area(rel(run, 0, 20, 0), rel(run, 127, 45, 127),
			{"default:lava_source", "default:lava_flowing"})
		return n
	end

	grug_xp.set_xp(player, grug_xp.xp_for_level(60))
	lib.check(grug_quests.accept(player, QUEST, GIVER), "the leader gives the quest")
	run = assert(E.create(player, "last_mint", 0))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.logf("ready after %.1f s", (core.get_us_time() - t0) / 1e6)
	lib.check(run.state == "ready", "ready at 60")
	core.load_area(run.minp, run.maxp)
	local falls = lava_cells()
	lib.logf("LAVA in the falls as written: %d cells", falls)
	lib.check(falls == 41, "the three falls' 41 lava cells")
	local armed = E.traps.chosen(run).ambush
	lib.check(#armed == 1, "one ambush armed of two: " .. #armed)
	lib.logf("armed: %s", armed[1] and armed[1].room or "-")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
	lib.wait(2)
	go(12, 106, PLUS_X, 0.1)
	shot("arrival")

	-- ---- 1. The bins: a pack follows into the sunken floor and out of it -------------
	-- A Seep's object stands half a node over its feet: 29.5 on the pit's floor (y 29),
	-- 31.5 on the rim, 32.5 in the passage north of the room.
	go(63, 104, MINUS_X)
	local low, diver = 99, nil
	lib.wait_for(function()
		for _, ent in ipairs(mobs_in(run, function(e) return e.name == "grug_mobs:lava_flan" end)) do
			local p = ent.object:get_pos()
			if p and p.y - run.minp.y < low then low, diver = p.y - run.minp.y, ent end
		end
		return low < 29.6
	end, 12)
	lib.logf("PIT: the lowest Seep at y %.2f (the pit's floor is 29)", low)
	lib.check(low < 29.6, "a Seep came down the stairs into the pit")
	go(70, 87, MINUS_Z)
	local high = -99
	lib.wait_for(function()
		local p = diver and diver.object:get_pos()
		if p then high = math.max(high, p.y - run.minp.y) end
		return high > 32.4
	end, 15)
	lib.logf("OUT: that Seep climbed to y %.2f", high)
	lib.check(high > 32.4, "and climbed out of the pit after the player, into the passage")
	lib.wait(1)
	lib.logf("killed %d of pack a", kill())
	go(55, 104, PLUS_X, 0.15)
	shot("bins_pit")

	-- ---- 2. The ambush ----------------------------------------------------------------
	local function cross(room)
		local c = CROSS[room]
		local function at(v)
			if c.axis == "x" then return v, c.at end
			return c.at, v
		end
		local x, z = at(c.from)
		go(x, z, c.axis == "x" and PLUS_X or PLUS_Z, 0)
		lib.wait(0.5)
		local v = c.from
		while v < c.to do
			v = v + 0.25
			x, z = at(v)
			player:set_pos(rel(run, x, feet(math.floor(x + 0.5), math.floor(z + 0.5)) - 0.49, z))
			lib.wait(0.06)
		end
	end
	local other = armed[1].room == "ambush_flue" and "ambush_drift" or "ambush_flue"
	cross(other)
	lib.wait(1)
	lib.check(#springs == 0, "the unarmed candidate stays quiet: " .. other)
	go(72, 86, PLUS_X, 0)
	shot("flue_dark")
	cross(armed[1].room)
	lib.wait(0.2)
	lib.logf("BURST ambush")
	lib.wait(1.5)
	local ambush = mobs_in(run, function(e) return e._grug_pack and e.name == "grug_mobs:lava_flan" end)
	lib.check(#springs == 1 and springs[1] == armed[1].room, "the armed candidate springs once")
	lib.check(#ambush == 3, "its three Seeps in the alcoves: " .. #ambush)
	lib.check(grug_core.in_combat(player), "and they take the player at once")
	lib.logf("killed %d of the ambush", kill())
	cross(armed[1].room)
	lib.wait(1)
	lib.check(#springs == 1, "crossing again springs nothing")

	-- ---- 3. The rooms after the bins ----------------------------------------------------
	for _, row in ipairs(ROOMS) do
		go(row[2], row[3])
		lib.wait(2.5)
		lib.logf("%s: killed %d", row[1], kill())
		lib.wait(1)
	end
	go(108, 104, PLUS_Z, 0.1)
	shot("furnace_fall")
	go(88, 26, PLUS_Z, 0)
	shot("drift_dark")
	local critters = mobs_in(run, function(e) return e._grug_scenery end)
	lib.logf("CRITTERS %d placed", #critters)
	lib.check(#critters >= 3, "the critters are there: " .. #critters)

	-- ---- 4. Duewarden on his arena's relief; the reset when the party leaves -------------
	go(64, 36, MINUS_Z, 0.1)
	shot("hall")
	-- He waits on the arena's floor (y 30); the character stands on its rim (y 32).
	local boss = assert(boss_of(run))
	local home = boss.object:get_pos()
	go(64, 35)
	grug_core.deal_ability_damage(player, boss.object, 4000)
	local lo, hi = 99, -99
	lib.wait_for(function()
		local p = boss.object:get_pos()
		if p then lo, hi = math.min(lo, p.y - run.minp.y), math.max(hi, p.y - run.minp.y) end
		return hi > lo + 1.6
	end, 12)
	lib.logf("BOSS moved from y %.2f, its feet between %.2f and %.2f", home.y - run.minp.y, lo, hi)
	lib.check(hi > lo + 0.9, "Duewarden climbs his arena's stairs after the player")
	go(64, 44)
	lib.wait_for(function() return boss.health == boss.hp_max end, 6)
	lib.wait(4)
	local back = boss.object:get_pos()
	lib.logf("RESET: HP %s/%s, %.1f from home", tostring(boss.health), tostring(boss.hp_max),
		back and vector.distance(back, home) or -1)
	lib.check(boss.health == boss.hp_max, "a player who leaves the hall resets him")
	go(64, 31)
	for _ = 1, 250 do
		if not boss.object:get_pos() then break end
		grug_core.deal_ability_damage(player, boss.object, 4000)
		lib.wait(0.1)
	end
	lib.wait(0.5)
	lib.check(boss_of(run) == nil and #kills == 1, "Duewarden is dead, one credit")
	local places = E.places(run)
	lib.check(core.get_node(places.door).name == "air", "the door opened")

	-- ---- 5. The chest, the lava, the end ------------------------------------------------
	go(23, 23, MINUS_X, 0.3)
	lib.wait(1)
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(places.chest,
		core.get_node(places.chest), player, player:get_wielded_item())
	local inv = core.get_inventory({type = "detached", name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME})
	local filled = 0
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then filled = filled + 1 end
	end
	lib.check(filled >= 3, "the chest pays: " .. filled .. " stacks")
	core.close_formspec(lib.NAME, "")
	lib.logf("LAVA in the falls after the run: %d cells", lava_cells())
	lib.check(lava_cells() == falls, "the falls stay as written")
	lib.check(grug_quests.turn_in(player, QUEST), "the quest is turned in")
	lib.keep_alive = nil
	E.leave(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	E.end_run(run, "probe")
end
