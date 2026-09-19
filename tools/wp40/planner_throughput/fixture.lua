-- Bounded actual-planner KAT for the retained 20x20 wet-neighbor scratch.
return function(repo, planner_repo)
	planner_repo = planner_repo or repo
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
	local calls, mode = 0, "mixed"
	local feature_kind, feature_id, feature_water, cave_y, excluded
	local function column_values_at(x, z)
		calls = calls + 1
		local terrain_y = 8
		if mode == "mixed" then
			local selector = (x + z * 3) % 11
			if selector == 0 then
				return "planned_water", 1, "zone", "biome", "race", terrain_y,
					10, "lower", 2
			elseif selector == 1 then
				return "planned_water", 1, "zone", "biome", "race", terrain_y,
					10, "upper", 2, nil, nil, nil, nil, "waterfall", "falls",
					12, 7, nil, 1, false
			elseif selector == 2 then
				return "planned_water", 1, "zone", "biome", "race", terrain_y,
					10, "lower", 0
			elseif selector == 3 then
				return "planned_water", 1, "zone", "biome", "race", terrain_y,
					10, "lower", -2
			elseif selector == 4 then
				return "planned_water", 1, "zone", "biome", "race", terrain_y,
					10, "lower", nil
			end
		end
		return "land", 1, "zone", "biome", "race", terrain_y,
			feature_water, nil, nil, feature_kind, terrain_y, feature_id
	end
	local planner_source = {schema = "grug_wp40_r5_planner_source_v1",
		column_values_at = column_values_at,
		surface_cave_run_at = function() return cave_y, cave_y end,
		surface_cave_candidate_at_cell = function() return nil end,
		surface_cave_cell_at = function() return 0, 0 end,
		surface_cave_constants = function() return 80, -30912, 24, 2, 24 end,
		coast_profile_at = function() return nil end,
		landmark_excluded_at = function() return false end,
		metrics = function() return {runtime_column_cache_hits = 0,
			runtime_column_cache_misses = calls} end}
	local surface = {id = "biome", top = "fixture:soil", shore = "fixture:soil",
		bed = "fixture:soil", top_ref = 1, filler_ref = 1, shore_ref = 1,
		bed_ref = 1, filler_depth = 1, dust_ref = 0}
	local content = {}
	function content.surfaces() return {surface} end
	function content.new_surface_selector() return function() return surface end end
	function content.resources() return {} end
	function content.cultural() return {} end
	function content.decorations()
		return {{id = "fixture_decor", biomes = {"biome"}, rule = "surface",
			numerator = 1, denominator = 1, settlement_class = 1}}
	end
	function content.content_ref(name) assert(name == "fixture:soil"); return 1 end
	function content.decoration_cover(id, biome, ref)
		assert(id == "fixture_decor" and biome == "biome" and ref == 1)
		return 1
	end
	local function raw(bytes)
		local value = 17
		for index = 1, #bytes do value = (value * 131 + bytes:byte(index)) % 65521 end
		return string.rep(string.char(value % 256), 32)
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return string.format("%02x", string.byte(byte))
		end))
	end
	local hash = dofile(wp40 .. "r6_hash.lua")(raw)
	local planner_module = dofile(planner_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua")
	local _, fixture = planner_module.new_runtime({
		full_seed_string = "planner-throughput", planner_source = planner_source,
		r5_planner = {plan_slice = function() error("unused") end},
		horizontal = {static_exclusion_values_at = function() return excluded end},
		content = content,
		templates = {maximum_footprint = function() return 17, 1, 17 end},
		hash = hash,
		source = {zones = {{id = "zone", race_region = "race"}},
			race_regions = {"race"},
			hydrology_profiles = {{id = "wet", depth = 3}},
			hydrology = {{id = "lower", profile_id = "wet"},
				{id = "upper", profile_id = "wet"}},
			hydrology_interfaces = {{id = "falls", kind = "waterfall",
				lower_id = "lower"}}},
		construction_identity = {value = {}},
		counting_allocator = dofile(wp40 .. "counting_allocator.lua").new(
			"grug_wp40_r6_planner_allocator_v1"),
	})
	local expected_calls = planner_repo == repo and 400 or 656
	local function build(cell_x, cell_z, expected, expected_columns)
		local before = calls
		local cultural, decorations, groups, coverage, columns =
			fixture.build_cell(cell_x, cell_z)
		assert(calls - before == expected, "planner source query count differs")
		assert(#groups == 1 and groups[1].kind == 2 and groups[1].catalog == 1 and
			groups[1].eligible >= 0 and groups[1].eligible <= 256)
		assert(#coverage == 1 and coverage[1].zone_id == "zone" and
			coverage[1].biome == "biome" and coverage[1].count == expected_columns)
		assert(columns == expected_columns)
		assert(#cultural == 0)
		local candidate_rows = {}
		for index = 1, #decorations do
			local row = decorations[index]
			candidate_rows[index] = table.concat({row.catalog, row.class, row.x,
				row.y, row.z, row.digest}, "/")
		end
		return groups[1].eligible, groups[1].budget, #decorations,
			hex(raw(table.concat(candidate_rows, "\n")))
	end
	local mixed, mixed_budget, mixed_candidates, mixed_digest =
		build(0, 0, expected_calls, 256)
	mode = "dry"
	local dry, dry_budget, dry_candidates, dry_digest =
		build(0, 0, expected_calls, 256)
	assert(mixed < dry and dry == 256,
		"wet-neighbor scratch did not affect or clear eligibility")
	local edge_expected = planner_repo == repo and 400 or 544
	local edge, edge_budget, edge_candidates, edge_digest =
		build(-234, -209, edge_expected, 144)
	assert(edge == 144 and edge_budget == 144 and edge_candidates == 144,
		"map-edge central population differs")
	mode = "mixed"
	local repeated, repeat_budget, repeat_candidates, repeat_digest =
		build(0, 0, expected_calls, 256)
	assert(repeated == mixed and repeat_budget == mixed_budget and
		repeat_candidates == mixed_candidates and repeat_digest == mixed_digest,
		"wet-neighbor scratch reuse differs")
	-- Compact final-parity witnesses for dry-anchor grade eligibility. They use
	-- the actual planner with scalar fixtures, never a seed/world population.
	--
	-- ANCHORS 1..12, not 1..6, since WP13 round 3: the six CAPITALS keep their
	-- own biome surface for the same reason the six starts do, because a
	-- capital fitting grades its whole 704-node blend square and everything
	-- inside it was `default:stone` before. Anchor 13 and up are ordinary POIs
	-- and are still refused, and so is `anchor_0010`, which is not an anchor id
	-- at all -- it is the four-digit typo the predicate has to keep rejecting.
	if planner_repo == repo then
		mode, feature_kind = "dry", "land_grade"
		for index = 1, 12 do
			feature_id = string.format("anchor_%03d", index)
			assert(select(12, fixture.column_values_at(0, 0)) == true,
				"dry start or capital grade must support its biome surface")
		end
		for _, id in ipairs({"anchor_013", "anchor_099", "anchor_0010",
				"road_001", "poi_001"}) do
			feature_id = id
			assert(select(12, fixture.column_values_at(0, 0)) == false,
				"other grade cannot acquire anchor surface semantics")
		end
		feature_id, excluded = "anchor_001", "fixture_exclusion"
		assert(select(12, fixture.column_values_at(0, 0)) == false,
			"protected starts must not generate rejected decoration candidates")
		feature_kind = nil
		assert(select(12, fixture.column_values_at(0, 0)) == true,
			"ordinary candidate populations must remain unchanged")
		excluded = nil
		for _, kind in ipairs({"anchor_platform", "causeway", "ford"}) do
			feature_kind = kind
			assert(select(12, fixture.column_values_at(0, 0)) == false)
		end
		feature_kind, feature_water = "land_grade", 10
		assert(select(12, fixture.column_values_at(0, 0)) == false,
			"wet start cannot acquire dry surface semantics")
		feature_water, cave_y = nil, 8
		assert(select(12, fixture.column_values_at(0, 0)) == false,
			"start surface cannot close a cave mouth")
	end
	return table.concat({"schema\tgrug_wp40_planner_throughput_fixture_v1",
		"mixed_eligible\t" .. mixed, "dry_eligible\t" .. dry,
		"mixed_budget_candidates\t" .. mixed_budget .. "/" .. mixed_candidates,
		"dry_budget_candidates\t" .. dry_budget .. "/" .. dry_candidates,
		"edge_budget_candidates\t" .. edge_budget .. "/" .. edge_candidates,
		"mixed_candidates_digest\t" .. mixed_digest,
		"dry_candidates_digest\t" .. dry_digest,
		"edge_candidates_digest\t" .. edge_digest,
		"repeat_eligible\t" .. repeated,
		"queries_per_cell\t" .. expected_calls, ""}, "\n")
end
