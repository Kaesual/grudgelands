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
	R_MIN = 118, BAND = 26,   -- outline radius floor; wall-to-reserved-edge band
	NRAY = 180, SMOOTH_PASSES = 2, SMOOTH_W = 3,
	BUDGET_NOISE = 0.32, WALL_BANK = 6,
	-- Round 26 outline character (M.STYLE overrides per capital): budget
	-- noise octaves {frequency, weight, x offset, z offset}; the two
	-- harmonics toward the open ground (ECC1 off-centre, ECC2 elongated
	-- along AXIS "open" or "across"); the terrain snap (SNAP reach in nodes,
	-- SNAP_T per node of crest or brow, SNAP_S for a shore just ahead,
	-- SNAP_D the penalty at full reach); POLY = corner count of an angular
	-- outline (nil: curved)
	NOISE_OCT = {{1.6, 0.7, 0, 0}, {4, 0.3, 7, -3}},
	ECC1 = 0.1, ECC2 = 0.08, AXIS = "open",
	SNAP = 20, SNAP_T = 1.0, SNAP_S = 3, SNAP_D = 2.5,
	POLY = nil,
	NOTCH = 0.14,
	BANK_RUN = 8,         -- at most this many rays on the far bank of a river follow their neighbours
	GATE_FLAT = 8, GATE_BLEND = 2, -- the wall runs straight across each gate this far beyond the gatehouse
	GROW = 0.08, GROW_TRIES = 2, -- a plan leaving a named plot out retries at +8 %, +16 % area
	SHORE_STOP = 70,      -- water met this far out along a ray: the city grows across it only
	C_BEYOND = 3,         -- ... at this multiple of the cost (it prefers its near bank)         -- a ray keeps within this share of the broadly smoothed outline
	C_WET = 4.0, C_STEEP = 2.6, C_BUILD = 1.0,
	BANK = 6, ROUGH = 6,      -- buildable: distance to water >= BANK, relief in a 10-node window <= ROUGH
	GATE_SLIDE = 60, GATE_SLIDE_WET = 2.5,   -- D70: a gate may slide further (x2.5) to avoid water
	GATE_MAX_ANGLE = 0.6, -- ... but never more than ~34 deg off its cardinal ray (gates stay apart)
	RINGS = {0.31, 0.71},     -- ring lanes at these fractions from the core gate radius to the outline
	RING_GUIDE = 1.2, AVENUE_GUIDE = 0.5, AVENUE_GUIDE_MAX = 6, ASSIGN = "capacity",
	CANAL = false, CANAL_OFF = 2, CANAL_HALF = 2, CANAL_DEPTH = 2, CANAL_CLEAR = 12, CANAL_VAR = 3, CANAL_MIN = 60,
	WALL_HALF = 3, WALL_KEEP = 8, TURRET_EVERY = 64, WALL_HEIGHT = 7,
	-- towers (Round 26): the edge kind's turret radius, flank towers beside
	-- the gatehouses, towers at bends turning more than BEND_MIN (radians
	-- over ~20 nodes; nil: none) at least BEND_GAP apart along the wall
	TURRET_R = 5, GATE_FLANK = true, BEND_MIN = 0.45, BEND_GAP = 40,
	WALL_SLACK = 1.05,    -- walk slope bound: <= 1/2 node per (node x this)
	WALL_CLEAR = 1,       -- over water the walk stands at least this far above the surface
	-- a civic lake is the edge (M.shore_flags, I.shore_distance)
	SHORE_INTO = 3,       -- the wall runs on over at most this many water points of a crossing
	SHORE_DEEP = 3,       -- ... and past the first only while they lie within this of the shore
	SHORE_MIN_RUN = 12,   -- a dry stretch between two crossings shorter than this carries no wall
	SHORE_REACH = 32,     -- ... nor one whose outer land the lake closes within this
	SHORE_KEEP = 6,       -- a wall point within this of the water stands on a solid footing
	SHORE_TURRET_GAP = 6, -- no turret within this many points of the lake
	GATE_DEPTH = 5, GATE_WIDTH = 7,   -- gatehouse half extents (along / across its axis)
	PLOT_GAP = 2, SETBACK = 1.0, PUSH = 6, APPROACH_MAX = 5, ENTRY_STEP = 2,
	FALL = 6, WET_MARGIN = 2,
	CITY_CELL = 4,
	FINE_R = 272,         -- 2-node sampling inside this radius, 4-node beyond
	SEARCH_BUDGET = 4,    -- a street search gives up beyond this multiple of its straight cost (+400)
	-- a connector crosses the natural ground beyond the city's calm plateau
	-- (D76) to a road end at the reserved edge, up to ~365 from the anchor at
	-- a corner: it may climb and wind, so it searches further before it gives
	-- up (a search that succeeded within SEARCH_BUDGET finds the same path)
	CONNECTOR_BUDGET = 16,
	WALL = "stone",       -- an edge kind of M.EDGE (its name travels in the payload)
	-- D70 street pattern: loosened rings, cross-lanes, squares (per capital
	-- and seed from a variation hash, so six capitals do not repeat)
	RING_JITTER = 0.05,   -- ring fractions +- this
	RING2_OPEN = 0.35,    -- share of ring-2 arcs that stop halfway in a square
	RING1_OPEN = 0,       -- ... and of ring-1 arcs (Round 26 character)
	OPEN_MAX = 2,         -- at most this many open arcs
	RING_SHAPE = nil,     -- {[ring] = "circle"}: a ring round the core, not along the outline
	CROSS_MEAN = 1.0,     -- cross-lanes ring 1 -> ring 2 per quadrant (0..CROSS_MAX)
	CROSS_MAX = 2,
	CROSS_FIXED = nil,    -- Round 26: exactly this many cross-lanes per quadrant, evenly spaced
	RING_WOBBLE = 0,      -- the inner ring's fraction varies by this share round the city
	GATE_TWIST = 0,       -- every gate turned by this (radians) off its cardinal ray
	SPOKES = 0, SPOKE_FIXED = false, SPOKE_IN = 30, SPOKE_MIN = 40,
	PLAZA = nil,          -- radius of one large plaza on the long side's avenue
	BUILD_R = 0,          -- buildings spread from this fraction of the way to the wall (0: from the core)
	RING_WALL_MAX = 46,   -- the outer ring keeps within this of the (smoothed) wall
	RING_GAP_MAX = 84,    -- ... and the ring inside it within this of it
	SQUARE_P = 0.5,       -- share of avenue/ring crossings that get a small square
	SQUARE_R = 6,         -- square radius (nodes)
	PIN = nil,            -- {district = quadrant-direction {x, z}}: pinned districts
}

-- Edge dimensions per edge kind (D69/D72, Round 23): the writer model of
-- `wp13/city_edge.lua` ("stone" curtain or "palisade"), wall half thickness,
-- walk height above the ground, gatehouse half extents along and across its
-- axis, turret spacing and radius. `opts` are the planner overrides; the
-- writer reads the rest.
--
-- The two NARROW kinds are the Round 23 walls of the two capitals that were
-- open until then (Lethariel's light curtain, Kezamba's timber palisade).
-- They keep the footprint the planted belt was planned with -- wall half 2,
-- keep 6, gate boxes 3 x 5 -- so those capitals keep their outline, gates,
-- streets and plots; only the wall's own payload (walk heights, turrets)
-- differs. Where their civic lake crosses the outline the lake is the edge
-- (M.shore_flags, the `l` and `f` flags of the payload).
M.EDGE = {
	stone = {model = "stone", half = 3, depth = 5, width = 7, turret = 5,
		opts = {WALL_HALF = 3, WALL_HEIGHT = 7, GATE_DEPTH = 5, GATE_WIDTH = 7, TURRET_R = 5}},
	palisade = {model = "palisade", half = 2, depth = 4, width = 6, turret = 3,
		opts = {WALL_HALF = 2, WALL_HEIGHT = 5, GATE_DEPTH = 4, GATE_WIDTH = 6,
			TURRET_EVERY = 56, TURRET_R = 3}},
	stone_narrow = {model = "stone", half = 2, depth = 3, width = 5, turret = 3,
		opts = {WALL_HALF = 2, WALL_HEIGHT = 6, GATE_DEPTH = 3, GATE_WIDTH = 5,
			WALL_KEEP = 6, TURRET_EVERY = 48, TURRET_R = 3}},
	palisade_narrow = {model = "palisade", half = 2, depth = 3, width = 5, turret = 3,
		opts = {WALL_HALF = 2, WALL_HEIGHT = 5, GATE_DEPTH = 3, GATE_WIDTH = 5,
			WALL_KEEP = 6, TURRET_EVERY = 56, TURRET_R = 3}},
}

