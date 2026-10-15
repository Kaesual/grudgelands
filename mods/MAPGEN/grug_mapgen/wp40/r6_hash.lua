-- Pure WP40 R6 hash and exact-integer arithmetic.

return function(raw_sha256)
	local MAX_SAFE = 9007199254740991
	local PREFIX = "grug_wp40_r6_hash_v1"
	-- The SHA-256 domains still in use: since Round 49 (lane HASH) only the
	-- seeded trees' template seeds (tree_templates.lua), a handful per world at
	-- construction. Every placement draw uses the integer placement hash below.
	local DOMAIN_VALUES = {
		"tree_template_seed_v1",
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

	local digest_parts = {}
	local function raw_digest_count(domain, full_seed_string, fields, count,
			require_dense)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 seam missing") end
		if not DOMAIN_SET[domain] then fail("unlisted domain " .. tostring(domain)) end
		if type(full_seed_string) ~= "string" then fail("full seed is not bytes") end
		if type(fields) ~= "table" then fail("field array missing") end
		safe_integer(count, "field count", 0, 32)
		for index = 1, count do
			if fields[index] == nil then fail("field array has a hole") end
		end
		if require_dense then
			for key in pairs(fields) do
				if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
					fail("field array is not dense")
				end
			end
		end
		digest_parts[1], digest_parts[2], digest_parts[3] =
			frame(PREFIX), frame(domain), frame(full_seed_string)
		for index = 1, count do digest_parts[index + 3] = frame(fields[index]) end
		local digest = raw_sha256(table.concat(digest_parts, "", 1, count + 3))
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("raw SHA-256 result is not 32 bytes")
		end
		return digest
	end

	local function raw_digest(domain, full_seed_string, fields)
		return raw_digest_count(domain, full_seed_string, fields, #fields, true)
	end

	local function hex(bytes)
		if type(bytes) ~= "string" then fail("hex input is not bytes") end
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	-- The integer placement hash (Round 49 lane HASH, mapgen-native-plan.md
	-- §4.5): the draws of the decoration candidates (rank, thinning, budget
	-- remainder), rotations, heights, variants and template probabilities
	-- (P9), the gathering sources (P9G) and the fill ores (P8), instead of a
	-- framed SHA-256 digest each (about 0.95 us against 0.01 us).
	--
	-- `mix(a, b, c, salt)`: a linear lattice term of three integers and the
	-- world's phase, then two squarings modulo the prime 2^24 - 3 for mixing.
	-- Every product stays below 2^53 (|a|, |b|, |c| up to about 10^8, the
	-- salt below 2^31), there is no `bit` library, and `%` on negative values
	-- floors in both interpreters, so LuaJIT and plain Lua 5.1 agree exactly.
	-- The result is an integer in [0, PLACEMENT_PRIME); consumers take `% n`
	-- (n at most 65536, so the bias stays below 0.4 %). This is the fill-ore
	-- hash Round 49 lane ORE introduced, moved here unchanged so there is one.
	-- `salt(domain, id)`: the salt of one stream, a byte hash of the domain,
	-- the row id and the full seed, so different purposes, rows and worlds
	-- draw independently (tools/r49_hash checks uniformity, neighbour and
	-- salt independence, and LuaJIT against plain Lua 5.1). A world's fill
	-- ores salt by resource index alone (r6_settlement.lua r49_fill_ores_new).
	-- More than three inputs chain: `mix(d, e, f, mix(a, b, c, salt))`.
	local PLACEMENT_PRIME = 16777213
	local PLACEMENT_DOMAINS = {
		"decoration_budget_remainder", "decoration_candidate_rank",
		"decoration_candidate_thin", "decoration_rotation",
		"decoration_simple_height", "decoration_variant",
		"gathering_budget_remainder", "gathering_candidate_rank",
		"template_probability",
	}
	local PLACEMENT_DOMAIN_SET = {}
	for index = 1, #PLACEMENT_DOMAINS do
		PLACEMENT_DOMAIN_SET[PLACEMENT_DOMAINS[index]] = true
	end
	local function placement(full_seed_string)
		if type(full_seed_string) ~= "string" or full_seed_string == "" then
			fail("placement full seed is not bytes")
		end
		local phase = 0
		for index = 1, #full_seed_string do
			phase = (phase * 131 + string.byte(full_seed_string, index)) % 65521
		end
		local function mix(a, b, c, salt)
			local value = (a * 374761 + b * 668265 + c * 972663 + phase * 69069 +
				salt) % 16777213
			value = (value * value + salt) % 16777213
			value = (value * 48271 + 1) % 16777213
			return (value * value) % 16777213
		end
		local function salt(domain, id)
			if not PLACEMENT_DOMAIN_SET[domain] then
				fail("unlisted placement domain " .. tostring(domain))
			end
			if type(id) ~= "string" then fail("placement stream id is not bytes") end
			local bytes = domain .. "\0" .. id .. "\0" .. full_seed_string
			local value = 0
			for index = 1, #bytes do
				value = (value * 257 + string.byte(bytes, index)) % 2147483647
			end
			return value
		end
		return mix, salt
	end

	-- A cell budget: the expected count's integer part, plus one when the
	-- stream's `draw` (a placement hash value) falls below the remainder.
	local function budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, draw)
		bound_integer(eligible, "eligible count", 0, 4096)
		bound_integer(numerator_factor, "density numerator", 1, 3)
		bound_integer(density_denominator, "density denominator", 1, 12000)
		bound_integer(multiplier_numerator, "multiplier numerator", 1, 5)
		bound_integer(multiplier_denominator, "multiplier denominator", 1, 4)
		bound_integer(draw, "budget draw", 0, PLACEMENT_PRIME - 1)
		local numerator = eligible * numerator_factor * multiplier_numerator
		local denominator = density_denominator * multiplier_denominator
		if numerator > MAX_SAFE or denominator > 48000 then
			error("fail_bound: R6 budget intermediate exceeds bound", 0)
		end
		local base = math.floor(numerator / denominator)
		local remainder = numerator - base * denominator
		local trial = remainder > 0 and draw % denominator < remainder
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
	function module.digest_count(domain, full_seed_string, fields, count)
		return raw_digest_count(domain, full_seed_string, fields, count, false)
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
	module.PLACEMENT_PRIME = PLACEMENT_PRIME
	function module.placement_domains()
		local copy = {}
		for index = 1, #PLACEMENT_DOMAINS do copy[index] = PLACEMENT_DOMAINS[index] end
		return copy
	end
	function module.placement(full_seed_string) return placement(full_seed_string) end
	function module.budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, draw)
		return budget(eligible, numerator_factor, density_denominator,
			multiplier_numerator, multiplier_denominator, draw)
	end
	return module
end
