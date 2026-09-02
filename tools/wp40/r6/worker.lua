-- Contract-shaped R6 evidence worker. The exhaustive evidence implementation
-- plugs into the explicitly named API methods below; no fallback population is
-- invented when that API is incomplete.

return function(codec, sha256, evidence)
	if type(codec) ~= "table" or type(codec.encode_data_row) ~= "function" or
			type(evidence) ~= "table" then
		error("WP40 R6 worker dependencies differ", 0)
	end
	local module = {}

	local function fail(message)
		error("WP40 R6 worker: " .. message, 0)
	end

	local function evidence_method(name)
		local method = evidence[name]
		if type(method) ~= "function" then
			fail("TODO evidence API: evidence." .. name .. " is not implemented")
		end
		return method
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" then fail(label .. " is not a table") end
		for key in pairs(value) do
			if not allowed[key] then fail(label .. " has an unexpected field") end
		end
		for key in pairs(allowed) do
			if value[key] == nil then fail(label .. " is missing " .. key) end
		end
		return value
	end

	local function integer(value, minimum, maximum, label)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or value < minimum or
				value > maximum then
			fail(label .. " is outside its integer range")
		end
		return value
	end

	local function digest_text(value, label)
		if type(value) ~= "string" or #value ~= 64 or
				not value:match("^[0-9a-f]+$") then
			fail(label .. " is not lowercase SHA-256")
		end
		return value
	end

	local function write_bytes(path, bytes)
		if type(path) ~= "string" or path == "" then fail("output path is missing") end
		if type(bytes) ~= "string" or bytes == "" then fail("output bytes are empty") end
		local file = assert(io.open(path, "wb"), "cannot create " .. path)
		assert(file:write(bytes))
		assert(file:close())
		return #bytes
	end

	local function require_sha256()
		if type(sha256) ~= "table" or type(sha256.file) ~= "function" then
			fail("streaming SHA-256 is unavailable for this worker mode")
		end
		return sha256
	end

	local function verify_descriptors(descriptors, expected_count, label)
		if type(descriptors) ~= "table" or #descriptors ~= expected_count then
			fail(label .. " descriptor population differs")
		end
		local file_sha256 = require_sha256()
		local seen_paths = {}
		for index = 1, expected_count do
			local descriptor = descriptors[index]
			if type(descriptor) ~= "table" or type(descriptor.path) ~= "string" or
					descriptor.path == "" then
				fail(label .. " descriptor " .. tostring(index) .. " differs")
			end
			digest_text(descriptor.sha256,
				label .. " descriptor " .. tostring(index) .. " digest")
			if seen_paths[descriptor.path] then fail("duplicate " .. label .. " path") end
			seen_paths[descriptor.path] = true
			local actual = file_sha256.file(descriptor.path)
			if actual ~= descriptor.sha256 then fail(label .. " file digest differs") end
		end
		return true
	end

	local function structured_row(row, index)
		exact_fields(row, {row_type = true, keys = true, values = true},
			"evidence row " .. tostring(index))
		if type(row.row_type) ~= "string" or type(row.keys) ~= "table" or
				type(row.values) ~= "table" then
			fail("evidence row " .. tostring(index) .. " shape differs")
		end
		local bytes = codec.encode_data_row(row.row_type, row.keys, row.values)
		local line = bytes:sub(1, -2)
		return {bytes = bytes,
			fields = codec.parse_data_line(line, "evidence row " .. tostring(index))}
	end

	local function write_fragment(path, result)
		exact_fields(result, {schema = true, rows = true}, "seed-range result")
		if result.schema ~= "grug_wp40_r6_worker_rows_v1" or
				type(result.rows) ~= "table" then
			fail("seed-range result schema differs")
		end
		local records = {}
		if #result.rows > codec.MAX_DATA_ROWS then fail("worker row bound exceeded") end
		for index = 1, #result.rows do
			records[index] = structured_row(result.rows[index], index)
		end
		for key in pairs(result.rows) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
					key > #result.rows then
				fail("seed-range rows are not dense")
			end
		end
		table.sort(records, function(left, right)
			return codec.compare(left.fields, right.fields)
		end)
		for index = 2, #records do
			if codec.same_key(records[index - 1].fields, records[index].fields) then
				fail("seed-range result contains a duplicate artifact key")
			end
		end
		local file = assert(io.open(path, "wb"), "cannot create " .. path)
		local byte_count = #codec.header_bytes()
		assert(file:write(codec.header_bytes()))
		for index = 1, #records do
			byte_count = byte_count + #records[index].bytes
			if byte_count > codec.MAX_FILE_BYTES then fail("worker fragment byte bound exceeded") end
			assert(file:write(records[index].bytes))
		end
		assert(file:close())
		local digest, measured_bytes = require_sha256().file(path)
		if measured_bytes ~= byte_count then fail("worker fragment byte count differs") end
		return {sha256 = digest, bytes = byte_count, rows = #records}
	end

	function module.run_seed_range(spec, output_path)
		exact_fields(spec, {mode = true, worker_id = true, scratch = true,
			slot_first = true, slot_last = true, assignment_sha256 = true,
			projection_sha256 = true, projection_path = true},
			"seed-range spec")
		if spec.mode ~= "fleet" then fail("seed-range mode differs") end
		integer(spec.worker_id, 1, 7, "worker ID")
		integer(spec.slot_first, 1, 32, "first seed slot")
		integer(spec.slot_last, spec.slot_first, 32, "last seed slot")
		digest_text(spec.assignment_sha256, "assignment token")
		digest_text(spec.projection_sha256, "approved projection digest")
		if type(spec.projection_path) ~= "string" or spec.projection_path == "" then
			fail("approved projection path is missing")
		end
		local projection_digest = require_sha256().file(spec.projection_path)
		if projection_digest ~= spec.projection_sha256 then
			fail("approved projection file digest differs")
		end
		if type(spec.scratch) ~= "string" or spec.scratch == "" then
			fail("worker scratch path is missing")
		end
		local result = evidence_method("run_seed_range")(spec)
		return write_fragment(output_path, result)
	end

	function module.run_pilot_shard(spec, output_path)
		exact_fields(spec, {mode = true, worker_id = true, scratch = true,
			partition_count = true, residue = true, assignment_sha256 = true},
			"pilot-shard spec")
		if spec.mode ~= "pilot_shard" then fail("pilot-shard mode differs") end
		integer(spec.worker_id, 1, 7, "worker ID")
		integer(spec.partition_count, 7, 7, "pilot partition count")
		integer(spec.residue, 0, 6, "pilot residue")
		digest_text(spec.assignment_sha256, "assignment token")
		local result = evidence_method("run_cost_pilot_shard")(spec)
		exact_fields(result, {schema = true, bytes = true}, "pilot-shard result")
		if result.schema ~= "grug_wp40_r6_pilot_shard_v1" then
			fail("pilot-shard result schema differs")
		end
		local byte_count = write_bytes(output_path, result.bytes)
		local digest, measured_bytes = require_sha256().file(output_path)
		if measured_bytes ~= byte_count then fail("pilot-shard byte count differs") end
		return {sha256 = digest, bytes = byte_count, rows = 0}
	end

	function module.run_pilot_reference(spec, output_path)
		exact_fields(spec, {mode = true, worker_id = true, scratch = true,
			assignment_sha256 = true},
			"pilot-reference spec")
		if spec.mode ~= "pilot_reference" or spec.worker_id ~= 1 then
			fail("pilot-reference identity differs")
		end
		digest_text(spec.assignment_sha256, "assignment token")
		local result = evidence_method("run_cost_pilot_reference")(spec)
		exact_fields(result, {schema = true, bytes = true}, "pilot-reference result")
		if result.schema ~= "grug_wp40_r6_pilot_reference_v1" then
			fail("pilot-reference result schema differs")
		end
		local byte_count = write_bytes(output_path, result.bytes)
		local digest, measured_bytes = require_sha256().file(output_path)
		if measured_bytes ~= byte_count then fail("pilot-reference byte count differs") end
		return {sha256 = digest, bytes = byte_count, rows = 0}
	end

	function module.combine_pilot(spec, shard_descriptors, reference_descriptor,
			output_path)
		exact_fields(spec, {mode = true, scratch = true, assignment_sha256 = true},
			"pilot-combine spec")
		if spec.mode ~= "pilot_combine" then fail("pilot-combine mode differs") end
		digest_text(spec.assignment_sha256, "assignment token")
		if type(shard_descriptors) ~= "table" or #shard_descriptors ~= 7 or
				type(reference_descriptor) ~= "table" then
			fail("pilot descriptor population differs")
		end
		verify_descriptors(shard_descriptors, 7, "pilot shard")
		verify_descriptors({reference_descriptor}, 1, "pilot reference")
		local result = evidence_method("combine_cost_pilot")(
			spec, shard_descriptors, reference_descriptor)
		exact_fields(result, {schema = true, bytes = true, sharded_digest = true,
			reference_digest = true}, "pilot-combine result")
		if result.schema ~= "grug_wp40_r6_pilot_combine_v1" or
				result.sharded_digest ~= result.reference_digest then
			fail("pilot sharded/reference digest parity differs")
		end
		local byte_count = write_bytes(output_path, result.bytes)
		local digest, measured_bytes = require_sha256().file(output_path)
		if measured_bytes ~= byte_count then fail("pilot report byte count differs") end
		return {sha256 = digest, bytes = byte_count, rows = 0,
			population_sha256 = result.sharded_digest}
	end

	function module.finalize_global(spec, worker_descriptors, micro_descriptors,
			production_descriptor, output_path)
		exact_fields(spec, {mode = true, scratch = true,
			assignment_sha256 = true, projection_sha256 = true,
			projection_path = true}, "global-finalizer spec")
		if spec.mode ~= "global_finalize" then fail("global-finalizer mode differs") end
		digest_text(spec.assignment_sha256, "assignment token")
		digest_text(spec.projection_sha256, "approved projection digest")
		verify_descriptors(worker_descriptors, 7, "seed worker")
		verify_descriptors(micro_descriptors, 2, "micro-KAT")
		verify_descriptors({production_descriptor}, 1, "production KAT")
		if micro_descriptors[1].engine_id ~= "luajit" or
				micro_descriptors[2].engine_id ~= "puc51" then
			fail("micro-KAT descriptor engine order differs")
		end
		if micro_descriptors[1].sha256 ~= micro_descriptors[2].sha256 then
			fail("LuaJIT/PUC micro-KAT byte digest differs")
		end
		local projection_digest = require_sha256().file(spec.projection_path)
		if projection_digest ~= spec.projection_sha256 then
			fail("approved projection file digest differs")
		end
		local result = evidence_method("finalize_global_fragment")(
			spec, worker_descriptors, micro_descriptors, production_descriptor)
		return write_fragment(output_path, result)
	end

	function module.run_micro(spec, output_path)
		exact_fields(spec, {mode = true, scratch = true, engine_id = true,
			assignment_sha256 = true},
			"micro-KAT spec")
		if spec.mode ~= "micro" or
				(spec.engine_id ~= "luajit" and spec.engine_id ~= "puc51") then
			fail("micro-KAT identity differs")
		end
		digest_text(spec.assignment_sha256, "assignment token")
		local result = evidence_method("run_micro_kat")(spec)
		exact_fields(result, {schema = true, bytes = true}, "micro-KAT result")
		if result.schema ~= "grug_wp40_r6_micro_kat_v2" then
			fail("micro-KAT result schema differs")
		end
		return {bytes = write_bytes(output_path, result.bytes), rows = 0}
	end

	return module
end
