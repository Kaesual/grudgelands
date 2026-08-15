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

-- The body is compiled by whichever interpreter reads it, so every token has
-- to decode to the same value under PUC Lua 5.1 and under LuaJIT.
--
-- Negative zero is the one number that a decimal literal cannot carry across
-- both. PUC interns numeric constants by numeric equality and -0 == 0, so a
-- "-0" literal in a chunk that already interned "0" is folded onto the +0
-- constant and loses its sign; LuaJIT interns the two separately and keeps it.
-- The compiler does produce -0: deterministic.round_ratio returns
-- sign * quotient, so a negative value that rounds to zero comes back as -0
-- (for example bay station_radius_delta, 285 entries in the seed-0 payload).
-- That sign carries no meaning the geometry ever reads -- canonical.lua, the
-- only checksum seam, encodes -0 and 0 to identical bytes -- but the cache
-- reproduces the compiler's output rather than improving it, so the encoder
-- stays faithful and emits a run-time negation instead of a literal. IEEE
-- unary minus on +0 is -0 on both interpreters, with no constant folding
-- involved, so "n" below decodes exactly.
local prelude = "local z=0 local n=-z\n"

-- string.format("%q") is host-dependent for bytes outside the printable ASCII
-- range: PUC emits a raw tab where LuaJIT emits \9, and \000 where LuaJIT
-- emits \0. Escape explicitly so a payload written by one interpreter still
-- re-encodes byte-identically under the other. Printable ASCII is untouched,
-- so the emitted text matches %q for every string the payload holds today.
local escapes = {["\""] = "\\034", ["\\"] = "\\092"}
for byte = 0, 255 do
	if byte < 32 or byte > 126 then
		escapes[string.char(byte)] = ("\\%03d"):format(byte)
	end
end

local function quote(value)
	return "\"" .. (value:gsub(".", escapes)) .. "\""
end

local function plain(value, seen)
	local kind = type(value)
	if kind == "nil" then return "nil" end
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "string" then return quote(value) end
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge or
				value % 1 ~= 0 then
			fail("payload contains a non-integer number")
		end
		if value == 0 then return 1 / value < 0 and "n" or "0" end
		-- tostring uses %.14g on both interpreters, so a magnitude that needs
		-- more than fourteen digits would round-trip to a different number.
		-- Reject the exponent and fraction forms instead of storing a lie.
		local text = tostring(value)
		if not text:match("^%-?[1-9][0-9]*$") then
			fail("payload number has no exact decimal form: " .. text)
		end
		return text
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
		parts[#parts + 1] = "[" .. quote(text[index]) .. "]=" ..
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
	-- v2 is the body grammar above. Bumping it retires v1 entries by key
	-- instead of leaving them to fail validation on every run.
	local dependency_parts = {"grug_wp40_t2_payload_cache_v2"}
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
		if not ok_plain or body ~= prelude .. "return " .. encoded .. "\n" then
			return nil
		end
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
		local body = prelude .. "return " .. plain(compiled) .. "\n"
		local bytes = "-- payload " .. hex(options.raw_sha256(body)) .. "\n" .. body
		-- Keep the temporary beside its destination so the atomic rename does not
		-- cross filesystems when the harness scratch lives under /tmp.
		local temporary = path .. ".tmp-" ..
			hex(options.raw_sha256(options.scratch))
		local file = assert(io.open(temporary, "wb"))
		assert(file:write(bytes))
		assert(file:close())
		assert(os.rename(temporary, path))
		body, bytes = nil, nil
		-- Read the entry straight back through the same validator. A write this
		-- interpreter cannot accept is a defect worth reporting at the moment it
		-- happens, not a silent miss on every later run.
		if load_payload(path) == nil then
			fail("the payload just written for seed " .. seed ..
				" does not load back exactly")
		end
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
