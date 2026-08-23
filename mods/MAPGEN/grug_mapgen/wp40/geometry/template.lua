-- Payload-free WP40 terrain-template primitives and ordered composition.
-- Local x/z inputs are signed integer world-column offsets from the anchor.

local function fail(message)
	error("WP40 template: " .. message, 0)
end

local function dependency_contract(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {deterministic = true, exact = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	if type(value.deterministic) ~= "table" or
			type(value.deterministic.qdiv) ~= "function" or
			type(value.deterministic.qlerp) ~= "function" or
			type(value.deterministic.smootherstep) ~= "function" or
			type(value.exact) ~= "table" or
			type(value.exact.integer) ~= "function" or
			type(value.exact.safe_signed_product) ~= "function" then
		fail("deterministic or exact dependency is missing")
	end
end

return function(dependencies)
	dependency_contract(dependencies)
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	local Q = deterministic.Q
	local MAX_SAFE = deterministic.MAX_SAFE
	local template = {}

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

	local function exact_fields(value, names, label)
		plain_table(value, label)
		local count = 0
		for key in pairs(value) do
			if type(key) ~= "string" or not names[key] then
				fail(label .. " has unknown field " .. tostring(key))
			end
			count = count + 1
		end
		for name in pairs(names) do
			if value[name] == nil then fail(label .. " is missing field " .. name) end
		end
		if count == 0 and next(names) ~= nil then fail(label .. " is empty") end
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

	local function local_q(local_x, local_z)
		integer(local_x, -2147483648, 2147483647, "local x")
		integer(local_z, -2147483648, 2147483647, "local z")
		return qnodes(local_x, "local x Q16"), qnodes(local_z, "local z Q16")
	end

	local function width_bounds(width, label)
		integer(width, 1, 2147483647, label)
		return -math.floor(width / 2), math.ceil(width / 2)
	end

	local function centered_contains(width, local_x, local_z)
		local minimum, maximum = width_bounds(width, "centred width")
		integer(local_x, -2147483648, 2147483647, "local x")
		integer(local_z, -2147483648, 2147483647, "local z")
		return local_x >= minimum and local_x < maximum and
			local_z >= minimum and local_z < maximum
	end

	local function footprint_signed_distance_q(width, local_x, local_z)
		local minimum, maximum = width_bounds(width, "footprint width")
		local x_q, z_q = local_q(local_x, local_z)
		local minimum_q = qnodes(minimum, "footprint minimum")
		local maximum_q = qnodes(maximum, "footprint maximum")
		return math.max(minimum_q - x_q, x_q - maximum_q,
			minimum_q - z_q, z_q - maximum_q)
	end

	local function radius_q(local_x, local_z)
		local x_q, z_q = local_q(local_x, local_z)
		local squared = exact.safe_sum(exact.safe_square(x_q, "radial x"),
			exact.safe_square(z_q, "radial z"), "radial sum")
		return deterministic.isqrt(squared)
	end

	local PARAMETER_NAMES = {
		flat = {height_offset = true},
		tilt = {axis_x = true, axis_z = true, rise = true, run = true},
		terrace = {step_height = true, step_run = true, rings = true},
		plateau = {inner_radius = true, shoulder_width = true},
		basin = {inner_radius = true, depth = true, rim_width = true},
		rim = {inner_radius = true, peak_radius = true, outer_radius = true,
			height = true},
	}
	local DEFERRED = {causeway = true, cross_section = true,
		housing_smoothing = true}

	local function primitive_result(offset_q, weight_q, signed_distance_q, inside)
		return {offset_q = offset_q, weight_q = weight_q,
			signed_distance_q = signed_distance_q, inside = inside}
	end

	local function evaluate_primitive(primitive_id, parameters, local_x, local_z,
			fitting_width)
		if DEFERRED[primitive_id] then
			fail("provider_unavailable:" .. primitive_id)
		end
		local parameter_names = PARAMETER_NAMES[primitive_id]
		if not parameter_names then fail("unknown primitive " .. tostring(primitive_id)) end
		exact_fields(parameters, parameter_names, primitive_id .. " parameters")
		local inside, signed_distance_q, offset_q, weight_q
		if primitive_id == "flat" or primitive_id == "tilt" or
				primitive_id == "terrace" then
			integer(fitting_width, 1, 2147483647, "fitting width")
			inside = centered_contains(fitting_width, local_x, local_z)
			signed_distance_q = footprint_signed_distance_q(fitting_width,
				local_x, local_z)
			weight_q = inside and Q or 0
		end
		if primitive_id == "flat" then
			offset_q = qnodes(parameters.height_offset, "flat height offset")
		elseif primitive_id == "tilt" then
			local axis_x = integer(parameters.axis_x, -1, 1, "tilt axis x")
			local axis_z = integer(parameters.axis_z, -1, 1, "tilt axis z")
			if math.abs(axis_x) + math.abs(axis_z) ~= 1 then
				fail("tilt axis is not a unit Manhattan axis")
			end
			local rise = integer(parameters.rise, -MAX_SAFE, MAX_SAFE, "tilt rise")
			local run = integer(parameters.run, 1, MAX_SAFE, "tilt run")
			local dot = safe_add(exact.safe_signed_product(axis_x, local_x,
				"tilt dot"), exact.safe_signed_product(axis_z, local_z,
				"tilt dot"), "tilt dot")
			offset_q = deterministic.qdiv(exact.safe_signed_product(dot, rise,
				"tilt rise"), run)
		elseif primitive_id == "terrace" then
			local step_height = integer(parameters.step_height, 0, MAX_SAFE,
				"terrace step height")
			local step_run = integer(parameters.step_run, 1, MAX_SAFE,
				"terrace step run")
			local rings = integer(parameters.rings, 1, 4294967295,
				"terrace rings")
			local ring = math.min(rings - 1,
				math.floor(radius_q(local_x, local_z) / qnodes(step_run,
					"terrace step run Q16")))
			offset_q = qnodes(exact.safe_signed_product(ring, step_height,
				"terrace offset"), "terrace offset Q16")
		else
			local radius = radius_q(local_x, local_z)
			if primitive_id == "plateau" then
				local inner = integer(parameters.inner_radius, 0, MAX_SAFE,
					"plateau inner radius")
				local shoulder = integer(parameters.shoulder_width, 1, MAX_SAFE,
					"plateau shoulder width")
				local inner_q = qnodes(inner, "plateau inner Q16")
				local outer_q = safe_add(inner_q, qnodes(shoulder,
					"plateau shoulder Q16"), "plateau outer Q16")
				signed_distance_q = radius - outer_q
				inside = radius <= outer_q
				offset_q = 0
				if radius <= inner_q then weight_q = Q
				elseif radius >= outer_q then weight_q = 0
				else weight_q = Q - deterministic.smootherstep(
					deterministic.qdiv(radius - inner_q, outer_q - inner_q)) end
			elseif primitive_id == "basin" then
				local inner = integer(parameters.inner_radius, 0, MAX_SAFE,
					"basin inner radius")
				local depth = integer(parameters.depth, 0, MAX_SAFE, "basin depth")
				local rim_width = integer(parameters.rim_width, 1, MAX_SAFE,
					"basin rim width")
				local inner_q = qnodes(inner, "basin inner Q16")
				local outer_q = safe_add(inner_q, qnodes(rim_width,
					"basin rim Q16"), "basin outer Q16")
				local depth_q = qnodes(depth, "basin depth Q16")
				signed_distance_q = radius - outer_q
				inside = radius <= outer_q
				weight_q = inside and Q or 0
				if radius <= inner_q then offset_q = -depth_q
				elseif radius >= outer_q then offset_q = 0
				else offset_q = deterministic.qlerp(-depth_q, 0,
					deterministic.qdiv(radius - inner_q, outer_q - inner_q)) end
			elseif primitive_id == "rim" then
				local inner = integer(parameters.inner_radius, 0, MAX_SAFE,
					"rim inner radius")
				local peak = integer(parameters.peak_radius, 1, MAX_SAFE,
					"rim peak radius")
				local outer = integer(parameters.outer_radius, 1, MAX_SAFE,
					"rim outer radius")
				local height = integer(parameters.height, 0, MAX_SAFE, "rim height")
				if not (inner < peak and peak < outer) then
					fail("rim radii are not strictly increasing")
				end
				local inner_q, peak_q, outer_q = qnodes(inner, "rim inner Q16"),
					qnodes(peak, "rim peak Q16"), qnodes(outer, "rim outer Q16")
				local height_q = qnodes(height, "rim height Q16")
				signed_distance_q = radius - outer_q
				inside = radius <= outer_q
				weight_q = inside and Q or 0
				if radius <= inner_q or radius >= outer_q then offset_q = 0
				elseif radius <= peak_q then
					offset_q = deterministic.qmul(height_q,
						deterministic.smootherstep(deterministic.qdiv(
							radius - inner_q, peak_q - inner_q)))
				else
					offset_q = deterministic.qmul(height_q, Q -
						deterministic.smootherstep(deterministic.qdiv(
							radius - peak_q, outer_q - peak_q)))
				end
			end
		end
		return primitive_result(offset_q, weight_q, signed_distance_q, inside)
	end

	local function feature_blend_weight(fitting_width, blend_width, local_x,
			local_z)
		integer(fitting_width, 1, 2147483647, "fitting width")
		integer(blend_width, fitting_width, 2147483647, "blend width")
		if centered_contains(fitting_width, local_x, local_z) then return Q end
		local span_q = deterministic.qfrom_ratio(blend_width - fitting_width, 2)
		if span_q == 0 then return 0 end
		local distance_q = math.max(0, footprint_signed_distance_q(fitting_width,
			local_x, local_z))
		if distance_q >= span_q then return 0 end
		return Q - deterministic.smootherstep(deterministic.qdiv(distance_q,
			span_q))
	end

	local function blend_to_natural(natural_y, base_y, offset_q, weight_q)
		local natural_q = qnodes(natural_y, "natural height Q16")
		local shaped_q = safe_add(qnodes(base_y, "base height Q16"),
			integer(offset_q, -MAX_SAFE, MAX_SAFE, "template offset Q16"),
			"shaped height Q16")
		integer(weight_q, 0, Q, "feature blend weight Q16")
		return deterministic.qround(deterministic.qlerp(natural_q, shaped_q,
			weight_q))
	end

	local function copy_parameters(parameters, names, label)
		exact_fields(parameters, names, label)
		local result = {}
		for name in pairs(names) do
			result[name] = integer(parameters[name], -MAX_SAFE, MAX_SAFE,
				label .. "." .. name)
		end
		return result
	end

	function template.new(source)
		plain_table(source, "source")
		local primitive_rows = source.template_primitives
		local composition_rows = source.template_compositions
		local template_rows = source.templates
		dense_count(primitive_rows, "source.template_primitives")
		dense_count(composition_rows, "source.template_compositions")
		dense_count(template_rows, "source.templates")
		local known_primitives = {}
		for index = 1, #primitive_rows do
			local id = primitive_rows[index].id
			if type(id) ~= "string" or id == "" or known_primitives[id] then
				fail("source primitive IDs are invalid")
			end
			if not PARAMETER_NAMES[id] and not DEFERRED[id] then
				fail("source contains unknown primitive " .. id)
			end
			known_primitives[id] = true
		end
		local compositions = {}
		for index = 1, #composition_rows do
			local row = plain_table(composition_rows[index], "composition")
			if type(row.id) ~= "string" or row.id == "" or compositions[row.id] or
					row.version ~= 1 then fail("source composition identity is invalid") end
			dense_count(row.operations, row.id .. ".operations")
			if #row.operations == 0 then fail(row.id .. " has no operations") end
			local operations = {}
			for operation_index = 1, #row.operations do
				local operation = plain_table(row.operations[operation_index],
					row.id .. " operation")
				if operation.op ~= "apply" and operation.op ~= "overlay" and
						operation.op ~= "subtract" and operation.op ~= "blend" then
					fail(row.id .. " has an unknown composition operator")
				end
				if operation_index == 1 and operation.op ~= "apply" then
					fail(row.id .. " first operation is not apply")
				end
				local id = operation.primitive_id
				if not known_primitives[id] then fail(row.id .. " references unknown primitive") end
				local names = PARAMETER_NAMES[id]
				local parameters = {}
				if names then parameters = copy_parameters(operation.parameters, names,
					row.id .. " parameters")
				else
					plain_table(operation.parameters, row.id .. " deferred parameters")
					for key, value in pairs(operation.parameters) do
						if type(key) ~= "string" then fail("deferred parameter name is invalid") end
						parameters[key] = integer(value, -MAX_SAFE, MAX_SAFE,
							row.id .. "." .. key)
					end
				end
				operations[operation_index] = {op = operation.op,
					primitive_id = id, parameters = parameters}
			end
			compositions[row.id] = {id = row.id, operations = operations}
		end
		local widths = {}
		for index = 1, #template_rows do
			local row = template_rows[index]
			if type(row.composition_id) ~= "string" or
					not compositions[row.composition_id] or widths[row.composition_id] then
				fail("source template composition mapping is invalid")
			end
			widths[row.composition_id] = {
				fitting = integer(row.fitting_width, 1, 2147483647,
					"template fitting width"),
				blend = integer(row.blend_width, row.fitting_width, 2147483647,
					"template blend width"),
			}
		end

		local session = {}
		function session.evaluate_primitive(...)
			return evaluate_primitive(...)
		end
		function session.evaluate(composition_id, local_x, local_z, fitting_width)
			local composition = compositions[composition_id]
			if not composition then fail("unknown composition " .. tostring(composition_id)) end
			for index = 1, #composition.operations do
				local primitive_id = composition.operations[index].primitive_id
				if DEFERRED[primitive_id] then
					fail("provider_unavailable:" .. primitive_id)
				end
			end
			local width = fitting_width or
				(widths[composition_id] and widths[composition_id].fitting)
			if width == nil then fail("composition fitting width is unavailable") end
			local accumulator = 0
			for index = 1, #composition.operations do
				local operation = composition.operations[index]
				local result = evaluate_primitive(operation.primitive_id,
					operation.parameters, local_x, local_z, width)
				if result.inside then
					if operation.op == "apply" then accumulator = result.offset_q
					elseif operation.op == "overlay" then
						accumulator = math.max(accumulator, result.offset_q)
					elseif operation.op == "subtract" then
						accumulator = safe_add(accumulator, -math.abs(result.offset_q),
							"template subtraction")
					else
						accumulator = deterministic.qlerp(accumulator, result.offset_q,
							result.weight_q)
					end
				end
			end
			return accumulator
		end
		function session.widths(composition_id)
			local row = widths[composition_id]
			if not row then return nil end
			return {fitting_width = row.fitting, blend_width = row.blend}
		end
		return session
	end

	template.centered_contains = centered_contains
	template.footprint_signed_distance_q = footprint_signed_distance_q
	template.radius_q = radius_q
	template.feature_blend_weight = feature_blend_weight
	template.blend_to_natural = blend_to_natural
	return template
end
