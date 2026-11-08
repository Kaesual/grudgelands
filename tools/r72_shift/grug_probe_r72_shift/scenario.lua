-- The scenario: The Second Shift from the registrar to the chest at its first and last
-- level, 40 (the character at 40, with the quest) and 69 (the character at 60). Each
-- run: the tier's ore and gem in the template's places, the shift board, the mobs'
-- counts, levels, HP and names, a floor trap and the wall trap at the character, Auditor
-- Nemm's marked spot, his kill credit, the door, the chest by band and the tier's
-- nodes dug. Mobs are killed by the probe, Nemm by the character's own hit.
local E = grug_expeditions
local QUEST, GIVER = "capital_second_shift", "r58_guild_leader_highcourt"
local FEET = 8
-- Where the probe stands to wake a room. Nemm's court comes last, on its own: a pulled
-- boss is a pack of one, and the probe's set_pos (no travel, so no leaving) would let his
-- pack jump him after the character out of his room.
local ROOMS = {{"pack_a", 76, 20}, {"pack_b", 30, 20}, {"pack_c", 20, 66}, {"pack_d", 28, 92}}
local T2_ORE, T2_GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
local NAMES = {[40] = "Shift Raider", [69] = "Overdue Raider"}
local BAND = {[40] = {"grug_mobs:marching_bone", "grug_mobs:leathery_flesh"},
	[69] = {"grug_mobs:unquiet_bone", "grug_mobs:salt_cured_flesh"}}

-- levels.lua's HP: the curve times the tier, rounded once; Nemm's factor on the elite's.
local function hp(level, mult) return math.floor((20 + 5 * level + 0.66 * level * level) * mult + 0.5) end
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

local function go(lib, player, run, x, z, yaw)
	lib.check(player:get_hp() > 0, "the character lives")
	player:set_pos(feet(rel(run, x, FEET, z)))
	if yaw then player:set_look_horizontal(yaw) end
	player:set_look_vertical(0.05)
end

local function shot(lib, name)
	lib.wait(3)
	lib.logf("BURST %s_%s", name, tostring(lib.tag))
	lib.wait(1)
end

local function count(player, name)
	local total = 0
	for _, stack in ipairs(player:get_inventory():get_list("main")) do
		if stack:get_name() == name then total = total + stack:get_count() end
	end
	return total
end

local function dig_with(player, pos, pick)
	player:set_wielded_item(ItemStack(pick))
	local node = core.get_node(pos)
	core.registered_nodes[node.name].on_dig(pos, node, player)
	return core.get_node(pos).name == "air"
end

-- The hits a trap or a strike dealt the character since `since` (no puncher, armor applied).
local function trap_hits(lib, since)
	local out = {}
	for i = since + 1, #lib.hits do out[#out + 1] = lib.hits[i] end
	return out
end

