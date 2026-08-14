-- Private WP40 T2 extreme-corpus selector. It consumes only fresh data-only
-- scalar records from partition's sole R7 materializer. It owns no raster,
-- displacement, attachment, partition, IPC, or public runtime authority.

local function fail(message)
	error("WP40 geometry extreme: " .. message, 0)
end

local function exact_dependencies(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {deterministic = true, exact = true, raw_sha256 = true,
		scalar_reader = true, seed_corpus = true, source = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	for _, key in ipairs({"deterministic", "exact", "seed_corpus", "source"}) do
		if type(value[key]) ~= "table" or getmetatable(value[key]) ~= nil then
			fail(key .. " dependency is not a plain table")
		end
	end
	if type(value.raw_sha256) ~= "function" then fail("raw SHA dependency missing") end
	if type(value.scalar_reader) ~= "function" then fail("scalar reader missing") end
	if type(value.seed_corpus.extreme_candidate) ~= "function" or
			type(value.seed_corpus.label_seed) ~= "function" then
		fail("seed-corpus helper missing")
	end
end

return function(dependencies)
	exact_dependencies(dependencies)
	local function private_plain_copy(value, seen)
		if type(value) ~= "table" then return value end
		if getmetatable(value) ~= nil then fail("Source contains a metatable") end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local result = {}
		seen[value] = result
		for key, child in pairs(value) do
			result[private_plain_copy(key, seen)] = private_plain_copy(child, seen)
		end
		return result
	end
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	-- Selection policy is session-stable even if the factory caller later
	-- mutates its catalog table.  Intentional Source aliases are retained only
	-- inside this unreachable copy.
	local source = private_plain_copy(dependencies.source)
	local seed_corpus = private_plain_copy(dependencies.seed_corpus)
	local raw_sha256 = dependencies.raw_sha256
	local scalar_reader = dependencies.scalar_reader
	local Q = deterministic.Q
	local selector = {}

	local function dense(value, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain array")
		end
		local count = #value
		for key in pairs(value) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail(label .. " is not dense")
			end
		end
		return count
	end

	local function exact_fields(value, fields, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain table")
		end
		local allowed = {}
		for index = 1, #fields do allowed[fields[index]] = true end
		for key in pairs(value) do
			if type(key) ~= "string" or not allowed[key] then
				fail(label .. " has unknown field " .. tostring(key))
			end
		end
		for index = 1, #fields do
			if value[fields[index]] == nil then fail(label .. " lacks " .. fields[index]) end
		end
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return ("%02x"):format(char:byte())
		end))
	end

	local function decimal_less(a, b)
		if type(a) ~= "string" or type(b) ~= "string" or
				(a ~= "0" and not a:match("^[1-9][0-9]*$")) or
				(b ~= "0" and not b:match("^[1-9][0-9]*$")) then
			fail("seed decimal is not canonical unsigned text")
		end
		return #a < #b or #a == #b and a < b
	end

	local function rational_reduce(numerator, denominator)
		exact.integer(numerator, -exact.MAX_SAFE, exact.MAX_SAFE,
			"score numerator")
		exact.integer(denominator, 1, exact.MAX_SAFE, "score denominator")
		if numerator == 0 then return 0, 1 end
		local divisor = exact.gcd(math.abs(numerator), denominator)
		return numerator / divisor, denominator / divisor
	end

	local function rational_add(an, ad, bn, bd)
		an, ad = rational_reduce(an, ad)
		bn, bd = rational_reduce(bn, bd)
		local divisor = exact.gcd(ad, bd)
		local left_multiplier, right_multiplier = bd / divisor, ad / divisor
		local numerator = exact.safe_sum(exact.safe_signed_product(an,
			left_multiplier, "score addition"), exact.safe_signed_product(bn,
			right_multiplier, "score addition"), "score addition")
		local denominator = exact.safe_product(ad, left_multiplier,
			"score denominator")
		return rational_reduce(numerator, denominator)
	end

	local function rational_mean(numerator, denominator, count)
		exact.integer(count, 1, exact.MAX_SAFE, "score sample count")
		numerator, denominator = rational_reduce(numerator, denominator)
		local divisor = exact.gcd(math.abs(numerator), count)
		return rational_reduce(numerator / divisor,
			exact.safe_product(denominator, count / divisor, "score mean"))
	end

	local function rational_compare(an, ad, bn, bd)
		an, ad = rational_reduce(an, ad)
		bn, bd = rational_reduce(bn, bd)
		if an < 0 and bn >= 0 then return -1 end
		if an >= 0 and bn < 0 then return 1 end
		local comparison = exact.rational_compare(math.abs(an), ad, math.abs(bn), bd)
		return an < 0 and -comparison or comparison
	end

	local expected = {}
	local expected_count = 0
	local function expect_record(family, row, numeric_id)
		local record_key = family .. ":" .. row.id
		if expected[record_key] then fail("duplicate expected scalar record " .. record_key) end
		expected[record_key] = {family = family, id = row.id,
			numeric_id = numeric_id, max_displacement = row.max_displacement,
			source = row}
		expected_count = expected_count + 1
	end
	for index = 1, #source.perimeters do
		expect_record("perimeter", source.perimeters[index], index)
	end
	for index = 1, #source.islands do
		expect_record("island", source.islands[index], index)
	end
	for index = 1, #source.land_edges do
		expect_record("land_edge", source.land_edges[index],
			source.land_edges[index].numeric_id)
	end
	local perimeter_order, island_order, land_order = {}, {}, {}
	for index = 1, #source.perimeters do perimeter_order[index] = source.perimeters[index] end
	table.sort(perimeter_order, function(a, b) return a.id < b.id end)
	local island_arc_seen = {}
	for index = 1, #source.islands do
		local row = source.islands[index]
		if type(row.closed_arc_id) ~= "string" or row.closed_arc_id == "" or
				island_arc_seen[row.closed_arc_id] then
			fail("island closed-arc roster is invalid")
		end
		island_arc_seen[row.closed_arc_id] = true
		island_order[index] = row
	end
	table.sort(island_order, function(a, b) return a.closed_arc_id < b.closed_arc_id end)
	for index = 1, #source.land_edges do
		if source.land_edges[index].max_displacement > 0 then
			land_order[#land_order + 1] = source.land_edges[index]
		end
	end
	table.sort(land_order, function(a, b)
		return a.numeric_id < b.numeric_id
	end)
	for index = 2, #land_order do
		if land_order[index - 1].numeric_id == land_order[index].numeric_id then
			fail("positive land-edge numeric roster is duplicated")
		end
	end

	local coast_segments = {}
	for index = 1, #source.perimeter_spans do
		local span = source.perimeter_spans[index]
		local by_segment = coast_segments[span.perimeter_id] or {}
		coast_segments[span.perimeter_id] = by_segment
		for segment = span.first_segment - 1, span.last_segment - 1 do
			by_segment[segment] = true
		end
	end

	local function sample_less(a, b)
		return a.source_segment < b.source_segment or
			a.source_segment == b.source_segment and a.local_station < b.local_station
	end

	local function validate_records(records)
		dense(records, "scalar records")
		if #records ~= expected_count then fail("scalar record roster count changed") end
		local by_key = {}
		for record_index = 1, #records do
			local record = records[record_index]
			exact_fields(record, {"family", "id", "numeric_id", "max_displacement",
				"topology_ceiling_nodes", "samples"}, "scalar record")
			local record_key = record.family .. ":" .. record.id
			local wanted = expected[record_key]
			if not wanted or by_key[record_key] or record.numeric_id ~= wanted.numeric_id or
					record.max_displacement ~= wanted.max_displacement then
				fail("scalar record roster or identity changed")
			end
			exact.integer(record.max_displacement, 0, 96, "record displacement")
			exact.integer(record.topology_ceiling_nodes, 0, record.max_displacement,
				"record topology ceiling")
			dense(record.samples, record_key .. " samples")
			local identities = {}
			for sample_index = 1, #record.samples do
				local sample = record.samples[sample_index]
				exact_fields(sample, {"x", "z", "scalar_q", "source_segment",
					"local_station"}, record_key .. " sample")
				exact.integer(sample.x, -2147483648, 2147483647, "sample x")
				exact.integer(sample.z, -2147483648, 2147483647, "sample z")
				exact.integer(sample.scalar_q,
					-record.topology_ceiling_nodes * Q,
					record.topology_ceiling_nodes * Q, "selected scalar")
				exact.integer(sample.source_segment, 0, 2147483647,
					"sample source segment")
				exact.integer(sample.local_station, 0, 2147483647,
					"sample local station")
				local identity = sample.source_segment .. ":" .. sample.local_station
				if identities[identity] then fail(record_key .. " repeats scalar identity") end
				identities[identity] = true
			end
			by_key[record_key] = record
		end
		for record_key in pairs(expected) do
			if not by_key[record_key] then fail("scalar record roster omitted " .. record_key) end
		end
		return by_key
	end

	local function append_score(samples, record, selected, sequence, identity_family,
			identity_id)
		if record.max_displacement <= 0 then
			fail(record.family .. ":" .. record.id .. " has no scoring amplitude")
		end
		local ordered = {}
		for sample_index = 1, #samples do
			if selected(samples[sample_index]) then ordered[#ordered + 1] = samples[sample_index] end
		end
		table.sort(ordered, sample_less)
		local previous_segment, previous_local
		for sample_index = 1, #ordered do
			local sample = ordered[sample_index]
			if previous_segment ~= nil and (sample.source_segment < previous_segment or
					sample.source_segment == previous_segment and
					sample.local_station <= previous_local) then
				fail("scalar selector sequence is not strict")
			end
			previous_segment, previous_local = sample.source_segment, sample.local_station
			sequence[#sequence + 1] = {family = identity_family or record.family,
				id = identity_id or record.id,
				numeric_id = record.numeric_id,
				topology_ceiling_nodes = record.topology_ceiling_nodes,
				x = sample.x, z = sample.z, scalar_q = sample.scalar_q,
				source_segment = sample.source_segment,
				local_station = sample.local_station,
				amplitude_q = record.max_displacement * Q}
		end
	end

	local expected_identity = {
		coast = {count = 23552,
			sha256 = "0be6420d4f27c8e885f1c4af23ab98f0551c658e07715a1384e47629ba69a662"},
		noncoast = {count = 42565,
			sha256 = "8070e4c25a86397aaa04e474b9d4917e4d79ac8def9998c111ae76747b32ca38"},
	}

	local function identity_summary(sequence)
		local bytes = {}
		for index = 1, #sequence do
			local sample = sequence[index]
			bytes[index] = table.concat({sample.family, sample.id,
				tostring(sample.numeric_id), tostring(sample.source_segment),
				tostring(sample.local_station), tostring(sample.x), tostring(sample.z),
				tostring(sample.amplitude_q)}, ";")
		end
		return #sequence, hex(raw_sha256(table.concat(bytes, "\n") .. "\n"))
	end

	local function score_sequence(sequence, label)
		if #sequence == 0 then fail(label .. " scalar sequence is empty") end
		local numerator, denominator = 0, 1
		local bytes = {}
		for index = 1, #sequence do
			local sample = sequence[index]
			numerator, denominator = rational_add(numerator, denominator,
				sample.scalar_q, sample.amplitude_q)
			bytes[index] = table.concat({sample.family, sample.id,
				tostring(sample.numeric_id), tostring(sample.topology_ceiling_nodes),
				tostring(sample.source_segment), tostring(sample.local_station),
				tostring(sample.x), tostring(sample.z), tostring(sample.scalar_q),
				tostring(sample.amplitude_q)}, ";")
		end
		numerator, denominator = rational_mean(numerator, denominator, #sequence)
		return numerator, denominator, #sequence,
			hex(raw_sha256(table.concat(bytes, "\n") .. "\n"))
	end

	local function score_seed(seed_row)
		exact_fields(seed_row, {"label", "digest", "first8", "decimal"}, "seed row")
		deterministic.validate_seed(seed_row.decimal)
		local by_key = validate_records(scalar_reader(seed_row.decimal))
		local coast, noncoast = {}, {}
		for index = 1, #perimeter_order do
			local row = perimeter_order[index]
			local record = by_key["perimeter:" .. row.id]
			if record.max_displacement > 0 then
				local segments = coast_segments[row.id] or {}
				append_score(record.samples, record,
					function(sample) return segments[sample.source_segment] == true end,
					coast)
			end
		end
		for index = 1, #island_order do
			local row = island_order[index]
			local record = by_key["island:" .. row.id]
			if record.max_displacement > 0 then
				append_score(record.samples, record, function() return true end, coast,
					"island_arc", row.closed_arc_id)
			end
		end
		for index = 1, #land_order do
			local row = land_order[index]
			local record = by_key["land_edge:" .. row.id]
			if record.max_displacement > 0 then
				append_score(record.samples, record, function() return true end, noncoast)
			end
		end
		local coast_identity_count, coast_identity_sha = identity_summary(coast)
		local noncoast_identity_count, noncoast_identity_sha = identity_summary(noncoast)
		if coast_identity_count ~= expected_identity.coast.count or
				coast_identity_sha ~= expected_identity.coast.sha256 then
			fail("coast scalar identity roster changed")
		end
		if noncoast_identity_count ~= expected_identity.noncoast.count or
				noncoast_identity_sha ~= expected_identity.noncoast.sha256 then
			fail("noncoast scalar identity roster changed")
		end
		local cn, cd, cc, ch = score_sequence(coast, "coast")
		local nn, nd, nc, nh = score_sequence(noncoast, "noncoast")
		return {label = seed_row.label, digest = seed_row.digest,
			first8 = seed_row.first8, decimal = seed_row.decimal,
			coast_n = cn, coast_d = cd, coast_sample_count = cc,
			coast_sequence_sha256 = ch,
			coast_identity_sha256 = coast_identity_sha,
			noncoast_n = nn, noncoast_d = nd, noncoast_sample_count = nc,
			noncoast_sequence_sha256 = nh,
			noncoast_identity_sha256 = noncoast_identity_sha}
	end

	local fixed_decimal = {}
	if #seed_corpus.fixed ~= 27 and #seed_corpus.fixed ~= 31 then
		fail("fixed corpus must contain either base 27 or measured 31 seeds")
	end
	for index = 1, 27 do
		local decimal = seed_corpus.fixed[index]
		deterministic.validate_seed(decimal)
		if fixed_decimal[decimal] then fail("base fixed corpus seed is duplicated") end
		fixed_decimal[decimal] = true
	end

	local function score_candidate(index)
		exact.integer(index, 0, 4095, "candidate index")
		local seed_row = seed_corpus.extreme_candidate(index, raw_sha256)
		if fixed_decimal[seed_row.decimal] then
			return {candidate_index = index, label = seed_row.label,
				digest = seed_row.digest, first8 = seed_row.first8,
				decimal = seed_row.decimal, status = "skipped_fixed"}
		end
		local result = score_seed(seed_row)
		result.candidate_index = index
		result.status = "scored"
		return result
	end

	local skipped_fields = {"candidate_index", "label", "digest", "first8",
		"decimal", "status"}
	local scored_fields = {"candidate_index", "label", "digest", "first8",
		"decimal", "status", "coast_n", "coast_d", "coast_sample_count",
		"coast_sequence_sha256", "coast_identity_sha256", "noncoast_n",
		"noncoast_d", "noncoast_sample_count", "noncoast_sequence_sha256",
		"noncoast_identity_sha256"}
	local function validate_candidate_row(row)
		if type(row) ~= "table" then fail("candidate row is not a plain table") end
		exact.integer(row.candidate_index, 0, 4095, "candidate row index")
		local derived = seed_corpus.extreme_candidate(row.candidate_index, raw_sha256)
		local expected_status = fixed_decimal[derived.decimal] and
			"skipped_fixed" or "scored"
		exact_fields(row, expected_status == "scored" and scored_fields or
			skipped_fields, "candidate row")
		if row.status ~= expected_status or row.label ~= derived.label or
				row.digest ~= derived.digest or row.first8 ~= derived.first8 or
				row.decimal ~= derived.decimal then
			fail("candidate identity or status changed")
		end
		if row.status == "scored" then
			local coast_n, coast_d = rational_reduce(row.coast_n, row.coast_d)
			local noncoast_n, noncoast_d = rational_reduce(row.noncoast_n,
				row.noncoast_d)
			if coast_n ~= row.coast_n or coast_d ~= row.coast_d or
					noncoast_n ~= row.noncoast_n or noncoast_d ~= row.noncoast_d then
				fail("candidate score is not reduced")
			end
			exact.integer(row.coast_sample_count, 1, exact.MAX_SAFE,
				"coast sample count")
			exact.integer(row.noncoast_sample_count, 1, exact.MAX_SAFE,
				"noncoast sample count")
			if row.coast_sample_count ~= expected_identity.coast.count or
					row.coast_identity_sha256 ~= expected_identity.coast.sha256 then
				fail("candidate coast identity roster changed")
			end
			if row.noncoast_sample_count ~= expected_identity.noncoast.count or
					row.noncoast_identity_sha256 ~= expected_identity.noncoast.sha256 then
				fail("candidate noncoast identity roster changed")
			end
			for _, field in ipairs({"coast_sequence_sha256", "coast_identity_sha256",
					"noncoast_sequence_sha256", "noncoast_identity_sha256"}) do
				if type(row[field]) ~= "string" or #row[field] ~= 64 or
						not row[field]:match("^[0-9a-f]+$") then
					fail("candidate " .. field .. " is not lowercase SHA-256")
				end
			end
		end
		return row
	end

	local function score_better(candidate, best, family, direction)
		if not best then return true end
		local prefix = family == "coast" and "coast_" or "noncoast_"
		local comparison = rational_compare(candidate[prefix .. "n"],
			candidate[prefix .. "d"], best[prefix .. "n"], best[prefix .. "d"])
		if comparison == 0 then return decimal_less(candidate.decimal, best.decimal) end
		return direction == "greatest" and comparison > 0 or
			direction == "least" and comparison < 0
	end

	local slot_definitions = {
		{id = "greatest_coast", family = "coast", direction = "greatest"},
		{id = "least_coast", family = "coast", direction = "least"},
		{id = "greatest_noncoast", family = "noncoast", direction = "greatest"},
		{id = "least_noncoast", family = "noncoast", direction = "least"},
	}

	local function select_slots(rows)
		dense(rows, "candidate rows")
		if #rows ~= 4096 then fail("global selection requires all 4096 candidates") end
		local by_index, decimal_seen = {}, {}
		for row_index = 1, #rows do
			local row = validate_candidate_row(rows[row_index])
			if by_index[row.candidate_index] then fail("candidate index is duplicated") end
			if decimal_seen[row.decimal] then fail("candidate seed decimal is duplicated") end
			by_index[row.candidate_index] = row
			decimal_seen[row.decimal] = true
		end
		for index = 0, 4095 do
			if not by_index[index] then fail("candidate index is missing") end
		end
		local chosen_decimal, slots = {}, {}
		for slot_index = 1, #slot_definitions do
			local definition, best = slot_definitions[slot_index]
			for candidate_index = 0, 4095 do
				local candidate = by_index[candidate_index]
				if candidate.status == "scored" and
						not chosen_decimal[candidate.decimal] and
						score_better(candidate, best, definition.family,
							definition.direction) then best = candidate end
			end
			if not best then fail("extreme slot has no candidate") end
			chosen_decimal[best.decimal] = true
			slots[slot_index] = {slot = 27 + slot_index, id = definition.id,
				family = definition.family, direction = definition.direction,
				candidate_index = best.candidate_index, label = best.label,
				digest = best.digest, first8 = best.first8, decimal = best.decimal,
				score_n = best[(definition.family == "coast" and "coast_" or
					"noncoast_") .. "n"],
				score_d = best[(definition.family == "coast" and "coast_" or
					"noncoast_") .. "d"]}
		end
		return slots
	end

	local function staging_seed(slots)
		dense(slots, "extreme slots")
		if #slots ~= 4 then fail("staging selection requires four extreme slots") end
		if #seed_corpus.fixed ~= 27 and #seed_corpus.fixed ~= 31 then
			fail("fixed corpus must contain either base 27 or measured 31 seeds")
		end
		local used, slot_seen = {}, {}
		for index = 1, #seed_corpus.fixed do used[seed_corpus.fixed[index]] = true end
		for index = 1, #slots do
			local slot = slots[index]
			exact_fields(slot, {"slot", "id", "family", "direction",
				"candidate_index", "label", "digest", "first8", "decimal",
				"score_n", "score_d"}, "extreme slot")
			local definition = slot_definitions[index]
			local candidate = seed_corpus.extreme_candidate(slot.candidate_index,
				raw_sha256)
			local reduced_n, reduced_d = rational_reduce(slot.score_n, slot.score_d)
			if slot.slot ~= 27 + index or slot.id ~= definition.id or
					slot.family ~= definition.family or
					slot.direction ~= definition.direction or
					slot.label ~= candidate.label or slot.digest ~= candidate.digest or
					slot.first8 ~= candidate.first8 or slot.decimal ~= candidate.decimal or
					reduced_n ~= slot.score_n or reduced_d ~= slot.score_d or
					slot_seen[slot.decimal] or (#seed_corpus.fixed == 31 and
					seed_corpus.fixed[27 + index] ~= slot.decimal) then
				fail("extreme slot identity is invalid")
			end
			slot_seen[slot.decimal] = true
			used[slot.decimal] = true
		end
		for label_index = 8, 9999 do
			local row = seed_corpus.label_seed(("grudgelands-wp40-seed-%02d"):format(
				label_index), raw_sha256)
			if not used[row.decimal] then
				row.status = "T2_STAGING_ONLY"
				return row
			end
		end
		fail("no unique staging label is available")
	end

	local candidate_header = "candidate_index\tstatus\tlabel\tdigest\tfirst8\tdecimal\tcoast_n\tcoast_d\tcoast_count\tcoast_sequence_sha256\tcoast_identity_sha256\tnoncoast_n\tnoncoast_d\tnoncoast_count\tnoncoast_sequence_sha256\tnoncoast_identity_sha256"
	local function candidate_line(row)
		return table.concat({tostring(row.candidate_index), row.status,
				row.label, row.digest, row.first8, row.decimal,
				tostring(row.coast_n or ""), tostring(row.coast_d or ""),
				tostring(row.coast_sample_count or ""), row.coast_sequence_sha256 or "",
				row.coast_identity_sha256 or "",
				tostring(row.noncoast_n or ""), tostring(row.noncoast_d or ""),
				tostring(row.noncoast_sample_count or ""),
				row.noncoast_sequence_sha256 or "",
				row.noncoast_identity_sha256 or ""}, "\t")
	end

	local function indexed_rows(rows, expected_count)
		dense(rows, "candidate artifact rows")
		if expected_count and #rows ~= expected_count then
			fail("candidate artifact row count changed")
		end
		local by_index, decimal_seen = {}, {}
		for row_index = 1, #rows do
			local row = validate_candidate_row(rows[row_index])
			if by_index[row.candidate_index] then fail("candidate index is duplicated") end
			if decimal_seen[row.decimal] then fail("candidate seed decimal is duplicated") end
			by_index[row.candidate_index] = row
			decimal_seen[row.decimal] = true
		end
		return by_index
	end

	local function candidate_blob(rows)
		local by_index = indexed_rows(rows, 4096)
		local lines = {candidate_header}
		for candidate_index = 0, 4095 do
			local row = by_index[candidate_index]
			if not row then fail("candidate index is missing") end
			lines[#lines + 1] = candidate_line(row)
		end
		return table.concat(lines, "\n") .. "\n"
	end

	local pin_fields = {"source_checksum", "boundary_policy_checksum",
		"authority_dag_sha256", "authority_commit", "authority_tree",
		"interpreter_id", "interpreter_launcher", "interpreter_path",
		"interpreter_version", "interpreter_sha256", "measurement_scope",
		"stage2_status", "scorer_schema"}
	local function validate_pins(pins)
		exact_fields(pins, pin_fields, "candidate shard pins")
		for _, field in ipairs({"source_checksum", "boundary_policy_checksum",
				"authority_dag_sha256", "interpreter_sha256"}) do
			if type(pins[field]) ~= "string" or #pins[field] ~= 64 or
					not pins[field]:match("^[0-9a-f]+$") then
				fail("candidate shard " .. field .. " is invalid")
			end
		end
		for _, field in ipairs({"authority_commit", "authority_tree"}) do
			if type(pins[field]) ~= "string" or #pins[field] ~= 40 or
					not pins[field]:match("^[0-9a-f]+$") then
				fail("candidate shard " .. field .. " is invalid")
			end
		end
		if pins.scorer_schema ~= "grug_wp40_extreme_selector_e0_v1" then
			fail("candidate shard scorer schema changed")
		end
		if pins.interpreter_id ~= "puc_lua51" and pins.interpreter_id ~= "luajit" and
				pins.interpreter_id ~= "test_only" then
			fail("candidate shard interpreter evidence is invalid")
		end
		if type(pins.interpreter_launcher) ~= "string" or
				type(pins.interpreter_path) ~= "string" or
				type(pins.interpreter_version) ~= "string" or
				pins.interpreter_launcher == "" or pins.interpreter_path == "" or
				pins.interpreter_version == "" or
				pins.interpreter_launcher:find("[\t\r\n]") or
				pins.interpreter_path:find("[\t\r\n]") or
				pins.interpreter_version:find("[\t\r\n]") then
			fail("candidate shard interpreter provenance is invalid")
		end
		if pins.measurement_scope ~= "R7_SCALAR_MEASUREMENT_ONLY" or
				pins.stage2_status ~= "blocked" then
			fail("candidate shard scope status changed")
		end
		return pins
	end

	local function rows_blob(rows)
		local lines = {}
		for index = 1, #rows do lines[index] = candidate_line(rows[index]) end
		return table.concat(lines, "\n") .. "\n"
	end

	local function candidate_shard(rows, first_index, last_index, pins)
		exact.integer(first_index, 0, 4095, "candidate shard first index")
		exact.integer(last_index, first_index, 4095, "candidate shard last index")
		validate_pins(pins)
		dense(rows, "candidate shard rows")
		if #rows ~= last_index - first_index + 1 then
			fail("candidate shard range/count changed")
		end
		local copy, decimal_seen = {}, {}
		for index = 1, #rows do
			local row = validate_candidate_row(rows[index])
			if row.candidate_index ~= first_index + index - 1 then
				fail("candidate shard row order changed")
			end
			if decimal_seen[row.decimal] then fail("candidate seed decimal is duplicated") end
			decimal_seen[row.decimal] = true
			copy[index] = private_plain_copy(row)
		end
		local pin_copy = private_plain_copy(pins)
		return {schema = "grug_wp40_extreme_candidate_shard_v1",
			first_index = first_index, last_index = last_index, count = #copy,
			pins = pin_copy, rows_sha256 = hex(raw_sha256(rows_blob(copy))), rows = copy}
	end

	local shard_fields = {"schema", "first_index", "last_index", "count",
		"pins", "rows_sha256", "rows"}
	local function validate_candidate_shard(shard)
		exact_fields(shard, shard_fields, "candidate shard")
		if shard.schema ~= "grug_wp40_extreme_candidate_shard_v1" then
			fail("candidate shard schema changed")
		end
		exact.integer(shard.first_index, 0, 4095, "candidate shard first index")
		exact.integer(shard.last_index, shard.first_index, 4095,
			"candidate shard last index")
		exact.integer(shard.count, 1, 4096, "candidate shard count")
		validate_pins(shard.pins)
		if type(shard.rows_sha256) ~= "string" or #shard.rows_sha256 ~= 64 or
				not shard.rows_sha256:match("^[0-9a-f]+$") then
			fail("candidate shard row digest is invalid")
		end
		dense(shard.rows, "candidate shard rows")
		if shard.count ~= #shard.rows or
				shard.count ~= shard.last_index - shard.first_index + 1 then
			fail("candidate shard range/count changed")
		end
		local decimal_seen = {}
		for index = 1, #shard.rows do
			local row = validate_candidate_row(shard.rows[index])
			if row.candidate_index ~= shard.first_index + index - 1 then
				fail("candidate shard row order changed")
			end
			if decimal_seen[row.decimal] then fail("candidate seed decimal is duplicated") end
			decimal_seen[row.decimal] = true
		end
		if hex(raw_sha256(rows_blob(shard.rows))) ~= shard.rows_sha256 then
			fail("candidate shard row digest changed")
		end
		return shard
	end

	local function shard_blob(shard)
		validate_candidate_shard(shard)
		local pins = shard.pins
		local lines = {"schema\t" .. shard.schema,
			"range\t" .. shard.first_index .. "\t" .. shard.last_index .. "\t" ..
				tostring(shard.count),
			"source_checksum\t" .. pins.source_checksum,
			"boundary_policy_checksum\t" .. pins.boundary_policy_checksum,
			"authority_dag_sha256\t" .. pins.authority_dag_sha256,
			"authority_commit\t" .. pins.authority_commit,
			"authority_tree\t" .. pins.authority_tree,
			"interpreter_id\t" .. pins.interpreter_id,
			"interpreter_launcher\t" .. pins.interpreter_launcher,
			"interpreter_path\t" .. pins.interpreter_path,
			"interpreter_version\t" .. pins.interpreter_version,
			"interpreter_sha256\t" .. pins.interpreter_sha256,
			"measurement_scope\t" .. pins.measurement_scope,
			"stage2_status\t" .. pins.stage2_status,
			"scorer_schema\t" .. pins.scorer_schema,
			"rows_sha256\t" .. shard.rows_sha256, candidate_header}
		for index = 1, #shard.rows do lines[#lines + 1] = candidate_line(shard.rows[index]) end
		return table.concat(lines, "\n") .. "\n"
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

	local function parsed_integer(text, label)
		local value = tonumber(text)
		if not value or value % 1 ~= 0 or tostring(value) ~= text then
			fail(label .. " is not canonical integer text")
		end
		return value
	end

	local function parse_shard_blob(blob)
		if type(blob) ~= "string" or blob == "" or blob:sub(-1) ~= "\n" or
				blob:find("\r", 1, true) or blob:find(string.char(0), 1, true) then
			fail("candidate shard blob framing is invalid")
		end
		local lines = {}
		for line in blob:gmatch("([^\n]*)\n") do
			if line == "" then fail("candidate shard blob has an empty line") end
			lines[#lines + 1] = line
		end
		if #lines < 18 or lines[17] ~= candidate_header then
			fail("candidate shard blob header changed")
		end
		local expected_headers = {"schema", "range", "source_checksum",
			"boundary_policy_checksum", "authority_dag_sha256", "authority_commit",
			"authority_tree", "interpreter_id", "interpreter_launcher", "interpreter_path",
			"interpreter_version", "interpreter_sha256",
			"measurement_scope", "stage2_status", "scorer_schema", "rows_sha256"}
		local headers = {}
		for index = 1, 16 do
			local fields = split_tabs(lines[index])
			if fields[1] ~= expected_headers[index] then
				fail("candidate shard blob header order changed")
			end
			headers[index] = fields
		end
		if #headers[1] ~= 2 or #headers[2] ~= 4 then
			fail("candidate shard blob header width changed")
		end
		for index = 3, 16 do if #headers[index] ~= 2 then
			fail("candidate shard blob header width changed") end end
		local rows = {}
		for line_index = 18, #lines do
			local fields = split_tabs(lines[line_index])
			if #fields ~= 16 then fail("candidate shard row width changed") end
			local row = {candidate_index = parsed_integer(fields[1], "candidate index"),
				status = fields[2], label = fields[3], digest = fields[4],
				first8 = fields[5], decimal = fields[6]}
			if row.status == "scored" then
				row.coast_n = parsed_integer(fields[7], "coast score numerator")
				row.coast_d = parsed_integer(fields[8], "coast score denominator")
				row.coast_sample_count = parsed_integer(fields[9], "coast count")
				row.coast_sequence_sha256 = fields[10]
				row.coast_identity_sha256 = fields[11]
				row.noncoast_n = parsed_integer(fields[12], "noncoast score numerator")
				row.noncoast_d = parsed_integer(fields[13], "noncoast score denominator")
				row.noncoast_sample_count = parsed_integer(fields[14], "noncoast count")
				row.noncoast_sequence_sha256 = fields[15]
				row.noncoast_identity_sha256 = fields[16]
			else
				for field_index = 7, 16 do
					if fields[field_index] ~= "" then
						fail("skipped candidate shard row has score data")
					end
				end
			end
			rows[#rows + 1] = row
		end
		local shard = {schema = headers[1][2],
			first_index = parsed_integer(headers[2][2], "candidate shard first"),
			last_index = parsed_integer(headers[2][3], "candidate shard last"),
			count = parsed_integer(headers[2][4], "candidate shard count"),
			pins = {source_checksum = headers[3][2],
				boundary_policy_checksum = headers[4][2],
				authority_dag_sha256 = headers[5][2], authority_commit = headers[6][2],
				authority_tree = headers[7][2], interpreter_id = headers[8][2],
				interpreter_launcher = headers[9][2], interpreter_path = headers[10][2],
				interpreter_version = headers[11][2], interpreter_sha256 = headers[12][2],
				measurement_scope = headers[13][2], stage2_status = headers[14][2],
				scorer_schema = headers[15][2]},
			rows_sha256 = headers[16][2], rows = rows}
		return validate_candidate_shard(shard)
	end

	local function merge_shards(shards, pins)
		dense(shards, "candidate shards")
		validate_pins(pins)
		local by_index, decimal_seen = {}, {}
		for shard_index = 1, #shards do
			local shard = validate_candidate_shard(shards[shard_index])
			for _, field in ipairs(pin_fields) do
				if shard.pins[field] ~= pins[field] then fail("candidate shard pins differ") end
			end
			for row_index = 1, #shard.rows do
				local row = shard.rows[row_index]
				if by_index[row.candidate_index] then fail("candidate shards overlap") end
				if decimal_seen[row.decimal] then fail("candidate seed decimal is duplicated") end
				by_index[row.candidate_index] = row
				decimal_seen[row.decimal] = true
			end
		end
		local merged = {}
		for index = 0, 4095 do
			if not by_index[index] then fail("candidate shards do not cover 0..4095") end
			merged[index + 1] = private_plain_copy(by_index[index])
		end
		return merged
	end

	selector.score_seed = score_seed
	selector.score_candidate = score_candidate
	selector.validate_candidate_row = validate_candidate_row
	selector.select_slots = select_slots
	selector.staging_seed = staging_seed
	selector.candidate_blob = candidate_blob
	selector.candidate_shard = candidate_shard
	selector.validate_candidate_shard = validate_candidate_shard
	selector.shard_blob = shard_blob
	selector.parse_shard_blob = parse_shard_blob
	selector.merge_shards = merge_shards
	selector.rational_add = rational_add
	selector.rational_mean = rational_mean
	selector.rational_compare = rational_compare
	selector.decimal_less = decimal_less
	return selector
end
