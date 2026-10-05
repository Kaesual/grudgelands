-- Round 35 lane B portable test (level-proof talents, round35-plan.md §2.7,
-- §4.4). Loads the REAL talent files (grug_classes/talents.lua,
-- scout_talents.lua, talents_ui.lua) and the real fit formulas cut out of
-- grug_core/combat.lua under small stubs, and checks:
--   A. every converted talent's effect key is level-scaled, and nothing else
--      is: a flat damage or armor value cannot slip back in unnoticed;
--   B. the rule: at levels 10, 30 and 60 every converted value is the same
--      share of its reference (damage: a base hit, which the level scalar
--      turns into one eighth of the base pool; armor: the armor constant);
--   C. end to end through get_talent_bonus: a whole tree at level 60 (each
--      converted key answers its percentage of the level reference), Tinder
--      5/5 at levels 10, 30 and 60 (the same relative bonus, a level change
--      needs no cache drop), the windowed keys only inside their window;
--   D. the tooltip (talent_description_for) shows the amounts at the
--      viewer's level, and a pool talent keeps its own line;
--   E. the consumers: Whitehot's damage and Longshot's hit read the talent
--      keys, no literal +6 / +4 is left;
--   F. the user's phase-2 picks (2026-10-05): every changed talent's values,
--      Cold Focus x1.4 per rank, the consumers of Heavy Hand, Ruination,
--      Whitehot, Second Skin, Recompense's 6 s internal cooldown, Last Word's
--      cooldown reset (the real clear_cooldown cut out of init.lua), Charge at
--      12 % of a base hit, Opening on a rooted or stunned target (the real
--      held_target cut out of scout.lua) and Loose without a pre-scalar floor.
--
-- Usage (repo root): luajit tools/r35_b/portable_test.lua [REPO]
local ROOT = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, label)
	check(math.abs(a - b) < 1e-9, label .. " (" .. tostring(a) .. " vs " ..
		tostring(b) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The real fit formulas (base_pool .. level_scale, armor_k) of grug_core.
grug_core = {}
local combat = read("mods/CORE/grug_core/combat.lua")
local fit = combat:match("(function grug_core%.base_pool%(level%).-\n" ..
	"function grug_core%.level_scale%(level%).-\nend)\n")
local armor_k = combat:match("(function grug_core%.armor_k%(attacker_level%).-\nend)\n")
check(fit ~= nil and armor_k ~= nil, "the fit block and armor_k are found in combat.lua")
assert(loadstring(fit))()
assert(loadstring(armor_k))()
check(type(grug_core.baseline_melee_total) == "function",
	"grug_core.baseline_melee_total is public")
grug_core.feed = function() end
grug_core.clear_move_immunity = function() end
grug_core.clear_absorb_modifiers = function() end

-- Engine and neighbour stubs, just enough for the three files to load.
local now_us = 0
core = {
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_classes" end,
	get_current_modname = function() return "grug_classes" end,
	get_us_time = function() return now_us end,
	register_on_player_hpchange = function() end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_mods_loaded = function() end,
	register_chatcommand = function() end,
	formspec_escape = function(text) return text end,
}
sfinv = {register_page = function() end, pages = {}, pages_unordered = {}}
grug_xp = {
	get_level = function(player) return player.level end,
	register_on_level_change = function() end,
}
grug_classes = {
	registered_classes = {warrior = {}, mage = {}, priest = {}, scout = {}},
	register_on_class_chosen = function() end,
	get_class = function(player) return player.class end,
	apply_stats = function() end,
	pool_percent_amount = function(player, pool, percent)
		return math.floor(grug_core.base_pool(player.level) * percent / 100 + 0.5)
	end,
}
dofile(ROOT .. "/mods/PLAYER/grug_classes/talents.lua")
dofile(ROOT .. "/mods/PLAYER/grug_classes/talents_ui.lua")

-- Every player gets its own name: the parsed talent cache is per name.
local serial = 0
local function new_player(class, level, talents)
	local meta = {["grug_classes:talents"] = talents or ""}
	local player = {class = class, level = level}
	serial = serial + 1
	local name = class .. level .. "_" .. serial
	function player.is_player() return true end
	function player.get_player_name() return name end
	function player.get_meta()
		return {
			get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end,
		}
	end
	return player
end

-- The converted talents (skill_trees.md §2.10): talent -> its scaled key.
local CONVERTED = {
	ironbound = "armor_percent_add", unbroken = "armor_rating_add_low_hp",
	tinder = "fireball_damage_add", brand = "fireball_splash",
	whitehot = "whitehot_damage", cinderfall = "cinderfall_damage",
	rimebite = "control_damage_add", sharpened_word = "smite_damage_add",
	warded_wrath = "smite_damage_while_shielded_add",
	word_of_ruin = "word_of_ruin_damage", strong_draw = "loose_damage_add",
	longshot = "longshot_damage_add", fine_edge = "melee_damage_add",
}
local scaled = grug_classes.TALENT_LEVEL_SCALED_KEYS

local function reference(key, level)
	if scaled[key] == "armor" then return grug_core.armor_k(level) end
	return grug_core.baseline_melee_total(level)
end

-- A. Exactly the converted keys are level-scaled.
local seen = {}
for id, key in pairs(CONVERTED) do
	local def = grug_classes.registered_talents[id]
	check(def and def.effects[key], id .. " carries " .. key)
	check(scaled[key] ~= nil, key .. " (" .. id .. ") is level-scaled")
	seen[key] = true
end
for key in pairs(scaled) do
	check(seen[key], key .. " is level-scaled but belongs to no converted talent")
	check(grug_classes.TALENT_EFFECT_KEYS[key], key .. " is in the closed vocabulary")
end

-- B. The same share of the reference at levels 10, 30 and 60, and a damage
-- value is the same share of the effective base hit (one eighth of the pool).
for id, key in pairs(CONVERTED) do
	local values = grug_classes.registered_talents[id].effects[key]
	for _, level in ipairs({10, 30, 60}) do
		local player = new_player("mage", level)
		for rank, value in ipairs(values) do
			local amount = grug_classes.talent_level_amount(player, key, value)
			near(amount / reference(key, level), value / 100,
				("B %s rank %d at level %d is %g%% of its reference"):format(
					id, rank, level, value))
			if scaled[key] == "damage" then
				near(amount * grug_core.level_scale(level) /
					(grug_core.base_pool(level) / 8), value / 100,
					("B %s rank %d at level %d is %g%% of a dealt base hit"):format(
						id, rank, level, value))
			end
		end
	end
end
check(grug_classes.talent_level_amount(new_player("mage", 60), "crit_chance_add", 5) == 5,
	"B an unscaled key answers its own value")

-- C. End to end. A whole tree is 28 ranks, legal at level 60 (30 points).
local function whole_tree(tree_id)
	local parts = {}
	for _, def in ipairs(grug_classes.registered_trees[tree_id].talents) do
		parts[#parts + 1] = def.id .. "=" .. def.ranks
	end
	return table.concat(parts, ",")
end
for id, key in pairs(CONVERTED) do
	local def = grug_classes.registered_talents[id]
	local player = new_player(def.class, 60, whole_tree(def.tree))
	check(grug_classes.talent_rank(player, id) == def.ranks,
		"C " .. id .. " is held at full rank by a whole " .. def.tree .. " tree")
	local expected = def.effects[key][def.ranks] * reference(key, 60) / 100
	if def.window then
		check(grug_classes.get_talent_bonus(player, key) == 0,
			"C " .. id .. " adds nothing outside its window")
		grug_classes.start_talent_window(player, id, 8)
	end
	near(grug_classes.get_talent_bonus(player, key), expected,
		"C " .. id .. " at level 60 through get_talent_bonus")
end
do
	local player = new_player("mage", 10, "tinder=5")
	local shares = {}
	for _, level in ipairs({10, 30, 60}) do
		player.level = level -- the cached parse holds the percentage sum only
		shares[#shares + 1] = grug_classes.get_talent_bonus(player,
			"fireball_damage_add") / grug_core.baseline_melee_total(level)
	end
	near(shares[1], 0.20, "C Tinder 5/5 is 20 % of a base hit at level 10")
	near(shares[2], shares[1], "C Tinder 5/5 is the same share at level 30")
	near(shares[3], shares[1], "C Tinder 5/5 is the same share at level 60")
	check(grug_classes.get_talent_bonus(new_player("mage", 60, ""),
		"fireball_damage_add") == 0, "C no Tinder, no bonus")
end

-- D. The tooltip shows the amounts at the viewer's level.
do
	local tinder = grug_classes.registered_talents.tinder
	local at30 = grug_classes.talent_description_for(new_player("mage", 30), tinder)
	local at60 = grug_classes.talent_description_for(new_player("mage", 60), tinder)
	check(at30:find(tinder.description, 1, true) == 1, "D the rule text stays first")
	check(at30:find("At your level a base hit is 95 damage: " ..
		"+3.8 / +7.6 / +11 / +15 / +19 damage.", 1, true) ~= nil,
		"D Tinder at level 30: " .. at30)
	check(at60:find("At your level a base hit is 337 damage: " ..
		"+13 / +27 / +40 / +54 / +67 damage.", 1, true) ~= nil,
		"D Tinder at level 60: " .. at60)
	local ironbound = grug_classes.talent_description_for(new_player("warrior", 60),
		grug_classes.registered_talents.ironbound)
	check(ironbound:find("At your level: +1.5 / +3 / +4.5 / +6 / +7.5 armor rating.",
		1, true) ~= nil, "D Ironbound at level 60: " .. ironbound)
	local whitehot = grug_classes.talent_description_for(new_player("mage", 50),
		grug_classes.registered_talents.whitehot)
	check(whitehot:find("At your level a base hit is 240 damage: +72 damage.",
		1, true) ~= nil, "D Whitehot at level 50: " .. whitehot)
	local weathered = grug_classes.talent_description_for(new_player("warrior", 30),
		grug_classes.registered_talents.weathered)
	check(weathered:find("At your level: 2.5% = ", 1, true) ~= nil and
		not weathered:find("base hit", 1, true), "D a pool talent keeps its line")
	local keen = grug_classes.registered_talents.keen_edge
	check(grug_classes.talent_description_for(new_player("warrior", 30), keen)
		== keen.description, "D an unscaled talent shows its rule text only")
end

-- E. The consumers read the keys; no flat literal is left behind.
do
	local kits = read("mods/PLAYER/grug_abilities/kits.lua")
	check(kits:find('get_talent_bonus(user, "whitehot_damage")', 1, true) ~= nil,
		"E Fireball reads Whitehot's damage key")
	check(not kits:find('"whitehot") and 6 or 0', 1, true),
		"E no literal +6 for Whitehot")
	local scout = read("mods/PLAYER/grug_abilities/scout.lua")
	check(scout:find('"longshot_damage_add"', 1, true) ~= nil and
		scout:find("damage = damage + data.longshot", 1, true) ~= nil,
		"E Longshot's hit adds the key's launch snapshot")
	check(not scout:find("damage = damage + 4", 1, true), "E no literal +4 for Longshot")
	local icons = read("mods/CORE/grug_core/status_icons.lua")
	check(not icons:find("+15 armor rating", 1, true),
		"E the Unbroken status names no fixed rating")
end

-- F. The phase-2 picks.
do
	local function same(values, expected)
		if #values ~= #expected then return false end
		for i = 1, #values do
			if math.abs(values[i] - expected[i]) > 1e-12 then return false end
		end
		return true
	end
	local PICKS = {
		ironbound = {"armor_percent_add", {3, 6, 9, 12, 15}},
		unbroken = {"armor_rating_add_low_hp", {33}},
		tinder = {"fireball_damage_add", {4, 8, 12, 16, 20}},
		brand = {"fireball_splash", {6, 9, 12}},
		cinderfall = {"cinderfall_damage", {15, 20, 25}},
		sharpened_word = {"smite_damage_add", {4, 8, 12, 16, 20}},
		warded_wrath = {"smite_damage_while_shielded_add", {4, 8, 12, 16}},
		word_of_ruin = {"word_of_ruin_damage", {18, 24, 30}},
		strong_draw = {"loose_damage_add", {4, 8, 12, 16, 20}},
		longshot = {"longshot_damage_add", {11}},
		fine_edge = {"melee_damage_add", {4, 8, 12, 16, 20}},
		recompense = {"smite_absorb", {6, 9, 12}},
		fletching = {"draw_time_sub", {0.125, 0.25, 0.375, 0.5}},
		twin_shot = {"loose_second_arrow", {40, 50, 60}},
		swift_word = {"smite_cooldown_sub", {0.1, 0.2, 0.3, 0.4}},
		hardened = {"max_hp_percent_add", {2, 4, 6}},
		second_skin = {"shield_cooldown_sub", {1, 2, 3}},
		weathered = {"max_hp_percent_add", {2.5, 5, 7.5, 10}},
		heavy_hand = {"mighty_blow_multiplier_add", {0.1, 0.2, 0.3, 0.4, 0.5}},
		cold_focus = {"combat_mana_regen_add", {0.2, 0.4, 0.6, 0.8, 1.0}},
		shifting_weight = {"dodge_chance_add", {2, 4, 6}},
		keen_edge = {"crit_chance_add", {2, 4, 6, 8, 10}},
		firebrand = {"crit_chance_add", {2, 4, 6, 8}},
		hard_faith = {"crit_chance_add", {2, 4, 6, 8, 10}},
		cold_eye = {"crit_chance_add", {2, 4, 6, 8}},
		whitehot = {"whitehot_damage", {30}},
		rimebite = {"control_damage_add", {25}},
	}
	for id, pick in pairs(PICKS) do
		local def = grug_classes.registered_talents[id]
		check(def and def.effects[pick[1]] and same(def.effects[pick[1]], pick[2]),
			"F " .. id .. " carries the picked " .. pick[1])
	end
	check(grug_classes.TALENT_EFFECT_KEYS.shield_duration_add == nil,
		"F Second Skin's duration key is gone")
	-- Cold Focus: in-combat regeneration x(1 + 2 x bonus) in mana_regen_rate.
	local init = read("mods/PLAYER/grug_abilities/init.lua")
	check(init:find("combat_rate * (1 + 2 * bonus)", 1, true) ~= nil,
		"F mana_regen_rate still doubles the Cold Focus bonus")
	for rank, value in ipairs(PICKS.cold_focus[2]) do
		near(1 + 2 * value, 1 + 0.4 * rank, "F Cold Focus rank " .. rank .. " is x" ..
			(1 + 0.4 * rank))
	end
	local kits = read("mods/PLAYER/grug_abilities/kits.lua")
	check(kits:find('local mult = 1.5 + grug_classes.get_talent_bonus(user,', 1, true),
		"F Mighty Blow adds Heavy Hand's multiplier directly (x2.0 at 5/5)")
	check(kits:find('try_trigger_talent_window(user, "ruination", 15, 60)', 1, true),
		"F Ruination: 15 s window, 60 s cooldown")
	check(kits:find('"whitehot_window", 8), 60)', 1, true), "F Whitehot: 60 s cooldown")
	check(kits:find('cooldown_talent = "shield_cooldown_sub"', 1, true) and
		not kits:find("shield_duration_add", 1, true), "F Second Skin shortens Shield's cooldown")
	check(kits:find("local RECOMPENSE_ICD = 6", 1, true) and
		kits:find("now >= (recompense_ready[name] or 0)", 1, true),
		"F Recompense grants at most once every 6 s")
	check(kits:find('try_trigger_talent_window(user, "last_word", 12, 180) then', 1, true) and
		kits:find('grug_abilities.clear_cooldown(player, "word_of_ruin")', 1, true),
		"F Last Word: 12 s window, the trigger resets Word of Ruin")
	check(kits:find("return {damage = 0.12 * grug_core.baseline_melee_total(", 1, true),
		"F Charge deals 12 % of a base hit")
	near(0.12 * grug_core.baseline_melee_total(30), 2.964, "F Charge at level 30 ~ the former 3")
	-- clear_cooldown, cut out of init.lua: the record expires now.
	local helper = init:match("\n(function grug_abilities%.clear_cooldown%(player, id%).-\nend)\n")
	check(helper ~= nil, "F clear_cooldown is found in init.lua")
	local cooldowns = {p = {word_of_ruin = {expiry = 99e6, duration = 12}}}
	grug_abilities = {}
	local env = setmetatable({cooldowns = cooldowns}, {__index = _G})
	local chunk = assert(loadstring(helper))
	setfenv(chunk, env)()
	now_us = 5e6
	grug_abilities.clear_cooldown({get_player_name = function() return "p" end}, "word_of_ruin")
	check(cooldowns.p.word_of_ruin.expiry == 5e6, "F clear_cooldown ends the cooldown now")
	grug_abilities.clear_cooldown({get_player_name = function() return "q" end}, "word_of_ruin")
	-- Opening's held_target, cut out of scout.lua.
	local scout = read("mods/PLAYER/grug_abilities/scout.lua")
	local held = scout:match("\n(local function held_target%(target%).-\nend)\n")
	check(held ~= nil, "F held_target is found in scout.lua")
	local states = {}
	grug_core.is_stunned = function(p) return states[p] == "stun" end
	grug_core.is_rooted = function(p) return states[p] == "root" end
	local held_target = assert(loadstring(held .. "\nreturn held_target"))()
	local function mob(fields)
		return {is_player = function() return false end,
			get_luaentity = function() return fields end}
	end
	local function pl(state)
		local p = {is_player = function() return true end}
		states[p] = state
		return p
	end
	check(held_target(mob({_grug_root_left = 1.5})), "F a rooted mob is held")
	check(held_target(mob({_grug_stun_left = 0.5})), "F a stunned mob is held")
	check(not held_target(mob({})), "F a free mob is not held")
	check(not held_target(mob({_grug_root_left = 0})), "F a spent root holds nothing")
	check(held_target(pl("stun")) and held_target(pl("root")) and not held_target(pl(nil)),
		"F players: stunned or rooted is held")
	check(scout:find("if not behind_target(user, target) and not held_target(target) then",
		1, true), "F Opening lands from behind or on a held target")
	check(not scout:find("math.floor((base_damage", 1, true) and
		not scout:find("math.floor(damage * effect.second_percent", 1, true),
		"F Loose leaves the one floor to the level scalar")
	check(read("mods/CORE/grug_core/movement.lua"):find("function grug_core.is_rooted(player)",
		1, true), "F grug_core.is_rooted exists")
end

print(("r35_b portable test: %d checks passed"):format(checks))
