local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local candidate_text = assert(arg[3], "candidate index required")
local output_path = assert(arg[4], "rescore output required")
local conformance_commit = assert(arg[5], "conformance commit required")
local conformance_tree = assert(arg[6], "conformance tree required")
local conformance_dag = assert(arg[7], "conformance DAG required")
local interpreter_path = assert(arg[8], "PUC interpreter path required")
assert(arg[9] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"PUC rescore worker requires plain Lua 5.1")
assert(arg[-1] == interpreter_path, "PUC rescore interpreter path changed")
local candidate_index = tonumber(candidate_text)
assert(candidate_index and candidate_index % 1 == 0 and candidate_index >= 0 and
	candidate_index <= 4095 and tostring(candidate_index) == candidate_text,
	"candidate index is not canonical")
local function safe_absolute(path)
	assert(type(path) == "string" and path:match("^/[A-Za-z0-9._/-]+$") and
		not path:find("/../", 1, true) and not path:find("/./", 1, true) and
		path:sub(-3) ~= "/.." and path:sub(-2) ~= "/." and
		not path:find("/" .. "/", 1, true), "unsafe rescore path")
end
for _, path in ipairs({repo, scratch, output_path, interpreter_path}) do
	safe_absolute(path)
end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%-worker%.[A-Za-z0-9]+$"),
	"unsafe rescore scratch path")
local expected_output = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
	"rescore-puc-%04d.tsv"):format(candidate_index)
assert(output_path == expected_output, "rescore output path changed")
assert(type(conformance_commit) == "string" and #conformance_commit == 40 and
	conformance_commit:match("^[0-9a-f]+$") and type(conformance_tree) == "string" and
	#conformance_tree == 40 and conformance_tree:match("^[0-9a-f]+$") and
	type(conformance_dag) == "string" and #conformance_dag == 64 and
	conformance_dag:match("^[0-9a-f]+$"), "conformance pins changed")
local existing = io.open(output_path, "rb")
if existing then existing:close(); error("rescore output already exists", 0) end

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
local cache, counter = {}, 0
local function raw_sha256(data)
	if cache[data] then return cache[data] end
	counter = counter + 1
	local input, output = scratch .. "/sha-" .. counter .. ".bin",
		scratch .. "/sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	cache[data] = digest
	return digest
end
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local conformance_authority_path = "tools/wp40/t2_extreme_conformance_authority.lua"
local conformance_authority_bytes = read_file(repo .. "/" ..
	conformance_authority_path)
local conformance_authority = assert(loadstring(conformance_authority_bytes,
	"@" .. conformance_authority_path))()({raw_sha256 = raw_sha256})
local conformance_snapshot = conformance_authority.capture(repo,
	{[conformance_authority_path] = conformance_authority_bytes})
assert(conformance_snapshot.dag_sha256 == conformance_dag,
	"conformance DAG differs from launcher")

local measurement_authority_path = "tools/wp40/t2_extreme_authority.lua"
local measurement_authority_bytes = read_file(repo .. "/" .. measurement_authority_path)
local measurement_authority = assert(loadstring(measurement_authority_bytes,
	"@" .. measurement_authority_path))()({raw_sha256 = raw_sha256})
local files = measurement_authority.capture_files(repo,
	{[measurement_authority_path] = measurement_authority_bytes})
local canonical = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local raster_factory = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")
local raster = raster_factory({canonical = canonical, deterministic = deterministic,
	exact = exact, raw_sha256 = raw_sha256})
local source = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local validator_module = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
local seed_corpus = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local vocabulary = measurement_authority.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local measurement_snapshot = measurement_authority.bind_vocabulary(files, vocabulary)
local validator = validator_module.new_offline_test_adapter(canonical, raw_sha256)
local partition = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raster = raster,
	raw_sha256 = raw_sha256, source = source, source_validator = validator,
	vocabulary = vocabulary})
local scalar_reader = partition.new_extreme_scalar_session()
local extreme = measurement_authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
		scalar_reader = scalar_reader, seed_corpus = seed_corpus, source = source})
local conformance = assert(loadstring(conformance_snapshot.files[
	"tools/wp40/t2_extreme_conformance.lua"],
	"@tools/wp40/t2_extreme_conformance.lua"))()({raw_sha256 = raw_sha256,
	extreme = extreme, rational_compare = extreme.rational_compare,
	decimal_less = extreme.decimal_less})
local gate = assert(loadstring(conformance_snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua"],
	"@tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua"))()
