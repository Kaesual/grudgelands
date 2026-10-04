-- Round 33 lane C1 portable test (LuaJIT): drops (round33-plan.md §2.1, §2.2).
--
-- Loads the REAL grug_gear (init.lua with permissions.lua, enchant_colors.lua
-- and trinkets.lua), grug_quality's init.lua, grug_core's can_use_item_level
-- (cut out of combat.lua), grug_traders' price_rules.lua and prices.lua under a
-- permissive engine stub with real ItemStack metadata semantics:
--   A. drop rates over many simulated kills: normal 5/2/1 % white/blue/gold,
--      elite and named rare 10/10/5 %, never more than one gear item per kill,
--      critters none; the quality is the enchant count plus one;
--   B. bosses: a King, a dragon and a General always drop two items, blue or
--      gold at about even odds, at item level 65 / 70 / 65; the kill-loot hook
--      leaves Kings and royal guards to the ledger and drops the General's;
--   C. deep sea: the Kraken (no quality loot) drops nothing;
--   D. bags: about 0.1 % per kill, the size by mob level (8/16/24/32 slots,
--      read from grug_inventory's bags.lua);
--   E. the pool: every equippable item of the tier (weapons, armour, shield,
--      spellbook, six trinkets), all of them dropping;
--   F. trinkets roll 0/1/2 enchants, the single one on either channel, each
--      from its channel's pool;
--   G. the enchant tier of an item level (T1..T6 by ten levels, T7 above 60);
--   H. the requirement: every equipment definition carries min(ilvl, 60) (1 in
--      the first bracket); dropped armour, offhands and trinkets carry their
--      own, capped at 60, refuse a lower character and show "Requires level";
--   I. sale value: blue x3, gold x6 of the Common payout, per stack;
--   J. the Kraken (user ruling, Round 33): the REAL kraken.lua definition is
--      a level-70 elite; it drops no item and no bag, and the REAL level
--      engine (levels.lua, grug_xp) pays no kill XP for it.
--
--   luajit tools/r33_c1/portable_test.lua [REPO]
-- Prints "R33 C1 PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function read_file(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- Engine stub.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
	grug_traders = ROOT .. "/mods/ENTITIES/grug_traders",
}
local current_mod = "grug_gear"
local serial = {}
local added = {}
local mods_loaded = {}
core = permissive({
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do registered[name][key] = value end
	end,
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
	add_item = function(_, stack)
		added[#added + 1] = stack
		return {set_velocity = function() end}
	end,
})
local loot_hook, reward_hook
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({
	register_kill_loot_hook = function(fn) loot_hook = fn end,
	register_boss_reward_hook = function(fn) reward_hook = fn end,
})
grug_inventory = permissive({})
grug_jobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

local function new_meta()
	local fields = {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(fields[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(name)
	local meta = new_meta()
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	return stack
end
-- Park-Miller with a short warm-up: good enough for rate checks.
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	local function step() state = (state * 48271) % 2147483647 end
	step(); step(); step()
	return {next = function(_, low, high)
		step()
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
-- The real level gate of grug_core (combat.lua), which grug_quality wraps.
do
	local source = read_file(ROOT .. "/mods/CORE/grug_core/combat.lua")
	local body = source:match("(function grug_core%.can_use_item_level%(player, item%).-\nend)\n")
	check(body ~= nil, "can_use_item_level found in combat.lua")
	assert(loadstring(body))()
	grug_core.get_player_level = function(player) return player.level end
end
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
check(loot_hook ~= nil and reward_hook ~= nil, "grug_quality registers its loot hooks")

local function is_bag(stack) return stack:get_name():find("^grug_inventory:bag_") ~= nil end
local function quality_of(stack) return stack:get_meta():get_int("grug_quality") end
local function affixes_of(stack) return grug_items.get_affixes(stack) end

-- Seeds spread over the generator's range.
local function seed_of(index) return (index * 2654435761) % 2147483646 + 1 end

------------------------------------------------------------------------------
-- A. Drop rates.
------------------------------------------------------------------------------
local bags_seen, bag_kills = 0, 0
local pool_hits = {}
local function simulate(mob, kills, salt)
	local counts, most = {[1] = 0, [2] = 0, [3] = 0}, 0
	local shape_ok = true
	for index = 1, kills do
		local out = grug_items.roll_mob_gear(mob, seed_of(index + salt))
		local gear = 0
		bag_kills = bag_kills + 1
		for _, stack in ipairs(out) do
			if is_bag(stack) then
				bags_seen = bags_seen + 1
			else
				gear = gear + 1
				local quality = quality_of(stack)
				counts[quality] = (counts[quality] or 0) + 1
				shape_ok = shape_ok and #affixes_of(stack) == quality - 1 and
					stack:get_meta():get_int("grug_ilvl") == math.min(mob._grug_level, 60)
				pool_hits[stack:get_name()] = (pool_hits[stack:get_name()] or 0) + 1
			end
		end
		if gear > most then most = gear end
	end
	return counts, most, shape_ok
end
local function near(value, target, tolerance) return math.abs(value - target) <= tolerance end

do
	local N = 200000
	local normal = {name = "grug_mobs:wolf", _grug_tier = "normal", _grug_level = 24}
	local counts, most, shape_ok = simulate(normal, N, 0)
	local white, blue, gold = 100 * counts[1] / N, 100 * counts[2] / N, 100 * counts[3] / N
	print(("normal mob: %.2f %% white, %.2f %% blue, %.2f %% gold (N=%d)"):format(white, blue, gold, N))
	check(near(white, 5, 0.25) and near(blue, 2, 0.15) and near(gold, 1, 0.1),
		"A normal mob drops 5/2/1 % white/blue/gold")
	check(most <= 1, "A a normal kill drops at most one gear item")
	check(shape_ok, "A quality = enchants + 1, item level = mob level")
	for _, tier in ipairs({"elite", "rare"}) do
		local mob = {name = "grug_mobs:bear", _grug_tier = tier, _grug_level = 47}
		counts, most, shape_ok = simulate(mob, N, N * (tier == "elite" and 1 or 2))
		white, blue, gold = 100 * counts[1] / N, 100 * counts[2] / N, 100 * counts[3] / N
		print(("%s mob: %.2f %% white, %.2f %% blue, %.2f %% gold"):format(tier, white, blue, gold))
		check(near(white, 10, 0.4) and near(blue, 10, 0.4) and near(gold, 5, 0.3),
			"A " .. tier .. " drops 10/10/5 % white/blue/gold")
		check(most <= 1, "A an " .. tier .. " kill drops at most one gear item")
		check(shape_ok, "A " .. tier .. ": quality = enchants + 1, item level = mob level")
	end
	local high = {name = "grug_mobs:wyrm", _grug_tier = "elite", _grug_level = 63}
	local out = {}
	for index = 1, 400 do
		for _, stack in ipairs(grug_items.roll_mob_gear(high, seed_of(index))) do
			if not is_bag(stack) then out[#out + 1] = stack end
		end
	end
	local capped = #out > 0
	for _, stack in ipairs(out) do capped = capped and stack:get_meta():get_int("grug_ilvl") == 60 end
	check(capped, "A an ordinary mob above 60 drops item level 60")
	local critter = {name = "grug_mobs:rabbit", _grug_tier = "critter", _grug_level = 1}
	local gear = 0
	for index = 1, 20000 do
		for _, stack in ipairs(grug_items.roll_mob_gear(critter, seed_of(index))) do
			if not is_bag(stack) then gear = gear + 1 end
		end
	end
	check(gear == 0, "A a critter drops no gear")
end

------------------------------------------------------------------------------
-- B. Bosses.
------------------------------------------------------------------------------
do
	local bosses = {
		{label = "King", ilvl = 65, mob = {name = "grug_mobs:king_human",
			_grug_boss_id = "king:human", _grug_royal_king = true, _grug_tier = "elite",
			_grug_level = 65}},
		{label = "dragon", ilvl = 70, mob = {name = "grug_mobs:dragon_ice",
			_grug_boss_id = "dragon:ice", _grug_tier = "boss", _grug_level = 70}},
		{label = "General", ilvl = 65, mob = {name = "grug_mobs:general_accord",
			_grug_boss_id = "general:accord", _grug_royal_king = true, _grug_tier = "elite",
			_grug_level = 65}},
	}
	for _, boss in ipairs(bosses) do
		local blue, gold, n, shape_ok = 0, 0, 2000, true
		for index = 1, n do
			local gear = {}
			for _, stack in ipairs(grug_items.roll_mob_gear(boss.mob, seed_of(index))) do
				if not is_bag(stack) then gear[#gear + 1] = stack end
			end
			shape_ok = shape_ok and #gear == 2
			for _, stack in ipairs(gear) do
				local quality = quality_of(stack)
				if quality == 2 then blue = blue + 1 elseif quality == 3 then gold = gold + 1 end
				shape_ok = shape_ok and (quality == 2 or quality == 3) and
					#affixes_of(stack) == quality - 1 and
					stack:get_meta():get_int("grug_ilvl") == boss.ilvl and
					stack:get_meta():get_int("grug_req_level") == 60 and
					stack:get_definition()._grug_bracket == 6
			end
		end
		print(("%s: %.1f %% blue, %.1f %% gold of %d items"):format(boss.label,
			100 * blue / (2 * n), 100 * gold / (2 * n), 2 * n))
		check(shape_ok, "B a " .. boss.label .. " always drops two blue or gold T6 items at " ..
			boss.ilvl .. ", requirement 60")
		check(near(blue / (2 * n), 0.5, 0.04), "B ...blue and gold at even odds")
	end
	-- The hooks: a King's gear goes through his ledger (the reward hook), his
	-- royal guards and the General's bodyguards drop none; the General's
	-- drops on the kill.
	local pos = {x = 0, y = 0, z = 0}
	local object = {get_pos = function() return pos end}
	local function hook_drops(mob, kills)
		added = {}
		mob.object = object
		for _ = 1, kills do loot_hook(mob, "org") end
		return #added
	end
	check(hook_drops(bosses[1].mob, 20) == 0, "B the kill hook leaves a King to his ledger")
	check(hook_drops({name = "grug_mobs:royal_guard_human", _grug_boss_id = "king:human",
		_grug_tier = "elite", _grug_level = 60}, 50) == 0, "B a royal guard drops no gear")
	check(hook_drops({name = "grug_mobs:bodyguard_accord", _grug_boss_id = "general:accord",
		_grug_tier = "elite", _grug_level = 60}, 50) == 0, "B a bodyguard drops no gear")
	check(hook_drops(bosses[3].mob, 20) >= 40, "B the kill hook drops the General's two items")
	local rewards = reward_hook(bosses[2].mob, "dragon:ice", nil)
	local gear = 0
	for _, stack in ipairs(rewards) do if not is_bag(stack) then gear = gear + 1 end end
	check(gear == 2, "B the reward hook gives a dragon's two items")
end

------------------------------------------------------------------------------
-- C. Deep sea.
------------------------------------------------------------------------------
do
	local kraken = {name = "grug_mobs:kraken", _grug_tier = "elite", _grug_level = 70,
		_grug_no_quality_loot = true}
	local any = 0
	for index = 1, 20000 do any = any + #grug_items.roll_mob_gear(kraken, seed_of(index)) end
	check(any == 0, "C a mob without quality loot drops nothing (no gear, no bag)")
end

------------------------------------------------------------------------------
-- D. Bags.
------------------------------------------------------------------------------
do
	local rate = 100 * bags_seen / bag_kills
	print(("bags: %d in %d kills (%.3f %%)"):format(bags_seen, bag_kills, rate))
	check(near(rate, 0.1, 0.02), "D a bag drops at about 0.1 % per kill")
	-- Sizes, read from the real registrations.
	local source = read_file(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
	local slots = {}
	for name, size in source:gmatch('register_craftitem%("grug_inventory:([%w_]+)".-bagslots = (%d+)') do
		slots[name] = tonumber(size)
	end
	for name, size in source:gmatch('{"([%w_]+)", "[^"]+", (%d+),') do slots[name] = tonumber(size) end
	local saved = grug_items.BAG_DROPS.chance
	grug_items.BAG_DROPS.chance = 100
	for _, row in ipairs({{1, 8}, {15, 8}, {16, 16}, {30, 16}, {31, 24}, {45, 24}, {46, 32},
			{60, 32}, {70, 32}}) do
		local mob = {name = "grug_mobs:wolf", _grug_tier = "critter", _grug_level = row[1]}
		local out = grug_items.roll_mob_gear(mob, seed_of(row[1]))
		local bag = out[#out]
		local name = bag and bag:get_name():match("^grug_inventory:(.+)$")
		check(#out == 1 and slots[name] == row[2],
			("D a level-%d mob drops a %d-slot bag (%s)"):format(row[1], row[2], tostring(name)))
	end
	-- A boss rolls the bag too, by its own level.
	local dragon = {name = "grug_mobs:dragon_ice", _grug_boss_id = "dragon:ice",
		_grug_tier = "boss", _grug_level = 70}
	local out = grug_items.roll_mob_gear(dragon, 7)
	check(#out == 3 and slots[out[3]:get_name():match(":(.+)$")] == 32,
		"D a dragon's bag comes beside its two items")
	grug_items.BAG_DROPS.chance = saved
	check(slots.bag_small == 8, "D the 8-slot bag is the vendor's small bag")
end

------------------------------------------------------------------------------
-- E. The pool.
------------------------------------------------------------------------------
do
	for tier = 1, 6 do
		local pool = grug_gear.drop_pool[tier]
		local kinds = {weapon = 0, armor = 0, shield = 0, spellbook = 0, trinket = 0}
		local seen, all_tier = {}, true
		for _, name in ipairs(pool) do
			local def = registered[name] or {}
			local groups = def.groups or {}
			all_tier = all_tier and def._grug_bracket == tier and not seen[name]
			seen[name] = true
			if (groups.grug_equip_weapon or 0) > 0 then kinds.weapon = kinds.weapon + 1
			elseif (groups.grug_armor_class or 0) > 0 then kinds.armor = kinds.armor + 1
			elseif (groups.grug_shield or 0) > 0 then kinds.shield = kinds.shield + 1
			elseif (groups.grug_spellbook or 0) > 0 then kinds.spellbook = kinds.spellbook + 1
			elseif (groups.grug_equip_trinket or 0) > 0 then kinds.trinket = kinds.trinket + 1
			end
		end
		check(all_tier and #pool == 26 and kinds.weapon == 6 and kinds.armor == 12 and
			kinds.shield == 1 and kinds.spellbook == 1 and kinds.trinket == 6,
			"E tier " .. tier .. ": six weapons, twelve armour pieces, shield, spellbook, six trinkets")
	end
	-- Every equippable registered item is in its tier's pool.
	local in_pool = {}
	for tier = 1, 6 do for _, name in ipairs(grug_gear.drop_pool[tier]) do in_pool[name] = true end end
	local missing = {}
	for name, def in pairs(registered) do
		local groups = def.groups or {}
		for group, value in pairs(groups) do
			if group:find("^grug_equip_") and value > 0 and not in_pool[name] then
				missing[#missing + 1] = name
				break
			end
		end
	end
	check(#missing == 0, "E every equippable item is in a pool: missing " .. table.concat(missing, ", "))
	-- The simulated drops of tiers 3 and 5 hit every item of both pools.
	local unhit = {}
	for _, tier in ipairs({3, 5}) do
		for _, name in ipairs(grug_gear.drop_pool[tier]) do
			if not pool_hits[name] then unhit[#unhit + 1] = name end
		end
	end
	check(#unhit == 0, "E every pool item drops: never " .. table.concat(unhit, ", "))
end

------------------------------------------------------------------------------
-- F. Trinkets roll 0/1/2.
------------------------------------------------------------------------------
do
	local prefix_pool = {str = true, int = true, dex = true}
	local suffix_pool = {max_hp_percent = true, max_mana_percent = true, crit_percent = true}
	local channels = {prefix = 0, suffix = 0}
	local ok = true
	for count = 0, 2 do
		for index = 1, 200 do
			local stack = ItemStack("grug_gear:manawell_t3")
			check(grug_items.roll_enchants(stack, 27, count, seed_of(index)) == true or count < 0,
				"F roll_enchants takes a trinket")
			local affixes = affixes_of(stack)
			ok = ok and #affixes == count and quality_of(stack) == count + 1
			for _, affix in ipairs(affixes) do
				channels[affix.channel] = channels[affix.channel] + (count == 1 and 1 or 0)
				ok = ok and (affix.channel == "prefix" and prefix_pool[affix.stat] or
					affix.channel == "suffix" and suffix_pool[affix.stat]) and true or false
			end
			if count == 2 then ok = ok and affixes[1].channel ~= affixes[2].channel end
		end
	end
	check(ok, "F a trinket rolls exactly 0/1/2 enchants, each from its channel's pool")
	check(channels.prefix > 60 and channels.suffix > 60,
		("F a single trinket enchant takes either channel (%d / %d)"):format(channels.prefix, channels.suffix))
	local white = ItemStack("grug_gear:manawell_t3")
	grug_items.roll_enchants(white, 27, 0, 5)
	local description = white:get_meta():get_string("description")
	check(description:find("Mana per second", 1, true) ~= nil,
		"F a white trinket keeps its special")
	-- Over the simulated kills, trinkets dropped in every quality.
	local by_quality = {}
	for index = 1, 60000 do
		for _, stack in ipairs(grug_items.roll_mob_gear({name = "grug_mobs:x",
				_grug_tier = "elite", _grug_level = 33}, seed_of(index))) do
			if registered[stack:get_name()] and registered[stack:get_name()]._grug_trinket_identity then
				by_quality[quality_of(stack)] = true
			end
		end
	end
	check(by_quality[1] and by_quality[2] and by_quality[3], "F trinkets drop white, blue and gold")
end

------------------------------------------------------------------------------
-- G. Enchant tier of an item level.
------------------------------------------------------------------------------
do
	local want = {[1] = 1, [3] = 1, [10] = 1, [11] = 2, [20] = 2, [21] = 3, [40] = 4,
		[41] = 5, [50] = 5, [51] = 6, [60] = 6, [61] = 7, [65] = 7, [70] = 7, [75] = 7}
	local ok = true
	for ilvl, tier in pairs(want) do ok = ok and grug_items.enchant_tier(ilvl) == tier end
	check(ok, "G item level 1-10 -> T1 ... 51-60 -> T6, above 60 -> T7")
	-- Every found roll asks it (the seam lane C4 caps the value at).
	local asked = {}
	local original = grug_items.enchant_tier
	grug_items.enchant_tier = function(ilvl)
		asked[#asked + 1] = ilvl
		return original(ilvl)
	end
	local stack = ItemStack("grug_gear:sword_steel")
	grug_items.roll_enchants(stack, 27, 2, 11)
	grug_items.enchant_tier = original
	check(#asked >= 2 and asked[#asked] == 27, "G each found enchant asks the item's tier")
end

------------------------------------------------------------------------------
-- H. The requirement.
------------------------------------------------------------------------------
do
	local ok, bad = true, {}
	for name, def in pairs(registered) do
		local groups = def.groups or {}
		local equip = false
		for group, value in pairs(groups) do
			if group:find("^grug_equip_") and value > 0 then equip = true end
		end
		if equip then
			local want = def._grug_bracket == 1 and 1 or math.min(def._grug_ilvl, 60)
			if def._grug_req_level ~= want then ok = false; bad[#bad + 1] = name end
		end
	end
	check(ok, "H every equipment definition requires min(ilvl, 60), 1 in bracket 1: " ..
		table.concat(bad, ", "))
	for _, row in ipairs({{"grug_gear:chest_metal_silversteel", 37, 37},
			{"grug_gear:shield_embersteel", 44, 44}, {"grug_gear:spellbook_iron", 17, 17},
			{"grug_gear:battlebeat_t4", 33, 33}, {"grug_gear:head_cloth_stormweave", 65, 60},
			{"grug_gear:mercy_seal_t6", 70, 60}}) do
		local stack = ItemStack(row[1])
		grug_items.roll_enchants(stack, row[2], 1, 99)
		local meta = stack:get_meta()
		check(meta:get_int("grug_req_level") == row[3],
			("H a dropped %s at item level %d requires %d"):format(row[1], row[2], row[3]))
		local low = grug_core.can_use_item_level({level = row[3] - 1}, stack)
		local fit = grug_core.can_use_item_level({level = row[3]}, stack)
		check(low == false and fit == true, "H ...refused below, allowed at " .. row[3])
		check(meta:get_string("description"):find("\nRequires level " .. row[3], 1, true) ~= nil,
			"H ...and its tooltip says Requires level " .. row[3])
	end
	-- A first-bracket drop stays level 1 up to the item's own level 3.
	for _, row in ipairs({{1, 1}, {2, 1}, {3, 1}, {4, 4}, {7, 7}}) do
		local stack = ItemStack("grug_gear:chest_metal_bronze")
		grug_items.roll_enchants(stack, row[1], 0, 7)
		check(stack:get_meta():get_int("grug_req_level") == row[2],
			("H a Bronze Chestplate at item level %d requires %d"):format(row[1], row[2]))
	end
	-- A plain vendor stack: the definition's requirement and tooltip line.
	local helm = ItemStack("grug_gear:head_metal_steel")
	check(grug_core.can_use_item_level({level = 19}, helm) == false and
		grug_core.can_use_item_level({level = 20}, helm) == true,
		"H a plain Steel Helm needs level 20")
	-- The definitions' tooltips, once every mod has loaded.
	for _, fn in ipairs(mods_loaded) do fn() end
	local function line_count(name, line)
		local _, count = registered[name].description:gsub(line, "")
		return count
	end
	check(line_count("grug_gear:head_metal_steel", "\nRequires level 20") == 1 and
		line_count("grug_gear:sword_abyssal_steel", "\nRequires level 50") == 1 and
		line_count("grug_gear:reclaimers_mark_t2", "\nRequires level 10") == 1 and
		line_count("grug_gear:spellbook_silversteel", "\nRequires level 30") == 1,
		"H the definitions' tooltips end with one Requires level line")
	check(line_count("grug_gear:sword_bronze", "Requires level") == 0 and
		line_count("grug_gear:feet_leather_light", "Requires level") == 0,
		"H ...none in the first bracket")
	local bronze = ItemStack("grug_gear:chest_cloth_patch")
	grug_items.regenerate_description(bronze)
	check(grug_core.can_use_item_level({level = 1}, bronze) == true and
		bronze:get_meta():get_string("description"):find("Requires level", 1, true) == nil,
		"H a first-bracket piece is worn at level 1 and shows no requirement line")
	local crafted = ItemStack("grug_gear:legs_leather_scaled")
	grug_items.crafted_output(crafted)
	check(crafted:get_meta():get_int("grug_req_level") == 30, "H a crafted piece requires its level")
end

------------------------------------------------------------------------------
-- I. Sale value.
------------------------------------------------------------------------------
do
	grug_traders = {}
	current_mod = "grug_traders"
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/prices.lua")
	local rules = grug_traders.price_rules
	check(rules.quality_payout(10, 1) == 10 and rules.quality_payout(10, 2) == 30 and
		rules.quality_payout(10, 3) == 60 and rules.quality_payout(10, 0) == 10,
		"I payout x1 / x3 / x6 for white / blue / gold")
	grug_traders.sell_price = function(name) return name == "grug_gear:sword_steel" and 8 or 0 end
	local paid = {}
	for quality = 1, 3 do
		local stack = ItemStack("grug_gear:sword_steel")
		grug_items.roll_enchants(stack, 25, quality - 1, 3)
		paid[quality] = grug_traders.stack_sell_price(stack)
	end
	check(paid[1] == 8 and paid[2] == 24 and paid[3] == 48, "I a dropped sword sells for 8 / 24 / 48c")
	local plain = ItemStack("grug_gear:sword_steel")
	check(grug_traders.stack_sell_price(plain) == 8, "I a plain stack sells at the Common payout")
	local trade = read_file(ROOT .. "/mods/ENTITIES/grug_traders/trade.lua")
	local _, uses = trade:gsub("grug_traders%.stack_sell_price%(stack%)", "")
	check(uses == 2 and not trade:find("sell_price%(stack:get_name%(%)%)"),
		"I the sell tab and the sale price each stack")
end

------------------------------------------------------------------------------
-- J. The Kraken.
------------------------------------------------------------------------------
do
	local def
	grug_mobs.register_mob = function(name, d)
		if name == "grug_mobs:kraken" then def = d end
	end
	mobs = {spawn = function() end}
	grug_zones = {water_class_at = function() return "deep_ocean" end}
	dofile(ROOT .. "/mods/ENTITIES/grug_mobs/kraken.lua")
	check(def ~= nil and def._grug_fixed_level == 70 and def._grug_tier == "elite",
		"J the Kraken is a level-70 elite")
	check(def and def.armor == nil, "J ...with the elite tier's armor")
	check(def and def._grug_no_quality_loot == true and #def.drops == 0,
		"J ...and nothing to drop")
	-- No item and no bag, even with the bag chance forced to 100 %.
	local saved = grug_items.BAG_DROPS.chance
	grug_items.BAG_DROPS.chance = 100
	local mob = {name = "grug_mobs:kraken", _grug_tier = def._grug_tier,
		_grug_level = def._grug_fixed_level, _grug_no_quality_loot = def._grug_no_quality_loot,
		object = {get_pos = function() return {x = 0, y = 0, z = 0} end}}
	local any = 0
	for index = 1, 2000 do any = any + #grug_items.roll_mob_gear(mob, seed_of(index)) end
	added = {}
	for _ = 1, 200 do loot_hook(mob, "org") end
	grug_items.BAG_DROPS.chance = saved
	check(any == 0 and #added == 0, "J the Kraken drops no item and no bag")
	-- Its kill XP through the real level engine.
	core.settings = {get = function() return nil end}
	dofile(ROOT .. "/mods/PLAYER/grug_xp/init.lua")
	dofile(ROOT .. "/mods/ENTITIES/grug_mobs/levels.lua")
	grug_mobs.register_level_cfg("grug_mobs:kraken", def)
	check(grug_mobs.kill_xp(mob, 60) == 0 and grug_mobs.kill_xp(mob, 30) == 0,
		"J its kill XP is 0")
	-- (an ordinary level-70 elite pays, so the 0 is the Kraken's own)
	check(grug_mobs.kill_xp({name = "grug_mobs:other", _grug_level = 70,
		_grug_tier = "elite"}, 60) == 4 * grug_xp.mob_xp(65), "J ...an ordinary elite's is not")
end

if failures > 0 then
	print(("R33 C1 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R33 C1 PORTABLE PASS checks=%d"):format(checks))
