local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local first_text = assert(arg[3], "first candidate index required")
local last_text = assert(arg[4], "last candidate index required")
local output_path = assert(arg[5], "shard output path required")
local interpreter_id = assert(arg[6], "interpreter evidence required")
local interpreter_launcher = assert(arg[7], "interpreter launcher evidence required")
local interpreter_path = assert(arg[8], "interpreter path evidence required")
local interpreter_version = assert(arg[9], "interpreter version evidence required")
local authority_commit = assert(arg[10], "authority commit evidence required")
local authority_tree = assert(arg[11], "authority tree evidence required")

local function safe_absolute_path(value)
	assert(type(value) == "string" and value:match("^/[A-Za-z0-9._/-]+$") and
		not value:find("/../", 1, true) and not value:find("/./", 1, true) and
		not value:find("//", 1, true), "unsafe absolute path")
	return value
end
for _, path in ipairs({repo, scratch, output_path, interpreter_launcher,
		interpreter_path}) do
	safe_absolute_path(path)
end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-extreme%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
local first, last = tonumber(first_text), tonumber(last_text)
assert(first and last and first % 1 == 0 and last % 1 == 0 and first >= 0 and
	last >= first and last <= 4095 and tostring(first) == first_text and
	tostring(last) == last_text, "candidate range is not canonical 0..4095")
assert(interpreter_id == "puc_lua51" or interpreter_id == "luajit",
	"interpreter evidence is invalid")
assert(#authority_commit == 40 and authority_commit:match("^[0-9a-f]+$") and
	#authority_tree == 40 and authority_tree:match("^[0-9a-f]+$"),
	"authority commit/tree evidence is invalid")
if interpreter_id == "luajit" then
	assert(interpreter_launcher == "/usr/bin/luajit" and
		interpreter_path == "/usr/bin/luajit-2.1.1767980792",
		"LuaJIT measurement must use the reviewed system interpreter")
	assert(interpreter_version ==
		"LuaJIT 2.1.1767980792 -- Copyright (C) 2005-2026 Mike Pall. https://luajit.org/",
		"LuaJIT version evidence changed")
else
	assert(interpreter_launcher == interpreter_path and
		interpreter_path:match("/tools/bin/lua51$"),
		"PUC conformance must use the vendored interpreter")
	assert(interpreter_version ==
		"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
		"PUC interpreter version evidence changed")
