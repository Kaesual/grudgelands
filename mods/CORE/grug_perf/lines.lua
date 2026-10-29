-- The [GRUG-PERF] log lines (contract v1, 0.66.1): one JSON object after the
-- marker, written at action level for the hosting platform's log shipper.
-- The contract is fixed: fields may be added, never renamed, removed or
-- reinterpreted (docs/technical/module-guide.md "Performance log lines").
--
-- Pure: no engine call, so tools/r661_perf/portable_test.lua loads this file
-- as it ships. Returns the module table; it publishes no global itself.
local L = {}

L.PREFIX = "[GRUG-PERF] "
L.VERSION = 1
-- The parser stores a longer line as plain text.
L.MAX_BYTES = 4096

local floor, huge = math.floor, math.huge
local format, concat = string.format, table.concat

-- Every field per kind, in the order the line writes them: name, type
-- ("int", "num", "bool", "str") and whether it may be absent.
L.FIELDS = {
	minute = {
		{"v", "int"}, {"kind", "str"}, {"span_s", "num"}, {"steps", "int"},
		{"step_p50", "num"}, {"step_p95", "num"}, {"step_max", "num"},
		{"spikes", "int"}, {"spike_ms", "num"}, {"max_lag", "num"},
		{"players", "int"}, {"objects", "int"}, {"luaentities", "int"},
		{"rtt_p50", "num", true}, {"rtt_max", "num", true},
		{"jitter_max", "num", true},
		{"minimap_us", "int"}, {"minimap_changes", "int"},
		{"minimap_bytes", "int"}, {"lua_kb", "int"}, {"profiler", "bool"},
	},
	spike = {
		{"v", "int"}, {"kind", "str"}, {"step_ms", "num"}, {"players", "int"},
		{"objects", "int"}, {"luaentities", "int"},
	},
	profile_saved = {{"v", "int"}, {"kind", "str"}, {"file", "str"}},
}

-- A finite number >= 0; anything else (nil, NaN, an infinity, a negative
-- difference) is 0, since the parser refuses the whole line for one bad value.
local function clean(x)
	if type(x) ~= "number" or x ~= x or x == huge or x < 0 then return 0 end
	return x
end
L.clean = clean

-- Integer fields: the nearest integer.
function L.int(x)
	return floor(clean(x) + 0.5)
end

-- Number fields: one decimal (0.1 ms, 0.1 s) keeps the line short.
function L.tenth(x)
	return floor(clean(x) * 10 + 0.5) / 10
end

local function number_text(x)
	-- Integers without a decimal point (up to 2^53, so minimap_us fits);
	-- the rest at one decimal, as L.tenth rounded them.
	if x == floor(x) then return format("%.0f", x) end
	return format("%.1f", x)
end

local function string_text(s)
	s = tostring(s):gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
		return format("\\u%04x", c:byte())
	end)
	return '"' .. s .. '"'
end

-- The line for `kind` from `values` (field name -> value). `v` and `kind`
-- are filled in; an optional field that is nil stays absent; a required
-- number that is missing is written as 0, a missing boolean as false.
-- Returns the line, or nil and a reason for an unknown kind or a line over
-- the size limit.
function L.build(kind, values)
	local fields = L.FIELDS[kind]
	if not fields then return nil, "unknown kind " .. tostring(kind) end
	local parts = {}
	for i = 1, #fields do
		local name, kind_of, optional = fields[i][1], fields[i][2], fields[i][3]
		local value
		if name == "v" then
			value = L.VERSION
		elseif name == "kind" then
			value = kind
		else
			value = values[name]
		end
		local text
		if value == nil and optional then
			text = nil
		elseif kind_of == "int" then
			text = number_text(L.int(value))
		elseif kind_of == "num" then
			text = number_text(L.tenth(value))
		elseif kind_of == "bool" then
			text = value == true and "true" or "false"
		else
			text = string_text(value == nil and "" or value)
		end
		if text then parts[#parts + 1] = '"' .. name .. '":' .. text end
	end
	local line = L.PREFIX .. "{" .. concat(parts, ",") .. "}"
	if #line >= L.MAX_BYTES then return nil, "line over " .. L.MAX_BYTES .. " bytes" end
	return line
end

return L
