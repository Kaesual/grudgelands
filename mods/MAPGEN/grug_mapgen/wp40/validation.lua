-- Generic Stage 1/2/3 validation and the sole IPC transport seam.

local validation = {}
local published = {}
local consumed = {}

local function diagnostic(stage, invariant, expected, observed, context)
	context = context or {}
	return {
		stage = stage,
		schema = context.schema,
		seed_hash = context.seed_hash,
		record_id = context.record_id,
		invariant = invariant,
		expected = expected,
		observed = observed,
	}
end

local function display(value)
	if value == nil then return "<nil>" end
	return tostring(value)
end

local function dense_count(values, label)
	if type(values) ~= "table" then
		error("WP40 " .. label .. " is not an array", 0)
	end
	local count = #values
	for i = 1, count do
		if values[i] == nil then error("WP40 " .. label .. " has a hole", 0) end
	end
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			error("WP40 " .. label .. " is not a dense array", 0)
		end
	end
	return count
end

function validation.format(diag)
	return ("WP40 validation %s failed: schema=%s seed_hash=%s " ..
		"record=%s invariant=%s expected=%s observed=%s"):format(
		display(diag.stage), display(diag.schema), display(diag.seed_hash),
		display(diag.record_id), display(diag.invariant),
		display(diag.expected), display(diag.observed))
end

function validation.fail(stage, invariant, expected, observed, context)
	return nil, diagnostic(stage, invariant, expected, observed, context)
end

function validation.assert_valid(ok, diag)
	if not ok then error(validation.format(diag), 0) end
	return true
end

-- Validators return true, or nil plus a structured diagnostic. A thrown error
-- is converted into a diagnostic and stops the stage immediately.
function validation.run(stage, validators, context)
	if type(validators) ~= "table" then
		return validation.fail(stage, "validator_list", "table",
			type(validators), context)
	end
	local dense_ok, count = pcall(dense_count, validators, "validator list")
	if not dense_ok then
		return validation.fail(stage, "validator_list", "dense array", count,
			context)
	end
	for i = 1, count do
		if type(validators[i]) ~= "function" then
			return validation.fail(stage, "validator_" .. i, "function",
				type(validators[i]), context)
		end
		local ok, accepted, diag = pcall(validators[i], context)
		if not ok then
			return validation.fail(stage, "validator_exception", "success",
				accepted, context)
		end
		if not accepted then
			if type(diag) == "table" then
				diag.stage = diag.stage or stage
				diag.schema = diag.schema or (context or {}).schema
				diag.seed_hash = diag.seed_hash or (context or {}).seed_hash
				return nil, diag
			end
			return validation.fail(stage, "validator_" .. i, true, accepted,
				context)
		end
	end
	return true
end

local function copy_graph(value, seen)
	local kind = type(value)
	if kind == "function" or kind == "userdata" or kind == "thread" then
		error("WP40 transport graph contains " .. kind, 0)
	end
	if kind ~= "table" then return value end
	if getmetatable(value) ~= nil then
		error("WP40 transport graph contains a metatable", 0)
	end
	seen = seen or {}
	if seen[value] then error("WP40 transport graph contains a cycle", 0) end
	seen[value] = true
	local result = {}
	for key, child in pairs(value) do
		local key_kind = type(key)
		if key_kind ~= "string" and key_kind ~= "number" and
				key_kind ~= "boolean" then
			error("WP40 transport graph contains unsupported key type " .. key_kind, 0)
		end
		result[key] = copy_graph(child, seen)
	end
	seen[value] = nil
	return result
end

local function equal(a, b, seen)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	seen = seen or {}
	if seen[a] then return seen[a] == b end
	seen[a] = b
	for key, value in pairs(a) do
		if not equal(value, b[key], seen) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

local function sorted_unique_text(values, label)
	local result = {}
	values = values or {}
	local count = dense_count(values, label)
	for i = 1, count do
		if type(values[i]) ~= "string" or values[i] == "" then
			error("WP40 " .. label .. " contains invalid text", 0)
		end
		result[i] = values[i]
	end
	table.sort(result)
	for i = 2, #result do
		if result[i - 1] == result[i] then
			error("WP40 " .. label .. " contains duplicate " .. result[i], 0)
		end
	end
	return result
