-- Round 22 horizontal world: per-seed zone borders and coastline
-- (world_zones.md §7.1-7.4, D8, D14, D17, D24). Port of the approved Phase 2b
-- prototype. Pure float function of (seed, x, z); no chunk state.
--
--   local field = zone_field.new_checked(seed, source, params)
--   field.sample(x, z)  -> zone (numeric, 0 = sea), coast_signed (nodes, + = land),
--                          owner (numeric, also over water), border distance,
--                          second owner
--   field.bay_at(x, z)  -> index into source.bays when the column lies in a bay
--                          body (at the coast-warped point), else nil
--   field.check         -> {scale, tries, seconds} of the construction self-check
--
-- Mechanism:
--   F(p) = p + W(p), W a composed simplex warp; every step keeps
--   amp * 7.3 * sqrt(2) / period < 0.8, so no step and no composition folds.
--   Owner = argmin_i dist(F(p), F(site_i))^2 - bias_i - bulge_i(p): one power
--   diagram in warped space over the mainland zones; the Battlegrounds and the
--   six frontier zones use short segment sites so the front stays one band.
--   Land = S(Fc(p)) + N(p) + bonus(p) > 0: S is the signed distance of the
--   authored land primitives plus a front band, minus the bays, plus the
--   island polygons; Fc is the warp damped near landings and islands; N is a
--   small coast fBm. One ordered construction pass adds a flat-topped bulge to
--   an anchor's own zone score where the warped border would cut its footprint
--   and a land bonus where the warped coast would drown it. No iteration.
--   A cheap self-check rebuilds with a weaker warp when it fails.

local bit = bit
local band, bxor = bit.band, bit.bxor
local floor, sqrt, abs, max, min = math.floor, math.sqrt, math.abs, math.max, math.min

local M = {}

local function now()
	return os.clock()
end

-- ---------------------------------------------------------------- noise
-- exact 32-bit FNV-1a (the plain product can exceed 2^53, so do it in halves)
local function fnv1a(str)
	local h = 2166136261
	for i = 1, #str do
		h = bxor(h, str:byte(i))
		if h < 0 then h = h + 4294967296 end
		local lo = band(h, 0xffff)
		local hi = floor(h / 65536)
		-- 16777619 = 0x01000193 = 2^24 + 403
		local p = lo * 403 + (hi * 403 % 65536) * 65536 + (lo * 16777216) % 4294967296
		h = p % 4294967296
	end
	return h
end

local function new_rng(state)
	state = state % 4294967296
	if state == 0 then state = 0x9e3779b9 end
	return function()
		-- xorshift32
		local x = state
		x = bxor(x, band(x * 8192, 0xffffffff))      -- << 13
		if x < 0 then x = x + 4294967296 end
		x = bxor(x, floor(x / 131072))                 -- >> 17
		if x < 0 then x = x + 4294967296 end
		x = bxor(x, band(x * 32, 0xffffffff))          -- << 5
		if x < 0 then x = x + 4294967296 end
		state = x
		return x
	end
end

local F2 = 0.5 * (sqrt(3) - 1)
local G2 = (3 - sqrt(3)) / 6
-- 8 unit gradient directions
local GX, GZ = {}, {}
for k = 0, 7 do
	local a = (k + 0.5) * math.pi / 4
	GX[k], GZ[k] = math.cos(a), math.sin(a)
end
local NORM = 99.2 -- scales the unit-gradient simplex sum to about [-1, 1]

local function new_simplex(rng)
	local perm = {}
	for i = 0, 255 do perm[i] = i end
	for i = 255, 1, -1 do
		local j = rng() % (i + 1)
		perm[i], perm[j] = perm[j], perm[i]
	end
	for i = 0, 255 do perm[i + 256] = perm[i] end
	local grad = {}
	for i = 0, 511 do grad[i] = perm[i] % 8 end
	return function(x, y)
		local s = (x + y) * F2
		local i, j = floor(x + s), floor(y + s)
		local t = (i + j) * G2
		local x0, y0 = x - (i - t), y - (j - t)
		local i1, j1
		if x0 > y0 then i1, j1 = 1, 0 else i1, j1 = 0, 1 end
		local x1, y1 = x0 - i1 + G2, y0 - j1 + G2
		local x2, y2 = x0 - 1 + 2 * G2, y0 - 1 + 2 * G2
		local ii, jj = band(i, 255), band(j, 255)
		local n = 0
		local t0 = 0.5 - x0 * x0 - y0 * y0
		if t0 > 0 then
			local g = grad[ii + perm[jj]]
			t0 = t0 * t0
			n = t0 * t0 * (GX[g] * x0 + GZ[g] * y0)
		end
		local t1 = 0.5 - x1 * x1 - y1 * y1
		if t1 > 0 then
			local g = grad[ii + i1 + perm[jj + j1]]
			t1 = t1 * t1
			n = n + t1 * t1 * (GX[g] * x1 + GZ[g] * y1)
		end
		local t2 = 0.5 - x2 * x2 - y2 * y2
		if t2 > 0 then
			local g = grad[ii + 1 + perm[jj + 1]]
			t2 = t2 * t2
			n = n + t2 * t2 * (GX[g] * x2 + GZ[g] * y2)
		end
		return NORM * n
	end
