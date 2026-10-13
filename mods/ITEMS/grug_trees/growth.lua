-- Sapling growth through the tree generator (Round 47 lane TC, the
-- coordinator's choice "saplings grow through the generator"; handoff §5).
--
-- A sapling grows the generator's tree of its species (wp40/treegen.lua by
-- way of wp40/tree_templates.lua, the same trees the world generator
-- places), with a seed hashed from the world seed and the sapling's
-- position, so a sapling always grows the same tree. Its roots test the
-- real ground (`is_ground` reads the nodes): nothing where the ground falls
-- away or rises.
--
-- Like the vendored growth (default/trees.lua place_schematic without
-- force), a tree only takes free cells: air or a plant a node may replace
-- (buildable_to). Like every system change of the world it asks the
-- terrain guard (grug_core.world_alterable) for every cell. A trunk, limb or
-- root cell that is not free or not alterable fails the growth (the sapling
-- tries again later, default.on_grow_failed); a leaf there is left out.
-- Player protection is checked when the sapling is placed, over the volume
-- the species can grow into (VOLUMES, init.lua). Apples keep param2 0, the
-- generator's natural apple, so they regrow (default:apple after_dig_node).
--
-- Pure: every engine access comes through `api`, so the fixture runs it:
--   api.get_node(pos) -> {name, param2}, api.set_node(pos, node),
--   api.registered_nodes, api.get_item_group(name, group),
--   api.alterable(pos) -> bool, api.seed(species, pos) -> integer,
--   api.trees() -> the tree_templates module (read at the first growth)
return function(api)
	local M = {}

	-- Saplings and the species they grow.
	M.SPECIES = {
		["default:sapling"] = "apple",
		["default:junglesapling"] = "jungle",
		["default:emergent_jungle_sapling"] = "kapok",
		["default:acacia_sapling"] = "acacia",
		["default:pine_sapling"] = "pine",
		["default:aspen_sapling"] = "aspen",
		["grug_trees:silverwood_sapling"] = "silverwood",
		["grug_trees:gravewood_sapling"] = "gravewood",
	}

	-- The volume a species grows into, relative to the sapling: the
	-- generator's box (x and z -8..8) and the species' tallest tree plus its
	-- buried foot (the lane fixture holds every species to it).
	M.VOLUMES = {}
	local TOP = {apple = 13, jungle = 17, kapok = 27, acacia = 10, pine = 18,
		aspen = 17, silverwood = 24, gravewood = 13}
	for _, key in pairs(M.SPECIES) do
		M.VOLUMES[key] = {min = {x = -8, y = 0, z = -8}, max = {x = 8, y = TOP[key], z = 8}}
	end

	local function ground(name)
		return name == "default:gravel" or api.get_item_group(name, "soil") > 0 or
			api.get_item_group(name, "sand") > 0
	end

	local function free(node, sapling)
		if node.name == "air" or node.name == sapling then return true end
		if node.name == "ignore" then return false end
		local def = api.registered_nodes[node.name]
		return def ~= nil and def.buildable_to == true
	end

	-- Grow the sapling at pos into its species' tree. Returns true when the
	-- tree stands, false (nothing changed) when it does not fit.
	function M.grow(pos, sapling)
		local key = M.SPECIES[sapling]
		if not key then return false end
		local trees = api.trees()
		local function at(x, y, z)
			return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
		end
		local cells = trees.tree(key, api.seed(key, pos), function(x, y, z)
			return ground(api.get_node(at(x, y, z)).name)
		end)
		local writes = {}
		for index = 1, #cells do
			local cell = cells[index]
			local target = at(cell.x, cell.y, cell.z)
			local ok = (cell.x == 0 and cell.y == 0 and cell.z == 0) or
				free(api.get_node(target), sapling)
			ok = ok and api.alterable(target)
			if ok then
				writes[#writes + 1] = {target, cell}
			elseif cell.flag ~= trees.LEAF then
				return false
			end
		end
		for index = 1, #writes do
			local write = writes[index]
			api.set_node(write[1], {name = write[2].name, param2 = write[2].param2})
		end
		return true
	end
	return M
end
