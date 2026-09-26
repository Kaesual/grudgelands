-- Round 22 Phase 4: the road network (roads v2; world_zones.md §9, plan D9,
-- D14, D15, D18, D19, D44-D51, D59, D67, D68). Float maths (D2), pure, no
-- chunk state and no cache file (D37).
--
--   local roads = dofile(".../road_layout.lua")
--   local inputs = roads.inputs(source, position_of)   -- nodes, trails, order
--   local layout = roads.build(seed, opts)            -- main only, once
--   local text = roads.serialize(layout)              -- the ipc_set payload
--   local S = roads.sampler(roads.deserialize(text))  -- main and emerge
--   S.column(x, z, t, wy) -> per-column road answer (see sampler)
--   layout.connect(kind, a, b, through)               -- point-to-point (main)
--
-- Mechanism:
--  1. Routing on the shared 16-node natural-field grid of the water layout
--     (height.water_coarse_grid()): A* over (cell, heading) states with 16
--     headings, so turns cost and serpentines come out as a few long legs
--     with 2-cell hairpins (legs 16 apart, D45). Costs: length with a
--     low-frequency noise factor, grade (a steep penalty above 1:2.5 plus a
--     preference for grades gentler than ~1:4, D67), cross slope (bench
--     cost), rivers/lakes (bridge cost), forbidden cells (sea, reserved
--     areas, POI cores).
--  2. Greedy network (D14): capitals chained per faction; starts, villages
--     and the contested endpoints join the nearest road (T junctions, a
--     minimum gap between junctions); loops where the network distance is
--     long against the straight one; every trail candidate joins the nearest
--     road (D67).
--  3. Geometry: cell path -> Chaikin -> moving average -> a small lateral
--     wiggle from 2D noise on gentle ground -> 1-node points on a 1/128
--     lattice.
--  4. Profile: a DP over levels in 1/16 node along the 1-node centreline,
--     fitted to the carved natural ground at the centre and both edges; the
--     slope bound keeps every pair of neighbouring road columns within 1/2
--     node after rounding to half steps (D49), hairpins and junction mouths
--     are flat, bridges clear the water by CLEAR, shallow water may be
--     forded. The uphill edge's cut costs more on steep side slopes, so a
--     half gallery beats a deep cut (D67). Free decks (no ground on either
--     side, outside a short valley crossing) are a last resort (D68); the
--     audit only classifies them.
--  5. Sampler: per column, the nearest road surface segment gives the road
--     height; side slopes are a min/max over every segment in reach, so the
--     result is continuous across bisectors (no seams, no straight edges).
local DEFAULT_P = {
	-- routing grid costs (node-equivalents)
	NOISE_PERIOD = 320, NOISE_AMP = 0.35, K_GENTLE = 0.6,
	GMAX = 0.4, K_STEEP = 25, TRAIL_GMAX = 0.5,
	G0 = 0.25, K_G = 3,           -- gentle-grade preference above ~1:4 (D67)
	SIDE0 = 0.35, K_SIDE = 4,
	C_RIVER = 60, C_RIVER_W = 6, RIVER_PAD = 12, C_LAKE = 300,
	K_PARALLEL = 0.5,
	TURN_K = 6, SHARP_TURN = 40, TURN_MAX_DEG = 136, K_PLATFORM = 4, LOOP_LOOKBACK = 8,
	-- avenue and lane: capital streets (`capital_planner.lua`)
	HALF = {primary = 3.5, secondary = 2.5, trail = 1.5, avenue = 3.5, lane = 2.5},
	JUNCTION_GAP = 64, END_GAP = 24, RING_GAP = 160, JOIN_MAXCOS = 0.8,
	JOIN_FLAT_REACH = 8, JOIN_OFF = 2.5, EDGE_EVERY = 2,
	START_GATE = 64, START_STRETCH = 32,
	WIGGLE = 14, WIGGLE_PERIOD = 220, WIGGLE_TAPER = 64, WIGGLE_RMIN = 30,
	WIGGLE_S0 = 0.12, WIGGLE_S1 = 0.3, WIGGLE_ENV = 40, SMOOTH = 5, SMOOTH_MAXTURN = 0.8,
	LOOPS = 4, LOOP_RATIO = 1.3, K_ONROAD = 3, LOOP_END_FREE = 80, LOOP_REACH = 1100,
	TRAIL_BUDGET = nil,           -- every trail candidate is built (D67, D68)
	-- profile DP
	CMAX = 4, JUNCTION_FLAT = 4, END_FLAT = 6,
	C_CUT = 1.0, C_FILL = 1.3, EMB = 2, C_DECK0 = 3, C_DECK = 1.2,
	CUT_DEEP = 6, C_DEEP = 1.5,
	K_SCAR = 0.5, SCAR_SMAX = 0.8, -- half gallery over deep uphill cut (D67)
	CLEAR = 2, FORD_DEPTH = 2, C_BRIDGE = 4, C_FORD = 2, C_WET_SIDE = 12,
	C_STEP = 0.05,
	DP_BELOW = 10, DP_ABOVE = 8, Q = 16,
	DECK_GAP = 4, DECK_MIN = 4,
	-- deck audit (D67): gallery tolerance, short valley crossing, deep cut run
	GALLERY_TOL = 1, CROSS_MAX = 32, DEEP_RUN = 6,
	-- sampler / raster
	BUCKET = 32, SIDE_MAX = 24, EMB_TOE = 3, EMB_REACH = 6, CUT_SLOPE = 1,
	CUT_SOIL = 6, CUT_ROCK = 2, EMB_SLOPE = 1,
	WALL_MIN = 5, WALL_H = 3, PILLAR_EVERY = 5,
	-- ground points a bridge run lands on at each bank (D74)
	BRIDGE_LAND = 2,
	-- road-corridor claim exclusion beyond the road edge (nodes)
	EXCLUDE_PAD = 2,
	-- a road ends CORE_GAP nodes (square distance) outside a village's or
	-- POI's core, at the core's fitted height; a join is taken only where
	-- that height can be reached: |dy| <= PIN_GRADE * (distance - PIN_SLACK)
	CORE_GAP = 0.5, PIN_GRADE = 0.35, PIN_SLACK = 24, PIN_TRIES = 4,
}

