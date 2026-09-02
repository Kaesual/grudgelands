-- Narrow command-line boundary for R6 workers, pilot reduction and artifacts.

local command = assert(arg[1], "R6 CLI command required")
local repo = assert(arg[2], "repository root required")
local tool_dir = repo .. "/tools/wp40/r6"
local codec = dofile(tool_dir .. "/artifact_codec.lua")

local function fail(message)
	error("WP40 R6 CLI: " .. message, 0)
end

local function integer(text, minimum, maximum, label)
	if type(text) ~= "string" or (text ~= "0" and
			not text:match("^[1-9][0-9]*$")) then
		fail(label .. " is not minimal unsigned decimal")
	end
	local value = tonumber(text)
	if not value or value < minimum or value > maximum or value % 1 ~= 0 then
		fail(label .. " is outside its range")
	end
	return value
end

local function streaming_sha256()
	local ffi = rawget(_G, "wp40_ffi")
	if ffi == nil then fail("LuaJIT FFI injection is required for this command") end
	return dofile(tool_dir .. "/sha256_stream.lua")(ffi)
end

local function load_worker(with_sha256)
	local loader = dofile(tool_dir .. "/offline.lua")(repo)
	local evidence = dofile(tool_dir .. "/evidence.lua")(loader)
	local sha256 = with_sha256 and streaming_sha256() or false
	return dofile(tool_dir .. "/worker.lua")(codec, sha256, evidence)
end

local function print_worker_receipt(mode, worker_id, result)
	io.write("r6_worker_receipt_v1\t", mode, "\t", tostring(worker_id), "\t",
		result.sha256 or "", "\t", tostring(result.bytes), "\t",
		tostring(result.rows), "\n")
end

if command == "static-file-list" then
	if #arg ~= 2 then fail("usage: static-file-list REPO") end
	local loader = dofile(tool_dir .. "/offline.lua")(repo)
	for index = 1, #loader.fixtures.static_receipt_files do
		io.write(loader.fixtures.static_receipt_files[index], "\n")
	end
elseif command == "fleet-worker" then
	if #arg ~= 10 then
		fail("usage: fleet-worker REPO SCRATCH OUTPUT WORKER_ID SLOT_FIRST SLOT_LAST ASSIGNMENT_SHA PROJECTION_SHA PROJECTION_PATH")
	end
	local scratch, output = arg[3], arg[4]
	local worker_id = integer(arg[5], 1, 7, "worker ID")
	local result = load_worker(true).run_seed_range({mode = "fleet",
		worker_id = worker_id, scratch = scratch,
		slot_first = integer(arg[6], 1, 32, "first slot"),
		slot_last = integer(arg[7], 1, 32, "last slot"),
		assignment_sha256 = arg[8], projection_sha256 = arg[9],
		projection_path = arg[10]}, output)
	print_worker_receipt("fleet", worker_id, result)
elseif command == "roster-verify" then
	if #arg ~= 3 then fail("usage: roster-verify REPO OUTPUT") end
	local loader = dofile(tool_dir .. "/offline.lua")(repo)
	local evidence = dofile(tool_dir .. "/evidence.lua")(loader)
	local digest = evidence.verify_frozen_census_roster()
	local bytes = "schema\tgrug_wp40_r6_roster_receipt_v1\n" ..
		"selection_sha256\t" .. digest .. "\n" ..
		"population\t48\n"
	local file = assert(io.open(arg[3], "wb"), "cannot create roster receipt")
	assert(file:write(bytes)) assert(file:close())
	io.write("r6_roster_receipt_v1\t", digest, "\t48\n")
