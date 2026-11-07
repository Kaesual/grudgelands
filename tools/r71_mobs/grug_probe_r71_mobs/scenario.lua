-- The one scenario, on test_vault at +9 (level 29), with mob_active_limit = 1 and a
-- short block unload (run.sh): rooms, levels, survival of an unload, drops, the
-- boss, door, chest, the end of the run.
local E = grug_expeditions

local function mobs_in(run)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition then out[#out + 1] = ent end
	end
	return out
end

local function boss_of(run)
	for _, ent in ipairs(mobs_in(run)) do
		if ent._grug_boss_id then return ent end
	end
end

local function describe(lib, ent)
	lib.logf("mob %s name=%s level %s tier %s hp %s/%s lifetimer %s authored %s", ent.name,
		tostring(ent.description), tostring(ent._grug_level), tostring(ent._grug_tier),
		tostring(ent.health), tostring(ent.hp_max), tostring(ent.lifetimer),
		tostring(ent._grug_authored))
end

local function kill_silently(ent)
	ent.health = 0
	ent:check_for_death({type = "unknown"})
end

local function back_in(lib, player, run)
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
end

local function out(lib, player, run)
	core.registered_nodes["grug_expeditions:waystone"].on_rightclick(run.places.start_waystone,
		{name = "grug_expeditions:waystone"}, player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.check(E.run_inside(player) == nil, "left through the waystone")
end

return function(lib, player)
	lib.logf("mob_active_limit %s active %d unload timeout %s",
		tostring(core.settings:get("mob_active_limit")), mobs:get_active_mob_count(),
		tostring(core.settings:get("server_unload_unused_data_timeout")))
	grug_xp.set_xp(player, grug_xp.xp_for_level(27))
	local kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) kills[#kills + 1] = id end)

	local run = assert(E.create(player, "test_vault", 9))
	lib.wait_for(function() return run.state == "ready" end, 90)
	lib.check(run.state == "ready" and run.level == 29, "ready at level 29")
	local places = E.places(run)
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door stands")
	lib.check(core.get_node(places.chest).name == "grug_expeditions:reward_chest", "the chest stands")
	lib.check(core.get_meta(places.chest):get_string("infotext") == "Reward Chest", "its hover text")
	lib.check(#mobs_in(run) == 0, "no mob before anyone enters")

	lib.wait_for(function() return mobs:get_active_mob_count() >= 1 end, 60)
	lib.logf("at the limit: active %d", mobs:get_active_mob_count())
	back_in(lib, player, run)
	lib.wait(3)
	local mobs_now = mobs_in(run)
	lib.check(#mobs_now == 4, "four mobs, the boss too, at mob_active_limit 1: " .. #mobs_now)
	for _, ent in ipairs(mobs_now) do
		describe(lib, ent)
		lib.check(ent._grug_level == 29, "level 29")
		lib.check(ent._grug_expedition == run.id, "the run's id")
	end
	local boss = assert(boss_of(run))
	lib.check(boss._grug_tier == "elite", "the boss is an elite: " .. tostring(boss._grug_boss_id))

	-- What dies stays dead; the living wait through an unload of their block.
	for _, ent in ipairs(mobs_now) do
		if not ent._grug_boss_id and ent._grug_tier == "normal" then
			kill_silently(ent)
			break
		end
	end
	lib.wait(2)
	lib.check(#mobs_in(run) == 3, "three left")
	out(lib, player, run)
	local cell = E.encounters(run)[1].pos
	local gone = lib.wait_for(function() return core.get_node_or_nil(cell) == nil end, 60)
	lib.logf("the block unloaded after %s s, live objects in the box %d", tostring(gone), #mobs_in(run))
	lib.check(gone ~= nil and #mobs_in(run) == 0, "nothing live in an unloaded box")
	back_in(lib, player, run)
	lib.wait_for(function() return #mobs_in(run) >= 3 end, 20)
	lib.wait(3)
	mobs_now = mobs_in(run)
	lib.check(#mobs_now == 3, "the living came back, the dead did not: " .. #mobs_now)
	for _, ent in ipairs(mobs_now) do
		describe(lib, ent)
		lib.check(ent._grug_level == 29 and ent._grug_expedition == run.id, "kept level and run")
	end

	-- Drops.
	boss = assert(boss_of(run)) -- the old reference went with the unload
	local function test_mob(name, level, expedition)
		local object = core.add_entity(boss.object:get_pos(), name, core.serialize({
			_grug_spawn_level = level, _grug_expedition = expedition,
			_grug_authored = true})) -- without it the limit of 1 refuses the test mob
		local ent = object:get_luaentity()
		grug_mobs.ensure_init(ent)
		return ent
	end
	local golem = test_mob("grug_mobs:stone_golem", 29, run.id)
	golem._grug_player_tag = {name = lib.NAME, until_t = core.get_gametime() + 60}
	local names = {}
	for _, row in ipairs(grug_mobs._item_drop_filter(golem, core.registered_entities[golem.name].drops or {})) do
		names[#names + 1] = row.name
	end
	-- Both of the golem's rows are ore or gem: nothing stays.
	lib.check(#names == 0, "a golem's rows: " .. table.concat(names, " "))
	golem.object:remove()
	local function ilvls(ent)
		local seen = {}
		for index = 1, 300 do
			for _, stack in ipairs(grug_items.roll_mob_gear(ent, index * 7919)) do
				local level = stack:get_meta():get_int("grug_ilvl")
				if level > 0 then seen[level] = true end
			end
		end
		return dump(seen):gsub("%s+", " ")
	end
	local deep = test_mob("grug_mobs:giant_spider", 65, run.id)
	deep._grug_tier = "elite"
	lib.logf("level 65 Expedition mob item levels %s", ilvls(deep))
	local plain = test_mob("grug_mobs:giant_spider", 65, nil)
	plain._grug_tier = "elite"
	lib.logf("level 65 other mob item levels %s", ilvls(plain))
	deep.object:remove()
	plain.object:remove()

	-- A wipe: the boss heals and stands, the rest of the run is untouched.
	boss = assert(boss_of(run))
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(1)
	lib.logf("boss after a hit %s/%s", tostring(boss.health), tostring(boss.hp_max))
	lib.check(boss.health < boss.hp_max, "the boss is hurt")
	grug_mobs.leash_reset(boss)
	lib.logf("after the reset %s/%s, mobs %d, state %s, evading %s", tostring(boss.health),
		tostring(boss.hp_max), #mobs_in(run), run.state, tostring(boss.temp.grug_evading))
	lib.check(boss.health == boss.hp_max, "evading healed it")
	lib.check(#mobs_in(run) == 3 and run.state == "running", "the run goes on, its dead stay dead")
	lib.check(not E.rewards_open(run), "the chest stays shut")
	lib.wait(1)

	-- The kill, a real player's.
	local before = {}
	for index, stack in ipairs(player:get_inventory():get_list("main")) do
		before[index] = stack:to_string()
	end
	boss = assert(boss_of(run))
	local pos_of_boss = vector.round(boss.object:get_pos())
	player:set_pos({x = pos_of_boss.x, y = pos_of_boss.y + 2, z = pos_of_boss.z - 4})
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(0.5)
	grug_core.deal_ability_damage(player, boss.object, 1000000)
	lib.wait(1)
	lib.check(boss_of(run) == nil, "the boss is dead")
	lib.logf("kill credit %s", table.concat(kills, " "))
	lib.check(#kills == 1 and kills[1] == "expedition:test_vault", "one credit, the stable id")
	lib.check(player:get_meta():get_int("grug_boss_lockout:expedition:test_vault:" .. run.id) == 0 and
		player:get_meta():get_int("grug_boss_lockout:expedition:test_vault") == 0, "no lockout")
	local same = true
	for index, stack in ipairs(player:get_inventory():get_list("main")) do
		same = same and before[index] == stack:to_string()
	end
	lib.check(same, "no direct reward in the inventory")
	local ground = 0
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent.name == "__builtin:item" then
			ground = ground + 1
			lib.logf("on the ground %s at %s", ent.itemstring, core.pos_to_string(object:get_pos()))
		end
	end
	lib.logf("items on the ground %d", ground)
	lib.check(ground == 0, "the boss dropped nothing")
	lib.check(core.get_node(places.door).name == "air" and
		#core.find_nodes_in_area(run.minp, run.maxp, "grug_expeditions:reward_door") == 0, "the door opened")

	-- The chest.
	lib.check(E.rewards_open(run), "the chest is open")
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(places.chest,
		core.get_node(places.chest), player, player:get_wielded_item())
	local name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME
	local inv = core.get_inventory({type = "detached", name = name})
	lib.check(inv ~= nil, "a list of the player's own")
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then
			lib.logf("chest %s ilvl %d", stack:get_name(), stack:get_meta():get_int("grug_ilvl"))
		end
	end
	lib.log("BURST chest 3")
	lib.wait(4)
	core.close_formspec(lib.NAME, "")

	-- The end of the run.
	E.end_run(run, "probe")
	lib.check(core.get_inventory({type = "detached", name = name}) == nil, "the list ended with the run")
	lib.wait(1)
	local left = 0
	for object in core.objects_in_area(run.minp, run.maxp) do
		if not object:is_player() then left = left + 1 end
	end
	lib.check(left == 0, "nothing live stays in the box: " .. left)
	local second = assert(E.create(player, "test_vault", 0))
	lib.wait_for(function() return second.state == "ready" end, 90)
	lib.check(second.state == "ready" and #mobs_in(second) == 0, "a new run finds no mob of the old one")
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door stands again")
end
