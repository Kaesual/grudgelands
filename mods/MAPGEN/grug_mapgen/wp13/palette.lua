-- WP13 settlement palette: role to node name, one table per race.
--
-- Every generator in this library addresses nodes only through roles, so one
-- generator can serve six races (docs/research/wp13-settlement-pipeline.md
-- section 4). Plain Lua 5.1, no engine calls, no globals.

local M = {}

-- Roles a generator may rely on unconditionally.
M.required = {
	"beam", "bed", "ceiling", "chimney", "chimney_cap", "door", "door_hidden",
	"fence", "fence_rail", "fern", "floor", "foundation", "grass_tuft",
	"ground", "ground_bare", "ground_patch", "hearth", "light_indoor",
	"light_post", "light_wall", "low_wall", "path", "planter", "planter_soil",
	"plaza", "plaza_edge", "post", "railing", "roof_ridge", "roof_slab",
	"roof_stair", "roof_stair_inner", "roof_stair_outer", "rubble", "rug",
	"rug_accent", "seat", "shelf", "shelf_vessels", "storage", "subsoil",
	"table_leg", "table_top", "tree_leaves", "tree_log", "undergrowth",
	"wall", "wall_accent", "window", "window_frame", "workbench",
}

-- Roles a generator must degrade gracefully without. Everything a race can
-- do without lives here, so a palette that has no half timbering, no straw
-- and no flower pots still builds; `palette.maybe(role)` answers nil and the
-- part that wanted it writes nothing.
M.optional = {"bale", "bed_fancy", "bench_seat", "board_table", "crop",
	"fence_gate", "flower", "flower_alt", "ground_straw", "hedge",
	"hedge_stem", "mat", "shutter", "stepping", "wall_infill", "wheel"}

-- Three roles do not name a node at all: they name the BASE of a family the
-- engine registers under several suffixes, and only the part that knows the
-- family may put one together. The suffix set lives here so that a typo in a
-- part fails at construction time instead of writing an unregistered name.
M.prefix_roles = {
	door = {"_a", "_b"},
	bed = {"_bottom", "_top"},
	bed_fancy = {"_bottom", "_top"},
}

-- Roles that must be bound to a node with no metadata behaviour at all.
-- WP13 writes its cells through VoxelManip, and `on_construct` is never run
-- for bulk placement (lua_api.md), so a chest, a furnace, a bookshelf or a
-- vessel shelf written this way has no inventory and no formspec: it is a
-- dead prop that a player can open into nothing. Every furnishing role is
-- therefore bound to a static decor node. `tools/wp13/library_kat.lua`
-- proves this for EVERY palette name against the real registrations, so
-- no role list is kept here.

M.races = {}

-- Dwarf (Hearthpine Vale): stone footings, pine timber, warm torchlight.
M.races.dwarf = {
	ground = "default:dirt_with_coniferous_litter",
	ground_patch = "default:dirt_with_grass",
	ground_bare = "default:dirt",
	subsoil = "default:dirt",
	path = "default:cobble",
	plaza = "default:stone_block",
	plaza_edge = "default:stonebrick",
	rubble = "default:gravel",

	foundation = "default:stone_block",
	wall = "default:pine_wood",
	wall_accent = "default:stonebrick",
	post = "default:pine_tree",
	beam = "default:pine_tree",
	floor = "default:pine_wood",
	ceiling = "default:pine_wood",

	roof_stair = "stairs:stair_pine_wood",
	roof_stair_outer = "stairs:stair_outer_pine_wood",
	roof_stair_inner = "stairs:stair_inner_pine_wood",
	roof_slab = "stairs:slab_pine_wood",
	roof_ridge = "default:pine_wood",

	window = "xpanes:pane_flat",
	window_frame = "default:pine_tree",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_pine_wood",
	fence_rail = "default:fence_rail_pine_wood",
	low_wall = "walls:cobble",
	railing = "default:fence_pine_wood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_pine_wood",
	table_leg = "default:fence_pine_wood",
	seat = "stairs:stair_pine_wood",
	-- Furnishing: static decor only. A `default:chest`, `default:bookshelf`,
	-- `vessels:shelf` or `default:furnace` placed by VoxelManip never gets
	-- its `on_construct`, so it carries no inventory and no formspec; the
	-- barrel, the plain shelf, the crock shelf and the cauldron are pure
	-- geometry and look the part without pretending to a service the
	-- settlement design explicitly does not offer.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_materials:iron_block",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:stonebrick",
	chimney_cap = "stairs:slab_stonebrick",
	rug = "wool:brown",
	rug_accent = "wool:red",

	planter = "default:stonebrick",
	planter_soil = "default:dirt_with_grass",
	tree_log = "default:pine_tree",
	tree_leaves = "default:pine_needles",
	undergrowth = "default:fern_1",
	grass_tuft = "default:grass_1",
	fern = "default:fern_2",
}

