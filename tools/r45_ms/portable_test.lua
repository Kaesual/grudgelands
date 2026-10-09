-- Round 45 lane MS portable test (LuaJIT): the online part of the migration
-- step 0.45.0 (grug_core/migrations.lua; the offline step is
-- tools/migration/steps/v0_45_0.py, its tests tools/r45_ms/test_step.py and
-- e2e.py). It stays in tools/run_fixtures.sh for good: the old handler runs
-- against new game code (round workflow §3 "Migration steps").
--
-- Loads the REAL grug_gear (with its trinkets), grug_quality and
-- grug_core/migrations.lua with the handler under an engine stub with
-- ItemStack metadata, tool capabilities and player inventories; the give
-- helper and the output area are small stand-ins of grug_inventory.give and
-- grug_jobs.ensure_output_area:
--   A. the registry: 0.45.0 listed after 0.44.0 with a character handler only;
--   B. craft leftovers (ruling 6): the give helper first, then the output
--      area (created first), then the feet; the grid ends empty; the
--      engine's craftresult list the same way, after the grid;
--   C. a drop that fails stops the handler with the grid holding exactly
--      what is left (no copy), and the rerun finishes it;
--   D. tool capabilities: an unmodified first-tier weapon pinned at the old
--      level deals its old damage again (broken ones through the repair's
--      kept capabilities); weapons whose damage already matches (new,
--      crafted, a station-enchanted first-tier sword without an item level
--      of its own (pinned offline), upgraded, crowned, higher tiers, a broken
--      one with its old capabilities) keep their item level, requirement,
--      enchants and capabilities;
--   E. the tooltips of gear in every list show the pinned level and
--      requirement; a plain item is not touched;
--   F. a second run changes nothing.
--
--   luajit tools/r45_ms/portable_test.lua [REPO]
-- Prints "R45 MS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
	grug_core = ROOT .. "/mods/CORE/grug_core",
}
local current_mod = "grug_gear"
local serial = {}
local mods_loaded = {}
local drops, drop_fails = {}, false
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
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
	add_item = function(pos, stack)
		if drop_fails then return nil end
		drops[#drops + 1] = stack:to_string()
		return {}
	end,
})
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = copy(child) end
	return out
end

