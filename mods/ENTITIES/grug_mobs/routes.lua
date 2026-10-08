--
-- SETTLEMENT ROUTES (Round 42 NV3; round42-plan.md rulings 5, 12-14, 16-18;
-- settlements.md "Settlement NPCs"). The walkers' and patrols' legs in start
-- towns and capitals: the terrain there is protected and never changes, and
-- the same pairs of fixed points (two idle spots, two patrol waypoints)
-- repeat all day, so a leg's route is computed once, on first use, and
-- reused by every walker that walks it.
--
--   * A LEG is one pair of fixed points (from, to) in one settlement, for one
--     body class (head room, wider than one node). Its route is a list of
--     corner points ending at `to`: a straight walk from each to the next is
--     walkable (nav.line_walkable, the smoothing of ruling 7).
--   * IT IS BUILT ON FIRST USE, one engine search at a time, each inside the
--     per-step A* budget and the global cap (nav.claim_search), each bounded:
--     padding 6 (never below 2) and no piece longer than SPLIT nodes -- a
--     longer leg is split at intermediate standable points on the straight
--     line (or beside it, when the point on it is no place to stand). A leg
--     whose searches fail MAX_FAILS times is spent (a street plan falls back
--     to the straight one once); while it builds, the walker walks to its
--     goal as a fixed walk.
--   * CAPITAL PATROLS RUN OVER THE STREETS (ruling 14): a patrol leg longer
--     than nav.MAX_LEG whose two ends each lie within STREET_REACH of a street
--     is "to the street" (a cached search), along the streets (the planner's
--     own centrelines, read from the road layout the runtime already holds,
--     `grug_mapgen.wp40.road_layout_text`; the carriageway is kept free) and
--     "from the street" (a cached search). A street route that is no route
--     (an end the search cannot join to its street, a detour of more than
--     DETOUR times the straight line) falls back to the split straight leg.
--   * THROUGH DOORS (Round 42 DR, ruling 15): a door is a wall to the
--     engine, so a leg whose plain plan is spent tries DOOR PLANS
--     (npc_doors.lua finds the doors near its ends at runtime): through one
--     of the doors nearest to `to` (the end behind it), through one of
--     those nearest to `from`, through both nearest. A door plan is "to the
--     door" (searches to the cell in front of it), "through the door" (two
--     corners: the door's centre, marked with the door, and the cell behind
--     it; no search) and "from the door" (searches on). Each starts over
--     from `from`; the first that gets through is the route.
--   * A LEG WITH NO ROUTE IS REMEMBERED as such: the walker's later stage
--     takes over at once (a villager's next spot, a patrol's next waypoint)
--     and nothing searches that leg again until the server restarts. A walker
--     away from the leg's start walks to its goal as a plain fixed walk
--     instead (with its own give-up). Unloaded is never "no route": a build
--     waits until its candidates, ends and search box are loaded, and the
--     walker meanwhile walks to its goal as a fixed walk.
--   * FOLLOWING: the walker steers at its next corner with the fixed walk
--     (patrol.lua walk_fixed: the one stuck detector, a local search when it
--     is stuck, followed to its end); a corner within CORNER_REACH is passed.
--     A walker that starts a leg away from it (after a fight, a reload, a
--     skipped spot) takes the corner that ends the route segment nearest to
--     it: walking there is the return to the route (ruling 5); one more than
--     two nodes off and blocked is stuck within a second and searches its way
--     back to that corner. At a door corner it opens the door (within
--     npc_doors.OPEN_REACH) and is steered every step until it stands behind
--     it; the door is closed after it (npc_doors.settle, from walk_follow).
--
-- Kept in memory only (round42-plan.md §7: persisting is decided by the
-- measurement; tools/r42_nv3). Settlements other than start towns and
-- capitals have no cache: their walkers follow fixed targets (walk_fixed).
--
local nav = mobs.grug_nav
local doors = grug_mobs.npc_doors
local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

local routes = {
	SPLIT = 24, -- nodes: a longer straight piece is split
	MAX_FAILS = 4, -- failed engine searches that spend a leg's plan
	STREET_REACH = 24, -- nodes from a patrol point to its street
	STREET_RISE = 6, -- nodes of height between them
	STREET_DEV = 1, -- nodes a street corner line may leave the centreline
	STREET_GAP = 24, -- nodes between two street corners at most
	STREET_JOIN = 1.5, -- nodes: two streets this close are joined
	DETOUR = 3, -- a street route longer than this times the straight line is none
	CORNER_REACH = 0.4, -- nodes: a corner is passed (checked every step)
	FROM_SLACK = 5, -- nodes from a leg's start within which "no route" holds
	SMOOTH_MARGIN = 0.25, -- nodes of side room a corner line keeps in addition
	LOOK = 16, -- path points one smoothing test looks ahead
	CAPITAL_REACH = 320, -- nodes from a capital's anchor its streets start
	OFFSETS = {0, 3, -3, 6, -6}, -- nodes beside the line for a split point
}
grug_mobs.routes = routes

