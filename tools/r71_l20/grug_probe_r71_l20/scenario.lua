-- The one scenario, on the real template with the pack rule on: a run at level 20 from
-- create to the store, with the quest, and the rooms again at level 29. A pulled pack
-- follows the probe's teleports by its jumps, as it follows a runner. Mobs are killed
-- by the probe; the boss by the character's own hits, for the kill credit.
local E = grug_expeditions
local QUEST, GIVER = "capital_stilled_seam", "r58_guild_leader_highcourt"
local FEET = 5
local HP = {[20] = {normal = 384, elite = 1152, boss = 13824}, [29] = {normal = 720, elite = 2160, boss = 25920}}
-- Where the probe stands to wake a room.
local ROOMS = {{"pack_a", 54, 20}, {"pack_b", 100, 20}, {"pack_c", 100, 66}, {"pack_d", 100, 98}, {"boss", 84, 108}}

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

local function boss_of(run)
	for _, ent in ipairs(mobs_in(run)) do
		if ent._grug_boss_id then return ent end
	end
end

-- What a failure needs: the character's state, and where its pack's mobs stand.
local function status(lib, player, run, label)
	local at, near, stacked = player:get_pos(), 0, 0
	for _, ent in ipairs(mobs_in(run)) do
		local pos = ent.object:get_pos()
		if vector.distance(pos, at) <= 16 then near = near + 1 end
		if math.abs(pos.x - at.x) < 0.6 and math.abs(pos.z - at.z) < 0.6 then stacked = stacked + 1 end
	end
	lib.logf("%s: hp %d at %s, inside %s, in combat %s, %d mobs within 16, %d on the player's cell",
		label, player:get_hp(), core.pos_to_string(at, 2), tostring(E.run_inside(player) == run),
		tostring(grug_core.in_combat(player)), near, stacked)
end

local function go(lib, player, run, x, z, yaw)
	status(lib, player, run, "leaving for " .. x .. "," .. z)
	lib.check(player:get_hp() > 0, "the character lives")
	player:set_pos(feet(rel(run, x, FEET, z)))
	if yaw then player:set_look_horizontal(yaw) end
	player:set_look_vertical(0.05)
end

local function shot(lib, player, name)
	lib.wait(4)
	lib.logf("BURST %s_%s", name, tostring(lib.tag))
	lib.wait(1)
end

