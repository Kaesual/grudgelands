-- Tree shape nodes (Round 47 lane TA): the wood pieces of the generated trees,
-- four per wood type, as approved in the Round 46 concept viewer
-- (docs/planning/tree-rework-handoff.md §3; the binding data is
-- tools/r46_tree/concept/shapes.js, which also writes the quarter mesh).
--
--   grug_trees:<wood>_quarter  a quarter of a 2 x 2 (or the corner of a 3 x 3)
--                              octagon trunk: mesh grug_tree_quarter_oct.obj,
--                              facedir 0..3, trunk axis at +x +z for 0;
--                              collision and selection: the full node
--   grug_trees:<wood>_base     limb base, connected box 12/16 thick whose level
--                              arms reach 8/16 into the neighbour cell
--   grug_trees:<wood>_branch   connected box 10/16 thick
--   grug_trees:<wood>_twig     connected box 6/16 thick; the only piece that
--                              joins leaves (only a leaf above it)
--
-- <wood> is one of WOODS below. The base and the twig also join the ground
-- below them (roots). The connected pieces take facedir 0 / 4 / 12 so the bark
-- runs along y / z / x: connected boxes never turn, facedir turns their tiles.
-- Every piece drops its trunk item, copies the trunk's groups and sounds, is a
-- trunk for its leaves' decay and refuses being placed by a player (nobody
-- holds one: they drop the trunk). Shapes are placed by the world generator
-- and saplings (lanes TB/TC), never by hand.

local S16 = 1 / 16

-- Wood type -> trunk node, every node that decays to it (`leaves`) and the
-- leaves a twig joins from below (`joins`; the first is the wood's own leaf,
-- published as shape_woods[wood].leaves). The apple fruit only shares the
-- decay. Kapok grows from jungle wood (its lianas decay with it, Round 51
-- lane LP); the swamp tree (Round 47 lane SW)
-- from gravewood, so its leaves and hanging moss decay to gravewood wood
-- and its leaves take the twig too. Every name must be registered before
-- this file runs (the end of init.lua).
local WOODS = {
	{key = "apple", trunk = "default:tree", leaves = {"default:leaves", "default:apple"},
		joins = {"default:leaves"}},
	{key = "jungle", trunk = "default:jungletree", leaves = {"default:jungleleaves",
		"grug_trees:liana", "grug_trees:liana_strand"},
		joins = {"default:jungleleaves"}},
	{key = "acacia", trunk = "default:acacia_tree", leaves = {"default:acacia_leaves"},
		joins = {"default:acacia_leaves"}},
	{key = "pine", trunk = "default:pine_tree", leaves = {"default:pine_needles"},
		joins = {"default:pine_needles"}},
	{key = "aspen", trunk = "default:aspen_tree", leaves = {"default:aspen_leaves"},
		joins = {"default:aspen_leaves"}},
	{key = "silverwood", trunk = "grug_trees:silverwood_tree",
		leaves = {"grug_trees:silverwood_leaves"}, joins = {"grug_trees:silverwood_leaves"}},
	{key = "gravewood", trunk = "grug_trees:gravewood_tree",
		leaves = {"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves",
			"grug_trees:swamp_hanging_moss", "grug_trees:swamp_hanging_moss_strand"},
		joins = {"grug_trees:gravewood_leaves", "grug_trees:swamp_leaves"}},
}
local SHAPES = {"quarter", "base", "branch", "twig"}

-- The ground a root joins through its bottom: soil (dirt, grass, the litters,
-- blight dirt, swamp mud), sand and gravel.
local GROUND = {"group:soil", "group:sand", "default:gravel"}

-- Jungle bark M (Round 46 pick, CC0, LICENSE-media.md): own texture names
-- set on the jungle tree, so the vendored PNGs stay as they are.
core.override_item("default:jungletree", {tiles = {
	"grug_trees_jungle_bark_top.png", "grug_trees_jungle_bark_top.png",
	"grug_trees_jungle_bark.png"}})

-- shapes.js connected(h, reach): a core of half-width h, level arms to
-- `reach` (8 = the node border, 16 = 8/16 into the neighbour), the top and
-- bottom arms to the border. Sixteenths, centred on the node.
local function connected(h, reach)
	local function box(x1, y1, z1, x2, y2, z2)
		return {x1 * S16, y1 * S16, z1 * S16, x2 * S16, y2 * S16, z2 * S16}
	end
	return {
		type = "connected",
		fixed = box(-h, -h, -h, h, h, h),
		connect_top = box(-h, h, -h, h, 8, h),
		connect_bottom = box(-h, -8, -h, h, -h, h),
		connect_front = box(-h, -h, -reach, h, h, -h),
		connect_back = box(-h, -h, h, h, h, reach),
		connect_left = box(-reach, -h, -h, -h, h, h),
		connect_right = box(h, -h, -h, reach, h, h),
	}
