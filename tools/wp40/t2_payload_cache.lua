-- Offline-only persistent cache for the data-only T2 partition payload.
-- Acceptance runners bypass it through WP40_NO_CACHE=1.

local function fail(message)
	error("WP40 T2 payload cache: " .. message, 0)
end

local function exact_options(value)
	local allowed = {repo = true, scratch = true, cache_dir = true,
		raw_sha256 = true, validate_hit = true, no_cache = true}
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("options are not a plain table")
	end
	for key in pairs(value) do
		if not allowed[key] then fail("unknown option " .. tostring(key)) end
	end
	for _, key in ipairs({"repo", "scratch", "cache_dir"}) do
		if type(value[key]) ~= "string" or value[key] == "" then
			fail(key .. " is unavailable")
		end
	end
	if type(value.raw_sha256) ~= "function" then fail("raw SHA-256 is unavailable") end
	if value.validate_hit ~= nil and type(value.validate_hit) ~= "function" then
		fail("hit validator is not a function")
	end
	if value.no_cache == nil then value.no_cache = os.getenv("WP40_NO_CACHE") end
	if value.no_cache == nil then value.no_cache = "0" end
	if value.no_cache == "0" then value.no_cache = false
	elseif value.no_cache == "1" then value.no_cache = true
	elseif type(value.no_cache) ~= "boolean" then
		fail("no-cache flag must be 0 or 1")
	end
	return value
end

local function hex(bytes)
	if type(bytes) ~= "string" or #bytes ~= 32 then
		fail("digest is not 32 bytes")
	end
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then fail("cannot read " .. path) end
	local bytes = file:read("*a")
	if bytes == nil or not file:close() then fail("cannot read " .. path) end
	return bytes
end

local function plain(value, seen)
	local kind = type(value)
	if kind == "nil" then return "nil" end
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "string" then return string.format("%q", value) end
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge or
				value % 1 ~= 0 then
			fail("payload contains a non-integer number")
		end
		return tostring(value)
	end
	if kind ~= "table" or getmetatable(value) ~= nil then
		fail("payload is not data-only")
	end
	seen = seen or {}
	if seen[value] then fail("payload contains an alias or cycle") end
	seen[value] = true
	local numeric, text = {}, {}
	for key in pairs(value) do
		if type(key) == "number" and key % 1 == 0 and key >= 1 then
			numeric[#numeric + 1] = key
		elseif type(key) == "string" then
			text[#text + 1] = key
		else
			fail("payload contains an unsupported key")
		end
	end
	table.sort(numeric)
	table.sort(text)
	local parts = {"{"}
	for index = 1, #numeric do
		parts[#parts + 1] = "[" .. numeric[index] .. "]=" ..
			plain(value[numeric[index]], seen) .. ","
	end
	for index = 1, #text do
		parts[#parts + 1] = "[" .. string.format("%q", text[index]) .. "]=" ..
			plain(value[text[index]], seen) .. ","
	end
	parts[#parts + 1] = "}"
	return table.concat(parts)
end

return function(raw_options)
	local options = exact_options(raw_options)
	local dependency_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	}
	local dependency_parts = {"grug_wp40_t2_payload_cache_v1"}
	for index = 1, #dependency_paths do
		local path = dependency_paths[index]
		dependency_parts[#dependency_parts + 1] = path
		dependency_parts[#dependency_parts + 1] =
			hex(options.raw_sha256(read_file(options.repo .. "/" .. path)))
	end
	local dependency_key = hex(options.raw_sha256(table.concat(dependency_parts, "\n")))
	local cache = {last_status = "unused", dependency_key = dependency_key}

	local function cache_path(seed)
		if type(seed) ~= "string" or not seed:match("^[0-9]+$") then
			fail("seed is not canonical unsigned decimal")
		end
		local key = hex(options.raw_sha256(dependency_key .. "\n" .. seed))
		return options.cache_dir .. "/" .. key .. ".lua"
	end

	local function load_payload(path)
		local file = io.open(path, "rb")
		if not file then return nil end
		local bytes = file:read("*a")
		assert(file:close())
		local expected, body = bytes:match("^%-%- payload ([0-9a-f]+)\n(.*)$")
		if not expected or #expected ~= 64 or
				expected ~= hex(options.raw_sha256(body)) then
			return nil
		end
		local chunk = loadstring(body, "@" .. path)
		if not chunk then return nil end
		setfenv(chunk, {})
		local ok, payload = pcall(chunk)
		if not ok then return nil end
		local ok_plain, encoded = pcall(plain, payload)
		if not ok_plain or body ~= "return " .. encoded .. "\n" then return nil end
		return payload
	end

	function cache.compile(seed, compile_uncached)
		if type(compile_uncached) ~= "function" then fail("compiler is unavailable") end
		if options.no_cache then
			cache.last_status = "bypass"
			return compile_uncached(seed)
		end
		local path = cache_path(seed)
		local payload = load_payload(path)
		if payload ~= nil then
			if options.validate_hit then options.validate_hit() end
			cache.last_status = "hit"
			print("WP40 T2 payload cache hit seed=" .. seed)
			return payload
		end
		local compiled = compile_uncached(seed)
		local body = "return " .. plain(compiled) .. "\n"
		local bytes = "-- payload " .. hex(options.raw_sha256(body)) .. "\n" .. body
		-- Keep the temporary beside its destination so the atomic rename does not
		-- cross filesystems when the harness scratch lives under /tmp.
		local temporary = path .. ".tmp-" ..
			hex(options.raw_sha256(options.scratch))
		local file = assert(io.open(temporary, "wb"))
		assert(file:write(bytes))
		assert(file:close())
		assert(os.rename(temporary, path))
		cache.last_status = "miss"
		print("WP40 T2 payload cache miss seed=" .. seed)
		return compiled
	end

	function cache.wrap(compile_uncached)
		if type(compile_uncached) ~= "function" then fail("compiler is unavailable") end
		return function(seed)
			return cache.compile(seed, compile_uncached)
		end
	end

	return cache
end
