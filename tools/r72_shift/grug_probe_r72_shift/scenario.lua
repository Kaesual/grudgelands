-- The scenario: The Second Shift from the registrar to the chest at its first level, 40
-- (Round 72 lane SHIFT; Round 73 lane SHIFT, the redesign). The tier's ore and gem in the
-- template's places, the shift board, the mobs' counts, levels, HP and names over the
-- relief; a pack following into bay d's sunken pay floor and out of it; the armed ambush
-- crossed once and again; a floor trap and the wall trap at the character; Auditor
-- Nemm's marked spot, his reset when the character leaves his court, his kill credit; the
-- door, the chest by band, the tier's nodes dug; the lava as written; the critters. Mobs
-- are killed by the probe, Nemm by the character's own hit.
local E = grug_expeditions
local QUEST, GIVER = "capital_second_shift", "r58_guild_leader_highcourt"
-- Where the probe stands to wake a room. Nemm's court comes last, on its own: a pulled
-- boss is a pack of one, and the probe's set_pos (no travel, so no leaving) would let his
-- pack jump him after the character out of his room. Pack d is kept for the pit.
local ROOMS = {{"pack_a", 76, 20}, {"pack_b", 30, 20}, {"pack_c", 20, 66}, {"pack_d", 28, 92}}
-- One shot per place at eye height once every mob is dead: the store, the arrival, the
-- office, the marking floor with its lava fall, the wage hall's bays, the two drifts, the
-- court. Each: name, x, z, yaw.
local TOUR = {{"store", 97, 104, -1.571}, {"arrival", 108, 26, 3.031}, {"office", 76, 27, 2.428},
	{"marking", 30, 33, 1.0}, {"wage_c", 27, 66, 0.4}, {"wage_d", 29, 99, 0.9},
	{"grain_drift", 27, 42, 0}, {"pay_drift", 38, 106, math.pi}, {"court", 75, 108, 1.571}}
local T2_ORE, T2_GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
local BAND = {"grug_mobs:marching_bone", "grug_mobs:leathery_flesh"}
-- The ambush candidates: the zone's middle line and the walk across it (x or z), from
-- one side to the other.
local AMBUSH = {grain_drift = {axis = "z", at = 27.5, from = 45, to = 57},
	pay_drift = {axis = "z", at = 38.5, from = 99, to = 87}}

-- levels.lua's HP: the curve times the tier, rounded once; Nemm's factor on the elite's.
local function hp(level, mult) return math.floor((20 + 5 * level + 0.66 * level * level) * mult + 0.5) end
local function rel(run, x, y, z) return vector.add(run.minp, vector.new(x, y, z)) end

-- The floor's height at x, z (Round 73: a height map): the lowest row with a walkable
-- node below and two free rows.
local function floor_y(run, x, z)
	x, z = math.floor(x + 0.5), math.floor(z + 0.5)
	local function walkable(y)
		local def = core.registered_nodes[core.get_node(rel(run, x, y, z)).name]
		return not def or def.walkable ~= false
	end
	for y = 3, 24 do
		if walkable(y - 1) and not walkable(y) and not walkable(y + 1) then return y end
	end
	return 8
end

