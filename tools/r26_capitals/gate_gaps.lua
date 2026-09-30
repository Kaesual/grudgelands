-- Round 26 Lane W (playtest fix): wall-gatehouse gaps and walls dipping into
-- a river, portably (LuaJIT).
--
--   luajit tools/r26_capitals/gate_gaps.lua <repo> --layouts FILE ...
--   luajit tools/r26_capitals/gate_gaps.lua <repo> <out.tsv> seed [seed ...]
--
-- Builds every capital's city edge with the SHIPPED writer of <repo>
-- (`r7_capital_blueprint.source` -> `wp13/city_edge.lua`) and measures round
-- each gate (within GATE_REACH of the gatehouse's larger half extent):
--   gap   -- columns on the wall's centre line outside the gatehouse box (and
--            off the civic lake's open stretch and its ends) that carry no
--            edge cell: a gap between the wall and the gatehouse;
--   leak  -- gates where a walker gets from the city side to the field side
--            round the gatehouse (4-connected, the gatehouse box closed, a
--            column closed when it carries an edge cell above its ground);
--            gates with a civic lake point in reach are not tested;
--   off   -- gates whose box holds no wall point (the wall passes it by);
--   road  -- (seeds only) centre-line columns next to a gatehouse that a road
--            or street surface keeps open (the writer never builds over one;
--            the avenue through the passage is inside the box, so these are
--            other roads crossing the wall beside the gate).
-- The edge is written without roads, so `gap` and `leak` are the wall and
-- the gatehouse alone. With --layouts (render.lua's layout files) the ground
-- is synthetic (the nearest wall point's walk less the walk height, the
-- gatehouse box at its floor); with seeds it plans each seed
-- (tools/r26_capitals/world.lua, the planner of <repo>) and writes on the
-- seed's final ground and water, and also measures the wall over water:
--   dip   -- runs of wall points over water (off the civic lake and its
--            walled shore points; runs at most DIP_MERGE dry points apart
--            count as one, so a V touching the far bank is one) whose dry
--            neighbours lie on the SAME bank (4-connected dry land in the
--            run's box + 4): the wall dips into the water and back;
--   cross -- runs whose dry neighbours lie on opposite banks (an arcade over
--            a river crossing the outline: intended).
-- and, as a guard on the outline changes, the planner's plots:
--   named -- named (non-fill) plots left out;  req -- required plots missing
--            (a load failure in the engine); lake -- wall points on the civic
--            lake's open stretch (per capital only).
-- One TSV line per seed:
--   seed gap caps_with_gaps leak off road dip cross named req open float fgate hang
--   key[gates=..;cols=N;leak=..;off=..;road=N;dip=N;cross=N;named=N;req=N;lake=N;
--       open=N;openk=kind:N,..;line=N;linek=kind:N,..;float=N;fgate=N;hang=N] ...
-- (open, float, fgate and hang: Round 27, see the whole-edge block below)
-- Prints a summary and never fails: it measures.
local repo = arg[1]
assert(repo and arg[2], "usage: gate_gaps.lua <repo> (--layouts FILE ... | <out.tsv> seed ...)")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local planner = dofile(wp40 .. "/capital_planner.lua")
local blueprint = dofile(wp40 .. "/r7_capital_blueprint.lua")
local floor, sqrt, abs, max, min = math.floor, math.sqrt, math.abs, math.max, math.min
local KEY = {anchor_007 = "dur_brannoc", anchor_008 = "highcourt", anchor_009 = "lethariel",
	anchor_010 = "nhal_veyr", anchor_011 = "gor_drazhak", anchor_012 = "kezamba"}
local GATE_REACH = 14   -- beyond the gatehouse's larger half extent
local DIP_MERGE = 12    -- wet runs at most this many dry wall points apart are one excursion

-- S: the planned seed's session (final ground, water, roads) or nil
local function check_layout(text, S)
	local L = planner.deserialize(text)
	local key = KEY[L.anchor.id]
	local cfg = blueprint.CAPITALS[key]
	local dims = planner.EDGE[cfg.edge]
	local source = blueprint.source(key, L, text)
	local AX, AZ = L.anchor.x, L.anchor.z
	local edge = source.overlay.make({x = AX, z = AZ})
	local W = L.wall
	local n = #W.pts
	local height = dims.opts.WALL_HEIGHT
	local function in_box(g, lx, lz)
		local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
		local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
		return abs(dd) <= dims.depth + 0.5 and abs(ww) <= dims.width + 0.5
	end
	local ground_of = {}
	local function column(x, z)
		local lx, lz = x - AX, z - AZ
		local k = x .. ":" .. z
		if S then
			local t = S.terrain_height_at(x, z)
			local wy = S.water_surface_at(x, z)
			if wy and wy <= t then wy = nil end
			ground_of[k] = t
			return t, wy, false
		end
		for c = 1, 4 do
			local g = L.gates[c]
			local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
			local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
			if abs(dd) <= dims.depth + 1 and abs(ww) <= dims.width + 1 then
				ground_of[k] = g.y
				return g.y, nil, false
			end
		end
		local best, bi
		for i = 1, n do
			local dx, dz = lx - W.pts[i][1], lz - W.pts[i][2]
			local d = dx * dx + dz * dz
			if not best or d < best then best, bi = d, i end
		end
		local y = floor(W.walk[bi] / 2) - height
		ground_of[k] = y
		return y, nil, false
	end
	local out = {key = key, gates = {}, cols = 0, leaks = {}, offs = {}, road = 0, dip = 0, cross = 0, lake = 0}
	for i = 1, n do if W.lake[i] then out.lake = out.lake + 1 end end
	local R = max(dims.depth, dims.width) + GATE_REACH
	for c = 1, 4 do
		local g = L.gates[c]
		local gx, gz = floor(AX + g.x + 0.5), floor(AZ + g.z + 0.5)
		local box = {min_x = gx - R - 4, max_x = gx + R + 4, min_z = gz - R - 4, max_z = gz + R + 4}
		local cells = edge.cells(box, column)
		local present, closed = {}, {}
		for _, cell in ipairs(cells) do
			if cell.name ~= "air" then
				local k = cell.x .. ":" .. cell.z
				present[(cell.x - AX) .. ":" .. (cell.z - AZ)] = true
				if cell.y >= ground_of[k] + 1 then closed[k] = true end
			end
		end
		-- gap (and road) columns on the centre line
		local missing, roadcols, seen, inside, lake_near = 0, 0, {}, 0, false
		for i = 1, n do
			local p = W.pts[i]
			local rx, rz = p[1] - g.x, p[2] - g.z
			if rx * rx + rz * rz <= (R + 2) * (R + 2) then
				if W.lake[i] then lake_near = true end
				if in_box(g, p[1], p[2]) then inside = inside + 1 end
			end
			local j = i % n + 1
			if not (W.lake[i] or W.lake[j]) then
				local a, b = W.pts[i], W.pts[j]
				local ux, uz = b[1] - a[1], b[2] - a[2]
				local len = sqrt(ux * ux + uz * uz)
				local steps = max(1, floor(len / 0.25))
				for s = 0, steps do
					local t = s / steps
					local x, z = a[1] + t * ux, a[2] + t * uz
					local qx, qz = x - g.x, z - g.z
					if qx * qx + qz * qz <= R * R and not in_box(g, x, z) then
						local cx, cz = floor(x + 0.5), floor(z + 0.5)
						local k = cx .. ":" .. cz
						if not seen[k] then
							seen[k] = true
							if not present[k] then
								missing = missing + 1
								io.stderr:write(("  gap %s gate %s at %d,%d\n"):format(key, g.name, AX + cx, AZ + cz))
							end
							if S and S.road_column_at(AX + cx, AZ + cz) == "surface" then
								roadcols = roadcols + 1
							end
						end
					end
				end
			end
		end
		if missing > 0 then
			out.gates[#out.gates + 1] = g.name
			out.cols = out.cols + missing
		end
		out.road = out.road + roadcols
		if inside == 0 then out.offs[#out.offs + 1] = g.name end
		-- leak: the city side to the field side round the gatehouse
		if not lake_near then
			local function free(x, z)
				if abs(x - gx) > R or abs(z - gz) > R then return false end
				if closed[x .. ":" .. z] then return false end
				return not in_box(g, x - AX, z - AZ)
			end
			local reached, queue = {}, {}
			local targets = {}
			for dd = dims.depth + 2, R - 1 do
				for ww = -1, 1 do
					local ix = floor(AX + g.x - g.dx * dd - g.dz * ww + 0.5)
					local iz = floor(AZ + g.z - g.dz * dd + g.dx * ww + 0.5)
					local ox = floor(AX + g.x + g.dx * dd - g.dz * ww + 0.5)
					local oz = floor(AZ + g.z + g.dz * dd + g.dx * ww + 0.5)
					if free(ix, iz) and not reached[ix .. ":" .. iz] then
						reached[ix .. ":" .. iz] = true
						queue[#queue + 1] = {ix, iz}
					end
					if free(ox, oz) then targets[ox .. ":" .. oz] = true end
				end
			end
			local head, leak = 1, false
			while head <= #queue and not leak do
				local q = queue[head]
				head = head + 1
				if targets[q[1] .. ":" .. q[2]] then leak = true end
				for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local x, z = q[1] + d[1], q[2] + d[2]
					local k = x .. ":" .. z
					if not reached[k] and free(x, z) then
						reached[k] = true
						queue[#queue + 1] = {x, z}
					end
				end
			end
			if leak then out.leaks[#out.leaks + 1] = g.name end
		end
	end
	-- the wall over water (seeds only): runs of wet points off the civic lake
	-- (its open stretch `l` and the walled points by it `f`: the heads the
	-- wall runs into the lake by design)
	if S then
		local function wet(x, z)
			local t = S.terrain_height_at(x, z)
			local wy = S.water_surface_at(x, z)
			return wy ~= nil and wy > t
		end
		local wetp = {}
		for i = 1, n do
			local p = W.pts[i]
			wetp[i] = not W.lake[i] and not W.gap[i] and not W.foot[i] and
				wet(AX + floor(p[1] + 0.5), AZ + floor(p[2] + 0.5))
		end
		-- start the cyclic scan on a dry point
		local s0
		for i = 1, n do if not wetp[i] then s0 = i break end end
		if s0 then
			local k = 0
			while k < n do
				local i = (s0 - 1 + k) % n + 1
				if wetp[i] then
					local first, len = i, 0
					while wetp[(first - 1 + len) % n + 1] and len < n do len = len + 1 end
					-- a wet run a short dry stretch after this one (a V whose
					-- tip touches the far bank) belongs to the same excursion
					while k + len < n do
						local dry = 0
						while k + len + dry < n and not wetp[(first - 1 + len + dry) % n + 1] do
							dry = dry + 1
						end
						if dry > DIP_MERGE or k + len + dry >= n then break end
						len = len + dry
						while k + len < n and wetp[(first - 1 + len) % n + 1] do len = len + 1 end
					end
					local pa = W.pts[(first - 2) % n + 1]
					local pb = W.pts[(first - 1 + len) % n + 1]
					local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
					for m = -1, len do
						local p = W.pts[(first - 1 + m) % n + 1]
						x0, x1 = min(x0, p[1]), max(x1, p[1])
						z0, z1 = min(z0, p[2]), max(z1, p[2])
					end
					x0, x1 = floor(AX + x0) - 4, floor(AX + x1) + 5
					z0, z1 = floor(AZ + z0) - 4, floor(AZ + z1) + 5
					local ax, az = AX + floor(pa[1] + 0.5), AZ + floor(pa[2] + 0.5)
					local bx, bz = AX + floor(pb[1] + 0.5), AZ + floor(pb[2] + 0.5)
					local reached, queue, head, same = {[ax .. ":" .. az] = true}, {{ax, az}}, 1, false
					while head <= #queue and not same do
						local q = queue[head]
						head = head + 1
						if q[1] == bx and q[2] == bz then same = true end
						for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
							local x, z = q[1] + d[1], q[2] + d[2]
							local kk = x .. ":" .. z
							if x >= x0 and x <= x1 and z >= z0 and z <= z1 and not reached[kk] and
									not wet(x, z) then
								reached[kk] = true
								queue[#queue + 1] = {x, z}
							end
						end
					end
					if same then
						out.dip = out.dip + 1
						io.stderr:write(("  dip %s: %d wall points over water from %d,%d to %d,%d\n"):format(
							key, len, ax, az, bx, bz))
					else
						out.cross = out.cross + 1
					end
					k = k + len
				else
					k = k + 1
				end
			end
		end
	end
	-- Round 27 (seeds only): the WHOLE edge as the shipped writer builds it
	-- on the seed's final ground, water and real roads.
	--   open  -- wall centre-line columns (off the civic lake's open stretch,
	--            outside every gatehouse box) a walker reaches from inside
	--            AND from outside the city through the wall band (dry, no
	--            edge cell above the ground; see the flood below): an opening
	--            in the wall away from a gatehouse, by the road kind on it;
	--   line  -- road or square surface columns on that centre line (built
	--            over or not), by road kind;
	--   float -- dry columns whose lowest edge cell stands above the ground
	--            (y > ground + 1): unsupported. A gatehouse passage column is
	--            a lintel, supported when a grounded tower column (no air in
	--            it) stands in its row on both sides; `fgate` counts the
	--            unsupported ones inside a gatehouse box;
	--   hang  -- the same over water (the arcade's arches and the palisade's
	--            deck between piles: by design), for information.
	if S then
		out.open, out.float, out.fgate, out.hang, out.line = 0, 0, 0, 0, 0
		out.openk, out.linek = {}, {}
		local B = edge.bounds
		local gr, wet_of, rk = {}, {}, {}
		local cells = edge.cells({min_x = AX + B.min_x, max_x = AX + B.max_x,
			min_z = AZ + B.min_z, max_z = AZ + B.max_z}, function(x, z)
			local t = S.terrain_height_at(x, z)
			local wy = S.water_surface_at(x, z)
			if wy and wy <= t then wy = nil end
			local kind, _, _, _, _, _, _, rkind = S.road_column_at(x, z)
			local k = x .. ":" .. z
			gr[k], wet_of[k] = t, wy ~= nil
			if kind == "surface" then rk[k] = rkind or "road" end
			return t, wy, kind == "surface"
		end)
		local lo, top, airy = {}, {}, {}
		for _, c in ipairs(cells) do
			local k = c.x .. ":" .. c.z
			if c.name == "air" then airy[k] = true
			else
				if not lo[k] or c.y < lo[k] then lo[k] = c.y end
				if not top[k] or c.y > top[k] then top[k] = c.y end
			end
		end
		local function grounded(k) return lo[k] ~= nil and lo[k] <= gr[k] + 1 end
		local function gate_at(lx, lz)
			for c = 1, 4 do
				local g = L.gates[c]
				if in_box(g, lx, lz) then
					local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
					local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
					return g, floor(dd + 0.5), floor(ww + 0.5)
				end
			end
			return nil
		end
		-- line: road or square surface columns on the wall's centre line
		local seen = {}
		for i = 1, n do
			local j = i % n + 1
			if not (W.lake[i] or W.lake[j]) then
				local a, b = W.pts[i], W.pts[j]
				local ux, uz = b[1] - a[1], b[2] - a[2]
				local len = sqrt(ux * ux + uz * uz)
				local steps = max(1, floor(len / 0.25))
				for s = 0, steps do
					local t = s / steps
					local x, z = a[1] + t * ux, a[2] + t * uz
					if not gate_at(x, z) then
						local cx, cz = floor(x + 0.5), floor(z + 0.5)
						local k = (AX + cx) .. ":" .. (AZ + cz)
						if not seen[k] and gr[k] then
							seen[k] = true
							local kind = rk[k]
							if kind then
								out.line = out.line + 1
								out.linek[kind] = (out.linek[kind] or 0) + 1
							end
						end
					end
				end
			end
		end
		-- open: a walker's way through the wall band. The band is every
		-- column within BAND of the wall polyline; a band column is free when
		-- it is dry, outside every gatehouse box, not nearest to the civic
		-- lake's open stretch and carries no edge cell above its ground. One flood from the band's inner rim, one from its outer
		-- rim (4-connected, inside the band); the centre-line columns (within
		-- 0.75 of the polyline) both reach are the opening.
		local BAND = dims.half + 4
		local BK = 8
		local bk = {}
		for i = 1, n do
			local a, b = W.pts[i], W.pts[i % n + 1]
			for bz = floor((min(a[2], b[2]) - BAND - 1) / BK), floor((max(a[2], b[2]) + BAND + 1) / BK) do
				for bx = floor((min(a[1], b[1]) - BAND - 1) / BK), floor((max(a[1], b[1]) + BAND + 1) / BK) do
					local kk = bz * 65536 + bx
					local l = bk[kk]
					if not l then l = {}; bk[kk] = l end
					l[#l + 1] = i
				end
			end
		end
		-- the side of a rim column: even-odd crossings of the closed wall
		-- polyline (a radius test misreads a wall stretch that runs radially)
		local function inside_wall(lx, lz)
			local c = false
			for i = 1, n do
				local a, b = W.pts[i], W.pts[i % n + 1]
				if (a[2] > lz) ~= (b[2] > lz) then
					local x = a[1] + (lz - a[2]) * (b[1] - a[1]) / (b[2] - a[2])
					if x > lx then c = not c end
				end
			end
			return c
		end
		-- every free band column is inside (i), outside (o) or on the centre
		-- line (c, within 0.75 of it); the rim is a free column at least
		-- WALL_HALF + 2 from the line
		local band, rim, centre = {}, {}, {}
		local x0, x1 = floor(B.min_x), floor(B.max_x)
		local z0, z1 = floor(B.min_z), floor(B.max_z)
		for lz = z0, z1 do
			for lx = x0, x1 do
				local l = bk[floor(lz / BK) * 65536 + floor(lx / BK)]
				if l then
					local best, bi
					for m = 1, #l do
						local i = l[m]
						local a, b = W.pts[i], W.pts[i % n + 1]
						local vx, vz = b[1] - a[1], b[2] - a[2]
						local l2 = vx * vx + vz * vz
						local u = l2 > 0 and ((lx - a[1]) * vx + (lz - a[2]) * vz) / l2 or 0
						if u < 0 then u = 0 elseif u > 1 then u = 1 end
						local dx, dz = lx - a[1] - u * vx, lz - a[2] - u * vz
						local d = sqrt(dx * dx + dz * dz)
						if not best or d < best then best, bi = d, i end
					end
					if best <= BAND then
						local k = (AX + lx) .. ":" .. (AZ + lz)
						local t = gr[k] or S.terrain_height_at(AX + lx, AZ + lz)
						local wy = S.water_surface_at(AX + lx, AZ + lz)
						-- the civic lake's open stretch is the edge by design:
						-- its band never connects the two sides
						local lake_seg = W.lake[bi] or W.lake[bi % n + 1]
						local closed = lake_seg or (wy ~= nil and wy > t) or gate_at(lx, lz) ~= nil or
							(top[k] ~= nil and top[k] >= t + 1)
						if not closed then
							if best <= 0.75 then
								band[k] = "c"
								centre[k] = {AX + lx, AZ + lz}
							else
								band[k] = inside_wall(lx, lz) and "i" or "o"
								if best >= dims.half + 2 then rim[k] = true end
							end
						end
					end
				end
			end
		end
		-- one flood from the inner rim through inside and centre columns, one
		-- from the outer rim through outside and centre columns (4-connected);
		-- an opening column is a centre column both reach, or an inside column
		-- next to an outside column the outer flood reached (a way through
		-- that steps across the line between two columns)
		local STEP = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		local function flood(which)
			local reached, queue, head = {}, {}, 1
			for k in pairs(rim) do
				if band[k] == which then reached[k] = true; queue[#queue + 1] = k end
			end
			table.sort(queue)
			while head <= #queue do
				local k = queue[head]
				head = head + 1
				local x, z = k:match("^(-?%d+):(-?%d+)$")
				x, z = tonumber(x), tonumber(z)
				for _, d in ipairs(STEP) do
					local k2 = (x + d[1]) .. ":" .. (z + d[2])
					local b2 = band[k2]
					if (b2 == which or b2 == "c") and not reached[k2] then
						reached[k2] = true
						queue[#queue + 1] = k2
					end
				end
			end
			return reached
		end
		local from_in, from_out = flood("i"), flood("o")
		local function opening(k, x, z)
			out.open = out.open + 1
			local why = rk[k] or "none"
			out.openk[why] = (out.openk[why] or 0) + 1
			io.stderr:write(("  open %s at %d,%d (%s)\n"):format(key, x, z, why))
		end
		for k, c in pairs(centre) do
			if from_in[k] and from_out[k] then opening(k, c[1], c[2]) end
		end
		for k in pairs(from_in) do
			if band[k] == "i" then
				local x, z = k:match("^(-?%d+):(-?%d+)$")
				x, z = tonumber(x), tonumber(z)
				for _, d in ipairs(STEP) do
					local k2 = (x + d[1]) .. ":" .. (z + d[2])
					if band[k2] == "o" and from_out[k2] then opening(k, x, z) break end
				end
			end
		end
		-- float and hang
		for k, l in pairs(lo) do
			if l > gr[k] + 1 then
				if wet_of[k] then
					out.hang = out.hang + 1
				else
					local x, z = k:match("^(-?%d+):(-?%d+)$")
					x, z = tonumber(x), tonumber(z)
					local g, dd, ww = gate_at(x - AX, z - AZ)
					local held = false
					if g and airy[k] then
						-- a lintel: grounded towers on both sides in its row
						local sx, sz = -g.dz, g.dx
						local function side(sg)
							for m = 1, 2 * dims.width + 1 do
								local w2 = ww + sg * m
								if abs(w2) > dims.width then return false end
								local k2 = (x + sg * m * sx) .. ":" .. (z + sg * m * sz)
								if gr[k2] and grounded(k2) and not airy[k2] then return true end
							end
							return false
						end
						held = side(1) and side(-1)
					end
					if not held then
						out.float = out.float + 1
						if g then out.fgate = out.fgate + 1 end
						io.stderr:write(("  float %s at %d,%d%s (lowest %d, ground %d)\n"):format(key, x, z,
							g and (" gate " .. g.name .. " dd " .. dd .. " ww " .. ww) or "", l, gr[k]))
					end
				end
			end
		end
	end
	return out
end

local function check_text(all, S, plans)
	local section = all:match("section capital %d+ %x+\n(.-)\nsection ") or all
	local texts, order = planner.split(section .. "\n")
	local res = {}
	for _, id in ipairs(order) do
		local r = check_layout(texts[id], S)
		local plan = plans and plans[r.key]
		r.named, r.req = 0, 0
		if plan then
			for _, p in ipairs(plan.left_out) do
				if not p.required and p.kind ~= "fill" then r.named = r.named + 1 end
			end
			r.req = #(plan.missing_required or {})
		end
		res[#res + 1] = r
	end
	return res
end

local function kinds(t)
	local keys, out = {}, {}
	for k in pairs(t or {}) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do out[#out + 1] = k .. ":" .. t[k] end
	return table.concat(out, ",")
end

local function line(tag, res)
	local total, caps, leaks, offs, road, dip, cross, named, req, parts = 0, 0, 0, 0, 0, 0, 0, 0, 0, {}
	local open, float, fgate, hang = 0, 0, 0, 0
	for _, r in ipairs(res) do
		total = total + r.cols
		if r.cols > 0 then caps = caps + 1 end
		leaks, offs = leaks + #r.leaks, offs + #r.offs
		road, dip, cross = road + r.road, dip + r.dip, cross + r.cross
		named, req = named + (r.named or 0), req + (r.req or 0)
		open, float, fgate, hang = open + (r.open or 0), float + (r.float or 0),
			fgate + (r.fgate or 0), hang + (r.hang or 0)
		parts[#parts + 1] = ("%s[gates=%s;cols=%d;leak=%s;off=%s;road=%d;dip=%d;cross=%d;named=%d;req=%d;lake=%d" ..
			";open=%d;openk=%s;line=%d;linek=%s;float=%d;fgate=%d;hang=%d]"):format(
			r.key, table.concat(r.gates, ","), r.cols, table.concat(r.leaks, ","), table.concat(r.offs, ","),
			r.road, r.dip, r.cross, r.named or 0, r.req or 0, r.lake,
			r.open or 0, kinds(r.openk), r.line or 0, kinds(r.linek), r.float or 0, r.fgate or 0, r.hang or 0)
	end
	return table.concat({tag, total, caps, leaks, offs, road, dip, cross, named, req,
		open, float, fgate, hang, table.concat(parts, " ")}, "\t")
end

if arg[2] == "--layouts" then
	for i = 3, #arg do
		local f = assert(io.open(arg[i]))
		local text = f:read("*a")
		f:close()
		print((line(arg[i], check_text(text))))
	end
else
	local W = dofile(here .. "/world.lua")(repo)
	local out = assert(io.open(arg[2], "a"))
	for i = 3, #arg do
		local ok, run = pcall(W.plan, arg[i])
		local l
		if ok then
			local ok2, res = pcall(check_text, run.text, run.session, run.plans)
			l = ok2 and line(arg[i], res) or (arg[i] .. "\tERROR\t" .. tostring(res):gsub("[\t\n]", " "))
		else
			l = arg[i] .. "\tERROR\t" .. tostring(run):gsub("[\t\n]", " ")
		end
		out:write(l, "\n")
		out:flush()
		io.stderr:write(l, "\n")
	end
	out:close()
end
