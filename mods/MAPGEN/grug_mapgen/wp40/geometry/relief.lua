-- Payload-free raw relief, exact landmark masks, collars, and ordered
-- landmark composition. Sessions own their bounded SHA memo and counters.

local function fail(message)
	error("WP40 relief: " .. message, 0)
end

local function dependency_contract(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {canonical = true, deterministic = true, exact = true,
		raw_sha256 = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	if type(value.canonical) ~= "table" or
			type(value.deterministic) ~= "table" or
			type(value.exact) ~= "table" or
			type(value.raw_sha256) ~= "function" then
		fail("canonical, deterministic, exact, or raw SHA dependency is missing")
	end
end

return function(dependencies)
	dependency_contract(dependencies)
	local canonical = dependencies.canonical
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	local injected_raw_sha256 = dependencies.raw_sha256
	local Q = deterministic.Q
	local MAX_SAFE = deterministic.MAX_SAFE
	local relief = {}

	local function plain_table(value, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain table")
		end
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

	local function integer(value, minimum, maximum, label)
		return exact.integer(value, minimum, maximum, label)
	end

	local function safe_add(a, b, label)
		integer(a, -MAX_SAFE, MAX_SAFE, label)
		integer(b, -MAX_SAFE, MAX_SAFE, label)
		return integer(a + b, -MAX_SAFE, MAX_SAFE, label)
	end

	local function qnodes(value, label)
		integer(value, -MAX_SAFE, MAX_SAFE, label)
		return exact.safe_signed_product(value, Q, label)
	end

	local function raw_height_from_noise(profile, water_level, noise_q)
		plain_table(profile, "relief profile")
		local minimum = integer(profile.min_above_water, -2147483648,
			2147483647, "profile minimum")
		local maximum = integer(profile.max_above_water, minimum,
			2147483647, "profile maximum")
		integer(water_level, -2147483648, 2147483647, "water level")
		integer(noise_q, -MAX_SAFE, MAX_SAFE, "raw noise Q16")
		local clamped = deterministic.clamp(noise_q, -Q, Q)
		local delta = maximum - minimum
		local product = exact.safe_signed_product(clamped + Q, delta,
			"raw relief height product")
		return integer(water_level + minimum + math.floor(product / (2 * Q)),
			-2147483648, 2147483647, "raw relief height")
	end

	local function mask_copy(row)
		plain_table(row, "landmark")
		if type(row.id) ~= "string" or row.id == "" or
			type(row.noise_domain) ~= "string" or row.noise_domain == "" then
			fail("landmark identity or noise domain is invalid")
		end
		local primitive = row.primitive
		if primitive ~= "rectangle" and primitive ~= "ellipse" and
				primitive ~= "capsule" then fail("landmark primitive is invalid") end
		plain_table(row.center, row.id .. " center")
		local center = {x = integer(row.center.x, -2147483648, 2147483647,
			row.id .. " center x"), z = integer(row.center.z, -2147483648,
			2147483647, row.id .. " center z")}
		return {id = row.id, primitive = primitive, center = center,
			radius_x = integer(row.radius_x, 1, 2147483647, row.id .. " radius x"),
			radius_z = integer(row.radius_z, 1, 2147483647, row.id .. " radius z"),
			secondary_relief_id = row.secondary_relief_id,
			noise_domain = row.noise_domain,
			base_h_priority = integer(row.base_h_priority, 0, 4294967295,
				row.id .. " priority"),
			blend_width = integer(row.base_h_blend_width, 1, 2147483647,
				row.id .. " blend width")}
	end

	local function mask_evaluate(row, x, z)
		integer(x, -2147483648, 2147483647, "landmark x")
		integer(z, -2147483648, 2147483647, "landmark z")
		local dx = exact.safe_difference(x, row.center.x, "landmark dx")
		local dz = exact.safe_difference(z, row.center.z, "landmark dz")
		local ax, az = math.abs(dx), math.abs(dz)
		local inside, signed_distance_q
		if row.primitive == "rectangle" then
			inside = ax <= row.radius_x and az <= row.radius_z
			signed_distance_q = qnodes(math.max(ax - row.radius_x,
				az - row.radius_z), "rectangle signed distance")
		elseif row.primitive == "ellipse" then
			inside = exact.ellipse_member(x, z, row.center, row)
			local dx_q = qnodes(dx, "ellipse dx Q16")
			local dz_q = qnodes(dz, "ellipse dz Q16")
			local ux = deterministic.qdiv(dx_q,
				qnodes(row.radius_x, "ellipse radius x Q16"))
			local uz = deterministic.qdiv(dz_q,
				qnodes(row.radius_z, "ellipse radius z Q16"))
			local normalized_square = safe_add(deterministic.qmul(ux, ux),
				deterministic.qmul(uz, uz), "ellipse normalized square")
			if normalized_square < 0 then fail("ellipse normalized square is negative") end
			local rho_q = deterministic.isqrt(exact.safe_product(
				normalized_square, Q, "ellipse normalized root"))
			signed_distance_q = deterministic.qmul(rho_q - Q,
				qnodes(math.min(row.radius_x, row.radius_z),
					"ellipse minimum radius Q16"))
		else
			local x_axis = row.radius_x >= row.radius_z
			local short = math.min(row.radius_x, row.radius_z)
			local long = math.max(row.radius_x, row.radius_z)
			local half_segment = long - short
			local along, perpendicular = x_axis and ax or az, x_axis and az or ax
			local excess = math.max(0, along - half_segment)
			inside = exact.safe_sum(exact.safe_square(excess, "capsule cap"),
				exact.safe_square(perpendicular, "capsule perpendicular"),
				"capsule distance") <= exact.safe_square(short, "capsule radius")
			local excess_q = qnodes(excess, "capsule excess Q16")
			local perpendicular_q = qnodes(perpendicular,
				"capsule perpendicular Q16")
			local distance_square = exact.safe_sum(exact.safe_square(excess_q,
				"capsule excess square"), exact.safe_square(perpendicular_q,
				"capsule perpendicular square"), "capsule Q16 distance")
			signed_distance_q = deterministic.isqrt(distance_square) -
				qnodes(short, "capsule radius Q16")
		end
		local outside_q = math.max(0, signed_distance_q)
		local blend_q = qnodes(row.blend_width, "landmark blend width Q16")
		local weight_q
		if outside_q >= blend_q then weight_q = 0
		else weight_q = Q - deterministic.smootherstep(
			deterministic.qdiv(outside_q, blend_q)) end
		return {inside = inside, signed_distance_q = signed_distance_q,
			weight_q = weight_q}
	end

	function relief.new(source, seed, water_level, options)
		plain_table(source, "source")
		deterministic.validate_seed(seed)
		integer(water_level, -2147483648, 2147483647, "water level")
		options = options or {}
		plain_table(options, "relief options")
		for key in pairs(options) do
			if key ~= "sha_cache_capacity" then
				fail("unknown relief option " .. tostring(key))
			end
		end
		local capacity = integer(options.sha_cache_capacity or 512, 1, 4096,
			"SHA cache capacity")

		local profile_rows = source.relief_profiles
		local landmark_rows = source.landmarks
		if dense_count(profile_rows, "source.relief_profiles") ~= 6 then
			fail("source does not contain exactly six relief profiles")
		end
		dense_count(landmark_rows, "source.landmarks")
		local profiles = {}
		for index = 1, #profile_rows do
			local row = plain_table(profile_rows[index], "relief profile")
			if type(row.id) ~= "string" or row.id == "" or profiles[row.id] or
					type(row.noise_domain) ~= "string" or row.noise_domain == "" then
				fail("relief profile identity is invalid")
			end
			dense_count(row.octaves, row.id .. ".octaves")
			local octaves = {}
			for octave_index = 1, #row.octaves do
				local octave = plain_table(row.octaves[octave_index], "relief octave")
				plain_table(octave.amplitude, "relief amplitude")
				octaves[octave_index] = {
					period = integer(octave.period, 1, 2147483647, "relief period"),
					amplitude_numerator = integer(octave.amplitude.numerator,
						-MAX_SAFE, MAX_SAFE, "relief amplitude numerator"),
					amplitude_denominator = integer(octave.amplitude.denominator,
						1, MAX_SAFE, "relief amplitude denominator"),
				}
			end
			profiles[row.id] = {id = row.id,
				min_above_water = integer(row.min_above_water, -2147483648,
					2147483647, "profile minimum"),
				max_above_water = integer(row.max_above_water, row.min_above_water,
					2147483647, "profile maximum"),
				noise_domain = row.noise_domain, octaves = octaves}
		end
		local landmarks, landmark_by_id, priorities = {}, {}, {}
		for index = 1, #landmark_rows do
			local row = mask_copy(landmark_rows[index])
			if landmark_by_id[row.id] then fail("landmark ID is duplicated") end
			if priorities[row.base_h_priority] then
				fail("landmark priority is duplicated")
			end
			if type(row.secondary_relief_id) ~= "string" or
					not profiles[row.secondary_relief_id] then
				fail("landmark secondary relief profile is invalid")
			end
			landmark_by_id[row.id] = row
			priorities[row.base_h_priority] = true
			landmarks[#landmarks + 1] = row
		end
		table.sort(landmarks, function(a, b)
			return a.base_h_priority < b.base_h_priority
		end)

		local stats = {sha_requests = 0, sha_calls = 0, cache_hits = 0,
			cache_misses = 0, raw_evaluations = 0,
			replacement_evaluations = 0, mask_evaluations = 0,
			contributions = 0}
		local cache, order, cache_count, replacement_index = {}, {}, 0, 1
		local function cached_raw_sha256(data)
			stats.sha_requests = stats.sha_requests + 1
			local cached = cache[data]
			if cached ~= nil then
				stats.cache_hits = stats.cache_hits + 1
				return cached
			end
			stats.cache_misses = stats.cache_misses + 1
			stats.sha_calls = stats.sha_calls + 1
			local digest = injected_raw_sha256(data)
			if type(digest) ~= "string" or #digest ~= 32 then
				fail("raw SHA-256 injection did not return 32 bytes")
			end
			if cache_count < capacity then
				cache_count = cache_count + 1
				order[cache_count] = data
			else
				local old = order[replacement_index]
				cache[old] = nil
				order[replacement_index] = data
				replacement_index = replacement_index % capacity + 1
			end
			cache[data] = digest
			return digest
		end

		local function evaluate_profile(profile, domain, x, z, replacement)
			integer(x, -2147483648, 2147483647, "relief x")
			integer(z, -2147483648, 2147483647, "relief z")
			if replacement then stats.replacement_evaluations =
				stats.replacement_evaluations + 1
			else stats.raw_evaluations = stats.raw_evaluations + 1 end
			local noise_q = deterministic.value_noise_2d(canonical,
				cached_raw_sha256, {schema = "grug_wp40_geometry_source_v1",
					seed = seed, domain = domain, feature = "",
					octaves = profile.octaves}, x, z)
			return raw_height_from_noise(profile, water_level, noise_q), noise_q
		end

		local session = {}
		function session.raw_height(profile_id, x, z)
			local profile = profiles[profile_id]
			if not profile then fail("unknown relief profile " .. tostring(profile_id)) end
			return evaluate_profile(profile, profile.noise_domain, x, z, false)
		end
		function session.mask(landmark_id, x, z)
			local row = landmark_by_id[landmark_id]
			if not row then fail("unknown landmark " .. tostring(landmark_id)) end
			stats.mask_evaluations = stats.mask_evaluations + 1
			return mask_evaluate(row, x, z)
		end
		function session.compose_landmarks(initial_h, x, z, landmark_ids)
			integer(initial_h, -2147483648, 2147483647, "initial relief height")
			local selected = landmarks
			if landmark_ids ~= nil then
				dense_count(landmark_ids, "landmark selection")
				selected = {}
				local selected_priorities = {}
				for index = 1, #landmark_ids do
					local row = landmark_by_id[landmark_ids[index]]
					if not row then fail("unknown selected landmark") end
					if selected_priorities[row.base_h_priority] then
						fail("selected landmark priority is duplicated")
					end
					selected_priorities[row.base_h_priority] = true
					selected[#selected + 1] = row
				end
				table.sort(selected, function(a, b)
					return a.base_h_priority < b.base_h_priority
				end)
			end
			local composed, contributions = initial_h, {}
			for index = 1, #selected do
				local row = selected[index]
				stats.mask_evaluations = stats.mask_evaluations + 1
				local mask = mask_evaluate(row, x, z)
				if mask.weight_q > 0 then
					local profile = profiles[row.secondary_relief_id]
					local replacement = evaluate_profile(profile, row.noise_domain,
						x, z, true)
					local previous = composed
					composed = deterministic.qlerp(composed, replacement, mask.weight_q)
					stats.contributions = stats.contributions + 1
					contributions[#contributions + 1] = {id = row.id,
						priority = row.base_h_priority, weight_q = mask.weight_q,
						replacement_h = replacement, previous_h = previous,
						result_h = composed, exact_inside = mask.inside}
				end
			end
			return composed, contributions
		end
		function session.stats()
			local result = {}
			for key, value in pairs(stats) do result[key] = value end
			result.cache_capacity = capacity
			result.cache_entries = cache_count
			return result
		end
		function session.clear_cache()
			cache, order, cache_count, replacement_index = {}, {}, 0, 1
		end
		return session
	end

	relief.raw_height_from_noise = raw_height_from_noise
	relief.mask_copy = mask_copy
	relief.mask_evaluate = mask_evaluate
	return relief
end
