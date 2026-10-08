-- Round 45 lane IL portable test (LuaJIT): the item level ladder
-- (round45-plan.md §4.1, ui-crafting-rework-plan.md §2.25 and §6).
--
-- Loads the REAL grug_gear (init.lua with permissions.lua, enchant_colors.lua
-- and trinkets.lua), grug_quality's init.lua and grug_core's
-- can_use_item_level (cut out of combat.lua) under a permissive engine stub
-- with ItemStack metadata:
--   A. the brackets: base item level 1/11/21/31/41/51, cap 10 x tier, the
--      base level is the band's first level;
--   B. every gear definition sits at its bracket's base level and requires
--      that level (none in the first bracket), in its fields and its tooltip;
--   C. the requirement rule: the item level from level 1, capped at 60, for
--      definitions, drops, crafted bases and boss items; no bracket-1
--      exception;
--   D. trinkets on the same ladder (item level, requirement, the baked
--      "Item level N" line); consumables stay off it (food and alchemy read
--      neither the brackets nor the gear requirement);
--   E. the meta override (the 0.45.0 pin of lane MS): a stack whose
--      `grug_ilvl` / `grug_req_level` hold the old ladder's values keeps its
--      old level, requirement, tooltip, armor and enchant values, and stays
--      wearable at the old requirement.
--
--   luajit tools/r45_il/portable_test.lua [REPO]
-- Prints "R45 IL PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
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
}
local current_mod = "grug_gear"
local serial = {}
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
})
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({})
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
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	return {next = function(_, low, high)
		state = (state * 48271) % 2147483647
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
do
	local source = read_file(ROOT .. "/mods/CORE/grug_core/combat.lua")
	local body = source:match("(function grug_core%.can_use_item_level%(player, item%).-\nend)\n")
	check(body ~= nil, "can_use_item_level found in combat.lua")
	assert(loadstring(body))()
	grug_core.get_player_level = function(player) return player.level end
end
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end

local function wearable(level, item)
	return grug_core.can_use_item_level({level = level}, item) == true
end
local function tooltip(stack)
	grug_items.regenerate_description(stack)
	return stack:get_meta():get_string("description")
end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end

------------------------------------------------------------------------------
-- A. The brackets.
------------------------------------------------------------------------------
check(#grug_gear.BRACKETS == 6, "A six brackets")
for tier, br in ipairs(grug_gear.BRACKETS) do
	check(br.ilvl == 10 * (tier - 1) + 1, ("A T%d base item level %d"):format(tier, br.ilvl))
	check(br.cap == 10 * tier, ("A T%d cap %s = 10 x tier"):format(tier, tostring(br.cap)))
	check(br.ilvl == br.min_level and br.cap == br.max_level,
		("A T%d spans its level band %d-%d"):format(tier, br.min_level, br.max_level))
end

------------------------------------------------------------------------------
-- B. Every gear definition on the ladder.
------------------------------------------------------------------------------
do
	local count, bad = 0, {}
	for name, def in pairs(registered) do
		local groups = def.groups or {}
		local equip = false
		for group, value in pairs(groups) do
			if group:find("^grug_equip_") and value > 0 then equip = true end
		end
		if equip then
			count = count + 1
			local br = grug_gear.BRACKETS[def._grug_bracket or 0]
			local ilvl = br and br.ilvl
			local text = def.description or ""
			local ok = br ~= nil and def._grug_ilvl == ilvl and def._grug_req_level == ilvl and
				has(text, "\nItem level " .. ilvl .. "\n")
			if ilvl == 1 then
				ok = ok and not has(text, "Requires level")
			else
				local _, lines = text:gsub("\nRequires level " .. ilvl, "")
				ok = ok and lines == 1
			end
			if not ok then bad[#bad + 1] = name end
		end
	end
	table.sort(bad)
	-- 36 weapons, 72 armour pieces, 12 offhands, 36 trinkets.
	check(count == 156, "B 156 gear definitions (" .. count .. ")")
	check(#bad == 0, "B each at its bracket's base level and requirement: " ..
		table.concat(bad, ", "))
	local sword = registered["grug_gear:sword_bronze"]
	check(sword._grug_ilvl == 1 and sword.tool_capabilities.damage_groups.fleshy ==
		grug_gear.weapon_damage_at_level(1, "sword"),
		"B a Bronze Sword's damage is the curve at item level 1")
	local helm = registered["grug_gear:head_metal_steel"]
	check(helm._grug_ilvl == 21 and helm._grug_req_level == 21, "B a Steel Helm is 21 / 21")
end

------------------------------------------------------------------------------
-- C. The requirement rule.
------------------------------------------------------------------------------
do
	local ok = true
	for ilvl = 1, 75 do
		ok = ok and grug_gear.required_level(ilvl) == math.min(ilvl, 60)
	end
	check(ok, "C required_level = min(ilvl, 60) from level 1")
	check(grug_gear.bracket_required_level == nil, "C the bracket-1 exception is gone")
	-- Drops in the first bracket require their own level.
	for _, ilvl in ipairs({1, 2, 3, 7, 10}) do
		local stack = ItemStack("grug_gear:chest_metal_bronze")
		grug_items.roll_enchants(stack, ilvl, 0, 7)
		local meta = stack:get_meta()
		check(meta:get_int("grug_ilvl") == ilvl and meta:get_int("grug_req_level") == ilvl,
			("C a Bronze Chestplate dropped at %d requires %d"):format(ilvl, ilvl))
		check((ilvl == 1 or not wearable(ilvl - 1, stack)) and wearable(ilvl, stack),
			("C ...refused below %d, worn at %d"):format(ilvl, ilvl))
	end
	for _, row in ipairs({{"grug_gear:head_cloth_stormweave", 65, 60},
			{"grug_gear:mercy_seal_t6", 70, 60}, {"grug_gear:shield_embersteel", 44, 44}}) do
		local stack = ItemStack(row[1])
		grug_items.roll_enchants(stack, row[2], 1, 99)
		check(stack:get_meta():get_int("grug_req_level") == row[3],
			("C %s at item level %d requires %d"):format(row[1], row[2], row[3]))
	end
	-- A crafted base starts at its tier's base level.
	for tier, br in ipairs(grug_gear.BRACKETS) do
		local stack = ItemStack(grug_gear.weapon_item("dagger", tier))
		grug_items.crafted_output(stack)
		local meta = stack:get_meta()
		check(meta:get_int("grug_ilvl") == br.ilvl and meta:get_int("grug_req_level") == br.ilvl,
			("C a crafted T%d dagger is %d / %d"):format(tier, br.ilvl, br.ilvl))
	end
	-- A plain definition stack: the definition's requirement.
	local iron = ItemStack("grug_gear:legs_leather_cured")
	check(not wearable(10, iron) and wearable(11, iron), "C a plain T2 piece needs level 11")
	check(wearable(1, ItemStack("grug_gear:sword_bronze")), "C a plain T1 sword at level 1")
end

------------------------------------------------------------------------------
-- D. Trinkets on the ladder; consumables off it.
------------------------------------------------------------------------------
do
	local bad = {}
	for _, identity in ipairs(grug_gear.TRINKETS) do
		for tier, br in ipairs(grug_gear.BRACKETS) do
			local name = grug_gear.trinket_item(identity.key, tier)
			local def = registered[name]
			if not (def and def._grug_ilvl == br.ilvl and def._grug_req_level == br.ilvl and
					def._grug_bracket == tier and
					has(def.description, "\nItem level " .. br.ilvl .. "\n")) then
				bad[#bad + 1] = name
			end
		end
	end
	check(#bad == 0, "D every trinket on its bracket's level: " .. table.concat(bad, ", "))
	local gear_source = read_file(ROOT .. "/mods/ITEMS/grug_gear/trinkets.lua")
	check(not gear_source:find("ILVLS", 1, true), "D trinkets keep no level table of their own")
	local rolled = ItemStack("grug_gear:battlebeat_t4")
	grug_items.roll_enchants(rolled, 33, 1, 5)
	local text = tooltip(rolled)
	check(has(text, "Item level 33") and has(text, "Requires level 33"),
		"D a dropped trinket shows its own level and requirement")
	for _, path in ipairs({"/mods/ITEMS/grug_food/init.lua",
			"/mods/ITEMS/grug_alchemy/effects.lua"}) do
		local source = read_file(ROOT .. path)
		check(not source:find("grug_gear.BRACKETS", 1, true) and
			not source:find("required_level", 1, true),
			"D " .. path .. " stays off the ladder")
	end
end

------------------------------------------------------------------------------
-- E. The meta override: a stack pinned at the old ladder (lane MS's 0.45.0
-- step writes the 0.44 definition values into grug_ilvl / grug_req_level).
------------------------------------------------------------------------------
do
	local OLD = {{3, 1}, {10, 10}, {20, 20}, {30, 30}, {40, 40}, {50, 50}}
	for tier, old in ipairs(OLD) do
		local name = grug_gear.armor_item("chest", "metal", tier)
		local plain, pinned = ItemStack(name), ItemStack(name)
		pinned:get_meta():set_int("grug_ilvl", old[1])
		pinned:get_meta():set_int("grug_req_level", old[2])
		check(grug_items.effective_ilvl(pinned) == old[1],
			("E T%d pinned item level %d"):format(tier, old[1]))
		check(wearable(old[2], pinned), ("E T%d pinned piece worn at level %d"):format(tier, old[2]))
		check(tier == 1 or not wearable(old[2], plain),
			("E ...where an unpinned T%d piece needs %d"):format(tier, grug_gear.BRACKETS[tier].ilvl))
		local text = tooltip(pinned)
		check(has(text, "\nItem level " .. old[1] .. "\n"),
			("E T%d tooltip shows item level %d"):format(tier, old[1]))
		check(old[2] == 1 and not has(text, "Requires level") or
			has(text, "\nRequires level " .. old[2]),
			("E T%d tooltip shows the old requirement"):format(tier))
		local _, stats = grug_gear.describe_stack_base(pinned, grug_items.effective_ilvl(pinned))
		local line = 0.86667 * old[1] + 5.6
		check(stats.armor == math.max(1, math.floor(line * 0.35 + 0.5)),
			("E T%d armor from the pinned level"):format(tier))
	end
	-- A pinned shield keeps its old rating.
	local shield = ItemStack("grug_gear:shield_bronze")
	shield:get_meta():set_int("grug_ilvl", 3)
	shield:get_meta():set_int("grug_req_level", 1)
	local _, old_stats = grug_gear.describe_stack_base(shield, 3)
	local _, new_stats = grug_gear.describe_stack_base(ItemStack("grug_gear:shield_bronze"), 1)
	local _, pinned_stats = grug_gear.describe_stack_base(shield, grug_items.effective_ilvl(shield))
	check(pinned_stats.armor == old_stats.armor and old_stats.armor ~= new_stats.armor,
		"E a pinned Bronze Shield keeps its item-level-3 rating")
	-- Enchant values follow the pinned level, not the definition.
	local sword = ItemStack("grug_gear:sword_iron")
	sword:get_meta():set_int("grug_ilvl", 10)
	sword:get_meta():set_int("grug_req_level", 10)
	grug_items.roll_enchants(sword, nil, 1, 3)
	local affix = grug_items.get_affixes(sword)[1]
	check(affix and affix.value == grug_items.enchant_value(affix.stat, 10, affix.tier),
		"E an enchant on a pinned stack reads the pinned level")
	check(sword:get_meta():get_int("grug_req_level") == 10 and wearable(10, sword),
		"E ...and the stack stays wearable at 10")
	-- A pinned trinket: its old level line and requirement.
	local trinket = ItemStack("grug_gear:manawell_t3")
	trinket:get_meta():set_int("grug_ilvl", 20)
	trinket:get_meta():set_int("grug_req_level", 20)
	local text = tooltip(trinket)
	check(has(text, "Item level 20") and has(text, "Requires level 20") and
		wearable(20, trinket), "E a pinned trinket keeps 20 / 20")
end

if failures > 0 then
	print(("R45 IL PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R45 IL PORTABLE PASS checks=%d"):format(checks))
