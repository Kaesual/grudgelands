-- Disabled WP40 R6 refinement planner. R7 owns callback activation.

local function planner_factory()
	local MAX_SAFE = 9007199254740991
	local MAX_AXIS = 80
	local MAX_COLUMNS = 6400
	local MAX_CELLS = 100
	local MAX_CANDIDATES = 65536
	local COLUMN_STRIDE = 12
	local CELL_STRIDE = 4
	local CANDIDATE_STRIDE = 14
	local WATER_SENTINEL = -31007
	local WATER_CLASS_ID = {
		land = 1, planned_water = 2, coastal_shelf = 3, deep_ocean = 4,
		immutable_dragon_channel = 5,
	}

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail("fail_bound", label .. " is not an exact bounded integer")
		end
		return value
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail("fail_source", label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then
				fail("fail_source", label .. " has unexpected field " .. tostring(key))
			end
		end
		for key in pairs(allowed) do
			if value[key] == nil then fail("fail_source", label .. " is missing " .. key) end
		end
		return value
	end

	local function position(value, label)
		exact_fields(value, {x = true, y = true, z = true}, label)
		return integer(value.x, label .. " x", -30912, 30927),
			integer(value.y, label .. " y", -30912, 30927),
			integer(value.z, label .. " z", -30912, 30927)
	end

	local function floor_div(value, divisor)
		return math.floor(value / divisor)
	end

	local function copy_array(values)
		local result = {}
		for index = 1, #values do result[index] = values[index] end
		return result
	end

	local function new(dependencies, evidence_only)
		if evidence_only ~= nil and evidence_only ~= true then
			fail("fail_source", "evidence-only construction flag differs")
		end
		exact_fields(dependencies, {
			full_seed_string = true, planner_source = true, r5_planner = true,
			horizontal = true, content = true, templates = true, hash = true,
			source = true, construction_identity = true, counting_allocator = true,
		}, "planner dependencies")
		local full_seed = dependencies.full_seed_string
		if type(full_seed) ~= "string" or full_seed == "" then
			fail("fail_source", "full seed differs")
		end
		local planner_source = dependencies.planner_source
		local r5_planner = dependencies.r5_planner
		local horizontal = dependencies.horizontal
		local content = dependencies.content
		local templates = dependencies.templates
		local hash = dependencies.hash
		local source = dependencies.source
		local identity_holder = dependencies.construction_identity
		local allocator = dependencies.counting_allocator
		if type(planner_source) ~= "table" or
				planner_source.schema ~= "grug_wp40_r5_planner_source_v1" or
				type(planner_source.column_values_at) ~= "function" or
				type(r5_planner) ~= "table" or type(r5_planner.plan_slice) ~= "function" or
				type(horizontal) ~= "table" or
				type(horizontal.static_exclusion_values_at) ~= "function" or
				type(content) ~= "table" or type(templates) ~= "table" or
			type(hash) ~= "table" or type(source) ~= "table" or
			type(identity_holder) ~= "table" or identity_holder.value == nil then
			fail("fail_source", "planner construction seam differs")
		end
		exact_fields(allocator, {new_array = true, new_map = true, grow = true,
			map_put = true, seal_construction = true, enter_hotpath = true,
			leave_hotpath = true, metrics = true}, "planner counting allocator")
		for name, method in pairs(allocator) do
			if type(method) ~= "function" then
				fail("fail_source", "planner allocator method differs: " .. name)
			end
		end
		local function retained_array(label, size, value)
			local values = allocator:new_array(label, size)
			allocator:grow(values, label, 0, size)
			if value ~= 0 then
				for index = 1, size do values[index] = value end
			end
			return values
		end

		local surfaces = content.surfaces()
		local resources = content.resources()
		local cultural = content.cultural()
		local decorations = content.decorations()
		local surface_by_id, biome_ref, race_ref, stable_ref = {}, {}, {}, {}
		local stable_refs = {}
		local function add_ref(value)
			if type(value) == "string" and value ~= "" and not stable_ref[value] then
				stable_ref[value] = true
				stable_refs[#stable_refs + 1] = value
			end
		end
		for index = 1, #surfaces do
			surface_by_id[surfaces[index].id] = surfaces[index]
			add_ref(surfaces[index].id)
		end
		for index = 1, #resources do add_ref(resources[index].key) end
		for index = 1, #cultural do add_ref(cultural[index].key) end
		for index = 1, #decorations do add_ref(decorations[index].id) end
		for index = 1, #(source.zones or {}) do
			local zone = source.zones[index]
			add_ref(zone.id)
			add_ref(zone.race_region)
		end
		table.sort(stable_refs, hash.less_bytes)
		for index = 1, #stable_refs do stable_ref[stable_refs[index]] = index end
		for id in pairs(surface_by_id) do biome_ref[id] = stable_ref[id] end
		for index = 1, #(source.race_regions or {}) do
			local row = source.race_regions[index]
			local id = type(row) == "table" and row.id or row
			if id then race_ref[id] = stable_ref[id] end
		end
		for index = 1, #(source.zones or {}) do
			local race = source.zones[index].race_region
			if race then race_ref[race] = stable_ref[race] end
		end

		local cultural_biome = {}
		for index = 1, #cultural do
			local set = {}
			for b = 1, #cultural[index].biomes do set[cultural[index].biomes[b]] = true end
			cultural_biome[index] = set
		end
		local decoration_biome = {}
		for index = 1, #decorations do
			local set = {}
			for b = 1, #decorations[index].biomes do set[decorations[index].biomes[b]] = true end
			decoration_biome[index] = set
		end
		local profile_depth, hydrology_depth, lower_hydrology = {}, {}, {}
		for index = 1, #(source.hydrology_profiles or {}) do
			local row = source.hydrology_profiles[index]
			profile_depth[row.id] = row.depth
		end
		for index = 1, #(source.hydrology or {}) do
			local row = source.hydrology[index]
			hydrology_depth[row.id] = profile_depth[row.profile_id]
		end
		for index = 1, #(source.hydrology_interfaces or {}) do
			local row = source.hydrology_interfaces[index]
			if row.kind == "waterfall" then lower_hydrology[row.id] = row.lower_id end
		end
		local max_footprint_x, _, max_footprint_z = templates.maximum_footprint()
		local halo_x = math.ceil(math.max(0, max_footprint_x - 1) / 16)
		local halo_z = math.ceil(math.max(0, max_footprint_z - 1) / 16)
		if halo_x > 2 or halo_z > 2 then fail("fail_bound", "candidate halo differs") end

		local candidate_capacity = evidence_only and 16384 or MAX_CANDIDATES
		local column_values = retained_array("r6_planner_column_values",
			evidence_only and 1 or MAX_COLUMNS * COLUMN_STRIDE, false)
		local candidate_cell_values = retained_array("r6_planner_candidate_cells",
			evidence_only and 1 or MAX_CELLS * CELL_STRIDE, false)
		local candidate_values = retained_array("r6_planner_candidates",
			evidence_only and 1 or MAX_CANDIDATES * CANDIDATE_STRIDE, false)
		local scratch = {
			x = retained_array("r6_planner_scratch_x", 256, false),
			z = retained_array("r6_planner_scratch_z", 256, false),
			water_class = retained_array("r6_planner_scratch_water_class", 256, false),
			zone_numeric = retained_array("r6_planner_scratch_zone_numeric", 256, false),
			zone_id = retained_array("r6_planner_scratch_zone_id", 256, false),
			biome = retained_array("r6_planner_scratch_biome", 256, false),
			race = retained_array("r6_planner_scratch_race", 256, false),
			terrain_y = retained_array("r6_planner_scratch_terrain_y", 256, false),
			water_y = retained_array("r6_planner_scratch_water_y", 256, false),
			excluded = retained_array("r6_planner_scratch_excluded", 256, false),
			surface_kind = retained_array("r6_planner_scratch_surface_kind", 256, false),
			support_name = retained_array("r6_planner_scratch_support_name", 256, false),
			p7_support = retained_array("r6_planner_scratch_p7_support", 256, false),
			wet_bed = retained_array("r6_planner_scratch_wet_bed", 400, false),
			wet_surface = retained_array("r6_planner_scratch_wet_surface", 400, false),
		}
		local rank_scratch = {}
		for index = 1, 256 do
			rank_scratch[index] = {digest = false, x = 0, y = 0, z = 0}
		end
		local cultural_candidates, decoration_candidates = {}, {}
		local group_scratch = {}
		for index = 1, #cultural * 2 + #decorations do
			group_scratch[index] = {kind = 0, catalog = 0, parameter = 0,
				eligible = 0, budget = 0, candidates = 0}
		end
		local coverage_scratch = {}
		for index = 1, 64 do
			coverage_scratch[index] = {zone_id = false, biome = false, count = 0}
		end
		for index = 1, candidate_capacity do
			cultural_candidates[index] = {catalog = 0, parameter = 0, x = 0, y = 0,
				z = 0, digest = false}
			decoration_candidates[index] = {catalog = 0, parameter = 0, x = 0, y = 0,
				z = 0, digest = false}
		end

		local plan = {
			schema = "grug_wp40_r6_refinement_plan_v1",
			construction_identity = false,
			generation = 0, valid = false,
			min_x = 0, min_y = 0, min_z = 0, max_x = 0, max_y = 0, max_z = 0,
			r5_plan = false, r5_generation = 0,
			column_values = column_values, column_count = 0,
			candidate_cell_values = candidate_cell_values, candidate_cell_count = 0,
			candidate_values = candidate_values, candidate_count = 0,
			-- The public plan never aliases the planner's private interning array.
			stable_refs = copy_array(stable_refs),
		}
		local metrics = {
			plan_buffer_reuse_calls = 0,
			peak_candidate_cells = 0, peak_candidates = 0,
			peak_column_value_cells = 0, peak_candidate_value_cells = 0,
		}

		local function column_tuple(x, z)
			local water_class, zone_numeric, zone_id, biome, race, terrain_y,
				water_y, classified_hydrology_id, _, functional_kind, functional_y,
				_, _, transition_kind, _, _, _, _, transition_face_mask =
					planner_source.column_values_at(x, z)
			if not WATER_CLASS_ID[water_class] or
					((zone_numeric == nil) ~= (zone_id == nil)) or
					((biome == nil) ~= (zone_id == nil)) or
					(biome ~= nil and not surface_by_id[biome]) then
				fail("fail_source", "R6 column vocabulary differs")
			end
			local wet = water_y ~= nil and water_y > terrain_y
			local surface_kind = wet and 3 or (biome == "grug_beach" and 2 or 1)
			local surface = surface_by_id[biome]
			local support_name = surface and (surface_kind == 1 and surface.top or
				(surface_kind == 2 and surface.shore or surface.bed)) or false
			-- These are the P2-P4 surface winners exposed as exact R5 planner-source
			-- scalars. Dry bank seals are neighborhood-derived inside the R5 planner
			-- and have no equivalent read-only source scalar, so settlement must still
			-- verify the final predecessor.
			local p7_support = surface ~= nil
			if functional_kind == "anchor_platform" or
					functional_kind == "land_grade" or functional_kind == "ford" or
					functional_kind == "causeway" then
				p7_support = false
			elseif functional_kind == "tunnel_floor" and
					functional_y <= terrain_y and terrain_y <= functional_y + 5 then
				p7_support = false
			end
			if (classified_hydrology_id ~= nil and water_y ~= nil and
					transition_kind ~= "waterfall") or
					(transition_kind == "waterfall" and transition_face_mask ~= nil) then
				p7_support = false
			end
			return water_class, zone_numeric, zone_id, biome, race, terrain_y,
				water_y, surface_kind, surface, support_name,
				horizontal.static_exclusion_values_at(x, z) ~= nil, p7_support
		end

		local function load_cell(cell_x, cell_z)
			local count = 0
			local start_x, start_z = cell_x * 16, cell_z * 16
			for z = start_z, start_z + 15 do
				for x = start_x, start_x + 15 do
					if x >= -3740 and x <= 3740 and z >= -3340 and z <= 3340 then
						count = count + 1
						local water_class, zone_numeric, zone_id, biome, race, terrain_y,
							water_y, surface_kind, _, support_name, excluded, p7_support =
								column_tuple(x, z)
						scratch.x[count], scratch.z[count] = x, z
						scratch.water_class[count] = water_class
						scratch.zone_numeric[count], scratch.zone_id[count] = zone_numeric or false,
							zone_id or false
						scratch.biome[count], scratch.race[count] = biome or false, race or false
						scratch.terrain_y[count], scratch.water_y[count] = terrain_y, water_y or false
						scratch.excluded[count], scratch.surface_kind[count] = excluded, surface_kind
						scratch.support_name[count], scratch.p7_support[count] = support_name,
							p7_support
					end
				end
			end
			-- R5's dry-bank seal is the only surface winner derived from neighbor
			-- columns.  Reproduce that exact yes/no decision once on a retained
			-- 20-by-20 halo, instead of re-querying twelve neighbors per column.
			for local_z = 0, 19 do
				for local_x = 0, 19 do
					local halo_index = local_z * 20 + local_x + 1
					local x, z = start_x + local_x - 2, start_z + local_z - 2
					scratch.wet_bed[halo_index], scratch.wet_surface[halo_index] =
						false, false
					local _, _, _, _, _, _, water_y, classified_id,
						classified_depth, _, _, _, _, transition_kind,
						transition_id, _, transition_lower_y, _, transition_face_mask =
							planner_source.column_values_at(x, z)
					local wet_surface, depth
					if transition_kind == "waterfall" and transition_face_mask ~= nil then
						wet_surface = transition_lower_y
						depth = hydrology_depth[lower_hydrology[transition_id]]
					elseif water_y ~= nil and classified_id ~= nil and
							transition_kind ~= "waterfall" then
						wet_surface, depth = water_y, classified_depth
					end
					if wet_surface and depth and depth > 0 then
						scratch.wet_surface[halo_index] = wet_surface
						scratch.wet_bed[halo_index] = wet_surface - depth
					end
				end
			end
			for column = 1, count do
				if scratch.p7_support[column] and not scratch.excluded[column] and
						scratch.surface_kind[column] ~= 3 then
					local local_x = scratch.x[column] - start_x + 2
					local local_z = scratch.z[column] - start_z + 2
					local minimum_seal_y, maximum_water_y
					for dx = -2, 2 do
						for dz = -2, 2 do
							local distance = math.abs(dx) + math.abs(dz)
							if distance >= 1 and distance <= 2 then
								local halo_index = (local_z + dz) * 20 +
									(local_x + dx) + 1
								local bed = scratch.wet_bed[halo_index]
								if bed then
									local seal_y = bed - 2
									minimum_seal_y = minimum_seal_y and
										math.min(minimum_seal_y, seal_y) or seal_y
									local water = scratch.wet_surface[halo_index]
									maximum_water_y = maximum_water_y and
										math.max(maximum_water_y, water) or water
								end
							end
						end
					end
					local terrain_y = scratch.terrain_y[column]
					if minimum_seal_y and minimum_seal_y <= terrain_y and
							terrain_y <= maximum_water_y then
						scratch.p7_support[column] = false
					end
				end
			end
			return count
		end

		local function rank_less(left, right)
			if left.digest ~= right.digest then return hash.less_bytes(left.digest, right.digest) end
			if left.z ~= right.z then return left.z < right.z end
			return left.x < right.x
		end

		local function sift_down(values, root, finish, less)
			while root * 2 <= finish do
				local child = root * 2
				if child < finish and less(values[child], values[child + 1]) then
					child = child + 1
				end
				if not less(values[root], values[child]) then return end
				values[root], values[child] = values[child], values[root]
				root = child
			end
		end

		local function sort_prefix(values, count, less)
			for root = math.floor(count / 2), 1, -1 do
				sift_down(values, root, count, less)
			end
			for finish = count, 2, -1 do
				values[1], values[finish] = values[finish], values[1]
				sift_down(values, 1, finish - 1, less)
			end
		end

		local function append_candidate(buffer, count, catalog, parameter, x, y, z,
				digest)
			count = count + 1
			if count > candidate_capacity then fail("fail_bound", "candidate bound exceeded") end
			local record = buffer[count]
			record.catalog, record.parameter, record.x, record.y, record.z =
				catalog, parameter, x, y, z
			record.digest = digest
			return count
		end

		local function build_cell(cell_x, cell_z, capture_groups)
			local column_count = load_cell(cell_x, cell_z)
			local cultural_count, decoration_count = 0, 0
			local group_count = 0
			local coverage_count = 0
			if capture_groups then
				for column = 1, column_count do
					if scratch.zone_id[column] and scratch.biome[column] then
						local found
						for index = 1, coverage_count do
							local row = coverage_scratch[index]
							if row.zone_id == scratch.zone_id[column] and
									row.biome == scratch.biome[column] then found = row break end
						end
						if not found then
							coverage_count = coverage_count + 1
							if coverage_count > #coverage_scratch then
								fail("fail_bound", "cell surface coverage bound exceeded")
							end
							found = coverage_scratch[coverage_count]
							found.zone_id, found.biome, found.count = scratch.zone_id[column],
								scratch.biome[column], 0
						end
						found.count = found.count + 1
					end
				end
			end
			for catalog = 1, #cultural do
				local row = cultural[catalog]
				for _, denominator in ipairs({1024, 4096}) do
					local eligible = 0
					for column = 1, column_count do
						local concentrated = scratch.zone_id[column] == row.concentrated_zone
						if (denominator == 1024) == concentrated and
								scratch.race[column] == row.race and
								cultural_biome[catalog][scratch.biome[column]] and
								scratch.surface_kind[column] ~= 3 and
								scratch.p7_support[column] and
								scratch.terrain_y[column] >= 1 and not scratch.excluded[column] then
							eligible = eligible + 1
							local ranked = rank_scratch[eligible]
							ranked.x, ranked.y, ranked.z = scratch.x[column],
								scratch.terrain_y[column], scratch.z[column]
							ranked.digest = hash.digest("cultural_candidate_rank_v1", full_seed,
								{row.key, cell_x, cell_z, denominator, ranked.x, ranked.z})
						end
					end
					local budget = 0
					if eligible > 0 then
						local remainder_digest = hash.digest("cultural_budget_remainder_v1",
							full_seed, {row.key, cell_x, cell_z, denominator})
						budget = hash.budget(eligible, 1, denominator, 1, 1,
							remainder_digest)
						sort_prefix(rank_scratch, eligible, rank_less)
						for chosen = 1, budget do
							local ranked = rank_scratch[chosen]
							cultural_count = append_candidate(cultural_candidates,
								cultural_count, catalog, denominator, ranked.x, ranked.y,
								ranked.z, ranked.digest)
						end
					end
					if capture_groups then
						group_count = group_count + 1
						local group = group_scratch[group_count]
						group.kind, group.catalog, group.parameter = 1, catalog, denominator
						group.eligible, group.budget, group.candidates = eligible, budget, budget
					end
				end
			end
			for catalog = 1, #decorations do
				local row = decorations[catalog]
				local eligible = 0
				for column = 1, column_count do
					local terrain_y = scratch.terrain_y[column]
					local special_ok = true
					if row.rule:find("surface_y_at_least_60", 1, true) then
						special_ok = terrain_y >= 60
					elseif row.rule:find("surface_y_at_most_32", 1, true) then
						special_ok = terrain_y <= 32
					elseif row.rule:find("surface_y_1_to_4", 1, true) then
						special_ok = terrain_y >= 1 and terrain_y <= 4
					end
					if terrain_y >= 1 and special_ok and
							decoration_biome[catalog][scratch.biome[column]] and
							scratch.p7_support[column] and
							scratch.support_name[column] == row.host then
						eligible = eligible + 1
						local ranked = rank_scratch[eligible]
						ranked.x, ranked.y, ranked.z = scratch.x[column], terrain_y + 1,
							scratch.z[column]
						ranked.digest = hash.digest("decoration_candidate_rank_v1", full_seed,
							{row.id, cell_x, cell_z, ranked.x, ranked.z})
					end
				end
				local budget = 0
				if eligible > 0 then
					local remainder_digest = hash.digest("decoration_budget_remainder_v1",
						full_seed, {row.id, cell_x, cell_z})
					budget = hash.budget(eligible, row.numerator, row.denominator,
						1, 1, remainder_digest)
					sort_prefix(rank_scratch, eligible, rank_less)
					for chosen = 1, budget do
						local ranked = rank_scratch[chosen]
						decoration_count = append_candidate(decoration_candidates,
							decoration_count, catalog, row.settlement_class, ranked.x,
							ranked.y, ranked.z, ranked.digest)
					end
				end
				if capture_groups then
					group_count = group_count + 1
					local group = group_scratch[group_count]
					group.kind, group.catalog, group.parameter = 2, catalog,
						row.settlement_class
					group.eligible, group.budget, group.candidates = eligible, budget, budget
				end
			end
			sort_prefix(cultural_candidates, cultural_count, function(left, right)
				if left.digest ~= right.digest then return hash.less_bytes(left.digest, right.digest) end
				if left.z ~= right.z then return left.z < right.z end
				if left.x ~= right.x then return left.x < right.x end
				return hash.less_bytes(cultural[left.catalog].key,
					cultural[right.catalog].key)
			end)
			sort_prefix(decoration_candidates, decoration_count, function(left, right)
				if left.parameter ~= right.parameter then return left.parameter < right.parameter end
				if left.digest ~= right.digest then return hash.less_bytes(left.digest, right.digest) end
				if left.z ~= right.z then return left.z < right.z end
				if left.x ~= right.x then return left.x < right.x end
				return hash.less_bytes(decorations[left.catalog].id,
					decorations[right.catalog].id)
			end)
			return cultural_count, decoration_count, group_count, coverage_count,
				column_count
		end

		local function write_candidate(kind, record, output_index)
			if output_index > MAX_CANDIDATES then
				fail("fail_bound", "combined candidate bound exceeded")
			end
			local base = (output_index - 1) * CANDIDATE_STRIDE
			candidate_values[base + 1] = kind
			candidate_values[base + 2] = record.catalog
			candidate_values[base + 3] = record.parameter
			candidate_values[base + 4] = record.x
			candidate_values[base + 5] = record.y
			candidate_values[base + 6] = record.z
			local words = hash.words(record.digest)
			for word = 1, 8 do candidate_values[base + 6 + word] = words[word] end
		end

		local function plan_slice_core(min_x, min_y, min_z, max_x, max_y, max_z)
			plan.valid = false
			local r5_plan, r5_generation = r5_planner:plan_slice(
				{x = min_x, y = min_y, z = min_z}, {x = max_x, y = max_y, z = max_z})
			plan.generation = plan.generation + 1
			plan.min_x, plan.min_y, plan.min_z = min_x, min_y, min_z
			plan.max_x, plan.max_y, plan.max_z = max_x, max_y, max_z
			plan.r5_plan, plan.r5_generation = r5_plan, r5_generation
			if identity_holder.value == false then
				identity_holder.value = r5_plan.construction_identity
			elseif not rawequal(identity_holder.value, r5_plan.construction_identity) then
				fail("fail_source", "nested plan identity differs")
			end
			plan.construction_identity = identity_holder.value
			local column_count = 0
			for z = min_z, max_z do
				for x = min_x, max_x do
					column_count = column_count + 1
					local water_class, zone_numeric, _, biome, race, terrain_y, water_y,
						surface_kind, surface = column_tuple(x, z)
					local base = (column_count - 1) * COLUMN_STRIDE
					column_values[base + 1] = WATER_CLASS_ID[water_class]
					column_values[base + 2] = zone_numeric or 0
					column_values[base + 3] = biome and biome_ref[biome] or 0
					column_values[base + 4] = race and race_ref[race] or 0
					column_values[base + 5] = terrain_y
					column_values[base + 6] = water_y or WATER_SENTINEL
					column_values[base + 7] = surface_kind
					column_values[base + 8] = surface and surface.top_ref or 0
					column_values[base + 9] = surface and surface.filler_ref or 0
					column_values[base + 10] = surface and
						(surface_kind == 2 and surface.shore_ref or
							(surface_kind == 3 and surface.bed_ref or 0)) or 0
					column_values[base + 11] = surface and surface.filler_depth or 0
					column_values[base + 12] = surface and surface.dust_ref or 0
				end
			end
			local first_cell_x = floor_div(min_x, 16) - halo_x
			local last_cell_x = floor_div(max_x, 16) + halo_x
			local first_cell_z = floor_div(min_z, 16) - halo_z
			local last_cell_z = floor_div(max_z, 16) + halo_z
			local cell_count, candidate_count = 0, 0
			for cell_z = first_cell_z, last_cell_z do
				for cell_x = first_cell_x, last_cell_x do
					cell_count = cell_count + 1
					if cell_count > MAX_CELLS then fail("fail_bound", "candidate cell bound exceeded") end
					local cell_base = (cell_count - 1) * CELL_STRIDE
					candidate_cell_values[cell_base + 1] = cell_x
					candidate_cell_values[cell_base + 2] = cell_z
					candidate_cell_values[cell_base + 3] = candidate_count + 1
					local cc, dc = build_cell(cell_x, cell_z, false)
					for index = 1, cc do
						candidate_count = candidate_count + 1
						write_candidate(1, cultural_candidates[index], candidate_count)
					end
					for index = 1, dc do
						candidate_count = candidate_count + 1
						write_candidate(2, decoration_candidates[index], candidate_count)
					end
					candidate_cell_values[cell_base + 4] = candidate_count + 1
				end
			end
			plan.column_count, plan.candidate_cell_count, plan.candidate_count =
				column_count, cell_count, candidate_count
			metrics.plan_buffer_reuse_calls = metrics.plan_buffer_reuse_calls + 1
			if cell_count > metrics.peak_candidate_cells then metrics.peak_candidate_cells = cell_count end
			if candidate_count > metrics.peak_candidates then metrics.peak_candidates = candidate_count end
			metrics.peak_column_value_cells = math.max(metrics.peak_column_value_cells,
				column_count * COLUMN_STRIDE)
			metrics.peak_candidate_value_cells = math.max(metrics.peak_candidate_value_cells,
				candidate_count * CANDIDATE_STRIDE)
			plan.valid = true
			return plan, plan.generation
		end

		local planner = {}
		function planner.plan_slice(self, minp, maxp)
			if not rawequal(self, planner) then fail("fail_source", "planner receiver differs") end
			if evidence_only then fail("fail_status", "evidence fixture has no plan writer") end
			local min_x, min_y, min_z = position(minp, "minp")
			local max_x, max_y, max_z = position(maxp, "maxp")
			local x_count, y_count, z_count = max_x - min_x + 1,
				max_y - min_y + 1, max_z - min_z + 1
			if x_count < 1 or x_count > MAX_AXIS or y_count < 1 or y_count > MAX_AXIS or
					z_count < 1 or z_count > MAX_AXIS or x_count * z_count > MAX_COLUMNS then
				fail("fail_bound", "slice bounds differ")
			end
			allocator:enter_hotpath("r6_plan_slice")
			local ok, result, generation = pcall(plan_slice_core, min_x, min_y, min_z,
				max_x, max_y, max_z)
			allocator:leave_hotpath("r6_plan_slice")
			if not ok then error(result, 0) end
			return result, generation
		end
		function planner.metrics(self)
			if not rawequal(self, planner) then fail("fail_source", "planner receiver differs") end
			local allocation = allocator:metrics()
			return {
				retained_buffer_growth_events = allocation.hotpath_table_allocations,
				allocator_sealed = allocation.construction_sealed,
				plan_buffer_reuse_calls = metrics.plan_buffer_reuse_calls,
				peak_candidate_cells = metrics.peak_candidate_cells,
				peak_candidates = metrics.peak_candidates,
				peak_column_value_cells = metrics.peak_column_value_cells,
				peak_candidate_value_cells = metrics.peak_candidate_value_cells,
				candidate_halo_x_cells = halo_x, candidate_halo_z_cells = halo_z,
			}
		end

		local fixture = {}
		function fixture.column_values_at(x, z)
			integer(x, "fixture x", -30912, 30927)
			integer(z, "fixture z", -30912, 30927)
			return column_tuple(x, z)
		end
		function fixture.build_cell(cell_x, cell_z)
			integer(cell_x, "fixture cell x", -1932, 1932)
			integer(cell_z, "fixture cell z", -1932, 1932)
			local cc, dc, group_count, coverage_count, column_count =
				build_cell(cell_x, cell_z, true)
			local ccopy, dcopy = {}, {}
			for index = 1, cc do
				local row = cultural_candidates[index]
				ccopy[index] = {catalog = row.catalog, denominator = row.parameter,
					x = row.x, y = row.y, z = row.z, digest = hash.hex(row.digest)}
			end
			for index = 1, dc do
				local row = decoration_candidates[index]
				dcopy[index] = {catalog = row.catalog, class = row.parameter,
					x = row.x, y = row.y, z = row.z, digest = hash.hex(row.digest)}
			end
			local groups = {}
			for index = 1, group_count do
				local row = group_scratch[index]
				groups[index] = {kind = row.kind, catalog = row.catalog,
					parameter = row.parameter, eligible = row.eligible,
					budget = row.budget, candidates = row.candidates}
			end
			local coverage = {}
			for index = 1, coverage_count do
				local row = coverage_scratch[index]
				coverage[index] = {zone_id = row.zone_id, biome = row.biome,
					count = row.count}
			end
			return ccopy, dcopy, groups, coverage, column_count
		end
		function fixture.stable_refs() return copy_array(stable_refs) end
		allocator:seal_construction()
		return planner, fixture
	end

	return {new = function(dependencies) return new(dependencies, nil) end,
		new_evidence = function(dependencies) return new(dependencies, true) end}
end

return planner_factory()
