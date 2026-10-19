-- Round 51 TERRAIN T3: CPU time of planning and writing a few fixed
-- mapchunks through the real writer and a fake VoxelManip (a comparison of
-- two checkouts; CPU seconds are steadier than an engine boot's wall time on
-- a busy workstation).
--
--   luajit tools/r51_terrain/chunk_cost.lua REPO [SEED] [ROUNDS]
--
-- The chunks are mgprof_t2_extra.lua's (seed 12345): the Wyrmglass channel
-- (C1, C2), the middle of bay_kragmar_west (B1), belt water off the southern
-- coast (B2), the southern coast's land (B3) and the open sea (O1). Each is
-- written ROUNDS times (default 3, the first a warm-up); the median of the
-- rest is printed in ms.
local repo, seed, rounds = arg[1], arg[2] or "12345", tonumber(arg[3] or "3")
assert(repo, "usage: chunk_cost.lua REPO [SEED] [ROUNDS]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local CHUNKS = {{"C1 channel", -2672, -32}, {"C2 channel", -2672, -112},
	{"B1 bay", -912, 2528}, {"B2 belt", 1648, -3312}, {"B3 coast land", 1648, -3072},
	{"O1 open sea", -32, -3712}}
local total = 0
for _, c in ipairs(CHUNKS) do
	local times = {}
	for round = 1, rounds do
		local t0 = os.clock()
		R.chunk({x = c[2], y = -32, z = c[3]})
		if round > 1 then times[#times + 1] = (os.clock() - t0) * 1000 end
	end
	table.sort(times)
	local median = times[math.floor((#times + 1) / 2)]
	total = total + median
	print(("%-14s %7.1f ms"):format(c[1], median))
end
print(("sum            %7.1f ms"):format(total))
