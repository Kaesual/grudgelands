-- Minimal JSON for the Round 28 Lane B4 tools (portable LuaJIT, never shipped):
-- `decode` stands in for core.parse_json in fixtures, `encode` writes
-- canonical JSON (object keys sorted, two-space indent optional) so two
-- registries compare as strings.
local json = {}

local escapes = {['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
	["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"}

local function encode_string(text)
	return '"' .. text:gsub('[%c"\\]', function(c)
		return escapes[c] or ("\\u%04x"):format(c:byte())
	end) .. '"'
end

local function is_array(value)
	local n = 0
	for _ in pairs(value) do n = n + 1 end
	for i = 1, n do if value[i] == nil then return false end end
	return true, n
end

-- `indent` nil: compact. A number: pretty, that many spaces per level.
function json.encode(value, indent, depth)
	depth = depth or 0
	local t = type(value)
	if t == "string" then return encode_string(value) end
	if t == "number" then
		if value % 1 == 0 and math.abs(value) < 2^53 then return ("%d"):format(value) end
		return ("%.17g"):format(value)
	end
	if t == "boolean" then return tostring(value) end
	if value == nil or value == json.null then return "null" end
	assert(t == "table", "cannot encode " .. t)
	local pad, inner, sep, open_nl = "", "", ",", ""
	if indent then
		pad = ("\n" .. (" "):rep(indent * depth))
		inner = ("\n" .. (" "):rep(indent * (depth + 1)))
		sep = ","
	end
	local array, n = is_array(value)
	local parts = {}
	if array then
		if n == 0 then return "[]" end
		for i = 1, n do parts[i] = inner .. json.encode(value[i], indent, depth + 1) end
		return "[" .. table.concat(parts, sep) .. pad .. "]"
	end
	local keys = {}
	for k in pairs(value) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	for i, k in ipairs(keys) do
		parts[i] = inner .. encode_string(k) .. (indent and ": " or ":") ..
			json.encode(value[k], indent, depth + 1)
	end
	return "{" .. table.concat(parts, sep) .. pad .. "}" .. open_nl
end

json.null = setmetatable({}, {__tostring = function() return "null" end})

function json.decode(text)
	local pos = 1
	local function ws() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
	local function fail(msg) error(("json: %s at %d"):format(msg, pos), 0) end
	local value
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = text:sub(pos, pos)
			if c == "" then fail("unterminated string") end
			if c == '"' then pos = pos + 1; break end
			if c == "\\" then
				local e = text:sub(pos + 1, pos + 1)
				local map = {b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
				if e == "u" then
					local code = tonumber(text:sub(pos + 2, pos + 5), 16)
					if code < 0x80 then out[#out + 1] = string.char(code)
					elseif code < 0x800 then
						out[#out + 1] = string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
					else
						out[#out + 1] = string.char(0xE0 + math.floor(code / 4096),
							0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
					end
					pos = pos + 6
				else
					out[#out + 1] = map[e] or e
					pos = pos + 2
				end
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = text:sub(pos, pos)
		if c == "{" then
			local out = {}
			pos = pos + 1
			ws()
			if text:sub(pos, pos) == "}" then pos = pos + 1; return out end
			while true do
				ws()
				if text:sub(pos, pos) ~= '"' then fail("key expected") end
				local k = str()
				ws()
				if text:sub(pos, pos) ~= ":" then fail("colon expected") end
				pos = pos + 1
				out[k] = value()
				ws()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return out end
				if d ~= "," then fail("comma expected") end
			end
		elseif c == "[" then
			local out = {}
			pos = pos + 1
			ws()
			if text:sub(pos, pos) == "]" then pos = pos + 1; return out end
			while true do
				out[#out + 1] = value()
				ws()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return out end
				if d ~= "," then fail("comma expected") end
			end
		elseif c == '"' then return str()
		elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
		elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
		elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
		end
		local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if not num or num == "" then fail("value expected") end
		pos = pos + #num
		return tonumber(num)
	end
	local ok, result = pcall(value)
	if not ok then return nil, result end
	return result
end

return json
