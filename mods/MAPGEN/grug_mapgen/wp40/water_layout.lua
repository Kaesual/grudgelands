-- Round 22 Phase 5 inland water (world_zones.md §7.4; plan D38, D39,
-- D54-D57).
--
-- Rivers and lakes laid out once from the drainage of the natural terrain
-- field on a coarse grid, then a pure per-column carve/water function. A
-- river's cross-section is a trough (D54): the ground is pulled toward a bed
-- below the reach's flat level, U-shaped on gentle ground and V-shaped where
-- the terrain stands high, and the water fills the trough up to the level
-- wherever the trough ground lies below it, so its width and shoreline vary
-- with the terrain like a lake's. Reach levels never rise downstream,
-- confluences and lake mouths included (D56).
--
--   local water_module = dofile("water_layout.lua")(terrain_data.water)
--   local layout = water_module.build(seed, opts)      -- main only, ~4 s
--   local text = water_module.serialize(layout)        -- the ipc_set payload
--   local water = water_module.sampler(water_module.deserialize(text), seed,
--       simplex)                                        -- main and emerge
--   water.column(x, z, h0) -> h, water_y or nil, kind or nil, id, bank_distance,
--       bank_y, material_distance
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

	-- The trough weight G(t, v), t = distance / trough radius: 0 on the
	-- centreline, 1 from t = 1 on, with zero slope there so the trough runs
	-- into the terrain without a crease. v = 0 is a U (smoothstep: a flat
	-- floor), v = 1 a V (ease-out: a straight floor that rounds off at the
	-- top). `trough_inv` is its (approximate) inverse: the mix of the two
	-- exact inverses, used to size a trough and to estimate a water edge.
	local function trough_g(t, v)
		if t >= 1 then return 1 elseif t <= 0 then return 0 end
		local u = 1 - t
		return (1 - v) * t * t * (3 - 2 * t) + v * (1 - u * u)
	end
	local function trough_inv(y, v)
		if y <= 0 then return 0 elseif y >= 1 then return 1 end
		local us = 0.5 - math.sin(math.asin(1 - 2 * y) / 3)
		local vs = 1 - sqrt(1 - y)
		return (1 - v) * us + v * vs
	end
	M.trough_g, M.trough_inv = trough_g, trough_inv

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
	-- circle (plan D57, like the D28 calm edge).
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

		-- Keep-outs (starts, protected capital cores, D57) raise the routing
		-- surface so rivers and lakes route around them; the terrain itself is
		-- unchanged.
		local nwob = opts.simplex(seed, "river_keepout")
		local R, keep = {}, {}
		for k = 0, N - 1 do R[k] = H[k] end
		-- A soft keep-out (a capital core, D57) lifts nothing: rivers drain
		-- through the reserved area as the terrain says, and the centreline
		-- bends past the core on one side (`detour`); it only keeps lakes out
		-- of the core. A hard one (a start, a civic lake) lifts the routing
		-- surface, so water routes around it.
		local soft = {}
		for ei, e in ipairs(opts.keepouts or {}) do
			soft[ei] = e.soft or nil
			local rr = e.r * (1 + (e.edge or 0))
			for iz = max(0, floor((e.z - rr - GZ0) / C)),
					min(nz - 1, floor((e.z + rr - GZ0) / C) + 1) do
				for ix = max(0, floor((e.x - rr - GX0) / C)),
						min(nx - 1, floor((e.x + rr - GX0) / C) + 1) do
					local x, z = GX0 + ix * C, GZ0 + iz * C
					local dx, dz = x - e.x, z - e.z
					local k = iz * nx + ix
					if sqrt(dx * dx + dz * dz) <= keep_radius(e, nwob, x, z) then
						keep[k] = ei
						if land[k] and not e.soft then R[k] = R[k] + P.KEEP_LIFT end
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
		-- in the keep-outs, whose lift is no depression.
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
			-- The spill comes from the routing surface; where a keep-out is the
			-- barrier it stands above the natural rim. The natural rim
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
		return {nx = nx, nz = nz, N = N, H = H, land = land, keep = keep, soft = soft,
			recv = recv, acc = acc, lakes = lakes, lake_of = lake_of, mask = mask,
			stats = stats, t0 = t0}
	end

	-- 4) Rivers: main-stem decomposition of the receiver tree.
	local function river_tree(S, opts)
		local nx, nz, N = S.nx, S.nz, S.N
		local land, keep, recv, acc, lake_of = S.land, S.keep, S.recv, S.acc, S.lake_of
		local soft = S.soft
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
			if land[k] and acc[k] >= P.RIVER_ACC and not lake_of[k] and
					not (keep[k] and not soft[keep[k]]) then
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
			elseif keep[r] and not soft[keep[r]] then e.end_kind = "keepout"
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
		-- A spring's gully (D55): the trough continues upstream along the
		-- drainage (the largest donor each step) for up to GULLY_LEN nodes,
		-- dry; `gully` lists its cells from the tip down to the spring.
		for _, rv in ipairs(rivers) do
			if not rv.src_lake then
				local up, cur, len = {}, rv.cells[1], 0
				while len < P.GULLY_LEN do
					local cx, cz = cur % nx, floor(cur / nx)
					local best, ba, bd = nil, 0, 1
					for d = 1, 8 do
						local jx, jz = cx + DX[d], cz + DZ[d]
						if jx >= 0 and jx < nx and jz >= 0 and jz < nz then
							local j = jz * nx + jx
							if recv[j] == cur and land[j] and not lake_of[j] and
									not keep[j] and not isriv[j] and acc[j] > ba then
								best, ba, bd = j, acc[j], DD[d]
							end
						end
					end
					if not best then break end
					up[#up + 1] = best
					len = len + bd * P.C
					cur = best
				end
				if #up > 0 then
					local g = {}
					for i = #up, 1, -1 do g[#g + 1] = up[i] end
					rv.gully = g
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
		-- `reach` is how far water may stand from the centreline.
		local function detour(out, reach)
			local n = #out
			local rmax_all = 0
			for i = 1, n do if reach[i] > rmax_all then rmax_all = reach[i] end end
			for _, e in ipairs(opts.keepouts or {}) do
				if e.soft then
					-- A soft keep-out: the course bends past it on the side it
					-- already leans to, along a smooth lens stretched LENS times
					-- along the flow, so the bend starts early and never
					-- follows the core's outline.
					local best, bi = math.huge, nil
					for i = 1, n do
						local d2 = (out[i][1] - e.x) ^ 2 + (out[i][2] - e.z) ^ 2
						if d2 < best then best, bi = d2, i end
					end
					local rc = e.r * (1 + (e.edge or 0)) + rmax_all + P.POI_PAD
					if bi and best < rc * rc then
						local function frame(i)
							local ia, ib = max(1, i - 4), min(n, i + 4)
							local tx, tz = out[ib][1] - out[ia][1], out[ib][2] - out[ia][2]
							local tl = sqrt(tx * tx + tz * tz)
							if tl < 1e-6 then return 1, 0 end
							return tx / tl, tz / tl
						end
						local tx, tz = frame(bi)
						local side = (tx * (out[bi][2] - e.z) - tz * (out[bi][1] - e.x)) >= 0 and 1 or -1
						-- the push along each vertex's own normal (its local
						-- frame, so a curved course keeps its shape), then
						-- smoothed along the course
						local px, pz = {}, {}
						for i = 1, n do
							px[i], pz[i] = 0, 0
							local x, z = out[i][1], out[i][2]
							local dx, dz = x - e.x, z - e.z
							local r0 = keep_radius(e, nwob, x, z) + reach[i] + P.POI_PAD
							local A = P.LENS * r0
							local fx, fz = frame(i)
							local a = dx * fx + dz * fz
							if a * a < A * A then
								local f = 1 - abs(a) / A
								local lim = r0 * f * f * (3 - 2 * f)
								local l0 = -dx * fz + dz * fx
								if abs(l0) < lim and side * l0 < lim then
									local dl = side * lim - l0
									px[i], pz[i] = -fz * dl, fx * dl
								end
							end
						end
						for _ = 1, 6 do
							local ox, oz = {}, {}
							for i = 1, n do
								local ia, ib = max(1, i - 1), min(n, i + 1)
								ox[i] = (px[ia] + 2 * px[i] + px[ib]) / 4
								oz[i] = (pz[ia] + 2 * pz[i] + pz[ib]) / 4
							end
							px, pz = ox, oz
						end
						for i = 1, n do
							local x, z = out[i][1] + px[i], out[i][2] + pz[i]
							-- the smoothing may leave a vertex short of the core:
							-- the radial clearance still holds
							local r = keep_radius(e, nwob, x, z) + reach[i] + P.POI_PAD
							local dx, dz = x - e.x, z - e.z
							local d2 = dx * dx + dz * dz
							if d2 < r * r then
								local d = sqrt(d2)
								if d < 1e-3 then dx, dz, d = 1, 0, 1 end
								x, z = e.x + dx / d * r, e.z + dz / d * r
							end
							out[i] = {x, z}
						end
					end
				else
					for i = 1, n do
						local x, z = out[i][1], out[i][2]
						local r = keep_radius(e, nwob, x, z) + reach[i] + P.POI_PAD
						local dx, dz = x - e.x, z - e.z
						local d2 = dx * dx + dz * dz
						if d2 < r * r then
							local d = sqrt(d2)
							if d < 1e-3 then dx, dz, d = 1, 0, 1 end
							out[i] = {e.x + dx / d * r, e.z + dz / d * r}
						end
					end
				end
			end
			for _, p in ipairs(opts.pois or {}) do
				local best, bi = math.huge, nil
				for i = 1, n do
					local d2 = (out[i][1] - p.x) ^ 2 + (out[i][2] - p.z) ^ 2
					if d2 < best then best, bi = d2, i end
				end
				local rmax = p.r + rmax_all + P.POI_PAD + P.MEANDER_MAX
				if bi and best < rmax * rmax then
					local ia, ib = max(1, bi - 3), min(n, bi + 3)
					local tx, tz = out[ib][1] - out[ia][1], out[ib][2] - out[ia][2]
					local tl = sqrt(tx * tx + tz * tz)
					if tl < 1e-6 then tx, tz, tl = 1, 0, 1 end
					tx, tz = tx / tl, tz / tl
					local side = (tx * (out[bi][2] - p.z) - tz * (out[bi][1] - p.x)) >= 0 and 1 or -1
					for i = 1, n do
						local x, z = out[i][1], out[i][2]
						local r = p.r + reach[i] + P.POI_PAD
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
		local function plen(pts, a, b)
			local l = 0
			for i = a, b - 1 do
				l = l + sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2)
			end
			return l
		end
		for _, rv in ipairs(S.rivers) do
			-- the cell path: the gully (tip first), then the river cells
			local cells = {}
			for _, c in ipairs(rv.gully or {}) do cells[#cells + 1] = c end
			local ng = #cells
			for _, c in ipairs(rv.cells) do cells[#cells + 1] = c end
			local pts = {}
			if rv.src_cell then local x, z = cxz(rv.src_cell); pts[1] = {x, z} end
			for _, c in ipairs(cells) do local x, z = cxz(c); pts[#pts + 1] = {x, z} end
			-- raw length of the gully (tip to spring cell) and of the path
			local raw_gully = ng > 0 and plen(pts, 1, ng + 1) or 0
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
			local raw_total = plen(pts, 1, #pts)
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
			-- the spring's arc position on the smoothed path; vertices above it
			-- are the gully
			local s0 = raw_total > 0 and raw_gully * total / raw_total or 0
			local gully = {}
			for i = 1, n do gully[i] = ng > 0 and s[i] < s0 end
			-- The course width (the accepted Phase 5 channel model) drives the
			-- meander and nothing else, so the winding shape stays as it was.
			local widths = {}
			for i = 1, n do
				local x, z = pts[i][1], pts[i][2]
				local w = P.CW_A * sqrt(accs[i] * C * C)
				w = w * (1 + P.CW_NOISE * nwidth(x / 300, z / 300))
				widths[i] = min(P.CW_MAX, max(P.CW_MIN, w))
			end
			-- The water width target (D55): about W_MUL x the course width,
			-- with more variation along the course, at least W_MIN.
			local water = {}
			for i = 1, n do
				local x, z = pts[i][1], pts[i][2]
				local w = P.W_MUL * widths[i] * (1 + P.W_NOISE * nwidth(x / P.W_P + 17.3,
					z / P.W_P - 5.9) + P.W_NOISE2 * nwidth(x / P.W_P2 - 31.1, z / P.W_P2 + 8.4))
				water[i] = min(P.W_MAX, max(P.W_MIN, w))
			end
			-- a river that does not leave a lake starts small (a spring)
			if not rv.src_lake then
				for i = 1, n do
					local sd = s[i] - s0
					widths[i] = max(P.CW_SRC, widths[i] * (P.SRC_KEEP + (1 - P.SRC_KEEP) *
						smoothstep(0, P.SRC_TAPER, sd)))
					water[i] = P.W_MIN + (water[i] - P.W_MIN) * smoothstep(0, P.W_TAPER, sd)
				end
			end
			for _ = 1, 4 do
				local o, ow = {}, {}
				for i = 1, n do
					local a, b = max(1, i - 1), min(n, i + 1)
					o[i] = (widths[a] + 2 * widths[i] + widths[b]) / 4
					ow[i] = (water[a] + 2 * water[i] + water[b]) / 4
				end
				widths, water = o, ow
			end
			-- meander: a displacement normal to the path from 2D noise, never
			-- from arc length; it fades in below the spring, not in the gully
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
				local taper = smoothstep(0, 80, s[i] - s0) * smoothstep(0, 80, total - s[i])
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
			-- twice: a detour around one core can push the path into a
			-- neighbour's. Water may stand up to W + WET_X + WET_B from the
			-- centreline (the sampler's wet limit), the gully not at all.
			local reach = {}
			for i = 1, n do
				reach[i] = gully[i] and P.GULLY_A0 or water[i] + P.WET_X + P.WET_B
			end
			detour(out, reach)
			detour(out, reach)
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
					water[i] = water[i] * (1 + P.MOUTH_FLARE * (1 - smoothstep(-10, 120, sd)))
				end
			end
			-- signed widths: water width (> 0), or minus a gully's trough
			-- width (< 0: dry), its half-width falling toward the tip
			local ws = {}
			for i = 1, n do
				if gully[i] then
					local f = s0 > 0 and s[i] / s0 or 1
					ws[i] = -2 * (P.GULLY_A1 + (P.GULLY_A0 - P.GULLY_A1) * f)
				else
					ws[i] = water[i]
				end
			end
			rv.pts, rv.acc, rv.gully_s0, rv.s = out, accs, s0, s
			-- the geometry's widths; `levels` narrows its own copy at sinks
			rv.w_geom = ws
		end
	end

	local function tangent(pts, i)
		local n = #pts
		local ia, ib = max(1, i - 1), min(n, i + 1)
		local tx, tz = pts[ib][1] - pts[ia][1], pts[ib][2] - pts[ia][2]
		local tl = sqrt(tx * tx + tz * tz)
		if tl < 1e-6 then return 1, 0 end
		return tx / tl, tz / tl
	end

	-- 6) Levels: band minimum of the terrain, cumulative minimum downstream,
	-- incision, reaches of constant surface, steps shaped by the slope. Reach
	-- levels never rise downstream (D56): the rivers are levelled
	-- tributaries first, and a tributary's level at its junction caps its
	-- parent's levels below it; the stretch after a sink starts no higher
	-- than the one before it; a river ending in a lake is raised to the lake's
	-- level at its mouth (the trough's fill level absorbs the difference).
	local function levels(S, opts)
		local field, land_at = opts.field, opts.land_at
		local lakes, stats = S.lakes, S.stats
		stats.sinks, stats.max_cut, stats.lake_raise, stats.dry_junctions = 0, 0, 0, 0
		stats.trib_raise = 0
		local function fh(x, z)
			if not land_at(x, z) then return 1 end
			return field.height_at(x, z, true)
		end
		local ACROSS = {-1, -0.5, 0, 0.5, 1}
		-- (a gully's width is negative: its trough width)
		local function band_min(rv, i)
			local x, z = rv.pts[i][1], rv.pts[i][2]
			local tx, tz = tangent(rv.pts, i)
			local r = abs(rv.w[i]) / 2 + P.BAND
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
			local r = abs(rv.w[i]) / 2 + P.WET_B + 2
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
		-- the sea is a floor for every river of a system that reaches it
		local function reaches_sea(rv)
			while rv.parent do rv = S.rivers[rv.parent] end
			return rv.end_kind == "sea"
		end
		local caps = {}
		for ri = #S.rivers, 1, -1 do
			local rv = S.rivers[ri]
			local n = #rv.pts
			local w = {}
			for q = 1, n do w[q] = rv.w_geom[q] end
			rv.w = w
			local m = {}
			for i = 1, n do m[i] = band_min(rv, i) end
			local sea_floor = reaches_sea(rv) and 1 or nil
			local start_cap = math.huge
			if rv.src_lake then start_cap = lakes[rv.src_lake].level end
			-- junction caps from the tributaries levelled before this river
			local cap_at = {}
			for _, c in ipairs(caps[rv.id] or {}) do
				local q = min(n, c.index + 1)
				if not cap_at[q] or c.level < cap_at[q] then cap_at[q] = c.level end
			end
			-- incision below the band terrain; a gully's fades out to its tip
			local s0 = rv.gully_s0 or 0
			local function inc(i)
				if w[i] < 0 then
					return (P.INC_A + P.INC_B * P.W_MIN) * (s0 > 0 and rv.s[i] / s0 or 1)
				end
				return P.INC_A + P.INC_B * w[i]
			end
			-- A river may not climb: where the band terrain stands more than
			-- CUT_MAX above the current level, the river sinks, a dry gap
			-- follows, and a new stretch springs up with its own profile, no
			-- higher than the one before.
			local p, dry, lv = {}, {}, {}
			local run = start_cap + inc(1)
			local L, lcap = nil, math.huge
			local i = 1
			rv.sinks = {}
			while i <= n do
				if cap_at[i] and cap_at[i] < lcap then lcap = cap_at[i] end
				if L == nil and not (i == 1 and rv.src_lake) then
					local sm = spring_min(rv, i)
					if sm < run then run = sm end
				end
				if m[i] < run then run = m[i] end
				p[i] = run
				local tt = run - inc(i)
				-- The sea is a floor for the whole river system. A lake is not:
				-- raising a river that runs below its end would perch it on bank
				-- walls above its own valley; its mouth is raised afterwards.
				if sea_floor and tt < sea_floor then tt = sea_floor end
				if L == nil then
					L = floor(tt)
					if i == 1 and rv.src_lake then L = lakes[rv.src_lake].level end
				end
				if tt <= L - 1 then L = floor(tt) + 1 end
				if L > lcap then L = lcap end
				if sea_floor and (tt <= sea_floor or L < sea_floor) then L = sea_floor end
				if w[i] > 0 and m[i] - L > P.CUT_MAX and i > 1 and i + P.SINK_GAP < n then
					local j = i
					local back = L + inc(i) + P.SINK_BACK
					while j < n - 1 and (j < i + P.SINK_GAP or m[j] > back) and
							j < i + P.SINK_MAX do
						j = j + 1
					end
					rv.sinks[#rv.sinks + 1] = {i, j}
					for q = i, j - 1 do
						dry[q], lv[q], p[q] = true, L, run
						if cap_at[q] and cap_at[q] < lcap then lcap = cap_at[q] end
					end
					if L < lcap then lcap = L end
					i = j
					run, L = math.huge, nil
				else
					lv[i] = L
					i = i + 1
				end
			end
			stats.sinks = stats.sinks + #rv.sinks
			-- the lowest cap met (junctions, sinks): a raised mouth stays below
			rv.lcap = lcap
			if sea_floor and not rv.parent and rv.end_kind == "sea" then lv[n] = sea_floor end
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
			-- A lake mouth meets the lake at its level (D56); `settle_lakes`
			-- keeps that raise small.
			rv.mouth = nil
			if rv.end_kind == "lake" and rv.end_lake and not rv.parent then
				local ll = lakes[rv.end_lake].level
				-- the mouth: the river's own level at its last vertex whose band
				-- still stands above the lake (the last vertices lie over the
				-- lake bed and would pull the profile down)
				for q = n, 1, -1 do
					if dry[q] then break end
					rv.mouth = lv[q]
					if m[q] >= ll then break end
				end
				for q = n, 1, -1 do
					if dry[q] or lv[q] >= ll then break end
					if ll - lv[q] > stats.lake_raise then stats.lake_raise = ll - lv[q] end
					lv[q] = ll
				end
			end
			rv.levels = lv
			-- the water narrows to W_MIN into a sink and out of the spring
			-- after it
			for _, gap in ipairs(rv.sinks) do
				local e, sp = gap[1] - 1, gap[2]
				for q = 1, n do
					local dd
					if q <= e then dd = (e - q) * P.SEG elseif q >= sp then dd = (q - sp) * P.SEG end
					if dd and dd < P.W_TAPER and w[q] > 0 then
						w[q] = min(w[q], P.W_MIN + (w[q] - P.W_MIN) *
							smoothstep(0, P.W_TAPER, dd))
					end
				end
			end
			for q in pairs(dry) do w[q] = 0 end
			rv.dry = dry
			for q = 1, n do
				local c = (dry[q] or w[q] <= 0) and 0 or m[q] - lv[q]
				if c > (stats.max_cut or 0) then stats.max_cut = c end
			end
			-- the tributary's level at the junction caps its parent below it
			if rv.parent and not dry[n] and w[n] > 0 then
				local list = caps[rv.parent]
				if not list then list = {}; caps[rv.parent] = list end
				list[#list + 1] = {index = rv.junction_index, level = lv[n]}
			end
		end
		-- Tributary mouths, parents first: the tail that already runs inside
		-- the parent's channel (the junction snap can overlap it for a few
		-- vertices) takes the parent's surface, so the two channels never hold
		-- different surfaces side by side, and a tributary never runs below
		-- its parent. A parent dry at the junction (inside its sink gap) has
		-- no surface to meet: the tributary keeps its own profile.
		for _, rv in ipairs(S.rivers) do
			local par = rv.parent and S.rivers[rv.parent]
			if par then
				local n, lv = #rv.pts, rv.levels
				local ji = rv.junction_index
				local jb = min(#par.levels, ji + 1)
				if not rv.dry[n] and not (par.dry[ji] or par.dry[jb]) and
						par.w[ji] > 0 and par.w[jb] > 0 then
					local end_level = par.levels[jb]
					lv[n] = end_level
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
							local reach = max(par.w[k], par.w[k + 1]) / 2 + P.WET_X + P.WET_B
							if par.w[k] > 0 and ex * ex + ez * ez <= reach * reach then
								inside = true
								break
							end
						end
						if not inside then break end
						lv[q] = end_level
					end
					for q = n, 1, -1 do
						if rv.dry[q] or lv[q] >= end_level then break end
						if end_level - lv[q] > stats.trib_raise then
							stats.trib_raise = end_level - lv[q]
						end
						lv[q] = end_level
					end
				else
					stats.dry_junctions = stats.dry_junctions + 1
				end
			end
		end
	end

	-- Lake levels against the rivers between them (D56): a river's mouth may
	-- be raised to its lake by at most LAKE_RAISE nodes (the trough's fill
	-- absorbs that); a lake standing higher above the river's own profile is
	-- lowered, and a lake stands no higher than a lake feeding it through a
	-- river, a tributary joining that river or the stretch before a sink. Returns true when a level changed (the rivers are then
	-- levelled again).
	-- True when the masks of lakes a and b come within three coarse cells
	-- (their B-spline supports overlap: their water could meet).
	local function lakes_touch(S, a, b)
		local nx = S.nx
		for k, id in pairs(S.mask) do
			if id == b then
				local kx, kz = k % nx, floor(k / nx)
				for dz = -3, 3 do
					for dx = -3, 3 do
						if S.mask[(kz + dz) * nx + kx + dx] == a then return true end
					end
				end
			end
		end
		return false
	end

	local function settle_lakes(S)
		local changed = false
		for _, rv in ipairs(S.rivers) do
			local L = rv.end_kind == "lake" and not rv.parent and rv.end_lake and
				S.lakes[rv.end_lake]
			if L then
				local cap = rv.mouth and rv.mouth + P.LAKE_RAISE or math.huge
				if rv.lcap < cap then cap = rv.lcap end
				-- Between two lakes the lower one stands no higher than the
				-- upper one; where their masks lie so close that their water
				-- could meet, it takes exactly the upper one's level (their
				-- surfaces must not meet at different levels).
				local A = rv.src_lake and S.lakes[rv.src_lake]
				if A then
					if A.level < cap then cap = A.level end
					if cap < A.level and L.level >= A.level and
							lakes_touch(S, rv.src_lake, rv.end_lake) then
						cap = A.level
					end
				end
				if L.level > cap then
					L.level = cap
					changed = true
					S.stats.lakes_lowered = (S.stats.lakes_lowered or 0) + 1
				end
			end
		end
		return changed
	end

	-- 7) Troughs (D54): per vertex the bed depth D below the level, the
	-- trough radius R and the profile shape v (0 U, 1 V), from the water
	-- half-width a and the bank height hb (the mean natural terrain HB_OFF
	-- beyond the nominal water edge, above the level). R puts the water edge
	-- at a for that bank; where R is clamped, D follows. A gully's trough has
	-- no depth below its level (it stays dry).
	local function troughs(S, opts)
		local field, land_at = opts.field, opts.land_at
		local stats = S.stats
		local rsum, rn, nclamp_lo, nclamp_hi = 0, 0, 0, 0
		for _, rv in ipairs(S.rivers) do
			local n = #rv.pts
			local R, D, V = {}, {}, {}
			for i = 1, n do
				local w = rv.w[i]
				if w < 0 then
					R[i], D[i], V[i] = -w / 2 * P.GULLY_R, 0, 0.5
				elseif w == 0 then
					R[i], D[i], V[i] = 0, 0, 0
				else
					local a = w / 2
					local x, z = rv.pts[i][1], rv.pts[i][2]
					local tx, tz = tangent(rv.pts, i)
					local o = a + P.HB_OFF
					local hs, c = 0, 0
					for f = -1, 1, 2 do
						local px, pz = x - tz * o * f, z + tx * o * f
						if land_at(px, pz) then
							hs = hs + field.height_at(px, pz, true)
							c = c + 1
						end
					end
					local hb = c > 0 and hs / c - rv.levels[i] or 1
					if hb < 0.5 then hb = 0.5 end
					local v = smoothstep(P.HB_U, P.HB_V, hb)
					local d = P.DEPTH_A + P.DEPTH_B * w
					local r = a / max(0.02, trough_inv(d / (hb + d), v))
					local rc = min(P.R_MAX, max(a * P.R_MIN, r))
					if rc < r then nclamp_hi = nclamp_hi + 1
					elseif rc > r then nclamp_lo = nclamp_lo + 1 end
					if rc ~= r then
						local g = trough_g(a / rc, v)
						d = hb * g / (1 - g)
					end
					R[i], D[i], V[i] = rc, min(P.D_MAX, max(P.D_MIN, d)), v
					rsum, rn = rsum + rc, rn + 1
				end
			end
			-- smooth along the course among wet vertices (the bank samples
			-- are noisy)
			for _ = 1, 3 do
				local oR, oD, oV = {}, {}, {}
				for i = 1, n do
					oR[i], oD[i], oV[i] = R[i], D[i], V[i]
					if rv.w[i] > 0 then
						local sr, sd, sv, sw = 2 * R[i], 2 * D[i], 2 * V[i], 2
						for j = i - 1, i + 1, 2 do
							if j >= 1 and j <= n and rv.w[j] > 0 then
								sr, sd, sv, sw = sr + R[j], sd + D[j], sv + V[j], sw + 1
							end
						end
						oR[i], oD[i], oV[i] = sr / sw, sd / sw, sv / sw
					end
				end
				R, D, V = oR, oD, oV
			end
			rv.R, rv.D, rv.V = R, D, V
		end
		stats.trough_r_mean = rn > 0 and rsum / rn or 0
		stats.trough_clamp_lo, stats.trough_clamp_hi = nclamp_lo, nclamp_hi
	end

	-- A lake whose rim a passing river cuts below its surface drains: it is
	-- dropped (rivers that ended in it end dry there).
	local function drain_crossed_lakes(S)
		local lake_ind = M.lake_indicator(S.mask, S.nx, S.nz)
		local drained, drained_ids = {}, {}
		for _, rv in ipairs(S.rivers) do
			local n = #rv.pts
			for i = 1, n do
				if not rv.dry[i] and rv.w[i] > 0 then
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
		for _ = 1, 6 do
			if not settle_lakes(S) then break end
			levels(S, opts)
		end
		troughs(S, opts)
		-- A river's vertices well inside its source or end lake carry no
		-- trough (a straight trench across the lake bed with straight
		-- edges at the shore): the river starts at the shore; a river
		-- ending in a lake keeps reaching into it a little further, so its
		-- mouth joins the lake's water (a shorter one ends in a bank dam).
		local lake_ind = M.lake_indicator(S.mask, S.nx, S.nz)
		local function inside(rv, i, lid, limit)
			local id, m = lake_ind(rv.pts[i][1], rv.pts[i][2])
			return id == lid and m >= limit
		end
		for _, rv in ipairs(S.rivers) do
			local n = #rv.pts
			if rv.src_lake then
				for i = 1, n - 1 do
					if rv.w[i] > 0 and inside(rv, i, rv.src_lake, P.LAKE_TRIM) then
						rv.w[i] = 0
					else
						break
					end
				end
			end
			if rv.end_lake and not rv.parent then
				for i = n, 2, -1 do
					if rv.w[i] > 0 and inside(rv, i, rv.end_lake, P.LAKE_TRIM_END) then
						rv.w[i] = 0
					else
						break
					end
				end
			end
		end
		local stats = S.stats
		local nsteps, maxstep, hist = 0, 0, {}
		for _, rv in ipairs(S.rivers) do
			for i = 2, #rv.levels do
				local d = rv.levels[i - 1] - rv.levels[i]
				if d > 0 and not rv.dry[i] and rv.w[i] > 0 and rv.w[i - 1] > 0 then
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
				x = {}, z = {}, w = {}, level = {}, R = {}, D = {}, V = {}}
			for i, p in ipairs(rv.pts) do
				r.x[i], r.z[i], r.w[i], r.level[i] = p[1], p[2], rv.w[i], rv.levels[i]
				r.R[i], r.D[i], r.V[i] = rv.R[i], rv.D[i], rv.V[i]
			end
			layout.rivers[rv.id] = r
		end
		layout.grid = {nx = S.nx, nz = S.nz, cell = P.C, x0 = P.GX0, z0 = P.GZ0,
			height = S.H, land = S.land}
		return layout
	end

	---------------------------------------------------------------------------
	-- Serialization: the ipc_set payload (plain text, deterministic).
	--   W2 <nx> <nz> <lakes> <rivers>
	--   L <level> <ncells> <delta-encoded mask cell indices>   (per lake)
	--   R <id> <parent or 0> <end kind> <nvertices> <src lake or 0> <end lake or 0> <drains or ->
	--   <x> <z> <width> <level> <R> <D> <v>                    (per vertex)
	-- width: the water width target, 0 in a dry gap (no trough), minus the
	-- trough width in a spring's dry gully; R, D, v: the trough (troughs()).
	---------------------------------------------------------------------------
	function M.serialize(layout)
		local out = {}
		out[#out + 1] = ("W2 %d %d %d %d\n"):format(layout.nx, layout.nz,
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
				out[#out + 1] = ("%.1f %.1f %.1f %d %.1f %.2f %.2f\n"):format(r.x[i],
					r.z[i], r.w[i], r.level[i], r.R[i], r.D[i], r.V[i])
			end
		end
		return table.concat(out)
	end

	function M.deserialize(text)
		if type(text) ~= "string" then error("water layout text differs", 0) end
		local lines = {}
		for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
		local nx, nz, nl, nr = (lines[1] or ""):match("^W2 (%d+) (%d+) (%d+) (%d+)$")
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
				level = {}, R = {}, D = {}, V = {}, drains = {}}
			if tonumber(parent) ~= 0 then r.parent = tonumber(parent) end
			if tonumber(sl) ~= 0 then r.src_lake = tonumber(sl) end
			if tonumber(el) ~= 0 then r.end_lake = tonumber(el) end
			for v in dl:gmatch("%d+") do r.drains[tonumber(v)] = true end
			for i = 1, tonumber(n) do
				local a, b, c, d, e, f, g = (lines[li] or ""):match(
					"^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
				if not a then error("water layout vertex differs", 0) end
				li = li + 1
				r.x[i], r.z[i], r.w[i], r.level[i] = tonumber(a), tonumber(b),
					tonumber(c), tonumber(d)
				r.R[i], r.D[i], r.V[i] = tonumber(e), tonumber(f), tonumber(g)
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
		local nwall = simplex(seed, "river_wall")
		local WOB, K = P.TROUGH_WOBBLE, P.BLEND_K

		-- Flat segment arrays, bucketed on BUCKET-node cells. Every segment
		-- with a trough (a wet reach or a gully) is listed within the same
		-- reach, the largest trough plus the blend range, so a column's
		-- nearest segment is always in its list wherever any trough reaches
		-- it (no bucket-edge seams).
		local SAX, SAZ, SVX, SVZ, SL2 = {}, {}, {}, {}, {}
		local SW0, SW1, SLV, SLW, SRIV, SIDX, SWET = {}, {}, {}, {}, {}, {}, {}
		local SR0, SR1, SD0, SD1, SV0, SV1, SL0, SL1 = {}, {}, {}, {}, {}, {}, {}, {}
		local ns = 0
		local BUCKET = P.BUCKET
		local buckets = {}
		local REACH = P.R_MAX * (1 + WOB) + 4 * K + 2
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
		-- How far water may stand from the centreline at a vertex: where the
		-- trough ground lies below the level, within min(R, W + WET_X) +
		-- WET_B; none in a gully or a dry gap.
		local function wet_limit(w, R)
			if w <= 0 then return 0 end
			return min(R, w + P.WET_X) + P.WET_B
		end
		for _, r in ipairs(layout.rivers) do
			-- the level of the first wet vertex below a gully: the water table
			-- that a gully column near the spring pool fills to
			local n = #r.x
			local spring_level
			for i = 1, n do
				if r.w[i] > 0 then spring_level = r.level[i]; break end
			end
			for i = 1, n - 1 do
				local wa, wb = r.w[i], r.w[i + 1]
				if wa ~= 0 and wb ~= 0 then
					ns = ns + 1
					SAX[ns], SAZ[ns] = r.x[i], r.z[i]
					SVX[ns], SVZ[ns] = r.x[i + 1] - r.x[i], r.z[i + 1] - r.z[i]
					SL2[ns] = SVX[ns] ^ 2 + SVZ[ns] ^ 2
					if SL2[ns] < 1e-9 then SL2[ns] = 1e-9 end
					SW0[ns], SW1[ns] = abs(wa), abs(wb)
					SR0[ns], SR1[ns] = r.R[i], r.R[i + 1]
					SD0[ns], SD1[ns] = r.D[i], r.D[i + 1]
					SV0[ns], SV1[ns] = r.V[i], r.V[i + 1]
					SL0[ns], SL1[ns] = wet_limit(wa, r.R[i]), wet_limit(wb, r.R[i + 1])
					SWET[ns] = wa > 0 and wb > 0
					-- a segment's level is its downstream vertex's; its water
					-- surface too, except a gully's: the spring pool's
					SLV[ns] = min(r.level[i], r.level[i + 1])
					SLW[ns] = SLV[ns]
					if not SWET[ns] and spring_level then SLW[ns] = spring_level end
					SRIV[ns], SIDX[ns] = r.id, i
					local x0, x1 = min(r.x[i], r.x[i + 1]), max(r.x[i], r.x[i + 1])
					local z0, z1 = min(r.z[i], r.z[i + 1]), max(r.z[i], r.z[i + 1])
					for bz = floor((z0 - REACH) / BUCKET), floor((z1 + REACH) / BUCKET) do
						for bx = floor((x0 - REACH) / BUCKET), floor((x1 + REACH) / BUCKET) do
							local key = bkey(bx, bz)
							local list = buckets[key]
							if not list then list = {}; buckets[key] = list end
							list[#list + 1] = ns
						end
					end
					-- the blended wet limit can borrow from a neighbour within
					-- the blend range
					local wl = max(SL0[ns], SL1[ns])
					if wl > 0 then
						wl = wl + 4 * K + 2
						mark(x0 - wl, z0 - wl, x1 + wl, z1 + wl)
					end
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
		-- Distance to the nearest segment (true polyline distance), the
		-- attributes blended by smooth weights of the segment distances
		-- (water width, level reference, trough radius, depth, shape, wet
		-- limit), the nearest segment's water surface and index, and the level
		-- blend over the nearest river's own segments only (a step inside one
		-- river shows against it, a confluence does not). Near a spring the gully's depth and wet limit
		-- fade out within a few nodes past the nearest wet segment, so the
		-- spring pool ends short instead of trickling up the gully.
		local function river_at(x, z)
			local list = buckets[bkey(floor(x / BUCKET), floor(z / BUCKET))]
			if not list then return nil end
			local dmin, best, dwet = math.huge, nil, math.huge
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
				if SWET[s] and d < dwet then dwet = d end
			end
			if dmin > REACH then return nil end
			local sw, sW, sL, sR, sD, sV, sWL = 0, 0, 0, 0, 0, 0, 0
			local rv, sws, sLs = SRIV[list[best]], 0, 0
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
					if SRIV[s] == rv then sws, sLs = sws + wt, sLs + wt * SLV[s] end
					sR = sR + wt * (SR0[s] + (SR1[s] - SR0[s]) * t)
					sD = sD + wt * (SD0[s] + (SD1[s] - SD0[s]) * t)
					sV = sV + wt * (SV0[s] + (SV1[s] - SV0[s]) * t)
					sWL = sWL + wt * (SL0[s] + (SL1[s] - SL0[s]) * t)
				end
			end
			local s = list[best]
			local D, WL = sD / sw, sWL / sw
			if not SWET[s] then
				local f = 1 - smoothstep(0, 6, dwet - dmin)
				D, WL = D * f, WL * f
			end
			return dmin, sW / sw, sL / sw, SLW[s], s, sR / sw, D, sV / sw, WL,
				sLs / sws
		end

		local api = {}
		-- h0: the natural float field at the land column (x, z). Returns
		--   h        float ground after carving (<= h0 except the bank fill)
		--   water_y  the water surface of a wet column, else nil (wet when
		--            floor(h) <= water_y - 1)
		--   kind     "river", "lake", "fill_river", "fill_lake" (a dry bank
		--            raised to the water level: the containment margin) or nil
		--   id       segment index (rivers) or lake id
		--   bank_distance  for a column near natural water: its distance in
		--            nodes to where that water may stand (rivers: beyond the
		--            wet limit, never an overestimate; lakes: the indicator
		--            proxy), nil when no natural water is near (more than
		--            about ten nodes)
		--   bank_y   that water's surface
		--   material_distance  the distance the bank material rule reads
		--            (rivers: the estimated water edge for this column's bank
		--            height, times RIVER_BANK_MUL for a narrow sand band;
		--            lakes: the proxy)
		function api.column(x, z, h0)
			local h = h0
			local d, w, lref, level, seg, R, D, V, wl, lown = river_at(x, z)
			local bank_distance, bank_y, material_distance
			local channel = 0
			if d then
				local a = w / 2
				local t = R > 0 and d / (R * (1 + WOB * nwall(x / 53, z / 53))) or 1
				if t < 1 or d <= wl + 10 then
					-- The trough (D54): the ground is pulled toward the bed B =
					-- lb - D with the weight G(t), lb the smooth blend of the
					-- reach levels. At a step within one river, near the water,
					-- lb moves to the nearest reach's own level, so the step
					-- stays a face inside the channel (no pool above a fall
					-- spilling over lowered banks, no dry floor below one); the
					-- banks beyond keep the smooth blend. Between two rivers
					-- (a confluence) the blend stays smooth: their bisector
					-- runs along the flow and must not show as a line.
					local lb = lref
					if D > 0 then
						lb = lref + (level - lown) * (1 - smoothstep(a + 2, a + 8, d))
					end
					-- Above a step the upper reach keeps to its channel: water
					-- beyond it would flood the low bank up to the step's
					-- straight bisector.
					if level > lown and wl > a + P.WET_B then
						wl = wl + (a + P.WET_B - wl) * smoothstep(0.15, 0.6, level - lown)
					end
					local B = lb - D * (1 + P.BED_NOISE * nbed(x / 11, z / 11))
					if h > B then h = B + (h - B) * trough_g(t, V) end
					if wl > 0 then
						-- the water edge for this column's own bank height (an
						-- estimate): the bank rule's distance, never beyond
						-- the nominal half-width
						local hl = h0 - level
						if hl < 0 then hl = 0 end
						local de = D > 0 and trough_inv(D / (hl + D), V) * R or 0
						if de < a then de = a end
						-- the river's own channel (kept carved through a lake's
						-- rim): full in its core, fading out by the water edge
						channel = 1 - smoothstep(0.5 * a, de + 4, d)
						local u = d - de
						material_distance = (u > 0 and u or 0) * P.RIVER_BANK_MUL
						u = d - wl
						bank_distance, bank_y = u > 0 and u or 0, level
					end
				else
					d = nil
				end
			end
			local lid, m, nlk, LIDS, LMS = lake_at(x, z)
			if lid then
				local L = lakes[lid].level
				local ld = (0.5 - m) * P.LAKE_PROXY
				-- dry ground inside the mask (an island, or a basin a lowered
				-- lake no longer fills): its height above the water stands in
				-- for the distance, so no dry lake bed turns to beach
				if ld < 0 then ld = h > L and (h - L) * P.LAKE_RISE_D or 0 end
				if not bank_distance or ld < bank_distance then
					bank_distance, bank_y, material_distance = ld, L, ld
				end
				-- A valley never cuts into a lake's rim: the carve fades out
				-- toward the lake and is fully undone by the rim threshold, so
				-- no one-node bank-fill line runs across a carved valley at an
				-- outlet. Only the river's channel stays carved through the rim,
				-- fading smoothly across its width (no straight channel edge).
				if h < L and h0 > h and channel < 1 then
					local keep = min(h0, L)
					h = h + (max(h, keep) - h) *
						smoothstep(P.LAKE_UNCARVE, P.LAKE_RIM, m) * (1 - channel)
				end
				if m >= 0.5 and h < L then
					return h, L, "lake", lid, 0, L
				end
			end
			if d and wl >= 0.5 and d <= wl and floor(h) <= level - 1 then
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
				if rl then
					return rl, nil, "fill_lake", rid, bank_distance, bank_y, material_distance
				end
			end
			if d and wl > 0 and d <= wl + 1.5 and floor(h) < level then
				return level, nil, "fill_river", seg, bank_distance, bank_y,
					material_distance
			end
			return h, nil, nil, seg, bank_distance, bank_y, material_distance
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
					local wl = max(SL0[s], SL1[s])
					if wl > 0 then
						local ox, oz = x - SAX[s], z - SAZ[s]
						local t = (ox * SVX[s] + oz * SVZ[s]) / SL2[s]
						if t < 0 then t = 0 elseif t > 1 then t = 1 end
						local ex, ez = ox - t * SVX[s], oz - t * SVZ[s]
						-- the column's wet limit is a blend with nearby (possibly
						-- wider) segments, hence the margin
						local reach = wl + 4 * K + 1
						if ex * ex + ez * ez <= reach * reach then return true end
					end
				end
			end
			local lid, m = lake_at(x, z)
			return lid ~= nil and m >= 0.5
		end
		-- River centrelines for drawing (the world map): one row per run of
		-- vertices of positive width (the runs the segments above cover),
		-- {id =, points = {{x =, z =, w =}, ...}} in layout order. A fresh
		-- copy per call.
		function api.polylines()
			local result = {}
			for _, r in ipairs(layout.rivers) do
				local points = {}
				for i = 1, #r.x + 1 do
					local w = r.w[i]
					if w and w > 0 then
						points[#points + 1] = {x = r.x[i], z = r.z[i], w = w}
					else
						if #points > 1 then result[#result + 1] = {id = r.id, points = points} end
						points = {}
					end
				end
			end
			return result
		end
		api.river_at, api.lake_at = river_at, lake_at
		api.rivers, api.lakes = layout.rivers, lakes
		api.segments = ns
		api.seg_river, api.seg_index = SRIV, SIDX
		return api
	end

	return M
end
