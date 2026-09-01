-- Command-line entry point for the R7 evidence bridge. All output files are
-- created by this process from validated canonical bytes.

local mode = assert(arg[1], "mode required")
local repo = assert(arg[2], "repository root required")
local output = assert(arg[3], "output path required")
local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
local adapter = dofile(repo .. "/tools/wp40/r7/integration_adapter.lua")

local function fail(message)
	error("WP40 R7 adapter CLI: " .. message, 0)
end

local function slot_argument(index, label)
	local raw = arg[index]
	if type(raw) ~= "string" or not raw:match("^[1-9][0-9]*$") then
		fail(label .. " is not one canonical decimal slot")
	end
	local value = tonumber(raw)
	if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > 32 then
		fail(label .. " is outside the frozen 1..32 corpus")
	end
	return value
end

local function write_file(path, bytes)
	if type(bytes) ~= "string" or bytes == "" then fail("output bytes are absent") end
	local file, message = io.open(path, "wb")
	if not file then fail("cannot create output: " .. tostring(message)) end
	assert(file:write(bytes))
	assert(file:close())
end

local function copy_descriptor(path, descriptor, schema)
	if type(descriptor) ~= "table" or type(descriptor.path) ~= "string" or
			type(descriptor.sha256) ~= "string" or #descriptor.sha256 ~= 64 or
			not descriptor.sha256:match("^[0-9a-f]+$") or
			type(descriptor.bytes) ~= "number" or descriptor.bytes % 1 ~= 0 or
			descriptor.bytes < 1 then
		fail("finalizer " .. schema .. " descriptor differs")
	end
	local count = 0
	for key in pairs(descriptor) do
		if key ~= "path" and key ~= "sha256" and key ~= "bytes" then
			fail("finalizer " .. schema .. " descriptor has unknown field")
		end
		count = count + 1
	end
	if count ~= 3 then fail("finalizer " .. schema .. " descriptor is incomplete") end
	local source = assert(io.open(descriptor.path, "rb"), "cannot read finalizer output")
	local header = source:read("*l")
	if header ~= "schema\t" .. schema then
		fail("finalizer " .. schema .. " schema differs")
	end
	assert(source:seek("set", 0))
	local probe = io.open(path, "rb")
	if probe then probe:close(); fail("finalizer destination already exists") end
	local output = assert(io.open(path, "wb"), "cannot create finalizer destination")
	local stream = dofile(repo .. "/tools/wp40/r6/sha256_stream.lua")(
		assert(rawget(_G, "wp40_ffi"), "wp40_ffi injection required"))
	local hasher, bytes = stream.new(), 0
	while true do
		local chunk = source:read(1024 * 1024)
		if not chunk then break end
		if chunk == "" then fail("finalizer source stream stalled") end
		assert(output:write(chunk)); hasher.update(chunk); bytes = bytes + #chunk
	end
	assert(source:close()); assert(output:close())
	if hasher.final_hex() ~= descriptor.sha256 or bytes ~= descriptor.bytes then
		fail("finalizer " .. schema .. " descriptor binding differs")
	end
end

if mode == "sample-roster" then
	if arg[4] ~= nil then fail("sample-roster arguments differ") end
	local bytes = adapter.sample_assignment(repo)
	write_file(output, bytes)
	print("WP40 R7 sample roster PASS seeds=32 owners=4096")
elseif mode == "frontier-access-roster" then
	if arg[4] ~= nil then fail("frontier-access-roster arguments differ") end
	local bytes = adapter.frontier_access_assignment(repo)
	write_file(output, bytes)
	print("WP40 R7 frontier access roster PASS seeds=32 owners=14656")
elseif mode == "catalog" then
	if arg[4] ~= nil then fail("catalog arguments differ") end
	local snapshot = adapter.catalog_snapshot(repo)
	contract.validate_catalog(snapshot, adapter.raw_sha256)
	write_file(output, contract.catalog_receipt(snapshot))
	print("WP40 R7 catalog gate PASS sha256=" .. snapshot.manifest.sha256 ..
		" populations=12/8/6")
elseif mode == "integration-kat" then
	if arg[4] ~= nil then fail("integration-kat arguments differ") end
	local receipt = adapter.integration_kat(repo)
	write_file(output, contract.integration_receipt_bytes(receipt))
	print("WP40 R7 integration KAT PASS manifest=" .. receipt.r7_manifest_sha256)
elseif mode == "pilot" then
	local scratch = assert(arg[4], "pilot scratch required")
	local seed_slot = slot_argument(5, "pilot seed slot")
	if arg[6] ~= nil then fail("pilot arguments differ") end
	local receipt = adapter.pilot(repo, scratch, seed_slot)
	write_file(output, contract.pilot_result_bytes(receipt))
	print("WP40 R7 pilot PASS seed_slot=" .. tostring(seed_slot))
elseif mode == "worker" then
	local scratch = assert(arg[4], "worker scratch required")
	local first_slot = slot_argument(5, "worker first slot")
	local last_slot = slot_argument(6, "worker last slot")
	local projection_sha256 = assert(arg[7], "projection SHA-256 required")
	if arg[8] ~= nil then fail("worker arguments differ") end
	local result = adapter.worker(repo, scratch, first_slot, last_slot,
		projection_sha256)
	if type(result) ~= "string" or
			not result:find("^schema\tgrug_wp40_r7_worker_receipt_v2\n") then
		fail("runtime adapter returned an invalid worker receipt")
	end
	write_file(output, result)
	print("WP40 R7 worker PASS slots=" .. first_slot .. "-" .. last_slot)
elseif mode == "finalize" then
	local scratch = assert(arg[4], "finalizer scratch required")
	local artifact = assert(arg[5], "artifact output required")
	local stage_a = assert(arg[6], "Stage-A output required")
	local stage_b = assert(arg[7], "Stage-B output required")
	local p9g = assert(arg[8], "P9G output required")
	local frontier_access = assert(arg[9], "Frontier access output required")
	local receipt = assert(arg[10], "run-receipt output required")
	local worker_paths = {}
	for index = 11, #arg do worker_paths[#worker_paths + 1] = arg[index] end
	if #worker_paths ~= 7 then fail("finalizer requires exactly seven workers") end
	local result = adapter.finalize(repo, scratch, worker_paths)
	if type(result) ~= "table" then fail("finalizer result is not a table") end
	local outputs = {
		{artifact, result.artifact, "grug_wp40_r7_artifact_v1"},
		{stage_a, result.stage_a, "grug_wp40_r7_stage_a_aggregate_v1"},
		{stage_b, result.stage_b, "grug_wp40_r7_stage_b_aggregate_v1"},
		{p9g, result.p9g, "grug_wp40_r7_p9g_ledger_v1"},
		{frontier_access, result.frontier_access,
			"grug_wp40_r7_frontier_access_ledger_v1"},
		{receipt, result.run_receipt,
			"grug_wp40_r7_run_receipt_v2"},
	}
	for index = 1, #outputs do
		copy_descriptor(outputs[index][1], outputs[index][2], outputs[index][3])
	end
	print("WP40 R7 finalizer PASS workers=7")
else
	fail("unknown mode " .. tostring(mode))
end
