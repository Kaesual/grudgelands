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

-- Roles a generator must degrade gracefully without.
M.optional = {"bed_fancy", "crop", "fence_gate", "shutter"}

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
	shelf = "default:bookshelf",
	shelf_vessels = "vessels:shelf",
	storage = "default:chest",
	workbench = "default:steelblock",
	hearth = "default:furnace",
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

local function contains(list, value)
	for index = 1, #list do
		if list[index] == value then return true end
	end
	return false
end

-- Build a validated palette handle. `node(role)` is the only accessor a
-- generator may use; an unbound or misspelled role fails loudly at
-- construction time instead of producing an unregistered node name.
function M.new(race)
	local source = M.races[race]
	if type(source) ~= "table" then
		error("wp13 palette: unknown race " .. tostring(race), 0)
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
		local name = bound[role]
		if name == nil then
			error("wp13 palette: role " .. tostring(role) .. " is not bound", 0)
		end
		return name
	end
	function handle.maybe(role)
		if not contains(M.required, role) and not contains(M.optional, role) then
			error("wp13 palette: role " .. tostring(role) .. " is not declared", 0)
		end
		return bound[role]
	end
	return handle
end

return M
