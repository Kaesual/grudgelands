-- Disposable engine probe (Round 28 Lane B4). Never shipped:
-- tools/r28_b4_quests/run.sh stages it through tools/luanti_headless.sh.
--
-- After every mod loaded (the boot itself proves the zone files pass the
-- load-time validation against the real registries) it checks:
--   1. a sample new-format zone file through the real loader: a new giver
--      at Highcourt's free quest socket, a quest with a kill, an item group
--      and a quest-only drop, a repeatable, a travel quest;
--   2. the sample played end to end by a player stand-in (a headless server
--      has no client): accept, kill credit, quest drop into the inventory,
--      turn-in with the weight reward, the repeatable's cooldown, travel
--      credit on accept;
--   3. the load-time world checks against the shipped Dawnmere recipe (level
--      fit, role in area).
-- It logs what the shipped zone files register (quests, objectives, rewards).

local P = "[r28_quests_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then core.log("error", P .. "FAIL " .. msg) end
	end
	return ok
end
local function eq(got, want, msg)
	return check(got == want, msg .. " (got " .. tostring(got) .. ", expected " .. tostring(want) .. ")")
end

-- What the shipped zone files register (a log line, no check).
local function summary(Q)
	local registered, objectives, kills, items, talks, xp, copper = 0, 0, 0, 0, 0, 0, 0
	for _, def in pairs(Q.registered_quests) do
		registered = registered + 1
		for _, objective in ipairs(def.objectives) do
			objectives = objectives + 1
			if objective.type == "kill" then kills = kills + 1
			elseif objective.type == "item" then items = items + 1 else talks = talks + 1 end
		end
		xp, copper = xp + grug_quests.reward_xp(def), copper + def.rewards.copper
	end
	local files = 0
	for _ in pairs(Q.quest_files) do files = files + 1 end
	log(("registry: %d quests from %d zone files; objectives: %d (kill %d, item %d, talk %d); " ..
		"rewards: %d XP, %d copper in total"):format(registered, files, objectives, kills, items, talks, xp, copper))
end

-- A sample zone file in the Round 28 format (frame 4.7).
local SAMPLE = {
	name = "elandor_highcourt.quests.json", zone = "elandor_highcourt", front = false,
	data = {
		zone = "elandor_highcourt",
		hubs = {{id = "probe_hub", anchor = "highcourt", givers = {
			{npc = "probe_lore_keeper", new = {name = "Probe Lorekeep", race = "dwarf",
				socket = "lore_shrine/lore_shrine_quest"}, lines = {"probe", "bounties"}}}}},
		quests = {
			{id = "probe_supplies", line = "probe", giver = "probe_lore_keeper", turnin = "probe_lore_keeper",
				min_level = 20, level = 22, title = "Probe Supplies",
				text = "Boars and logs for the shrine. The boars carry the stolen purses.",
				objectives = {
					{type = "kill", roles = {"boar"}, count = 2},
					{type = "item", group = "group:tree", count = 2},
					{type = "item", item = "grug_mobs:stolen_purse", count = 1},
				},
				quest_drops = {{item = "grug_mobs:stolen_purse", roles = {"boar"}, chance = 1}},
				rewards = {weight = 3, copper = 7, items = {{item = "mobs:meat_raw", count = 2}}}},
			{id = "probe_bounty", line = "bounties", giver = "probe_lore_keeper", turnin = "probe_lore_keeper",
				min_level = 20, level = 22, requires = {"probe_supplies"}, title = "Probe Bounty",
				text = "Boars again. Come back after a minute.",
				objectives = {{type = "kill", roles = {"boar"}, count = 1}},
				repeatable = {cooldown = 60}, rewards = {weight = 1, copper = 1}},
			{id = "probe_travel", line = "probe", giver = "probe_lore_keeper",
				turnin = "r20_human_capital_envoy", min_level = 20, level = 22, title = "Probe Travel",
				text = "Walk to the chapel. Mariel expects you.",
				objectives = {{type = "talk", npc = "r20_human_capital_envoy"}},
				rewards = {weight = 1, copper = 1}},
		},
	},
}

