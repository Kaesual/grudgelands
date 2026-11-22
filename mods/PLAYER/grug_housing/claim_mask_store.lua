-- The claim mask's two files in the world folder (Round 85 lane MASK; the
-- format is docs/technical/claim-mask-format.md, which a Python tool reads
-- without this file):
--
--   grug_claim_mask.txt    the map's snapshot (ruling 7): the header, the
--                          mask of every faction as of the map's first start
--                          and per claim-ground chunk its fingerprints.
--                          Written once per map: at a start whose map has
--                          none yet (a new world, or the first start after a
--                          map reset), never at a later one.
--   grug_claim_ground.txt  the cache of the column rule's full scans (rule 5
--                          of claim_mask.lua), used only when its key equals
--                          this start's (the world-layout cache's key parts
--                          and a digest of the mask's own files).
--
-- Both are plain text lines ending in "end <sha256 of every byte before>":
-- a truncated, edited or half-written file never decodes. Every failure
-- means a rebuild (the cache) or a severe report (the snapshot), never a stop.
--
-- Plain Lua 5.1, no globals, no engine calls: hashing and file access are
-- injected (as spawn_regions_cache.lua's):
--   deps.sha256(bytes) -> lowercase hex digest
--   deps.read(path) -> bytes, or nil when there is no such file
--   deps.write(path, bytes) -> true after an atomic replace
return function(deps)
	assert(type(deps) == "table" and type(deps.sha256) == "function" and
		type(deps.read) == "function" and type(deps.write) == "function",
		"claim mask store dependencies differ")
	local sha256 = deps.sha256
	local M = {
		SNAPSHOT_FORMAT = "grug_claim_mask_v1", SNAPSHOT_FILE = "grug_claim_mask.txt",
		CACHE_FORMAT = "grug_claim_ground_v1", CACHE_FILE = "grug_claim_ground.txt",
	}

	local function value(v, name)
		v = tostring(v)
		if v == "" or v:find("[\r\n]") then
			error("claim mask store: header value " .. name .. " differs", 0)
		end
		return v
	end
	local function token(v, name)
		v = tostring(v)
		if v == "" or v:find("%s") then
			error("claim mask store: " .. name .. " differs: " .. v, 0)
		end
		return v
	end

	local function seal(lines)
		local head = table.concat(lines, "\n") .. "\n"
		return head .. "end " .. sha256(head) .. "\n"
	end

	-- The lines of a sealed file without its trailer, or nil and the reason.
	local function open(bytes, format)
		if type(bytes) ~= "string" or bytes == "" then return nil, "empty file" end
		local tail = bytes:find("end %x+\n$")
		if not tail or (tail > 1 and bytes:sub(tail - 1, tail - 1) ~= "\n") or
				bytes:sub(tail + 4, -2) ~= sha256(bytes:sub(1, tail - 1)) then
			return nil, "file hash differs or trailer missing"
		end
		local lines = {}
		for line in bytes:sub(1, tail - 1):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
		if lines[1] ~= format then return nil, "format differs (" .. tostring(lines[1]) .. ")" end
		return lines
	end

	--
	-- The snapshot
	--

	-- `header`: ordered {name, value} pairs; `rows`: claim_mask.fingerprints
	-- rows {faction, cx, cz, height, water, zone, roads, places}.
	function M.encode_snapshot(header, rows)
		local lines = {M.SNAPSHOT_FORMAT}
		for _, pair in ipairs(header) do
			lines[#lines + 1] = token(pair[1], "header name") .. "=" .. value(pair[2], pair[1])
		end
		lines[#lines + 1] = "chunks " .. #rows
		for _, r in ipairs(rows) do
			lines[#lines + 1] = table.concat({token(r[1], "faction"), r[2], r[3], r[4], r[5],
				r[6], r[7], r[8]}, " ")
		end
		return seal(lines)
	end

	-- {header = {name -> value}, names = {...in order}, rows = {...}}, or nil
	-- and the reason. Never raises.
	function M.decode_snapshot(bytes)
		local lines, why = open(bytes, M.SNAPSHOT_FORMAT)
		if not lines then return nil, why end
		local out = {header = {}, names = {}, rows = {}}
		local n = 2
		while lines[n] and not lines[n]:match("^chunks ") do
			local name, v = lines[n]:match("^([%w_]+)=(.+)$")
			if not name then return nil, "header line " .. n .. " differs" end
			out.header[name] = v
			out.names[#out.names + 1] = name
			n = n + 1
		end
		local count = tonumber((lines[n] or ""):match("^chunks (%d+)$"))
		if not count then return nil, "chunk count line missing" end
		if #lines ~= n + count then return nil, "chunk rows differ from their count" end
		for k = 1, count do
			local f, cx, cz, h, w, z, r, p = lines[n + k]:match(
				"^(%a+) (%-?%d+) (%-?%d+) (%x+) (%x+) (%x+) (%x+) (%x+)$")
			if not f then return nil, "chunk row " .. k .. " differs" end
			out.rows[k] = {f, tonumber(cx), tonumber(cz), h, w, z, r, p}
		end
		return out
	end

	function M.snapshot_path(world_dir)
		return world_dir .. "/" .. M.SNAPSHOT_FILE
	end

	-- The world's snapshot: the decoded file, or nil and the reason ("no
	-- file" when there is none).
	function M.load_snapshot(world_dir)
		local bytes = deps.read(M.snapshot_path(world_dir))
		if not bytes then return nil, "no file" end
		return M.decode_snapshot(bytes)
	end

	function M.store_snapshot(world_dir, header, rows)
		local bytes = M.encode_snapshot(header, rows)
		return deps.write(M.snapshot_path(world_dir), bytes) == true, #bytes
	end

	--
	-- The scan cache
	--

	-- `key`: ordered {name, value} pairs; `scans`: claim_mask scans
	-- {"cx cz faction" -> {code, cap}}, written in key order.
	function M.encode_cache(key, scans)
		local lines = {M.CACHE_FORMAT}
		for _, pair in ipairs(key) do
			lines[#lines + 1] = token(pair[1], "key name") .. "=" .. value(pair[2], pair[1])
		end
		local keys = {}
		for k in pairs(scans) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local s = scans[k]
			lines[#lines + 1] = "s " .. k .. " " .. token(s.code, "scan code") .. " " ..
				(s.cap and 1 or 0)
		end
		return seal(lines)
	end

	-- The scans when the file's key equals `key`; otherwise nil, the reason
	-- and whether the file is damaged (rather than of another key). Never raises.
	function M.decode_cache(bytes, key)
		local lines, why = open(bytes, M.CACHE_FORMAT)
		if not lines then
			return nil, why, not (why or ""):match("^format differs")
		end
		for n, pair in ipairs(key) do
			local name, v = (lines[n + 1] or ""):match("^([%w_]+)=(.+)$")
			if name ~= pair[1] then return nil, "key line " .. n .. " differs", true end
			if v ~= pair[2] then return nil, name .. " differs", false end
		end
		local scans = {}
		for n = #key + 2, #lines do
			local k, code, cap = lines[n]:match("^s (%-?%d+ %-?%d+ %a+) ([%w_]+) ([01])$")
			if not k then return nil, "scan line " .. n .. " differs", true end
			scans[k] = {code = code, cap = cap == "1"}
		end
		return scans
	end

	function M.cache_path(world_dir)
		return world_dir .. "/" .. M.CACHE_FILE
	end

	function M.load_cache(world_dir, key)
		local bytes = deps.read(M.cache_path(world_dir))
		if not bytes then return nil, "no cache file", false end
		return M.decode_cache(bytes, key)
	end

	function M.store_cache(world_dir, key, scans)
		local bytes = M.encode_cache(key, scans)
		return deps.write(M.cache_path(world_dir), bytes) == true, #bytes
	end

	return M
end
