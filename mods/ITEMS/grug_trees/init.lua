-- Race trees (WP18, docs/design/biomes_mobs.md §5).
--
-- Four of the six races reuse a minetest_game tree (oak/pine/acacia/jungle);
-- only the Elf and the Undead tree need own nodes:
--
--   * Silverwood (Elf)    -- pale silver bark, pale sage leaves. Shape is
--                            default's aspen, so it can reuse default's
--                            aspen schematic with node `replacements`.
--   * Gravewood (Undead)  -- blackened, BARE dead trunk (no leaves at all,
--                            that bareness is the identity).
--
-- Both woods are in `group:wood`, so every base recipe accepts them
-- (biomes_mobs.md §5/§6); the race woods only matter for looks and for the
-- settlement schematics.
--
-- All textures are cheap retints of vendored minetest_game textures
-- (CC BY-SA 3.0) -- see LICENSE-media.md for attribution and the exact
-- ImageMagick operations.
--
-- WP18 registers the nodes only. The mapgen DECORATIONS keep using
-- default's .mts files and substitute our nodes via `replacements` at
-- placement time (grug_mapgen, T4); the hand-built great_silverwood.mts
-- treehouse schematic is WP13.

grug_trees = {}

-- Wrappers mirroring default/nodes.lua, so a later override of the default
-- helpers is still picked up.
local function after_place_leaves(...)
	return default.after_place_leaves(...)
end

local function grow_sapling(...)
	return default.grow_sapling(...)
end

--
-- Growth
--

-- Node replacements for the aspen schematics. grug_mapgen's silverwood
-- decoration needs the same table, so it lives on the mod table.
grug_trees.silverwood_replacements = {
	["default:aspen_tree"] = "grug_trees:silverwood_tree",
	["default:aspen_leaves"] = "grug_trees:silverwood_leaves",
}

local SILVERWOOD_SCHEMATIC = core.get_modpath("default") ..
	"/schematics/aspen_tree_from_sapling.mts"

-- Silverwood grows default's aspen schematic with the aspen nodes swapped
-- for ours -- exactly what the decorations will do as well.
function grug_trees.grow_silverwood(pos)
	core.place_schematic({x = pos.x - 2, y = pos.y - 1, z = pos.z - 2},
		SILVERWOOD_SCHEMATIC, "0", grug_trees.silverwood_replacements, false)
end

local GRAVEWOOD_TRUNK = "grug_trees:gravewood_tree"

-- Branch offsets, hoisted: the grower picks one or two of these per tree.
local GRAVEWOOD_BRANCH_DIRS = {
	{x = 1, z = 0}, {x = -1, z = 0}, {x = 0, z = 1}, {x = 0, z = -1},
}

local function is_free(pos)
	local node = core.get_node(pos)
	if node.name == "ignore" then
		return false
	end
	local def = core.registered_nodes[node.name]
	return def ~= nil and def.buildable_to == true
end