local function sample(Q)
	local ok, err = pcall(Q.load_quest_files, {SAMPLE})
	if not check(ok, "sample file loads: " .. tostring(err)) then return end
	ok, err = pcall(Q.validate_quest_data, {SAMPLE})
	check(ok, "sample passes the world checks: " .. tostring(err))
	local keeper = Q.registered_npcs.probe_lore_keeper
	check(keeper and keeper.settlement == "highcourt" and keeper.socket == "lore_shrine/lore_shrine_quest",
		"new giver bound to Highcourt's free quest socket")
	eq(grug_mobs.quest_socket_title("highcourt", "lore_shrine/lore_shrine_quest"), "Probe Lorekeep",
		"the quest shell at that socket takes the new giver's name")
	-- A broken sample is refused with the file and quest named.
	local broken = table.copy(SAMPLE)
	broken.data = table.copy(SAMPLE.data)
	broken.data.hubs = {}
	broken.data.quests = {{id = "probe_turkey", line = "probe", giver = "r20_human_capital_envoy",
		turnin = "r20_human_capital_envoy", min_level = 1, level = 1, title = "T", text = "T. T.",
		objectives = {{type = "kill", roles = {"wild_turkey"}, count = 1}}, rewards = {weight = 1}}}
	local found = Q.validate.world({broken}, {
		entity = function(name) return core.registered_entities[name] end,
		disposition = function(name) return grug_mobs.disposition(name) end,
		role_levels = function() return nil end, leader = function() return nil end,
		area = function() return nil end, zone_areas = function() return {} end,
		item = function() return true end, group = function() return true end})
	check(found[1] and found[1]:find("zones/elandor_highcourt.quests.json: quest probe_turkey", 1, true)
		and found[1]:find("E-critter-target", 1, true), "critter target refused: " .. tostring(found[1]))
	log("sample load error example: " .. tostring(found[1]))
end