-- settlement key -> {kind, anchor, legs = {leg key -> entry}, streets = graph,
-- false (none) or nil (not read yet), stats}
local settlements = {}

-- The start towns and capitals (start_npcs.lua build_rows registers them).
function grug_mobs.route_settlement(key, kind, anchor)
	if kind ~= "start" and kind ~= "capital" then return end
	settlements[key] = {kind = kind, anchor = {x = anchor.x, y = anchor.y,
		z = anchor.z}, legs = {}, stats = {legs = 0, ok = 0, none = 0,
		searches = 0, search_us = 0, max_us = 0, smooth_us = 0, corners = 0,
		street_legs = 0, streets_us = 0, door_legs = 0}}
end

function grug_mobs.route_cached(key)
	return settlements[key] ~= nil
end

--
-- Cells.
--
local function engine_walkable(x, y, z)
	local node = core.get_node_or_nil({x = x, y = y, z = z})
	if not node or node.name == "ignore" then return nil end
	local def = core.registered_nodes[node.name]
	return not def or def.walkable == true
end

-- A fixed point's search cell: its feet cell, one up when that is a slab or
-- a step (the engine refuses a walkable end). nil: not loaded, or no end.
local function end_cell(p)
	local x, y, z = floor(p.x + 0.5), floor(p.y + 0.5), floor(p.z + 0.5)
	local w = engine_walkable(x, y, z)
	if w == nil then return nil, "unloaded" end
	if w then
		y = y + 1
		w = engine_walkable(x, y, z)
		if w == nil then return nil, "unloaded" end
		if w then return nil end
	end
	return {x = x, y = y, z = z}
end

