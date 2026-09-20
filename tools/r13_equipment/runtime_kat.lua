local repo = assert(arg[1], "repository path required")

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return setmetatable(result, getmetatable(value))
end
local function check(value, message)
	if not value then error(message, 0) end
end

local definitions = {
	["test:weapon"] = {type = "tool", groups = {grug_equip_weapon = 1}},
	["test:book"] = {type = "tool", groups = {grug_spellbook = 1}},
	["test:hoe"] = {type = "tool", groups = {hoe = 1}},
	["test:food"] = {type = "craft", groups = {}},
}
for _, uses in ipairs({30,60,300,600,1000,1500,2000,3000}) do
 definitions["test:tool" .. uses] = {type="tool",groups={pickaxe=1},_grug_tool_uses=uses}
end
local Stack = {}; Stack.__index = Stack
local function stack(value)
	local result = type(value) == "table" and copy(value) or
		{name = value or "", wear = 0, count = value == "" and 0 or 1,
			meta = {}, caps = {damage_groups = {fleshy = 4}}}
	return setmetatable(result, Stack)
end
function Stack:is_empty() return self.name == "" or self.count == 0 end
function Stack:get_name() return self.name end
function Stack:get_wear() return self.wear end
function Stack:set_wear(value) self.wear = value end
function Stack:get_definition() return definitions[self.name] or {} end
function Stack:get_tool_capabilities() return copy(self.caps) end
function Stack:get_meta()
	local owner = self
	return {
		get_int = function(_, key) return tonumber(owner.meta[key]) or 0 end,
		set_int = function(_, key, value) owner.meta[key] = tostring(value) end,
		get_string = function(_, key) return owner.meta[key] or "" end,
		set_string = function(_, key, value) owner.meta[key] = value end,
		set_tool_capabilities = function(_, value) owner.caps = copy(value) end,
	}
end
ItemStack = stack

local store = {}
local callbacks = {}
local leave_callbacks = {}
local loaded_callbacks = {}
local creative = false
local operations = 0
definitions["test:hoe"].on_use = function(item)
	operations = operations + 1
	item:set_wear(65535)
	return item
