-- Generic world-aligned 128x128 acceleration grid. Geometry remains in the
-- caller's exact evaluator; this module only compiles and verifies candidates.

local index128 = {}

local CELL_SIZE = 128
local MAX_SAFE = 9007199254740991
local MAX_CELL = math.floor(MAX_SAFE / CELL_SIZE)
local EMPTY_CANDIDATES = {}

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

local function exact_fields(value, fields, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	local expected = {}
	for i = 1, #fields do expected[fields[i]] = true end
	for key in pairs(value) do
		if not expected[key] then fail(label .. " has unknown field " .. tostring(key)) end
	end
	for i = 1, #fields do
		if value[fields[i]] == nil then fail(label .. " is missing field " .. fields[i]) end
	end
	return value
end

local function text_id(value, label)
	if type(value) ~= "string" or value == "" then
		fail(label .. " is not non-empty text")
	end
	return value
end

local function safe_add(a, b, label)
	integer(a, label .. " left")
	integer(b, label .. " right")
	if (b > 0 and a > MAX_SAFE - b) or (b < 0 and a < -MAX_SAFE - b) then
		fail(label .. " is outside the exact Lua integer range")
	end
	return a + b
end

local function safe_multiply(a, b, label)
	integer(a, label .. " left")
	integer(b, label .. " right")
	if a ~= 0 and math.abs(b) > math.floor(MAX_SAFE / math.abs(a)) then
		fail(label .. " is outside the exact Lua integer range")
	end
	return a * b
end

local function safe_subtract(a, b, label)
	return safe_add(a, -b, label)
end

local function safe_square(value, label)
	return safe_multiply(value, value, label)
end

local function safe_squared_sum(a, b, label)
	return safe_add(safe_square(a, label .. " x"),
		safe_square(b, label .. " z"), label)
end

local function divmod_nonnegative(numerator, denominator)
	local quotient = math.floor(numerator / denominator)
	local product = quotient * denominator
	while product > numerator do
		quotient = quotient - 1
		product = product - denominator
	end
	while numerator - product >= denominator do
		quotient = quotient + 1
		product = product + denominator
	end
	return quotient, numerator - product
end

-- Continued fractions compare exact non-negative ratios without multiplying
-- arbitrary numerators and denominators.
local function rational_compare(a, b, c, d)
	integer(a, "left ratio numerator", 0)
	integer(b, "left ratio denominator", 1)
	integer(c, "right ratio numerator", 0)
	integer(d, "right ratio denominator", 1)
	local direction = 1
	while true do
		local left, left_remainder = divmod_nonnegative(a, b)
		local right, right_remainder = divmod_nonnegative(c, d)
		if left < right then return -direction end
		if left > right then return direction end
		if left_remainder == 0 or right_remainder == 0 then
			if left_remainder == right_remainder then return 0 end
			return (left_remainder == 0 and -1 or 1) * direction
		end
		a, b = b, left_remainder
		c, d = d, right_remainder
		direction = -direction
	end
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

local function sparse_bounds(definition, label)
	local min_x = integer(definition.min_x, label .. " min_x")
	local max_x = integer(definition.max_x, label .. " max_x")
	local min_z = integer(definition.min_z, label .. " min_z")
	local max_z = integer(definition.max_z, label .. " max_z")
	if min_x > max_x or min_z > max_z then fail(label .. " bounds are empty") end
	safe_add(max_x, 1, label .. " max_x half-open bound")
	safe_add(max_z, 1, label .. " max_z half-open bound")
	return min_x, max_x, min_z, max_z
end

local function new_sparse_cells(min_x, max_x, min_z, max_z)
	return {}, floor_div(min_x), floor_div(max_x), floor_div(min_z),
		floor_div(max_z)
end

local function add_sparse_candidate(compiled, cx, cz, candidate)
	local column = compiled.cells[cx]
	if not column then
		column = {}
		compiled.cells[cx] = column
	end
	local cell = column[cz]
	if not cell then
		cell = {}
		column[cz] = cell
		compiled.metrics.populated_cells = compiled.metrics.populated_cells + 1
	end
	cell[#cell + 1] = candidate
	compiled.metrics.candidate_references =
		compiled.metrics.candidate_references + 1
end

local function check_sparse_schema(definition, expected_schema, label)
	if type(expected_schema) ~= "string" or expected_schema == "" then
		fail("expected " .. label .. " schema missing")
	end
	if definition.schema ~= expected_schema then fail(label .. " schema mismatch") end
end

-- Compile flattened, non-degenerate polyline segments into sparse cells.
-- `segment` is the raw one-based source point-pair ordinal; it is never
-- renumbered here. The returned object is session-private index data.
function index128.compile_sparse_segments(definition, expected_schema)
	exact_fields(definition, {"schema", "min_x", "max_x", "min_z", "max_z",
		"tie_break", "segments"}, "sparse segment definition")
	check_sparse_schema(definition, expected_schema, "sparse segment")
	if definition.tie_break ~= "feature_id" and
			definition.tie_break ~= "feature_order" then
		fail("sparse segment tie_break is invalid")
	end
	local min_x, max_x, min_z, max_z = sparse_bounds(definition,
		"sparse segment")
	local cells, min_cx, max_cx, min_cz, max_cz =
		new_sparse_cells(min_x, max_x, min_z, max_z)
	local compiled = {
		_index128_kind = "sparse_segments",
		schema = definition.schema,
		cell_size = CELL_SIZE,
		min_x = min_x, max_x = max_x, min_z = min_z, max_z = max_z,
		min_cx = min_cx, max_cx = max_cx,
		min_cz = min_cz, max_cz = max_cz,
		tie_break = definition.tie_break,
		segments = {}, cells = cells,
		metrics = {segment_count = 0, populated_cells = 0,
			candidate_references = 0, maximum_candidates = 0},
	}
	local segment_count = dense_count(definition.segments,
		"sparse segment records")
	if segment_count == 0 then fail("sparse segment records are empty") end
	local feature_ordinals = {}
	local feature_orders = {}
	local order_features = {}
	for record_index = 1, segment_count do
		local input = exact_fields(definition.segments[record_index],
			{"feature_id", "feature_order", "segment", "ax", "az", "bx", "bz"},
			"sparse segment record")
		local feature_id = text_id(input.feature_id, "segment feature_id")
		local feature_order = integer(input.feature_order,
			"segment feature_order", 1)
		local segment = integer(input.segment, "segment ordinal", 1)
		local ax = integer(input.ax, "segment ax", min_x, max_x)
		local az = integer(input.az, "segment az", min_z, max_z)
		local bx = integer(input.bx, "segment bx", min_x, max_x)
		local bz = integer(input.bz, "segment bz", min_z, max_z)
		if ax == bx and az == bz then fail("sparse segment is degenerate") end
		if feature_orders[feature_id] and
				feature_orders[feature_id] ~= feature_order then
			fail("segment feature has inconsistent source order")
		end
		if order_features[feature_order] and
				order_features[feature_order] ~= feature_id then
			fail("segment source order is not unique")
		end
		feature_orders[feature_id] = feature_order
		order_features[feature_order] = feature_id
		local ordinals = feature_ordinals[feature_id]
		if not ordinals then
			ordinals = {count = 0, maximum = 0}
			feature_ordinals[feature_id] = ordinals
		end
		if ordinals[segment] then fail("duplicate compiled segment identity") end
		ordinals[segment] = true
		ordinals.count = ordinals.count + 1
		ordinals.maximum = math.max(ordinals.maximum, segment)
		local record = {feature_id = feature_id, feature_order = feature_order,
			segment = segment, ax = ax, az = az, bx = bx, bz = bz}
		compiled.segments[record_index] = record
		local bbox_min_x, bbox_max_x = math.min(ax, bx),
			safe_add(math.max(ax, bx), 1, "segment bbox max_x")
		local bbox_min_z, bbox_max_z = math.min(az, bz),
			safe_add(math.max(az, bz), 1, "segment bbox max_z")
		local first_cx, last_cx = floor_div(bbox_min_x),
			floor_div(bbox_max_x - 1)
		local first_cz, last_cz = floor_div(bbox_min_z),
			floor_div(bbox_max_z - 1)
		for cx = first_cx, last_cx do
			for cz = first_cz, last_cz do
				add_sparse_candidate(compiled, cx, cz, record_index)
			end
		end
	end
	for feature_id, ordinals in pairs(feature_ordinals) do
		if ordinals.count ~= ordinals.maximum then
			fail("raw segment ordinals are not dense for " .. feature_id)
		end
	end
	local function segment_less(left_index, right_index)
		local left, right = compiled.segments[left_index],
			compiled.segments[right_index]
		if compiled.tie_break == "feature_id" then
			if left.feature_id ~= right.feature_id then
				return left.feature_id < right.feature_id
			end
		else
			if left.feature_order ~= right.feature_order then
				return left.feature_order < right.feature_order
			end
		end
		return left.segment < right.segment
	end
	for _, column in pairs(compiled.cells) do
		for _, candidates in pairs(column) do
			table.sort(candidates, segment_less)
			compiled.metrics.maximum_candidates = math.max(
				compiled.metrics.maximum_candidates, #candidates)
		end
	end
	compiled.metrics.segment_count = segment_count
	return compiled
end

-- Compile complete half-open footprint bboxes. Exact shape membership remains
-- with the caller; this layer only returns borrowed, read-only candidate IDs.
function index128.compile_footprints(definition, expected_schema)
	exact_fields(definition, {"schema", "min_x", "max_x", "min_z", "max_z",
		"records"}, "footprint definition")
	check_sparse_schema(definition, expected_schema, "footprint")
	local min_x, max_x, min_z, max_z = sparse_bounds(definition, "footprint")
	local cells, min_cx, max_cx, min_cz, max_cz =
		new_sparse_cells(min_x, max_x, min_z, max_z)
	local compiled = {
		_index128_kind = "footprints",
		schema = definition.schema,
		cell_size = CELL_SIZE,
		min_x = min_x, max_x = max_x, min_z = min_z, max_z = max_z,
		min_cx = min_cx, max_cx = max_cx,
		min_cz = min_cz, max_cz = max_cz,
		cells = cells,
		metrics = {record_count = 0, populated_cells = 0,
			candidate_references = 0, maximum_candidates = 0},
	}
	local record_count = dense_count(definition.records, "footprint records")
	local ids = {}
	for record_index = 1, record_count do
		local input = exact_fields(definition.records[record_index], {"id", "bbox"},
			"footprint record")
		local id = text_id(input.id, "footprint id")
		if ids[id] then fail("duplicate footprint id " .. id) end
		ids[id] = true
		exact_fields(input.bbox, {"min_x", "max_x", "min_z", "max_z"},
			"footprint bbox")
		validate_bbox(input.bbox)
		if input.bbox.min_x < min_x or input.bbox.max_x > max_x + 1 or
				input.bbox.min_z < min_z or input.bbox.max_z > max_z + 1 then
			fail("footprint bbox is outside query bounds")
		end
		local first_cx, last_cx = floor_div(input.bbox.min_x),
			floor_div(input.bbox.max_x - 1)
		local first_cz, last_cz = floor_div(input.bbox.min_z),
			floor_div(input.bbox.max_z - 1)
		for cx = first_cx, last_cx do
			for cz = first_cz, last_cz do
				add_sparse_candidate(compiled, cx, cz, id)
			end
		end
	end
	for _, column in pairs(compiled.cells) do
		for _, candidates in pairs(column) do
			table.sort(candidates)
			for index = 2, #candidates do
				if candidates[index - 1] == candidates[index] then
					fail("duplicate footprint cell candidate")
				end
			end
			compiled.metrics.maximum_candidates = math.max(
				compiled.metrics.maximum_candidates, #candidates)
		end
	end
	compiled.metrics.record_count = record_count
	return compiled
end

local function assert_sparse_kind(compiled, wanted)
	if type(compiled) ~= "table" or compiled._index128_kind ~= wanted or
			compiled.cell_size ~= CELL_SIZE or type(compiled.cells) ~= "table" then
		fail("compiled " .. wanted .. " index is invalid")
	end
	return compiled
end

function index128.footprint_candidates(compiled, x, z)
	assert_sparse_kind(compiled, "footprints")
	integer(x, "footprint query x")
	integer(z, "footprint query z")
	if x < compiled.min_x or x > compiled.max_x or
			z < compiled.min_z or z > compiled.max_z then
		return EMPTY_CANDIDATES
	end
	local column = compiled.cells[floor_div(x)]
	if not column then return EMPTY_CANDIDATES end
	return column[floor_div(z)] or EMPTY_CANDIDATES
end

local function point_segment_distance(x, z, segment)
	local vx = safe_subtract(segment.bx, segment.ax, "segment vector x")
	local vz = safe_subtract(segment.bz, segment.az, "segment vector z")
	local wx = safe_subtract(x, segment.ax, "query vector x")
	local wz = safe_subtract(z, segment.az, "query vector z")
	local length_squared = safe_squared_sum(vx, vz, "segment length squared")
	local dot = safe_add(safe_multiply(wx, vx, "segment dot x"),
		safe_multiply(wz, vz, "segment dot z"), "segment dot")
	if dot <= 0 then return safe_squared_sum(wx, wz, "start distance"), 1 end
	if dot >= length_squared then
		return safe_squared_sum(safe_subtract(x, segment.bx, "end delta x"),
			safe_subtract(z, segment.bz, "end delta z"), "end distance"), 1
	end
	local cross = safe_subtract(
		safe_multiply(wx, vz, "segment cross left"),
		safe_multiply(wz, vx, "segment cross right"), "segment cross")
	return safe_square(cross, "segment cross squared"), length_squared
end

local function segment_tie_less(compiled, left, right)
	if compiled.tie_break == "feature_id" then
		if left.feature_id ~= right.feature_id then
			return left.feature_id < right.feature_id
		end
	else
		if left.feature_order ~= right.feature_order then
			return left.feature_order < right.feature_order
		end
	end
	return left.segment < right.segment
end

local function cell_distance_squared(x, z, cx, cz)
	local min_x = safe_multiply(cx, CELL_SIZE, "cell minimum x")
	local min_z = safe_multiply(cz, CELL_SIZE, "cell minimum z")
	local max_x = safe_add(min_x, CELL_SIZE - 1, "cell maximum x")
	local max_z = safe_add(min_z, CELL_SIZE - 1, "cell maximum z")
	local dx, dz = 0, 0
	if x < min_x then dx = min_x - x elseif x > max_x then dx = x - max_x end
	if z < min_z then dz = min_z - z elseif z > max_z then dz = z - max_z end
	return safe_squared_sum(dx, dz, "cell distance squared")
end

local function scratch_integer(scratch, key, label, minimum, maximum)
	return integer(rawget(scratch, key), label, minimum, maximum)
end

local function validate_nearest_scratch(compiled, scratch)
	if type(scratch) ~= "table" or
			not rawequal(rawget(scratch, "_index128_compiled"), compiled) then
		fail("nearest scratch identity differs")
	end
	local capacity = dense_count(compiled.segments, "compiled sparse segments")
	if scratch_integer(scratch, "_index128_capacity", "nearest scratch capacity",
			1, MAX_SAFE) ~= capacity then
		fail("nearest scratch capacity differs")
	end
	scratch_integer(scratch, "_index128_generation",
		"nearest scratch generation", 0, MAX_SAFE)
	for index = 1, capacity do
		integer(rawget(scratch, index), "nearest scratch seen generation", 0,
			MAX_SAFE)
	end
	return capacity
end

local function advance_nearest_generation(scratch, capacity)
	local generation = rawget(scratch, "_index128_generation")
	if generation == MAX_SAFE then
		for index = 1, capacity do scratch[index] = 0 end
		generation = 1
	else
		generation = generation + 1
	end
	scratch._index128_generation = generation
	return generation
end

local function reset_nearest_state(scratch)
	scratch._index128_best_index = 0
	scratch._index128_best_numerator = 0
	scratch._index128_best_denominator = 1
	scratch._index128_cells_scanned = 0
	scratch._index128_candidates_scanned = 0
end

local function scan_nearest_cell(compiled, x, z, cx, cz, scratch,
		generation)
	if cx < compiled.min_cx or cx > compiled.max_cx or
			cz < compiled.min_cz or cz > compiled.max_cz then
		return
	end
	scratch._index128_cells_scanned =
		scratch._index128_cells_scanned + 1
	local column = compiled.cells[cx]
	local candidates = column and column[cz]
	if not candidates then return end
	for index = 1, #candidates do
		local segment_index = candidates[index]
		if scratch[segment_index] ~= generation then
			scratch[segment_index] = generation
			scratch._index128_candidates_scanned =
				scratch._index128_candidates_scanned + 1
			local segment = compiled.segments[segment_index]
			local numerator, denominator = point_segment_distance(x, z, segment)
			local best_index = scratch._index128_best_index
			local comparison = best_index ~= 0 and rational_compare(numerator,
				denominator, scratch._index128_best_numerator,
				scratch._index128_best_denominator) or -1
			if best_index == 0 or comparison < 0 or
					(comparison == 0 and segment_tie_less(compiled, segment,
						compiled.segments[best_index])) then
				scratch._index128_best_index = segment_index
				scratch._index128_best_numerator = numerator
				scratch._index128_best_denominator = denominator
			end
		end
	end
end

local function scan_nearest_ring(compiled, x, z, center_x, center_z, radius,
		scratch, generation)
	if radius == 0 then
		scan_nearest_cell(compiled, x, z, center_x, center_z, scratch,
			generation)
		return
	end
	local minimum_x, maximum_x = center_x - radius, center_x + radius
	local minimum_z, maximum_z = center_z - radius, center_z + radius
	for cx = minimum_x, maximum_x do
		scan_nearest_cell(compiled, x, z, cx, minimum_z, scratch, generation)
		scan_nearest_cell(compiled, x, z, cx, maximum_z, scratch, generation)
	end
	for cz = minimum_z + 1, maximum_z - 1 do
		scan_nearest_cell(compiled, x, z, minimum_x, cz, scratch, generation)
		scan_nearest_cell(compiled, x, z, maximum_x, cz, scratch, generation)
	end
end

local function consider_cell_lower_bound(compiled, x, z, cx, cz, minimum)
	if cx < compiled.min_cx or cx > compiled.max_cx or
			cz < compiled.min_cz or cz > compiled.max_cz then
		return minimum
	end
	local distance = cell_distance_squared(x, z, cx, cz)
	if minimum == nil or distance < minimum then return distance end
	return minimum
end

local function next_ring_lower_bound(compiled, x, z, center_x, center_z,
		radius)
	local next_radius = radius + 1
	local minimum_x, maximum_x = center_x - next_radius,
		center_x + next_radius
	local minimum_z, maximum_z = center_z - next_radius,
		center_z + next_radius
	local minimum
	for cx = minimum_x, maximum_x do
		minimum = consider_cell_lower_bound(compiled, x, z, cx, minimum_z,
			minimum)
		minimum = consider_cell_lower_bound(compiled, x, z, cx, maximum_z,
			minimum)
	end
	for cz = minimum_z + 1, maximum_z - 1 do
		minimum = consider_cell_lower_bound(compiled, x, z, minimum_x, cz,
			minimum)
		minimum = consider_cell_lower_bound(compiled, x, z, maximum_x, cz,
			minimum)
	end
	return minimum
end

local function nearest_segment_core(compiled, x, z, scratch)
	assert_sparse_kind(compiled, "sparse_segments")
	integer(x, "nearest query x")
	integer(z, "nearest query z")
	if x < compiled.min_x or x > compiled.max_x or
			z < compiled.min_z or z > compiled.max_z then
		return nil, nil, nil, nil, nil, nil, nil, nil
	end
	local capacity = validate_nearest_scratch(compiled, scratch)
	local generation = advance_nearest_generation(scratch, capacity)
	reset_nearest_state(scratch)
	local center_x, center_z = floor_div(x), floor_div(z)
	local maximum_radius = math.max(center_x - compiled.min_cx,
		compiled.max_cx - center_x, center_z - compiled.min_cz,
		compiled.max_cz - center_z)
	local radius = 0
	while radius <= maximum_radius do
		scan_nearest_ring(compiled, x, z, center_x, center_z, radius, scratch,
			generation)
		local lower_bound = next_ring_lower_bound(compiled, x, z,
			center_x, center_z, radius)
		local best_index = scratch._index128_best_index
		if lower_bound == nil or (best_index ~= 0 and rational_compare(
				lower_bound, 1, scratch._index128_best_numerator,
				scratch._index128_best_denominator) > 0) then break end
		radius = radius + 1
	end
	local best_index = scratch._index128_best_index
	if best_index == 0 then return nil, nil, nil, nil, nil, nil, nil, nil end
	local best = compiled.segments[best_index]
	return best.feature_id, best.feature_order, best.segment,
		scratch._index128_best_numerator,
		scratch._index128_best_denominator, radius + 1,
		scratch._index128_cells_scanned,
		scratch._index128_candidates_scanned
end

local function new_nearest_scratch(compiled)
	local scratch = {}
	local capacity = dense_count(compiled.segments, "compiled sparse segments")
	for index = 1, capacity do scratch[index] = 0 end
	scratch._index128_compiled = compiled
	scratch._index128_capacity = capacity
	scratch._index128_generation = 0
	reset_nearest_state(scratch)
	return scratch
end

function index128.nearest_segment_values(compiled, x, z, scratch)
	return nearest_segment_core(compiled, x, z, scratch)
end

function index128.nearest_segment(compiled, x, z)
	assert_sparse_kind(compiled, "sparse_segments")
	integer(x, "nearest query x")
	integer(z, "nearest query z")
	if x < compiled.min_x or x > compiled.max_x or
			z < compiled.min_z or z > compiled.max_z then return nil end
	local scratch = new_nearest_scratch(compiled)
	local feature_id, feature_order, segment, numerator, denominator,
		rings_scanned, cells_scanned, candidates_scanned =
		nearest_segment_core(compiled, x, z, scratch)
	if feature_id == nil then return nil end
	return {feature_id = feature_id, feature_order = feature_order,
		segment = segment, distance_numerator = numerator,
		distance_denominator = denominator,
		distance_squared = numerator / denominator,
		rings_scanned = rings_scanned, cells_scanned = cells_scanned,
		candidates_scanned = candidates_scanned}
end

function index128.sparse_metrics(compiled)
	if type(compiled) ~= "table" or
			(compiled._index128_kind ~= "sparse_segments" and
			compiled._index128_kind ~= "footprints") then
		fail("compiled sparse index is invalid")
	end
	local result = {kind = compiled._index128_kind, schema = compiled.schema,
		cell_size = CELL_SIZE, min_x = compiled.min_x, max_x = compiled.max_x,
		min_z = compiled.min_z, max_z = compiled.max_z}
	for key, value in pairs(compiled.metrics) do result[key] = value end
	return result
end

index128.CELL_SIZE = CELL_SIZE
index128.floor_cell = floor_div

return index128
