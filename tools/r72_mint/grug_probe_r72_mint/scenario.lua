-- The one scenario, on the real template with the pack rule on: a run at level 60 from
-- create to the chest, with the quest, the six jumps over the lake both ways by the real
-- client's own movement (run.sh presses the keys: a KEYS line), a fall into the lava and
-- the Return Home refusal there; then a run at 69, across the lake, its rooms and
-- Duewarden. Mobs are killed by the probe, Duewarden by the character's own hits, for
-- the kill credit.
local E = grug_expeditions
local QUEST, GIVER = "capital_last_mint", "r58_guild_leader_highcourt"
local FEET = 32
local HP = {[60] = {normal = 2696, elite = 8088, boss = 113232},
	[69] = {normal = 3507, elite = 10522, boss = 147308}}
-- Where the probe stands to wake a room, before the lake and after it.
local NEAR_ROOMS = {{"pack_a", 64, 104}, {"pack_b", 108, 104}}
local FAR_ROOMS = {{"pack_c", 108, 20}, {"pack_d", 64, 60}, {"boss", 64, 34}}
-- The tops in crossing order: the approach landing, five pillars, the exit landing (z).
local TOPS = {{76, 80}, {70, 74}, {64, 68}, {58, 62}, {52, 56}, {46, 50}, {40, 44}}
local CROSS_X = 107.5
-- One shot per room at eye height, facing what the room is about (Round 72 PROOF), at 60
-- once the room's pack is dead; the lake and the hall have their own.
local NEAR_TOUR = {{"arrival", 31, 106, 1.571}, {"bins", 50, 108, -1.768}, {"furnace", 96, 108, -2.034}}
-- The far rooms once Duewarden is dead too: no boss resets while the probe is away.
local FAR_TOUR = {{"store", 31, 20, 1.340}, {"cooling", 108, 30, math.pi}, {"vestibule", 80, 60, math.pi / 2}}

local function rel(run, x, y, z) return vector.add(run.minp, vector.new(x, y, z)) end
local function feet_at(run, x, z) return rel(run, x, FEET - 0.5, z) end

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
	player:set_pos(feet_at(run, x, z))
	if yaw then player:set_look_horizontal(yaw) end
	player:set_look_vertical(0.05)
end

local function shot(lib, name)
	lib.wait(3)
	lib.logf("BURST %s_%s", name, tostring(lib.tag))
	lib.wait(1)
end

local function tour(lib, player, run, rows)
	for _, row in ipairs(rows) do
		go(lib, player, run, row[2], row[3], row[4])
		shot(lib, row[1])
	end
end

-- Wakes the rooms, holds their mobs against the template and kills them, room by room.
local function prove_rooms(lib, player, run, level, rooms, tally)
	for _, row in ipairs(rooms) do
		go(lib, player, run, row[2], row[3])
		lib.wait(2.5)
		for _, ent in ipairs(mobs_in(run)) do
			local tier = ent._grug_boss_id and "boss" or ent._grug_tier
			lib.check(ent._grug_level == level, ("%s at level %s"):format(ent.name, tostring(ent._grug_level)))
			lib.check(ent.hp_max == HP[level][tier], ("%s %s HP %s"):format(ent.name, tier, tostring(ent.hp_max)))
			if tier ~= "boss" then
				tally[tier] = tally[tier] + 1
				tally.names[grug_mobs.tag_text and grug_mobs.tag_text(ent) or ent.description or "?"] = true
				ent.health = 0
				ent:check_for_death({type = "unknown"})
			end
		end
		lib.wait(1)
	end
end

