-- Compact differential KAT for the exact production hash and rank primitives.
return function(repo)
	local path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
	local hash_factory = dofile(path .. "r6_hash.lua")
	local captured, calls = false, 0
	local hash = hash_factory(function(bytes)
		captured, calls = bytes, calls + 1
		return string.rep("a", 32)
	end)
	local rows = {}
	local function check(ok, label)
		assert(ok, "resource primitive: " .. label)
	end
	local function rejected(func, label)
		local ok, message = pcall(func)
		check(not ok and tostring(message):find("fail_hash:", 1, true), label)
	end
	local values = {0, -0, -31012, 31012, -9007199254740991,
		9007199254740991, "", "a", "a\0b", string.char(255, 128, 1)}
	local domains = hash.domains()
	for domain_index = 1, #domains do
		local domain = domains[domain_index]
		for _, count in ipairs({0, 7, 29}) do
			local fields = {}
			for index = 1, count do fields[index] = values[(index - 1) % #values + 1] end
			-- Stale tail keys are permitted by the counted interface.
			fields[32], fields.stale = "ignored", true
			local prepared = hash.prepare_digest3(domain, "seed\0" .. domain, fields, count)
			for index = 1, #values do
				local x, y, z = values[index], values[#values + 1 - index], index - 6
				local complete = {}
				for field = 1, count do complete[field] = fields[field] end
				complete[count + 1], complete[count + 2], complete[count + 3] = x, y, z
				local before = calls
				local ordinary = hash.digest_count(domain, "seed\0" .. domain,
					complete, count + 3)
				local expected = captured
				check(prepared(x, y, z) == ordinary and captured == expected and
					calls == before + 2, "prepared/full byte and call parity")
			end
		end
	end
	local prefix = {"before", 1}
	local first = hash.prepare_digest3(domains[1], "", prefix, 2)
	prefix[1], prefix[2] = "after", -7
	local second = hash.prepare_digest3(domains[2], "other", prefix, 2)
	for index = 1, 3 do
		first(1, 2, 3)
		local expected = captured
		hash.digest(domains[1], "", {"before", 1, 1, 2, 3})
		check(captured == expected, "immutable prefix")
		second(3, 2, 1)
		expected = captured
		hash.digest(domains[2], "other", {"after", -7, 3, 2, 1})
		check(captured == expected, "interleaved closures")
	end
	-- Exceed the private 64-entry cache bound, then revisit cached and
	-- uncached values in reverse order; the ordinary API remains uncached.
	local capped = hash.prepare_digest3(domains[1], "", {}, 0)
	for pass = 1, 2 do
		for index = -80, 80 do
			local value = pass == 1 and index or -index
			capped(value, value + 1, value + 2)
			local expected = captured
			hash.digest(domains[1], "", {value, value + 1, value + 2})
			check(captured == expected, "cache cap and revisit order")
		end
	end
	local invalid = {0 / 0, math.huge, -math.huge, 0.5, 9007199254740992, {}, true}
	for index = 1, #invalid do
		local value = invalid[index]
		rejected(function() first(value, 0, 0) end, "invalid suffix")
		rejected(function() hash.prepare_digest3(domains[1], "", {value}, 1) end,
			"invalid prefix")
	end
	rejected(function() first(nil, 0, 0) end, "nil suffix")
	rejected(function() hash.prepare_digest3("unlisted", "", {}, 0) end, "domain")
	rejected(function() hash.prepare_digest3(domains[1], 0, {}, 0) end, "seed")
	rejected(function() hash.prepare_digest3(domains[1], "", false, 0) end, "fields")
	for _, count in ipairs({-1, 30, 0.5}) do
		rejected(function() hash.prepare_digest3(domains[1], "", {}, count) end, "count")
	end
	rejected(function() hash.prepare_digest3(domains[1], "", {[2] = 1}, 2) end, "hole")
	for _, value in ipairs({false, "", string.rep("x", 31), string.rep("x", 33)}) do
		local bad = hash_factory(function() return value end)
		rejected(function() bad.prepare_digest3(domains[1], "", {}, 0)(0, 0, 0) end,
			"invalid SHA result")
	end
	rows[#rows + 1] = "prepared_hash\tall_domains/0_7_29/binary/bounds/immutable/cache_cap/errors"

	-- Load the exact private production primitives, not a second implementation.
	-- This seam is tool-only; full-engine and settlement tests cover integration.
	local file = assert(io.open(path .. "r6_settlement.lua", "rb"))
	local source = assert(file:read("*a")); assert(file:close())
	local first_at = assert(source:find("\tlocal function sift_down(", 1, true))
	local last_at = assert(source:find("\tlocal function new(dependencies,", first_at, true))
	local chunk = assert(loadstring(source:sub(first_at, last_at - 1) ..
		"\nreturn sort_prefix, heap_prefix, pop_min", "@resource_rank_primitives"))
	local sort_prefix, heap_prefix, pop_min = chunk()
	local function less(left, right)
		if left.digest ~= right.digest then return hash.less_bytes(left.digest, right.digest) end
		if left.z ~= right.z then return left.z < right.z end
		if left.x ~= right.x then return left.x < right.x end
		return left.y < right.y
	end
	local scratch, seen = {}, {}
	for index = 1, 4096 do
		scratch[index] = {x = index % 16 - 8, y = math.floor(index / 16) % 16 - 8,
			z = math.floor(index / 256) - 8,
			digest = string.char((index * 17) % 256) .. string.rep("\0", 31)}
		seen[scratch[index]] = true
	end
	for _, count in ipairs({0, 1, 4096, 17, 2, 4096}) do
		local reference = {}
		for index = 1, count do reference[index] = scratch[index] end
		sort_prefix(reference, count, less)
		heap_prefix(scratch, count, less)
		for rank = 1, count do
			check(pop_min(scratch, count - rank + 1, less) == reference[rank],
				"exact pop order after scratch reuse")
		end
		local remaining = {}
		for index = 1, 4096 do
			check(seen[scratch[index]] and not remaining[scratch[index]], "scratch permutation")
			remaining[scratch[index]] = true
		end
	end
	-- All digest ties must still use z/x/y, including signed coordinates.
	for index = 1, 4096 do scratch[index].digest = string.rep("\0", 32) end
	local reference = {}
	for index = 1, 4096 do reference[index] = scratch[index] end
	sort_prefix(reference, 4096, less); heap_prefix(scratch, 4096, less)
	for rank = 1, 4096 do
		check(pop_min(scratch, 4097 - rank, less) == reference[rank], "all digest ties")
	end
	rows[#rows + 1] = "root_heap\t0/1/4096/partial/reuse/binary/ties/permutation"
	return table.concat(rows, "\n") .. "\n"
end
