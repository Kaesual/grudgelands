-- Focused engine-free contract test for the Round 75 functional displays.
local root = arg[1] or "."
local passed = 0
local function check(value, label)
	if not value then error("FAIL: " .. label, 0) end
	passed = passed + 1
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ")")
end

table.copy = function(source)
	local out = {}
	for key, value in pairs(source or {}) do out[key] = value end
	return out
end
vector = {
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
	round = function(p) return {x = p.x, y = p.y, z = p.z} end,
	copy = function(p) return {x = p.x, y = p.y, z = p.z} end,
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end,
	multiply = function(a, n) return {x = a.x * n, y = a.y * n, z = a.z * n} end,
}

local groups = {
	["test:head"] = {grug_equip_head = 1},
	["test:chest"] = {grug_equip_chest = 1},
	["test:legs"] = {grug_equip_legs = 1},
	["test:feet"] = {grug_equip_feet = 1},
	["test:sword"] = {grug_equip_weapon = 1},
	["test:shield"] = {grug_shield = 1},
}
local Stack = {}
Stack.__index = Stack
function Stack:new(name, count, broken, affixes, serialized)
	return setmetatable({name = name or "", count = count or 0, broken = broken,
		affixes = affixes, serialized = serialized}, self)
end
function Stack:is_empty() return self.name == "" or self.count == 0 end
function Stack:get_count() return self.count end
function Stack:get_name() return self.name end
function Stack:to_string() return self.serialized or (self.name .. " " .. self.count) end

local lists = {}
local Inventory = {}
function Inventory:get_stack(name) return lists[name] or Stack:new() end
function Inventory:set_size() end
function Inventory:is_empty(name) return self:get_stack(name):is_empty() end
local inventory = setmetatable({}, {__index = Inventory})

