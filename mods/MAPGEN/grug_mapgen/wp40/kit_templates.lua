-- Round 51 lane LK: the land kit's small structures (land plan rulings 7-9,
-- 12-14; the land viewer tools/r47_sw/land.js `BUILD`, the user's picks of
-- 2026-10-19): wild graveyards, ruins, the crypt doorway, statues, the
-- obelisk, fallen logs and stumps, grave mounds, bone finds, boulders,
-- cairns, dead snow-covered pines and the beach's driftwood.
--
-- Pure Lua 5.1 / LuaJIT, no engine calls, no globals: the main and the
-- mapgen environment both `dofile` it (r7_runtime.lua), and so do the
-- portable tools.
--
--   local kit = dofile(wp40 .. "/kit_templates.lua")(treegen, trees)
--
-- (`trees`: tree_templates.lua's module, for the dead pine.) The module
-- has the shape r6_templates.lua reads from tree_templates.lua: SPECIES,
-- BY_KEY, template_seeds, variant, rotate, rotated_bounds. A decoration row
-- whose asset is `kitgen:<key>` places this world's variants of `key`,
-- as many per world as SPECIES says, turned per placement like a tree, so
-- every world has its own graveyards and no two bone finds need to look
-- alike (ruling 8). Variant seeds come from the world seed string exactly
-- as the trees' do (r6_templates.lua).
--
-- A variant is a list of RUNS (the trees' root runs, handoff §5): the
-- world writer places a run only if, for every cell of it, the cell's
-- column has kit ground right under the root's level and none at it (the
-- terrain neither falls away nor rises there) and the cell itself is free;
-- a run with a parent only with its parent. A REQUIRED run that cannot
-- stand rejects the whole structure, so the core of a structure stands on
-- level ground or not at all and its optional pieces (a fence post, a
-- fallen block, the second piece of a bone pair) drop out where the ground
-- differs. Nothing floats, and nothing cuts into ground it does not stand
-- on: a cell at y = -1 (a sunken course, a crypt step) takes the place of
-- its own column's top, which the same test has just found to be ground.
-- The dead pine is the one structure with cells outside runs: a tree's
-- stem, limbs and snow, which the writer places as it places every
-- generated tree (stem force-placed, limbs into free cells, snow optional),
-- its roots as runs.
--
-- Every block is a default block or a prop of grug_nodes (props.lua): a
-- prop drops a default block, a bone piece nothing (ruling 7).
return function(treegen, trees)
	if type(treegen) ~= "table" or type(treegen.new_rng) ~= "function" or
			type(treegen.rint) ~= "function" or type(trees) ~= "table" or
			type(trees.tree) ~= "function" then
		error("kit templates: generator missing", 0)
	end
	local M = {}
	local new_rng, rint = treegen.new_rng, treegen.rint
	local MODULUS = 2147483646

	local N = {
		cobble = "default:cobble", mossy = "default:mossycobble",
		brick = "default:stonebrick", block = "default:stone_block",
		stone = "default:stone", gravel = "default:gravel", dirt = "default:dirt",
		fence = "default:fence_junglewood", carpet = "grug_nodes:moss_carpet",
		snow = "default:snow",
		ss = "default:silver_sandstone", ss_brick = "default:silver_sandstone_brick",
		ss_block = "default:silver_sandstone_block",
		slab = "grug_nodes:gravestone_stele", cross = "grug_nodes:gravestone_cross",
		fallen = "grug_nodes:gravestone_fallen", sunken = "grug_nodes:gravestone_sunken",
		skull = "grug_nodes:skull_human", horned = "grug_nodes:skull_horned",
		ribcage = "grug_nodes:ribcage_human", spine = "grug_nodes:spine_animal",
		bones = "grug_nodes:bone_pile", fragments = "grug_nodes:bones_fragments",
		mourner_base = "grug_nodes:statue_mourner_base",
		mourner_upper = "grug_nodes:statue_mourner_upper",
		torso = "grug_nodes:statue_broken_torso", head = "grug_nodes:statue_veiled_head",
		tip = "grug_nodes:obelisk_broken_tip",
		course = "grug_nodes:cairn_course", cap = "grug_nodes:cairn_cap",
		cairn_base = "grug_nodes:cairn_base", cairn_branch = "grug_nodes:cairn_branch",
		cairn_twig = "grug_nodes:cairn_twig",
		gravewood = "grug_trees:gravewood_tree", gw_base = "grug_trees:gravewood_base",
		gw_branch = "grug_trees:gravewood_branch", gw_twig = "grug_trees:gravewood_twig",
		jungle = "default:jungletree", silverwood = "grug_trees:silverwood_tree",
		drift_log = "grug_nodes:driftwood_log", drift_fork = "grug_nodes:driftwood_fork",
	}
	M.NODES = N
	-- A log lying along x (facedir 12; a quarter turn makes it lie along z).
	local ALONG_X = 12
	local SIDES = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

	-- The ground a kit cell's column must stand on (right under the root's
	-- level, and none at it): the trees' root ground and the bare tops of
	-- the kit's zones (stone, snow, mesa clay, the decorative rocks).
	M.GROUND = {}
	for index = 1, #trees.ROOT_GROUND do M.GROUND[index] = trees.ROOT_GROUND[index] end
	for _, name in ipairs({"default:stone", "default:snowblock", "default:ice",
			"grug_nodes:mesa_clay", "grug_nodes:clay_band_chalk", "grug_nodes:clay_band_ochre",
			"grug_nodes:clay_band_sienna", "grug_nodes:clay_band_umber", "grug_materials:slate",
			"grug_materials:basalt", "grug_materials:granite"}) do
		M.GROUND[#M.GROUND + 1] = name
	end
	table.sort(M.GROUND)

	-- ------------------------------------------------------------ builder
	--
	-- A variant under construction: runs of cells, each cell once. `run`
	-- opens a run (required or not, with an optional parent run index) and
	-- returns its index; `put` adds a cell to the open run and skips a cell
	-- another run already holds. `main` adds a cell outside the runs (the
	-- dead pine's tree cells).
	local function new_builder()
		local b = {runs = {}, taken = {}, main = {}}
		function b.run(required, parent)
			b.runs[#b.runs + 1] = {required = required == true, parent = parent or 0, cells = {}}
			return #b.runs
		end
		function b.put(x, y, z, name, param2)
			local key = x .. "," .. y .. "," .. z
			if b.taken[key] then return false end
			b.taken[key] = true
			local cells = b.runs[#b.runs].cells
			cells[#cells + 1] = {x, y, z, name, param2 or 0}
			return true
		end
		function b.main_cell(x, y, z, name, param2, flag)
			local key = x .. "," .. y .. "," .. z
			if b.taken[key] then return false end
			b.taken[key] = true
			b.main[#b.main + 1] = {x, y, z, name, param2 or 0, flag}
			return true
		end
		return b
	end
	local function pick(rng, list) return list[rint(rng, 1, #list)] end

	-- ----------------------------------------------------------- builders
	--
	-- Each builds one structure round the root column (0, 0), y = 0 the
	-- first free node above the ground, as the viewer's builder of the same
	-- name lays it (tools/r47_sw/land.js).
	local BUILD = {}

	-- A small plot that differs per world: 2-6 stones in rough rows 2 or 3
	-- apart, a fifth fallen and a fifth sunken, the rest a mix leaning to
	-- steles or to crosses (a stele, a low cross, a stele crowned by the
	-- cross, one quarter turn per stack), and a fence remnant on 0-2 sides.
	-- The first stone stands on the root and must; every other one is a
	-- run of its own.
	function BUILD.graveyard(b, rng)
		local gap, cols, rows = rint(rng, 2, 3), rint(rng, 2, 3), rint(rng, 1, 2)
		local wide, deep = (cols - 1) * gap + 2, (rows - 1) * gap + 2
		local lean = rint(rng, 0, 2)   -- 0 steles, 1 mixed, 2 crosses
		local spots = {}
		for gz = 0, rows - 1 do
			for gx = 0, cols - 1 do
				if gx == 0 and gz == 0 then
					spots[1] = {0, 0}
				else
					spots[#spots + 1] = {gx * gap + rint(rng, 0, 1), gz * gap + rint(rng, 0, 1)}
				end
			end
		end
		for i = #spots, 3, -1 do
			local j = rint(rng, 2, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		local n = math.min(#spots, rint(rng, 2, 6))
		for i = 1, n do
			local x, z = spots[i][1], spots[i][2]
			b.run(i == 1)
			local form = rint(rng, 0, 9) + (lean - 1) * 3
			local turn = pick(rng, {0, 0, 0, 1, 3, 2})
			local ruin = rint(rng, 0, 9)
			if ruin < 2 then
				b.put(x, 0, z, N.fallen, rint(rng, 0, 3))
			elseif ruin < 4 then
				b.put(x, 0, z, N.sunken, turn)
			elseif form >= 7 then
				b.put(x, 0, z, N.cross, turn)
			elseif form <= 2 then
				b.put(x, 0, z, N.slab, turn)
			else
				b.put(x, 0, z, N.slab, turn)
				b.put(x, 1, z, N.cross, turn)
			end
		end
		local sides = rint(rng, 0, 2)
		if sides >= 1 then
			for fx = -1, wide do
				if rint(rng, 0, 9) < 6 then
					b.run(false)
					b.put(fx, 0, -1, N.fence)
				end
			end
		end
		if sides >= 2 then
			for fz = 0, deep do
				if rint(rng, 0, 9) < 5 then
					b.run(false)
					b.put(-1, 0, fz, N.fence)
				end
			end
		end
	end

	-- An L of two wall pieces falling off in height, a third piece apart,
	-- a fallen block or two; each wall column a run, the corner required.
	local function ruin(b, rng, mats)
		local function wall(px, pz, high, required)
			b.run(required)
			for k = 0, high - 1 do b.put(px, k, pz, pick(rng, mats)) end
		end
		local la, lb = rint(rng, 3, 5), rint(rng, 2, 4)
		for i = 0, la - 1 do
			wall(i, 0, math.max(1, 3 - math.floor(i * 3 / la) - rint(rng, 0, 1)), i == 0)
		end
		for j = 1, lb - 1 do
			wall(0, j, math.max(1, 2 - math.floor(j * 2 / lb) + rint(rng, 0, 1)))
		end
		local ox, oz = rint(rng, 3, 5), rint(rng, 3, 5)
		wall(ox, oz, rint(rng, 1, 2))
		if rint(rng, 0, 1) == 1 then wall(ox + 1, oz, 1) end
		for _ = 1, 2 do
			b.run(false)
			b.put(rint(rng, 1, 4), 0, rint(rng, 1, 4), pick(rng, mats))
		end
	end
	function BUILD.ruin_undead(b, rng)
		ruin(b, rng, {N.mossy, N.mossy, N.cobble, N.brick})
	end
	function BUILD.ruin_elves(b, rng)
		ruin(b, rng, {N.ss_brick, N.ss_brick, N.ss_block, N.mossy})
	end

	-- Two stone brick piers three apart, the higher carrying a broken
	-- lintel, the other fallen short; a block lying between them.
	function BUILD.ruin_arch(b, rng)
		local function mat() return rint(rng, 0, 9) < 7 and N.brick or N.mossy end
		local high = rint(rng, 3, 4)
		b.run(true)
		for k = 0, high - 1 do b.put(0, k, 0, mat()) end
		for k = 0, rint(rng, 1, high - 1) - 1 do b.put(3, k, 0, mat()) end
		b.put(1, high - 1, 0, mat())
		b.run(false)
		b.put(2, 0, 0, mat())
	end

	-- A stone brick column 1-2 high on a stone block, a drum fallen beside
	-- it, a moss carpet.
	function BUILD.ruin_column(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.block)
		b.put(0, 1, 0, N.brick)
		if rint(rng, 0, 1) == 1 then b.put(0, 2, 0, N.brick) end
		local side = pick(rng, SIDES)
		b.run(false)
		b.put(side[1], 0, side[2], N.brick)
		b.run(false)
		b.put(-side[2], 0, side[1], N.carpet)
	end

	-- An L of mossy wall whose lowest course lies in the ground (the
	-- ground's top turned to wall), 0-2 courses showing; the corner has two.
	function BUILD.ruin_corner(b, rng)
		local function mat() return rint(rng, 0, 9) < 6 and N.mossy or N.brick end
		local function wall(px, pz, up, required)
			b.run(required)
			b.put(px, -1, pz, mat())
			for k = 0, up - 1 do b.put(px, k, pz, mat()) end
		end
		local la, lb = rint(rng, 3, 4), rint(rng, 2, 3)
		for i = 0, la - 1 do wall(i, 0, i == 0 and 2 or rint(rng, 0, 1), i == 0) end
		for j = 1, lb - 1 do wall(0, j, rint(rng, 0, 1)) end
	end

	-- A stone brick doorway (two posts, a lintel, a broken end) over a
	-- threshold of brick in the ground, a gravel step before it and the
	-- doorway choked with gravel and cobble.
	function BUILD.crypt(b, rng)
		b.run(true)
		for k = 0, 1 do
			b.put(-1, k, 0, N.brick)
			b.put(1, k, 0, N.brick)
		end
		b.put(-1, 2, 0, N.brick)
		b.put(0, 2, 0, N.brick)
		if rint(rng, 0, 1) == 1 then b.put(1, 2, 0, N.brick) end
		b.put(0, -1, 0, N.brick)
		b.put(0, 0, 0, pick(rng, {N.gravel, N.cobble}))
		-- the rubble behind the door and the step before it, where the
		-- ground allows
		b.run(false, 1)
		b.put(0, 0, 1, N.cobble)
		b.put(-1, 0, 1, N.brick)
		b.put(1, 0, 1, N.brick)
		b.run(false, 1)
		b.put(0, -1, -1, N.gravel)
	end

	-- A log lying along x, its grain along it, now and then a moss carpet
	-- on it. Its first three nodes must lie level; each further node only
	-- with the one before it, so on uneven ground the log is shorter.
	local function log(b, rng, name, lo, hi)
		local len = rint(rng, lo, hi)
		local core = b.run(true)
		for i = 0, 2 do b.put(i, 0, 0, name, ALONG_X) end
		local last = core
		for i = 3, len - 1 do
			last = b.run(false, last)
			b.put(i, 0, 0, name, ALONG_X)
		end
		if rint(rng, 0, 1) == 1 then
			b.run(false, core)
			b.put(1, 1, 0, N.carpet)
		end
	end
	function BUILD.gravewood_log(b, rng) log(b, rng, N.gravewood, 3, 5) end
	function BUILD.kapok_log(b, rng) log(b, rng, N.jungle, 5, 7) end
	function BUILD.silver_log(b, rng) log(b, rng, N.silverwood, 3, 5) end

	-- A gravewood log 1-2 high, its broken top a branch or twig shape, a
	-- root base on one side.
	function BUILD.gravewood_stump(b, rng)
		local high = rint(rng, 1, 2)
		b.run(true)
		for k = 0, high - 1 do b.put(0, k, 0, N.gravewood) end
		b.put(0, high, 0, rint(rng, 0, 1) == 1 and N.gw_branch or N.gw_twig)
		local side = pick(rng, SIDES)
		b.run(false)
		b.put(side[1], 0, side[2], N.gw_base)
	end

	-- Two dirt nodes in a row, a low cross at the head now and then.
	function BUILD.grave_mound(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.dirt)
		b.put(1, 0, 0, N.dirt)
		if rint(rng, 0, 1) == 1 then
			b.run(false)
			b.put(2, 0, 0, N.cross, 1)
		end
	end

	-- The kneeling mourner (base and upper with the same quarter turn) on a
	-- stone block; now and then only the bust, or only the broken base.
	function BUILD.statue_undead(b, rng)
		local turn, form = rint(rng, 0, 3), rint(rng, 0, 5)
		b.run(true)
		b.put(0, 0, 0, N.block)
		if form == 0 then
			b.put(0, 1, 0, N.mourner_upper, turn)
		else
			b.put(0, 1, 0, N.mourner_base, turn)
			if form ~= 1 then b.put(0, 2, 0, N.mourner_upper, turn) end
		end
		b.run(false)
		b.put(1, 0, 0, N.carpet)
	end

	-- The broken torso on a silver sandstone plinth, the veiled head on it
	-- (the same quarter turn) or, decayed, fallen beside it.
	function BUILD.statue_elves(b, rng)
		local turn = rint(rng, 0, 3)
		b.run(true)
		b.put(0, 0, 0, N.ss)
		b.put(0, 1, 0, N.torso, turn)
		if rint(rng, 0, 2) > 0 then
			b.put(0, 2, 0, N.head, turn)
		else
			b.run(false)
			b.put(1, 0, 0, N.head, rint(rng, 0, 3))
		end
		b.run(false)
		b.put(-1, 0, 1, N.carpet)
	end

	-- A stone block plinth, a shaft of 1-2 plain stone, the broken tip.
	function BUILD.obelisk(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.block)
		b.put(0, 1, 0, N.stone)
		local top = 2
		if rint(rng, 0, 1) == 1 then
			b.put(0, 2, 0, N.stone)
			top = 3
		end
		b.put(0, top, 0, N.tip, rint(rng, 0, 3))
	end

	-- One piece, or now and then a pair: a skull beside its ribcage
	-- (humanoid) or beside a spine (animal), both with one quarter turn.
	function BUILD.bones(b, rng)
		if rint(rng, 0, 3) == 0 then
			local human = rint(rng, 0, 1) == 1
			local turn = rint(rng, 0, 3)
			b.run(true)
			b.put(0, 0, 0, human and N.skull or N.horned, turn)
			b.run(false)
			b.put(1, 0, 0, human and N.ribcage or N.spine, turn)
		else
			b.run(true)
			b.put(0, 0, 0, pick(rng, {N.skull, N.horned, N.ribcage, N.spine, N.bones,
				N.fragments}), rint(rng, 0, 3))
		end
	end

	-- 2-4 nodes of stone and mossy cobble: two side by side, maybe a third,
	-- maybe one on top.
	function BUILD.boulder(b, rng)
		local function mat() return rint(rng, 0, 9) < 6 and N.stone or N.mossy end
		local dz = rint(rng, 0, 1)
		local core = b.run(true)
		b.put(0, 0, 0, mat())
		b.put(1 - dz, 0, dz, mat())
		if rint(rng, 0, 1) == 1 then
			b.run(false)
			b.put(1, 0, 1, mat())
		end
		if rint(rng, 0, 2) == 0 then
			b.run(false, core)
			b.put(0, 1, 0, mat())
		end
	end

	-- Cairn A (ruling 13): one or two rough courses, then the cap stones.
	function BUILD.cairn_blocks(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.course, rint(rng, 0, 3))
		local top = 1
		if rint(rng, 0, 1) == 1 then
			b.put(0, 1, 0, N.course, rint(rng, 0, 3))
			top = 2
		end
		b.put(0, top, 0, N.cap, rint(rng, 0, 3))
	end

	-- Cairn B (ruling 13): a base on the ground, a branch, a twig on top: a
	-- rough tapering column; sometimes a twig leaning on its foot.
	function BUILD.cairn_branches(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.cairn_base)
		b.put(0, 1, 0, N.cairn_branch)
		if rint(rng, 0, 1) == 1 then b.put(0, 2, 0, N.cairn_twig) end
		if rint(rng, 0, 1) == 1 then
			b.run(false)
			b.put(1, 0, 0, N.cairn_twig)
		end
	end

	-- Driftwood on the beach (the coordinator, 2026-10-19: the kit places
	-- it): a bleached log (drops wood), now and then the forked branch
	-- (drops sticks) beside it.
	function BUILD.driftwood(b, rng)
		b.run(true)
		b.put(0, 0, 0, N.drift_log, rint(rng, 0, 3))
		if rint(rng, 0, 2) == 0 then
			b.run(false)
			b.put(1, 0, 0, N.drift_fork, rint(rng, 0, 3))
		end
	end

	-- A pine without needles, its top broken off at 60 % of its height,
	-- snow on its logs: the generator's pine of `seed` (tree_templates.lua),
	-- its leaves left out and every cell above the break; stem, limbs and
	-- snow are tree cells, the roots runs.
	local function dead_pine(b, seed)
		local cells, tree = trees.tree("pine", seed)
		local cut = math.floor(tree.height * 6 / 10)
		local kept, wood = {}, {}
		for index = 1, #cells do
			local c = cells[index]
			if c.flag ~= trees.LEAF and c.y <= cut and not c.root then
				kept[#kept + 1] = c
				wood[c.x .. "," .. c.y .. "," .. c.z] = true
			end
		end
		for index = 1, #kept do
			local c = kept[index]
			b.main_cell(c.x, c.y, c.z, c.name, c.param2, c.flag)
		end
		for index = 1, #kept do
			local c = kept[index]
			if c.name == "default:pine_tree" and not wood[c.x .. "," .. (c.y + 1) .. "," .. c.z] then
				b.main_cell(c.x, c.y + 1, c.z, N.snow, 0, trees.LEAF)
			end
		end
		local by_pos = {}
		for index = 1, #cells do
			local c = cells[index]
			if c.root then by_pos[c.x .. "," .. c.y .. "," .. c.z] = c end
		end
		local run_of = {}
		for index = 1, #tree.root_runs do
			local r = tree.root_runs[index]
			run_of[index] = b.run(false, r.parent > 0 and run_of[r.parent] or 0)
			for k = r.first, r.last do
				local root = tree.roots[k]
				local c = by_pos[root[1] .. "," .. root[2] .. "," .. root[3]]
				if c then b.put(c.x, c.y, c.z, c.name, c.param2) end
			end
		end
	end

	-- ------------------------------------------------------------ species
	--
	-- In a fixed order: the key a row's `kitgen:<key>` names, the builder,
	-- the variants every world gets, and the builder's RNG salt.
	M.SPECIES = {
		{key = "graveyard", build = "graveyard", count = 16, salt = 5101},
		{key = "ruin_undead", build = "ruin_undead", count = 16, salt = 5102},
		{key = "ruin_arch", build = "ruin_arch", count = 8, salt = 5103},
		{key = "ruin_column", build = "ruin_column", count = 8, salt = 5104},
		{key = "ruin_corner", build = "ruin_corner", count = 8, salt = 5105},
		{key = "crypt", build = "crypt", count = 8, salt = 5106},
		{key = "gravewood_log", build = "gravewood_log", count = 8, salt = 5107},
		{key = "gravewood_stump", build = "gravewood_stump", count = 8, salt = 5108},
		{key = "grave_mound", build = "grave_mound", count = 8, salt = 5109},
		{key = "statue_undead", build = "statue_undead", count = 8, salt = 5110},
		{key = "obelisk", build = "obelisk", count = 8, salt = 5111},
		{key = "bones", build = "bones", count = 32, salt = 5112},
		{key = "boulder", build = "boulder", count = 16, salt = 5113},
		{key = "cairn_blocks", build = "cairn_blocks", count = 8, salt = 5114},
		{key = "cairn_branches", build = "cairn_branches", count = 8, salt = 5115},
		{key = "dead_pine", build = "dead_pine", count = 16, salt = 5116},
		{key = "ruin_elves", build = "ruin_elves", count = 16, salt = 5117},
		{key = "statue_elves", build = "statue_elves", count = 8, salt = 5118},
		{key = "silver_log", build = "silver_log", count = 8, salt = 5119},
		{key = "kapok_log", build = "kapok_log", count = 8, salt = 5120},
		{key = "driftwood", build = "driftwood", count = 8, salt = 5121},
	}
	M.BY_KEY = {}
	for index = 1, #M.SPECIES do M.BY_KEY[M.SPECIES[index].key] = M.SPECIES[index] end
	M.STEM, M.LIMB, M.LEAF = trees.STEM, trees.LIMB, trees.LEAF

	-- The total of variants every world builds.
	function M.total()
		local total = 0
		for index = 1, #M.SPECIES do total = total + M.SPECIES[index].count end
		return total
	end

	-- The `count` template seeds of a species for one world, as the trees'
	-- (tree_templates.lua `template_seeds`): `digest(k)` returns the raw
	-- SHA-256 of (world seed string, key, k).
	function M.template_seeds(key, digest)
		local row = M.BY_KEY[key]
		local seeds, taken, k = {}, {}, 0
		while #seeds < row.count do
			local a, b, c, d = string.byte(digest(k), 1, 4)
			local seed = (((a * 256 + b) * 256 + c) * 256 + d) % MODULUS - 1
			if not taken[seed] then
				taken[seed] = true
				seeds[#seeds + 1] = seed
			end
			k = k + 1
		end
		return seeds
	end

	-- One variant of a species, packed as tree_templates.lua packs a tree:
	--   count, x, y, z, name, param2, flag      the cells outside runs
	--   runs = {{first, last, parent, required}} over
	--   root_count, rx, ry, rz, rname, rparam2  the run cells
	--   min_x .. max_z                           the bounds of everything
	--   bytes                                    the canonical bytes (digest)
	-- Runs without a cell are dropped (their children follow their parent).
	function M.variant(key, seed)
		local row = M.BY_KEY[key]
		if not row then error("kit templates: unknown kit " .. tostring(key), 0) end
		local b = new_builder()
		if row.build == "dead_pine" then
			dead_pine(b, seed)
		else
			BUILD[row.build](b, new_rng(seed, row.salt))
		end
		local v = {species = key, seed = seed, count = 0, x = {}, y = {}, z = {},
			name = {}, param2 = {}, flag = {}, root_count = 0, rx = {}, ry = {}, rz = {},
			rname = {}, rparam2 = {}, runs = {}}
		local min_x, max_x, min_y, max_y, min_z, max_z = 0, 0, 0, 0, 0, 0
		local function bound(x, y, z)
			if x < min_x then min_x = x end
			if x > max_x then max_x = x end
			if y < min_y then min_y = y end
			if y > max_y then max_y = y end
			if z < min_z then min_z = z end
			if z > max_z then max_z = z end
		end
		local parts = {"grug_kit_template_v1", key, string.format("%.0f", seed)}
		for index = 1, #b.main do
			local c = b.main[index]
			local n = v.count + 1
			v.count = n
			v.x[n], v.y[n], v.z[n], v.name[n], v.param2[n], v.flag[n] =
				c[1], c[2], c[3], c[4], c[5], c[6]
			bound(c[1], c[2], c[3])
			parts[#parts + 1] = table.concat(c, ",")
		end
		parts[#parts + 1] = "runs"
		local packed = {}
		for index = 1, #b.runs do
			local run = b.runs[index]
			local parent = run.parent > 0 and packed[run.parent] or 0
			if #run.cells > 0 and (run.parent == 0 or packed[run.parent]) then
				local first = v.root_count + 1
				for k = 1, #run.cells do
					local c = run.cells[k]
					local n = v.root_count + 1
					v.root_count = n
					v.rx[n], v.ry[n], v.rz[n], v.rname[n], v.rparam2[n] =
						c[1], c[2], c[3], c[4], c[5]
					bound(c[1], c[2], c[3])
				end
				v.runs[#v.runs + 1] = {first = first, last = v.root_count, parent = parent,
					required = run.required}
				packed[index] = #v.runs
				parts[#parts + 1] = "run," .. parent .. "," .. (run.required and 1 or 0)
				for k = 1, #run.cells do parts[#parts + 1] = table.concat(run.cells[k], ",") end
			end
		end
		v.min_x, v.max_x, v.min_y, v.max_y, v.min_z, v.max_z =
			min_x, max_x, min_y, max_y, min_z, max_z
		v.bytes = table.concat(parts, "\n")
		return v
	end

	-- Every node name a species may place, sorted (from many sample
	-- variants; the lane fixture holds them to the production rows).
	function M.names(key)
		local seen, list = {}, {}
		for seed = 1, 64 do
			local v = M.variant(key, seed)
			for index = 1, v.count do seen[v.name[index]] = true end
			for index = 1, v.root_count do seen[v.rname[index]] = true end
		end
		for name in pairs(seen) do list[#list + 1] = name end
		table.sort(list)
		return list
	end

	M.rotate = trees.rotate
	M.rotated_bounds = trees.rotated_bounds
	return M
end
