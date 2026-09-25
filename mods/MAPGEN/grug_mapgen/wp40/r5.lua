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
		terrain_field = true,
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
	local LOOKUP_SCHEMA = "grug_wp40_r5_feature_lookup_v2"
	local PLANNER_ALLOCATOR_DOMAIN =
		"grug_wp40_r5_planner_allocator_v1"
	local ADAPTER_ALLOCATOR_DOMAIN =
		"grug_wp40_r5_adapter_allocator_v1"

	local function fail(message)
		error("WP40 R5 fail_status: " .. message, 0)
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
		terrain_field = dependencies.terrain_field,
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

	-- The feature IDs the planner interns: the anchor fittings, the only
	-- functional features the vertical model publishes. Any other feature or
	-- interface ID (Phase 4 roads, Phase 5 rivers) maps to ordinal 0 in the
	-- plan; nothing about water or roads has to be registered here.
	local function build_feature_lookup(allocator)
		local count = #source.anchors
		if count < 1 or count > MAX_STABLE_REFS then
			fail("anchor feature population differs")
		end
		local stable_refs = allocator:new_array("stable_refs", MAX_STABLE_REFS)
		allocator:grow(stable_refs, "stable_refs", 0, count)
		for index = 1, count do
			stable_refs[index] = text(source.anchors[index].id, "anchor ID")
		end
		table.sort(stable_refs)
		for index = 2, count do
			if stable_refs[index - 1] == stable_refs[index] then
				fail("anchor ID is not unique")
			end
		end
		local lookup = allocator:new_map("feature_lookup", 3 + count)
		allocator:map_put(lookup, "feature_lookup", "schema", LOOKUP_SCHEMA)
		allocator:map_put(lookup, "feature_lookup", "allocator_identity", allocator)
		allocator:map_put(lookup, "feature_lookup", "stable_refs", stable_refs)
		for index = 1, count do
			allocator:map_put(lookup, "feature_lookup", stable_refs[index], index)
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

	local function new_impl(runtime_mode, full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context, trusted_classify)
		if content_contract == nil then fail("content contract missing") end
		if mapgen_context == nil then fail("mapgen context missing") end
		local manifest = manifest_validate(manifest_values)
		local planner_allocator = allocator_new(PLANNER_ALLOCATOR_DOMAIN)
		local adapter_allocator = allocator_new(ADAPTER_ALLOCATOR_DOMAIN)
		local zones_constructor = zones_module.new_with_planner_source
		if runtime_mode then
			zones_constructor = zones_module.new_with_planner_source_runtime
			if type(zones_constructor) ~= "function" then
				fail("runtime zones constructor missing")
			end
		end
		local session, planner_source = zones_constructor(full_seed_string,
			configured_water_level)
		local feature_lookup = build_feature_lookup(planner_allocator)
		local plan_identity = planner_allocator:new_map("plan_identity", 0)
		local planner = planner_module.new(planner_source, manifest,
			feature_lookup, planner_allocator, plan_identity)
		local adapter = adapter_module.new(manifest, content_contract,
			mapgen_context, adapter_allocator, plan_identity,
			runtime_mode and trusted_classify or nil)
		planner_allocator:seal_construction()
		adapter_allocator:seal_construction()
		return session, planner_source, planner, adapter
	end

	function module.new(full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context)
		return new_impl(false, full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context)
	end

	function module.new_runtime(full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context, trusted_classify)
		return new_impl(true, full_seed_string, configured_water_level,
			manifest_values, content_contract, mapgen_context, trusted_classify)
	end

	function module.new_source_runtime(full_seed_string, configured_water_level,
			manifest_values)
		manifest_validate(manifest_values)
		if type(zones_module.new_with_planner_source_runtime) ~= "function" then
			fail("runtime zones constructor missing")
		end
		return zones_module.new_with_planner_source_runtime(full_seed_string,
			configured_water_level)
	end

	return module
end
