-- Round 47 lane TC: the trees of one world, from the seeded generator
-- (treegen.lua, the approved Round 46 concept).
--
-- Pure Lua 5.1 / LuaJIT, no engine calls, no globals: the main and the
-- mapgen environment both `dofile` it, and so do the saplings (grug_trees),
-- the town dressing (wp13/dressing.lua) and the portable tools.
--
--   local trees = dofile(wp40 .. "/tree_templates.lua")(treegen)
--
-- SPECIES is the one species table: per species its node names (the TA
-- shape nodes of its wood, its trunk, leaves and fruit) and how many
-- template variants every world gets (Round 47 ruling 1: 32, kapok 16).
--
-- Template seeds (ruling 2): variant k of a species is the generator's tree
-- of seed s_k, where s_k comes from SHA-256 over the full world seed STRING
-- (Luanti's u64 seed as `get_mapgen_setting("seed")` returns it), the
-- species and k. The string is never turned into a number, so a seed above
-- 2^53 loses nothing, and main and emerge, which read the same string,
-- derive the same seeds and so the same templates. The first four digest
-- bytes give a u32; `u32 % 2147483646 - 1` lies in -1 .. 2147483644, the
-- generator's distinct seeds (TB report). A seed already taken by the same
-- species is skipped (k counts on), so a world's variants are distinct.
--
-- A variant is the generator's tree on flat ground, stored sparse (packed
-- arrays, never one table per cell): its cells without the roots, and the
-- roots as optional runs (handoff §5): every run a list of cells the world
-- writer places only if each cell's column has ground right under the foot
-- and none at the foot's level (two reads per cell); a fork's toe only with
-- its parent run. Cell flags: STEM (trunk logs and quarters, force-placed:
-- they may cut the surface skin like every tree trunk), LIMB (base, branch,
-- twig: need free space) and LEAF (leaves, fruit, moss: skipped where the
-- ground or a neighbour is in the way, as the shrubs' leaves are).
-- A trunk wider than one node also gets one buried layer (y = -1, a copy of
-- its foot layer, force-placed), so a 2 x 2 or 3 x 3 trunk on a gentle slope
-- does not stand on air at its low corners; on flat ground it is out of
-- sight.
return function(treegen)
	if type(treegen) ~= "table" or type(treegen.generate) ~= "function" then
		error("tree templates: generator missing", 0)
	end
	local M = {}
	local MODULUS = 2147483646

	-- Species in a fixed order. `wood` names the TA shape set
	-- (grug_trees:<wood>_quarter|base|branch|twig); kapok grows from jungle
	-- wood (handoff §3).
	M.SPECIES = {
		{key = "apple", count = 32, wood = "apple", trunk = "default:tree",
			leaves = "default:leaves", fruit = "default:apple"},
		{key = "jungle", count = 32, wood = "jungle", trunk = "default:jungletree",
			leaves = "default:jungleleaves"},
		{key = "kapok", count = 16, wood = "jungle", trunk = "default:jungletree",
			leaves = "default:jungleleaves"},
		{key = "acacia", count = 32, wood = "acacia", trunk = "default:acacia_tree",
			leaves = "default:acacia_leaves"},
		{key = "pine", count = 32, wood = "pine", trunk = "default:pine_tree",
			leaves = "default:pine_needles"},
		{key = "aspen", count = 32, wood = "aspen", trunk = "default:aspen_tree",
			leaves = "default:aspen_leaves"},
		{key = "silverwood", count = 32, wood = "silverwood",
			trunk = "grug_trees:silverwood_tree", leaves = "grug_trees:silverwood_leaves"},
		{key = "gravewood", count = 32, wood = "gravewood",
			trunk = "grug_trees:gravewood_tree", leaves = "grug_trees:gravewood_leaves"},
		-- The swamp tree (Round 47 lane SW): gravewood's wood, its own olive
		-- leaves and hanging moss.
		-- Its stilts (the limb cells up to one above the stem's lowest log)
		-- are optional like leaves: a stilt cell the ground takes is left
		-- out, so on uneven ground a stilt ends on the higher ground instead
		-- of refusing the tree (`stilts`).
		{key = "swamp", count = 32, wood = "gravewood",
			trunk = "grug_trees:gravewood_tree", leaves = "grug_trees:swamp_leaves",
			moss = "grug_trees:swamp_hanging_moss", stilts = true},
	}
	M.BY_KEY = {}
	for index = 1, #M.SPECIES do
		local row = M.SPECIES[index]
		row.quarter = "grug_trees:" .. row.wood .. "_quarter"
		row.base = "grug_trees:" .. row.wood .. "_base"
		row.branch = "grug_trees:" .. row.wood .. "_branch"
		row.twig = "grug_trees:" .. row.wood .. "_twig"
		M.BY_KEY[row.key] = row
	end

	-- The ground a root stands in (lane TA's ground connect sides: group
	-- soil, group sand and default:gravel), by name, for the world writer,
	-- which has no registry; the lane fixture holds it to the registry.
	M.ROOT_GROUND = {
		"default:desert_sand", "default:dirt", "default:dirt_with_coniferous_litter",
		"default:dirt_with_dry_grass", "default:dirt_with_grass",
		"default:dirt_with_grass_footsteps", "default:dirt_with_rainforest_litter",
		"default:dirt_with_snow", "default:dry_dirt", "default:dry_dirt_with_dry_grass",
		"default:gravel", "default:sand", "default:silver_sand", "grug_farming:soil",
		"grug_farming:soil_wet", "grug_nodes:ash_ground", "grug_nodes:blight_dirt",
		"grug_nodes:dirt_with_bone_litter", "grug_nodes:dirt_with_canopy_litter",
		"grug_nodes:dirt_with_forest_litter", "grug_nodes:dirt_with_moss",
		"grug_nodes:dirt_with_silver_litter", "grug_nodes:mud", "grug_nodes:mud_dry",
		"grug_nodes:mud_mottled", "grug_nodes:mud_with_wet_grass",
	}

	M.STEM, M.LIMB, M.LEAF = 1, 2, 3
	local FLAG = {trunk = 1, quarter = 1, base = 2, branch = 2, twig = 2,
		leaves = 3, fruit = 3, moss = 3}
	-- The flag of a node of a tree: a stilt of a `stilts` species (a limb
	-- cell up to one above the stem's lowest log) is optional (LEAF).
	local function stilt_foot(row, tree)
		if not row.stilts then return nil end
		local foot
		for index = 1, #tree.nodes do
			local node = tree.nodes[index]
			if FLAG[node.kind] == 1 and (foot == nil or node.y < foot) then foot = node.y end
		end
		return foot
	end
	local function flag_of(node, foot)
		local flag = FLAG[node.kind]
		if foot and flag == 2 and node.y <= foot + 1 then return 3 end
		return flag
	end

	-- Every node name a species places, sorted.
	function M.names(key)
		local row = M.BY_KEY[key]
		local list = {row.trunk, row.quarter, row.base, row.branch, row.twig, row.leaves}
		if row.fruit then list[#list + 1] = row.fruit end
		if row.moss then list[#list + 1] = row.moss end
		table.sort(list)
		return list
	end

	local function name_of(row, kind)
		local name = row[kind]
		if type(name) ~= "string" then
			error("tree templates: " .. row.key .. " has no node for " .. tostring(kind), 0)
		end
		return name
	end

	-- The total of variants every world builds, from the species table.
	function M.total()
		local total = 0
		for index = 1, #M.SPECIES do total = total + M.SPECIES[index].count end
		return total
	end

	-- The generator's seed from a digest's first four bytes.
	function M.seed_from_digest(digest)
		local a, b, c, d = string.byte(digest, 1, 4)
		return (((a * 256 + b) * 256 + c) * 256 + d) % MODULUS - 1
	end

	-- The `count` template seeds of a species for one world. `digest(k)`
	-- returns the raw SHA-256 of (world seed string, species, k): the caller
	-- binds the world seed and its hash (r6_templates.lua).
	function M.template_seeds(key, digest)
		local row = M.BY_KEY[key]
		local seeds, taken, k = {}, {}, 0
		while #seeds < row.count do
			local seed = M.seed_from_digest(digest(k))
			if not taken[seed] then
				taken[seed] = true
				seeds[#seeds + 1] = seed
			end
			k = k + 1
		end
		return seeds
	end

	-- One grown tree with node names: the generator's tree of `seed` on
	-- the given ground (nil: flat), as cells {x, y, z, name, param2, flag}
	-- in the generator's order, the roots among them marked `root = true`.
	-- Saplings and the town dressing use this; is_ground must return a
	-- boolean (0 is true in Lua).
	function M.tree(key, seed, is_ground)
		local row = M.BY_KEY[key]
		if not row then error("tree templates: unknown species " .. tostring(key), 0) end
		local tree = treegen.generate(key, seed, is_ground)
		local foot = stilt_foot(row, tree)
		local root_set = {}
		for index = 1, #tree.roots do
			local r = tree.roots[index]
			root_set[r[1] .. "," .. r[2] .. "," .. r[3]] = true
		end
		local cells = {}
		for index = 1, #tree.nodes do
			local node = tree.nodes[index]
			cells[index] = {x = node.x, y = node.y, z = node.z,
				name = name_of(row, node.kind), param2 = node.rot,
				flag = flag_of(node, foot),
				root = root_set[node.x .. "," .. node.y .. "," .. node.z] == true}
		end
		return cells, tree
	end

	-- One template variant: the tree of `seed` on flat ground, packed.
	--   count, x, y, z, name, param2, flag   the cells without the roots
	--   runs = {{first, last, parent}}        the root runs over
	--   root_count, rx, ry, rz, rname, rparam2  the root cells
	--   min_x .. max_z                         the bounds of everything
	--   bytes                                  the canonical bytes (digest)
	function M.variant(key, seed)
		local row = M.BY_KEY[key]
		local tree = treegen.generate(key, seed)
		local foot_y = stilt_foot(row, tree)
		local roots = {}
		for index = 1, #tree.roots do
			local r = tree.roots[index]
			roots[r[1] .. "," .. r[2] .. "," .. r[3]] = index
		end
		local v = {species = key, seed = seed, count = 0, x = {}, y = {}, z = {},
			name = {}, param2 = {}, flag = {}, root_count = #tree.roots, rx = {},
			ry = {}, rz = {}, rname = {}, rparam2 = {}, runs = {}}
		local min_x, max_x, min_y, max_y, min_z, max_z = 0, 0, 0, 0, 0, 0
		local function bound(x, y, z)
			if x < min_x then min_x = x end
			if x > max_x then max_x = x end
			if y < min_y then min_y = y end
			if y > max_y then max_y = y end
			if z < min_z then min_z = z end
			if z > max_z then max_z = z end
		end
		local foot = {}
		local function add(x, y, z, name, param2, flag)
			local n = v.count + 1
			v.count = n
			v.x[n], v.y[n], v.z[n], v.name[n], v.param2[n], v.flag[n] =
				x, y, z, name, param2, flag
			bound(x, y, z)
		end
		for index = 1, #tree.nodes do
			local node = tree.nodes[index]
			local name = name_of(row, node.kind)
			local root_index = roots[node.x .. "," .. node.y .. "," .. node.z]
			if root_index then
				v.rx[root_index], v.ry[root_index], v.rz[root_index] =
					node.x, node.y, node.z
				v.rname[root_index], v.rparam2[root_index] = name, node.rot
				bound(node.x, node.y, node.z)
			else
				add(node.x, node.y, node.z, name, node.rot, flag_of(node, foot_y))
				if node.y == 0 and FLAG[node.kind] == M.STEM then
					foot[#foot + 1] = {node.x, node.z, name, node.rot}
				end
			end
		end
		if #foot > 1 then
			for index = 1, #foot do
				local cell = foot[index]
				add(cell[1], -1, cell[2], cell[3], cell[4], M.STEM)
			end
		end
		for index = 1, #tree.root_runs do
			local run = tree.root_runs[index]
			v.runs[index] = {first = run.first, last = run.last, parent = run.parent}
		end
		v.min_x, v.max_x, v.min_y, v.max_y, v.min_z, v.max_z =
			min_x, max_x, min_y, max_y, min_z, max_z
		local parts = {"grug_tree_template_v1", key, string.format("%.0f", seed)}
		for index = 1, v.count do
			parts[#parts + 1] = v.x[index] .. "," .. v.y[index] .. "," .. v.z[index] ..
				"," .. v.name[index] .. "," .. v.param2[index] .. "," .. v.flag[index]
		end
		parts[#parts + 1] = "roots"
		for index = 1, #v.runs do
			local run = v.runs[index]
			parts[#parts + 1] = "run," .. run.parent
			for r = run.first, run.last do
				parts[#parts + 1] = v.rx[r] .. "," .. v.ry[r] .. "," .. v.rz[r] .. "," ..
					v.rname[r] .. "," .. v.rparam2[r]
			end
		end
		v.bytes = table.concat(parts, "\n")
		return v
	end

	-- A quarter turn of a tree cell about the trunk cell (0, 0), the same
	-- sense as r6_templates.lua turns a schematic: 1 is (x, z) -> (z, -x).
	function M.rotate(x, z, rotation)
		if rotation == 0 then return x, z end
		if rotation == 1 then return z, -x end
		if rotation == 2 then return -x, -z end
		return -z, x
	end

	-- The bounds of a variant turned by `rotation`.
	function M.rotated_bounds(v, rotation)
		local ax, az = M.rotate(v.min_x, v.min_z, rotation)
		local bx, bz = M.rotate(v.max_x, v.max_z, rotation)
		return math.min(ax, bx), math.max(ax, bx), v.min_y, v.max_y,
			math.min(az, bz), math.max(az, bz)
	end
	return M
end
