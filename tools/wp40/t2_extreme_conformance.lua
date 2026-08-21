-- Test/tool-only T2c-E0-C1 conformance authority for the v3 scalar pool.  It
-- validates the retained v3 measurement and merge bytes, independently replays
-- the four sequential rankings, defines the closed 20-row PUC rescore roster,
-- and owns the v3 result schemas and the v3 output-path guards.
--
-- Three provenance claims are kept strictly apart and never share a field name.
--
--   (a) POOL ORIGIN -- pool_measurement_commit / pool_measurement_tree /
--       pool_authority_dag_sha256.  Historical: where the scalars were
--       measured.  t2_extreme_conformance_verify.lua re-materializes that
--       commit through t2_extreme_authority.validate_pinned_authority, without
--       a partition_sha256, because v3 pool provenance does not carry one.
--   (b) STAGE-S1 CURRENCY -- s1_authority_sha256 / s1_source_projection_sha256.
--       Recomputed from the tree the conformance actually runs on (s1_currency
--       below, following t2_extreme_gate_check.lua) and required to equal the
--       gate.  This is what lets a measured pool survive a later-stage geometry
--       correction instead of being invalidated by it.
--   (c) EXECUTING CODE -- execution_authority_dag_sha256.  The measurement
--       Authority-DAG of the conformance tree, i.e. of the modules that
--       actually re-derived the scalars.  It is recorded in a GATE-INDEPENDENT
--       position, and it is established against the EXECUTING TREE, never
--       against the pool: geometry/partition.lua, source/catalog.lua and
--       validation/t2_source.lua all differ between the pool commit and HEAD,
--       so asserting equality with (a) -- which the pre-v3 chain did -- would
--       now be a false claim rather than a check.  The field is nonetheless
--       checked: t2_extreme_conformance_verify.lua recomputes it from the
--       conformance tree per row, and t2_extreme_conformance_finalize.lua
--       requires all twenty-four rows to agree.
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

	-- Two pool generations live in the same directory and must never share a
	-- path.  Every v3 path guard is expressed here once, and each one rejects a
	-- pre-v3 name; is_historical_result_path is the mirrored predicate, so the
	-- KAT can prove both directions instead of trusting a format string.
	local retained_dir = "tools/wp40/fixtures/t2_extreme_e0/"
	local historical_result_patterns = {
		"^rescore%-puc%-%d%d%d%d%.tsv$",
		"^selected%-puc%-slot%d%d%.tsv$",
		"^conformance%-puc%.tsv$",
	}
	local function base_name(path)
		if type(path) ~= "string" or path == "" then
			fail("result path is not text")
		end
		return path:match("([^/]+)$") or path
	end
	local function is_historical_result_path(path)
		local name = base_name(path)
		for index = 1, #historical_result_patterns do
			if name:match(historical_result_patterns[index]) then return true end
		end
		return false
	end
	local function v3_result_path(relative, context)
		if is_historical_result_path(relative) then
			fail(context .. " names pre-v3 evidence")
		end
		return retained_dir .. relative
	end
	local function retained_shard_path(first, last)
		if type(first) ~= "number" or type(last) ~= "number" or
				first % 1 ~= 0 or last % 1 ~= 0 or first < 0 or last > 4095 or
				first % 512 ~= 0 or last ~= first + 511 then
			fail("v3 shard range is not canonical")
		end
		local relative = ("shard-luajit-v3-%04d-%04d.tsv"):format(first, last)
		if relative:match("^shard%-luajit%-%d%d%d%d%-%d%d%d%d%.tsv$") then
			fail("v3 shard path names pre-v3 evidence")
		end
		return retained_dir .. relative
	end
	local function rescore_result_path(candidate_index)
		integer(candidate_index, 0, 4095, "v3 rescore candidate")
		return v3_result_path(("rescore-puc-v3-%04d.tsv"):format(candidate_index),
			"v3 rescore output")
	end
	local function selected_result_path(slot)
		integer(slot, 28, 31, "v3 selected slot")
		return v3_result_path(("selected-puc-v3-slot%02d.tsv"):format(slot),
			"v3 selected output")
	end
	local function final_result_path()
		return v3_result_path("conformance-puc-v3.tsv", "v3 final output")
	end
	-- Exact absolute identity, not a suffix test.  A loose suffix match accepts
	-- /etc/rescore-puc-v3-0000.tsv and /xrescore-puc-v3-0000.tsv; requiring the
	-- retained directory under a named repository root accepts neither.
	local function assert_v3_result_path(path, repo, relative, context)
		if type(repo) ~= "string" or repo:sub(1, 1) ~= "/" or
				repo:sub(-1) == "/" or repo:find("/../", 1, true) or
				repo:find("/./", 1, true) then
			fail(context .. " repository root is not a plain absolute path")
		end
		if type(relative) ~= "string" or
				relative:sub(1, #retained_dir) ~= retained_dir or
				relative:find("/", #retained_dir + 1, true) then
			fail(context .. " is outside the retained directory")
		end
		if is_historical_result_path(relative) then
			fail(context .. " names pre-v3 evidence")
		end
		if type(path) ~= "string" or path ~= repo .. "/" .. relative then
			fail(context .. " path changed")
		end
		return path
	end

	-- A pre-v3 gate carries measurement_commit/source_checksum/
	-- boundary_policy_checksum/partition_sha256 and no pool_ or s1_ field, so
	-- exact_fields rejects it here before any digest is read -- and a v3 gate is
	-- rejected by the pre-v3 readers for the mirrored reason.
	local gate_fields = {"schema", "status", "pool_measurement_commit",
		"pool_measurement_tree", "pool_authority_dag_sha256",
		"s1_authority_sha256", "s1_source_projection_sha256", "artifact_sha256",
		"manifest_sha256", "candidate_rows_sha256", "shards", "winners",
		"staging"}
	local function validate_gate(gate)
		exact_fields(gate, gate_fields, "conformance gate")
		if gate.schema ~= "grug_wp40_extreme_conformance_gate_v3" or
				gate.status ~= "pending_selected_four_conformance" then
			fail("conformance gate schema/status changed")
		end
		commit(gate.pool_measurement_commit, "pool measurement commit")
		commit(gate.pool_measurement_tree, "pool measurement tree")
		for _, field in ipairs({"pool_authority_dag_sha256",
				"s1_authority_sha256", "s1_source_projection_sha256",
				"artifact_sha256", "manifest_sha256", "candidate_rows_sha256"}) do
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

	-- Nineteen v3 headers; the pre-v3 artifact has twenty and a different
	-- schema line, so neither can parse as the other.
	local artifact_headers = {"schema", "measurement_scope", "stage2_status",
		"s1_authority_sha256", "s1_source_projection_sha256",
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
		if values.schema ~= "grug_wp40_extreme_measurement_artifact_v3" or
				values.measurement_scope ~= "R7_SCALAR_MEASUREMENT_ONLY" or
				values.stage2_status ~= "pending_selected_four" or
				values.interpreter_id ~= "luajit" or
				values.scorer_schema ~= "grug_wp40_extreme_selector_e0_v1" or
				values.merge_interpreter_id ~= "puc_lua51" then
			fail("measurement artifact authority fields changed")
		end
		local gate_map = {s1_authority_sha256 = "s1_authority_sha256",
			s1_source_projection_sha256 = "s1_source_projection_sha256",
			authority_dag_sha256 = "pool_authority_dag_sha256",
			authority_commit = "pool_measurement_commit",
			authority_tree = "pool_measurement_tree",
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
			"schema\tgrug_wp40_extreme_candidate_shard_v3",
			"range\t0\t4095\t4096",
			"s1_authority_sha256\t" .. values.s1_authority_sha256,
			"s1_source_projection_sha256\t" .. values.s1_source_projection_sha256,
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
		-- The retained merged artifact is the current v3 pool, so it is read with
		-- the current v3 reader.  parse_historical_shard_blob is the read-only
		-- pre-v3 reader and is deliberately not reachable from this chain any
		-- more: presenting a pre-v3 record here must fail, not be tolerated.
		local shard = extreme.parse_shard_blob(fake)
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
		"s1_authority_sha256", "s1_source_projection_sha256",
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
				source_lines[1] ~= "grug_wp40_extreme_shard_manifest_v3" then
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
			s1_authority_sha256 = gate.s1_authority_sha256,
			s1_source_projection_sha256 = gate.s1_source_projection_sha256,
			authority_dag_sha256 = gate.pool_authority_dag_sha256,
			authority_commit = gate.pool_measurement_commit,
			authority_tree = gate.pool_measurement_tree, interpreter_id = "luajit",
			scorer_schema = "grug_wp40_extreme_selector_e0_v1",
			merge_interpreter_id = "puc_lua51"}
		for field, value in pairs(expected) do
			if values[field] ~= value then fail("measurement manifest pin changed") end
		end
		local shards = {}
		for index = 1, 8 do
			local fields = split_tabs(source_lines[1 + #manifest_headers + index])
			local expected_shard = gate.shards[index]
			local path = retained_shard_path(expected_shard.first,
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

	-- (a) pool_*, (b) s1_*, (c) execution_authority_dag_sha256 -- three separate
	-- claims, three separate names.  conformance_* is a fourth, different thing:
	-- the C1 launch pin of the run that produced the row.
	local rescore_fields = {"schema", "status", "scope",
		"pool_measurement_commit", "pool_measurement_tree",
		"pool_authority_dag_sha256", "s1_authority_sha256",
		"s1_source_projection_sha256", "conformance_commit", "conformance_tree",
		"conformance_dag_sha256", "execution_authority_dag_sha256",
		"artifact_sha256", "manifest_sha256", "candidate_rows_sha256",
		"interpreter_id", "interpreter_path", "interpreter_version",
		"interpreter_sha256", "candidate_index", "candidate_decimal",
		"candidate_role", "expected_row_sha256", "rescored_row_sha256"}
	local function validate_rescore_result(row, gate, expected_index,
			expected_row_sha256, conformance_pins, expected_interpreter_path)
		validate_gate(gate)
		exact_fields(row, rescore_fields, "PUC rescore result")
		if row.schema ~= "grug_wp40_extreme_puc_rescore_v3" or
				row.status ~= "passed" or
				row.scope ~= "T2C_E0_PUC_ROW_CONFORMANCE_ONLY" or
				row.interpreter_id ~= "puc_lua51" then
			fail("PUC rescore schema/status changed")
		end
		local gate_map = {pool_measurement_commit = "pool_measurement_commit",
			pool_measurement_tree = "pool_measurement_tree",
			pool_authority_dag_sha256 = "pool_authority_dag_sha256",
			s1_authority_sha256 = "s1_authority_sha256",
			s1_source_projection_sha256 = "s1_source_projection_sha256",
			artifact_sha256 = "artifact_sha256",
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
		for _, field in ipairs({"conformance_dag_sha256",
				"execution_authority_dag_sha256", "interpreter_sha256",
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
	local selected_fields = {"schema", "status", "scope",
		"pool_measurement_commit", "pool_measurement_tree",
		"pool_authority_dag_sha256", "s1_authority_sha256",
		"s1_source_projection_sha256", "conformance_commit", "conformance_tree",
		"conformance_dag_sha256", "execution_authority_dag_sha256",
		"artifact_sha256", "manifest_sha256", "candidate_rows_sha256",
		"interpreter_id", "interpreter_path", "interpreter_version",
		"interpreter_sha256", "slot", "slot_id", "candidate_index",
		"candidate_decimal", "compiled_sha256", "columns", "base_total",
		"planned_water", "dry", "g", "o", "r", "m", "schedule_intervals",
		"perimeter_aperture", "perimeter_attachment", "perimeter_dry",
		"transition_count", "bank_count", "wing_count", "coast_count",
		"face_count"}
	local function validate_selected_result(row, gate, winner, conformance_pins,
			expected_interpreter_path)
		validate_gate(gate)
		exact_fields(row, selected_fields, "selected partition result")
		if row.schema ~= "grug_wp40_extreme_selected_partition_v3" or
				row.status ~= "passed" or
				row.scope ~= "T2C_E0_SELECTED_FOUR_PARTITION_CONFORMANCE_ONLY" or
				row.interpreter_id ~= "puc_lua51" then
			fail("selected partition schema/status changed")
		end
		local measurement = {
			pool_measurement_commit = gate.pool_measurement_commit,
			pool_measurement_tree = gate.pool_measurement_tree,
			pool_authority_dag_sha256 = gate.pool_authority_dag_sha256,
			s1_authority_sha256 = gate.s1_authority_sha256,
			s1_source_projection_sha256 = gate.s1_source_projection_sha256,
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
		for _, field in ipairs({"conformance_dag_sha256",
				"execution_authority_dag_sha256", "interpreter_sha256",
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

	-- (R3b) Stage-S1 CURRENCY, computed exactly like t2_extreme_gate_check.lua
	-- and in the same order: the S1 Source projection is a pure function of the
	-- catalog with no seed geometry, and the S1 authority digest covers the S1
	-- module plus the arithmetic surface it reads.  geometry/partition.lua and
	-- source/catalog.lua BYTES are deliberately not inputs; that decoupling is
	-- exactly what keeps a measured pool valid across a later-stage correction.
	--
	-- The caller passes a LIVE capture of the tree the conformance runs on, not
	-- a re-materialized historical commit: this is a claim about today's code.
	local function s1_currency(measurement_authority, files, gate)
		validate_gate(gate)
		if type(measurement_authority) ~= "table" or
				type(measurement_authority.load_module) ~= "function" or
				type(files) ~= "table" or type(files.files) ~= "table" then
			fail("stage-S1 currency inputs are invalid")
		end
		local function load(path)
			return measurement_authority.load_module(files, path)
		end
		local canonical = load("mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
		local deterministic = load("mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
		local exact = load("mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua")({
			deterministic = deterministic})
		local raster = load("mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua")({
			canonical = canonical, deterministic = deterministic, exact = exact,
			raw_sha256 = raw_sha256})
		local source = load("mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
		local validator = load(
			"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua")
		local vocabulary = load("tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
		local boundary = load("mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua")({
			canonical = canonical, deterministic = deterministic, exact = exact,
			raster = raster, raw_sha256 = raw_sha256, source = source,
			source_validator = validator, vocabulary = vocabulary})
		local s1_authority = load("tools/wp40/t2_s1_authority.lua")({
			raw_sha256 = raw_sha256})
		local projection = sha(boundary.s1_source_checksum(),
			"stage-S1 Source projection")
		local authority_digest = sha(s1_authority.digest(files.files, projection,
			boundary.PROJECTION_SCHEMA), "stage-S1 authority digest")
		if projection ~= gate.s1_source_projection_sha256 then
			fail("stage-S1 Source projection differs from the conformance gate")
		end
		if authority_digest ~= gate.s1_authority_sha256 then
			fail("stage-S1 authority digest differs from the conformance gate")
		end
		-- Recheck through the S1 authority's own verifier, so the projection
		-- schema is bound as well and not just the two digest values.
		if not s1_authority.verify(files.files, projection,
				boundary.PROJECTION_SCHEMA, gate.s1_authority_sha256) then
			fail("stage-S1 authority verification failed")
		end
		return {s1_authority_sha256 = authority_digest,
			s1_source_projection_sha256 = projection}
	end

	-- (R3c) The measurement Authority-DAG of the tree that is executing this
	-- conformance -- the modules that actually re-derive the scalars.  It is
	-- recorded in every result row in a GATE-INDEPENDENT position, because it
	-- legitimately differs from the pool's own Authority-DAG: the Section 11
	-- correction landed after the pool was measured.  It is established against
	-- the executing tree, never against the pool -- the verifier recomputes it
	-- live per row and the finalizer requires cross-row agreement.
	local function execution_authority_dag(measurement_authority, files)
		if type(measurement_authority) ~= "table" or
				type(measurement_authority.bind_vocabulary) ~= "function" or
				type(measurement_authority.load_module) ~= "function" then
			fail("execution authority inputs are invalid")
		end
		local vocabulary = measurement_authority.load_module(files,
			"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
		local bound = measurement_authority.bind_vocabulary(files, vocabulary)
		return sha(bound.authority_dag_sha256, "execution Authority-DAG")
	end

	conformance.retained_shard_path = retained_shard_path
	conformance.rescore_result_path = rescore_result_path
	conformance.selected_result_path = selected_result_path
	conformance.final_result_path = final_result_path
	conformance.assert_v3_result_path = assert_v3_result_path
	conformance.is_historical_result_path = is_historical_result_path
	conformance.s1_currency = s1_currency
	conformance.execution_authority_dag = execution_authority_dag
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
