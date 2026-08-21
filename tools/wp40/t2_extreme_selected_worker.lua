local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "conformance scratch required")
local partition_scratch = assert(arg[3], "partition scratch required")
local slot_text = assert(arg[4], "selected slot required")
local output_path = assert(arg[5], "selected result output required")
local conformance_commit = assert(arg[6], "conformance commit required")
local conformance_tree = assert(arg[7], "conformance tree required")
local conformance_dag = assert(arg[8], "conformance DAG required")
local interpreter_path = assert(arg[9], "PUC interpreter path required")
assert(arg[10] == nil and _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"selected partition worker requires plain Lua 5.1")
assert(arg[-1] == interpreter_path, "selected partition interpreter path changed")
local slot = tonumber(slot_text)
assert(slot and slot % 1 == 0 and slot >= 28 and slot <= 31 and
	tostring(slot) == slot_text, "selected slot is not canonical")
local function safe_absolute(path)
	assert(type(path) == "string" and path:match("^/[A-Za-z0-9._/-]+$") and
		not path:find("/../", 1, true) and not path:find("/./", 1, true) and
		path:sub(-3) ~= "/.." and path:sub(-2) ~= "/." and
		not path:find("/" .. "/", 1, true), "unsafe selected partition path")
end
for _, path in ipairs({repo, scratch, partition_scratch, output_path,
		interpreter_path}) do safe_absolute(path) end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%-worker%.[A-Za-z0-9]+$") and
	partition_scratch:match("^/tmp/grudgelands%-wp40%-t2%-partition%.[A-Za-z0-9]+$"),
	"unsafe selected partition scratch path")
-- v3 outputs have their own names; a pre-v3 target is refused outright.
local expected_output = repo .. ("/tools/wp40/fixtures/t2_extreme_e0/" ..
	"selected-puc-v3-slot%02d.tsv"):format(slot)
assert(output_path == expected_output, "selected partition output path changed")
assert(not output_path:match("/selected%-puc%-slot%d%d%.tsv$") and
	not output_path:match("/rescore%-puc%-%d%d%d%d%.tsv$") and
	not output_path:match("/conformance%-puc%.tsv$"),
	"selected output names pre-v3 evidence")
assert(type(conformance_commit) == "string" and #conformance_commit == 40 and
	conformance_commit:match("^[0-9a-f]+$") and type(conformance_tree) == "string" and
	#conformance_tree == 40 and conformance_tree:match("^[0-9a-f]+$") and
	type(conformance_dag) == "string" and #conformance_dag == 64 and
	conformance_dag:match("^[0-9a-f]+$"), "selected conformance pins changed")
