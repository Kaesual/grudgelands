-- Pure, disabled WP40 named-zone and policy payload. Publication remains R7.

local function new_surface_cave_factory(definition)
	if type(definition) ~= "table" or type(definition.full_seed_string) ~= "string" or
			definition.full_seed_string == "" or
			type(definition.column_values_at) ~= "function" or
			type(definition.static_exclusion_values_at) ~= "function" or
			type(definition.housing_mask_id_at) ~= "function" then
		error("WP40 surface caves: construction seam differs", 0)
	end
	-- Candidates are owner-local.  The writer alone may turn one into a mouth,
	-- after proving that its untouched v7 input contains reachable cave air.
	local CELL_SIZE, CELL_ORIGIN = 80, -30912
	local MARGIN, LENGTH, RADIUS, MAXIMUM_DEPTH, CACHE_LIMIT = 28, 24, 2, 24, 128
	local SINK_SEARCH_RADIUS = 24
	local PRIME = 16777213
	local phase = 0
	for index = 1, #definition.full_seed_string do
		phase = (phase * 131 + string.byte(definition.full_seed_string, index)) % 65521
	end
	local direction_x, direction_z = {1, 0, -1, 0}, {0, 1, 0, -1}
	local cache = {}
	for index = 1, CACHE_LIMIT do
		cache[index] = {ready = false, valid = false, cell_x = 0, cell_z = 0,
			record = {}}
	end
	local cache_hits, cache_misses, cache_evictions = 0, 0, 0

	local function integer(value, label)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or
				math.abs(value) > 9007199254740991 then
			error("WP40 surface caves: " .. label .. " differs", 0)
		end
		return value
	end

	local function mixed(cell_x, cell_z, salt)
		local value = (cell_x * 374761 + cell_z * 668265 +
			phase * 69069 + salt) % PRIME
		value = (value * value) % PRIME
		return (value * 48271) % PRIME
	end

	local function ordinary_column(x, z, wanted_zone)
		local water_class, _, zone_id, biome, _, terrain_y, water_y,
			classified_hydrology_id, _, functional_kind, _, _, _, transition_kind,
			_, _, _, _, _, hard_foundation = definition.column_values_at(x, z)
		if water_class ~= "land" or zone_id == nil or biome == nil or
				(wanted_zone ~= nil and zone_id ~= wanted_zone) or water_y ~= nil or
				classified_hydrology_id ~= nil or functional_kind ~= nil or
				transition_kind ~= nil or hard_foundation ~= false or
				definition.static_exclusion_values_at(x, z) ~= nil or
				definition.housing_mask_id_at(x, z) ~= nil then
			return nil
		end
		return integer(terrain_y, "terrain height"), zone_id
	end

	local function build_candidate(cell_x, cell_z, record)
		if mixed(cell_x, cell_z, 19349663) % 4 == 0 then return false end
		local cell_min_x = CELL_ORIGIN + cell_x * CELL_SIZE
		local cell_min_z = CELL_ORIGIN + cell_z * CELL_SIZE
		local span = CELL_SIZE - MARGIN * 2
		local mouth_x = cell_min_x + MARGIN + mixed(cell_x, cell_z, 83492791) % span
		local mouth_z = cell_min_z + MARGIN + mixed(cell_x, cell_z, 297121507) % span
		local mouth_y, zone_id = ordinary_column(mouth_x, mouth_z, nil)
		if not mouth_y or mouth_y - MAXIMUM_DEPTH - RADIUS < -37 then return false end
		local endpoint_distance = 12
		local first_direction = mixed(cell_x, cell_z, 982451653) % 4 + 1
		local best_direction, best_height, best_rise
		for offset = 0, 3 do
			local direction = (first_direction + offset - 1) % 4 + 1
			local endpoint_x = mouth_x + direction_x[direction] * endpoint_distance
			local endpoint_z = mouth_z + direction_z[direction] * endpoint_distance
			local endpoint_y = ordinary_column(endpoint_x, endpoint_z, zone_id)
			local rise = endpoint_y and endpoint_y - mouth_y or -9007199254740991
			if best_rise == nil or rise > best_rise then
				best_direction, best_height, best_rise = direction, endpoint_y, rise
			end
		end
		if not best_height then return false end
		local kind = best_rise >= 4 and "hillside" or "sinkhole"
		if kind == "sinkhole" then
			local lowest, highest = mouth_y, mouth_y
			for direction = 1, 4 do
				local sample_y = ordinary_column(mouth_x + direction_x[direction] * 6,
					mouth_z + direction_z[direction] * 6, zone_id)
				if not sample_y then return false end
				lowest, highest = math.min(lowest, sample_y), math.max(highest, sample_y)
			end
			if highest - lowest > 3 then return false end
		end
		local dx, dz = direction_x[best_direction], direction_z[best_direction]
		local footprint_length = kind == "hillside" and LENGTH or 1
		local last_x, last_z = mouth_x + dx * (footprint_length - 1),
			mouth_z + dz * (footprint_length - 1)
		local min_x, max_x, min_z, max_z
		if kind == "sinkhole" then
			-- Only the fixed mouth apron is an offline volume.  The writer selects
			-- and validates the exact slant path after seeing immutable native air;
			-- reserving every possible path here would turn the search disc itself
			-- into an exclusion and discard otherwise valid candidates.
			min_x, max_x = mouth_x - RADIUS - 2, mouth_x + RADIUS + 2
			min_z, max_z = mouth_z - RADIUS - 2, mouth_z + RADIUS + 2
		elseif dx ~= 0 then
			min_x, max_x = math.min(mouth_x, last_x) - 2,
				math.max(mouth_x, last_x) + 2
			min_z, max_z = mouth_z - RADIUS - 2, mouth_z + RADIUS + 2
		else
			min_x, max_x = mouth_x - RADIUS - 2, mouth_x + RADIUS + 2
			min_z, max_z = math.min(mouth_z, last_z) - 2,
				math.max(mouth_z, last_z) + 2
		end
		if min_x < cell_min_x or max_x >= cell_min_x + CELL_SIZE or
				min_z < cell_min_z or max_z >= cell_min_z + CELL_SIZE then
			error("WP40 surface caves: footprint escaped its cell", 0)
		end
		for z = min_z, max_z do
			for x = min_x, max_x do
				if not ordinary_column(x, z, zone_id) then return false end
			end
		end
		local minimum_y = mouth_y - MAXIMUM_DEPTH - RADIUS
		if kind == "hillside" then
			for step = 8, LENGTH - 1 do
				local terrain_y = ordinary_column(mouth_x + dx * step,
					mouth_z + dz * step, zone_id)
				if not terrain_y or terrain_y < mouth_y + 4 then return false end
			end
		end
		record.cell_x, record.cell_z = cell_x, cell_z
		record.zone_id = zone_id
		record.mouth_x, record.mouth_y, record.mouth_z = mouth_x, mouth_y, mouth_z
		record.direction_x, record.direction_z = dx, dz
		record.endpoint_distance, record.endpoint_height = endpoint_distance, best_height
		record.kind, record.length, record.radius = kind, LENGTH, RADIUS
		record.search_radius = kind == "sinkhole" and SINK_SEARCH_RADIUS or RADIUS
		record.maximum_depth, record.minimum_y = MAXIMUM_DEPTH, minimum_y
		return true
	end

	local function candidate_at(cell_x, cell_z)
		cell_x, cell_z = integer(cell_x, "cell x"), integer(cell_z, "cell z")
		local slot_index = (cell_x * 37 + cell_z * 61) % CACHE_LIMIT + 1
		local slot = cache[slot_index]
		if slot.ready and slot.cell_x == cell_x and slot.cell_z == cell_z then
			cache_hits = cache_hits + 1
			return slot.valid and slot.record or nil
		end
		cache_misses = cache_misses + 1
		if slot.ready then cache_evictions = cache_evictions + 1 end
		slot.ready, slot.cell_x, slot.cell_z = true, cell_x, cell_z
		slot.valid = build_candidate(cell_x, cell_z, slot.record)
		return slot.valid and slot.record or nil
	end

	local session = {}
	function session.run_at(x, z)
		integer(x, "query x") integer(z, "query z")
		return nil
	end
	function session.candidate_record_at_cell(cell_x, cell_z)
		local record = candidate_at(cell_x, cell_z)
		if not record then return nil end
		local copy = {}
		for key, value in pairs(record) do copy[key] = value end
		return copy
	end
	function session.metrics()
		return {cache_limit = CACHE_LIMIT, cache_hits = cache_hits,
			cache_misses = cache_misses, cache_evictions = cache_evictions}
	end
	function session.cell_at(x, z)
		x, z = integer(x, "query x"), integer(z, "query z")
		return math.floor((x - CELL_ORIGIN) / CELL_SIZE),
			math.floor((z - CELL_ORIGIN) / CELL_SIZE)
	end
	function session.constants()
		return CELL_SIZE, CELL_ORIGIN, LENGTH, RADIUS, MAXIMUM_DEPTH
	end
	return session
