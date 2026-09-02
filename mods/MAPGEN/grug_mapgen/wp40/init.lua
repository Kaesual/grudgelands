-- Shared pure WP40 foundation loader. R4 constructs a validated named-zone
-- payload only on explicit request; publication and map writing remain R7.

return function(directory)
	if type(directory) ~= "string" then
		error("WP40 foundation directory argument missing", 0)
	end

	local function fail(message)
		error("WP40 R4 loader: " .. message, 0)
	end

	local foundation = {
		enabled = false,
		disabled_reason = "WP40 R4 payload is validated but not published until R7",
		schemas = dofile(directory .. "/schemas.lua"),
		canonical = dofile(directory .. "/canonical.lua"),
		deterministic = dofile(directory .. "/deterministic.lua"),
		validation = dofile(directory .. "/validation.lua"),
		index128 = dofile(directory .. "/index128.lua"),
		seed_corpus = dofile(directory .. "/seed_corpus.lua"),
	}

	local function raw_sha256_from_core(core_api)
		if type(core_api) ~= "table" or type(core_api.sha256) ~= "function" then
			fail("core.sha256 API unavailable")
		end
		local sha256 = core_api.sha256
		return function(data) return sha256(data, true) end
	end

	local function new_session(full_seed_string, raw_sha256,
			configured_water_level)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 function missing") end
		-- Load fresh private copies. Public foundation-table mutation cannot
		-- replace the authority closed over by this constructor. Accepted artifact
		-- verification belongs to the offline R4 preflight before this boundary.
		local source = dofile(directory .. "/source/simple_map.lua")
		local schemas = dofile(directory .. "/schemas.lua")
		local canonical = dofile(directory .. "/canonical.lua")
		local deterministic = dofile(directory .. "/deterministic.lua")
		local index128 = dofile(directory .. "/index128.lua")
		local horizontal_factory = dofile(directory .. "/simple_map.lua")
		local height_factory = dofile(directory .. "/height.lua")
		local zones_factory = dofile(directory .. "/zones.lua")
		local zones_module = zones_factory({
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			index128 = index128,
			horizontal_factory = horizontal_factory,
			height_factory = height_factory,
			raw_sha256 = raw_sha256,
		})
		if type(zones_module) ~= "table" or type(zones_module.new) ~= "function" then
			fail("zones factory did not return the R4 module")
		end
		return zones_module.new(full_seed_string, configured_water_level)
	end

	local function new_engine_session(full_seed_string, core_api)
		if type(core_api) ~= "table" or
				type(core_api.get_mapgen_setting) ~= "function" then
			fail("core.get_mapgen_setting API unavailable")
		end
		local raw_sha256 = raw_sha256_from_core(core_api)
		local raw_water_level = core_api.get_mapgen_setting("water_level")
		local water_level = tonumber(raw_water_level)
		if type(water_level) ~= "number" or water_level ~= water_level or
				water_level == math.huge or water_level == -math.huge or
				water_level % 1 ~= 0 or water_level ~= 1 then
			fail("engine water_level must be exact integer 1")
		end
		return new_session(full_seed_string, raw_sha256, water_level)
	end

	foundation.raw_sha256_from_core = raw_sha256_from_core
	foundation.new_session = new_session
	foundation.new_engine_session = new_engine_session
	return foundation
end
