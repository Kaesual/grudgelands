-- Engine-free, authority-gated loader for the WP40 simple-map R4 payload.

return function(repo, scratch, injected_raw_sha256)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	assert(type(scratch) == "string" and
		scratch:match("^/tmp/grudgelands%-wp40%-simple%-map%.[A-Za-z0-9]+$"),
		"unsafe simple-map scratch directory")
	if injected_raw_sha256 ~= nil then
		assert(type(injected_raw_sha256) == "function",
			"injected raw SHA-256 must be a function")
	end

	local common = dofile(repo .. "/tools/wp40/simple_map_r4_common.lua")
	local counter, calls, cache = 0, 0, {}
	local function from_hex(value)
		return (value:gsub("..", function(pair)
			return string.char(assert(tonumber(pair, 16)))
		end))
	end
	local function raw_sha256(data)
		assert(type(data) == "string", "SHA-256 input must be bytes")
		local cached = #data <= 4096 and cache[data] or nil
		if cached then return cached end
		calls = calls + 1
		local digest
		if injected_raw_sha256 then
			digest = injected_raw_sha256(data)
		else
			counter = counter + 1
			local input = scratch .. "/r4-sha-" .. counter .. ".bin"
			local output = scratch .. "/r4-sha-" .. counter .. ".txt"
			local file = assert(io.open(input, "wb"))
			assert(file:write(data))
			assert(file:close())
			local ok, why, code = os.execute(
				"sha256sum " .. input .. " > " .. output)
			assert(ok == 0 or ok == true and why == "exit" and code == 0,
				"sha256sum failed")
			file = assert(io.open(output, "rb"))
			local line = assert(file:read("*l"))
			assert(file:close())
			assert(os.remove(input))
			assert(os.remove(output))
			digest = from_hex(assert(line:match("^([0-9a-f]+)")))
		end
		assert(type(digest) == "string" and #digest == 32,
			"SHA-256 seam did not return 32 bytes")
		if #data <= 4096 then cache[data] = digest end
		return digest
	end

	local authority
	local initialized = false
	local source, schemas, canonical, deterministic, index128, zones_module
	local loader = {raw_sha256 = raw_sha256}

	function loader.sha256_call_count()
		return calls
	end

	function loader.preflight()
		if not authority then
			-- This reads and hashes both accepted artifacts and every embedded
			-- input before initialize() can execute an artifact-bound Lua file.
			authority = common.verify_authority(repo, raw_sha256)
		end
		return common.deep_copy(authority)
	end

	function loader.loaded()
		return initialized
	end

	local function initialize()
		if initialized then return end
		-- Do not rely on an earlier cached preflight: refresh the complete
		-- authority immediately before the first artifact-bound dofile.
		authority = common.verify_authority(repo, raw_sha256)
		local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
		-- Keep every artifact-bound dofile below the completed preflight.
		source = dofile(directory .. "/source/simple_map.lua")
		schemas = dofile(directory .. "/schemas.lua")
		canonical = dofile(directory .. "/canonical.lua")
		deterministic = dofile(directory .. "/deterministic.lua")
		local horizontal_factory = dofile(directory .. "/simple_map.lua")
		local height_factory = dofile(directory .. "/height.lua")
		index128 = dofile(directory .. "/index128.lua")
		local zones_factory = dofile(directory .. "/zones.lua")
		assert(type(source) == "table" and source.schema == common.SOURCE_SCHEMA,
			"simple-map source schema differs")
		assert(source.layout_id == common.LAYOUT_ID,
			"simple-map layout identity differs")
		assert(source.layout_revision_id == common.LAYOUT_REVISION_ID,
			"simple-map layout revision differs")
		assert(type(schemas) == "table" and
			schemas.simple_map == common.HORIZONTAL_SCHEMA,
			"horizontal schema differs")
		assert(type(horizontal_factory) == "function",
			"horizontal factory is missing")
		assert(type(height_factory) == "function", "height factory is missing")
		assert(type(index128) == "table", "index128 dependency is missing")
		assert(type(zones_factory) == "function", "zones factory is missing")
		zones_module = zones_factory({
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			index128 = index128,
			horizontal_factory = horizontal_factory,
			height_factory = height_factory,
			raw_sha256 = raw_sha256,
		})
		assert(type(zones_module) == "table" and
			type(zones_module.new) == "function", "zones module.new is missing")
		initialized = true
	end

	function loader.load(full_seed_string, configured_water_level)
		initialize()
		local session = zones_module.new(full_seed_string,
			configured_water_level)
		assert(type(session) == "table", "zones session is missing")
		return {
			authority = common.deep_copy(authority),
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			index128 = index128,
			module = zones_module,
			session = session,
		}
	end

	function loader.load_foundation(full_seed_string, configured_water_level,
			options)
		if options == nil then options = {} end
		assert(type(options) == "table", "foundation load options must be a table")
		for key in pairs(options) do
			assert(key == "peer" or key == "horizontal_oracle" or
				key == "height_oracle", "unknown foundation load option")
			assert(type(options[key]) == "boolean",
				"foundation load option must be boolean")
		end
		local want_peer = options.peer == true
		local want_height_oracle = options.height_oracle == true
		local want_horizontal_oracle = options.horizontal_oracle == true or
			want_height_oracle
		-- The foundation loads accepted executable inputs while its factory runs,
		-- so refresh all R2/R3 bindings before even loading init.lua.
		authority = common.verify_authority(repo, raw_sha256)
		local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
		local foundation_factory = dofile(directory .. "/init.lua")
		assert(type(foundation_factory) == "function",
			"foundation factory is missing")
		local foundation = foundation_factory(directory)
		assert(type(foundation) == "table" and
			type(foundation.new_session) == "function" and
			type(foundation.new_engine_session) == "function",
			"R4 foundation constructors are missing")

		local session = foundation.new_session(full_seed_string, raw_sha256,
			configured_water_level)
		local engine_sha256_calls, engine_setting_reads = 0, 0
		local engine_callback_registration_calls = 0
		local engine_unexpected_api_reads = 0
		local peer_session
		if want_peer then
			local core_api = setmetatable({}, {__index = function(_, key)
				if type(key) == "string" and key:match("^register_") then
					return function()
						engine_callback_registration_calls =
							engine_callback_registration_calls + 1
					end
				end
				engine_unexpected_api_reads = engine_unexpected_api_reads + 1
				error("unexpected engine-shaped API read: " .. tostring(key), 0)
			end})
			function core_api.sha256(data, raw)
				assert(raw == true,
					"engine-shaped SHA-256 did not request raw bytes")
				engine_sha256_calls = engine_sha256_calls + 1
				return raw_sha256(data)
			end
			function core_api.get_mapgen_setting(name)
				assert(name == "water_level", "unexpected mapgen setting read")
				engine_setting_reads = engine_setting_reads + 1
				return tostring(configured_water_level)
			end
			peer_session = foundation.new_engine_session(full_seed_string,
				core_api)
			assert(engine_setting_reads == 1,
				"engine-shaped session did not read water_level exactly once")
		end

		local loaded = {
			authority = common.deep_copy(authority),
			foundation = foundation,
			session = session,
			peer_session = peer_session,
			engine_sha256_calls = engine_sha256_calls,
			engine_setting_reads = engine_setting_reads,
			engine_callback_registration_calls =
				engine_callback_registration_calls,
			engine_unexpected_api_reads = engine_unexpected_api_reads,
			repo = repo,
		}
		if want_horizontal_oracle then
			-- These are independent accepted R2/R3 validation oracles, never a
			-- second production-policy implementation and never returned by R4.
			local oracle_source = dofile(directory .. "/source/simple_map.lua")
			local oracle_schemas = dofile(directory .. "/schemas.lua")
			local oracle_canonical = dofile(directory .. "/canonical.lua")
			local oracle_deterministic = dofile(directory .. "/deterministic.lua")
			local horizontal_module = dofile(directory .. "/simple_map.lua")({
				source = oracle_source,
				schemas = oracle_schemas,
				canonical = oracle_canonical,
				deterministic = oracle_deterministic,
				raw_sha256 = raw_sha256,
			})
			assert(type(horizontal_module) == "table" and
				type(horizontal_module.new) == "function",
				"horizontal validation oracle is missing")
			if type(horizontal_module.validate_source) == "function" then
				assert(horizontal_module.validate_source(),
					"horizontal validation source differs")
			end
			local horizontal = horizontal_module.new(full_seed_string)
			local height_module = dofile(directory .. "/height.lua")({
				source = oracle_source,
				canonical = oracle_canonical,
				deterministic = oracle_deterministic,
				raw_sha256 = raw_sha256,
				horizontal_session = horizontal,
			})
			assert(type(height_module) == "table" and
				type(height_module.new) == "function",
				"height validation oracle is missing")
			if type(height_module.validate_source) == "function" then
				assert(height_module.validate_source(),
					"height validation source differs")
			end
			loaded.source = oracle_source
			loaded.horizontal = horizontal
			if want_height_oracle then
				loaded.height = height_module.new(full_seed_string)
			end
		else
			-- Validators still need immutable source metadata for targeted rows.
			loaded.source = dofile(directory .. "/source/simple_map.lua")
		end
		return loaded
	end

	return loader
end