end

function validation.prepare(options)
	if type(options) ~= "table" then
		validation.assert_valid(validation.fail("stage1", "options", "table",
			type(options), {}))
	end
	local context = {
		schema = options.geometry_schema,
		seed_hash = options.seed_hash,
	}
	local schema_fields = {"transport_schema", "algorithm_schema",
		"geometry_schema", "seed_hash"}
	for i = 1, #schema_fields do
		local field = schema_fields[i]
		if type(options[field]) ~= "string" or options[field] == "" then
			validation.assert_valid(validation.fail("stage1", field,
				"non-empty text", options[field], context))
		end
	end
	if type(options.record_counts) ~= "table" or
			type(options.critical_manifest) ~= "table" then
		validation.assert_valid(validation.fail("stage1", "manifest_shape",
			"record_counts and critical_manifest tables", "missing", context))
	end
	for id, count in pairs(options.record_counts) do
		if type(id) ~= "string" or id == "" or type(count) ~= "number" or
				count % 1 ~= 0 or count < 0 or count > 4294967295 then
			validation.assert_valid(validation.fail("stage1", "record_count",
				"named u32", tostring(id) .. "=" .. tostring(count), context))
		end
	end
	validation.assert_valid(validation.run("stage1", options.stage1_validators,
		options.stage1_context or context))
	local canonical = options.canonical
	if type(options.canonicalize_compiled) ~= "function" then
		validation.assert_valid(validation.fail("stage1",
			"compiled_canonicalizer", "function",
			type(options.canonicalize_compiled), context))
	end
	local source_checksum = canonical.hex(canonical.checksum(
		options.source_canonical, options.raw_sha256))
	local semantic_ids = sorted_unique_text(options.semantic_ids, "semantic IDs")
	if #semantic_ids > 0 and type(options.registration_resolver) ~= "function" then
		validation.assert_valid(validation.fail("stage1", "semantic_resolver",
			"function", type(options.registration_resolver), context))
	end
	for i = 1, #semantic_ids do
		local id = semantic_ids[i]
		local resolved, reason = options.registration_resolver(id)
		if not resolved then
			context.record_id = id
			validation.assert_valid(validation.fail("stage1",
				"semantic_registration", "resolved", reason or "missing", context))
		end
	end
	validation.assert_valid(validation.run("stage2", options.stage2_validators,
		options.stage2_context or context))
	local private_data = copy_graph(options.data or {})
	local canonical_ok, compiled_canonical = pcall(
		options.canonicalize_compiled, private_data, semantic_ids, canonical)
	if not canonical_ok then
		validation.assert_valid(validation.fail("stage2",
			"compiled_canonicalizer", "valid canonical graph",
			compiled_canonical, context))
	end
	local compiled_checksum = canonical.hex(canonical.checksum(
		compiled_canonical, options.raw_sha256))
	local payload = {
		transport_schema = options.transport_schema,
		algorithm_schema = options.algorithm_schema,
		geometry_schema = options.geometry_schema,
		seed_hash = options.seed_hash,
		source_checksum = source_checksum,
		compiled_checksum = compiled_checksum,
		source_canonical = options.source_canonical,
		record_counts = copy_graph(options.record_counts or {}),
		critical_manifest = copy_graph(options.critical_manifest or {}),
		semantic_ids = semantic_ids,
		data = private_data,
	}
	return copy_graph(payload)
end

