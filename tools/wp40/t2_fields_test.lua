local repo = assert(arg[1], "repository root required")
local mode = assert(arg[2], "test mode required")
local output_dir = assert(arg[3], "output directory required")
local request_fifo = arg[4]
local response_fifo = arg[5]

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic,
})
local source = dofile(wp40 .. "/source/catalog.lua")
local analytic_record = dofile(wp40 .. "/analytic_record.lua")
local template = dofile(wp40 .. "/geometry/template.lua")({
	deterministic = deterministic,
	exact = exact,
})

local request_file
local response_file
local transport_sha_calls = 0
local function raw_sha256(data)
	if not request_file then
		request_file = assert(io.open(assert(request_fifo), "wb"))
		response_file = assert(io.open(assert(response_fifo), "rb"))
	end
	assert(request_file:write(tostring(#data), "\n", data))
	assert(request_file:flush())
	local digest = assert(response_file:read(32))
	assert(#digest == 32, "truncated SHA-256 response")
	transport_sha_calls = transport_sha_calls + 1
	return digest
end

local relief = dofile(wp40 .. "/geometry/relief.lua")({
	canonical = canonical,
	deterministic = deterministic,
	exact = exact,
	raw_sha256 = raw_sha256,
})

local function write_file(path, data)
	local file = assert(io.open(path, "wb"))
	assert(file:write(data))
	assert(file:close())
end

if mode == "generate-ellipse-fixture" then
	local session = relief.new(source, "0", 1)
	local rows = {"landmark_id\tx\tz\texact_inside\tsigned_inside\tsigned_distance_q"}
	for landmark_index = 1, #source.landmarks do
		local landmark = source.landmarks[landmark_index]
		if landmark.primitive == "ellipse" then
			for z = landmark.center.z - landmark.radius_z,
					landmark.center.z + landmark.radius_z do
				for x = landmark.center.x - landmark.radius_x,
						landmark.center.x + landmark.radius_x do
					local result = session.mask(landmark.id, x, z)
					local signed_inside = result.signed_distance_q <= 0
					if result.inside ~= signed_inside then
						rows[#rows + 1] = table.concat({landmark.id, x, z,
							result.inside and 1 or 0, signed_inside and 1 or 0,
							result.signed_distance_q}, "\t")
					end
				end
			end
		end
	end
	assert(#rows == 265, "ellipse disagreement roster changed: " .. (#rows - 1))
	write_file(output_dir .. "/ellipse-disagreements-v1.tsv",
		table.concat(rows, "\n") .. "\n")
	print("WP40 C-a1 ellipse fixture rows=" .. (#rows - 1))
	return
end

assert(mode == "full" or mode == "targeted", "unknown test mode")

local Q = deterministic.Q

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

local function dense_count(value)
	local count = #value
	for key in pairs(value) do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1 and
			key <= count)
	end
	return count
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	assert(not seen[value], "fixture graph is cyclic")
	seen[value] = true
	local result = {}
	for key, child in pairs(value) do result[key] = deep_copy(child, seen) end
	seen[value] = nil
	return result
end

local function find_row(rows, id)
	for index = 1, #rows do
		if rows[index].id == id then return rows[index] end
	end
	error("missing Source row " .. id, 0)
end

local function split_tsv(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("(.-)\t") do
		fields[#fields + 1] = field
	end
	return fields
end

local function bool_text(value) return value and "1" or "0" end

local cases = {}
local function add_case(id, targeted, callback)
	assert(type(id) == "string" and id ~= "")
	cases[#cases + 1] = {id = id, targeted = targeted, callback = callback}
end

local performance_metrics = {}

add_case("analytic_shape", true, function()
	local text_values = {{name = "zeta", value = "z"},
		{name = "alpha", value = "a"}}
	local candidates = {3, 0, 4294967295}
	local record = analytic_record.new("grug_wp40_test_record_v1", "row", 7, {
		text_values = text_values,
		signed_values = {{name = "below", value = -3}},
		unsigned_values = {{name = "above", value = 4}},
		boolean_values = {{name = "enabled", value = true}},
		text_arrays = {{name = "labels", values = {"a", "b"}}},
		signed_arrays = {{name = "points", values = {-1, 2}}},
		unsigned_arrays = {{name = "counts", values = {0, 9}}},
		candidates = candidates,
		attributes = {},
	})
	assert(dense_count(record.text_values) == 2 and
		record.text_values[1].name == "alpha" and
		record.text_values[2].name == "zeta")
	assert(dense_count(record.candidates) == 3 and record.candidates[1] == 3)
	text_values[1].value = "changed"
	candidates[1] = 99
	assert(record.text_values[2].value == "z" and record.candidates[1] == 3)
	local field_count = 0
	for _ in pairs(record) do field_count = field_count + 1 end
	assert(field_count == 12 and next(record.attributes) == nil)
	return table.concat({record.record_schema, record.id, record.numeric_id,
		record.text_values[1].name, record.text_values[2].name,
		record.candidates[1]}, ":")
end)

add_case("analytic_rejects", true, function()
	expect_error("unknown field", function()
		analytic_record.new("s", "i", 0, {extra = {}})
	end)
	expect_error("occurs in text_values and signed_values", function()
		analytic_record.new("s", "i", 0, {text_values = {
			{name = "same", value = "a"}}, signed_values = {
			{name = "same", value = 1}}})
	end)
	expect_error("text_values has duplicate field same", function()
		analytic_record.new("s", "i", 0, {text_values = {
			{name = "same", value = "a"}, {name = "same", value = "b"}}})
	end)
	expect_error("dense array", function()
		analytic_record.new("s", "i", 0, {candidates = {[1] = 1, [3] = 3}})
	end)
	expect_error("has a metatable", function()
		analytic_record.new("s", "i", 0, setmetatable({}, {}))
	end)
	expect_error("not text", function()
		analytic_record.new("s", "i", 0, {text_values = {
			{name = "bad", value = function() end}}})
	end)
	expect_error("attributes must", function()
		analytic_record.new("s", "i", 0, {attributes = {x = 1}})
	end)
	local structurally_valid = analytic_record.new("s", "i", 0, {
		text_values = {{name = "bytes", value = string.char(255)}}})
	expect_error("valid UTF-8", function()
		canonical.text(structurally_valid.text_values[1].value)
	end)
	return "extra,cross,same,sparse,metatable,function,attributes,utf8_seam"
end)

add_case("raw_mapping", true, function()
	local singleton = {min_above_water = 5, max_above_water = 5}
	local rows = {}
	for index = 1, #source.relief_profiles do
		local profile = source.relief_profiles[index]
		local low = relief.raw_height_from_noise(profile, 1, -Q)
		local middle = relief.raw_height_from_noise(profile, 1, 0)
		local high = relief.raw_height_from_noise(profile, 1, Q)
		assert(low == 1 + profile.min_above_water)
		assert(middle == 1 + profile.min_above_water +
			math.floor((profile.max_above_water - profile.min_above_water) / 2))
		assert(high == 1 + profile.max_above_water)
		assert(relief.raw_height_from_noise(profile, 1, Q + 1) == high)
		assert(relief.raw_height_from_noise(profile, 1, -Q - 1) == low)
		assert(relief.raw_height_from_noise(profile, 1, 2 * Q) == high)
		assert(relief.raw_height_from_noise(profile, 1, -2 * Q) == low)
		rows[#rows + 1] = profile.id .. ":" .. low .. ":" .. middle ..
			":" .. high
	end
	assert(relief.raw_height_from_noise(singleton, -7, -9007199254740991) == -2)
	assert(relief.raw_height_from_noise(singleton, -7, 9007199254740991) == -2)
	return table.concat(rows, ",")
end)

local function relief_probe(seed, profile_id, x, z)
	local session = relief.new(source, seed, 1)
	local height, noise = session.raw_height(profile_id, x, z)
	local stats = session.stats()
	return height, noise, stats.sha_calls, stats.cache_hits
end

add_case("seed_zero", true, function()
	local h, noise, calls, hits = relief_probe("0", "wetland_delta", 0, 0)
	assert(h == 16 and noise == 17333 and calls == 4 and hits == 4)
	return table.concat({h, noise, calls, hits}, ":")
end)

add_case("seed_max_u64", true, function()
	local h, noise, calls = relief_probe("18446744073709551615", "mountain",
		-3260, -40)
	assert(h == 254 and noise == -4196 and calls == 12)
	return table.concat({h, noise, calls}, ":")
end)

add_case("seed_small_corpus", false, function()
	local probes = {
		{"1", "lowland", -1800, -2520, 34, 4322},
		{"2147483648", "rolling_hills", 1736, -1500, 79, 33881},
		{"343674299183575008", "highland", 2050, 0, 124, -37197},
	}
	local values = {}
	for index = 1, #probes do
		local row = probes[index]
		local h, noise = relief_probe(row[1], row[2], row[3], row[4])
		assert(h == row[5] and noise == row[6])
		local again_h, again_noise = relief_probe(row[1], row[2], row[3], row[4])
		assert(h == again_h and noise == again_noise)
		values[index] = table.concat({row[1], row[2], row[3], row[4], h, noise},
			":")
	end
	return table.concat(values, ",")
end)

local function expected_hash_input(seed, domain, x, z, block)
	return "GRUGWP40HASH" .. string.char(0) ..
		canonical.encode(canonical.text("grug_wp40_geometry_source_v1")) ..
		canonical.encode(canonical.text(domain)) ..
		canonical.encode(canonical.text(seed)) ..
		canonical.encode(canonical.text("")) ..
		canonical.encode(canonical.array({canonical.signed(x),
			canonical.signed(z)})) ..
		canonical.encode(canonical.unsigned(0)) ..
		canonical.encode(canonical.unsigned(block)) ..
		canonical.encode(canonical.unsigned(0))
end

add_case("hash_domain_candidate_zero", true, function()
	local captured = {}
	local function spy(data)
		captured[#captured + 1] = data
		return raw_sha256(data)
	end
	local spy_relief = dofile(wp40 .. "/geometry/relief.lua")({
		canonical = canonical, deterministic = deterministic, exact = exact,
		raw_sha256 = spy})
	local session = spy_relief.new(source, "0", 1)
	session.raw_height("wetland_delta", 0, 0)
	local expected = {}
	for z = 0, 1 do
		for x = 0, 1 do
			expected[expected_hash_input("0", "relief_wetland_delta", x, z, 0)] = true
		end
	end
	assert(#captured == 4)
	for index = 1, #captured do assert(expected[captured[index]]) end
	local stats = session.stats()
	assert(stats.sha_requests == 8 and stats.sha_calls == 4 and
		stats.cache_hits == 4 and stats.cache_misses == 4)

	captured = {}
	session = spy_relief.new(source, "0", 1)
	local landmark = find_row(source.landmarks, "hearthpine_bowl")
	local _, contributions = session.compose_landmarks(0, landmark.center.x,
		landmark.center.z, {landmark.id})
	assert(#contributions == 1)
	local allowed = {}
	local profile = find_row(source.relief_profiles, landmark.secondary_relief_id)
	for octave_index = 1, #profile.octaves do
		local period = profile.octaves[octave_index].period
		local lx = deterministic.floor_div(landmark.center.x, period)
		local lz = deterministic.floor_div(landmark.center.z, period)
		for dz = 0, 1 do
			for dx = 0, 1 do
				allowed[expected_hash_input("0", landmark.noise_domain,
					lx + dx, lz + dz, 0)] = true
			end
		end
	end
	for index = 1, #captured do assert(allowed[captured[index]]) end
	return table.concat({stats.sha_requests, stats.sha_calls, #captured,
		landmark.noise_domain}, ":")
end)

add_case("mask_rectangle", true, function()
	local row = find_row(source.landmarks, "copperfell_coastal_terraces")
	local session = relief.new(source, "0", 1)
	local negative = session.mask(row.id, row.center.x - row.radius_x,
		row.center.z - row.radius_z)
	local positive = session.mask(row.id, row.center.x + row.radius_x,
		row.center.z + row.radius_z)
	local outside = session.mask(row.id, row.center.x + row.radius_x + 1,
		row.center.z)
	local zero = session.mask(row.id, row.center.x + row.radius_x + 64,
		row.center.z)
	assert(negative.inside and positive.inside and not outside.inside)
	assert(negative.signed_distance_q == 0 and positive.signed_distance_q == 0)
	assert(outside.signed_distance_q == Q and outside.weight_q > 0)
	assert(zero.signed_distance_q == 64 * Q and zero.weight_q == 0)
	return table.concat({negative.weight_q, positive.weight_q,
		outside.weight_q, zero.weight_q}, ":")
end)

add_case("mask_ellipse", true, function()
	local row = find_row(source.landmarks, "hearthpine_bowl")
	local session = relief.new(source, "0", 1)
	local cardinal = session.mask(row.id, row.center.x + row.radius_x,
		row.center.z)
	local outside = session.mask(row.id, row.center.x + row.radius_x + 1,
		row.center.z)
	local disagreement = session.mask(row.id, -1801, -2740)
	assert(cardinal.inside and cardinal.signed_distance_q == 0)
	assert(not outside.inside and outside.signed_distance_q > 0)
	assert(not disagreement.inside and disagreement.signed_distance_q == 0 and
		disagreement.weight_q == Q)
	return table.concat({bool_text(cardinal.inside), cardinal.signed_distance_q,
		bool_text(outside.inside), outside.signed_distance_q,
		bool_text(disagreement.inside), disagreement.signed_distance_q}, ":")
end)

add_case("mask_capsule", true, function()
	local row = find_row(source.landmarks, "copperfell_drainage")
	local session = relief.new(source, "0", 1)
	local long_boundary = session.mask(row.id, row.center.x,
		row.center.z + row.radius_z)
	local long_outside = session.mask(row.id, row.center.x,
		row.center.z + row.radius_z + 1)
	local side = session.mask(row.id, row.center.x + row.radius_x, row.center.z)
	local cap_corner = session.mask(row.id, row.center.x + row.radius_x,
		row.center.z + row.radius_z - row.radius_x)
	assert(long_boundary.inside and long_boundary.signed_distance_q == 0 and
		not long_boundary.signed_distance_saturated)
	assert(not long_outside.inside and long_outside.signed_distance_q == Q)
	assert(side.inside and cap_corner.inside)
	local near_zero = session.mask(row.id,
		row.center.x + row.radius_x + row.base_h_blend_width - 2, row.center.z)
	local zero = session.mask(row.id,
		row.center.x + row.radius_x + row.base_h_blend_width, row.center.z)
	local extreme = session.mask(row.id, 2147483647, -2147483648)
	assert(not near_zero.inside and near_zero.signed_distance_q == 62 * Q and
		near_zero.weight_q > 0 and not near_zero.signed_distance_saturated)
	assert(not zero.inside and zero.signed_distance_q == 64 * Q and
		zero.weight_q == 0 and zero.signed_distance_saturated)
	assert(not extreme.inside and extreme.signed_distance_q == 64 * Q and
		extreme.weight_q == 0 and extreme.signed_distance_saturated)
	return table.concat({long_boundary.weight_q, long_outside.weight_q,
		side.signed_distance_q, cap_corner.signed_distance_q,
		near_zero.weight_q, bool_text(zero.signed_distance_saturated)}, ":")
end)

add_case("landmark_default_real_columns", true, function()
	local probes = {{0, 0}, {-1800, -2520}, {-3260, -40}, {2050, 0},
		{3149, 300}, {1736, -1500}}
	local rows = {}
	for index = 1, #probes do
		local probe = probes[index]
		local session = relief.new(source, "0", 1)
		local height, contributions = session.compose_landmarks(20,
			probe[1], probe[2])
		local ids = {}
		for contribution_index = 1, #contributions do
			local contribution = contributions[contribution_index]
			assert(contribution.weight_q > 0)
			if contribution_index > 1 then
				assert(contributions[contribution_index - 1].priority <
					contribution.priority)
			end
			ids[contribution_index] = contribution.id
		end
		rows[index] = table.concat({probe[1], probe[2], height,
			table.concat(ids, "+"), session.stats().sha_calls}, ":")
	end
	local result = table.concat(rows, ",")
	assert(result == "0:0:20::0,-1800:-2520:31:hearthpine_bowl:8," ..
		"-3260:-40:215:wyrmglass_ring+wyrmglass_faultfields+" ..
		"wyrmglass_dragonspire:32,2050:0:55:skyglass_escarpment+" ..
		"skyglass_hangingways:20,3149:300:255:stormscale_caldera:12," ..
		"1736:-1500:35:lethariel_crownlake:8")
	return result
end)

local triple_ids = {"wyrmglass_ring", "wyrmglass_faultfields",
	"wyrmglass_dragonspire"}

add_case("landmark_triple_order", true, function()
	local session = relief.new(source, "0", 1)
	local final_h, contributions = session.compose_landmarks(17, -3260, -40,
		{triple_ids[3], triple_ids[1], triple_ids[2]})
	assert(#contributions == 3)
	for index = 1, 3 do
		assert(contributions[index].id == triple_ids[index] and
			contributions[index].weight_q == Q and
			contributions[index].exact_inside)
	end
	assert(final_h == contributions[3].replacement_h)
	assert(final_h == 215)
	local second = relief.new(source, "0", 1)
	local permuted_h, permuted = second.compose_landmarks(17, -3260, -40,
		{triple_ids[2], triple_ids[3], triple_ids[1]})
	assert(permuted_h == final_h and #permuted == 3)
	local stats = session.stats()
	assert(stats.sha_calls == 32)
	performance_metrics.triple_sha_calls = stats.sha_calls
	performance_metrics.triple_contributions = stats.contributions
	performance_metrics.triple_cache_hits = stats.cache_hits
	performance_metrics.triple_cache_misses = stats.cache_misses
	performance_metrics.triple_replacement_evaluations =
		stats.replacement_evaluations
	return table.concat({contributions[1].priority, contributions[2].priority,
		contributions[3].priority, final_h, stats.sha_calls}, ":")
end)

add_case("landmark_two_collar_chain", true, function()
	local ids = {"hearthpine_bowl", "copperfell_drainage"}
	local session = relief.new(source, "0", 1)
	local final_h, contributions = session.compose_landmarks(20, -2061, -2355,
		{ids[2], ids[1]})
	assert(#contributions == 2 and contributions[1].id == ids[1] and
		contributions[2].id == ids[2])
	assert(contributions[1].weight_q > 0 and contributions[1].weight_q < Q and
		contributions[2].weight_q > 0 and contributions[2].weight_q < Q)
	assert(contributions[2].previous_h == contributions[1].result_h and
		final_h == contributions[2].result_h)
	local non_chained_h = deterministic.qlerp(20,
		contributions[2].replacement_h, contributions[2].weight_q)
	assert(contributions[1].weight_q == 21986 and
		contributions[1].replacement_h == 35 and
		contributions[1].previous_h == 20 and
		contributions[1].result_h == 25 and
		contributions[2].weight_q == 10058 and
		contributions[2].replacement_h == 141 and
		contributions[2].previous_h == 25 and
		contributions[2].result_h == 43 and final_h == 43 and
		non_chained_h == 39)
	local permuted = relief.new(source, "0", 1)
	local permuted_h, permuted_contributions = permuted.compose_landmarks(20,
		-2061, -2355, {ids[1], ids[2]})
	assert(permuted_h == final_h and #permuted_contributions == 2)
	for index = 1, 2 do
		assert(permuted_contributions[index].id == contributions[index].id and
			permuted_contributions[index].weight_q == contributions[index].weight_q and
			permuted_contributions[index].previous_h == contributions[index].previous_h and
			permuted_contributions[index].result_h == contributions[index].result_h)
	end
	return table.concat({contributions[1].id, contributions[1].weight_q,
		contributions[1].replacement_h, contributions[1].previous_h,
		contributions[1].result_h, contributions[2].id,
		contributions[2].weight_q, contributions[2].replacement_h,
		contributions[2].previous_h, contributions[2].result_h, final_h}, ":")
end)

add_case("landmark_zero_weight", false, function()
	local row = find_row(source.landmarks, "copperfell_coastal_terraces")
	local session = relief.new(source, "0", 1)
	local before = session.stats()
	local height, contributions = session.compose_landmarks(19,
		row.center.x + row.radius_x + row.base_h_blend_width, row.center.z,
		{row.id})
	local after = session.stats()
	assert(height == 19 and #contributions == 0)
	assert(after.sha_calls == before.sha_calls and
		after.replacement_evaluations == before.replacement_evaluations and
		after.contributions == before.contributions)
	return table.concat({height, after.sha_calls, after.replacement_evaluations,
		after.mask_evaluations}, ":")
end)

add_case("landmark_priority_rejects", false, function()
	local corrupted = deep_copy(source)
	corrupted.landmarks[2].base_h_priority =
		corrupted.landmarks[1].base_h_priority
	expect_error("priority is duplicated", function()
		relief.new(corrupted, "0", 1)
	end)
	local session = relief.new(source, "0", 1)
	expect_error("selected landmark priority is duplicated", function()
		session.compose_landmarks(0, 0, 0, {source.landmarks[1].id,
			source.landmarks[1].id})
	end)
	return "source_duplicate,selection_duplicate"
end)

add_case("relief_cache_performance", false, function()
	local warmup = relief.new(source, "0", 1)
	warmup.raw_height("rolling_hills", -997, 881)
	local session = relief.new(source, "0", 1, {sha_cache_capacity = 16})
	local started = os.clock()
	local first_h, first_noise = session.raw_height("rolling_hills", 123, -456)
	local cold_cpu = os.clock() - started
	local cold = session.stats()
	local second_h, second_noise
	started = os.clock()
	for _ = 1, 16 do
		second_h, second_noise = session.raw_height("rolling_hills", 123, -456)
	end
	local warm_cpu = (os.clock() - started) / 16
	local warm = session.stats()
	assert(first_h == second_h and first_noise == second_noise)
	assert(cold.sha_calls == 6)
	assert(warm.sha_calls == cold.sha_calls and warm.cache_hits > cold.cache_hits)
	performance_metrics.ordinary_cold_sha_calls = cold.sha_calls
	performance_metrics.ordinary_cold_cache_hits = cold.cache_hits
	performance_metrics.ordinary_cold_cache_misses = cold.cache_misses
	performance_metrics.ordinary_cold_raw_evaluations = cold.raw_evaluations
	performance_metrics.ordinary_warm_added_sha_calls = warm.sha_calls - cold.sha_calls
	performance_metrics.ordinary_warm_added_cache_hits =
		warm.cache_hits - cold.cache_hits
	performance_metrics.ordinary_warm_added_cache_misses =
		warm.cache_misses - cold.cache_misses
	performance_metrics.ordinary_cold_cpu_seconds = cold_cpu
	performance_metrics.ordinary_warm_cpu_seconds = warm_cpu
	session.clear_cache()
	local cleared = session.stats()
	assert(cleared.cache_entries == 0 and cleared.sha_calls == warm.sha_calls)
	local cleared_h, cleared_noise = session.raw_height("rolling_hills", 123, -456)
	local refilled = session.stats()
	assert(cleared_h == first_h and cleared_noise == first_noise and
		refilled.sha_calls == warm.sha_calls + cold.sha_calls and
		refilled.cache_entries == cold.cache_entries and
		refilled.cache_misses == warm.cache_misses + cold.cache_misses)
	local bounded = relief.new(source, "0", 1, {sha_cache_capacity = 4})
	for index = 1, 4 do bounded.raw_height("lowland", index * 1000, index * -777) end
	local bounded_stats = bounded.stats()
	assert(bounded_stats.cache_entries == 4 and bounded_stats.cache_capacity == 4)
	assert(warm.cache_hits - cold.cache_hits == 128)
	return table.concat({cold.sha_calls, warm.sha_calls - cold.sha_calls,
		warm.cache_hits - cold.cache_hits, cleared.cache_entries,
		refilled.sha_calls, bounded_stats.cache_entries}, ":")
end)

local template_session = template.new(source)

add_case("primitive_flat_tilt", true, function()
	local flat_negative = template_session.evaluate_primitive("flat",
		{height_offset = 3}, -2, 0, 4)
	local flat_positive = template_session.evaluate_primitive("flat",
		{height_offset = 3}, 2, 0, 4)
	assert(flat_negative.inside and flat_negative.signed_distance_q == 0 and
		flat_negative.offset_q == 3 * Q and flat_negative.weight_q == Q)
	assert(not flat_positive.inside and flat_positive.signed_distance_q == 0 and
		flat_positive.weight_q == 0)
	assert(dense_count({flat_negative.offset_q, flat_negative.weight_q,
		flat_negative.signed_distance_q, flat_negative.inside and 1 or 0}) == 4)
	local field_count = 0
	for _ in pairs(flat_negative) do field_count = field_count + 1 end
	assert(field_count == 4)
	local tilt_positive = template_session.evaluate_primitive("tilt",
		{axis_x = 1, axis_z = 0, rise = 1, run = 2}, 1, 0, 8)
	local tilt_negative = template_session.evaluate_primitive("tilt",
		{axis_x = 1, axis_z = 0, rise = 1, run = 2}, -1, 0, 8)
	local tilt_outside = template_session.evaluate_primitive("tilt",
		{axis_x = 1, axis_z = 0, rise = 1, run = 2}, 4, 0, 8)
	assert(tilt_positive.offset_q == Q / 2 and
		tilt_negative.offset_q == -Q / 2 and not tilt_outside.inside and
		tilt_outside.signed_distance_q == 0)
	assert(template.footprint_signed_distance_q(8, 0, 0) < 0 and
		template.footprint_signed_distance_q(8, 5, 0) > 0)
	local singleton = template_session.evaluate_primitive("flat",
		{height_offset = 0}, 0, 0, 1)
	assert(template.centered_contains(1, 0, 0) and
		not template.centered_contains(1, -1, 0) and
		not template.centered_contains(1, 1, 0) and
		singleton.signed_distance_q == 0 and
		tostring(singleton.signed_distance_q) == "0")
	return table.concat({flat_negative.offset_q, bool_text(flat_negative.inside),
		bool_text(flat_positive.inside), tilt_positive.offset_q,
		tilt_negative.offset_q, tostring(singleton.signed_distance_q)}, ":")
end)

add_case("primitive_terrace", true, function()
	local centre = template_session.evaluate_primitive("terrace",
		{step_height = 2, step_run = 5, rings = 4}, 0, 0, 32)
	local first = template_session.evaluate_primitive("terrace",
		{step_height = 2, step_run = 5, rings = 4}, 3, 4, 32)
	local capped = template_session.evaluate_primitive("terrace",
		{step_height = 2, step_run = 5, rings = 4}, 15, 0, 32)
	local outside = template_session.evaluate_primitive("terrace",
		{step_height = 2, step_run = 5, rings = 4}, 16, 0, 32)
	assert(centre.offset_q == 0 and first.offset_q == 2 * Q and
		capped.offset_q == 6 * Q and not outside.inside and
		outside.signed_distance_q == 0)
	assert(template.radius_q(3, 4) == 5 * Q)
	return table.concat({centre.offset_q, first.offset_q, capped.offset_q,
		template.radius_q(3, 4)}, ":")
end)

add_case("primitive_radial", true, function()
	local plateau_inner = template_session.evaluate_primitive("plateau",
		{inner_radius = 10, shoulder_width = 10}, 10, 0, 64)
	local plateau_middle = template_session.evaluate_primitive("plateau",
		{inner_radius = 10, shoulder_width = 10}, 15, 0, 64)
	local plateau_outer = template_session.evaluate_primitive("plateau",
		{inner_radius = 10, shoulder_width = 10}, 20, 0, 64)
	local plateau_outside = template_session.evaluate_primitive("plateau",
		{inner_radius = 10, shoulder_width = 10}, 21, 0, 64)
	assert(plateau_inner.weight_q == Q and plateau_middle.weight_q == Q / 2 and
		plateau_outer.inside and plateau_outer.weight_q == 0 and
		plateau_outer.signed_distance_q == 0 and not plateau_outside.inside and
		plateau_outside.signed_distance_q == Q)
	local basin_inner = template_session.evaluate_primitive("basin",
		{inner_radius = 10, depth = 6, rim_width = 10}, 0, 0, 64)
	local basin_middle = template_session.evaluate_primitive("basin",
		{inner_radius = 10, depth = 6, rim_width = 10}, 15, 0, 64)
	local basin_outer = template_session.evaluate_primitive("basin",
		{inner_radius = 10, depth = 6, rim_width = 10}, 20, 0, 64)
	local basin_outside = template_session.evaluate_primitive("basin",
		{inner_radius = 10, depth = 6, rim_width = 10}, 21, 0, 64)
	assert(basin_inner.offset_q == -6 * Q and basin_middle.offset_q == -3 * Q and
		basin_outer.offset_q == 0 and basin_outer.inside and
		not basin_outside.inside)
	local rim_inner = template_session.evaluate_primitive("rim",
		{inner_radius = 10, peak_radius = 15, outer_radius = 20, height = 8},
		10, 0, 64)
	local rim_peak = template_session.evaluate_primitive("rim",
		{inner_radius = 10, peak_radius = 15, outer_radius = 20, height = 8},
		15, 0, 64)
	local rim_outer = template_session.evaluate_primitive("rim",
		{inner_radius = 10, peak_radius = 15, outer_radius = 20, height = 8},
		20, 0, 64)
	local rim_outside = template_session.evaluate_primitive("rim",
		{inner_radius = 10, peak_radius = 15, outer_radius = 20, height = 8},
		21, 0, 64)
	assert(rim_inner.offset_q == 0 and rim_peak.offset_q == 8 * Q and
		rim_outer.offset_q == 0 and rim_outer.inside and not rim_outside.inside)
	return table.concat({plateau_middle.weight_q, basin_inner.offset_q,
		basin_middle.offset_q, rim_peak.offset_q}, ":")
end)

add_case("primitive_invalid_overflow", false, function()
	expect_error("unit Manhattan axis", function()
		template_session.evaluate_primitive("tilt",
			{axis_x = 1, axis_z = 1, rise = 1, run = 2}, 0, 0, 8)
	end)
	expect_error("exceeds the exact Lua integer range", function()
		template_session.evaluate_primitive("flat",
			{height_offset = deterministic.MAX_SAFE}, 0, 0, 8)
	end)
	expect_error("exceeds the exact Lua integer range", function()
		template.radius_q(2147483647, 2147483647)
	end)
	expect_error("strictly increasing", function()
		template_session.evaluate_primitive("rim", {inner_radius = 10,
			peak_radius = 10, outer_radius = 20, height = 1}, 0, 0, 64)
	end)
	expect_error("missing field", function()
		template_session.evaluate_primitive("flat", {}, 0, 0, 8)
	end)
	return "axis,qoverflow,radius_overflow,radii,missing"
end)

local function operator_source(operations)
	return {template_primitives = deep_copy(source.template_primitives),
		template_compositions = {{id = "compose_operator", version = 1,
			operations = operations}}, templates = {{id = "operator",
			composition_id = "compose_operator", fitting_width = 64,
			blend_width = 80}}}
end

add_case("operator_apply", false, function()
	local session = template.new(operator_source({{op = "apply",
		primitive_id = "flat", parameters = {height_offset = 2}}}))
	assert(session.evaluate("compose_operator", 0, 0) == 2 * Q)
	assert(session.evaluate("compose_operator", 32, 0) == 0)
	return tostring(2 * Q)
end)

add_case("operator_overlay", false, function()
	local session = template.new(operator_source({{op = "apply",
		primitive_id = "flat", parameters = {height_offset = -1}},
		{op = "overlay", primitive_id = "flat",
			parameters = {height_offset = 3}}}))
	assert(session.evaluate("compose_operator", 0, 0) == 3 * Q)
	return tostring(3 * Q)
end)

add_case("operator_subtract", false, function()
	local session = template.new(operator_source({{op = "apply",
		primitive_id = "flat", parameters = {height_offset = 10}},
		{op = "subtract", primitive_id = "basin",
			parameters = {inner_radius = 10, depth = 3, rim_width = 10}}}))
	assert(session.evaluate("compose_operator", 0, 0) == 7 * Q)
	return tostring(7 * Q)
end)

add_case("operator_blend", true, function()
	local session = template.new(operator_source({{op = "apply",
		primitive_id = "flat", parameters = {height_offset = 8}},
		{op = "blend", primitive_id = "plateau",
			parameters = {inner_radius = 10, shoulder_width = 10}}}))
	local expected = deterministic.qlerp(8 * Q, 0, Q / 2)
	local actual = session.evaluate("compose_operator", 15, 0)
	assert(actual == expected)
	return tostring(actual)
end)

add_case("composition_payload_free_14", false, function()
	local samples = {
		compose_start = {-63, 1, 128, 256},
		compose_capital_dwarf = {96, 0, 512, 704},
		compose_capital_human = {0, 176, 512, 704},
		compose_capital_elf = {112, 0, 512, 704},
		compose_capital_undead = {96, 0, 512, 704},
		compose_capital_orc = {232, 0, 512, 704},
		compose_capital_troll = {84, 0, 512, 704},
		compose_village = {-48, 0, 96, 160},
		compose_outpost = {-31, 1, 64, 112},
		compose_bandit_home = {17, -19, 64, 112},
		compose_bandit_frontier = {0, -32, 64, 112},
		compose_mine = {39, 0, 80, 128},
		compose_dragon = {42, 0, 96, 160},
		compose_apex_mine = {32, 0, 96, 160},
	}
	local values = {}
	for index = 1, #source.template_compositions do
		local row = source.template_compositions[index]
		local sample = samples[row.id]
		if sample then
			local widths = assert(template_session.widths(row.id))
			assert(widths.fitting_width == sample[3] and
				widths.blend_width == sample[4])
			widths.fitting_width = 1
			assert(template_session.widths(row.id).fitting_width == sample[3])
			local blend_probe = math.ceil(sample[3] / 2) +
				(sample[4] - sample[3]) / 4
			local blend_weight = template.feature_blend_weight(sample[3], sample[4],
				blend_probe, 0)
			assert(blend_weight == Q / 2)
			values[#values + 1] = table.concat({row.id, sample[1], sample[2],
				template_session.evaluate(row.id, sample[1], sample[2]),
				sample[3], sample[4], blend_weight}, ":")
		end
	end
	assert(#values == 14)
	local result = table.concat(values, ",")
	assert(result ==
		"compose_start:-63:1:0:128:256:32768," ..
		"compose_capital_dwarf:96:0:524288:512:704:32768," ..
		"compose_capital_human:0:176:65536:512:704:32768," ..
		"compose_capital_elf:112:0:393216:512:704:32768," ..
		"compose_capital_undead:96:0:393216:512:704:32768," ..
		"compose_capital_orc:232:0:524288:512:704:32768," ..
		"compose_capital_troll:84:0:-393216:512:704:32768," ..
		"compose_village:-48:0:-32768:96:160:32768," ..
		"compose_outpost:-31:1:0:64:112:32768," ..
		"compose_bandit_home:17:-19:0:64:112:32768," ..
		"compose_bandit_frontier:0:-32:-32768:64:112:32768," ..
		"compose_mine:39:0:0:80:128:32768," ..
		"compose_dragon:42:0:262144:96:160:32768," ..
		"compose_apex_mine:32:0:262144:96:160:32768")
	return result
end)

add_case("composition_deferred_4", true, function()
	local expected = {
		{"compose_mirefolk", "provider_unavailable:causeway"},
		{"compose_clash", "provider_unavailable:cross_section"},
		{"compose_rare_route", "provider_unavailable:cross_section"},
		{"compose_coastal_housing_core",
			"provider_unavailable:housing_smoothing"},
	}
	for index = 1, #expected do
		expect_error(expected[index][2], function()
			template_session.evaluate(expected[index][1], 0, 0, 64)
		end)
	end
	for _, primitive_id in ipairs({"causeway", "cross_section",
			"housing_smoothing"}) do
		expect_error("provider_unavailable:" .. primitive_id, function()
			template_session.evaluate_primitive(primitive_id, {}, 0, 0, 64)
		end)
	end
	return "causeway,cross_section,cross_section,housing_smoothing"
end)

add_case("feature_blend_and_natural", false, function()
	assert(template.centered_contains(4, -2, -2))
	assert(template.centered_contains(4, 1, 1))
	assert(not template.centered_contains(4, 2, 0))
	assert(template.feature_blend_weight(4, 8, 1, 0) == Q)
	assert(template.feature_blend_weight(4, 8, 2, 0) == Q)
	assert(template.feature_blend_weight(4, 8, 3, 0) == Q / 2)
	assert(template.feature_blend_weight(4, 8, 4, 0) == 0)
	assert(template.feature_blend_weight(4, 8, -4, 0) == 0)
	local target = template.blend_to_natural(10, 20, 3 * Q, Q / 2)
	assert(target == 17)
	return table.concat({Q, Q / 2, 0, target}, ":")
end)

add_case("api_defensive_source", false, function()
	expect_error("unknown dependency", function()
		dofile(wp40 .. "/geometry/template.lua")({deterministic = deterministic,
			exact = exact, extra = true})
	end)
	expect_error("dependencies are not a plain table", function()
		dofile(wp40 .. "/geometry/relief.lua")(setmetatable({}, {}))
	end)
	local incomplete_deterministic = {}
	for key, value in pairs(deterministic) do
		incomplete_deterministic[key] = value
	end
	incomplete_deterministic.value_noise_2d = nil
	expect_error("dependency is missing", function()
		dofile(wp40 .. "/geometry/relief.lua")({canonical = canonical,
			deterministic = incomplete_deterministic, exact = exact,
			raw_sha256 = raw_sha256})
	end)
	expect_error("unknown relief option", function()
		relief.new(source, "0", 1, {unknown = 1})
	end)
	expect_error("canonical unsigned decimal", function()
		relief.new(source, "01", 1)
	end)
	return "dependency_metatable,extra_dependency,option,seed"
end)

assert(#cases == 28, "aggregate case roster changed: " .. #cases)

local result_rows = {"case_id\tresult"}
local shared_rows = {"case_id\tresult"}
local aggregate_count = 0
local shared_count = 0
local suite_started = os.clock()
for index = 1, #cases do
	local row = cases[index]
	if mode == "full" or row.targeted then
		local result = row.callback()
		assert(type(result) == "string" and not result:find("[\r\n\t]"),
			"case result is not one TSV field: " .. row.id)
		local line = row.id .. "\t" .. result
		result_rows[#result_rows + 1] = line
		aggregate_count = aggregate_count + 1
		if row.targeted then
			shared_rows[#shared_rows + 1] = line
			shared_count = shared_count + 1
		end
	end
end

local ellipse_count = 0
if mode == "full" then
	local file = assert(io.open(repo ..
		"/tools/wp40/fixtures/t2_fields/ellipse-disagreements-v1.tsv", "rb"))
	local fixture_session = relief.new(source, "0", 1)
	local fixture_seen, ellipse_order = {}, {}
	for landmark_index = 1, #source.landmarks do
		if source.landmarks[landmark_index].primitive == "ellipse" then
			ellipse_order[source.landmarks[landmark_index].id] = landmark_index
		end
	end
	local previous_order, previous_z, previous_x = 0
	local disagreement_ids, disagreement_id_count = {}, 0
	local zero_distance_count, negative_distance_count = 0, 0
	local header = assert(file:read("*l"))
	assert(header == "landmark_id\tx\tz\texact_inside\tsigned_inside\tsigned_distance_q")
	for line in file:lines() do
		local fields = split_tsv(line)
		assert(#fields == 6)
		local fixture_key = fields[1] .. "\0" .. fields[2] .. "\0" .. fields[3]
		assert(not fixture_seen[fixture_key], "duplicate ellipse fixture query")
		fixture_seen[fixture_key] = true
		local order = assert(ellipse_order[fields[1]])
		local fixture_x, fixture_z = assert(tonumber(fields[2])),
			assert(tonumber(fields[3]))
		assert(order > previous_order or order == previous_order and
			(fixture_z > previous_z or fixture_z == previous_z and
			fixture_x > previous_x), "ellipse fixture ordering drift")
		if not disagreement_ids[fields[1]] then
			disagreement_ids[fields[1]] = true
			disagreement_id_count = disagreement_id_count + 1
		end
		previous_order, previous_z, previous_x = order, fixture_z, fixture_x
		assert(fields[4] == "0" and fields[5] == "1",
			"ellipse disagreement direction drift")
		if fields[6] == "0" then zero_distance_count = zero_distance_count + 1
		elseif fields[6] == "-120" then
			negative_distance_count = negative_distance_count + 1
		else error("ellipse disagreement distance roster drift", 0) end
		local result = fixture_session.mask(fields[1],
			fixture_x, fixture_z)
		local exact_inside = fields[4] == "1"
		local signed_inside = fields[5] == "1"
		assert(result.inside == exact_inside)
		assert((result.signed_distance_q <= 0) == signed_inside)
		assert(result.signed_distance_q == assert(tonumber(fields[6])))
		assert(exact_inside ~= signed_inside)
		ellipse_count = ellipse_count + 1
		result_rows[#result_rows + 1] = "ellipse_" ..
			("%03d"):format(ellipse_count) .. "\t" .. line:gsub("\t", ":")
	end
	assert(file:close())
	assert(ellipse_count == 264 and disagreement_id_count == 20 and
		zero_distance_count == 260 and negative_distance_count == 4)
end

assert(shared_count == 17, "targeted KAT roster changed: " .. shared_count)
local sample_count = aggregate_count + ellipse_count
if mode == "full" then assert(sample_count == 292)
else assert(sample_count == 17) end

local function canonical_rows(rows)
	local values = {}
	for index = 1, #rows do values[index] = canonical.text(rows[index]) end
	return canonical.encode(canonical.array(values))
end

write_file(output_dir .. "/" .. mode .. "-results.tsv",
	table.concat(result_rows, "\n") .. "\n")
write_file(output_dir .. "/" .. mode .. "-results.bin",
	canonical_rows(result_rows))
write_file(output_dir .. "/shared-kats.bin", canonical_rows(shared_rows))

local elapsed_cpu = os.clock() - suite_started
local metric_rows = {"metric\tvalue",
	"mode\t" .. mode,
	"sample_count\t" .. sample_count,
	"aggregate_count\t" .. aggregate_count,
	"ellipse_count\t" .. ellipse_count,
	"targeted_count\t" .. shared_count,
	"transport_sha_calls\t" .. transport_sha_calls,
	("suite_cpu_seconds\t%.6f"):format(elapsed_cpu)}
local metric_names = {}
for name in pairs(performance_metrics) do metric_names[#metric_names + 1] = name end
table.sort(metric_names)
for index = 1, #metric_names do
	local name = metric_names[index]
	local value = performance_metrics[name]
	if type(value) == "number" and value % 1 ~= 0 then value = ("%.6f"):format(value) end
	metric_rows[#metric_rows + 1] = name .. "\t" .. tostring(value)
end
write_file(output_dir .. "/metrics.tsv", table.concat(metric_rows, "\n") .. "\n")

print(("WP40 C-a1 fields passed mode=%s samples=%d aggregate=%d ellipse=%d " ..
	"targeted=%d transport_sha=%d cpu=%.6f"):format(mode, sample_count,
	aggregate_count, ellipse_count, shared_count, transport_sha_calls, elapsed_cpu))

if request_file then assert(request_file:close()) end
if response_file then assert(response_file:close()) end
