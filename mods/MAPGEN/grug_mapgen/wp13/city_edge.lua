-- WP13 city edge on the capital planner's outline (Round 22, plan D69, D70,
-- design §5 and §9 of docs/research/round22-capital-planner-design.md): the
-- stone curtain with turrets and gatehouses (Highcourt, Dur Brannoc, Nhal
-- Veyr), the orc palisade on its rampart (Gor Drazhak), and the planted belt
-- with four thresholds of the open capitals (Lethariel, Kezamba).
--
-- The geometry is the planner's payload (`wp40/capital_planner.lua`): the
-- closed wall polyline in local coordinates with a walk level per point in
-- half nodes, the gate gaps and the points over water, the turret points and
-- the four gates. Everything here is a pure function of that geometry and of
-- one column's final ground and water, so a mapchunk writes exactly its own
-- part of the edge whatever the generation order (seam rule):
--   * the walk height of a column is the half-rounded interpolation of the
--     polyline's walk at the column's projection on the nearest segment; the
--     planner keeps the walk within 1/2 node per node, so neighbouring walk
--     columns differ by at most 1/2 (a slab) and the walk is walked like a
--     street;
--   * masonry starts two courses under the column's own ground, so a wall on
--     a slope is a stepped face, never a gap;
--   * over water (a point flagged `a` by the planner, or a wet column) the
--     wall is an arcade: the walk on a three-course arch, piers down to the
--     bed every few points, the river passing below;
--   * a gatehouse or a threshold owns its box: the avenue runs through the
--     passage (the road writer paves it) and the gatehouse writes nothing
--     below the lintel there.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local palettes = dofile(directory .. "/palette.lua")
	local parts = dofile(directory .. "/parts.lua")
	local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt,
		math.abs, math.min, math.max

	local M = {}

	-- The roles each edge kind writes, with fallbacks into the start
	-- vocabulary so every race builds every kind.
	local function roles(palette, kind)
		local function pick(...)
			for index = 1, select("#", ...) do
				local role = select(index, ...)
				local ok, name = pcall(palette.maybe, role)
				if ok and type(name) == "string" and name ~= "" then return name end
			end
			error("wp13 city edge: the palette has none of the roles asked", 0)
		end
		local r = {}
		if kind == "stone" then
			r.face = pick("castle_wall", "wall_accent")
			r.core = pick("castle_rubble", "rubble", "castle_wall")
			r.walk = pick("castle_paving", "plaza")
			r.walk_slab = pick("castle_wall_slab", "signature_slab")
			r.course = pick("signature", "wall_accent")
			r.cap = pick("signature_slab", "castle_wall_slab")
			r.light = pick("light_wall")
		elseif kind == "palisade" then
			r.stake = pick("post", "tree_log")
			r.cap = pick("stake_cap", "post")
			r.bank = pick("subsoil", "ground")
			r.walk = pick("path", "plaza")
			r.walk_slab = pick("castle_wall_slab", "signature_slab")
			r.beam = pick("tree_log", "post")
			r.light = pick("light_post")
		elseif kind == "open" then
			r.leaves = pick("hedge", "tree_leaves")
			r.stem = pick("hedge_stem", "tree_log")
			r.log = pick("tree_log", "post")
			r.crown = pick("tree_leaves", "hedge")
			r.post = pick("post", "tree_log")
			r.beam = pick("signature", "plaza_edge")
			r.light = pick("light_post")
		else
			error("wp13 city edge: unknown edge kind " .. tostring(kind), 0)
		end
		return r
	end

	-- Every node name an edge of this race and kind may write, sorted by
	-- bytes (the overlay's identity and the settlement channel close over it).
	function M.names(race, kind)
		local r = roles(palettes.new(race), kind)
		local seen, list = {air = true}, {"air"}
		for _, name in pairs(r) do
			if not seen[name] then seen[name] = true; list[#list + 1] = name end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	-- `layout` is the deserialized capital layout (local coordinates), `dims`
	-- the planner's edge dimensions for this kind ({half, depth, width,
	-- turret}), `anchor` the world anchor {x, z}.
	function M.new(race, kind, layout, dims, anchor)
		local R = roles(palettes.new(race), kind)
		local W = layout.wall
		local pts, n = W.pts, #W.pts
		local HALF, DEPTH, WIDTH = dims.half, dims.depth, dims.width
		local TURRET = dims.turret or 0
		local AX, AZ = anchor.x, anchor.z
		-- segments i -> i + 1 (closed), bucketed on an 8-node grid
		local BUCKET = 8
		local buckets = {}
		local function bkey(bx, bz) return bz * 65536 + bx end
		-- a segment reaches every column of its belt and of a turret disc on it
		local reach = max(HALF, TURRET) + 2
		local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			local x0, x1 = min(a[1], b[1]) - reach, max(a[1], b[1]) + reach
			local z0, z1 = min(a[2], b[2]) - reach, max(a[2], b[2]) + reach
			if x0 < min_x then min_x = x0 end
			if x1 > max_x then max_x = x1 end
			if z0 < min_z then min_z = z0 end
			if z1 > max_z then max_z = z1 end
			for bz = floor(z0 / BUCKET), floor(z1 / BUCKET) do
				for bx = floor(x0 / BUCKET), floor(x1 / BUCKET) do
					local k = bkey(bx, bz)
					local l = buckets[k]
					if not l then l = {}; buckets[k] = l end
					l[#l + 1] = i
				end
			end
		end
		local turret_at = {}
		for _, i in ipairs(W.turrets) do turret_at[#turret_at + 1] = pts[i] end
		-- the open belt's trees: every eighth point off gaps and water, as
		-- rounded trunk columns bucketed by the 5 x 5 crown square they own
		local TREE_EVERY, CROWN = 8, 2
		local trees = {}
		if kind == "open" then
			for i = TREE_EVERY, n, TREE_EVERY do
				if not W.gap[i] and not W.gap[i % n + 1] and not W.wet[i] then
					local tx, tz = floor(pts[i][1] + 0.5), floor(pts[i][2] + 0.5)
					local t = {tx, tz}
					for bz = floor((tz - CROWN) / BUCKET), floor((tz + CROWN) / BUCKET) do
						for bx = floor((tx - CROWN) / BUCKET), floor((tx + CROWN) / BUCKET) do
							local k = bkey(bx, bz)
							local l = trees[k]
							if not l then l = {}; trees[k] = l end
							l[#l + 1] = t
						end
					end
				end
			end
		end
		local gates = {}
		for c = 1, 4 do gates[c] = layout.gates[c] end
		local extra = max(DEPTH, WIDTH, TURRET) + 1
		local edge = {bounds = {min_x = floor(min_x) - extra, max_x = ceil(max_x) + extra,
			min_z = floor(min_z) - extra, max_z = ceil(max_z) + extra}}

		-- the nearest wall segment of a local column: distance, segment index,
		-- projection parameter, and whether the column lies outside the city
		local function nearest(lx, lz)
			local list = buckets[bkey(floor(lx / BUCKET), floor(lz / BUCKET))]
			if not list then return nil end
			local best, bi, bu
			for j = 1, #list do
				local i = list[j]
				local a, b = pts[i], pts[i % n + 1]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local l2 = vx * vx + vz * vz
				local u = l2 > 0 and ((lx - a[1]) * vx + (lz - a[2]) * vz) / l2 or 0
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local dx, dz = lx - a[1] - u * vx, lz - a[2] - u * vz
				local d = sqrt(dx * dx + dz * dz)
				if not best or d < best then best, bi, bu = d, i, u end
			end
			if not best then return nil end
			local a, b = pts[bi], pts[bi % n + 1]
			local px, pz = a[1] + bu * (b[1] - a[1]), a[2] + bu * (b[2] - a[2])
			local outside = lx * lx + lz * lz > px * px + pz * pz
			return best, bi, bu, outside
		end
		-- the walk top (full node) and whether a slab sits on it
		local function walk_at(i, u)
			local w = (W.walk[i] + u * (W.walk[i % n + 1] - W.walk[i])) / 2
			local h = floor(2 * w + 0.5) / 2
			local top = floor(h)
			return top, h - top >= 0.5
		end
		local function gate_of(lx, lz)
			for c = 1, 4 do
				local g = gates[c]
				local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
				local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
				if abs(dd) <= DEPTH + 0.5 and abs(ww) <= WIDTH + 0.5 then
					return g, floor(dd + 0.5), floor(ww + 0.5)
				end
			end
			return nil
		end

		-- One column: `put(y, name, param2)` writes a node, `column` is the
		-- column's final ground y and water surface (nil when dry), `road`
		-- whether a road or street surface lies here.
		local function stone_column(lx, lz, ground, water, road, put)
			local g, dd, ww = gate_of(lx, lz)
			if g then
				-- a street column is always passage, never tower
				local tower = abs(ww) >= WIDTH - 2 and not road
				local roof = g.y + 9
				if tower then
					for y = ground - 2, roof + 2 do put(y, R.face) end
					if (dd + ww) % 2 == 0 and (abs(dd) == DEPTH or abs(ww) == WIDTH) then
						put(roof + 3, R.face)
						put(roof + 4, R.cap)
					end
				else
					for y = g.y + 2, g.y + 5 do put(y, "air") end
					for y = g.y + 6, roof - 1 do put(y, R.face) end
					put(roof, R.walk)
					if abs(dd) == DEPTH then
						put(roof + 1, R.face)
						if (ww % 2) == 0 then put(roof + 2, R.cap) end
					end
				end
				return
			end
			-- a road or street column is never built over (a connector may
			-- cross the edge next to a turret)
			if road then return end
			for _, t in ipairs(turret_at) do
				local dx, dz = lx - t[1], lz - t[2]
				local r2 = dx * dx + dz * dz
				if r2 <= TURRET * TURRET + 1 then
					local d, i, u = nearest(lx, lz)
					if not d then return end
					local top = walk_at(i, u)
					local crown = top + 5
					for y = ground - 2, crown - 1 do put(y, R.face) end
					if d and d <= 1.5 then
						-- the walk passes through the turret
						for y = top + 1, top + 3 do put(y, "air") end
						put(top, R.walk)
					end
					if r2 >= (TURRET - 1) * (TURRET - 1) then
						put(crown, R.face)
						if (lx + lz) % 2 == 0 then put(crown + 1, R.face); put(crown + 2, R.cap) end
					else
						put(crown, R.walk)
					end
					return
				end
			end
			local d, i, u, outside = nearest(lx, lz)
			if not d or d > HALF + 0.5 then return end
			if W.gap[i] or W.gap[i % n + 1] then return end
			local top, slab = walk_at(i, u)
			local edge_lane = d > HALF - 0.5
			local wet = W.wet[i] or (water ~= nil and water > ground)
			local pier = (i % 6) < 2
			local low = ground - 2
			if wet and not pier then low = top - 3 end
			for y = low, top - 1 do put(y, edge_lane and R.face or R.core) end
			if edge_lane then
				local rise = top + (slab and 1 or 0)
				for y = top, rise + 1 do put(y, R.face) end
				if outside then
					-- merlons on the field side, two nodes on and two off
					if i % 2 == 0 then put(rise + 2, R.face); put(rise + 3, R.cap) end
				end
				-- a string course of the signature material under the walk
				if top - 3 >= low then put(top - 3, R.course) end
			else
				put(top, R.walk)
				local above = top + 1
				if slab then put(above, R.walk_slab); above = above + 1 end
				for y = above, top + 4 do put(y, "air") end
			end
		end

		local function palisade_column(lx, lz, ground, water, road, put)
			local g, dd, ww = gate_of(lx, lz)
			if g then
				local tower = abs(ww) >= WIDTH - 1 and not road
				local roof = g.y + 7
				if tower then
					for y = ground - 1, roof do put(y, R.stake) end
					if (dd + ww) % 2 == 0 then put(roof + 1, R.cap) end
				else
					for y = g.y + 2, g.y + 5 do put(y, "air") end
					if abs(dd) == DEPTH or dd == 0 then
						for y = g.y + 6, roof do put(y, R.beam) end
					end
				end
				return
			end
			if road then return end
			for _, t in ipairs(turret_at) do
				local dx, dz = lx - t[1], lz - t[2]
				local r2 = dx * dx + dz * dz
				if r2 <= TURRET * TURRET + 1 then
					local d, i, u = nearest(lx, lz)
					if not d then return end
					local top = walk_at(i, u)
					local crown = top + 4
					if r2 >= (TURRET - 1) * (TURRET - 1) then
						for y = ground - 1, crown do put(y, R.stake) end
						if (lx + lz) % 2 == 0 then put(crown + 1, R.cap) end
					else
						for y = ground, top - 1 do put(y, R.bank) end
						put(top, R.walk)
						for y = top + 1, top + 3 do put(y, "air") end
					end
					return
				end
			end
			local d, i, u, outside = nearest(lx, lz)
			if not d or d > HALF + 0.5 then return end
			if W.gap[i] or W.gap[i % n + 1] then return end
			local top, slab = walk_at(i, u)
			local wet = W.wet[i] or (water ~= nil and water > ground)
			if outside and d > HALF - 1.5 then
				-- the stockade: stakes from under the ground to above the walk
				local low = ground - 1
				if wet and (i % 4) >= 2 then low = top - 2 end
				for y = low, top + 2 do put(y, R.stake) end
				if (i + floor(lx + lz)) % 2 == 0 then put(top + 3, R.cap) end
			else
				-- the rampart behind it: an earth bank, the walk on top (a
				-- timber deck on stakes over water)
				if wet then
					if (i % 4) < 2 then
						for y = ground - 1, top - 1 do put(y, R.stake) end
					end
				else
					for y = ground - 1, top - 1 do put(y, R.bank) end
				end
				put(top, R.walk)
				local above = top + 1
				if slab then put(above, R.walk_slab); above = above + 1 end
				for y = above, top + 3 do put(y, "air") end
			end
		end

		local function open_column(lx, lz, ground, water, road, put)
			local g, dd, ww = gate_of(lx, lz)
			if g then
				-- a threshold: two posts and a beam over the avenue
				if abs(dd) <= 1 and abs(ww) == WIDTH and not road then
					for y = ground + 1, g.y + 5 do put(y, R.post) end
					if dd == 0 then put(g.y + 7, R.light, 1) end
				end
				if dd == 0 and abs(ww) <= WIDTH then put(g.y + 6, R.beam) end
				return
			end
			if road then return end
			if water ~= nil and water > ground then return end
			-- a tree every eight points (iterated as tree points, so the crown
			-- square never depends on which segment is nearest), a hedge between
			local crowned = false
			for _, t in ipairs(trees[bkey(floor(lx / BUCKET), floor(lz / BUCKET))] or {}) do
				if lx == t[1] and lz == t[2] then
					for y = ground + 1, ground + 5 do put(y, R.log) end
					put(ground + 6, R.crown)
					return
				end
				if not crowned and abs(lx - t[1]) <= CROWN and abs(lz - t[2]) <= CROWN then
					for y = ground + 4, ground + 6 do put(y, R.crown) end
					crowned = true
				end
			end
			local d, i = nearest(lx, lz)
			if not d or d > HALF + 0.5 then return end
			if W.gap[i] or W.gap[i % n + 1] then return end
			if W.wet[i] then return end
			if d <= HALF - 0.5 then
				put(ground + 1, R.stem ~= R.log and R.stem or R.leaves)
				put(ground + 2, R.leaves)
			end
		end

		local writer = kind == "stone" and stone_column or
			(kind == "palisade" and palisade_column or open_column)
		-- Every cell of the edge inside the world box, as {x, y, z, name}.
		-- `column(x, z)` answers the final ground y, the water surface y (or
		-- nil) and whether a road or street surface covers the column.
		function edge.cells(box, column)
			local cells = {}
			local x0 = max(box.min_x, AX + edge.bounds.min_x)
			local x1 = min(box.max_x, AX + edge.bounds.max_x)
			local z0 = max(box.min_z, AZ + edge.bounds.min_z)
			local z1 = min(box.max_z, AZ + edge.bounds.max_z)
			for z = z0, z1 do
				for x = x0, x1 do
					local lx, lz = x - AX, z - AZ
					-- cheap rejection: no segment bucket and no gate or turret
					local near = buckets[bkey(floor(lx / BUCKET), floor(lz / BUCKET))] ~= nil or
						gate_of(lx, lz) ~= nil
					if not near then
						for _, t in ipairs(turret_at) do
							if abs(lx - t[1]) <= TURRET + 1 and abs(lz - t[2]) <= TURRET + 1 then
								near = true
								break
							end
						end
					end
					if near then
						local ground, water, road = column(x, z)
						writer(lx, lz, ground, water, road, function(y, name, param2)
							cells[#cells + 1] = {x = x, y = y, z = z, name = name,
								param2 = param2 or 0}
						end)
					end
				end
			end
			return cells
		end
		return edge
	end

	return M
end

return loader
