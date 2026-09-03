-- Reject-only WP40 R7 gathering successor. This module owns no engine API and
-- can mutate world data only through the single private R6 successor closure.

return function(catalog, p9g_content, raw_sha256)
	local MAX_SAFE = 9007199254740991
	local MAX_CANDIDATES = 4096
	local HASH_PREFIX = "grug_wp40_r6_hash_v1"
	local REASONS = {
		"clipped_owner", "fixed_or_protected", "route_or_water",
		"housing_exclusion", "content_ignore", "wrong_zone", "wrong_biome",
		"wrong_shore", "wrong_support", "insufficient_clearance", "r6_occupancy",
	}
	local REASON_SET = {}
	for index = 1, #REASONS do REASON_SET[REASONS[index]] = true end
	local DRY_ISLAND_COAST = {
		["exclude:coast:island_stormscale"] = true,
		["exclude:coast:island_wyrmglass"] = true,
	}

	local function fail(message)
		error("fail_p9g: " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(label .. " is not an exact bounded integer")
		end
		return value
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then fail(label .. " has unexpected field " .. tostring(key)) end
		end
		for key, requirement in pairs(allowed) do
			if requirement ~= "optional" and value[key] == nil then
				fail(label .. " is missing " .. key)
			end
		end
		return value
	end

	local function dense(values, expected, label)
		if type(values) ~= "table" or getmetatable(values) ~= nil or
				#values ~= expected then
			fail(label .. " population differs")
		end
		for index = 1, expected do
			if values[index] == nil then fail(label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > expected then
				fail(label .. " is not dense")
			end
		end
		return values
	end

	local function less_bytes(left, right)
		local count = math.min(#left, #right)
		for index = 1, count do
			local a, b = string.byte(left, index), string.byte(right, index)
			if a ~= b then return a < b end
		end
		return #left < #right
	end

	local function frame(value)
		local bytes = type(value) == "number" and string.format("%.0f", value) or value
		if type(bytes) ~= "string" then fail("hash field is not bytes or integer") end
		return tostring(#bytes) .. ":" .. bytes
	end

	local function digest(domain, full_seed, ...)
		local parts = {frame(HASH_PREFIX), frame(domain), frame(full_seed)}
		local count = select("#", ...)
		for index = 1, count do parts[#parts + 1] = frame(select(index, ...)) end
		local value = raw_sha256(table.concat(parts))
		if type(value) ~= "string" or #value ~= 32 then fail("SHA-256 seam differs") end
		return value
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	if type(catalog) ~= "table" or type(catalog.manifest) ~= "function" or
			type(catalog.p9g_sources) ~= "function" or type(p9g_content) ~= "table" or
			p9g_content.schema ~= "grug_wp40_r7_p9g_content_v1" or
			type(p9g_content.resolve_p9g) ~= "function" or
			type(p9g_content.content_ref) ~= "function" or type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	local manifest = catalog.manifest()
	local rows = catalog.p9g_sources()
	if manifest.schema ~= "grug_wp33_gathering_catalog_v1" or
			type(manifest.canonical_bytes) ~= "string" or
			type(manifest.sha256) ~= "string" or
			hex(raw_sha256(manifest.canonical_bytes)) ~= manifest.sha256 or
			type(manifest.population) ~= "table" or
			manifest.population.new_p9g_source ~= 12 or
			manifest.population.reuse_r6_source ~= 8 or
			manifest.population.r6_cultural_slot ~= 6 then
		fail("gathering manifest identity differs")
	end
	dense(rows, 12, "P9G catalog")
	dense(p9g_content.content_names, 12, "P9G content names")
	dense(p9g_content.content_cids, 12, "P9G content CIDs")

	local zone_sets, host_sets, shore_sets = {}, {}, {}
	for index = 1, #rows do
		local row = rows[index]
		if type(row) ~= "table" or row.placement_class ~= "new_p9g_source" or
			type(row.id) ~= "string" or type(row.source_node) ~= "string" or
			row.fill_numerator ~= 1 or (row.fill_denominator ~= 256 and
			row.fill_denominator ~= 384 and row.fill_denominator ~= 512 and
			row.fill_denominator ~= 768 and row.fill_denominator ~= 1024) or
			(index > 1 and not less_bytes(rows[index - 1].id, row.id)) or
			p9g_content.content_names[index] ~= row.source_node or
			p9g_content.content_ref(row.source_node) ~= index then
			fail("P9G catalog/content row differs")
		end
		local cid, kind, mode, param2, capability =
			p9g_content.resolve_p9g(index, 0)
		if cid ~= p9g_content.content_cids[index] or kind ~= 1 or mode ~= 1 or
				param2 ~= 0 or capability ~= 8 then
			fail("P9G resolver row differs")
		end
		local zones, hosts, shore = {}, {}, {}
		if type(row.zones) ~= "table" or #row.zones < 1 or
				type(row.hosts) ~= "table" or #row.hosts < 1 or
				type(row.shore_water_classes) ~= "table" then
			fail("P9G predicate arrays differ")
		end
		for item = 1, #row.zones do
			local value = row.zones[item]
			if type(value) ~= "string" or zones[value] or
					(item > 1 and not less_bytes(row.zones[item - 1], value)) then
				fail("P9G zone set differs")
			end
			zones[value] = true
		end
		for item = 1, #row.hosts do
			local value = row.hosts[item]
			if type(value) ~= "table" or type(value.biome) ~= "string" or
					type(value.support) ~= "string" or hosts[value.biome] or
					(item > 1 and not less_bytes(row.hosts[item - 1].biome,
						value.biome)) then
				fail("P9G host set differs")
			end
			hosts[value.biome] = value.support
		end
		for item = 1, #row.shore_water_classes do
			shore[row.shore_water_classes[item]] = true
		end
		if row.shore_predicate ~= "none" and
				row.shore_predicate ~= "dry_cardinal" and
				row.shore_predicate ~= "salt_cardinal" then
			fail("P9G shore predicate differs")
		end
		zone_sets[index], host_sets[index], shore_sets[index] = zones, hosts, shore
	end

	local function sift_down(values, root, finish)
		while root * 2 <= finish do
			local child = root * 2
			local function before(left, right)
				if left.digest ~= right.digest then
					return less_bytes(left.digest, right.digest)
				end
				if left.z ~= right.z then return left.z < right.z end
				return left.x < right.x
			end
			if child < finish and before(values[child], values[child + 1]) then
				child = child + 1
			end
			if not before(values[root], values[child]) then return end
			values[root], values[child] = values[child], values[root]
			root = child
		end
	end

	local function sort_prefix(values, count)
		for root = math.floor(count / 2), 1, -1 do sift_down(values, root, count) end
		for finish = count, 2, -1 do
			values[1], values[finish] = values[finish], values[1]
			sift_down(values, 1, finish - 1)
		end
	end

	local config = {schema = "grug_wp40_r7_successor_config_v1"}
	function config.new(dependencies)
		exact_fields(dependencies, {full_seed_string = true, hash = true,
			planner_source = true, horizontal = true, content = true, source = true,
			zones_session = true, construction_identity = true,
			runtime_mode = "optional"},
			"successor dependencies")
		local full_seed = dependencies.full_seed_string
		local hash = dependencies.hash
		local production = dependencies.content.content_contract()
		if dependencies.runtime_mode ~= nil and
				type(dependencies.runtime_mode) ~= "boolean" then
			fail("runtime mode differs")
		end
		local emit_ledger = not dependencies.runtime_mode
		if type(full_seed) ~= "string" or full_seed == "" or type(hash) ~= "table" or
				type(hash.budget) ~= "function" or
				type(dependencies.zones_session) ~= "table" or
				type(dependencies.zones_session.surface_mob_level_at) ~= "function" or
				type(production) ~= "table" or
				production.schema ~= "grug_wp40_r7_production_r6_content_v1" or
				#production.content_names ~= 83 then
			fail("successor production identity differs")
		end
		local air_cid, air_kind, air_param2 = production.r5.resolve(1, 0, 0)
		if air_kind ~= 0 or air_param2 ~= 0 or air_cid == production.ignore_cid then
			fail("successor air authority differs")
		end

		local rank_scratch = {}
		for index = 1, 256 do
			rank_scratch[index] = {x = 0, y = 0, z = 0, digest = false}
		end
		local candidate_scratch = {}
		for index = 1, MAX_CANDIDATES do
			candidate_scratch[index] = {catalog = 0, x = 0, y = 0, z = 0,
				cell_x = 0, cell_z = 0, digest = false}
		end
		local bound_plan, bound_generation, bound_vertical_active = false, 0, false
		local evidence_generation = 1000000000
		local metrics = {plan_calls = 0, settle_calls = 0, replay_calls = 0,
			peak_candidates = 0, peak_eligible_per_cell = 0, accepted = 0}

		local function shore_matches(context, catalog_index, x, z)
			if rows[catalog_index].shore_predicate == "none" then return true end
			local allowed = shore_sets[catalog_index]
			return allowed[context.column_values_at(x + 1, z)] == true or
				allowed[context.column_values_at(x - 1, z)] == true or
				allowed[context.column_values_at(x, z + 1)] == true or
				allowed[context.column_values_at(x, z - 1)] == true
		end

		local FACTION_BY_RACE = {dwarf = "accord", human = "accord",
			elf = "accord", orc = "throng", undead = "throng",
			troll = "throng", minotaur = "throng"}
		local LEVEL_BRACKET = {}
		for level = 1, 60 do
			local lower = math.floor((level - 1) / 10) * 10 + 1
			LEVEL_BRACKET[level] = tostring(lower) .. "-" ..
				tostring(math.min(lower + 9, 60))
		end
		local function population_values(context, catalog_index, x, z)
			local _, _, zone_id, biome, race = context.column_values_at(x, z)
			local faction = FACTION_BY_RACE[race]
			local level = dependencies.zones_session.surface_mob_level_at(x, z)
			integer(level, "P9G surface level", 1, 60)
			if type(zone_id) ~= "string" or type(biome) ~= "string" or
					not faction then
				fail("P9G population authority differs")
			end
			return rows[catalog_index].id, zone_id, biome, faction,
				LEVEL_BRACKET[level]
		end

		local function geographic_reason(context, catalog_index, x, surface_y, z)
			local water_class, _, zone_id, biome = context.column_values_at(x, z)
			if not zone_sets[catalog_index][zone_id] then return "wrong_zone" end
			local support_name = host_sets[catalog_index][biome]
			if water_class ~= "land" or not support_name then return "wrong_biome" end
			if not shore_matches(context, catalog_index, x, z) then return "wrong_shore" end
			local support_ref = context.production_content(support_name)
			if not support_ref or context.analytic_p7_ref(x, surface_y, z) ~= support_ref then
				return "wrong_support"
			end
			return nil
		end

		local function settlement_decision(context, catalog_index, x, y, z)
			local value = {original_cid = -1, original_param2 = -1,
				prior_cid = -1, prior_param2 = -1, prior_occupancy = -3,
				prior_opcode = -1, prior_feature = -1, prior_interface = -1,
				prior_aux = -1, support_mode = "not_checked", support_cid = -1,
				support_param2 = -1, support_occupancy = -3, support_opcode = -1,
				support_feature = -1, support_interface = -1, support_aux = -1}
			if not context.inside_owner(x, y, z) then return "clipped_owner", value end
			value.original_cid, value.original_param2 = context.original_at(x, y, z)
			-- Capture the complete pre-P9G tuple before applying the ordered
			-- exclusion predicates. Early rejections are still observations of
			-- the unchanged settled state and must carry an authentic prior/final
			-- pair in the operation ledger.
			value.prior_cid, value.prior_param2, value.prior_occupancy,
				value.prior_opcode, value.prior_feature, value.prior_interface,
				value.prior_aux = context.settled_at(x, y, z)
			local exclusion, exclusion_id = context.exclusion_at(x, z)
			-- The two island coast records are claim envelopes over the complete
			-- island polygon, not occupied world cells.  Their physically dry P7
			-- surface remains the ratified host for endpoint gathering sources.
			-- Earlier anchor, route and water exclusions retain priority in the
			-- source index; exact prior/support/occupancy checks remain below.
			if exclusion == "route_or_water" and DRY_ISLAND_COAST[exclusion_id] and
					context.column_values_at(x, z) == "land" then
				exclusion = nil
			end
			if exclusion == "fixed_or_protected" or exclusion == "route_or_water" then
				return exclusion, value
			elseif context.housing_excluded_at(x, z) then
				return "housing_exclusion", value
			elseif value.original_cid == production.ignore_cid then
				return "content_ignore", value
			end
			if value.prior_cid == production.ignore_cid then
				return "content_ignore", value
			end
			local reason = geographic_reason(context, catalog_index, x, y - 1, z)
			if reason then return reason, value end
			local support_name = host_sets[catalog_index][select(4,
				context.column_values_at(x, z))]
			local expected_support_cid = select(2,
				context.production_content(support_name))
			if context.inside_owner(x, y - 1, z) then
				value.support_mode = "settled_owner"
				value.support_cid, value.support_param2, value.support_occupancy,
					value.support_opcode, value.support_feature, value.support_interface,
					value.support_aux = context.settled_at(x, y - 1, z)
			else
				value.support_mode = "analytic_lower_owner"
				value.support_cid, value.support_param2, value.support_occupancy,
					value.support_opcode, value.support_feature, value.support_interface,
					value.support_aux = context.analytic_p7_tuple(x, y - 1, z)
			end
			if value.support_cid ~= expected_support_cid or
					value.support_param2 ~= 0 or value.support_opcode < 1 or
					value.support_opcode > 4 then
				return "wrong_support", value
			end
			if value.prior_cid ~= air_cid or value.prior_param2 ~= 0 then
				return "insufficient_clearance", value
			end
			if value.prior_occupancy ~= 0 or value.prior_opcode ~= 0 then
				return "r6_occupancy", value
			end
			return nil, value
		end

		local tail = {}
		function tail.plan_slice(self, minp, maxp, plan, generation)
			if not rawequal(self, tail) then fail("plan receiver differs") end
			if type(minp) ~= "table" or type(maxp) ~= "table" or
				type(plan) ~= "table" or plan.schema ~=
					"grug_wp40_r6_refinement_plan_v1" or plan.generation ~= generation or
					plan.min_x ~= minp.x or plan.min_y ~= minp.y or plan.min_z ~= minp.z or
					plan.max_x ~= maxp.x or plan.max_y ~= maxp.y or plan.max_z ~= maxp.z then
				fail("plan binding differs")
			end
			-- R6 has already materialized the 2-D surface scalar for every central
			-- column. Use it to avoid repeating the complete twelve-source scan in
			-- the hundreds of vertical owners that cannot contain a P9G root.
			local vertical_active = false
			if type(plan.column_values) ~= "table" or plan.column_count ~= 6400 then
				fail("plan column population differs")
			end
			for index = 1, plan.column_count do
				local surface_y = plan.column_values[(index - 1) * 12 + 5]
				if type(surface_y) ~= "number" or surface_y % 1 ~= 0 then
					fail("plan surface scalar differs")
				end
				local root_y = surface_y + 1
				if surface_y >= 1 and root_y >= minp.y and root_y <= maxp.y then
					vertical_active = true
					break
				end
			end
			bound_plan, bound_generation, bound_vertical_active =
				plan, generation, vertical_active
			metrics.plan_calls = metrics.plan_calls + 1
		end

		-- Private production-evidence binding. It lets the R6 analytic settlement
		-- fixture run the identical successor core once for a complete x/z owner,
		-- without fabricating a VM plan or exposing a public session method.
		function tail.plan_evidence_owner(self, min_x, max_x, min_z, max_z)
			if not rawequal(self, tail) then fail("evidence-plan receiver differs") end
			integer(min_x, "evidence min x", -30912, 30927)
			integer(max_x, "evidence max x", -30912, 30927)
			integer(min_z, "evidence min z", -30912, 30927)
			integer(max_z, "evidence max z", -30912, 30927)
			if max_x - min_x ~= 79 or max_z - min_z ~= 79 then
				fail("evidence owner bounds differ")
			end
			evidence_generation = evidence_generation + 1
			local plan = {schema = "grug_wp40_r7_evidence_plan_v1",
				generation = evidence_generation, min_x = min_x, max_x = max_x,
				min_y = -30912, max_y = 30927, min_z = min_z, max_z = max_z}
			bound_plan, bound_generation, bound_vertical_active =
				plan, evidence_generation, true
			metrics.plan_calls = metrics.plan_calls + 1
			return plan, evidence_generation
		end

		function tail.settle(self, context)
			if not rawequal(self, tail) then fail("settle receiver differs") end
			exact_fields(context, {schema = true, plan = true, generation = true,
				call_mode = true, min_x = true, min_y = true, min_z = true,
				max_x = true, max_y = true, max_z = true, inside_owner = true,
				original_at = true, settled_at = true, production_content = true,
				analytic_p7_ref = true, analytic_p7_tuple = true, exclusion_at = true,
				housing_excluded_at = true, column_values_at = true, write_p9g = true},
				"successor context")
			if context.schema ~= "grug_wp40_r7_successor_context_v1" or
				not rawequal(context.plan, bound_plan) or
				context.generation ~= bound_generation or
				(context.call_mode ~= "fixture" and context.call_mode ~= "production" and
					context.call_mode ~= "replay_fixture" and
					context.call_mode ~= "evidence_fixture") then
				fail("settlement plan binding differs")
			end
			local ledger = {schema = "grug_wp40_r7_p9g_ledger_v1", accepted = 0}
			if emit_ledger then
				ledger.groups, ledger.populations, ledger.operations = {}, {}, {}
				ledger.rejections, ledger.planned, ledger.eligible = {}, 0, 0
				ledger.manifest_sha256 = manifest.sha256
				for index = 1, #REASONS do ledger.rejections[REASONS[index]] = 0 end
			end
			local population_by_key = {}
			local function population(catalog_index, x, z)
				local source_id, zone_id, biome, faction, bracket =
					population_values(context, catalog_index, x, z)
				local key = source_id .. "\0" .. zone_id .. "\0" .. biome .. "\0" ..
					faction .. "\0" .. bracket
				local value = population_by_key[key]
				if not value then
					value = {source_id = source_id, zone_id = zone_id, biome = biome,
						faction = faction, bracket = bracket, eligible = 0, budget = 0,
						accepted = 0, rejections = {}}
					for index = 1, #REASONS do value.rejections[REASONS[index]] = 0 end
					population_by_key[key] = value
					ledger.populations[#ledger.populations + 1] = value
				end
				return value
			end
			if not bound_vertical_active then
				if context.call_mode == "replay_fixture" then
					metrics.replay_calls = metrics.replay_calls + 1
				else
					metrics.settle_calls = metrics.settle_calls + 1
				end
				return ledger
			end
			local candidate_count = 0
			local first_cell_x = math.floor(context.min_x / 16)
			local last_cell_x = math.floor(context.max_x / 16)
			local first_cell_z = math.floor(context.min_z / 16)
			local last_cell_z = math.floor(context.max_z / 16)
			for catalog_index = 1, #rows do
				local row = rows[catalog_index]
				for cell_z = first_cell_z, last_cell_z do
					for cell_x = first_cell_x, last_cell_x do
						local eligible, routed_eligible = 0, 0
						for z = cell_z * 16, cell_z * 16 + 15 do
							for x = cell_x * 16, cell_x * 16 + 15 do
								if x >= -3740 and x <= 3740 and z >= -3340 and z <= 3340 then
									local _, _, _, _, _, surface_y =
										context.column_values_at(x, z)
									if surface_y >= 1 and not geographic_reason(context,
											catalog_index, x, surface_y, z) then
										eligible = eligible + 1
										if context.inside_owner(x, surface_y + 1, z) then
											routed_eligible = routed_eligible + 1
											if emit_ledger then
												local population_row = population(catalog_index, x, z)
												population_row.eligible = population_row.eligible + 1
											end
										end
										local ranked = rank_scratch[eligible]
										ranked.x, ranked.y, ranked.z = x, surface_y + 1, z
										ranked.digest = digest("gathering_candidate_rank_v1",
											full_seed, row.id, cell_x, cell_z, x,
											surface_y + 1, z)
									end
								end
							end
						end
						if eligible > metrics.peak_eligible_per_cell then
							metrics.peak_eligible_per_cell = eligible
						end
						local remainder = digest("gathering_budget_remainder_v1", full_seed,
							row.id, cell_x, cell_z, row.fill_numerator,
							row.fill_denominator)
						local budget = hash.budget(eligible, row.fill_numerator,
							row.fill_denominator, 1, 1, remainder)
						sort_prefix(rank_scratch, eligible)
						local group
						if emit_ledger then
							group = {source_id = row.id, cell_x = cell_x,
								cell_z = cell_z, eligible = routed_eligible, budget = 0,
								accepted = 0, rejections = {}}
							for reason_index = 1, #REASONS do
								group.rejections[REASONS[reason_index]] = 0
							end
							ledger.groups[#ledger.groups + 1] = group
							ledger.eligible = ledger.eligible + routed_eligible
						end
						for chosen = 1, budget do
							local ranked = rank_scratch[chosen]
							-- The fixed 2-D budget prefix is shared by every vertical
							-- callback, but exactly the 3-D owner containing the root may
							-- account for or settle it. Skipping is not rejection/refill.
							if context.inside_owner(ranked.x, ranked.y, ranked.z) then
								candidate_count = candidate_count + 1
								if candidate_count > MAX_CANDIDATES then
									fail("candidate bound exceeded")
								end
								local candidate = candidate_scratch[candidate_count]
								candidate.catalog, candidate.x, candidate.y, candidate.z =
									catalog_index, ranked.x, ranked.y, ranked.z
								candidate.cell_x, candidate.cell_z, candidate.digest =
									cell_x, cell_z, ranked.digest
								local population_row
								if emit_ledger then
									population_row = population(catalog_index,
										candidate.x, candidate.z)
									group.budget = group.budget + 1
									ledger.planned = ledger.planned + 1
									population_row.budget = population_row.budget + 1
								end
								local reason, decision = settlement_decision(context,
									catalog_index, candidate.x, candidate.y, candidate.z)
								if reason then
									if not REASON_SET[reason] then fail("unknown rejection reason") end
									if emit_ledger then
										ledger.rejections[reason] = ledger.rejections[reason] + 1
										group.rejections[reason] = group.rejections[reason] + 1
										population_row.rejections[reason] =
											population_row.rejections[reason] + 1
									end
								else
									local cid, _, _, param2 =
										p9g_content.resolve_p9g(catalog_index, 0)
									context.write_p9g(candidate.x, candidate.y, candidate.z, cid,
										param2, catalog_index, catalog_index)
									ledger.accepted = ledger.accepted + 1
									if emit_ledger then
										group.accepted = group.accepted + 1
										population_row.accepted = population_row.accepted + 1
									end
								end
								if emit_ledger then
									local final_cid, final_param2, final_occupancy, final_opcode,
										final_feature, final_interface, final_aux = -1, -1, -3, -1,
										-1, -1, -1
									if context.inside_owner(candidate.x, candidate.y, candidate.z) then
										final_cid, final_param2, final_occupancy, final_opcode,
											final_feature, final_interface, final_aux =
												context.settled_at(candidate.x, candidate.y, candidate.z)
									end
									local _, zone_id, biome, faction, bracket =
										population_values(context, catalog_index, candidate.x, candidate.z)
									ledger.operations[#ledger.operations + 1] = {
										source_id = row.id, cell_x = candidate.cell_x,
										cell_z = candidate.cell_z, root_x = candidate.x,
										root_y = candidate.y, root_z = candidate.z,
										zone_id = zone_id, biome = biome, faction = faction,
										bracket = bracket, candidate_sha256 = hex(candidate.digest),
										original_cid = decision.original_cid,
										original_param2 = decision.original_param2,
										prior_cid = decision.prior_cid,
										prior_param2 = decision.prior_param2,
										prior_occupancy = decision.prior_occupancy,
										prior_opcode = decision.prior_opcode,
										prior_feature = decision.prior_feature,
										prior_interface = decision.prior_interface,
										prior_aux = decision.prior_aux,
										support_mode = decision.support_mode,
										support_cid = decision.support_cid,
										support_param2 = decision.support_param2,
										support_occupancy = decision.support_occupancy,
										support_opcode = decision.support_opcode,
										support_feature = decision.support_feature,
										support_interface = decision.support_interface,
										support_aux = decision.support_aux,
										final_cid = final_cid, final_param2 = final_param2,
										final_occupancy = final_occupancy, final_opcode = final_opcode,
										final_feature = final_feature,
										final_interface = final_interface, final_aux = final_aux,
										accepted = reason == nil, reason = reason or "accepted",
									}
								end
							end
						end
					end
				end
			end
			if candidate_count > metrics.peak_candidates then
				metrics.peak_candidates = candidate_count
			end
			if emit_ledger then
				table.sort(ledger.populations, function(left, right)
					local a = left.source_id .. "\0" .. left.zone_id .. "\0" .. left.biome ..
						"\0" .. left.faction .. "\0" .. left.bracket
					local b = right.source_id .. "\0" .. right.zone_id .. "\0" .. right.biome ..
						"\0" .. right.faction .. "\0" .. right.bracket
					return less_bytes(a, b)
				end)
				table.sort(ledger.operations, function(left, right)
					if left.root_z ~= right.root_z then return left.root_z < right.root_z end
					if left.root_x ~= right.root_x then return left.root_x < right.root_x end
					if left.root_y ~= right.root_y then return left.root_y < right.root_y end
					return less_bytes(left.source_id, right.source_id)
				end)
			end
			if context.call_mode == "replay_fixture" then
				metrics.replay_calls = metrics.replay_calls + 1
			else
				metrics.settle_calls = metrics.settle_calls + 1
				metrics.accepted = metrics.accepted + ledger.accepted
			end
			return ledger
		end

		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = "grug_wp40_r7_p9g_metrics_v1",
				plan_calls = metrics.plan_calls, settle_calls = metrics.settle_calls,
				replay_calls = metrics.replay_calls,
				peak_candidates = metrics.peak_candidates,
				peak_eligible_per_cell = metrics.peak_eligible_per_cell,
				accepted = metrics.accepted, retained_buffer_growth_events = 0,
				allocator_sealed = true}
		end
		function tail.probe_reason(self, context, catalog_index, x, y, z)
			if not rawequal(self, tail) then fail("probe receiver differs") end
			exact_fields(context, {inside_owner = true, original_at = true,
				settled_at = true, production_content = true, analytic_p7_ref = true,
				analytic_p7_tuple = true, exclusion_at = true,
				housing_excluded_at = true, column_values_at = true},
				"P9G probe context")
			integer(catalog_index, "P9G probe catalog", 1, 12)
			integer(x, "P9G probe x", -30912, 30927)
			integer(y, "P9G probe y", -31000, 31000)
			integer(z, "P9G probe z", -30912, 30927)
			local reason, evidence = settlement_decision(context, catalog_index, x, y, z)
			return reason or "accepted", evidence
		end
		return tail
	end
	return config
end
