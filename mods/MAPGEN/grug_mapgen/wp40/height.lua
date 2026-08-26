-- Engine-free deterministic vertical model for the accepted WP40 simple map.
-- All construction is session-local; scalar query seams allocate no records.

return function(dependencies)
	if type(dependencies) ~= "table" then
		error("WP40 simple-map height dependencies missing", 0)
	end
	local source = assert(dependencies.source,
		"WP40 simple-map height source missing")
	local canonical = assert(dependencies.canonical,
		"WP40 simple-map height canonical dependency missing")
	local deterministic = assert(dependencies.deterministic,
		"WP40 simple-map height deterministic dependency missing")
	local raw_sha256 = assert(dependencies.raw_sha256,
		"WP40 simple-map height SHA-256 dependency missing")
	local horizontal = assert(dependencies.horizontal_session,
		"WP40 simple-map horizontal session missing")
	local Q = 65536
	local P = 2147483647
	local B = 32768
	local MAX_SAFE = 9007199254740991
	local WATER_LEVEL = 1
	local HEIGHT_SCHEMA = "grug_wp40_simple_map_height_v1"
	local BASE_CELL = 64
	local FEATURE_CELL = 128
	local CONTACT_FACE_SCOPE = "orthogonal_reach_contact_face_v1"
	local CONTACT_FACE_EXPECTATIONS = {
		highcourt_goldmead_fall = {
			edges = 13, upper = 13, lower = 13,
			first = {-106, -1756, -106, -1757},
			upper_bounds = {-106, -94, -1756, -1756},
			lower_bounds = {-106, -94, -1757, -1757},
		},
		gravesalt_broken_fall = {
			edges = 163, upper = 114, lower = 114,
			first = {-1713, 21, -1712, 21},
			upper_bounds = {-1713, -1650, 21, 110},
			lower_bounds = {-1712, -1649, 21, 110},
		},
		raincall_reedmaze_fall = {
			edges = 109, upper = 66, lower = 65,
			first = {2070, 1864, 2069, 1864},
			upper_bounds = {2026, 2070, 1864, 1929},
			lower_bounds = {2026, 2069, 1864, 1928},
		},
	}

	local function fail(message)
		error("WP40 simple-map height: " .. message, 0)
	end

	local function integer(value, label)
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 or
				math.abs(value) > MAX_SAFE then
			fail((label or "value") .. " is not a safe integer")
		end
		return value
	end

	local function coordinate(value, label)
		integer(value, label)
		if value < -2147483648 or value > 2147483647 then
			fail((label or "coordinate") .. " is outside signed 32-bit range")
		end
		return value
	end

	local function dense_count(values, label)
		if type(values) ~= "table" then fail(label .. " is not an array") end
		local count = #values
		for index = 1, count do
			if values[index] == nil then fail(label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
					key > count then fail(label .. " is not a dense array") end
		end
		return count
	end

	local function deep_copy(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("cyclic evidence value") end
		active[value] = true
		local copy = {}
		for key, child in pairs(value) do
			copy[deep_copy(key, active)] = deep_copy(child, active)
		end
		active[value] = nil
		return copy
	end

	local function round_ratio(numerator, denominator)
		integer(numerator, "round numerator")
		integer(denominator, "round denominator")
		if denominator <= 0 then fail("round denominator is not positive") end
		return deterministic.round_ratio(numerator, denominator)
	end

	local function floor_div(value, divisor)
		return deterministic.floor_div(value, divisor)
	end

	local function floor_mod(value, divisor)
		return deterministic.floor_mod(value, divisor)
	end

	local function clamp(value, minimum, maximum)
		if value < minimum then return minimum end
		if value > maximum then return maximum end
		return value
	end

	local function qweight(outside, width)
		if outside <= 0 then return Q end
		if outside >= width then return 0 end
		return Q - deterministic.smootherstep(
			deterministic.qfrom_ratio(outside, width))
	end

	local function qlerp_integer(a, b, weight_q)
		return round_ratio(a * Q + (b - a) * weight_q, Q)
	end

	local function squared_distance(ax, az, bx, bz)
		local dx, dz = ax - bx, az - bz
		return dx * dx + dz * dz
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

	-- Continued fractions compare positive ratios without unsafe products.
	local function rational_compare(a, b, c, d)
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

	local function point_segment_ratio(x, z, a, b)
		local vx, vz = b.x - a.x, b.z - a.z
		local wx, wz = x - a.x, z - a.z
		local length_squared = vx * vx + vz * vz
		if length_squared == 0 then
			return wx * wx + wz * wz, 1, 0, 1
		end
		local dot = wx * vx + wz * vz
		if dot <= 0 then return wx * wx + wz * wz, 1, 0, length_squared end
		if dot >= length_squared then
			return squared_distance(x, z, b.x, b.z), 1,
				length_squared, length_squared
		end
		local cross = wx * vz - wz * vx
		return cross * cross, length_squared, dot, length_squared
	end

	local function corridor_member_ratio(numerator, denominator, total_width)
		return 4 * numerator <= total_width * total_width * denominator
	end

	local function in_polygon(x, z, points)
		local inside = false
		local previous = points[#points]
		for index = 1, #points do
			local current = points[index]
			local cross = (x - previous.x) * (current.z - previous.z) -
				(z - previous.z) * (current.x - previous.x)
			if cross == 0 and x >= math.min(previous.x, current.x) and
					x <= math.max(previous.x, current.x) and
					z >= math.min(previous.z, current.z) and
					z <= math.max(previous.z, current.z) then return true end
			if (current.z > z) ~= (previous.z > z) then
				local orientation = (previous.x - current.x) * (z - current.z) -
					(previous.z - current.z) * (x - current.x)
				if (previous.z > current.z and orientation > 0) or
						(previous.z < current.z and orientation < 0) then
					inside = not inside
				end
			end
			previous = current
		end
		return inside
	end

	local function in_half_open_square(x, z, center, width)
		return 2 * x >= 2 * center.x - width and
			2 * x < 2 * center.x + width and
			2 * z >= 2 * center.z - width and
			2 * z < 2 * center.z + width
	end

	local function half_open_square_excess(x, z, center, width)
		local half = width / 2
		local min_x, max_x = center.x - half, center.x + half - 1
		local min_z, max_z = center.z - half, center.z + half - 1
		return math.max(0, min_x - x, x - max_x, min_z - z, z - max_z)
	end

	local function text(value) return canonical.text(value or "") end
	local function signed(value) return canonical.signed(value or 0) end

	local function add_bucket(grid, record, min_x, max_x, min_z, max_z)
		local min_ix, max_ix = floor_div(min_x, FEATURE_CELL),
			floor_div(max_x, FEATURE_CELL)
		local min_iz, max_iz = floor_div(min_z, FEATURE_CELL),
			floor_div(max_z, FEATURE_CELL)
		for iz = min_iz, max_iz do
			local row = grid[iz]
			if not row then row = {} grid[iz] = row end
			for ix = min_ix, max_ix do
				local bucket = row[ix]
				if not bucket then bucket = {} row[ix] = bucket end
				bucket[#bucket + 1] = record
			end
		end
	end

	local function bucket_at(grid, x, z)
		local row = grid[floor_div(z, FEATURE_CELL)]
		return row and row[floor_div(x, FEATURE_CELL)] or nil
	end

	local function mulmod(a, b)
		a, b = floor_mod(a, P), floor_mod(b, P)
		local a1, a0 = math.floor(a / B), a % B
		local b1, b0 = math.floor(b / B), b % B
		local r = (a1 * b1) % P
		r = (r * B + a1 * b0 + a0 * b1) % P
		r = (r * B + a0 * b0) % P
		return r
	end

	local function digest_first_word(digest)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("raw SHA-256 injection did not return 32 bytes")
		end
		local a, b, c, d = digest:byte(1, 4)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end

	local function lattice_corner(root, ix, iz, octave)
		local x, z = floor_mod(ix, P), floor_mod(iz, P)
		local s = (root + mulmod(x, 73856093) + mulmod(z, 19349663) +
			octave * 83492791) % P
		s = (mulmod((s + 104729) % P, (s + 130363) % P) + 12345) % P
		s = (mulmod((s + mulmod((x + 37) % P, (z + 53) % P)) % P,
			48271) + 1) % P
		s = (mulmod((s + 32452843) % P, (s + 49979687) % P) +
			86028121) % P
		return math.floor(s * 131073 / P) - 65536, s
	end

	local module = {}
	local bound_seed_string

	local function construct(full_seed_string, diagnose_final_axis)
		deterministic.validate_seed(full_seed_string)
		if bound_seed_string and bound_seed_string ~= full_seed_string then
			fail("one height factory cannot reuse its horizontal session for a " ..
				"different full seed")
		end
		bound_seed_string = full_seed_string
		if source.schema ~= "grug_wp40_simple_map_source_v2" or
				source.layout_id ~= "wp40-simple-map-v1d" or
				source.layout_revision_id ~= "wp40-simple-map-v1e" then
			fail("source schema/layout identity differs from V1e R2")
		end
		if #source.relief_profiles ~= 6 or #source.landmarks ~= 70 or
				#source.anchors ~= 100 or #source.hard_protection ~= 42 or
				#source.hydrology ~= 25 or #source.hydrology_interfaces ~= 15 then
			fail("accepted R2 source population differs")
		end
		local proof = horizontal.warp_proof()
		local bounds = {min_x = proof.min_x, max_x = proof.max_x,
			min_z = proof.min_z, max_z = proof.max_z}
		for _, key in ipairs({"min_x", "max_x", "min_z", "max_z"}) do
			coordinate(bounds[key], "query bound " .. key)
		end
		local construction_complete = false
		local construction_sha_calls, query_sha_calls = 0, 0
		local query_lattice_constructions = 0
		local function counted_sha(data)
			if construction_complete then
				query_sha_calls = query_sha_calls + 1
			else
				construction_sha_calls = construction_sha_calls + 1
			end
			local result = raw_sha256(data)
			if type(result) ~= "string" or #result ~= 32 then
				fail("raw SHA-256 injection did not return 32 bytes")
			end
			return result
		end
		local function counted_digest(rows)
			return canonical.hex(counted_sha(canonical.encode(canonical.array(rows))))
		end
		local function note_lattice_construction()
			if construction_complete then
				query_lattice_constructions = query_lattice_constructions + 1
			end
		end

		local profile_by_id, profiles = {}, {}
		local relief_roots, octave_evidence = {}, {}
		local octave_digest_rows = {}
		for profile_index = 1, #source.relief_profiles do
			local source_profile = source.relief_profiles[profile_index]
			if profile_by_id[source_profile.id] then
				fail("duplicate relief profile " .. source_profile.id)
			end
			local root_input = "GRUGWP40HEIGHT" .. string.char(0) ..
				canonical.encode(text(HEIGHT_SCHEMA)) ..
				canonical.encode(text(full_seed_string)) ..
				canonical.encode(text(source_profile.noise_domain))
			local root = digest_first_word(counted_sha(root_input)) % P
			if root == 0 then root = 1 end
			local profile = {id = source_profile.id,
				min_above_water = source_profile.min_above_water,
				max_above_water = source_profile.max_above_water,
				noise_domain = source_profile.noise_domain, root = root, octaves = {}}
			profiles[profile_index] = profile
			profile_by_id[profile.id] = profile
			relief_roots[profile_index] = {id = profile.id,
				domain = profile.noise_domain, root = root}
			for octave_index = 1, #source_profile.octaves do
				note_lattice_construction()
				local source_octave = source_profile.octaves[octave_index]
				local period = source_octave.period
				local min_ix = floor_div(bounds.min_x - BASE_CELL, period) - 1
				local max_ix = floor_div(bounds.max_x + BASE_CELL, period) + 1
				local min_iz = floor_div(bounds.min_z - BASE_CELL, period) - 1
				local max_iz = floor_div(bounds.max_z + BASE_CELL, period) + 1
				local values, rows = {}, {}
				local observed_min, observed_max, min_x, min_z, max_x, max_z
				for iz = min_iz, max_iz do
					local row = {} values[iz] = row
					for ix = min_ix, max_ix do
						local value = lattice_corner(root, ix, iz, octave_index)
						row[ix] = value
						rows[#rows + 1] = canonical.array({signed(ix), signed(iz),
							signed(value)})
						if not observed_min or value < observed_min then
							observed_min, min_x, min_z = value, ix, iz
						end
						if not observed_max or value > observed_max then
							observed_max, max_x, max_z = value, ix, iz
						end
					end
				end
				local digest = counted_digest(rows)
				local octave = {period = period,
					amplitude_numerator = source_octave.amplitude.numerator,
					amplitude_denominator = source_octave.amplitude.denominator,
					values = values, min_ix = min_ix, max_ix = max_ix,
					min_iz = min_iz, max_iz = max_iz, digest = digest}
				profile.octaves[octave_index] = octave
				local evidence = {profile_id = profile.id, ordinal = octave_index,
					period = period, digest = digest, observed_min = observed_min,
					observed_min_ix = min_x, observed_min_iz = min_z,
					observed_max = observed_max, observed_max_ix = max_x,
					observed_max_iz = max_z}
				octave_evidence[#octave_evidence + 1] = evidence
				octave_digest_rows[#octave_digest_rows + 1] = canonical.array({
					text(profile.id), signed(octave_index), text(digest)})
			end
		end

		local function raw_profile_height(profile, x, z)
			local total = 0
			for octave_index = 1, #profile.octaves do
				local octave = profile.octaves[octave_index]
				local ix, iz = floor_div(x, octave.period),
					floor_div(z, octave.period)
				local row0, row1 = octave.values[iz], octave.values[iz + 1]
				if not row0 or not row1 or row0[ix] == nil or
						row0[ix + 1] == nil or row1[ix] == nil or
						row1[ix + 1] == nil then
					fail("relief query escaped its precomputed lattice")
				end
				local tx = deterministic.smootherstep(deterministic.qfrom_ratio(
					x - ix * octave.period, octave.period))
				local tz = deterministic.smootherstep(deterministic.qfrom_ratio(
					z - iz * octave.period, octave.period))
				local top = deterministic.qlerp(row0[ix], row0[ix + 1], tx)
				local bottom = deterministic.qlerp(row1[ix], row1[ix + 1], tx)
				local value = deterministic.qlerp(top, bottom, tz)
				total = total + round_ratio(value * octave.amplitude_numerator,
					octave.amplitude_denominator)
			end
			total = clamp(total, -Q, Q)
			return WATER_LEVEL + profile.min_above_water + math.floor(
				(total + Q) * (profile.max_above_water -
				profile.min_above_water) / (2 * Q))
		end

		local base_min_ix = floor_div(bounds.min_x, BASE_CELL) - 1
		local base_max_ix = floor_div(bounds.max_x, BASE_CELL) + 1
		local base_min_iz = floor_div(bounds.min_z, BASE_CELL) - 1
		local base_max_iz = floor_div(bounds.max_z, BASE_CELL) + 1
		local base_values, base_rows = {}, {}
		local primary_profile_stats = {}
		note_lattice_construction()
		for profile_index = 1, #profiles do
			primary_profile_stats[profile_index] = {count = 0}
		end
		for iz = base_min_iz, base_max_iz do
			local row = {} base_values[iz] = row
			for ix = base_min_ix, base_max_ix do
				local x, z = ix * BASE_CELL, iz * BASE_CELL
				local _, _, owner = horizontal.classification_values_at(x, z)
				local profile = owner and
					profile_by_id[source.zones[owner].primary_relief_id] or
					profile_by_id.lowland
				local height = raw_profile_height(profile, x, z)
				local profile_index
				for index = 1, #profiles do
					if profiles[index] == profile then profile_index = index break end
				end
				local stats = primary_profile_stats[profile_index]
				stats.count = stats.count + 1
				if not stats.minimum or height < stats.minimum then
					stats.minimum, stats.minimum_count, stats.minimum_x,
						stats.minimum_z = height, 1, x, z
				elseif height == stats.minimum then
					stats.minimum_count = stats.minimum_count + 1
				end
				if not stats.maximum or height > stats.maximum then
					stats.maximum, stats.maximum_count, stats.maximum_x,
						stats.maximum_z = height, 1, x, z
				elseif height == stats.maximum then
					stats.maximum_count = stats.maximum_count + 1
				end
				row[ix] = height
				base_rows[#base_rows + 1] = canonical.array({signed(ix), signed(iz),
					signed(height), text(profile.id)})
			end
		end
		local base_lattice_digest = counted_digest(base_rows)
		local octave_lattice_digest = counted_digest(octave_digest_rows)

		local function base_height_at(x, z)
			local ix, iz = floor_div(x, BASE_CELL), floor_div(z, BASE_CELL)
			local tx = deterministic.smootherstep(deterministic.qfrom_ratio(
				x - ix * BASE_CELL, BASE_CELL))
			local tz = deterministic.smootherstep(deterministic.qfrom_ratio(
				z - iz * BASE_CELL, BASE_CELL))
			local row0, row1 = base_values[iz], base_values[iz + 1]
			if not row0 or not row1 or not row0[ix] or not row0[ix + 1] or
					not row1[ix] or not row1[ix + 1] then
				fail("base-height query escaped its precomputed lattice")
			end
			local top = deterministic.qlerp(row0[ix] * Q, row0[ix + 1] * Q, tx)
			local bottom = deterministic.qlerp(row1[ix] * Q,
				row1[ix + 1] * Q, tx)
			return deterministic.qround(deterministic.qlerp(top, bottom, tz))
		end

		local landmark_grid, landmark_evidence = {}, {}
		local landmarks = {}
		for index = 1, #source.landmarks do
			local row = source.landmarks[index]
			if row.numeric_id ~= index then fail("landmark order differs") end
			local replacement = profile_by_id[row.secondary_relief_id]
			if not replacement then fail("landmark relief reference differs") end
			local record = {numeric_id = index, id = row.id,
				zone_numeric_id = row.zone_numeric_id, primitive = row.primitive,
				center = row.center, radius_x = row.radius_x,
				radius_z = row.radius_z, replacement = replacement,
				collar = BASE_CELL}
			landmarks[index] = record
			add_bucket(landmark_grid, record,
				row.center.x - row.radius_x - BASE_CELL,
				row.center.x + row.radius_x + BASE_CELL,
				row.center.z - row.radius_z - BASE_CELL,
				row.center.z + row.radius_z + BASE_CELL)
			landmark_evidence[index] = {numeric_id = index, id = row.id,
				zone_numeric_id = row.zone_numeric_id, primitive = row.primitive,
				center_x = row.center.x, center_z = row.center.z,
				radius_x = row.radius_x, radius_z = row.radius_z,
				secondary_relief_id = row.secondary_relief_id,
				collar_width = BASE_CELL}
		end

		local function landmark_weight(record, x, z)
			local dx, dz = x - record.center.x, z - record.center.z
			local ax, az = math.abs(dx), math.abs(dz)
			if math.max(ax - record.radius_x, az - record.radius_z) >=
					record.collar then return 0 end
			local signed_distance_q
			if record.primitive == "rectangle" then
				signed_distance_q = math.max(ax - record.radius_x,
					az - record.radius_z) * Q
			elseif record.primitive == "ellipse" then
				local ux = deterministic.qdiv(dx * Q, record.radius_x * Q)
				local uz = deterministic.qdiv(dz * Q, record.radius_z * Q)
				local square = deterministic.qmul(ux, ux) +
					deterministic.qmul(uz, uz)
				if square < 0 then fail("ellipse distance became negative") end
				local rho = deterministic.isqrt(square * Q)
				signed_distance_q = deterministic.qmul(rho - Q,
					math.min(record.radius_x, record.radius_z) * Q)
			elseif record.primitive == "capsule" then
				local x_axis = record.radius_x >= record.radius_z
				local short = math.min(record.radius_x, record.radius_z)
				local long = math.max(record.radius_x, record.radius_z)
				local along, perpendicular = x_axis and ax or az, x_axis and az or ax
				local excess = math.max(0, along - (long - short))
				local excess_q, perpendicular_q = excess * Q, perpendicular * Q
				signed_distance_q = deterministic.isqrt(excess_q * excess_q +
					perpendicular_q * perpendicular_q) - short * Q
			else
				fail("unknown landmark primitive " .. tostring(record.primitive))
			end
			if signed_distance_q <= 0 then return Q end
			if signed_distance_q >= record.collar * Q then return 0 end
			return Q - deterministic.smootherstep(deterministic.qdiv(
				signed_distance_q, record.collar * Q))
		end

		local function natural_height_at(x, z)
			local height = base_height_at(x, z)
			local _, _, owner = horizontal.classification_values_at(x, z)
			local candidates = bucket_at(landmark_grid, x, z)
			if candidates then
				for index = 1, #candidates do
					local record = candidates[index]
					if owner == record.zone_numeric_id then
						local weight = landmark_weight(record, x, z)
						if weight > 0 then
							local replacement = raw_profile_height(record.replacement, x, z)
							height = qlerp_integer(height, replacement, weight)
						end
					end
				end
			end
			return height
		end

		local hydro_profile_by_id = {}
		for index = 1, #source.hydrology_profiles do
			local row = source.hydrology_profiles[index]
			hydro_profile_by_id[row.id] = row
		end
		local hydrology_by_id, hydro_segments, hydro_grid = {}, {}, {}
		local hydrology_evidence = {}
		for reach_index = 1, #source.hydrology do
			local reach = source.hydrology[reach_index]
			local profile = hydro_profile_by_id[reach.profile_id]
			if not profile then fail("hydrology profile reference differs") end
			local record = {numeric_id = reach_index, id = reach.id,
				zone_numeric_id = reach.zone_numeric_id, profile = profile,
				water_y = WATER_LEVEL + reach.water_surface_offset,
				reach = reach, segments = {}}
			hydrology_by_id[record.id] = record
			for segment_index = 1, #reach.centreline - 1 do
				local a, b = reach.centreline[segment_index],
					reach.centreline[segment_index + 1]
				local maximum_half = math.max(a.half_width, b.half_width) +
					profile.bank_blend_width
				local segment = {reach = record, ordinal = segment_index,
					a = a, b = b, maximum_half = maximum_half}
				record.segments[#record.segments + 1] = segment
				hydro_segments[#hydro_segments + 1] = segment
				add_bucket(hydro_grid, segment,
					math.min(a.x, b.x) - maximum_half,
					math.max(a.x, b.x) + maximum_half,
					math.min(a.z, b.z) - maximum_half,
					math.max(a.z, b.z) + maximum_half)
			end
			hydrology_evidence[reach_index] = {numeric_id = reach_index,
				id = reach.id, zone_numeric_id = reach.zone_numeric_id,
				profile_id = reach.profile_id, depth = profile.depth,
				water_surface_y = profile.depth > 0 and record.water_y or nil,
				dry_datum_y = profile.depth == 0 and record.water_y or nil,
				bed_y = profile.depth > 0 and record.water_y - profile.depth or
					record.water_y, bank_blend_width = profile.bank_blend_width,
				segment_count = #record.segments}
		end

		local function nearest_hydrology_segment(x, z, owner, allow_wet,
				allow_dry)
			local candidates = bucket_at(hydro_grid, x, z)
			local best, best_numerator, best_denominator
			if not candidates then return nil end
			for index = 1, #candidates do
				local segment = candidates[index]
				local reach = segment.reach
				local dry = reach.profile.depth == 0
				if reach.zone_numeric_id == owner and
						((dry and allow_dry) or (not dry and allow_wet)) then
					local numerator, denominator = point_segment_ratio(x, z,
						segment.a, segment.b)
					if numerator <= segment.maximum_half * segment.maximum_half *
							denominator then
						local better = not best or rational_compare(numerator,
							denominator, best_numerator, best_denominator) < 0
						if not better and best and rational_compare(numerator,
								denominator, best_numerator, best_denominator) == 0 then
							better = reach.numeric_id < best.reach.numeric_id or
								(reach.numeric_id == best.reach.numeric_id and
								segment.ordinal < best.ordinal)
						end
						if better then
							best, best_numerator, best_denominator = segment,
								numerator, denominator
						end
					end
				end
			end
			return best, best_numerator, best_denominator
		end

		local function hydrology_half_width(segment, x, z)
			local vx, vz = segment.b.x - segment.a.x,
				segment.b.z - segment.a.z
			local length_squared = vx * vx + vz * vz
			local dot = (x - segment.a.x) * vx + (z - segment.a.z) * vz
			dot = clamp(dot, 0, length_squared)
			return segment.a.half_width + round_ratio(
				(segment.b.half_width - segment.a.half_width) * dot,
				length_squared)
		end

		local function hydrology_scalar_at(x, z, natural, water_class, owner,
				classified_hydrology_id)
			if classified_hydrology_id then
				local reach = hydrology_by_id[classified_hydrology_id]
				if not reach or reach.profile.depth <= 0 then
					fail("classified wet hydrology reference differs")
				end
				return reach.water_y - reach.profile.depth
			end
			if water_class == "land" then
				local segment, numerator, denominator = nearest_hydrology_segment(
					x, z, owner, true, true)
				if segment then
					local reach = segment.reach
					local axis_distance = deterministic.isqrt(math.floor(
						numerator / denominator))
					local half_width = hydrology_half_width(segment, x, z)
					local outside = math.max(0, axis_distance - half_width)
					local weight = qweight(outside,
						reach.profile.bank_blend_width)
					if weight > 0 then
						local target = reach.profile.depth == 0 and reach.water_y or
							reach.water_y + 1
						return qlerp_integer(natural, target, weight)
					end
				end
			end
			return natural
		end

		local function ordinary_water_surface(water_class, bay_id,
				classified_hydrology_id)
			if classified_hydrology_id then
				local reach = hydrology_by_id[classified_hydrology_id]
				return reach and reach.profile.depth > 0 and reach.water_y or nil
		end
		if water_class == "planned_water" and bay_id then return WATER_LEVEL end
		if water_class == "coastal_shelf" or water_class == "deep_ocean" or
				water_class == "immutable_dragon_channel" then return WATER_LEVEL end
			return nil
		end

		local function raster_line(a, b)
			local dx, dz = b.x - a.x, b.z - a.z
			local steps = math.max(math.abs(dx), math.abs(dz))
			local points = {}
			if steps == 0 then
				points[1] = {x = a.x, z = a.z}
				return points
			end
			for k = 0, steps do
				points[#points + 1] = {x = a.x + round_ratio(dx * k, steps),
					z = a.z + round_ratio(dz * k, steps)}
			end
			return points
		end

		local function raster_polyline(points)
			local result, segments = {}, {}
			for source_segment = 1, #points - 1 do
				local line = raster_line(points[source_segment],
					points[source_segment + 1])
				local first_run = #result == 0 and 0 or #result - 1
				for index = 1, #line do
					if source_segment == 1 or index > 1 then
						result[#result + 1] = line[index]
					end
				end
				segments[source_segment] = {a = points[source_segment],
					b = points[source_segment + 1], first_run = first_run,
					steps = #line - 1, ordinal = source_segment}
			end
			local seen = {}
			for index = 1, #result do
				local key = result[index].x .. ":" .. result[index].z
				if seen[key] then fail("non-join duplicate in canonical raster") end
				seen[key] = true
			end
			return result, segments
		end

		local function reach_support_bounds(record)
			local min_x, max_x, min_z, max_z
			for point_index = 1, #record.reach.centreline do
				local point = record.reach.centreline[point_index]
				local point_min_x, point_max_x = point.x - point.half_width,
					point.x + point.half_width
				local point_min_z, point_max_z = point.z - point.half_width,
					point.z + point.half_width
				min_x = min_x and math.min(min_x, point_min_x) or point_min_x
				max_x = max_x and math.max(max_x, point_max_x) or point_max_x
				min_z = min_z and math.min(min_z, point_min_z) or point_min_z
				max_z = max_z and math.max(max_z, point_max_z) or point_max_z
			end
			return {min_x = min_x - 1, max_x = max_x + 1,
				min_z = min_z - 1, max_z = max_z + 1}
		end

		local function point_before(a, b)
			return a.z < b.z or (a.z == b.z and a.x < b.x)
		end

		local function contact_edge_before(a, b)
			if a.upper_z ~= b.upper_z then return a.upper_z < b.upper_z end
			if a.upper_x ~= b.upper_x then return a.upper_x < b.upper_x end
			if a.lower_z ~= b.lower_z then return a.lower_z < b.lower_z end
			return a.lower_x < b.lower_x
		end

		local function point_set_bounds(points)
			if #points == 0 then fail("contact-face point set is empty") end
			local min_x, max_x = points[1].x, points[1].x
			local min_z, max_z = points[1].z, points[1].z
			for point_index = 2, #points do
				local point = points[point_index]
				min_x, max_x = math.min(min_x, point.x), math.max(max_x, point.x)
				min_z, max_z = math.min(min_z, point.z), math.max(max_z, point.z)
			end
			return {min_x = min_x, max_x = max_x, min_z = min_z, max_z = max_z}
		end

		local function eight_connected_component_count(points)
			local members, visited = {}, {}
			for point_index = 1, #points do
				local point = points[point_index]
				local row = members[point.z]
				if not row then row = {} members[point.z] = row end
				row[point.x] = true
			end
			local components = 0
			for point_index = 1, #points do
				local point = points[point_index]
				local visited_row = visited[point.z]
				if not visited_row or not visited_row[point.x] then
					components = components + 1
					local queue_x, queue_z = {point.x}, {point.z}
					local cursor = 1
					visited_row = visited_row or {}
					visited[point.z] = visited_row
					visited_row[point.x] = true
					while cursor <= #queue_x do
						local x, z = queue_x[cursor], queue_z[cursor]
						cursor = cursor + 1
						for dz = -1, 1 do
							local member_row = members[z + dz]
							if member_row then
								local neighbour_visited = visited[z + dz]
								for dx = -1, 1 do
									if (dx ~= 0 or dz ~= 0) and member_row[x + dx] and
											(not neighbour_visited or
											not neighbour_visited[x + dx]) then
										neighbour_visited = neighbour_visited or {}
										visited[z + dz] = neighbour_visited
										neighbour_visited[x + dx] = true
										queue_x[#queue_x + 1] = x + dx
										queue_z[#queue_z + 1] = z + dz
									end
								end
							end
						end
					end
				end
			end
			return components
		end

		local function contact_face_mask_bit(upper_x, upper_z, lower_x, lower_z)
			if upper_x == lower_x - 1 and upper_z == lower_z then return 1 end
			if upper_x == lower_x + 1 and upper_z == lower_z then return 2 end
			if upper_x == lower_x and upper_z == lower_z - 1 then return 4 end
			if upper_x == lower_x and upper_z == lower_z + 1 then return 8 end
			fail("contact-face edge is not orthogonal")
		end

		local function bounds_differ(bounds, expected)
			return bounds.min_x ~= expected[1] or bounds.max_x ~= expected[2] or
				bounds.min_z ~= expected[3] or bounds.max_z ~= expected[4]
		end

		local transition_grid, transitions, interface_evidence = {}, {}, {}
		local contact_face_grid, contact_face_records, contact_face_evidence =
			{}, {}, {}
		local contact_face_seen, unequal_pair_seen = {}, {}
		local hydrology_interface_population = {total = 0,
			unequal_level_pairs = 0, rapids = 0, waterfalls = 0,
			cardinal_waterfalls = 0, contact_face_waterfalls = 0, other = 0}

		local function build_contact_face_record(row, evidence)
			local expected = CONTACT_FACE_EXPECTATIONS[row.id]
			local upper, lower = hydrology_by_id[row.upper_id],
				hydrology_by_id[row.lower_id]
			if not expected or contact_face_seen[row.id] or not upper or not lower or
					upper.profile.depth <= 0 or lower.profile.depth <= 0 or
					row.upper_level_offset ~= upper.reach.water_surface_offset or
					row.lower_level_offset ~= lower.reach.water_surface_offset or
					row.transition_profile_id ~= "waterfall_drop" or
					row.plunge_profile_id ~= lower.profile.id or
					row.drop ~= row.upper_level_offset - row.lower_level_offset or
					row.drop_height ~= row.drop or row.bed_seal_layers ~= 3 or
					row.bank_seal_nodes ~= 2 or
					row.receiver_source_omission_nodes ~= 1 or row.sealed ~= true then
				fail("contact-face waterfall source contract differs")
			end
			for _, forbidden in ipairs({"axis_start", "axis_end", "run", "width",
					"drop_mask_width", "drop_mask_length", "plunge_width",
					"plunge_length"}) do
				if row[forbidden] ~= nil then
					fail("contact-face waterfall carries axis or rectangle geometry")
				end
			end
			contact_face_seen[row.id] = true

			local upper_support, lower_support = reach_support_bounds(upper),
				reach_support_bounds(lower)
			local scan_min_x = math.max(upper_support.min_x, lower_support.min_x)
			local scan_max_x = math.min(upper_support.max_x, lower_support.max_x)
			local scan_min_z = math.max(upper_support.min_z, lower_support.min_z)
			local scan_max_z = math.min(upper_support.max_z, lower_support.max_z)
			if scan_min_x > scan_max_x or scan_min_z > scan_max_z then
				fail("contact-face reach support intersection is empty")
			end

			local edges, upper_lips, lower_faces = {}, {}, {}
			local upper_seen, lower_by_coordinate = {}, {}
			local neighbour_x, neighbour_z = {-1, 1, 0, 0}, {0, 0, -1, 1}
			for z = scan_min_z, scan_max_z do
				for x = scan_min_x, scan_max_x do
					local water_class, _, _, _, hydrology_id =
						horizontal.classification_values_at(x, z)
					if water_class == "planned_water" and hydrology_id == upper.id then
						for direction = 1, 4 do
							local lower_x, lower_z = x + neighbour_x[direction],
								z + neighbour_z[direction]
							local lower_class, _, _, _, lower_hydrology_id =
								horizontal.classification_values_at(lower_x, lower_z)
							if lower_class == "planned_water" and
									lower_hydrology_id == lower.id then
								local bit = contact_face_mask_bit(x, z, lower_x, lower_z)
								edges[#edges + 1] = {upper_x = x, upper_z = z,
									lower_x = lower_x, lower_z = lower_z,
									face_mask_bit = bit}
								local upper_key = x .. ":" .. z
								if not upper_seen[upper_key] then
									upper_seen[upper_key] = true
									upper_lips[#upper_lips + 1] = {x = x, z = z}
								end
								local lower_key = lower_x .. ":" .. lower_z
								local face = lower_by_coordinate[lower_key]
								if not face then
									face = {x = lower_x, z = lower_z, face_mask = 0}
									lower_by_coordinate[lower_key] = face
									lower_faces[#lower_faces + 1] = face
								end
								if math.floor(face.face_mask / bit) % 2 ~= 0 then
									fail("duplicate contact-face direction bit")
								end
								face.face_mask = face.face_mask + bit
							end
						end
					end
				end
			end

			table.sort(edges, contact_edge_before)
			table.sort(upper_lips, point_before)
			table.sort(lower_faces, point_before)
			local upper_components = eight_connected_component_count(upper_lips)
			local lower_components = eight_connected_component_count(lower_faces)
			local upper_bounds, lower_bounds = point_set_bounds(upper_lips),
				point_set_bounds(lower_faces)
			local first = edges[1]
			if #edges ~= expected.edges or #upper_lips ~= expected.upper or
					#lower_faces ~= expected.lower or upper_components ~= 1 or
					lower_components ~= 1 or not first or
					first.upper_x ~= expected.first[1] or
					first.upper_z ~= expected.first[2] or
					first.lower_x ~= expected.first[3] or
					first.lower_z ~= expected.first[4] or
					bounds_differ(upper_bounds, expected.upper_bounds) or
					bounds_differ(lower_bounds, expected.lower_bounds) then
				fail("contact-face waterfall population or bounds differ")
			end

			local direction_counts = {}
			for face_index = 1, #lower_faces do
				local mask = lower_faces[face_index].face_mask
				if mask <= 0 or mask > 15 then fail("contact-face mask differs") end
				direction_counts[mask] = (direction_counts[mask] or 0) + 1
			end
			local direction_mask_counts = {}
			for mask = 1, 15 do
				if direction_counts[mask] then
					direction_mask_counts[#direction_mask_counts + 1] = {
						face_mask = mask, column_count = direction_counts[mask]}
				end
			end

			local edge_lines, upper_lines, lower_lines, direction_lines = {}, {}, {}, {}
			for edge_index = 1, #edges do
				local edge = edges[edge_index]
				edge_lines[edge_index] = table.concat({"edge", row.id,
					tostring(edge.upper_x), tostring(edge.upper_z),
					tostring(edge.lower_x), tostring(edge.lower_z),
					tostring(edge.face_mask_bit)}, "\t") .. "\n"
			end
			for lip_index = 1, #upper_lips do
				local lip = upper_lips[lip_index]
				upper_lines[lip_index] = table.concat({"upper_lip", row.id,
					tostring(lip.x), tostring(lip.z)}, "\t") .. "\n"
			end
			for face_index = 1, #lower_faces do
				local face = lower_faces[face_index]
				lower_lines[face_index] = table.concat({"lower_face", row.id,
					tostring(face.x), tostring(face.z), tostring(face.face_mask)},
					"\t") .. "\n"
			end
			for count_index = 1, #direction_mask_counts do
				local count = direction_mask_counts[count_index]
				direction_lines[count_index] = table.concat({"direction_mask", row.id,
					tostring(count.face_mask), tostring(count.column_count)}, "\t") .. "\n"
			end
			local edge_bytes, upper_bytes, lower_bytes, direction_bytes =
				table.concat(edge_lines), table.concat(upper_lines),
				table.concat(lower_lines), table.concat(direction_lines)
			local edge_digest = canonical.hex(counted_sha(edge_bytes))
			local upper_digest = canonical.hex(counted_sha(upper_bytes))
			local lower_digest = canonical.hex(counted_sha(lower_bytes))
			local direction_digest = canonical.hex(counted_sha(direction_bytes))
			local contact_digest = canonical.hex(counted_sha(edge_bytes .. upper_bytes ..
				lower_bytes .. direction_bytes))

			local record = {kind = "waterfall", id = row.id, row = row,
				contact_face = true, transition_scope_id = CONTACT_FACE_SCOPE,
				upper_y = WATER_LEVEL + row.upper_level_offset,
				lower_y = WATER_LEVEL + row.lower_level_offset,
				upper_bed = WATER_LEVEL + row.upper_level_offset - upper.profile.depth,
				lower_bed = WATER_LEVEL + row.lower_level_offset - lower.profile.depth,
				lower_face_columns = lower_faces}
			transitions[#transitions + 1] = record
			contact_face_records[#contact_face_records + 1] = record
			for face_index = 1, #lower_faces do
				local face = lower_faces[face_index]
				local grid_row = contact_face_grid[face.z]
				if not grid_row then grid_row = {} contact_face_grid[face.z] = grid_row end
				if grid_row[face.x] then fail("contact-face waterfalls overlap") end
				grid_row[face.x] = {record = record, face_mask = face.face_mask}
			end

			evidence.transition_profile_id = row.transition_profile_id
			evidence.transition_scope_id = row.transition_scope_id
			evidence.upper_id, evidence.lower_id = row.upper_id, row.lower_id
			evidence.upper_y, evidence.lower_y = record.upper_y, record.lower_y
			evidence.upper_bed, evidence.lower_bed = record.upper_bed, record.lower_bed
			evidence.lip_id, evidence.drop_id = row.lip_id, row.drop_id
			evidence.plunge_id, evidence.plunge_profile_id = row.plunge_id,
				row.plunge_profile_id
			evidence.drop, evidence.drop_height = row.drop, row.drop_height
			evidence.bed_seal_layers = row.bed_seal_layers
			evidence.bank_seal_nodes = row.bank_seal_nodes
			evidence.receiver_source_omission_nodes =
				row.receiver_source_omission_nodes
			evidence.sealed = row.sealed
			evidence.scan_min_x, evidence.scan_max_x = scan_min_x, scan_max_x
			evidence.scan_min_z, evidence.scan_max_z = scan_min_z, scan_max_z
			evidence.contact_edge_count = #edges
			evidence.upper_lip_count, evidence.lower_face_count = #upper_lips,
				#lower_faces
			evidence.upper_lip_component_count = upper_components
			evidence.lower_face_component_count = lower_components
			evidence.first_upper_x, evidence.first_upper_z = first.upper_x, first.upper_z
			evidence.first_lower_x, evidence.first_lower_z = first.lower_x, first.lower_z
			evidence.upper_min_x, evidence.upper_max_x = upper_bounds.min_x,
				upper_bounds.max_x
			evidence.upper_min_z, evidence.upper_max_z = upper_bounds.min_z,
				upper_bounds.max_z
			evidence.lower_min_x, evidence.lower_max_x = lower_bounds.min_x,
				lower_bounds.max_x
			evidence.lower_min_z, evidence.lower_max_z = lower_bounds.min_z,
				lower_bounds.max_z
			evidence.receiver_opening_count = #lower_faces
			evidence.receiver_y = record.lower_y
			evidence.receiver_source_min_y = record.lower_bed + 1
			evidence.receiver_source_max_y = record.lower_y - 1
			evidence.authored_falling_water_columns = 0
			evidence.contact_edges = edges
			evidence.upper_lip_columns = upper_lips
			evidence.lower_face_columns = lower_faces
			evidence.direction_mask_counts = direction_mask_counts
			evidence.contact_edge_digest = edge_digest
			evidence.upper_lip_digest = upper_digest
			evidence.lower_face_digest = lower_digest
			evidence.direction_mask_digest = direction_digest
			evidence.contact_face_digest = contact_digest
			contact_face_evidence[#contact_face_evidence + 1] = evidence
		end
		for interface_index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[interface_index]
			if row.transition_scope_id ~= nil and
					row.transition_scope_id ~= CONTACT_FACE_SCOPE then
				fail("unknown hydrology transition scope")
			elseif row.transition_scope_id == CONTACT_FACE_SCOPE and
					row.kind ~= "waterfall" then
				fail("non-waterfall entered contact-face scope")
			end
			hydrology_interface_population.total =
				hydrology_interface_population.total + 1
			if row.upper_id and row.lower_id and row.upper_level_offset ~= nil and
					row.lower_level_offset ~= nil and
					row.upper_level_offset ~= row.lower_level_offset then
				local pair_a, pair_b = row.upper_id, row.lower_id
				if pair_b < pair_a then pair_a, pair_b = pair_b, pair_a end
				local pair_key = pair_a .. "\t" .. pair_b
				if unequal_pair_seen[pair_key] then
					fail("duplicate unequal-level hydrology interface pair")
				end
				unequal_pair_seen[pair_key] = true
				hydrology_interface_population.unequal_level_pairs =
					hydrology_interface_population.unequal_level_pairs + 1
			end
			if row.kind == "rapid" then
				hydrology_interface_population.rapids =
					hydrology_interface_population.rapids + 1
			elseif row.kind == "waterfall" then
				hydrology_interface_population.waterfalls =
					hydrology_interface_population.waterfalls + 1
				if row.transition_scope_id == CONTACT_FACE_SCOPE then
					hydrology_interface_population.contact_face_waterfalls =
						hydrology_interface_population.contact_face_waterfalls + 1
				else
					hydrology_interface_population.cardinal_waterfalls =
						hydrology_interface_population.cardinal_waterfalls + 1
				end
			else
				hydrology_interface_population.other =
					hydrology_interface_population.other + 1
			end
			local evidence = {numeric_id = interface_index, id = row.id,
				kind = row.kind, position_x = row.position.x,
				position_z = row.position.z}
			interface_evidence[interface_index] = evidence
			if row.kind == "rapid" then
				local upper, lower = hydrology_by_id[row.upper_id],
					hydrology_by_id[row.lower_id]
				if not upper or not lower or row.upper_level_offset ~=
						upper.reach.water_surface_offset or row.lower_level_offset ~=
						lower.reach.water_surface_offset then
					fail("rapid reach/level reference differs")
				end
				local first = lower.reach.centreline[1]
				local second
				for point_index = 2, #lower.reach.centreline do
					local candidate = lower.reach.centreline[point_index]
					if candidate.x ~= first.x or candidate.z ~= first.z then
						second = candidate break
					end
				end
				if not second then fail("rapid lower reach has no direction") end
				local dx, dz = second.x - first.x, second.z - first.z
				local m = math.max(math.abs(dx), math.abs(dz))
				local axis_steps = row.run - 1
				local before = math.floor(axis_steps / 2)
				local after = axis_steps - before
				local a = {x = row.position.x - round_ratio(dx * before, m),
					z = row.position.z - round_ratio(dz * before, m)}
				local b = {x = row.position.x + round_ratio(dx * after, m),
					z = row.position.z + round_ratio(dz * after, m)}
				local axis = raster_line(a, b)
				if #axis ~= row.run or axis[before + 1].x ~= row.position.x or
						axis[before + 1].z ~= row.position.z then
					fail("rapid raster length/position differs")
				end
				local record = {kind = "rapid", id = row.id, row = row,
					axis = axis, width = row.width,
					upper_y = WATER_LEVEL + row.upper_level_offset,
					lower_y = WATER_LEVEL + row.lower_level_offset,
					upper_bed = WATER_LEVEL + row.upper_level_offset -
						upper.profile.depth,
					lower_bed = WATER_LEVEL + row.lower_level_offset -
						lower.profile.depth}
				transitions[#transitions + 1] = record
				add_bucket(transition_grid, record,
					math.min(a.x, b.x) - row.width,
					math.max(a.x, b.x) + row.width,
					math.min(a.z, b.z) - row.width,
					math.max(a.z, b.z) + row.width)
				evidence.upper_y, evidence.lower_y = record.upper_y, record.lower_y
				evidence.upper_bed, evidence.lower_bed = record.upper_bed,
					record.lower_bed
				evidence.run, evidence.width = #axis, row.width
				evidence.axis_start_x, evidence.axis_start_z = a.x, a.z
				evidence.axis_end_x, evidence.axis_end_z = b.x, b.z
			elseif row.kind == "waterfall" and
					row.transition_scope_id == CONTACT_FACE_SCOPE then
				build_contact_face_record(row, evidence)
			elseif row.kind == "waterfall" then
				local upper, lower = hydrology_by_id[row.upper_id],
					hydrology_by_id[row.lower_id]
				if not upper or not lower or
						row.upper_level_offset ~= upper.reach.water_surface_offset or
						row.lower_level_offset ~= lower.reach.water_surface_offset or
						lower.profile.id ~= row.plunge_profile_id then
					fail("waterfall reach/profile reference differs")
				end
				local a = upper.reach.centreline[#upper.reach.centreline]
				local b = lower.reach.centreline[1]
				local dx, dz = b.x - a.x, b.z - a.z
				if (dx == 0) == (dz == 0) or math.max(math.abs(dx),
						math.abs(dz)) ~= row.drop_mask_length or
						a.x + b.x ~= 2 * row.position.x or
						a.z + b.z ~= 2 * row.position.z then
					fail("waterfall cardinal axis/midpoint differs")
				end
				local axis = raster_line(a, b)
				local direction_x = dx == 0 and 0 or (dx > 0 and 1 or -1)
				local direction_z = dz == 0 and 0 or (dz > 0 and 1 or -1)
				local lower_class, _, _, _, lower_hydrology_id =
					horizontal.classification_values_at(b.x, b.z)
				if lower_class ~= "planned_water" or
						lower_hydrology_id ~= lower.id or row.plunge_width <= 0 or
						row.plunge_length <= 0 then
					fail("waterfall plunge footprint/reference differs")
				end
				local record = {kind = "waterfall", id = row.id, row = row,
					axis = axis, width = row.drop_mask_width,
					upper_y = WATER_LEVEL + row.upper_level_offset,
					lower_y = WATER_LEVEL + row.lower_level_offset,
					upper_bed = WATER_LEVEL + row.upper_level_offset -
						upper.profile.depth,
					lower_bed = WATER_LEVEL + row.lower_level_offset -
						lower.profile.depth,
					direction_x = direction_x, direction_z = direction_z}
				transitions[#transitions + 1] = record
				add_bucket(transition_grid, record,
					math.min(a.x, b.x) - row.drop_mask_width,
					math.max(a.x, b.x) + row.drop_mask_width,
					math.min(a.z, b.z) - row.drop_mask_width,
					math.max(a.z, b.z) + row.drop_mask_width)
				evidence.upper_y, evidence.lower_y = record.upper_y, record.lower_y
				evidence.upper_bed, evidence.lower_bed = record.upper_bed,
					record.lower_bed
				evidence.run, evidence.width = #axis, row.drop_mask_width
				evidence.axis_start_x, evidence.axis_start_z = a.x, a.z
				evidence.axis_end_x, evidence.axis_end_z = b.x, b.z
				evidence.plunge_width = row.plunge_width
				evidence.plunge_length = row.plunge_length
			else
				local hydrology_id = row.hydrology_id or row.outgoing_reach_id
				local reach = hydrology_id and hydrology_by_id[hydrology_id] or nil
				evidence.hydrology_id = hydrology_id
				evidence.water_surface_y = reach and reach.water_y or nil
				evidence.route_interface_id = row.route_interface_id
			end
		end
		if hydrology_interface_population.total ~= 15 or
				hydrology_interface_population.unequal_level_pairs ~= 7 or
				hydrology_interface_population.rapids ~= 2 or
				hydrology_interface_population.waterfalls ~= 5 or
				hydrology_interface_population.cardinal_waterfalls ~= 2 or
				hydrology_interface_population.contact_face_waterfalls ~= 3 or
				hydrology_interface_population.other ~= 8 or
				#contact_face_records ~= 3 or #contact_face_evidence ~= 3 then
			fail("hydrology interface population differs from V1e closure")
		end
		for interface_id in pairs(CONTACT_FACE_EXPECTATIONS) do
			if not contact_face_seen[interface_id] then
				fail("contact-face waterfall roster differs")
			end
		end

		local function transition_progress(record, x, z)
			local best_index, best_numerator, best_denominator, best_dot,
				best_length
			for index = 1, #record.axis - 1 do
				local numerator, denominator, dot, length_squared =
					point_segment_ratio(x, z, record.axis[index],
						record.axis[index + 1])
				if corridor_member_ratio(numerator, denominator, record.width) and
						(not best_index or rational_compare(numerator, denominator,
							best_numerator, best_denominator) < 0) then
					best_index, best_numerator, best_denominator = index, numerator,
						denominator
					best_dot, best_length = dot, length_squared
				end
			end
			if not best_index then return nil end
			local numerator = (best_index - 1) * best_length + best_dot
			local denominator = (#record.axis - 1) * best_length
			return clamp(deterministic.qfrom_ratio(numerator, denominator), 0, Q)
		end

		local function axis_transition_values_at(x, z)
			local candidates = bucket_at(transition_grid, x, z)
			if not candidates then return nil end
			for index = 1, #candidates do
				local record = candidates[index]
				local progress = transition_progress(record, x, z)
				if progress then return record, progress end
			end
			return nil
		end

		for record_index = 1, #contact_face_records do
			local record = contact_face_records[record_index]
			for face_index = 1, #record.lower_face_columns do
				local face = record.lower_face_columns[face_index]
				if axis_transition_values_at(face.x, face.z) then
					fail("contact-face overlaps a rapid or cardinal waterfall mask")
				end
			end
		end

		local function transition_values_at(x, z)
			local face_row = contact_face_grid[z]
			local face = face_row and face_row[x] or nil
			if face then return face.record, nil, face.face_mask end
			return axis_transition_values_at(x, z)
		end

		local function classified_values(x, z)
			return horizontal.classification_values_at(x, z)
		end

		local function pregrade_water_surface_at(x, z, water_class, bay_id,
				hydrology_id)
			local transition, progress = transition_values_at(x, z)
			if transition then
				if transition.kind == "waterfall" then return nil end
				return qlerp_integer(transition.upper_y, transition.lower_y,
					progress)
			end
			return ordinary_water_surface(water_class, bay_id, hydrology_id)
		end

		local anchor_profile_by_id = {}
		for index = 1, #source.anchor_profiles do
			local row = source.anchor_profiles[index]
			anchor_profile_by_id[row.id] = row
		end
		local function clearance_datum_at(x, z, water_class, bay_id,
				hydrology_id)
			local water_y = pregrade_water_surface_at(x, z, water_class, bay_id,
				hydrology_id)
			if water_y ~= nil then return water_y end
			local transition = transition_values_at(x, z)
			if transition and transition.kind == "waterfall" then
				return math.max(transition.upper_y, transition.lower_y)
			end
			return nil
		end

		local zone_station_y, zone_midpoint_y = {}, {}
		for zone_index = 1, #source.zones do
			local zone = source.zones[zone_index]
			local primary = profile_by_id[zone.primary_relief_id]
			if not primary then fail("zone primary relief reference differs") end
			zone_station_y[zone_index] = WATER_LEVEL + primary.min_above_water
			zone_midpoint_y[zone_index] = WATER_LEVEL + math.floor(
				(primary.min_above_water + primary.max_above_water) / 2)
		end

		local anchor_by_id, fittings, start_fittings, capital_fittings,
			selected_fittings = {}, {}, {}, {}, {}
		local start_by_zone, capital_by_zone = {}, {}
		local fitting_grids = {start = {}, capital = {}, selected = {}}
		for anchor_index = 1, #source.anchors do
			local anchor = source.anchors[anchor_index]
			anchor_by_id[anchor.id] = anchor
			local selected = horizontal.selected_anchor_by_id(anchor.id)
			if not selected or selected.anchor_id ~= anchor.id then
				fail("selected anchor missing or differs")
			end
			local profile = anchor_profile_by_id[anchor.template_id]
			if not profile then fail("anchor profile reference differs") end
			local expected_selection_mode =
				anchor.placement_mode == "authored_fixed" and
				"authored_fixed" or "frozen_layout"
			if selected.selection_mode ~= expected_selection_mode or
					selected.approved_candidate_index ~=
					anchor.approved_candidate_index then
				fail("selected anchor fixed-layout provenance differs")
			end
			local fitting = {numeric_id = anchor_index, id = anchor.id,
				anchor = anchor, profile = profile,
				center = {x = selected.x, z = selected.z},
				selection_mode = selected.selection_mode,
				approved_candidate_index = selected.approved_candidate_index,
				zone_numeric_id = anchor.zone_numeric_id,
				is_capital = anchor.slot_id == "capital"}
			if profile.fitting_width <= 0 or profile.blend_width <= 0 or
					profile.fitting_width % 2 ~= 0 or profile.blend_width % 2 ~= 0 or
					profile.blend_width <= profile.fitting_width then
				fail("anchor fitting widths differ from the exact primitive")
			end
			local half = profile.fitting_width / 2
			local land_count, water_count, civic_water_count = 0, 0, 0
			local platform_witness_x, platform_witness_z
			local civic_max_clearance_y, civic_witness_x, civic_witness_z
			local center_class, _, center_owner, center_bay, center_hydrology =
				classified_values(selected.x, selected.z)
			if center_owner ~= anchor.zone_numeric_id then
				fail("selected anchor centre owner differs at " .. anchor.id)
			end
			local is_start = anchor_index <= 6
			if fitting.is_capital and center_class ~= "land" then
				fail("capital centre is not land at " .. anchor.id)
			elseif center_class ~= "land" and center_class ~= "planned_water" then
				fail("anchor centre enters unsupported water at " .. anchor.id)
			end
			if is_start then
				if center_class ~= "land" then fail("start centre is not land") end
				fitting.reference_y = zone_station_y[anchor.zone_numeric_id]
				fitting.reference_rule = "start_zone_station"
			elseif fitting.is_capital then
				fitting.reference_y = zone_station_y[anchor.zone_numeric_id]
				fitting.reference_rule = "capital_zone_station"
			else
				fitting.reference_y = zone_midpoint_y[anchor.zone_numeric_id]
				fitting.reference_rule = center_class == "planned_water" and
					"profile_midpoint_water_raise" or "profile_midpoint"
				if center_class == "planned_water" then
					local datum = clearance_datum_at(selected.x, selected.z,
						center_class, center_bay, center_hydrology)
					if datum == nil then fail("anchor centre water has no clearance datum") end
					fitting.reference_y = math.max(fitting.reference_y, datum + 1)
				end
			end
			for z = selected.z - half, selected.z + half - 1 do
				for x = selected.x - half, selected.x + half - 1 do
					local water_class, _, owner, bay_id, hydrology_id =
						classified_values(x, z)
					if owner == anchor.zone_numeric_id then
						if water_class == "land" then
							land_count = land_count + 1
						elseif water_class == "planned_water" then
							local datum = clearance_datum_at(x, z, water_class,
								bay_id, hydrology_id)
							if datum == nil then fail("anchor water has no clearance datum") end
							if fitting.is_capital then
								civic_water_count = civic_water_count + 1
								if civic_max_clearance_y == nil or
										datum > civic_max_clearance_y then
									civic_max_clearance_y, civic_witness_x,
										civic_witness_z = datum, x, z
								end
							else
								water_count = water_count + 1
								if not platform_witness_x then
									platform_witness_x, platform_witness_z = x, z
								end
							end
						end
					end
				end
			end
			if fitting.is_capital and civic_max_clearance_y ~= nil then
				fitting.reference_y = math.max(fitting.reference_y,
					civic_max_clearance_y + 1)
				fitting.reference_rule = "capital_civic_max"
			end
			fitting.target_y = fitting.reference_y
			fitting.land_count, fitting.water_count = land_count, water_count
			fitting.civic_water_count = civic_water_count
			fitting.civic_max_clearance_y = civic_max_clearance_y
			fitting.civic_witness_x, fitting.civic_witness_z = civic_witness_x,
				civic_witness_z
			fitting.platform_witness_x = platform_witness_x
			fitting.platform_witness_z = platform_witness_z
			fittings[anchor_index] = fitting
			local class, collection
			if anchor_index <= 6 then
				class, collection = "start", start_fittings
				start_by_zone[anchor.zone_numeric_id] = fitting
			elseif anchor_index <= 12 then
				class, collection = "capital", capital_fittings
				capital_by_zone[anchor.zone_numeric_id] = fitting
			else class, collection = "selected", selected_fittings end
			collection[#collection + 1] = fitting
			local envelope_half = profile.blend_width / 2
			add_bucket(fitting_grids[class], fitting,
				selected.x - envelope_half, selected.x + envelope_half,
				selected.z - envelope_half, selected.z + envelope_half)
		end

		local function fitting_grade_at(grid, x, z, incoming, owner,
				water_class, platform_only)
			local candidates = bucket_at(grid, x, z)
			if not candidates then return nil end
			for index = 1, #candidates do
				local fitting = candidates[index]
				if owner == fitting.zone_numeric_id then
					local profile = fitting.profile
					if water_class == "planned_water" and not fitting.is_capital and
							in_half_open_square(x, z, fitting.center,
								profile.fitting_width) then
						local _, _, _, bay_id, hydrology_id = classified_values(x, z)
						local datum = clearance_datum_at(x, z, water_class,
							bay_id, hydrology_id)
						if datum == nil then fail("anchor platform water has no clearance datum") end
						return math.max(fitting.reference_y, datum + 1), fitting, true, Q
					elseif not platform_only and water_class == "land" then
						local fitting_half = profile.fitting_width / 2
						local envelope_half = profile.blend_width / 2
						local outside = half_open_square_excess(x, z,
							fitting.center, profile.fitting_width)
						if outside < envelope_half - fitting_half then
						local weight = qweight(math.max(0, outside),
							envelope_half - fitting_half)
						if weight > 0 then
							return qlerp_integer(incoming, fitting.reference_y,
								weight), fitting, false, weight
						end
						end
					end
				end
			end
			return nil
		end

		local landmark_by_id = {}
		for index = 1, #source.landmarks do
			landmark_by_id[source.landmarks[index].id] = source.landmarks[index]
		end
		local coastal_grid, coastal_cores, coastal_evidence = {}, {}, {}
		for core_index = 1, #source.coastal_housing_cores do
			local row = source.coastal_housing_cores[core_index]
			local landmark = landmark_by_id[row.landmark_id]
			if not landmark or landmark.primitive ~= "rectangle" then
				fail("coastal core landmark differs")
			end
			local radius = landmark.radius_x
			local half_axis = landmark.radius_z - radius
			local domain = "coastal-core-gentle-v1:" .. row.id
			local root_input = "GRUGWP40HEIGHT" .. string.char(0) ..
				canonical.encode(text(HEIGHT_SCHEMA)) ..
				canonical.encode(text(full_seed_string)) ..
				canonical.encode(text(domain))
			local root = digest_first_word(counted_sha(root_input)) % P
			if root == 0 then root = 1 end
			local min_ix = floor_div(landmark.center.x - landmark.radius_x -
				BASE_CELL, BASE_CELL) - 1
			local max_ix = floor_div(landmark.center.x + landmark.radius_x +
				BASE_CELL, BASE_CELL) + 1
			local min_iz = floor_div(landmark.center.z - landmark.radius_z -
				BASE_CELL, BASE_CELL) - 1
			local max_iz = floor_div(landmark.center.z + landmark.radius_z +
				BASE_CELL, BASE_CELL) + 1
			local values, rows = {}, {}
			note_lattice_construction()
			for iz = min_iz, max_iz do
				local values_row = {} values[iz] = values_row
				for ix = min_ix, max_ix do
					local _, state = lattice_corner(root, ix, iz, 1)
					local value = math.floor(state * 13 / P) - 6
					values_row[ix] = value
					rows[#rows + 1] = canonical.array({signed(ix), signed(iz),
						signed(value)})
				end
			end
			local core = {numeric_id = core_index, id = row.id, row = row,
				zone_numeric_id = row.zone_numeric_id, center = landmark.center,
				radius_x = landmark.radius_x, radius_z = landmark.radius_z,
				radius = radius, half_axis = half_axis, root = root,
				values = values, target_y = natural_height_at(landmark.center.x,
					landmark.center.z)}
			coastal_cores[core_index] = core
			add_bucket(coastal_grid, core,
				landmark.center.x - landmark.radius_x - BASE_CELL,
				landmark.center.x + landmark.radius_x + BASE_CELL,
				landmark.center.z - landmark.radius_z - BASE_CELL,
				landmark.center.z + landmark.radius_z + BASE_CELL)
			coastal_evidence[core_index] = {numeric_id = core_index, id = row.id,
				zone_numeric_id = row.zone_numeric_id, root = root,
				target_y = core.target_y, theoretical_min_y = core.target_y - 6,
				theoretical_max_y = core.target_y + 6,
				lattice_digest = counted_digest(rows), relief_max = row.relief_max,
				center_x = landmark.center.x, center_z = landmark.center.z,
				radius_x = landmark.radius_x, radius_z = landmark.radius_z}
		end

		local function coastal_weight(core, x, z)
			local dx, dz = math.abs(x - core.center.x), math.abs(z - core.center.z)
			if math.max(dx - core.radius_x, dz - core.radius_z) >= BASE_CELL then
				return 0
			end
			local excess = math.max(0, dz - core.half_axis)
			local distance_q = deterministic.isqrt((dx * Q) * (dx * Q) +
				(excess * Q) * (excess * Q)) - core.radius * Q
			if distance_q <= 0 then return Q end
			if distance_q >= BASE_CELL * Q then return 0 end
			return Q - deterministic.smootherstep(deterministic.qdiv(
				distance_q, BASE_CELL * Q))
		end

		local function coastal_target_at(core, x, z)
			local ix, iz = floor_div(x, BASE_CELL), floor_div(z, BASE_CELL)
			local tx = deterministic.smootherstep(deterministic.qfrom_ratio(
				x - ix * BASE_CELL, BASE_CELL))
			local tz = deterministic.smootherstep(deterministic.qfrom_ratio(
				z - iz * BASE_CELL, BASE_CELL))
			local row0, row1 = core.values[iz], core.values[iz + 1]
			local top = deterministic.qlerp(row0[ix] * Q, row0[ix + 1] * Q, tx)
			local bottom = deterministic.qlerp(row1[ix] * Q,
				row1[ix + 1] * Q, tx)
			return core.target_y + deterministic.qround(
				deterministic.qlerp(top, bottom, tz))
		end

		local function coastal_grade_at(x, z, incoming, owner, water_class)
			if water_class ~= "land" then return nil end
			local candidates = bucket_at(coastal_grid, x, z)
			if not candidates then return nil end
			for index = 1, #candidates do
				local core = candidates[index]
				if owner == core.zone_numeric_id then
					local weight = coastal_weight(core, x, z)
					if weight > 0 then
						return qlerp_integer(incoming,
							coastal_target_at(core, x, z), weight), core, weight
					end
				end
			end
			return nil
		end

		local function exterior_bed_at(x, z, water_class)
			if water_class == "coastal_shelf" then
				local low, high = 1, source.shelf_width
				while low < high do
					local middle = math.floor((low + high) / 2)
					if horizontal.expanded_land_at(x, z, middle) then high = middle
					else low = middle + 1 end
				end
				local depth = 1 + math.floor(7 * (low - 1) / 79)
				return WATER_LEVEL - depth
		elseif water_class == "deep_ocean" or
				water_class == "immutable_dragon_channel" then
				return WATER_LEVEL - 24
		end
		return nil
		end

		local function scalar_before_nonpath_grades(x, z, water_class, owner,
				bay_id, hydrology_id)
			local transition, progress = transition_values_at(x, z)
			if transition then
				if transition.contact_face then return transition.lower_bed end
				return qlerp_integer(transition.upper_bed,
					transition.lower_bed, progress)
			end
			local exterior = exterior_bed_at(x, z, water_class)
			if exterior then return exterior end
			if water_class == "planned_water" and bay_id then
				return WATER_LEVEL - 8
			end
			local natural = natural_height_at(x, z)
			return hydrology_scalar_at(x, z, natural, water_class, owner,
				hydrology_id)
		end

		local function scalar_before_paths(x, z)
			local water_class, _, owner, bay_id, hydrology_id =
				classified_values(x, z)
			local incoming = scalar_before_nonpath_grades(x, z, water_class,
				owner, bay_id, hydrology_id)
			if water_class ~= "land" then return incoming end
			local value = fitting_grade_at(fitting_grids.start, x, z, incoming,
				owner, water_class, false)
			if value ~= nil then return value end
			value = fitting_grade_at(fitting_grids.capital, x, z, incoming,
				owner, water_class, false)
			if value ~= nil then return value end
			value = coastal_grade_at(x, z, incoming, owner, water_class)
			if value ~= nil then return value end
			value = fitting_grade_at(fitting_grids.selected, x, z, incoming,
				owner, water_class, false)
			if value ~= nil then return value end
			return incoming
		end

		local route_station_target, station_evidence = {}, {}
		for zone_index = 1, #source.zones do
			local zone = source.zones[zone_index]
			local primary = profile_by_id[zone.primary_relief_id]
			local water_class, _, _, bay_id, hydrology_id =
				classified_values(zone.hub.x, zone.hub.z)
			local hub_water = water_class == "planned_water"
			local clearance_y
			local capital = capital_by_zone[zone_index]
			local target = zone_station_y[zone_index]
			if capital then
				if hub_water then fail("capital hub is planned water") end
				target = capital.reference_y
			elseif hub_water then
				clearance_y = clearance_datum_at(zone.hub.x, zone.hub.z,
					water_class, bay_id, hydrology_id)
				if clearance_y == nil then
					fail("planned-water route station has no clearance datum at " ..
						zone.id)
				end
				target = math.max(target, clearance_y + 1)
			elseif water_class ~= "land" then
				fail("route station enters unsupported water at " .. zone.id)
			end
			route_station_target[zone_index] = target
			station_evidence[zone_index] = {id = source.route_stations[zone_index].id,
				zone_id = zone.id,
				zone_numeric_id = zone_index,
				primary_profile_id = primary.id,
				primary_min_above_water = primary.min_above_water,
				primary_max_above_water = primary.max_above_water,
				zone_station_y = zone_station_y[zone_index],
				hub_x = zone.hub.x, hub_z = zone.hub.z,
				hub_target_y = target, hub_water = hub_water,
				hub_clearance_y = clearance_y,
				capital_anchor_id = capital and capital.id or nil}
		end

		local paths, path_by_id = {}, {}
		local function make_path(id, kind, priority, centreline, surface_width,
				corridor_width, owner_a, owner_b)
			if path_by_id[id] then fail("duplicate graded path " .. id) end
			local axis, source_segments = raster_polyline(centreline)
			local path = {id = id, kind = kind, priority = priority,
				centreline = centreline, surface_width = surface_width,
				corridor_width = corridor_width, owner_a = owner_a,
				owner_b = owner_b, axis = axis, source_segments = source_segments,
				pins = {}, operations = {}, fords = {}}
			paths[#paths + 1] = path
			path_by_id[id] = path
			return path
		end

		local function add_pin(path, run_index, y, pin_kind, source_id)
			integer(run_index, "route pin run") integer(y, "route pin y")
			if run_index < 1 or run_index > #path.axis then
				fail("route pin escaped axis at " .. path.id)
			end
			local old = path.pins[run_index]
			if old and old.y ~= y then
				fail("conflicting route pins at " .. path.id .. " (" ..
					old.pin_kind .. " versus " .. pin_kind .. ")")
			end
			path.pins[run_index] = old or {y = y, pin_kind = pin_kind,
				source_id = source_id}
		end

		for route_index = 1, #source.routes do
			local route = source.routes[route_index]
			local path = make_path(route.id, "land_route", 1, route.centreline,
				route.surface_width, route.corridor_width, route.zone_a,
				route.zone_b)
			path.source_route = route
			add_pin(path, 1, route_station_target[route.zone_a], "endpoint_a",
				source.zones[route.zone_a].id)
			add_pin(path, #path.axis, route_station_target[route.zone_b],
				"endpoint_b", source.zones[route.zone_b].id)
		end

		local trail_template = {bandit_home = true, bandit_frontier = true,
			mirefolk = true, clash = true}
		for spur_index = 1, #source.poi_spurs do
			local spur = source.poi_spurs[spur_index]
			local anchor = anchor_by_id[spur.anchor_id]
			local fitting = fittings[anchor.numeric_id]
			local centreline = spur.centreline
			if not centreline then
				fail("fixed POI spur centreline differs")
			end
			local corridor_width = trail_template[anchor.template_id] and 8 or 12
			local surface_width = corridor_width == 8 and 3 or 5
			local path = make_path(spur.id, "selected_poi_spur", 2, centreline,
				surface_width, corridor_width, anchor.zone_numeric_id,
				anchor.zone_numeric_id)
			path.source_spur, path.anchor_id = spur, anchor.id
			add_pin(path, 1, fitting.reference_y, "anchor_endpoint", anchor.id)
			add_pin(path, #path.axis, route_station_target[anchor.zone_numeric_id],
				"station_endpoint", source.zones[anchor.zone_numeric_id].id)
		end

		local fixed_fitting_by_coordinate = {}
		for fitting_index = 1, #fittings do
			local fitting = fittings[fitting_index]
			local template_id = fitting.anchor.template_id
			if template_id == "dragon" or template_id == "apex_mine" then
				local key = fitting.center.x .. ":" .. fitting.center.z
				if fixed_fitting_by_coordinate[key] then
					fail("duplicate island anchor fitting coordinate")
				end
				fixed_fitting_by_coordinate[key] = fitting
			end
		end
		local landing_by_coordinate = {}
		for landing_index = 1, #source.island_landings do
			local landing = source.island_landings[landing_index]
			local key = landing.position.x .. ":" .. landing.position.z
			if landing_by_coordinate[key] then
				fail("duplicate island landing coordinate")
			end
			landing_by_coordinate[key] = landing
		end
		local function island_endpoint_target(owner, point)
			local key = point.x .. ":" .. point.z
			local landing = landing_by_coordinate[key]
			if landing then return WATER_LEVEL + 1, "landing_endpoint", landing.id end
			local fitting = fixed_fitting_by_coordinate[key]
			if fitting then
				return fitting.reference_y, "island_anchor_endpoint", fitting.id
			end
			return zone_station_y[owner], "island_junction", source.zones[owner].id
		end
		local function island_endpoint_owner(point)
			local key = point.x .. ":" .. point.z
			local landing = landing_by_coordinate[key]
			local fitting = fixed_fitting_by_coordinate[key]
			if landing and fitting and
					landing.zone_numeric_id ~= fitting.zone_numeric_id then
				fail("island endpoint owner differs between source records")
			end
			if landing then return landing.zone_numeric_id end
			if fitting then return fitting.zone_numeric_id end
			return nil
		end
		for route_index = 1, #source.island_routes do
			local route = source.island_routes[route_index]
			local first = route.centreline[1]
			local last = route.centreline[#route.centreline]
			local first_owner = island_endpoint_owner(first)
			local last_owner = island_endpoint_owner(last)
			if first_owner and last_owner and first_owner ~= last_owner then
				fail("island route endpoint owners differ")
			end
			local owner = first_owner or last_owner
			if not owner then
				fail("island route has no authoritative endpoint owner")
			end
			local path = make_path(route.id, "island_route", 3,
				route.centreline, 5, 12, owner, owner)
			path.source_island_route = route
			local first_y, first_kind, first_id = island_endpoint_target(owner, first)
			local last_y, last_kind, last_id = island_endpoint_target(owner, last)
			add_pin(path, 1, first_y, first_kind, first_id)
			add_pin(path, #path.axis, last_y, last_kind, last_id)
		end

		local landing_grades, landing_route_by_id = {}, {}
		for path_index = 1, #paths do
			local path = paths[path_index]
			if path.kind == "island_route" then
				local first = path.axis[1]
				local landing = landing_by_coordinate[first.x .. ":" .. first.z]
				if landing then landing_route_by_id[landing.id] = path.id end
			end
		end
		for landing_index = 1, #source.island_landings do
			local row = source.island_landings[landing_index]
			local boat
			for boat_index = 1, #source.boat_paths do
				if source.boat_paths[boat_index].id == row.boat_path_id then
					boat = source.boat_paths[boat_index] break
				end
			end
			if not boat or not landing_route_by_id[row.id] then
				fail("island landing route/boat reference differs")
			end
			local _, segments = raster_polyline(boat.centreline)
			landing_grades[landing_index] = {numeric_id = landing_index,
				id = row.id, boat_path_id = boat.id,
				route_id = landing_route_by_id[row.id],
				zone_numeric_id = row.zone_numeric_id, width = row.width,
				surface_y = WATER_LEVEL + 1, centreline = boat.centreline,
				source_segments = segments}
		end

		local crossing_by_id = {}
		for index = 1, #source.crossing_interfaces do
			crossing_by_id[source.crossing_interfaces[index].id] =
				source.crossing_interfaces[index]
		end

		local function projected_run_for_segment(segment, dot, length_squared)
			local numerator = segment.first_run * length_squared +
				dot * segment.steps
			local quotient, remainder = divmod_nonnegative(numerator,
				length_squared)
			if 2 * remainder > length_squared then quotient = quotient + 1 end
			return quotient + 1
		end

		local function path_surface_run_at(path, x, z)
			local best, best_numerator, best_denominator, best_dot, best_length
			for segment_index = 1, #path.source_segments do
				local segment = path.source_segments[segment_index]
				local numerator, denominator, dot, length_squared =
					point_segment_ratio(x, z, segment.a, segment.b)
				if corridor_member_ratio(numerator, denominator, path.surface_width) then
					local better = not best or rational_compare(numerator, denominator,
						best_numerator, best_denominator) < 0
					if not better and best and rational_compare(numerator, denominator,
							best_numerator, best_denominator) == 0 then
						better = segment.ordinal < best.ordinal
					end
					if better then
						best, best_numerator, best_denominator = segment, numerator,
							denominator
						best_dot, best_length = dot, length_squared
					end
				end
			end
			return best and projected_run_for_segment(best, best_dot, best_length) or nil
		end

		local function named_operation_column_at(path, x, z, run_index)
			for operation_index = 1, #path.operations do
				local operation = path.operations[operation_index]
				if operation.named_non_tunnel and run_index >= operation.first_run and
						run_index <= operation.last_run then
					local water_class, _, _, _, hydrology_id = classified_values(x, z)
					if water_class == "planned_water" and
							hydrology_id == operation.hydrology_id and
							in_polygon(x, z, operation.authorization_polygon) then
						return operation
					end
				end
			end
			return nil
		end

		local water_operations, named_water_operations = {}, {}
		for interface_index = 1, #source.hydrology_interfaces do
			local interface = source.hydrology_interfaces[interface_index]
			if interface.route_interface_id then
				local crossing = crossing_by_id[interface.route_interface_id]
				local path = crossing and path_by_id[crossing.route_id] or nil
				if not crossing or not path or crossing.kind == "tunnel" then
					fail("named water route interface differs")
				end
				local reach = hydrology_by_id[interface.hydrology_id]
				if not reach then fail("named water reach missing") end
				local first_run, last_run
				for run_index = 1, #path.axis do
					local point = path.axis[run_index]
					local water_class, _, _, _, hydrology_id =
						classified_values(point.x, point.z)
					local authorized = crossing.authorization_polygon and
						in_polygon(point.x, point.z,
							crossing.authorization_polygon) or false
					if water_class == "planned_water" and
							hydrology_id == interface.hydrology_id and authorized then
						if first_run and run_index ~= last_run + 1 then
							fail("named operation axis is disconnected")
						end
						first_run, last_run = first_run or run_index, run_index
					end
				end
				if not first_run then fail("named operation has empty axis footprint") end
				local kind
				if crossing.kind == "bridge" then
					kind = "bridge_deck"
				elseif crossing.kind == "ford" then
					kind = "ford"
				elseif crossing.kind == "causeway" then
					kind = "causeway"
				else fail("unknown named crossing kind") end
				local operation = {kind = kind, feature_id = path.id,
					interface_id = crossing.id, path = path,
					first_run = first_run, last_run = last_run,
					hydrology_id = interface.hydrology_id,
					authorization_polygon = crossing.authorization_polygon,
					named_non_tunnel = true}
				path.operations[#path.operations + 1] = operation
				water_operations[#water_operations + 1] = operation
				named_water_operations[#named_water_operations + 1] = operation
				if kind == "ford" then
					local ford_run
					for run_index = 1, #path.axis do
						local point = path.axis[run_index]
						if point.x == crossing.position.x and
								point.z == crossing.position.z then
							ford_run = run_index break
						end
					end
					if not ford_run then fail("ford centre is absent from route axis") end
					local point = path.axis[ford_run]
					local ford_class, _, _, ford_bay, ford_hydrology =
						classified_values(point.x, point.z)
					if ford_class ~= "planned_water" or
							ford_hydrology ~= operation.hydrology_id then
						fail("ford centre hydrology differs")
					end
					local datum = clearance_datum_at(point.x, point.z, ford_class,
						ford_bay, ford_hydrology)
					if datum == nil then fail("ford centre has no clearance datum") end
					operation.ford_run, operation.ford_pin_y = ford_run, datum - 1
					path.fords[#path.fords + 1] = operation
					add_pin(path, ford_run, operation.ford_pin_y, "ford_center",
						crossing.id)
				end
			end
		end

		local final_terrain_height_at, final_functional_values_at,
			final_water_surface_at, route_evidence, tunnel_operations,
			operation_raw_member, operation_member, path_grid,
			route_exact_pin_evidence, route_lower_bound_evidence,
			route_raise_evidence, ford_approach_evidence,
			ford_approach_summary_evidence, named_operation_evidence,
			derived_water_evidence, landing_evidence,
			visible_surface_classification_digest
		local function build_public_session()
		local anchor_records, anchor_evidence = {}, {}
		local spur_id_by_anchor = {}
		for index = 1, #source.poi_spurs do
			spur_id_by_anchor[source.poi_spurs[index].anchor_id] =
				source.poi_spurs[index].id
		end
		for anchor_index = 1, #fittings do
			local fitting = fittings[anchor_index]
			local anchor = fitting.anchor
			local observed_max_cut, observed_max_fill = 0, 0
			local cut_x, cut_z, fill_x, fill_z
			local fitting_columns, collar_columns = 0, 0
			local platform_columns = 0
			local platform_witness_x, platform_witness_z
			local profile = fitting.profile
			local envelope_half = profile.blend_width / 2
			local fitting_half = profile.fitting_width / 2
			for z = fitting.center.z - envelope_half,
					fitting.center.z + envelope_half - 1 do
				for x = fitting.center.x - envelope_half,
						fitting.center.x + envelope_half - 1 do
					local water_class, _, owner = classified_values(x, z)
					local outside = half_open_square_excess(x, z,
						fitting.center, profile.fitting_width)
					if owner == fitting.zone_numeric_id then
						if outside == 0 then fitting_columns = fitting_columns + 1
						elseif outside < envelope_half - fitting_half then
							collar_columns = collar_columns + 1 end
					end
					if not fitting.is_capital and outside == 0 and
							owner == fitting.zone_numeric_id and
							water_class == "planned_water" then
						local platform_kind, _, platform_feature_id =
							final_functional_values_at(x, z)
						if platform_kind == "anchor_platform" and
								platform_feature_id == fitting.id then
							platform_columns = platform_columns + 1
							if not platform_witness_x then
								platform_witness_x, platform_witness_z = x, z
							end
						end
					end
					if water_class == "land" and owner == fitting.zone_numeric_id and
							outside < envelope_half - fitting_half then
						local natural = natural_height_at(x, z)
						local weight = qweight(outside, envelope_half - fitting_half)
						local value = qlerp_integer(natural, fitting.reference_y, weight)
						local cut, fill = natural - value, value - natural
						if cut_x == nil or cut > observed_max_cut then
							observed_max_cut, cut_x, cut_z = cut, x, z
						end
						if fill_x == nil or fill > observed_max_fill then
							observed_max_fill, fill_x, fill_z = fill, x, z
						end
					end
				end
			end
			local kind, surface_y, feature_id = final_functional_values_at(
				fitting.center.x, fitting.center.z)
			surface_y = surface_y or final_terrain_height_at(fitting.center.x,
				fitting.center.z)
			local record = {id = anchor.id, numeric_id = anchor_index,
				zone_numeric_id = anchor.zone_numeric_id, slot_id = anchor.slot_id,
				template_id = anchor.template_id,
				selection_mode = fitting.selection_mode,
				approved_candidate_index = fitting.approved_candidate_index,
				x = fitting.center.x,
				y = surface_y, z = fitting.center.z,
				platform_kind = kind == "anchor_platform" and kind or nil,
				path_kind = spur_id_by_anchor[anchor.id],
				functional_feature_id = feature_id}
			anchor_records[anchor_index] = record
			anchor_evidence[anchor_index] = deep_copy(record)
			anchor_evidence[anchor_index].reference_y = fitting.reference_y
			anchor_evidence[anchor_index].reference_rule = fitting.reference_rule
			anchor_evidence[anchor_index].profile_midpoint_y =
				zone_midpoint_y[anchor.zone_numeric_id]
			anchor_evidence[anchor_index].fitting_width = profile.fitting_width
			anchor_evidence[anchor_index].blend_width = profile.blend_width
			anchor_evidence[anchor_index].collar_width =
				(profile.blend_width - profile.fitting_width) / 2
			anchor_evidence[anchor_index].fitting_columns = fitting_columns
			anchor_evidence[anchor_index].collar_columns = collar_columns
			anchor_evidence[anchor_index].owner_escape_columns = 0
			anchor_evidence[anchor_index].observed_max_cut = observed_max_cut
			anchor_evidence[anchor_index].observed_max_cut_witness_x = cut_x
			anchor_evidence[anchor_index].observed_max_cut_witness_z = cut_z
			anchor_evidence[anchor_index].observed_max_fill = observed_max_fill
			anchor_evidence[anchor_index].observed_max_fill_witness_x = fill_x
			anchor_evidence[anchor_index].observed_max_fill_witness_z = fill_z
			anchor_evidence[anchor_index].rejected = false
			anchor_evidence[anchor_index].reselected = false
			anchor_evidence[anchor_index].platform_columns = platform_columns
			anchor_evidence[anchor_index].civic_water_columns =
				fitting.civic_water_count
			anchor_evidence[anchor_index].civic_max_clearance_y =
				fitting.civic_max_clearance_y
			anchor_evidence[anchor_index].civic_max_clearance_witness_x =
				fitting.civic_witness_x
			anchor_evidence[anchor_index].civic_max_clearance_witness_z =
				fitting.civic_witness_z
			anchor_evidence[anchor_index].platform_witness_x = platform_witness_x
			anchor_evidence[anchor_index].platform_witness_z = platform_witness_z
		end

		local hard_records, hard_evidence = {}, {}
		for hard_index = 1, #source.hard_protection do
			local source_hard = source.hard_protection[hard_index]
			local record = deep_copy(source_hard)
			local recipe
			for recipe_index = 1, #source.hard_protection_recipes do
				if source.hard_protection_recipes[recipe_index].id == record.recipe_id then
					recipe = source.hard_protection_recipes[recipe_index] break
				end
			end
			if not recipe then fail("hard-protection recipe missing") end
			record.y_min = recipe.y_min
			record.upward_unbounded = recipe.upward_unbounded
			record.y_policy_id = recipe.y_policy_id
			if record.center then
				local _, surface_y = final_functional_values_at(record.center.x,
					record.center.z)
				record.surface_y = surface_y or final_terrain_height_at(record.center.x,
					record.center.z)
			else record.surface_y = nil end
			hard_records[hard_index] = record
			hard_evidence[hard_index] = deep_copy(record)
		end

		local operation_evidence, tunnel_evidence = {}, {}
		local operation_counts = {named = #named_operation_evidence,
			derived_runs = #derived_water_evidence, tunnels = #tunnel_operations,
			ford_approach_runs = #ford_approach_evidence,
			causeway_columns = 0, bridge_columns = 0,
			tunnel_named_operation_overlap_columns = 0}
		local operation_digest_rows = {}
		for operation_index = 1, #named_operation_evidence do
			local evidence = named_operation_evidence[operation_index]
			operation_evidence[#operation_evidence + 1] = deep_copy(evidence)
			operation_digest_rows[#operation_digest_rows + 1] = canonical.array({
				text("named"), text(evidence.interface_id), text(evidence.path_id),
				text(evidence.kind), signed(evidence.footprint_columns),
				text(evidence.classification_digest)})
		end
		for index = 1, #derived_water_evidence do
			local evidence = derived_water_evidence[index]
			operation_counts.causeway_columns = operation_counts.causeway_columns +
				evidence.causeway_columns
			operation_counts.bridge_columns = operation_counts.bridge_columns +
				evidence.bridge_columns
			operation_digest_rows[#operation_digest_rows + 1] = canonical.array({
				text("derived"), text(evidence.path_id), signed(evidence.run),
				signed(evidence.causeway_columns), signed(evidence.bridge_columns),
				text(evidence.classification_digest)})
		end
		for tunnel_index = 1, #tunnel_operations do
			local operation = tunnel_operations[tunnel_index]
			local evidence = {interface_id = operation.interface_id,
				path_id = operation.path.id, center_run = operation.center_run,
				first_run = operation.first_run, last_run = operation.last_run,
				axis_node_count = operation.last_run - operation.first_run + 1,
				footprint_columns = operation.footprint_columns,
				interior_min = operation.interior_min,
				interior_min_witness_x = operation.interior_min_witness_x,
				interior_min_witness_z = operation.interior_min_witness_z,
				baseline_y = operation.baseline_y,
				feasible_lower_y = operation.feasible_lower_y,
				feasible_upper_y = operation.feasible_upper_y,
				floor_y = operation.surface_y,
				before_pin_run = operation.before_pin_run,
				before_pin_y = operation.before_pin_y,
				before_pin_source_id = operation.before_pin_source_id,
				after_pin_run = operation.after_pin_run,
				after_pin_y = operation.after_pin_y,
				after_pin_source_id = operation.after_pin_source_id,
				minimum_overburden = operation.minimum_overburden,
				overburden_witness_x = operation.overburden_witness_x,
				overburden_witness_z = operation.overburden_witness_z,
				named_overlap_columns = operation.named_overlap_columns,
				tunnel_overlap_columns = operation.tunnel_overlap_columns,
				classification_digest = operation.classification_digest}
			tunnel_evidence[tunnel_index] = evidence
			operation_evidence[#operation_evidence + 1] = deep_copy(evidence)
			operation_evidence[#operation_evidence].kind = "tunnel_floor"
			operation_digest_rows[#operation_digest_rows + 1] = canonical.array({
				text("tunnel"), text(evidence.interface_id), text(evidence.path_id),
				signed(evidence.first_run), signed(evidence.last_run),
				signed(evidence.floor_y), text(evidence.classification_digest)})
		end
		operation_counts.total = operation_counts.named +
			operation_counts.derived_runs + operation_counts.tunnels
		local operation_digest = counted_digest(operation_digest_rows)
		local route_digest_rows = {}
		for index = 1, #route_evidence do
			local row = route_evidence[index]
			route_digest_rows[#route_digest_rows + 1] = canonical.array({
				text(row.id), text(row.kind), signed(row.node_count),
				signed(row.baseline_min_y), signed(row.baseline_max_y),
				signed(row.final_min_y), signed(row.final_max_y),
				signed(row.maximum_step), text(row.final_grade_digest)})
		end
		local route_digest = counted_digest(route_digest_rows)
		local tunnel_named_operation_overlap_columns = 0

		local primary_profile_evidence = {}
		for profile_index = 1, #profiles do
			local profile = profiles[profile_index]
			local stats = primary_profile_stats[profile_index]
			primary_profile_evidence[profile_index] = {numeric_id = profile_index,
				id = profile.id, root = profile.root,
				authored_min_y = WATER_LEVEL + profile.min_above_water,
				authored_max_y = WATER_LEVEL + profile.max_above_water,
				octave_count = #profile.octaves,
				sample_count = stats.count, observed_min_y = stats.minimum,
				observed_min_count = stats.minimum_count,
				observed_min_witness_x = stats.minimum_x,
				observed_min_witness_z = stats.minimum_z,
				observed_max_y = stats.maximum,
				observed_max_count = stats.maximum_count,
				observed_max_witness_x = stats.maximum_x,
				observed_max_witness_z = stats.maximum_z}
		end

		for landmark_index = 1, #landmarks do
			local landmark = landmarks[landmark_index]
			local applied_count, full_mask_count, collar_count = 0, 0, 0
			local rejected_owner_count, observed_min, observed_max = 0
			local min_x, min_z, max_x, max_z
			for z = math.max(bounds.min_z,
					landmark.center.z - landmark.radius_z - BASE_CELL),
					math.min(bounds.max_z,
					landmark.center.z + landmark.radius_z + BASE_CELL) do
				for x = math.max(bounds.min_x,
						landmark.center.x - landmark.radius_x - BASE_CELL),
						math.min(bounds.max_x,
						landmark.center.x + landmark.radius_x + BASE_CELL) do
					local weight = landmark_weight(landmark, x, z)
					if weight > 0 then
						local _, _, owner = classified_values(x, z)
						if owner == landmark.zone_numeric_id then
							applied_count = applied_count + 1
							if weight == Q then full_mask_count = full_mask_count + 1
							else collar_count = collar_count + 1 end
							local replacement = raw_profile_height(landmark.replacement,
								x, z)
							if not observed_min or replacement < observed_min then
								observed_min, min_x, min_z = replacement, x, z
							end
							if not observed_max or replacement > observed_max then
								observed_max, max_x, max_z = replacement, x, z
							end
						else rejected_owner_count = rejected_owner_count + 1 end
					end
				end
			end
			local evidence = landmark_evidence[landmark_index]
			evidence.center_weight_q = landmark_weight(landmark,
				landmark.center.x, landmark.center.z)
			evidence.center_natural_y = natural_height_at(landmark.center.x,
				landmark.center.z)
			evidence.owner_clipped_count = applied_count
			evidence.mask_columns = full_mask_count
			evidence.collar_columns = collar_count
			evidence.rejected_owner_count = rejected_owner_count
			evidence.owner_escape_columns = 0
			evidence.observed_min_y = observed_min
			evidence.observed_min_witness_x = min_x
			evidence.observed_min_witness_z = min_z
			evidence.observed_max_y = observed_max
			evidence.observed_max_witness_x = max_x
			evidence.observed_max_witness_z = max_z
		end

		local exterior_evidence, exterior_seen = {}, {}
		for z = bounds.min_z, bounds.max_z, 32 do
			for x = bounds.min_x, bounds.max_x, 32 do
				local water_class, _, _, bay_id = classified_values(x, z)
				local key = bay_id and "bay" or water_class
				if (key == "bay" or key == "coastal_shelf" or
						key == "deep_ocean" or
						key == "immutable_dragon_channel") and not exterior_seen[key] then
					exterior_seen[key] = true
					exterior_evidence[#exterior_evidence + 1] = {kind = key,
						x = x, z = z, terrain_y = final_terrain_height_at(x, z),
						water_y = final_water_surface_at(x, z), bay_id = bay_id}
				end
			end
		end
		for _, key in ipairs({"bay", "coastal_shelf", "deep_ocean",
				"immutable_dragon_channel"}) do
			if not exterior_seen[key] then fail("missing exterior witness " .. key) end
		end

		local relief_lattice_digest = counted_digest({canonical.array({
			text(HEIGHT_SCHEMA), text(octave_lattice_digest),
			text(base_lattice_digest)})})
		local artifact_evidence = {
			height_schema = HEIGHT_SCHEMA,
			schema = HEIGHT_SCHEMA,
			source_schema = source.schema,
			layout_id = source.layout_id,
			layout_revision_id = source.layout_revision_id,
			full_seed_string = full_seed_string,
			water_level = WATER_LEVEL,
			base_lattice_digest = base_lattice_digest,
			relief_lattice_digest = relief_lattice_digest,
			octave_lattice_digest = octave_lattice_digest,
			relief_roots = relief_roots,
			octave_lattices = octave_evidence,
			primary_profiles = primary_profile_evidence,
			landmarks = landmark_evidence,
			stations = station_evidence,
			anchors = anchor_evidence,
			source_cut_fill_limits_consumed = false,
			hard_protection = hard_evidence,
			routes = route_evidence,
			route_exact_pins = route_exact_pin_evidence,
			route_water_lower_bounds = route_lower_bound_evidence,
			route_raise_witnesses = route_raise_evidence,
			ford_approaches = ford_approach_evidence,
			ford_approach_summaries = ford_approach_summary_evidence,
			named_water_operations = named_operation_evidence,
			derived_water_runs = derived_water_evidence,
			landings = landing_evidence,
			tunnels = tunnel_evidence,
			water_operations = operation_evidence,
			operation_counts = operation_counts,
			operation_digest = operation_digest,
			route_digest = route_digest,
			visible_surface_classification_digest =
				visible_surface_classification_digest,
			tunnel_named_operation_overlap_columns =
				tunnel_named_operation_overlap_columns,
			hydrology = hydrology_evidence,
			interfaces = interface_evidence,
			wet_reach_contact_pairs = 12,
			unequal_interface_pairs =
				hydrology_interface_population.unequal_level_pairs,
			hydrology_interface_population = hydrology_interface_population,
			contact_face_waterfalls = contact_face_evidence,
			exterior_witnesses = exterior_evidence,
			coastal_cores = coastal_evidence,
		}

		local kat_rows = {canonical.array({text("schema"), text(HEIGHT_SCHEMA),
			text(source.schema), text(source.layout_id),
			text(source.layout_revision_id), text(full_seed_string),
			signed(WATER_LEVEL), text(relief_lattice_digest),
			text(base_lattice_digest)})}
		for index = 1, #relief_roots do
			local row = relief_roots[index]
			kat_rows[#kat_rows + 1] = canonical.array({text("root"), signed(index),
				text(row.id), signed(row.root)})
		end
		for _, coordinates in ipairs({{bounds.min_x, bounds.min_z}, {-2049, -1537},
				{-1, -1}, {0, 0}, {1, 1}, {2049, 1537},
				{bounds.max_x, bounds.max_z}}) do
			local x, z = coordinates[1], coordinates[2]
			local kind, surface_y, feature_id, interface_id =
				final_functional_values_at(x, z)
			local transition_kind, transition_id, upper_y, lower_y, progress_q,
				face_mask
			local transition, progress, transition_face_mask =
				transition_values_at(x, z)
			if transition then transition_kind, transition_id, upper_y, lower_y,
				progress_q = transition.kind, transition.id, transition.upper_y,
				transition.lower_y, progress
				face_mask = transition_face_mask end
			kat_rows[#kat_rows + 1] = canonical.array({text("query"), signed(x),
				signed(z), signed(final_terrain_height_at(x, z)),
				signed(final_water_surface_at(x, z) or -2147483648), text(kind),
				signed(surface_y or -2147483648), text(feature_id),
				text(interface_id), text(transition_kind), text(transition_id),
				signed(upper_y or -2147483648), signed(lower_y or -2147483648),
				signed(progress_q or -2147483648),
				signed(face_mask or -2147483648)})
		end
		for index = 1, #anchor_records do
			local row = anchor_records[index]
			kat_rows[#kat_rows + 1] = canonical.array({text("anchor"),
				signed(index), text(row.id), text(row.selection_mode),
				signed(row.approved_candidate_index),
				signed(row.x), signed(row.y), signed(row.z),
				text(row.platform_kind), text(row.path_kind)})
		end
		for index = 1, #contact_face_evidence do
			local row = contact_face_evidence[index]
			kat_rows[#kat_rows + 1] = canonical.array({text("contact_face"),
				text(row.id), text(row.upper_id), text(row.lower_id),
				signed(row.upper_y), signed(row.lower_y),
				signed(row.contact_edge_count), signed(row.upper_lip_count),
				signed(row.lower_face_count), signed(row.receiver_y),
				signed(row.receiver_source_min_y),
				signed(row.receiver_source_max_y),
				signed(row.authored_falling_water_columns),
				text(row.contact_edge_digest), text(row.upper_lip_digest),
				text(row.lower_face_digest), text(row.direction_mask_digest),
				text(row.contact_face_digest)})
		end
		kat_rows[#kat_rows + 1] = canonical.array({text("route_digest"),
			text(route_digest), text("operation_digest"), text(operation_digest),
			text("visible_surface_classification_digest"),
			text(visible_surface_classification_digest)})
		local canonical_kat = canonical.encode(canonical.array(kat_rows))
		local canonical_kat_digest = canonical.hex(counted_sha(canonical_kat))

		local metrics = {relief_profile_count = #profiles,
			octave_lattice_count = #octave_evidence,
			base_lattice_vertex_count = #base_rows,
			graded_path_count = #paths,
			contact_face_waterfall_count = #contact_face_records,
			water_operation_count = operation_counts.total}

		local session = {}

		function session.terrain_height_at(x, z)
			return final_terrain_height_at(x, z)
		end

		function session.water_surface_at(x, z)
			return final_water_surface_at(x, z)
		end

		function session.functional_surface_values_at(x, z)
			return final_functional_values_at(x, z)
		end

		function session.hydrology_transition_values_at(x, z)
			coordinate(x, "transition query x") coordinate(z, "transition query z")
			if x < bounds.min_x or x > bounds.max_x or z < bounds.min_z or
					z > bounds.max_z then return nil, nil, nil, nil, nil, nil end
			local transition, progress, face_mask = transition_values_at(x, z)
			if not transition then return nil, nil, nil, nil, nil, nil end
			return transition.kind, transition.id, transition.upper_y,
				transition.lower_y, progress, face_mask
		end

		function session.selected_anchor_3d_by_id(anchor_id)
			if type(anchor_id) ~= "string" then return nil end
			local anchor = anchor_by_id[anchor_id]
			return anchor and deep_copy(anchor_records[anchor.numeric_id]) or nil
		end

		function session.hard_protection_volumes()
			return deep_copy(hard_records)
		end

		function session.relief_lattice_digest()
			return relief_lattice_digest
		end

		function session.base_lattice_digest()
			return base_lattice_digest
		end

		function session.canonical_kat()
			return canonical_kat
		end

		function session.canonical_kat_digest()
			return canonical_kat_digest
		end

		function session.artifact_evidence()
			return deep_copy(artifact_evidence)
		end

		function session.metrics()
			local result = deep_copy(metrics)
			result.construction_sha256_calls = construction_sha_calls
			result.query_sha256_calls = query_sha_calls
			result.query_lattice_constructions = query_lattice_constructions
			return result
		end

		return session
	end

		local function ordered_pin_indices(path)
			local result = {}
			for run_index in pairs(path.pins) do result[#result + 1] = run_index end
			table.sort(result)
			return result
		end

		local function baseline_from_pins(path)
			local pins = path.pins
			local indices = ordered_pin_indices(path)
			local result = {}
			if #indices < 2 or indices[1] ~= 1 or
					indices[#indices] ~= #path.axis then
				fail("route pin set does not cover axis at " .. path.id)
			end
			for index = 1, #indices - 1 do
				local a, b = indices[index], indices[index + 1]
				local ay, by = pins[a].y, pins[b].y
				if math.abs(by - ay) > b - a then
					fail("route exact-pin interval is infeasible at " .. path.id)
				end
				for run_index = a, b do
					result[run_index] = ay + round_ratio(
						(by - ay) * (run_index - a), b - a)
				end
			end
			return result
		end

		local function visit_path_surface(path, first_run, last_run, callback)
			local seen = {}
			for segment_index = 1, #path.source_segments do
				local segment = path.source_segments[segment_index]
				local min_x = math.min(segment.a.x, segment.b.x) - path.surface_width
				local max_x = math.max(segment.a.x, segment.b.x) + path.surface_width
				local min_z = math.min(segment.a.z, segment.b.z) - path.surface_width
				local max_z = math.max(segment.a.z, segment.b.z) + path.surface_width
				for z = min_z, max_z do
					local row = seen[z]
					if not row then row = {} seen[z] = row end
					for x = min_x, max_x do
						if not row[x] then
							row[x] = true
							local run_index = path_surface_run_at(path, x, z)
							if run_index and run_index >= first_run and
									run_index <= last_run then
								callback(x, z, run_index)
							end
						end
					end
				end
			end
		end

		tunnel_operations = {}
		local tunnel_column_owner = {}
		for crossing_index = 1, #source.crossing_interfaces do
			local crossing = source.crossing_interfaces[crossing_index]
			if crossing.kind == "tunnel" then
				local path = path_by_id[crossing.route_id]
				if not path then fail("tunnel route missing") end
				local center_run
				for run_index = 1, #path.axis do
					local point = path.axis[run_index]
					if point.x == crossing.position.x and point.z == crossing.position.z then
						center_run = run_index break
					end
				end
				if not center_run or center_run <= 16 or
						center_run + 16 > #path.axis then
					fail("tunnel does not have its exact 33-node span")
				end
				local first_run, last_run = center_run - 16, center_run + 16
				for index = 1, #tunnel_operations do
					local old = tunnel_operations[index]
					if old.path == path and first_run <= old.last_run and
							last_run >= old.first_run then
						fail("tunnel interfaces overlap")
					end
				end
				local pin_indices = ordered_pin_indices(path)
				local before_run, after_run
				for index = 1, #pin_indices do
					local run_index = pin_indices[index]
					if run_index < first_run then before_run = run_index end
					if run_index > last_run then after_run = run_index break end
				end
				if not before_run or not after_run then
					fail("tunnel lacks external non-tunnel pins")
				end
				local baseline = baseline_from_pins(path)
				local baseline_y = baseline[center_run]
				local interior_min, interior_x, interior_z, footprint_columns
				local tunnel_rows, named_overlap_columns, tunnel_overlap_columns =
					{}, 0, 0
				visit_path_surface(path, first_run, last_run,
					function(x, z, run_index)
						footprint_columns = (footprint_columns or 0) + 1
						local water_class = classified_values(x, z)
						if water_class ~= "land" then
							fail("tunnel footprint is not land at " .. crossing.id)
						end
						if named_operation_column_at(path, x, z, run_index) then
							named_overlap_columns = named_overlap_columns + 1
						end
						local key = x .. ":" .. z
						if tunnel_column_owner[key] then
							tunnel_overlap_columns = tunnel_overlap_columns + 1
						else tunnel_column_owner[key] = crossing.id end
						local h = scalar_before_paths(x, z)
						if interior_min == nil or h < interior_min then
							interior_min, interior_x, interior_z = h, x, z
						end
						tunnel_rows[#tunnel_rows + 1] = canonical.array({
							signed(x), signed(z), signed(run_index), signed(h)})
					end)
				if named_overlap_columns ~= 0 or tunnel_overlap_columns ~= 0 then
					fail("tunnel footprint overlaps another operation")
				end
				local before_y, after_y = path.pins[before_run].y,
					path.pins[after_run].y
				local before_distance, after_distance = first_run - before_run,
					after_run - last_run
				local lower = math.max(before_y - before_distance,
					after_y - after_distance)
				local upper = math.min(interior_min - 5,
					before_y + before_distance, after_y + after_distance)
				if lower > upper then
					fail("tunnel floor interval is empty at " .. crossing.id)
				end
				local floor_y = clamp(baseline_y, lower, upper)
				add_pin(path, first_run, floor_y, "tunnel_first", crossing.id)
				add_pin(path, last_run, floor_y, "tunnel_last", crossing.id)
				local operation = {kind = "tunnel_floor", feature_id = path.id,
					interface_id = crossing.id, path = path, first_run = first_run,
					last_run = last_run, surface_y = floor_y, tunnel = true,
					center_run = center_run, interior_min = interior_min,
					interior_min_witness_x = interior_x,
					interior_min_witness_z = interior_z,
					footprint_columns = footprint_columns,
					baseline_y = baseline_y, feasible_lower_y = lower,
					feasible_upper_y = upper, before_pin_run = before_run,
					before_pin_y = before_y,
					before_pin_source_id = path.pins[before_run].source_id,
					after_pin_run = after_run, after_pin_y = after_y,
					after_pin_source_id = path.pins[after_run].source_id,
					minimum_overburden = interior_min - floor_y,
					overburden_witness_x = interior_x,
					overburden_witness_z = interior_z,
					named_overlap_columns = named_overlap_columns,
					tunnel_overlap_columns = tunnel_overlap_columns,
					classification_digest = counted_digest(tunnel_rows)}
				path.operations[#path.operations + 1] = operation
				tunnel_operations[#tunnel_operations + 1] = operation
				water_operations[#water_operations + 1] = operation
			end
		end

		local function lexicographically_before(x, z, old_x, old_z)
			return old_x == nil or x < old_x or (x == old_x and z < old_z)
		end

		local function ford_cap_at(path, hydrology_id, run_index, ordinary_lower)
			local best, best_cap
			for index = 1, #path.fords do
				local ford = path.fords[index]
				if ford.hydrology_id == hydrology_id then
					local cap = ford.ford_pin_y + math.abs(run_index - ford.ford_run)
					if cap < ordinary_lower and (not best or cap < best_cap or
							(cap == best_cap and ford.interface_id < best.interface_id)) then
						best, best_cap = ford, cap
					end
				end
			end
			return best, best_cap
		end

		path_grid = {}
		for path_index = 1, #paths do
			local path = paths[path_index]
			for segment_index = 1, #path.source_segments do
				local segment = path.source_segments[segment_index]
				segment.path = path
				add_bucket(path_grid, segment,
					math.min(segment.a.x, segment.b.x) - path.corridor_width,
					math.max(segment.a.x, segment.b.x) + path.corridor_width,
					math.min(segment.a.z, segment.b.z) - path.corridor_width,
					math.max(segment.a.z, segment.b.z) + path.corridor_width)
			end
		end

		local function path_segment_better(segment, numerator, denominator,
				best, best_numerator, best_denominator)
			if not best then return true end
			local comparison = rational_compare(numerator, denominator,
				best_numerator, best_denominator)
			if comparison ~= 0 then return comparison < 0 end
			if segment.path.priority ~= best.path.priority then
				return segment.path.priority < best.path.priority
			end
			if segment.path.id ~= best.path.id then
				return segment.path.id < best.path.id
			end
			return segment.ordinal < best.ordinal
		end

		local function nearest_path_segment_at(x, z, width_kind, only_path)
			local candidates = only_path and only_path.source_segments or
				bucket_at(path_grid, x, z)
			if not candidates then return nil end
			local best, best_numerator, best_denominator, best_dot, best_length
			for index = 1, #candidates do
				local segment = candidates[index]
				local path = segment.path or only_path
				local width = width_kind == "surface" and path.surface_width or
					path.corridor_width
				local numerator, denominator, dot, length_squared =
					point_segment_ratio(x, z, segment.a, segment.b)
				if corridor_member_ratio(numerator, denominator, width) and
						path_segment_better(segment, numerator, denominator, best,
							best_numerator, best_denominator) then
					best, best_numerator, best_denominator = segment, numerator,
						denominator
					best_dot, best_length = dot, length_squared
				end
			end
			if not best then return nil end
			return best, best_numerator, best_denominator,
				projected_run_for_segment(best, best_dot, best_length)
		end

		local function winning_named_operation_at(x, z)
			local winner
			for operation_index = 1, #named_water_operations do
				local operation = named_water_operations[operation_index]
				local run_index = path_surface_run_at(operation.path, x, z)
				if run_index and named_operation_column_at(operation.path, x, z,
						run_index) == operation and (not winner or
						operation.interface_id < winner.interface_id) then
					winner = operation
				end
			end
			return winner
		end

		route_evidence, route_exact_pin_evidence = {}, {}
		route_lower_bound_evidence, route_raise_evidence = {}, {}
		ford_approach_evidence, ford_approach_summary_evidence = {}, {}
		named_operation_evidence, derived_water_evidence = {}, {}
		local complete_classification_rows = {}
		for path_index = 1, #paths do
			local path = paths[path_index]
			path.baseline = baseline_from_pins(path)
			path.lower, path.lower_columns, path.lower_witness = {}, {}, {}
			path.ford_cap_by_run = {}
			visit_path_surface(path, 1, #path.axis, function(x, z, run_index)
				local water_class, _, owner, bay_id, hydrology_id =
					classified_values(x, z)
				if water_class == "planned_water" then
					if owner ~= path.owner_a and owner ~= path.owner_b then
						fail("graded path enters non-local planned water at " .. path.id)
					end
					local datum = clearance_datum_at(x, z, water_class, bay_id,
						hydrology_id)
					if datum == nil then fail("path water has no clearance datum") end
					local operation = named_operation_column_at(path, x, z, run_index)
					local lower_y, bound_kind, interface_id
					if operation then
						bound_kind, interface_id = operation.kind, operation.interface_id
						if operation.kind == "bridge_deck" then lower_y = datum + 4
						elseif operation.kind == "causeway" then lower_y = datum + 1
						else lower_y = datum - 1 end
					else
						local uncapped = datum + 1
						local ford, cap = ford_cap_at(path, hydrology_id, run_index,
							uncapped)
						if ford then
							lower_y, bound_kind, interface_id = cap, "ford_approach",
								ford.interface_id
							local active = path.ford_cap_by_run[run_index]
							if not active or uncapped > active.uncapped_lower_y or
									(uncapped == active.uncapped_lower_y and
										lexicographically_before(x, z, active.witness_x,
											active.witness_z)) then
								path.ford_cap_by_run[run_index] = {path_id = path.id,
									run = run_index, interface_id = ford.interface_id,
									hydrology_id = hydrology_id, ford_run = ford.ford_run,
									ford_pin_y = ford.ford_pin_y,
									distance = math.abs(run_index - ford.ford_run),
									uncapped_lower_y = uncapped, capped_lower_y = cap,
									witness_x = x, witness_z = z}
							end
						else lower_y, bound_kind = uncapped, "ordinary_water" end
					end
					path.lower_columns[run_index] =
						(path.lower_columns[run_index] or 0) + 1
					local old = path.lower[run_index]
					local witness = path.lower_witness[run_index]
					if old == nil or lower_y > old or (lower_y == old and
							lexicographically_before(x, z, witness.x, witness.z)) then
						path.lower[run_index] = lower_y
						path.lower_witness[run_index] = {x = x, z = z,
							kind = bound_kind, interface_id = interface_id,
							water_y = datum, lower_y = lower_y, run = run_index}
					end
				elseif water_class ~= "land" then
					fail("graded path enters forbidden exterior water at " .. path.id)
				end
			end)

			path.y, path.support = {}, {}
			for run_index = 1, #path.axis do
				local lower_y = path.lower[run_index]
				if lower_y and lower_y > path.baseline[run_index] then
					path.y[run_index] = lower_y
					path.support[run_index] = path.lower_witness[run_index]
				else path.y[run_index] = path.baseline[run_index] end
			end
			for run_index = 2, #path.axis do
				local raised = path.y[run_index - 1] - 1
				if raised > path.y[run_index] then
					path.y[run_index], path.support[run_index] = raised,
						path.support[run_index - 1]
				end
			end
			for run_index = #path.axis - 1, 1, -1 do
				local raised = path.y[run_index + 1] - 1
				if raised > path.y[run_index] then
					path.y[run_index], path.support[run_index] = raised,
						path.support[run_index + 1]
				end
			end

			local pin_indices = ordered_pin_indices(path)
			for pin_index = 1, #pin_indices do
				local run_index = pin_indices[pin_index]
				local pin = path.pins[run_index]
				if path.y[run_index] ~= pin.y then
					fail("route envelope changed exact pin at " .. path.id)
				end
				route_exact_pin_evidence[#route_exact_pin_evidence + 1] = {
					path_id = path.id, run = run_index, pin_kind = pin.pin_kind,
					source_id = pin.source_id, y = pin.y,
					baseline_y = path.baseline[run_index], final_y = path.y[run_index]}
			end
			local baseline_rows, final_rows, pin_rows, lower_rows = {}, {}, {}, {}
			local baseline_min, baseline_max, final_min, final_max, maximum_step
			local lower_run_count, lower_column_count, raised_run_count = 0, 0, 0
			for run_index = 1, #path.axis do
				local point = path.axis[run_index]
				local base_y, final_y = path.baseline[run_index], path.y[run_index]
				baseline_min = baseline_min and math.min(baseline_min, base_y) or base_y
				baseline_max = baseline_max and math.max(baseline_max, base_y) or base_y
				final_min = final_min and math.min(final_min, final_y) or final_y
				final_max = final_max and math.max(final_max, final_y) or final_y
				baseline_rows[#baseline_rows + 1] = canonical.array({signed(run_index),
					signed(point.x), signed(point.z), signed(base_y)})
				final_rows[#final_rows + 1] = canonical.array({signed(run_index),
					signed(final_y)})
				if run_index > 1 then
					local step = math.abs(final_y - path.y[run_index - 1])
					maximum_step = math.max(maximum_step or 0, step)
					if step > 1 then fail("final route step exceeds one at " .. path.id) end
				end
				if path.lower[run_index] then
					lower_run_count = lower_run_count + 1
					lower_column_count = lower_column_count + path.lower_columns[run_index]
					local witness = path.lower_witness[run_index]
					local row = {path_id = path.id, run = run_index,
						column_count = path.lower_columns[run_index],
						lower_y = path.lower[run_index], witness_x = witness.x,
						witness_z = witness.z, bound_kind = witness.kind,
						interface_id = witness.interface_id}
					route_lower_bound_evidence[#route_lower_bound_evidence + 1] = row
					lower_rows[#lower_rows + 1] = canonical.array({signed(run_index),
						signed(row.column_count), signed(row.lower_y), signed(row.witness_x),
						signed(row.witness_z), text(row.bound_kind), text(row.interface_id)})
				end
				if final_y > base_y then
					raised_run_count = raised_run_count + 1
					local support = path.support[run_index]
					if not support then fail("raised route run has no lower-bound support") end
					route_raise_evidence[#route_raise_evidence + 1] = {
						path_id = path.id, run = run_index, baseline_y = base_y,
						final_y = final_y, support_run = support.run,
						support_lower_y = support.lower_y, support_x = support.x,
						support_z = support.z, support_kind = support.kind,
						support_id = support.interface_id}
				end
				local active = path.ford_cap_by_run[run_index]
				if active then ford_approach_evidence[#ford_approach_evidence + 1] =
					deep_copy(active) end
			end
			for pin_index = 1, #pin_indices do
				local run_index = pin_indices[pin_index]
				local pin = path.pins[run_index]
				pin_rows[#pin_rows + 1] = canonical.array({signed(run_index),
					text(pin.pin_kind), text(pin.source_id), signed(pin.y)})
			end

			local classification_rows = {}
			local derived_by_run = {}
			visit_path_surface(path, 1, #path.axis, function(x, z, run_index)
				local water_class, _, owner, bay_id, hydrology_id =
					classified_values(x, z)
				local kind, interface_id = "land_grade", nil
				if water_class == "planned_water" and
						(owner == path.owner_a or owner == path.owner_b) then
					local operation = named_operation_column_at(path, x, z, run_index)
					if operation then kind, interface_id = operation.kind,
						operation.interface_id
					else
						local datum = clearance_datum_at(x, z, water_class, bay_id,
							hydrology_id)
						local ford = ford_cap_at(path, hydrology_id, run_index, datum + 1)
						if ford then kind, interface_id = "ford", ford.interface_id
						elseif path.y[run_index] == datum + 1 then kind = "causeway"
						else kind = "bridge_deck" end
						local winning_segment = nearest_path_segment_at(x, z,
							"surface", nil)
						local visible_derived = not ford and winning_segment and
							winning_segment.path == path and
							winning_named_operation_at(x, z) == nil
						if visible_derived then
							local row = derived_by_run[run_index]
							if not row then row = {path_id = path.id, run = run_index,
								causeway_columns = 0, bridge_columns = 0, rows = {}}
								derived_by_run[run_index] = row end
							if kind == "causeway" then
								row.causeway_columns = row.causeway_columns + 1
								if lexicographically_before(x, z, row.causeway_witness_x,
										row.causeway_witness_z) then
									row.causeway_witness_x, row.causeway_witness_z = x, z
								end
							else
								row.bridge_columns = row.bridge_columns + 1
								if lexicographically_before(x, z, row.bridge_witness_x,
										row.bridge_witness_z) then
									row.bridge_witness_x, row.bridge_witness_z = x, z
								end
							end
							row.rows[#row.rows + 1] = canonical.array({signed(x), signed(z),
								signed(run_index), text(kind), signed(path.y[run_index])})
						end
					end
				end
				local encoded = canonical.array({text(path.id), signed(x), signed(z),
					signed(run_index), text(kind), signed(path.y[run_index]),
					text(interface_id)})
				classification_rows[#classification_rows + 1] = encoded
				complete_classification_rows[#complete_classification_rows + 1] = encoded
			end)
			for run_index = 1, #path.axis do
				local row = derived_by_run[run_index]
				if row then
					row.classification_digest = counted_digest(row.rows)
					row.rows = nil
					derived_water_evidence[#derived_water_evidence + 1] = row
				end
			end
			local classification_digest = counted_digest(classification_rows)
			route_evidence[path_index] = {numeric_id = path_index, id = path.id,
				kind = path.kind, node_count = #path.axis,
				baseline_min_y = baseline_min, baseline_max_y = baseline_max,
				final_min_y = final_min, final_max_y = final_max,
				maximum_step = maximum_step or 0, exact_pin_count = #pin_indices,
				water_lower_bound_run_count = lower_run_count,
				water_lower_bound_column_count = lower_column_count,
				raised_run_count = raised_run_count,
				support_witness_count = raised_run_count,
				baseline_digest = counted_digest(baseline_rows),
				final_grade_digest = counted_digest(final_rows),
				exact_pin_digest = counted_digest(pin_rows),
				lower_bound_digest = counted_digest(lower_rows),
				classification_digest = classification_digest}
		end

		for operation_index = 1, #named_water_operations do
			local operation = named_water_operations[operation_index]
			local count, minimum, maximum, witness_x, witness_z = 0
			local rows = {}
			visit_path_surface(operation.path, operation.first_run,
				operation.last_run, function(x, z, run_index)
					if named_operation_column_at(operation.path, x, z, run_index) ==
							operation then
						local surface_y = operation.path.y[run_index]
						count = count + 1
						minimum = minimum and math.min(minimum, surface_y) or surface_y
						maximum = maximum and math.max(maximum, surface_y) or surface_y
						local identity_wins = true
						for other_index = 1, #named_water_operations do
							local other = named_water_operations[other_index]
							if other ~= operation and
									other.interface_id < operation.interface_id then
								local other_run = path_surface_run_at(other.path, x, z)
								if other_run and named_operation_column_at(other.path,
										x, z, other_run) == other then
									identity_wins = false
									break
								end
							end
						end
						if identity_wins and
								lexicographically_before(x, z, witness_x, witness_z) then
							witness_x, witness_z = x, z
						end
						rows[#rows + 1] = canonical.array({signed(x), signed(z),
							signed(run_index), signed(surface_y)})
					end
				end)
			if count == 0 then fail("named operation has empty 2D footprint") end
			if not witness_x then fail("named operation has no final identity witness") end
			named_operation_evidence[operation_index] = {
				interface_id = operation.interface_id, path_id = operation.path.id,
				kind = operation.kind, footprint_columns = count,
				min_surface_y = minimum, max_surface_y = maximum,
				first_witness_x = witness_x, first_witness_z = witness_z,
				classification_digest = counted_digest(rows)}
		end
		visible_surface_classification_digest =
			counted_digest(complete_classification_rows)

		for path_index = 1, #paths do
			local path = paths[path_index]
			for ford_index = 1, #path.fords do
				local ford = path.fords[ford_index]
				local count, first_run, last_run = 0
				for run_index = 1, #path.axis do
					local active = path.ford_cap_by_run[run_index]
					if active and active.interface_id == ford.interface_id then
						count = count + 1
						first_run = first_run and math.min(first_run, run_index) or run_index
						last_run = last_run and math.max(last_run, run_index) or run_index
					end
				end
				local resume_before_run, resume_after_run
				if first_run then
					for run_index = first_run - 1, 1, -1 do
						local witness = path.lower_witness[run_index]
						if witness and witness.kind == "ordinary_water" then
							resume_before_run = run_index
							break
						end
					end
					for run_index = last_run + 1, #path.axis do
						local witness = path.lower_witness[run_index]
						if witness and witness.kind == "ordinary_water" then
							resume_after_run = run_index
							break
						end
					end
				end
				ford_approach_summary_evidence[#ford_approach_summary_evidence + 1] = {
					interface_id = ford.interface_id, path_id = path.id,
					ford_run = ford.ford_run, ford_pin_y = ford.ford_pin_y,
					capped_run_count = count, first_run = first_run, last_run = last_run,
					resume_before_run = resume_before_run,
					resume_after_run = resume_after_run}
			end
		end

		local function landing_member(landing, x, z)
			for segment_index = 1, #landing.source_segments do
				local segment = landing.source_segments[segment_index]
				local numerator, denominator = point_segment_ratio(x, z,
					segment.a, segment.b)
				if corridor_member_ratio(numerator, denominator, landing.width) then
					return true
				end
			end
			return false
		end

		local function landing_grade_at(x, z, owner, water_class)
			if water_class ~= "land" then return nil end
			for landing_index = 1, #landing_grades do
				local landing = landing_grades[landing_index]
				if owner == landing.zone_numeric_id and landing_member(landing, x, z) then
					return landing.surface_y, landing
				end
			end
			return nil
		end

		landing_evidence = {}
		for landing_index = 1, #landing_grades do
			local landing = landing_grades[landing_index]
			local min_x, max_x, min_z, max_z
			for point_index = 1, #landing.centreline do
				local point = landing.centreline[point_index]
				min_x = min_x and math.min(min_x, point.x) or point.x
				max_x = max_x and math.max(max_x, point.x) or point.x
				min_z = min_z and math.min(min_z, point.z) or point.z
				max_z = max_z and math.max(max_z, point.z) or point.z
			end
			local land_columns, graded_columns, water_unchanged, mainland_unchanged =
				0, 0, 0, 0
			local witness_x, witness_z, rows = nil, nil, {}
			for z = min_z - landing.width, max_z + landing.width do
				for x = min_x - landing.width, max_x + landing.width do
					if landing_member(landing, x, z) then
						local water_class, _, owner = classified_values(x, z)
						local result = "unchanged"
						if water_class == "land" and owner == landing.zone_numeric_id then
							land_columns, graded_columns = land_columns + 1,
								graded_columns + 1
							result = "landing_grade"
							if lexicographically_before(x, z, witness_x, witness_z) then
								witness_x, witness_z = x, z
							end
						elseif water_class ~= "land" then
							water_unchanged = water_unchanged + 1
						else mainland_unchanged = mainland_unchanged + 1 end
						rows[#rows + 1] = canonical.array({signed(x), signed(z),
							text(water_class), signed(owner or 0), text(result)})
					end
				end
			end
			landing_evidence[landing_index] = {id = landing.id,
				boat_path_id = landing.boat_path_id, route_id = landing.route_id,
				surface_y = landing.surface_y, corridor_land_columns = land_columns,
				graded_columns = graded_columns,
				water_columns_unchanged = water_unchanged,
				mainland_columns_unchanged = mainland_unchanged,
				witness_x = witness_x, witness_z = witness_z,
				classification_digest = counted_digest(rows)}
		end

		local operation_grid = {}
		for operation_index = 1, #water_operations do
			local operation = water_operations[operation_index]
			local min_x, max_x, min_z, max_z
			for run_index = operation.first_run, operation.last_run do
				local point = operation.path.axis[run_index]
				min_x = not min_x and point.x or math.min(min_x, point.x)
				max_x = not max_x and point.x or math.max(max_x, point.x)
				min_z = not min_z and point.z or math.min(min_z, point.z)
				max_z = not max_z and point.z or math.max(max_z, point.z)
			end
			operation.priority = operation.named_non_tunnel and 1 or 2
			add_bucket(operation_grid, operation,
				min_x - operation.path.surface_width,
				max_x + operation.path.surface_width,
				min_z - operation.path.surface_width,
				max_z + operation.path.surface_width)
		end

		operation_raw_member = function(operation, x, z)
			local segment, _, _, run_index = nearest_path_segment_at(x, z,
				"surface", operation.path)
			if not segment or run_index < operation.first_run or
					run_index > operation.last_run then return false end
			if operation.named_non_tunnel then
				local water_class, _, _, _, hydrology_id = classified_values(x, z)
				return water_class == "planned_water" and
					hydrology_id == operation.hydrology_id and
					in_polygon(x, z, operation.authorization_polygon)
			end
			return true
		end

		operation_member = function(operation, x, z)
			return operation_raw_member(operation, x, z)
		end

		local function functional_operation_at(x, z)
			local candidates = bucket_at(operation_grid, x, z)
			local best
			if not candidates then return nil end
			for index = 1, #candidates do
				local operation = candidates[index]
				if operation_member(operation, x, z) and
						(not best or operation.priority < best.priority or
						(operation.priority == best.priority and
							operation.interface_id < best.interface_id)) then
					best = operation
				end
			end
			return best
		end

		local function path_grade_at(x, z, incoming)
			local segment, numerator, denominator, run_index =
				nearest_path_segment_at(x, z, "surface", nil)
			if segment then
				local path = segment.path
				return path.y[run_index], path, run_index, true
			end
			segment, numerator, denominator, run_index =
				nearest_path_segment_at(x, z, "corridor", nil)
			if not segment then return nil end
			local path = segment.path
			local target = path.y[run_index]
			local qnumerator = 4 * numerator -
				path.surface_width * path.surface_width * denominator
			local qdenominator = (path.corridor_width * path.corridor_width -
				path.surface_width * path.surface_width) * denominator
			local fraction = clamp(deterministic.qfrom_ratio(qnumerator,
				qdenominator), 0, Q)
			local weight = Q - deterministic.smootherstep(fraction)
			return qlerp_integer(incoming, target, weight), path, run_index, false
		end

		local function operation_surface_at(operation, x, z)
			if operation.tunnel then return operation.surface_y end
			local _, _, _, run_index = nearest_path_segment_at(x, z, "surface",
				operation.path)
			if not run_index then fail("operation lost its projected route run") end
			return operation.path.y[run_index]
		end

		local function derived_water_surface_at(x, z, water_class, owner, bay_id,
				hydrology_id)
			if water_class ~= "planned_water" then return nil end
			local segment, _, _, run_index = nearest_path_segment_at(x, z,
				"surface", nil)
			if not segment then return nil end
			local path = segment.path
			if owner ~= path.owner_a and owner ~= path.owner_b then return nil end
			local datum = clearance_datum_at(x, z, water_class, bay_id, hydrology_id)
			if datum == nil then fail("derived water query has no clearance datum") end
			local ford = ford_cap_at(path, hydrology_id, run_index, datum + 1)
			if ford then return "ford", path.y[run_index], path,
				ford.interface_id end
			local kind = path.y[run_index] == datum + 1 and "causeway" or
				"bridge_deck"
			return kind, path.y[run_index], path, nil
		end

		local function composed_land_values_at(x, z, incoming, owner, water_class)
			local terrain_y = incoming
			local kind, surface_y, feature_id, interface_id
			local value, feature = fitting_grade_at(fitting_grids.selected, x, z,
				terrain_y, owner, water_class, false)
			if value ~= nil then
				terrain_y, kind, surface_y, feature_id = value, "land_grade", value,
					feature.id
			end
			value, feature = landing_grade_at(x, z, owner, water_class)
			if value ~= nil then
				terrain_y, kind, surface_y, feature_id = value, "land_grade", value,
					feature.id
			end
			local operation = functional_operation_at(x, z)
			local on_path_surface = false
			if operation and operation.kind == "tunnel_floor" then
				on_path_surface = true
				kind, surface_y, feature_id, interface_id = operation.kind,
					operation.surface_y, operation.feature_id, operation.interface_id
			else
				local path, projected_run
				value, path, projected_run, on_path_surface = path_grade_at(x, z,
					terrain_y)
				if value ~= nil then
					terrain_y, kind, surface_y, feature_id, interface_id = value,
						"land_grade", value, path.id, nil
				end
			end
			local weight, platform
			value, feature, weight = coastal_grade_at(x, z, terrain_y, owner,
				water_class)
			if value ~= nil and not (on_path_surface and weight > 0) then
				terrain_y, kind, surface_y, feature_id, interface_id = value,
					"land_grade", value, feature.id, nil
			end
			value, feature, platform, weight = fitting_grade_at(
				fitting_grids.capital, x, z,
				terrain_y, owner, water_class, false)
			if value ~= nil and not (on_path_surface and weight > 0) then
				terrain_y, kind, surface_y, feature_id, interface_id = value,
					"land_grade", value, feature.id, nil
			end
			value, feature, platform, weight = fitting_grade_at(fitting_grids.start,
				x, z,
				terrain_y, owner, water_class, false)
			if value ~= nil and not (on_path_surface and weight > 0) then
				terrain_y, kind, surface_y, feature_id, interface_id = value,
					"land_grade", value, feature.id, nil
			end
			return terrain_y, kind, surface_y, feature_id, interface_id
		end

		final_terrain_height_at = function(x, z)
			coordinate(x, "terrain query x") coordinate(z, "terrain query z")
			if x < bounds.min_x or x > bounds.max_x or z < bounds.min_z or
					z > bounds.max_z then return WATER_LEVEL - 24 end
			local water_class, _, owner, bay_id, hydrology_id =
				classified_values(x, z)
			local incoming = scalar_before_nonpath_grades(x, z, water_class,
				owner, bay_id, hydrology_id)
			local operation = functional_operation_at(x, z)
			if water_class == "planned_water" and operation then
				if operation.kind == "causeway" or operation.kind == "ford" then
					return operation_surface_at(operation, x, z)
				end
			end
			if water_class == "planned_water" then
				local kind, surface_y = derived_water_surface_at(x, z, water_class,
					owner, bay_id, hydrology_id)
				if kind == "causeway" or kind == "ford" then return surface_y end
				local value = fitting_grade_at(fitting_grids.selected, x, z, incoming,
					owner, water_class, false)
				if value ~= nil then return value end
				return incoming
			elseif water_class ~= "land" then return incoming end
			return composed_land_values_at(x, z, incoming, owner, water_class)
		end

		final_functional_values_at = function(x, z)
			coordinate(x, "functional query x") coordinate(z, "functional query z")
			if x < bounds.min_x or x > bounds.max_x or z < bounds.min_z or
					z > bounds.max_z then return nil, nil, nil, nil end
			local water_class, _, owner, bay_id, hydrology_id =
				classified_values(x, z)
			local incoming = scalar_before_nonpath_grades(x, z, water_class,
				owner, bay_id, hydrology_id)
			local operation = functional_operation_at(x, z)
			if water_class == "planned_water" and operation then return operation.kind,
				operation_surface_at(operation, x, z), operation.feature_id,
				operation.interface_id end
			if water_class == "planned_water" then
				local kind, surface_y, path, interface_id =
					derived_water_surface_at(x, z, water_class, owner, bay_id,
						hydrology_id)
				if kind then return kind, surface_y, path.id, interface_id end
			elseif water_class == "land" then
				local _, kind, surface_y, feature_id, interface_id =
					composed_land_values_at(x, z, incoming, owner, water_class)
				return kind, surface_y, feature_id, interface_id
			end
			local value, fitting = fitting_grade_at(fitting_grids.selected, x, z,
				incoming, owner, water_class, false)
			if value ~= nil then
				return water_class == "planned_water" and "anchor_platform" or
					"land_grade", value, fitting.id, nil
			end
			return nil, nil, nil, nil
		end

		final_water_surface_at = function(x, z)
			coordinate(x, "water query x") coordinate(z, "water query z")
			if x < bounds.min_x or x > bounds.max_x or z < bounds.min_z or
					z > bounds.max_z then return WATER_LEVEL end
			local water_class, _, _, bay_id, hydrology_id = classified_values(x, z)
			return pregrade_water_surface_at(x, z, water_class, bay_id,
				hydrology_id)
		end

		-- This is the sole final-axis scan. Normal construction fails on its first
		-- violation; the read-only diagnosis mode records the same composed query
		-- results without introducing a second height or path authority.
		local function final_axis_witness(path, run_index, from_point, from_y,
				from_feature_id, to_point, to_y, to_feature_id)
			local foreign_id, foreign_x, foreign_z
			for _, endpoint in ipairs({
				{feature_id = from_feature_id, x = from_point.x, z = from_point.z},
				{feature_id = to_feature_id, x = to_point.x, z = to_point.z},
			}) do
				if not path_by_id[endpoint.feature_id] then
					fail("final-axis feature identity is not a graded path at " ..
						path.id .. " run " .. tostring(run_index))
				end
				if endpoint.feature_id ~= path.id then
					if foreign_id and foreign_id ~= endpoint.feature_id then
						fail("final-axis violation has multiple foreign winners at " ..
							path.id .. " run " .. tostring(run_index))
					end
					if not foreign_id then
						foreign_id, foreign_x, foreign_z = endpoint.feature_id,
							endpoint.x, endpoint.z
					end
				end
			end
			if not foreign_id then
				fail("final-axis violation has no foreign winning path at " ..
					path.id .. " run " .. tostring(run_index))
			end
			local winner = path_by_id[foreign_id]
			local winner_run = path_surface_run_at(winner, foreign_x, foreign_z)
			if not winner_run then
				fail("final-axis winner is not attributable to its visible surface")
			end
			local winner_point = winner.axis[winner_run]
			if not winner_point then fail("final-axis winner run escaped its axis") end
			local pair_a, pair_b = path.id, foreign_id
			if pair_b < pair_a then pair_a, pair_b = pair_b, pair_a end
			return {
				losing_path_id = path.id,
				losing_run = run_index,
				from_x = from_point.x,
				from_z = from_point.z,
				from_y = from_y,
				to_x = to_point.x,
				to_z = to_point.z,
				to_y = to_y,
				absolute_step = math.abs(to_y - from_y),
				winner_path_id = foreign_id,
				winner_run = winner_run,
				winner_x = winner_point.x,
				winner_z = winner_point.z,
				pair_a = pair_a,
				pair_b = pair_b,
			}
		end

		local final_axis_sort_fields = {"losing_path_id", "losing_run",
			"from_x", "from_z", "to_x", "to_z", "winner_path_id",
			"winner_run", "winner_x", "winner_z"}
		local final_axis_record_fields = {"losing_path_id", "losing_run",
			"from_x", "from_z", "from_y", "to_x", "to_z", "to_y",
			"absolute_step", "winner_path_id", "winner_run", "winner_x",
			"winner_z", "pair_a", "pair_b"}
		local function ascii_record_key(record, fields)
			local values = {}
			for index = 1, #fields do
				values[index] = tostring(record[fields[index]])
			end
			return table.concat(values, "\t")
		end

		local function scan_final_axes(collect)
			local violations, record_keys, sort_keys = {}, {}, {}
			for path_index = 1, #paths do
				local path = paths[path_index]
				local previous_point, previous_y, previous_feature_id
				for run_index = 1, #path.axis do
					local point = path.axis[run_index]
					local _, surface_y, feature_id = final_functional_values_at(
						point.x, point.z)
					local y = surface_y or final_terrain_height_at(point.x, point.z)
					local absolute_step = previous_y and
						math.abs(y - previous_y) or 0
					if previous_y and absolute_step > 1 then
						if not collect then
							fail("final composed route step exceeds one at " .. path.id ..
								" run " .. tostring(run_index) .. " x/z " ..
								tostring(point.x) .. "/" .. tostring(point.z) .. " (" ..
								tostring(previous_y) .. " [" ..
								tostring(previous_feature_id) .. "] -> " .. tostring(y) ..
								" [" .. tostring(feature_id) .. "])")
						end
						local witness = final_axis_witness(path, run_index,
							previous_point, previous_y, previous_feature_id,
							point, y, feature_id)
						local record_key = ascii_record_key(witness,
							final_axis_record_fields)
						if record_keys[record_key] then
							fail("duplicate final-axis diagnosis row")
						end
						local sort_key = ascii_record_key(witness,
							final_axis_sort_fields)
						if sort_keys[sort_key] then
							fail("ambiguous final-axis diagnosis sort key")
						end
						record_keys[record_key], sort_keys[sort_key] = true, true
						witness._ascii_sort_key = sort_key
						violations[#violations + 1] = witness
					end
					previous_point, previous_y, previous_feature_id = point, y,
						feature_id
				end
			end
			table.sort(violations, function(a, b)
				return a._ascii_sort_key < b._ascii_sort_key
			end)
			for index = 1, #violations do
				violations[index]._ascii_sort_key = nil
			end
			return violations
		end

		local final_axis_violations = scan_final_axes(diagnose_final_axis)
		if diagnose_final_axis then return nil, final_axis_violations end
		local public_session = build_public_session()
		construction_complete = true
		return public_session, final_axis_violations
	end

	function module.new(full_seed_string)
		local session = construct(full_seed_string, false)
		return session
	end

	function module.diagnose_final_axis_violations(full_seed_string)
		local _, violations = construct(full_seed_string, true)
		return deep_copy(violations)
	end

	return module
end
