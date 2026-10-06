-- Round 38 lane I: the zones' gameplay neighbours (world_zones.md §7.3, §9.1)
-- on the six quest seeds, for the name inventory (inventory.py reads the
-- file this prints). Neighbours are geometric and seed-dependent: two zones
-- are neighbours when they share at least `neighbor_min_border` nodes of
-- land border on that seed (wp40/simple_map.lua). Built as the runtime
-- builds the zone session (wp40/world_assembly.lua), without the capitals.
--
--   luajit tools/r38_names/neighbours.lua <repo> > tools/r38_names/neighbours.tsv
--
-- About 9 s per seed (LuaJIT); run it through the round's Lua queue.
-- Output: one line per seed and zone, "seed<TAB>zone<TAB>n1,n2,...",
-- zones in mapgen order, neighbours sorted.
local repo = arg[1] or "."
local SEEDS = {"42", "7", "2026", "1234", "99999", "314159"}
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local A = dofile(dir .. "/world_assembly.lua")(dir, common.new_sha256())
print("seed\tzone\tneighbours")
for _, seed in ipairs(SEEDS) do
	local session = A.world(seed).zones().new_with_planner_source_runtime(seed, 1)
	for _, zone in ipairs(A.source.zones) do
		print(seed .. "\t" .. zone.id .. "\t" .. table.concat(session.neighbors(zone.id), ","))
	end
end
