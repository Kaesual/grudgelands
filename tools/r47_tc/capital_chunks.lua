-- Round 47 lane TC: the write time of the mapchunks round a capital (the
-- capital greening's cost), through the seed fleet's runtime and writer.
--
--   luajit tools/r47_tc/capital_chunks.lua REPO SEED [N]
--
-- For every capital: the N x N mapchunks (default 5) centred on its anchor's
-- ground layer, planned and written; prints the write seconds per capital.
-- A comparison between two trees, never a target.
local repo, seed, n = arg[1], arg[2], tonumber(arg[3] or "5")
assert(repo and seed, "usage: capital_chunks.lua REPO SEED [N]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local roster = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster
local total = 0
for _, profile in ipairs(roster) do
	if profile.slot == "capital" then
		local anchor = zones.anchor(profile.zone_id, profile.slot)
		local seconds = 0
		local half = math.floor(n / 2)
		for dz = -half, half do
			for dx = -half, half do
				local x, z = anchor.x + dx * 80, anchor.z + dz * 80
				local minp = {x = R.origin(x), y = R.origin(math.max(R.ground_at(x, z), 1)),
					z = R.origin(z)}
				seconds = seconds + R.chunk(minp).write_seconds
			end
		end
		total = total + seconds
		print(("%-12s %d chunks, write %.2f s"):format(profile.key, n * n, seconds))
	end
end
print(("all capitals: write %.2f s"):format(total))