local function play(Q)
	local name = "probe_b4"
	local inv = core.create_detached_inventory("probe_b4_inventory", {})
	inv:set_size("main", 32)
	local meta = {}
	local player = {}
	function player:get_player_name() return name end
	function player:is_player() return true end
	function player:get_hp() return 20 end
	function player:get_pos() return vector.new(0, 0, -1500) end
	function player:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function player:get_inventory() return inv end
	local granted, paid, fed = {}, 0, {}
	local saved = {grug_xp.get_level, grug_xp.add_xp, grug_money.add, grug_money.get,
		grug_factions.get_faction, grug_classes.get_race, core.get_player_by_name, grug_core.feed_item}
	grug_xp.get_level = function() return 22 end
	grug_xp.add_xp = function(_, amount, source) granted[#granted + 1] = amount .. " " .. source end
	grug_money.add = function(_, copper) paid = paid + copper end
	grug_money.get = function() return paid end
	grug_factions.get_faction = function() return "accord" end
	grug_classes.get_race = function() return "human" end
	core.get_player_by_name = function(who) if who == name then return player end return saved[7](who) end
	grug_core.feed_item = function(_, stack) fed[#fed + 1] = ItemStack(stack):get_name() end
	local ok, err = pcall(function()
		local boar = {name = "grug_mobs:boar", object = {is_player = function() return false end,
			get_luaentity = function() return nil end}}
		local at = vector.new(0, 0, -1500)
		check(Q.accept(player, "probe_supplies"), "accept the sample quest")
		local row = Q.journal(player).quests[1]
		local line = Q.hud_line(row, 400)
		eq(line, "Boar 0/2, Any Tree 0/2, Stolen Purse 0/1", "compact HUD line")
		Q.credit_kill(player, boar, at)
		Q.roll_quest_drops(boar, {name}, at)
		Q.credit_kill(player, boar, at)
		Q.roll_quest_drops(boar, {name}, at)
		eq(inv:contains_item("main", "grug_mobs:stolen_purse 2"), false, "one purse only: the quest needs one")
		eq(inv:contains_item("main", "grug_mobs:stolen_purse"), true, "quest drop in the inventory")
		eq(fed[1], "grug_mobs:stolen_purse", "feed line for the drop")
		inv:add_item("main", "default:tree")
		inv:add_item("main", "default:pine_tree")
		eq(Q.status(player, "probe_supplies"), "ready", "kills, group and drop complete the quest")
		check(Q.turn_in(player, "probe_supplies"), "turn in")
		eq(granted[1], grug_xp.quest_reward(22, 3) .. " quest", "weight reward through grug_xp.quest_reward")
		log("sample reward: " .. tostring(granted[1]) .. " (weight 3 at level 22), " .. paid .. " copper")
		eq(inv:contains_item("main", "default:tree") or inv:contains_item("main", "default:pine_tree"), false,
			"logs taken")
		eq(inv:contains_item("main", "mobs:meat_raw 2"), true, "reward items delivered")
		local clock = Q.clock
		local now = clock()
		Q.clock = function() return now end
		check(Q.accept(player, "probe_bounty"), "accept the repeatable")
		Q.credit_kill(player, boar, at)
		check(Q.turn_in(player, "probe_bounty"), "turn in the repeatable")
		local status, reason = Q.status(player, "probe_bounty")
		eq(status, "locked", "repeatable cools down")
		log("repeatable after turn-in: " .. status .. " (" .. tostring(reason) .. ")")
		Q.clock = function() return now + 60 end
		eq(Q.status(player, "probe_bounty"), "available", "repeatable available after its cooldown")
		Q.clock = clock
		check(Q.accept(player, "probe_travel"), "accept the travel quest")
		local travel
		for _, quest in ipairs(Q.journal(player).quests) do if quest.id == "probe_travel" then travel = quest end end
		check(travel and travel.ready, "travel credited on accept")
		eq(travel and Q.hud_line(travel, 400), "Travel to Mariel Waybook", "travel HUD line")
		eq(Q.marker_states(player).r20_human_capital_envoy, "ready", "destination shows the turn-in at once")
	end)
	grug_xp.get_level, grug_xp.add_xp, grug_money.add, grug_money.get, grug_factions.get_faction,
		grug_classes.get_race, core.get_player_by_name, grug_core.feed_item = unpack(saved)
	check(ok, "play: " .. tostring(err))
end

-- The load-time world checks against the shipped Dawnmere spawn recipe (Lane
-- S1): an area a quest names is a kind or a camp of its zone's recipe.
local function area_checks(Q)
	local function file(level, role)
		return {name = "elandor_dawnmere_fields.quests.json", zone = "elandor_dawnmere_fields", front = false,
			data = {zone = "elandor_dawnmere_fields", quests = {{id = "probe_area", line = "hunt",
				giver = "r14_human_elder", turnin = "r14_human_elder", min_level = 1, level = level,
				title = "Probe Area", text = "Boars. In the home fields.",
				objectives = {{type = "kill", roles = {role}, count = 1,
					area = "elandor_dawnmere_fields/home_fields"}}, rewards = {weight = 1}}}}}
	end
	local ok, err = pcall(Q.validate_quest_data, {file(2, "small_boar")})
	check(ok, "area objective within level 2 +-3 accepted: " .. tostring(err))
	ok, err = pcall(Q.validate_quest_data, {file(9, "small_boar")})
	check(not ok and tostring(err):find("quest probe_area: objective 1: small_boar is met at levels 1-2", 1, true)
		and tostring(err):find("E-level-fit", 1, true), "level outside the slack refused: " .. tostring(err))
	ok, err = pcall(Q.validate_quest_data, {file(2, "small_fox")})
	check(not ok and tostring(err):find("E-role-not-in-area", 1, true), "role outside the area refused: " .. tostring(err))
	log("area check example: " .. tostring(err):gsub("\n%s*", " | "))
end

local function run()
	local Q = grug_quests
	local areas_ok, areas_err = pcall(area_checks, Q)
	check(areas_ok, "area checks: " .. tostring(areas_err))
	-- New givers the shipped zone files declare (none until a design adds one).
	local new = {}
	for id, npc in pairs(Q.registered_npcs) do
		if npc.race then new[#new + 1] = ("%s (%s, %s) at %s/%s"):format(id, npc.title, npc.race,
			npc.settlement, npc.socket) end
	end
	table.sort(new)
	log("new givers from the zone files: " .. (#new > 0 and table.concat(new, "; ") or "none"))
	local ok, err = pcall(summary, Q)
	check(ok, "registry summary: " .. tostring(err))
	sample(Q)
	play(Q)
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
