-- Round 51 TERRAIN T1: what the terrain field's grids cost (a comparison of
-- two checkouts, not a target).
--
--   luajit tools/r51_terrain/grid_cost.lua REPO SEED [N]
--
-- Builds the real runtime of SEED from REPO (tools/seed_fleet/runtime.lua),
-- keeping the arguments of its terrain field construction, then constructs
-- the field N more times (default 5) with the same arguments: CPU seconds of
-- each and the Lua heap the field keeps (after full collections, with the
-- zone field's sample memo already warm, so the difference is the field's own
-- grids and buckets). Prints the cell counts of both grids, the median time
-- and the median heap.
local repo, seed, count = arg[1], arg[2], tonumber(arg[3] or "5")
assert(repo and seed and count, "usage: grid_cost.lua REPO SEED [N]")

local captured
do
	local real_dofile = dofile
	_G.dofile = function(path)
		local result = real_dofile(path)
		if type(path) == "string" and path:match("/terrain_field%.lua$") and
				type(result) == "function" then
			return function(data)
				local module = result(data)
				local new = module.new
				module.new = function(...)
					if not captured then captured = {new = new, args = {...}} end
					return new(...)
				end
				return module
			end
		end
		return result
	end
end

dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
assert(captured, "the terrain field was not built")
local V = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/terrain_data.lua").params
local function cells(step)
	return (math.floor((V.grid_max_x - V.grid_min_x) / step) + 1) *
		(math.floor((V.grid_max_z - V.grid_min_z) / step) + 1)
end
print(("grids x %d..%d z %d..%d: character %d cells (x9 channels), coast %d cells")
	:format(V.grid_min_x, V.grid_max_x, V.grid_min_z, V.grid_max_z, cells(V.blend_cell),
		cells(V.coast_cell)))

local times, heaps = {}, {}
for index = 1, count do
	collectgarbage("collect") collectgarbage("collect")
	local kib0, t0 = collectgarbage("count"), os.clock()
	local field = captured.new(unpack(captured.args))
	local seconds = os.clock() - t0
	collectgarbage("collect") collectgarbage("collect")
	times[index], heaps[index] = seconds, collectgarbage("count") - kib0
	assert(field.height_at)
	field = nil
	print(("build %d: %.3f s CPU, %.0f KiB kept"):format(index, times[index], heaps[index]))
end
table.sort(times)
table.sort(heaps)
local middle = math.floor((count + 1) / 2)
print(("median: %.3f s CPU, %.0f KiB kept"):format(times[middle], heaps[middle]))
