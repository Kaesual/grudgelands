-- Test/tool-only T2c-E0-C1 conformance authority.  It validates the retained
-- measurement and merge bytes, independently replays the four sequential
-- rankings, and defines the closed 20-row PUC rescore roster.  Geometry is
-- loaded separately from the pinned measurement commit.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = assert(dependencies.raw_sha256)
	local extreme = assert(dependencies.extreme)
	local rational_compare = assert(dependencies.rational_compare)
	local decimal_less = assert(dependencies.decimal_less)

	local conformance = {}
	local function fail(message)
		error("WP40 T2 extreme conformance: " .. message, 0)
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end
	local function digest(bytes) return hex(raw_sha256(bytes)) end
	local function exact_fields(value, names, context)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(context .. " is not a plain table")
		end
		local allowed, count = {}, 0
		for index = 1, #names do allowed[names[index]] = true end
		for key in pairs(value) do
			if not allowed[key] then fail(context .. " has an unknown field") end
			count = count + 1
		end
		if count ~= #names then fail(context .. " has a missing field") end
	end
	local function dense(rows, context)
		if type(rows) ~= "table" or getmetatable(rows) ~= nil then
			fail(context .. " is not a plain array")
		end
		local count = 0
		for key in pairs(rows) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				fail(context .. " is not dense")
			end
			if key > count then count = key end
		end
		for index = 1, count do
			if rows[index] == nil then fail(context .. " is not dense") end
		end
		return count
	end
	local function sha(value, context)
		if type(value) ~= "string" or #value ~= 64 or
				not value:match("^[0-9a-f]+$") then
			fail(context .. " is not lowercase SHA-256")
		end
		return value
	end
	local function commit(value, context)
		if type(value) ~= "string" or #value ~= 40 or
				not value:match("^[0-9a-f]+$") then
			fail(context .. " is not a commit/tree id")
		end
		return value
	end
	local launch_pin_fields = {"commit", "tree", "dag"}
	local function validate_launch_pins(pins)
		exact_fields(pins, launch_pin_fields, "conformance launch pins")
		commit(pins.commit, "conformance launch commit")
		commit(pins.tree, "conformance launch tree")
		sha(pins.dag, "conformance launch DAG")
		return pins
	end
	local function assert_launch_pins(row, pins, context)
		validate_launch_pins(pins)
		if type(row) ~= "table" or
				row.conformance_commit ~= pins.commit or
				row.conformance_tree ~= pins.tree or
				row.conformance_dag_sha256 ~= pins.dag then
			fail((context or "conformance result") .. " launch pins changed")
		end
		return row
	end
	local function integer(value, minimum, maximum, context)
		if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or
				value > maximum then fail(context .. " is not an exact integer") end
		return value
	end
	local function split_tabs(line)
		local fields, start = {}, 1
		while true do
			local position = line:find("\t", start, true)
			if not position then fields[#fields + 1] = line:sub(start); break end
			fields[#fields + 1] = line:sub(start, position - 1)
			start = position + 1
		end
		return fields
	end
	local function lines(blob, context)
		if type(blob) ~= "string" or blob == "" or blob:sub(-1) ~= "\n" or
				blob:find("\r", 1, true) or blob:find(string.char(0), 1, true) then
			fail(context .. " framing changed")
		end
		local result = {}
		for line in blob:gmatch("([^\n]*)\n") do
			if line == "" then fail(context .. " has an empty line") end
			result[#result + 1] = line
		end
		return result
	end

	local gate_fields = {"schema", "status", "measurement_commit",
		"measurement_tree", "authority_dag_sha256", "source_checksum",
		"boundary_policy_checksum", "partition_sha256", "artifact_sha256",
		"manifest_sha256", "candidate_rows_sha256", "shards", "winners",
		"staging"}
	local function validate_gate(gate)
		exact_fields(gate, gate_fields, "conformance gate")
		if gate.schema ~= "grug_wp40_extreme_conformance_gate_v1" or
				gate.status ~= "pending_selected_four_conformance" then
			fail("conformance gate schema/status changed")
		end
		commit(gate.measurement_commit, "measurement commit")
		commit(gate.measurement_tree, "measurement tree")
		for _, field in ipairs({"authority_dag_sha256", "source_checksum",
				"boundary_policy_checksum", "partition_sha256", "artifact_sha256",
				"manifest_sha256", "candidate_rows_sha256"}) do
			sha(gate[field], "conformance gate " .. field)
		end
		if dense(gate.shards, "conformance gate shards") ~= 8 then
			fail("conformance gate does not have eight shards")
		end
		for index = 1, 8 do
			local row = gate.shards[index]
			exact_fields(row, {"first", "last", "sha256"}, "conformance shard")
			local first = (index - 1) * 512
			if integer(row.first, 0, 4095, "shard first") ~= first or
					integer(row.last, 0, 4095, "shard last") ~= first + 511 then
				fail("conformance shard range changed")
			end
			sha(row.sha256, "conformance shard digest")
		end
		if dense(gate.winners, "conformance winners") ~= 4 then
			fail("conformance gate does not have four winners")
		end
		local ids = {"greatest_coast", "least_coast", "greatest_noncoast",
			"least_noncoast"}
		local decimal_seen, index_seen = {}, {}
		for index = 1, 4 do
			local row = gate.winners[index]
			exact_fields(row, {"slot", "id", "candidate_index", "decimal",
				"score_n", "score_d"}, "conformance winner")
			if row.slot ~= 27 + index or row.id ~= ids[index] then
				fail("conformance winner order changed")
			end
			integer(row.candidate_index, 0, 4095, "winner candidate")
			integer(row.score_n, -9007199254740991, 9007199254740991,
				"winner numerator")
			integer(row.score_d, 1, 9007199254740991, "winner denominator")
			if type(row.decimal) ~= "string" or not row.decimal:match("^[0-9]+$") or
					decimal_seen[row.decimal] or index_seen[row.candidate_index] then
				fail("conformance winner identity changed")
			end
			decimal_seen[row.decimal], index_seen[row.candidate_index] = true, true
		end
		exact_fields(gate.staging, {"label", "decimal"}, "conformance staging")
		if type(gate.staging.label) ~= "string" or
				not gate.staging.label:match("^grudgelands%-wp40%-seed%-%d%d$") or
				type(gate.staging.decimal) ~= "string" or
				not gate.staging.decimal:match("^[0-9]+$") then
			fail("conformance staging identity changed")
		end
		return gate
	end

	local artifact_headers = {"schema", "measurement_scope", "stage2_status",
		"source_checksum", "boundary_policy_checksum", "partition_sha256",
		"authority_dag_sha256", "authority_commit", "authority_tree",
		"interpreter_id", "interpreter_launcher", "interpreter_path",
		"interpreter_version", "interpreter_sha256", "scorer_schema",
		"candidate_rows_sha256", "merge_interpreter_id",
		"merge_interpreter_path", "merge_interpreter_version",
		"merge_interpreter_sha256"}
	local candidate_header = "candidate_index\tstatus\tlabel\tdigest\tfirst8\t" ..
		"decimal\tcoast_n\tcoast_d\tcoast_count\tcoast_sequence_sha256\t" ..
		"coast_identity_sha256\tnoncoast_n\tnoncoast_d\tnoncoast_count\t" ..
		"noncoast_sequence_sha256\tnoncoast_identity_sha256"
	local function parse_artifact(blob, gate)
		validate_gate(gate)
		if digest(blob) ~= gate.artifact_sha256 then
			fail("measurement artifact digest changed")
		end
		local source_lines = lines(blob, "measurement artifact")
		if #source_lines ~= #artifact_headers + 1 + 4096 then
			fail("measurement artifact line count changed")
		end
		local values = {}
		for index = 1, #artifact_headers do
			local fields = split_tabs(source_lines[index])
			if #fields ~= 2 or fields[1] ~= artifact_headers[index] then
				fail("measurement artifact header order changed")
			end
			values[fields[1]] = fields[2]
		end
		if source_lines[#artifact_headers + 1] ~= candidate_header then
			fail("measurement artifact candidate header changed")
		end
		if values.schema ~= "grug_wp40_extreme_measurement_artifact_v2" or
				values.measurement_scope ~= "R7_SCALAR_MEASUREMENT_ONLY" or
				values.stage2_status ~= "pending_selected_four" or
				values.interpreter_id ~= "luajit" or
				values.scorer_schema ~= "grug_wp40_extreme_selector_e0_v1" or
				values.merge_interpreter_id ~= "puc_lua51" then
			fail("measurement artifact authority fields changed")
		end
		local gate_map = {source_checksum = "source_checksum",
			boundary_policy_checksum = "boundary_policy_checksum",
			partition_sha256 = "partition_sha256",
			authority_dag_sha256 = "authority_dag_sha256",
			authority_commit = "measurement_commit",
			authority_tree = "measurement_tree",
			candidate_rows_sha256 = "candidate_rows_sha256"}
		for artifact_field, gate_field in pairs(gate_map) do
			if values[artifact_field] ~= gate[gate_field] then
				fail("measurement artifact pin changed")
			end
		end
		local candidate_lines = {}
		for index = #artifact_headers + 1, #source_lines do
			candidate_lines[#candidate_lines + 1] = source_lines[index]
		end
		local candidate_blob = table.concat(candidate_lines, "\n") .. "\n"
		if digest(candidate_blob) ~= gate.candidate_rows_sha256 then
			fail("measurement candidate rows digest changed")
		end
		local row_lines = {}
		for index = #artifact_headers + 2, #source_lines do
			row_lines[#row_lines + 1] = source_lines[index]
		end
		local row_digest = digest(table.concat(row_lines, "\n") .. "\n")
		local fake = table.concat({
			"schema\tgrug_wp40_extreme_candidate_shard_v2",
			"range\t0\t4095\t4096",
			"source_checksum\t" .. values.source_checksum,
			"boundary_policy_checksum\t" .. values.boundary_policy_checksum,
			"partition_sha256\t" .. values.partition_sha256,
			"authority_dag_sha256\t" .. values.authority_dag_sha256,
			"authority_commit\t" .. values.authority_commit,
			"authority_tree\t" .. values.authority_tree,
			"interpreter_id\t" .. values.interpreter_id,
			"interpreter_launcher\t" .. values.interpreter_launcher,
			"interpreter_path\t" .. values.interpreter_path,
			"interpreter_version\t" .. values.interpreter_version,
			"interpreter_sha256\t" .. values.interpreter_sha256,
			"measurement_scope\t" .. values.measurement_scope,
			"stage2_status\t" .. values.stage2_status,
			"scorer_schema\t" .. values.scorer_schema,
			"rows_sha256\t" .. row_digest,
			candidate_blob,
		}, "\n")
		-- The retained merged artifact is pre-v3 (v2) historical evidence: read it
		-- with the explicit historical reader, never with the current v3 parser.
		local shard = extreme.parse_historical_shard_blob(fake)
		if extreme.candidate_blob(shard.rows) ~= candidate_blob then
			fail("measurement candidate rows are not canonical bytes")
		end
		local raw_by_index = {}
		for index = 0, 4095 do
			raw_by_index[index] = source_lines[#artifact_headers + 2 + index]
		end
		return {headers = values, rows = shard.rows,
			rows_by_index = (function()
				local result = {}
				for index = 1, #shard.rows do
					result[shard.rows[index].candidate_index] = shard.rows[index]
				end
				return result
			end)(), raw_by_index = raw_by_index, candidate_blob = candidate_blob}
	end

	local manifest_headers = {"measurement_scope", "stage2_status",
		"source_checksum", "boundary_policy_checksum", "partition_sha256",
		"authority_dag_sha256", "authority_commit", "authority_tree",
		"interpreter_id", "interpreter_launcher", "interpreter_path",
		"interpreter_version", "interpreter_sha256", "scorer_schema",
		"merge_interpreter_id", "merge_interpreter_path",
		"merge_interpreter_version", "merge_interpreter_sha256"}
	local function parse_manifest(blob, gate)
		validate_gate(gate)
		if digest(blob) ~= gate.manifest_sha256 then
			fail("measurement manifest digest changed")
		end
		local source_lines = lines(blob, "measurement manifest")
		if #source_lines ~= 1 + #manifest_headers + 8 or
				source_lines[1] ~= "grug_wp40_extreme_shard_manifest_v2" then
			fail("measurement manifest line count/schema changed")
		end
		local values = {}
		for index = 1, #manifest_headers do
			local fields = split_tabs(source_lines[index + 1])
			if #fields ~= 2 or fields[1] ~= manifest_headers[index] then
				fail("measurement manifest header order changed")
			end
			values[fields[1]] = fields[2]
		end
		local expected = {measurement_scope = "R7_SCALAR_MEASUREMENT_ONLY",
			stage2_status = "pending_selected_four",
			source_checksum = gate.source_checksum,
			boundary_policy_checksum = gate.boundary_policy_checksum,
			partition_sha256 = gate.partition_sha256,
			authority_dag_sha256 = gate.authority_dag_sha256,
			authority_commit = gate.measurement_commit,
			authority_tree = gate.measurement_tree, interpreter_id = "luajit",
			scorer_schema = "grug_wp40_extreme_selector_e0_v1",
			merge_interpreter_id = "puc_lua51"}
		for field, value in pairs(expected) do
			if values[field] ~= value then fail("measurement manifest pin changed") end
		end
		local shards = {}
		for index = 1, 8 do
			local fields = split_tabs(source_lines[1 + #manifest_headers + index])
			local expected_shard = gate.shards[index]
			local path = ("tools/wp40/fixtures/t2_extreme_e0/" ..
				"shard-luajit-%04d-%04d.tsv"):format(expected_shard.first,
				expected_shard.last)
			if #fields ~= 5 or fields[1] ~= "shard" or
					fields[2] ~= tostring(expected_shard.first) or
					fields[3] ~= tostring(expected_shard.last) or fields[4] ~= path or
					fields[5] ~= expected_shard.sha256 then
				fail("measurement manifest shard roster changed")
			end
			shards[index] = {first = expected_shard.first, last = expected_shard.last,
				path = path, sha256 = expected_shard.sha256}
		end
		return {headers = values, shards = shards}
	end

	local slot_definitions = {
		{id = "greatest_coast", family = "coast", greatest = true},
		{id = "least_coast", family = "coast", greatest = false},
		{id = "greatest_noncoast", family = "noncoast", greatest = true},
		{id = "least_noncoast", family = "noncoast", greatest = false},
	}
	-- Independent sequential rank replay.  It deliberately accepts a small
	-- synthetic roster for tie/skip KATs as well as the validated 4096 rows.
	local function sequential_slots(rows)
		dense(rows, "sequential rank rows")
		local chosen, result = {}, {}
		for slot_index = 1, 4 do
			local definition, best = slot_definitions[slot_index], nil
			local prefix = definition.family == "coast" and "coast_" or "noncoast_"
			for row_index = 1, #rows do
				local row = rows[row_index]
				if row.status == "scored" and not chosen[row.decimal] then
					if not best then
						best = row
					else
						local comparison = rational_compare(row[prefix .. "n"],
							row[prefix .. "d"], best[prefix .. "n"],
							best[prefix .. "d"])
						if (comparison == 0 and decimal_less(row.decimal, best.decimal)) or
								(comparison > 0 and definition.greatest) or
								(comparison < 0 and not definition.greatest) then best = row end
					end
				end
			end
			if not best then fail("sequential extreme slot has no candidate") end
			chosen[best.decimal] = true
			result[slot_index] = {slot = 27 + slot_index, id = definition.id,
				candidate_index = best.candidate_index, decimal = best.decimal,
				score_n = best[prefix .. "n"], score_d = best[prefix .. "d"]}
		end
		return result
	end

	local function selected_and_required(parsed, gate, staging_seed)
		validate_gate(gate)
		local production = extreme.select_slots(parsed.rows)
		local independent = sequential_slots(parsed.rows)
		for index = 1, 4 do
			local expected, actual, replay = gate.winners[index], production[index],
				independent[index]
			for _, field in ipairs({"slot", "id", "candidate_index", "decimal",
					"score_n", "score_d"}) do
				if actual[field] ~= expected[field] or replay[field] ~= expected[field] then
					fail("PUC winner selection changed")
				end
			end
		end
		local staging = staging_seed(production)
		if staging.label ~= gate.staging.label or staging.decimal ~= gate.staging.decimal then
			fail("PUC staging selection changed")
		end
		local selected = {}
		for index = 0, 7 do
			selected[index * 512] = true
			selected[index * 512 + 511] = true
		end
		for index = 1, 4 do selected[gate.winners[index].candidate_index] = true end
		local indices = {}
		for index = 0, 4095 do if selected[index] then indices[#indices + 1] = index end end
		if #indices ~= 20 then fail("PUC rescore union is not exactly 20 candidates") end
		return production, staging, indices
	end

	local rescore_fields = {"schema", "status", "scope", "measurement_commit",
		"measurement_tree", "authority_dag_sha256", "conformance_commit",
		"conformance_tree", "conformance_dag_sha256", "source_checksum",
		"boundary_policy_checksum", "partition_sha256", "artifact_sha256",
		"manifest_sha256", "candidate_rows_sha256", "interpreter_id",
		"interpreter_path", "interpreter_version", "interpreter_sha256",
		"candidate_index", "candidate_decimal", "candidate_role",
		"expected_row_sha256", "rescored_row_sha256"}
	local function validate_rescore_result(row, gate, expected_index,
			expected_row_sha256, conformance_pins, expected_interpreter_path)
		validate_gate(gate)
		exact_fields(row, rescore_fields, "PUC rescore result")
		if row.schema ~= "grug_wp40_extreme_puc_rescore_v1" or
				row.status ~= "passed" or
				row.scope ~= "T2C_E0_PUC_ROW_CONFORMANCE_ONLY" or
				row.interpreter_id ~= "puc_lua51" then
			fail("PUC rescore schema/status changed")
		end
		local gate_map = {measurement_commit = "measurement_commit",
			measurement_tree = "measurement_tree",
			authority_dag_sha256 = "authority_dag_sha256",
			source_checksum = "source_checksum",
			boundary_policy_checksum = "boundary_policy_checksum",
			partition_sha256 = "partition_sha256", artifact_sha256 = "artifact_sha256",
			manifest_sha256 = "manifest_sha256",
			candidate_rows_sha256 = "candidate_rows_sha256"}
		for result_field, gate_field in pairs(gate_map) do
			if row[result_field] ~= gate[gate_field] then
				fail("PUC rescore measurement pin changed")
			end
		end
		if type(conformance_pins) ~= "table" or
				row.conformance_commit ~= conformance_pins.commit or
				row.conformance_tree ~= conformance_pins.tree or
				row.conformance_dag_sha256 ~= conformance_pins.dag then
			fail("PUC rescore conformance pin changed")
		end
		commit(row.conformance_commit, "PUC rescore conformance commit")
		commit(row.conformance_tree, "PUC rescore conformance tree")
		for _, field in ipairs({"conformance_dag_sha256", "interpreter_sha256",
				"expected_row_sha256", "rescored_row_sha256"}) do
			sha(row[field], "PUC rescore " .. field)
		end
		if row.expected_row_sha256 ~= row.rescored_row_sha256 or
				row.expected_row_sha256 ~= expected_row_sha256 or
				row.candidate_index ~= expected_index then
			fail("PUC rescore row bytes changed")
		end
		integer(row.candidate_index, 0, 4095, "PUC rescore candidate")
		if type(row.candidate_decimal) ~= "string" or
				not row.candidate_decimal:match("^[0-9]+$") or
				(row.candidate_role ~= "endpoint" and row.candidate_role ~= "winner") then
			fail("PUC rescore candidate identity changed")
		end
		if type(expected_interpreter_path) ~= "string" or
				row.interpreter_path ~= expected_interpreter_path or
				row.interpreter_version ~=
				"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" then
			fail("PUC rescore interpreter changed")
		end
		return row
	end
	local function result_blob(row, fields, context)
		local result = {}
		for index = 1, #fields do
			local value = row[fields[index]]
			if type(value) ~= "string" and type(value) ~= "number" then
				fail(context .. " value is not scalar")
			end
			local text = tostring(value)
			if text:find("\t", 1, true) or text:find("\n", 1, true) then
				fail(context .. " value framing changed")
			end
			result[index] = fields[index] .. "\t" .. text
		end
		return table.concat(result, "\n") .. "\n"
	end
	local function parse_result_blob(blob, fields, context)
		local source_lines = lines(blob, context)
		if #source_lines ~= #fields then fail(context .. " line count changed") end
		local result = {}
		for index = 1, #fields do
			local pair = split_tabs(source_lines[index])
			if #pair ~= 2 or pair[1] ~= fields[index] then
				fail(context .. " field order changed")
			end
			result[pair[1]] = pair[2]
		end
		result.candidate_index = tonumber(result.candidate_index)
		return result
	end
	local function rescore_result_blob(row)
		return result_blob(row, rescore_fields, "PUC rescore result")
	end
	local function parse_rescore_result(blob)
		local row = parse_result_blob(blob, rescore_fields, "PUC rescore result")
		if rescore_result_blob(row) ~= blob then
			fail("PUC rescore result bytes are not canonical")
		end
		return row
	end
	local selected_fields = {"schema", "status", "scope", "measurement_commit",
		"measurement_tree", "authority_dag_sha256", "conformance_commit",
		"conformance_tree", "conformance_dag_sha256", "source_checksum",
		"boundary_policy_checksum", "partition_sha256", "artifact_sha256",
		"manifest_sha256", "candidate_rows_sha256", "interpreter_id",
		"interpreter_path", "interpreter_version", "interpreter_sha256", "slot",
		"slot_id", "candidate_index", "candidate_decimal", "compiled_sha256",
		"columns", "base_total", "planned_water", "dry", "g", "o", "r", "m",
		"schedule_intervals", "perimeter_aperture", "perimeter_attachment",
		"perimeter_dry", "transition_count", "bank_count", "wing_count",
		"coast_count", "face_count"}
	local function validate_selected_result(row, gate, winner, conformance_pins,
			expected_interpreter_path)
		validate_gate(gate)
		exact_fields(row, selected_fields, "selected partition result")
		if row.schema ~= "grug_wp40_extreme_selected_partition_v1" or
				row.status ~= "passed" or
				row.scope ~= "T2C_E0_SELECTED_FOUR_PARTITION_CONFORMANCE_ONLY" or
				row.interpreter_id ~= "puc_lua51" then
			fail("selected partition schema/status changed")
		end
		local measurement = {measurement_commit = gate.measurement_commit,
			measurement_tree = gate.measurement_tree,
			authority_dag_sha256 = gate.authority_dag_sha256,
			source_checksum = gate.source_checksum,
			boundary_policy_checksum = gate.boundary_policy_checksum,
			partition_sha256 = gate.partition_sha256,
			artifact_sha256 = gate.artifact_sha256,
			manifest_sha256 = gate.manifest_sha256,
			candidate_rows_sha256 = gate.candidate_rows_sha256}
		for field, value in pairs(measurement) do
			if row[field] ~= value then fail("selected partition measurement pin changed") end
		end
		if type(conformance_pins) ~= "table" or
				row.conformance_commit ~= conformance_pins.commit or
				row.conformance_tree ~= conformance_pins.tree or
				row.conformance_dag_sha256 ~= conformance_pins.dag then
			fail("selected partition conformance pin changed")
		end
		if type(winner) ~= "table" or row.slot ~= winner.slot or
				row.slot_id ~= winner.id or row.candidate_index ~= winner.candidate_index or
				row.candidate_decimal ~= winner.decimal then
			fail("selected partition winner identity changed")
		end
		for _, field in ipairs({"slot", "candidate_index", "columns", "base_total",
				"planned_water", "dry", "g", "o", "r", "m", "schedule_intervals",
				"perimeter_aperture", "perimeter_attachment", "perimeter_dry",
				"transition_count", "bank_count", "wing_count", "coast_count",
				"face_count"}) do
			integer(row[field], 0, 9007199254740991, "selected partition " .. field)
		end
		if row.slot < 28 or row.slot > 31 or row.columns <= 0 or row.base_total <= 0 or
				row.planned_water <= 0 or row.base_total > row.planned_water or row.dry <= 0 or
				row.planned_water + row.dry ~= row.columns or row.g ~= 0 or row.o ~= 0 or
				row.r ~= 0 or row.m ~= 0 or row.transition_count ~= 8 or
				row.bank_count ~= 20 or row.wing_count ~= 8 or row.coast_count ~= 22 or
				row.face_count ~= 38 or row.perimeter_aperture <= 0 or
				row.perimeter_attachment ~= 8 or row.perimeter_dry <= 0 or
				row.schedule_intervals <= 0 then
			fail("selected partition complete gate changed")
		end
		for _, field in ipairs({"conformance_dag_sha256", "interpreter_sha256",
				"compiled_sha256"}) do sha(row[field], "selected partition " .. field) end
		if type(expected_interpreter_path) ~= "string" or
				row.interpreter_path ~= expected_interpreter_path or
				row.interpreter_version ~=
				"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio" then
			fail("selected partition interpreter changed")
		end
		return row
	end
	local function selected_result_blob(row)
		return result_blob(row, selected_fields, "selected partition result")
	end
	local function parse_selected_result(blob)
		local row = parse_result_blob(blob, selected_fields, "selected partition result")
		for _, field in ipairs({"slot", "candidate_index", "columns", "base_total",
				"planned_water", "dry", "g", "o", "r", "m", "schedule_intervals",
				"perimeter_aperture", "perimeter_attachment", "perimeter_dry",
				"transition_count", "bank_count", "wing_count", "coast_count",
				"face_count"}) do row[field] = tonumber(row[field]) end
		if selected_result_blob(row) ~= blob then
			fail("selected partition result bytes are not canonical")
		end
		return row
	end

	conformance.validate_gate = validate_gate
	conformance.validate_launch_pins = validate_launch_pins
	conformance.assert_launch_pins = assert_launch_pins
	conformance.parse_artifact = parse_artifact
	conformance.parse_manifest = parse_manifest
	conformance.sequential_slots = sequential_slots
	conformance.selected_and_required = selected_and_required
	conformance.validate_rescore_result = validate_rescore_result
	conformance.rescore_result_blob = rescore_result_blob
	conformance.parse_rescore_result = parse_rescore_result
	conformance.validate_selected_result = validate_selected_result
	conformance.selected_result_blob = selected_result_blob
	conformance.parse_selected_result = parse_selected_result
	conformance.digest = digest
	conformance.hex = hex
	return conformance
end
