-- Shared WP40 R6 offline bytes, hashing, MTS parsing and artifact rows.

local common = {}

local function fail(message)
	error("WP40 R6 tool: " .. message, 0)
end
common.fail = fail

function common.read_file(path)
	local file = assert(io.open(path, "rb"), "cannot open " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

function common.write_file(path, bytes)
	local file = assert(io.open(path, "wb"), "cannot write " .. path)
	assert(file:write(bytes))
	assert(file:close())
end

function common.hex(bytes)
	return (bytes:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

function common.new_sha256()
	local ok, ffi = pcall(require, "ffi")
	if not ok then
		local counter = 0
		return function(bytes)
			counter = counter + 1
			local base = "/tmp/grudgelands-wp40-r6-sha-" ..
				tostring(os.time()) .. "-" .. tostring(counter)
			common.write_file(base .. ".bin", bytes)
			local status = os.execute("sha256sum " .. base .. ".bin > " .. base .. ".txt")
			if status ~= 0 and status ~= true then fail("sha256sum failed") end
			local digest = common.read_file(base .. ".txt"):match("^([0-9a-f]+)")
			assert(os.remove(base .. ".bin"))
			assert(os.remove(base .. ".txt"))
			return (digest:gsub("..", function(pair)
				return string.char(assert(tonumber(pair, 16)))
			end))
		end
	end
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest = ffi.new("unsigned char[32]")
	local vectors = {
		[""] = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
	}
	local function raw(bytes)
		assert(type(bytes) == "string")
		assert(crypto.SHA256(bytes, #bytes, digest) ~= nil)
		return ffi.string(digest, 32)
	end
	for bytes, expected in pairs(vectors) do
		if common.hex(raw(bytes)) ~= expected then fail("OpenSSL SHA-256 KAT failed") end
	end
	return raw
end

local function u16(bytes, offset)
	local a, b = string.byte(bytes, offset, offset + 1)
	if not b then fail("truncated u16") end
	return a * 256 + b, offset + 2
end

local function s16(bytes, offset)
	local value
	value, offset = u16(bytes, offset)
	if value >= 32768 then value = value - 65536 end
	return value, offset
end

local function u32(bytes, offset)
	local a, b, c, d = string.byte(bytes, offset, offset + 3)
	if not d then fail("truncated u32") end
	return ((a * 256 + b) * 256 + c) * 256 + d, offset + 4
end

function common.read_mts(path)
	local bytes = common.read_file(path)
	local signature, offset = u32(bytes, 1)
	if signature ~= 0x4d54534d then fail("MTS signature differs: " .. path) end
	local version
	version, offset = u16(bytes, offset)
	if version ~= 4 then fail("MTS version differs: " .. path) end
	local sx, sy, sz
	 sx, offset = s16(bytes, offset)
	 sy, offset = s16(bytes, offset)
	 sz, offset = s16(bytes, offset)
	if sx < 1 or sy < 1 or sz < 1 then fail("MTS size differs") end
	local yslice = {}
	for y = 0, sy - 1 do
		local value = string.byte(bytes, offset)
		if not value then fail("truncated MTS y slices") end
		offset = offset + 1
		yslice[y + 1] = {ypos = y, prob = (value % 128) * 2}
	end
	local name_count
	name_count, offset = u16(bytes, offset)
	local names = {}
	for index = 1, name_count do
		local length
		length, offset = u16(bytes, offset)
		local name = bytes:sub(offset, offset + length - 1)
		if #name ~= length then fail("truncated MTS node name") end
		offset = offset + length
		names[index] = name == "ignore" and "air" or name
	end
	local compressed = bytes:sub(offset)
	local node_count = sx * sy * sz
	local output_length = node_count * 4
	local ok, ffi = pcall(require, "ffi")
	if not ok then fail("LuaJIT FFI is required to parse pinned MTS files") end
	ffi.cdef[[
		int uncompress(unsigned char *dest, unsigned long *destLen,
			const unsigned char *source, unsigned long sourceLen);
	]]
	local zlib = ffi.load("z")
	local output = ffi.new("unsigned char[?]", output_length)
	local length = ffi.new("unsigned long[1]", output_length)
	if zlib.uncompress(output, length, compressed, #compressed) ~= 0 or
			tonumber(length[0]) ~= output_length then
		fail("MTS zlib stream differs: " .. path)
	end
	local raw = ffi.string(output, output_length)
	local data = {}
	for index = 1, node_count do
		local high, low = string.byte(raw, index * 2 - 1, index * 2)
		local name_index = high * 256 + low + 1
		local param1 = string.byte(raw, node_count * 2 + index)
		local param2 = string.byte(raw, node_count * 3 + index)
		local name = names[name_index]
		if not name then fail("MTS name index differs") end
		data[index] = {name = name, prob = (param1 % 128) * 2,
			param2 = param2, force_place = param1 >= 128}
	end
	return {size = {x = sx, y = sy, z = sz}, yslice_prob = yslice, data = data}
end

function common.tsv(path)
	local bytes = common.read_file(path)
	if bytes:sub(-1) ~= "\n" or bytes:find("\r", 1, true) then
		fail("TSV line endings differ: " .. path)
	end
	local rows, header = {}, nil
	for line in bytes:gmatch("([^\n]+)\n") do
		local fields = {}
		for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
		if not header then header = fields else
			local row = {}
			for index = 1, #header do row[header[index]] = fields[index] end
			rows[#rows + 1] = row
		end
	end
	return rows, header, bytes
end

local HEADER = {
	"row_type", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8",
	"k9", "k10", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8",
	"v9", "v10", "v11", "v12",
}
function common.artifact_header() return table.concat(HEADER, "\t") .. "\n" end

function common.row(row_type, keys, values)
	local function scalar(value)
		if value == nil then return "" end
		if type(value) == "string" then return value end
		if type(value) == "boolean" then return value and "true" or "false" end
		if type(value) == "number" and value == value and value ~= math.huge and
				value ~= -math.huge and value % 1 == 0 and
				math.abs(value) <= 9007199254740991 then
			return string.format("%.0f", value)
		end
		fail("unsupported artifact scalar")
	end
	local fields = {scalar(row_type)}
	for index = 1, 10 do fields[#fields + 1] = scalar(keys[index]) end
	for index = 1, 12 do fields[#fields + 1] = scalar(values[index]) end
	for index = 1, #fields do
		if fields[index]:find("\0", 1, true) or fields[index]:find("\t", 1, true) or
				fields[index]:find("\r", 1, true) or fields[index]:find("\n", 1, true) then
			fail("unsafe artifact scalar")
		end
	end
	return table.concat(fields, "\t") .. "\n"
end

function common.less_bytes(left, right)
	local count = math.min(#left, #right)
	for index = 1, count do
		local left_byte, right_byte = string.byte(left, index), string.byte(right, index)
		if left_byte ~= right_byte then return left_byte < right_byte end
	end
	return #left < #right
end

function common.sort_rows(rows)
	table.sort(rows, function(left, right)
		local lkey = left:match("^([^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*)")
		local rkey = right:match("^([^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*)")
		return common.less_bytes(lkey, rkey)
	end)
	local previous
	for index = 1, #rows do
		local key = rows[index]:match("^([^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*)")
		if key == previous then fail("duplicate artifact key tuple") end
		previous = key
	end
	return rows
end

return common
