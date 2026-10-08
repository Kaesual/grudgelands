-- Round 33 lane C4 portable test (LuaJIT): enchant tiers, upgrades, the
-- crown and the profession families (round33-plan.md §2.3-2.5, §2.9a;
-- docs/design/item_tiers.md §1-§4).
--
-- Loads the REAL grug_gear and grug_quality (init.lua), grug_jobs'
-- station_operations.lua, registry.lua and state.lua, grug_professions'
-- enchant_data.lua, enchants.lua and tailor.lua, grug_artisans' enchants.lua
-- and goldsmith.lua and grug_materials' registry.lua under engine stubs with
-- real ItemStack metadata semantics:
--   A. the value rule at the tier tops, on plain bases, at sample item levels
--      per tier, with the tier cap and T7 (item_tiers.md §1.1 tables);
--   B. the tier is stored per enchant and shown in the tooltip; a found
--      enchant has the item's tier and exactly the rule's value (no roll),
--      boss drops at 65/70 carry T7;
--   C. an enchant at the station: the recipe's tier, its value at the item's
--      level, the same enchant refused, the weaker-overwrite warning
--      ("Replaces T7 Strength with T6 Strength."), none for a stronger one;
--   D. upgrades: item level 10 x tier, the requirement, enchants follow,
--      never lower (at the top, crowned, boss drops), only the recipe's
--      tier, only the profession's families; each awards profession
--      progress through award_progress;
--   E. the crown: tier top + 5, every enchant +1 tier (T7 at most), once per
--      item, refusals (crowned, would lower, would change nothing, no
--      equipment), the preview text;
--   F. families: bow enchants and upgrades at the Leatherworker (leather),
--      spellbooks at the Tailor (bolts; the recipe 2 bolts + Parchment, no
--      mastery band since Round 45), the Woodcarver keeps staves and wands;
--      every enchant
--      takes its channel's loot, every upgrade 2 own materials + the two
--      signatures of upgrades.json; the data files equal tools/r33_ds;
--   G. the Goldsmith: no Ornament Components, no spellbook, Cut Citrine is
--      the T1 trinket gem, no Cut Quartz (raw Quartz stays a T1 input);
--   H. zone leaders and war-camp captains roll the named/elite row
--      (10 / 10 / 5 %), an ordinary mob the normal row.
--
--   luajit tools/r33_c4/portable_test.lua [REPO]
-- Prints "R33 C4 PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
-- The data files are plain JSON with identifier keys: enough for a Lua table.
local function decode_json(text)
	local lua = text:gsub("%[", "{"):gsub("%]", "}"):gsub('"([%w_]+)"%s*:', "%1 =")
	return assert(loadstring("return " .. lua))()
end
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = table.copy(child) end
	return out
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
}
local current_mod = "grug_gear"
local serial = {}
core = permissive({
	register_on_mods_loaded = function() end,
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
	serialize = function(value) serial[#serial + 1] = table.copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and table.copy(serial[index]) or nil
	end,
	get_us_time = function() return 1 end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
})
local garrison = {pvp_kind = function(name)
	return name:find("^grug_mobs:captain_") and "captain" or nil
end}
local LEADER_SUBTYPE = "grug_mobs:bandit_chief"
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	pool_percent_amount = function() return 42 end})
grug_mobs = permissive({
	register_kill_loot_hook = function() end,
	register_boss_reward_hook = function() end,
	subtype = function(name) return name == LEADER_SUBTYPE and {leader = true} or nil end,
	pvp_garrison = garrison,
})
grug_inventory = permissive({})
grug_xp = permissive({get_level = function() return 60 end})

