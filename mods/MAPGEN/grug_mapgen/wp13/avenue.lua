-- WP13 capital avenues: the surface overlay that carries a gate road across
-- terraced ground.
--
-- The capitals contract (docs/research/wp13-capitals-pois-contract.md section
-- 2.1) gives a capital four avenues from the core edge to the four gate
-- stations, and says what they are: "pavement at surface, one stair node at
-- each terrace rise, lamp posts every 8 nodes, no height queries". The last
-- clause is the design: a blueprint is anchor-relative and an avenue is not,
-- because WP40's terraces put every node of it at a different height, so the
-- avenue cannot be authored as cells at all. It is authored as a FUNCTION of
-- the column surface, and the surface arrives through one callback the caller
-- owns.
--
-- That makes this module the one piece of WP13 a successor can run per
-- mapchunk: give it the run and a `surface(x, z)` that answers for the
-- columns of the chunk it is emerging, and it yields the cells of that piece
-- of road and nothing else. It queries no height of its own, reads no engine
-- and keeps no state; two calls with the same arguments produce the identical
-- cell list.
--
-- Where the contract's sentence is not enough
-- -------------------------------------------
-- "One stair node at each terrace rise" is one stair per NODE of rise, not
-- one per rise. A player walks up half a node and jumps a whole one, and the
-- race terrace steps of WP40 are 2 (human), 3 (elf, undead, troll) and 4
-- (dwarf, orc), so a single stair in front of a two-node rise leaves the
-- second node to be jumped, which is not a road.
--
-- The first version of this module built a flight per joint and it was wrong
-- twice, in ways a per-joint rule cannot be right: two joints closer than
-- their flights fought over the columns between them and left a wall, and a
-- joint that fell on the border between two PIECES of the run was walked by
-- neither, so a road emerged one mapchunk at a time grew a four-node step
-- where a single call had a flight.
--
-- What replaces it is one rule with no joints in it: the road's walking
-- level is the ONE-LIPSCHITZ UPPER ENVELOPE of the ground -- the lowest
-- height field that is everywhere at or above the surface and never changes
-- by more than a node between two columns. Fill carries each column up to
-- its envelope and a tread caps it wherever the envelope stands above the
-- ground or above a neighbour, because a one-node change is walked as the
-- two halves of a stair. A rise of `h` still climbs over `h` columns; two
-- joints in a row simply make the road leave the ground earlier; and the
-- envelope of a column depends on the ground within `REACH` columns of it
-- and on nothing else, which is what makes a piece of the run equal to that
-- stretch of the whole.
--
-- Every lane of the road is profiled on its own, because a terrace joint
-- crossing the road at an angle arrives at the five lanes in five different
-- columns; a per-lane envelope follows it, a road-wide one would step where
-- the ground does not.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The capitals contract's own numbers.
	M.WIDTH = 5
	M.LAMP_SPACING = 8
	-- How far beyond a piece the ground is read; see the carriageway below.
	M.REACH = 40

	-- The avenue vocabulary, each with its fallback into the start
	-- vocabulary, exactly as `capitals.lua` resolves the same roles: the
	-- capital roles are optional and a palette that has not been given them
	-- still builds a road.
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end

	-- Every node name a run may write, in ASCII byte order and without
	-- duplicates. The seam needs it because an overlay has NO CELLS until a
	-- surface is handed to it, so the one thing its identity can be written
	-- from is its specification, and the palette is part of that
	-- specification (`wp40/r7_settlement.lua`, the "overlay" blueprint kind).
	-- It is also what lets a settlement's shared content channel carry the
	-- road: the channel is closed at load, and a name the road can write but
	-- the channel does not know would only fail on the mapchunk that finally
	-- needs it.
	--
	-- Derived from the same four resolvers the run itself uses plus the two
	-- names the standard is built from, so a change to any of them cannot
	-- leave this list behind.
	function M.palette_names(palette)
		local names, seen, list = {paving(palette), kerb(palette),
			tread(palette), palette.node("post"),
			palette.node("light_post")}, {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 avenue: the palette has no name for a road role", 0)
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
		error("wp13 avenue: unknown axis " .. tostring(axis), 0)
	end

	-- One run of avenue.
	--
	-- `spec`:
	--   axis          "x" or "z", the direction the road runs
	--   at            the OTHER coordinate: the centre line of the road
	--   from, to      inclusive span along `axis`, from <= to
	--   width         odd, default 5 (the contract's gate corridor)
	--   lamp_spacing  default 8
	--   lamp_phase    the position along `axis` the lamp rhythm is anchored
	--                 to, default `from`; a successor emerging the road in
	--                 pieces passes the same phase for every piece, which is
	--                 what keeps one lamp line across a chunk border
	--   id            a label carried into the returned table
	--
	-- `surface(x, z)` returns the y of the topmost terrain node of that
	-- column. It is called exactly once per column this run touches and is
	-- the ONLY source of height in here.
	--
	-- Returns `{cells, lamps, pavement, treads, risers, columns, queries}`:
	-- `cells` is the canonical cell list (z, then y, then x) a writer can
	-- project directly, `lamps` the lamp positions for a lighting landmark,
	-- and the counts are what the KAT holds the run to.
	function M.run(palette, spec, surface)
		if type(surface) ~= "function" then
			error("wp13 avenue: a run needs a surface callback", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 avenue: the run has no span", 0)
		end
		local width = spec.width or M.WIDTH
		if width % 2 ~= 1 or width < 3 then
			error("wp13 avenue: the width " .. tostring(width) ..
				" is not an odd carriageway", 0)
		end
		local half = (width - 1) / 2
		local spacing = spec.lamp_spacing or M.LAMP_SPACING
		local phase = spec.lamp_phase or from
		local at = spec.at
		local buf = parts.buffer()
		local lamps = {}
		local queries = 0

		-- The column (x, z) of position `p` along the run, `offset` lanes to
		-- the side. The side runs with the axis: +x is offset +1 for a road
		-- along z, +z for a road along x, so a lane index means the same
		-- hand of the road whichever way it points.
		local function column(p, offset)
			if dx == 1 then return p, at + offset end
			return at + offset, p
		end
		local function height(x, z)
			local y = surface(x, z)
			queries = queries + 1
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 avenue: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. The carriageway, lane by lane.
		--
		-- The road's walking level is the ONE-LIPSCHITZ UPPER ENVELOPE of the
		-- lane's own surface: the lowest height field that is everywhere at or
		-- above the ground and never changes by more than one node between two
		-- columns. A column whose envelope stands above its ground is filled up
		-- to one course below it and capped with a tread; a column whose
		-- envelope is higher than a neighbour's is a step and is capped with a
		-- tread too, because a one-node change is walked as two half nodes --
		-- the tread's own lower half and its raised half -- and a full cube
		-- there would be a node to jump.
		--
		-- That single rule replaces the per-joint flights the first version
		-- built, and it is what makes the road work where those did not:
		--
		--   * a rise of `h` still climbs over `h` columns, one half node at a
		--     time, which is the contract's stair per terrace rise generalised
		--     to the two-, three- and four-node race terrace steps;
		--   * TWO JOINTS CLOSER THAN THEIR FLIGHTS no longer fight over the
		--     columns between them. The envelope simply rises earlier: the
		--     profile 0, 0, 2, 4 is walked as 1, 2, 3, 4 and the road leaves
		--     the ground where it has to, instead of leaving a wall the
		--     per-joint version could not reach back over;
		--   * and it is CHUNK INDEPENDENT. The envelope of a column depends on
		--     the ground within `reach` columns of it and on nothing else, so
		--     the profile is read that far beyond both ends of the piece and
		--     the union of the pieces is the whole run, cell for cell.
		--
		-- `reach` is the distance a terrace can still raise the envelope here.
		-- WP40 terraces the capital envelope within cut 24 and fill 16, so no
		-- column further than 40 away can lift this one: the influence of a
		-- column decays by exactly one node per column of distance. A caller
		-- that knows its own terrain is flatter may pass a smaller `reach`.
		local reach = spec.reach or M.REACH
		local low_end, high_end = from - reach, to + reach
		local pavement, treads, risers = 0, 0, 0
		for offset = -half, half do
			local ground, level = {}, {}
			for p = low_end, high_end do
				local x, z = column(p, offset)
				ground[p] = height(x, z)
				level[p] = ground[p]
			end
			for p = low_end + 1, high_end do
				if level[p] < level[p - 1] - 1 then level[p] = level[p - 1] - 1 end
			end
			for p = high_end - 1, low_end, -1 do
				if level[p] < level[p + 1] - 1 then level[p] = level[p + 1] - 1 end
			end
			local surface_name = (offset == -half or offset == half) and
				kerb(palette) or paving(palette)
			for p = from, to do
				local x, z = column(p, offset)
				local top = level[p]
				for y = ground[p], top - 1 do
					buf:put(x, y, z, surface_name)
					if y == ground[p] then
						pavement = pavement + 1
					else
						risers = risers + 1
					end
				end
				local before, after = level[p - 1], level[p + 1]
				if top > before or top > after then
					-- A step. The raised half faces the higher neighbour, which is
					-- the way a walker climbs it; a column higher than both is
					-- walked over either half, so the run's own direction decides.
					local sign = (after >= before) and 1 or -1
					parts.stair(buf, x, top, z, tread(palette),
						parts.step_facedir(dx * sign, dz * sign))
					treads = treads + 1
				else
					buf:put(x, top, z, surface_name)
				end
				if top == ground[p] then pavement = pavement + 1 end
			end
		end

		-- 2. The lamps: a standard on each verge, one node outside the
		-- carriageway, every `spacing` nodes. The verge column carries the
		-- lamp at its OWN surface, so a standard beside a terrace joint
		-- stands on the ground it is next to and not on the road's level.
		--
		-- EVERY STANDARD GETS ITS OWN FOOTING, at the verge column's surface and
		-- in the kerb's material. On ordinary ground that cell is already solid
		-- and the footing is a paving stone under the post; over water it is the
		-- only thing between the post and the river. The run cannot tell the two
		-- apart -- it is a pure function of one surface number and knows nothing
		-- about water -- so it lays the footing unconditionally, which is both
		-- correct and cheaper than a rule with a case in it.
		--
		-- This is not hypothetical: the first engine pass of the WP13 seam took
		-- Highcourt's east avenue across a river as a causeway, and sixteen
		-- standards stood in the water with nothing under them.
		for p = from, to do
			if (p - phase) % spacing == 0 then
				for _, offset in ipairs({-half - 1, half + 1}) do
					local x, z = column(p, offset)
					local y = height(x, z)
					buf:put(x, y, z, kerb(palette))
					buf:put(x, y + 1, z, palette.node("post"))
					buf:put(x, y + 2, z, palette.node("post"))
					parts.floor_torch(buf, palette, x, y + 3, z)
					lamps[#lamps + 1] = {x = x, y = y + 3, z = z}
				end
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
			width = width, cells = cells, lamps = lamps,
			pavement = pavement, treads = treads, risers = risers,
			columns = (to - from + 1) * width, queries = queries,
		}
	end

	return M
end

return loader
