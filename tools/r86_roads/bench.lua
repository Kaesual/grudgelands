-- Round 86 lane ROADS: the road sampler's cost under today's rule and the
-- candidate rules (census.lua's), on one seed's real road layout (the seed
-- fleet's runtime) over the same columns: every second column of a square
-- of HALF round the arena, its pre-road ground read once beforehand. CPU
-- seconds, best of three, for building the sampler and for the walk.
--
--   luajit tools/r86_roads/bench.lua REPO SEED [HALF]
local repo, seed, half = arg[1], arg[2], tonumber(arg[3] or 1024)
assert(repo and seed, "usage: bench.lua REPO SEED [HALF]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local RL = dofile(wp40 .. "/road_layout.lua")
local L = dofile(wp40 .. "/breach_layout.lua")
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
local X, Z, T, WY, n = {}, {}, {}, {}, 0
for z = site.z - half, site.z + half, 2 do
	for x = site.x - half, site.x + half, 2 do
		local t, wy, land = height.fitted_values_at(x, z)
		if land then
			n = n + 1
			X[n], Z[n], T[n], WY[n] = x, z, t, wy or false
		end
	end
end
local function patched()
	local f = assert(io.open(wp40 .. "/road_layout.lua", "rb"))
	local src = f:read("*a")
	f:close()
	local anchor = "\t\t\t\t\t\tlocal walled = wh > 0 and e <= 1.5\n"
	local a = assert(src:find(anchor, 1, true))
	src = src:sub(1, a - 1) ..
		"\t\t\t\t\t\tif P.FADE then cap = max(cap, t - P.FADE * (SIDE - e)) end\n" .. src:sub(a)
	return assert(loadstring(src))()
end
local PM = patched()
local variants = {
	{"today", RL},
	{"fade1", PM.with_params({FADE = 1})},
	{"side40", RL.with_params({SIDE_MAX = 40})},
	{"side40fade1", PM.with_params({SIDE_MAX = 40, FADE = 1})},
	{"side64", RL.with_params({SIDE_MAX = 64})},
}
local function best(fn)
	local b = math.huge
	for _ = 1, 3 do
		collectgarbage()
		local c0 = os.clock()
		fn()
		b = math.min(b, os.clock() - c0)
	end
	return b
end
print(("seed %s columns %d (every second of %d x %d round %d,%d)"):format(seed, n,
	2 * half + 1, 2 * half + 1, site.x, site.z))
for _, v in ipairs(variants) do
	local s
	local build = best(function() s = v[2].sampler(layout) end)
	local col, road = s.column, 0
	local walk = best(function()
		road = 0
		for i = 1, n do
			if col(X[i], Z[i], T[i], WY[i] or nil) ~= nil then road = road + 1 end
		end
	end)
	print(("%-12s build %.3f s  walk %.3f s  road columns %d"):format(v[1], build, walk, road))
end