local function new_module(P)
	local M = {P = P}
	P.variant = {G0 = P.G0, K_G = P.K_G}
	local floor, sqrt, abs, min, max = math.floor, math.sqrt, math.abs, math.min, math.max
	local atan2, pi, cos, sin = math.atan2, math.pi, math.cos, math.sin
	local INF = math.huge
	local LAT = 128        -- centreline positions live on a 1/LAT-node lattice

	local function smoothstep(a, b, x)
		local t = (x - a) / (b - a)
		if t <= 0 then return 0 elseif t >= 1 then return 1 end
		return t * t * (3 - 2 * t)
	end

	---------------------------------------------------------------------------
	-- Binary heap keyed by number.
	---------------------------------------------------------------------------
	local function heap_new() return {v = {}, k = {}, n = 0} end
	local function heap_push(h, value, key)
		local n = h.n + 1
		h.n = n
		local hv, hk = h.v, h.k
		while n > 1 do
			local p = floor(n / 2)
			if hk[p] <= key then break end
			hv[n], hk[n] = hv[p], hk[p]
			n = p
		end
		hv[n], hk[n] = value, key
	end
	local function heap_pop(h)
		local n = h.n
		if n == 0 then return nil end
		local hv, hk = h.v, h.k
		local top, topk = hv[1], hk[1]
		local lv, lk = hv[n], hk[n]
		hv[n], hk[n] = nil, nil
		n = n - 1
		h.n = n
		local i = 1
		while true do
			local c = i * 2
			if c > n then break end
			if c < n and hk[c + 1] < hk[c] then c = c + 1 end
			if hk[c] >= lk then break end
			hv[i], hk[i] = hv[c], hk[c]
			i = c
		end
		if n > 0 then hv[i], hk[i] = lv, lk end
		return top, topk
	end

	---------------------------------------------------------------------------
	-- 16 headings on the coarse grid, ordered by angle.
	---------------------------------------------------------------------------
	local DIRS = {}
	do
		local raw = {{1, 0}, {2, 1}, {1, 1}, {1, 2}, {0, 1}, {-1, 2}, {-1, 1}, {-2, 1},
			{-1, 0}, {-2, -1}, {-1, -1}, {-1, -2}, {0, -1}, {1, -2}, {1, -1}, {2, -1}}
		for i, d in ipairs(raw) do
			local len = sqrt(d[1] * d[1] + d[2] * d[2])
			local mids = {}
			-- intermediate cells a knight move passes through
			if abs(d[1]) == 2 then
				mids = {{d[1] / 2, 0}, {d[1] / 2, d[2]}}
			elseif abs(d[2]) == 2 then
				mids = {{0, d[2] / 2}, {d[1], d[2] / 2}}
			end
			DIRS[i] = {dx = d[1], dz = d[2], len = len, ux = d[1] / len, uz = d[2] / len,
				ang = atan2(d[2], d[1]), mids = mids,
				knight = mids[1] ~= nil,
				m1x = mids[1] and mids[1][1] or 0, m1z = mids[1] and mids[1][2] or 0,
				m2x = mids[2] and mids[2][1] or 0, m2z = mids[2] and mids[2][2] or 0,
				diag = abs(d[1]) == 1 and abs(d[2]) == 1}
		end
	end
	local ND = #DIRS
	local TURN = {}
	for a = 1, ND do
		TURN[a] = {}
		for b = 1, ND do
			local d = abs(DIRS[a].ang - DIRS[b].ang)
			if d > pi then d = 2 * pi - d end
			TURN[a][b] = d * 180 / pi
		end
	end
	local function turn_cost(deg)
		if deg < 1 then return 0 end
		if deg > P.TURN_MAX_DEG + 0.5 then return INF end
		local c = P.TURN_K * (deg / 45) ^ 2
		if deg > 91 then c = c + P.SHARP_TURN end
		return c
	end
	local TURNC = {}
	for a = 1, ND do
		TURNC[a] = {}
		for b = 1, ND do TURNC[a][b] = turn_cost(TURN[a][b]) end
	end

	---------------------------------------------------------------------------
	-- Polyline helpers.
	---------------------------------------------------------------------------
	local function chaikin(pts, iters)
		for _ = 1, iters do
			local out = {pts[1]}
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				out[#out + 1] = {0.75 * a[1] + 0.25 * b[1], 0.75 * a[2] + 0.25 * b[2]}
				out[#out + 1] = {0.25 * a[1] + 0.75 * b[1], 0.25 * a[2] + 0.75 * b[2]}
			end
			out[#out + 1] = pts[#pts]
			pts = out
		end
		return pts
	end
	local function resample(pts, step)
		local out = {{pts[1][1], pts[1][2]}}
		local carry = 0
		for i = 1, #pts - 1 do
			local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
			local L = sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local s = step - carry
			while s <= L do
				out[#out + 1] = {ax + (bx - ax) * s / L, az + (bz - az) * s / L}
				s = s + step
			end
			carry = L - (s - step)
		end
		local last = pts[#pts]
		local lo = out[#out]
		if (last[1] - lo[1]) ^ 2 + (last[2] - lo[2]) ^ 2 > 1e-12 then
			out[#out + 1] = {last[1], last[2]}
		else
			out[#out] = {last[1], last[2]}
		end
		return out
	end
	local function polylen(pts)
		local L = 0
		for i = 2, #pts do L = L + sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
		return L
	end
	-- signed turning angle at every point over a +-w window (radians) and the
	-- local curvature radius
	local function curvature(X, Z, w)
		local n = #X
		local R, TH = {}, {}
		for i = 1, n do
			local a, b = max(1, i - w), min(n, i + w)
			if b - a < 2 or i == a or i == b then
				R[i], TH[i] = INF, 0
			else
				local h1 = atan2(Z[i] - Z[a], X[i] - X[a])
				local h2 = atan2(Z[b] - Z[i], X[b] - X[i])
				local d = h2 - h1
				while d > pi do d = d - 2 * pi end
				while d < -pi do d = d + 2 * pi end
				local L = 0.5 * ((i - a) + (b - i))
				TH[i] = d
				R[i] = abs(d) > 1e-6 and L / abs(d) or INF
			end
		end
		return R, TH
	end

	---------------------------------------------------------------------------
	-- Build.
	---------------------------------------------------------------------------
	function M.build(seed, opts)
		local T0 = os.clock()
		local stats = {}
		local grid = assert(opts.grid, "coarse grid missing")
		local nx, nz, C, GX0, GZ0 = grid.nx, grid.nz, grid.cell, grid.x0, grid.z0
		local H, LAND = grid.height, grid.land
		local N = nx * nz
		local function cxz(k) return GX0 + (k % nx) * C, GZ0 + floor(k / nx) * C end
		local function cell_of(x, z)
			local ix, iz = floor((x - GX0) / C + 0.5), floor((z - GZ0) / C + 0.5)
			if ix < 0 or iz < 0 or ix >= nx or iz >= nz then return nil end
			return iz * nx + ix
		end
		local noise = opts.simplex(seed, "road_cost")
		local wig = opts.simplex(seed, "road_wiggle")

		-- compact land index (states only exist on land cells)
		local LI, KOF, NL = {}, {}, 0
		for k = 0, N - 1 do
			if LAND[k] then NL = NL + 1; LI[k] = NL; KOF[NL] = k end
		end
		-- per-cell static cost terms
		local blocked, NOISE, WATERC, GX, GZ = {}, {}, {}, {}, {}
		for li = 1, NL do
			local k = KOF[li]
			local x, z = cxz(k)
			NOISE[li] = noise(x / P.NOISE_PERIOD, z / P.NOISE_PERIOD)
			local ix, iz = k % nx, floor(k / nx)
			local function hh(dx, dz)
				local jx, jz = ix + dx, iz + dz
				if jx < 0 or jz < 0 or jx >= nx or jz >= nz then return H[k] end
				local j = jz * nx + jx
				return LAND[j] and H[j] or H[k]
			end
			GX[li] = (hh(1, 0) - hh(-1, 0)) / (2 * C)
			GZ[li] = (hh(0, 1) - hh(0, -1)) / (2 * C)
			WATERC[li] = 0
		end
		-- rivers: every cell within w/2 + pad of a wet centreline
		for _, pl in ipairs(opts.rivers or {}) do
			local pts = pl.points
			for i = 1, #pts do
				local p = pts[i]
				local reach = p.w / 2 + P.RIVER_PAD
				local c = P.C_RIVER + P.C_RIVER_W * p.w
				for z = p.z - reach, p.z + reach + C, C do
					for x = p.x - reach, p.x + reach + C, C do
						local k = cell_of(x, z)
						if k and LI[k] then
							local cx, cz = cxz(k)
							if (cx - p.x) ^ 2 + (cz - p.z) ^ 2 <= reach * reach then
								local li = LI[k]
								if WATERC[li] < c then WATERC[li] = c end
							end
						end
					end
				end
			end
		end
		for k, id in pairs(opts.lake_mask or {}) do
			local li = LI[k]
			if li and id then WATERC[li] = max(WATERC[li], P.C_LAKE) end
		end
		-- reserved areas and POI cores
		local owner = {}          -- li -> reservation id (blocked unless it is the target)
		local ring = {}           -- li -> capital id for cells on the reserved-area edge
		for _, b in ipairs(opts.reserved or {}) do
			local half = b.half
			for z = b.z - half - 2 * C, b.z + half + 2 * C, C do
				for x = b.x - half - 2 * C, b.x + half + 2 * C, C do
					local k = cell_of(x, z)
					if k and LI[k] then
						local cx, cz = cxz(k)
						local m = max(abs(cx - b.x), abs(cz - b.z))
						if b.round then m = sqrt((cx - b.x) ^ 2 + (cz - b.z) ^ 2) end
						if m <= half then
							owner[LI[k]] = b.id
						elseif m <= half + C and b.ring then
							ring[LI[k]] = b.id
						end
					end
				end
			end
		end
		for li = 1, NL do if owner[li] then blocked[li] = true end end
		-- Kit hooks (capital planner): caller-given blocked cells and a static
		-- extra cost per cell (e.g. a civic lake that is no river polyline).
		if opts.blocked or opts.cell_cost then
			for li = 1, NL do
				local x, z = cxz(KOF[li])
				if opts.blocked and opts.blocked(x, z) then blocked[li] = true end
				if opts.cell_cost then WATERC[li] = WATERC[li] + (opts.cell_cost(x, z) or 0) end
			end
		end
		stats.t_grid = os.clock() - T0

		-- network state
		local roads = {}          -- built roads (geometry filled later)
		local netcell = {}        -- li -> {road = id, idx = coarse index} joinable road cells
		local near_road = {}      -- li -> true: within one cell of a road (parallel penalty)
		local ring_used = {}      -- capital id -> list of {x, z} road ends on its edge

		local variant = P.variant
		local ndist_dirty = true
		local on_road_penalty = nil   -- set while routing loops
		local road_check = nil        -- set while routing loops
		local bad_join, pin_check = {}, false  -- core-pin join checks (routed)
		local GUIDE = nil   -- kit: li -> extra cost per node (a planner's corridor preference)
		-- move cost from li (heading da) to lj (heading d) along DIRS[d]:
		-- the static part (grade, noise, cross slope, water; li follows from
		-- lj and d) is memoised per (lj, d) and road class, the network
		-- terms are added on every call (same additions, same order)
		local SCOST = {[false] = {}, [true] = {}}
		local function static_cost(li, lj, d, trail)
			local D = DIRS[d]
			local L = C * D.len
			local ka, kb = KOF[li], KOF[lj]
			local g = abs(H[kb] - H[ka]) / L
			local c = L * (1 + P.NOISE_AMP * NOISE[lj])
			local gmax = trail and P.TRAIL_GMAX or P.GMAX
			if g > gmax then c = c + L * P.K_STEEP * (g - gmax) / gmax end
			-- every grade costs a little: roads bend around hills
			c = c + L * P.K_GENTLE * min(g, 0.25) / 0.25
			local g0 = variant.G0
			if g0 and g > g0 then
				c = c + L * variant.K_G * ((g - g0) / (gmax - g0)) ^ 2
			end
			-- cross slope at the target cell: a bench needs cut and fill
			local cross = abs(GX[lj] * D.uz - GZ[lj] * D.ux)
			if cross > P.SIDE0 then c = c + L * P.K_SIDE * (cross - P.SIDE0) ^ 2 end
			c = c + WATERC[lj]
			return c
		end
		local function move_cost(li, lj, d, trail)
			local memo = SCOST[trail == true]
			local key = (lj - 1) * ND + d
			local c = memo[key]
			if not c then
				c = static_cost(li, lj, d, trail)
				memo[key] = c
			end
			if GUIDE then
				local gv = GUIDE[lj]
				if gv then c = c + C * DIRS[d].len * gv end
			end
			if near_road[lj] and not netcell[lj] then c = c + C * DIRS[d].len * P.K_PARALLEL end
			if on_road_penalty and netcell[lj] then c = c + C * DIRS[d].len * on_road_penalty end
			return c
		end

		-- scratch state arrays (reused; generation-stamped)
		local NS = NL * ND
		local dist, prev, gen, closed = {}, {}, {}, {}
		local generation = 0

		-- search(sources, target, heuristic) -> list of li, end info
		-- sources: {{li, d or nil, cost}}; target(li, d) -> info or nil
		local nsearch, nexpand, last_expand = 0, 0, 0
		local RMARK, rstamp = {}, 0   -- li -> stamp: a recent cell of the state
		local function search(sources, target, heur, budget, trail, forbid_owner, allow)
			generation = generation + 1
			nsearch = nsearch + 1
			last_expand = 0
			local G = generation
			local heap = heap_new()
			for _, s in ipairs(sources) do
				local ds = s[2] and {s[2]} or nil
				if not ds then ds = {} for d = 1, ND do ds[d] = d end end
				for _, d in ipairs(ds) do
					local st = (s[1] - 1) * ND + d
					if gen[st] ~= G or dist[st] > s[3] then
						gen[st], dist[st], prev[st], closed[st] = G, s[3], false, false
						heap_push(heap, st, s[3] + (heur and heur(s[1]) or 0))
					end
				end
			end
			while true do
				local st, key = heap_pop(heap)
				if not st then return nil end
				if not closed[st] then
					closed[st] = true
					local ds = dist[st]
					if budget and ds > budget then return nil end
					local li = floor((st - 1) / ND) + 1
					local da = st - (li - 1) * ND
					local info = target(li, da, ds)
					if info then
						local path, dirs = {}, {}
						local s = st
						while s do
							local l = floor((s - 1) / ND) + 1
							table.insert(path, 1, l)
							table.insert(dirs, 1, s - (l - 1) * ND)
							s = prev[s]
						end
						return path, info, ds, dirs
					end
					nexpand = nexpand + 1
					last_expand = last_expand + 1
					local k = KOF[li]
					local ix, iz = k % nx, floor(k / nx)
					local TC = TURNC[da]
					-- the last cells of this state's path (spiral check)
					local nrecent = 0
					rstamp = rstamp + 1
					do
						local s2 = prev[st]
						while s2 and nrecent < P.LOOP_LOOKBACK do
							nrecent = nrecent + 1
							RMARK[floor((s2 - 1) / ND) + 1] = rstamp
							s2 = prev[s2]
						end
					end
					for d = 1, ND do
						local tc = TC[d]
						if tc < INF then
							local D = DIRS[d]
							local jx, jz = ix + D.dx, iz + D.dz
							if jx >= 0 and jz >= 0 and jx < nx and jz < nz then
								local lj = LI[jz * nx + jx]
								if lj and (not blocked[lj] or (allow and allow[lj])) then
									local ok, extra = true, 0
									local m1, m2
									if D.knight then
										m1 = LI[(iz + D.m1z) * nx + ix + D.m1x]
										if not m1 or (blocked[m1] and not (allow and allow[m1])) or netcell[m1] then
											ok = false
										else
											extra = extra + 0.5 * WATERC[m1]
											m2 = LI[(iz + D.m2z) * nx + ix + D.m2x]
											if not m2 or (blocked[m2] and not (allow and allow[m2])) or netcell[m2] then
												ok = false
											else
												extra = extra + 0.5 * WATERC[m2]
											end
										end
									end
									-- never cross a road without joining it
									if ok and netcell[lj] and not target(lj, d) then ok = false end
									if ok and D.diag then
										local l1 = LI[iz * nx + ix + D.dx]
										local l2 = LI[(iz + D.dz) * nx + ix]
										if l1 and l2 and netcell[l1] and netcell[l2] then ok = false end
									end
									-- after a sharp turn the path must not come back onto
									-- (or across) its own recent cells: no spirals; a
									-- hairpin's legs stay one cell apart (D45)
									if ok and nrecent > 0 and (TURN[da][d] >= 60 or D.knight) then
										if RMARK[lj] == rstamp or (m1 and RMARK[m1] == rstamp) or
												(m2 and RMARK[m2] == rstamp) then
											ok = false
										end
									end
									if ok then
										local c = ds + tc + extra + move_cost(li, lj, d, trail)
										-- a hairpin wants a calm platform
										if tc >= P.SHARP_TURN then
											local sl = sqrt(GX[li] ^ 2 + GZ[li] ^ 2)
											c = c + P.K_PLATFORM * sl * C
										end
										local sj = (lj - 1) * ND + d
										if gen[sj] ~= G then
											gen[sj], dist[sj], prev[sj], closed[sj] = G, INF, false, false
										end
										if c < dist[sj] then
											dist[sj], prev[sj] = c, st
											heap_push(heap, sj, c + (heur and heur(lj) or 0))
										end
									end
								end
							end
						end
					end
				end
			end
		end

		local function li_xz(li) return cxz(KOF[li]) end
		-- coarse slope magnitude, bilinear over the four surrounding cells
		local function grad_at(x, z)
			local fx, fz = (x - GX0) / C, (z - GZ0) / C
			local ix, iz = floor(fx), floor(fz)
			local ux, uz = fx - ix, fz - iz
			local gx, gz, wsum = 0, 0, 0
			for dz = 0, 1 do
				for dx = 0, 1 do
					local jx, jz = ix + dx, iz + dz
					if jx >= 0 and jz >= 0 and jx < nx and jz < nz then
						local li = LI[jz * nx + jx]
						if li then
							local wgt = (dx == 1 and ux or 1 - ux) * (dz == 1 and uz or 1 - uz)
							gx, gz, wsum = gx + wgt * GX[li], gz + wgt * GZ[li], wsum + wgt
						end
					end
				end
			end
			if wsum <= 0 then return 0 end
			return sqrt(gx * gx + gz * gz) / wsum
		end
		local minmult = 1 - P.NOISE_AMP

		-----------------------------------------------------------------------
		-- Profiles: a DP over levels in 1/Q node along the 1-node centreline.
		-- The road height is a continuous piecewise-linear profile Rc(s); a
		-- column takes round-to-half(Rc(s)) at its projection s. Neighbouring
		-- surface columns are at most f apart in s (f = R / (R - e) on the
		-- inner edge of a curve of radius R), so a slope bound of 1/(2 f)
		-- keeps every neighbour pair within 1/2 node after rounding: 1:2 on
		-- straights, a little gentler in curves, flat in hairpins and at
		-- junction mouths.
		-----------------------------------------------------------------------
		local Q = P.Q
		-- how far a T junction's mouth reaches along the parent (Fp) and
		-- along the child (Fc), from the angle between the two roads
		-- (`side == "a"`: a kit street that starts on its parent, a_parent)
		local function junction_extent(child, side)
			local parent = roads[side == "a" and child.a_parent or child.parent]
			local n, idx = #child.X, side == "a" and child.a_parent_idx or child.parent_idx
			local a = max(1, n - 8)
			local cx, cz = child.X[n] - child.X[a], child.Z[n] - child.Z[a]
			if side == "a" then
				local b = min(n, 9)
				cx, cz = child.X[b] - child.X[1], child.Z[b] - child.Z[1]
			end
			local i0, i1 = max(1, idx - 4), min(#parent.X, idx + 4)
			local px, pz = parent.X[i1] - parent.X[i0], parent.Z[i1] - parent.Z[i0]
			local lc, lp = sqrt(cx * cx + cz * cz), sqrt(px * px + pz * pz)
			local sn, cs = 1, 0
			if lc > 0 and lp > 0 then
				sn = abs(cx * pz - cz * px) / (lc * lp)
				cs = abs(cx * px + cz * pz) / (lc * lp)
			end
			sn = max(sn, 0.3)
			local Fp = math.ceil(child.hw / sn + parent.hw * cs / sn) + P.JUNCTION_FLAT
			local Fc = math.ceil(parent.hw / sn + child.hw * cs / sn) + P.JUNCTION_FLAT
			return Fp, Fc
		end
		local function solve(road)
			local X, Z, n, hw = road.X, road.Z, #road.X, road.hw
			local T, WY = road.T, road.WY
			local R = curvature(X, Z, 3)
			local dmax = {}       -- per step i-1 -> i, in 1/Q node
			local fsd = {}        -- d / f per step (0 where flat)
			-- kink angle at every vertex (the lattice adds a little jitter):
			-- a column at offset e projects with a jump of about e * angle
			local kink = {}
			for i = 1, n do
				if i == 1 or i == n then kink[i] = 0 else
					local h1 = atan2(Z[i] - Z[i - 1], X[i] - X[i - 1])
					local h2 = atan2(Z[i + 1] - Z[i], X[i + 1] - X[i])
					local dd = h2 - h1
					while dd > pi do dd = dd - 2 * pi end
					while dd < -pi do dd = dd + 2 * pi end
					kink[i] = abs(dd)
				end
			end
			for i = 1, n do
				local rr = INF
				for j = max(1, i - 2), min(n, i + 2) do rr = min(rr, R[j]) end
				local e = hw + 0.5
				local f
				if rr == INF then f = 1 elseif rr <= e + 0.5 then f = INF else f = max(1, rr / (rr - e)) end
				local kj = max(kink[max(1, i - 1)], kink[i])
				if f < INF then f = max(f, 1 + e * kj * 1.05) end
				-- the step i-1 -> i spans d nodes of arc (the 1/128 lattice
				-- makes it 0.9-1.1): the bound is on the slope per node
				local d = i > 1 and sqrt((X[i] - X[i - 1]) ^ 2 + (Z[i] - Z[i - 1]) ^ 2) or 1
				dmax[i] = f == INF and 0 or floor(Q * 0.5 * d / f + 1e-9)
				fsd[i] = f == INF and 0 or d / f
			end
			-- flat zones: junction mouths on this road, this road's mouth on
			-- its parent, road ends
			for _, j in ipairs(road.junctions) do
				local Fp = junction_extent(roads[j.road], j.side)
				for i = max(1, j.idx - Fp), min(n, j.idx + Fp) do dmax[i] = 0 end
			end
			local pin_end
			if road.parent then
				local parent = roads[road.parent]
				local _, F = junction_extent(road)
				for i = max(1, n - F), n do dmax[i] = 0 end
				pin_end = parent.RQ and parent.RQ[road.parent_idx] or nil
				road.solved_parent_pin = pin_end or false
			end
			for i = 1, min(n, P.END_FLAT) do dmax[i] = 0 end
			if not road.parent then
				for i = max(1, n - P.END_FLAT), n do dmax[i] = 0 end
			end
			local pin_start
			if road.a_kind == "start" then
				-- the gate stretch starts on the start pad's ground, level
				pin_start = floor((road.a_y or T[1][1]) * Q + 0.5)
				for i = 1, min(n, P.START_STRETCH) do dmax[i] = 0 end
			end
			local core_pins = not road.no_core_pin
			if core_pins and road.a_core and road.a_y then pin_start = floor(road.a_y * Q + 0.5) end
			if core_pins and road.b_core and road.b_y and not road.parent then
				pin_end = floor(road.b_y * Q + 0.5)
			end
			-- a point-to-point road may pin its ends (a gate's ground)
			if road.pin_a then pin_start = floor(road.pin_a * Q + 0.5) end
			if road.pin_b and not road.parent then pin_end = floor(road.pin_b * Q + 0.5) end
			-- Kit streets (capital planner): a T junction at the first point
			-- (flat mouth, pinned to the parent's level), and flat end stretches
			-- of a given length with or without a pin (a gate passage, a lane
			-- ending in a square).
			if road.a_parent then
				local parent = roads[road.a_parent]
				local _, F = junction_extent(road, "a")
				for i = 1, min(n, F + 1) do dmax[i] = 0 end
				pin_start = parent.RQ and parent.RQ[road.a_parent_idx] or pin_start
			end
			if road.flat_a then
				for i = 1, min(n, road.flat_a) do dmax[i] = 0 end
			end
			if road.flat_b and not road.parent then
				for i = max(1, n - road.flat_b), n do dmax[i] = 0 end
			end
			road.dmax = dmax
			road.solved_junctions = #road.junctions
			local C_CUT, C_FILL, EMB = P.C_CUT, P.C_FILL, P.EMB
			local function scost(r, t, wy, centre, cm)
				if wy and wy > t then
					if r >= wy + P.CLEAR then return P.C_BRIDGE end
					if wy - t <= P.FORD_DEPTH and r <= wy and r >= wy - 1 then
						return P.C_FORD + C_FILL * max(0, r - t)
					end
					return centre and INF or P.C_WET_SIDE
				end
				local d = r - t
				if d >= 0 then
					if d <= EMB then return C_FILL * d end
					return C_FILL * EMB + P.C_DECK0 + P.C_DECK * (d - EMB)
				end
				local c = -d
				if c > P.CUT_DEEP then return cm * (C_CUT * c + P.C_DEEP * (c - P.CUT_DEEP)) end
				return cm * C_CUT * c
			end
			-- cut multiplier per point and edge: the cut slope behind the uphill
			-- edge climbs the side slope, so its scar grows like 1 / (1 - slope);
			-- on steep side slopes a half gallery (shallow uphill cut, downhill
			-- half on pillars) then beats a deep uphill cut (D67)
			local CM2, CM3 = {}, {}
			for i = 1, n do
				local t = T[i]
				local sl = min(P.SCAR_SMAX, abs(t[2] - t[3]) / (2 * hw))
				local m = 1 + P.K_SCAR * sl / (1 - sl)
				if t[2] > t[3] then CM2[i], CM3[i] = m, 1 else CM2[i], CM3[i] = 1, m end
			end
			-- windows (levels in 1/Q), made consistent with the step bound so
			-- every state has a successor and the pins are reachable
			local lo, hi = {}, {}
			for i = 1, n do
				local t = T[i]
				local tl, th = min(t[1], t[2], t[3]), max(t[1], t[2], t[3])
				for s = 1, 3 do
					local wy = WY[i][s]
					if wy and wy > th then th = wy end
				end
				lo[i] = floor(Q * (tl - P.DP_BELOW))
				hi[i] = floor(Q * (th + P.DP_ABOVE)) + 1
			end
			if pin_start then lo[1], hi[1] = pin_start, pin_start end
			if pin_end then lo[n], hi[n] = pin_end, pin_end end
			for i = 2, n do
				local a = dmax[i]
				if not (pin_end and i == n) then
					if hi[i] < hi[i - 1] - a then hi[i] = hi[i - 1] - a end
					if lo[i] > lo[i - 1] + a then lo[i] = lo[i - 1] + a end
				end
			end
			for i = n, 2, -1 do
				local a = dmax[i]
				if not (pin_start and i - 1 == 1) then
					if hi[i - 1] < hi[i] - a then hi[i - 1] = hi[i] - a end
					if lo[i - 1] > lo[i] + a then lo[i - 1] = lo[i] + a end
				end
			end
			local w = {0.5, 0.25, 0.25}
			local back = {}
			local prev = {}
			do
				local t, wy = T[1], WY[1]
				for v = lo[1], hi[1] do
					local r = v / Q
					local pc = 0
					local cm = {1, CM2[1], CM3[1]}
					for s = 1, 3 do pc = pc + w[s] * scost(r, t[s], wy[s] or nil, s == 1, cm[s]) end
					prev[v - lo[1] + 1] = pc
				end
			end
			local CSTEP = P.C_STEP
			-- sliding-window minimum of prev over [v - a, v + a] for every v,
			-- the lowest level on ties (deterministic): blocks of 2a + 1
			-- levels with a forward (prefix) and a backward (suffix) minimum,
			-- so a window is one or two lookups (no inner loops, which keeps
			-- the loop compiled under LuaJIT)
			local mv, ma = {}, {}
			local prev_v, prev_i, suf_v, suf_i = {}, {}, {}, {}
			local function window_min(prevv, plo, phi, vlo, vhi, a)
				local m, B = phi - plo + 1, 2 * a + 1
				-- prefix minima within each block (strict <: keeps the lowest index)
				local bv, bi = INF, 0
				for j = 1, m do
					local x = prevv[j]
					if (j - 1) % B == 0 or x < bv then bv, bi = x, j end
					prev_v[j], prev_i[j] = bv, bi
				end
				-- suffix minima within each block (<=: the lowest index on ties)
				for j = m, 1, -1 do
					local x = prevv[j]
					if j % B == 0 or j == m or x <= bv then bv, bi = x, j end
					suf_v[j], suf_i[j] = bv, bi
				end
				for v = vlo, vhi do
					local L, R = v - a - plo + 1, v + a - plo + 1
					if L < 1 then L = 1 end
					if R > m then R = m end
					local k = v - vlo + 1
					if L > R then
						mv[k], ma[k] = INF, false
					else
						local blockL, blockR = floor((L - 1) / B), floor((R - 1) / B)
						local val, idx
						if blockL ~= blockR then
							val, idx = suf_v[L], suf_i[L]
							if prev_v[R] < val then val, idx = prev_v[R], prev_i[R] end
						elseif (L - 1) % B == 0 then
							val, idx = prev_v[R], prev_i[R]
						elseif R % B == 0 or R == m then
							val, idx = suf_v[L], suf_i[L]
						else
							-- a window clipped on both sides inside one block
							val, idx = prevv[L], L
							for j = L + 1, R do
								if prevv[j] < val then val, idx = prevv[j], j end
							end
						end
						mv[k], ma[k] = val, idx + plo - 1
					end
				end
			end
			-- the level costs of two steps alternate between two buffers
			local cur = {}
			local cmi = {1, 1, 1}
			for i = 2, n do
				local plo, phi = lo[i - 1], hi[i - 1]
				local nc, bk = cur, {}
				cur = prev
				local t, wy = T[i], WY[i]
				local a = dmax[i]
				local vlo, vhi = lo[i], hi[i]
				window_min(prev, plo, phi, vlo, vhi, a)
				local t1, t2, t3 = t[1], t[2], t[3]
				local w1, w2, w3 = wy[1], wy[2], wy[3]
				local m2, m3 = CM2[i], CM3[i]
				cmi[2], cmi[3] = m2, m3
				local dry = not (w1 and w1 > t1) and not (w2 and w2 > t2) and not (w3 and w3 > t3)
				for v = vlo, vhi do
					local r = v / Q
					local pc
					if dry then
						-- inlined dry cost (the common case)
						pc = 0
						local d = r - t1
						if d >= 0 then
							pc = pc + 0.5 * (d <= EMB and C_FILL * d or C_FILL * EMB + P.C_DECK0 + P.C_DECK * (d - EMB))
						else
							pc = pc + 0.5 * (-d > P.CUT_DEEP and -C_CUT * d + P.C_DEEP * (-d - P.CUT_DEEP) or -C_CUT * d)
						end
						d = r - t2
						if d >= 0 then
							pc = pc + 0.25 * (d <= EMB and C_FILL * d or C_FILL * EMB + P.C_DECK0 + P.C_DECK * (d - EMB))
						else
							pc = pc + 0.25 * m2 * (-d > P.CUT_DEEP and -C_CUT * d + P.C_DEEP * (-d - P.CUT_DEEP) or -C_CUT * d)
						end
						d = r - t3
						if d >= 0 then
							pc = pc + 0.25 * (d <= EMB and C_FILL * d or C_FILL * EMB + P.C_DECK0 + P.C_DECK * (d - EMB))
						else
							pc = pc + 0.25 * m3 * (-d > P.CUT_DEEP and -C_CUT * d + P.C_DEEP * (-d - P.CUT_DEEP) or -C_CUT * d)
						end
					else
						pc = 0
						for s = 1, 3 do pc = pc + w[s] * scost(r, t[s], wy[s] or nil, s == 1, cmi[s]) end
					end
					local best, arg = INF, nil
					if pc < INF then
						if v >= plo and v <= phi then best, arg = prev[v - plo + 1], v end
						local x = mv[v - vlo + 1] + CSTEP
						if x < best then best, arg = x, ma[v - vlo + 1] end
					end
					nc[v - vlo + 1] = best + pc
					bk[v - vlo + 1] = arg or false
				end
				back[i] = bk
				prev = nc
				if not road.dead_at then
					local any = false
					for q = 1, vhi - vlo + 1 do if nc[q] < INF then any = true break end end
					if not any then
						road.dead_at = i
					end
				end
			end
			local last, bestv = INF, nil
			for v = lo[n], hi[n] do
				local val = prev[v - lo[n] + 1]
				if val < last then last, bestv = val, v end
			end
			local RQ, Rv = {}, {}
			if not bestv and core_pins and (road.a_core or road.b_core) then
				-- the core pins do not fit (a core far above or below its
				-- approach within the road's length): free those ends
				road.no_core_pin = true
				stats.core_pin_dropped = (stats.core_pin_dropped or 0) + 1
				return solve(road)
			end
			if not bestv then
				-- no profile within the windows (should not happen): follow the
				-- ground within the step bound, so the road stays walkable
				stats.infeasible = (stats.infeasible or 0) + 1
				stats.infeasible_ids = (stats.infeasible_ids or "") .. " " ..
					tostring(road.id) .. ":" .. road.kind
				for i = 1, n do
					local want = floor(T[i][1] * Q + 0.5)
					if i > 1 then
						local a = dmax[i]
						if want > RQ[i - 1] + a then want = RQ[i - 1] + a end
						if want < RQ[i - 1] - a then want = RQ[i - 1] - a end
					end
					RQ[i], Rv[i] = want, want / Q
				end
				road.RQ, road.R, road.cost = RQ, Rv, INF
				return
			end
			local v = bestv
			for i = n, 1, -1 do
				RQ[i], Rv[i] = v, v / Q
				if i > 1 then v = back[i][v - lo[i] + 1] end
			end
			road.RQ, road.R, road.cost = RQ, Rv, last
		end
		-----------------------------------------------------------------------
		-- Per-point classes (payload): bridge, ford, deck (runs), else ground.
		-----------------------------------------------------------------------
		local function classify(road)
			local n, Rv, T, WY = #road.X, road.R, road.T, road.WY
			local cls = {}
			for i = 1, n do
				local r, wy = Rv[i], WY[i][1]
				if wy and wy > T[i][1] then
					cls[i] = r >= wy + P.CLEAR and "B" or "F"
				else
					local fill = 0
					for s = 1, 3 do
						local ws = WY[i][s]
						local f = r - T[i][s]
						if ws and ws > T[i][s] then f = P.EMB + 1 end
						if f > fill then fill = f end
					end
					cls[i] = fill > P.EMB and "D" or "G"
				end
			end
			-- close short gaps between decks, drop tiny deck runs
			local function runs(ch)
				local out, i = {}, 1
				while i <= n do
					if cls[i] == ch then
						local j = i
						while j < n and cls[j + 1] == ch do j = j + 1 end
						out[#out + 1] = {i, j}
						i = j + 1
					else i = i + 1 end
				end
				return out
			end
			local dr = runs("D")
			for k = 2, #dr do
				local a, b = dr[k - 1][2], dr[k][1]
				if b - a - 1 <= P.DECK_GAP then for i = a + 1, b - 1 do if cls[i] == "G" then cls[i] = "D" end end end
			end
			for _, r in ipairs(runs("D")) do
				if r[2] - r[1] + 1 < P.DECK_MIN then for i = r[1], r[2] do cls[i] = "G" end end
			end
			-- a pinned core end stands on the ground (fill, never a deck
			-- ending at the core's edge)
			local reach = P.END_FLAT + floor(road.hw) + 1
			if road.a_core and not road.no_core_pin then
				for i = 1, min(n, reach) do if cls[i] == "D" then cls[i] = "G" end end
			end
			if road.b_core and not road.no_core_pin and not road.parent then
				for i = max(1, n - reach + 1), n do if cls[i] == "D" then cls[i] = "G" end end
			end
			road.cls = cls
		end

		-----------------------------------------------------------------------
		-- Deck and cut audit (D67). A deck point is one-sided (a gallery) when
		-- its lowest sample (centre or an edge) is at most GALLERY_TOL above the
		-- ground; otherwise it floats free. Free points are allowed only inside a
		-- short valley crossing: a deck run of at most CROSS_MAX points between
		-- ground-supported points whose ground dips below both ends. Every other
		-- free point, and every point of a run cut deeper than CUT_DEEP, is a
		-- route error. Returns the number of bad points and the coarse cells
		-- around them (extended over the stretch where the profile was at its
		-- slope limit, where the lag or the cut builds up).
		-----------------------------------------------------------------------
		local function audit(road)
			local n, Rv, T, WY, cls = #road.X, road.R, road.T, road.WY, road.cls
			local free, cross, deep = {}, {}, {}
			for i = 1, n do
				if cls[i] == "D" then
					local lo = INF
					for s = 1, 3 do
						local ws = WY[i][s]
						local f = (ws and ws > T[i][s]) and INF or Rv[i] - T[i][s]
						if f < lo then lo = f end
					end
					if lo > P.GALLERY_TOL then free[i] = true end
				end
			end
			-- a free stretch between ground-supported or one-sided points is a
			-- short crossing when it is short and its ground dips below both ends
			local i = 1
			while i <= n do
				if free[i] then
					local j = i
					while j < n and free[j + 1] do j = j + 1 end
					if j - i + 1 <= P.CROSS_MAX and i > 1 and j < n then
						local low = INF
						for q = i, j do low = min(low, T[q][1]) end
						if low < min(T[i - 1][1], T[j + 1][1]) then
							for q = i, j do free[q] = nil; cross[q] = true end
						end
					end
					i = j + 1
				else
					i = i + 1
				end
			end
			-- deep cuts: the centre or the uphill edge more than CUT_DEEP below
			-- the ground over at least DEEP_RUN points
			local function is_deep(q)
				if cls[q] ~= "G" then return false end
				local c = 0
				for s = 1, 3 do
					local ws = WY[q][s]
					if not (ws and ws > T[q][s]) then c = max(c, T[q][s] - Rv[q]) end
				end
				return c > P.CUT_DEEP
			end
			i = 1
			while i <= n do
				if is_deep(i) then
					local j = i
					while j < n and is_deep(j + 1) do j = j + 1 end
					if j - i + 1 >= P.DEEP_RUN then for q = i, j do deep[q] = true end end
					i = j + 1
				else
					i = i + 1
				end
			end
			local nfree, ncross, ndeep = 0, 0, 0
			for q = 1, n do
				if free[q] then nfree = nfree + 1 end
				if cross[q] then ncross = ncross + 1 end
				if deep[q] then ndeep = ndeep + 1 end
			end
			road.free, road.cross, road.deep = free, cross, deep
			road.nfree, road.ncross, road.ndeep = nfree, ncross, ndeep
			return nfree + ndeep
		end

		-----------------------------------------------------------------------
		-- Geometry of a routed road: cell path -> smooth 1-node centreline.
		-----------------------------------------------------------------------
		local function make_geometry(ctrl, hw)
			local pts = chaikin(ctrl, 3)
			pts = resample(pts, 1)
			local X, Z = {}, {}
			for i, p in ipairs(pts) do X[i], Z[i] = p[1], p[2] end
			-- moving average (two passes), ends fixed: widens the grid corners
			-- (not across sharp turns: a hairpin keeps its legs a cell apart)
			local SM = P.SMOOTH
			if SM > 0 and #X > 2 * SM + 2 then
				local n0 = #X
				local win = {}
				for i = 1, n0 do
					local a, b = max(1, i - 8), min(n0, i + 8)
					local h1 = atan2(Z[i] - Z[a], X[i] - X[a])
					local h2 = atan2(Z[b] - Z[i], X[b] - X[i])
					local dd = abs(h2 - h1)
					if dd > pi then dd = 2 * pi - dd end
					if i == a or i == b then dd = 0 end
					win[i] = dd > P.SMOOTH_MAXTURN and 0 or SM
				end
				-- a window never grows by more than one per point
				for i = 2, n0 do win[i] = min(win[i], win[i - 1] + 1) end
				for i = n0 - 1, 1, -1 do win[i] = min(win[i], win[i + 1] + 1) end
				for _ = 1, 2 do
					local cx, cz = {[0] = 0}, {[0] = 0}
					for i = 1, n0 do cx[i], cz[i] = cx[i - 1] + X[i], cz[i - 1] + Z[i] end
					local NXs, NZs = {}, {}
					for i = 1, n0 do
						local k = min(win[i], i - 1, n0 - i)
						NXs[i] = (cx[i + k] - cx[i - k - 1]) / (2 * k + 1)
						NZs[i] = (cz[i + k] - cz[i - k - 1]) / (2 * k + 1)
					end
					X, Z = NXs, NZs
				end
				local q = {}
				for i = 1, #X do q[i] = {X[i], Z[i]} end
				q = resample(q, 1)
				X, Z = {}, {}
				for i, p in ipairs(q) do X[i], Z[i] = p[1], p[2] end
			end
			-- lateral wiggle from 2D noise, tapered at the ends and in curves
			local n = #X
			if P.WIGGLE > 0 and n > 20 then
				local R = curvature(X, Z, 6)
				local total = n - 1
				local NX, NZ = {}, {}
				for i = 1, n do
					local a, b = max(1, i - 2), min(n, i + 2)
					local tx, tz = X[b] - X[a], Z[b] - Z[a]
					local l = sqrt(tx * tx + tz * tz)
					if l < 1e-9 then l = 1 end
					NX[i], NZ[i] = -tz / l, tx / l
				end
				-- only on gentle ground: slope from the coarse grid gradient
				-- (bilinear), smoothed along the path
				local flat = {}
				for i = 1, n do
					local sl = grad_at(X[i], Z[i])
					flat[i] = 1 - smoothstep(P.WIGGLE_S0, P.WIGGLE_S1, sl)
				end
				-- amplitude envelope: gentle ground, no tight curve near,
				-- tapered at the ends, then averaged over +-ENV so the
				-- displacement never changes faster than ~A/ENV per node
				local env = {}
				for i = 1, n do
					local s = i - 1
					local taper = smoothstep(0, P.WIGGLE_TAPER, s) * smoothstep(0, P.WIGGLE_TAPER, total - s)
					local rmin = INF
					for j = max(1, i - 12), min(n, i + 12) do rmin = min(rmin, R[j]) end
					local calm = smoothstep(P.WIGGLE_RMIN, 3 * P.WIGGLE_RMIN, rmin)
					env[i] = taper * calm * flat[i]
				end
				local cum = {[0] = 0}
				for i = 1, n do cum[i] = cum[i - 1] + env[i] end
				local ENV = P.WIGGLE_ENV
				local out = {}
				for i = 1, n do
					local a0, a1 = max(0, i - ENV), min(n, i + ENV)
					local amp = P.WIGGLE * (cum[a1] - cum[a0]) / (a1 - a0)
					local o = amp * wig(X[i] / P.WIGGLE_PERIOD, Z[i] / P.WIGGLE_PERIOD)
					out[i] = {X[i] + NX[i] * o, Z[i] + NZ[i] * o}
				end
				pts = resample(out, 1)
				X, Z = {}, {}
				for i, p in ipairs(pts) do X[i], Z[i] = p[1], p[2] end
			end
			-- positions on a 1/16-node lattice: the payload carries them exactly
			for i = 1, #X do
				X[i] = floor(X[i] * LAT + 0.5) / LAT
				Z[i] = floor(Z[i] * LAT + 0.5) / LAT
			end
			return X, Z
		end

		-- terrain and water along a road: centre and both edges per point,
		-- plus a cheap profile estimate (midpoint of the cut-only and
		-- fill-only 1:2 envelopes) that tells where the road will lie near
		-- its ground: junctions only go there (D51)
		local terrain_at, water_at = opts.terrain_at, opts.water_at
		local nsample = 0
		stats.t_sample = 0
		local function sample(x, z)
			nsample = nsample + 1
			local ix, iz = floor(x + 0.5), floor(z + 0.5)
			return terrain_at(ix, iz), water_at(ix, iz)
		end
		local function sample_road(road)
			local ts = os.clock()
			local X, Z, n, hw = road.X, road.Z, #road.X, road.hw
			local T, WY = {}, {}
			for i = 1, n do
				local a, b = max(1, i - 2), min(n, i + 2)
				local tx, tz = X[b] - X[a], Z[b] - Z[a]
				local l = sqrt(tx * tx + tz * tz)
				if l < 1e-9 then l = 1 end
				local ox, oz = -tz / l * hw, tx / l * hw
				local t0, w0 = sample(X[i], Z[i])
				local t1, w1, t2, w2
				if i % P.EDGE_EVERY == 1 or i == n or P.EDGE_EVERY == 1 then
					t1, w1 = sample(X[i] + ox, Z[i] + oz)
					t2, w2 = sample(X[i] - ox, Z[i] - oz)
				end
				T[i] = {t0, t1 or false, t2 or false}
				WY[i] = {w0 or false, w1 or false, w2 or false}
			end
			-- edges between sampled points: linear in the centre offset
			if P.EDGE_EVERY > 1 then
				local last = 1
				for i = 2, n do
					if T[i][2] then
						for j = last + 1, i - 1 do
							local u = (j - last) / (i - last)
							for s = 2, 3 do
								local d0 = T[last][s] - T[last][1]
								local d1 = T[i][s] - T[i][1]
								T[j][s] = T[j][1] + floor(d0 + (d1 - d0) * u + 0.5)
								local wa, wb = WY[last][s], WY[i][s]
								WY[j][s] = (wa and wb) and ((u < 0.5) and wa or wb) or false
							end
						end
						last = i
					end
				end
			end
			road.T, road.WY = T, WY
			local U, Lo = {}, {}
			for i = 1, n do
				local t = T[i][1]
				U[i] = i > 1 and min(t, U[i - 1] + 0.5) or t
				Lo[i] = i > 1 and max(t, Lo[i - 1] - 0.5) or t
			end
			for i = n - 1, 1, -1 do
				U[i] = min(U[i], U[i + 1] + 0.5)
				Lo[i] = max(Lo[i], Lo[i + 1] - 0.5)
			end
			local off = {}
			for i = 1, n do off[i] = abs(0.5 * (U[i] + Lo[i]) - T[i][1]) end
			road.off = off
			stats.t_sample = stats.t_sample + os.clock() - ts
		end

		-- distance (nodes, chamfer 1/sqrt2, scaled down to stay a lower
		-- bound) from every cell to the nearest road cell or used capital
		-- edge: the A* heuristic of joins
		local NDIST = {}
		local function update_ndist()
			local S2 = sqrt(2) * C
			for k = 0, N - 1 do NDIST[k] = INF end
			for li, nc in pairs(netcell) do
				if nc.kind ~= "trail" then NDIST[KOF[li]] = 0 end
			end
			for li, cid in pairs(ring) do
				if ring_used[cid] then NDIST[KOF[li]] = 0 end
			end
			for iz = 0, nz - 1 do
				for ix = 0, nx - 1 do
					local k = iz * nx + ix
					local d = NDIST[k]
					if ix > 0 then d = min(d, NDIST[k - 1] + C) end
					if iz > 0 then
						d = min(d, NDIST[k - nx] + C)
						if ix > 0 then d = min(d, NDIST[k - nx - 1] + S2) end
						if ix < nx - 1 then d = min(d, NDIST[k - nx + 1] + S2) end
					end
					NDIST[k] = d
				end
			end
			for iz = nz - 1, 0, -1 do
				for ix = nx - 1, 0, -1 do
					local k = iz * nx + ix
					local d = NDIST[k]
					if ix < nx - 1 then d = min(d, NDIST[k + 1] + C) end
					if iz < nz - 1 then
						d = min(d, NDIST[k + nx] + C)
						if ix < nx - 1 then d = min(d, NDIST[k + nx + 1] + S2) end
						if ix > 0 then d = min(d, NDIST[k + nx - 1] + S2) end
					end
					NDIST[k] = d
				end
			end
		end

		-- register a road's cells as joinable network
		local function register(road)
			local X, Z = road.X, road.Z
			for i = 1, #X, 4 do
				local k = cell_of(X[i], Z[i])
				local li = k and LI[k]
				if li then
					if not netcell[li] or road.kind ~= "trail" and netcell[li].kind == "trail" then
						netcell[li] = {road = road.id, idx = i, kind = road.kind}
					end
					local ix, iz = k % nx, floor(k / nx)
					for dz = -1, 1 do for dx = -1, 1 do
						local j = LI[(iz + dz) * nx + ix + dx]
						if j then near_road[j] = true end
					end end
				end
			end
		end
		-- is arc index idx of road far enough from its junctions and ends?
		local function join_ok(road, idx)
			local gap = P.JUNCTION_GAP
			for _, j in ipairs(road.junctions) do
				if abs(j.idx - idx) < gap then return false end
			end
			if idx < gap and road.a_kind == "capital" then return false end
			if #road.X - idx < gap and road.b_kind == "capital" then return false end
			if idx < P.END_GAP or #road.X - idx < P.END_GAP then return false end
			-- the parent must lie near its ground around the junction
			for i = max(1, idx - P.JOIN_FLAT_REACH), min(#road.X, idx + P.JOIN_FLAT_REACH) do
				if road.off[i] > P.JOIN_OFF then return false end
			end
			return true
		end
		local function nearest_idx(road, x, z)
			local best, bi = INF, 1
			for i = 1, #road.X do
				local d = (road.X[i] - x) ^ 2 + (road.Z[i] - z) ^ 2
				if d < best then best, bi = d, i end
			end
			return bi, sqrt(best)
		end

		local nodes = opts.nodes
		local node_by_id = {}
		for _, nd in ipairs(nodes) do node_by_id[nd.id] = nd end

		-- source description of an endpoint: cells + fixed heading + the fixed
		-- leading control points (a start's straight gate stretch)
		local function endpoint(nd)
			if nd.kind == "capital" then
				local srcs = {}
				for li, cid in pairs(ring) do
					if cid == nd.id then srcs[#srcs + 1] = {li, nil, 0} end
				end
				table.sort(srcs, function(a, b) return a[1] < b[1] end)
				return srcs, nil
			elseif nd.kind == "start" then
				local gx, gz = nd.x, nd.z + nd.gate_dir * P.START_GATE
				local ox, oz = nd.x, nd.z + nd.gate_dir * (P.START_GATE + P.START_STRETCH)
				local k = cell_of(ox, oz)
				local d = nd.gate_dir > 0 and 5 or 13
				return {{LI[k], d, 0}}, {{gx, gz}, {ox, oz}}
			else
				local k = cell_of(nd.x, nd.z)
				return {{LI[k], nil, 0}}, nil
			end
		end
		-- cells an endpoint's own reservation may use
		local function allow_of(nd)
			local a = {}
			for li, id in pairs(owner) do if id == nd.id then a[li] = true end end
			return a
		end
		-- capital ring cells free for a new road end (not near another end)
		local function ring_free(cid, li)
			local x, z = li_xz(li)
			for _, e in ipairs(ring_used[cid] or {}) do
				if (e[1] - x) ^ 2 + (e[2] - z) ^ 2 < P.RING_GAP ^ 2 then return false end
			end
			return true
		end

		-- a routed road before it joins the network: geometry, samples, a
		-- provisional profile (the final one also sees later junctions)
		local function make_candidate(kind, a, b, path, info, dirs, lead)
			if #path < 2 then return nil end
			-- control points: cell centres; ends replaced by the exact points
			local ctrl = {}
			if lead then for _, p in ipairs(lead) do ctrl[#ctrl + 1] = {p[1], p[2]} end end
			for i, li in ipairs(path) do
				local x, z = li_xz(li)
				if not (lead and i == 1) then ctrl[#ctrl + 1] = {x, z} end
			end
			if a.kind ~= "capital" and a.kind ~= "start" and not lead then
				ctrl[1] = {a.x, a.z}
			end
			local b_kind = info.kind
			if info.kind == "road" then
				local parent = roads[info.road]
				local idx = nearest_idx(parent, li_xz(path[#path]))
				ctrl[#ctrl] = {parent.X[idx], parent.Z[idx]}
			elseif info.kind == "node" and b.kind ~= "capital" and b.kind ~= "start" then
				ctrl[#ctrl] = {b.x, b.z}
			end
			local hw = P.HALF[kind]
			local X, Z = make_geometry(ctrl, hw)
			-- snap the end back onto the parent centreline and record the junction
			local road = {id = #roads + 1, kind = kind, hw = hw, X = X, Z = Z,
				a = a.id, a_kind = a.kind, a_y = a.y, b_kind = b_kind, junctions = {}, cells = path,
				dirs = dirs}
			if info.kind == "road" then
				local parent = roads[info.road]
				local idx = nearest_idx(parent, X[#X], Z[#Z])
				X[#X], Z[#Z] = parent.X[idx], parent.Z[idx]
				-- the snapped end may sit off the 1-node spacing: resample
				-- and put the result back on the 1/128 lattice
				local q = {}
				for i = 1, #X do q[i] = {X[i], Z[i]} end
				q = resample(q, 1)
				X, Z = {}, {}
				for i, pt in ipairs(q) do
					X[i], Z[i] = floor(pt[1] * LAT + 0.5) / LAT, floor(pt[2] * LAT + 0.5) / LAT
				end
				road.parent, road.parent_idx = parent.id, idx
				road.b = "road:" .. parent.id
			else
				road.b = b and b.id or "?"
				road.b_kind = b and b.kind or b_kind
			end
			-- a road ends at a village's or POI's core edge, at both ends; the
			-- core is a square, so the distance is the larger axis distance
			-- from the core centre (the road's round end then stays clear of
			-- the core and its one-node margin on every side)
			local function cheb(i, nd) return max(abs(X[i] - nd.x), abs(Z[i] - nd.z)) end
			local function trim_back(r)
				local n = #X
				local cut = n
				while cut > 1 and cheb(cut, b) < r do cut = cut - 1 end
				if cut < n then
					local nX, nZ = {}, {}
					for i = 1, cut do nX[i], nZ[i] = X[i], Z[i] end
					X, Z = nX, nZ
				end
			end
			local function trim_front(r)
				local cut = 1
				while cut < #X and cheb(cut, a) < r do cut = cut + 1 end
				if cut > 1 then
					local nX, nZ = {}, {}
					for i = cut, #X do nX[#nX + 1], nZ[#nZ + 1] = X[i], Z[i] end
					X, Z = nX, nZ
				end
			end
			-- (its round end stays outside the building core)
			if a.core then trim_front(a.core / 2 + P.CORE_GAP + hw) end
			if b and b.core and info.kind == "node" then trim_back(b.core / 2 + P.CORE_GAP + hw) end
			if #X < 2 then return nil end
			-- a trimmed end is pinned to the core's fitted height, so the road
			-- meets the pad level and leaves the core's ground alone
			road.a_core = a.core ~= nil
			road.b_core = b ~= nil and b.core ~= nil and info.kind == "node"
			road.b_y = b and b.y or nil
			road.X, road.Z = X, Z
			if road_check and not road_check(road) then return nil end
			road.expand = last_expand
			road.a_node, road.b_node = a, b
			sample_road(road)
			solve(road)
			classify(road)
			return road
		end
		-- the chosen candidate joins the network
		local function commit(road)
			local a, b, X, Z = road.a_node, road.b_node, road.X, road.Z
			if road.parent then
				local parent = roads[road.parent]
				parent.junctions[#parent.junctions + 1] = {idx = road.parent_idx, road = road.id}
			end
			-- capital ends
			for _, nd in ipairs({a, b}) do
				if nd and nd.kind == "capital" then
					local ex, ez
					if nd == a then ex, ez = X[1], Z[1] else ex, ez = X[#X], Z[#Z] end
					ring_used[nd.id] = ring_used[nd.id] or {}
					table.insert(ring_used[nd.id], {ex, ez})
				end
			end
			roads[road.id] = road
			register(road)
			if road.kind ~= "trail" then ndist_dirty = true end
			return road
		end
		-- one routed road: search, candidate (geometry, samples, provisional
		-- profile, audit), commit. Free decks are a last resort (D68): the
		-- audit only classifies them.
		-- A road whose core pin does not fit is routed again (the join it
		-- took is excluded) up to PIN_TRIES times; a loop is dropped instead.
		local function routed(kind, a, b_fixed, do_search)
			bad_join, pin_check = {}, true
			local road, cost
			for _ = 1, P.PIN_TRIES do
				local path, info, c, dirs, lead = do_search()
				if not path and pin_check then
					-- no join carries the pin: route without the check
					pin_check = false
					path, info, c, dirs, lead = do_search()
				end
				if not path then break end
				local b = b_fixed or (info.node and node_by_id[info.node]) or nil
				road, cost = make_candidate(kind, a, b, path, info, dirs, lead), c
				if not road or not road.no_core_pin then break end
				if not road.parent then
					if road_check then road = nil end    -- a loop: dropped
					break
				end
				local bucket = floor(road.parent_idx / 16)
				for k = bucket - 1, bucket + 1 do bad_join[road.parent .. ":" .. k] = true end
				stats.pin_rerouted = (stats.pin_rerouted or 0) + 1
			end
			pin_check = false
			if not road then return nil end
			audit(road)
			return commit(road), cost
		end

		local function heur_to(nd)
			if nd.kind == "capital" then
				local half = nd.half
				return function(li)
					local x, z = li_xz(li)
					local dx = max(abs(x - nd.x) - half - C, 0)
					local dz = max(abs(z - nd.z) - half - C, 0)
					return sqrt(dx * dx + dz * dz) * minmult
				end
			end
			return function(li)
				local x, z = li_xz(li)
				return sqrt((x - nd.x) ^ 2 + (z - nd.z) ^ 2) * minmult
			end
		end

		-- route node a to node b specifically (capital chain, loops)
		local function route_pair(kind, a, b)
			local srcs, lead = endpoint(a)
			local allow = allow_of(a)
			for li in pairs(allow_of(b)) do allow[li] = true end
			local tcells = {}
			if b.kind == "capital" then
				for li, cid in pairs(ring) do if cid == b.id and ring_free(b.id, li) then tcells[li] = true end end
			else
				local k = cell_of(b.x, b.z)
				tcells[LI[k]] = true
			end
			return routed(kind, a, b, function()
				local path, info, cost, dirs = search(srcs, function(li)
					if tcells[li] then return {kind = "node"} end
				end, heur_to(b), nil, kind == "trail", nil, allow)
				return path, info, cost, dirs, lead
			end)
		end
		-- route node a to the nearest joinable road cell (or a free capital edge)
		local function route_join(kind, a, budget, joinable_kinds)
			local srcs, lead = endpoint(a)
			local allow = allow_of(a)
			if ndist_dirty then update_ndist(); ndist_dirty = false end
			local hk = 0.9 * minmult
			local function heur(li)
				local d = NDIST[KOF[li]]
				if d == INF then return 0 end
				return d * hk
			end
			-- a core end is pinned to its pad: a join is taken only where the
			-- parent's height can be reached from it (plus the retry list)
			local function pin_fits(road, idx)
				if not (pin_check and a.core and a.y and road.R) then return true end
				if bad_join[road.id .. ":" .. floor(idx / 16)] then return false end
				local d = sqrt((road.X[idx] - a.x) ^ 2 + (road.Z[idx] - a.z) ^ 2) -
					a.core / 2 - P.CORE_GAP
				return abs(road.R[idx] - a.y) <= P.PIN_GRADE * (d - P.PIN_SLACK)
			end
			local function target(li, d)
				local nc = netcell[li]
				if nc and joinable_kinds[nc.kind] then
					local road = roads[nc.road]
					if join_ok(road, nc.idx) and pin_fits(road, nc.idx) then
						-- junction angle: no shallow merges
						local i = nc.idx
						local j = min(#road.X, i + 3)
						local i0 = max(1, i - 3)
						local tx, tz = road.X[j] - road.X[i0], road.Z[j] - road.Z[i0]
						local l = sqrt(tx * tx + tz * tz)
						if l > 0 then
							local c = abs(tx * DIRS[d].ux + tz * DIRS[d].uz) / l
							if c <= P.JOIN_MAXCOS then return {kind = "road", road = nc.road} end
						end
					end
				end
				local cid = ring[li]
				if cid and kind ~= "trail" and joinable_kinds.capital and ring_used[cid] and ring_free(cid, li) then
					return {kind = "node", node = cid}
				end
			end
			return routed(kind, a, nil, function()
				local path, info, cost, dirs = search(srcs, target, heur, budget, kind == "trail", nil, allow)
				return path, info, cost, dirs, lead
			end)
		end

		-----------------------------------------------------------------------
		-- Kit (capital planner, plan §11): with `opts.kit` the build hands the
		-- caller the routing grid, the A* search, the geometry, the terrain
		-- sampling, the profile DP and the classes instead of running
		-- `opts.order`, so a planner builds its own streets (avenues, lanes,
		-- connectors) on its own grid with the same look, grade rule (<= 1/2
		-- per column) and raster as the network.
		-----------------------------------------------------------------------
		if opts.kit then
			local kit = {LI = LI, KOF = KOF, NL = NL, nx = nx, nz = nz, C = C,
				x0 = GX0, z0 = GZ0, H = H, cell_of = cell_of, li_xz = li_xz,
				minmult = minmult, roads = roads, netcell = netcell,
				blocked = blocked, stats = stats, DIRS = DIRS}
			function kit.set_guide(g) GUIDE = g end
			function kit.search(sources, target, heur, allow, budget)
				return search(sources, target, heur, budget, false, nil, allow)
			end
			local function relattice(X, Z)
				local q = {}
				for i = 1, #X do q[i] = {X[i], Z[i]} end
				q = resample(q, 1)
				local nX, nZ = {}, {}
				for i, pt in ipairs(q) do
					nX[i], nZ[i] = floor(pt[1] * LAT + 0.5) / LAT, floor(pt[2] * LAT + 0.5) / LAT
				end
				return nX, nZ
			end
			-- ctrl: control points {{x, z}, ...} (cell centres of a searched
			-- path plus fixed lead points); f: a/b labels, a_parent/b_parent
			-- (road ids the street starts/ends on), pin_a/pin_b (end levels in
			-- nodes), flat_a/flat_b (flat end stretches in points)
			function kit.street(kind, ctrl, f)
				f = f or {}
				local hw = assert(P.HALF[kind], "unknown street kind " .. tostring(kind))
				local X, Z = make_geometry(ctrl, hw)
				local road = {id = #roads + 1, kind = kind, hw = hw, junctions = {},
					a = f.a or "-", b = f.b or "-", a_kind = "street", b_kind = "street"}
				if f.b_parent then
					local parent = roads[f.b_parent]
					local idx = nearest_idx(parent, X[#X], Z[#Z])
					X[#X], Z[#Z] = parent.X[idx], parent.Z[idx]
					X, Z = relattice(X, Z)
					road.parent, road.parent_idx = parent.id, idx
					road.b = "road:" .. parent.id
				end
				if f.a_parent then
					local parent = roads[f.a_parent]
					local idx = nearest_idx(parent, X[1], Z[1])
					X[1], Z[1] = parent.X[idx], parent.Z[idx]
					X, Z = relattice(X, Z)
					road.a_parent, road.a_parent_idx = parent.id, idx
					road.a = "road:" .. parent.id
				end
				road.X, road.Z = X, Z
				road.pin_a, road.pin_b, road.flat_a, road.flat_b = f.pin_a, f.pin_b, f.flat_a, f.flat_b
				sample_road(road)
				solve(road)
				classify(road)
				return road
			end
			function kit.commit(road)
				if road.parent then
					local p = roads[road.parent]
					p.junctions[#p.junctions + 1] = {idx = road.parent_idx, road = road.id}
				end
				if road.a_parent then
					local p = roads[road.a_parent]
					p.junctions[#p.junctions + 1] = {idx = road.a_parent_idx, road = road.id, side = "a"}
				end
				roads[road.id] = road
				register(road)
				return road
			end
			-- final profiles in build order (parents first), classes and audit
			function kit.finish()
				local t4 = os.clock()
				stats.infeasible, stats.infeasible_ids = nil, nil
				for _, road in ipairs(roads) do road.dead_at = nil end
				for _, road in ipairs(roads) do solve(road) end
				for _, road in ipairs(roads) do classify(road); audit(road) end
				stats.t_profile = (stats.t_profile or 0) + os.clock() - t4
				stats.samples = nsample
				return {roads = roads, stats = stats, seed = seed}
			end
			return kit
		end

		local T1 = os.clock()
		local order = opts.order
		local built_pairs = {}
		for _, step in ipairs(order) do
			if step.op == "pair" then
				local r = route_pair(step.kind, node_by_id[step.a], node_by_id[step.b])
				if not r then stats.failed = (stats.failed or 0) + 1 end
			elseif step.op == "join" then
				local r = route_join(step.kind, node_by_id[step.a], step.budget,
					step.targets or {primary = true, secondary = true, capital = true})
				if not r then stats.failed = (stats.failed or 0) + 1 end
			end
		end
		stats.t_route_roads = os.clock() - T1

		-- loops: a few pairs whose network distance is long against their
		-- straight distance
		local T2 = os.clock()
		if P.LOOPS > 0 and opts.loop_candidates then
			-- network distance by Dijkstra on the road graph (roads as edges
			-- between their end points and junction points, arc lengths)
			local function netdist(aid, bid)
				-- graph nodes: "road:i:idx" points; edges along roads between
				-- consecutive key points
				local keys = {}
				local adj = {}
				local function key(r, idx) return r .. ":" .. idx end
				local function add(u, v, w)
					adj[u] = adj[u] or {}; adj[v] = adj[v] or {}
					table.insert(adj[u], {v, w}); table.insert(adj[v], {u, w})
				end
				for _, r in ipairs(roads) do
					if r.kind ~= "trail" then
						local pts = {1, #r.X}
						for _, j in ipairs(r.junctions) do pts[#pts + 1] = j.idx end
						table.sort(pts)
						for i = 2, #pts do add(key(r.id, pts[i - 1]), key(r.id, pts[i]), pts[i] - pts[i - 1]) end
						if r.parent then add(key(r.id, #r.X), key(r.parent, r.parent_idx), 0) end
					end
				end
				-- node ids to graph keys
				local function node_keys(id)
					local out = {}
					for _, r in ipairs(roads) do
						if r.kind ~= "trail" then
							if r.a == id then out[#out + 1] = key(r.id, 1) end
							if r.b == id then out[#out + 1] = key(r.id, #r.X) end
						end
					end
					return out
				end
				local src, dst = node_keys(aid), {}
				for _, k in ipairs(node_keys(bid)) do dst[k] = true end
				local dd, heap = {}, heap_new()
				for _, k in ipairs(src) do dd[k] = 0; heap_push(heap, k, 0) end
				-- capitals: all their ends are one node
				while true do
					local u, du = heap_pop(heap)
					if not u then return INF end
					if du <= dd[u] then
						if dst[u] then return du end
						for _, e in ipairs(adj[u] or {}) do
							local v, w = e[1], du + e[2]
							if not dd[v] or w < dd[v] then dd[v] = w; heap_push(heap, v, w) end
						end
					end
				end
			end
			local cands = {}
			for _, c in ipairs(opts.loop_candidates) do
				local a, b = node_by_id[c[1]], node_by_id[c[2]]
				-- a start is always the near end (its gate stretch leads out);
				-- two starts never form a loop
				if b.kind == "start" then a, b = b, a end
				if b.kind ~= "start" then
					local straight = sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
					local nd = netdist(a.id, b.id)
					if nd < INF and nd > P.LOOP_RATIO * straight then
						cands[#cands + 1] = {a = a, b = b, gain = nd - straight, ratio = nd / straight}
					end
				end
			end
			table.sort(cands, function(p, q) if p.gain ~= q.gain then return p.gain > q.gain end return p.a.id < q.a.id end)
			local nloops = 0
			stats.loop_candidates = #cands
			stats.loops_rejected = 0
			-- a loop must not touch another road away from its two ends (it
			-- would cross it without a junction)
			road_check = function(road)
				local hash = {}
				local function hk(x, z) return floor(z / 16) * 8192 + floor(x / 16) end
				for _, o in ipairs(roads) do
					for i = 1, #o.X, 2 do
						local k = hk(o.X[i], o.Z[i])
						hash[k] = hash[k] or {}
						table.insert(hash[k], {o.X[i], o.Z[i], o.hw})
					end
				end
				local n = #road.X
				for i = P.LOOP_END_FREE, n - P.LOOP_END_FREE do
					local x, z = road.X[i], road.Z[i]
					for dz = -1, 1 do for dx = -1, 1 do
						local l = hash[hk(x, z) + dz * 8192 + dx]
						if l then
							for _, p in ipairs(l) do
								local lim = road.hw + p[3] + 4
								if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < lim * lim then return false end
							end
						end
					end end
				end
				return true
			end
			on_road_penalty = P.K_ONROAD
			local tried = {}
			for _, c in ipairs(cands) do
				if nloops >= P.LOOPS then break end
				-- one loop per endpoint
				if not tried[c.a.id] and not tried[c.b.id] then
					local r = route_pair("secondary", c.a, c.b)
					if r then
						r.loop = true; nloops = nloops + 1
						tried[c.a.id], tried[c.b.id] = true, true
					else
						stats.loops_rejected = stats.loops_rejected + 1
					end
				end
			end
			on_road_penalty, road_check = nil, nil
			stats.loops = nloops
		end
		stats.t_loops = os.clock() - T2

		-- trails
		local T3 = os.clock()
		stats.trails_tried, stats.trails_built = 0, 0
		for _, poi in ipairs(opts.trail_nodes or {}) do
			stats.trails_tried = stats.trails_tried + 1
			local r = route_join("trail", poi, P.TRAIL_BUDGET, {primary = true, secondary = true})
			if r then stats.trails_built = stats.trails_built + 1; r.a_poi = poi.kind end
		end
		stats.t_route_trails = os.clock() - T3
		stats.searches, stats.expansions = nsearch, nexpand

		local T4 = os.clock()
		-- solve in build order (parents first; loops after both ends exist)
		-- A road's provisional profile is final unless it has since gained a
		-- junction or its parent's height at the junction changed: solve is a
		-- pure function of those inputs and the road's own geometry and
		-- samples, so those roads keep their profile as it is.
		for _, road in ipairs(roads) do
			local pin_now = false
			if road.parent then
				local parent = roads[road.parent]
				pin_now = parent.RQ and parent.RQ[road.parent_idx] or false
			end
			if not road.RQ or road.solved_junctions ~= #road.junctions or
					(road.parent and road.solved_parent_pin ~= pin_now) then
				solve(road)
			end
		end
		stats.t_profile = os.clock() - T4
		stats.samples = nsample

		for _, road in ipairs(roads) do classify(road); audit(road) end
		-- roads whose core pin did not fit (never seen on the tested seeds):
		-- the loader logs them
		stats.pins_dropped = {}
		for _, road in ipairs(roads) do
			if road.no_core_pin then
				stats.pins_dropped[#stats.pins_dropped + 1] = road.id .. ":" .. road.a .. "-" .. road.b
			end
		end
		stats.t_total = os.clock() - T0
		local layout = {roads = roads, stats = stats, seed = seed}

		-- Point-to-point routing (plan §11, D59/D60): a road of `kind` from
		-- `a` to `b` ({x =, z =, y = optional ground y to pin the end to})
		-- with the network's own routing costs, geometry, profile and
		-- classes, appended to this layout (serialize afterwards). `through`
		-- lists reservation ids the road may enter (e.g. the capital whose
		-- gate it reaches). Main only, after build; returns the road or nil.
		function layout.connect(kind, a, b, through)
			if not P.HALF[kind] then error("road kind differs: " .. tostring(kind), 2) end
			local na = {id = "point", kind = "point", x = a.x, z = a.z}
			local nb = {id = "point", kind = "point", x = b.x, z = b.z}
			local ka, kb = cell_of(a.x, a.z), cell_of(b.x, b.z)
			if not (ka and LI[ka] and kb and LI[kb]) then return nil end
			local allow = {}
			for li, id in pairs(owner) do
				for _, t in ipairs(through or {}) do
					if id == t then allow[li] = true end
				end
			end
			local target = LI[kb]
			local path, info, cost, dirs = search({{LI[ka], nil, 0}}, function(li)
				if li == target then return {kind = "node"} end
			end, heur_to(nb), nil, kind == "trail", nil, allow)
			if not path then return nil end
			-- both points in one grid cell: the straight piece between them
			if #path == 1 then path, dirs = {path[1], path[1]}, {dirs[1], dirs[1]} end
			local road = make_candidate(kind, na, nb, path, info, dirs, nil)
			if not road then return nil end
			road.pin_a, road.pin_b = a.y, b.y
			if a.y or b.y then solve(road); classify(road) end
			audit(road)
			commit(road)
			return road
		end
		return layout
	end

	---------------------------------------------------------------------------
	-- Serialization (the ipc_set payload), plain text, deterministic:
	--   R3 <nroads>
	--   r <id> <kind> <parent or 0> <parent idx or 0> <n> <a> <b> <x0*128> <z0*128> <v0>
	--   <3 chars per step: centreline delta in 1/LAT node>
	--   <1 char per step: profile delta in 1/Q node>
	--   c <run-length classes>
	-- The centreline is on a 1/LAT lattice and about 1 node apart, so every
	-- step fits three base-64 characters; the profile changes by at most Q per step.
	---------------------------------------------------------------------------
	local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local B64I = {}
	for i = 1, 64 do B64I[B64:byte(i)] = i - 1 end
	function M.serialize(layout)
		local out = {"R3 " .. #layout.roads}
		local ch = {}
		for i = 1, 64 do ch[i - 1] = B64:sub(i, i) end
		for _, r in ipairs(layout.roads) do
			local n = #r.X
			local qx, qz = floor(r.X[1] * LAT + 0.5), floor(r.Z[1] * LAT + 0.5)
			out[#out + 1] = ("r %d %s %d %d %d %s %s %d %d %d"):format(r.id, r.kind, r.parent or 0,
				r.parent_idx or 0, n, r.a, r.b, qx, qz, r.RQ[1])
			local xs = {}
			for i = 2, n do
				local x, z = floor(r.X[i] * LAT + 0.5), floor(r.Z[i] * LAT + 0.5)
				local dx, dz = x - qx + LAT + 2, z - qz + LAT + 2
				local SPAN = 2 * LAT + 5
				assert(dx >= 0 and dx < SPAN and dz >= 0 and dz < SPAN, "centreline step too long")
				local code = dx * SPAN + dz
				xs[#xs + 1] = ch[floor(code / 4096)] .. ch[floor(code / 64) % 64] .. ch[code % 64]
				qx, qz = x, z
			end
			out[#out + 1] = table.concat(xs)
			local ps = {}
			for i = 2, n do
				local dv = r.RQ[i] - r.RQ[i - 1] + 32
				assert(dv >= 0 and dv < 64, "profile step too large")
				ps[#ps + 1] = ch[dv]
			end
			out[#out + 1] = table.concat(ps)
			local cr = {}
			local i = 1
			while i <= n do
				local j = i
				while j < n and r.cls[j + 1] == r.cls[i] do j = j + 1 end
				cr[#cr + 1] = r.cls[i] .. (j - i + 1)
				i = j + 1
			end
			out[#out + 1] = "c " .. table.concat(cr, " ")
		end
		return table.concat(out, "\n") .. "\n"
	end

	function M.deserialize(text)
		local lines = {}
		for l in text:gmatch("[^\n]*") do lines[#lines + 1] = l end
		-- gmatch("[^\n]*") yields empty strings between separators; keep
		-- only the real lines (an empty centreline line is possible for
		-- n == 1, which build never emits)
		local L = {}
		for _, l in ipairs(lines) do if l ~= "" then L[#L + 1] = l end end
		lines = L
		local nroads = tonumber(lines[1]:match("^R3 (%d+)"))
		local Q = M.P.Q
		local roads, li = {}, 2
		for _ = 1, nroads do
			local id, kind, parent, pidx, n, a, b, qx, qz, v = lines[li]:match(
				"^r (%d+) (%a+) (%d+) (%d+) (%d+) (%S+) (%S+) (%-?%d+) (%-?%d+) (%-?%d+)$")
			id, parent, pidx, n = tonumber(id), tonumber(parent), tonumber(pidx), tonumber(n)
			qx, qz, v = tonumber(qx), tonumber(qz), tonumber(v)
			local X, Z, RQ, Rv = {qx / LAT}, {qz / LAT}, {v}, {v / Q}
			local xs, ps = lines[li + 1], lines[li + 2]
			local SPAN = 2 * LAT + 5
			for i = 2, n do
				local o = 3 * (i - 2)
				local code = B64I[xs:byte(o + 1)] * 4096 + B64I[xs:byte(o + 2)] * 64 + B64I[xs:byte(o + 3)]
				qx = qx + floor(code / SPAN) - LAT - 2
				qz = qz + code % SPAN - LAT - 2
				X[i], Z[i] = qx / LAT, qz / LAT
				v = v + B64I[ps:byte(i - 1)] - 32
				RQ[i], Rv[i] = v, v / Q
			end
			local cls = {}
			local i = 1
			for tkn in lines[li + 3]:sub(3):gmatch("%S+") do
				local c, cnt = tkn:match("^(%a)(%d+)$")
				for _ = 1, tonumber(cnt) do cls[i] = c; i = i + 1 end
			end
			roads[id] = {id = id, kind = kind, parent = parent > 0 and parent or nil,
				parent_idx = pidx > 0 and pidx or nil, X = X, Z = Z, R = Rv, RQ = RQ, cls = cls,
				a = a, b = b, hw = M.P.HALF[kind]}
			li = li + 4
		end
		return {roads = roads}
	end

	---------------------------------------------------------------------------
	-- Sampler: per-column road answer (the emerge-side raster).
	--   S.column(x, z, t, wy) -> kind, road_y, new_t, road_id, idx, extra
	--   kind: nil (untouched), "surface" (road surface column; extra = class
	--   "grade"/"cut"/"fill"/"deck"/"bridge"/"ford"), "cutslope",
	--   "wall", "embslope"; new_t: the terrain after the road (for surface
	--   columns on a deck/bridge: the untouched terrain). extra.pillar flags
	--   pillar columns on a deck/bridge; extra.bridge flags every surface
	--   column of a bridge run (below).
	-- Bridge runs (D74): a raised run is a maximal run of consecutive deck
	-- or bridge points ("D"/"B") of one road; it is a bridge run when it
	-- holds at least one water-crossing point ("B"). It lands on each bank
	-- with up to BRIDGE_LAND ground points ("G"), so the wet edge columns of
	-- an oblique bank still belong to it. Every surface column whose nearest
	-- point lies in a bridge run takes the bridge material, bank to bank,
	-- whatever supports it; every other column takes the road's one surface
	-- material. The runs come from the serialized classes alone, so main
	-- and emerge and every chunk agree.
	---------------------------------------------------------------------------
	function M.bridge_points(cls)
		local out, n, i = {}, #cls, 1
		local land = P.BRIDGE_LAND
		while i <= n do
			local c = cls[i]
			if c == "D" or c == "B" then
				local j, wet = i, c == "B"
				while j < n and (cls[j + 1] == "D" or cls[j + 1] == "B") do
					j = j + 1
					if cls[j] == "B" then wet = true end
				end
				if wet then
					local a, b = i, j
					while a > 1 and a > i - land and cls[a - 1] == "G" do a = a - 1 end
					while b < n and b < j + land and cls[b + 1] == "G" do b = b + 1 end
					for q = a, b do out[q] = true end
				end
				i = j + 1
			else
				i = i + 1
			end
		end
		return out
	end
	function M.sampler(layout)
		local BUCKET = P.BUCKET
		local buckets = {}
		local SIDE = P.SIDE_MAX
		local function bkey(bx, bz) return bz * 8192 + bx end
		local bridge_at = {}
		for _, r in ipairs(layout.roads) do
			bridge_at[r.id] = M.bridge_points(r.cls)
			local X, Z = r.X, r.Z
			local reach = r.hw + SIDE + 1
			for i = 1, #X - 1 do
				local x0, x1 = min(X[i], X[i + 1]) - reach, max(X[i], X[i + 1]) + reach
				local z0, z1 = min(Z[i], Z[i + 1]) - reach, max(Z[i], Z[i + 1]) + reach
				for bz = floor(z0 / BUCKET), floor(z1 / BUCKET) do
					for bx = floor(x0 / BUCKET), floor(x1 / BUCKET) do
						local k = bkey(bx, bz)
						local l = buckets[k]
						if not l then l = {}; buckets[k] = l end
						l[#l + 1] = r.id * 65536 + i
					end
				end
			end
		end
		local roads = layout.roads
		local function column(x, z, t, wy)
			local list = buckets[bkey(floor(x / BUCKET), floor(z / BUCKET))]
			if not list then return nil end
			-- nearest surface segment (hard min of distance minus half width)
			local best, br, bi, bu = INF, nil, nil, nil
			local cut_cap, fill_floor = INF, -INF
			local wall_at, wall_base = false, nil
			for j = 1, #list do
				local code = list[j]
				local rid, i = floor(code / 65536), code % 65536
				local r = roads[rid]
				local ax, az, bx, bz = r.X[i], r.Z[i], r.X[i + 1], r.Z[i + 1]
				local vx, vz = bx - ax, bz - az
				local l2 = vx * vx + vz * vz
				local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
				-- "interior": the projection falls on this segment, or past
				-- its end onto a neighbour that is ground-supported too (so
				-- the outside of a bend has no gaps; only the end of a
				-- ground-supported run next to a deck is excluded)
				local interior = true
				if u < 0 then
					local c0 = r.cls[i - 1]
					interior = c0 == nil or c0 == "G"
				elseif u > 1 then
					local c2 = r.cls[i + 2]
					interior = c2 == nil or c2 == "G"
				end
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local px, pz = ax + u * vx, az + u * vz
				local d = sqrt((x - px) ^ 2 + (z - pz) ^ 2)
				local e = d - r.hw
				if e < best then best, br, bi, bu = e, r, i, u end
				if e > 0 and e <= SIDE then
					local idx = u < 0.5 and i or i + 1
					local ry = r.R[i] + u * (r.R[i + 1] - r.R[i])
					local c = r.cls[idx]
					-- cut slope ~1:1 back from the edge, a low wall at its foot
					-- where the cut is deep
					-- (the wall height grows with the column's cut, so the
					-- answer stays continuous)
					local wh = min(P.WALL_H, max(0, t - ry - P.WALL_MIN))
					-- ~1:1 soil slope for the first CUT_SOIL nodes, then a
					-- steeper rock face (CUT_ROCK per node), so deep cuts end
					-- inside the side zone instead of at its edge
					local ee = max(0, e - 1)
					local cap = ry + wh + min(ee, P.CUT_SOIL) * P.CUT_SLOPE +
						max(0, ee - P.CUT_SOIL) * P.CUT_ROCK +
						min(e, 1) * (1 - wh / P.WALL_H) * P.CUT_SLOPE
					local walled = wh > 0 and e <= 1.5
					if cap < cut_cap then
						cut_cap, wall_at = cap, walled
						wall_base = walled and floor(ry) + 1 or nil
					end
					-- embankment only beside ground-supported road, and only
					-- straight out from it (not around the end of a
					-- ground-supported stretch, which would spill under a deck)
					if c == "G" and interior and e <= P.EMB_REACH then
						local fl = ry - e * P.EMB_SLOPE
						if fl > fill_floor then fill_floor = fl end
					end
				end
			end
			if not br then return nil end
			if best <= 0 then
				local idx = bu < 0.5 and bi or bi + 1
				local rc = br.R[bi] + bu * (br.R[bi + 1] - br.R[bi])
				local ry = floor(2 * rc + 0.5) / 2
				local c = br.cls[idx]
				local top = floor(ry)            -- full node top; +0.5 = slab
				local kind
				local wet = wy and wy > t
				if c == "B" or (wet and ry >= wy + P.CLEAR) then kind = "bridge"
				elseif wet then kind = "ford"
				elseif c == "D" and ry - t >= 1 then kind = "deck"
				elseif ry > t then kind = "fill"
				elseif ry < t then kind = "cut"
				else kind = "grade" end
				local extra = {class = kind, bridge = bridge_at[br.id][idx]}
				if kind == "deck" or kind == "bridge" then
					extra.pillar = (idx % P.PILLAR_EVERY == 0) and best > -1.2
				end
				local newt = t
				if kind == "cut" or kind == "fill" or kind == "grade" then newt = top end
				if kind == "ford" then newt = top end
				return "surface", ry, newt, br.id, idx, extra
			end
			-- side zone
			if t > cut_cap then
				local nt = floor(cut_cap)
				if nt < t then
					if wall_at then return "wall", nil, nt, nil, nil, {base = wall_base} end
					return "cutslope", nil, nt
				end
			end
			if t < fill_floor and not (wy and wy > t) then
				-- the fill never stands more than EMB_TOE above the ground:
				-- where the terrain falls away faster than the fill slope the
				-- embankment ends there in a low step (its toe wall) and the
				-- ground beyond stays untouched
				local nt = floor(fill_floor + 0.5)
				if nt - t > P.EMB_TOE then return nil end
				return (nt - t >= 2 and "embwall" or "embslope"), nil, nt
			end
			return nil
		end
		-- True when (x, z) lies within `pad` nodes of a road's edge (the claim
		-- exclusion of the corridor, beside its side slopes).
		-- (A pad beyond the buckets' side reach also scans the neighbouring
		-- buckets.)
		local function near(x, z, pad)
			local k = pad > SIDE and math.ceil((pad - SIDE) / BUCKET) or 0
			local bx0, bz0 = floor(x / BUCKET), floor(z / BUCKET)
			for bz = bz0 - k, bz0 + k do
				for bx = bx0 - k, bx0 + k do
					local list = buckets[bkey(bx, bz)]
					if list then
						for j = 1, #list do
							local code = list[j]
							local rid, i = floor(code / 65536), code % 65536
							local r = roads[rid]
							local ax, az = r.X[i], r.Z[i]
							local vx, vz = r.X[i + 1] - ax, r.Z[i + 1] - az
							local l2 = vx * vx + vz * vz
							local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
							if u < 0 then u = 0 elseif u > 1 then u = 1 end
							local dx, dz = x - ax - u * vx, z - az - u * vz
							local lim = r.hw + pad
							if dx * dx + dz * dz <= lim * lim then return true end
						end
					end
				end
			end
			return false
		end
		return {column = column, near = near, buckets = buckets, roads = roads}
	end

	---------------------------------------------------------------------------
	-- Network inputs from the source anchors (world_zones.md §9): nodes
	-- (capitals, starts, villages, one contested endpoint per frontier zone:
	-- the outpost or clash site nearest the own capital, D18), trail nodes
	-- (every other outpost, mine, bandit and Mirefolk camp on the two
	-- mainlands, D19), reserved areas (capital squares, D59; start envelopes;
	-- POI cores), the build order and the loop candidates. `position_of(id)`
	-- returns an anchor's fitted x, z and (optionally) its fitted ground y.
	---------------------------------------------------------------------------
	function M.inputs(source, position_of)
		local prof = {}
		for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
		local zone = {}
		for _, z in ipairs(source.zones) do zone[z.numeric_id] = z end
		local function faction(zn)
			return zn <= 16 and "elandor" or (zn <= 32 and "kragmar" or "front")
		end
		local function pos(a)
			if position_of then return position_of(a.id) end
			return a.position.x, a.position.z
		end
		local nodes, trail_nodes, reserved, caps = {}, {}, {}, {}
		for _, a in ipairs(source.anchors) do
			if a.slot_id == "capital" then
				local x, z = pos(a)
				local nd = {id = a.id, kind = "capital", x = x, z = z, half = 256,
					faction = faction(a.zone_numeric_id), zone = a.zone_numeric_id}
				nodes[#nodes + 1] = nd
				caps[#caps + 1] = nd
				reserved[#reserved + 1] = {id = a.id, x = x, z = z, half = 256, ring = true}
			end
		end
		local function own_capital(x, z, fac)
			local best, bd
			for _, c in ipairs(caps) do
				if c.faction == fac then
					local d = (c.x - x) ^ 2 + (c.z - z) ^ 2
					if not bd or d < bd then best, bd = c, d end
				end
			end
			return best, bd and math.sqrt(bd)
		end
		local contested = {}
		for _, a in ipairs(source.anchors) do
			local fac = faction(a.zone_numeric_id)
			if zone[a.zone_numeric_id].territory_rule == "contested_land" and fac ~= "front" and
					(a.template_id == "outpost" or a.template_id == "clash") then
				local x, z = pos(a)
				local _, d = own_capital(x, z, fac)
				local cur = contested[a.zone_numeric_id]
				if not cur or d < cur.d then contested[a.zone_numeric_id] = {a = a, d = d} end
			end
		end
		local used = {}
		for _, a in ipairs(source.anchors) do
			local x, z = pos(a)
			local fac = faction(a.zone_numeric_id)
			if a.slot_id == "start" then
				local cap = own_capital(x, z, fac)
				-- the gate stretch starts level with the start pad (its fitted
				-- ground y when `position_of` gives it)
				local _, _, pad_y = pos(a)
				nodes[#nodes + 1] = {id = a.id, kind = "start", x = x, z = z, y = pad_y,
					faction = fac, gate_dir = cap.z > z and 1 or -1, zone = a.zone_numeric_id}
				reserved[#reserved + 1] = {id = a.id, x = x, z = z, half = 80}
			elseif a.slot_id ~= "capital" then
				local core = prof[a.template_id].building_core_width or 16
				reserved[#reserved + 1] = {id = a.id, x = x, z = z, half = core / 2 + 10, round = true}
				local _, _, core_y = pos(a)
				if a.template_id == "village" then
					nodes[#nodes + 1] = {id = a.id, kind = "village", x = x, z = z, y = core_y,
						faction = fac, core = core, zone = a.zone_numeric_id}
					used[a.id] = true
				elseif contested[a.zone_numeric_id] and contested[a.zone_numeric_id].a == a then
					nodes[#nodes + 1] = {id = a.id, kind = "contested", x = x, z = z, y = core_y,
						faction = fac, core = core, zone = a.zone_numeric_id}
					used[a.id] = true
				end
			end
		end
		for _, a in ipairs(source.anchors) do
			local t = a.template_id
			local fac = faction(a.zone_numeric_id)
			if not used[a.id] and fac ~= "front" and (t == "outpost" or t == "mine" or
					t == "bandit_home" or t == "bandit_frontier" or t == "mirefolk") then
				local x, z, core_y = pos(a)
				trail_nodes[#trail_nodes + 1] = {id = a.id, kind = t, x = x, z = z, y = core_y,
					core = prof[t].building_core_width, faction = fac, zone = a.zone_numeric_id}
			end
		end
		table.sort(trail_nodes, function(a, b) return a.id < b.id end)
		-- build order per faction: the capital chain west to east, then
		-- starts, villages and contested endpoints nearest their capital first
		local order = {}
		for _, fac in ipairs({"elandor", "kragmar"}) do
			local fc = {}
			for _, c in ipairs(caps) do if c.faction == fac then fc[#fc + 1] = c end end
			table.sort(fc, function(a, b) return a.x < b.x end)
			for i = 2, #fc do
				order[#order + 1] = {op = "pair", kind = "primary", a = fc[i - 1].id, b = fc[i].id}
			end
			local function add(kind, filter)
				local list = {}
				for _, nd in ipairs(nodes) do
					if nd.faction == fac and filter(nd) then list[#list + 1] = nd end
				end
				table.sort(list, function(a, b)
					local _, da = own_capital(a.x, a.z, fac)
					local _, db = own_capital(b.x, b.z, fac)
					if da ~= db then return da < db end
					return a.id < b.id
				end)
				for _, nd in ipairs(list) do order[#order + 1] = {op = "join", kind = kind, a = nd.id} end
			end
			add("primary", function(nd) return nd.kind == "start" end)
			add("secondary", function(nd) return nd.kind == "village" end)
			add("secondary", function(nd) return nd.kind == "contested" end)
		end
		local loops = {}
		for i = 1, #nodes do
			for j = i + 1, #nodes do
				local a, b = nodes[i], nodes[j]
				if a.faction == b.faction and a.kind ~= "contested" and b.kind ~= "contested" and
						not (a.kind == "capital" and b.kind == "capital") then
					local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
					if d < P.LOOP_REACH then loops[#loops + 1] = {a.id, b.id} end
				end
			end
		end
		return {nodes = nodes, trail_nodes = trail_nodes, reserved = reserved,
			order = order, loop_candidates = loops}
	end

	-- Centrelines for drawing (the world map): {kind = "road" or "trail",
	-- points = {{x =, z =}, ...}} with every 8th point and both ends.
	function M.polylines(layout)
		local out = {}
		for _, r in ipairs(layout.roads) do
			local pts = {}
			local n = #r.X
			for i = 1, n, 8 do pts[#pts + 1] = {x = floor(r.X[i] + 0.5), z = floor(r.Z[i] + 0.5)} end
			if (n - 1) % 8 ~= 0 then pts[#pts + 1] = {x = floor(r.X[n] + 0.5), z = floor(r.Z[n] + 0.5)} end
			out[#out + 1] = {kind = r.kind == "trail" and "trail" or "road", points = pts}
		end
		return out
	end

	-- Showcase spots for a playtest (main, on a built layout): one place per
	-- feature, {name, x, y, z, road} with y the road surface; nil entries are
	-- features this world does not have. Serpentine: the first hairpin of a
	-- road (heading change >= 150 degrees within 40 nodes); gallery: the
	-- longest run of one-sided deck points; valley crossing: the longest short
	-- crossing; bridge: the longest bridge run; deepest cut: the deepest
	-- ground-supported centre cut; junction: a road joining a road; ford: the
	-- first ford run. Roads before trails.
	function M.showcase(layout)
		local spots = {}
		local function at(name, r, i)
			spots[#spots + 1] = {name = name, x = floor(r.X[i] + 0.5),
				y = floor(r.R[i] + 0.5), z = floor(r.Z[i] + 0.5), road = r.id, kind = r.kind}
		end
		local function best_run(pred)
			local best
			for pass = 1, 2 do
				for _, r in ipairs(layout.roads) do
					if (pass == 1) == (r.kind ~= "trail") then
						local i, n = 1, #r.X
						while i <= n do
							if pred(r, i) then
								local j = i
								while j < n and pred(r, j + 1) do j = j + 1 end
								if not best or j - i > best[3] - best[2] then best = {r, i, j} end
								i = j + 1
							else
								i = i + 1
							end
						end
					end
				end
				if best then return best[1], floor((best[2] + best[3]) / 2) end
			end
			return nil
		end
		-- serpentine
		local done
		for pass = 1, 2 do
			for _, r in ipairs(layout.roads) do
				if not done and (pass == 1) == (r.kind ~= "trail") then
					local X, Z, n, W = r.X, r.Z, #r.X, 20
					for i = 1, n - 2 * W do
						local h1 = atan2(Z[i + 4] - Z[i], X[i + 4] - X[i])
						local h2 = atan2(Z[i + 2 * W] - Z[i + 2 * W - 4], X[i + 2 * W] - X[i + 2 * W - 4])
						local d = abs(h2 - h1)
						if d > pi then d = 2 * pi - d end
						if d >= 150 / 180 * pi then at("serpentine", r, i + W); done = true break end
					end
				end
			end
		end
		local r, i = best_run(function(q, k)
			return q.cls[k] == "D" and not q.free[k] and not q.cross[k]
		end)
		if r then at("gallery", r, i) end
		r, i = best_run(function(q, k) return q.cross[k] end)
		if r then at("valley crossing", r, i) end
		r, i = best_run(function(q, k) return q.cls[k] == "B" end)
		if r then at("bridge", r, i) end
		local deep, dr, di = -INF, nil, nil
		for _, q in ipairs(layout.roads) do
			if q.kind ~= "trail" then
				for k = 1, #q.X do
					local wet = q.WY[k][1] and q.WY[k][1] > q.T[k][1]
					if q.cls[k] == "G" and not wet and q.T[k][1] - q.R[k] > deep then
						deep, dr, di = q.T[k][1] - q.R[k], q, k
					end
				end
			end
		end
		if dr then at("deepest cut", dr, di) end
		for _, q in ipairs(layout.roads) do
			if q.parent and q.kind ~= "trail" then at("junction", q, #q.X) break end
		end
		r, i = best_run(function(q, k)
			local wy = q.WY[k][1]
			return q.cls[k] == "F" and wy and q.R[k] < wy
		end)
		if r then at("ford", r, i) end
		return spots
	end

	return M
end

local M = new_module(DEFAULT_P)
-- The same code with other tunables (offline comparisons).
function M.with_params(overrides)
	local P = {}
	for k, v in pairs(DEFAULT_P) do P[k] = v end
	for k, v in pairs(overrides or {}) do P[k] = v end
	return new_module(P)
end
return M
