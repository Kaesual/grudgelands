-- Round 57 lane QSYS, the grug_quality part (LuaJIT; run by
-- tools/r57_qsys/portable_test.lua, also alone): the two public functions
-- the quest rewards and the recipe details use (quests.md "Choice
-- rewards", items_crafting.md):
--   A. grug_items.check_affixes: the pools per family and channel, one
--      enchant per channel, no enchants on tools and plain items;
--   B. grug_items.make_stack: an authored item at a given item level with
--      fixed enchants (their values, the quality, the name, the tooltip;
--      the receiver's lines with a player);
--   C. grug_items.tooltip_text: the lines a stack shows, on a copy; a plain
--      registered item its description, an unknown one its name.
-- The engine stub is tools/r56_affix's (real grug_gear and grug_quality).
--
--   luajit tools/r57_qsys/quality_test.lua [REPO]
-- Prints "R57 QSYS QUALITY PASS checks=<n>" or the failures (exit 1).

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

local Q = grug_items

local function description(stack) return stack:get_meta():get_string("description") end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. " in " .. ("%q"):format(tostring(text)) .. ")")
end
-- A tool and a plain item next to the gear.
core.register_tool("grug_materials:pick_wood", {description = "Wood Pickaxe",
	groups = {pickaxe = 1, grug_gathering_tool = 1}})
core.register_craftitem("mobs:meat", {description = "Meat"})
local SWORD = "grug_gear:sword_steel" -- T3, item level 21
local CLOTH = grug_gear.armor_item("chest", "cloth", 1)
local LEATHER = grug_gear.armor_item("chest", "leather", 1)
check(registered[CLOTH] ~= nil and registered[LEATHER] ~= nil, "the T1 cloth and leather chests exist")

------------------------------------------------------------------------------
-- A. check_affixes.
------------------------------------------------------------------------------
do
	check(Q.check_affixes(SWORD, {}), "A no enchants: fine on any item")
	check(Q.check_affixes("mobs:meat", {}), "A ... a plain item too")
	check(Q.check_affixes(SWORD, {{channel = "prefix", stat = "str"},
		{channel = "suffix", stat = "crit_percent"}}), "A a sword's prefix and suffix")
	local ok, reason = Q.check_affixes(SWORD, {{channel = "prefix", stat = "str"},
		{channel = "prefix", stat = "dex"}})
	check(not ok and reason:find("two enchants in the prefix", 1, true), "A two prefixes refused: " .. tostring(reason))
	ok, reason = Q.check_affixes(SWORD, {{channel = "prefix", stat = "armor_rating"}})
	check(not ok and reason:find("not in the prefix pool", 1, true), "A a stat outside the pool refused: " .. tostring(reason))
	ok, reason = Q.check_affixes(SWORD, {{channel = "middle", stat = "str"}})
	check(not ok, "A an unknown channel refused: " .. tostring(reason))
	ok, reason = Q.check_affixes("grug_materials:pick_wood", {{channel = "prefix", stat = "str"}})
	check(not ok and reason:find("takes no enchants", 1, true), "A a tool takes no enchants: " .. tostring(reason))
	ok, reason = Q.check_affixes("mobs:meat", {{channel = "prefix", stat = "str"}})
	check(not ok, "A a plain item takes no enchants: " .. tostring(reason))
	ok, reason = Q.check_affixes("nope:nothing", {})
	check(not ok and reason:find("unknown item", 1, true), "A an unknown item: " .. tostring(reason))
	ok, reason = Q.check_affixes(SWORD, {{channel = "prefix", stat = "str"}, {channel = "suffix", stat = "dex"},
		{channel = "suffix", stat = "int"}})
	check(not ok, "A three enchants refused")
end

------------------------------------------------------------------------------
-- B. make_stack.
------------------------------------------------------------------------------
do
	local stack = Q.make_stack(SWORD, 9, {{channel = "prefix", stat = "str"},
		{channel = "suffix", stat = "crit_percent"}})
	check(stack ~= nil, "B the sword is made")
	local meta = stack:get_meta()
	eq(meta:get_int("grug_ilvl"), 9, "B the authored item level, not the definition's 21")
	eq(meta:get_int("grug_req_level"), 9, "B its requirement follows")
	eq(meta:get_int("grug_quality"), 3, "B two enchants: Rare")
	local affixes = Q.get_affixes(stack)
	eq(#affixes, 2, "B both enchants stored")
	eq(affixes[1].channel .. ":" .. affixes[1].stat .. ":T" .. affixes[1].tier, "prefix:str:T1",
		"B the prefix at the item level's tier")
	eq(affixes[1].value, Q.enchant_value("str", 9, 1), "B ... its value is the rule at item level 9")
	eq(affixes[2].channel .. ":" .. affixes[2].stat, "suffix:crit_percent", "B the suffix")
	local text = description(stack)
	has(text, "Heavy Steel Sword of the Eagle", "B the name carries both enchant words")
	has(text, "Item level 9", "B the tooltip shows the item level")
	has(text, "Prefix: +", "B ... the prefix line")
	has(text, "Suffix: +", "B ... the suffix line")
	-- One enchant: Uncommon; the cloth chest at item level 5.
	local chest = Q.make_stack(CLOTH, 5, {{channel = "suffix", stat = "int"}})
	eq(chest:get_meta():get_int("grug_quality"), 2, "B one enchant: Uncommon")
	eq(chest:get_meta():get_int("grug_ilvl"), 5, "B the chest's item level")
	has(description(chest), "Item level 5", "B ... in its tooltip")
	-- No enchants: a Common at the item level.
	local plain = Q.make_stack(LEATHER, 7)
	eq(plain:get_meta():get_int("grug_quality"), 1, "B no enchants: Common")
	eq(#Q.get_affixes(plain), 0, "B ... and none stored")
	eq(plain:get_meta():get_int("grug_ilvl"), 7, "B ... at item level 7")
	-- With the receiver: the HP amount at the player's level.
	local hero = {get_player_name = function() return "hero" end}
	local hp = Q.make_stack(CLOTH, 5, {{channel = "suffix", stat = "max_hp_percent"}}, hero)
	has(description(hp), "42 at your level", "B the receiver's line")
	-- A tool and a plain item: no item level, no enchants, the count kept.
	local pick = Q.make_stack("grug_materials:pick_wood", 9)
	eq(pick:get_meta():get_int("grug_ilvl"), 0, "B a tool takes no item level")
	local meat = Q.make_stack("mobs:meat 3", 9)
	eq(meat:get_count(), 3, "B an item string keeps its count")
	eq(meat:get_meta():get_int("grug_ilvl"), 0, "B ... and a plain item no item level")
	local refused, reason = Q.make_stack("mobs:meat", 9, {{channel = "prefix", stat = "str"}})
	check(refused == nil and reason ~= nil, "B enchants on a plain item refused")
end

------------------------------------------------------------------------------
-- C. tooltip_text.
------------------------------------------------------------------------------
do
	local made = Q.make_stack(SWORD, 9, {{channel = "prefix", stat = "str"}})
	local before = description(made)
	local text = Q.tooltip_text(made)
	eq(text, before, "C a made stack: its own tooltip")
	eq(description(made), before, "C ... the stack unchanged")
	-- A plain registered sword (no meta): the item level and the stats.
	local fresh = Q.tooltip_text(SWORD)
	has(fresh, "Item level 21", "C a sword by name: its item level")
	check(not fresh:find("Prefix", 1, true), "C ... and no enchant line")
	local stack = ItemStack(SWORD)
	Q.tooltip_text(stack)
	eq(stack:get_meta():get_string("description"), "", "C the caller's stack keeps no meta")
	eq(Q.tooltip_text("mobs:meat"), "Meat", "C a plain item: its description")
	eq(Q.tooltip_text("mobs:meat 5"), "Meat", "C ... from an item string")
	eq(Q.tooltip_text("nope:nothing"), "nope:nothing", "C an unknown item: its name")
	eq(Q.tooltip_text(""), "", "C nothing: empty")
	local hero = {get_player_name = function() return "hero" end}
	has(Q.tooltip_text(Q.make_stack(CLOTH, 5, {{channel = "suffix", stat = "max_hp_percent"}}), hero),
		"42 at your level", "C the reader's lines")
	has(Q.tooltip_text(SWORD, hero), "Effective at level 60", "C a weapon's effective line for the reader")
end

if failures > 0 then
	error(("R57 QSYS QUALITY FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 QSYS QUALITY PASS checks=%d"):format(checks))
