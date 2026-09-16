-- Where Lethariel's four districts stand, and which of them stands where.
--
--
-- 1. THE LAKE, AND WHY THIS FILE IS NOT `highcourt_quadrants.lua`
--
-- The capitals contract (section 2.1) says the four district roles are
-- "assigned to quadrants by a deterministic permutation from the world seed
-- through the existing R6 hash". That sentence assumes four quarters a
-- district can be moved BETWEEN, and Highcourt's own note already had to bend
-- it once: its two rivers meant the four quadrants could not be one layout
-- rotated four times, so each quadrant carries its own nine lots.
--
-- At Lethariel the same measurement gives a harder answer. WP40 puts a LAKE in
-- this capital's envelope -- 9 625 of the 66 049 columns of the +-256 square
-- sampled every two nodes, a crescent reaching from the core's own north edge
-- out past the east envelope line -- and it is not a river that can be bridged
-- but a body of water covering more than half the north-east quarter. Held to
-- the same lot envelope every other capital's lots are held to (dry footprint
-- and margin, perimeter fall at most the skirt, rise under the airspace the
-- plot clears, clear of the core, the gate corridors and every street run,
-- inside its own quarter, a lane clear of its neighbours) on ALL NINE SEEDS of
-- `tools/wp13/capital_anchor_fixture.lua`, the north-east quarter carries
-- exactly THREE lots. The other three carry nine each with room to spare.
-- `tools/wp13/lethariel_plots.lua --census` counts the legal positions per
-- quarter and section 3.1 of the research note is its output. `tools/wp13/lethariel_plots.lua` is the
-- predicate and section 3 of docs/research/wp13-lethariel.md the measurement.
--
-- So four interchangeable quarters do not exist here, and the honest
-- implementation of the contract's intent is this:
--
--   * the NORTH-EAST quarter is THE MERE. The lore and spiritual district
--     stands there and only there -- three lots on the far shore, the shrine,
--     the mourning grove and the fishing stages -- because a precinct built
--     round a lake cannot be moved to a quarter that has no lake in it;
--   * the OTHER THREE roles permute over the OTHER THREE quarters, by the
--     same construction Highcourt's permutation uses (section 4), reduced
--     modulo 3! = 6 instead of 4! = 24.
--
-- That is a DESIGN DECISION of this lane, not a user ruling and not contract
-- text, and it is recorded as one. What it keeps is the property the
-- permutation exists for: which district a player walks into out of the south,
-- the west or the north-west gate is the world seed's and not the author's.
-- What it gives up is that the lore district could have stood anywhere, and
-- the ground is what took that away.
--
--
-- 2. A LOT IS A LOT, WHICHEVER OF THE THREE DISTRICTS STANDS ON IT
--
-- The permutation only means something if any of the three may take any of
-- the three quarters, so a lot is held to ONE envelope and every plot of
-- every district is held to the same one: footprint inside +-11 of the lot,
-- two nodes of dry margin round that, perimeter fall at most the foundation
-- skirt (6) and rise at most 6 under an airspace clear of at least 8 -- on
-- BOTH gate seeds.
--
-- THE REACH IS 11 AND NOT HIGHCOURT'S 13. That is the lake again, measured:
-- at 13 the north-east quarter carries no lot at all that also clears the
-- quarter rule, and the three dry quarters lose about a tenth of their legal
-- positions. Eleven is what the ground will carry here, it is still inside the
-- contract's +-15 plot volume with four nodes to spare, and it suits the
-- elf capital anyway -- "tall narrow halls" and "groves between plots" is a
-- smaller footprint with more green round it, not a wider one.
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
-- list is pinned by the WP40 R6 micro-KAT. What this file uses instead is
-- R6's CONSTRUCTION with a WP13 prefix of its own -- the same length-framed
-- canonical fields, the same SHA-256, the same two-word modular reduction
-- that is exact in a double -- exactly as `highcourt_quadrants.lua` does, and
-- with its own prefix so the two capitals cannot share a permutation.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- Turns 0..3, in quarter-turn order: (x, z) -> (-z, x).
	M.QUADRANTS = {"southeast", "northeast", "northwest", "southwest"}

	-- The district roles, in the contract's authored order.
	M.ROLES = {"market_professions", "martial_garrison", "lore_spiritual",
		"residential_cultural"}

	-- The role that does not move, and the quarter it does not move out of.
	M.FIXED_ROLE = "lore_spiritual"
	M.FIXED_QUADRANT = "northeast"

	-- The three roles the permutation acts on and the three quarters they
	-- take, both in authored order. Derived from the two lists above rather
	-- than typed again, so a change to either cannot leave the other behind.
	M.MOVING_ROLES = {}
	for index = 1, #M.ROLES do
		if M.ROLES[index] ~= M.FIXED_ROLE then
			M.MOVING_ROLES[#M.MOVING_ROLES + 1] = M.ROLES[index]
		end
	end
	M.MOVING_QUADRANTS = {}
	for index = 1, #M.QUADRANTS do
		if M.QUADRANTS[index] ~= M.FIXED_QUADRANT then
			M.MOVING_QUADRANTS[#M.MOVING_QUADRANTS + 1] = M.QUADRANTS[index]
		end
	end

	-- The envelope every lot is held to (section 2), and the envelope the
	-- MERE's own three lots are held to, which is the same one.
	M.LOT = {reach = 11, margin = 2, fall = 6, rise = 6, clear = 8,
		lane = 6, quarter = 32}

	-- The authored layout, in the south-east quadrant's frame: three rows of
	-- three, 52 nodes apart, the near row along the east avenue and the near
	-- column beside the core. Every moving quadrant's grid is this one
	-- rotated and then slid onto ground that carries it.
	M.AUTHORED = {
		{x = 72, z = -72}, {x = 124, z = -72}, {x = 176, z = -72},
		{x = 72, z = -124}, {x = 124, z = -124}, {x = 176, z = -124},
		{x = 72, z = -176}, {x = 124, z = -176}, {x = 176, z = -176},
	}

	-- The MERE's own three, also written in the south-east frame so that one
	-- rotation rule serves every quarter: they are the dry shelf the lake
	-- leaves on the far shore and the ridge east of it.
	M.MERE_AUTHORED = {
		{x = 200, z = -48}, {x = 232, z = -180}, {x = 212, z = -214},
	}

	-- The lots of each quadrant, in the order a district's plots take them.
	--
	-- Derived and verified by `tools/wp13/lethariel_plots.lua --derive` against
	-- the terrain of ALL NINE SEEDS of `capital_anchor_fixture.lua`, and not
	-- against the two gate seeds every earlier capital's lots were derived on.
	-- That is a finding rather than a preference: the first version of this
	-- table was a two-seed derivation, and asking the same predicate the other
	-- seven seeds refused SEVENTEEN of the forty-four lots -- fourteen for a
	-- rise over the airspace the plot clears and three for a fall past the
	-- foundation skirt. A lot that is flat on two worlds is not a lot that is
	-- flat; the terrace the fitting lays over the relief moves with the seed.
	M.LOTS = {
		southeast = {
			{x = 72, z = -74}, {x = 124, z = -72}, {x = 176, z = -72},
			{x = 72, z = -126}, {x = 124, z = -118}, {x = 176, z = -124},
			{x = 72, z = -176}, {x = 124, z = -176}, {x = 178, z = -166},
		},
		northeast = {
			{x = 46, z = 206}, {x = 182, z = 234}, {x = 218, z = 214},
		},
		northwest = {
			{x = -72, z = 76}, {x = -124, z = 72}, {x = -174, z = 72},
			{x = -72, z = 124}, {x = -124, z = 124}, {x = -180, z = 122},
			{x = -72, z = 176}, {x = -124, z = 176}, {x = -166, z = 162},
		},
		southwest = {
			{x = -78, z = -72}, {x = -72, z = -124}, {x = -72, z = -176},
			{x = -124, z = -72}, {x = -124, z = -124}, {x = -124, z = -176},
			{x = -176, z = -78}, {x = -176, z = -124}, {x = -170, z = -168},
		},
	}

	----------------------------------------------------------------------
	-- THE FILL LOTS
	----------------------------------------------------------------------
	--
	-- The round-3 playtest's verdict on a capital with buildings and nothing
	-- between them was "huge and empty", and the user's ruling was a fill
	-- grade of "loose, with fields and gardens". A dressing is therefore a
	-- PLOT like any other -- terrain-relative, with its own reference column,
	-- foundation skirt and cleared airspace, because a garden laid at the
	-- core's height across a three-node elf terrace is a garden with a step
	-- through it.
	--
	-- A fill lot carries its OWN REACH: the slots are deliberately different
	-- sizes, because a capital of nothing but 23-node squares is as repetitive
	-- as a capital of nothing but houses. Slot k has the same reach in every
	-- moving quadrant, which is all the interchange needs. The LANE is 4 and
	-- not 6: a grove between two halls is four nodes of turf.
	M.FILL = {margin = 2, fall = 6, rise = 6, clear = 8, lane = 4,
		quarter = 32}

	M.FILL_AUTHORED = {
		{x = 216, z = -104, reach = 11},
		{x = 104, z = -216, reach = 11},
		{x = 208, z = -208, reach = 8},
		{x = 98, z = -148, reach = 5},
	}

	-- The mere's two, in the same south-east frame. They are the SMALL pair
	-- of the four slots and not the large one: the far shelf carries no
	-- eleven-reach dressing anywhere -- the search refuses every position on
	-- both gate seeds with a rise of nine against an airspace of eight -- and
	-- a slot the ground will not carry is not a slot.
	M.MERE_FILL_AUTHORED = {
		{x = 208, z = -114, reach = 8},
		{x = 228, z = -170, reach = 5},
	}

	-- Derived and verified by `tools/wp13/lethariel_plots.lua --derive-fill`
	-- on the same NINE seeds as the district lots, and against those lots:
	-- a fill lot is held clear of every district lot of its own quarter.
	M.FILL_LOTS = {
		southeast = {
			{x = 216, z = -104}, {x = 80, z = -206},
			{x = 210, z = -208}, {x = 108, z = -148},
		},
		northeast = {
			{x = 72, z = 214}, {x = 158, z = 232},
		},
		northwest = {
			{x = -216, z = 104}, {x = -96, z = 206},
			{x = -208, z = 212}, {x = -108, z = 148},
		},
		southwest = {
			{x = -88, z = -206}, {x = -216, z = -104},
			{x = -214, z = -210}, {x = -148, z = -108},
		},
	}

	-- The reach of each fill slot, in slot order, for a moving quadrant and
	-- for the mere. A roster says WHAT a dressing is; this file is the one
	-- place that says how big its lot is.
	M.FILL_REACHES = {11, 11, 8, 5}
	M.MERE_FILL_REACHES = {8, 5}

	-- THE DISTRICT LANES.
	--
	-- A district is a place with streets in it: without them nine buildings
	-- stand in a meadow, which is what Highcourt's first four-district render
	-- showed. A lane is an ordinary `avenue.lua` run, so it costs no new code,
	-- it is paved at whatever surface it finds and it climbs an elf terrace
	-- the same way the great avenues do.
	--
	-- Every lane runs down the middle of a gap between two rows or columns of
	-- lots. They belong to the QUADRANT and not to the district standing in
	-- it, so the list is the same on every world and the overlay's identity
	-- does not depend on the seed.
	--
	-- EACH LANE IS THE RING STREET CARRYING ON PAST ITS OWN CORNER, and that
	-- is the round-4 fix (2026-09-16).
	--
	-- The first version ran every lane at +-98 from the avenue at 0 out to
	-- +-190, which put six of them ALONGSIDE the ring street at +-96 for 97
	-- columns each, three of the five lanes of one being three of the five
	-- lanes of the other. Two streets two nodes apart are one street, and the
	-- user walked into exactly that in playtest 6: "at ~1700,-1400, in +x and
	-- in -z, two streets overlay each other with a 2-node offset across the
	-- walking direction; the last one written wins and artefacts of the
	-- overwritten street remain." It cost the only unwalkable steps left in the
	-- six capitals -- 3, 7 and 11 pairs on the fixture seeds
	-- (`docs/research/wp13-street-geometry.md` section 8), because the
	-- road-wide envelope gives two runs two answers for the same column and
	-- first-run-wins picks one of them.
	--
	-- So a lane now stands on the RING'S OWN CENTRE LINE and begins one column
	-- past the end of the ring run it continues. Three things follow, and all
	-- three are what the ruling asks for:
	--
	--   * the lane and the ring are COLLINEAR and share no column, so there is
	--     no side-by-side stretch left and nothing to arbitrate;
	--   * the lane meets the PERPENDICULAR ring run at the corner, which is an
	--     ordinary junction, so the corner's plateau covers the ring's last
	--     columns AND the lane's first ones and the two are pinned to one y --
	--     a collinear seam with a plateau under it cannot step;
	--   * the two lanes of a quadrant meet the two ring sides at the SAME
	--     corner, so each ring corner is one four-way junction group rather
	--     than four places two streets happen to pass.
	--
	-- What it costs: the stretch of lane that ran inside the ring is gone,
	-- because the ring was already there -- and the lane no longer touches an
	-- avenue directly. It reaches every avenue through the ring, which is what
	-- the ring is for.
	--
	-- The MERE has ONE lane and it is a SHORE WALK: the three lots of the lore
	-- district stand on the far shelf, the ring street at 96 is under water on
	-- that side, and the only way to them is along the north shore. It is the
	-- one lane that was never beside a ring run, so it is unchanged: it starts
	-- on the north avenue and crosses the head of the lake, which
	-- `avenue.lua` bridges (the seam hands a road the WATER surface where
	-- water stands, not the bed under it -- `r7_settlement.lua`,
	-- `walkable_values`).
	local RING_AT = 96
	local LANE_END = 190
	-- One past the ring run's own last column, so the two are collinear
	-- neighbours and not collinear overlappers.
	local LANE_START = RING_AT + 1
	M.LANES = {
		southeast = {
			{id = "lane_southeast_spine", axis = "z", at = RING_AT,
				from = -LANE_END, to = -LANE_START},
			{id = "lane_southeast_cross", axis = "x", at = -RING_AT,
				from = LANE_START, to = LANE_END},
		},
		northeast = {
			{id = "lane_northeast_shore", axis = "x", at = 184,
				from = 0, to = 232},
		},
		northwest = {
			{id = "lane_northwest_spine", axis = "z", at = -RING_AT,
				from = LANE_START, to = LANE_END},
			{id = "lane_northwest_cross", axis = "x", at = RING_AT,
				from = -LANE_END, to = -LANE_START},
		},
		southwest = {
			{id = "lane_southwest_spine", axis = "z", at = -RING_AT,
				from = -LANE_END, to = -LANE_START},
			{id = "lane_southwest_cross", axis = "x", at = -RING_AT,
				from = -LANE_END, to = -LANE_START},
		},
	}

	-- Every lane, in quadrant order then authored order.
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

	-- The turns that carry the south-east frame onto a named quadrant.
	function M.turns_of(quadrant)
		for index = 1, #M.QUADRANTS do
			if M.QUADRANTS[index] == quadrant then return index - 1 end
		end
		error("wp13 lethariel quadrants: unknown quadrant " ..
			tostring(quadrant), 0)
	end

	----------------------------------------------------------------------
	-- The hash (section 4)
	----------------------------------------------------------------------

	local PREFIX = "grug_wp13_lethariel_district_quadrant_v1"
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
			error("wp13 lethariel quadrants: canonical field differs", 0)
		end
		return integer_ascii(#bytes) .. ":" .. bytes
	end

	-- The first two 32-bit words of a raw digest, reduced modulo a
	-- denominator without ever leaving the exact integer range of a double.
	local function reduce(digest, denominator)
		local hi, lo = 0, 0
		for byte = 1, 4 do hi = hi * 256 + string.byte(digest, byte) end
		for byte = 5, 8 do lo = lo * 256 + string.byte(digest, byte) end
		local power = UINT32 % denominator
		return ((hi % denominator) * power + (lo % denominator)) % denominator
	end

	local FACTORIAL = {[0] = 1, 1, 2, 6, 24}

	-- Index 0..5 -> one of the 6 permutations of 1..3, factorial base.
	function M.permutation_of_index(index)
		local size = #M.MOVING_ROLES
		if type(index) ~= "number" or index % 1 ~= 0 or index < 0 or
				index > FACTORIAL[size] - 1 then
			error("wp13 lethariel quadrants: permutation index differs", 0)
		end
		local pool = {}
		for value = 1, size do pool[value] = value end
		local result, rest = {}, index
		for remaining = size, 1, -1 do
			local block = FACTORIAL[remaining - 1]
			local pick = math.floor(rest / block) + 1
			rest = rest - (pick - 1) * block
			result[#result + 1] = table.remove(pool, pick)
		end
		return result
	end

	-- The permutation this world's seed asks for: moving-role index ->
	-- moving-quadrant index.
	function M.permutation(full_seed, raw_sha256)
		if type(full_seed) ~= "string" or full_seed == "" or
				not full_seed:match("^%-?%d+$") then
			error("wp13 lethariel quadrants: full world seed differs", 0)
		end
		if type(raw_sha256) ~= "function" then
			error("wp13 lethariel quadrants: SHA-256 seam differs", 0)
		end
		local size = #M.MOVING_ROLES
		local digest = raw_sha256(frame(PREFIX) .. frame(full_seed) ..
			frame(size))
		if type(digest) ~= "string" or #digest ~= 32 then
			error("wp13 lethariel quadrants: SHA-256 result differs", 0)
		end
		return M.permutation_of_index(reduce(digest, FACTORIAL[size]))
	end

	-- The canonical assignment, used where no world exists: the moving roles
	-- take the moving quarters in authored order.
	function M.canonical()
		local list = {}
		for index = 1, #M.MOVING_ROLES do list[index] = index end
		return list
	end

	-- A permutation is a bijection of 1..n onto itself, and an external one is
	-- not trusted to be: two roles mapped to one quarter would put two
	-- districts on one set of lots and leave a third of the capital empty,
	-- which is a wrong CITY rather than an error anything downstream catches.
	function M.check_permutation(permutation)
		local size = #M.MOVING_ROLES
		if type(permutation) ~= "table" or #permutation ~= size then
			error("wp13 lethariel quadrants: the permutation is not " ..
				size .. " long", 0)
		end
		local seen = {}
		for index = 1, size do
			local value = permutation[index]
			if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or
					value > size or seen[value] then
				error("wp13 lethariel quadrants: the permutation is not a " ..
					"bijection at position " .. index, 0)
			end
			seen[value] = true
		end
		return permutation
	end

	-- Resolve role -> quadrant. The fixed role is answered first and never
	-- from the permutation; the three moving ones follow it.
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
		local function entry(quadrant)
			return {quadrant = quadrant, turns = M.turns_of(quadrant),
				lots = M.LOTS[quadrant], fill_lots = M.FILL_LOTS[quadrant]}
		end
		local assignment = {[M.FIXED_ROLE] = entry(M.FIXED_QUADRANT)}
		for index = 1, #M.MOVING_ROLES do
			local quadrant = M.MOVING_QUADRANTS[permutation[index]]
			if type(quadrant) ~= "string" then
				error("wp13 lethariel quadrants: permutation differs", 0)
			end
			assignment[M.MOVING_ROLES[index]] = entry(quadrant)
		end
		return assignment, permutation
	end

	return M
end

return loader
