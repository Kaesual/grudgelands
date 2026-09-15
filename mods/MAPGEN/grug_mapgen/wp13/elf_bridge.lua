-- WP13: the elven bridge that carries a capital's road over its own lake
-- without damming it.
--
-- WHY THIS EXISTS
-- ---------------
-- The seam hands a road the WATER surface where water stands rather than the
-- bed under it (`wp40/r7_settlement.lua`, `walkable_values`), so `avenue.lua`
-- lays a solid CAUSEWAY at the water line — which is the right answer for
-- Highcourt's rivers, where a road crossing eight nodes of water is a ford with
-- a bank on either side, and the wrong one for a capital built on a lake.
--
-- Measured on Lethariel (`tools/wp13/lethariel_plots.lua --bodies`): the mere
-- is ONE body of 38 527 columns, and the six road runs that cross it pave 2 410
-- of them — cutting it into SIX lakes, the north avenue alone shearing a
-- 2 000-column bay off the main water. The independent review of 2026-09-16
-- found it; **the coordinator's ruling is that a water body stays one body**,
-- and that where an avenue crosses water it runs as a bridge with the water
-- continuous beneath.
--
-- THE RULE
-- --------
-- This module is a pure post-process on the piece `avenue.run` has just
-- returned. For every column of the run the committed water plan calls wet:
--
--   1. every cell the road wrote in that column is DROPPED. Over water they are
--      the causeway, and a causeway is the thing being removed;
--   2. the deck goes at `max(the road's own top cell, water + lift)`. The
--      water is the LOWEST of the carriageway's own lanes -- at the shore some
--      of them are dry bank standing above it, and the deck is meant to clear
--      the water, not the bank -- and the lift RAMPS: nothing at a span's first
--      and last column, so the bridge starts flush with the road it continues,
--      then a node a column inwards up to `LIFT`. Every term is 1-Lipschitz in
--      the column and so is their maximum, so the deck never steps more than a
--      node, and a step is capped with a tread exactly as the road caps its
--      own;
--   3. it is seven lanes wide: the five of the carriageway in the road's own
--      paving and kerb, and a plank verge either side under a rail, so a walker
--      cannot step off it;
--   4. the PIERS stand on the two VERGE lanes and nowhere else, every `PIER`
--      columns, reaching from one node under the deck down past the water
--      surface into the bed. The whole five-wide carriageway is therefore open
--      water underneath, along the run and across it, which is what keeps the
--      lake one lake;
--   5. a lantern on the deck every `LAMP` columns, because the road's own
--      standards stood on the water surface and went with the causeway.
--
-- WHY A COMMITTED WATER PLAN AND NOT A WATER QUERY. An overlay is handed
-- `surface(x, z)` and nothing else — there is no water predicate at this seam,
-- and inventing one would mean a second authority for where the lake is. The
-- spans are measured from WP40's own `water_class_at` by
-- `tools/wp13/lethariel_plots.lua --water`, which also proves they are the same
-- on all nine fixture seeds: a planned water body is a property of the static
-- world plan and not of the seed.
--
-- A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN. Every cell of a
-- column depends on that column's own surface, on its two neighbours' deck
-- levels (which are the same pure function) and on the run-wide rhythms
-- anchored on `lamp_phase` — nothing else. The KAT cuts a span at every column
-- and compares the union with the whole.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The deck stands ONE node over the water, and not two: the shore step a
	-- walker takes onto the bridge is exactly that number, and a player jumps
	-- one node.
	M.LIFT = 1
	-- A pier every eight columns, reaching four nodes under the water surface.
	M.PIER = 8
	M.PIER_DEPTH = 4
	-- A lantern every sixteen, which is the rhythm of the grove edge's own.
	M.LAMP = 16

	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end

	-- Every node name a bridged column may write, in ASCII byte order and
	-- without duplicates. `air` is in it because a bridged column CLEARS the
	-- causeway the road put there.
	function M.palette_names(palette)
		local names = {parts.AIR, paving(palette), kerb(palette),
			tread(palette), mark(palette), palette.node("floor"),
			palette.node("railing"), palette.node("post"),
			palette.node("light_post")}
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 elf bridge: the palette has no name for a bridge " ..
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

	-- Carry a road piece over its own water.
	--
	-- `spec` is the seam's overlay spec for the ROAD run; `surface(x, z)` the
	-- same callback the road was handed; `piece` what `avenue.run` returned;
	-- `spans` the run's committed wet spans, `{{from, to}, ...}` along its axis.
	--
	-- Returns the same piece table, with its cells replaced over the spans and
	-- `bridge` describing what was built.
	function M.span(palette, spec, surface, piece, spans)
		if type(piece) ~= "table" or type(piece.cells) ~= "table" then
			error("wp13 elf bridge: no road piece to carry", 0)
		end
		if spans == nil or #spans == 0 then
			piece.bridge = {columns = 0, piers = 0, lanterns = 0, dropped = 0}
			return piece
		end
		local dx = (spec.axis == "x") and 1 or 0
		local dz = 1 - dx
		local at = spec.at
		local width = spec.width
		if type(width) ~= "number" or width % 2 ~= 1 then
			error("wp13 elf bridge: the run has no carriageway", 0)
		end
		local half = (width - 1) / 2
		local verge = half + 1
		local phase = spec.lamp_phase or spec.from

		local function column(p, lane)
			if dx == 1 then return p, at + lane end
			return at + lane, p
		end
		local function height(x, z)
			local y = surface(x, z)
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 elf bridge: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- Which columns of this piece are over water, and HOW FAR EACH IS FROM
		-- DRY LAND along the run. The distance is what ramps the lift: see
		-- `deck_of`.
		local wet, from_shore = {}, {}
		for index = 1, #spans do
			local span = spans[index]
			for p = span[1], span[2] do
				wet[p] = true
				local reach_in = math.min(p - span[1], span[2] - p)
				if from_shore[p] == nil or reach_in < from_shore[p] then
					from_shore[p] = reach_in
				end
			end
		end

		-- The road's own top cell per column, over the carriageway lanes: the
		-- envelope it walks at. Read off the piece rather than recomputed, so
		-- the bridge and the road cannot disagree about where the road is.
		local road_top = {}
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local p = (dx == 1) and cell.x or cell.z
			local lane = (dx == 1) and (cell.z - at) or (cell.x - at)
			if math.abs(lane) <= half and cell.name ~= parts.AIR then
				if road_top[p] == nil or cell.y > road_top[p] then
					road_top[p] = cell.y
				end
			end
		end

		-- THE DECK, as a pure function of the column: the road's own top where
		-- that is higher, and `LIFT` over the water everywhere else. Asked for
		-- a column's two neighbours as well, so a step can be capped.
		--
		-- TWO THINGS HERE ARE CORRECTIONS WITH A MEASUREMENT BEHIND THEM, both
		-- from the rebase onto Lane R, whose `route_gates.lua` walks a
		-- traveller from outside the gate into the city and refuses any
		-- position that climbs more than a node.
		--
		--   * THE WATER IS THE MINIMUM over the carriageway's own lanes and not
		--     the maximum over all seven. A column at the shore has wet lanes
		--     and dry ones, and the dry bank stands ABOVE the water: taking the
		--     maximum read the bank, added the lift to that, and put the first
		--     plank of the bridge two nodes over the road it continues. The
		--     minimum is the water, which is the thing the deck is meant to
		--     clear.
		--   * THE LIFT RAMPS. A span's own first and last columns take no lift
		--     at all and lie flush with the road, and the lift grows a node a
		--     column inwards. That is what makes the deck 1-LIPSCHITZ rather
		--     than nearly so: at the boundary it IS the road, and inside it is
		--     the road's envelope or the water plus a field that itself never
		--     changes by more than a node.
		local deck_memo = {}
		local function deck_of(p)
			if deck_memo[p] ~= nil then return deck_memo[p] end
			if not wet[p] then
				deck_memo[p] = false
				return false
			end
			local water
			for lane = -half, half do
				local x, z = column(p, lane)
				local y = height(x, z)
				if water == nil or y < water then water = y end
			end
			local lift = from_shore[p]
			if lift > M.LIFT then lift = M.LIFT end
			local level = water + lift
			local top = road_top[p]
			if top ~= nil and top > level then level = top end
			deck_memo[p] = level
			return level
		end

		local PAVING, KERB, TREAD = paving(palette), kerb(palette),
			tread(palette)
		local MARK = mark(palette)
		local PLANK = palette.node("floor")
		local RAIL = palette.node("railing")
		local POST = palette.node("post")

		-- 1. Drop every cell the road wrote in a wet column. Over water those
		-- cells ARE the causeway; the verge's lamp standard goes with them,
		-- because it stood on the water surface.
		local kept, dropped = {}, 0
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local p = (dx == 1) and cell.x or cell.z
			if wet[p] then
				dropped = dropped + 1
			else
				kept[#kept + 1] = cell
			end
		end

		-- A lamp the road published in a dropped column is no longer there.
		local lamps = {}
		for index = 1, #(piece.lamps or {}) do
			local lamp = piece.lamps[index]
			local p = (dx == 1) and lamp.x or lamp.z
			if not wet[p] then lamps[#lamps + 1] = lamp end
		end

		-- 2. Build the bridge.
		local buf = parts.buffer()
		local columns, piers, lanterns = 0, 0, 0
		for p = spec.from, spec.to do
			local level = deck_of(p)
			if level then
				columns = columns + 1
				local before, after = deck_of(p - 1), deck_of(p + 1)
				local step = (before and level > before) or
					(after and level > after)
				for lane = -verge, verge do
					local x, z = column(p, lane)
					if math.abs(lane) == verge then
						-- The plank verge and its rail: a walker cannot step
						-- off the deck into the mere.
						buf:put(x, level, z, PLANK)
						buf:put(x, level + 1, z, RAIL)
					else
						local name = (math.abs(lane) == half) and KERB or PAVING
						if step and math.abs(lane) <= half then
							-- A one-node change is walked as two half nodes,
							-- the same rule `avenue.lua` caps its own steps
							-- with.
							local sign = (after and level > after) and -1 or 1
							parts.stair(buf, x, level, z, TREAD,
								parts.step_facedir(dx * sign, dz * sign))
						else
							buf:put(x, level, z, name)
						end
					end
					-- Nothing of this run's stands between the deck and the
					-- water on the carriageway lanes; the clear says so rather
					-- than leaving it to the writer's memory.
					--
					-- IT STOPS AT THE SURFACE, and that is the whole point of
					-- the bridge. The first version cleared `level - 1`
					-- unconditionally, and with a lift of one node that cell IS
					-- the water surface: the built map then carried a five-wide
					-- trench of AIR down the middle of the mere under the deck
					-- -- not a dam, but not water either, and the lake's
					-- surface inside the avenue's own corridor came apart into
					-- two sheets. So the clear runs from one node OVER this
					-- lane's own surface (the water where the lane is wet, the
					-- bank where it is dry) up to one under the deck, and is
					-- empty for a lift of one. The water stays.
					if math.abs(lane) <= half then
						local surface_y = height(x, z)
						if level - 1 > surface_y then
							buf:clear(x, surface_y + 1, z, x, level - 1, z)
						end
					end
				end
				-- 3. THE PIERS, on the two verge lanes and nowhere else: the
				-- whole carriageway stays open water underneath, which is what
				-- keeps the lake one lake.
				if (p - phase) % M.PIER == 0 then
					for _, lane in ipairs({-verge, verge}) do
						local x, z = column(p, lane)
						local foot = height(x, z) - M.PIER_DEPTH
						for y = foot, level - 1 do
							buf:put(x, y, z, MARK)
						end
					end
					piers = piers + 2
				end
				-- 4. A lantern on the deck.
				if (p - phase) % M.LAMP == 0 then
					local x, z = column(p, verge)
					buf:put(x, level + 1, z, POST)
					buf:put(x, level + 2, z, POST)
					parts.floor_torch(buf, palette, x, level + 3, z)
					lanterns = lanterns + 1
					lamps[#lamps + 1] = {x = x, y = level + 3, z = z}
				end
			end
		end

		local order, count = buf:cells()
		for index = 1, count do kept[#kept + 1] = order[index] end
		table.sort(kept, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		piece.cells = kept
		piece.lamps = lamps
		piece.bridge = {columns = columns, piers = piers, lanterns = lanterns,
			dropped = dropped}
		return piece
	end

	return M
end

return loader
