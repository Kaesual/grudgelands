-- Continent ocean mask: the GEOMETRY, and nothing else.
--
-- One question, one place: "how high may the column at (x, z) stand?"
-- (column_cap), plus the cheap box test that says whether a mapchunk or a
-- mapblock can contain such a column at all (box_needs_mask). Three consumers
-- in TWO Lua environments read this file:
--
--   * ocean_mask_mapgen.lua — MAPGEN environment (core.register_mapgen_script):
--     the carve itself, during generation.
--   * ocean_mask.lua — MAIN environment: the idempotent healing LBM.
--   * structures.lua — MAIN environment: the outpost/bandit-camp height clamp
--     (candidate_ground_y), which must agree with the coast profile or it
--     drowns a pad.
--
-- WHY THIS FILE EXISTS AT ALL: the mapgen env is a separate Lua state with its
-- own globals. It has no `grug_core`, no mod storage and no POI registry
-- (lua_api.md:7678-7691 "Mapgen environment" — only the scripts registered with
-- register_mapgen_script are run there, not the mods). It therefore cannot read
-- grug_core.CONTINENT_X_HALF / _Z_MIN / _Z_MAX. Copying those three numbers
-- into the mapgen script would give the coastline two owners and one silent
-- divergence away from a mask that cuts at different heights in the two
-- environments — which is exactly the invariant the healing LBM depends on.
-- So the rectangle is not owned here either: it is an ARGUMENT. The main env
-- passes grug_core's values into build() and republishes the same three numbers
-- to the mapgen env via core.ipc_set (see ocean_mask.lua). Everything else —
-- the whole cap profile below — is owned HERE and exists exactly once.
--
-- Pure arithmetic plus one 2D noise, and the noise is created lazily (the
-- engine forbids noise objects at load time, lua_api.md:9871), so this file
-- also loads headless: pass cfg.water_level and a cfg.inset stub and every
-- function below can be exercised with plain luajit, no engine. That is how
-- the cut heights are regression-tested.

-- Mask profile. All of these were file-local constants of structures.lua
-- before the mapgen-env split; they moved as a block, unchanged.
local TAPER = 150 -- width of the shore -> inland ramp; beyond it: no cap
local INSET_MAX = 150 -- the coast noise pulls the shoreline in by 0..150
local SHORE_DROP = 5 -- surface cap right at the shoreline: W - 5
local TAPER_RISE = 119 -- cap gained across the taper band (quadratic ease)
local SHELF_DEPTH = 10 -- seabed drops this much across SHELF_WIDTH
local SHELF_WIDTH = 60 -- ... and is flat further out (v7 takes over)

-- Decorations (trees) are placed before the mask runs and reach at most this
-- far above the mapgen heightmap; carving stops there, so a mapchunk high above
-- the terrain costs nothing.
local DECO_MARGIN = 32
-- Width of the emerged shell around a mapchunk (the mapgen VM reaches this far
-- beyond minp..maxp on every side).
local SHELL = 16

-- The coast noise. Its `seed` is a seed DIFFERENCE: core.get_value_noise adds
-- the world seed on top, in both environments (main env:
-- l_env.cpp:997 `params.seed += env->getServerMap().getSeed()`; mapgen env:
-- builtin/emerge/env.lua `params.seed = core.get_seed(params.seed)`, and
-- emerge->mgparams IS servermap.getMapgenParams(), server.cpp:577). So the two
-- environments sample the identical field — without that, the LBM would heal a
-- coastline at heights the mapgen never cut.
local COAST_NOISE = {
	offset = 75, scale = 75,
	spread = {x = 300, y = 300, z = 300},
	seed = 91744, octaves = 3, persist = 0.55,
}

