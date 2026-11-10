-- The walk grid of an Expedition template (Round 74 NAV, round74-plan.md section 3.2):
-- every mob path inside an Expedition goes over it. tools/expedition_templates/walkgrid.py
-- writes it into the template file (the `grid` section, template.lua); the game makes one
-- grid per template at load and every run of that template shares it: a run only adds its
-- slot's minimum corner (preparation.lua places the template there, unrotated). Pure: no
-- engine call, so tools/r74_nav/portable_test.lua loads it as it is.
--
-- Cells are the template's columns, index i = z * sx + x + 1 with box-relative x, z. Per
-- column, four planes of one byte (walkgrid.py has the rules):
--   height     the feet row of its one walking cell (the proof's height map), NONE without
--   mask       the moves from it, bit k - 1 for MOVES[k]: four straight, four diagonal (a
--              diagonal only where both straight neighbours are moves, no corner cut)
--   clearance  the Chebyshev distance to the nearest column a body here would hit
--   flags      bit 0 a door cell (passable only while the door is open); bits 1 to 4 a
--              2 x 2 block of free columns towards QUADS[k]
--
-- A body's class (W.class(width)): 1 fits every cell, 2 (up to two nodes wide) a cell of a
-- free 2 x 2 block, c >= 3 a cell with clearance c - 1 (a body centred on it). Costs: 5 a
-- straight move, 7 a diagonal one.
--
--   local g = W.new(tpl)                       once per template (tpl.grid, tpl.size)
--   W.cell(g, x, fy, z, class, door)           the walking cell for a body at box-relative
--                                              (x, z), feet row fy: its own, else the nearest
--                                              within SNAP nodes; nil (off the grid)
--   W.path(g, s, t, class, door)               A* from cell s to cell t: {cells...}, cost; nil
--   W.distances(g, t, class, door)             {[i] = cost to t} of every cell that walks to t
--   W.field(g, t, class, door)                 the same as one byte per column, the move
--                                              towards t (0 at t, NONE: no way); built once
--   W.descend(g, field, i, steps)              the cells of the field's walk from i
--   W.line(g, a, b, class, hw, door, rise)     a straight walk from point a to point b
--                                              ({x, y, z}, box-relative, y the feet) over
--                                              the moves, reading no node
local W = {}

local floor, ceil, sqrt, abs, min = math.floor, math.ceil, math.sqrt, math.abs, math.min

W.NONE = 255
W.STRAIGHT, W.DIAGONAL = 5, 7
W.SNAP = 2 -- nodes: how far an off-grid body looks for its walking cell
W.BRUSH = 0.25 -- nodes a wide body's sides may reach into a wall it walks along (W.line)
W.MOVES = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
W.QUADS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local MOVES = W.MOVES

-- The moves of a mask, as lists of move numbers (straight first).
local MASK_MOVES = {}
for mask = 0, 255 do
	local list, rest = {}, mask
	for k = 1, 8 do
		if rest % 2 == 1 then list[#list + 1] = k end
		rest = floor(rest / 2)
	end
	MASK_MOVES[mask] = list
end
-- The move number of a step (dx, dz), keyed (dx + 1) * 3 + dz + 2.
local MOVE_OF = {}
for k, d in ipairs(MOVES) do MOVE_OF[(d[1] + 1) * 3 + d[2] + 2] = k end

function W.new(tpl)
	local sx, sz = tpl.size.x, tpl.size.z
	local n = sx * sz
	assert(tpl.grid and #tpl.grid == 4 * n, "walkgrid: the template has no grid of its size")
	local g = {name = tpl.name, sx = sx, sz = sz, n = n, raw = tpl.grid, fields = {},
		-- One search at a time: its marks, stamped so nothing is cleared between searches.
		stamp = 0, seen = {}, closed = {}, cost = {}, from = {}}
	g.step = {}
	for k, d in ipairs(MOVES) do g.step[k] = d[1] + d[2] * sx end
	return g
end

function W.height(g, i) local h = g.raw:byte(i); return h ~= W.NONE and h or nil end
function W.mask(g, i) return g.raw:byte(g.n + i) end
function W.clearance(g, i) return g.raw:byte(2 * g.n + i) end
function W.flags(g, i) return g.raw:byte(3 * g.n + i) end
function W.index(g, x, z)
	if x < 0 or z < 0 or x >= g.sx or z >= g.sz then return nil end
	return z * g.sx + x + 1
end
function W.xz(g, i) return (i - 1) % g.sx, floor((i - 1) / g.sx) end

-- The class of a body `width` nodes wide (its collision box's larger side).
function W.class(width)
	if width <= 1 then return 1 end
	if width <= 2 then return 2 end
	return ceil(width / 2 - 0.5) + 2
end

-- A body of `class` may stand on walking cell i; a shut door (door false) stops it.
local function usable(g, i, class, door)
	local raw, n = g.raw, g.n
	local flags = raw:byte(3 * n + i)
	if flags % 2 == 1 and not door then return false end
	if class == 1 then return true end
	if class == 2 then return flags >= 2 end
	return raw:byte(2 * n + i) >= class - 1
end
function W.usable(g, i, class, door)
	return W.height(g, i) ~= nil and usable(g, i, class, door)
end

function W.cell(g, x, fy, z, class, door)
	local cx, cz = floor(x + 0.5), floor(z + 0.5)
	local best, best_d
	for dz = -W.SNAP, W.SNAP do
		for dx = -W.SNAP, W.SNAP do
			local i = W.index(g, cx + dx, cz + dz)
			local h = i and g.raw:byte(i)
			if h and h ~= W.NONE and abs(h - fy) <= W.SNAP and usable(g, i, class, door) then
				local ex, ez = cx + dx - x, cz + dz - z
				local d = ex * ex + ez * ez + (dx == 0 and dz == 0 and -1 or 0)
				if not best_d or d < best_d then best, best_d = i, d end
			end
		end
	end
	return best
end

-- ---- The binary heap of a search: cells by their key ---------------------------------
local hi, hk, hn = {}, {}, 0
local function push(i, key)
	hn = hn + 1
	local at = hn
	while at > 1 do
		local up = floor(at / 2)
		if hk[up] <= key then break end
		hi[at], hk[at] = hi[up], hk[up]
		at = up
	end
	hi[at], hk[at] = i, key
end
local function pop()
	local top = hi[1]
	local last_i, last_k = hi[hn], hk[hn]
	hn = hn - 1
	local at = 1
	while true do
		local child = at * 2
		if child > hn then break end
		if child < hn and hk[child + 1] < hk[child] then child = child + 1 end
		if hk[child] >= last_k then break end
		hi[at], hk[at] = hi[child], hk[child]
		at = child
	end
	hi[at], hk[at] = last_i, last_k
	return top
end

-- One search over the grid from s: A* towards t, or with t nil every cell (Dijkstra).
-- Leaves g.cost and g.from stamped with g.stamp. Returns the cells expanded and whether
-- t was reached.
local function search(g, s, t, class, door)
	g.stamp = g.stamp + 1
	local stamp, seen, closed, cost, from = g.stamp, g.seen, g.closed, g.cost, g.from
	local raw, n, sx, step = g.raw, g.n, g.sx, g.step
	local tx, tz = 0, 0
	if t then tx, tz = W.xz(g, t) end
	local function guess(i)
		if not t then return 0 end
		local dx, dz = abs((i - 1) % sx - tx), abs(floor((i - 1) / sx) - tz)
		return 5 * (dx + dz) - 3 * min(dx, dz)
	end
	hn = 0
	seen[s], cost[s], from[s] = stamp, 0, 0
	push(s, guess(s))
	local expanded = 0
	while hn > 0 do
		local i = pop()
		if closed[i] ~= stamp then
			closed[i] = stamp
			expanded = expanded + 1
			if i == t then return expanded, true end
			local base = cost[i]
			local moves = MASK_MOVES[raw:byte(n + i)]
			for m = 1, #moves do
				local k = moves[m]
				local j = i + step[k]
				if closed[j] ~= stamp and usable(g, j, class, door) then
					local c = base + (k > 4 and 7 or 5)
					if seen[j] ~= stamp or c < cost[j] then
						seen[j], cost[j], from[j] = stamp, c, i
						push(j, c + guess(j))
					end
				end
			end
		end
	end
	return expanded, false
end

function W.path(g, s, t, class, door)
	if not (W.usable(g, s, class, door) and W.usable(g, t, class, door)) then return nil end
	local expanded, found = search(g, s, t, class, door)
	if not found then return nil, nil, expanded end
	local list, i = {}, t
	while i ~= 0 do
		list[#list + 1] = i
		i = g.from[i]
	end
	for a = 1, floor(#list / 2) do
		local b = #list + 1 - a
		list[a], list[b] = list[b], list[a]
	end
	return list, g.cost[t], expanded
end

function W.distances(g, t, class, door)
	local out = {}
	if not W.usable(g, t, class, door) then return out end
	search(g, t, nil, class, door)
	local stamp, closed, cost = g.stamp, g.closed, g.cost
	for i = 1, g.n do
		if closed[i] == stamp then out[i] = cost[i] end
	end
	return out
end

-- The masks are symmetric (build.py checks it), so the distances from t are the
-- distances to t, and each cell's move is one that lies on a shortest way.
function W.field(g, t, class, door)
	local key = t .. ":" .. class .. ":" .. (door and 1 or 0)
	local field = g.fields[key]
	if field then return field end
	local dist = W.distances(g, t, class, door)
	local bytes, chunk = {}, {}
	for i = 1, g.n do
		local d, move = dist[i], W.NONE
		if d == 0 then
			move = 0
		elseif d then
			for _, k in ipairs(MASK_MOVES[W.mask(g, i)]) do
				local j = i + g.step[k]
				local dj = dist[j]
				if dj and dj + (k > 4 and 7 or 5) == d then
					move = k
					break
				end
			end
		end
		chunk[#chunk + 1] = move
		if #chunk == 1024 then
			bytes[#bytes + 1] = string.char(unpack(chunk))
			chunk = {}
		end
	end
	if #chunk > 0 then bytes[#bytes + 1] = string.char(unpack(chunk)) end
	field = table.concat(bytes)
	g.fields[key] = field
	return field
end

function W.descend(g, field, i, steps)
	local list = {}
	for _ = 1, steps do
		local move = field:byte(i)
		if move == 0 or move == W.NONE then break end
		i = i + g.step[move]
		list[#list + 1] = i
	end
	return list
end

-- The straight walk of grug_nav's line_walkable over the grid: sampled every half node,
-- each change of the centre's cell a move of its mask onto a cell the body may stand on,
-- both sides of the body (half width hw, across the walking direction) over walking cells
-- within a step of the centre's; ends within one node of b's feet (`rise` more above).
-- A body wider than a node (class 2 and up) has its room from its cells' class; its
-- sides are tested BRUSH nearer the centre, so a body that touches a wall (the engine
-- pushes it there, its centre half its width from the wall's face) still sees its way
-- along it (the Round 74 engine run: an elite in a passage got a point one cell ahead).
function W.line(g, a, b, class, hw, door, rise)
	local cx, cz = floor(a.x + 0.5), floor(a.z + 0.5)
	local i = W.index(g, cx, cz)
	local h = i and W.height(g, i)
	if not h or abs(floor(a.y + 0.55) - h) > 1 or not usable(g, i, class, door) then return false end
	local raw, n = g.raw, g.n
	local dx, dz = b.x - a.x, b.z - a.z
	local len = sqrt(dx * dx + dz * dz)
	if len >= 0.01 then
		local ux, uz = dx / len, dz / len
		local side = hw * (abs(ux) + abs(uz))
		if class > 1 then side = side > W.BRUSH and side - W.BRUSH or 0 end
		local sx, sz = -uz * side, ux * side
		for s = 1, ceil(len / 0.5) do
			local t = s * 0.5
			if t > len then t = len end
			local x, z = a.x + ux * t, a.z + uz * t
			local nx, nz = floor(x + 0.5), floor(z + 0.5)
			if nx ~= cx or nz ~= cz then
				local k = MOVE_OF[(nx - cx + 1) * 3 + nz - cz + 2]
				if not k or floor(raw:byte(n + i) / 2 ^ (k - 1)) % 2 == 0 then return false end
				i = i + g.step[k]
				if not usable(g, i, class, door) then return false end
				cx, cz, h = nx, nz, raw:byte(i)
			end
			for dir = -1, 1, 2 do
				local px, pz = floor(x + sx * dir + 0.5), floor(z + sz * dir + 0.5)
				if px ~= cx or pz ~= cz then
					local j = W.index(g, px, pz)
					local ph = j and raw:byte(j)
					if not ph or ph == W.NONE or abs(ph - h) > 1 or
							(raw:byte(3 * n + j) % 2 == 1 and not door) then
						return false
					end
				end
			end
		end
	end
	local by = floor(b.y + 0.55)
	return by - h >= -1 and by - h <= 1 + (rise or 0)
end

return W
