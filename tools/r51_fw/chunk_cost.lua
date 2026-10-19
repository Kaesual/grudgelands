-- Round 51 follow-up FW: CPU time of planning and writing fixed mapchunks of
-- the sea and of wild lakes through the real writer and a fake VoxelManip,
-- seed 12345 (a comparison of two checkouts, the method of
-- tools/r51_terrain/chunk_cost.lua).
--
--   luajit tools/r51_fw/chunk_cost.lua REPO [ROUNDS]
--
-- S1 the belt off the Dawnmere coast (meadows), S2 the Wyrmglass channel,
-- S3 the middle of bay_kragmar_west, L1 and L2 the two lake chunks holding
-- the most wild lake water, L3 a mesa lake. Each is written ROUNDS times
-- (default 5, the first a warm-up); the median of the rest, in ms.
local repo, rounds = arg[1], tonumber(arg[2] or "5")
assert(repo, "usage: chunk_cost.lua REPO [ROUNDS]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "12345")
local CHUNKS = {{"S1 belt", 208, -32, -2992}, {"S2 channel", -2672, -32, -32},
	{"S3 bay", -912, -32, 2528}, {"L1 lake", -1792, 128, -192}, {"L2 lake", -1792, 128, 768},
	{"L3 mesa lake", -192, 48, 928}}
local sums = {S = 0, L = 0}
for _, c in ipairs(CHUNKS) do
	local times = {}
	for round = 1, rounds do
		local t0 = os.clock()
		R.chunk({x = c[2], y = c[3], z = c[4]})
		if round > 1 then times[#times + 1] = (os.clock() - t0) * 1000 end
	end
	table.sort(times)
	local median = times[math.floor((#times + 1) / 2)]
	sums[c[1]:sub(1, 1)] = sums[c[1]:sub(1, 1)] + median
	print(("%-14s %7.1f ms"):format(c[1], median))
end
print(("sea sum        %7.1f ms"):format(sums.S))
print(("lake sum       %7.1f ms"):format(sums.L))