elseif command == "finalizer-preflight" then
	if #arg ~= 2 then fail("usage: finalizer-preflight REPO") end
	local loader = dofile(tool_dir .. "/offline.lua")(repo)
	local finalizer = dofile(tool_dir .. "/finalizer.lua")(loader)
	local static = finalizer.static_preflight()
	local apex = finalizer.apex_preflight()
	io.write("r6_finalizer_preflight_v1\t", static.digest, "\t",
		tostring(#static.rows), "\t", static.roster_digest, "\t",
		apex.digest, "\t", tostring(apex.population), "\n")
elseif command == "production-kat" then
	if #arg ~= 3 then fail("usage: production-kat REPO OUTPUT") end
	local bytes = dofile(tool_dir .. "/production_kat.lua")(repo)
	local file = assert(io.open(arg[3], "wb"), "cannot create production KAT")
	assert(file:write(bytes)) assert(file:close())
	io.write("r6_production_kat_receipt_v1\t", tostring(#bytes), "\n")
elseif command == "pilot-shard" then
	if #arg ~= 8 then
		fail("usage: pilot-shard REPO SCRATCH OUTPUT WORKER_ID PARTITIONS RESIDUE ASSIGNMENT_SHA")
	end
	local worker_id = integer(arg[5], 1, 7, "worker ID")
	local result = load_worker(true).run_pilot_shard({mode = "pilot_shard",
		worker_id = worker_id, scratch = arg[3],
		partition_count = integer(arg[6], 7, 7, "partition count"),
		residue = integer(arg[7], 0, 6, "residue"),
		assignment_sha256 = arg[8]}, arg[4])
	print_worker_receipt("pilot_shard", worker_id, result)
elseif command == "pilot-reference" then
	if #arg ~= 5 then
		fail("usage: pilot-reference REPO SCRATCH OUTPUT ASSIGNMENT_SHA256")
	end
	local result = load_worker(true).run_pilot_reference({mode = "pilot_reference",
		worker_id = 1, scratch = arg[3], assignment_sha256 = arg[5]}, arg[4])
	print_worker_receipt("pilot_reference", 1, result)
elseif command == "pilot-combine" then
	if #arg ~= 21 then
		fail("usage: pilot-combine REPO SCRATCH OUTPUT ASSIGNMENT_SHA REF_SHA REF_PATH (SHA PATH)x7")
	end
	local descriptors = {}
	for index = 1, 7 do
		descriptors[index] = {sha256 = arg[8 + (index - 1) * 2],
			path = arg[9 + (index - 1) * 2]}
	end
	local result = load_worker(true).combine_pilot(
		{mode = "pilot_combine", scratch = arg[3], assignment_sha256 = arg[5]},
		descriptors, {sha256 = arg[6], path = arg[7]}, arg[4])
	io.write("r6_pilot_receipt_v1\t", result.sha256, "\t",
		result.population_sha256, "\t", tostring(result.bytes), "\n")
elseif command == "finalize-global" then
	if #arg ~= 27 then
		fail("usage: finalize-global REPO SCRATCH OUTPUT ASSIGNMENT_SHA PROJECTION_SHA PROJECTION_PATH (WORKER_SHA PATH)x7 LJ_SHA LJ_PATH PUC_SHA PUC_PATH PRODUCTION_SHA PRODUCTION_PATH")
	end
	local workers = {}
	for index = 1, 7 do
		workers[index] = {sha256 = arg[6 + index * 2],
			path = arg[7 + index * 2]}
	end
	local micro = {
		{engine_id = "luajit", sha256 = arg[22], path = arg[23]},
		{engine_id = "puc51", sha256 = arg[24], path = arg[25]},
	}
	local result = load_worker(true).finalize_global({mode = "global_finalize",
		scratch = arg[3], assignment_sha256 = arg[5],
		projection_sha256 = arg[6], projection_path = arg[7]}, workers, micro,
		{sha256 = arg[26], path = arg[27]}, arg[4])
	print_worker_receipt("global_finalize", 0, result)
elseif command == "micro" then
	if #arg ~= 7 then
		fail("usage: micro REPO SCRATCH OUTPUT ENGINE_ID FINAL_BYTES ASSIGNMENT_SHA")
	end
	if arg[6] ~= "final_bytes" then fail("micro-KAT freeze token differs") end
	if arg[5] ~= "luajit" and arg[5] ~= "puc51" then
		fail("micro-KAT engine identity differs")
	end
	if not arg[7]:match("^[0-9a-f]+$") or #arg[7] ~= 64 then
		fail("micro-KAT assignment digest differs")
	end
	local bytes = dofile(tool_dir .. "/micro_kat.lua")(repo)
	local file = assert(io.open(arg[4], "wb"), "cannot create micro-KAT output")
	assert(file:write(bytes)) assert(file:close())
	io.write("r6_micro_receipt_v1\t", arg[5], "\t", tostring(#bytes), "\n")
elseif command == "combine" or command == "combine-fleet" then
	if #arg < 6 or (#arg - 4) % 2 ~= 0 then
		fail("usage: combine[-fleet] REPO OUTPUT COUNT (SHA PATH)...")
	end
	local expected = integer(arg[4], 1, 8, "fragment count")
	if command == "combine-fleet" and expected ~= 8 then
		fail("fleet combine requires seven worker fragments plus one global fragment")
	end
	if (#arg - 4) / 2 ~= expected then fail("fragment count differs") end
	local descriptors = {}
	for index = 1, expected do
		descriptors[index] = {sha256 = arg[3 + index * 2],
			path = arg[4 + index * 2],
			skip_access = command == "combine-fleet" and index <= 7}
	end
	local combiner = dofile(tool_dir .. "/artifact_combiner.lua")(
		codec, streaming_sha256())
	local result = combiner.combine(descriptors, arg[3])
	io.write("r6_artifact_receipt_v1\t", result.body_sha256, "\t",
		result.file_sha256, "\t", tostring(result.data_rows), "\t",
		tostring(result.bytes), "\n")
elseif command == "validate" then
	if #arg ~= 3 and #arg ~= 4 then
		fail("usage: validate REPO ARTIFACT [EXPECTED_FILE_SHA256]")
	end
	local combiner = dofile(tool_dir .. "/artifact_combiner.lua")(
		codec, streaming_sha256())
	local result = combiner.validate(arg[3], arg[4])
	io.write("r6_artifact_valid_v1\t", result.body_sha256, "\t",
		result.file_sha256, "\t", tostring(result.data_rows), "\t",
		tostring(result.bytes), "\n")
else
	fail("unknown command " .. tostring(command))
end
