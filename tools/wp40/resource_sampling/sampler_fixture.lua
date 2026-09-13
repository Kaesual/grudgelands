-- Portable oracle for the proposed resource-root draw stream.

return function(repo, production_repo, expanded)
	if expanded and type(jit) ~= "table" then
		error("resource sampling fixture: expanded mode requires LuaJIT", 0)
	end
	production_repo = production_repo or repo
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local real_sha256 = common.new_sha256()
	local hash_factory = dofile(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua")
	local MODULUS, MULTIPLIER = 2147483647, 16807
	local function check(value, message)
		if not value then error("resource sampling fixture: " .. message, 0) end
	end
	local function frame(value)
		local bytes = type(value) == "number" and string.format("%.0f", value) or value
		return tostring(#bytes) .. ":" .. bytes
	end
	local fields = {"copper", -2, 7, 11, "stone", 3, "ordinary"}
	local function prefix(seed, values, count)
		local parts = {frame("grug_wp40_r6_hash_v1"),
			frame("resource_root_shuffle_v1"), frame(seed)}
		for index = 1, count do parts[#parts + 1] = frame(values[index]) end
		return table.concat(parts)
	end
	local function seed_from_digest(digest)
		local value = 0
		for index = 1, 4 do value = value * 256 + string.byte(digest, index) end
		return value % 2147483646 + 1
	end
	local function oracle_draw(raw_sha256, seed, values, count)
		local state = seed_from_digest(raw_sha256(prefix(seed, values, count)))
		return function(remaining)
			local limit = math.floor(2147483646 / remaining) * remaining
			while true do
				state = state * MULTIPLIER % MODULUS
				local value = state - 1
				if value < limit then return value % remaining + 1 end
			end
		end
	end
	local function expect_error(callback, label, prefix)
		local ok, message = pcall(callback)
		check(not ok, label .. " did not fail")
		check(type(message) == "string" and string.find(message, prefix, 1, true) == 1,
			label .. " error prefix differs")
	end
	local rows = {"schema\tgrug_wp40_resource_sampling_fixture_v1"}

	-- Constant digest gives a hand-computable seed of one.
	local zero_digest = string.rep(string.char(0), 32)
	local constant_sha = function() return zero_digest end
	local hash = hash_factory(constant_sha)
	check(type(hash.prepare_root_draw) == "function", "prepare_root_draw missing")
	local actual = hash.prepare_root_draw("seed", fields, 7)
	local expected = oracle_draw(constant_sha, "seed", fields, 7)
	local known = {}
	for _, remaining in ipairs({4096, 4095, 97, 16, 3, 1}) do
		local a, e = actual(remaining), expected(remaining)
		check(a == e, "constant-digest KAT differs")
		known[#known + 1] = a
	end
	local literal_known = {423, 2149, 26, 10, 1, 1}
	for index = 1, #literal_known do
		check(known[index] == literal_known[index], "literal KAT differs")
	end
	rows[#rows + 1] = "known\t" .. table.concat(known, ",")

	-- The captured bytes prove domain separation, seed framing and count-7 prefixing.
	local captured
	local capture_sha = function(bytes)
		captured = bytes
		return real_sha256(bytes)
	end
	hash_factory(capture_sha).prepare_root_draw("0\0seed", fields, 7)
	local expected_prefix = prefix("0\0seed", fields, 7)
	check(captured == expected_prefix, "canonical prefix framing differs")
	rows[#rows + 1] = "prefix_sha256\t" .. common.hex(real_sha256(captured))

	-- Interleaving closures must not share mutable generator state.
	local real_hash = hash_factory(real_sha256)
	local left = real_hash.prepare_root_draw("left", fields, 7)
	local right = real_hash.prepare_root_draw("right", fields, 7)
	local left_alone = real_hash.prepare_root_draw("left", fields, 7)
	local right_alone = real_hash.prepare_root_draw("right", fields, 7)
	for remaining = 31, 1, -1 do
		check(left(remaining) == left_alone(remaining), "left closure leaked state")
		check(right(remaining) == right_alone(remaining), "right closure leaked state")
	end

	-- Exercise the rejection branch deliberately. 739806647 advances to M-1;
	-- for remaining=4096 that value is rejected before the second state is used.
	local seed_word = 739806646
	local forced_digest = string.char(math.floor(seed_word / 16777216) % 256,
		math.floor(seed_word / 65536) % 256, math.floor(seed_word / 256) % 256,
		seed_word % 256) .. string.rep(string.char(0), 28)
	local forced_sha = function() return forced_digest end
	local forced_actual = hash_factory(forced_sha).prepare_root_draw("forced", fields, 7)
	local forced_expected = oracle_draw(forced_sha, "forced", fields, 7)
	local forced_value = forced_actual(4096)
	check(forced_value == forced_expected(4096) and forced_value == 3672,
		"rejection-boundary draw differs")
	rows[#rows + 1] = "rejection\tok"

	-- Mirror the writer's lazy Fisher-Yates operation and require unique exhaustion.
	local records = {}
	for index = 1, 4096 do records[index] = index end
	local draw = real_hash.prepare_root_draw("exhaustion", fields, 7)
	local seen = {}
	for remaining = 4096, 1, -1 do
		local selected = draw(remaining)
		check(selected >= 1 and selected <= remaining, "draw escaped remaining bound")
		local value = records[selected]
		records[selected], records[remaining] = records[remaining], value
		check(not seen[value], "lazy shuffle repeated a record")
		seen[value] = true
	end
	for index = 1, 4096 do check(seen[index], "lazy shuffle omitted a record") end
	rows[#rows + 1] = "exhaustion\t4096"

	expect_error(function() actual(0) end, "remaining zero", "fail_bound:")
	expect_error(function() actual(4097) end, "remaining high", "fail_bound:")
	expect_error(function() actual(1.5) end, "remaining fraction", "fail_bound:")
	expect_error(function() hash.prepare_root_draw(false, fields, 7) end,
		"seed type", "fail_hash:")
	expect_error(function() hash.prepare_root_draw("seed", fields, 6.5) end,
		"count fraction", "fail_hash:")
	local hole = {"a", "b", "c", "d", "e", "f"}
	expect_error(function() hash.prepare_root_draw("seed", hole, 7) end,
		"field hole", "fail_hash:")
	rows[#rows + 1] = "bounds\tok"

	local settlement_source = common.read_file(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
	check(string.find(settlement_source,
		"return hash.prepare_root_draw(full_seed,\n\t\t\t\tdigest_fields, 7)",
		1, true) ~= nil, "writer helper does not pass exactly seven fields")
	rows[#rows + 1] = "writer_fields\t7"

	if expanded then
		-- LuaJIT-only statistical smoke: independent SHA-seeded cells, one draw
		-- into 64 bins. Wide limits catch gross bias/wiring errors; they are not
		-- evidence for whole-world resource distribution.
		local bins, samples = {}, 16384
		for index = 1, 64 do bins[index] = 0 end
		for cell = 1, samples do
			local smoke_fields = {"smoke", cell, 0, 0, "stone", 1, "ordinary"}
			local smoke = real_hash.prepare_root_draw("smoke-seed", smoke_fields, 7)
			local selected = smoke(64)
			bins[selected] = bins[selected] + 1
		end
		local minimum, maximum = bins[1], bins[1]
		for index = 2, 64 do
			minimum, maximum = math.min(minimum, bins[index]), math.max(maximum, bins[index])
		end
		check(minimum >= 160 and maximum <= 360,
			"statistical smoke escaped broad bounds")
		rows[#rows + 1] = table.concat({"smoke", samples, 64, minimum, maximum,
			"diagnostic_not_distribution_proof"}, "\t")
	else
		rows[#rows + 1] = "smoke\tskipped_compact"
	end
	rows[#rows + 1] = "resource_sampling_fixture\tok"
	return table.concat(rows, "\n") .. "\n"
end