end

local function zones_factory(dependencies)
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
		terrain_field = true,
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
	local terrain_field = dependencies.terrain_field
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
	end

	validate_factory_authority()

	local module = {
		schema = ZONES_SCHEMA,
		sparse_schema = SPARSE_SCHEMA,
	}

	local function construct(full_seed_string, configured_water_level,
			planner_source_requested, runtime_mode)
		if runtime_mode ~= nil and runtime_mode ~= true then
			fail("runtime construction mode differs")
		end
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
				type(horizontal.warp_at) ~= "function" or
				type(horizontal.zone_level_at) ~= "function" or
				type(horizontal.biome_lookup_at) ~= "function" or
				type(horizontal.neighbors) ~= "function" or
				type(horizontal.housing_eligible_at) ~= "function" or
				type(horizontal.static_exclusion_values_at) ~= "function" or
				type(horizontal.housing_mask_id_at) ~= "function" then
			fail("horizontal session seam differs")
		end
		horizontal_session_count = horizontal_session_count + 1
		local height_module = height_factory({
			source = source,
			canonical = canonical,
			deterministic = deterministic,
			raw_sha256 = counted_sha,
			horizontal_session = horizontal,
			terrain_field = terrain_field,
		})
		if type(height_module) ~= "table" or
				type(height_module.new) ~= "function" or
				(runtime_mode and type(height_module.new_runtime) ~= "function") then
			fail("height module seam differs")
		end
		local height_constructor = runtime_mode and height_module.new_runtime or
			height_module.new
		local height = height_constructor(full_seed_string)
		if type(height) ~= "table" or
				type(height.terrain_height_at) ~= "function" or
				type(height.water_surface_at) ~= "function" or
				type(height.functional_surface_values_at) ~= "function" or
				type(height.hydrology_transition_values_at) ~= "function" or
				type(height.selected_anchor_3d_by_id) ~= "function" or
				type(height.hard_protection_volumes) ~= "function" or
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
					row.territory_rule ~= "contested_land" then
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
				civic_no_hostiles = row.civic_no_hostiles == true,
				hub = {x = row.hub.x, z = row.hub.z},
				biomes = biomes,
			}
			zone_records[zone_index] = record
			zone_by_numeric[zone_index] = record
			zone_by_id[row.id] = record
		end
		-- Gameplay neighbours are geometric zone adjacency (world_zones.md §9.1,
		-- D14), computed once per world by the horizontal session.
		local neighbor_ids = {}
		for zone_index = 1, #source.zones do
			neighbor_ids[zone_index] = horizontal.neighbors(zone_index)
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
		local logical_sites = {}
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
			end
		end

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

		-- R11 uses squared integer distance so the public level field stays
		-- deterministic, allocation-free and independent of chunk order.
		local START_LEVEL_CORE_RADIUS = 100
		local START_LEVEL_BAND_RADIUS = 150
		local START_LEVEL_CORE_RADIUS_SQUARED =
			START_LEVEL_CORE_RADIUS * START_LEVEL_CORE_RADIUS
		local START_LEVEL_BAND_RADIUS_SQUARED =
			START_LEVEL_BAND_RADIUS * START_LEVEL_BAND_RADIUS
		local start_level_anchors = {}
		for anchor_index = 1, #anchor_records do
			local anchor = anchor_records[anchor_index]
			if anchor.slot_id == "start" then
				start_level_anchors[#start_level_anchors + 1] = {
					x = anchor.x,
					z = anchor.z,
				}
			end
		end
		if #start_level_anchors ~= 6 then
			fail("start-level anchor population differs")
		end

		local function start_band_level_at(x, z)
			local inside_band = false
			for anchor_index = 1, #start_level_anchors do
				local anchor = start_level_anchors[anchor_index]
				local dx, dz = x - anchor.x, z - anchor.z
				local distance_squared = dx * dx + dz * dz
				if distance_squared <= START_LEVEL_CORE_RADIUS_SQUARED then
					return 1
				elseif distance_squared <= START_LEVEL_BAND_RADIUS_SQUARED then
					inside_band = true
				end
			end
			if inside_band then return 2 end
			return nil
		end

		-- Levels follow the owning zone (world_zones.md §2, D20); the inner start
		-- band overrides them around the six starts.
		local function surface_level_from_classification(x, z, water_class, owner)
			if water_class ~= "land" and water_class ~= "planned_water" then
				return nil
			end
			local level = horizontal.zone_level_at(x, z, owner)
			if type(level) ~= "number" or level % 1 ~= 0 or
					level < 1 or level > 60 then
				fail("surface mob level differs")
			end
			return start_band_level_at(x, z) or level
		end

		local function logical_biome_at(x, z, zone_numeric_id)
			-- Biome dither at zone borders (world_zones.md §7.3): the palette zone
			-- and the patch lookup both use one jittered point.
			local palette_zone, qx, qz = horizontal.biome_lookup_at(x, z)
			if palette_zone then
				zone_numeric_id = palette_zone
				x = math.min(MAX_X, math.max(MIN_X, qx))
				z = math.min(MAX_Z, math.max(MIN_Z, qz))
			end
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

		-- Sparse civic-water and hard-footprint indexes follow. Roads are gone
		-- until Round 22 Phase 4 and ordinary inland water until Phase 5; the
		-- civic water inside start and capital cores is the only indexed
		-- hydrology. The indexes hold acceleration data only.
		local hydrology_profile_by_id = {}
		for profile_index = 1, dense_count(source.hydrology_profiles or {},
				"hydrology profiles") do
			local profile = source.hydrology_profiles[profile_index]
			hydrology_profile_by_id[profile.id] = profile
		end
		local hydrology_by_id, hydrology_segments = {}, {}
		for reach_index = 1, #(source.hydrology or {}) do
			local reach = source.hydrology[reach_index]
			local profile = hydrology_profile_by_id[reach.profile_id]
			if reach.civic_core_zone_numeric_id and profile then
				hydrology_by_id[reach.id] = {id = reach.id, order = reach_index,
					profile_id = profile.id, profile_depth = profile.depth}
				local points = reach.centreline
				for segment = 1, #points - 1 do
					local a, b = points[segment], points[segment + 1]
					if a.x ~= b.x or a.z ~= b.z then
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
			end
		end
		local hydrology_index = #hydrology_segments > 0 and
			index128.compile_sparse_segments({
				schema = SPARSE_SCHEMA,
				min_x = MIN_X,
				max_x = MAX_X,
				min_z = MIN_Z,
				max_z = MAX_Z,
				tie_break = "feature_order",
				segments = hydrology_segments,
			}, SPARSE_SCHEMA) or nil
		local hydrology_scalar_scratch
		if planner_source_requested and hydrology_index then
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

		local recipe_by_id = {}
		for recipe_index = 1, #source.hard_protection_recipes do
			local recipe = source.hard_protection_recipes[recipe_index]
			recipe_by_id[recipe.id] = recipe
		end
		-- Hard protection: start and capital cores and apex socket columns. The
		-- capital ingress corridors are retired (D9); their legacy source rows
		-- are skipped.
		local height_hard_by_id = {}
		local height_hard_records = height.hard_protection_volumes()
		for index = 1, #height_hard_records do
			local row = height_hard_records[index]
			if type(row) == "table" and row.id then height_hard_by_id[row.id] = row end
		end
		local hard_by_id, hard_rows, footprint_records = {}, {}, {}
		for hard_index = 1, #source.hard_protection do
			local source_hard = source.hard_protection[hard_index]
			local recipe = recipe_by_id[source_hard.recipe_id]
			if not recipe then fail("hard recipe missing") end
			if recipe.shape ~= "polyline_corridor" then
				local height_hard = height_hard_by_id[source_hard.id]
				if type(height_hard) ~= "table" or
						not source_subset_matches(source_hard, height_hard) or
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
				if hard_by_id[internal.id] then fail("duplicate hard footprint id") end
				hard_rows[#hard_rows + 1] = internal
				hard_by_id[internal.id] = internal
				footprint_records[#footprint_records + 1] = {id = internal.id, bbox = bbox}
			end
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
			elseif row.shape == "exact_column" then
				return x == row.center.x and z == row.center.z
			end
			fail("unknown hard footprint at query")
		end

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
			local water_class, _, owner = classification_values(x, z, outside)
			return surface_level_from_classification(x, z, water_class, owner)
		end

		function session.mob_level_at(position)
			local x, y, z, outside = normalize_position(position, "mob-level query")
			local water_class, _, owner = classification_values(x, z, outside)
			if water_class == "deep_ocean" or
					water_class == "immutable_dragon_channel" then return nil end
			local surface = surface_level_from_classification(x, z, water_class, owner)
			if y >= 0 then return surface end
			local depth = depth_level(y)
			if surface and surface > depth then return surface end
			return depth
		end

		function session.guard_level_at(position)
			local x, y, z, outside = normalize_position(position,
				"guard-level query")
			local water_class, _, owner = classification_values(x, z, outside)
			if water_class ~= "land" and water_class ~= "planned_water" then
				return nil
			end
			if capital_member(x, y, z) then return 60 end
			local surface = surface_level_from_classification(x, z, water_class, owner)
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
			elseif territory == "contested_land" then
				return false
			end
			fail("unknown protection territory result")
		end
		session.compatibility = compatibility

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
			}
		end

		local planner_source
		if planner_source_requested then
			planner_source = {
				schema = "grug_wp40_r5_planner_source_v1",
			}
			local column_cache_limit = 65536
			local column_cache_by_x = runtime_mode and {} or nil
			local column_cache_slot_x = runtime_mode and {} or nil
			local column_cache_slot_z = runtime_mode and {} or nil
			local column_cache_rows = runtime_mode and {} or nil
			local column_cache_count = 0
			local column_cache_next_slot = 1
			local column_cache_hits, column_cache_misses,
				column_cache_evictions = 0, 0, 0

			local function compute_column_values_at(x, z, outside)
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
				-- Ordinary wet columns publish the actual authored bed depth. Named
				-- transitions and raised functional crossings retain the fixed profile
				-- depth consumed by their seal and clearance contracts.
				if classified_hydrology_id ~= nil and transition_kind == nil and
						functional_kind == nil and
						water_y ~= nil and water_y > terrain_y then
					classified_profile_depth = water_y - terrain_y
				end
				local hard_foundation = hard_row_at(x, terrain_y, z) ~= nil
				return water_class, zone_numeric_id, zone_id, logical_biome_id,
					race_region_id, terrain_y, water_y, classified_hydrology_id,
					classified_profile_depth, functional_kind, functional_y,
					functional_feature_id, functional_interface_id, transition_kind,
					transition_interface_id, transition_upper_y, transition_lower_y,
					transition_progress_q, transition_face_mask, hard_foundation
			end

			function planner_source.column_values_at(x, z)
				local outside
				x, z, outside = normalize_xz(x, z, "planner column query")
				if not runtime_mode then
					return compute_column_values_at(x, z, outside)
				end

				local bucket = column_cache_by_x[x]
				local row = bucket and bucket[z] or nil
				if row then
					column_cache_hits = column_cache_hits + 1
					return unpack(row, 1, 20)
				end
				column_cache_misses = column_cache_misses + 1
				local value_1, value_2, value_3, value_4, value_5,
					value_6, value_7, value_8, value_9, value_10,
					value_11, value_12, value_13, value_14, value_15,
					value_16, value_17, value_18, value_19, value_20 =
						compute_column_values_at(x, z, outside)

				local slot
				if column_cache_count < column_cache_limit then
					column_cache_count = column_cache_count + 1
					slot = column_cache_count
					row = {}
					column_cache_rows[slot] = row
				else
					column_cache_evictions = column_cache_evictions + 1
					slot = column_cache_next_slot
					column_cache_next_slot = column_cache_next_slot + 1
					if column_cache_next_slot > column_cache_limit then
						column_cache_next_slot = 1
					end
					local old_x = column_cache_slot_x[slot]
					local old_z = column_cache_slot_z[slot]
					local old_bucket = column_cache_by_x[old_x]
					if not old_bucket or old_bucket[old_z] ~= column_cache_rows[slot] then
						fail("planner runtime column cache differs")
					end
					old_bucket[old_z] = nil
					old_bucket._count = old_bucket._count - 1
					if old_bucket._count == 0 then column_cache_by_x[old_x] = nil end
					row = column_cache_rows[slot]
				end

				row[1], row[2], row[3], row[4], row[5] =
					value_1, value_2, value_3, value_4, value_5
				row[6], row[7], row[8], row[9], row[10] =
					value_6, value_7, value_8, value_9, value_10
				row[11], row[12], row[13], row[14], row[15] =
					value_11, value_12, value_13, value_14, value_15
				row[16], row[17], row[18], row[19], row[20] =
					value_16, value_17, value_18, value_19, value_20
				bucket = column_cache_by_x[x]
				if not bucket then
					bucket = {_count = 0}
					column_cache_by_x[x] = bucket
				end
				if bucket[z] ~= nil then fail("planner runtime column cache collision") end
				bucket[z] = row
				bucket._count = bucket._count + 1
				column_cache_slot_x[slot] = x
				column_cache_slot_z[slot] = z
				return unpack(row, 1, 20)
			end

			function planner_source.hydrology_metric_values_at(x, z)
				local outside
				x, z, outside = normalize_xz(x, z, "planner hydrology metric query")
				if outside or not hydrology_index then return nil, nil, nil, nil end
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

			local surface_caves = new_surface_cave_factory({
				full_seed_string = full_seed_string,
				column_values_at = planner_source.column_values_at,
				static_exclusion_values_at = horizontal.static_exclusion_values_at,
				housing_mask_id_at = horizontal.housing_mask_id_at,
			})
			function planner_source.surface_cave_run_at(x, z)
				return surface_caves.run_at(x, z)
			end
			function planner_source.surface_cave_candidate_at_cell(cell_x, cell_z)
				return surface_caves.candidate_record_at_cell(cell_x, cell_z)
			end
			function planner_source.surface_cave_cell_at(x, z)
				return surface_caves.cell_at(x, z)
			end
			function planner_source.surface_cave_constants()
				return surface_caves.constants()
			end
			function planner_source.coast_material_at(x, z)
				return height.coast_material_at(x, z)
			end
			function planner_source.primary_relief_at(x, z)
				local _, _, owner = horizontal.classification_values_at(x, z)
				return owner and source.zones[owner].primary_relief_id or nil
			end
			function planner_source.landmark_excluded_at(x, z)
				return height.landmark_excluded_at(x, z)
			end
			-- Narrow read-only runtime bridge. These are the same geometry owners the
			-- planner and writer consume; ecology must not reconstruct their shapes.
			function planner_source.static_exclusion_values_at(x, z)
				return horizontal.static_exclusion_values_at(x, z)
			end
			function planner_source.housing_mask_id_at(x, z)
				return horizontal.housing_mask_id_at(x, z)
			end
			function planner_source.functional_surface_values_at(x, z)
				return height.functional_surface_values_at(x, z)
			end
			function planner_source.hard_row_at(x, y, z)
				return hard_row_at(x, y, z)
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
					runtime_column_cache_limit = runtime_mode and
						column_cache_limit or 0,
					runtime_column_cache_entries = column_cache_count,
					runtime_column_cache_hits = column_cache_hits,
					runtime_column_cache_misses = column_cache_misses,
					runtime_column_cache_evictions = column_cache_evictions,
				}
			end
			planner_source_count = planner_source_count + 1
		end

		construction_complete = true
		return session, planner_source
	end

	function module.new(full_seed_string, configured_water_level)
		local session = construct(full_seed_string, configured_water_level, false,
			nil)
		return session
	end

	function module.new_runtime(full_seed_string, configured_water_level)
		local session = construct(full_seed_string, configured_water_level, false,
			true)
		return session
	end

	function module.new_with_planner_source(full_seed_string,
			configured_water_level)
		return construct(full_seed_string, configured_water_level, true, nil)
	end

	function module.new_with_planner_source_runtime(full_seed_string,
			configured_water_level)
		return construct(full_seed_string, configured_water_level, true, true)
	end

	return module
end

return zones_factory, new_surface_cave_factory
