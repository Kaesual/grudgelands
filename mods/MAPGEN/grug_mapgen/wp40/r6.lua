-- Internal, disabled WP40 R6 construction boundary. R7 owns activation.

return function(dependencies)
	if type(dependencies) ~= "table" then error("WP40 R6 dependencies missing", 0) end
	local ALLOWED = {
		r5_factory = true, zones_factory = true, r5_planner_factory = true,
		r5_adapter_factory = true, manifest_module = true, allocator_factory = true,
		source = true, schemas = true, canonical = true, deterministic = true,
		index128 = true, horizontal_factory = true, height_factory = true,
		terrain_field = true,
		raw_sha256 = true, hash_factory = true, content_factory = true,
		templates_factory = true, planner_factory = true, settlement_factory = true,
		habitat = true,
	}
	for key in pairs(dependencies) do
		if not ALLOWED[key] then
			error("WP40 R6 unexpected dependency " .. tostring(key), 0)
		end
	end
	for key in pairs(ALLOWED) do
		if dependencies[key] == nil then
			error("WP40 R6 dependency missing: " .. key, 0)
		end
	end
	local STATUS = "disabled_r6_surface_resource_content"
	local MAX_SAFE = 9007199254740991

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail("fail_manifest", label .. " is not an exact bounded integer")
		end
		return value
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail("fail_status", label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then
				fail("fail_status", label .. " has unexpected field " .. tostring(key))
			end
		end
		for key in pairs(allowed) do
			if value[key] == nil then
				fail("fail_status", label .. " is missing " .. key)
			end
		end
		return value
	end

	if type(dependencies.raw_sha256) ~= "function" or
			type(dependencies.hash_factory) ~= "function" or
			type(dependencies.content_factory) ~= "function" or
			type(dependencies.templates_factory) ~= "function" or
			type(dependencies.planner_factory) ~= "table" or
			type(dependencies.planner_factory.new) ~= "function" or
			type(dependencies.settlement_factory) ~= "table" or
			type(dependencies.settlement_factory.new) ~= "function" or
			type(dependencies.r5_factory) ~= "function" then
		fail("fail_status", "module factory seam differs")
	end

	local hash = dependencies.hash_factory(dependencies.raw_sha256)

	local r5_module = dependencies.r5_factory({
		zones_factory = dependencies.zones_factory,
		planner_factory = dependencies.r5_planner_factory,
		adapter_factory = dependencies.r5_adapter_factory,
		manifest_module = dependencies.manifest_module,
		allocator_factory = dependencies.allocator_factory,
		source = dependencies.source, schemas = dependencies.schemas,
		canonical = dependencies.canonical,
		deterministic = dependencies.deterministic,
		index128 = dependencies.index128,
		horizontal_factory = dependencies.horizontal_factory,
		height_factory = dependencies.height_factory,
		terrain_field = dependencies.terrain_field,
		raw_sha256 = dependencies.raw_sha256,
	})

	local module = {}
	function module.status() return STATUS end
	local function new_impl(construction_mode, full_seed_string, configured_water_level,
			manifest_values,
			content_contract, mapgen_context, wp43_projection, template_source,
			successor_config)
		if type(full_seed_string) ~= "string" or full_seed_string == "" then
			fail("fail_hash", "full seed string differs")
		end
		integer(configured_water_level, "configured water level", -31000, 31000)
		if configured_water_level ~= 1 then fail("fail_manifest", "water level differs") end
		local content_module = dependencies.content_factory(manifest_values,
			content_contract, wp43_projection, dependencies.habitat)
		local templates_module = dependencies.templates_factory(hash, content_module,
			template_source)
		if construction_mode == "authority" then
			if type(r5_module.new_source_runtime) ~= "function" then
				fail("fail_status", "R5 source-only runtime constructor is absent")
			end
			local zones_session, planner_source = r5_module.new_source_runtime(
				full_seed_string, configured_water_level,
				content_module.r5_manifest_values())
			-- Read-only decoration cover by node name for runtime vegetation
			-- renewal (vegetation_density.lua): the per-support factor the
			-- planner budgets each decoration with, 0 where the node is no host.
			local support_names = {}
			for index = 1, #content_contract.content_names do
				support_names[index] = content_contract.content_names[index]
			end
			return zones_session, {
				schema = "grug_wp40_r6_authority_identity_v1",
				template_records = templates_module.records(),
				planner_source = planner_source,
				-- The vegetation and altitude rule the emerge planner and
				-- surface selector use (habitat_registry.lua), for renewal.
				vegetation_rule = content_module.vegetation_rule(full_seed_string,
					planner_source),
				decoration_support_names = support_names,
				decoration_cover = function(id, biome, support_name)
					local ref = content_module.content_ref(support_name)
					return ref and content_module.decoration_cover(id, biome, ref) or 0
				end,
			}
		end

		local runtime_mode = construction_mode == "runtime"
		local r5_constructor
		if runtime_mode then
			r5_constructor = r5_module.new_runtime
		else
			r5_constructor = r5_module.new
		end
		if type(r5_constructor) ~= "function" then
			fail("fail_status", "R5 runtime constructor is absent")
		end
		local zones_session, planner_source, r5_planner, r5_adapter = r5_constructor(
			full_seed_string, configured_water_level,
			content_module.r5_manifest_values(), content_contract.r5, mapgen_context,
			runtime_mode and content_contract.classify_runtime or nil)
		local horizontal_module = dependencies.horizontal_factory({
			source = dependencies.source, schemas = dependencies.schemas,
			canonical = dependencies.canonical,
			deterministic = dependencies.deterministic,
			raw_sha256 = dependencies.raw_sha256,
		})
		local horizontal = horizontal_module.new(full_seed_string)
		local identity_holder = {value = false}
		local planner_allocator = dependencies.allocator_factory.new(
			"grug_wp40_r6_planner_allocator_v1")
		local settlement_allocator = dependencies.allocator_factory.new(
			"grug_wp40_r6_settlement_allocator_v1")
		local evidence_only = construction_mode == "horizontal"
		local capture_enabled = construction_mode == "capture"
		if construction_mode ~= nil and not evidence_only and not capture_enabled and
				not runtime_mode then
			fail("fail_status", "private construction mode differs")
		end
		local planner_constructor
		if evidence_only then
			planner_constructor = dependencies.planner_factory.new_evidence
		elseif runtime_mode then
			planner_constructor = dependencies.planner_factory.new_runtime
		else
			planner_constructor = dependencies.planner_factory.new
		end
		if type(planner_constructor) ~= "function" then
			fail("fail_status", "R6 planner construction mode is absent")
		end
		local planner, planner_fixture = planner_constructor({
			full_seed_string = full_seed_string, planner_source = planner_source,
			r5_planner = r5_planner, horizontal = horizontal,
			content = content_module, hash = hash,
			source = dependencies.source, construction_identity = identity_holder,
			counting_allocator = planner_allocator,
		})
		local successor_tail
		if successor_config ~= nil then
			exact_fields(successor_config, {schema = true, new = true},
				"successor configuration")
			if successor_config.schema ~= "grug_wp40_r7_successor_config_v1" or
					type(successor_config.new) ~= "function" then
				fail("fail_status", "successor configuration differs")
			end
			successor_tail = successor_config.new({
				full_seed_string = full_seed_string, hash = hash,
				raw_sha256 = dependencies.raw_sha256,
				planner_source = planner_source, horizontal = horizontal,
				zones_session = zones_session,
				content = content_module, source = dependencies.source,
				construction_identity = identity_holder,
				runtime_mode = runtime_mode == true,
			})
			if type(successor_tail) ~= "table" or
					type(successor_tail.plan_slice) ~= "function" or
					type(successor_tail.settle) ~= "function" or
					type(successor_tail.metrics) ~= "function" then
				fail("fail_status", "successor tail seam differs")
			end
		end
		local settlement_dependencies = {
			full_seed_string = full_seed_string, r5_adapter = r5_adapter,
			content = content_module, templates = templates_module, hash = hash,
			horizontal = horizontal, planner_source = planner_source,
			construction_identity = identity_holder,
			source = dependencies.source, counting_allocator = settlement_allocator,
			planner_stable_refs = planner_fixture.stable_refs(),
		}
		if successor_tail then settlement_dependencies.successor_tail = successor_tail end
		local settlement_constructor
		if evidence_only then
			settlement_constructor = dependencies.settlement_factory.new_evidence
		elseif capture_enabled then
			settlement_constructor = dependencies.settlement_factory.new_capture
		elseif runtime_mode then
			settlement_constructor = dependencies.settlement_factory.new_runtime
		else
			settlement_constructor = dependencies.settlement_factory.new
		end
		if type(settlement_constructor) ~= "function" then
			fail("fail_status", "settlement construction mode is absent")
		end
		local settlement, settlement_fixture = settlement_constructor(settlement_dependencies)
		local direct_evidence_fixture
		if evidence_only and successor_tail then
			local direct_allocator = dependencies.allocator_factory.new(
				"grug_wp40_r6_settlement_allocator_v1")
			local direct_dependencies = {
				full_seed_string = full_seed_string, r5_adapter = r5_adapter,
				content = content_module, templates = templates_module, hash = hash,
				horizontal = horizontal, planner_source = planner_source,
				construction_identity = identity_holder,
				source = dependencies.source, counting_allocator = direct_allocator,
				planner_stable_refs = planner_fixture.stable_refs(),
			}
			local _
			_, direct_evidence_fixture =
				dependencies.settlement_factory.new_evidence(direct_dependencies)
		end
		local session = {}
		function session.plan_slice(minp, maxp)
			local plan, generation = planner:plan_slice(minp, maxp)
			if successor_tail then
				successor_tail:plan_slice(minp, maxp, plan, generation)
			end
			return plan, generation
		end
		function session.metrics()
			local result = {planner = planner:metrics(), settlement = settlement:metrics(),
				r5_planner = r5_planner:metrics(), r5_adapter = r5_adapter:metrics(),
				content = content_contract.metrics()}
			if successor_tail then
				local successor_metrics = successor_tail:metrics()
				if successor_metrics.schema == "grug_wp40_r7_successor_metrics_v1" then
					result.p9g, result.anchors = successor_metrics.p9g,
						successor_metrics.anchors
					result.settlements = {}
					for key, value in pairs(successor_metrics) do
						if type(value) == "table" and value.approach_findings then
							result.settlements[key] = value
						end
					end
				else
					result.p9g = successor_metrics
				end
			end
			return result
		end
		function session.status() return STATUS end
		local writer = {}
		function writer.apply(vm, minp, maxp, plan, generation)
			if not successor_tail then
				fail("fail_status", "production writer lacks R7 successor authority")
			end
			return settlement:apply(vm, minp, maxp, plan, generation, "production")
		end
		-- The fourth result is a private evidence seam. It is deliberately not a
		-- method on the frozen public session and is never published by the loader.
		return session, writer, zones_session, settlement_fixture, {
			schema = "grug_wp40_r6_private_identity_v1",
			template_records = templates_module.records(),
			planner_fixture = planner_fixture, planner_source = planner_source,
			successor_tail = successor_tail,
			direct_evidence_fixture = direct_evidence_fixture,
		}
	end
	function module.new(...)
		return new_impl(nil, ...)
	end
	function module.new_runtime(...)
		return new_impl("runtime", ...)
	end
	function module.new_authority(...)
		return new_impl("authority", ...)
	end
	function module.new_evidence(...)
		return new_impl("horizontal", ...)
	end
	function module.new_capture(...)
		return new_impl("capture", ...)
	end
	return module
end
