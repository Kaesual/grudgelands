-- WHERE A CAPITAL'S STREETS MEET EACH OTHER.
--
-- `wp13/avenue.lua` is a pure function of ONE run and knows nothing about the
-- road it crosses. That is what makes it emergeable per mapchunk, and it is
-- also why playtest 5 found what it found: at a crossing on a slope the two
-- runs walk at two different heights, the successor's first-run-wins
-- arbitration hands the square to whichever run was authored first, and the
-- other one arrives at a wall. The user's ruling of 2026-09-16 is that
--
--     "the connecting street must be raised artificially at the junction" --
--     every junction is a SQUARE PLATEAU on one y, and every run arriving at
--     it meets that y with steps of at most one node per column.
--
-- A plateau is a property of TWO runs, so somebody has to know both. This
-- module is that somebody, and it knows nothing else: it takes a capital's
-- street runs -- the rectangles, not the ground -- and answers, for each run,
-- the squares it shares with another street and which stretch of the other run
-- those squares are. `avenue.run` then computes the plateau's HEIGHT itself,
-- from the two runs' ground, by the rule its own header states.
--
-- WHY THE RECTANGLES AND NOT THE HEIGHTS. A run list is static: it is the same
-- on every world and every seed, it is what the overlay's identity is already
-- hashed from (`wp40/r7_settlement.lua`, `prepare_overlay`), and it is
-- therefore free to compute and safe to compute anywhere. The heights are the
-- seed's, and they stay where the road is.
--
-- WHAT COUNTS AS A JUNCTION. Two street runs whose CARRIAGEWAYS -- the `width`
-- lanes either run paves, not the verges beside them -- share at least one
-- column, and which cross at a right angle. Two PARALLEL runs that overlap are
-- not a crossing: they share a stretch of road, and a plateau over such a
-- stretch would flatten a whole street rather than level a square. They are
-- returned separately as `overlaps`, with the rectangle they share, and
-- `tools/wp13/street_kat.lua` pins the inventory.
--
-- MEASURED, on all six capitals (tools/wp13/street_geometry.lua): since round 4
-- (2026-09-16) there are TWELVE, and every one of them is the same thing.
--
--   * TWELVE BUTT JOINTS -- one continuous lane authored as two runs meeting
--     end to end, sharing exactly one column (Dur Brannoc, Gor Drazhak and Nhal
--     Veyr, four each). Those need nothing: the road's level at a column
--     depends on the ground within `reach` of it, both runs read that same
--     ground, and both therefore walk the shared column at the same height.
--   * NO SIDE-BY-SIDE STRETCH. Wave 3 measured six of them, all Lethariel's,
--     where a district lane at +-98 ran alongside the ring street at +-96 for
--     up to 97 columns and three of the five lanes of each were the same
--     columns -- which the user then walked into ("two streets overlay each
--     other with a 2-node offset across the walking direction", playtest 6).
--     Round 4 put each of those lanes on the RING'S OWN centre line, starting
--     one column past the ring run it continues, so the pair is collinear,
--     shares nothing, and is pinned to one y by the ring corner's own plateau
--     (`wp13/lethariel_quadrants.lua`, THE DISTRICT LANES). Lethariel's two
--     lane/lane butt joints went with them: the ring now stands between the
--     two halves that used to meet at 0.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local avenue = dofile(directory .. "/avenue.lua")(directory)

	local M = {}

	-- The carriageway a junction is measured over is the road's own, so the
	-- default comes from the road module rather than from a number spelled
	-- twice.
	M.WIDTH = avenue.WIDTH

	local function band(run, half)
		if run.axis == "x" then
			return run.from, run.to, run.at - half, run.at + half
		end
		return run.at - half, run.at + half, run.from, run.to
	end

	-- The junctions of a street run list, as `{[run id] = {junction, ...}}`.
	--
	-- A junction record carries the square in EVERY participating run's own
	-- coordinates:
	--
	--   low, high        the positions of the square along THIS run's axis
	--   members          one row per OTHER run of the same junction:
	--                    {id, axis, at, from, to, low, high}, the last two
	--                    being the positions of the same square along ITS axis
	--
	-- so a run can compute the plateau's height from the profiles of everybody
	-- who stands in it, without ever being handed a height.
	--
	-- WHY A RECORD IS A GROUP AND NOT A PAIR. Three streets can meet in one
	-- place: Lethariel's east avenue crosses the ring street at 94..98 and a
	-- district lane at 96..100, and those two squares SHARE three columns. Taken
	-- as two independent pairs they get two different levels -- measured on the
	-- gate seed, 22 and 23 -- and the shared columns then take the higher one,
	-- which leaves the ring street's own square a node out of true. So squares
	-- that share a column on any one run are one junction: they are merged into
	-- the smallest range covering them, on every run that stands in them, and
	-- every member computes the maximum over the same set of profiles and
	-- therefore the same number.
	function M.junctions(runs, width)
		if type(runs) ~= "table" then
			error("wp13 street plan: no run list", 0)
		end
		width = width or M.WIDTH
		if type(width) ~= "number" or width % 2 ~= 1 or width < 3 then
			error("wp13 street plan: the width " .. tostring(width) ..
				" is not an odd carriageway", 0)
		end
		local half = (width - 1) / 2
		local index_of, overlaps = {}, {}
		for index = 1, #runs do
			local run = runs[index]
			if type(run) ~= "table" or type(run.id) ~= "string" or
					(run.axis ~= "x" and run.axis ~= "z") or
					type(run.at) ~= "number" or type(run.from) ~= "number" or
					type(run.to) ~= "number" then
				error("wp13 street plan: run " .. index .. " is not a run", 0)
			end
			if index_of[run.id] then
				error("wp13 street plan: two runs called " .. run.id, 0)
			end
			index_of[run.id] = index
		end

		-- 1. Every crossing, as a pair of ranges -- one per run, in that run's
		-- own coordinates.
		local squares = {}
		for a = 1, #runs do
			for b = a + 1, #runs do
				local one, two = runs[a], runs[b]
				local ax0, ax1, az0, az1 = band(one, half)
				local bx0, bx1, bz0, bz1 = band(two, half)
				local min_x = (ax0 > bx0) and ax0 or bx0
				local max_x = (ax1 < bx1) and ax1 or bx1
				local min_z = (az0 > bz0) and az0 or bz0
				local max_z = (az1 < bz1) and az1 or bz1
				if min_x <= max_x and min_z <= max_z then
					if one.axis == two.axis then
						overlaps[#overlaps + 1] = {one = one.id, two = two.id,
							min_x = min_x, max_x = max_x,
							min_z = min_z, max_z = max_z}
					else
						-- Complete the square around the two centre lines, including
						-- the outside quarter of an L-shaped endpoint junction.
						local across_x = one.axis == "x" and one or two
						local across_z = one.axis == "z" and one or two
						min_x, max_x = across_z.at - half, across_z.at + half
						min_z, max_z = across_x.at - half, across_x.at + half
						local range = {}
						for _, run in ipairs({one, two}) do
							if run.axis == "x" then
								range[run.id] = {min_x, max_x}
							else
								range[run.id] = {min_z, max_z}
							end
						end
						squares[#squares + 1] = {ids = {one.id, two.id},
							range = range}
					end
				end
			end
		end

		-- 2. Two squares that share a column on ANY one run are one junction.
		-- Union-find over the squares, joined through the runs they touch.
		local parent = {}
		for index = 1, #squares do parent[index] = index end
		local function root(index)
			while parent[index] ~= index do
				parent[index] = parent[parent[index]]
				index = parent[index]
			end
			return index
		end
		local function join(one, two)
			local a, b = root(one), root(two)
			if a ~= b then parent[a] = b end
		end
		for a = 1, #squares do
			for b = a + 1, #squares do
				local shared = false
				for id, range in pairs(squares[a].range) do
					local other = squares[b].range[id]
					if other and range[1] <= other[2] and other[1] <= range[2] then
						shared = true
					end
				end
				if shared then join(a, b) end
			end
		end

		-- 3. One record per run per group, over the merged range.
		local groups = {}
		for index = 1, #squares do
			local key = root(index)
			local group = groups[key]
			if group == nil then
				group = {order = {}, range = {}}
				groups[key] = group
			end
			for id, range in pairs(squares[index].range) do
				local merged = group.range[id]
				if merged == nil then
					group.range[id] = {range[1], range[2]}
					group.order[#group.order + 1] = id
				else
					if range[1] < merged[1] then merged[1] = range[1] end
					if range[2] > merged[2] then merged[2] = range[2] end
				end
			end
		end
		local by_id = {}
		for index = 1, #runs do by_id[runs[index].id] = {} end
		for _, group in pairs(groups) do
			table.sort(group.order, function(p, q)
				return index_of[p] < index_of[q]
			end)
			for _, id in ipairs(group.order) do
				local mine = group.range[id]
				local members = {}
				for _, other_id in ipairs(group.order) do
					if other_id ~= id then
						local run = runs[index_of[other_id]]
						local range = group.range[other_id]
						members[#members + 1] = {id = run.id, axis = run.axis,
							at = run.at, from = run.from, to = run.to,
							low = range[1], high = range[2]}
					end
				end
				local list = by_id[id]
				local x0, x1, z0, z1
				for _, member_id in ipairs(group.order) do
					local run = runs[index_of[member_id]]
					local range = group.range[member_id]
					if run.axis == "x" then x0, x1 = range[1], range[2]
					else z0, z1 = range[1], range[2] end
				end
				list[#list + 1] = {low = mine[1], high = mine[2],
					members = members, owner = group.order[1],
					min_x = x0, max_x = x1, min_z = z0, max_z = z1}
			end
		end
		-- Sorted by their own position, so the list a run is handed does not
		-- depend on the order the pairs happened to be found in.
		for _, list in pairs(by_id) do
			table.sort(list, function(p, q)
				if p.low ~= q.low then return p.low < q.low end
				return p.high < q.high
			end)
		end
		return by_id, overlaps
	end

	-- WHERE A STREET PASSES THROUGH SOMETHING THAT IS NOT A STREET.
	--
	-- A capital's overlay carries runs that are not roads: the curtain wall, the
	-- orc palisade, the grove edge, Kezamba's gate cones. A road runs THROUGH
	-- them, at a gate, and inside that passage the authored structure owns the
	-- lanes either side of the carriageway -- which is why the kerb parapets
	-- this lane replaced each carried the sentence "a kerb course would be
	-- masonry in the tunnel mouth".
	--
	-- The shared verge rule has to know the same thing, so it is derived here
	-- from the same rectangles the junctions are: `barriers` is a list of
	-- `{runs = <the non-street runs>, half = <that module's own HALF>}`, and the
	-- answer is, per street, the spans along it that a barrier's band covers.
	-- `wp13/avenue.lua` writes no plank, no rail and no pillar there -- a lamp
	-- standard still stands, because a standard is not a walk.
	--
	-- MEASURED: four cells, at `gate - HALF` on the north avenue of Nhal Veyr
	-- (both gate seeds) and of Highcourt (the 531802985935182545 seed). Every
	-- other barrier band in the six capitals is a position the road walks on its
	-- own ground, where the verge writes nothing anyway.
	function M.barrier_spans(streets, barriers, width)
		width = width or M.WIDTH
		local half = (width - 1) / 2
		local by_id = {}
		for index = 1, #streets do by_id[streets[index].id] = {} end
		for _, group in ipairs(barriers or {}) do
			local reach = group.half
			if type(reach) ~= "number" or reach < 0 then
				error("wp13 street plan: a barrier has no half-width", 0)
			end
			for _, barrier in ipairs(group.runs or {}) do
				for _, street in ipairs(streets) do
					if street.axis ~= barrier.axis then
						local low = barrier.at - reach
						local high = barrier.at + reach
						-- The barrier's band crosses this street only where the
						-- street's own carriageway lies inside the barrier's
						-- span, and the span it covers is the band itself,
						-- clipped to the street's run.
						local across_low = street.at - half
						local across_high = street.at + half
						if barrier.from <= across_high and
								barrier.to >= across_low then
							if low < street.from then low = street.from end
							if high > street.to then high = street.to end
							if low <= high then
								local list = by_id[street.id]
								list[#list + 1] = {low, high}
							end
						end
					end
				end
			end
		end
		for _, list in pairs(by_id) do
			table.sort(list, function(p, q)
				if p[1] ~= q[1] then return p[1] < q[1] end
				return p[2] < q[2]
			end)
		end
		return by_id
	end

	-- WHERE A RUN'S VERGE STANDS IN THE MIDDLE OF ANOTHER RUN'S ROAD.
	--
	-- A street's two VERGE lanes are one node outside its carriageway, and
	-- that is where `wp13/avenue.lua` writes the plank walk, the rail, the
	-- pillars and the lamp standards. At a crossing, at a corner and at a
	-- T-joint those two lanes run straight ACROSS the road that joins, so the
	-- furniture of one street stands in the carriageway of the other. Playtest
	-- 6 (2026-09-16) walked into three of them:
	--
	--   * Lethariel's north-east ring corner, where `ring_east` ends at
	--     z = 96 and `ring_north` ends at x = 96 over the mere: "two street
	--     ends meet on a bridge over water; the rail of each protrudes into
	--     the other street";
	--   * Kezamba's north crossing, where `avenue_north` crosses `ring_north`
	--     over water: "the side rails leave only a one-node gap into the
	--     crossing";
	--
	-- and the ruling is that "railings, fences, verge posts and pillars end at
	-- the crossing square; the plateau square is rail-free towards every street
	-- that joins it".
	--
	-- WHY IT IS A RECTANGLE QUESTION AND NOT A PLATEAU QUESTION. The plateau
	-- square is the two carriageways' intersection; the verge lane is one node
	-- OUTSIDE the carriageway, so the cells at issue are beside the square and
	-- not in it, and at a corner only ONE of the two verge lanes is in the
	-- other road at all. What decides it exactly is the column: a verge cell
	-- has to go where its own column is inside another street's carriageway,
	-- and it may stay where it is not -- which keeps the parapet on the
	-- OUTSIDE of a corner, where nothing joins.
	--
	-- THE DECK STAYS CONTINUOUS, and that is the other half of the ruling: the
	-- cell the verge gives up is by construction a cell the other run PAVES, at
	-- the plateau's own y, so the walk is not interrupted -- it is handed over.
	--
	-- Returns, per street id, a sorted list of `{low, high, side}` spans, where
	-- `side` is -1 or +1 in the same hand `avenue.lua` counts its lanes in: the
	-- verge lane at `at + side * (half + 1)`.
	--
	-- STREETS ONLY. The curtain wall, the palisade, the grove edge and the gate
	-- cones are not roads and a street does not yield its rail to them; where a
	-- street runs THROUGH one, `barrier_spans` above is the rule.
	function M.verge_clearance(streets, width)
		width = width or M.WIDTH
		if type(width) ~= "number" or width % 2 ~= 1 or width < 3 then
			error("wp13 street plan: the width " .. tostring(width) ..
				" is not an odd carriageway", 0)
		end
		local half = (width - 1) / 2
		local verge = half + 1
		local by_id = {}
		for index = 1, #streets do by_id[streets[index].id] = {} end
		for _, street in ipairs(streets) do
			local list = by_id[street.id]
			for _, side in ipairs({-1, 1}) do
				local line = street.at + side * verge
				local spans = {}
				for _, other in ipairs(streets) do
					if other.id ~= street.id then
						local low, high
						if other.axis == street.axis then
							-- A PARALLEL run: its carriageway covers this verge
							-- lane over its whole span, or not at all.
							if line >= other.at - half and
									line <= other.at + half then
								low, high = other.from, other.to
							end
						else
							-- A CROSSING run: its carriageway covers this verge
							-- lane only where the lane is inside its span, and
							-- then over its own width.
							if line >= other.from and line <= other.to then
								low, high = other.at - half, other.at + half
							end
						end
						if low ~= nil then
							if low < street.from then low = street.from end
							if high > street.to then high = street.to end
							if low <= high then
								spans[#spans + 1] = {low, high}
							end
						end
					end
				end
				table.sort(spans, function(p, q)
					if p[1] ~= q[1] then return p[1] < q[1] end
					return p[2] < q[2]
				end)
				-- Merged, so the list a run is handed does not depend on how
				-- many other runs happen to cover the same stretch.
				local open
				for index = 1, #spans do
					local span = spans[index]
					if open ~= nil and span[1] <= open[2] + 1 then
						if span[2] > open[2] then open[2] = span[2] end
					else
						open = {span[1], span[2], side}
						list[#list + 1] = open
					end
				end
			end
		end
		for _, list in pairs(by_id) do
			table.sort(list, function(p, q)
				if p[3] ~= q[3] then return p[3] < q[3] end
				if p[1] ~= q[1] then return p[1] < q[1] end
				return p[2] < q[2]
			end)
		end
		return by_id
	end

	-- The same lists, attached to COPIES of the run specs so the composition's
	-- own authored tables are never mutated: two worlds in one process must not
	-- be able to see each other's junctions.
	function M.attach(runs, width, barriers)
		width = width or M.WIDTH
		local junctions = M.junctions(runs, width)
		local extended = {}
		for index, run in ipairs(runs) do
			local copy = {}
			for name, value in pairs(run) do copy[name] = value end
			for _, joint in ipairs(junctions[run.id]) do
				copy.from = math.min(copy.from, joint.low)
				copy.to = math.max(copy.to, joint.high)
			end
			extended[index] = copy
		end
		local passages = M.barrier_spans(extended, barriers, width)
		local clearances = M.verge_clearance(extended, width)
		local out = {}
		for index = 1, #extended do
			local run = extended[index]
			local copy = {}
			for name, value in pairs(run) do copy[name] = value end
			copy.junctions = junctions[run.id]
			local spans = passages[run.id]
			copy.plain_verge = (spans and #spans > 0) and spans or nil
			local clear = clearances[run.id]
			copy.clear_verge = (clear and #clear > 0) and clear or nil
			out[index] = copy
		end
		return out
	end

	return M
end

return loader
