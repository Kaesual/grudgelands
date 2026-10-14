-- Round 47 lane OR portable test (LuaJIT): the online part of the migration
-- step 0.47.0 (grug_core/migrations.lua; the offline step is
-- tools/migration/steps/v0_47_0.py, its tests tools/r47_ms/test_step.py and
-- e2e.py). It stays in tools/run_fixtures.sh for good: the old handler runs
-- against new game code (round workflow §3 "Migration steps").
--
-- Loads the REAL grug_gear, grug_quality and grug_core/migrations.lua under
-- an engine stub with ItemStack metadata (tool capabilities stored as a
-- deterministic serialization, as the engine stores a string), player
-- inventories and two tool definitions standing in for the new scale:
--   A. the registry: 0.47.0 listed last, with a character handler only;
--   B. a crafted tool's stored copy (the old scale) is rebuilt from the
--      definition in main, the hotbar, a bag's content list and the output
--      area; a broken one's kept copy too, its stack staying broken;
--   C. a tool without a stored copy, a weapon with stored capabilities and a
--      plain item are not touched (no write);
--   D. the rebuilt copy equals what a craft of the same tool stores now
--      (grug_items.crafted_output);
--   E. a second run writes nothing.
--
--   luajit tools/r47_ms/portable_test.lua [REPO]
-- Prints "R47 MS PORTABLE PASS checks=<n>" or the failures (exit 1).

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

-- Engine stub ---------------------------------------------------------------
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
local mods_loaded = {}

-- A deterministic serialization (sorted keys), so equal tables give equal
-- strings as core.serialize does for these plain tables.
local function encode(value)
	if type(value) ~= "table" then return type(value) == "string" and ("%q"):format(value)
		or tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. encode(key) .. "]=" .. encode(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local decoded = {}
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
	serialize = function(value)
		local text = encode(value)
		decoded[text] = value
		return text
	end,
	deserialize = function(text) return decoded[text] end,
	get_us_time = function() return 1 end,
})
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})
grug_inventory = permissive({})
grug_jobs = permissive({})

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
		fields.tool_capabilities = caps and encode(caps) or nil
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
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[self.name] or {} end
	function stack:get_wear() return self.wear end
	function stack:set_wear(wear) self.wear = wear end
	function stack:get_tool_capabilities()
		return copy(self.caps or (registered[self.name] or {}).tool_capabilities)
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

local writes = 0
local function new_inventory()
	local lists = {}
	local inv = {lists = lists}
	function inv:get_size(name) return lists[name] and #lists[name] or 0 end
	function inv:set_size(name, size)
		local list = lists[name] or {}
		for index = 1, size do list[index] = list[index] or new_stack("") end
		lists[name] = list
	end
	function inv:get_stack(name, index) return ItemStack(lists[name][index]) end
	function inv:set_stack(name, index, stack)
		writes = writes + 1
		lists[name][index] = ItemStack(stack)
	end
	function inv:get_lists()
		local out = {}
		for name, list in pairs(lists) do
			out[name] = {}
			for index, stack in ipairs(list) do out[name][index] = ItemStack(stack) end
		end
		return out
	end
	return inv
end
local function new_player(name)
	local inv = new_inventory()
	return {get_inventory = function() return inv end,
		get_player_name = function() return name end}, inv
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end
current_mod = "grug_core"
dofile(ROOT .. "/mods/CORE/grug_core/migrations.lua")

-- Two gathering tools on the new scale and the copies the old scale left.
local function caps(maxlevel, time, gated)
	local groupcaps = {cracky = {times = {[3] = time}, uses = 200, maxlevel = maxlevel}}
	if gated then groupcaps.grug_pick_level = {times = {[2] = time}, uses = 200,
		maxlevel = maxlevel} end
	return {full_punch_interval = 1, max_drop_level = 0, punch_attack_uses = 0,
		damage_groups = {fleshy = 0}, groupcaps = groupcaps}
end
registered["grug_materials:pick_iron"] = {name = "grug_materials:pick_iron",
	groups = {pickaxe = 1, grug_pick_tier = 2, grug_gathering_tool = 1},
	tool_capabilities = caps(2, 0.85, true)}
registered["grug_materials:axe_iron"] = {name = "grug_materials:axe_iron",
	groups = {axe = 1, grug_axe_tier = 2, grug_gathering_tool = 1},
	tool_capabilities = caps(2, 1.55, false)}
