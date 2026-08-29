-- Pure, disabled WP40 named-zone and policy payload. Publication remains R7.

return function(dependencies)
	if type(dependencies) ~= "table" then
		error("WP40 R4 dependencies missing", 0)
	end
	local allowed_dependencies = {
		source = true,
		schemas = true,
		canonical = true,
		deterministic = true,
		index128 = true,
		horizontal_factory = true,
		height_factory = true,
		raw_sha256 = true,
	}
	for key in pairs(dependencies) do
		if not allowed_dependencies[key] then
			error("WP40 R4 unexpected dependency " .. tostring(key), 0)
		end
	end
	for key in pairs(allowed_dependencies) do
		if dependencies[key] == nil then
			error("WP40 R4 dependency missing: " .. key, 0)
		end
	end

	local source = dependencies.source
	local schemas = dependencies.schemas
	local canonical = dependencies.canonical
	local deterministic = dependencies.deterministic
	local index128 = dependencies.index128
	local horizontal_factory = dependencies.horizontal_factory
	local height_factory = dependencies.height_factory
	local injected_raw_sha256 = dependencies.raw_sha256
	local MAX_SAFE = 9007199254740991
	local WATER_LEVEL = 1
	local MIN_X, MAX_X = -3740, 3740
	local MIN_Z, MAX_Z = -3340, 3340
	local ZONES_SCHEMA = "grug_wp40_zones_v1"
	local SPARSE_SCHEMA = "grug_wp40_sparse_feature_index_v1"
	local WATER_CLASSES = {
		land = true,
		planned_water = true,
		coastal_shelf = true,
		deep_ocean = true,
		immutable_dragon_channel = true,
	}
	local OWNER_CLASSES = {
		land = true,
		planned_water = true,
		coastal_shelf = true,
	}
	local FUNCTIONAL_KINDS = {
		anchor_platform = true,
		bridge_deck = true,
		causeway = true,
		ford = true,
		land_grade = true,
		tunnel_floor = true,
	}

	local function fail(message)
		error("WP40 R4: " .. message, 0)
	end

	local function dense_count(values, label)
		if type(values) ~= "table" then fail(label .. " is not an array") end
		local count = #values
		for index = 1, count do
			if values[index] == nil then fail(label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
					key > count then
				fail(label .. " is not a dense array")
			end
		end
		return count
	end

	local function finite_number(value, label)
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or
				math.abs(value) > MAX_SAFE then
			fail(label .. " is not a finite safe number")
		end
		return value
	end

	local function integer(value, label)
		finite_number(value, label)
		if value % 1 ~= 0 then fail(label .. " is not an integer") end
		return value
	end

	local function normalize_coordinate(value, label)
		finite_number(value, label)
		local result
		if value >= 0 then
			local base = math.floor(value)
			result = value - base >= 0.5 and base + 1 or base
		else
			local base = math.ceil(value)
			result = base - value >= 0.5 and base - 1 or base
		end
		return integer(result, label .. " rounded")
	end

	local function normalize_xz(x, z, label)
		x = normalize_coordinate(x, label .. " x")
		z = normalize_coordinate(z, label .. " z")
		return x, z, x < MIN_X or x > MAX_X or z < MIN_Z or z > MAX_Z
	end

	local function normalize_position(position, label)
		if type(position) ~= "table" then fail(label .. " is not a position") end
		local x = normalize_coordinate(position.x, label .. " x")
		local y = normalize_coordinate(position.y, label .. " y")
		local z = normalize_coordinate(position.z, label .. " z")
		return x, y, z,
			x < MIN_X or x > MAX_X or z < MIN_Z or z > MAX_Z
	end

	local function require_text(value, label)
		if type(value) ~= "string" then fail(label .. " is not text") end
		return value
	end

	local function deep_copy(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("cyclic result table") end
		active[value] = true
		local result = {}
		for key, child in pairs(value) do
			result[deep_copy(key, active)] = deep_copy(child, active)
		end
		active[value] = nil
		return result
	end

	local function source_subset_matches(expected, actual, active)
		if type(expected) ~= type(actual) then return false end
		if type(expected) ~= "table" then return expected == actual end
		active = active or {}
		if active[expected] then fail("cyclic source authority") end
		active[expected] = true
		for key, value in pairs(expected) do
			if not source_subset_matches(value, actual[key], active) then
				active[expected] = nil
				return false
			end
		end
		active[expected] = nil
		return true
	end

	local function sorted_keys(values)
		local result = {}
		for key in pairs(values) do result[#result + 1] = key end
		table.sort(result)
		return result
	end

	local function validate_factory_authority()
		if type(source) ~= "table" or type(schemas) ~= "table" or
				type(canonical) ~= "table" or type(deterministic) ~= "table" or
				type(index128) ~= "table" or type(horizontal_factory) ~= "function" or
				type(height_factory) ~= "function" or
				type(injected_raw_sha256) ~= "function" then
			fail("dependency type differs")
		end
		if source.schema ~= "grug_wp40_simple_map_source_v2" or
				schemas.simple_map_source ~= source.schema or
				schemas.simple_map ~= "grug_wp40_simple_map_v1" or
				schemas.geometry_source ~= "grug_wp40_geometry_source_v1" or
				source.layout_id ~= "wp40-simple-map-v1d" or
				source.layout_revision_id ~= "wp40-simple-map-v1e" then
			fail("source/schema/layout authority differs")
		end
		if type(canonical.encode) ~= "function" or
				type(canonical.text) ~= "function" or
				type(canonical.signed) ~= "function" or
				type(canonical.array) ~= "function" or
				type(canonical.hex) ~= "function" or
				type(deterministic.new_hash) ~= "function" or
				type(deterministic.floor_div) ~= "function" then
			fail("canonical/deterministic seam differs")
		end
		for _, name in ipairs({"compile_sparse_segments", "nearest_segment",
				"nearest_segment_values", "compile_footprints",
				"footprint_candidates", "sparse_metrics"}) do
			if type(index128[name]) ~= "function" then
				fail("sparse index seam missing: " .. name)
			end
		end
		local expected_counts = {
			zones = 38,
			routes = 57,
			boat_paths = 4,
			island_routes = 8,
			anchors = 100,
			poi_spurs = 74,
			hydrology = 25,
			hard_protection = 42,
			hard_protection_recipes = 4,
			capital_ingresses = 6,
		}
		for key, expected in pairs(expected_counts) do
			if dense_count(source[key], key) ~= expected then
				fail(key .. " count differs")
			end
		end
		if source.housing_policy.reservation_width ~= 101 or
				source.housing_policy.reservation_radius ~= 50 or
				dense_count(source.claim_exclusions, "claim exclusions") ~= 314 then
			fail("housing authority differs")
		end
	end

	validate_factory_authority()

	local module = {
		schema = ZONES_SCHEMA,
		sparse_schema = SPARSE_SCHEMA,
	}

	local function construct(full_seed_string, configured_water_level,
			planner_source_requested)
		if configured_water_level ~= WATER_LEVEL then
			fail("configured water level differs from exact integer 1")
		end
		local horizontal_session_count = 0
		local height_session_count = 0
		local planner_source_count = 0
		local construction_complete = false
		local construction_sha256_calls = 0
		local query_sha256_calls = 0
		local function counted_sha(data)
			if type(data) ~= "string" then fail("SHA-256 input is not bytes") end
			if construction_complete then
				query_sha256_calls = query_sha256_calls + 1
			else
				construction_sha256_calls = construction_sha256_calls + 1
			end
			local digest = injected_raw_sha256(data)
			if type(digest) ~= "string" or #digest ~= 32 then
				fail("raw SHA-256 injection did not return 32 bytes")
			end
			return digest
		end

		-- new_hash performs the canonical unsigned-64 seed validation before any
		-- evaluator construction and remains the one R4 hash grammar.
		local logical_hash = deterministic.new_hash(canonical, counted_sha,
			schemas.geometry_source, full_seed_string)
		local horizontal_module = horizontal_factory({
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			raw_sha256 = counted_sha,
		})
		if type(horizontal_module) ~= "table" or
				type(horizontal_module.new) ~= "function" then
			fail("horizontal module seam differs")
		end
		local horizontal = horizontal_module.new(full_seed_string)
		if type(horizontal) ~= "table" or
				type(horizontal.classification_values_at) ~= "function" or
				type(horizontal.difficulty_for_macro_at) ~= "function" or
				type(horizontal.polyline_corridor_member) ~= "function" or
				type(horizontal.housing_eligible_at) ~= "function" then
			fail("horizontal session seam differs")
		end
		horizontal_session_count = horizontal_session_count + 1
		local height_module = height_factory({
			source = source,
			canonical = canonical,
			deterministic = deterministic,
			raw_sha256 = counted_sha,
			horizontal_session = horizontal,
		})
		if type(height_module) ~= "table" or
				type(height_module.new) ~= "function" then
			fail("height module seam differs")
		end
		local height = height_module.new(full_seed_string)
		if type(height) ~= "table" or
				type(height.terrain_height_at) ~= "function" or
				type(height.water_surface_at) ~= "function" or
				type(height.functional_surface_values_at) ~= "function" or
				type(height.hydrology_transition_values_at) ~= "function" or
				type(height.selected_anchor_3d_by_id) ~= "function" or
				type(height.hard_protection_volumes) ~= "function" or
				type(height.canonical_kat_digest) ~= "function" or
				type(height.metrics) ~= "function" then
			fail("height session seam differs")
		end
		height_session_count = height_session_count + 1

		local zone_by_id, zone_by_numeric, zone_records = {}, {}, {}
		for zone_index = 1, #source.zones do
			local row = source.zones[zone_index]
			if row.numeric_id ~= zone_index or type(row.id) ~= "string" or
					row.id == "" or zone_by_id[row.id] then
				fail("zone identity/order differs")
			end
			if row.faction ~= false and row.faction ~= "accord" and
					row.faction ~= "throng" then
				fail("zone faction differs")
			end
			if row.territory_rule ~= "accord_home" and
					row.territory_rule ~= "throng_home" and
					row.territory_rule ~= "contested_land" and
					row.territory_rule ~= "holy_grounds" then
				fail("zone territory rule differs")
			end
			if row.pvp_rule ~= "peaceful" and row.pvp_rule ~= "contested" then
				fail("zone PvP rule differs")
			end
			local biomes = {}
			local share_total = 0
			for biome_index = 1, dense_count(row.biomes, "zone biomes") do
				local biome = row.biomes[biome_index]
				if type(biome.id) ~= "string" or biome.id == "" or
						integer(biome.share, "biome share") <= 0 then
					fail("zone biome entry differs")
				end
				share_total = share_total + biome.share
				biomes[biome_index] = {id = biome.id, share = biome.share}
			end
			if share_total ~= 100 then fail("zone biome shares do not total 100") end
			local record = {
				numeric_id = zone_index,
				id = row.id,
				display_name = row.display_name,
				macro_region = row.macro_region,
				race_region = row.race_region,
				faction = row.faction ~= false and row.faction or nil,
				territory_rule = row.territory_rule,
				pvp_rule = row.pvp_rule,
				level_min = row.level_min,
				level_max = row.level_max,
				primary_relief_id = row.primary_relief_id,
				difficulty_target = row.difficulty_target,
				civic_no_hostiles = row.civic_no_hostiles == true,
				hub = {x = row.hub.x, z = row.hub.z},
				biomes = biomes,
			}
			zone_records[zone_index] = record
			zone_by_numeric[zone_index] = record
			zone_by_id[row.id] = record
		end

		local neighbor_ids = {}
		for zone_index = 1, #source.zones do neighbor_ids[zone_index] = {} end
		local neighbor_seen = {}
		local neighbor_edges = {}
		for route_index = 1, #source.routes do
			local route = source.routes[route_index]
			local a, b = integer(route.zone_a, "route zone a"),
				integer(route.zone_b, "route zone b")
			if not zone_by_numeric[a] or not zone_by_numeric[b] or a == b then
				fail("route endpoint zone differs")
			end
			local first, second = a, b
			if second < first then first, second = second, first end
			local key = tostring(first) .. ":" .. tostring(second)
			if neighbor_seen[key] then fail("duplicate land neighbor edge") end
			neighbor_seen[key] = true
			neighbor_ids[a][#neighbor_ids[a] + 1] = zone_by_numeric[b].id
			neighbor_ids[b][#neighbor_ids[b] + 1] = zone_by_numeric[a].id
			neighbor_edges[#neighbor_edges + 1] = {
				a = zone_by_numeric[first].id,
				b = zone_by_numeric[second].id,
				route_id = route.id,
			}
		end
		for zone_index = 1, #neighbor_ids do table.sort(neighbor_ids[zone_index]) end
		table.sort(neighbor_edges, function(a, b)
			if a.a ~= b.a then return a.a < b.a end
			if a.b ~= b.b then return a.b < b.b end
			return a.route_id < b.route_id
		end)

		local travel_by_zone, travel_records = {}, {}
		for zone_index = 1, #source.zones do travel_by_zone[zone_index] = {} end
		for boat_index = 1, #source.boat_paths do
			local boat = source.boat_paths[boat_index]
			if type(boat.id) ~= "string" or not zone_by_numeric[boat.from_zone] or
					not zone_by_numeric[boat.to_zone] or
					boat.from_zone == boat.to_zone or boat.kind ~= "boat" then
				fail("boat path record differs")
			end
			local absolute = {
				id = boat.id,
				kind = "boat",
				from_zone_id = zone_by_numeric[boat.from_zone].id,
				to_zone_id = zone_by_numeric[boat.to_zone].id,
				landing_id = boat.landing_id,
				width = boat.width,
				centreline = deep_copy(boat.centreline),
			}
			travel_records[boat_index] = absolute
			for _, zone_index in ipairs({boat.from_zone, boat.to_zone}) do
				local row = deep_copy(absolute)
				row.destination_zone_id = zone_by_numeric[
					zone_index == boat.from_zone and boat.to_zone or boat.from_zone].id
				travel_by_zone[zone_index][#travel_by_zone[zone_index] + 1] = row
			end
		end
		for zone_index = 1, #travel_by_zone do
			table.sort(travel_by_zone[zone_index], function(a, b) return a.id < b.id end)
		end

		local anchor_by_zone_slot, anchor_records = {}, {}
		for zone_index = 1, #source.zones do anchor_by_zone_slot[zone_index] = {} end
		for anchor_index = 1, #source.anchors do
			local source_anchor = source.anchors[anchor_index]
			local record = height.selected_anchor_3d_by_id(source_anchor.id)
			if type(record) ~= "table" or record.id ~= source_anchor.id or
					record.numeric_id ~= anchor_index or
					record.zone_numeric_id ~= source_anchor.zone_numeric_id or
					record.slot_id ~= source_anchor.slot_id or
					record.template_id ~= source_anchor.template_id or
					record.selection_mode ~= (source_anchor.placement_mode ==
						"authored_fixed" and "authored_fixed" or "frozen_layout") or
					record.approved_candidate_index ~=
						source_anchor.approved_candidate_index or
					record.x ~= source_anchor.position.x or
					record.z ~= source_anchor.position.z then
				fail("R3 anchor passthrough differs")
			end
			local slots = anchor_by_zone_slot[record.zone_numeric_id]
			if slots[record.slot_id] then fail("duplicate anchor zone slot") end
			anchor_records[anchor_index] = deep_copy(record)
			slots[record.slot_id] = anchor_records[anchor_index]
		end

		local selector = source.logical_biome_selector
		if type(selector) ~= "table" or selector.cell_size ~= 192 or
				selector.site_offset_min ~= 32 or selector.site_offset_span ~= 128 or
				type(selector.hash_lanes) ~= "table" or
				selector.hash_lanes.site_x ~= 0 or
				selector.hash_lanes.site_z ~= 1 or
				selector.hash_lanes.palette ~= 2 or
				selector.hash_domain ~= "logical_biome_patch_v1" or
				selector.nearest_tie_rule ~= "lowest_cell_x_then_lowest_cell_z" then
			fail("logical biome selector differs")
		end
		local cell_size = selector.cell_size
		local min_cell_x = deterministic.floor_div(MIN_X, cell_size) - 1
		local max_cell_x = deterministic.floor_div(MAX_X, cell_size) + 1
		local min_cell_z = deterministic.floor_div(MIN_Z, cell_size) - 1
		local max_cell_z = deterministic.floor_div(MAX_Z, cell_size) + 1
		local logical_sites, logical_digest_rows = {}, {}
		local logical_site_count = 0
		for cell_x = min_cell_x, max_cell_x do
			local column = {}
			logical_sites[cell_x] = column
			for cell_z = min_cell_z, max_cell_z do
				local site_x = cell_x * cell_size + selector.site_offset_min +
					logical_hash.range(selector.hash_domain, "", {cell_x, cell_z},
						0, selector.hash_lanes.site_x, selector.site_offset_span)
				local site_z = cell_z * cell_size + selector.site_offset_min +
					logical_hash.range(selector.hash_domain, "", {cell_x, cell_z},
						0, selector.hash_lanes.site_z, selector.site_offset_span)
				local roll = logical_hash.range(selector.hash_domain, "",
					{cell_x, cell_z}, 0, selector.hash_lanes.palette, 100)
				column[cell_z] = {x = site_x, z = site_z, roll = roll}
				logical_site_count = logical_site_count + 1
				logical_digest_rows[#logical_digest_rows + 1] = canonical.array({
					canonical.signed(cell_x), canonical.signed(cell_z),
					canonical.signed(site_x), canonical.signed(site_z),
					canonical.signed(roll),
				})
			end
		end
		local logical_site_digest = canonical.hex(counted_sha(canonical.encode(
			canonical.array(logical_digest_rows))))

		local function classification_values(x, z, outside)
			if outside then return "deep_ocean", nil, nil end
			local water_class, macro_region, zone_numeric_id, bay_id,
				classified_hydrology_id, channel_id, fixed, civic_water =
				horizontal.classification_values_at(x, z)
			if not WATER_CLASSES[water_class] then
				fail("unknown horizontal water class")
			end
			if OWNER_CLASSES[water_class] then
				if not zone_by_numeric[zone_numeric_id] then
					fail("owner-bearing class lacks a valid zone")
				end
			elseif zone_numeric_id ~= nil then
				fail("ownerless water class carries a zone")
			end
			return water_class, macro_region, zone_numeric_id, bay_id,
				classified_hydrology_id, channel_id, fixed, civic_water
		end

		local function surface_level_from_classification(x, z, water_class,
				macro_region)
			if water_class ~= "land" and water_class ~= "planned_water" then
				return nil
			end
			local level = horizontal.difficulty_for_macro_at(x, z, macro_region)
			if type(level) ~= "number" or level % 1 ~= 0 or
					level < 1 or level > 60 then
				fail("surface mob level differs")
			end
			return level
		end

		local function logical_biome_at(x, z, zone_numeric_id)
			local own_x = deterministic.floor_div(x, cell_size)
			local own_z = deterministic.floor_div(z, cell_size)
			local best_site, best_x, best_z, best_distance
			for cell_x = own_x - 1, own_x + 1 do
				for cell_z = own_z - 1, own_z + 1 do
					local site = logical_sites[cell_x] and logical_sites[cell_x][cell_z]
					if not site then fail("logical biome halo is incomplete") end
					local dx, dz = x - site.x, z - site.z
					local distance = dx * dx + dz * dz
					if best_distance == nil or distance < best_distance or
							(distance == best_distance and (cell_x < best_x or
							(cell_x == best_x and cell_z < best_z))) then
						best_site, best_x, best_z, best_distance = site, cell_x, cell_z,
							distance
					end
				end
			end
			local cumulative = 0
			local palette = zone_by_numeric[zone_numeric_id].biomes
			for index = 1, #palette do
				cumulative = cumulative + palette[index].share
				if best_site.roll < cumulative then return palette[index].id end
			end
			fail("logical biome roll escaped its palette")
		end

		-- Sparse path/hydrology and hard-footprint compilation follows below.
		-- All three indexes contain acceleration data only; exact policy and
		-- membership remain in this session and the accepted evaluators.
		local source_anchor_by_id = {}
		for anchor_index = 1, #source.anchors do
			source_anchor_by_id[source.anchors[anchor_index].id] =
				source.anchors[anchor_index]
		end
		local trail_templates = {
			bandit_home = true,
			bandit_frontier = true,
			mirefolk = true,
			clash = true,
		}
		local path_by_id, path_rows, route_segments = {}, {}, {}
		local function add_path(source_path, path_kind, route_class, order,
				surface_width, corridor_width)
			if type(source_path.id) ~= "string" or source_path.id == "" or
					path_by_id[source_path.id] then
				fail("graded path identity differs")
			end
			if not source.route_profiles[route_class] or
					source.route_profiles[route_class].surface_width ~= surface_width or
					source.route_profiles[route_class].corridor_width ~= corridor_width then
				fail("graded path profile differs")
			end
			local points = source_path.centreline
			if dense_count(points, "graded path points") < 2 then
				fail("graded path has fewer than two points")
			end
			local row = {
				id = source_path.id,
				path_kind = path_kind,
				route_class = route_class,
				surface_width = surface_width,
				corridor_width = corridor_width,
				centreline = points,
				feature_order = order,
			}
			path_rows[#path_rows + 1] = row
			path_by_id[row.id] = row
			for segment = 1, #points - 1 do
				local a, b = points[segment], points[segment + 1]
				integer(a.x, "path point x") integer(a.z, "path point z")
				integer(b.x, "path point x") integer(b.z, "path point z")
				if a.x == b.x and a.z == b.z then
					fail("graded path has a degenerate source segment")
				end
				route_segments[#route_segments + 1] = {
					feature_id = row.id,
					feature_order = order,
					segment = segment,
					ax = a.x,
					az = a.z,
					bx = b.x,
					bz = b.z,
				}
			end
		end
		for route_index = 1, #source.routes do
			local route = source.routes[route_index]
			local profile = source.route_profiles[route.class]
			if not profile or route.surface_width ~= profile.surface_width or
					route.corridor_width ~= profile.corridor_width then
				fail("authored land-route profile differs")
			end
			add_path(route, "land_route", route.class, #path_rows + 1,
				profile.surface_width, profile.corridor_width)
		end
		for spur_index = 1, #source.poi_spurs do
			local spur = source.poi_spurs[spur_index]
			local anchor = source_anchor_by_id[spur.anchor_id]
			if not anchor then fail("POI spur anchor missing") end
			local route_class = trail_templates[anchor.template_id] and
				"trail" or "secondary"
			local profile = source.route_profiles[route_class]
			add_path(spur, "poi_spur", route_class, #path_rows + 1,
				profile.surface_width, profile.corridor_width)
		end
		for island_index = 1, #source.island_routes do
			local profile = source.route_profiles.secondary
			add_path(source.island_routes[island_index], "island_route",
				"secondary", #path_rows + 1, profile.surface_width,
				profile.corridor_width)
		end
		if #path_rows ~= 139 or #route_segments ~= 476 then
			fail("graded path/segment population differs")
		end
		local route_index = index128.compile_sparse_segments({
			schema = SPARSE_SCHEMA,
			min_x = MIN_X,
			max_x = MAX_X,
			min_z = MIN_Z,
			max_z = MAX_Z,
			tie_break = "feature_id",
			segments = route_segments,
		}, SPARSE_SCHEMA)

		local hydrology_profile_by_id = {}
		for profile_index = 1, dense_count(source.hydrology_profiles,
				"hydrology profiles") do
			local profile = source.hydrology_profiles[profile_index]
			if type(profile.id) ~= "string" or profile.id == "" or
					hydrology_profile_by_id[profile.id] then
				fail("hydrology profile identity differs")
			end
			local depth = integer(profile.depth, "hydrology profile depth")
			if depth < 0 or profile.bed_seal_layers ~= 3 or
					profile.bank_seal_nodes ~= 2 then
				fail("hydrology profile planner fields differ")
			end
			hydrology_profile_by_id[profile.id] = profile
		end
		local hydrology_by_id, hydrology_segments = {}, {}
		for reach_index = 1, #source.hydrology do
			local reach = source.hydrology[reach_index]
			if type(reach.id) ~= "string" or reach.id == "" or
					hydrology_by_id[reach.id] then
				fail("hydrology identity differs")
			end
			local profile = hydrology_profile_by_id[reach.profile_id]
			if not profile then fail("hydrology profile reference differs") end
			hydrology_by_id[reach.id] = {id = reach.id, order = reach_index,
				profile_id = profile.id, profile_depth = profile.depth}
			local points = reach.centreline
			if dense_count(points, "hydrology points") < 2 then
				fail("hydrology has fewer than two points")
			end
			for segment = 1, #points - 1 do
				local a, b = points[segment], points[segment + 1]
				integer(a.x, "hydrology point x") integer(a.z, "hydrology point z")
				integer(b.x, "hydrology point x") integer(b.z, "hydrology point z")
				if a.x == b.x and a.z == b.z then
					fail("hydrology has a degenerate source segment")
				end
				hydrology_segments[#hydrology_segments + 1] = {
					feature_id = reach.id,
					feature_order = reach_index,
					segment = segment,
					ax = a.x,
					az = a.z,
					bx = b.x,
					bz = b.z,
				}
			end
		end
		if #hydrology_segments ~= 102 then
			fail("hydrology segment population differs")
		end
		local hydrology_index = index128.compile_sparse_segments({
			schema = SPARSE_SCHEMA,
			min_x = MIN_X,
			max_x = MAX_X,
			min_z = MIN_Z,
			max_z = MAX_Z,
			tie_break = "feature_order",
			segments = hydrology_segments,
		}, SPARSE_SCHEMA)
		local hydrology_scalar_scratch
		if planner_source_requested then
			hydrology_scalar_scratch = {}
			for segment_index = 1, #hydrology_segments do
				hydrology_scalar_scratch[segment_index] = 0
			end
			hydrology_scalar_scratch._index128_compiled = hydrology_index
			hydrology_scalar_scratch._index128_capacity = #hydrology_segments
			hydrology_scalar_scratch._index128_generation = 0
			hydrology_scalar_scratch._index128_best_index = 0
			hydrology_scalar_scratch._index128_best_numerator = 0
			hydrology_scalar_scratch._index128_best_denominator = 1
			hydrology_scalar_scratch._index128_cells_scanned = 0
			hydrology_scalar_scratch._index128_candidates_scanned = 0
		end

		local recipe_by_id, source_route_by_id = {}, {}
		for recipe_index = 1, #source.hard_protection_recipes do
			local recipe = source.hard_protection_recipes[recipe_index]
			recipe_by_id[recipe.id] = recipe
		end
		for source_route_index = 1, #source.routes do
			local route = source.routes[source_route_index]
			source_route_by_id[route.id] = route
		end
		local height_hard_records = height.hard_protection_volumes()
		if dense_count(height_hard_records, "R3 hard volumes") ~= 42 then
			fail("R3 hard-volume count differs")
		end
		local hard_by_id, hard_rows, footprint_records = {}, {}, {}
		local function add_ingress_path_bounds(paths, points, bounds)
			paths[#paths + 1] = points
			for point_index = 1, #points do
				local point = points[point_index]
				bounds.min_x = bounds.min_x and math.min(bounds.min_x, point.x) or
					point.x
				bounds.max_x = bounds.max_x and math.max(bounds.max_x, point.x) or
					point.x
				bounds.min_z = bounds.min_z and math.min(bounds.min_z, point.z) or
					point.z
				bounds.max_z = bounds.max_z and math.max(bounds.max_z, point.z) or
					point.z
			end
		end
		for hard_index = 1, #source.hard_protection do
			local source_hard = source.hard_protection[hard_index]
			local height_hard = height_hard_records[hard_index]
			local recipe = recipe_by_id[source_hard.recipe_id]
			if not recipe then fail("hard recipe missing") end
			if type(height_hard) ~= "table" or
					not source_subset_matches(source_hard, height_hard) or
					height_hard.id ~= source_hard.id or
					height_hard.recipe_id ~= source_hard.recipe_id or
					height_hard.y_min ~= -700 or
					height_hard.upward_unbounded ~= true or
					height_hard.y_policy_id ~= recipe.y_policy_id then
				fail("R3 hard-volume passthrough differs")
			end
			local internal = {
				id = source_hard.id,
				record = deep_copy(height_hard),
				shape = recipe.shape,
				total_width = recipe.total_width,
				y_min = recipe.y_min,
			}
			local bbox
			if recipe.shape == "centered_half_open_square" then
				local center = source_hard.center
				if type(center) ~= "table" or recipe.total_width % 2 ~= 0 then
					fail("hard square geometry differs")
				end
				local half = recipe.total_width / 2
				internal.center = center
				bbox = {min_x = center.x - half, max_x = center.x + half,
					min_z = center.z - half, max_z = center.z + half}
			elseif recipe.shape == "polyline_corridor" then
				if dense_count(source_hard.route_ids, "hard ingress routes") ~= 2 then
					fail("hard ingress route count differs")
				end
				internal.paths = {}
				local raw_bounds = {}
				for route_id_index = 1, #source_hard.route_ids do
					local route = source_route_by_id[source_hard.route_ids[route_id_index]]
					if not route then fail("hard ingress route missing") end
					add_ingress_path_bounds(internal.paths, route.centreline, raw_bounds)
				end
				local expansion = math.floor((recipe.total_width + 1) / 2)
				bbox = {min_x = raw_bounds.min_x - expansion,
					max_x = raw_bounds.max_x + expansion + 1,
					min_z = raw_bounds.min_z - expansion,
					max_z = raw_bounds.max_z + expansion + 1}
			elseif recipe.shape == "exact_column" then
				local center = source_hard.center
				if type(center) ~= "table" then fail("hard socket center missing") end
				internal.center = center
				bbox = {min_x = center.x, max_x = center.x + 1,
					min_z = center.z, max_z = center.z + 1}
			else
				fail("unknown hard footprint shape")
			end
			internal.bbox = bbox
			hard_rows[hard_index] = internal
			if hard_by_id[internal.id] then fail("duplicate hard footprint id") end
			hard_by_id[internal.id] = internal
			footprint_records[hard_index] = {id = internal.id, bbox = bbox}
		end
		local hard_index = index128.compile_footprints({
			schema = SPARSE_SCHEMA,
			min_x = MIN_X,
			max_x = MAX_X,
			min_z = MIN_Z,
			max_z = MAX_Z,
			records = footprint_records,
		}, SPARSE_SCHEMA)

		local function square_member(x, z, center, total_width)
			local x2, z2 = 2 * x, 2 * z
			return x2 >= 2 * center.x - total_width and
				x2 < 2 * center.x + total_width and
				z2 >= 2 * center.z - total_width and
				z2 < 2 * center.z + total_width
		end

		local function hard_horizontal_member(row, x, z)
			if row.shape == "centered_half_open_square" then
				return square_member(x, z, row.center, row.total_width)
			elseif row.shape == "polyline_corridor" then
				for path_index = 1, #row.paths do
					if horizontal.polyline_corridor_member(x, z,
							row.paths[path_index], row.total_width) then
						return true
					end
				end
				return false
			elseif row.shape == "exact_column" then
				return x == row.center.x and z == row.center.z
			end
			fail("unknown hard footprint at query")
		end

		local hard_membership_counts = {}
		for hard_row_index = 1, #hard_rows do
			local row = hard_rows[hard_row_index]
			local count = 0
			for z = row.bbox.min_z, row.bbox.max_z - 1 do
				for x = row.bbox.min_x, row.bbox.max_x - 1 do
					if hard_horizontal_member(row, x, z) then
						count = count + 1
						local water_class, _, owner =
							horizontal.classification_values_at(x, z)
						if not OWNER_CLASSES[water_class] or not zone_by_numeric[owner] then
							fail("hard footprint overlaps immutable/ownerless water")
						end
					end
				end
			end
			if count == 0 then fail("hard footprint is empty") end
			hard_membership_counts[hard_row_index] = count
		end

		local route_index_metrics = index128.sparse_metrics(route_index)
		local hydrology_index_metrics = index128.sparse_metrics(hydrology_index)
		local hard_index_metrics = index128.sparse_metrics(hard_index)
		local nearest_route_query_count, nearest_hydrology_query_count = 0, 0
		local nearest_route_rings, nearest_hydrology_rings = 0, 0
		local nearest_route_cells, nearest_hydrology_cells = 0, 0
		local nearest_route_candidates, nearest_hydrology_candidates = 0, 0
		local nearest_route_max_rings, nearest_hydrology_max_rings = 0, 0
		local nearest_route_max_cells, nearest_hydrology_max_cells = 0, 0
		local nearest_route_max_candidates, nearest_hydrology_max_candidates = 0, 0

		local session = {}

		local function hard_row_at(x, y, z)
			if y < -700 then return nil end
			local candidates = index128.footprint_candidates(hard_index, x, z)
			for candidate_index = 1, #candidates do
				local row = hard_by_id[candidates[candidate_index]]
				if not row then fail("hard candidate identity differs") end
				if y >= row.y_min and hard_horizontal_member(row, x, z) then
					return row
				end
			end
			return nil
		end

		local function capital_member(x, y, z)
			if y < -700 then return false end
			local candidates = index128.footprint_candidates(hard_index, x, z)
			for candidate_index = 1, #candidates do
				local row = hard_by_id[candidates[candidate_index]]
				if row and row.record.recipe_id ==
						"hard_capital_build_plus_apron_v1" and
						hard_horizontal_member(row, x, z) then
					return true
				end
			end
			return false
		end

		local function depth_level(y)
			if y <= -992 then return 60 end
			local numerator = -3 * y
			local base = math.floor(numerator / 50)
			local remainder = numerator - base * 50
			local value = remainder >= 25 and base + 1 or base
			if value < 1 then return 1 end
			if value > 60 then return 60 end
			return value
		end

		function session.get(zone_id)
			require_text(zone_id, "zone id")
			local record = zone_by_id[zone_id]
			return record and deep_copy(record) or nil
		end

		function session.at(position)
			local x, _, z, outside = normalize_position(position, "zone query")
			local _, _, owner = classification_values(x, z, outside)
			return owner and deep_copy(zone_by_numeric[owner]) or nil
		end

		function session.neighbors(zone_id)
			require_text(zone_id, "neighbor zone id")
			local record = zone_by_id[zone_id]
			return record and deep_copy(neighbor_ids[record.numeric_id]) or {}
		end

		function session.travel_links(zone_id)
			require_text(zone_id, "travel zone id")
			local record = zone_by_id[zone_id]
			return record and deep_copy(travel_by_zone[record.numeric_id]) or {}
		end

		function session.anchor(zone_id, slot_id)
			require_text(zone_id, "anchor zone id")
			require_text(slot_id, "anchor slot id")
			local zone = zone_by_id[zone_id]
			if not zone then return nil end
			local record = anchor_by_zone_slot[zone.numeric_id][slot_id]
			return record and deep_copy(record) or nil
		end

		function session.id_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "zone id query")
			local _, _, owner = classification_values(x, z, outside)
			return owner and zone_by_numeric[owner].id or nil
		end

		function session.biome_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "biome query")
			local _, _, owner = classification_values(x, z, outside)
			return owner and logical_biome_at(x, z, owner) or nil
		end

		function session.race_region_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "race-region query")
			local _, _, owner = classification_values(x, z, outside)
			return owner and zone_by_numeric[owner].race_region or nil
		end

		function session.faction_at(position)
			local x, _, z, outside = normalize_position(position, "faction query")
			local _, _, owner = classification_values(x, z, outside)
			return owner and zone_by_numeric[owner].faction or nil
		end

		function session.territory_rule_at(position)
			local x, y, z, outside = normalize_position(position,
				"territory query")
			if not outside and hard_row_at(x, y, z) then return "hard_protected" end
			local water_class, _, owner = classification_values(x, z, outside)
			if water_class == "deep_ocean" or
					water_class == "immutable_dragon_channel" then
				return "immutable"
			end
			if y <= -701 then return "contested_land" end
			if not owner then fail("territory owner is absent") end
			return zone_by_numeric[owner].territory_rule
		end

		function session.pvp_rule_at(position)
			local x, y, z, outside = normalize_position(position, "PvP query")
			local water_class, _, owner = classification_values(x, z, outside)
			if water_class == "deep_ocean" or
					water_class == "immutable_dragon_channel" then return nil end
			if y <= -701 then return "contested" end
			if not owner then fail("PvP owner is absent") end
			return zone_by_numeric[owner].pvp_rule
		end

		function session.surface_mob_level_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "surface-level query")
			local water_class, macro_region = classification_values(x, z, outside)
			return surface_level_from_classification(x, z, water_class,
				macro_region)
		end

		function session.mob_level_at(position)
			local x, y, z, outside = normalize_position(position, "mob-level query")
			local water_class, macro_region = classification_values(x, z, outside)
			if water_class == "deep_ocean" or
					water_class == "immutable_dragon_channel" then return nil end
			local surface = surface_level_from_classification(x, z, water_class,
				macro_region)
			if y >= 0 then return surface end
			local depth = depth_level(y)
			if surface and surface > depth then return surface end
			return depth
		end

		function session.guard_level_at(position)
			local x, y, z, outside = normalize_position(position,
				"guard-level query")
			local water_class, macro_region = classification_values(x, z, outside)
			if water_class ~= "land" and water_class ~= "planned_water" then
				return nil
			end
			if capital_member(x, y, z) then return 60 end
			local surface = surface_level_from_classification(x, z, water_class,
				macro_region)
			if surface < 20 then return 20 end
			if surface > 70 then return 70 end
			return surface
		end

		function session.terrain_height_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "terrain-height query")
			if outside then return -23 end
			local value = height.terrain_height_at(x, z)
			return integer(value, "R3 terrain height")
		end

		function session.water_class_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "water-class query")
			local water_class = classification_values(x, z, outside)
			return water_class
		end

		function session.nearest_route_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "nearest-route query")
			if outside then return nil end
			local nearest = index128.nearest_segment(route_index, x, z)
			if not nearest then return nil end
			local path = path_by_id[nearest.feature_id]
			if not path then fail("nearest route identity differs") end
			nearest_route_query_count = nearest_route_query_count + 1
			nearest_route_rings = nearest_route_rings + nearest.rings_scanned
			nearest_route_cells = nearest_route_cells + nearest.cells_scanned
			nearest_route_candidates = nearest_route_candidates +
				nearest.candidates_scanned
			nearest_route_max_rings = math.max(nearest_route_max_rings,
				nearest.rings_scanned)
			nearest_route_max_cells = math.max(nearest_route_max_cells,
				nearest.cells_scanned)
			nearest_route_max_candidates = math.max(nearest_route_max_candidates,
				nearest.candidates_scanned)
			return {
				route_id = path.id,
				path_kind = path.path_kind,
				route_class = path.route_class,
				segment = nearest.segment,
				distance_numerator = nearest.distance_numerator,
				distance_denominator = nearest.distance_denominator,
				distance_squared = nearest.distance_squared,
				surface_width = path.surface_width,
				corridor_width = path.corridor_width,
			}
		end

		function session.nearest_hydrology_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "nearest-hydrology query")
			if outside then return nil end
			local nearest = index128.nearest_segment(hydrology_index, x, z)
			if not nearest then return nil end
			if not hydrology_by_id[nearest.feature_id] then
				fail("nearest hydrology identity differs")
			end
			nearest_hydrology_query_count = nearest_hydrology_query_count + 1
			nearest_hydrology_rings = nearest_hydrology_rings +
				nearest.rings_scanned
			nearest_hydrology_cells = nearest_hydrology_cells +
				nearest.cells_scanned
			nearest_hydrology_candidates = nearest_hydrology_candidates +
				nearest.candidates_scanned
			nearest_hydrology_max_rings = math.max(nearest_hydrology_max_rings,
				nearest.rings_scanned)
			nearest_hydrology_max_cells = math.max(nearest_hydrology_max_cells,
				nearest.cells_scanned)
			nearest_hydrology_max_candidates = math.max(
				nearest_hydrology_max_candidates, nearest.candidates_scanned)
			return {
				hydrology_id = nearest.feature_id,
				segment = nearest.segment,
				distance_numerator = nearest.distance_numerator,
				distance_denominator = nearest.distance_denominator,
				distance_squared = nearest.distance_squared,
			}
		end

		function session.housing_eligible_at(x, z)
			local outside
			x, z, outside = normalize_xz(x, z, "housing query")
			if outside then return false end
			return horizontal.housing_eligible_at(x, z)
		end

		local compatibility = {}
		function compatibility.surface_level_at(x, z)
			return session.terrain_height_at(x, z)
		end
		function compatibility.mob_level_at(position)
			return session.mob_level_at(position)
		end
		function compatibility.guard_level_at(position)
			return session.guard_level_at(position)
		end
		function compatibility.open_sea_at(position)
			local x, _, z = normalize_position(position, "open-sea query")
			return session.water_class_at(x, z) == "deep_ocean"
		end
		function compatibility.difficulty_at(position)
			local level = session.mob_level_at(position)
			if not level then return 1 end
			local value = (level - 1) / 59
			if value < 0 then return 0 end
			if value > 1 then return 1 end
			return value
		end
		function compatibility.territory_at(position)
			return session.faction_at(position) or "ocean"
		end
		function compatibility.zone_at(position)
			local x, y, z = normalize_position(position, "legacy-zone query")
			if y < -40 then return "underground" end
			local water_class = session.water_class_at(x, z)
			if water_class == "deep_ocean" then return "ocean" end
			if water_class == "immutable_dragon_channel" then return "strait" end
			if water_class == "coastal_shelf" then return "coast" end
			if session.pvp_rule_at({x = x, y = y, z = z}) == "contested" then
				return "war_coast"
			end
			local level = session.surface_mob_level_at(x, z)
			if level <= 5 then return "core" end
			if level <= 15 then return "inner" end
			return "outer"
		end
		function compatibility.world_protected_for_faction(position, actor_faction)
			if actor_faction ~= "accord" and actor_faction ~= "throng" then
				return true
			end
			local territory = session.territory_rule_at(position)
			if territory == "hard_protected" or territory == "immutable" then
				return true
			elseif territory == "accord_home" then
				return actor_faction ~= "accord"
			elseif territory == "throng_home" then
				return actor_faction ~= "throng"
			elseif territory == "contested_land" or
					territory == "holy_grounds" then
				return false
			end
			fail("unknown protection territory result")
		end
		session.compatibility = compatibility

		local horizontal_kat_digest = horizontal.canonical_kat_digest()
		local height_kat_digest = height.canonical_kat_digest()
		local evidence_hard = {}
		for hard_row_index = 1, #hard_rows do
			evidence_hard[hard_row_index] = deep_copy(hard_rows[hard_row_index].record)
			evidence_hard[hard_row_index].membership_columns =
				hard_membership_counts[hard_row_index]
			evidence_hard[hard_row_index].bbox =
				deep_copy(hard_rows[hard_row_index].bbox)
		end
		local artifact_evidence = {
			schema = ZONES_SCHEMA,
			sparse_schema = SPARSE_SCHEMA,
			layout_id = source.layout_id,
			layout_revision_id = source.layout_revision_id,
			full_seed = full_seed_string,
			water_level = WATER_LEVEL,
			bounds = {min_x = MIN_X, max_x = MAX_X,
				min_z = MIN_Z, max_z = MAX_Z},
			zone_records = deep_copy(zone_records),
			neighbor_edges = deep_copy(neighbor_edges),
			boat_paths = deep_copy(travel_records),
			anchors = deep_copy(anchor_records),
			hard_protection = evidence_hard,
			logical_biome = {
				cell_size = cell_size,
				min_cell_x = min_cell_x,
				max_cell_x = max_cell_x,
				min_cell_z = min_cell_z,
				max_cell_z = max_cell_z,
				site_count = logical_site_count,
				digest = logical_site_digest,
			},
			path_population = {features = #path_rows, segments = #route_segments},
			hydrology_population = {features = #source.hydrology,
				segments = #hydrology_segments},
			route_index = deep_copy(route_index_metrics),
			hydrology_index = deep_copy(hydrology_index_metrics),
			hard_index = deep_copy(hard_index_metrics),
			horizontal_canonical_kat_digest = horizontal_kat_digest,
			height_canonical_kat_digest = height_kat_digest,
			height_relief_lattice_digest = height.relief_lattice_digest(),
		}

		local function kat_text(value)
			return canonical.text(value or "")
		end
		local function kat_signed(value)
			return canonical.signed(value or 0)
		end
		local kat_rows = {
			canonical.array({kat_text("identity"), kat_text(ZONES_SCHEMA),
				kat_text(SPARSE_SCHEMA), kat_text(source.layout_id),
				kat_text(source.layout_revision_id), kat_text(full_seed_string),
				kat_signed(WATER_LEVEL), kat_text(horizontal_kat_digest),
				kat_text(height_kat_digest), kat_text(logical_site_digest)}),
			canonical.array({kat_text("counts"), kat_signed(#zone_records),
				kat_signed(#neighbor_edges), kat_signed(#travel_records),
				kat_signed(#anchor_records), kat_signed(#hard_rows),
				kat_signed(#path_rows), kat_signed(#route_segments),
				kat_signed(#source.hydrology), kat_signed(#hydrology_segments),
				kat_signed(logical_site_count)}),
		}
		for zone_index = 1, #zone_records do
			local row = zone_records[zone_index]
			kat_rows[#kat_rows + 1] = canonical.array({kat_text("zone"),
				kat_signed(zone_index), kat_text(row.id), kat_text(row.display_name),
				kat_text(row.macro_region), kat_text(row.race_region),
				kat_text(row.faction), kat_text(row.territory_rule),
				kat_text(row.pvp_rule), kat_signed(row.level_min),
				kat_signed(row.level_max), kat_text(row.primary_relief_id),
				kat_signed(row.difficulty_target), kat_signed(row.hub.x),
				kat_signed(row.hub.z)})
		end
		for _, point in ipairs({
			{0, 0, 0}, {-1800, -1500, -700}, {1800, 1500, -701},
			{-3740, -3340, -1000}, {3740, 3340, 1},
		}) do
			local x, z, y = point[1], point[2], point[3]
			kat_rows[#kat_rows + 1] = canonical.array({kat_text("sample"),
				kat_signed(x), kat_signed(y), kat_signed(z),
				kat_text(session.id_at(x, z)), kat_text(session.biome_at(x, z)),
				kat_text(session.water_class_at(x, z)),
				kat_text(session.territory_rule_at({x = x, y = y, z = z})),
				kat_text(session.pvp_rule_at({x = x, y = y, z = z})),
				kat_signed(session.surface_mob_level_at(x, z)),
				kat_signed(session.mob_level_at({x = x, y = y, z = z})),
				kat_signed(session.guard_level_at({x = x, y = y, z = z})),
				kat_signed(session.terrain_height_at(x, z))})
		end
		local canonical_kat = canonical.encode(canonical.array(kat_rows))
		local canonical_kat_digest = canonical.hex(counted_sha(canonical_kat))

		function session.canonical_kat()
			return canonical_kat
		end
		function session.canonical_kat_digest()
			return canonical_kat_digest
		end
		function session.artifact_evidence()
			return deep_copy(artifact_evidence)
		end
		function session.metrics()
			local height_metrics = height.metrics()
			if type(height_metrics) ~= "table" or
					type(height_metrics.query_lattice_constructions) ~= "number" then
				fail("R3 height metrics differ")
			end
			return {
				construction_sha256_calls = construction_sha256_calls,
				query_sha256_calls = query_sha256_calls,
				query_lattice_constructions =
					height_metrics.query_lattice_constructions,
				query_feature_list_constructions = 0,
				query_unindexed_catalog_scans = 0,
				logical_lattice_constructions = 1,
				logical_site_count = logical_site_count,
				nearest_route_query_count = nearest_route_query_count,
				nearest_route_rings_scanned = nearest_route_rings,
				nearest_route_cells_scanned = nearest_route_cells,
				nearest_route_candidates_scanned = nearest_route_candidates,
				nearest_route_maximum_rings_scanned = nearest_route_max_rings,
				nearest_route_maximum_cells_scanned = nearest_route_max_cells,
				nearest_route_maximum_candidates_scanned =
					nearest_route_max_candidates,
				nearest_hydrology_query_count = nearest_hydrology_query_count,
				nearest_hydrology_rings_scanned = nearest_hydrology_rings,
				nearest_hydrology_cells_scanned = nearest_hydrology_cells,
				nearest_hydrology_candidates_scanned =
					nearest_hydrology_candidates,
				nearest_hydrology_maximum_rings_scanned =
					nearest_hydrology_max_rings,
				nearest_hydrology_maximum_cells_scanned =
					nearest_hydrology_max_cells,
				nearest_hydrology_maximum_candidates_scanned =
					nearest_hydrology_max_candidates,
			}
		end

		local planner_source
		if planner_source_requested then
			planner_source = {
				schema = "grug_wp40_r5_planner_source_v1",
			}

			function planner_source.column_values_at(x, z)
				local outside
				x, z, outside = normalize_xz(x, z, "planner column query")
				local water_class, _, zone_numeric_id, _,
					classified_hydrology_id = classification_values(x, z, outside)
				local zone = zone_numeric_id and zone_by_numeric[zone_numeric_id] or nil
				if zone_numeric_id ~= nil and not zone then
					fail("planner column zone identity differs")
				end
				local zone_id = zone and zone.id or nil
				local logical_biome_id = zone and
					logical_biome_at(x, z, zone_numeric_id) or nil
				local race_region_id = zone and zone.race_region or nil
				local terrain_y = outside and -23 or
					integer(height.terrain_height_at(x, z),
						"planner R3 terrain height")
				local water_y = height.water_surface_at(x, z)
				if water_y ~= nil then
					water_y = integer(water_y, "planner R3 water height")
				end
				local classified_profile_depth
				if classified_hydrology_id ~= nil then
					local hydrology = hydrology_by_id[classified_hydrology_id]
					if not hydrology then
						fail("planner classified hydrology identity differs")
					end
					classified_profile_depth = hydrology.profile_depth
				end
				local functional_kind, functional_y, functional_feature_id,
					functional_interface_id =
					height.functional_surface_values_at(x, z)
				if functional_kind == nil then
					if functional_y ~= nil or functional_feature_id ~= nil or
							functional_interface_id ~= nil then
						fail("planner nil functional tuple differs")
					end
				elseif not FUNCTIONAL_KINDS[functional_kind] then
					fail("planner functional kind differs")
				else
					functional_y = integer(functional_y,
						"planner functional height")
					if type(functional_feature_id) ~= "string" or
							functional_feature_id == "" then
						fail("planner functional feature identity differs")
					end
					if functional_interface_id ~= nil and
							(type(functional_interface_id) ~= "string" or
							functional_interface_id == "") then
						fail("planner functional interface identity differs")
					end
				end
				local transition_kind, transition_interface_id,
					transition_upper_y, transition_lower_y, transition_progress_q,
					transition_face_mask =
					height.hydrology_transition_values_at(x, z)
				if transition_kind == nil then
					if transition_interface_id ~= nil or transition_upper_y ~= nil or
							transition_lower_y ~= nil or transition_progress_q ~= nil or
							transition_face_mask ~= nil then
						fail("planner nil transition tuple differs")
					end
				elseif transition_kind ~= "rapid" and
						transition_kind ~= "waterfall" then
					fail("planner transition kind differs")
				else
					if type(transition_interface_id) ~= "string" or
							transition_interface_id == "" then
						fail("planner transition interface identity differs")
					end
					transition_upper_y = integer(transition_upper_y,
						"planner transition upper height")
					transition_lower_y = integer(transition_lower_y,
						"planner transition lower height")
					if transition_face_mask ~= nil then
						if transition_kind ~= "waterfall" or
								transition_progress_q ~= nil then
							fail("planner contact transition tuple differs")
						end
						transition_face_mask = integer(transition_face_mask,
							"planner transition face mask")
						if transition_face_mask < 1 or transition_face_mask > 15 then
							fail("planner transition face mask differs")
						end
					else
						transition_progress_q = integer(transition_progress_q,
							"planner transition progress")
						if transition_progress_q < 0 or
								transition_progress_q > 65536 then
							fail("planner transition progress differs")
						end
					end
				end
				local hard_foundation = hard_row_at(x, terrain_y, z) ~= nil
				return water_class, zone_numeric_id, zone_id, logical_biome_id,
					race_region_id, terrain_y, water_y, classified_hydrology_id,
					classified_profile_depth, functional_kind, functional_y,
					functional_feature_id, functional_interface_id, transition_kind,
					transition_interface_id, transition_upper_y, transition_lower_y,
					transition_progress_q, transition_face_mask, hard_foundation
			end

			function planner_source.hydrology_metric_values_at(x, z)
				local outside
				x, z, outside = normalize_xz(x, z, "planner hydrology metric query")
				if outside then return nil, nil, nil, nil end
				local feature_id, _, segment, numerator, denominator =
					index128.nearest_segment_values(hydrology_index, x, z,
						hydrology_scalar_scratch)
				if feature_id == nil then return nil, nil, nil, nil end
				if not hydrology_by_id[feature_id] then
					fail("planner nearest hydrology identity differs")
				end
				integer(segment, "planner hydrology source segment")
				integer(numerator, "planner hydrology distance numerator")
				integer(denominator, "planner hydrology distance denominator")
				if numerator < 0 or denominator <= 0 then
					fail("planner hydrology distance ratio differs")
				end
				return feature_id, segment, numerator, denominator
			end

			function planner_source.metrics()
				local height_metrics = height.metrics()
				if type(height_metrics) ~= "table" or
						type(height_metrics.query_lattice_constructions) ~= "number" then
					fail("R3 height metrics differ")
				end
				return {
					horizontal_session_count = horizontal_session_count,
					height_session_count = height_session_count,
					planner_source_count = planner_source_count,
					query_table_allocations = 0,
					query_sha256_calls = query_sha256_calls,
					query_lattice_constructions =
						height_metrics.query_lattice_constructions,
					query_feature_list_constructions = 0,
					query_unindexed_catalog_scans = 0,
				}
			end
			planner_source_count = planner_source_count + 1
		end

		construction_complete = true
		return session, planner_source
	end

	function module.new(full_seed_string, configured_water_level)
		local session = construct(full_seed_string, configured_water_level, false)
		return session
	end

	function module.new_with_planner_source(full_seed_string,
			configured_water_level)
		return construct(full_seed_string, configured_water_level, true)
	end

	return module
end
