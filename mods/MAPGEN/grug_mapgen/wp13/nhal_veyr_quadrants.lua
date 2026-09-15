-- Where Nhal Veyr's four districts stand, and which of them stands where.
--
-- The capitals contract (section 2.1) says the four district roles are
-- "assigned to quadrants by a deterministic permutation from the world seed
-- through the existing R6 hash". This file is both halves of that sentence for
-- the undead capital: the four quadrants' LOT GRIDS, and the PERMUTATION that
-- hands one grid to one district. It is `highcourt_quadrants.lua`'s shape with
-- this capital's own measured grids and its own hash prefix; the pilot's file
-- is frozen against its 52 shipped blueprints and is not edited here.
--
--
-- 1. THE GROUND, MEASURED FIRST
--
-- `tools/wp13/run_capital.sh <out> nhal_veyr terrain <seed>` samples the whole
-- 512 envelope and its collar before any composition exists, on both gate
-- seeds. What it says about the raised necropolis, and what the grids below
-- are derived from:
--
--   * NOT ONE COLUMN of the envelope is water, on either seed. The undead
--     capital stands on the Kragmar blight; the two rivers that made
--     Highcourt's four grids differ from one another are not here.
--   * The civic core is flat at the fitted height out to +-48 and the rest
--     of the envelope is terraced in THREE-node steps (the contract's step
--     for the undead), falling and rising some thirty nodes across it.
--   * The four candidate wall lines never step more than 3 along their own
--     course, and the widest spread along one line is 52 nodes
--     (seed 531802985935182545, east). `wp13/wall.lua`'s one-Lipschitz rule
--     is written for exactly that.
--
-- WHY THE FOUR GRIDS ARE STILL NOT ONE GRID TURNED FOUR TIMES. With no water
-- in the envelope the obvious implementation nearly works, and the table below
-- is what "nearly" costs. Of the 36 district lots, 32 are the authored layout
-- rotated into their quadrant and slid at most twelve nodes -- three of the
-- four grids carry a two-node shift in z that the whole-grid search found, and
-- five lots slid a further four to twelve off a riser -- and FOUR had to move
-- 38 to 42 nodes, because the ground under them falls or rises more than the
-- skirt and the clear allow whatever the grid does. Of the 16 fill lots, ten
-- moved, four of them the full width of a lot.
--
-- The terrain is radially TERRACED but not radially symmetric: the blight
-- north of the anchor climbs where the ground east of it drops, so the same
-- authored position is flat in one quarter and on a riser in the next.
--
--
-- 2. A LOT IS A LOT, WHICHEVER DISTRICT STANDS ON IT
--
-- The permutation only means something if any district may take any quadrant,
-- so a lot is held to ONE envelope and every plot of every district is held to
-- the same one: footprint inside +-13 of the lot, two nodes of dry margin
-- round that, perimeter fall at most the foundation skirt (6) and rise at most
-- 6 under an airspace clear of at least 8 -- on BOTH gate seeds. That is two
-- nodes tighter than the contract's +-15 plot volume, and the two nodes are
-- exactly what buys the interchange.
--
--
-- 3. THE QUADRANTS ARE THE DIAGONALS
--
-- The four avenues leave the core on the axes, so the four QUARTERS they cut
-- the envelope into are the diagonals: south-east, north-east, north-west,
-- south-west, in that order, which is also the order a quarter turn walks
-- them ((x, z) -> (-z, x)).
--
--
-- 4. THE HASH
--
-- `r6_hash.lua` refuses a domain that is not on its own closed list, and that
-- list is pinned by the WP40 R6 micro-KAT. What this file uses instead is R6's
-- CONSTRUCTION with a WP13 prefix of its own -- the same length-framed
-- canonical fields, the same SHA-256, the same two-word modular reduction that
-- is exact in a double -- exactly as Highcourt's does, with `nhal_veyr` in the
-- prefix so the two capitals' permutations are independent draws rather than
-- the same draw twice.
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
	-- nhal_veyr_plots.lua` re-derives the grids below against exactly these.
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
	-- them. Derived and verified by `tools/wp13/nhal_veyr_plots.lua` against
	-- the terrain of seeds 531802985935182545 and 8675309; the shift each grid
	-- needed and the lots that had to slide further are the table in section 4
	-- of docs/research/wp13-nhal_veyr.md.
	--
	-- Three of the four grids carry a two-node shift in z. That is not taste:
	-- the whole-grid translation is searched first and the shift that leaves
	-- the most lots on the authored layout wins, and on this terrain two nodes
	-- north takes the north-east, north-west and south-west grids off a
	-- terrace riser that would otherwise have cost each of them a lot.
	--
	-- THE FOUR THAT MOVED FAR, and what was under them, measured on both gate
	-- seeds over the lot's own footprint plus its two-node margin:
	--
	--   * `southeast` lot 6, (160, -116) -> (198, -116): a fall of 7 against a
	--     skirt of 6;
	--   * `northeast` lot 6, (116, 162) -> (116, 202): a rise of 8 against a
	--     clear of 8, with nothing to spare;
	--   * `northeast` lot 8, (160, 118) -> (198, 118): a fall of 9;
	--   * `southwest` lot 9, (-160, -158) -> (-172, -158): a fall of 6, which
	--     is the skirt exactly and is the one case where this table is
	--     TIGHTER than the rule -- `nhal_veyr_plots.lua` derives against a
	--     fall of 5, because its input samples every fourth column and can
	--     understate a relief by a node.
	M.LOTS = {
		southeast = {
			{x = 72, z = -72}, {x = 116, z = -72}, {x = 160, z = -72},
			{x = 72, z = -116}, {x = 116, z = -116}, {x = 198, z = -116},
			{x = 72, z = -160}, {x = 116, z = -160}, {x = 160, z = -160},
		},
		northeast = {
			{x = 72, z = 74}, {x = 72, z = 118}, {x = 72, z = 162},
			{x = 116, z = 72}, {x = 116, z = 118}, {x = 116, z = 202},
			{x = 160, z = 74}, {x = 198, z = 118}, {x = 160, z = 162},
		},
		northwest = {
			{x = -72, z = 74}, {x = -116, z = 74}, {x = -160, z = 74},
			{x = -72, z = 118}, {x = -116, z = 118}, {x = -160, z = 118},
			{x = -72, z = 162}, {x = -116, z = 162}, {x = -158, z = 162},
		},
		southwest = {
			{x = -76, z = -70}, {x = -68, z = -116}, {x = -72, z = -160},
			{x = -116, z = -70}, {x = -116, z = -114}, {x = -116, z = -158},
			{x = -160, z = -70}, {x = -160, z = -114}, {x = -172, z = -158},
		},
	}

	----------------------------------------------------------------------
	-- THE FILL LOTS
	----------------------------------------------------------------------
	--
	-- The user's playtest-round-3 ruling on the pilot capital -- a fill grade
	-- of "loose, with fields and gardens", not dense, but lived in, with open
	-- ground still visible between the pieces -- is the standard every wave-2
	-- capital is built to (the lane brief's Highcourt table). A dressing is
	-- therefore a PLOT like any other: terrain-relative, with its own
	-- reference column, its own foundation skirt and its own cleared airspace,
	-- because a grave field laid at the core's height across a three-node
	-- terrace is a field with a step through it.
	--
	-- WHAT IS DIFFERENT FROM A DISTRICT LOT, and why:
	--
	--   * a fill lot carries its OWN REACH, because the four fill slots are
	--     four deliberately different sizes and a capital of nothing but
	--     23-node squares is as repetitive as a capital of nothing but houses;
	--   * the LANE is 4 and not 8: eight nodes is what a street between two
	--     building lots needs, and four is what keeps "loose" visible;
	--   * the rise limit used to DERIVE them is 5 rather than 6, because a
	--     yard plot's airspace clear is the builder's floor of 8 and nothing
	--     more -- a building plot clears its own roof and has 9 to 13.
	M.FILL = {margin = 2, fall = 6, rise = 6, clear = 8, lane = 4,
		quarter = 32}

	-- The authored fill layout, in the south-east quadrant's frame, with the
	-- reach of each slot:
	--
	--   1. the east outer band, between the lot grid and the curtain;
	--   2. the south outer band;
	--   3. the outer corner of the quarter;
	--   4. the small close inside the quarter.
	M.FILL_AUTHORED = {
		{x = 208, z = -104, reach = 11},
		{x = 104, z = -208, reach = 11},
		{x = 200, z = -200, reach = 8},
		{x = 94, z = -160, reach = 5},
	}

	-- The four fill lots of each quadrant, in the order a district's fill
	-- plots take them. Derived and verified by `tools/wp13/nhal_veyr_plots.lua`
	-- (`--derive-fill` reproduces this table).
	--
	-- SLOT 4 IS THE ONE THAT MOVED EVERYWHERE, and the reason is arithmetic
	-- rather than ground: a 5-reach close with two nodes of margin is 15 wide,
	-- the gap between two 31-wide lot footprints 44 apart is 14, and a four-node
	-- lane either side needs 23. The authored close cannot stand between two
	-- columns of this grid on any world, so in three quadrants it takes the
	-- nearest open ground inside its own quarter and in the north-east it sits
	-- in the hole lot 8 left when it slid outward.
	M.FILL_LOTS = {
		southeast = {
			{x = 208, z = -82}, {x = 104, z = -210},
			{x = 200, z = -200}, {x = 78, z = -188},
		},
		northeast = {
			{x = 82, z = 208}, {x = 208, z = 84},
			{x = 200, z = 200}, {x = 160, z = 102},
		},
		northwest = {
			{x = -208, z = 104}, {x = -106, z = 208},
			{x = -202, z = 200}, {x = -80, z = 190},
		},
		southwest = {
			{x = -104, z = -208}, {x = -208, z = -104},
			{x = -200, z = -200}, {x = -188, z = -78},
		},
	}

	-- THE DISTRICT LANES.
	--
	-- A district is a place with streets in it, and the only streets a capital
	-- has of its own are the four avenues on the axes and the ring at 96 -- a
	-- district sits outside both. A lane is an ordinary `avenue.lua` run, so it
	-- costs no new code: it is paved at the surface it finds, it climbs a
	-- terrace the same way, it carries the same lamp rhythm, and the
	-- successor's cross-run arbitration already knows what to do where it meets
	-- the ring or an avenue.
	--
	-- Every lane runs down the middle of the gap between the outer two columns
	-- or rows of lots and STARTS ON AN AVENUE, so a district is reached from
	-- the city and not merely near it. They belong to the QUADRANT, not to the
	-- district standing in it: every quadrant is always occupied by one of the
	-- four districts, so the lanes are the same on every world and the overlay's
	-- identity stays independent of the seed.
	--
	-- Unlike Highcourt's, all four quadrants carry the crossing PAIR: with no
	-- river in this envelope every grid keeps the authored 44-node spacing, so
	-- the gap at 138 exists in all four.
	M.LANES = {
		southeast = {
			{id = "lane_southeast_spine", axis = "z", at = 138,
				from = -186, to = 0},
			{id = "lane_southeast_cross", axis = "x", at = -138,
				from = 0, to = 186},
		},
		northeast = {
			{id = "lane_northeast_spine", axis = "x", at = 138,
				from = 0, to = 186},
			{id = "lane_northeast_cross", axis = "z", at = 138,
				from = 0, to = 186},
		},
		northwest = {
			{id = "lane_northwest_spine", axis = "z", at = -138,
				from = 0, to = 186},
			{id = "lane_northwest_cross", axis = "x", at = 138,
				from = -186, to = 0},
		},
		southwest = {
			{id = "lane_southwest_spine", axis = "x", at = -138,
				from = -186, to = 0},
			{id = "lane_southwest_cross", axis = "z", at = -138,
				from = -186, to = 0},
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

	local PREFIX = "grug_wp13_nhal_veyr_district_quadrant_v1"
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
			error("wp13 nhal veyr quadrants: canonical field differs", 0)
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
			error("wp13 nhal veyr quadrants: permutation index differs", 0)
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
			error("wp13 nhal veyr quadrants: full world seed differs", 0)
		end
		if type(raw_sha256) ~= "function" then
			error("wp13 nhal veyr quadrants: SHA-256 seam differs", 0)
		end
		local digest = raw_sha256(frame(PREFIX) .. frame(full_seed) ..
			frame(#M.ROLES))
		if type(digest) ~= "string" or #digest ~= 32 then
			error("wp13 nhal veyr quadrants: SHA-256 result differs", 0)
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
			error("wp13 nhal veyr quadrants: the permutation is not " ..
				#M.ROLES .. " long", 0)
		end
		local seen = {}
		for index = 1, #M.ROLES do
			local value = permutation[index]
			if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or
					value > #M.ROLES or seen[value] then
				error("wp13 nhal veyr quadrants: the permutation is not a " ..
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
				error("wp13 nhal veyr quadrants: permutation differs", 0)
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
