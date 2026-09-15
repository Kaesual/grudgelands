-- Gor Drazhak's city wall: a STAKE PALISADE ON AN EARTH RAMPART, as a surface
-- overlay round the 512 envelope.
--
-- WHY THIS IS NOT `wall.lua` WITH AN ORC PALETTE
-- ---------------------------------------------
-- The capitals contract (docs/research/wp13-capitals-pois-contract.md section
-- 2.4) gives the orc capital "adobe flat roofs with parapets, ors-stone base
-- courses, PALISADE AND EARTHWORKS, warlord hall with fighting platform", and
-- section 4 makes it one of the walled capitals. `wp13/wall.lua` builds the
-- other kind of wall: a five-thick masonry curtain, rubble-cored, with a
-- crenellated parapet, loopholes and merlon caps. Rebinding its `castle_wall`
-- role to acacia would produce a five-thick SOLID TIMBER curtain with
-- crenellations -- a wooden castle, which is neither a palisade nor an
-- earthwork. The contract names a different piece of architecture, so this is
-- a different module.
--
-- What it is NOT is a different SEAM. Everything `wall.lua` promises the
-- successor, this promises in the same words and with the same constants:
--
--   * the same run specification (`axis`, `at`, `from`, `to`, `lamp_phase`,
--     `reach`) and the same authored `plan` (`outside`, `towers`,
--     `cross_towers`, `gates`);
--   * the same one-Lipschitz envelope rule, so a piece of a run is exactly
--     that stretch of the whole run and the successor may call it per
--     mapchunk;
--   * the same `HALF` = 3 activation band, so no cell of any piece lands in a
--     mapchunk the run is never offered;
--   * the same `RISE`, `FOOTING`, `REACH` and `GATE_PASSAGE`, which is what
--     lets `tools/wp13/capital_wall.lua` -- which loads its constants from
--     `wall.lua` -- measure the ground under THESE runs and be measuring the
--     right thing. `gor_drazhak_kat.lua` asserts the five constants equal
--     rather than leaving that to a comment.
--
-- THE SECTION, from the field inward, with `o` the outward lane sign:
--
--   lane 3o   the OUTER BERM: dug earth from the footing to three courses
--             over the envelope, beaten bare on top. The earthwork.
--   lane 2o   the STOCKADE: an ors-stone base course from the footing to one
--             under the walk, then three courses of acacia stakes standing
--             proud of it, every stake sharpened. The palisade.
--   lanes 1o, 0, 1i   the RAMPART BODY: rammed earth to one under the walk,
--             and the walk itself -- a three-wide timber fighting platform at
--             `level + RISE`, treaded wherever it steps.
--   lane 2i   the body's inner edge: earth, a log kerb at the walk and a
--             rail above it, because a fighting platform with a fall on the
--             city side is not a platform.
--   lane 3i   the INNER SLOPE: earth to three courses, beaten bare on top --
--             the back of the bank, which is how a defender gets up it.
--
-- NO GAP IS POSSIBLE, for `wall.lua`'s reason exactly: every column is filled
-- from `B[p] - FOOTING`, at or below every one of that column's own seven
-- ground samples, up to its own `D[p]`, and `D` is the one-Lipschitz upper
-- envelope of `B` plus `RISE`, so a terrace step makes the next column start
-- lower and the face becomes a staircase of bank and stake, never a hole.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- THE FIVE CONSTANTS THE SEAM AND THE TERRAIN TOOL SHARE WITH `wall.lua`.
	-- `gor_drazhak_kat.lua` section 4 asserts each of them equal to that
	-- module's, so the day one moves the other is a red row and not a wall
	-- measured against the wrong rule.
	M.HALF = 3
	M.RISE = 6
	M.FOOTING = 2
	M.REACH = 40
	M.GATE_PASSAGE = 3

	-- The rampart body's own half-thickness: lanes -2..2, five nodes, exactly
	-- `wall.CURTAIN`. The two outermost lanes of the seven are the berm and
	-- the inner slope, which a masonry curtain does not have and an earthwork
	-- does.
	M.BODY = 2
	-- How far the berm and the inner slope rise over the envelope.
	M.BANK = 3
	-- The stake rhythm: every column carries a stake, and every fourth one
	-- stands a course taller, which is what keeps five hundred nodes of
	-- timber from reading as a fence.
	M.STAKE = 4
	M.STAKE_RISE = 3
	-- A brazier on the crest every this many columns.
	M.LAMP = 16
	-- A tower is seven across and eleven along and rises six courses over the
	-- walk; a gatehouse is seven across and fifteen along.
	M.TOWER_HALF = 5
	M.TOWER_RISE = 6
	M.GATE_HALF = 7

	-- The palisade vocabulary. Every accessor has the same fallback discipline
	-- `wall.lua` and `capitals.lua` use, so a palette without the capital roles
	-- still builds a rampart.
	local function timber(palette) return palette.node("tree_log") end
	local function point(palette)
		return palette.maybe("stake_cap") or palette.node("roof_stair_outer")
	end
	local function base_course(palette)
		return palette.maybe("wall_infill") or palette.node("foundation")
	end
	local function earth(palette) return palette.node("subsoil") end
	local function beaten(palette) return palette.node("ground_bare") end
	local function deck_board(palette) return palette.node("floor") end
	local function tread(palette) return palette.node("seat") end
	local function rail(palette) return palette.node("railing") end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end

	-- Every node name a run may write, in ASCII byte order and without
	-- duplicates. Same contract as `wall.palette_names` and for the same two
	-- reasons: an overlay has no cells, so its identity is written from its
	-- specification, and the settlement's shared content channel is closed
	-- over this list at load. `air` is in it because a rampart CLEARS -- the
	-- walk's headroom and the gate passage are authored air.
	function M.palette_names(palette)
		local names = {parts.AIR, timber(palette), point(palette),
			base_course(palette), earth(palette), beaten(palette),
			deck_board(palette), tread(palette), rail(palette),
			paving(palette), mark(palette), palette.node("light_post")}
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 orc palisade: the palette has no name for a " ..
					"rampart role", 0)
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
		error("wp13 orc palisade: unknown axis " .. tostring(axis), 0)
	end

	-- One piece of rampart. The arguments are `wall.run`'s, exactly.
	function M.run(palette, spec, surface, plan)
		if type(surface) ~= "function" then
			error("wp13 orc palisade: a run needs a surface callback", 0)
		end
		if type(plan) ~= "table" or
				(plan.outside ~= 1 and plan.outside ~= -1) then
			error("wp13 orc palisade: a run needs its authored plan", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 orc palisade: the run has no span", 0)
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
				error("wp13 orc palisade: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. The ground under all seven lanes, the lowest of it per column,
		-- and the one-Lipschitz envelope over that. All seven, not the five
		-- the body stands on: the berm, the inner slope and a tower's own
		-- projecting face all reach the outermost lanes.
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

		-- 2. Where the towers and the gates are, over this piece's span plus
		-- the reach, so a tower whose centre is outside the piece still writes
		-- the part of itself that is inside it.
		local tower_of, cross_of, gate_of = {}, {}, {}
		local function mark_span(map, centre, half, value)
			for p = centre - half, centre + half do
				if p >= low_end and p <= high_end then map[p] = value end
			end
		end
		for index = 1, #(plan.towers or {}) do
			local centre = plan.towers[index]
			mark_span(tower_of, centre, M.TOWER_HALF, centre)
		end
		for index = 1, #(plan.cross_towers or {}) do
			cross_of[plan.cross_towers[index]] = true
		end
		for index = 1, #(plan.gates or {}) do
			local centre = plan.gates[index]
			mark_span(gate_of, centre, M.GATE_HALF, centre)
		end

		-- 3. The rampart, column by column.
		local TIMBER, POINT = timber(palette), point(palette)
		local BASE, EARTH, BEATEN = base_course(palette), earth(palette),
			beaten(palette)
		local BOARD, TREAD, RAIL = deck_board(palette), tread(palette),
			rail(palette)
		local PAVING, MARK = paving(palette), mark(palette)
		local berm_lane, stockade_lane = M.HALF * outside, M.BODY * outside
		local inner_edge, slope_lane = -M.BODY * outside, -M.HALF * outside
		local boards, treads, stakes, braziers, bank = 0, 0, 0, 0, 0

		for p = from, to do
			local foot = base[p] - M.FOOTING
			local top = deck(p)
			local gate = gate_of[p]
			local in_passage = gate ~= nil and
				p >= gate - M.GATE_PASSAGE and p <= gate + M.GATE_PASSAGE

			if in_passage then
				-- THE GATE PASSAGE, seven columns along the run: the avenue's
				-- five-wide carriageway plus the two verges its lamp standards
				-- stand on. The tunnel is authored as air through the whole
				-- thickness, from ONE COURSE ABOVE the column's lowest ground
				-- -- the road through it is the AVENUE overlay's, it runs
				-- first and wins every shared cell, and it lays its pavement
				-- from the ground upward, so clearing below the ground would
				-- leave that road over a void.
				for lane = -M.HALF, M.HALF do
					local x, z = column(p, lane)
					buf:put(x, base[p], z, PAVING)
					buf:clear(x, base[p] + 1, z, x, top - 1, z)
				end
			else
				-- The bank: earth under the whole body, from the column's own
				-- footing to one under its own walk.
				for lane = -M.BODY, M.BODY do
					local x, z = column(p, lane)
					for y = foot, top - 1 do buf:put(x, y, z, EARTH) end
				end
				-- The stockade's ors-stone base course replaces the earth on
				-- the outer lane: the contract's banded base under the stakes.
				do
					local x, z = column(p, stockade_lane)
					for y = foot, top - 1 do buf:put(x, y, z, BASE) end
					-- One string course of the signature material three under
					-- the walk, which is what keeps a five-hundred-node base
					-- from reading as a cliff.
					if top - 3 >= foot then buf:put(x, top - 3, z, MARK) end
				end
				-- The berm and the inner slope: dug earth to `BANK` courses
				-- over the envelope, beaten bare on top, and open sky above.
				for _, lane in ipairs({berm_lane, slope_lane}) do
					local x, z = column(p, lane)
					local crest = base[p] + M.BANK
					for y = foot, crest - 1 do buf:put(x, y, z, EARTH) end
					buf:put(x, crest, z, BEATEN)
					buf:clear(x, crest + 1, z, x, top + 2, z)
					bank = bank + 1
				end
			end

			-- The walk. Over the passage it is the tunnel's ceiling as well,
			-- so it is written in both cases.
			for lane = -1, 1 do
				local x, z = column(p, lane)
				local before, after = deck(p - 1), deck(p + 1)
				if top > before or top > after then
					-- A step in the walk, capped with a tread: a one-node
					-- change is walked as the two halves of one stair, and a
					-- full cube there is a node to jump.
					local sign = (after >= before) and 1 or -1
					parts.stair(buf, x, top, z, TREAD,
						parts.step_facedir(dx * sign, dz * sign))
					treads = treads + 1
				else
					buf:put(x, top, z, BOARD)
					boards = boards + 1
				end
			end
			-- The body's two outer lanes at walk height: the stockade's own
			-- footing course on one side and the kerb log on the other.
			do
				local x, z = column(p, inner_edge)
				buf:put(x, top, z, TIMBER)
				buf:put(x, top + 1, z, RAIL)
			end

			-- The headroom over the walk, so an uphill shoulder of terrace is
			-- not left standing in the rampart.
			for lane = -1, 1 do
				local x, z = column(p, lane)
				buf:clear(x, top + 1, z, x, top + 3, z)
			end

			-- THE STAKES. Every column of the stockade lane carries one, from
			-- the walk upward, sharpened; every fourth stands a course taller,
			-- which is what a hewn crest looks like and a moulding does not.
			--
			-- A BRAZIER TAKES THE PLACE OF A POINT every `LAMP` columns, and
			-- stands there rather than over the walk for a reason that is not
			-- taste: a torch is not walkable, and a rampart lit from its own
			-- three-node walk is a rampart with a post in the middle of it
			-- every sixteen paces. The crest log under it is a full node, which
			-- is what `parts.floor_torch` demands.
			do
				local x, z = column(p, stockade_lane)
				local beat = (p - phase) % M.STAKE
				if beat < 0 then beat = beat + M.STAKE end
				local crest = top + M.STAKE_RISE - 1 + ((beat == 0) and 1 or 0)
				for y = top, crest do buf:put(x, y, z, TIMBER) end
				if (p - phase) % M.LAMP == 0 and not in_passage then
					parts.floor_torch(buf, palette, x, crest + 1, z)
					braziers = braziers + 1
				else
					buf:put(x, crest + 1, z, POINT, (p + at) % 4)
				end
				stakes = stakes + 1
			end
		end

		-- 4. The towers and the gate towers: the same piece of architecture at
		-- two lengths -- a timber box seven across standing on the bank, open
		-- along the run at walk height so the rampart passes through it, with
		-- a fighting floor and a stake crown over it.
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
			local floor_y = crown + M.TOWER_RISE - 2
			for p = math.max(first, from), math.min(last, to) do
				local top = deck(p)
				local foot = base[p] - M.FOOTING
				local edge = (p == first or p == last)
				-- A gate passage column carries no fill under the walk, not
				-- even on the projecting faces: those lanes are the mouth of
				-- the tunnel and filling them walls the gate up.
				local open = passage ~= nil and
					p >= centre - passage and p <= centre + passage
				for lane = -M.HALF, M.HALF do
					local x, z = column(p, lane)
					local face_lane = (lane == -M.HALF or lane == M.HALF)
					if face_lane and not open then
						-- The projecting faces carry their own footing to the
						-- ground: ors-stone below the walk, because a timber
						-- post sunk eight courses into a bank is a post that
						-- rots, and because the contract's base course is what
						-- this capital's masonry is.
						for y = foot, top - 1 do buf:put(x, y, z, BASE) end
						buf:put(x, top, z, TIMBER)
					elseif face_lane then
						-- Over the mouth of the tunnel the same lane carries
						-- only the course the chamber stands on.
						buf:put(x, top, z, TIMBER)
					end
					-- The chamber's own walls, from the walk to the fighting
					-- floor: acacia, which is what an orc tower is.
					if face_lane or edge then
						for y = top + 1, floor_y do buf:put(x, y, z, TIMBER) end
					else
						buf:clear(x, top + 1, z, x, floor_y - 1, z)
					end
					if not face_lane and not edge then
						buf:put(x, floor_y, z, BOARD)
					end
				end
				-- The rampart passes THROUGH: a three-wide, three-high opening
				-- in each end face. Without it the walk dead-ends at every
				-- tower.
				if edge then
					for lane = -1, 1 do
						local x, z = column(p, lane)
						buf:clear(x, top + 1, z, x, top + 3, z)
					end
				end
			end
			-- The city-face opening of a corner tower, which is how the run
			-- that meets this one at right angles gets onto the rampart.
			if cross then
				local lane = -M.HALF * outside
				for p = math.max(centre - 1, from), math.min(centre + 1, to) do
					local x, z = column(p, lane)
					local top = deck(p)
					buf:clear(x, top + 1, z, x, top + 3, z)
				end
			end
			-- The crown: a log breastwork all round the fighting floor with a
			-- sharpened stake every other node.
			for p = math.max(first, from), math.min(last, to) do
				for lane = -M.HALF, M.HALF do
					if p == first or p == last or lane == -M.HALF or
							lane == M.HALF then
						local x, z = column(p, lane)
						buf:put(x, floor_y + 1, z, TIMBER)
						if (p + lane) % 2 == 0 then
							buf:put(x, floor_y + 2, z, TIMBER)
							buf:put(x, floor_y + 3, z, POINT, (p + lane) % 4)
						end
					end
				end
			end
		end

		local seen = {}
		for p = from, to do
			local centre = tower_of[p]
			if centre and not seen["tower:" .. centre] then
				seen["tower:" .. centre] = true
				chamber(centre, M.TOWER_HALF, cross_of[centre] == true, nil)
			end
			local gate = gate_of[p]
			if gate and not seen["gate:" .. gate] then
				seen["gate:" .. gate] = true
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
			-- road's carriageway; a brazier stands on the rampart's own kerb
			-- and there is never another run inside a rampart, so the list is
			-- empty and the arbitration has nothing to do.
			lamps = {},
			boards = boards, treads = treads, stakes = stakes,
			braziers = braziers, bank_columns = bank,
			columns = to - from + 1, queries = queries,
		}
	end

	return M
end

return loader
