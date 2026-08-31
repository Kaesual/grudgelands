-- Canonical WP40 R7 runtime evidence over the production-private facade.
-- This tool never implements placement policy: it encodes and compares the
-- planner/settlement decisions returned by r7_runtime.build(..., true).

local module = {schema = "grug_wp40_r7_runtime_adapter_v1"}

local MAX_SAFE = 9007199254740991
local INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z = -32, -32
local OWNER_MIN_X, OWNER_MAX_X = -3792, 3728
local OWNER_MIN_Z, OWNER_MAX_Z = -3392, 3328
local ACCEPTED_R6_ARTIFACT_SHA256 =
	"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4"
local P9G_REASONS = {
	"clipped_owner", "fixed_or_protected", "route_or_water",
	"housing_exclusion", "content_ignore", "wrong_zone", "wrong_biome",
	"wrong_shore", "wrong_support", "insufficient_clearance", "r6_occupancy",
}
local P9G_BRACKETS = {['1-10'] = true, ['11-20'] = true, ['21-30'] = true,
	['31-40'] = true, ['41-50'] = true, ['51-60'] = true}

local function fail(message)
	error("WP40 R7 runtime adapter: " .. message, 0)
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum or math.abs(value) > MAX_SAFE then
		fail(label .. " is not an exact bounded integer")
	end
	return value
end

local function text(value, label)
	if type(value) ~= "string" or value == "" or
			value:find("\0", 1, true) or value:find("\t", 1, true) or
			value:find("\r", 1, true) or value:find("\n", 1, true) then
		fail(label .. " is not one nonempty TSV-safe string")
	end
	return value
end

local function digest(value, label)
	if type(value) ~= "string" or #value ~= 64 or
			not value:match("^[0-9a-f]+$") then
		fail(label .. " is not lowercase SHA-256")
	end
	return value
end