-- Human (Dawnmere Fields): cobble footings, plank and half-timbered walls,
-- brick accents and chimneys, oak framing, and the straw, barrels, bales and
-- flower pots of a working farm. Contract section 4's human column, plus the
-- kit nodes that fit it; the roof stays the `stairs:` family because the
-- cottages roof nodes ship no corner shapes (see the increment-3 evidence).
M.races.human = {
	ground = "default:dirt_with_grass",
	ground_patch = "default:dirt",
	ground_bare = "default:gravel",
	ground_straw = "grug_decor:cottages_straw_ground",
	subsoil = "default:dirt",
	path = "default:cobble",
	plaza = "default:cobble",
	plaza_edge = "default:brick",
	stepping = "grug_decor:xdecor_stonepath",
	rubble = "default:gravel",

	foundation = "default:cobble",
	wall = "default:wood",
	wall_infill = "grug_decor:cottages_loam",
	wall_accent = "default:brick",
	post = "default:tree",
	beam = "default:tree",
	floor = "default:wood",
	ceiling = "default:wood",

	roof_stair = "stairs:stair_wood",
	roof_stair_outer = "stairs:stair_outer_wood",
	roof_stair_inner = "stairs:stair_inner_wood",
	roof_slab = "stairs:slab_wood",
	roof_ridge = "default:wood",

	window = "xpanes:pane_flat",
	window_frame = "default:tree",
	shutter = "grug_decor:cottages_window_shutter_closed",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_wood",
	fence_rail = "default:fence_rail_wood",
	fence_gate = "doors:gate_wood_closed",
	low_wall = "walls:cobble",
	railing = "default:fence_wood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_wood",
	table_leg = "default:fence_wood",
	seat = "stairs:stair_wood",
	bench_seat = "grug_decor:cottages_bench",
	board_table = "grug_decor:cottages_table",
	mat = "grug_decor:cottages_straw_mat",
	bale = "grug_decor:cottages_straw_bale",
	wheel = "grug_decor:cottages_wagon_wheel",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The anvil is the human workbench; it is geometry, not a
	-- crafting service.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:cottages_anvil",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:brick",
	chimney_cap = "stairs:slab_brick",
	rug = "wool:white",
	rug_accent = "wool:red",

	planter = "default:brick",
	planter_soil = "default:dirt_with_grass",
	flower = "grug_decor:xdecor_potted_geranium",
	flower_alt = "grug_decor:xdecor_potted_dandelion_yellow",
	crop = "default:junglegrass",
	tree_log = "default:tree",
	tree_leaves = "default:leaves",
	hedge = "default:bush_leaves",
	hedge_stem = "default:bush_stem",
	undergrowth = "default:grass_4",
	grass_tuft = "default:grass_3",
	fern = "default:fern_1",
}

local function contains(list, value)
	for index = 1, #list do
		if list[index] == value then return true end
	end
	return false
end