end
core = {
	registered_items = definitions,
	get_mod_storage = function()
		return {
			get_string = function(_, key) return store[key] or "" end,
			set_string = function(_, key, value) store[key] = value end,
		}
	end,
	serialize = function(value) return copy(value) end,
	deserialize = function(value) return copy(value) end,
	is_creative_enabled = function() return creative end,
	get_item_group = function(name, group)
		return ((definitions[name] or {}).groups or {})[group] or 0
	end,
	register_on_leaveplayer = function(fn) leave_callbacks[#leave_callbacks + 1] = fn end,
	register_on_mods_loaded = function(fn) loaded_callbacks[#loaded_callbacks + 1] = fn end,
	override_item = function(name, patch)
		for key, value in pairs(patch) do definitions[name][key] = value end
	end,
}
grug_repair = {
	eligible = function(item)
		local groups = item:get_definition().groups or {}
		return (groups.grug_equip_weapon or 0) > 0 or
			(groups.grug_spellbook or 0) > 0 or (groups.hoe or 0) > 0 or (groups.pickaxe or 0) > 0
	end,
}
grug_inventory = {
	BAG_COUNT = 1,
	content_list = function() return "bag1" end,
	is_equipment_list = function(name)
		return name == "grug_weapon" or name == "grug_offhand"
	end,
	equipment_changed = function() end,
}
grug_gear = {reference_purchase_price = function() return 10 end}
grug_core = {
	equipment_is_broken = function(item) return item:get_wear() >= 65535 end,
	register_on_settled_outgoing_action = function(fn) callbacks.outgoing = fn end,
	register_on_settled_incoming_hit = function(fn) callbacks.incoming = fn end,
	run_settled_outgoing_action = function(player, id, kind)
		callbacks.outgoing(player, id, kind)
	end,
}

local lists = {grug_weapon = {}, grug_offhand = {}, main = {}, bag1 = {}}
local inventory = {}
function inventory:get_stack(name, index) return stack((lists[name] or {})[index] or "") end
function inventory:set_stack(name, index, item) lists[name][index] = stack(item) end
function inventory:get_list(name) return copy(lists[name] or {}) end
local player = {
	get_player_name = function() return "owner" end,
	get_inventory = function() return inventory end,
	is_player = function() return true end,
}

local function load_runtime()
	callbacks, leave_callbacks, loaded_callbacks = {}, {}, {}
	dofile(repo .. "/mods/ITEMS/grug_repair/runtime.lua")
	for _, fn in ipairs(loaded_callbacks) do fn() end
end
local function fresh_weapon() return stack("test:weapon") end
load_runtime()
for tier, lifetime in ipairs({1000, 1500, 2000, 2500, 3000, 4000}) do
 definitions["test:weapon"]._grug_bracket = tier
 lists.grug_weapon[1] = fresh_weapon()
 lists.grug_offhand[1] = stack("test:book")
 for index = 1, lifetime - 1 do callbacks.outgoing(player, tier .. ":" .. index, "damage") end
 check(lists.grug_weapon[1].wear < 65535, "weapon broke early at tier " .. tier)
 callbacks.outgoing(player, tier .. ":" .. lifetime, "damage")
 check(lists.grug_weapon[1].wear == 65535, "wrong weapon lifetime " .. tier)
 check(lists.grug_offhand[1].wear == 0, "outgoing wore offhand")
 check(lists.grug_weapon[1].caps.damage_groups.fleshy == 0, "broken capabilities active")
end
definitions["test:weapon"]._grug_bracket = 1

local broken_hoe = stack("test:hoe"); broken_hoe:set_wear(65535)
local returned = definitions["test:hoe"].on_use(broken_hoe, player, {})
check(operations == 0 and returned:get_wear() == 65535,
	"broken hoe performed or destroyed its operation")

lists.grug_weapon[1] = fresh_weapon(false)
local heal_action = {id = "heal:one"}
local before_heal = lists.grug_weapon[1].wear
callbacks.outgoing(player, heal_action, "heal")
local once = lists.grug_weapon[1].wear
check(once == before_heal + 65,
	"shared heal action did not debit the expected durability")
callbacks.outgoing(player, heal_action, "heal")
callbacks.outgoing(player, heal_action, "absorb")
check(lists.grug_weapon[1].wear == once,
	"one multi-target heal/absorb action spent more than once")
local ordinary_action = {}
local before_ordinary = lists.grug_weapon[1].wear
callbacks.outgoing(player, ordinary_action, "damage")
local ordinary_once = lists.grug_weapon[1].wear
check(ordinary_once == before_ordinary + 66,
	"ordinary table action identity did not debit the expected durability")
callbacks.outgoing(player, ordinary_action, "damage")
check(lists.grug_weapon[1].wear == ordinary_once,
	"ordinary table action identity without id did not debit exactly once")
creative = true
callbacks.outgoing(player, "creative")
check(lists.grug_weapon[1].wear == ordinary_once, "creative action spent durability")
creative = false

lists.grug_weapon[1] = fresh_weapon(false)
local first_receipt = grug_repair.capture_action(player, "projectile:first")
lists.main[1] = lists.grug_weapon[1]
load_runtime()
lists.grug_weapon[1] = fresh_weapon(false)
local receipt = grug_repair.capture_action(player, "projectile:second")
check(first_receipt.item_ids[1] == "repair:1" and
	receipt.item_ids[1] == "repair:2",
	"persistent identity serial was reused after restart")
local launched = lists.grug_weapon[1]
lists.bag1[1] = launched
lists.grug_weapon[1] = fresh_weapon(false)
local persisted = copy(receipt)
callbacks.outgoing(player, persisted, "damage")
check(lists.bag1[1].wear > 0, "persisted launch item was not worn after restart/swap")
check(lists.main[1].wear == 0 and lists.grug_weapon[1].wear == 0,
	"settlement wore the prior persisted or replacement item")

-- Run actual after_use wrappers through every exact gathering lifetime.
for _, uses in ipairs({30,60,300,600,1000,1500,2000,3000}) do
 local name = "test:tool" .. uses
 local item = stack(name)
 for n = 1, uses - 1 do item = definitions[name].after_use(item,player,{}, {wear=1}) end
 check(item:get_wear() < 65535, "gathering tool broke early " .. uses)
 item = definitions[name].after_use(item,player,{}, {wear=1})
 check(item:get_wear() == 65535 and not item:is_empty(), "gathering lifetime differs " .. uses)
 local intact = stack(name)
 intact = definitions[name].after_use(intact,player,{}, {wear=0})
 check(intact:get_wear() == 0, "wear-free dig charged")
end

-- All incoming candidates share one debit; a broken piece cannot be selected.
for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet"}) do
 lists[list] = {stack("test:book")}
end
lists.grug_offhand = {stack("test:book")}
local previous = 0
math.randomseed(1301)
for hit = 1, 30 do
 callbacks.incoming(player)
 local total = 0
 for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet", "grug_offhand"}) do
  total = total + lists[list][1].wear
 end
 check(total - previous == 65 or total - previous == 66, "incoming wore more than one item")
 previous = total
end
for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet"}) do lists[list][1]:set_wear(65535) end
local before = lists.grug_offhand[1].wear
callbacks.incoming(player)
check(lists.grug_offhand[1].wear > before, "intact offhand excluded")
lists.grug_offhand[1]:set_wear(65535)
callbacks.incoming(player) -- no candidates is a valid no-op
print("r13_equipment_runtime_kat\tPASS: all six lifetimes, one incoming item, main-only, action identity, delayed settlement")
