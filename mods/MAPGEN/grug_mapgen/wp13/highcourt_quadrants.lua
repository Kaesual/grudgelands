-- Where Highcourt's four districts stand, and which of them stands where.
--
-- The capitals contract (section 2.1) says the four district roles are
-- "assigned to quadrants by a deterministic permutation from the world seed
-- through the existing R6 hash". This file is both halves of that sentence:
-- the four quadrants' LOT GRIDS, and the PERMUTATION that hands one grid to
-- one district.
--
--
-- 1. WHY THE FOUR GRIDS ARE NOT ONE GRID TURNED FOUR TIMES
--
-- The obvious implementation is one authored layout rotated by a quarter turn
-- per quadrant. It was measured against the real terrain of both gate seeds
-- and it does not exist: WP40 runs two rivers through Highcourt's 512
-- envelope -- the capital of the contract's own "river plateau" line -- and
-- they meet north of the core on a diagonal. The set of positions that are
-- dry, inside the foundation skirt and under the plot's own airspace in ALL
-- FOUR rotations at once is a handful of columns at the envelope edge, nine
-- of which cannot be found with lanes between them. A rotating layout would
-- have had to put a building in a river to keep its shape.
--
-- So each quadrant carries its OWN nine lots, and the four grids are what the
-- same authored 3 x 3 layout becomes when it is rotated into that quadrant
-- and then allowed to slide to the nearest ground that will carry it. Three
-- of the four grids are the authored layout exactly, translated; the
-- south-west, where both rivers run, moved four of its nine by up to 32
-- nodes. `tools/wp13/highcourt_plots.lua` is the predicate that derives and
-- re-checks every one of them, and section 4 of
-- docs/research/wp13-highcourt-districts.md is the measurement.
--
--
-- 2. A LOT IS A LOT, WHICHEVER DISTRICT STANDS ON IT
--
-- The permutation only means something if any district may take any quadrant,
-- so a lot is held to ONE envelope and every plot of every district is held
-- to the same one: footprint inside +-13 of the lot, two nodes of dry margin
-- round that, perimeter fall at most the foundation skirt (6) and rise at
-- most 6 under an airspace clear of at least 8 -- on BOTH gate seeds. That is
-- two nodes tighter than the contract's +-15 plot volume, and the two nodes
-- are exactly what buys the interchange.
--
--
-- 3. THE QUADRANTS ARE THE DIAGONALS
--
-- The four avenues leave the core on the axes, so the four QUARTERS they cut
-- the envelope into are the diagonals: south-east, north-east, north-west,
-- south-west, in that order, which is also the order a quarter turn walks
-- them ((x, z) -> (-z, x)). A district therefore sits BETWEEN two avenues
-- with the ring street's corner running through it, which is what "along its
-- avenue and the ring street" means once the avenues are on the axes.
--
--
-- 4. THE HASH
--
-- `r6_hash.lua` refuses a domain that is not on its own closed list, and that
-- list is pinned by the WP40 R6 micro-KAT's `domain_population` row -- adding
-- a domain to it would move a frozen WP40 digest for a WP13 reason. What this
-- file uses instead is R6's CONSTRUCTION with a WP13 prefix of its own: the
-- same length-framed canonical fields, the same SHA-256, the same two-word
-- modular reduction that is exact in a double. The seed reaches it as the
-- engine's own `seed` mapgen setting, so main and emerge agree by
-- construction, and the result is decoded as a factorial-base index into the
-- 24 permutations of four.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- Turns 0..3, in quarter-turn order: (x, z) -> (-z, x).
	M.QUADRANTS = {"southeast", "northeast", "northwest", "southwest"}

	-- The district roles, in authored order. The permutation maps this order
	-- onto `M.QUADRANTS`.
	M.ROLES = {"market_professions", "martial_garrison", "lore_spiritual",
		"residential_cultural"}

	-- The envelope every lot is held to (section 2). `tools/wp13/
	-- highcourt_plots.lua` re-derives the grids below against exactly these.
	M.LOT = {reach = 13, margin = 2, fall = 6, rise = 6, clear = 8,
		lane = 8, quarter = 32}

	-- The authored layout, in the south-east quadrant's frame: three rows of
	-- three, 44 nodes apart, the near row along the east avenue and the near
	-- column beside the core, with the ring street's south-east corner
	-- passing between lots 1/2/4/5. Every other quadrant's grid is this one
	-- rotated and then slid onto ground that carries it.
	M.AUTHORED = {
		{x = 72, z = -72}, {x = 116, z = -72}, {x = 160, z = -72},
		{x = 72, z = -116}, {x = 116, z = -116}, {x = 160, z = -116},
		{x = 72, z = -160}, {x = 116, z = -160}, {x = 160, z = -160},
	}

	-- The nine lots of each quadrant, in the order a district's plots take
	-- them. Derived and verified by `tools/wp13/highcourt_plots.lua` against
	-- the terrain of seeds 531802985935182545 and 8675309; the shift each
	-- grid needed and the plots that had to slide further are the table in
	-- section 4 of the research note.
	--
	-- THREE OF THEM MOVED WITH THE TERRACE STEP BANDS (2026-09-15, WP13 round
	-- 3): the band turns every terrace riser into one-block steps, which lifts
	-- about one Highcourt column in nine by a node, and three lots then stood
	-- one node past their skirt or their roof. `highcourt_plots.lua --repair`
	-- moved exactly those three to the nearest legal position and left the
	-- other thirty-three where they were -- northeast 9 by 4 nodes, northwest 8
	-- by 8, south-west 2 by 4.
	M.LOTS = {
		southeast = {
			{x = 72, z = -72}, {x = 116, z = -72}, {x = 160, z = -72},
			{x = 72, z = -116}, {x = 116, z = -116}, {x = 160, z = -116},
			{x = 72, z = -160}, {x = 116, z = -160}, {x = 160, z = -160},
		},
		northeast = {
			{x = 132, z = 108}, {x = 132, z = 152}, {x = 132, z = 196},
			{x = 176, z = 108}, {x = 176, z = 152}, {x = 176, z = 196},
			{x = 220, z = 108}, {x = 220, z = 152}, {x = 216, z = 196},
		},
		northwest = {
			{x = -132, z = 80}, {x = -176, z = 80}, {x = -220, z = 80},
			{x = -132, z = 124}, {x = -176, z = 124}, {x = -220, z = 124},
			{x = -132, z = 168}, {x = -180, z = 164}, {x = -220, z = 168},
		},
		southwest = {
			{x = -48, z = -76}, {x = -48, z = -136}, {x = -48, z = -172},
			{x = -84, z = -116}, {x = -84, z = -152}, {x = -84, z = -188},
			{x = -120, z = -84}, {x = -128, z = -128}, {x = -120, z = -164},
		},
	}

	-- THE DISTRICT LANES.
	--
	-- The first render of the four districts showed nine buildings standing in
	-- a meadow: every plot had its own kerbed pad and there was nothing
	-- between them but grass, because the only streets the capital had were
	-- the four avenues on the axes and the ring at 96, and a district sits
	-- outside both. A district is a place with streets in it.
	--
	-- A lane is an ordinary `avenue.lua` run, so it costs no new code: it is
	-- paved at the surface it finds, it climbs a terrace the same way, it
	-- carries the same lamp rhythm, and the successor's cross-run arbitration
	-- already knows what to do where it meets the ring or an avenue.
	--
	-- Every lane runs down the middle of a gap between two rows or columns of
	-- lots and STARTS ON AN AVENUE, so a district is reached from the city and
	-- not merely near it. They belong to the QUADRANT, not to the district
	-- standing in it: every quadrant is always occupied by one of the four
	-- districts, so the lanes are the same on every world and the avenue
	-- overlay's identity stays independent of the seed.
	--
	-- The south-west has ONE lane where the others have a crossing pair: both
	-- rivers run through that quadrant, its nine lots are the only staggered
	-- grid of the four, and there is no second gap wide enough to carry a
	-- road between them. Its outer column is served by the ring street's west
	-- side instead.
	M.LANES = {
		southeast = {
			{id = "lane_southeast_spine", axis = "z", at = 138,
				from = -186, to = 0},
			{id = "lane_southeast_cross", axis = "x", at = -138,
				from = 0, to = 186},
		},
		northeast = {
			{id = "lane_northeast_spine", axis = "z", at = 198,
				from = 0, to = 222},
			{id = "lane_northeast_cross", axis = "x", at = 174,
				from = 0, to = 246},
		},
		northwest = {
			{id = "lane_northwest_spine", axis = "z", at = -198,
				from = 0, to = 194},
			{id = "lane_northwest_cross", axis = "x", at = 146,
				from = -246, to = 0},
		},
		southwest = {
			{id = "lane_southwest_spine", axis = "z", at = -66,
				from = -200, to = 0},
		},
	}

	-- Every lane, in quadrant order then authored order. This is the list the
	-- capital source appends to the avenues and the ring, and the list the
	-- KAT and the plot predicate hold the lots clear of.
	function M.lane_runs()
		local runs = {}
		for index = 1, #M.QUADRANTS do
			local lanes = M.LANES[M.QUADRANTS[index]]
			for lane = 1, #lanes do runs[#runs + 1] = lanes[lane] end
		end
		return runs
	end

	-- A quarter turn, and the quadrant a point in the south-east frame lands
	-- in after `turns` of them.
	function M.rotate(x, z, turns)
		for _ = 1, (turns % 4) do
			x, z = -z, x
		end
		return x, z
	end

	----------------------------------------------------------------------
	-- The hash (section 4)
	----------------------------------------------------------------------

	local PREFIX = "grug_wp13_highcourt_district_quadrant_v1"
	local UINT32 = 4294967296

	local function integer_ascii(value)
		if value == 0 then return "0" end
		return string.format("%.0f", value)
	end

	-- R6's own framing: every field is its own byte length, a colon and the
	-- bytes, so no two field lists can collide.
	local function frame(value)
		local bytes = (type(value) == "number") and integer_ascii(value) or value
		if type(bytes) ~= "string" then
			error("wp13 highcourt quadrants: canonical field differs", 0)
		end
		return integer_ascii(#bytes) .. ":" .. bytes
	end

	-- The first two 32-bit words of a raw digest, reduced modulo a
	-- denominator without ever leaving the exact integer range of a double:
	-- `UINT32 % denominator` first, then one multiply of two values that are
	-- both smaller than the denominator.
	local function reduce(digest, denominator)
		local hi, lo = 0, 0
		for byte = 1, 4 do hi = hi * 256 + string.byte(digest, byte) end
		for byte = 5, 8 do lo = lo * 256 + string.byte(digest, byte) end
		local power = UINT32 % denominator
		return ((hi % denominator) * power + (lo % denominator)) % denominator
	end

	local FACTORIAL = {[0] = 1, 1, 2, 6, 24}

	-- Index 0..23 -> one of the 24 permutations of 1..4, factorial base.
	function M.permutation_of_index(index)
		if type(index) ~= "number" or index % 1 ~= 0 or index < 0 or
				index > 23 then
			error("wp13 highcourt quadrants: permutation index differs", 0)
		end
		local pool = {1, 2, 3, 4}
		local result, rest = {}, index
		for remaining = 4, 1, -1 do
			local block = FACTORIAL[remaining - 1]
			local pick = math.floor(rest / block) + 1
			rest = rest - (pick - 1) * block
			result[#result + 1] = table.remove(pool, pick)
		end
		return result
	end

	-- The permutation this world's seed asks for: role index -> quadrant
	-- index. `full_seed` is the engine's own `seed` mapgen setting as the
	-- string it publishes it as, and `raw_sha256` returns 32 raw bytes.
	function M.permutation(full_seed, raw_sha256)
		if type(full_seed) ~= "string" or full_seed == "" or
				not full_seed:match("^%-?%d+$") then
			error("wp13 highcourt quadrants: full world seed differs", 0)
		end
		if type(raw_sha256) ~= "function" then
			error("wp13 highcourt quadrants: SHA-256 seam differs", 0)
		end
		local digest = raw_sha256(frame(PREFIX) .. frame(full_seed) ..
			frame(#M.ROLES))
		if type(digest) ~= "string" or #digest ~= 32 then
			error("wp13 highcourt quadrants: SHA-256 result differs", 0)
		end
		return M.permutation_of_index(reduce(digest, FACTORIAL[4]))
	end

	-- The canonical assignment, used where no world exists: the roles take
	-- the quadrants in authored order. Every engine-free tool and fixture
	-- sees this one, and the KAT checks the seeded permutations beside it.
	function M.canonical()
		return {1, 2, 3, 4}
	end

	-- Resolve role -> quadrant name. `options.full_seed` and
	-- `options.raw_sha256` are the explicit seam; with neither, and with no
	-- engine to ask, the canonical assignment stands.
	-- A permutation is a bijection of 1..n onto itself, and an external one is
	-- not trusted to be: two roles mapped to one quadrant would put two
	-- districts on one set of lots and leave a quarter of the capital empty,
	-- which is a wrong CITY rather than an error anything downstream would
	-- catch. `permutation_of_index` produces one by construction; this is for
	-- everything that does not come from it.
	function M.check_permutation(permutation)
		if type(permutation) ~= "table" or #permutation ~= #M.ROLES then
			error("wp13 highcourt quadrants: the permutation is not " ..
				#M.ROLES .. " long", 0)
		end
		local seen = {}
		for index = 1, #M.ROLES do
			local value = permutation[index]
			if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or
					value > #M.ROLES or seen[value] then
				error("wp13 highcourt quadrants: the permutation is not a " ..
					"bijection at position " .. index, 0)
			end
			seen[value] = true
		end
		return permutation
	end

	function M.assign(options)
		options = options or {}
		local permutation
		if options.permutation then
			permutation = M.check_permutation(options.permutation)
		elseif options.full_seed and options.raw_sha256 then
			permutation = M.permutation(options.full_seed, options.raw_sha256)
		else
			permutation = M.canonical()
		end
		local assignment = {}
		for index = 1, #M.ROLES do
			local quadrant = M.QUADRANTS[permutation[index]]
			if type(quadrant) ~= "string" then
				error("wp13 highcourt quadrants: permutation differs", 0)
			end
			assignment[M.ROLES[index]] = {quadrant = quadrant,
				turns = permutation[index] - 1,
				lots = M.LOTS[quadrant]}
		end
		return assignment, permutation
	end

	return M
end

return loader
