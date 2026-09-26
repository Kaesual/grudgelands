-- Round 22 capital planner (plan D60, D69, D70, D72; design option A,
-- docs/research/round22-capital-planner-design.md). Float maths (D2). A pure
-- function of the seed and its inputs (the height session's fitted column
-- answers, the river polylines, the road layout's ends at the reserved edge,
-- the plot kit): no chunk state, no cache file, no time budget.
--
--   local planner = dofile(".../capital_planner.lua")
--   local plan = planner.plan(seed, inputs, opts)  -- main, once per capital
--   local text = planner.serialize(plan)           -- the capital_layout payload
--   local layout = planner.deserialize(text)       -- main and emerge
--   plan.layout.roads                              -- streets and connectors,
--                                                  -- added to the road layout
--
-- Main runs it once per capital after height, water and roads
-- (`r7_runtime.lua`); emerge only deserializes. Both environments build the
-- capital from the DESERIALIZED layout, so they agree exactly.
--
-- Steps (design section 4):
--  1. sample a 2-node height/water grid of the reserved area (+ the band the
--     road ends lie in);
--  2. buildable mask (dry, off banks, not rough, outside the civic core);
--  3. outline: per ray from the anchor, a cost-accumulated reach over the
--     mask (steep ground and water cost more), a seeded low-frequency budget
--     noise, circular smoothing, the budget bisected to the target area;
--  4. four cardinal gates on the outline, slid (<= GATE_SLIDE along the
--     outline) toward the road ends they serve; each road end goes to the
--     gate nearest to it;
--  5. avenues core gate -> city gate and two ring lanes (per quadrant one arc
--     each, T junctions on the avenues), all routed with the road module's
--     A* on a 4-node city grid (a guide cost keeps rings near their radius
--     and every street inside the outline) and profiled by its DP (half
--     steps, <= 1/2 per column);
--  6. plots: candidate positions along every street side at plot-depth
--     setback, each plot turned (quarter turns) so its entry faces the
--     street; legality as today (dry with a margin, fall <= 6 under the
--     skirt, rise <= its cleared airspace) plus the entry step to the street;
--     required plots first, districts one quadrant each, buildings toward
--     the core, fill pieces (fields, orchards, parks) toward the wall;
--  7. wall: the outline as a closed polyline, gatehouses at the gates,
--     turrets about every 64 nodes, walk level as a <= 1/2-per-column
--     profile (walkable on half steps like the streets), bridge-wall
--     (arcade) over water;
--  8. connectors from every road end to its gate (road module routing,
--     profile and raster), pinned to the road's end height and the gate
--     floor; a second road end at the same gate joins the first connector.
--  (9. canal: see `canal` below; dropped first if it grows.)
local M = {}
local floor, ceil, sqrt, abs, min, max = math.floor, math.ceil, math.sqrt, math.abs, math.min, math.max
local atan2, cos, sin, pi = math.atan2, math.cos, math.sin, math.pi
local INF = math.huge

M.DEFAULTS = {
	EXT = 284,            -- sampled half extent (road ends lie up to 272 out)
	G = 2,                -- sample spacing
	HALF = 256,           -- reserved area half width (D59)
	CORE = 48,            -- civic core half width (96 x 96)
	CORE_GATE = 49,       -- core gatehouse radius on the axes
	CORE_KEEP = 52,       -- streets and plots keep this Chebyshev distance
	TARGET_AREA = 100000, -- city footprint target (D70: ~100 k m2 first)
	R_MIN = 110, BAND = 26,   -- outline radius floor; wall-to-reserved-edge band
	NRAY = 180, SMOOTH_PASSES = 4, SMOOTH_W = 4,
	BUDGET_NOISE = 0.3, WALL_BANK = 6,
	C_WET = 4.0, C_STEEP = 2.6, C_BUILD = 1.0,
	BANK = 6, ROUGH = 6,      -- buildable: distance to water >= BANK, relief in a 10-node window <= ROUGH
	GATE_SLIDE = 60, GATE_SLIDE_WET = 2.5,   -- D70: a gate may slide further (x2.5) to avoid water
	GATE_MAX_ANGLE = 0.6, -- ... but never more than ~34 deg off its cardinal ray (gates stay apart)
	RINGS = {0.31, 0.71},     -- ring lanes at these fractions from the core gate radius to the outline
	RING_GUIDE = 1.2, AVENUE_GUIDE = 0.5, AVENUE_GUIDE_MAX = 6, ASSIGN = "capacity",
	CANAL = false, CANAL_OFF = 2, CANAL_HALF = 2, CANAL_DEPTH = 2, CANAL_CLEAR = 12, CANAL_VAR = 3, CANAL_MIN = 60,
	WALL_HALF = 3, WALL_KEEP = 8, TURRET_EVERY = 64, WALL_HEIGHT = 7,
	WALL_SLACK = 1.05,    -- walk slope bound: <= 1/2 node per (node x this)
	GATE_DEPTH = 5, GATE_WIDTH = 7,   -- gatehouse half extents (along / across its axis)
	PLOT_GAP = 2, SETBACK = 1.0, PUSH = 6, APPROACH_MAX = 5, ENTRY_STEP = 2,
	FALL = 6, WET_MARGIN = 2,
	CITY_CELL = 4,
	FINE_R = 272,         -- 2-node sampling inside this radius, 4-node beyond
	SEARCH_BUDGET = 4,    -- a street search gives up beyond this multiple of its straight cost (+400)
	WALL = "stone",       -- "stone" | "palisade" | "open" (planted edge + thresholds)
	-- D70 street pattern: loosened rings, cross-lanes, squares (per capital
	-- and seed from a variation hash, so six capitals do not repeat)
	RING_JITTER = 0.05,   -- ring fractions +- this
	RING2_OPEN = 0.35,    -- share of ring-2 arcs that stop halfway in a square
	CROSS_MEAN = 1.0,     -- cross-lanes ring 1 -> ring 2 per quadrant (0..2)
	SQUARE_P = 0.5,       -- share of avenue/ring crossings that get a small square
	SQUARE_R = 6,         -- square radius (nodes)
	PIN = nil,            -- {district = quadrant-direction {x, z}}: pinned districts
}

-- Edge dimensions per edge kind (D69/D72): wall half thickness, walk height
-- above the ground, gatehouse (or threshold) half extents along and across
-- its axis, turret spacing and radius. `opts` are the planner overrides; the
-- writer (`wp13/city_edge.lua`) reads the rest.
M.EDGE = {
	stone = {half = 3, depth = 5, width = 7, turret = 5,
		opts = {WALL_HALF = 3, WALL_HEIGHT = 7, GATE_DEPTH = 5, GATE_WIDTH = 7}},
	palisade = {half = 2, depth = 4, width = 6, turret = 3,
		opts = {WALL_HALF = 2, WALL_HEIGHT = 5, GATE_DEPTH = 4, GATE_WIDTH = 6,
			TURRET_EVERY = 56}},
	open = {half = 2, depth = 3, width = 5, turret = 0,
		opts = {WALL_HALF = 2, WALL_HEIGHT = 4, GATE_DEPTH = 3, GATE_WIDTH = 5,
			WALL_KEEP = 6}},
}

-- cardinal directions: E, S, W, N (x east, z south; north = -z)
local CARD = {
	{name = "east", dx = 1, dz = 0, ang = 0},
	{name = "south", dx = 0, dz = 1, ang = pi / 2},
	{name = "west", dx = -1, dz = 0, ang = pi},
	{name = "north", dx = 0, dz = -1, ang = -pi / 2},
}
M.CARD = CARD
-- quadrant q lies between avenue q and avenue q % 4 + 1 (SE, SW, NW, NE)
M.QUADRANT_NAMES = {"south-east", "south-west", "north-west", "north-east"}

local function wrap(a)
	while a > pi do a = a - 2 * pi end
	while a < -pi do a = a + 2 * pi end
	return a
end

-- plot rotation: one quarter turn maps local +z to world +x and local +x to
-- world -z (wp13/parts.lua); the entry lies on the local -z edge
function M.rot(x, z, t)
	t = t % 4
	if t == 0 then return x, z end
	if t == 1 then return z + 0, 0 - x end
	if t == 2 then return 0 - x, 0 - z end
	return 0 - z, x + 0 -- 0 - v, never -v: Lua 5.1 keeps a signed zero ("-0" keys)
