-- Round 22 natural terrain field (world_zones.md §7.6; plan D6, D7, D13, D25).
--
-- A float surface height that is a pure function of (seed, x, z): gradient
-- (simplex) noise as fBm, a domain warp, ridged ranges, zone character blended
-- as parameters, soft landmark fields and calm bowls around starts and
-- capitals. Floats are allowed (D2); callers floor the result to a node y.
-- Every tunable is data in `terrain_data.lua`; this file is the mechanism,
-- ported from the accepted Phase 2 prototype (variant R2).
--
-- Seam rules (prototype round 3): no non-distance field feeds a steep ramp,
-- grids are read through cubic B-splines, polyline distance is a smooth
-- minimum, and long low-frequency abs() creases are rounded.
--
--   local field_module = dofile("terrain_field.lua")(dofile("terrain_data.lua"))
--   local field = field_module.new(seed_string, {zones = source.zones,
--       anchors = source.anchors, zone_at = f, land_at = f})
--   field.height_at(x, z, land)  -> float surface y (water level 1)
return function(data)
	local bit = assert(rawget(_G, "bit"), "terrain field needs the bit library")
	local band, bxor, lshift, rshift, tobit = bit.band, bit.bxor, bit.lshift,
		bit.rshift, bit.tobit
	local floor, sqrt, abs, min, max = math.floor, math.sqrt, math.abs,
		math.min, math.max
	local cos, sin, rad, exp, pi = math.cos, math.sin, math.rad, math.exp, math.pi
	local WATER = 1

	local function smoothstep(a, b, x)
		local t = (x - a) / (b - a)
		if t <= 0 then return 0 elseif t >= 1 then return 1 end
		return t * t * (3 - 2 * t)
	end
	local function smootherstep(a, b, x)
		local t = (x - a) / (b - a)
		if t <= 0 then return 0 elseif t >= 1 then return 1 end
		return t * t * t * (t * (t * 6 - 15) + 10)
	end

	---------------------------------------------------------------------------
	-- Seeded 2D simplex noise with analytic derivatives. 256 unit gradients at
	-- seeded random angles (no preferred axis). f(x, z) -> n, dn/dx, dn/dz with
	-- n roughly in [-1, 1].
	---------------------------------------------------------------------------
	local function fnv(s)
		local h = 0x811c9dc5
		for i = 1, #s do
			h = bxor(h, s:byte(i))
			h = tobit((lshift(h, 24) % 0x100000000) + (h % 0x100000000) * 0x193)
		end
		return h % 0x100000000
	end
	local function rng(seed_string, salt)
		local state = fnv(seed_string .. "/" .. salt)
		if state == 0 then state = 0x9e3779b9 end
		state = tobit(state)
		return function()
			state = bxor(state, lshift(state, 13))
			state = bxor(state, rshift(state, 17))
			state = bxor(state, lshift(state, 5))
			return (state % 0x100000000) / 0x100000000
		end
	end
	local F2 = 0.5 * (sqrt(3) - 1)
	local G2 = (3 - sqrt(3)) / 6
	local G2x2m1 = 2 * G2 - 1
	local SCALE = 99.2
	local function simplex(seed_string, salt)
		local rnd = rng(seed_string, "simplex/" .. salt)
		local perm, GX, GZ = {}, {}, {}
		for i = 0, 255 do perm[i] = i end
		for i = 255, 1, -1 do
			local j = floor(rnd() * (i + 1))
			perm[i], perm[j] = perm[j], perm[i]
		end
		for i = 0, 255 do perm[i + 256] = perm[i] end
		for i = 0, 255 do
			local a = rnd() * 2 * pi
			GX[i], GZ[i] = cos(a), sin(a)
		end
		return function(x, z)
			local s = (x + z) * F2
			local i = floor(x + s)
			local j = floor(z + s)
			local t = (i + j) * G2
			local x0 = x - i + t
			local z0 = z - j + t
			local i1, j1 = 0, 1
			if x0 > z0 then i1, j1 = 1, 0 end
			local x1, z1 = x0 - i1 + G2, z0 - j1 + G2
			local x2, z2 = x0 + G2x2m1, z0 + G2x2m1
			local ii, jj = band(i, 255), band(j, 255)
			local n, dx, dz = 0, 0, 0
			local t0 = 0.5 - x0 * x0 - z0 * z0
			if t0 > 0 then
				local g = perm[ii + perm[jj]]
				local gx, gz = GX[g], GZ[g]
				local gd = gx * x0 + gz * z0
				local t2 = t0 * t0
				local t4 = t2 * t2
				local c = -8 * t2 * t0 * gd
				n = t4 * gd
				dx = c * x0 + t4 * gx
				dz = c * z0 + t4 * gz
			end
			local t1 = 0.5 - x1 * x1 - z1 * z1
			if t1 > 0 then
				local g = perm[ii + i1 + perm[jj + j1]]
				local gx, gz = GX[g], GZ[g]
				local gd = gx * x1 + gz * z1
				local t2 = t1 * t1
				local t4 = t2 * t2
				local c = -8 * t2 * t1 * gd
				n = n + t4 * gd
				dx = dx + c * x1 + t4 * gx
				dz = dz + c * z1 + t4 * gz
			end
			local t2_ = 0.5 - x2 * x2 - z2 * z2
			if t2_ > 0 then
				local g = perm[ii + 1 + perm[jj + 1]]
				local gx, gz = GX[g], GZ[g]
				local gd = gx * x2 + gz * z2
				local t2 = t2_ * t2_
				local t4 = t2 * t2
				local c = -8 * t2 * t2_ * gd
				n = n + t4 * gd
				dx = dx + c * x2 + t4 * gx
				dz = dz + c * z2 + t4 * gz
			end
			return SCALE * n, SCALE * dx, SCALE * dz
		end
	end
	-- Octave rotations: an irrational-ish angle per octave, so lattice
	-- artefacts do not stack.
	local ROT_C, ROT_S = {}, {}
	for o = 1, 12 do
		local a = 0.61 + o * 1.37
		ROT_C[o], ROT_S[o] = cos(a), sin(a)
	end

	-- Cubic B-spline weights, shared by the two precomputed grids. Bilinear
	-- reads leave slope kinks on every cell line, which a steep response turns
	-- into straight seams.
	local function bspline(f)
		local f2 = f * f
		return (1 - f) ^ 3 / 6, (3 * f2 * f - 6 * f2 + 4) / 6,
			(-3 * f2 * f + 3 * f2 + 3 * f + 1) / 6, f2 * f / 6
	end

	local module = {simplex = simplex, WATER = WATER}

	function module.new(seed, opts)
		local V = data.params
		local CH = data.channels
		local NC = #CH
		local zones = assert(opts.zones, "terrain field zones missing")
		local zone_at = assert(opts.zone_at, "terrain field zone_at missing")
		local land_at = assert(opts.land_at, "terrain field land_at missing")

		local nwarp1 = simplex(seed, "warp1")
		local nwarp2 = simplex(seed, "warp2")
		local nhills = simplex(seed, "hills")
		local nridge = simplex(seed, "ridge")
		local nrange = simplex(seed, "range")
		local nhilly = simplex(seed, "hilly")
		local ncliff = simplex(seed, "cliff")
		local nmisc = simplex(seed, "misc")

		-- Zone parameter vector: relief id x mild race accent x global knobs.
		local function zone_params(zone)
			local p = {}
			local r = data.relief[zone.primary_relief_id] or
				data.relief[data.default_relief]
			for c = 1, NC do p[CH[c]] = r[CH[c]] end
			local accent = data.race[zone.race_region] or {}
			for c, op in pairs(accent) do
				if op[1] == "+" then p[c] = p[c] + op[2] else p[c] = p[c] * op[2] end
			end
			p.ridge = p.ridge * V.ridge_mul
			p.base = p.base + V.base_add
			p.rshare = max(0, min(1, p.rshare + V.rshare_add))
			p.hill = p.hill * V.hill_mul
			p.rough = p.rough * V.rough_mul
			p.cliff = max(0, p.cliff)
			return p
		end
		local params_by_zone = {}
		for index = 1, #zones do params_by_zone[index] = zone_params(zones[index]) end

		local GX0, GZ0, GX1, GZ1 = V.grid_min_x, V.grid_min_z, V.grid_max_x,
			V.grid_max_z

		-- 1) Zone character grid: normalized convolution of land-only samples.
		local cell = V.blend_cell
		local pnx = floor((GX1 - GX0) / cell) + 1
		local pnz = floor((GZ1 - GZ0) / cell) + 1
		local pgrid = {}
		for c = 1, NC do pgrid[c] = {} end
		local wgrid = {}
		for iz = 0, pnz - 1 do
			for ix = 0, pnx - 1 do
				local k = iz * pnx + ix
				local owner = zone_at(GX0 + ix * cell, GZ0 + iz * cell)
				local p = owner and params_by_zone[owner]
				if p then
					wgrid[k] = 1
					for c = 1, NC do pgrid[c][k] = p[CH[c]] end
				else
					wgrid[k] = 0
					for c = 1, NC do pgrid[c][k] = 0 end
				end
			end
		end
		local tmp = {}
		local function box_blur(a, r)
			for iz = 0, pnz - 1 do
				local row = iz * pnx
				for ix = 0, pnx - 1 do
					local s, n = 0, 0
					for d = -r, r do
						local jx = ix + d
						if jx >= 0 and jx < pnx then s = s + a[row + jx]; n = n + 1 end
					end
					tmp[row + ix] = s / n
				end
			end
			for ix = 0, pnx - 1 do
				for iz = 0, pnz - 1 do
					local s, n = 0, 0
					for d = -r, r do
						local jz = iz + d
						if jz >= 0 and jz < pnz then s = s + tmp[jz * pnx + ix]; n = n + 1 end
					end
					a[iz * pnx + ix] = s / n
				end
			end
		end
		for _ = 1, V.blend_passes do
			box_blur(wgrid, V.blend_radius)
			for c = 1, NC do box_blur(pgrid[c], V.blend_radius) end
		end
		tmp = nil
		local sea_default = data.relief[data.sea_relief]
		for k = 0, pnx * pnz - 1 do
			local w = wgrid[k]
			for c = 1, NC do
				if w > 1e-4 then
					pgrid[c][k] = pgrid[c][k] / w
				else
					pgrid[c][k] = sea_default[CH[c]]
				end
			end
		end
		wgrid = nil
		-- Interleave the channels (cell-major) so one lookup touches a few
		-- cache lines instead of nine scattered grids: scattered queries
		-- (spawning, NPC placement, map render) are dominated by memory reads.
		local G = {}
		for k = 0, pnx * pnz - 1 do
			for c = 1, NC do G[k * NC + c] = pgrid[c][k] end
		end
		pgrid = nil
		local P = {}
		local function params_at(x, z)
			local u = (x - GX0) / cell
			local v = (z - GZ0) / cell
			local iu, iv = floor(u), floor(v)
			local wu0, wu1, wu2, wu3 = bspline(u - iu)
			local wv0, wv1, wv2, wv3 = bspline(v - iv)
			local ix0 = max(1, min(pnx - 3, iu)) - 1
			local iz0 = max(1, min(pnz - 3, iv)) - 1
			local k0 = (iz0 * pnx + ix0) * NC
			local row = pnx * NC
			local k1, k2, k3 = k0 + row, k0 + 2 * row, k0 + 3 * row
			local a, b, d = NC, 2 * NC, 3 * NC
			for c = 1, NC do
				local q0, q1, q2, q3 = k0 + c, k1 + c, k2 + c, k3 + c
				P[c] = wv0 * (wu0 * G[q0] + wu1 * G[q0 + a] + wu2 * G[q0 + b] + wu3 * G[q0 + d])
					+ wv1 * (wu0 * G[q1] + wu1 * G[q1 + a] + wu2 * G[q1 + b] + wu3 * G[q1 + d])
					+ wv2 * (wu0 * G[q2] + wu1 * G[q2 + a] + wu2 * G[q2 + b] + wu3 * G[q2 + d])
					+ wv3 * (wu0 * G[q3] + wu1 * G[q3 + a] + wu2 * G[q3 + b] + wu3 * G[q3 + d])
			end
			return P
		end

		-- 2) Coast distance: a chamfer distance of land_at on a coarse grid,
		-- read through a cubic B-spline. A true distance: the horizontal
		-- session's own coast measures are not (seam rule 1).
		local cc = V.coast_cell
		local cnx = floor((GX1 - GX0) / cc) + 1
		local cnz = floor((GZ1 - GZ0) / cc) + 1
		local sdf = {}
		do
			local landg, dl, ds = {}, {}, {}
			local BIG = 1e9
			for iz = 0, cnz - 1 do
				for ix = 0, cnx - 1 do
					local k = iz * cnx + ix
					local l = land_at(GX0 + ix * cc, GZ0 + iz * cc) and true or false
					landg[k] = l
					dl[k] = l and BIG or 0 -- distance to the nearest sea cell
					ds[k] = l and 0 or BIG -- distance to the nearest land cell
				end
			end
			local D1, D2 = cc, cc * sqrt(2)
			local function chamfer(d)
				for iz = 0, cnz - 1 do
					for ix = 0, cnx - 1 do
						local k = iz * cnx + ix
						local v = d[k]
						if v > 0 then
							if ix > 0 then v = min(v, d[k - 1] + D1) end
							if iz > 0 then
								v = min(v, d[k - cnx] + D1)
								if ix > 0 then v = min(v, d[k - cnx - 1] + D2) end
								if ix < cnx - 1 then v = min(v, d[k - cnx + 1] + D2) end
							end
							d[k] = v
						end
					end
				end
				for iz = cnz - 1, 0, -1 do
					for ix = cnx - 1, 0, -1 do
						local k = iz * cnx + ix
						local v = d[k]
						if v > 0 then
							if ix < cnx - 1 then v = min(v, d[k + 1] + D1) end
							if iz < cnz - 1 then
								v = min(v, d[k + cnx] + D1)
								if ix < cnx - 1 then v = min(v, d[k + cnx + 1] + D2) end
								if ix > 0 then v = min(v, d[k + cnx - 1] + D2) end
							end
							d[k] = v
						end
					end
				end
			end
			chamfer(dl)
			chamfer(ds)
			for k = 0, cnx * cnz - 1 do
				sdf[k] = landg[k] and (dl[k] - cc / 2) or -(ds[k] - cc / 2)
			end
		end
		local function coast_signed(x, z)
			local u = (x - GX0) / cc
			local v = (z - GZ0) / cc
			local iu, iv = floor(u), floor(v)
			local a0, a1, a2, a3 = bspline(u - iu)
			local b0, b1, b2, b3 = bspline(v - iv)
			local ix0 = max(1, min(cnx - 3, iu)) - 1
			local iz0 = max(1, min(cnz - 3, iv)) - 1
			local k0 = iz0 * cnx + ix0
			local k1, k2, k3 = k0 + cnx, k0 + 2 * cnx, k0 + 3 * cnx
			return b0 * (a0 * sdf[k0] + a1 * sdf[k0 + 1] + a2 * sdf[k0 + 2] + a3 * sdf[k0 + 3])
				+ b1 * (a0 * sdf[k1] + a1 * sdf[k1 + 1] + a2 * sdf[k1 + 2] + a3 * sdf[k1 + 3])
				+ b2 * (a0 * sdf[k2] + a1 * sdf[k2 + 1] + a2 * sdf[k2 + 2] + a3 * sdf[k2 + 3])
				+ b3 * (a0 * sdf[k3] + a1 * sdf[k3 + 1] + a2 * sdf[k3 + 2] + a3 * sdf[k3 + 3])
		end

		-- 3) Landmarks: soft fields in rotated local coordinates, bucketed on a
		-- 128-node grid.
		local LMS = {}
		for _, l in ipairs(data.landmarks) do
			local a = rad(l.angle or 0)
			local e = {id = l.id, type = l.type, x = l.x, z = l.z, ca = cos(a),
				sa = sin(a), L = l.L or 0, R = l.R, A = l.A, S = l.S or 14,
				side = l.side or 1, salt = #LMS * 97.3}
			e.reach = e.L + 2 * e.R + 200
			LMS[#LMS + 1] = e
		end
		local BUCKET = 128
		local buckets = {}
		for _, e in ipairs(LMS) do
			for bz = floor((e.z - e.reach) / BUCKET), floor((e.z + e.reach) / BUCKET) do
				for bx = floor((e.x - e.reach) / BUCKET), floor((e.x + e.reach) / BUCKET) do
					local key = bz * 4096 + bx
					local list = buckets[key]
					if not list then list = {}; buckets[key] = list end
					list[#list + 1] = e
				end
			end
		end

		-- 4) Continental ranges: warped polylines with precomputed segments.
		local SPINES = {}
		local SPD = {}
		if V.spines then
			for k, sp in ipairs(data.ranges) do
				local e = {id = sp.id, W = sp.W, A = sp.A, salt = 13.7 * k, segs = {}}
				local acc = 0
				local x0, z0, x1, z1 = 1e9, 1e9, -1e9, -1e9
				for i = 1, #sp.pts - 1 do
					local a, b = sp.pts[i], sp.pts[i + 1]
					local vx, vz = b[1] - a[1], b[2] - a[2]
					local len = sqrt(vx * vx + vz * vz)
					e.segs[i] = {ax = a[1], az = a[2], vx = vx, vz = vz, len2 = len * len,
						len = len, u0 = acc}
					acc = acc + len
					x0, z0 = min(x0, a[1], b[1]), min(z0, a[2], b[2])
					x1, z1 = max(x1, a[1], b[1]), max(z1, a[2], b[2])
				end
				local pad = sp.W * 1.6 + 200
				e.len, e.x0, e.z0, e.x1, e.z1 = acc, x0 - pad, z0 - pad, x1 + pad, z1 + pad
				SPINES[#SPINES + 1] = e
			end
		end

		-----------------------------------------------------------------------
		-- The natural field (no anchor damping). Lua 5.1 allows 60 upvalues per
		-- function; the knobs therefore stay in one table read once per call.
		-----------------------------------------------------------------------
		local K = {HP = V.hill_period, HO = V.hill_octaves, FINE = V.fine,
			CREST = V.crest, RW = V.ridge_warp, RP = V.ridge_period,
			RO = V.ridge_octaves, WA = V.warp, WP = V.warp_period,
			LW = V.landmark_warp, PW = V.param_warp, CLIFF_STEP = V.cliff_step,
			RANGEP = V.range_period, HILLYP = V.hilly_period, SPW = V.spine_warp,
			RANGE_RIDGE = V.range_ridge, MID = V.mid, NEGC = V.neg_compress,
			CW = V.crest_warp, MASSIF_MIN = V.massif_min or 0.55}

		local function landmarks_at(lx, lz)
			local lm_add, rm_boost, mesa_m, mesa_top = 0, 0, 0, 0
			local list = buckets[floor(lz / BUCKET) * 4096 + floor(lx / BUCKET)]
			if not list then return 0, 0, 0, 0 end
			for i = 1, #list do
				local e = list[i]
				local dx, dz = lx - e.x, lz - e.z
				local u = dx * e.ca + dz * e.sa
				local v = -dx * e.sa + dz * e.ca
				local t = e.type
				if t == "valley" then
					local au = abs(u)
					if au < e.L + 2 * e.R then
						local vm = v + 0.9 * e.R * nmisc(u / 260 + e.salt, e.salt)
						local q = 1 - abs(vm) / (e.R * 2.2)
						if q > 0 then
							local taper = 1 - smoothstep(e.L * 0.8, e.L + 2 * e.R, au)
							lm_add = lm_add - e.A * q ^ 1.4 * taper
						end
					end
				elseif t == "escarpment" then
					-- A broad rock band: two ledges, gullies cut into the face, a
					-- broken top that fades back into the land.
					local au = abs(u)
					if au < e.L * 1.4 then
						local g = 1 - abs(nmisc(u / 170 + e.salt, 5.3 * e.salt))
						local vm = e.side * v + 0.3 * e.R * nmisc(u / 300 + e.salt, 3.7 + e.salt)
							- 0.1 * e.R * g * g
						local S = e.S * 2.2
						local step = 0.55 * smoothstep(-S, 0, vm) + 0.45 * smoothstep(S * 0.6, S * 1.6, vm)
						local top = 0.75 + 0.25 * nmisc(u / 140 - e.salt, v / 140)
						local fade = 1 - smoothstep(e.R * 0.6, e.R * 1.8, vm)
						local taper = 1 - smoothstep(e.L * 0.6, e.L * 1.4, au)
						lm_add = lm_add + e.A * step * top * fade * taper
					end
				else
					local du = abs(u) - e.L
					if du < 0 then du = 0 end
					local s = sqrt(du * du + v * v) / e.R
					if t == "basin" then
						if s < 1 then lm_add = lm_add - e.A * (1 - smootherstep(0, 1, s)) end
					elseif t == "lake" then
						if s < 1.1 then lm_add = lm_add - e.A * (1 - smoothstep(0.5, 1.1, s)) end
					elseif t == "dome" then
						if s < 1 then lm_add = lm_add + e.A * (1 - smootherstep(0, 1, s)) end
					elseif t == "ridge" then
						local vm = v + 0.7 * e.R * nmisc(u / 380 + e.salt, 7.1 + e.salt)
						du = abs(u) - e.L
						if du < 0 then du = 0 end
						s = sqrt(du * du + vm * vm) / e.R
						if s < 1 then
							local b = 1 - smoothstep(0, 1, s)
							local along = 0.65 + 0.35 * nmisc(u / 220 - e.salt, 2.9 * e.salt)
							lm_add = lm_add + e.A * along * b ^ 1.5
							if b > rm_boost then rm_boost = b end
						end
					elseif t == "peak" then
						if s < 1 then
							local b = 1 - s
							lm_add = lm_add + e.A * b * b
							if b > rm_boost then rm_boost = b end
						end
					elseif t == "caldera" then
						if s < 1.4 then
							local ring = exp(-((s - 0.72) / 0.22) ^ 2)
							lm_add = lm_add + e.A * ring - 0.35 * e.A * (1 - smoothstep(0, 0.6, s))
							if ring > rm_boost then rm_boost = ring end
						end
					elseif t == "mesa" then
						-- Broken tableland: lobed outline notched by gullies and
						-- two ledges whose outlines differ, so they do not run
						-- parallel like contour rings.
						local g = 1 - abs(nmisc(lx / 150 + e.salt, lz / 150))
						local sm = s + 0.22 * nmisc(lx / 260 + e.salt, lz / 260)
							+ 0.1 * g * g
						local sm2 = sm + 0.12 * nmisc(lx / 120 - 3 * e.salt, lz / 120 + e.salt)
						local m = 0.45 * (1 - smoothstep(0.58, 0.76, sm2))
							+ 0.55 * (1 - smoothstep(0.84, 1.0, sm))
						if m > mesa_m then
							mesa_m = m
							mesa_top = e.A * (0.8 + 0.2 * nmisc(lx / 150 - e.salt, lz / 150))
						end
					elseif t == "ring" then
						-- A broken ring of low mounds (barrows).
						if s > 0.55 and s < 1.25 then
							local ang = math.atan2(v, u)
							local broken = smoothstep(-0.1, 0.4, nmisc(ang * 2.2 + e.salt, 1.3 * e.salt))
							local mounds = 0.6 + 0.4 * nmisc(lx / 45, lz / 45 + e.salt)
							lm_add = lm_add + e.A * exp(-((s - 0.9) / 0.12) ^ 2) * broken * mounds
						end
					end
				end
			end
			return lm_add, rm_boost, mesa_m, mesa_top
		end

		-- Continental spines: returns the spine body height and raises the
		-- range mask `rm` and ridge amplitude `ra`.
		local function spines_at(x, z, wx, wz, ridge, rm, ra)
			local spine_h = 0
			local sx, sz = x + K.SPW * wx, z + K.SPW * wz
			local massif = K.MASSIF_MIN + ridge / 300
			if massif > 1.3 then massif = 1.3 end
			for k = 1, #SPINES do
				local e = SPINES[k]
				if sx > e.x0 and sx < e.x1 and sz > e.z0 and sz < e.z1 then
					-- Smooth minimum of the segment distances; the along-spine
					-- variation comes from 2D noise (seam rule 3).
					local segs = e.segs
					local ds = SPD
					local dmin = 1e18
					for i = 1, #segs do
						local g = segs[i]
						local ox, oz = sx - g.ax, sz - g.az
						local t = (ox * g.vx + oz * g.vz) / g.len2
						if t < 0 then t = 0 elseif t > 1 then t = 1 end
						local ex, ez = ox - t * g.vx, oz - t * g.vz
						local di = sqrt(ex * ex + ez * ez)
						ds[i] = di
						if di < dmin then dmin = di end
					end
					local acc = 0
					for i = 1, #segs do acc = acc + exp((dmin - ds[i]) / 40) end
					local d = dmin - 40 * math.log(acc)
					if d < 0 then d = 0 end
					local W = e.W * (0.8 + 0.3 * nmisc(sx / 1300 + e.salt, sz / 1300))
					if d < W * 1.3 then
						local m = 1 - smoothstep(0, W * 1.3, d)
						local g1, gn = segs[1], segs[#segs]
						local tA = ((sx - g1.ax) * g1.vx + (sz - g1.az) * g1.vz) / g1.len
						local tB = ((gn.ax + gn.vx - sx) * gn.vx + (gn.az + gn.vz - sz) * gn.vz) / gn.len
						local taper = smoothstep(0, 700, tA) * smoothstep(0, 700, tB)
						local along = smoothstep(-0.7, 0.6, nmisc(sx / 850 - e.salt, sz / 850 + 2.3 * e.salt))
						along = 0.3 + 0.7 * along -- low values are the passes
						local mm = m * taper
						local body = e.A * along * mm * mm * massif
						if body > spine_h then spine_h = body end
						if mm > rm then rm = mm end
						local rr = K.RANGE_RIDGE * massif * mm * sqrt(mm) * (0.5 + 0.5 * along)
						if rr > ra then ra = rr end
					end
				end
			end
			return spine_h, rm, ra
		end

		-- Ridged multifractal with a small second warp that breaks long smooth
		-- crest arcs of the lowest octave.
		local function ridged_at(x, z, wx, wz)
			local RP = K.RP
			local kx = 20 * nmisc(x / 300 + 71.3, z / 300)
			local kz = 20 * nmisc(x / 300, z / 300 - 44.1)
			local rx0, rz0 = (x + K.RW * wx + kx) / RP, (z + K.RW * wz + kz) / RP
			local sum, w, a, nrm = 0, 1, 1, 0
			for o = 1, K.RO do
				if o == 4 then rx0, rz0 = (x + 0.3 * wx) / RP * 8, (z + 0.3 * wz) / RP * 8 end
				local c, s = ROT_C[o + 3], ROT_S[o + 3]
				local n = nridge(rx0 * c - rz0 * s + o * 11.1, rx0 * s + rz0 * c - o * 7.9)
				-- rounded crests on the two lowest octaves (seam rule 4)
				local sig = o <= 2 and 1 - sqrt(n * n + 0.004) or 1 - abs(n)
				sig = sig * sig * w
				w = sig * 2
				if w > 1 then w = 1 end
				sum = sum + sig * a
				nrm = nrm + a
				a = a * 0.5
				rx0, rz0 = rx0 * 2, rz0 * 2
			end
			return sum / nrm
		end

		-- Returns the height above water, the small-scale hill part (kept as a
		-- residual inside the city bowls), the warp and the coast ramp width.
		local function natural(x, z)
			local HP = K.HP
			-- Domain warp, 2 octaves; fold-free (folds draw sharp straight edges).
			local ux, uz = x / K.WP, z / K.WP
			local w1 = nwarp1(ux, uz) + 0.5 * nwarp1(ux * 2.03 + 17.1, uz * 2.03 - 3.3)
			local w2 = nwarp2(ux, uz) + 0.5 * nwarp2(ux * 2.03 + 5.3, uz * 2.03 + 11.9)
			local wx, wz = K.WA * w1 / 1.5, K.WA * w2 / 1.5
			local qx, qz = x + wx, z + wz

			local p = params_at(x + K.PW * wx, z + K.PW * wz)
			local base, hill, gain, ridge, rshare, cliff, erode, rough =
				p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]
			local coastw = p[9]

			local lm_add, rm_boost, mesa_m, mesa_top =
				landmarks_at(x + K.LW * wx, z + K.LW * wz)

			-- Hilliness: calm and hilly patches inside a zone.
			local hm = 0.8 + 0.55 * nhilly(x / K.HILLYP, z / K.HILLYP)
			if hm < 0.25 then hm = 0.25 elseif hm > 1.3 then hm = 1.3 end

			-- Hills: rotated fBm octaves. Octaves 1-3 (landforms) take the full
			-- warp and crest shaping; finer octaves a weaker warp. The slope of
			-- the landform octaves damps the fine octaves ("erosion look").
			local px, pz = qx / HP, qz / HP
			local dx4, dz4 = (x + 0.3 * wx) / HP * 8, (z + 0.3 * wz) / HP * 8
			local amp, sum_lo, sum_hi = 1, 0, 0
			local ddx, ddz = 0, 0
			local f = 1
			local hscale = hill * hm
			local CREST, MID = K.CREST, K.MID
			for o = 1, 3 do
				if o == 2 then px, pz = (x + K.CW * wx) / HP * 2, (z + K.CW * wz) / HP * 2 end
				local c, s = ROT_C[o], ROT_S[o]
				local rx, rz = px * c - pz * s, px * s + pz * c
				local n, nx, nz = nhills(rx + o * 31.7, rz - o * 17.3)
				ddx = ddx + amp * f * (nx * c + nz * s)
				ddz = ddz + amp * f * (-nx * s + nz * c)
				local an = sqrt(n * n + 0.01)
				local nn = n
				if o >= 2 then nn = n + CREST * erode * ((1 - an) * (1 - an) * 2 - 0.85 - n) end
				local a = o >= 2 and amp * MID or amp
				if o <= 2 then sum_lo = sum_lo + a * nn else sum_hi = sum_hi + a * nn end
				amp = amp * gain
				px, pz = px * 2, pz * 2
				f = f * 2
			end
			local ls = hscale * sqrt(ddx * ddx + ddz * ddz) / HP
			local damp = 1 / (1 + erode * (ls / 0.3) ^ 2)
			px, pz = dx4, dz4
			local FINE = K.FINE
			for o = 4, K.HO do
				local c, s = ROT_C[o], ROT_S[o]
				local n = nhills(px * c - pz * s + o * 31.7, px * s + pz * c - o * 17.3)
				local a = amp
				if o >= 5 then a = a * rough end
				sum_hi = sum_hi + a * damp * n
				amp = amp * gain * FINE
				px, pz = px * 2, pz * 2
			end

			-- Ranges: ridged noise where the range mask allows it.
			local rv = 0.5 + 0.5 * nrange(x / K.RANGEP, z / K.RANGEP)
			local rm = smoothstep(1 - rshare - 0.12, 1 - rshare + 0.12, rv)
			if rm_boost > rm then rm = rm_boost end
			local ra = ridge * rm
			local ridge_h = 0
			if #SPINES > 0 then
				ridge_h, rm, ra = spines_at(x, z, wx, wz, ridge, rm, ra)
			end
			if ra > 0 then ridge_h = ridge_h + ra * ridged_at(x, z, wx, wz) end

			-- Hills rise from plains more than valleys sink below them.
			local hv = sum_lo + sum_hi
			hv = hv - K.NEGC * 0.5 * (hv - sqrt(hv * hv + 0.09))
			local relief = hscale * hv + ridge_h
			local h = base + relief

			-- Occasional soft ledges, warped so they do not follow contours.
			if cliff > 0.01 then
				local cm = cliff * smoothstep(0.15, 0.55, ncliff(x / 900, z / 900))
				if cm > 0.01 then
					local CLIFF_STEP = K.CLIFF_STEP
					local jitter = 0.35 * ncliff(x / 170 + 40, z / 170)
					local t = h / CLIFF_STEP + jitter
					local k = floor(t)
					local fr = smoothstep(0.35, 0.75, t - k)
					local terr = (k + fr - jitter) * CLIFF_STEP
					h = h + cm * (terr - h)
				end
			end
			-- Mesas replace the field with a near-flat top.
			if mesa_m > 0 then
				local top = base + mesa_top + 0.6 * relief
				h = h + mesa_m * (top - h)
			end
			h = h + lm_add
			return h, hscale * sum_hi, wx, wz, coastw
		end

		-- Soft floor of dry land. Inland it keeps land about one node above the
		-- water (floor 1, knee 4); toward the shore it sinks to the water
		-- surface itself (floor 0, knee 1.5), so a beach runs down to the water
		-- instead of standing on a step (plan D35). C1 at the knee.
		local SHORE_FLOOR_REACH = 48
		local function soft_floor(h, sd)
			local t = smoothstep(0, SHORE_FLOOR_REACH, sd)
			local knee = 1.5 + 1.5 * t
			local k = t + knee
			if h < k then return t + knee * exp((h - k) / knee) end
			return h
		end

		-- Coast ramp and sea floor on top of the natural field. One profile
		-- runs through the waterline (plan D35): near the water the land's
		-- blend target slopes down to the water surface (1:8) and the sea floor
		-- starts just below it and deepens across a shallow shelf (the coral
		-- depths), then falls away to the deep sea. Gentle coasts shelve
		-- slowly; short ramps, where the land meets the sea steeply, shelve
		-- faster. Returns the height and the coast distance.
		local BEACH, SHELF, SHELF_NEAR, SHELF_EDGE = 0.12, 0.07, 1.8, 70
		local function with_coast(x, z, h, land, cw)
			local sd = coast_signed(x, z)
			local steep = smoothstep(0.35, 0.7, nmisc(x / 700 + 91, z / 700 - 13))
			cw = cw + (40 - cw) * steep
			if land then
				local r = smoothstep(-20, cw, sd + 30 * nmisc(x / 260, z / 260 + 50))
				local shore = BEACH * sd
				if shore > 1.5 then shore = 1.5 end
				h = shore + (h - shore) * r
				h = soft_floor(h, sd)
			else
				local d = sd < 0 and -sd or 0
				local k = 150 / cw
				if k < 0.75 then k = 0.75 elseif k > 1.25 then k = 1.25 end
				local depth = k * (SHELF * d + SHELF_NEAR * (1 - exp(-d / 10)))
				-- Past the shallow shelf the floor falls away to the deep sea.
				local off = d - SHELF_EDGE
				if off > 0 then depth = depth + 0.12 * off * off / (off + 40) end
				if depth > 31.7 then depth = 31.7 end
				h = -(0.3 + depth) + 1.5 * nmisc(x / 120, z / 120) * smoothstep(0, 40, d)
				if h > -0.3 then h = -0.3 end
			end
			return h, sd
		end

		-----------------------------------------------------------------------
		-- Starts and capitals: damping masks keyed to the anchor (the civic-core
		-- centre for a capital, D7 and guardrail 8).
		-----------------------------------------------------------------------
		-- Capitals (D28): only the civic core is flat. Around it the calm zone
		-- keeps long-wave hills and hollows of limited height, faded in from
		-- the core, and its outer edge is pulled in and out by noise, so the
		-- zone is neither flat nor round. Starts keep a plain calm bowl.
		local nwave = simplex(seed, "capital_wave")
		local nedge = simplex(seed, "capital_edge")
		local WAVE_P, WAVE_CORE, WAVE_FULL = V.capital_wave_period,
			V.capital_wave_core, V.capital_wave_full
		local EDGE, EDGE_P = V.capital_edge, V.capital_edge_period
		local ANCH = {}
		for _, a in ipairs(opts.anchors or {}) do
			local slot = a.slot_id
			if slot == "start" or slot == "capital" then
				local zone = zones[a.zone_numeric_id]
				local e = {id = a.id, slot = slot, zone = zone.id, race = zone.race_region,
					x = a.position.x, z = a.position.z}
				if slot == "capital" then
					e.r_in, e.r_out, e.resid = V.capital_r_in, V.capital_r_out, V.capital_resid
					e.band = data.capital_target[zone.race_region] or V.start_band
					e.wave = data.capital_wave[zone.race_region] or 0
					e.edge = EDGE
				else
					e.r_in, e.r_out, e.resid = V.start_r_in, V.start_r_out, V.start_resid
					e.band = V.start_band
					e.wave, e.edge = 0, 0
				end
				local sum, n = 0, 0
				local r, step = V.target_radius, V.target_step
				for dz = -r, r, step do
					for dx = -r, r, step do
						if dx * dx + dz * dz <= r * r then
							local h, _, _, _, cw = natural(e.x + dx, e.z + dz)
							sum = sum + with_coast(e.x + dx, e.z + dz, h, true, cw)
							n = n + 1
						end
					end
				end
				e.natural_mean = sum / n
				e.target = max(e.band[1], min(e.band[2], e.natural_mean))
				e.edge_p = EDGE_P
				ANCH[#ANCH + 1] = e
			end
		end
		-- POIs on steep ground (plan D33): where the natural relief under a
		-- POI's building core exceeds `poi_bowl_relief`, a small calm bowl
		-- around it turns the slope or summit into a shelf at the local
		-- ground's mean height, so the core is fitted onto a natural-looking
		-- plateau instead of dug into the slope. Unwarped distance (the bowl
		-- is small), an irregular outer edge.
		local profile_by_id = {}
		for _, p in ipairs(opts.anchor_profiles or {}) do profile_by_id[p.id] = p end
		local function undamped(x, z)
			local h, _, _, _, cw = natural(x, z)
			return (with_coast(x, z, h, true, cw))
		end
		for _, a in ipairs(opts.anchors or {}) do
			local profile = profile_by_id[a.template_id]
			local core = profile and profile.building_core_width
			if core and a.slot_id ~= "start" and a.slot_id ~= "capital" then
				local ax, az, half = a.position.x, a.position.z, core / 2
				local lo, hi = math.huge, -math.huge
				for dz = -half, half, 4 do
					for dx = -half, half, 4 do
						if land_at(ax + dx, az + dz) then
							local h = undamped(ax + dx, az + dz)
							if h < lo then lo = h end
							if h > hi then hi = h end
						end
					end
				end
				if hi > lo and hi - lo > V.poi_bowl_relief then
					local r_in = core * V.poi_bowl_core + V.poi_bowl_pad
					local sum, n = 0, 0
					for dz = -r_in, r_in, 4 do
						for dx = -r_in, r_in, 4 do
							if dx * dx + dz * dz <= r_in * r_in and land_at(ax + dx, az + dz) then
								sum, n = sum + undamped(ax + dx, az + dz), n + 1
							end
						end
					end
					if n > 0 then ANCH[#ANCH + 1] = {id = a.id, slot = a.slot_id, x = ax, z = az,
						r_in = r_in, r_out = r_in + V.poi_bowl_width, resid = V.poi_bowl_resid,
						target = sum / n, natural_mean = sum / n, wave = 0,
						edge = V.poi_bowl_edge, edge_p = V.poi_bowl_edge_period, nowarp = true} end
				end
			end
		end
		-- Water landmarks that are authored lakes (plan D41, Moonfall's
		-- crescent): a calm bowl at the landmark's mean natural height, so the
		-- lake lies on a shelf instead of a hillside.
		for _, l in ipairs(data.landmarks) do
			local b = l.bowl
			if b then
				local sum, n = 0, 0
				for dz = -b.r, b.r, 8 do
					for dx = -b.r, b.r, 8 do
						if dx * dx + dz * dz <= b.r * b.r and land_at(l.x + dx, l.z + dz) then
							sum, n = sum + undamped(l.x + dx, l.z + dz), n + 1
						end
					end
				end
				if n > 0 then ANCH[#ANCH + 1] = {id = l.id, slot = "landmark", x = l.x, z = l.z,
					r_in = b.r, r_out = b.r + b.width, resid = b.resid, target = sum / n,
					natural_mean = sum / n, wave = 0, edge = V.poi_bowl_edge,
					edge_p = V.poi_bowl_edge_period, nowarp = true} end
			end
		end
		local AW = V.anchor_warp
		-- The calm ground of one anchor at distance `d`: its target, the
		-- long-wave undulation (capitals) and a residual of the small hills.
		local function calm_at(e, x, z, hills_hi)
			local y = e.target + e.resid * hills_hi
			if e.wave > 0 then
				-- Faded in by the true distance from the civic-core centre, so
				-- the core itself stays at the target.
				local cx, cz = x - e.x, z - e.z
				local n = nwave(x / WAVE_P, z / WAVE_P) +
					0.3 * nwave(x / WAVE_P * 2 + 37.1, z / WAVE_P * 2 - 11.9)
				y = y + e.wave * n / 1.3 *
					smoothstep(WAVE_CORE, WAVE_FULL, sqrt(cx * cx + cz * cz))
			end
			return y
		end
		local function damp(x, z, h, hills_hi, wx, wz)
			local ax, az = x + AW * wx, z + AW * wz
			local best_m, best, best_calm, count = 1, nil, nil, 0
			local w_sum, c_sum, m_prod = 0, 0, 1
			for i = 1, #ANCH do
				local e = ANCH[i]
				local dx, dz = ax - e.x, az - e.z
				if e.nowarp then dx, dz = x - e.x, z - e.z end
				local d2 = dx * dx + dz * dz
				local r_out = e.r_out * (1 + e.edge)
				if d2 < r_out * r_out then
					local d = sqrt(d2)
					-- Irregular outer edge: the fade-out radius grows by up to
					-- `edge` with a smooth 2D noise (seam rules: no angle
					-- parameter, no crease). It only grows, so the district
					-- plots never lose calm ground.
					if e.edge > 0 then
						r_out = e.r_out * (1 + e.edge * 0.5 *
							(1 + nedge(x / e.edge_p, z / e.edge_p)))
					else
						r_out = e.r_out
					end
					local m = smootherstep(e.r_in, r_out, d)
					if m < 1 then
						local calm = calm_at(e, x, z, hills_hi)
						if m < best_m then best_m, best, best_calm = m, e, calm end
						count = count + 1
						m_prod = m_prod * m
						local w = 1 - m
						w_sum, c_sum = w_sum + w, c_sum + w * calm
					end
				end
			end
			if not best then return h, 1 end
			if count == 1 or w_sum <= 0 then
				return best_calm + best_m * (h - best_calm), best_m
			end
			-- Overlapping bowls (a capital's calm zone can reach a start's, two
			-- POI bowls can meet): blend their calm grounds by influence and
			-- multiply their fade factors. The minimum of the factors would
			-- crease along the straight bisector between the two anchors.
			local calm = c_sum / w_sum
			return calm + m_prod * (h - calm), m_prod
		end

		local field = {anchors = ANCH, landmarks = LMS, coast_signed = coast_signed,
			params_at = params_at}

		-- Float surface y. `land` is the caller's land/water decision for this
		-- column (it already classified it); nil asks land_at.
		function field.height_at(x, z, land)
			if land == nil then land = land_at(x, z) end
			local h, hills_hi, wx, wz, cw = natural(x, z)
			local sd
			h, sd = with_coast(x, z, h, land, cw)
			if land then
				h = soft_floor(damp(x, z, h, hills_hi, wx, wz), sd)
			end
			return WATER + h
		end

		-- Debug parts for the render harness: y, land, damping weight.
		function field.parts_at(x, z, land)
			if land == nil then land = land_at(x, z) end
			local h, hills_hi, wx, wz, cw = natural(x, z)
			local sd
			h, sd = with_coast(x, z, h, land, cw)
			local m = 1
			if land then
				h, m = damp(x, z, h, hills_hi, wx, wz)
				h = soft_floor(h, sd)
			end
			return WATER + h, land, m
		end

		-- Undamped surface (the capital fit table's "before damping" column).
		function field.undamped_at(x, z, land)
			if land == nil then land = land_at(x, z) end
			local h, _, _, _, cw = natural(x, z)
			return WATER + with_coast(x, z, h, land, cw), land
		end

		return field
	end

	return module
end
