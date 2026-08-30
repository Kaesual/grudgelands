-- Exhaustive R6 evidence reducer. Settlement stays in production-owned fixture
-- seams; this module only partitions immutable populations and merges ledgers.

return function(loader)
	local common, fixtures = loader.common, loader.fixtures
	local Y_CELLS = {-4, -13, -26, -38, -53, -78, -100, -188}
	local OWNER_MIN_X, OWNER_MAX_X = -3792, 3728
	local OWNER_MIN_Z, OWNER_MAX_Z = -3392, 3328
	local QUERY_MIN_X, QUERY_MAX_X = -3740, 3740
	local QUERY_MIN_Z, QUERY_MAX_Z = -3340, 3340
	local HORIZONTAL_COLUMNS = 49980561
	local PILOT_SHARD_COLUMNS = {
		7140108, 7138080, 7138080, 7140693, 7141200, 7141200, 7141200,
	}
	local R2_BODY = "1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b"
	local module = {}
	local seed_rows = common.tsv(loader.repo ..
		"/docs/research/wp40-simple-map-r6-seed-corpus.tsv")
	local frozen_roster = dofile(loader.repo ..
		"/tools/wp40/r6/census_roster.lua")
	local finalizer = dofile(loader.repo .. "/tools/wp40/r6/finalizer.lua")(loader)
	local race_assignments = {}
	do
		local projection = fixtures.projection()
		for index = 1, #projection.race_regions do
			local row = projection.race_regions[index]
			race_assignments[row.race] = {g1 = row.g1, g2 = row.g2}
		end
	end

	local function add(map, key, value) map[key] = (map[key] or 0) + (value or 1) end

	local function new_horizontal_state()
		local state = {coverage = {}, cultural_candidates = {}, cultural_slots = {},
			decoration_candidates = {}, decoration_settlement = {}, rejections = {},
			witnesses = {}, apex_overlaps = 0}
		for index = 1, #fixtures.cultural do
			local key = fixtures.cultural[index].key
			for _, rate in ipairs({"concentrated", "ordinary"}) do
				state.cultural_candidates[key .. "\0" .. rate] =
					{eligible = 0, budget = 0, candidates = 0}
				state.cultural_slots[key .. "\0" .. rate] = {accepted = 0, reserved = 0}
			end
		end
		for index = 1, #fixtures.decorations do
			local id = fixtures.decorations[index].id
			state.decoration_candidates[id] = {eligible = 0, budget = 0, candidates = 0}
			state.decoration_settlement[id] = {accepted = 0, emitted = 0, reserved = 0}
		end
		return state
	end

	local function aggregate_groups(state, groups)
		for index = 1, #groups do
			local group = groups[index]
			if group.kind == 1 then
				local row = fixtures.cultural[group.catalog]
				local rate = group.parameter == 1024 and "concentrated" or "ordinary"
				local aggregate = state.cultural_candidates[row.key .. "\0" .. rate]
				aggregate.eligible = aggregate.eligible + group.eligible
				aggregate.budget = aggregate.budget + group.budget
				aggregate.candidates = aggregate.candidates + group.candidates
			else
				local row = fixtures.decorations[group.catalog]
				local aggregate = state.decoration_candidates[row.id]
				aggregate.eligible = aggregate.eligible + group.eligible
				aggregate.budget = aggregate.budget + group.budget
				aggregate.candidates = aggregate.candidates + group.candidates
			end
		end
	end

	local function merge_owner(state, owner)
		for key, row in pairs(owner.cultural) do
			local aggregate = state.cultural_slots[key]
			aggregate.accepted = aggregate.accepted + row.accepted
			aggregate.reserved = aggregate.reserved + row.reserved
		end
		for id, row in pairs(owner.decorations) do
			local aggregate = state.decoration_settlement[id]
			aggregate.accepted = aggregate.accepted + row.accepted
			aggregate.emitted = aggregate.emitted + row.emitted
			aggregate.reserved = aggregate.reserved + row.reserved
		end
		for key, count in pairs(owner.rejections) do add(state.rejections, key, count) end
		state.apex_overlaps = state.apex_overlaps + owner.apex_overlaps
		for key, witness in pairs(owner.witnesses) do
			if not state.witnesses[key] then state.witnesses[key] = witness end
		end
	end

	local function scan_horizontal_loaded(loaded, partition_count, residue)
		local state = new_horizontal_state()
		local owner_ordinal = 0
		for owner_z = OWNER_MIN_Z, OWNER_MAX_Z, 80 do
			for owner_x = OWNER_MIN_X, OWNER_MAX_X, 80 do
				if owner_ordinal % partition_count == residue then
					local owner_cultural, owner_decorations = {}, {}
					for cell_z = owner_z / 16, owner_z / 16 + 4 do
						for cell_x = owner_x / 16, owner_x / 16 + 4 do
							local cultural, decorations, groups, coverage, column_count =
								loaded.planner_fixture.build_cell(cell_x, cell_z)
							state.column_population =
								(state.column_population or 0) + column_count
							aggregate_groups(state, groups)
							for index = 1, #coverage do
								add(state.coverage, coverage[index].zone_id .. "\0" ..
									coverage[index].biome, coverage[index].count)
							end
							for index = 1, #cultural do
								owner_cultural[#owner_cultural + 1] = cultural[index]
							end
							for index = 1, #decorations do
								owner_decorations[#owner_decorations + 1] = decorations[index]
							end
						end
					end
					merge_owner(state, loaded.settlement_fixture.scan_horizontal_owner(
						owner_x, owner_z, owner_cultural, owner_decorations))
				end
				owner_ordinal = owner_ordinal + 1
			end
		end
		state.owner_population = owner_ordinal
		local expected_columns
		if partition_count == 1 and residue == 0 then
			expected_columns = HORIZONTAL_COLUMNS
		elseif partition_count == 7 and residue >= 0 and residue <= 6 then
			expected_columns = PILOT_SHARD_COLUMNS[residue + 1]
		else
			common.fail("unsupported horizontal evidence partition")
		end
		if state.column_population ~= expected_columns then
			common.fail("horizontal evidence column population differs")
		end
		if state.apex_overlaps ~= 0 then
			common.fail("horizontal evidence overlaps an apex socket")
		end
		return state
	end

	local function select_census(loaded)
		local buckets = {}
		for _, race in ipairs({"dwarf", "elf", "human", "orc", "troll", "undead"}) do
			buckets[race .. "\0lower"], buckets[race .. "\0frontier"] = {}, {}
		end
		for cell_z = math.ceil(QUERY_MIN_Z / 16), math.floor((QUERY_MAX_Z - 15) / 16) do
			for cell_x = math.ceil(QUERY_MIN_X / 16), math.floor((QUERY_MAX_X - 15) / 16) do
				local race, zone_numeric, zone_id
				local valid = true
				for z = cell_z * 16, cell_z * 16 + 15 do
					for x = cell_x * 16, cell_x * 16 + 15 do
						local water, numeric, id, _, current_race =
							loaded.planner_source.column_values_at(x, z)
						if (water ~= "land" and water ~= "planned_water") or
								not current_race or
								loaded.horizontal.static_exclusion_values_at(x, z) ~= nil then
							valid = false break
						end
						if race and (race ~= current_race or zone_numeric ~= numeric) then
							valid = false break
						end
						race, zone_numeric, zone_id = current_race, numeric, id
					end
					if not valid then break end
				end
				if valid then
					local zone = loader.source.zones[zone_numeric]
					local bucket = zone.level_max <= 30 and "lower" or
						(zone.level_min >= 31 and "frontier" or nil)
					if not bucket then common.fail("census zone straddles bucket boundary") end
					local digest = loaded.hash.digest_hex("evidence_cell_rank_v1", "",
						{R2_BODY, race, bucket, cell_x, cell_z})
					local list = buckets[race .. "\0" .. bucket]
					list[#list + 1] = {race = race, bucket = bucket, cell_x = cell_x,
						cell_z = cell_z, zone_id = zone_id, level_min = zone.level_min,
						level_max = zone.level_max, digest = digest}
				end
			end
		end
		local selected = {}
		for key, list in pairs(buckets) do
			table.sort(list, function(a, b)
				if a.digest ~= b.digest then
					return loaded.hash.less_bytes(a.digest, b.digest)
				end
				if a.cell_z ~= b.cell_z then return a.cell_z < b.cell_z end
				return a.cell_x < b.cell_x
			end)
			if #list < 4 then common.fail("census bucket has fewer than four cells: " .. key) end
			for index = 1, 4 do selected[#selected + 1] = list[index] end
		end
		table.sort(selected, function(a, b)
			if a.race ~= b.race then return loaded.hash.less_bytes(a.race, b.race) end
			if a.bucket ~= b.bucket then return loaded.hash.less_bytes(a.bucket, b.bucket) end
			if a.cell_z ~= b.cell_z then return a.cell_z < b.cell_z end
			return a.cell_x < b.cell_x
		end)
		if #selected ~= 48 then common.fail("census roster population differs") end
		return selected
	end

	local function roster_bytes(roster)
		local lines = {}
		for index = 1, #roster do
			local row = roster[index]
			lines[index] = table.concat({row.race, row.bucket, row.cell_z,
				row.cell_x, row.digest, row.zone_id, row.level_min,
				row.level_max}, "\t") .. "\n"
		end
		return table.concat(lines)
	end

	local function load_frozen_roster()
		if type(frozen_roster) ~= "table" or
				frozen_roster.schema ~= "grug_wp40_r6_census_roster_v1" or
				type(frozen_roster.rows) ~= "table" or
				#frozen_roster.rows ~= 48 then
			common.fail("frozen census roster shape differs")
		end
		local roster = {}
		for index = 1, 48 do
			local source = frozen_roster.rows[index]
			if type(source) ~= "table" or #source ~= 8 then
				common.fail("frozen census roster row differs at " .. tostring(index))
			end
			roster[index] = {race = source[1], bucket = source[2],
				cell_z = source[3], cell_x = source[4], digest = source[5],
				zone_id = source[6], level_min = source[7], level_max = source[8]}
		end
		local digest = common.hex(loader.raw_sha256(roster_bytes(roster)))
		if digest ~= frozen_roster.selection_sha256 then
			common.fail("frozen census roster digest differs")
		end
		return roster
	end

	local function scan_census_loaded(loaded, roster, partition_count, residue)
		local state = {cubes = {}, rejections = {}, witnesses = {}, apex_overlaps = 0}
		local ordinal = 0
		for roster_index = 1, #roster do
			local selected = roster[roster_index]
			for y_index = 1, #Y_CELLS do
				if ordinal % partition_count == residue then
					local cell_y = Y_CELLS[y_index]
					local result = loaded.settlement_fixture.scan_census_cube({
						race = selected.race, bucket = selected.bucket,
						zone_id = selected.zone_id, cell_x = selected.cell_x,
						cell_y = cell_y, cell_z = selected.cell_z})
					state.cubes[#state.cubes + 1] = {race = selected.race,
						bucket = selected.bucket, zone_id = selected.zone_id,
						cell_x = selected.cell_x, cell_y = cell_y,
						cell_z = selected.cell_z, result = result}
					for key, count in pairs(result.rejections) do add(state.rejections, key, count) end
					state.apex_overlaps = state.apex_overlaps + result.apex_overlaps
					for resource, witness in pairs(result.witnesses) do
						local depth = witness.y <= -701 and "deep" or "ordinary"
						local key = selected.race .. "\0" .. selected.bucket .. "\0" ..
							resource .. "\0" .. depth
						if not state.witnesses[key] then state.witnesses[key] = witness end
					end
				end
				ordinal = ordinal + 1
			end
		end
		state.cube_population = ordinal
		if state.apex_overlaps ~= 0 then
			common.fail("resource evidence overlaps an apex socket")
		end
		return state
	end

	local function artifact_row(row_type, keys, values)
		return {row_type = row_type, keys = keys, values = values}
	end

	local function split_key(key)
		local values = {}
		local first = 1
		while true do
			local delimiter = key:find("\0", first, true)
			if not delimiter then
				values[#values + 1] = key:sub(first)
				break
			end
			values[#values + 1] = key:sub(first, delimiter - 1)
			first = delimiter + 1
		end
		return values
	end
	local split_probe = split_key("first\0second\0")
	if #split_probe ~= 3 or split_probe[1] ~= "first" or
			split_probe[2] ~= "second" or split_probe[3] ~= "" then
		common.fail("evidence key splitter differs")
	end
	split_probe = split_key("\0middle\0\0")
	if #split_probe ~= 4 or split_probe[1] ~= "" or
			split_probe[2] ~= "middle" or split_probe[3] ~= "" or
			split_probe[4] ~= "" then
		common.fail("evidence key splitter differs")
	end
	split_probe = split_key("")
	if #split_probe ~= 1 or split_probe[1] ~= "" then
		common.fail("evidence key splitter differs")
	end
	split_probe = nil

	local function rows_for_seed(slot, seed, horizontal, census, partial)
		local rows = {}
		local function emit(row_type, keys, values)
			rows[#rows + 1] = artifact_row(row_type, keys, values)
		end
		local seed_row = seed_rows[slot]
		if not seed_row or seed_row.seed_decimal_text ~= seed then
			common.fail("seed corpus row differs at slot " .. tostring(slot))
		end
		emit("seed", {slot}, {seed_row.label, seed, seed_row.class, seed_row.sha256})

		local allowed = {}
		for zone_index = 1, #loader.source.zones do
			local zone = loader.source.zones[zone_index]
			for biome_index = 1, #zone.biomes do
				allowed[zone.id .. "\0" .. zone.biomes[biome_index].id] = true
			end
		end
		for key, count in pairs(horizontal.coverage) do
			local fields = split_key(key)
			if #fields ~= 2 then common.fail("surface coverage key width differs") end
			emit("surface_coverage", {slot, fields[1], fields[2], "occurring"}, {count})
			allowed[key] = nil
		end
		if not partial then
			for key in pairs(allowed) do
				local fields = split_key(key)
				if #fields ~= 2 then common.fail("surface catalog key width differs") end
				emit("surface_coverage", {slot, fields[1], fields[2], "catalog_zero"}, {0})
			end
		end

		for index = 1, #fixtures.cultural do
			local id = fixtures.cultural[index].key
			for _, rate in ipairs({"concentrated", "ordinary"}) do
				local key = id .. "\0" .. rate
				local candidate, settled = horizontal.cultural_candidates[key],
					horizontal.cultural_slots[key]
				emit("cultural_candidate", {slot, id, rate}, {candidate.eligible,
					candidate.budget, candidate.candidates})
				emit("cultural_slot", {slot, id, rate},
					{settled.accepted, settled.reserved})
			end
		end
		for index = 1, #fixtures.decorations do
			local definition = fixtures.decorations[index]
			local candidate = horizontal.decoration_candidates[definition.id]
			local settled = horizontal.decoration_settlement[definition.id]
			emit("decoration_candidate", {slot, definition.id,
				definition.settlement_class}, {candidate.eligible, candidate.budget,
				candidate.candidates})
			emit("decoration_settlement", {slot, definition.id,
				definition.settlement_class}, {settled.accepted, settled.emitted,
				settled.reserved})
		end

		local rejections = {}
		for key, count in pairs(horizontal.rejections) do add(rejections, key, count) end
		for key, count in pairs(census.rejections) do add(rejections, key, count) end
		for cube_index = 1, #census.cubes do
			local cube = census.cubes[cube_index]
			for class_name, substrate in pairs(cube.result.substrate) do
				emit("substrate_class", {slot, cube.race, cube.bucket, cube.cell_z,
					cube.cell_x, cube.cell_y, class_name},
					{substrate.count, substrate.digest})
			end
			for resource_index = 1, #fixtures.resources do
				local resource = fixtures.resources[resource_index]
				local value = cube.result.resources[resource.key]
				local keys = {slot, cube.race, resource.key, cube.cell_z, cube.cell_x,
					cube.cell_y, value.host, "T" .. tostring(value.tier), value.band}
				emit("resource_host", keys, {value.eligible})
				emit("resource_budget", keys, {value.numerator, value.denominator,
					value.base, value.remainder, value.remainder_digest})
				emit("resource_vein", keys, {value.planned, value.accepted,
					value.collisions, value.shortfall})
				emit("resource_node", keys, {value.target_nodes, value.placed_nodes})
				add(rejections, "resource\0" .. resource.key .. "\0collision_resource",
					value.collisions)
			end
			emit("region_host", {slot, cube.race, cube.cell_z, cube.cell_x,
				cube.cell_y, "T" .. tostring(cube.result.region_host.tier),
				cube.result.region_host.band}, {cube.result.region_host.count})
		end

		local cultural_reasons = {"clipped_owner", "fixed_or_protected",
			"route_or_water", "content_ignore", "wrong_support", "cultural_collision"}
		for index = 1, #fixtures.cultural do
			local id = fixtures.cultural[index].key
			for reason_index = 1, #cultural_reasons do
				local reason = cultural_reasons[reason_index]
				emit("rejection", {slot, "cultural", id, reason},
					{rejections["cultural\0" .. id .. "\0" .. reason] or 0})
			end
		end
		local decoration_reasons = {"clipped_owner", "content_ignore",
			"fixed_or_protected", "route_or_water", "wrong_host",
			"insufficient_clearance", "cultural_collision", "resource_collision",
			"decoration_collision", "forbidden_old_class"}
		for index = 1, #fixtures.decorations do
			local id = fixtures.decorations[index].id
			for reason_index = 1, #decoration_reasons do
				local reason = decoration_reasons[reason_index]
				emit("rejection", {slot, "decoration", id, reason},
					{rejections["decoration\0" .. id .. "\0" .. reason] or 0})
			end
		end
		for index = 1, #fixtures.resources do
			local id = fixtures.resources[index].key
			for _, reason in ipairs({"collision_resource", "rejected_no_root",
					"short_frontier"}) do
				emit("rejection", {slot, "resource", id, reason},
					{rejections["resource\0" .. id .. "\0" .. reason] or 0})
			end
		end
		-- Fleet-only authenticated proof rows are consumed by the finalizer and
		-- omitted from the promoted closed artifact. Pilot shards deliberately do
		-- not carry them, so the measured pilot byte projection remains exact.
		if partial == nil then
			emit("vm_metric", {"worker_apex", tostring(slot), "horizontal_overlap"},
				{horizontal.apex_overlaps, 0, horizontal.apex_overlaps == 0})
			emit("vm_metric", {"worker_apex", tostring(slot), "census_overlap"},
				{census.apex_overlaps, 0, census.apex_overlaps == 0})
		end
		return rows
	end

	function module.census_roster(seed)
		return select_census(loader.new_evidence(seed or "0"))
	end
	function module.frozen_census_roster()
		return load_frozen_roster()
	end
	function module.verify_frozen_census_roster()
		local frozen = load_frozen_roster()
		local recomputed = select_census(loader.new_evidence("0"))
		if roster_bytes(frozen) ~= roster_bytes(recomputed) then
			common.fail("recomputed census roster differs")
		end
		return frozen_roster.selection_sha256
	end
	function module.scan_horizontal(seed, partition_count, residue)
		return scan_horizontal_loaded(loader.new_evidence(seed), partition_count, residue)
	end
	function module.scan_census(seed, roster, partition_count, residue)
		local loaded = loader.new_evidence(seed)
		return scan_census_loaded(loaded, roster or select_census(loaded),
			partition_count, residue)
	end
	function module.scan_partition(seed, roster, partition_count, residue)
		local loaded = loader.new_evidence(seed)
		local selected = roster or select_census(loaded)
		return scan_horizontal_loaded(loaded, partition_count, residue),
			scan_census_loaded(loaded, selected, partition_count, residue), selected
	end

	function module.run_seed_range(spec)
		local roster = load_frozen_roster()
		local rows = {}
		local access = {}
		local function witness_less(left, right)
			if left.zone_id ~= right.zone_id then
				return common.less_bytes(left.zone_id, right.zone_id)
			end
			if left.z ~= right.z then return left.z < right.z end
			if left.x ~= right.x then return left.x < right.x end
			return left.y < right.y
		end
		local function access_witness(gate, owner, resource, discriminator,
				slot, witness)
			local key = table.concat({gate, owner, resource or "",
				discriminator or ""}, "\0")
			local old = access[key]
			if not old or slot < old.slot or
					(slot == old.slot and witness_less(witness, old.witness)) then
				access[key] = {gate = gate, owner = owner, resource = resource or "",
					discriminator = discriminator or "", slot = slot, witness = witness}
			end
		end
		for slot = spec.slot_first, spec.slot_last do
			local seed = loader.seed_corpus.fixed[slot]
			local horizontal, census = module.scan_partition(seed, roster, 1, 0)
			local seed_artifact_rows = rows_for_seed(slot, seed, horizontal, census)
			for index = 1, #seed_artifact_rows do
				rows[#rows + 1] = seed_artifact_rows[index]
			end
			for key, witness in pairs(horizontal.witnesses) do
				local fields = split_key(key)
				if #fields ~= 2 then common.fail("cultural witness key width differs") end
				local race
				for cultural_index = 1, #fixtures.cultural do
					if fixtures.cultural[cultural_index].key == fields[1] then
						race = fixtures.cultural[cultural_index].race break
					end
				end
				access_witness("access_cultural", race, fields[1], fields[2],
					slot, witness)
			end
			for key, witness in pairs(census.witnesses) do
				local fields = split_key(key)
				if #fields ~= 4 then common.fail("resource witness key width differs") end
				local race, bucket, resource, depth = fields[1], fields[2], fields[3], fields[4]
				local assignment = race_assignments[race]
				if assignment and (resource == assignment.g1 or resource == assignment.g2) then
					access_witness("access_native_region", race, resource, "", slot, witness)
				end
				local accord = race == "dwarf" or race == "elf" or race == "human"
				if bucket == "frontier" and resource == "ruby" and not accord then
					access_witness("access_opposing_frontier", "accord", resource, "",
						slot, witness)
				elseif bucket == "frontier" and resource == "sapphire" and accord then
					access_witness("access_opposing_frontier", "throng", resource, "",
						slot, witness)
				end
				if depth == "deep" and resource == "ruby" and not accord then
					access_witness("access_deep_cross_border", "accord", resource, "",
						slot, witness)
				elseif depth == "deep" and resource == "sapphire" and accord then
					access_witness("access_deep_cross_border", "throng", resource, "",
						slot, witness)
				end
			end
		end
		for _, record in pairs(access) do
			local witness = record.witness
			rows[#rows + 1] = artifact_row("access", {record.gate, record.owner,
				record.resource, record.discriminator}, {true, record.slot,
				witness.zone_id, witness.x, witness.y, witness.z, witness.zone_id})
		end
		return {schema = "grug_wp40_r6_worker_rows_v1", rows = rows}
	end

	local function rows_bytes(rows)
		local lines = {}
		for index = 1, #rows do
			local row = rows[index]
			lines[index] = common.row(row.row_type, row.keys, row.values)
		end
		common.sort_rows(lines)
		return common.artifact_header() .. table.concat(lines), #lines
	end

	function module.run_cost_pilot_shard(spec)
		local roster = load_frozen_roster()
		local horizontal, census = module.scan_partition(loader.seed_corpus.fixed[1],
			roster, spec.partition_count, spec.residue)
		local bytes = rows_bytes(rows_for_seed(1, loader.seed_corpus.fixed[1],
			horizontal, census, true))
		return {schema = "grug_wp40_r6_pilot_shard_v1", bytes = bytes}
	end

	function module.run_cost_pilot_reference(spec)
		local roster = load_frozen_roster()
		local horizontal, census = module.scan_partition(loader.seed_corpus.fixed[1],
			roster, 1, 0)
		local bytes = rows_bytes(rows_for_seed(1, loader.seed_corpus.fixed[1],
			horizontal, census, false))
		return {schema = "grug_wp40_r6_pilot_reference_v1", bytes = bytes}
	end

	local function parse_artifact_rows(bytes)
		local header, body = bytes:match("^([^\n]+)\n(.*)$")
		if header .. "\n" ~= common.artifact_header() then
			common.fail("pilot fragment header differs")
		end
		local rows = {}
		for line in body:gmatch("([^\n]+)\n") do
			local fields = {}
			for field in (line .. "\t"):gmatch("([^\t]*)\t") do
				fields[#fields + 1] = field
			end
			if #fields ~= 23 then common.fail("pilot fragment row width differs") end
			rows[#rows + 1] = fields
		end
		return rows
	end

	local SUM_VALUES = {surface_coverage = 1, cultural_candidate = 3,
		cultural_slot = 2, decoration_candidate = 3, decoration_settlement = 3,
		rejection = 1}
	local function merge_pilot_fragments(descriptors)
		local merged = {}
		for descriptor_index = 1, #descriptors do
			local parsed = parse_artifact_rows(common.read_file(
				descriptors[descriptor_index].path))
			for row_index = 1, #parsed do
				local fields = parsed[row_index]
				local key = table.concat(fields, "\t", 1, 11)
				local old = merged[key]
				if not old then merged[key] = fields
				elseif fields[1] == "seed" then
					if table.concat(old, "\t") ~= table.concat(fields, "\t") then
						common.fail("pilot seed rows differ")
					end
				elseif SUM_VALUES[fields[1]] then
					for value_index = 1, SUM_VALUES[fields[1]] do
						local column = 11 + value_index
						old[column] = tostring(assert(tonumber(old[column])) +
							assert(tonumber(fields[column])))
					end
				else
					common.fail("pilot fragments overlap a detail key")
				end
			end
		end
		local occurring = {}
		for _, fields in pairs(merged) do
			if fields[1] == "surface_coverage" and fields[5] == "occurring" then
				occurring[fields[3] .. "\0" .. fields[4]] = true
			end
		end
		for zone_index = 1, #loader.source.zones do
			local zone = loader.source.zones[zone_index]
			for biome_index = 1, #zone.biomes do
				local biome = zone.biomes[biome_index].id
				if not occurring[zone.id .. "\0" .. biome] then
					local line = common.row("surface_coverage",
						{1, zone.id, biome, "catalog_zero"}, {0})
					local fields = parse_artifact_rows(common.artifact_header() .. line)[1]
					merged[table.concat(fields, "\t", 1, 11)] = fields
				end
			end
		end
		local lines = {}
		for _, fields in pairs(merged) do
			lines[#lines + 1] = table.concat(fields, "\t") .. "\n"
		end
		common.sort_rows(lines)
		return common.artifact_header() .. table.concat(lines), #lines
	end

	local function resource_measure(path)
		local bytes = common.read_file(path)
		local wall, user, system, rss = bytes:match(
			"r6_resource_v1\t[^\t]+\t[^\t]+\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\n]+)")
		if not wall then common.fail("pilot resource measurement differs: " .. path) end
		return tonumber(wall), tonumber(user), tonumber(system), tonumber(rss)
	end

	local function unsigned_file(path)
		local value = common.read_file(path)
		local text = value:match("^([0-9]+)\n$")
		if not text then common.fail("pilot scratch measurement differs") end
		local number = tonumber(text)
		if not number or number % 1 ~= 0 then
			common.fail("pilot scratch measurement is not exact")
		end
		return number
	end

	function module.combine_cost_pilot(spec, descriptors, reference_descriptor)
		local combined, combined_rows = merge_pilot_fragments(descriptors)
		local reference = common.read_file(reference_descriptor.path)
		local combined_digest = common.hex(loader.raw_sha256(combined))
		local reference_digest = common.hex(loader.raw_sha256(reference))
		local wall, cpu, rss = 0, 0, 0
		local worker_report = {}
		for index = 1, #descriptors do
			local w, u, s, r = resource_measure(spec.scratch ..
				"/pilot-" .. tostring(index) .. ".resource")
			wall, cpu, rss = math.max(wall, w), cpu + u + s, math.max(rss, r)
			worker_report[#worker_report + 1] = "pilot_worker_" .. tostring(index) ..
				"_wall_seconds\t" .. string.format("%.2f", w)
			worker_report[#worker_report + 1] = "pilot_worker_" .. tostring(index) ..
				"_cpu_seconds\t" .. string.format("%.2f", u + s)
			worker_report[#worker_report + 1] = "pilot_worker_" .. tostring(index) ..
				"_peak_rss_kib\t" .. tostring(r)
		end
		local reference_wall, reference_user, reference_system, reference_rss =
			resource_measure(spec.scratch .. "/pilot-reference.resource")
		local static = loader.new_static()
		local closed_global_rows = 361 + #static.content_contract.content_names +
			#static.templates.records() * 4
		local seed_body_bytes = #combined - #common.artifact_header()
		local projected_seed_bytes = seed_body_bytes * 32
		local global_row_byte_ceiling = closed_global_rows * 2048
		local trailer_byte_ceiling = 256
		local projected_rows = combined_rows * 32 + closed_global_rows
		local projected_bytes = #common.artifact_header() + projected_seed_bytes +
			global_row_byte_ceiling + trailer_byte_ceiling
		local evidence_scratch = unsigned_file(spec.scratch ..
			"/pilot-scratch-bytes.txt")
		local report_rows = {
			"schema\tgrug_wp40_r6_pilot_projection_v1",
			"assignment_sha256\t" .. spec.assignment_sha256,
			"roster_selection_sha256\t" .. frozen_roster.selection_sha256,
			"static_gate_receipt_sha256\t" .. common.hex(loader.raw_sha256(
				common.read_file(spec.scratch .. "/static-gates.tsv"))),
			"population_sha256\t" .. combined_digest,
			"reference_sha256\t" .. reference_digest,
			"pilot_wall_seconds\t" .. string.format("%.2f", wall),
			"pilot_cpu_seconds\t" .. string.format("%.2f", cpu),
			"pilot_peak_rss_kib\t" .. tostring(rss),
			"pilot_scratch_bytes\t" .. tostring(evidence_scratch),
			"pilot_evidence_scratch_bytes\t" .. tostring(evidence_scratch),
			"pilot_combined_rows\t" .. tostring(combined_rows),
			"pilot_combined_bytes\t" .. tostring(#combined),
			"pilot_seed_body_bytes\t" .. tostring(seed_body_bytes),
			"reference_wall_seconds\t" .. string.format("%.2f", reference_wall),
			"reference_cpu_seconds\t" .. string.format("%.2f",
				reference_user + reference_system),
			"reference_peak_rss_kib\t" .. tostring(reference_rss),
			"projected_fleet_wall_seconds\t" .. string.format("%.2f", wall * 35),
			"projected_fleet_cpu_seconds\t" .. string.format("%.2f", cpu * 32),
			"projected_fleet_peak_rss_kib\t" .. tostring(rss * 7),
			"projected_fleet_scratch_bytes\t" .. tostring(evidence_scratch * 32),
			"projected_seed_body_bytes\t" .. tostring(projected_seed_bytes),
			"projected_global_rows\t" .. tostring(closed_global_rows),
			"projected_global_row_byte_ceiling\t" ..
				tostring(global_row_byte_ceiling),
			"projected_artifact_rows\t" .. tostring(projected_rows),
			"projected_artifact_bytes\t" .. tostring(projected_bytes),
		}
		for index = 1, #worker_report do
			report_rows[#report_rows + 1] = worker_report[index]
		end
		local report = table.concat(report_rows, "\n") .. "\n"
		return {schema = "grug_wp40_r6_pilot_combine_v1", bytes = report,
			sharded_digest = combined_digest, reference_digest = reference_digest}
	end

	function module.finalize_global_fragment(spec, worker_descriptors,
			micro_descriptors, production_descriptor)
		return finalizer.finalize(spec, worker_descriptors, micro_descriptors,
			production_descriptor)
	end
	return module
end