end
-- world direction the entry (front) of a plot turned t faces
local FRONT = {[0] = {0, -1}, [1] = {-1, 0}, [2] = {0, 1}, [3] = {1, 0}}
M.FRONT = FRONT
function M.rot_bounds(b, t)
	local xs, zs = {}, {}
	for _, c in ipairs({{b.min.x, b.min.z}, {b.max.x, b.min.z}, {b.min.x, b.max.z}, {b.max.x, b.max.z}}) do
		local x, z = M.rot(c[1], c[2], t)
		xs[#xs + 1], zs[#zs + 1] = x, z
	end
	return min(xs[1], xs[2], xs[3], xs[4]), max(xs[1], xs[2], xs[3], xs[4]),
		min(zs[1], zs[2], zs[3], zs[4]), max(zs[1], zs[2], zs[3], zs[4])
end

-- The street parameters: the network's routing, geometry and profile code on
-- a 4-node city grid, with town tunables (D70). The profile rule (<= 1/2 per
-- column), the half widths and the raster are the network's own, so the
-- streets deserialize and rasterize with the road module's sampler.
M.CITY = {
	NOISE_PERIOD = 96, NOISE_AMP = 0.2,
	G0 = 0.2, K_G = 3,                              -- prefer streets gentler than 1:5
	TURN_K = 3, SHARP_TURN = 40, TURN_MAX_DEG = 91, -- no hairpins in town
	RIVER_PAD = 4, C_RIVER = 15, C_RIVER_W = 1,     -- city bridges are normal
	K_PARALLEL = 12,   -- 4-node cells: a street one cell beside another overlaps it
	WIGGLE = 2.5, WIGGLE_PERIOD = 70, WIGGLE_TAPER = 20, WIGGLE_RMIN = 20,
	WIGGLE_ENV = 16, SMOOTH = 4,
	JUNCTION_FLAT = 3, END_FLAT = 4, EDGE_EVERY = 1,
	JUNCTION_GAP = 16, END_GAP = 8,
}
local city_cache = setmetatable({}, {__mode = "k"})
function M.city_roads(roads_module)
	local city = city_cache[roads_module]
	if not city then
		city = roads_module.with_params(M.CITY)
		city_cache[roads_module] = city
	end
	return city
end

local function hash_seed(seed)
	local h = 2166136261
	for i = 1, #seed do
		h = bit.bxor(h, seed:byte(i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

-------------------------------------------------------------------------------
-- plan(seed, I)
--   I.anchor = {id, x, z}; I.sample(x, z) -> t, wy|nil, land (the fitted
--   ground before streets, world coordinates; height.lua fitted_values_at);
--   I.rivers (river polylines); I.simplex;
--   I.road_ends = {{x, z, q (profile level in 1/16), hx, hz (heading into
--   the area), kind, road}}; I.plots = the plot kit ({id, district, kind,
--   bounds, clear_to, required}); I.roads_module = the road module (the
--   planner derives its city parameters, M.city_roads)
-------------------------------------------------------------------------------
function M.plan(seed, I, opt)
	local P = {}
	for k, v in pairs(M.DEFAULTS) do P[k] = v end
	for k, v in pairs(opt or {}) do P[k] = v end
	local T0 = os.clock()
	local st = {t = {}}
	local AX, AZ = I.anchor.x, I.anchor.z
	local EXT, G = P.EXT, P.G
	local NG = floor(2 * EXT / G) + 1
	-- variation stream per capital and seed (street pattern choices): a
	-- deterministic LCG seeded from the seed and the anchor id
	local vstate = hash_seed(tostring(seed) .. ":" .. I.anchor.id)
	local function vrand()
		vstate = (vstate * 1103515245 + 12345) % 2147483648
		return vstate / 2147483648
	end
	do
		local rings = {}
		for i = 1, #P.RINGS do rings[i] = P.RINGS[i] + (2 * vrand() - 1) * P.RING_JITTER end
		P.RINGS = rings
	end
	---------------------------------------------------------------------------
	-- 1. sample grid (local coordinates -EXT..EXT, step G)
	---------------------------------------------------------------------------
	-- inside FINE_R (the largest outline + wall + plot margin) every 2 nodes;
	-- beyond it (the connector band toward the square's corners) every 4
	-- nodes, the odd samples copied from the nearest even one
	local TT, WW, WET = {}, {}, {}
	local FR2 = P.FINE_R * P.FINE_R
	local nsamp = 0
	for pass = 1, 2 do
		for iz = 0, NG - 1 do
			for ix = 0, NG - 1 do
				local k = iz * NG + ix
				local lx, lz = -EXT + ix * G, -EXT + iz * G
				local coarse = lx * lx + lz * lz > FR2
				local even = ix % 2 == 0 and iz % 2 == 0
				if pass == 1 and (not coarse or even) then
					local t, wy, land = I.sample(AX + lx, AZ + lz)
					nsamp = nsamp + 1
					TT[k] = t
					WW[k] = wy or false
					WET[k] = (not land) or (wy ~= nil and wy ~= false and wy > t)
				elseif pass == 2 and coarse and not even then
					local k2 = (iz - iz % 2) * NG + (ix - ix % 2)
					TT[k], WW[k], WET[k] = TT[k2], WW[k2], WET[k2]
				end
			end
		end
	end
	st.samples = nsamp
	st.t.sample = os.clock() - T0
	local function gk(lx, lz)
		local ix, iz = floor((lx + EXT) / G + 0.5), floor((lz + EXT) / G + 0.5)
		if ix < 0 then ix = 0 elseif ix >= NG then ix = NG - 1 end
		if iz < 0 then iz = 0 elseif iz >= NG then iz = NG - 1 end
		return iz * NG + ix
	end
	local function t_at(lx, lz) return TT[gk(lx, lz)] end
	local function wet_at(lx, lz) return WET[gk(lx, lz)] end
	---------------------------------------------------------------------------
	-- 2. masks: distance to water (chamfer, nodes), relief, buildable
	---------------------------------------------------------------------------
	local T1 = os.clock()
	local DW = {}
	for k = 0, NG * NG - 1 do DW[k] = WET[k] and 0 or INF end
	local S2 = sqrt(2) * G
	for iz = 0, NG - 1 do
		for ix = 0, NG - 1 do
			local k = iz * NG + ix
			local d = DW[k]
			if ix > 0 then d = min(d, DW[k - 1] + G) end
			if iz > 0 then
				d = min(d, DW[k - NG] + G)
				if ix > 0 then d = min(d, DW[k - NG - 1] + S2) end
				if ix < NG - 1 then d = min(d, DW[k - NG + 1] + S2) end
			end
			DW[k] = d
		end
	end
	for iz = NG - 1, 0, -1 do
		for ix = NG - 1, 0, -1 do
			local k = iz * NG + ix
			local d = DW[k]
			if ix < NG - 1 then d = min(d, DW[k + 1] + G) end
			if iz < NG - 1 then
				d = min(d, DW[k + NG] + G)
				if ix < NG - 1 then d = min(d, DW[k + NG + 1] + S2) end
				if ix > 0 then d = min(d, DW[k + NG - 1] + S2) end
			end
			DW[k] = d
		end
	end
	-- relief: max - min over a 5x5 sample window (10 nodes), separable
	local RMX, RMN = {}, {}
	for iz = 0, NG - 1 do
		for ix = 0, NG - 1 do
			local a, b = INF, -INF
			for dx = -2, 2 do
				local jx = ix + dx
				if jx >= 0 and jx < NG then
					local t = TT[iz * NG + jx]
					if t < a then a = t end
					if t > b then b = t end
				end
			end
			RMN[iz * NG + ix], RMX[iz * NG + ix] = a, b
		end
	end
	local ROUGH, BUILD = {}, {}
	local CK = P.CORE_KEEP
	for iz = 0, NG - 1 do
		for ix = 0, NG - 1 do
			local a, b = INF, -INF
			for dz = -2, 2 do
				local jz = iz + dz
				if jz >= 0 and jz < NG then
					local k = jz * NG + ix
					if RMN[k] < a then a = RMN[k] end
					if RMX[k] > b then b = RMX[k] end
				end
			end
			local k = iz * NG + ix
			ROUGH[k] = b - a
			local lx, lz = -EXT + ix * G, -EXT + iz * G
			BUILD[k] = not WET[k] and DW[k] >= P.BANK and ROUGH[k] <= P.ROUGH and
				max(abs(lx), abs(lz)) > CK
		end
	end
	st.t.masks = os.clock() - T1
	---------------------------------------------------------------------------
	-- 3. outline r(phi)
	---------------------------------------------------------------------------
	local T2 = os.clock()
	local NR = P.NRAY
	local noise = I.simplex(seed, "capital_outline")
	local RAYS = {}
	local rmax = {}
	for a = 1, NR do
		local phi = (a - 1) * 2 * pi / NR - pi
		local c, s = cos(phi), sin(phi)
		local m = max(abs(c), abs(s))
		local s0 = P.CORE / m
		rmax[a] = min((P.HALF - P.BAND) / m, 260)
		local cum, rr = {}, {}
		local acc = 0
		local r = s0
		while r <= rmax[a] + 2 do
			local k = gk(r * c, r * s)
			local w = WET[k] and P.C_WET or (BUILD[k] and P.C_BUILD or P.C_STEEP)
			acc = acc + w * G
			cum[#cum + 1], rr[#rr + 1] = acc, r
			r = r + G
		end
		local nz = 0.7 * noise(c * 1.6, s * 1.6) + 0.3 * noise(c * 4 + 7, s * 4 - 3)
		RAYS[a] = {phi = phi, c = c, s = s, s0 = s0, cum = cum, r = rr, f = 1 + P.BUDGET_NOISE * nz}
	end
	local function outline_for(B)
		local R = {}
		for a = 1, NR do
			local ray = RAYS[a]
			local lim = B * ray.f
			local r = ray.r[#ray.r]
			for j = 1, #ray.cum do
				if ray.cum[j] >= lim then r = ray.r[j] break end
			end
			R[a] = r
		end
		for _ = 1, P.SMOOTH_PASSES do
			local S = {}
			for a = 1, NR do
				local acc = 0
				for d = -P.SMOOTH_W, P.SMOOTH_W do acc = acc + R[(a - 1 + d) % NR + 1] end
				S[a] = acc / (2 * P.SMOOTH_W + 1)
			end
			R = S
		end
		for a = 1, NR do R[a] = max(P.R_MIN, min(rmax[a], R[a])) end
		-- the wall keeps off banks: a ray whose outline point lies within
		-- WALL_BANK of water moves to the nearest point that does not
		-- (inward first on ties, within 40), then one light smoothing pass.
		-- Where a river crosses the outline the neighbouring rays snap to
		-- opposite banks and the wall crosses it short (an arcade).
		for _ = 1, (P.WALL_BANK > 0 and 3 or 0) do
			for a = 1, NR do
				local ray = RAYS[a]
				local function bad(r) return DW[gk(r * ray.c, r * ray.s)] < P.WALL_BANK end
				if bad(R[a]) then
					for d = 2, 40, 2 do
						local ri, ro = R[a] - d, R[a] + d
						if ri >= P.R_MIN and not bad(ri) then R[a] = ri break end
						if ro <= rmax[a] and not bad(ro) then R[a] = ro break end
					end
				end
			end
			local S = {}
			for a = 1, NR do
				S[a] = 0.25 * R[(a - 2) % NR + 1] + 0.5 * R[a] + 0.25 * R[a % NR + 1]
			end
			R = S
		end
		local area = 0
		for a = 1, NR do
			area = area + 0.5 * R[a] * R[a] * 2 * pi / NR
		end
		return R, area
	end
	local lo, hi = 20, 1200
	local R, area
	for _ = 1, 40 do
		local mid = 0.5 * (lo + hi)
		R, area = outline_for(mid)
		if area < P.TARGET_AREA then lo = mid else hi = mid end
	end
	st.budget = 0.5 * (lo + hi)
	R, area = outline_for(st.budget)
	st.area = area
	-- r(phi) by linear interpolation between rays
	local function r_at(phi)
		local u = (wrap(phi) + pi) / (2 * pi) * NR
		local a = floor(u)
		local f = u - a
		local r1, r2 = R[a % NR + 1], R[(a + 1) % NR + 1]
		return r1 + (r2 - r1) * f
	end
	local function inside(lx, lz, margin)
		local r = sqrt(lx * lx + lz * lz)
		return r <= r_at(atan2(lz, lx)) - (margin or 0)
	end
	st.t.outline = os.clock() - T2
	---------------------------------------------------------------------------
	-- 4. gates
	---------------------------------------------------------------------------
	local T3 = os.clock()
	local ends = {}
	for _, e in ipairs(I.road_ends or {}) do
		ends[#ends + 1] = {x = e.x - AX, z = e.z - AZ, q = e.q, hx = e.hx, hz = e.hz,
			kind = e.kind, road = e.road}
	end
	local gates = {}
	for c = 1, 4 do
		local phi = CARD[c].ang
		gates[c] = {c = c, name = CARD[c].name, dx = CARD[c].dx, dz = CARD[c].dz, phi = phi, ends = {}}
	end
	local function place_gate(g, phi)
		local r = r_at(phi)
		g.phi, g.r = phi, r
		g.x, g.z = r * cos(phi), r * sin(phi)
		g.ox, g.oz = g.x + g.dx * (P.GATE_DEPTH + 3), g.z + g.dz * (P.GATE_DEPTH + 3)
		g.ix, g.iz = g.x - g.dx * (P.GATE_DEPTH + 3), g.z - g.dz * (P.GATE_DEPTH + 3)
	end
	for _, g in ipairs(gates) do place_gate(g, g.phi) end
	for pass = 1, 2 do
		for _, g in ipairs(gates) do g.ends = {} end
		for _, e in ipairs(ends) do
			local best, bd
			for _, g in ipairs(gates) do
				local d = sqrt((e.x - g.ox) ^ 2 + (e.z - g.oz) ^ 2)
				if not bd or d < bd then best, bd = g, d end
			end
			e.gate = best.c
			best.ends[#best.ends + 1] = e
		end
		for _, g in ipairs(gates) do
			local base = CARD[g.c].ang
			local phi = base
			if #g.ends > 0 then
				local sx, sz = 0, 0
				for _, e in ipairs(g.ends) do
					local a = atan2(e.z, e.x)
					sx, sz = sx + cos(a), sz + sin(a)
				end
				local d = wrap(atan2(sz, sx) - base)
				local lim = P.GATE_SLIDE / r_at(base)
				phi = base + max(-lim, min(lim, d))
			end
			-- a gate stands on dry ground: nearest dry position within the
			-- slide (widened by half when nothing is dry); otherwise a bridge
			-- gate (floor above the water, see below)
			local best, bd
			local lim = P.GATE_SLIDE / r_at(base)
			local rb = r_at(base)
			for step = 0, floor(2 * P.GATE_SLIDE_WET * P.GATE_SLIDE) do
				for _, sg in ipairs({1, -1}) do
					local p2 = phi + sg * step / rb
					if abs(wrap(p2 - base)) <= min(P.GATE_SLIDE_WET * lim, P.GATE_MAX_ANGLE) then
						local r = r_at(p2)
						local ok = true
						for dd = -P.GATE_DEPTH - 20, P.GATE_DEPTH + 10, 1 do
							for ww = -P.GATE_WIDTH, P.GATE_WIDTH, 1 do
								local x = r * cos(p2) + g.dx * dd - g.dz * ww
								local z = r * sin(p2) + g.dz * dd + g.dx * ww
								if wet_at(x, z) then ok = false end
							end
						end
						if ok and not best then best = p2 end
					end
				end
				if best then break end
			end
			g.dry = best ~= nil
			place_gate(g, best or phi)
		end
	end
	-- gate floor: the median ground under the gatehouse
	for _, g in ipairs(gates) do
		local vals = {}
		local wmax
		for dd = -P.GATE_DEPTH, P.GATE_DEPTH, 2 do
			for ww = -P.GATE_WIDTH + 1, P.GATE_WIDTH - 1, 2 do
				local k = gk(g.x + g.dx * dd - g.dz * ww, g.z + g.dz * dd + g.dx * ww)
				vals[#vals + 1] = TT[k]
				if WET[k] and WW[k] then wmax = max(wmax or -INF, WW[k]) end
			end
		end
		table.sort(vals)
		g.y = vals[floor((#vals + 1) / 2)]
		-- a gate over water (no dry spot within the slide) is a bridge gate
		if wmax and g.y < wmax + 2 then g.y, g.bridge = floor(wmax + 2), true end
		g.slide = g.r * wrap(g.phi - CARD[g.c].ang)
	end
	st.t.gates = os.clock() - T3
	---------------------------------------------------------------------------
	-- 5. streets: the road module's kit on a 4-node city grid
	---------------------------------------------------------------------------
	local T4 = os.clock()
	local C = P.CITY_CELL
	local gx0 = -EXT
	local gn = floor(2 * EXT / C) + 1
	local gh, gl = {}, {}
	for iz = 0, gn - 1 do
		for ix = 0, gn - 1 do
			local lx, lz = gx0 + ix * C, gx0 + iz * C
			local k = gk(lx, lz)
			gh[iz * gn + ix] = TT[k]
			gl[iz * gn + ix] = true
		end
	end
	local grid = {nx = gn, nz = gn, cell = C, x0 = AX + gx0, z0 = AZ + gx0, height = gh, land = gl}
	local city = M.city_roads(I.roads_module)
	local Q = city.P.Q
	local kit = city.build(seed, {
		kit = true, grid = grid, rivers = I.rivers, simplex = I.simplex, nodes = {},
		terrain_at = function(x, z) local t = I.sample(x, z) return t end,
		water_at = function(x, z) local t, wy = I.sample(x, z) return (wy and wy > t) and wy or nil end,
		blocked = function(x, z)
			local lx, lz = x - AX, z - AZ
			return max(abs(lx), abs(lz)) <= CK
		end,
		cell_cost = function(x, z)
			return wet_at(x - AX, z - AZ) and 10 or 0
		end,
	})
	local LI, KOF = kit.LI, kit.KOF
	local function cell_li(lx, lz)
		local k = kit.cell_of(AX + lx, AZ + lz)
		return k and LI[k] or nil
	end
	local function li_local(li)
		local x, z = kit.li_xz(li)
		return x - AX, z - AZ
	end
	local function dir_index(dx, dz)
		local best, bd
		for d, D in ipairs(kit.DIRS) do
			local v = D.ux * dx + D.uz * dz
			if not bd or v > bd then best, bd = d, v end
		end
		return best
	end
	-- guide tables
	local NLc = kit.NL
	local function guide_for(fn)
		local g = {}
		for li = 1, NLc do
			local lx, lz = li_local(li)
			local v = fn(lx, lz)
			if v and v > 0 then g[li] = v end
		end
		return g
	end
	local function outside_cost(lx, lz, margin, k)
		local r = sqrt(lx * lx + lz * lz)
		local ro = r_at(atan2(lz, lx)) - margin
		if r > ro then return k * (1 + (r - ro) / 4) end
		return 0
	end
	local streets = {}      -- ordered list of {road, role, quadrant(s)}
	local function route(src_li, src_dir, target, heur_xz, guide)
		kit.set_guide(guide)
		local tx, tz = heur_xz[1], heur_xz[2]
		local mm = kit.minmult
		local sx, sz = li_local(src_li)
		local budget = P.SEARCH_BUDGET * sqrt((sx - tx) ^ 2 + (sz - tz) ^ 2) + 400
		local path, info = kit.search({{src_li, src_dir, 0}}, target, function(li)
			local x, z = li_local(li)
			return sqrt((x - tx) ^ 2 + (z - tz) ^ 2) * mm
		end, nil, budget)
		kit.set_guide(nil)
		return path, info
	end
	local function ctrl_from(path, head, tail)
		local ctrl = {}
		for _, p in ipairs(head) do ctrl[#ctrl + 1] = {AX + p[1], AZ + p[2]} end
		for i = 2, #path - 1 do
			local x, z = kit.li_xz(path[i])
			ctrl[#ctrl + 1] = {x, z}
		end
		for _, p in ipairs(tail) do ctrl[#ctrl + 1] = {AX + p[1], AZ + p[2]} end
		return ctrl
	end
	-- 5a. avenues: core gate -> through the city gate to its outer point
	local avenues = {}
	local core_y = t_at(0, 0)
	for c = 1, 4 do
		local g = gates[c]
		local dx, dz = g.dx, g.dz
		local a0 = {dx * (P.CORE_GATE + 1), dz * (P.CORE_GATE + 1)}
		local a1 = {dx * (CK + 8), dz * (CK + 8)}
		local b1 = {g.ix - dx * 8, g.iz - dz * 8}
		local src = cell_li(a1[1] + dx * C, a1[2] + dz * C)
		local tgt = cell_li(b1[1], b1[2])
		-- inside the outline, and a mild pull toward the straight line core
		-- gate -> city gate (avenues bend with the terrain, never detour)
		local vx, vz = b1[1] - a1[1], b1[2] - a1[2]
		local l2 = vx * vx + vz * vz
		local guide = guide_for(function(lx, lz)
			local u = max(0, min(1, ((lx - a1[1]) * vx + (lz - a1[2]) * vz) / l2))
			local d = sqrt((lx - a1[1] - u * vx) ^ 2 + (lz - a1[2] - u * vz) ^ 2)
			return outside_cost(lx, lz, 10, 4) + min(P.AVENUE_GUIDE_MAX, P.AVENUE_GUIDE * (d / 16) ^ 2)
		end)
		local path = route(src, dir_index(dx, dz), function(li, d)
			if li == tgt then return {kind = "node"} end
		end, b1, guide)
		local ctrl
		if path then
			ctrl = ctrl_from(path, {a0, a1}, {b1, {g.ix, g.iz}, {g.x, g.z}, {g.ox, g.oz}})
		else
			st.failed = (st.failed or 0) + 1
			ctrl = {{AX + a0[1], AZ + a0[2]}, {AX + g.x, AZ + g.z}, {AX + g.ox, AZ + g.oz}}
		end
		local road = kit.street("avenue", ctrl, {a = "core_" .. g.name, b = "gate_" .. g.name,
			pin_a = floor(core_y * Q + 0.5) / Q, flat_a = 6,
			-- the gate end is flat through the passage but not pinned: the
			-- gate floor takes the avenue's level (set after the final solve)
			flat_b = 2 * P.GATE_DEPTH + 10})
		kit.commit(road)
		road.role, road.gate = "avenue", c
		avenues[c] = road
		streets[#streets + 1] = road
	end
	-- 5b. ring lanes: per quadrant an arc from avenue q to avenue q+1
	local function ring_r(frac, phi)
		return P.CORE_GATE + frac * (r_at(phi) - P.CORE_GATE)
	end
	local function avenue_index_at(road, frac)
		-- first centreline point whose radius reaches the ring
		local best
		for i = 1, #road.X do
			local lx, lz = road.X[i] - AX, road.Z[i] - AZ
			if sqrt(lx * lx + lz * lz) >= ring_r(frac, atan2(lz, lx)) then best = i break end
		end
		best = best or floor(#road.X / 2)
		-- a junction needs dry, ground-supported parent points around it
		-- (not on a bridge or a deck): the nearest such index within 40
		local function ok(i)
			for j = max(1, i - 10), min(#road.X, i + 10) do
				if road.cls[j] ~= "G" then return false end
				if wet_at(road.X[j] - AX, road.Z[j] - AZ) then return false end
				local lx, lz = road.X[j] - AX, road.Z[j] - AZ
				if DW[gk(lx, lz)] < 6 then return false end
			end
			return true
		end
		for d = 0, 40 do
			if best + d <= #road.X - 12 and ok(best + d) then return best + d end
			if best - d >= 12 and ok(best - d) then return best - d end
		end
		st.junction_wet = (st.junction_wet or 0) + 1
		return best
	end
	local rings = {}
	local squares = {}       -- {x, z, road, idx | y, why}: flat paved squares
	local function add_square(road, idx, why)
		local x, z = road.X[idx] - AX, road.Z[idx] - AZ
		for _, q in ipairs(squares) do
			if (q.x - x) ^ 2 + (q.z - z) ^ 2 < 14 * 14 then return end
		end
		squares[#squares + 1] = {x = x, z = z, road = road, idx = idx, why = why}
	end
	-- a lane from `src` (li, heading) to a target set on `B` (road) or to a
	-- single dead-end cell; returns the committed street or nil
	local function lane_to(src, sdir, head, target_road, tset, tcell, guide, f, heur_pt)
		local path = src and route(src, sdir, function(li, d)
			if tcell and li == tcell then return {kind = "node"} end
			if tset and tset[li] then
				local i = tset[li]
				local B = target_road
				local px, pz = B.X[min(#B.X, i + 3)] - B.X[max(1, i - 3)], B.Z[min(#B.X, i + 3)] - B.Z[max(1, i - 3)]
				local lp = sqrt(px * px + pz * pz)
				local D = kit.DIRS[d]
				if lp > 0 and abs(px * D.ux + pz * D.uz) / lp <= 0.8 then return {kind = "road", idx = i} end
			end
		end, heur_pt, guide)
		if not path then return nil end
		local last = path[#path]
		local ctrl = ctrl_from(path, head, {})
		local ex, ez = kit.li_xz(last)
		ctrl[#ctrl + 1] = {ex, ez}
		local ff = {}
		for k, v in pairs(f) do ff[k] = v end
		if not (tset and tset[last]) then ff.b_parent = nil; ff.flat_b = ff.flat_b or 8 end
		local road = kit.street("lane", ctrl, ff)
		-- a lane whose profile has no feasible solution (e.g. its mouth
		-- in water) is not built; the caller tries its next option
		if road.cost == math.huge then
			st.lanes_rejected = (st.lanes_rejected or 0) + 1
			return nil
		end
		-- its mouths (flat, pinned to the parent) must be dry: a later
		-- junction can move the parent's level there
		do
			local n = #road.X
			for _, i in ipairs({1, 3, 5, 7, 9, 11, 13, 15, n - 14, n - 12, n - 10, n - 8, n - 6, n - 4, n - 2, n}) do
				if i >= 1 and i <= n then
					local k = gk(road.X[i] - AX, road.Z[i] - AZ)
					if WET[k] or DW[k] < 3 then
						st.lanes_rejected = (st.lanes_rejected or 0) + 1
						st.lanes_wet_mouth = (st.lanes_wet_mouth or 0) + 1
						return nil
					end
				end
			end
		end
		-- a lane must not run alongside another street (their surfaces
		-- would touch at different levels): away from its two junction
		-- mouths no point may come within the two half widths + 1.5 of
		-- another street's centreline
		do
			local n = #road.X
			for _, o in ipairs(streets) do
				local lim = road.hw + o.hw + 1.5
				local lim2 = lim * lim
				for i = 14, n - 14, 2 do
					local x, z = road.X[i], road.Z[i]
					for j = 1, #o.X, 2 do
						local dx, dz = o.X[j] - x, o.Z[j] - z
						if dx * dx + dz * dz < lim2 then
							st.lanes_rejected = (st.lanes_rejected or 0) + 1
							st.lanes_overlap = (st.lanes_overlap or 0) + 1
							return nil
						end
					end
				end
			end
		end
		kit.commit(road)
		road.dead_end = ff.b_parent == nil
		return road
	end
	local function unit_normal_toward(A, ia, px, pz)
		local tx, tz = A.X[min(#A.X, ia + 3)] - A.X[max(1, ia - 3)], A.Z[min(#A.X, ia + 3)] - A.Z[max(1, ia - 3)]
		local l = sqrt(tx * tx + tz * tz)
		tx, tz = tx / l, tz / l
		local nx_, nz_ = -tz, tx
		if nx_ * px + nz_ * pz < 0 then nx_, nz_ = -nx_, -nz_ end
		return nx_, nz_
	end
	local nopen = 0
	for ri, frac in ipairs(P.RINGS) do
		for q = 1, 4 do
			local road
			-- D70: some outer arcs stop halfway in a small square
			local open = ri == #P.RINGS and nopen < 2 and vrand() < P.RING2_OPEN
			local from_b = vrand() < 0.5
			local u_end = 0.45 + 0.2 * vrand()
			-- attempts: A -> B; B -> A; A -> B with a wider target window;
			-- a chosen open arc comes first and falls back to a closed one;
			-- a closed arc that finds no route falls back to open arcs
			-- (dead ends in a square) from either side
			local modes = {{false, false, 10}, {false, true, 10}, {false, false, 30}}
			if open then table.insert(modes, 1, {true, from_b, 10})
			else modes[#modes + 1] = {true, false, 10}; modes[#modes + 1] = {true, true, 10} end
			for attempt, mode in ipairs(modes) do
				local A, B = avenues[q], avenues[q % 4 + 1]
				local is_open = mode[1]
				if mode[2] then A, B = B, A end
				local span = mode[3]
				local ia, ib = avenue_index_at(A, frac), avenue_index_at(B, frac)
				local ax, az = A.X[ia] - AX, A.Z[ia] - AZ
				local bx, bz = B.X[ib] - AX, B.Z[ib] - AZ
				local nx_, nz_ = unit_normal_toward(A, ia, bx - ax, bz - az)
				local s1 = {ax + nx_ * 10, az + nz_ * 10}
				local src = cell_li(s1[1], s1[2])
				local phi_a, phi_b = atan2(az, ax), atan2(bz, bx)
				local guide = guide_for(function(lx, lz)
					local r = sqrt(lx * lx + lz * lz)
					local phi = atan2(lz, lx)
					local u = wrap(phi - phi_a) / wrap(phi_b - phi_a)
					local g = outside_cost(lx, lz, 14, 10)
					if u < -0.05 or u > 1.05 then g = g + 20 end
					local dr = (r - ring_r(frac, phi)) / 10
					return g + min(8, P.RING_GUIDE * dr * dr)
				end)
				if is_open then
					local pt = phi_a + u_end * wrap(phi_b - phi_a)
					local rt = ring_r(frac, pt)
					local tx, tz = rt * cos(pt), rt * sin(pt)
					local tcell = cell_li(tx, tz)
					if tcell and not wet_at(tx, tz) and DW[gk(tx, tz)] >= 6 then
						road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, nil, nil, tcell, guide,
							{a_parent = A.id}, {tx, tz})
					end
					if road then
						nopen = nopen + 1
						if not open then st.open_fallback = (st.open_fallback or 0) + 1 end
						add_square(road, #road.X, "lane end")
						add_square(A, ia, "crossing")
						road.open = true
						break
					end
				else
					local tset = {}
					for i = max(12, ib - span), min(#B.X - 12, ib + span) do
						local li = cell_li(B.X[i] - AX, B.Z[i] - AZ)
						if li then tset[li] = i end
					end
					road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, B, tset, nil, guide,
						{a_parent = A.id, b_parent = B.id}, {bx, bz})
					if road then
						if attempt > 1 then st.ring_retries = (st.ring_retries or 0) + 1 end
						if vrand() < P.SQUARE_P then add_square(A, ia, "crossing") end
						if vrand() < P.SQUARE_P then add_square(B, road.parent_idx, "crossing") end
						break
					end
				end
			end
			if not road then
				st.failed = (st.failed or 0) + 1
				st.no_route = (st.no_route or "") .. (" ring%d/q%d"):format(ri, q)
			end
			if road then
				road.role, road.quadrant, road.ring = "ring" .. ri, q, ri
				rings[#rings + 1] = road
				streets[#streets + 1] = road
			end
		end
	end
	st.open_arcs = nopen
	-- D70 cross-lanes: ring 1 -> ring 2 (or a dead end with a square where
	-- ring 2 is open), 0..2 per quadrant
	local ncross = 0
	for q = 1, 4 do
		local r1, r2s
		for _, r in ipairs(rings) do
			if r.quadrant == q and r.ring == 1 then r1 = r end
		end
		r2s = {}
		for _, r in ipairs(rings) do
			if r.quadrant == q and r.ring == #P.RINGS then r2s[#r2s + 1] = r end
		end
		local v = vrand()
		local n = v < 0.25 and 0 or (v < 0.8 and 1 or 2)
		n = min(2, floor(n * P.CROSS_MEAN + 0.5))
		for k = 1, (r1 and n or 0) do
			local u = n == 1 and (0.35 + 0.3 * vrand()) or (k == 1 and 0.28 + 0.1 * vrand() or 0.62 + 0.1 * vrand())
			local i1 = max(20, min(#r1.X - 20, floor(u * #r1.X + 0.5)))
			local ok = true
			for _, j in ipairs(r1.junctions) do if abs(j.idx - i1) < 18 then ok = false end end
			if ok then
				local ax, az = r1.X[i1] - AX, r1.Z[i1] - AZ
				local nx_, nz_ = unit_normal_toward(r1, i1, ax, az)   -- outward
				local s1 = {ax + nx_ * 8, az + nz_ * 8}
				local src = cell_li(s1[1], s1[2])
				local phi_u = atan2(az, ax)
				local r2f = P.RINGS[#P.RINGS]
				local guide = guide_for(function(lx, lz)
					local r = sqrt(lx * lx + lz * lz)
					local dphi = wrap(atan2(lz, lx) - phi_u)
					local g = outside_cost(lx, lz, 14, 10)
					return g + min(10, 1.5 * (dphi * r / 12) ^ 2)
				end)
				local tset, B = {}, nil
				for _, r2 in ipairs(r2s) do
					for i = 12, #r2.X - 12 do
						local near = false
						for _, j in ipairs(r2.junctions) do if abs(j.idx - i) < 16 then near = true end end
						if not near then
							local lx, lz = r2.X[i] - AX, r2.Z[i] - AZ
							if abs(wrap(atan2(lz, lx) - phi_u)) < 0.25 then
								local li = cell_li(lx, lz)
								if li then tset[li] = i; B = r2 end
							end
						end
					end
				end
				local rt = ring_r(r2f, phi_u)
				local tx, tz = rt * cos(phi_u), rt * sin(phi_u)
				local road
				if B then
					road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, B, tset, nil, guide,
						{a_parent = r1.id, b_parent = B.id}, {tx, tz})
				end
				if not road then
					-- dead end: halfway out, ending in a square
					local rd = 0.5 * (ring_r(P.RINGS[1], phi_u) + rt)
					local dx, dz = rd * cos(phi_u), rd * sin(phi_u)
					local tcell = cell_li(dx, dz)
					if tcell and not wet_at(dx, dz) then
						road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, nil, nil, tcell, guide,
							{a_parent = r1.id}, {dx, dz})
					end
				end
				if road then
					ncross = ncross + 1
					road.role, road.quadrant = "cross", q
					streets[#streets + 1] = road
					if road.dead_end then add_square(road, #road.X, "lane end")
					elseif vrand() < P.SQUARE_P then add_square(road, #road.X, "crossing") end
				end
			end
		end
	end
	st.cross_lanes = ncross
	st.t.streets = os.clock() - T4
	---------------------------------------------------------------------------
	-- occupancy raster (1 node): streets, core, wall band, gatehouses
	---------------------------------------------------------------------------
	local T5 = os.clock()
	local ON = 2 * EXT + 1
	local OCC = {}          -- key -> "s" street, "c" core, "w" wall, "g" gate, plot index
	local function ok_(lx, lz) return lx >= -EXT and lx <= EXT and lz >= -EXT and lz <= EXT end
	local function okey(lx, lz) return (lz + EXT) * ON + (lx + EXT) end
	-- street corridors: every column within hw + 1 of a centreline segment
	local SD = {}           -- key -> {road id, point index, distance - hw}
	local function mark_street(road, extra)
		local X, Z, hw = road.X, road.Z, road.hw
		local reach = hw + extra
		for i = 1, #X - 1 do
			local ax, az = X[i] - AX, Z[i] - AZ
			local bx, bz = X[i + 1] - AX, Z[i + 1] - AZ
			local vx, vz = bx - ax, bz - az
			local l2 = vx * vx + vz * vz
			for lz = floor(min(az, bz) - reach), ceil(max(az, bz) + reach) do
				for lx = floor(min(ax, bx) - reach), ceil(max(ax, bx) + reach) do
					if ok_(lx, lz) then
						local u = l2 > 0 and ((lx - ax) * vx + (lz - az) * vz) / l2 or 0
						if u < 0 then u = 0 elseif u > 1 then u = 1 end
						local d = sqrt((lx - ax - u * vx) ^ 2 + (lz - az - u * vz) ^ 2) - hw
						if d <= extra then
							local k = okey(lx, lz)
							local cur = SD[k]
							if not cur or d < cur[3] then SD[k] = {road.id, u < 0.5 and i or i + 1, d} end
						end
					end
				end
			end
		end
	end
	for _, r in ipairs(streets) do mark_street(r, 8) end
	for lz = -CK, CK do for lx = -CK, CK do OCC[okey(lx, lz)] = "c" end end
	-- wall polyline (closed), gatehouse boxes
	local wall = {pts = {}}
	do
		local pts = {}
		for a = 1, NR do
			local ray = RAYS[a]
			pts[#pts + 1] = {R[a] * ray.c, R[a] * ray.s}
		end
		-- resample the closed ring every ~2 nodes
		local out = {}
		for i = 1, #pts do
			local p, q2 = pts[i], pts[i % #pts + 1]
			local L = sqrt((q2[1] - p[1]) ^ 2 + (q2[2] - p[2]) ^ 2)
			local n = max(1, floor(L / 2 + 0.5))
			for j = 0, n - 1 do
				out[#out + 1] = {p[1] + (q2[1] - p[1]) * j / n, p[2] + (q2[2] - p[2]) * j / n}
			end
		end
		wall.pts = out
	end
	-- gatehouse boxes
	for _, g in ipairs(gates) do
		g.box = {}
		for dd = -P.GATE_DEPTH, P.GATE_DEPTH do
			for ww = -P.GATE_WIDTH, P.GATE_WIDTH do
				local lx = floor(g.x + g.dx * dd - g.dz * ww + 0.5)
				local lz = floor(g.z + g.dz * dd + g.dx * ww + 0.5)
				if ok_(lx, lz) then OCC[okey(lx, lz)] = "g" end
			end
		end
	end
	-- wall band and gate gaps; walk profile (<= 1 per step), arcade over water
	do
		local pts = wall.pts
		local n = #pts
		local s = {0}
		for i = 2, n do s[i] = s[i - 1] + sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
		wall.length = s[n] + sqrt((pts[1][1] - pts[n][1]) ^ 2 + (pts[1][2] - pts[n][2]) ^ 2)
		local gap = {}
		for i = 1, n do
			local p = pts[i]
			for _, g in ipairs(gates) do
				-- inside the gatehouse box (+1): the wall stops at its sides
				local dd = (p[1] - g.x) * g.dx + (p[2] - g.z) * g.dz
				local ww = -(p[1] - g.x) * g.dz + (p[2] - g.z) * g.dx
				if abs(dd) <= P.GATE_DEPTH + 2 and abs(ww) <= P.GATE_WIDTH then gap[i] = g.c end
			end
		end
		-- walk level: ground + height, then limited to 1/2 per node both ways
		local walk, wetp = {}, {}
		for i = 1, n do
			walk[i] = t_at(pts[i][1], pts[i][2]) + P.WALL_HEIGHT
			wetp[i] = wet_at(pts[i][1], pts[i][2])
		end
		-- over water the walk bridges: take the neighbours' level
		for _ = 1, 3 do
			for i = 1, n do
				local a, b = walk[(i - 2) % n + 1], walk[i % n + 1]
				if wetp[i] then walk[i] = max(walk[i], 0.5 * (a + b)) end
			end
		end
		-- The walk in half nodes, raised (never lowered) until it changes by
		-- at most 1/2 node per node along the closed loop, with 5 % slack for
		-- the inner edge of a curve: the writer interpolates it per column and
		-- rounds to half steps, so neighbouring walk columns differ by at most
		-- a slab and the walk is walked without jumping (like the streets).
		local seg = {}
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			seg[i] = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		end
		for i = 1, n do walk[i] = ceil(2 * walk[i]) end
		local changed = true
		while changed do
			changed = false
			for i = 1, n do
				local j = i % n + 1
				local lim = floor(seg[i] / P.WALL_SLACK)
				if walk[j] < walk[i] - lim then walk[j] = walk[i] - lim; changed = true end
				if walk[i] < walk[j] - lim then walk[i] = walk[j] - lim; changed = true end
			end
		end
		wall.walk, wall.wet, wall.gap, wall.s = walk, wetp, gap, s
		-- turrets about every TURRET_EVERY along the wall, not at gates
		local turrets = {}
		local nextt = P.TURRET_EVERY / 2
		for i = 1, n do
			if s[i] >= nextt then
				local near_gate = false
				for j = max(1, i - 8), min(n, i + 8) do if gap[j] then near_gate = true end end
				if not near_gate then
					turrets[#turrets + 1] = {x = pts[i][1], z = pts[i][2], i = i}
					nextt = s[i] + P.TURRET_EVERY
				end
			end
		end
		if P.WALL == "open" then turrets = {} end
		wall.turrets, wall.kind = turrets, P.WALL
		local nwet = 0
		for i = 1, n do if wetp[i] and not gap[i] then nwet = nwet + 1 end end
		wall.arcade_points = nwet
		-- mark the band (half thickness + keep) as occupied for plots
		for i = 1, n do
			if not gap[i] then
				local p = pts[i]
				local reach = P.WALL_HALF + 1
				for lz = floor(p[2] - reach), ceil(p[2] + reach) do
					for lx = floor(p[1] - reach), ceil(p[1] + reach) do
						if ok_(lx, lz) and (lx - p[1]) ^ 2 + (lz - p[2]) ^ 2 <= reach * reach then
							local k = okey(lx, lz)
							if not OCC[k] then OCC[k] = "w" end
						end
					end
				end
			end
		end
	end
	st.t.wall = os.clock() - T5
	---------------------------------------------------------------------------
	-- 9. canal (D58), kept minimal and dropped first if it grows: one canal
	-- system of one water level, beside a ring-2 lane (a quay canal CANAL_OFF
	-- out from the lane's outer edge), on the longest stretch that is clear
	-- of natural water (>= CANAL_CLEAR), inside the wall and whose ground
	-- varies <= CANAL_VAR. Level = lowest bank ground - 1, so it spills
	-- nowhere and needs no raised rims; trough CANAL_DEPTH deep; closed ends
	-- (not connected to world water). Emitted as a polyline + level (the
	-- water rows of water_authored.lua would take it as a capsule chain).
	---------------------------------------------------------------------------
	local canal
	if P.CANAL then
		local Tc = os.clock()
		local best
		for _, road in ipairs(rings) do
			if road.ring == #P.RINGS then
				local X, Z, n = road.X, road.Z, #road.X
				local pts, g, okp = {}, {}, {}
				for i = 1, n do
					local tx, tz = X[min(n, i + 3)] - X[max(1, i - 3)], Z[min(n, i + 3)] - Z[max(1, i - 3)]
					local l = sqrt(tx * tx + tz * tz)
					local nx_, nz_ = -tz / l, tx / l
					local lx, lz = X[i] - AX, Z[i] - AZ
					if nx_ * lx + nz_ * lz < 0 then nx_, nz_ = -nx_, -nz_ end
					local off = road.hw + P.CANAL_OFF + P.CANAL_HALF
					local cx, cz = lx + nx_ * off, lz + nz_ * off
					pts[i] = {cx, cz}
					local k = gk(cx, cz)
					g[i] = TT[k]
					okp[i] = DW[k] >= P.CANAL_CLEAR and inside(cx, cz, P.WALL_HALF + P.WALL_KEEP + P.CANAL_HALF) and
						max(abs(cx), abs(cz)) > CK + 6
					-- keep off junction mouths
					for _, j in ipairs(road.junctions) do if abs(j.idx - i) < 12 then okp[i] = false end end
					if i < 14 or i > n - 14 then okp[i] = false end
				end
				local a = 1
				while a <= n do
					if okp[a] then
						local lo_, hi_ = g[a], g[a]
						local b = a
						while b < n and okp[b + 1] and max(hi_, g[b + 1]) - min(lo_, g[b + 1]) <= P.CANAL_VAR do
							b = b + 1
							lo_, hi_ = min(lo_, g[b]), max(hi_, g[b])
						end
						if b - a + 1 >= P.CANAL_MIN and (not best or b - a > best.b - best.a) then
							best = {road = road, a = a, b = b, lo = lo_, hi = hi_, pts = pts}
						end
						a = a + max(1, floor((b - a) / 2))
					else
						a = a + 1
					end
				end
			end
		end
		if best then
			local cpts = {}
			for i = best.a, best.b, 2 do cpts[#cpts + 1] = best.pts[i] end
			canal = {pts = cpts, level = best.lo - 1, half = P.CANAL_HALF, depth = P.CANAL_DEPTH,
				length = best.b - best.a, var = best.hi - best.lo, lane = best.road.id,
				max_cut = best.hi - (best.lo - 1 - P.CANAL_DEPTH + 1)}
			-- occupancy: the canal band + 1
			local reach = P.CANAL_HALF + 1
			for _, p in ipairs(cpts) do
				for lz = floor(p[2] - reach), ceil(p[2] + reach) do
					for lx = floor(p[1] - reach), ceil(p[1] + reach) do
						if ok_(lx, lz) and (lx - p[1]) ^ 2 + (lz - p[2]) ^ 2 <= reach * reach then
							local k = okey(lx, lz)
							if not OCC[k] then OCC[k] = "q" end
						end
					end
				end
			end
		end
		st.t.canal = os.clock() - Tc
	end
	---------------------------------------------------------------------------
	-- 6. plots
	---------------------------------------------------------------------------
	local T6 = os.clock()
	local street_by_id = {}
	for _, r in ipairs(streets) do street_by_id[r.id] = r end
	-- provisional final profiles of the streets (connectors do not change
	-- them: they only continue avenues at the gates)
	local L0 = kit.finish()
	for c = 1, 4 do
		local av = avenues[c]
		gates[c].ground_y = gates[c].y
		gates[c].y = floor(av.R[#av.X])
		gates[c].q = av.RQ[#av.X]   -- connectors continue at exactly this level
	end
	-- squares: flat at the street level where they sit; occupied for plots
	local kept_sq = {}
	for _, q in ipairs(squares) do
		q.y = floor(2 * q.road.R[q.idx] + 0.5) / 2
		-- the square reaches only as far as every street through it stays
		-- within 1/2 of its level (junction mouths are flat), so its edge
		-- never makes a step against a street surface
		local r = P.SQUARE_R
		for _, sr in ipairs(streets) do
			for i = 1, #sr.X do
				local d = sqrt((sr.X[i] - AX - q.x) ^ 2 + (sr.Z[i] - AZ - q.z) ^ 2)
				if d <= P.SQUARE_R + sr.hw + 2 then
					local y = floor(2 * sr.R[i] + 0.5) / 2
					if abs(y - q.y) > 0.5 then r = min(r, d - sr.hw - 2) end
				end
			end
		end
		q.r = r
		if r >= 3 then kept_sq[#kept_sq + 1] = q end
	end
	st.squares_dropped = #squares - #kept_sq
	squares = kept_sq
	for _, q in ipairs(squares) do
		local R2 = q.r * q.r
		for lz = floor(q.z - q.r), ceil(q.z + q.r) do
			for lx = floor(q.x - q.r), ceil(q.x + q.r) do
				if ok_(lx, lz) and (lx - q.x) ^ 2 + (lz - q.z) ^ 2 <= R2 then
					local k = okey(lx, lz)
					if not OCC[k] then OCC[k] = "p" end
				end
			end
		end
	end
	st.squares = #squares
	-- districts -> quadrants: a seeded permutation
	local plots = I.plots
	local roles = {}
	for _, p in ipairs(plots) do
		if not roles[p.district] then roles[#roles + 1] = p.district; roles[p.district] = #roles end
	end
	local perm = {1, 2, 3, 4}
	do
		local h = hash_seed(tostring(seed))
		for i = 4, 2, -1 do
			local j = h % i + 1
			h = floor(h / i)
			perm[i], perm[j] = perm[j], perm[i]
		end
	end
	local quadrant_of = {}
	for i = 1, #roles do quadrant_of[roles[i]] = perm[i] end
	st.quadrant_of = quadrant_of
	-- candidates: along every street side, every 2 points
	local function street_side_quadrant(road, sidex, sidez, px, pz)
		if road.quadrant then return road.quadrant end
		-- avenue c: quadrant c on the side toward avenue c+1, c-1 on the other
		local c = road.gate
		local nxt = CARD[c % 4 + 1]
		local q = (sidex * nxt.dx + sidez * nxt.dz) > 0 and c or ((c + 2) % 4 + 1)
		return q
	end
	local cands = {}
	for _, road in ipairs(streets) do
		local X, Z, n = road.X, road.Z, #road.X
		-- junction zones on this street
		local jz = {}
		for _, j in ipairs(road.junctions) do jz[#jz + 1] = j.idx end
		for i = 6, n - 5, 2 do
			local lx, lz = X[i] - AX, Z[i] - AZ
			local near_j = false
			for _, ji in ipairs(jz) do if abs(ji - i) < 10 then near_j = true end end
			if road.a_parent and i < 10 then near_j = true end
			if road.parent and i > n - 10 then near_j = true end
			if road.dead_end and i > n - 12 then near_j = true end
			if road.role == "avenue" and i < 8 then near_j = true end
			if not near_j then
				local tx, tz = X[min(n, i + 3)] - X[max(1, i - 3)], Z[min(n, i + 3)] - Z[max(1, i - 3)]
				local l = sqrt(tx * tx + tz * tz)
				tx, tz = tx / l, tz / l
				for _, sg in ipairs({1, -1}) do
					local nx_, nz_ = -tz * sg, tx * sg
					local best, bd
					for t = 0, 3 do
						local f = FRONT[t]
						local v = -(f[1] * nx_ + f[2] * nz_)
						if not bd or v > bd then best, bd = t, v end
					end
					cands[#cands + 1] = {road = road, i = i, x = lx, z = lz, nx = nx_, nz = nz_,
						turns = best, align = bd, r = sqrt(lx * lx + lz * lz),
						q = street_side_quadrant(road, nx_, nz_, lx, lz), ry = road.R[i]}
				end
			end
		end
	end
	st.candidates = #cands
	-- districts -> quadrants by capacity (D69: districts stay groups, the
	-- planner picks their place): a quadrant's capacity is the count of its
	-- candidate slots whose probe point (a typical plot centre) is buildable
	-- and free; the district with the largest total footprint takes the
	-- largest quadrant, and so on. Ties keep the seeded order above.
	if P.ASSIGN == "capacity" then
		local cap = {0, 0, 0, 0}
		for _, c in ipairs(cands) do
			local D = c.road.hw + 12
			local px, pz = floor(c.x + c.nx * D + 0.5), floor(c.z + c.nz * D + 0.5)
			local k = gk(px, pz)
			if BUILD[k] and inside(px, pz, 20) and not OCC[okey(px, pz)] then cap[c.q] = cap[c.q] + 1 end
		end
		local demand = {}
		for _, p in ipairs(plots) do
			local b = p.bounds
			demand[p.district] = (demand[p.district] or 0) + (b.max.x - b.min.x + 1) * (b.max.z - b.min.z + 1)
		end
		-- pinned districts (Lethariel's mere precinct, Kezamba's shore market:
		-- they belong beside their civic lake) take the quadrant their
		-- direction points into; the rest go by capacity
		for d, dir in pairs(P.PIN or {}) do
			local a = atan2(dir[2], dir[1])
			local q = a >= 0 and (a < pi / 2 and 1 or 2) or (a < -pi / 2 and 3 or 4)
			quadrant_of[d] = q
			cap[q] = -1
		end
		local ds = {}
		for i = 1, #roles do
			if not (P.PIN and P.PIN[roles[i]]) then
				ds[#ds + 1] = {d = roles[i], w = demand[roles[i]], o = perm[i]}
			end
		end
		table.sort(ds, function(a, b) if a.w ~= b.w then return a.w > b.w end return a.o < b.o end)
		local qs = {}
		for q = 1, 4 do qs[q] = {q = q, c = cap[q]} end
		table.sort(qs, function(a, b) if a.c ~= b.c then return a.c > b.c end return perm[a.q] < perm[b.q] end)
		for i = 1, #ds do quadrant_of[ds[i].d] = qs[i].q end
		st.capacity = cap
	end
	local placed, left_out, relaxed = {}, {}, {}
	local plot_of_key = {}
	local function try_place(p, cand, relax)
		local b = p.bounds
		local t = cand.turns
		local x0, x1, z0, z1 = M.rot_bounds(b, t)
		local f = FRONT[t]
		-- distance from the plot origin to its front edge (local -z edge)
		local front = -b.min.z
		local road = cand.road
		for push = 0, P.PUSH do
			local D = road.hw + P.SETBACK + front + push
			-- the plot centre, on the street normal; its front faces the street
			local cx = floor(cand.x + cand.nx * D + 0.5)
			local cz = floor(cand.z + cand.nz * D + 0.5)
			local good, why = true, nil
			-- inside the outline (wall + walk keep)
			for _, cc in ipairs({{x0, z0}, {x1, z0}, {x0, z1}, {x1, z1}}) do
				if not inside(cx + cc[1], cz + cc[2], P.WALL_HALF + P.WALL_KEEP) then good, why = false, "outline" break end
			end
			-- occupancy: streets (corridor hw + 1), core, wall, gates, plots (+gap)
			local blocked_by_street = false
			if good then
				local gp = P.PLOT_GAP
				for lz = cz + z0 - gp, cz + z1 + gp do
					for lx = cx + x0 - gp, cx + x1 + gp do
						if not ok_(lx, lz) then good, why = false, "extent" break end
						local k = okey(lx, lz)
						local o = OCC[k]
						local inner = lx >= cx + x0 and lx <= cx + x1 and lz >= cz + z0 and lz <= cz + z1
						if o and (inner or type(o) == "number") then good, why = false, "occupied" break end
						local sd = SD[k]
						if inner and sd and sd[3] <= 1 then good, why, blocked_by_street = false, "street", true break end
					end
					if not good then break end
				end
			end
			if good then
				-- terrain legality (as the successor's audit): base at the origin,
				-- fall under the skirt, rise under the cleared airspace, dry
				local base = t_at(cx, cz)
				local low, high, wet = base, base, false
				for lz = cz + z0 - P.WET_MARGIN, cz + z1 + P.WET_MARGIN, 2 do
					for lx = cx + x0 - P.WET_MARGIN, cx + x1 + P.WET_MARGIN, 2 do
						local k = gk(lx, lz)
						if WET[k] then wet = true end
						local inner = lx >= cx + x0 and lx <= cx + x1 and lz >= cz + z0 and lz <= cz + z1
						if inner then
							local y = TT[k]
							if y < low then low = y end
							if y > high then high = y end
						end
					end
				end
				local fall, rise = base - low, high - base
				local fall_lim = P.FALL + (relax and 4 or 0)
				local rise_lim = (p.clear_to or b.max.y) + (relax and 4 or 0)
				if wet then good, why = false, "wet"
				elseif fall > fall_lim then good, why = false, "fall"
				elseif rise > rise_lim then good, why = false, "rise" end
				-- entry: the front edge's middle, one node out, to the street
				if good then
					local ex, ez = M.rot(0, b.min.z - 1, t)
					ex, ez = cx + ex, cz + ez
					local sd = SD[okey(floor(ex + 0.5), floor(ez + 0.5))]
					local appr, sy
					if sd then
						appr = max(0, sd[3])
						local rr = street_by_id[sd[1]]
						sy = rr and rr.R[sd[2]] or nil
					end
					if not appr or appr > P.APPROACH_MAX + (relax and 4 or 0) then good, why = false, "approach"
					elseif sy and abs(base - floor(sy)) > P.ENTRY_STEP + (relax and 2 or 0) then good, why = false, "entry_step"
					else
						return {id = p.id, x = cx, z = cz, turns = t, y = base, fall = fall, rise = rise,
							approach = appr, entry_step = sy and (base - floor(sy)) or 0,
							street = road.id, street_role = road.role, align = cand.align,
							x0 = x0, x1 = x1, z0 = z0, z1 = z1, district = p.district, kind = p.kind,
							required = p.required, quadrant = cand.q, relaxed = relax or nil}
					end
				end
			end
			if good == false and why ~= "street" then return nil, why end
		end
		return nil, "street"
	end
	local function mark_plot(pl, idx)
		for lz = pl.z + pl.z0, pl.z + pl.z1 do
			for lx = pl.x + pl.x0, pl.x + pl.x1 do
				OCC[okey(lx, lz)] = idx
			end
		end
	end
	-- order: required plots first, then buildings, then fill pieces
	local order = {}
	for i, p in ipairs(plots) do order[#order + 1] = {p = p, i = i} end
	local function prio(p) if p.required then return 0 elseif p.kind == "plot" then return 1 else return 2 end end
	table.sort(order, function(a, b)
		local pa, pb = prio(a.p), prio(b.p)
		if pa ~= pb then return pa < pb end
		return a.i < b.i
	end)
	-- candidate order per quadrant: buildings near the core first, fill
	-- pieces from the wall inward
	local byq = {{}, {}, {}, {}}
	for _, c in ipairs(cands) do table.insert(byq[c.q], c) end
	local near, far = {}, {}
	for q = 1, 4 do
		local a = {}
		for i, c in ipairs(byq[q]) do a[i] = c end
		table.sort(a, function(u, v) if u.r ~= v.r then return u.r < v.r end return u.i < v.i end)
		near[q] = a
		local b = {}
		for i, c in ipairs(byq[q]) do b[i] = c end
		table.sort(b, function(u, v) if u.r ~= v.r then return u.r > v.r end return u.i < v.i end)
		far[q] = b
	end
	local reasons = {}
	local function place_in(p, qlist, relax)
		local list = p.kind == "fill" and far or near
		for _, q in ipairs(qlist) do
			for _, c in ipairs(list[q]) do
				local pl, why = try_place(p, c, relax)
				if pl then return pl end
				reasons[why] = (reasons[why] or 0) + 1
			end
		end
	end
	-- D70 placement passes: (1) every plot in its own quarter (required,
	-- buildings, fill); (2) what did not fit overflows into the two
	-- neighbouring quarters (nearer first by angle order); (3) buildings
	-- (named plots, quest texts name them) and required plots then take
	-- relaxed legality anywhere -- never dropped; only fill pieces may be
	-- left out.
	local overflowed = {}
	local function commit_plot(pl)
		placed[#placed + 1] = pl
		mark_plot(pl, #placed)
	end
	local pending = {}
	for _, o in ipairs(order) do
		local p = o.p
		local pl = place_in(p, {quadrant_of[p.district]})
		if pl then commit_plot(pl) else pending[#pending + 1] = p end
	end
	local pending2 = {}
	for _, p in ipairs(pending) do
		local q = quadrant_of[p.district]
		local pl = place_in(p, {q % 4 + 1, (q + 2) % 4 + 1})
		if pl then
			pl.overflow = true
			overflowed[#overflowed + 1] = p.id
			commit_plot(pl)
		else
			pending2[#pending2 + 1] = p
		end
	end
	for _, p in ipairs(pending2) do
		local pl
		if p.required or p.kind ~= "fill" then
			local q = quadrant_of[p.district]
			local all = {q, q % 4 + 1, (q + 2) % 4 + 1, (q + 1) % 4 + 1}
			pl = place_in(p, {all[4]}) or place_in(p, all, true)
			if pl then
				relaxed[#relaxed + 1] = p.id
				if pl.quadrant ~= q then pl.overflow = true; overflowed[#overflowed + 1] = p.id end
			end
		end
		if pl then
			commit_plot(pl)
		else
			left_out[#left_out + 1] = {id = p.id, required = p.required, kind = p.kind, district = p.district}
		end
	end
	st.overflowed = overflowed
	st.reject_reasons = reasons
	st.t.plots = os.clock() - T6
	---------------------------------------------------------------------------
	-- 8. connectors: road end -> gate (the band between wall and reserved edge)
	---------------------------------------------------------------------------
	local T7 = os.clock()
	local connectors = {}
	for _, g in ipairs(gates) do
		table.sort(g.ends, function(a, b)
			local da = (a.x - g.ox) ^ 2 + (a.z - g.oz) ^ 2
			local db = (b.x - g.ox) ^ 2 + (b.z - g.oz) ^ 2
			if da ~= db then return da < db end
			return a.road < b.road
		end)
		local first
		for _, e in ipairs(g.ends) do
			local kind = e.kind == "primary" and "primary" or "secondary"
			local guide = guide_for(function(lx, lz)
				-- stay outside the city (the wall), except in front of the gate
				local dg = sqrt((lx - g.ox) ^ 2 + (lz - g.oz) ^ 2)
				if dg < 20 then return 0 end
				local r = sqrt(lx * lx + lz * lz)
				local ro = r_at(atan2(lz, lx)) + P.WALL_HALF + 6
				if r < ro then return 50 end
				return 0
			end)
			local lead = {e.x + e.hx * 6, e.z + e.hz * 6}
			local src = cell_li(e.x + e.hx * 10, e.z + e.hz * 10) or cell_li(lead[1], lead[2])
			local o2 = {g.ox + g.dx * 10, g.oz + g.dz * 10}
			local tgt = cell_li(o2[1], o2[2])
			local tset = {}
			if first then
				for i = 1, #first.X - 16 do
					local li = cell_li(first.X[i] - AX, first.Z[i] - AZ)
					if li and i > 12 then tset[li] = i end
				end
			end
			local path = src and route(src, dir_index(e.hx, e.hz), function(li, d)
				if li == tgt then return {kind = "node"} end
				if tset[li] then return {kind = "road", idx = tset[li]} end
			end, o2, guide)
			local road
			if path then
				local _, info = nil, nil
				local last = path[#path]
				if tset[last] then
					local ctrl = ctrl_from(path, {{e.x, e.z}, lead}, {})
					local ex, ez = kit.li_xz(last)
					ctrl[#ctrl + 1] = {ex, ez}
					road = kit.street(kind, ctrl, {a = "end:" .. e.road, b_parent = first.id,
						pin_a = e.q / Q, flat_a = 4})
				else
					local ctrl = ctrl_from(path, {{e.x, e.z}, lead}, {o2, {g.ox, g.oz}})
					road = kit.street(kind, ctrl, {a = "end:" .. e.road, b = "gate_" .. g.name,
						pin_a = e.q / Q, flat_a = 4, pin_b = g.q / Q, flat_b = 12})
				end
				kit.commit(road)
				road.role, road.gate, road.end_road = "connector", g.c, e.road
				connectors[#connectors + 1] = road
				first = first or road
			else
				st.connector_failed = (st.connector_failed or 0) + 1
			end
		end
	end
	st.t.connectors = os.clock() - T7
	local T8 = os.clock()
	local layout = kit.finish()
	st.t.profile_final = os.clock() - T8
	st.t.total = os.clock() - T0
	st.kit_stats = layout.stats
	return {seed = seed, anchor = I.anchor, P = P, R = R, rays = RAYS, area = area,
		gates = gates, ends = ends, streets = streets, avenues = avenues, rings = rings,
		connectors = connectors, layout = layout, plots = placed, left_out = left_out,
		relaxed = relaxed, wall = wall, canal = canal, squares = squares, stats = st, r_at = r_at, inside = inside,
		grid = {TT = TT, WET = WET, BUILD = BUILD, DW = DW, NG = NG, G = G, EXT = EXT}}
end

-------------------------------------------------------------------------------
-- Payload (text, the `capital_layout` field of the ipc_set payload), local
-- coordinates relative to the anchor:
--   C2 <anchor id> <x> <z>
--   k stone|palisade|open                    edge kind
--   o <outline radius per ray, 0.1>
--   g <name> <x> <z> <floor y>               the four gates
--   p <plot id> <x> <z> <turns> <y>          one per placed plot
--   w <x,z,walk2[flags]> ...                 wall points (~2 nodes apart), the
--                                            walk in half nodes; flags: g gate
--                                            gap, a over water
--   t <wall point index> ...                 turrets
--   s <x> <z> <r> <y>                        squares (flat paving at y)
--   q <level> <half> <depth> <x,z> ...       canal polyline (optional)
-- The streets and connectors are not in it: they join the road layout
-- (`height.lua` add_roads), which travels in its own field.
-------------------------------------------------------------------------------
function M.serialize(plan)
	local out = {("C2 %s %d %d"):format(plan.anchor.id, plan.anchor.x, plan.anchor.z)}
	out[#out + 1] = "k " .. plan.wall.kind
	local r = {}
	for a = 1, #plan.R do r[a] = ("%.1f"):format(plan.R[a]) end
	out[#out + 1] = "o " .. table.concat(r, " ")
	for _, g in ipairs(plan.gates) do
		out[#out + 1] = ("g %s %.2f %.2f %d"):format(g.name, g.x, g.z, g.y)
	end
	for _, p in ipairs(plan.plots) do
		out[#out + 1] = ("p %s %d %d %d %d"):format(p.id, p.x, p.z, p.turns, p.y)
	end
	local w = {}
	for i, p in ipairs(plan.wall.pts) do
		w[#w + 1] = ("%.1f,%.1f,%d%s%s"):format(p[1], p[2], plan.wall.walk[i],
			plan.wall.gap[i] and "g" or "", plan.wall.wet[i] and "a" or "")
	end
	out[#out + 1] = "w " .. table.concat(w, " ")
	local tt = {}
	for _, t in ipairs(plan.wall.turrets) do tt[#tt + 1] = tostring(t.i) end
	out[#out + 1] = "t " .. table.concat(tt, " ")
	for _, q in ipairs(plan.squares or {}) do
		out[#out + 1] = ("s %.1f %.1f %.1f %.1f"):format(q.x, q.z, q.r, q.y)
	end
	if plan.canal then
		local c = {}
		for _, p in ipairs(plan.canal.pts) do c[#c + 1] = ("%.1f,%.1f"):format(p[1], p[2]) end
		out[#out + 1] = ("q %d %d %d %s"):format(plan.canal.level, plan.canal.half,
			plan.canal.depth, table.concat(c, " "))
	end
	return table.concat(out, "\n") .. "\n"
end

-- The payload of every capital is the concatenation of their texts; this
-- splits it again: {anchor id -> text}, and the ids in payload order.
function M.split(text)
	local out, order, cur, id = {}, {}, nil, nil
	for line in text:gmatch("[^\n]+") do
		local head = line:match("^C2 (%S+) ")
		if head then
			if id then out[id] = table.concat(cur, "\n") .. "\n" end
			id, cur = head, {}
			order[#order + 1] = id
		end
		if not cur then error("capital layout: text before the first capital", 0) end
		cur[#cur + 1] = line
	end
	if id then out[id] = table.concat(cur, "\n") .. "\n" end
	return out, order
end

-- The payload back as a table (every consumer reads THIS, in main as in
-- emerge): {anchor = {id, x, z}, kind, outline = {r...}, gates = {name =
-- {name, x, z, y, dx, dz}} and gates[1..4] in CARD order, plots = {{id, x,
-- z, turns, y}}, wall = {pts = {{x, z}}, walk, gap, wet, turrets = {index}},
-- squares = {{x, z, r, y}}, canal = {level, half, depth, pts} or nil}.
function M.deserialize(text)
	local function fail(message) error("capital layout: " .. message, 0) end
	if type(text) ~= "string" then fail("text differs") end
	local L = {plots = {}, squares = {}, gates = {}, outline = {},
		wall = {pts = {}, walk = {}, gap = {}, wet = {}, turrets = {}}}
	local card = {}
	for i, c in ipairs(CARD) do card[c.name] = i end
	for line in text:gmatch("[^\n]+") do
		local tag, rest = line:match("^(%S+)%s*(.*)$")
		if tag == "C2" then
			local id, x, z = rest:match("^(%S+) (%-?%d+) (%-?%d+)$")
			if not id then fail("header differs") end
			L.anchor = {id = id, x = tonumber(x), z = tonumber(z)}
		elseif tag == "k" then
			L.kind = rest
		elseif tag == "o" then
			for v in rest:gmatch("%S+") do L.outline[#L.outline + 1] = tonumber(v) end
		elseif tag == "g" then
			local name, x, z, y = rest:match("^(%a+) (%S+) (%S+) (%-?%d+)$")
			local c = name and card[name]
			if not c then fail("gate differs: " .. line) end
			local g = {name = name, x = tonumber(x), z = tonumber(z), y = tonumber(y),
				dx = CARD[c].dx, dz = CARD[c].dz}
			L.gates[c], L.gates[name] = g, g
		elseif tag == "p" then
			local id, x, z, t, y = rest:match("^(%S+) (%-?%d+) (%-?%d+) (%d) (%-?%d+)$")
			if not id then fail("plot differs: " .. line) end
			L.plots[#L.plots + 1] = {id = id, x = tonumber(x), z = tonumber(z),
				turns = tonumber(t), y = tonumber(y)}
		elseif tag == "w" then
			local W = L.wall
			for x, z, walk, flags in rest:gmatch("(%-?[%d.]+),(%-?[%d.]+),(%-?%d+)(%a*)") do
				local i = #W.pts + 1
				W.pts[i] = {tonumber(x), tonumber(z)}
				W.walk[i] = tonumber(walk)
				W.gap[i] = flags:find("g", 1, true) ~= nil
				W.wet[i] = flags:find("a", 1, true) ~= nil
			end
		elseif tag == "t" then
			for v in rest:gmatch("%d+") do L.wall.turrets[#L.wall.turrets + 1] = tonumber(v) end
		elseif tag == "s" then
			local x, z, r, y = rest:match("^(%S+) (%S+) (%S+) (%S+)$")
			L.squares[#L.squares + 1] = {x = tonumber(x), z = tonumber(z),
				r = tonumber(r), y = tonumber(y)}
		elseif tag == "q" then
			local level, half, depth, pts = rest:match("^(%-?%d+) (%d+) (%d+) (.*)$")
			if not level then fail("canal differs") end
			local c = {level = tonumber(level), half = tonumber(half),
				depth = tonumber(depth), pts = {}}
			for x, z in pts:gmatch("(%-?[%d.]+),(%-?[%d.]+)") do
				c.pts[#c.pts + 1] = {tonumber(x), tonumber(z)}
			end
			L.canal = c
		else
			fail("line differs: " .. line)
		end
	end
	if not L.anchor or not L.kind or #L.outline == 0 or #L.wall.pts < 3 then
		fail("layout incomplete")
	end
	for c = 1, 4 do if not L.gates[c] then fail("gate missing") end end
	return L
end

return M
