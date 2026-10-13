-- Tree prototype (Round 46 lane TREE). A draft for the user to judge from
-- engine screenshots; nothing in world generation, town dressing or
-- saplings uses it. Dropping the mod folder removes it completely.
--
--   shapes.lua     the four wood shapes (corner, branch, twig, root)
--   generator.lua  the seeded generator for the jungle tree, the kapok and
--                  the apple tree
--   metrics.lua    node and face counts by the client's culling rules
--
-- This file registers the shapes for every wood type in WOODS (one row per
-- wood type, one loop) and a tinted stand-in of its leaves, and extends leaf
-- decay so the shapes hold leaves like the trunk does.
--
-- Every shape drops the wood type's normal trunk (as the tier rocks all drop
-- Cobble), copies the trunk's groups (tree, choppy, its level), stays out of
-- the creative inventory and refuses to be placed, so a player never holds
-- or builds one.

grug_treeproto = {}

local modpath = core.get_modpath(core.get_current_modname())
local shapes = dofile(modpath .. "/shapes.lua")
local generator = dofile(modpath .. "/generator.lua")
generator.set_corner_rule(shapes.corner_param2)
grug_treeproto.shapes = shapes
grug_treeproto.generator = generator
grug_treeproto.metrics = dofile(modpath .. "/metrics.lua")(shapes)

-- One row per wood type. `leaves` are the leaf decay list of the wood (its
-- leaves last), `fruit` what a fruit cell places, `decay_radius` default's
-- leaf decay radius for these leaves outside mapgen v6 (default/nodes.lua
-- "register trees for leafdecay"). A new wood type is one more row.
grug_treeproto.WOODS = {
	{key = "jungle", trunk = "default:jungletree",
		top = "default_jungletree_top.png", bark = "default_jungletree.png",
		leaves = {"default:jungleleaves"}, fruit = "default:jungleleaves",
		decay_radius = 2},
	{key = "oak", trunk = "default:tree",
		top = "default_tree_top.png", bark = "default_tree.png",
		leaves = {"default:apple", "default:leaves"}, fruit = "default:apple",
		decay_radius = 3},
}

-- Four leaf tints on one leaf node: param2 is a palette index. The palette
-- is a generated 8 x 1 image (no texture file); the engine stretches an
-- 8-pixel palette over 256 values, so pixel k answers param2 32k..32k+31
-- (src/client/texturesource.cpp getPalette). param2 1, which default's
-- after_place_leaves writes to mark a player's leaves (and which leaf decay
-- then skips), therefore keeps the untinted pixel 0. Hardware colouring
-- multiplies, so every tint is a little darker than the texture.
--
-- The prototype does NOT change default's leaves: their paramtype2 is part
-- of the world generator's frozen content digest (grug_mapgen
-- wp40/r7_manifest.lua "frozen content semantics"), which an override breaks
-- at load. It registers one tinted stand-in per wood type instead, a copy of
-- the wood's leaves (same texture, drops and decay) with the palette; the
-- drafts use it. Integration would put the palette on the real leaves and
-- renew that pin (a map reset).
grug_treeproto.LEAF_PALETTE = "[fill:8x1:#ffffff" ..
	"^[fill:1x1:1,0:#d6ebbf" ..
	"^[fill:1x1:2,0:#bfd2b0" ..
	"^[fill:1x1:3,0:#fff0bf"

local function node_box(boxes)
	local result = {}
	for index = 1, #boxes do
		local b = boxes[index]
		result[index] = {b[1] / 16, b[2] / 16, b[3] / 16, b[4] / 16, b[5] / 16,
			b[6] / 16}
	end
	return result
end

local function definition_box(shape)
	if shape.kind == "fixed" then
		return {type = "fixed", fixed = node_box(shape.boxes)}
	end
	local box = {type = "connected", fixed = node_box({shape.core})}
	for _, side in ipairs(shapes.SIDES) do
		if shape.arms[side] then
			box["connect_" .. side] = node_box({shape.arms[side]})
		end
	end
	return box
end

local function refuse_place(itemstack)
	return itemstack
end

-- The node name of one shape of one wood type.
function grug_treeproto.shape_name(wood_key, shape)
	return "grug_treeproto:" .. wood_key .. "_" .. shape
end

-- The tinted stand-in leaves of one wood type.
function grug_treeproto.tinted_leaves_name(wood_key)
	return "grug_treeproto:" .. wood_key .. "_leaves"
end

-- kind -> node name for the generator's cells of one wood type.
function grug_treeproto.names(wood_key)
	for _, row in ipairs(grug_treeproto.WOODS) do
		if row.key == wood_key then
			local names = {trunk = row.trunk,
				leaves = grug_treeproto.tinted_leaves_name(row.key), fruit = row.fruit}
			for _, shape in ipairs(shapes.ORDER) do
				names[shape] = grug_treeproto.shape_name(row.key, shape)
			end
			return names
		end
	end
	error("grug_treeproto: unknown wood " .. tostring(wood_key))
end

for _, row in ipairs(grug_treeproto.WOODS) do
	local trunk = core.registered_nodes[row.trunk]
	assert(trunk, "grug_treeproto: no trunk " .. row.trunk)
	local groups = table.copy(trunk.groups)
	groups.not_in_creative_inventory = 1
	groups.grug_tree_shape = 1
	local family = {row.trunk}
	for _, shape in ipairs(shapes.ORDER) do
		family[#family + 1] = grug_treeproto.shape_name(row.key, shape)
	end
	for _, shape_key in ipairs(shapes.ORDER) do
		local shape = shapes.SHAPES[shape_key]
		local tiles = {row.bark}
		if shape.tiles == "top_top_bark" then
			tiles = {row.top, row.top, row.bark}
		end
		core.register_node(grug_treeproto.shape_name(row.key, shape_key), {
			description = trunk.description,
			drawtype = "nodebox",
			paramtype = "light",
			paramtype2 = shape.kind == "fixed" and "facedir" or nil,
			node_box = definition_box(shape),
			connects_to = shape.kind == "connected" and family or nil,
			tiles = tiles,
			groups = groups,
			drop = row.trunk,
			is_ground_content = false,
			sounds = trunk.sounds,
			node_placement_prediction = "",
			on_place = refuse_place,
			_grug_trunk = row.trunk,
		})
	end
	local source = core.registered_nodes[row.leaves[#row.leaves]]
	assert(source, "grug_treeproto: no leaves " .. row.leaves[#row.leaves])
	local tinted = table.copy(source)
	tinted.name, tinted.type, tinted.mod_origin = nil, nil, nil
	tinted.paramtype2 = "color"
	tinted.palette = grug_treeproto.LEAF_PALETTE
	tinted.groups.not_in_creative_inventory = 1
	tinted._grug_leaves = row.leaves[#row.leaves]
	core.register_node(grug_treeproto.tinted_leaves_name(row.key), tinted)
	local leaves = table.copy(row.leaves)
	leaves[#leaves + 1] = grug_treeproto.tinted_leaves_name(row.key)
	-- Leaf decay keeps leaves that have any of the family within the radius;
	-- registering again replaces default's callbacks for these leaves and
	-- this trunk with the same function over the longer list.
	default.register_leafdecay({
		trunks = family,
		leaves = leaves,
		radius = row.decay_radius,
	})
end
