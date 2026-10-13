-- Round 47 lane TC portable test (round47-plan.md §4.3): the trees in the
-- world, from the seeded generator.
--   A. Templates from the seed (rulings 1-2): the real expander
--      (wp40/r6_templates.lua with wp40/tree_templates.lua and treegen.lua)
--      builds every species' variants (32, kapok 16) for six sample world
--      seeds, among them seeds above 2^53 and the u64 maximum; the roll-up
--      of the variant digests per world seed is pinned here (the frozen
--      `decoded_templates` pin's successor for the generated trees). Two
--      seeds that are the same double (2^53 and 2^53 + 1) give different
--      trees, so the seed string is used exactly; two independent loads of
--      the expander (what main and emerge each dofile) give the same digests.
--   B. Every variant of a world: distinct seeds, its trunk standing on the
--      root column, the bounds the expander checks (-8..8, y -1..63), the
--      root runs inside the variant's bounds (so a run is complete or absent
--      with its tree at a mapchunk border), apples at param2 0, and the
--      turned cells inside the turned bounds for every quarter turn.
--   C. The roots pass's rule (`kept_root_runs`): a run only when every cell
--      passes, a fork's toe only with its parent.
--   D. Sapling growth (mods/ITEMS/grug_trees/growth.lua) on a stub world:
--      the generator's tree of the sapling's seed, apples at param2 0, the
--      sapling replaced, roots only on ground, a blocked wood cell fails the
--      growth with nothing written, a guarded leaf is left out, and every
--      species' trees fit the volume `on_place` protects.
--   E. Town trees (wp13/dressing.lua): the generator's cells in the
--      palette's wood, stable across loads, a built cell in the way moves
--      the tree to another seed or refuses it, the volume's top respected;
--      settlement buffers turn the lying pieces like the templates.
--   F. Markers (wp40/vegetation_density.lua): trees are counted by trunk
--      and quarter, and every generated node is natural vegetation.
--   G. The node names: every species' names are registered, the shape
--      names are lane TA's, and the root ground list equals the registry's
--      ground (group soil, group sand, default:gravel).
--
-- Usage (repo root): luajit tools/r47_tc/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function hex(bytes) return common.hex(bytes) end

-- One independent load of the generator, the tree templates, the hash and
-- the expander, as each Lua environment does it.
local function load_stack()
	local treegen = dofile(wp40 .. "/treegen.lua")
	local trees = dofile(wp40 .. "/tree_templates.lua")(treegen)
	local hash = dofile(wp40 .. "/r6_hash.lua")(sha)
	return trees, hash
end

