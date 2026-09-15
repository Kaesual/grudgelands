-- Where Dur Brannoc's four districts stand, and which of them stands where.
--
-- The capitals contract (section 2.1) says the four district roles are
-- "assigned to quadrants by a deterministic permutation from the world seed
-- through the existing R6 hash". This file is both halves of that sentence for
-- the dwarf capital: the four quadrants' LOT GRIDS, and the PERMUTATION that
-- hands one grid to one district. `highcourt_quadrants.lua` is the same file
-- for the pilot capital and was read as the pattern; the grids and the hash
-- prefix are this capital's own and nothing is shared, because a lot grid is a
-- measurement of one world's terrain and not a design that travels.
--
--
-- 1. WHY THE FOUR GRIDS ARE NOT ONE GRID TURNED FOUR TIMES
--
-- Highcourt's answer was the two rivers in its envelope. Dur Brannoc has no
-- river at all -- nine seeds, zero wet columns anywhere in the 512 envelope
-- (docs/research/wp13-dur-brannoc.md section 3b) -- and its answer is the other
-- half of the same problem: the granite terrace steps FOUR nodes, the deepest
-- of the six races, and WP40 blends the flat civic core down to it over some
-- forty nodes, falling up to 44 while it does. The whole inner band is
-- therefore ground no lot can stand on, and what is left outside it is not the
-- same shape in the four quarters. Each quadrant carries its OWN nine lots, and
-- the four grids are what the same authored 3 x 3 layout becomes when it is
-- rotated into that quadrant and then allowed to slide to the nearest ground
-- that will carry it. `tools/wp13/capital_lots.lua` is the predicate that
-- derives and re-checks every one of them.
--
--
-- 2. A LOT IS A LOT, WHICHEVER DISTRICT STANDS ON IT
--
-- The permutation only means something if any district may take any quadrant,
-- so a lot is held to ONE envelope and every plot of every district is held to
-- the same one: footprint inside +-13 of the lot, two nodes of dry margin round
-- that, perimeter fall at most the foundation skirt (6) and rise at most 6
-- under an airspace clear of at least 8 -- on ALL NINE seeds of
-- `tools/wp13/capital_anchor_fixture.lua`, not on two. Wave 1 measured this
-- capital's nine plots on two seeds; the wave-1 review of Highcourt then found
-- a plot that was legal on two seeds and illegal on a third, which is why the
-- bar here is nine.
--
-- The +-13 is two nodes tighter than the contract's +-15 plot volume, and the
-- two nodes are exactly what buys the interchange.
--
--
-- 3. THE QUADRANTS ARE THE DIAGONALS
--
-- The four avenues leave the core on the axes, so the four QUARTERS they cut
-- the envelope into are the diagonals: south-east, north-east, north-west,
-- south-west, in that order, which is also the order a quarter turn walks them
-- ((x, z) -> (-z, x)). A district therefore sits BETWEEN two avenues with the
-- ring street's corner running through it.
--
--
-- 4. THE HASH
--
-- `r6_hash.lua` refuses a domain that is not on its own closed list, and that
-- list is pinned by the WP40 R6 micro-KAT's `domain_population` row -- adding a
-- domain to it would move a frozen WP40 digest for a WP13 reason. What this
-- file uses instead is R6's CONSTRUCTION with a WP13 prefix of its own: the
-- same length-framed canonical fields, the same SHA-256, the same two-word
-- modular reduction that is exact in a double. The PREFIX is Dur Brannoc's, so
-- the dwarf capital's permutation and Highcourt's are independent draws on the
-- same world seed and the two capitals do not lay their districts out in
-- lockstep.
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
	-- capital_lots.lua` re-derives the grids below against exactly these.
	M.LOT = {reach = 13, margin = 2, fall = 6, rise = 6, clear = 8,
		lane = 8, quarter = 32}

	-- The authored layout, in the south-east quadrant's frame: three rows of
	-- three, 44 nodes apart.
	--
	-- IT STANDS FURTHER OUT THAN HIGHCOURT'S (116/160/204 against 72/116/160)
	-- and that is the blend band of section 1, measured rather than chosen: on
	-- the user seed the ground under the east avenue is 149 at sixty nodes out
	-- and 105 at a hundred and four, a fall of 44 over 44 columns, and a
	-- reach-13 lot anywhere in it has a perimeter fall of 8 to 12 against a
	-- foundation skirt that reaches 6. The inner ring of a dwarf capital is a
	-- hillside, and the city stands above and below it rather than on it.
	M.AUTHORED = {
		{x = 116, z = -116}, {x = 160, z = -116}, {x = 204, z = -116},
		{x = 116, z = -160}, {x = 160, z = -160}, {x = 204, z = -160},
		{x = 116, z = -204}, {x = 160, z = -204}, {x = 204, z = -204},
	}

	-- The nine lots of each quadrant, in the order a district's plots take
	-- them. Derived and verified by `tools/wp13/capital_lots.lua` against the
	-- terrain of all nine seeds; `--derive` reproduces this table.
	M.LOTS = {
		southeast = {
			{x = 120, z = -120}, {x = 156, z = -112}, {x = 200, z = -112},
			{x = 112, z = -164}, {x = 156, z = -164}, {x = 200, z = -164},
			{x = 112, z = -212}, {x = 156, z = -208}, {x = 200, z = -208},
		},
		northeast = {
			{x = 116, z = 108}, {x = 120, z = 156}, {x = 116, z = 204},
			{x = 156, z = 112}, {x = 156, z = 156}, {x = 156, z = 200},
			{x = 204, z = 112}, {x = 204, z = 156}, {x = 204, z = 204},
		},
		northwest = {
			{x = -120, z = 72}, {x = -164, z = 72}, {x = -208, z = 72},
			{x = -120, z = 112}, {x = -164, z = 116}, {x = -208, z = 116},
			{x = -120, z = 156}, {x = -164, z = 160}, {x = -204, z = 160},
		},
		southwest = {
			{x = -116, z = -120}, {x = -116, z = -164}, {x = -116, z = -208},
			{x = -164, z = -120}, {x = -160, z = -164}, {x = -160, z = -208},
			{x = -204, z = -120}, {x = -204, z = -164}, {x = -204, z = -212},
		},
	}

	-- WHAT THE DERIVATION DECIDED, and the one thing in it worth reading twice.
	-- Three quadrants took the authored layout almost unchanged (worst move 4 to
	-- 8 nodes on a four-node grid); the NORTH-WEST slid 44 nodes towards the
	-- core, so its near row stands at z = 72 rather than at 116. That is the
	-- blend band again and it is not symmetric: on the north-west diagonal WP40
	-- brings the terraces up to meet the core pad more gently than it does on
	-- the other three, and a reach-13 lot at 72 there has a perimeter fall of 4
	-- and a rise of 5 on all nine worlds. The ranking prefers the smallest WORST
	-- move, then the smallest total, then the smallest shift, so the translation
	-- that needs no lot to walk further than four nodes wins over the one that
	-- keeps the authored radius. One quarter of this capital therefore starts
	-- closer to the citadel than the other three, which is what a city on
	-- unequal ground looks like.

	----------------------------------------------------------------------
	-- THE FILL LOTS
	----------------------------------------------------------------------
	--
	-- The round-3 playtest said a capital of 36 buildings in a 512 envelope is
	-- huge and empty, and the user's ruling is a fill grade of "loose, with
	-- fields and gardens". A dressing is therefore a PLOT like any other:
	-- terrain-relative, with its own reference column, its own foundation skirt
	-- and its own cleared airspace, because a mushroom bed laid at the core's
	-- height across a four-node terrace is a bed with a step through it.
	--
	-- WHAT IS DIFFERENT FROM A DISTRICT LOT: a fill lot carries its OWN REACH
	-- (the four slots are four deliberately different sizes -- two
	-- field-sized, one yard-sized, one strip-sized), and its LANE is 4 rather
	-- than 8, because a garden between two halls is four nodes of ground and
	-- four is also what keeps "loose" visible.
	--
	-- WHERE THEY STAND IS WHERE HIGHCOURT'S DO NOT, and the difference is the
	-- blend band again. Highcourt's fourth slot is a garden strip INSIDE the lot
	-- grid, in the gap between two columns of it; at Dur Brannoc there is no
	-- such gap to have. A reach-5 lot between two reach-13 lots needs
	-- 13 + 4 + 5 = 22 nodes of clearance on each side, which is 44 nodes of gap,
	-- and the grid's own spacing is 44 exactly -- the lot rectangles touch at
	-- the boundary and the predicate refuses it. Widening the grid is not
	-- available either: the outermost column already stands at 204 and the
	-- envelope ends at 235. So all four dwarf fill slots stand in the OUTER
	-- band and the outer corner, between the lot grid and the curtain wall,
	-- which is also where a dwarf city would put its ore heaps and its goat
	-- pens: outside the halls, inside the wall.
	M.FILL = {margin = 2, fall = 6, rise = 6, clear = 8, lane = 4,
		quarter = 32}

	-- The authored fill layout, in the south-east quadrant's frame, with the
	-- reach of each slot:
	--
	--   1. the east outer band, between the lot grid and the curtain;
	--   2. the south outer band, the same on the other axis;
	--   3. the outer corner of the quarter, a yard;
	--   4. a strip on the south outer band between 2 and 3.
	M.FILL_AUTHORED = {
		{x = 234, z = -116, reach = 11},
		{x = 116, z = -234, reach = 11},
		{x = 232, z = -232, reach = 8},
		{x = 182, z = -232, reach = 5},
	}

	-- The four fill lots of each quadrant, in the order a district's fill plots
	-- take them. Derived and verified by `tools/wp13/capital_lots.lua`
	-- (`--derive-fill` reproduces this table) against all nine seeds.
	M.FILL_LOTS = {
		southeast = {
			{x = 232, z = -116}, {x = 80, z = -232},
			{x = 228, z = -232}, {x = 162, z = -232},
		},
		northeast = {
			{x = 116, z = 234}, {x = 234, z = 116},
			{x = 232, z = 232}, {x = 232, z = 182},
		},
		northwest = {
			{x = -234, z = 148}, {x = -120, z = 232},
			{x = -232, z = 232}, {x = -184, z = 232},
		},
		southwest = {
			{x = -84, z = -208}, {x = -218, z = -88},
			{x = -232, z = -204}, {x = -228, z = -156},
		},
	}

	-- The fill derivation moved more than the lot derivation did (worst move 38
	-- against 8) and the reason is the order the two run in: the district lots
	-- are placed first and a fill lot has to find room BESIDE nine of them, on
	-- nine worlds, inside the same band. Two slots therefore ended up on the
	-- other axis from the one they were authored on -- the south-west's field
	-- belt is at (-84, -208) rather than out on the west band, and the
	-- north-west's is at (-120, 232) -- which is a dressing standing where its
	-- quarter has ground rather than where the drawing put it. Nothing reads the
	-- slot's compass direction; a roster says WHAT a dressing is and the slot
	-- says how big its lot is.

	-- THE DISTRICT LANES.
	--
	-- A district is a place with streets in it: the only roads a capital has of
	-- its own are the four avenues on the axes and the ring at 96, and a
	-- district sits outside both. A lane is an ordinary `avenue.lua` run, so it
	-- costs no new code -- it is paved at the surface it finds, it climbs a
	-- terrace the same way with one stair node per rise, it carries the same
	-- lamp rhythm, and the successor's cross-run arbitration already knows what
	-- to do where it meets the ring, an avenue or the curtain.
	--
	-- THE STAIR LANES OF THE CONTRACT'S SECTION 2.4 ARE THESE, and they are
	-- what makes the dwarf lanes different from Highcourt's: each quadrant's
	-- CROSS lane starts on an avenue at the core edge and runs out across the
	-- blend band, which falls 44 nodes in 44 columns, so it is a stair the whole
	-- way down. "Stair streets between terraces" is not a new generator; it is
	-- `avenue.lua`'s own terrace rule applied to a run that crosses a 44-node
	-- fall, and the render is what says whether it reads as one.
	--
	-- Every lane runs down the middle of a gap between two rows or columns of
	-- lots and STARTS ON AN AVENUE, so a district is reached from the city and
	-- not merely near it. They belong to the QUADRANT, not to the district
	-- standing in it: every quadrant is always occupied by one of the four
	-- districts, so the lanes are the same on every world and the overlay's
	-- identity stays independent of the seed.
	M.LANES = {
		southeast = {
			{id = "lane_southeast_spine", axis = "z", at = 138,
				from = -220, to = 0},
			{id = "lane_southeast_cross", axis = "x", at = -138,
				from = 0, to = 220},
		},
		northeast = {
			{id = "lane_northeast_spine", axis = "z", at = 138,
				from = 0, to = 220},
			{id = "lane_northeast_cross", axis = "x", at = 138,
				from = 0, to = 220},
		},
		northwest = {
			{id = "lane_northwest_spine", axis = "z", at = -138,
				from = 0, to = 220},
			{id = "lane_northwest_cross", axis = "x", at = 138,
				from = -220, to = 0},
		},
		southwest = {
			{id = "lane_southwest_spine", axis = "z", at = -138,
				from = -220, to = 0},
			{id = "lane_southwest_cross", axis = "x", at = -138,
				from = -220, to = 0},
		},
	}

	-- Every lane, in quadrant order then authored order. This is the list the
	-- capital source appends to the avenues and the ring, and the list the KAT
	-- and the lot predicate hold the lots clear of.
	function M.lane_runs()
		local runs = {}
		for index = 1, #M.QUADRANTS do
			local lanes = M.LANES[M.QUADRANTS[index]]
			for lane = 1, #lanes do runs[#runs + 1] = lanes[lane] end
		end
		return runs
	end

	-- A quarter turn, and the quadrant a point in the south-east frame lands in
	-- after `turns` of them.
	function M.rotate(x, z, turns)
		for _ = 1, (turns % 4) do
			x, z = -z, x
		end
		return x, z
	end

	----------------------------------------------------------------------
	-- The hash (section 4)
	----------------------------------------------------------------------

	local PREFIX = "grug_wp13_dur_brannoc_district_quadrant_v1"
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
			error("wp13 dur brannoc quadrants: canonical field differs", 0)
		end
		return integer_ascii(#bytes) .. ":" .. bytes
	end

	-- The first two 32-bit words of a raw digest, reduced modulo a denominator
	-- without ever leaving the exact integer range of a double.
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
			error("wp13 dur brannoc quadrants: permutation index differs", 0)
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

	-- The permutation this world's seed asks for: role index -> quadrant index.
	-- `full_seed` is the engine's own `seed` mapgen setting as the string it
	-- publishes it as, and `raw_sha256` returns 32 raw bytes.
	function M.permutation(full_seed, raw_sha256)
		if type(full_seed) ~= "string" or full_seed == "" or
				not full_seed:match("^%-?%d+$") then
			error("wp13 dur brannoc quadrants: full world seed differs", 0)
		end
		if type(raw_sha256) ~= "function" then
			error("wp13 dur brannoc quadrants: SHA-256 seam differs", 0)
		end
		local digest = raw_sha256(frame(PREFIX) .. frame(full_seed) ..
			frame(#M.ROLES))
		if type(digest) ~= "string" or #digest ~= 32 then
			error("wp13 dur brannoc quadrants: SHA-256 result differs", 0)
		end
		return M.permutation_of_index(reduce(digest, FACTORIAL[4]))
	end

	-- The canonical assignment, used where no world exists: the roles take the
	-- quadrants in authored order. Every engine-free tool and fixture sees this
	-- one, and the KAT checks the seeded permutations beside it.
	function M.canonical()
		return {1, 2, 3, 4}
	end

	-- A permutation is a bijection of 1..n onto itself, and an external one is
	-- not trusted to be: two roles mapped to one quadrant would put two
	-- districts on one set of lots and leave a quarter of the capital empty,
	-- which is a wrong CITY rather than an error anything downstream would
	-- catch.
	function M.check_permutation(permutation)
		if type(permutation) ~= "table" or #permutation ~= #M.ROLES then
			error("wp13 dur brannoc quadrants: the permutation is not " ..
				#M.ROLES .. " long", 0)
		end
		local seen = {}
		for index = 1, #M.ROLES do
			local value = permutation[index]
			if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or
					value > #M.ROLES or seen[value] then
				error("wp13 dur brannoc quadrants: the permutation is not a " ..
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
				error("wp13 dur brannoc quadrants: permutation differs", 0)
			end
			assignment[M.ROLES[index]] = {quadrant = quadrant,
				turns = permutation[index] - 1,
				lots = M.LOTS[quadrant],
				fill_lots = M.FILL_LOTS[quadrant]}
		end
		return assignment, permutation
	end

	return M
end

return loader
