local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "finalizer scratch required")
local output_path = assert(arg[3], "final conformance output required")
local expected_commit = assert(arg[4], "launch commit required")
local expected_tree = assert(arg[5], "launch tree required")
local expected_dag = assert(arg[6], "launch DAG required")
local mode = arg[7]
assert((mode == nil or mode == "verify") and arg[8] == nil and
	_VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"C1 finalizer requires plain PUC Lua 5.1")
assert(#expected_commit == 40 and expected_commit:match("^[0-9a-f]+$") and
	#expected_tree == 40 and expected_tree:match("^[0-9a-f]+$") and
	#expected_dag == 64 and expected_dag:match("^[0-9a-f]+$"),
	"expected C1 launch pins are invalid")
local expected_launch = expected_commit .. ":" .. expected_tree .. ":" .. expected_dag
assert(arg[-1] == repo .. "/tools/bin/lua51",
	"C1 finalizer requires the reviewed vendored interpreter")
local function safe_absolute(path)
	assert(type(path) == "string" and path:match("^/[A-Za-z0-9._/-]+$") and
		not path:find("/../", 1, true) and not path:find("/./", 1, true) and
		path:sub(-3) ~= "/.." and path:sub(-2) ~= "/." and
		not path:find("/" .. "/", 1, true), "unsafe C1 finalizer path")
end
for _, path in ipairs({repo, scratch, output_path}) do safe_absolute(path) end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%-final%.[A-Za-z0-9]+$"),
	"unsafe C1 finalizer scratch")
local retained = repo .. "/tools/wp40/fixtures/t2_extreme_e0/"
assert(output_path == retained .. "conformance-puc-v3.tsv",
	"final C1 output path changed")
-- The pre-v3 conformance-puc.tsv is retained evidence of the 53be77e pool.
-- The v3 finalizer must never be able to name it.
assert(not output_path:match("/conformance%-puc%.tsv$") and
	not output_path:match("/rescore%-puc%-%d%d%d%d%.tsv$") and
	not output_path:match("/selected%-puc%-slot%d%d%.tsv$"),
	"final C1 output names pre-v3 evidence")
local output_file = io.open(output_path, "rb")
local output_exists = output_file ~= nil
if output_file then output_file:close() end
local temporary_file = io.open(output_path .. ".tmp", "rb")
if temporary_file then temporary_file:close(); error("final C1 temporary exists", 0) end
if mode == "verify" then
	assert(output_exists, "final C1 output is missing")
else
	assert(not output_exists, "final C1 output already exists")
end
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
local function headers(blob)
	local result = {}
	for line in blob:gmatch("([^\n]*)\n") do
		local name, value = line:match("^([^\t]+)\t([^\t]+)$")
		if name then result[name] = value end
	end
	return result
end
local required = {0, 511, 512, 1023, 1024, 1047, 1535, 1536, 1713, 2047,
	2048, 2192, 2559, 2560, 3071, 3072, 3438, 3583, 3584, 4095}
local result_lines, common, common_execution = {}, nil, nil
local lua = repo .. "/tools/bin/lua51"
local execution_repo = assert(arg[0]:match("^(.*)/tools/wp40/"),
	"cannot resolve captured C1 verifier")
safe_absolute(execution_repo)
local verifier = execution_repo .. "/tools/wp40/t2_extreme_conformance_verify.lua"

-- The pool/stage-S1 record written below is read from the pinned v3 gate, not
-- retyped here: the gate is inside the C1 v3 DAG, so there is exactly one place
-- these digests can come from.
local v3_authority = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance_v3_authority.lua"))()({
	raw_sha256 = raw_sha256})
assert(v3_authority.validate_provenance(repo, scratch,
	{commit = expected_commit, tree = expected_tree}))
local v3_snapshot = v3_authority.capture_git(repo, scratch, expected_commit)
assert(v3_snapshot.dag_sha256 == expected_dag, "pinned C1 v3 DAG changed")
local gate = assert(loadstring(v3_snapshot.files[
	"tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"],
	"@tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua"))()

-- Every result row carries the three provenance claims separately.  (a) and
-- (b) must equal the gate.  (c) is deliberately absent from the gate -- it
-- describes the conformance tree, not the pool -- so it is checked here for
-- agreement across all twenty-four rows, after t2_extreme_conformance_verify.lua
-- has already recomputed it live against the executing tree for each row.
local function accept_provenance(row, label)
	assert(row.pool_measurement_commit == gate.pool_measurement_commit and
		row.pool_measurement_tree == gate.pool_measurement_tree and
		row.pool_authority_dag_sha256 == gate.pool_authority_dag_sha256,
		label .. " pool origin differs from the v3 gate")
	assert(row.s1_authority_sha256 == gate.s1_authority_sha256 and
		row.s1_source_projection_sha256 == gate.s1_source_projection_sha256,
		label .. " stage-S1 currency differs from the v3 gate")
	local execution = row.execution_authority_dag_sha256
	assert(type(execution) == "string" and #execution == 64 and
		execution:match("^[0-9a-f]+$"),
		label .. " executing Authority-DAG is invalid")
	common_execution = common_execution or execution
	assert(execution == common_execution,
		"C1 results use different executing Authority-DAGs")
