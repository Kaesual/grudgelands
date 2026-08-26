-- Engine-free loader for the accepted WP40 simple-map R3 factory contract.

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

	local counter, cache = 0, {}
	local function from_hex(value)
		return (value:gsub("..", function(pair)
			return string.char(assert(tonumber(pair, 16)))
		end))
	end
	local function raw_sha256(data)
		assert(type(data) == "string", "SHA-256 input must be bytes")
		local cached = cache[data]
		if cached then return cached end
		local digest
		if injected_raw_sha256 then
			digest = injected_raw_sha256(data)
		else
			counter = counter + 1
			local input = scratch .. "/r3-sha-" .. counter .. ".bin"
			local output = scratch .. "/r3-sha-" .. counter .. ".txt"
			local file = assert(io.open(input, "wb"))
			assert(file:write(data))
			assert(file:close())
			local ok, why, code = os.execute("sha256sum " .. input .. " > " .. output)
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
		cache[data] = digest
		return digest
	end

	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source, canonical, deterministic, horizontal_module
	local loader = {raw_sha256 = raw_sha256}
	local function initialize_horizontal()
		if horizontal_module then return end
		-- The caller verifies the accepted artifact and all fifteen R2 input
		-- hashes before this function executes any R2-bound Lua file.
		source = dofile(directory .. "/source/simple_map.lua")
		local schemas = dofile(directory .. "/schemas.lua")
		canonical = dofile(directory .. "/canonical.lua")
		deterministic = dofile(directory .. "/deterministic.lua")
		horizontal_module = dofile(directory .. "/simple_map.lua")({
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			raw_sha256 = raw_sha256,
		})
		assert(horizontal_module.validate_source(),
			"simple-map source validation failed")
		loader.source = source
		loader.canonical = canonical
		loader.deterministic = deterministic
	end
	function loader.load(full_seed_string)
		initialize_horizontal()
		-- R2 artifact verification deliberately happens in the caller before this
		-- first load of any vertical implementation code.
		local height_factory = dofile(directory .. "/height.lua")
		local horizontal_session = horizontal_module.new(full_seed_string)
		local height_module = height_factory({
			source = source,
			canonical = canonical,
			deterministic = deterministic,
			raw_sha256 = raw_sha256,
			horizontal_session = horizontal_session,
		})
		if type(height_module.validate_source) == "function" then
			assert(height_module.validate_source(), "height source validation failed")
		end
		assert(type(height_module.new) == "function", "height module.new missing")
		return {
			source = source,
			horizontal = horizontal_session,
			height_module = height_module,
			height = height_module.new(full_seed_string),
		}
	end
	return loader
end
