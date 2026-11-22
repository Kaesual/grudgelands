-- Round 87. Each generation of a world records the housing-area chunks hit
-- by its protected roads. Keep the input and the result together at rollover.
return function(CM)
	local M = {FILE = "grug_road_chunks.txt"}
	local MAGIC = "grug_road_chunks_v1"

	function M.key(cx, cz)
		return cx .. " " .. cz
	end

	function M.collect(road, housing_at, occupied)
		local added = {}
		CM.mark_road_chunks(road, added, M.key, housing_at, occupied)
		return added
	end

	function M.capture(world)
		local allowed, rows = {}, {}
		for _, zone in ipairs(world.zones) do
			allowed[zone.id] = CM.zone_allowed("accord", zone) or CM.zone_allowed("throng", zone)
		end
		-- Adjacent centreline segments cover many of the same node columns.
		local function housing_at(x, z)
			local row = rows[z]
			if not row then row = {}; rows[z] = row end
			if row[x] == nil then
				local zone = world.zone_at(x, z)
				row[x] = zone and allowed[zone.id] or false
			end
			return row[x]
		end
		local chunks = {}
		for _, road in ipairs(world.roads) do
			CM.mark_road_chunks(road, chunks, M.key, housing_at)
		end
		return chunks
	end

	local function append_set(lines, name, chunks)
		local keys = {}
		for key in pairs(chunks) do keys[#keys + 1] = key end
		table.sort(keys)
		lines[#lines + 1] = name .. " " .. #keys
		for _, key in ipairs(keys) do lines[#lines + 1] = key end
	end

	function M.encode(record, sha256)
		local lines = {MAGIC, "grid " .. CM.CHUNK .. " " .. CM.ORIGIN, "seed " .. record.seed,
			"reset " .. record.map_reset, "from " .. (record.previous_reset or "-")}
		append_set(lines, "previous", record.previous)
		append_set(lines, "current", record.chunks)
		local body = table.concat(lines, "\n") .. "\n"
		return body .. "end " .. sha256(body) .. "\n"
	end

	function M.decode(bytes, sha256)
		if not bytes then return nil, "missing" end
		local body, hash = bytes:match("^(.*\n)end (%x+)\n$")
		if not body or sha256(body) ~= hash then return nil, "checksum" end
		local next_line = body:gmatch("([^\n]*)\n")
		if next_line() ~= MAGIC or next_line() ~= "grid " .. CM.CHUNK .. " " .. CM.ORIGIN then
			return nil, "format"
		end
		local seed = (next_line() or ""):match("^seed (%-?%d+)$")
		local reset = tonumber((next_line() or ""):match("^reset (%d+)$"))
		local from = (next_line() or ""):match("^from (.+)$")
		local previous_reset = tonumber(from and from:match("^%d+$"))
		if not seed or not reset or (from ~= "-" and not previous_reset) or
				(previous_reset and previous_reset >= reset) then return nil, "identity" end
		local function read_set(name)
			local count = tonumber((next_line() or ""):match("^" .. name .. " (%d+)$"))
			if not count then return nil end
			local chunks = {}
			for _ = 1, count do
				local key = next_line()
				if not key or not key:match("^%-?%d+ %-?%d+$") or chunks[key] then return nil end
				chunks[key] = true
			end
			return chunks
		end
		local previous = read_set("previous")
		local chunks = read_set("current")
		if not previous or not chunks or (not previous_reset and next(previous)) or next_line() then
			return nil, "chunk rows"
		end
		return {seed = seed, map_reset = reset, previous_reset = previous_reset,
			previous = previous, chunks = chunks}
	end

	-- Returns nil on a warm start. Computing the corridor set can then be skipped.
	function M.advance(seed, reset, old, capture)
		local previous, previous_reset = {}, nil
		if old and old.seed == seed then
			if old.map_reset == reset then return nil end
			if old.map_reset < reset then previous, previous_reset = old.chunks, old.map_reset end
		end
		return {seed = seed, map_reset = reset, previous = previous,
			previous_reset = previous_reset, chunks = capture()}
	end

	return M
end