-- Build a validated palette handle.
--
-- `node(role)` returns the node name a role is bound to, and refuses an
-- unbound or misspelled role. It does NOT prove the result is registered:
-- the palette is a plain table of strings, and only the engine knows what
-- exists. What proves that is `tools/wp13/library_kat.lua`, which loads the
-- real registrations under a stub `core` and checks every name the blueprint
-- emits, and the engine run itself, where R7's content manifest hard-fails
-- on an unregistered Hearthpine palette name.
--
-- Three roles -- `door`, `bed` and `bed_fancy` -- are not node names but
-- family bases, and `node` refuses them outright. Their members come from
-- `variant(role, suffix)`, whose suffix must be one the family declares, so
-- `parts.door` and `parts.bed` are the only way to emit them and a typo
-- cannot reach the cell list. `names(role)` is the whole family, for callers
-- that need to recognise the emitted names again.
--
-- `overrides` rebinds individual roles on top of the race, so a composition
-- can give one building a roof of another material without a second race or
-- a second generator. An override still has to name a declared role.
function M.new(race, overrides)
	local base = M.races[race]
	if type(base) ~= "table" then
		error("wp13 palette: unknown race " .. tostring(race), 0)
	end
	local source = base
	if overrides ~= nil then
		if type(overrides) ~= "table" then
			error("wp13 palette: overrides is not a table", 0)
		end
		source = {}
		for role, name in pairs(base) do source[role] = name end
		for role, name in pairs(overrides) do
			if not contains(M.required, role) and
					not contains(M.optional, role) then
				error("wp13 palette: override role " .. tostring(role) ..
					" is not declared", 0)
			end
			source[role] = name
		end
	end
	local bound = {}
	for _, role in ipairs(M.required) do
		local name = source[role]
		if type(name) ~= "string" or name == "" then
			error("wp13 palette: role " .. role .. " is unbound for " .. race, 0)
		end
		bound[role] = name
	end
	for _, role in ipairs(M.optional) do
		local name = source[role]
		if name ~= nil and (type(name) ~= "string" or name == "") then
			error("wp13 palette: optional role " .. role .. " is not a name", 0)
		end
		bound[role] = name
	end
	for role in pairs(source) do
		if not contains(M.required, role) and not contains(M.optional, role) then
			error("wp13 palette: role " .. tostring(role) .. " is not declared", 0)
		end
	end
	local handle = {race = race}
	function handle.node(role)
		if M.prefix_roles[role] then
			error("wp13 palette: role " .. role ..
				" is a family base; use variant()", 0)
		end
		local name = bound[role]
		if name == nil then
			error("wp13 palette: role " .. tostring(role) .. " is not bound", 0)
		end
		return name
	end
	function handle.maybe(role)
		if M.prefix_roles[role] then
			error("wp13 palette: role " .. role ..
				" is a family base; use variant()", 0)
		end
		if not contains(M.required, role) and not contains(M.optional, role) then
			error("wp13 palette: role " .. tostring(role) .. " is not declared", 0)
		end
		return bound[role]
	end
	-- One member of a family role. Returns nil when an optional family is
	-- unbound, so a generator can degrade; an undeclared suffix is an error.
	function handle.variant(role, suffix)
		local suffixes = M.prefix_roles[role]
		if not suffixes then
			error("wp13 palette: role " .. tostring(role) ..
				" is not a family base", 0)
		end
		if not contains(suffixes, suffix) then
			error("wp13 palette: " .. role .. " has no variant " ..
				tostring(suffix), 0)
		end
		local base = bound[role]
		if base == nil then return nil end
		return base .. suffix
	end
	-- Every node name a family role can emit, in declaration order.
	function handle.names(role)
		local suffixes = M.prefix_roles[role]
		if not suffixes then
			error("wp13 palette: role " .. tostring(role) ..
				" is not a family base", 0)
		end
		local base = bound[role]
		if base == nil then return {} end
		local out = {}
		for index = 1, #suffixes do out[index] = base .. suffixes[index] end
		return out
	end
	return handle
end

return M
