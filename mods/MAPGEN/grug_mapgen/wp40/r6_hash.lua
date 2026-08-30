-- Pure WP40 R6 hash and exact-integer arithmetic.

return function(raw_sha256)
	local MAX_SAFE = 9007199254740991
	local UINT32 = 4294967296
	local PREFIX = "grug_wp40_r6_hash_v1"
	local DOMAIN_VALUES = {
		"cultural_budget_remainder_v1",
		"cultural_candidate_rank_v1",
		"decoration_budget_remainder_v1",
		"decoration_candidate_rank_v1",
		"decoration_rotation_v1",
		"decoration_simple_height_v1",
		"evidence_cell_rank_v1",
		"evidence_substrate_v1",
		"resource_budget_remainder_v1",
		"resource_frontier_rank_v1",
		"resource_root_rank_v1",
		"template_probability_v1",
	}
	local DOMAIN_SET = {}
	for index = 1, #DOMAIN_VALUES do
		DOMAIN_SET[DOMAIN_VALUES[index]] = true
	end

	local function fail(message)
		error("fail_hash: " .. message, 0)
	end

	local function safe_integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				(minimum ~= nil and value < minimum) or
				(maximum ~= nil and value > maximum) then
			fail((label or "value") .. " is not an exact bounded integer")
		end
		return value
	end

	local function bound_integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			error("fail_bound: " .. label .. " is not an exact bounded integer", 0)
		end
		return value
	end

	local function less_bytes(left, right)
		if type(left) ~= "string" or type(right) ~= "string" then
			fail("byte-order input is not bytes")
		end
		local count = math.min(#left, #right)
		for index = 1, count do
			local left_byte, right_byte = string.byte(left, index), string.byte(right, index)
			if left_byte ~= right_byte then return left_byte < right_byte end
		end
		return #left < #right
	end

	local function integer_ascii(value)
		safe_integer(value, "canonical integer")
		if value == 0 then return "0" end
		return string.format("%.0f", value)
	end

	local function canon(value)
		if type(value) == "number" then return integer_ascii(value) end
		if type(value) ~= "string" then
			fail("canonical field is neither bytes nor integer")
		end
		return value
	end

	local function frame(value)
		local bytes = canon(value)
		return integer_ascii(#bytes) .. ":" .. bytes
	end

	local function raw_digest(domain, full_seed_string, fields)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 seam missing") end
		if not DOMAIN_SET[domain] then fail("unlisted domain " .. tostring(domain)) end
		if type(full_seed_string) ~= "string" then fail("full seed is not bytes") end
		if type(fields) ~= "table" then fail("field array missing") end
		local count = #fields
		for index = 1, count do
			if fields[index] == nil then fail("field array has a hole") end
		end
		for key in pairs(fields) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail("field array is not dense")
			end
		end
		local parts = {frame(PREFIX), frame(domain), frame(full_seed_string)}
		for index = 1, count do parts[#parts + 1] = frame(fields[index]) end
		local digest = raw_sha256(table.concat(parts))
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("raw SHA-256 result is not 32 bytes")
		end
		return digest
	end

	local function hex(bytes)
		if type(bytes) ~= "string" then fail("hex input is not bytes") end
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	local function words(digest)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("word input is not a SHA-256 digest")
		end
		local result = {}
		for word = 1, 8 do
			local offset = (word - 1) * 4
			local value = 0
			for byte = 1, 4 do
				value = value * 256 + string.byte(digest, offset + byte)
			end
			result[word] = value
		end
		return result
	end

	local function reduce_words(hi, lo, denominator)
		bound_integer(hi, "high digest word", 0, UINT32 - 1)
		bound_integer(lo, "low digest word", 0, UINT32 - 1)
		bound_integer(denominator, "modular denominator", 1, 48000)
		local power = UINT32 % denominator
		return ((hi % denominator) * power + (lo % denominator)) % denominator
	end

	local function reduce_digest(digest, denominator)
		local digest_words = words(digest)
		return reduce_words(digest_words[1], digest_words[2], denominator)
	end

	local function budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, digest)
		bound_integer(eligible, "eligible count", 0, 4096)
		bound_integer(numerator_factor, "density numerator", 1, 3)
		bound_integer(density_denominator, "density denominator", 1, 12000)
		bound_integer(multiplier_numerator, "multiplier numerator", 1, 5)
		bound_integer(multiplier_denominator, "multiplier denominator", 1, 4)
		local numerator = eligible * numerator_factor * multiplier_numerator
		local denominator = density_denominator * multiplier_denominator
		if numerator > MAX_SAFE or denominator > 48000 then
			error("fail_bound: R6 budget intermediate exceeds bound", 0)
		end
		local base = math.floor(numerator / denominator)
		local remainder = numerator - base * denominator
		local trial = remainder > 0 and reduce_digest(digest, denominator) < remainder
		local value = base + (trial and 1 or 0)
		if value < 0 or value > eligible then
			error("fail_bound: R6 budget is outside eligible population", 0)
		end
		return value, numerator, denominator, base, remainder, trial
	end

	local module = {}
	function module.domains()
		local copy = {}
		for index = 1, #DOMAIN_VALUES do copy[index] = DOMAIN_VALUES[index] end
		return copy
	end
	function module.frame(value) return frame(value) end
	function module.digest(domain, full_seed_string, fields)
		return raw_digest(domain, full_seed_string, fields)
	end
	function module.digest_hex(domain, full_seed_string, fields)
		return hex(raw_digest(domain, full_seed_string, fields))
	end
	function module.hex(bytes) return hex(bytes) end
	function module.less_bytes(left, right) return less_bytes(left, right) end
	function module.sha256_bytes(bytes)
		if type(bytes) ~= "string" then fail("SHA-256 input is not bytes") end
		local digest = raw_sha256(bytes)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("raw SHA-256 result is not 32 bytes")
		end
		return digest
	end
	function module.words(digest) return words(digest) end
	function module.reduce_words(hi, lo, denominator)
		return reduce_words(hi, lo, denominator)
	end
	function module.reduce_digest(digest, denominator)
		return reduce_digest(digest, denominator)
	end
	function module.budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, digest)
		return budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, digest)
	end
	return module
end
