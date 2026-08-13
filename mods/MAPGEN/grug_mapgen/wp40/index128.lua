-- Generic world-aligned 128x128 acceleration grid. Geometry remains in the
-- caller's exact evaluator; this module only compiles and verifies candidates.

local index128 = {}

local CELL_SIZE = 128
local MAX_SAFE = 9007199254740991
local MAX_CELL = math.floor(MAX_SAFE / CELL_SIZE)

local function fail(message)
	error("WP40 index128: " .. message, 0)
end

local function integer(value, label, minimum, maximum)
	minimum = minimum or -MAX_SAFE
	maximum = maximum or MAX_SAFE
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is not an integer")
	end
	return value
end

local function floor_div(value)
	return math.floor(value / CELL_SIZE)
end

local function dense_count(values, label)
	if type(values) ~= "table" then fail(label .. " is not an array") end
	local count = #values
	for i = 1, count do
		if values[i] == nil then fail(label .. " has a hole") end
	end
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	return count
end

local function checked_scalar(value, label)
	local kind = type(value)
	if kind ~= "nil" and kind ~= "boolean" and kind ~= "number" and
			kind ~= "string" then
		fail(label .. " is not scalar")
	end
	if kind == "number" then integer(value, label) end
	return value
end

local function exact_integer_keys(values, minimum, maximum, label)
	if type(values) ~= "table" then fail(label .. " is not a table") end
	local count = 0
	for key in pairs(values) do
		integer(key, label .. " key", minimum, maximum)
		count = count + 1
	end
	if count ~= maximum - minimum + 1 then
		fail(label .. " has missing or extra coverage")
	end
	return values
end

local function validate_candidates(candidates, label)
	local count = dense_count(candidates, label)
	if count == 0 then fail(label .. " is empty") end
	local previous
	local previous_type
	for i = 1, count do
		local candidate = checked_scalar(candidates[i], label .. " ID")
		local kind = type(candidate)
		if kind ~= "number" and kind ~= "string" then
			fail(label .. " ID is not comparable")
		end
		if previous_type and kind ~= previous_type then
			fail(label .. " IDs have mixed types")
		end
		if previous ~= nil and not (previous < candidate) then
			fail(label .. " IDs are not strictly sorted and unique")
		end
		previous = candidate
		previous_type = kind
	end
	return true
end

local function validate_cell_keys(cell)
	for key in pairs(cell) do
		if key ~= "direct" and key ~= "scalar" and key ~= "candidates" then
			fail("compiled cell has unknown field " .. tostring(key))
		end
	end
end

local function validate_bbox(bbox)
	if type(bbox) ~= "table" then fail("record bbox missing") end
	integer(bbox.min_x, "bbox min_x")
	integer(bbox.max_x, "bbox max_x")
	integer(bbox.min_z, "bbox min_z")
	integer(bbox.max_z, "bbox max_z")
	if bbox.min_x >= bbox.max_x or bbox.min_z >= bbox.max_z then
		fail("record bbox is not half-open and non-empty")
	end
end

local function intersects_cell(bbox, cx, cz)
	local min_x, min_z = cx * CELL_SIZE, cz * CELL_SIZE
	return bbox.min_x < min_x + CELL_SIZE and bbox.max_x > min_x and
		bbox.min_z < min_z + CELL_SIZE and bbox.max_z > min_z
end

