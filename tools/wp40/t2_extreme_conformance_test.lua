local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(arg[3] == nil)
assert(repo:match("^/[A-Za-z0-9._/-]+$") and not repo:find("/../", 1, true) and
	not repo:find("/./", 1, true) and repo:sub(-3) ~= "/.." and
	repo:sub(-2) ~= "/." and
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-conformance%.[A-Za-z0-9]+$"),
	"unsafe T2 conformance test path")

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
local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do result[deep_copy(key, seen)] =
		deep_copy(child, seen) end
	return result
end
local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok and tostring(message):find(fragment, 1, true), tostring(message))
end

local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority = assert(loadstring(authority_bytes, "@" .. authority_path))()({
	raw_sha256 = raw_sha256})
local files = authority.capture_files(repo, {[authority_path] = authority_bytes})
local canonical = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = authority.load_module(files,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
		deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
		scalar_reader = function() error("conformance parser cannot materialize") end,
		seed_corpus = seed_corpus, source = source})
local conformance = assert(loadfile(repo ..
	"/tools/wp40/t2_extreme_conformance.lua"))()({raw_sha256 = raw_sha256,
	extreme = extreme, rational_compare = extreme.rational_compare,
	decimal_less = extreme.decimal_less})
local gate = assert(loadfile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua"))()
local retained = repo .. "/tools/wp40/fixtures/t2_extreme_e0/"
local artifact_bytes = read_file(retained .. "candidates-luajit.tsv")
local manifest_bytes = read_file(retained .. "manifest-luajit.tsv")
local parsed = conformance.parse_artifact(artifact_bytes, gate)
local manifest = conformance.parse_manifest(manifest_bytes, gate)
for index = 1, 8 do
	assert(conformance.digest(read_file(repo .. "/" .. manifest.shards[index].path)) ==
		manifest.shards[index].sha256, "retained shard digest changed")
end
local slots, staging, required = conformance.selected_and_required(parsed, gate,
	extreme.staging_seed)
assert(#slots == 4 and #required == 20 and staging.decimal == gate.staging.decimal)
local expected_indices = {0, 511, 512, 1023, 1024, 1047, 1535, 1536, 1713,
	2047, 2048, 2192, 2559, 2560, 3071, 3072, 3438, 3583, 3584, 4095}
for index = 1, #expected_indices do assert(required[index] == expected_indices[index]) end

-- Independent ranking regression: equal rational scores use lower decimal,
-- and each chosen decimal is removed before the next category is scanned.
local synthetic = {
	{status = "scored", candidate_index = 1, decimal = "10",
		coast_n = 5, coast_d = 1, noncoast_n = 100, noncoast_d = 1},
	{status = "scored", candidate_index = 2, decimal = "2",
		coast_n = 10, coast_d = 2, noncoast_n = 1000, noncoast_d = 1},
	{status = "scored", candidate_index = 3, decimal = "3",
		coast_n = -5, coast_d = 1, noncoast_n = -100, noncoast_d = 1},
	{status = "scored", candidate_index = 4, decimal = "4",
		coast_n = 0, coast_d = 1, noncoast_n = -200, noncoast_d = 1},
}
local synthetic_slots = conformance.sequential_slots(synthetic)
assert(synthetic_slots[1].candidate_index == 2 and
	synthetic_slots[2].candidate_index == 3 and
	synthetic_slots[3].candidate_index == 1 and
	synthetic_slots[4].candidate_index == 4,
	"rational tie or sequential chosen skip changed")

for _, mutation in ipairs({
	function(row) row.extra = true end,
	function(row) row.artifact_sha256 = string.rep("0", 64) end,
	function(row) row.winners[1].candidate_index = row.winners[2].candidate_index end,
	function(row) table.remove(row.shards) end,
}) do
	local corrupt = deep_copy(gate)
	mutation(corrupt)
	expect_error("conformance", function()
		conformance.parse_artifact(artifact_bytes, corrupt)
	end)
end
local corrupted_artifact = artifact_bytes:sub(1, #artifact_bytes - 2) .. "x\n"
expect_error("artifact digest", function()
	conformance.parse_artifact(corrupted_artifact, gate)
end)
local corrupted_manifest = manifest_bytes:gsub("shard\t0\t511", "shard\t1\t511", 1)
expect_error("manifest digest", function()
	conformance.parse_manifest(corrupted_manifest, gate)
end)

local conformance_pins = {commit = string.rep("1", 40),
	tree = string.rep("2", 40), dag = string.rep("3", 64)}
assert(conformance.validate_launch_pins(conformance_pins))
local stale_launch_pins = {commit = string.rep("9", 40),
	tree = string.rep("a", 40), dag = string.rep("b", 64)}
for _, corrupt in ipairs({
	{commit = conformance_pins.commit, tree = conformance_pins.tree},
	{commit = conformance_pins.commit, tree = conformance_pins.tree,
		dag = conformance_pins.dag, extra = true},
}) do
	expect_error("conformance launch pins", function()
		conformance.validate_launch_pins(corrupt)
	end)
end
local row_sha = conformance.digest(assert(parsed.raw_by_index[0]) .. "\n")
local rescore = {schema = "grug_wp40_extreme_puc_rescore_v1", status = "passed",
	scope = "T2C_E0_PUC_ROW_CONFORMANCE_ONLY",
	measurement_commit = gate.measurement_commit, measurement_tree = gate.measurement_tree,
	authority_dag_sha256 = gate.authority_dag_sha256,
	conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag,
	source_checksum = gate.source_checksum,
	boundary_policy_checksum = gate.boundary_policy_checksum,
	partition_sha256 = gate.partition_sha256, artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = repo .. "/tools/bin/lua51",
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = string.rep("4", 64), candidate_index = 0,
	candidate_decimal = parsed.rows_by_index[0].decimal, candidate_role = "endpoint",
	expected_row_sha256 = row_sha, rescored_row_sha256 = row_sha}
assert(conformance.validate_rescore_result(rescore, gate, 0, row_sha,
	conformance_pins, repo .. "/tools/bin/lua51"))
assert(conformance.assert_launch_pins(rescore, conformance_pins,
	"PUC rescore result"))
expect_error("PUC rescore result launch pins changed", function()
	conformance.assert_launch_pins(rescore, stale_launch_pins, "PUC rescore result")
end)
local rescore_blob = conformance.rescore_result_blob(rescore)
assert(conformance.validate_rescore_result(conformance.parse_rescore_result(rescore_blob),
	gate, 0, row_sha, conformance_pins, repo .. "/tools/bin/lua51"))
for _, noncanonical in ipairs({
	(rescore_blob:gsub("candidate_index\t0\n", "candidate_index\t00\n", 1)),
	(rescore_blob:gsub("candidate_index\t0\n", "candidate_index\t0e0\n", 1)),
}) do
	expect_error("PUC rescore result bytes are not canonical", function()
		conformance.parse_rescore_result(noncanonical)
	end)
end
for _, mutation in ipairs({
	function(row) row.extra = true end,
	function(row) row.rescored_row_sha256 = string.rep("5", 64) end,
	function(row) row.conformance_commit = string.rep("6", 40) end,
	function(row) row.interpreter_path = "/fake/tools/bin/lua51" end,
}) do
	local corrupt = deep_copy(rescore)
	mutation(corrupt)
	expect_error("PUC rescore", function()
		conformance.validate_rescore_result(corrupt, gate, 0, row_sha,
			conformance_pins, repo .. "/tools/bin/lua51")
	end)
end

local winner = gate.winners[1]
local selected = {schema = "grug_wp40_extreme_selected_partition_v1",
	status = "passed", scope = "T2C_E0_SELECTED_FOUR_PARTITION_CONFORMANCE_ONLY",
	measurement_commit = gate.measurement_commit, measurement_tree = gate.measurement_tree,
	authority_dag_sha256 = gate.authority_dag_sha256,
	conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag,
	source_checksum = gate.source_checksum,
	boundary_policy_checksum = gate.boundary_policy_checksum,
	partition_sha256 = gate.partition_sha256, artifact_sha256 = gate.artifact_sha256,
	manifest_sha256 = gate.manifest_sha256,
	candidate_rows_sha256 = gate.candidate_rows_sha256,
	interpreter_id = "puc_lua51", interpreter_path = repo .. "/tools/bin/lua51",
	interpreter_version = "Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	interpreter_sha256 = string.rep("7", 64), slot = winner.slot, slot_id = winner.id,
	candidate_index = winner.candidate_index, candidate_decimal = winner.decimal,
	compiled_sha256 = string.rep("8", 64), columns = 100, base_total = 20,
	planned_water = 40, dry = 60, g = 0, o = 0, r = 0, m = 0,
	schedule_intervals = 10, perimeter_aperture = 2, perimeter_attachment = 8,
	perimeter_dry = 6, transition_count = 8, bank_count = 20, wing_count = 8,
	coast_count = 22, face_count = 38}
assert(conformance.validate_selected_result(selected, gate, winner, conformance_pins,
	repo .. "/tools/bin/lua51"))
assert(conformance.assert_launch_pins(selected, conformance_pins,
	"selected partition result"))
expect_error("selected partition result launch pins changed", function()
	conformance.assert_launch_pins(selected, stale_launch_pins,
		"selected partition result")
end)
-- The final fast path reads these same three exact fields before accepting
-- any retained child count.  A final artifact from a previous clean HEAD is
-- therefore rejected even when all of its child pins agree with each other.
local final_header = {conformance_commit = conformance_pins.commit,
	conformance_tree = conformance_pins.tree,
	conformance_dag_sha256 = conformance_pins.dag}
assert(conformance.assert_launch_pins(final_header, conformance_pins,
	"final conformance artifact"))
expect_error("final conformance artifact launch pins changed", function()
	conformance.assert_launch_pins(final_header, stale_launch_pins,
		"final conformance artifact")
end)
local selected_blob = conformance.selected_result_blob(selected)
assert(conformance.validate_selected_result(conformance.parse_selected_result(selected_blob),
	gate, winner, conformance_pins, repo .. "/tools/bin/lua51"))
for _, noncanonical in ipairs({
	(selected_blob:gsub("slot\t28\n", "slot\t028\n", 1)),
	(selected_blob:gsub("columns\t100\n", "columns\t1e2\n", 1)),
}) do
	expect_error("selected partition result bytes are not canonical", function()
		conformance.parse_selected_result(noncanonical)
	end)
end
for _, mutation in ipairs({
	function(row) row.extra = true end,
	function(row) row.g = 1 end,
	function(row) row.candidate_decimal = "1" end,
	function(row) row.perimeter_attachment = 7 end,
	function(row) row.base_total = 0 end,
	function(row) row.base_total = row.planned_water + 1 end,
	function(row) row.schedule_intervals = 0 end,
	function(row) row.interpreter_path = "/fake/tools/bin/lua51" end,
}) do
	local corrupt = deep_copy(selected)
	mutation(corrupt)
	expect_error("selected partition", function()
		conformance.validate_selected_result(corrupt, gate, winner, conformance_pins,
			repo .. "/tools/bin/lua51")
	end)
end

print("WP40 T2 E0 conformance foundation passed artifact=" .. gate.artifact_sha256 ..
	" manifest=" .. gate.manifest_sha256 .. " rescore_count=" .. #required ..
	" winners=" .. slots[1].candidate_index .. "," .. slots[2].candidate_index ..
	"," .. slots[3].candidate_index .. "," .. slots[4].candidate_index)