local function one_run(lib, player, level, player_level, picks, quest)
	lib.tag = level
	grug_xp.set_xp(player, grug_xp.xp_for_level(player_level))
	local tier = E.catalogue.tier_of(level)
	lib.logf("T%d at level %d, character %d", tier.tier, level, grug_xp.get_level(player))
	if quest then
		local ok, why = grug_quests.accept(player, QUEST, GIVER)
		lib.check(ok, "the guild leader gives the quest: " .. tostring(why))
	end
	local run = assert(E.create(player, "second_shift", level - 40))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.logf("ready after %.1f s, level %d, max players %d", (core.get_us_time() - t0) / 1e6, run.level,
		run.max_players)
	lib.check(run.state == "ready" and run.level == level and run.max_players == 4, "ready at level " .. level)
	core.load_area(run.minp, run.maxp)
	local places = E.places(run)
	local ores = #core.find_nodes_in_area(run.minp, run.maxp, tier.ore)
	local gems = #core.find_nodes_in_area(run.minp, run.maxp, tier.gem)
	local old = #core.find_nodes_in_area(run.minp, run.maxp, {T2_ORE, T2_GEM})
	lib.logf("nodes in the box: %d %s, %d %s, %d of T2", ores, tier.ore, gems, tier.gem, old)
	lib.check(ores == 5 and gems == 3 and old == 0, "five ore and three gem places of the tier, no T2 node")
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door stands")
	local board = places.shift_board
	lib.check(core.get_meta(board):get_string("text") == "SECOND SHIFT\nSAME NAMES\nSTILL DUE", "the shift board")
	local text_entities = 0
	for _, object in ipairs(core.get_objects_inside_radius(board, 1)) do
		local ent = object:get_luaentity()
		if ent and ent.name == "grug_text:text" then text_entities = text_entities + 1 end
	end
	lib.check(text_entities == 1, "the board's text shows: " .. text_entities)
	local chosen = E.traps.chosen(run)
	local groups = {}
	for _, row in ipairs(chosen.floor) do groups[row.group] = (groups[row.group] or 0) + 1 end
	lib.logf("traps armed: f1 %s, f5 %s, f7 %s, f9 %s, wall at x %d", tostring(groups.f1), tostring(groups.f5),
		tostring(groups.f7), tostring(groups.f9), chosen.wall[1].muzzle.x - run.minp.x)
	lib.check(groups.f1 == 2 and groups.f5 == 1 and groups.f7 == 1 and groups.f9 == 2 and #chosen.wall == 1,
		"the plan's traps armed")
	lib.check(#mobs_in(run) == 0, "no mob before anyone enters")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")

	if level == 40 then
		go(lib, player, run, 63, 14, math.pi)
		shot(lib, "board")
	end

	-- The rooms in order: counts, levels, HP and names; the normal ones killed.
	local want_hp = {normal = hp(level, 1), elite = hp(level, 3), boss = math.floor(hp(level, 3) * 20 + 0.5)}
	local tally, names = {normal = 0, elite = 0}, {}
	for _, row in ipairs(ROOMS) do
		go(lib, player, run, row[2], row[3])
		lib.wait(2.5)
		for _, ent in ipairs(mobs_in(run)) do
			local kind = ent._grug_boss_id and "boss" or ent._grug_tier
			lib.check(ent._grug_level == level, ("%s at level %s"):format(ent.name, tostring(ent._grug_level)))
			lib.check(ent.hp_max == want_hp[kind], ("%s %s HP %s, want %d"):format(ent.name, kind,
				tostring(ent.hp_max), want_hp[kind]))
			names[ent.name .. " " .. kind .. " " .. tostring(ent.description)] = true
			if kind ~= "boss" then
				tally[kind] = tally[kind] + 1
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
	lib.check(tally.normal == 14 and tally.elite == 3, ("fourteen normal, three elite: %d, %d"):format(
		tally.normal, tally.elite))
	lib.check(names["grug_mobs:skeleton_raider normal " .. NAMES[level]], "the raiders' name at " .. level)
	lib.check(names["grug_mobs:zombie elite Buried Miner"], "the elite miners' name")
	-- A floor trap of room 2 at the character, then the wall's fireball in the passage.
	local trap
	for _, row in ipairs(chosen.floor) do
		if row.group == "f1" then trap = row end
	end
	local before = #lib.hits
	lib.pin = {x = trap.cell.x, y = trap.cell.y - 0.5, z = trap.cell.z}
	player:set_pos(lib.pin)
	lib.wait(2.2)
	lib.pin = nil
	local hits = trap_hits(lib, before)
	lib.logf("floor trap at %s: %d hits %s", core.pos_to_string(vector.subtract(trap.cell, run.minp)), #hits,
		#hits > 0 and hits[1].amount or "-")
	lib.check(#hits == 1, "the floor trap hits the character once")
	local wall = chosen.wall[1].muzzle
	go(lib, player, run, wall.x - run.minp.x, 20, 0)
	before = #lib.hits
	lib.wait(8.5)
	hits = trap_hits(lib, before)
	lib.logf("wall trap at x %d: %d hits %s", wall.x - run.minp.x, #hits, #hits > 0 and hits[1].amount or "-")
	lib.check(#hits >= 1, "the fireball bursts on the character")
	go(lib, player, run, 40, 20)
	lib.wait(1)

	-- Nemm: his HP and name; his marked spot falls where the character stands, his floor
	-- is the court.
	go(lib, player, run, 50, 98, -math.pi / 2)
	lib.wait(2.5)
	local boss = boss_of(run)
	lib.check(boss ~= nil and boss.description == "Auditor Nemm" and boss._grug_tier == "elite" and
		boss._grug_level == level and boss.hp_max == want_hp.boss, ("Auditor Nemm, an elite at %d, HP %s"):format(
		level, tostring(boss and boss.hp_max)))
	local marks = 0
	local mark = grug_mobs.expedition_mark
	grug_mobs.expedition_mark = function(self, pos)
		marks = marks + 1
		lib.logf("Nemm marks %s", core.pos_to_string(vector.subtract(pos, run.minp), 1))
		return mark(self, pos)
	end
	go(lib, player, run, 58, 104, -math.pi / 2)
	lib.pin = player:get_pos()
	before = #lib.hits
	lib.wait(15)
	lib.pin = nil
	hits = trap_hits(lib, before)
	grug_mobs.expedition_mark = mark
	local cells = grug_mobs.boss_floor_of(boss)
	local n = 0
	for _ in pairs(cells or {}) do n = n + 1 end
	lib.logf("Nemm: %d marks, %d marked hits %s, floor %d cells, health %s/%s", marks, #hits,
		#hits > 0 and hits[1].amount or "-", n, tostring(boss.health), tostring(boss.hp_max))
	lib.check(marks >= 1 and #hits >= 1, "Nemm marks the character's spot and the hit falls there")
	lib.check(n > 0, "Nemm has his floor")
	if level == 40 then
		go(lib, player, run, 50, 98, -math.pi / 2)
		shot(lib, "court")
	end
	lib.logf("Nemm at %s, evading %s", core.pos_to_string(vector.subtract(vector.round(boss.object:get_pos()),
		run.minp)), tostring(boss.temp and boss.temp.grug_evading ~= nil))
	local kills = #lib.kills
	go(lib, player, run, 60, 104, -math.pi / 2)
	lib.wait(0.5)
	boss.health = 1
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(1)
	lib.check(#lib.kills == kills + 1 and lib.kills[#lib.kills] == "expedition:second_shift",
		"the kill credit at " .. level)
	if quest then
		lib.check(grug_quests.status(player, QUEST) == "ready", "the kill counts for the quest")
	end
	lib.check(E.rewards_open(run) and core.get_node(places.door).name == "air", "the reward room opens")

	-- The chest: gear at the run's level, a bag, the band's bone and flesh, no ore.
	go(lib, player, run, 105, 104, -math.pi / 2)
	lib.wait(1)
	local chest = places.chest
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(chest, core.get_node(chest), player,
		player:get_wielded_item())
	local inv = core.get_inventory({type = "detached", name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME})
	local gear, bags, got = 0, 0, {}
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then
			local ilvl = stack:get_meta():get_int("grug_ilvl")
			lib.logf("chest at %d: %s x%d ilvl %d", level, stack:get_name(), stack:get_count(), ilvl)
			if ilvl > 0 then
				gear = gear + 1
				lib.check(ilvl == level, "the gear's item level " .. ilvl)
			elseif (grug_money.bag_amount(stack) or 0) > 0 then
				bags = bags + 1
				lib.logf("a Bag of Coins of %dc", grug_money.bag_amount(stack))
			else
				got[stack:get_name()] = stack:get_count()
			end
		end
	end
	lib.check(gear >= 1 and bags == 1, "gear and a bag")
	lib.check(got[BAND[level][1]] and got[BAND[level][2]], "the band's bone and flesh")
	if level == 40 then shot(lib, "chest") end
	core.close_formspec(lib.NAME, "")

	-- The tier's nodes, by a fitting pick; a weaker pick leaves them.
	local gem_pos = rel(run, 119, FEET + 1, 108)
	go(lib, player, run, 118, 108, -math.pi / 2)
	lib.wait(0.5)
	lib.check(not dig_with(player, gem_pos, picks.weak), "a weaker pick leaves the gem")
	local raw = grug_materials.resource_for_node(tier.gem).raw_item
	local had = count(player, raw)
	lib.check(dig_with(player, gem_pos, picks.fit) and count(player, raw) > had, "the gem dug: " .. raw)
	local ore_pos = rel(run, 119, FEET + 1, 96)
	go(lib, player, run, 118, 96, -math.pi / 2)
	lib.wait(0.5)
	local item = grug_materials.resource_for_node(tier.ore).raw_item
	had = count(player, item)
	lib.check(dig_with(player, ore_pos, picks.fit) and count(player, item) > had, "the ore dug: " .. item)
	local rock = vector.offset(ore_pos, 1, 0, 0)
	local hull = core.get_node(rock).name
	dig_with(player, rock, picks.fit)
	lib.check(core.get_node(rock).name == hull, "the hull behind it stands")

	if quest then
		local done, why = grug_quests.turn_in(player, QUEST)
		lib.logf("turn in: %s %s", tostring(done), tostring(why))
		lib.check(done, "the quest is turned in")
	end
	E.leave(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.check(E.run_inside(player) == nil, "the way out")
	E.end_run(run, "probe")
end

return function(lib, player)
	lib.keep_alive = player
	lib.kills, lib.hits = {}, {}
	grug_mobs.register_on_boss_kill(function(_, id) lib.kills[#lib.kills + 1] = id end)
	core.register_on_player_hpchange(function(_, change, reason)
		if change < 0 and reason.type == "punch" and not reason.object then
			lib.hits[#lib.hits + 1] = {amount = -change, at = core.get_us_time()}
		end
	end, false)
	-- No dodge in the probe: each trap and mark must land once (a dodged hit changes no HP).
	lib.logf("the character's dodge chance at %d: %.3f", grug_xp.get_level(player),
		grug_core.get_dodge_chance(player))
	grug_core.get_dodge_chance = function() return 0 end
	local offered = false
	for _, row in ipairs(E.list()) do offered = offered or row.id == "second_shift" end
	lib.check(offered, "the dialog offers The Second Shift")
	one_run(lib, player, 40, 40, {fit = "grug_materials:pick_silversteel", weak = "grug_materials:pick_steel"}, true)
	one_run(lib, player, 69, 60, {fit = "grug_materials:pick_abyssal_steel",
		weak = "grug_materials:pick_embersteel"}, false)
	lib.keep_alive = nil
end
