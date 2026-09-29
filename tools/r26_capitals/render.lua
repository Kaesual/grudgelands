-- Round 26 Lane W: plan the six capitals of one seed and write the render
-- inputs for tools/r26_capitals/render.py (LuaJIT, no engine).
--
--   luajit tools/r26_capitals/render.lua <repo> <seed> <out_dir> [capital ...]
--
-- <repo> is the tree whose mapgen is planned (main or a branch); <out_dir>
-- must exist (run.sh makes it). The output
-- is <out_dir>/<capital>.json (the plan: outline, wall, turrets, gates,
-- streets, squares, plots with their tier, left-out plots, statistics) and
-- <out_dir>/<capital>.layers (the final ground around the capital, one node
-- per pixel: terrain y, water surface, road class/kind, and the city edge the
-- shipped writer `wp13/city_edge.lua` builds there), plus
-- <out_dir>/timing.tsv (planner seconds per capital, from plan_all).
local repo, seed, out_dir = arg[1], arg[2], arg[3]
assert(repo and seed and out_dir, "usage: render.lua <repo> <seed> <out_dir> [capital ...]")
local only = {}
for i = 4, #arg do only[arg[i]] = true end
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local W = dofile(here .. "/world.lua")(repo)
local blueprint = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_capital_blueprint.lua")
local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min, math.abs

local t0 = os.clock()
local run = W.plan(seed)
local texts = W.planner.split(run.text .. "\n")
io.stderr:write(("seed %s: session %.1f s, planning total %.1f s\n"):format(seed,
	run.seconds.session, run.seconds.total))