-- The expander over a stub content contract that knows exactly the
-- species' node names (wood: facedir, leaves and fruit: none).
local function expander(trees, hash, world_seed, rows)
	local refs, kinds, names = {}, {}, {}
	for _, row in ipairs(trees.SPECIES) do
		for _, name in ipairs(trees.names(row.key)) do
			if not refs[name] then
				names[#names + 1] = name
				refs[name] = #names
				local wood = name:match("_tree$") or name:match("tree$") or
					name:match("_quarter$") or name:match("_base$") or
					name:match("_branch$") or name:match("_twig$")
				kinds[#names] = wood and "facedir" or "none"
			end
		end
	end
	local content = {
		content_contract = function()
			return {content_kind_masks = setmetatable({}, {__index = function() return 8 end}),
				resolve_r6 = function() return 1, 1 end, ignore_cid = 0}
		end,
		decorations = function() return rows end,
		param2_kind = function(ref) return kinds[ref] end,
		content_ref = function(name) return refs[name] end,
	}
	return dofile(wp40 .. "/r6_templates.lua")(hash, content,
		{read = function() error("no schematic expected") end},
		{full_seed = world_seed, trees = trees})
end

local function species_rows(trees)
	local rows = {}
	for _, row in ipairs(trees.SPECIES) do
		rows[#rows + 1] = {id = "r47tc_" .. row.key, kind = "template",
			asset_or_node = "treegen:" .. row.key, rule = "center_xz;quarter_turn_rotation"}
	end
	return rows
end

-- The roll-up of one world: per species in table order, its variant digests.
local function rollup(templates)
	local lines = {}
	for _, row in ipairs(templates.identity().generated) do
		lines[#lines + 1] = row.species .. ":" .. table.concat(row.digests, ",")
	end
	return hex(sha(table.concat(lines, "\n")))
end

-- ---------------------------------------------------------------------------
-- A. templates from the seed
-- ---------------------------------------------------------------------------
local trees, hash = load_stack()
check(trees.total() == 32 * 8 + 16, "the species table counts 272 variants")
-- Re-pinned in Round 47 lane SW: the swamp species joins the table (32
-- variants), which adds its digests to every world's roll-up.
local PINNED = {
	["0"] = "32db91ace668a658ca91449ef13a17c8093e74cbf398ef6388a1245513caa7c6",
	["1"] = "f825090a2ea5927c8aa4dc4620f4a8e362e615c91302fc0bb4b26ccadf4fac61",
	["12345"] = "d39db26481cee771b85ce87d8af692d1c95d2d5b2ff3f236af139f0527f12b6f",
	["9007199254740992"] = "b363897d30db7f95ec13fdc857a91562133d8ba0b129bdf56b49d0a18a01db54",
	["17713522922938657774"] = "b1a9a3fb2bdf274969f7b621e1235ef069f45faf4e0c9ac7e3254fbe20170134",
	["18446744073709551615"] = "0e3ad986a547286032cd5aff117e7286b78a9b004ccc71b4892e9af99c783859",
}
local ORDER = {"0", "1", "12345", "9007199254740992", "17713522922938657774",
	"18446744073709551615"}
local rolled, sample = {}, nil
for _, world_seed in ipairs(ORDER) do
	local started = os.clock()
	local templates = expander(trees, hash, world_seed, species_rows(trees))
	rolled[world_seed] = rollup(templates)
	print(("A %s: %s (%.2f s CPU)"):format(world_seed, rolled[world_seed], os.clock() - started))
	check(rolled[world_seed] == PINNED[world_seed],
		"pinned roll-up of world seed " .. world_seed .. ": " .. rolled[world_seed])
	if world_seed == "12345" then sample = templates end
	for _, row in ipairs(templates.identity().generated) do
		check(#row.digests == trees.BY_KEY[row.species].count,
			world_seed .. " " .. row.species .. " has its species' variant count")
	end
end
do
	local a = expander(trees, hash, "9007199254740992", species_rows(trees))
	local b = expander(trees, hash, "9007199254740993", species_rows(trees))
	check(tonumber("9007199254740992") == tonumber("9007199254740993"),
		"2^53 and 2^53 + 1 are the same double")
	check(rollup(a) ~= rollup(b), "the seed string is used exactly (2^53 vs 2^53 + 1)")
	check(rollup(a) == rolled["9007199254740992"], "the same seed builds the same trees")
	-- the second environment: its own load of every module
	local trees2, hash2 = load_stack()
	local other = expander(trees2, hash2, "17713522922938657774", species_rows(trees2))
	check(rollup(other) == rolled["17713522922938657774"],
		"two independent loads (main, emerge) build the same templates")
end
-- The real catalog: every generated row names a species of the table.
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local generated_rows = {}
for _, row in ipairs(manifest.decorations) do
	local key = row.kind == "template" and row.asset_or_node:match("^treegen:(.+)$")
	if key then
		generated_rows[#generated_rows + 1] = row
		check(trees.BY_KEY[key] ~= nil, row.id .. " names a species: " .. key)
		check(row.settlement_class == nil, row.id .. " pins no settlement class")
	end
end
check(#generated_rows == 15, "fifteen tree rows are generated (" .. #generated_rows .. ")")

-- ---------------------------------------------------------------------------
-- B. every variant of a world
-- ---------------------------------------------------------------------------
for _, record in ipairs(sample.records()) do
	local seen = {}
	for index, v in ipairs(record.variants) do
		local label = record.species .. " variant " .. index
		check(not seen[v.seed], label .. " has its own seed")
		seen[v.seed] = true
		check(v.seed >= -1 and v.seed <= 2147483644, label .. " seed in the generator's range")
		local foot, fruit_ok = false, true
		local cells = {}
		for c = 1, v.count do
			-- a stilt species' stem stands 1-2 up on its stilts (lane SW)
			local foot_y = trees.BY_KEY[record.species].stilts and v.y[c] >= 1 and
				v.y[c] <= 2 and v.y[c] or 0
			if v.x[c] == 0 and v.y[c] == foot_y and v.z[c] == 0 and v.flag[c] == trees.STEM then
				foot = true
			end
			if v.name[c] == "default:apple" and v.param2[c] ~= 0 then fruit_ok = false end
			cells[v.x[c] .. "," .. v.y[c] .. "," .. v.z[c]] = true
		end
		check(foot, label .. ": a trunk stands on the root column")
		check(fruit_ok, label .. ": apples at param2 0")
		check(v.min_x >= -8 and v.max_x <= 8 and v.min_z >= -8 and v.max_z <= 8 and
			v.min_y >= -1 and v.max_y <= 63, label .. " inside the generator's box")
		for r = 1, v.root_count do
			check(v.rx[r] >= v.min_x and v.rx[r] <= v.max_x and v.rz[r] >= v.min_z and
				v.rz[r] <= v.max_z and v.ry[r] >= 0 and v.ry[r] <= 3,
				label .. " root inside the bounds")
			check(not cells[v.rx[r] .. "," .. v.ry[r] .. "," .. v.rz[r]],
				label .. " root apart from the tree's cells")
		end
		for rotation = 0, 3 do
			local turned, runs, b = sample.generated_cells(record.definition_id, index, rotation)
			local inside = #turned == v.count
			for _, cell in ipairs(turned) do
				if cell.x < b.min_x or cell.x > b.max_x or cell.z < b.min_z or
						cell.z > b.max_z or cell.y < b.min_y or cell.y > b.max_y then
					inside = false
				end
			end
			for _, run in ipairs(runs) do
				for _, cell in ipairs(run) do
					if cell.x < b.min_x or cell.x > b.max_x or cell.z < b.min_z or
							cell.z > b.max_z then inside = false end
				end
			end
			check(inside, label .. " turned " .. rotation .. " stays in its turned bounds")
		end
	end
end
-- A few spot values of the turn: a quarter turns its corner, a limb its grain.
do
	local record = sample.records()[1]
	local turned = sample.generated_cells(record.definition_id, 1, 1)
	local v = record.variants[1]
	for c = 1, v.count do
		if v.name[c]:match("_branch$") and v.param2[c] == 12 then
			check(turned[c].param2 == 4 or turned[c].param2 == 9 or turned[c].param2 == 10 or
				turned[c].param2 == 8 or turned[c].param2 == 11,
				"a branch along x runs along z after a quarter turn (" .. turned[c].param2 .. ")")
			break
		end
	end
end

-- ---------------------------------------------------------------------------
-- C. the roots pass's rule
-- ---------------------------------------------------------------------------
do
	local runs = {
		{parent = 0, {x = 1}, {x = 2}},
		{parent = 1, {x = 3}},
		{parent = 0, {x = 9}, {x = 4}},
		{parent = 3, {x = 5}},
		{parent = 0, {x = 6}},
	}
	local kept = sample.kept_root_runs(runs, function(cell) return cell.x ~= 9 end)
	check(kept[1] and kept[2] and not kept[3] and not kept[4] and kept[5],
		"a run only when every cell passes, a toe only with its parent")
end

-- ---------------------------------------------------------------------------
-- D. sapling growth
-- ---------------------------------------------------------------------------
local REG = {
	["default:dirt_with_grass"] = {groups = {soil = 1}},
	["default:stone"] = {groups = {}},
	["default:grass_1"] = {groups = {}, buildable_to = true},
}
local function stub_world(ground_at)
	local world = {}
	local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
	local api = {}
	function api.get_node(p)
		local node = world[key(p)]
		if node then return node end
		if p.y <= ground_at(p.x, p.z) then return {name = "default:dirt_with_grass", param2 = 0} end
		return {name = "air", param2 = 0}
	end
	function api.set_node(p, node) world[key(p)] = {name = node.name, param2 = node.param2 or 0} end
	api.registered_nodes = setmetatable({}, {__index = function(_, name)
		return REG[name] or {groups = {}}
	end})
	function api.get_item_group(name, group)
		local def = REG[name]
		return def and def.groups[group] or 0
	end
	api.guarded = {}
	function api.alterable(p) return not api.guarded[key(p)] end
	function api.seed(species, p) return 1000 + p.x * 7 + p.z * 13 + #species end
	api.trees = function() return trees end
	return api, world, key
end
local function growth_with(api) return dofile(repo .. "/mods/ITEMS/grug_trees/growth.lua")(api) end
do
	local api, world, key = stub_world(function() return -1 end)
	local growth = growth_with(api)
	local pos = {x = 100, y = 0, z = 200}
	world[key(pos)] = {name = "default:sapling", param2 = 0}
	check(growth.grow(pos, "default:sapling"), "an apple sapling grows on flat ground")
	local cells = trees.tree("apple", api.seed("apple", pos))
	local same, apples = true, 0
	for _, cell in ipairs(cells) do
		local node = world[key({x = pos.x + cell.x, y = cell.y, z = pos.z + cell.z})]
		if not node or node.name ~= cell.name or node.param2 ~= cell.param2 then same = false end
		if cell.name == "default:apple" then
			apples = apples + 1
			if node.param2 ~= 0 then same = false end
		end
	end
	check(same, "the sapling grew exactly the generator's tree of its seed")
	check(apples > 0, "the apple tree carries apples (" .. apples .. ")")
	check(world[key(pos)].name ~= "default:sapling", "the trunk replaced the sapling")
end
do
	-- a kapok on ground with a ditch west of it: no root over the ditch
	local api, world, key = stub_world(function(x) if x <= 197 then return -3 end return -1 end)
	local growth = growth_with(api)
	local pos = {x = 200, y = 0, z = 0}
	check(growth.grow(pos, "default:emergent_jungle_sapling"), "a kapok grows")
	local _, tree = trees.tree("kapok", api.seed("kapok", pos), function(x, y, z)
		return api.get_item_group(api.get_node({x = pos.x + x, y = y, z = pos.z + z}).name,
			"soil") > 0
	end)
	local over_ditch = false
	for _, r in ipairs(tree.roots) do
		if pos.x + r[1] <= 197 then over_ditch = true end
	end
	check(not over_ditch, "no root over the ditch")
	check(#tree.roots > 0, "the kapok keeps roots on the ground (" .. #tree.roots .. ")")
end
do
	-- a stone in a wood cell: the growth fails and nothing is written
	local api, world, key = stub_world(function() return -1 end)
	local growth = growth_with(api)
	local pos = {x = 0, y = 0, z = 0}
	world[key(pos)] = {name = "grug_trees:silverwood_sapling", param2 = 0}
	local cells = trees.tree("silverwood", api.seed("silverwood", pos))
	local wood
	for _, cell in ipairs(cells) do
		if cell.flag ~= trees.LEAF and cell.y > 2 then wood = cell break end
	end
	world[key({x = wood.x, y = wood.y, z = wood.z})] = {name = "default:stone", param2 = 0}
	local before = 0
	for _ in pairs(world) do before = before + 1 end
	check(not growth.grow(pos, "grug_trees:silverwood_sapling"), "a blocked limb fails the growth")
	local after = 0
	for _ in pairs(world) do after = after + 1 end
	check(after == before and world[key(pos)].name == "grug_trees:silverwood_sapling",
		"a failed growth writes nothing")
	-- a guarded leaf is left out, the rest grows
	world[key({x = wood.x, y = wood.y, z = wood.z})] = nil
	local leaf
	for _, cell in ipairs(cells) do if cell.flag == trees.LEAF then leaf = cell break end end
	api.guarded[key({x = leaf.x, y = leaf.y, z = leaf.z})] = true
	check(growth.grow(pos, "grug_trees:silverwood_sapling"), "the tree grows past a guarded leaf")
	check(world[key({x = leaf.x, y = leaf.y, z = leaf.z})] == nil, "the guarded leaf stays air")
	-- grass is replaced
	check(growth.grow({x = 50, y = 0, z = 50}, "default:pine_sapling"), "a pine grows")
end
do
	local api = stub_world(function() return -1 end)
	local growth = growth_with(api)
	for sapling, species in pairs(growth.SPECIES) do
		local volume, fits = growth.VOLUMES[species], true
		for seed = 1, 120 do
			local tree = trees.tree(species, seed * 7919)
			for _, cell in ipairs(tree) do
				if cell.x < volume.min.x or cell.x > volume.max.x or cell.z < volume.min.z or
						cell.z > volume.max.z or cell.y > volume.max.y then fits = false end
			end
		end
		check(fits, sapling .. ": 120 trees fit the protected volume")
	end
end

-- ---------------------------------------------------------------------------
-- E. town trees
-- ---------------------------------------------------------------------------
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local parts = dofile(wp13 .. "/parts.lua")
local palettes = dofile(wp13 .. "/palette.lua")
local function pad(radius)
	local buf = parts.buffer()
	buf:fill(-radius, 0, -radius, radius, 0, radius, "default:dirt_with_grass")
	return buf
end
do
	local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
	local human = palettes.new("human")
	local buf = pad(14)
	check(dressing.broadleaf(buf, human, 0, 0, 5), "a town apple stands on open ground")
	local count, pieces, top = 0, 0, 0
	for _, cell in ipairs(buf.order) do
		if cell.y >= 1 then
			count = count + 1
			if parts.tree_piece(cell.name) then pieces = pieces + 1 end
			top = math.max(top, cell.y)
		end
	end
	local again = pad(14)
	dofile(wp13 .. "/dressing.lua")(wp13).broadleaf(again, human, 0, 0, 5)
	local same = #again.order == #buf.order
	for index, cell in ipairs(buf.order) do
		local other = again.order[index]
		if not other or other.name ~= cell.name or other.param2 ~= cell.param2 or
				other.x ~= cell.x or other.y ~= cell.y or other.z ~= cell.z then same = false end
	end
	check(same, "the town tree is the same on every load (" .. count .. " cells)")
	check(pieces > 0, "the town tree is made of the shape nodes (" .. pieces .. ")")
	check(top <= 21, "the town tree stays under the volume's top (" .. top .. ")")
	-- the generator's own cells at attempt 0, in the palette's wood
	local undead = palettes.new("undead")
	local grave = pad(14)
	dressing.gravewood(grave, undead, 0, 0, 5)
	local logs = 0
	for _, cell in ipairs(grave.order) do
		if cell.name == "grug_trees:gravewood_tree" then logs = logs + 1 end
		check(cell.y < 1 or cell.name:match("^grug_trees:gravewood") ~= nil,
			"a gravewood is gravewood wood and leaves: " .. cell.name)
	end
	check(logs > 0, "the gravewood has a stem")
	-- a pine routine in the human palette grows a pine of apple wood
	local mixed = pad(14)
	dressing.tree(mixed, human, 0, 0, 9)
	local woods = {}
	for _, cell in ipairs(mixed.order) do
		if cell.y >= 1 then woods[cell.name] = true end
	end
	check(woods["default:tree"] and not woods["default:pine_tree"],
		"the routine's shape in the palette's wood")
	-- a wall in the way: no wood lands on it
	local walled = pad(14)
	walled:fill(2, 1, -14, 2, 6, 14, "default:cobble")
	dressing.broadleaf(walled, human, 0, 0, 5)
	local wall_kept = true
	for z = -14, 14 do
		for y = 1, 6 do
			local cell = walled:at(2, y, z)
			if not cell or cell.name ~= "default:cobble" then wall_kept = false end
		end
	end
	check(wall_kept, "a town tree never replaces a built cell")
	-- no ground: no tree
	local bare = parts.buffer()
	check(not dressing.broadleaf(bare, human, 0, 0, 5), "no ground, no town tree")
	-- a lying piece turns with a plot like a template's
	check(parts.rotate_param2(4, parts.FACEDIR, 1) == 13 and
		parts.rotate_param2(12, parts.FACEDIR, 1) == 9 and
		parts.rotate_param2(2, parts.FACEDIR, 1) == 3,
		"settlement turns: grain along z -> x, along x -> z, quarters by one")
end

-- E2. dense town trees (groves follow-up): on one pad a lattice of trees
-- three nodes apart (a grove's spacing): wood never lands on wood or on a
-- built cell, a leaf never replaces anything, the crowns interleave.
do
	local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
	local elf = palettes.new("elf")
	local buf = pad(16)
	buf.tree_spacing = 3
	buf:fill(-16, 1, 15, 16, 3, 16, "default:cobble")
	local wood_names = {}
	for _, row in ipairs(trees.SPECIES) do
		for _, key in ipairs({"trunk", "quarter", "base", "branch", "twig"}) do
			wood_names[row[key]] = true
		end
	end
	local real_put = buf.put
	local violations, wood_puts, leaf_on_leaf = 0, 0, 0
	buf.put = function(self, x, y, z, name, param2)
		local old = self:at(x, y, z)
		if old and old.name ~= "air" then
			if not wood_names[name] then violations = violations + 1 end
			if wood_names[old.name] or old.name == "default:cobble" then
				violations = violations + 1
			end
			if not wood_names[name] then leaf_on_leaf = leaf_on_leaf + 1 end
		end
		if wood_names[name] then wood_puts = wood_puts + 1 end
		return real_put(self, x, y, z, name, param2)
	end
	local planted = 0
	for gx = -12, 12, 3 do
		for gz = -12, 12, 3 do
			if dressing.columnar(buf, elf, gx, gz, 10) then planted = planted + 1 end
		end
	end
	check(planted >= 12, "a dense lattice plants a grove (" .. planted .. " trees)")
	check(violations == 0, "no wood on wood or a built cell, no leaf replacing anything (" ..
		violations .. ")")
	check(leaf_on_leaf == 0 and wood_puts > 0, "crowns merge without a leaf overwrite")
end
-- E3. every capital grove and copse plot has trees again (>= 4 each).
do
	local counting = 0
	local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
	local real_dofile = dofile
	local function counted(loader)
		return function(...)
			local M = loader(...)
			for _, name in ipairs({"tree", "broadleaf", "columnar", "acacia", "gravewood",
					"jungle_tree", "emergent"}) do
				local routine = M[name]
				M[name] = function(...)
					local planted = routine(...)
					if planted then counting = counting + 1 end
					return planted
				end
			end
			return M
		end
	end
	rawset(_G, "dofile", function(path, ...)
		local result = real_dofile(path, ...)
		if type(path) == "string" and path:match("wp13/dressing%.lua$") then
			return counted(result)
		end
		return result
	end)
	local groves = 0
	for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
			"kezamba"}) do
		local kit = capital.kit(key)
		for _, plot in ipairs(kit.plots) do
			if plot.id:match("grove") or plot.id:match("copse") then
				counting = 0
				plot.build()
				groves = groves + 1
				check(counting >= 4, key .. "/" .. plot.id .. " has trees (" .. counting .. ")")
			end
		end
	end
	rawset(_G, "dofile", real_dofile)
	check(groves >= 8, "the grove and copse plots were found (" .. groves .. ")")
end

-- E4. capital greening (wp13/city_green.lua) on a synthetic city: a square
-- wall of half 120 round the anchor, one plot, a street; the trees stand
-- only on the open ground, keep their stems apart, never share wood, and a
-- mapchunk split writes exactly the cells of the whole (the seam rule).
do
	local green_module = dofile(wp13 .. "/city_green.lua")(wp13)
	local pts = {}
	for i = -120, 119, 8 do pts[#pts + 1] = {i, -120} end
	for i = -120, 119, 8 do pts[#pts + 1] = {120, i} end
	for i = 120, -119, -8 do pts[#pts + 1] = {i, 120} end
	for i = 120, -119, -8 do pts[#pts + 1] = {-120, i} end
	local layout = {wall = {pts = pts}, squares = {{x = 70, z = -70, r = 6}}}
	local anchor = {x = 1000, z = 2000}
	local plot = {min_x = 1060, max_x = 1080, min_z = 2060, max_z = 2080, turns = 0}
	local function column(x, z)
		local road = (x - anchor.x) == 30 or (x - anchor.x) == 31
		local ground = 10 + (z - anchor.z > 90 and 1 or 0)
		return ground, nil, road
	end
	local function make()
		return green_module.new({race = "human", anchor = anchor, layout = layout,
			plots = {plot}, column = column})
	end
	local green = make()
	local box = {min_x = anchor.x - 130, max_x = anchor.x + 130,
		min_z = anchor.z - 130, max_z = anchor.z + 130}
	local cells = green.cells(box)
	check(#cells > 1000, "the synthetic city grows trees (" .. #cells .. " cells)")
	local by, wood_names = {}, {}
	for _, row in ipairs(trees.SPECIES) do
		for _, key in ipairs({"trunk", "quarter", "base", "branch", "twig"}) do
			wood_names[row[key]] = true
		end
	end
	local ok_place, unique, stems = true, true, {}
	for _, c in ipairs(cells) do
		local k = c.x .. ":" .. c.y .. ":" .. c.z
		if by[k] then unique = false end
		by[k] = c
		local lx, lz = c.x - anchor.x, c.z - anchor.z
		local wood = wood_names[c.name]
		-- wood clear of the plot's collar (8 + 1) and approach (12, front -z),
		-- a leaf of the plot itself (2)
		local m = wood and 9 or 2
		if (math.abs(lx) <= 53 and math.abs(lz) <= 53) or math.abs(lx) > 108 or
				math.abs(lz) > 108 or (c.x >= plot.min_x - m and c.x <= plot.max_x + m and
					c.z >= plot.min_z - m - (wood and 12 or 0) and c.z <= plot.max_z + m) or
				((lx == 30 or lx == 31) and c.y <= column(c.x, c.z) + 3) then
			ok_place = false
		end
		if wood_names[c.name] and c.y == 11 then stems[#stems + 1] = c end
	end
	check(ok_place, "no city tree in the core, near the wall, on a plot or low over the street")
	check(unique, "no two city trees write one cell")
	check(#stems > 20, "the city has trees (" .. #stems .. " trunk feet)")
	local again = make().cells(box)
	local same = #again == #cells
	for i = 1, math.min(#again, #cells) do
		local a, b = again[i], cells[i]
		if a.x ~= b.x or a.y ~= b.y or a.z ~= b.z or a.name ~= b.name or a.param2 ~= b.param2 then
			same = false
		end
	end
	check(same, "the city trees are deterministic")
	local split, parts_seen = {}, 0
	local fresh = make()
	for _, sub in ipairs({
			{min_x = box.min_x, max_x = anchor.x - 1, min_z = box.min_z, max_z = anchor.z - 1},
			{min_x = anchor.x, max_x = box.max_x, min_z = box.min_z, max_z = anchor.z - 1},
			{min_x = box.min_x, max_x = anchor.x - 1, min_z = anchor.z, max_z = box.max_z},
			{min_x = anchor.x, max_x = box.max_x, min_z = anchor.z, max_z = box.max_z}}) do
		for _, c in ipairs(fresh.cells(sub)) do
			split[c.x .. ":" .. c.y .. ":" .. c.z] = c.name
			parts_seen = parts_seen + 1
		end
	end
	local seam = parts_seen == #cells
	for k, c in pairs(by) do if split[k] ~= c.name then seam = false end end
	check(seam, "four mapchunk parts write exactly the whole city's tree cells")
end

-- E5. over every composition (the POIs, the starts, every capital core and
-- plot): no write after a town tree cuts its wood -- every tree still
-- standing holds all its wood cells, and a tree a later prop cut is gone.
do
	local buffers = {}
	local real_dofile = dofile
	rawset(_G, "dofile", function(path, ...)
		local result = real_dofile(path, ...)
		if type(path) == "string" and path:match("wp13/parts%.lua$") and
				type(result) == "table" and not result.r47tc_wrapped then
			local make = result.buffer
			result.buffer = function(...)
				local b = make(...)
				buffers[#buffers + 1] = b
				return b
			end
			result.r47tc_wrapped = true
		end
		return result
	end)
	real_dofile(repo .. "/tools/r36_w/baseline.lua")(repo)
	rawset(_G, "dofile", real_dofile)
	local standing, cut, broken = 0, 0, 0
	for _, b in ipairs(buffers) do
		b:cells()
		for _, tree in ipairs(b.grown_trees or {}) do
			if tree.cut then
				cut = cut + 1
				-- nothing of a removed tree stays: no wood and no leaf of its own
				-- (a cell holding its name now is a prop's or another tree's write)
				for _, w in ipairs(tree.writes) do
					local cell = b.cell[w.key]
					if cell and cell.name == w.name and
							(not w.prev_name or w.prev_name ~= w.name) then
						local owner = b.grown_wood and b.grown_wood[w.key]
						if w.wood or not owner then broken = broken + 1 end
					end
				end
			else
				standing = standing + 1
				for _, w in ipairs(tree.writes) do
					local cell = b.cell[w.key]
					if w.wood and (not cell or cell.name ~= w.name) then broken = broken + 1 end
				end
			end
		end
	end
	-- two cut trees where the later one's wood stands on the earlier one's
	-- leaf: taken out newest first, no leaf of either floats afterwards
	do
		local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
		local human = palettes.new("human")
		local buf = pad(16)
		buf.tree_spacing = 3
		local planted = {}
		for gx = -9, 9, 3 do
			for gz = -9, 9, 3 do
				if dressing.broadleaf(buf, human, gx, gz, 5) then planted[#planted + 1] = true end
			end
		end
		local overlap
		for id = #buf.grown_trees, 2, -1 do
			for _, w in ipairs(buf.grown_trees[id].writes) do
				if w.wood and w.prev_name == human.node("tree_leaves") then overlap = id break end
			end
			if overlap then break end
		end
		check(overlap ~= nil, "the dense lattice has a tree whose wood stands on a leaf")
		if overlap then
			-- cut the overlapping tree and every earlier one by a prop on a wood cell
			local cut_ids = {overlap}
			for id = 1, overlap - 1 do cut_ids[#cut_ids + 1] = id end
			for _, id in ipairs(cut_ids) do
				for _, w in ipairs(buf.grown_trees[id].writes) do
					if w.wood and buf.grown_wood[w.key] == id then
						local x, y, z = w.key:match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
						buf:put(tonumber(x), tonumber(y), tonumber(z), "default:cobble")
						break
					end
				end
			end
			buf:cells()
			local floating = 0
			for _, id in ipairs(cut_ids) do
				for _, w in ipairs(buf.grown_trees[id].writes) do
					local cell = buf.cell[w.key]
					if cell and cell.name == w.name and not w.wood and
							not (buf.grown_leaves[w.key]) then
						floating = floating + 1
					end
				end
			end
			check(floating == 0, "no leaf of a removed tree is restored (" .. floating .. ")")
		end
	end
	print(("E5: %d town trees standing, %d cut by a later write and taken out"):format(
		standing, cut))
	check(standing > 800, "the town trees stand (" .. standing .. ")")
	check(broken == 0, "no later write cuts a town tree's wood (" .. broken .. " cells)")
end

-- ---------------------------------------------------------------------------
-- F. markers
-- ---------------------------------------------------------------------------
do
	local habitat = dofile(wp40 .. "/habitat_registry.lua")
	local world_seed = "12345"
	local rows = {}
	for _, row in ipairs(manifest.decorations) do
		if row.kind == "template" and row.asset_or_node:match("^treegen:") then
			rows[#rows + 1] = row
		end
	end
	local templates = expander(trees, hash, world_seed, rows)
	local records = templates.records()
	for _, row in ipairs(manifest.decorations) do
		if row.kind == "template" and not row.asset_or_node:match("^treegen:") then
			records[#records + 1] = {definition_id = row.id, rotations = {{size_x = 1,
				size_y = 4, size_z = 1, cells = {
					{name = "default:bush_stem", probability = 254},
					{name = "default:pine_bush_stem", probability = 254},
					{name = "default:acacia_bush_stem", probability = 254},
					{name = "default:blueberry_bush_leaves", probability = 254}}}}}
		end
	end
	local density = dofile(wp40 .. "/vegetation_density.lua")({
		habitat = habitat, vegetation_rule = habitat.vegetation_rule(world_seed,
			function() return "elandor_dawnmere_fields" end),
		world_plants = {}, p9g_rows = {}, decorations = manifest.decorations,
		decoration_cover = function() return 1 end,
		support_names = {"default:dirt_with_grass", "grug_nodes:dirt_with_canopy_litter"},
		template_records = records,
		column_values_at = function() return "land" end,
		overlay_exclusion_at = function() return nil end,
		surface_mob_level_at = function() return 5 end,
		primary_relief_at = function() return "plains" end,
		static_exclusion_values_at = function() return nil end,
		surface_cave_run_at = function() return nil end,
	})
	local markers = {}
	for _, name in ipairs(density.markers("tree")) do markers[name] = true end
	check(markers["default:tree"] and markers["grug_trees:apple_quarter"] and
		markers["grug_trees:jungle_quarter"] and not markers["grug_trees:apple_branch"],
		"trees are counted by trunk and quarter")
	local natural = density.natural_vegetation()
	check(natural["grug_trees:kapok_quarter"] == nil and natural["grug_trees:jungle_quarter"] and
		natural["grug_trees:apple_twig"] and natural["grug_trees:jungle_base"],
		"every generated node is natural vegetation")
	local entry
	for _, e in ipairs(density.palette("tree", "grug_meadows", "default:dirt_with_grass") or {}) do
		if e.id == "meadows_apple_tree" then entry = e end
	end
	check(entry and entry.columns >= 1 and entry.columns < 4,
		"an apple marks 1..4 trunk columns on average (" .. tostring(entry and entry.columns) .. ")")
end

-- ---------------------------------------------------------------------------
-- G. the node names
-- ---------------------------------------------------------------------------
do
	_G.R24_MINING_HARNESS = true
	local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
	_G.R24_MINING_HARNESS = nil
	for _, row in ipairs(trees.SPECIES) do
		for _, name in ipairs(trees.names(row.key)) do
			check(H.nodes[name] ~= nil, row.key .. " node registered: " .. name)
		end
		local shapes = rawget(_G, "grug_trees") and grug_trees.shape_nodes[row.wood]
		check(shapes and shapes.quarter == row.quarter and shapes.base == row.base and
			shapes.branch == row.branch and shapes.twig == row.twig,
			row.key .. " uses lane TA's " .. row.wood .. " shapes")
		check(grug_trees.shape_woods[row.wood].trunk == row.trunk,
			row.key .. " trunk is its wood's")
	end
	local ground = {}
	for name, def in pairs(H.nodes) do
		local groups = def.groups or {}
		if (groups.soil or 0) > 0 or (groups.sand or 0) > 0 or name == "default:gravel" then
			ground[#ground + 1] = name
		end
	end
	table.sort(ground)
	check(table.concat(ground, " ") == table.concat(trees.ROOT_GROUND, " "),
		"the root ground list is the registry's ground: " .. table.concat(ground, " "))
end

print(("r47_tc: %d checks, %d failed"):format(checks, failures))
if failures > 0 then error("r47_tc: " .. failures .. " failures", 0) end
print("PASS r47_tc")
