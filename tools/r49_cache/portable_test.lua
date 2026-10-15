-- Round 49 lane CACHE portable fixture (LuaJIT):
--
--   luajit tools/r49_cache/portable_test.lua REPO
--
-- P9G's 2-D result per chunk column (wp40/r7_p9g.lua, COLUMN_CACHE_LIMIT) on
-- two real runtimes of seed 12345 (tools/seed_fleet/runtime.lua), their fake
-- VoxelManip's ground moved off the planned terrain (so the chunk's voxels
-- differ from the plan the kept roots were ranked on):
-- 1. Hit equals miss: runtime H (the shipped limit) writes the surface
--    chunks of two columns so that the second chunk of each column hits the
--    kept roots; runtime M (the same source with the limit 1) writes them in
--    an order that evicts every column before its second chunk, so each of
--    those chunks scans again. Every chunk writes the same bytes and the
--    same writer result in both, and P9G settles the same number of sources
--    (some in every chunk, so the hit path really writes).
-- 2. Eviction: M counts a miss for every chunk and an eviction for every
--    chunk after the first; H counts exactly one miss per column.
-- 3. Key completeness: the key is the chunk's x/z owner, so a neighbouring
--    column never reuses a kept column (H's second column misses), and a
--    chunk at another height of the same column always may (the kept list
--    holds no y range: the hit chunks above lie at another height than the
--    chunk that kept them). Nothing else the 2-D result reads varies within
--    a session: the seed, the source rows and pure functions of x, y, z.
-- Prints "R49 CACHE PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	print("ok   " .. label)
end

local SEED = "12345"
local P9G_PATH = "/mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua"

-- The shipped limit, read from the source.
local shipped_limit
do
	local file = assert(io.open(repo .. P9G_PATH, "rb"))
	shipped_limit = tonumber(file:read("*a"):match("local COLUMN_CACHE_LIMIT = (%d+)"))
	file:close()
end
check(shipped_limit and shipped_limit >= 2,
	"the shipped P9G column cache limit is read (" .. tostring(shipped_limit) .. ")")

-- One runtime; with `limit`, r7_p9g.lua is loaded with that cache limit.
local function runtime(limit)
	local real_dofile = dofile
	dofile = function(path, ...)
		if limit and type(path) == "string" and path:sub(-#P9G_PATH) == P9G_PATH then
			local file = assert(io.open(path, "rb"))
			local text = file:read("*a")
			file:close()
			local patched, count = text:gsub("local COLUMN_CACHE_LIMIT = %d+",
				"local COLUMN_CACHE_LIMIT = " .. limit)
			assert(count == 1, "COLUMN_CACHE_LIMIT not found once")
			return assert(loadstring(patched, "@" .. path))(...)
		end
		return real_dofile(path, ...)
	end
	local ok, R = pcall(real_dofile, repo .. "/tools/seed_fleet/runtime.lua")
	if ok then ok, R = pcall(R, repo, SEED) end
	dofile = real_dofile
	if not ok then error(R, 0) end
	-- v7's stand-in ground up to about 13 nodes off the plan (the plan reads
	-- the planner's own column source, not this table field).
	local zones = R.built.zones_session
	local terrain_height_at = zones.terrain_height_at
	zones.terrain_height_at = function(x, z)
		return terrain_height_at(x, z) +
			math.floor(10 * math.sin(x * 0.05) * math.cos(z * 0.04) + 3)
	end
	return R
end

local function p9g_metrics(R)
	return R.built.session.metrics().p9g
end

-- Writes `order` (chunk names) in R: name -> {result, hash, accepted}.
local function write(R, chunks, order)
	local out = {}
	for _, name in ipairs(order) do
		local before = p9g_metrics(R).accepted
		local result = R.chunk(chunks[name])
		out[name] = {result = result.result, hash = result.data_hash,
			accepted = p9g_metrics(R).accepted - before}
	end
	return out
end

-- Two neighbouring columns of the mgprof corpus (column A, terrain y 34..65,
-- and the column east of it): both surface chunks of each hold P9G roots.
local CHUNKS = {
	A_S1 = {x = 368, y = -32, z = -2352}, A_S2 = {x = 368, y = 48, z = -2352},
	C_S1 = {x = 448, y = -32, z = -2352}, C_S2 = {x = 448, y = 48, z = -2352},
}
local NAMES = {"A_S1", "A_S2", "C_S1", "C_S2"}

local H = runtime(nil)
local h_metrics = p9g_metrics(H)
check(h_metrics.column_cache_limit == shipped_limit,
	"runtime H runs the shipped limit (" .. tostring(h_metrics.column_cache_limit) .. ")")
-- A_S2 and C_S1 hit (the second chunk of their column).
local hit = write(H, CHUNKS, {"A_S1", "A_S2", "C_S2", "C_S1"})
h_metrics = p9g_metrics(H)
H = nil
collectgarbage()

local M = runtime(1)
check(p9g_metrics(M).column_cache_limit == 1, "runtime M runs the limit 1")
-- Every column is evicted before its second chunk.
local miss = write(M, CHUNKS, {"A_S1", "C_S1", "A_S2", "C_S2"})
local m_metrics = p9g_metrics(M)

-- 1. Hit equals miss.
for _, name in ipairs(NAMES) do
	local a, b = hit[name], miss[name]
	check(a.result == b.result and a.hash == b.hash and a.accepted == b.accepted,
		("%s: kept and scanned roots write the same chunk (%s, %s, %d sources)")
			:format(name, tostring(a.result), a.hash, a.accepted))
	check(a.accepted > 0, name .. ": P9G settles sources in the chunk")
end

-- 2. Eviction and the counts.
check(h_metrics.column_cache_misses == 2 and h_metrics.column_cache_hits == 2 and
	h_metrics.column_cache_evictions == 0,
	("H: one miss per column, the second chunks hit (hits %d, misses %d, evictions %d)")
		:format(h_metrics.column_cache_hits, h_metrics.column_cache_misses,
			h_metrics.column_cache_evictions))
check(m_metrics.column_cache_misses == 4 and m_metrics.column_cache_hits == 0 and
	m_metrics.column_cache_evictions == 3,
	("M: every chunk misses, each after the first evicts (hits %d, misses %d, " ..
		"evictions %d)"):format(m_metrics.column_cache_hits,
		m_metrics.column_cache_misses, m_metrics.column_cache_evictions))

-- 3. Key completeness: H's order wrote C_S2 right after A's chunks; it
-- missed (counted above: two misses, A_S1 and C_S2), so a neighbouring
-- column is never served A's roots, and the hits came at another height.
check(CHUNKS.A_S2.y ~= CHUNKS.A_S1.y and CHUNKS.C_S1.y ~= CHUNKS.C_S2.y,
	"the hit chunks lie at another height than the chunks that kept the roots")

print(("R49 CACHE PORTABLE PASS checks=%d"):format(checks))
