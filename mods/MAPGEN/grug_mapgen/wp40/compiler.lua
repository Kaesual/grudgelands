-- Trusted entrypoint for compiling the immutable WP40 world dataset. The
-- geometry implementation is deliberately a fixed-path dependency. Until the
-- later T2 geometry slices install it, compilation fails closed.

local engine_core = rawget(_G, "core")
local captured_dofile = dofile
local captured_select = select
local production = engine_core ~= nil
local captured_get_modpath = production and engine_core.get_modpath or nil
local captured_sha256 = production and engine_core.sha256 or nil

local function fail(message)
	error("WP40 compiler: " .. message, 0)
end

local function exact_dependency_fields(value)
	local allowed = {
		raw_sha256 = true, canonical = true, deterministic = true,
		validation = true, schemas = true, source = true,
		source_validator = true,
	}
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("offline dependencies are not a plain table")
	end
	for key in pairs(value) do
		if not allowed[key] then
			fail("offline dependencies contain unknown field " .. tostring(key))
		end
	end
	if type(value.raw_sha256) ~= "function" then
		fail("offline raw SHA-256 dependency missing")
	end
end

return function(offline_directory)
	local directory
	if production then
		if type(captured_get_modpath) ~= "function" or
				type(captured_sha256) ~= "function" then
			fail("captured engine APIs are unavailable")
		end
		local modpath = captured_get_modpath("grug_mapgen")
		if type(modpath) ~= "string" or modpath == "" then
			fail("captured grug_mapgen path is unavailable")
		end
		directory = modpath .. "/wp40"
	else
		if type(offline_directory) ~= "string" or offline_directory == "" then
			fail("offline foundation directory missing")
		end
		directory = offline_directory
	end

	-- Every production authority is loaded from a fixed project path and
	-- captured as a local. No caller can replace one through compile().
	local bindings = {
		canonical = captured_dofile(directory .. "/canonical.lua"),
		deterministic = captured_dofile(directory .. "/deterministic.lua"),
		validation = captured_dofile(directory .. "/validation.lua"),
		schemas = captured_dofile(directory .. "/schemas.lua"),
		source = captured_dofile(directory .. "/source/catalog.lua"),
		source_validator = captured_dofile(directory ..
			"/validation/t2_source.lua"),
	}
	if production then
		bindings.raw_sha256 = function(data)
			return captured_sha256(data, true)
		end
	end
	local schema_module = captured_dofile(directory .. "/compiled_schema.lua")
	local canonicalize_compiled = schema_module.canonicalize_compiled
	if type(canonicalize_compiled) ~= "function" then
		fail("compiled canonicalizer is unavailable")
	end

	local geometry_impl
	local impl_ok, impl_result = pcall(captured_dofile,
		directory .. "/geometry/compiler_impl.lua")
	if impl_ok then
		if type(impl_result) ~= "table" or
				type(impl_result.compile) ~= "function" then
			fail("fixed geometry compiler has an invalid module contract")
		end
		geometry_impl = impl_result.compile
	elseif not tostring(impl_result):find("No such file or directory", 1, true) then
		fail("fixed geometry compiler failed to load: " .. tostring(impl_result))
	end

	local function compile_impl(active_bindings, full_seed_string,
			wp43_vocabulary)
		active_bindings.deterministic.validate_seed(full_seed_string)
		if type(wp43_vocabulary) ~= "table" or
				getmetatable(wp43_vocabulary) ~= nil then
			fail("WP43 vocabulary is not a plain table")
		end
		-- Exercise the real captured trust chain before geometry can become ready:
		-- fixed source, fixed Stage-1 validator, private raw SHA closure, and the
		-- exact canonicalizer that Stage 3 will later receive. This returns no
		-- compiled graph and exposes no production probe.
		local stage1 = active_bindings.source_validator
		if type(stage1.new_offline_test_adapter) == "function" then
			stage1 = stage1.new_offline_test_adapter(active_bindings.canonical,
				active_bindings.raw_sha256)
		end
		local valid, diagnostic = stage1.validate(active_bindings.source,
			wp43_vocabulary)
		if not valid then
			fail("captured Stage-1 trust validation failed: " ..
				tostring(diagnostic and diagnostic.invariant))
		end
		local function empty_record(id)
			return {record_schema = "grug_wp40_trust_record_v1", id = id,
				numeric_id = 0, text_values = {}, signed_values = {},
				unsigned_values = {}, boolean_values = {}, text_arrays = {},
				signed_arrays = {}, unsigned_arrays = {}, candidates = {},
				attributes = {}}
		end
		local geometry = {}
		local geometry_names = {"zones", "land_boundaries", "land_routes",
			"boat_routes", "perimeters", "bays", "mouth_apertures",
			"closure_wings", "dry_faces", "relief_fields", "templates",
			"anchors", "route_profiles", "hydrology", "coast_shelf",
			"islands", "channels", "hard_protection", "claim_exclusions",
			"housing_masks"}
		for i = 1, #geometry_names do geometry[geometry_names[i]] = {} end
		local trust_data = {
			schema = active_bindings.schemas.compiled,
			algorithm_schema = active_bindings.schemas.compiled_algorithm,
			full_seed = full_seed_string,
			geometry = geometry,
			selectors = {logical_biomes = {}, nearest_features = {},
				housing_centers = {}},
			spatial_index = {schema = active_bindings.schemas.index,
				cell_size = 128, min_cx = 0, max_cx = 0, min_cz = 0, max_cz = 0,
				layers = {}, candidates = {}, attributes = {}},
			coverage = {schema = active_bindings.schemas.coverage,
				geometry_volumes = {}, resolver_interfaces = {},
				pending = {t4 = {}, t6 = {}, t7 = {}}},
			release_fixtures = {seed_corpus = {}, extreme_slots = {},
				staging_seed = empty_record("trust_staging"),
				microcorpus_classes_1_9 = {},
				requester_trace = empty_record("trust_trace")},
		}
		local projected = canonicalize_compiled(trust_data, {},
			active_bindings.canonical)
		active_bindings.canonical.checksum(projected,
			active_bindings.raw_sha256)
		if geometry_impl == nil then fail("compiled_geometry_unavailable") end
		return geometry_impl(active_bindings, full_seed_string, wp43_vocabulary,
			canonicalize_compiled)
	end

	local compiler = {
		compile = false,
	}

	function compiler.compile(...)
		if captured_select("#", ...) ~= 2 then
			fail("compile requires exactly full_seed_string and wp43_vocabulary")
		end
		if not production then
			fail("production compile is unavailable outside the engine")
		end
		local full_seed_string, wp43_vocabulary = ...
		return compile_impl(bindings, full_seed_string, wp43_vocabulary)
	end

	-- The adapter is created only in an engine-free module instance. It captures
	-- an audited offline SHA seam and optional audited module/source overrides,
	-- then enters the same private compile_impl. It is never a production export.
	if not production then
		function compiler.new_offline_test_adapter(dependencies)
			exact_dependency_fields(dependencies)
			local offline = {
				raw_sha256 = dependencies.raw_sha256,
				canonical = dependencies.canonical or bindings.canonical,
				deterministic = dependencies.deterministic or bindings.deterministic,
				validation = dependencies.validation or bindings.validation,
				schemas = dependencies.schemas or bindings.schemas,
				source = dependencies.source or bindings.source,
				source_validator = dependencies.source_validator or
					bindings.source_validator,
			}
			local adapter = {}
			function adapter.compile(...)
				if captured_select("#", ...) ~= 2 then
					fail("compile requires exactly full_seed_string and wp43_vocabulary")
				end
				local full_seed_string, wp43_vocabulary = ...
				return compile_impl(offline, full_seed_string, wp43_vocabulary)
			end
			return adapter
		end
	end

	return compiler
end
