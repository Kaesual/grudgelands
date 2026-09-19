-- Round 7 Food v2 compact KAT. Loads the changed production seams under
-- deterministic engine stubs and returns one canonical digest.

local function load_in(path, environment)
	local chunk, load_error = loadfile(path)
	assert(chunk, load_error)
	setfenv(chunk, environment)
	return chunk()
end

local function food_status_rows(root, failures)
	local now = 0
	local connected = {}
	local hooks = {join = {}, leave = {}, die = {}, step = {}}
	local chats = {}
	local items = {}

	local function check(condition, message)
		if not condition then failures[#failures + 1] = message end
	end

	local item_names = {
		"default:apple", "default:blueberries", "mobs:meat_raw", "mobs:meat",
		"mobs:meatblock_raw", "mobs:meatblock", "grug_mobs:raw_fish",
		"grug_fishing:silver_trout", "grug_fishing:mire_carp",
		"grug_fishing:frostfin", "grug_fishing:ember_eel",
		"grug_fishing:storm_tuna", "grug_fishing:cooked_fish",
		"grug_gathering:corn",
		"grug_gathering:melon", "grug_gathering:mushroom",
		"grug_gathering:potato", "grug_gathering:rock_salt",
		"grug_gathering:wild_cocoa",
	}
	for index = 1, #item_names do
		items[item_names[index]] = {description = item_names[index], groups = {}}
	end

	local core = {
		registered_items = items,
		get_us_time = function() return now end,
		get_connected_players = function() return connected end,
		get_player_by_name = function(name)
			for index = 1, #connected do
				local player = connected[index]
				if player and player:get_player_name() == name then
					return player
				end
			end
			return nil
		end,
		register_on_joinplayer = function(fn) hooks.join[#hooks.join + 1] = fn end,
		register_on_leaveplayer = function(fn) hooks.leave[#hooks.leave + 1] = fn end,
		register_on_dieplayer = function(fn) hooks.die[#hooks.die + 1] = fn end,
		register_globalstep = function(fn) hooks.step[#hooks.step + 1] = fn end,
		register_on_player_hpchange = function() end,
		chat_send_player = function(name, message)
			chats[#chats + 1] = name .. ":" .. message
		end,
		override_item = function(name, fields)
			for key, value in pairs(fields) do items[name][key] = value end
		end,
	}

	local grug_core = {hud_layout = {anchors = {status_list = {
		position = {x = 1, y = 0}, offset = {x = 0, y = 0},
		alignment = {x = 1, y = 1},
	}}}}
	local talent = {}
	local grug_classes = {
		get_class = function() return "mage" end,
		get_class_def = function() return {resource = "mana", growth = {}} end,
		get_talent_bonus = function(_, key) return talent[key] or 0 end,
	}
	local grug_xp = {
		get_level = function(player) return player.level end,
		register_on_level_change = function() end,
	}
	local grug_abilities = {}
	function grug_abilities.restore_mana(player, amount)
		local before = player.mana
		player.mana = math.min(grug_classes.get_max_mana(player), before + amount)
		return player.mana - before
	end
	local gathering = {
		{key = "corn", raw_item = "grug_gathering:corn", harvest_kind = "food"},
		{key = "melon", raw_item = "grug_gathering:melon", harvest_kind = "food"},
		{key = "mushroom", raw_item = "grug_gathering:mushroom", harvest_kind = "found_only_food"},
		{key = "potato", raw_item = "grug_gathering:potato", harvest_kind = "food"},
		{key = "rock_salt", raw_item = "grug_gathering:rock_salt", harvest_kind = "found_only_food"},
		{key = "wild_cocoa", raw_item = "grug_gathering:wild_cocoa", harvest_kind = "found_only_food"},
	}
	local environment = {
		core = core, grug_core = grug_core, grug_classes = grug_classes,
		grug_xp = grug_xp, grug_abilities = grug_abilities,
		grug_gathering = {p9g_sources = function() return gathering end},
		math = math, string = string, table = table,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, rawget = rawget,
		assert = assert, error = error, pcall = pcall,
	}
	environment._G = environment

	load_in(root .. "/mods/CORE/grug_core/status.lua", environment)
	load_in(root .. "/mods/CORE/grug_core/combat.lua", environment)
	grug_core.get_player_level = function(player) return player.level end
	load_in(root .. "/mods/PLAYER/grug_classes/stats.lua", environment)
	grug_core.in_combat = function(player) return player.combat == true end
	load_in(root .. "/mods/ITEMS/grug_food/init.lua", environment)

	local Player = {}
	Player.__index = Player
	local empty_inventory = {get_stack = function()
		return {is_empty = function() return true end}
	end}
	local function player(name, level, hp)
		return setmetatable({name = name, level = level, hp = hp, hp_max = 30,
			mana = 0, hud = {}, next_hud = 0}, Player)
	end
	function Player:is_player() return true end
	function Player:get_player_name() return self.name end
	function Player:get_hp() return self.hp end
	function Player:set_hp(value) self.hp = value end
	function Player:get_properties() return {hp_max = self.hp_max} end
	function Player:set_properties(fields) self.hp_max = fields.hp_max end
	function Player:get_inventory() return empty_inventory end
	function Player:hud_add(definition)
		self.next_hud = self.next_hud + 1
		self.hud[self.next_hud] = definition
		return self.next_hud
	end
	function Player:hud_change(id, field, value) self.hud[id][field] = value end
	function Player:hud_remove(id) self.hud[id] = nil end

	local Stack = {}
	Stack.__index = Stack
	local function stack(name, count)
		return setmetatable({name = name, count = count or 1}, Stack)
	end
	function Stack:get_name() return self.name end
	function Stack:take_item(count) self.count = math.max(0, self.count - count) end

	local tier_digest = {}
	local expected_instant = {5, 15, 40, 90, 180, 300}
	local expected_level = {1, 11, 21, 31, 41, 51}
	for tier = 1, 6 do
		local definition = environment.grug_food.TIERS[tier]
		local raw = environment.grug_food.effect_for(tier, "raw", "hp")
		check(definition and definition.instant_hp == expected_instant[tier] and
			definition.min_level == expected_level[tier] and
			definition.dishes.hearty and definition.dishes.caster and
			definition.dishes.hunter, "tier table shape T" .. tier)
		check(raw and raw.regen.hp == 1 and next(raw.modifiers) == nil,
			"raw rule T" .. tier)
		tier_digest[#tier_digest + 1] = expected_instant[tier] .. "/" ..
			expected_level[tier] .. "/" .. raw.regen.hp
	end
	local dish = environment.grug_food.effect_for(4, "dish", "caster")
	check(dish.regen.hp == 3.5 and dish.regen.mana == 3.5 and
		dish.modifiers.mana_pool_percent == 4, "dish table rule")

	local stats_player = player("stats", 10, 122)
	connected[1] = stats_player
	for index = 1, #hooks.join do hooks.join[index](stats_player) end
	grug_classes.apply_stats(stats_player)
	local base_hp = grug_classes.get_max_hp(stats_player)
	local base_mana = grug_classes.get_max_mana(stats_player)
	local base_crit = grug_classes.get_crit_chance(stats_player)
	local base_spell = grug_classes.get_spell_power_bonus(stats_player)
	local first = grug_core.set_status(stats_player, "food", {
		label = "Food", duration = 30, modifiers = {
			hp_pool_percent = 10, mana_pool_percent = 20,
			crit_percent = 2, armor = 4, spell_damage_percent = 3,
		},
	})
	check(first ~= nil and grug_classes.get_max_hp(stats_player) == 135 and
		grug_classes.get_max_mana(stats_player) == 163 and
		math.abs(grug_classes.get_crit_chance(stats_player) - 0.08) < 0.000001 and
		grug_classes.get_spell_power_bonus(stats_player) == 1 and
		grug_classes.get_spell_damage_percent(stats_player) == 3 and
		grug_core.status_modifier_sum(stats_player, "armor") == 4 and
		stats_player.hp_max == 135, "status modifiers reach stat accessors")
	local modified_crit = grug_classes.get_crit_chance(stats_player)
	local equipment_source_file = assert(io.open(root ..
		"/mods/PLAYER/grug_inventory/equipment.lua", "rb"))
	local equipment_source = equipment_source_file:read("*a")
	equipment_source_file:close()
	local armor_first = assert(equipment_source:find(
		"function grug_core.get_armor_percent", 1, true))
	local armor_last = assert(equipment_source:find("\nend", armor_first, true))
	local armor_environment = {
		grug_core = grug_core,
		grug_inventory = {get_equipped_armor = function() return 7 end},
		grug_classes = {get_talent_bonus = function() return 2 end},
		math = math,
	}
	local armor_chunk = assert(loadstring(equipment_source:sub(
		armor_first, armor_last + 3)))
	setfenv(armor_chunk, armor_environment)
	armor_chunk()
	local modified_armor = armor_environment.grug_core.get_armor_percent(
		stats_player)
	check(modified_armor == 13, "status modifier reaches armor accessor")
	grug_core.set_status(stats_player, "elixir", {
		label = "Elixir", duration = 30, modifiers = {hp_pool_percent = 5},
	})
	check(grug_core.status_modifier_sum(stats_player, "hp_pool_percent") == 15 and
		grug_classes.get_max_hp(stats_player) == 141,
		"status modifiers stack across statuses")
	check(grug_core.set_status(stats_player, "bad", {
		label = "Bad", duration = 30, modifiers = {unknown = 1},
	}) == nil, "unknown modifier key rejected")
	stats_player.hp = 141
	grug_core.clear_status(stats_player, "elixir")
	check(stats_player.hp == 135 and stats_player.hp_max == 135,
		"status expiry path clamps current HP")

	-- Load the exact offensive/support formula slice. A spell-damage status
	-- must multiply Fireball while leaving the shared heal formula unchanged.
	grug_core.clear_status(stats_player, "food")
	local kits_file = assert(io.open(root ..
		"/mods/PLAYER/grug_abilities/kits.lua", "rb"))
	local kits_source = kits_file:read("*a")
	kits_file:close()
	local helper_first = assert(kits_source:find(
		"local function spell_damage_value", 1, true))
	local helper_last = assert(kits_source:find(
		"--\n-- Particle helpers", helper_first, true))
	local fire_first = assert(kits_source:find(
		"local function fireball_values", helper_last, true))
	local fire_last = assert(kits_source:find("\nend", fire_first, true))
	local formula_chunk = assert(loadstring(
		kits_source:sub(helper_first, helper_last - 1) ..
		kits_source:sub(fire_first, fire_last + 3) ..
		"\nreturn support_value, fireball_values"))
	setfenv(formula_chunk, environment)
	local support_value, fireball_values = formula_chunk()
	talent.fireball_damage_add = 1
	local base_fireball = fireball_values(stats_player).damage
	local base_heal = support_value(stats_player, 20)
	grug_core.set_status(stats_player, "spell_test", {
		label = "Spell test", duration = 30,
		modifiers = {spell_damage_percent = 10},
	})
	local boosted_fireball = fireball_values(stats_player).damage
	local boosted_heal = support_value(stats_player, 20)
	talent.fireball_damage_add = nil
	check(boosted_fireball == math.floor(base_fireball * 1.10 + 0.5) and
		boosted_heal == base_heal and
		grug_classes.get_spell_power_bonus(stats_player) == base_spell,
		"spell damage percent raises Fireball only")

	local raw_label = environment.grug_food.status_label(
		environment.grug_food.effect_for(1, "raw", "hp"))
	local mixed_label = environment.grug_food.status_label({
		regen = {hp = 2, mana = 4}, modifiers = {hp_pool_percent = 2},
	})
	check(raw_label == "Food +1% HP/5s" and
		mixed_label == "Food +2% HP, +4% Mana/5s, +2% HP pool",
		"buff labels state effects")
	local apple_desc = items["default:apple"].description
	local mushroom_desc = items["grug_gathering:mushroom"].description
	check(apple_desc:find("Restores 5 HP instantly.", 1, true) and
		apple_desc:find("Regenerates 1% of maximum HP every 5 s for 3 min.", 1, true) and
		apple_desc:find("Instant heal and regeneration wait until you are out of combat; other bonuses stay.", 1, true) and
		not apple_desc:find("Requires level", 1, true) and
		mushroom_desc:find("Requires level 21.", 1, true), "food tooltip text")

	local eater = player("eater", 1, 10)
	connected[2] = eater
	local apple = stack("default:apple", 2)
	items["default:apple"].on_use(apple, eater)
	check(apple.count == 1 and eater.hp == 15, "instant heal applies out of combat")
	now = 5 * 1000000
	for index = 1, #hooks.step do hooks.step[index](5) end
	check(eater.hp == 16, "raw regeneration ticks at five seconds")

	now = 100 * 1000000
	local deferred = player("deferred", 1, 10)
	deferred.combat = true
	connected[2] = deferred
	items["default:apple"].on_use(stack("default:apple"), deferred)
	now = 105 * 1000000
	for index = 1, #hooks.step do hooks.step[index](5) end
	check(deferred.hp == 10, "combat pauses instant and regeneration")
	deferred.combat = false
	now = 110 * 1000000
	for index = 1, #hooks.step do hooks.step[index](5) end
	check(deferred.hp == 16, "first out-of-combat moment applies instant once")
	now = 115 * 1000000
	for index = 1, #hooks.step do hooks.step[index](5) end
	check(deferred.hp == 17, "deferred instant is not repeated")

	now = 300 * 1000000
	local expired_pending = player("expired_pending", 1, 10)
	expired_pending.combat = true
	connected[2] = expired_pending
	items["default:apple"].on_use(stack("default:apple"), expired_pending)
	now = 481 * 1000000
	for index = 1, #hooks.step do hooks.step[index](181) end
	check(grug_core.get_status(expired_pending, "food") == nil and
		expired_pending.hp == 10,
		"combat expiry ends food status but keeps deferred instant")
	expired_pending.combat = false
	now = 482 * 1000000
	for index = 1, #hooks.step do hooks.step[index](1) end
	local paid_after_expiry = expired_pending.hp
	now = 483 * 1000000
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(paid_after_expiry == 15 and expired_pending.hp == 15,
		"expired food pays deferred instant exactly once out of combat")

	now = 600 * 1000000
	local replacement_pending = player("replacement_pending", 11, 10)
	replacement_pending.combat = true
	connected[2] = replacement_pending
	items["default:apple"].on_use(stack("default:apple"), replacement_pending)
	items["grug_fishing:silver_trout"].on_use(stack("grug_fishing:silver_trout"),
		replacement_pending)
	replacement_pending.combat = false
	now = 601 * 1000000
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(replacement_pending.hp == 25,
		"new serving replaces rather than adds deferred instant")

	now = 700 * 1000000
	local dead_pending = player("dead_pending", 1, 10)
	dead_pending.combat = true
	connected[2] = dead_pending
	items["default:apple"].on_use(stack("default:apple"), dead_pending)
	for index = 1, #hooks.die do hooks.die[index](dead_pending) end
	dead_pending.combat = false
	now = 701 * 1000000
	for index = 1, #hooks.step do hooks.step[index](1) end
	check(dead_pending.hp == 10, "death clears deferred instant")

	local low = player("low", 10, 20)
	local fish = stack("grug_fishing:silver_trout", 1)
	items["grug_fishing:silver_trout"].on_use(fish, low)
	check(fish.count == 1 and chats[#chats] == "low:Requires level 11.",
		"consumable level gate refuses without consuming")
	low.level = 11
	items["grug_fishing:silver_trout"].on_use(fish, low)
	check(fish.count == 0, "consumable level gate accepts at level")

	return "tiers=" .. table.concat(tier_digest, ",") ..
		("\tstats=%d/%d/%.2f/%d->%d/%d/%.2f/%d/%d"):format(
			base_hp, base_mana, base_crit, base_spell,
			135, 163, modified_crit, 3, modified_armor) ..
		("\tspell=%d->%d/heal=%g"):format(
			base_fireball, boosted_fireball, boosted_heal) ..
		"\tlabels=" .. raw_label .. "|" .. mixed_label ..
		"\tdeferred=10/16/17,expiry=10/15/15,replacement=25,death=10" ..
		"\tgate=10:refused,11:accepted"
end

local function regen_row(root, failures)
	local source_file = assert(io.open(root ..
		"/mods/PLAYER/grug_abilities/init.lua", "rb"))
	local source = source_file:read("*a")
	source_file:close()
	local first = assert(source:find(
		"function grug_abilities.mana_regen_rate", 1, true))
	local last = assert(source:find("\nfunction grug_abilities.mana_cost", first, true))
	local level = 1
	local maximum = 26
	local cold = 0
	local troll = 1
	local environment = {
		grug_abilities = {},
		grug_core = {get_player_level = function() return level end},
		grug_classes = {
			get_max_mana = function() return maximum end,
			get_race_perk = function() return troll end,
			get_talent_bonus = function() return cold end,
		},
		math = math,
	}
	local chunk = assert(loadstring(source:sub(first, last - 1)))
	setfenv(chunk, environment)
	chunk()
	local rows = {}
	local levels = {
		{level = 1, maximum = 26},
		{level = 10, maximum = 136},
		{level = 20, maximum = 384},
		{level = 30, maximum = 764},
		{level = 40, maximum = 1276},
		{level = 60, maximum = 2696},
	}
	for index = 1, #levels do
		level = levels[index].level
		maximum = levels[index].maximum
		cold = 0
		troll = 1
		local ooc = environment.grug_abilities.mana_regen_rate({}, false)
		local combat = environment.grug_abilities.mana_regen_rate({}, true)
		cold = 0.5
		local focused = environment.grug_abilities.mana_regen_rate({}, true)
		troll = 1.5
		cold = 0
		local troll_ooc = environment.grug_abilities.mana_regen_rate({}, false)
		local troll_combat = environment.grug_abilities.mana_regen_rate({}, true)
		cold = 0.5
		local troll_focused = environment.grug_abilities.mana_regen_rate({}, true)
		local expected = 1 + 0.15 * level
		local expected_combat = math.max(expected * 0.25, maximum * 0.0025)
		if math.abs(ooc - expected) > 0.000001 or
				math.abs(combat - expected_combat) > 0.000001 or
			math.abs(focused - expected_combat * 2) > 0.000001 or
			math.abs(troll_ooc - expected * 1.5) > 0.000001 or
			math.abs(troll_combat - expected_combat) > 0.000001 or
			math.abs(troll_focused - expected_combat * 2) > 0.000001 then
			failures[#failures + 1] = "mana regen curve L" .. level
		end
		rows[#rows + 1] = ("L%d=%.4f/%.4f/%.4f/%.4f/%.4f/%.4f"):format(
			level, ooc, combat, focused, troll_ooc, troll_combat,
			troll_focused)
	end
	return table.concat(rows, ",")
end

local function preload_once(root, initial_marker)
	local stored = initial_marker
	local scheduled = {}
	local emerges = {}
	local logs = {}
	local mods_loaded
	local core = {
		EMERGE_CANCELLED = 1, EMERGE_ERRORED = 2,
		get_us_time = function() return 0 end,
		get_mod_storage = function()
			return {
				get_int = function() return stored end,
				set_int = function(_, _, value) stored = value end,
			}
		end,
		after = function(_, callback) scheduled[#scheduled + 1] = callback end,
		emerge_area = function(pos1, pos2, callback)
			emerges[#emerges + 1] = callback
		end,
		log = function(_, message) logs[#logs + 1] = message end,
		register_on_mods_loaded = function(callback) mods_loaded = callback end,
	}
	local identities = {}
	for index = 1, 6 do
		identities[index] = {race_id = "race" .. index,
			faction_id = index <= 3 and "accord" or "throng",
			anchor = {x = index * 100, y = 10, z = 100}}
	end
	local environment = {
		core = core,
		grug_core = {start_identities = function() return identities end},
		math = math, string = string, table = table,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber,
	}
	load_in(root .. "/mods/CORE/grug_core/starts_preload.lua", environment)
	mods_loaded()
	local function drain()
		while #scheduled > 0 do
			local callback = table.remove(scheduled, 1)
			callback()
		end
	end
	drain()
	local completed = 0
	while completed < #emerges do
		completed = completed + 1
		emerges[completed](nil, 0, 0)
		drain()
	end
	local ready, total = environment.grug_core.starts_ready()
	return stored, #emerges, ready, total, table.concat(logs, "|")
end

local function preload_row(root, failures)
	local stored, emerges, ready, total = preload_once(root, 0)
	if stored ~= 1 or emerges ~= 6 or ready ~= 6 or total ~= 6 then
		failures[#failures + 1] = "fresh preload did not persist after six starts"
	end
	local stored_again, skipped, ready_again, total_again, logs =
		preload_once(root, 1)
	local marker_log = "[grug_core] start areas already generated"
	local count = logs == marker_log and 1 or 0
	if stored_again ~= 1 or skipped ~= 0 or ready_again ~= 6 or
			total_again ~= 6 or count ~= 1 then
		failures[#failures + 1] = "stored preload marker did not skip exactly once"
	end
	return ("fresh=%d/%d/%d restart=%d/%d/%d log=%d"):format(
		emerges, ready, stored, skipped, ready_again, stored_again, count)
end

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"r7_food KAT requires an absolute repository root")
	local failures = {}
	local rows = {
		"r7_food\t" .. food_status_rows(root, failures),
		"r7_mana_regen\t" .. regen_row(root, failures),
		"r7_start_preload\t" .. preload_row(root, failures),
	}
	rows[#rows + 1] = "r7_food_result\tfailures=" .. #failures
	if #failures > 0 then
		rows[#rows + 1] = "FAIL " .. table.concat(failures, "; ")
	else
		rows[#rows + 1] = "PASS"
	end
	return table.concat(rows, "\n") .. "\n"
end