-- Gravewood is too small and too irregular to be worth a schematic: a bare
-- trunk of 3-5 nodes plus one or two stubby branches, built in Lua.
function grug_trees.grow_gravewood(pos)
	local height = math.random(3, 5)
	-- The sapling node itself becomes the base of the trunk.
	core.set_node(pos, {name = GRAVEWOOD_TRUNK})
	local top = pos.y
	local i = 1
	while i < height do
		local p = {x = pos.x, y = pos.y + i, z = pos.z}
		if not is_free(p) then
			break
		end
		core.set_node(p, {name = GRAVEWOOD_TRUNK})
		top = p.y
		i = i + 1
	end

	for _ = 1, math.random(1, 2) do
		local d = GRAVEWOOD_BRANCH_DIRS[math.random(#GRAVEWOOD_BRANCH_DIRS)]
		local p = {
			x = pos.x + d.x,
			y = top - math.random(0, 1),
			z = pos.z + d.z,
		}
		if p.y > pos.y and is_free(p) then
			core.set_node(p, {name = GRAVEWOOD_TRUNK})
		end
	end
end

default.register_sapling_growth("grug_trees:silverwood_sapling", {
	grow = grug_trees.grow_silverwood,
})
default.register_sapling_growth("grug_trees:gravewood_sapling", {
	grow = grug_trees.grow_gravewood,
})

--
-- Silverwood (Elf)
--

core.register_node("grug_trees:silverwood_tree", {
	description = "Silverwood Tree",
	tiles = {"grug_trees_silverwood_tree_top.png",
		"grug_trees_silverwood_tree_top.png",
		"grug_trees_silverwood_tree.png"},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {tree = 1, choppy = 3, oddly_breakable_by_hand = 1, flammable = 3},
	sounds = default.node_sound_wood_defaults(),

	on_place = core.rotate_node,
})

core.register_node("grug_trees:silverwood_wood", {
	description = "Silverwood Planks",
	paramtype2 = "facedir",
	place_param2 = 0,
	tiles = {"grug_trees_silverwood_wood.png"},
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
	sounds = default.node_sound_wood_defaults(),
})

core.register_node("grug_trees:silverwood_leaves", {
	description = "Silverwood Tree Leaves",
	drawtype = "allfaces_optional",
	tiles = {"grug_trees_silverwood_leaves.png"},
	waving = 1,
	paramtype = "light",
	is_ground_content = false,
	groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
	drop = {
		max_items = 1,
		items = {
			{items = {"grug_trees:silverwood_sapling"}, rarity = 20},
			{items = {"grug_trees:silverwood_leaves"}}
		}
	},
	sounds = default.node_sound_leaves_defaults(),

	after_place_node = after_place_leaves,
})

core.register_node("grug_trees:silverwood_sapling", {
	description = "Silverwood Tree Sapling",
	drawtype = "plantlike",
	tiles = {"grug_trees_silverwood_sapling.png"},
	inventory_image = "grug_trees_silverwood_sapling.png",
	wield_image = "grug_trees_silverwood_sapling.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	on_timer = grow_sapling,
	selection_box = {
		type = "fixed",
		fixed = {-3 / 16, -0.5, -3 / 16, 3 / 16, 0.5, 3 / 16}
	},
	groups = {snappy = 2, dig_immediate = 3, flammable = 3,
		attached_node = 1, sapling = 1},
	sounds = default.node_sound_leaves_defaults(),

	on_construct = function(pos)
		core.get_node_timer(pos):start(math.random(300, 1500))
	end,

	on_place = function(itemstack, placer, pointed_thing)
		-- Same grown volume as default's aspen: the schematic is aspen's.
		itemstack = default.sapling_on_place(itemstack, placer, pointed_thing,
			"grug_trees:silverwood_sapling",
			-- minp, maxp to be checked, relative to sapling pos
			-- minp_relative.y = 1 because sapling pos has been checked
			{x = -2, y = 1, z = -2},
			{x = 2, y = 12, z = 2},
			-- maximum interval of interior volume check
			4)

		return itemstack
	end,
})

-- Aspen's leafdecay radius, because it is aspen's schematic.
default.register_leafdecay({
	trunks = {"grug_trees:silverwood_tree"},
	leaves = {"grug_trees:silverwood_leaves"},
	radius = 3,
})

--
-- Gravewood (Undead) -- no leaves on purpose
--

core.register_node("grug_trees:gravewood_tree", {
	description = "Gravewood Tree",
	tiles = {"grug_trees_gravewood_tree_top.png",
		"grug_trees_gravewood_tree_top.png",
		"grug_trees_gravewood_tree.png"},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
	sounds = default.node_sound_wood_defaults(),

	on_place = core.rotate_node,
})

core.register_node("grug_trees:gravewood_wood", {
	description = "Gravewood Planks",
	paramtype2 = "facedir",
	place_param2 = 0,
	tiles = {"grug_trees_gravewood_wood.png"},
	is_ground_content = false,
	groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
	sounds = default.node_sound_wood_defaults(),
})

core.register_node("grug_trees:gravewood_sapling", {
	description = "Gravewood Tree Sapling",
	drawtype = "plantlike",
	tiles = {"grug_trees_gravewood_sapling.png"},
	inventory_image = "grug_trees_gravewood_sapling.png",
	wield_image = "grug_trees_gravewood_sapling.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	on_timer = grow_sapling,
	selection_box = {
		type = "fixed",
		fixed = {-3 / 16, -0.5, -3 / 16, 3 / 16, 0.5, 3 / 16}
	},
	groups = {snappy = 2, dig_immediate = 3, flammable = 3,
		attached_node = 1, sapling = 1},
	sounds = default.node_sound_leaves_defaults(),

	on_construct = function(pos)
		core.get_node_timer(pos):start(math.random(300, 1500))
	end,

	on_place = function(itemstack, placer, pointed_thing)
		-- Max 5 trunk nodes plus branches one node to the side.
		itemstack = default.sapling_on_place(itemstack, placer, pointed_thing,
			"grug_trees:gravewood_sapling",
			{x = -1, y = 1, z = -1},
			{x = 1, y = 6, z = 1},
			2)

		return itemstack
	end,
})

--
-- Crafts
--

core.register_craft({
	output = "grug_trees:silverwood_wood 4",
	recipe = {{"grug_trees:silverwood_tree"}}
})

core.register_craft({
	output = "grug_trees:gravewood_wood 4",
	recipe = {{"grug_trees:gravewood_tree"}}
})

-- Planks are covered by default's `group:wood` fuel recipe; the logs are
-- not, so they need own entries (values as for aspen / apple logs).
core.register_craft({
	type = "fuel",
	recipe = "grug_trees:silverwood_tree",
	burntime = 22,
})

core.register_craft({
	type = "fuel",
	recipe = "grug_trees:gravewood_tree",
	burntime = 30,
})
