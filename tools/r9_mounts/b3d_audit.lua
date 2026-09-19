local function i32(body, at)
	local b1, b2, b3, b4 = body:byte(at, at + 3)
	assert(b4, "truncated B3D integer")
	local value = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	if value >= 2147483648 then value = value - 4294967296 end
	return value
end

return function(path)
	local file = assert(io.open(path, "rb"))
	local body = assert(file:read("*a"))
	file:close()
	assert(body:sub(1, 4) == "BB3D", "not a B3D mesh: " .. path)
	local result = {anim = 0, bone = 0, keys = 0, keyframes = 0}
	local walk
	local function keyed(from, to)
		local flags = i32(body, from)
		local floats = 0
		if flags % 2 == 1 then floats = floats + 3 end
		if math.floor(flags / 2) % 2 == 1 then floats = floats + 3 end
		if math.floor(flags / 4) % 2 == 1 then floats = floats + 4 end
		local stride = 4 + floats * 4
		assert(stride > 4 and (to - from - 4) % stride == 0,
			"malformed KEYS chunk: " .. path)
		local at = from + 4
		while at < to do
			local frame = i32(body, at)
			result.keyframes = result.keyframes + 1
			if not result.min_frame or frame < result.min_frame then result.min_frame = frame end
			if not result.max_frame or frame > result.max_frame then result.max_frame = frame end
			at = at + stride
		end
	end
	walk = function(from, to)
		local at = from
		while at < to do
			local tag = body:sub(at, at + 3)
			local length = i32(body, at + 4)
			local payload, finish = at + 8, at + 8 + length
			assert(length >= 0 and finish <= to, "malformed " .. tag .. " chunk: " .. path)
			if tag == "BB3D" then
				walk(payload + 4, finish)
			elseif tag == "NODE" then
				local stop = assert(body:find("\0", payload, true), "unterminated NODE")
				walk(stop + 1 + 40, finish)
			elseif tag == "MESH" then
				walk(payload + 4, finish)
			elseif tag == "ANIM" then
				result.anim = result.anim + 1
			elseif tag == "BONE" then
				result.bone = result.bone + 1
			elseif tag == "KEYS" then
				result.keys = result.keys + 1
				keyed(payload, finish)
			end
			at = finish
		end
		assert(at == to, "chunk boundary mismatch: " .. path)
	end
	walk(1, #body + 1)
	assert(result.anim > 0 and result.bone > 0 and result.keys > 0,
		"mesh is not fully animated: " .. path)
	return result
end