end
M.new_simplex = new_simplex
M.new_rng = new_rng
M.seed32 = fnv1a

-- ---------------------------------------------------------------- SDF helpers
-- all return signed distance, positive INSIDE
local function sdf_capsule(x, z, r)
	local ax, az, bx, bz = r.a.x, r.a.z, r.b.x, r.b.z
	local vx, vz = bx - ax, bz - az
	local wx, wz = x - ax, z - az
	local t = (wx * vx + wz * vz) / (vx * vx + vz * vz)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local dx, dz = wx - vx * t, wz - vz * t
	return r.radius - sqrt(dx * dx + dz * dz)
end

local function sdf_ellipse(x, z, r)
	local dx, dz = (x - r.center.x) / r.radius_x, (z - r.center.z) / r.radius_z
	return (1 - sqrt(dx * dx + dz * dz)) * min(r.radius_x, r.radius_z)
end

local function sdf_rrect(x, z, r)
	local cx, cz = (r.min_x + r.max_x) * 0.5, (r.min_z + r.max_z) * 0.5
	local hx, hz = (r.max_x - r.min_x) * 0.5 - r.radius, (r.max_z - r.min_z) * 0.5 - r.radius
	local qx, qz = abs(x - cx) - hx, abs(z - cz) - hz
	local ox, oz = max(qx, 0), max(qz, 0)
	return r.radius - (sqrt(ox * ox + oz * oz) + min(max(qx, qz), 0))
end

local function sdf_primitive(x, z, r)
	if r.kind == "capsule" then return sdf_capsule(x, z, r)
	elseif r.kind == "ellipse" then return sdf_ellipse(x, z, r)
	else return sdf_rrect(x, z, r) end
end

-- tapered polyline (bay): positive inside the water body
local function sdf_tapered(x, z, pts)
	local best = -math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local vx, vz = b.x - a.x, b.z - a.z
		local wx, wz = x - a.x, z - a.z
		local t = (wx * vx + wz * vz) / (vx * vx + vz * vz)
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local dx, dz = wx - vx * t, wz - vz * t
		local v = a.half_width + (b.half_width - a.half_width) * t - sqrt(dx * dx + dz * dz)
		if v > best then best = v end
	end
	return best
end

local function sdf_polygon(x, z, pts)
	local d2 = math.huge
	local inside = false
	local n = #pts
	local j = n
	for i = 1, n do
		local a, b = pts[j], pts[i]
		local vx, vz = b.x - a.x, b.z - a.z
		local wx, wz = x - a.x, z - a.z
		local t = (wx * vx + wz * vz) / (vx * vx + vz * vz)
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local dx, dz = wx - vx * t, wz - vz * t
		local dd = dx * dx + dz * dz
		if dd < d2 then d2 = dd end
		if (a.z > z) ~= (b.z > z) and x < a.x + (z - a.z) * vx / vz then
			inside = not inside
		end
		j = i
	end
	local d = sqrt(d2)
	return inside and d or -d
end

local function smootherstep01(t)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- flat top of radius r0, then falls to 0 over `falloff`
local function plateau(dist, r0, falloff)
	return 1 - smootherstep01((dist - r0) / falloff)
end

