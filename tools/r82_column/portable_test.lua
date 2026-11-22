-- Round 82 lane COLUMN portable test (the per-column samplers,
-- docs/planning/round82-plan.md §4 COLUMN), on synthetic layouts, LuaJIT:
--   A. the road sampler (`road_layout.lua` sampler: flat point arrays, the
--      8-node column index, no sqrt beyond the side reach) answers every
--      column exactly as the full walk over the 32-node buckets before
--      Round 82 (kept below as the reference), at three terrain heights,
--      dry and wet: a straight road, a winding road, a junction, a crossing,
--      a doubled road (the first of two equal distances wins), a road with a
--      repeated point, deck and bridge runs next to ground and road ends on
--      bucket edges at negative coordinates; `near` at pads 2 and 30 too;
--   B. the water sampler's nearest-segment walk on squared distances
--      (`water_layout.lua` river_at) answers every column exactly as the
--      walk on distances before Round 82 (the reference, over the sampler's
--      own buckets), including a segment earlier in the list whose square is
--      one ulp larger with the same root (the first one stays the nearest)
--      and the spring fade of a gully;
--   C. the vegetation rule's lattice corner memo (`habitat_registry.lua`):
--      the factors of a grid in row order and in a scattered order agree;
--   D. the cost, printed: the reference and the new road and river walks
--      over the same columns (best of three, CPU seconds).
-- Usage (repo root): luajit tools/r82_column/portable_test.lua [REPO]
-- The samplers on real worlds, base against branch: tools/r82_column/compare.sh.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local floor, sqrt, min, max, exp = math.floor, math.sqrt, math.min, math.max, math.exp
local function fmt(v)
	if type(v) == "number" then return ("%.17g"):format(v) end
	if type(v) == "table" then
		return ("{%s,%s,%s,%s,%s}"):format(tostring(v.class), tostring(v.bridge),
			tostring(v.pillar), tostring(v.rail), tostring(v.base))
	end
	return tostring(v)
end
local function pack(...)
	local parts = {}
	for index = 1, select("#", ...) do parts[index] = fmt((select(index, ...))) end
	return table.concat(parts, " ")
end
local function best_of(fn)
	local best = math.huge
	for _ = 1, 3 do
		local c0 = os.clock()
		fn()
		best = min(best, os.clock() - c0)
	end
	return best
end

-------------------------------------------------------------------------------
-- A. Roads
-------------------------------------------------------------------------------
local roads_module = dofile(wp40 .. "/road_layout.lua")
local P = roads_module.P
local INF = math.huge

-- The sampler's column walk before Round 82 (road_layout.lua at 3112817e),
-- over the 32-node buckets of segment codes.
local function reference_sampler(layout)
	local BUCKET, SIDE = P.BUCKET, P.SIDE_MAX
	local function bkey(bx, bz) return bz * 8192 + bx end
	local buckets, bridge_at, straight_at = {}, {}, {}
	for _, r in ipairs(layout.roads) do
		bridge_at[r.id] = roads_module.bridge_points(r.cls)
		if r.kind == "avenue" or r.kind == "lane" then
			straight_at[r.id] = roads_module.straight_points(r.X, r.Z)
		end
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
			local rx, rz = x - px, z - pz
			local d = sqrt(rx * rx + rz * rz)
			local e = d - r.hw
			if e < best then best, br, bi, bu = e, r, i, u end
			if e > 0 and e <= SIDE then
				local idx = u < 0.5 and i or i + 1
				local ry = r.R[i] + u * (r.R[i + 1] - r.R[i])
				local c = r.cls[idx]
				local wh = min(P.WALL_H, max(0, t - ry - P.WALL_MIN))
				local ee = max(0, e - 1)
				local cap = ry + wh + min(ee, P.CUT_SOIL) * P.CUT_SLOPE +
					max(0, ee - P.CUT_SOIL) * P.CUT_ROCK +
					min(e, 1) * (1 - wh / P.WALL_H) * P.CUT_SLOPE
				-- Round 86 ROADS: the cut meets the ground at the side zone's
				-- edge (CUT_FADE), a rule of the answer, not of the walk
				cap = max(cap, min(t - P.CUT_FADE * (SIDE - e), cap + P.CUT_FADE_LIFT * e * e))
				local walled = wh > 0 and e <= 1.5
				if cap < cut_cap then
					cut_cap, wall_at = cap, walled
					wall_base = walled and floor(ry) + 1 or nil
				end
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
			local top = floor(ry)
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
				local straight = straight_at[br.id]
				extra.rail = straight ~= nil and straight[idx] == true and
					best > -1 and ry - t >= 2
			end
			local newt = t
			if kind == "cut" or kind == "fill" or kind == "grade" then newt = top end
			if kind == "ford" then newt = top end
			return "surface", ry, newt, br.id, idx, extra
		end
		if t > cut_cap then
			local nt = floor(cut_cap)
			if nt < t then
				if wall_at then return "wall", nil, nt, nil, nil, {base = wall_base} end
				return "cutslope", nil, nt
			end
		end
		if t < fill_floor and not (wy and wy > t) then
			local nt = floor(fill_floor + 0.5)
			if nt - t > P.EMB_TOE then return nil end
			return (nt - t >= 2 and "embwall" or "embslope"), nil, nt
		end
		return nil
	end
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
	return {column = column, near = near}