local new_stack
local function new_meta(fields, owner)
	local meta = {}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = tostring(value) end
	end
	function meta:get_int(key) return math.floor(tonumber(fields[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities(caps)
		owner.caps = copy(caps)
		fields.tool_capabilities = caps and "caps" or nil
	end
	return meta
end
new_stack = function(name, count, wear, fields, caps)
	local stack = {name = name or "", count = count or 1, wear = wear or 0,
		fields = fields or {}, caps = caps}
	if stack.name == "" then stack.count = 0 end
	local meta = new_meta(stack.fields, stack)
	function stack:get_name() return self.name end
	function stack:is_empty() return self.name == "" or self.count <= 0 end
	function stack:get_count() return self.count end
	function stack:set_count(n)
		self.count = n
		if n <= 0 then self.name = "" end
	end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[self.name] or {} end
	function stack:get_wear() return self.wear end
	function stack:get_stack_max() return (registered[self.name] or {}).stack_max or 99 end
	function stack:get_tool_capabilities()
		return copy(self.caps or (registered[self.name] or {}).tool_capabilities)
	end
	function stack:to_string()
		if self:is_empty() then return "" end
		local keys = {}
		for key in pairs(self.fields) do keys[#keys + 1] = key end
		table.sort(keys)
		local parts = {}
		for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. self.fields[key] end
		local caps = self.caps and self.caps.damage_groups and
			(" caps=" .. tostring(self.caps.damage_groups.fleshy)) or ""
		return ("%s %d %d {%s}%s"):format(self.name, self.count, self.wear,
			table.concat(parts, ","), caps)
	end
	return stack
end
ItemStack = function(value)
	if type(value) == "table" then
		return new_stack(value.name, value.count, value.wear, copy(value.fields), copy(value.caps))
	end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
	return new_stack(name, tonumber(count) or 1)
end
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	return {next = function(_, low, high)
		state = (state * 48271) % 2147483647
		return low + state % (high - low + 1)
	end}
end

-- Player inventories: `lists` maps a list name to its size; stacks via set.
local function new_inventory()
	local lists = {}
	local inv = {lists = lists}
	function inv:get_size(name) return lists[name] and #lists[name] or 0 end
	function inv:set_size(name, size)
		local list = lists[name] or {}
		for index = 1, size do list[index] = list[index] or new_stack("") end
		for index = size + 1, #list do list[index] = nil end
		lists[name] = size > 0 and list or nil
	end
	function inv:get_stack(name, index)
		return ItemStack(lists[name] and lists[name][index] or new_stack(""))
	end
	function inv:set_stack(name, index, stack) lists[name][index] = ItemStack(stack) end
	function inv:is_empty(name)
		for _, stack in ipairs(lists[name] or {}) do
			if not stack:is_empty() then return false end
		end
		return true
	end
	function inv:get_lists()
		local out = {}
		for name, list in pairs(lists) do
			out[name] = {}
			for index, stack in ipairs(list) do out[name][index] = ItemStack(stack) end
		end
		return out
	end
	-- InvRef:add_item: partial stacks of the same plain item, then empty slots.
	function inv:add_item(name, stack)
		stack = ItemStack(stack)
		for pass = 1, 2 do
			for _, cell in ipairs(lists[name] or {}) do
				if stack:is_empty() then return stack end
				if pass == 1 and cell.name == stack.name and next(cell.fields) == nil and
						next(stack.fields) == nil then
					local room = cell:get_stack_max() - cell.count
					local moved = math.min(room, stack.count)
					cell.count = cell.count + moved
					stack:set_count(stack.count - moved)
				elseif pass == 2 and cell:is_empty() then
					cell.name, cell.count, cell.wear = stack.name, stack.count, stack.wear
					for key, value in pairs(stack.fields) do cell.fields[key] = value end
					cell.caps = copy(stack.caps)
					return new_stack("")
				end
			end
		end
		return stack
	end
	return inv
end

local output_calls = 0
grug_inventory = permissive({
	-- Stand-in for the give helper: main only, partial stacks, then empty.
	give = function(player, stack)
		return player:get_inventory():add_item("main", stack)
	end,
})
grug_jobs = permissive({
	ensure_output_area = function(player)
		output_calls = output_calls + 1
		local inv = player:get_inventory()
		if inv:get_size("grug_craft_out") ~= 4 then inv:set_size("grug_craft_out", 4) end
	end,
})

local function new_player(name)
	local inv = new_inventory()
	return {
		get_inventory = function() return inv end,
		get_player_name = function() return name end,
		get_pos = function() return {x = 1, y = 2, z = 3} end,
	}, inv
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end
current_mod = "grug_core"
dofile(ROOT .. "/mods/CORE/grug_core/migrations.lua")

local function pinned(name, ilvl, req, wear)
	local stack = new_stack(name, 1, wear or 0)
	stack:get_meta():set_int("grug_ilvl", ilvl)
	stack:get_meta():set_int("grug_req_level", req)
	return stack
end
local function damage(stack)
	local caps = stack:get_tool_capabilities()
	return caps and caps.damage_groups and caps.damage_groups.fleshy
end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end

------------------------------------------------------------------------------
-- A. The registry.
------------------------------------------------------------------------------
local registry = grug_core.migrations
check(#registry.versions == 2 and registry.versions[1] == "0.44.0" and
	registry.versions[2] == "0.45.0", "A versions are 0.44.0, 0.45.0")
local handler = registry.handlers["0.45.0"]
check(handler and type(handler.character) == "function" and handler.world == nil,
	"A 0.45.0 has a character handler and no world handler")
check(registry.handlers["0.44.0"] == nil, "A 0.44.0 stays offline only")
local run = handler.character

------------------------------------------------------------------------------
-- B. Craft leftovers: give, the output area, the feet.
------------------------------------------------------------------------------
do
	local player, inv = new_player("crafter")
	inv:set_size("main", 4)
	inv:set_stack("main", 1, new_stack("default:torch", 10))
	inv:set_stack("main", 2, new_stack("default:dirt", 99))
	inv:set_stack("main", 3, new_stack("default:dirt", 99))
	inv:set_stack("main", 4, new_stack("default:dirt", 99))
	inv:set_size("craft", 9)
	local items = {"default:torch 5", "default:cobble 4", "default:stick 6", "default:paper 2",
		"default:book 1", "default:apple 3"}
	for index, item in ipairs(items) do inv:set_stack("craft", index, ItemStack(item)) end
	run(player, "1")
	local main1 = inv:get_stack("main", 1)
	check(main1.name == "default:torch" and main1.count == 15,
		"B the torches merge into main through the give helper")
	check(output_calls >= 1 and inv:get_size("grug_craft_out") == 4,
		"B the output area is created before it is written")
	local out = {}
	for index = 1, 4 do out[index] = inv:get_stack("grug_craft_out", index):to_string() end
	check(out[1]:match("^default:cobble 4") and out[2]:match("^default:stick 6") and
		out[3]:match("^default:paper 2") and out[4]:match("^default:book 1"),
		"B four leftovers fill the output area in grid order: " .. table.concat(out, " | "))
	check(#drops == 1 and drops[1]:match("^default:apple 3"),
		"B the fifth drops at the feet: " .. table.concat(drops, " | "))
	check(inv:is_empty("craft"), "B the craft grid ends empty")
	-- The engine's craftresult list: handed out the same way, after the grid.
	drops = {}
	local p2, inv2 = new_player("resulter")
	inv2:set_size("main", 1)
	inv2:set_stack("main", 1, new_stack("default:torch", 10))
	inv2:set_size("craft", 9)
	inv2:set_stack("craft", 1, new_stack("default:stick", 2))
	inv2:set_size("craftresult", 1)
	inv2:set_stack("craftresult", 1, new_stack("default:torch", 4))
	run(p2, "1")
	check(inv2:get_stack("main", 1).count == 14 and inv2:is_empty("craftresult") and
		inv2:get_size("craftresult") == 1, "B craftresult's torches merge through the give "
		.. "helper; the list stays, empty")
	check(inv2:get_stack("grug_craft_out", 1):to_string():match("^default:stick 2") and #drops == 0,
		"B ...the grid's sticks went to the output area first")
end

------------------------------------------------------------------------------
-- C. A failing drop: no copy, the rerun finishes.
------------------------------------------------------------------------------
do
	drops = {}
	local player, inv = new_player("full")
	-- Room for 2 dirt in main and 1 in the output area: 2 of 5 are left.
	inv:set_size("main", 1)
	inv:set_stack("main", 1, new_stack("default:dirt", 97))
	inv:set_size("grug_craft_out", 4)
	for index = 1, 3 do inv:set_stack("grug_craft_out", index, new_stack("default:stone", 99)) end
	inv:set_stack("grug_craft_out", 4, new_stack("default:dirt", 98))
	inv:set_size("craft", 9)
	inv:set_stack("craft", 2, new_stack("default:dirt", 5))
	inv:set_stack("craft", 3, new_stack("default:gravel", 7))
	drop_fails = true
	local ok = pcall(run, player, "1")
	drop_fails = false
	check(not ok, "C a drop that fails stops the handler (the runner keeps the marker)")
	local total = 0
	for _, list in ipairs({"main", "grug_craft_out", "craft"}) do
		for index = 1, inv:get_size(list) do
			local stack = inv:get_stack(list, index)
			if stack.name == "default:dirt" then total = total + stack.count end
		end
	end
	check(total == 200 and inv:get_stack("craft", 2).count == 2 and
		inv:get_stack("craft", 3).count == 7, "C nothing copied, nothing lost: the grid "
		.. "holds exactly what is left (" .. total .. ")")
	ok = pcall(run, player, "1")
	check(ok and inv:is_empty("craft") and #drops == 2 and drops[1]:match("^default:dirt 2 ") and
		drops[2]:match("^default:gravel 7 "), "C the rerun drops both and ends empty")
end

------------------------------------------------------------------------------
-- D. Tool capabilities of first-tier weapons.
------------------------------------------------------------------------------
do
	local old5 = grug_gear.weapon_damage_at_level(3, "sword")
	local new4 = grug_gear.weapon_damage_at_level(1, "sword")
	check(old5 == 5 and new4 == 4 and
		registered["grug_gear:sword_bronze"].tool_capabilities.damage_groups.fleshy == 4,
		"D the ladder lowered a Bronze Sword from 5 to 4")
	local player, inv = new_player("smith")
	inv:set_size("main", 12)
	inv:set_size("grug_weapon", 1)
	inv:set_size("craft", 0)
	inv:set_stack("grug_weapon", 1, pinned("grug_gear:sword_bronze", 3, 1))
	inv:set_stack("main", 1, pinned("grug_gear:dagger_bronze", 3, 1))
	inv:set_stack("main", 2, pinned("grug_gear:greataxe_bronze", 3, 1))
	inv:set_stack("main", 3, new_stack("grug_gear:sword_bronze"))     -- a new one: 4 is right
	local crafted = new_stack("grug_gear:sword_bronze")
	grug_items.crafted_output(crafted)
	inv:set_stack("main", 4, crafted)                                    -- 1 / 4, own caps
	local old_crafted = pinned("grug_gear:sword_bronze", 3, 1)
	old_crafted:get_meta():set_tool_capabilities({full_punch_interval = 1.0,
		damage_groups = {fleshy = 5}, groupcaps = {}, max_drop_level = 0})
	inv:set_stack("main", 5, old_crafted)                                -- a 0.44 craft
	inv:set_stack("main", 6, pinned("grug_gear:sword_iron", 10, 10))   -- 8 at 10 and 11
	-- Broken, as grug_repair leaves it: zero capabilities, the usable ones kept.
	local broken_kept = pinned("grug_gear:sword_bronze", 3, 1, 65535)
	broken_kept:get_meta():set_string("_grug_repair_caps", core.serialize({
		full_punch_interval = 1.0, damage_groups = {fleshy = 5}, groupcaps = {},
		max_drop_level = 0}))
	broken_kept:get_meta():set_tool_capabilities({full_punch_interval = 1.4,
		damage_groups = {fleshy = 0}, groupcaps = {}, punch_attack_uses = 0})
	inv:set_stack("main", 7, broken_kept)
	local broken_bare = pinned("grug_gear:bow_bronze", 3, 1, 65535)
	broken_bare:get_meta():set_tool_capabilities({full_punch_interval = 1.4,
		damage_groups = {fleshy = 0}, groupcaps = {}, punch_attack_uses = 0})
	inv:set_stack("main", 8, broken_bare)
	inv:set_stack("main", 9, pinned("grug_gear:shield_bronze", 3, 1))
	-- Enchanted at a station at 0.44.0: the enchant and the capabilities
	-- (store_affixes -> apply_capabilities at the definition's item level 3:
	-- 5 damage, the swing shortened by the speed enchant), no item level of
	-- its own, so the offline step pinned 3 / 1.
	local speed = grug_items.enchant_value("attack_speed_percent", 3, 1)
	local enchanted = pinned("grug_gear:sword_bronze", 3, 1)
	enchanted:get_meta():set_string("grug_ench", core.serialize({{channel = "prefix",
		stat = "attack_speed_percent", tier = 1, value = speed}}))
	enchanted:get_meta():set_int("grug_quality", 2)
	enchanted:get_meta():set_tool_capabilities({full_punch_interval = 1.0 / (1 + speed / 100),
		damage_groups = {fleshy = 5}, groupcaps = {}, max_drop_level = 0})
	inv:set_stack("main", 10, enchanted)
	-- Upgraded at 0.44.0 (upgrade_plan: write_item_level_meta to 10 x tier,
	-- then store_affixes): item level and requirement 10, 8 damage.
	local upgraded = pinned("grug_gear:sword_bronze", 10, 10)
	upgraded:get_meta():set_int("grug_quality", 1)            -- store_affixes: enchants + 1
	upgraded:get_meta():set_tool_capabilities({full_punch_interval = 1.0,
		damage_groups = {fleshy = grug_gear.weapon_damage_at_level(10, "sword")},
		groupcaps = {}, max_drop_level = 0})
	inv:set_stack("main", 11, upgraded)
	-- Crowned (crown_plan: 10 x tier + 5, the same at 0.44.0).
	local crowned = assert(grug_items.crown_item(new_stack("grug_gear:sword_bronze")))
	inv:set_stack("main", 12, crowned)
	local function fields(stack)
		local meta = stack:get_meta()
		local caps = stack.caps or {}
		return table.concat({meta:get_string("grug_ilvl"), meta:get_string("grug_req_level"),
			meta:get_string("grug_ench"), meta:get_string("grug_crowned"),
			meta:get_string("grug_quality"), tostring(caps.full_punch_interval),
			tostring(caps.damage_groups and caps.damage_groups.fleshy), tostring(stack.wear)}, "|")
	end
	local kept_before = {}
	for index = 10, 12 do kept_before[index] = fields(inv:get_stack("main", index)) end
	local before = {}
	for index = 4, 7 do before[index] = inv:get_stack("main", index):to_string() end
	run(player, "1")
	check(damage(inv:get_stack("grug_weapon", 1)) == 5,
		"D the equipped pinned Bronze Sword deals 5 again")
	check(damage(inv:get_stack("main", 1)) == grug_gear.weapon_damage_at_level(3, "dagger") and
		damage(inv:get_stack("main", 2)) == grug_gear.weapon_damage_at_level(3, "greataxe"),
		"D a pinned dagger and battle axe deal their item-level-3 damage")
	check(damage(inv:get_stack("main", 3)) == 4 and inv:get_stack("main", 3).caps == nil,
		"D a new Bronze Sword keeps the definition's 4 and no capabilities of its own")
	check(damage(inv:get_stack("main", 4)) == 4 and damage(inv:get_stack("main", 5)) == 5 and
		damage(inv:get_stack("main", 6)) == 8 and inv:get_stack("main", 6).caps == nil,
		"D crafted, 0.44-crafted and higher-tier weapons keep their capabilities")
	local same = true
	for index = 4, 7 do
		local stack = inv:get_stack("main", index)
		same = same and (stack:to_string():match(" caps=%d+$") or "") ==
			(before[index]:match(" caps=%d+$") or "") and stack.wear == ItemStack(
			{name = "x", count = 1, wear = tonumber(before[index]:match("^%S+ %d+ (%d+)")),
				fields = {}}).wear
	end
	check(same, "D ...their own capabilities and wear unchanged")
	local bk = inv:get_stack("main", 7)
	check(damage(bk) == 0 and core.deserialize(bk:get_meta():get_string("_grug_repair_caps"))
		.damage_groups.fleshy == 5, "D a broken sword with its old kept capabilities is "
		.. "left as it is")
	local bb = inv:get_stack("main", 8)
	local kept_caps = core.deserialize(bb:get_meta():get_string("_grug_repair_caps"))
	check(damage(bb) == 0 and kept_caps and kept_caps.damage_groups.fleshy ==
		grug_gear.weapon_damage_at_level(3, "bow"),
		"D a broken bow without kept capabilities stays broken and keeps its old damage "
		.. "for the repair")
	check(inv:get_stack("main", 9).caps == nil, "D a shield gets no capabilities")
	local kept = {}
	for index = 10, 12 do
		local now = fields(inv:get_stack("main", index))
		if now ~= kept_before[index] then kept[#kept + 1] = index .. ": " .. kept_before[index] ..
			" -> " .. now end
	end
	check(kept_before[10]:match("^3|1|S%d+||2|0%.98") and kept_before[11]:match("^10|10|") and
		kept_before[12]:match("^15|15|.*|1|") and damage(inv:get_stack("main", 10)) == 5 and
		damage(inv:get_stack("main", 11)) == 8 and damage(inv:get_stack("main", 12)) ==
		grug_gear.weapon_damage_at_level(15, "sword") and #kept == 0,
		"D a station-enchanted (5 damage, faster swing), an upgraded (10 / 10, 8) and a crowned "
		.. "(15 / 15) Bronze Sword keep item level, requirement, enchant, quality and "
		.. "capabilities: " .. table.concat(kept, "; ") .. " " .. table.concat(kept_before, " / ", 10, 12))
end

------------------------------------------------------------------------------
-- E. Tooltips in every list.
------------------------------------------------------------------------------
local hero, hero_inv
do
	hero, hero_inv = new_player("hero")
	for _, list in ipairs({"grug_chest", "grug_trinket1", "grug_shift"}) do
		hero_inv:set_size(list, 1)
	end
	hero_inv:set_size("main", 2)
	hero_inv:set_size("grug_bag1_content", 2)
	hero_inv:set_stack("grug_chest", 1, pinned("grug_gear:chest_metal_iron", 10, 10))
	hero_inv:set_stack("grug_trinket1", 1, pinned("grug_gear:manawell_t1", 3, 1))
	hero_inv:set_stack("grug_shift", 1, pinned("grug_gear:shield_silversteel", 30, 30))
	hero_inv:set_stack("grug_bag1_content", 1, pinned("grug_gear:legs_cloth_silk", 40, 40))
	hero_inv:set_stack("main", 1, new_stack("default:apple", 3))
	hero_inv:set_stack("main", 2, new_stack("grug_materials:pick_steel"))
	run(hero, "1")
	local function text(list) return hero_inv:get_stack(list, 1):get_meta():get_string("description") end
	check(has(text("grug_chest"), "Item level 10") and has(text("grug_chest"), "Requires level 10")
		and not has(text("grug_chest"), "Item level 11"), "E the equipped chest: 10 / 10")
	check(has(text("grug_trinket1"), "Item level 3") and not has(text("grug_trinket1"), "Requires"),
		"E a first-tier trinket: item level 3, no requirement")
	check(has(text("grug_shift"), "Item level 30") and has(text("grug_shift"), "Requires level 30"),
		"E the shift-click slot's shield: 30 / 30")
	check(has(text("grug_bag1_content"), "Item level 40"), "E a bag's robe: 40")
	check(hero_inv:get_stack("main", 1):to_string() == "default:apple 3 0 {}" and
		hero_inv:get_stack("main", 2):to_string() == "grug_materials:pick_steel 1 0 {}",
		"E an apple and a pickaxe are not touched")
end

------------------------------------------------------------------------------
-- F. A second run changes nothing.
------------------------------------------------------------------------------
do
	local function snapshot(inv)
		local out = {}
		for name, list in pairs(inv:get_lists()) do
			for index, stack in ipairs(list) do out[#out + 1] = name .. index .. stack:to_string() end
		end
		table.sort(out)
		return table.concat(out, "\n")
	end
	local before = snapshot(hero_inv)
	run(hero, "1")
	check(snapshot(hero_inv) == before, "F the rerun changes nothing")
end

if failures > 0 then
	print(("R45 MS PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R45 MS PORTABLE PASS checks=%d"):format(checks))
