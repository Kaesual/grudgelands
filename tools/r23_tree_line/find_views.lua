-- Picks render windows: a high mountain whose slopes cross the tree start,
-- the tree line and the snow line, and a low deep-forest window with groves
-- and clearings. luajit find_views.lua <repo> <seed> [size]
local repo, seed, size = arg[1], arg[2] or "4242", tonumber(arg[3] or "224")
local habitat = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/habitat_registry.lua")
local W = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, seed)
local ps = W.planner_source
local rule = habitat.vegetation_rule(seed, ps.land_zone_at)
local mountains, forests = {}, {}
for z0 = -3200, 3200 - size, 32 do
	for x0 = -3600, 3600 - size, 32 do
		local n, land, lo, hi, band, snow, deep, fsum, fsq, open = 0, 0, 1e9, -1e9, 0, 0, 0,
			0, 0, 0
		for z = z0, z0 + size - 1, 16 do
			for x = x0, x0 + size - 1, 16 do
				n = n + 1
				local water, _, zone, biome, _, y, wy = ps.column_values_at(x, z)
				if water == "land" and not (wy and wy > y) then
					land = land + 1
					lo, hi = math.min(lo, y), math.max(hi, y)
					local start, line, sl = rule.lines(x, z, biome, zone)
					if y >= start and y < line then band = band + 1 end
					if y >= sl then snow = snow + 1 end
					if biome == "grug_deep_forest" and y < 140 then
						deep = deep + 1
						local f = rule.forest(x, z) / 4096
						fsum, fsq = fsum + f, fsq + f * f
						if f < 0.05 then open = open + 1 end
					end
				end
			end
		end
		if land == n and band >= n * 0.2 and snow >= n * 0.1 and hi - lo < 330 then
			mountains[#mountains + 1] = {score = band + snow, text = ("mountain %d,%d " ..
				"y %d..%d band %.2f snow %.2f"):format(x0, z0, lo, hi, band / n, snow / n)}
		end
		if deep >= n * 0.9 and hi - lo < 60 and open >= 2 then
			local mean = fsum / deep
			local var = fsq / deep - mean * mean
			forests[#forests + 1] = {score = var + open / n, text = ("forest %d,%d y %d..%d " ..
				"field var %.2f clearings %.2f"):format(x0, z0, lo, hi, var, open / n)}
		end
	end
end
table.sort(mountains, function(a, b) return a.score > b.score end)
table.sort(forests, function(a, b) return a.score > b.score end)
for i = 1, math.min(6, #mountains) do print(mountains[i].text) end
for i = 1, math.min(6, #forests) do print(forests[i].text) end
