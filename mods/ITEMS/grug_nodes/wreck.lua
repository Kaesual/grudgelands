-- Shipwreck nodes (Round 51 lane WRECK, sea plan §5a, tools/r51_wreck/DESIGN.md).
--
-- Wrecks are decoration on the protected seabed (grug_mapgen's
-- wp40/wreck_writer.lua places them). They are built from full blocks only,
-- so water draws no wall around them: the waterlogged planks, their algae
-- form and the waterlogged log. Masts and small details are rooted plants
-- (`plantlike_rooted`, the kelp mechanism): a plank base cube with a
-- plantlike extension in the water above it, drawn without an air pocket.
-- The mast is leveled (its height is param2 / 16 nodes); the rope, the sail
-- tatters and the algae tuft are one node high. Every node drops ordinary
-- wood (the planks and the rooted ones) or an ordinary log (round plan
-- §4.1); none is in the creative inventory, and none carries the `wood` or
-- `tree` group, so no recipe takes a wreck node.

-- The ordinary wood's and log's digging (an axe, by hand slowly), without
-- the groups recipes and leaf decay read.
local function groups_of(name)
	local groups = table.copy(core.registered_nodes[name].groups)
	groups.wood, groups.tree, groups.flammable = nil, nil, nil
	groups.not_in_creative_inventory = 1
	return groups
end
local wood_groups, log_groups = groups_of("default:wood"), groups_of("default:tree")
local wood_sounds = default.node_sound_wood_defaults()

core.register_node("grug_nodes:wreck_planks", {
	description = "Waterlogged Planks",
	tiles = {"grug_nodes_wreck_planks.png"},
	is_ground_content = false,
	groups = wood_groups,
	drop = "default:wood",
	sounds = wood_sounds,
})

core.register_node("grug_nodes:wreck_planks_algae", {
	description = "Waterlogged Planks with Algae",
	tiles = {"grug_nodes_wreck_planks_algae.png"},
	is_ground_content = false,
	groups = wood_groups,
	drop = "default:wood",
	sounds = wood_sounds,
})

-- Keel, stem, ribs and fallen masts: facedir like a log (param2 0 upright,
-- 4 along z, 12 along x).
core.register_node("grug_nodes:wreck_log", {
	description = "Waterlogged Log",
	tiles = {"grug_nodes_wreck_log_top.png", "grug_nodes_wreck_log_top.png",
		"grug_nodes_wreck_log.png"},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = log_groups,
	drop = "default:tree",
	sounds = wood_sounds,
	on_place = core.rotate_node,
})

-- A rooted wreck detail: the plank base (or its algae form) with `special`
-- above it. `leveled`: the mast, param2 / 16 nodes high (the wreck shapes
-- break it 2.5 to 6 nodes above the deck); without it one node.
local function rooted(name, description, base, special, leveled)
	core.register_node("grug_nodes:" .. name, {
		description = description,
		drawtype = "plantlike_rooted",
		-- a tall mast stays still; the small details sway like kelp
		waving = leveled and 0 or 1,
		tiles = {base},
		special_tiles = {{name = special, tileable_vertical = true}},
		inventory_image = special,
		wield_image = special,
		paramtype = "light",
		paramtype2 = leveled and "leveled" or nil,
		is_ground_content = false,
		groups = wood_groups,
		selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
		node_dig_prediction = "air",
		drop = "default:wood",
		sounds = wood_sounds,
	})
end
rooted("wreck_mast", "Waterlogged Planks with a Broken Mast", "grug_nodes_wreck_planks.png",
	"grug_nodes_wreck_mast.png", true)
rooted("wreck_rope", "Waterlogged Planks with a Rope", "grug_nodes_wreck_planks.png",
	"grug_nodes_wreck_rope.png")
rooted("wreck_sail", "Waterlogged Planks with Sail Tatters", "grug_nodes_wreck_planks.png",
	"grug_nodes_wreck_sail.png")
rooted("wreck_algae", "Waterlogged Planks with an Algae Tuft", "grug_nodes_wreck_planks_algae.png",
	"grug_nodes_wreck_algae.png")
