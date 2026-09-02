-- Defensive structural shaper for normalized WP40 records. Text fields are
-- byte strings here; the canonical publication seam remains the single owner
-- of valid-UTF8 enforcement. Inputs are copied and no registry/cache is kept.

local analytic_record = {}

local U32_MAX = 4294967295
local I32_MIN = -2147483648
local I32_MAX = 2147483647

local function fail(message)
	error("WP40 analytic record: " .. message, 0)
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is outside its integer range")
	end
	return value
end

local function plain_table(value, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	return value
end

local function dense_count(value, label)
	plain_table(value, label)
	local count = #value
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	for index = 1, count do
		if value[index] == nil then fail(label .. " has a hole") end
	end
	return count
end

local function exact_fields(value, allowed, label)
	plain_table(value, label)
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
end

local function text(value, label, nonempty)
	if type(value) ~= "string" or nonempty and value == "" then
		fail(label .. " is not " .. (nonempty and "non-empty " or "") .. "text")
	end
	return value
end

local function copy_scalar(kind, value, label)
	if kind == "text" then return text(value, label, false) end
	if kind == "signed" then
		return integer(value, I32_MIN, I32_MAX, label)
	end
	if kind == "unsigned" then
		return integer(value, 0, U32_MAX, label)
	end
	if kind == "boolean" then
		if type(value) ~= "boolean" then fail(label .. " is not boolean") end
		return value
	end
	fail("unknown scalar kind " .. tostring(kind))
end

local function copy_array(kind, values, label)
	local count = dense_count(values, label)
	local result = {}
	for index = 1, count do
		result[index] = copy_scalar(kind, values[index], label .. "[" .. index .. "]")
	end
	return result
end

local BUCKETS = {
	{name = "text_values", kind = "text", array = false},
	{name = "signed_values", kind = "signed", array = false},
	{name = "unsigned_values", kind = "unsigned", array = false},
	{name = "boolean_values", kind = "boolean", array = false},
	{name = "text_arrays", kind = "text", array = true},
	{name = "signed_arrays", kind = "signed", array = true},
	{name = "unsigned_arrays", kind = "unsigned", array = true},
}

local TOP_FIELDS = {candidates = true, attributes = true}
for index = 1, #BUCKETS do TOP_FIELDS[BUCKETS[index].name] = true end

local SCALAR_ROW_FIELDS = {name = true, value = true}
local ARRAY_ROW_FIELDS = {name = true, values = true}

local function copy_bucket(definition, rows, seen)
	rows = rows or {}
	local count = dense_count(rows, definition.name)
	local result = {}
	local bucket_seen = {}
	for index = 1, count do
		local row = rows[index]
		exact_fields(row, definition.array and ARRAY_ROW_FIELDS or
			SCALAR_ROW_FIELDS, definition.name .. "[" .. index .. "]")
		local name = text(row.name, definition.name .. " field name", true)
		if bucket_seen[name] then
			fail(definition.name .. " has duplicate field " .. name)
		end
		if seen[name] then
			fail("field " .. name .. " occurs in " .. seen[name] .. " and " ..
				definition.name)
		end
		bucket_seen[name] = true
		seen[name] = definition.name
		if definition.array then
			result[index] = {name = name, values = copy_array(definition.kind,
				row.values, definition.name .. "." .. name)}
		else
			result[index] = {name = name, value = copy_scalar(definition.kind,
				row.value, definition.name .. "." .. name)}
		end
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

function analytic_record.new(record_schema, id, numeric_id, fields)
	record_schema = text(record_schema, "record_schema", true)
	id = text(id, "id", true)
	numeric_id = integer(numeric_id, 0, U32_MAX, "numeric_id")
	fields = fields or {}
	exact_fields(fields, TOP_FIELDS, "fields")

	local result = {
		record_schema = record_schema,
		id = id,
		numeric_id = numeric_id,
	}
	local seen = {}
	for index = 1, #BUCKETS do
		local definition = BUCKETS[index]
		result[definition.name] = copy_bucket(definition,
			fields[definition.name], seen)
	end
	result.candidates = copy_array("unsigned", fields.candidates or {},
		"candidates")
	local attributes = fields.attributes or {}
	plain_table(attributes, "attributes")
	if next(attributes) ~= nil then
		fail("attributes must be the explicitly typed empty map")
	end
	result.attributes = {}
	return result
end

return analytic_record
