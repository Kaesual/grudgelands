-- Known-answer test for the weapon-slot item-level gate (round 5 Lane A).
-- Loads the real equipment.lua under a minimal engine stub.

local repo = arg[1] or "."
local allow_callback
local messages = {}
local player_level = 1

local Stack = {}
Stack.__index = Stack

function ItemStack(value)
	if getmetatable(value) == Stack then
		return setmetatable({name = value.name, count = value.count}, Stack)
	end
	return setmetatable({name = type(value) == "string" and value or "",
		count = 1}, Stack)
end

function Stack:get_name() return self.name end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.name == "" end

local callbacks = {}
core = {
	registered_items = {
		["test:level_weapon"] = {description = "Level Weapon",
			groups = {grug_equip_weapon = 1}, _grug_ilvl = 20},
		["test:starter_weapon"] = {description = "Starter Weapon",
			groups = {grug_equip_weapon = 1}},
		["test:tool_axe"] = {description = "Tool Axe",
			groups = {grug_equip_weapon = 1, axe = 1}},
		["test:tool_pick"] = {description = "Tool Pick",
			groups = {pick = 1}, _grug_ilvl = 50},
	},
	register_allow_player_inventory_action = function(fn) allow_callback = fn end,
	register_on_joinplayer = function(fn) callbacks.join = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave = fn end,
	register_on_player_inventory_action = function(fn) callbacks.action = fn end,
	register_on_mods_loaded = function(fn) callbacks.mods_loaded = fn end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	chat_send_player = function(name, message)
		messages[#messages + 1] = name .. ":" .. message
	end,
	colorize = function(_, text) return text end,
	log = function() end,
	after = function() end,
	get_player_by_name = function() return nil end,
}

grug_inventory = {}
grug_core = {
	mono_time = function() return 0 end,
	notify_equipment_change = function() end,
	status_modifier_sum = function() return 0 end,
	can_use_item_level = function(_, stack)
		local definition = core.registered_items[stack:get_name()]
		local required = definition and definition._grug_ilvl
		if type(required) ~= "number" or required <= 0 then
			return true, nil, player_level
		end
		return player_level >= required, required, player_level
	end,
}
grug_classes = {
	class_ids = {"warrior", "mage", "priest"},
	get_armor_rank = function() return 3 end,
	get_class_def = function() return {name = "Warrior"} end,
	get_class = function() return "warrior" end,
	get_talent_bonus = function() return 0 end,
	register_on_class_chosen = function(fn)
		callbacks.class_chosen = callbacks.class_chosen or {}
		callbacks.class_chosen[#callbacks.class_chosen + 1] = fn
	end,
}
grug_gear = {STARTER_SWORD = "test:starter_weapon",
	STARTER_STAFF = "test:starter_weapon"}
grug_xp = {get_level = function() return player_level end}

local inventory = {}
function inventory:get_stack() return ItemStack("") end

local player = {}
function player:is_player() return true end
function player:get_player_name() return "kat" end
function player:get_inventory() return inventory end

assert(loadfile(repo .. "/mods/PLAYER/grug_inventory/equipment.lua"))()
assert(type(allow_callback) == "function", "equipment allow callback was not registered")

local function put(listname, itemname)
	return allow_callback(player, "put", inventory,
		{listname = listname, stack = ItemStack(itemname)})
end

player_level = 19
assert(put("grug_weapon", "test:level_weapon") == 0,
	"below-level weapon was accepted")
assert(#messages == 1 and messages[1]:find("requires level 20", 1, true),
	"below-level refusal did not explain the required level")

player_level = 20
assert(put("grug_weapon", "test:level_weapon") == 1,
	"at-level weapon was refused")
player_level = 21
assert(put("grug_weapon", "test:level_weapon") == 1,
	"above-level weapon was refused")

player_level = 1
assert(put("grug_weapon", "test:starter_weapon") == 1,
	"weapon without ilvl was gated")
assert(put("grug_weapon", "test:tool_axe") == 1,
	"tool-ladder axe without ilvl was gated")
assert(put("main", "test:tool_pick") == nil,
	"non-equipment tool action was claimed by the equipment filter")

print("weapon_level_gate_kat: PASS below=0 at=1 above=1 no_ilvl=1 tools=untouched")
