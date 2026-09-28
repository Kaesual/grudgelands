-- Measured shares of dry land above each line, coarse analytic grid (every
-- STEP nodes, the planned terrain of the real zones.lua source; no world scan).
-- luajit shares.lua <repo> <step> <seed> [seed ...]
local repo, step = arg[1], tonumber(arg[2] or "32")
local habitat = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/habitat_registry.lua")
local V = habitat.VEGETATION
print(("%-22s %7s %8s %8s %8s %8s %8s"):format("seed", "land", "thinning",
	"treeless", "no_shrub", "dust", "snow_cap"))
local totals = {n = 0, a = 0, b = 0, c = 0, d = 0, e = 0}
for index = 3, #arg do
	local seed = arg[index]
	local W = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, seed)
	local ps = W.planner_source
	local rule = habitat.vegetation_rule(seed)
	local n, a, b, c, d, e = 0, 0, 0, 0, 0, 0
	for z = -3340, 3340, step do
		for x = -3740, 3740, step do
			local water, _, zone, biome, _, y, wy = ps.column_values_at(x, z)
			if water == "land" and biome and not (wy and wy > y) then
				n = n + 1
				local start, line = rule.lines(x, z, biome, zone)
				if y >= start then a = a + 1 end
				if y >= line then b = b + 1 end
				if y >= line + V.SHRUB_REACH then c = c + 1 end
				local snow = rule.snow_class(x, z, y, biome, zone)
				if snow == 1 then d = d + 1 elseif snow == 2 then e = e + 1 end
			end
		end
	end
	print(("%-22s %7d %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%%"):format(seed, n,
		100 * a / n, 100 * b / n, 100 * c / n, 100 * d / n, 100 * e / n))
	totals.n, totals.a, totals.b, totals.c = totals.n + n, totals.a + a, totals.b + b,
		totals.c + c
	totals.d, totals.e = totals.d + d, totals.e + e
end
local t = totals
print(("%-22s %7d %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%%"):format("all", t.n,
	100 * t.a / t.n, 100 * t.b / t.n, 100 * t.c / t.n, 100 * t.d / t.n, 100 * t.e / t.n))
print("thinning: at or above the tree start; treeless: at or above the tree line;")
print("no_shrub: 40 or more above the tree line; dust: patchy band; snow_cap: at or")
print("above the snow line (steep rock faces inside it stay bare stone)")