-- Wakes the rooms in order, holds their mobs against the document and kills them,
-- room by room: objects_in_area sees only active mobs, so the far rooms come to it
-- one at a time.
local function prove_rooms(lib, player, run, level)
	local tally, names = {normal = 0, elite = 0}, {}
	for _, row in ipairs(ROOMS) do
		go(lib, player, run, row[2], row[3])
		lib.wait(2.5)
		for _, ent in ipairs(mobs_in(run)) do
			local tier = ent._grug_boss_id and "boss" or ent._grug_tier
			lib.check(ent._grug_level == level, ("%s at level %s"):format(ent.name, tostring(ent._grug_level)))
			lib.check(ent.hp_max == HP[level][tier], ("%s HP %s"):format(ent.name, tostring(ent.hp_max)))
			if tier ~= "boss" then
				tally[tier] = tally[tier] + 1
				names[ent.description or "?"] = true
				ent.health = 0
				ent:check_for_death({type = "unknown"})
			end
		end
		lib.wait(1)
	end
	local list = {}
	for name in pairs(names) do list[#list + 1] = name end
	table.sort(list)
	lib.logf("rooms at level %d: %d normal, %d elite, names %s", level, tally.normal, tally.elite,
		table.concat(list, ", "))
	lib.check(tally.normal == 12 and tally.elite == 3, "the document's counts")
	lib.check(boss_of(run) ~= nil, "Flintback stands alone")
end

-- How far mobs walk on their own while the party stands apart. A mob that went for
-- the probe's character stops counting.
local function prove_wander(lib, player, run, x, z, seconds)
	go(lib, player, run, x, z)
	lib.wait(2)
	local rows = {}
	for _, ent in ipairs(mobs_in(run)) do
		rows[#rows + 1] = {ent = ent, from = ent.object:get_pos(), far = 0}
	end
	local t0 = core.get_us_time()
	while core.get_us_time() - t0 < seconds * 1e6 do
		for _, row in ipairs(rows) do
			local at = row.ent.object:get_pos()
			if row.ent.state == "attack" or row.ent.attack then row.fought = true end
			if at and not row.fought then row.far = math.max(row.far, vector.distance(at, row.from)) end
		end
		lib.wait(0.5)
	end
	local idle, far = 0, 0
	for _, row in ipairs(rows) do
		if not row.fought then
			idle = idle + 1
			far = math.max(far, row.far)
		end
	end
	lib.logf("wander near %d,%d: %d mobs, %d stayed idle, furthest of those %.1f nodes in %d s", x, z,
		#rows, idle, far, seconds)
	return far
end

local function open_chest(lib, player, run, level)
	local places = E.places(run)
	go(lib, player, run, 23, 108, math.pi / 2)
	lib.wait(1)
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(places.chest,
		core.get_node(places.chest), player, player:get_wielded_item())
	local name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME
	local inv = core.get_inventory({type = "detached", name = name})
	lib.check(inv ~= nil, "a list of the player's own")
	local gear, bags, items = 0, 0, 0
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then
			local ilvl = stack:get_meta():get_int("grug_ilvl")
			lib.logf("chest level %d: %s x%d ilvl %d", level, stack:get_name(), stack:get_count(), ilvl)
			if ilvl > 0 then
				gear = gear + 1
				lib.check(ilvl == level, "the gear's item level: " .. ilvl)
			elseif (grug_money.bag_amount(stack) or 0) > 0 then
				bags = bags + 1
				lib.logf("a Bag of Coins of %dc", grug_money.bag_amount(stack))
			else
				items = items + 1
				lib.check(not stack:get_name():find("lump") and not stack:get_name():find("rough_"),
					"no ore, no gem: " .. stack:get_name())
			end
		end
	end
	lib.check(gear >= 1 and bags == 1 and items >= 1, ("the chest pays: %d gear, %d bag, %d stacks"):format(gear, bags, items))
	shot(lib, player, "chest")
	core.close_formspec(lib.NAME, "")
end

local function hit_boss(lib, player, run)
	local boss = assert(boss_of(run))
	status(lib, player, run, "to the boss")
	lib.logf("boss %s: name %q tier %s level %s HP %s/%s id %s tag %q", boss.name, tostring(boss.description),
		tostring(boss._grug_tier), tostring(boss._grug_level), tostring(boss.health), tostring(boss.hp_max),
		tostring(boss._grug_boss_id), tostring(grug_mobs.tag_text(boss)))
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(0.5)
	lib.check(boss.health < boss.hp_max, "the boss is hurt")
	-- A punch's damage is 16 bits, after the player's own scale: small hits.
	for _ = 1, 30 do
		if not boss.object:get_pos() then break end
		grug_core.deal_ability_damage(player, boss.object, 2000)
		lib.wait(0.2)
	end
	lib.wait(0.5)
	lib.check(boss_of(run) == nil, "the boss is dead")
end

return function(lib, player)
	lib.keep_alive = player
	core.register_on_dieplayer(function(_, reason)
		lib.logf("DIED %s %s", tostring(reason and reason.type), core.pos_to_string(player:get_pos(), 2))
	end)
	core.register_on_player_hpchange(function(_, change, reason)
		if reason.type == "fall" then lib.logf("FALL %d", change) end
	end, false)
	local kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) kills[#kills + 1] = id end)
	local Q = grug_quests
	lib.check(#E.list() == 1 and E.list()[1].id == "stilled_seam", "the dialog offers The Stilled Seam")

	-- Level 20: the whole way.
	lib.tag = 20
	grug_xp.set_xp(player, grug_xp.xp_for_level(20))
	lib.check(Q.accept(player, QUEST, GIVER), "the leader gives the quest")
	local run = assert(E.create(player, "stilled_seam", 0))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.logf("ready after %.1f s, level %d, max players %d", (core.get_us_time() - t0) / 1e6, run.level,
		run.max_players)
	lib.check(run.state == "ready" and run.level == 20, "ready at level 20")
	core.load_area(run.minp, run.maxp)
	local places = E.places(run)
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door stands")
	lib.check(#core.find_nodes_in_area(run.minp, run.maxp, "default:stone_with_gold") == 5, "five Gold")
	lib.check(#core.find_nodes_in_area(run.minp, run.maxp, "grug_materials:stone_with_jade") == 3, "three Jade")
	lib.check(#mobs_in(run) == 0, "no mob before anyone enters")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
	lib.logf("arrival %s; start %s", core.pos_to_string(vector.round(player:get_pos())),
		core.pos_to_string(E.start_arrival(run)))

	-- The look of each room, from its door, mobs asleep at the far end.
	go(lib, player, run, 20, 12, 0)
	shot(lib, player, "room0")
	go(lib, player, run, 50, 20, -math.pi / 2)
	shot(lib, player, "room1")
	go(lib, player, run, 98, 30, -math.pi / 2)
	shot(lib, player, "room2")
	local a = prove_wander(lib, player, run, 108, 52, 30)
	go(lib, player, run, 108, 66, math.pi)
	shot(lib, player, "room3")
	local b = prove_wander(lib, player, run, 88, 108, 30)
	go(lib, player, run, 50, 108, -math.pi / 2)
	shot(lib, player, "room4")
	lib.logf("wander, furthest: %.1f / %.1f nodes", a, b)
	prove_rooms(lib, player, run, 20)

	lib.check(not E.rewards_open(run), "the chest is sealed before the kill")
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door still stands")
	lib.check(Q.status(player, QUEST) ~= "complete", "the quest waits for Flintback")
	hit_boss(lib, player, run)
	lib.logf("kill credit %s", table.concat(kills, " "))
	lib.check(#kills == 1 and kills[1] == "expedition:stilled_seam", "one credit, the stable id")
	lib.logf("quest status after the kill: %s", tostring(Q.status(player, QUEST)))
	lib.check(core.get_node(places.door).name == "air" and
		#core.find_nodes_in_area(run.minp, run.maxp, "grug_expeditions:reward_door") == 0, "the door opened")
	go(lib, player, run, 30, 108, -math.pi / 2)
	shot(lib, player, "room5")
	open_chest(lib, player, run, 20)

	-- A marked Gold node by the ordinary path.
	local gold = rel(run, 31, FEET + 1, 92)
	lib.check(core.get_node(gold).name == "default:stone_with_gold", "the Gold of the store")
	go(lib, player, run, 29, 92, -math.pi / 2)
	lib.wait(1)
	player:set_wielded_item(ItemStack("grug_materials:pick_steel"))
	local node = core.get_node(gold)
	local function count(name)
		local total = 0
		for _, stack in ipairs(player:get_inventory():get_list("main")) do
			if stack:get_name() == name then total = total + stack:get_count() end
		end
		return total
	end
	local lumps = count("default:gold_lump")
	core.registered_nodes[node.name].on_dig(gold, node, player)
	lib.check(core.get_node(gold).name == "air", "a marked node is dug")
	lib.check(count("default:gold_lump") > lumps, "its Gold in the bags: " .. count("default:gold_lump"))
	local rock = rel(run, 32, FEET + 1, 92)
	node = core.get_node(rock)
	core.registered_nodes[node.name].on_dig(rock, node, player)
	lib.check(core.get_node(rock).name == node.name, "the hull behind it stands")

	-- The quest, turned in at its giver.
	local xp, copper = grug_xp.get_xp(player), grug_money.get(player)
	local done, why = Q.turn_in(player, QUEST)
	lib.logf("turn in: %s %s; XP +%d, copper +%d", tostring(done), tostring(why),
		grug_xp.get_xp(player) - xp, grug_money.get(player) - copper)
	lib.check(done, "the quest is turned in")
	lib.check(Q.status(player, QUEST) == "done" or Q.quest_held(player, QUEST), "done once")
	E.use_waystone(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.check(E.run_inside(player) == nil, "the end waystone leads out")
	E.end_run(run, "probe")

	-- Level 29: the same rooms at +9.
	lib.tag = 29
	grug_xp.set_xp(player, grug_xp.xp_for_level(29))
	local high = assert(E.create(player, "stilled_seam", 9))
	lib.wait_for(function() return high.state == "ready" end, 120)
	lib.check(high.state == "ready" and high.level == 29, "ready at level 29")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == high end, 40)
	lib.check(E.run_inside(player) == high, "inside at level 29")
	prove_rooms(lib, player, high, 29)
	hit_boss(lib, player, high)
	lib.check(#kills == 2 and kills[2] == "expedition:stilled_seam", "the second credit")
	lib.check(Q.status(player, QUEST) ~= "ready", "the quest is done once, the Expedition repeats")
	open_chest(lib, player, high, 29)
	lib.keep_alive = nil
end
