-- Full-seed hash lanes and integer/Q16.16 deterministic arithmetic.

local deterministic = {}

local Q = 65536
local U32 = 4294967296
local MAX_SAFE = 9007199254740991

local function fail(message)
	error("WP40 deterministic: " .. message, 0)
end

local function integer(value, minimum, maximum, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail((label or "value") .. " is outside its integer range")
	end
	return value
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

local function safe_product(a, b, label)
	integer(a, -MAX_SAFE, MAX_SAFE, label)
	integer(b, -MAX_SAFE, MAX_SAFE, label)
	local aa, bb = math.abs(a), math.abs(b)
	if aa ~= 0 and bb > math.floor(MAX_SAFE / aa) then
		fail((label or "product") .. " exceeds the exact Lua integer range")
	end
	return a * b
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

local function round_ratio(numerator, denominator)
	integer(numerator, -MAX_SAFE, MAX_SAFE, "round numerator")
	integer(denominator, 1, MAX_SAFE, "round denominator")
	local sign = numerator < 0 and -1 or 1
	local quotient, remainder = divmod_nonnegative(math.abs(numerator),
		denominator)
	local half = math.floor(denominator / 2) + denominator % 2
	if remainder >= half then quotient = quotient + 1 end
	return sign * quotient
end

function deterministic.floor_div(value, divisor)
	integer(value, -MAX_SAFE, MAX_SAFE, "floor dividend")
	integer(divisor, 1, MAX_SAFE, "floor divisor")
	local quotient, remainder = divmod_nonnegative(math.abs(value), divisor)
	if value >= 0 then return quotient end
	if remainder == 0 then return -quotient end
	return -quotient - 1
end

function deterministic.floor_mod(value, divisor)
	integer(value, -MAX_SAFE, MAX_SAFE, "floor dividend")
	integer(divisor, 1, MAX_SAFE, "floor divisor")
	local _, remainder = divmod_nonnegative(math.abs(value), divisor)
	if value >= 0 or remainder == 0 then return remainder end
	return divisor - remainder
end

function deterministic.qfrom_ratio(numerator, denominator)
	return round_ratio(safe_product(numerator, Q, "Q ratio"), denominator)
end

function deterministic.qround(value)
	return round_ratio(value, Q)
end

function deterministic.qmul(a, b)
	return round_ratio(safe_product(a, b, "qmul"), Q)
end

function deterministic.qdiv(a, b)
	if b == 0 then fail("qdiv denominator is zero") end
	local product = safe_product(a, Q, "qdiv")
	if b < 0 then product, b = -product, -b end
	return round_ratio(product, b)
end

function deterministic.clamp(value, minimum, maximum)
	if value < minimum then return minimum end
	if value > maximum then return maximum end
	return value
end

function deterministic.qlerp(a, b, t)
	integer(a, -MAX_SAFE, MAX_SAFE, "lerp start")
	integer(b, -MAX_SAFE, MAX_SAFE, "lerp end")
	t = deterministic.clamp(t, 0, Q)
	integer(t, -MAX_SAFE, MAX_SAFE, "lerp fraction")
	local delta = b - a
	integer(delta, -MAX_SAFE, MAX_SAFE, "lerp delta")
	local result = a + deterministic.qmul(delta, t)
	return integer(result, -MAX_SAFE, MAX_SAFE, "lerp result")
end

function deterministic.smootherstep(q)
	q = deterministic.clamp(q, 0, Q)
	local q2 = deterministic.qmul(q, q)
	local q3 = deterministic.qmul(q2, q)
	local q4 = deterministic.qmul(q3, q)
	local q5 = deterministic.qmul(q4, q)
	local value = safe_product(6, q5, "smootherstep") -
		safe_product(15, q4, "smootherstep") +
		safe_product(10, q3, "smootherstep")
	return deterministic.clamp(value, 0, Q)
end

function deterministic.isqrt(value)
	integer(value, 0, MAX_SAFE, "isqrt value")
	local low = 0
	local high = math.min(value, 94906265)
	local answer = 0
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if middle == 0 or middle * middle <= value then
			answer = middle
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return answer
end

local function validate_seed(seed)
	if type(seed) ~= "string" or
			(seed ~= "0" and not seed:match("^[1-9][0-9]*$")) then
		fail("full seed is not canonical unsigned decimal text")
	end
	local max_u64 = "18446744073709551615"
	if #seed > #max_u64 or (#seed == #max_u64 and seed > max_u64) then
		fail("full seed exceeds unsigned 64-bit decimal range")
	end
	return seed
end

local function digest_word(digest, word_index)
	if type(digest) ~= "string" or #digest ~= 32 then
		fail("raw SHA-256 injection did not return 32 bytes")
	end
	local offset = word_index * 4 + 1
	local a, b, c, d = digest:byte(offset, offset + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

function deterministic.new_hash(canonical, raw_sha256, schema, seed)
	if type(canonical) ~= "table" or type(canonical.encode) ~= "function" then
		fail("canonical encoder injection missing")
	end
	if type(raw_sha256) ~= "function" then fail("raw SHA-256 injection missing") end
	if type(schema) ~= "string" or schema == "" then fail("schema text missing") end
	seed = validate_seed(seed)
	local prefix = "GRUGWP40HASH" .. string.char(0)

	local function input(domain, feature, coordinates, candidate, block, rejection)
		if type(domain) ~= "string" or domain == "" then fail("hash domain missing") end
		feature = feature or ""
		if type(feature) ~= "string" then fail("feature ID is not text") end
		if type(coordinates) ~= "table" or
				(#coordinates ~= 2 and #coordinates ~= 3) then
			fail("hash coordinates must be x,z or x,y,z")
		end
		local coordinate_count = dense_count(coordinates, "hash coordinates")
		if coordinate_count ~= 2 and coordinate_count ~= 3 then
			fail("hash coordinates must be x,z or x,y,z")
		end
		local encoded_coordinates = {}
		for i = 1, coordinate_count do
			encoded_coordinates[i] = canonical.signed(coordinates[i])
		end
		return prefix ..
			canonical.encode(canonical.text(schema)) ..
			canonical.encode(canonical.text(domain)) ..
			canonical.encode(canonical.text(seed)) ..
			canonical.encode(canonical.text(feature)) ..
			canonical.encode(canonical.array(encoded_coordinates)) ..
			canonical.encode(canonical.unsigned(candidate)) ..
			canonical.encode(canonical.unsigned(block)) ..
			canonical.encode(canonical.unsigned(rejection))
	end

	local hash = {}

	function hash.word(domain, feature, coordinates, candidate, lane, rejection)
		integer(candidate, 0, 4294967295, "candidate index")
		integer(lane, 0, 4294967295, "logical lane")
		rejection = rejection or 0
		integer(rejection, 0, 4294967295, "rejection counter")
		local block = math.floor(lane / 8)
		local digest = raw_sha256(input(domain, feature, coordinates, candidate,
			block, rejection))
		return digest_word(digest, lane % 8)
	end

	function hash.range(domain, feature, coordinates, candidate, lane, size)
		integer(size, 1, U32, "range size")
		local limit = math.floor(U32 / size) * size
		local rejection = 0
		while true do
			local word = hash.word(domain, feature, coordinates, candidate, lane,
				rejection)
			if word < limit then return word % size end
			if rejection == 4294967295 then fail("rejection counter exhausted") end
			rejection = rejection + 1
		end
	end

	function hash.unit_word(domain, feature, coordinates, candidate, lane)
		return hash.word(domain, feature, coordinates, candidate, lane, 0) / U32
	end

	function hash.signed_noise(domain, feature, coordinates, candidate, lane)
		return hash.range(domain, feature, coordinates, candidate, lane,
			2 * Q + 1) - Q
	end

	function hash.seed_hash()
		return raw_sha256(canonical.encode(canonical.text(seed)))
	end

	return hash
end

-- Definition fields: schema, seed, domain, feature and ordered octaves.
-- Each octave is {period = positive integer, amplitude_numerator = signed
-- integer, amplitude_denominator = positive integer}. No field catalog lives
-- here; T2 supplies authored definitions.
function deterministic.value_noise_2d(canonical, raw_sha256, definition, x, z)
	integer(x, -2147483648, 2147483647, "noise x")
	integer(z, -2147483648, 2147483647, "noise z")
	if type(definition) ~= "table" or type(definition.octaves) ~= "table" then
		fail("noise definition missing")
	end
	local octave_count = dense_count(definition.octaves, "noise octaves")
	local hash = deterministic.new_hash(canonical, raw_sha256,
		definition.schema, definition.seed)
	local total = 0
	for octave_index = 1, octave_count do
		local octave = definition.octaves[octave_index]
		local period = integer(octave.period, 1, 2147483647, "noise period")
		local lx = deterministic.floor_div(x, period)
		local lz = deterministic.floor_div(z, period)
		local tx = deterministic.qdiv(deterministic.floor_mod(x, period), period)
		local tz = deterministic.qdiv(deterministic.floor_mod(z, period), period)
		local lane = octave_index - 1
		local c00 = hash.signed_noise(definition.domain, definition.feature,
			{lx, lz}, 0, lane)
		local c10 = hash.signed_noise(definition.domain, definition.feature,
			{lx + 1, lz}, 0, lane)
		local c01 = hash.signed_noise(definition.domain, definition.feature,
			{lx, lz + 1}, 0, lane)
		local c11 = hash.signed_noise(definition.domain, definition.feature,
			{lx + 1, lz + 1}, 0, lane)
		local sx = deterministic.smootherstep(tx)
		local sz = deterministic.smootherstep(tz)
		local top = deterministic.qlerp(c00, c10, sx)
		local bottom = deterministic.qlerp(c01, c11, sx)
		local value = deterministic.qlerp(top, bottom, sz)
		local amplitude = deterministic.qfrom_ratio(octave.amplitude_numerator,
			octave.amplitude_denominator)
		total = total + deterministic.qmul(value, amplitude)
		integer(total, -MAX_SAFE, MAX_SAFE, "noise accumulation")
	end
	return total
end

deterministic.Q = Q
deterministic.U32 = U32
deterministic.MAX_SAFE = MAX_SAFE
deterministic.validate_seed = validate_seed
deterministic.safe_product = safe_product
deterministic.round_ratio = round_ratio

return deterministic
