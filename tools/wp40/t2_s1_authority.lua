-- Stage-S1 authority for the E0 scalar pool.
--
-- The extreme selector consumes stage S1 only (the per-record R7 displacement:
-- noise, damping, local clip, record-wide topology ceiling, component
-- conversion, the sole final reraster, fixed closure, junction departures and
-- perimeters).  Pinning whole Source and compiler files therefore invalidated
-- the measured pool on every later-stage geometry correction even though each
-- of R16..R19 changes no scalar identity or value.
--
-- This authority pins exactly what S1 reads:
--   * the S1 module bytes (geometry/boundary.lua),
--   * the arithmetic surface it consumes (canonical, deterministic, exact and
--     the boundary raster),
--   * the canonical checksum of the S1 Source projection published by
--     geometry/boundary.lua -- not the bytes of source/catalog.lua.
--
-- What is deliberately absent: geometry/partition.lua (S2..S9), the Source
-- catalog bytes, and validation/t2_source.lua.  A record kind that S1 does not
-- read cannot move this digest, which is the whole point.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = assert(dependencies.raw_sha256)

	local authority = {}
	local schema = "grug_wp40_s1_authority_v1"
	local module_path = "mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua"
	local arithmetic_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
	}
	local excluded_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua",
	}

	local function fail(message)
		error("WP40 T2 S1 authority: " .. message, 0)
	end

	local function hex(bytes)
		if type(bytes) ~= "string" or #bytes ~= 32 then fail("digest is not 32 bytes") end
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end

	local function checked_digest(value, label)
		if type(value) ~= "string" or #value ~= 64 or not value:match("^[0-9a-f]+$") then
			fail(label .. " is not a lowercase SHA-256 hex digest")
		end
		return value
	end

	local function bytes_for(files, path)
		if type(files) ~= "table" or getmetatable(files) ~= nil then
			fail("file bytes are not a plain table")
		end
		local bytes = files[path]
		if type(bytes) ~= "string" then fail("missing S1 authority file " .. path) end
		return bytes
	end

	-- One ordered, self-describing text blob.  Paths are fixed and already in
	-- sorted order, so the digest has no map/iteration order dependence.
	local function blob(files, source_projection_sha256, projection_schema)
		local lines = {schema}
		lines[#lines + 1] = "s1_module\t" .. module_path .. "\t" ..
			hex(raw_sha256(bytes_for(files, module_path)))
		for index = 1, #arithmetic_paths do
			local path = arithmetic_paths[index]
			lines[#lines + 1] = "s1_arithmetic\t" .. path .. "\t" ..
				hex(raw_sha256(bytes_for(files, path)))
		end
		if type(projection_schema) ~= "string" or projection_schema == "" then
			fail("S1 projection schema is missing")
		end
		lines[#lines + 1] = "s1_source_projection\t" .. projection_schema .. "\t" ..
			checked_digest(source_projection_sha256, "S1 source projection checksum")
		return table.concat(lines, "\n") .. "\n"
	end

	local function digest(files, source_projection_sha256, projection_schema)
		return hex(raw_sha256(blob(files, source_projection_sha256,
			projection_schema)))
	end

	-- The pool provenance carries the S1 digest instead of a partition/Source
	-- byte pin; verification recomputes it from the live tree and the live
	-- projection, so a stale pool is rejected without reading catalog bytes.
	local function verify(files, source_projection_sha256, projection_schema,
			expected)
		local actual = digest(files, source_projection_sha256, projection_schema)
		if actual ~= checked_digest(expected, "expected S1 authority digest") then
			fail("stage-S1 authority digest differs")
		end
		return true
	end

	authority.SCHEMA = schema
	authority.module_path = module_path
	authority.arithmetic_paths = arithmetic_paths
	authority.excluded_paths = excluded_paths
	authority.paths = {module_path, arithmetic_paths[1], arithmetic_paths[2],
		arithmetic_paths[3], arithmetic_paths[4]}
	authority.blob = blob
	authority.digest = digest
	authority.verify = verify
	return authority
end
