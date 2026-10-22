-- Round 56 lane AFFIX portable test (LuaJIT): the channel names in the
-- enchant lines and the enchant box's "Replaces:" line (round56-plan.md §2
-- ruling 12, §4 AFFIX; items_crafting.md §6b.4, §6b.5).
--
-- Loads the REAL grug_gear and grug_quality (init.lua), grug_jobs'
-- station_operations.lua and grug_professions' and grug_artisans' enchant
-- registrations under the engine stub of tools/r33_c4 (real ItemStack
-- metadata semantics):
--   A. the tooltip: a prefix only, a suffix only, both (the prefix line
--      first, also when the suffix was stored first), none; the amount at
--      the player's level stays inside the brackets; a trinket's suffix;
--   B. the enchant plan's `replaces`: the line of the enchant in the
--      recipe's channel, none for an empty channel (also with the other
--      channel filled), with the higher-tier warning beside it, and the
--      result's tooltip in its fixed order.
--
--   luajit tools/r56_affix/portable_test.lua [REPO]
-- Prints "R56 AFFIX PORTABLE PASS checks=<n>" or the failures (exit 1).

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
	ingredient_list = function(tokens)
		local list, at = {}, {}
		for _, token in ipairs(tokens) do
			if at[token] then list[at[token]].n = list[at[token]].n + 1
			else list[#list + 1] = {item = token, n = 1}; at[token] = #list end
		end
		return list
	end,
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

local function description(stack) return stack:get_meta():get_string("description") end
local function lines_of(stack)
	local out = {}
	for line in (description(stack) .. "\n"):gmatch("(.-)\n") do out[#out + 1] = line end
	return out
end
-- The enchant lines of a tooltip, in order.
local function affix_lines(stack)
	local out = {}
	for _, line in ipairs(lines_of(stack)) do
		if line:find("^Prefix: ") or line:find("^Suffix: ") then out[#out + 1] = line end
	end
	return out
end
-- A stack with the given enchants stored as is (any order), its tooltip built.
local function enchanted(name, affixes, player)
	local stack = ItemStack(name)
	Q.crafted_output(stack)
	local meta = stack:get_meta()
	local ilvl = Q.effective_ilvl(stack)
	for _, affix in ipairs(affixes) do
		affix.value = Q.enchant_value(affix.stat, ilvl, affix.tier)
	end
	meta:set_string("grug_ench", #affixes > 0 and core.serialize(affixes) or "")
	Q.regenerate_description(stack, player)
	return stack
end

------------------------------------------------------------------------------
-- A. The tooltip.
------------------------------------------------------------------------------
local SWORD = "grug_gear:sword_steel" -- T3, item level 21
do
	local prefix = enchanted(SWORD, {{channel = "prefix", stat = "str", tier = 2}})
	local lines = affix_lines(prefix)
	eq(#lines, 1, "A a prefix only: one enchant line")
	eq(lines[1], "Prefix: +5 Strength (T2)", "A the prefix line")
	eq(lines_of(prefix)[1], "Heavy Steel Sword", "A the name keeps its prefix word")

	local suffix = enchanted(SWORD, {{channel = "suffix", stat = "crit_percent", tier = 3}})
	lines = affix_lines(suffix)
	eq(#lines, 1, "A a suffix only: one enchant line")
	eq(lines[1], "Suffix: +2.6% Crit (T3)", "A the suffix line")

	local both = enchanted(SWORD, {{channel = "prefix", stat = "str", tier = 3},
		{channel = "suffix", stat = "dex", tier = 1}})
	lines = affix_lines(both)
	eq(#lines, 2, "A both: two enchant lines")
	eq(lines[1], "Prefix: +5 Strength (T3)", "A both: the prefix first")
	eq(lines[2], "Suffix: +2 Dexterity (T1)", "A both: the suffix second")

	-- Stored suffix first (no writer does it today): the tooltip keeps the order.
	local reversed = enchanted(SWORD, {{channel = "suffix", stat = "dex", tier = 1},
		{channel = "prefix", stat = "str", tier = 3}})
	eq(table.concat(affix_lines(reversed), "|"), table.concat(lines, "|"),
		"A the order is fixed, whatever the stored order")
	eq(description(reversed), description(both), "A ... and the whole tooltip is the same")

	local plain = enchanted(SWORD, {})
	eq(#affix_lines(plain), 0, "A none: no enchant line")
	check(not description(plain):find("Prefix", 1, true) and
		not description(plain):find("Suffix", 1, true), "A none: no channel word anywhere")

	-- The amount at the player's level stays inside the brackets.
	local hero = {get_player_name = function() return "hero" end}
	local hp = enchanted(SWORD, {{channel = "suffix", stat = "max_hp_percent", tier = 2}}, hero)
	eq(affix_lines(hp)[1], "Suffix: +2.4% maximum HP (T2; 42 at your level)",
		"A an HP suffix with its amount at the player's level")

	-- A trinket's single enchant may be its suffix.
	local trinket = enchanted(grug_gear.trinket_item("manawell", 2),
		{{channel = "suffix", stat = "max_mana_percent", tier = 2}})
	eq(table.concat(affix_lines(trinket), "|"), "Suffix: +2.5% maximum Mana (T2)",
		"A a trinket's suffix")
end

------------------------------------------------------------------------------
-- B. The enchant plan's "Replaces:" line.
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
local player = {get_player_name = function() return "smith" end}
local function plan(id, item)
	local recipe = assert(grug_jobs.station_operation(id), id)
	return Q.operation_plan(recipe, item, player)
end
do
	local sword = enchanted(SWORD, {})
	local result = plan("enchant:sword:prefix:str:t3", sword)
	eq(result and result.replaces, nil, "B an empty channel: no line")
	eq(result and result.warning, nil, "B ... and no warning")
	eq(table.concat(affix_lines(result.output), "|"), "Prefix: +5 Strength (T3)",
		"B the preview's tooltip names the prefix")

	-- The prefix filled: a suffix replaces nothing.
	local with_prefix = result.output
	result = plan("enchant:sword:suffix:crit_percent:t3", with_prefix)
	eq(result and result.replaces, nil, "B the other channel filled: no line")
	eq(table.concat(affix_lines(result.output), "|"),
		"Prefix: +5 Strength (T3)|Suffix: +2.6% Crit (T3)", "B the result lists prefix, suffix")

	-- The same channel: the line of the enchant it replaces.
	local full = result.output
	result = plan("enchant:sword:prefix:dex:t3", full)
	eq(result and result.replaces, "Replaces: Prefix: +5 Strength (T3)",
		"B a new prefix names the prefix it replaces")
	eq(result and result.warning, nil, "B ... an equal tier warns of nothing")
	eq(table.concat(affix_lines(result.output), "|"),
		"Prefix: +4 Dexterity (T3)|Suffix: +2.6% Crit (T3)", "B ... the result keeps the suffix")
	result = plan("enchant:sword:suffix:crit_percent:t1", full)
	eq(result and result.replaces, "Replaces: Suffix: +2.6% Crit (T3)",
		"B a new suffix names the suffix it replaces")
	-- A higher tier replaced: the line and the warning.
	eq(result and result.warning, "Replaces T3 Crit with T1 Crit.",
		"B ... a higher tier keeps its warning beside the line")
	result = plan("enchant:sword:prefix:str:t2", full)
	eq(result and result.replaces, "Replaces: Prefix: +5 Strength (T3)",
		"B the same stat at a lower tier names it too")
	eq(result and result.warning, "Replaces T3 Strength with T2 Strength.",
		"B ... with the warning")
	-- A higher tier replacing a lower one: the line, no warning.
	local low = plan("enchant:sword:prefix:str:t1", with_prefix).output
	result = plan("enchant:sword:prefix:str:t3", low)
	eq(result and result.replaces, "Replaces: Prefix: +3 Strength (T1)",
		"B a stronger enchant names the weaker one")
	eq(result and result.warning, nil, "B ... without a warning")
	-- The line carries no amount at the player's level (two lines in the box).
	local hp = plan("enchant:sword:suffix:max_hp_percent:t2", with_prefix).output
	result = plan("enchant:sword:suffix:crit_percent:t2", hp)
	eq(result and result.replaces, "Replaces: Suffix: +2.4% maximum HP (T2)",
		"B an HP suffix without the amount at the player's level")
	-- A refused enchant has no plan, so no line.
	local _, reason = plan("enchant:sword:prefix:str:t3", full)
	eq(reason, "This enchantment would not change the item.", "B a no-op is refused")
end

if failures > 0 then
	error(("R56 AFFIX PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R56 AFFIX PORTABLE PASS checks=%d"):format(checks))
