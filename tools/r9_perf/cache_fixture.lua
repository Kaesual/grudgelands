-- Portable bounded-cache, nil-tuple and request-order regressions.
return function(repo)
	local _, coast_factory = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/height.lua")
	local coast = coast_factory("0")
	local function tuple(...) return {n = select("#", ...), ...} end
	local function equal(a, b)
		assert(a.n == b.n, "classification return arity changed")
		for index = 1, a.n do assert(a[index] == b[index], "classification tuple changed") end
	end
	local calls = 0
	local function classify(x, z)
		calls = calls + 1
		if x == 999 then error("injected classifier failure", 0) end
		if x % 3 == 0 then return "deep_ocean" end
		if x % 3 == 1 then return "planned_water", nil, x, nil, z, nil, true, false end
		return nil, false, nil, nil, nil, nil, nil, nil
	end
	local cached, stats = coast.new_classification_cache(classify, 4)
	for _, x in ipairs({-3, -2, -1, 0}) do
		equal(tuple(classify(x, -7)), tuple(cached(x, -7)))
	end
	local before = calls
	for _, x in ipairs({0, -1, -2, -3}) do cached(x, -7) end
	assert(calls == before, "warm cache evaluated classifier")
	assert(not pcall(cached, 999, 0), "classifier error was swallowed")
	local size, hits, misses, evictions = stats()
	assert(size == 4 and hits == 4 and misses == 4 and evictions == 0)
	cached(7, 8)
	before = calls
	cached(-3, -7)
	assert(calls == before + 1, "FIFO did not evict oldest entry")
	for index = 1, 200 do
		local x, z = index % 19 - 9, index % 23 - 11
		equal(tuple(classify(x, z)), tuple(cached(x, z)))
	end
	size, hits, misses, evictions = stats()
	assert(size == 4 and evictions == misses - 4, "classification cache exceeded bound")
	local builds, order = 0, {}
	local function build(x, z)
		builds = builds + 1
		return {x = x, z = z, result = (x * 97 + z * 17) % 113}
	end
	local lattice = coast.new_lattice_cache(16)
	for z = -2, 1 do for x = -2, 1 do
		order[#order + 1] = {x, z}
		lattice.get(x, z, build)
	end end
	assert(builds == 16)
	for index = #order, 1, -1 do
		local point = order[index]
		local value = lattice.get(point[1], point[2], build)
		assert(value.x == point[1] and value.z == point[2])
	end
	assert(builds == 16, "neighbor footprint was not retained")
	lattice.get(9, 9, build)
	lattice.get(1, 1, build) -- oldest after reverse traversal
	assert(builds == 18, "lattice LRU eviction differs")
	for index = 1, #order do
		local point = order[index]
		local value = lattice.get(point[1], point[2], build)
		assert(value.result == (point[1] * 97 + point[2] * 17) % 113)
	end
	-- The existing R8 KAT authenticates exact world coordinates and tied
	-- distances against direct rebuilds; keep it separate from cache policy.
	return "r9_perf_cache\tbound=4/16 nil_holes=pass arity=pass error=pass order=pass eviction=pass\n"
end
