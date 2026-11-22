-- The arena's site and ground (Round 85 WORLD, round85-plan.md §4 WORLD,
-- rulings 5, 9 and 22). Pure, plain Lua 5.1, no globals; the geometry is
-- `breach_layout.lua`'s.
--
--   local B = dofile(wp40 .. "/breach_site.lua")(dofile(wp40 .. "/breach_layout.lua"))
--   local site, stats = B.search(q)        -- main, in the POI placement
--   local profile = B.profile(site, natural_height_at)   -- every height session
--   local y = B.ground(profile, x, z, natural)            -- a graded column or nil
--
-- THE SITE (ruling 9): the best site in a window of WINDOW nodes round
-- (0, 0), read from the natural world only (the placement session: the
-- natural carved ground, the inland water, the zones), which the arena does
-- not change (it is no anchor: the zone field, the terrain field and the
-- inland water never see it). Candidates on a LATTICE-node lattice; a
-- coarse pass over an 8-node raster ranks them, they are measured exactly
-- in that order until FINALISTS passed (EXACT_MAX tried at most) and the
-- lowest exact score wins (ties: nearer (0, 0), then by x, then z):
--   score = earth + K_REACH * reach + K_ROAD * detour + K_Z * |z|
--           + K_FACE * max(0, face - FACE_FREE)
-- with earth the mean |natural - datum| over the levelled hull (the work
-- of levelling), reach the blend's widest reach beyond it, detour what
-- passing through the site adds to the natural middle road, and a pull
-- toward z = 0, the line halfway between the two factions' capitals, and
-- face the steepest natural grade (rise or fall over 4 nodes along the hull's
-- outward normal, every second bin's ray) from the hull out to FACE_REACH
-- beyond the blend's edge: a steep natural bank right behind the hull or
-- the blend's edge, which a player in the arena would look at, costs a site
-- only above FACE_FREE, so a site on ordinary ground keeps its score. The
-- natural middle road is stood in by the cheapest south-north path across
-- the raster (8-neighbour Dijkstra with the router's grade costs and its
-- axis guide round x = 0, `road_layout.lua` GMAX, K_STEEP, K_GENTLE, G0,
-- K_G, AXIS_FREE, K_AXIS; water a bridge's cost): detour = the cheapest
-- path through the site's cell minus the cheapest path, in node lengths,
-- so a site off the road or on a hill the road would pass by costs its
-- climb and its bend. A candidate is refused when the hull plus DRY
-- nodes is not all land of the two Battlegrounds zones round the centre,
-- holds inland water, water lies within WET_MARGIN of the graded ground, or
-- its rim's step needs a blend wider than WIDTH_MAX.
-- When no candidate passes, the measured candidate that meets every rule
-- but the blend's width and needs the narrowest blend (of the up to
-- EXACT_MAX candidates measured, not of the whole window) is taken, its blend
-- up to WIDTH_FALLBACK (so the grade bound holds unless it needs more), and
-- the stats say "fallback" (Round 85 fix 3: seed 5664044364126834037);
-- when none even does that, the coarse best, and the stats say "wet".
--
-- THE GROUND (rulings 5 and 22): the hull is flat at the datum (the lower
-- median of the natural ground under it). Outside it each column keeps its
-- natural shape, offset toward the datum: natural + w(d / W) * delta, with
-- d the distance to the hull, delta = datum - the natural ground just
-- outside the hull at the column's nearest hull point (averaged along the
-- hull), W = clamp(1.5 * |delta| / GRADE, WIDTH_MIN, WIDTH_FALLBACK)
-- widened and averaged along the hull (a site that passes needs at most
-- WIDTH_MAX), and w = 1 - smoothstep. So the blend adds at most
-- GRADE to the natural grade (1.5 is smoothstep's steepest slope), reaches
-- no farther than the site needs, keeps no flat apron and cuts no wall; it
-- ignores the zone border (both zones' columns, one datum).
return function(layout)
	assert(type(layout) == "table" and type(layout.hull_project) == "function",
		"breach site: layout differs")
	local floor, ceil, abs, sqrt, min, max = math.floor, math.ceil, math.abs, math.sqrt,
		math.min, math.max
	local M = {layout = layout}
	local P = {WINDOW = 200, LATTICE = 8, RASTER = 8, GRADE = 0.5, WIDTH_MIN = 8,
		WIDTH_MAX = 64, WIDTH_FALLBACK = 128, EASE = 12, EDGE_SPAN = 4,
		-- the grade the checks hold the blend to (4-node baseline): GRADE and
		-- up to three quarters of a node per node for the rounding, the ease's
		-- own detail and the width's change along the hull (measured: 0.75 on
		-- the eleven study seeds, 1 on all but one of the fleet's 100, 1.25
		-- on a sharp natural ridge of 1552427553307566)
		LIMIT = 1.25,
		-- a steep natural face round the site (Round 85 fix 2, the user): free
		-- up to FACE_FREE (natural grade, rise or fall per node over 4 nodes), then
		-- K_FACE per unit; read out to FACE_REACH beyond the blend's edge
		FACE_FREE = 1.5, K_FACE = 4, FACE_REACH = 8, BINS = 152, SMOOTH = 4, RING = 4, DRY = 8, WET_MARGIN = 4,
		FINALISTS = 8, EXACT_MAX = 64, K_REACH = 0.1, K_ROAD = 0.02, K_Z = 0.02,
		-- the natural middle road's stand-in (road_layout.lua's values)
		GMAX = 0.4, K_STEEP = 25, K_GENTLE = 0.6, G0 = 0.25, K_G = 3, AXIS_FREE = 48,
		K_AXIS = 0.02, C_WET = 60,
		ZONES = {"front_broken_causeway", "front_shattered_line"}}
	M.P = P
	local HX, HZ = layout.HALF_X, layout.HALF_Z
	local PERIMETER = layout.PERIMETER

	local function smoothstep(t)
		if t <= 0 then return 0 elseif t >= 1 then return 1 end
		return t * t * (3 - 2 * t)
	end
	local function lower_median(values)
		table.sort(values)
		return values[floor((#values + 1) / 2)]
	end
	local function round(v) return floor(v + 0.5) end

	-- The blend's per-bin numbers along the hull for a datum: delta and
	-- width (BINS bins of equal arc, bin i centred at (i - 0.5) / BINS).
	local function bins_of(cx, cz, datum, natural_at)
		local n, k = P.BINS, P.SMOOTH
		local nat = {}
		for i = 1, n do
			local px, pz, nx, nz = layout.hull_point((i - 0.5) * PERIMETER / n)
			local sum = 0
			for r = 1, P.RING do
				sum = sum + natural_at(cx + round(px + nx * r), cz + round(pz + nz * r))
			end
			nat[i] = sum / P.RING
		end
		local function circular(values, reduce)
			local out = {}
			for i = 1, n do
				local acc = reduce == "max" and -math.huge or 0
				for j = -k, k do
					local v = values[(i - 1 + j) % n + 1]
					if reduce == "max" then acc = max(acc, v) else acc = acc + v end
				end
				out[i] = reduce == "max" and acc or acc / (2 * k + 1)
			end
			return out
		end
		local smooth = circular(nat)
		-- (a site that passes needs at most WIDTH_MAX everywhere, so the cap
		-- WIDTH_FALLBACK only ever holds the fallback's wider blend)
		local delta, width, capped, most = {}, {}, false, 0
		for i = 1, n do
			delta[i] = datum - smooth[i]
			local need = 1.5 * abs(delta[i]) / P.GRADE
			if need > P.WIDTH_MAX then capped = true end
			most = max(most, need)
			width[i] = min(max(need, P.WIDTH_MIN), P.WIDTH_FALLBACK)
		end
		width = circular(circular(width, "max"))
		local reach = 0
		for i = 1, n do reach = max(reach, width[i]) end
		return delta, width, reach, capped, most
	end

	-- The blend of a site: {x, z, y, delta, width, reach (exact), bbox}.
	function M.profile(site, natural_at)
		assert(type(site) == "table" and type(natural_at) == "function", "breach profile seam")
		local delta, width, reach, capped, need = bins_of(site.x, site.z, site.y, natural_at)
		return {x = site.x, z = site.z, y = site.y, delta = delta, width = width,
			reach = reach, capped = capped, need = need, min_x = site.x - HX - ceil(reach), max_x = site.x + HX + ceil(reach),
			min_z = site.z - HZ - ceil(reach), max_z = site.z + HZ + ceil(reach)}
	end

	-- The steepest natural grade round a site (its profile): rise or fall over 4
	-- nodes along the hull's outward normal, every 2 nodes from the hull out
	-- to its bin's blend width + FACE_REACH, on every second bin's ray.
	function M.face(profile, natural_at)
		local worst = 0
		for i = 1, P.BINS, 2 do
			local px, pz, nx, nz = layout.hull_point((i - 0.5) * PERIMETER / P.BINS)
			local last = profile.width[i] + P.FACE_REACH
			local function at(t)
				return natural_at(profile.x + round(px + nx * t), profile.z + round(pz + nz * t))
			end
			local t = 0
			while t <= last do
				worst = max(worst, abs(at(t + 4) - at(t)) / 4)
				t = t + 2
			end
		end
		return worst
	end

	-- A column's levelled ground: the datum on the hull, the blended value
	-- and its weight in the blend, nil beyond it. `natural` is the column's
	-- natural (carved) ground, `natural_at` the natural ground's query.
	function M.ground(profile, x, z, natural, natural_at)
		if x < profile.min_x or x > profile.max_x or z < profile.min_z or z > profile.max_z then
			return nil
		end
		local d, s = layout.hull_project(x - profile.x, z - profile.z)
		if d == 0 then return profile.y, 1 end
		if d >= profile.reach then return nil end
		local n = P.BINS
		local t = s / PERIMETER * n - 0.5
		local i0 = floor(t)
		local f = t - i0
		local a, b = i0 % n + 1, (i0 + 1) % n + 1
		local width = profile.width[a] * (1 - f) + profile.width[b] * f
		if d >= width then return nil end
		local delta = profile.delta[a] * (1 - f) + profile.delta[b] * f
		local w = 1 - smoothstep(d / width)
		local value = natural + w * delta
		local ease = min(P.EASE, width)
		if d < ease then
			-- the ease: the natural ground at the nearest hull column against
			-- the hull's averaged edge there (datum - delta) fades out within
			-- EASE, so the blend meets the datum exactly at the hull
			-- (the natural ground read bilinearly along the hull round the
			-- nearest hull point, EDGE_SPAN nodes each way every 2: a rounded
			-- column jumps by the ground's own steps, and the mean keeps the
			-- ground's slope along the hull out of the blend)
			local edge, count = 0, 0
			for o = -P.EDGE_SPAN, P.EDGE_SPAN, 2 do
				local px, pz = layout.hull_point(s + o)
				px, pz = profile.x + px, profile.z + pz
				local ix, iz = floor(px), floor(pz)
				local fx, fz = px - ix, pz - iz
				edge = edge + (natural_at(ix, iz) * (1 - fx) + natural_at(ix + 1, iz) * fx) * (1 - fz) +
					(natural_at(ix, iz + 1) * (1 - fx) + natural_at(ix + 1, iz + 1) * fx) * fz
				count = count + 1
			end
			edge = edge / count
			value = value - (1 - smoothstep(d / ease)) * (edge - profile.y + delta)
		end
		return floor(value + 0.5), w
	end

	-- THE SEARCH. `q`: natural_at(x, z) (the natural carved ground y),
	-- wet(x, z) (natural inland water), zone_at(x, z) (the land column's zone
	-- numeric id or nil), zone_number(id), blocked(x, z, half) (true when
	-- a square of half side `half` round x, z meets a fixed anchor's square).
	-- Returns the site {x, z, y, reach} and stats {seconds, candidates,
	-- finalists, wet, score, earth, reach}.
	function M.search(q)
		local started = os.clock()
		local allowed = {}
		for _, id in ipairs(P.ZONES) do allowed[assert(q.zone_number(id), id)] = true end
		local R, W = P.RASTER, P.WINDOW
		-- The 8-node raster: heights, wet, allowed land.
		local reach_r = W + HX + P.WIDTH_MAX + P.DRY + R
		local n = floor(reach_r / R)
		local side = 2 * n + 1
		local H, WET, OK = {}, {}, {}
		for j = 0, side - 1 do
			for i = 0, side - 1 do
				local x, z = (i - n) * R, (j - n) * R
				local k = j * side + i
				local zone = q.zone_at(x, z)
				OK[k] = zone ~= nil and allowed[zone] == true
				H[k] = q.natural_at(x, z)
				WET[k] = q.wet(x, z)
			end
		end
		-- The natural middle road's stand-in: the cheapest paths from the
		-- raster's south row (dS) and from its north row (dN).
		local function dijkstra(row)
			local dist, done = {}, {}
			local hv, hk, hn = {}, {}, 0
			local function push(k, key)
				hn = hn + 1
				local m = hn
				while m > 1 do
					local parent = floor(m / 2)
					if hk[parent] < key or (hk[parent] == key and hv[parent] <= k) then break end
					hv[m], hk[m] = hv[parent], hk[parent]
					m = parent
				end
				hv[m], hk[m] = k, key
			end
			local function pop()
				local k, key = hv[1], hk[1]
				local lv, lk = hv[hn], hk[hn]
				hv[hn], hk[hn] = nil, nil
				hn = hn - 1
				local m = 1
				while true do
					local c = m * 2
					if c > hn then break end
					if c < hn and (hk[c + 1] < hk[c] or (hk[c + 1] == hk[c] and hv[c + 1] < hv[c])) then
						c = c + 1
					end
					if lk < hk[c] or (lk == hk[c] and lv <= hv[c]) then break end
					hv[m], hk[m] = hv[c], hk[c]
					m = c
				end
				if hn > 0 then hv[m], hk[m] = lv, lk end
				return k, key
			end
			for i = 0, side - 1 do
				local k = row * side + i
				dist[k] = 0
				push(k, 0)
			end
			while hn > 0 do
				local k, key = pop()
				if not done[k] then
					done[k] = true
					local i, j = k % side, floor(k / side)
					for dj = -1, 1 do
						for di = -1, 1 do
							local ii, jj = i + di, j + dj
							if (di ~= 0 or dj ~= 0) and ii >= 0 and jj >= 0 and ii < side and jj < side then
								local m = jj * side + ii
								local len = (di ~= 0 and dj ~= 0) and R * 1.4142135623730951 or R
								local g = abs(H[m] - H[k]) / len
								local cost = len * (1 + P.K_STEEP * max(g - P.GMAX, 0) / P.GMAX +
									P.K_GENTLE * min(g, 0.25) / 0.25)
								local qg = max(g - P.G0, 0) / (P.GMAX - P.G0)
								cost = cost + len * P.K_G * qg * qg +
									len * P.K_AXIS * max(abs((ii - n) * R) - P.AXIS_FREE, 0)
								if WET[m] then cost = cost + P.C_WET end
								local d = key + cost
								if not done[m] and (dist[m] == nil or d < dist[m]) then
									dist[m] = d
									push(m, d)
								end
							end
						end
					end
				end
			end
			return dist
		end
		local dS, dN = dijkstra(0), dijkstra(side - 1)
		local best_path = math.huge
		for i = 0, side - 1 do best_path = min(best_path, dS[(side - 1) * side + i]) end
		local function detour(cx, cz)
			local k = (n + cz / R) * side + n + cx / R
			return dS[k] + dN[k] - best_path
		end

		-- Raster offsets (in cells) of the hull, its DRY margin and its ring,
		-- and those of the blend's widest reach by distance (the coarse wet
		-- test).
		local hull_cells, dry_cells, ring_cells, blend_cells = {}, {}, {}, {}
		local span = floor((HX + P.WIDTH_MAX + P.WET_MARGIN) / R) + 1
		for dj = -span, span do
			for di = -span, span do
				local d = layout.hull_project(di * R, dj * R)
				if d == 0 then hull_cells[#hull_cells + 1] = {di, dj} end
				if d <= P.DRY then dry_cells[#dry_cells + 1] = {di, dj} end
				if d > 0 and d <= R then ring_cells[#ring_cells + 1] = {di, dj} end
				if d > P.DRY and d <= P.WIDTH_MAX + P.WET_MARGIN then
					blend_cells[#blend_cells + 1] = {di, dj, d}
				end
			end
		end
		table.sort(blend_cells, function(l, r)
			if l[3] ~= r[3] then return l[3] < r[3] end
			if l[2] ~= r[2] then return l[2] < r[2] end
			return l[1] < r[1]
		end)
		local coarse = {}
		local values = {}
		for cz = -W, W, P.LATTICE do
			for cx = -W, W, P.LATTICE do
				if cx * cx + cz * cz <= W * W then
					local ci, cj = n + cx / R, n + cz / R
					local ok, earth, reach = true, 0, 0
					for _, c in ipairs(dry_cells) do
						local k = (cj + c[2]) * side + ci + c[1]
						if not OK[k] or WET[k] then ok = false break end
					end
					if ok then
						for index = #values, 1, -1 do values[index] = nil end
						for index, c in ipairs(hull_cells) do
							values[index] = H[(cj + c[2]) * side + ci + c[1]]
						end
						local datum = lower_median(values)
						for _, v in ipairs(values) do earth = earth + abs(v - datum) end
						earth = earth / #values
						local dmax = 0
						for _, c in ipairs(ring_cells) do
							dmax = max(dmax, abs(H[(cj + c[2]) * side + ci + c[1]] - datum))
						end
						reach = min(max(1.5 * dmax / P.GRADE, P.WIDTH_MIN), P.WIDTH_MAX)
						for _, c in ipairs(blend_cells) do
							if c[3] > reach + P.WET_MARGIN then break end
							if WET[(cj + c[2]) * side + ci + c[1]] then ok = false break end
						end
					end
					if ok then
						coarse[#coarse + 1] = {x = cx, z = cz, score = earth + P.K_REACH * reach +
							P.K_ROAD * detour(cx, cz) +
							P.K_Z * abs(cz)}
					end
				end
			end
		end
		local function by_score(l, r)
			if l.score ~= r.score then return l.score < r.score end
			local dl, dr = l.x * l.x + l.z * l.z, r.x * r.x + r.z * r.z
			if dl ~= dr then return dl < dr end
			if l.x ~= r.x then return l.x < r.x end
			return l.z < r.z
		end
		table.sort(coarse, by_score)

		-- The exact measure of one candidate: nil when refused.
		local function exact(cx, cz)
			for lz = -HZ - P.DRY, HZ + P.DRY, 2 do
				for lx = -HX - P.DRY, HX + P.DRY, 2 do
					local d = layout.hull_project(lx, lz)
					if d <= P.DRY then
						local x, z = cx + lx, cz + lz
						local zone = q.zone_at(x, z)
						if zone == nil or not allowed[zone] or q.wet(x, z) then return nil end
					end
				end
			end
			local hull = {}
			for lz = -HZ, HZ, 4 do
				for lx = -HX, HX, 4 do
					if layout.in_hull(lx, lz) then hull[#hull + 1] = q.natural_at(cx + lx, cz + lz) end
				end
			end
			local datum = lower_median(hull)
			local earth = 0
			for _, v in ipairs(hull) do earth = earth + abs(v - datum) end
			earth = earth / #hull
			local site = {x = cx, z = cz, y = datum}
			local profile = M.profile(site, q.natural_at)
			-- a step the widest blend cannot take at GRADE: refused below, but
			-- kept as a fallback (its blend up to WIDTH_FALLBACK) when it meets
			-- every other rule
			if q.blocked and q.blocked(cx, cz, max(HX, HZ) + ceil(profile.reach)) then return nil end
			-- no water within WET_MARGIN of the graded ground
			local r = ceil(profile.reach) + P.WET_MARGIN
			for lz = -HZ - r, HZ + r, 4 do
				for lx = -HX - r, HX + r, 4 do
					local d, s = layout.hull_project(lx, lz)
					if d > P.DRY then
						local t = s / PERIMETER * P.BINS - 0.5
						local i0 = floor(t)
						local f = t - i0
						local width = profile.width[i0 % P.BINS + 1] * (1 - f) +
							profile.width[(i0 + 1) % P.BINS + 1] * f
						if d < width + P.WET_MARGIN and q.wet(cx + lx, cz + lz) then return nil end
					end
				end
			end
			site.reach = ceil(profile.reach)
			local face = M.face(profile, q.natural_at)
			local score = earth + P.K_REACH * profile.reach +
				P.K_ROAD * detour(cx, cz) + P.K_Z * abs(cz) +
				P.K_FACE * max(0, face - P.FACE_FREE)
			if q.trace then q.trace(cx, cz, score, earth, profile.reach, detour(cx, cz), face) end
			site.face = face
			return site, score, earth, profile.capped and profile.need or nil
		end

		-- the coarse order, measured exactly until FINALISTS passed (at most
		-- EXACT_MAX tried); the lowest exact score wins
		local best, best_score, best_earth
		-- the fallback: of the capped candidates that meet every other rule,
		-- the one that needs the narrowest blend
		local spare, spare_need, spare_score, spare_earth
		local tried, passed = 0, 0
		for index = 1, #coarse do
			if passed >= P.FINALISTS or tried >= P.EXACT_MAX then break end
			local c = coarse[index]
			local site, score, earth, need = exact(c.x, c.z)
			tried = tried + 1
			if site and need then
				if not spare or need < spare_need or (need == spare_need and by_score(
						{score = score, x = site.x, z = site.z},
						{score = spare_score, x = spare.x, z = spare.z})) then
					spare, spare_need, spare_score, spare_earth = site, need, score, earth
				end
			elseif site then
				passed = passed + 1
				if not best or by_score({score = score, x = site.x, z = site.z},
						{score = best_score, x = best.x, z = best.z}) then
					best, best_score, best_earth = site, score, earth
				end
			end
		end
		local stats = {candidates = #coarse, finalists = tried}
		if not best and spare then
			-- no site whose ground the blend takes within WIDTH_MAX (very rough
			-- ground round the centre, one seed of the fleet's 304): the one
			-- that needs the narrowest blend, which may reach WIDTH_FALLBACK,
			-- so the grade rule holds there too unless it needs more still
			best, best_score, best_earth = spare, spare_score, spare_earth
			stats.fallback, stats.need, stats.cap = true, spare_need, P.WIDTH_FALLBACK
		end
		if not best then
			-- no dry site in the window (no seed of the studies): the coarse
			-- best, or the centre, levelled anyway
			local c = coarse[1] or {x = 0, z = 0}
			local hull = {}
			for lz = -HZ, HZ, 4 do
				for lx = -HX, HX, 4 do
					if layout.in_hull(lx, lz) then hull[#hull + 1] = q.natural_at(c.x + lx, c.z + lz) end
				end
			end
			best = {x = c.x, z = c.z, y = lower_median(hull)}
			best.reach = ceil(M.profile(best, q.natural_at).reach)
			stats.wet = true
		end
		stats.score, stats.earth, stats.face = best_score, best_earth, best.face
		-- the stand-in road's added cost through the site and through (0, 0)
		stats.detour, stats.centre_detour = detour(best.x, best.z), detour(0, 0)
		stats.seconds = os.clock() - started
		return best, stats
	end

	return M
end
