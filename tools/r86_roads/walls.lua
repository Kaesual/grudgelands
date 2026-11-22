-- Round 86 lane ROADS: the road cut wall measure (round86-plan.md §4 ROADS).
-- A road's cut slope ends at its side zone's edge (`road_layout.lua`
-- sampler, hw + SIDE_MAX from the centreline); where the hill rises faster
-- than the cut, the column just inside the edge is still cut and the first
-- column beyond is untouched ground: a wall. Measured as the arena check
-- measures its grade (`tools/seed_fleet/seed.lua`), the step the world adds
-- over nature, here between two neighbouring columns (x or z) of which one
-- is a cut road column (a side column below its pre-road ground) and the
-- other no road column at all:
--
--   added = |final_b - final_a| - |final_b - pre_a|
--
-- (b is off the roads, so its final ground is its ground before the roads,
-- the shore rule's included; a is the cut column, pre_a its ground before
-- the road.)
-- Inside the side zone, where the cut meets the ground on its own, this is
-- at most 3 (the cut's steepest face is 2 per node: CUT_ROCK); at the side
-- zone's edge it is the depth of the cut there, the wall's height.
--
--   local W = dofile(repo .. "/tools/r86_roads/walls.lua")
--   W.band(layout, side, visit)  -- every column whose distance from a road's
--                                -- edge lies in [side - 1.5, side], once:
--                                -- visit(x, z, road, point)
--   W.steps(columns, query, min) -- the steps of at least `min` from those
--                                -- columns; query(x, z) -> final y, pre-road
--                                -- y, road kind (nil off the roads)
--   W.clusters(steps, reach)     -- the steps grouped into walls
--   W.face(layout, from, to, query, exempt) -- the largest step a cut adds
--                                -- over nature between neighbouring columns
--                                -- from..to nodes from the road's edge (a
--                                -- sample; the road's last column and the
--                                -- slope's low wall included), and that
--                                -- step's column (report only: the seed
--                                -- fleet's road_face)
--   W.largest(layout, side, query, exempt) -- the largest step at the side
--                                -- zone's edge (0 without one) and that
--                                -- step; exempt(x, z) true skips a column
--                                -- (the seed fleet's check)
local floor, abs, sqrt, atan2, cos, sin, ceil, pi =
	math.floor, math.abs, math.sqrt, math.atan2, math.cos, math.sin, math.ceil, math.pi

local M = {}

local OFF = 32768
local function key(x, z) return (z + OFF) * 65536 + (x + OFF) end
local function unkey(k) return k % 65536 - OFF, floor(k / 65536) - OFF end
M.key, M.unkey = key, unkey

-- The band columns: probes on both sides of every segment (four per node),
-- round every vertex's outer arc and round both road ends, at seven
-- distances from side - 1.5 to side beyond the edge; each probe's nearest
-- column is visited once (with the first road and point that reached it).
-- Returns the visited keys in visit order and the per-key road and point.
function M.band(layout, side)
	local seen, order, road_of, point_of = {}, {}, {}, {}
	local function mark(px, pz, n, i)
		local x, z = floor(px + 0.5), floor(pz + 0.5)
		local k = key(x, z)
		if not seen[k] then
			seen[k] = true
			order[#order + 1] = k
			road_of[k], point_of[k] = n, i
		end
	end
	local offsets = {}
	for j = 0, 6 do offsets[#offsets + 1] = side - 1.5 + 0.25 * j end
	local function arc(cx, cz, a1, delta, hw, n, i)
		for _, o in ipairs(offsets) do
			local r = hw + o
			local k = ceil(abs(delta) * r / 0.5)
			for t = 1, k - 1 do
				local a = a1 + delta * t / k
				mark(cx + r * cos(a), cz + r * sin(a), n, i)
			end
		end
	end
	for n, r in ipairs(layout.roads) do
		local X, Z, hw, count = r.X, r.Z, r.hw, #r.X
		local prev
		for i = 1, count - 1 do
			local dx, dz = X[i + 1] - X[i], Z[i + 1] - Z[i]
			local len = sqrt(dx * dx + dz * dz)
			if len > 0 then
				local nx, nz = -dz / len, dx / len
				local steps = ceil(len * 4)
				for s = 0, steps do
					local u = s / steps
					local cx, cz = X[i] + u * dx, Z[i] + u * dz
					for _, o in ipairs(offsets) do
						local d = hw + o
						mark(cx + d * nx, cz + d * nz, n, i)
						mark(cx - d * nx, cz - d * nz, n, i)
					end
				end
				local a = atan2(nz, nx)
				if prev then
					local delta = a - prev
					if delta > pi then delta = delta - 2 * pi elseif delta < -pi then delta = delta + 2 * pi end
					arc(X[i], Z[i], prev, delta, hw, n, i)
					arc(X[i], Z[i], prev + pi, delta, hw, n, i)
				else
					arc(X[i], Z[i], a, pi, hw, n, i)       -- round the start
				end
				prev = a
			end
		end
		if prev then arc(X[count], Z[count], prev, -pi, hw, n, count - 1) end -- round the end
	end
	return order, road_of, point_of
end

-- The steps of at least `min` from the given column keys outward to a
-- neighbour that is no road column: {key (the cut column), x, z, added,
-- final, pre, neighbour final, neighbour pre, neighbour x, neighbour z}.
local NB = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
function M.steps(columns, query, min)
	local out = {}
	for _, k in ipairs(columns) do
		local x, z = unkey(k)
		local f, n, kind = query(x, z)
		if kind ~= nil and kind ~= "surface" and f < n then
			local best
			for _, o in ipairs(NB) do
				local f2, n2, kind2 = query(x + o[1], z + o[2])
				if kind2 == nil then
					local added = abs(f2 - f) - abs(f2 - n)
					if added >= min and (not best or added > best[4]) then
						best = {k, x, z, added, f, n, f2, n2, x + o[1], z + o[2]}
					end
				end
			end
			if best then out[#out + 1] = best end
		end
	end
	return out
end

-- The largest step at the side zone's edge over every road (see M.steps):
-- returns the step (0 without one) and {key, x, z, added, ...} or nil.
function M.largest(layout, side, query, exempt)
	local columns = M.band(layout, side)
	local best, at = 0, nil
	for _, s in ipairs(M.steps(columns, query, 1)) do
		if s[4] > best and not (exempt and (exempt(s[2], s[3]) or exempt(s[9], s[10]))) then
			best, at = s[4], s
		end
	end
	return best, at
end

-- The largest step a cut adds inside the band from..to (M.face above), a
-- sample: one cross-section every sixth node along every road, both sides,
-- its columns a node apart from `from` to `to` beyond the road's edge, each
-- next to the one before (a ledge runs along the road, so the sample sees it
-- at a fraction of a full scan's cost). Over neighbours of which at least one
-- is a cut column; nature is a road column's pre-road ground and a column
-- off the roads' final ground. Returns the step and its column.
function M.face(layout, from, to, query, exempt)
	local best, bx, bz = 0, nil, nil
	local function nature(f, n, kind) return kind == nil and f or n end
	local function cut(f, n, kind) return kind ~= nil and kind ~= "surface" and f < n end
	for _, r in ipairs(layout.roads) do
		local X, Z, hw = r.X, r.Z, r.hw
		for i = 6, #X - 1, 6 do
			local dx, dz = X[i + 1] - X[i], Z[i + 1] - Z[i]
			local len = sqrt(dx * dx + dz * dz)
			if len > 0 then
				for side = -1, 1, 2 do
					local nx, nz = -dz / len * side, dx / len * side
					local lx, lz, lf, ln, lk
					for d = from, to, 1 do
						local x = floor(X[i] + (hw + d) * nx + 0.5)
						local z = floor(Z[i] + (hw + d) * nz + 0.5)
						if x ~= lx or z ~= lz then
							local f, n, kind = query(x, z)
							if lx and (cut(f, n, kind) or cut(lf, ln, lk)) and
									not (exempt and (exempt(x, z) or exempt(lx, lz))) then
								local added = abs(f - lf) - abs(nature(f, n, kind) - nature(lf, ln, lk))
								if added > best then best, bx, bz = added, x, z end
							end
							lx, lz, lf, ln, lk = x, z, f, n, kind
						end
					end
				end
			end
		end
	end
	return best, bx, bz
end

-- The steps grouped into walls: steps within `reach` (Chebyshev) of each
-- other join; per wall {max = largest step, at = that step, columns = its
-- step count, steps = the list}, largest first.
function M.clusters(steps, reach)
	local parent, at = {}, {}
	for i, s in ipairs(steps) do parent[i] = i; at[s[1]] = i end
	local function root(i)
		while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
		return i
	end
	for i, s in ipairs(steps) do
		for dz = -reach, reach do
			for dx = -reach, reach do
				local j = at[key(s[2] + dx, s[3] + dz)]
				if j and j ~= i then
					local a, b = root(i), root(j)
					if a ~= b then parent[a] = b end
				end
			end
		end
	end
	local groups, list = {}, {}
	for i, s in ipairs(steps) do
		local r = root(i)
		local g = groups[r]
		if not g then
			g = {max = -math.huge, columns = 0, steps = {}}
			groups[r] = g
			list[#list + 1] = g
		end
		g.columns = g.columns + 1
		g.steps[#g.steps + 1] = s
		if s[4] > g.max then g.max, g.at = s[4], s end
	end
	table.sort(list, function(a, b)
		if a.max ~= b.max then return a.max > b.max end
		return a.at[1] < b.at[1]
	end)
	return list
end

return M
