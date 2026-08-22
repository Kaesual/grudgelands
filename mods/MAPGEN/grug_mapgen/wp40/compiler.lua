-- Trusted entrypoint for compiling the immutable WP40 world dataset. The
-- geometry implementation is deliberately a fixed-path dependency. Until the
-- later T2 geometry slices install it, compilation fails closed.

local engine_core = rawget(_G, "core")
local captured_dofile = dofile
local captured_select = select
local captured_io = rawget(_G, "io")
local captured_io_open
if type(captured_io) == "table" then
	captured_io_open = captured_io.open
end
local production = engine_core ~= nil
local captured_get_modpath = production and engine_core.get_modpath or nil
local captured_sha256 = production and engine_core.sha256 or nil

local function fail(message)
	error("WP40 compiler: " .. message, 0)
end

-- io.open is captured exactly like the authorities above, at load time, so a
-- later replacement cannot change how the optional geometry probe decides.
if type(captured_io_open) ~= "function" then
	fail("captured io.open is unavailable")
end

-- POSIX ENOENT. It is the single errno that means "the optional file is simply
-- not there"; every other errno is a real I/O failure on a file that IS there.
local enoent_errno = 2

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

	-- Whether the optional fixed geometry implementation is present is decided
	-- by an OPEN PROBE, never by inspecting the prose of a failed load. Two
	-- independent engine measurements forbid a message match:
	--   * Luanti localizes strerror. src/main.cpp:792 calls init_gettext, which
	--     runs setlocale(LC_ALL, "") (src/gettext.cpp:192 and :223) and forces
	--     only LC_NUMERIC back to "C" (src/gettext.cpp:229). On engine 5.16.1
	--     the secured loader pushes path .. ": " .. strerror(errno)
	--     (5.16.1 src/script/cpp_api/s_security.cpp:677), so under an inherited
	--     de_DE.UTF-8 locale it reads "Datei oder Verzeichnis nicht gefunden"
	--     and an English match aborts the whole game load.
	--   * Luanti 5.17.0 removed strerror from that path entirely and pushes the
	--     fixed text path .. ": Failed reading file."
	--     (5.17.0 src/script/cpp_api/s_security.cpp:731-732), so the English
	--     strerror phrase appears there under NO locale at all.
	-- The sandbox additionally DROPS io.open's third (errno) return: sl_io_open
	-- ends in lua_call(L, 2) and "return 2" (5.17.0 s_security.cpp:1089ff,
	-- identical at 5.16.1 s_security.cpp:1039), while plain PUC 5.1 and LuaJIT
	-- return three values. The errno branch below therefore strengthens the
	-- offline and no-security cases and is simply inert under mod security; a
	-- path the sandbox refuses outright raises a Lua error rather than
	-- reporting absence (s_security.h:10-14), so that stays loud.
	local geometry_impl
	local impl_path = directory .. "/geometry/compiler_impl.lua"
	local impl_handle, impl_message, impl_errno =
		captured_io_open(impl_path, "r")
	if impl_handle then
		impl_handle:close()
		-- The file is there, so it is no longer optional: load it UNPROTECTED,
		-- so a syntax error or a runtime error raised while it executes
		-- propagates with its own message instead of reading as absence.
		local impl_result = captured_dofile(impl_path)
		if type(impl_result) ~= "table" or
				type(impl_result.compile) ~= "function" then
			fail("fixed geometry compiler has an invalid module contract")
		end
		geometry_impl = impl_result.compile
	elseif type(impl_errno) == "number" and impl_errno ~= enoent_errno then
		fail("fixed geometry compiler could not be opened: " ..
			tostring(impl_message))
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