local function exact_fields(value, expected, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	local actual_count, expected_count = 0, 0
	for key in pairs(value) do
		actual_count = actual_count + 1
		if not expected[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
	for key in pairs(expected) do
		expected_count = expected_count + 1
		if rawget(value, key) == nil then fail(label .. " is missing " .. key) end
	end
	if actual_count ~= expected_count then fail(label .. " field count differs") end
	return value
end

local function dense(value, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain array")
	end
	local count = #value
	for index = 1, count do
		if value[index] == nil then fail(label .. " has a hole") end
	end
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not dense")
		end
		seen = seen + 1
	end
	if seen ~= count then fail(label .. " dense population differs") end
	return value
end

local function less_bytes(left, right)
	local count = math.min(#left, #right)
	for index = 1, count do
		local a, b = string.byte(left, index), string.byte(right, index)
		if a ~= b then return a < b end
	end
	return #left < #right
end

local function scalar(value)
	if type(value) == "string" then
		-- This is a length-prefixed graph encoding, not a line format.  R6's
		-- production settlement maps deliberately use NUL-delimited composite
		-- keys, and every byte is unambiguous once the exact length is encoded.
		return "s" .. tostring(#value) .. ":" .. value
	elseif type(value) == "number" then
		integer(value, -MAX_SAFE, MAX_SAFE, "canonical number")
		return "n" .. string.format("%.0f", value) .. ";"
	elseif type(value) == "boolean" then
		return value and "b1;" or "b0;"
	end
	fail("canonical scalar type differs: " .. type(value))
end

local function graph(value, active)
	if type(value) ~= "table" then return scalar(value) end
	if getmetatable(value) ~= nil then fail("canonical graph has a metatable") end
	active = active or {}
	if active[value] then fail("canonical graph is cyclic") end
	active[value] = true
	local count, key_count, is_array = #value, 0, true
	for key in pairs(value) do
		key_count = key_count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			is_array = false
		end
	end
	if key_count ~= count then is_array = false end
	local result = {}
	if is_array then
		result[1] = "a" .. tostring(count) .. "["
		for index = 1, count do result[#result + 1] = graph(value[index], active) end
		result[#result + 1] = "]"
	else
		local entries = {}
		for key, child in pairs(value) do
			local encoded_key = graph(key, active)
			entries[#entries + 1] = encoded_key .. graph(child, active)
		end
		table.sort(entries, less_bytes)
		result[1] = "m" .. tostring(#entries) .. "{"
		for index = 1, #entries do result[#result + 1] = entries[index] end
		result[#result + 1] = "}"
	end
	active[value] = nil
	return table.concat(result)
end

local function raw_sha256(repo, bytes)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	return common.new_sha256()(bytes)
end

local function hex(bytes)
	return (bytes:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

local function sha256(repo, bytes)
	return hex(raw_sha256(repo, bytes))
end

local function sha_stream(repo)
	local ffi = rawget(_G, "wp40_ffi")
	if not ffi then fail("LuaJIT FFI injection is required") end
	return dofile(repo .. "/tools/wp40/r6/sha256_stream.lua")(ffi)
end

local function row_key(row)
	return tostring(row[1]) .. "/" .. tostring(row[2]) .. "/" .. tostring(row[3])
end

local function population_key(source_id, zone_id, biome, faction, bracket)
	return table.concat({source_id, zone_id, biome, faction, bracket}, "\0")
end

local function validate_evidence_rows(rows, label)
	dense(rows, label)
	local previous
	for index = 1, #rows do
		local row = dense(rows[index], label .. " row " .. index)
		if #row ~= 10 then fail(label .. " row width differs") end
		for field = 1, 10 do
			integer(row[field], -MAX_SAFE, MAX_SAFE,
				label .. " row " .. index .. " field " .. field)
		end
		local key = row_key(row)
		if previous and not (rows[index - 1][3] < row[3] or
				(rows[index - 1][3] == row[3] and
					(rows[index - 1][1] < row[1] or
						(rows[index - 1][1] == row[1] and
							rows[index - 1][2] < row[2])))) then
			fail(label .. " rows are not canonical z/x/y unique")
		end
		previous = key
	end
	return rows
end

local function evidence_row_bytes(rows)
	validate_evidence_rows(rows, "evidence rows")
	local output = {"schema\tgrug_wp40_r7_private_buffer_projection_v1\n"}
	for index = 1, #rows do
		local row, fields = rows[index], {}
		for field = 1, 10 do fields[field] = string.format("%.0f", row[field]) end
		output[#output + 1] = "row\t" .. table.concat(fields, "\t") .. "\n"
	end
	return table.concat(output)
end

local function production_run_bytes(runs)
	dense(runs, "production evidence runs")
	local output = {"schema\tgrug_wp40_r7_production_run_projection_v1\n"}
	for index = 1, #runs do
		local row = dense(runs[index], "production evidence run " .. index)
		if #row ~= 11 then fail("production evidence run width differs") end
		local fields = {}
		for field = 1, 11 do
			integer(row[field], -MAX_SAFE, MAX_SAFE,
				"production evidence run field")
			fields[field] = string.format("%.0f", row[field])
		end
		output[#output + 1] = "run\t" .. table.concat(fields, "\t") .. "\n"
	end
	return table.concat(output)
end

local OPERATION_FIELDS = {
	"source_id", "cell_x", "cell_z", "root_x", "root_y", "root_z",
	"zone_id", "biome", "faction", "bracket", "candidate_sha256",
	"original_cid", "original_param2", "prior_cid", "prior_param2",
	"prior_occupancy", "prior_opcode", "prior_feature", "prior_interface",
	"prior_aux", "support_mode", "support_cid", "support_param2",
	"support_occupancy", "support_opcode", "support_feature",
	"support_interface", "support_aux", "final_cid", "final_param2",
	"final_occupancy", "final_opcode", "final_feature", "final_interface",
	"final_aux", "accepted", "reason",
}
local OPERATION_KEYS = {}
local OPERATION_COLUMN = {}
for index = 1, #OPERATION_FIELDS do
	OPERATION_KEYS[OPERATION_FIELDS[index]] = true
	OPERATION_COLUMN[OPERATION_FIELDS[index]] = index + 1
end

local function same_tuple(row, operation, prefix)
	return row[4] == operation[prefix .. "cid"] and
		row[5] == operation[prefix .. "param2"] and
		row[6] == operation[prefix .. "occupancy"] and
		row[7] == operation[prefix .. "opcode"] and
		row[8] == operation[prefix .. "feature"] and
		row[9] == operation[prefix .. "interface"] and
		row[10] == operation[prefix .. "aux"]
end

local function operation_bytes(operation)
	exact_fields(operation, OPERATION_KEYS, "P9G operation")
	text(operation.source_id, "P9G source ID")
	text(operation.zone_id, "P9G zone ID")
	text(operation.biome, "P9G biome")
	text(operation.faction, "P9G faction")
	text(operation.bracket, "P9G bracket")
	digest(operation.candidate_sha256, "P9G candidate digest")
	if type(operation.accepted) ~= "boolean" then fail("P9G acceptance differs") end
	text(operation.reason, "P9G reason")
	local values = {}
	for index = 1, #OPERATION_FIELDS do
		local value = operation[OPERATION_FIELDS[index]]
		if type(value) == "number" then
			integer(value, -MAX_SAFE, MAX_SAFE, "P9G operation integer")
			value = string.format("%.0f", value)
		elseif type(value) == "boolean" then
			value = value and "true" or "false"
		end
		values[index] = value
	end
	return "operation\t" .. table.concat(values, "\t") .. "\n"
end

local function validate_scan(scan, owner_x, owner_z, successor)
	exact_fields(scan, {schema = true, owner_x = true, owner_z = true,
		column_count = true, groups = true, coverage = true, candidates = true,
		settlement = true},
		"horizontal owner evidence")
	if scan.schema ~= "grug_wp40_r7_horizontal_owner_evidence_v1" or
			scan.owner_x ~= owner_x or scan.owner_z ~= owner_z or
			scan.column_count ~= 6400 then
		fail("horizontal owner evidence identity differs")
	end
	dense(scan.groups, "owner groups")
	dense(scan.coverage, "owner coverage")
	exact_fields(scan.candidates, {cultural = true, decorations = true},
		"owner candidates")
	dense(scan.candidates.cultural, "owner Cultural candidates")
	dense(scan.candidates.decorations, "owner decoration candidates")
	local expected = {cultural = true, decorations = true, rejections = true,
		witnesses = true, apex_overlaps = true, direct_rows = true,
		direct_runs = true}
	if successor then expected.p9g, expected.final_rows, expected.final_runs =
		true, true, true end
	exact_fields(scan.settlement, expected, "owner settlement")
	validate_evidence_rows(scan.settlement.direct_rows, "owner direct rows")
	production_run_bytes(scan.settlement.direct_runs)
	if successor then validate_evidence_rows(scan.settlement.final_rows,
		"owner final rows"); production_run_bytes(scan.settlement.final_runs) end
	if scan.settlement.apex_overlaps ~= 0 then fail("owner overlaps an apex socket") end
	return scan
end

local function validate_ledger(ledger)
	exact_fields(ledger, {schema = true, groups = true, populations = true,
		operations = true, rejections = true, accepted = true, planned = true,
		eligible = true, manifest_sha256 = true}, "P9G ledger")
	if ledger.schema ~= "grug_wp40_r7_p9g_ledger_v1" then
		fail("P9G ledger schema differs")
	end
	dense(ledger.groups, "P9G groups")
	dense(ledger.populations, "P9G populations")
	dense(ledger.operations, "P9G operations")
	digest(ledger.manifest_sha256, "P9G manifest digest")
	integer(ledger.accepted, 0, MAX_SAFE, "P9G accepted")
	integer(ledger.planned, 0, MAX_SAFE, "P9G planned")
	integer(ledger.eligible, 0, MAX_SAFE, "P9G eligible")
	if #ledger.operations ~= ledger.planned then fail("P9G operation population differs") end
	local function rejection_map(value, label)
		local keys = {}
		for index = 1, #P9G_REASONS do keys[P9G_REASONS[index]] = true end
		exact_fields(value, keys, label)
		for index = 1, #P9G_REASONS do
			integer(value[P9G_REASONS[index]], 0, MAX_SAFE,
				label .. " " .. P9G_REASONS[index])
		end
	end
	rejection_map(ledger.rejections, "P9G ledger rejections")
	local group_sums = {eligible = 0, budget = 0, accepted = 0, rejections = {}}
	local population_sums = {eligible = 0, budget = 0, accepted = 0, rejections = {}}
	for index = 1, #P9G_REASONS do
		group_sums.rejections[P9G_REASONS[index]] = 0
		population_sums.rejections[P9G_REASONS[index]] = 0
	end
	for index = 1, #ledger.groups do
		local row = exact_fields(ledger.groups[index], {source_id = true, cell_x = true,
			cell_z = true, eligible = true, budget = true, accepted = true,
			rejections = true}, "P9G group")
		text(row.source_id, "P9G group source")
		integer(row.cell_x, -1932, 1932, "P9G group cell x")
		integer(row.cell_z, -1932, 1932, "P9G group cell z")
		for _, field in ipairs({"eligible", "budget", "accepted"}) do
			integer(row[field], 0, MAX_SAFE, "P9G group " .. field)
			group_sums[field] = group_sums[field] + row[field]
		end
		rejection_map(row.rejections, "P9G group rejections")
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			group_sums.rejections[name] = group_sums.rejections[name] +
				row.rejections[name]
		end
	end
	for index = 1, #ledger.populations do
		local row = exact_fields(ledger.populations[index], {source_id = true,
			zone_id = true, biome = true, faction = true, bracket = true,
			eligible = true, budget = true, accepted = true, rejections = true},
			"P9G population")
		for _, field in ipairs({"source_id", "zone_id", "biome", "faction", "bracket"}) do
			text(row[field], "P9G population " .. field)
		end
		for _, field in ipairs({"eligible", "budget", "accepted"}) do
			integer(row[field], 0, MAX_SAFE, "P9G population " .. field)
			population_sums[field] = population_sums[field] + row[field]
		end
		rejection_map(row.rejections, "P9G population rejections")
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			population_sums.rejections[name] = population_sums.rejections[name] +
				row.rejections[name]
		end
	end
	for _, sums in ipairs({group_sums, population_sums}) do
		if sums.eligible ~= ledger.eligible or sums.budget ~= ledger.planned or
				sums.accepted ~= ledger.accepted then
			fail("P9G group/population totals differ")
		end
		for reason = 1, #P9G_REASONS do
			local name = P9G_REASONS[reason]
			if sums.rejections[name] ~= ledger.rejections[name] then
				fail("P9G group/population rejection totals differ")
			end
		end
	end
	local accepted = 0
	local operation_rejections = {}
	for index = 1, #P9G_REASONS do operation_rejections[P9G_REASONS[index]] = 0 end
	local previous
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		operation_bytes(operation)
		if operation.accepted then accepted = accepted + 1
		else
			if operation_rejections[operation.reason] == nil then
				fail("P9G operation rejection reason differs")
			end
			operation_rejections[operation.reason] =
				operation_rejections[operation.reason] + 1
		end
		local key = table.concat({operation.root_z, operation.root_x,
			operation.root_y, operation.source_id}, "\0")
		if previous then
			local old = ledger.operations[index - 1]
			if not (old.root_z < operation.root_z or
					(old.root_z == operation.root_z and
						(old.root_x < operation.root_x or
							(old.root_x == operation.root_x and
								(old.root_y < operation.root_y or
									(old.root_y == operation.root_y and
										less_bytes(old.source_id, operation.source_id))))))) then
				fail("P9G operations are not coordinate/source ordered")
			end
		end
		previous = key
	end
	if accepted ~= ledger.accepted then fail("P9G accepted count differs") end
	for index = 1, #P9G_REASONS do
		local name = P9G_REASONS[index]
		if operation_rejections[name] ~= ledger.rejections[name] then
			fail("P9G operation rejection partition differs")
		end
	end
	return ledger
end

local function copy_rows(rows)
	local result = {}
	for index = 1, #rows do
		result[index] = {}
		for field = 1, 10 do result[index][field] = rows[index][field] end
	end
	return result
end

local function stage_a_owner(repo, fixture, successor, direct)
	validate_scan(successor, successor.owner_x, successor.owner_z, true)
	validate_scan(direct, successor.owner_x, successor.owner_z, false)
	if graph(successor.groups) ~= graph(direct.groups) or
			graph(successor.coverage) ~= graph(direct.coverage) or
			graph(successor.candidates) ~= graph(direct.candidates) or
			evidence_row_bytes(successor.settlement.direct_rows) ~=
				evidence_row_bytes(direct.settlement.direct_rows) or
			production_run_bytes(successor.settlement.direct_runs) ~=
				production_run_bytes(direct.settlement.direct_runs) then
		fail("successor Direct-83 projection differs from independent direct scan")
	end
	local ledger = validate_ledger(successor.settlement.p9g)
	local final_by_key, direct_by_key = {}, {}
	for index = 1, #successor.settlement.final_rows do
		local row = successor.settlement.final_rows[index]
		final_by_key[row_key(row)] = row
	end
	for index = 1, #direct.settlement.direct_rows do
		local row = direct.settlement.direct_rows[index]
		direct_by_key[row_key(row)] = row
	end
	local restored = copy_rows(successor.settlement.final_rows)
	local restored_by_key = {}
	for index = 1, #restored do restored_by_key[row_key(restored[index])] = index end
	local operation_lines, accepted, rejected = {}, 0, 0
	local air_cid = fixture.cid_by_name.air
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		operation_lines[index] = operation_bytes(operation)
		local key = tostring(operation.root_x) .. "/" .. tostring(operation.root_y) ..
			"/" .. tostring(operation.root_z)
		local final_row = final_by_key[key]
		if operation.accepted then
			accepted = accepted + 1
			if not final_row or not same_tuple(final_row, operation, "final_") or
				operation.reason ~= "accepted" or operation.final_opcode ~= 35 or
				operation.final_occupancy ~= -2 then
				fail("accepted P9G final tuple differs")
			end
			local direct_row = direct_by_key[key]
			if direct_row then
				if not same_tuple(direct_row, operation, "prior_") then
					fail("accepted P9G prior tuple differs from direct row")
				end
				restored[restored_by_key[key]] = copy_rows({direct_row})[1]
			else
				if operation.prior_cid ~= air_cid or operation.prior_param2 ~= 0 or
						operation.prior_occupancy ~= 0 or operation.prior_opcode ~= 0 or
						operation.prior_feature ~= 0 or operation.prior_interface ~= 0 or
						operation.prior_aux ~= 0 then
					fail("accepted P9G prior tuple is not independent implicit air")
				end
				restored[restored_by_key[key]] = false
			end
		else
			rejected = rejected + 1
			if operation.reason == "accepted" then fail("rejected P9G reason differs") end
			if operation.final_cid ~= -1 and
					(operation.final_cid ~= operation.prior_cid or
					operation.final_param2 ~= operation.prior_param2 or
					operation.final_occupancy ~= operation.prior_occupancy or
					operation.final_opcode ~= operation.prior_opcode or
					operation.final_feature ~= operation.prior_feature or
					operation.final_interface ~= operation.prior_interface or
					operation.final_aux ~= operation.prior_aux) then
				fail("rejected P9G operation changed the full prior tuple")
			end
		end
	end
	local compact = {}
	for index = 1, #restored do
		if restored[index] then compact[#compact + 1] = restored[index] end
	end
	table.sort(compact, function(left, right)
		if left[3] ~= right[3] then return left[3] < right[3] end
		if left[1] ~= right[1] then return left[1] < right[1] end
		return left[2] < right[2]
	end)
	local restored_buffers, direct_buffers = evidence_row_bytes(compact),
		evidence_row_bytes(direct.settlement.direct_rows)
	local restored_run_rows, p9g_run_count = {}, 0
	for index = 1, #successor.settlement.final_runs do
		local row = successor.settlement.final_runs[index]
		if row[6] == 35 then
			p9g_run_count = p9g_run_count + 1
			if row[3] ~= row[4] or row[5] ~= 10 or row[7] ~= 17 or
					row[8] ~= 11 or row[10] ~= 0 then
				fail("P9G production run identity differs")
			end
		else
			restored_run_rows[#restored_run_rows + 1] = row
		end
	end
	if p9g_run_count ~= accepted then fail("P9G accepted/run population differs") end
	local restored_runs = production_run_bytes(restored_run_rows)
	local direct_runs = production_run_bytes(direct.settlement.direct_runs)
	if restored_buffers ~= direct_buffers or restored_runs ~= direct_runs then
		fail("Stage-A restored Direct-83 state differs")
	end
	return {accepted = accepted, rejected = rejected,
		operation_count = #ledger.operations, operation_bytes = table.concat(operation_lines),
		ledger = ledger,
		restored_buffers = restored_buffers, direct_buffers = direct_buffers,
		restored_runs = restored_runs, direct_runs = direct_runs}
end

local function fixture(repo, seed, evidence_mode)
	if evidence_mode == nil or evidence_mode == true then
		return dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(repo, seed)
	end
	if evidence_mode ~= "horizontal" then fail("runtime fixture mode differs") end
	local constructor = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")
	local base = constructor(repo, seed, true)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local runtime = dofile(wp40 .. "/r7_runtime.lua")(base.core, wp40,
		repo .. "/mods/BASE/default/schematics", base.projection, base.catalog)
	base.built = runtime.build(base.native_identities, nil, "horizontal")
	base.catalog_manifest = base.catalog.manifest()
	base.schema = "grug_wp40_r7_runtime_fixture_v1"
	return base
end

local PROJECTION_FAMILIES = {
	surface_coverage = true, cultural_candidate = true, cultural_slot = true,
	decoration_candidate = true, decoration_settlement = true,
}

local cultural_name_set

local function artifact_content_binding(repo, runtime_fixture, seed_slot)
	local path = repo .. "/docs/research/wp40-simple-map-r6-artifact.tsv"
	local stream = sha_stream(repo)
	local hasher = stream.new()
	local codec = dofile(repo .. "/tools/wp40/r6/artifact_codec.lua")
	local file = assert(io.open(path, "rb"), "cannot open accepted R6 artifact")
	local header = file:read("*l")
	if header ~= codec.header_line() then fail("accepted R6 artifact header differs") end
	hasher.update(header .. "\n")
	local content, projection_records, cultural_access = {}, {}, {}
	local expected_cultural = {dwarf = "runeslate", elf = "moonresin",
		human = "sunwax", orc = "red_ochre", troll = "spirit_resin",
		undead = "gravesalt"}
	while true do
		local line = file:read("*l")
		if not line then break end
		if line:find("\r", 1, true) then fail("accepted R6 artifact has CR bytes") end
		hasher.update(line .. "\n")
		if line:find("^content\t") then
			local fields = codec.parse_data_line(line, "accepted R6 content row")
			local ref = tonumber(fields[2])
			if not ref or ref % 1 ~= 0 or ref < 1 or ref > 77 or content[ref] then
				fail("accepted R6 content ref differs")
			end
			content[ref] = {name = fields[12], cid = tonumber(fields[13]),
				mask = tonumber(fields[14]), line = line .. "\n"}
		elseif line:find("^access\taccess_cultural\t") then
			local access = codec.parse_data_line(line, "accepted R6 Cultural access row")
			local race, key, rate = access[3], access[4], access[5]
			local identity = tostring(race) .. "\0" .. tostring(key) .. "\0" ..
				tostring(rate)
			if expected_cultural[race] ~= key or
					(rate ~= "ordinary" and rate ~= "concentrated") or
					access[12] ~= "true" or cultural_access[identity] then
				fail("accepted R6 Cultural access identity differs")
			end
			cultural_access[identity] = true
		elseif seed_slot and (PROJECTION_FAMILIES[line:match("^([^\t]+)")] or
				line:find("^rejection\t")) then
			local fields = codec.parse_data_line(line, "accepted R6 projection row")
			local family = fields[1]
			if tonumber(fields[2]) == seed_slot and
					(family ~= "rejection" or fields[3] == "cultural" or
						fields[3] == "decoration") then
				projection_records[#projection_records + 1] = {fields = fields,
					bytes = line .. "\n"}
			end
		end
	end
	assert(file:close())
	local cultural_access_count = 0
	for race, key in pairs(expected_cultural) do
		for _, rate in ipairs({"ordinary", "concentrated"}) do
			if not cultural_access[race .. "\0" .. key .. "\0" .. rate] then
				fail("accepted R6 Cultural access row is absent")
			end
			cultural_access_count = cultural_access_count + 1
		end
	end
	if cultural_access_count ~= 12 then fail("accepted R6 Cultural access count differs") end
	local file_digest = hasher.final_hex()
	if file_digest ~= ACCEPTED_R6_ARTIFACT_SHA256 or
			runtime_fixture.built.manifest.values.r6_artifact_sha256 ~= file_digest then
		fail("accepted R6 artifact file digest differs")
	end
	local accepted_rows = runtime_fixture.built.content.accepted_r6_rows()
	dense(accepted_rows, "accepted R6 content rows")
	if #accepted_rows ~= 77 then fail("accepted R6 content population differs") end
	local by_name = {}
	for index = 1, 77 do
		local expected, actual = accepted_rows[index], content[index]
		if type(expected) ~= "table" or #expected ~= 2 or not actual or
				actual.name ~= expected[1] or actual.mask ~= expected[2] or
				actual.cid ~= 999 + index or by_name[actual.name] then
			fail("accepted R6 content row differs at ref " .. tostring(index))
		end
		by_name[actual.name] = {ref = index, cid = actual.cid, mask = actual.mask}
	end
	if seed_slot then
		table.sort(projection_records, function(left, right)
			return codec.compare(left.fields, right.fields)
		end)
		if #projection_records ~= 104 + 12 + 12 + 48 + 48 + 36 + 480 then
			fail("accepted R6 horizontal aggregate row population differs")
		end
	end
	local cultural = cultural_name_set(runtime_fixture)
	return {sha256 = file_digest, by_name = by_name, rows = content,
		projection_records = projection_records, codec = codec, cultural = cultural,
		inherited_cultural_access_count = cultural_access_count}
end

cultural_name_set = function(runtime_fixture)
	local set, rows = {}, runtime_fixture.catalog.cultural_sources()
	dense(rows, "cultural source catalog")
	if #rows ~= 6 then fail("cultural source population differs") end
	for index = 1, #rows do
		local name = rows[index].source_node
		text(name, "cultural source node")
		if set[name] then fail("duplicate cultural source node") end
		set[name] = true
	end
	return set
end

local function normalize_rows(runtime_fixture, binding, rows)
	local cultural = binding.cultural or cultural_name_set(runtime_fixture)
	if not binding.total_map_checked then
		local names = runtime_fixture.built.content.production.content_names
		if #names ~= 83 then fail("Direct-83 name-map population differs") end
		local previous, accepted_count, cultural_count = nil, 0, 0
		for index = 1, #names do
			local name = names[index]
			if previous and not less_bytes(previous, name) then
				fail("Direct-83 names are not ASCII unique")
			end
			if binding.by_name[name] then accepted_count = accepted_count + 1
			elseif cultural[name] then cultural_count = cultural_count + 1
			else fail("Direct-83 name escapes total accepted map: " .. name) end
			previous = name
		end
		if accepted_count ~= 77 or cultural_count ~= 6 then
			fail("Direct-83 accepted/Cultural partition differs")
		end
		binding.cultural, binding.total_map_checked = cultural, true
	end
	local bone = assert(binding.by_name["grug_nodes:bone_pile"])
	local output, substitutions = {}, 0
	for index = 1, #rows do
		local source, row = rows[index], {}
		for field = 1, 10 do row[field] = source[field] end
		local name = runtime_fixture.name_by_cid[source[4]]
		local target = name and binding.by_name[name]
		if name == "air" then
			if source[4] ~= runtime_fixture.cid_by_name.air or source[10] ~= 0 then
				fail("Direct-83 air reservation tuple differs")
			end
			output[index] = row
		elseif not target and name and cultural[name] then
			if source[7] ~= 34 then
				fail("Cultural target substitution escaped opcode 34")
			end
			target, substitutions = bone, substitutions + 1
		elseif not target then
			fail("Direct-83 row has no total accepted name mapping: cid=" ..
				tostring(source[4]) .. " name=" .. tostring(name) .. " opcode=" ..
				tostring(source[7]))
		end
		if target then
			row[4] = target.cid
			row[10] = (target.ref - 1) * 256 + row[5]
			output[index] = row
		end
	end
	return output, substitutions
end

local function normalize_runs(runtime_fixture, binding, runs)
	local cultural = binding.cultural or cultural_name_set(runtime_fixture)
	local bone = assert(binding.by_name["grug_nodes:bone_pile"])
	local names = runtime_fixture.built.content.production.content_names
	local output = {}
	for index = 1, #runs do
		local source, row = runs[index], {}
		for field = 1, 11 do row[field] = source[field] end
		local ref = math.floor(source[11] / 256) + 1
		local param2 = source[11] % 256
		local name, target = names[ref], names[ref] and binding.by_name[names[ref]]
		if not target and name and cultural[name] then
			if source[6] ~= 34 then
				fail("Cultural run substitution escaped opcode 34")
			end
			target = bone
		elseif not target then
			fail("Direct-83 run has no total accepted name mapping")
		end
		row[11] = (target.ref - 1) * 256 + param2
		output[index] = row
	end
	return output
end

local function scan_accepted_loaded(loaded, owner_x, owner_z)
	local cultural, decorations, groups, coverage, columns = {}, {}, {}, {}, 0
	for cell_z = owner_z / 16, owner_z / 16 + 4 do
		for cell_x = owner_x / 16, owner_x / 16 + 4 do
			local c, d, g, v, n = loaded.planner_fixture.build_cell(cell_x, cell_z)
			columns = columns + n
			for index = 1, #c do cultural[#cultural + 1] = c[index] end
			for index = 1, #d do decorations[#decorations + 1] = d[index] end
			for index = 1, #g do groups[#groups + 1] = g[index] end
			for index = 1, #v do coverage[#coverage + 1] = v[index] end
		end
	end
	if columns ~= 6400 then fail("accepted R6 owner column population differs") end
	return {groups = groups, coverage = coverage,
		candidates = {cultural = cultural, decorations = decorations},
		settlement = loaded.settlement_fixture.scan_horizontal_owner(owner_x, owner_z,
			cultural, decorations)}
end

local function accepted_owner_scan(repo, seed, owner_x, owner_z)
	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	return scan_accepted_loaded(offline.new_evidence(seed, true), owner_x, owner_z)
end

local function settlement_decisions(settlement, rows, runs)
	return graph({cultural = settlement.cultural,
		decorations = settlement.decorations, rejections = settlement.rejections,
		witnesses = settlement.witnesses, apex_overlaps = settlement.apex_overlaps,
		direct_rows = rows, direct_runs = runs})
end

function module.canonical_graph_nul_kat()
	-- Exact key forms emitted by r6_settlement.scan_horizontal_owner().  This
	-- catches the integration failure before constructing a production runtime.
	local aggregate_key = "runeslate\0ordinary"
	local rejection_key = "cultural\0runeslate\0wrong_support"
	local encoded = settlement_decisions({
		cultural = {[aggregate_key] = {accepted = 1, reserved = 225}},
		decorations = {}, rejections = {[rejection_key] = 1},
		witnesses = {[aggregate_key] = {zone_id = "front_shattered_line",
			x = -32, y = 23, z = -32}}, apex_overlaps = 0,
	}, {{-32, 23, -32, 1000, 0, 1, 34, 1, 0, 0}},
		{{-32, -32, 23, 23, 9, 34, 16, 10, 0}})
	local aggregate_scalar = "s" .. tostring(#aggregate_key) .. ":" .. aggregate_key
	local rejection_scalar = "s" .. tostring(#rejection_key) .. ":" .. rejection_key
	if not encoded:find(aggregate_scalar, 1, true) or
			not encoded:find(rejection_scalar, 1, true) then
		fail("canonical graph lost a production NUL-delimited key")
	end
	local distinct = settlement_decisions({cultural = {}, decorations = {},
		rejections = {[rejection_key .. "x"] = 1}, witnesses = {}, apex_overlaps = 0},
		{}, {})
	if encoded == distinct then fail("canonical graph key framing is ambiguous") end
	return true
end

local function stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
	local normalized, substitutions = normalize_rows(runtime_fixture, binding,
		direct.settlement.direct_rows)
	local normalized_runs = normalize_runs(runtime_fixture, binding,
		direct.settlement.direct_runs)
	if graph(direct.groups) ~= graph(accepted.groups) or
			graph(direct.coverage) ~= graph(accepted.coverage) then
		fail("Stage-B planner candidate projection differs")
	end
	if graph(direct.candidates) ~= graph(accepted.candidates) then
		fail("Stage-B planner candidate coordinates differ")
	end
	local production = graph({groups = direct.groups, coverage = direct.coverage,
		candidates = direct.candidates,
		settlement = settlement_decisions(direct.settlement, normalized,
			normalized_runs)})
	local predecessor = graph({groups = accepted.groups, coverage = accepted.coverage,
		candidates = accepted.candidates,
		settlement = settlement_decisions(accepted.settlement,
			accepted.settlement.direct_rows, accepted.settlement.direct_runs)})
	if production ~= predecessor then
		fail("Stage-B normalized placement decisions differ from accepted R6")
	end
	return {bytes = production, accepted_bytes = predecessor,
		substitutions = substitutions}
end

local function probe_rejections(runtime_fixture)
	local evidence, built = runtime_fixture.built.evidence, runtime_fixture.built
	local catalog = runtime_fixture.catalog.p9g_sources()
	local ordinary_index, shore_index
	for index = 1, #catalog do
		if catalog[index].shore_predicate == "none" and not ordinary_index then
			ordinary_index = index
	elseif catalog[index].shore_predicate ~= "none" and not shore_index then
			shore_index = index
	end
	end
	if not ordinary_index or not shore_index then fail("P9G probe catalog classes differ") end
	local function context(index, mode)
		local row = catalog[index]
		local zone, host = row.zones[1], row.hosts[1]
		local support_name = host.support
		local support_ref
		for ref = 1, #built.content.production.content_names do
			if built.content.production.content_names[ref] == support_name then
				support_ref = ref break
			end
		end
		if not support_ref then fail("P9G probe support ref is absent") end
		local support_cid = built.content.production.content_cids[support_ref]
		local air_cid = runtime_fixture.cid_by_name.air
		local ignore_cid = built.content.production.ignore_cid
		return {
			inside_owner = function() return mode ~= "clipped_owner" end,
			original_at = function()
				return mode == "content_ignore" and ignore_cid or air_cid, 0
			end,
			settled_at = function(_, y)
				if mode == "insufficient_clearance" and y == 11 then
					return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
				elseif mode == "r6_occupancy" and y == 11 then
					return air_cid, 0, 1, 0, 0, 0, 0
				elseif y == 11 then
					return air_cid, 0, 0, 0, 0, 0, 0
				end
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end,
			production_content = function(name)
				for ref = 1, #built.content.production.content_names do
					if built.content.production.content_names[ref] == name then
						return ref, built.content.production.content_cids[ref]
					end
				end
				return nil, nil
			end,
			analytic_p7_ref = function()
				return mode == "wrong_support" and support_ref + 1 or support_ref
			end,
			analytic_p7_tuple = function()
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end,
			exclusion_at = function()
				if mode == "fixed_or_protected" or mode == "route_or_water" then
					return mode
				end
				return nil
			end,
			housing_excluded_at = function() return mode == "housing_exclusion" end,
			column_values_at = function(x, z)
				local actual_zone = mode == "wrong_zone" and "not_a_zone" or zone
				local biome = mode == "wrong_biome" and "not_a_biome" or host.biome
				local water = "land"
				if index == shore_index and mode ~= "wrong_shore" and
						(x ~= 10 or z ~= 10) then
					water = row.shore_water_classes[1]
				end
				return water, 1, actual_zone, biome, "human", 10, nil
			end,
		}
	end
	local reasons = {"clipped_owner", "fixed_or_protected", "route_or_water",
		"housing_exclusion", "content_ignore", "wrong_zone", "wrong_biome",
		"wrong_support", "insufficient_clearance", "r6_occupancy"}
	for index = 1, #reasons do
		local reason = evidence.probe_p9g_reason(context(ordinary_index, reasons[index]),
			ordinary_index, 10, 11, 10)
		if reason ~= reasons[index] then
			fail("P9G rejection probe differs for " .. reasons[index] .. ": " .. reason)
		end
	end
	local shore_reason = evidence.probe_p9g_reason(context(shore_index, "wrong_shore"),
		shore_index, 10, 11, 10)
	if shore_reason ~= "wrong_shore" then fail("P9G wrong-shore probe differs") end
	local accepted = evidence.probe_p9g_reason(context(ordinary_index, "accepted"),
		ordinary_index, 10, 11, 10)
	if accepted ~= "accepted" then fail("P9G accepted probe differs") end
	return true
end

local function owner_minimum(value)
	return -30912 + math.floor((value + 30912) / 80) * 80
end

local function validate_vm_commit(result, snapshot, label)
	if type(result) ~= "string" or not result:find("^applied_") then
		fail(label .. " did not commit one transaction")
	end
	local suffix = result:match("^applied_([cplq]+)$")
	if not suffix then fail(label .. " result vocabulary differs") end
	local calls = snapshot.calls
	local function changed(letter) return suffix:find(letter, 1, true) ~= nil end
	for _, name in ipairs({"get_emerged_area", "get_data", "get_param2_data"}) do
		if calls[name] ~= 1 then fail(label .. " call count differs for " .. name) end
	end
	if calls.get_light_data ~= (changed("l") and 2 or 0) or
			calls.set_data ~= (changed("c") and 1 or 0) or
			calls.set_param2_data ~= (changed("p") and 1 or 0) or
			calls.calc_lighting ~= (changed("l") and 1 or 0) or
			calls.set_light_data ~= (changed("l") and 1 or 0) or
			calls.update_liquids ~= (changed("q") and 1 or 0) then
		fail(label .. " conditional VM call counts differ")
	end
	if (changed("l") and (calls.set_lighting < 1 or calls.set_lighting > 6401)) or
			(not changed("l") and calls.set_lighting ~= 0) then
		fail(label .. " lighting seed-call bound differs")
	end
	if snapshot.inactive_tail_unchanged ~= true then
		fail(label .. " retained inactive tail changed")
	end
	return suffix
end

local function compare_vm_arrays(left, right, label)
	for _, field in ipairs({"data", "param2", "light"}) do
		if #left[field] ~= #right[field] then fail(label .. " " .. field .. " shape differs") end
		for index = 1, #left[field] do
			if left[field][index] ~= right[field][index] then
				fail(label .. " " .. field .. " differs at VM index " .. tostring(index))
			end
		end
	end
end

local function snapshot_index(snapshot, x, y, z)
	if x < snapshot.emin.x or x > snapshot.emax.x or
			y < snapshot.emin.y or y > snapshot.emax.y or
			z < snapshot.emin.z or z > snapshot.emax.z then
		return nil
	end
	local axis_x = snapshot.emax.x - snapshot.emin.x + 1
	local axis_y = snapshot.emax.y - snapshot.emin.y + 1
	return (z - snapshot.emin.z) * axis_x * axis_y +
		(y - snapshot.emin.y) * axis_x + (x - snapshot.emin.x) + 1
end

local function actual_run_bytes(values, count, drop_opcode, normalize)
	dense(values, "actual settlement run values")
	integer(count, 0, MAX_SAFE, "actual settlement run count")
	if #values ~= count * 9 then fail("actual settlement run shape differs") end
	local output = {"schema\tgrug_wp40_r7_actual_run_projection_v1\n"}
	local dropped = 0
	for run = 1, count do
		local base, row = (run - 1) * 9, {}
		for field = 1, 9 do
			row[field] = integer(values[base + field], -MAX_SAFE, MAX_SAFE,
				"actual settlement run field")
		end
		if normalize then row = normalize(row) end
		if drop_opcode and row[4] == drop_opcode then
			dropped = dropped + 1
		else
			local fields = {}
			for field = 1, 9 do fields[field] = tostring(row[field]) end
			output[#output + 1] = "run\t" .. table.concat(fields, "\t") .. "\n"
		end
	end
	return table.concat(output), dropped
end

local PRIVATE_CAPTURE_FIELDS = {
	schema = true, min_x = true, min_y = true, min_z = true,
	max_x = true, max_y = true, max_z = true, tuple_order = true,
	tuple_stride = true, tuple_count = true, tuple_values = true,
	tuple_sha256 = true, run_stride = true, run_count = true,
	run_values = true, run_sha256 = true, run_checksum_a = true,
	run_checksum_b = true, ledger = true, ledger_sha256 = true,
	metrics = true,
}

local PRIVATE_CAPTURE_METRIC_FIELDS = {
	schema = true, tuple_count = true, tuple_scalar_count = true,
	tuple_encoded_bytes = true, run_count = true, run_scalar_count = true,
	run_encoded_bytes = true, run_checksum_a = true, run_checksum_b = true,
	ledger_encoded_bytes = true,
}

local function private_tuple_header(capture)
	return table.concat({
		"schema\tgrug_wp40_r7_private_tuple_tsv_v1\n",
		"bounds\t", string.format("%.0f", capture.min_x), "\t",
		string.format("%.0f", capture.min_y), "\t",
		string.format("%.0f", capture.min_z), "\t",
		string.format("%.0f", capture.max_x), "\t",
		string.format("%.0f", capture.max_y), "\t",
		string.format("%.0f", capture.max_z), "\n",
		"order\tz_outer_x_middle_y_inner\n",
		"fields\tdata\tparam2\toccupancy\topcode\tfeature\tinterface\taux\n",
	})
end

local function private_run_header()
	return table.concat({
		"schema\tgrug_wp40_r7_private_run_tsv_v1\n",
		"fields\tymin\tymax\tclass\topcode\tkind\tpolicy\tfeature\tinterface\taux\n",
	})
end

local function validate_private_capture(repo, capture, minp, maxp, expect_ledger,
		label)
	exact_fields(capture, PRIVATE_CAPTURE_FIELDS, label .. " private capture")
	if capture.schema ~= "grug_wp40_r7_private_buffer_capture_v1" or
			capture.tuple_order ~= "z_outer_x_middle_y_inner" or
			capture.tuple_stride ~= 7 or capture.run_stride ~= 9 then
		fail(label .. " private capture identity differs")
	end
	for _, axis in ipairs({"x", "y", "z"}) do
		if capture["min_" .. axis] ~= minp[axis] or
				capture["max_" .. axis] ~= maxp[axis] then
			fail(label .. " private capture bounds differ")
		end
	end
	local tuple_count = (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) *
		(maxp.z - minp.z + 1)
	integer(capture.tuple_count, 1, MAX_SAFE, label .. " tuple count")
	dense(capture.tuple_values, label .. " tuple values")
	if capture.tuple_count ~= tuple_count or #capture.tuple_values ~= tuple_count * 7 then
		fail(label .. " private tuple shape differs")
	end
	digest(capture.tuple_sha256, label .. " tuple digest")
	integer(capture.run_count, 0, MAX_SAFE, label .. " run count")
	dense(capture.run_values, label .. " run values")
	if #capture.run_values ~= capture.run_count * 9 then
		fail(label .. " private run shape differs")
	end
	digest(capture.run_sha256, label .. " run digest")
	digest(capture.ledger_sha256, label .. " ledger digest")
	integer(capture.run_checksum_a, 0, 6700416, label .. " run checksum A")
	integer(capture.run_checksum_b, 0, 15485862, label .. " run checksum B")

	local stream = sha_stream(repo)
	local tuple_hasher, tuple_bytes = stream.new(), 0
	local function tuple_update(bytes)
		tuple_hasher.update(bytes); tuple_bytes = tuple_bytes + #bytes
	end
	tuple_update(private_tuple_header(capture))
	local rows = {}
	for tuple = 1, capture.tuple_count do
		local base, fields = (tuple - 1) * 7, {}
		for field = 1, 7 do
			local value = integer(capture.tuple_values[base + field], -MAX_SAFE,
				MAX_SAFE, label .. " private tuple scalar")
			fields[field] = string.format("%.0f", value)
		end
		rows[#rows + 1] = "tuple\t" .. table.concat(fields, "\t") .. "\n"
		if #rows == 4096 then tuple_update(table.concat(rows)); rows = {} end
	end
	if #rows > 0 then tuple_update(table.concat(rows)) end
	if tuple_hasher.final_hex() ~= capture.tuple_sha256 then
		fail(label .. " private tuple digest differs")
	end

	local run_hasher, run_bytes = stream.new(), 0
	local function run_update(bytes)
		run_hasher.update(bytes); run_bytes = run_bytes + #bytes
	end
	run_update(private_run_header())
	local checksum_a, checksum_b = 1, 7
	for run = 1, capture.run_count do
		local base, fields = (run - 1) * 9, {}
		for field = 1, 9 do
			local value = integer(capture.run_values[base + field], -MAX_SAFE,
				MAX_SAFE, label .. " private run scalar")
			fields[field] = string.format("%.0f", value)
			checksum_a = (checksum_a * 131 + (value + 31012)) % 6700417
			checksum_b = (checksum_b * 257 + (value + 31012)) % 15485863
		end
		run_update("run\t" .. table.concat(fields, "\t") .. "\n")
	end
	if run_hasher.final_hex() ~= capture.run_sha256 or
			checksum_a ~= capture.run_checksum_a or
			checksum_b ~= capture.run_checksum_b then
		fail(label .. " private run authority differs")
	end

	local ledger_bytes
	if expect_ledger then
		if type(capture.ledger) ~= "table" or type(capture.ledger.p9g) ~= "table" then
			fail(label .. " private successor ledger is absent")
		end
		validate_ledger(capture.ledger.p9g)
		ledger_bytes = "schema\tgrug_wp40_r7_private_ledger_graph_v1\nledger\t" ..
			graph(capture.ledger) .. "\n"
	else
		if capture.ledger ~= false then fail(label .. " private direct ledger differs") end
		ledger_bytes = "schema\tgrug_wp40_r7_private_ledger_graph_v1\nnone\n"
	end
	if sha256(repo, ledger_bytes) ~= capture.ledger_sha256 then
		fail(label .. " private ledger digest differs")
	end

	local metrics = exact_fields(capture.metrics, PRIVATE_CAPTURE_METRIC_FIELDS,
		label .. " private capture metrics")
	if metrics.schema ~= "grug_wp40_r7_private_buffer_capture_metrics_v1" or
			metrics.tuple_count ~= capture.tuple_count or
			metrics.tuple_scalar_count ~= #capture.tuple_values or
			metrics.tuple_encoded_bytes ~= tuple_bytes or
			metrics.run_count ~= capture.run_count or
			metrics.run_scalar_count ~= #capture.run_values or
			metrics.run_encoded_bytes ~= run_bytes or
			metrics.run_checksum_a ~= capture.run_checksum_a or
			metrics.run_checksum_b ~= capture.run_checksum_b or
			metrics.ledger_encoded_bytes ~= #ledger_bytes then
		fail(label .. " private capture metrics differ")
	end
	return capture
end

local function capture_tuple_base(capture, x, y, z)
	if x < capture.min_x or x > capture.max_x or y < capture.min_y or
			y > capture.max_y or z < capture.min_z or z > capture.max_z then
		return nil
	end
	local x_count, y_count = capture.max_x - capture.min_x + 1,
		capture.max_y - capture.min_y + 1
	local tuple = (z - capture.min_z) * x_count * y_count +
		(x - capture.min_x) * y_count + (y - capture.min_y)
	return tuple * 7
end

local function same_capture_runs(left, right, label)
	if left.run_count ~= right.run_count or #left.run_values ~= #right.run_values then
		fail(label .. " private run population differs")
	end
	for index = 1, #left.run_values do
		if left.run_values[index] ~= right.run_values[index] then
			fail(label .. " private run scalar differs at " .. tostring(index))
		end
	end
end

local function fixture_runs_match_capture(fixture, capture, label)
	local values, count = fixture.run_values()
	if count ~= capture.run_count or #values ~= #capture.run_values then
		fail(label .. " capture/fixture run population differs")
	end
	for index = 1, #values do
		if values[index] ~= capture.run_values[index] then
			fail(label .. " capture/fixture run scalar differs")
		end
	end
end

local function normalize_actual_run(runtime_fixture, binding, source)
	local row = {}
	for field = 1, 9 do row[field] = source[field] end
	local names = runtime_fixture.built.content.production.content_names
	local ref = math.floor(source[9] / 256) + 1
	local param2 = source[9] % 256
	local name, target = names[ref], names[ref] and binding.by_name[names[ref]]
	if not target and name and binding.cultural[name] then
		if source[4] ~= 34 then
			fail("full-VM Cultural run substitution escaped opcode 34")
		end
		target = assert(binding.by_name["grug_nodes:bone_pile"])
	elseif not target then
		fail("full-VM Direct-83 run has no accepted content mapping")
	end
	row[9] = (target.ref - 1) * 256 + param2
	return row
end

local function normalize_direct_snapshot(runtime_fixture, binding, direct_scan,
		accepted_scan, accepted_loaded, snapshot)
	local accepted_rows, cultural_positions = {}, {}
	for index = 1, #accepted_scan.settlement.direct_rows do
		local row = accepted_scan.settlement.direct_rows[index]
		accepted_rows[row_key(row)] = row
	end
	local bone = assert(binding.by_name["grug_nodes:bone_pile"])
	for index = 1, #direct_scan.settlement.direct_rows do
		local row = direct_scan.settlement.direct_rows[index]
		local name = runtime_fixture.name_by_cid[row[4]]
		if name and binding.cultural[name] then
			local accepted = accepted_rows[row_key(row)]
			if row[7] ~= 34 or not accepted or accepted[7] ~= 34 or
					accepted[8] ~= row[8] or accepted[4] ~= bone.cid then
				fail("full-VM Cultural coordinate/opcode/feature mapping differs")
			end
			cultural_positions[row_key(row)] = true
		end
	end
	local axis_x = snapshot.emax.x - snapshot.emin.x + 1
	local axis_y = snapshot.emax.y - snapshot.emin.y + 1
	for index = 1, #snapshot.data do
		local offset = index - 1
		local z_offset = math.floor(offset / (axis_x * axis_y))
		offset = offset - z_offset * axis_x * axis_y
		local y_offset = math.floor(offset / axis_x)
		local x_offset = offset - y_offset * axis_x
		local key = tostring(snapshot.emin.x + x_offset) .. "/" ..
			tostring(snapshot.emin.y + y_offset) .. "/" ..
			tostring(snapshot.emin.z + z_offset)
		local cid = snapshot.data[index]
		local name = runtime_fixture.name_by_cid[cid]
		local target
		if name and binding.cultural[name] then
			if not cultural_positions[key] then
				fail("full-VM Cultural CID escaped an exact Cultural placement")
			end
			target = bone.cid
		elseif name == "ignore" then
			target = accepted_loaded.content_contract.ignore_cid
		elseif name then
			target = accepted_loaded.cid_by_name[name]
			if binding.by_name[name] and target ~= binding.by_name[name].cid then
				fail("accepted full-VM content CID differs from artifact")
			end
		end
		if target == nil then
			fail("full-VM Direct-83 CID has no accepted mapping: " .. tostring(name))
		end
		snapshot.data[index] = target
	end
end

local function compare_stage_a_captures(repo, successor, direct)
	if successor.tuple_count ~= direct.tuple_count or
			private_tuple_header(successor) ~= private_tuple_header(direct) then
		fail("Stage-A private capture shape differs")
	end
	local ledger = validate_ledger(successor.ledger.p9g)
	local accepted_by_base, accepted = {}, 0
	for index = 1, #ledger.operations do
		local operation = ledger.operations[index]
		if operation.accepted then
			local base = capture_tuple_base(successor, operation.root_x,
				operation.root_y, operation.root_z)
			if base == nil or accepted_by_base[base] then
				fail("Stage-A accepted P9G capture root differs")
			end
			accepted_by_base[base] = operation
			accepted = accepted + 1
			local finals = {operation.final_cid, operation.final_param2,
				operation.final_occupancy, operation.final_opcode,
				operation.final_feature, operation.final_interface, operation.final_aux}
			for field = 1, 7 do
				if successor.tuple_values[base + field] ~= finals[field] then
					fail("Stage-A private final tuple differs at accepted root")
				end
			end
		end
	end
	local prior_fields = {"prior_cid", "prior_param2", "prior_occupancy",
		"prior_opcode", "prior_feature", "prior_interface", "prior_aux"}
	for tuple = 1, successor.tuple_count do
		local base = (tuple - 1) * 7
		local operation = accepted_by_base[base]
		for field = 1, 7 do
			local restored = operation and operation[prior_fields[field]] or
				successor.tuple_values[base + field]
			if restored ~= direct.tuple_values[base + field] then
				fail("Stage-A restored private tuple differs at tuple " ..
					tostring(tuple) .. " field " .. tostring(field))
			end
		end
	end
	local restored_runs, dropped = actual_run_bytes(successor.run_values,
		successor.run_count, 35)
	local direct_runs = actual_run_bytes(direct.run_values, direct.run_count)
	if dropped ~= accepted or restored_runs ~= direct_runs then
		fail("Stage-A restored private production runs differ")
	end
	return {accepted = accepted, tuple_sha256 = direct.tuple_sha256,
		run_sha256 = direct.run_sha256,
		restored_run_projection_sha256 = sha256(repo, restored_runs)}
end

local function accepted_content_target(runtime_fixture, binding, accepted_loaded,
		name, opcode, accepted_values, accepted_base)
	local target_name = name
	if name and binding.cultural[name] then
		if opcode ~= 34 or accepted_values[accepted_base + 4] ~= 34 or
				accepted_values[accepted_base + 5] == nil then
			fail("Stage-B private Cultural substitution escaped opcode 34")
		end
		target_name = "grug_nodes:bone_pile"
	end
	local cid
	if target_name == "air" then cid = 0
	elseif target_name == "ignore" then cid = accepted_loaded.content_contract.ignore_cid
	else cid = accepted_loaded.cid_by_name[target_name] end
	if cid == nil then
		fail("Stage-B private CID has no accepted mapping: " .. tostring(name))
	end
	if binding.by_name[target_name] and
			cid ~= binding.by_name[target_name].cid then
		fail("Stage-B private accepted CID differs from artifact")
	end
	return target_name, cid
end

local function compare_stage_b_captures(repo, runtime_fixture, binding,
		accepted_loaded, direct, accepted)
	if direct.tuple_count ~= accepted.tuple_count or
			private_tuple_header(direct) ~= private_tuple_header(accepted) then
		fail("Stage-B private capture shape differs")
	end
	local stream, tuple_hasher, tuple_bytes = sha_stream(repo), nil, 0
	tuple_hasher = stream.new()
	local function tuple_update(bytes)
		tuple_hasher.update(bytes); tuple_bytes = tuple_bytes + #bytes
	end
	tuple_update(private_tuple_header(accepted))
	local rows, substitutions = {}, 0
	local production_names = runtime_fixture.built.content.production.content_names
	for tuple = 1, direct.tuple_count do
		local base, normalized = (tuple - 1) * 7, {}
		for field = 1, 7 do normalized[field] = direct.tuple_values[base + field] end
		local name = runtime_fixture.name_by_cid[normalized[1]]
		local target_name, target_cid = accepted_content_target(runtime_fixture,
			binding, accepted_loaded, name, normalized[4], accepted.tuple_values, base)
		if binding.cultural[name] then
			if accepted.tuple_values[base + 5] ~= normalized[5] then
				fail("Stage-B private Cultural feature differs")
			end
			substitutions = substitutions + 1
		end
		normalized[1] = target_cid
		if normalized[7] ~= 0 or target_name ~= "air" then
			local ref = math.floor(normalized[7] / 256) + 1
			local param2 = normalized[7] % 256
			local aux_name = production_names[ref]
			if not aux_name then
				fail("Stage-B private aux ref escaped production content")
			end
			local aux_target = aux_name
			if binding.cultural[aux_name] then
				if normalized[4] ~= 34 then
					fail("Stage-B private Cultural aux escaped opcode 34")
				end
				aux_target = "grug_nodes:bone_pile"
			end
			local accepted_ref = accepted_loaded.ref_by_name[aux_target]
			if not accepted_ref then fail("Stage-B private aux has no accepted ref") end
			normalized[7] = (accepted_ref - 1) * 256 + param2
		end
		local fields = {}
		for field = 1, 7 do
			if normalized[field] ~= accepted.tuple_values[base + field] then
				fail("Stage-B normalized private tuple differs at tuple " ..
					tostring(tuple) .. " field " .. tostring(field))
			end
			fields[field] = string.format("%.0f", normalized[field])
		end
		rows[#rows + 1] = "tuple\t" .. table.concat(fields, "\t") .. "\n"
		if #rows == 4096 then tuple_update(table.concat(rows)); rows = {} end
	end
	if #rows > 0 then tuple_update(table.concat(rows)) end
	local normalized_tuple_sha = tuple_hasher.final_hex()
	if normalized_tuple_sha ~= accepted.tuple_sha256 or
			tuple_bytes ~= accepted.metrics.tuple_encoded_bytes then
		fail("Stage-B normalized private tuple digest differs")
	end

	if direct.run_count ~= accepted.run_count then
		fail("Stage-B private run population differs")
	end
	local run_hasher, run_bytes = stream.new(), 0
	local function run_update(bytes)
		run_hasher.update(bytes); run_bytes = run_bytes + #bytes
	end
	run_update(private_run_header())
	for run = 1, direct.run_count do
		local base, row = (run - 1) * 9, {}
		for field = 1, 9 do row[field] = direct.run_values[base + field] end
		if row[9] == 0 then
			local structural = true
			for field = 1, 8 do
				if row[field] ~= accepted.run_values[base + field] then structural = false end
			end
			if accepted.run_values[base + 9] ~= 0 then structural = false end
			if not structural then
				row = normalize_actual_run(runtime_fixture, binding, row)
			end
		else
			row = normalize_actual_run(runtime_fixture, binding, row)
		end
		local fields = {}
		for field = 1, 9 do
			if row[field] ~= accepted.run_values[base + field] then
				fail("Stage-B normalized private run differs at run " ..
					tostring(run) .. " field " .. tostring(field))
			end
			fields[field] = string.format("%.0f", row[field])
		end
		run_update("run\t" .. table.concat(fields, "\t") .. "\n")
	end
	local normalized_run_sha = run_hasher.final_hex()
	if normalized_run_sha ~= accepted.run_sha256 or
			run_bytes ~= accepted.metrics.run_encoded_bytes then
		fail("Stage-B normalized private run digest differs")
	end
	return {substitutions = substitutions, tuple_sha256 = normalized_tuple_sha,
		run_sha256 = normalized_run_sha}
end

local function sorted_operations(operations)
	table.sort(operations, function(left, right)
		if left.root_z ~= right.root_z then return left.root_z < right.root_z end
		if left.root_x ~= right.root_x then return left.root_x < right.root_x end
		if left.root_y ~= right.root_y then return left.root_y < right.root_y end
		return less_bytes(left.source_id, right.source_id)
	end)
	return operations
end

local function multi_y_owner_kat(repo, runtime_fixture, horizontal, heights,
		first_capture)
	local bands, ordered_bands = {}, {}
	for index = 1, #heights do
		local band = owner_minimum(heights[index] + 1)
		if not bands[band] then bands[band] = true; ordered_bands[#ordered_bands + 1] = band end
	end
	table.sort(ordered_bands)
	if #ordered_bands < 2 then
		fail("multi-y KAT owner surfaces do not span two vertical owners")
	end
	local horizontal_ledger = validate_ledger(horizontal.settlement.p9g)
	local active_bands, active_count = {}, 0
	for index = 1, #horizontal_ledger.operations do
		local band = owner_minimum(horizontal_ledger.operations[index].root_y)
		if not active_bands[band] then active_bands[band] = true; active_count = active_count + 1 end
	end
	if active_count < 2 then
		fail("multi-y KAT lacks two active P9G vertical owners")
	end
	local aggregate = {eligible = 0, planned = 0, accepted = 0,
		rejections = {}, groups = {}, populations = {}, operations = {}, roots = {}}
	for index = 1, #P9G_REASONS do aggregate.rejections[P9G_REASONS[index]] = 0 end
	local consumed = {}
	local function consume(capture, band)
		if consumed[band] then fail("multi-y KAT repeated one vertical owner") end
		consumed[band] = true
		local ledger = validate_ledger(capture.ledger.p9g)
		if ledger.manifest_sha256 ~= horizontal_ledger.manifest_sha256 or
				ledger.rejections.clipped_owner ~= 0 then
			fail("multi-y KAT manifest/artificial clipping differs")
		end
		for _, field in ipairs({"eligible", "planned", "accepted"}) do
			aggregate[field] = aggregate[field] + ledger[field]
		end
		for index = 1, #P9G_REASONS do
			local reason = P9G_REASONS[index]
			aggregate.rejections[reason] = aggregate.rejections[reason] +
				ledger.rejections[reason]
		end
		for index = 1, #ledger.groups do
			local row = ledger.groups[index]
			local key = table.concat({row.source_id, row.cell_x, row.cell_z}, "\0")
			local target = aggregate.groups[key]
			if not target then
				target = {source_id = row.source_id, cell_x = row.cell_x,
					cell_z = row.cell_z, eligible = 0, budget = 0, accepted = 0,
					rejections = {}}
				for reason = 1, #P9G_REASONS do
					target.rejections[P9G_REASONS[reason]] = 0
				end
				aggregate.groups[key] = target
			end
			for _, field in ipairs({"eligible", "budget", "accepted"}) do
				target[field] = target[field] + row[field]
			end
			for reason = 1, #P9G_REASONS do
				local name = P9G_REASONS[reason]
				target.rejections[name] = target.rejections[name] + row.rejections[name]
			end
		end
		for index = 1, #ledger.populations do
			local row = ledger.populations[index]
			local key = population_key(row.source_id, row.zone_id, row.biome,
				row.faction, row.bracket)
			local target = aggregate.populations[key]
			if not target then
				target = {source_id = row.source_id, zone_id = row.zone_id,
					biome = row.biome, faction = row.faction, bracket = row.bracket,
					eligible = 0, budget = 0, accepted = 0, rejections = {}}
				for reason = 1, #P9G_REASONS do
					target.rejections[P9G_REASONS[reason]] = 0
				end
				aggregate.populations[key] = target
			end
			for _, field in ipairs({"eligible", "budget", "accepted"}) do
				target[field] = target[field] + row[field]
			end
			for reason = 1, #P9G_REASONS do
				local name = P9G_REASONS[reason]
				target.rejections[name] = target.rejections[name] + row.rejections[name]
			end
		end
		for index = 1, #ledger.operations do
			local operation = ledger.operations[index]
			if owner_minimum(operation.root_y) ~= band then
				fail("multi-y KAT operation escaped its vertical owner")
			end
			local root = table.concat({operation.root_x, operation.root_y,
				operation.root_z, operation.source_id}, "/")
			if aggregate.roots[root] then fail("multi-y KAT operation settled twice") end
			aggregate.roots[root] = true
			aggregate.operations[#aggregate.operations + 1] = operation
		end
	end

	local first_band = first_capture.min_y
	if not bands[first_band] then fail("full-VM capture band escaped surface bands") end
	consume(first_capture, first_band)
	for index = 1, #ordered_bands do
		local band = ordered_bands[index]
		if not consumed[band] then
			local minp = {x = horizontal.owner_x, y = band, z = horizontal.owner_z}
			local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
			local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
			local plan, generation = runtime_fixture.built.session.plan_slice(minp, maxp)
			runtime_fixture.built.settlement_fixture.arm_private_capture()
			local result = runtime_fixture.built.writer.apply(vm, minp, maxp,
				plan, generation)
			local capture = runtime_fixture.built.settlement_fixture.take_private_capture()
			validate_vm_commit(result, observer.snapshot(),
				"multi-y R7 production writer")
			validate_private_capture(repo, capture, minp, maxp, true,
				"multi-y R7 production writer")
			fixture_runs_match_capture(runtime_fixture.built.settlement_fixture, capture,
				"multi-y R7 production writer")
			consume(capture, band)
			capture = nil
			collectgarbage("collect")
		end
	end
	for index = 1, #ordered_bands do
		if not consumed[ordered_bands[index]] then fail("multi-y KAT missed a vertical owner") end
	end
	if aggregate.eligible ~= horizontal_ledger.eligible or
			aggregate.planned ~= horizontal_ledger.planned or
			aggregate.accepted ~= horizontal_ledger.accepted or
			graph(aggregate.rejections) ~= graph(horizontal_ledger.rejections) then
		fail("multi-y KAT E/B/accepted/reasons union differs")
	end
	local function compare_aggregate(expected, actual, key_fn, label)
		local seen = {}
		for index = 1, #expected do
			local key = key_fn(expected[index])
			if seen[key] or not actual[key] or graph(expected[index]) ~= graph(actual[key]) then
				fail("multi-y KAT " .. label .. " union differs")
			end
			seen[key] = true
		end
		for key in pairs(actual) do
			if not seen[key] then fail("multi-y KAT extra " .. label .. " union row") end
		end
	end
	compare_aggregate(horizontal_ledger.groups, aggregate.groups, function(row)
		return table.concat({row.source_id, row.cell_x, row.cell_z}, "\0")
	end, "group")
	compare_aggregate(horizontal_ledger.populations, aggregate.populations, function(row)
		return population_key(row.source_id, row.zone_id, row.biome, row.faction,
			row.bracket)
	end, "population")
	if graph(sorted_operations(aggregate.operations)) ~=
			graph(horizontal_ledger.operations) then
		fail("multi-y KAT operation union differs")
	end
	return {band_count = #ordered_bands, eligible = aggregate.eligible,
		planned = aggregate.planned, accepted = aggregate.accepted}
end

local function full_vm_integration(repo, runtime_fixture, successor, direct_scan,
		accepted_scan, binding, seed)
	local root_y
	for index = 1, #successor.settlement.p9g.operations do
		local operation = successor.settlement.p9g.operations[index]
		if operation.accepted then root_y = operation.root_y break end
	end
	if not root_y then fail("full VM KAT lacks an accepted P9G root") end
	local minp = {x = successor.owner_x, y = owner_minimum(root_y),
		z = successor.owner_z}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local heights = {}
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			heights[#heights + 1] = runtime_fixture.built.zones_session.terrain_height_at(x, z)
		end
	end
	if #heights ~= 6400 then fail("full VM heightmap population differs") end
	runtime_fixture.set_heightmap(heights)
	local successor_snapshot, successor_result, successor_capture
	local before = runtime_fixture.built.session.metrics()
	do
		local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
		if type(vm) ~= "table" or type(observer) ~= "table" or
				type(observer.snapshot) ~= "function" then
			fail("full VM fixture seam differs")
		end
		local plan, generation = runtime_fixture.built.session.plan_slice(minp, maxp)
		runtime_fixture.built.settlement_fixture.arm_private_capture()
		successor_result = runtime_fixture.built.writer.apply(vm, minp, maxp,
			plan, generation)
		successor_capture = runtime_fixture.built.settlement_fixture.take_private_capture()
		successor_snapshot = observer.snapshot()
		validate_vm_commit(successor_result, successor_snapshot, "R7 production writer")
	end
	validate_private_capture(repo, successor_capture, minp, maxp, true,
		"R7 production writer")
	fixture_runs_match_capture(runtime_fixture.built.settlement_fixture,
		successor_capture, "R7 production writer")
	local metrics = runtime_fixture.built.session.metrics()
	if metrics.settlement.apply_calls - before.settlement.apply_calls ~= 1 or
			metrics.settlement.replay_count - before.settlement.replay_count ~= 1 or
			metrics.p9g.settle_calls - before.p9g.settle_calls ~= 1 or
			metrics.p9g.replay_calls - before.p9g.replay_calls ~= 1 or
			metrics.p9g.accepted - before.p9g.accepted < 1 then
		fail("production writer/replay/P9G metrics differ")
	end
	local direct_snapshot, direct_result, direct_capture
	do
		local vm, _, observer = runtime_fixture.new_vm(minp, maxp)
		local plan, generation = runtime_fixture.built.direct_session.plan_slice(minp, maxp)
		runtime_fixture.built.direct_fixture.arm_private_capture()
		direct_result = runtime_fixture.built.direct_session.apply_fixture(vm, minp, maxp,
			plan, generation)
		direct_capture = runtime_fixture.built.direct_fixture.take_private_capture()
		direct_snapshot = observer.snapshot()
		validate_vm_commit(direct_result, direct_snapshot, "independent Direct-83 writer")
	end
	validate_private_capture(repo, direct_capture, minp, maxp, false,
		"independent Direct-83 writer")
	fixture_runs_match_capture(runtime_fixture.built.direct_fixture, direct_capture,
		"independent Direct-83 writer")
	local stage_a_capture = compare_stage_a_captures(repo, successor_capture,
		direct_capture)

	local restored_count = 0
	for index = 1, #successor_capture.ledger.p9g.operations do
		local operation = successor_capture.ledger.p9g.operations[index]
		if operation.accepted then
			local vm_index = snapshot_index(successor_snapshot, operation.root_x,
				operation.root_y, operation.root_z)
			if not vm_index or operation.root_x < minp.x or operation.root_x > maxp.x or
					operation.root_y < minp.y or operation.root_y > maxp.y or
					operation.root_z < minp.z or operation.root_z > maxp.z then
				fail("accepted integration P9G root escaped the owner VM")
			end
			if successor_snapshot.data[vm_index] ~= operation.final_cid or
					successor_snapshot.param2[vm_index] ~= operation.final_param2 then
				fail("full-VM P9G final tuple differs from production ledger")
			end
			successor_snapshot.data[vm_index] = operation.prior_cid
			successor_snapshot.param2[vm_index] = operation.prior_param2
			restored_count = restored_count + 1
		end
	end
	compare_vm_arrays(successor_snapshot, direct_snapshot,
		"Stage-A restored successor/direct83 VM")
	if restored_count ~= stage_a_capture.accepted then
		fail("Stage-A private/VM restored population differs")
	end
	successor_snapshot = nil
	collectgarbage("collect")

	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local accepted_loaded = offline.new_capture(seed, heights, true)
	if type(accepted_loaded.settlement_fixture) ~= "table" then
		fail("accepted R6 full-VM settlement fixture is absent")
	end
	local accepted_snapshot, accepted_result, accepted_capture
	do
		local volume = (maxp.x - minp.x + 33) * (maxp.y - minp.y + 33) *
			(maxp.z - minp.z + 33)
		local data, param2, light = {}, {}, {}
		for index = 1, volume do data[index], param2[index], light[index] = 0, 0, 0 end
		local vm, _, observer = offline.vm_module.new({minp = minp, maxp = maxp,
			data = data, param2 = param2, light = light, heightmap = heights,
			content_contract = accepted_loaded.content_contract, water_level = 1,
			ignore_cid = accepted_loaded.content_contract.ignore_cid,
			verify_inactive_tail = false})
		local plan, generation = accepted_loaded.session.plan_slice(minp, maxp)
		accepted_loaded.settlement_fixture.arm_private_capture()
		accepted_result = accepted_loaded.session.apply_fixture(vm, minp, maxp,
			plan, generation)
		accepted_capture = accepted_loaded.settlement_fixture.take_private_capture()
		accepted_snapshot = observer.snapshot()
		validate_vm_commit(accepted_result, accepted_snapshot, "accepted R6 writer")
	end
	validate_private_capture(repo, accepted_capture, minp, maxp, false,
		"accepted R6 writer")
	fixture_runs_match_capture(accepted_loaded.settlement_fixture, accepted_capture,
		"accepted R6 writer")
	local stage_b_capture = compare_stage_b_captures(repo, runtime_fixture, binding,
		accepted_loaded, direct_capture, accepted_capture)
	normalize_direct_snapshot(runtime_fixture, binding, direct_scan, accepted_scan,
		accepted_loaded, direct_snapshot)
	compare_vm_arrays(direct_snapshot, accepted_snapshot,
		"Stage-B normalized Direct-83/accepted-R6 VM")
	local successor_run_count, direct_run_count, accepted_run_count =
		successor_capture.run_count, direct_capture.run_count, accepted_capture.run_count
	local capture_proof = {
		private_tuple_count = successor_capture.tuple_count,
		successor_tuple_sha256 = successor_capture.tuple_sha256,
		direct_tuple_sha256 = direct_capture.tuple_sha256,
		accepted_tuple_sha256 = accepted_capture.tuple_sha256,
		successor_run_sha256 = successor_capture.run_sha256,
		direct_run_sha256 = direct_capture.run_sha256,
		accepted_run_sha256 = accepted_capture.run_sha256,
		successor_run_checksum_a = successor_capture.run_checksum_a,
		successor_run_checksum_b = successor_capture.run_checksum_b,
		direct_run_checksum_a = direct_capture.run_checksum_a,
		direct_run_checksum_b = direct_capture.run_checksum_b,
		accepted_run_checksum_a = accepted_capture.run_checksum_a,
		accepted_run_checksum_b = accepted_capture.run_checksum_b,
	}
	direct_snapshot, accepted_snapshot = nil, nil
	direct_capture, accepted_capture = nil, nil
	collectgarbage("collect")
	local multi_y = multi_y_owner_kat(repo, runtime_fixture, successor, heights,
		successor_capture)
	return {successor_result = successor_result, direct_result = direct_result,
		accepted_result = accepted_result, restored_p9g = restored_count,
		proof_scope = "full_owner_7_private_buffers_pre_replay",
		private_tuple_count = capture_proof.private_tuple_count,
		successor_run_count = successor_run_count,
		direct_run_count = direct_run_count,
		accepted_run_count = accepted_run_count,
		successor_tuple_sha256 = capture_proof.successor_tuple_sha256,
		direct_tuple_sha256 = capture_proof.direct_tuple_sha256,
		accepted_tuple_sha256 = capture_proof.accepted_tuple_sha256,
		successor_run_sha256 = capture_proof.successor_run_sha256,
		direct_run_sha256 = capture_proof.direct_run_sha256,
		accepted_run_sha256 = capture_proof.accepted_run_sha256,
		successor_run_checksum_a = capture_proof.successor_run_checksum_a,
		successor_run_checksum_b = capture_proof.successor_run_checksum_b,
		direct_run_checksum_a = capture_proof.direct_run_checksum_a,
		direct_run_checksum_b = capture_proof.direct_run_checksum_b,
		accepted_run_checksum_a = capture_proof.accepted_run_checksum_a,
		accepted_run_checksum_b = capture_proof.accepted_run_checksum_b,
		stage_a_tuple_sha256 = stage_a_capture.tuple_sha256,
		stage_a_run_sha256 = stage_a_capture.run_sha256,
		stage_b_tuple_sha256 = stage_b_capture.tuple_sha256,
		stage_b_run_sha256 = stage_b_capture.run_sha256,
		stage_b_substitutions = stage_b_capture.substitutions,
		multi_y_band_count = multi_y.band_count,
		multi_y_eligible = multi_y.eligible, multi_y_planned = multi_y.planned,
		multi_y_accepted = multi_y.accepted}
end

function module.integration_kat(repo)
	text(repo, "repository path")
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	seeds.verify(function(bytes) return raw_sha256(repo, bytes) end)
	local runtime_fixture = fixture(repo, seeds.fixed[1])
	local built = runtime_fixture.built
	if built.schema ~= "grug_wp40_r7_runtime_v1" or
		built.evidence.schema ~= "grug_wp40_r7_private_evidence_v1" or
		built.manifest.values.production_enabled ~= true or
		built.manifest.values.writer_schema ~= "grug_wp40_r7_single_vm_writer_v1" or
		built.manifest.values.p9g_order ~= "after_r6_p9_before_run_derivation" or
		built.manifest.values.p9g_overwrite ~= false or
		#built.content.production.content_names ~= 83 or
		#built.content.p9g.content_names ~= 12 then
		fail("production runtime identity differs")
	end
	local binding = artifact_content_binding(repo, runtime_fixture)
	local successor = validate_scan(built.evidence.scan_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, true)
	local direct = validate_scan(built.evidence.scan_direct_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, false)
	local stage_a = stage_a_owner(repo, runtime_fixture, successor, direct)
	if stage_a.operation_count == 0 or stage_a.accepted == 0 then
		fail("integration owner does not exercise P9G acceptance")
	end
	local accepted = accepted_owner_scan(repo, seeds.fixed[1],
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z)
	local stage_b = stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
	local replay = validate_scan(built.evidence.scan_owner(
		INTEGRATION_OWNER_X, INTEGRATION_OWNER_Z), INTEGRATION_OWNER_X,
		INTEGRATION_OWNER_Z, true)
	if graph(successor) ~= graph(replay) then fail("production owner replay differs") end
	probe_rejections(runtime_fixture)
	local full_vm = full_vm_integration(repo, runtime_fixture, successor, direct,
		accepted, binding, seeds.fixed[1])

	local catalog_manifest = runtime_fixture.catalog_manifest
	if catalog_manifest.population.new_p9g_source ~= 12 or
		catalog_manifest.population.reuse_r6_source ~= 8 or
		catalog_manifest.population.r6_cultural_slot ~= 6 or
		catalog_manifest.sha256 ~= built.manifest.values.gathering_sha256 then
		fail("gathering manifest binding differs")
	end
	for _, name in ipairs({"at", "id_at", "biome_at", "race_region_at",
		"faction_at", "territory_rule_at", "pvp_rule_at", "surface_mob_level_at",
		"mob_level_at", "guard_level_at", "terrain_height_at", "water_class_at",
		"housing_eligible_at"}) do
		if type(built.zones_session[name]) ~= "function" then
			fail("zones/query adapter lacks " .. name)
		end
	end
	if type(built.session.plan_slice) ~= "function" or
			type(built.writer.apply) ~= "function" then
		fail("single transaction API differs")
	end
	local ok = pcall(fixture, repo, "not-a-decimal-seed")
	if ok then fail("runtime initialization did not fail closed") end

	local cases = {}
	for _, name in ipairs(contract.integration_cases()) do cases[name] = true end
	local receipt = {
		schema = "grug_wp40_r7_integration_kat_receipt_v1",
		r7_manifest_sha256 = built.manifest.sha256,
		production_r6_content_sha256 = built.manifest.values.production_r6_content_sha256,
		p9g_content_sha256 = built.manifest.values.p9g_content_sha256,
		catalog_sha256 = catalog_manifest.sha256,
		proof_scope = full_vm.proof_scope,
		private_tuple_count = full_vm.private_tuple_count,
		successor_tuple_sha256 = full_vm.successor_tuple_sha256,
		direct_tuple_sha256 = full_vm.direct_tuple_sha256,
		accepted_tuple_sha256 = full_vm.accepted_tuple_sha256,
		successor_run_count = full_vm.successor_run_count,
		direct_run_count = full_vm.direct_run_count,
		accepted_run_count = full_vm.accepted_run_count,
		successor_run_sha256 = full_vm.successor_run_sha256,
		direct_run_sha256 = full_vm.direct_run_sha256,
		accepted_run_sha256 = full_vm.accepted_run_sha256,
		successor_run_checksum_a = full_vm.successor_run_checksum_a,
		successor_run_checksum_b = full_vm.successor_run_checksum_b,
		direct_run_checksum_a = full_vm.direct_run_checksum_a,
		direct_run_checksum_b = full_vm.direct_run_checksum_b,
		accepted_run_checksum_a = full_vm.accepted_run_checksum_a,
		accepted_run_checksum_b = full_vm.accepted_run_checksum_b,
		stage_a_tuple_sha256 = full_vm.stage_a_tuple_sha256,
		stage_a_run_sha256 = full_vm.stage_a_run_sha256,
		stage_b_tuple_sha256 = full_vm.stage_b_tuple_sha256,
		stage_b_run_sha256 = full_vm.stage_b_run_sha256,
		multi_y_band_count = full_vm.multi_y_band_count,
		multi_y_eligible = full_vm.multi_y_eligible,
		multi_y_planned = full_vm.multi_y_planned,
		multi_y_accepted = full_vm.multi_y_accepted,
		cases = cases,
	}
	contract.validate_integration_receipt(receipt)
	if binding.sha256 ~= ACCEPTED_R6_ARTIFACT_SHA256 or
		sha256(repo, stage_a.direct_buffers) ~= sha256(repo, stage_a.restored_buffers) or
		sha256(repo, stage_b.bytes) ~= sha256(repo, stage_b.accepted_bytes) then
		fail("integration proof digest parity differs")
	end
	return receipt
end

local function add(map, key, value)
	map[key] = (map[key] or 0) + value
end

local function new_horizontal_aggregate(offline)
	local result = {coverage = {}, cultural_candidates = {}, cultural_slots = {},
		decoration_candidates = {}, decoration_settlement = {}, rejections = {}}
	for index = 1, #offline.fixtures.cultural do
		local key = offline.fixtures.cultural[index].key
		for _, rate in ipairs({"concentrated", "ordinary"}) do
			result.cultural_candidates[key .. "\0" .. rate] =
				{eligible = 0, budget = 0, candidates = 0}
			result.cultural_slots[key .. "\0" .. rate] =
				{accepted = 0, reserved = 0}
		end
	end
	for index = 1, #offline.fixtures.decorations do
		local id = offline.fixtures.decorations[index].id
		result.decoration_candidates[id] =
			{eligible = 0, budget = 0, candidates = 0}
		result.decoration_settlement[id] =
			{accepted = 0, emitted = 0, reserved = 0}
	end
	return result
end

local function merge_horizontal(aggregate, offline, scan)
	for index = 1, #scan.coverage do
		local row = scan.coverage[index]
		add(aggregate.coverage, row.zone_id .. "\0" .. row.biome, row.count)
	end
	for index = 1, #scan.groups do
		local group = scan.groups[index]
		if group.kind == 1 then
			local definition = offline.fixtures.cultural[group.catalog]
			if not definition then fail("unknown Cultural planner catalog") end
			local rate = group.parameter == 1024 and "concentrated" or
				(group.parameter == 4096 and "ordinary" or nil)
			if not rate then fail("Cultural planner denominator differs") end
			local target = aggregate.cultural_candidates[
				definition.key .. "\0" .. rate]
			target.eligible = target.eligible + group.eligible
			target.budget = target.budget + group.budget
			target.candidates = target.candidates + group.candidates
		elseif group.kind == 2 then
			local definition = offline.fixtures.decorations[group.catalog]
			if not definition then fail("unknown decoration planner catalog") end
			local target = aggregate.decoration_candidates[definition.id]
			target.eligible = target.eligible + group.eligible
			target.budget = target.budget + group.budget
			target.candidates = target.candidates + group.candidates
		else
			fail("planner group kind differs")
		end
	end
	for key, row in pairs(scan.settlement.cultural) do
		local target = aggregate.cultural_slots[key]
		if not target then fail("unknown Cultural settlement key") end
		target.accepted = target.accepted + row.accepted
		target.reserved = target.reserved + row.reserved
	end
	for id, row in pairs(scan.settlement.decorations) do
		local target = aggregate.decoration_settlement[id]
		if not target then fail("unknown decoration settlement key") end
		target.accepted = target.accepted + row.accepted
		target.emitted = target.emitted + row.emitted
		target.reserved = target.reserved + row.reserved
	end
	for key, count in pairs(scan.settlement.rejections) do
		add(aggregate.rejections, key, count)
	end
end

local function split_nul(value)
	local fields, first = {}, 1
	while true do
		local delimiter = value:find("\0", first, true)
		if not delimiter then
			fields[#fields + 1] = value:sub(first)
			return fields
		end
		fields[#fields + 1] = value:sub(first, delimiter - 1)
		first = delimiter + 1
	end
end

local function aggregate_projection(binding, offline, seed_slot, aggregate)
	local codec, records = binding.codec, {}
	local function emit(row_type, keys, values)
		local bytes = codec.encode_data_row(row_type, keys, values)
		records[#records + 1] = {bytes = bytes,
			fields = codec.parse_data_line(bytes:sub(1, -2),
				"normalized R6 projection row")}
	end
	local allowed = {}
	for zone_index = 1, #offline.source.zones do
		local zone = offline.source.zones[zone_index]
		for biome_index = 1, #zone.biomes do
			allowed[zone.id .. "\0" .. zone.biomes[biome_index].id] = true
		end
	end
	for key in pairs(allowed) do
		local fields, count = split_nul(key), aggregate.coverage[key]
		emit("surface_coverage", {seed_slot, fields[1], fields[2],
			count and "occurring" or "catalog_zero"}, {count or 0})
	end
	for index = 1, #offline.fixtures.cultural do
		local id = offline.fixtures.cultural[index].key
		for _, rate in ipairs({"concentrated", "ordinary"}) do
			local key = id .. "\0" .. rate
			local candidate, settled = aggregate.cultural_candidates[key],
				aggregate.cultural_slots[key]
			emit("cultural_candidate", {seed_slot, id, rate},
				{candidate.eligible, candidate.budget, candidate.candidates})
			emit("cultural_slot", {seed_slot, id, rate},
				{settled.accepted, settled.reserved})
		end
	end
	for index = 1, #offline.fixtures.decorations do
		local definition = offline.fixtures.decorations[index]
		local candidate = aggregate.decoration_candidates[definition.id]
		local settled = aggregate.decoration_settlement[definition.id]
		emit("decoration_candidate", {seed_slot, definition.id,
			definition.settlement_class},
			{candidate.eligible, candidate.budget, candidate.candidates})
		emit("decoration_settlement", {seed_slot, definition.id,
			definition.settlement_class},
			{settled.accepted, settled.emitted, settled.reserved})
	end
	local cultural_reasons = {"clipped_owner", "fixed_or_protected",
		"route_or_water", "content_ignore", "wrong_support", "cultural_collision"}
	for index = 1, #offline.fixtures.cultural do
		local id = offline.fixtures.cultural[index].key
		for reason_index = 1, #cultural_reasons do
			local reason = cultural_reasons[reason_index]
			emit("rejection", {seed_slot, "cultural", id, reason},
				{aggregate.rejections["cultural\0" .. id .. "\0" .. reason] or 0})
		end
	end
	local decoration_reasons = {"clipped_owner", "content_ignore",
		"fixed_or_protected", "route_or_water", "wrong_host",
		"insufficient_clearance", "cultural_collision", "resource_collision",
		"decoration_collision", "forbidden_old_class"}
	for index = 1, #offline.fixtures.decorations do
		local id = offline.fixtures.decorations[index].id
		for reason_index = 1, #decoration_reasons do
			local reason = decoration_reasons[reason_index]
			emit("rejection", {seed_slot, "decoration", id, reason},
				{aggregate.rejections["decoration\0" .. id .. "\0" .. reason] or 0})
		end
	end
	table.sort(records, function(left, right) return codec.compare(left.fields, right.fields) end)
	if #records ~= #binding.projection_records then
		fail("normalized/accepted R6 aggregate population differs")
	end
	local normalized, accepted = {}, {}
	for index = 1, #records do
		normalized[index] = records[index].bytes
		accepted[index] = binding.projection_records[index].bytes
		if normalized[index] ~= accepted[index] then
			fail("normalized Direct-83 aggregate differs from accepted R6 at row " ..
				tostring(index))
		end
	end
	return table.concat(normalized), table.concat(accepted)
end

local function new_p9g_aggregate(reasons)
	local result = {populations = {}, rejections = {}}
	for index = 1, #reasons do result.rejections[reasons[index]] = 0 end
	return result
end

local function merge_p9g(aggregate, reasons, ledger)
	for index = 1, #ledger.populations do
		local row = ledger.populations[index]
		local key = table.concat({row.source_id, row.zone_id, row.biome,
			row.faction, row.bracket}, "\0")
		local target = aggregate.populations[key]
		if not target then
			target = {source_id = row.source_id, zone_id = row.zone_id,
				biome = row.biome, faction = row.faction, bracket = row.bracket,
				eligible = 0, budget = 0, accepted = 0, rejections = {}}
			for reason = 1, #reasons do target.rejections[reasons[reason]] = 0 end
			aggregate.populations[key] = target
		end
		target.eligible = target.eligible + row.eligible
		target.budget = target.budget + row.budget
		target.accepted = target.accepted + row.accepted
		for reason = 1, #reasons do
			local name = reasons[reason]
			target.rejections[name] = target.rejections[name] + row.rejections[name]
		end
	end
	for index = 1, #reasons do
		local name = reasons[index]
		aggregate.rejections[name] = aggregate.rejections[name] +
			ledger.rejections[name]
	end
end

local function p9g_aggregate_bytes(aggregate, reasons)
	local rows = {}
	local population_keys = {}
	for key in pairs(aggregate.populations) do population_keys[#population_keys + 1] = key end
	table.sort(population_keys, less_bytes)
	for index = 1, #population_keys do
		local row = aggregate.populations[population_keys[index]]
		local values = {row.source_id, row.zone_id, row.biome, row.faction,
			row.bracket, row.eligible, row.budget, row.accepted}
		for reason = 1, #reasons do
			values[#values + 1] = row.rejections[reasons[reason]]
		end
		for field = 6, #values do values[field] = tostring(values[field]) end
		rows[#rows + 1] = "population\t" .. table.concat(values, "\t") .. "\n"
	end
	return table.concat(rows)
end

local function prefix_lines(prefix, bytes)
	local rows = {}
	for line in bytes:gmatch("([^\n]+)\n") do
		rows[#rows + 1] = prefix .. line .. "\n"
	end
	return table.concat(rows)
end

local function unopened_output(path)
	text(path, "seed output path")
	local probe = io.open(path, "rb")
	if probe then probe:close(); fail("seed output already exists") end
	return assert(io.open(path, "wb"), "cannot create seed output")
end

-- The exhaustive seed encoder writes its complete ledger incrementally.  It is
-- the same owner loop as integration_kat; no second placement implementation
-- exists in tooling and no full-seed payload is retained in memory.
function module.run_seed(repo, seed_slot, output_path)
	integer(seed_slot, 1, 32, "seed slot")
	local output = unopened_output(output_path)
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	local seed = seeds.fixed[seed_slot]
	local runtime_fixture = fixture(repo, seed, "horizontal")
	local binding = artifact_content_binding(repo, runtime_fixture, seed_slot)
	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local accepted_loaded = offline.new_evidence(seed, true)
	local aggregate = new_horizontal_aggregate(offline)
	local stream = sha_stream(repo)
	local output_hasher, output_bytes = stream.new(), 0
	local function write(bytes)
		if type(bytes) ~= "string" or bytes == "" then fail("empty seed output write") end
		assert(output:write(bytes))
		output_hasher.update(bytes)
		output_bytes = output_bytes + #bytes
	end
	write("schema\tgrug_wp40_r7_seed_evidence_v1\n")
	write("seed_slot\t" .. tostring(seed_slot) .. "\n")
	write("seed_identity\t" .. seed .. "\n")
	local restored_buffers, direct_buffers = stream.new(), stream.new()
	local restored_runs, direct_runs = stream.new(), stream.new()
	local candidate, accepted_candidate = stream.new(), stream.new()
	local reasons = contract.rejection_reasons()
	if graph(reasons) ~= graph(P9G_REASONS) then
		fail("runtime/contract P9G rejection order differs")
	end
	local p9g_aggregate = new_p9g_aggregate(reasons)
	local operation_count, accepted_count, rejected_count = 0, 0, 0
	local substitutions = 0
	for owner_z = OWNER_MIN_Z, OWNER_MAX_Z, 80 do
		for owner_x = OWNER_MIN_X, OWNER_MAX_X, 80 do
			local successor = validate_scan(runtime_fixture.built.evidence.scan_owner(
				owner_x, owner_z), owner_x, owner_z, true)
			local direct = validate_scan(runtime_fixture.built.evidence.scan_direct_owner(
				owner_x, owner_z), owner_x, owner_z, false)
			local a = stage_a_owner(repo, runtime_fixture, successor, direct)
			restored_buffers.update(a.restored_buffers)
			direct_buffers.update(a.direct_buffers)
			restored_runs.update(a.restored_runs)
			direct_runs.update(a.direct_runs)
			operation_count = operation_count + a.operation_count
			accepted_count = accepted_count + a.accepted
			rejected_count = rejected_count + a.rejected
			if a.operation_bytes ~= "" then write(a.operation_bytes) end
			merge_p9g(p9g_aggregate, reasons, a.ledger)
			local _, count = normalize_rows(runtime_fixture, binding,
				direct.settlement.direct_rows)
			substitutions = substitutions + count
			local accepted = scan_accepted_loaded(accepted_loaded, owner_x, owner_z)
			local b = stage_b_owner(repo, runtime_fixture, binding, direct, accepted)
			candidate.update(b.bytes)
			accepted_candidate.update(b.accepted_bytes)
			merge_horizontal(aggregate, offline, direct)
		end
	end
	local stage_a = {
		schema = "grug_wp40_r7_stage_a_receipt_v1", seed_slot = seed_slot,
		seed_identity = seed,
		production_r6_content_sha256 =
			runtime_fixture.built.manifest.values.production_r6_content_sha256,
		p9g_content_sha256 = runtime_fixture.built.manifest.values.p9g_content_sha256,
		p9g_delta_sha256 = runtime_fixture.built.manifest.values.p9g_delta_sha256,
		operation_count = operation_count, accepted_count = accepted_count,
		rejected_count = rejected_count,
		restored_buffers_sha256 = restored_buffers.final_hex(),
		direct_buffers_sha256 = direct_buffers.final_hex(),
		restored_runs_sha256 = restored_runs.final_hex(),
		direct_runs_sha256 = direct_runs.final_hex(), equal = true,
	}
	contract.validate_stage_a(stage_a)
	local normalized_projection, accepted_projection = aggregate_projection(
		binding, offline, seed_slot, aggregate)
	local candidate_sha, accepted_candidate_sha = candidate.final_hex(),
		accepted_candidate.final_hex()
	local normalized_projection_sha, accepted_projection_sha =
		sha256(repo, normalized_projection), sha256(repo, accepted_projection)
	local stage_b = {
		schema = "grug_wp40_r7_stage_b_receipt_v1", seed_slot = seed_slot,
		seed_identity = seed,
		production_r6_content_sha256 =
			runtime_fixture.built.manifest.values.production_r6_content_sha256,
		accepted_r6_projection_sha256 = accepted_projection_sha,
		name_map_population = 83, cultural_name_map_population = 6,
		cultural_substitution_count = substitutions,
		inherited_cultural_access_count = binding.inherited_cultural_access_count,
		normalized_artifact_sha256 = normalized_projection_sha,
		candidate_decisions_sha256 = candidate_sha,
		accepted_candidate_decisions_sha256 = accepted_candidate_sha, equal = true,
	}
	contract.validate_stage_b(stage_b)
	write(p9g_aggregate_bytes(p9g_aggregate, reasons))
	local stage_a_bytes, stage_b_bytes = contract.stage_a_bytes(stage_a),
		contract.stage_b_bytes(stage_b)
	assert(output:close())
	return {schema = "grug_wp40_r7_seed_result_v1", seed_slot = seed_slot,
		seed_identity = seed, manifest_sha256 = runtime_fixture.built.manifest.sha256,
		accepted_r6_artifact_sha256 = binding.sha256, stage_a = stage_a,
		stage_b = stage_b, path = output_path, sha256 = output_hasher.final_hex(),
		bytes = output_bytes, stage_a_sha256 = sha256(repo, stage_a_bytes),
		stage_b_sha256 = sha256(repo, stage_b_bytes)}
end

function module.pilot(repo, scratch, seed_slot)
	text(scratch, "pilot scratch")
	local result = module.run_seed(repo, seed_slot,
		scratch .. "-seed-" .. string.format("%02d", seed_slot) .. ".tsv")
	return {
		schema = "grug_wp40_r7_pilot_result_v1", seed_slot = seed_slot,
		seed_identity = result.seed_identity,
		canonical_output_sha256 = result.sha256,
		canonical_output_bytes = result.bytes,
		stage_a_sha256 = result.stage_a_sha256,
		stage_b_sha256 = result.stage_b_sha256,
		p9g_delta_sha256 = result.stage_a.p9g_delta_sha256,
	}
end

function module.worker(repo, scratch, first_slot, last_slot, projection_sha256)
	text(scratch, "worker scratch")
	integer(first_slot, 1, 32, "worker first slot")
	integer(last_slot, first_slot, 32, "worker last slot")
	digest(projection_sha256, "approved projection digest")
	local rows = {"schema\tgrug_wp40_r7_worker_receipt_v1\n",
		"projection_sha256\t" .. projection_sha256 .. "\n",
		"first_slot\t" .. tostring(first_slot) .. "\n",
		"last_slot\t" .. tostring(last_slot) .. "\n"}
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	for slot = first_slot, last_slot do
		local path = scratch .. "/seed-" .. string.format("%02d", slot) .. ".tsv"
		local result = module.run_seed(repo, slot, path)
		rows[#rows + 1] = table.concat({"seed", slot, result.seed_identity,
			result.path, result.sha256, result.bytes, result.manifest_sha256,
			result.accepted_r6_artifact_sha256, result.stage_a_sha256,
			result.stage_b_sha256, result.stage_a.p9g_delta_sha256}, "\t") .. "\n"
		rows[#rows + 1] = "stage_a\t" .. tostring(slot) .. "\t" ..
			hex(contract.stage_a_bytes(result.stage_a)) .. "\n"
		rows[#rows + 1] = "stage_b\t" .. tostring(slot) .. "\t" ..
			hex(contract.stage_b_bytes(result.stage_b)) .. "\n"
	end
	return table.concat(rows)
end

local function split_tabs(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
	return fields
end

local function unhex(value)
	if type(value) ~= "string" or #value % 2 ~= 0 or
			not value:match("^[0-9a-f]+$") then fail("hex payload differs") end
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end

local function parse_receipt_bytes(bytes, stage)
	local result = {}
	for line in bytes:gmatch("([^\n]+)\n") do
		local fields = split_tabs(line)
		if #fields ~= 2 or result[fields[1]] ~= nil then
			fail(stage .. " receipt bytes differ")
		end
		local value = fields[2]
		if fields[1] == "seed_slot" or fields[1]:find("_count$") or
				fields[1]:find("_population$") then
			value = tonumber(value)
		elseif fields[1] == "equal" then value = value == "true" end
		result[fields[1]] = value
	end
	return result
end

local function read_file(path)
	local file = assert(io.open(path, "rb"), "cannot open " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local function worker_descriptors(repo, path, contract, stream)
	local bytes = read_file(path)
	local lines, first = {}, true
	local projection, first_slot, last_slot
	local seeds, stage_a, stage_b = {}, {}, {}
	for line in bytes:gmatch("([^\n]+)\n") do
		local fields = split_tabs(line)
		if first then
			if line ~= "schema\tgrug_wp40_r7_worker_receipt_v1" then
				fail("worker receipt schema differs")
			end
			first = false
		elseif fields[1] == "projection_sha256" and #fields == 2 and not projection then
			projection = digest(fields[2], "worker projection digest")
		elseif fields[1] == "first_slot" and #fields == 2 and not first_slot then
			first_slot = tonumber(fields[2])
		elseif fields[1] == "last_slot" and #fields == 2 and not last_slot then
			last_slot = tonumber(fields[2])
		elseif fields[1] == "seed" and #fields == 11 then
			local slot = tonumber(fields[2])
			if not slot or seeds[slot] then fail("worker seed descriptor differs") end
			seeds[slot] = {slot = slot, identity = fields[3], path = fields[4],
				sha256 = fields[5], bytes = tonumber(fields[6]), manifest_sha256 = fields[7],
				accepted_r6_artifact_sha256 = fields[8], stage_a_sha256 = fields[9],
				stage_b_sha256 = fields[10], p9g_delta_sha256 = fields[11]}
		elseif fields[1] == "stage_a" and #fields == 3 then
			local slot = assert(tonumber(fields[2]))
			if stage_a[slot] then fail("duplicate worker Stage-A row") end
			stage_a[slot] = unhex(fields[3])
		elseif fields[1] == "stage_b" and #fields == 3 then
			local slot = assert(tonumber(fields[2]))
			if stage_b[slot] then fail("duplicate worker Stage-B row") end
			stage_b[slot] = unhex(fields[3])
		else fail("worker receipt row differs") end
	end
	if first or not projection then fail("worker receipt is incomplete") end
	integer(first_slot, 1, 32, "worker first slot")
	integer(last_slot, first_slot, 32, "worker last slot")
	local expected_count, seed_count, stage_a_count, stage_b_count =
		last_slot - first_slot + 1, 0, 0, 0
	for slot in pairs(seeds) do
		if slot < first_slot or slot > last_slot then fail("worker seed escaped assignment") end
		seed_count = seed_count + 1
	end
	for slot in pairs(stage_a) do
		if slot < first_slot or slot > last_slot then fail("worker Stage-A escaped assignment") end
		stage_a_count = stage_a_count + 1
	end
	for slot in pairs(stage_b) do
		if slot < first_slot or slot > last_slot then fail("worker Stage-B escaped assignment") end
		stage_b_count = stage_b_count + 1
	end
	if seed_count ~= expected_count or stage_a_count ~= expected_count or
			stage_b_count ~= expected_count then
		fail("worker evidence population differs")
	end
	for slot = first_slot, last_slot do
		local row = seeds[slot]
		if not row or not stage_a[slot] or not stage_b[slot] then
			fail("worker seed evidence is incomplete")
		end
		digest(row.sha256, "seed file digest")
		integer(row.bytes, 1, MAX_SAFE, "seed file bytes")
		for _, field in ipairs({"manifest_sha256", "accepted_r6_artifact_sha256",
			"stage_a_sha256", "stage_b_sha256", "p9g_delta_sha256"}) do
			digest(row[field], "seed descriptor " .. field)
		end
		local actual_sha, actual_bytes = stream.file(row.path)
		if actual_sha ~= row.sha256 or actual_bytes ~= row.bytes or
				sha256(repo, stage_a[slot]) ~= row.stage_a_sha256 or
				sha256(repo, stage_b[slot]) ~= row.stage_b_sha256 then
			fail("worker seed descriptor binding differs")
		end
		local a, b = parse_receipt_bytes(stage_a[slot], "Stage-A"),
			parse_receipt_bytes(stage_b[slot], "Stage-B")
		contract.validate_stage_a(a); contract.validate_stage_b(b)
		if a.seed_slot ~= slot or b.seed_slot ~= slot or
				a.seed_identity ~= row.identity or b.seed_identity ~= row.identity or
				a.p9g_delta_sha256 ~= row.p9g_delta_sha256 then
			fail("worker seed receipt identity differs")
		end
		row.stage_a, row.stage_b = stage_a[slot], stage_b[slot]
		row.stage_a_receipt, row.stage_b_receipt = a, b
	end
	return projection, first_slot, last_slot, seeds
end

local function new_final_output(path, stream)
	text(path, "finalizer output path")
	local probe = io.open(path, "rb")
	if probe then probe:close(); fail("finalizer output already exists") end
	local file = assert(io.open(path, "wb"), "cannot create finalizer output")
	local hasher, byte_count, closed = stream.new(), 0, false
	local output = {}
	function output.write(bytes)
		if closed or type(bytes) ~= "string" or bytes == "" then
			fail("finalizer output write differs")
		end
		assert(file:write(bytes))
		hasher.update(bytes)
		byte_count = byte_count + #bytes
	end
	function output.close()
		if closed then fail("finalizer output closed twice") end
		assert(file:close())
		closed = true
		return {path = path, sha256 = hasher.final_hex(), bytes = byte_count}
	end
	return output
end

local function parsed_integer(value, minimum, maximum, label)
	local number = tonumber(value)
	if not number or tostring(number) == "nan" then fail(label .. " is not numeric") end
	return integer(number, minimum, maximum, label)
end

function module.finalizer_authority_kat(repo)
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local source = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local zones, faction = {}, {dwarf = "accord", human = "accord", elf = "accord",
		undead = "throng", orc = "throng", troll = "throng"}
	for index = 1, #source.zones do zones[source.zones[index].id] = source.zones[index] end
	local contested = {accord = 0, throng = 0}
	for _, row in ipairs(catalog.p9g_sources()) do
		for index = 1, #row.zones do
			local zone = zones[row.zones[index]]
			if not zone or not faction[zone.race_region] then
				fail("finalizer authority KAT source zone differs")
			end
			local minimum = math.floor((zone.difficulty_target - 1) / 10) * 10 + 1
			if not P9G_BRACKETS[tostring(minimum) .. "-" .. tostring(minimum + 9)] then
				fail("finalizer authority KAT bracket differs")
			end
			if zone.faction == false then
				contested[faction[zone.race_region]] = contested[faction[zone.race_region]] + 1
			elseif zone.faction ~= faction[zone.race_region] then
				fail("finalizer authority KAT home faction differs")
			end
		end
		for index = 1, #row.hosts do
			if type(row.hosts[index].biome) ~= "string" or
					type(row.hosts[index].support) ~= "string" then
				fail("finalizer authority KAT host differs")
			end
		end
	end
	if contested.accord == 0 or contested.throng == 0 then
		fail("finalizer authority KAT lacks both contested factions")
	end
	return true
end

function module.finalize(repo, scratch, worker_paths)
	text(scratch, "finalizer scratch")
	dense(worker_paths, "worker paths")
	if #worker_paths ~= 7 then fail("finalizer worker population differs") end
	local contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local stream = sha_stream(repo)
	local all, projection, ranges = {}, nil, {}
	local allowed_ranges = {['1/5'] = true, ['6/10'] = true, ['11/15'] = true,
		['16/20'] = true, ['21/25'] = true, ['26/30'] = true, ['31/32'] = true}
	for index = 1, 7 do
		local worker_projection, first_slot, last_slot, seeds =
			worker_descriptors(repo, worker_paths[index], contract, stream)
		local range = tostring(first_slot) .. "/" .. tostring(last_slot)
		if not allowed_ranges[range] or ranges[range] or
				(projection and projection ~= worker_projection) then
			fail("worker assignment/projection differs")
		end
		ranges[range], projection = true, worker_projection
		for slot = first_slot, last_slot do
			if all[slot] then fail("duplicate finalizer seed slot") end
			all[slot] = seeds[slot]
		end
	end

	local seeds = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local map_source = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local content_fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
		repo, seeds.fixed[1], true)
	local source_rows, source_by_id, source_index = catalog.p9g_sources(), {}, {}
	if #source_rows ~= 12 then fail("finalizer P9G source population differs") end
	for index = 1, #source_rows do
		local row = source_rows[index]
		if source_by_id[row.id] then fail("finalizer duplicate P9G source") end
		source_by_id[row.id], source_index[row.id] = row, index
	end
	local zone_by_id, faction_by_race = {}, {dwarf = "accord", human = "accord",
		elf = "accord", undead = "throng", orc = "throng", troll = "throng"}
	for index = 1, #map_source.zones do
		local zone = map_source.zones[index]
		local regional_faction = faction_by_race[zone.race_region]
		if zone_by_id[zone.id] or not regional_faction or
				(zone.faction ~= false and zone.faction ~= regional_faction) then
			fail("finalizer R4 zone/faction authority differs")
		end
		zone_by_id[zone.id] = zone
	end
	local function expected_bracket(target)
		integer(target, 1, 60, "zone difficulty target")
		local minimum = math.floor((target - 1) / 10) * 10 + 1
		return tostring(minimum) .. "-" .. tostring(minimum + 9)
	end
	local function source_semantics(source_id, zone_id, biome, faction, bracket)
		local source, zone = source_by_id[source_id], zone_by_id[zone_id]
		if not source or not zone then fail("P9G source/zone identity differs") end
		local zone_allowed = false
		for index = 1, #source.zones do
			if source.zones[index] == zone_id then zone_allowed = true break end
		end
		local support
		for index = 1, #source.hosts do
			if source.hosts[index].biome == biome then
				support = source.hosts[index].support break
			end
		end
		if not zone_allowed or not support or faction ~= faction_by_race[zone.race_region] or
				bracket ~= expected_bracket(zone.difficulty_target) then
			fail("P9G source/zone/biome/faction/bracket semantics differ")
		end
		return source, support
	end
	local reason_set = {}
	for index = 1, #P9G_REASONS do reason_set[P9G_REASONS[index]] = true end
	local source_totals, access, parity, source_final_tuple = {}, {}, {}, {}
	for index = 1, #source_rows do
		local id = source_rows[index].id
		source_totals[id] = {eligible = 0, budget = 0, accepted = 0}
		access[id] = {accord = 0, throng = 0}
		parity[id] = {}
	end

	local artifact = new_final_output(scratch .. "/artifact.tsv", stream)
	local stage_a = new_final_output(scratch .. "/stage-a.tsv", stream)
	local stage_b = new_final_output(scratch .. "/stage-b.tsv", stream)
	local p9g = new_final_output(scratch .. "/p9g.tsv", stream)
	artifact.write("schema\tgrug_wp40_r7_artifact_v1\n")
	artifact.write("projection_sha256\t" .. projection .. "\n")
	artifact.write("accepted_r6_artifact_sha256\t" ..
		ACCEPTED_R6_ARTIFACT_SHA256 .. "\n")
	stage_a.write("schema\tgrug_wp40_r7_stage_a_aggregate_v1\n")
	stage_b.write("schema\tgrug_wp40_r7_stage_b_aggregate_v1\n")
	p9g.write("schema\tgrug_wp40_r7_p9g_ledger_v1\n")

	local production_content_sha, p9g_content_sha, p9g_delta_sha
	local total_operations, total_accepted, total_rejected = 0, 0, 0
	for slot = 1, 32 do
		local descriptor = all[slot]
		if not descriptor or descriptor.identity ~= seeds.fixed[slot] or
				descriptor.accepted_r6_artifact_sha256 ~= ACCEPTED_R6_ARTIFACT_SHA256 then
			fail("finalizer seed identity/artifact binding differs")
		end
		local a, b = descriptor.stage_a_receipt, descriptor.stage_b_receipt
		if a.production_r6_content_sha256 ~= b.production_r6_content_sha256 or
				b.inherited_cultural_access_count ~= 12 or
				(production_content_sha and
					production_content_sha ~= a.production_r6_content_sha256) or
				(p9g_content_sha and p9g_content_sha ~= a.p9g_content_sha256) or
				(p9g_delta_sha and p9g_delta_sha ~= a.p9g_delta_sha256) then
			fail("finalizer Stage-A/B content identity differs")
		end
		production_content_sha, p9g_content_sha, p9g_delta_sha =
			a.production_r6_content_sha256, a.p9g_content_sha256, a.p9g_delta_sha256
		artifact.write(table.concat({"seed", tostring(slot), descriptor.identity,
			descriptor.manifest_sha256, descriptor.sha256, tostring(descriptor.bytes),
			descriptor.stage_a_sha256, descriptor.stage_b_sha256,
			descriptor.p9g_delta_sha256}, "\t") .. "\n")
		stage_a.write(prefix_lines("seed\t" .. tostring(slot) .. "\t", descriptor.stage_a))
		stage_b.write(prefix_lines("seed\t" .. tostring(slot) .. "\t", descriptor.stage_b))

		local file = assert(io.open(descriptor.path, "rb"), "cannot open seed evidence")
		local final_byte
		if assert(file:seek("end", -1)) then final_byte = file:read(1) end
		if final_byte ~= "\n" then fail("seed evidence lacks canonical final LF") end
		assert(file:seek("set", 0))
		local line_number, seed_slot, seed_identity = 0, nil, nil
		local operations, accepted_count, rejected_count, population_count = 0, 0, 0, 0
		local operations_by_population, populations_seen, accepted_roots = {}, {}, {}
		local previous_operation, previous_population
		for line in file:lines() do
			line_number = line_number + 1
			if line:find("\r", 1, true) then fail("seed evidence has CR bytes") end
			if line_number == 1 then
				if line ~= "schema\tgrug_wp40_r7_seed_evidence_v1" then
					fail("seed evidence schema differs")
				end
			elseif line:find("^seed_slot\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or seed_slot ~= nil then fail("seed slot row differs") end
				seed_slot = parsed_integer(fields[2], 1, 32, "seed slot")
			elseif line:find("^seed_identity\t") then
				local fields = split_tabs(line)
				if #fields ~= 2 or seed_identity ~= nil then fail("seed identity row differs") end
				seed_identity = text(fields[2], "seed identity")
			elseif line:find("^operation\t") then
				local fields = split_tabs(line)
				if #fields ~= #OPERATION_FIELDS + 1 then fail("P9G operation TSV width differs") end
				local function value(name) return fields[OPERATION_COLUMN[name]] end
				local source_id, zone_id, biome = text(value("source_id"), "operation source"),
					text(value("zone_id"), "operation zone"), text(value("biome"), "operation biome")
				local faction, bracket = text(value("faction"), "operation faction"),
					text(value("bracket"), "operation bracket")
				if not source_by_id[source_id] or (faction ~= "accord" and faction ~= "throng") or
					not P9G_BRACKETS[bracket] then
					fail("P9G operation population identity differs")
				end
				local source_definition, support_name = source_semantics(source_id, zone_id,
					biome, faction, bracket)
				digest(value("candidate_sha256"), "operation candidate digest")
				for _, name in ipairs({"cell_x", "cell_z", "root_x", "root_y", "root_z",
						"original_cid", "original_param2", "prior_cid", "prior_param2",
						"prior_occupancy", "prior_opcode", "prior_feature", "prior_interface",
						"prior_aux", "support_cid", "support_param2", "support_occupancy",
						"support_opcode", "support_feature", "support_interface", "support_aux",
						"final_cid", "final_param2", "final_occupancy", "final_opcode",
						"final_feature", "final_interface", "final_aux"}) do
					parsed_integer(value(name), -MAX_SAFE, MAX_SAFE, "operation " .. name)
				end
				text(value("support_mode"), "operation support mode")
				local accepted = value("accepted")
				local reason = text(value("reason"), "operation reason")
				if accepted ~= "true" and accepted ~= "false" then
					fail("operation acceptance encoding differs")
				end
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				local target = operations_by_population[key]
				if not target then
					target = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do target.rejections[P9G_REASONS[index]] = 0 end
					operations_by_population[key] = target
				end
				target.budget = target.budget + 1
				local root_x = parsed_integer(value("root_x"), -31007, 31007, "operation root x")
				local root_y = parsed_integer(value("root_y"), -31007, 31007, "operation root y")
				local root_z = parsed_integer(value("root_z"), -31007, 31007, "operation root z")
				local order = {owner_minimum(root_z), owner_minimum(root_x), root_z,
					root_x, root_y, source_id}
				if previous_operation then
					local less = false
					for field = 1, 5 do
						if previous_operation[field] ~= order[field] then
							less = previous_operation[field] < order[field]
							break
						end
					end
					if not less and previous_operation[1] == order[1] and
							previous_operation[2] == order[2] and
							previous_operation[3] == order[3] and
							previous_operation[4] == order[4] and
							previous_operation[5] == order[5] then
						less = less_bytes(previous_operation[6], order[6])
					end
					if not less then fail("seed P9G operations are not canonical/unique") end
				end
				previous_operation = order
				if accepted == "true" then
					local root = table.concat({root_x, root_y, root_z}, "/")
					local final_cid = parsed_integer(value("final_cid"), 0, MAX_SAFE,
						"final CID")
					local final_feature = parsed_integer(value("final_feature"), 0,
						MAX_SAFE, "final feature")
					local final_interface = parsed_integer(value("final_interface"), 0,
						MAX_SAFE, "final interface")
					if reason ~= "accepted" or accepted_roots[root] or
							final_cid ~= content_fixture.cid_by_name[source_definition.source_node] or
							parsed_integer(value("final_param2"), 0, 255, "final param2") ~= 0 or
							parsed_integer(value("final_occupancy"), -MAX_SAFE, MAX_SAFE,
								"final occupancy") ~= -2 or
							parsed_integer(value("final_opcode"), 0, MAX_SAFE,
								"final opcode") ~= 35 or
							final_feature ~= source_index[source_id] or final_interface ~= 0 or
							parsed_integer(value("final_aux"), 0, MAX_SAFE, "final aux") ~=
								(82 + source_index[source_id]) * 256 then
						fail("accepted P9G operation tuple/uniqueness differs")
					end
					local support_mode = value("support_mode")
					if (support_mode ~= "settled_owner" and
							support_mode ~= "analytic_lower_owner") or
							parsed_integer(value("original_cid"), 0, MAX_SAFE,
								"original CID") == content_fixture.cid_by_name.ignore or
							parsed_integer(value("prior_cid"), 0, MAX_SAFE, "prior CID") ~=
								content_fixture.cid_by_name.air or
							parsed_integer(value("prior_param2"), 0, 255, "prior param2") ~= 0 or
							parsed_integer(value("prior_occupancy"), -MAX_SAFE, MAX_SAFE,
								"prior occupancy") ~= 0 or
							parsed_integer(value("prior_opcode"), -MAX_SAFE, MAX_SAFE,
								"prior opcode") ~= 0 or
							parsed_integer(value("prior_feature"), -MAX_SAFE, MAX_SAFE,
								"prior feature") ~= 0 or
							parsed_integer(value("prior_interface"), -MAX_SAFE, MAX_SAFE,
								"prior interface") ~= 0 or
							parsed_integer(value("prior_aux"), -MAX_SAFE, MAX_SAFE,
								"prior aux") ~= 0 or
							parsed_integer(value("support_cid"), 0, MAX_SAFE, "support CID") ~=
								content_fixture.cid_by_name[support_name] or
							parsed_integer(value("support_param2"), 0, 255,
								"support param2") ~= 0 or
							parsed_integer(value("support_opcode"), 1, 4,
								"support opcode") < 1 then
						fail("accepted P9G prior/support authority differs")
					end
					local identity = table.concat({final_cid, final_feature,
						final_interface, value("final_aux")}, "/")
					if source_final_tuple[source_id] and
							source_final_tuple[source_id] ~= identity then
						fail("accepted P9G source final tuple differs")
					end
					source_final_tuple[source_id] = identity
					accepted_roots[root], target.accepted = true, target.accepted + 1
					accepted_count = accepted_count + 1
				else
					if not reason_set[reason] then fail("operation rejection reason differs") end
					for _, field in ipairs({"cid", "param2", "occupancy", "opcode",
							"feature", "interface", "aux"}) do
						if value("final_" .. field) ~= value("prior_" .. field) then
							fail("rejected P9G operation changed its prior tuple")
						end
					end
					target.rejections[reason] = target.rejections[reason] + 1
					rejected_count = rejected_count + 1
				end
				operations = operations + 1
				p9g.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			elseif line:find("^population\t") then
				local fields = split_tabs(line)
				if #fields ~= 9 + #P9G_REASONS then fail("P9G population TSV width differs") end
				local source_id, zone_id, biome = text(fields[2], "population source"),
					text(fields[3], "population zone"), text(fields[4], "population biome")
				local faction, bracket = text(fields[5], "population faction"),
					text(fields[6], "population bracket")
				if not source_by_id[source_id] or (faction ~= "accord" and faction ~= "throng") or
						not P9G_BRACKETS[bracket] then
					fail("P9G population identity differs")
				end
				source_semantics(source_id, zone_id, biome, faction, bracket)
				local key = population_key(source_id, zone_id, biome, faction, bracket)
				if populations_seen[key] or (previous_population and
						not less_bytes(previous_population, key)) then
					fail("seed P9G populations are not canonical/unique")
				end
				populations_seen[key], previous_population = true, key
				local eligible = parsed_integer(fields[7], 0, MAX_SAFE, "population eligible")
				local budget = parsed_integer(fields[8], 0, MAX_SAFE, "population budget")
				local accepted = parsed_integer(fields[9], 0, MAX_SAFE, "population accepted")
				local rejected, operation = 0, operations_by_population[key]
				if not operation then
					operation = {budget = 0, accepted = 0, rejections = {}}
					for index = 1, #P9G_REASONS do
						operation.rejections[P9G_REASONS[index]] = 0
					end
				end
				for index = 1, #P9G_REASONS do
					local count = parsed_integer(fields[9 + index], 0, MAX_SAFE,
						"population rejection")
					rejected = rejected + count
					if count ~= operation.rejections[P9G_REASONS[index]] then
						fail("population/operation rejection partition differs")
					end
				end
				if budget > eligible or accepted + rejected ~= budget or
						operation.budget ~= budget or operation.accepted ~= accepted then
					fail("population E/B/accepted invariant differs")
				end
				operations_by_population[key] = nil
				local totals = source_totals[source_id]
				totals.eligible, totals.budget, totals.accepted = totals.eligible + eligible,
					totals.budget + budget, totals.accepted + accepted
				access[source_id][faction] = access[source_id][faction] + accepted
				local bracket_row = parity[source_id][bracket]
				if not bracket_row then
					bracket_row = {accord = {eligible = 0, budget = 0},
						throng = {eligible = 0, budget = 0}}
					parity[source_id][bracket] = bracket_row
				end
				bracket_row[faction].eligible = bracket_row[faction].eligible + eligible
				bracket_row[faction].budget = bracket_row[faction].budget + budget
				population_count = population_count + 1
				p9g.write("seed\t" .. tostring(slot) .. "\t" .. line .. "\n")
			else
				fail("seed evidence row differs")
			end
		end
		assert(file:close())
		for key in pairs(operations_by_population) do
			fail("operation population is absent: " .. key)
		end
		if line_number < 4 or seed_slot ~= slot or seed_identity ~= descriptor.identity or
				population_count < 1 or operations ~= a.operation_count or
				accepted_count ~= a.accepted_count or rejected_count ~= a.rejected_count then
			fail("seed P9G ledger population/Stage-A identity differs")
		end
		total_operations, total_accepted, total_rejected = total_operations + operations,
			total_accepted + accepted_count, total_rejected + rejected_count
	end

	local nonzero_sources, access_gates, parity_gates = 0, 0, 0
	local function safe_product(left, right, label)
		integer(left, 0, MAX_SAFE, label .. " left")
		integer(right, 0, MAX_SAFE, label .. " right")
		if left ~= 0 and right > math.floor(MAX_SAFE / left) then
			fail(label .. " exceeds exact-double integer range")
		end
		return left * right
	end
	for index = 1, #source_rows do
		local row, totals = source_rows[index], source_totals[source_rows[index].id]
		if totals.eligible <= 0 or totals.budget <= 0 or totals.accepted <= 0 then
			fail("P9G source lacks nonzero E/B/accepted: " .. row.id)
		end
		nonzero_sources = nonzero_sources + 1
		local access_required = row.harvest_kind == "healing_herb" or
			row.harvest_kind == "spice" or row.key == "wild_cocoa" or row.key == "rock_salt"
		if access_required then
			for _, faction in ipairs({"accord", "throng"}) do
				if access[row.id][faction] <= 0 then
					fail("P9G required faction access is zero: " .. row.id .. "/" .. faction)
				end
				access_gates = access_gates + 1
			end
		end
		if row.harvest_kind == "healing_herb" or row.harvest_kind == "spice" then
			for bracket, factions in pairs(parity[row.id]) do
				local accord, throng = factions.accord, factions.throng
				if accord.eligible <= 0 or throng.eligible <= 0 then
					fail("P9G parity faction/bracket is absent: " .. row.id .. "/" .. bracket)
				end
				local left = safe_product(accord.budget, throng.eligible,
					"P9G parity cross-product")
				local right = safe_product(throng.budget, accord.eligible,
					"P9G parity cross-product")
				local high, low = math.max(left, right), math.min(left, right)
				if high - low > math.floor(low / 10) then
					fail("P9G exact decade parity inequality failed: " .. row.id .. "/" .. bracket)
				end
				parity_gates = parity_gates + 1
			end
		end
	end
	if nonzero_sources ~= 12 or total_operations ~= total_accepted + total_rejected then
		fail("fleet P9G closed totals differ")
	end

	local artifact_result, stage_a_result, stage_b_result, p9g_result =
		artifact.close(), stage_a.close(), stage_b.close(), p9g.close()
	local receipt = new_final_output(scratch .. "/run-receipt.tsv", stream)
	receipt.write(table.concat({
		"schema\tgrug_wp40_r7_run_receipt_v1\n",
		"proof_scope_fleet\t32_seed_affected_cell_7_tuple_delta_plus_r6_aggregates\n",
		"projection_sha256\t", projection, "\n",
		"accepted_r6_artifact_sha256\t", ACCEPTED_R6_ARTIFACT_SHA256, "\n",
		"production_r6_content_sha256\t", production_content_sha, "\n",
		"p9g_content_sha256\t", p9g_content_sha, "\n",
		"p9g_delta_sha256\t", p9g_delta_sha, "\n",
		"seed_population\t32\n",
		"p9g_source_population\t12\n",
		"inherited_cultural_access_count\t12\n",
		"p9g_nonzero_source_population\t", tostring(nonzero_sources), "\n",
		"p9g_operation_count\t", tostring(total_operations), "\n",
		"p9g_accepted_count\t", tostring(total_accepted), "\n",
		"p9g_rejected_count\t", tostring(total_rejected), "\n",
		"p9g_access_gate_count\t", tostring(access_gates), "\n",
		"p9g_parity_gate_count\t", tostring(parity_gates), "\n",
		"canonical_worker_order\tseed_slot\n",
		"artifact_sha256\t", artifact_result.sha256, "\n",
		"stage_a_sha256\t", stage_a_result.sha256, "\n",
		"stage_b_sha256\t", stage_b_result.sha256, "\n",
		"p9g_sha256\t", p9g_result.sha256, "\n",
	}))
	local receipt_result = receipt.close()
	return {artifact = artifact_result, stage_a = stage_a_result,
		stage_b = stage_b_result, p9g = p9g_result, run_receipt = receipt_result}
end

return module
