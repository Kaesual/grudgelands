-- Lane RANGE's scenario (run.sh with SCENARIO=range): The Stilled Seam at T4 (level 47,
-- the character at 47, with the quest) and T6 (level 65, the character at 60). Each run:
-- the tier's ore and gem in the template's places and no T2 node, the mobs' levels and
-- names, the boss's kill credit and the quest, the chest's item level and materials, and
-- the tier's nodes dug by a fitting pick while a weaker one leaves them.
local E = grug_expeditions
local QUEST, GIVER = "capital_stilled_seam", "r58_guild_leader_highcourt"
local FEET = 5
local ROOMS = {{"pack_a", 54, 20}, {"pack_b", 100, 20}, {"pack_c", 100, 66}, {"pack_d", 100, 98}, {"boss", 84, 108}}
local T2_ORE, T2_GEM = "default:stone_with_gold", "grug_materials:stone_with_jade"
-- Two ore places and one gem place of the store, each with a cell to stand on.
local ORE_AT, GEM_AT = {{31, 92, 29}, {31, 100, 29}}, {8, 108, 10}

local function rel(run, x, y, z) return vector.add(run.minp, vector.new(x, y, z)) end
local function feet(pos) return {x = pos.x, y = pos.y - 0.5, z = pos.z} end

local function mobs_in(run)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition then out[#out + 1] = ent end
	end
	return out
end

local function go(player, run, x, z, yaw)
	player:set_pos(feet(rel(run, x, FEET, z)))
	if yaw then player:set_look_horizontal(yaw) end
	player:set_look_vertical(0.05)
end

local function count(player, name)
	local total = 0
	for _, stack in ipairs(player:get_inventory():get_list("main")) do
		if stack:get_name() == name then total = total + stack:get_count() end
	end
	return total
end

-- Digs `pos` by the ordinary path with `pick`; true when the node went.
local function dig_with(player, pos, pick)
	player:set_wielded_item(ItemStack(pick))
	local node = core.get_node(pos)
	core.registered_nodes[node.name].on_dig(pos, node, player)
	return core.get_node(pos).name == "air"
end

local function one_run(lib, player, level, player_level, picks, quest)
	lib.tag = level
	grug_xp.set_xp(player, grug_xp.xp_for_level(player_level))
	local tier = E.catalogue.tier_of(level)
	lib.logf("T%d at level %d, character %d: ore %s, gem %s", tier.tier, level,
		grug_xp.get_level(player), tier.ore, tier.gem)
	if quest then
		local ok, why = grug_quests.accept(player, QUEST, GIVER)
		lib.check(ok, "the leader gives the quest at " .. player_level .. ": " .. tostring(why))
	end
	local run = assert(E.create(player, "stilled_seam", level - 20))
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.check(run.state == "ready" and run.level == level, "ready at level " .. level)
	core.load_area(run.minp, run.maxp)
	local ores = #core.find_nodes_in_area(run.minp, run.maxp, tier.ore)
	local gems = #core.find_nodes_in_area(run.minp, run.maxp, tier.gem)
	local old = #core.find_nodes_in_area(run.minp, run.maxp, {T2_ORE, T2_GEM})
	lib.logf("nodes in the box: %d %s, %d %s, %d of T2", ores, tier.ore, gems, tier.gem, old)
	if tier.ore == tier.gem then
		lib.check(ores == 8, "eight places of " .. tier.ore)
	else
		lib.check(ores == 5 and gems == 3, "five ore and three gem places of the tier")
	end
	lib.check(old == 0, "no T2 node left")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")

	-- The rooms: every mob at the run's level, its name, the normal ones killed.
	local names, boss = {}, nil
	for _, row in ipairs(ROOMS) do
		go(player, run, row[2], row[3])
		lib.wait(2.5)
		for _, ent in ipairs(mobs_in(run)) do
			lib.check(ent._grug_level == level, ("%s at level %s"):format(ent.name, tostring(ent._grug_level)))
			names[("%s %s %s hp %d"):format(ent.name, ent._grug_boss_id and "boss" or ent._grug_tier,
				tostring(ent.description), ent.hp_max or 0)] = true
			if ent._grug_boss_id then
				boss = ent
			else
				ent.health = 0
				ent:check_for_death({type = "unknown"})
			end
		end
		lib.wait(1)
	end
	local list = {}
	for line in pairs(names) do list[#list + 1] = line end
	table.sort(list)
	for _, line in ipairs(list) do lib.logf("mob at %d: %s", level, line) end
	lib.check(boss ~= nil and boss.description == "Flintback", "Flintback by name at " .. level)

	-- The kill by the character's own hit, for the ledger and the quest.
	local kills = #lib.kills
	go(player, run, 76, 108, -math.pi / 2)
	lib.wait(0.5)
	boss.health = 1
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(1)
	lib.check(#lib.kills == kills + 1 and lib.kills[#lib.kills] == "expedition:stilled_seam",
		"the kill credit at " .. level)
	if quest then
		lib.logf("quest status after the kill at %d: %s", level, tostring(grug_quests.status(player, QUEST)))
		lib.check(grug_quests.status(player, QUEST) == "ready", "the kill at " .. level .. " counts for the quest")
	end
	lib.check(E.rewards_open(run), "the reward room opens")

	-- The chest: its gear at the run's level, its materials.
	go(player, run, 23, 108, math.pi / 2)
	lib.wait(1)
	local chest = E.places(run).chest
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(chest, core.get_node(chest), player,
		player:get_wielded_item())
	local inv = core.get_inventory({type = "detached", name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME})
	local gear = 0
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then
			local ilvl = stack:get_meta():get_int("grug_ilvl")
			lib.logf("chest at %d: %s x%d ilvl %d", level, stack:get_name(), stack:get_count(), ilvl)
			if ilvl > 0 then
				gear = gear + 1
				lib.check(ilvl == level, "the gear's item level " .. ilvl)
			end
			lib.check(not stack:get_name():find("lump") and not stack:get_name():find("rough_") and
				not stack:get_name():find("crystal"), "no ore, no gem: " .. stack:get_name())
		end
	end
	lib.check(gear >= 1, "gear in the chest")
	core.close_formspec(lib.NAME, "")
	-- The store's east wall with two ore places, for the user's eyes.
	go(player, run, 24, 96, -math.pi / 2)
	lib.wait(3)
	lib.logf("BURST store_%d", level)
	lib.wait(1)

	-- The tier's nodes by a fitting pick; a weaker pick leaves them.
	local gem_pos = rel(run, GEM_AT[1], FEET + 1, GEM_AT[2])
	go(player, run, GEM_AT[3], GEM_AT[2], math.pi / 2)
	lib.wait(0.5)
	lib.check(not dig_with(player, gem_pos, picks.weak), "a weaker pick leaves the gem (" .. picks.weak .. ")")
	local raw = grug_materials.resource_for_node(tier.gem).raw_item
	local before = count(player, raw)
	lib.check(dig_with(player, gem_pos, picks.fit), "the gem dug with " .. picks.fit)
	lib.check(count(player, raw) > before, "its " .. raw .. " in the bags")
	for _, spot in ipairs(ORE_AT) do
		local pos = rel(run, spot[1], FEET + 1, spot[2])
		go(player, run, spot[3], spot[2], -math.pi / 2)
		lib.wait(0.5)
		local item = grug_materials.resource_for_node(tier.ore).raw_item
		local had = count(player, item)
		lib.check(core.get_node(pos).name == tier.ore, "the tier's ore at " .. spot[1] .. "," .. spot[2])
		lib.check(dig_with(player, pos, picks.fit) and count(player, item) > had, "the ore dug: " .. item)
		local rock = vector.offset(pos, 1, 0, 0)
		local hull = core.get_node(rock).name
		dig_with(player, rock, picks.fit)
		lib.check(core.get_node(rock).name == hull, "the hull behind it stands")
	end
	E.use_waystone(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	E.end_run(run, "probe")
end

return function(lib, player)
	lib.keep_alive = player
	lib.kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) lib.kills[#lib.kills + 1] = id end)
	-- T4's nodes need the T4 pick: Steel (T3) is refused. T6's Diamond needs T6.
	one_run(lib, player, 47, 47, {fit = "grug_materials:pick_silversteel", weak = "grug_materials:pick_steel"}, true)
	one_run(lib, player, 65, 60, {fit = "grug_materials:pick_abyssal_steel",
		weak = "grug_materials:pick_embersteel"}, false)
	lib.keep_alive = nil
end
