-- Exact integer and rational geometry used by the private WP40 compiler.
-- This file is engine-free.  It owns predicates only; compiled records never
-- retain a function, metatable, alias, or mutable source table.

local MAX_SAFE = 9007199254740991

local function fail(message)
	error("WP40 exact geometry: " .. message, 0)
end

local function exact_dependencies(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {deterministic = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	if type(value.deterministic) ~= "table" or
			type(value.deterministic.isqrt) ~= "function" or
			type(value.deterministic.safe_product) ~= "function" then
		fail("T1 deterministic dependency missing")
	end
end

return function(dependencies)
	exact_dependencies(dependencies)
	local deterministic = dependencies.deterministic
	local exact = {}

	local function integer(value, minimum, maximum, label)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or value < minimum or
				value > maximum then
			fail((label or "value") .. " is outside its exact integer range")
		end
		return value
	end

	local function safe_nonnegative_product(a, b, label)
		integer(a, 0, MAX_SAFE, label)
		integer(b, 0, MAX_SAFE, label)
		return deterministic.safe_product(a, b, label or "product")
	end

	local function safe_product(a, b, label)
		integer(a, -MAX_SAFE, MAX_SAFE, label)
		integer(b, -MAX_SAFE, MAX_SAFE, label)
		return deterministic.safe_product(a, b, label or "product")
	end

	local function safe_square(value, label)
		integer(value, -MAX_SAFE, MAX_SAFE, label)
		return safe_nonnegative_product(math.abs(value), math.abs(value), label)
	end

	local function safe_sum(a, b, label)
		integer(a, -MAX_SAFE, MAX_SAFE, label)
		integer(b, -MAX_SAFE, MAX_SAFE, label)
		local value = a + b
		return integer(value, -MAX_SAFE, MAX_SAFE, label or "sum")
	end

	local function safe_difference(a, b, label)
		return safe_sum(a, -integer(b, -MAX_SAFE, MAX_SAFE, label), label)
	end

	local function point(value, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail((label or "point") .. " is not a plain table")
		end
		integer(value.x, -2147483648, 2147483647, (label or "point") .. " x")
		integer(value.z, -2147483648, 2147483647, (label or "point") .. " z")
		return value
	end

	local function dense_count(value, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail((label or "array") .. " is not a plain array")
		end
		local count = #value
		for key in pairs(value) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail((label or "array") .. " is not dense")
			end
		end
		return count
	end

	local function validate_closed_polygon(polygon)
		local count = dense_count(polygon, "closed polygon")
		if count < 4 then fail("closed polygon is invalid") end
		for index = 1, count do point(polygon[index], "closed polygon point") end
		if polygon[1].x ~= polygon[count].x or
				polygon[1].z ~= polygon[count].z then
			fail("closed polygon has no repeated terminal")
		end
		for index = 1, count - 1 do
			if polygon[index].x == polygon[index + 1].x and
					polygon[index].z == polygon[index + 1].z then
				fail("closed polygon has a zero-length segment")
			end
		end
		return count
	end

	local function vector(a, b, label)
		point(a, label)
		point(b, label)
		return safe_difference(b.x, a.x, label),
			safe_difference(b.z, a.z, label)
	end

	local function dot(ax, az, bx, bz, label)
		return safe_sum(safe_product(ax, bx, label),
			safe_product(az, bz, label), label)
	end

	local function cross(ax, az, bx, bz, label)
		return safe_difference(safe_product(ax, bz, label),
			safe_product(az, bx, label), label)
	end

	local function gcd(a, b)
		integer(a, 0, MAX_SAFE, "gcd operand")
		integer(b, 0, MAX_SAFE, "gcd operand")
		while b ~= 0 do a, b = b, a % b end
		return a
	end

	local function reduce(numerator, denominator)
		integer(numerator, 0, MAX_SAFE, "rational numerator")
		integer(denominator, 1, MAX_SAFE, "rational denominator")
		if numerator == 0 then return 0, 1 end
		local divisor = gcd(numerator, denominator)
		return numerator / divisor, denominator / divisor
	end

	local function rational_compare(an, ad, bn, bd)
		an, ad = reduce(an, ad)
		bn, bd = reduce(bn, bd)
		local denominator_gcd = gcd(ad, bd)
		local left = safe_nonnegative_product(an, bd / denominator_gcd,
			"rational comparison")
		local right = safe_nonnegative_product(bn, ad / denominator_gcd,
			"rational comparison")
		if left < right then return -1 end
		if left > right then return 1 end
		return 0
	end

	local function ceil_isqrt(value)
		integer(value, 0, MAX_SAFE, "ceil isqrt value")
		local root = deterministic.isqrt(value)
		return root * root == value and root or root + 1
	end

	local function point_on_segment(x, z, a, b)
		integer(x, -2147483648, 2147483647, "segment point x")
		integer(z, -2147483648, 2147483647, "segment point z")
		local dx, dz = vector(a, b, "segment vector")
		local px = safe_difference(x, a.x, "segment point vector")
		local pz = safe_difference(z, a.z, "segment point vector")
		return cross(dx, dz, px, pz, "segment determinant") == 0 and
			x >= math.min(a.x, b.x) and x <= math.max(a.x, b.x) and
			z >= math.min(a.z, b.z) and z <= math.max(a.z, b.z)
	end

	-- Returns -1 outside, 0 on an exact segment, and 1 in the strict interior.
	-- A segment candidate list is an acceleration only: this one checked
	-- predicate remains the sole winding/equality authority.
	local function polygon_class_candidates_checked(x, z, polygon, candidates)
		integer(x, -2147483648, 2147483647, "polygon x")
		integer(z, -2147483648, 2147483647, "polygon z")
		local winding = 0
		local count = candidates and #candidates or #polygon - 1
		for candidate_index = 1, count do
			local index = candidates and candidates[candidate_index] or candidate_index
			integer(index, 1, #polygon - 1, "polygon segment candidate")
			local a, b = polygon[index], polygon[index + 1]
			local dx, dz = vector(a, b, "polygon edge")
			local px = safe_difference(x, a.x, "polygon query")
			local pz = safe_difference(z, a.z, "polygon query")
			local side = cross(dx, dz, px, pz, "polygon determinant")
			if side == 0 and point_on_segment(x, z, a, b) then return 0 end
			if a.z <= z then
				if b.z > z and side > 0 then winding = winding + 1 end
			elseif b.z <= z and side < 0 then
				winding = winding - 1
			end
		end
		return winding == 0 and -1 or 1
	end

	local function polygon_class_candidates(x, z, polygon, candidates)
		validate_closed_polygon(polygon)
		if candidates ~= nil then dense_count(candidates, "polygon candidates") end
		return polygon_class_candidates_checked(x, z, polygon, candidates)
	end

	local function polygon_class(x, z, polygon)
		return polygon_class_candidates(x, z, polygon, nil)
	end

	local function polygon_index(polygon)
		validate_closed_polygon(polygon)
		local rows = {}
		local min_x, max_x, min_z, max_z
		for index = 1, #polygon - 1 do
			local a, b = point(polygon[index], "polygon index point"),
				point(polygon[index + 1], "polygon index point")
			min_x = min_x and math.min(min_x, a.x) or a.x
			max_x = max_x and math.max(max_x, a.x) or a.x
			min_z = min_z and math.min(min_z, a.z) or a.z
			max_z = max_z and math.max(max_z, a.z) or a.z
			for z = math.min(a.z, b.z), math.max(a.z, b.z) do
				local row = rows[z] or {}
				rows[z] = row row[#row + 1] = index
			end
		end
		return {polygon = polygon, rows = rows, min_x = min_x, max_x = max_x,
			min_z = min_z, max_z = max_z}
	end

	local function indexed_polygon_class(index, x, z)
		if type(index) ~= "table" or getmetatable(index) ~= nil or
				type(index.polygon) ~= "table" or type(index.rows) ~= "table" then
			fail("polygon index is invalid")
		end
		if x < index.min_x or x > index.max_x or z < index.min_z or
				z > index.max_z then return -1 end
		local candidates = index.rows[z]
		if not candidates then return -1 end
		return polygon_class_candidates_checked(x, z, index.polygon, candidates)
	end

	local function signed_area2(polygon)
		validate_closed_polygon(polygon)
		local area = 0
		for index = 1, #polygon - 1 do
			local a, b = polygon[index], polygon[index + 1]
			point(a, "polygon area point")
			point(b, "polygon area point")
			area = safe_sum(area, cross(a.x, a.z, b.x, b.z,
				"polygon area determinant"), "polygon area")
		end
		return area
	end

	local function orientation(a, b, c)
		local abx, abz = vector(a, b, "orientation edge")
		local acx, acz = vector(a, c, "orientation query")
		local value = cross(abx, abz, acx, acz, "orientation determinant")
		if value < 0 then return -1 end
		if value > 0 then return 1 end
		return 0
	end

	local function segments_intersect(a, b, c, d)
		local ab_c, ab_d = orientation(a, b, c), orientation(a, b, d)
		local cd_a, cd_b = orientation(c, d, a), orientation(c, d, b)
		if ab_c == 0 and point_on_segment(c.x, c.z, a, b) then return true end
		if ab_d == 0 and point_on_segment(d.x, d.z, a, b) then return true end
		if cd_a == 0 and point_on_segment(a.x, a.z, c, d) then return true end
		if cd_b == 0 and point_on_segment(b.x, b.z, c, d) then return true end
		return ab_c ~= ab_d and cd_a ~= cd_b
	end

	local function polygon_simple(polygon)
		validate_closed_polygon(polygon)
		local last = #polygon - 1
		for first = 1, last do
			for second = first + 1, last do
				local adjacent = second == first + 1 or
					(first == 1 and second == last)
				if not adjacent and segments_intersect(polygon[first],
						polygon[first + 1], polygon[second], polygon[second + 1]) then
					return false
				end
			end
		end
		return true
	end

	local function segment_distance(x, z, a, b)
		integer(x, -2147483648, 2147483647, "distance x")
		integer(z, -2147483648, 2147483647, "distance z")
		local dx, dz = vector(a, b, "distance segment")
		local px = safe_difference(x, a.x, "distance query")
		local pz = safe_difference(z, a.z, "distance query")
		local length = safe_sum(safe_square(dx, "segment length"),
			safe_square(dz, "segment length"), "segment length")
		if length == 0 then fail("zero-length segment") end
		local projection = dot(px, pz, dx, dz, "distance projection")
		if projection <= 0 then
			return safe_sum(safe_square(px, "endpoint distance"),
				safe_square(pz, "endpoint distance"), "endpoint distance"), 1
		elseif projection >= length then
			local ex = safe_difference(x, b.x, "endpoint distance")
			local ez = safe_difference(z, b.z, "endpoint distance")
			return safe_sum(safe_square(ex, "endpoint distance"),
				safe_square(ez, "endpoint distance"), "endpoint distance"), 1
		end
		local determinant = cross(dx, dz, px, pz, "segment cross")
		return reduce(safe_square(determinant, "segment cross"), length)
	end

	local function bay_segment(x, z, a, b, delta_nodes)
		delta_nodes = delta_nodes or 0
		integer(delta_nodes, -48, 48, "Bay displacement")
		integer(x, -2147483648, 2147483647, "Bay x")
		integer(z, -2147483648, 2147483647, "Bay z")
		local dx, dz = vector(a, b, "Bay segment")
		local px = safe_difference(x, a.x, "Bay query")
		local pz = safe_difference(z, a.z, "Bay query")
		local length = safe_sum(safe_square(dx, "Bay length"),
			safe_square(dz, "Bay length"), "Bay length")
		if length <= 0 then fail("zero-length Bay segment") end
		local projection = dot(px, pz, dx, dz, "Bay projection")
		integer(a.half_width, 0, MAX_SAFE, "Bay radius")
		integer(b.half_width, 0, MAX_SAFE, "Bay radius")
		local radius_a = a.half_width + delta_nodes
		local radius_b = b.half_width + delta_nodes
		if radius_a < 0 or radius_b < 0 then fail("negative Bay radius") end
		if projection <= 0 then
			return safe_sum(safe_square(px, "Bay cap"), safe_square(pz,
				"Bay cap"), "Bay cap") < safe_square(radius_a, "Bay cap")
		elseif projection >= length then
			local ex = safe_difference(x, b.x, "Bay cap")
			local ez = safe_difference(z, b.z, "Bay cap")
			return safe_sum(safe_square(ex, "Bay cap"), safe_square(ez,
				"Bay cap"), "Bay cap") < safe_square(radius_b, "Bay cap")
		end
		local determinant = cross(dx, dz, px, pz, "Bay cross")
		local maximum_radius = math.max(radius_a, radius_b)
		if math.abs(determinant) >= safe_nonnegative_product(maximum_radius,
				ceil_isqrt(length), "Bay early reject") then
			return false
		end
		local width_numerator = safe_sum(safe_sum(
			safe_product(a.half_width, length - projection, "Bay width"),
			safe_product(b.half_width, projection, "Bay width"), "Bay width"),
			safe_product(delta_nodes, length, "Bay width"), "Bay width")
		local left = safe_nonnegative_product(safe_square(determinant, "Bay cross"),
			length, "Bay body")
		local right = safe_square(width_numerator, "Bay width")
		return left < right
	end

	local function bay_member(x, z, bay, deltas)
		for index = 1, #bay.centreline - 1 do
			if bay_segment(x, z, bay.centreline[index],
					bay.centreline[index + 1], deltas and deltas[index] or 0) then
				return true
			end
		end
		return false
	end

	local function wing_member(x, z, wing)
		integer(x, -2147483648, 2147483647, "wing x")
		integer(z, -2147483648, 2147483647, "wing z")
		local dx, dz = vector(wing.head, wing.junction, "wing segment")
		local px = safe_difference(x, wing.head.x, "wing query")
		local pz = safe_difference(z, wing.head.z, "wing query")
		local length = safe_sum(safe_square(dx, "wing length"),
			safe_square(dz, "wing length"), "wing length")
		if length <= 0 then fail("zero-length closure wing") end
		local projection = dot(px, pz, dx, dz, "wing projection")
		if projection < 0 or projection >= length then return false end
		local determinant = cross(dx, dz, px, pz, "wing cross")
		integer(wing.head_half_width, 0, MAX_SAFE, "wing radius")
		if math.abs(determinant) >= safe_nonnegative_product(
				wing.head_half_width, ceil_isqrt(length), "wing early reject") then
			return false
		end
		local remaining = length - projection
		local left = safe_nonnegative_product(safe_square(determinant, "wing cross"),
			length, "wing body")
		local radius_square = safe_square(wing.head_half_width, "wing radius")
		local right = safe_nonnegative_product(radius_square,
			safe_square(remaining, "wing taper"), "wing body")
		return left < right
	end

	local function ellipse_member(x, z, center, envelope)
		integer(x, -2147483648, 2147483647, "ellipse x")
		integer(z, -2147483648, 2147483647, "ellipse z")
		point(center, "ellipse center")
		local dx = safe_difference(x, center.x, "ellipse delta")
		local dz = safe_difference(z, center.z, "ellipse delta")
		local rx = integer(envelope.radius_x, 1, MAX_SAFE, "ellipse radius")
		local rz = integer(envelope.radius_z, 1, MAX_SAFE, "ellipse radius")
		if math.abs(dx) > rx or math.abs(dz) > rz then return false end
		local left = safe_sum(safe_nonnegative_product(safe_square(dx,
			"ellipse term"), safe_square(rz, "ellipse term"), "ellipse term"),
			safe_nonnegative_product(safe_square(dz, "ellipse term"),
				safe_square(rx, "ellipse term"), "ellipse term"), "ellipse sum")
		local right = safe_nonnegative_product(safe_square(rx, "ellipse bound"),
			safe_square(rz, "ellipse bound"), "ellipse bound")
		return left <= right
	end

	exact.integer = integer
	exact.safe_product = safe_nonnegative_product
	exact.safe_signed_product = safe_product
	exact.safe_square = safe_square
	exact.safe_sum = safe_sum
	exact.safe_difference = safe_difference
	exact.point = point
	exact.validate_closed_polygon = validate_closed_polygon
	exact.vector = vector
	exact.dot = dot
	exact.cross = cross
	exact.gcd = gcd
	exact.reduce = reduce
	exact.rational_compare = rational_compare
	exact.ceil_isqrt = ceil_isqrt
	exact.point_on_segment = point_on_segment
	exact.polygon_class = polygon_class
	exact.polygon_class_candidates = polygon_class_candidates
	exact.polygon_index = polygon_index
	exact.indexed_polygon_class = indexed_polygon_class
	exact.signed_area2 = signed_area2
	exact.polygon_simple = polygon_simple
	exact.segment_distance = segment_distance
	exact.bay_segment = bay_segment
	exact.bay_member = bay_member
	exact.wing_member = wing_member
	exact.ellipse_member = ellipse_member
	exact.MAX_SAFE = MAX_SAFE
	return exact
end