end
local BOXES = {base = connected(6, 16), branch = connected(5, 8), twig = connected(3, 8)}

local function refuse_place(itemstack)
	return itemstack
end

-- Published for the generator lanes: names[wood][shape], plus each wood's
-- trunk and leaves.
grug_trees.shape_nodes = {}
grug_trees.shape_woods = {}

for _, wood in ipairs(WOODS) do
	-- One decay registration per trunk: default.register_leafdecay replaces
	-- the trunk's after_destruct, so every leaf of the trunk is in this list.
	for _, name in ipairs(wood.leaves) do
		assert(core.registered_nodes[name], "grug_trees: " .. name ..
			" must be registered before shapes.lua (" .. wood.key .. " leaves)")
	end
	local trunk = assert(core.registered_nodes[wood.trunk],
		"grug_trees: missing trunk " .. wood.trunk)
	local names = {}
	for _, shape in ipairs(SHAPES) do
		names[shape] = "grug_trees:" .. wood.key .. "_" .. shape
	end
	local wood_pieces = {wood.trunk, names.quarter, names.base, names.branch, names.twig}
	local connects = {
		base = table.copy(wood_pieces),
		branch = table.copy(wood_pieces),
		twig = table.copy(wood_pieces),
	}
	for _, leaf in ipairs(wood.joins) do connects.twig[#connects.twig + 1] = leaf end
	for _, ground in ipairs(GROUND) do
		connects.base[#connects.base + 1] = ground
		connects.twig[#connects.twig + 1] = ground
	end
	local top, bark = trunk.tiles[1], trunk.tiles[#trunk.tiles]
	local groups = table.copy(trunk.groups)
	groups.not_in_creative_inventory = 1

	for _, shape in ipairs(SHAPES) do
		local def = {
			description = trunk.description,
			paramtype = "light",
			paramtype2 = "facedir",
			is_ground_content = trunk.is_ground_content,
			groups = table.copy(groups),
			sounds = table.copy(trunk.sounds),
			drop = wood.trunk,
			node_placement_prediction = "",
			on_place = refuse_place,
		}
		if shape == "quarter" then
			-- Material groups of the mesh: the end grain (both caps and the
			-- two faces towards the trunk axis, so a partly felled trunk shows
			-- cut wood), then the bark. Mesh tiles default to no backface
			-- culling; the concept draws front faces only (shapes.js winds
			-- every face outwards).
			def.drawtype = "mesh"
			def.mesh = "grug_tree_quarter_oct.obj"
			def.tiles = {{name = top, backface_culling = true},
				{name = bark, backface_culling = true}}
			def.selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
			def.collision_box = def.selection_box
		else
			-- Bark on every face, as in the viewer; facedir sets the grain.
			def.drawtype = "nodebox"
			def.node_box = BOXES[shape]
			def.tiles = {bark}
			def.connects_to = connects[shape]
			def.sunlight_propagates = true
		end
		core.register_node(names[shape], def)
	end

	grug_trees.shape_nodes[wood.key] = names
	grug_trees.shape_woods[wood.key] = {trunk = wood.trunk, leaves = wood.leaves[1]}

	-- Leaves keep a trunk piece within 3 (the generator keeps every leaf that
	-- close to wood); this replaces default's and grug_trees' own decay
	-- registration of these leaves (jungle and acacia had radius 2).
	default.register_leafdecay({trunks = wood_pieces, leaves = wood.leaves, radius = 3})

	-- A twig joins its leaf only through the leaf's bottom: only a leaf above.
	for _, leaf in ipairs(wood.joins) do
		core.override_item(leaf, {connect_sides = {"bottom"}})
	end
end

-- The ground joins a root only through its top. Every mod's ground is
-- registered by now; the mapgen environment receives these definitions after
-- this callback (builtin/emerge/register.lua copies them at its start).
core.register_on_mods_loaded(function()
	local names = {}
	for name, def in pairs(core.registered_nodes) do
		local groups = def.groups or {}
		if (groups.soil or 0) > 0 or (groups.sand or 0) > 0 or name == "default:gravel" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		core.override_item(name, {connect_sides = {"top"}})
	end
	core.log("action", "grug_trees: ground connect_sides top on " .. #names ..
		" nodes: " .. table.concat(names, " "))
end)
