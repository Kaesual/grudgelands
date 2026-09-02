local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(arg[3] == nil, "merge accepts no output-path arguments")
assert(_VERSION == "Lua 5.1" and rawget(_G, "jit") == nil,
	"merge/ranking requires plain PUC Lua 5.1")
local merge_interpreter_path = repo .. "/tools/bin/lua51"
assert(arg[-1] == merge_interpreter_path,
	"merge/ranking requires the reviewed vendored interpreter path")

local function safe_absolute_path(value)
	assert(type(value) == "string" and value:match("^/[A-Za-z0-9._/-]+$") and
		not value:find("/../", 1, true) and not value:find("/./", 1, true) and
		not value:find("//", 1, true), "unsafe absolute path")
	return value
end
for _, path in ipairs({repo, scratch}) do
	safe_absolute_path(path)
end
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-extreme%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
local retained_root = repo .. "/tools/wp40/fixtures/t2_extreme_e0/"
-- v3 outputs carry their own names. The unsuffixed manifest-luajit.tsv and
-- candidates-luajit.tsv are the frozen pre-v3 measurement: their exact paths
-- are content-pinned by t2_extreme_conformance_authority.lua, and the retained
-- manifest digest is pinned by fixtures/t2_extreme_e0/selected_stage2_blocked.
-- Writing v3 bytes over them would destroy historical evidence in place.
local manifest_path = retained_root .. "manifest-luajit-v3.tsv"
local artifact_path = retained_root .. "candidates-luajit-v3.tsv"
assert(manifest_path ~= artifact_path)
for _, path in ipairs({manifest_path, artifact_path, manifest_path .. ".tmp",
		artifact_path .. ".tmp"}) do
	local existing = io.open(path, "rb")
	if existing then existing:close(); error("merge output already exists", 0) end
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
local sha_cache, sha_counter = {}, 0
local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/merge-sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/merge-sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	local line = read_file(output)
	local raw = from_hex(assert(line:match("^([0-9a-f]+)")))
	assert(#raw == 32)
	sha_cache[data] = raw
	return raw
end
local merge_interpreter_sha256 = (raw_sha256(read_file(merge_interpreter_path)):gsub(
	".", function(byte) return ("%02x"):format(string.byte(byte)) end))
assert(merge_interpreter_sha256 ==
	"a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f",
	"merge/ranking PUC binary changed")

-- Bind the same complete file graph as the immutable-export workers before
-- loading scorer modules.  Merge later rechecks these bytes before its only
-- retained write.
local authority_path = "tools/wp40/t2_extreme_authority.lua"
local authority_bytes = read_file(repo .. "/" .. authority_path)
local authority_chunk = assert(loadstring(authority_bytes, "@" .. authority_path))
local authority = authority_chunk()({raw_sha256 = raw_sha256})
local file_snapshot = authority.capture_files(repo,
	{[authority_path] = authority_bytes})
local authority_snapshot = authority.bind_expected_vocabulary(file_snapshot)
local first_shard_path = repo .. "/" .. authority.retained_shard_path(0, 511)
local first_shard_provenance = authority.preparse_shard_provenance(
	read_file(first_shard_path))
local pinned_snapshot = authority.validate_pinned_authority(repo, scratch,
	first_shard_provenance)
assert(pinned_snapshot.authority_dag_sha256 ==
	authority_snapshot.authority_dag_sha256,
	"current merge Authority-DAG differs from the pinned measurement commit")
local full_scan_gate = authority.load_module(file_snapshot,
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua")
assert(authority.validate_full_scan_gate(full_scan_gate))

-- Preload the 4096 candidate-label hashes in one bounded process. Parsing a
-- retained shard then performs zero per-row hash forks while still deriving
-- every identity independently from its index.
local batch_in, batch_out = scratch .. "/merge-labels.bin",
	scratch .. "/merge-labels.out"
local batch = assert(io.open(batch_in, "wb"))
local labels = {}
for index = 0, 4095 do
	local label = ("grudgelands-wp40-extreme-%04d"):format(index)
	labels[index + 1] = label
	assert(batch:write(tostring(#label), "\n", label))
end
assert(batch:close())
local status, reason, code = os.execute("python3 " .. repo ..
	"/tools/wp40/t2_sha256_batch.py " .. batch_in .. " " .. batch_out)
assert(status == 0 or status == true and reason == "exit" and code == 0)
local label_hashes = read_file(batch_out)
assert(#label_hashes == 4096 * 32)
for index = 1, 4096 do
	sha_cache[labels[index]] = label_hashes:sub(index * 32 - 31, index * 32)
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
local deterministic = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local exact = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({deterministic = deterministic})
local seed_corpus = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local source = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local extreme = authority.load_module(file_snapshot,
	"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua")({
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256,
	scalar_reader = function() error("merge must not materialize scalar geometry") end,
	seed_corpus = seed_corpus, source = source})

local pins
local shards, shard_manifest_lines = {}, {}
local measurement_ranges = authority.canonical_measurement_ranges()
assert(authority.validate_measurement_ranges(measurement_ranges))
for index = 1, #measurement_ranges do
	local first, last = measurement_ranges[index].first, measurement_ranges[index].last
	local relative_path = authority.retained_shard_path(first, last)
	assert(authority.validate_retained_shard_path(relative_path, first, last))
	local path = repo .. "/" .. relative_path
	local bytes = read_file(path)
	local digest = canonical.hex(raw_sha256(bytes))
	local shard = extreme.parse_shard_blob(bytes)
	assert(shard.first_index == first and shard.last_index == last,
		"retained measurement shard range changed")
	if pins == nil then
		pins = shard.pins
	else
		for key, value in pairs(pins) do
			assert(shard.pins[key] == value, "retained measurement shard pins differ")
		end
		for key in pairs(shard.pins) do
			assert(pins[key] ~= nil, "retained measurement shard pins differ")
		end
	end
	shards[index] = shard
	shard_manifest_lines[index] = table.concat({"shard", first, last,
		relative_path, digest}, "\t")
end
assert(pins)
-- Every shard must agree with the checked-in stage-S1 gate. The gate is
-- re-derived from the live tree by t2_extreme_gate_check.lua before any
-- measurement; the merge only has to prove the eight shards and the gate speak
-- about the same S1.
assert(pins.s1_authority_sha256 == full_scan_gate.s1_authority_sha256,
	"retained shard stage-S1 authority differs from the full-scan gate")
assert(pins.s1_source_projection_sha256 ==
	full_scan_gate.s1_source_projection_sha256,
	"retained shard stage-S1 Source projection differs from the full-scan gate")
assert(pins.scorer_schema == "grug_wp40_extreme_selector_e0_v1")
assert(authority.verify_git_provenance(repo, scratch, pins.authority_commit,
	pins.authority_tree))
assert(pins.measurement_scope == "R7_SCALAR_MEASUREMENT_ONLY" and
	pins.stage2_status == "pending_selected_four",
	"retained measurement scope changed")
assert(pins.interpreter_id == "luajit" and
	pins.interpreter_launcher == "/usr/bin/luajit" and
	pins.interpreter_path == "/usr/bin/luajit-2.1.1767980792" and
	pins.interpreter_version ==
		"LuaJIT 2.1.1767980792 -- Copyright (C) 2005-2026 Mike Pall. https://luajit.org/",
	"retained 4096 measurement interpreter changed")
assert(pins.authority_dag_sha256 == authority_snapshot.authority_dag_sha256,
	"manifest Authority-DAG pin differs")
assert(canonical.hex(raw_sha256(read_file(pins.interpreter_path))) ==
	pins.interpreter_sha256, "measurement interpreter binary changed")
local rows = extreme.merge_shards(shards, pins)
local candidates = extreme.candidate_blob(rows)
local candidate_sha = canonical.hex(raw_sha256(candidates))
local artifact = table.concat({
	"schema\tgrug_wp40_extreme_measurement_artifact_v3",
	"measurement_scope\t" .. pins.measurement_scope,
	"stage2_status\t" .. pins.stage2_status,
	"s1_authority_sha256\t" .. pins.s1_authority_sha256,
	"s1_source_projection_sha256\t" .. pins.s1_source_projection_sha256,
	"authority_dag_sha256\t" .. pins.authority_dag_sha256,
	"authority_commit\t" .. pins.authority_commit,
	"authority_tree\t" .. pins.authority_tree,
	"interpreter_id\t" .. pins.interpreter_id,
	"interpreter_launcher\t" .. pins.interpreter_launcher,
	"interpreter_path\t" .. pins.interpreter_path,
	"interpreter_version\t" .. pins.interpreter_version,
	"interpreter_sha256\t" .. pins.interpreter_sha256,
	"scorer_schema\t" .. pins.scorer_schema,
	"candidate_rows_sha256\t" .. candidate_sha,
	"merge_interpreter_id\tpuc_lua51",
	"merge_interpreter_path\t" .. merge_interpreter_path,
	"merge_interpreter_version\tLua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	"merge_interpreter_sha256\t" .. merge_interpreter_sha256,
}, "\n") .. "\n" .. candidates
local artifact_sha = canonical.hex(raw_sha256(artifact))
local slots = extreme.select_slots(rows)
local staging = extreme.staging_seed(slots)
local manifest_lines = {
	"grug_wp40_extreme_shard_manifest_v3",
	"measurement_scope\t" .. pins.measurement_scope,
	"stage2_status\t" .. pins.stage2_status,
	"s1_authority_sha256\t" .. pins.s1_authority_sha256,
	"s1_source_projection_sha256\t" .. pins.s1_source_projection_sha256,
	"authority_dag_sha256\t" .. pins.authority_dag_sha256,
	"authority_commit\t" .. pins.authority_commit,
	"authority_tree\t" .. pins.authority_tree,
	"interpreter_id\t" .. pins.interpreter_id,
	"interpreter_launcher\t" .. pins.interpreter_launcher,
	"interpreter_path\t" .. pins.interpreter_path,
	"interpreter_version\t" .. pins.interpreter_version,
	"interpreter_sha256\t" .. pins.interpreter_sha256,
	"scorer_schema\t" .. pins.scorer_schema,
	"merge_interpreter_id\tpuc_lua51",
	"merge_interpreter_path\t" .. merge_interpreter_path,
	"merge_interpreter_version\tLua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
	"merge_interpreter_sha256\t" .. merge_interpreter_sha256,
}
for index = 1, #shard_manifest_lines do
	manifest_lines[#manifest_lines + 1] = shard_manifest_lines[index]
end
local manifest = table.concat(manifest_lines, "\n") .. "\n"
-- The retained output is created last. No rejected merge, selection, staging,
-- pin, or path may leave a partial authority artifact behind.
assert(authority.verify(repo, authority_snapshot))
assert(canonical.hex(raw_sha256(read_file(pins.interpreter_path))) ==
	pins.interpreter_sha256, "measurement interpreter changed before publication")
local temporary_path = artifact_path .. ".tmp"
local temporary_manifest = manifest_path .. ".tmp"
local published, publish_message = pcall(function()
	local output = assert(io.open(temporary_path, "wb"))
	assert(output:write(artifact)) assert(output:close())
	assert(read_file(temporary_path) == artifact, "artifact bytes changed after write")
	output = assert(io.open(temporary_manifest, "wb"))
	assert(output:write(manifest)) assert(output:close())
	assert(read_file(temporary_manifest) == manifest,
		"manifest bytes changed after write")
	assert(os.rename(temporary_path, artifact_path), "atomic artifact publish failed")
	assert(os.rename(temporary_manifest, manifest_path), "atomic manifest publish failed")
end)
if not published then
	os.remove(temporary_path)
	os.remove(temporary_manifest)
	-- The manifest is the completion marker. If its final rename failed after
	-- the artifact rename, remove only this just-created unreferenced output.
	local manifest_file = io.open(manifest_path, "rb")
	if not manifest_file then os.remove(artifact_path) else manifest_file:close() end
	error(publish_message, 0)
end
print("WP40 T2 E0 merged candidate artifact SHA-256 " .. artifact_sha)
print("WP40 T2 E0 scope=" .. pins.measurement_scope ..
	" stage2=" .. pins.stage2_status .. " candidate_rows_sha256=" .. candidate_sha)
for index = 1, #slots do
	local slot = slots[index]
	print(("WP40 T2 E0 measured slot=%d id=%s candidate=%04d decimal=%s " ..
		"score=%d/%d"):format(slot.slot, slot.id, slot.candidate_index,
		slot.decimal, slot.score_n, slot.score_d))
end
print("WP40 T2 E0 staging " .. staging.label .. " " .. staging.decimal)
