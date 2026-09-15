-- The troll gate threshold: what an OPEN capital has where a walled one has a
-- gatehouse.
--
-- The capitals contract's section 4 ruling of 2026-09-14 leaves Lethariel and
-- Kezamba open -- "open edges (hedges/orchards, groves, stilts and water) for
-- Highcourt, Lethariel and Kezamba", of which Highcourt was later given a wall
-- by the round-3 plan and these two were not. An open capital still has four
-- GATE POINTS: WP40 pins a gate station at (ax +- 256, az) and (ax, az +- 256),
-- and the wave-2 route lane ends every long-distance route on exactly those
-- four columns. A traveller arriving there has to be able to see that they have
-- arrived somewhere.
--
-- So each gate point carries a THRESHOLD: two totem posts on the verges with a
-- junglewood lintel across the road between them, a wall torch on the inner face
-- of each post and one marker course of basalt laid flush into the road under
-- it. It is Kezamba'''s answer to a gatehouse and it is the contract'''s own troll
-- vocabulary -- "junglewood walkways, totem posts" -- rather than a new idea.
--
-- IT RAISES NO GROUND. See the base rule in `M.run`: a threshold that levelled
-- its own apron came out as a wall across a descending road, and the fix was to
-- stop writing ground at all.
--
-- WHY IT IS AN OVERLAY RUN AND NOT A BLUEPRINT. Same three reasons the curtain
-- wall is one (`wp13/wall.lua`): an anchor blueprint is bounded at +-47 and the
-- gate stands 256 nodes out; a reference plot is projected from ONE column and
-- the threshold spans the road; and an overlay is a pure function of the column
-- surface evaluated per mapchunk, which is exactly what a gate standing on
-- terraced ground is. It shares the capital's ONE overlay with the avenues,
-- because the successor's cross-run arbitration -- which is what lets the road
-- keep the cells of its own carriageway under the lintel -- only exists within
-- one overlay, and the avenues run FIRST in `kezamba.lua`'s run list.
--
-- EVERY CELL STAYS INSIDE THE SEAM'S ACTIVATION BAND. `bind_plan` offers a
-- mapchunk a run when the chunk meets `at +- (half + 1)`, three nodes either
-- side of the centre line for the contract's five-wide carriageway. A cell
-- outside that band would be a cell in a mapchunk the run is never called for.
-- The posts therefore stand on lanes +-3 and nothing reaches further.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The threshold's own numbers.
	M.HALF = 3                 -- the seam's activation band
	M.RISE = 5                 -- courses of post over the road
	M.PAVE_HALF = 1            -- how far along the axis the marker course runs

	M.REACH = 40               -- the look-around, `avenue.REACH`

	local function signature(palette)
		return palette.maybe("signature") or palette.node("foundation")
	end
	function M.palette_names(palette)
		local names = {parts.AIR, signature(palette),
			palette.node("post"), palette.node("beam"),
			palette.node("plaza_edge"), palette.node("roof_slab"),
			palette.node("light_wall")}
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 kezamba gate: the palette has no name for a " ..
					"threshold role", 0)
			end
			if not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	local function axis_steps(axis)
		if axis == "x" then return 1, 0 end
		if axis == "z" then return 0, 1 end
		error("wp13 kezamba gate: unknown axis " .. tostring(axis), 0)
	end

	-- One piece of one threshold.
	--
	-- `spec` is the seam's own overlay spec, identical to `avenue.run`'s:
	-- axis, at, from, to (THIS PIECE's span), lamp_phase, reach.
	-- `plan` is the run's authored geometry -- here only `centre`, the gate
	-- point's own position along the axis -- looked up from the same table for
	-- every piece, which is what keeps a piece of a run exactly that stretch of
	-- the whole run.
	--
	-- THE LINTEL IS LEVEL, and that is why the base height is taken over the
	-- GATE POINT'''s own seven lanes and not over the piece: two halves of one
	-- gate computed from two different windows would meet at a step. Those seven
	-- columns lie inside `from - reach .. to + reach` for every piece of a run
	-- this short, so every piece computes the same number from the same columns.
	function M.run(palette, spec, surface, plan)
		if type(surface) ~= "function" then
			error("wp13 kezamba gate: a run needs a surface callback", 0)
		end
		if type(plan) ~= "table" or type(plan.centre) ~= "number" then
			error("wp13 kezamba gate: a run needs its authored plan", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 kezamba gate: the run has no span", 0)
		end
		local at = spec.at
		local centre = plan.centre
		local buf = parts.buffer()
		local queries = 0

		local function column(p, lane)
			if dx == 1 then return p, at + lane end
			return at + lane, p
		end
		local function height(x, z)
			local y = surface(x, z)
			queries = queries + 1
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 kezamba gate: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. THE BASE: the height the ROAD is walked at over the gate point, which
		-- is not the ground there.
		--
		-- Two corrections are folded into this one number, and each had a render
		-- behind it.
		--
		-- The first version took the highest GROUND over the gate point plus six
		-- columns either way and carried every column of its seven-lane band up
		-- to it, so where the road descends the "threshold" came out as a solid
		-- wall of masonry across it. A gate a traveller cannot see through is not
		-- a gate, and nothing is filled up to anything now.
		--
		-- The second version took the highest ground over the gate point alone --
		-- and buried its own posts. `avenue.lua` walks its road at the
		-- ONE-LIPSCHITZ UPPER ENVELOPE of the surface, "the lowest height field
		-- that is everywhere at or above the surface and never changes by more
		-- than a node between two columns", and at Kezamba's east gate the
		-- terrain outside the envelope climbs 40 nodes in 32 columns, so the road
		-- is already 16 nodes above the ground when it reaches the gate point.
		-- Posts standing on the ground there stand at the foot of an embankment
		-- the road runs over.
		--
		-- So the base is that same envelope, evaluated at the gate point: the
		-- greatest `surface(q) - |centre - q|` within the look-around, over all
		-- seven lanes. Taking the maximum over the lanes rather than one lane's
		-- own envelope puts the lintel at or above the road on every lane, which
		-- is the side of the rounding a lintel wants to be on. It is the same
		-- rule read from the same callback the road reads, so the two cannot
		-- drift apart; and it is computed from a window every piece of this short
		-- run contains, so every piece gets the same number and the lintel stays
		-- level.
		local reach = spec.reach or M.REACH
		local base
		for lane = -M.HALF, M.HALF do
			for q = centre - reach, centre + reach do
				local x, z = column(q, lane)
				local lifted = height(x, z) - math.abs(centre - q)
				if base == nil or lifted > base then base = lifted end
			end
		end

		-- 2. The marker course: the gate point's own row of the carriageway, in
		-- the signature rock, laid at each column's own surface so it is flush
		-- with the road rather than a step in it. Only the columns of THIS
		-- piece, and only where the avenue has not already claimed the cell --
		-- which the successor decides, not this run.
		local MARK = signature(palette)
		local KERB = palette.node("plaza_edge")
		local POST = palette.node("post")
		local BEAM = palette.node("beam")
		local paved, posts, lintel = 0, 0, 0
		local first = math.max(from, centre - 1)
		local last = math.min(to, centre + 1)
		for p = first, last do
			for lane = -M.HALF, M.HALF do
				local x, z = column(p, lane)
				-- The marker course goes at the ROAD's level and not at the
				-- ground's, for the same reason the posts do.
				buf:put(x, base, z,
					(lane == -M.HALF or lane == M.HALF) and KERB or MARK)
				buf:clear(x, base + 1, z, x, base + M.RISE + 2, z)
				paved = paved + 1
			end
		end

		-- 3. The two totem posts on the verges at the gate point itself, and
		-- the junglewood lintel between them.
		if centre >= from and centre <= to then
			for _, lane in ipairs({-M.HALF, M.HALF}) do
				local x, z = column(centre, lane)
				for step = 1, M.RISE do
					buf:put(x, base + step, z,
						(step % 3 == 0) and KERB or POST)
				end
				buf:put(x, base + M.RISE + 1, z, palette.node("roof_slab"))
				posts = posts + 1
			end
			for lane = -M.HALF + 1, M.HALF - 1 do
				local x, z = column(centre, lane)
				buf:put(x, base + M.RISE, z, BEAM)
				lintel = lintel + 1
			end
			-- A torch on the inner face of each post, which is what makes the
			-- gate readable at night.
			for _, lane in ipairs({-M.HALF, M.HALF}) do
				local x, z = column(centre, lane)
				local inward = (lane < 0) and 1 or -1
				local tx, tz = x, z
				if dx == 1 then tz = z + inward else tx = x + inward end
				parts.wall_torch(buf, palette, tx, base + M.RISE - 1, tz,
					(dx == 1) and 0 or -inward, 0, (dx == 1) and -inward or 0)
			end
		end

		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		return {
			id = spec.id, axis = spec.axis, at = at, from = from, to = to,
			cells = cells,
			-- A threshold publishes no lamp for the successor's arbitration to
			-- weigh: its two torches are attached to its own posts and stand on
			-- the verge the road never paves.
			lamps = {},
			pavement = paved, treads = 0, posts = posts, lintel = lintel,
			base = base,
			columns = to - from + 1, queries = queries,
		}
	end

	return M
end

return loader
