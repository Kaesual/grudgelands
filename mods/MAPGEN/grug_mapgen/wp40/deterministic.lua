-- Full-seed hash lanes and exact integer division helpers.

local deterministic = {}

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

	return hash
end

deterministic.validate_seed = validate_seed
deterministic.round_ratio = round_ratio

return deterministic