registered["default:dirt"] = {name = "default:dirt", groups = {}}
local OLD = caps(1, 0.425, false)
local EMPTY = {full_punch_interval = 1.4, damage_groups = {fleshy = 0}, groupcaps = {},
	punch_attack_uses = 0}

local function crafted_old(name)
	local stack = new_stack(name)
	stack:get_meta():set_tool_capabilities(OLD)
	stack.fields.description = "crafted"
	return stack
end
local function broken_old(name)
	local stack = new_stack(name, 1, 65535)
	stack:get_meta():set_string("_grug_repair_caps", core.serialize(OLD))
	stack:get_meta():set_tool_capabilities(EMPTY)
	return stack
end
local function fresh_craft(name)
	local stack = new_stack(name)
	assert(grug_items.crafted_output(stack, nil), "crafted_output " .. name)
	return stack
end

-- A. The registry.
local registry = grug_core.migrations
-- Round 48 lists 0.48.0 after it: 0.47.0 is listed, after 0.45.0.
local listed = {}
for index, version in ipairs(registry.versions) do listed[version] = index end
check(listed["0.47.0"] and listed["0.45.0"] and listed["0.47.0"] > listed["0.45.0"],
	"A 0.47.0 is listed after 0.45.0")
local handler = registry.handlers["0.47.0"]
check(handler and type(handler.character) == "function" and handler.world == nil,
	"A 0.47.0 has a character handler and no world handler")
local run = handler.character

-- B-D. One character with every case.
local player, inv = new_player("miner")
inv:set_size("main", 32)
inv:set_size("grug_bag1_content", 8)
inv:set_size("grug_craft_out", 4)
inv.lists.main[2] = crafted_old("grug_materials:pick_iron")          -- hotbar
inv.lists.main[12] = crafted_old("grug_materials:axe_iron")          -- main
inv.lists.grug_bag1_content[3] = crafted_old("grug_materials:pick_iron")
inv.lists.grug_craft_out[1] = crafted_old("grug_materials:pick_iron")
inv.lists.main[13] = broken_old("grug_materials:pick_iron")
inv.lists.main[14] = new_stack("grug_materials:pick_iron")           -- no copy
inv.lists.main[15] = new_stack("default:dirt", 99)
local sword = fresh_craft("grug_gear:sword_iron")
local sword_caps = sword.fields.tool_capabilities
inv.lists.main[16] = sword
writes = 0
run(player, "1")
local fresh_pick = fresh_craft("grug_materials:pick_iron").fields.tool_capabilities
local fresh_axe = fresh_craft("grug_materials:axe_iron").fields.tool_capabilities
check(fresh_pick == encode(registered["grug_materials:pick_iron"].tool_capabilities),
	"D a craft now stores the new definition's capabilities")
for _, at in ipairs({{"main", 2}, {"grug_bag1_content", 3}, {"grug_craft_out", 1}}) do
	local stack = inv.lists[at[1]][at[2]]
	check(stack.fields.tool_capabilities == fresh_pick and stack.caps.groupcaps.cracky.maxlevel == 2
		and stack.caps.groupcaps.grug_pick_level ~= nil,
		"B " .. at[1] .. "[" .. at[2] .. "]: the old copy rebuilt (maxlevel 2, gated cap)")
	check(stack.fields.description == "crafted", "B " .. at[1] .. "[" .. at[2] ..
		"]: the rest of the meta kept")
end
check(inv.lists.main[12].fields.tool_capabilities == fresh_axe, "B the axe's copy rebuilt")
local broken = inv.lists.main[13]
check(broken.wear == 65535 and broken.fields._grug_repair_caps == fresh_pick and
	broken.fields.tool_capabilities == encode(EMPTY),
	"B the broken pick stays broken; its repair copy is the new definition's")
check(next(inv.lists.main[14].fields) == nil, "C a tool without a copy stays without one")
check(inv.lists.main[16].fields.tool_capabilities == sword_caps, "C a weapon is not touched")
check(writes == 5, "C exactly the five tool stacks with an old copy are written (got " ..
	writes .. ")")

-- E. A second run writes nothing.
writes = 0
run(player, "1")
check(writes == 0, "E a second run writes nothing (got " .. writes .. ")")

if failures > 0 then
	error("R47 MS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R47 MS PORTABLE PASS checks=" .. checks)
