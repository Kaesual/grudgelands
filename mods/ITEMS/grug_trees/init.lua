-- Race trees (WP18, docs/design/biomes_mobs.md §5).
--
-- Four of the six races reuse a minetest_game tree (oak/pine/acacia/jungle);
-- only the Elf and the Undead tree need own nodes:
--
--   * Silverwood (Elf)    -- pale silver bark, pale sage leaves; a tall,
--                            columnar tree of its own (Round 47 generator).
--   * Gravewood (Undead)  -- blackened, knotted dead branches with a few
--                            scattered grey leaf remnants.
--
-- Both woods are in `group:wood`, so every base recipe accepts them
-- (biomes_mobs.md §5/§6); the race woods only matter for looks and for the
-- settlement schematics.
--
-- All textures are cheap retints of vendored minetest_game textures
-- (CC BY-SA 3.0) -- see LICENSE-media.md for attribution and the exact
-- ImageMagick operations.
--
-- shapes.lua adds the tree shape nodes (trunk quarter, limb base, branch,
-- twig) of all seven wood types, the jungle bark and the leaf decay of every
-- wood (Round 47).
--
-- The world generator (WP40 R7) and every sapling grow all trees from the
-- seeded generator (Round 47: wp40/treegen.lua, wp40/tree_templates.lua).

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
-- Growth (Round 47 lane TC): every tree sapling grows the seeded generator's
-- tree of its species (growth.lua over the world generator's own
-- wp40/tree_templates.lua, the same trees the world places): a seed from
-- the world seed and the sapling's position, roots tested on the real
-- ground, free cells only, the terrain guard per cell. The bushes keep
-- default's schematics.
--

-- The generator is read at the first growth, not at load (grug_mapgen's
-- files are pure; this mod does not depend on that mod's load).
local tree_templates
local function trees()
	if not tree_templates then
		local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
		tree_templates = dofile(wp40 .. "/tree_templates.lua")(dofile(wp40 .. "/treegen.lua"))
	end
	return tree_templates
end

grug_trees.growth = dofile(core.get_modpath("grug_trees") .. "/growth.lua")({
	trees = trees,
	get_node = function(pos) return core.get_node(pos) end,
	set_node = function(pos, node) return core.set_node(pos, node) end,
	registered_nodes = core.registered_nodes,
	get_item_group = function(name, group) return core.get_item_group(name, group) end,
	alterable = function(pos) return grug_core.world_alterable(pos) end,
	-- The position hash: SHA-256 of the world seed string, the species and
	-- the sapling's position (tree_templates.seed_from_digest).
	seed = function(species, pos)
		return trees().seed_from_digest(core.sha256(table.concat({
			"grug_sapling_tree_v1", core.get_mapgen_setting("seed"), species,
			pos.x, pos.y, pos.z}, ":"), true))
	end,
})

for sapling, species in pairs(grug_trees.growth.SPECIES) do
	default.register_sapling_growth(sapling, {
		grow = function(pos)
			if not grug_trees.growth.grow(pos, sapling) then
				default.on_grow_failed(pos)
			end
		end,
	})
	-- Placing a sapling checks player protection over the volume its tree
	-- can grow into (the vendored sapling_on_place; the volume is the
	-- generator's, not the old schematic's).
	local volume = grug_trees.growth.VOLUMES[species]
	core.register_on_mods_loaded(function()
		core.override_item(sapling, {on_place = function(itemstack, placer, pointed_thing)
			return default.sapling_on_place(itemstack, placer, pointed_thing, sapling,
				{x = volume.min.x, y = 1, z = volume.min.z},
				{x = volume.max.x, y = volume.max.y, z = volume.max.z}, 4)
		end})
	end)
end

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

	-- on_place: the growth section above (the generated tree's volume).
})

--
-- Gravewood (Undead) -- mostly bare branches, sparse grey leaf remnants
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

