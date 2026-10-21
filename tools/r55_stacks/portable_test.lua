-- Round 55 lane STACKS portable test (LuaJIT): shield and spellbook stacks
-- enchanted or broken under 0.54.1 show the current art after the refresh.
--
--   luajit tools/r55_stacks/portable_test.lua [REPO]
--
-- Until 0.54.1 the registration tinted some offhand icons (the Iron shield
-- `^[hsl`, the Embersteel shield `^[colorize`, one shared spellbook image
-- `^[colorize`d per tier); an enchanted stack keeps the image built from it
-- in its meta (grug_quality refresh_enchant_image), a broken one also the
-- uncracked base (grug_repair refresh_appearance). Loads the REAL grug_gear,
-- grug_quality and grug_repair (service, presentation) under the r55_game
-- engine stub, builds such stacks exactly as 0.54.1 did (the same functions
-- with the old registered image), and checks:
--   R  grug_gear.initialize_weapon_tooltip gives each the meta a fresh stack
--      of the current registration gets (images, broken base and drawn
--      keys), returns true, and a second call changes nothing and returns
--      false; current stacks (plain, enchanted, broken) return false;
--   J  the join path (the equipment-change consumer grug_gear registers,
--      which grug_inventory's join notification runs): the old stacks are
--      written back into their lists, the offhand slot is announced once,
--      a second pass writes nothing.
-- Prints "R55 STACKS PORTABLE PASS checks=<n>" or the failures.

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

------------------------------------------------------------------------------
-- Engine stub (tools/r55_game's, without grug_visuals).
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
	grug_repair = ROOT .. "/mods/ITEMS/grug_repair",
}
local current_mod = "grug_gear"
local serial = {}
local equipment_consumers, mods_loaded = {}, {}
core = permissive({
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_node = function(name, def) registered[name] = def end,
	register_on_mods_loaded = function(fn)
		if current_mod == "grug_gear" then mods_loaded[#mods_loaded + 1] = fn end
	end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
})
table.copy = table.copy or function(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = table.copy(item) end
	return out
end
minetest = core
vector = permissive({})
grug_core = permissive({
	level_scale = function() return 1 end,
	register_on_equipment_change = function(fn) equipment_consumers[#equipment_consumers + 1] = fn end,
})
do
	local handle = assert(io.open(ROOT .. "/mods/CORE/grug_core/combat.lua", "rb"))
	local body = handle:read("*a"):match("\n(function grug_core%.equipment_is_broken%(.-\nend)\n")
	handle:close()
	assert(loadstring(assert(body, "equipment_is_broken in combat.lua")))()
end
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	pool_percent_amount = function() return 7 end,
	registered_races = {}, race_ids = {}})
grug_mobs = permissive({})
grug_jobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})
local announced = {}
grug_inventory = permissive({
	equipment_changed = function(_, listname)
		announced[#announced + 1] = listname or "(all)"
	end,
})

local function new_meta(fields)
	fields = fields or {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return tonumber(fields[key]) or 0 end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(source)
	local name, wear, fields = source or "", 0, {}
	if type(source) == "table" then
		name, wear = source:get_name(), source:get_wear()
		for key, value in pairs(source:get_meta().fields) do fields[key] = value end
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return name == "" and 0 or 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return wear end
	function stack:set_wear(value) wear = value end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:to_string() return name end
	return stack
end
PcgRandom = function(seed)
	local state = seed
	return {next = function(_, low, high)
		state = (state * 1103515245 + 12345) % 2147483648
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
current_mod = "grug_repair"
grug_repair = {}
dofile(ROOT .. "/mods/ITEMS/grug_repair/service.lua")
dofile(ROOT .. "/mods/ITEMS/grug_repair/presentation.lua")
for _, fn in ipairs(mods_loaded) do fn() end

------------------------------------------------------------------------------
-- Stacks: 0.54.1's (the old registered image) and the current registration's.
------------------------------------------------------------------------------
local GRADES = {}
for bracket, materials in ipairs(grug_gear.MATERIALS) do GRADES[bracket] = materials.metal.key end
local SHIELD = function(bracket) return "grug_gear:shield_" .. GRADES[bracket] end
local BOOK = function(bracket) return "grug_gear:spellbook_" .. GRADES[bracket] end
-- 0.54.1's registered images (cf7c6ce3 mods/ITEMS/grug_gear/init.lua).
local OLD_IMAGE = {
	[SHIELD(2)] = "grug_gear_shield_iron.png^[hsl:0:-100:-12",
	[SHIELD(5)] = "grug_gear_shield_embersteel.png^[colorize:#9f2418:112",
	[BOOK(3)] = "grug_gear_spellbook.png^[colorize:#c0b088:48",
}

-- An enchanted (and possibly broken) stack the way enchanting, breaking and
-- the join refresh wrote it, under `image` as the registered image (nil: the
-- current one).
local function make_stack(name, prefix, suffix, broken, image)
	local def = registered[name]
	local current = def.inventory_image
	if image then def.inventory_image = image end
	local stack = ItemStack(name)
	local affixes = {}
	if prefix then affixes[#affixes + 1] = {channel = "prefix", stat = prefix, tier = 3, value = 5} end
	if suffix then affixes[#affixes + 1] = {channel = "suffix", stat = suffix, tier = 3, value = 5} end
	if #affixes > 0 then
		stack:get_meta():set_string("grug_ench", core.serialize(affixes))
	end
	grug_items.refresh_enchant_image(stack, affixes)
	if broken then stack:set_wear(65535) end
	grug_repair.refresh_appearance(stack)
	-- Settled as a carried stack is: 0.54.1's join refresh already wrote
	-- its description, so only the image can differ now.
	grug_gear.initialize_weapon_tooltip(stack, {})
	def.inventory_image = current
	return stack
end

local IMAGE_KEYS = {"inventory_image", "wield_image",
	"_grug_broken_base_inventory_image", "_grug_broken_drawn_inventory_image",
	"_grug_broken_base_wield_image", "_grug_broken_drawn_wield_image"}
local function same_look(stack, expected, label)
	local meta, want = stack:get_meta(), expected:get_meta()
	for _, key in ipairs(IMAGE_KEYS) do
		eq(meta:get_string(key), want:get_string(key), label .. " " .. key)
	end
end

local refresh = grug_gear.initialize_weapon_tooltip
local player = {}

------------------------------------------------------------------------------
-- R. One stack at a time.
------------------------------------------------------------------------------
local CASES = {
	{"enchanted Iron shield", SHIELD(2), "str", "armor_rating", false},
	{"enchanted Embersteel shield", SHIELD(5), "dex", nil, false},
	{"enchanted spellbook", BOOK(3), nil, "max_mana_percent", false},
	{"broken enchanted Iron shield", SHIELD(2), "int", "dodge_percent", true},
	{"broken plain Embersteel shield", SHIELD(5), nil, nil, true},
	{"broken enchanted spellbook", BOOK(3), "int", nil, true},
}
for _, case in ipairs(CASES) do
	local label, name, prefix, suffix, broken = case[1], case[2], case[3], case[4], case[5]
	local old = make_stack(name, prefix, suffix, broken, OLD_IMAGE[name])
	local fresh = make_stack(name, prefix, suffix, broken)
	check(old:get_meta():get_string("inventory_image") ~=
		fresh:get_meta():get_string("inventory_image"), label .. ": the old image differs")
	eq(refresh(old, player), true, label .. ": first refresh reports the change")
	same_look(old, fresh, label)
	local image = old:get_meta():get_string("inventory_image")
	check(not image:find("^[hsl:0:-100:-12", 1, true) and
		not image:find("^[colorize:#9f2418", 1, true) and
		not image:find("grug_gear_spellbook.png", 1, true), label .. ": no old tint or shared book left")
	local before = {}
	for key, value in pairs(old:get_meta().fields) do before[key] = value end
	eq(refresh(old, player), false, label .. ": second refresh changes nothing")
	local same = true
	for key, value in pairs(old:get_meta().fields) do
		if before[key] ~= value then same = false end
	end
	for key in pairs(before) do
		if old:get_meta().fields[key] == nil then same = false end
	end
	check(same, label .. ": second refresh leaves the meta as it was")
end

-- Current stacks: nothing to write.
for _, case in ipairs({
	{"plain Iron shield", SHIELD(2)},
	{"enchanted Iron shield", SHIELD(2), "str", "armor_rating"},
	{"broken enchanted spellbook", BOOK(3), "int", nil, true},
}) do
	local stack = make_stack(case[2], case[3], case[4], case[5])
	local image = stack:get_meta():get_string("inventory_image")
	eq(refresh(stack, player), false, "current " .. case[1] .. ": nothing to write")
	eq(stack:get_meta():get_string("inventory_image"), image,
		"current " .. case[1] .. ": the image stays")
end

------------------------------------------------------------------------------
-- J. The join path: grug_inventory's join notification runs grug_gear's
-- equipment-change consumer over every list of the player's inventory.
------------------------------------------------------------------------------
local lists = {
	main = {make_stack(SHIELD(5), "dex", nil, false, OLD_IMAGE[SHIELD(5)]),
		make_stack(SHIELD(2), "str", nil), ItemStack("")},
	grug_offhand = {make_stack(BOOK(3), nil, "max_mana_percent", true, OLD_IMAGE[BOOK(3)])},
}
local writes = 0
local inv = {}
function inv:get_lists() return lists end
function inv:get_stack(list, index) return ItemStack(lists[list][index]) end
function inv:set_stack(list, index, stack)
	writes = writes + 1
	lists[list][index] = ItemStack(stack)
end
function player:get_inventory() return inv end
eq(#equipment_consumers, 1, "grug_gear registers one equipment-change consumer")
equipment_consumers[1](player, nil, nil)
same_look(lists.main[1], make_stack(SHIELD(5), "dex"), "join: main Embersteel shield")
same_look(lists.grug_offhand[1], make_stack(BOOK(3), nil, "max_mana_percent", true),
	"join: offhand spellbook")
eq(writes, 2, "join: the two old stacks are written back, the current one not")
eq(#announced, 1, "join: one equipment announcement")
eq(announced[1], "grug_offhand", "join: the offhand list is named")
writes, announced = 0, {}
equipment_consumers[1](player, nil, nil)
eq(writes, 0, "join again: nothing written")
eq(#announced, 0, "join again: nothing announced")

if failures > 0 then
	error("R55 STACKS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R55 STACKS PORTABLE PASS checks=" .. checks)