local existing = io.open(output_path, "rb")
if existing then existing:close(); error("selected output already exists", 0) end

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
local function plain_bytes(value, seen)
	local kind = type(value)
	if kind == "string" then return "s" .. #value .. ":" .. value end
	if kind == "number" then assert(value % 1 == 0); return "n" .. value .. ";" end
	if kind == "boolean" then return value and "b1" or "b0" end
	if kind == "nil" then return "z" end
	assert(kind == "table" and getmetatable(value) == nil)
	seen = seen or {}
	assert(not seen[value], "compiled payload aliases or cycles")
	seen[value] = true
	local count, array = 0, true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then array = false end
	end
	local parts
	if array and count == #value then
		parts = {"a", tostring(count), ":"}
		for index = 1, count do parts[#parts + 1] = plain_bytes(value[index], seen) end
	else
		local keys = {}
		for key in pairs(value) do assert(type(key) == "string"); keys[#keys + 1] = key end
		table.sort(keys)
		parts = {"m", tostring(#keys), ":"}
		for index = 1, #keys do
			parts[#parts + 1] = plain_bytes(keys[index], seen)
			parts[#parts + 1] = plain_bytes(value[keys[index]], seen)
		end
	end
	seen[value] = nil
	return table.concat(parts)
end

local conformance_authority_path =
	"tools/wp40/t2_extreme_conformance_v3_authority.lua"
local authority_bytes = read_file(repo .. "/" .. conformance_authority_path)
local authority = assert(loadstring(authority_bytes,
	"@" .. conformance_authority_path))()({raw_sha256 = raw_sha256})
local snapshot = authority.capture(repo,
	{[conformance_authority_path] = authority_bytes})
assert(snapshot.dag_sha256 == conformance_dag, "selected conformance DAG changed")
local measurement_path = "tools/wp40/t2_extreme_authority.lua"
local measurement_bytes = read_file(repo .. "/" .. measurement_path)
local measurement = assert(loadstring(measurement_bytes, "@" .. measurement_path))()({
	raw_sha256 = raw_sha256})
local files = measurement.capture_files(repo, {[measurement_path] = measurement_bytes})
local vocabulary = measurement.load_module(files,
	"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local measured = measurement.bind_vocabulary(files, vocabulary)
local canonical = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = measurement.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
		scalar_reader = function() error("selected parser cannot materialize") end,
		seed_corpus = seed_corpus, source = source})
local conformance = assert(loadstring(snapshot.files[
	"tools/wp40/t2_extreme_conformance.lua"],
	"@tools/wp40/t2_extreme_conformance.lua"))()({raw_sha256 = raw_sha256,
	extreme = extreme, rational_compare = extreme.rational_compare,
	decimal_less = extreme.decimal_less})
local gate = assert(loadstring(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"],
	"@tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"))()
assert(output_path == repo .. "/" .. conformance.selected_result_path(slot),
	"selected output path is not the canonical v3 target")
-- (R3b) stage-S1 CURRENCY against the tree this worker is executing on, and
-- (R3c) the Authority-DAG of the code that performs the partition gate.  The
-- pre-v3 equality assertion against the pool's own DAG is deliberately gone.
local s1 = conformance.s1_currency(measurement, files, gate)
local execution_dag = conformance.execution_authority_dag(measurement, files)
assert(execution_dag == measured.authority_dag_sha256,
	"executing measurement Authority-DAG is inconsistent")
local artifact = conformance.parse_artifact(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv"], gate)
conformance.parse_manifest(snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv"], gate)
local slots = conformance.selected_and_required(artifact, gate, extreme.staging_seed)
local winner = assert(slots[slot - 27])
assert(winner.slot == slot and winner.candidate_index == gate.winners[slot - 27].candidate_index)
local interpreter_sha = hex(raw_sha256(read_file(interpreter_path)))
assert(artifact.headers.merge_interpreter_path == interpreter_path and
	artifact.headers.merge_interpreter_version ==
		"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" and
	artifact.headers.merge_interpreter_sha256 == interpreter_sha,
	"selected PUC interpreter differs from retained merge authority")

local request = {seed = winner.decimal}
local test_chunk = assert(loadstring(snapshot.files["tools/wp40/t2_partition_test.lua"],
	"@tools/wp40/t2_partition_test.lua"))
local test_arg = {[0] = "tools/wp40/t2_partition_test.lua", [1] = repo,
	[2] = partition_scratch, [-1] = interpreter_path}
local environment = setmetatable({arg = test_arg, WP40_T2_SELECTED_REQUEST = request},
	{__index = _G})
environment._G = environment
setfenv(test_chunk, environment)
local start_wall = os.time()
print(("WP40 T2 C1 v3 selected start slot=%d candidate=%04d decimal=%s"):format(
	slot, winner.candidate_index, winner.decimal))
io.stdout:flush()
test_chunk()
local result = assert(request.result, "selected partition test returned no result")
local report, compiled = assert(result.report), assert(result.compiled)
local compiled_sha = hex(raw_sha256(plain_bytes(compiled)))
local output = {schema = "grug_wp40_extreme_selected_partition_v3",
	status = "passed", scope = "T2C_E0_SELECTED_FOUR_PARTITION_CONFORMANCE_ONLY",
	pool_measurement_commit = gate.pool_measurement_commit,
	pool_measurement_tree = gate.pool_measurement_tree,
	pool_authority_dag_sha256 = gate.pool_authority_dag_sha256,
	s1_authority_sha256 = s1.s1_authority_sha256,
	s1_source_projection_sha256 = s1.s1_source_projection_sha256,
	conformance_commit = conformance_commit, conformance_tree = conformance_tree,
	conformance_dag_sha256 = conformance_dag,
	execution_authority_dag_sha256 = execution_dag,
	artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = interpreter_path,
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = interpreter_sha, slot = slot, slot_id = winner.id,
	candidate_index = winner.candidate_index, candidate_decimal = winner.decimal,
	compiled_sha256 = compiled_sha, columns = report.columns,
	base_total = report.base_total, planned_water = report.planned_water, dry = report.dry,
	g = report.g, o = report.o, r = report.r, m = report.m,
	schedule_intervals = report.schedule_intervals,
	perimeter_aperture = assert(report.perimeter_aperture),
	perimeter_attachment = assert(report.perimeter_attachment),
	perimeter_dry = assert(report.perimeter_dry),
	transition_count = result.transition_count, bank_count = result.bank_count,
	wing_count = result.wing_count, coast_count = result.coast_count,
	face_count = result.face_count}
local pins = {commit = conformance_commit, tree = conformance_tree,
	dag = conformance_dag}
assert(conformance.validate_selected_result(output, gate, gate.winners[slot - 27], pins,
	interpreter_path))
local blob = conformance.selected_result_blob(output)
local temporary = output_path .. ".tmp"
assert(not io.open(temporary, "rb"), "temporary selected output already exists")
local published, message = pcall(function()
	local file = assert(io.open(temporary, "wb"))
	assert(file:write(blob)) assert(file:close())
	assert(read_file(temporary) == blob)
	assert(os.rename(temporary, output_path), "atomic selected publish failed")
end)
if not published then os.remove(temporary); error(message, 0) end
assert(measurement.verify(repo, measured, vocabulary))
assert(authority.verify(repo, snapshot))
print(("WP40 T2 C1 v3 selected passed slot=%d candidate=%04d compiled_sha256=%s " ..
	"columns=%d g/o/r/m=%d/%d/%d/%d wall_seconds=%d"):format(slot,
	winner.candidate_index, compiled_sha, report.columns, report.g, report.o,
	report.r, report.m, os.difftime(os.time(), start_wall)))
