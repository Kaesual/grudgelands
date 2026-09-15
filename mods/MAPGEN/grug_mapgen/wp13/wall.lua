-- WP13 capital curtain wall: the surface overlay that carries a city wall,
-- its turrets and its gatehouses round the 512 envelope of a walled capital.
--
-- WHY THIS IS AN OVERLAY AND NOT A BLUEPRINT
-- ------------------------------------------
-- The capitals contract (docs/research/wp13-capitals-pois-contract.md section
-- 2.1) gives Dur Brannoc, Nhal Veyr and Gor Drazhak a curtain wall on the
-- envelope edge, and the WP13 seam (`wp40/r7_settlement.lua`) offers three
-- kinds of blueprint to put it in. Two of them cannot hold it:
--
--   * an ANCHOR blueprint is anchor-relative and bounded at +-47; a wall side
--     is 513 nodes long and stands 250 nodes further out than that;
--   * a REFERENCE plot is bounded at +-15 and is projected from ONE column, so
--     a wall would need some seventy of them per capital -- seventy identity
--     rows, seventy height queries, and a projection seam every thirty-two
--     nodes, which is exactly where a wall on terraced ground would show a
--     step or a gap.
--
-- The third kind, OVERLAY, is a pure function of the column surface evaluated
-- per mapchunk, and that is what a wall on WP40's terraces actually is: the
-- ground under Dur Brannoc's four wall lines falls by up to 36 nodes along one
-- side in four-node terrace steps (measured on both gate seeds; see
-- docs/research/wp13-dur-brannoc.md section 3). So the wall is authored the way
-- `avenue.lua` authors a road -- as a function -- and it shares that module's
-- one-Lipschitz envelope, because the two problems are the same problem: a
-- walkable level over ground that steps.
--
-- THE RULE, and what it guarantees
-- --------------------------------
-- For each column `p` of a run, `B[p]` is the LOWEST ground under the wall's
-- own footprint at that column and `E` is the one-Lipschitz upper envelope of
-- `B` -- the lowest height field everywhere at or above `B` that never changes
-- by more than a node between two columns. The wall walk is `D = E + RISE`.
-- From that single rule:
--
--   * NO GAP IS POSSIBLE. Every column is masonry from `B[p] - FOOTING`, which
--     is at or below every one of that column's own ground samples, up to
--     `D[p]`. A terrace step makes the neighbouring column start lower and the
--     wall face becomes a staircase of masonry following the ground; it never
--     becomes a hole, because no column's fill begins above its own ground.
--   * THE WALK IS WALKABLE. `D` changes by at most one node per column and a
--     column whose deck stands above a neighbour's is capped with a tread, so
--     a four-node terrace step is walked as four half-node stairs.
--   * A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN. `E[p]` depends
--     on the ground within `reach` columns of `p` and on nothing else, which is
--     what lets the successor call this per mapchunk.
--
-- EVERY CELL STAYS INSIDE THE RUN RECTANGLE THE SEAM ACTIVATES ON.
-- `r7_settlement.lua` decides whether a mapchunk is offered a run by testing
-- that mapchunk against `at +- (half + 1)`, which for the contract's five-wide
-- carriageway is three nodes either side of the centre line. A wall cell
-- outside that band would be a cell in a mapchunk the run is never called for.
-- So the wall is five thick, its turrets and gatehouses are seven across, and
-- `M.HALF` is 3: the KAT asserts that no cell of any piece leaves it.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The section. `THICK` is the curtain's own thickness (lanes -2..2),
	-- `HALF` the outermost lane any piece of this module may write, which is
	-- the seam's activation band (see the header).
	M.THICK = 5
	M.HALF = 3
	-- Courses from the envelope to the wall walk, and courses of footing below
	-- the lowest ground of a column.
	M.RISE = 6
	M.FOOTING = 2
	-- The merlon and loophole rhythm, and the lamp rhythm on the walk.
	M.MERLON = 4
	M.LAMP = 16
	-- How far beyond a piece the ground is read; the same number and the same
	-- argument as `avenue.REACH` (WP40 terraces a capital envelope within cut
	-- 24 and fill 16, and a column's influence decays by one node per column).
	M.REACH = 40
	-- A turret is seven across and eleven along, and rises nine courses above
	-- the walk; a gatehouse is seven across and fifteen along.
	M.TURRET_HALF = 5
	M.TURRET_RISE = 9
	M.GATE_HALF = 7
	-- The gate passage, as a half-width: seven columns, which is the avenue's
	-- five-wide carriageway plus the two verges its lamp standards stand on.
	-- Five would be the carriageway alone, and the capital's lamp rhythm puts a
	-- standard exactly in the gate: with a five-wide passage those two posts
	-- would be walled into the piers, because the avenue is authored before the
	-- wall and wins every cell the two share.
	M.GATE_PASSAGE = 3

	-- The wall vocabulary, each with the same fallback into the start
	-- vocabulary `capitals.lua` uses, so a palette without the capital roles
	-- still builds a wall.
	local function stone(palette)
		return palette.maybe("castle_wall") or palette.node("wall_accent")
	end
	local function spoil(palette)
		return palette.maybe("castle_rubble") or palette.node("rubble")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end
	local function mark_slab(palette)
		return palette.maybe("signature_slab") or palette.node("roof_slab")
	end

	-- Every node name a run may write, in ASCII byte order and without
	-- duplicates -- the same contract `avenue.palette_names` answers, and for
	-- the same two reasons: an overlay has no cells, so its identity is written
	-- from its specification, and the settlement's shared content channel is
	-- closed over this list at load.
	--
	-- `air` is in it because a wall CLEARS: the walk's headroom and the gate
	-- passage are authored air, and a name the channel does not know would only
	-- fail on the mapchunk that finally needs it.
	function M.palette_names(palette)
		local names = {parts.AIR, stone(palette), spoil(palette),
			paving(palette), tread(palette), mark(palette), mark_slab(palette),
			palette.node("light_wall")}
		local slit = palette.maybe("castle_slit")
		if slit then names[#names + 1] = slit end
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 wall: the palette has no name for a wall role", 0)
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
		error("wp13 wall: unknown axis " .. tostring(axis), 0)
	end

	-- One piece of curtain wall.
	--
	-- `spec` is the seam's own overlay spec, identical to the one `avenue.run`
	-- is handed (`wp40/r7_settlement.lua`, the overlay branch of `settle`):
	--   axis, at        the run's direction and its centre line
	--   from, to        the inclusive span of THIS PIECE along the axis
	--   lamp_phase      the WHOLE run's start, which anchors every rhythm, so
	--                   the merlons and the lamps survive a mapchunk border
	--   reach           the look-around
	--
	-- `plan` is the run's own authored geometry, the same table for every
	-- piece, because a piece may not know less than the whole run does:
	--   outside         +1 or -1: which lane sign faces the field
	--   towers          positions along the axis carrying a turret
	--   cross_towers    the subset that also opens on the CITY face, which is
	--                   how the wall that meets this one at a corner gets in
	--   gates           positions along the axis carrying a gatehouse
	--
	-- `surface(x, z)` is the only source of height, called once per column.
	function M.run(palette, spec, surface, plan)
		if type(surface) ~= "function" then
			error("wp13 wall: a run needs a surface callback", 0)
		end
		if type(plan) ~= "table" or (plan.outside ~= 1 and plan.outside ~= -1) then
			error("wp13 wall: a run needs its authored plan", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 wall: the run has no span", 0)
		end
		local at = spec.at
		local outside = plan.outside
		local phase = spec.lamp_phase or from
		local reach = spec.reach or M.REACH
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
				error("wp13 wall: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. The ground, the lowest of it per column, and the envelope.
		--
		-- All seven lanes are read, not the five the curtain stands on: a
		-- turret and a gatehouse are seven across and their footing has to
		-- reach the ground under their own outermost course. Reading them
		-- everywhere costs two columns per position and buys one rule instead
		-- of two.
		local low_end, high_end = from - reach, to + reach
		local base, level = {}, {}
		for p = low_end, high_end do
			local lowest
			for lane = -M.HALF, M.HALF do
				local x, z = column(p, lane)
				local y = height(x, z)
				if lowest == nil or y < lowest then lowest = y end
			end
			base[p] = lowest
			level[p] = lowest
		end
		for p = low_end + 1, high_end do
			if level[p] < level[p - 1] - 1 then level[p] = level[p - 1] - 1 end
		end
		for p = high_end - 1, low_end, -1 do
			if level[p] < level[p + 1] - 1 then level[p] = level[p + 1] - 1 end
		end
		local function deck(p) return level[p] + M.RISE end

		-- 2. Where the special pieces are, as a lookup over this piece's own
		-- span plus the reach, so a turret whose centre is outside the piece
		-- still writes the part of itself that is inside it.
		local turret_of, cross_of, gate_of = {}, {}, {}
		local function mark_span(map, centre, half, value)
			for p = centre - half, centre + half do
				if p >= low_end and p <= high_end then map[p] = value end
			end
		end
		for index = 1, #(plan.towers or {}) do
			local centre = plan.towers[index]
			mark_span(turret_of, centre, M.TURRET_HALF, centre)
		end
		for index = 1, #(plan.cross_towers or {}) do
			cross_of[plan.cross_towers[index]] = true
		end
		for index = 1, #(plan.gates or {}) do
			local centre = plan.gates[index]
			mark_span(gate_of, centre, M.GATE_HALF, centre)
		end

		-- 3. The curtain, column by column.
		local pavement, treads, merlons, slits, lamps = 0, 0, 0, 0, 0
		local outer, inner = 2 * outside, -2 * outside
		local STONE, SPOIL = stone(palette), spoil(palette)
		local PAVING, TREAD = paving(palette), tread(palette)
		local MARK, MARK_SLAB = mark(palette), mark_slab(palette)
		local SLIT = palette.maybe("castle_slit")

		for p = from, to do
			local foot = base[p] - M.FOOTING
			local top = deck(p)
			local gate = gate_of[p]
			local in_passage = gate ~= nil and
				p >= gate - M.GATE_PASSAGE and p <= gate + M.GATE_PASSAGE

			if in_passage then
				-- THE GATE PASSAGE, five columns wide along the run, which is
				-- the contract's own gate corridor. No masonry below the walk:
				-- the tunnel is authored as air through the whole thickness,
				-- from ONE COURSE ABOVE the column's lowest ground to one
				-- course under the deck.
				--
				-- One course above, not from the footing: the road through the
				-- gate is the AVENUE overlay's, it is authored before this one
				-- and therefore wins every cell the two share
				-- (`r7_settlement.lua`, cross-run arbitration rule 1), and it
				-- writes its pavement from the GROUND upward. Clearing under
				-- the ground would leave that pavement over a two-node void
				-- that only the arch would show.
				for lane = -M.HALF, M.HALF do
					local x, z = column(p, lane)
					buf:put(x, base[p], z, PAVING)
					buf:clear(x, base[p] + 1, z, x, top - 1, z)
				end
			else
				-- The two faces and the rubble core, from the footing to the
				-- walk. This is the whole of the no-gap guarantee: the fill
				-- starts under the column's OWN lowest ground, so a terrace
				-- step simply makes the next column start lower.
				for lane = -2, 2 do
					local x, z = column(p, lane)
					local name = (lane == -2 or lane == 2) and STONE or SPOIL
					for y = foot, top - 1 do buf:put(x, y, z, name) end
				end
				-- A string course of the signature material, three under the
				-- walk, on both faces: what makes 500 nodes of masonry read as
				-- a wall and not as a cliff.
				for _, lane in ipairs({-2, 2}) do
					local x, z = column(p, lane)
					if top - 3 >= foot then buf:put(x, top - 3, z, MARK) end
				end
			end

			-- The deck. Over the passage it is the tunnel's ceiling as well,
			-- so it is written in both cases.
			for lane = -2, 2 do
				local x, z = column(p, lane)
				if lane == -2 or lane == 2 then
					buf:put(x, top, z, STONE)
				else
					local before, after = deck(p - 1), deck(p + 1)
					if top > before or top > after then
						-- A step in the walk, capped with a tread: a one-node
						-- change is walked as the two halves of one stair, and
						-- a full cube there is a node to jump.
						local sign = (after >= before) and 1 or -1
						parts.stair(buf, x, top, z, TREAD,
							parts.step_facedir(dx * sign, dz * sign))
						treads = treads + 1
					else
						buf:put(x, top, z, PAVING)
						pavement = pavement + 1
					end
				end
			end

			-- The headroom over the walk, so an uphill shoulder of terrace or a
			-- tree the decoration pass put here is not left standing in the
			-- rampart.
			for lane = -1, 1 do
				local x, z = column(p, lane)
				buf:clear(x, top + 1, z, x, top + 3, z)
			end

			-- The parapets: the outer one crenellated and capped with the
			-- signature slab, the inner one a single waist course, because a
			-- walkway with a fall on both sides is not a walkway.
			local ox, oz = column(p, outer)
			local ix, iz = column(p, inner)
			buf:put(ox, top + 1, oz, STONE)
			buf:put(ix, top + 1, iz, STONE)
			local beat = (p - phase) % M.MERLON
			if beat < 0 then beat = beat + M.MERLON end
			if beat == 0 or beat == 1 then
				buf:put(ox, top + 2, oz, STONE)
				buf:put(ox, top + 3, oz, MARK_SLAB)
				merlons = merlons + 1
			end
			-- A loophole in the outer face, on the same rhythm as the merlons
			-- above it, two courses under the walk so a defender behind it is
			-- standing on the deck.
			if beat == 2 and not in_passage and SLIT then
				buf:put(ox, top - 2, oz, SLIT,
					parts.step_facedir(dx == 1 and 0 or outside,
						dx == 1 and outside or 0))
				slits = slits + 1
			end
			-- A lamp on the inner face of the outer parapet, which is the one
			-- piece of masonry at lamp height that every column has.
			if (p - phase) % M.LAMP == 0 and not in_passage then
				local lx, lz = column(p, outside)
				-- The step runs from the torch to the masonry carrying it: one
				-- lane further out, which is the outer parapet written above.
				parts.wall_torch(buf, palette, lx, top + 1, lz,
					(dx == 1) and 0 or outside, 0, (dx == 1) and outside or 0)
				lamps = lamps + 1
			end
		end

		-- 4. The turrets and the gatehouse chambers, which are the same piece
		-- of architecture at two lengths: a box seven across standing on the
		-- walk, open along the run at walk height so the rampart passes
		-- through it, with a fighting floor and a crenellated crown.
		local function chamber(centre, half, cross, passage)
			local first, last = centre - half, centre + half
			local crown = nil
            for p = first, last do
				if p >= low_end and p <= high_end then
					local top = deck(p)
					if crown == nil or top > crown then crown = top end
				end
			end
			if crown == nil then return end
			local floor_y = crown + M.TURRET_RISE - 3
			for p = math.max(first, from), math.min(last, to) do
				local top = deck(p)
				local foot = base[p] - M.FOOTING
				local edge = (p == first or p == last)
				-- A gate passage column carries NO masonry under the walk, not
				-- even on the projecting faces: those two lanes are the mouth
				-- of the tunnel, and filling them walls the gate up.
				local open = passage ~= nil and
					p >= centre - passage and p <= centre + passage
				for lane = -M.HALF, M.HALF do
					local x, z = column(p, lane)
					local wall_lane = (lane == -M.HALF or lane == M.HALF)
					-- The projecting faces carry their own footing to the
					-- ground: a turret standing on nothing is the defect this
					-- whole module exists to make impossible.
					if wall_lane and not open then
						for y = foot, top do buf:put(x, y, z, STONE) end
					elseif wall_lane then
						-- Over the mouth of the tunnel the same lane carries
						-- only the course the chamber stands on, which is the
						-- arch's own springing.
						buf:put(x, top, z, STONE)
					end
					-- The chamber's own walls, from the walk to the fighting
					-- floor.
					if wall_lane or edge then
						for y = top + 1, floor_y do buf:put(x, y, z, STONE) end
					else
						buf:clear(x, top + 1, z, x, floor_y - 1, z)
					end
					if not wall_lane and not edge then
						buf:put(x, floor_y, z, PAVING)
					end
				end
				-- The rampart passes THROUGH: a three-wide, three-high opening
				-- in each end face. Without it the wall walk dead-ends at every
				-- turret, which is the defect the capital-parts review found in
				-- the gatehouse (wp13-capital-library.md section 3b, M1).
				if edge then
					for lane = -1, 1 do
						local x, z = column(p, lane)
						buf:clear(x, top + 1, z, x, top + 3, z)
					end
				end
			end
			-- The city-face opening of a corner turret, which is how the wall
			-- that meets this one at right angles gets onto the rampart.
			if cross then
				local lane = -M.HALF * outside
				for p = math.max(centre - 1, from), math.min(centre + 1, to) do
					local x, z = column(p, lane)
					local top = deck(p)
					buf:clear(x, top + 1, z, x, top + 3, z)
				end
			end
			-- The crown: a course all round, merlons on a two-node rhythm and
			-- the signature cap on each of them.
			for p = math.max(first, from), math.min(last, to) do
				for lane = -M.HALF, M.HALF do
					if p == first or p == last or lane == -M.HALF or
							lane == M.HALF then
						local x, z = column(p, lane)
						buf:put(x, floor_y + 1, z, STONE)
						if (p + lane) % 2 == 0 then
							buf:put(x, floor_y + 2, z, STONE)
							buf:put(x, floor_y + 3, z, MARK_SLAB)
						end
					end
				end
			end
		end

		local seen_turret = {}
		for p = from, to do
			local centre = turret_of[p]
			if centre and not seen_turret[centre] then
				seen_turret[centre] = true
				chamber(centre, M.TURRET_HALF, cross_of[centre] == true, nil)
			end
			local gate = gate_of[p]
			if gate and not seen_turret["gate:" .. gate] then
				seen_turret["gate:" .. gate] = true
				chamber(gate, M.GATE_HALF, false, M.GATE_PASSAGE)
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
			-- An overlay's caller drops a LAMP that would stand in another
			-- road's carriageway; a wall lamp is a torch on its own masonry and
			-- there is never another run inside a wall, so the list is empty
			-- and the arbitration has nothing to do.
			lamps = {},
			pavement = pavement, treads = treads, merlons = merlons,
			arrowslits = slits, wall_lamps = lamps,
			columns = to - from + 1, queries = queries,
		}
	end

	return M
end

return loader
