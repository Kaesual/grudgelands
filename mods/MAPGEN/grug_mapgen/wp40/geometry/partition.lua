-- Private WP40 T2 partition compiler.  It consumes only checksum-validated
-- source plus T1/exact/raster seams and returns normalized data-only records.

local function fail(message)
	error("WP40 geometry partition: " .. message, 0)
end

local function exact_dependencies(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {canonical = true, deterministic = true, exact = true,
		raster = true, raw_sha256 = true, source = true,
		source_validator = true, vocabulary = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unknown dependency " .. tostring(key)) end
	end
	for _, key in ipairs({"canonical", "deterministic", "exact", "raster",
			"source", "source_validator", "vocabulary"}) do
		if type(value[key]) ~= "table" or getmetatable(value[key]) ~= nil then
			fail(key .. " dependency is not a plain table")
		end
	end
	if type(value.raw_sha256) ~= "function" then fail("raw SHA dependency missing") end
end

local function new_partition(dependencies)
	exact_dependencies(dependencies)
	local canonical = dependencies.canonical
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	local raster = dependencies.raster
	local source = dependencies.source
	local Q = deterministic.Q
	local partition = {}

	local function dense(value, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain array")
		end
		local count = #value
		for key in pairs(value) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail(label .. " is not dense")
			end
		end
		return count
	end

	local function checked_coordinate(value, delta, label)
		exact.integer(value, -2147483648, 2147483647, label .. " coordinate")
		exact.integer(delta, -2147483648, 2147483647, label .. " delta")
		return exact.integer(exact.safe_sum(value, delta, label),
			-2147483648, 2147483647, label .. " result")
	end

	local function copy_points(points)
		local result = {}
		for index = 1, dense(points, "points") do
			result[index] = {x = points[index].x, z = points[index].z}
		end
		return result
	end

	local function coordinates(points, closed)
		local result = {}
		for index = 1, #points do
			result[#result + 1] = points[index].x
			result[#result + 1] = points[index].z
		end
		if closed then
			result[#result + 1] = points[1].x
			result[#result + 1] = points[1].z
		end
		return result
	end

	local function scalar_sample_arrays(row)
		local positions, scalar_q, source_segment, local_station = {}, {}, {}, {}
		for index = 1, #row.scalar_samples do
			local sample = row.scalar_samples[index]
			positions[#positions + 1] = sample.x
			positions[#positions + 1] = sample.z
			scalar_q[index] = sample.scalar_q
			source_segment[index] = sample.source_segment
			local_station[index] = sample.local_station
		end
		return positions, scalar_q, source_segment, local_station
	end

	local function named_text(values)
		local result = {}
		for name, value in pairs(values or {}) do
			result[#result + 1] = {name = name, value = value}
		end
		table.sort(result, function(a, b) return a.name < b.name end)
		return result
	end

	local function named_number(values)
		local result = {}
		for name, value in pairs(values or {}) do
			result[#result + 1] = {name = name, value = value}
		end
		table.sort(result, function(a, b) return a.name < b.name end)
		return result
	end

	local function named_array(values)
		local result = {}
		for name, value in pairs(values or {}) do
			local copy = {}
			for index = 1, #value do copy[index] = value[index] end
			result[#result + 1] = {name = name, values = copy}
		end
		table.sort(result, function(a, b) return a.name < b.name end)
		return result
	end

	local function array_copy(values)
		local result = {}
		for index = 1, #values do result[index] = values[index] end
		return result
	end

	local function named_values(record_value, field, name)
		local rows = record_value[field]
		for index = 1, dense(rows, field) do
			if rows[index].name == name then return rows[index].values end
		end
		fail(record_value.id .. " lacks " .. name)
	end

	local function named_scalar(record_value, field, name)
		local rows = record_value[field]
		for index = 1, dense(rows, field) do
			if rows[index].name == name then return rows[index].value end
		end
		fail(record_value.id .. " lacks " .. name)
	end

	local function record(schema, id, numeric_id, fields)
		fields = fields or {}
		return {record_schema = schema, id = id, numeric_id = numeric_id or 0,
			text_values = named_text(fields.text),
			signed_values = named_number(fields.signed),
			unsigned_values = named_number(fields.unsigned),
			boolean_values = named_number(fields.boolean),
			text_arrays = named_array(fields.text_arrays),
			signed_arrays = named_array(fields.signed_arrays),
			unsigned_arrays = named_array(fields.unsigned_arrays),
			candidates = fields.candidates or {}, attributes = {}}
	end

	local function key(point)
		return point.x .. ":" .. point.z
	end

	local function append_points(target, part)
		for index = 1, #part do
			local point = part[index]
			if #target == 0 or target[#target].x ~= point.x or
					target[#target].z ~= point.z then
				target[#target + 1] = {x = point.x, z = point.z}
			end
		end
	end

	local function reverse_points(points)
		local result = {}
		for index = #points, 1, -1 do
			result[#result + 1] = {x = points[index].x, z = points[index].z}
		end
		return result
	end

	local function fixed_closure_union(perimeter, edge_by_id)
		local closure = perimeter.r7_fixed_closure
		if closure == nil then return nil end
		if type(closure) ~= "table" or getmetatable(closure) ~= nil or
				closure.kind ~= "fixed_holy_land_edge_union" or
				type(closure.edge_refs) ~= "table" or #closure.edge_refs ~= 6 then
			fail(perimeter.id .. " fixed closure is malformed")
		end
		local union, seen = {}, {}
		for ref_index = 1, #closure.edge_refs do
			local ref = closure.edge_refs[ref_index]
			local edge = edge_by_id[ref.edge_id]
			if not edge or edge.max_displacement ~= 0 or
					(ref.direction ~= "forward" and ref.direction ~= "reverse") then
				fail(perimeter.id .. " fixed closure reference is invalid")
			end
			local part = raster.final_raster(copy_points(edge.control), false)
			if ref.direction == "reverse" then part = reverse_points(part) end
			if #union > 0 and (union[#union].x ~= part[1].x or
					union[#union].z ~= part[1].z) then
				fail(perimeter.id .. " fixed closure references do not join")
			end
			for point_index = 1, #part do
				local point = part[point_index]
				if #union == 0 or union[#union].x ~= point.x or union[#union].z ~= point.z then
					local point_key = key(point)
					if seen[point_key] then
						fail(perimeter.id .. " fixed closure repeats a station")
					end
					seen[point_key] = true
					union[#union + 1] = {x = point.x, z = point.z}
				end
			end
		end
		return union
	end

	local function select_attachment_station(e, candidates, canonical_indices)
		exact.point(e, "Attachment E")
		dense(candidates, "Attachment candidates")
		if type(canonical_indices) ~= "table" or getmetatable(canonical_indices) ~= nil then
			fail("Attachment canonical index is invalid")
		end
		local best, best_distance, best_index
		for candidate_index = 1, #candidates do
			local candidate = candidates[candidate_index]
			exact.point(candidate, "Attachment candidate")
			local canonical_index = canonical_indices[key(candidate)]
			exact.integer(canonical_index, 1, exact.MAX_SAFE,
				"Attachment canonical station index")
			local distance = math.max(math.abs(exact.safe_difference(e.x, candidate.x,
				"Attachment distance")), math.abs(exact.safe_difference(e.z, candidate.z,
				"Attachment distance")))
			if not best or distance < best_distance or distance == best_distance and
					canonical_index < best_index then
				best, best_distance, best_index = candidate, distance, canonical_index
			end
		end
		if not best or best_distance > 1 then fail("Attachment E/A distance exceeds one") end
		return {x = best.x, z = best.z}, best_distance, best_index
	end

	local function transition_water_owned(final_water_value, same_bay_final_value)
		if type(final_water_value) ~= "boolean" or
				type(same_bay_final_value) ~= "boolean" then
			fail("Bay edge transition water evidence is not boolean")
		end
		return final_water_value and same_bay_final_value
	end

	-- Production-consumed closed decision seam for one declared Bay edge
	-- transition. Geometry classifiers are evaluated by compile_impl; this seam
	-- owns the exact direct/fallback decision, elbow derivation, and lex tie.
	local function select_edge_transition(evidence)
		if type(evidence) ~= "table" or getmetatable(evidence) ~= nil or
				type(evidence.id) ~= "string" or
				type(evidence.direct_candidate) ~= "boolean" then
			fail("Bay edge transition evidence is malformed")
		end
		exact.point(evidence.e, evidence.id .. " E")
		if evidence.direct_candidate then
			local allowed = {id = true, e = true, direct_candidate = true}
			for field in pairs(evidence) do
				if not allowed[field] then
					fail(evidence.id .. " direct evidence has an unknown field")
				end
			end
			return {point = {x = evidence.e.x, z = evidence.e.z}, mode = "direct"}
		end
		local allowed = {id = true, e = true, direct_candidate = true, w = true,
			e_strict_dry = true, e_cardinal_water = true, w_owned_by_bay = true,
			w_foreign_water = true, elbow_valid = true}
		for field in pairs(evidence) do
			if not allowed[field] then
				fail(evidence.id .. " fallback evidence has an unknown field")
			end
		end
		if type(evidence.e_strict_dry) ~= "boolean" or
				type(evidence.e_cardinal_water) ~= "boolean" or
				type(evidence.w_owned_by_bay) ~= "boolean" or
				type(evidence.w_foreign_water) ~= "boolean" or
				type(evidence.elbow_valid) ~= "table" or
				getmetatable(evidence.elbow_valid) ~= nil or
				dense(evidence.elbow_valid, evidence.id .. " elbow validity") ~= 2 or
				type(evidence.elbow_valid[1]) ~= "boolean" or
				type(evidence.elbow_valid[2]) ~= "boolean" then
			fail(evidence.id .. " fallback evidence is malformed")
		end
		exact.point(evidence.w, evidence.id .. " W")
		local dx = exact.safe_difference(evidence.w.x, evidence.e.x,
			evidence.id .. " E/W dx")
		local dz = exact.safe_difference(evidence.w.z, evidence.e.z,
			evidence.id .. " E/W dz")
		if not evidence.e_strict_dry then fail(evidence.id .. " has a nondry E") end
		if evidence.e_cardinal_water then
			fail(evidence.id .. " noncandidate E has cardinal water")
		end
		if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 then
			fail(evidence.id .. " E/W is not exactly diagonal")
		end
		if not evidence.w_owned_by_bay then
			fail(evidence.id .. " W is not referenced-Bay water")
		end
		if evidence.w_foreign_water then fail(evidence.id .. " W is foreign-Bay water") end
		local elbows = {{x = evidence.w.x, z = evidence.e.z},
			{x = evidence.e.x, z = evidence.w.z}}
		if key(elbows[1]) == key(elbows[2]) then
			fail(evidence.id .. " has duplicate orthogonal elbows")
		end
		if not evidence.elbow_valid[1] or not evidence.elbow_valid[2] then
			fail(evidence.id .. " has an invalid orthogonal elbow")
		end
		if elbows[2].x < elbows[1].x or
				elbows[2].x == elbows[1].x and elbows[2].z < elbows[1].z then
			elbows[1], elbows[2] = elbows[2], elbows[1]
		end
		return {point = {x = elbows[1].x, z = elbows[1].z}, mode = "diagonal_elbow",
			w = {x = evidence.w.x, z = evidence.w.z}, elbows = copy_points(elbows)}
	end

	local function add_edge_transition_control(controls, transition, endpoint, e)
		dense(controls, "Bay edge transition controls")
		local result = copy_points(controls)
		if not transition then return result end
		if endpoint ~= "from" and endpoint ~= "to" then
			fail("Bay edge transition endpoint is invalid")
		end
		exact.point(e, "Bay edge transition E")
		if type(transition) ~= "table" or getmetatable(transition) ~= nil or
				(transition.mode ~= "direct" and transition.mode ~= "diagonal_elbow") then
			fail("Bay edge transition selection is malformed")
		end
		exact.point(transition.point, "Bay edge transition selected point")
		if transition.mode == "direct" then
			local allowed = {mode = true, point = true}
			for field in pairs(transition) do
				if not allowed[field] then fail("direct transition selection has an unknown field") end
			end
			if key(transition.point) ~= key(e) then
				fail("direct transition selection differs from E")
			end
			return result
		end
		local allowed = {mode = true, point = true, w = true, elbows = true}
		for field in pairs(transition) do
			if not allowed[field] then fail("elbow transition selection has an unknown field") end
		end
		exact.point(transition.w, "Bay edge transition W")
		if dense(transition.elbows, "Bay edge transition elbows") ~= 2 then
			fail("elbow transition selection must contain two elbows")
		end
		exact.point(transition.elbows[1], "Bay edge transition first elbow")
		exact.point(transition.elbows[2], "Bay edge transition second elbow")
		local derived = {{x = transition.w.x, z = e.z}, {x = e.x, z = transition.w.z}}
		if derived[2].x < derived[1].x or
				derived[2].x == derived[1].x and derived[2].z < derived[1].z then
			derived[1], derived[2] = derived[2], derived[1]
		end
		local dx = exact.safe_difference(transition.w.x, e.x,
			"Bay edge transition assembly E/W dx")
		local dz = exact.safe_difference(transition.w.z, e.z,
			"Bay edge transition assembly E/W dz")
		if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 or
				key(transition.elbows[1]) ~= key(derived[1]) or
				key(transition.elbows[2]) ~= key(derived[2]) or
				key(transition.point) ~= key(derived[1]) or
				math.abs(transition.point.x - e.x) +
					math.abs(transition.point.z - e.z) ~= 1 then
			fail("elbow transition selection is not the exact lex E/W elbow")
		end
		local point = {x = transition.point.x, z = transition.point.z}
		if endpoint == "from" then table.insert(result, 1, point)
		else result[#result + 1] = point end
		return result
	end

	-- Private ordered decision seam used by the R12 trace and its synthetic
	-- stop-at-first KAT.  Candidate geometry remains private to compile_impl.
	local function select_first_reachable(candidates, predicate)
		dense(candidates, "reachable candidates")
		if type(predicate) ~= "function" then fail("reachability predicate is invalid") end
		for index = 1, #candidates do
			if predicate(candidates[index], index) then return candidates[index], index end
		end
		return nil
	end

	-- Private evaluator seam for the frozen horizontal precedence.  Geometry
	-- membership and owners are computed by the caller from the compiled
	-- payload; this function only resolves the mutually ordered result.
	local function horizontal_precedence(base_owner, wing_owner, footprint_kind,
			dry_owner, channel_id, shelf)
		local function optional_string(value)
			if value ~= nil and type(value) ~= "string" then
				fail("horizontal precedence input is invalid")
			end
		end
		optional_string(base_owner)
		optional_string(wing_owner)
		optional_string(footprint_kind)
		optional_string(dry_owner)
		optional_string(channel_id)
		if type(shelf) ~= "boolean" then fail("horizontal shelf input is invalid") end
		if base_owner then return "planned_water", base_owner end
		if wing_owner then return "planned_water", wing_owner end
		if footprint_kind then
			if not dry_owner then fail("closed footprint lacks a dry owner") end
			return "land", dry_owner
		end
		if channel_id then return "immutable_dragon_channel", channel_id end
		return shelf and "coastal_shelf" or "deep_ocean", nil
	end

	local function shelf_from_distance(numerator, denominator)
		exact.integer(numerator, 0, exact.MAX_SAFE, "exterior distance numerator")
		exact.integer(denominator, 1, exact.MAX_SAFE, "exterior distance denominator")
		return exact.rational_compare(numerator, denominator, 6400, 1) <= 0
	end

	local function closed_polygon(points)
		local polygon = copy_points(points)
		if #polygon == 0 then fail("empty closed polygon") end
		polygon[#polygon + 1] = {x = polygon[1].x, z = polygon[1].z}
		return polygon
	end

	-- Every composed face is an eight-connected integer lattice walk. For this
	-- representation, unique nonterminal stations plus the one possible
	-- station-free intersection (opposing cell diagonals) are the complete
	-- simplicity proof. This keeps 15k-station coast faces linear.
	local function validate_face_polygon(id, polygon)
		if #polygon < 4 or key(polygon[1]) ~= key(polygon[#polygon]) then
			fail(id .. " is not closed " .. key(polygon[1]) .. " -> " ..
				key(polygon[#polygon]))
		end
		local seen, diagonal_cells = {}, {}
		for index = 1, #polygon - 1 do
			local point = polygon[index]
			exact.point(point, id .. " station")
			local station_key = key(point)
			if seen[station_key] then fail(id .. " is not simple") end
			seen[station_key] = true
			local following = polygon[index + 1]
			exact.point(following, id .. " following station")
			local dx = exact.safe_difference(following.x, point.x, id .. " step")
			local dz = exact.safe_difference(following.z, point.z, id .. " step")
			if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
				fail(id .. " is not eight-connected")
			end
			if math.abs(dx) == 1 and math.abs(dz) == 1 then
				local cell_key = math.min(point.x, following.x) .. ":" ..
					math.min(point.z, following.z)
				local slope = dx == dz and 1 or -1
				if diagonal_cells[cell_key] and diagonal_cells[cell_key] ~= slope then
					fail(id .. " is not simple")
				end
				diagonal_cells[cell_key] = slope
			end
		end
		if exact.signed_area2(polygon) <= 0 then fail(id .. " is not CCW") end
	end

	local function polygon_index(points)
		local polygon = closed_polygon(points)
		return exact.polygon_index(polygon)
	end

	local function validate_junction_pair(junction, left, right, label)
		exact.point(junction, "junction pair point")
		local left_count = dense(left, "left junction raster")
		local right_count = dense(right, "right junction raster")
		if left_count < 2 or right_count < 2 then fail("junction pair raster is short") end
		local junction_key = key(junction)
		if key(left[1]) ~= junction_key and key(left[left_count]) ~= junction_key or
				key(right[1]) ~= junction_key and key(right[right_count]) ~= junction_key then
			fail((label or junction_key) .. " is not an edge endpoint")
		end
		local left_stations, left_diagonals = {}, {}
		for index = 1, left_count do
			exact.point(left[index], "left junction station")
			left_stations[key(left[index])] = true
			if index < left_count then
				local a, b = left[index], left[index + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
					fail((label or junction_key) .. " left raster is not eight-connected")
				end
				if math.abs(dx) == 1 and math.abs(dz) == 1 then
					local cell = math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z)
					left_diagonals[cell] = dx == dz and 1 or -1
				end
			end
		end
		for index = 1, right_count do
			exact.point(right[index], "right junction station")
			local station_key = key(right[index])
			if left_stations[station_key] and station_key ~= junction_key then
				fail((label or junction_key) .. " incident edges share a nonjunction station")
			end
			if index < right_count then
				local a, b = right[index], right[index + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
					fail((label or junction_key) .. " right raster is not eight-connected")
				end
				if math.abs(dx) == 1 and math.abs(dz) == 1 then
					local cell = math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z)
					local slope = dx == dz and 1 or -1
					if left_diagonals[cell] and left_diagonals[cell] ~= slope then
						fail((label or junction_key) ..
							" incident edges have an opposing diagonal X-cross")
					end
				end
			end
		end
		return true
	end

	local function trace_bounds(envelope_columns)
		envelope_columns = exact.integer(envelope_columns, 1, exact.MAX_SAFE,
			"Bay-bank envelope columns")
		return {envelope_columns = envelope_columns,
			reachability_frames = exact.safe_product(8, envelope_columns,
				"Bay-bank reachability frames"), stack_depth = envelope_columns,
			main_steps = exact.safe_difference(envelope_columns, 1,
				"Bay-bank main steps")}
	end

	local function count_trace_envelope(boxes, footprint_index, label)
		local count = dense(boxes, "Bay-bank trace boxes")
		if count == 0 then fail("Bay-bank trace boxes are empty") end
		local min_x, max_x, min_z, max_z
		for index = 1, count do
			local box = boxes[index]
			if type(box) ~= "table" or getmetatable(box) ~= nil then
				fail("Bay-bank trace box is invalid")
			end
			for _, field in ipairs({"min_x", "max_x", "min_z", "max_z"}) do
				exact.integer(box[field], -2147483648, 2147483647,
					"Bay-bank trace box " .. field)
			end
			if box.min_x > box.max_x or box.min_z > box.max_z then
				fail("Bay-bank trace box is inverted")
			end
			min_x = min_x and math.min(min_x, box.min_x) or box.min_x
			max_x = max_x and math.max(max_x, box.max_x) or box.max_x
			min_z = min_z and math.min(min_z, box.min_z) or box.min_z
			max_z = max_z and math.max(max_z, box.max_z) or box.max_z
		end
		local width = exact.safe_sum(exact.safe_difference(max_x, min_x,
			"Bay-bank trace rectangle width"), 1, "Bay-bank trace rectangle width")
		local height = exact.safe_sum(exact.safe_difference(max_z, min_z,
			"Bay-bank trace rectangle height"), 1, "Bay-bank trace rectangle height")
		exact.safe_product(width, height, "Bay-bank trace rectangle area")
		local envelope_columns = 0
		for x = min_x, max_x do
			for z = min_z, max_z do
				local in_union = false
				for box_index = 1, count do
					local box = boxes[box_index]
					if x >= box.min_x and x <= box.max_x and z >= box.min_z and
							z <= box.max_z then in_union = true break end
				end
				if in_union and exact.indexed_polygon_class(footprint_index, x, z) >= 0 then
					envelope_columns = exact.safe_sum(envelope_columns, 1,
						(label or "Bay-bank") .. " envelope columns")
				end
			end
		end
		if envelope_columns == 0 then fail((label or "Bay-bank") ..
			" has an empty trace envelope") end
		return envelope_columns
	end

	local function validate_trace_counters(bounds, pushed_frames, stack_depth,
			main_steps)
		if type(bounds) ~= "table" or getmetatable(bounds) ~= nil then
			fail("Bay-bank trace bounds are invalid")
		end
		if pushed_frames ~= nil then
			exact.integer(pushed_frames, 0, exact.MAX_SAFE, "Bay-bank pushed frames")
			if pushed_frames > bounds.reachability_frames then
				fail("Bay-bank reachability frame cap exhausted")
			end
		end
		if stack_depth ~= nil then
			exact.integer(stack_depth, 0, exact.MAX_SAFE, "Bay-bank stack depth")
			if stack_depth > bounds.stack_depth then
				fail("Bay-bank reachability stack cap exhausted")
			end
		end
		if main_steps ~= nil then
			exact.integer(main_steps, 0, exact.MAX_SAFE, "Bay-bank main steps")
			if main_steps > bounds.main_steps then
				fail("Bay-bank main trace cap exhausted")
			end
		end
		return true
	end

	local function source_validator()
		local validator = dependencies.source_validator
		if type(validator.new_offline_test_adapter) == "function" then
			validator = validator.new_offline_test_adapter(canonical,
				dependencies.raw_sha256)
		end
		local valid, diagnostic = validator.validate(source, dependencies.vocabulary)
		if not valid then
			fail("checksum-validated source rejected: " ..
				tostring(diagnostic and diagnostic.invariant) .. " at " ..
				tostring(diagnostic and diagnostic.record_id) .. " expected " ..
				tostring(diagnostic and diagnostic.expected) .. " observed " ..
				tostring(diagnostic and diagnostic.observed))
		end
	end

	local function collect_no_jitter_sources()
		local points, seen = {}, {}
		local function add(point)
			if type(point) == "table" and type(point.x) == "number" and
					type(point.z) == "number" then
				local id = key(point)
				if not seen[id] then
					seen[id] = true
					points[#points + 1] = {x = point.x, z = point.z}
				end
			end
		end
		local function add_polyline_collection(collection, field)
			for index = 1, #collection do
				local values = collection[index][field]
				if values then for point_index = 1, #values do add(values[point_index]) end end
			end
		end
		add_polyline_collection(source.land_edges, "control")
		add_polyline_collection(source.perimeters, "polygon")
		add_polyline_collection(source.bays, "centreline")
		add_polyline_collection(source.islands, "polygon")
		add_polyline_collection(source.channels, "polygon")
		add_polyline_collection(source.routes, "centreline")
		add_polyline_collection(source.island_routes, "centreline")
		add_polyline_collection(source.hydrology, "centreline")
		add_polyline_collection(source.housing_masks, "polygon")
		for spur_index = 1, #source.poi_spurs do
			local paths = source.poi_spurs[spur_index].candidate_paths
			for path_index = 1, #paths do
				for point_index = 1, #paths[path_index] do
					add(paths[path_index][point_index])
				end
			end
		end
		for arc_index = 1, #source.face_arcs do
			for component_index = 1, #source.face_arcs[arc_index].authority_components do
				local component = source.face_arcs[arc_index].authority_components[component_index]
				if component.kind == "literal_arc" then
					for point_index = 1, #component.control do add(component.control[point_index]) end
				end
			end
		end
		for _, collection in ipairs({source.route_interfaces,
				source.island_route_interfaces}) do
			for index = 1, #collection do add(collection[index].position) end
		end
		for index = 1, #source.anchors do
			if source.anchors[index].placement_mode == "fixed" then
				add(source.anchors[index].position)
			end
		end
		local holy = source.constants.holy_grounds
		for _, x in ipairs({holy.min_x, holy.max_x}) do
			for _, z in ipairs({holy.min_z, holy.max_z}) do add({x = x, z = z}) end
		end
		for index = 1, #source.constants.holy_junction_x do
			local x = source.constants.holy_junction_x[index]
			add({x = x, z = holy.min_z}) add({x = x, z = holy.max_z})
		end
		table.sort(points, function(a, b) return a.x < b.x or
			a.x == b.x and a.z < b.z end)
		return points
	end

	local function segment_parts(displaced, control_count, closed)
		local result = {}
		local segment_count = closed and control_count - 1 or control_count - 1
		for segment_index = 0, segment_count - 1 do
			local controls = {}
			for station_index = 1, #displaced.base_stations do
				local station = displaced.base_stations[station_index]
				if station.source_segment == segment_index then
					controls[#controls + 1] = displaced.shifted_controls[station.authored_order]
				elseif station.source_segment == segment_index - 1 and
						station.local_station == station.local_last then
					controls[#controls + 1] = displaced.shifted_controls[station.authored_order]
				end
			end
			if segment_index == segment_count - 1 and closed then
				controls[#controls + 1] = displaced.shifted_controls[1]
			end
			if #controls < 2 then fail("displaced source segment lost controls") end
			result[segment_index + 1] = raster.final_raster(controls, false)
		end
		return result
	end

	local function bay_data(seed)
		local rows, by_id = {}, {}
		for bay_index = 1, #source.bays do
			local bay = source.bays[bay_index]
			local segments = {}
			for segment_index = 1, #bay.centreline - 1 do
				local stations = raster.segment(bay.centreline[segment_index],
					bay.centreline[segment_index + 1])
				local deltas = {}
				local noise = {schema = "grug_wp40_geometry_source_v1", seed = seed,
					domain = bay.noise_domain, feature = "", octaves = {
						{period = 256, amplitude_numerator = 2, amplitude_denominator = 3},
						{period = 512, amplitude_numerator = 1, amplitude_denominator = 3}}}
				for station_index = 1, #stations do
					local point = stations[station_index]
					local noise_q = deterministic.clamp(deterministic.value_noise_2d(
						canonical, dependencies.raw_sha256, noise, point.x, point.z), -Q, Q)
					local distance = math.min(station_index - 1, #stations - station_index)
					local taper_q = deterministic.smootherstep(
						deterministic.qfrom_ratio(math.min(distance, 96), 96))
					deltas[station_index] = deterministic.qround(deterministic.qmul(
						deterministic.qmul(noise_q, bay.max_displacement * Q), taper_q))
				end
				segments[segment_index] = {stations = stations, deltas = deltas}
			end
			local compiled = {source = bay, segments = segments}
			by_id[bay.id] = compiled rows[#rows + 1] = compiled
		end
		return rows, by_id
	end

	local function nearest_bay_delta(compiled, segment_index, x, z)
		local segment = compiled.segments[segment_index]
		local best_index, best_distance
		for index = 1, #segment.stations do
			local point = segment.stations[index]
			local dx, dz = point.x - x, point.z - z
			local distance = dx * dx + dz * dz
			if not best_distance or distance < best_distance then
				best_index, best_distance = index, distance
			end
		end
		return segment.deltas[best_index], best_index - 1
	end

	local function base_bay_member(compiled, x, z)
		local bay = compiled.source
		for segment_index = 1, #bay.centreline - 1 do
			local delta = nearest_bay_delta(compiled, segment_index, x, z)
			if exact.bay_segment(x, z, bay.centreline[segment_index],
					bay.centreline[segment_index + 1], delta) then return true end
		end
		return false
	end

	-- Sole seed-dependent R7 boundary materialization authority. Partition
	-- compilation and the extreme selector consume this same result; neither
	-- path may prepare effective controls, no-jitter sources, fixed closure, or
	-- displacement independently.
	local function materialize_boundary_seed(seed)
		deterministic.validate_seed(seed)
		source_validator()
		local zone_numeric = {}
		for index = 1, #source.zones do
			zone_numeric[source.zones[index].id] = source.zones[index].numeric_id
		end
		local edge_source_by_id = {}
		for index = 1, #source.land_edges do
			edge_source_by_id[source.land_edges[index].id] = source.land_edges[index]
		end
		local departure_by_edge, effective_control_by_edge, departure_points = {}, {}, {}
		if #source.junction_departures ~= 4 then
			fail("junction departure roster is not exactly four records")
		end
		for index = 1, #source.junction_departures do
			local departure = source.junction_departures[index]
			local edge = edge_source_by_id[departure.edge_id]
			if not edge or departure_by_edge[departure.edge_id] then
				fail(departure.id .. " has a missing or duplicate edge")
			end
			local from = departure.edge_endpoint == "from"
			local endpoint_index = from and 1 or #edge.control
			local adjacent_index = from and 2 or #edge.control - 1
			local junction, adjacent = edge.control[endpoint_index], edge.control[adjacent_index]
			if adjacent.x == junction.x or adjacent.z == junction.z then
				fail(departure.id .. " cannot derive a diagonal departure")
			end
			local step_x = adjacent.x > junction.x and 1 or -1
			local step_z = adjacent.z > junction.z and 1 or -1
			local derived = {x = exact.safe_sum(junction.x, step_x,
				departure.id .. " x"), z = exact.safe_sum(junction.z, step_z,
				departure.id .. " z")}
			local frame = source.constants.mainland_frame
			if derived.x < frame.min_x or derived.x > frame.max_x or
					derived.z < frame.min_z or derived.z > frame.max_z then
				fail(departure.id .. " leaves the mainland frame")
			end
			local control = copy_points(edge.control)
			if from then
				table.insert(control, 2, derived)
			else
				table.insert(control, #control, derived)
			end
			departure_by_edge[departure.edge_id] = {source = departure,
				point = derived, effective_control = control}
			effective_control_by_edge[departure.edge_id] = control
			departure_points[#departure_points + 1] = derived
		end
		local no_jitter = collect_no_jitter_sources()
		local no_jitter_seen = {}
		for index = 1, #no_jitter do no_jitter_seen[key(no_jitter[index])] = true end
		for index = 1, #departure_points do
			local point = departure_points[index]
			if not no_jitter_seen[key(point)] then
				no_jitter[#no_jitter + 1] = {x = point.x, z = point.z}
				no_jitter_seen[key(point)] = true
			end
		end
		table.sort(no_jitter, function(a, b) return a.x < b.x or
			a.x == b.x and a.z < b.z end)
		local perimeter_rows, perimeter_by_id = {}, {}
		for index = 1, #source.perimeters do
			local row = source.perimeters[index]
			local kind = row.kind == "fixed_land_band" and "fixed" or
				"mainland_coast"
			local closure = fixed_closure_union(row, edge_source_by_id)
			local displaced = raster.displace({id = row.id, kind = kind,
				control = row.polygon, closed = true,
				orientation = row.orientation,
				noise_domain = row.noise_domain,
				max_displacement = row.max_displacement,
				fixed_closure = closure,
				envelope = source.constants.mainland_frame}, seed, no_jitter)
			displaced.source = row
			displaced.segment_parts = segment_parts(displaced, #row.polygon, true)
		local canonical_ok, canonical_stations = pcall(raster.canonical_closed,
				displaced.stations)
			if not canonical_ok then
				local repeated = {}
				for station_index = 1, #displaced.stations do
					local station_key = key(displaced.stations[station_index])
					if repeated[station_key] then
						local first, second = repeated[station_key], station_index
						local nearest = {}
						for sample_index = 1, #displaced.scalar_samples do
							local sample = displaced.scalar_samples[sample_index]
							local distance = math.max(math.abs(sample.x - displaced.stations[first].x),
								math.abs(sample.z - displaced.stations[first].z))
							if distance <= 4 then nearest[#nearest + 1] =
								sample.source_segment .. ":" .. sample.local_station .. ":" ..
								sample.x .. ":" .. sample.z .. ":" .. sample.scalar_q end
						end
						fail(row.id .. " repeated final station " .. station_key .. " at " ..
							first .. "/" .. second .. " samples " .. table.concat(nearest, ","))
					end
					repeated[station_key] = station_index
				end
				fail(row.id .. " " .. tostring(canonical_stations))
			end
			displaced.canonical_stations = canonical_stations
			displaced.lookup = {}
			for station_index = 1, #displaced.stations do
				displaced.lookup[key(displaced.stations[station_index])] = station_index
			end
			displaced.polygon_index = polygon_index(displaced.stations)
			perimeter_rows[#perimeter_rows + 1] = displaced
			perimeter_by_id[row.id] = displaced
		end
		local island_rows, island_by_id = {}, {}
		for index = 1, #source.islands do
			local row = source.islands[index]
			local displaced = raster.displace({id = row.id, kind = "island_coast",
				control = row.polygon, closed = true,
				orientation = row.orientation,
				noise_domain = row.noise_domain,
				max_displacement = row.max_displacement,
				envelope = {center = row.center, radius_x = row.envelope.radius_x,
					radius_z = row.envelope.radius_z}}, seed, no_jitter)
			displaced.source = row island_rows[#island_rows + 1] = displaced
			displaced.polygon_index = polygon_index(displaced.stations)
			island_by_id[row.id] = displaced
		end
		local provisional_edges, edge_by_id = {}, {}
		for index = 1, #source.land_edges do
			local row = source.land_edges[index]
			local displaced = raster.displace({id = row.id, kind = "land_edge",
				control = effective_control_by_edge[row.id] or row.control, closed = false,
				noise_domain = row.noise_domain,
				max_displacement = row.max_displacement}, seed, no_jitter)
			displaced.source = row provisional_edges[index] = displaced
			edge_by_id[row.id] = displaced
		end
		return {zone_numeric = zone_numeric,
			edge_source_by_id = edge_source_by_id,
			departure_by_edge = departure_by_edge,
			perimeter_rows = perimeter_rows, perimeter_by_id = perimeter_by_id,
			island_rows = island_rows, island_by_id = island_by_id,
			provisional_edges = provisional_edges, edge_by_id = edge_by_id}
	end

	local function compile_impl(seed)
		local boundary = materialize_boundary_seed(seed)
		local zone_numeric = boundary.zone_numeric
		local departure_by_edge = boundary.departure_by_edge
		local perimeter_rows, perimeter_by_id = boundary.perimeter_rows,
			boundary.perimeter_by_id
		local island_rows, island_by_id = boundary.island_rows, boundary.island_by_id
		local provisional_edges, edge_by_id = boundary.provisional_edges,
			boundary.edge_by_id
		local bays, bay_by_id = bay_data(seed)
		local aperture_rows, aperture_by_bay, aperture_by_id = {}, {}, {}
		local aperture_station_owner = {}
		for index = 1, #source.bay_mouth_apertures do
			local row = source.bay_mouth_apertures[index]
			local perimeter = perimeter_by_id[row.perimeter_id]
			local bay = bay_by_id[row.bay_id]
			local mouth = bay.source.centreline[row.mouth_sample_index]
			local canonical_lookup = {}
			for station_index = 1, #perimeter.canonical_stations do
				canonical_lookup[key(perimeter.canonical_stations[station_index])] =
					station_index
			end
			local mouth_index = canonical_lookup[key(mouth)]
			if not mouth_index then fail(row.id .. " mouth absent from final perimeter") end
			local first, last = mouth_index, mouth_index
			while first > 1 and base_bay_member(bay,
					perimeter.canonical_stations[first - 1].x,
					perimeter.canonical_stations[first - 1].z) do
				first = first - 1
			end
			while last < #perimeter.canonical_stations and base_bay_member(bay,
					perimeter.canonical_stations[last + 1].x,
					perimeter.canonical_stations[last + 1].z) do
				last = last + 1
			end
			if first == 1 or last == #perimeter.canonical_stations or first > mouth_index or
					last < mouth_index then fail(row.id .. " aperture is not nonwrapping") end
			local included = {}
			for station_index = first, last do
				local point = perimeter.canonical_stations[station_index]
				if not base_bay_member(bay, point.x, point.z) then
					fail(row.id .. " aperture contains a dry station")
				end
				if aperture_station_owner[key(point)] then
					fail(row.id .. " overlaps " .. aperture_station_owner[key(point)])
				end
				aperture_station_owner[key(point)] = row.id
				included[key(point)] = true
			end
			local before = perimeter.canonical_stations[first - 1]
			local excluded_end = perimeter.canonical_stations[last + 1]
			if base_bay_member(bay, before.x, before.z) or
					base_bay_member(bay, excluded_end.x, excluded_end.z) then
				fail(row.id .. " is not a maximal aperture run")
			end
			for station_index = 1, #perimeter.canonical_stations do
				if (station_index < first or station_index > last) and
						base_bay_member(bay,
							perimeter.canonical_stations[station_index].x,
							perimeter.canonical_stations[station_index].z) then
					fail(row.id .. " has a wrapping or second aperture run")
				end
			end
			local compiled = {source = row, first = first, finish = last + 1,
				count = last - first + 1, included = included,
				first_point = perimeter.canonical_stations[first],
				last_point = perimeter.canonical_stations[last], before = before,
				excluded_end = excluded_end}
			-- Bank terminals deliberately use the final authored/declared perimeter
			-- direction.  Canonical indices above remain the mouth payload and
			-- equality authority; the two orders must never be conflated.
			local authored_lookup = {}
			for station_index = 1, #perimeter.stations do
				authored_lookup[key(perimeter.stations[station_index])] = station_index
			end
			local authored_mouth = authored_lookup[key(mouth)]
			if not authored_mouth then fail(row.id .. " mouth absent from authored perimeter") end
			local authored_first, authored_last = authored_mouth, authored_mouth
			while authored_first > 1 and base_bay_member(bay,
					perimeter.stations[authored_first - 1].x,
					perimeter.stations[authored_first - 1].z) do
				authored_first = authored_first - 1
			end
			while authored_last < #perimeter.stations and base_bay_member(bay,
					perimeter.stations[authored_last + 1].x,
					perimeter.stations[authored_last + 1].z) do
				authored_last = authored_last + 1
			end
			if authored_first <= 2 or authored_last >= #perimeter.stations - 1 then
				fail(row.id .. " authored Bank aperture wraps")
			end
			for station_index = 1, #perimeter.stations do
				if (station_index < authored_first or station_index > authored_last) and
						base_bay_member(bay, perimeter.stations[station_index].x,
							perimeter.stations[station_index].z) then
					fail(row.id .. " authored Bank aperture has a second run")
				end
			end
			compiled.bank_first = authored_first
			compiled.bank_finish = authored_last + 1
			compiled.bank_before = perimeter.stations[authored_first - 1]
			compiled.bank_after = perimeter.stations[authored_last + 1]
			compiled.bank_before_previous = perimeter.stations[authored_first - 2]
			compiled.bank_after_previous = perimeter.stations[authored_last + 2]
			aperture_rows[#aperture_rows + 1] = compiled
			aperture_by_bay[row.bay_id] = compiled
			aperture_by_id[row.id] = compiled
		end
		local function footprint_class(x, z)
			for index = 1, 2 do
				local class = exact.indexed_polygon_class(
					perimeter_rows[index].polygon_index, x, z)
				if class >= 0 then return class, perimeter_rows[index] end
			end
			local holy = source.constants.holy_grounds
			if x >= holy.min_x and x <= holy.max_x and z >= holy.min_z and
					z <= holy.max_z then return 1, perimeter_rows[3] end
			for index = 1, #island_rows do
				local class = exact.indexed_polygon_class(
					island_rows[index].polygon_index, x, z)
				if class >= 0 then return class, island_rows[index] end
			end
			return -1
		end
		local wing_by_bay = {}
		local wing_by_id = {}
		for index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[index]
			wing_by_id[wing.id] = wing
			wing_by_bay[wing.bay_id] = wing_by_bay[wing.bay_id] or {}
			wing_by_bay[wing.bay_id][#wing_by_bay[wing.bay_id] + 1] = wing
		end
		local cardinal = {{x = 1, z = 0}, {x = 0, z = -1},
			{x = -1, z = 0}, {x = 0, z = 1}}
		local diagonal = {{x = 1, z = 1}, {x = 1, z = -1},
			{x = -1, z = 1}, {x = -1, z = -1}}
		local function point_less(a, b)
			return a.x < b.x or a.x == b.x and a.z < b.z
		end

		-- Bay boundary classification is shared by transition resolution and the
		-- later Bank tracer.  Building it once here prevents a transition elbow
		-- from becoming a second, privately interpreted candidate authority.
		local bay_context_by_id = {}
		for bay_index = 1, #bays do
			local bay = bays[bay_index]
			local context = {bay = bay,
				perimeter = perimeter_by_id[bay.source.perimeter_projection.perimeter_id],
				aperture = aperture_by_bay[bay.source.id],
				wings = wing_by_bay[bay.source.id], raw_rows = {}, fill = {},
				fill_points = {},
				water_cache = {}, dry_cache = {}, candidate_cache = {}, boxes = {}}
			local min_x, max_x, min_z, max_z
			for segment_index = 1, #bay.source.centreline - 1 do
				local a, b = bay.source.centreline[segment_index],
					bay.source.centreline[segment_index + 1]
				local radius = exact.safe_sum(exact.safe_sum(
					math.max(a.half_width, b.half_width),
					bay.source.max_displacement, bay.source.id .. " Base envelope"),
					1, bay.source.id .. " Base envelope")
				local box = {min_x = checked_coordinate(math.min(a.x, b.x), -radius,
					bay.source.id .. " Base envelope x"),
					max_x = checked_coordinate(math.max(a.x, b.x), radius,
						bay.source.id .. " Base envelope x"),
					min_z = checked_coordinate(math.min(a.z, b.z), -radius,
						bay.source.id .. " Base envelope z"),
					max_z = checked_coordinate(math.max(a.z, b.z), radius,
						bay.source.id .. " Base envelope z")}
				context.boxes[#context.boxes + 1] = box
				min_x = min_x and math.min(min_x, box.min_x) or box.min_x
				max_x = max_x and math.max(max_x, box.max_x) or box.max_x
				min_z = min_z and math.min(min_z, box.min_z) or box.min_z
				max_z = max_z and math.max(max_z, box.max_z) or box.max_z
			end
			for wing_index = 1, #context.wings do
				local wing = context.wings[wing_index]
				local radius = exact.safe_sum(wing.head_half_width, 1,
					wing.id .. " envelope")
				local box = {min_x = checked_coordinate(
					math.min(wing.head.x, wing.junction.x), -radius,
					wing.id .. " envelope x"),
					max_x = checked_coordinate(math.max(wing.head.x, wing.junction.x),
						radius, wing.id .. " envelope x"),
					min_z = checked_coordinate(math.min(wing.head.z, wing.junction.z),
						-radius, wing.id .. " envelope z"),
					max_z = checked_coordinate(math.max(wing.head.z, wing.junction.z),
						radius, wing.id .. " envelope z")}
				context.boxes[#context.boxes + 1] = box
				min_x, max_x = math.min(min_x, box.min_x), math.max(max_x, box.max_x)
				min_z, max_z = math.min(min_z, box.min_z), math.max(max_z, box.max_z)
			end
			context.min_x, context.max_x = min_x, max_x
			context.min_z, context.max_z = min_z, max_z
			bay_context_by_id[bay.source.id] = context
		end

		local function in_bay_envelope(context, x, z)
			for index = 1, #context.boxes do
				local box = context.boxes[index]
				if x >= box.min_x and x <= box.max_x and z >= box.min_z and
						z <= box.max_z then return true end
			end
			return false
		end

		local function row_contains(rows, x, z)
			local runs = rows[z]
			if not runs then return false end
			for index = 1, #runs do
				local run = runs[index]
				if x < run.first then return false end
				if x <= run.finish then return true end
			end
			return false
		end

		-- For one integer z row, remove the common x^2 term from every squared
		-- station distance.  The lower envelope below retains the exact lower
		-- canonical station-index tie and avoids a station scan per mask column.
		local function nearest_schedule(stations, z, label)
			local lines = {}
			for index = 1, #stations do
				local point = stations[index]
				local dz = exact.safe_difference(z, point.z, label .. " row distance")
				lines[index] = {m = exact.safe_signed_product(-2, point.x,
					label .. " row slope"), b = exact.safe_sum(
					exact.safe_square(point.x, label .. " row intercept"),
					exact.safe_square(dz, label .. " row intercept"),
					label .. " row intercept"), index = index}
			end
			table.sort(lines, function(a, b)
				return a.m > b.m or a.m == b.m and
					(a.b < b.b or a.b == b.b and a.index < b.index)
			end)
			local unique = {}
			for index = 1, #lines do
				if #unique == 0 or lines[index].m ~= unique[#unique].m then
					unique[#unique + 1] = lines[index]
				end
			end
			local hull = {}
			for index = 1, #unique do
				local line, start = unique[index], -2147483648
				while #hull > 0 do
					local previous = hull[#hull]
					local numerator = exact.safe_difference(line.b, previous.b,
						label .. " row intersection")
					local denominator = exact.safe_difference(previous.m, line.m,
						label .. " row intersection")
					if denominator <= 0 then fail(label .. " row slopes are not ordered") end
					if line.index < previous.index then
						start = -deterministic.floor_div(-numerator, denominator)
					else
						start = exact.safe_sum(deterministic.floor_div(numerator,
							denominator), 1, label .. " row intersection")
					end
					if start > previous.start then break end
					table.remove(hull)
				end
				if #hull == 0 then start = -2147483648 end
				line.start = start
				hull[#hull + 1] = line
			end
			return hull
		end

		local function schedule_station(schedule, x, cursor)
			while cursor < #schedule and schedule[cursor + 1].start <= x do
				cursor = cursor + 1
			end
			return schedule[cursor].index, cursor
		end

		-- Materialize the immutable raw per-Bay mask exactly once.  Its row runs
		-- are then the only input to the simultaneous R17 fill; a filled point is
		-- never visible while another fill decision is made.
		for bay_index = 1, #bays do
			local context = bay_context_by_id[bays[bay_index].source.id]
			for z = context.min_z, context.max_z do
				local schedules, cursors = {}, {}
				for segment_index = 1, #context.bay.segments do
					schedules[segment_index] = nearest_schedule(
						context.bay.segments[segment_index].stations, z,
						context.bay.source.id)
					cursors[segment_index] = 1
				end
				local runs, first = {}, nil
				for x = context.min_x, context.max_x do
					local point_key = x .. ":" .. z
					local class = exact.indexed_polygon_class(
						context.perimeter.polygon_index, x, z)
					local raw = false
					if class >= 0 then
						local base = false
						for segment_index = 1, #context.bay.segments do
							local station_index
							station_index, cursors[segment_index] = schedule_station(
								schedules[segment_index], x, cursors[segment_index])
							if exact.bay_segment(x, z,
									context.bay.source.centreline[segment_index],
									context.bay.source.centreline[segment_index + 1],
									context.bay.segments[segment_index].deltas[station_index]) then
								base = true break
							end
						end
						if base and (class > 0 or context.aperture.included[point_key]) then
							raw = true
						elseif class > 0 then
							for wing_index = 1, #context.wings do
								if exact.wing_member(x, z, context.wings[wing_index]) then
									raw = true break
								end
							end
						end
					end
					if raw and not first then first = x end
					if not raw and first then
						runs[#runs + 1] = {first = first, finish =
							checked_coordinate(x, -1,
								context.bay.source.id .. " raw run")}
						first = nil
					end
				end
				if first then runs[#runs + 1] = {first = first, finish = context.max_x} end
				if #runs > 0 then context.raw_rows[z] = runs end
			end
		end

		local function raw_bay_water(context, x, z)
			return row_contains(context.raw_rows, x, z)
		end

		local function raw_owner_count(x, z)
			local count, owner = 0, nil
			for bay_index = 1, #bays do
				local context = bay_context_by_id[bays[bay_index].source.id]
				if raw_bay_water(context, x, z) then
					count, owner = count + 1, context
				end
			end
			return count, owner
		end

		local fill_owner = {}
		for bay_index = 1, #bays do
			local context = bay_context_by_id[bays[bay_index].source.id]
			local candidates = {}
			for z = context.min_z, context.max_z do
				local runs = context.raw_rows[z] or {}
				for run_index = 1, #runs do
					local run = runs[run_index]
					for _, x in ipairs({checked_coordinate(run.first, -1,
							context.bay.source.id .. " notch candidate"),
						checked_coordinate(run.finish, 1,
							context.bay.source.id .. " notch candidate")}) do
						if x >= context.min_x and x <= context.max_x then
							candidates[x .. ":" .. z] = {x = x, z = z}
						end
					end
				end
			end
			local ordered = {}
			for _, point in pairs(candidates) do ordered[#ordered + 1] = point end
			table.sort(ordered, point_less)
			for candidate_index = 1, #ordered do
				local point = ordered[candidate_index]
				local strict = in_bay_envelope(context, point.x, point.z)
				for dx = -1, 1 do
					for dz = -1, 1 do
						local nx = checked_coordinate(point.x, dx,
							context.bay.source.id .. " notch neighborhood x")
						local nz = checked_coordinate(point.z, dz,
							context.bay.source.id .. " notch neighborhood z")
						if exact.indexed_polygon_class(context.perimeter.polygon_index,
								nx, nz) ~= 1 then strict = false end
					end
				end
				if strict then
					local point_count = raw_owner_count(point.x, point.z)
					local cardinal_count, fourth = 0, nil
					for direction_index = 1, #cardinal do
						local direction = cardinal[direction_index]
						local nx = checked_coordinate(point.x, direction.x,
							context.bay.source.id .. " notch cardinal x")
						local nz = checked_coordinate(point.z, direction.z,
							context.bay.source.id .. " notch cardinal z")
						if raw_bay_water(context, nx, nz) then
							cardinal_count = cardinal_count + 1
						else
							fourth = {x = nx, z = nz}
						end
					end
					local diagonals_water = true
					for direction_index = 1, #diagonal do
						local direction = diagonal[direction_index]
						local nx = checked_coordinate(point.x, direction.x,
							context.bay.source.id .. " notch diagonal x")
						local nz = checked_coordinate(point.z, direction.z,
							context.bay.source.id .. " notch diagonal z")
						if not raw_bay_water(context, nx, nz) then
							diagonals_water = false break
						end
					end
					if point_count == 0 and cardinal_count == 3 and fourth and
							raw_owner_count(fourth.x, fourth.z) == 0 and diagonals_water then
						for direction_index = 1, #cardinal do
							local direction = cardinal[direction_index]
							local nx = checked_coordinate(point.x, direction.x,
								context.bay.source.id .. " notch owner x")
							local nz = checked_coordinate(point.z, direction.z,
								context.bay.source.id .. " notch owner z")
							if raw_bay_water(context, nx, nz) then
								local count, owner = raw_owner_count(nx, nz)
								if count ~= 1 or owner ~= context then
									fail("Bay notch has foreign or multiple cardinal water")
								end
							end
						end
						for direction_index = 1, #diagonal do
							local direction = diagonal[direction_index]
							local nx = checked_coordinate(point.x, direction.x,
								context.bay.source.id .. " notch owner x")
							local nz = checked_coordinate(point.z, direction.z,
								context.bay.source.id .. " notch owner z")
							local count, owner = raw_owner_count(nx, nz)
							if count ~= 1 or owner ~= context then
								fail("Bay notch has foreign or multiple diagonal water")
							end
						end
						local point_key = point.x .. ":" .. point.z
						if fill_owner[point_key] then
							fail("Bay notch qualifies for more than one Bay")
						end
						fill_owner[point_key], context.fill[point_key] = context, true
						context.fill_points[#context.fill_points + 1] =
							{x = point.x, z = point.z}
					end
				end
			end
		end

		local function bay_water(context, x, z)
			local point_key = x .. ":" .. z
			local cached = context.water_cache[point_key]
			if cached ~= nil then return cached end
			local water = raw_bay_water(context, x, z) or context.fill[point_key] == true
			context.water_cache[point_key] = water
			return water
		end

		local function planned_water(x, z, perimeter_equality)
			for bay_index = 1, #bays do
				local context = bay_context_by_id[bays[bay_index].source.id]
				if bay_water(context, x, z) then
					if not perimeter_equality or context.aperture.included[x .. ":" .. z] then
						return true
					end
				end
			end
			return false
		end

		local function dry_land(x, z)
			local class = footprint_class(x, z)
			if class < 0 then return false end
			return not planned_water(x, z, class == 0)
		end

		local function wing_water(context, wing, x, z)
			return exact.indexed_polygon_class(context.perimeter.polygon_index, x, z) > 0
				and exact.wing_member(x, z, wing)
		end

		local function bay_dry(context, x, z)
			local point_key = x .. ":" .. z
			local cached = context.dry_cache[point_key]
			if cached ~= nil then return cached end
			local class = exact.indexed_polygon_class(context.perimeter.polygon_index, x, z)
			local dry = class >= 0 and not planned_water(x, z, class == 0)
			context.dry_cache[point_key] = dry
			return dry
		end

		local function final_water(x, z)
			local class = footprint_class(x, z)
			return class >= 0 and planned_water(x, z, class == 0)
		end

		local function bay_candidate(context, x, z)
			local point_key = x .. ":" .. z
			local cached = context.candidate_cache[point_key]
			if cached ~= nil then return cached end
			local candidate = false
			if in_bay_envelope(context, x, z) then
				local own_water = false
				for index = 1, 4 do
					local direction = cardinal[index]
					if bay_water(context, x + direction.x, z + direction.z) then
						own_water = true break
					end
				end
				if own_water and bay_dry(context, x, z) then
					candidate = true
					for index = 1, 4 do
						local direction = cardinal[index]
						local nx, nz = x + direction.x, z + direction.z
						if final_water(nx, nz) and not bay_water(context, nx, nz) then
							candidate = false break
						end
					end
				end
			end
			context.candidate_cache[point_key] = candidate
			return candidate
		end

		local function water_on_right(context, current, following)
			local dx, dz = following.x - current.x, following.z - current.z
			for index = 1, 4 do
				local direction = cardinal[index]
				if bay_water(context, current.x + direction.x, current.z + direction.z) and
						exact.cross(dx, dz, direction.x, direction.z,
							"Bay-bank water side") < 0 then return true end
			end
			return false
		end
		local function validate_all_junction_pairs(stage)
			local junction_pair_count = 0
			for junction_index = 1, #source.relief_junctions do
				local junction = source.relief_junctions[junction_index]
				local incident = junction.incident_edge_ids
				for left_index = 1, #incident - 1 do
					local left = edge_by_id[incident[left_index]]
					if not left then fail(junction.id .. " lacks an incident edge") end
					for right_index = left_index + 1, #incident do
						local right = edge_by_id[incident[right_index]]
						if not right then fail(junction.id .. " lacks an incident edge") end
						validate_junction_pair(junction.position, left.stations,
							right.stations, stage .. " " .. junction.id .. " " ..
								left.id .. "/" .. right.id)
						junction_pair_count = junction_pair_count + 1
					end
				end
			end
			if #source.relief_junctions ~= 38 or junction_pair_count ~= 102 then
				fail(stage .. " junction gate did not cover 38/102")
			end
			return junction_pair_count
		end
		-- Binding R13 proof for the seed-selected R7/effective-control rasters.
		-- Partition clipping and attachment rerastering are later topology stages.
		validate_all_junction_pairs("selected-r7")
		local attachment_by_edge = {}
		for index = 1, #source.perimeter_attachments do
			attachment_by_edge[source.perimeter_attachments[index].edge_id] =
				source.perimeter_attachments[index]
		end
		local function land_transition_key(edge_id, endpoint)
			return "land_edge_transition:" .. edge_id .. ":" .. endpoint
		end
		local declared_transition_by_key, transitions_by_edge = {}, {}
		local projected_incidence = {}
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			for _, terminal in ipairs({bank.start_terminal, bank.end_terminal}) do
				if terminal.kind == "land_edge_transition" then
					local transition_key = land_transition_key(terminal.edge_id,
						terminal.edge_endpoint)
					local rows = projected_incidence[transition_key] or {}
					projected_incidence[transition_key] = rows
					rows[#rows + 1] = bank.id
				end
			end
		end
		if dense(source.bay_edge_transitions, "Bay edge transitions") ~= 8 then
			fail("Bay edge transition roster must contain eight rows")
		end
		for transition_index = 1, #source.bay_edge_transitions do
			local row = source.bay_edge_transitions[transition_index]
			if type(row) ~= "table" or getmetatable(row) ~= nil or
					type(row.id) ~= "string" or type(row.bay_id) ~= "string" or
					type(row.edge_id) ~= "string" or
					(row.edge_endpoint ~= "from" and row.edge_endpoint ~= "to") or
					row.resolution_policy_id ~=
						"direct_candidate_or_same_bay_diagonal_elbow_v1" or
					row.candidate_tie_rule ~= "lexicographically_least_x_then_z" or
					dense(row.incident_bank_component_ids,
						row.id .. " incident Banks") ~= 2 then
				fail("malformed Bay edge transition row")
			end
			local transition_key = land_transition_key(row.edge_id, row.edge_endpoint)
			if declared_transition_by_key[transition_key] then
				fail(row.id .. " duplicates a Bay edge transition endpoint")
			end
			local incident = projected_incidence[transition_key]
			if not incident or #incident ~= 2 or
					incident[1] ~= row.incident_bank_component_ids[1] or
					incident[2] ~= row.incident_bank_component_ids[2] then
				fail(row.id .. " does not match its two incident Banks")
			end
			declared_transition_by_key[transition_key] = row
			local edge_rows = transitions_by_edge[row.edge_id] or {}
			transitions_by_edge[row.edge_id] = edge_rows
			edge_rows[#edge_rows + 1] = row
		end
		for transition_key in pairs(projected_incidence) do
			if not declared_transition_by_key[transition_key] then
				fail(transition_key .. " lacks a declared Bay edge transition")
			end
		end

		local resolved_transition_by_key, transition_by_edge = {}, {}
		local function resolve_edge_transition(row, edge, retained)
			local context = bay_context_by_id[row.bay_id]
			if not context then fail(row.id .. " references an absent Bay") end
			local e_index = row.edge_endpoint == "from" and retained[1] or
				retained[#retained]
			local e = edge.stations[e_index]
			local evidence = {id = row.id, e = {x = e.x, z = e.z},
				direct_candidate = bay_candidate(context, e.x, e.z)}
			if not evidence.direct_candidate then
				evidence.e_strict_dry = footprint_class(e.x, e.z) == 1 and
					bay_dry(context, e.x, e.z)
				evidence.e_cardinal_water = false
				for direction_index = 1, #cardinal do
					local direction = cardinal[direction_index]
					if final_water(e.x + direction.x, e.z + direction.z) then
						evidence.e_cardinal_water = true break
					end
				end
				local w_index = row.edge_endpoint == "from" and e_index - 1 or e_index + 1
				local w = edge.stations[w_index]
				if not w then fail(row.id .. " lacks an immediate discarded W") end
				evidence.w = {x = w.x, z = w.z}
				evidence.w_owned_by_bay = transition_water_owned(
					final_water(w.x, w.z), bay_water(context, w.x, w.z))
				evidence.w_foreign_water = false
				for bay_id, other_context in pairs(bay_context_by_id) do
					if bay_id ~= row.bay_id and bay_water(other_context, w.x, w.z) then
						evidence.w_foreign_water = true break
					end
				end
				local elbows = {{x = w.x, z = e.z}, {x = e.x, z = w.z}}
				evidence.elbow_valid = {}
				for elbow_index = 1, 2 do
					local elbow = elbows[elbow_index]
					exact.point(elbow, row.id .. " elbow")
					evidence.elbow_valid[elbow_index] =
						footprint_class(elbow.x, elbow.z) == 1 and
							bay_dry(context, elbow.x, elbow.z) and
							bay_candidate(context, elbow.x, elbow.z)
				end
			end
			local selected = select_edge_transition(evidence)
			local resolved = {source = row, e = {x = e.x, z = e.z},
				point = selected.point, mode = selected.mode,
				w = selected.w, elbows = selected.elbows, selection = selected}
			return resolved
		end
		local attachment_result = {}
		for index = 1, #provisional_edges do
			local edge = provisional_edges[index]
			local attachment = attachment_by_edge[edge.id]
			local edge_transitions = transitions_by_edge[edge.id]
			local retained = {}
			for station_index = 1, #edge.stations do
				if dry_land(edge.stations[station_index].x, edge.stations[station_index].z) then
					retained[#retained + 1] = station_index
				end
			end
			if #retained == 0 then fail(edge.id .. " has no retained land run") end
			for retained_index = 2, #retained do
				if retained[retained_index] ~= retained[retained_index - 1] + 1 then
					fail(edge.id .. " has a second retained land run")
				end
			end
			local controls = {}
			local from_transition, to_transition
			if edge_transitions then
				for transition_index = 1, #edge_transitions do
					local transition = resolve_edge_transition(edge_transitions[transition_index],
						edge, retained)
					if transition.source.edge_endpoint == "from" then
						if from_transition then fail(edge.id .. " has two from transitions") end
						from_transition = transition
					else
						if to_transition then fail(edge.id .. " has two to transitions") end
						to_transition = transition
					end
				end
			end
			if attachment and ((attachment.edge_endpoint == "from" and from_transition) or
					(attachment.edge_endpoint == "to" and to_transition)) then
				fail(edge.id .. " mixes Attachment and transition at one endpoint")
			end
			local function retain_resolved_transition(transition)
				if not transition then return end
				local endpoint_index = transition.source.edge_endpoint == "from" and
					1 or #edge.stations
				local away_index = transition.source.edge_endpoint == "from" and
					2 or #edge.stations - 1
				if key(edge.stations[endpoint_index]) ~= key(transition.point) then
					fail(transition.source.id .. " changed during sole final reraster")
				end
				transition.previous = {x = edge.stations[away_index].x,
					z = edge.stations[away_index].z}
				local transition_key = land_transition_key(edge.id,
					transition.source.edge_endpoint)
				resolved_transition_by_key[transition_key] = transition
				local rows = transition_by_edge[edge.id] or {}
				transition_by_edge[edge.id] = rows
				rows[#rows + 1] = {id = transition_key,
					bay_id = transition.source.bay_id,
					endpoint = transition.source.edge_endpoint,
					point = {x = transition.point.x, z = transition.point.z}, offset = 0}
			end
			if attachment then
				local e_index = attachment.retained_run == "suffix" and retained[1] or
					retained[#retained]
				local e = edge.stations[e_index]
				local perimeter = perimeter_by_id[attachment.perimeter_id]
				local candidates = perimeter.segment_parts[attachment.perimeter_segment_index]
				local canonical_indices = {}
				for station_index = 1, #perimeter.canonical_stations do
					canonical_indices[key(perimeter.canonical_stations[station_index])] = station_index
				end
				local best, best_distance, best_index = select_attachment_station(e,
					candidates, canonical_indices)
				local retained_controls = {}
				for control_index = 1, #edge.shifted_controls do
					local point = edge.shifted_controls[control_index]
					if dry_land(point.x, point.z) then
						retained_controls[#retained_controls + 1] = control_index
					end
				end
				if #retained_controls == 0 then
					fail(attachment.id .. " has no retained controls")
				end
				for retained_index = 2, #retained_controls do
					if retained_controls[retained_index] ~=
							retained_controls[retained_index - 1] + 1 then
						fail(attachment.id .. " retained controls form a second run")
					end
				end
				local opposite
				if attachment.edge_endpoint == "from" then
					if attachment.retained_run ~= "suffix" then
						fail(attachment.id .. " endpoint/run declaration disagrees")
					end
					controls[1] = {x = best.x, z = best.z}
					for retained_index = 1, #retained_controls do
						local point = edge.shifted_controls[retained_controls[retained_index]]
						controls[#controls + 1] = {x = point.x, z = point.z}
					end
					opposite = edge.stations[retained[#retained]]
					controls[#controls + 1] = {x = opposite.x, z = opposite.z}
					controls = add_edge_transition_control(controls,
						to_transition and to_transition.selection, "to", opposite)
				else
					if attachment.edge_endpoint ~= "to" or
							attachment.retained_run ~= "prefix" then
						fail(attachment.id .. " endpoint/run declaration disagrees")
					end
					opposite = edge.stations[retained[1]]
					controls[1] = {x = opposite.x, z = opposite.z}
					for retained_index = 1, #retained_controls do
						local point = edge.shifted_controls[retained_controls[retained_index]]
						controls[#controls + 1] = {x = point.x, z = point.z}
					end
					controls[#controls + 1] = {x = best.x, z = best.z}
					controls = add_edge_transition_control(controls,
						from_transition and from_transition.selection, "from", opposite)
				end
				edge.stations = raster.final_raster(controls, false)
				local terminal = attachment.edge_endpoint == "from" and
					edge.stations[1] or edge.stations[#edge.stations]
				if key(terminal) ~= key(best) then
					fail(attachment.id .. " A is not the exact final terminal")
				end
				local other_terminal = attachment.edge_endpoint == "from" and
					edge.stations[#edge.stations] or edge.stations[1]
				local opposite_transition = attachment.edge_endpoint == "from" and
					to_transition or from_transition
				local expected_other_terminal = opposite_transition and
					opposite_transition.point or opposite
				if key(other_terminal) ~= key(expected_other_terminal) then
					fail(attachment.id ..
						" opposite resolved terminal changed during reraster")
				end
				raster.validate_final({id = edge.id, kind = "land_edge", closed = false,
					max_displacement = edge.source.max_displacement},
					edge.base_stations, edge.stations)
				for station_index = 1, #edge.stations do
					if key(edge.stations[station_index]) ~= key(best) then
						local class = footprint_class(edge.stations[station_index].x,
							edge.stations[station_index].z)
						if class ~= 1 or planned_water(edge.stations[station_index].x,
								edge.stations[station_index].z, false) then
							fail(attachment.id .. " has a non-strict-interior station")
						end
					end
					if station_index > 1 then
						local previous = edge.stations[station_index - 1]
						local dx = math.abs(previous.x - edge.stations[station_index].x)
						local dz = math.abs(previous.z - edge.stations[station_index].z)
						if math.max(dx, dz) ~= 1 then
							fail(attachment.id .. " final raster is not eight-connected")
						end
					end
				end
				attachment_result[attachment.id] = {source = attachment, e = e,
					a = best, distance = best_distance, canonical_index = best_index}
				retain_resolved_transition(from_transition)
				retain_resolved_transition(to_transition)
			else
				local first_e = edge.stations[retained[1]]
				for station_index = retained[1], retained[#retained] do
					controls[#controls + 1] = {x = edge.stations[station_index].x,
						z = edge.stations[station_index].z}
				end
				local last_e = edge.stations[retained[#retained]]
				controls = add_edge_transition_control(controls,
					from_transition and from_transition.selection, "from", first_e)
				controls = add_edge_transition_control(controls,
					to_transition and to_transition.selection, "to", last_e)
				if edge_transitions then
					edge.stations = raster.final_raster(controls, false)
					raster.validate_final({id = edge.id, kind = "land_edge", closed = false,
						max_displacement = edge.source.max_displacement},
						edge.base_stations, edge.stations)
					retain_resolved_transition(from_transition)
					retain_resolved_transition(to_transition)
				else
					edge.stations = controls
				end
			end
			if #edge.stations - 1 < 192 then fail(edge.id .. " final raster is shorter than 192") end
		end
		local resolved_transition_count = 0
		for transition_key in pairs(declared_transition_by_key) do
			if not resolved_transition_by_key[transition_key] then
				fail(transition_key .. " was not materialized by its final edge")
			end
			resolved_transition_count = resolved_transition_count + 1
		end
		if resolved_transition_count ~= 8 then
			fail("final Bay edge transition roster does not contain eight rows")
		end
		local span_by_id = {}
		for index = 1, #source.perimeter_spans do
			local span = source.perimeter_spans[index]
			local perimeter = perimeter_by_id[span.perimeter_id]
			local first_point = span.start_boundary.kind == "perimeter_attachment" and
				attachment_result[span.start_boundary.attachment_id].a or
				perimeter.source.polygon[span.start_boundary.index]
			local last_point = span.end_boundary.kind == "perimeter_attachment" and
				attachment_result[span.end_boundary.attachment_id].a or
				perimeter.source.polygon[span.end_boundary.index]
			local points = {}
			local collecting = false
			for station_index = 1, #perimeter.stations do
				local point = perimeter.stations[station_index]
				if key(point) == key(first_point) then collecting = true end
				if collecting then points[#points + 1] = point end
				if collecting and key(point) == key(last_point) then break end
			end
			if #points == 0 or key(points[#points]) ~= key(last_point) then
				fail(span.id .. " final endpoints are absent")
			end
			if span.face_direction == "reverse" then points = reverse_points(points) end
			span_by_id[span.id] = {source = span, stations = points}
		end

		local clockwise = {{x = 1, z = 0}, {x = 1, z = -1},
			{x = 0, z = -1}, {x = -1, z = -1}, {x = -1, z = 0},
			{x = -1, z = 1}, {x = 0, z = 1}, {x = 1, z = 1}}

		local function sequence_less(a, b)
			local count = math.min(#a, #b)
			for index = 1, count do
				if point_less(a[index], b[index]) then return true end
				if point_less(b[index], a[index]) then return false end
			end
			return #a < #b
		end

		local function chebyshev(a, b)
			return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
		end

		local function diagonal_signature(a, b)
			local dx, dz = b.x - a.x, b.z - a.z
			if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 then return nil end
			return math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z),
				dx == dz and 1 or -1
		end

		local function add_diagonal(diagonals, a, b)
			local cell, slope = diagonal_signature(a, b)
			if not cell then return nil end
			if diagonals[cell] and diagonals[cell] ~= slope then return false end
			if not diagonals[cell] then diagonals[cell] = slope return cell end
			return nil
		end

		local function wing_terms(wing, point)
			local vx = exact.safe_difference(wing.junction.x, wing.head.x,
				wing.id .. " axis")
			local vz = exact.safe_difference(wing.junction.z, wing.head.z,
				wing.id .. " axis")
			local px = exact.safe_difference(point.x, wing.head.x,
				wing.id .. " query")
			local pz = exact.safe_difference(point.z, wing.head.z,
				wing.id .. " query")
			local length = exact.safe_sum(exact.safe_square(vx, wing.id .. " length"),
				exact.safe_square(vz, wing.id .. " length"), wing.id .. " length")
			local projection = exact.dot(px, pz, vx, vz, wing.id .. " projection")
			local determinant = exact.cross(vx, vz, px, pz, wing.id .. " cross")
			return projection, determinant, length
		end

		-- The R12 caps count the finite search envelope itself, not its larger
		-- outer rectangle: exact union of expanded Base/Wing boxes, clipped to
		-- the referenced final mainland footprint.
		for bay_index = 1, #bays do
			local context = bay_context_by_id[bays[bay_index].source.id]
			local column_count = count_trace_envelope(context.boxes,
				context.perimeter.polygon_index, context.bay.source.id)
			context.step_bound = column_count
			context.trace_bounds = trace_bounds(column_count)
		end

		local wing_tail_by_id = {}
		for wing_index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[wing_index]
			local context = bay_context_by_id[wing.bay_id]
			local radius = wing.head_half_width
			local box = {min_x = math.min(wing.head.x, wing.junction.x) - radius,
				max_x = math.max(wing.head.x, wing.junction.x) + radius,
				min_z = math.min(wing.head.z, wing.junction.z) - radius,
				max_z = math.max(wing.head.z, wing.junction.z) + radius}
			local selected = {}
			for _, side in ipairs({"negative", "positive"}) do
				local best, best_projection
				for x = box.min_x, box.max_x do
					for z = box.min_z, box.max_z do
						local own_neighbor = false
						for direction_index = 1, 4 do
							local direction = cardinal[direction_index]
							if wing_water(context, wing, x + direction.x,
									z + direction.z) then own_neighbor = true break end
						end
						if own_neighbor and bay_dry(context, x, z) then
							local point = {x = x, z = z}
							local projection, determinant, length = wing_terms(wing, point)
							local signed = side == "negative" and determinant < 0 or
								side == "positive" and determinant > 0
							if projection >= 0 and projection < length and signed and
									(not best or projection > best_projection or
									projection == best_projection and point_less(point, best)) then
								best, best_projection = point, projection
							end
						end
					end
				end
				if not best then fail(wing.id .. " has no " .. side .. " K") end
				if chebyshev(best, wing.junction) > 4 then
					fail(wing.id .. " " .. side .. " K exceeds current bound")
				end
				selected[side] = best
			end

			local paths = {negative = {}, positive = {}}
			local function collect_paths(side, path)
				local current = path[#path]
				if current.x == wing.junction.x and current.z == wing.junction.z then
					local copy = copy_points(path)
					paths[side][#paths[side] + 1] = copy
					return
				end
				local distance = chebyshev(current, wing.junction)
				local next_points = {}
				for dx = -1, 1 do for dz = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local following = {x = current.x + dx, z = current.z + dz}
						if chebyshev(following, wing.junction) == distance - 1 then
							local _, determinant = wing_terms(wing, following)
							local at_junction = key(following) == key(wing.junction)
							local strict_side = side == "negative" and determinant < 0 or
								side == "positive" and determinant > 0
							if bay_dry(context, following.x, following.z) and
									(at_junction or strict_side) then
								next_points[#next_points + 1] = following
							end
						end
					end
				end end
				table.sort(next_points, point_less)
				for index = 1, #next_points do
					path[#path + 1] = next_points[index]
					collect_paths(side, path)
					path[#path] = nil
				end
			end
			collect_paths("negative", {{x = selected.negative.x, z = selected.negative.z}})
			collect_paths("positive", {{x = selected.positive.x, z = selected.positive.z}})
			for _, side in ipairs({"negative", "positive"}) do
				table.sort(paths[side], sequence_less)
				if #paths[side] == 0 then fail(wing.id .. " lacks a complete " .. side .. " tail") end
			end

			local function tail_diagonals(path)
				local diagonals = {}
				for index = 1, #path - 1 do
					if add_diagonal(diagonals, path[index], path[index + 1]) == false then
						return nil
					end
				end
				return diagonals
			end
			local function wedge_valid(negative, positive)
				local polygon = copy_points(negative)
				for index = #positive - 1, 1, -1 do
					polygon[#polygon + 1] = {x = positive[index].x, z = positive[index].z}
				end
				polygon[#polygon + 1] = {x = polygon[1].x, z = polygon[1].z}
				if exact.signed_area2(polygon) == 0 or not exact.polygon_simple(polygon) then
					return false
				end
				local radius = 1 + math.max(chebyshev(negative[1], wing.junction),
					chebyshev(positive[1], wing.junction))
				if radius > 5 then return false end
				local exempt = {}
				for index = 1, #negative do exempt[key(negative[index])] = true end
				for index = 1, #positive do exempt[key(positive[index])] = true end
				for x = wing.junction.x - radius, wing.junction.x + radius do
					for z = wing.junction.z - radius, wing.junction.z + radius do
						if exact.polygon_class(x, z, polygon) >= 0 and
								not exempt[x .. ":" .. z] and
								not wing_water(context, wing, x, z) then return false end
					end
				end
				return true
			end
			local chosen_negative, chosen_positive
			for negative_index = 1, #paths.negative do
				local negative = paths.negative[negative_index]
				local negative_diagonals = tail_diagonals(negative)
				if negative_diagonals then
					local negative_points = {}
					for index = 1, #negative - 1 do negative_points[key(negative[index])] = true end
					for positive_index = 1, #paths.positive do
						local positive = paths.positive[positive_index]
						local valid = key(negative[#negative - 1]) ~=
							key(positive[#positive - 1])
						local diagonals = {}
						for cell, slope in pairs(negative_diagonals) do diagonals[cell] = slope end
						for index = 1, #positive - 1 do
							if negative_points[key(positive[index])] then valid = false break end
							if add_diagonal(diagonals, positive[index], positive[index + 1]) == false then
								valid = false break
							end
						end
						if valid and wedge_valid(negative, positive) then
							chosen_negative, chosen_positive = negative, positive
							break
						end
					end
				end
				if chosen_negative then break end
			end
			if not chosen_negative then fail(wing.id .. " has no wedge-valid joint tail pair") end
			local length = select(3, wing_terms(wing, wing.junction))
			local path_bound = exact.ceil_isqrt(length) + 1
			if #chosen_negative > path_bound or #chosen_positive > path_bound then
				fail(wing.id .. " joint tail exceeds finite path bound")
			end
			wing_tail_by_id[wing.id] = {negative = chosen_negative,
				positive = chosen_positive, negative_k = selected.negative,
				positive_k = selected.positive}
		end

		local function terminal_key(terminal)
			if terminal.kind == "aperture_dry" then
				return terminal.kind .. ":" .. terminal.aperture_id .. ":" .. terminal.side
			elseif terminal.kind == "land_edge_transition" then
				return terminal.kind .. ":" .. terminal.edge_id .. ":" ..
					terminal.edge_endpoint
			end
			return terminal.kind .. ":" .. terminal.wing_id .. ":" .. terminal.tail_side
		end

		local terminal_cache = {}
		local function resolve_terminal(terminal, bay_id)
			local cache_key = terminal_key(terminal)
			local cached = terminal_cache[cache_key]
			if cached then
				if bay_id and cached.bay_id ~= bay_id then
					fail(cache_key .. " reused by a foreign Bay")
				end
				return cached
			end
			local resolved = {id = cache_key, bay_id = bay_id}
			if terminal.kind == "aperture_dry" then
				local aperture = aperture_by_id[terminal.aperture_id]
				if not aperture then fail(cache_key .. " references an absent aperture") end
				resolved.bay_id = aperture.source.bay_id
				local perimeter = perimeter_by_id[aperture.source.perimeter_id]
				local point_index, away_index
				if terminal.side == "before" then
					point_index = aperture.bank_first - 1
					away_index = point_index - 1
				else
					point_index = aperture.bank_finish
					away_index = point_index + 1
				end
				if away_index < 1 or away_index > #perimeter.stations then
					fail(cache_key .. " authored away station is absent")
				end
				resolved.point = copy_points({perimeter.stations[point_index]})[1]
				resolved.previous = copy_points({perimeter.stations[away_index]})[1]
				resolved.aperture_id = terminal.aperture_id
				resolved.aperture_side = terminal.side
				resolved.authored_index = point_index - 1
				resolved.authored_away_index = away_index - 1
			elseif terminal.kind == "land_edge_transition" then
				local materialized = resolved_transition_by_key[cache_key]
				if not materialized then
					fail(cache_key .. " lacks a once-resolved final edge transition")
				end
				resolved.bay_id = materialized.source.bay_id
				resolved.point = {x = materialized.point.x, z = materialized.point.z}
				resolved.previous = {x = materialized.previous.x,
					z = materialized.previous.z}
				resolved.edge_id = terminal.edge_id
				resolved.edge_endpoint = terminal.edge_endpoint
				resolved.transition_id = materialized.source.id
			elseif terminal.kind == "wing_junction_tail_side" then
				local wing = wing_by_id[terminal.wing_id]
				local tails = wing_tail_by_id[terminal.wing_id]
				if not wing or not tails then fail(cache_key .. " references an absent Wing tail") end
				resolved.bay_id = wing.bay_id
				resolved.point = {x = wing.junction.x, z = wing.junction.z}
				resolved.tail = tails[terminal.tail_side]
				resolved.k = terminal.tail_side == "negative" and tails.negative_k or
					tails.positive_k
			else
				fail(cache_key .. " has an unknown terminal kind")
			end
			if bay_id and resolved.bay_id ~= bay_id then fail(cache_key .. " has the wrong Bay") end
			terminal_cache[cache_key] = resolved
			return resolved
		end

		local function state_key(previous, current)
			return key(previous) .. ">" .. key(current)
		end

		local function ordered_successors(context, previous, current, seen_states,
				seen_columns, diagonals)
			local back_x, back_z = previous.x - current.x, previous.z - current.z
			local back_index
			for index = 1, 8 do
				if clockwise[index].x == back_x and clockwise[index].z == back_z then
					back_index = index break
				end
			end
			if not back_index then fail("Bay-bank start half-edge is not eight-connected") end
			local result = {}
			for offset = 1, 8 do
				local direction_index = ((back_index - offset - 1) % 8) + 1
				local direction = clockwise[direction_index]
				local following = {x = current.x + direction.x, z = current.z + direction.z}
				local following_key = key(following)
				local directed_key = state_key(current, following)
				local cell, slope = diagonal_signature(current, following)
				if following_key ~= key(previous) and not seen_states[directed_key] and
						not seen_columns[following_key] and
						(not cell or not diagonals[cell] or diagonals[cell] == slope) and
						bay_candidate(context, following.x, following.z) and
						water_on_right(context, current, following) then
					result[#result + 1] = following
				end
			end
			return result
		end

		local function reachable(context, previous, current, target, base_states,
				base_columns, base_diagonals)
			local seen_states, seen_columns, diagonals = {}, {}, {}
			for value in pairs(base_states) do seen_states[value] = true end
			for value in pairs(base_columns) do seen_columns[value] = true end
			for cell, slope in pairs(base_diagonals) do diagonals[cell] = slope end
			local first_state, first_column = state_key(previous, current), key(current)
			if seen_states[first_state] or seen_columns[first_column] then return false end
			seen_states[first_state], seen_columns[first_column] = true, true
			local first_cell = add_diagonal(diagonals, previous, current)
			if first_cell == false then return false end
			local stack = {{previous = previous, current = current,
				state = first_state, column = first_column, diagonal = first_cell}}
			local pushed_frames = 1
			while #stack > 0 do
				local frame = stack[#stack]
				if key(frame.current) == key(target) then return true end
				validate_trace_counters(context.trace_bounds, pushed_frames, #stack, nil)
				if not frame.successors then
					frame.successors = ordered_successors(context, frame.previous,
						frame.current, seen_states, seen_columns, diagonals)
					frame.next = 1
				end
				local following = frame.successors[frame.next]
				if following then
					frame.next = frame.next + 1
					local directed_key = state_key(frame.current, following)
					local column_key = key(following)
					seen_states[directed_key], seen_columns[column_key] = true, true
					local cell = add_diagonal(diagonals, frame.current, following)
					stack[#stack + 1] = {previous = frame.current, current = following,
						state = directed_key, column = column_key, diagonal = cell}
					pushed_frames = exact.safe_sum(pushed_frames, 1,
						context.bay.source.id .. " reachability frame count")
					validate_trace_counters(context.trace_bounds, pushed_frames,
						#stack, nil)
				else
					seen_states[frame.state], seen_columns[frame.column] = nil, nil
					if frame.diagonal then diagonals[frame.diagonal] = nil end
					stack[#stack] = nil
				end
			end
			return false
		end

		local bank_by_id = {}
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			local context = bay_context_by_id[bank.bay_id]
			local start = resolve_terminal(bank.start_terminal, bank.bay_id)
			local finish = resolve_terminal(bank.end_terminal, bank.bay_id)
			local points, seen_states, seen_columns, diagonals = {}, {}, {}, {}
			local previous, current, target, suffix
			if bank.start_terminal.kind == "wing_junction_tail_side" then
				if bank.start_terminal.tail_side ~= "negative" then
					fail(bank.id .. " has a nonnegative Wing start")
				end
				local prefix = reverse_points(start.tail)
				for index = 1, #prefix do
					local point = prefix[index]
					if seen_columns[key(point)] then fail(bank.id .. " repeats a joint-tail column") end
					if index > 1 then
						local cell = add_diagonal(diagonals, prefix[index - 1], point)
						if cell == false then fail(bank.id .. " joint tail X-crosses") end
						seen_states[state_key(prefix[index - 1], point)] = true
					end
					points[#points + 1] = {x = point.x, z = point.z}
					seen_columns[key(point)] = true
				end
				previous, current = points[#points - 1], points[#points]
			else
				previous = start.previous
				current = {x = start.point.x, z = start.point.z}
				points[1] = {x = current.x, z = current.z}
				seen_columns[key(current)] = true
				seen_states[state_key(previous, current)] = true
			end
			if bank.end_terminal.kind == "wing_junction_tail_side" then
				if bank.end_terminal.tail_side ~= "positive" then
					fail(bank.id .. " has a nonpositive Wing end")
				end
				target, suffix = finish.k, finish.tail
			else
				target = finish.point
			end
			local start_distance = chebyshev(previous, current)
			local start_candidate = bay_candidate(context, current.x, current.z)
			if start_distance ~= 1 or not start_candidate then
				local own_bits, foreign_bits = {}, {}
				for direction_index = 1, #cardinal do
					local direction = cardinal[direction_index]
					local nx, nz = current.x + direction.x, current.z + direction.z
					local own = bay_water(context, nx, nz)
					own_bits[direction_index] = own and "1" or "0"
					foreign_bits[direction_index] = final_water(nx, nz) and not own and
						"1" or "0"
				end
				local current_key = key(current)
				local aperture = aperture_by_bay[bank.bay_id]
				fail(bank.id .. " has an invalid start half-edge distance=" ..
					start_distance .. " candidate=" .. tostring(start_candidate) .. " " ..
					key(previous) .. "->" .. key(current) .. " target=" .. key(target) ..
					" end=" .. tostring(finish.aperture_id or finish.edge_id or
						finish.id) .. ":" .. tostring(finish.aperture_side or
						finish.edge_endpoint or "") .. " authored=" ..
					tostring(finish.authored_index) .. "/" ..
					tostring(finish.authored_away_index) .. " own_ESWN=" ..
					table.concat(own_bits) .. " foreign_ESWN=" ..
					table.concat(foreign_bits) .. " envelope=" ..
					tostring(in_bay_envelope(context, current.x, current.z)) ..
					" dry=" .. tostring(bay_dry(context, current.x, current.z)) ..
					" footprint=" .. tostring(footprint_class(current.x, current.z)) ..
					" aperture=" .. tostring(aperture.included[current_key] == true))
			end
			if not bay_candidate(context, target.x, target.z) then
				fail(bank.id .. " has a noncandidate target")
			end
			local steps = 0
			while key(current) ~= key(target) do
				local successors = ordered_successors(context, previous, current,
					seen_states, seen_columns, diagonals)
				local following
				if #successors == 1 then
					following = successors[1]
				elseif #successors > 1 then
					following = select_first_reachable(successors, function(successor)
						return reachable(context, current, successor, target,
							seen_states, seen_columns, diagonals)
					end)
				end
				if not following then fail(bank.id .. " cannot reach its target") end
				local directed_key = state_key(current, following)
				local cell = add_diagonal(diagonals, current, following)
				if cell == false then fail(bank.id .. " X-crosses") end
				seen_states[directed_key], seen_columns[key(following)] = true, true
				points[#points + 1] = {x = following.x, z = following.z}
				previous, current = current, following
				steps = steps + 1
				validate_trace_counters(context.trace_bounds, nil, nil, steps)
			end
			if suffix then
				for index = 2, #suffix do
					local following = suffix[index]
					if seen_columns[key(following)] then
						fail(bank.id .. " repeats a positive joint-tail column")
					end
					local cell = add_diagonal(diagonals, points[#points], following)
					if cell == false then fail(bank.id .. " positive joint tail X-crosses") end
					seen_columns[key(following)] = true
					points[#points + 1] = {x = following.x, z = following.z}
				end
			end
			bank_by_id[bank.id] = {source = bank, stations = points}
		end

		-- Every declared incident Bank consumes the one materialized terminal;
		-- no Bank is permitted to scan or resolve the edge a second time.
		local transition_consumers = {}
		for _, bank in ipairs(source.bay_bank_components) do
			for terminal_index, terminal in ipairs({bank.start_terminal,
					bank.end_terminal}) do
				if terminal.kind == "land_edge_transition" then
					local resolved = resolve_terminal(terminal, bank.bay_id)
					local edge = edge_by_id[terminal.edge_id]
					local first = terminal.edge_endpoint == "from" and 1 or #edge.stations
					if key(edge.stations[first]) ~= key(resolved.point) then
						fail(resolved.id .. " is not the final edge endpoint")
					end
					local bank_points = bank_by_id[bank.id].stations
					local bank_terminal = terminal_index == 1 and bank_points[1] or
						bank_points[#bank_points]
					if key(bank_terminal) ~= key(resolved.point) then
						fail(resolved.id .. " is not the incident Bank endpoint")
					end
					local consumers = transition_consumers[resolved.id] or {}
					transition_consumers[resolved.id] = consumers
					consumers[#consumers + 1] = bank.id
				end
			end
		end
		for transition_key, row in pairs(declared_transition_by_key) do
			local consumers = transition_consumers[transition_key]
			if not consumers or #consumers ~= 2 or
					consumers[1] ~= row.incident_bank_component_ids[1] or
					consumers[2] ~= row.incident_bank_component_ids[2] then
				fail(row.id .. " was not consumed by its two ordered incident Banks")
			end
		end

		local function component_span(component)
			local full = span_by_id[component.ref_id].stations
			local first_point = component.from_terminal ~= false and
				resolve_terminal(component.from_terminal).point or full[1]
			local last_point = component.to_terminal ~= false and
				resolve_terminal(component.to_terminal).point or full[#full]
			local first_index, last_index
			for index = 1, #full do
				if not first_index and key(full[index]) == key(first_point) then first_index = index end
				if key(full[index]) == key(last_point) then last_index = index end
			end
			if not first_index or not last_index or first_index > last_index then
				fail(component.ref_id .. " terminal-trimmed span is absent")
			end
			local points = {}
			for index = first_index, last_index do
				points[#points + 1] = {x = full[index].x, z = full[index].z}
			end
			return points
		end

		local arc_by_id = {}
		for index = 1, #source.face_arcs do
			local arc = source.face_arcs[index]
			local points, bank_ids = {}, {}
			for component_index = 1, #arc.authority_components do
				local component = arc.authority_components[component_index]
				local part
				if component.kind == "perimeter_span" then
					part = component_span(component)
				elseif component.kind == "bay_bank" then
					part = copy_points(bank_by_id[component.ref_id].stations)
					bank_ids[#bank_ids + 1] = component.ref_id
				elseif component.boundary_role == "island_coast" then
					part = copy_points(island_by_id[component.source_ref].stations)
					part[#part + 1] = {x = part[1].x, z = part[1].z}
				else
					part = raster.final_raster(component.control, false)
				end
				if #points > 0 and key(points[#points]) ~= key(part[1]) then
					fail(arc.id .. " authority components do not join")
				end
				append_points(points, part)
			end
			arc_by_id[arc.id] = {source = arc, stations = points,
				bank_component_ids = bank_ids}
		end
		-- Coast payloads retain a deduplicated ring.  Faces and serialized coast
		-- records each add their one terminal copy at their own closed boundary.
		local coast_component_by_id = {}
		for id, span in pairs(span_by_id) do
			coast_component_by_id[id] = {source = span.source,
				stations = copy_points(span.stations), closed = false}
		end
		for id, arc in pairs(arc_by_id) do
			if id ~= "face_arc:wyrmglass:island" and
					id ~= "face_arc:stormscale:island" then
				coast_component_by_id[id] = {source = arc.source,
					stations = copy_points(arc.stations), closed = false}
			end
		end
		for _, id in ipairs({"face_arc:wyrmglass:island",
				"face_arc:stormscale:island"}) do
			local arc = arc_by_id[id]
			local island = island_by_id[arc.source.source_refs[1]]
			coast_component_by_id[id] = {source = arc.source,
				stations = copy_points(island.stations), closed = true}
		end
		local face_rows = {}
		for index = 1, #source.zone_faces do
			local face = source.zone_faces[index]
			local polygon, face_bank_ids = {}, {}
			for cycle_index = 1, #face.cycle do
				local component = face.cycle[cycle_index]
				local points = component.kind == "shared_edge" and
					edge_by_id[component.ref_id].stations or arc_by_id[component.ref_id].stations
				if component.kind ~= "shared_edge" then
					local arc = arc_by_id[component.ref_id]
					for bank_index = 1, #arc.bank_component_ids do
						face_bank_ids[#face_bank_ids + 1] = arc.bank_component_ids[bank_index]
					end
				end
				if component.direction == "reverse" then points = reverse_points(points) end
				if #polygon > 0 and key(polygon[#polygon]) ~= key(points[1]) then
					fail(face.id .. " component graph does not join")
				end
				append_points(polygon, points)
			end
			validate_face_polygon(face.id, polygon)
			face_rows[#face_rows + 1] = {source = face, polygon = polygon,
				bank_component_ids = face_bank_ids}
		end
		local families = {land_boundaries = {}, perimeters = {}, bays = {},
			mouth_apertures = {}, closure_wings = {}, dry_faces = {},
			coast_shelf = {}, islands = {}, channels = {}}
		for index = 1, #provisional_edges do local row = provisional_edges[index]
			local attachment = attachment_by_edge[row.id]
			local attachment_fields = attachment and attachment_result[attachment.id]
			local departure = departure_by_edge[row.id]
			local text = {zone_a = row.source.zone_a,
				zone_b = row.source.zone_b, tie_zone_id = row.source.tie_zone_id}
			local sample_xz, scalar_q, scalar_source_segment,
				scalar_local_station = scalar_sample_arrays(row)
			local text_arrays = {}
			local signed_arrays = {stations_xz = coordinates(row.stations, false),
				scalar_sample_xz = sample_xz, scalar_q = scalar_q}
			local unsigned_arrays = {scalar_source_segment = scalar_source_segment,
				scalar_local_station = scalar_local_station}
			local signed, unsigned = {}, {station_count = #row.stations,
				scalar_sample_count = #row.scalar_samples,
				topology_ceiling_nodes = row.topology_ceiling_nodes}
			if departure then
				text.junction_departure_id = departure.source.id
				text.junction_departure_endpoint = departure.source.edge_endpoint
				signed.junction_departure_x = departure.point.x
				signed.junction_departure_z = departure.point.z
				unsigned.effective_control_count = #departure.effective_control
			end
			local transitions = transition_by_edge[row.id] or {}
			if #transitions > 0 then
				table.sort(transitions, function(a, b)
					return a.endpoint == "from" and b.endpoint ~= "from"
				end)
				local ids, bays_for_transition, endpoints, positions, offsets = {}, {}, {}, {}, {}
				for transition_index = 1, #transitions do
					local transition = transitions[transition_index]
					ids[transition_index] = transition.id
					bays_for_transition[transition_index] = transition.bay_id
					endpoints[transition_index] = transition.endpoint
					positions[#positions + 1] = transition.point.x
					positions[#positions + 1] = transition.point.z
					offsets[transition_index] = transition.offset
				end
				unsigned.bank_transition_count = #transitions
				text_arrays.bank_transition_ids = ids
				text_arrays.bank_transition_bay_ids = bays_for_transition
				text_arrays.bank_transition_endpoints = endpoints
				signed_arrays.bank_transition_xz = positions
				unsigned_arrays.bank_transition_offsets = offsets
			end
			if attachment then
				text.attachment_id = attachment.id
				text.attachment_edge_endpoint = attachment.edge_endpoint
				text.attachment_perimeter_id = attachment.perimeter_id
				text.attachment_retained_run = attachment.retained_run
				text.attachment_before_span_id = attachment.canonical_before_span_id
				text.attachment_after_span_id = attachment.canonical_after_span_id
				text.attachment_clip_policy_id = attachment.clip_policy_id
				signed.attachment_a_x = attachment_fields.a.x
				signed.attachment_a_z = attachment_fields.a.z
				unsigned.attachment_perimeter_segment_index =
					attachment.perimeter_segment_index - 1
				unsigned.attachment_canonical_index =
					attachment_fields.canonical_index - 1
			end
			families.land_boundaries[index] = record("grug_wp40_land_boundary_v1",
				row.id, row.source.numeric_id, {text = text, signed = signed,
					unsigned = unsigned,
					text_arrays = text_arrays, signed_arrays = signed_arrays,
					unsigned_arrays = unsigned_arrays})
		end
		for index = 1, #perimeter_rows do local row = perimeter_rows[index]
			local sample_xz, scalar_q, scalar_source_segment,
				scalar_local_station = scalar_sample_arrays(row)
			families.perimeters[index] = record("grug_wp40_perimeter_v1", row.id,
				index, {text = {continent = row.source.continent},
					unsigned = {station_count = #row.stations,
						scalar_sample_count = #row.scalar_samples,
						topology_ceiling_nodes = row.topology_ceiling_nodes},
					signed_arrays = {stations_xz = coordinates(
						row.canonical_stations, true), scalar_sample_xz = sample_xz,
						scalar_q = scalar_q},
					unsigned_arrays = {scalar_source_segment = scalar_source_segment,
						scalar_local_station = scalar_local_station}})
		end
		for index = 1, #bays do local row = bays[index]
			local centreline, deltas = {}, {}
			local fill_points = bay_context_by_id[row.source.id].fill_points
			local owner_first, owner_last, owner_left, owner_right = {}, {}, {}, {}
			local owner_left_numeric, owner_right_numeric = {}, {}
			local bank_ids, bank_offsets, bank_counts, bank_stations = {}, {}, {}, {}
			for p = 1, #row.source.centreline do
				centreline[#centreline + 1] = row.source.centreline[p].x
				centreline[#centreline + 1] = row.source.centreline[p].z
				centreline[#centreline + 1] = row.source.centreline[p].half_width
			end
			for s = 1, #row.segments do for d = 1, #row.segments[s].deltas do
				deltas[#deltas + 1] = row.segments[s].deltas[d] end end
			for span_index = 1, #row.source.owner_spans do
				local span = row.source.owner_spans[span_index]
				owner_first[span_index] = span.first_segment - 1
				owner_last[span_index] = span.last_segment - 1
				owner_left[span_index] = span.left_zone_id
				owner_right[span_index] = span.right_zone_id
				owner_left_numeric[span_index] = zone_numeric[span.left_zone_id]
				owner_right_numeric[span_index] = zone_numeric[span.right_zone_id]
			end
			local shore_numeric = {}
			for shore_index = 1, #row.source.shore_zone_ids do
				shore_numeric[shore_index] =
					zone_numeric[row.source.shore_zone_ids[shore_index]]
			end
			for bank_index = 1, #source.bay_bank_components do
				local bank = source.bay_bank_components[bank_index]
				if bank.bay_id == row.source.id then
					local materialized = bank_by_id[bank.id].stations
					bank_ids[#bank_ids + 1] = bank.id
					bank_offsets[#bank_offsets + 1] = #bank_stations / 2
					bank_counts[#bank_counts + 1] = #materialized
					local values = coordinates(materialized, false)
					for value_index = 1, #values do bank_stations[#bank_stations + 1] = values[value_index] end
				end
			end
			if #bank_ids ~= 5 then fail(row.source.id .. " does not materialize five Banks") end
			families.bays[index] = record("grug_wp40_bay_v2", row.source.id, index,
				{text = {continent = row.source.continent,
					notch_fill_policy_id = source.geometry_policies.world_partition.
						bay_notch_fill_policy_id,
					perimeter_id = row.source.perimeter_projection.perimeter_id,
					owner_policy_id = source.geometry_policies.world_partition.
						bay_owner_policy_id,
					owner_segment_tie = source.geometry_policies.world_partition.
						bay_owner_segment_tie,
					owner_side_rule = source.geometry_policies.world_partition.
						bay_owner_side_rule,
					owner_side_zero_rule = source.geometry_policies.world_partition.
						bay_owner_side_zero_rule,
					owner_span_transition_rule = row.source.owner_span_transition_rule,
					owner_span_transition_tie = row.source.owner_span_transition_tie},
					unsigned = {notch_fill_count = #fill_points},
					text_arrays = {shore_zone_ids = array_copy(row.source.shore_zone_ids),
						owner_left_zone_ids = owner_left,
						owner_right_zone_ids = owner_right,
						bank_component_ids = bank_ids},
						signed_arrays = {centreline_xz_width = centreline,
						notch_fill_xz = coordinates(fill_points, false),
						station_radius_delta = deltas,
						bank_stations_xz = bank_stations},
					unsigned_arrays = {shore_zone_numeric_ids = shore_numeric,
						owner_span_first_segments = owner_first,
						owner_span_last_segments = owner_last,
						owner_left_zone_numeric_ids = owner_left_numeric,
						owner_right_zone_numeric_ids = owner_right_numeric,
						bank_station_offsets = bank_offsets,
						bank_station_counts = bank_counts}})
		end
		for index = 1, #aperture_rows do local row = aperture_rows[index]
			families.mouth_apertures[index] = record("grug_wp40_mouth_aperture_v1",
				row.source.id, index, {text = {bay_id = row.source.bay_id,
					perimeter_id = row.source.perimeter_id}, unsigned = {first = row.first - 1,
					finish = row.finish - 1, station_count = row.count,
					analytic_width = 2 * bay_by_id[row.source.bay_id].source.centreline[1].half_width},
					signed_arrays = {endpoints_xz = coordinates({row.first_point,
						row.last_point}, false)}})
		end
		for index = 1, #source.bay_closure_wings do local row = source.bay_closure_wings[index]
			local tails = wing_tail_by_id[row.id]
			families.closure_wings[index] = record("grug_wp40_closure_wing_v1",
				row.id, row.numeric_id, {text = {bay_id = row.bay_id,
					left_zone_id = row.left_zone_id, right_zone_id = row.right_zone_id,
					tie_zone_id = row.tie_zone_id}, signed = {head_x = row.head.x,
					head_z = row.head.z, junction_x = row.junction.x,
					junction_z = row.junction.z, negative_k_x = tails.negative_k.x,
					negative_k_z = tails.negative_k.z, positive_k_x = tails.positive_k.x,
					positive_k_z = tails.positive_k.z}, unsigned = {
					head_half_width = row.head_half_width,
					negative_tail_station_count = #tails.negative,
					positive_tail_station_count = #tails.positive},
					signed_arrays = {negative_tail_xz = coordinates(tails.negative, false),
						positive_tail_xz = coordinates(tails.positive, false)}})
		end
		for index = 1, #face_rows do local row = face_rows[index]
			local bank_offsets, bank_counts, bank_stations = {}, {}, {}
			for bank_index = 1, #row.bank_component_ids do
				local stations = bank_by_id[row.bank_component_ids[bank_index]].stations
				bank_offsets[bank_index] = #bank_stations / 2
				bank_counts[bank_index] = #stations
				local values = coordinates(stations, false)
				for value_index = 1, #values do bank_stations[#bank_stations + 1] = values[value_index] end
			end
			families.dry_faces[index] = record("grug_wp40_dry_face_v1", row.source.id,
				zone_numeric[row.source.zone_id], {text = {zone_id = row.source.zone_id},
					unsigned = {station_count = #row.polygon - 1},
					text_arrays = {bank_component_ids = array_copy(row.bank_component_ids)},
					signed_arrays = {polygon_xz = coordinates(row.polygon, false),
						bank_stations_xz = bank_stations},
					unsigned_arrays = {bank_station_offsets = bank_offsets,
						bank_station_counts = bank_counts}})
		end
		local coast_ids = source.geometry_policies.world_partition.
			coast_source_allowed_component_ids
		for index = 1, #coast_ids do
			local component_id = coast_ids[index]
			local component = coast_component_by_id[component_id]
			if not component then fail(component_id .. " coast component is absent") end
			local zone_id = component.source.zone_id
			local closed = component.closed
			families.coast_shelf[index] = record("grug_wp40_coast_component_v1",
				component_id, zone_numeric[zone_id], {text = {zone_id = zone_id},
					unsigned = {shelf_width = source.constants.coastal_shelf_width,
						station_count = #component.stations},
					boolean = {closed = closed},
					signed_arrays = {stations_xz = coordinates(component.stations,
						closed)}})
		end
		for index = 1, #island_rows do local row = island_rows[index]
			local sample_xz, scalar_q, scalar_source_segment,
				scalar_local_station = scalar_sample_arrays(row)
			families.islands[index] = record("grug_wp40_island_v1", row.id, index,
				{text = {zone_id = row.source.zone_id},
					unsigned = {station_count = #row.stations,
						scalar_sample_count = #row.scalar_samples,
						topology_ceiling_nodes = row.topology_ceiling_nodes},
					signed_arrays = {stations_xz = coordinates(row.stations, true),
						scalar_sample_xz = sample_xz, scalar_q = scalar_q},
					unsigned_arrays = {scalar_source_segment = scalar_source_segment,
						scalar_local_station = scalar_local_station}})
		end
		for index = 1, #source.channels do local row = source.channels[index]
			families.channels[index] = record("grug_wp40_channel_v1", row.id, index,
				{text = {island_id = row.island_id,
					mainland_zone_id = row.mainland_zone_id},
					unsigned = {minimum_hard_width = row.minimum_hard_width,
						warning_width = row.warning_width},
					signed_arrays = {polygon_xz = coordinates(row.polygon, false)}})
		end
		return {families = families}
	end

	-- Fresh data-only projection of the sole R7 materialization. Extreme
	-- selection consumes provenance-bearing pre-component scalar identities,
	-- never internal geometry tables or final partition artifacts.
	local function extreme_scalar_records(seed)
		local boundary = materialize_boundary_seed(seed)
		local records = {}
		local function append(family, row, numeric_id)
			local samples = {}
			for sample_index = 1, #row.scalar_samples do
				local sample = row.scalar_samples[sample_index]
				samples[sample_index] = {x = sample.x, z = sample.z,
					scalar_q = sample.scalar_q,
					source_segment = sample.source_segment,
					local_station = sample.local_station}
			end
			records[#records + 1] = {family = family, id = row.id,
				numeric_id = numeric_id, max_displacement = row.source.max_displacement,
				topology_ceiling_nodes = row.topology_ceiling_nodes,
				samples = samples}
		end
		for index = 1, #boundary.perimeter_rows do
			append("perimeter", boundary.perimeter_rows[index], index)
		end
		for index = 1, #boundary.island_rows do
			append("island", boundary.island_rows[index], index)
		end
		for index = 1, #boundary.provisional_edges do
			append("land_edge", boundary.provisional_edges[index],
				boundary.provisional_edges[index].source.numeric_id)
		end
		return records
	end

	local function private_plain_copy(value, seen)
		if type(value) ~= "table" then return value end
		if getmetatable(value) ~= nil then fail("extreme session input has a metatable") end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local result = {}
		seen[value] = result
		for key, child in pairs(value) do
			result[private_plain_copy(key, seen)] = private_plain_copy(child, seen)
		end
		return result
	end

	-- The long extreme scan validates Stage 1 exactly once, then reads an
	-- isolated copy through a closure. The unchecked validator is unreachable
	-- outside this already-validated private session; mutating the factory's
	-- original Source or vocabulary cannot affect later candidate rows.
	local function new_extreme_scalar_session()
		source_validator()
		local isolated_source = private_plain_copy(source)
		local isolated_vocabulary = private_plain_copy(dependencies.vocabulary)
		local isolated = new_partition({canonical = canonical,
			deterministic = deterministic, exact = exact, raster = raster,
			raw_sha256 = dependencies.raw_sha256, source = isolated_source,
			source_validator = {validate = function() return true end},
			vocabulary = isolated_vocabulary})
		local reader = isolated.extreme_scalar_records
		return function(...)
			if select("#", ...) ~= 1 then
				fail("extreme scalar reader requires exactly one seed")
			end
			return reader(...)
		end
	end

	-- Payload-only Bay ownership evaluator.  It is private compiler/test code;
	-- the compiled graph carries no closure or mutable Source reference.
	local bay_source_by_id = {}
	local bay_zone_numeric = {}
	local bay_source_numeric = {}
	for index = 1, #source.bays do
		bay_source_by_id[source.bays[index].id] = source.bays[index]
		bay_source_numeric[source.bays[index].id] = index
	end
	for index = 1, #source.zones do
		bay_zone_numeric[source.zones[index].id] = source.zones[index].numeric_id
	end

	local function exact_named_rows(record_value, field, names)
		local rows = record_value[field]
		if dense(rows, record_value.id .. " " .. field) ~= #names then
			fail(record_value.id .. " " .. field .. " count changed")
		end
		for index = 1, #names do
			if type(rows[index]) ~= "table" or getmetatable(rows[index]) ~= nil or
					rows[index].name ~= names[index] then
				fail(record_value.id .. " " .. field .. " names changed")
			end
			local is_array = field == "text_arrays" or field == "signed_arrays" or
				field == "unsigned_arrays"
			local value_field = is_array and "values" or "value"
			for key in pairs(rows[index]) do
				if key ~= "name" and key ~= value_field then
					fail(record_value.id .. " " .. field .. " row shape changed")
				end
			end
			if rows[index][value_field] == nil then
				fail(record_value.id .. " " .. field .. " row shape changed")
			end
		end
		return rows
	end

	local function validate_plain_tree(value, label, seen)
		local kind = type(value)
		if kind == "function" or kind == "userdata" or kind == "thread" then
			fail(label .. " is not data-only")
		end
		if kind ~= "table" then return end
		if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
		seen = seen or {}
		if seen[value] then fail(label .. " has a cycle or mutable alias") end
		seen[value] = true
		for key, child in pairs(value) do
			validate_plain_tree(key, label, seen)
			validate_plain_tree(child, label, seen)
		end
	end

	local function validate_bay_payload(bay)
		if type(bay) ~= "table" or getmetatable(bay) ~= nil or
				bay.record_schema ~= "grug_wp40_bay_v2" then
			fail("Bay owner payload is invalid")
		end
		validate_plain_tree(bay, bay.id or "Bay payload")
		local authored = bay_source_by_id[bay.id]
		if not authored then fail("Bay owner payload ID is invalid") end
		local record_fields = {record_schema = true, id = true, numeric_id = true,
			text_values = true, signed_values = true, unsigned_values = true,
			boolean_values = true, text_arrays = true, signed_arrays = true,
			unsigned_arrays = true, candidates = true, attributes = true}
		for key in pairs(bay) do
			if not record_fields[key] then fail(bay.id .. " Bay record shape changed") end
		end
		if bay.numeric_id ~= bay_source_numeric[bay.id] then
			fail(bay.id .. " Bay numeric ID changed")
		end
		exact_named_rows(bay, "text_values", {"continent", "notch_fill_policy_id",
			"owner_policy_id",
			"owner_segment_tie", "owner_side_rule", "owner_side_zero_rule",
			"owner_span_transition_rule", "owner_span_transition_tie", "perimeter_id"})
		exact_named_rows(bay, "signed_values", {})
		exact_named_rows(bay, "unsigned_values", {"notch_fill_count"})
		exact_named_rows(bay, "boolean_values", {})
		exact_named_rows(bay, "text_arrays", {"bank_component_ids", "owner_left_zone_ids",
			"owner_right_zone_ids", "shore_zone_ids"})
		exact_named_rows(bay, "signed_arrays", {"bank_stations_xz",
			"centreline_xz_width", "notch_fill_xz", "station_radius_delta"})
		exact_named_rows(bay, "unsigned_arrays", {"bank_station_counts",
			"bank_station_offsets", "owner_left_zone_numeric_ids",
			"owner_right_zone_numeric_ids", "owner_span_first_segments",
			"owner_span_last_segments", "shore_zone_numeric_ids"})
		if dense(bay.candidates, bay.id .. " Bay candidates") ~= 0 or
				type(bay.attributes) ~= "table" or getmetatable(bay.attributes) ~= nil or
				next(bay.attributes) ~= nil then
			fail(bay.id .. " Bay record tail changed")
		end
		if named_scalar(bay, "text_values", "continent") ~= authored.continent or
				named_scalar(bay, "text_values", "notch_fill_policy_id") ~=
					source.geometry_policies.world_partition.bay_notch_fill_policy_id or
				named_scalar(bay, "text_values", "perimeter_id") ~=
					authored.perimeter_projection.perimeter_id or
				named_scalar(bay, "text_values", "owner_policy_id") ~=
					source.geometry_policies.world_partition.bay_owner_policy_id or
				named_scalar(bay, "text_values", "owner_segment_tie") ~=
					source.geometry_policies.world_partition.bay_owner_segment_tie or
				named_scalar(bay, "text_values", "owner_side_rule") ~=
					source.geometry_policies.world_partition.bay_owner_side_rule or
				named_scalar(bay, "text_values", "owner_side_zero_rule") ~=
					source.geometry_policies.world_partition.bay_owner_side_zero_rule or
				named_scalar(bay, "text_values", "owner_span_transition_rule") ~=
					authored.owner_span_transition_rule or
				named_scalar(bay, "text_values", "owner_span_transition_tie") ~=
					authored.owner_span_transition_tie then
			fail(bay.id .. " Bay owner policy changed")
		end
		local shore = named_values(bay, "text_arrays", "shore_zone_ids")
		local shore_numeric = named_values(bay, "unsigned_arrays",
			"shore_zone_numeric_ids")
		if #shore ~= #authored.shore_zone_ids or #shore_numeric ~= #shore then
			fail(bay.id .. " Bay shore roster changed")
		end
		for index = 1, #shore do
			if shore[index] ~= authored.shore_zone_ids[index] or
					shore_numeric[index] ~= bay_zone_numeric[shore[index]] then
				fail(bay.id .. " Bay shore roster changed")
			end
		end
		local bank_ids = named_values(bay, "text_arrays", "bank_component_ids")
		local bank_offsets = named_values(bay, "unsigned_arrays", "bank_station_offsets")
		local bank_counts = named_values(bay, "unsigned_arrays", "bank_station_counts")
		local bank_stations = named_values(bay, "signed_arrays", "bank_stations_xz")
		local expected_bank_ids = {}
		for index = 1, #source.bay_bank_components do
			if source.bay_bank_components[index].bay_id == bay.id then
				expected_bank_ids[#expected_bank_ids + 1] =
					source.bay_bank_components[index].id
			end
		end
		if #bank_ids ~= 5 or #bank_offsets ~= 5 or #bank_counts ~= 5 then
			fail(bay.id .. " Bank roster changed")
		end
		local station_offset = 0
		for index = 1, 5 do
			if bank_ids[index] ~= expected_bank_ids[index] or
					bank_offsets[index] ~= station_offset or bank_counts[index] < 2 then
				fail(bay.id .. " Bank roster changed")
			end
			local seen = {}
			for station_index = 1, bank_counts[index] do
				local offset = (station_offset + station_index - 1) * 2
				local x, z = bank_stations[offset + 1], bank_stations[offset + 2]
				exact.integer(x, -2147483648, 2147483647, "Bank station x")
				exact.integer(z, -2147483648, 2147483647, "Bank station z")
				local station_key = x .. ":" .. z
				if seen[station_key] then fail(bay.id .. " Bank station repeats") end
				seen[station_key] = true
				if station_index > 1 then
					local dx = math.abs(x - bank_stations[offset - 1])
					local dz = math.abs(z - bank_stations[offset])
					if math.max(dx, dz) ~= 1 then
						fail(bay.id .. " Bank is not eight-connected")
					end
				end
			end
			station_offset = station_offset + bank_counts[index]
		end
		if #bank_stations ~= station_offset * 2 then
			fail(bay.id .. " Bank station count changed")
		end
		local notch_count = named_scalar(bay, "unsigned_values", "notch_fill_count")
		exact.integer(notch_count, 0, exact.MAX_SAFE, "Bay notch fill count")
		local notch_values = named_values(bay, "signed_arrays", "notch_fill_xz")
		if dense(notch_values, bay.id .. " Bay notch fill") ~= exact.safe_product(
				notch_count, 2, "Bay notch fill coordinate count") then
			fail(bay.id .. " Bay notch fill count changed")
		end
		local previous_x, previous_z
		for index = 1, notch_count do
			local x, z = notch_values[index * 2 - 1], notch_values[index * 2]
			exact.integer(x, -2147483648, 2147483647, "Bay notch fill x")
			exact.integer(z, -2147483648, 2147483647, "Bay notch fill z")
			if previous_x and (x < previous_x or x == previous_x and z <= previous_z) then
				fail(bay.id .. " Bay notch fill is not canonical")
			end
			previous_x, previous_z = x, z
		end
		local centreline = named_values(bay, "signed_arrays", "centreline_xz_width")
		if #centreline ~= #authored.centreline * 3 then
			fail(bay.id .. " Bay centreline changed")
		end
		for index = 1, #authored.centreline do
			local offset = (index - 1) * 3
			local point = authored.centreline[index]
			if centreline[offset + 1] ~= point.x or centreline[offset + 2] ~= point.z or
					centreline[offset + 3] ~= point.half_width then
				fail(bay.id .. " Bay centreline changed")
			end
		end
		local deltas = named_values(bay, "signed_arrays", "station_radius_delta")
		local expected_delta_count, delta_offset = 0, 0
		for segment_index = 1, #authored.centreline - 1 do
			local station_count = #raster.segment(authored.centreline[segment_index],
				authored.centreline[segment_index + 1])
			expected_delta_count = expected_delta_count + station_count
			for station_index = 1, station_count do
				local value = deltas[delta_offset + station_index]
				exact.integer(value, -authored.max_displacement,
					authored.max_displacement, "Bay displacement delta")
				if (station_index == 1 or station_index == station_count) and value ~= 0 then
					fail(bay.id .. " Bay displacement taper changed")
				end
			end
			delta_offset = delta_offset + station_count
		end
		if dense(deltas, bay.id .. " Bay deltas") ~= expected_delta_count then
			fail(bay.id .. " Bay displacement count changed")
		end
		local first = named_values(bay, "unsigned_arrays",
			"owner_span_first_segments")
		local finish = named_values(bay, "unsigned_arrays",
			"owner_span_last_segments")
		local left = named_values(bay, "text_arrays", "owner_left_zone_ids")
		local right = named_values(bay, "text_arrays", "owner_right_zone_ids")
		local left_numeric = named_values(bay, "unsigned_arrays",
			"owner_left_zone_numeric_ids")
		local right_numeric = named_values(bay, "unsigned_arrays",
			"owner_right_zone_numeric_ids")
		local span_count = dense(first, "Bay owner spans")
		if span_count ~= #authored.owner_spans or #finish ~= span_count or
				#left ~= span_count or #right ~= span_count or
				#left_numeric ~= span_count or #right_numeric ~= span_count then
			fail("Bay owner span arrays disagree")
		end
		for index = 1, span_count do
			local span = authored.owner_spans[index]
			if first[index] ~= span.first_segment - 1 or
					finish[index] ~= span.last_segment - 1 or
					left[index] ~= span.left_zone_id or right[index] ~= span.right_zone_id or
					left_numeric[index] ~= bay_zone_numeric[left[index]] or
					right_numeric[index] ~= bay_zone_numeric[right[index]] then
				fail(bay.id .. " Bay owner spans changed")
			end
		end
		return centreline, first, finish, left, right, left_numeric, right_numeric
	end

	local function bay_owner(bay, x, z)
		exact.integer(x, -2147483648, 2147483647, "Bay owner x")
		exact.integer(z, -2147483648, 2147483647, "Bay owner z")
		local centreline, first, finish, left, right, left_numeric, right_numeric =
			validate_bay_payload(bay)
		local span_count = #first
		local function span_for(segment_index)
			for index = 1, span_count do
				if segment_index >= first[index] and segment_index <= finish[index] then
					return index
				end
			end
			fail("Bay owner segment is uncovered")
		end
		local best, best_n, best_d, tied
		local point_count = #centreline / 3
		for index = 1, point_count - 1 do
			local offset = (index - 1) * 3
			local a = {x = centreline[offset + 1], z = centreline[offset + 2]}
			local b = {x = centreline[offset + 4], z = centreline[offset + 5]}
			local n, d = exact.segment_distance(x, z, a, b)
			local dx, dz = exact.vector(a, b, "Bay owner segment")
			local px = exact.safe_difference(x, a.x, "Bay owner query")
			local pz = exact.safe_difference(z, a.z, "Bay owner query")
			local side = exact.cross(dx, dz, px, pz, "Bay owner side")
			local span_index = span_for(index - 1)
			local owner_id, owner_numeric
			if side > 0 then
				owner_id, owner_numeric = left[span_index], left_numeric[span_index]
			elseif side < 0 then
				owner_id, owner_numeric = right[span_index], right_numeric[span_index]
			elseif left_numeric[span_index] < right_numeric[span_index] then
				owner_id, owner_numeric = left[span_index], left_numeric[span_index]
			else
				owner_id, owner_numeric = right[span_index], right_numeric[span_index]
			end
			local candidate = {zone_id = owner_id, zone_numeric = owner_numeric,
				segment_index = index - 1, side = side}
			local comparison = best and exact.rational_compare(n, d, best_n, best_d) or -1
			if comparison < 0 then
				best, best_n, best_d, tied = candidate, n, d, false
			elseif comparison == 0 then
				tied = true
				if candidate.zone_numeric < best.zone_numeric then best = candidate end
			end
		end
		return best, best_n, best_d, tied
	end

	local coast_expected_owner = {}
	local coast_zone_numeric = {}
	for index = 1, #source.zones do
		coast_zone_numeric[source.zones[index].id] = source.zones[index].numeric_id
	end
	for index = 1, #source.perimeter_spans do
		local row = source.perimeter_spans[index]
		coast_expected_owner[row.id] = row.zone_id
	end
	for index = 1, #source.face_arcs do
		local row = source.face_arcs[index]
		coast_expected_owner[row.id] = row.zone_id
	end

	local function validate_coast_payload(payload)
		dense(payload, "coast payload")
		local roster = source.geometry_policies.world_partition.
			coast_source_allowed_component_ids
		if #payload ~= #roster then fail("coast payload roster count changed") end
		for component_index = 1, #payload do
			local component = payload[component_index]
			if type(component) ~= "table" or getmetatable(component) ~= nil or
					component.record_schema ~= "grug_wp40_coast_component_v1" or
					component.id ~= roster[component_index] then
				fail("coast payload roster or schema changed")
			end
			local record_fields = {record_schema = true, id = true, numeric_id = true,
				text_values = true, signed_values = true, unsigned_values = true,
				boolean_values = true, text_arrays = true, signed_arrays = true,
				unsigned_arrays = true, candidates = true, attributes = true}
			for key in pairs(component) do
				if not record_fields[key] then fail(component.id .. " coast record shape changed") end
			end
			local expected_zone = coast_expected_owner[component.id]
			if component.numeric_id ~= coast_zone_numeric[expected_zone] then
				fail(component.id .. " coast owner numeric changed")
			end
			local text_rows = exact_named_rows(component, "text_values", {"zone_id"})
			if text_rows[1].value ~= expected_zone then
				fail(component.id .. " coast owner zone changed")
			end
			exact_named_rows(component, "signed_values", {})
			local unsigned_rows = exact_named_rows(component, "unsigned_values",
				{"shelf_width", "station_count"})
			if unsigned_rows[1].value ~= source.constants.coastal_shelf_width then
				fail(component.id .. " coast shelf width changed")
			end
			local station_count = unsigned_rows[2].value
			exact.integer(station_count, 2, 1000000, "coast station count")
			local boolean_rows = exact_named_rows(component, "boolean_values", {"closed"})
			local expected_closed = component_index > 20
			if type(boolean_rows[1].value) ~= "boolean" or
					boolean_rows[1].value ~= expected_closed then
				fail(component.id .. " coast closure changed")
			end
			exact_named_rows(component, "text_arrays", {})
			local signed_rows = exact_named_rows(component, "signed_arrays",
				{"stations_xz"})
			exact_named_rows(component, "unsigned_arrays", {})
			if dense(component.candidates, component.id .. " candidates") ~= 0 or
					type(component.attributes) ~= "table" or
					getmetatable(component.attributes) ~= nil or
					next(component.attributes) ~= nil then
				fail(component.id .. " coast record tail changed")
			end
			local values = signed_rows[1].values
			local coordinate_count = dense(values, component.id .. " coast stations")
			local point_count = coordinate_count / 2
			if coordinate_count % 2 ~= 0 or
					point_count ~= station_count + (expected_closed and 1 or 0) then
				fail(component.id .. " coast station count or closure changed")
			end
			local seen = {}
			for point_index = 1, point_count do
				local offset = (point_index - 1) * 2
				exact.integer(values[offset + 1], -2147483648, 2147483647,
					"coast station x")
				exact.integer(values[offset + 2], -2147483648, 2147483647,
					"coast station z")
				local station_key = values[offset + 1] .. ":" .. values[offset + 2]
				if not expected_closed or point_index < point_count then
					if seen[station_key] then
						fail(component.id .. " coast station repeats")
					end
					seen[station_key] = true
				end
			end
			if expected_closed then
				if values[1] ~= values[coordinate_count - 1] or
						values[2] ~= values[coordinate_count] then
					fail(component.id .. " coast closure changed")
				end
			elseif values[1] == values[coordinate_count - 1] and
					values[2] == values[coordinate_count] then
				fail(component.id .. " open coast component is closed")
			end
			for segment_index = 1, point_count - 1 do
				local offset = (segment_index - 1) * 2
				local dx = math.abs(values[offset + 3] - values[offset + 1])
				local dz = math.abs(values[offset + 4] - values[offset + 2])
				if math.max(dx, dz) ~= 1 then
					fail(component.id .. " coast segment is not nonzero eight-connected")
				end
			end
		end
		return roster
	end

	local function coast_consider(best, best_n, best_d, ties, candidate, n, d)
		local comparison = best and exact.rational_compare(n, d, best_n, best_d) or -1
		local tie_less = best and
			(candidate.zone_numeric < best.zone_numeric or
			candidate.zone_numeric == best.zone_numeric and
				(candidate.component_id < best.component_id or
				candidate.component_id == best.component_id and
					candidate.segment_index < best.segment_index))
		if comparison < 0 then return candidate, n, d, 1 end
		if comparison == 0 then
			ties = ties + 1
			if tie_less then best = candidate end
		end
		return best, best_n, best_d, ties
	end

	-- The later spatial wrapper owns the compiled interesting-extent check and
	-- returns nil outside it.  This slice evaluates only already-admitted points.
	local function coast_source(payload, x, z)
		validate_coast_payload(payload)
		exact.integer(x, -2147483648, 2147483647, "coast query x")
		exact.integer(z, -2147483648, 2147483647, "coast query z")
		local best, best_n, best_d, ties
		for component_index = 1, #payload do
			local component = payload[component_index]
			local values = component.signed_arrays[1].values
			local station_count = #values / 2
			for segment_index = 1, station_count - 1 do
				local offset = (segment_index - 1) * 2
				local candidate = {zone_numeric = component.numeric_id,
					component_id = component.id, segment_index = segment_index - 1}
				local n, d = exact.segment_distance(x, z,
					{x = values[offset + 1], z = values[offset + 2]},
					{x = values[offset + 3], z = values[offset + 4]})
				best, best_n, best_d, ties = coast_consider(best, best_n, best_d,
					ties, candidate, n, d)
			end
		end
		return best, best_n, best_d, ties
	end

	partition.compile = compile_impl
	partition.extreme_scalar_records = extreme_scalar_records
	partition.new_extreme_scalar_session = new_extreme_scalar_session
	partition.bay_owner = bay_owner
	partition.validate_bay_payload = validate_bay_payload
	partition.coast_source = coast_source
	partition.coast_consider = coast_consider
	partition.validate_coast_payload = validate_coast_payload
	partition.validate_junction_pair = validate_junction_pair
	partition.select_attachment_station = select_attachment_station
	partition.transition_water_owned = transition_water_owned
	partition.select_edge_transition = select_edge_transition
	partition.add_edge_transition_control = add_edge_transition_control
	partition.select_first_reachable = select_first_reachable
	partition.horizontal_precedence = horizontal_precedence
	partition.shelf_from_distance = shelf_from_distance
	partition.count_trace_envelope = count_trace_envelope
	partition.trace_bounds = trace_bounds
	partition.validate_trace_counters = validate_trace_counters
	partition.reverse_materialized = reverse_points
	return partition
end

return new_partition
