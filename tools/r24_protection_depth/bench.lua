-- Micro-benchmark (LuaJIT): the ruling-30 addendum lookups for the Orc start
-- town's mapchunk (x -32..47, z 2528..2607, y -112..-33), seed 4242424242,
-- per call versus memoised per column as r6_settlement.lua does.
--   luajit tools/r24_protection_depth/bench.lua "$PWD"
local repo = assert(arg[1], "usage: bench.lua <repo>")
local world = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, "4242424242")
local P = world.planner_source
local S = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
local limit_of = S.r30_cave_limit
local x0, z0, y0, y1 = -32, 2528, -112, -33
local function limit(x, z)
	local water, _, _, _, _, _, _, _, _, fkind, _, _, _, _, _, _, _, _, _, hard =
		P.column_values_at(x, z)
	local _, cave_id = P.static_exclusion_values_at(x, z, "cave")
	return limit_of(water, cave_id, fkind, hard, P.protected_floor_at, x, z)
end
-- warm the planner caches once
for x = x0, x0 + 79 do for z = z0, z0 + 79 do limit(x, z); P.protected_only_floor_at(x, z) end end
local hits = 0
local function run(memo)
	local cache = {}
	local started = os.clock()
	local count = 0
	for x = x0, x0 + 79 do
		for z = z0, z0 + 79 do
			for y = y0, y1 do
				-- the cave rows' 1/768 hash hits (stand-in hash)
				if (x * 374761 + y * 193939 + z * 668265) % 768 == 0 then
					count = count + 1
					local key = x * 8192 + z
					local l = memo and cache[key]
					if not l then l = limit(x, z); if memo then cache[key] = l end end
				end
			end
		end
	end
	hits = count
	return (os.clock() - started) * 1000
end
local function strata(memo)
	local cache = {}
	local started = os.clock()
	for x = x0, x0 + 79 do
		for z = z0, z0 + 79 do
			if P.static_exclusion_values_at(x, z) ~= nil then
				-- bands/nests: once per column; cultural boxes: up to 45 voxels
				for _ = 1, memo and 1 or 45 do
					local key = x * 8192 + z
					local f = memo and cache[key]
					if not f then
						f = P.protected_only_floor_at(x, z) or -math.huge
						if memo then cache[key] = f end
					end
				end
			end
		end
	end
	return (os.clock() - started) * 1000
end
local a, b = run(false), run(true)
print(("cave rule, %d hash hits: per call %.2f ms, memoised per column %.2f ms"):format(hits, a, b))
print(("protected-only floor over the excluded columns: 45 calls per column %.2f ms," ..
	" memoised %.2f ms"):format(strata(false), strata(true)))