end
-- The authorized output path is asserted below, as soon as the Authority-DAG
-- helper is loaded. It deliberately is NOT rebuilt from a local copy of the
-- naming rule: this file used to carry one, it went stale the moment the v3
-- pool moved to its own names, and it aborted every fresh launch before a
-- single seed was measured.

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local direct_cache, direct_calls, direct_misses, direct_counter = {}, 0, 0, 0
local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function direct_raw_sha256(data)
	direct_calls = direct_calls + 1
	if direct_cache[data] then return direct_cache[data] end
	direct_misses, direct_counter = direct_misses + 1, direct_counter + 1
	local input = scratch .. "/direct-" .. direct_counter .. ".bin"
	local output = scratch .. "/direct-" .. direct_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	file = assert(io.open(output, "rb"))
	local raw = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close()) assert(#raw == 32)
	direct_cache[data] = raw
	return raw
end

-- Capture the complete scorer/code input before loading any geometry module.
-- The authority helper itself is loaded from exactly the bytes placed in the
-- snapshot, avoiding an unpinned second orchestration path.
local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority_chunk = assert(loadstring(authority_bytes,
	"@" .. authority_path))
local authority = authority_chunk()({raw_sha256 = direct_raw_sha256})

-- Single source of truth for where a measurement may write, shared with
-- run_t2_extreme_shards.sh and t2_extreme_verify_shard.lua. This runs before
-- the file snapshot and long before any seed is measured, so it still fails
-- fast, and it keeps both guarantees the earlier local check provided: a
-- worker may write only to its own authorized retained path, and may never
-- overwrite an existing shard. retained_shard_path additionally rejects any
-- non-canonical range outright.
assert(interpreter_id == "luajit",
	"the retained E0 pool is the LuaJIT measurement")
local expected_output = repo .. "/" .. authority.retained_shard_path(first, last)
assert(output_path == expected_output,
	"shard output path is not the authorized retained path")
local existing = io.open(output_path, "rb")
if existing then existing:close(); error("shard output already exists", 0) end

local file_snapshot = authority.capture_files(repo,
	{[authority_path] = authority_bytes})
local full_scan_gate = authority.load_module(file_snapshot,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
assert(authority.validate_full_scan_gate(full_scan_gate))
local interpreter_bytes = read_file(interpreter_path)
local interpreter_sha256 = (direct_raw_sha256(interpreter_bytes):gsub(".",
	function(byte) return ("%02x"):format(string.byte(byte)) end))

local canonical = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local raster_factory = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")
local source = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local source_validator_module = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
local seed_corpus = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
-- The Source catalog is still validated by its own Stage-1 checksum below (the
-- validator runs during partition construction); it is simply no longer a pool
-- pin.  What the pool binds is the stage-S1 authority, computed after the S1
-- module is live and re-checked immediately before publication.
local s1_authority = authority.load_module(file_snapshot,
	"tools/wp40/t2_s1_authority.lua")({raw_sha256 = direct_raw_sha256})

local vocabulary = authority.load_module(file_snapshot,
	"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local authority_snapshot = authority.bind_vocabulary(file_snapshot, vocabulary)

local batch_cache, permanent_cache, pending, pending_seen = {}, {}, {}, {}
local batch_mode, batch_calls, batch_misses, batch_processes = "direct", 0, 0, 0
local collect_real_batch_proof, real_batch_proof_count = false, 0
local zero_digest = string.rep(string.char(0), 32)
local function queue(data)
	if not pending_seen[data] then pending_seen[data] = true; pending[#pending + 1] = data end
end
local function batch_raw_sha256(data)
	batch_calls = batch_calls + 1
	local value = batch_cache[data] or permanent_cache[data]
	if value then return value end
	batch_misses = batch_misses + 1
	if batch_mode == "discover" then queue(data); return zero_digest end
	if batch_mode == "strict" then queue(data); error("WP40 T2 batch SHA cache miss", 0) end
	value = direct_raw_sha256(data)
	permanent_cache[data] = value
	return value
end
local function fill_batch()
	if #pending == 0 then return 0 end
	local input, output = scratch .. "/batch.bin", scratch .. "/batch.out"
	local file = assert(io.open(input, "wb"))
	for index = 1, #pending do
		assert(file:write(tostring(#pending[index]), "\n", pending[index]))
	end
	assert(file:close())
	local status, reason, code = os.execute("python3 " .. repo ..
		"/tools/wp40/t2_sha256_batch.py " .. input .. " " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	batch_processes = batch_processes + 1
	file = assert(io.open(output, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close()) assert(#bytes == #pending * 32)
	for index = 1, #pending do
		batch_cache[pending[index]] = bytes:sub(index * 32 - 31, index * 32)
	end
	if collect_real_batch_proof and real_batch_proof_count == 0 then
		assert(#pending >= 8, "first real SHA batch has fewer than eight inputs")
		for index = 1, 8 do
			assert(batch_cache[pending[index]] == direct_raw_sha256(pending[index]),
				"Python batch SHA differs from direct sha256sum")
		end
		real_batch_proof_count = 8
	end
	local count = #pending
	pending, pending_seen = {}, {}
	return count
end

-- Every shard independently proves the Python framing/hash implementation
-- against fixed binary vectors before scoring, then compares the first eight
-- real noise inputs in fill_batch above before candidate 1 can begin.
local fixed_batch_vectors = {
	{bytes = "", digest =
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	{bytes = "abc", digest =
		"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
	{bytes = string.char(0, 255, 1, 254), digest =
		"5d8d910591d272938aef5f966e0816e374beaf7b5adf02cca5f8f770596c2ce3"},
}
for index = 1, #fixed_batch_vectors do queue(fixed_batch_vectors[index].bytes) end
assert(fill_batch() == #fixed_batch_vectors)
for index = 1, #fixed_batch_vectors do
	local row = fixed_batch_vectors[index]
	assert(batch_cache[row.bytes] == from_hex(row.digest) and
		batch_cache[row.bytes] == direct_raw_sha256(row.bytes),
		"fixed Python batch SHA vector changed")
end
batch_cache, pending, pending_seen = {}, {}, {}

local land_by_id, effective_land = {}, {}
for index = 1, #source.land_edges do land_by_id[source.land_edges[index].id] =
	source.land_edges[index] end
for index = 1, #source.junction_departures do
	local departure = source.junction_departures[index]
	local row = assert(land_by_id[departure.edge_id])
	local from = departure.edge_endpoint == "from"
	local junction = row.control[from and 1 or #row.control]
	local adjacent = row.control[from and 2 or #row.control - 1]
	local derived = {x = exact.safe_sum(junction.x,
		adjacent.x > junction.x and 1 or -1, "worker D x"),
		z = exact.safe_sum(junction.z, adjacent.z > junction.z and 1 or -1,
			"worker D z")}
	local control = {}
	for point_index = 1, #row.control do
		control[point_index] = {x = row.control[point_index].x,
			z = row.control[point_index].z}
	end
	if from then table.insert(control, 2, derived) else table.insert(control, #control, derived) end
	effective_land[row.id] = control
end

local identity_raster = raster_factory({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = direct_raw_sha256})
local lattice_by_key = {}
local function add_collection(collection, control_field, closed, period, effective)
	for row_index = 1, #collection do
		local row = collection[row_index]
		if row.max_displacement > 0 then
			local control = effective and effective[row.id] or row[control_field]
			local stations = identity_raster.authored_stations(control, closed)
			for station_index = 1, #stations do
				local station = stations[station_index]
				for lane = 0, 1 do
					local lane_period = period * (lane + 1)
					local lx = deterministic.floor_div(station.x, lane_period)
					local lz = deterministic.floor_div(station.z, lane_period)
					for dx = 0, 1 do for dz = 0, 1 do
						local key = table.concat({row.noise_domain, lane, lx + dx, lz + dz}, ";")
						lattice_by_key[key] = {domain = row.noise_domain, lane = lane,
							x = lx + dx, z = lz + dz}
					end end
				end
			end
		end
	end
end
add_collection(source.perimeters, "polygon", true, 512)
add_collection(source.islands, "polygon", true, 256)
add_collection(source.land_edges, "control", false, 384, effective_land)
local lattices = {}
for _, row in pairs(lattice_by_key) do lattices[#lattices + 1] = row end
table.sort(lattices, function(a, b) return a.domain < b.domain or
	a.domain == b.domain and (a.lane < b.lane or a.lane == b.lane and
	(a.x < b.x or a.x == b.x and a.z < b.z)) end)

local stage1 = source_validator_module.new_offline_test_adapter(canonical,
	batch_raw_sha256)
local validation_calls = 0
local validator = {validate = function(...)
	validation_calls = validation_calls + 1
	return stage1.validate(...)
end}
local batch_raster = raster_factory({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = batch_raw_sha256})
local new_boundary = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua")
local partition = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, new_boundary = new_boundary,
	raster = batch_raster,
	raw_sha256 = batch_raw_sha256, source = source, source_validator = validator,
	vocabulary = vocabulary})
local scalar_reader = partition.new_extreme_scalar_session()
assert(validation_calls == 1)

-- Fail closed before a single seed is measured: the live S1 projection and the
-- captured S1 bytes must reproduce the digest the checked-in gate pins.
local s1_source_projection_sha256 = partition.s1_source_checksum()
local s1_authority_sha256 = s1_authority.digest(file_snapshot.files,
	s1_source_projection_sha256, partition.s1_source_projection_schema)
assert(s1_source_projection_sha256 == full_scan_gate.s1_source_projection_sha256,
	"stage-S1 Source projection differs from the full-scan gate")
assert(s1_authority.verify(file_snapshot.files, s1_source_projection_sha256,
	partition.s1_source_projection_schema, full_scan_gate.s1_authority_sha256))
assert(authority.validate_full_scan_gate(full_scan_gate, {
	s1_authority_sha256 = s1_authority_sha256,
	s1_source_projection_sha256 = s1_source_projection_sha256,
}))
for data, digest in pairs(batch_cache) do permanent_cache[data] = digest end
batch_cache = {}
local active_seed, active_records
local extreme = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
	deterministic = deterministic, exact = exact, raw_sha256 = batch_raw_sha256,
	scalar_reader = function(seed)
		assert(seed == active_seed and active_records)
		local copy = {}
		for record_index = 1, #active_records do
			local record = active_records[record_index]
			local samples = {}
			for sample_index = 1, #record.samples do
				local row = record.samples[sample_index]
				samples[sample_index] = {x = row.x, z = row.z, scalar_q = row.scalar_q,
					source_segment = row.source_segment, local_station = row.local_station}
			end
			copy[record_index] = {family = record.family, id = record.id,
				numeric_id = record.numeric_id, max_displacement = record.max_displacement,
				topology_ceiling_nodes = record.topology_ceiling_nodes, samples = samples}
		end
		return copy
	end, seed_corpus = seed_corpus, source = source})

local function materialize(seed)
	batch_cache, pending, pending_seen = {}, {}, {}
	local hash = deterministic.new_hash(canonical, batch_raw_sha256,
		"grug_wp40_geometry_source_v1", seed)
	batch_mode = "discover"
	for index = 1, #lattices do local row = lattices[index]
		hash.signed_noise(row.domain, "", {row.x, row.z}, 0, row.lane) end
	fill_batch()
	while true do
		batch_mode = "strict"
		local ok, message = pcall(function()
			for index = 1, #lattices do local row = lattices[index]
				hash.signed_noise(row.domain, "", {row.x, row.z}, 0, row.lane) end
		end)
		if ok then break end
		assert(tostring(message):find("batch SHA cache miss", 1, true))
		assert(fill_batch() > 0)
	end
	local misses_before, direct_before = batch_misses, direct_calls
	local records = scalar_reader(seed)
	assert(batch_misses == misses_before and direct_calls == direct_before)
	return records
end

local rows, start_wall, start_cpu = {}, os.time(), os.clock()
local calls_before, misses_before, processes_before = batch_calls, batch_misses,
	batch_processes
collect_real_batch_proof = true
for candidate_index = first, last do
	batch_mode = "direct"
	local seed = seed_corpus.extreme_candidate(candidate_index,
		batch_raw_sha256).decimal
	active_seed, active_records = seed, materialize(seed)
	while true do
		batch_mode = "discover"
		local ok, message = pcall(extreme.score_candidate, candidate_index)
		local filled = fill_batch()
		if ok then break end
		assert(tostring(message):find("identity roster changed", 1, true) and filled > 0)
	end
	batch_mode = "strict"
	local misses_at_score, direct_at_score = batch_misses, direct_calls
	rows[#rows + 1] = extreme.score_candidate(candidate_index)
	assert(batch_misses == misses_at_score and direct_calls == direct_at_score)
	active_seed, active_records = nil, nil
	if candidate_index == first then
		assert(real_batch_proof_count == 8,
			"first eight real Python batch inputs were not independently verified")
	end
	local completed = candidate_index - first + 1
	if completed % 32 == 0 or candidate_index == last then
		local elapsed = math.max(0, os.difftime(os.time(), start_wall))
		local remaining = last - candidate_index
		local eta = completed > 0 and math.floor(elapsed * remaining / completed) or 0
		print(("WP40 T2 E0 shard progress range=%04d..%04d current=%04d " ..
			"completed512=%d/%d wall_seconds=%d eta_seconds=%d"):format(
			first, last, candidate_index, completed, last - first + 1, elapsed, eta))
		io.stdout:flush()
	end
end

batch_mode = "direct"
assert(authority.verify(repo, authority_snapshot, vocabulary))
assert(read_file(interpreter_path) == interpreter_bytes,
	"interpreter binary changed during shard measurement")
-- Recompute the S1 authority from the live tree, not from the captured
-- snapshot: authority.verify has just proved the two agree, so a difference
-- here means S1 moved mid-run and the shard must not be published.
assert(partition.s1_source_checksum() == s1_source_projection_sha256,
	"stage-S1 Source projection changed during shard measurement")
assert(s1_authority.verify(authority.capture_files(repo).files,
	s1_source_projection_sha256, partition.s1_source_projection_schema,
	full_scan_gate.s1_authority_sha256))
local pins = {s1_authority_sha256 = s1_authority_sha256,
	s1_source_projection_sha256 = s1_source_projection_sha256,
	authority_dag_sha256 = authority_snapshot.authority_dag_sha256,
	authority_commit = authority_commit, authority_tree = authority_tree,
	interpreter_id = interpreter_id,
	interpreter_launcher = interpreter_launcher, interpreter_path = interpreter_path,
	interpreter_version = interpreter_version,
	interpreter_sha256 = interpreter_sha256,
	measurement_scope = "R7_SCALAR_MEASUREMENT_ONLY",
	stage2_status = "pending_selected_four",
	scorer_schema = "grug_wp40_extreme_selector_e0_v1"}
local shard = extreme.candidate_shard(rows, first, last, pins)
local shard_bytes = extreme.shard_blob(shard)
local temporary_output = output_path .. ".tmp"
local temporary_existing = io.open(temporary_output, "rb")
if temporary_existing then
	temporary_existing:close()
	error("temporary shard output already exists", 0)
end
local published, publish_message = pcall(function()
	local output = assert(io.open(temporary_output, "wb"))
	assert(output:write(shard_bytes)) assert(output:close())
	assert(read_file(temporary_output) == shard_bytes,
		"temporary shard bytes changed after write")
	assert(os.rename(temporary_output, output_path), "atomic shard publish failed")
end)
if not published then
	os.remove(temporary_output)
	error(publish_message, 0)
end
print(("WP40 T2 E0 shard range=%d..%d candidates=%d wall_seconds=%d cpu=%.3f " ..
	"hash_calls=%d cache_misses=%d batch_processes=%d lattice_inputs=%d " ..
	"batch_proof_inputs=%d rows_sha256=%s"):format(first, last, #rows,
	os.difftime(os.time(), start_wall), os.clock() - start_cpu,
	batch_calls - calls_before, batch_misses - misses_before,
	batch_processes - processes_before, #lattices, real_batch_proof_count,
	shard.rows_sha256))
