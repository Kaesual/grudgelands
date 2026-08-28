-- Internal, disabled WP40 R5 construction boundary. R7 owns activation.

return function(dependencies)
	if type(dependencies) ~= "table" then
		error("WP40 R5 dependencies missing", 0)
	end
	local allowed_dependencies = {
		zones_factory = true,
		planner_factory = true,
		adapter_factory = true,
		manifest_module = true,
		allocator_factory = true,
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
			error("WP40 R5 unexpected dependency " .. tostring(key), 0)
		end
	end
	for key in pairs(allowed_dependencies) do
		if dependencies[key] == nil then
			error("WP40 R5 dependency missing: " .. key, 0)
		end
	end

	local source = dependencies.source
	local schemas = dependencies.schemas
	local allocator_factory = dependencies.allocator_factory
	local manifest_module = dependencies.manifest_module
	local MAX_STABLE_REFS = 512
	local RELATION_SCHEMA = "grug_wp40_r5_relational_lookup_v1"
	local PLANNER_ALLOCATOR_DOMAIN =
		"grug_wp40_r5_planner_allocator_v1"
	local ADAPTER_ALLOCATOR_DOMAIN =
		"grug_wp40_r5_adapter_allocator_v1"

	local function fail(message)
		error("WP40 R5 fail_status: " .. message, 0)
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
				fail(label .. " is not dense")
			end
		end
		return count
	end

	local function exact_fields(values, allowed, label)
		if type(values) ~= "table" then fail(label .. " is not a table") end
		for key in pairs(values) do
			if not allowed[key] then
				fail(label .. " has unexpected field " .. tostring(key))
			end
		end
		for key in pairs(allowed) do
			if values[key] == nil then fail(label .. " is missing " .. key) end
		end
		return values
	end

	local function text(value, label)
		if type(value) ~= "string" or value == "" then
			fail(label .. " is not non-empty text")
		end
		return value
	end

	if type(source) ~= "table" or
			source.schema ~= "grug_wp40_simple_map_source_v2" or
			source.layout_id ~= "wp40-simple-map-v1d" or
			source.layout_revision_id ~= "wp40-simple-map-v1e" or
			type(schemas) ~= "table" or
			schemas.simple_map ~= "grug_wp40_simple_map_v1" then
		fail("source authority differs")
	end
	if type(dependencies.zones_factory) ~= "function" or
			type(dependencies.planner_factory) ~= "function" or
			type(dependencies.adapter_factory) ~= "function" or
			type(manifest_module) ~= "table" or
			type(allocator_factory) ~= "table" or
			type(allocator_factory.new) ~= "function" then
		fail("module factory seam differs")
	end
	exact_fields(manifest_module, {validate = true, canonical_bytes = true},
		"manifest module")
	exact_fields(allocator_factory, {new = true}, "allocator factory")
	if type(manifest_module.validate) ~= "function" or
			type(manifest_module.canonical_bytes) ~= "function" then
		fail("manifest module API differs")
	end
	local manifest_validate = manifest_module.validate
	local allocator_new = allocator_factory.new

	local zones_module = dependencies.zones_factory({
		source = source,
		schemas = schemas,
		canonical = dependencies.canonical,
		deterministic = dependencies.deterministic,
		index128 = dependencies.index128,
		horizontal_factory = dependencies.horizontal_factory,
		height_factory = dependencies.height_factory,
		raw_sha256 = dependencies.raw_sha256,
	})
	local planner_module = dependencies.planner_factory(allocator_factory)
	local adapter_module = dependencies.adapter_factory(allocator_factory)
	exact_fields(planner_module, {new = true}, "planner module")
	exact_fields(adapter_module, {new = true}, "adapter module")
	if type(zones_module) ~= "table" or
			type(zones_module.new) ~= "function" or
			type(zones_module.new_with_planner_source) ~= "function" then
		fail("zones private seam differs")
	end

	local function find_hydrology_ordinal(id)
		for index = 1, #source.hydrology do
			if source.hydrology[index].id == id then return index end
		end
		return nil
	end

	local function find_profile(id)
		for index = 1, #source.hydrology_profiles do
			local profile = source.hydrology_profiles[index]
			if profile.id == id then return profile end
		end
		return nil
	end

	local function find_transition_profile(id)
		for index = 1, #source.hydrology_transition_profiles do
			local profile = source.hydrology_transition_profiles[index]
			if profile.id == id then return profile end
		end
		return nil
	end

	local function find_route(id)
		for index = 1, #source.routes do
			if source.routes[index].id == id then return source.routes[index] end
		end
		return nil
	end

	local function find_crossing(id)
		local found
		for index = 1, #source.crossing_interfaces do
			if source.crossing_interfaces[index].id == id then
				if found ~= nil then fail("crossing interface ID is not unique") end
				found = source.crossing_interfaces[index]
			end
		end
		return found
	end

	local function build_relational_lookup(allocator)
		local stable_refs = allocator:new_array("stable_refs", MAX_STABLE_REFS)
		local stable_ref_count = 0
		local function add_candidate(id, label)
			id = text(id, label)
			for index = 1, stable_ref_count do
				if stable_refs[index] == id then return end
			end
			if stable_ref_count >= MAX_STABLE_REFS then
				fail("stable-reference bound differs")
			end
			allocator:grow(stable_refs, "stable_refs", stable_ref_count,
				stable_ref_count + 1)
			stable_ref_count = stable_ref_count + 1
			stable_refs[stable_ref_count] = id
		end
		for index = 1, #source.routes do
			add_candidate(source.routes[index].id, "route ID")
		end
		for index = 1, #source.poi_spurs do
			add_candidate(source.poi_spurs[index].id, "spur ID")
		end
		for index = 1, #source.island_routes do
			add_candidate(source.island_routes[index].id, "island route ID")
		end
		for index = 1, #source.island_landings do
			add_candidate(source.island_landings[index].id, "island landing ID")
		end
		for index = 1, #source.anchors do
			add_candidate(source.anchors[index].id, "anchor ID")
		end
		for index = 1, #source.coastal_housing_cores do
			add_candidate(source.coastal_housing_cores[index].id, "coastal core ID")
		end
		for index = 1, #source.hydrology do
			add_candidate(source.hydrology[index].id, "hydrology ID")
		end
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			add_candidate(row.id, "hydrology interface ID")
			if row.route_interface_id ~= nil then
				add_candidate(row.route_interface_id, "route interface ID")
			end
		end
		for index = 1, #source.crossing_interfaces do
			local crossing = source.crossing_interfaces[index]
			for previous = 1, index - 1 do
				if source.crossing_interfaces[previous].id == crossing.id then
					fail("crossing interface ID is not unique")
				end
			end
			if not find_route(crossing.route_id) or
					(crossing.kind ~= "bridge" and crossing.kind ~= "ford" and
					crossing.kind ~= "causeway" and crossing.kind ~= "tunnel") then
				fail("crossing interface relation is incomplete")
			end
			add_candidate(crossing.id,
				"crossing interface ID")
		end
		if stable_ref_count < 1 then fail("stable-reference set is empty") end
		-- Canonicalize the exact unique retained prefix without scratch storage.
		for index = 2, stable_ref_count do
			local value = stable_refs[index]
			local cursor = index - 1
			while cursor >= 1 and value < stable_refs[cursor] do
				stable_refs[cursor + 1] = stable_refs[cursor]
				cursor = cursor - 1
			end
			stable_refs[cursor + 1] = value
		end

		local hydrology_count = dense_count(source.hydrology, "hydrology")
		local hydrology_values = allocator:new_array("relation_hydrology_values",
			hydrology_count * 5)
		allocator:grow(hydrology_values, "relation_hydrology_values", 0,
			hydrology_count * 5)
		for index = 1, hydrology_count do
			local hydrology = source.hydrology[index]
			for previous = 1, index - 1 do
				if source.hydrology[previous].id == hydrology.id then
					fail("hydrology ID is not unique")
				end
			end
			local profile = find_profile(hydrology.profile_id)
			if not profile or profile.bed_seal_layers ~= 3 or
					profile.bank_seal_nodes ~= 2 then
				fail("hydrology profile authority differs")
			end
			local base = (index - 1) * 5
			hydrology_values[base + 1] = text(hydrology.id, "hydrology ID")
			hydrology_values[base + 2] =
				text(hydrology.profile_id, "hydrology profile ID")
			hydrology_values[base + 3] = profile.depth
			hydrology_values[base + 4] = profile.bed_seal_layers
			hydrology_values[base + 5] = profile.bank_seal_nodes
		end

		local interface_count = dense_count(source.hydrology_interfaces,
			"hydrology interfaces")
		local member_capacity = 0
		for index = 1, interface_count do
			local row = source.hydrology_interfaces[index]
			for previous = 1, index - 1 do
				local previous_row = source.hydrology_interfaces[previous]
				if previous_row.id == row.id then
					fail("hydrology interface ID is not unique")
				end
				if row.route_interface_id ~= nil and
						previous_row.route_interface_id == row.route_interface_id then
					fail("route interface ID is not unique")
				end
			end
			if not find_transition_profile(row.transition_profile_id) or
					(row.plunge_profile_id ~= nil and
						not find_profile(row.plunge_profile_id)) then
				fail("hydrology interface profile is unknown")
			end
			if row.kind == "bridge" or row.kind == "ford" or
					row.kind == "causeway" then
				local crossing = find_crossing(row.route_interface_id)
				if not crossing or crossing.kind ~= row.kind then
					fail("route interface crossing is unknown or incompatible")
				end
				member_capacity = member_capacity + 1
			elseif row.kind == "rapid" or row.kind == "waterfall" then
				member_capacity = member_capacity + 2
			elseif row.kind == "confluence" then
				if type(row.from_ids) ~= "table" or #row.from_ids < 1 or
						type(row.outgoing_reach_id) ~= "string" then
					fail("confluence relation is incomplete")
				end
				local union_count = 0
				for member_index = 1, #row.from_ids do
					local id = text(row.from_ids[member_index],
						"confluence hydrology ID")
					local duplicate = false
					for previous_index = 1, member_index - 1 do
						if row.from_ids[previous_index] == id then
							duplicate = true
						end
					end
					if not duplicate then union_count = union_count + 1 end
				end
				local outgoing_duplicate = false
				for member_index = 1, #row.from_ids do
					if row.from_ids[member_index] == row.outgoing_reach_id then
						outgoing_duplicate = true
					end
				end
				if not outgoing_duplicate then union_count = union_count + 1 end
				if union_count < 2 then
					fail("confluence relation has too few members")
				end
				member_capacity = member_capacity + union_count
			else
				fail("unknown hydrology interface kind")
			end
		end
		local interface_values = allocator:new_array("relation_interface_values",
			interface_count * 6 + 1)
		local interface_members = allocator:new_array(
			"relation_interface_members", member_capacity)
		allocator:grow(interface_values, "relation_interface_values", 0,
			interface_count * 6 + 1)
		allocator:grow(interface_members, "relation_interface_members", 0,
			member_capacity)

		local member_count = 0
		local current_interface = 0
		local function append_member(hydrology_id)
			local ordinal = find_hydrology_ordinal(hydrology_id)
			if not ordinal then fail("interface references unknown hydrology") end
			local first = interface_values[(current_interface - 1) * 6 + 6]
			for cursor = first, member_count do
				if interface_members[cursor] == ordinal then return end
			end
			member_count = member_count + 1
			interface_members[member_count] = ordinal
		end
		-- Kept outside append_member's contract-visible data; Lua 5.1 closures
		-- capture this scalar without constructing a per-row record.
		for index = 1, interface_count do
			current_interface = index
			local row = source.hydrology_interfaces[index]
			local base = (index - 1) * 6
			interface_values[base + 1] = text(row.id, "interface ID")
			interface_values[base + 2] = text(row.kind, "interface kind")
			interface_values[base + 3] = 0
			interface_values[base + 4] = 0
			interface_values[base + 5] = 0
			interface_values[base + 6] = member_count + 1
			if row.kind == "bridge" or row.kind == "ford" or
					row.kind == "causeway" then
				local ordinal = find_hydrology_ordinal(row.hydrology_id)
				if not ordinal or type(row.route_interface_id) ~= "string" then
					fail("route interface relation is incomplete")
				end
				interface_values[base + 3] = ordinal
				append_member(row.hydrology_id)
			elseif row.kind == "rapid" or row.kind == "waterfall" then
				local upper = find_hydrology_ordinal(row.upper_id)
				local lower = find_hydrology_ordinal(row.lower_id)
				if not upper or not lower or upper == lower then
					fail("transition relation is incomplete")
				end
				interface_values[base + 4] = upper
				interface_values[base + 5] = lower
				append_member(row.upper_id)
				append_member(row.lower_id)
			else
				if type(row.from_ids) ~= "table" or #row.from_ids < 1 or
						type(row.outgoing_reach_id) ~= "string" then
					fail("confluence relation is incomplete")
				end
				for from_index = 1, #row.from_ids do
					append_member(row.from_ids[from_index])
				end
				append_member(row.outgoing_reach_id)
			end
			-- Canonicalize the current member interval by hydrology ID bytes.
			local first = interface_values[base + 6]
			for cursor = first + 1, member_count do
				local ordinal = interface_members[cursor]
				local scan = cursor - 1
				while scan >= first and
						hydrology_values[(ordinal - 1) * 5 + 1] <
							hydrology_values[(interface_members[scan] - 1) * 5 + 1] do
					interface_members[scan + 1] = interface_members[scan]
					scan = scan - 1
				end
				interface_members[scan + 1] = ordinal
			end
		end
		interface_values[interface_count * 6 + 1] = member_count + 1
		if member_count ~= member_capacity then
			fail("relation member population differs")
		end

		local lookup = allocator:new_map("relational_lookup",
			15 + stable_ref_count)
		allocator:map_put(lookup, "relational_lookup", "schema", RELATION_SCHEMA)
		allocator:map_put(lookup, "relational_lookup", "allocator_identity",
			allocator)
		allocator:map_put(lookup, "relational_lookup", "stable_refs", stable_refs)
		allocator:map_put(lookup, "relational_lookup", "hydrology_ids",
			hydrology_values)
		allocator:map_put(lookup, "relational_lookup", "hydrology_profile_ids",
			hydrology_values)
		allocator:map_put(lookup, "relational_lookup", "hydrology_depths",
			hydrology_values)
		allocator:map_put(lookup, "relational_lookup",
			"hydrology_bed_seal_layers", hydrology_values)
		allocator:map_put(lookup, "relational_lookup",
			"hydrology_bank_seal_nodes", hydrology_values)
		allocator:map_put(lookup, "relational_lookup", "interface_ids",
			interface_values)
		allocator:map_put(lookup, "relational_lookup", "interface_kinds",
			interface_values)
		allocator:map_put(lookup, "relational_lookup",
			"interface_hydrology_ordinals", interface_values)
		allocator:map_put(lookup, "relational_lookup",
			"interface_upper_ordinals", interface_values)
		allocator:map_put(lookup, "relational_lookup",
			"interface_lower_ordinals", interface_values)
		allocator:map_put(lookup, "relational_lookup", "interface_member_start",
			interface_values)
		allocator:map_put(lookup, "relational_lookup", "interface_members",
			interface_members)
		local LOOKUP_BASE = 513
		for stable_index = 1, stable_ref_count do
			local id = stable_refs[stable_index]
			local hydrology_ordinal = find_hydrology_ordinal(id) or 0
			local interface_ordinal = 0
			local route_interface_ordinal = 0
			for index = 1, interface_count do
				local row = source.hydrology_interfaces[index]
				if row.id == id then interface_ordinal = index end
				if row.route_interface_id == id then
					if route_interface_ordinal ~= 0 then
						fail("route interface ID is not unique")
					end
					route_interface_ordinal = index
				end
			end
			local packed = stable_index + LOOKUP_BASE * hydrology_ordinal +
				LOOKUP_BASE * LOOKUP_BASE * interface_ordinal +
				LOOKUP_BASE * LOOKUP_BASE * LOOKUP_BASE *
					route_interface_ordinal
			allocator:map_put(lookup, "relational_lookup", id, packed)
		end
		return lookup
	end

	local module = {}

	function module.status()
		return {
			schema = "grug_wp40_simple_map_r5_status_v1",
			planner_available = true,
			adapter_available = true,
			production_enabled = false,
			callback_registered = false,
			disabled_reason =
				"WP40 R5 planner and adapter are internal and disabled until R7",
		}
	end

	function module.new(full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context)
		if content_contract == nil then fail("content contract missing") end
		if mapgen_context == nil then fail("mapgen context missing") end
		local manifest = manifest_validate(manifest_values)
		local planner_allocator = allocator_new(PLANNER_ALLOCATOR_DOMAIN)
		local adapter_allocator = allocator_new(ADAPTER_ALLOCATOR_DOMAIN)
		local session, planner_source = zones_module.new_with_planner_source(
			full_seed_string, configured_water_level)
		local relational_lookup = build_relational_lookup(planner_allocator)
		local plan_identity = planner_allocator:new_map("plan_identity", 0)
		local planner = planner_module.new(planner_source, manifest,
			relational_lookup, planner_allocator, plan_identity)
		local adapter = adapter_module.new(manifest, content_contract,
			mapgen_context, adapter_allocator, plan_identity)
		planner_allocator:seal_construction()
		adapter_allocator:seal_construction()
		return session, planner_source, planner, adapter
	end

	return module
end
