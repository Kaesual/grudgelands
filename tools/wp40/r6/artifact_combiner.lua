-- Streaming validator and deterministic k-way combiner for R6 ledger fragments.

return function(codec, sha256)
	if type(codec) ~= "table" or type(codec.parse_data_line) ~= "function" or
			type(sha256) ~= "table" or type(sha256.new) ~= "function" or
			type(sha256.file) ~= "function" then
		error("WP40 R6 artifact combiner dependencies differ", 0)
	end
	local module = {}

	local function fail(message)
		error("WP40 R6 fail_ledger: " .. message, 0)
	end

	local function checked_reader(path, label)
		local file = assert(io.open(path, "rb"), "cannot open " .. path)
		local size = assert(file:seek("end"))
		if size < 1 then fail(label .. " is empty") end
		assert(file:seek("set", size - 1))
		if file:read(1) ~= "\n" then fail(label .. " lacks final LF") end
		assert(file:seek("set", 0))
		return file, size
	end

	local function read_header(file, label)
		local header = file:read("*l")
		if header ~= codec.header_line() then fail(label .. " header differs") end
	end

	local function read_fragment_record(state)
		while true do
			local line = state.file:read("*l")
			if line == nil then
				if not state.finished then
					local digest = state.hasher.final_hex()
					if digest ~= state.expected_sha256 then
						fail(state.label .. " changed while being combined")
					end
					state.finished = true
				end
				state.record = nil
				return
			end
			local fields = codec.parse_data_line(line,
				state.label .. " row " .. tostring(state.row_number + 1))
			if state.previous and not codec.compare(state.previous, fields) then
				if codec.same_key(state.previous, fields) then
					fail(state.label .. " contains a duplicate key tuple")
				end
				fail(state.label .. " is not canonically sorted")
			end
			state.row_number = state.row_number + 1
			state.previous = fields
			state.hasher.update(line .. "\n")
			local private_worker_row = fields[1] == "access" or
				(fields[1] == "vm_metric" and fields[2] == "worker_apex")
			if not (state.skip_access and private_worker_row) then
				state.record = {line = line, fields = fields}
				return
			end
		end
	end

	local function observe_record(inventory, previous, record)
		if previous then
			if codec.same_key(previous, record.fields) then
				fail("fragment merge produced a duplicate key tuple")
			elseif not codec.compare(previous, record.fields) then
				fail("fragment merge order differs")
			end
		end
	codec.observe(inventory, record.fields)
		return record.fields
	end

	local function validate_descriptor(descriptor, index, output_path)
		if type(descriptor) ~= "table" or type(descriptor.path) ~= "string" or
				descriptor.path == "" or type(descriptor.sha256) ~= "string" or
				#descriptor.sha256 ~= 64 or
				not descriptor.sha256:match("^[0-9a-f]+$") then
			fail("fragment descriptor " .. tostring(index) .. " differs")
		end
		if descriptor.path == output_path then fail("output path aliases an input fragment") end
	end

	function module.combine(descriptors, output_path)
		if type(descriptors) ~= "table" or #descriptors < 1 then
			fail("fragment descriptor array is empty")
		end
		if type(output_path) ~= "string" or output_path == "" then
			fail("combined output path is missing")
		end
		local states, seen_paths = {}, {}
		for index = 1, #descriptors do
			local descriptor = descriptors[index]
			validate_descriptor(descriptor, index, output_path)
			if seen_paths[descriptor.path] then fail("duplicate fragment path") end
			seen_paths[descriptor.path] = true
			local actual_sha256 = sha256.file(descriptor.path)
			if actual_sha256 ~= descriptor.sha256 then
				fail("fragment SHA-256 differs: " .. descriptor.path)
			end
			local file = checked_reader(descriptor.path, "fragment " .. tostring(index))
			read_header(file, "fragment " .. tostring(index))
			local fragment_hasher = sha256.new()
			fragment_hasher.update(codec.header_bytes())
			states[index] = {file = file, label = "fragment " .. tostring(index),
				row_number = 0, hasher = fragment_hasher,
				expected_sha256 = descriptor.sha256, finished = false,
				skip_access = descriptor.skip_access == true}
			read_fragment_record(states[index])
		end

		local output = assert(io.open(output_path, "wb"),
			"cannot create " .. output_path)
		local body_hasher = sha256.new()
		local header = codec.header_bytes()
		assert(output:write(header))
		body_hasher.update(header)
		local byte_count = #header
		local inventory = codec.new_inventory()
		local previous

		while true do
			local selected
			for index = 1, #states do
				if states[index].record and (not selected or
						codec.compare(states[index].record.fields,
							states[selected].record.fields)) then
					selected = index
				end
			end
			if not selected then break end
			local record = states[selected].record
			previous = observe_record(inventory, previous, record)
			local bytes = record.line .. "\n"
			byte_count = byte_count + #bytes
			if byte_count > codec.MAX_FILE_BYTES then fail("artifact byte bound exceeded") end
			assert(output:write(bytes))
			body_hasher.update(bytes)
			read_fragment_record(states[selected])
		end

		for index = 1, #states do assert(states[index].file:close()) end
		codec.validate_complete(inventory)
		local body_digest = body_hasher.final_hex()
		local trailer = codec.trailer_line(body_digest)
		byte_count = byte_count + #trailer
		if byte_count > codec.MAX_FILE_BYTES then fail("artifact byte bound exceeded") end
		assert(output:write(trailer))
		assert(output:close())
		local file_digest, measured_bytes = sha256.file(output_path)
		if measured_bytes ~= byte_count then fail("combined artifact byte count differs") end
		return {body_sha256 = body_digest, file_sha256 = file_digest,
			data_rows = inventory.data_rows, bytes = byte_count}
	end

	function module.validate(path, expected_file_sha256)
		local file, byte_count = checked_reader(path, "artifact")
		if byte_count > codec.MAX_FILE_BYTES then fail("artifact byte bound exceeded") end
		read_header(file, "artifact")
		local body_hasher = sha256.new()
		body_hasher.update(codec.header_bytes())
		local inventory = codec.new_inventory()
		local previous
		local current = file:read("*l")
		if current == nil then fail("artifact trailer is absent") end
		while true do
			local following = file:read("*l")
			if following == nil then break end
			local fields = codec.parse_data_line(current,
				"artifact row " .. tostring(inventory.data_rows + 1))
			local record = {line = current, fields = fields}
			previous = observe_record(inventory, previous, record)
			body_hasher.update(current .. "\n")
			current = following
		end
		local embedded_digest = codec.parse_trailer_line(current)
		assert(file:close())
		codec.validate_complete(inventory)
		local body_digest = body_hasher.final_hex()
		if body_digest ~= embedded_digest then fail("artifact body SHA-256 differs") end
		local file_digest, measured_bytes = sha256.file(path)
		if measured_bytes ~= byte_count then fail("artifact byte count changed while validating") end
		if expected_file_sha256 and expected_file_sha256 ~= "" and
				file_digest ~= expected_file_sha256 then
			fail("artifact complete-file SHA-256 differs")
		end
		return {body_sha256 = body_digest, file_sha256 = file_digest,
			data_rows = inventory.data_rows, bytes = byte_count}
	end

	return module
end
