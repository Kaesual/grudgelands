-- Gor Drazhak's city plan: the streets, the lots, and which district stands
-- in which quarter of the mesa.
--
-- The capitals contract (section 2.1) says the four district roles are
-- "assigned to quadrants by a deterministic permutation from the world seed
-- through the existing R6 hash". This file is both halves of that sentence for
-- the orc capital, plus the run geometry the overlay is built from, because
-- everything here is the same question -- where a thing stands in the 512
-- envelope -- and `tools/wp13/gor_drazhak_lots.lua` has to read the streets
-- and the lots together.
--
--
-- 1. ONE GRID, ROTATED FOUR TIMES -- WHICH HIGHCOURT COULD NOT DO
--
-- The pilot capital carries four separately authored lot grids, and its own
-- module says why: WP40 runs two rivers through Highcourt's envelope and the
-- set of positions that are dry in all four rotations is a handful of columns,
-- so its south-west quadrant had to slide four of its nine lots by up to 32
-- nodes.
--
-- Gor Drazhak's envelope has NO WATER IN IT. That is measured and not assumed:
-- `run_capital.sh <out> gor_drazhak terrain <seed>` samples the pure final
-- height and the water class of every fourth column of the whole 576-node
-- envelope, and on the two gate seeds and the user's world seed the count of
-- wet columns is zero, everywhere, including all four rampart lines. A mesa
-- shelf is dry ground. So the obvious implementation -- ONE authored layout
-- turned a quarter at a time -- is available here, and it is what this file
-- uses: `M.LOTS` and `M.FILL_LOTS` are DERIVED from `M.AUTHORED` and
-- `M.FILL_AUTHORED` by `M.rotate` at load, not typed out per quadrant. There
-- is nothing to remember and nothing to drift, and the verification tool
-- re-measures the derived table rather than a copy of it.
--
--
-- 2. A LOT IS A LOT, WHICHEVER DISTRICT STANDS ON IT
--
-- The permutation only means something if any district may take any quadrant,
-- so every lot is held to ONE envelope and every plot of every district to the
-- same one: footprint inside +-13 of the lot, two nodes of dry margin round
-- that, perimeter fall at most the foundation skirt (6) and rise at most 6
-- under an airspace clear of at least 8, on every seed measured. That is two
-- nodes tighter than the contract's +-15 plot volume, and the two nodes are
-- exactly what buys the interchange. The numbers are Highcourt's, deliberately:
-- a lot rule that differed per capital would be a second thing to reason about
-- for no gain.
--
--
-- 3. THE QUADRANTS ARE THE DIAGONALS
--
-- The four avenues leave the core on the axes, so the quarters they cut the
-- envelope into are the diagonals: south-east, north-east, north-west,
-- south-west, in that order, which is also the order a quarter turn walks them
-- ((x, z) -> (-z, x)).
--
--
-- 4. THE HASH
--
-- `r6_hash.lua` refuses a domain that is not on its own closed list, and that
-- list is pinned by a frozen WP40 digest, so this uses R6's CONSTRUCTION with a
-- WP13 prefix of its own -- the same length-framed canonical fields, the same
-- SHA-256, the same two-word modular reduction that is exact in a double --
-- exactly as `highcourt_quadrants.lua` does. The seed reaches it as the
-- engine's own `seed` mapgen setting, so main and emerge agree by construction.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- Turns 0..3, in quarter-turn order: (x, z) -> (-z, x).
	M.QUADRANTS = {"southeast", "northeast", "northwest", "southwest"}

	-- The district roles, in the contract's authored order. The permutation
	-- maps this order onto `M.QUADRANTS`.
	M.ROLES = {"market_professions", "martial_garrison", "lore_spiritual",
		"residential_cultural"}

	-- A quarter turn, and the point a south-east-frame position lands on after
	-- `turns` of them.
	-- NEGATING A ZERO IS NOT A NO-OP IN LUA 5.1. A quarter turn is a pair of
	-- negations, and `-0` is a distinct value that concatenates as "-0": a run
	-- whose span ends at `-0` writes its last column at x = -0, and every
	-- consumer that keys a cell by `x .. ":" .. y .. ":" .. z` -- the
	-- successor's cross-run arbitration among them -- then fails to see it as
	-- the same cell as the avenue's own x = 0. The integration fixture is what
	-- found it: the north avenue and the north-east spine both claimed one
	-- column of ground and neither yielded, because their keys differed by a
	-- minus sign. `parts.lua` carries the same normalisation for the same
	-- reason.
	local function unsign(value)
		if value == 0 then return 0 end
		return value
	end

	function M.rotate(x, z, turns)
		for _ = 1, (turns % 4) do
			x, z = unsign(-z), x
		end
		return unsign(x), unsign(z)
	end

	-- A RUN turned the same way. A run is a line segment on an axis: axis "z"
	-- at `at` carries the points (at, p) for p in [from, to], and the turn
	-- sends (at, p) to (-p, at) -- a line at z = at along x, spanning
	-- [-to, -from]. Axis "x" at `at` carries (p, at), which goes to (-at, p) --
	-- a line at x = -at along z, spanning the same [from, to].
	function M.rotate_run(run, turns)
		local axis, at, from, to = run.axis, run.at, run.from, run.to
		for _ = 1, (turns % 4) do
			if axis == "z" then
				axis, at, from, to = "x", at, unsign(-to), unsign(-from)
			else
				axis, at, from, to = "z", unsign(-at), from, to
			end
		end
		return {id = run.id, axis = axis, at = unsign(at),
			from = unsign(from), to = unsign(to)}
	end

	----------------------------------------------------------------------
	-- THE STREETS
	----------------------------------------------------------------------

	-- The four avenues, core edge to gate. They reach 261 and not the gate
	-- station at 256 because Gor Drazhak is WALLED: the rampart's centre line
	-- is at +-256 and its gate tunnel runs through the whole seven-node
	-- thickness, so a road that stopped at the centre line would stop inside
	-- the gate. The four gate points Lane R's routes end on -- (+-256, 0) and
	-- (0, +-256) on the avenue centre lines -- are therefore columns of these
	-- runs, and no route cell or bridge deck is needed inside the envelope.
	local GATE_OUT = 261
	M.AVENUES = {
		{id = "avenue_south", axis = "z", at = 0, from = -GATE_OUT, to = -50,
			gate = "gate_south"},
		{id = "avenue_north", axis = "z", at = 0, from = 50, to = GATE_OUT,
			gate = "gate_north"},
		{id = "avenue_west", axis = "x", at = 0, from = -GATE_OUT, to = -50,
			gate = "gate_west"},
		{id = "avenue_east", axis = "x", at = 0, from = 50, to = GATE_OUT,
			gate = "gate_east"},
	}

	-- The ring street at 96, which the inner column of lots stands along.
	-- Every run spans the full -96..96 so the circuit closes at all four
	-- corners.
	M.RING = {
		{id = "ring_west", axis = "z", at = -96, from = -96, to = 96},
		{id = "ring_east", axis = "z", at = 96, from = -96, to = 96},
		{id = "ring_south", axis = "x", at = -96, from = -96, to = 96},
		{id = "ring_north", axis = "x", at = 96, from = -96, to = 96},
	}

	-- THE RAMPART, on the four edges of the 512 envelope.
	--
	-- The two axes are authored differently on purpose, exactly as Dur
	-- Brannoc's curtain is. The z-runs (west and east) carry the four CORNER
	-- TOWERS and therefore reach 261, five nodes past the envelope edge, so a
	-- tower centred on the corner is whole; the x-runs (south and north) stop
	-- at 252, one node short of the corner tower's own face, so the two never
	-- write into each other. First-run-wins arbitration would otherwise decide
	-- which half of a corner survives, and half a corner is not a corner.
	local WALL_AT = 256
	local WALL_END = 261
	local WALL_SIDE = 252
	local TOWERS = {-192, -128, -64, 64, 128, 192}
	local function tower_list(extra)
		local list = {}
		for index = 1, #TOWERS do list[index] = TOWERS[index] end
		for index = 1, #(extra or {}) do list[#list + 1] = extra[index] end
		table.sort(list)
		return list
	end
	M.WALL = {
		{id = "wall_west", axis = "z", at = -WALL_AT,
			from = -WALL_END, to = WALL_END},
		{id = "wall_east", axis = "z", at = WALL_AT,
			from = -WALL_END, to = WALL_END},
		{id = "wall_south", axis = "x", at = -WALL_AT,
			from = -WALL_SIDE, to = WALL_SIDE},
		{id = "wall_north", axis = "x", at = WALL_AT,
			from = -WALL_SIDE, to = WALL_SIDE},
	}
	-- `outside` says which lane sign faces the field, which is what turns the
	-- berm, the stockade and the stake crest outward.
	--
	-- `corners` is the pair of places each run's walk MEETS another run's, and
	-- it is what `orc_palisade.lua` section 1b reconciles. A z-run meets an
	-- x-run at its own corner tower's centre column (+-256); the x-run meets it
	-- four columns earlier, at its own end (+-252), which is where its walk
	-- stops and the tower's city-face opening begins. Each entry names MY
	-- column and the other run's line and column, and both runs of a pair name
	-- the same two places, which is what lets them agree on a datum without
	-- knowing about each other.
	local function corner(p, axis, at, other_p)
		return {p = p, axis = axis, at = at, other_p = other_p}
	end
	M.WALL_PLAN = {
		wall_west = {outside = -1, gates = {0},
			towers = tower_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT},
			corners = {corner(-WALL_AT, "x", -WALL_AT, -WALL_SIDE),
				corner(WALL_AT, "x", WALL_AT, -WALL_SIDE)}},
		wall_east = {outside = 1, gates = {0},
			towers = tower_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT},
			corners = {corner(-WALL_AT, "x", -WALL_AT, WALL_SIDE),
				corner(WALL_AT, "x", WALL_AT, WALL_SIDE)}},
		wall_south = {outside = -1, gates = {0}, towers = tower_list(),
			cross_towers = {},
			corners = {corner(-WALL_SIDE, "z", -WALL_AT, -WALL_AT),
				corner(WALL_SIDE, "z", WALL_AT, -WALL_AT)}},
		wall_north = {outside = 1, gates = {0}, towers = tower_list(),
			cross_towers = {},
			corners = {corner(-WALL_SIDE, "z", -WALL_AT, WALL_AT),
				corner(WALL_SIDE, "z", WALL_AT, WALL_AT)}},
	}

	-- THE DISTRICT LANES. A lane is an ordinary `avenue.lua` run, so it costs
	-- no new code: it is paved at the surface it finds, it climbs a terrace the
	-- same way, it carries the same lamp rhythm, and the successor's cross-run
	-- arbitration already knows what to do where it meets the ring or an
	-- avenue. Every lane runs down the middle of a gap between two rows or
	-- columns of lots and STARTS ON AN AVENUE, so a district is reached from
	-- the city and not merely near it.
	--
	-- They belong to the QUADRANT and not to the district standing in it, so
	-- the overlay's identity stays independent of the world seed. Gor Drazhak's
	-- four grids are one grid turned, so its four lane pairs are one pair
	-- turned, and unlike the pilot capital no quadrant loses a lane to a river.
	M.LANE_AUTHORED = {
		{id = "lane_spine", axis = "z", at = 138, from = -186, to = 0},
		{id = "lane_cross", axis = "x", at = -138, from = 0, to = 186},
	}

	-- Every lane, in quadrant order then authored order. This is the list the
	-- capital source appends to the avenues and the ring, and the list the KAT
	-- and the lot predicate hold the lots clear of.
	function M.lane_runs()
		local runs = {}
		for index = 1, #M.QUADRANTS do
			for lane = 1, #M.LANE_AUTHORED do
				local turned = M.rotate_run(M.LANE_AUTHORED[lane], index - 1)
				turned.id = M.LANE_AUTHORED[lane].id .. "_" ..
					M.QUADRANTS[index]
				runs[#runs + 1] = turned
			end
		end
		return runs
	end

	----------------------------------------------------------------------
	-- THE LOTS
	----------------------------------------------------------------------

	-- The envelope every lot is held to (section 2).
	M.LOT = {reach = 13, margin = 2, fall = 6, rise = 6, clear = 8,
		lane = 8, quarter = 32}

	-- The authored layout, in the south-east quadrant's frame: three rows of
	-- three, 44 nodes apart, the near row along the east avenue and the near
	-- column beside the core, with the ring street's south-east corner passing
	-- between lots 1/2/4/5.
	M.AUTHORED = {
		{x = 72, z = -72}, {x = 116, z = -72}, {x = 160, z = -72},
		{x = 72, z = -116}, {x = 116, z = -116}, {x = 160, z = -116},
		{x = 72, z = -160}, {x = 116, z = -160}, {x = 160, z = -160},
	}

	-- THE FILL LOTS (user ruling, playtest round 3: "loose, with fields and
	-- gardens"). A dressing is a PLOT like any other -- terrain-relative, with
	-- its own reference column, its own foundation skirt and its own cleared
	-- airspace -- because a field laid at the core's height across a four-node
	-- terrace is a field with a step through it.
	--
	-- What differs from a district lot: a fill lot carries its OWN REACH,
	-- because four slots of four deliberately different sizes is what keeps a
	-- capital from being nothing but 27-node squares; and the lane between it
	-- and its neighbours is 4 rather than 8, because a garden between two
	-- houses is four nodes of ground and four is also what keeps "loose"
	-- visible.
	M.FILL = {margin = 2, fall = 6, rise = 6, clear = 8, lane = 4,
		quarter = 32}

	-- In the south-east frame:
	--   1. the east outer band, between the lot grid and the rampart;
	--   2. the south outer band;
	--   3. the outer corner of the quarter;
	--   4. the strip in the gap between two columns of the lot grid, the one
	--      fill lot that stands INSIDE the district rather than round it.
	M.FILL_AUTHORED = {
		{x = 208, z = -104, reach = 11},
		{x = 104, z = -208, reach = 11},
		{x = 200, z = -200, reach = 8},
		{x = 94, z = -160, reach = 5},
	}

	-- THE EIGHTEEN LOTS THAT DO NOT TAKE THE TURN.
	--
	-- One grid turned four times is where the layout starts, not where it ends:
	-- the ground under a turned lot is not the ground under its original, and
	-- eighteen of the fifty-two land on a shoulder that rises more than the
	-- plot's own airspace clears, or fall further than the skirt reaches.
	-- `tools/wp13/gor_drazhak_lots.lua --repair` measured them on ALL NINE
	-- fixture seeds and moved each to the NEAREST legal position -- nearest and
	-- not flattest, because the layout is a design and sorting on flatness is
	-- what put two Highcourt plots in a river.
	--
	-- NINE SEEDS AND NOT THREE, and the difference is the whole of this table's
	-- second version. Measured on the two gate seeds and the user's world, the
	-- turn needed seven repairs; measured on all nine, it needs eighteen, and
	-- the seven were not a subset -- three of them were repairs to ground that
	-- only three worlds made bad. A layout tuned to three worlds is a layout
	-- tuned to nothing.
	--
	-- Seventeen of the eighteen move four to twenty nodes and stay in their own
	-- row and column of the grid. The exception is the south-west quarter's
	-- lot 8, which moves seventy-two to (-204, -144): that quarter is the one
	-- the mesa's own back runs through, its nine lots are boxed in by the gate
	-- corridor, the ring street and each other, and the nearest ground that
	-- carries a lot on all nine worlds is in the outer band. It stands in line
	-- with lot 9 and fill 2 rather than in its own column, and that is the
	-- honest cost of the nine-seed bar.
	--
	-- Each row is {quadrant, lot index, x, z}.
	M.LOT_REPAIRS = {
		{"northeast", 4, 116, 52},
		{"northwest", 7, -68, 160},
		{"southeast", 2, 116, -68},
		{"southeast", 4, 68, -116},
		{"southeast", 7, 72, -164},
		{"southeast", 8, 116, -164},
		{"southwest", 1, -76, -72},
		{"southwest", 5, -112, -112},
		{"southwest", 7, -160, -68},
		{"southwest", 8, -204, -144},
		{"southwest", 9, -160, -168},
	}
	-- The same, for the fill lots.
	M.FILL_REPAIRS = {
		{"northwest", 2, -104, 204},
		{"northwest", 3, -200, 196},
		{"southeast", 1, 212, -104},
		{"southeast", 3, 200, -204},
		{"southwest", 2, -212, -104},
		{"southwest", 3, -204, -200},
		{"southwest", 4, -168, -94},
	}

	-- The nine lots and the four fill lots of each quadrant, DERIVED from the
	-- authored layout (section 1) and then repaired where the ground refused
	-- the turn. `M.LOTS[quadrant][k]` is authored lot k turned into that
	-- quadrant, so lot k means the same thing in all four and the districts
	-- interchange by construction.
	M.LOTS, M.FILL_LOTS = {}, {}
	for index = 1, #M.QUADRANTS do
		local name = M.QUADRANTS[index]
		local turns = index - 1
		local lots, fill = {}, {}
		for lot = 1, #M.AUTHORED do
			local x, z = M.rotate(M.AUTHORED[lot].x, M.AUTHORED[lot].z, turns)
			lots[lot] = {x = x, z = z}
		end
		for lot = 1, #M.FILL_AUTHORED do
			local x, z = M.rotate(M.FILL_AUTHORED[lot].x,
				M.FILL_AUTHORED[lot].z, turns)
			fill[lot] = {x = x, z = z, reach = M.FILL_AUTHORED[lot].reach}
		end
		M.LOTS[name] = lots
		M.FILL_LOTS[name] = fill
	end
	local function apply(repairs, table_of)
		for index = 1, #repairs do
			local row = repairs[index]
			local list = table_of[row[1]]
			if type(list) ~= "table" or type(list[row[2]]) ~= "table" then
				error("wp13 gor drazhak quadrants: repair " .. index ..
					" names no lot", 0)
			end
			list[row[2]].x, list[row[2]].z = row[3], row[4]
		end
	end
	apply(M.LOT_REPAIRS, M.LOTS)
	apply(M.FILL_REPAIRS, M.FILL_LOTS)

	----------------------------------------------------------------------
	-- The hash (section 4)
	----------------------------------------------------------------------

	local PREFIX = "grug_wp13_gor_drazhak_district_quadrant_v1"
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
			error("wp13 gor drazhak quadrants: canonical field differs", 0)
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
			error("wp13 gor drazhak quadrants: permutation index differs", 0)
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

	function M.permutation(full_seed, raw_sha256)
		if type(full_seed) ~= "string" or full_seed == "" or
				not full_seed:match("^%-?%d+$") then
			error("wp13 gor drazhak quadrants: full world seed differs", 0)
		end
		if type(raw_sha256) ~= "function" then
			error("wp13 gor drazhak quadrants: SHA-256 seam differs", 0)
		end
		local digest = raw_sha256(frame(PREFIX) .. frame(full_seed) ..
			frame(#M.ROLES))
		if type(digest) ~= "string" or #digest ~= 32 then
			error("wp13 gor drazhak quadrants: SHA-256 result differs", 0)
		end
		return M.permutation_of_index(reduce(digest, FACTORIAL[4]))
	end

	-- The canonical assignment, used where no world exists: the roles take the
	-- quadrants in authored order. Every engine-free fixture, the renderer and
	-- the timing harness see this one, and the KAT checks the seeded
	-- permutations beside it.
	function M.canonical()
		return {1, 2, 3, 4}
	end

	-- A permutation is a bijection of 1..n onto itself and an external one is
	-- not trusted to be: two roles mapped to one quadrant would put two
	-- districts on one set of lots and leave a quarter of the capital empty,
	-- which is a wrong CITY rather than an error anything downstream catches.
	function M.check_permutation(permutation)
		if type(permutation) ~= "table" or #permutation ~= #M.ROLES then
			error("wp13 gor drazhak quadrants: the permutation is not " ..
				#M.ROLES .. " long", 0)
		end
		local seen = {}
		for index = 1, #M.ROLES do
			local value = permutation[index]
			if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or
					value > #M.ROLES or seen[value] then
				error("wp13 gor drazhak quadrants: the permutation is not a " ..
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
				error("wp13 gor drazhak quadrants: permutation differs", 0)
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