-- ---------------------------------------------------------------- bucket grid
local BUCKET = 256
local function bucket_add(grid, cx, cz, radius, item)
	for iz = floor((cz - radius) / BUCKET), floor((cz + radius) / BUCKET) do
		local row = grid[iz]
		if not row then row = {} grid[iz] = row end
		for ix = floor((cx - radius) / BUCKET), floor((cx + radius) / BUCKET) do
			local cell = row[ix]
			if not cell then cell = {} row[ix] = cell end
			cell[#cell + 1] = item
		end
	end
end
local function bucket_get(grid, x, z)
	local row = grid[floor(z / BUCKET)]
	return row and row[floor(x / BUCKET)]
end

local function is_island_region(region)
	return region == "wyrmglass_island" or region == "stormscale_island"
end

-- ---------------------------------------------------------------- key points
-- Every fixed point the field keeps: anchors (with their fitting-width or
-- hard-protected footprint), zone hubs, island landings and boat-path mainland ends.
local function footprint_samples(cx, cz, half, step)
	local s = {{cx, cz}}
	if half <= 0 then return s end
	-- integer columns of the half-open square [c - half, c + half - 1]
	local n = max(1, floor(2 * half / step + 0.5))
	for k = 0, n do
		local u = floor(-half + (2 * half - 1) * k / n + 0.5)
		s[#s + 1] = {cx + u, cz - half}
		s[#s + 1] = {cx + u, cz + half - 1}
		s[#s + 1] = {cx - half, cz + u}
		s[#s + 1] = {cx + half - 1, cz + u}
	end
	return s
end

function M.keypoints(source)
	local prof = {}
	for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
	local hard = {}
	for _, r in ipairs(source.hard_protection_recipes or {}) do hard[r.id] = r.total_width end
	local kp = {}
	for _, a in ipairs(source.anchors) do
		local p = prof[a.template_id]
		-- the footprint that must be in-zone and on land: the fitting square
		-- (villages 96, ...); for starts and capitals their hard-protected
		-- square (capitals 532 = build envelope plus apron, starts 148)
		local width = p.fitting_width
		if a.slot_id == "capital" then
			width = max(width, hard.hard_capital_build_plus_apron_v1 or width)
		elseif a.slot_id == "start" then
			width = max(width, hard.hard_start_core_v1 or width)
		end
		local half = width / 2
		kp[#kp + 1] = {kind = "anchor", id = a.id .. ":" .. a.template_id .. ":" ..
			source.zones[a.zone_numeric_id].id, zone = a.zone_numeric_id,
			x = a.position.x, z = a.position.z, half = half,
			samples = footprint_samples(a.position.x, a.position.z, half, 32)}
	end
	for i, zr in ipairs(source.zones) do
		kp[#kp + 1] = {kind = "hub", id = "hub:" .. zr.id, zone = i, x = zr.hub.x,
			z = zr.hub.z, half = 0, samples = {{zr.hub.x, zr.hub.z}}}
	end
	for _, l in ipairs(source.island_landings) do
		kp[#kp + 1] = {kind = "landing", id = l.id, zone = l.zone_numeric_id,
			x = l.position.x, z = l.position.z, half = 0,
			samples = {{l.position.x, l.position.z}}, landing = true}
	end
	for _, b in ipairs(source.boat_paths) do
		local p = b.centreline[1]
		kp[#kp + 1] = {kind = "boat_start", id = b.id .. ":mainland_end", zone = b.from_zone,
			x = p.x, z = p.z, half = 0, samples = {{p.x, p.z}}, landing = true}
	end
	return kp
end

-- ---------------------------------------------------------------- field
function M.new(seed, source, o, warp_scale)
	local t_start = now()
	warp_scale = warp_scale or 1
	local rng = new_rng(fnv1a(o.seed_domain .. tostring(seed)))
	local noise = new_simplex(rng)
	local function offset() return (rng() % 100000) + 0.5 end

	-- warp octaves
	local WP, WA, WOX, WOZ, WOX2, WOZ2 = {}, {}, {}, {}, {}, {}
	for k = 1, #o.warp_periods do
		WP[k] = 1 / o.warp_periods[k]; WA[k] = o.warp_amps[k] * warp_scale
		WOX[k], WOZ[k], WOX2[k], WOZ2[k] = offset(), offset(), offset(), offset()
	end
	local NW = #WP
	-- Composed warp: each octave displaces the point already moved by the
	-- previous ones. Every step has a Lipschitz constant below one, so every
	-- step is a homeomorphism and so is the composition: no folds.
	local function warp_raw(x, z)
		local px, pz = x, z
		for k = 1, NW do
			local f = WP[k]
			local dx = WA[k] * noise(px * f + WOX[k], pz * f + WOZ[k])
			local dz = WA[k] * noise(px * f + WOX2[k], pz * f + WOZ2[k])
			px, pz = px + dx, pz + dz
		end
		return px - x, pz - z
	end
	local CP, CA, COX, COZ = {}, {}, {}, {}
	for k = 1, #o.coast_periods do
		CP[k] = 1 / o.coast_periods[k]; CA[k] = o.coast_amps[k]
		COX[k], COZ[k] = offset(), offset()
	end
	local NC = #CP
	local function coast_noise(x, z)
		local v = 0
		for k = 1, NC do
			local f = CP[k]
			v = v + CA[k] * noise(x * f + COX[k], z * f + COZ[k])
		end
		return v
	end

	-- ---------------- land model
	local prims = {}
	for _, r in ipairs(source.land_primitives) do prims[#prims + 1] = r end
	local fb = o.front_band
	prims[#prims + 1] = {id = "front_band", kind = "rounded_rect", min_x = fb.min_x,
		max_x = fb.max_x, min_z = fb.min_z, max_z = fb.max_z, radius = fb.radius}
	local NPR = #prims
	local bays = {}
	for _, b in ipairs(source.bays) do
		local bb = {min_x = math.huge, max_x = -math.huge, min_z = math.huge, max_z = -math.huge}
		for _, s in ipairs(b.centreline) do
			bb.min_x = min(bb.min_x, s.x - s.half_width); bb.max_x = max(bb.max_x, s.x + s.half_width)
			bb.min_z = min(bb.min_z, s.z - s.half_width); bb.max_z = max(bb.max_z, s.z + s.half_width)
		end
		bays[#bays + 1] = {pts = b.centreline, bb = bb}
	end
	local NB = #bays
	-- Dragon islands: polygon shrunk towards the hub so warp and coast noise keep
	-- the island inside its 600 x 700 envelope; the envelope itself is a final
	-- soft clamp (a rounded box, rarely reached).
	local islands, island_env = {}, {}
	local env = o.island_envelope
	for _, isl in ipairs(source.islands) do
		local zr = source.zones[isl.zone_numeric_id]
		local hx, hz = zr.hub.x, zr.hub.z
		local pts = {}
		for _, p in ipairs(isl.polygon) do
			pts[#pts + 1] = {x = hx + (p.x - hx) * o.island_scale, z = hz + (p.z - hz) * o.island_scale}
		end
		islands[#islands + 1] = {pts = pts, zone = isl.zone_numeric_id}
		island_env[isl.zone_numeric_id] = {min_x = hx - env.half_x, max_x = hx + env.half_x,
			min_z = hz - env.half_z, max_z = hz + env.half_z, radius = env.radius}
	end

	-- S(p): signed distance to the static continent at (already warped) p;
	-- returns value, island zone (numeric) or 0 for mainland
	local function static_land(x, z)
		local u = -math.huge
		for i = 1, NPR do
			local v = sdf_primitive(x, z, prims[i])
			if v > u then u = v end
		end
		for i = 1, NB do
			local b = bays[i]
			local bb = b.bb
			-- lower bound of distance to the bay's box: skip if it cannot win
			local dx = max(bb.min_x - x, 0, x - bb.max_x)
			local dz = max(bb.min_z - z, 0, z - bb.max_z)
			if dx * dx + dz * dz < u * u or u < 0 then
				local v = -sdf_tapered(x, z, b.pts)
				if v < u then u = v end
			end
		end
		local iz = 0
		for i = 1, #islands do
			local v = sdf_polygon(x, z, islands[i].pts)
			if v > u then u = v iz = islands[i].zone end
		end
		return u, iz
	end

	-- ---------------- zones
	local mainland = {}
	for i, zr in ipairs(source.zones) do
		if not is_island_region(zr.macro_region) then
			mainland[#mainland + 1] = i
		end
	end
	local NM = #mainland
	local SX, SZ, SB, SX2, SZ2 = {}, {}, {}, {}, {}
	for k = 1, NM do
		local i = mainland[k]
		local zr = source.zones[i]
		local seg = o.front_segments[i]
		if seg then
			-- a segment site (warped end points): the Battlegrounds zones own a
			-- band along the front instead of four point cells
			local ax, az = seg[1], seg[3] or 0
			local bx, bz = seg[2], seg[3] or 0
			local wx, wz = warp_raw(ax, az)
			SX[k], SZ[k] = ax + wx, az + wz
			wx, wz = warp_raw(bx, bz)
			SX2[k], SZ2[k] = bx + wx, bz + wz
		else
			local hub = zr.hub
			local wx, wz = warp_raw(hub.x, hub.z)
			SX[k], SZ[k] = hub.x + wx, hub.z + wz
		end
		local b = (zr.bias or 0) + (o.zone_bias[i] or 0)
		if zr.macro_region == "holy_grounds" then b = b + o.front_bias end
		SB[k] = b
	end
	local slot_of = {}
	for k = 1, NM do slot_of[mainland[k]] = k end

	local bulge_grid, bonus_grid, damp_grid = {}, {}, {}

	-- power score of site k at warped point f, plus the nearest site point
	local function site(k, fx, fz)
		local ax, az = SX[k], SZ[k]
		local bx = SX2[k]
		if bx then
			local vx, vz = bx - ax, SZ2[k] - az
			local t = ((fx - ax) * vx + (fz - az) * vz) / (vx * vx + vz * vz)
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			ax, az = ax + vx * t, az + vz * t
		end
		local dx, dz = fx - ax, fz - az
		return dx * dx + dz * dz - SB[k], ax, az
	end

	-- power scores in warped space, with bulges; best slot, score, 2nd slot, score
	local function owner_scores(x, z, fx, fz)
		local cell = bucket_get(bulge_grid, x, z)
		local best, bs, second, ss = 0, math.huge, 0, math.huge
		for k = 1, NM do
			local sc = site(k, fx, fz)
			if sc < ss then
				if sc < bs then second, ss, best, bs = best, bs, k, sc
				else second, ss = k, sc end
			end
		end
		if cell then
			-- recompute with bulges for the affected zones only (few items)
			local adj
			for n = 1, #cell do
				local bu = cell[n]
				local ddx, ddz = x - bu.x, z - bu.z
				local w = plateau(sqrt(ddx * ddx + ddz * ddz), bu.r0, bu.falloff)
				if w > 0 then
					adj = adj or {}
					adj[bu.slot] = (adj[bu.slot] or 0) + bu.beta * w
				end
			end
			if adj then
				best, bs, second, ss = 0, math.huge, 0, math.huge
				for k = 1, NM do
					local sc = site(k, fx, fz) - (adj[k] or 0)
					if sc < ss then
						if sc < bs then second, ss, best, bs = best, bs, k, sc
						else second, ss = k, sc end
					end
				end
			end
		end
		return best, bs, second, ss
	end

	local function coast_damp(x, z)
		local cell = bucket_get(damp_grid, x, z)
		if not cell then return 1 end
		local d = 1
		for n = 1, #cell do
			local p = cell[n]
			local dx, dz = x - p.x, z - p.z
			local w = plateau(sqrt(dx * dx + dz * dz), p.r0, p.falloff)
			local v = 1 - (1 - p.k) * w
			if v < d then d = v end
		end
		return d
	end

	local function land_bonus(x, z)
		local cell = bucket_get(bonus_grid, x, z)
		if not cell then return 0 end
		local b = 0
		for n = 1, #cell do
			local p = cell[n]
			local dx, dz = x - p.x, z - p.z
			local w = plateau(sqrt(dx * dx + dz * dz), p.r0, p.falloff)
			if w > 0 then b = max(b, p.amp * w) end
		end
		return b
	end

	-- coast signed distance (+ island zone)
	local CS = 0.5 + 0.5 * warp_scale
	local function coast_values(x, z, wx, wz)
		local d = coast_damp(x, z)
		local s, iz = static_land(x + d * wx, z + d * wz)
		if iz ~= 0 then
			local v = s + CS * o.island_noise * coast_noise(x, z) + land_bonus(x, z)
			local e = sdf_rrect(x, z, island_env[iz]) - 6
			if v > e then v = e end
			return v, iz
		end
		return s + CS * coast_noise(x, z) + land_bonus(x, z), iz
	end

	-- ---------------- construction pass: bulges and land bonuses
	local kps = M.keypoints(source)
	local diag = {bulges = {}, bonuses = {}, damps = {}}
	-- (1) coast damping at landings / boat-path mainland ends and islands
	for _, kp in ipairs(kps) do
		if kp.landing then
			local item = {x = kp.x, z = kp.z, r0 = o.landing_damp_r0,
				falloff = o.landing_damp_falloff, k = o.landing_damp}
			bucket_add(damp_grid, kp.x, kp.z, item.r0 + item.falloff, item)
			diag.damps[#diag.damps + 1] = kp.id
		end
	end
	for _, zr in ipairs(source.zones) do
		if is_island_region(zr.macro_region) then
			local item = {x = zr.hub.x, z = zr.hub.z, r0 = o.island_damp_r0,
				falloff = o.island_damp_falloff, k = o.island_damp}
			bucket_add(damp_grid, item.x, item.z, item.r0 + item.falloff, item)
			diag.damps[#diag.damps + 1] = "island:" .. zr.id
		end
	end
	-- (2) zone bulges, one ordered pass. Each bulge is sized against the scores
	-- including the bulges already placed.
	local function bulge_adj(x, z)
		local cell = bucket_get(bulge_grid, x, z)
		local adj = {}
		if cell then
			for n = 1, #cell do
				local bu = cell[n]
				local ddx, ddz = x - bu.x, z - bu.z
				local w = plateau(sqrt(ddx * ddx + ddz * ddz), bu.r0, bu.falloff)
				if w > 0 then adj[bu.slot] = (adj[bu.slot] or 0) + bu.beta * w end
			end
		end
		return adj
	end
	for _, kp in ipairs(kps) do
		local slot = slot_of[kp.zone]
		if slot then
			local need, reach = 0, 0
			for _, s in ipairs(kp.samples) do
				local x, z = s[1], s[2]
				local wx, wz = warp_raw(x, z)
				local fx, fz = x + wx, z + wz
				local adj = bulge_adj(x, z)
				local own, ox, oz = site(slot, fx, fz)
				own = own - (adj[slot] or 0)
				for k = 1, NM do
					if k ~= slot then
						local sc, px, pz = site(k, fx, fz)
						sc = sc - (adj[k] or 0)
						local hx, hz = px - ox, pz - oz
						local margin = 2 * sqrt(hx * hx + hz * hz) * o.zone_margin
						local v = own - sc + margin
						if v > need then need = v end
						-- reach: how far (nodes) the border must be pushed here
						local r = v / (2 * sqrt(hx * hx + hz * hz)) - o.zone_margin
						if r > reach then reach = r end
					end
				end
			end
			if need > 0 then
				local item = {x = kp.x, z = kp.z, r0 = kp.half * 1.415 + o.zone_margin,
					falloff = o.bulge_falloff, beta = need, slot = slot, id = kp.id, reach = reach}
				bucket_add(bulge_grid, kp.x, kp.z, item.r0 + item.falloff, item)
				diag.bulges[#diag.bulges + 1] = item
			end
		end
	end
	-- (3) land bonuses: from the coast without bonuses
	local pending = {}
	for _, kp in ipairs(kps) do
		local need = 0
		for _, s in ipairs(kp.samples) do
			local x, z = s[1], s[2]
			local wx, wz = warp_raw(x, z)
			local d = coast_damp(x, z)
			local sv, iz = static_land(x + d * wx, z + d * wz)
			sv = sv + CS * (iz ~= 0 and o.island_noise or 1) * coast_noise(x, z)
			local v = o.land_margin - sv
			if v > need then need = v end
		end
		if need > 0 then
			pending[#pending + 1] = {x = kp.x, z = kp.z, r0 = kp.half * 1.415 + o.land_margin,
				falloff = o.bonus_falloff, amp = need, id = kp.id}
		end
	end
	for _, item in ipairs(pending) do
		bucket_add(bonus_grid, item.x, item.z, item.r0 + item.falloff, item)
		diag.bonuses[#diag.bonuses + 1] = item
	end

	-- ---------------- queries
	local s = {source = source, params = o, diag = diag, seed = seed,
		warp_scale = warp_scale, keypoints = kps}

	-- core sample: zone (0 = sea), coast signed, owner, border distance, second
	local function sample(x, z)
		local wx, wz = warp_raw(x, z)
		local c, iz = coast_values(x, z, wx, wz)
		if iz ~= 0 then
			return (c > 0) and iz or 0, c, iz, math.huge, 0
		end
		local fx, fz = x + wx, z + wz
		local b, bs, sec, ss = owner_scores(x, z, fx, fz)
		local _, ax, az = site(b, fx, fz)
		local _, cx, cz = site(sec, fx, fz)
		local hx, hz = cx - ax, cz - az
		local bd = (ss - bs) / (2 * sqrt(hx * hx + hz * hz))
		local owner = mainland[b]
		return (c > 0) and owner or 0, c, owner, bd, mainland[sec]
	end
	s.sample = sample

	-- Bay body at the coast-warped point (the same point the land SDF uses).
	function s.bay_at(x, z)
		local wx, wz = warp_raw(x, z)
		local d = coast_damp(x, z)
		local qx, qz = x + d * wx, z + d * wz
		for i = 1, NB do
			local bb = bays[i].bb
			if qx >= bb.min_x and qx <= bb.max_x and qz >= bb.min_z and qz <= bb.max_z and
					sdf_tapered(qx, qz, bays[i].pts) > 0 then
				return i, qx, qz
			end
		end
		return nil
	end
	function s.coast_signed(x, z)
		local wx, wz = warp_raw(x, z)
		return (coast_values(x, z, wx, wz))
	end
	function s.warp_at(x, z)
		local wx, wz = warp_raw(x, z)
		return x + wx, z + wz
	end
	-- Biome dither: one small noise jitter shared by the palette-zone and the
	-- biome-patch lookup, so palette borders and patch edges finger into each
	-- other instead of switching on one line (world_zones.md §7.3).
	local dither = o.biome_dither
	local DA, DP = dither.amplitude, 1 / dither.period
	local DOX, DOZ, DOX2, DOZ2 = offset(), offset(), offset(), offset()
	function s.dither_point(x, z)
		local jx = DA * noise(x * DP + DOX, z * DP + DOZ)
		local jz = DA * noise(x * DP + DOX2, z * DP + DOZ2)
		return floor(x + jx + 0.5), floor(z + jz + 0.5)
	end
	s.warp_raw = warp_raw
	diag.construct_s = now() - t_start
	return s
end

-- ---------------------------------------------------------------- self-check
-- Cheap construction-time check (rough targets, D21) for per-seed layouts (D24):
--   1. every key-point footprint sample in its own zone and on land
--   2. zones connected on a coarse grid (tolerates small fragments and islets)
--   3. every zone's main part on the main land mass
--   4. dragon straits at least `min_strait` nodes of water wide
--   5. dragon island land inside its 600 x 700 envelope
--   6. no Accord zone borders a Throng zone (a shared border of at least
--      `faction_contact` nodes on the grid fails)
-- Returns ok, list of failure strings, stats.
function M.check(s, c)
	local grid = c.grid
	local inland_cells = c.inland_cells   -- inland enclave of >= this many cells fails
	local coast_cells = c.coast_cells     -- coast-cut fragment of >= this many cells fails
	local min_strait = c.min_strait
	local fails = {}
	local sample = s.sample
	local zones = s.source.zones
	-- 1
	for _, kp in ipairs(s.keypoints) do
		for _, smp in ipairs(kp.samples) do
			if sample(smp[1], smp[2]) ~= kp.zone then
				fails[#fails + 1] = "keypoint " .. kp.id
				break
			end
		end
	end
	-- 2 + 3: coarse grid flood fill
	local x0, x1, z0, z1 = c.min_x, c.max_x, c.min_z, c.max_z
	local W = floor((x1 - x0) / grid) + 1
	local H = floor((z1 - z0) / grid) + 1
	local zone = {}
	for j = 0, H - 1 do
		for i = 0, W - 1 do zone[j * W + i] = sample(x0 + i * grid, z0 + j * grid) end
	end
	-- land and zone components, both 8-connected (a coarse grid cannot resolve
	-- narrow necks or thin wedges)
	local function components(lab, same)
		local size, count, stack = {}, 0, {}
		for c0 = 0, W * H - 1 do
			if zone[c0] ~= 0 and not lab[c0] then
				count = count + 1
				local n, sp = 0, 1
				stack[1] = c0 lab[c0] = count
				while sp > 0 do
					local cc = stack[sp] sp = sp - 1 n = n + 1
					local cx, cz = cc % W, (cc - cc % W) / W
					for dz = -1, 1 do for dx = -1, 1 do
						local nx, nz = cx + dx, cz + dz
						if nx >= 0 and nx < W and nz >= 0 and nz < H then
							local nb = nz * W + nx
							if zone[nb] ~= 0 and not lab[nb] and same(cc, nb) then
								lab[nb] = count sp = sp + 1 stack[sp] = nb
							end
						end
					end end
				end
				size[count] = n
			end
		end
		return size
	end
	local land_lab, zone_lab = {}, {}
	local land_size = components(land_lab, function() return true end)
	local zone_size = components(zone_lab, function(a, b) return zone[a] == zone[b] end)
	local touches_sea = {}
	for cc = 0, W * H - 1 do
		local l = zone_lab[cc]
		if l and not touches_sea[l] then
			local cx = cc % W
			if (cx > 0 and zone[cc - 1] == 0) or (cx < W - 1 and zone[cc + 1] == 0) or
				(cc >= W and zone[cc - W] == 0) or (cc < W * (H - 1) and zone[cc + W] == 0) then
				touches_sea[l] = true
			end
		end
	end
	local parts = {}
	local seen = {}
	for cc = 0, W * H - 1 do
		local l = zone_lab[cc]
		if l and not seen[l] then
			seen[l] = true
			local zn = zone[cc]
			parts[zn] = parts[zn] or {}
			local t = parts[zn]
			t[#t + 1] = {size = zone_size[l], land = land_lab[cc], coast = touches_sea[l]}
		end
	end
	local main_land, main_size = nil, 0
	for l, n in pairs(land_size) do if n > main_size then main_land, main_size = l, n end end
	for zn, zr in ipairs(zones) do
		local t = parts[zn]
		if not t then
			fails[#fails + 1] = "zone empty " .. zr.id
		else
			table.sort(t, function(a, b) return a.size > b.size end)
			if not is_island_region(zr.macro_region) and t[1].land ~= main_land then
				fails[#fails + 1] = "zone off the main land " .. zr.id
			end
			for k = 2, #t do
				local islet = land_size[t[k].land] == t[k].size
				local limit = t[k].coast and coast_cells or inland_cells
				if not islet and t[k].size >= limit then
					fails[#fails + 1] = ("zone split %s (%s fragment, %d cells of %d nodes)"):format(
						zr.id, t[k].coast and "coast" or "inland", t[k].size, grid)
				end
			end
		end
	end
	-- 4 + 5: dragon straits and island envelopes
	local island_zone = {}
	for _, zr in ipairs(zones) do
		if is_island_region(zr.macro_region) then island_zone[zr.numeric_id] = true end
	end
	local env = s.params.island_envelope
	local min_gap = math.huge
	for _, zr in ipairs(zones) do
		if island_zone[zr.numeric_id] then
			local sx = zr.hub.x > 0 and 1 or -1
			for z = -env.half_z + 10, env.half_z - 10, 20 do
				local main_x, isl_x = -math.huge, math.huge
				for d = c.strait_from, c.strait_to, 4 do
					local n = sample(sx * d, z)
					if n ~= 0 then
						if island_zone[n] then isl_x = min(isl_x, d)
						else main_x = max(main_x, d) end
					end
				end
				if isl_x < math.huge and main_x > -math.huge then
					min_gap = min(min_gap, isl_x - main_x)
				end
			end
			-- envelope ring: no island land just outside the envelope box
			local hx, hz = zr.hub.x, zr.hub.z
			local ox, oz = env.half_x + 4, env.half_z + 4
			local out = 0
			for t = -oz - 6, oz + 6, 4 do
				if sample(hx - ox, hz + t) == zr.numeric_id then out = out + 1 end
				if sample(hx + ox, hz + t) == zr.numeric_id then out = out + 1 end
			end
			for t = -ox, ox, 4 do
				if sample(hx + t, hz - oz) == zr.numeric_id then out = out + 1 end
				if sample(hx + t, hz + oz) == zr.numeric_id then out = out + 1 end
			end
			if out > 0 then fails[#fails + 1] = ("island outside envelope %s (%d ring samples)"):format(zr.id, out) end
		end
	end
	if min_gap < min_strait then fails[#fails + 1] = ("dragon strait %d < %d nodes"):format(min_gap, min_strait) end
	-- 6: Accord/Throng contact (world_zones.md: the Battlegrounds separate them)
	local faction = {}
	for zn, zr in ipairs(zones) do
		if zr.faction == "accord" or zr.faction == "throng" then faction[zn] = zr.faction end
	end
	local contact = 0
	for j = 0, H - 1 do
		for i = 0, W - 1 do
			local a = faction[zone[j * W + i]]
			if a then
				local b = i < W - 1 and faction[zone[j * W + i + 1]] or nil
				if b and b ~= a then contact = contact + 1 end
				b = j < H - 1 and faction[zone[(j + 1) * W + i]] or nil
				if b and b ~= a then contact = contact + 1 end
			end
		end
	end
	if contact * grid >= (c.faction_contact or 64) then
		fails[#fails + 1] = ("accord/throng contact %d grid edges"):format(contact)
	end
	return #fails == 0, fails, {min_strait = min_gap, grid_samples = W * H,
		faction_contact = contact}
end

-- Build, check, and fall back to a weaker warp until the check passes.
function M.new_checked(seed, source, params)
	local t0 = now()
	local tries = {}
	for _, sc in ipairs(params.fallback_scales) do
		local s = M.new(seed, source, params, sc)
		local ok, fails, stats = M.check(s, params.check)
		tries[#tries + 1] = {scale = sc, ok = ok, fails = fails, stats = stats}
		if ok then
			s.check = {scale = sc, tries = tries, seconds = now() - t0}
			return s
		end
	end
	error("zone field: no warp scale passes the self-check for seed " .. tostring(seed), 0)
end

return M
