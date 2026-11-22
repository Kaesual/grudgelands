-- Round 86 lane ROADS: the road cut wall census of one seed (round86-plan.md
-- §4 ROADS, step 1). Builds the seed's real world plan (the seed fleet's
-- runtime, `tools/seed_fleet/runtime.lua`: main's build, no chunk written)
-- and measures every road's cut at its side zone's edge with
-- `tools/r86_roads/walls.lua` (the step a cut adds over nature between two
-- neighbouring columns): today's rule exactly (the height session's own
-- answers) and, on request, candidate rules estimated (the road sampler with
-- other tunables, or with a candidate's lines patched into a copy of
-- `road_layout.lua` in memory, on the same pre-road ground; a column the
-- session keeps off the road, a core's edge, stays off; nothing is written).
--
--   luajit tools/r86_roads/census.lua REPO SEED [MAX_WALL_LINES]
--   R86_ROADS_RULES="side40 fade2 ..."  candidate rules (RULES below)
--   R86_ROADS_PROFILE=<n>  the cross-section of today's n largest walls
--                          under every rule
--
-- Prints:
--   seed <seed> roads=<n> nodes=<centreline points> build=<s> census=<s>
--     arena=<x>,<z>
--   rule <name> columns=<band columns> steps=<steps of 1 or more>
--     max=<largest> w2=.. w3=.. w4=.. w6=.. w10=.. (walls whose largest
--     step is at least that) hist=<largest step per wall: count,...>
--     mismatch=<band columns where the sampler and the session disagree,
--     today's rule only> seconds=<s>
--   wall <rule> <largest> <steps> <x> <z> <road id> <road kind> <a> <b>
--     <where: arena (an arena leg), capital, other> <arena distance>
--     <natural rise per node over the 8 nodes beyond the edge> <the reach
--     from the road's edge at which today's 2:1 rock face would meet the
--     ground along that cross-section, ">128" beyond>
--     (walls of 2 or more, at most MAX_WALL_LINES per rule, default 40)
--   faces <rule> <x>,<z>:<steepest rise> ...  along the cross-section of
--     each of today's listed walls of 3 or more: the largest rise between
--     neighbouring columns from the road out to the rule's edge + 2
--   profile <rule> <x>,<z> road y <y>: <e>:<pre-road y>/<final y><kind>...
local repo, seed, max_lines = arg[1], arg[2], tonumber(arg[3] or 40)
assert(repo and seed and seed:match("^%d+$"), "usage: census.lua REPO SEED [MAX_WALL_LINES]")
local t0 = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local t_build = os.clock() - t0
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local W = dofile(repo .. "/tools/r86_roads/walls.lua")
local RL = dofile(wp40 .. "/road_layout.lua")
local L = dofile(wp40 .. "/breach_layout.lua")
local floor, abs, sqrt = math.floor, math.abs, math.sqrt

local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
local height = upvalue(R.planner_source.road_column_at, "height")
local layout = RL.deserialize(height.road_layout_text())
local site = L.from_placement(R.main.placement_layout_text())
local capitals = R.main.capital_protection()
local P = RL.P
local SIDE = P.SIDE_MAX

-- memoised column answers (the band and its neighbours ask a column up to
-- five times)
local function memo(fn)
	local F, N, K = {}, {}, {}
	return function(x, z)
		local k = W.key(x, z)
		local f = F[k]
		if f == nil then
			local n, kind
			f, n, kind = fn(x, z)
			F[k], N[k], K[k] = f, n, kind or false
		end
		return f, N[k], K[k] or nil
	end
end
-- today's rule: the session's own answers
local today = memo(function(x, z)
	local pre = height.fitted_values_at(x, z)
	return height.terrain_height_at(x, z), pre, (height.road_column_at(x, z))
end)

-- The candidates' road modules: today's code with other tunables, or with
-- the edge fade patched in (FADE = K: a column's cut is at most K per node
-- of its distance to the side zone's edge deep, so the cut meets the ground
-- at the edge whatever the hill does beyond).
local function patched_module()
	local f = assert(io.open(wp40 .. "/road_layout.lua", "rb"))
	local src = f:read("*a")
	f:close()
	local anchor = "\t\t\t\t\t\tlocal walled = wh > 0 and e <= 1.5\n"
	local a, b = src:find(anchor, 1, true)
	assert(a and not src:find(anchor, b, true), "the cap's anchor line is not unique")
	src = src:sub(1, a - 1) ..
		"\t\t\t\t\t\tif P.FADE then cap = max(cap, t - P.FADE * (SIDE - e)) end\n" .. src:sub(a)
	return assert(loadstring(src, "=road_layout.lua (census patch)"))()
end
local PATCHED
local function module_for(rule)
	if rule.patch then
		PATCHED = PATCHED or patched_module()
		return PATCHED.with_params(rule.over)
	end
	return RL.with_params(rule.over)
end
-- a candidate: today's answer where today's sampler and the candidate's
-- agree; else the candidate's on the same pre-road ground
local base_sampler = RL.sampler(layout)
local function candidate(rule)
	local s = module_for(rule).sampler(layout)
	return memo(function(x, z)
		local f, pre, kind = today(x, z)
		local t, wy, land = height.fitted_values_at(x, z)
		if not land then return f, pre, kind end
		local k0, _, n0 = base_sampler.column(x, z, t, wy)
		local k1, _, n1 = s.column(x, z, t, wy)
		if k0 == k1 and n0 == n1 then return f, pre, kind end
		if kind == nil and k0 ~= nil then return f, pre, kind end -- kept off (a core)
		if k1 == nil then return t, pre, nil end
		return n1 or t, pre, k1
	end)
end

local CANDIDATES = {
	{name = "side32", side = 32, over = {SIDE_MAX = 32}},
	{name = "side40", side = 40, over = {SIDE_MAX = 40}},
	{name = "side48", side = 48, over = {SIDE_MAX = 48}},
	{name = "side64", side = 64, over = {SIDE_MAX = 64}},
	{name = "rock3", side = SIDE, over = {CUT_ROCK = 3}},
	{name = "rock4", side = SIDE, over = {CUT_ROCK = 4}},
	{name = "fade05", side = SIDE, over = {FADE = 0.5}, patch = true},
	{name = "fade1", side = SIDE, over = {FADE = 1}, patch = true},
	{name = "fade2", side = SIDE, over = {FADE = 2}, patch = true},
	{name = "fade3", side = SIDE, over = {FADE = 3}, patch = true},
	{name = "lift0125", side = SIDE, over = {CUT_FADE_LIFT = 0.125}},
	{name = "lift05", side = SIDE, over = {CUT_FADE_LIFT = 0.5}},
	{name = "liftinf", side = SIDE, over = {CUT_FADE_LIFT = 1e9}},
	{name = "side40fade1", side = 40, over = {SIDE_MAX = 40, FADE = 1}, patch = true},
	{name = "side40fade2", side = 40, over = {SIDE_MAX = 40, FADE = 2}, patch = true},
}
local RULES = {{name = "today", side = SIDE}}
local only = os.getenv("R86_ROADS_RULES") or ""
for _, rule in ipairs(CANDIDATES) do
	if (" " .. only .. " "):find(" " .. rule.name .. " ", 1, true) then RULES[#RULES + 1] = rule end
end
local n_profiles = tonumber(os.getenv("R86_ROADS_PROFILE") or 0)
local sections = os.getenv("R86_ROADS_SECTIONS")

local nodes = 0
for _, r in ipairs(layout.roads) do nodes = nodes + #r.X end
local function where(x, z, r)
	if r.a:match("^breach_") or r.b:match("^breach_") then return "arena" end
	if r.kind == "avenue" or r.kind == "lane" then return "capital" end
	for _, shape in pairs(capitals) do
		if shape.member(x, z) then return "capital" end
	end
	return "other"
end
local function arena_distance(x, z)
	return math.max(abs(x - site.x) - L.HALF_X, abs(z - site.z) - L.HALF_Z, 0)
end
-- the cross-section through a step: the nearest centreline point of its
-- road and the normal towards the step
local function ray(r, x, z)
	local i, best = 1, math.huge
	for j = 1, #r.X - 1 do
		local d = (r.X[j] - x) ^ 2 + (r.Z[j] - z) ^ 2
		if d < best then i, best = j, d end
	end
	local dx, dz = r.X[i + 1] - r.X[i], r.Z[i + 1] - r.Z[i]
	local len = sqrt(dx * dx + dz * dz)
	local nx, nz = -dz / len, dx / len
	if (x - r.X[i]) * nx + (z - r.Z[i]) * nz < 0 then nx, nz = -nx, -nz end
	return function(e)
		return floor(r.X[i] + (r.hw + e) * nx + 0.5), floor(r.Z[i] + (r.hw + e) * nz + 0.5)
	end, r.R[i], floor(r.X[i] + 0.5), floor(r.Z[i] + 0.5)
end
-- today's 2:1 face extended (full low wall): ry + 2e - 5 beyond CUT_SOIL
local function face(ry, e)
	local ee = math.max(0, e - 1)
	return ry + P.WALL_H + math.min(ee, P.CUT_SOIL) * P.CUT_SLOPE +
		math.max(0, ee - P.CUT_SOIL) * P.CUT_ROCK
end

local t1 = os.clock()
local out, rays = {}, {}
-- R86_ROADS_AT="x,z x,z ...": sections also through these columns (the
-- nearest road's nearest point; for before/after pictures at the same place)
for x, z in (os.getenv("R86_ROADS_AT") or ""):gmatch("(%-?%d+),(%-?%d+)") do
	x, z = tonumber(x), tonumber(z)
	local best, br = math.huge, nil
	for _, r in ipairs(layout.roads) do
		for j = 1, #r.X do
			local d = (r.X[j] - x) ^ 2 + (r.Z[j] - z) ^ 2
			if d < best then best, br = d, r end
		end
	end
	local at, ry, cx, cz = ray(br, x, z)
	rays[#rays + 1] = {at, ry, x, z, cx, cz, 0, br.id}
end
local forced = #rays
for _, rule in ipairs(RULES) do
	local c0 = os.clock()
	local query = rule.over and candidate(rule) or today
	local columns, road_of = W.band(layout, rule.side)
	local mismatch = 0
	if not rule.over then
		-- the sampler on the pre-road ground against the session (that the
		-- candidates' stand-in is the session's rule)
		for _, k in ipairs(columns) do
			local x, z = W.unkey(k)
			local t, wy, land = height.fitted_values_at(x, z)
			if land then
				local f, _, kind = today(x, z)
				local k0, _, n0 = base_sampler.column(x, z, t, wy)
				if k0 ~= kind or (k0 ~= nil and k0 ~= "surface" and n0 ~= f) then
					mismatch = mismatch + 1
				end
			end
		end
	end
	local steps = W.steps(columns, query, 1)
	local walls = W.clusters(steps, 3)
	local hist, top = {}, 0
	local counts = {[2] = 0, [3] = 0, [4] = 0, [6] = 0, [10] = 0}
	for _, w in ipairs(walls) do
		hist[w.max] = (hist[w.max] or 0) + 1
		if w.max > top then top = w.max end
		for limit in pairs(counts) do
			if w.max >= limit then counts[limit] = counts[limit] + 1 end
		end
	end
	local hs = {}
	for h = 1, top do
		if hist[h] then hs[#hs + 1] = h .. ":" .. hist[h] end
	end
	out[#out + 1] = ("rule %s columns=%d steps=%d max=%d w2=%d w3=%d w4=%d w6=%d w10=%d " ..
		"hist=%s mismatch=%d seconds=%.1f"):format(rule.name, #columns, #steps, top, counts[2],
		counts[3], counts[4], counts[6], counts[10], #hs > 0 and table.concat(hs, ",") or "-",
		mismatch, os.clock() - c0)
	local lines = 0
	for _, w in ipairs(walls) do
		if w.max < 2 or lines >= max_lines then break end
		local s = w.at
		local r = layout.roads[road_of[s[1]]]
		local at, ry, cx, cz = ray(r, s[2], s[3])
		local x0, z0 = at(SIDE)
		local x8, z8 = at(SIDE + 8)
		local rise = (select(2, today(x8, z8)) - select(2, today(x0, z0))) / 8
		local need = ">128"
		for e = SIDE, 128 do
			if select(2, today(at(e))) <= face(ry, e) then need = tostring(e) break end
		end
		if not rule.over and w.max >= 3 and forced == 0 then
			rays[#rays + 1] = {at, ry, s[2], s[3], cx, cz, w.max, r.id}
		end
		out[#out + 1] = ("wall %s %d %d %d %d %d %s %s %s %s %d %.1f %s"):format(rule.name, w.max,
			w.columns, s[2], s[3], r.id, r.kind, r.a, r.b, where(s[2], s[3], r),
			arena_distance(s[2], s[3]), rise, need)
		lines = lines + 1
	end
	local faces = {}
	for _, q in ipairs(rays) do
		local steep, last = 0, nil
		for e = 0, rule.side + 2 do
			local f = query(q[1](e))
			if last and f - last > steep then steep = f - last end
			last = f
		end
		faces[#faces + 1] = ("%d,%d:%d"):format(q[3], q[4], steep)
	end
	if #faces > 0 then out[#out + 1] = "faces " .. rule.name .. " " .. table.concat(faces, " ") end
	-- R86_ROADS_SECTIONS=1: the whole cross-section of each of today's
	-- walls of 3 or more (from the road's edge to 6 beyond the side zone,
	-- 1 node apart along the normal): "section <rule> <x>,<z> wall=<today's
	-- height> depth=<pre-road ground at the centreline above the road>
	-- rise=<pre-road ground at the side zone's edge above the road>
	-- max=<largest step between neighbours>@<distance> steep=<steps of more
	-- than 2> cliff=<largest rise of consecutive steps of more than 2>/<its
	-- length>@<its start> f=<final y per distance,...> n=<pre-road y,...>"
	if sections then
		for _, q in ipairs(rays) do
			local fs, ns = {}, {}
			for e = 0, SIDE + 6 do
				local f, pre = query(q[1](e))
				fs[#fs + 1], ns[#ns + 1] = f, pre
			end
			local big, big_at, steep = 0, 0, 0
			local cliff, cliff_len, cliff_at = 0, 0, 0
			local run, run_len, run_at = 0, 0, 0
			for e = 1, #fs - 1 do
				local d = fs[e + 1] - fs[e]
				if abs(d) > abs(big) then big, big_at = d, e end
				if abs(d) > 2 then
					steep = steep + 1
					if run_len == 0 then run_at = e end
					run, run_len = run + abs(d), run_len + 1
					if run > cliff then cliff, cliff_len, cliff_at = run, run_len, run_at end
				else
					run, run_len = 0, 0
				end
			end
			local centre = select(2, today(q[5], q[6]))
			out[#out + 1] = ("section %s %d,%d wall=%d road=%d depth=%.1f rise=%.1f max=%d@%d " ..
				"steep=%d cliff=%d/%d@%d f=%s n=%s"):format(rule.name, q[3], q[4], q[7], q[8],
				centre - q[2], ns[SIDE + 1] - q[2], big, big_at - 1, steep, cliff, cliff_len,
				cliff_at - 1, table.concat(fs, ","), table.concat(ns, ","))
		end
	end
	for n, q in ipairs(rays) do
		if n > n_profiles then break end
		local row = {}
		for e = 0, 64, 2 do
			local f, pre, kind = query(q[1](e))
			row[#row + 1] = ("%d:%d/%d%s"):format(e, pre, f, kind and kind:sub(1, 1) or "")
		end
		out[#out + 1] = ("profile %s %d,%d road y %.1f: %s"):format(rule.name, q[3], q[4], q[2],
			table.concat(row, " "))
	end
end
-- R86_ROADS_DUMP=<dir>: the pictures' data (tools/r86_roads/render.py):
-- <seed>-roads.tsv (road id, kind, x, z of every second centreline point),
-- <seed>-coarse.tsv (x, z, ground, land: every 16 nodes over the world) and
-- per section <seed>-local-<x>_<z>.tsv (x, z, final y, road code 0 none, 1
-- surface, 2 side column, over 97 x 97 round the wall) plus its line ends.
local dump = os.getenv("R86_ROADS_DUMP")
if dump then
	local f = assert(io.open(dump .. "/" .. seed .. "-roads.tsv", "w"))
	for _, r in ipairs(layout.roads) do
		for i = 1, #r.X, 2 do f:write(r.id, "\t", r.kind, "\t", ("%.1f\t%.1f\n"):format(r.X[i], r.Z[i])) end
	end
	f:close()
	local B = dofile(wp40 .. "/source/simple_map.lua").world_bounds
	f = assert(io.open(dump .. "/" .. seed .. "-coarse.tsv", "w"))
	for z = B.min_z, B.max_z, 16 do
		for x = B.min_x, B.max_x, 16 do
			local y, _, land = height.fitted_values_at(x, z)
			f:write(x, "\t", z, "\t", y, "\t", land and 1 or 0, "\n")
		end
	end
	f:close()
	for _, q in ipairs(rays) do
		f = assert(io.open(("%s/%s-local-%d_%d.tsv"):format(dump, seed, q[3], q[4]), "w"))
		local x0, z0 = q[1](0)
		local x1, z1 = q[1](SIDE + 6)
		f:write(("# line %d %d %d %d centre %d %d\n"):format(x0, z0, x1, z1, q[5], q[6]))
		for z = q[4] - 48, q[4] + 48 do
			for x = q[3] - 48, q[3] + 48 do
				local fy, _, kind = today(x, z)
				f:write(x, "\t", z, "\t", fy, "\t", kind == nil and 0 or kind == "surface" and 1 or 2, "\n")
			end
		end
		f:close()
	end
end
print(("seed %s roads=%d nodes=%d build=%.1f census=%.1f arena=%d,%d"):format(seed,
	#layout.roads, nodes, t_build, os.clock() - t1, site.x, site.z))
for _, line in ipairs(out) do print(line) end