end

-- Synthetic roads with points about a node apart, written and read through
-- the layout's own text as main and emerge do. `profile(i)` is the road
-- level in 1/Q node (integer steps under 32).
local road_rows = {}
local function add_road(kind, points, profile, classes)
	local id = #road_rows + 1
	local X, Z, RQ, cls = {}, {}, {}, {}
	for i, p in ipairs(points) do
		X[i], Z[i] = p[1], p[2]
		RQ[i] = profile(i)
		cls[i] = classes and classes(i, #points) or "G"
	end
	road_rows[id] = {id = id, kind = kind, X = X, Z = Z, RQ = RQ, cls = cls,
		a = "a" .. id, b = "b" .. id}
end
local function line(x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	local n = math.ceil(sqrt(dx * dx + dz * dz))
	local pts = {}
	for i = 0, n do pts[#pts + 1] = {x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n} end
	return pts
end
-- a straight primary road along x, a winding secondary crossing it, a trail
-- ending on it (a junction), a doubled avenue (two equal roads), a lane with
-- a repeated point, and a road ending on a bucket corner at negative
-- coordinates; decks and a bridge between ground runs
add_road("primary", line(-200, -64, 120, -64), function(i) return 192 + 4 * math.abs(i % 34 - 17) end,
	function(i) if i >= 60 and i < 70 then return "D" elseif i >= 120 and i < 126 then return "B" end return "G" end)
do
	local pts = {}
	for i = 0, 700 do
		local s = i / 700
		pts[#pts + 1] = {-150 + 260 * s + 30 * math.sin(s * 9), -180 + 240 * s + 40 * math.cos(s * 7)}
	end
	add_road("secondary", pts, function(i) return floor(128 + 96 * math.sin(i / 23)) end,
		function(i, n) if i == 1 or i == n then return "D" end return "G" end)
end
add_road("trail", line(-40, -20, -40, -63.5), function() return 248 end)
add_road("avenue", line(-96, 32, 64, 32), function(i) return 320 + i end,
	function(i) if i > 40 and i < 50 then return "D" end return "G" end)
add_road("avenue", line(-96, 32, 64, 32), function(i) return 320 + i end,
	function(i) if i > 40 and i < 50 then return "D" end return "G" end)
do
	local pts = line(-128, 96, -32, 96)
	table.insert(pts, 30, {pts[30][1], pts[30][2]})
	add_road("lane", pts, function(i) return 480 - 2 * i end)
end
add_road("primary", line(-160, -160, -128, -128), function() return 64 end,
	function(i, n) if i == n then return "B" end return "G" end)
-- through the layout's own text, as main and emerge read it
local layout_text = roads_module.serialize({roads = road_rows})
local new_sampler = roads_module.sampler(roads_module.deserialize(layout_text))
local old_sampler = reference_sampler(roads_module.deserialize(layout_text))
local road_columns = {}
for z = -230, 160 do
	for x = -260, 180 do road_columns[#road_columns + 1] = {x, z} end
end
do
	local differ, answered = 0, 0
	for _, c in ipairs(road_columns) do
		local x, z = c[1], c[2]
		for _, t in ipairs({2, 14, 27}) do
			for _, wy in ipairs({false, t + 1}) do
				local a = pack(old_sampler.column(x, z, t, wy or nil))
				local b = pack(new_sampler.column(x, z, t, wy or nil))
				if a ~= b then
					differ = differ + 1
					if differ <= 3 then print("road differs", x, z, t, wy, a, "|", b) end
				end
				if a ~= "nil" and a ~= "" then answered = answered + 1 end
			end
		end
		for _, pad in ipairs({2, 30}) do
			if old_sampler.near(x, z, pad) ~= new_sampler.near(x, z, pad) then
				differ = differ + 1
			end
		end
	end
	check(differ == 0, "A every road answer equals the full walk")
	check(answered > 50000, "A the roads answer many columns (" .. answered .. ")")
	print(("A road answers: %d columns x 6, %d non-nil, 0 differ"):format(#road_columns,
		answered))
end

-------------------------------------------------------------------------------
-- B. Water
-------------------------------------------------------------------------------
local terrain_data = dofile(wp40 .. "/terrain_data.lua")
local terrain_field = dofile(wp40 .. "/terrain_field.lua")(terrain_data)
local water_module = dofile(wp40 .. "/water_layout.lua")(terrain_data.water)
local WP = water_module.P
local function river(id, xs, zs, w, level, R, D, V, parent)
	local r = {id = id, x = xs, z = zs, w = {}, level = {}, R = {}, D = {}, V = {},
		drains = {}, parent = parent}
	for i = 1, #xs do
		r.w[i], r.level[i] = w(i), level(i)
		r.R[i], r.D[i], r.V[i] = R(i), D(i), V(i)
	end
	return r
end
local rivers = {}
do
	-- a winding river with a gully at its spring (w < 0 then > 0), a
	-- tributary joining it, and the one-ulp pair: an earlier segment whose
	-- nearest point lies at the square 4 + 2^-50 of column (0, 0) and a
	-- later one at 4 (both roots 2)
	local xs, zs = {}, {}
	for i = 0, 120 do xs[#xs + 1] = -300 + 5 * i; zs[#zs + 1] = 60 * math.sin(i / 11) + 0.25 end
	rivers[1] = river(1, xs, zs, function(i) return i < 12 and -2 or 3 + i / 20 end,
		function(i) return 30 - i * 0.2 end, function(i) return 20 + (i % 9) * 3 end,
		function(i) return 2 + (i % 5) * 0.5 end, function(i) return (i % 4) / 4 end)
	local tx, tz = {}, {}
	for i = 0, 40 do tx[#tx + 1] = -60 + 2 * i; tz[#tz + 1] = 180 - 4 * i end
	rivers[2] = river(2, tx, tz, function() return 2 end, function(i) return 26 - i * 0.1 end,
		function() return 14 end, function() return 1.5 end, function() return 0.5 end, 1)
	rivers[3] = river(3, {2, 2}, {1 / 33554432, 1}, function() return 1 end, function() return 5 end,
		function() return 9 end, function() return 1 end, function() return 0 end)
	rivers[4] = river(4, {2, 2}, {0, -1}, function() return 1 end, function() return 4 end,
		function() return 30 end, function() return 1 end, function() return 0 end)
end
local water_layout = {nx = 4, nz = 4, lakes = {}, rivers = rivers, mask = {}}
local water = water_module.sampler(water_layout, "12345", terrain_field.simplex)
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
-- river_at before Round 82, over the sampler's own buckets and arrays
local reference_river_at
do
	local ra = water.river_at
	local U = {}
	for _, name in ipairs({"buckets", "SAX", "SAZ", "SVX", "SVZ", "SL2", "SWET", "SRIV",
			"SLV", "SLW", "SW0", "SW1", "SR0", "SR1", "SD0", "SD1", "SV0", "SV1", "SL0",
			"SL1", "REACH", "BUCKET", "K"}) do
		U[name] = upvalue(ra, name)
	end
	local function smoothstep(a, b, x)
		local t = (x - a) / (b - a)
		if t <= 0 then return 0 elseif t >= 1 then return 1 end
		return t * t * (3 - 2 * t)
	end
	local ds, ws = {}, {}
	reference_river_at = function(x, z)
		local list = U.buckets[floor(z / U.BUCKET) * 4096 + floor(x / U.BUCKET)]
		if not list then return nil end
		local dmin, best, dwet = math.huge, nil, math.huge
		local cnt = #list
		for j = 1, cnt do
			local s = list[j]
			local ox, oz = x - U.SAX[s], z - U.SAZ[s]
			local t = (ox * U.SVX[s] + oz * U.SVZ[s]) / U.SL2[s]
			if t < 0 then t = 0 elseif t > 1 then t = 1 end
			local ex, ez = ox - t * U.SVX[s], oz - t * U.SVZ[s]
			local d = sqrt(ex * ex + ez * ez)
			ds[j], ws[j] = d, t
			if d < dmin then dmin, best = d, j end
			if U.SWET[s] and d < dwet then dwet = d end
		end
		if dmin > U.REACH then return nil end
		local K = U.K
		local sw, sW, sL, sR, sD, sV, sWL = 0, 0, 0, 0, 0, 0, 0
		local rv, sws, sLs = U.SRIV[list[best]], 0, 0
		local lim = dmin + 4 * K
		for j = 1, cnt do
			local d = ds[j]
			if d < lim then
				local s = list[j]
				local wt = exp(-(d - dmin) / K)
				local t = ws[j]
				sw = sw + wt
				sW = sW + wt * (U.SW0[s] + (U.SW1[s] - U.SW0[s]) * t)
				sL = sL + wt * U.SLV[s]
				if U.SRIV[s] == rv then sws, sLs = sws + wt, sLs + wt * U.SLV[s] end
				sR = sR + wt * (U.SR0[s] + (U.SR1[s] - U.SR0[s]) * t)
				sD = sD + wt * (U.SD0[s] + (U.SD1[s] - U.SD0[s]) * t)
				sV = sV + wt * (U.SV0[s] + (U.SV1[s] - U.SV0[s]) * t)
				sWL = sWL + wt * (U.SL0[s] + (U.SL1[s] - U.SL0[s]) * t)
			end
		end
		local s = list[best]
		local Dv, WL = sD / sw, sWL / sw
		if not U.SWET[s] then
			local f = 1 - smoothstep(0, 6, dwet - dmin)
			Dv, WL = Dv * f, WL * f
		end
		return dmin, sW / sw, sL / sw, U.SLW[s], s, sR / sw, Dv, sV / sw, WL, sLs / sws
	end
	check(U.REACH == WP.R_MAX * (1 + WP.TROUGH_WOBBLE) + 4 * WP.BLEND_K + 2,
		"B the reference reads the sampler's reach")
end
local water_columns = {}
for z = -260, 260 do
	for x = -520, 340 do water_columns[#water_columns + 1] = {x, z} end
end
do
	local differ, near = 0, 0
	for _, c in ipairs(water_columns) do
		local a = pack(reference_river_at(c[1], c[2]))
		local b = pack(water.river_at(c[1], c[2]))
		if a ~= b then
			differ = differ + 1
			if differ <= 3 then print("river differs", c[1], c[2], a, "|", b) end
		end
		if a ~= "" and a ~= "nil" then near = near + 1 end
	end
	check(differ == 0, "B every river answer equals the walk on distances")
	check(near > 100000, "B many columns lie within the reach (" .. near .. ")")
	local _, _, _, _, seg = water.river_at(0, 0)
	local _, _, _, _, ref = reference_river_at(0, 0)
	local list = upvalue(water.river_at, "buckets")[0]
	local first
	for j = 1, #list do
		if upvalue(water.river_at, "SRIV")[list[j]] == 3 then first = list[j] break end
	end
	check(seg == ref and seg == first, "B the one-ulp pair: the earlier segment stays nearest")
	print(("B river answers: %d columns, %d within the reach, 0 differ"):format(
		#water_columns, near))
end

-------------------------------------------------------------------------------
-- C. The lattice corner memo
-------------------------------------------------------------------------------
do
	local habitat = dofile(wp40 .. "/habitat_registry.lua")
	local function zone(x, z)
		local k = (floor(x / 700) + floor(z / 600)) % 5
		return k > 0 and ("z" .. k) or nil
	end
	local rows = habitat.vegetation_rule("12345", zone)
	local scattered = habitat.vegetation_rule("12345", zone)
	local cols = {}
	for z = -300, 299, 3 do for x = -400, 399, 2 do cols[#cols + 1] = {x, z} end end
	local answers = {}
	for index, c in ipairs(cols) do
		answers[index] = pack(rows.factors(c[1], c[2], (c[1] + c[2]) % 120, "grug_crags", "z1"))
	end
	local differ = 0
	local index, n = 1, #cols
	for _ = 1, n do
		index = (index * 7919) % n + 1
		local c = cols[index]
		if pack(scattered.factors(c[1], c[2], (c[1] + c[2]) % 120, "grug_crags", "z1")) ~=
				answers[index] then
			differ = differ + 1
		end
	end
	check(differ == 0, "C the factors do not depend on the query order")
end

-------------------------------------------------------------------------------
-- D. The cost
-------------------------------------------------------------------------------
do
	local road_old = best_of(function()
		for _, c in ipairs(road_columns) do old_sampler.column(c[1], c[2], 14, nil) end
	end)
	local road_new = best_of(function()
		for _, c in ipairs(road_columns) do new_sampler.column(c[1], c[2], 14, nil) end
	end)
	local river_old = best_of(function()
		for _, c in ipairs(water_columns) do reference_river_at(c[1], c[2]) end
	end)
	local river_new = best_of(function()
		for _, c in ipairs(water_columns) do water.river_at(c[1], c[2]) end
	end)
	print(("D road column walk: before %.3f s, after %.3f s (%d columns)"):format(road_old,
		road_new, #road_columns))
	print(("D river walk: before %.3f s, after %.3f s (%d columns)"):format(river_old,
		river_new, #water_columns))
end

print(("R82 COLUMN PORTABLE PASS checks=%d"):format(checks))