local function stage3_check(payload, expected, canonical, raw_sha256, resolver,
		canonicalize_compiled)
	local context = {
		schema = payload and payload.geometry_schema,
		seed_hash = payload and payload.seed_hash,
	}
	local function check(invariant, wanted, actual)
		if not equal(wanted, actual) then
			return validation.fail("stage3", invariant, wanted, actual, context)
		end
		return true
	end
	if type(payload) ~= "table" then
		return validation.fail("stage3", "payload", "table", type(payload), context)
	end
	local graph_ok, graph_error = pcall(copy_graph, payload)
	if not graph_ok then
		return validation.fail("stage3", "immutable_transport_graph", "valid",
			graph_error, context)
	end
	local fields = {"transport_schema", "algorithm_schema", "geometry_schema",
		"seed_hash", "source_checksum", "compiled_checksum", "record_counts",
		"critical_manifest"}
	for i = 1, #fields do
		local field = fields[i]
		local ok, diag = check(field, expected[field], payload[field])
		if not ok then return nil, diag end
	end
	local checksum_ok, source_checksum = pcall(function()
		return canonical.hex(canonical.checksum(payload.source_canonical,
			raw_sha256))
	end)
	if not checksum_ok then
		return validation.fail("stage3", "source_canonical", "valid",
			source_checksum, context)
	end
	local ok, diag = check("source_checksum", payload.source_checksum,
		source_checksum)
	if not ok then return nil, diag end
	if type(canonicalize_compiled) ~= "function" then
		return validation.fail("stage3", "compiled_canonicalizer", "function",
			type(canonicalize_compiled), context)
	end
	local semantic_ok, semantic_count = pcall(dense_count,
		payload.semantic_ids or {}, "semantic IDs")
	if not semantic_ok then
		return validation.fail("stage3", "semantic_ids", "dense array",
			semantic_count, context)
	end
	local compiled_checksum
	checksum_ok, compiled_checksum = pcall(function()
		local rebuilt = canonicalize_compiled(payload.data, payload.semantic_ids,
			canonical)
		return canonical.hex(canonical.checksum(rebuilt, raw_sha256))
	end)
	if not checksum_ok then
		return validation.fail("stage3", "compiled_canonicalizer", "valid",
			compiled_checksum, context)
	end
	ok, diag = check("compiled_checksum", payload.compiled_checksum,
		compiled_checksum)
	if not ok then return nil, diag end
	if type(resolver) ~= "function" then
		return validation.fail("stage3", "semantic_resolver", "function",
			type(resolver), context)
	end
	local previous_id
	for i = 1, semantic_count do
		local id = payload.semantic_ids[i]
		if type(id) ~= "string" or id == "" or
				(previous_id and previous_id >= id) then
			return validation.fail("stage3", "semantic_id_order",
				"sorted unique text", id, context)
		end
		previous_id = id
		local resolved, reason = resolver(id)
		if not resolved then
			context.record_id = id
			return validation.fail("stage3", "semantic_registration",
				"resolved", reason or "missing", context)
		end
	end
	return true
end

-- The only production IPC write/read functions. Callers retain the returned
-- private graph and never use IPC from a query or callback.
function validation.publish(core_api, key, payload)
	if type(core_api) ~= "table" or type(core_api.ipc_set) ~= "function" then
		error("WP40 IPC publish API unavailable", 0)
	end
	if type(key) ~= "string" or key == "" then error("WP40 IPC key invalid", 0) end
	published[core_api] = published[core_api] or {}
	if published[core_api][key] then error("WP40 IPC key already published", 0) end
	core_api.ipc_set(key, copy_graph(payload))
	published[core_api][key] = true
	return true
end

function validation.consume(core_api, key, expected, canonical, raw_sha256,
		resolver, canonicalize_compiled)
	if type(core_api) ~= "table" or type(core_api.ipc_get) ~= "function" then
		error("WP40 IPC consume API unavailable", 0)
	end
	if type(key) ~= "string" or key == "" then error("WP40 IPC key invalid", 0) end
	consumed[core_api] = consumed[core_api] or {}
	if consumed[core_api][key] then error("WP40 IPC key already consumed", 0) end
	local payload = core_api.ipc_get(key)
	consumed[core_api][key] = true
	local ok, diag = stage3_check(payload, expected, canonical, raw_sha256,
		resolver, canonicalize_compiled)
	validation.assert_valid(ok, diag)
	return copy_graph(payload)
end

function validation.consume_and_enable(core_api, key, expected, canonical,
		raw_sha256, resolver, canonicalize_compiled, register_callback)
	local payload = validation.consume(core_api, key, expected, canonical,
		raw_sha256, resolver, canonicalize_compiled)
	if type(register_callback) ~= "function" then
		error("WP40 generated callback registrar missing", 0)
	end
	register_callback(payload)
	return payload
end

validation.copy_graph = copy_graph
validation.equal = equal

return validation