local function mobs_in(run, fn)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition and (not fn or fn(ent)) then out[#out + 1] = ent end
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
	player:set_pos(rel(run, x, floor_y(run, x, z) - 0.5, z))
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

local function kill(ent) ent.health = 0; ent:check_for_death({type = "unknown"}) end

-- Every lava node of the box with its param2, as one text: the written falls.
local function lava_digest(run)
	local list = core.find_nodes_in_area(run.minp, run.maxp, {"default:lava_source", "default:lava_flowing"})
	local rows = {}
	for _, pos in ipairs(list) do
		local node = core.get_node(pos)
		rows[#rows + 1] = core.pos_to_string(vector.subtract(pos, run.minp)) .. node.name:sub(14, 14) .. node.param2
	end
	table.sort(rows)
	return #list, table.concat(rows, ";")
end

local function one_run(lib, player, level, picks)
	lib.tag = level
	grug_xp.set_xp(player, grug_xp.xp_for_level(level))
	local tier = E.catalogue.tier_of(level)
	lib.logf("T%d at level %d, character %d", tier.tier, level, grug_xp.get_level(player))
	local ok, why = grug_quests.accept(player, QUEST, GIVER)
	lib.check(ok, "the guild leader gives the quest: " .. tostring(why))
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
	local lava_n, lava_written = lava_digest(run)
	lib.logf("LAVA at readiness: %d nodes", lava_n)
	local chosen = E.traps.chosen(run)
	local groups = {}
	for _, row in ipairs(chosen.floor) do groups[row.group] = (groups[row.group] or 0) + 1 end
	local armed = chosen.ambush[1]
	lib.logf("traps armed: f1 %s, f5 %s, f7 %s, f9 %s, wall at x %d, ambush %s of %d", tostring(groups.f1),
		tostring(groups.f5), tostring(groups.f7), tostring(groups.f9), chosen.wall[1].muzzle.x - run.minp.x,
		armed and armed.room or "-", #chosen.ambush)
	lib.check(groups.f1 == 2 and groups.f5 == 1 and groups.f7 == 1 and groups.f9 == 2 and #chosen.wall == 1 and
		#chosen.ambush == 1 and AMBUSH[armed.room] ~= nil, "the plan's traps and one ambush armed")
	lib.check(#mobs_in(run) == 0, "no mob before anyone enters")
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
	go(lib, player, run, 63, 13, math.pi)
	shot(lib, "board")

	-- The rooms in order: counts, levels, HP and names; a, b and c killed, d kept.
	local want_hp = {normal = hp(level, 1), elite = hp(level, 3), boss = math.floor(hp(level, 3) * 14 + 0.5)} -- Nemm x14 since Round 73 BOSSHP (was x20)
	local tally, names = {normal = 0, elite = 0}, {}
	local packd = {}
	for _, row in ipairs(ROOMS) do
		go(lib, player, run, row[2], row[3])
		lib.wait(2.5)
		for _, ent in ipairs(mobs_in(run, function(e) return not e._grug_scenery end)) do
			local kind = ent._grug_boss_id and "boss" or ent._grug_tier
			if not ent._grug_seen then
				ent._grug_seen = true
				lib.check(ent._grug_level == level, ("%s at level %s"):format(ent.name, tostring(ent._grug_level)))
				lib.check(ent.hp_max == want_hp[kind], ("%s %s HP %s, want %d"):format(ent.name, kind,
					tostring(ent.hp_max), want_hp[kind]))
				names[ent.name .. " " .. kind .. " " .. tostring(ent.description)] = true
				if kind ~= "boss" then tally[kind] = tally[kind] + 1 end
			end
			-- Pack d (its home in bay d, south of the screen) is placed with c's visit and
			-- kept for the pit; every other pack dies where it stands.
			local home = ent._grug_home
			if kind ~= "boss" then
				if home and home.z - run.minp.z >= 96 and home.x - run.minp.x <= 32 then
					if not ent._grug_kept then
						ent._grug_kept = true
						packd[#packd + 1] = ent
					end
				else
					kill(ent)
				end
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
	lib.check(names["grug_mobs:skeleton_raider normal Shift Raider"], "the raiders' name at " .. level)
	lib.check(names["grug_mobs:zombie elite Buried Miner"], "the elite miners' name")

	-- Pack d follows into bay d's sunken pay floor and out of it again, over its stairs.
	local function nearest(pos)
		local best, best_d
		for _, ent in ipairs(packd) do
			local p = ent.object:get_pos()
			if p then
				local d = vector.distance(p, pos)
				if not best_d or d < best_d then best, best_d = p, d end
			end
		end
		return best, best_d
	end
	local pit = {x = 16, z = 104}
	local pit_y = floor_y(run, pit.x, pit.z)
	lib.pin = rel(run, pit.x, pit_y - 0.5, pit.z)
	player:set_pos(lib.pin)
	local reached = lib.wait_for(function()
		local p, d = nearest(lib.pin)
		return p and d < 2.6 and p.y - run.minp.y < pit_y
	end, 12)
	local p = nearest(lib.pin)
	lib.logf("PIT down: floor %d, a mob at %s after %s s", pit_y, p and core.pos_to_string(vector.round(
		vector.subtract(p, run.minp))) or "-", tostring(reached))
	lib.check(reached ~= nil, "pack d follows the character into the pit")
	local rim = {x = 29, z = 99}
	local rim_y = floor_y(run, rim.x, rim.z)
	lib.pin = rel(run, rim.x, rim_y - 0.5, rim.z)
	player:set_pos(lib.pin)
	reached = lib.wait_for(function()
		local q, d = nearest(lib.pin)
		return q and d < 3 and q.y - run.minp.y > pit_y + 0.4
	end, 12)
	p = nearest(lib.pin)
	lib.logf("PIT up: rim %d, a mob at %s after %s s", rim_y, p and core.pos_to_string(vector.round(
		vector.subtract(p, run.minp))) or "-", tostring(reached))
	lib.check(reached ~= nil, "and out of it again")
	lib.pin = nil
	for _, ent in ipairs(packd) do if ent.object:get_pos() then kill(ent) end end
	lib.wait(1)
	lib.wait_for(function() return not grug_core.in_combat(player) end, 8)

	-- The armed ambush: a walk across springs it once; its miners come from the alcoves
	-- and take the character; killed, a second walk springs nothing.
	local way = AMBUSH[armed.room]
	local function walk_across(from, to)
		local s = from
		local dir = to > from and 1 or -1
		local last = core.get_us_time()
		lib.wait_for(function()
			local now = core.get_us_time()
			s = s + dir * 4 * (now - last) / 1e6
			last = now
			local x, z = way.at, s
			player:set_pos(rel(run, x, floor_y(run, x, z) - 0.5, z))
			return (to - s) * dir <= 0
		end, 10)
	end
	local function miners()
		return mobs_in(run, function(e) return e.name == "grug_mobs:zombie" and e.health > 0 end)
	end
	lib.check(#miners() == 0, "no miner waits in the dark before the ambush")
	go(lib, player, run, way.at, way.from, way.to > way.from and 0 or math.pi)
	lib.wait(0.5)
	walk_across(way.from, way.to)
	lib.wait(1)
	local fired = E.traps.chosen(run).ambush[1].fired
	local found = miners()
	local fighting = grug_core.in_combat(player)
	lib.logf("AMBUSH %s: fired %s, %d miners, in combat %s", armed.room, tostring(fired), #found, tostring(fighting))
	lib.check(fired and #found == 3 and fighting, "the ambush springs: three miners take the character")
	shot(lib, "ambush")
	for _, ent in ipairs(found) do kill(ent) end
	lib.wait(1)
	walk_across(way.to, way.from)
	lib.wait(1)
	lib.check(#miners() == 0, "crossing again spawns nothing")
	lib.wait_for(function() return not grug_core.in_combat(player) end, 8)

	-- A floor trap of room 2 at the character, then the wall's fireball in the gallery.
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

	-- Nemm on his sunken floor: HP and name; his marked spot; his reset when the
	-- character leaves the court; then his death.
	go(lib, player, run, 52, 98, -math.pi / 2)
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
	local bpos = boss.object:get_pos()
	lib.logf("Nemm: %d marks, %d marked hits %s, floor %d cells, at %s, health %s/%s", marks, #hits,
		#hits > 0 and hits[1].amount or "-", n, bpos and core.pos_to_string(vector.round(vector.subtract(bpos,
		run.minp))) or "-", tostring(boss.health), tostring(boss.hp_max))
	lib.check(marks >= 1 and #hits >= 1, "Nemm marks the character's spot and the hit falls there")
	lib.check(n > 0, "Nemm has his floor")
	-- Out of his court, beyond his reach (3 nodes) of its floor: the door's far side at
	-- x 86 (the envelope ends at x 79). Alone, the character resets him at once.
	go(lib, player, run, 86, 108, math.pi / 2)
	local reset = lib.wait_for(function()
		return boss.object:get_pos() and (boss.temp.grug_evading ~= nil or boss.attack ~= player)
	end, 8)
	local at = boss.object:get_pos()
	lib.logf("NEMM reset after %s s: evading %s, at %s", tostring(reset), tostring(boss.temp.grug_evading ~= nil),
		at and core.pos_to_string(vector.round(vector.subtract(at, run.minp))) or "-")
	lib.check(reset ~= nil, "Nemm resets when the character leaves his court")
	lib.wait_for(function() return not grug_core.in_combat(player) end, 10)
	go(lib, player, run, 75, 108, 1.571)
	shot(lib, "court")
	local kills = #lib.kills
	go(lib, player, run, 60, 104, -math.pi / 2)
	lib.wait(0.5)
	boss.health = 1
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(1)
	lib.check(#lib.kills == kills + 1 and lib.kills[#lib.kills] == "expedition:second_shift",
		"the kill credit at " .. level)
	lib.check(grug_quests.status(player, QUEST) == "ready", "the kill counts for the quest")
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
			else
				got[stack:get_name()] = stack:get_count()
			end
		end
	end
	lib.check(gear >= 1 and bags == 1, "gear and a bag")
	lib.check(got[BAND[1]] and got[BAND[2]], "the band's bone and flesh")
	shot(lib, "chest")
	core.close_formspec(lib.NAME, "")

	-- The tier's nodes, by a fitting pick; a weaker pick leaves them.
	local gem_y = floor_y(run, 118, 108) + 1
	local gem_pos = rel(run, 119, gem_y, 108)
	go(lib, player, run, 118, 108, -math.pi / 2)
	lib.wait(0.5)
	lib.check(not dig_with(player, gem_pos, picks.weak), "a weaker pick leaves the gem")
	local raw = grug_materials.resource_for_node(tier.gem).raw_item
	local had = count(player, raw)
	lib.check(dig_with(player, gem_pos, picks.fit) and count(player, raw) > had, "the gem dug: " .. raw)
	local ore_pos = rel(run, 119, floor_y(run, 118, 96) + 1, 96)
	go(lib, player, run, 118, 96, -math.pi / 2)
	lib.wait(0.5)
	local item = grug_materials.resource_for_node(tier.ore).raw_item
	had = count(player, item)
	lib.check(dig_with(player, ore_pos, picks.fit) and count(player, item) > had, "the ore dug: " .. item)
	local rock = vector.offset(ore_pos, 1, 0, 0)
	local hull = core.get_node(rock).name
	dig_with(player, rock, picks.fit)
	lib.check(core.get_node(rock).name == hull, "the hull behind it stands")

	-- The critters seen on the tour (an object far from the player is not active).
	local seen_critters, critters = {}, {}
	for _, row in ipairs(TOUR) do
		go(lib, player, run, row[2], row[3], row[4])
		shot(lib, row[1])
		for _, ent in ipairs(mobs_in(run, function(e) return e._grug_scenery end)) do
			if not seen_critters[ent] then
				seen_critters[ent] = true
				critters[#critters + 1] = ent
			end
		end
	end
	-- The lava as written after the whole run; the critters placed, none in a fight.
	local lava_now, lava_after = lava_digest(run)
	lib.logf("LAVA at the end: %d nodes, %s", lava_now, lava_after == lava_written and "as written" or "CHANGED")
	lib.check(lava_after == lava_written, "the lava falls stay as written")
	local kinds = {}
	for _, ent in ipairs(critters) do kinds[#kinds + 1] = ent.name:sub(11) end
	table.sort(kinds)
	lib.logf("CRITTERS %d: %s", #critters, table.concat(kinds, " "))
	lib.check(#critters == 5, "the five critters are there")

	local done, why2 = grug_quests.turn_in(player, QUEST)
	lib.logf("turn in: %s %s", tostring(done), tostring(why2))
	lib.check(done, "the quest is turned in")
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
	grug_core.get_dodge_chance = function() return 0 end
	local offered = false
	for _, row in ipairs(E.list()) do offered = offered or row.id == "second_shift" end
	lib.check(offered, "the dialog offers The Second Shift")
	one_run(lib, player, 40, {fit = "grug_materials:pick_silversteel", weak = "grug_materials:pick_steel"})
	lib.keep_alive = nil
end
