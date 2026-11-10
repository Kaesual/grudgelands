local M = grug_displays

local ENTITY = "grug_displays:projection"
local RADIUS = 1.1
local BLANK = "blank.png"

local function same_pos(a, b)
	return a and b and vector.equals(a, b)
end

local function attached(pos)
	local found = {}
	for _, object in ipairs(core.get_objects_inside_radius(pos, RADIUS)) do
		local entity = object:get_luaentity()
		if entity and entity.name == ENTITY and same_pos(entity._grug_display_pos, pos) then
			found[#found + 1] = entity
		end
	end
	return found
end

local function facedir_yaw(node)
	local dir = core.facedir_to_dir((node.param2 or 0) % 4)
	return core.dir_to_yaw(dir)
end

local function frame_projection(pos, node, stack)
	if stack:is_empty() then return nil end
	local dir = core.facedir_to_dir((node.param2 or 0) % 4)
	return {
		-- The frame occupies local z 0.4375..0.5; 0.32 is in front of its face.
		at = vector.add(pos, vector.multiply(dir, 0.32)),
		properties = {
			visual = "wielditem",
			wield_item = stack:to_string(),
			textures = {stack:get_name()},
			visual_size = {x = 0.30, y = 0.30},
			selectionbox = {0, 0, 0, 0, 0, 0},
		},
		yaw = facedir_yaw(node),
	}
end

local SLOT_GROUP = {
	head = "grug_equip_head",
	chest = "grug_equip_chest",
	legs = "grug_equip_legs",
	feet = "grug_equip_feet",
}

function M.slot_accepts(slot, stack)
	local group = SLOT_GROUP[slot]
	return group ~= nil and stack ~= nil and not stack:is_empty() and
		stack:get_count() == 1 and core.get_item_group(stack:get_name(), group) > 0
end

function M.weapon_accepts(stack)
	if stack == nil or stack:is_empty() or stack:get_count() ~= 1 then return false end
	local name = stack:get_name()
	return core.get_item_group(name, "grug_equip_weapon") > 0 or
		core.get_item_group(name, "grug_shield") > 0
end

function M.stand_spec(pos)
	local inv = core.get_meta(pos):get_inventory()
	local armor, broken, worn = {}, {}, {}
	local count = 0
	for _, slot in ipairs(grug_visuals.SLOTS) do
		local stack = inv:get_stack(slot, 1)
		if M.slot_accepts(slot, stack) then
			count = count + 1
			armor[slot] = stack:get_name()
			broken[slot] = grug_core.equipment_is_broken(stack)
			local items = rawget(_G, "grug_items")
			worn[slot] = {name = stack:get_name(),
				affixes = items and items.get_affixes(stack) or nil}
		end
	end
	return {skin = BLANK, armor = armor, armor_broken = broken, _has_armor = count > 0,
		armor_enchant = grug_visuals.armor_enchants(worn)}
end

function M.stand_textures(spec)
	local result = grug_visuals.compose(spec)
	return {result.skin, result.armor, grug_visuals.WEAPON_NONE,
		grug_visuals.OFFHAND_NONE, grug_visuals.BACK_NONE}, result
end

local function stand_projection(pos, node)
	local stand = M.stand_spec(pos)
	if not stand._has_armor then return nil end
	local textures = M.stand_textures(stand)
	return {
		at = {x = pos.x, y = pos.y - 0.5, z = pos.z},
		properties = {
			visual = "mesh", mesh = grug_visuals.NPC_MODEL,
			textures = textures, visual_size = {x = 1, y = 1},
			selectionbox = {0, 0, 0, 0, 0, 0},
		},
		yaw = facedir_yaw(node), animation = {x = 0, y = 0},
	}
end

local function weapon_projection(pos, node, stack)
	if stack:is_empty() then return nil end
	local dir = core.facedir_to_dir((node.param2 or 0) % 4)
	return {
		at = vector.add(pos, vector.multiply(dir, 0.30)),
		properties = {visual = "wielditem",
			wield_item = stack:to_string(),
			textures = {stack:get_name()},
			visual_size = {x = 0.42, y = 0.42}, selectionbox = {0, 0, 0, 0, 0, 0}},
		yaw = facedir_yaw(node),
	}
end

local function wanted(pos, node)
	local kind = (core.registered_nodes[node.name] or {})._grug_display_kind
	local inv = core.get_meta(pos):get_inventory()
	if kind == "frame" then return frame_projection(pos, node, inv:get_stack("item", 1)) end
	if kind == "stand" then return stand_projection(pos, node) end
	if kind == "weapon" then return weapon_projection(pos, node, inv:get_stack("item", 1)) end
	return nil
end

function M.remove(pos)
	pos = vector.round(pos)
	for _, entity in ipairs(attached(pos)) do entity.object:remove() end
end

function M.refresh(pos)
	pos = vector.round(pos)
	local node = core.get_node_or_nil(pos)
	local spec = node and wanted(pos, node) or nil
	local found = attached(pos)
	local kept = found[1]
	for index = 2, #found do found[index].object:remove() end
	if not spec then
		if kept then kept.object:remove() end
		return
	end
	if not kept then
		local object = core.add_entity(spec.at, ENTITY)
		kept = object and object:get_luaentity()
		if not kept then return end
		kept._grug_display_pos = vector.copy(pos)
	end
	kept.object:set_pos(spec.at)
	kept.object:set_properties(spec.properties)
	kept.object:set_yaw(spec.yaw)
	if spec.animation then kept.object:set_animation(spec.animation, 0, 0, false) end
end

core.register_entity(ENTITY, {
	initial_properties = {physical = false, collide_with_objects = false,
		pointable = false, static_save = false, visual = "sprite",
		textures = {BLANK}, collisionbox = {0, 0, 0, 0, 0, 0}, hp_max = 1},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
})

core.register_lbm({
	label = "Recreate functional display projections",
	name = "grug_displays:restore",
	nodenames = {"group:grug_functional_display"},
	run_at_every_load = true,
	action = function(pos) M.refresh(pos) end,
})
