-- WP13 capital GROVE EDGE: the surface overlay that carries an open capital's
-- planted boundary and its four thresholds round the 512 envelope.
--
-- WHY THIS EXISTS AND WHY IT IS AN OVERLAY
-- ----------------------------------------
-- The capitals contract's section 4 records the user's ruling of 2026-09-14:
-- three capitals are walled and three are open, and Lethariel is one of the
-- two that stayed open after the round-3 plan moved Highcourt. An open capital
-- still needs an EDGE -- the round-3 playtest's own verdict on a capital
-- without one was that it "reads as a field with houses in it" -- and for the
-- elf the contract's section 2.4 says what it is made of: "groves between
-- plots, no curtain wall".
--
-- So this module is `wall.lua`'s place in the composition with masonry taken
-- out of it: a planted belt along the envelope line, a silverwood standard
-- every twelve columns, a lantern every thirty-two, a denser grove at each
-- corner, and at each of the four gate axes a THRESHOLD -- two pairs of marble
-- pillars carrying a lintel over the road, which is what marks a way in when
-- there is no gate to open. Lane R ends its four routes at exactly those
-- points.
--
-- It is an OVERLAY for the same reason a wall is: an anchor blueprint is
-- bounded at +-47 and a reference plot at +-15, while an envelope side is 513
-- nodes long and stands 250 nodes further out, and the belt has to follow
-- whatever the terrain does under it. An overlay is a pure function of the
-- column surface evaluated per mapchunk, and that is what a hedge on a terrace
-- actually is.
--
-- THE RULE, and what it guarantees
-- --------------------------------
-- Every cell of a column is written relative to THAT COLUMN'S OWN GROUND, read
-- through the seam's surface callback. Nothing is carried between columns
-- except the gate arch, whose level is the lowest ground over its own
-- sixteen-column zone. From that:
--
--   * A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN. A column's
--     cells depend on its own seven lanes and, inside a gate zone, on the
--     ground within eight columns -- and the seam's look-around is forty. The
--     KAT cuts a run at every column and compares the union with the whole.
--   * NO CELL LEAVES THE SEAM'S ACTIVATION BAND. `r7_settlement.lua` offers a
--     mapchunk a run when the chunk meets `at +- (half + 1)`, which for the
--     contract's five-wide carriageway is three nodes either side of the
--     centre line, so `M.HALF` is 3 and every piece of this module is held to
--     it.
--   * THE BELT STOPS AT THE WATER. A run may carry `plan.water`, the spans of
--     itself that stand over a planned water body; nothing is written there,
--     because a hedge floating on a lake is not an edge and the lake already
--     is one. Lethariel's west line has one such span and the other three have
--     none, measured on all nine seeds of the capital anchor fixture -- a
--     planned water body is a property of the static world plan, not of the
--     seed.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The outermost lane any piece of this module may write, which is the
	-- seam's activation band, and the lane the hedge rows stand on.
	M.HALF = 3
	M.BELT = 2
	-- Courses of clipped hedge above a column's own ground.
	M.HEDGE = 3
	-- The rhythms, anchored on the run's own start so they survive a mapchunk
	-- border.
	M.STANDARD = 12
	M.STANDARD_HEIGHT = 8
	M.LAMP = 32
	-- The threshold: the zone it owns, the columns it leaves completely clear
	-- for the road, and the height its lintel springs to.
	M.GATE_HALF = 8
	M.GATE_PASSAGE = 3
	M.RISE = 7
	-- The corner grove.
	M.CORNER_HALF = 6
	-- How far beyond a piece the ground is read. The same number and the same
	-- argument as `avenue.REACH`; this module needs only eight of it (the gate
	-- zone) but takes what the seam offers.
	M.REACH = 40

	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end
	local function mark_slab(palette)
		return palette.maybe("signature_slab") or palette.node("roof_slab")
	end
	local function hedge_leaf(palette)
		return palette.maybe("hedge") or palette.node("tree_leaves")
	end
	local function hedge_stem(palette)
		return palette.maybe("hedge_stem") or palette.node("tree_log")
	end

	-- Every node name a run may write, in ASCII byte order and without
	-- duplicates -- the contract `avenue.palette_names` answers and for the
	-- same two reasons: an overlay has no cells, so its identity is written
	-- from its specification, and the settlement's shared content channel is
	-- closed over this list at load.
	--
	-- `air` is in it because a threshold CLEARS its own passage.
	function M.palette_names(palette)
		local names = {parts.AIR, paving(palette), mark(palette),
			mark_slab(palette), hedge_leaf(palette), hedge_stem(palette),
			palette.node("tree_log"), palette.node("tree_leaves"),
			palette.node("ground")}
		for _, role in ipairs({"light_beacon", "light_hanging"}) do
			local name = palette.maybe(role)
			if name then names[#names + 1] = name end
		end
		for _, suffix in ipairs({"_bottom", "_middle", "_top"}) do
			local name = palette.variant("pillar", suffix)
			if name then names[#names + 1] = name end
		end
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 elf grove: the palette has no name for an edge " ..
					"role", 0)
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
		error("wp13 elf grove: unknown axis " .. tostring(axis), 0)
	end

	-- One piece of grove edge.
	--
	-- `spec` is the seam's own overlay spec, identical to the one `avenue.run`
	-- is handed: axis, at, from, to (THIS PIECE's span), lamp_phase (the WHOLE
	-- run's start, which anchors every rhythm) and reach.
	--
	-- `plan` is the run's authored geometry, the same table for every piece:
	--   outside   +1 or -1: which lane sign faces the field
	--   gates     positions along the axis carrying a threshold
	--   corners   positions carrying the denser corner grove
	--   water     spans {from, to} of the run that stand over planned water
	--
	-- `surface(x, z)` is the only source of height, called once per column.
	function M.run(palette, spec, surface, plan)
		if type(surface) ~= "function" then
			error("wp13 elf grove: a run needs a surface callback", 0)
		end
		if type(plan) ~= "table" or
				(plan.outside ~= 1 and plan.outside ~= -1) then
			error("wp13 elf grove: a run needs its authored plan", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 elf grove: the run has no span", 0)
		end
		local at = spec.at
		local outside = plan.outside
		local inside = -outside
		local phase = spec.lamp_phase or from
		local reach = spec.reach or M.REACH
		if reach < M.GATE_HALF then
			error("wp13 elf grove: the look-around is shorter than a " ..
				"threshold", 0)
		end
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
				error("wp13 elf grove: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. The ground: every lane of every column of this piece plus the
		-- look-around, so a threshold whose centre lies outside the piece
		-- still springs from the same level it does in every other piece.
		local low_end, high_end = from - reach, to + reach
		local lane_ground, base = {}, {}
		for p = low_end, high_end do
			local lanes, lowest = {}, nil
			for lane = -M.HALF, M.HALF do
				local x, z = column(p, lane)
				local y = height(x, z)
				lanes[lane] = y
				if lowest == nil or y < lowest then lowest = y end
			end
			lane_ground[p] = lanes
			base[p] = lowest
		end

		-- 2. Where the special pieces are.
		local gate_of, corner_of = {}, {}
		local function mark_span(map, centre, half, value)
			for p = centre - half, centre + half do
				if p >= low_end and p <= high_end then map[p] = value end
			end
		end
		for index = 1, #(plan.gates or {}) do
			mark_span(gate_of, plan.gates[index], M.GATE_HALF,
				plan.gates[index])
		end
		for index = 1, #(plan.corners or {}) do
			mark_span(corner_of, plan.corners[index], M.CORNER_HALF,
				plan.corners[index])
		end
		-- The water the belt stops at.
		local wet = {}
		for index = 1, #(plan.water or {}) do
			local span = plan.water[index]
			for p = span[1], span[2] do wet[p] = true end
		end

		-- THE LEVEL A THRESHOLD SPRINGS FROM: one level for the whole gate
		-- zone, so its pillars and its lintel are one piece of architecture
		-- and not a staircase, and high enough that the road under it is a
		-- road everywhere.
		--
		-- `lowest + RISE` alone is not enough, and the KAT is what said so: on
		-- ground that climbs across the zone the arch springs from the low end
		-- and comes down to meet the high end, and at the high end the lintel
		-- stood four courses over the carriageway -- head height for a player
		-- two nodes tall. So the level is the HIGHER of the two rules: seven
		-- over the lowest ground, and four over the highest, which is the
		-- three blocks of air `avenue.MIN_CLEAR` asks for plus the deck.
		local gate_level = {}
		local function level_of(centre)
			if gate_level[centre] then return gate_level[centre] end
			local lowest, highest
			for p = centre - M.GATE_HALF, centre + M.GATE_HALF do
				local value = base[p]
				if value ~= nil then
					if lowest == nil or value < lowest then lowest = value end
					if highest == nil or value > highest then
						highest = value
					end
				end
			end
			local level = lowest + M.RISE
			if highest + 4 > level then level = highest + 4 end
			gate_level[centre] = level
			return level
		end

		local LEAF, STEM = hedge_leaf(palette), hedge_stem(palette)
		local LOG = palette.node("tree_log")
		local CROWN = palette.node("tree_leaves")
		local MARK, MARK_SLAB = mark(palette), mark_slab(palette)
		local PAVING = paving(palette)
		local BEACON = palette.maybe("light_beacon")
		local PILLAR = palette.variant("pillar", "_bottom")

		local function pillar(x, y0, y1, z)
			if PILLAR == nil then
				for y = y0, y1 do buf:put(x, y, z, MARK) end
				return
			end
			buf:put(x, y0, z, PILLAR)
			for y = y0 + 1, y1 - 1 do
				buf:put(x, y, z, palette.variant("pillar", "_middle"))
			end
			if y1 > y0 then
				buf:put(x, y1, z, palette.variant("pillar", "_top"))
			end
		end

		-- A silverwood standard, written COLUMN BY COLUMN.
		--
		-- The crown of a standard reaches two nodes along the run as well as
		-- two across it, so a standard whose centre sits at the very edge of a
		-- piece has cells in the NEXT piece -- and the next piece, computing
		-- itself, would never write them. That is exactly the property this
		-- module has to keep ("a piece of a run is exactly that stretch of the
		-- whole run"), so nothing is ever emitted for a column but that
		-- column's own cells: a standard centred at `p0` is asked what it puts
		-- in column `p`, and every column asks every standard within two of
		-- it.
		--
		-- The first version wrote the whole tree from its centre. The
		-- integration fixture found it: 228 of Lethariel's 353 834 cells were
		-- in the oracle and never written by any mapchunk.
		local function standard_column(p, p0, lane, ground)
			local top = ground + M.STANDARD_HEIGHT
			local dq = p - p0
			if dq == 0 then
				for y = ground + 1, top do
					local x, z = column(p, lane)
					buf:put(x, y, z, LOG)
				end
				local x, z = column(p, lane)
				buf:put(x, top + 1, z, CROWN)
				buf:put(x, top + 2, z, CROWN)
			end
			for step = 1, 5 do
				local y = top - 5 + step
				local spread = (step % 2 == 1) and 1 or 2
				if math.abs(dq) <= spread then
					for dlane = -spread, spread do
						if (dq ~= 0 or dlane ~= 0) and
								math.abs(lane + dlane) <= M.HALF then
							local x, z = column(p, lane + dlane)
							buf:put(x, y, z, CROWN)
						end
					end
				end
			end
		end

		local hedges, standards, lamps, thresholds = 0, 0, 0, 0

		-- Which columns carry a standard, over the piece PLUS the two columns
		-- either side of it, so a crown reaching in from outside is written by
		-- the column it lands in. The rhythm is a pure function of the
		-- position, which is what lets every piece agree about it.
		local standard_lanes = {}
		for p = math.max(low_end, from - 2), math.min(high_end, to + 2) do
			if not wet[p] and gate_of[p] == nil then
				local corner = corner_of[p]
				if corner ~= nil then
					if (p - corner) % 3 == 0 then
						standard_lanes[p] = {-M.BELT + 1, M.BELT - 1}
					end
				elseif (p - phase) % M.STANDARD == 0 then
					standard_lanes[p] = {0}
				end
			end
		end

		for p = from, to do
			local ground = base[p]
			local lanes = lane_ground[p]
			local gate = gate_of[p]
			local corner = corner_of[p]
			if wet[p] then
				-- The mere is the edge here, and nothing is written on it.
			elseif gate ~= nil then
				local level = level_of(gate)
				local offset = p - gate
				local absolute = math.abs(offset)
				if absolute <= M.GATE_PASSAGE then
					-- THE PASSAGE. The road through the threshold is the
					-- AVENUE overlay's, it is authored before this one and
					-- wins every cell the two share; this run only makes sure
					-- nothing of its own stands in the way, and carries the
					-- lintel over it.
					for lane = -M.HALF, M.HALF do
						local x, z = column(p, lane)
						buf:clear(x, lanes[lane] + 1, z, x, level - 1, z)
					end
					if absolute <= 4 then
						local x, z = column(p, 0)
						buf:put(x, level, z, MARK)
						buf:put(x, level + 1, z, MARK_SLAB)
					end
				elseif absolute == 4 then
					-- THE TWO PAIRS OF PILLARS, one pair either side of the
					-- road on the belt's centre lane and one on its outer
					-- lanes, with the lintel between them.
					for _, lane in ipairs({0, M.BELT, -M.BELT}) do
						local x, z = column(p, lane)
						buf:put(x, lanes[lane], z, PAVING)
						pillar(x, lanes[lane] + 1, level - 1, z)
						buf:put(x, level, z, MARK)
						buf:put(x, level + 1, z, MARK_SLAB)
					end
					-- The lantern hung under the head of each pillar pair.
					local x, z = column(p, 0)
					if parts.hanging_light(buf, palette, x, level - 1, z)
							~= false then
						lamps = lamps + 1
					end
					thresholds = thresholds + 1
				else
					-- The threshold's own landing: paving either side of the
					-- road, which is what makes the four pillars stand on
					-- something rather than in the grass.
					for lane = -M.BELT, M.BELT do
						local x, z = column(p, lane)
						buf:put(x, lanes[lane], z, PAVING)
						buf:clear(x, lanes[lane] + 1, z, x, lanes[lane] + 4, z)
					end
				end
			elseif corner ~= nil then
				-- THE CORNER GROVE: standards on both belt lanes every third
				-- column and no hedge, so the four corners of the envelope
				-- read as a wood and not as a hedge that turns a right angle.
				-- The trees themselves are written by the column pass below.
				if (p - corner) % 3 == 0 then standards = standards + 2 end
			else
				-- THE BELT: two clipped rows of silverwood hedge with kept
				-- turf between them, each row following its OWN lane's ground.
				for _, lane in ipairs({-M.BELT, M.BELT}) do
					local x, z = column(p, lane)
					local g = lanes[lane]
					buf:put(x, g + 1, z, STEM)
					for y = g + 2, g + M.HEDGE do
						buf:put(x, y, z, LEAF)
					end
					hedges = hedges + 1
				end
				if (p - phase) % M.STANDARD == 0 then
					standards = standards + 1
				end
				if (p - phase) % M.LAMP == 0 and BEACON then
					local lane = inside * M.HALF
					local x, z = column(p, lane)
					local g = lanes[lane]
					buf:put(x, g + 1, z, MARK)
					buf:put(x, g + 2, z, BEACON, 0)
					buf:put(x, g + 3, z, MARK_SLAB)
					lamps = lamps + 1
				end
			end
		end

		-- The standards, column by column: every column of this piece asks
		-- every standard within two of it what it puts here.
		for p = from, to do
			for p0 = p - 2, p + 2 do
				local carried = standard_lanes[p0]
				if carried ~= nil then
					for index = 1, #carried do
						local lane = carried[index]
						standard_column(p, p0, lane, lane_ground[p0][lane])
					end
				end
			end
		end

		local order, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = order[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		-- `lamps` is the LIST of lamp standards a road run publishes, and the
		-- seam's own arbitration reads it (a standard that falls in another
		-- run's carriageway is dropped). This run plants none of that kind, so
		-- the list is empty and its own lantern count travels beside it under
		-- its own name.
		return {id = spec.id, cells = cells, lamps = {}, hedges = hedges,
			standards = standards, lanterns = lamps, thresholds = thresholds,
			columns = to - from + 1, queries = queries}
	end

	return M
end

return loader