local function report_rooms(lib, level, tally)
	local list = {}
	for name in pairs(tally.names) do list[#list + 1] = name end
	table.sort(list)
	lib.logf("rooms at level %d: %d normal, %d elite; tags %s", level, tally.normal, tally.elite,
		table.concat(list, " | "))
	lib.check(tally.normal == 16 and tally.elite == 3, "the template's counts")
end

-- One jump from top `from` to the next in `dir` (-1: across, +1: back): the character
-- stands 0.6 inside the edge, facing the gap; run.sh holds forward and taps jump.
local function jump(lib, player, run, from, dir)
	local top, target = TOPS[from], TOPS[from - dir]
	local edge = dir < 0 and top[1] - 0.5 or top[2] - 0.5
	go(lib, player, run, CROSS_X, edge - dir * 0.6, dir < 0 and math.pi or 0)
	lib.wait(0.8)
	lib.logf("KEYS jump %d %d", from, dir)
	lib.wait(2.6)
	local pos = player:get_pos()
	local z, y = pos.z - run.minp.z, pos.y - run.minp.y
	local landed = math.abs(y - (FEET - 0.5)) < 0.15 and z > target[1] - 0.8 and z < target[2] - 0.2
	lib.logf("JUMP from top %d %s: at z %.2f y %.2f, %s", from, dir < 0 and "across" or "back", z, y,
		landed and "on the next top" or "MISSED")
	lib.check(landed, ("the jump from top %d %s"):format(from, dir < 0 and "across" or "back"))
	return landed
end

local function cross(lib, player, run, back)
	local made = 0
	if back then
		for from = #TOPS, 2, -1 do
			if jump(lib, player, run, from, 1) then made = made + 1 end
		end
	else
		for from = 1, #TOPS - 1 do
			if jump(lib, player, run, from, -1) then made = made + 1 end
		end
	end
	return made
end

local function hit_boss(lib, player, run)
	local boss = assert(boss_of(run))
	local room = grug_mobs.expedition_boss_room(boss)
	lib.check(room and room.x0 == run.minp.x + 48 and room.z0 == run.minp.z + 8 and room.x1 == run.minp.x + 79
		and room.z1 == run.minp.z + 39, "Duewarden's room is the hall's envelope")
	lib.logf("boss %s: tier %s level %s HP %s/%s id %s tag %q", boss.name, tostring(boss._grug_tier),
		tostring(boss._grug_level), tostring(boss.health), tostring(boss.hp_max), tostring(boss._grug_boss_id),
		tostring(grug_mobs.tag_text(boss)))
	for _ = 1, 200 do
		if not boss.object:get_pos() then break end
		grug_core.deal_ability_damage(player, boss.object, 4000)
		lib.wait(0.1)
	end
	lib.wait(0.5)
	lib.check(boss_of(run) == nil, "Duewarden is dead")
end

local function open_chest(lib, player, run, level)
	local places = E.places(run)
	go(lib, player, run, 23, 23, math.pi / 2)
	lib.wait(1)
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(places.chest,
		core.get_node(places.chest), player, player:get_wielded_item())
	local inv = core.get_inventory({type = "detached", name = "grug_expedition_chest_" .. run.id .. "_" .. lib.NAME})
	lib.check(inv ~= nil, "a list of the player's own")
	local gear, bags, items = 0, 0, {}
	for _, stack in ipairs(inv and inv:get_list("main") or {}) do
		if not stack:is_empty() then
			local ilvl = stack:get_meta():get_int("grug_ilvl")
			if ilvl > 0 then
				gear = gear + 1
				lib.check(ilvl == level, "the gear's item level: " .. ilvl)
			elseif (grug_money.bag_amount(stack) or 0) > 0 then
				bags = bags + 1
				lib.logf("a Bag of Coins of %dc", grug_money.bag_amount(stack))
			else
				items[stack:get_name()] = stack:get_count()
			end
		end
	end
	lib.logf("chest at %d: %d gear, %d bag, Stone Core %s, Slime Gel %s", level, gear, bags,
		tostring(items["grug_mobs:stone_core"]), tostring(items["grug_mobs:slime_gel"]))
	lib.check(gear >= 1 and bags == 1 and items["grug_mobs:stone_core"] and items["grug_mobs:slime_gel"],
		"the chest pays")
	core.close_formspec(lib.NAME, "")
end

local function enter(lib, player, run)
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
end

local function create(lib, player, bonus)
	local run = assert(E.create(player, "last_mint", bonus))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.logf("ready after %.1f s, level %d, max players %d", (core.get_us_time() - t0) / 1e6, run.level,
		run.max_players)
	lib.check(run.state == "ready" and run.level == 60 + bonus, "ready at " .. (60 + bonus))
	return run
end

return function(lib, player)
	lib.keep_alive = player
	local hits, chat = {}, {}
	core.register_on_dieplayer(function(_, reason)
		lib.logf("DIED %s at %s", tostring(reason and reason.type), core.pos_to_string(player:get_pos(), 2))
	end)
	core.register_on_player_hpchange(function(_, change, reason)
		hits[#hits + 1] = {t = core.get_us_time(), change = change, type = reason.type,
			node = reason.node, object = reason.object, custom = reason.custom_type}
	end, false)
	local send = core.chat_send_player
	core.chat_send_player = function(name, text)
		if name == lib.NAME then
			chat[#chat + 1] = text
			lib.logf("CHAT %s", text)
		end
		return send(name, text)
	end
	local kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) kills[#kills + 1] = id end)
	local Q = grug_quests
	local offered = false
	for _, row in ipairs(E.list()) do offered = offered or row.id == "last_mint" end
	lib.check(offered, "the dialog offers The Last Mint")

	-- ---- Level 60: the whole way ----------------------------------------------------
	lib.tag = 60
	grug_xp.set_xp(player, grug_xp.xp_for_level(60))
	lib.check(Q.accept(player, QUEST, GIVER), "the leader gives the quest")
	local run = create(lib, player, 0)
	core.load_area(run.minp, run.maxp)
	local places = E.places(run)
	lib.check(core.get_node(places.door).name == "grug_expeditions:reward_door", "the door stands")
	local ore = #core.find_nodes_in_area(run.minp, run.maxp, "grug_materials:abyssal_crystal_ore")
	local gem = #core.find_nodes_in_area(run.minp, run.maxp, "grug_materials:stone_with_diamond")
	lib.logf("T6 places: %d Abyssal Crystal, %d Diamond", ore, gem)
	lib.check(ore == 5 and gem == 3, "five Abyssal Crystal and three Diamond")
	local lava = #core.find_nodes_in_area(run.minp, run.maxp, "default:lava_source")
	lib.check(lava == (24 * 32 - 5 * 16) * 6, "the lake's lava as written: " .. lava)
	lib.check(#mobs_in(run) == 0, "no mob before anyone enters")
	enter(lib, player, run)

	local tally = {normal = 0, elite = 0, names = {}}
	prove_rooms(lib, player, run, 60, NEAR_ROOMS, tally)
	-- A floor trap of the furnace room fires at the character.
	local armed = E.traps.chosen(run)
	local trap = armed.floor[1]
	for _, t in ipairs(armed.floor) do
		if t.group == "f1" then trap = t end
	end
	local before = #hits
	player:set_pos({x = trap.cell.x, y = trap.cell.y - 0.5, z = trap.cell.z})
	lib.wait(2.5)
	local trap_hits = 0
	for i = before + 1, #hits do
		if hits[i].type == "punch" and not hits[i].object and hits[i].change < 0 then trap_hits = trap_hits + 1 end
	end
	lib.logf("trap %s at %s: %d hit(s)", trap.group, core.pos_to_string(trap.cell), trap_hits)
	lib.check(trap_hits >= 1, "a floor trap hits the character")
	lib.check(core.get_node(trap.cell).name == "grug_expeditions:trap_mark", "its mark")

	tour(lib, player, run, NEAR_TOUR)

	-- The lake, from the approach landing, both ways.
	go(lib, player, run, CROSS_X, 78.5, math.pi)
	lib.wait(0.5)
	player:set_look_vertical(0.35)
	shot(lib, "lake")
	local across = cross(lib, player, run, false)
	local back = cross(lib, player, run, true)
	lib.logf("jumps at 60: %d of 6 across, %d of 6 back", across, back)

	-- A fall into the lava: five ticks, Return Home refused, a respawn at the start.
	lib.keep_alive = nil
	player:set_hp(player:get_properties().hp_max)
	lib.wait(0.5)
	local hp_max = player:get_properties().hp_max
	before = #hits
	go(lib, player, run, 100.5, 60)
	lib.wait_for(function() return player:get_pos().y < run.minp.y + 8 end, 6)
	lib.wait(0.3)
	lib.check(grug_home.return_home(player) == false, "Return Home is refused in the lava")
	lib.check(chat[#chat] == "Cannot return home from the lava.", "with its line: " .. tostring(chat[#chat]))
	lib.wait_for(function() return player:get_hp() <= 0 end, 10)
	local ticks, other = 0, 0
	for i = before + 1, #hits do
		if hits[i].type == "node_damage" then ticks = ticks + 1 elseif hits[i].change < 0 then other = other + 1 end
	end
	lib.logf("the lava: hp_max %d, %d ticks to death, %d other hits", hp_max, ticks, other)
	lib.check(player:get_hp() <= 0 and ticks + other <= 5 and ticks >= 4, "about five ticks kill a full pool")
	lib.wait(1)
	player:respawn()
	-- The client keeps builtin's death screen open after a respawn from the server: it hid
	-- the hall's shot in the lane's run (Round 72 PROOF).
	core.close_formspec(lib.NAME, "__builtin:death")
	lib.wait(3)
	lib.check(E.run_inside(player) == run and
		vector.distance(player:get_pos(), E.start_arrival(run)) < 2, "respawned at the start waystone")
	lib.keep_alive = player

	-- Over the lake by teleport, the far rooms, Duewarden, the chest, a Diamond.
	go(lib, player, run, CROSS_X, 41.5, 0)
	lib.wait(1)
	prove_rooms(lib, player, run, 60, FAR_ROOMS, tally)
	report_rooms(lib, 60, tally)
	lib.check(not E.rewards_open(run) and core.get_node(places.door).name == "grug_expeditions:reward_door",
		"sealed before the kill")
	go(lib, player, run, 64, 30, math.pi)
	shot(lib, "hall")
	hit_boss(lib, player, run)
	lib.check(#kills == 1 and kills[1] == "expedition:last_mint", "one credit, the stable id")
	lib.check(core.get_node(places.door).name == "air", "the door opened")
	lib.logf("quest status after the kill: %s", tostring(Q.status(player, QUEST)))
	open_chest(lib, player, run, 60)
	tour(lib, player, run, FAR_TOUR)
	local diamond = rel(run, 31, FEET + 1, 11)
	lib.check(core.get_node(diamond).name == "grug_materials:stone_with_diamond", "the store's Diamond")
	go(lib, player, run, 29, 11, -math.pi / 2)
	lib.wait(1)
	player:set_wielded_item(ItemStack("grug_materials:pick_abyssal_steel"))
	local function count(name)
		local total = 0
		for _, stack in ipairs(player:get_inventory():get_list("main")) do
			if stack:get_name() == name then total = total + stack:get_count() end
		end
		return total
	end
	local had = count("grug_materials:rough_diamond")
	local node = core.get_node(diamond)
	core.registered_nodes[node.name].on_dig(diamond, node, player)
	lib.check(core.get_node(diamond).name == "air" and count("grug_materials:rough_diamond") > had,
		"a Diamond dug by the ordinary path")
	local done = Q.turn_in(player, QUEST)
	lib.check(done, "the quest is turned in")
	E.leave(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	E.end_run(run, "probe")

	-- ---- Level 69: across the lake, the rooms and Duewarden ---------------------------
	lib.tag = 69
	local high = create(lib, player, 9)
	enter(lib, player, high)
	tally = {normal = 0, elite = 0, names = {}}
	prove_rooms(lib, player, high, 69, NEAR_ROOMS, tally)
	local across69 = cross(lib, player, high, false)
	lib.logf("jumps at 69: %d of 6 across", across69)
	prove_rooms(lib, player, high, 69, FAR_ROOMS, tally)
	report_rooms(lib, 69, tally)
	hit_boss(lib, player, high)
	lib.check(#kills == 2 and kills[2] == "expedition:last_mint", "the second credit")
	open_chest(lib, player, high, 69)
	lib.keep_alive = nil
end