local function hdist(a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	return sqrt(dx * dx + dz * dz)
end

--
-- Smoothing (ruling 7): from each kept point the furthest of the next LOOK
-- path points a straight walk reaches. Appends to `out` without the first.
--
local function smooth(body, pts, out)
	local i, n = 1, #pts
	while i < n do
		local j = i + routes.LOOK
		if j > n then j = n end
		while j > i + 1 and not nav.line_walkable(body, pts[i], pts[j]) do
			j = j - 1
		end
		local p = pts[j]
		out[#out + 1] = {x = p.x, y = floor(p.y + 0.5), z = p.z}
		i = j
	end
end

--
-- THE STREETS of a capital, from the road layout the runtime holds: the
-- capital planner's avenues and lanes (road_layout.lua; their centrelines
-- at one node spacing, R the surface height). Read once per capital on first
-- need; nil when the runtime has no layout (a fixture, a bare test world).
--
local road_module
local function street_roads(anchor)
	local wp40 = rawget(_G, "grug_mapgen") and grug_mapgen.wp40
	local text = wp40 and wp40.road_layout_text
	if type(text) ~= "string" then return nil end
	if not road_module then
		road_module = dofile(core.get_modpath("grug_mapgen") .. "/wp40/road_layout.lua")
	end
	local layout = road_module.deserialize(text)
	local out = {}
	local reach2 = routes.CAPITAL_REACH * routes.CAPITAL_REACH
	for _, road in pairs(layout.roads) do
		if road.kind == "avenue" or road.kind == "lane" then
			local dx, dz = road.X[1] - anchor.x, road.Z[1] - anchor.z
			if dx * dx + dz * dz <= reach2 then
				out[#out + 1] = {id = road.id, X = road.X, Z = road.Z, R = road.R}
			end
		end
	end
	-- Ids, not table order: the same graph on every boot.
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

-- Stop ids: road index * S + point index.
local S = 65536

--
-- The street graph: every road's two ends and every point where it meets
-- another road (centrelines within STREET_JOIN, surfaces within one node)
-- are stops; edges run along a road between neighbouring stops and across
-- each meeting. Pure; `roads` = {{X, Z, R}, ...}.
--
function routes.street_graph(roads)
	local g = {roads = {}, joins = {}}
	local cells = {}
	for ri, road in ipairs(roads) do
		local n = #road.X
		local cum = {0}
		for i = 2, n do
			local dx, dz = road.X[i] - road.X[i - 1], road.Z[i] - road.Z[i - 1]
			local dy = road.R[i] - road.R[i - 1]
			cum[i] = cum[i - 1] + sqrt(dx * dx + dz * dz + dy * dy)
		end
		g.roads[ri] = {X = road.X, Z = road.Z, R = road.R, cum = cum,
			stop = {[1] = true, [n] = true}}
		for i = 1, n do
			local k = floor(road.X[i]) * S + floor(road.Z[i])
			local list = cells[k]
			if not list then
				list = {}
				cells[k] = list
			end
			list[#list + 1] = ri * S + i
		end
	end
	local join2 = routes.STREET_JOIN * routes.STREET_JOIN
	for ri, road in ipairs(g.roads) do
		for i = 1, #road.X do
			local x, z = road.X[i], road.Z[i]
			local cx, cz = floor(x), floor(z)
			for ox = -1, 1 do
				for oz = -1, 1 do
					local list = cells[(cx + ox) * S + cz + oz]
					for k = 1, list and #list or 0 do
						local id = list[k]
						local rj = floor(id / S)
						if rj > ri then
							local j = id - rj * S
							local other = g.roads[rj]
							local dx, dz = other.X[j] - x, other.Z[j] - z
							if dx * dx + dz * dz <= join2
							and abs(other.R[j] - road.R[i]) <= 1 then
								local a, b = ri * S + i, id
								road.stop[i], other.stop[j] = true, true
								local w = sqrt(dx * dx + dz * dz)
								g.joins[a] = g.joins[a] or {}
								g.joins[b] = g.joins[b] or {}
								g.joins[a][#g.joins[a] + 1] = {b, w}
								g.joins[b][#g.joins[b] + 1] = {a, w}
							end
						end
					end
				end
			end
		end
	end
	-- Each road's stops in order, and the place of each in that order.
	for _, road in ipairs(g.roads) do
		local order, at = {}, {}
		for i = 1, #road.X do
			if road.stop[i] then
				order[#order + 1] = i
				at[i] = #order
			end
		end
		road.order, road.at, road.stop = order, at, nil
	end
	return g
end

-- The nearest centreline point to `p` within STREET_REACH and STREET_RISE:
-- road index, point index, distance; nil when there is none.
function routes.street_entry(g, p)
	local best, bi, bd2
	local reach2 = routes.STREET_REACH * routes.STREET_REACH
	for ri, road in ipairs(g.roads) do
		for i = 1, #road.X do
			local dx, dz = road.X[i] - p.x, road.Z[i] - p.z
			local d2 = dx * dx + dz * dz
			if d2 <= reach2 and (not bd2 or d2 < bd2)
			and abs(floor(road.R[i] + 0.5) + 1 - p.y) <= routes.STREET_RISE then
				best, bi, bd2 = ri, i, d2
			end
		end
	end
	if best then return best, bi, sqrt(bd2) end
end

-- The neighbouring stops of point i on a road (the stop at or below it and
-- the one at or above it).
local function around(road, i)
	local order = road.order
	local lo, hi = order[1], order[#order]
	for k = 1, #order do
		local s = order[k]
		if s <= i then lo = s end
		if s >= i then
			hi = s
			break
		end
	end
	return lo, hi
end

--
-- The shortest way along the streets from point (ra, ia) to (rb, ib):
-- Dijkstra over the stops (a capital has a few hundred; a linear scan for
-- the next one is enough). Returns the centreline points in walking order
-- and the length, or nil.
--
function routes.street_route(g, ra, ia, rb, ib)
	local dist, prev, done, open = {}, {}, {}, {}
	local function relax(id, d, from)
		if not dist[id] or d < dist[id] then
			dist[id], prev[id] = d, from
			open[#open + 1] = id
		end
	end
	local A, B = g.roads[ra], g.roads[rb]
	local best, best_end = math.huge, nil
	if ra == rb then best, best_end = abs(A.cum[ia] - A.cum[ib]), "direct" end
	local lo, hi = around(A, ia)
	relax(ra * S + lo, abs(A.cum[ia] - A.cum[lo]), "entry")
	relax(ra * S + hi, abs(A.cum[ia] - A.cum[hi]), "entry")
	while true do
		local pick, pk
		for k = 1, #open do
			local id = open[k]
			if not done[id] and (not pick or dist[id] < dist[pick]) then
				pick, pk = id, k
			end
		end
		if not pick or dist[pick] >= best then break end
		open[pk] = open[#open]
		open[#open] = nil
		done[pick] = true
		local r = floor(pick / S)
		local i = pick - r * S
		local road = g.roads[r]
		local d = dist[pick]
		if r == rb and d + abs(B.cum[i] - B.cum[ib]) < best then
			best, best_end = d + abs(B.cum[i] - B.cum[ib]), pick
		end
		local at = road.at[i]
		for _, k in ipairs({at - 1, at + 1}) do
			local s = road.order[k]
			if s then relax(r * S + s, d + abs(road.cum[s] - road.cum[i]), pick) end
		end
		for _, join in ipairs(g.joins[pick] or {}) do
			relax(join[1], d + join[2], pick)
		end
	end
	if not best_end then return nil end
	-- The stops back to the entry, then the runs along each road.
	local chain = {}
	local id = best_end
	while id ~= "direct" and id ~= "entry" do
		table.insert(chain, 1, id)
		id = prev[id]
	end
	local pts = {}
	local function run(r, i, j)
		local road = g.roads[r]
		local step = j >= i and 1 or -1
		for k = i, j, step do
			local p = pts[#pts]
			if not p or p.x ~= road.X[k] or p.z ~= road.Z[k] then
				pts[#pts + 1] = {x = road.X[k], z = road.Z[k], r = road.R[k]}
			end
		end
	end
	local cr, ci = ra, ia
	for _, stop in ipairs(chain) do
		local r = floor(stop / S)
		local i = stop - r * S
		if r == cr then run(r, ci, i) else run(r, i, i) end
		cr, ci = r, i
	end
	run(rb, cr == rb and ci or ib, ib)
	return pts, best
end

--
-- A street run as corner points: Douglas-Peucker within STREET_DEV of the
-- centreline, no two corners further apart than STREET_GAP, each at the
-- feet height of its surface (R; a half step is a slab under the feet).
--
function routes.street_corners(pts)
	local n = #pts
	local keep = {[1] = true, [n] = true}
	local stack = {{1, n}}
	local dev2 = routes.STREET_DEV * routes.STREET_DEV
	while #stack > 0 do
		local seg = table.remove(stack)
		local a, b = pts[seg[1]], pts[seg[2]]
		local vx, vz = b.x - a.x, b.z - a.z
		local l2 = vx * vx + vz * vz
		local far, fk = -1, nil
		for k = seg[1] + 1, seg[2] - 1 do
			local p = pts[k]
			local wx, wz = p.x - a.x, p.z - a.z
			local t = l2 > 0 and (wx * vx + wz * vz) / l2 or 0
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			local ex, ez = wx - vx * t, wz - vz * t
			local e2 = ex * ex + ez * ez
			if e2 > far then far, fk = e2, k end
		end
		if fk and far > dev2 then
			keep[fk] = true
			stack[#stack + 1] = {seg[1], fk}
			stack[#stack + 1] = {fk, seg[2]}
		end
	end
	local out, last = {}, nil
	local function corner(p)
		out[#out + 1] = {x = p.x, y = floor(p.r + 0.5) + 1, z = p.z}
	end
	for k = 1, n do
		if keep[k] then
			if last then
				-- A long straight run gets corners in between (its points
				-- lie within STREET_DEV of the chord).
				local parts = ceil(hdist(pts[last], pts[k]) / routes.STREET_GAP)
				for s = 1, parts - 1 do
					corner(pts[floor(last + (k - last) * s / parts + 0.5)])
				end
			end
			corner(pts[k])
			last = k
		end
	end
	return out
end

-- The capital's street graph, built on first need; false: none.
local function streets_of(set)
	if set.streets ~= nil then return set.streets end
	local t0 = core.get_us_time()
	local roads = street_roads(set.anchor)
	set.streets = roads and #roads > 0 and routes.street_graph(roads) or false
	set.stats.streets_us = core.get_us_time() - t0
	return set.streets
end

--
-- A leg's plan: the steps its build runs in turn. A search step goes from
-- the last point reached to `to` (or to the first standable candidate of a
-- split point beside the line); a street step appends its corners.
--
local function split_steps(steps, a, b)
	local n = ceil(hdist(a, b) / routes.SPLIT)
	for k = 1, n - 1 do
		steps[#steps + 1] = {split = {a = a, b = b, t = k / n}}
	end
	steps[#steps + 1] = {to = b}
end

local function plan(set, a, b, patrol)
	local steps = {}
	if patrol and set.kind == "capital" and hdist(a, b) > nav.MAX_LEG then
		local g = streets_of(set)
		local ra, ia = nil, nil
		local rb, ib = nil, nil
		if g then
			ra, ia = routes.street_entry(g, a)
			rb, ib = routes.street_entry(g, b)
		end
		local pts, len
		if ra and rb then pts, len = routes.street_route(g, ra, ia, rb, ib) end
		if pts and #pts >= 2 and len <= routes.DETOUR * hdist(a, b) then
			local corners = routes.street_corners(pts)
			local entry, exit = corners[1], corners[#corners]
			split_steps(steps, a, entry)
			steps[#steps + 1] = {street = corners}
			split_steps(steps, exit, b)
			steps.street = true
			return steps
		end
	end
	split_steps(steps, a, b)
	return steps
end

-- Is the column (x, z) loaded from `y - band` to `y + band`? A mapblock is
-- 16 nodes high: its two ends and its middle answer for it.
local function column_loaded(x, y, z, band)
	for _, dy in ipairs({-band, 0, band}) do
		local node = core.get_node_or_nil({x = x, y = y + dy, z = z})
		if not node or node.name == "ignore" then return false end
	end
	return true
end

-- The candidates of a split point: on the line at its fraction, then beside
-- it (OFFSETS across the line), the first standable one for `body`; "wait"
-- when a candidate before it is not loaded (unloaded is never "nowhere to
-- stand").
local function split_point(body, sp, skip)
	local a, b, t = sp.a, sp.b, sp.t
	local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
	local y0 = floor(a.y + (b.y - a.y) * t + 0.5)
	local len = hdist(a, b)
	local ux, uz = (b.z - a.z) / len, -(b.x - a.x) / len
	local seen = 0
	for _, off in ipairs(routes.OFFSETS) do
		local cx, cz = floor(x + ux * off + 0.5), floor(z + uz * off + 0.5)
		if not column_loaded(cx, y0, cz, 3) then return "wait" end
		local y = nav.stand_y(body, cx, cz, y0, 3)
		if y then
			seen = seen + 1
			if seen > skip then return {x = cx, y = y, z = cz} end
		end
	end
	return nil
end

local function key_of(body, a, b)
	return ("%d,%d,%d>%d,%d,%d/%d%s"):format(floor(a.x + 0.5), floor(a.y + 0.5),
		floor(a.z + 0.5), floor(b.x + 0.5), floor(b.y + 0.5), floor(b.z + 0.5),
		body.head, body.width > 1 and "w" or "")
end

local function finish(set, entry, state)
	entry.state, entry.job = state, nil
	local st = set.stats
	if state == "ok" then
		st.ok = st.ok + 1
		st.corners = st.corners + #entry.points
		if entry.street then st.street_legs = st.street_legs + 1 end
		if entry.doors then st.door_legs = st.door_legs + 1 end
	else
		st.none = st.none + 1
		entry.points = nil
	end
end

-- The search box of (from, to) at padding nav.PADDING: loaded at every
-- mapblock it touches, at the heights of both ends (sampled every 16 nodes).
local function box_loaded(from, to)
	local pad = nav.PADDING
	local x1, x2 = math.min(from.x, to.x) - pad, math.max(from.x, to.x) + pad - 1
	local z1, z2 = math.min(from.z, to.z) - pad, math.max(from.z, to.z) + pad - 1
	local P = {}
	for _, y in ipairs({from.y, to.y}) do
		local x = x1
		while true do
			local z = z1
			while true do
				P.x, P.y, P.z = x, y, z
				local node = core.get_node_or_nil(P)
				if not node or node.name == "ignore" then return false end
				if z >= z2 then break end
				z = math.min(z + 16, z2)
			end
			if x >= x2 then break end
			x = math.min(x + 16, x2)
		end
	end
	return true
end

--
-- THE DOOR PLANS of a leg whose plain plans are spent: through each of the
-- doors nearest to `b`, then each of those nearest to `a`, then through the
-- nearest of both. The side of a door its end is on is the side that end
-- lies on (a room behind a door lies behind its wall). "wait" while the
-- area round an end is not loaded.
--
local function door_plans(a, b)
	local da = doors.near(a)
	if da == "wait" then return "wait" end
	local db = doors.near(b)
	if db == "wait" then return "wait" end
	local plans = {}
	for _, d in ipairs(db) do plans[#plans + 1] = {nil, d} end
	for _, d in ipairs(da) do plans[#plans + 1] = {d, nil} end
	if da[1] and db[1] and da[1].key ~= db[1].key then
		plans[#plans + 1] = {da[1], db[1]}
	end
	return plans
end

-- A door plan's steps: first a check per door that its end reaches its own
-- side of it (a short search in the room, in walking order; a wrong door
-- costs that one, not a walk across the town; the walk reuses its path),
-- then to the door, through it ({door, behind}), on.
local function door_steps(a, b, plan)
	local steps, from = {}, a
	local da, db = plan[1], plan[2]
	if da then steps[#steps + 1] = {check = a, to = (doors.sides(da, a))} end
	if db then steps[#steps + 1] = {check = (doors.sides(db, b)), to = b} end
	if da then
		local here, there = doors.sides(da, a)
		split_steps(steps, from, here)
		steps[#steps + 1] = {door = da, behind = there}
		from = there
	end
	if db then
		local here, there = doors.sides(db, b)
		split_steps(steps, from, there)
		steps[#steps + 1] = {door = db, behind = here}
		from = here
	end
	split_steps(steps, from, b)
	return steps
end

--
-- One step of a pending leg's build: street and door steps at once, then at most one
-- engine search, when the cap and the step's budget allow (the queue is
-- keyed by the build). Nothing happens while a candidate, an end or the
-- search box is not loaded: unloaded is "later", never "no route".
--
local function advance(set, entry)
	local job = entry.job
	-- A build that found its area unloaded looks again a second later, not
	-- every step of every walker waiting on it.
	local now = core.get_us_time()
	if now < (job.wait_until or 0) then return end
	local steps = job.steps
	while job.i <= #steps and (steps[job.i].street or steps[job.i].door) do
		local s = steps[job.i]
		local points = entry.points
		if s.street then
			for k = 2, #s.street do points[#points + 1] = s.street[k] end
			job.from = s.street[#s.street]
		else
			-- Through the door: its centre (the door rides on the corner)
			-- and the cell behind it; the cell in front ended the search.
			local d = s.door
			points[#points + 1] = {x = d.x, y = d.y, z = d.z,
				door = {x = d.x, y = d.y, z = d.z, key = d.key}}
			points[#points + 1] = {x = s.behind.x, y = s.behind.y, z = s.behind.z}
			job.from = s.behind
			entry.doors = (entry.doors or 0) + 1
		end
		job.i = job.i + 1
	end
	local step = steps[job.i]
	if not step then return finish(set, entry, "ok") end
	if job.fails >= routes.MAX_FAILS then
		-- A street plan that ran out falls back to the straight leg once.
		if steps.street and not job.fallback then
			job.fallback, job.fails = true, 0
			job.steps, job.i, job.from = {}, 1, entry.a
			split_steps(job.steps, entry.a, entry.b)
			entry.points, entry.street = {}, nil
			return
		end
		-- Then the door plans, each from the start again.
		if not job.door_plans then
			local plans = door_plans(entry.a, entry.b)
			if plans == "wait" then
				job.wait_until = now + 1000000
				return
			end
			job.door_plans, job.di = plans, 0
		end
		job.di = job.di + 1
		local plan = job.door_plans[job.di]
		if not plan then return finish(set, entry, "none") end
		job.steps, job.i, job.fails = door_steps(entry.a, entry.b, plan), 1, 0
		job.checked = nil
		job.from, entry.points, entry.street, entry.doors = entry.a, {}, nil, nil
		return
	end
	local body = job.body
	local goal = step.to
	if step.split then
		goal = split_point(body, step.split, step.skip or 0)
		if goal == "wait" then
			job.wait_until = now + 1000000
			return
		end
		if not goal then
			-- No candidate left: the plan is spent.
			job.fails = routes.MAX_FAILS
			return
		end
	end
	local from, why = end_cell(step.check or job.from)
	local to, why2 = end_cell(goal)
	if why == "unloaded" or why2 == "unloaded" then
		job.wait_until = now + 1000000
		return
	end
	local steer
	local pair = from and to and (from.x .. "," .. from.y .. "," .. from.z .. ">" ..
		to.x .. "," .. to.y .. "," .. to.z)
	if from and to and from.x == to.x and from.y == to.y and from.z == to.z then
		-- Already there (a leg that starts in front of its door).
		steer = {from}
	elseif pair and job.checked and job.checked[pair] then
		-- The door plan's check searched this very piece.
		steer = job.checked[pair]
		job.checked[pair] = nil
	elseif from and to then
		-- The engine reads unloaded nodes as walls: a search whose box is
		-- not loaded waits, so no route is ever "none" for want of a load.
		if not box_loaded(from, to) then
			job.wait_until = now + 1000000
			return
		end
		-- The queue is keyed by the build, not by a walker: any walker on
		-- the leg may claim the grant, and a walker's own local searches
		-- keep theirs.
		if not nav.claim_search(job) then return end
		local t0 = core.get_us_time()
		local path = nav.search(from, to, nav.PADDING, body.jump, body.drop)
		local t1 = core.get_us_time()
		steer = path and nav.check_path(body, path)
		local st = set.stats
		st.searches = st.searches + 1
		st.search_us = st.search_us + (t1 - t0)
		if t1 - t0 > st.max_us then st.max_us = t1 - t0 end
	end
	if not steer then
		-- A split point gets its next candidate; a fixed end has none, so
		-- the plan is spent (a street plan falls back once, above).
		job.fails = job.fails + 1
		if step.split then
			step.skip = (step.skip or 0) + 1
		else
			job.fails = routes.MAX_FAILS
		end
		return
	end
	if step.check then
		-- The end reaches its side of the door: on to the plan's walk,
		-- which takes this path when it walks the same piece.
		job.checked = job.checked or {}
		job.checked[pair] = steer
		job.i = job.i + 1
		return
	end
	local t1 = core.get_us_time()
	steer[#steer] = {x = goal.x, y = to.y, z = goal.z}
	smooth(body, steer, entry.points)
	set.stats.smooth_us = set.stats.smooth_us + (core.get_us_time() - t1)
	job.from = {x = goal.x, y = to.y, z = goal.z}
	job.i = job.i + 1
	if job.i > #steps then finish(set, entry, "ok") end
end

-- The cache entry of leg (a, b) for this body; a new one starts pending.
local function entry_of(set, body, a, b, patrol)
	local key = key_of(body, a, b)
	local entry = set.legs[key]
	if entry then return entry, key end
	local steps = plan(set, a, b, patrol)
	entry = {state = "pending", key = key, set = set, a = a, b = b, points = {},
		street = steps.street,
		job = {steps = steps, i = 1, fails = 0, body = body,
			from = {x = a.x, y = a.y, z = a.z}}}
	-- The body's cell rules only; the walker itself is not kept. Its sides
	-- get SMOOTH_MARGIN more room: the line test samples every half node, and
	-- a corner line that grazes a trunk between two samples is a walker that
	-- slides along the bark slowly enough to read stuck.
	local copy = {}
	for k, v in pairs(body) do copy[k] = v end
	copy.mob = nil
	copy.hw = copy.hw + routes.SMOOTH_MARGIN
	entry.job.body = copy
	set.legs[key] = entry
	set.stats.legs = set.stats.legs + 1
	return entry, key
end

-- The route segment nearest to `pos`; the index of the corner ending it.
local function nearest_corner(points, a, pos)
	local best, bk = nil, 1
	local prev = a
	for k = 1, #points do
		local p = points[k]
		local vx, vz = p.x - prev.x, p.z - prev.z
		local wx, wz = pos.x - prev.x, pos.z - prev.z
		local l2 = vx * vx + vz * vz
		local t = l2 > 0 and (wx * vx + wz * vz) / l2 or 0
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local ex, ez = wx - vx * t, wz - vz * t
		local e2 = ex * ex + ez * ez
		if not best or e2 < best then best, bk = e2, k end
		prev = p
	end
	return bk
end

-- Is corner k of `points` passed? The cell in front of a door is reached
-- closer (FRONT_REACH): a walker lined up with the doorway walks through it.
local function passed(c, pos, nxt)
	local dx, dz = c.x - pos.x, c.z - pos.z
	local r = nxt and nxt.door and doors.FRONT_REACH or routes.CORNER_REACH
	return dx * dx + dz * dz < r * r
end

-- The door ahead of a walker on corner k (heading for the cell in front of
-- it, for its centre or for the cell behind it): heading through it, opening
-- it once near. Returns the point to steer at every step while it does (the
-- middle of the doorway, npc_doors.aim), nil otherwise.
local function door_ahead(self, points, k, pos)
	local c, nxt = points[k], points[k + 1]
	if not c then
		if nxt and nxt.door then doors.heading(self, nxt.door) end
		return nil
	end
	local prev = k > 1 and points[k - 1] or nil
	local d = c.door or (nxt and nxt.door) or (prev and prev.door)
	doors.heading(self, (c.door or (nxt and nxt.door)) and d or nil)
	if not d then return nil end
	if c.door then
		doors.approach(self, pos, d)
	elseif not (prev and prev.door) then
		-- On the way to the cell in front: steered only for its last nodes.
		local dx, dz = c.x - pos.x, c.z - pos.z
		if dx * dx + dz * dz > 4 then return nil end
	end
	return doors.aim(d, c)
end

-- Is the walker in a doorway on its way through (a cached route's door
-- corner, or the cell behind it while still within CLEAR of the door; a
-- fixed walk's door detour crossing; within CLEAR of a door it holds)? An amble does not stop there
-- (start_villagers.lua): arriving in the doorway would hold the door open.
function grug_mobs.door_crossing(self, pos)
	local t = self.temp
	if not t then return false end
	if t.grug_walk and t.grug_walk.phase == "cross" then return true end
	for _, o in pairs(t.grug_door_open or {}) do
		-- Still in the doorway of a door it holds open.
		local dx, dz = o.x - pos.x, o.z - pos.z
		if dx * dx + dz * dz < doors.CLEAR * doors.CLEAR then return true end
	end
	local leg = t.grug_leg
	local points = leg and leg.k and leg.entry.state == "ok" and leg.entry.points
	local c = points and points[leg.k]
	if not c then return false end
	if c.door then return true end
	local prev = leg.k > 1 and points[leg.k - 1]
	if not (prev and prev.door) then return false end
	local dx, dz = prev.x - pos.x, prev.z - pos.z
	return dx * dx + dz * dz < doors.CLEAR * doors.CLEAR
end

local ON_ROUTE = {route = true}

--
-- One decision of a leg walk, from its owner's once-a-second tick: walk leg
-- (from, to) of settlement `key` as walk `owner` (`patrol`: a patrol, which
-- takes the streets in a capital). Returns the fixed walk's failed searches
-- in a row toward the current corner (or toward `to` while the leg is still
-- built), and true as a second value when the leg has no route and the
-- walker stands at its start (the owner's later stage, now). nil: the owner
-- walks to `to` itself as a fixed walk -- this settlement has no route
-- cache, the walker flies, or the leg has no route but the walker is away
-- from its start (FROM_SLACK): the leg's verdict is about `from`, not about
-- where the walker stands.
--
function grug_mobs.route_walk(self, dtime, pos, key, from, to, owner, patrol)
	local set = settlements[key]
	if not set or self.fly or from.y == nil or to.y == nil then return nil end
	self.temp = self.temp or {}
	local t = self.temp
	local leg = t.grug_leg
	if not leg or leg.owner ~= owner or leg.from ~= from or leg.to ~= to then
		local entry, lk = entry_of(set, nav.body(self), from, to, patrol)
		leg = {owner = owner, from = from, to = to, entry = entry, key = lk}
		t.grug_leg = leg
	end
	local entry = leg.entry
	if entry.state == "pending" then advance(set, entry) end
	if entry.state == "none" then
		local dx, dz = from.x - pos.x, from.z - pos.z
		if dx * dx + dz * dz > routes.FROM_SLACK * routes.FROM_SLACK then
			return nil
		end
		grug_mobs.walk_clear(self, owner)
		return 0, true
	end
	if entry.state == "pending" then
		-- While the route is built (or waits for its area to load): the
		-- fixed walk at the goal, stuck detector and local search included.
		return grug_mobs.walk_fixed(self, dtime, pos, to.x, to.y, to.z,
			leg.key .. "#to", owner)
	end
	local points = entry.points
	if not leg.k then
		-- Joining the route: the corner ending the nearest segment when the
		-- way there is a straight walk, else that segment's start (a patrol
		-- counts a waypoint reached 4 nodes short of it; a walker pushed
		-- aside). 0 is the leg's own start.
		local k = nearest_corner(points, from, pos)
		local body = nav.body(self)
		local feet = {x = pos.x, y = pos.y + body.feet, z = pos.z}
		if not nav.line_walkable(body, feet, points[k]) then k = k - 1 end
		leg.k = k
	end
	while leg.k < #points
			and passed(leg.k == 0 and from or points[leg.k], pos, points[leg.k + 1]) do
		leg.k = leg.k + 1
	end
	local c = leg.k == 0 and from or points[leg.k]
	if leg.wk ~= leg.k then leg.wk, leg.wkey = leg.k, leg.key .. "#" .. leg.k end
	door_ahead(self, points, leg.k, pos)
	-- A corner is the route's own: no door detour of the fixed walk.
	return grug_mobs.walk_fixed(self, dtime, pos, c.x, c.y, c.z, leg.wkey, owner,
		ON_ROUTE)
end

--
-- Every other step of the owner: a pending leg builds on (the budget queue
-- grants a search for the next step only), a passed corner turns the walker
-- at once (a once-a-second nudge overshoots it by a second's walk), and the
-- fixed walk steers along a local path.
--
function grug_mobs.route_follow(self, dtime, owner)
	local t = self.temp
	local leg = t and t.grug_leg
	if leg and leg.owner == owner and not self.attack
			and (self.state == "stand" or self.state == "walk") then
		local entry = leg.entry
		if entry.state == "pending" then
			advance(entry.set, entry)
		elseif entry.state == "ok" and leg.k then
			local pos = self.object:get_pos()
			local points = entry.points
			if pos and leg.k < #points and passed(leg.k == 0 and leg.from
					or points[leg.k], pos, points[leg.k + 1]) then
				leg.k = leg.k + 1
				while leg.k < #points and passed(points[leg.k], pos, points[leg.k + 1]) do
					leg.k = leg.k + 1
				end
				grug_mobs.walk_clear(self, owner)
				local c = door_ahead(self, points, leg.k, pos) or entry.points[leg.k]
				grug_mobs.walk_toward(self, c.x, c.z, pos)
				return
			end
			local aim = pos and door_ahead(self, points, leg.k, pos)
			if aim then
				-- Into, through and out of a doorway: steered at its middle
				-- every step, no random turn into the frame.
				grug_mobs.walk_toward(self, aim.x, aim.z, pos)
			end
		end
	end
	grug_mobs.walk_follow(self, dtime, owner)
end

-- The leg walk is over (arrived, given up, a fight): the next one starts at
-- its own nearest corner.
function grug_mobs.route_clear(self, owner)
	local t = self.temp
	local leg = t and t.grug_leg
	if leg and (not owner or leg.owner == owner) then
		t.grug_leg, t.grug_door_next = nil, nil
	end
	grug_mobs.walk_clear(self, owner)
end

-- What the cache holds for one settlement (the probe, the report).
function grug_mobs.route_cache_stats(key)
	local set = settlements[key]
	if not set then return nil end
	local out = {}
	for k, v in pairs(set.stats) do out[k] = v end
	local pending = 0
	for _, entry in pairs(set.legs) do
		if entry.state == "pending" then pending = pending + 1 end
	end
	out.pending = pending
	if set.streets then
		local stops, points = 0, 0
		for _, road in ipairs(set.streets.roads) do
			stops, points = stops + #road.order, points + #road.X
		end
		out.street_roads, out.street_stops, out.street_points =
			#set.streets.roads, stops, points
	end
	return out
end
