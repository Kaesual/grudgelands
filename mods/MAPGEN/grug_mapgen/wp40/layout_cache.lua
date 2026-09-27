-- World-folder layout cache (Round 22, plan D71; world_zones.md §13.4).
--
-- Main builds the inland water, road and capital layouts once per world and
-- hands their texts to emerge (`ipc_set`). This module stores exactly those
-- three texts in the world folder after the first build, plus a small block
-- of build diagnostics (log lines, road showcase spots, build seconds), and
-- returns them on a later boot ONLY when the stored key equals the current
-- one. The key names everything the layouts depend on: a format version, the
-- full world seed, a digest of every Lua source of the mapgen mod (the whole
-- tree, through `preparation_identity.lua`'s routine, so no new module can be
-- forgotten), the mapgen settings and the Lua interpreter. Every text section
-- carries its length and SHA-256 and the file ends in a SHA-256 over all
-- bytes before it: a truncated, edited or half-written file never decodes.
-- A main boot with a hit is an emerge-style construction from the texts,
-- which is what emerge already does with main's payload.
--
-- Plain Lua 5.1, no globals, no engine calls: hashing, directory listing and
-- the atomic write are injected, so offline tools run this same code.
--   deps.sha256(bytes) -> lowercase hex digest
--   deps.list_dir(path, want_dirs) -> list of entry names (core.get_dir_list)
--   deps.write(path, bytes) -> true after an atomic replace
--     (core.safe_file_write: temp file, then rename)
--   deps.identity: `preparation_identity.lua`'s function
return function(deps)
	assert(type(deps) == "table" and type(deps.sha256) == "function" and
		type(deps.list_dir) == "function" and type(deps.write) == "function" and
		type(deps.identity) == "function", "WP40 layout cache dependencies differ")
	local sha256 = deps.sha256
	local M = {FORMAT = "grug_world_layouts_v1", FILE = "grug_world_layouts.txt"}
	-- The sections in file order; the first three are the ipc_set texts.
	local SECTIONS = {"water", "road", "capital", "meta"}
	local KEY_NAMES = {"format", "seed", "source", "settings", "interpreter"}

	-- Byte order, never Lua's locale-dependent `<`.
	local function less_bytes(a, b)
		for i = 1, math.min(#a, #b) do
			local x, y = a:byte(i), b:byte(i)
			if x ~= y then return x < y end
		end
		return #a < #b
	end

	-- Every `.lua` file below `mod_dir`, as paths relative to it, byte-sorted.
	function M.source_files(mod_dir)
		local out = {}
		local function walk(rel)
			local path = rel == "" and mod_dir or mod_dir .. "/" .. rel
			local prefix = rel == "" and "" or rel .. "/"
			for _, name in ipairs(deps.list_dir(path, false) or {}) do
				if name:sub(-4) == ".lua" and name:sub(1, 1) ~= "." then
					out[#out + 1] = prefix .. name
				end
			end
			for _, name in ipairs(deps.list_dir(path, true) or {}) do
				if name:sub(1, 1) ~= "." then walk(prefix .. name) end
			end
		end
		walk("")
		table.sort(out, less_bytes)
		if #out == 0 then error("WP40 layout cache: no mapgen sources below " .. mod_dir, 0) end
		return out
	end

	-- The source identity: the preparation identity routine over the tree.
	function M.source_digest(mod_dir)
		return deps.identity(mod_dir, sha256, M.source_files(mod_dir))
	end

	-- The key as ordered {name, value} pairs; values are single-line text.
	function M.key(seed, source, settings, interpreter)
		local values = {M.FORMAT, seed, source, settings, interpreter}
		local parts = {}
		for index, name in ipairs(KEY_NAMES) do
			local value = values[index]
			if type(value) ~= "string" or value == "" or value:find("[\r\n]") then
				error("WP40 layout cache: key part " .. name .. " differs", 0)
			end
			parts[index] = {name, value}
		end
		return parts
	end

	-- Diagnostics block: `logs` {{level, text}}, `spots` {{name, kind, x, y, z,
	-- road}} (the road showcase), `seconds` {construction, water, roads,
	-- capitals} of the build that wrote the file.
	local function encode_meta(meta)
		local out = {}
		local s = meta.seconds or {}
		out[#out + 1] = string.format("seconds %.3f %.3f %.3f %.3f", s.construction or 0,
			s.water or 0, s.roads or 0, s.capitals or 0)
		for _, row in ipairs(meta.logs or {}) do
			assert(not row[2]:find("[\r\n]"), "layout cache log line spans lines")
			out[#out + 1] = "log " .. row[1] .. " " .. row[2]
		end
		for _, spot in ipairs(meta.spots or {}) do
			out[#out + 1] = string.format("spot %d %d %d %d %s %s", spot.x, spot.y, spot.z,
				spot.road, spot.kind, spot.name)
		end
		return table.concat(out, "\n") .. "\n"
	end
	local function decode_meta(text)
		local meta = {logs = {}, spots = {}}
		for line in text:gmatch("([^\n]*)\n") do
			local a, b, c, d = line:match("^seconds (%S+) (%S+) (%S+) (%S+)$")
			if a then
				meta.seconds = {construction = tonumber(a), water = tonumber(b),
					roads = tonumber(c), capitals = tonumber(d)}
				for _, value in pairs(meta.seconds) do
					if value ~= value then return nil end
				end
				if not (meta.seconds.construction and meta.seconds.water and
						meta.seconds.roads and meta.seconds.capitals) then
					return nil
				end
			elseif line:match("^log ") then
				local level, msg = line:match("^log (%a+) (.*)$")
				if not level then return nil end
				meta.logs[#meta.logs + 1] = {level, msg}
			elseif line:match("^spot ") then
				local x, y, z, road, kind, name = line:match(
					"^spot (%-?%d+) (%-?%d+) (%-?%d+) (%d+) (%S+) (.+)$")
				if not x then return nil end
				meta.spots[#meta.spots + 1] = {x = tonumber(x), y = tonumber(y),
					z = tonumber(z), road = tonumber(road), kind = kind, name = name}
			else
				return nil
			end
		end
		if not meta.seconds then return nil end
		return meta
	end

	-- The file bytes: header, key lines, one length- and hash-framed section
	-- per text, and a trailer hash over everything before it. Deterministic
	-- for the same inputs; the texts are written exactly as built.
	function M.encode(parts, texts, meta)
		-- the header line is the format part; the other parts follow it
		local out = {M.FORMAT .. "\n"}
		for _, part in ipairs(parts) do
			if part[1] ~= "format" then out[#out + 1] = part[1] .. "=" .. part[2] .. "\n" end
		end
		local bodies = {water = texts.water, road = texts.road, capital = texts.capital,
			meta = encode_meta(meta or {})}
		for _, name in ipairs(SECTIONS) do
			local body = bodies[name]
			if type(body) ~= "string" or body == "" then
				error("WP40 layout cache: section " .. name .. " is empty", 0)
			end
			out[#out + 1] = string.format("section %s %d %s\n", name, #body, sha256(body))
			out[#out + 1] = body
			out[#out + 1] = "\n"
		end
		local head = table.concat(out)
		return head .. "end " .. sha256(head) .. "\n"
	end

	-- `bytes` against the current key parts. Returns {water, road, capital,
	-- meta} on a match; otherwise nil, the reason and whether the file is
	-- damaged (a warning) rather than merely built for another key.
	function M.decode(bytes, parts)
		if type(bytes) ~= "string" or bytes == "" then return nil, "empty cache file", true end
		local pos = 1
		local function line()
			local stop = bytes:find("\n", pos, true)
			if not stop then return nil end
			local text = bytes:sub(pos, stop - 1)
			pos = stop + 1
			return text
		end
		local header = line()
		if header == nil then return nil, "truncated header", true end
		if header ~= M.FORMAT then
			if header:match("^grug_world_layouts_") then
				return nil, "format differs (" .. header .. ")", false
			end
			return nil, "not a layout cache file", true
		end
		for _, part in ipairs(parts) do
			if part[1] ~= "format" then
				local text = line()
				if text == nil then return nil, "truncated key", true end
				local name, value = text:match("^([%a_]+)=(.*)$")
				if name ~= part[1] then return nil, "key line differs (" .. text .. ")", true end
				if value ~= part[2] then return nil, name .. " differs", false end
			end
		end
		local out = {}
		for _, name in ipairs(SECTIONS) do
			local text = line()
			if text == nil then return nil, "truncated before section " .. name, true end
			local got, len, digest = text:match("^section (%a+) (%d+) (%x+)$")
			if got ~= name then return nil, "section header differs (" .. name .. ")", true end
			len = tonumber(len)
			if pos + len > #bytes then return nil, "section " .. name .. " truncated", true end
			local body = bytes:sub(pos, pos + len - 1)
			if bytes:sub(pos + len, pos + len) ~= "\n" then
				return nil, "section " .. name .. " unterminated", true
			end
			if sha256(body) ~= digest then return nil, "section " .. name .. " hash differs", true end
			out[name] = body
			pos = pos + len + 1
		end
		local head_end = pos - 1
		local trailer = line()
		if trailer == nil or trailer ~= "end " .. sha256(bytes:sub(1, head_end)) then
			return nil, "file hash differs or trailer missing", true
		end
		if pos ~= #bytes + 1 then return nil, "trailing bytes after the file hash", true end
		local meta = decode_meta(out.meta)
		if not meta then return nil, "diagnostics block differs", true end
		return {water = out.water, road = out.road, capital = out.capital, meta = meta}
	end

	function M.path(world_dir)
		return world_dir .. "/" .. M.FILE
	end

	-- Read and decode the world's cache file (see `decode` for the returns).
	function M.load(world_dir, parts)
		local file = io.open(M.path(world_dir), "rb")
		if not file then return nil, "no cache file", false end
		local bytes = file:read("*a")
		file:close()
		return M.decode(bytes, parts)
	end

	-- Encode and atomically replace the world's cache file. Returns success
	-- and the byte count.
	function M.store(world_dir, parts, texts, meta)
		local bytes = M.encode(parts, texts, meta)
		return deps.write(M.path(world_dir), bytes) == true, #bytes
	end

	return M
end