local function sorted_candidates(layer, cx, cz)
	local candidates = {}
	local seen = {}
	local record_count = dense_count(layer.records, "layer records")
	for i = 1, record_count do
		local record = layer.records[i]
		validate_bbox(record.bbox)
		if intersects_cell(record.bbox, cx, cz) then
			if seen[record.id] then fail("duplicate record id " .. tostring(record.id)) end
			seen[record.id] = true
			candidates[#candidates + 1] = record.id
		end
	end
	table.sort(candidates, function(a, b)
		if type(a) ~= type(b) then fail("candidate IDs have mixed types") end
		return a < b
	end)
	return candidates
end

-- layer.classify_cell(cx, cz, sorted_candidates) returns
-- true, scalar for a proven homogeneous cell; false for an exact-evaluator
-- boundary cell. The compiled result contains data only, never functions.
function index128.compile(definition, expected_schema)
	if type(expected_schema) ~= "string" or expected_schema == "" then
		fail("expected index schema missing")
	end
	if type(definition) ~= "table" or type(definition.layers) ~= "table" then
		fail("definition missing")
	end
	if definition.schema ~= expected_schema then
		fail("index schema mismatch")
	end
	local min_cx = integer(definition.min_cx, "min_cx", -MAX_CELL, MAX_CELL)
	local max_cx = integer(definition.max_cx, "max_cx", -MAX_CELL, MAX_CELL)
	local min_cz = integer(definition.min_cz, "min_cz", -MAX_CELL, MAX_CELL)
	local max_cz = integer(definition.max_cz, "max_cz", -MAX_CELL, MAX_CELL)
	if min_cx > max_cx or min_cz > max_cz then fail("extent is empty") end
	local compiled = {
		schema = definition.schema,
		cell_size = CELL_SIZE,
		min_cx = min_cx,
		max_cx = max_cx,
		min_cz = min_cz,
		max_cz = max_cz,
		layers = {},
	}
	local layer_ids = {}
	local layer_count = dense_count(definition.layers, "index layers")
	for layer_index = 1, layer_count do
		local layer = definition.layers[layer_index]
		if type(layer.id) ~= "string" or layer.id == "" or layer_ids[layer.id] then
			fail("layer ID is missing or duplicate")
		end
		layer_ids[layer.id] = true
		if type(layer.records) ~= "table" or
				type(layer.classify_cell) ~= "function" then
			fail("layer compiler inputs missing for " .. layer.id)
		end
		local record_ids = {}
		local record_count = dense_count(layer.records, "layer records")
		for i = 1, record_count do
			local record = layer.records[i]
			if type(record) ~= "table" or record.id == nil or
					record_ids[record.id] then
				fail("record ID is missing or duplicate in " .. layer.id)
			end
			record_ids[record.id] = true
			validate_bbox(record.bbox)
		end
		checked_scalar(layer.outside, "outside result for " .. layer.id)
		local output = {id = layer.id, outside = layer.outside, cells = {}}
		for cx = min_cx, max_cx do
			local column = {}
			output.cells[cx] = column
			for cz = min_cz, max_cz do
				local candidates = sorted_candidates(layer, cx, cz)
				local direct, scalar = layer.classify_cell(cx, cz, candidates)
				if direct then
					column[cz] = {direct = true,
						scalar = checked_scalar(scalar, "homogeneous result")}
				else
					if #candidates == 0 then
						fail("boundary cell has no candidates")
					end
					column[cz] = {direct = false, candidates = candidates}
				end
			end
		end
		compiled.layers[layer_index] = output
	end
	return compiled
end

function index128.attach(compiled, expected_schema, evaluators)
	if type(expected_schema) ~= "string" or expected_schema == "" then
		fail("expected index schema missing")
	end
	if type(compiled) ~= "table" or compiled.cell_size ~= CELL_SIZE then
		fail("compiled grid schema/cell size mismatch")
	end
	if compiled.schema ~= expected_schema then fail("index schema mismatch") end
	if type(evaluators) ~= "table" then fail("exact evaluators missing") end
	local min_cx = integer(compiled.min_cx, "compiled min_cx", -MAX_CELL, MAX_CELL)
	local max_cx = integer(compiled.max_cx, "compiled max_cx", -MAX_CELL, MAX_CELL)
	local min_cz = integer(compiled.min_cz, "compiled min_cz", -MAX_CELL, MAX_CELL)
	local max_cz = integer(compiled.max_cz, "compiled max_cz", -MAX_CELL, MAX_CELL)
	if min_cx > max_cx or min_cz > max_cz then fail("compiled extent is empty") end
	local by_id = {}
	local layer_count = dense_count(compiled.layers, "compiled layers")
	for i = 1, layer_count do
		local layer = compiled.layers[i]
		if type(layer) ~= "table" or type(layer.id) ~= "string" or
				layer.id == "" or by_id[layer.id] then
			fail("compiled layer ID is missing or duplicate")
		end
		checked_scalar(layer.outside, "outside result for " .. tostring(layer.id))
		local evaluator = evaluators[layer.id]
		if type(evaluator) ~= "function" then
			fail("exact evaluator missing for " .. tostring(layer.id))
		end
		exact_integer_keys(layer.cells, min_cx, max_cx,
			"compiled cell columns for " .. layer.id)
		for cx = min_cx, max_cx do
			local column = exact_integer_keys(layer.cells[cx], min_cz, max_cz,
				"compiled cell rows for " .. layer.id)
			for cz = min_cz, max_cz do
				local cell = column[cz]
				if type(cell) ~= "table" or type(cell.direct) ~= "boolean" then
					fail("compiled cell direct flag is not boolean")
				end
				validate_cell_keys(cell)
				if cell.direct then
					checked_scalar(cell.scalar, "compiled direct scalar")
					if cell.candidates ~= nil then
						fail("compiled direct cell has candidates")
					end
				else
					if cell.scalar ~= nil then
						fail("compiled boundary cell has direct scalar")
					end
					validate_candidates(cell.candidates,
						"compiled boundary candidates")
				end
			end
		end
		by_id[layer.id] = {data = layer, exact = evaluator}
	end
	return {compiled = compiled, by_id = by_id}
end

-- Allocation-free scalar hot path after attach().
function index128.query(attached, layer_id, x, z)
	integer(x, "query x")
	integer(z, "query z")
	local layer = attached.by_id[layer_id]
	if not layer then fail("unknown query layer " .. tostring(layer_id)) end
	local data = layer.data
	local cx, cz = floor_div(x), floor_div(z)
	if cx < attached.compiled.min_cx or cx > attached.compiled.max_cx or
			cz < attached.compiled.min_cz or cz > attached.compiled.max_cz then
		return data.outside
	end
	local cell = data.cells[cx][cz]
	if cell.direct then return cell.scalar end
	return layer.exact(cell.candidates, x, z)
end

-- Samples are dense/exhaustive at the caller's chosen construction gate.
-- Each row is {layer_id, x, z}; oracle returns the authoritative scalar.
function index128.verify(attached, samples, oracle)
	if type(samples) ~= "table" or type(oracle) ~= "function" then
		fail("verification inputs missing")
	end
	local sample_count = dense_count(samples, "verification samples")
	for i = 1, sample_count do
		local sample = samples[i]
		if dense_count(sample, "verification sample") ~= 3 then
			fail("verification sample must contain layer,x,z")
		end
		local accelerated = index128.query(attached, sample[1], sample[2], sample[3])
		local slow = oracle(sample[1], sample[2], sample[3])
		if accelerated ~= slow then
			fail(("oracle mismatch at sample %d (%s,%d,%d): %s ~= %s"):
				format(i, sample[1], sample[2], sample[3], tostring(accelerated),
					tostring(slow)))
		end
	end
	return true
end

index128.CELL_SIZE = CELL_SIZE
index128.floor_cell = floor_div

return index128