-- minimal JSON
local function json(v, out)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			out[#out + 1] = "["
			for i = 1, #v do
				if i > 1 then out[#out + 1] = "," end
				json(v[i], out)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			for i, k in ipairs(keys) do
				if i > 1 then out[#out + 1] = "," end
				out[#out + 1] = ("%q:"):format(k)
				local val = v[k]
				if val == nil then val = v[tonumber(k)] end
				json(val, out)
			end
			out[#out + 1] = "}"
		end
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "null"
		elseif v == floor(v) and abs(v) < 1e15 then out[#out + 1] = ("%d"):format(v)
		else out[#out + 1] = ("%.3f"):format(v) end
	elseif t == "boolean" then
		out[#out + 1] = tostring(v)
	elseif t == "string" then
		out[#out + 1] = ("%q"):format(v):gsub("\\\n", "\\n")
	else
		out[#out + 1] = "null"
	end
	return out
end
local function write(path, s)
	local f = assert(io.open(path, "w"))
	f:write(s)
	f:close()
end

local timing = {}
for _, st in ipairs(run.stats) do timing[st.key] = st end

local CLASS = {grade = 1, cut = 2, fill = 3, deck = 4, bridge = 5, ford = 6}
local KIND = {cutslope = 7, wall = 8, embslope = 9, embwall = 10}
local RKIND = {primary = 1, secondary = 2, trail = 3, avenue = 4, lane = 5}
local S = run.session
local WIN = 280
local tsv = {}
for _, key in ipairs(run.order) do
	if not next(only) or only[key] then
		local plan, I = run.plans[key], run.inputs[key]
		local AX, AZ = plan.anchor.x, plan.anchor.z
		local st = plan.stats
		local tr = os.clock()
		-- layers: terrain, water surface (or -999), road code (class * 10 + kind)
		local N = 2 * WIN + 1
		local rows_t, rows_w, rows_r = {}, {}, {}
		for iz = 0, N - 1 do
			local rt, rw, rr = {}, {}, {}
			for ix = 0, N - 1 do
				local x, z = AX - WIN + ix, AZ - WIN + iz
				local t = S.terrain_height_at(x, z)
				local wy = S.water_surface_at(x, z)
				local kind, _, ty, class, _, _, _, rkind = S.road_column_at(x, z)
				local code = 0
				if kind == "surface" then code = (CLASS[class] or 1) * 10 + (RKIND[rkind] or 0)
				elseif kind then code = (KIND[kind] or 0) * 10 + (RKIND[rkind] or 0) end
				if ty then t = ty end
				rt[ix + 1] = t
				rw[ix + 1] = (wy and wy > t) and wy or -999
				rr[ix + 1] = code
			end
			rows_t[#rows_t + 1] = table.concat(rt, " ")
			rows_w[#rows_w + 1] = table.concat(rw, " ")
			rows_r[#rows_r + 1] = table.concat(rr, " ")
		end
		-- the city edge as the shipped writer builds it on this ground (the
		-- 4th layer, one code per column): 0 none, 1 wall face / parapet,
		-- 2 wall walk, 3 gatehouse tower, 4 gatehouse passage, 5 turret
		local rows_e = {}
		do
			local L = W.planner.deserialize(texts[plan.anchor.id])
			local edge = blueprint.source(key, L, texts[plan.anchor.id]).overlay.make({x = AX, z = AZ})
			local dims = W.planner.EDGE[L.kind]
			local cells = edge.cells({min_x = AX - WIN, max_x = AX + WIN, min_z = AZ - WIN,
				max_z = AZ + WIN}, function(x, z)
				local t = S.terrain_height_at(x, z)
				local wy = S.water_surface_at(x, z)
				if wy and wy <= t then wy = nil end
				return t, wy, S.road_column_at(x, z) == "surface"
			end)
			local top, air = {}, {}
			for _, c in ipairs(cells) do
				local k = (c.z - AZ + WIN) * N + (c.x - AX + WIN)
				if c.name == "air" then air[k] = true
				elseif not top[k] or c.y > top[k] then top[k] = c.y end
			end
			local function boxed(lx, lz)
				for g = 1, 4 do
					local G = L.gates[g]
					local dd = (lx - G.x) * G.dx + (lz - G.z) * G.dz
					local ww = -(lx - G.x) * G.dz + (lz - G.z) * G.dx
					if abs(dd) <= dims.depth + 0.5 and abs(ww) <= dims.width + 0.5 then return true end
				end
				return false
			end
			local function turret(lx, lz)
				local r = dims.turret or 0
				for _, i in ipairs(L.wall.turrets) do
					local p = L.wall.pts[i]
					local dx, dz = lx - p[1], lz - p[2]
					if dx * dx + dz * dz <= r * r + 1 then return true end
				end
				return false
			end
			for iz = 0, N - 1 do
				local re = {}
				for ix = 0, N - 1 do
					local k = iz * N + ix
					local code = 0
					if top[k] then
						local lx, lz = ix - WIN, iz - WIN
						if boxed(lx, lz) then code = air[k] and 4 or 3
						elseif turret(lx, lz) then code = 5
						else code = air[k] and 2 or 1 end
					end
					re[ix + 1] = code
				end
				rows_e[#rows_e + 1] = table.concat(re, " ")
			end
		end
		write(out_dir .. "/" .. key .. ".layers", ("%d %d %d\n"):format(N, AX - WIN, AZ - WIN) ..
			table.concat(rows_t, "\n") .. "\n" .. table.concat(rows_w, "\n") .. "\n" ..
			table.concat(rows_r, "\n") .. "\n" .. table.concat(rows_e, "\n") .. "\n")
		local raster_s = os.clock() - tr
		-- the plan
		local J = {key = key, seed = seed, anchor = {x = AX, z = AZ}, window = WIN,
			area = plan.area, edge = plan.wall.kind, P = {}, outline = {}, gates = {}, ends = {},
			streets = {}, squares = {}, plots = {}, left_out = {}, relaxed = plan.relaxed,
			turrets = {}, wall = {}, missing_required = plan.missing_required or {}}
		local dims = W.planner.EDGE[plan.wall.kind]
		J.dims = {half = dims.half, depth = dims.depth, width = dims.width, turret = dims.turret,
			model = dims.model}
		for _, k in ipairs({"WALL_HALF", "WALL_KEEP", "GATE_DEPTH", "GATE_WIDTH", "TARGET_AREA",
				"CORE", "HALF", "BAND"}) do
			J.P[k] = plan.P[k]
		end
		J.P.RINGS = plan.P.RINGS
		J.style = plan.P.NAME
		for a, r in ipairs(plan.R) do
			local ray = plan.rays[a]
			J.outline[#J.outline + 1] = {r * ray.c, r * ray.s}
		end
		local w = plan.wall
		for i, p in ipairs(w.pts) do
			J.wall[#J.wall + 1] = {p[1], p[2], w.gap[i] and 1 or 0, w.wet[i] and 1 or 0,
				w.lake and w.lake[i] and 1 or 0}
		end
		for _, t in ipairs(w.turrets) do
			J.turrets[#J.turrets + 1] = {t.x, t.z, t.kind or "turret"}
		end
		for _, g in ipairs(plan.gates) do
			J.gates[#J.gates + 1] = {name = g.name, x = g.x, z = g.z, dx = g.dx, dz = g.dz,
				bridge = g.bridge or false, slide = g.slide}
		end
		for _, e in ipairs(plan.ends) do J.ends[#J.ends + 1] = {e.x, e.z} end
		for _, r in ipairs(plan.streets) do
			local pts = {}
			for i = 1, #r.X, 3 do pts[#pts + 1] = {r.X[i] - AX, r.Z[i] - AZ} end
			pts[#pts + 1] = {r.X[#r.X] - AX, r.Z[#r.Z] - AZ}
			J.streets[#J.streets + 1] = {role = r.role or r.kind, hw = r.hw, pts = pts}
		end
		for _, q in ipairs(plan.squares) do J.squares[#J.squares + 1] = {q.x, q.z, q.r} end
		local kit = {}
		for _, p in ipairs(I.plots) do kit[p.id] = p end
		local nfill, nnamed, nreq = 0, 0, 0
		for _, p in ipairs(I.plots) do
			if p.required then nreq = nreq + 1 elseif p.kind == "fill" then nfill = nfill + 1
			else nnamed = nnamed + 1 end
		end
		local built = 96 * 96
		for _, p in ipairs(plan.plots) do
			if not p.stand_in then
				local b = kit[p.id].bounds
				local ex, ez = W.planner.rot(0, b.min.z, p.turns)
				local f = W.planner.FRONT[p.turns]
				local tier = p.required and "required" or (p.kind == "fill" and "fill" or "named")
				J.plots[#J.plots + 1] = {id = p.id, district = p.district, tier = tier,
					x0 = p.x + p.x0, x1 = p.x + p.x1, z0 = p.z + p.z0, z1 = p.z + p.z1,
					ex = p.x + ex, ez = p.z + ez, fx = f[1], fz = f[2],
					overflow = p.overflow or false, relaxed = p.relaxed or false}
				built = built + (p.x1 - p.x0 + 1) * (p.z1 - p.z0 + 1)
			end
		end
		for _, p in ipairs(plan.left_out) do
			J.left_out[#J.left_out + 1] = {id = p.id, tier = p.required and "required" or
				(p.kind == "fill" and "fill" or "named")}
		end
		if plan.canal then
			J.canal = {}
			for _, p in ipairs(plan.canal.pts) do J.canal[#J.canal + 1] = p end
		end
		local rmin, rmax = math.huge, 0
		for _, r in ipairs(plan.R) do rmin, rmax = min(rmin, r), max(rmax, r) end
		local tm = timing[key] or {}
		J.stats = {seconds = tm.seconds, sample = st.t.sample, streets_s = st.t.streets,
			placed = #J.plots, total = #I.plots, kit_required = nreq, kit_named = nnamed,
			kit_fill = nfill, overflowed = #st.overflowed, built_share = built / plan.area,
			rmin = rmin, rmax = rmax, wall_length = w.length, turrets = #w.turrets,
			open_arcs = st.open_arcs or 0, cross_lanes = st.cross_lanes or 0,
			squares = st.squares or 0, spokes = st.spokes or 0, plaza = st.plaza or false,
			no_route = st.no_route, failed = st.failed or 0,
			infeasible = tm.infeasible or 0, connector_failed = st.connector_failed or 0,
			raster_s = raster_s}
		write(out_dir .. "/" .. key .. ".json", table.concat(json(J, {})))
		tsv[#tsv + 1] = ("%s\t%s\t%.3f\t%.3f\t%.3f"):format(seed, key, tm.seconds or -1,
			st.t.sample or -1, st.t.streets or -1)
		io.stderr:write(("  %s: planner %.2f s, raster %.1f s, plots %d/%d, left out %d\n"):format(
			key, tm.seconds or -1, raster_s, #J.plots, #I.plots, #plan.left_out))
	end
end
write(out_dir .. "/timing.tsv", table.concat(tsv, "\n") .. "\n")
-- the capital layout text in the world layout file's section format, for
-- tools/wp13/capital_walls_probe.lua (part 2) without an engine boot
write(out_dir .. "/layouts.txt", ("section capital %d 0\n%s\nsection meta 0\n"):format(#run.text, run.text))
io.stderr:write(("done %.1f s\n"):format(os.clock() - t0))
