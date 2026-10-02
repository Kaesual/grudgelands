-- Round 25 Lane E micro-benchmark (LuaJIT): the world-protection check of
-- core.is_protected before and after the road/POI protection, on seed
-- 4242424242, at random world points, road-heavy points (inside and around
-- the corridors) and points far from every road. Comparisons only.
--   luajit tools/r25_road_poi/bench.lua "$PWD"
--
-- "before": the zone session's R4 faction policy alone (what
-- grug_core.world_protected_for_faction was); "after": the installed
-- grug_core.world_protected_for_faction (road/POI lookup with position
-- rounding, then that policy); "lookup": the corridor/box lookup alone, for
-- several registered run lengths (segments per candidate-grid record).
local repo = assert(arg[1], "usage: bench.lua <repo>")
local seed = arg[2] or "4242424242"
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
local S = W.session
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local floor = math.floor

local state = 12345
local function random(n)
	state = (state * 48271) % 2147483647
	return state % n
end

local N = 20000
local sets = {random = {}, road = {}, deep = {}, far = {}}
while #sets.random < N do
	local x, z = -3740 + random(7481), -3340 + random(6681)
	sets.random[#sets.random + 1] = {x = x, y = S.terrain_height_at(x, z) - 8 + random(17), z = z}
end
local corridors = W.wp.road_corridors(W.roads, W.road_text)
while #sets.road < N do
	local c = corridors[1 + random(#corridors)]
	local i = 1 + random(#c.X)
	local reach = floor(c.half_width + c.side) + 2
	local x = floor(c.X[i] + 0.5) - reach + random(2 * reach + 1)
	local z = floor(c.Z[i] + 0.5) - reach + random(2 * reach + 1)
	local y = W.wp.surface_node(c.R[i], c.R[i], 0) - 7 + random(15)
	sets.road[#sets.road + 1] = {x = x, y = y, z = z}
end
-- inside the corridors' reach, 10 to 40 above or below the surface (mining
-- under a road, building high above it)
while #sets.deep < N do
	local c = corridors[1 + random(#corridors)]
	local i = 1 + random(#c.X)
	local reach = floor(c.half_width + c.side)
	local x = floor(c.X[i] + 0.5) - reach + random(2 * reach + 1)
	local z = floor(c.Z[i] + 0.5) - reach + random(2 * reach + 1)
	local off = 10 + random(31)
	if random(2) == 0 then off = -off end
	sets.deep[#sets.deep + 1] = {x = x, y = W.wp.surface_node(c.R[i], c.R[i], 0) + off, z = z}
end
while #sets.far < N do
	local x, z = -3740 + random(7481), -3340 + random(6681)
	if not W.sampler.near(x, z, 160) then
		sets.far[#sets.far + 1] = {x = x, y = S.terrain_height_at(x, z) - 8 + random(17), z = z}
	end
end

-- grug_core installed for real.
local sha_hex = function(bytes) return W.common.hex(W.sha(bytes)) end
_G.core = {sha256 = sha_hex, is_protected = function() return false end,
	check_player_privs = function() return false end, log = function() end}
_G.grug_zones = nil
_G.grug_core = {get_player_faction = function() return "accord" end,
	zone_bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")}
assert(loadfile(repo .. "/mods/CORE/grug_core/zone_authority.lua"))()
grug_core.install_zone_authority(S, dofile(dir .. "/r7_consumer_payload.lua")(W.source,
	sha_hex), W.protection)

local before = S.compatibility.world_protected_for_faction
local after = grug_core.world_protected_for_faction
local REPEAT = 5
local function time(fn, list)
	-- warm (memoised columns), then measure
	for i = 1, #list do fn(list[i]) end
	local started = os.clock()
	local hits = 0
	for _ = 1, REPEAT do
		for i = 1, #list do if fn(list[i]) then hits = hits + 1 end end
	end
	return (os.clock() - started) * 1e9 / (REPEAT * #list), hits / REPEAT
end

local lookups = {}
for _, chunk in ipairs({1, 4, 16, 64}) do
	local started = os.clock()
	local P = W.wp.new(W.index128, {chunk = chunk, corridors = corridors,
		boxes = W.wp.settlement_boxes(W.rows)})
	lookups[#lookups + 1] = {chunk = chunk, P = P, build = os.clock() - started}
end

print(("seed %s, %d points per set, %d repeats, ns per call (LuaJIT); before/after: " ..
	"fastest of 3 alternating rounds"):format(seed, N, REPEAT))
for _, name in ipairs({"random", "road", "deep", "far"}) do
	local list = sets[name]
	-- alternating rounds, the fastest of each (the zone session's column
	-- memos make a single pass order-dependent)
	local b, a, bh, ah = math.huge, math.huge, 0, 0
	for _ = 1, 3 do
		local t, h = time(function(p) return before(p, "accord") end, list)
		if t < b then b, bh = t, h end
		t, h = time(function(p) return after(p, "accord") end, list)
		if t < a then a, ah = t, h end
	end
	local k, kh = time(function(p) return grug_core.world_feature_at(p) end, list)
	print(("%-6s before %6.0f  after %6.0f  (+%4.0f%%)  lookup incl. rounding %5.0f; " ..
		"protected before %d after %d, road/POI %d"):format(name, b, a, 100 * (a - b) / b, k,
		bh, ah, kh))
	local parts = {}
	for _, row in ipairs(lookups) do
		local ns = time(function(p) return row.P.kind_at(p.x, p.y, p.z) end, list)
		parts[#parts + 1] = ("run %d: %.0f"):format(row.chunk, ns)
	end
	print("       lookup by segments per run: " .. table.concat(parts, ", "))
end
local parts = {}
for _, row in ipairs(lookups) do
	local m = row.P.metrics
	parts[#parts + 1] = ("run %d: %d records, %d references, max %d per cell, built %.1f ms"):format(
		row.chunk, m.records, m.candidate_references, m.maximum_candidates, row.build * 1000)
end
print("index: " .. table.concat(parts, "; "))
