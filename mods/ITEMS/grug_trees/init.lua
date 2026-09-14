-- Race trees (WP18, docs/design/biomes_mobs.md §5).
--
-- Four of the six races reuse a minetest_game tree (oak/pine/acacia/jungle);
-- only the Elf and the Undead tree need own nodes:
--
--   * Silverwood (Elf)    -- pale silver bark, pale sage leaves. Shape is
--                            default's aspen, so it can reuse default's
--                            aspen schematic with node `replacements`.
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
-- R7 P9 resolves Silverwood through default's aspen plus replacements and
-- Gravewood through this mod's original .mts assets in the single mapgen
-- transaction. The great_silverwood.mts treehouse remains WP13.

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

-- Node replacements for the aspen schematics. R7 P9's silverwood template
-- resolver needs the same table, so it lives on the mod table.
grug_trees.silverwood_replacements = {
	["default:aspen_tree"] = "grug_trees:silverwood_tree",
	["default:aspen_leaves"] = "grug_trees:silverwood_leaves",
}

-- Silverwood grows default's aspen schematic with the aspen nodes swapped
-- for ours -- exactly what R7 P9 template placement does as well.
--
-- LANDMINE (first found in the retired engine-decoration path): Luanti caches
-- file-loaded schematics BY FULL PATH, so place_schematic(pos, "<path>",
-- rot, replacements) only applies those replacements on the FIRST load of
-- that path; every later call reuses the cached object and its replacements.
-- default.grow_new_aspen_tree() places this very same
-- aspen_tree_from_sapling.mts with NO replacements, so whichever sapling
-- happened to grow first in a session would decide for both -- silver aspens
-- or green silverwoods, at random per server run.
--
-- Reading the file into a table and registering it once gives us a private
-- schematic handle with the replacements baked in: no path in the cache, no
-- collision with default, and no per-growth re-load either.
local SILVERWOOD_SCHEMATIC = core.register_schematic(
	core.read_schematic(core.get_modpath("default") ..
		"/schematics/aspen_tree_from_sapling.mts", {}),
	grug_trees.silverwood_replacements)

if not SILVERWOOD_SCHEMATIC then
	error("grug_trees: cannot register the silverwood schematic")
end

function grug_trees.grow_silverwood(pos)
	core.place_schematic({x = pos.x - 2, y = pos.y - 1, z = pos.z - 2},
		SILVERWOOD_SCHEMATIC, "0", nil, false)
end

local gravewood_schematics = {}
for _, filename in ipairs({"grug_gravewood_small.mts", "grug_gravewood_tall.mts"}) do
	local schematic = core.read_schematic(core.get_modpath("grug_trees") ..
		"/schematics/" .. filename, {})
	local handle = schematic and core.register_schematic(schematic)
	if not handle then error("grug_trees: cannot register " .. filename) end
	gravewood_schematics[#gravewood_schematics + 1] = {handle = handle,
		height = schematic.size.y}
end

-- Saplings and mapgen consume the same face-connected, bent dead-tree assets.
function grug_trees.grow_gravewood(pos)
	local schematic = gravewood_schematics[math.random(#gravewood_schematics)]
	-- Check the complete rotation-invariant volume before removing the sapling:
	-- partially obstructed placement must not leave disconnected branch tips.
	for z = pos.z - 3, pos.z + 3 do
		for y = pos.y, pos.y + schematic.height - 1 do
			for x = pos.x - 3, pos.x + 3 do
				if x ~= pos.x or y ~= pos.y or z ~= pos.z then
					local node = core.get_node({x = x, y = y, z = z})
					local def = core.registered_nodes[node.name]
					if node.name == "ignore" or not def or not def.buildable_to then
						default.on_grow_failed(pos)
						return
					end
				end
			end
		end
	end
	core.remove_node(pos)
	core.place_schematic({x = pos.x - 3, y = pos.y, z = pos.z - 3},
		schematic.handle, tostring(math.random(0, 3) * 90), nil, false)
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

default.register_leafdecay({
	trunks = {"grug_trees:gravewood_tree"},
	leaves = {"grug_trees:gravewood_leaves"},
	radius = 3,
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
		-- Both grown silhouettes fit this shared rotation-invariant envelope.
		itemstack = default.sapling_on_place(itemstack, placer, pointed_thing,
			"grug_trees:gravewood_sapling",
			{x = -3, y = 0, z = -3},
			{x = 3, y = 8, z = 3},
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