core.register_node("grug_trees:gravewood_leaves", {
	description = "Gravewood Dead Leaves",
	drawtype = "allfaces_optional",
	-- Existing CC BY-SA leaf texture; the engine modifier tints the foliage toward grey.
	tiles = {"default_leaves.png^[colorize:#858585:210"},
	paramtype = "light",
	-- Same waving as silverwood leaves; the client setting decides whether
	-- it renders (allfaces_optional maps waving 1 to the leaves material).
	waving = 1,
	is_ground_content = false,
	groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
	drop = "",
	sounds = default.node_sound_leaves_defaults(),
	after_place_node = after_place_leaves,
})

-- The swamp tree (Round 47 lane SW, tools/r47_sw/DESIGN.md) grows from
-- gravewood's wood with its own olive leaves and hanging moss. Both decay
-- with gravewood's wood (the generator keeps them within 3 of it) and
-- drop nothing, as gravewood's leaves.
core.register_node("grug_trees:swamp_leaves", {
	description = "Swamp Leaves",
	drawtype = "allfaces_optional",
	-- Lane ART's olive leaves (CC0, LICENSE-media.md).
	tiles = {"grug_trees_swamp_leaves.png"},
	paramtype = "light",
	waving = 1,
	is_ground_content = false,
	groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
	drop = "",
	sounds = default.node_sound_leaves_defaults(),
	after_place_node = after_place_leaves,
})

-- Hanging moss trails 1-3 nodes below leaves and limbs. Not an attached
-- node: `attached_node = 4` needs a walkable node above, so the second
-- node of a strand would fall; it goes with the tree's leaf decay instead.
-- Round 51 (land plan ruling 4): a run is the continuous strand above the
-- tapered end (`swamp_hanging_moss`, the lowest node); hanging.lua keeps a
-- dug run whole (the end moves up).
local function hanging_moss(name, description, texture)
	core.register_node(name, {
		description = description,
		drawtype = "plantlike",
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		waving = 1,
		is_ground_content = false,
		selection_box = {type = "fixed", fixed = {-5 / 16, -0.5, -5 / 16, 5 / 16, 0.5, 5 / 16}},
		groups = {snappy = 3, leafdecay = 3, flammable = 2},
		drop = "",
		sounds = default.node_sound_leaves_defaults(),
		after_place_node = after_place_leaves,
	})
end
hanging_moss("grug_trees:swamp_hanging_moss", "Hanging Moss",
	"grug_trees_swamp_hanging_moss.png")
hanging_moss("grug_trees:swamp_hanging_moss_strand", "Hanging Moss Strand",
	"grug_trees_swamp_hanging_moss_strand.png")
-- Round 51 lane LP: the jungle's lianas, the same strand above an end under
-- jungle and kapok leaves (wp40/tree_templates.lua), decaying with jungle
-- wood (shapes.lua) and dropping nothing.
hanging_moss("grug_trees:liana", "Liana", "grug_trees_liana.png")
hanging_moss("grug_trees:liana_strand", "Liana Strand", "grug_trees_liana_strand.png")

-- The strand/end pairs (lane LP's lianas register theirs the same way).
grug_trees.hanging = dofile(core.get_modpath("grug_trees") .. "/hanging.lua")({
	get_node = function(pos) return core.get_node(pos) end,
	swap_node = function(pos, node) return core.swap_node(pos, node) end,
	remove_node = function(pos) return core.remove_node(pos) end,
	is_protected = function(pos, name) return core.is_protected(pos, name) end,
	override_item = function(name, fields) return core.override_item(name, fields) end,
})
grug_trees.hanging.register("grug_trees:swamp_hanging_moss_strand", "grug_trees:swamp_hanging_moss")
grug_trees.hanging.register("grug_trees:liana_strand", "grug_trees:liana")

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

	-- on_place: the growth section above (the generated tree's volume).
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

-- The tree shape nodes of every wood type, the leaf decay of all seven woods
-- (radius 3, the shapes included) and the leaf and ground connect sides.
dofile(core.get_modpath("grug_trees") .. "/shapes.lua")
