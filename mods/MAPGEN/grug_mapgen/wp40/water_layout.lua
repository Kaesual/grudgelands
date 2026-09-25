-- Round 22 Phase 5 inland water (world_zones.md §7.4; plan D38-D40).
--
-- Rivers and lakes laid out once from the drainage of the natural terrain
-- field on a coarse grid, then a pure per-column carve/water function:
--
--   local water_module = dofile("water_layout.lua")(terrain_data.water)
--   local layout = water_module.build(seed, opts)      -- main only, ~4 s
--   local text = water_module.serialize(layout)        -- the ipc_set payload
--   local water = water_module.sampler(water_module.deserialize(text), seed,
--       simplex)                                        -- main and emerge
--   water.column(x, z, h0) -> h, water_y or nil, kind or nil, id, bank_distance,
--       bank_y
--
-- Float arithmetic (plan D2). The sampler is a pure function of (layout, x, z,
-- h0), h0 being the natural float field at a land column; the layout is a pure
-- function of the seed, and both environments sample the SAME deserialized
-- text, so main and emerge agree exactly. Every tunable is data
-- (`terrain_data.lua` `water`); this file is the mechanism, ported from the
-- accepted Phase 5 prototype W1.
--
-- Seam rules (prototype B): distances fed into ramps are true polyline
-- distances (hard minimum over the segments of a finely sampled smooth
-- centreline); attributes (width, valley width, level reference) are blended
-- by smooth weights of the segment distances, never read off an arc
-- parameter; lake masks are cubic B-spline reads of a coarse indicator grid.
return function(P)
	assert(type(P) == "table", "water layout parameters missing")
	local M = {P = P}
	local floor, sqrt, abs, min, max, exp = math.floor, math.sqrt, math.abs,
		math.min, math.max, math.exp

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
	local function bspline(f)
		local f2 = f * f
		return (1 - f) ^ 3 / 6, (3 * f2 * f - 6 * f2 + 4) / 6,
			(-3 * f2 * f + 3 * f2 + 3 * f + 1) / 6, f2 * f / 6
	end

	-- Binary min-heap of (value, key).
	local function heap_new() return {v = {}, k = {}, n = 0} end
	local function heap_push(h, value, key)
		local n = h.n + 1
		h.n = n
		local V, K = h.v, h.k
		while n > 1 do
			local p = floor(n / 2)
			if V[p] <= value then break end
			V[n], K[n] = V[p], K[p]
			n = p
		end
		V[n], K[n] = value, key
	end
	local function heap_pop(h)
		local V, K = h.v, h.k
		local rv, rk = V[1], K[1]
		local n = h.n
		local lv, lk = V[n], K[n]
		V[n], K[n] = nil, nil
		n = n - 1
		h.n = n
		if n > 0 then
			local i = 1
			while true do
				local c = 2 * i
				if c > n then break end
				if c < n and V[c + 1] < V[c] then c = c + 1 end
				if V[c] >= lv then break end
				V[i], K[i] = V[c], K[c]
				i = c
			end
			V[i], K[i] = lv, lk
		end
		return rv, rk
	end

	-- A keep-out's radius at (x, z): the base radius grown by up to `edge`
	-- (share) with a smooth 2D noise, so its outline is irregular, never a
	-- circle (plan D40, like the D28 calm edge).
	local function keep_radius(e, noise, x, z)
		return e.r * (1 + (e.edge or 0) * (0.5 + 0.5 * noise(x / P.KEEP_EDGE_P,
			z / P.KEEP_EDGE_P)))
	end

	---------------------------------------------------------------------------
	-- Construction (main only).
	---------------------------------------------------------------------------
	local DX = {1, -1, 0, 0, 1, 1, -1, -1}
	local DZ = {0, 0, 1, -1, 1, -1, 1, -1}
	local DD = {1, 1, 1, 1, 1.4142, 1.4142, 1.4142, 1.4142}

	-- Grid sampling, priority flood, depressions and lakes. Returns the
	-- construction state `S` shared by the later steps.
	local function drainage(seed, opts)
		local field, land_at = opts.field, opts.land_at
		local C, GX0, GZ0 = P.C, P.GX0, P.GZ0
		local nx = floor((P.GX1 - GX0) / C) + 1
		local nz = floor((P.GZ1 - GZ0) / C) + 1
		local N = nx * nz
		local stats = {}
		local t0 = os.clock()

		-- 1) the natural field on the coarse grid (land only)
		local H, land = {}, {}
		for iz = 0, nz - 1 do
			local z = GZ0 + iz * C
			for ix = 0, nx - 1 do
				local x = GX0 + ix * C
				local k = iz * nx + ix
				local l = land_at(x, z) and true or false
				land[k] = l
				H[k] = l and field.height_at(x, z, true) or 0
			end
		end
		stats.t_grid = os.clock() - t0

		-- Keep-outs (starts, capital built areas) raise the routing surface so
		-- rivers and lakes route around them; the terrain itself is unchanged.
		local nwob = opts.simplex(seed, "river_keepout")
		local R, keep = {}, {}
		for k = 0, N - 1 do R[k] = H[k] end
		local RW, RS = P.KEEP_RAMP_W or 0, P.KEEP_RAMP or 0
		for ei, e in ipairs(opts.keepouts or {}) do
			local rr = e.r * (1 + (e.edge or 0)) + RW
			for iz = max(0, floor((e.z - rr - GZ0) / C)),
					min(nz - 1, floor((e.z + rr - GZ0) / C) + 1) do
				for ix = max(0, floor((e.x - rr - GX0) / C)),
						min(nx - 1, floor((e.x + rr - GX0) / C) + 1) do
					local x, z = GX0 + ix * C, GZ0 + iz * C
					local dx, dz = x - e.x, z - e.z
					local d = sqrt(dx * dx + dz * dz)
					local r = keep_radius(e, nwob, x, z)
					local k = iz * nx + ix
					if d <= r then
						keep[k] = ei
						if land[k] then R[k] = R[k] + P.KEEP_LIFT end
					elseif d < r + RW and land[k] then
						-- a gentle apron outside the keep-out: water turns away
						-- before it reaches the edge instead of hugging it
						R[k] = R[k] + RS * (r + RW - d)
					end
				end
			end
		end

		-- 2) priority flood with epsilon (Barnes et al. 2014) from the sea.
		-- `sinks` (optional) maps extra outlet cells to their water level: the
		-- second pass uses the terminal lakes as outlets.
		local EPS = P.EPS
		local function flood(sinks)
			local filled, closed, order = {}, {}, {}
			local no = 0
			local hp = heap_new()
			for iz = 0, nz - 1 do
				for ix = 0, nx - 1 do
					local k = iz * nx + ix
					if not land[k] then
						closed[k] = true
						filled[k] = 1
						for d = 1, 8 do
							local jx, jz = ix + DX[d], iz + DZ[d]
							if jx >= 0 and jx < nx and jz >= 0 and jz < nz and
									land[jz * nx + jx] then
								heap_push(hp, 1, k)
								break
							end
						end
					end
				end
			end
			-- sinks in index order, so the heap sees them deterministically
			local sink_keys = {}
			for k in pairs(sinks or {}) do sink_keys[#sink_keys + 1] = k end
			table.sort(sink_keys)
			for _, k in ipairs(sink_keys) do
				closed[k] = true
				filled[k] = sinks[k]
				heap_push(hp, sinks[k], k)
			end
			while hp.n > 0 do
				local v, k = heap_pop(hp)
				if land[k] and not (sinks and sinks[k]) then no = no + 1; order[no] = k end
				local ix, iz = k % nx, floor(k / nx)
				for d = 1, 8 do
					local jx, jz = ix + DX[d], iz + DZ[d]
					if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
						local j = jz * nx + jx
						if not closed[j] then
							closed[j] = true
							local f = R[j]
							if f < v + EPS then f = v + EPS end
							filled[j] = f
							heap_push(hp, f, j)
						end
					end
				end
			end
			-- receivers: steepest descent on the filled surface (sinks: -2)
			local recv = {}
			for k = 0, N - 1 do
				if land[k] then
					if sinks and sinks[k] then
						recv[k] = -2
					else
						local ix, iz = k % nx, floor(k / nx)
						local best, bs = nil, 0
						for d = 1, 8 do
							local jx, jz = ix + DX[d], iz + DZ[d]
							if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
								local j = jz * nx + jx
								local sl = (filled[k] - filled[j]) / DD[d]
								if sl > bs then best, bs = j, sl end
							end
						end
						recv[k] = best or -1
					end
				end
			end
			-- accumulation (cells), in descending filled order
			local acc = {}
			for k = 0, N - 1 do acc[k] = land[k] and 1 or 0 end
			for i = no, 1, -1 do
				local k = order[i]
				local r = recv[k]
				if r and r >= 0 and land[r] then acc[r] = acc[r] + acc[k] end
			end
			return filled, recv, acc
		end
		local filled, recv, acc = flood(nil)

		-- 3) depressions (the routing surface below the filled surface) ->
		-- lakes or a breach. The routing surface is the natural field except
		-- in the keep-outs and their aprons, whose lift is no depression.
		local comp, deps = {}, {}
		for k = 0, N - 1 do
			if land[k] and not comp[k] and filled[k] - R[k] > P.DEP_MIN and not keep[k] then
				local id = #deps + 1
				local cells, stack = {}, {k}
				comp[k] = id
				local maxd, spill, blocked = 0, math.huge, nil
				while #stack > 0 do
					local c = stack[#stack]; stack[#stack] = nil
					cells[#cells + 1] = c
					local dd = filled[c] - R[c]
					if dd > maxd then maxd = dd end
					if filled[c] < spill then spill = filled[c] end
					local cx, cz = c % nx, floor(c / nx)
					for d = 1, 8 do
						local jx, jz = cx + DX[d], cz + DZ[d]
						if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
							local j = jz * nx + jx
							if land[j] and not comp[j] and filled[j] - R[j] > P.DEP_MIN then
								if keep[j] then blocked = blocked or {}; blocked[keep[j]] = true
								else comp[j] = id; stack[#stack + 1] = j end
							end
						end
					end
				end
				table.sort(cells)
				deps[id] = {cells = cells, depth = maxd, spill = spill, blocked = blocked}
			end
		end
		local lakes, lake_of = {}, {}
		local nbreach = 0
		for id, dp in ipairs(deps) do
			-- Hybrid breach/fill: a river may cut up to BREACH_MAX nodes through
			-- the rim; the rest of a deeper depression holds a lake at that
			-- lowered level. Wetland zones and water landmarks keep their
			-- shallow depressions as ponds at the spill level.
			local lim, minc = P.BREACH_MAX, P.LAKE_MIN_CELLS
			if opts.breach_at then
				local lo, lc = math.huge, nil
				for _, c in ipairs(dp.cells) do if H[c] < lo then lo, lc = H[c], c end end
				local b, mc = opts.breach_at(GX0 + (lc % nx) * C, GZ0 + floor(lc / nx) * C)
				if b and dp.depth <= P.MARSH_MAX_DEPTH then lim, minc = b, mc or minc end
			end
			-- The spill comes from the routing surface; where a keep-out apron
			-- is the barrier it stands above the natural rim. The natural rim
			-- (the lowest natural cell around the depression) caps the level,
			-- so no lake is perched on bank walls above its own ground.
			local rim = math.huge
			for _, c in ipairs(dp.cells) do
				local cx, cz = c % nx, floor(c / nx)
				for d = 1, 8 do
					local jx, jz = cx + DX[d], cz + DZ[d]
					if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
						local j = jz * nx + jx
						if comp[j] ~= id and H[j] < rim then rim = land[j] and H[j] or 1 end
					end
				end
			end
			local level = floor(min(dp.spill, rim) - lim + 1e-6)
			local function count(lv)
				local n = 0
				for _, c in ipairs(dp.cells) do if H[c] < lv then n = n + 1 end end
				return n
			end
			-- POI cores stay dry: the level drops below the lowest core ground
			for _, p in ipairs(opts.pois or {}) do
				local pix, piz = floor((p.x - GX0) / C + 0.5), floor((p.z - GZ0) / C + 0.5)
				local inside = false
				for dz = -3, 3 do
					for dx = -3, 3 do
						if comp[(piz + dz) * nx + pix + dx] == id then inside = true end
					end
				end
				if inside and p.ground and p.ground - 1 < level then level = floor(p.ground - 1) end
			end
			-- a basin touching a keep-out stays below that keep-out's lowest ground
			local blocked_ids = {}
			for ei in pairs(dp.blocked or {}) do blocked_ids[#blocked_ids + 1] = ei end
			table.sort(blocked_ids)
			for _, ei in ipairs(blocked_ids) do
				local g = opts.keepouts[ei].ground
				if g and g - 1 < level then level = floor(g - 1) end
			end
			-- very large basins: the level drops until the lake fits
			local wet = count(level)
			while wet > P.LAKE_MAX_CELLS do level = level - 1; wet = count(level) end
			if dp.depth > lim and wet >= minc and level >= 2 then
				local L = {id = #lakes + 1, level = level, cells = {},
					-- lowered below spill - BREACH_MAX (POI rule, size cap): no outlet
					terminal = dp.spill - level > lim + 1}
				for _, c in ipairs(dp.cells) do
					if H[c] < level then
						L.cells[#L.cells + 1] = c
						lake_of[c] = L.id
					end
				end
				lakes[#lakes + 1] = L
			else
				nbreach = nbreach + 1
			end
		end
		-- Terminal lakes have no outlet: a second flood uses them as outlets
		-- next to the sea, so their basin drains into them.
		local sinks, nterm = {}, 0
		for _, L in ipairs(lakes) do
			if L.terminal then
				nterm = nterm + 1
				for _, c in ipairs(L.cells) do sinks[c] = L.level end
			end
		end
		stats.depressions, stats.breached, stats.terminal_lakes = #deps, nbreach, nterm
		if nterm > 0 then
			local f2
			f2, recv, acc = flood(sinks)
			for k, v in pairs(f2) do filled[k] = v end
		end
		-- lake mask: lake cells plus one ring of cells at or above the level
		local mask = {}
		for _, L in ipairs(lakes) do
			for _, c in ipairs(L.cells) do mask[c] = L.id end
		end
		for _, L in ipairs(lakes) do
			local ring = {}
			for _, c in ipairs(L.cells) do
				local cx, cz = c % nx, floor(c / nx)
				for d = 1, 8 do
					local jx, jz = cx + DX[d], cz + DZ[d]
					if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
						local j = jz * nx + jx
						if land[j] and mask[j] == nil and H[j] >= L.level then ring[j] = true end
					end
				end
			end
			local ring_cells = {}
			for j in pairs(ring) do ring_cells[#ring_cells + 1] = j end
			table.sort(ring_cells)
			for _, j in ipairs(ring_cells) do mask[j] = L.id end
		end
		stats.t_drainage = os.clock() - t0
		return {nx = nx, nz = nz, N = N, H = H, land = land, keep = keep,
			recv = recv, acc = acc, lakes = lakes, lake_of = lake_of, mask = mask,
			stats = stats, t0 = t0}
	end

	-- 4) Rivers: main-stem decomposition of the receiver tree.
	local function river_tree(S, opts)
		local nx, nz, N = S.nx, S.nz, S.N
		local land, keep, recv, acc, lake_of = S.land, S.keep, S.recv, S.acc, S.lake_of
		for _, hnt in ipairs(opts.sources or {}) do
			local k = floor((hnt.x - P.GX0) / P.C + 0.5) + floor((hnt.z - P.GZ0) / P.C + 0.5) * nx
			local guard = 0
			while k and k >= 0 and land[k] and guard < 4000 do
				acc[k] = acc[k] + hnt.acc
				k = recv[k]
				guard = guard + 1
			end
		end
		local isriv = {}
		for k = 0, N - 1 do
			if land[k] and acc[k] >= P.RIVER_ACC and not lake_of[k] and not keep[k] then
				isriv[k] = true
			end
		end
		local donors, outlets = {}, {}
		for k = 0, N - 1 do
			if isriv[k] then
				local r = recv[k]
				if r >= 0 and isriv[r] then
					local list = donors[r]
					if not list then list = {}; donors[r] = list end
					list[#list + 1] = k
				else
					outlets[#outlets + 1] = k
				end
			end
		end
		table.sort(outlets, function(a, b)
			if acc[a] ~= acc[b] then return acc[a] > acc[b] end
			return a < b
		end)
		local rivers, queue = {}, {}
		for _, k in ipairs(outlets) do
			local r = recv[k]
			local e = {start = k}
			if r < 0 or not land[r] then e.end_kind, e.end_cell = "sea", r
			elseif lake_of[r] then e.end_kind, e.end_cell, e.end_lake = "lake", r, lake_of[r]
			elseif keep[r] then e.end_kind = "keepout"
			else e.end_kind = "land" end
			queue[#queue + 1] = e
		end
		local qi = 1
		while qi <= #queue do
			local e = queue[qi]; qi = qi + 1
			local path, tribs = {}, {}
			local cur = e.start
			while cur do
				path[#path + 1] = cur
				local list = donors[cur]
				local best, ba = nil, -1
				if list then
					for _, dnr in ipairs(list) do
						if acc[dnr] > ba or (acc[dnr] == ba and dnr < best) then
							best, ba = dnr, acc[dnr]
						end
					end
					for _, dnr in ipairs(list) do
						if dnr ~= best then tribs[#tribs + 1] = {start = dnr, junction = cur} end
					end
				end
				cur = best
			end
			-- the path runs mouth -> source; reverse it
			local cells = {}
			for i = #path, 1, -1 do cells[#cells + 1] = path[i] end
			if e.parent == nil or #cells >= P.MIN_TRIB_CELLS then
				local rv = {id = #rivers + 1, cells = cells, parent = e.parent,
					junction = e.junction, end_kind = e.end_kind or "river",
					end_cell = e.end_cell, end_lake = e.end_lake}
				-- a source in a lake: the largest donor of the first cell is a lake cell
				local src = cells[1]
				local sx, sz = src % nx, floor(src / nx)
				local bl, ba = nil, 0
				for d = 1, 8 do
					local jx, jz = sx + DX[d], sz + DZ[d]
					if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
						local j = jz * nx + jx
						if recv[j] == src and lake_of[j] and acc[j] > ba then bl, ba = j, acc[j] end
					end
				end
				if bl then rv.src_lake, rv.src_cell = lake_of[bl], bl end
				rivers[#rivers + 1] = rv
				for _, t in ipairs(tribs) do
					queue[#queue + 1] = {start = t.start, parent = rv.id, junction = t.junction}
				end
			end
		end
		-- lakes that drain sideways into a river (the outflow joins mid-course)
		local river_of_cell = {}
		for _, rv in ipairs(rivers) do for _, c in ipairs(rv.cells) do river_of_cell[c] = rv.id end end
		for _, L in ipairs(S.lakes) do
			for _, c in ipairs(L.cells) do
				local r = recv[c]
				local rid = r and r >= 0 and river_of_cell[r]
				if rid then
					local rv = rivers[rid]
					rv.drains = rv.drains or {}
					rv.drains[L.id] = true
				end
			end
		end
		S.rivers = rivers
	end

	-- 5) Centreline geometry: smoothing, width, meander, keep-out detours.
	local function geometry(S, seed, opts)
		local nx = S.nx
		local C, GX0, GZ0 = P.C, P.GX0, P.GZ0
		local acc = S.acc
		local nmeander = opts.simplex(seed, "river_meander")
		local nwidth = opts.simplex(seed, "river_width")
		local nwob = opts.simplex(seed, "river_keepout")
		local function cxz(k) return GX0 + (k % nx) * C, GZ0 + floor(k / nx) * C end
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
				local a, b = pts[i], pts[i + 1]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local len = sqrt(vx * vx + vz * vz)
				local t = step - carry
				while t <= len do
					out[#out + 1] = {a[1] + vx * t / len, a[2] + vz * t / len}
					t = t + step
				end
				carry = len - (t - step)
			end
			local last, lp = pts[#pts], out[#out]
			if (lp[1] - last[1]) ^ 2 + (lp[2] - last[2]) ^ 2 > (step * 0.3) ^ 2 then
				out[#out + 1] = {last[1], last[2]}
			else
				out[#out] = {last[1], last[2]}
			end
			return out
		end
		local function nearest_on(pts, x, z)
			local bd, bx, bz, bi = math.huge, x, z, 1
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local l2 = vx * vx + vz * vz
				local t = l2 > 0 and ((x - a[1]) * vx + (z - a[2]) * vz) / l2 or 0
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local px, pz = a[1] + t * vx, a[2] + t * vz
				local d = (px - x) ^ 2 + (pz - z) ^ 2
				if d < bd then bd, bx, bz, bi = d, px, pz, i end
			end
			return bx, bz, bi
		end
		-- Keep-out discs: routing already goes around them (lifted routing
		-- surface), so only meander excursions enter; they are pushed radially
		-- onto the keep-out's irregular outline. POI cores: a one-sided detour.
		local function detour(out, widths)
			local n = #out
			for _, e in ipairs(opts.keepouts or {}) do
				for i = 1, n do
					local x, z = out[i][1], out[i][2]
					local r = keep_radius(e, nwob, x, z) + widths[i] / 2 + P.POI_PAD
					local dx, dz = x - e.x, z - e.z
					local d2 = dx * dx + dz * dz
					if d2 < r * r then
						local d = sqrt(d2)
						if d < 1e-3 then dx, dz, d = 1, 0, 1 end
						out[i] = {e.x + dx / d * r, e.z + dz / d * r}
					end
				end
			end
			for _, p in ipairs(opts.pois or {}) do
				local best, bi = math.huge, nil
				for i = 1, n do
					local d2 = (out[i][1] - p.x) ^ 2 + (out[i][2] - p.z) ^ 2
					if d2 < best then best, bi = d2, i end
				end
				local rmax = p.r + P.W_MAX + P.POI_PAD + P.MEANDER_MAX
				if bi and best < rmax * rmax then
					local ia, ib = max(1, bi - 3), min(n, bi + 3)
					local tx, tz = out[ib][1] - out[ia][1], out[ib][2] - out[ia][2]
					local tl = sqrt(tx * tx + tz * tz)
					if tl < 1e-6 then tx, tz, tl = 1, 0, 1 end
					tx, tz = tx / tl, tz / tl
					local side = (tx * (out[bi][2] - p.z) - tz * (out[bi][1] - p.x)) >= 0 and 1 or -1
					for i = 1, n do
						local x, z = out[i][1], out[i][2]
						local r = p.r + widths[i] / 2 + P.POI_PAD
						local dx, dz = x - p.x, z - p.z
						local a = dx * tx + dz * tz
						local l0 = -dx * tz + dz * tx
						if a * a < r * r then
							local lim = r * sqrt(1 - (a / r) ^ 2)
							if abs(l0) < lim then
								local l = side * lim
								out[i] = {p.x + a * tx - l * tz, p.z + a * tz + l * tx}
							end
						end
					end
				end
			end
		end

		local coast = opts.field.coast_signed
		for _, rv in ipairs(S.rivers) do
			local cells = rv.cells
			local pts = {}
			if rv.src_cell then local x, z = cxz(rv.src_cell); pts[1] = {x, z} end
			for _, c in ipairs(cells) do local x, z = cxz(c); pts[#pts + 1] = {x, z} end
			if rv.parent then
				local x, z = cxz(rv.junction); pts[#pts + 1] = {x, z}
			elseif (rv.end_kind == "sea" or rv.end_kind == "lake") and
					rv.end_cell and rv.end_cell >= 0 then
				local x, z = cxz(rv.end_cell); pts[#pts + 1] = {x, z}
			end
			-- a sea mouth extends ~48 nodes further out along the last direction
			if rv.end_kind == "sea" and #pts >= 2 then
				local a, b = pts[#pts - 1], pts[#pts]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local l = sqrt(vx * vx + vz * vz)
				pts[#pts + 1] = {b[1] + vx / l * 48, b[2] + vz / l * 48}
			end
			pts = chaikin(pts, 3)
			pts = resample(pts, P.SEG)
			-- a wide moving average removes the grid staircase; the ends stay
			for _ = 1, P.PATH_SMOOTH do
				local o = {pts[1]}
				local np = #pts
				for i = 2, np - 1 do
					local r = min(4, i - 1, np - i)
					local sx, sz = 0, 0
					for q = i - r, i + r do sx, sz = sx + pts[q][1], sz + pts[q][2] end
					o[i] = {sx / (2 * r + 1), sz / (2 * r + 1)}
				end
				o[np] = pts[np]
				pts = o
			end
			-- per-vertex catchment: the nearest cell along the path, searched forward
			local n = #pts
			local accs = {}
			local ci = 1
			for i = 1, n do
				local x, z = pts[i][1], pts[i][2]
				local bd, bj = math.huge, ci
				for j = max(1, ci - 2), min(#cells, ci + 6) do
					local cx, cz = cxz(cells[j])
					local d = (cx - x) ^ 2 + (cz - z) ^ 2
					if d < bd then bd, bj = d, j end
				end
				ci = bj
				accs[i] = acc[cells[bj]]
			end
			local s = {0}
			for i = 2, n do
				s[i] = s[i - 1] + sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 +
					(pts[i][2] - pts[i - 1][2]) ^ 2)
			end
			local total = s[n]
			local widths = {}
			for i = 1, n do
				local x, z = pts[i][1], pts[i][2]
				local w = P.W_A * sqrt(accs[i] * C * C)
				w = w * (1 + P.W_NOISE * nwidth(x / 300, z / 300))
				widths[i] = min(P.W_MAX, max(P.W_MIN, w))
			end
			-- a river that does not leave a lake starts small (a spring)
			if not rv.src_lake then
				for i = 1, n do
					widths[i] = max(P.W_SRC, widths[i] * (P.SRC_KEEP + (1 - P.SRC_KEEP) *
						smoothstep(0, P.SRC_TAPER, s[i])))
				end
			end
			for _ = 1, 4 do
				local o = {}
				for i = 1, n do
					o[i] = (widths[max(1, i - 1)] + 2 * widths[i] + widths[min(n, i + 1)]) / 4
				end
				widths = o
			end
			-- meander: a displacement normal to the path from 2D noise, never
			-- from arc length
			local out = {}
			for i = 1, n do
				local x, z = pts[i][1], pts[i][2]
				local w = widths[i]
				local ia, ib = max(1, i - 2), min(n, i + 2)
				local tx, tz = pts[ib][1] - pts[ia][1], pts[ib][2] - pts[ia][2]
				local tl = sqrt(tx * tx + tz * tz)
				if tl < 1e-6 then tx, tz, tl = 1, 0, 1 end
				local nxv, nzv = -tz / tl, tx / tl
				local lambda = 60 + P.MEANDER_P * 22 * sqrt(w)
				local amp = min(P.MEANDER_MAX, P.MEANDER_A * (6 + 2 * w))
				local taper = smoothstep(0, 80, s[i]) * smoothstep(0, 80, total - s[i])
				if rv.end_kind == "sea" then taper = taper * smoothstep(-10, 60, coast(x, z)) end
				local m = nmeander(x / lambda, z / lambda) +
					0.35 * nmeander(x / lambda * 2.3 + 41.7, z / lambda * 2.3 - 8.1)
				local off = amp * taper * m
				out[i] = {x + nxv * off, z + nzv * off}
			end
			for _ = 1, 2 do
				local o = {out[1]}
				for i = 2, n - 1 do
					o[i] = {(out[i - 1][1] + 2 * out[i][1] + out[i + 1][1]) / 4,
						(out[i - 1][2] + 2 * out[i][2] + out[i + 1][2]) / 4}
				end
				o[n] = out[n]
				out = o
			end
			-- twice: a detour around one core can push the path into a neighbour's
			detour(out, widths)
			detour(out, widths)
			-- a tributary's junction end snaps onto the parent's final centreline
			if rv.parent then
				local par = S.rivers[rv.parent]
				local jx, jz, ji = nearest_on(par.pts, out[n][1], out[n][2])
				out[n] = {jx, jz}
				rv.junction_index = ji
			end
			if rv.end_kind == "sea" then
				for i = 1, n do
					local sd = coast(out[i][1], out[i][2])
					widths[i] = widths[i] * (1 + P.MOUTH_FLARE * (1 - smoothstep(-10, 120, sd)))
				end
			end
			rv.pts, rv.w, rv.acc = out, widths, accs
			-- the geometry's widths; `levels` narrows its own copy at sinks
			rv.w_geom = widths
		end
	end

	-- 6) Levels: band minimum of the terrain, cumulative minimum downstream,
	-- incision, reaches of constant surface, steps shaped by the slope.
	local function levels(S, opts)
		local field, land_at = opts.field, opts.land_at
		local lakes, stats = S.lakes, S.stats
		stats.sinks, stats.max_cut = 0, 0
		local function fh(x, z)
			if not land_at(x, z) then return 1 end
			return field.height_at(x, z, true)
		end
		local function tangent(pts, i)
			local n = #pts
			local ia, ib = max(1, i - 1), min(n, i + 1)
			local tx, tz = pts[ib][1] - pts[ia][1], pts[ib][2] - pts[ia][2]
			local tl = sqrt(tx * tx + tz * tz)
			if tl < 1e-6 then return 1, 0 end
			return tx / tl, tz / tl
		end
		local ACROSS = {-1, -0.5, 0, 0.5, 1}
		local function band_min(rv, i)
			local x, z = rv.pts[i][1], rv.pts[i][2]
			local tx, tz = tangent(rv.pts, i)
			local r = rv.w[i] / 2 + P.BAND
			local m = math.huge
			for _, f in ipairs(ACROSS) do
				local h = fh(x - tz * r * f, z + tx * r * f)
				if h < m then m = h end
			end
			return m
		end
		-- A spring's end cap: the terrain just upstream of the first vertex
		-- counts too, so the first reach never stands above the ground around
		-- the channel's rounded end (no raised bank ring around a source).
		local function spring_min(rv, i)
			local x, z = rv.pts[i][1], rv.pts[i][2]
			local tx, tz = tangent(rv.pts, i)
			local r = rv.w[i] / 2 + P.WET_B + 2
			local m = math.huge
			for _, f in ipairs(ACROSS) do
				local h = fh(x - tx * r - tz * r * f, z - tz * r + tx * r * f)
				if h < m then m = h end
			end
			return m
		end
		-- Slope of the cumulative-minimum profile around vertex i (nodes of
		-- drop per node), over +-SLOPE_K vertices.
		local function profile_slope(p, n, i)
			local a, b = max(1, i - P.SLOPE_K), min(n, i + P.SLOPE_K)
			if b <= a then return 0 end
			local g = (p[a] - p[b]) / ((b - a) * P.SEG)
			return g > 0 and g or 0
		end
		-- D39: the tallest merged step allowed at a slope: rapids of up to
		-- STEP_GENTLE nodes on gentle ground, falls up to FALL_MAX only where
		-- the terrain is steep.
		local function fall_limit(g)
			return floor(P.STEP_GENTLE + (P.FALL_MAX - P.STEP_GENTLE) *
				smoothstep(P.SLOPE_GENTLE, P.SLOPE_STEEP, g) + 0.5)
		end
		for _, rv in ipairs(S.rivers) do
			local n = #rv.pts
			local w = {}
			for q = 1, n do w[q] = rv.w_geom[q] end
			rv.w = w
			local m = {}
			for i = 1, n do m[i] = band_min(rv, i) end
			-- The downstream end fixes the last level: the sea, a lake, the
			-- parent river. A river that ends dry (in a sink, a drained lake,
			-- a keep-out) keeps its own profile to the end.
			local end_level
			if rv.end_kind == "sea" then end_level = 1 end
			local par = rv.parent and S.rivers[rv.parent]
			if par then
				-- A parent that is dry at the junction (inside its sink gap)
				-- has no surface to meet: the tributary keeps its own profile.
				local ji = rv.junction_index
				local jb = min(#par.levels, ji + 1)
				if not (par.dry[ji] or par.dry[jb]) and par.w[ji] > 0 and par.w[jb] > 0 then
					end_level = par.levels[jb]
				end
			elseif rv.end_kind == "lake" then
				end_level = lakes[rv.end_lake].level
			end
			local sea_floor = rv.end_kind == "sea" and not rv.parent and 1 or nil
			local start_cap = math.huge
			if rv.src_lake then start_cap = lakes[rv.src_lake].level end
			-- A river may not climb: where the band terrain stands more than
			-- CUT_MAX above the current level, the river sinks, a dry gap
			-- follows, and a new stretch springs up with its own profile.
			local p, dry, lv = {}, {}, {}
			local function inc(i) return P.INC_A + P.INC_B * rv.w[i] end
			local run = start_cap + inc(1)
			local L = nil
			local i = 1
			rv.sinks = {}
			while i <= n do
				if L == nil and not (i == 1 and rv.src_lake) then
					local sm = spring_min(rv, i)
					if sm < run then run = sm end
				end
				if m[i] < run then run = m[i] end
				p[i] = run
				local tt = run - inc(i)
				-- The sea is a floor for the whole river. A lake or parent
				-- river is not: raising a river that runs below its end would
				-- perch it on bank walls above its own valley (a terminal lake
				-- can lie above a neighbouring basin); it keeps its own profile
				-- and the higher end falls into it instead.
				if sea_floor and tt < sea_floor then tt = sea_floor end
				if L == nil then
					L = floor(tt)
					if i == 1 and rv.src_lake then L = lakes[rv.src_lake].level end
				end
				if tt <= L - 1 then L = floor(tt) + 1 end
				if sea_floor and (tt <= sea_floor or L < sea_floor) then L = sea_floor end
				if m[i] - L > P.CUT_MAX and i > 1 and i + P.SINK_GAP < n then
					rv.sinks[#rv.sinks + 1] = i
					local j = i
					local back = L + P.INC_A + P.INC_B * rv.w[i] + P.SINK_BACK
					while j < n - 1 and (j < i + P.SINK_GAP or m[j] > back) and
							j < i + P.SINK_MAX do
						j = j + 1
					end
					for q = i, j - 1 do dry[q], lv[q], p[q] = true, L, run end
					i = j
					run, L = math.huge, nil
				else
					lv[i] = L
					i = i + 1
				end
			end
			stats.sinks = stats.sinks + #rv.sinks
			if end_level and not par and end_level <= lv[max(1, n - 1)] then
				lv[n] = end_level
			end
			-- A tributary's tail that already runs inside the parent's channel
			-- (the junction snap can overlap it for a few vertices) takes the
			-- parent's surface, so the two channels never hold different
			-- surfaces side by side. The parent's banks contain that surface,
			-- so this never perches the tributary.
			if par and end_level then
				lv[n] = end_level
				local ji = rv.junction_index
				for q = n - 1, 2, -1 do
					local x, z = rv.pts[q][1], rv.pts[q][2]
					local inside = false
					for k = max(1, ji - 12), min(#par.pts - 1, ji + 12) do
						local a, b = par.pts[k], par.pts[k + 1]
						local vx, vz = b[1] - a[1], b[2] - a[2]
						local l2 = vx * vx + vz * vz
						local t = l2 > 0 and ((x - a[1]) * vx + (z - a[2]) * vz) / l2 or 0
						if t < 0 then t = 0 elseif t > 1 then t = 1 end
						local ex, ez = x - a[1] - t * vx, z - a[2] - t * vz
						local reach = max(par.w[k], par.w[k + 1]) / 2 + P.WET_B + 2
						if par.w[k] > 0 and ex * ex + ez * ez <= reach * reach then
							inside = true
							break
						end
					end
					if not inside then break end
					lv[q] = end_level
				end
			end
			-- Steps closer than FALL_GAP vertices merge into one step at the
			-- run's first step (the lower reach reaches back and cuts a notch),
			-- as long as the merged drop stays within the slope's limit.
			i = 2
			while i <= n do
				if lv[i] < lv[i - 1] then
					local top = lv[i - 1]
					local limit = fall_limit(profile_slope(p, n, i))
					local j, last = i, i
					while j <= n do
						if lv[j] < lv[j - 1] then
							if top - lv[j] > limit then break end
							last = j
						elseif j - last > P.FALL_GAP then break end
						j = j + 1
					end
					local low = lv[last]
					for q = i, last do lv[q] = low end
					i = last + 1
				else
					i = i + 1
				end
			end
			-- A single step taller than FALL_MAX (a hanging tributary mouth, a
			-- sea cliff) lowers the reach above it by the excess, which moves
			-- the excess to the next step upstream, until every step fits.
			local changed = true
			while changed do
				changed = false
				for q = n, 2, -1 do
					local drop = lv[q - 1] - lv[q]
					if drop > P.FALL_MAX then
						local excess, top, j = drop - P.FALL_MAX, lv[q - 1], q - 1
						while j >= 1 and lv[j] == top do
							lv[j] = lv[j] - excess
							j = j - 1
						end
						changed = true
					end
				end
			end
			rv.levels = lv
			-- taper the widths into a sink and out of the spring after it
			for _, si in ipairs(rv.sinks) do
				local e, sp = si - 1, si + P.SINK_GAP
				for q = 1, n do
					local dd
					if q <= e then dd = (e - q) * P.SEG elseif q >= sp then dd = (q - sp) * P.SEG end
					if dd and dd < P.SRC_TAPER then
						local f = P.SRC_KEEP + (1 - P.SRC_KEEP) * smoothstep(0, P.SRC_TAPER, dd)
						rv.w[q] = max(P.W_SRC, min(rv.w[q], rv.w[q] * f))
					end
				end
			end
			for q in pairs(dry) do rv.w[q] = 0 end
			rv.dry = dry
			for q = 1, n do
				local c = dry[q] and 0 or m[q] - lv[q]
				if c > (stats.max_cut or 0) then stats.max_cut = c end
			end
		end
	end

	-- A lake whose rim a passing river cuts below its surface drains: it is
	-- dropped (rivers that ended in it end dry there).
	local function drain_crossed_lakes(S)
		local lake_ind = M.lake_indicator(S.mask, S.nx, S.nz)
		local drained, drained_ids = {}, {}
		for _, rv in ipairs(S.rivers) do
			local n = #rv.pts
			for i = 1, n do
				if not rv.dry[i] then
					local ia, ib = max(1, i - 1), min(n, i + 1)
					local tx, tz = rv.pts[ib][1] - rv.pts[ia][1], rv.pts[ib][2] - rv.pts[ia][2]
					local tl = sqrt(tx * tx + tz * tz)
					if tl < 1e-6 then tx, tz, tl = 1, 0, 1 end
					for f = -1, 1 do
						local r = f * (rv.w[i] / 2 + P.WET_B + 1)
						local lid, m = lake_ind(rv.pts[i][1] - tz / tl * r, rv.pts[i][2] + tx / tl * r)
						-- a centreline inside the lake drains it even when the
						-- lake also spills into this river sideways
						local related = rv.src_lake == lid or rv.end_lake == lid or
							(f ~= 0 and rv.drains and rv.drains[lid])
						if lid and m >= (f == 0 and 0.5 or 0.3) and
								rv.levels[i] < S.lakes[lid].level and not related and
								not drained[lid] then
							drained[lid] = true
							drained_ids[#drained_ids + 1] = lid
						end
					end
				end
			end
		end
		for k, v in pairs(S.mask) do if drained[v] then S.mask[k] = nil end end
		for _, lid in ipairs(drained_ids) do
			S.lakes[lid].drained = true
			for _, c in ipairs(S.lakes[lid].cells) do S.lake_of[c] = nil end
		end
		for _, rv in ipairs(S.rivers) do
			if rv.end_lake and drained[rv.end_lake] then rv.end_kind, rv.end_lake = "sink", nil end
			if rv.src_lake and drained[rv.src_lake] then rv.src_lake = nil end
		end
		S.stats.lakes_drained = #drained_ids
	end

	-- opts: field (height_at(x, z, true), coast_signed), land_at(x, z),
	-- simplex, keepouts {x, z, r, edge, ground}, pois {x, z, r, ground},
	-- breach_at(x, z) -> limit, min cells (optional), sources (optional).
	-- Returns the layout plus `grid` (the coarse natural field, main only).
	function M.build(seed, opts)
		local S = drainage(seed, opts)
		river_tree(S, opts)
		geometry(S, seed, opts)
		levels(S, opts)
		drain_crossed_lakes(S)
		-- a river that ended in (or left) a drained lake must not keep that
		-- lake's level: the levels are computed again without it
		if S.stats.lakes_drained > 0 then levels(S, opts) end
		local stats = S.stats
		local nsteps, maxstep, hist = 0, 0, {}
		for _, rv in ipairs(S.rivers) do
			for i = 2, #rv.levels do
				local d = rv.levels[i - 1] - rv.levels[i]
				if d > 0 and not rv.dry[i] then
					nsteps = nsteps + 1
					hist[d] = (hist[d] or 0) + 1
					if d > maxstep then maxstep = d end
				end
			end
		end
		stats.steps, stats.maxstep, stats.step_hist = nsteps, maxstep, hist
		stats.t_total = os.clock() - S.t0
		local layout = {nx = S.nx, nz = S.nz, lakes = {}, rivers = {}, mask = S.mask,
			stats = stats}
		for _, L in ipairs(S.lakes) do
			layout.lakes[L.id] = {level = L.level, drained = L.drained}
		end
		for _, rv in ipairs(S.rivers) do
			local r = {id = rv.id, parent = rv.parent, end_kind = rv.end_kind,
				src_lake = rv.src_lake, end_lake = rv.end_lake, drains = rv.drains,
				x = {}, z = {}, w = {}, level = {}}
			for i, p in ipairs(rv.pts) do
				r.x[i], r.z[i], r.w[i], r.level[i] = p[1], p[2], rv.w[i], rv.levels[i]
			end
			layout.rivers[rv.id] = r
		end
		layout.grid = {nx = S.nx, nz = S.nz, cell = P.C, x0 = P.GX0, z0 = P.GZ0,
			height = S.H, land = S.land}
		return layout
	end

	---------------------------------------------------------------------------
	-- Serialization: the ipc_set payload (plain text, deterministic).
	--   W1 <nx> <nz> <lakes> <rivers>
	--   L <level> <ncells> <delta-encoded mask cell indices>   (per lake)
	--   R <id> <parent or 0> <end kind> <nvertices> <src lake or 0> <end lake or 0> <drains or ->
	--   <x> <z> <width> <level>                                (per vertex)
	---------------------------------------------------------------------------
	function M.serialize(layout)
		local out = {}
		out[#out + 1] = ("W1 %d %d %d %d\n"):format(layout.nx, layout.nz,
			#layout.lakes, #layout.rivers)
		local cells_of = {}
		for k, lid in pairs(layout.mask) do
			local list = cells_of[lid]
			if not list then list = {}; cells_of[lid] = list end
			list[#list + 1] = k
		end
		for id, L in ipairs(layout.lakes) do
			local cells = cells_of[id] or {}
			table.sort(cells)
			out[#out + 1] = ("L %d %d"):format(L.level, #cells)
			local prev = 0
			for _, k in ipairs(cells) do out[#out + 1] = " " .. (k - prev); prev = k end
			out[#out + 1] = "\n"
		end
		for _, r in ipairs(layout.rivers) do
			local dl = {}
			for lid in pairs(r.drains or {}) do dl[#dl + 1] = lid end
			table.sort(dl)
			out[#out + 1] = ("R %d %d %s %d %d %d %s\n"):format(r.id, r.parent or 0,
				r.end_kind, #r.x, r.src_lake or 0, r.end_lake or 0,
				#dl > 0 and table.concat(dl, ",") or "-")
			for i = 1, #r.x do
				out[#out + 1] = ("%.1f %.1f %.1f %d\n"):format(r.x[i], r.z[i], r.w[i],
					r.level[i])
			end
		end
		return table.concat(out)
	end

	function M.deserialize(text)
		if type(text) ~= "string" then error("water layout text differs", 0) end
		local lines = {}
		for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
		local nx, nz, nl, nr = (lines[1] or ""):match("^W1 (%d+) (%d+) (%d+) (%d+)$")
		if not nx then error("water layout header differs", 0) end
		local layout = {nx = tonumber(nx), nz = tonumber(nz), lakes = {}, rivers = {},
			mask = {}}
		local li = 2
		for id = 1, tonumber(nl) do
			local level, count, rest = (lines[li] or ""):match("^L (%-?%d+) (%d+)(.*)$")
			if not level then error("water layout lake row differs", 0) end
			li = li + 1
			local k, seen = 0, 0
			for v in rest:gmatch("%d+") do
				k = k + tonumber(v)
				layout.mask[k] = id
				seen = seen + 1
			end
			if seen ~= tonumber(count) then error("water layout lake cells differ", 0) end
			layout.lakes[id] = {level = tonumber(level)}
		end
		for _ = 1, tonumber(nr) do
			local id, parent, kind, n, sl, el, dl = (lines[li] or ""):match(
				"^R (%d+) (%d+) (%S+) (%d+) (%d+) (%d+) (%S+)$")
			if not id then error("water layout river row differs", 0) end
			li = li + 1
			local r = {id = tonumber(id), end_kind = kind, x = {}, z = {}, w = {},
				level = {}, drains = {}}
			if tonumber(parent) ~= 0 then r.parent = tonumber(parent) end
			if tonumber(sl) ~= 0 then r.src_lake = tonumber(sl) end
			if tonumber(el) ~= 0 then r.end_lake = tonumber(el) end
			for v in dl:gmatch("%d+") do r.drains[tonumber(v)] = true end
			for i = 1, tonumber(n) do
				local a, b, c, d = (lines[li] or ""):match("^(%S+) (%S+) (%S+) (%S+)$")
				if not a then error("water layout vertex differs", 0) end
				li = li + 1
				r.x[i], r.z[i], r.w[i], r.level[i] = tonumber(a), tonumber(b),
					tonumber(c), tonumber(d)
			end
			layout.rivers[r.id] = r
		end
		return layout
	end

	-- Lake indicator: cubic B-spline read of the coarse mask grid. Returns the
	-- lake id with the largest indicator in the 4x4 support, that indicator,
	-- the number of lakes in the support and their ids / indicators.
	function M.lake_indicator(mask, nx, nz)
		local C, GX0, GZ0 = P.C, P.GX0, P.GZ0
		local A4, B4, IDS, MS = {0, 0, 0, 0}, {0, 0, 0, 0}, {}, {}
		return function(x, z)
			local u, v = (x - GX0) / C, (z - GZ0) / C
			local iu, iv = floor(u), floor(v)
			if iu < 1 or iv < 1 or iu > nx - 3 or iv > nz - 3 then return nil end
			A4[1], A4[2], A4[3], A4[4] = bspline(u - iu)
			B4[1], B4[2], B4[3], B4[4] = bspline(v - iv)
			local nid = 0
			for dz = -1, 2 do
				local row = (iv + dz) * nx + iu
				local bw = B4[dz + 2]
				for dx = -1, 2 do
					local l = mask[row + dx]
					if l then
						local q = 1
						while q <= nid and IDS[q] ~= l do q = q + 1 end
						if q > nid then nid = q; IDS[q], MS[q] = l, 0 end
						MS[q] = MS[q] + bw * A4[dx + 2]
					end
				end
			end
			if nid == 0 then return nil end
			local bi = 1
			for q = 2, nid do if MS[q] > MS[bi] then bi = q end end
			return IDS[bi], MS[bi], nid, IDS, MS
		end
	end

	---------------------------------------------------------------------------
	-- Per-column sampler (main and emerge).
	---------------------------------------------------------------------------
	function M.sampler(layout, seed, simplex)
		local nx, nz = layout.nx, layout.nz
		local lakes = layout.lakes
		local nbed = simplex(seed, "river_bed")
		local nval = simplex(seed, "river_valley")
		local nwall = simplex(seed, "river_wall")

		-- Flat segment arrays, bucketed on BUCKET-node cells by their reach.
		local SAX, SAZ, SVX, SVZ, SL2 = {}, {}, {}, {}, {}
		local SW0, SW1, SLV, SRIV, SIDX = {}, {}, {}, {}, {}
		local ns = 0
		local BUCKET = P.BUCKET
		local buckets = {}
		-- Occupancy of wet water on OCC-node cells: true where a river or lake
		-- column may be wet (the planner's seal scans run only there).
		local OCC = P.OCC
		local occupied = {}
		local function bkey(bx, bz) return bz * 4096 + bx end
		local function mark(x0, z0, x1, z1)
			for bz = floor(z0 / OCC), floor(z1 / OCC) do
				for bx = floor(x0 / OCC), floor(x1 / OCC) do occupied[bkey(bx, bz)] = true end
			end
		end
		for _, r in ipairs(layout.rivers) do
			for i = 1, #r.x - 1 do
				if r.w[i] > 0 and r.w[i + 1] > 0 then
					ns = ns + 1
					SAX[ns], SAZ[ns] = r.x[i], r.z[i]
					SVX[ns], SVZ[ns] = r.x[i + 1] - r.x[i], r.z[i + 1] - r.z[i]
					SL2[ns] = SVX[ns] ^ 2 + SVZ[ns] ^ 2
					if SL2[ns] < 1e-9 then SL2[ns] = 1e-9 end
					SW0[ns], SW1[ns] = r.w[i], r.w[i + 1]
					-- a segment's water surface is its downstream vertex's level
					SLV[ns] = min(r.level[i], r.level[i + 1])
					SRIV[ns], SIDX[ns] = r.id, i
					local wmax = max(r.w[i], r.w[i + 1])
					local reach = wmax / 2 + min(P.V_MAX, P.V_A + P.V_B * wmax) * 1.25 *
						(1 + 1.5 * P.WALL_WOBBLE) + 4 * P.BLEND_K + 2
					local x0, x1 = min(r.x[i], r.x[i + 1]), max(r.x[i], r.x[i + 1])
					local z0, z1 = min(r.z[i], r.z[i + 1]), max(r.z[i], r.z[i + 1])
					for bz = floor((z0 - reach) / BUCKET), floor((z1 + reach) / BUCKET) do
						for bx = floor((x0 - reach) / BUCKET), floor((x1 + reach) / BUCKET) do
							local key = bkey(bx, bz)
							local list = buckets[key]
							if not list then list = {}; buckets[key] = list end
							list[#list + 1] = ns
						end
					end
					local wet = wmax / 2 + P.WET_B + 2
					mark(x0 - wet, z0 - wet, x1 + wet, z1 + wet)
				end
			end
		end
		-- a lake column can be wet only within the B-spline support of a mask
		-- cell (two cells either side)
		for k in pairs(layout.mask) do
			local x = P.GX0 + (k % nx) * P.C
			local z = P.GZ0 + floor(k / nx) * P.C
			mark(x - 2 * P.C, z - 2 * P.C, x + 2 * P.C, z + 2 * P.C)
		end

		local lake_at = M.lake_indicator(layout.mask, nx, nz)

		local ds, ws = {}, {}
		local K = P.BLEND_K
		-- Distance to the nearest segment (true polyline distance), blended
		-- width and level reference, the nearest segment's level and index.
		local function river_at(x, z)
			local list = buckets[bkey(floor(x / BUCKET), floor(z / BUCKET))]
			if not list then return nil end
			local dmin, best = math.huge, nil
			local cnt = #list
			for j = 1, cnt do
				local s = list[j]
				local ox, oz = x - SAX[s], z - SAZ[s]
				local t = (ox * SVX[s] + oz * SVZ[s]) / SL2[s]
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local ex, ez = ox - t * SVX[s], oz - t * SVZ[s]
				local d = sqrt(ex * ex + ez * ez)
				ds[j], ws[j] = d, t
				if d < dmin then dmin, best = d, j end
			end
			local sw, sW, sL = 0, 0, 0
			local lim = dmin + 4 * K
			for j = 1, cnt do
				local d = ds[j]
				if d < lim then
					local s = list[j]
					local wt = exp(-(d - dmin) / K)
					local t = ws[j]
					sw = sw + wt
					sW = sW + wt * (SW0[s] + (SW1[s] - SW0[s]) * t)
					sL = sL + wt * SLV[s]
				end
			end
			local s = list[best]
			return dmin, sW / sw, sL / sw, SLV[s], s
		end

		local api = {}
		-- h0: the natural float field at the land column (x, z). Returns
		--   h        float ground after carving (<= h0 except the bank fill)
		--   water_y  the water surface of a wet column, else nil (wet when
		--            floor(h) <= water_y - 1)
		--   kind     "river", "lake", "fill_river", "fill_lake" (a dry bank
		--            raised to the water level: the containment margin) or nil
		--   id       segment index (rivers) or lake id
		--   bank_distance, bank_y  for a column near water: the distance to
		--            that water (true distance for rivers, a proxy for lakes)
		--            and its surface, for the bank material rule
		function api.column(x, z, h0)
			local h = h0
			local d, w, lref, level, seg = river_at(x, z)
			local u, half
			local bank_distance, bank_y
			if d then
				half = w / 2
				u = d - half
				bank_distance, bank_y = u > 0 and u or 0, level
				local V = min(P.V_MAX, P.V_A + P.V_B * w) * (1 + 0.25 * nval(x / 180, z / 180))
				if u < V * (1 + 1.5 * P.WALL_WOBBLE) then
					-- Near the channel the floor never sits below the reach's own
					-- surface (no pool above a fall): the level reference is the
					-- reach's level across the bank band (so neither a spring's
					-- end nor the upper side of a step is ringed by bank fill)
					-- and blends to the neighbours' levels within three nodes.
					-- The nearest reach changes on a straight step bisector, so
					-- this band is kept narrow: a wide one draws a long straight
					-- ramp across the floodplain at every step.
					local fp = P.FP_A + P.FP_B * w
					if level > lref then
						lref = lref + (level - lref) *
							(1 - smoothstep(P.WET_B + 2, P.WET_B + 5, u))
					end
					if h > lref then
						-- the wall distance wobbles by a 2D noise beyond the
						-- floodplain, so walls do not run parallel to the river
						local uw = u + P.WALL_WOBBLE * V * smoothstep(0, fp, u) *
							(nwall(x / 53, z / 53) + 0.5 * nwall(x / 23 + 7.3, z / 23 - 2.1))
						local S = P.FP_KEEP + (1 - P.FP_KEEP) * smootherstep(fp, V, uw)
						if u < 0 then S = P.FP_KEEP end
						h = lref + (h - lref) * S
					end
					if u < 0 then
						local q = d / half
						local depth = (1 + 0.28 * w) * (1 - q * q) + 0.6 * nbed(x / 11, z / 11)
						local bed = level - 0.3 - depth
						if bed < h then h = bed end
					end
				else
					d = nil
				end
			end
			local lid, m, nlk, LIDS, LMS = lake_at(x, z)
			if lid then
				local L = lakes[lid].level
				local ld = (0.5 - m) * P.LAKE_PROXY
				if not bank_distance or ld < bank_distance then
					bank_distance, bank_y = ld > 0 and ld or 0, L
				end
				-- A valley never cuts into a lake's rim: outside the river
				-- channel the carve fades out toward the lake and is fully
				-- undone by the rim threshold, so no one-node bank-fill line
				-- runs across a carved valley at an outlet.
				if h < L and h0 > h and not (d and u < 0) then
					local keep = min(h0, L)
					h = h + (max(h, keep) - h) * smoothstep(P.LAKE_UNCARVE, P.LAKE_RIM, m)
				end
				if m >= 0.5 and h < L then
					return h, L, "lake", lid, 0, L
				end
			end
			if d and u <= P.WET_B and floor(h) <= level - 1 then
				return h, level, "river", seg, 0, level
			end
			if lid then
				-- the rim: any lake in the support whose indicator reaches it
				local rl, rid = nil, nil
				for q = 1, nlk do
					local L = lakes[LIDS[q]].level
					if LMS[q] >= P.LAKE_RIM and floor(h) < L and (not rl or L > rl) then
						rl, rid = L, LIDS[q]
					end
				end
				if rl then return rl, nil, "fill_lake", rid, bank_distance, bank_y end
			end
			if d and u <= P.WET_B + 1.5 and floor(h) < level then
				return level, nil, "fill_river", seg, bank_distance, bank_y
			end
			return h, nil, nil, seg, bank_distance, bank_y
		end
		-- True when a river or lake column may be wet inside the rectangle.
		function api.water_in(min_x, min_z, max_x, max_z)
			for bz = floor(min_z / OCC), floor(max_z / OCC) do
				for bx = floor(min_x / OCC), floor(max_x / OCC) do
					if occupied[bkey(bx, bz)] then return true end
				end
			end
			return false
		end
		-- A cheap, conservative pre-test: false only where the column cannot
		-- be wet river or lake water (scattered queries skip the height there).
		function api.maybe_wet(x, z)
			local list = buckets[bkey(floor(x / BUCKET), floor(z / BUCKET))]
			if list then
				for j = 1, #list do
					local s = list[j]
					local ox, oz = x - SAX[s], z - SAZ[s]
					local t = (ox * SVX[s] + oz * SVZ[s]) / SL2[s]
					if t < 0 then t = 0 elseif t > 1 then t = 1 end
					local ex, ez = ox - t * SVX[s], oz - t * SVZ[s]
					-- the column's width is a blend with nearby (possibly
					-- wider) segments, hence the margin
					local reach = max(SW0[s], SW1[s]) / 2 + P.WET_B + 4
					if ex * ex + ez * ez <= reach * reach then return true end
				end
			end
			local lid, m = lake_at(x, z)
			return lid ~= nil and m >= 0.5
		end
		api.river_at, api.lake_at = river_at, lake_at
		api.rivers, api.lakes = layout.rivers, lakes
		api.segments = ns
		api.seg_river, api.seg_index = SRIV, SIDX
		return api
	end

	return M
end