-- cfg = {
--   x_half, z_min, z_max  -- the continent rectangle (grug_core's numbers)
--   water_level           -- optional; read from the mapgen settings otherwise
--   inset                 -- optional function(x, z) -> 0..INSET_MAX; only the
--                            headless tests pass this, it replaces the noise
-- }
local function build(cfg)
	local X_HALF = cfg.x_half
	local Z_MIN = cfg.z_min
	local Z_MAX = cfg.z_max

	-- Sea level of the active mapgen (v7 default 1); the whole mask profile is
	-- expressed relative to it.
	local WATER_LEVEL = cfg.water_level
	if WATER_LEVEL == nil then
		WATER_LEVEL = tonumber(core.get_mapgen_setting("water_level")) or 1
	end

	-- Inland-signed distance to the NEARER continent rectangle: positive
	-- inside, negative outside, in nodes. Only three edges can be the nearest
	-- one for a given continent — the flank (|x| = X_HALF), the strait-facing
	-- front (|z| = Z_MIN) and the back (|z| = Z_MAX) — and since the two
	-- rectangles are mirrored at z = 0, evaluating them on |z| yields the max
	-- over both (the far continent is never the nearer one).
	local function continent_distance(x, z)
		local ax = x >= 0 and x or -x
		local az = z >= 0 and z or -z
		local d = X_HALF - ax -- flank
		local front = az - Z_MIN
		if front < d then
			d = front
		end
		local back = Z_MAX - az
		if back < d then
			d = back
		end
		return d
	end

	-- Highest y the terrain may keep at inland-signed distance s (after the
	-- coast noise inset), or nil for "no cap at all" from TAPER inland — the
	-- mask shapes the coast, it must never flatten the hinterland.
	-- Seaward of the shoreline the cap is the ocean floor profile: a shelf from
	-- ~5 below sea level at the beach to ~15 below out at SHELF_WIDTH (deeper
	-- is pointless — v7's own seabed is below that anyway). Inland it rises
	-- quadratically to ~W+114 across the ramp, so the last nodes before the
	-- water sit at beach level and only real mountains near the shore get cut.
	-- Strictly a function of (x, z): vertically stacked mapchunks of the same
	-- column MUST agree on the cap, so nothing chunk-local (heightmap!) may
	-- enter here.
	local function surface_cap(s)
		if s >= TAPER then
			return nil
		end
		if s <= 0 then
			local away = -s
			if away > SHELF_WIDTH then
				away = SHELF_WIDTH
			end
			return math.floor(WATER_LEVEL - SHORE_DROP - 1 -
				away / SHELF_WIDTH * SHELF_DEPTH)
		end
		local t = s / TAPER -- 0 < t < 1, the s >= TAPER case returned above
		return math.floor(WATER_LEVEL - SHORE_DROP + t * t * TAPER_RISE)
	end

	-- Flat part of the shelf: everything from SHELF_WIDTH seaward shares one
	-- cap, so the open sea needs no coast noise at all.
	local SEA_FLOOR_CAP = surface_cap(-SHELF_WIDTH)

	-- Deepest y the mask can ever carve (deepest shelf cap + 1). Everything
	-- below is pure underground: such mapchunks — and, for the healing LBM,
	-- such mapblocks — are skipped outright, so caves stay caves no matter how
	-- far out at sea they are. (The beach re-surfacing reaches BEACH_DEPTH
	-- lower, but it only ever runs in a chunk that carved something, i.e. one
	-- that is above this line.)
	local MASK_MIN_Y = SEA_FLOOR_CAP + 1

	-- ... and the highest cap it can ever produce (the last node before the
	-- taper ends and surface_cap turns nil). Only a bound, never a decision:
	-- the healing LBM uses it to size the map region it has to have in memory
	-- before it can probe a column's cap, in the one case where box_cap_bounds
	-- returns no upper bound because some column of the box is uncapped.
	local MASK_MAX_Y = surface_cap(TAPER - 1)

	-- core.get_perlin was renamed in 5.12; keep working on both. Both names
	-- exist in the mapgen env too (builtin/emerge/env.lua).
	local coast_inset = cfg.inset
	if not coast_inset then
		local get_noise = core.get_value_noise or core.get_perlin
		local coast_noise
		coast_inset = function(x, z)
			coast_noise = coast_noise or get_noise(COAST_NOISE)
			local inset = coast_noise:get_2d({x = x, y = z})
			if inset < 0 then
				return 0
			elseif inset > INSET_MAX then
				return INSET_MAX
			end
			return inset
		end
	end

	-- Cap of a single column — the whole geometry of the mask in one place.
	-- nil means "hands off". Depends on (x, z) only: every mapchunk that ever
	-- looks at this column, from whatever direction and at whatever time,
	-- derives exactly the same cap — and so does the healing LBM, sessions
	-- later, which is what makes that sweep idempotent.
	local function column_cap(x, z)
		local d = continent_distance(x, z)
		if d >= TAPER + INSET_MAX then
			return nil -- inland, beyond the reach of the coast band
		end
		if d <= -SHELF_WIDTH then
			return SEA_FLOOR_CAP -- flat shelf: no noise lookup needed
		end
		return surface_cap(d - coast_inset(x, z))
	end

	-- Range of continent_distance over a box, grown by `grow` in x/z: the exact
	-- minimum and an upper bound on the maximum (the three rectangle edges are
	-- maximised at different corners, so the min of the three per-edge maxima is
	-- a bound, not the value — which is all either caller needs).
	local function box_distance_range(minp, maxp, grow)
		local ax_far = math.max(math.abs(minp.x), math.abs(maxp.x)) + grow
		local ax_near = 0
		if minp.x > 0 then
			ax_near = math.max(minp.x - grow, 0)
		elseif maxp.x < 0 then
			ax_near = math.max(-maxp.x - grow, 0)
		end
		local az_far = math.max(math.abs(minp.z), math.abs(maxp.z)) + grow
		local az_near = 0
		if minp.z > 0 then
			az_near = math.max(minp.z - grow, 0)
		elseif maxp.z < 0 then
			az_near = math.max(-maxp.z - grow, 0)
		end
		local lo = math.min(X_HALF - ax_far, az_near - Z_MIN, Z_MAX - az_far)
		local hi = math.min(X_HALF - ax_near, az_far - Z_MIN, Z_MAX - az_near)
		return lo, hi
	end

	-- Box-level fast path: true only for a box that can contain a coast column
	-- at all. Pure arithmetic on the box — no mapgen object is fetched and no
	-- noise is sampled for the (vast majority of) fully inland or fully deep
	-- boxes.
	-- `grow` widens the box in x/z before the test. The mapgen pass passes
	-- SHELL, because the shell clean works on columns up to SHELL nodes outside
	-- minp..maxp; the healing LBM passes 0, because an LBM only ever sees the
	-- mapblock's own nodes.
	local function box_needs_mask(minp, maxp, grow)
		if maxp.y < MASK_MIN_Y then
			return false -- pure underground: caves stay caves
		end
		local lo = box_distance_range(minp, maxp, grow)
		return lo < TAPER + INSET_MAX
	end

	-- Bounds on column_cap over a box, again without a single noise sample:
	-- surface_cap is monotone non-decreasing in s, and the coast inset only ever
	-- LOWERS s (by at most INSET_MAX, and never below 0), so for every column in
	-- the box
	--     surface_cap(d_lo - INSET_MAX) <= column_cap <= surface_cap(d_hi).
	-- A nil low bound means every column in the box is inland and uncapped
	-- (exactly the case box_needs_mask already rejects); a nil high bound means
	-- SOME column here may be uncapped, so no whole-box shortcut is allowed.
	-- The healing LBM uses both: below the low bound it has no work at all, and
	-- above the high bound it needs no per-column lookup, because every node it
	-- is looking at is above its own column's cap.
	local function box_cap_bounds(minp, maxp, grow)
		local lo, hi = box_distance_range(minp, maxp, grow)
		return surface_cap(lo - INSET_MAX), surface_cap(hi)
	end

	return {
		-- geometry
		continent_distance = continent_distance,
		surface_cap = surface_cap,
		coast_inset = coast_inset,
		column_cap = column_cap,
		box_needs_mask = box_needs_mask,
		box_cap_bounds = box_cap_bounds,
		-- constants the two masks share
		X_HALF = X_HALF,
		Z_MIN = Z_MIN,
		Z_MAX = Z_MAX,
		WATER_LEVEL = WATER_LEVEL,
		TAPER = TAPER,
		INSET_MAX = INSET_MAX,
		SHELF_WIDTH = SHELF_WIDTH,
		DECO_MARGIN = DECO_MARGIN,
		SHELL = SHELL,
		SEA_FLOOR_CAP = SEA_FLOOR_CAP,
		MASK_MIN_Y = MASK_MIN_Y,
		MASK_MAX_Y = MASK_MAX_Y,
	}
end

return build
