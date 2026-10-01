-- Minimal JSON decoder for the Round 28 Lane B1 portable fixture: stands in
-- for core.parse_json (objects, arrays, strings with the common escapes,
-- numbers, true/false/null). Not used by the game.
local M = {}

local function fail(text, i, message)
	error(("json: %s at byte %d near %q"):format(message, i, text:sub(i, i + 20)), 0)
end

local function skip(text, i)
	local _, e = text:find("^[ \t\r\n]*", i)
	return e + 1
end

local decode_value

local escapes = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f",
	n = "\n", r = "\r", t = "\t"}

local function decode_string(text, i)
	local out, j = {}, i + 1
	while true do
		local c = text:sub(j, j)
		if c == "" then fail(text, i, "unterminated string") end
		if c == '"' then return table.concat(out), j + 1 end
		if c == "\\" then
			local e = text:sub(j + 1, j + 1)
			if escapes[e] then
				out[#out + 1] = escapes[e]
				j = j + 2
			elseif e == "u" then
				local code = tonumber(text:sub(j + 2, j + 5), 16)
				if not code then fail(text, j, "bad \\u escape") end
				out[#out + 1] = code < 128 and string.char(code) or "?"
				j = j + 6
			else
				fail(text, j, "bad escape")
			end
		else
			out[#out + 1] = c
			j = j + 1
		end
	end
end

function decode_value(text, i, null)
	i = skip(text, i)
	local c = text:sub(i, i)
	if c == "{" then
		local obj = {}
		i = skip(text, i + 1)
		if text:sub(i, i) == "}" then return obj, i + 1 end
		while true do
			if text:sub(i, i) ~= '"' then fail(text, i, "object key expected") end
			local key
			key, i = decode_string(text, i)
			i = skip(text, i)
			if text:sub(i, i) ~= ":" then fail(text, i, "':' expected") end
			local value
			value, i = decode_value(text, i + 1, null)
			obj[key] = value
			i = skip(text, i)
			local d = text:sub(i, i)
			if d == "}" then return obj, i + 1 end
			if d ~= "," then fail(text, i, "',' or '}' expected") end
			i = skip(text, i + 1)
		end
	elseif c == "[" then
		local arr = {}
		i = skip(text, i + 1)
		if text:sub(i, i) == "]" then return arr, i + 1 end
		while true do
			local value
			value, i = decode_value(text, i, null)
			arr[#arr + 1] = value
			i = skip(text, i)
			local d = text:sub(i, i)
			if d == "]" then return arr, i + 1 end
			if d ~= "," then fail(text, i, "',' or ']' expected") end
			i = i + 1
		end
	elseif c == '"' then
		return decode_string(text, i)
	elseif text:sub(i, i + 3) == "true" then
		return true, i + 4
	elseif text:sub(i, i + 4) == "false" then
		return false, i + 5
	elseif text:sub(i, i + 3) == "null" then
		return null, i + 4
	end
	local s, e = text:find("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
	if not s then fail(text, i, "unexpected character") end
	return tonumber(text:sub(s, e)), e + 1
end

-- core.parse_json(text[, nullvalue, return_error]) shape.
function M.parse(text, null, return_error)
	local ok, value, i = pcall(decode_value, text, 1, null)
	if ok then
		i = skip(text, i)
		if i <= #text then
			ok, value = false, "json: trailing characters"
		end
	end
	if not ok then
		if return_error then return nil, value end
		error(value, 0)
	end
	return value
end

return M