local function new_meta(fields)
	local store = {}
	for key, value in pairs(fields or {}) do store[key] = value end
	local meta = {fields = store}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value)
		if value == "" then store[key] = nil else store[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(store[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
local function new_stack(name, fields, count)
	local meta = new_meta(fields)
	count = count or (name == "" and 0 or 1)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" or count == 0 end
	function stack:get_count() return count end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	return stack
end
ItemStack = function(value)
	if type(value) == "table" then
		return new_stack(value:get_name(), value:get_meta().fields, value:get_count())
	end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)$")
	return new_stack(name, nil, tonumber(count))
end
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
current_mod = "grug_quality"

-- grug_jobs as the station operations need it; the real registration below.
local can_craft = true
grug_jobs = {
	PROFESSIONS = {weaponsmith = {}, armorsmith = {}, tailor = {}, leatherworker = {},
		woodcarver = {}, goldsmith = {}},
	station_info = function(station) return {id = station} end,
	can_craft_recipe = function() return can_craft, "Weaponsmith tier 6 required." end,
	_flatten_inputs = function(value)
		local out = {}
		local function walk(node)
			if type(node) == "string" then
				if node ~= "" then out[#out + 1] = node end
			elseif type(node) == "table" then
				for index = 1, #node do walk(node[index]) end
			end
		end
		walk(value)
		return out
	end,
}
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/station_operations.lua")
local Q = grug_items

------------------------------------------------------------------------------
-- A. The value rule (item_tiers.md §1.1 tables).
------------------------------------------------------------------------------
local TOPS = {
	str = {3, 5, 8, 11, 15, 19, 21, 24},
	dex = {2, 4, 6, 8, 10, 13, 14, 15},
	int = {3, 5, 8, 11, 15, 19, 21, 24},
	crit_percent = {2.1, 2.6, 3.0, 3.5, 3.9, 4.3, 4.6, 4.8},
	attack_speed_percent = {2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.2, 4.4},
	max_hp_percent = {2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.2, 4.4},
	max_mana_percent = {2.5, 2.8, 3.1, 3.4, 3.7, 4.0, 4.2, 4.3},
	dodge_percent = {1.8, 2.1, 2.5, 2.8, 3.1, 3.4, 3.6, 3.7},
	armor_rating = {0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.2, 5.6},
}
local BASES = {
	str = {1, 3, 5, 8, 11, 15}, dex = {1, 2, 4, 6, 8, 10}, int = {1, 3, 5, 8, 11, 15},
	crit_percent = {1.7, 2.2, 2.6, 3.1, 3.5, 3.9},
	attack_speed_percent = {1.6, 2.0, 2.4, 2.8, 3.2, 3.6},
	max_hp_percent = {1.6, 2.0, 2.4, 2.8, 3.2, 3.6},
	max_mana_percent = {2.2, 2.5, 2.8, 3.1, 3.4, 3.7},
	dodge_percent = {1.5, 1.9, 2.2, 2.5, 2.8, 3.1},
	armor_rating = {0.5, 0.9, 1.7, 2.5, 3.3, 4.1},
}
local BASE_ILVL = {1, 11, 21, 31, 41, 51}
for stat, row in pairs(TOPS) do
	for tier = 1, 6 do
		check(near(Q.enchant_value(stat, 10 * tier, tier), row[tier]),
			"A " .. stat .. " T" .. tier .. " at its top")
		check(near(Q.enchant_top_value(stat, tier), row[tier]), "A " .. stat .. " top value T" .. tier)
		check(near(Q.enchant_value(stat, BASE_ILVL[tier], tier), BASES[stat][tier]),
			"A " .. stat .. " T" .. tier .. " on a plain base")
		-- The cap: any higher item level reads the tier's top.
		for _, ilvl in ipairs({10 * tier + 1, 10 * tier + 5, 60, 65, 70}) do
			if ilvl > 10 * tier then
				check(near(Q.enchant_value(stat, ilvl, tier), row[tier]),
					"A " .. stat .. " T" .. tier .. " capped at item level " .. ilvl)
			end
		end
	end
	check(near(Q.enchant_value(stat, 65, 7), row[7]), "A " .. stat .. " T7 at 65")
	check(near(Q.enchant_value(stat, 70, 7), row[8]), "A " .. stat .. " T7 at 70")
	check(near(Q.enchant_value(stat, 75, 7), row[8]), "A " .. stat .. " clamps at 70")
	local last = -1
	for ilvl = 1, 70 do
		local value = Q.enchant_value(stat, ilvl, 7)
		check(value >= last, "A " .. stat .. " never falls (" .. ilvl .. ")")
		last = value
	end
end
-- Sample levels inside a tier: the curve, not a band.
eq(Q.enchant_value("str", 25, 3), 6, "A Strength T3 at 25")
eq(Q.enchant_value("str", 25, 6), 6, "A a T6 enchant on a level-25 item reads 25")
eq(Q.enchant_value("crit_percent", 37, 4), 3.3, "A Crit T4 at 37")
eq(Q.enchant_value("armor_rating", 1, 1), 0.5, "A armor keeps its minimum")
eq(Q.enchant_value("dex", 1, 1), 1, "A Dexterity keeps its minimum")
eq(Q.enchant_tier(10), 1, "A item level 10 is T1")
eq(Q.enchant_tier(11), 2, "A item level 11 is T2")
eq(Q.enchant_tier(60), 6, "A item level 60 is T6")
eq(Q.enchant_tier(65), 7, "A item level 65 is T7")
eq(Q.BANDS, nil, "A the four flat value bands are gone")
eq(Q.ENCHANT_VALUES, nil, "A the fixed crafted values are gone")

------------------------------------------------------------------------------
-- B. Tier stored and shown; found enchants at the item's tier.
------------------------------------------------------------------------------
local function affixes_of(stack) return Q.get_affixes(stack) end
local function description(stack) return stack:get_meta():get_string("description") end
local found_ok, found_count = true, 0
for ilvl = 1, 60, 3 do
	for seed = 1, 8 do
		local stack = ItemStack("grug_gear:chest_leather_cured")
		Q.roll_enchants(stack, ilvl, 2, seed * 7919 + ilvl)
		for _, affix in ipairs(affixes_of(stack)) do
			found_count = found_count + 1
			found_ok = found_ok and affix.tier == Q.enchant_tier(ilvl) and
				near(affix.value, Q.enchant_value(affix.stat, ilvl, affix.tier))
		end
	end
end
check(found_count > 300 and found_ok, "B every found enchant has the item's tier and the rule's value")
do
	local stack = ItemStack("grug_gear:sword_silversteel")
	Q.roll_enchants(stack, 37, 2, 4242)
	local text = description(stack)
	local affixes = affixes_of(stack)
	eq(#affixes, 2, "B a gold drop has two enchants")
	for _, affix in ipairs(affixes) do
		eq(affix.tier, 4, "B item level 37 rolls T4 (" .. affix.stat .. ")")
		local label = Q.AFFIXES[affix.stat].label
		check(text:find("+" .. Q.format_enchant_value(affix.stat, affix.value), 1, true) and
			text:find(label .. " (T4", 1, true), "B tooltip shows value and tier of " .. affix.stat)
	end
	-- The same seed gives the same item (deterministic rolls stay).
	local again = ItemStack("grug_gear:sword_silversteel")
	Q.roll_enchants(again, 37, 2, 4242)
	eq(description(again), text, "B a seed reproduces its item")
	-- One decimal for the percentage stats and armor.
	eq(Q.format_enchant_value("max_hp_percent", 4), "4.0", "B HP shows one decimal")
	eq(Q.format_enchant_value("armor_rating", 4.8), "4.8", "B armor shows one decimal")
	eq(Q.format_enchant_value("str", 19), "19", "B attributes stay whole")
end
local function boss(kind)
	local id = kind == "dragon" and "dragon:ice" or "king:accord"
	return {name = "grug_mobs:boss", _grug_tier = "boss", _grug_level = 70,
		_grug_boss_id = id, _grug_royal_king = kind ~= "dragon"}
end
for _, kind in ipairs({"king", "dragon"}) do
	local all_t7 = true
	for seed = 1, 40 do
		for _, stack in ipairs(Q.roll_mob_gear(boss(kind), seed * 104729)) do
			if not stack:get_name():find("^grug_inventory:bag_") then
				local ilvl = stack:get_meta():get_int("grug_ilvl")
				for _, affix in ipairs(affixes_of(stack)) do
					all_t7 = all_t7 and affix.tier == 7 and
						near(affix.value, Q.enchant_value(affix.stat, ilvl, 7))
				end
			end
		end
	end
	check(all_t7, "B " .. kind .. " drops carry T7 enchants at their item level")
end
-- A stored enchant without a tier is no enchant (fresh-server data only).
do
	local stack = ItemStack("grug_gear:sword_steel")
	stack:get_meta():set_string("grug_ench", core.serialize({{channel = "prefix",
		stat = "str", value = 3}}))
	eq(#affixes_of(stack), 0, "B an enchant needs its tier")
end

------------------------------------------------------------------------------
-- Families: the real enchant and upgrade registrations.
------------------------------------------------------------------------------
local data = dofile(ROOT .. "/mods/ITEMS/grug_professions/enchant_data.lua")
grug_professions = {
	enchant_data = data,
	read_json = function(name)
		return decode_json(read_file("mods/ITEMS/grug_professions/data/" .. name))
	end,
}
dofile(ROOT .. "/mods/ITEMS/grug_professions/enchants.lua")
dofile(ROOT .. "/mods/ITEMS/grug_artisans/enchants.lua")
local P = grug_professions
local operations = grug_jobs.station_operations()
local ENCHANTS = decode_json(read_file("mods/ITEMS/grug_professions/data/enchants.json"))
local UPGRADES = decode_json(read_file("mods/ITEMS/grug_professions/data/upgrades.json"))

------------------------------------------------------------------------------
-- C. Enchanting at the station.
------------------------------------------------------------------------------
local player = {get_player_name = function() return "smith" end}
local function plan(id, item, extra_inputs)
	local recipe = assert(grug_jobs.station_operation(id), id)
	local inputs = {item}
	for _, token in ipairs(recipe.flat_inputs) do inputs[#inputs + 1] = ItemStack(token) end
	for _, stack in ipairs(extra_inputs or {}) do inputs[#inputs + 1] = stack end
	return Q.operation_plan(recipe, inputs, player)
end
local function crafted(name, ilvl)
	local stack = ItemStack(name)
	Q.crafted_output(stack)
	if ilvl then Q.roll_enchants(stack, ilvl, 0, 1) end
	return stack
end
local function affix_on(stack, channel)
	for _, affix in ipairs(affixes_of(stack)) do
		if affix.channel == channel then return affix end
	end
end

local ember_sword = crafted("grug_gear:sword_embersteel")
eq(ember_sword:get_meta():get_int("grug_ilvl"), 41, "C a crafted T5 sword is item level 41")
local result = plan("enchant:sword:prefix:str:t5", ember_sword)
check(result ~= nil, "C a T5 Strength enchant applies")
local str = affix_on(result.output, "prefix")
eq(str and str.tier, 5, "C the enchant carries the recipe's tier")
eq(str and str.value, 11, "C its value is the rule at item level 41")
eq(result.warning, nil, "C a first enchant warns of nothing")
eq(result.output:get_meta():get_int("grug_quality"), 2, "C one enchant is Uncommon")
check(description(result.output):find("+11 Strength (T5)", 1, true),
	"C the tooltip names the tier")
eq(result.consume[1], 1, "C the item is consumed from the grid")
local enchanted = result.output
result = plan("enchant:sword:suffix:crit_percent:t4", enchanted)
check(result and affix_on(result.output, "suffix").tier == 4 and
	near(affix_on(result.output, "suffix").value, 3.5), "C a T4 Crit suffix at item level 41")
enchanted = result.output
local _, reason = plan("enchant:sword:prefix:str:t5", enchanted)
eq(reason, "This enchantment would not change the item.", "C the same enchant is refused")
_, reason = plan("enchant:sword:suffix:str:t5", enchanted)
eq(reason, "The other channel already uses this stat.", "C one stat per item")
result = plan("enchant:sword:prefix:str:t3", enchanted)
eq(result and result.warning, "Replaces T5 Strength with T3 Strength.",
	"C a weaker Strength warns")
result = plan("enchant:sword:prefix:dex:t4", enchanted)
eq(result and result.warning, "Replaces T5 Strength with T4 Dexterity.",
	"C a lower tier of another stat warns")
result = plan("enchant:sword:suffix:crit_percent:t5", enchanted)
check(result and result.warning == nil, "C a stronger replacement does not warn")
_, reason = plan("enchant:sword:prefix:str:t6", enchanted)
eq(reason, "The item tier must be at least the enchantment tier.",
	"C an enchant above the item's tier is refused")
_, reason = plan("enchant:sword:prefix:str:t5", enchanted, {ItemStack("default:dirt")})
eq(reason, "Remove unrelated items from the station.", "C unrelated items are refused")
can_craft = false
_, reason = plan("enchant:sword:prefix:str:t5", enchanted)
eq(reason, "Weaponsmith tier 6 required.", "C the profession gate still decides")
can_craft = true

------------------------------------------------------------------------------
-- D. Upgrades.
------------------------------------------------------------------------------
result = plan("upgrade:weaponsmith:t5", enchanted)
check(result ~= nil, "D a T5 sword upgrades at the Weaponsmith's T5 upgrade")
local upgraded = result.output
local meta = upgraded:get_meta()
eq(meta:get_int("grug_ilvl"), 50, "D the item level becomes 10 x tier")
eq(meta:get_int("grug_req_level"), 50, "D the requirement follows")
eq(affix_on(upgraded, "prefix").tier, 5, "D the enchant keeps its tier")
eq(affix_on(upgraded, "prefix").value, 15, "D Strength follows to its item-level-50 value")
check(near(affix_on(upgraded, "suffix").value, 3.5), "D T4 Crit stays at its cap (3.5)")
eq(meta:get_int("grug_quality"), 3, "D the quality stays")
check(description(upgraded):find("Item level 50", 1, true), "D the tooltip shows item level 50")
_, reason = plan("upgrade:weaponsmith:t5", upgraded)
eq(reason, "The item is already at item level 50 or higher.", "D never twice, never lower")
_, reason = plan("upgrade:weaponsmith:t6", crafted("grug_gear:sword_embersteel"))
eq(reason, "This upgrade takes tier 6 items.", "D only the recipe's material tier")
_, reason = plan("upgrade:armorsmith:t5", crafted("grug_gear:sword_embersteel"))
eq(reason, "Insert an item of the selected family.", "D only the profession's families")
local book = crafted("grug_gear:spellbook_iron")
result = plan("upgrade:tailor:t2", book)
eq(result and result.output:get_meta():get_int("grug_ilvl"), 20, "D the Tailor upgrades a spellbook")
local bow = crafted("grug_gear:bow_bronze")
result = plan("upgrade:leatherworker:t1", bow)
eq(result and result.output:get_meta():get_int("grug_ilvl"), 10, "D the Leatherworker upgrades a bow")
eq(result and result.output:get_meta():get_int("grug_req_level"), 10,
	"D a first-bracket item upgraded to 10 requires level 10")
local trinket = crafted(grug_gear.trinket_item("manawell", 3))
result = plan("upgrade:goldsmith:t3", trinket)
eq(result and result.output:get_meta():get_int("grug_ilvl"), 30, "D the Goldsmith upgrades a trinket")
-- A boss drop (65/70) is never lowered.
local boss_item
for seed = 1, 50 do
	for _, stack in ipairs(Q.roll_mob_gear(boss("king"), seed)) do
		if stack:get_name():find("^grug_gear:sword_") then boss_item = boss_item or stack end
	end
end
check(boss_item ~= nil, "D a King drops a sword in 50 kills")
if boss_item then
	_, reason = plan("upgrade:weaponsmith:t6", boss_item)
	eq(reason, "The item is already at item level 60 or higher.", "D a boss drop is refused")
end
-- Every upgrade is a progress craft: the real grug_jobs state awards it.
for _, op in ipairs(operations) do
	if op.operation == "upgrade" then
		check(op.progress == true and op.station_operation == true,
			op.id .. " counts as progress and is keyed by id")
	end
end

------------------------------------------------------------------------------
-- E. The crown.
------------------------------------------------------------------------------
do
	-- A T5 sword at 41 with T5 Strength and T4 Crit: 55, T6 and T5.
	local item = enchanted
	local text = Q.crown_preview(item)
	eq(text, "Item level 41 becomes 55. T5 Strength becomes T6. T4 Crit becomes T5.",
		"E the preview text")
	local crowned, shown = Q.crown_item(item, player)
	check(crowned ~= nil and shown == text, "E the crown applies")
	local cm = crowned:get_meta()
	eq(cm:get_int("grug_ilvl"), 55, "E item level = tier top + 5")
	eq(cm:get_int("grug_req_level"), 55, "E the requirement follows")
	eq(cm:get_int("grug_crowned"), 1, "E the item is marked crowned")
	eq(affix_on(crowned, "prefix").tier, 6, "E Strength +1 tier")
	eq(affix_on(crowned, "prefix").value, 17, "E T6 Strength reads its item-level-55 value")
	eq(affix_on(crowned, "suffix").tier, 5, "E Crit +1 tier")
	check(description(crowned):find("Crowned", 1, true), "E the tooltip says Crowned")
	eq(item:get_meta():get_int("grug_crowned"), 0, "E the crown works on a copy")
	local again, why = Q.crown_item(crowned)
	check(again == nil and why == "This item is already crowned.", "E once per item")
	_, why = plan("upgrade:weaponsmith:t5", crowned)
	eq(why, "The item is already at item level 50 or higher.",
		"E a crowned item above its tier top is not upgraded")
	-- An upgraded T6 item with T6 enchants reaches T7 at 65.
	local abyssal = crafted("grug_gear:sword_abyssal_steel")
	abyssal = plan("enchant:sword:prefix:str:t6", abyssal).output
	abyssal = plan("upgrade:weaponsmith:t6", abyssal).output
	local top = Q.crown_item(abyssal)
	eq(top:get_meta():get_int("grug_ilvl"), 65, "E a T6 item crowns to 65")
	eq(affix_on(top, "prefix").tier, 7, "E T6 becomes T7")
	eq(affix_on(top, "prefix").value, 21, "E a crowned T7 Strength reads its item-level-65 value")
	-- Re-enchanting a crowned item warns about the lost T7.
	result = plan("enchant:sword:prefix:str:t6", top)
	eq(result and result.warning, "Replaces T7 Strength with T6 Strength.",
		"E the crowned T7 overwrite warns")
	-- Refusals.
	if boss_item then
		local refused, boss_why = Q.crown_item(boss_item)
		local ilvl = boss_item:get_meta():get_int("grug_ilvl")
		check(refused == nil and boss_why == "The crown would change nothing on this item.",
			"E a level-" .. ilvl .. " boss drop changes nothing")
	end
	local dragon_item
	for seed = 1, 50 do
		for _, stack in ipairs(Q.roll_mob_gear(boss("dragon"), seed)) do
			if stack:get_name():find("^grug_gear:") then dragon_item = dragon_item or stack end
		end
	end
	local refused, dragon_why = Q.crown_item(dragon_item)
	check(refused == nil and dragon_why == "The crown would lower this item's level (70 to 65).",
		"E a level-70 dragon drop would be lowered")
	local _, tool_why = Q.crown_preview(ItemStack("grug_materials:pick_bronze"))
	check(tool_why ~= nil, "E a tool or non-item is refused")
	local _, empty_why = Q.crown_preview(ItemStack(""))
	eq(empty_why, "Hand over the item to crown.", "E nothing to crown")
	-- An enchant-only crown (a re-enchanted King drop at 65: T6 below T7)
	-- leaves the item level out of the preview.
	if boss_item then
		local reenchanted = plan("enchant:sword:prefix:str:t6", boss_item)
		if check(reenchanted ~= nil, "E a King drop takes a T6 enchant") then
			local item = reenchanted.output
			local text = Q.crown_preview(item)
			check(text ~= nil and not text:find("Item level", 1, true) and
				text:find("T6 Strength becomes T7.", 1, true) ~= nil,
				"E an enchant-only crown names no item level (" .. tostring(text) .. ")")
			local crowned = Q.crown_item(item)
			check(crowned and crowned:get_meta():get_int("grug_ilvl") == 65 and
				affix_on(crowned, "prefix").tier == 7, "E the enchant-only crown applies")
		end
	end
	-- A plain item is crowned too: only its item level rises.
	local plain = Q.crown_item(crafted("grug_gear:chest_cloth_patch"))
	eq(plain and plain:get_meta():get_int("grug_ilvl"), 15, "E a plain T1 item crowns to 15")
end

------------------------------------------------------------------------------
-- F. Families and inputs.
------------------------------------------------------------------------------
local LEATHERS = {"grug_mobs:light_leather", "grug_professions:cured_leather",
	"grug_mobs:heavy_leather", "grug_mobs:scaled_hide", "grug_professions:sleek_leather",
	"grug_professions:nightscale_leather"}
local BOLTS = {"patch", "woven", "heavy", "silkweave", "silk", "stormweave"}
local OWNER = {sword = "weaponsmith", dagger = "weaponsmith", greataxe = "weaponsmith",
	metal_armor = "armorsmith", shield = "armorsmith", caster_weapon = "woodcarver",
	bow = "leatherworker", leather_armor = "leatherworker", cloth_armor = "tailor",
	spellbook = "tailor", trinket = "goldsmith"}
local STATION = {weaponsmith = "forge", armorsmith = "forge", woodcarver = "carving_bench",
	leatherworker = "tanning_rack", tailor = "tailor_bench", goldsmith = "jewellers_bench"}
local enchant_count, upgrade_count, family_ok, loot_ok = 0, 0, true, true
local upgrades_seen = {}
for _, op in ipairs(operations) do
	if op.operation == "enchant" then
		enchant_count = enchant_count + 1
		family_ok = family_ok and OWNER[op.family] == op.profession and
			STATION[op.profession] == op.station
		loot_ok = loot_ok and op.flat_inputs[2] ==
			ENCHANTS[op.tier][op.enchant_channel .. "_loot"][op.enchant_stat] and
			op.flat_inputs[3] == ENCHANTS[op.tier].family_input[op.family]
		if op.family == "bow" then
			eq(op.flat_inputs[1], LEATHERS[op.tier], "F " .. op.id .. " takes the leather grade")
		elseif op.family == "spellbook" then
			eq(op.flat_inputs[1], "grug_professions:bolt_" .. BOLTS[op.tier],
				"F " .. op.id .. " takes the bolt")
		end
	else
		upgrade_count = upgrade_count + 1
		upgrades_seen[op.profession .. ":" .. op.tier] = op
	end
end
eq(enchant_count, 588, "F 588 enchant operations")
check(family_ok, "F every family is enchanted by its owner at its station")
check(loot_ok, "F every enchant takes its channel's loot and the family input")
eq(upgrade_count, 36, "F one upgrade per profession and tier")
for _, row in ipairs(UPGRADES) do
	local op = upgrades_seen[row.profession .. ":" .. row.tier]
	if check(op ~= nil, "F upgrade " .. row.profession .. " T" .. row.tier .. " registered") then
		eq(table.concat(op.families, ","), table.concat(row.families, ","),
			"F " .. op.id .. " families")
		eq(STATION[row.profession], op.station, "F " .. op.id .. " station")
		local inputs = op.flat_inputs
		check(#inputs == 4 and inputs[1] == inputs[2] and inputs[3] == row.signatures[1] and
			inputs[4] == row.signatures[2], "F " .. op.id .. " takes 2 own + the two signatures")
	end
end
eq(upgrades_seen["leatherworker:1"].flat_inputs[1], LEATHERS[1], "F Leatherworker upgrades with leather")
eq(upgrades_seen["tailor:4"].flat_inputs[1], "grug_professions:bolt_silkweave",
	"F Tailor upgrades with the bolt")
eq(upgrades_seen["woodcarver:2"].flat_inputs[1], "grug_artisans:polished_wood",
	"F Woodcarver upgrades with wood")
eq(upgrades_seen["goldsmith:6"].flat_inputs[1], "grug_artisans:setting_gold_filigreed_abyssal_steel",
	"F Goldsmith upgrades with the setting")
eq(table.concat(P.FAMILY_OWNERS.woodcarver, ","), "caster_weapon", "F the Woodcarver keeps staves and wands")
eq(read_file("mods/ITEMS/grug_professions/data/enchants.json"),
	read_file("tools/r33_ds/enchants_r33.json"), "F enchants.json is the data design's")
eq(read_file("mods/ITEMS/grug_professions/data/upgrades.json"),
	read_file("tools/r33_ds/upgrades_r33.json"), "F upgrades.json is the data design's")
check(not pcall(data.validate_upgrades, {UPGRADES[1]}, P.FAMILY_OWNERS),
	"F an incomplete upgrade table fails the load")
do
	local rows = decode_json(read_file("mods/ITEMS/grug_professions/data/upgrades.json"))
	rows[1].families = {"sword"}
	check(not pcall(data.validate_upgrades, rows, P.FAMILY_OWNERS),
		"F an upgrade naming foreign families fails the load")
end
-- The station names an enchant by its tier's top ("up to").
eq(grug_jobs.station_operation("enchant:sword:prefix:str:t6").label,
	"Heavy — prefix T6 Strength (up to +19)", "F the selector label")
eq(grug_jobs.station_operation("enchant:spellbook:suffix:max_mana_percent:t2").label,
	"of the Raven — suffix T2 maximum Mana (up to +2.8%)", "F a percentage label")

-- The spellbook recipe at the Tailor.
do
	local recipes = {}
	local stub = {
		register_item = function(name) return name end,
		register_ingredient = function() end,
		register_recipe = function(profession, definition)
			definition.profession = profession
			recipes[#recipes + 1] = definition
		end,
	}
	local env = setmetatable({grug_professions = stub,
		grug_jobs = {DURATIONS = {gear = 3, bag = 3, material = 1}},
		core = {register_craft = function() end}}, {__index = _G})
	local chunk = assert(loadfile(ROOT .. "/mods/ITEMS/grug_professions/tailor.lua"))
	setfenv(chunk, env)
	chunk()
	local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
	for tier = 1, 6 do
		local found
		for _, recipe in ipairs(recipes) do
			if recipe.output == "grug_gear:spellbook_" .. METALS[tier] then found = recipe end
		end
		if check(found ~= nil, "F the Tailor binds the T" .. tier .. " spellbook") then
			local bolt = "grug_professions:bolt_" .. BOLTS[tier]
			local parts = {}
			for index, entry in ipairs(found.ingredients) do
				parts[index] = entry.item .. "*" .. entry.n
			end
			eq(table.concat(parts, ","), bolt .. "*2,grug_professions:parchment*1",
				"F T" .. tier .. " spellbook takes two bolts and a Parchment")
			check(found.profession == "tailor" and found.tier == tier and found.time == 3 and
				found.mastery_required == nil,
				"F T" .. tier .. " spellbook: a Tailor recipe of its tier, 3 s, no mastery band")
		end
	end
end

------------------------------------------------------------------------------
-- G. The Goldsmith's leftovers.
------------------------------------------------------------------------------
do
	local env_registry = setmetatable({grug_materials = {},
		core = {get_modpath = function() return nil end}}, {__index = _G})
	local chunk = assert(loadfile(ROOT .. "/mods/ITEMS/grug_materials/registry.lua"))
	setfenv(chunk, env_registry)
	chunk()
	local M = env_registry.grug_materials
	eq(M.RESOURCE_BY_KEY.quartz.cut_item, nil, "G Quartz has no cut form")
	local recipes, items, tiers = {}, {}, {}
	local A = {
		register_ingredient = function(item, tier) tiers[item] = tier end,
		register_recipe = function(profession, definition) recipes[#recipes + 1] = definition end,
		register_item = function(name) items[#items + 1] = name; return name end,
	}
	local env = setmetatable({grug_artisans = A,
		grug_materials = {RESOURCES = M.RESOURCES, register_on_harvest = function() end},
		grug_gear = {trinket_item = function(key, tier) return "trinket:" .. key .. ":" .. tier end},
		grug_jobs = {has = function() return true end, DURATIONS = {gear = 3, material = 1},
			ingredient_list = function(tokens)
				local list = {}
				for _, token in ipairs(tokens) do list[#list + 1] = {item = token, n = 1} end
				return list
			end},
		grug_items = {mastery_band = function() return 1 end},
		core = {add_item = function() end, register_craft = function() end},
	}, {__index = _G})
	chunk = assert(loadfile(ROOT .. "/mods/ITEMS/grug_artisans/goldsmith.lua"))
	setfenv(chunk, env)
	chunk()
	local ornaments, books, quartz_cut, t1_gems = 0, 0, 0, nil
	for _, name in ipairs(items) do
		if name:find("ornament") then ornaments = ornaments + 1 end
	end
	for _, recipe in ipairs(recipes) do
		if recipe.output:find("ornament") then ornaments = ornaments + 1 end
		if recipe.output:find("^grug_gear:spellbook_") then books = books + 1 end
		if recipe.output:find("cut_quartz") then quartz_cut = quartz_cut + 1 end
		if recipe.output == "trinket:manawell:1" then
			local gems = {}
			for _, entry in ipairs(recipe.ingredients) do
				if entry.item:find("^grug_materials:cut_") then gems[#gems + 1] = entry.item end
			end
			t1_gems = table.concat(gems, ",")
		end
	end
	eq(ornaments, 0, "G no Ornament Components")
	eq(books, 0, "G the Goldsmith binds no spellbook")
	eq(quartz_cut, 0, "G no Cut Quartz recipe")
	eq(t1_gems, "grug_materials:cut_citrine", "G Cut Citrine is the T1 trinket gem")
	eq(tiers["grug_materials:quartz"], 1, "G raw Quartz stays a T1 ingredient")
	local quartz_in_enchants = false
	for _, row in ipairs(ENCHANTS) do
		for _, item in pairs(row.family_input) do
			quartz_in_enchants = quartz_in_enchants or item == "grug_materials:quartz"
		end
	end
	check(quartz_in_enchants, "G raw Quartz stays an enchant input")
end

------------------------------------------------------------------------------
-- H. Zone leaders and war-camp captains roll the named/elite row.
------------------------------------------------------------------------------
local function rates(mob, kills, salt)
	local counts = {0, 0, 0}
	for index = 1, kills do
		for _, stack in ipairs(Q.roll_mob_gear(mob, (index * 2654435761 + salt) % 2147483646 + 1)) do
			if not stack:get_name():find("^grug_inventory:bag_") then
				local quality = stack:get_meta():get_int("grug_quality")
				counts[quality] = counts[quality] + 1
			end
		end
	end
	return 100 * counts[1] / kills, 100 * counts[2] / kills, 100 * counts[3] / kills
end
local function close(value, target, tolerance) return math.abs(value - target) <= tolerance end
local N = 60000
for _, case in ipairs({
	{"placed zone leader", {name = "grug_mobs:wolf", _grug_tier = "normal", _grug_level = 24,
		_grug_leader = true}},
	{"leader sub-type", {name = LEADER_SUBTYPE, _grug_tier = "normal", _grug_level = 12}},
	{"camp captain", {name = "grug_mobs:captain_throng", _grug_tier = "normal", _grug_level = 38}},
}) do
	local white, blue, gold = rates(case[2], N, #case[1])
	print(("%s: %.2f %% white, %.2f %% blue, %.2f %% gold"):format(case[1], white, blue, gold))
	check(close(white, 10, 0.5) and close(blue, 10, 0.5) and close(gold, 5, 0.4),
		"H a " .. case[1] .. " rolls 10 / 10 / 5 %")
end
local white, blue, gold = rates({name = "grug_mobs:wolf", _grug_tier = "normal", _grug_level = 24}, N, 99)
check(close(white, 5, 0.4) and close(blue, 2, 0.25) and close(gold, 1, 0.2),
	"H an ordinary mob keeps 5 / 2 / 1 %")

------------------------------------------------------------------------------
-- Progress: the real grug_jobs state counts an upgrade like an enchant.
------------------------------------------------------------------------------
do
	-- Round 45: the station dialogs no longer apply operations (lane EU makes
	-- them jobs); the counting itself stays.
	local upgrade = grug_jobs.station_operation("upgrade:tailor:t1")
	local saved = grug_jobs
	_G.grug_jobs = {}
	grug_inventory = {refresh = function() end, refresh_character_tab = function() end}
	grug_xp = {get_level = function() return 5 end}
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/state.lua")
	local store = {}
	local meta_stub = {
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value) store[key] = value end,
		get_int = function(_, key) return tonumber(store[key]) or 0 end,
		set_int = function(_, key, value) store[key] = value end,
	}
	local tailor = {get_meta = function() return meta_stub end,
		get_player_name = function() return "tailor" end}
	core.chat_send_player = function() end
	grug_jobs.learn(tailor, "tailor")
	grug_jobs.award_progress(tailor, upgrade)
	eq(grug_jobs.crafts_in_tier(tailor, "tailor"), 1, "progress: an upgrade awards one craft")
	_G.grug_jobs = saved
end

-- No Ornament Components anywhere in the game.
do
	local handle = io.popen("grep -rl 'ornament_components\\|cut_quartz' '" .. ROOT .. "/mods' 2>/dev/null")
	local hits = handle and handle:read("*a") or ""
	if handle then handle:close() end
	eq(hits, "", "G no Ornament Components or Cut Quartz in mods/")
end

if failures > 0 then
	print(("R33 C4 PORTABLE FAIL checks=%d failures=%d"):format(checks, failures))
	os.exit(1)
end
print(("R33 C4 PORTABLE PASS checks=%d"):format(checks))
