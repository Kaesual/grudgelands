-- Streaming global reducer for the closed WP40 R6 artifact ledger.

return function(loader)
	local common = loader.common
	local HEADER = common.artifact_header()
	local MAX_ROWS = 900000
	local MAX_BYTES = 512 * 1024 * 1024
	local MAX_SAFE = 9007199254740991
	local ZONED_HORIZONTAL_COLUMNS = 31618582
	local DEEP_CONTESTED_MAX_Y = -701
	local DEEP_TERRITORY_AUTHORITY = "docs/design/world.md:324"
	local RACES = {"dwarf", "elf", "human", "orc", "troll", "undead"}
	local NOT_OWNED = {"cloth", "feather", "herb", "leather", "reagent",
		"silk", "spice"}
	local EXPECTED = {
		seed = 32,
		cultural_candidate = 32 * 6 * 2,
		cultural_slot = 32 * 6 * 2,
		decoration_candidate = 32 * 48,
		decoration_settlement = 32 * 48,
		substrate_class = 32 * 384 * 4,
		resource_host = 32 * 384 * 15,
		resource_budget = 32 * 384 * 15,
		resource_vein = 32 * 384 * 15,
		resource_node = 32 * 384 * 15,
		region_host = 32 * 384,
		rejection = 32 * (6 * 6 + 48 * 10 + 15 * 3),
	}
	local module = {}

	local function fail(message)
		common.fail("global finalizer: " .. message)
	end

	local function sha256(bytes)
		return common.hex(loader.raw_sha256(bytes))
	end

	local function validate_zoned_column_authority()
		local bytes = common.read_file(loader.repo ..
			"/docs/research/wp40-simple-map-r4-artifact.tsv")
		local unzoned, matches = 0, 0
		for line in bytes:gmatch("([^\n]+)\n") do
			local value = line:match(
				"^evidence\tr4/population/biome/%-\tnumber\t([0-9]+)$")
			if value then
				matches, unzoned = matches + 1, tonumber(value)
			end
		end
		if matches ~= 1 or 49980561 - unzoned ~= ZONED_HORIZONTAL_COLUMNS then
			fail("R4 zoned horizontal-column authority differs")
		end
	end

	local function structured(row_type, keys, values)
		return {row_type = row_type, keys = keys, values = values}
	end

	local function row_line(row)
		return common.row(row.row_type, row.keys, row.values)
	end

	local function split_line(line)
		local fields = {}
		for field in (line .. "\t"):gmatch("([^\t]*)\t") do
			fields[#fields + 1] = field
		end
		if #fields ~= 23 then fail("worker row width differs") end
		return fields
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
	local split_probe = split_nul("slot\0resource\0id\0shortfall_nodes")
	if #split_probe ~= 4 or split_probe[1] ~= "slot" or
			split_probe[2] ~= "resource" or split_probe[3] ~= "id" or
			split_probe[4] ~= "shortfall_nodes" then
		fail("NUL key splitter differs")
	end
	split_probe = split_nul("first\0second\0")
	if #split_probe ~= 3 or split_probe[1] ~= "first" or
			split_probe[2] ~= "second" or split_probe[3] ~= "" then
		fail("NUL key splitter differs")
	end
	split_probe = split_nul("\0middle\0\0")
	if #split_probe ~= 4 or split_probe[1] ~= "" or
			split_probe[2] ~= "middle" or split_probe[3] ~= "" or
			split_probe[4] ~= "" then
		fail("NUL key splitter differs")
	end
	split_probe = split_nul("")
	if #split_probe ~= 1 or split_probe[1] ~= "" then
		fail("NUL key splitter differs")
	end
	split_probe = nil

	local function unsigned(value, label)
		if type(value) ~= "string" or (value ~= "0" and
				not value:match("^[1-9][0-9]*$")) then
			fail(label .. " is not unsigned decimal")
		end
		local number = tonumber(value)
		if not number or number % 1 ~= 0 or number > MAX_SAFE then
			fail(label .. " is not exact")
		end
		return number
	end

	local function canonical_digest(label, lines)
		local copy = {}
		for index = 1, #lines do copy[index] = lines[index] end
		table.sort(copy, common.less_bytes)
		return sha256(label .. "\n" .. table.concat(copy))
	end

	local function lines_for(rows, predicate)
		local result = {}
		for index = 1, #rows do
			local row = rows[index]
			if not predicate or predicate(row) then
				result[#result + 1] = row_line(row)
			end
		end
		return result
	end

	local function append(target, values)
		for index = 1, #values do target[#target + 1] = values[index] end
	end

	local function access_less(left, right)
		if left.slot ~= right.slot then return left.slot < right.slot end
		if left.z ~= right.z then return left.z < right.z end
		if left.x ~= right.x then return left.x < right.x end
		if left.y ~= right.y then return left.y < right.y end
		if left.zone ~= right.zone then return common.less_bytes(left.zone, right.zone) end
		return common.less_bytes(left.witness, right.witness)
	end

	local function worker_scan(descriptors, assignments, static)
		validate_zoned_column_authority()
		local counts, seeds, access = {}, {}, {}
		local hosts, veins = {}, {}
		local region_lines, worker_bindings = {}, {}
		local kept_rows, kept_bytes = 0, 0
		local apex_overlap_count, apex_proofs = 0, {}
		local expected_first = {1, 6, 11, 16, 21, 26, 31}
		local expected_last = {5, 10, 15, 20, 25, 30, 32}
		local per_seed = {seed = 1, substrate_class = 384 * 4,
			surface_coverage = 104, resource_host = 384 * 15,
			resource_budget = 384 * 15, resource_vein = 384 * 15,
			resource_node = 384 * 15, region_host = 384,
			cultural_candidate = 6 * 2, cultural_slot = 6 * 2,
			decoration_candidate = 48, decoration_settlement = 48, vm_metric = 2,
			rejection = 6 * 6 + 48 * 10 + 15 * 3}
		local worker_family = {access = true}
		for family in pairs(per_seed) do worker_family[family] = true end
		local race_set, zone_by_id = {}, {}
		for index = 1, #RACES do race_set[RACES[index]] = true end
		for index = 1, #loader.source.zones do
			zone_by_id[loader.source.zones[index].id] = loader.source.zones[index]
		end
		local roster = dofile(loader.repo .. "/tools/wp40/r6/census_roster.lua")
		local seed_rows = common.tsv(loader.repo ..
			"/docs/research/wp40-simple-map-r6-seed-corpus.tsv")
		local roster_cells = {}
		for index = 1, #roster.rows do
			local row = roster.rows[index]
			local key = table.concat({row[1], row[4], row[3]}, "\0")
			if roster_cells[key] then fail("duplicate census roster cell") end
			roster_cells[key] = row[2]
		end
		local cell_tier = {[-4] = 1, [-13] = 2, [-26] = 3, [-38] = 4,
			[-53] = 5, [-78] = 6, [-100] = 6, [-188] = 6}
		local function cell_values(race, cell_z, cell_x, cell_y)
			local bucket = roster_cells[table.concat({race, cell_x, cell_z}, "\0")]
			local tier = cell_tier[cell_y]
			if not bucket or not tier then fail("row is outside the frozen census matrix") end
			local band = cell_y == -100 and "deep_1500_1999" or
				(cell_y == -188 and "deep_2000_floor" or "ordinary")
			return bucket, tier, band, static.content_contract and
				loader.fixtures.projection().tiers[tier].node or false
		end
		local resources, resource_by_key = loader.fixtures.resources, {}
		for index = 1, #resources do resource_by_key[resources[index].key] = resources[index] end
		local cultural_by_key = {}
		for index = 1, #loader.fixtures.cultural do
			cultural_by_key[loader.fixtures.cultural[index].key] =
				loader.fixtures.cultural[index]
		end
		local decoration_by_id = {}
		for index = 1, #loader.fixtures.decorations do
			local row = loader.fixtures.decorations[index]
			decoration_by_id[row.id] = row
		end
		local allowed_surface, allowed_surface_count = {}, 0
		for index = 1, #loader.source.zones do
			local zone = loader.source.zones[index]
			for biome_index = 1, #zone.biomes do
				local key = zone.id .. "\0" .. zone.biomes[biome_index].id
				if allowed_surface[key] then fail("duplicate allowed surface pair") end
				allowed_surface[key], allowed_surface_count = true, allowed_surface_count + 1
			end
		end
		if allowed_surface_count ~= 104 then fail("allowed surface-pair population differs") end
		local cultural_reasons = {clipped_owner = true, fixed_or_protected = true,
			route_or_water = true, content_ignore = true, wrong_support = true,
			cultural_collision = true}
		local decoration_reasons = {clipped_owner = true, content_ignore = true,
			fixed_or_protected = true, route_or_water = true, wrong_host = true,
			insufficient_clearance = true, cultural_collision = true,
			resource_collision = true, decoration_collision = true,
			forbidden_old_class = true}
		local resource_reasons = {collision_resource = true,
			rejected_no_root = true, short_frontier = true}
		local access_gates = {access_native_region = true,
			access_opposing_frontier = true, access_deep_cross_border = true,
			access_cultural = true}
		local actual_rejections, expected_rejections = {}, {}
		local rejection_totals, expected_rejection_totals = {}, {}
		local access_resource_needs, access_resource_found = {}, {}
		local access_cultural_needs, access_cultural_found = {}, {}
		local substrate_region, reported_region = {}, {}
		local function number_field(fields, index, label)
			return unsigned(fields[index], label)
		end
		local function integer_field(value, label)
			local number = tonumber(value)
			if not number or number % 1 ~= 0 or math.abs(number) > MAX_SAFE then
				fail(label .. " is not an exact integer")
			end
			return number
		end
		local function require_slot(fields, first, last, family)
			local slot = number_field(fields, 2, family .. " seed slot")
			if slot < first or slot > last then fail(family .. " escaped worker slot range") end
			return slot
		end
		local function cube_key(fields, key_z, key_x, key_y)
			local race = fields[3]
			if not race_set[race] then fail("unknown census race") end
			local cell_z, cell_x, cell_y = integer_field(fields[key_z], "cell z"),
				integer_field(fields[key_x], "cell x"), integer_field(fields[key_y], "cell y")
			local bucket, tier, band, host = cell_values(race, cell_z, cell_x, cell_y)
			return race, cell_z, cell_x, cell_y, bucket, tier, band, host
		end
		local function add_value(map, key, value) map[key] = (map[key] or 0) + value end
		local function family_reader(path, wanted)
			local file = assert(io.open(path, "rb"), "cannot open worker fragment")
			if file:read("*l") .. "\n" ~= HEADER then fail("worker header differs") end
			return function()
				while true do
					local line = file:read("*l")
					if not line then assert(file:close()) return nil end
					local fields = split_line(line)
					if fields[1] == wanted then return fields end
				end
			end
		end
		local function equal_keys(left, right, last)
			for field = 2, last do
				if left[field] ~= right[field] then return false end
			end
			return true
		end
		for index = 1, #RACES do hosts[RACES[index]], veins[RACES[index]] = 0, 0 end
		local counted = {}
		for index = 1, #RACES do
			local race, row = RACES[index], assignments[RACES[index]]
			counted[race] = {coal = true, copper = true, tin = true, iron = true,
				quartz = true, gold = true, silver = true, emberglass = true,
				abyssal_crystal = true, [row.g1] = true, [row.g2] = true}
		end
		for descriptor_index = 1, #descriptors do
			local descriptor = descriptors[descriptor_index]
			local first, last = expected_first[descriptor_index], expected_last[descriptor_index]
			local descriptor_counts, descriptor_seeds = {}, {}
			local surface_pairs, surface_sums = {}, {}
			local previous_key
			local substrate_group, substrate_count, substrate_host_count, substrate_classes
			local function finish_substrate()
				if not substrate_group then return end
				if substrate_count ~= 4 or substrate_classes.AIR ~= true or
						substrate_classes.NATIVE_ORE ~= true or
						substrate_classes.LIQUID ~= true or
						substrate_classes[substrate_group.host] ~= true or
						substrate_group.total ~= 4096 then
					fail("substrate cube matrix differs")
				end
				substrate_region[#substrate_region + 1] = table.concat({
					substrate_group.slot, substrate_group.race, substrate_group.cell_z,
					substrate_group.cell_x, substrate_group.cell_y,
					"T" .. tostring(substrate_group.tier), substrate_group.band,
					substrate_host_count}, "\0") .. "\n"
			end
			worker_bindings[#worker_bindings + 1] = "worker\t" ..
				tostring(descriptor_index) .. "\t" .. tostring(first) .. "\t" ..
				tostring(last) .. "\t" .. descriptor.sha256 .. "\n"
			local file = assert(io.open(descriptor.path, "rb"),
				"cannot open worker fragment")
			if file:read("*l") .. "\n" ~= HEADER then fail("worker header differs") end
			for line in file:lines() do
				local fields = split_line(line)
				local family = fields[1]
				if not worker_family[family] then fail("unexpected worker family " .. family) end
				local sort_key = table.concat(fields, "\t", 1, 11)
				if previous_key and not common.less_bytes(previous_key, sort_key) then
					fail("worker rows are unsorted or duplicate")
				end
				previous_key = sort_key
				counts[family] = (counts[family] or 0) + 1
				descriptor_counts[family] = (descriptor_counts[family] or 0) + 1
				if family ~= "access" and family ~= "vm_metric" then
					kept_rows = kept_rows + 1
					kept_bytes = kept_bytes + #line + 1
				end
				if family == "seed" then
					local slot = unsigned(fields[2], "seed slot")
					if slot < first or slot > last or seeds[slot] or descriptor_seeds[slot] then
						fail("worker seed population differs")
					end
					local expected_seed = seed_rows[slot]
					if not expected_seed or fields[12] ~= expected_seed.label or
							fields[13] ~= expected_seed.seed_decimal_text or
							fields[14] ~= expected_seed.class or
							fields[15] ~= expected_seed.sha256 or
							loader.seed_corpus.fixed[slot] ~= expected_seed.seed_decimal_text then
						fail("worker seed row differs from the frozen corpus")
					end
					seeds[slot], descriptor_seeds[slot] = true, true
				elseif family == "surface_coverage" then
					local slot = require_slot(fields, first, last, family)
					local pair = fields[3] .. "\0" .. fields[4]
					if not allowed_surface[pair] then fail("surface pair is outside catalog") end
					surface_pairs[slot] = surface_pairs[slot] or {}
					if surface_pairs[slot][pair] then fail("duplicate surface pair status") end
					surface_pairs[slot][pair] = true
					local value = number_field(fields, 12, "surface columns")
					if (fields[5] == "catalog_zero" and value ~= 0) or
							(fields[5] == "occurring" and value == 0) or
							(fields[5] ~= "catalog_zero" and fields[5] ~= "occurring") then
						fail("surface status/count differs")
					end
					surface_sums[slot] = (surface_sums[slot] or 0) + value
				elseif family == "substrate_class" then
					local slot = require_slot(fields, first, last, family)
					local race, cell_z, cell_x, cell_y, bucket, tier, band, host =
						cube_key(fields, 5, 6, 7)
					if fields[4] ~= bucket then fail("substrate bucket differs") end
					local group_key = table.concat({slot, race, cell_z, cell_x, cell_y}, "\0")
					if not substrate_group or substrate_group.key ~= group_key then
						finish_substrate()
						substrate_group = {key = group_key, slot = slot, race = race,
							cell_z = cell_z, cell_x = cell_x, cell_y = cell_y,
							tier = tier, band = band, host = host, total = 0}
						substrate_count, substrate_host_count, substrate_classes = 0, 0, {}
					end
					local class_name, value = fields[8], number_field(fields, 12,
						"substrate population")
					if class_name ~= "AIR" and class_name ~= "NATIVE_ORE" and
							class_name ~= "LIQUID" and class_name ~= host then
						fail("unknown substrate class")
					end
					if substrate_classes[class_name] then fail("duplicate substrate class") end
					substrate_classes[class_name], substrate_count = true, substrate_count + 1
					substrate_group.total = substrate_group.total + value
					if class_name == host then substrate_host_count = value end
				elseif family == "resource_host" or family == "resource_budget" or
						family == "resource_vein" or family == "resource_node" then
					local slot = require_slot(fields, first, last, family)
					local race, cell_z, cell_x, cell_y, _, tier, band, host =
						cube_key(fields, 5, 6, 7)
					if not resource_by_key[fields[4]] or fields[8] ~= host or
							fields[9] ~= "T" .. tostring(tier) or fields[10] ~= band then
						fail("resource matrix key differs")
					end
					if family == "resource_vein" and counted[race] and
							counted[race][fields[4]] then
						veins[race] = veins[race] + unsigned(fields[13],
							"accepted resource veins")
					end
				elseif family == "region_host" then
					local slot = require_slot(fields, first, last, family)
					local race, cell_z, cell_x, cell_y, _, tier, band =
						cube_key(fields, 4, 5, 6)
					if fields[7] ~= "T" .. tostring(tier) or fields[8] ~= band then
						fail("region host key differs")
					end
					local value = number_field(fields, 12, "region host")
					hosts[race] = hosts[race] + value
					region_lines[#region_lines + 1] = line .. "\n"
					reported_region[#reported_region + 1] = table.concat({slot, race,
						cell_z, cell_x, cell_y, fields[7], band, value}, "\0") .. "\n"
				elseif family == "cultural_candidate" or family == "cultural_slot" then
					local slot = require_slot(fields, first, last, family)
					if not cultural_by_key[fields[3]] or
							(fields[4] ~= "ordinary" and fields[4] ~= "concentrated") then
						fail("cultural matrix key differs")
					end
				elseif family == "decoration_candidate" or
						family == "decoration_settlement" then
					local slot = require_slot(fields, first, last, family)
					local definition = decoration_by_id[fields[3]]
					if not definition or fields[4] ~= tostring(definition.settlement_class) then
						fail("decoration matrix key differs")
					end
				elseif family == "rejection" then
					local slot = require_slot(fields, first, last, family)
					local subsystem, id, reason = fields[3], fields[4], fields[5]
					local valid = subsystem == "cultural" and cultural_by_key[id] and
						cultural_reasons[reason] or subsystem == "decoration" and
						decoration_by_id[id] and decoration_reasons[reason] or
						subsystem == "resource" and resource_by_key[id] and
						resource_reasons[reason]
					if not valid then fail("rejection matrix key differs") end
					local value = number_field(fields, 12, "rejection count")
					local key = table.concat({slot, subsystem, id, reason}, "\0")
					actual_rejections[key] = value
					add_value(rejection_totals,
						table.concat({slot, subsystem, id}, "\0"), value)
				elseif family == "vm_metric" then
					if fields[2] ~= "worker_apex" or
							(fields[4] ~= "horizontal_overlap" and
								fields[4] ~= "census_overlap") then
						fail("worker apex proof identity differs")
					end
					local slot = unsigned(fields[3], "worker apex seed slot")
					if slot < first or slot > last then
						fail("worker apex proof escaped worker slot range")
					end
					local overlap = number_field(fields, 12, "worker apex overlap")
					if fields[13] ~= "0" or fields[14] ~= (overlap == 0 and "true" or "false") then
						fail("worker apex proof payload differs")
					end
					apex_proofs[slot] = apex_proofs[slot] or {}
					if apex_proofs[slot][fields[4]] ~= nil then
						fail("duplicate worker apex proof")
					end
					apex_proofs[slot][fields[4]] = overlap
					apex_overlap_count = apex_overlap_count + overlap
				elseif family == "access" then
					if fields[12] ~= "true" or not access_gates[fields[2]] then
						fail("worker access row is not a positive closed-gate witness")
					end
					local key = table.concat({fields[2], fields[3], fields[4], fields[5]},
						"\0")
					local record = {gate = fields[2], owner = fields[3],
						resource = fields[4], discriminator = fields[5],
						slot = unsigned(fields[13], "access seed slot"), zone = fields[14],
						x = integer_field(fields[15], "access x"),
						y = integer_field(fields[16], "access y"),
						z = integer_field(fields[17], "access z"), witness = fields[18]}
					if record.slot < first or record.slot > last then
						fail("access witness escaped worker slot range")
					end
					local zone = zone_by_id[record.zone]
					if not zone or not zone.race_region then fail("access witness zone differs") end
					record.race = zone.race_region
					if record.gate ~= "access_cultural" then
						local cell_x, cell_y, cell_z = math.floor(record.x / 16),
							math.floor(record.y / 16), math.floor(record.z / 16)
						local _, tier, band, host = cell_values(record.race, cell_z,
							cell_x, cell_y)
						record.resource_group = table.concat({record.slot, record.race,
							record.resource, cell_z, cell_x, cell_y, host,
							"T" .. tostring(tier), band}, "\0")
						access_resource_needs[record.resource_group] = true
					else
						record.cultural_group = table.concat({record.slot, record.resource,
							record.discriminator}, "\0")
						access_cultural_needs[record.cultural_group] = true
					end
					if not access[key] or access_less(record, access[key]) then
						access[key] = record
					end
				end
			end
			assert(file:close())
			finish_substrate()
			local slot_count = last - first + 1
			for family, expected in pairs(per_seed) do
				if descriptor_counts[family] ~= expected * slot_count then
					fail("worker " .. tostring(descriptor_index) .. " " .. family ..
						" population differs")
				end
			end
			for slot = first, last do
				if not descriptor_seeds[slot] then fail("worker descriptor slot binding differs") end
				local proofs = apex_proofs[slot]
				if not proofs or proofs.horizontal_overlap == nil or
						proofs.census_overlap == nil then
					fail("worker apex proof population differs")
				end
				local pair_count = 0
				for _ in pairs(surface_pairs[slot] or {}) do pair_count = pair_count + 1 end
				if pair_count ~= 104 or
						surface_sums[slot] ~= ZONED_HORIZONTAL_COLUMNS then
					fail("surface population differs for seed slot " .. tostring(slot))
				end
			end

			local host_next = family_reader(descriptor.path, "resource_host")
			local budget_next = family_reader(descriptor.path, "resource_budget")
			local vein_next = family_reader(descriptor.path, "resource_vein")
			local node_next = family_reader(descriptor.path, "resource_node")
			while true do
				local host_row, budget_row, vein_row, node_row = host_next(), budget_next(),
					vein_next(), node_next()
				if not host_row and not budget_row and not vein_row and not node_row then break end
				if not host_row or not budget_row or not vein_row or not node_row or
						not equal_keys(host_row, budget_row, 10) or
						not equal_keys(host_row, vein_row, 10) or
						not equal_keys(host_row, node_row, 10) then
					fail("resource family keysets differ")
				end
				local slot, race, resource_key = unsigned(host_row[2], "resource slot"),
					host_row[3], host_row[4]
				local definition = assert(resource_by_key[resource_key])
				local tier = assert(tonumber(host_row[9]:match("^T([1-6])$")))
				local allowed = definition.scope == "universal" or
					(definition.scope == "regional_g1" and assignments[race].g1 == resource_key) or
					(definition.scope == "regional_g2" and assignments[race].g2 == resource_key)
				local eligible = number_field(host_row, 12, "resource host")
				local denominator = definition.denominators[tier]
				if (not denominator or not allowed) and eligible ~= 0 then
					fail("ineligible resource has hosts")
				end
				local multiplier_numerator, multiplier_denominator = 1, 1
				if host_row[10] == "deep_1500_1999" then
					multiplier_numerator, multiplier_denominator = 5, 4
				elseif host_row[10] == "deep_2000_floor" then
					multiplier_numerator, multiplier_denominator = 3, 2
				end
				local digest = static.hash.digest("resource_budget_remainder_v1",
					loader.seed_corpus.fixed[slot], {resource_key,
						integer_field(host_row[6], "resource cell x"),
						integer_field(host_row[7], "resource cell y"),
						integer_field(host_row[5], "resource cell z"), host_row[8], tier,
						host_row[10]})
				local expected_budget, numerator, budget_denominator, base, remainder =
					0, 0, denominator and denominator * multiplier_denominator or 1, 0, 0
				if denominator then
					expected_budget, numerator, budget_denominator, base, remainder =
						static.hash.budget(eligible, 1, denominator, multiplier_numerator,
							multiplier_denominator, digest)
				end
				if number_field(budget_row, 12, "resource numerator") ~= numerator or
						number_field(budget_row, 13, "resource denominator") ~= budget_denominator or
						number_field(budget_row, 14, "resource base") ~= base or
						number_field(budget_row, 15, "resource remainder") ~= remainder or
						budget_row[16] ~= static.hash.hex(digest) then
					fail("resource budget arithmetic differs")
				end
				local planned, accepted = number_field(vein_row, 12, "planned veins"),
					number_field(vein_row, 13, "accepted veins")
				local collisions, shortfall = number_field(vein_row, 14,
					"resource collisions"), number_field(vein_row, 15, "resource shortfall")
				local target, placed = number_field(node_row, 12, "resource target nodes"),
					number_field(node_row, 13, "resource placed nodes")
				local expected_planned = expected_budget == 0 and 0 or math.floor(
					(expected_budget + definition.max_nodes_per_vein - 1) /
					definition.max_nodes_per_vein)
				if target ~= expected_budget or planned ~= expected_planned or
						accepted > planned or placed > target or target - placed ~= shortfall or
						(accepted == 0 and placed ~= 0) then
					fail("resource settlement aggregate differs")
				end
				local rejection_base = table.concat({slot, "resource", resource_key}, "\0")
				add_value(expected_rejections, rejection_base .. "\0collision_resource", collisions)
				add_value(expected_rejections, rejection_base .. "\0rejected_no_root",
					planned - accepted)
				add_value(expected_rejection_totals, rejection_base .. "\0shortfall_nodes",
					shortfall)
				add_value(expected_rejection_totals, rejection_base .. "\0accepted_veins",
					accepted)
				local group = table.concat(host_row, "\0", 2, 10)
				if accepted > 0 and access_resource_needs[group] then
					access_resource_found[group] = true
				end
			end

			local cultural_candidate_next = family_reader(descriptor.path,
				"cultural_candidate")
			local cultural_slot_next = family_reader(descriptor.path, "cultural_slot")
			while true do
				local candidate, settled = cultural_candidate_next(), cultural_slot_next()
				if not candidate and not settled then break end
				if not candidate or not settled or not equal_keys(candidate, settled, 4) then
					fail("cultural family keysets differ")
				end
				local eligible, budget, candidates = number_field(candidate, 12,
					"cultural eligible"), number_field(candidate, 13, "cultural budget"),
					number_field(candidate, 14, "cultural candidates")
				local accepted, reserved = number_field(settled, 12, "cultural accepted"),
					number_field(settled, 13, "cultural reserved")
				if candidates ~= budget or budget > eligible or accepted > candidates or
						reserved ~= accepted * 225 then fail("cultural aggregate differs") end
				local base = table.concat({candidate[2], "cultural", candidate[3]}, "\0")
				add_value(expected_rejection_totals, base, candidates - accepted)
				local group = table.concat({candidate[2], candidate[3], candidate[4]}, "\0")
				if accepted > 0 and access_cultural_needs[group] then
					access_cultural_found[group] = true
				end
			end

			local decoration_candidate_next = family_reader(descriptor.path,
				"decoration_candidate")
			local decoration_settlement_next = family_reader(descriptor.path,
				"decoration_settlement")
			while true do
				local candidate, settled = decoration_candidate_next(),
					decoration_settlement_next()
				if not candidate and not settled then break end
				if not candidate or not settled or not equal_keys(candidate, settled, 4) then
					fail("decoration family keysets differ")
				end
				local eligible, budget, candidates = number_field(candidate, 12,
					"decoration eligible"), number_field(candidate, 13, "decoration budget"),
					number_field(candidate, 14, "decoration candidates")
				local accepted, emitted, reserved = number_field(settled, 12,
					"decoration accepted"), number_field(settled, 13, "decoration emitted"),
					number_field(settled, 14, "decoration reserved")
				if candidates ~= budget or budget > eligible or accepted > candidates or
						emitted > reserved or (accepted == 0 and (emitted ~= 0 or reserved ~= 0)) then
					fail("decoration aggregate differs")
				end
				local base = table.concat({candidate[2], "decoration", candidate[3]}, "\0")
				expected_rejection_totals[base] = candidates - accepted
			end
		end
		if canonical_digest("region_host_cross_v1", substrate_region) ~=
				canonical_digest("region_host_cross_v1", reported_region) then
			fail("substrate/region-host keysets or counts differ")
		end
		for key, expected in pairs(expected_rejections) do
			if actual_rejections[key] ~= expected then fail("resource rejection aggregate differs") end
		end
		for key, expected in pairs(expected_rejection_totals) do
			local fields = split_nul(key)
			if #fields == 3 then
				if rejection_totals[key] ~= expected then
					fail(fields[2] .. " rejection total differs")
				end
			elseif #fields == 4 then
				local base, suffix = table.concat(fields, "\0", 1, 3), fields[4]
				if suffix == "shortfall_nodes" then
					local short = actual_rejections[base .. "\0short_frontier"] or 0
					local rootless = actual_rejections[base .. "\0rejected_no_root"] or 0
					local accepted = expected_rejection_totals[base .. "\0accepted_veins"] or 0
					if (expected == 0 and (short ~= 0 or rootless ~= 0)) or
							(expected > 0 and (short + rootless < 1 or short > accepted)) then
						fail("resource short-frontier aggregate differs")
					end
				elseif suffix ~= "accepted_veins" then
					fail("resource rejection-total key differs")
				end
			else
				fail("rejection-total key width differs")
			end
		end
		for key in pairs(access_resource_needs) do
			if not access_resource_found[key] then fail("access root lacks accepted vein binding") end
		end
		for key in pairs(access_cultural_needs) do
			if not access_cultural_found[key] then fail("access root lacks accepted cultural binding") end
		end
		for family, expected in pairs(EXPECTED) do
			if counts[family] ~= expected then
				fail(family .. " population differs: " .. tostring(counts[family]))
			end
		end
		if not counts.surface_coverage or counts.surface_coverage < 1 then
			fail("surface coverage population is empty")
		end
		for slot = 1, 32 do if not seeds[slot] then fail("missing seed slot") end end
		return {counts = counts, access = access, hosts = hosts, veins = veins,
			region_lines = region_lines, worker_bindings = worker_bindings,
			kept_rows = kept_rows, kept_bytes = kept_bytes,
			zone_by_id = zone_by_id, apex_overlap_count = apex_overlap_count}
	end

	local function key_value_file(path, expected_schema)
		local bytes = common.read_file(path)
		if bytes:sub(-1) ~= "\n" or bytes:find("\r", 1, true) then
			fail("receipt line endings differ")
		end
		local values = {}
		for line in bytes:gmatch("([^\n]+)\n") do
			local key, value = line:match("^([^\t]+)\t([^\t]+)$")
			if not key or values[key] then fail("receipt row differs") end
			values[key] = value
		end
		if values.schema ~= expected_schema then fail("receipt schema differs") end
		return values, bytes
	end

	local function validate_micro_receipt(bytes)
		local body, embedded = bytes:match("^(.*)output_sha256\t([0-9a-f]+)\n$")
		if not body or #embedded ~= 64 or sha256(body) ~= embedded then
			fail("micro-KAT body digest differs")
		end
		local expected = {
			analytic_bridge_predecessor = "1",
			["budget/deep_1500_1999_12000"] = "2/20480/12000/1/8480",
			["budget/deep_2000_floor_24000"] = "1/12288/24000/0/12288",
			["budget/ordinary_512"] = "8/4096/512/8/0",
			["budget/remainder_48000"] = "0/20480/48000/0/20480",
			cultural = "kat_cultural/225", ["decoration_class/1"] = "1",
			["decoration_class/2"] = "4", ["decoration_class/3"] = "1",
			["decoration_class/4"] = "1", domain_population = "12",
			ignore = "kat_simple/1/noop_equal_content",
			light_seed_runs = "103",
			negative_frame = "6ca4ab68b300888eb55b616b4022e2c5685abfb63fc87b575f92b5af6b34739a",
			negative_owner = "-112", owner_clipping = "kat_small/1",
			p7_opcodes = "1/1/1/9/1", resource_collision = "2",
			["resource_collision/ore_1"] = "0",
			["resource_collision/ore_2"] = "0",
			["resource_collision/ore_3"] = "2",
			["reduce_words/512/0/1000"] = "488",
			["reduce_words/12000/1/0"] = "11296",
			["reduce_words/12000/0/2147483648"] = "11648",
			["reduce_words/48000/4294967295/4294967295"] = "15615",
			["rotation/0"] = "kat_small/3/1/3/0",
			["rotation/1"] = "kat_small/3/1/3/1",
			["rotation/2"] = "kat_small/3/1/3/2",
			["rotation/3"] = "kat_small/3/1/3/3",
			["rotation/4dir_invalid"] =
				"template contains forbidden param2 rotation kind",
			["rotation/meshoptions_passthrough"] = "4",
			["rotation/wallmounted_invalid"] =
				"invalid wallmounted template param2",
			schema = "grug_wp40_r6_micro_kat_v2", short_vein = "2",
			["vm_band/deep_1500_1999"] = "applied_c/32/4/5",
			["vm_band/deep_2000_floor"] = "applied_c/32/5/6",
			vm_deep = "applied_c", vm_surface = "applied_cplq/104/1/1/1",
		}
		local seen, count = {}, 0
		for line in body:gmatch("([^\n]+)\n") do
			local key, value = line:match("^([^\t]+)\t([^\t]+)$")
			if not key or seen[key] or expected[key] ~= value then
				fail("micro-KAT key/value differs")
			end
			seen[key], count = true, count + 1
		end
		local expected_count = 0
		for key in pairs(expected) do
			expected_count = expected_count + 1
			if not seen[key] then fail("micro-KAT key is absent: " .. key) end
		end
		if count ~= expected_count then fail("micro-KAT population differs") end
		return embedded
	end

	local function static_receipt(path)
		local bytes = common.read_file(path)
		if bytes:sub(-1) ~= "\n" or bytes:find("\r", 1, true) then
			fail("static receipt line endings differ")
		end
		local expected_gates = {luac51_parse = true, setglobal = true,
			lua51_source_sweeps = true, sandbox_boundary = true,
			disabled_writer = true, bash_syntax = true}
		local expected_metrics = {activation_api_matches = true,
			map_writer_matches = true}
		local expected_files = loader.fixtures.static_receipt_files
		local expected_file_set = {}
		for index = 1, #expected_files do expected_file_set[expected_files[index]] = true end
		local line_number, gates, metrics, files = 0, 0, 0, 0
		local seen_gates, seen_metrics, seen_files, facts = {}, {}, {}, {}
		for line in bytes:gmatch("([^\n]+)\n") do
			line_number = line_number + 1
			if line_number == 1 then
				if line ~= "schema\tgrug_wp40_r6_static_gate_receipt_v1" then
					fail("static receipt schema differs")
				end
			else
				local kind, name, value = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
				if kind == "gate" and value == "true" and expected_gates[name] and
						not seen_gates[name] then
					gates, seen_gates[name] = gates + 1, true
				elseif kind == "metric" and expected_metrics[name] and
						not seen_metrics[name] then
					local observed = unsigned(value, "static receipt metric")
					metrics, seen_metrics[name], facts[name] = metrics + 1, true, observed
				elseif kind == "file" and expected_file_set[name] and not seen_files[name] and
						value:match("^[0-9a-f]+$") and #value == 64 and
						sha256(common.read_file(loader.repo .. "/" .. name)) == value then
					files, seen_files[name] = files + 1, true
				else fail("static receipt row differs") end
				if not name or name == "" then fail("static receipt name is empty") end
			end
		end
		if gates ~= 6 or metrics ~= 2 or files ~= #expected_files then
			fail("static receipt population differs")
		end
		return bytes, facts
	end

	local function artifact_authority(path, expected_body)
		local bytes = common.read_file(loader.repo .. "/" .. path)
		local file_digest = sha256(bytes)
		local lines, last = 0, nil
		for line in bytes:gmatch("([^\n]+)\n") do lines, last = lines + 1, line end
		if not last or last:match("^artifact_sha256\t(.+)$") ~= expected_body then
			fail("fixed artifact body digest differs at " .. path)
		end
		return expected_body, file_digest, lines - 2, bytes
	end

	local function build_assignments()
		local result = {}
		local projection = loader.fixtures.projection()
		for index = 1, #projection.race_regions do
			local row = projection.race_regions[index]
			result[row.race] = {g1 = row.g1, g2 = row.g2, faction = row.faction,
				cultural = row.cultural}
		end
		for index = 1, #RACES do if not result[RACES[index]] then
			fail("race assignment population differs")
		end end
		return result
	end

	local function build_vocabulary(static)
		local r5 = dofile(loader.repo .. "/tools/wp40/simple_map_r5_common.lua")
		local rows = {}
		local function list(kind, values)
			for index = 1, #values do
				rows[#rows + 1] = structured("vocabulary", {kind, index}, {values[index]})
			end
		end
		local opcodes = {}
		for index = 1, #r5.OPCODES do opcodes[index] = r5.OPCODES[index] end
		opcodes[33], opcodes[34] = "BIOME_DUST", "CULTURAL_SOURCE"
		local roles = {}
		for index = 1, #r5.TARGET_ROLES do roles[index] = r5.TARGET_ROLES[index] end
		roles[17] = "R6_CONTENT"
		local policies = {}
		for index = 1, #r5.REPLACE_POLICIES do
			policies[index] = r5.REPLACE_POLICIES[index]
		end
		policies[8], policies[9], policies[10] = "DECORATION_CELL",
			"CULTURAL_CELL", "BIOME_FILLER_EXACT"
		list("opcode", opcodes)
		list("role", roles)
		list("policy", policies)
		list("old_content_class", r5.CONTENT_CLASSES)
		list("water_class", {"land", "planned_water", "coastal_shelf",
			"deep_ocean", "immutable_dragon_channel"})
		list("surface_kind", {"dry_top", "dry_shore", "wet_bed"})
		list("candidate_kind", {"cultural", "decoration"})
		list("settlement_class", {"emergent_or_large_template",
			"ordinary_tree_template", "simple_multi_node_trunk", "ground_cover"})
		local domains = static.hash.domains()
		list("hash_domain", domains)
		for _, entry in ipairs({{1, "p7_material"}, {2, "dust"},
				{4, "wp43_resource"}, {8, "decoration"}, {16, "cultural"}}) do
			rows[#rows + 1] = structured("vocabulary", {"target_role_bit", entry[1]},
				{entry[2]})
		end
		local target_kinds = {"air", "solid", "water_source"}
		for index = 0, 2 do
			rows[#rows + 1] = structured("vocabulary", {"target_kind", index},
				{target_kinds[index + 1]})
		end
		rows[#rows + 1] = structured("vocabulary", {"param2_mode", 1}, {"exact"})
		return rows
	end

	local function build_content_rows(static)
		local rows, contract = {}, static.content_contract
		for ref = 1, #contract.content_names do
			rows[#rows + 1] = structured("content", {ref},
				{contract.content_names[ref], contract.content_cids[ref],
					contract.content_kind_masks[ref]})
		end
		return rows
	end

	local function build_template_rows(static)
		local rows, records = {}, static.templates.records()
		for ref = 1, #records do
			for rotation = 0, 3 do
				local record = static.templates.rotation(records[ref].definition_id, rotation)
				rows[#rows + 1] = structured("template",
					{ref, records[ref].definition_id, rotation},
					{record.digest, record.size_x, record.size_y, record.size_z,
						record.size_x * record.size_y * record.size_z})
			end
		end
		return rows
	end

	local function build_fixed_rows()
		local rows = {}
		local r2_body, r2_file, r2_population, r2_bytes = artifact_authority(
			"docs/research/wp40-simple-map-r2-artifact.tsv",
			"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b")
		rows[#rows + 1] = structured("fixed_projection", {"r2_layout"},
			{r2_body, r2_file, r2_population})
		if not r2_bytes:find(
				"validator\troutes\tgrug_wp40_simple_map_r2_routes_result_v1\ttrue\t0\n",
				1, true) then
			fail("R2 fixed-route authority is not accepted")
		end
		local housing = {}
		for line in r2_bytes:gmatch("([^\n]+)\n") do
			if line:match("^housing_mask\t") then housing[#housing + 1] = line .. "\n" end
		end
		if #housing ~= 10 then fail("R2 housing-mask projection differs") end
		rows[#rows + 1] = structured("fixed_projection", {"r2_housing"},
			{sha256(table.concat(housing)), r2_file, #housing})
		local anchors = {}
		for index = 1, #loader.source.anchors do
			anchors[loader.source.anchors[index].id] = loader.source.anchors[index]
		end
		local apex = {}
		for index = 1, #loader.source.apex_sockets do
			local socket = loader.source.apex_sockets[index]
			local anchor = assert(anchors[socket.anchor_id])
			apex[#apex + 1] = table.concat({socket.id, socket.anchor_id, socket.species,
				anchor.position.x + socket.offset.x, -700,
				anchor.position.z + socket.offset.z,
				"hard_apex_socket_column_v1"}, "\t") .. "\n"
		end
		table.sort(apex, common.less_bytes)
		if #apex ~= 24 then fail("R2 apex-socket projection differs") end
		rows[#rows + 1] = structured("fixed_projection", {"r2_apex_sockets"},
			{sha256(table.concat(apex)), r2_file, #apex})
		local authorities = {
			{"r3_height", "docs/research/wp40-simple-map-r3-artifact.tsv",
				"09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2"},
			{"r4_logical_biome", "docs/research/wp40-simple-map-r4-artifact.tsv",
				"bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca"},
			{"r5_p2_p6", "docs/research/wp40-simple-map-r5-artifact.tsv",
				"a0e7241dabf71833c490d574cbbf4702cdd2c63289277bcc3f49255039a78e1b"},
		}
		for index = 1, #authorities do
			local row = authorities[index]
			local body, file_digest, population = artifact_authority(row[2], row[3])
			rows[#rows + 1] = structured("fixed_projection", {row[1]},
				{body, file_digest, population})
		end
		return rows
	end

	local function build_census_rows()
		local rows, roster = {}, dofile(loader.repo ..
			"/tools/wp40/r6/census_roster.lua")
		if roster.schema ~= "grug_wp40_r6_census_roster_v1" or #roster.rows ~= 48 then
			fail("frozen census roster differs")
		end
		local bytes = {}
		for index = 1, #roster.rows do
			local value = roster.rows[index]
			bytes[index] = table.concat(value, "\t") .. "\n"
			rows[#rows + 1] = structured("census_cell",
				{value[1], value[2], value[3], value[4]},
				{value[5], value[6], value[7], value[8]})
		end
		if sha256(table.concat(bytes)) ~= roster.selection_sha256 then
			fail("frozen census roster hash differs")
		end
		return rows, roster.selection_sha256
	end

	local function access_row(gate, owner, resource, discriminator, record,
			witness_id)
		if not record then
			return structured("access", {gate, owner, resource or "",
				discriminator or ""}, {false, "", "", "", "", "", ""})
		end
		return structured("access", {gate, owner, resource or "",
			discriminator or ""}, {true, record.slot, record.zone, record.x,
				record.y, record.z, witness_id})
	end

	local function route_witness(faction, target_zone_numeric)
		local adjacency, starts = {}, {}
		for index = 1, #loader.source.zones do adjacency[index] = {} end
		for index = 1, #loader.source.routes do
			local route = loader.source.routes[index]
			adjacency[route.zone_a][#adjacency[route.zone_a] + 1] =
				{zone = route.zone_b, route = route.id}
			adjacency[route.zone_b][#adjacency[route.zone_b] + 1] =
				{zone = route.zone_a, route = route.id}
		end
		for zone = 1, #adjacency do
			table.sort(adjacency[zone], function(left, right)
				if left.route ~= right.route then
					return common.less_bytes(left.route, right.route)
				end
				return left.zone < right.zone
			end)
			local row = loader.source.zones[zone]
			if row.faction == faction and row.level_min == 1 then starts[#starts + 1] = zone end
		end
		table.sort(starts)
		local queue, head, seen, previous, previous_route = {}, 1, {}, {}, {}
		for index = 1, #starts do
			local zone = starts[index]
			queue[#queue + 1], seen[zone], previous[zone] = zone, true, 0
		end
		while head <= #queue and not seen[target_zone_numeric] do
			local zone = queue[head]
			head = head + 1
			for index = 1, #adjacency[zone] do
				local edge = adjacency[zone][index]
				if not seen[edge.zone] then
					seen[edge.zone], previous[edge.zone], previous_route[edge.zone] =
						true, zone, edge.route
					queue[#queue + 1] = edge.zone
				end
			end
		end
		if not seen[target_zone_numeric] then fail("fixed route graph cannot reach witness") end
		local routes, zone = {}, target_zone_numeric
		while previous[zone] ~= 0 do
			table.insert(routes, 1, previous_route[zone])
			zone = previous[zone]
		end
		if #routes == 0 then fail("opposing access route is empty") end
		return "route_chain:" .. loader.source.zones[zone].id .. ">" ..
			table.concat(routes, ",") .. ">" .. loader.source.zones[target_zone_numeric].id
	end

	local function build_access_rows(scan, assignments)
		local rows, pass = {}, {access_native_region = true,
			access_opposing_frontier = true, access_deep_cross_border = true,
			access_island_apex = true, access_cultural = true}
		local loaded_by_slot = {}
		local census_by_cube, horizontal_by_owner = {}, {}
		local roster = dofile(loader.repo .. "/tools/wp40/r6/census_roster.lua")
		local roster_bucket = {}
		for index = 1, #roster.rows do
			local row = roster.rows[index]
			roster_bucket[table.concat({row[1], row[4], row[3]}, "\0")] = row[2]
		end
		local cultural_by_key = {}
		for index = 1, #loader.fixtures.cultural do
			cultural_by_key[loader.fixtures.cultural[index].key] =
				loader.fixtures.cultural[index]
		end
		local function validate_record(gate, owner, resource, discriminator, record)
			local loaded = loaded_by_slot[record.slot]
			if not loaded then
				loaded = loader.new_evidence(loader.seed_corpus.fixed[record.slot])
				loaded_by_slot[record.slot] = loaded
			end
			local water, zone_numeric, zone_id, biome, race =
				loaded.planner_source.column_values_at(record.x, record.z)
			local zone = loader.source.zones[zone_numeric or 0]
			local admitted = water == "land" or water == "planned_water"
			if not admitted or not zone or
					zone_id ~= record.zone or race ~= record.race or
					zone.id ~= record.zone then
				fail("access root does not bind to its declared zone/race")
			end
			local root_id = table.concat({"root", record.slot, record.x, record.y,
				record.z}, ":")
			if gate ~= "access_cultural" then
				local cell_x, cell_y, cell_z = math.floor(record.x / 16),
					math.floor(record.y / 16), math.floor(record.z / 16)
				local cube_key = table.concat({record.slot, record.race, cell_x,
					cell_y, cell_z}, "\0")
				local result = census_by_cube[cube_key]
				if not result then
					local bucket = roster_bucket[table.concat({record.race, cell_x,
						cell_z}, "\0")]
					if not bucket then fail("access root is outside the frozen census") end
					result = loaded.settlement_fixture.scan_census_cube({race = record.race,
						bucket = bucket, zone_id = record.zone, cell_x = cell_x,
						cell_y = cell_y, cell_z = cell_z})
					census_by_cube[cube_key] = result
				end
				local witness = result.witnesses[resource]
				if not witness or witness.zone_id ~= record.zone or
						witness.x ~= record.x or witness.y ~= record.y or
						witness.z ~= record.z then
					fail("access resource root is not the production census witness")
				end
			else
				local owner_x = -30912 + math.floor((record.x + 30912) / 80) * 80
				local owner_z = -30912 + math.floor((record.z + 30912) / 80) * 80
				local owner_key = table.concat({record.slot, owner_x, owner_z}, "\0")
				local result = horizontal_by_owner[owner_key]
				if not result then
					local cultural_candidates, decoration_candidates = {}, {}
					for cell_z = owner_z / 16, owner_z / 16 + 4 do
						for cell_x = owner_x / 16, owner_x / 16 + 4 do
							local cultural, decorations =
								loaded.planner_fixture.build_cell(cell_x, cell_z)
							for index = 1, #cultural do
								cultural_candidates[#cultural_candidates + 1] = cultural[index]
							end
							for index = 1, #decorations do
								decoration_candidates[#decoration_candidates + 1] =
									decorations[index]
							end
						end
					end
					result = loaded.settlement_fixture.scan_horizontal_owner(owner_x,
						owner_z, cultural_candidates, decoration_candidates)
					horizontal_by_owner[owner_key] = result
				end
				local witness = result.witnesses[resource .. "\0" .. discriminator]
				if not witness or witness.zone_id ~= record.zone or
						witness.x ~= record.x or witness.y ~= record.y or
						witness.z ~= record.z then
					fail("access cultural root is not the production owner witness")
				end
			end
			if gate == "access_native_region" then
				if owner ~= race or (resource ~= assignments[race].g1 and
						resource ~= assignments[race].g2) then
					fail("native access root predicate differs")
				end
				return "census_" .. root_id
			elseif gate == "access_opposing_frontier" then
				local accord_race = race == "dwarf" or race == "elf" or race == "human"
				if zone.level_min < 31 or (owner == "accord" and
						(resource ~= "ruby" or accord_race)) or (owner == "throng" and
						(resource ~= "sapphire" or not accord_race)) or
						(owner ~= "accord" and owner ~= "throng") then
					fail("opposing-frontier access predicate differs")
				end
				return route_witness(owner, zone_numeric) .. ":" .. root_id
			elseif gate == "access_deep_cross_border" then
				local accord_race = race == "dwarf" or race == "elf" or race == "human"
				local territory_rule, territory_authority = zone.territory_rule,
					"surface_zone:" .. tostring(zone.territory_rule)
				if admitted and record.y <= DEEP_CONTESTED_MAX_Y then
					territory_rule, territory_authority = "contested_land",
						DEEP_TERRITORY_AUTHORITY
				end
				if territory_rule ~= "contested_land" or (owner == "accord" and
						(resource ~= "ruby" or accord_race)) or (owner == "throng" and
						(resource ~= "sapphire" or not accord_race)) or
						(owner ~= "accord" and owner ~= "throng") then
					fail("deep cross-border access predicate differs")
				end
				return "territory_rule_at:y<=" .. tostring(DEEP_CONTESTED_MAX_Y) ..
					":admitted_" .. water .. ":contested_land:" .. territory_authority ..
					":" .. root_id
			elseif gate == "access_cultural" then
				local definition = cultural_by_key[resource]
				local biome_ok = false
				if definition then for index = 1, #definition.biomes do
					if definition.biomes[index] == biome then biome_ok = true break end
				end end
				local concentrated = zone_id == (definition and definition.concentrated_zone)
				if not definition or owner ~= definition.race or race ~= definition.race or
						not biome_ok or (discriminator == "concentrated") ~= concentrated or
						(discriminator ~= "ordinary" and discriminator ~= "concentrated") then
					fail("cultural access root predicate differs")
				end
				return "cultural_" .. root_id
			end
			fail("unknown access witness gate")
		end
		local function required(gate, owner, resource, discriminator)
			local key = table.concat({gate, owner, resource or "",
				discriminator or ""}, "\0")
			local record = scan.access[key]
			local witness = record and validate_record(gate, owner, resource,
				discriminator, record) or ""
			rows[#rows + 1] = access_row(gate, owner, resource, discriminator,
				record, witness)
			if not record then pass[gate] = false end
		end
		for index = 1, #RACES do
			local race, assignment = RACES[index], assignments[RACES[index]]
			required("access_native_region", race, assignment.g1, "")
			required("access_native_region", race, assignment.g2, "")
		end
		required("access_opposing_frontier", "accord", "ruby", "")
		required("access_opposing_frontier", "throng", "sapphire", "")
		required("access_deep_cross_border", "accord", "ruby", "")
		required("access_deep_cross_border", "throng", "sapphire", "")
		for index = 1, #RACES do
			local race, key = RACES[index], assignments[RACES[index]].cultural
			required("access_cultural", race, key, "ordinary")
			required("access_cultural", race, key, "concentrated")
		end
		local anchors, islands = {}, {}
		for index = 1, #loader.source.anchors do
			anchors[loader.source.anchors[index].id] = loader.source.anchors[index]
		end
		for index = 1, #loader.source.islands do
			islands[loader.source.islands[index].zone_numeric_id] =
				loader.source.islands[index].id
		end
		local ordinal = {}
		for index = 1, #loader.source.apex_sockets do
			local socket = loader.source.apex_sockets[index]
			local anchor = assert(anchors[socket.anchor_id])
			local island = assert(islands[anchor.zone_numeric_id])
			local count_key = island .. "\0" .. socket.species
			ordinal[count_key] = (ordinal[count_key] or 0) + 1
			local record = {slot = "", zone = loader.source.zones[
				anchor.zone_numeric_id].id, x = anchor.position.x + socket.offset.x,
				y = -700, z = anchor.position.z + socket.offset.z}
			rows[#rows + 1] = structured("access",
				{"access_island_apex", island, socket.species,
					tostring(ordinal[count_key])},
				{true, "", record.zone, record.x, record.y, record.z, socket.id})
		end
		if #rows ~= 52 then fail("access row population differs") end
		return rows, pass
	end

	local function validate_apex_authority(scan)
		local anchors, hard_by_socket, hard_count = {}, {}, 0
		local exclusion_by_source, exclusion_by_id = {}, {}
		for index = 1, #loader.source.anchors do
			anchors[loader.source.anchors[index].id] = loader.source.anchors[index]
		end
		for index = 1, #loader.source.hard_protection do
			local hard = loader.source.hard_protection[index]
			if hard.recipe_id == "hard_apex_socket_column_v1" then
				hard_count = hard_count + 1
				if not hard.socket_id or hard_by_socket[hard.socket_id] then
					fail("apex hard-protection identity differs")
				end
				hard_by_socket[hard.socket_id] = hard
			end
		end
		for index = 1, #loader.source.claim_exclusions do
			local exclusion = loader.source.claim_exclusions[index]
			exclusion_by_id[exclusion.id] = exclusion
			if exclusion.recipe_id == "exclude_active_core_v1" then
				if exclusion_by_source[exclusion.source_id] then
					fail("duplicate active-hard static exclusion")
				end
				exclusion_by_source[exclusion.source_id] = exclusion
			end
		end
		if #loader.source.apex_sockets ~= 24 or hard_count ~= 24 or
				type(scan.apex_overlap_count) ~= "number" or
				scan.apex_overlap_count ~= 0 then
			fail("apex worker/static population differs")
		end
		local evidence = loader.new_evidence("0")
		local lines, seen, species = {}, {}, {}
		for index = 1, #loader.source.apex_sockets do
			local socket = loader.source.apex_sockets[index]
			local anchor, hard = anchors[socket.anchor_id], hard_by_socket[socket.id]
			local exclusion = hard and exclusion_by_source[hard.id]
			if not anchor or not hard or not exclusion or seen[socket.id] or
					hard.resource_key ~= socket.species or
					hard.source_anchor_id ~= socket.anchor_id or hard.active ~= true or
					hard.status ~= "active" or hard.activation_owner ~= "WP40" or
					exclusion.id ~= "exclude:active:" .. hard.id or
					exclusion.source_id ~= hard.id or
					exclusion.coverage ~= "exact_active_hard_footprint" then
				fail("apex socket/hard-protection binding differs")
			end
			seen[socket.id] = true
			local x, z = anchor.position.x + socket.offset.x,
				anchor.position.z + socket.offset.z
			local _, returned_exclusion_id =
				evidence.horizontal.static_exclusion_values_at(x, z)
			if not hard.center or hard.center.x ~= x or hard.center.z ~= z or
					returned_exclusion_id ~= exclusion.id or
					not exclusion_by_id[returned_exclusion_id] or
					exclusion_by_id[returned_exclusion_id].recipe_id ~=
						"exclude_active_core_v1" or
					exclusion_by_id[returned_exclusion_id].source_id ~= hard.id then
				fail("apex socket is absent from static exclusion")
			end
			species[socket.species] = (species[socket.species] or 0) + 1
			lines[#lines + 1] = table.concat({socket.id, socket.anchor_id,
				socket.species, x, -700, z, hard.id, exclusion.id,
				returned_exclusion_id,
				"hard_apex_socket_column_v1",
				"worker_overlap=" .. tostring(scan.apex_overlap_count)}, "\t") .. "\n"
		end
		local species_count = 0
		for _, count in pairs(species) do
			species_count = species_count + 1
			if count ~= 4 then fail("apex species socket parity differs") end
		end
		if species_count ~= 6 then fail("apex species population differs") end
		table.sort(lines, common.less_bytes)
		return scan.apex_overlap_count, lines
	end

	local function build_region_rows(scan)
		local rows, lowest, highest
		rows = {}
		for index = 1, #RACES do
			local race, h, v = RACES[index], scan.hosts[RACES[index]],
				scan.veins[RACES[index]]
			if h <= 0 or h > 8388608 or v < 0 or v > h then
				fail("region density bound differs at " .. race)
			end
			local candidate = {race = race, h = h, v = v}
			if not lowest or v * lowest.h < lowest.v * h or
					(v * lowest.h == lowest.v * h and
						common.less_bytes(race, lowest.race)) then
				lowest = candidate
			end
			if not highest or v * highest.h > highest.v * h or
					(v * highest.h == highest.v * h and
						common.less_bytes(race, highest.race)) then
				highest = candidate
			end
			rows[#rows + 1] = structured("region_denominator", {race}, {h})
			rows[#rows + 1] = structured("region_opportunity", {race}, {v, 384, true})
		end
		local left = 20 * highest.v * lowest.h
		local right = 21 * lowest.v * highest.h
		local pass = left <= right
		rows[#rows + 1] = structured("region_parity", {lowest.race, highest.race},
			{lowest.v, lowest.h, highest.v, highest.h, left, right, pass})
		return rows, pass
	end

	local function parse_centiseconds(value, label)
		local whole, fraction = value:match("^([0-9]+)%.([0-9][0-9])$")
		if not whole then fail(label .. " is not fixed two-decimal seconds") end
		return assert(tonumber(whole)) * 100 + assert(tonumber(fraction))
	end

	local function metric_row(family, run, phase, name, observed, ceiling)
		return structured(family, {run, phase, name},
			{observed, ceiling, observed <= ceiling})
	end

	local function trailer_length()
		local fields = {"artifact_body_sha256"}
		for _ = 1, 10 do fields[#fields + 1] = "" end
		fields[#fields + 1] = string.rep("0", 64)
		for _ = 2, 12 do fields[#fields + 1] = "" end
		return #table.concat(fields, "\t") + 1
	end

	function module.static_preflight()
		local static = loader.new_static()
		local rows = build_vocabulary(static)
		append(rows, build_content_rows(static))
		append(rows, build_template_rows(static))
		append(rows, build_fixed_rows())
		local census, roster_digest = build_census_rows()
		append(rows, census)
		return {rows = rows, roster_digest = roster_digest,
			digest = canonical_digest("static_preflight_v1", lines_for(rows))}
	end

	function module.finalize(spec, worker_descriptors, micro_descriptors,
			production_descriptor)
		local assignments = build_assignments()
		local static = loader.new_static()
		local scan = worker_scan(worker_descriptors, assignments, static)
		local manifest = loader.fixtures.r6_manifest()
		local rows = {}
		local function add(row) rows[#rows + 1] = row return row end
		local static_bytes, static_facts = static_receipt(
			spec.scratch .. "/static-gates.tsv")
		local projection, projection_bytes = key_value_file(spec.projection_path,
			"grug_wp40_r6_pilot_projection_v1")
		if projection.assignment_sha256 ~= spec.assignment_sha256 then
			fail("pilot assignment differs")
		end
		if projection.population_sha256 ~= projection.reference_sha256 then
			fail("pilot sharded/reference population differs")
		end
		local census_rows, roster_digest = build_census_rows()
		if projection.roster_selection_sha256 and
				projection.roster_selection_sha256 ~= roster_digest then
			fail("pilot roster selection differs")
		end
		local worker_set_digest = canonical_digest("worker_set_v1",
			scan.worker_bindings)
		local static_digest = sha256(static_bytes)
		if projection.static_gate_receipt_sha256 ~= static_digest then
			fail("static source receipt changed after pilot approval")
		end
		local identity_rows = {
			structured("identity", {"artifact_schema"}, {"grug_wp40_r6_artifact_v1"}),
			structured("identity", {"contract_sha256"},
				{"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f"}),
			structured("identity", {"accepted_base_commit"},
				{"56405edecb5c80e610e2e5c47a237b03195c6b59"}),
			structured("identity", {"r6_status"}, {loader.r6_module.status()}),
			structured("identity", {"assignment_sha256"}, {spec.assignment_sha256}),
			structured("identity", {"approved_projection_sha256"},
				{spec.projection_sha256}),
			structured("identity", {"worker_set_sha256"}, {worker_set_digest}),
			structured("identity", {"static_gate_receipt_sha256"}, {static_digest}),
			structured("identity", {"census_roster_sha256"}, {roster_digest}),
			structured("identity", {"seed_population"}, {"32"}),
			structured("identity", {"horizontal_columns_per_seed"}, {"49980561"}),
			structured("identity", {"census_xz_cells"}, {"48"}),
			structured("identity", {"census_y_cells"}, {"8"}),
		}
		for index = 1, #NOT_OWNED do
			identity_rows[#identity_rows + 1] = structured("identity",
				{"not_owned_opportunity/" .. NOT_OWNED[index]}, {"0"})
		end
		append(rows, identity_rows)
		local input_rows = {}
		local input_count = 0
		for path, digest in pairs(manifest.input_sha256) do
			input_rows[#input_rows + 1] = structured("input_sha256", {path},
				{digest, manifest.input_bytes[path]})
			input_count = input_count + 1
		end
		if input_count ~= 38 then fail("input manifest population differs") end
		append(rows, input_rows)
		local vocabulary_rows = build_vocabulary(static)
		local content_rows = build_content_rows(static)
		local template_rows = build_template_rows(static)
		local fixed_rows = build_fixed_rows()
		append(rows, vocabulary_rows) append(rows, content_rows)
		append(rows, template_rows) append(rows, fixed_rows) append(rows, census_rows)
		local region_rows, region_pass = build_region_rows(scan)
		local access_rows, access_pass = build_access_rows(scan, assignments)
		local apex_overlap_count, apex_authority_lines = validate_apex_authority(scan)
		append(rows, region_rows) append(rows, access_rows)

		local static_source_lines = {}
		for index = 1, #loader.fixtures.static_receipt_files do
			local path = loader.fixtures.static_receipt_files[index]
			static_source_lines[#static_source_lines + 1] = path .. "\t" ..
				sha256(common.read_file(loader.repo .. "/" .. path)) .. "\n"
		end
		local micro_source_digest = canonical_digest("micro_kat_source_set_v1",
			static_source_lines)
		local micro_bytes = common.read_file(micro_descriptors[1].path)
		if micro_bytes ~= common.read_file(micro_descriptors[2].path) or
				micro_descriptors[1].sha256 ~= micro_descriptors[2].sha256 then
			fail("micro-KAT parity differs")
		end
		validate_micro_receipt(micro_bytes)
		local production_values, production_bytes = key_value_file(
			production_descriptor.path, "grug_wp40_r6_production_kat_v1")
		local production_body, production_embedded = production_bytes:match(
			"^(.*)output_sha256\t([0-9a-f]+)\n$")
		local production_expected = {
			candidate_cell_count = "49", candidate_count = "190",
			column_count = "6400", generation = "1",
			plan_schema = "grug_wp40_r6_refinement_plan_v1",
			planner_allocator_sealed = "true", planner_peak_candidate_cells = "49",
			planner_peak_candidates = "190",
			planner_retained_buffer_growth_events = "0", result_code = "applied_cplq",
			schema = "grug_wp40_r6_production_kat_v1",
			settlement_allocator_sealed = "true",
			settlement_content_dirty_columns = "6400",
			settlement_light_dirty_columns = "6400",
			settlement_liquid_dirty_columns = "6400",
			settlement_modified_voxels = "230436",
			settlement_param2_dirty_columns = "25",
			settlement_peak_successor_runs = "10854", settlement_replay_count = "1",
			settlement_retained_buffer_growth_events = "0",
			status = "disabled_r6_surface_resource_content", vm_active_volume = "1404928",
			vm_calc_lighting_calls = "1", vm_get_data_calls = "1",
			vm_get_light_calls = "2", vm_get_param2_calls = "1",
			vm_inactive_tail_checks = "0", vm_inactive_tail_unchanged = "true",
			vm_retained_capacity = "1404928", vm_set_data_calls = "1",
			vm_set_light_calls = "1", vm_set_lighting_calls = "1",
			vm_set_param2_calls = "1", vm_trace_entries = "11",
			vm_trace_sha256 =
				"821f06e034958b82cac1e0ce3a3ff6470e6c09fdd2ec36b00650ca58da6d6cf1",
			vm_update_liquids_calls = "1",
			output_sha256 =
				"5391681b80a4ea4c6b41948bfc8cb6b4c74ddb4e7f0a148daa80d2749773d1b9",
		}
		local production_count, expected_production_count = 0, 0
		for key, value in pairs(production_values) do
			production_count = production_count + 1
			if production_expected[key] ~= value then fail("production KAT key/value differs") end
		end
		for key in pairs(production_expected) do
			expected_production_count = expected_production_count + 1
			if production_values[key] == nil then fail("production KAT key is absent: " .. key) end
		end
		if not production_body or #production_embedded ~= 64 or
				sha256(production_body) ~= production_embedded or
				production_values.output_sha256 ~= production_embedded or
				production_count ~= expected_production_count then
			fail("production transaction KAT differs")
		end
		local production_source_digest = canonical_digest(
			"production_kat_source_set_v1", static_source_lines)
		local kat_rows = {
			structured("kat", {"luajit", "final_micro"},
				{micro_source_digest, micro_descriptors[1].sha256, true}),
			structured("kat", {"puc51", "final_micro"},
				{micro_source_digest, micro_descriptors[2].sha256, true}),
			structured("kat", {"luajit", "production_vm"},
				{production_source_digest, production_descriptor.sha256, true}),
		}
		append(rows, kat_rows)

		local vm_rows = {
			metric_row("vm_metric", "pilot", "sharded", "wall_centiseconds",
				parse_centiseconds(projection.pilot_wall_seconds, "pilot wall"), 8640000),
			metric_row("vm_metric", "pilot", "sharded", "cpu_centiseconds",
				parse_centiseconds(projection.pilot_cpu_seconds, "pilot CPU"), 60480000),
			metric_row("vm_metric", "pilot", "sharded", "peak_rss_kib",
				unsigned(projection.pilot_peak_rss_kib, "pilot RSS"), 2097152),
			metric_row("vm_metric", "projection", "fleet", "wall_centiseconds",
				parse_centiseconds(projection.projected_fleet_wall_seconds,
					"projected wall"), 60480000),
			metric_row("vm_metric", "projection", "fleet", "cpu_centiseconds",
				parse_centiseconds(projection.projected_fleet_cpu_seconds,
					"projected CPU"), 60480000),
			metric_row("vm_metric", "projection", "fleet", "peak_rss_kib",
				unsigned(projection.projected_fleet_peak_rss_kib, "projected RSS"),
				16777216),
			metric_row("vm_metric", "static", "disabled", "callback_registrations",
				static_facts.activation_api_matches, 0),
			metric_row("vm_metric", "static", "disabled", "map_writer_count",
				static_facts.map_writer_matches, 0),
			metric_row("vm_metric", "fleet", "apex_nonoverlap",
				"accepted_overlap_count", apex_overlap_count, 0),
			metric_row("vm_metric", "production_kat", "transaction", "set_data_calls",
				unsigned(production_values.vm_set_data_calls, "production data calls"), 1),
			metric_row("vm_metric", "production_kat", "transaction", "set_param2_calls",
				unsigned(production_values.vm_set_param2_calls, "production param2 calls"), 1),
			metric_row("vm_metric", "production_kat", "transaction", "set_light_calls",
				unsigned(production_values.vm_set_light_calls, "production light calls"), 1),
			metric_row("vm_metric", "production_kat", "transaction", "update_liquids_calls",
				unsigned(production_values.vm_update_liquids_calls,
					"production liquid calls"), 1),
			metric_row("vm_metric", "production_kat", "transaction", "replay_count",
				unsigned(production_values.settlement_replay_count,
					"production replay count"), 1),
		}
		for index = 1, 7 do
			local prefix = "pilot_worker_" .. tostring(index)
			vm_rows[#vm_rows + 1] = metric_row("vm_metric", prefix, "shard",
				"wall_centiseconds", parse_centiseconds(projection[prefix ..
					"_wall_seconds"], prefix .. " wall"), 8640000)
			vm_rows[#vm_rows + 1] = metric_row("vm_metric", prefix, "shard",
				"cpu_centiseconds", parse_centiseconds(projection[prefix ..
					"_cpu_seconds"], prefix .. " CPU"), 8640000)
			vm_rows[#vm_rows + 1] = metric_row("vm_metric", prefix, "shard",
				"peak_rss_kib", unsigned(projection[prefix .. "_peak_rss_kib"],
					prefix .. " RSS"), 2097152)
		end
		vm_rows[#vm_rows + 1] = metric_row("vm_metric", "pilot_reference",
			"targeted", "wall_centiseconds", parse_centiseconds(
				projection.reference_wall_seconds, "reference wall"), 8640000)
		vm_rows[#vm_rows + 1] = metric_row("vm_metric", "pilot_reference",
			"targeted", "cpu_centiseconds", parse_centiseconds(
				projection.reference_cpu_seconds, "reference CPU"), 8640000)
		vm_rows[#vm_rows + 1] = metric_row("vm_metric", "pilot_reference",
			"targeted", "peak_rss_kib", unsigned(projection.reference_peak_rss_kib,
				"reference RSS"), 2097152)
		append(rows, vm_rows)

		local allocation_rows = {
			metric_row("allocation_metric", "pilot", "sharded", "combined_rows",
				unsigned(projection.pilot_combined_rows, "pilot rows"), MAX_ROWS),
			metric_row("allocation_metric", "pilot", "sharded", "combined_bytes",
				unsigned(projection.pilot_combined_bytes, "pilot bytes"), MAX_BYTES),
			metric_row("allocation_metric", "pilot", "sharded", "scratch_bytes",
				unsigned(projection.pilot_scratch_bytes, "pilot scratch"), MAX_BYTES),
			metric_row("allocation_metric", "pilot", "all_evidence", "scratch_bytes",
				unsigned(projection.pilot_evidence_scratch_bytes,
					"pilot evidence scratch"), MAX_BYTES),
			metric_row("allocation_metric", "projection", "fleet", "artifact_rows",
				unsigned(projection.projected_artifact_rows, "projected rows"), MAX_ROWS),
			metric_row("allocation_metric", "projection", "fleet", "artifact_bytes",
				unsigned(projection.projected_artifact_bytes, "projected bytes"), MAX_BYTES),
			metric_row("allocation_metric", "projection", "fleet", "scratch_bytes",
				unsigned(projection.projected_fleet_scratch_bytes,
					"projected scratch"), MAX_BYTES),
			metric_row("allocation_metric", "projection", "fleet", "seed_body_bytes",
				unsigned(projection.projected_seed_body_bytes,
					"projected seed body"), MAX_BYTES),
			metric_row("allocation_metric", "projection", "global",
				"row_population", unsigned(projection.projected_global_rows,
					"projected global rows"), MAX_ROWS),
			metric_row("allocation_metric", "projection", "global",
				"row_byte_ceiling", unsigned(projection.projected_global_row_byte_ceiling,
					"projected global row bytes"), MAX_BYTES),
			metric_row("allocation_metric", "planner", "retained", "candidate_capacity",
				65536, 65536),
			metric_row("allocation_metric", "settlement", "retained", "run_capacity",
				512000, 512000),
			metric_row("allocation_metric", "planner", "hotpath",
				"retained_buffer_growth_events", unsigned(
					production_values.planner_retained_buffer_growth_events,
					"production planner retained growth"), 0),
			metric_row("allocation_metric", "settlement", "hotpath",
				"retained_buffer_growth_events", unsigned(
					production_values.settlement_retained_buffer_growth_events,
					"production settlement retained growth"), 0),
		}
		local mandatory_gate_count = 20
		local final_row_count = scan.kept_rows + #rows + #allocation_rows + 2 +
			mandatory_gate_count
		local final_rows_metric = metric_row("allocation_metric", "final", "artifact",
			"data_rows", final_row_count, MAX_ROWS)
		local final_bytes_metric = metric_row("allocation_metric", "final", "artifact",
			"bytes", 0, MAX_BYTES)
		allocation_rows[#allocation_rows + 1] = final_rows_metric
		allocation_rows[#allocation_rows + 1] = final_bytes_metric

		local gate_ids = {"input_manifest", "vocabulary_manifest",
			"p7_p9_schema_fixture", "r2_r5_projection", "complete_ledgers",
			"region_natural_density_parity", "ordinary_camp_equality",
			"access_native_region", "access_opposing_frontier",
			"access_deep_cross_border", "access_island_apex", "access_cultural",
			"content_coverage", "apex_nonoverlap", "fixed_housing_projection",
			"allocation_bounds", "disabled_single_writer", "static_gates",
			"micro_kat_parity", "not_owned_not_evaluated"}
		local gate_pass = {
			input_manifest = true, vocabulary_manifest = true,
			p7_p9_schema_fixture = true, r2_r5_projection = true,
			complete_ledgers = true, region_natural_density_parity = region_pass,
			ordinary_camp_equality = true,
			access_native_region = access_pass.access_native_region,
			access_opposing_frontier = access_pass.access_opposing_frontier,
			access_deep_cross_border = access_pass.access_deep_cross_border,
			access_island_apex = access_pass.access_island_apex,
			access_cultural = access_pass.access_cultural,
			content_coverage = true, apex_nonoverlap = apex_overlap_count == 0,
			fixed_housing_projection = true, allocation_bounds = true,
			disabled_single_writer = true, static_gates = true,
			micro_kat_parity = true, not_owned_not_evaluated = true,
		}
		local provisional_gates = {}
		for index = 1, #gate_ids do
			provisional_gates[index] = structured("gate", {gate_ids[index]},
				{gate_pass[gate_ids[index]], string.rep("0", 64)})
		end
		local observed_bytes = 0
		local byte_count_converged = false
		for _ = 1, 4 do
			final_bytes_metric.values[1] = observed_bytes
			local global_bytes = 0
			for index = 1, #rows do global_bytes = global_bytes + #row_line(rows[index]) end
			for index = 1, #allocation_rows do
				global_bytes = global_bytes + #row_line(allocation_rows[index])
			end
			for index = 1, #provisional_gates do
				global_bytes = global_bytes + #row_line(provisional_gates[index])
			end
			local calculated = #HEADER + scan.kept_bytes + global_bytes + trailer_length()
			if calculated == observed_bytes then
				byte_count_converged = true
				break
			end
			observed_bytes = calculated
		end
		if not byte_count_converged then fail("artifact byte-count fixed point did not converge") end
		final_bytes_metric.values[1] = observed_bytes
		if final_row_count > MAX_ROWS or observed_bytes > MAX_BYTES then
			gate_pass.allocation_bounds = false
		end
		for index = 1, #allocation_rows do
			if not allocation_rows[index].values[3] then gate_pass.allocation_bounds = false end
		end

		local component = {}
		component.input_manifest = lines_for(input_rows)
		append(component.input_manifest, lines_for(identity_rows, function(row)
			return row.keys[1] == "contract_sha256"
		end))
		component.vocabulary_manifest = lines_for(vocabulary_rows)
		component.p7_p9_schema_fixture = lines_for(vocabulary_rows)
		append(component.p7_p9_schema_fixture, lines_for(content_rows))
		append(component.p7_p9_schema_fixture, lines_for(template_rows))
		append(component.p7_p9_schema_fixture, lines_for(kat_rows))
		component.r2_r5_projection = lines_for(fixed_rows)
		component.complete_ledgers = {}
		append(component.complete_ledgers, scan.worker_bindings)
		append(component.complete_ledgers, lines_for(census_rows))
		append(component.complete_ledgers, lines_for(region_rows))
		append(component.complete_ledgers, lines_for(access_rows))
		component.region_natural_density_parity = {}
		append(component.region_natural_density_parity, scan.region_lines)
		append(component.region_natural_density_parity, lines_for(region_rows))
		component.ordinary_camp_equality = lines_for(input_rows, function(row)
			return row.keys[1] == "docs/design/world.md" or
				row.keys[1] == "docs/design/world_zones.md"
		end)
		append(component.ordinary_camp_equality, lines_for(region_rows, function(row)
			return row.row_type == "region_opportunity"
		end))
		for _, gate in ipairs({"access_native_region", "access_opposing_frontier",
				"access_deep_cross_border", "access_island_apex", "access_cultural"}) do
			component[gate] = lines_for(access_rows, function(row)
				return row.keys[1] == gate
			end)
			append(component[gate], scan.worker_bindings)
		end
		append(component.access_opposing_frontier, lines_for(fixed_rows, function(row)
			return row.keys[1] == "r2_layout"
		end))
		append(component.access_opposing_frontier, lines_for(identity_rows, function(row)
			return row.keys[1] == "static_gate_receipt_sha256"
		end))
		append(component.access_deep_cross_border, lines_for(input_rows, function(row)
			return row.keys[1] == "docs/design/world.md" or
				row.keys[1] == "docs/design/world_zones.md"
		end))
		append(component.access_deep_cross_border, lines_for(identity_rows, function(row)
			return row.keys[1] == "static_gate_receipt_sha256"
		end))
		component.content_coverage = lines_for(content_rows)
		append(component.content_coverage, lines_for(template_rows))
		append(component.content_coverage, scan.worker_bindings)
		component.apex_nonoverlap = lines_for(fixed_rows, function(row)
			return row.keys[1] == "r2_apex_sockets"
		end)
		append(component.apex_nonoverlap, lines_for(access_rows, function(row)
			return row.keys[1] == "access_island_apex"
		end))
		append(component.apex_nonoverlap, lines_for(vm_rows, function(row)
			return row.keys[2] == "apex_nonoverlap"
		end))
		append(component.apex_nonoverlap, apex_authority_lines)
		append(component.apex_nonoverlap, scan.worker_bindings)
		append(component.apex_nonoverlap, lines_for(identity_rows, function(row)
			return row.keys[1] == "static_gate_receipt_sha256"
		end))
		component.fixed_housing_projection = lines_for(fixed_rows, function(row)
			return row.keys[1] == "r2_housing" or row.keys[1] == "r2_layout"
		end)
		component.allocation_bounds = lines_for(allocation_rows)
		component.disabled_single_writer = lines_for(identity_rows, function(row)
			return row.keys[1] == "r6_status" or
				row.keys[1] == "static_gate_receipt_sha256"
		end)
		append(component.disabled_single_writer, lines_for(vm_rows, function(row)
			return row.keys[2] == "disabled"
		end))
		component.static_gates = lines_for(identity_rows, function(row)
			return row.keys[1] == "static_gate_receipt_sha256"
		end)
		component.micro_kat_parity = lines_for(kat_rows, function(row)
			return row.keys[2] == "final_micro"
		end)
		component.not_owned_not_evaluated = lines_for(identity_rows, function(row)
			return row.keys[1]:match("^not_owned_opportunity/") ~= nil
		end)
		append(component.not_owned_not_evaluated, lines_for(input_rows, function(row)
			return row.keys[1] == "docs/design/world.md" or
				row.keys[1] == "docs/design/world_zones.md" or
				row.keys[1] == "docs/research/wp40-simple-map-r6-resource-density.tsv" or
				row.keys[1] == "docs/research/wp40-simple-map-r6-cultural-opportunities.tsv"
		end))

		local gate_rows = {}
		for index = 1, #gate_ids do
			local gate = gate_ids[index]
			if not gate_pass[gate] then fail("mandatory gate failed: " .. gate) end
			gate_rows[#gate_rows + 1] = structured("gate", {gate},
				{true, canonical_digest("gate/" .. gate .. "/v1", component[gate])})
		end
		append(rows, allocation_rows) append(rows, gate_rows)
		if scan.kept_rows + #rows ~= final_row_count then
			fail("final artifact row accounting differs")
		end
		return {schema = "grug_wp40_r6_worker_rows_v1", rows = rows}
	end

	return module
end
