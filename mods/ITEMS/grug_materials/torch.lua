-- The Anthracite torch (Round 47 ruling 10): a floor, wall and ceiling node
-- triple modelled on the vendored torch (mods/BASE/default/torch.lua): the
-- same meshes, selection boxes, groups and placement, light 14 (the
-- engine's LIGHT_MAX) instead of 12. Its Basic recipe (10 from 1 Anthracite
-- and 1 stick) is a row of tools/r45_rg/edits.lua.
--
-- Spawn rules read the light where a mob would stand (mobs_redo's
-- max_light, grug_mobs/spawn_policy.lua): light falls by one per node, so
-- cave rows (max_light 7) stay clear within 6 nodes of this torch (4 for
-- the Coal torch) and night rows (max_light 5) within 8 (6).

local FLOOR = "grug_materials:anthracite_torch"
local WALL = "grug_materials:anthracite_torch_wall"
local CEILING = "grug_materials:anthracite_torch_ceiling"
local LIGHT = 14

-- Textures: lane ART's Anthracite set (the user's pick of 2026-10-13), in
-- the vendored torch's formats. All three meshes sample the floor sheet, as
-- the vendored triple does with default_torch_on_floor_animated.png; the
-- set's ceiling and wall sheets keep the vendored files' layouts for a mesh
-- that would sample them.
local INVENTORY_IMAGE = "grug_materials_anthracite_torch_on_floor.png"
local TILE = {
	name = "grug_materials_anthracite_torch_on_floor_animated.png",
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3},
}

-- As the vendored torch, a flood removes the node and drops the torch item.
-- The vendored hiss is a raw sound call, which a grug mod does not make
-- (one play path, grug_sounds); this torch goes out silently.
local function on_flood(pos)
	core.add_item(pos, ItemStack(FLOOR))
	return false
end

local function base(groups, mesh, selection_box)
	return {
		drawtype = "mesh",
		mesh = mesh,
		tiles = {TILE},
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		walkable = false,
		liquids_pointable = false,
		light_source = LIGHT,
		groups = groups,
		drop = FLOOR,
		selection_box = selection_box,
		sounds = default.node_sound_wood_defaults(),
		floodable = true,
		on_flood = on_flood,
		on_rotate = false,
	}
end

local floor = base({choppy = 2, dig_immediate = 3, flammable = 1, attached_node = 1,
		torch = 1}, "torch_floor.obj",
	{type = "wallmounted", wall_bottom = {-1/8, -1/2, -1/8, 1/8, 2/16, 1/8}})
floor.description = "Anthracite Torch"
floor.inventory_image = INVENTORY_IMAGE
floor.wield_image = INVENTORY_IMAGE
-- The vendored placement: a right-clickable node gets the click (unless
-- sneaking), else the torch takes the floor, wall or ceiling form.
floor.on_place = function(itemstack, placer, pointed_thing)
	local under = pointed_thing.under
	local node = core.get_node(under)
	local def = core.registered_nodes[node.name]
	if def and def.on_rightclick and
			not (placer and placer:is_player() and
			placer:get_player_control().sneak) then
		return def.on_rightclick(under, node, placer, itemstack,
			pointed_thing) or itemstack
	end
	local above = pointed_thing.above
	local wdir = core.dir_to_wallmounted(vector.subtract(under, above))
	local fakestack = itemstack
	if wdir == 0 then
		fakestack:set_name(CEILING)
	elseif wdir == 1 then
		fakestack:set_name(FLOOR)
	else
		fakestack:set_name(WALL)
	end
	itemstack = core.item_place(fakestack, placer, pointed_thing, wdir)
	itemstack:set_name(FLOOR)
	return itemstack
end
core.register_node(FLOOR, floor)

core.register_node(WALL, base({choppy = 2, dig_immediate = 3, flammable = 1,
		not_in_creative_inventory = 1, attached_node = 1, torch = 1}, "torch_wall.obj",
	{type = "wallmounted", wall_side = {-1/2, -1/2, -1/8, -1/8, 1/8, 1/8}}))

core.register_node(CEILING, base({choppy = 2, dig_immediate = 3, flammable = 1,
		not_in_creative_inventory = 1, attached_node = 1, torch = 1}, "torch_ceiling.obj",
	{type = "wallmounted", wall_top = {-1/8, -1/16, -5/16, 1/8, 1/2, 1/8}}))

grug_materials.ANTHRACITE_TORCH = {floor = FLOOR, wall = WALL, ceiling = CEILING,
	light = LIGHT}