local nodes, entities, objects = {}, {}, {}
local shown, violations, interaction_protected = 0, 0, false
local placed_param2, built_form, refreshed_forms
local function live_objects()
	local out = {}
	for _, object in ipairs(objects) do
		if not object.removed then out[#out + 1] = object end
	end
	return out
end
core = {
	registered_nodes = nodes,
	get_item_group = function(name, group) return (groups[name] or {})[group] or 0 end,
	get_meta = function() return {get_inventory = function() return inventory end} end,
	facedir_to_dir = function() return {x = 0, y = 0, z = 1} end,
	dir_to_yaw = function() return 0 end,
	register_entity = function(name, def) entities[name] = def end,
	register_lbm = function(def) core.lbm = def end,
	get_objects_inside_radius = live_objects,
	get_node_or_nil = function() return {name = "grug_displays:armor_stand", param2 = 0} end,
	add_entity = function(pos, name)
		local entity = {name = name}
		local object = {entity = entity, pos = pos}
		entity.object = object
		function object:get_luaentity() return self.entity end
		function object:remove() self.removed = true end
		function object:set_pos(at) self.pos = at end
		function object:set_properties(properties) self.properties = properties end
		function object:set_yaw(yaw) self.yaw = yaw end
		function object:set_animation(animation, speed, blend, loop)
			self.animation, self.animation_speed, self.animation_loop = animation, speed, loop
		end
		function object:set_armor_groups() end
		objects[#objects + 1] = object
		entities[name].on_activate(entity)
		return object
	end,
	register_node = function(name, def) nodes[name] = def end,
	override_item = function(name, def)
		for key, value in pairs(def) do nodes[name][key] = value end
	end,
	is_protected = function() return false end,
	dir_to_facedir = function(dir)
		if dir.z == 1 then return 0 elseif dir.x == 1 then return 1
		elseif dir.z == -1 then return 2 else return 3 end
	end,
	item_place = function(stack, player, pointed, param2)
		placed_param2 = param2
		return stack
	end,
	record_protection_violation = function() violations = violations + 1 end,
	formspec_escape = tostring,
	pos_to_string = function() return "(0,0,0)" end,
}
default = {
	node_sound_wood_defaults = function() return {} end,
	node_formspec = {
		location = function() return "nodemeta:0,0,0" end,
		show = function(player, pos, build)
			shown = shown + 1
			built_form = build(pos, player, {})
		end,
		refresh = function() refreshed_forms = (refreshed_forms or 0) + 1 end,
	},
}
grug_core = {
	equipment_is_broken = function(stack) return stack.broken == true end,
	interaction_protected = function() return interaction_protected end,
	ui = {text_growth = function() return 1 end,
		heading = function(_, _, text) return "heading[" .. text .. "]" end},
}
grug_inventory = {
	STATION = {x = 0.8, y = 1.2, pitch = 1.1},
	station_box = function() return "station_box[]", 3 end,
	station_formspec = function(player, content)
		return "combined_inventory[]" .. content
	end,
}
grug_visuals = {
	SLOTS = {"head", "chest", "legs", "feet"},
	WEAPON_NONE = "blank.png", OFFHAND_NONE = "blank.png", BACK_NONE = "blank.png",
	NPC_MODEL = "grug_visuals_npc.b3d",
	armor_enchants = function(worn)
		local out = {}
		for slot, row in pairs(worn) do out[slot] = row.affixes end
		return out
	end,
	compose = function(spec)
		local names = {}
		for _, slot in ipairs(grug_visuals.SLOTS) do
			if spec.armor[slot] then names[#names + 1] = spec.armor[slot] end
		end
		return {skin = spec.skin, armor = #names > 0 and table.concat(names, "^") or "blank.png"}
	end,
}
grug_items = {get_affixes = function(stack) return stack.affixes end}
grug_displays = {}

dofile(root .. "/mods/PLAYER/grug_displays/entities.lua")

check(grug_displays.slot_accepts("head", Stack:new("test:head", 1)), "head accepts head armor")
check(not grug_displays.slot_accepts("head", Stack:new("test:chest", 1)), "head rejects chest armor")
check(not grug_displays.slot_accepts("head", Stack:new("test:head", 2)), "armor rejects a count above one")
check(grug_displays.weapon_accepts(Stack:new("test:sword", 1)), "holder accepts weapon")
check(grug_displays.weapon_accepts(Stack:new("test:shield", 1)), "holder accepts shield")
check(not grug_displays.weapon_accepts(Stack:new("test:chest", 1)), "holder rejects arbitrary gear")

lists.head = Stack:new("test:head", 1, true, {prefix = "might"})
lists.chest = Stack:new("test:chest", 1, false, {suffix = "guard"})
lists.legs = Stack:new("test:legs", 1)
lists.feet = Stack:new("test:feet", 1)
local spec = grug_displays.stand_spec({x = 0, y = 0, z = 0})
check(spec._has_armor, "populated stand reports armor")
check(spec.armor_broken.head, "broken state reaches the renderer")
eq(spec.armor_enchant.head.prefix, "might", "prefix reaches the renderer")
eq(spec.armor_enchant.chest.suffix, "guard", "suffix reaches the renderer")
local textures = grug_displays.stand_textures(spec)
eq(#textures, 5, "mixed armor uses the NPC model's five texture channels")
check(textures[2]:find("test:head", 1, true) ~= nil and
	textures[2]:find("test:feet", 1, true) ~= nil, "mixed slots share the armor atlas")
nodes["grug_displays:armor_stand"] = {_grug_display_kind = "stand"}
grug_displays.refresh({x = 0, y = 0, z = 0})
eq(#live_objects(), 1, "refresh creates one unsaved projection")
eq(live_objects()[1].animation.x, 0, "armor projection uses a static pose frame")
eq(live_objects()[1].animation_speed, 0, "armor projection has no idle animation")
grug_displays.refresh({x = 0, y = 0, z = 0})
eq(#live_objects(), 1, "repeated refresh deduplicates the projection")
core.lbm.action({x = 0, y = 0, z = 0})
eq(#live_objects(), 1, "load-time restoration deduplicates the projection")
grug_displays.remove({x = 0, y = 0, z = 0})
eq(#live_objects(), 0, "node destruction removes its projection")
lists.item = Stack:new("test:sword", 1)
nodes["grug_displays:armor_stand"] = {_grug_display_kind = "frame"}
grug_displays.refresh({x = 0, y = 0, z = 0})
eq(live_objects()[1].pos.z, 0.32, "framed item sits in front of the frame face")
grug_displays.remove({x = 0, y = 0, z = 0})
local serialized_weapon = "test:sword 1 0 {enchanted metadata}"
lists.item = Stack:new("test:sword", 1, false, nil, serialized_weapon)
nodes["grug_displays:armor_stand"] = {_grug_display_kind = "weapon"}
grug_displays.refresh({x = 0, y = 0, z = 0})
eq(live_objects()[1].properties.wield_item, serialized_weapon,
	"wield projection preserves the complete serialized stack")
eq(live_objects()[1].properties.textures[1], "test:sword",
	"legacy wield texture contains only the item basename")
eq(live_objects()[1].pos.z, 0.30, "wall holder item sits in front of its rack")
grug_displays.remove({x = 0, y = 0, z = 0})

nodes["grug_decor:xdecor_itemframe"] = {groups = {}}
dofile(root .. "/mods/PLAYER/grug_displays/nodes.lua")
eq(nodes["grug_decor:xdecor_itemframe"]._grug_decor_family, "N01", "old frame id is N01")
eq(nodes["grug_displays:frame_iron"]._grug_decor_family, "N03", "special frame is N03")
eq(nodes["grug_displays:armor_stand"]._grug_decor_family, "N02", "basic stand is N02")
eq(nodes["grug_displays:armor_stand_iron"]._grug_decor_family, "N04", "special stand is N04")
eq(nodes["grug_displays:weapon_holder"]._grug_decor_family, "N05", "holder is N05")
eq(nodes["grug_displays:weapon_holder"]._grug_decor_mount, "wall", "holder mounts on a wall")
core.is_protected = function() return true end
check(not nodes["grug_displays:armor_stand"].can_dig({x = 0, y = 0, z = 0},
	{get_player_name = function() return "stranger" end}), "protected stand cannot be dug")
core.is_protected = function() return false end
check(not nodes["grug_displays:armor_stand"].can_dig({x = 0, y = 0, z = 0}, nil),
	"filled stand cannot be dug")
for _, slot in ipairs(grug_visuals.SLOTS) do lists[slot] = Stack:new() end
check(nodes["grug_displays:armor_stand"].can_dig({x = 0, y = 0, z = 0}, nil),
	"empty unprotected stand can be dug")

local player = {is_player = function() return true end,
	get_player_name = function() return "friend" end}
local stand = nodes["grug_displays:armor_stand"]
interaction_protected = false
stand.on_rightclick({x = 0, y = 0, z = 0}, nil, player, Stack:new())
eq(shown, 1, "claim friend with interact permission opens the display")
check(built_form:find("combined_inventory", 1, true) ~= nil,
	"display uses the combined bag station formspec")
eq(stand.allow_metadata_inventory_put({x = 0, y = 0, z = 0}, "head", 1,
	Stack:new("test:head", 1), player), 1, "claim friend may put")
eq(stand.allow_metadata_inventory_take({x = 0, y = 0, z = 0}, "head", 1,
	Stack:new("test:head", 1), player), 1, "claim friend may take")
interaction_protected = true
stand.on_rightclick({x = 0, y = 0, z = 0}, nil, player, Stack:new())
eq(shown, 1, "world-protected or unauthorized claim display stays closed")
eq(stand.allow_metadata_inventory_put({x = 0, y = 0, z = 0}, "head", 1,
	Stack:new("test:head", 1), player), 0, "protected display refuses put")
eq(stand.allow_metadata_inventory_take({x = 0, y = 0, z = 0}, "head", 1,
	Stack:new("test:head", 1), player), 0, "protected display refuses take")
eq(stand.allow_metadata_inventory_move({x = 0, y = 0, z = 0}, "head", 1,
	"chest", 1, 1, player), 0, "protected display refuses move")
check(violations >= 4, "protected display records interaction violations")

local frame = nodes["grug_decor:xdecor_itemframe"]
placed_param2 = nil
frame.on_place(Stack:new("grug_decor:xdecor_itemframe", 1), player,
	{type = "node", under = {x = 0, y = 0, z = 0}, above = {x = 0, y = 0, z = -1}})
eq(placed_param2, 0, "frame orientation follows the clicked wall face")
placed_param2 = nil
frame.on_place(Stack:new("grug_decor:xdecor_itemframe", 1), player,
	{type = "node", under = {x = 0, y = 0, z = 0}, above = {x = 0, y = 1, z = 0}})
eq(placed_param2, nil, "frame refuses floor and ceiling placement")

local stored = "test:sword 1 0 {bound enchanted metadata}"
lists.item = Stack:new("test:sword", 1, false, nil, stored)
local frame_drops = {Stack:new("grug_decor:xdecor_itemframe", 1)}
frame.preserve_metadata({x = 0, y = 0, z = 0}, nil, {}, frame_drops)
eq(#frame_drops, 2, "support loss drops the filled frame's stored item")
eq(frame_drops[2]:to_string(), stored, "frame support-loss drop preserves item metadata")
local holder_drops = {Stack:new("grug_displays:weapon_holder", 1)}
nodes["grug_displays:weapon_holder"].preserve_metadata(
	{x = 0, y = 0, z = 0}, nil, {}, holder_drops)
eq(#holder_drops, 2, "support loss drops the holder's stored weapon")
eq(holder_drops[2]:to_string(), stored, "holder support-loss drop preserves item metadata")

print(("r75 displays: %d passed, 0 failed"):format(passed))