-- Round 26 (D72, plan rulings 1-4): each capital's character, planner
-- overrides applied after its edge kind's (`r7_capitals.lua`). NAME is a
-- short description for the review images. Within the planner's legality
-- rules they vary the outline (noise, harmonics toward the open ground,
-- terrain snap, angular corners), the towers and the street pattern (ring
-- fractions and shape, open arcs, cross-lanes, squares, avenue pull).
M.STYLE = {
	highcourt = {NAME = "royal city: a broad curtain along its river, flanked gatehouses; two rings and a royal plaza on its main avenue",
		SMOOTH_PASSES = 2, SMOOTH_W = 3, BUDGET_NOISE = 0.3, ECC1 = 0.12, ECC2 = 0.1,
		SNAP = 20, GATE_FLANK = true, BEND_MIN = 0.4, BEND_GAP = 44, TURRET_EVERY = 80,
		RINGS = {0.3, 0.7}, RING2_OPEN = 0.2, CROSS_MEAN = 1.0, SQUARE_P = 0.6,
		AVENUE_GUIDE = 0.6, PLAZA = 12},
	dur_brannoc = {NAME = "mountain hold: straight faces on the crests, a tower on every corner; an eight-armed star of straight streets",
		POLY = 8, SMOOTH_PASSES = 1, SMOOTH_W = 2, BUDGET_NOISE = 0.22, ECC1 = 0.16, ECC2 = 0.08,
		SNAP = 30, SNAP_T = 1.5, GATE_FLANK = true, BEND_MIN = 0.2, BEND_GAP = 30,
		TURRET_EVERY = 90, RINGS = {0.3, 0.62}, RING_SHAPE = {[2] = "wall"}, RING2_OPEN = 0,
		RING_WALL_MAX = 66, CROSS_FIXED = 1, SPOKES = 1, SPOKE_FIXED = true, SPOKE_IN = 16,
		SPOKE_MIN = 24,
		SQUARE_P = 0.35, AVENUE_GUIDE = 1.2},
	nhal_veyr = {NAME = "walled necropolis: long closed curtain, a steady tower rhythm; one round ring with rows of lanes out to the wall",
		SMOOTH_PASSES = 3, SMOOTH_W = 3, BUDGET_NOISE = 0.2, ECC1 = 0.06, ECC2 = 0.22,
		SNAP = 16, GATE_FLANK = true, BEND_MIN = false, TURRET_EVERY = 64,
		RINGS = {0.46}, RING_SHAPE = {"circle"}, RING2_OPEN = 0, SPOKES = 3, SPOKE_FIXED = true,
		SPOKE_IN = 24, SQUARE_R = 5, AVENUE_GUIDE = 0.8, BUILD_R = 0.4},
	gor_drazhak = {NAME = "war camp: rough jagged stockade; gates turned into a pinwheel of winding avenues, a war yard, broken outer ring",
		SMOOTH_PASSES = 1, SMOOTH_W = 2, BUDGET_NOISE = 0.32,
		NOISE_OCT = {{1.6, 0.55, 0, 0}, {4, 0.3, 7, -3}, {9, 0.15, -11, 5}},
		ECC1 = 0.2, ECC2 = 0.06, SNAP = 20, GATE_FLANK = false, BEND_MIN = 0.45, BEND_GAP = 44,
		TURRET_EVERY = 84, RINGS = {0.34, 0.74}, RING2_OPEN = 0.4, GATE_TWIST = 0.4,
		OPEN_MAX = 2, CROSS_MEAN = 1.4, CROSS_MAX = 3, SPOKES = 1, SPOKE_IN = 16, SPOKE_MIN = 24,
		SQUARE_P = 0.7, SQUARE_R = 8,
		PLAZA = 14, AVENUE_GUIDE = 0.2, BUILD_R = 0.3},
	lethariel = {NAME = "lakeside city: a long flowing curtain along the crown lake, few towers; gates turned, rings drawn off-centre",
		SMOOTH_PASSES = 3, SMOOTH_W = 4, BUDGET_NOISE = 0.24, ECC1 = 0.14, ECC2 = 0.22,
		AXIS = "across", SNAP = 20, SNAP_S = 5, GATE_FLANK = false, BEND_MIN = 0.55,
		BEND_GAP = 60, TURRET_EVERY = 96, RINGS = {0.32, 0.72}, RING2_OPEN = 0.5,
		RING_WOBBLE = 0.4, GATE_TWIST = -0.3, CROSS_MEAN = 1.0, SQUARE_P = 0.5, AVENUE_GUIDE = 0.25},
	kezamba = {NAME = "jungle city: an irregular stockade round the cenote, winding avenues, a market plaza, lanes out into the green",
		SMOOTH_PASSES = 2, SMOOTH_W = 2, BUDGET_NOISE = 0.34,
		NOISE_OCT = {{1.6, 0.6, 0, 0}, {4, 0.4, 7, -3}},
		ECC1 = 0.08, ECC2 = 0.12, AXIS = "across", SNAP = 20, SNAP_S = 4, GATE_FLANK = false,
		BEND_MIN = 0.4, BEND_GAP = 36, TURRET_EVERY = 64, RINGS = {0.3, 0.72},
		RING2_OPEN = 0.3, RING_WOBBLE = 0.3, CROSS_MEAN = 1.4, CROSS_MAX = 3, SPOKES = 1,
		SPOKE_IN = 16, SPOKE_MIN = 24,
		SQUARE_P = 0.5, SQUARE_R = 7, PLAZA = 10, AVENUE_GUIDE = 0.2, BUILD_R = 0.25},
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
-- shore_flags(pts, gap, distance, P): where a capital's CIVIC lake crosses
-- its outline (Lethariel's crown lake, Kezamba's cenote), the lake is the
-- edge (Round 23 user rulings of 2026-09-28, the second after a playtest).
-- `pts` is the closed wall polyline (local), `gap` its gate points,
-- `distance(lx, lz)` the local column's distance from the lake's water (<= 0
-- on it). Returns {lake, foot, water, stats}, each flag a table by point:
--   * a crossing is a run of water points (a gate point never is one); the
--     wall runs on over its first SHORE_INTO water points from each end --
--     past the first (and next to a gate from the first) only while they lie
--     within SHORE_DEEP of the shore -- and ends there in the water, so no
--     beach is left to walk round its end; the rest of the crossing is
--     `lake` (no wall); a crossing of up to 2 x SHORE_INTO shallow points is
--     walled right across;
--   * a dry stretch between two crossings is lake too when it is shorter
--     than SHORE_MIN_RUN, or when the land on either side of it is closed
--     by the lake: a fill over the dry columns outside (inside) the
--     outline, started beside the stretch, never gets SHORE_REACH beyond
--     it. Outside, the outline runs along a shore whose far side is the
--     lake, so that land is reached only over the water or through the
--     city; inside, the stretch guards a spit the lake cuts off from the
--     city, so the land outside reaches no city ground over land. Either
--     way a wall there would stand alone between two crossings. Every other
--     dry point carries wall, so the wall is continuous on land and the
--     city is never open over land; a dry stretch between a crossing and a
--     gate always carries wall;
--   * `foot`: a walled point within SHORE_KEEP of the water (the ones in it
--     included) stands on a solid footing down to the bed, not an arcade.
-- The flags are the wall's own: gaps, the plot band, the streets and the
-- gates are planned before and without them.
-------------------------------------------------------------------------------
function M.shore_flags(pts, gap, distance, P)
	local n = #pts
	local d, water = {}, {}
	local any = false
	for i = 1, n do
		d[i] = distance(pts[i][1], pts[i][2])
		water[i] = not gap[i] and d[i] <= 0
		if water[i] then any = true end
	end
	local lake, foot = {}, {}
	local stats = {lake_points = 0, crossings = 0, lake_ends = 0, shore_runs = 0, land_runs = 0}
	if not any then return {lake = lake, foot = foot, water = water, stats = stats} end
	local function at(k) return (k - 1) % n + 1 end
	-- the scan starts where no dry stretch can: a gate point, else water
	local start
	for i = 1, n do if gap[i] then start = i break end end
	if not start then for i = 1, n do if water[i] then start = i break end end end
	-- a column inside the closed outline (even-odd crossings; the segments
	-- bucketed by the 4-node rows they span)
	local rows = {}
	for i = 1, n do
		local a, b = pts[i], pts[at(i + 1)]
		for r = floor(min(a[2], b[2]) / 4), floor(max(a[2], b[2]) / 4) do
			local l = rows[r]
			if not l then l = {}; rows[r] = l end
			l[#l + 1] = i
		end
	end
	local function inside(x, z)
		local l, c = rows[floor(z / 4)], false
		if not l then return false end
		for _, i in ipairs(l) do
			local a, b = pts[i], pts[at(i + 1)]
			if (a[2] > z) ~= (b[2] > z) and
					x < a[1] + (z - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) then
				c = not c
			end
		end
		return c
	end
	-- the land on one side of a dry stretch (outside the outline, or inside
	-- it with `within`) is closed when a fill over the dry columns on that
	-- side, started within 3 of its points, stays inside the stretch's box
	-- grown by SHORE_REACH (4-connected, whole local columns, i.e. world
	-- columns): outside, that land is reached only over the water or
	-- through the city; inside, it is a spit the lake cuts off from the city
	local function closed(run, within)
		local x0, x1, z0, z1 = INF, -INF, INF, -INF
		for _, m in ipairs(run) do
			local p = pts[m]
			x0, x1 = min(x0, p[1]), max(x1, p[1])
			z0, z1 = min(z0, p[2]), max(z1, p[2])
		end
		x0, x1 = floor(x0) - P.SHORE_REACH, ceil(x1) + P.SHORE_REACH
		z0, z1 = floor(z0) - P.SHORE_REACH, ceil(z1) + P.SHORE_REACH
		local width = x1 - x0 + 1
		local seen, qx, qz = {}, {}, {}
		local function visit(x, z)
			local k = (z - z0) * width + (x - x0)
			if seen[k] then return true end
			seen[k] = true
			if inside(x, z) ~= (within == true) or distance(x, z) <= 0 then return true end
			if x <= x0 or x >= x1 or z <= z0 or z >= z1 then return false end
			qx[#qx + 1], qz[#qz + 1] = x, z
			return true
		end
		for _, m in ipairs(run) do
			local cx, cz = floor(pts[m][1] + 0.5), floor(pts[m][2] + 0.5)
			for dz = -3, 3 do
				for dx = -3, 3 do
					if not visit(cx + dx, cz + dz) then return false end
				end
			end
		end
		local head = 1
		while head <= #qx do
			local x, z = qx[head], qz[head]
			head = head + 1
			if not (visit(x + 1, z) and visit(x - 1, z) and visit(x, z + 1) and
					visit(x, z - 1)) then
				return false
			end
		end
		return true
	end
	-- the dry stretches between two crossings
	local merged = {}
	for i = 1, n do merged[i] = water[i] end
	if start then
		local k = 0
		while k < n do
			local i = at(start + k)
			if not water[i] and not gap[i] and water[at(i - 1)] then
				local run, j = {}, i
				while not water[j] and not gap[j] and #run < n do
					run[#run + 1] = j
					j = at(j + 1)
				end
				if water[j] then
					local shore = #run < P.SHORE_MIN_RUN or closed(run) or closed(run, true)
					if shore then
						for _, m in ipairs(run) do merged[m] = true end
						stats.shore_runs = stats.shore_runs + 1
					else
						stats.land_runs = stats.land_runs + 1
					end
				end
				k = k + #run
			else
				k = k + 1
			end
		end
	end
	-- the wall runs on into each crossing from both ends
	local kept = {}
	for i = 1, n do
		if merged[i] and not merged[at(i - 1)] then
			stats.crossings = stats.crossings + 1
			local j = i
			while merged[at(j + 1)] and at(j + 1) ~= i do j = at(j + 1) end
			for _, e in ipairs({{i, 1}, {j, -1}}) do
				local k = e[1]
				-- from land the first water point always carries wall; from a
				-- gate (one standing on the shore or, D70, in the water) only
				-- a shallow one: a deep one is closed by the gatehouse itself
				local from_gate = gap[at(k - e[2])]
				for c = 1, P.SHORE_INTO do
					if not merged[k] or not water[k] or
							((c > 1 or from_gate) and d[k] < -P.SHORE_DEEP) then
						break
					end
					kept[k] = true
					k = at(k + e[2])
				end
			end
		end
	end
	for i = 1, n do
		if merged[i] and not kept[i] then
			lake[i] = true
			stats.lake_points = stats.lake_points + 1
		end
	end
	for i = 1, n do
		if lake[i] then
			if not lake[at(i - 1)] then stats.lake_ends = stats.lake_ends + 1 end
			if not lake[at(i + 1)] then stats.lake_ends = stats.lake_ends + 1 end
		elseif not gap[i] and d[i] <= P.SHORE_KEEP then
			foot[i] = true
		end
	end
	return {lake = lake, foot = foot, water = water, stats = stats}
end

-------------------------------------------------------------------------------
-- plan(seed, I)
--   I.anchor = {id, x, z}; I.sample(x, z) -> t, wy|nil, land (the fitted
--   ground before streets, world coordinates; height.lua fitted_values_at);
--   I.rivers (river polylines); I.simplex;
--   I.road_ends = {{x, z, q (profile level in 1/16), hx, hz (heading into
--   the area), kind, road}}; I.plots = the plot kit ({id, district, kind,
--   bounds, clear_to, required}); I.roads_module = the road module (the
--   planner derives its city parameters, M.city_roads); I.network_roads =
--   the network's roads (streets and connectors meet them level, D49)
-------------------------------------------------------------------------------
local function plan_once(seed, I, opt)
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
	--
	-- Round 26 (D72, rulings 1-4 of the Round 26 plan): still star-shaped,
	-- one wall point per ray, but each capital's character (M.STYLE) shapes
	-- it: the seeded budget noise (octaves NOISE_OCT), two harmonics that
	-- stretch the city toward its open ground (ECC1: off-centre toward the
	-- most buildable side, ECC2: elongated along the axis AXIS), a snap of
	-- every ray to the terrain near its reach (a crest, the brow of a
	-- slope or a shore ahead, within SNAP), little smoothing, and for an
	-- angular capital (POLY) straight wall faces between corners.
	---------------------------------------------------------------------------
	local T2 = os.clock()
	local NR = P.NRAY
	local noise = I.simplex(seed, "capital_outline")
	local RAYS = {}
	local rmax = {}
	local SL = 5   -- terrain snap: crest/brow half window, in samples (10 nodes)
	local open_c1, open_s1, open_c2, open_s2 = 0, 0, 0, 0
	for a = 1, NR do
		local phi = (a - 1) * 2 * pi / NR - pi
		local c, s = cos(phi), sin(phi)
		local m = max(abs(c), abs(s))
		local s0 = P.CORE / m
		rmax[a] = min((P.HALF - P.BAND) / m, 260)
		local cum, rr, hh, wet, dw = {}, {}, {}, {}, {}
		local acc = 0
		local r = s0
		local nopen, nall = 0, 0
		local shore_r   -- the first water beyond SHORE_STOP along the ray
		while r <= rmax[a] + 2 do
			local k = gk(r * c, r * s)
			local w = WET[k] and P.C_WET or (BUILD[k] and P.C_BUILD or P.C_STEEP)
			if WET[k] and not shore_r and r >= P.SHORE_STOP then shore_r = r end
			if shore_r then w = w * P.C_BEYOND end
			acc = acc + w * G
			cum[#cum + 1], rr[#rr + 1] = acc, r
			hh[#hh + 1], wet[#wet + 1], dw[#dw + 1] = TT[k], WET[k], DW[k]
			if r >= P.CORE_KEEP + 16 and not shore_r then
				nall = nall + 1
				if BUILD[k] then nopen = nopen + 1 end
			end
			r = r + G
		end
		-- the terrain score of every sample (independent of the budget): a
		-- crest or the brow of an outward slope, and a shore just ahead
		local terr = {}
		for j = 1, #rr do
			local h = hh[j]
			local hin, hout = hh[max(1, j - SL)], hh[min(#rr, j + SL)]
			local crest = h - 0.5 * (hin + hout)
			local brow = 0.5 * (h - hout)
			local shore = 0
			for q = j + 1, min(#rr, j + 8) do
				if wet[q] then shore = 1 break end
			end
			terr[j] = P.SNAP_T * max(crest, brow, 0) + P.SNAP_S * shore
		end
		local nz, wsum = 0, 0
		for _, o in ipairs(P.NOISE_OCT) do
			nz = nz + o[2] * noise(c * o[1] + (o[3] or 0), s * o[1] + (o[4] or 0))
			wsum = wsum + o[2]
		end
		local open = nall > 0 and nopen / nall or 0
		open_c1, open_s1 = open_c1 + open * c, open_s1 + open * s
		open_c2, open_s2 = open_c2 + open * cos(2 * phi), open_s2 + open * sin(2 * phi)
		RAYS[a] = {phi = phi, c = c, s = s, s0 = s0, cum = cum, r = rr, h = hh, wet = wet,
			dw = dw, terr = terr, nz = nz / wsum}
	end
	-- the character's harmonics, oriented by the open ground: ECC1 pushes
	-- the city toward its most buildable side (the core then sits off
	-- centre), ECC2 stretches it along the open ground's long axis ("open")
	-- or across the first harmonic ("across": along a lake shore). Where the
	-- ground is even all round, a seeded direction decides.
	do
		local mag1 = sqrt(open_c1 * open_c1 + open_s1 * open_s1) / NR
		local phi1 = mag1 > 0.02 and atan2(open_s1, open_c1) or (2 * vrand() - 1) * pi
		local phi2
		if P.AXIS == "across" then
			phi2 = phi1 + pi / 2
		else
			local mag2 = sqrt(open_c2 * open_c2 + open_s2 * open_s2) / NR
			phi2 = mag2 > 0.02 and 0.5 * atan2(open_s2, open_c2) or (2 * vrand() - 1) * pi
		end
		st.ecc_dir, st.axis_dir = phi1, phi2
		for a = 1, NR do
			local ray = RAYS[a]
			ray.f = max(0.35, 1 + P.BUDGET_NOISE * ray.nz + P.ECC1 * cos(ray.phi - phi1) +
				P.ECC2 * cos(2 * (ray.phi - phi2)))
		end
	end
	-- angular capitals: the corner rays (evenly spread, seeded jitter); each
	-- corner then takes the farthest-reaching ray near its nominal angle
	local corners
	if P.POLY then
		local K = P.POLY + floor(3 * vrand()) - 1
		local off = vrand()
		corners = {}
		for k = 0, K - 1 do
			local u = (k + off + 0.3 * (vrand() - 0.5)) / K
			corners[#corners + 1] = floor(u * NR) % NR + 1
		end
		table.sort(corners)
		st.corners = #corners
	end
	local function smooth(R, passes, w)
		for _ = 1, passes do
			local S = {}
			for a = 1, NR do
				local acc = 0
				for d = -w, w do acc = acc + R[(a - 1 + d) % NR + 1] end
				S[a] = acc / (2 * w + 1)
			end
			R = S
		end
		return R
	end
	local function outline_for(B)
		local R = {}
		for a = 1, NR do
			local ray = RAYS[a]
			local lim = B * ray.f
			local j0 = #ray.r
			for j = 1, #ray.cum do
				if ray.cum[j] >= lim then j0 = j break end
			end
			-- terrain snap: the best-scoring sample within SNAP of the reach
			-- (a crest, a brow, a shore ahead), off the banks, penalised by
			-- its distance from the reach
			local span = floor(P.SNAP / G)
			local best, bs = j0, ray.terr[j0]
			if span > 0 then
				for j = max(1, j0 - span), min(#ray.r, j0 + span) do
					if ray.dw[j] >= P.WALL_BANK + 2 and not ray.wet[j] then
						local u = (j - j0) / span
						local sc = ray.terr[j] - P.SNAP_D * u * u
						if sc > bs + 1e-9 then best, bs = j, sc end
					end
				end
			end
			R[a] = ray.r[best]
		end
		R = smooth(R, P.SMOOTH_PASSES, P.SMOOTH_W)
		-- no bays and no lobes (ruling 2): each ray stays within NOTCH of
		-- the broadly smoothed outline
		do
			local W = smooth(R, 3, 5)
			for a = 1, NR do
				R[a] = max(W[a] * (1 - P.NOTCH), min(W[a] * (1 + P.NOTCH), R[a]))
			end
		end
		for a = 1, NR do R[a] = max(P.R_MIN, min(rmax[a], R[a])) end
		if corners then
			-- straight faces between the corners (polar line through two
			-- corner points; each corner the farthest ray within a quarter
			-- of its spacing)
			local K = #corners
			local cp = {}
			for k = 1, K do
				local a0 = corners[k]
				local gap = ((corners[k % K + 1] - a0) % NR)
				local w = max(1, floor(gap / 5))
				local ba, br = a0, R[a0]
				for d = -w, w do
					local a = (a0 - 1 + d) % NR + 1
					if R[a] > br then ba, br = a, R[a] end
				end
				cp[k] = ba
			end
			local S = {}
			for k = 1, K do
				local a1, a2 = cp[k], cp[k % K + 1]
				local p1, p2 = RAYS[a1].phi, RAYS[a2].phi
				local r1, r2 = R[a1], R[a2]
				local span = wrap(p2 - p1)
				if span <= 0 then span = span + 2 * pi end
				local n = (a2 - a1) % NR
				if n == 0 then n = NR end
				for d = 0, n - 1 do
					local a = (a1 - 1 + d) % NR + 1
					local t = wrap(RAYS[a].phi - p1)
					if t < 0 then t = t + 2 * pi end
					S[a] = r1 * r2 * sin(span) / (r1 * sin(t) + r2 * sin(span - t))
				end
			end
			for a = 1, NR do R[a] = max(P.R_MIN, min(rmax[a], S[a] or R[a])) end
		end
		-- the wall keeps off banks: a ray whose outline point lies within
		-- WALL_BANK of water moves to the nearest point that does not
		-- (inward first on ties, within 40), and the rays round a moved one
		-- are smoothed lightly. Where a river crosses the outline the
		-- neighbouring rays snap to opposite banks and the wall crosses it
		-- short (an arcade).
		for _ = 1, (P.WALL_BANK > 0 and 3 or 0) do
			local moved = {}
			for a = 1, NR do
				local ray = RAYS[a]
				local function bad(r) return DW[gk(r * ray.c, r * ray.s)] < P.WALL_BANK end
				if bad(R[a]) then
					for d = 2, 40, 2 do
						local ri, ro = R[a] - d, R[a] + d
						if ri >= P.R_MIN and not bad(ri) then R[a] = ri; moved[a] = true break end
						if ro <= rmax[a] and not bad(ro) then R[a] = ro; moved[a] = true break end
					end
				end
			end
			local S = {}
			for a = 1, NR do
				local near = false
				for d = -2, 2 do if moved[(a - 1 + d) % NR + 1] then near = true end end
				S[a] = near and (0.25 * R[(a - 2) % NR + 1] + 0.5 * R[a] + 0.25 * R[a % NR + 1]) or R[a]
			end
			R = S
		end
		-- Round 26 playtest (the wall dipping into a river). The segment from
		-- ray a to the next: whether it crosses water (interior samples of
		-- the planner grid), and whether any of that water is the civic lake
		-- (which is the edge, M.shore_flags, and never steered round here).
		local function seg_wet(a, ra, rb)
			local b = a % NR + 1
			ra, rb = ra or R[a], rb or R[b]
			local ax, az = ra * RAYS[a].c, ra * RAYS[a].s
			local vx, vz = rb * RAYS[b].c - ax, rb * RAYS[b].s - az
			local steps = max(1, floor(sqrt(vx * vx + vz * vz) / G))
			local wet, civic, n = false, false, 0
			for k = 1, steps - 1 do
				local x, z = ax + vx * k / steps, az + vz * k / steps
				if WET[gk(x, z)] then
					wet, n = true, n + 1
					if I.shore_distance and I.shore_distance(AX + floor(x + 0.5), AZ + floor(z + 0.5)) <= 0 then
						civic = true
					end
				end
			end
			return wet, civic, n
		end
		-- wet samples on the wall from ray f1 to ray f2
		local function chain_wet(f1, f2)
			local n, a = 0, f1
			repeat
				local _, _, k = seg_wet(a)
				n = n + k
				a = a % NR + 1
			until a == f2
			return n
		end
		-- how much water the wall crosses on either side of ray a with the
		-- ray at r: wet grid samples (every G) on the segments from both
		-- neighbours to it, the ray's own point included
		local function wet_around(a, r)
			local wet = 0
			local rx, rz = r * RAYS[a].c, r * RAYS[a].s
			for _, q in ipairs({(a - 2) % NR + 1, a % NR + 1}) do
				local qx, qz = R[q] * RAYS[q].c, R[q] * RAYS[q].s
				local vx, vz = qx - rx, qz - rz
				local steps = max(1, floor(sqrt(vx * vx + vz * vz) / G))
				for k = 0, steps - 1 do
					if WET[gk(rx + vx * k / steps, rz + vz * k / steps)] then wet = wet + 1 end
				end
			end
			return wet
		end
		-- A short run of rays (at most BANK_RUN) whose wall crosses the same
		-- river on both sides of it -- the run on one bank, its neighbours on
		-- the other -- moves to the neighbours' bank (the dry point nearest
		-- the line between them, within 50), so the wall follows one bank
		-- instead of dipping across the water and back. The move stands only
		-- when the wall from neighbour to neighbour then crosses less water
		-- than before (a river along a ray, or two separate streams, keep
		-- their crossings); the civic lake is left alone.
		for _ = 1, (P.WALL_BANK > 0 and 2 or 0) do
			local changed = false
			for a0 = 1, NR do
				local w0, c0 = seg_wet(a0)
				if w0 and not c0 then
					local len, e, we, ce = 0, a0, false, false
					repeat
						e = e % NR + 1
						len = len + 1
						we, ce = seg_wet(e)
					until we or len > P.BANK_RUN
					if we and not ce and len <= P.BANK_RUN and e ~= a0 then
						local f1, f2 = a0, e % NR + 1
						local moves = {}
						for k = 1, len do
							local a = (a0 - 1 + k) % NR + 1
							local ray = RAYS[a]
							local target = R[f1] + (R[f2] - R[f1]) * k / (len + 1)
							local found
							for d = 0, 50, 2 do
								for _, r in ipairs({target - d, target + d}) do
									if not found and r >= P.R_MIN and r <= rmax[a] and
											DW[gk(r * ray.c, r * ray.s)] >= P.WALL_BANK then
										found = r
									end
								end
								if found then break end
							end
							if not found then moves = nil break end
							moves[#moves + 1] = {a, found}
						end
						if moves then
							local old, before = {}, chain_wet(f1, f2)
							for _, m in ipairs(moves) do old[m[1]] = R[m[1]]; R[m[1]] = m[2] end
							if chain_wet(f1, f2) < before then
								for _, m in ipairs(moves) do
									if abs(old[m[1]] - m[2]) > 1 then changed = true end
								end
							else
								for _, m in ipairs(moves) do R[m[1]] = old[m[1]] end
							end
						end
					end
				end
			end
			if not changed then break end
		end
		-- Round 26 playtest (a V into the river): the smoothing above can
		-- leave a ray back on a bank or in the water between neighbours that
		-- stand on the far bank. A last pass without smoothing moves every
		-- such ray to the dry point (within 40) nearest the mean of its two
		-- neighbours, so it follows them instead of dipping into the river --
		-- never to a point whose segments to its neighbours cross more water
		-- than they did (a river along the ray keeps the ray where it is:
		-- moved along it, the wall would cross the river twice). A ray on or
		-- by the civic lake stays: the lake is the edge (M.shore_flags).
		for _ = 1, (P.WALL_BANK > 0 and 3 or 0) do
			local any = false
			for a = 1, NR do
				local ray = RAYS[a]
				local function bad(r) return DW[gk(r * ray.c, r * ray.s)] < P.WALL_BANK end
				local civic = I.shore_distance and I.shore_distance(AX + floor(R[a] * ray.c + 0.5),
					AZ + floor(R[a] * ray.s + 0.5)) < P.WALL_BANK
				if bad(R[a]) and not civic then
					local target = 0.5 * (R[(a - 2) % NR + 1] + R[a % NR + 1])
					local lo_r, hi_r = max(P.R_MIN, R[a] - 40), min(rmax[a], R[a] + 40)
					local wet0 = wet_around(a, R[a])
					local done = false
					for d = 0, 80, 2 do
						local c1, c2 = target - d, target + d
						if abs(c2 - R[a]) < abs(c1 - R[a]) then c1, c2 = c2, c1 end
						for _, r in ipairs({c1, c2}) do
							if not done and r >= lo_r and r <= hi_r and not bad(r) and
									wet_around(a, r) <= wet0 then
								R[a], done, any = r, true, true
							end
						end
						if done then break end
					end
				end
			end
			if not any then break end
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
	-- the outline smoothed as before Round 26: the ring lanes follow it, so
	-- an irregular wall does not make them zigzag
	local RS = smooth(R, 4, 4)
	local rs_mean = 0
	for a = 1, NR do rs_mean = rs_mean + RS[a] / NR end
	local function rs_at(phi)
		local u = (wrap(phi) + pi) / (2 * pi) * NR
		local a = floor(u)
		local f = u - a
		local r1, r2 = RS[a % NR + 1], RS[(a + 1) % NR + 1]
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
				local rx, rz = e.x - g.ox, e.z - g.oz
				local d = sqrt(rx * rx + rz * rz)
				if not bd or d < bd then best, bd = g, d end
			end
			e.gate = best.c
			best.ends[#best.ends + 1] = e
		end
		for _, g in ipairs(gates) do
			local base = CARD[g.c].ang
			-- Round 26: a character may turn every gate the same way off its
			-- cardinal ray (a pinwheel of avenues), never beyond GATE_MAX_ANGLE
			local phi = base + P.GATE_TWIST
			if #g.ends > 0 then
				local sx, sz = 0, 0
				for _, e in ipairs(g.ends) do
					local a = atan2(e.z, e.x)
					sx, sz = sx + cos(a), sz + sin(a)
				end
				local d = wrap(atan2(sz, sx) - phi)
				local lim = P.GATE_SLIDE / r_at(base)
				phi = phi + max(-lim, min(lim, d))
			end
			phi = base + max(-P.GATE_MAX_ANGLE, min(P.GATE_MAX_ANGLE, wrap(phi - base)))
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
	-- Round 26 playtest: the wall meets every gatehouse across its passage.
	-- A gatehouse box is compass-aligned; where the outline passed the gate
	-- at a steep angle (a slid or turned gate on an irregular outline) the
	-- wall ran into the box's front or back face, or along the passage, and
	-- stopped short of it. So the rays whose outline point lies within
	-- GATE_WIDTH + GATE_FLAT of the gate (across its axis) move onto the
	-- straight line through the gate at right angles to its axis, and the
	-- next GATE_BLEND rays on either side ease back to the outline. The line
	-- keeps off the water like the outline: going out from the gate, a side
	-- stops at the first ray beyond the box whose point on the line lies
	-- within WALL_BANK of water (a river, the civic lake) or outside the
	-- ray's radius bounds (clamped, it would leave the line), and a blended
	-- ray that would come that near water stays on the outline.
	do
		local flat_w, near = {}, {}
		local function bad(a, r)
			local ray = RAYS[a]
			return DW[gk(r * ray.c, r * ray.s)] < P.WALL_BANK
		end
		for _, g in ipairs(gates) do
			local c0 = g.x * g.dx + g.z * g.dz
			local function line_r(a)
				local ray = RAYS[a]
				local den = ray.c * g.dx + ray.s * g.dz
				if den < 0.3 then return nil end
				local r = c0 / den
				local ww = -(r * ray.c - g.x) * g.dz + (r * ray.s - g.z) * g.dx
				return r, ww
			end
			local cand = {}
			for a = 1, NR do
				local r, ww = line_r(a)
				if r and abs(ww) <= P.GATE_WIDTH + P.GATE_FLAT then cand[#cand + 1] = {a, r, ww} end
			end
			table.sort(cand, function(u, v)
				if abs(u[3]) ~= abs(v[3]) then return abs(u[3]) < abs(v[3]) end
				return u[1] < v[1]
			end)
			local run, stopped = {}, {}
			for _, c in ipairs(cand) do
				local a, r, ww = c[1], c[2], c[3]
				local side = ww < 0 and 1 or 2
				if not stopped[side] then
					if abs(ww) > P.GATE_WIDTH + 1 and (bad(a, r) or r < P.R_MIN or r > rmax[a]) then
						stopped[side] = true
					else
						run[#run + 1] = a
						flat_w[a] = r
					end
				end
			end
			for _, a0 in ipairs(run) do
				for d = 1, P.GATE_BLEND do
					for sg = -1, 1, 2 do
						local a = (a0 - 1 + sg * d) % NR + 1
						if not flat_w[a] then
							local r = line_r(a)
							if r then
								local w = 1 - d / (P.GATE_BLEND + 1)
								if not near[a] or w > near[a][2] then near[a] = {r, w} end
							end
						end
					end
				end
			end
		end
		for a = 1, NR do
			if flat_w[a] then
				R[a] = max(P.R_MIN, min(rmax[a], flat_w[a]))
			elseif near[a] then
				local r, w = near[a][1], near[a][2]
				local b = max(P.R_MIN, min(rmax[a], w * r + (1 - w) * R[a]))
				if not bad(a, b) or bad(a, R[a]) then R[a] = b end
			end
		end
		area = 0
		for a = 1, NR do area = area + 0.5 * R[a] * R[a] * 2 * pi / NR end
		st.area = area
	end
	st.t.gates = os.clock() - T3
	-- Round 27 playtest (the wall is closed everywhere except at its
	-- gatehouses): the outline is final here, and the wall polyline is the
	-- straight line between its ray points (`wall.pts` below resamples
	-- exactly that ring). `wall_dist(lx, lz)` is a column's distance from it,
	-- capped at WALL_REACH; `box_dist` its distance from the nearest
	-- gatehouse box. Streets, squares and the plaza keep their surface off
	-- the wall band with these, so no road surface lies on the wall line
	-- away from a gate (the writer never builds over one).
	-- WALL_REACH caps the distance search, so it must stay ABOVE every
	-- threshold wall_dist is compared with below: the spoke end's
	-- SPOKE_IN - 2 (28 at the default 30, the largest), a square's or the
	-- plaza's radius + WALL_HALF + 4, a junction's and a lane cell's
	-- WALL_CLEAR_ST + 8 and a connector's WALL_CLEAR_ST + 5.5. A capped
	-- answer then reads as "clear" exactly where the true distance would.
	local WALL_REACH = max(32, P.SPOKE_IN + 1, max(P.PLAZA or 0, P.SQUARE_R) + P.WALL_HALF + 5)
	local WB = 8
	local wall_bk = {}
	local wall_xz = {}
	for a = 1, NR do wall_xz[a] = {R[a] * RAYS[a].c, R[a] * RAYS[a].s} end
	for a = 1, NR do
		local p, q = wall_xz[a], wall_xz[a % NR + 1]
		for bz = floor((min(p[2], q[2]) - WALL_REACH) / WB), floor((max(p[2], q[2]) + WALL_REACH) / WB) do
			for bx = floor((min(p[1], q[1]) - WALL_REACH) / WB), floor((max(p[1], q[1]) + WALL_REACH) / WB) do
				local k = bz * 65536 + bx
				local l = wall_bk[k]
				if not l then l = {}; wall_bk[k] = l end
				l[#l + 1] = a
			end
		end
	end
	local function wall_dist(lx, lz)
		local l = wall_bk[floor(lz / WB) * 65536 + floor(lx / WB)]
		local best = WALL_REACH
		if not l then return best end
		for m = 1, #l do
			local a = l[m]
			local p, q = wall_xz[a], wall_xz[a % NR + 1]
			local vx, vz = q[1] - p[1], q[2] - p[2]
			local l2 = vx * vx + vz * vz
			local u = l2 > 0 and ((lx - p[1]) * vx + (lz - p[2]) * vz) / l2 or 0
			if u < 0 then u = 0 elseif u > 1 then u = 1 end
			local dx, dz = lx - p[1] - u * vx, lz - p[2] - u * vz
			local d = sqrt(dx * dx + dz * dz)
			if d < best then best = d end
		end
		return best
	end
	local function box_dist(lx, lz)
		local best = INF
		for _, g in ipairs(gates) do
			local dd = abs((lx - g.x) * g.dx + (lz - g.z) * g.dz) - P.GATE_DEPTH - 0.5
			local ww = abs(-(lx - g.x) * g.dz + (lz - g.z) * g.dx) - P.GATE_WIDTH - 0.5
			dd, ww = max(0, dd), max(0, ww)
			local d = sqrt(dd * dd + ww * ww)
			if d < best then best = d end
		end
		return best
	end
	-- a street keeps its surface edge this far from the wall's centre line
	-- (the writer's band reaches WALL_HALF + 1/2, then a node and a half of
	-- clearance), a square its rim
	local WALL_CLEAR_ST = P.WALL_HALF + 2
	local function wall_hit(road)
		local X, Z = road.X, road.Z
		for i = 1, #X do
			if wall_dist(X[i] - AX, Z[i] - AZ) - road.hw < WALL_CLEAR_ST then return true end
		end
		return false
	end
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
	-- the network's roads reaching into the sampled square: a street or
	-- connector touching one takes its level there (road module contacts, D49)
	local fixed = {}
	for _, r in ipairs(I.network_roads or {}) do
		for i = 1, #r.X, 4 do
			if max(abs(r.X[i] - AX), abs(r.Z[i] - AZ)) <= EXT + 16 then
				fixed[#fixed + 1] = r
				break
			end
		end
	end
	local kit = city.build(seed, {
		fixed = fixed,
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
	local LI = kit.LI
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
			local v = fn(lx, lz, li)
			if v and v > 0 then g[li] = v end
		end
		return g
	end
	-- a lattice cell's wall distance, once per plan (every search attempt
	-- builds its guide over all cells)
	local cell_wd = {}
	local function cell_wall_dist(lx, lz, li)
		local d = cell_wd[li]
		if not d then
			d = wall_dist(lx, lz)
			cell_wd[li] = d
		end
		return d
	end
	-- Round 27: a lane's search keeps off the wall band (a lane that still
	-- reaches it is cut back or not built, `lane_to`), a 4-node cell's
	-- width of margin beyond a lane's clearance
	local function wall_cost(lx, lz, li)
		if cell_wall_dist(lx, lz, li) < WALL_CLEAR_ST + 2.5 + 4 then return 12 end
		return 0
	end
	local function outside_cost(lx, lz, margin, k)
		local r = sqrt(lx * lx + lz * lz)
		local ro = r_at(atan2(lz, lx)) - margin
		if r > ro then return k * (1 + (r - ro) / 4) end
		return 0
	end
	local streets = {}      -- ordered list of {road, role, quadrant(s)}
	local function route(src_li, src_dir, target, heur_xz, guide, budget_mult)
		kit.set_guide(guide)
		local tx, tz = heur_xz[1], heur_xz[2]
		local mm = kit.minmult
		local sx, sz = li_local(src_li)
		local rx, rz = sx - tx, sz - tz
		local budget = (budget_mult or P.SEARCH_BUDGET) * sqrt(rx * rx + rz * rz) + 400
		local path, info = kit.search({{src_li, src_dir, 0}}, target, function(li)
			local x, z = li_local(li)
			local hx, hz = x - tx, z - tz
			return sqrt(hx * hx + hz * hz) * mm
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
	-- 5a. avenues: core gate -> through the city gate to its outer point.
	-- An avenue never ends over water: where the civic core's edge on its
	-- axis is civic water without a core landing (Lethariel's crown mere),
	-- it starts on the dry shore nearest the core gate instead (a lakeside
	-- end, not pinned to the core); where its gate has no connector and the
	-- ground outside the gate is wet, it runs on to the first dry ground.
	local avenues = {}
	local core_y = t_at(0, 0)
	local function dry_along(x0, z0, dx, dz, from, to)
		for r = from, to, G do
			local ok = true
			for k = 0, 2 * G, G do
				if wet_at(x0 + dx * (r + k), z0 + dz * (r + k)) then ok = false end
			end
			if ok then return r end
		end
		return nil
	end
	for c = 1, 4 do
		local g = gates[c]
		local dx, dz = g.dx, g.dz
		local a0 = {dx * (P.CORE_GATE + 1), dz * (P.CORE_GATE + 1)}
		local a1 = {dx * (CK + 8), dz * (CK + 8)}
		local b1 = {g.ix - dx * 8, g.iz - dz * 8}
		local pin_a = floor(core_y * Q + 0.5) / Q
		local landed = not wet_at(dx * (P.CORE - 2), dz * (P.CORE - 2)) or
			(I.core_landing ~= nil and I.core_landing(dx, dz))
		if not landed then
			-- the dry point (with a dry ring around it) nearest the core
			-- gate, beyond the kept core distance and short of the gate
			local reach = floor(sqrt(b1[1] * b1[1] + b1[2] * b1[2])) - 24
			local best, bd
			for along = CK + 2, reach, G do
				for across = -reach, reach, G do
					local x, z = dx * along + dz * across, dz * along - dx * across
					local rx, rz = x - a0[1], z - a0[2]
					local d = rx * rx + rz * rz
					if (not bd or d < bd) and max(abs(x), abs(z)) >= CK + 2 then
						local ok = true
						for ox = -2 * G, 2 * G, G do
							for oz = -2 * G, 2 * G, G do
								if wet_at(x + ox, z + oz) then ok = false end
							end
						end
						if ok then best, bd = {x, z}, d end
					end
				end
			end
			if best then
				local vx, vz = b1[1] - best[1], b1[2] - best[2]
				local l = sqrt(vx * vx + vz * vz)
				a0 = best
				a1 = {best[1] + 8 * vx / l, best[2] + 8 * vz / l}
				pin_a = nil
				st.shore_avenues = (st.shore_avenues or 0) + 1
			else
				st.wet_avenue_ends = (st.wet_avenue_ends or 0) + 1
			end
		end
		local tail = {b1, {g.ix, g.iz}, {g.x, g.z}, {g.ox, g.oz}}
		local runout = 0
		if #g.ends == 0 and wet_at(g.ox, g.oz) then
			local r = dry_along(g.ox, g.oz, dx, dz, G, 48)
			if r then
				runout = r + 2
				tail[#tail + 1] = {g.ox + dx * runout, g.oz + dz * runout}
				st.gate_runouts = (st.gate_runouts or 0) + 1
			else
				st.wet_avenue_ends = (st.wet_avenue_ends or 0) + 1
			end
		end
		local src = cell_li(a1[1] + dx * C, a1[2] + dz * C)
		local tgt = cell_li(b1[1], b1[2])
		-- inside the outline, and a mild pull toward the straight line core
		-- gate -> city gate (avenues bend with the terrain, never detour)
		local vx, vz = b1[1] - a1[1], b1[2] - a1[2]
		local l2 = vx * vx + vz * vz
		local guide = guide_for(function(lx, lz)
			local u = max(0, min(1, ((lx - a1[1]) * vx + (lz - a1[2]) * vz) / l2))
			local rx, rz = lx - a1[1] - u * vx, lz - a1[2] - u * vz
			local d = sqrt(rx * rx + rz * rz)
			local dq = d / 16
			return outside_cost(lx, lz, 10, 4) + min(P.AVENUE_GUIDE_MAX, P.AVENUE_GUIDE * (dq * dq))
		end)
		local path = route(src, dir_index(dx, dz), function(li, d)
			if li == tgt then return {kind = "node"} end
		end, b1, guide)
		local ctrl
		if path then
			ctrl = ctrl_from(path, {a0, a1}, tail)
		else
			st.failed = (st.failed or 0) + 1
			ctrl = {{AX + a0[1], AZ + a0[2]}, {AX + g.x, AZ + g.z}}
			for i = 4, #tail do ctrl[#ctrl + 1] = {AX + tail[i][1], AZ + tail[i][2]} end
		end
		local road = kit.street("avenue", ctrl, {a = "core_" .. g.name, b = "gate_" .. g.name,
			pin_a = pin_a, flat_a = 6,
			-- the gate end is flat through the passage but not pinned: the
			-- gate floor takes the avenue's level (set after the final solve)
			-- (a run-out to dry ground stays at that level)
			flat_b = 2 * P.GATE_DEPTH + 10 + runout})
		kit.commit(road)
		road.role, road.gate = "avenue", c
		avenues[c] = road
		streets[#streets + 1] = road
	end
	-- 5b. ring lanes: per quadrant an arc from avenue q to avenue q+1. A
	-- ring follows the smoothed outline at its fraction of the way from the
	-- core gate to the wall; a "circle" ring (M.STYLE RING_SHAPE) keeps one
	-- radius round the core instead, never nearer the wall than the outline
	-- ring at 0.8
	-- ("wall": along the unsmoothed outline, an angular capital's straight
	-- faces). Where the city reaches far out (an off-centre or elongated
	-- outline) the outer ring keeps within RING_WALL_MAX of the wall and the
	-- inner one within RING_GAP_MAX of the outer, so the wide side is not
	-- left without streets.
	local ring_r, ring_loose
	-- Round 26: the inner ring may sit nearer the core on one side and
	-- further out on the other (RING_WOBBLE, a seeded direction)
	local wobble_phi = (2 * vrand() - 1) * pi
	ring_r = function(ri, phi)
		local frac = P.RINGS[ri]
		if ri == 1 and #P.RINGS > 1 then frac = frac * (1 + P.RING_WOBBLE * cos(phi - wobble_phi)) end
		local shape = P.RING_SHAPE and P.RING_SHAPE[ri]
		local base = shape == "wall" and r_at(phi) or rs_at(phi)
		local r
		if ring_loose then frac = frac * ring_loose end
		if shape == "circle" then
			r = min(P.CORE_GATE + frac * (rs_mean - P.CORE_GATE),
				P.CORE_GATE + 0.8 * (base - P.CORE_GATE))
		else
			r = P.CORE_GATE + frac * (base - P.CORE_GATE)
		end
		if ring_loose or #P.RINGS == 1 then
			return r
		elseif ri == #P.RINGS then
			r = max(r, base - P.RING_WALL_MAX)
		elseif ri == #P.RINGS - 1 then
			r = max(r, ring_r(#P.RINGS, phi) - P.RING_GAP_MAX)
		end
		return r
	end
	local function avenue_index_at(road, ri)
		-- first centreline point whose radius reaches the ring
		local best
		for i = 1, #road.X do
			local lx, lz = road.X[i] - AX, road.Z[i] - AZ
			if sqrt(lx * lx + lz * lz) >= ring_r(ri, atan2(lz, lx)) then best = i break end
		end
		best = best or floor(#road.X / 2)
		-- a junction needs dry, ground-supported parent points around it
		-- (not on a bridge or a deck): the nearest such index within 40
		local function dry_ok(i)
			for j = max(1, i - 10), min(#road.X, i + 10) do
				if road.cls[j] ~= "G" then return false end
				if wet_at(road.X[j] - AX, road.Z[j] - AZ) then return false end
				local lx, lz = road.X[j] - AX, road.Z[j] - AZ
				if DW[gk(lx, lz)] < 6 then return false end
			end
			return true
		end
		-- Round 27: a junction (and the square a crossing may get) keeps
		-- well off the wall, never at the gatehouse's inner mouth; `by_wall`
		-- notes a point that was dry enough and only too near the wall
		local by_wall = false
		local function ok(i)
			if wall_dist(road.X[i] - AX, road.Z[i] - AZ) < WALL_CLEAR_ST + 8 then
				if not by_wall and dry_ok(i) then by_wall = true end
				return false
			end
			return dry_ok(i)
		end
		for d = 0, 40 do
			if best + d <= #road.X - 12 and ok(best + d) then return best + d end
			if best - d >= 12 and ok(best - d) then return best - d end
		end
		if by_wall then
			st.junction_wall = (st.junction_wall or 0) + 1
		else
			st.junction_wet = (st.junction_wet or 0) + 1
		end
		return best
	end
	local rings = {}
	local squares = {}       -- {x, z, road, idx | y, why}: flat paved squares
	local function add_square(road, idx, why)
		local x, z = road.X[idx] - AX, road.Z[idx] - AZ
		for _, q in ipairs(squares) do
			local rx, rz = q.x - x, q.z - z
			if rx * rx + rz * rz < 14 * 14 then return end
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
		-- Round 27 playtest: a lane keeps its surface off the wall band. A
		-- dead end (a spoke, an open arc, a dead-end cross-lane) is cut back
		-- from its far end one control point at a time until it clears the
		-- wall; a lane between two streets that reaches the band is not built
		-- (the caller tries its next option).
		if wall_hit(road) then
			if ff.b_parent then
				st.lanes_rejected = (st.lanes_rejected or 0) + 1
				st.lanes_wall = (st.lanes_wall or 0) + 1
				return nil
			end
			local c = #ctrl
			while wall_hit(road) and c > #head + 2 do
				c = c - 1
				local cut = {}
				for i = 1, c do cut[i] = ctrl[i] end
				road = kit.street("lane", cut, ff)
			end
			if wall_hit(road) or #road.X < 32 then
				st.lanes_rejected = (st.lanes_rejected or 0) + 1
				st.lanes_wall = (st.lanes_wall or 0) + 1
				return nil
			end
			st.lanes_trimmed = (st.lanes_trimmed or 0) + 1
		end
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
	for ri in ipairs(P.RINGS) do
		for q = 1, 4 do
			local road
			-- D70: some outer arcs stop halfway in a small square (Round 26:
			-- the share and the count by character; an inner arc too where
			-- the character opens its inner ring)
			local share = ri == #P.RINGS and P.RING2_OPEN or (P.RING1_OPEN or 0)
			local open = nopen < P.OPEN_MAX and vrand() < share
			local from_b = vrand() < 0.5
			local u_end = 0.45 + 0.2 * vrand()
			-- attempts: A -> B; B -> A; A -> B with a wider target window;
			-- a chosen open arc comes first and falls back to a closed one;
			-- a closed arc that finds no route falls back to open arcs
			-- (dead ends in a square) from either side
			-- (Round 26: a ring kept near a far wall that finds no route --
			-- e.g. across a river -- retries at its plain fraction and then a
			-- little further in: `ring_loose` scales the fraction, no bound)
			local modes = {{false, false, 10}, {false, true, 10}, {false, false, 30},
				{false, false, 10, 1}, {false, true, 10, 1}, {false, false, 10, 0.85},
				{false, true, 10, 0.85}}
			if open then table.insert(modes, 1, {true, from_b, 10})
			else modes[#modes + 1] = {true, false, 10}; modes[#modes + 1] = {true, true, 10} end
			for attempt, mode in ipairs(modes) do
				ring_loose = mode[4]
				local A, B = avenues[q], avenues[q % 4 + 1]
				local is_open = mode[1]
				if mode[2] then A, B = B, A end
				local span = mode[3]
				local ia, ib = avenue_index_at(A, ri), avenue_index_at(B, ri)
				local ax, az = A.X[ia] - AX, A.Z[ia] - AZ
				local bx, bz = B.X[ib] - AX, B.Z[ib] - AZ
				local nx_, nz_ = unit_normal_toward(A, ia, bx - ax, bz - az)
				local s1 = {ax + nx_ * 10, az + nz_ * 10}
				local src = cell_li(s1[1], s1[2])
				local phi_a, phi_b = atan2(az, ax), atan2(bz, bx)
				local guide = guide_for(function(lx, lz, li)
					local r = sqrt(lx * lx + lz * lz)
					local phi = atan2(lz, lx)
					local u = wrap(phi - phi_a) / wrap(phi_b - phi_a)
					local g = outside_cost(lx, lz, 14, 10) + wall_cost(lx, lz, li)
					if u < -0.05 or u > 1.05 then g = g + 20 end
					local dr = (r - ring_r(ri, phi)) / 10
					return g + min(8, P.RING_GUIDE * dr * dr)
				end)
				if is_open then
					local pt = phi_a + u_end * wrap(phi_b - phi_a)
					local rt = ring_r(ri, pt)
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
	ring_loose = nil
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
		n = min(P.CROSS_MAX, floor(n * P.CROSS_MEAN + 0.5))
		-- Round 26: a fixed count at even spacing (CROSS_FIXED: a star of
		-- radial streets); none where the city has one ring (spokes instead)
		if P.CROSS_FIXED then n = P.CROSS_FIXED end
		if #P.RINGS == 1 then n = 0 end
		for k = 1, (r1 and n or 0) do
			local u = (k - 0.5) / n + (P.CROSS_FIXED and 0 or (0.3 * vrand() - 0.15) / n)
			local i1 = max(20, min(#r1.X - 20, floor(u * #r1.X + 0.5)))
			local ok = true
			for _, j in ipairs(r1.junctions) do if abs(j.idx - i1) < 18 then ok = false end end
			if ok then
				local ax, az = r1.X[i1] - AX, r1.Z[i1] - AZ
				local nx_, nz_ = unit_normal_toward(r1, i1, ax, az)   -- outward
				local s1 = {ax + nx_ * 8, az + nz_ * 8}
				local src = cell_li(s1[1], s1[2])
				local phi_u = atan2(az, ax)
				local guide = guide_for(function(lx, lz, li)
					local r = sqrt(lx * lx + lz * lz)
					local dphi = wrap(atan2(lz, lx) - phi_u)
					local g = outside_cost(lx, lz, 14, 10) + wall_cost(lx, lz, li)
					local t = dphi * r / 12
					return g + min(10, 1.5 * (t * t))
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
				local rt = ring_r(#P.RINGS, phi_u)
				local tx, tz = rt * cos(phi_u), rt * sin(phi_u)
				local road
				if B then
					road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, B, tset, nil, guide,
						{a_parent = r1.id, b_parent = B.id}, {tx, tz})
				end
				if not road then
					-- dead end: halfway out, ending in a square
					local rd = 0.5 * (ring_r(1, phi_u) + rt)
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
	-- Round 26 spokes: lanes from the outer ring out toward the wall, where
	-- the band beyond the ring is wide (SPOKE_MIN), each ending in a square
	-- SPOKE_IN inside the wall; SPOKES per outer arc, evenly spaced
	-- (SPOKE_FIXED) or jittered
	local nspoke = 0
	for q = 1, 4 do
		for _, ro in ipairs(rings) do
			if P.SPOKES > 0 and ro.quadrant == q and ro.ring == #P.RINGS then
				local n = P.SPOKES
				for k = 1, n do
					local u = (k - 0.5) / n + (P.SPOKE_FIXED and 0 or (0.3 * vrand() - 0.15) / n)
					-- the nominal point, else the nearest one 20 or 30 points
					-- along that is clear of junctions and has the room
					local i0 = floor(u * #ro.X + 0.5)
					local i1, ax, az, phi_u, rd
					for _, d in ipairs({0, 20, -20, 30, -30}) do
						local i = i0 + d
						local ok = i >= 20 and i <= #ro.X - 20 and not (ro.open and i > #ro.X - 24)
						for _, j in ipairs(ro.junctions) do if abs(j.idx - i) < 18 then ok = false end end
						if ok then
							local x, z = ro.X[i] - AX, ro.Z[i] - AZ
							local ph = atan2(z, x)
							local r_end = r_at(ph) - P.SPOKE_IN
							-- Round 27: SPOKE_IN from the wall itself, which
							-- comes nearer than its radius at that angle where
							-- it runs slanted (a jagged outline)
							local cph, sph = cos(ph), sin(ph)
							while r_end > 0 and wall_dist(r_end * cph, r_end * sph) < P.SPOKE_IN - 2 do
								r_end = r_end - 2
							end
							-- not alongside an avenue (its gate's direction)
							for _, g in ipairs(gates) do
								if abs(wrap(ph - g.phi)) < 0.25 then r_end = -INF end
							end
							if r_end - sqrt(x * x + z * z) >= P.SPOKE_MIN then
								i1, ax, az, phi_u, rd = i, x, z, ph, r_end
								break
							end
						end
					end
					if i1 then
						local nx_, nz_ = unit_normal_toward(ro, i1, ax, az)   -- outward
						local s1 = {ax + nx_ * 8, az + nz_ * 8}
						local src = cell_li(s1[1], s1[2])
						local guide = guide_for(function(lx, lz, li)
							local r = sqrt(lx * lx + lz * lz)
							local dphi = wrap(atan2(lz, lx) - phi_u)
							local t = dphi * r / 12
							return outside_cost(lx, lz, 14, 10) + wall_cost(lx, lz, li) + min(10, 1.5 * (t * t))
						end)
						local dx, dz = rd * cos(phi_u), rd * sin(phi_u)
						local tcell = cell_li(dx, dz)
						local road
						if src and tcell and not wet_at(dx, dz) and DW[gk(dx, dz)] >= 6 then
							road = lane_to(src, dir_index(nx_, nz_), {{ax, az}, s1}, nil, nil, tcell, guide,
								{a_parent = ro.id}, {dx, dz})
						end
						if road then
							nspoke = nspoke + 1
							road.role, road.quadrant = "spoke", q
							streets[#streets + 1] = road
							add_square(road, #road.X, "lane end")
						end
					end
				end
			end
		end
	end
	st.spokes = nspoke
	-- Round 26 plaza (PLAZA = its largest radius): one large flat square on
	-- the avenue of the city's long side, where that avenue is flattest
	-- between the core and the outer ring; it replaces the small squares it
	-- covers (it still shrinks until every street through it stays within
	-- 1/2 of its level)
	if P.PLAZA then
		local c0, rbest
		for c = 1, 4 do
			if avenues[c] and (not rbest or gates[c].r > rbest) then c0, rbest = c, gates[c].r end
		end
		local av = avenues[c0]
		local lo_i, hi_i = avenue_index_at(av, 1), avenue_index_at(av, #P.RINGS)
		local reach = P.PLAZA + 4
		local bi, bs
		for i = max(12, lo_i - 10), min(#av.X - 20, hi_i) do
			local lx, lz = av.X[i] - AX, av.Z[i] - AZ
			if max(abs(lx), abs(lz)) > CK + P.PLAZA + 2 and not wet_at(lx, lz) and
					wall_dist(lx, lz) >= P.PLAZA + WALL_CLEAR_ST + 2 then
				local dev = 0
				for j = max(1, i - reach), min(#av.X, i + reach) do
					dev = max(dev, abs(av.R[j] - av.R[i]))
				end
				local sc = dev + 0.02 * abs(i - lo_i)
				if not bs or sc < bs then bi, bs = i, sc end
			end
		end
		if bi then
			local x, z = av.X[bi] - AX, av.Z[bi] - AZ
			local kept = {}
			for _, q in ipairs(squares) do
				local rx, rz = q.x - x, q.z - z
				if rx * rx + rz * rz >= (P.PLAZA + 10) * (P.PLAZA + 10) then kept[#kept + 1] = q end
			end
			squares = kept
			squares[#squares + 1] = {x = x, z = z, road = av, idx = bi, why = "plaza", rmax = P.PLAZA}
			st.plaza = true
		end
	end
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
						local rx, rz = lx - ax - u * vx, lz - az - u * vz
						local d = sqrt(rx * rx + rz * rz) - hw
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
			local rx, rz = q2[1] - p[1], q2[2] - p[2]
			local L = sqrt(rx * rx + rz * rz)
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
		for i = 2, n do
			local rx, rz = pts[i][1] - pts[i - 1][1], pts[i][2] - pts[i - 1][2]
			s[i] = s[i - 1] + sqrt(rx * rx + rz * rz)
		end
		local cx, cz = pts[1][1] - pts[n][1], pts[1][2] - pts[n][2]
		wall.length = s[n] + sqrt(cx * cx + cz * cz)
		local gap = {}
		for i = 1, n do
			local p = pts[i]
			for _, g in ipairs(gates) do
				-- inside the gatehouse box (the writer's, +0.5): the wall is built
				-- up to its sides (`wp13/city_edge.lua`)
				local dd = (p[1] - g.x) * g.dx + (p[2] - g.z) * g.dz
				local ww = -(p[1] - g.x) * g.dz + (p[2] - g.z) * g.dx
				if abs(dd) <= P.GATE_DEPTH + 0.5 and abs(ww) <= P.GATE_WIDTH + 0.5 then gap[i] = g.c end
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
		-- ... and clears the surface however long the crossing. The walk
		-- starts from the bed, and three neighbour passes cannot lift the
		-- middle of a long crossing (Round 23 found a walk 15 nodes under a
		-- lake), so the walk stands at least WALL_CLEAR above the surface. It
		-- runs for every capital; it only raises a walk at or below the water.
		for i = 1, n do
			if wetp[i] then
				local wy = WW[gk(pts[i][1], pts[i][2])]
				if wy then walk[i] = max(walk[i], wy + P.WALL_CLEAR) end
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
			local rx, rz = b[1] - a[1], b[2] - a[2]
			seg[i] = sqrt(rx * rx + rz * rz)
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
		-- Towers (Round 26, ruling 3: a few well-placed ones, never filler):
		--  * "flank": beside each gatehouse, one each side on the first wall
		--    point clear of its box by the turret radius (M.STYLE GATE_FLANK),
		--    so the gate reads as a fortified gatehouse;
		--  * "bend": at the sharpest bends of the wall (turning more than
		--    BEND_MIN over ~20 nodes), strongest first, BEND_GAP apart along
		--    the wall -- an angular capital's corners;
		--  * "rhythm": the stretches still longer than TURRET_EVERY get evenly
		--    spaced towers.
		-- None stands on or beside water (an arcade) or within 8 points of a
		-- gate gap (flank towers excepted).
		local turrets = {}
		local TR = P.TURRET_R or 5
		local function at(k) return (k - 1) % n + 1 end
		local function blocked(i, flank)
			for d = -2, 2 do if wetp[at(i + d)] then return true end end
			if flank then
				if gap[i] then return true end
			else
				for d = -8, 8 do if gap[at(i + d)] then return true end end
			end
			return false
		end
		local function along(i, j)   -- wall distance from point i forward to j
			local d = s[j] - s[i]
			if d < 0 then d = d + wall.length end
			return d
		end
		local function far_from_all(i, lim)
			for _, t in ipairs(turrets) do
				local d = along(i, t.i)
				if min(d, wall.length - d) < lim then return false end
			end
			return true
		end
		if P.GATE_FLANK then
			for _, g in ipairs(gates) do
				-- the gap's two ends, then outward along the wall
				local first
				for i = 1, n do
					if gap[i] == g.c and gap[at(i - 1)] ~= g.c then first = i end
				end
				if first then
					for _, dir in ipairs({-1, 1}) do
						local i = first
						if dir == 1 then
							while gap[i] == g.c do i = at(i + 1) end
						else
							i = at(i - 1)
						end
						for _ = 1, 12 do
							local rx, rz = pts[i][1] - g.x, pts[i][2] - g.z
							local ww = abs(-rx * g.dz + rz * g.dx)
							if ww >= P.GATE_WIDTH + TR - 0.5 then
								if not blocked(i, true) and far_from_all(i, 2 * TR + 2) then
									turrets[#turrets + 1] = {x = pts[i][1], z = pts[i][2], i = i, kind = "flank"}
								end
								break
							end
							i = at(i + dir)
						end
					end
				end
			end
		end
		if P.BEND_MIN then
			local K = 5
			local bends = {}
			for i = 1, n do
				local a, b, c = pts[at(i - K)], pts[i], pts[at(i + K)]
				local ux, uz = b[1] - a[1], b[2] - a[2]
				local vx, vz = c[1] - b[1], c[2] - b[2]
				local turn = abs(atan2(ux * vz - uz * vx, ux * vx + uz * vz))
				bends[i] = turn
			end
			local cand = {}
			for i = 1, n do
				local tb = bends[i]
				if tb >= P.BEND_MIN and tb >= bends[at(i - 1)] and tb > bends[at(i + 1)] then
					cand[#cand + 1] = i
				end
			end
			table.sort(cand, function(u, v)
				if bends[u] ~= bends[v] then return bends[u] > bends[v] end
				return u < v
			end)
			for _, i in ipairs(cand) do
				if not blocked(i) and far_from_all(i, P.BEND_GAP) then
					turrets[#turrets + 1] = {x = pts[i][1], z = pts[i][2], i = i, kind = "bend",
						turn = bends[i]}
				end
			end
		end
		-- rhythm: fill every stretch longer than TURRET_EVERY between two
		-- towers or gate gaps with evenly spaced towers
		do
			local stops = {}
			for _, t in ipairs(turrets) do stops[#stops + 1] = t.i end
			for i = 1, n do
				if gap[i] and not gap[at(i - 1)] then stops[#stops + 1] = i end
				if gap[i] and not gap[at(i + 1)] then stops[#stops + 1] = i end
			end
			table.sort(stops)
			if #stops == 0 then stops[1] = 1 end
			local add = {}
			for k = 1, #stops do
				local i, j = stops[k], stops[k % #stops + 1]
				local len = along(i, j)
				if #stops == 1 then len = wall.length end
				local cnt = floor(len / P.TURRET_EVERY)
				for c = 1, cnt do
					local target = s[i] + c * len / (cnt + 1)
					if target >= wall.length then target = target - wall.length end
					-- the wall point nearest that distance, moved off gates and water
					local best, bd
					for m = 1, n do
						local d = abs(s[m] - target)
						d = min(d, wall.length - d)
						if (not bd or d < bd) then best, bd = m, d end
					end
					local ok = false
					for d = 0, 6 do
						for _, sg in ipairs({1, -1}) do
							local m = at(best + sg * d)
							if not ok and not blocked(m) and far_from_all(m, 0.5 * P.TURRET_EVERY) then
								best, ok = m, true
							end
						end
					end
					if ok then add[#add + 1] = best; turrets[#turrets + 1] = {x = pts[best][1],
						z = pts[best][2], i = best, kind = "turret"} end
				end
			end
		end
		table.sort(turrets, function(u, v) return u.i < v.i end)
		-- Round 23 (user rulings 2026-09-28): a capital's CIVIC lake is its
		-- edge where it crosses the outline (Lethariel's crown lake, Kezamba's
		-- cenote). M.shore_flags: the wall is continuous on land, runs a few
		-- points into each crossing and ends there; no turret stands within
		-- SHORE_TURRET_GAP points of the open lake or on the water.
		local lake, foot = {}, {}
		wall.lake_points, wall.lake_ends = 0, 0
		if I.shore_distance then
			local flags = M.shore_flags(pts, gap, function(lx, lz)
				return I.shore_distance(AX + lx, AZ + lz)
			end, P)
			lake, foot = flags.lake, flags.foot
			wall.lake_points, wall.lake_ends = flags.stats.lake_points, flags.stats.lake_ends
			wall.shore = flags.stats
			local kept = {}
			for _, t in ipairs(turrets) do
				local clear = true
				for k = t.i - P.SHORE_TURRET_GAP, t.i + P.SHORE_TURRET_GAP do
					local m = (k - 1) % n + 1
					if lake[m] or flags.water[m] then clear = false end
				end
				if clear then kept[#kept + 1] = t end
			end
			turrets = kept
		end
		wall.lake, wall.foot = lake, foot
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
						local rx, rz = lx - p[1], lz - p[2]
						if ok_(lx, lz) and rx * rx + rz * rz <= reach * reach then
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
						local rx, rz = lx - p[1], lz - p[2]
						if ok_(lx, lz) and rx * rx + rz * rz <= reach * reach then
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
	kit.finish()
	for c = 1, 4 do
		local av = avenues[c]
		local g = gates[c]
		-- the avenue's point at the gate's outer end (a run-out continues
		-- past it at the same level)
		local io, bd = #av.X, nil
		for i = #av.X, max(1, #av.X - 80), -1 do
			local rx, rz = av.X[i] - AX - g.ox, av.Z[i] - AZ - g.oz
			local d = rx * rx + rz * rz
			if not bd or d < bd then io, bd = i, d end
		end
		g.ground_y = g.y
		g.y = floor(av.R[io])
		g.q = av.RQ[io]   -- connectors continue at exactly this level
	end
	-- squares: flat at the street level where they sit; occupied for plots
	local kept_sq = {}
	for _, q in ipairs(squares) do
		-- Round 27 playtest: a square never reaches the wall band or a
		-- gatehouse box. A lane's end square moves back along its lane (up to
		-- twice its radius) until it has its full size clear of both; any
		-- square is then cut to what is clear (and dropped below 3, below)
		local r0 = q.rmax or P.SQUARE_R
		if q.why == "lane end" then
			local X, Z = q.road.X, q.road.Z
			local idx, lim = q.idx, max(12, q.idx - 2 * r0)
			while idx > lim and (wall_dist(X[idx] - AX, Z[idx] - AZ) < r0 + WALL_CLEAR_ST or
					box_dist(X[idx] - AX, Z[idx] - AZ) < r0 + 1) do
				idx = idx - 1
			end
			if idx ~= q.idx then
				q.idx, q.x, q.z, q.pulled = idx, X[idx] - AX, Z[idx] - AZ, true
				st.squares_pulled = (st.squares_pulled or 0) + 1
			end
		end
		q.y = floor(2 * q.road.R[q.idx] + 0.5) / 2
		-- the square reaches only as far as every street through it stays
		-- within 1/2 of its level (junction mouths are flat), so its edge
		-- never makes a step against a street surface
		local r = q.rmax or P.SQUARE_R
		for _, sr in ipairs(streets) do
			for i = 1, #sr.X do
				local rx, rz = sr.X[i] - AX - q.x, sr.Z[i] - AZ - q.z
				local d = sqrt(rx * rx + rz * rz)
				if d <= (q.rmax or P.SQUARE_R) + sr.hw + 2 then
					local y = floor(2 * sr.R[i] + 0.5) / 2
					if abs(y - q.y) > 0.5 then r = min(r, d - sr.hw - 2) end
				end
			end
		end
		local clear = min(wall_dist(q.x, q.z) - WALL_CLEAR_ST, box_dist(q.x, q.z) - 1)
		if clear < r then
			r = clear
			st.squares_cut = (st.squares_cut or 0) + 1
		end
		q.r = r
		-- a square moved back keeps add_square's 14-node spacing to the
		-- squares kept before it
		if r >= 3 and q.pulled then
			for _, o in ipairs(kept_sq) do
				local rx, rz = o.x - q.x, o.z - q.z
				if rx * rx + rz * rz < 14 * 14 then
					r = 0
					st.squares_close = (st.squares_close or 0) + 1
					break
				end
			end
		end
		if r >= 3 then kept_sq[#kept_sq + 1] = q end
	end
	st.squares_dropped = #squares - #kept_sq
	squares = kept_sq
	for _, q in ipairs(squares) do
		local R2 = q.r * q.r
		for lz = floor(q.z - q.r), ceil(q.z + q.r) do
			for lx = floor(q.x - q.r), ceil(q.x + q.r) do
				local rx, rz = lx - q.x, lz - q.z
				if ok_(lx, lz) and rx * rx + rz * rz <= R2 then
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
				local wz0, wz1 = cz + z0 - P.WET_MARGIN, cz + z1 + P.WET_MARGIN
				local wx0, wx1 = cx + x0 - P.WET_MARGIN, cx + x1 + P.WET_MARGIN
				wz0, wx0 = wz0 - wz0 % G, wx0 - wx0 % G
				wz1, wx1 = wz1 + (-wz1) % G, wx1 + (-wx1) % G
				for lz = wz0, wz1, G do
					for lx = wx0, wx1, G do
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
		if P.BUILD_R > 0 then
			-- Round 26: buildings spread from a ring BUILD_R of the way from
			-- the core gate to the wall, so fields and houses mix
			for _, c in ipairs(a) do
				local pref = P.CORE_GATE + P.BUILD_R * (r_at(atan2(c.z, c.x)) - P.CORE_GATE)
				c.pref = abs(c.r - pref)
			end
			table.sort(a, function(u, v) if u.pref ~= v.pref then return u.pref < v.pref end
				if u.r ~= v.r then return u.r < v.r end return u.i < v.i end)
		else
			table.sort(a, function(u, v) if u.r ~= v.r then return u.r < v.r end return u.i < v.i end)
		end
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
	-- D70 placement passes, run per tier (required plots, then the other
	-- buildings, then fill pieces; Round 25 Lane H): (1) every plot of the
	-- tier in its own quarter; (2) what did not fit overflows into the two
	-- neighbouring quarters; (3) buildings (named plots, quest texts name
	-- them) and required plots then try the opposite quarter and, failing
	-- that, relaxed legality anywhere -- never dropped; only fill pieces may
	-- be left out. A tier finishes all its passes before the next tier
	-- places anything, so a required or named plot that misses its quarter
	-- is not squeezed out by lower tiers (Kezamba's shore market, pinned to
	-- its cenote quarter, always overflows). Where every plot fits its own
	-- quarter the order is the plain one, required, buildings, fill.
	local overflowed = {}
	local function commit_plot(pl)
		placed[#placed + 1] = pl
		mark_plot(pl, #placed)
	end
	local function place_tier(tier)
		local pending = {}
		for _, p in ipairs(tier) do
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
	end
	local tiers = {{}, {}, {}}
	for _, o in ipairs(order) do
		local t = tiers[prio(o.p) + 1]
		t[#t + 1] = o.p
	end
	for _, tier in ipairs(tiers) do place_tier(tier) end
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
			local ax, az = a.x - g.ox, a.z - g.oz
			local bx, bz = b.x - g.ox, b.z - g.oz
			local da = ax * ax + az * az
			local db = bx * bx + bz * bz
			if da ~= db then return da < db end
			return a.road < b.road
		end)
		local first
		for _, e in ipairs(g.ends) do
			local kind = e.kind == "primary" and "primary" or "secondary"
			local kit_half = city.P.HALF[kind]
			local guide = guide_for(function(lx, lz, li)
				-- stay outside the city (the wall), except in front of the gate
				local rx, rz = lx - g.ox, lz - g.oz
				-- Round 27 playtest: and off the wall band, which a road
				-- skirting a slanted stretch of wall ran along (its radius
				-- was clear of the wall, its surface on it), except in the
				-- gate's own approach straight out from the passage
				local along = rx * g.dx + rz * g.dz
				local across = -rx * g.dz + rz * g.dx
				if along >= -1 and abs(across) <= P.GATE_WIDTH + 1 then return 0 end
				if cell_wall_dist(lx, lz, li) < WALL_CLEAR_ST + kit_half + 2 then return 50 end
				local dg = sqrt(rx * rx + rz * rz)
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
			end, o2, guide, P.CONNECTOR_BUDGET)
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

-- Round 26 (ruling 3, a size that fits the content): a plan that leaves a
-- named or required plot out is planned again with a slightly larger target
-- area (GROW, at most GROW_TRIES times); the plan with the fewest such plots
-- left out wins (the first on ties). Nearly every capital plans once.
function M.plan(seed, I, opt)
	local function named_left(plan)
		local n = 0
		for _, p in ipairs(plan.left_out) do
			if p.required or p.kind ~= "fill" then n = n + 1 end
		end
		return n
	end
	local best = plan_once(seed, I, opt)
	local best_n = named_left(best)
	local area = (opt and opt.TARGET_AREA) or M.DEFAULTS.TARGET_AREA
	local grow = (opt and opt.GROW) or M.DEFAULTS.GROW
	local tries = (opt and opt.GROW_TRIES) or M.DEFAULTS.GROW_TRIES
	local t = best.stats.t.total
	for k = 1, tries do
		if best_n == 0 then break end
		local o = {}
		for key, v in pairs(opt or {}) do o[key] = v end
		o.TARGET_AREA = area * (1 + k * grow)
		local plan = plan_once(seed, I, o)
		t = t + plan.stats.t.total
		local n = named_left(plan)
		if n < best_n then best, best_n = plan, n end
	end
	best.stats.t.all_tries = t
	return best
end

-------------------------------------------------------------------------------
-- Payload (text, the `capital_layout` field of the ipc_set payload), local
-- coordinates relative to the anchor:
--   C2 <anchor id> <x> <z>
--   k <edge kind>                            a key of M.EDGE
--   o <outline radius per ray, 0.1>
--   g <name> <x> <z> <floor y>               the four gates
--   p <plot id> <x> <z> <turns> <y>          one per placed plot
--   w <x,z,walk2[flags]> ...                 wall points (~2 nodes apart), the
--                                            walk in half nodes; flags: g gate
--                                            gap, a over water, l civic lake
--                                            (no wall), f footing by the
--                                            civic lake (solid, no arcade)
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
		w[#w + 1] = ("%.1f,%.1f,%d%s%s%s%s"):format(p[1], p[2], plan.wall.walk[i],
			plan.wall.gap[i] and "g" or "", plan.wall.wet[i] and "a" or "",
			plan.wall.lake and plan.wall.lake[i] and "l" or "",
			plan.wall.foot and plan.wall.foot[i] and "f" or "")
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
-- z, turns, y}}, wall = {pts = {{x, z}}, walk, gap, wet, lake, foot, turrets = {index}},
-- squares = {{x, z, r, y}}, canal = {level, half, depth, pts} or nil}.
function M.deserialize(text)
	local function fail(message) error("capital layout: " .. message, 0) end
	if type(text) ~= "string" then fail("text differs") end
	local L = {plots = {}, squares = {}, gates = {}, outline = {},
		wall = {pts = {}, walk = {}, gap = {}, wet = {}, lake = {}, foot = {}, turrets = {}}}
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
				W.lake[i] = flags:find("l", 1, true) ~= nil
				W.foot[i] = flags:find("f", 1, true) ~= nil
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
