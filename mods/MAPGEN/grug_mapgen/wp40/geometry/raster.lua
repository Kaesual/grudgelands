-- Canonical one-node rasterization and the sole WP40 boundary displacement
-- path.  Calculation order is source-direction independent; output order is
-- restored only after scalar, clip, and component decisions are complete.

local function fail(message)
	error("WP40 boundary raster: " .. message, 0)
end

local function exact_dependencies(value)
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
		fail("canonical, deterministic, exact, or raw SHA dependency missing")
	end
end

return function(dependencies)
	exact_dependencies(dependencies)
	local canonical = dependencies.canonical
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	local Q = deterministic.Q
	local raster = {}

	local function point_less(a, b)
		return a.x < b.x or a.x == b.x and a.z < b.z
	end

	local function sequence_less(a, b)
		for index = 1, #a do
			if a[index].x ~= b[index].x then return a[index].x < b[index].x end
			if a[index].z ~= b[index].z then return a[index].z < b[index].z end
		end
		return false
	end

	local function reverse(values)
		local result = {}
		for index = #values, 1, -1 do result[#result + 1] = values[index] end
		return result
	end

	local function segment(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			fail("segment endpoints missing")
		end
		exact.integer(a.x, -2147483648, 2147483647, "segment x")
		exact.integer(a.z, -2147483648, 2147483647, "segment z")
		exact.integer(b.x, -2147483648, 2147483647, "segment x")
		exact.integer(b.z, -2147483648, 2147483647, "segment z")
		if a.x == b.x and a.z == b.z then fail("zero-length segment") end
		local low, high, authored_reverse = a, b, false
		if point_less(high, low) then
			low, high, authored_reverse = high, low, true
		end
		local dx, dz = high.x - low.x, high.z - low.z
		local absolute_x, absolute_z = math.abs(dx), math.abs(dz)
		local x_major = absolute_x >= absolute_z
		local major = x_major and absolute_x or absolute_z
		local minor = x_major and absolute_z or absolute_x
		local major_step = x_major and (dx < 0 and -1 or 1) or
			(dz < 0 and -1 or 1)
		local minor_step = x_major and (dz < 0 and -1 or 1) or
			(dx < 0 and -1 or 1)
		local x, z = low.x, low.z
		local error_value = 2 * minor - major
		local points = {}
		for step = 0, major do
			points[#points + 1] = {x = x, z = z}
			if step == major then break end
			if x_major then x = x + major_step else z = z + major_step end
			if error_value >= 0 then
				if x_major then z = z + minor_step else x = x + minor_step end
				error_value = error_value - 2 * major
			end
			error_value = error_value + 2 * minor
		end
		return authored_reverse and reverse(points) or points
	end

	local function same_sequence(a, b)
		if #a ~= #b then return false end
		for index = 1, #a do
			if a[index].x ~= b[index].x or a[index].z ~= b[index].z then return false end
		end
		return true
	end

	local function fixed_closure_segment(controls, count, closed, fixed_closure)
		if fixed_closure == nil then return nil end
		if not closed or type(fixed_closure) ~= "table" or
				getmetatable(fixed_closure) ~= nil or #fixed_closure < 2 then
			fail("fixed closure is not a closed-record plain station array")
		end
		for key, point in pairs(fixed_closure) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
					key > #fixed_closure then fail("fixed closure station array is not dense") end
			exact.point(point, "fixed closure station")
		end
		local reversed = reverse(fixed_closure)
		local matched
		for segment_index = 1, count do
			local following = segment_index == count and 1 or segment_index + 1
			local part = segment(controls[segment_index], controls[following])
			if same_sequence(part, fixed_closure) or same_sequence(part, reversed) then
				if matched then fail("fixed closure matches more than one source segment") end
				matched = segment_index
			end
		end
		if not matched then fail("fixed closure does not match one complete source segment") end
		return matched
	end

	local function authored_stations(controls, closed, fixed_closure)
		if type(controls) ~= "table" or getmetatable(controls) ~= nil then
			fail("controls are not a plain array")
		end
		local count = #controls
		if closed and count > 1 and controls[1].x == controls[count].x and
				controls[1].z == controls[count].z then count = count - 1 end
		if count < (closed and 3 or 2) then fail("too few controls") end
		local closure_segment = fixed_closure_segment(controls, count, closed,
			fixed_closure)
		local result = {}
		local segment_count = closed and count or count - 1
		for segment_index = 1, segment_count do
			local next_index = segment_index == count and 1 or segment_index + 1
			local part = segment(controls[segment_index], controls[next_index])
			for local_index = 1, #part do
				local point = part[local_index]
				local closure = segment_index == closure_segment
				if #result == 0 or result[#result].x ~= point.x or
						result[#result].z ~= point.z then
					result[#result + 1] = {x = point.x, z = point.z,
						source_segment = segment_index - 1,
						local_station = local_index - 1,
						local_last = #part - 1,
						authored_order = #result + 1,
						fixed_closure = closure or nil}
				elseif closure then
					result[#result].fixed_closure = true
				end
			end
		end
		if closed and #result > 1 and result[1].x == result[#result].x and
				result[1].z == result[#result].z then
			if result[#result].fixed_closure then result[1].fixed_closure = true end
			table.remove(result)
		end
		for index = 1, #result do result[index].authored_order = index end
		return result
	end

	local function canonical_open(points)
		local reversed = reverse(points)
		return sequence_less(reversed, points) and reversed or points
	end

	local function canonical_closed(points)
		if type(points) ~= "table" or #points < 3 then
			fail("closed station sequence is invalid")
		end
		local minimum_index = 1
		for index = 2, #points do
			if point_less(points[index], points[minimum_index]) then
				minimum_index = index
			elseif points[index].x == points[minimum_index].x and
					points[index].z == points[minimum_index].z then
				fail("closed station sequence repeats its lexicographic minimum at " ..
					minimum_index .. " and " .. index .. " near " ..
					points[minimum_index - 1].x .. ":" .. points[minimum_index - 1].z ..
					"/" .. points[index + 1].x .. ":" .. points[index + 1].z)
			end
		end
		local forward, backward = {}, {}
		for offset = 0, #points - 1 do
			forward[offset + 1] = points[(minimum_index - 1 + offset) % #points + 1]
			backward[offset + 1] = points[(minimum_index - 1 - offset) % #points + 1]
		end
		return sequence_less(backward, forward) and backward or forward
	end

	local function step_normal(dx, dz)
		if math.abs(dx) > 1 or math.abs(dz) > 1 or dx == 0 and dz == 0 then
			fail("normal step is not one nonzero eight-connected step")
		end
		local length_q = deterministic.isqrt((dx * dx + dz * dz) * Q * Q)
		return deterministic.qdiv(-dz * Q, length_q),
			deterministic.qdiv(dx * Q, length_q)
	end

	local function joint_normal(in_dx, in_dz, out_dx, out_dz)
		local in_x, in_z = step_normal(in_dx, in_dz)
		local out_x, out_z = step_normal(out_dx, out_dz)
		local sum_x, sum_z = in_x + out_x, in_z + out_z
		if sum_x == 0 and sum_z == 0 then fail("opposite joint normal") end
		local length_q = deterministic.isqrt(sum_x * sum_x + sum_z * sum_z)
		return deterministic.qdiv(sum_x, length_q),
			deterministic.qdiv(sum_z, length_q)
	end

	local function components(normal_x_q, normal_z_q, scalar_q)
		return deterministic.qround(deterministic.qmul(normal_x_q, scalar_q)),
			deterministic.qround(deterministic.qmul(normal_z_q, scalar_q))
	end

	local function no_jitter_damping(point, sources)
		local minimum = Q
		for index = 1, #sources do
			local source = sources[index]
			local distance = math.max(math.abs(point.x - source.x),
				math.abs(point.z - source.z))
			local damping
			if distance <= 96 then damping = 0
			elseif distance >= 192 then damping = Q
			else damping = deterministic.smootherstep(
				deterministic.qfrom_ratio(distance - 96, 96)) end
			if damping < minimum then minimum = damping end
			if minimum == 0 then return 0 end
		end
		return minimum
	end

	local function envelope_accept(definition, base, x, z)
		if definition.kind == "land_edge" then
			return math.abs(x - base.x) <= definition.max_displacement and
				math.abs(z - base.z) <= definition.max_displacement
		elseif definition.kind == "mainland_coast" then
			local frame = definition.envelope
			return x >= frame.min_x and x <= frame.max_x and
				z >= frame.min_z and z <= frame.max_z
		elseif definition.kind == "island_coast" then
			local envelope = definition.envelope
			return math.abs(x - envelope.center.x) <= envelope.radius_x and
				math.abs(z - envelope.center.z) <= envelope.radius_z
		elseif definition.kind == "fixed" then
			return x == base.x and z == base.z
		end
		fail("unknown displacement kind " .. tostring(definition.kind))
	end

	local function clip_scalar(definition, base, nx, nz, desired_q)
		local function accepted(scalar_q)
			local dx, dz = components(nx, nz, scalar_q)
			return envelope_accept(definition, base, base.x + dx, base.z + dz)
		end
		if accepted(desired_q) then return desired_q end
		local sign = desired_q < 0 and -1 or 1
		local magnitude = math.min(definition.max_displacement,
			math.floor(math.abs(desired_q) / Q))
		for nodes = magnitude, 0, -1 do
			local candidate = sign * nodes * Q
			if accepted(candidate) then return candidate end
		end
		fail("no local displacement magnitude is admissible")
	end

	local function final_raster(controls, closed)
		local result = {}
		local count = #controls
		local limit = closed and count or count - 1
		for index = 1, limit do
			local following = index == count and 1 or index + 1
			local current, next_point = controls[index], controls[following]
			if current.x ~= next_point.x or current.z ~= next_point.z then
				local part = segment(current, next_point)
				for station_index = 1, #part do
					local point = part[station_index]
					if #result == 0 or result[#result].x ~= point.x or
							result[#result].z ~= point.z then
						result[#result + 1] = point
					end
				end
			end
		end
		if #result == 0 and count > 0 then
			result[1] = {x = controls[1].x, z = controls[1].z}
		end
		if closed and #result > 1 and result[1].x == result[#result].x and
				result[1].z == result[#result].z then table.remove(result) end
		return result
	end

	local function land_envelope_accept(definition, base_stations, point)
		for index = 1, #base_stations do
			if math.abs(point.x - base_stations[index].x) <=
					definition.max_displacement and
					math.abs(point.z - base_stations[index].z) <=
					definition.max_displacement then return true end
		end
		return false
	end

	local function validate_final(definition, base_stations, final)
		if #final < (definition.closed and 3 or 2) then
			fail(definition.id .. " final raster has too few stations")
		end
		local station_seen, diagonal_cells = {}, {}
		for index = 1, #final do
			local point = final[index]
			local station_key = point.x .. ":" .. point.z
			if station_seen[station_key] then
				fail(definition.id .. " final raster repeats station " .. station_key ..
					" at " .. station_seen[station_key] .. "/" .. index)
			end
			station_seen[station_key] = index
			local inside
			if definition.kind == "land_edge" or definition.kind == "fixed" then
				inside = land_envelope_accept(definition, base_stations, point)
			else
				inside = envelope_accept(definition, point, point.x, point.z)
			end
			if not inside then fail(definition.id .. " final raster exits envelope") end
		end
		local edge_count = definition.closed and #final or #final - 1
		for index = 1, edge_count do
			local following = index == #final and 1 or index + 1
			local a, b = final[index], final[following]
			local dx, dz = b.x - a.x, b.z - a.z
			if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
				fail(definition.id .. " final raster is not eight-connected")
			end
			if math.abs(dx) == 1 and math.abs(dz) == 1 then
				local cell_key = math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z)
				local slope = dx == dz and 1 or -1
				if diagonal_cells[cell_key] and diagonal_cells[cell_key] ~= slope then
					fail(definition.id .. " final raster has an X-cross in cell " ..
						cell_key)
				end
				diagonal_cells[cell_key] = slope
			end
		end
		if definition.closed then
			local polygon = {}
			for index = 1, #final do polygon[index] = final[index] end
			polygon[#polygon + 1] = final[1]
			local area = exact.signed_area2(polygon)
			if definition.orientation == "counterclockwise" then
				if area <= 0 then fail(definition.id .. " final orientation is not CCW") end
			elseif definition.orientation == "clockwise" then
				if area >= 0 then fail(definition.id .. " final orientation is not clockwise") end
			else
				fail(definition.id .. " closed orientation declaration is invalid")
			end
		end
	end

	local function topology_ceiling(maximum, attempt)
		exact.integer(maximum, 0, 2147483647, "topology ceiling maximum")
		if type(attempt) ~= "function" then fail("topology attempt is not callable") end
		local zero_diagnostic
		for ceiling = maximum, 0, -1 do
			local valid, result = attempt(ceiling)
			if type(valid) ~= "boolean" then
				fail("topology attempt did not return a boolean")
			end
			if valid then return ceiling, result end
			if ceiling == 0 then zero_diagnostic = result end
		end
		fail("C=0 base topology is invalid: " .. tostring(zero_diagnostic))
	end

	local function displace(definition, seed, no_jitter_sources)
		if type(definition) ~= "table" or getmetatable(definition) ~= nil or
				type(definition.id) ~= "string" or
				type(definition.control) ~= "table" or
				type(definition.closed) ~= "boolean" or
				type(definition.noise_domain) ~= "string" or
				type(definition.max_displacement) ~= "number" then
			fail("displacement definition is invalid")
		end
		if definition.closed and definition.orientation ~= "clockwise" and
				definition.orientation ~= "counterclockwise" then
			fail("closed orientation declaration is invalid")
		elseif not definition.closed and definition.orientation ~= nil then
			fail("open displacement has an orientation declaration")
		end
		exact.integer(definition.max_displacement, 0, 2147483647,
			"maximum displacement")
		deterministic.validate_seed(seed)
		if type(no_jitter_sources) ~= "table" or
				getmetatable(no_jitter_sources) ~= nil then
			fail("no-jitter sources are not a plain array")
		end
		local authored = authored_stations(definition.control, definition.closed,
			definition.fixed_closure)
		local calculation = definition.closed and canonical_closed(authored) or
			canonical_open(authored)
		local period = definition.kind == "land_edge" and 384 or
			(definition.kind == "mainland_coast" and 512 or
			(definition.kind == "island_coast" and 256 or 0))
		local noise_definition
		if definition.max_displacement ~= 0 then
			if period == 0 then fail("moving fixed boundary") end
			noise_definition = {schema = "grug_wp40_geometry_source_v1", seed = seed,
				domain = definition.noise_domain, feature = "", octaves = {
					{period = period, amplitude_numerator = 2,
						amplitude_denominator = 3},
					{period = period * 2, amplitude_numerator = 1,
						amplitude_denominator = 3},
				}}
		end
		local local_rows = {}
		for index = 1, #calculation do
			local point = calculation[index]
			local previous, following
			if index == 1 then
				if definition.closed then previous = #calculation end
			else
				previous = index - 1
			end
			if index == #calculation then
				if definition.closed then following = 1 end
			else
				following = index + 1
			end
			local nx, nz
			if previous and following then
				nx, nz = joint_normal(point.x - calculation[previous].x,
					point.z - calculation[previous].z,
					calculation[following].x - point.x,
					calculation[following].z - point.z)
			elseif following then
				nx, nz = step_normal(calculation[following].x - point.x,
					calculation[following].z - point.z)
			else
				nx, nz = step_normal(point.x - calculation[previous].x,
					point.z - calculation[previous].z)
			end
			local noise_q = 0
			if noise_definition then
				noise_q = deterministic.clamp(deterministic.value_noise_2d(
					canonical, dependencies.raw_sha256, noise_definition,
					point.x, point.z), -Q, Q)
			end
			local raw_q = deterministic.qmul(noise_q,
				definition.max_displacement * Q)
			local station_distance = math.min(point.local_station,
				point.local_last - point.local_station)
			local taper_q = deterministic.smootherstep(
				deterministic.qfrom_ratio(math.min(station_distance, 96), 96))
			local damping_q = deterministic.qmul(taper_q,
				no_jitter_damping(point, no_jitter_sources))
			local desired_q = deterministic.qmul(raw_q, damping_q)
			local scalar_q = point.fixed_closure and 0 or
				clip_scalar(definition, point, nx, nz, desired_q)
			local_rows[index] = {x = point.x, z = point.z,
				source_segment = point.source_segment,
				local_station = point.local_station, authored_order = point.authored_order,
				local_scalar_q = scalar_q, normal_x_q = nx, normal_z_q = nz}
		end
		local ceiling, accepted = topology_ceiling(definition.max_displacement,
			function(candidate_ceiling)
				local shifted_by_authored, scalar_rows = {}, {}
				local bound_q = candidate_ceiling * Q
				for index = 1, #local_rows do
					local row = local_rows[index]
					local scalar_q = deterministic.clamp(row.local_scalar_q,
						-bound_q, bound_q)
					local dx, dz = components(row.normal_x_q, row.normal_z_q, scalar_q)
					shifted_by_authored[row.authored_order] =
						{x = row.x + dx, z = row.z + dz}
					if not envelope_accept(definition, row,
							row.x + dx, row.z + dz) then
						return false, "shifted control exits local envelope"
					end
					scalar_rows[index] = {x = row.x, z = row.z,
						source_segment = row.source_segment,
						local_station = row.local_station, scalar_q = scalar_q,
						normal_x_q = row.normal_x_q, normal_z_q = row.normal_z_q,
						dx = dx, dz = dz}
				end
				local final = final_raster(shifted_by_authored, definition.closed)
				local valid, diagnostic = pcall(validate_final, definition, authored, final)
				if not valid then return false, diagnostic end
				return true, {shifted_controls = shifted_by_authored,
					stations = final, scalar_samples = scalar_rows}
			end)
		return {id = definition.id, closed = definition.closed,
			base_stations = authored, shifted_controls = accepted.shifted_controls,
			stations = accepted.stations, scalar_samples = accepted.scalar_samples,
			topology_ceiling_nodes = ceiling}
	end

	raster.segment = segment
	raster.authored_stations = authored_stations
	raster.canonical_open = canonical_open
	raster.canonical_closed = canonical_closed
	raster.step_normal = step_normal
	raster.joint_normal = joint_normal
	raster.components = components
	raster.final_raster = final_raster
	raster.validate_final = validate_final
	raster.topology_ceiling = topology_ceiling
	raster.displace = displace
	return raster
end
