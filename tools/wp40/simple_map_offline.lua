-- Offline loader shared by the WP40 simple-map test and SVG renderer.

return function(repo, scratch, seed)
	assert(type(repo) == "string" and repo:sub(1,1) == "/",
		"absolute repository root required")
	assert(type(scratch) == "string" and
		scratch:match("^/tmp/grudgelands%-wp40%-simple%-map%.[A-Za-z0-9]+$"),
		"unsafe simple-map scratch directory")
	seed = seed or "0"
	local counter, cache = 0, {}
	local function from_hex(value)
		return (value:gsub("..", function(pair)
			return string.char(assert(tonumber(pair,16)))
		end))
	end
	local function raw_sha256(data)
		local cached = cache[data]
		if cached then return cached end
		counter = counter + 1
		local input = scratch .. "/sha-" .. counter .. ".bin"
		local output = scratch .. "/sha-" .. counter .. ".txt"
		local file = assert(io.open(input,"wb"))
		assert(file:write(data))
		assert(file:close())
		local ok, why, code = os.execute("sha256sum " .. input .. " > " .. output)
		assert(ok == 0 or ok == true and why == "exit" and code == 0,
			"sha256sum failed")
		file = assert(io.open(output,"rb"))
		local line = assert(file:read("*l"))
		assert(file:close())
		assert(os.remove(input))
		assert(os.remove(output))
		local digest = from_hex(assert(line:match("^([0-9a-f]+)")))
		assert(#digest == 32)
		cache[data] = digest
		return digest
	end

	local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(directory .. "/source/simple_map.lua")
	local schemas = dofile(directory .. "/schemas.lua")
	local module = dofile(directory .. "/simple_map.lua")({
		source=source,
		schemas=schemas,
		canonical=dofile(directory .. "/canonical.lua"),
		deterministic=dofile(directory .. "/deterministic.lua"),
		raw_sha256=raw_sha256,
	})
	return {
		source=source,
		module=module,
		session=module.new(seed),
		raw_sha256=raw_sha256,
	}
end
