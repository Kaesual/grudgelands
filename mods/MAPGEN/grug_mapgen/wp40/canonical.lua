-- Canonical WP40 binary grammar. This is the only encoder/checksum seam.
-- Strings enter through bytes() or text(); an untyped Lua string is invalid.

local canonical = {}

local U32_MAX = 4294967295
local I32_MIN = -2147483648
local I32_MAX = 2147483647

local function fail(message)
	error("WP40 canonical: " .. message, 0)
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is outside its integer range")
	end
	return value
end

local function u32(value, label)
	return integer(value, 0, U32_MAX, label or "u32")
end

local function be32(value)
	value = u32(value)
	local b1 = math.floor(value / 16777216)
	local rest = value - b1 * 16777216
	local b2 = math.floor(rest / 65536)
	rest = rest - b2 * 65536
	local b3 = math.floor(rest / 256)
	local b4 = rest - b3 * 256
	return string.char(b1, b2, b3, b4)
end

local function valid_utf8(value)
	local i = 1
	while i <= #value do
		local a = value:byte(i)
		if a <= 127 then
			i = i + 1
		elseif a >= 194 and a <= 223 then
			local b = value:byte(i + 1)
			if not b or b < 128 or b > 191 then return false end
			i = i + 2
		elseif a >= 224 and a <= 239 then
			local b, c = value:byte(i + 1, i + 2)
			if not b or not c or c < 128 or c > 191 or
					b < 128 or b > 191 or (a == 224 and b < 160) or
					(a == 237 and b > 159) then return false end
			i = i + 3
		elseif a >= 240 and a <= 244 then
			local b, c, d = value:byte(i + 1, i + 3)
			if not b or not c or not d or c < 128 or c > 191 or
					d < 128 or d > 191 or b < 128 or b > 191 or
					(a == 240 and b < 144) or (a == 244 and b > 143) then
				return false
			end
			i = i + 4
		else
			return false
		end
	end
	return true
end

local function node(kind, value)
	return {_wp40_type = kind, value = value}
end

function canonical.bytes(value)
	if type(value) ~= "string" then fail("bytes value is not a string") end
	return node("bytes", value)
end

function canonical.text(value)
	if type(value) ~= "string" or not valid_utf8(value) then
		fail("text value is not valid UTF-8")
	end
	return node("text", value)
end

function canonical.signed(value)
	return node("signed", integer(value, I32_MIN, I32_MAX, "signed value"))
end

function canonical.unsigned(value)
	return node("unsigned", u32(value, "unsigned value"))
end

function canonical.boolean(value)
	if type(value) ~= "boolean" then fail("boolean value is not boolean") end
	return canonical.unsigned(value and 1 or 0)
end

function canonical.array(values)
	if type(values) ~= "table" then fail("array value is not a table") end
	return node("array", values)
end

-- Maps are arrays of {key, value} pairs so duplicate encoded keys remain
-- observable and can be rejected instead of being overwritten by Lua.
function canonical.map(pairs_array)
	if type(pairs_array) ~= "table" then fail("map value is not a table") end
	return node("map", pairs_array)
end

local function array_count(values, label)
	local count = #values
	u32(count, label .. " count")
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	return count
end

local function encode_node(value, active)
	if type(value) ~= "table" or type(value._wp40_type) ~= "string" then
		fail("nil, primitive, or untyped value cannot be encoded")
	end
	if active[value] then fail("cyclic graph cannot be encoded") end
	active[value] = true
	local kind = value._wp40_type
	local encoded
	if kind == "bytes" or kind == "text" then
		local data = value.value
		if type(data) ~= "string" then fail(kind .. " payload changed type") end
		if kind == "text" and not valid_utf8(data) then
			fail("text payload is not valid UTF-8")
		end
		local tag = kind == "bytes" and 1 or 2
		encoded = string.char(tag) .. be32(#data) .. data
	elseif kind == "signed" then
		local number = integer(value.value, I32_MIN, I32_MAX, "signed value")
		if number < 0 then number = number + 4294967296 end
		encoded = string.char(3) .. be32(number)
	elseif kind == "unsigned" then
		encoded = string.char(4) .. be32(value.value)
	elseif kind == "array" then
		local count = array_count(value.value, "array")
		local parts = {string.char(5), be32(count)}
		for i = 1, count do
			parts[#parts + 1] = encode_node(value.value[i], active)
		end
		encoded = table.concat(parts)
	elseif kind == "map" then
		local count = array_count(value.value, "map pairs")
		local rows = {}
		for i = 1, count do
			local pair = value.value[i]
			if type(pair) ~= "table" or array_count(pair, "map pair") ~= 2 then
				fail("map row is not a key/value pair")
			end
			local key = encode_node(pair[1], active)
			rows[i] = {key = key, value = encode_node(pair[2], active)}
		end
		table.sort(rows, function(a, b) return a.key < b.key end)
		local parts = {string.char(6), be32(count)}
		for i = 1, count do
			if i > 1 and rows[i - 1].key == rows[i].key then
				fail("duplicate encoded map key")
			end
			parts[#parts + 1] = rows[i].key
			parts[#parts + 1] = rows[i].value
		end
		encoded = table.concat(parts)
	else
		fail("unknown type tag " .. kind)
	end
	active[value] = nil
	return encoded
end

function canonical.encode(value)
	return encode_node(value, {})
end

function canonical.checksum(value, raw_sha256)
	if type(raw_sha256) ~= "function" then fail("raw SHA-256 injection missing") end
	local digest = raw_sha256(canonical.encode(value))
	if type(digest) ~= "string" or #digest ~= 32 then
		fail("raw SHA-256 injection did not return 32 bytes")
	end
	return digest
end

function canonical.hex(bytes)
	if type(bytes) ~= "string" then fail("hex input is not bytes") end
	return (bytes:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end

canonical.U32_MAX = U32_MAX
canonical.I32_MIN = I32_MIN
canonical.I32_MAX = I32_MAX

return canonical