end
for index = 1, #required do
	local candidate = required[index]
	local path = retained .. ("rescore-puc-v3-%04d.tsv"):format(candidate)
	local verify_scratch = scratch .. ("/verify-r-%04d"):format(candidate)
	assert(os.execute("mkdir " .. verify_scratch) == 0)
	local status, reason, code = os.execute(lua .. " " .. verifier .. " " .. repo ..
		" " .. verify_scratch .. " rescore " .. candidate .. " " .. path .. " " ..
		expected_commit .. " " .. expected_tree .. " " .. expected_dag)
	assert(status == 0 or status == true and reason == "exit" and code == 0,
		"retained rescore verification failed")
	local bytes = read_file(path)
	local row = headers(bytes)
	local pins = row.conformance_commit .. ":" .. row.conformance_tree .. ":" ..
		row.conformance_dag_sha256
	assert(pins == expected_launch, "rescore result differs from exact launch pins")
	common = common or pins
	assert(pins == common, "C1 results use different conformance pins")
	accept_provenance(row, "rescore result")
	result_lines[#result_lines + 1] = table.concat({"rescore", candidate,
		("tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-%04d.tsv"):format(candidate),
		hex(raw_sha256(bytes))}, "\t")
end
local selected_lines = {}
for slot = 28, 31 do
	local path = retained .. ("selected-puc-v3-slot%02d.tsv"):format(slot)
	local verify_scratch = scratch .. ("/verify-s-%02d"):format(slot)
	assert(os.execute("mkdir " .. verify_scratch) == 0)
	local status, reason, code = os.execute(lua .. " " .. verifier .. " " .. repo ..
		" " .. verify_scratch .. " selected " .. slot .. " " .. path .. " " ..
		expected_commit .. " " .. expected_tree .. " " .. expected_dag)
	assert(status == 0 or status == true and reason == "exit" and code == 0,
		"selected partition verification failed")
	local bytes = read_file(path)
	local row = headers(bytes)
	local pins = row.conformance_commit .. ":" .. row.conformance_tree .. ":" ..
		row.conformance_dag_sha256
	assert(pins == expected_launch and pins == common,
		"selected results use different conformance pins")
	accept_provenance(row, "selected result")
	selected_lines[#selected_lines + 1] = table.concat({"selected", slot,
		row.slot_id, row.candidate_index, row.candidate_decimal, row.compiled_sha256,
		("tools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot%02d.tsv"):format(slot),
		hex(raw_sha256(bytes))}, "\t")
end
local commit, tree, dag = common:match("^([^:]+):([^:]+):([^:]+)$")
assert(commit and tree and dag)
assert(type(common_execution) == "string", "no C1 result carried an executing DAG")
local lines = {"schema\tgrug_wp40_extreme_puc_conformance_v3",
	"status\tpassed", "scope\tT2C_E0_SELECTED_FOUR_CONFORMANCE_ONLY",
	"stage2_status\tpending_seed_corpus_promotion",
	-- (a) pool origin, (b) stage-S1 currency, (c) executing code: three
	-- separate records, never merged into one "authority" line.
	"pool_measurement_commit\t" .. gate.pool_measurement_commit,
	"pool_measurement_tree\t" .. gate.pool_measurement_tree,
	"pool_authority_dag_sha256\t" .. gate.pool_authority_dag_sha256,
	"s1_authority_sha256\t" .. gate.s1_authority_sha256,
	"s1_source_projection_sha256\t" .. gate.s1_source_projection_sha256,
	"conformance_commit\t" .. commit, "conformance_tree\t" .. tree,
	"conformance_dag_sha256\t" .. dag,
	"execution_authority_dag_sha256\t" .. common_execution,
	"artifact_sha256\t" .. gate.artifact_sha256,
	"manifest_sha256\t" .. gate.manifest_sha256,
	"candidate_rows_sha256\t" .. gate.candidate_rows_sha256,
	"interpreter_id\tpuc_lua51", "rescore_count\t20", "selected_count\t4",
	"staging_label\t" .. gate.staging.label,
	"staging_decimal\t" .. gate.staging.decimal}
for index = 1, #result_lines do lines[#lines + 1] = result_lines[index] end
for index = 1, #selected_lines do lines[#lines + 1] = selected_lines[index] end
local blob = table.concat(lines, "\n") .. "\n"
if mode == "verify" then
	assert(read_file(output_path) == blob, "final C1 artifact bytes changed")
	print("WP40 T2 C1 v3 final conformance verified SHA-256 " ..
		hex(raw_sha256(blob)) .. " rescore=20 selected=4")
	return
end
local temporary = output_path .. ".tmp"
local published, message = pcall(function()
	local file = assert(io.open(temporary, "wb"))
	assert(file:write(blob)) assert(file:close())
	assert(read_file(temporary) == blob)
	assert(os.rename(temporary, output_path), "atomic final C1 publish failed")
end)
if not published then os.remove(temporary); error(message, 0) end
print("WP40 T2 C1 v3 final conformance SHA-256 " .. hex(raw_sha256(blob)) ..
	" rescore=20 selected=4 stage2=pending_seed_corpus_promotion")
