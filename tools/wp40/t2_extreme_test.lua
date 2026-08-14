local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local function safe_absolute_path(value)
	assert(type(value) == "string" and value:match("^/[A-Za-z0-9._/-]+$") and
		not value:find("/../", 1, true) and not value:find("/./", 1, true) and
		not value:find("//", 1, true), "unsafe absolute path")
	return value
end
safe_absolute_path(repo)
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-extreme%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
safe_absolute_path(scratch)
assert(not pcall(safe_absolute_path, "/tmp/unsafe;false"))

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local sha_cache, sha_counter, sha_calls, sha_misses = {}, 0, 0, 0
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function raw_sha256(data)
	sha_calls = sha_calls + 1
	local cached = sha_cache[data]
	if cached then return cached end
	sha_misses = sha_misses + 1
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	file = assert(io.open(output, "rb"))
	local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close()) assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

-- The Foundation runner proves the length-framed Python batch helper against
-- direct sha256sum even while the retained worker is R16-gated. Each eventual
-- shard repeats these vectors and additionally compares its first eight real
-- pending noise inputs before candidate 1.
local foundation_batch_vectors = {
	{bytes = "", digest =
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	{bytes = "abc", digest =
		"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
	{bytes = string.char(0, 255, 1, 254), digest =
		"5d8d910591d272938aef5f966e0816e374beaf7b5adf02cca5f8f770596c2ce3"},
}
local foundation_batch_input = scratch .. "/foundation-batch.bin"
local foundation_batch_output = scratch .. "/foundation-batch.out"
local foundation_batch_file = assert(io.open(foundation_batch_input, "wb"))
for index = 1, #foundation_batch_vectors do
	local bytes = foundation_batch_vectors[index].bytes
	assert(foundation_batch_file:write(tostring(#bytes), "\n", bytes))
end
assert(foundation_batch_file:close())
local foundation_status, foundation_reason, foundation_code = os.execute(
	"python3 " .. repo .. "/tools/wp40/t2_sha256_batch.py " ..
	foundation_batch_input .. " " .. foundation_batch_output)
assert(foundation_status == 0 or foundation_status == true and
	foundation_reason == "exit" and foundation_code == 0)
foundation_batch_file = assert(io.open(foundation_batch_output, "rb"))
local foundation_batch_bytes = assert(foundation_batch_file:read("*a"))
assert(foundation_batch_file:close() and
	#foundation_batch_bytes == #foundation_batch_vectors * 32)
for index = 1, #foundation_batch_vectors do
	local row = foundation_batch_vectors[index]
	local digest = foundation_batch_bytes:sub(index * 32 - 31, index * 32)
	assert(digest == from_hex(row.digest) and digest == raw_sha256(row.bytes),
		"Foundation Python batch SHA differs from direct sha256sum")
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do result[deep_copy(key, seen)] = deep_copy(child, seen) end
	return result
end

local function deep_equal(a, b, seen)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	seen = seen or {}
	if seen[a] then return seen[a] == b end
	seen[a] = b
	for key, value in pairs(a) do
		if not deep_equal(value, b[key], seen) then return false end
	end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

local function assert_data_only(value, seen, label)
	local kind = type(value)
	assert(kind == "nil" or kind == "boolean" or kind == "number" or
		kind == "string" or kind == "table", label .. " has " .. kind)
	if kind ~= "table" then return end
	assert(getmetatable(value) == nil, label .. " has a metatable")
	seen = seen or {}
	assert(not seen[value], label .. " has an alias or cycle")
	seen[value] = true
	for key, child in pairs(value) do
		assert_data_only(key, seen, label)
		assert_data_only(child, seen, label)
	end
end

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error" .. (fragment and " containing " .. fragment or ""))
	if fragment then assert(tostring(message):find(fragment, 1, true), tostring(message)) end
	return tostring(message)
end

local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({deterministic = deterministic})
local raster_factory = dofile(wp40 .. "/geometry/raster.lua")
local raster = raster_factory({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator_module = dofile(wp40 .. "/validation/t2_source.lua")
local seed_corpus = dofile(wp40 .. "/seed_corpus.lua")

local old_arg = arg
arg = {repo}
dofile(repo .. "/tools/wp43/materials_test.lua")
arg = old_arg
local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
local projection = handoff.project(grug_materials)
local function projection_keys(rows)
	local result = {}
	for index = 1, #rows do result[index] = rows[index].key or rows[index]._projection_key end
	return result
end
local vocabulary = {resource_keys = projection_keys(projection.resources),
	resource_rows = projection.resources,
	cultural_keys = projection_keys(projection.cultural_materials),
	wood_keys = projection_keys(projection.signature_woods)}
local authority = dofile(repo .. "/tools/wp40/t2_extreme_authority.lua")({
	raw_sha256 = raw_sha256})
local authority_files = authority.capture_files(repo)
local authority_snapshot = authority.bind_vocabulary(authority_files, vocabulary)
assert(authority_snapshot.vocabulary_sha256 ==
	"6d77298bb1861e91fb306bfe59cc8996bc64d7544034b47ed7465ba9c4aa164f")
assert(authority.verify(repo, authority_snapshot, vocabulary))
local git_provenance = authority.git_provenance(repo, scratch)
assert(authority.verify_git_provenance(repo, scratch, git_provenance.commit,
	git_provenance.tree))
expect_error("commit/tree provenance changed", function()
	authority.verify_git_provenance(repo, scratch, string.rep("0", 40),
		git_provenance.tree)
end)
local measurement_ranges = authority.canonical_measurement_ranges()
assert(authority.validate_measurement_ranges(measurement_ranges))
assert(#measurement_ranges == 8 and measurement_ranges[1].first == 0 and
	measurement_ranges[1].last == 511 and measurement_ranges[8].first == 3584 and
	measurement_ranges[8].last == 4095)
for _, mutate in ipairs({
	function(rows) table.remove(rows) end,
	function(rows) rows[2].first = rows[2].first + 1 end,
	function(rows) rows[9] = {first = 4096, last = 4607} end,
}) do
	local corrupt = deep_copy(measurement_ranges)
	mutate(corrupt)
	expect_error("measurement", function()
		authority.validate_measurement_ranges(corrupt)
	end)
end
local retained_path = authority.retained_shard_path(0, 511)
assert(retained_path ==
	"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-0000-0511.tsv" and
	authority.validate_retained_shard_path(retained_path, 0, 511))
for _, path in ipairs({repo .. "/" .. retained_path,
	"tools/wp40/fixtures/../fixtures/t2_extreme_e0/shard-luajit-0000-0511.tsv",
	"tools/wp40/fixtures/t2_extreme_e0/foreign.tsv"}) do
	expect_error("repo-relative", function()
		authority.validate_retained_shard_path(path, 0, 511)
	end)
end
expect_error("commit/tree provenance changed", function()
	authority.verify_git_provenance(repo, scratch, git_provenance.commit,
		string.rep("0", 40))
end)
local changed_vocabulary = deep_copy(vocabulary)
changed_vocabulary.resource_keys[1] = changed_vocabulary.resource_keys[1] .. "_wrong"
expect_error("vocabulary projection changed", function()
	authority.bind_vocabulary(authority_files, changed_vocabulary)
end)
local changed_authority = deep_copy(authority_snapshot)
local changed_path = authority.paths[1]
changed_authority.files[changed_path] = changed_authority.files[changed_path] .. "\n"
expect_error("Authority-DAG bytes changed", function()
	authority.verify(repo, changed_authority, vocabulary)
end)

local stage1 = source_validator_module.new_offline_test_adapter(canonical, raw_sha256)
local validator_calls = 0
local counted_validator = {}
function counted_validator.validate(...)
	validator_calls = validator_calls + 1
	return stage1.validate(...)
end

local partition_factory = dofile(wp40 .. "/geometry/partition.lua")
local function make_partition(active_source, active_vocabulary, active_validator,
		active_raw_sha256, active_raster)
	return partition_factory({canonical = canonical, deterministic = deterministic,
		exact = exact, raster = active_raster or raster,
		raw_sha256 = active_raw_sha256 or raw_sha256,
		source = active_source or source,
		source_validator = active_validator or counted_validator,
		vocabulary = active_vocabulary or vocabulary})
end

local partition = make_partition()
local session = partition.new_extreme_scalar_session()
assert(validator_calls == 1, "extreme session did not validate Source exactly once")
local seed_zero_records = session("0")
local high_seed_records = session("18446744073709551615")
assert(validator_calls == 1, "extreme session revalidated Source per seed")
assert(#seed_zero_records == 66 and #high_seed_records == 66)
assert_data_only(seed_zero_records, nil, "seed-zero scalar records")
assert_data_only(high_seed_records, nil, "high-bit scalar records")
assert(partition.source_validator == nil and partition.unchecked_validator == nil and
	partition.materialize_boundary_seed == nil,
	"private session authority escaped the partition module")

local function named_scalar(record, field, wanted)
	for index = 1, #record[field] do
		if record[field][index].name == wanted then return record[field][index].value end
	end
	error(record.id .. " lacks " .. wanted)
end
local function named_array(record, field, wanted)
	for index = 1, #record[field] do
		if record[field][index].name == wanted then return record[field][index].values end
	end
	error(record.id .. " lacks " .. wanted)
end
local source_max = {}
for _, collection in ipairs({source.perimeters, source.islands, source.land_edges}) do
	for index = 1, #collection do source_max[collection[index].id] =
		collection[index].max_displacement end
end
local function compiled_scalar_records(compiled)
	local records = {}
	local function append(family, rows)
		for row_index = 1, #rows do
			local row = rows[row_index]
			local xz = named_array(row, "signed_arrays", "scalar_sample_xz")
			local scalar = named_array(row, "signed_arrays", "scalar_q")
			local segments = named_array(row, "unsigned_arrays",
				"scalar_source_segment")
			local locals = named_array(row, "unsigned_arrays", "scalar_local_station")
			assert(#xz == #scalar * 2 and #segments == #scalar and #locals == #scalar)
			local samples = {}
			for index = 1, #scalar do samples[index] = {x = xz[index * 2 - 1],
				z = xz[index * 2], scalar_q = scalar[index],
				source_segment = segments[index], local_station = locals[index]} end
			records[#records + 1] = {family = family, id = row.id,
				numeric_id = row.numeric_id, max_displacement = assert(source_max[row.id]),
				topology_ceiling_nodes = named_scalar(row, "unsigned_values",
					"topology_ceiling_nodes"), samples = samples}
		end
	end
	append("perimeter", compiled.families.perimeters)
	append("island", compiled.families.islands)
	append("land_edge", compiled.families.land_boundaries)
	return records
end

local function plain_bytes(value, seen)
	local kind = type(value)
	if kind == "string" then return "s" .. #value .. ":" .. value end
	if kind == "number" then assert(value % 1 == 0); return "n" .. tostring(value) .. ";" end
	if kind == "boolean" then return value and "b1" or "b0" end
	if kind == "nil" then return "z" end
	assert(kind == "table" and getmetatable(value) == nil)
	seen = seen or {}
	assert(not seen[value], "compiled graph contains alias/cycle")
	seen[value] = true
	local count, array = 0, true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then array = false end
	end
	if array and count == #value then
		local parts = {"a", tostring(count), ":"}
		for index = 1, count do parts[#parts + 1] = plain_bytes(value[index], seen) end
		seen[value] = nil
		return table.concat(parts)
	end
	local keys = {}
	for key in pairs(value) do assert(type(key) == "string"); keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {"m", tostring(#keys), ":"}
	for index = 1, #keys do
		parts[#parts + 1] = plain_bytes(keys[index], seen)
		parts[#parts + 1] = plain_bytes(value[keys[index]], seen)
	end
	seen[value] = nil
	return table.concat(parts)
end

-- Session isolation: caller mutation after validation cannot affect the
-- isolated reader, and each result is a fresh alias-free projection.
local isolated_again = session("0")
assert(deep_equal(seed_zero_records, isolated_again))
seed_zero_records[1].samples[1].scalar_q = seed_zero_records[1].samples[1].scalar_q + 1
local isolated_third = session("0")
assert(deep_equal(isolated_again, isolated_third), "scalar result mutation leaked")
local saved_source_id = source.perimeters[1].id
local saved_vocabulary = vocabulary.resource_keys[1]
source.perimeters[1].id = "mutated_after_session"
vocabulary.resource_keys[1] = "mutated_after_session"
assert(deep_equal(isolated_again, session("0")), "session aliases caller inputs")
source.perimeters[1].id = saved_source_id
vocabulary.resource_keys[1] = saved_vocabulary

-- Direct reads retain the defensive Stage-1 validation on every call.
local before_direct = validator_calls
local direct_zero = partition.extreme_scalar_records("0")
local direct_high = partition.extreme_scalar_records("18446744073709551615")
assert(validator_calls == before_direct + 2,
	"direct scalar projection did not validate each call")
assert(deep_equal(direct_zero, isolated_again) and
	deep_equal(direct_high, high_seed_records),
	"session scalar projection differs from defensive direct projection")

local compile_before = validator_calls
local compiled_zero = partition.compile("0")
assert(validator_calls == compile_before + 1,
	"full partition compile changed defensive validation cadence")
assert(deep_equal(compiled_scalar_records(compiled_zero), isolated_again),
	"Seed0 scalar projection differs from the compile consumer")
local compiled_zero_sha256 = canonical.hex(raw_sha256(plain_bytes(compiled_zero)))
assert(compiled_zero_sha256 ==
	"1e1b60dc0b636d718b9b0f3154904fa6ae78733179dc687e41542c878bf20969",
	"Seed0 compiled family bytes changed from db62f43")
print("WP40 T2 E0 Seed0 full partition SHA-256 " .. compiled_zero_sha256)
local partition_module_file = assert(io.open(wp40 .. "/geometry/partition.lua", "rb"))
local partition_module_bytes = assert(partition_module_file:read("*a"))
assert(partition_module_file:close())
local partition_module_sha256 = canonical.hex(raw_sha256(partition_module_bytes))
local stage2_fixture = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/stage2_blocked.lua")
local stage2_fixture_fields = {
	"status", "scope", "seed", "fixed_slot", "bank_id", "previous", "current",
	"target", "end_terminal", "authored_index", "authored_away_index", "distance",
	"candidate",
	"own_cardinal_water_eswn", "foreign_cardinal_water_eswn", "in_envelope",
	"dry", "footprint_class", "aperture_member",
	"source_checksum", "boundary_policy_checksum", "partition_sha256",
	"interpreter", "reproduce", "diagnostic",
}
local function validate_stage2_fixture(row, actual_diagnostic)
	assert_data_only(row, nil, "Stage2 blocker fixture")
	local expected_fields = {}
	for index = 1, #stage2_fixture_fields do
		expected_fields[stage2_fixture_fields[index]] = true
	end
	local count = 0
	for key in pairs(row) do
		assert(expected_fields[key], "Stage2 blocker fixture has unknown field")
		count = count + 1
	end
	assert(count == #stage2_fixture_fields,
		"Stage2 blocker fixture field roster changed")
	assert(row.status == "STAGE2_BLOCKED" and
		row.scope == "R7_SCALAR_MEASUREMENT_ONLY" and row.fixed_slot == 19 and
		row.seed == "18446744073709551615")
	assert(row.bank_id == "bay_bank:kragmar_west:stillgrave" and
		row.end_terminal == "bay_mouth_aperture:kragmar_west:before" and
		row.authored_index == 3581 and row.authored_away_index == 3580)
	local function point(point, x, z)
		assert(type(point) == "table" and getmetatable(point) == nil and
			point.x == x and point.z == z)
	end
	point(row.previous, -1141, 2241)
	point(row.current, -1140, 2241)
	point(row.target, -1406, 2939)
	assert(row.distance == 1 and row.candidate == false and row.dry == true and
		row.in_envelope == true and row.footprint_class == 1 and
		row.aperture_member == false and row.own_cardinal_water_eswn == "0000" and
		row.foreign_cardinal_water_eswn == "0000")
	assert(row.source_checksum ==
		"9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68" and
		row.boundary_policy_checksum ==
		"3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140" and
		row.partition_sha256 == partition_module_sha256 and
		(type(actual_diagnostic) ~= "string" or row.diagnostic == actual_diagnostic))
	return true
end
local high_compile_ok, high_compile_error = pcall(partition.compile,
	"18446744073709551615")
assert(not high_compile_ok and tostring(high_compile_error):find(
	"bay_bank:kragmar_west:stillgrave has an invalid start half-edge", 1, true),
	tostring(high_compile_error))
assert(validate_stage2_fixture(stage2_fixture, tostring(high_compile_error)))
for _, mutate in ipairs({
	function(row) row.current.x = row.current.x + 1 end,
	function(row) row.candidate = true end,
	function(row) row.distance = 2 end,
	function(row) row.diagnostic = row.diagnostic .. " changed" end,
	function(row) row.source_checksum = string.rep("0", 64) end,
}) do
	local corrupt = deep_copy(stage2_fixture)
	mutate(corrupt)
	assert(not pcall(validate_stage2_fixture, corrupt, tostring(high_compile_error)),
		"Stage2 blocker fixture corruption was accepted")
end
print("WP40 T2 E0 STAGE2_BLOCKED seed=18446744073709551615 " ..
	"source=9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68 " ..
	"boundary=3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140 " ..
	"partition=" .. partition_module_sha256 .. " diagnostic=" ..
	tostring(high_compile_error))

local invalid_source = deep_copy(source)
invalid_source.perimeters[1].polygon[1].x =
	invalid_source.perimeters[1].polygon[1].x + 1
local invalid_source_error = expect_error(nil, function()
	make_partition(invalid_source, vocabulary,
		source_validator_module).new_extreme_scalar_session()
end)
local invalid_vocabulary = deep_copy(vocabulary)
invalid_vocabulary.resource_keys = {}
local invalid_vocabulary_error = expect_error(nil, function()
	make_partition(source, invalid_vocabulary,
		source_validator_module).new_extreme_scalar_session()
end)
assert(invalid_source_error ~= "" and invalid_vocabulary_error ~= "")

local extreme_factory = dofile(wp40 .. "/geometry/extreme.lua")
local extreme = extreme_factory({deterministic = deterministic, exact = exact,
	raw_sha256 = raw_sha256, scalar_reader = session,
	seed_corpus = seed_corpus, source = source})

-- Independently reconstruct the seed-invariant selector identities from the
-- checksum-declared controls.  This path never consumes scalar projection
-- records.  It binds effective D, H55 exclusion, span-union trimming, closed
-- join dedup, and the island closed-arc identity/order.
local function hex(bytes)
	return (bytes:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end
local coast_segments = {}
for index = 1, #source.perimeter_spans do
	local span = source.perimeter_spans[index]
	coast_segments[span.perimeter_id] = coast_segments[span.perimeter_id] or {}
	for segment = span.first_segment - 1, span.last_segment - 1 do
		coast_segments[span.perimeter_id][segment] = true
	end
end
local effective_land = {}
local land_by_id = {}
for index = 1, #source.land_edges do land_by_id[source.land_edges[index].id] =
	source.land_edges[index] end
for index = 1, #source.junction_departures do
	local departure = source.junction_departures[index]
	local row = assert(land_by_id[departure.edge_id])
	local from = departure.edge_endpoint == "from"
	local junction = row.control[from and 1 or #row.control]
	local adjacent = row.control[from and 2 or #row.control - 1]
	local derived = {x = exact.safe_sum(junction.x,
		adjacent.x > junction.x and 1 or -1, "identity D x"),
		z = exact.safe_sum(junction.z, adjacent.z > junction.z and 1 or -1,
			"identity D z")}
	local control = deep_copy(row.control)
	if from then table.insert(control, 2, derived) else table.insert(control, #control, derived) end
	effective_land[row.id] = control
end
local function identity_lines(rows, family, id_field, selected)
	local lines = {}
	for row_index = 1, #rows do
		local item = rows[row_index]
		local row, numeric_id, id = item.row, item.numeric_id, item[id_field]
		local stations = raster.authored_stations(item.control, item.closed)
		for station_index = 1, #stations do
			local station = stations[station_index]
			if selected(item, station) then
				lines[#lines + 1] = table.concat({family, id, tostring(numeric_id),
					tostring(station.source_segment), tostring(station.local_station),
					tostring(station.x), tostring(station.z),
					tostring(row.max_displacement * deterministic.Q)}, ";")
			end
		end
	end
	return lines
end
local perimeter_identity_rows = {}
for index = 1, #source.perimeters do
	local row = source.perimeters[index]
	perimeter_identity_rows[index] = {row = row, numeric_id = index,
		id = row.id, control = row.polygon, closed = true}
end
table.sort(perimeter_identity_rows, function(a, b) return a.id < b.id end)
local coast_identity_lines = identity_lines(perimeter_identity_rows,
	"perimeter", "id", function(item, station)
		return item.row.max_displacement > 0 and
			coast_segments[item.row.id][station.source_segment] == true
	end)
local island_identity_rows = {}
for index = 1, #source.islands do
	local row = source.islands[index]
	island_identity_rows[index] = {row = row, numeric_id = index,
		arc_id = row.closed_arc_id, control = row.polygon, closed = true}
end
table.sort(island_identity_rows, function(a, b) return a.arc_id < b.arc_id end)
local island_lines = identity_lines(island_identity_rows, "island_arc", "arc_id",
	function(item) return item.row.max_displacement > 0 end)
for index = 1, #island_lines do coast_identity_lines[#coast_identity_lines + 1] =
	island_lines[index] end
local land_identity_rows = {}
for index = 1, #source.land_edges do
	local row = source.land_edges[index]
	if row.max_displacement > 0 then land_identity_rows[#land_identity_rows + 1] =
		{row = row, numeric_id = row.numeric_id, id = row.id,
			control = effective_land[row.id] or row.control, closed = false} end
end
table.sort(land_identity_rows, function(a, b) return a.numeric_id < b.numeric_id end)
local noncoast_identity_lines = identity_lines(land_identity_rows, "land_edge", "id",
	function() return true end)
local independent_identity = {
	coast_count = #coast_identity_lines,
	coast_sha256 = hex(raw_sha256(table.concat(coast_identity_lines, "\n") .. "\n")),
	noncoast_count = #noncoast_identity_lines,
	noncoast_sha256 = hex(raw_sha256(table.concat(noncoast_identity_lines, "\n") .. "\n")),
}

local noise_lattice_by_key = {}
local function add_noise_sites(items, base_period)
	for item_index = 1, #items do
		local item = items[item_index]
		if item.row.max_displacement > 0 then
			local stations = raster.authored_stations(item.control, item.closed)
			for station_index = 1, #stations do
				local station = stations[station_index]
				for lane = 0, 1 do
					local period = base_period * (lane + 1)
					local lx = deterministic.floor_div(station.x, period)
					local lz = deterministic.floor_div(station.z, period)
					for dx = 0, 1 do for dz = 0, 1 do
						local id = table.concat({item.row.noise_domain, lane,
							lx + dx, lz + dz}, ";")
						noise_lattice_by_key[id] = {domain = item.row.noise_domain,
							lane = lane, x = lx + dx, z = lz + dz}
					end end
				end
			end
		end
	end
end
add_noise_sites(perimeter_identity_rows, 512)
add_noise_sites(island_identity_rows, 256)
add_noise_sites(land_identity_rows, 384)
local noise_lattices = {}
for _, row in pairs(noise_lattice_by_key) do noise_lattices[#noise_lattices + 1] = row end
table.sort(noise_lattices, function(a, b)
	return a.domain < b.domain or a.domain == b.domain and
		(a.lane < b.lane or a.lane == b.lane and
			(a.x < b.x or a.x == b.x and a.z < b.z))
end)

local batch_cache, permanent_hash_cache = {}, {}
local batch_mode = "direct"
local batch_pending, batch_pending_seen = {}, {}
local batch_calls, batch_cache_misses, batch_processes = 0, 0, 0
local zero_digest = string.rep(string.char(0), 32)
local function queue_hash_input(data)
	if not batch_pending_seen[data] then
		batch_pending_seen[data] = true
		batch_pending[#batch_pending + 1] = data
	end
end
local function batch_raw_sha256(data)
	batch_calls = batch_calls + 1
	local cached = batch_cache[data] or permanent_hash_cache[data]
	if cached then return cached end
	batch_cache_misses = batch_cache_misses + 1
	if batch_mode == "discover" then queue_hash_input(data); return zero_digest end
	if batch_mode == "strict" then
		queue_hash_input(data)
		error("WP40 T2 batch SHA cache miss", 0)
	end
	local digest = raw_sha256(data)
	permanent_hash_cache[data] = digest
	return digest
end
local function fill_batch()
	if #batch_pending == 0 then return 0 end
	local input_path = scratch .. "/sha-batch.bin"
	local output_path = scratch .. "/sha-batch.out"
	local file = assert(io.open(input_path, "wb"))
	for index = 1, #batch_pending do
		local data = batch_pending[index]
		assert(file:write(tostring(#data), "\n", data))
	end
	assert(file:close())
	local status, reason, code = os.execute("python3 " ..
		repo .. "/tools/wp40/t2_sha256_batch.py " .. input_path .. " " .. output_path)
	assert(status == 0 or status == true and reason == "exit" and code == 0,
		"SHA-256 batch helper failed")
	batch_processes = batch_processes + 1
	file = assert(io.open(output_path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	assert(#bytes == #batch_pending * 32, "SHA-256 batch output count changed")
	for index = 1, #batch_pending do
		batch_cache[batch_pending[index]] = bytes:sub(index * 32 - 31, index * 32)
	end
	local count = #batch_pending
	batch_pending, batch_pending_seen = {}, {}
	return count
end

batch_mode = "direct"
local batch_raster = raster_factory({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = batch_raw_sha256})
local batch_partition = make_partition(source, vocabulary, source_validator_module,
	batch_raw_sha256, batch_raster)
local batch_session = batch_partition.new_extreme_scalar_session()
for data, digest in pairs(batch_cache) do permanent_hash_cache[data] = digest end
batch_cache = {}
local current_batch_seed, current_batch_records
local batch_extreme = extreme_factory({deterministic = deterministic, exact = exact,
	raw_sha256 = batch_raw_sha256,
	scalar_reader = function(seed)
		assert(seed == current_batch_seed and current_batch_records)
		return deep_copy(current_batch_records)
	end,
	seed_corpus = seed_corpus, source = source})

local function preload_candidate(seed)
	batch_cache, batch_pending, batch_pending_seen = {}, {}, {}
	batch_mode = "discover"
	local hash = deterministic.new_hash(canonical, batch_raw_sha256,
		"grug_wp40_geometry_source_v1", seed)
	for index = 1, #noise_lattices do
		local row = noise_lattices[index]
		hash.signed_noise(row.domain, "", {row.x, row.z}, 0, row.lane)
	end
	local discovered = fill_batch()
	-- Real rejection chains are digest-dependent.  Close them before the
	-- authoritative scalar pass, then require that pass to have zero misses.
	while true do
		batch_mode = "strict"
		local ok, message = pcall(function()
			for index = 1, #noise_lattices do
				local row = noise_lattices[index]
				hash.signed_noise(row.domain, "", {row.x, row.z}, 0, row.lane)
			end
		end)
		if ok then break end
		assert(tostring(message):find("batch SHA cache miss", 1, true), tostring(message))
		assert(fill_batch() > 0)
	end
	local misses_before = batch_cache_misses
	local direct_calls_before = sha_calls
	local records = batch_session(seed)
	assert(batch_cache_misses == misses_before,
		"authoritative scalar pass had an unprepared SHA input")
	assert(sha_calls == direct_calls_before,
		"authoritative scalar pass bypassed the batched SHA seam")
	return records, discovered
end

local n, d = extreme.rational_add(1, 2, -1, 3)
assert(n == 1 and d == 6)
n, d = extreme.rational_add(-1, 2, -1, 3)
assert(n == -5 and d == 6)
n, d = extreme.rational_mean(-3, 2, 3)
assert(n == -1 and d == 2)
assert(extreme.rational_compare(-1, 2, -2, 3) > 0)
assert(extreme.rational_compare(1, 2, 2, 4) == 0)
assert(extreme.rational_compare(-2, 3, -1, 2) < 0)
n, d = extreme.rational_add(1, 2, -1, 2)
assert(n == 0 and d == 1)
n, d = extreme.rational_add(exact.MAX_SAFE - 1, exact.MAX_SAFE,
	-(exact.MAX_SAFE - 1), exact.MAX_SAFE)
assert(n == 0 and d == 1)
n, d = extreme.rational_add(exact.MAX_SAFE - 1, exact.MAX_SAFE - 1, -1, 1)
assert(n == 0 and d == 1)
n, d = extreme.rational_mean(exact.MAX_SAFE - 1, exact.MAX_SAFE - 1,
	exact.MAX_SAFE)
assert(n == 1 and d == exact.MAX_SAFE)
expect_error("score addition", function()
	extreme.rational_add(exact.MAX_SAFE, 1, exact.MAX_SAFE, 1)
end)
expect_error("score addition", function()
	extreme.rational_add(exact.MAX_SAFE, 2, 1, 3)
end)
expect_error("score denominator", function()
	extreme.rational_add(1, exact.MAX_SAFE, -1, exact.MAX_SAFE - 2)
end)
expect_error("integer range", function() extreme.rational_add(0.5, 1, 0, 1) end)
expect_error("integer range", function() extreme.rational_add(0, 0, 0, 1) end)
expect_error("integer range", function() extreme.rational_mean(1, 1, 0) end)
expect_error("integer range", function() extreme.rational_compare(1, 0, 1, 1) end)
assert(extreme.decimal_less("9", "10") and
	not extreme.decimal_less("18446744073709551615", "10"))
expect_error("canonical unsigned", function() extreme.decimal_less("01", "1") end)

local candidate_zero = seed_corpus.extreme_candidate(0, raw_sha256)
assert(candidate_zero.label == "grudgelands-wp40-extreme-0000" and
	candidate_zero.digest ==
		"2e0c0041e1bcc0abf1cf4f3e024dfc28d32b05b4742249335b4fa9979261f2c8" and
	candidate_zero.first8 == "2e0c0041e1bcc0ab" and
	candidate_zero.decimal == "3318027308425330859")
local candidate_last = seed_corpus.extreme_candidate(4095, raw_sha256)
assert(candidate_last.label == "grudgelands-wp40-extreme-4095" and
	candidate_last.digest ==
		"acaa5bda8ecb7eda7cb20f7db99e6d57824d56084a5247ae68cbcff7e21a2452" and
	candidate_last.first8 == "acaa5bda8ecb7eda" and
	candidate_last.decimal == "12441857914821115610")
expect_error("candidate index", function() seed_corpus.extreme_candidate(-1, raw_sha256) end)
expect_error("candidate index", function() seed_corpus.extreme_candidate(4096, raw_sha256) end)
expect_error("corpus label", function() seed_corpus.label_seed("unsafe", raw_sha256) end)
for _, bad_sha in ipairs({function() return "short" end,
	function() return string.rep("x", 33) end, function() return 17 end}) do
	expect_error("label SHA", function()
		seed_corpus.label_seed("grudgelands-wp40-extreme-bad", bad_sha)
	end)
end

local score_start = os.clock()
local saved_corpus_fixed = seed_corpus.fixed[1]
local saved_label_seed = seed_corpus.label_seed
local saved_extreme_candidate = seed_corpus.extreme_candidate
local saved_closed_arc = source.islands[1].closed_arc_id
seed_corpus.fixed[1] = candidate_zero.decimal
seed_corpus.label_seed = function() error("mutated corpus helper") end
seed_corpus.extreme_candidate = function() error("mutated corpus helper") end
source.islands[1].closed_arc_id = "mutated:closed_arc"
local score_zero = extreme.score_candidate(0)
seed_corpus.fixed[1] = saved_corpus_fixed
seed_corpus.label_seed = saved_label_seed
seed_corpus.extreme_candidate = saved_extreme_candidate
source.islands[1].closed_arc_id = saved_closed_arc
local score_seconds = os.clock() - score_start
assert(score_zero.status == "scored" and score_zero.candidate_index == 0 and
	score_zero.coast_sample_count > 0 and score_zero.noncoast_sample_count > 0)
assert(score_zero.coast_sample_count == independent_identity.coast_count and
	score_zero.coast_identity_sha256 == independent_identity.coast_sha256 and
	score_zero.noncoast_sample_count == independent_identity.noncoast_count and
	score_zero.noncoast_identity_sha256 == independent_identity.noncoast_sha256,
	"scalar projection changed the independent identity roster")
local candidate_corruptions = {
	function(row) row.extra = true end,
	function(row) row.label = row.label .. "-wrong" end,
	function(row) row.digest = string.rep("0", 64) end,
	function(row) row.status = "skipped_fixed" end,
	function(row) row.coast_n, row.coast_d = row.coast_n * 2, row.coast_d * 2 end,
	function(row) row.coast_sample_count = row.coast_sample_count - 1 end,
	function(row) row.noncoast_sequence_sha256 = string.rep("A", 64) end,
}
for index = 1, #candidate_corruptions do
	local row = deep_copy(score_zero)
	candidate_corruptions[index](row)
	expect_error("candidate", function() extreme.validate_candidate_row(row) end)
end
assert(deep_equal(extreme.validate_candidate_row(deep_copy(score_zero)), score_zero))
local collision_corpus = deep_copy(seed_corpus)
collision_corpus.fixed[1] = candidate_zero.decimal
local collision_extreme = extreme_factory({deterministic = deterministic, exact = exact,
	raw_sha256 = raw_sha256, scalar_reader = session,
	seed_corpus = collision_corpus, source = source})
local skipped_zero = collision_extreme.score_candidate(0)
assert(skipped_zero.status == "skipped_fixed")
collision_extreme.validate_candidate_row(skipped_zero)
local forged_skipped = deep_copy(skipped_zero)
forged_skipped.coast_n = 0
expect_error("unknown field", function()
	collision_extreme.validate_candidate_row(forged_skipped)
end)

local function new_scalar_extreme(reader)
	return extreme_factory({deterministic = deterministic, exact = exact,
		raw_sha256 = raw_sha256, scalar_reader = reader,
		seed_corpus = seed_corpus, source = source})
end
local nonzero_records = session(score_zero.decimal)
local removed_nonzero
for record_index = 1, #nonzero_records do
	local record = nonzero_records[record_index]
	for sample_index = 1, #record.samples do
		if record.samples[sample_index].scalar_q ~= 0 then
			removed_nonzero = table.remove(record.samples, sample_index)
			break
		end
	end
	if removed_nonzero then break end
end
assert(removed_nonzero, "candidate0000 had no nonzero scalar sample")
expect_error("identity roster changed", function()
	new_scalar_extreme(function() return deep_copy(nonzero_records) end).
		score_seed(candidate_zero)
end)
local duplicated_records = session(score_zero.decimal)
duplicated_records[1].samples[#duplicated_records[1].samples + 1] =
	deep_copy(duplicated_records[1].samples[1])
expect_error("repeats scalar identity", function()
	new_scalar_extreme(function() return deep_copy(duplicated_records) end).
		score_seed(candidate_zero)
end)
local mismatched_records = session(score_zero.decimal)
local first_sample, second_sample = mismatched_records[1].samples[1],
	mismatched_records[1].samples[2]
first_sample.source_segment, second_sample.source_segment =
	second_sample.source_segment, first_sample.source_segment
first_sample.local_station, second_sample.local_station =
	second_sample.local_station, first_sample.local_station
expect_error("identity roster changed", function()
	new_scalar_extreme(function() return deep_copy(mismatched_records) end).
		score_seed(candidate_zero)
end)

-- Pure shard authority KATs use a deterministic synthetic label digest so
-- all 4096 closed rows can exercise coverage/merge without materializing a
-- second geometry corpus.
local function small_u64_bytes(value)
	local bytes = {}
	for index = 8, 1, -1 do
		bytes[index] = string.char(value % 256)
		value = math.floor(value / 256)
	end
	return table.concat(bytes)
end
local function shard_raw_sha256(data)
	local index = data:match("^grudgelands%-wp40%-extreme%-(%d%d%d%d)$")
	if index then return small_u64_bytes(100000 + tonumber(index)) ..
		string.rep(string.char(0), 24) end
	return raw_sha256(data)
end
local shard_extreme = extreme_factory({deterministic = deterministic, exact = exact,
	raw_sha256 = shard_raw_sha256, scalar_reader = session,
	seed_corpus = seed_corpus, source = source})
local function synthetic_candidate(index, active_raw)
	local identity = seed_corpus.extreme_candidate(index, active_raw or shard_raw_sha256)
	return {candidate_index = index, label = identity.label, digest = identity.digest,
		first8 = identity.first8, decimal = identity.decimal, status = "scored",
		coast_n = index - 2048, coast_d = 1,
		coast_sample_count = independent_identity.coast_count,
		coast_sequence_sha256 = string.rep("1", 64),
		coast_identity_sha256 = independent_identity.coast_sha256,
		noncoast_n = 2048 - index, noncoast_d = 1,
		noncoast_sample_count = independent_identity.noncoast_count,
		noncoast_sequence_sha256 = string.rep("2", 64),
		noncoast_identity_sha256 = independent_identity.noncoast_sha256}
end
local synthetic_rows = {}
for index = 0, 4095 do synthetic_rows[index + 1] = synthetic_candidate(index) end
local shard_pins = {source_checksum =
	"9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68",
	boundary_policy_checksum =
	"3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140",
	authority_dag_sha256 = string.rep("3", 64), interpreter_id = "test_only",
	authority_commit = string.rep("a", 40), authority_tree = string.rep("b", 40),
	interpreter_launcher = "test_only", interpreter_path = "test_only",
	interpreter_version = "test_only",
	interpreter_sha256 = string.rep("4", 64),
	measurement_scope = "R7_SCALAR_MEASUREMENT_ONLY", stage2_status = "blocked",
	scorer_schema = "grug_wp40_extreme_selector_e0_v1"}
local shards = {}
for shard_index = 0, 3 do
	local first, last = shard_index * 1024, shard_index * 1024 + 1023
	local rows = {}
	for index = first, last do rows[#rows + 1] = synthetic_rows[index + 1] end
	shards[#shards + 1] = shard_extreme.candidate_shard(rows, first, last, shard_pins)
	shard_extreme.validate_candidate_shard(shards[#shards])
	local shard_bytes = shard_extreme.shard_blob(shards[#shards])
	assert(shard_bytes:match(
		"^schema\tgrug_wp40_extreme_candidate_shard_v1\n"))
	assert(shard_extreme.shard_blob(shard_extreme.parse_shard_blob(shard_bytes)) ==
		shard_bytes, "candidate shard parser changed canonical bytes")
end
local merged_forward = shard_extreme.merge_shards(shards, shard_pins)
local merged_reverse = shard_extreme.merge_shards(
	{shards[4], shards[3], shards[2], shards[1]}, shard_pins)
assert(shard_extreme.candidate_blob(merged_forward) ==
	shard_extreme.candidate_blob(merged_reverse),
	"candidate shard merge depends on shard order")
expect_error("do not cover", function()
	shard_extreme.merge_shards({shards[1], shards[2], shards[3]}, shard_pins)
end)
expect_error("overlap", function()
	shard_extreme.merge_shards({shards[1], shards[1], shards[2], shards[3],
		shards[4]}, shard_pins)
end)
local corrupt_shard = deep_copy(shards[1])
corrupt_shard.rows[1].coast_n = corrupt_shard.rows[1].coast_n + 1
expect_error("row digest changed", function()
	shard_extreme.validate_candidate_shard(corrupt_shard)
end)
local corrupt_pin = deep_copy(shards[1])
corrupt_pin.pins.authority_dag_sha256 = string.rep("4", 64)
expect_error("pins differ", function()
	shard_extreme.merge_shards({corrupt_pin, shards[2], shards[3], shards[4]},
		shard_pins)
end)
local corrupt_range = deep_copy(shards[1])
corrupt_range.last_index = corrupt_range.last_index - 1
expect_error("range/count", function()
	shard_extreme.validate_candidate_shard(corrupt_range)
end)
expect_error("blob header", function()
	shard_extreme.parse_shard_blob(shard_extreme.shard_blob(shards[1]):gsub(
		"source_checksum", "source_checkwrong", 1))
end)
expect_error("blob framing", function()
	local blob = shard_extreme.shard_blob(shards[1])
	shard_extreme.parse_shard_blob(blob:sub(1, #blob - 1))
end)
local function collision_raw_sha256(data)
	if data == "grudgelands-wp40-extreme-0001" then
		return small_u64_bytes(100000) .. string.rep(string.char(0), 24)
	end
	return shard_raw_sha256(data)
end
local collision_shard_extreme = extreme_factory({deterministic = deterministic,
	exact = exact, raw_sha256 = collision_raw_sha256, scalar_reader = session,
	seed_corpus = seed_corpus, source = source})
expect_error("seed decimal is duplicated", function()
	collision_shard_extreme.candidate_shard({synthetic_candidate(0,
		collision_raw_sha256), synthetic_candidate(1, collision_raw_sha256)},
		0, 1, shard_pins)
end)
print(("WP40 T2 E0 candidate0 decimal=%s coast=%d/%d noncoast=%d/%d " ..
	"samples=%d/%d identity=%s/%s cpu=%.3f sha_calls=%d sha_misses=%d"):format(
	score_zero.decimal, score_zero.coast_n, score_zero.coast_d,
	score_zero.noncoast_n, score_zero.noncoast_d,
	score_zero.coast_sample_count, score_zero.noncoast_sample_count,
	score_zero.coast_identity_sha256, score_zero.noncoast_identity_sha256,
	score_seconds, sha_calls, sha_misses))

local range_first_text, range_last_text = os.getenv("WP40_EXTREME_RANGE_FIRST"),
	os.getenv("WP40_EXTREME_RANGE_LAST")
assert((range_first_text == nil) == (range_last_text == nil),
	"both WP40 extreme range endpoints are required")
local benchmark_first, benchmark_last, benchmark_count
if range_first_text then
	benchmark_first, benchmark_last = tonumber(range_first_text), tonumber(range_last_text)
	assert(benchmark_first and benchmark_last and benchmark_first % 1 == 0 and
		benchmark_last % 1 == 0 and benchmark_first >= 0 and
		benchmark_last >= benchmark_first and benchmark_last <= 4095 and
		tostring(benchmark_first) == range_first_text and
		tostring(benchmark_last) == range_last_text,
		"WP40 extreme range is not canonical 0..4095")
	benchmark_count = benchmark_last - benchmark_first + 1
else
	local benchmark_text = os.getenv("WP40_EXTREME_BENCHMARK_COUNT") or "0"
	assert(benchmark_text == "0" or benchmark_text == "16" or
		benchmark_text == "64" or benchmark_text == "4096",
		"WP40_EXTREME_BENCHMARK_COUNT must be 0, 16, 64, or 4096")
	benchmark_count = tonumber(benchmark_text)
	benchmark_first, benchmark_last = 0, benchmark_count - 1
end
if benchmark_count > 0 then
	local rows = {}
	local start_cpu = os.clock()
	local start_wall = os.time()
	local calls_before, misses_before, processes_before = batch_calls,
		batch_cache_misses, batch_processes
	for candidate_index = benchmark_first, benchmark_last do
		batch_mode = "direct"
		local seed_row = seed_corpus.extreme_candidate(candidate_index,
			batch_raw_sha256)
		local records, discovered = preload_candidate(seed_row.decimal)
		assert(discovered > 0)
		if candidate_index == benchmark_first then
			local checked = 0
			for data, digest in pairs(batch_cache) do
				assert(digest == raw_sha256(data),
					"batched SHA-256 differs from independent sha256sum")
				checked = checked + 1
				if checked == 8 then break end
			end
			assert(checked == 8)
		end
		current_batch_seed, current_batch_records = seed_row.decimal, records
		-- Candidate/identity/score-artifact hashes are digest-independent after
		-- the real scalar records exist. Discover all four blobs, batch them,
		-- then require the retained authoritative row to have zero cache misses.
		while true do
			batch_mode = "discover"
			local ok, message = pcall(batch_extreme.score_candidate, candidate_index)
			local filled = fill_batch()
			if ok then break end
			assert(tostring(message):find("identity roster changed", 1, true),
				tostring(message))
			assert(filled > 0)
		end
		batch_mode = "strict"
		local score_misses_before, direct_calls_before = batch_cache_misses, sha_calls
		rows[#rows + 1] = batch_extreme.score_candidate(candidate_index)
		assert(batch_cache_misses == score_misses_before and
			sha_calls == direct_calls_before,
			"authoritative score pass bypassed the batched SHA seam")
		current_batch_seed, current_batch_records = nil, nil
		if candidate_index == 0 then
			assert(deep_equal(rows[1], score_zero),
				"batched scalar path changed candidate0000")
		end
	end
	local summary = {}
	for index = 1, #rows do
		local row = rows[index]
		batch_extreme.validate_candidate_row(row)
		summary[index] = table.concat({row.candidate_index, row.decimal,
			row.coast_n, row.coast_d, row.noncoast_n, row.noncoast_d,
			row.coast_sequence_sha256, row.noncoast_sequence_sha256}, ";")
	end
	batch_mode = "direct"
	local summary_sha = canonical.hex(batch_raw_sha256(
		table.concat(summary, "\n") .. "\n"))
	print(("WP40 T2 E0 benchmark range=%d..%d candidates=%d wall_seconds=%d " ..
		"cpu=%.3f hash_calls=%d " ..
		"cache_misses=%d batch_processes=%d lattice_inputs=%d sha256=%s"):format(
		benchmark_first, benchmark_last, benchmark_count,
		os.difftime(os.time(), start_wall), os.clock() - start_cpu,
		batch_calls - calls_before,
		batch_cache_misses - misses_before, batch_processes - processes_before,
		#noise_lattices, summary_sha))
	if benchmark_first == 0 and benchmark_last == 4095 then
		local slots = batch_extreme.select_slots(rows)
		local artifact = batch_extreme.candidate_blob(rows)
		local staging = batch_extreme.staging_seed(slots)
		print("WP40 T2 E0 candidate artifact SHA-256 " ..
			canonical.hex(batch_raw_sha256(artifact)))
		for index = 1, #slots do
			local slot = slots[index]
			print(("WP40 T2 E0 measured slot=%d id=%s candidate=%04d decimal=%s " ..
				"score=%d/%d"):format(slot.slot, slot.id, slot.candidate_index,
				slot.decimal, slot.score_n, slot.score_d))
		end
		print("WP40 T2 E0 staging " .. staging.label .. " " .. staging.decimal)
	end
end

print("WP40 T2 extreme selector foundation tests passed")