assert(measurement_snapshot.authority_dag_sha256 == gate.authority_dag_sha256,
	"measurement DAG differs from conformance gate")
local artifact = conformance.parse_artifact(conformance_snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv"], gate)
conformance.parse_manifest(conformance_snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv"], gate)
local slots, _, required = conformance.selected_and_required(artifact, gate,
	extreme.staging_seed)
local required_set = {}
for index = 1, #required do required_set[required[index]] = true end
assert(required_set[candidate_index], "candidate is outside exact PUC rescore roster")
local winner = {}
for index = 1, #slots do winner[slots[index].candidate_index] = true end
local expected_row = assert(artifact.rows_by_index[candidate_index])
local expected_line = assert(artifact.raw_by_index[candidate_index])
local interpreter_sha = hex(raw_sha256(read_file(interpreter_path)))
assert(artifact.headers.merge_interpreter_path == interpreter_path and
	artifact.headers.merge_interpreter_version ==
		"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" and
	artifact.headers.merge_interpreter_sha256 == interpreter_sha,
	"PUC rescore interpreter differs from retained merge authority")

local start_wall = os.time()
print(("WP40 T2 C1 PUC rescore start candidate=%04d role=%s"):format(
	candidate_index, winner[candidate_index] and "winner" or "endpoint"))
io.stdout:flush()
local rescored = extreme.score_candidate(candidate_index)
local pins = {source_checksum = gate.source_checksum,
	boundary_policy_checksum = gate.boundary_policy_checksum,
	partition_sha256 = gate.partition_sha256,
	authority_dag_sha256 = gate.authority_dag_sha256,
	authority_commit = gate.measurement_commit, authority_tree = gate.measurement_tree,
	interpreter_id = "puc_lua51", interpreter_launcher = interpreter_path,
	interpreter_path = interpreter_path,
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = interpreter_sha,
	measurement_scope = "R7_SCALAR_MEASUREMENT_ONLY",
	stage2_status = "pending_selected_four",
	scorer_schema = "grug_wp40_extreme_selector_e0_v1"}
local one = extreme.shard_blob(extreme.candidate_shard({rescored}, candidate_index,
	candidate_index, pins))
local rescored_line = assert(one:match("\n([^\n]*)\n$"))
assert(rescored_line == expected_line, "PUC rescored row differs byte-for-byte")
assert(rescored.decimal == expected_row.decimal)
local row_sha = hex(raw_sha256(expected_line .. "\n"))
local result = {schema = "grug_wp40_extreme_puc_rescore_v1", status = "passed",
	scope = "T2C_E0_PUC_ROW_CONFORMANCE_ONLY",
	measurement_commit = gate.measurement_commit, measurement_tree = gate.measurement_tree,
	authority_dag_sha256 = gate.authority_dag_sha256,
	conformance_commit = conformance_commit, conformance_tree = conformance_tree,
	conformance_dag_sha256 = conformance_dag,
	source_checksum = gate.source_checksum,
	boundary_policy_checksum = gate.boundary_policy_checksum,
	partition_sha256 = gate.partition_sha256, artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = interpreter_path,
	interpreter_version = pins.interpreter_version, interpreter_sha256 = interpreter_sha,
	candidate_index = candidate_index, candidate_decimal = rescored.decimal,
	candidate_role = winner[candidate_index] and "winner" or "endpoint",
	expected_row_sha256 = row_sha, rescored_row_sha256 = row_sha}
assert(conformance.validate_rescore_result(result, gate, candidate_index, row_sha,
	{commit = conformance_commit, tree = conformance_tree, dag = conformance_dag},
	interpreter_path))
local blob = conformance.rescore_result_blob(result)
local temporary = output_path .. ".tmp"
assert(not io.open(temporary, "rb"), "temporary rescore output already exists")
local published, message = pcall(function()
	local file = assert(io.open(temporary, "wb"))
	assert(file:write(blob)) assert(file:close())
	assert(read_file(temporary) == blob)
	assert(os.rename(temporary, output_path), "atomic rescore publish failed")
end)
if not published then os.remove(temporary); error(message, 0) end
assert(measurement_authority.verify(repo, measurement_snapshot, vocabulary))
assert(conformance_authority.verify(repo, conformance_snapshot))
print(("WP40 T2 C1 PUC rescore passed candidate=%04d row_sha256=%s " ..
	"wall_seconds=%d"):format(candidate_index, row_sha,
	os.difftime(os.time(), start_wall)))
