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

local function write_file(path, bytes)
	if type(bytes) ~= "string" or bytes == "" then fail("output bytes are absent") end
	local file, message = io.open(path, "wb")
	if not file then fail("cannot create output: " .. tostring(message)) end
	assert(file:write(bytes))
	assert(file:close())
end

if mode == "catalog" then
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
	local seed_slot = tonumber(assert(arg[5], "pilot seed slot required"))
	if arg[6] ~= nil then fail("pilot arguments differ") end
	local receipt = adapter.pilot(repo, scratch, seed_slot)
	write_file(output, contract.pilot_result_bytes(receipt))
	print("WP40 R7 pilot PASS seed_slot=" .. tostring(seed_slot))
elseif mode == "worker" then
	local scratch = assert(arg[4], "worker scratch required")
	local first_slot = tonumber(assert(arg[5], "first slot required"))
	local last_slot = tonumber(assert(arg[6], "last slot required"))
	local projection_sha256 = assert(arg[7], "projection SHA-256 required")
	if arg[8] ~= nil then fail("worker arguments differ") end
	local result = adapter.worker(repo, scratch, first_slot, last_slot,
		projection_sha256)
	if type(result) ~= "string" or
			not result:find("^schema\tgrug_wp40_r7_worker_receipt_v1\n") then
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
	local receipt = assert(arg[9], "run-receipt output required")
	local worker_paths = {}
	for index = 10, #arg do worker_paths[#worker_paths + 1] = arg[index] end
	if #worker_paths ~= 7 then fail("finalizer requires exactly seven workers") end
	local result = adapter.finalize(repo, scratch, worker_paths)
	if type(result) ~= "table" then fail("finalizer result is not a table") end
	local outputs = {
		{artifact, result.artifact_bytes, "grug_wp40_r7_artifact_v1"},
		{stage_a, result.stage_a_bytes, "grug_wp40_r7_stage_a_aggregate_v1"},
		{stage_b, result.stage_b_bytes, "grug_wp40_r7_stage_b_aggregate_v1"},
		{p9g, result.p9g_bytes, "grug_wp40_r7_p9g_ledger_v1"},
		{receipt, result.run_receipt_bytes, "grug_wp40_r7_run_receipt_v1"},
	}
	for index = 1, #outputs do
		local path, bytes, schema = outputs[index][1], outputs[index][2], outputs[index][3]
		if type(bytes) ~= "string" or not bytes:find("^schema\t" .. schema .. "\n") then
			fail("finalizer " .. schema .. " bytes differ")
		end
		write_file(path, bytes)
	end
	print("WP40 R7 finalizer PASS workers=7")
else
	fail("unknown mode " .. tostring(mode))
end
