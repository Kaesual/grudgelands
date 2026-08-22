-- Private WP40 T2 partition compiler.  It consumes only checksum-validated
-- source plus T1/exact/raster seams and returns normalized data-only records.

-- One prefix constant: the census stage-reject classifier anchors its site
-- extraction on these exact bytes, so rewording them in one place and not
-- the other would silently turn every classified stage reject back into a
-- fleet-killing abort.
local fail_prefix = "WP40 geometry partition: "

local function fail(message)
	error(fail_prefix .. message, 0)
end

local function exact_dependencies(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("dependencies are not a plain table")
	end
	local allowed = {canonical = true, deterministic = true, exact = true,
		new_boundary = true, raster = true, raw_sha256 = true, source = true,
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
	if type(value.new_boundary) ~= "function" then
		fail("stage-S1 boundary factory missing")
	end
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

	-- Stage S1 -- the whole per-record R7 displacement -- lives in its own
	-- module.  Everything below is S2..S9: this compiler consumes the S1 result
	-- and may never re-derive effective controls, no-jitter sources, fixed
	-- closure or displacement of its own.
	local boundary = dependencies.new_boundary({canonical = canonical,
		deterministic = deterministic, exact = exact, raster = raster,
		raw_sha256 = dependencies.raw_sha256, source = source,
		source_validator = dependencies.source_validator,
		vocabulary = dependencies.vocabulary})
	local materialize_boundary_seed = boundary.materialize

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

	-- The canonical x-then-z point order and the Chebyshev metric, hoisted so
	-- exactly one copy exists for the compiler stages and the census layer.
	local function point_less(a, b)
		return a.x < b.x or a.x == b.x and a.z < b.z
	end

	local function chebyshev(a, b)
		return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
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

	-- Consecutive-duplicate-free control append, shared by compile_impl's
	-- final-edge assembly and the census tuple probes so the two can never
	-- drift in dedup semantics.
	local function append_dedup(controls, point)
		if #controls == 0 or key(controls[#controls]) ~= key(point) then
			controls[#controls + 1] = {x = point.x, z = point.z}
		end
	end

	local function reverse_points(points)
		local result = {}
		for index = #points, 1, -1 do
			result[#result + 1] = {x = points[index].x, z = points[index].z}
		end
		return result
	end

	local function attachment_station_candidate(e, candidates, canonical_indices)
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
		return {x = best.x, z = best.z}, best_distance, best_index
	end

	local function select_attachment_station(e, candidates, canonical_indices)
		local best, best_distance, best_index = attachment_station_candidate(e,
			candidates, canonical_indices)
		if best_distance > 1 then fail("Attachment E/A distance exceeds one") end
		return best, best_distance, best_index
	end

	-- Production-consumed closed selector for the exact-six C2 interval policy.
	-- Geometry probes remain in compile_impl; this seam owns only the complete
	-- ordered from/to tuple and deliberately has no length or index tie.
	local function select_incidence_interval(candidates)
		if dense(candidates, "incidence interval candidates") == 0 then
			fail("incidence interval candidate roster is empty")
		end
		local selected
		for index = 1, #candidates do
			local candidate = candidates[index]
			if type(candidate) ~= "table" or getmetatable(candidate) ~= nil then
				fail("incidence interval candidate is not a plain table")
			end
			local allowed = {first = true, finish = true,
				from_complete = true, to_complete = true}
			for field in pairs(candidate) do
				if not allowed[field] then
					fail("incidence interval candidate has an unknown field")
				end
			end
			exact.integer(candidate.first, 1, exact.MAX_SAFE,
				"incidence interval first")
			exact.integer(candidate.finish, candidate.first, exact.MAX_SAFE,
				"incidence interval finish")
			if type(candidate.from_complete) ~= "boolean" or
					type(candidate.to_complete) ~= "boolean" then
				fail("incidence interval obligation is not boolean")
			end
			if candidate.from_complete and candidate.to_complete then
				if selected then fail("more than one incidence-complete interval") end
				selected = index
			end
		end
		if not selected then fail("no incidence-complete interval") end
		return selected
	end

	-- All matching authored indices, not pairwise-distinct displaced x/z, form
	-- the unique C2 subsequence. Consecutive shifted controls may legitimately
	-- collapse to one coordinate and are canonically deduplicated by final_raster.
	local function select_control_subsequence(shifted_controls, stations)
		dense(shifted_controls, "shifted controls")
		if dense(stations, "selected interval stations") == 0 then
			fail("selected interval station roster is empty")
		end
		local membership = {}
		for station_index = 1, #stations do
			exact.point(stations[station_index], "selected interval station")
			local point_key = key(stations[station_index])
			if membership[point_key] then
				fail("selected interval repeats a station identity")
			end
			membership[point_key] = true
		end
		local indices = {}
		for control_index = 1, #shifted_controls do
			exact.point(shifted_controls[control_index], "shifted control")
			if membership[key(shifted_controls[control_index])] then
				indices[#indices + 1] = control_index
			end
		end
		if #indices == 0 then fail("selected control subsequence is empty") end
		for index = 2, #indices do
			if indices[index] ~= indices[index - 1] + 1 then
				fail("selected control subsequence is not contiguous")
			end
		end
		return indices
	end

	-- The transition-only exact-six reraster may contain new Bresenham
	-- intermediates between retained controls. Compile computes these flags
	-- with the sole final Bay-water mask; this closed seam makes it impossible
	-- to publish even one wet final Land station.
	local function validate_transition_dry_flags(flags)
		if dense(flags, "transition-only final dry flags") == 0 then
			fail("transition-only final dry flag roster is empty")
		end
		for index = 1, #flags do
			if type(flags[index]) ~= "boolean" then
				fail("transition-only final dry flag is not boolean")
			end
			if not flags[index] then
				fail("transition-only final raster retained a wet station")
			end
		end
		return true
	end

	-- Closed production-consumed decision seam for C2 fragments discarded by
	-- the interval selector. Geometry lookup stays in compile_impl; this seam
	-- owns identity uniqueness and the Bank-first/exact-one-Face outcome.
	local function validate_excluded_fragment_evidence(rows)
		dense(rows, "excluded dry fragment evidence")
		local seen = {}
		for index = 1, #rows do
			local row = rows[index]
			if type(row) ~= "table" or getmetatable(row) ~= nil then
				fail("excluded dry fragment evidence is not a plain table")
			end
			local allowed = {edge_id = true, point = true, land_count = true,
				terminal_identity = true, bank_count = true, face_count = true}
			for field in pairs(row) do
				if not allowed[field] then
					fail("excluded dry fragment evidence has an unknown field")
				end
			end
			if type(row.edge_id) ~= "string" or row.edge_id == "" or
					type(row.terminal_identity) ~= "boolean" then
				fail("excluded dry fragment evidence is malformed")
			end
			exact.point(row.point, row.edge_id .. " excluded dry fragment")
			exact.integer(row.land_count, 0, exact.MAX_SAFE,
				row.edge_id .. " excluded land count")
			exact.integer(row.bank_count, 0, exact.MAX_SAFE,
				row.edge_id .. " excluded Bank count")
			exact.integer(row.face_count, 0, exact.MAX_SAFE,
				row.edge_id .. " excluded Face count")
			local point_key = key(row.point)
			if seen[point_key] then fail("excluded dry fragment identity is duplicated") end
			seen[point_key] = true
			if row.land_count > 0 or row.terminal_identity then
				fail(row.edge_id .. " excluded dry fragment retained a final identity")
			end
			local owner_count = row.bank_count > 0 and row.bank_count or row.face_count
			if owner_count ~= 1 then
				fail(row.edge_id .. " excluded dry fragment owner count is " .. owner_count)
			end
		end
		return true
	end

	-- The eight aperture incidences share this exact direct-or-unique-shoulder
	-- decision. Bank direction and its strict signed water-side check are owned
	-- by the materializer below, after this geometry-only selection.
	local function select_aperture_transition(evidence)
		if type(evidence) ~= "table" or getmetatable(evidence) ~= nil or
				type(evidence.id) ~= "string" or
				type(evidence.direct_candidate) ~= "boolean" then
			fail("aperture transition evidence is malformed")
		end
		exact.point(evidence.d, evidence.id .. " D")
		exact.point(evidence.a, evidence.id .. " A")
		if evidence.direct_candidate then
			local allowed = {id = true, d = true, a = true,
				direct_candidate = true}
			for field in pairs(evidence) do
				if not allowed[field] then
					fail(evidence.id .. " direct evidence has an unknown field")
				end
			end
			return {mode = "direct", d = {x = evidence.d.x, z = evidence.d.z},
				a = {x = evidence.a.x, z = evidence.a.z}}
		end
		local allowed = {id = true, d = true, a = true, direct_candidate = true,
			w = true, d_class = true, d_cardinal_water = true,
			w_raw_owned_by_bay = true, w_final_owned_by_bay = true,
			w_foreign_water = true, w_aperture_included = true,
			elbow_valid = true}
		for field in pairs(evidence) do
			if not allowed[field] then
				fail(evidence.id .. " shoulder evidence has an unknown field")
			end
		end
		exact.point(evidence.w, evidence.id .. " W")
		exact.integer(evidence.d_class, -1, 1, evidence.id .. " D class")
		for _, field in ipairs({"d_cardinal_water", "w_raw_owned_by_bay",
				"w_final_owned_by_bay", "w_foreign_water",
				"w_aperture_included"}) do
			if type(evidence[field]) ~= "boolean" then
				fail(evidence.id .. " shoulder evidence is malformed")
			end
		end
		if dense(evidence.elbow_valid, evidence.id .. " elbow validity") ~= 2 or
				type(evidence.elbow_valid[1]) ~= "boolean" or
				type(evidence.elbow_valid[2]) ~= "boolean" then
			fail(evidence.id .. " shoulder elbow evidence is malformed")
		end
		local dx = exact.safe_difference(evidence.w.x, evidence.d.x,
			evidence.id .. " D/W dx")
		local dz = exact.safe_difference(evidence.w.z, evidence.d.z,
			evidence.id .. " D/W dz")
		if evidence.d_class ~= 0 then fail(evidence.id .. " D is not dry equality") end
		if evidence.d_cardinal_water then fail(evidence.id .. " D has cardinal water") end
		if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 then
			fail(evidence.id .. " D/W is not exactly diagonal")
		end
		if not evidence.w_raw_owned_by_bay or not evidence.w_final_owned_by_bay then
			fail(evidence.id .. " W is not raw and final referenced-Bay water")
		end
		if evidence.w_foreign_water then fail(evidence.id .. " W is foreign-Bay water") end
		if not evidence.w_aperture_included then
			fail(evidence.id .. " W is not immediately aperture-included")
		end
		local valid_count, selected = 0, nil
		for index = 1, 2 do
			if evidence.elbow_valid[index] then
				valid_count, selected = valid_count + 1, index
			end
		end
		if valid_count ~= 1 then
			fail(evidence.id .. " does not have exactly one valid shoulder elbow")
		end
		local elbows = {{x = evidence.w.x, z = evidence.d.z},
			{x = evidence.d.x, z = evidence.w.z}}
		return {mode = "diagonal_shoulder",
			d = {x = evidence.d.x, z = evidence.d.z},
			a = {x = evidence.a.x, z = evidence.a.z},
			w = {x = evidence.w.x, z = evidence.w.z},
			t = {x = elbows[selected].x, z = elbows[selected].z},
			elbows = copy_points(elbows), selected_elbow = selected}
	end

	local function aperture_tail_water_side(first, second, water, side)
		exact.point(first, "aperture tail first")
		exact.point(second, "aperture tail second")
		exact.point(water, "aperture tail water")
		if side ~= "left" and side ~= "right" then
			fail("aperture tail water side is invalid")
		end
		local dx = exact.safe_difference(second.x, first.x,
			"aperture tail direction x")
		local dz = exact.safe_difference(second.z, first.z,
			"aperture tail direction z")
		local wx = exact.safe_difference(water.x, first.x,
			"aperture tail water x")
		local wz = exact.safe_difference(water.z, first.z,
			"aperture tail water z")
		local cross = exact.cross(dx, dz, wx, wz, "aperture tail water side")
		return side == "right" and cross < 0 or side == "left" and cross > 0
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

	-- The window-guarded appendix acceptance (contracts 11.5-C, ruled
	-- 2026-08-20; completed by the 11.9 ruling and re-ruled by 11.10 on
	-- the complete distribution): every measured self-touch is join-local
	-- within this many ring stations of a part join.  Provenance (pin
	-- lineage W 8 -> 11 -> 12): the 11.5 investigation measured bound 6
	-- over the 95 preserved violations (an 8.5% dump sample, ruled one
	-- wider at W = 8); the section-11.8 union sweep measured all 796 face
	-- witnesses and 11.9 pinned the observed maximum 11 -- in fact a
	-- one-witness generalization; the section-11.10 acceptance sweep then
	-- measured the COMPLETE distribution and 11.10 pins W at its maximum
	-- 12 exactly -- the first W pin whose provenance is a complete
	-- population; no margin, anything farther stays a named loud failure.
	--
	-- Corrected provenance (contracts 11.11, restated here 2026-08-22 with
	-- this file open for the section-13 comparator alignment): the earlier
	-- text of this comment cited the superseded 93-row w11-stop capture and
	-- its d=1 x14 / 2 x10 histogram.  The complete deduplicated family-B
	-- population is 105 stations, canonical fixture
	-- tools/wp40/fixtures/t2_census/s11-bjoin-complete-v1.tsv, all 60
	-- family-B seeds represented, d=1 x15, 2 x15, 3 x3, 4 x3, 8 x7, 9 x9,
	-- 10 x25, 11 x23, 12 x5, nothing beyond 12 -- still the silverleaf
	-- touch family 1138-1140:-2232 against its join anchor jittering +-1
	-- over 1126/1127/1128:-2233 at the maximum.  THE MAXIMUM IS UNCHANGED
	-- AT 12 and W does not move: only the population behind it is restated.
	-- The census authority pins the same value; the worker refuses to run
	-- when the two copies disagree.
	local FACE_APPENDIX_WINDOW = 12

	-- The eight lattice directions in counterclockwise cyclic order: the
	-- integer ground of the 11.9 locally-non-crossing touch predicate.
	local touch_direction_index = {
		["1:0"] = 0, ["1:1"] = 1, ["0:1"] = 2, ["-1:1"] = 3,
		["-1:0"] = 4, ["-1:-1"] = 5, ["0:-1"] = 6, ["1:-1"] = 7}

	-- Every composed face is an eight-connected integer lattice walk. For this
	-- representation, unique nonterminal stations plus the one possible
	-- station-free intersection (opposing cell diagonals) are the complete
	-- simplicity proof. This keeps 15k-station coast faces linear.
	--
	-- Two-tier validation (contracts 11.5-C, completed by 11.9): the linear
	-- simplicity proof is the fast path and clean geometry never leaves it.
	-- A ring with repeated stations is accepted only when every repeat is a
	-- join-local, locally non-crossing self-touch -- the fully measured
	-- bay-transition family and nothing else:
	--   * join-local: each occurrence within FACE_APPENDIX_WINDOW ring
	--     stations of one shared part join (`join_keys`, the station keys
	--     where composition joined two parts);
	--   * locally non-crossing: the two passes through the repeated station
	--     must not interleave in the cyclic order of the four incident ring
	--     edges (integer-only over the eight lattice directions; a shared
	--     edge direction is overlap, not a crossing -- the retraced
	--     corridor is exactly that).
	-- The touch FORM is then recorded, not gated on: a zero-width touch --
	-- NO cardinal 4-neighbour strictly interior by winding (the ratified
	-- 11.8/11.9 operationalization; the winding membership of
	-- exact.polygon_class requires closure, not simplicity) -- is a
	-- filament appendix (straight corridor stations have both laterals
	-- strictly outside, and W-112's dawnmere L-turn corridor mouth,
	-- measured 2026-08-20 at station -634:-2918 with classes
	-- E=0/W=-1/N=0/S=0, has boundary neighbours on both axes and still no
	-- interior beside it); a touch beside strict interior is a pinch (the
	-- 19 measured interior-hugging one-station dips of the 11.8 family B).
	-- Every failing condition aborts by its own name -- a crossing, a
	-- non-join-local repeat, a station repeated more than twice -- and an
	-- opposing cell diagonal stays an abort in either tier.
	-- Returns the filament (appendix) and pinch station counts -- distinct
	-- repeated stations by form -- both zero exactly on the fast path.
	local function validate_face_polygon(id, polygon, join_keys)
		if #polygon < 4 or key(polygon[1]) ~= key(polygon[#polygon]) then
			fail(id .. " is not closed " .. key(polygon[1]) .. " -> " ..
				key(polygon[#polygon]))
		end
		local seen, diagonal_cells = {}, {}
		local repeated_keys, repeats = {}, {}
		for index = 1, #polygon - 1 do
			local point = polygon[index]
			exact.point(point, id .. " station")
			local station_key = key(point)
			if seen[station_key] then
				local entry = repeats[station_key]
				if not entry then
					entry = {seen[station_key]}
					repeats[station_key] = entry
					repeated_keys[#repeated_keys + 1] = station_key
				end
				entry[#entry + 1] = index
			else
				seen[station_key] = index
			end
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
					fail(id .. " has an opposing cell diagonal at cell " .. cell_key)
				end
				diagonal_cells[cell_key] = slope
			end
		end
		local appendix_count, pinch_count = 0, 0
		if #repeated_keys > 0 then
			-- The appendix tier.  Conditions are checked per repeated station
			-- in first-occurrence ring order: occurrence count, join
			-- locality, local non-crossing -- deterministic, so the first
			-- failure is the same failure under every interpreter.  The
			-- zero-width measurement afterwards only records the touch form.
			local ring_count = #polygon - 1
			local join_indices = {}
			if join_keys then
				for index = 1, ring_count do
					if join_keys[key(polygon[index])] then
						join_indices[#join_indices + 1] = index
					end
				end
			end
			local polygon_index = exact.polygon_index(polygon)
			for order = 1, #repeated_keys do
				local station_key = repeated_keys[order]
				local entry = repeats[station_key]
				if #entry > 2 then
					fail(id .. " appendix station repeated more than twice at " ..
						station_key)
				end
				-- Join-local: both occurrences inside the window of the SAME
				-- join (the measured shape -- no violation straddles two
				-- joins), distances cyclic over the ring.
				local anchored = false
				for join_position = 1, #join_indices do
					local join_index = join_indices[join_position]
					local near = true
					for occurrence = 1, #entry do
						local distance = math.abs(entry[occurrence] - join_index)
						distance = math.min(distance, ring_count - distance)
						if distance > FACE_APPENDIX_WINDOW then
							near = false
							break
						end
					end
					if near then
						anchored = true
						break
					end
				end
				if not anchored then
					fail(id .. " has a non-join-local repeat at " .. station_key)
				end
				local station = polygon[entry[1]]
				-- Locally non-crossing (contracts 11.9, family B).  The
				-- repeated station splits the ring into two LOOPS: loop
				-- alpha runs from the first occurrence's outgoing edge to
				-- the second occurrence's incoming edge, loop beta from the
				-- second's outgoing edge back to the first's incoming edge.
				-- The self-touch crosses exactly when the two loops'
				-- edge-end pairs interleave in the cyclic order of the four
				-- incident ring edges -- the configuration that cannot
				-- close in the plane without a further self-intersection.
				-- The loop pairing, not the pass pairing, is the ruled
				-- predicate's operationalization: measured 2026-08-20 on
				-- the 11.9 family-C anatomy shape (the accepted one-station
				-- dip, e.g. kragmar_stillgrave_hollow at -1204:2233, passes
				-- W->E and S->NW), whose PASSES interleave while its loops
				-- occupy disjoint sectors -- the pass form would reject the
				-- measured family the 11.9 ruling accepts.  A coincident
				-- loop-end direction is a shared edge -- overlap, not a
				-- crossing (the retraced corridor and the measured dips are
				-- exactly that) -- and a loop with both ends on one
				-- direction is a degenerate spike that cannot separate the
				-- other loop.
				local function incident_direction(station_index, step)
					local neighbour_index
					if step < 0 then
						neighbour_index = station_index == 1 and ring_count or
							station_index - 1
					else
						neighbour_index = station_index + 1
					end
					local neighbour = polygon[neighbour_index]
					return touch_direction_index[
						(neighbour.x - station.x) .. ":" ..
						(neighbour.z - station.z)]
				end
				local function strictly_between(from, value, to)
					local offset = (value - from) % 8
					return offset > 0 and offset < (to - from) % 8
				end
				local a1 = incident_direction(entry[1], 1)
				local a2 = incident_direction(entry[2], -1)
				local b1 = incident_direction(entry[2], 1)
				local b2 = incident_direction(entry[1], -1)
				if a1 ~= a2 and b1 ~= b2 and
						(strictly_between(a1, b1, a2) and
							strictly_between(a2, b2, a1) or
						strictly_between(a1, b2, a2) and
							strictly_between(a2, b1, a1)) then
					fail(id .. " has a crossing repeat at " .. station_key)
				end
				-- The touch form, recorded under face_appendix_select
				-- (contracts 11.9): zero width -- the ratified no-cardinal-
				-- interior predicate -- is a filament appendix, strict
				-- interior beside the touch is a pinch.
				if exact.indexed_polygon_class(polygon_index,
							station.x - 1, station.z) > 0 or
						exact.indexed_polygon_class(polygon_index,
							station.x + 1, station.z) > 0 or
						exact.indexed_polygon_class(polygon_index,
							station.x, station.z - 1) > 0 or
						exact.indexed_polygon_class(polygon_index,
							station.x, station.z + 1) > 0 then
					pinch_count = pinch_count + 1
				else
					appendix_count = appendix_count + 1
				end
			end
		end
		if exact.signed_area2(polygon) <= 0 then fail(id .. " is not CCW") end
		return appendix_count, pinch_count
	end

	-- Census classification twin of the R13 pair gate: identical checks in
	-- identical order, returning the first failing class instead of aborting.
	-- validate_junction_pair below maps each class onto its original message,
	-- so the compile path keeps its exact fail behavior.
	local function classify_junction_pair(junction, left, right)
		exact.point(junction, "junction pair point")
		local left_count = dense(left, "left junction raster")
		local right_count = dense(right, "right junction raster")
		if left_count < 2 or right_count < 2 then return "short_raster" end
		local junction_key = key(junction)
		if key(left[1]) ~= junction_key and key(left[left_count]) ~= junction_key or
				key(right[1]) ~= junction_key and key(right[right_count]) ~= junction_key then
			return "not_endpoint"
		end
		local left_stations, left_diagonals = {}, {}
		for index = 1, left_count do
			exact.point(left[index], "left junction station")
			left_stations[key(left[index])] = true
			if index < left_count then
				local a, b = left[index], left[index + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
					return "left_not_eight_connected"
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
				return "shared_station"
			end
			if index < right_count then
				local a, b = right[index], right[index + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				if math.max(math.abs(dx), math.abs(dz)) ~= 1 then
					return "right_not_eight_connected"
				end
				if math.abs(dx) == 1 and math.abs(dz) == 1 then
					local cell = math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z)
					local slope = dx == dz and 1 or -1
					if left_diagonals[cell] and left_diagonals[cell] ~= slope then
						return "x_cross"
					end
				end
			end
		end
		return nil
	end

	local junction_pair_messages = {
		not_endpoint = " is not an edge endpoint",
		left_not_eight_connected = " left raster is not eight-connected",
		shared_station = " incident edges share a nonjunction station",
		right_not_eight_connected = " right raster is not eight-connected",
		x_cross = " incident edges have an opposing diagonal X-cross"}

	local function validate_junction_pair(junction, left, right, label)
		local class = classify_junction_pair(junction, left, right)
		if class == "short_raster" then fail("junction pair raster is short") end
		if class then
			fail((label or key(junction)) .. junction_pair_messages[class])
		end
		return true
	end

	-- Scan-1 stress scalar: the minimum Chebyshev distance between two incident
	-- rasters with the shared junction column excluded from both sides.  Sweep
	-- over x-sorted stations; the moving lower bound stays valid because the
	-- left x is nondecreasing while the best bound only shrinks.
	local function pair_clearance(junction, left, right)
		local junction_key = key(junction)
		local function collect(stations)
			local result = {}
			for index = 1, #stations do
				if key(stations[index]) ~= junction_key then
					result[#result + 1] = stations[index]
				end
			end
			table.sort(result, point_less)
			return result
		end
		local left_sorted, right_sorted = collect(left), collect(right)
		if #left_sorted == 0 or #right_sorted == 0 then return nil end
		local best, low = nil, 1
		for index = 1, #left_sorted do
			local point = left_sorted[index]
			while best and low <= #right_sorted and
					right_sorted[low].x < point.x - best do
				low = low + 1
			end
			for probe = low, #right_sorted do
				local candidate = right_sorted[probe]
				if best and candidate.x > point.x + best then break end
				local distance = chebyshev(candidate, point)
				if not best or distance < best then best = distance end
				if best == 0 then return 0 end
			end
		end
		return best
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

	-- The R12 caps count the finite search envelope itself, not its larger
	-- outer rectangle: exact union of expanded Base/Wing boxes, clipped to
	-- the referenced final mainland footprint.  Idempotent so the census
	-- completion tier can resolve it lazily per Bay while compile_impl keeps
	-- walking every Bay eagerly in its historical order.
	local function ensure_trace_bounds(context)
		if context.trace_bounds then return end
		local column_count = count_trace_envelope(context.boxes,
			context.perimeter.polygon_index, context.bay.source.id)
		context.step_bound = column_count
		context.trace_bounds = trace_bounds(column_count)
	end

	local function terminal_key(terminal)
		if terminal.kind == "aperture_dry" then
			return terminal.kind .. ":" .. terminal.aperture_id .. ":" .. terminal.side
		elseif terminal.kind == "land_edge_transition" then
			return terminal.kind .. ":" .. terminal.edge_id .. ":" ..
				terminal.edge_endpoint
		elseif terminal.kind == "wing_junction_tail_side" then
			return terminal.kind .. ":" .. terminal.wing_id .. ":" ..
				terminal.tail_side
		end
		fail("unknown Bank terminal kind " .. tostring(terminal.kind))
	end

	-- ------------------------------------------------------------------
	-- The D1 completion-multiplicity order (plan 7.1, contracts 8.1 and 13):
	-- among complete joint tuples the compiler selects the least under a
	-- declared total order.  Keys, in order: total retreat from the declared
	-- endpoints, maximum per-endpoint retreat, elbow-terminal count, the sorted
	-- resolved terminal set, the sorted previous set, and the probe bytes under
	-- canonical orientation (the lexicographically lesser of the byte text and
	-- its exact reverse).  Totality is guaranteed by the duplicate-authority
	-- reject: tuples equal under the last three keys share terminal, previous
	-- and probe byte identity and were rejected before the order applies.
	-- Every key is invariant under authored edge reversal, so the
	-- bay_edge_transition_terminal_reversal clause holds unchanged.
	--
	-- Keys 4 and 5 are the DECLARED COORDINATE ORDER -- lexicographic by
	-- (x, z) over signed integers -- and never the rendered "x:z" text.  The
	-- two metrics genuinely differ: as text "-1134:2242" precedes
	-- "-1135:2242", "10:z" precedes "9:z" and "12:3" precedes "1:5", while as
	-- coordinates -1135 < -1134, 9 < 10 and 1 < 12; they agree at the sign
	-- boundary, where "-" already sorts below "0".  Contracts section 13 rules
	-- the coordinate tuple the authority, records that production had
	-- implemented the rendering instead, and records the measured firing set:
	-- empty over all 759 retained multi-complete records, key 1 selecting
	-- uniquely at every one of them under both metrics, so no measured
	-- selection moved.  Key 6 is untouched by that ruling -- it is a byte
	-- sequence by declaration, including its ";" separator.
	--
	-- Two implementations exist by contract (8.1): joint_tuple_less_compile
	-- is the compile path's, joint_tuple_less_census the projection's.  The
	-- full-`W` cross-check, the synthetic key KATs (contracts 8.3) and the
	-- independent C2 oracle compare all three; neither production comparator
	-- may call the other, copy its result or share a comparison helper with it
	-- (contracts 13.5), which is why each carries its own point order below
	-- rather than reusing the file-level point_less.  Both consume the same
	-- descriptor shape: from_retreat/to_retreat (nil at an endpoint the edge
	-- does not declare), elbow_count, terminal_points and previous_points as
	-- arrays of {x = <int>, z = <int>} coordinate pairs, and the
	-- probe_forward/probe_reverse canonical point texts.
	local function validate_joint_points(points, label)
		if type(points) ~= "table" or getmetatable(points) ~= nil then
			fail("joint tuple descriptor " .. label .. " set is malformed")
		end
		for index = 1, #points do
			local point = points[index]
			if type(point) ~= "table" or getmetatable(point) ~= nil then
				fail("joint tuple descriptor " .. label .. " is malformed")
			end
			exact.integer(point.x, -2147483648, 2147483647,
				"joint tuple descriptor " .. label .. " x")
			exact.integer(point.z, -2147483648, 2147483647,
				"joint tuple descriptor " .. label .. " z")
		end
	end

	local function validate_joint_descriptor(descriptor)
		if type(descriptor) ~= "table" or getmetatable(descriptor) ~= nil then
			fail("joint tuple descriptor is malformed")
		end
		if descriptor.from_retreat == nil and descriptor.to_retreat == nil then
			fail("joint tuple descriptor lacks a declared endpoint")
		end
		for _, field in ipairs({"from_retreat", "to_retreat"}) do
			if descriptor[field] ~= nil then
				exact.integer(descriptor[field], 0, exact.MAX_SAFE,
					"joint tuple descriptor " .. field)
			end
		end
		exact.integer(descriptor.elbow_count, 0, 2,
			"joint tuple descriptor elbow count")
		validate_joint_points(descriptor.terminal_points, "terminal point")
		validate_joint_points(descriptor.previous_points, "previous point")
		if type(descriptor.probe_forward) ~= "string" or
				type(descriptor.probe_reverse) ~= "string" then
			fail("joint tuple descriptor is malformed")
		end
	end

	-- Two tuples of one edge always declare the same endpoints, so the two
	-- coordinate sequences always have the same length.  Comparing sequences
	-- of different length would let arity decide a key silently, so each of
	-- the two comparators below carries its own guard -- inline rather than
	-- shared, because contracts 13.5 keeps the two implementations apart --
	-- and fails loudly instead.
	local function joint_tuple_less_compile(left, right)
		validate_joint_descriptor(left)
		validate_joint_descriptor(right)
		if (left.from_retreat == nil) ~= (right.from_retreat == nil) or
				(left.to_retreat == nil) ~= (right.to_retreat == nil) or
				#left.terminal_points ~= #right.terminal_points or
				#left.previous_points ~= #right.previous_points then
			fail("joint tuple descriptors declare different endpoint arity")
		end
		local left_total = (left.from_retreat or 0) + (left.to_retreat or 0)
		local right_total = (right.from_retreat or 0) + (right.to_retreat or 0)
		if left_total ~= right_total then return left_total < right_total end
		local left_peak = math.max(left.from_retreat or 0, left.to_retreat or 0)
		local right_peak = math.max(right.from_retreat or 0,
			right.to_retreat or 0)
		if left_peak ~= right_peak then return left_peak < right_peak end
		if left.elbow_count ~= right.elbow_count then
			return left.elbow_count < right.elbow_count
		end
		-- Keys 4 and 5, this comparator's own construction: sort each set by
		-- (x, z) and walk the two sorted sequences pairwise, deciding at the
		-- first differing coordinate.  Nothing is rendered.
		local function sorted_points(points)
			local copy = {}
			for index = 1, #points do
				copy[index] = {x = points[index].x, z = points[index].z}
			end
			table.sort(copy, function(a, b)
				if a.x ~= b.x then return a.x < b.x end
				return a.z < b.z
			end)
			return copy
		end
		local function decide_points(left_points, right_points)
			local sorted_left = sorted_points(left_points)
			local sorted_right = sorted_points(right_points)
			for index = 1, #sorted_left do
				local a, b = sorted_left[index], sorted_right[index]
				if a.x ~= b.x then return a.x < b.x end
				if a.z ~= b.z then return a.z < b.z end
			end
			return nil
		end
		local terminal_decision = decide_points(left.terminal_points,
			right.terminal_points)
		if terminal_decision ~= nil then return terminal_decision end
		local previous_decision = decide_points(left.previous_points,
			right.previous_points)
		if previous_decision ~= nil then return previous_decision end
		local left_probe = left.probe_reverse < left.probe_forward and
			left.probe_reverse or left.probe_forward
		local right_probe = right.probe_reverse < right.probe_forward and
			right.probe_reverse or right.probe_forward
		return left_probe < right_probe
	end

	-- The projection's own (x, z) order, expressed as a three-way comparison
	-- so the rank vector below can be walked positionally.  Deliberately not
	-- the compile comparator's construction and not the file-level point_less
	-- either: contracts 13.5 makes a shared comparison helper between the two
	-- production implementations a STOP.
	local function census_point_order(a, b)
		if a.x < b.x then return -1 end
		if a.x > b.x then return 1 end
		if a.z < b.z then return -1 end
		if a.z > b.z then return 1 end
		return 0
	end

	-- The projection's independent implementation: a rank vector compared
	-- positionally.  Deliberately a different construction from the compile
	-- comparator above; see the contract note there.  Entries 4 and 5 are the
	-- sorted coordinate sequences themselves, never a rendering of them.
	local function joint_tuple_rank_census(descriptor)
		validate_joint_descriptor(descriptor)
		local retreats = {}
		if descriptor.from_retreat then
			retreats[#retreats + 1] = descriptor.from_retreat
		end
		if descriptor.to_retreat then
			retreats[#retreats + 1] = descriptor.to_retreat
		end
		local total, peak = 0, 0
		for index = 1, #retreats do
			total = total + retreats[index]
			if retreats[index] > peak then peak = retreats[index] end
		end
		local function sorted_copy(points)
			local copy = {}
			for index = 1, #points do
				copy[index] = {x = points[index].x, z = points[index].z}
			end
			table.sort(copy, function(a, b)
				return census_point_order(a, b) < 0
			end)
			return copy
		end
		local oriented = descriptor.probe_forward
		if descriptor.probe_reverse < oriented then
			oriented = descriptor.probe_reverse
		end
		return {total, peak, descriptor.elbow_count,
			sorted_copy(descriptor.terminal_points),
			sorted_copy(descriptor.previous_points), oriented}
	end

	local function joint_tuple_less_census(left, right)
		local left_rank = joint_tuple_rank_census(left)
		local right_rank = joint_tuple_rank_census(right)
		-- This side's own arity guard, same predicate as the compile
		-- comparator's and deliberately not the same code.
		local function endpoint_tag(descriptor)
			return (descriptor.from_retreat ~= nil and "from" or "") .. ":" ..
				(descriptor.to_retreat ~= nil and "to" or "")
		end
		if endpoint_tag(left) ~= endpoint_tag(right) or
				#left_rank[4] ~= #right_rank[4] or
				#left_rank[5] ~= #right_rank[5] then
			fail("joint tuple descriptors rank across different endpoint arity")
		end
		for index = 1, 6 do
			if index == 4 or index == 5 then
				local left_points, right_points = left_rank[index], right_rank[index]
				for point_index = 1, #left_points do
					local order = census_point_order(left_points[point_index],
						right_points[point_index])
					if order ~= 0 then return order < 0 end
				end
			elseif left_rank[index] ~= right_rank[index] then
				return left_rank[index] < right_rank[index]
			end
		end
		return false
	end

	-- The Source Bank roster, shared by the compile path's R19 completion,
	-- the Scan-2 completion tier and the Scan-3a passes; seed-independent, so
	-- built once.
	local bank_source_by_id = {}
	for index = 1, #source.bay_bank_components do
		bank_source_by_id[source.bay_bank_components[index].id] =
			source.bay_bank_components[index]
	end

	-- The compile path's R19 joint transition resolution (source-authority
	-- section 4, contracts 8.1): after the R18 interval is fixed, every
	-- eligible incidence of each declared transition endpoint runs R16, the
	-- checked Cartesian product of the successes is exhaustively probed and
	-- completion-traced, duplicate authority and zero-complete reject the
	-- seed, and among several complete tuples the D1 order selects the least.
	-- Per-tuple failures (empty or noncontiguous clip, invalid or wet probe,
	-- unsatisfiable previous binding, incomplete bank) are DECIDED
	-- continuations under the U1/U2 readings; enumeration never prunes.
	-- The census projection keeps its own independent enumeration in
	-- census_scan2; the full-`W` cross-check compares the two selections.
	local function resolve_edge_joint_terminals(stage, tracer, edge,
			transition_source, attachment, interval, probed_attachment)
		local choices = {}
		for _, endpoint in ipairs({"from", "to"}) do
			local row = transition_source[endpoint]
			if row then
				local from_side = endpoint == "from"
				local low = from_side and interval.first or interval.first + 1
				local high = from_side and interval.finish - 1 or interval.finish
				local list = {}
				for station_index = low, high do
					local probed = stage.probe_edge_transition_at(row, edge,
						station_index)
					if probed then
						list[#list + 1] = {index = station_index, resolved = probed}
					end
				end
				choices[endpoint] = list
			end
		end
		local from_choices, to_choices = choices.from, choices.to
		if from_choices and to_choices then
			exact.safe_product(#from_choices, #to_choices,
				edge.id .. " R19 tuple count")
		end

		local function probe_tuple(from_choice, to_choice)
			local from_i = from_choice and from_choice.index or interval.first
			local to_i = to_choice and to_choice.index or interval.finish
			if from_i > to_i then return nil end
			local ok, probe = pcall(function()
				local stations = {}
				for station_index = from_i, to_i do
					local point = edge.stations[station_index]
					stations[#stations + 1] = {x = point.x, z = point.z}
				end
				local retained = select_control_subsequence(edge.shifted_controls,
					stations)
				local controls = {}
				local function append_control(point)
					append_dedup(controls, point)
				end
				local from_station = edge.stations[from_i]
				local to_station = edge.stations[to_i]
				if attachment and attachment.edge_endpoint == "from" then
					append_control(probed_attachment.a)
					for index = 1, #retained do
						append_control(edge.shifted_controls[retained[index]])
					end
					append_control(to_station)
					controls = add_edge_transition_control(controls,
						to_choice.resolved.selection, "to", to_station)
				elseif attachment and attachment.edge_endpoint == "to" then
					append_control(from_station)
					for index = 1, #retained do
						append_control(edge.shifted_controls[retained[index]])
					end
					append_control(probed_attachment.a)
					controls = add_edge_transition_control(controls,
						from_choice.resolved.selection, "from", from_station)
				else
					append_control(from_station)
					for index = 1, #retained do
						append_control(edge.shifted_controls[retained[index]])
					end
					append_control(to_station)
					controls = add_edge_transition_control(controls,
						from_choice.resolved.selection, "from", from_station)
					controls = add_edge_transition_control(controls,
						to_choice.resolved.selection, "to", to_station)
				end
				local rastered = raster.final_raster(controls, false)
				if #rastered < 2 then
					fail(edge.id .. " joint tuple probe has one station")
				end
				raster.validate_final({id = edge.id, kind = "land_edge",
					closed = false,
					max_displacement = edge.source.max_displacement},
					edge.base_stations, rastered)
				if attachment then
					for station_index = 1, #rastered do
						local station = rastered[station_index]
						if key(station) ~= key(probed_attachment.a) and
								(stage.footprint_class(station.x, station.z) ~= 1 or
								stage.planned_water(station.x, station.z, false)) then
							fail(edge.id .. " joint tuple probe leaves strict interior")
						end
					end
				else
					local dry_flags = {}
					for station_index = 1, #rastered do
						local station = rastered[station_index]
						dry_flags[station_index] = stage.dry_land(station.x,
							station.z)
					end
					validate_transition_dry_flags(dry_flags)
				end
				local from_terminal = from_choice and from_choice.resolved.point or
					probed_attachment.a
				local to_terminal = to_choice and to_choice.resolved.point or
					probed_attachment.a
				if key(rastered[1]) ~= key(from_terminal) or
						key(rastered[#rastered]) ~= key(to_terminal) then
					fail(edge.id .. " joint tuple terminal is not its probe endpoint")
				end
				return rastered
			end)
			if not ok then return nil end
			local out = {from_choice = from_choice, to_choice = to_choice,
				from_i = from_i, to_i = to_i, probe = probe}
			if from_choice then
				out.from_previous = {x = probe[2].x, z = probe[2].z}
			end
			if to_choice then
				out.to_previous = {x = probe[#probe - 1].x,
					z = probe[#probe - 1].z}
			end
			local forward_texts = {}
			for station_index = 1, #probe do
				forward_texts[station_index] = key(probe[station_index])
			end
			out.probe_forward = table.concat(forward_texts, ";")
			local reverse_texts = {}
			for station_index = #probe, 1, -1 do
				reverse_texts[#reverse_texts + 1] = key(probe[station_index])
			end
			out.probe_reverse = table.concat(reverse_texts, ";")
			out.identity = table.concat({
				from_choice and key(from_choice.resolved.point) or "-",
				out.from_previous and key(out.from_previous) or "-",
				to_choice and key(to_choice.resolved.point) or "-",
				out.to_previous and key(out.to_previous) or "-",
				out.probe_forward}, "|")
			return out
		end

		local completion_roster = {}
		for _, endpoint in ipairs({"from", "to"}) do
			local row = transition_source[endpoint]
			if row then
				local transition_key = stage.land_transition_key(row.edge_id,
					row.edge_endpoint)
				local banks = {}
				for bank_index = 1, 2 do
					local bank = bank_source_by_id[
						row.incident_bank_component_ids[bank_index]]
					if not bank then
						fail(row.id .. " references an absent Bank")
					end
					local side
					if terminal_key(bank.start_terminal) == transition_key then
						side = "start"
					elseif terminal_key(bank.end_terminal) == transition_key then
						side = "end"
					else
						fail(bank.id .. " is not incident to " .. transition_key)
					end
					banks[bank_index] = {bank = bank, side = side}
				end
				completion_roster[endpoint] = {row = row,
					transition_key = transition_key, banks = banks}
			end
		end

		local function tuple_completes(candidate)
			for _, endpoint in ipairs({"from", "to"}) do
				local choice
				if endpoint == "from" then choice = candidate.from_choice
				else choice = candidate.to_choice end
				if choice then
					local roster = completion_roster[endpoint]
					local previous = endpoint == "from" and
						candidate.from_previous or candidate.to_previous
					local resolved = tracer.resolve_land_transition(
						roster.transition_key,
						{source = roster.row, point = choice.resolved.point,
							previous = previous, mode = choice.resolved.mode,
							e = choice.resolved.e, w = choice.resolved.w})
					for bank_index = 1, 2 do
						local entry = roster.banks[bank_index]
						local trace_ok = pcall(function()
							local start_resolved, finish_resolved
							if entry.side == "start" then
								start_resolved = resolved
								finish_resolved = tracer.resolve_terminal(
									entry.bank.end_terminal, entry.bank.bay_id)
							else
								finish_resolved = resolved
								start_resolved = tracer.resolve_terminal(
									entry.bank.start_terminal, entry.bank.bay_id)
							end
							tracer.trace_bank(entry.bank, start_resolved,
								finish_resolved)
						end)
						if not trace_ok then return false end
					end
				end
			end
			return true
		end

		local evaluated = {}
		local function evaluate(from_choice, to_choice)
			local candidate = probe_tuple(from_choice, to_choice)
			if candidate then evaluated[#evaluated + 1] = candidate end
		end
		if from_choices and to_choices then
			for from_index = 1, #from_choices do
				for to_index = 1, #to_choices do
					evaluate(from_choices[from_index], to_choices[to_index])
				end
			end
		elseif from_choices then
			for from_index = 1, #from_choices do
				evaluate(from_choices[from_index], nil)
			end
		else
			for to_index = 1, #to_choices do
				evaluate(nil, to_choices[to_index])
			end
		end

		local identity_counts = {}
		for index = 1, #evaluated do
			identity_counts[evaluated[index].identity] =
				(identity_counts[evaluated[index].identity] or 0) + 1
		end
		for _, count in pairs(identity_counts) do
			if count >= 2 then
				fail(edge.id .. " has duplicate joint tuple authority")
			end
		end

		-- Keys 4 and 5 compare coordinates, so the descriptor carries the
		-- coordinate pairs themselves and never their rendering (contracts 13).
		local function joint_descriptor(candidate)
			local descriptor = {elbow_count = 0, terminal_points = {},
				previous_points = {}, probe_forward = candidate.probe_forward,
				probe_reverse = candidate.probe_reverse}
			if candidate.from_choice then
				local terminal = candidate.from_choice.resolved.point
				local previous = candidate.from_previous
				descriptor.from_retreat = candidate.from_i - interval.first
				descriptor.terminal_points[#descriptor.terminal_points + 1] =
					{x = terminal.x, z = terminal.z}
				descriptor.previous_points[#descriptor.previous_points + 1] =
					{x = previous.x, z = previous.z}
				if candidate.from_choice.resolved.mode ~= "direct" then
					descriptor.elbow_count = descriptor.elbow_count + 1
				end
			end
			if candidate.to_choice then
				local terminal = candidate.to_choice.resolved.point
				local previous = candidate.to_previous
				descriptor.to_retreat = interval.finish - candidate.to_i
				descriptor.terminal_points[#descriptor.terminal_points + 1] =
					{x = terminal.x, z = terminal.z}
				descriptor.previous_points[#descriptor.previous_points + 1] =
					{x = previous.x, z = previous.z}
				if candidate.to_choice.resolved.mode ~= "direct" then
					descriptor.elbow_count = descriptor.elbow_count + 1
				end
			end
			return descriptor
		end

		local selected = nil
		for index = 1, #evaluated do
			local candidate = evaluated[index]
			if tuple_completes(candidate) then
				if not selected or joint_tuple_less_compile(
						joint_descriptor(candidate), joint_descriptor(selected)) then
					selected = candidate
				end
			end
		end
		if not selected then
			fail(edge.id .. " has zero complete joint tuples")
		end
		return selected
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

	-- Stages S1..S3 plus the shared classification substrate: boundary
	-- materialization, Bay contexts, raw mask, notch fill, water predicates and
	-- the interval/transition/attachment probes.  compile_impl consumes this
	-- stage and continues fail-closed; census_scan1 consumes the same stage and
	-- records decision classes instead.  Both callers see the identical
	-- functions, so the census can never drift from the compiler's predicates.
	local function build_scan_stage(seed)
		local materialized = materialize_boundary_seed(seed)
		-- Zone numbering is face/bank payload identity, not S1 displacement
		-- input, so it is derived here rather than inside the S1 stage.
		local zone_numeric = {}
		for index = 1, #source.zones do
			zone_numeric[source.zones[index].id] = source.zones[index].numeric_id
		end
		local departure_by_edge = materialized.departure_by_edge
		local perimeter_rows, perimeter_by_id = materialized.perimeter_rows,
			materialized.perimeter_by_id
		local island_rows, island_by_id = materialized.island_rows,
			materialized.island_by_id
		local provisional_edges, edge_by_id = materialized.provisional_edges,
			materialized.edge_by_id
		local bays, bay_by_id = bay_data(seed)
		local aperture_rows, aperture_by_bay, aperture_by_id = {}, {}, {}
		local aperture_station_owner = {}
		-- The D2 detached-shoulder admission (plan 7.2, contracts 8.1): a sweep
		-- admits, per aperture end, at most one Base-Bay-passing station
		-- separated from the aperture run by exactly one non-passing station.
		-- The admitted station stays outside aperture membership, payload and
		-- ownership; every other passing station outside the run keeps the
		-- reject, measured vacuous over the full `W` census.
		local function detached_shoulder_runs(stations, run_first, run_last, member)
			local runs, run_start = {}, nil
			for station_index = 1, #stations do
				local inside = station_index >= run_first and
					station_index <= run_last
				local passes = not inside and member(stations[station_index])
				if passes and not run_start then run_start = station_index end
				if not passes and run_start then
					runs[#runs + 1] = {run_start, station_index - 1}
					run_start = nil
				end
			end
			if run_start then runs[#runs + 1] = {run_start, #stations} end
			local admitted = {}
			for run_index = 1, #runs do
				local run = runs[run_index]
				if run[1] == run[2] and run[1] == run_first - 2 then
					admitted.before_station = run[1]
				elseif run[1] == run[2] and run[1] == run_last + 2 then
					admitted.after_station = run[1]
				else
					return nil
				end
			end
			return admitted
		end
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
			local canonical_detached = detached_shoulder_runs(
				perimeter.canonical_stations, first, last, function(point)
					return base_bay_member(bay, point.x, point.z)
				end)
			if not canonical_detached then
				fail(row.id .. " has a wrapping or second aperture run")
			end
			local compiled = {source = row, first = first, finish = last + 1,
				count = last - first + 1, included = included,
				first_point = perimeter.canonical_stations[first],
				last_point = perimeter.canonical_stations[last], before = before,
				excluded_end = excluded_end,
				detached_before = canonical_detached.before_station,
				detached_after = canonical_detached.after_station}
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
			local authored_detached = detached_shoulder_runs(perimeter.stations,
				authored_first, authored_last, function(point)
					return base_bay_member(bay, point.x, point.z)
				end)
			if not authored_detached then
				fail(row.id .. " authored Bank aperture has a second run")
			end
			compiled.bank_first = authored_first
			compiled.bank_finish = authored_last + 1
			compiled.bank_before = perimeter.stations[authored_first - 1]
			compiled.bank_after = perimeter.stations[authored_last + 1]
			compiled.authored_detached_before = authored_detached.before_station
			compiled.authored_detached_after = authored_detached.after_station
			-- Source-authority 3.1 read literally (the D2 decision): `A` is the
			-- next dry station away from `D`, so an admitted detached shoulder
			-- station is skipped rather than mistaken for the dry anchor.
			local before_previous_index = authored_first - 2
			if authored_detached.before_station == before_previous_index then
				before_previous_index = before_previous_index - 1
			end
			local after_previous_index = authored_last + 2
			if authored_detached.after_station == after_previous_index then
				after_previous_index = after_previous_index + 1
			end
			compiled.bank_before_previous = perimeter.stations[before_previous_index]
			compiled.bank_after_previous = perimeter.stations[after_previous_index]
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
				-- `fill` is the union of every planned-water addition to the
				-- raw mask; `fill_points` stays the section-7.1 notch fills
				-- alone and `closing_points` the section-11 connectivity
				-- closing's, so the notch projections and payload never
				-- absorb the other rule's columns.
				fill_points = {}, closing_points = {},
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

		-- O1 (decided 2026-08-16, plan section 5; implemented per contracts
		-- 8.1): aperture-versus-attachment collision is unreachable, asserted
		-- rather than restated.  Every mouth-aperture station lies inside its
		-- Bay's authored base envelope, and every displaced attachment station
		-- lies within the perimeter's authored max_displacement of its declared
		-- authored segment, so a strictly positive margin between the authored
		-- segment box and the envelope box makes the collision impossible at
		-- every seed.  All inputs are authored and seed-independent; in the
		-- F1-prefilter style the claim is verified at every stage build rather
		-- than trusted.
		for index = 1, #source.perimeter_attachments do
			local attachment = source.perimeter_attachments[index]
			local attachment_perimeter = perimeter_by_id[attachment.perimeter_id]
			if not attachment_perimeter then
				fail(attachment.id .. " references an absent perimeter")
			end
			local polygon = attachment_perimeter.source.polygon
			local a = polygon[attachment.perimeter_segment_index]
			local b = polygon[attachment.perimeter_segment_index + 1]
			if not a or not b then
				fail(attachment.id .. " declared authored segment is absent")
			end
			local seg_min_x, seg_max_x = math.min(a.x, b.x), math.max(a.x, b.x)
			local seg_min_z, seg_max_z = math.min(a.z, b.z), math.max(a.z, b.z)
			for bay_index = 1, #bays do
				local context = bay_context_by_id[bays[bay_index].source.id]
				local gap_x = math.max(
					exact.safe_difference(context.min_x, seg_max_x,
						attachment.id .. " O1 margin x"),
					exact.safe_difference(seg_min_x, context.max_x,
						attachment.id .. " O1 margin x"), 0)
				local gap_z = math.max(
					exact.safe_difference(context.min_z, seg_max_z,
						attachment.id .. " O1 margin z"),
					exact.safe_difference(seg_min_z, context.max_z,
						attachment.id .. " O1 margin z"), 0)
				if math.max(gap_x, gap_z) <=
						attachment_perimeter.source.max_displacement then
					fail(attachment.id .. " O1 aperture margin to " ..
						bays[bay_index].source.id .. " is not strictly positive")
				end
			end
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
		--
		-- The same pass records the raw-dry footprint complement as maximal
		-- row runs -- the flood domain of the section-11 connectivity closing
		-- below.  `class` here is the Bay's own perimeter; inside a Bay
		-- envelope that IS the footprint, which the closing's ground
		-- assertions verify against the other perimeter, the islands and the
		-- Holy band before the domain is read.
		local closing_domain_by_bay = {}
		for bay_index = 1, #bays do
			local context = bay_context_by_id[bays[bay_index].source.id]
			local dry_rows = {}
			closing_domain_by_bay[context.bay.source.id] = dry_rows
			for z = context.min_z, context.max_z do
				local schedules, cursors = {}, {}
				for segment_index = 1, #context.bay.segments do
					schedules[segment_index] = nearest_schedule(
						context.bay.segments[segment_index].stations, z,
						context.bay.source.id)
					cursors[segment_index] = 1
				end
				local runs, first = {}, nil
				local dry_runs, dry_first, dry_boundary = {}, nil, false
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
					if class >= 0 and not raw then
						if not dry_first then dry_first, dry_boundary = x, false end
						if class == 0 then dry_boundary = true end
					elseif dry_first then
						dry_runs[#dry_runs + 1] = {z = z, first = dry_first,
							finish = x - 1, boundary = dry_boundary}
						dry_first = nil
					end
				end
				if first then runs[#runs + 1] = {first = first, finish = context.max_x} end
				if #runs > 0 then context.raw_rows[z] = runs end
				if dry_first then
					dry_runs[#dry_runs + 1] = {z = z, first = dry_first,
						finish = context.max_x, boundary = dry_boundary}
				end
				if #dry_runs > 0 then dry_rows[z] = dry_runs end
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

		-- The connectivity closing (contracts section 11 branch 2c, ruled
		-- 2026-08-20; decoupled from the corridor question by the 1c
		-- refutation ruling at that section's end): a raw-dry column with no
		-- dry 4-connected path to the Bank-side mainland becomes planned
		-- water.  Bay water is the connected wet region, and dry noise at
		-- its jittered margin -- the measured 1..15-column pockets nobody
		-- owns, and the fragment singleton's isolated hole -- is water,
		-- stated as connectivity instead of as an enumeration of pocket
		-- shapes.  The section-7.1 notch rule above stays: on an enclosed
		-- pocket it is a fast path to the same fill, and on a
		-- mainland-connected degree-one spur tip it keeps a fill this rule
		-- deliberately does not make (such a tip has a dry path out).
		--
		-- "Bank-side mainland" is decidable inside one Bay envelope alone
		-- only while no other dry-land authority reaches into it, so in the
		-- F1-prefilter style that ground is verified at every stage build
		-- rather than trusted: the four envelopes pairwise disjoint, every
		-- island and the Holy band outside all of them.  Within a clean
		-- envelope the strict capsule and wing memberships plus each box's
		-- +1 margin keep raw water off the envelope border, so a dry border
		-- column is the mainland by construction: the flood seeds on the
		-- border ring and walks the maximal dry row runs recorded by the
		-- mask pass; a run no walk reaches is a margin pocket and fills.
		do
			local island_boxes = {}
			for island_index = 1, #island_rows do
				local stations = island_rows[island_index].stations
				local box = {min_x = stations[1].x, max_x = stations[1].x,
					min_z = stations[1].z, max_z = stations[1].z}
				for station_index = 2, #stations do
					local point = stations[station_index]
					box.min_x = math.min(box.min_x, point.x)
					box.max_x = math.max(box.max_x, point.x)
					box.min_z = math.min(box.min_z, point.z)
					box.max_z = math.max(box.max_z, point.z)
				end
				island_boxes[island_index] = box
			end
			local holy = source.constants.holy_grounds
			for bay_index = 1, #bays do
				local context = bay_context_by_id[bays[bay_index].source.id]
				for other_index = bay_index + 1, #bays do
					local other = bay_context_by_id[bays[other_index].source.id]
					if context.min_x <= other.max_x and
							other.min_x <= context.max_x and
							context.min_z <= other.max_z and
							other.min_z <= context.max_z then
						fail(context.bay.source.id .. " and " ..
							other.bay.source.id .. " Bay envelopes intersect")
					end
				end
				if context.min_x <= holy.max_x and holy.min_x <= context.max_x and
						context.min_z <= holy.max_z and
						holy.min_z <= context.max_z then
					fail(context.bay.source.id ..
						" Bay envelope reaches the Holy band")
				end
				for island_index = 1, #island_boxes do
					local box = island_boxes[island_index]
					if context.min_x <= box.max_x and
							box.min_x <= context.max_x and
							context.min_z <= box.max_z and
							box.min_z <= context.max_z then
						fail(context.bay.source.id ..
							" Bay envelope reaches " ..
							island_rows[island_index].id)
					end
				end
			end
		end
		for bay_index = 1, #bays do
			local context = bay_context_by_id[bays[bay_index].source.id]
			local dry_rows = closing_domain_by_bay[context.bay.source.id]
			local stack = {}
			local function reach(run)
				if not run.reached then
					run.reached = true
					stack[#stack + 1] = run
				end
			end
			for z = context.min_z, context.max_z do
				local runs = dry_rows[z]
				if runs then
					for run_index = 1, #runs do
						local run = runs[run_index]
						if z == context.min_z or z == context.max_z or
								run.first == context.min_x or
								run.finish == context.max_x then
							reach(run)
						end
					end
				end
			end
			while #stack > 0 do
				local run = stack[#stack]
				stack[#stack] = nil
				for step = -1, 1, 2 do
					local neighbors = dry_rows[run.z + step]
					if neighbors then
						for neighbor_index = 1, #neighbors do
							local neighbor = neighbors[neighbor_index]
							if neighbor.first <= run.finish and
									run.first <= neighbor.finish then
								reach(neighbor)
							end
						end
					end
				end
			end
			for z = context.min_z, context.max_z do
				local runs = dry_rows[z]
				if runs then
					for run_index = 1, #runs do
						local run = runs[run_index]
						if not run.reached then
							-- A footprint-ring station is mainland by
							-- definition -- never a closing candidate
							-- (contracts 11.9, family A).  The retired 11.8
							-- loud guard ("closing pocket holds a footprint
							-- boundary column") fired on exactly this
							-- condition: the measured 8/8 pinched fragments
							-- are single coast-ring stations whose mainland
							-- continuity is one diagonal ring step -- the
							-- coast ring walks eight-connected while this
							-- flood walks 4-connected row runs, so the
							-- "pinch" was the flood criterion's artefact,
							-- not the geometry's.  The ring column stays dry
							-- land here and the ownership layer adopts it
							-- along the ring's own connectivity
							-- (whole_adopt_residue); non-ring columns of the
							-- same pocket still fill, and the Whole gate
							-- stays the loud backstop if a ring chain ends
							-- up unowned.
							for x = run.first, run.finish do
								local point_key = x .. ":" .. z
								-- A notch-filled column is already planned
								-- water of this Bay; any other standing owner
								-- is a foreign Bay, unreachable under the
								-- envelope disjointness above.
								if run.boundary and exact.indexed_polygon_class(
										context.perimeter.polygon_index,
										x, z) == 0 then
									-- the ring station: never watered
								elseif not context.fill[point_key] then
									if fill_owner[point_key] then
										fail(context.bay.source.id ..
											" closing pocket is owned by " ..
											"another Bay")
									end
									fill_owner[point_key] = context
									context.fill[point_key] = true
									context.closing_points[
										#context.closing_points + 1] =
										{x = x, z = z}
								end
							end
						end
					end
				end
			end
			closing_domain_by_bay[context.bay.source.id] = nil
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

		local function maximal_dry_intervals(edge)
			local intervals, first = {}, nil
			for station_index = 1, #edge.stations do
				local point = edge.stations[station_index]
				if dry_land(point.x, point.z) then
					if not first then first = station_index end
				elseif first then
					intervals[#intervals + 1] = {first = first,
						finish = station_index - 1}
					first = nil
				end
			end
			if first then intervals[#intervals + 1] = {first = first,
				finish = #edge.stations} end
			return intervals
		end

		-- The R16 resolver at an explicit station incidence.  R19 (source
		-- authority section 4) evaluates this same resolver for every eligible
		-- incidence of the selected interval; the interval-endpoint form below
		-- is the R18 qualification probe and delegates here so the resolver
		-- exists exactly once.  W is the immediately adjacent provisional
		-- station toward the Bay: for an interior incidence that station is
		-- final-dry, so interior incidences can only succeed as direct
		-- candidates -- the elbow branch is reachable only at the endpoint.
		local function probe_edge_transition_at(row, edge, e_index)
			local context = bay_context_by_id[row.bay_id]
			if not context then fail(row.id .. " references an absent Bay") end
			local e = edge.stations[e_index]
			local evidence = {id = row.id, e = {x = e.x, z = e.z},
				direct_candidate = bay_candidate(context, e.x, e.z)}
			if not evidence.direct_candidate then
				evidence.e_strict_dry = footprint_class(e.x, e.z) == 1 and
					bay_dry(context, e.x, e.z)
				if not evidence.e_strict_dry then return nil end
				evidence.e_cardinal_water = false
				for direction_index = 1, #cardinal do
					local direction = cardinal[direction_index]
					local nx = checked_coordinate(e.x, direction.x,
						row.id .. " E cardinal x")
					local nz = checked_coordinate(e.z, direction.z,
						row.id .. " E cardinal z")
					if final_water(nx, nz) then
						evidence.e_cardinal_water = true break
					end
				end
				if evidence.e_cardinal_water then return nil end
				local w_index = row.edge_endpoint == "from" and e_index - 1 or e_index + 1
				local w = edge.stations[w_index]
				if not w then return nil end
				evidence.w = {x = w.x, z = w.z}
				evidence.w_owned_by_bay = transition_water_owned(
					final_water(w.x, w.z), bay_water(context, w.x, w.z))
				if not evidence.w_owned_by_bay then return nil end
				evidence.w_foreign_water = false
				for bay_id, other_context in pairs(bay_context_by_id) do
					if bay_id ~= row.bay_id and bay_water(other_context, w.x, w.z) then
						evidence.w_foreign_water = true break
					end
				end
				if evidence.w_foreign_water then return nil end
				local dx = exact.safe_difference(w.x, e.x, row.id .. " E/W dx")
				local dz = exact.safe_difference(w.z, e.z, row.id .. " E/W dz")
				if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 then return nil end
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
				if not evidence.elbow_valid[1] or not evidence.elbow_valid[2] then
					return nil
				end
			end
			local selected = select_edge_transition(evidence)
			local resolved = {source = row, e = {x = e.x, z = e.z},
				point = selected.point, mode = selected.mode,
				w = selected.w, elbows = selected.elbows, selection = selected}
			return resolved
		end

		local function probe_edge_transition(row, edge, interval)
			local e_index = row.edge_endpoint == "from" and interval.first or
				interval.finish
			return probe_edge_transition_at(row, edge, e_index)
		end

		local canonical_index_cache = {}
		local function canonical_indices_for(perimeter)
			local cached = canonical_index_cache[perimeter]
			if cached then return cached end
			local canonical_indices = {}
			for station_index = 1, #perimeter.canonical_stations do
				local point = perimeter.canonical_stations[station_index]
				canonical_indices[key(point)] = station_index
			end
			canonical_index_cache[perimeter] = canonical_indices
			return canonical_indices
		end

		-- Census projection of the F8 attachment obligation: the same nearest-
		-- station selection with the Chebyshev distance reported instead of the
		-- at-most-one contract enforced.  attachment_probe keeps the exact
		-- compile behavior by rejecting on the reported distance.
		local function attachment_distance(attachment, edge, interval)
			local e_index = attachment.edge_endpoint == "from" and interval.first or
				interval.finish
			local e = edge.stations[e_index]
			local perimeter = perimeter_by_id[attachment.perimeter_id]
			if not perimeter then fail(attachment.id .. " references an absent perimeter") end
			local candidates = perimeter.segment_parts[
				attachment.perimeter_segment_index]
			local best, best_distance, best_index = attachment_station_candidate(e,
				candidates, canonical_indices_for(perimeter))
			return {source = attachment, e = {x = e.x, z = e.z}, a = best,
				distance = best_distance, canonical_index = best_index}
		end

		local function attachment_probe(attachment, edge, interval)
			local probed = attachment_distance(attachment, edge, interval)
			if probed.distance > 1 then return nil end
			return probed
		end

		local function selected_control_indices(edge, interval)
			local stations = {}
			for station_index = interval.first, interval.finish do
				local point = edge.stations[station_index]
				stations[#stations + 1] = {x = point.x, z = point.z}
			end
			return select_control_subsequence(edge.shifted_controls, stations)
		end

		-- Shared obligation roster for one edge: which transition/attachment
		-- rows govern its from/to endpoints.  Source-shape violations fail here
		-- for compiler and census alike; they are catalog defects, not seed
		-- outcomes.
		local function edge_obligations(edge, edge_transitions, attachment)
			local transition_source = {}
			for transition_index = 1, #edge_transitions do
				local row = edge_transitions[transition_index]
				if transition_source[row.edge_endpoint] then
					fail(edge.id .. " has two " .. row.edge_endpoint .. " transitions")
				end
				transition_source[row.edge_endpoint] = row
			end
			if attachment and transition_source[attachment.edge_endpoint] then
				fail(edge.id .. " mixes Attachment and transition at one endpoint")
			end
			if not (transition_source.from or
					attachment and attachment.edge_endpoint == "from") or
					not (transition_source.to or
					attachment and attachment.edge_endpoint == "to") then
				fail(edge.id .. " lacks a complete from/to obligation tuple")
			end
			return transition_source
		end

		-- One obligation probe per interval, shared verbatim by the compiler's
		-- interval selection and the census qualifying count so the completeness
		-- expression exists exactly once.
		local function probe_interval(transition_source, attachment, edge, candidate)
			local from_probe = transition_source.from and
				probe_edge_transition(transition_source.from, edge, candidate) or
				(attachment and attachment.edge_endpoint == "from" and
					attachment_probe(attachment, edge, candidate) or nil)
			local to_probe = transition_source.to and
				probe_edge_transition(transition_source.to, edge, candidate) or
				(attachment and attachment.edge_endpoint == "to" and
					attachment_probe(attachment, edge, candidate) or nil)
			return from_probe, to_probe
		end

		-- The authored/declared-order aperture neighborhood for one Bank
		-- incidence side: D, then its away station A and the included water
		-- station W.  resolve_terminal and the census aperture stress rows
		-- must read identical indices, so both call this.
		local function aperture_neighborhood(aperture, side)
			-- The D2 detached-shoulder admission: `A` is the next dry station
			-- away from `D` (source-authority 3.1 read literally), so an
			-- admitted detached station is skipped, exactly as the compiled
			-- bank_before_previous/bank_after_previous fields skip it.
			if side == "before" then
				local point_index = aperture.bank_first - 1
				local away_index = point_index - 1
				if aperture.authored_detached_before == away_index then
					away_index = away_index - 1
				end
				return point_index, away_index, point_index + 1
			end
			local point_index = aperture.bank_finish
			local away_index = point_index + 1
			if aperture.authored_detached_after == away_index then
				away_index = away_index + 1
			end
			return point_index, away_index, point_index - 1
		end

		local aperture_terminal_incidence, aperture_terminal_count = {}, 0
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			for terminal_index, terminal in ipairs({bank.start_terminal,
					bank.end_terminal}) do
				if terminal.kind == "aperture_dry" then
					local incidence_key = terminal_key(terminal)
					if aperture_terminal_incidence[incidence_key] then
						fail(incidence_key .. " has two Bank incidences")
					end
					aperture_terminal_incidence[incidence_key] = {bank_id = bank.id,
						terminal_index = terminal_index, bay_id = bank.bay_id}
					aperture_terminal_count = aperture_terminal_count + 1
				end
			end
		end
		if aperture_terminal_count ~= 8 then
			fail("aperture transition roster does not contain eight incidences")
		end

		return {zone_numeric = zone_numeric,
			departure_by_edge = departure_by_edge,
			perimeter_rows = perimeter_rows, perimeter_by_id = perimeter_by_id,
			island_rows = island_rows, island_by_id = island_by_id,
			provisional_edges = provisional_edges, edge_by_id = edge_by_id,
			bays = bays, bay_by_id = bay_by_id,
			aperture_rows = aperture_rows, aperture_by_bay = aperture_by_bay,
			aperture_by_id = aperture_by_id,
			wing_by_id = wing_by_id,
			bay_context_by_id = bay_context_by_id,
			cardinal = cardinal, diagonal = diagonal, point_less = point_less,
			footprint_class = footprint_class, in_bay_envelope = in_bay_envelope,
			raw_bay_water = raw_bay_water, raw_owner_count = raw_owner_count,
			bay_water = bay_water, planned_water = planned_water,
			dry_land = dry_land, wing_water = wing_water, bay_dry = bay_dry,
			final_water = final_water, bay_candidate = bay_candidate,
			water_on_right = water_on_right,
			validate_all_junction_pairs = validate_all_junction_pairs,
			attachment_by_edge = attachment_by_edge,
			land_transition_key = land_transition_key,
			declared_transition_by_key = declared_transition_by_key,
			transitions_by_edge = transitions_by_edge,
			maximal_dry_intervals = maximal_dry_intervals,
			probe_edge_transition = probe_edge_transition,
			probe_edge_transition_at = probe_edge_transition_at,
			attachment_distance = attachment_distance,
			attachment_probe = attachment_probe,
			probe_interval = probe_interval,
			aperture_neighborhood = aperture_neighborhood,
			aperture_terminal_incidence = aperture_terminal_incidence,
			selected_control_indices = selected_control_indices,
			edge_obligations = edge_obligations}
	end

	-- The complete Bank trace machinery, shared verbatim by compile_impl and
	-- the census Scan-2 completion tier (M3 surgery, plan section 6.7):
	-- terminal resolution, Wing-tail selection, Moore successor ordering,
	-- bounded reachability and the main Bank trace.  compile_impl resolves
	-- everything eagerly in its historical order; the census resolves lazily
	-- so Wing tails and trace bounds cost only where a tuple actually traces.
	-- hooks.land_transition injects the once-resolved final edge transitions
	-- (the compiler's materialized table); consumers that resolve transitions
	-- themselves -- the census builds them per tuple through
	-- resolve_land_transition -- omit the hook, and a land terminal reaching
	-- resolve_terminal without one fails as unresolved.  Scan-3a (M4)
	-- consumes wing_tails and resolve_terminal from this same seam.
	local function new_bank_tracer(stage, hooks)
		if type(hooks) ~= "table" then fail("Bank tracer needs a hooks table") end
		local bays, bay_context_by_id = stage.bays, stage.bay_context_by_id
		local perimeter_by_id = stage.perimeter_by_id
		local aperture_by_id, aperture_by_bay = stage.aperture_by_id,
			stage.aperture_by_bay
		local aperture_neighborhood = stage.aperture_neighborhood
		local aperture_terminal_incidence = stage.aperture_terminal_incidence
		local wing_by_id = stage.wing_by_id
		local cardinal = stage.cardinal
		local footprint_class, in_bay_envelope = stage.footprint_class,
			stage.in_bay_envelope
		local raw_bay_water, raw_owner_count = stage.raw_bay_water,
			stage.raw_owner_count
		local bay_water, bay_dry = stage.bay_water, stage.bay_dry
		local final_water, wing_water = stage.final_water, stage.wing_water
		local bay_candidate, water_on_right = stage.bay_candidate,
			stage.water_on_right

		local clockwise = {{x = 1, z = 0}, {x = 1, z = -1},
			{x = 0, z = -1}, {x = -1, z = -1}, {x = -1, z = 0},
			{x = -1, z = 1}, {x = 0, z = 1}, {x = 1, z = 1}}

		-- Scan-3a observation seam (M4, plan section 6.2.5).  The observer is
		-- nil on the compile path and on the Scan-2 completion tier, and every
		-- call site below is guarded by it, so decision order, selection and
		-- emitted bytes are unchanged without one -- which the standing
		-- partition and extreme regimes prove.  With an observer the tracer
		-- additionally reports, without deciding anything differently: the
		-- realized per-probe step class, the per-step selection class, the
		-- reachability frame and stack maxima, and the complete Wing
		-- candidate/pair/wedge analysis the F5 table asks for but the
		-- stop-at-first enumeration cannot expose from outside.
		-- Probing the remaining successors of a branch step costs up to seven
		-- extra bounded DFS runs on top of the one to seven the decision itself
		-- pays, so it is budgeted per Bank rather than left open: the cost gate
		-- is projected from seeds whose head Banks branch zero times, and an
		-- unbudgeted observer would make that projection say nothing about a
		-- seed that branches often.  Steps past the budget are reported as
		-- unprobed, never as zero -- a bound this census keeps must be visible
		-- in the artifact, not implied by a missing row.
		local branch_probe_budget = 64

		local observer = nil
		local function set_observer(value)
			if value ~= nil then
				if type(value) ~= "table" or getmetatable(value) ~= nil then
					fail("Bank tracer observer is malformed")
				end
				-- `reachable` compares against these on every pushed frame and
				-- `observe_selection` decrements the probe budget, so a missing
				-- counter has to be refused here rather than surface as an
				-- arithmetic error from inside a bounded DFS.
				if type(value.max_frames) ~= "number" or
						type(value.max_stack) ~= "number" then
					fail("Bank tracer observer lacks its frame counters")
				end
				value.probes_left = branch_probe_budget
			end
			observer = value
		end

		local function sequence_less(a, b)
			local count = math.min(#a, #b)
			for index = 1, count do
				if point_less(a[index], b[index]) then return true end
				if point_less(b[index], a[index]) then return false end
			end
			return #a < #b
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

		-- Every per-pair exclusion cause the F5 table distinguishes, plus the two
		-- shapes it names only as one compound "structural" row.  Declared here
		-- so the analysis record and the census vocabulary cannot drift.
		local wing_exclusion_causes = {"shared_predecessor", "interior_overlap",
			"intra_tail_x_cross", "inter_tail_x_cross",
			"wedge_nonsimple_or_zero_area", "wedge_radius_above_five",
			"wedge_nonwing_water"}

		local wing_tail_cache = {}
		-- `wanted_rank` selects the wanted_rank-th wedge-valid pair of the
		-- same enumeration in the same order.  Rank 1 is the compile path's
		-- selection, byte-identical to the historical behavior and the only
		-- rank that caches or reports to the observer; rank 2 exists for the
		-- R21 alternative-pair probe (contracts 9.1), runs only on the dead
		-- condition, and returns nil -- never a reject -- when no usable
		-- second pair exists.
		local function resolve_wing_tails(wing_id, wanted_rank)
			local wing = wing_by_id[wing_id]
			if not wing then fail(wing_id .. " references an absent Wing") end
			-- With an observer the pair enumeration runs to exhaustion instead
			-- of stopping at the first wedge-valid pair.  The *selection* is
			-- untouched -- it stays the first valid pair in the same order -- and
			-- every failure still fails; the analysis is written to the observer
			-- before the failure propagates, so a dead Wing is a recorded F5
			-- class at the tracer edge rather than a lost measurement.
			local analysis = wanted_rank == 1 and observer and observer.wing and
				{id = wing_id, bay_id = wing.bay_id, sides = {}, excluded = {},
				raw_pair_count = 0, structural_pair_count = 0,
				wedge_valid_count = 0} or nil
			if analysis then
				for index = 1, #wing_exclusion_causes do
					analysis.excluded[wing_exclusion_causes[index]] = 0
				end
			end
			local function record(class, message)
				if analysis then
					analysis.class = class
					analysis.detail = message
					observer.wing(analysis)
				end
				return message
			end
			local context = bay_context_by_id[wing.bay_id]
			local radius = wing.head_half_width
			local box = {min_x = math.min(wing.head.x, wing.junction.x) - radius,
				max_x = math.max(wing.head.x, wing.junction.x) + radius,
				min_z = math.min(wing.head.z, wing.junction.z) - radius,
				max_z = math.max(wing.head.z, wing.junction.z) + radius}
			local selected = {}
			for _, side in ipairs({"negative", "positive"}) do
				local best, best_projection, candidate_count = nil, nil, 0
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
							if projection >= 0 and projection < length and signed then
								candidate_count = candidate_count + 1
								if not best or projection > best_projection or
										projection == best_projection and
										point_less(point, best) then
									best, best_projection = point, projection
								end
							end
						end
					end
				end
				if analysis then
					analysis.sides[side] = {k_count = candidate_count, k = best,
						chebyshev = best and chebyshev(best, wing.junction) or nil}
				end
				if not best then
					fail(record("wing_missing_k_reject",
						wing.id .. " has no " .. side .. " K"))
				end
				if chebyshev(best, wing.junction) > 4 then
					fail(record("wing_k_chebyshev_above_four_reject",
						wing.id .. " " .. side .. " K exceeds current bound"))
				end
				selected[side] = best
			end
			if analysis then
				analysis.radius = 1 + math.max(
					chebyshev(selected.negative, wing.junction),
					chebyshev(selected.positive, wing.junction))
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
				if analysis then
					analysis.sides[side].path_count = #paths[side]
				end
				-- The F5 table has no row for this: section 3.4 posits two
				-- *complete* distance-layer DAGs and never asks what an empty one
				-- means.  Its own class, so an occurrence lands as an uncovered
				-- configuration (plan section 6.4) instead of inside a neighbour.
				if #paths[side] == 0 then
					fail(record("wing_no_complete_tail_reject",
						wing.id .. " lacks a complete " .. side .. " tail"))
				end
			end
			if analysis then
				analysis.raw_pair_count = #paths.negative * #paths.positive
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
			-- Returns the exclusion cause alongside the verdict.  The compile path
			-- reads only the verdict, so the fixed order below -- polygon shape,
			-- then radius, then wedge occupancy -- is the compiler's own and a
			-- pair failing two clauses is attributed to the first.
			local function wedge_valid(negative, positive)
				local polygon = copy_points(negative)
				for index = #positive - 1, 1, -1 do
					polygon[#polygon + 1] = {x = positive[index].x, z = positive[index].z}
				end
				polygon[#polygon + 1] = {x = polygon[1].x, z = polygon[1].z}
				if exact.signed_area2(polygon) == 0 or not exact.polygon_simple(polygon) then
					return false, "wedge_nonsimple_or_zero_area"
				end
				local radius = 1 + math.max(chebyshev(negative[1], wing.junction),
					chebyshev(positive[1], wing.junction))
				if radius > 5 then return false, "wedge_radius_above_five" end
				local exempt = {}
				for index = 1, #negative do exempt[key(negative[index])] = true end
				for index = 1, #positive do exempt[key(positive[index])] = true end
				for x = wing.junction.x - radius, wing.junction.x + radius do
					for z = wing.junction.z - radius, wing.junction.z + radius do
						if exact.polygon_class(x, z, polygon) >= 0 and
								not exempt[x .. ":" .. z] and
								not wing_water(context, wing, x, z) then
							return false, "wedge_nonwing_water"
						end
					end
				end
				return true
			end
			local function exclude(cause)
				if analysis then
					analysis.excluded[cause] = analysis.excluded[cause] + 1
				end
			end
			local chosen_negative, chosen_positive
			local pair_rank, structural_rank, wedge_seen = 0, 0, 0
			for negative_index = 1, #paths.negative do
				local negative = paths.negative[negative_index]
				local negative_diagonals = tail_diagonals(negative)
				if not negative_diagonals then
					-- Every pair on this negative path dies of the same intra-tail
					-- X-cross; the compile path never enters the inner loop, so the
					-- ranks advance here instead of there.
					pair_rank = pair_rank + #paths.positive
					for _ = 1, #paths.positive do exclude("intra_tail_x_cross") end
				else
					local negative_points = {}
					for index = 1, #negative - 1 do negative_points[key(negative[index])] = true end
					for positive_index = 1, #paths.positive do
						local positive = paths.positive[positive_index]
						pair_rank = pair_rank + 1
						local cause = key(negative[#negative - 1]) ==
							key(positive[#positive - 1]) and "shared_predecessor" or nil
						local diagonals = {}
						for cell, slope in pairs(negative_diagonals) do diagonals[cell] = slope end
						for index = 1, #positive - 1 do
							if negative_points[key(positive[index])] then
								cause = cause or "interior_overlap" break
							end
							if add_diagonal(diagonals, positive[index], positive[index + 1]) == false then
								cause = cause or "inter_tail_x_cross" break
							end
						end
						if cause then
							exclude(cause)
						else
							structural_rank = structural_rank + 1
							if analysis then
								analysis.structural_pair_count =
									analysis.structural_pair_count + 1
							end
							local valid, wedge_cause = wedge_valid(negative, positive)
							if valid then
								wedge_seen = wedge_seen + 1
								if analysis then
									analysis.wedge_valid_count =
										analysis.wedge_valid_count + 1
								end
								if not chosen_negative and
										wedge_seen == wanted_rank then
									chosen_negative, chosen_positive = negative, positive
									if analysis then
										analysis.selected_raw_rank = pair_rank
										analysis.selected_structural_rank = structural_rank
									end
								end
								if chosen_negative and not analysis then break end
							else
								exclude(wedge_cause)
							end
						end
					end
				end
				if chosen_negative and not analysis then break end
			end
			if not chosen_negative then
				-- No wedge-valid pair at the wanted rank.  For the compile
				-- rank this is the F5 seed reject; for the R21 alternative
				-- probe it is the measured answer "no alternative exists"
				-- and must stay a nil, never a reject.
				if wanted_rank > 1 then return nil end
				fail(record("wing_no_wedge_valid_joint_tail_pair_reject",
					wing.id .. " has no wedge-valid joint tail pair"))
			end
			local length = select(3, wing_terms(wing, wing.junction))
			local path_bound = exact.ceil_isqrt(length) + 1
			if analysis then
				analysis.path_bound = path_bound
				analysis.sides.negative.tail_length = #chosen_negative
				analysis.sides.positive.tail_length = #chosen_positive
			end
			if #chosen_negative > path_bound or #chosen_positive > path_bound then
				-- The bound applies to the alternative too: a pair above it
				-- is not a usable selection, so the probe reads it as no
				-- alternative rather than as a reject.
				if wanted_rank > 1 then return nil end
				fail(record("wing_path_bound_exceeded_reject",
					wing.id .. " joint tail exceeds finite path bound"))
			end
			record("wing_wedge_valid_select", nil)
			return {negative = chosen_negative,
				positive = chosen_positive, negative_k = selected.negative,
				positive_k = selected.positive}
		end
		local function wing_tails(wing_id)
			local cached = wing_tail_cache[wing_id]
			if cached then return cached end
			local resolved = resolve_wing_tails(wing_id, 1)
			wing_tail_cache[wing_id] = resolved
			return resolved
		end
		-- The R21 probe's second wedge-valid pair: uncached, observer-free,
		-- nil when the Wing has no usable alternative (contracts 9.1 -- the
		-- probe runs only on the dead condition, so its cost is
		-- occupancy-driven).
		local function wing_alternative_tails(wing_id)
			return resolve_wing_tails(wing_id, 2)
		end

		-- The one resolved-terminal mapping for a materialized land
		-- transition, consumed by resolve_terminal's land branch and directly
		-- by the census tuple tier for its per-tuple candidate resolutions,
		-- so the field shape trace_bank reads exists exactly once.
		local function resolve_land_transition(cache_key, materialized)
			local resolved = {id = cache_key,
				bay_id = materialized.source.bay_id,
				point = {x = materialized.point.x, z = materialized.point.z},
				previous = {x = materialized.previous.x,
					z = materialized.previous.z},
				transition_mode = materialized.mode,
				transition_e = {x = materialized.e.x, z = materialized.e.z},
				edge_id = materialized.source.edge_id,
				edge_endpoint = materialized.source.edge_endpoint,
				transition_id = materialized.source.id}
			if materialized.w then
				resolved.transition_w = {x = materialized.w.x,
					z = materialized.w.z}
			end
			return resolved
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
				local incidence = aperture_terminal_incidence[cache_key]
				if not incidence then fail(cache_key .. " lacks a Bank incidence") end
				local aperture = aperture_by_id[terminal.aperture_id]
				if not aperture then fail(cache_key .. " references an absent aperture") end
				resolved.bay_id = aperture.source.bay_id
				if incidence.bay_id ~= resolved.bay_id then
					fail(cache_key .. " incidence has the wrong Bay")
				end
				local context = bay_context_by_id[resolved.bay_id]
				local perimeter = perimeter_by_id[aperture.source.perimeter_id]
				local point_index, away_index, water_index =
					aperture_neighborhood(aperture, terminal.side)
				if away_index < 1 or away_index > #perimeter.stations or
						water_index < 1 or water_index > #perimeter.stations then
					fail(cache_key .. " authored aperture neighborhood is absent")
				end
				local d = copy_points({perimeter.stations[point_index]})[1]
				local a = copy_points({perimeter.stations[away_index]})[1]
				local evidence = {id = cache_key, d = d, a = a,
					direct_candidate = bay_candidate(context, d.x, d.z)}
				if not evidence.direct_candidate then
					local w = perimeter.stations[water_index]
					evidence.w = {x = w.x, z = w.z}
					evidence.d_class = footprint_class(d.x, d.z)
					evidence.d_cardinal_water = false
					for direction_index = 1, #cardinal do
						local direction = cardinal[direction_index]
						local nx = checked_coordinate(d.x, direction.x,
							cache_key .. " D cardinal x")
						local nz = checked_coordinate(d.z, direction.z,
							cache_key .. " D cardinal z")
						if final_water(nx, nz) then
							evidence.d_cardinal_water = true break
						end
					end
					local raw_count, raw_owner = raw_owner_count(w.x, w.z)
					evidence.w_raw_owned_by_bay = raw_count == 1 and raw_owner == context
					local final_count, final_owner = 0, nil
					for other_bay_index = 1, #bays do
						local other = bay_context_by_id[bays[other_bay_index].source.id]
						if bay_water(other, w.x, w.z) then
							final_count, final_owner = final_count + 1, other
						end
					end
					evidence.w_final_owned_by_bay = final_count == 1 and
						final_owner == context and final_water(w.x, w.z)
					evidence.w_foreign_water = final_count ~= 1 or final_owner ~= context
					evidence.w_aperture_included =
						aperture.included[key(w)] == true
					local elbows = {{x = w.x, z = d.z}, {x = d.x, z = w.z}}
					evidence.elbow_valid = {}
					for elbow_index = 1, 2 do
						local elbow = elbows[elbow_index]
						exact.point(elbow, cache_key .. " shoulder elbow")
						evidence.elbow_valid[elbow_index] =
							footprint_class(elbow.x, elbow.z) == 1 and
								bay_dry(context, elbow.x, elbow.z) and
								bay_candidate(context, elbow.x, elbow.z)
					end
				end
				local selection = select_aperture_transition(evidence)
				resolved.point = {x = selection.d.x, z = selection.d.z}
				resolved.previous = selection.mode == "direct" and
					{x = selection.a.x, z = selection.a.z} or
					{x = selection.d.x, z = selection.d.z}
				resolved.aperture_transition = selection
				resolved.aperture_id = terminal.aperture_id
				resolved.aperture_side = terminal.side
				resolved.authored_index = point_index - 1
				resolved.authored_away_index = away_index - 1
			elseif terminal.kind == "land_edge_transition" then
				local materialized = hooks.land_transition and
					hooks.land_transition(cache_key) or nil
				if not materialized then
					fail(cache_key .. " lacks a once-resolved final edge transition")
				end
				resolved = resolve_land_transition(cache_key, materialized)
			elseif terminal.kind == "wing_junction_tail_side" then
				local wing = wing_by_id[terminal.wing_id]
				if not wing then fail(cache_key .. " references an absent Wing tail") end
				local tails = wing_tails(terminal.wing_id)
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

		-- `probe_sink` is the Scan-3a per-probe observer and is nil everywhere
		-- else, including inside the reachability DFS -- only the materialized
		-- main trace realizes a step class.  The predicate chain below is the
		-- same six tests in the same short-circuit order the single `and`
		-- expression used; naming the first failing one costs an interned-string
		-- assignment and removes the double evaluation an observer would
		-- otherwise need.
		local function ordered_successors(context, previous, current, seen_states,
				seen_columns, diagonals, probe_sink)
			local back_x, back_z = previous.x - current.x, previous.z - current.z
			local back_index
			for index = 1, 8 do
				if clockwise[index].x == back_x and clockwise[index].z == back_z then
					back_index = index break
				end
			end
			if not back_index then fail("Bay-bank start half-edge is not eight-connected") end
			local previous_key = key(previous)
			local result = {}
			for offset = 1, 8 do
				local direction_index = ((back_index - offset - 1) % 8) + 1
				local direction = clockwise[direction_index]
				local following = {x = current.x + direction.x, z = current.z + direction.z}
				local following_key = key(following)
				local directed_key = state_key(current, following)
				local cell, slope = diagonal_signature(current, following)
				local outcome
				if following_key == previous_key then
					outcome = "previous"
				elseif seen_states[directed_key] then
					outcome = "seen_state"
				elseif seen_columns[following_key] then
					outcome = "seen_column"
				elseif cell and diagonals[cell] and diagonals[cell] ~= slope then
					outcome = "x_cross"
				elseif not bay_candidate(context, following.x, following.z) then
					outcome = "noncandidate"
				elseif not water_on_right(context, current, following) then
					outcome = "water_side"
				else
					outcome = "admitted"
					result[#result + 1] = following
				end
				if probe_sink then probe_sink(direction_index, outcome) end
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
			-- The section 6.2.3 Bank stress scalars, sampled at exactly the two
			-- points where the counters change -- here and after each push -- so
			-- the deepest frame is observed even when the very next iteration
			-- returns true.  Sampling at the top of the loop instead would miss
			-- the last push of every successful probe, which is the one the caps
			-- are checked against and the one Scan-4's extremal seed set is
			-- chosen on.  Suspended while the observer probes the *remaining*
			-- successors of a branch, whose frames are an artefact of observing.
			if observer and not observer.suspend then
				observer.max_frames = math.max(observer.max_frames, pushed_frames)
				observer.max_stack = math.max(observer.max_stack, #stack)
			end
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
					if observer and not observer.suspend then
						observer.max_frames = math.max(observer.max_frames, pushed_frames)
						observer.max_stack = math.max(observer.max_stack, #stack)
					end
				else
					seen_states[frame.state], seen_columns[frame.column] = nil, nil
					if frame.diagonal then diagonals[frame.diagonal] = nil end
					stack[#stack] = nil
				end
			end
			return false
		end

		-- The three cap messages an observation probe is allowed to hit.  A probe
		-- that fails any other way is a defect, not an exhausted budget, and is
		-- re-raised: `pcall` here is a cap tolerance, never a sink.
		local probe_tolerated_failures = {
			"Bay-bank reachability frame cap exhausted",
			"Bay-bank reachability stack cap exhausted",
			"Bay-bank main trace cap exhausted",
		}

		-- The F3 branch-occupancy observation (analysis section 3-F3: "logged by
		-- the census ... not scanned repeatedly").  `select_first_reachable`
		-- stops at the first reachable successor, so multi-reachability needs
		-- the remaining ones probed; those probes are observation only, so they
		-- run with the frame counters suspended -- a cap they exhaust must never
		-- turn an otherwise complete Bank into a reject.
		local function observe_selection(sink, context, current, target, successors,
				chosen_index, seen_states, seen_columns, diagonals)
			local width = #successors
			if width == 0 then return sink("zero_admitted_successors", 0, 0) end
			if not chosen_index then return sink("branch_none_reachable", width, 0) end
			if width == 1 then
				-- The §3-F3 asymmetry worth its own class: a lone admitted
				-- successor is taken with no terminal-reachability test at all.
				-- Reachability is not merely unmeasured here, it is not part of
				-- the decision, so no count is reported.
				return sink("single_admitted_untested", 1, nil)
			end
			local class = chosen_index == 1 and "branch_first_reachable" or
				"branch_later_reachable"
			if observer.probes_left <= 0 then return sink(class, width, nil) end
			observer.probes_left = observer.probes_left - 1
			local reachable_count, complete = 1, true
			observer.suspend = true
			for index = chosen_index + 1, width do
				local ok, value = pcall(reachable, context, current,
					successors[index], target, seen_states, seen_columns, diagonals)
				if not ok then
					local message = tostring(value)
					local tolerated = false
					for entry = 1, #probe_tolerated_failures do
						if message:find(probe_tolerated_failures[entry], 1, true) then
							tolerated = true break
						end
					end
					if not tolerated then
						observer.suspend = nil
						error(value, 0)
					end
					complete = false break
				end
				if value then reachable_count = reachable_count + 1 end
			end
			observer.suspend = nil
			return sink(class, width, complete and reachable_count or nil)
		end

		local function trace_bank(bank, start, finish)
			local context = bay_context_by_id[bank.bay_id]
			ensure_trace_bounds(context)
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
			elseif start.aperture_transition and
					start.aperture_transition.mode == "diagonal_shoulder" then
				local shoulder = start.aperture_transition
				if not aperture_tail_water_side(shoulder.d, shoulder.t,
						shoulder.w, bank.water_side) then
					fail(bank.id .. " start shoulder has water on the wrong side")
				end
				points[1] = {x = shoulder.d.x, z = shoulder.d.z}
				points[2] = {x = shoulder.t.x, z = shoulder.t.z}
				seen_columns[key(points[1])], seen_columns[key(points[2])] = true, true
				seen_states[state_key(points[1], points[2])] = true
				local cell = add_diagonal(diagonals, points[1], points[2])
				if cell == false then fail(bank.id .. " start shoulder X-crosses") end
				previous, current = points[1], points[2]
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
			elseif finish.aperture_transition and
					finish.aperture_transition.mode == "diagonal_shoulder" then
				local shoulder = finish.aperture_transition
				if not aperture_tail_water_side(shoulder.t, shoulder.d,
						shoulder.w, bank.water_side) then
					fail(bank.id .. " end shoulder has water on the wrong side")
				end
				target = {x = shoulder.t.x, z = shoulder.t.z}
				suffix = {{x = shoulder.t.x, z = shoulder.t.z},
					{x = shoulder.d.x, z = shoulder.d.z}}
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
			local probe_sink = observer and observer.probe or nil
			local selection_sink = observer and observer.selection or nil
			local steps = 0
			while key(current) ~= key(target) do
				local successors = ordered_successors(context, previous, current,
					seen_states, seen_columns, diagonals, probe_sink)
				local following, reachability = nil, {}
				local chosen_index
				if #successors == 1 then
					following = successors[1]
					chosen_index = 1
				elseif #successors > 1 then
					following, chosen_index = select_first_reachable(successors,
						function(successor)
							local value = reachable(context, current, successor, target,
								seen_states, seen_columns, diagonals)
							reachability[#reachability + 1] = key(successor) .. "=" ..
								tostring(value)
							return value
						end)
				end
				if selection_sink then
					observe_selection(selection_sink, context, current, target,
						successors, chosen_index, seen_states, seen_columns, diagonals)
				end
				if not following then
					local identities = {}
					for successor_index = 1, #successors do
						identities[successor_index] = key(successors[successor_index])
					end
					local neighbor_evidence = {}
					for direction_index = 1, #clockwise do
						local direction = clockwise[direction_index]
						local candidate = {x = current.x + direction.x,
							z = current.z + direction.z}
						local directed_key = state_key(current, candidate)
						local candidate_key = key(candidate)
						local cell, slope = diagonal_signature(current, candidate)
						local raw_owners, final_owners = {}, {}
						for bay_index = 1, #bays do
							local other = bay_context_by_id[bays[bay_index].source.id]
							if raw_bay_water(other, candidate.x, candidate.z) then
								raw_owners[#raw_owners + 1] = other.bay.source.id
							end
							if bay_water(other, candidate.x, candidate.z) then
								final_owners[#final_owners + 1] = other.bay.source.id
							end
						end
						neighbor_evidence[direction_index] = table.concat({candidate_key,
							"candidate=" .. tostring(bay_candidate(context,
								candidate.x, candidate.z)),
							"right=" .. tostring(water_on_right(context, current, candidate)),
							"footprint=" .. tostring(footprint_class(candidate.x,
								candidate.z)),
							"dry=" .. tostring(bay_dry(context, candidate.x, candidate.z)),
							"envelope=" .. tostring(in_bay_envelope(context,
								candidate.x, candidate.z)),
							"state=" .. tostring(seen_states[directed_key] == true),
							"column=" .. tostring(seen_columns[candidate_key] == true),
							"diagonal=" .. tostring(not cell or not diagonals[cell] or
								diagonals[cell] == slope),
							"raw=" .. table.concat(raw_owners, "+"),
							"final=" .. table.concat(final_owners, "+")}, ":")
					end
					local start_mode = start.transition_mode or
						(start.aperture_transition and start.aperture_transition.mode) or "other"
					local finish_mode = finish.transition_mode or
						(finish.aperture_transition and finish.aperture_transition.mode) or "other"
					local function terminal_detail(resolved)
						if resolved.transition_e then
							return "land:E=" .. key(resolved.transition_e) ..
								",P=" .. key(resolved.point)
						end
						if resolved.aperture_transition then
							return "aperture:D=" .. key(resolved.aperture_transition.d) ..
								",A=" .. key(resolved.aperture_transition.a)
						end
						if resolved.tail then
							return "wing:K=" .. key(resolved.k) ..
								",junction=" .. key(resolved.point)
						end
						return "other:" .. tostring(resolved.id)
					end
					local start_detail, finish_detail = terminal_detail(start),
						terminal_detail(finish)
					fail(bank.id .. " cannot reach its target previous/current/target=" ..
						key(previous) .. "/" .. key(current) .. "/" .. key(target) ..
						" terminal_modes=" .. start_mode .. "/" .. finish_mode ..
						" terminal_details=[" .. start_detail .. ";" .. finish_detail .. "]" ..
						" successors=" .. table.concat(identities, ",") ..
						" reachable=" .. table.concat(reachability, ",") ..
						" neighbors=[" .. table.concat(neighbor_evidence, ";") .. "]" ..
						" steps=" .. steps)
				end
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
			return points
		end

		return {resolve_terminal = resolve_terminal,
			resolve_land_transition = resolve_land_transition,
			trace_bank = trace_bank, wing_tails = wing_tails,
			wing_alternative_tails = wing_alternative_tails,
			terminal_cache = terminal_cache, set_observer = set_observer,
			wing_exclusion_causes = wing_exclusion_causes}
	end

	-- The Whole tier's interval classifier core, pure over prepared row-run
	-- tables so the synthetic gate KATs can drive it directly (contracts
	-- 9.4).  `prepared` carries:
	--   footprint_rows: [z] -> sorted {first, finish} runs (the merged
	--     footprint universe);
	--   face_rows: [z] -> {first, finish, id, zone_id} runs of the composed
	--     simple face polygons;
	--   water_rows: [z] -> {first, finish, owner} runs of final planned
	--     water (the caller has already applied the perimeter-equality
	--     aperture rule, so these are literal planned-water columns);
	--   declared: ["x:z"] -> {zone_id = true} the declared seam owners
	--     (shared-edge stations and perimeter-span vertices);
	--   check: optional function(z, x, water_owner_or_nil, face_runs) ->
	--     boolean -- the per-interval representation cross-check behind the
	--     m count; nil skips it and m stays 0.
	-- Classification per interval (completeness analysis F10/F11): water
	-- single owner or dry single face -> whole_single_owner_select; dry
	-- multi-face exactly matching the declared seam at every column ->
	-- whole_declared_seam_select; dry uncovered -> whole_gap_reject (g);
	-- anything else -> whole_undeclared_multiplicity_reject (water overlap
	-- counts o, undeclared dry multiplicity counts r per column).  m counts
	-- the columns of every interval whose `check` disagreed -- the H38
	-- normalization's own measured invariance.
	--
	-- It sits here, above compile_impl, together with polygon_row_runs and
	-- the prepared-table constructors below, because the section-11
	-- production Whole gate made compile_impl its second caller: the census
	-- Scan-4 Whole tier and the compiler ask the identical functions, so the
	-- two readings of the footprint can never drift apart.
	-- Seam inheritance (contracts 11.9, family C): a column claimed by
	-- exactly two faces, BOTH as boundary stations of their rings (the
	-- covering runs carry their winding class), cardinally adjacent to a
	-- declared-seam column of the identical zone pair, inherits that
	-- declaration.  whole_declared derives only from final shared-edge
	-- stations and perimeter-span vertices and never declared the measured
	-- dip tips (the 11.9 anatomy: 7/7 witnesses boundary-boundary with the
	-- same-pair declaration at cardinal distance 1, never interior, never a
	-- third claimant).  An interior claimant, a third face, an identical
	-- zone pair or no adjacent same-pair declaration inherits nothing and
	-- stays the loud multiplicity reject.
	local function inherits_declared_seam(prepared, z, x, covering_faces)
		if #covering_faces ~= 2 then return false end
		if covering_faces[1].class ~= 0 or covering_faces[2].class ~= 0 then
			return false
		end
		local zone_a = covering_faces[1].zone_id
		local zone_b = covering_faces[2].zone_id
		if zone_a == zone_b then return false end
		local neighbours = {{x - 1, z}, {x + 1, z}, {x, z - 1}, {x, z + 1}}
		for index = 1, 4 do
			local owners = prepared.declared[neighbours[index][1] .. ":" ..
				neighbours[index][2]]
			if owners and owners[zone_a] and owners[zone_b] then
				local exact_pair = true
				for owner in pairs(owners) do
					if owner ~= zone_a and owner ~= zone_b then
						exact_pair = false
						break
					end
				end
				if exact_pair then return true end
			end
		end
		return false
	end

	local function census_whole_classify(prepared)
		local classes = {}
		local function note(class, z, first, finish)
			local entry = classes[class]
			if not entry then
				entry = {intervals = 0, columns = 0}
				classes[class] = entry
			end
			entry.intervals = entry.intervals + 1
			entry.columns = entry.columns + (finish - first + 1)
			if not entry.witness then
				entry.witness = "z=" .. z .. ":x=" .. first .. ".." .. finish
			end
		end
		local totals = {g = 0, o = 0, r = 0, m = 0, columns = 0,
			planned_water = 0, dry = 0}
		local zs = {}
		for z in pairs(prepared.footprint_rows) do zs[#zs + 1] = z end
		table.sort(zs)
		for z_index = 1, #zs do
			local z = zs[z_index]
			local footprint_runs = prepared.footprint_rows[z]
			local face_runs = prepared.face_rows[z] or {}
			local water_runs = prepared.water_rows[z] or {}
			for footprint_index = 1, #footprint_runs do
				local footprint_run = footprint_runs[footprint_index]
				local breaks = {footprint_run.first, footprint_run.finish + 1}
				for _, collection in ipairs({face_runs, water_runs}) do
					for index = 1, #collection do
						local run = collection[index]
						if run.finish >= footprint_run.first and
								run.first <= footprint_run.finish then
							breaks[#breaks + 1] =
								math.max(run.first, footprint_run.first)
							breaks[#breaks + 1] =
								math.min(run.finish, footprint_run.finish) + 1
						end
					end
				end
				table.sort(breaks)
				local unique = {}
				for index = 1, #breaks do
					if index == 1 or breaks[index] ~= breaks[index - 1] then
						unique[#unique + 1] = breaks[index]
					end
				end
				for index = 1, #unique - 1 do
					local first, finish = unique[index], unique[index + 1] - 1
					local length = finish - first + 1
					local covering_faces, covering_water = {}, {}
					for run_index = 1, #face_runs do
						local run = face_runs[run_index]
						if first >= run.first and first <= run.finish then
							covering_faces[#covering_faces + 1] = run
						end
					end
					for run_index = 1, #water_runs do
						local run = water_runs[run_index]
						if first >= run.first and first <= run.finish then
							covering_water[#covering_water + 1] = run
						end
					end
					totals.columns = totals.columns + length
					local class
					if #covering_water >= 1 then
						totals.planned_water = totals.planned_water + length
						if #covering_water > 1 then
							totals.o = totals.o + length
							class = "whole_undeclared_multiplicity_reject"
						else
							class = "whole_single_owner_select"
						end
					else
						totals.dry = totals.dry + length
						if #covering_faces == 0 then
							totals.g = totals.g + length
							class = "whole_gap_reject"
						elseif #covering_faces == 1 then
							class = "whole_single_owner_select"
						else
							-- The declared-seam check is per column: the
							-- covering faces are interval-constant, the
							-- declared owner sets are not.  A column the
							-- direct check refuses may still inherit an
							-- adjacent same-pair declaration (contracts
							-- 11.9, family C -- inherits_declared_seam
							-- above); everything else counts r and stays
							-- the loud multiplicity reject.
							local valid_all = true
							for x = first, finish do
								local owners = prepared.declared[x .. ":" .. z]
								local valid = owners ~= nil
								local seen = {}
								for face_index = 1, #covering_faces do
									local owner = covering_faces[face_index].zone_id
									if seen[owner] or not owners or
											not owners[owner] then
										valid = false
									end
									seen[owner] = true
								end
								if valid then
									for owner in pairs(owners) do
										if not seen[owner] then
											valid = false break
										end
									end
								end
								if not valid and inherits_declared_seam(
										prepared, z, x, covering_faces) then
									valid = true
								end
								if not valid then
									valid_all = false
									totals.r = totals.r + 1
								end
							end
							class = valid_all and "whole_declared_seam_select" or
								"whole_undeclared_multiplicity_reject"
						end
					end
					if prepared.check then
						local water_owner = #covering_water == 1 and
							covering_water[1].owner or nil
						if not prepared.check(z, first, water_owner,
								covering_faces) then
							totals.m = totals.m + length
						end
					end
					note(class, z, first, finish)
				end
			end
		end
		totals.classes = classes
		return totals
	end

	-- The polygon row-run normalization of the H38 method: every station of
	-- the closed polygon is a class-0 single-column run of its row, and
	-- every gap between consecutive boundary columns whose first column is
	-- interior is a class-1 run.  The class is constant between consecutive
	-- boundary columns of a row for EVERY closed eight-connected lattice
	-- ring, simple or not: an edge is a unit step, so any edge meeting the
	-- horizontal line of an integer row does so at a station on that row --
	-- which is a boundary column -- and the winding class
	-- (exact.indexed_polygon_class, closure required, simplicity not) can
	-- only change across the curve.  That is what makes the interval an
	-- exhaustive proof rather than a sample, and what lets the section-11.5-C
	-- winding row derivation reuse this function unchanged for an
	-- appendix-accepted face: `repeat_tolerant` (set exactly for faces the
	-- two-tier validator accepted with appendixes) deduplicates the row
	-- boundary column a zero-width appendix station contributes twice; on
	-- every other ring a repeated column stays the loud failure it was.
	local function polygon_row_runs(points, label, repeat_tolerant)
		if #points < 4 or key(points[1]) ~= key(points[#points]) then
			fail(label .. " row-run normalization needs a closed polygon")
		end
		local polygon_index = exact.polygon_index(points)
		local boundary = {}
		for index = 1, #points - 1 do
			local point = points[index]
			local row = boundary[point.z]
			if not row then row = {} boundary[point.z] = row end
			row[#row + 1] = point.x
		end
		local result = {}
		for z, xs in pairs(boundary) do
			table.sort(xs)
			local runs = {}
			local previous
			for index = 1, #xs do
				local x = xs[index]
				if x == previous then
					if not repeat_tolerant then
						fail(label .. " repeats a row boundary column")
					end
				else
					if previous and x > previous + 1 then
						local first, finish = previous + 1, x - 1
						if exact.indexed_polygon_class(polygon_index, first, z) > 0 then
							runs[#runs + 1] = {first = first, finish = finish,
								class = 1}
						end
					end
					runs[#runs + 1] = {first = x, finish = x, class = 0}
					previous = x
				end
			end
			result[z] = runs
		end
		return result, polygon_index
	end

	-- The Whole tier's prepared tables (contracts 9.1 and section 11), one
	-- constructor per table, shared verbatim by census_scan4's Whole tier
	-- and compile_impl's production Whole gate.

	-- Footprint universe: the merged row runs of the perimeter and island
	-- rings.
	local function whole_footprint_rows(stage)
		local footprint_rows = {}
		local function add_footprint(points, label)
			local ring = copy_points(points)
			if key(ring[1]) ~= key(ring[#ring]) then
				ring[#ring + 1] = {x = ring[1].x, z = ring[1].z}
			end
			local rows = polygon_row_runs(ring, label)
			for z, runs in pairs(rows) do
				local merged = footprint_rows[z]
				if not merged then merged = {} footprint_rows[z] = merged end
				for run_index = 1, #runs do
					merged[#merged + 1] = runs[run_index]
				end
			end
		end
		for index = 1, #stage.perimeter_rows do
			add_footprint(stage.perimeter_rows[index].stations,
				stage.perimeter_rows[index].id)
		end
		for index = 1, #stage.island_rows do
			add_footprint(stage.island_rows[index].stations,
				stage.island_rows[index].id)
		end
		-- Merge overlapping footprint runs per row into a disjoint
		-- ascending cover, keeping boundary columns distinguishable:
		-- the class-0 single-column runs stay their own intervals
		-- through the break machinery, so only the cover has to be
		-- disjoint.
		for z, runs in pairs(footprint_rows) do
			table.sort(runs, function(a, b)
				return a.first < b.first or
					(a.first == b.first and a.finish < b.finish)
			end)
			local merged = {}
			for index = 1, #runs do
				local run = runs[index]
				local last = merged[#merged]
				if last and run.first <= last.finish + 1 then
					if run.finish > last.finish then
						last.finish = run.finish
					end
				else
					merged[#merged + 1] = {first = run.first,
						finish = run.finish}
				end
			end
			footprint_rows[z] = merged
		end
		return footprint_rows
	end

	-- Water rows: per Bay the raw run mask plus its fill points,
	-- restricted to planned water by the perimeter-equality rule --
	-- a class-0 footprint boundary column is planned water only when
	-- the Bay's aperture includes it (planned_water's own rule,
	-- evaluated here from the same fields without the point cache).
	local function whole_water_rows(stage)
		local boundary_columns = {}
		do
			local function mark_ring(points)
				for index = 1, #points do
					boundary_columns[key(points[index])] = true
				end
			end
			for index = 1, #stage.perimeter_rows do
				mark_ring(stage.perimeter_rows[index].stations)
			end
			for index = 1, #stage.island_rows do
				mark_ring(stage.island_rows[index].stations)
			end
		end
		local water_rows = {}
		local function add_water_run(z, first, finish, owner, context)
			-- Split the run at footprint-boundary columns that the
			-- Bay's aperture does not include: those columns are dry
			-- perimeter equality, not planned water.
			local runs = water_rows[z]
			if not runs then runs = {} water_rows[z] = runs end
			local run_first = nil
			for x = first, finish do
				local water = true
				if boundary_columns[x .. ":" .. z] and
						not context.aperture.included[x .. ":" .. z] then
					water = false
				end
				if water and not run_first then run_first = x end
				if not water and run_first then
					runs[#runs + 1] = {first = run_first, finish = x - 1,
						owner = context.bay.source.id}
					run_first = nil
				end
			end
			if run_first then
				runs[#runs + 1] = {first = run_first, finish = finish,
					owner = context.bay.source.id}
			end
		end
		for bay_index = 1, #stage.bays do
			local context = stage.bay_context_by_id[
				stage.bays[bay_index].source.id]
			local zs = {}
			for z in pairs(context.raw_rows) do zs[#zs + 1] = z end
			table.sort(zs)
			for z_index = 1, #zs do
				local z = zs[z_index]
				local runs = context.raw_rows[z]
				for run_index = 1, #runs do
					add_water_run(z, runs[run_index].first,
						runs[run_index].finish,
						context.bay.source.id, context)
				end
			end
			local fills = copy_points(context.fill_points)
			table.sort(fills, point_less)
			for fill_index = 1, #fills do
				local point = fills[fill_index]
				add_water_run(point.z, point.x, point.x,
					context.bay.source.id, context)
			end
			-- The section-11 closing fills are planned water exactly like
			-- the notch fills; they are carried apart so the notch
			-- projections and payload stay the notch rule's own.
			local closings = copy_points(context.closing_points)
			table.sort(closings, point_less)
			for closing_index = 1, #closings do
				local point = closings[closing_index]
				add_water_run(point.z, point.x, point.x,
					context.bay.source.id, context)
			end
		end
		for z, runs in pairs(water_rows) do
			table.sort(runs, function(a, b)
				return a.first < b.first or
					(a.first == b.first and a.finish < b.finish)
			end)
		end
		return boundary_columns, water_rows
	end

	-- Face rows from composed polygons: `faces` is a list of
	-- {id, zone_id, polygon, appendix_stations, pinch_stations} rows.  A
	-- face the two-tier validator accepted with touches (filament
	-- appendixes or pinches, contracts 11.5-C/11.9) derives its region
	-- truth by winding through the repeat-tolerant row derivation: the
	-- touch columns stay in the region as boundary runs -- no orphan
	-- columns -- and every other face keeps the loud repeated-column
	-- failure.  Each run carries its winding class (0 boundary station,
	-- 1 interior) -- the 11.9 seam-inheritance rule of the classifier
	-- reads it to tell a boundary-boundary claim from an interior one.
	local function whole_face_row_runs(faces)
		local face_rows = {}
		local face_indexes = {}
		for index = 1, #faces do
			local face = faces[index]
			local rows, polygon_index = polygon_row_runs(face.polygon,
				face.id, (face.appendix_stations or 0) > 0 or
					(face.pinch_stations or 0) > 0)
			face_indexes[face.id] = polygon_index
			for z, runs in pairs(rows) do
				local merged = face_rows[z]
				if not merged then merged = {} face_rows[z] = merged end
				for run_index = 1, #runs do
					merged[#merged + 1] = {first = runs[run_index].first,
						finish = runs[run_index].finish, id = face.id,
						zone_id = face.zone_id,
						class = runs[run_index].class}
				end
			end
		end
		for z, runs in pairs(face_rows) do
			table.sort(runs, function(a, b)
				if a.first ~= b.first then return a.first < b.first end
				if a.finish ~= b.finish then return a.finish < b.finish end
				return a.id < b.id
			end)
		end
		return face_rows, face_indexes
	end

	-- The declared seam owners: every final shared-edge station
	-- declares its two zones, every perimeter-span vertex the owners
	-- of the spans sharing it.  `edge_stations` maps a provisional
	-- edge id to its final stations (absent edges are skipped).
	local function whole_declared(stage, edge_stations)
		local declared = {}
		local function declare(x, z, owner)
			local point_key = x .. ":" .. z
			local owners = declared[point_key]
			if not owners then owners = {} declared[point_key] = owners end
			owners[owner] = true
		end
		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			local stations = edge_stations[edge.id]
			if stations then
				for station_index = 1, #stations do
					declare(stations[station_index].x,
						stations[station_index].z, edge.source.zone_a)
					declare(stations[station_index].x,
						stations[station_index].z, edge.source.zone_b)
				end
			end
		end
		for index = 1, #source.perimeter_spans do
			local span = source.perimeter_spans[index]
			local perimeter = stage.perimeter_by_id[span.perimeter_id]
			for _, boundary in ipairs({span.start_boundary,
					span.end_boundary}) do
				if boundary.kind == "perimeter_vertex" then
					local point = perimeter.source.polygon[boundary.index]
					declare(point.x, point.z, span.zone_id)
				end
			end
		end
		return declared
	end

	-- The footprint rings' own station adjacency (contracts 11.9, family
	-- A): ["x:z"] -> the ring predecessor and successor points of that
	-- station, over the perimeter and island rings -- the eight-connected
	-- connectivity the rings themselves are built with.  The residue
	-- adoption below consults it for chains containing ring stations: the
	-- measured pinched fragments are mainland-continuous through exactly
	-- one diagonal ring step the 4-connected flood and the cardinal contact
	-- rule cannot see.
	local function whole_ring_links(stage)
		local links = {}
		local function add_ring(points)
			local count = #points
			if count > 1 and key(points[1]) == key(points[count]) then
				count = count - 1
			end
			if count < 2 then return end
			for index = 1, count do
				local previous = points[index == 1 and count or index - 1]
				local following = points[index == count and 1 or index + 1]
				local point_key = key(points[index])
				local entry = links[point_key]
				if not entry then entry = {} links[point_key] = entry end
				entry[#entry + 1] = {x = previous.x, z = previous.z}
				entry[#entry + 1] = {x = following.x, z = following.z}
			end
		end
		for index = 1, #stage.perimeter_rows do
			add_ring(stage.perimeter_rows[index].stations)
		end
		for index = 1, #stage.island_rows do
			add_ring(stage.island_rows[index].stations)
		end
		return links
	end

	-- Residue adoption at the ownership layer (contracts 11.7-B, ruled
	-- 2026-08-20; ring connectivity added by the 11.9 family-A ruling),
	-- shared verbatim by the census Whole tier and the production Whole
	-- gate, running after face composition and before the footprint proof.
	-- Every unowned dry footprint column joins its 4-connected unowned-dry
	-- chain; the chain's candidate owners are the faces it touches
	-- cardinally PLUS -- for chain columns that are footprint ring stations
	-- (prepared.ring_links) -- the faces owning its ring-neighbour
	-- stations, because a ring station is mainland by definition and the
	-- ring's own eight-connected step is its mainland continuity.  A chain
	-- with exactly one candidate face is adopted into that face's REGION --
	-- prepared.face_rows membership only, no ring, no mask, no trace and no
	-- Bank moves; a chain with two or more candidates is returned rejected
	-- and classifies residual_multi_face_reject (measured zero over the
	-- 112-pocket family, expected vacuous, never absorbed); a chain with
	-- zero candidates is exactly what the section-11 connectivity closing
	-- waters, so it stays uncovered here and the footprint proof rejects it
	-- loudly.  The rules partition the measured families by construction:
	-- attached pockets adopt cardinally, pinched ring fragments adopt along
	-- the ring, unattached pockets are already water when this runs.
	-- Winners carry no pockets, so this is a measured no-op on clean
	-- geometry and no record byte of a clean seed moves.
	local function whole_adopt_residue(prepared)
		-- The unowned dry intervals per row, by run arithmetic (the same
		-- interval altitude as the classifier -- never a per-column sweep):
		-- the face and water runs merge into one disjoint owned cover, and
		-- what remains of each footprint run is unowned.  Ascending row and
		-- column order everywhere keeps chain identity deterministic under
		-- both interpreters.
		local zs = {}
		for z in pairs(prepared.footprint_rows) do zs[#zs + 1] = z end
		table.sort(zs)
		local unowned_rows, unowned_zs = {}, {}
		for z_index = 1, #zs do
			local z = zs[z_index]
			local footprint_runs = prepared.footprint_rows[z]
			local cover = {}
			for _, collection in ipairs({prepared.face_rows[z] or {},
					prepared.water_rows[z] or {}}) do
				for index = 1, #collection do
					cover[#cover + 1] = {first = collection[index].first,
						finish = collection[index].finish}
				end
			end
			table.sort(cover, function(a, b)
				return a.first < b.first or
					a.first == b.first and a.finish < b.finish
			end)
			local merged = {}
			for index = 1, #cover do
				local run = cover[index]
				local last = merged[#merged]
				if last and run.first <= last.finish + 1 then
					if run.finish > last.finish then last.finish = run.finish end
				else
					merged[#merged + 1] = run
				end
			end
			local intervals
			local cursor = 1
			for run_index = 1, #footprint_runs do
				local run = footprint_runs[run_index]
				local first = run.first
				while first <= run.finish do
					while cursor <= #merged and merged[cursor].finish < first do
						cursor = cursor + 1
					end
					local finish
					if cursor <= #merged and merged[cursor].first <= first then
						first = merged[cursor].finish + 1
					else
						finish = run.finish
						if cursor <= #merged and
								merged[cursor].first <= run.finish then
							finish = merged[cursor].first - 1
						end
						if not intervals then
							intervals = {}
							unowned_rows[z] = intervals
							unowned_zs[#unowned_zs + 1] = z
						end
						intervals[#intervals + 1] = {z = z, first = first,
							finish = finish}
						first = finish + 1
					end
				end
			end
		end
		-- 4-connected chains over the intervals: adjacent rows, overlapping
		-- columns.  A depth-first merge in ascending (z, first) order keeps
		-- chain identity and member order deterministic.
		local chains = {}
		for z_position = 1, #unowned_zs do
			local z = unowned_zs[z_position]
			local intervals = unowned_rows[z]
			for interval_index = 1, #intervals do
				local interval = intervals[interval_index]
				if not interval.chain then
					local chain = {members = {}, columns = 0}
					chains[#chains + 1] = chain
					local stack = {interval}
					interval.chain = chain
					while #stack > 0 do
						local member = stack[#stack]
						stack[#stack] = nil
						chain.members[#chain.members + 1] = member
						chain.columns = chain.columns +
							(member.finish - member.first + 1)
						for step = -1, 1, 2 do
							local neighbors = unowned_rows[member.z + step]
							if neighbors then
								for neighbor_index = 1, #neighbors do
									local neighbor = neighbors[neighbor_index]
									if not neighbor.chain and
											neighbor.first <= member.finish and
											member.first <= neighbor.finish then
										neighbor.chain = chain
										stack[#stack + 1] = neighbor
									end
								end
							end
						end
					end
				end
			end
		end
		-- Face contact per chain, distinct by face id: the cardinal contact
		-- of every member interval's four cardinal neighbourhoods
		-- (contracts 11.7-B), plus -- for chain columns that are footprint
		-- ring stations -- the faces owning the ring-neighbour stations
		-- along the ring's own connectivity (contracts 11.9, family A: the
		-- measured pinched fragments touch no face cardinally and are
		-- mainland-continuous through exactly one diagonal ring step,
		-- 8/8).  The whole contact pass runs BEFORE any adoption, so every
		-- candidate lookup -- cardinal and ring alike -- reads the
		-- composed, pre-adoption face cover and no chain's decision can
		-- depend on another chain's adoption order.
		local function touch(chain, runs, first, finish)
			if not runs then return end
			for index = 1, #runs do
				local run = runs[index]
				if run.finish >= first and run.first <= finish then
					if not chain.touched[run.id] then
						chain.touched[run.id] = run
						chain.touched_ids[#chain.touched_ids + 1] = run.id
					end
					chain.cardinal_touched[run.id] = true
				end
			end
		end
		local function ring_touch(chain, x, z)
			local links = prepared.ring_links[x .. ":" .. z]
			if not links then return end
			chain.ring_stations = chain.ring_stations + 1
			for link_index = 1, #links do
				local link = links[link_index]
				local runs = prepared.face_rows[link.z]
				if runs then
					for run_index = 1, #runs do
						local run = runs[run_index]
						if link.x >= run.first and link.x <= run.finish then
							if not chain.touched[run.id] then
								chain.touched[run.id] = run
								chain.touched_ids[#chain.touched_ids + 1] =
									run.id
							end
						end
					end
				end
			end
		end
		for chain_index = 1, #chains do
			local chain = chains[chain_index]
			chain.touched, chain.touched_ids = {}, {}
			chain.cardinal_touched, chain.ring_stations = {}, 0
			for member_index = 1, #chain.members do
				local member = chain.members[member_index]
				touch(chain, prepared.face_rows[member.z], member.first - 1,
					member.first - 1)
				touch(chain, prepared.face_rows[member.z], member.finish + 1,
					member.finish + 1)
				touch(chain, prepared.face_rows[member.z - 1], member.first,
					member.finish)
				touch(chain, prepared.face_rows[member.z + 1], member.first,
					member.finish)
			end
			if prepared.ring_links then
				for member_index = 1, #chain.members do
					local member = chain.members[member_index]
					for x = member.first, member.finish do
						ring_touch(chain, x, member.z)
					end
				end
			end
			table.sort(chain.touched_ids)
		end
		local adopted, rejected = {}, {}
		for chain_index = 1, #chains do
			local chain = chains[chain_index]
			if #chain.touched_ids == 1 then
				local face_run = chain.touched[chain.touched_ids[1]]
				for member_index = 1, #chain.members do
					local member = chain.members[member_index]
					local runs = prepared.face_rows[member.z]
					if not runs then
						runs = {}
						prepared.face_rows[member.z] = runs
					end
					runs[#runs + 1] = {first = member.first,
						finish = member.finish, id = face_run.id,
						zone_id = face_run.zone_id, adopted = true}
					table.sort(runs, function(a, b)
						if a.first ~= b.first then return a.first < b.first end
						if a.finish ~= b.finish then return a.finish < b.finish end
						return a.id < b.id
					end)
				end
				-- `via` and `ring_stations` are observer telemetry (the
				-- adoption-verification probes): which contact rule found
				-- the adopting face, and how many chain columns are ring
				-- stations.  They reach no record row and no digest.
				adopted[#adopted + 1] = {face_id = face_run.id,
					zone_id = face_run.zone_id, members = chain.members,
					columns = chain.columns,
					ring_stations = chain.ring_stations,
					via = chain.cardinal_touched[face_run.id] and
						"cardinal" or "ring"}
			elseif #chain.touched_ids >= 2 then
				rejected[#rejected + 1] = {face_ids = chain.touched_ids,
					members = chain.members, columns = chain.columns,
					ring_stations = chain.ring_stations,
					witness = "z=" .. chain.members[1].z .. ":x=" ..
						chain.members[1].first .. ".." .. chain.members[1].finish}
			end
		end
		return {adopted = adopted, rejected = rejected}
	end

	local function compile_impl(seed)
		local stage = build_scan_stage(seed)
		local zone_numeric = stage.zone_numeric
		local departure_by_edge = stage.departure_by_edge
		local perimeter_rows, perimeter_by_id = stage.perimeter_rows,
			stage.perimeter_by_id
		local island_rows, island_by_id = stage.island_rows, stage.island_by_id
		local provisional_edges, edge_by_id = stage.provisional_edges,
			stage.edge_by_id
		local bays, bay_by_id = stage.bays, stage.bay_by_id
		local aperture_rows, aperture_by_bay, aperture_by_id = stage.aperture_rows,
			stage.aperture_by_bay, stage.aperture_by_id
		local wing_by_id = stage.wing_by_id
		local bay_context_by_id = stage.bay_context_by_id
		local cardinal, diagonal, point_less = stage.cardinal, stage.diagonal,
			stage.point_less
		local footprint_class, in_bay_envelope = stage.footprint_class,
			stage.in_bay_envelope
		local raw_bay_water, raw_owner_count = stage.raw_bay_water,
			stage.raw_owner_count
		local bay_water, planned_water = stage.bay_water, stage.planned_water
		local dry_land, wing_water = stage.dry_land, stage.wing_water
		local bay_dry, final_water = stage.bay_dry, stage.final_water
		local bay_candidate, water_on_right = stage.bay_candidate,
			stage.water_on_right
		local attachment_by_edge = stage.attachment_by_edge
		local land_transition_key = stage.land_transition_key
		local declared_transition_by_key = stage.declared_transition_by_key
		local transitions_by_edge = stage.transitions_by_edge
		local maximal_dry_intervals = stage.maximal_dry_intervals
		local attachment_distance = stage.attachment_distance
		local probe_interval = stage.probe_interval
		local aperture_neighborhood = stage.aperture_neighborhood
		local selected_control_indices = stage.selected_control_indices
		local edge_obligations = stage.edge_obligations
		-- Binding R13 proof for the seed-selected R7/effective-control rasters.
		-- Partition clipping and attachment rerastering are later topology stages.
		stage.validate_all_junction_pairs("selected-r7")
		local resolved_transition_by_key, transition_by_edge = {}, {}
		local excluded_dry_fragments = {}

		-- The tracer now precedes the edge loop because R19 tuple completion
		-- (contracts 8.1) traces both incident Banks of every candidate tuple
		-- before any edge is final.  The eager order -- R12 caps per Bay,
		-- every Wing tail, the eight aperture terminals -- is preserved and
		-- runs here so a structural failure in any of them stays a loud abort
		-- instead of being absorbed by a per-tuple completion pcall; R19
		-- probes then hit warm caches.  Probe-time completion resolves land
		-- transitions by passing its materialized candidate directly and never
		-- consults the land hook, whose table fills as edges finalize below.
		for bay_index = 1, #bays do
			ensure_trace_bounds(bay_context_by_id[bays[bay_index].source.id])
		end
		local tracer = new_bank_tracer(stage, {
			land_transition = function(cache_key)
				return resolved_transition_by_key[cache_key]
			end})
		local resolve_terminal, trace_bank = tracer.resolve_terminal,
			tracer.trace_bank
		local wing_tail_by_id = {}
		for wing_index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[wing_index]
			wing_tail_by_id[wing.id] = tracer.wing_tails(wing.id)
		end
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			for _, terminal in ipairs({bank.start_terminal, bank.end_terminal}) do
				if terminal.kind == "aperture_dry" then
					resolve_terminal(terminal, bank.bay_id)
				end
			end
		end

		local attachment_result = {}
		for index = 1, #provisional_edges do
			local edge = provisional_edges[index]
			local attachment = attachment_by_edge[edge.id]
			local edge_transitions = transitions_by_edge[edge.id]
			local intervals = maximal_dry_intervals(edge)
			if #intervals == 0 then fail(edge.id .. " has no retained land run") end
			local controls = {}
			local interval, from_transition, to_transition, selected_attachment
			local terminal_span
			if edge_transitions then
				local transition_source = edge_obligations(edge, edge_transitions,
					attachment)
				local probes, decisions = {}, {}
				for interval_index = 1, #intervals do
					local candidate = intervals[interval_index]
					local from_probe, to_probe = probe_interval(transition_source,
						attachment, edge, candidate)
					probes[interval_index] = {from = from_probe, to = to_probe}
					decisions[interval_index] = {first = candidate.first,
						finish = candidate.finish, from_complete = from_probe ~= nil,
						to_complete = to_probe ~= nil}
				end
				local selected_index = select_incidence_interval(decisions)
				interval = intervals[selected_index]
				local selected = probes[selected_index]
				selected_attachment = attachment and
					(attachment.edge_endpoint == "from" and selected.from or selected.to) or nil
				-- R19 joint transition resolution on the fixed R18 interval
				-- (source-authority section 4, contracts 8.1): the endpoint
				-- probes above only qualified the interval; the terminals are
				-- now resolved jointly over every eligible incidence, with
				-- completion checked at selection and the D1 order deciding
				-- among several complete tuples.
				local joint = resolve_edge_joint_terminals(stage, tracer, edge,
					transition_source, attachment, interval, selected_attachment)
				from_transition = joint.from_choice and joint.from_choice.resolved
					or nil
				to_transition = joint.to_choice and joint.to_choice.resolved or nil
				terminal_span = {first = joint.from_i, finish = joint.to_i}
				for interval_index = 1, #intervals do
					if interval_index ~= selected_index then
						local excluded = intervals[interval_index]
						for station_index = excluded.first, excluded.finish do
							local point = edge.stations[station_index]
							excluded_dry_fragments[#excluded_dry_fragments + 1] = {
								edge_id = edge.id, station_index = station_index,
								point = {x = point.x, z = point.z}}
						end
					end
				end
				-- Provisional stations the selected joint terminals clip off
				-- the interval are excluded dry fragments like any other
				-- discarded dry run: owned exactly once by a final Bank or dry
				-- Face, and by no final land edge (source-authority section 4).
				for station_index = interval.first, terminal_span.first - 1 do
					local point = edge.stations[station_index]
					excluded_dry_fragments[#excluded_dry_fragments + 1] = {
						edge_id = edge.id, station_index = station_index,
						point = {x = point.x, z = point.z}}
				end
				for station_index = terminal_span.finish + 1, interval.finish do
					local point = edge.stations[station_index]
					excluded_dry_fragments[#excluded_dry_fragments + 1] = {
						edge_id = edge.id, station_index = station_index,
						point = {x = point.x, z = point.z}}
				end
			else
				if #intervals ~= 1 then fail(edge.id .. " has a second retained land run") end
				interval = intervals[1]
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
			local function append_control(point)
				append_dedup(controls, point)
			end
			if attachment then
				if not selected_attachment then
					selected_attachment = attachment_distance(attachment, edge, interval)
					if selected_attachment.distance > 1 then
						fail("Attachment E/A distance exceeds one")
					end
				end
				local e, best = selected_attachment.e, selected_attachment.a
				local best_distance, best_index = selected_attachment.distance,
					selected_attachment.canonical_index
				local retained_controls = {}
				if edge_transitions then
					retained_controls = selected_control_indices(edge, terminal_span)
				else
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
				end
				local opposite
				if attachment.edge_endpoint == "from" then
					if attachment.retained_run ~= "suffix" then
						fail(attachment.id .. " endpoint/run declaration disagrees")
					end
					append_control(best)
					for retained_index = 1, #retained_controls do
						local point = edge.shifted_controls[retained_controls[retained_index]]
						append_control(point)
					end
					opposite = edge.stations[(terminal_span or interval).finish]
					append_control(opposite)
					controls = add_edge_transition_control(controls,
						to_transition and to_transition.selection, "to", opposite)
				else
					if attachment.edge_endpoint ~= "to" or
							attachment.retained_run ~= "prefix" then
						fail(attachment.id .. " endpoint/run declaration disagrees")
					end
					opposite = edge.stations[(terminal_span or interval).first]
					append_control(opposite)
					for retained_index = 1, #retained_controls do
						local point = edge.shifted_controls[retained_controls[retained_index]]
						append_control(point)
					end
					append_control(best)
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
				if edge_transitions then
					local retained_controls = selected_control_indices(edge,
						terminal_span)
					local first_e, last_e = edge.stations[terminal_span.first],
						edge.stations[terminal_span.finish]
					append_control(first_e)
					for control_index = 1, #retained_controls do
						append_control(edge.shifted_controls[retained_controls[control_index]])
					end
					append_control(last_e)
					controls = add_edge_transition_control(controls,
						from_transition and from_transition.selection, "from", first_e)
					controls = add_edge_transition_control(controls,
						to_transition and to_transition.selection, "to", last_e)
					edge.stations = raster.final_raster(controls, false)
					raster.validate_final({id = edge.id, kind = "land_edge", closed = false,
						max_displacement = edge.source.max_displacement},
						edge.base_stations, edge.stations)
					local dry_flags = {}
					for station_index = 1, #edge.stations do
						local station = edge.stations[station_index]
						dry_flags[station_index] = dry_land(station.x, station.z)
					end
					validate_transition_dry_flags(dry_flags)
					retain_resolved_transition(from_transition)
					retain_resolved_transition(to_transition)
				else
					for station_index = interval.first, interval.finish do
						append_control(edge.stations[station_index])
					end
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

		-- Bank materialization consumes the shared tracer created before the
		-- edge loop; R12 caps, Wing tails and aperture terminals resolved
		-- eagerly there, so the historical order is preserved.
		local bank_by_id = {}
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			local start = resolve_terminal(bank.start_terminal, bank.bay_id)
			local finish = resolve_terminal(bank.end_terminal, bank.bay_id)
			bank_by_id[bank.id] = {source = bank,
				stations = trace_bank(bank, start, finish)}
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
			local points, bank_ids, join_keys = {}, {}, {}
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
				-- The shared station where two authority components join --
				-- the bay-transition terminals live here -- feeds the
				-- window-guarded appendix acceptance (contracts 11.5-C).
				if #points > 0 then join_keys[key(part[1])] = true end
				append_points(points, part)
			end
			arc_by_id[arc.id] = {source = arc, stations = points,
				bank_component_ids = bank_ids, join_keys = join_keys}
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
			local polygon, face_bank_ids, join_keys = {}, {}, {}
			for cycle_index = 1, #face.cycle do
				local component = face.cycle[cycle_index]
				local points = component.kind == "shared_edge" and
					edge_by_id[component.ref_id].stations or arc_by_id[component.ref_id].stations
				if component.kind ~= "shared_edge" then
					local arc = arc_by_id[component.ref_id]
					for bank_index = 1, #arc.bank_component_ids do
						face_bank_ids[#face_bank_ids + 1] = arc.bank_component_ids[bank_index]
					end
					-- The arc's internal component joins travel with it; a
					-- station key survives the reverse direction unchanged.
					for join_key in pairs(arc.join_keys) do
						join_keys[join_key] = true
					end
				end
				if component.direction == "reverse" then points = reverse_points(points) end
				if #polygon > 0 and key(polygon[#polygon]) ~= key(points[1]) then
					fail(face.id .. " component graph does not join")
				end
				if #polygon > 0 then join_keys[key(points[1])] = true end
				append_points(polygon, points)
			end
			-- The cycle's wrap-around join is the ring terminal.
			join_keys[key(polygon[1])] = true
			local appendix_stations, pinch_stations = validate_face_polygon(
				face.id, polygon, join_keys)
			face_rows[#face_rows + 1] = {source = face, polygon = polygon,
				bank_component_ids = face_bank_ids,
				appendix_stations = appendix_stations,
				pinch_stations = pinch_stations}
		end

		-- C2 excluded fragments are resolved only after final Banks and Faces
		-- exist. A Bank boundary owns first; otherwise exactly one dry Face owns.
		-- Neither category can rescue a surviving land-edge or terminal identity.
		if #excluded_dry_fragments > 0 then
			local land_identity, bank_identity, terminal_identity = {}, {}, {}
			for edge_index = 1, #provisional_edges do
				local stations = provisional_edges[edge_index].stations
				for station_index = 1, #stations do
					local point_key = key(stations[station_index])
					land_identity[point_key] = (land_identity[point_key] or 0) + 1
				end
			end
			for _, bank in pairs(bank_by_id) do
				for station_index = 1, #bank.stations do
					local point_key = key(bank.stations[station_index])
					bank_identity[point_key] = (bank_identity[point_key] or 0) + 1
				end
			end
			for _, terminal in pairs(tracer.terminal_cache) do
				if terminal.point then terminal_identity[key(terminal.point)] = true end
			end
			local evidence = {}
			for fragment_index = 1, #excluded_dry_fragments do
				local fragment = excluded_dry_fragments[fragment_index]
				local point_key = key(fragment.point)
				local face_count = 0
				for face_index = 1, #face_rows do
					if exact.polygon_class(fragment.point.x, fragment.point.z,
							face_rows[face_index].polygon) >= 0 then
						face_count = face_count + 1
					end
				end
				evidence[#evidence + 1] = {edge_id = fragment.edge_id,
					point = {x = fragment.point.x, z = fragment.point.z},
					land_count = land_identity[point_key] or 0,
					terminal_identity = terminal_identity[point_key] == true,
					bank_count = bank_identity[point_key] or 0, face_count = face_count}
			end
			validate_excluded_fragment_evidence(evidence)
		end

		-- The production Whole gate (contracts section 11, ruled 2026-08-20
		-- beside the branch-2c closing): the footprint ownership-coverage
		-- proof the census Whole tier measures, enforced on every production
		-- compile.  This closes the step-0 hole -- nothing after face
		-- validation and the fragment seam exhausted the footprint, so a
		-- whole_gap seed compiled to completion.  The prepared tables and
		-- the classifier are the census's own functions (parity by
		-- construction); the census's optional representation cross-check
		-- stays census-side, so m plays no part here.  Any uncovered or
		-- multiply-owned footprint column aborts loudly.
		do
			local gate_faces = {}
			for index = 1, #face_rows do
				gate_faces[index] = {id = face_rows[index].source.id,
					zone_id = face_rows[index].source.zone_id,
					polygon = face_rows[index].polygon,
					appendix_stations = face_rows[index].appendix_stations,
					pinch_stations = face_rows[index].pinch_stations}
			end
			local gate_face_rows = whole_face_row_runs(gate_faces)
			local edge_stations = {}
			for index = 1, #provisional_edges do
				edge_stations[provisional_edges[index].id] =
					provisional_edges[index].stations
			end
			local boundary_columns, water_rows = whole_water_rows(stage)
			local prepared = {
				footprint_rows = whole_footprint_rows(stage),
				face_rows = gate_face_rows, water_rows = water_rows,
				declared = whole_declared(stage, edge_stations),
				ring_links = whole_ring_links(stage)}
			-- Residue adoption (contracts 11.7-B, ring connectivity added by
			-- 11.9 family A) between face composition and the footprint
			-- proof, identical to the census Whole tier: a multi-face chain
			-- aborts by its class name before the proof runs; adopted chains
			-- are face region membership below.
			local adoption = whole_adopt_residue(prepared)
			if #adoption.rejected > 0 then
				local parts = {}
				for index = 1, #adoption.rejected do
					local chain = adoption.rejected[index]
					parts[#parts + 1] = chain.witness .. " touches " ..
						table.concat(chain.face_ids, ",")
				end
				fail("footprint residue touches multiple faces: " ..
					"residual_multi_face_reject x" .. #adoption.rejected ..
					" (" .. table.concat(parts, "; ") .. ")")
			end
			local totals = census_whole_classify(prepared)
			if totals.g > 0 or totals.o > 0 or totals.r > 0 then
				local class_names, parts = {}, {}
				for class in pairs(totals.classes) do
					class_names[#class_names + 1] = class
				end
				table.sort(class_names)
				for index = 1, #class_names do
					local class = class_names[index]
					if class ~= "whole_single_owner_select" and
							class ~= "whole_declared_seam_select" then
						local entry = totals.classes[class]
						parts[#parts + 1] = class .. " x" .. entry.columns ..
							" (" .. entry.witness .. ")"
					end
				end
				fail("footprint ownership is incomplete: g=" .. totals.g ..
					" o=" .. totals.o .. " r=" .. totals.r .. "; " ..
					table.concat(parts, "; "))
			end
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

	-- ------------------------------------------------------------------
	-- Census Scan-1 projection (wp40-t2-plan.md section 6).  Classifies the
	-- F1/F7/F8 decisions plus the F6 fill counts on the same stage data the
	-- compiler consumes, but records each decision class and continues
	-- scanning instead of failing closed.  Classes are the section-3
	-- vocabulary of wp40-t2-degeneracy-completeness.md; a *_reject row is a
	-- census finding, not an error.  Stage-level global preconditions (S1
	-- validity, aperture formation, notch ownership) still fail closed: no
	-- Scan-1 class covers them, so their occupancy must surface loudly.
	-- ------------------------------------------------------------------

	local function record_stress(row)
		local max_abs = 0
		for index = 1, #row.scalar_samples do
			local magnitude = math.abs(row.scalar_samples[index].scalar_q)
			if magnitude > max_abs then max_abs = magnitude end
		end
		return row.topology_ceiling_nodes, max_abs
	end

	-- Seed-independent F1 prefilter (analysis section 3-F1).  The Bay context
	-- boxes are built from authored capsules, wings and width-jitter margins
	-- only, so they are identical on every seed; one extra column absorbs the
	-- notch-fill adjacency.  A discharged edge must additionally be unable to
	-- reach the displaced perimeter, since a station outside the final
	-- footprint is not final-dry either; the coast margin uses the authored
	-- perimeter base stations plus both records' displacement bounds.
	local function census_prefilter(stage)
		local boxes = {}
		for bay_index = 1, #stage.bays do
			local context = stage.bay_context_by_id[stage.bays[bay_index].source.id]
			for box_index = 1, #context.boxes do
				local box = context.boxes[box_index]
				boxes[#boxes + 1] = {min_x = box.min_x - 1, max_x = box.max_x + 1,
					min_z = box.min_z - 1, max_z = box.max_z + 1}
			end
		end
		-- Every footprint boundary that displaces per seed can flip dry_land:
		-- the two mainland coasts, the fixed Holy band (reach zero) and the
		-- island coasts all enter the grid, so an island-adjacent edge can
		-- never be discharged on mainland-only evidence.  The cell size is
		-- derived from the largest realizable margin, keeping the 3x3 bucket
		-- search sound under any future displacement bound.
		local coast_rows = {}
		for perimeter_index = 1, #stage.perimeter_rows do
			coast_rows[#coast_rows + 1] = stage.perimeter_rows[perimeter_index]
		end
		for island_index = 1, #stage.island_rows do
			coast_rows[#coast_rows + 1] = stage.island_rows[island_index]
		end
		local coast_reach = 0
		for index = 1, #coast_rows do
			coast_reach = math.max(coast_reach,
				coast_rows[index].source.max_displacement)
		end
		local max_margin = 0
		for index = 1, #stage.provisional_edges do
			max_margin = math.max(max_margin,
				stage.provisional_edges[index].source.max_displacement +
					coast_reach + 1)
		end
		local cell = math.max(256, max_margin)
		local coast_grid = {}
		for index = 1, #coast_rows do
			local row = coast_rows[index]
			for station_index = 1, #row.base_stations do
				local station = row.base_stations[station_index]
				local grid_key = deterministic.floor_div(station.x, cell) .. ":" ..
					deterministic.floor_div(station.z, cell)
				local bucket = coast_grid[grid_key]
				if not bucket then bucket = {} coast_grid[grid_key] = bucket end
				bucket[#bucket + 1] = station
			end
		end
		local function near_coast(station, margin)
			local grid_x = deterministic.floor_div(station.x, cell)
			local grid_z = deterministic.floor_div(station.z, cell)
			for dx = -1, 1 do
				for dz = -1, 1 do
					local bucket = coast_grid[(grid_x + dx) .. ":" .. (grid_z + dz)]
					if bucket then
						for index = 1, #bucket do
							if math.abs(bucket[index].x - station.x) <= margin and
									math.abs(bucket[index].z - station.z) <= margin then
								return true
							end
						end
					end
				end
			end
			return false
		end
		local rows = {}
		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			local row = {edge_id = edge.id, discharged = false}
			if stage.transitions_by_edge[edge.id] then
				row.reason = "transition_obligation"
			elseif stage.attachment_by_edge[edge.id] then
				row.reason = "attachment_obligation"
			else
				local margin = edge.source.max_displacement + 1
				local coast_margin = edge.source.max_displacement + coast_reach + 1
				if coast_margin > cell then fail("census coast margin exceeds grid cell") end
				local reason
				for station_index = 1, #edge.base_stations do
					local station = edge.base_stations[station_index]
					for box_index = 1, #boxes do
						local box = boxes[box_index]
						if station.x >= box.min_x - margin and
								station.x <= box.max_x + margin and
								station.z >= box.min_z - margin and
								station.z <= box.max_z + margin then
							reason = "envelope_reaches_bay_surface"
							break
						end
					end
					if not reason and near_coast(station, coast_margin) then
						reason = "envelope_reaches_coast_margin"
					end
					if reason then break end
				end
				row.discharged = reason == nil
				row.reason = reason or "envelope_disjoint_from_water_surfaces"
			end
			rows[index] = row
		end
		return rows
	end

	-- One worker pass per seed (plan section 6.6.1) computes Scan-1, Scan-3a
	-- and Scan-2 on one shared stage; the record schema is versioned as one
	-- unit because the M5 merge and the launcher's first-record validator
	-- consume the whole record, never one scan's rows alone.  v3 since M4;
	-- v4 since the stage-reject package (2026-08-17): a record is either the
	-- full per-seed roster or exactly one stage_reject row, never a mixture.
	local census_scan_schema = "grug_wp40_census_scan_v6"

	local function census_scan1(stage, seed)
		local result = {schema = census_scan_schema, seed = seed,
			prefilter = census_prefilter(stage), edges = {}, perimeters = {},
			aperture_stress = {}, attachments = {}, junctions = {},
			junction_pair_rejects = {}, bay_fills = {}}
		local intervals_by_edge, selected_by_edge = {}, {}
		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			local edge_transitions = stage.transitions_by_edge[edge.id]
			local attachment = stage.attachment_by_edge[edge.id]
			local intervals = stage.maximal_dry_intervals(edge)
			intervals_by_edge[edge.id] = intervals
			local ceiling, max_abs = record_stress(edge)
			local singleton_count = 0
			for interval_index = 1, #intervals do
				if intervals[interval_index].first ==
						intervals[interval_index].finish then
					singleton_count = singleton_count + 1
				end
			end
			local row = {id = edge.id, numeric_id = edge.source.numeric_id,
				kind = edge_transitions and
					(attachment and "transition_attachment" or "transition") or
					attachment and "ordinary_attachment" or "ordinary",
				station_count = #edge.stations,
				topology_ceiling_nodes = ceiling, max_abs_scalar_q = max_abs,
				interval_count = #intervals, singleton_count = singleton_count}
			if edge_transitions then
				local transition_source = stage.edge_obligations(edge,
					edge_transitions, attachment)
				local qualifying, selected = 0, nil
				for interval_index = 1, #intervals do
					local candidate = intervals[interval_index]
					local from_probe, to_probe = stage.probe_interval(
						transition_source, attachment, edge, candidate)
					if from_probe and to_probe then
						qualifying = qualifying + 1
						if qualifying == 1 then selected = candidate end
					end
				end
				row.qualifying_count = qualifying
				if qualifying == 1 then
					row.class = "transition_interval_select"
					row.selected_first = selected.first
					row.selected_finish = selected.finish
					selected_by_edge[edge.id] = selected
				elseif qualifying == 0 then
					row.class = "transition_interval_zero_reject"
				else
					row.class = "transition_interval_multi_reject"
				end
			elseif #intervals == 1 then
				row.class = "ordinary_interval_select"
				row.selected_first = intervals[1].first
				row.selected_finish = intervals[1].finish
				selected_by_edge[edge.id] = intervals[1]
			elseif #intervals == 0 then
				row.class = "ordinary_interval_zero_reject"
			else
				row.class = "ordinary_interval_multi_reject"
			end
			result.edges[index] = row
		end
		-- Plan section 6.6.8: the prefilter is verified, not trusted, and the
		-- verification is a property of the scan result itself, so every
		-- consumer of census_scan1 gets it — not only the worker's TSV loop.
		for index = 1, #result.prefilter do
			local prefilter_row = result.prefilter[index]
			local edge_row = result.edges[index]
			if prefilter_row.edge_id ~= edge_row.id then
				fail("census prefilter order diverged from the edge roster")
			end
			if prefilter_row.discharged and edge_row.interval_count ~= 1 then
				fail("discharged edge " .. edge_row.id ..
					" realized interval count " .. edge_row.interval_count ..
					" at seed " .. seed)
			end
		end
		for index = 1, #stage.perimeter_rows do
			local row = stage.perimeter_rows[index]
			local ceiling, max_abs = record_stress(row)
			result.perimeters[index] = {id = row.id,
				station_count = #row.stations,
				topology_ceiling_nodes = ceiling, max_abs_scalar_q = max_abs}
		end
		-- Aperture stress scalars (plan section 6.2.3, redefined 2026-08-16):
		-- per D/W/A station the scalar_q of the Chebyshev-nearest scalar
		-- sample of the owning perimeter, ties to the lower sample index.  The
		-- station indices are exactly the resolve_terminal aperture
		-- neighborhood in the authored/declared perimeter order.
		for index = 1, #stage.aperture_rows do
			local aperture = stage.aperture_rows[index]
			local perimeter = stage.perimeter_by_id[aperture.source.perimeter_id]
			for _, side in ipairs({"before", "after"}) do
				local point_index, away_index, water_index =
					stage.aperture_neighborhood(aperture, side)
				local stations = {d = perimeter.stations[point_index],
					w = perimeter.stations[water_index],
					a = perimeter.stations[away_index]}
				local row = {id = aperture.source.id, side = side}
				for _, name in ipairs({"d", "w", "a"}) do
					local station = stations[name]
					if not station then
						fail(aperture.source.id .. " " .. side ..
							" authored aperture neighborhood is absent")
					end
					local best_distance, best_scalar
					for sample_index = 1, #perimeter.scalar_samples do
						local sample = perimeter.scalar_samples[sample_index]
						local distance = chebyshev(sample, station)
						if not best_distance or distance < best_distance then
							best_distance, best_scalar = distance, sample.scalar_q
						end
					end
					if not best_distance then
						fail(aperture.source.id .. " " .. side ..
							" has no scalar sample to anchor its stress")
					end
					row[name .. "_x"] = station.x
					row[name .. "_z"] = station.z
					row[name .. "_scalar_q"] = best_scalar
					row[name .. "_sample_distance"] = best_distance
				end
				result.aperture_stress[#result.aperture_stress + 1] = row
			end
		end
		for index = 1, #source.perimeter_attachments do
			local attachment = source.perimeter_attachments[index]
			local edge = stage.edge_by_id[attachment.edge_id]
			if not edge then fail(attachment.id .. " references an absent edge") end
			local intervals = intervals_by_edge[attachment.edge_id]
			local row = {id = attachment.id, edge_id = attachment.edge_id,
				endpoint = attachment.edge_endpoint, interval_count = #intervals}
			local probed
			local selected = selected_by_edge[attachment.edge_id]
			if selected then
				probed = stage.attachment_distance(attachment, edge, selected)
			else
				for interval_index = 1, #intervals do
					local candidate = stage.attachment_distance(attachment, edge,
						intervals[interval_index])
					if not probed or candidate.distance < probed.distance then
						probed = candidate
					end
				end
			end
			if probed then
				row.distance = probed.distance
				row.e, row.a = probed.e, probed.a
				row.canonical_index = probed.canonical_index
				row.class = probed.distance == 0 and "attachment_equality_select" or
					probed.distance == 1 and "attachment_adjacent_select" or
					"attachment_distance_reject"
			else
				row.class = "attachment_edge_without_interval"
			end
			result.attachments[index] = row
		end
		local census_pair_total = 0
		for junction_index = 1, #source.relief_junctions do
			local junction = source.relief_junctions[junction_index]
			local incident = junction.incident_edge_ids
			local pair_count, pass_count, min_clearance = 0, 0, nil
			for left_index = 1, #incident - 1 do
				local left = stage.edge_by_id[incident[left_index]]
				if not left then fail(junction.id .. " lacks an incident edge") end
				for right_index = left_index + 1, #incident do
					local right = stage.edge_by_id[incident[right_index]]
					if not right then fail(junction.id .. " lacks an incident edge") end
					pair_count = pair_count + 1
					local class = classify_junction_pair(junction.position,
						left.stations, right.stations)
					if class then
						result.junction_pair_rejects[#result.junction_pair_rejects + 1] =
							{junction_id = junction.id, left_edge = left.id,
							right_edge = right.id, class = "junction_pair_" .. class}
					else
						pass_count = pass_count + 1
					end
					local clearance = pair_clearance(junction.position,
						left.stations, right.stations)
					if clearance and (not min_clearance or
							clearance < min_clearance) then
						min_clearance = clearance
					end
				end
			end
			census_pair_total = census_pair_total + pair_count
			result.junctions[junction_index] = {id = junction.id,
				pair_count = pair_count, pass_count = pass_count,
				fail_count = pair_count - pass_count,
				min_clearance = min_clearance}
		end
		-- Same stage-global precondition the compile path proves via
		-- validate_all_junction_pairs: an under-covered junction roster must
		-- abort the census loudly, not silently emit fewer rows.
		if #source.relief_junctions ~= 38 or census_pair_total ~= 102 then
			fail("census junction coverage did not cover 38/102")
		end
		for bay_index = 1, #stage.bays do
			local bay = stage.bays[bay_index]
			local context = stage.bay_context_by_id[bay.source.id]
			result.bay_fills[bay_index] = {id = bay.source.id,
				fill_count = #context.fill_points,
				fill_points = copy_points(context.fill_points)}
		end
		return result, selected_by_edge
	end

	-- ------------------------------------------------------------------
	-- Census Scan-2 projection (plan section 6, milestone M3): the F2
	-- counting tier and the complete R19 tuple tier of
	-- wp40-source-authority.md section 4, classified under the decided U1/U2
	-- readings (plan section 5).  The tuple tier is evaluated on every seed
	-- wherever at least one tuple exists: the section 6.2 artifact-5 joint
	-- (eligible, R16-success, complete) distribution, the U2 occupancy
	-- measurement and the 0-complete reject class are required outputs of
	-- this contract's scans, and none of them is measurable on the skipped
	-- side of the analysis section 5 flagging predicate -- Scan-3b cannot
	-- recover them, because it presupposes resolved, corrected tuples.  The
	-- predicate survives as the per-row flagged marker: the cost and
	-- reporting distinction, not a skip.  Per-tuple precondition failures
	-- are DECIDED-with-continuation; seed-level rejects arise only from a
	-- zero complete-tuple count, duplicate authority and the section 7.4
	-- 192-station backstop on the selected result -- several complete tuples
	-- are a DECIDED selection under the D1 order since the collected
	-- correction (plan 7.1, contracts 8.1).
	-- ------------------------------------------------------------------

	-- The Source Bank roster is shared with the compile path and built once
	-- beside the D1 comparators above.
	-- The far terminal of a transition-incident Bank -- the terminal that is
	-- not the land transition -- as the Scan-3b attribution histogram names
	-- it (contracts 9.1): kind, resolved mode and the site an R20/R21 event
	-- would land on.  `side` is the Bank side holding the transition.  The
	-- aperture mode needs the terminal resolved; resolve_terminal caches
	-- Aperture and Wing resolutions, so this costs nothing beyond the first
	-- call, and a far terminal whose own resolution fails reports mode "-"
	-- rather than aborting the attribution.
	local function census_far_terminal(tracer, bank, side)
		local far = side == "start" and bank.end_terminal or bank.start_terminal
		if far.kind == "aperture_dry" then
			local info = {kind = "aperture",
				site = far.aperture_id .. ":" .. far.side}
			local ok, resolved = pcall(tracer.resolve_terminal, far, bank.bay_id)
			info.mode = ok and resolved.aperture_transition.mode or "-"
			return info
		end
		if far.kind == "wing_junction_tail_side" then
			return {kind = "wing", mode = far.tail_side,
				site = far.wing_id .. ":" .. far.tail_side,
				wing_id = far.wing_id, tail_side = far.tail_side}
		end
		fail(bank.id .. " has an unexpected far terminal kind")
	end

	-- The tracer is supplied by census_scan and shared with Scan-3a.  The
	-- census resolves transition terminals per tuple through
	-- resolve_land_transition, never through the tracer's land hook; a land
	-- terminal reaching resolve_terminal fails as unresolved.
	local function census_scan2(stage, result, selected_by_edge, tracer)
		local endpoint_rows, edge_rows, tuple_rows = {}, {}, {}
		result.scan2_endpoints = endpoint_rows
		result.scan2_edges = edge_rows
		result.scan2_tuples = tuple_rows
		-- Scan-3b substrate (contracts 9.1): the selected tuple's resolved
		-- terminals and probe bytes per edge -- exactly what the sixteen
		-- Bank traces and the Scan-4 final-edge composition consume -- the
		-- bank-incomplete attribution counts, and the per-edge descriptors
		-- the R20/R21 classifiers read.
		local selected_tuples, attributions, descriptors = {}, {}, {}
		result.scan2_selected = selected_tuples
		result.scan3b_attributions = attributions
		result.scan3b_edge_descriptors = descriptors

		local function hex_digest(text)
			return canonical.hex(dependencies.raw_sha256(text))
		end
		local function digest_points(points)
			local texts = {}
			for index = 1, #points do
				texts[index] = key(points[index])
			end
			return hex_digest(table.concat(texts, ";"))
		end

		-- Read-set digests for the tuple key (plan section 6, keying decision):
		-- the tuple decision reads the displaced footprint rasters, the
		-- referenced Bays' raw rows and fills, the edge record and the probe
		-- bytes.  The key exists for duplicate detection only and is never a
		-- skip condition.
		local footprint_digest
		local function ensure_footprint_digest()
			if footprint_digest then return footprint_digest end
			local parts = {}
			for index = 1, #stage.perimeter_rows do
				parts[#parts + 1] = stage.perimeter_rows[index].id .. ":" ..
					digest_points(stage.perimeter_rows[index].stations)
			end
			for index = 1, #stage.island_rows do
				parts[#parts + 1] = stage.island_rows[index].id .. ":" ..
					digest_points(stage.island_rows[index].stations)
			end
			footprint_digest = hex_digest(table.concat(parts, "\n"))
			return footprint_digest
		end
		local bay_digest_cache = {}
		local function bay_envelope_digest(bay_id)
			local cached = bay_digest_cache[bay_id]
			if cached then return cached end
			local context = stage.bay_context_by_id[bay_id]
			local zs = {}
			for z in pairs(context.raw_rows) do zs[#zs + 1] = z end
			table.sort(zs)
			local parts = {}
			for z_index = 1, #zs do
				local runs = context.raw_rows[zs[z_index]]
				local run_texts = {}
				for run_index = 1, #runs do
					run_texts[run_index] = runs[run_index].first .. "-" ..
						runs[run_index].finish
				end
				parts[#parts + 1] = zs[z_index] .. ":" ..
					table.concat(run_texts, ",")
			end
			local fills = copy_points(context.fill_points)
			table.sort(fills, point_less)
			local fill_texts = {}
			for index = 1, #fills do
				fill_texts[index] = key(fills[index])
			end
			cached = hex_digest(bay_id .. "\n" .. table.concat(parts, ";") ..
				"\nfills:" .. table.concat(fill_texts, ","))
			bay_digest_cache[bay_id] = cached
			return cached
		end
		local function sanitize(text)
			return (tostring(text):gsub("[\t\n]", " "))
		end

		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			local edge_transitions = stage.transitions_by_edge[edge.id]
			if edge_transitions then
				local attachment = stage.attachment_by_edge[edge.id]
				local transition_source = stage.edge_obligations(edge,
					edge_transitions, attachment)
				local selected = selected_by_edge[edge.id]

				-- Counting tier: per declared endpoint, every eligible
				-- incidence of the selected interval -- all stations except
				-- the opposite endpoint, each with its immediately adjacent
				-- in-interval station away from the endpoint -- runs the
				-- exact R16 resolver.  These rows are also the section 6.2.3
				-- transition stress scalars.
				local counting = {}
				for _, endpoint in ipairs({"from", "to"}) do
					local row = transition_source[endpoint]
					if row then
						local out = {edge_id = edge.id, id = row.id,
							endpoint = endpoint, bay_id = row.bay_id}
						if not selected then
							out.class = "scan2_no_selected_interval"
							out.flagged = false
						else
							-- The bounds encode both eligibility clauses at once:
							-- the opposite endpoint is excluded, and the away
							-- station of every remaining incidence is in-interval
							-- by construction.  A singleton selected interval
							-- therefore has zero eligible incidences -- its lone
							-- station is the opposite endpoint and has no away
							-- station -- so zero tuples enumerate and the edge
							-- honestly classifies scan2_zero_complete_reject.
							local from_side = endpoint == "from"
							local endpoint_index = from_side and selected.first or
								selected.finish
							local low = from_side and selected.first or
								selected.first + 1
							local high = from_side and selected.finish - 1 or
								selected.finish
							local successes = {}
							local eligible, direct_count, elbow_count = 0, 0, 0
							local flagged = false
							for station_index = low, high do
								eligible = eligible + 1
								local probed = stage.probe_edge_transition_at(row,
									edge, station_index)
								if probed then
									successes[#successes + 1] = {index = station_index,
										resolved = probed}
									if probed.mode == "direct" then
										direct_count = direct_count + 1
									else
										elbow_count = elbow_count + 1
									end
									if probed.mode ~= "direct" or
											station_index ~= endpoint_index then
										flagged = true
									end
								end
							end
							if #successes >= 2 then flagged = true end
							out.class = "scan2_counting_evaluated"
							out.first, out.finish = selected.first, selected.finish
							out.eligible_count = eligible
							out.success_count = #successes
							out.direct_count = direct_count
							out.elbow_count = elbow_count
							out.successes = successes
							out.flagged = flagged
						end
						counting[endpoint] = out
						endpoint_rows[#endpoint_rows + 1] = out
					end
				end

				local edge_row = {edge_id = edge.id}
				edge_rows[#edge_rows + 1] = edge_row
				edge_row.flagged = (counting.from and counting.from.flagged) or
					(counting.to and counting.to.flagged) or false
				if not selected then
					edge_row.class = "scan2_no_selected_interval"
					edge_row.tuple_count = 0
					edge_row.complete_count = 0
					edge_row.duplicate_count = 0
				else
					local from_choices = transition_source.from and
						counting.from.successes or nil
					local to_choices = transition_source.to and
						counting.to.successes or nil
					local tuple_count
					if from_choices and to_choices then
						tuple_count = exact.safe_product(#from_choices, #to_choices,
							edge.id .. " R19 tuple count")
					else
						tuple_count = #(from_choices or to_choices)
					end
					edge_row.tuple_count = tuple_count

					local probed_attachment
					if attachment then
						probed_attachment = stage.attachment_distance(attachment,
							edge, selected)
					end

					-- Probe phase of one tuple: combined clip, control
					-- subsequence, E/T insertion, the sole final edge raster
					-- as an unretained probe, terminal and previous bindings.
					-- Every failure is a per-tuple DECIDED class (U1/U2
					-- readings); enumeration always continues.
					local function tuple_probe(from_choice, to_choice)
						local from_i = from_choice and from_choice.index or
							selected.first
						local to_i = to_choice and to_choice.index or
							selected.finish
						local out = {from_i = from_i, to_i = to_i}
						if from_i > to_i then
							out.class = "scan2_tuple_empty_combined_clip"
							out.detail = "inverted combined clip"
							return out
						end
						local stations = {}
						for station_index = from_i, to_i do
							stations[#stations + 1] = edge.stations[station_index]
						end
						local clip_ok, retained = pcall(select_control_subsequence,
							edge.shifted_controls, stations)
						if not clip_ok then
							-- Both failure strings live in select_control_subsequence
							-- above; the full literal is matched so a rewording
							-- there cannot silently flip tuples between the two
							-- DECIDED classes.
							local message = tostring(retained)
							if message:find("selected control subsequence is empty",
									1, true) then
								out.class = "scan2_tuple_empty_combined_clip"
							else
								out.class = "scan2_tuple_clip_not_contiguous"
							end
							out.detail = message
							return out
						end
						local controls = {}
						local function append_control(point)
							append_dedup(controls, point)
						end
						local from_station = edge.stations[from_i]
						local to_station = edge.stations[to_i]
						local assembly_ok, assembly_error = pcall(function()
							if attachment and attachment.edge_endpoint == "from" then
								append_control(probed_attachment.a)
								for control_index = 1, #retained do
									append_control(edge.shifted_controls[retained[control_index]])
								end
								append_control(to_station)
								controls = add_edge_transition_control(controls,
									to_choice.resolved.selection, "to", to_station)
							elseif attachment and attachment.edge_endpoint == "to" then
								append_control(from_station)
								for control_index = 1, #retained do
									append_control(edge.shifted_controls[retained[control_index]])
								end
								append_control(probed_attachment.a)
								controls = add_edge_transition_control(controls,
									from_choice.resolved.selection, "from", from_station)
							else
								append_control(from_station)
								for control_index = 1, #retained do
									append_control(edge.shifted_controls[retained[control_index]])
								end
								append_control(to_station)
								controls = add_edge_transition_control(controls,
									from_choice.resolved.selection, "from", from_station)
								controls = add_edge_transition_control(controls,
									to_choice.resolved.selection, "to", to_station)
							end
						end)
						if not assembly_ok then
							out.class = "scan2_tuple_probe_invalid"
							out.detail = tostring(assembly_error)
							return out
						end
						local raster_ok, probe = pcall(raster.final_raster,
							controls, false)
						if not raster_ok then
							out.class = "scan2_tuple_probe_invalid"
							out.detail = tostring(probe)
							return out
						end
						-- The decided U2 reading: a one-station probe dies at the
						-- previous binding, under its own class label.  This must
						-- be decided before validate_final, whose too-few-stations
						-- reject would otherwise absorb the shape into
						-- probe_invalid and leave the U2 occupancy unmeasurable.
						-- (The crossed-incidence sibling dies earlier, as the U1
						-- empty combined clip.)
						if #probe < 2 then
							out.class = "scan2_tuple_previous_binding_unsatisfiable"
							out.detail = "one-station probe has no adjacent station"
							return out
						end
						local validate_ok, validate_error = pcall(
							raster.validate_final,
							{id = edge.id, kind = "land_edge", closed = false,
								max_displacement = edge.source.max_displacement},
							edge.base_stations, probe)
						if not validate_ok then
							out.class = "scan2_tuple_probe_invalid"
							out.detail = tostring(validate_error)
							return out
						end
						for station_index = 1, #probe do
							local station = probe[station_index]
							if not stage.dry_land(station.x, station.z) then
								out.class = "scan2_tuple_probe_wet"
								out.detail = "wet probe station " .. key(station)
								return out
							end
						end
						-- On the four attachment transition edges the compiler
						-- additionally requires every final station except A to
						-- be strict footprint interior; a dry class-0 boundary
						-- station passes dry_land but aborts compile_impl, so
						-- the census must reject the same probes or its
						-- artifact-5 distribution reports selects the compiler
						-- would never produce.
						if attachment then
							for station_index = 1, #probe do
								local station = probe[station_index]
								if key(station) ~= key(probed_attachment.a) and
										(stage.footprint_class(station.x, station.z) ~= 1
										or stage.planned_water(station.x, station.z,
											false)) then
									out.class = "scan2_tuple_probe_invalid"
									out.detail = "non-strict-interior probe station " ..
										key(station)
									return out
								end
							end
						end
						local from_terminal = from_choice and
							from_choice.resolved.point or probed_attachment.a
						local to_terminal = to_choice and
							to_choice.resolved.point or probed_attachment.a
						if key(probe[1]) ~= key(from_terminal) or
								key(probe[#probe]) ~= key(to_terminal) then
							out.class = "scan2_tuple_probe_invalid"
							out.detail = "a resolved terminal is not its probe endpoint"
							return out
						end
						out.probe = probe
						out.probe_digest = digest_points(probe)
						local forward_texts = {}
						for station_index = 1, #probe do
							forward_texts[station_index] = key(probe[station_index])
						end
						out.probe_forward = table.concat(forward_texts, ";")
						local reverse_texts = {}
						for station_index = #probe, 1, -1 do
							reverse_texts[#reverse_texts + 1] =
								key(probe[station_index])
						end
						out.probe_reverse = table.concat(reverse_texts, ";")
						if from_choice then
							out.from_previous = {x = probe[2].x, z = probe[2].z}
						end
						if to_choice then
							out.to_previous = {x = probe[#probe - 1].x,
								z = probe[#probe - 1].z}
						end
						out.identity = table.concat({
							from_choice and key(from_choice.resolved.point) or "-",
							out.from_previous and key(out.from_previous) or "-",
							to_choice and key(to_choice.resolved.point) or "-",
							out.to_previous and key(out.to_previous) or "-",
							out.probe_digest}, "|")
						return out
					end

					-- Per-endpoint completion roster, resolved once per edge:
					-- the transition key, the two incident Banks in Source
					-- order and which of their terminals is the transition.
					-- Catalog-shape violations fail loudly here, outside any
					-- per-tuple pcall -- they are structural defects, never
					-- tuple outcomes.
					local completion_roster = {}
					for _, endpoint in ipairs({"from", "to"}) do
						local row = transition_source[endpoint]
						if row then
							local transition_key = stage.land_transition_key(
								row.edge_id, row.edge_endpoint)
							local banks = {}
							for bank_index = 1, 2 do
								local bank = bank_source_by_id[
									row.incident_bank_component_ids[bank_index]]
								if not bank then
									fail(row.id .. " references an absent Bank")
								end
								local side
								if terminal_key(bank.start_terminal) ==
										transition_key then
									side = "start"
								elseif terminal_key(bank.end_terminal) ==
										transition_key then
									side = "end"
								else
									fail(bank.id .. " is not incident to " ..
										transition_key)
								end
								banks[bank_index] = {bank = bank, side = side}
							end
							completion_roster[endpoint] = {row = row,
								transition_key = transition_key, banks = banks}
						end
					end

					-- The shared far-terminal identity (census_far_terminal
					-- above): the attribution histogram and Scan-3b's Bank
					-- rows must name the same kind, mode and site or the two
					-- would drift.

					-- Completion phase: both declared incident Banks of every
					-- transition in the tuple must complete to their
					-- already-authorized Aperture or Wing terminals under the
					-- unchanged R11 rules.  Far terminals resolve lazily
					-- through the shared tracer; any geometric failure inside
					-- -- including a Wing-tail or aperture resolution failure,
					-- whose own F4/F5 class is Scan-3a's to record -- is this
					-- tuple's bank-incomplete witness, with the original
					-- message preserved as the detail.
					local function tuple_complete(probed)
						for _, endpoint in ipairs({"from", "to"}) do
							local choice
							if endpoint == "from" then choice = probed.from_choice
							else choice = probed.to_choice end
							if choice then
								local roster = completion_roster[endpoint]
								local previous
								if endpoint == "from" then
									previous = probed.from_previous
								else
									previous = probed.to_previous
								end
								local resolved = tracer.resolve_land_transition(
									roster.transition_key,
									{source = roster.row,
										point = choice.resolved.point,
										previous = previous,
										mode = choice.resolved.mode,
										e = choice.resolved.e,
										w = choice.resolved.w})
								for bank_index = 1, 2 do
									local entry = roster.banks[bank_index]
									local trace_ok, trace_error = pcall(function()
										local start_resolved, finish_resolved
										if entry.side == "start" then
											start_resolved = resolved
											finish_resolved = tracer.resolve_terminal(
												entry.bank.end_terminal,
												entry.bank.bay_id)
										else
											finish_resolved = resolved
											start_resolved = tracer.resolve_terminal(
												entry.bank.start_terminal,
												entry.bank.bay_id)
										end
										tracer.trace_bank(entry.bank,
											start_resolved, finish_resolved)
									end)
									if not trace_ok then
										local info = census_far_terminal(tracer,
											entry.bank, entry.side)
										return false, {bank_id = entry.bank.id,
											endpoint = endpoint,
											far_kind = info.kind,
											far_mode = info.mode,
											far_site = info.site,
											wing_id = info.wing_id},
											tostring(trace_error)
									end
								end
							end
						end
						return true
					end

					-- The edge-invariant digest prefix (footprint, referenced
					-- Bay envelopes, edge and interval identity) is built once
					-- per edge; only the incidence pair and probe digest vary
					-- per tuple.  The concatenation reproduces the same byte
					-- layout as one flat newline join.
					local key_prefix
					local function tuple_key(probed)
						if not key_prefix then
							local parts = {ensure_footprint_digest()}
							local bay_ids, seen_bays = {}, {}
							for _, endpoint in ipairs({"from", "to"}) do
								local row = transition_source[endpoint]
								if row and not seen_bays[row.bay_id] then
									seen_bays[row.bay_id] = true
									bay_ids[#bay_ids + 1] = row.bay_id
								end
							end
							table.sort(bay_ids)
							for bay_index = 1, #bay_ids do
								parts[#parts + 1] =
									bay_envelope_digest(bay_ids[bay_index])
							end
							parts[#parts + 1] = edge.id
							parts[#parts + 1] = selected.first .. "-" ..
								selected.finish
							key_prefix = table.concat(parts, "\n")
						end
						return hex_digest(key_prefix .. "\n" ..
							probed.from_i .. "/" .. probed.to_i .. "\n" ..
							(probed.probe_digest or probed.class))
					end

					local evaluated = {}
					local function evaluate_tuple(from_choice, to_choice)
						local probed = tuple_probe(from_choice, to_choice)
						probed.from_choice, probed.to_choice = from_choice, to_choice
						evaluated[#evaluated + 1] = probed
					end
					if from_choices and to_choices then
						for from_index = 1, #from_choices do
							for to_index = 1, #to_choices do
								evaluate_tuple(from_choices[from_index],
									to_choices[to_index])
							end
						end
					elseif from_choices then
						for from_index = 1, #from_choices do
							evaluate_tuple(from_choices[from_index], nil)
						end
					else
						for to_index = 1, #to_choices do
							evaluate_tuple(nil, to_choices[to_index])
						end
					end

					-- Duplicate authority (F2 table: identical terminal,
					-- previous and probe-edge bytes are explicitly not
					-- collapsed): detected across every probe-valid tuple.
					-- Completion is still evaluated for duplicates, so the
					-- joint complete-count stays measured.
					local identity_counts, duplicate_count = {}, 0
					for tuple_index = 1, #evaluated do
						local identity = evaluated[tuple_index].identity
						if identity then
							identity_counts[identity] =
								(identity_counts[identity] or 0) + 1
						end
					end
					for _, count in pairs(identity_counts) do
						if count >= 2 then
							duplicate_count = duplicate_count + count
						end
					end
					edge_row.duplicate_count = duplicate_count

					-- The projection's own descriptor for the D1 order; the
					-- compile path builds its descriptors independently inside
					-- resolve_edge_joint_terminals (contracts 8.1).
					local function census_descriptor(probed)
						local descriptor = {elbow_count = 0, terminal_points = {},
							previous_points = {},
							probe_forward = probed.probe_forward,
							probe_reverse = probed.probe_reverse}
						if probed.from_choice then
							local terminal = probed.from_choice.resolved.point
							local previous = probed.from_previous
							descriptor.from_retreat = probed.from_i - selected.first
							descriptor.terminal_points[1] =
								{x = terminal.x, z = terminal.z}
							descriptor.previous_points[1] =
								{x = previous.x, z = previous.z}
							if probed.from_choice.resolved.mode ~= "direct" then
								descriptor.elbow_count = descriptor.elbow_count + 1
							end
						end
						if probed.to_choice then
							local terminal = probed.to_choice.resolved.point
							local previous = probed.to_previous
							descriptor.to_retreat = selected.finish - probed.to_i
							descriptor.terminal_points[#descriptor.terminal_points + 1] =
								{x = terminal.x, z = terminal.z}
							descriptor.previous_points[#descriptor.previous_points + 1] =
								{x = previous.x, z = previous.z}
							if probed.to_choice.resolved.mode ~= "direct" then
								descriptor.elbow_count = descriptor.elbow_count + 1
							end
						end
						return descriptor
					end
					local complete_count, selected_tuple = 0, nil
					for tuple_index = 1, #evaluated do
						local probed = evaluated[tuple_index]
						probed.probe_station_count = probed.probe and #probed.probe
							or nil
						if probed.probe then
							local ok, failure, detail = tuple_complete(probed)
							if ok then
								probed.class = "scan2_tuple_complete"
								probed.tuple_index = tuple_index
								complete_count = complete_count + 1
								-- D1 (plan 7.1): the least complete tuple under
								-- the declared order is selected; with exactly
								-- one completion the order is vacuous and the
								-- census-recorded outcome is unchanged.
								if not selected_tuple or joint_tuple_less_census(
										census_descriptor(probed),
										census_descriptor(selected_tuple)) then
									selected_tuple = probed
								end
							else
								probed.class = "scan2_tuple_bank_incomplete"
								probed.detail = failure.bank_id .. ": " .. detail
								probed.failure = failure
							end
						end
						local tuple_row = {edge_id = edge.id,
							tuple_index = tuple_index,
							from_index = probed.from_choice and probed.from_i or nil,
							from_mode = probed.from_choice and
								probed.from_choice.resolved.mode or nil,
							to_index = probed.to_choice and probed.to_i or nil,
							to_mode = probed.to_choice and
								probed.to_choice.resolved.mode or nil,
							class = probed.class,
							probe_station_count = probed.probe_station_count,
							from_point = probed.from_choice and
								key(probed.from_choice.resolved.point) or nil,
							from_previous = probed.from_previous and
								key(probed.from_previous) or nil,
							to_point = probed.to_choice and
								key(probed.to_choice.resolved.point) or nil,
							to_previous = probed.to_previous and
								key(probed.to_previous) or nil,
							key = tuple_key(probed),
							detail = probed.detail and sanitize(probed.detail) or nil}
						tuple_rows[#tuple_rows + 1] = tuple_row
					end
					-- The selected tuple's probe bytes are the edge's final
					-- raster (only the selected tuple's probe materializes,
					-- source authority section 4), so Scan-3b and Scan-4
					-- keep exactly that one; every other probe is dropped
					-- here as before.
					for tuple_index = 1, #evaluated do
						if evaluated[tuple_index] ~= selected_tuple then
							evaluated[tuple_index].probe = nil
						end
					end
					edge_row.complete_count = complete_count

					-- The D1 amendment (plan 7.1): several complete tuples are
					-- a DECIDED selection under the declared order, no longer a
					-- reject.  The section 7.4 192-station backstop applies to
					-- the selected result whatever the completion count.
					if duplicate_count > 0 then
						edge_row.class = "scan2_duplicate_authority_reject"
					elseif complete_count == 0 then
						edge_row.class = "scan2_zero_complete_reject"
					elseif selected_tuple.probe_station_count and
							selected_tuple.probe_station_count - 1 < 192 then
						edge_row.class = "scan2_selected_below_192_reject"
					elseif complete_count >= 2 then
						edge_row.class = "scan2_multi_complete_select"
					else
						edge_row.class = "scan2_exactly_one_complete_select"
					end
					if complete_count >= 1 then
						edge_row.selected_tuple_index = selected_tuple.tuple_index
						edge_row.selected_station_count =
							selected_tuple.probe_station_count
					end

					-- The v5 cross-check (contracts 8.5): the compile path's
					-- own R19 resolution runs beside the projection's.  On a
					-- DECIDED selection the two must agree and a mismatch
					-- aborts the scan loudly -- a finding, never a column; on
					-- a rejected class the compile outcome is recorded.
					local compile_ok, compile_selected = pcall(
						resolve_edge_joint_terminals, stage, tracer, edge,
						transition_source, attachment, selected,
						probed_attachment)
					if edge_row.class == "scan2_exactly_one_complete_select" or
							edge_row.class == "scan2_multi_complete_select" then
						if not compile_ok then
							fail(edge.id .. " compile joint resolution failed " ..
								"where the projection selected: " ..
								tostring(compile_selected))
						end
						if compile_selected.from_i ~= selected_tuple.from_i or
								compile_selected.to_i ~= selected_tuple.to_i or
								compile_selected.probe_forward ~=
									selected_tuple.probe_forward then
							fail(edge.id ..
								" compile and projection joint selections disagree")
						end
						edge_row.compile_agreement = "agrees"
					elseif compile_ok then
						edge_row.compile_agreement = "compile_selected"
					else
						edge_row.compile_agreement = "compile_failed"
					end

					-- Scan-3b substrate: the selected tuple's resolutions and
					-- probe bytes, the attribution counts and the R20/R21
					-- descriptor for this edge (contracts 9.1).
					if selected_tuple then
						selected_tuples[edge.id] = {
							interval = {first = selected.first,
								finish = selected.finish},
							from_i = selected_tuple.from_i,
							to_i = selected_tuple.to_i,
							from = selected_tuple.from_choice and {
								resolved = selected_tuple.from_choice.resolved,
								previous = selected_tuple.from_previous} or nil,
							to = selected_tuple.to_choice and {
								resolved = selected_tuple.to_choice.resolved,
								previous = selected_tuple.to_previous} or nil,
							sources = {from = transition_source.from,
								to = transition_source.to},
							probe = selected_tuple.probe}
					end
					local descriptor = {edge_id = edge.id,
						class = edge_row.class, tuples = {}}
					descriptors[edge.id] = descriptor
					local counts_by_key = {}
					for tuple_index = 1, #evaluated do
						local probed = evaluated[tuple_index]
						local entry = {class = probed.class}
						if probed.failure then
							entry.bank_id = probed.failure.bank_id
							entry.far_kind = probed.failure.far_kind
							entry.far_mode = probed.failure.far_mode
							entry.far_site = probed.failure.far_site
							entry.wing_id = probed.failure.wing_id
							local attribution_key = table.concat({edge.id,
								probed.failure.endpoint, probed.failure.bank_id,
								probed.failure.far_kind, probed.failure.far_mode},
								"\t")
							local row = counts_by_key[attribution_key]
							if not row then
								row = {edge_id = edge.id,
									endpoint = probed.failure.endpoint,
									bank_id = probed.failure.bank_id,
									far_kind = probed.failure.far_kind,
									far_mode = probed.failure.far_mode, count = 0}
								counts_by_key[attribution_key] = row
								attributions[#attributions + 1] = row
							end
							row.count = row.count + 1
						end
						descriptor.tuples[#descriptor.tuples + 1] = entry
					end
				end
				-- The tuple tier was the only consumer of the resolved R16
				-- objects; the long-lived record keeps only the emitted
				-- fields, mirroring the probed.probe cleanup above.
				for _, endpoint in ipairs({"from", "to"}) do
					local out = counting[endpoint]
					if out and out.successes then
						for success_index = 1, #out.successes do
							local success = out.successes[success_index]
							out.successes[success_index] = {index = success.index,
								mode = success.resolved.mode}
						end
					end
				end
			end
		end
		return result
	end

	-- ------------------------------------------------------------------
	-- Census Scan-3a projection (plan section 6, milestone M4): the F4
	-- aperture resolution classes, the F5 Wing analyses under the decided
	-- pair-exclusion reading (plan section 5), the section 6.4 `w = 0` bank
	-- width event, and the four head-bank traces of F3.  The sixteen
	-- transition-incident bank traces are Scan-3b and are not run here.
	--
	-- Table-to-vocabulary map, the F3/F4/F5 counterpart of the Scan-2 note
	-- above.  Where the analysis tables and the compiled decision procedure
	-- differ in granularity the census follows the *procedure* and records the
	-- difference, because a class no configuration can reach is a vacuous-branch
	-- row and not a measurement:
	--
	-- F4 (analysis section 3-F4, eight aperture incidences).  Rows 1/2/3/5/6
	-- map one to one onto `select_aperture_transition`.  Row 4 -- "`W` missing /
	-- non-unique / non-diagonal / not same-Bay-only raw+final" -- is four
	-- distinct rejects in the procedure (non-diagonal `D/W`, W not raw+final
	-- Bay water, W foreign water, and W not immediately aperture-included,
	-- which the table row does not name at all), so the census is finer and
	-- one table row aggregates four classes.  Row 7, the emitted tail's water
	-- side, is decided in `trace_bank` rather than at resolution, and all eight
	-- incidences sit on transition-incident Banks, so a trace-driven reading
	-- would make it unmeasurable before Scan-3b; the predicate is O(1) from the
	-- resolved `D,T,W` and the declared water side, and is therefore evaluated
	-- here.  Row 8, terminal identity drift, reads only catalog and aperture
	-- source and is seed-independent: declared, expected vacuous, and the
	-- underlying failure stays a loud abort rather than a row.  Rows 2 and 3
	-- are alternatives in the table but ordered in the procedure (`d_class`
	-- before `d_cardinal_water`); a configuration violating both is classified
	-- by the first.  For the same ordering reason
	-- `aperture_w_foreign_water_reject` is *dominated*, not merely unoccupied:
	-- `w_final_owned_by_bay` implies `not w_foreign_water` and is tested first,
	-- so a `W` owned by another Bay lands in `aperture_w_not_bay_water_reject`.
	-- The stage-level "authored aperture neighborhood is absent" stays a loud
	-- abort rather than becoming F4 row 4's "`W` missing": it is a perimeter /
	-- aperture-roster consistency failure, and the roster is already proven at
	-- stage build, so an occurrence is a structural defect and not a seed's
	-- decision.
	--
	-- F5 (section 3-F5, eight Wings).  Under the 2026-08-16 pair-exclusion
	-- reading the non-simple/zero-area and `R > 5` rows are per-pair
	-- exclusions, counted here per cause, and the seed rejects only through
	-- `no_wedge_valid_joint_tail_pair`.  The table's single "structural pair
	-- fails side/disjoint/predecessor/X-cross" row splits into four counted
	-- causes; its side clause is vacuous by construction, because
	-- `collect_paths` emits strict-side stations only.  Two procedure failures
	-- have no table row and get their own classes: an empty distance-layer DAG
	-- (`wing_no_complete_tail_reject`) and the finite path bound
	-- (`wing_path_bound_exceeded_reject`).  `Chebyshev(K,J) > 4` is the section
	-- 6.4 refuted-frozen-universal event and is the Wing's own class -- and it
	-- *dominates* the `R > 5` exclusion rather than sitting beside it, because
	-- the radius is derived from the same selected K stations the guard has
	-- already rejected, so `R = 1 + max Chebyshev(K,J) <= 5` identically.  The
	-- `intra_tail_x_cross` cause is vacuous for its own reason: a distance-layer
	-- tail visits exactly one column per Chebyshev level, so two of its diagonal
	-- steps can never share a 2x2 cell.  Both stay declared -- a dominated class
	-- reported vacuous is the finding, not a defect.
	--
	-- F3 (section 3-F3, four head Banks).  The table's step predicates are
	-- (candidate, unseen, /= previous, cardinal-water cross-sign,
	-- terminal-reachable).  `ordered_successors` realizes six: "unseen" is two
	-- separable bits (directed state and column), and the diagonal X-cross
	-- compatibility the table lists only among the rejects is a successor
	-- admission predicate.  Terminal reachability is not among them at all --
	-- `trace_bank` tests it only at branch width two or more, so a lone
	-- admitted successor is taken untested; that asymmetry is its own selection
	-- class rather than a hidden one.  Foreign-water contact has no failure
	-- site of its own: it is absorbed by `bay_candidate`, so it surfaces as a
	-- zero-reachable reject.
	-- ------------------------------------------------------------------

	local aperture_reject_by_suffix = {
		{" D is not dry equality", "aperture_d_not_dry_equality_reject"},
		{" D has cardinal water", "aperture_d_cardinal_water_reject"},
		{" D/W is not exactly diagonal", "aperture_w_not_diagonal_reject"},
		{" W is not raw and final referenced-Bay water",
			"aperture_w_not_bay_water_reject"},
		{" W is foreign-Bay water", "aperture_w_foreign_water_reject"},
		{" W is not immediately aperture-included",
			"aperture_w_not_aperture_included_reject"},
		{" does not have exactly one valid shoulder elbow",
			"aperture_shoulder_elbow_count_reject"},
	}

	-- Ordered because one message can contain another's fragment; the first
	-- match wins and an unmatched message is re-raised, so a structural defect
	-- can never be absorbed into a decision class.
	local bank_reject_by_fragment = {
		{"Bay-bank reachability frame cap exhausted",
			"bank_reachability_frame_cap_reject"},
		{"Bay-bank reachability stack cap exhausted",
			"bank_reachability_stack_cap_reject"},
		{"Bay-bank main trace cap exhausted", "bank_main_trace_cap_reject"},
		{"Bay-bank start half-edge is not eight-connected",
			"bank_start_anchor_invalid_reject"},
		{" has an empty trace envelope", "bank_trace_envelope_empty_reject"},
		{" has an invalid start half-edge", "bank_start_anchor_invalid_reject"},
		{" has a noncandidate target", "bank_target_noncandidate_reject"},
		{" cannot reach its target", "bank_zero_reachable_successor_reject"},
		{" joint tail X-crosses", "bank_x_cross_reject"},
		{" positive joint tail X-crosses", "bank_x_cross_reject"},
		{" repeats a joint-tail column", "bank_repeated_column_reject"},
		{" repeats a positive joint-tail column", "bank_repeated_column_reject"},
		{" X-crosses", "bank_x_cross_reject"},
		-- Unreachable from Scan-3a -- a head Bank has no aperture shoulder --
		-- but it is a named `bay_bank_reject` clause with a real failure site,
		-- so it is declared here rather than left to abort Scan-3b as an
		-- unmatched message.  M5 will report it vacuous, which is the truth.
		{" shoulder has water on the wrong side",
			"bank_shoulder_water_side_reject"},
	}

	-- The five seed-dependent Wing-tail rejects, as they reach a head Bank's
	-- terminal resolution.  Their own F5 class is already recorded on the Wing
	-- row; what this table buys is that everything *else* a terminal resolution
	-- can raise -- an absent Wing, a foreign-Bay reuse, an exact overflow --
	-- stays a loud abort instead of becoming a bank_terminal_unresolved row.
	-- A pcall used as an unfiltered sink is the M3 review's trap, and head-Bank
	-- terminals are exactly where it would bite next.
	local wing_reject_fragments = {" has no negative K", " has no positive K",
		" K exceeds current bound", " lacks a complete negative tail",
		" lacks a complete positive tail",
		" has no wedge-valid joint tail pair",
		" joint tail exceeds finite path bound"}

	local step_direction_names = {"east", "southeast", "south", "southwest",
		"west", "northwest", "north", "northeast"}

	local function classify_message(table_of_pairs, message)
		for index = 1, #table_of_pairs do
			if message:find(table_of_pairs[index][1], 1, true) then
				return table_of_pairs[index][2]
			end
		end
		return nil
	end

	-- One observer per instrumented Bank trace, and one fold of what it
	-- counted into the row and the step/selection coverage rows.  Shared by
	-- Scan-3a's four head Banks and Scan-3b's sixteen transition-incident
	-- Banks (contracts 9.1) so the two tiers cannot drift in what they
	-- count.
	local function new_bank_trace_observation()
		local steps, selections = {}, {}
		local observer = {max_frames = 0, max_stack = 0,
			probe = function(direction_index, outcome)
				local slot = steps[direction_index]
				if not slot then slot = {} steps[direction_index] = slot end
				slot[outcome] = (slot[outcome] or 0) + 1
			end,
			selection = function(class, width, reachable_count)
				local slot = selections[class]
				if not slot then
					slot = {count = 0, max_width = 0, multi_reachable = 0,
						unknown_reachable = 0}
					selections[class] = slot
				end
				slot.count = slot.count + 1
				if width > slot.max_width then slot.max_width = width end
				-- Only the two branch classes carry a reachability count at
				-- all; a nil there means the observation probe was cut short
				-- by a cap, never "no successor was reachable".
				if class == "branch_first_reachable" or
						class == "branch_later_reachable" then
					if reachable_count == nil then
						slot.unknown_reachable = slot.unknown_reachable + 1
					elseif reachable_count >= 2 then
						slot.multi_reachable = slot.multi_reachable + 1
					end
				end
			end}
		return observer, steps, selections
	end

	local function fold_bank_trace_observation(row, bank_id, observer, steps,
			selections, step_rows, selection_rows)
		row.max_frames = observer.max_frames
		row.max_stack = observer.max_stack
		local step_total, branch_total, multi_total = 0, 0, 0
		for direction_index = 1, #step_direction_names do
			local slot = steps[direction_index]
			if slot then
				for outcome, count in pairs(slot) do
					step_rows[#step_rows + 1] = {bank_id = bank_id,
						direction = step_direction_names[direction_index],
						outcome = outcome, count = count}
				end
			end
		end
		for _, class in ipairs({"single_admitted_untested",
				"branch_first_reachable", "branch_later_reachable",
				"branch_none_reachable", "zero_admitted_successors"}) do
			local slot = selections[class]
			if slot then
				selection_rows[#selection_rows + 1] = {bank_id = bank_id,
					class = class, count = slot.count,
					max_width = slot.max_width,
					multi_reachable = slot.multi_reachable,
					unknown_reachable = slot.unknown_reachable}
				step_total = step_total + slot.count
				if class ~= "single_admitted_untested" and
						class ~= "zero_admitted_successors" then
					branch_total = branch_total + slot.count
					multi_total = multi_total + slot.multi_reachable
				end
			end
		end
		row.step_count = step_total
		row.branch_step_count = branch_total
		row.multi_reachable_step_count = multi_total
	end

	-- The deterministic emission order for occupancy-driven step rows: the
	-- outcome keys inside one direction come out of `pairs`, which the
	-- section 5 divergence test exists to catch.
	local function sort_step_rows(step_rows)
		table.sort(step_rows, function(left, right)
			if left.bank_id ~= right.bank_id then
				return left.bank_id < right.bank_id
			end
			if left.direction ~= right.direction then
				return left.direction < right.direction
			end
			return left.outcome < right.outcome
		end)
	end

	local function census_scan3a(stage, result, tracer)
		local aperture_rows, wing_rows, bank_rows = {}, {}, {}
		local width_rows, step_rows, selection_rows = {}, {}, {}
		result.scan3_apertures = aperture_rows
		result.scan3_wings = wing_rows
		result.scan3_banks = bank_rows
		result.scan3_bay_widths = width_rows
		result.scan3_steps = step_rows
		result.scan3_selections = selection_rows
		result.scan3a_traces = {}

		-- F5 first, and before Scan-2: the tail cache is shared with the
		-- completion tier, so a Wing resolved without the analysis observer
		-- would return from cache and lose its measurement entirely.
		local analysis_by_wing = {}
		tracer.set_observer({wing = function(analysis)
			analysis_by_wing[analysis.id] = analysis
		end, max_frames = 0, max_stack = 0})
		for wing_index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[wing_index]
			local ok, failure = pcall(tracer.wing_tails, wing.id)
			local analysis = analysis_by_wing[wing.id]
			if not analysis then
				-- No record reached the observer, so the failure happened before
				-- any F5 decision -- an absent Wing or a broken exact seam.  Loud.
				error(ok and ("WP40 geometry partition: " .. wing.id ..
					" produced no Scan-3a analysis") or failure, 0)
			end
			local sides = analysis.sides
			local negative, positive = sides.negative or {}, sides.positive or {}
			local row = {id = wing.id, bay_id = analysis.bay_id,
				class = analysis.class,
				negative_k_count = negative.k_count,
				positive_k_count = positive.k_count,
				negative_k = negative.k and key(negative.k) or nil,
				positive_k = positive.k and key(positive.k) or nil,
				negative_chebyshev = negative.chebyshev,
				positive_chebyshev = positive.chebyshev,
				negative_path_count = negative.path_count,
				positive_path_count = positive.path_count,
				negative_tail_length = negative.tail_length,
				positive_tail_length = positive.tail_length,
				radius = analysis.radius, path_bound = analysis.path_bound,
				raw_pair_count = analysis.raw_pair_count,
				structural_pair_count = analysis.structural_pair_count,
				wedge_valid_count = analysis.wedge_valid_count,
				selected_raw_rank = analysis.selected_raw_rank,
				selected_structural_rank = analysis.selected_structural_rank,
				detail = analysis.detail}
			-- The per-cause counts travel as an ordered pair of arrays keyed by
			-- the tracer's own declared cause list, not as seven named fields
			-- the worker looks up by hand: adding a cause then widens the row,
			-- which the authority's declared field count refuses, instead of
			-- silently dropping the new column out of the TSV.
			row.exclusion_causes, row.exclusion_counts = {}, {}
			for cause_index = 1, #tracer.wing_exclusion_causes do
				local cause = tracer.wing_exclusion_causes[cause_index]
				row.exclusion_causes[cause_index] = cause
				row.exclusion_counts[cause_index] = analysis.excluded[cause]
			end
			wing_rows[#wing_rows + 1] = row
		end
		tracer.set_observer(nil)

		-- F4.  Every incidence is resolved through the compiler's own terminal
		-- authority; a known reject message becomes its class and anything else
		-- is re-raised, which keeps the roster and Bay-identity failures loud.
		for aperture_index = 1, #stage.aperture_rows do
			local aperture = stage.aperture_rows[aperture_index]
			for _, side in ipairs({"before", "after"}) do
				local terminal = {kind = "aperture_dry",
					aperture_id = aperture.source.id, side = side}
				local incidence_key = terminal_key(terminal)
				local incidence = stage.aperture_terminal_incidence[incidence_key]
				if not incidence then
					fail(incidence_key .. " lacks a Bank incidence")
				end
				local bank = bank_source_by_id[incidence.bank_id]
				if not bank then fail(incidence_key .. " names an absent Bank") end
				local row = {id = aperture.source.id, side = side,
					bank_id = incidence.bank_id,
					terminal_index = incidence.terminal_index}
				-- The D2 admission occupancy (plan 7.2, contracts 8.5): the
				-- authored-order detached shoulder station of this side, so
				-- the v5 record measures where the admission fires.
				local perimeter = stage.perimeter_by_id[
					aperture.source.perimeter_id]
				local detached_index
				if side == "before" then
					detached_index = aperture.authored_detached_before
				else
					detached_index = aperture.authored_detached_after
				end
				if detached_index then
					row.detached = key(perimeter.stations[detached_index])
				end
				local ok, resolved = pcall(tracer.resolve_terminal, terminal,
					incidence.bay_id)
				if ok then
					local selection = resolved.aperture_transition
					row.mode = selection.mode
					row.d = key(selection.d)
					if selection.mode == "direct" then
						row.class = "aperture_direct_select"
					else
						row.t, row.w = key(selection.t), key(selection.w)
						row.selected_elbow = selection.selected_elbow
						-- The emitted tail direction is D->T at a component start
						-- and T->D at an end (source authority section 3.1).
						local first, second = selection.d, selection.t
						if incidence.terminal_index == 2 then
							first, second = selection.t, selection.d
						end
						row.water_side_ok = aperture_tail_water_side(first, second,
							selection.w, bank.water_side)
						row.class = row.water_side_ok and "aperture_tail_select" or
							"aperture_tail_wrong_water_side_reject"
					end
				else
					local message = tostring(resolved)
					local class = classify_message(aperture_reject_by_suffix, message)
					if not class then error(resolved, 0) end
					row.class = class
					row.detail = message
				end
				aperture_rows[#aperture_rows + 1] = row
			end
		end

		-- Section 6.4 / source authority section 7.2: the jittered Bay bank
		-- half-width `w = r + delta_nodes` at every canonical bank-width
		-- station, in the exact body form `E = base_width_num + delta_nodes*L`
		-- so the census reads the same numerator `exact.bay_segment` does
		-- rather than an approximation of it -- `r` is the interpolation of the
		-- two segment half-widths at the station's own projection, not either
		-- endpoint's.  Outside `[0,L]` the compiler uses the endpoint cap
		-- radius, which is exactly the clamped interpolation.  Widths from
		-- different segments are compared as the rationals `E/L` they are.
		-- `exact.bay_segment` already refuses a *negative* radius, so Scan-1
		-- would have aborted before the census saw one; `w = 0` is the margin
		-- nothing asserts today.
		for bay_index = 1, #stage.bays do
			local bay = stage.bays[bay_index]
			local centreline = bay.source.centreline
			local label = bay.source.id .. " bank width"
			local row = {id = bay.source.id, station_count = 0}
			-- Station sampling answers section 6.4's question as written ("at any
			-- station"), but the compiler evaluates the same numerator at every
			-- *column*, pairing it with the delta of the nearest station rather
			-- than that column's own.  Those two sets are not the same, so the
			-- station minimum alone cannot decide the universal.  What closes it
			-- exactly: at any column of a segment the effective half-width is
			-- either the clamped interpolation of the two endpoint half-widths
			-- or one of the endpoint cap radii, and the delta is always an
			-- element of this segment's own array -- so
			-- `min(h_a, h_b) + min(deltas)` is a true lower bound over every
			-- column, computed from quantities already in hand.  The exact
			-- station minimum stays the reported histogram value; the bound
			-- decides whether a collapse can be ruled out at all.
			local column_bound
			for segment_index = 1, #bay.segments do
				local segment = bay.segments[segment_index]
				local a, b = centreline[segment_index], centreline[segment_index + 1]
				local dx = exact.safe_difference(b.x, a.x, label)
				local dz = exact.safe_difference(b.z, a.z, label)
				local length = exact.safe_sum(exact.safe_square(dx, label),
					exact.safe_square(dz, label), label)
				if length <= 0 then fail(label .. " has a zero-length segment") end
				local segment_min_delta
				for station_index = 1, #segment.stations do
					local station = segment.stations[station_index]
					local delta = segment.deltas[station_index]
					if not segment_min_delta or delta < segment_min_delta then
						segment_min_delta = delta
					end
					local projection = exact.dot(
						exact.safe_difference(station.x, a.x, label),
						exact.safe_difference(station.z, a.z, label), dx, dz, label)
					if projection < 0 then projection = 0 end
					if projection > length then projection = length end
					-- The two half-width terms are nonnegative by construction and
					-- keep the stricter checked product; `delta` is signed, and so
					-- is the numerator once the event this measures occurs, so the
					-- jitter term and the cross-comparison take the signed one.
					local numerator = exact.safe_sum(exact.safe_sum(
						exact.safe_product(a.half_width, length - projection, label),
						exact.safe_product(b.half_width, projection, label), label),
						exact.safe_signed_product(delta, length, label), label)
					row.station_count = row.station_count + 1
					if not row.min_numerator or exact.safe_signed_product(numerator,
							row.min_length, label) < exact.safe_signed_product(
							row.min_numerator, length, label) then
						row.min_numerator, row.min_length = numerator, length
						row.min_segment = segment_index
						row.min_station = station_index
						row.min_x, row.min_z = station.x, station.z
						row.min_delta_nodes = delta
					end
					-- The overall minimum *usually* sits where the 96-station
					-- taper forces `delta = 0`, but M4 read that off three seeds
					-- and Slot 30 refutes it: there the minimum moves to a
					-- jittered station in two of the four Bays (measured
					-- 2026-08-16, M5).  The taper decides the segment, not the
					-- station.  Carrying the minimum over the stations the jitter
					-- actually moves therefore still earns its keep -- it is the
					-- margin a correction would have to argue about -- and
					-- neither reading replaces the exact per-column bound above,
					-- which is what rules a collapse out.
					if delta ~= 0 and (not row.jittered_numerator or
							exact.safe_signed_product(numerator,
								row.jittered_length, label) <
							exact.safe_signed_product(row.jittered_numerator,
								length, label)) then
						row.jittered_numerator, row.jittered_length = numerator, length
						row.jittered_delta_nodes = delta
					end
					if not row.min_delta or delta < row.min_delta then
						row.min_delta = delta
					end
					if not row.max_delta or delta > row.max_delta then
						row.max_delta = delta
					end
				end
				if not segment_min_delta then
					fail(label .. " segment " .. segment_index .. " has no station")
				end
				local segment_bound = math.min(a.half_width, b.half_width) +
					segment_min_delta
				if not column_bound or segment_bound < column_bound then
					column_bound = segment_bound
				end
			end
			if not row.min_numerator then
				fail(label .. " has no station")
			end
			-- The reported width in nodes floors the rational, so it can only
			-- understate; the classes below are decided on the exact numerator
			-- and on the exact integer bound, never on this.
			row.min_width_nodes = math.floor(row.min_numerator / row.min_length)
			if row.jittered_numerator then
				row.jittered_width_nodes = math.floor(row.jittered_numerator /
					row.jittered_length)
			end
			row.column_bound_nodes = column_bound
			if row.min_numerator < 0 then
				row.class = "bay_bank_width_negative_event"
			elseif row.min_numerator == 0 then
				row.class = "bay_bank_width_zero_event"
			elseif column_bound <= 0 then
				-- No sampled station collapsed, but the bound cannot rule out a
				-- column between them.  Its own class, because "measured
				-- positive" and "could not be excluded" are different claims and
				-- collapsing them is how an unasserted universal survives.
				row.class = "bay_bank_width_unbounded_event"
			else
				row.class = "bay_bank_width_positive"
			end
			width_rows[#width_rows + 1] = row
		end

		-- F3, the four head Banks.  Both terminals are Wing tails, so no
		-- transition is consumed and the traces stand independently of the
		-- collected correction; the other sixteen are Scan-3b.
		local head_banks = {}
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			if bank.start_terminal.kind == "wing_junction_tail_side" and
					bank.end_terminal.kind == "wing_junction_tail_side" then
				head_banks[#head_banks + 1] = bank
			end
		end
		if #head_banks ~= 4 then
			fail("census Scan-3a expects four head Banks, found " .. #head_banks)
		end
		for head_index = 1, #head_banks do
			local bank = head_banks[head_index]
			local observer, steps, selections = new_bank_trace_observation()
			local row = {id = bank.id, bay_id = bank.bay_id}
			local terminals_ok, start_resolved, finish_resolved = pcall(function()
				return tracer.resolve_terminal(bank.start_terminal, bank.bay_id),
					tracer.resolve_terminal(bank.end_terminal, bank.bay_id)
			end)
			if not terminals_ok then
				local message = tostring(start_resolved)
				local recognised = false
				for entry = 1, #wing_reject_fragments do
					if message:find(wing_reject_fragments[entry], 1, true) then
						recognised = true break
					end
				end
				if not recognised then error(start_resolved, 0) end
				row.class = "bank_terminal_unresolved_reject"
				row.detail = message
			else
				tracer.set_observer(observer)
				local ok, points = pcall(tracer.trace_bank, bank, start_resolved,
					finish_resolved)
				tracer.set_observer(nil)
				if ok then
					row.class = "bank_trace_complete_select"
					row.station_count = #points
					-- Retained for Scan-4's face composition (contracts
					-- 9.1): the materialized head-Bank stations, four rows
					-- of ~10^3 points.
					result.scan3a_traces[bank.id] = points
				else
					local message = tostring(points)
					local class = classify_message(bank_reject_by_fragment, message)
					if not class then error(points, 0) end
					row.class = class
					row.detail = message
				end
			end
			fold_bank_trace_observation(row, bank.id, observer, steps,
				selections, step_rows, selection_rows)
			bank_rows[#bank_rows + 1] = row
		end
		-- Deterministic emission order (the section 5 divergence test).
		sort_step_rows(step_rows)
		return result
	end

	-- ------------------------------------------------------------------
	-- Census Scan-3b (contracts 9.1): the sixteen transition-incident Bank
	-- traces, materialization-style, from the terminals of the selected
	-- joint tuple, with the head-Bank observer instrumentation; the R20/R21
	-- classifiers ride beside them and their probes run only on the dead
	-- condition.
	-- ------------------------------------------------------------------

	-- The R20/R21 classifier core, a pure function over one edge's
	-- descriptor so the synthetic KATs can drive it directly (contracts
	-- 9.4: no measured configuration reaches either branch).  A descriptor
	-- carries the edge id and its evaluated tuples as
	-- {class, bank_id, far_kind, far_mode, far_site, wing_id}; `probe`
	-- answers the R21 alternative-pair question for a named Bank and Wing
	-- with "complete", "dead" or "no_alternative" and is consulted only on
	-- the dead condition.  A dead pair with no completing alternative stays
	-- a plain attribution row -- no event.
	local function census_scan3b_classify_events(descriptor, probe)
		if type(descriptor) ~= "table" or type(descriptor.tuples) ~= "table" or
				type(descriptor.edge_id) ~= "string" then
			fail("Scan-3b event classifier needs an edge descriptor")
		end
		local events = {}
		if #descriptor.tuples == 0 then return events end
		local same = nil
		for index = 1, #descriptor.tuples do
			local entry = descriptor.tuples[index]
			if entry.class ~= "scan2_tuple_bank_incomplete" then return events end
			if same == nil then same = entry
			elseif same.bank_id ~= entry.bank_id then return events end
		end
		if same.far_kind == "aperture" and same.far_mode == "direct" then
			-- R20: candidate D, the completeness analysis 3-F3 residual.
			-- The tail-mode variant is R18's own recovered class and is
			-- deliberately not this event.
			events[#events + 1] = {class = "aperture_anchor_dead_event",
				site = same.far_site,
				detail = "every tuple of " .. descriptor.edge_id ..
					" dead with " .. same.bank_id ..
					" while its aperture incidence resolved direct"}
		elseif same.far_kind == "wing" then
			local answer = probe and probe(same.bank_id, same.wing_id) or
				"no_alternative"
			if answer == "complete" then
				events[#events + 1] = {
					class = "wing_pair_dead_alternative_event",
					site = same.far_site,
					detail = same.bank_id ..
						" dead at the selected wedge-valid pair of " ..
						tostring(same.wing_id) ..
						" while the next wedge-valid pair completes"}
			elseif answer ~= "dead" and answer ~= "no_alternative" then
				fail("Scan-3b alternative-pair probe answered " ..
					tostring(answer))
			end
		end
		return events
	end

	local function census_scan3b(stage, result, tracer, land_transitions)
		local bank_rows, step_rows, selection_rows, event_rows = {}, {}, {}, {}
		result.scan3b_banks = bank_rows
		result.scan3b_steps = step_rows
		result.scan3b_selections = selection_rows
		result.scan3b_events = event_rows
		result.scan3b_traces = {}

		-- The sixteen: every Bank with exactly one land_edge_transition
		-- terminal -- per Bay four of the five chain components (contracts
		-- 9.1 names all sixteen).
		local roster = {}
		for bank_index = 1, #source.bay_bank_components do
			local bank = source.bay_bank_components[bank_index]
			local transition, side
			for terminal_index, terminal in ipairs({bank.start_terminal,
					bank.end_terminal}) do
				if terminal.kind == "land_edge_transition" then
					if transition then
						fail(bank.id .. " has two transition terminals")
					end
					transition = terminal
					side = terminal_index == 1 and "start" or "end"
				end
			end
			if transition then
				roster[#roster + 1] = {bank = bank, transition = transition,
					side = side}
			end
		end
		if #roster ~= 16 then
			fail("census Scan-3b expects sixteen transition-incident Banks, " ..
				"found " .. #roster)
		end

		-- The R21 alternative-pair probe: re-trace the named Bank with the
		-- probed Wing's second wedge-valid pair -- every other terminal
		-- stays the selected resolution.  Runs only on the dead condition;
		-- a trace death answers "dead", a structural failure re-raises (the
		-- pcall is a completion question, never a sink), no alternative
		-- pair answers "no_alternative".
		local function alternative_probe(bank_id, wing_id)
			local bank = bank_source_by_id[bank_id]
			if not bank then fail(bank_id .. " names an absent Bank") end
			local alternative = tracer.wing_alternative_tails(wing_id)
			if not alternative then return "no_alternative" end
			local function resolved_for(terminal)
				local resolved = tracer.resolve_terminal(terminal, bank.bay_id)
				if terminal.kind == "wing_junction_tail_side" and
						terminal.wing_id == wing_id then
					-- The synthetic alternative resolution: same shape as
					-- resolve_terminal's Wing branch, never cached.
					return {id = resolved.id, bay_id = resolved.bay_id,
						point = {x = resolved.point.x, z = resolved.point.z},
						tail = alternative[terminal.tail_side],
						k = terminal.tail_side == "negative" and
							alternative.negative_k or alternative.positive_k}
				end
				return resolved
			end
			local ok, failure = pcall(function()
				return tracer.trace_bank(bank,
					resolved_for(bank.start_terminal),
					resolved_for(bank.end_terminal))
			end)
			if ok then return "complete" end
			local message = tostring(failure)
			if not classify_message(bank_reject_by_fragment, message) then
				error(failure, 0)
			end
			return "dead"
		end

		for index = 1, #roster do
			local entry = roster[index]
			local bank = entry.bank
			local edge_id = entry.transition.edge_id
			local endpoint = entry.transition.edge_endpoint
			local info = census_far_terminal(tracer, bank, entry.side)
			local row = {id = bank.id, bay_id = bank.bay_id,
				edge_id = edge_id, endpoint = endpoint,
				far_kind = info.kind, far_mode = info.mode}
			local selected = result.scan2_selected[edge_id]
			local choice = selected and
				(endpoint == "from" and selected.from or selected.to)
			local source_row = selected and selected.sources[endpoint]
			if not choice or not source_row then
				-- No selected joint tuple: the Bank has no terminal to trace
				-- from, and "measured" versus "could not be evaluated" stay
				-- different claims.  The primary finding is the edge's own
				-- scan2 row; v5 measured this branch empty over W.
				local descriptor =
					result.scan3b_edge_descriptors[edge_id]
				row.class = "scan3b_bank_not_evaluated"
				row.detail = "no selected joint tuple on " .. edge_id ..
					(descriptor and (": " .. descriptor.class) or "")
			else
				local transition_key = stage.land_transition_key(edge_id,
					endpoint)
				local materialized = {source = source_row,
					point = choice.resolved.point,
					previous = choice.previous, mode = choice.resolved.mode,
					e = choice.resolved.e, w = choice.resolved.w}
				local resolved = tracer.resolve_land_transition(transition_key,
					materialized)
				-- The Scan-4 composition resolves land terminals through the
				-- tracer's land hook; this table is what that hook reads --
				-- the selected joint resolution, exactly once per
				-- transition.
				if land_transitions then
					land_transitions[transition_key] = materialized
				end
				local start_resolved, finish_resolved
				if entry.side == "start" then
					start_resolved = resolved
					finish_resolved = tracer.resolve_terminal(
						bank.end_terminal, bank.bay_id)
				else
					finish_resolved = resolved
					start_resolved = tracer.resolve_terminal(
						bank.start_terminal, bank.bay_id)
				end
				local observer, steps, selections = new_bank_trace_observation()
				tracer.set_observer(observer)
				local ok, points = pcall(tracer.trace_bank, bank,
					start_resolved, finish_resolved)
				tracer.set_observer(nil)
				if not ok then
					-- Scan-2's completion tier proved this Bank complete at
					-- the selected tuple: an instrumented trace that dies is
					-- a loud worker abort -- a finding, never a column
					-- (contracts 9.1).
					error("WP40 geometry partition: census Scan-3b " ..
						"instrumented trace of " .. bank.id .. " died where " ..
						"Scan-2 proved the selected tuple complete: " ..
						tostring(points), 0)
				end
				row.class = "bank_trace_complete_select"
				row.station_count = #points
				result.scan3b_traces[bank.id] = points
				fold_bank_trace_observation(row, bank.id, observer, steps,
					selections, step_rows, selection_rows)
			end
			bank_rows[#bank_rows + 1] = row
		end
		sort_step_rows(step_rows)

		-- R20/R21 occupancy, evaluated on the dead condition only: the
		-- sixteen via all-tuples-dead on their edges, the four head Banks
		-- via their Scan-3a trace rows.  Emission order is edge order then
		-- head-Bank order -- deterministic by construction.
		for index = 1, #stage.provisional_edges do
			local edge_id = stage.provisional_edges[index].id
			local descriptor = result.scan3b_edge_descriptors[edge_id]
			if descriptor then
				local events = census_scan3b_classify_events(descriptor,
					alternative_probe)
				for event_index = 1, #events do
					event_rows[#event_rows + 1] = events[event_index]
				end
			end
		end
		for index = 1, #result.scan3_banks do
			local head_row = result.scan3_banks[index]
			if head_row.class ~= "bank_trace_complete_select" and
					head_row.class ~= "bank_terminal_unresolved_reject" then
				local bank = bank_source_by_id[head_row.id]
				for _, terminal in ipairs({bank.start_terminal,
						bank.end_terminal}) do
					if terminal.kind == "wing_junction_tail_side" and
							alternative_probe(bank.id, terminal.wing_id) ==
								"complete" then
						event_rows[#event_rows + 1] = {
							class = "wing_pair_dead_alternative_event",
							site = terminal.wing_id .. ":" .. terminal.tail_side,
							detail = bank.id .. " dead at the selected " ..
								"wedge-valid pair of " .. terminal.wing_id ..
								" while the next wedge-valid pair completes"}
					end
				end
			end
		end
		return result
	end

	-- ------------------------------------------------------------------
	-- Census Scan-4 (contracts 9.1): the face tier over all 38 zone-face
	-- polygons, the Whole tier's exhaustive H38 row-run partition gated on
	-- all-faces-simple, and the excluded-fragment obligations -- evaluated
	-- on Scan-4 members only, on the same stage build the earlier scans
	-- paid for.  The scanners classify by decided policy; the tiers'
	-- internal invariants abort loudly rather than classify.
	-- ------------------------------------------------------------------

	-- The face classification map (the stage-reject precedent): the
	-- compiler's own validate_face_polygon decides, its message maps onto a
	-- class per fail site, and anything unmatched is re-raised.  Ordered:
	-- first match wins.
	local face_reject_by_fragment = {
		{" is not closed", "face_not_closed_reject"},
		{" is not eight-connected", "face_composition_reject"},
		-- The two-tier validator's by-name failures (contracts 11.5-C,
		-- completed by 11.9): the opposing diagonal and the three touch
		-- guard conditions all classify face_non_simple_reject -- the loud
		-- class for anything the window-guarded acceptance does not absorb.
		-- The former blanket " is not simple" message no longer exists, and
		-- the 11.5-C " has a non-zero-width repeat" failure retired with the
		-- 11.9 ruling: a non-zero-width touch is the accepted pinch form,
		-- and what stays loud at that check is the crossing.
		{" has an opposing cell diagonal", "face_non_simple_reject"},
		{" appendix station repeated more than twice", "face_non_simple_reject"},
		{" has a non-join-local repeat", "face_non_simple_reject"},
		{" has a crossing repeat", "face_non_simple_reject"},
		{" is not CCW", "face_wrong_orientation_reject"},
	}
	local function census_face_classify(id, polygon, join_keys)
		local ok, outcome, pinches = pcall(validate_face_polygon, id, polygon,
			join_keys)
		if ok then
			if outcome > 0 or pinches > 0 then
				-- The DECIDED touch acceptance carries its filament and
				-- pinch station counts (contracts 11.5-C/11.9: measured
				-- different things stay different claims -- both forms
				-- classify face_appendix_select, the counts name the form).
				return "face_appendix_select",
					"appendix_stations=" .. outcome ..
					" pinch_stations=" .. pinches, outcome, pinches
			end
			return "face_simple_select", nil, 0, 0
		end
		local message = tostring(outcome)
		local class = classify_message(face_reject_by_fragment, message)
		if not class then error(outcome, 0) end
		return class, message, 0, 0
	end

	-- The known composition-failure sites of the face assembly, so a pcall
	-- there is a classification map and never an unfiltered sink (the M3
	-- lesson): anything else re-raises.
	local face_composition_fragments = {
		{" component graph does not join", "face_composition_reject"},
		{" authority components do not join", "face_composition_reject"},
		{" has no materialized final edge", "face_composition_reject"},
		{" final endpoints are absent", "face_composition_reject"},
		{" terminal-trimmed span is absent", "face_composition_reject"},
	}

	-- The default per-tier stopwatch (contracts 9.5).  `census_scan` accepts an
	-- optional `tier_mark`, called with a tier name once that tier has returned,
	-- so the cost probe can measure the marginal each new tier adds instead of
	-- inferring it from two whole passes.  Pure telemetry: every production
	-- caller leaves it absent and pays these empty calls, and nothing the hook
	-- is given can reach a row, an artifact or a digest.
	local function tier_noop() end

	local function census_scan4(stage, result, tracer, tier_mark, whole_observer,
			face_observer)
		local face_rows_out, whole_rows, interval_rows, fragment_rows =
			{}, {}, {}, {}
		result.scan4_faces = face_rows_out
		result.scan4_wholes = whole_rows
		result.scan4_whole_intervals = interval_rows
		result.scan4_fragments = fragment_rows

		-- ----------------------------------------------------------
		-- Final edge materialization, projected from compile_impl's own
		-- finalization: transition edges are the selected tuple's probe
		-- bytes (only the selected probe materializes, source authority
		-- section 4); ordinary edges retain their single interval;
		-- attachment edges replace the terminal control with A and
		-- re-raster.  A failure marks the edge unmaterialized and every
		-- face referencing it classifies face_composition_reject.
		-- ----------------------------------------------------------
		local final_edges, edge_failures = {}, {}
		local attachment_a = {}
		for index = 1, #result.attachments do
			local row = result.attachments[index]
			if row.a then
				attachment_a[row.id] = {x = row.a.x, z = row.a.z}
			end
		end
		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			local edge_transitions = stage.transitions_by_edge[edge.id]
			local attachment = stage.attachment_by_edge[edge.id]
			local ok, failure = pcall(function()
				if edge_transitions then
					local selected = result.scan2_selected[edge.id]
					if not selected or not selected.probe then
						fail(edge.id .. " has no materialized final edge")
					end
					final_edges[edge.id] = selected.probe
					return
				end
				local intervals = stage.maximal_dry_intervals(edge)
				if attachment then
					if #intervals ~= 1 then
						fail(edge.id .. " has a second retained land run")
					end
					local interval = intervals[1]
					local selected_attachment = stage.attachment_distance(
						attachment, edge, interval)
					if selected_attachment.distance > 1 then
						fail("Attachment E/A distance exceeds one")
					end
					local best = selected_attachment.a
					local retained_controls = {}
					for control_index = 1, #edge.shifted_controls do
						local point = edge.shifted_controls[control_index]
						if stage.dry_land(point.x, point.z) then
							retained_controls[#retained_controls + 1] =
								control_index
						end
					end
					if #retained_controls == 0 then
						fail(attachment.id .. " has no retained controls")
					end
					for retained_index = 2, #retained_controls do
						if retained_controls[retained_index] ~=
								retained_controls[retained_index - 1] + 1 then
							fail(attachment.id ..
								" retained controls form a second run")
						end
					end
					local controls = {}
					local function append_control(point)
						append_dedup(controls, point)
					end
					if attachment.edge_endpoint == "from" then
						append_control(best)
						for retained_index = 1, #retained_controls do
							append_control(edge.shifted_controls[
								retained_controls[retained_index]])
						end
						append_control(edge.stations[interval.finish])
					else
						append_control(edge.stations[interval.first])
						for retained_index = 1, #retained_controls do
							append_control(edge.shifted_controls[
								retained_controls[retained_index]])
						end
						append_control(best)
					end
					local stations = raster.final_raster(controls, false)
					raster.validate_final({id = edge.id, kind = "land_edge",
						closed = false,
						max_displacement = edge.source.max_displacement},
						edge.base_stations, stations)
					final_edges[edge.id] = stations
					return
				end
				if #intervals ~= 1 then
					fail(edge.id .. " has a second retained land run")
				end
				local stations = {}
				for station_index = intervals[1].first, intervals[1].finish do
					append_dedup(stations, edge.stations[station_index])
				end
				final_edges[edge.id] = stations
			end)
			if not ok then
				edge_failures[edge.id] = tostring(failure)
			end
		end

		-- ----------------------------------------------------------
		-- Spans, arcs and faces, the compile_impl composition projected on
		-- the shared tracer.  Land transition terminals resolve through the
		-- Scan-3b materialized table the tracer's land hook reads.
		-- ----------------------------------------------------------
		local span_by_id = {}
		for index = 1, #source.perimeter_spans do
			local span = source.perimeter_spans[index]
			local perimeter = stage.perimeter_by_id[span.perimeter_id]
			local function boundary_point(boundary)
				if boundary.kind == "perimeter_attachment" then
					local a = attachment_a[boundary.attachment_id]
					if not a then
						fail(span.id .. " final endpoints are absent")
					end
					return a
				end
				return perimeter.source.polygon[boundary.index]
			end
			local ok, failure = pcall(function()
				local first_point = boundary_point(span.start_boundary)
				local last_point = boundary_point(span.end_boundary)
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
				if span.face_direction == "reverse" then
					points = reverse_points(points)
				end
				span_by_id[span.id] = {source = span, stations = points}
			end)
			if not ok then
				span_by_id[span.id] = {failure = tostring(failure)}
			end
		end

		local bank_points = {}
		for id, points in pairs(result.scan3a_traces) do
			bank_points[id] = points
		end
		for id, points in pairs(result.scan3b_traces) do
			bank_points[id] = points
		end

		local function component_span(component)
			local span = span_by_id[component.ref_id]
			if not span then
				fail(component.ref_id .. " terminal-trimmed span is absent")
			end
			if span.failure then error(span.failure, 0) end
			local full = span.stations
			local first_point = component.from_terminal ~= false and
				tracer.resolve_terminal(component.from_terminal).point or full[1]
			local last_point = component.to_terminal ~= false and
				tracer.resolve_terminal(component.to_terminal).point or
				full[#full]
			local first_index, last_index
			for station_index = 1, #full do
				if not first_index and
						key(full[station_index]) == key(first_point) then
					first_index = station_index
				end
				if key(full[station_index]) == key(last_point) then
					last_index = station_index
				end
			end
			if not first_index or not last_index or first_index > last_index then
				fail(component.ref_id .. " terminal-trimmed span is absent")
			end
			local points = {}
			for station_index = first_index, last_index do
				points[#points + 1] = {x = full[station_index].x,
					z = full[station_index].z}
			end
			return points
		end

		local arc_by_id, arc_failures = {}, {}
		for index = 1, #source.face_arcs do
			local arc = source.face_arcs[index]
			local ok, failure = pcall(function()
				local points, join_keys = {}, {}
				for component_index = 1, #arc.authority_components do
					local component = arc.authority_components[component_index]
					local part
					if component.kind == "perimeter_span" then
						part = component_span(component)
					elseif component.kind == "bay_bank" then
						local traced = bank_points[component.ref_id]
						if not traced then
							fail(component.ref_id ..
								" has no materialized final edge")
						end
						part = copy_points(traced)
					elseif component.boundary_role == "island_coast" then
						part = copy_points(
							stage.island_by_id[component.source_ref].stations)
						part[#part + 1] = {x = part[1].x, z = part[1].z}
					else
						part = raster.final_raster(component.control, false)
					end
					if #points > 0 and key(points[#points]) ~= key(part[1]) then
						fail(arc.id .. " authority components do not join")
					end
					-- Component joins feed the appendix window, exactly as
					-- in compile_impl's composition (contracts 11.5-C).
					if #points > 0 then join_keys[key(part[1])] = true end
					append_points(points, part)
				end
				arc_by_id[arc.id] = {source = arc, stations = points,
					join_keys = join_keys}
			end)
			if not ok then
				local message = tostring(failure)
				if not classify_message(face_composition_fragments, message) then
					error(failure, 0)
				end
				arc_failures[arc.id] = message
			end
		end

		local composed_faces = {}
		local all_accepted, blocking_face = true, nil
		for index = 1, #source.zone_faces do
			local face = source.zone_faces[index]
			local row = {id = face.id}
			local upstream
			for _, component in ipairs(face.cycle) do
				if component.kind ~= "shared_edge" and
						arc_failures[component.ref_id] then
					upstream = component.ref_id .. ": " ..
						arc_failures[component.ref_id]
					break
				end
			end
			if upstream then
				row.class = "face_upstream_not_evaluated"
				row.detail = upstream
			else
				local ok, failure = pcall(function()
					local polygon, join_keys = {}, {}
					for _, component in ipairs(face.cycle) do
						local points
						if component.kind == "shared_edge" then
							points = final_edges[component.ref_id]
							if not points then
								fail(component.ref_id ..
									" has no materialized final edge" ..
									(edge_failures[component.ref_id] and
										(": " .. edge_failures[component.ref_id])
										or ""))
							end
						else
							points = arc_by_id[component.ref_id].stations
							for join_key in pairs(
									arc_by_id[component.ref_id].join_keys) do
								join_keys[join_key] = true
							end
						end
						if component.direction == "reverse" then
							points = reverse_points(points)
						else
							points = copy_points(points)
						end
						if #polygon > 0 and
								key(polygon[#polygon]) ~= key(points[1]) then
							fail(face.id .. " component graph does not join")
						end
						if #polygon > 0 then join_keys[key(points[1])] = true end
						append_points(polygon, points)
					end
					join_keys[key(polygon[1])] = true
					return {polygon = polygon, join_keys = join_keys}
				end)
				if ok then
					local polygon = failure.polygon
					row.station_count = #polygon
					local appendix_stations, pinch_stations
					row.class, row.detail, appendix_stations, pinch_stations =
						census_face_classify(face.id, polygon,
							failure.join_keys)
					-- The face-tier observation seam (the whole_observer
					-- precedent, contracts 10.3 step 3: telemetry only,
					-- production callers leave it nil, nothing it is given
					-- reaches a row or a digest).
					if face_observer then
						face_observer({id = face.id, polygon = polygon,
							join_keys = failure.join_keys, class = row.class,
							detail = row.detail})
					end
					composed_faces[#composed_faces + 1] = {id = face.id,
						zone_id = face.zone_id, polygon = polygon,
						simple = row.class == "face_simple_select",
						appendix_stations = appendix_stations,
						pinch_stations = pinch_stations}
				else
					local message = tostring(failure)
					if not classify_message(face_composition_fragments,
							message) then
						error(failure, 0)
					end
					row.class = "face_composition_reject"
					row.detail = message
				end
			end
			if row.class ~= "face_simple_select" and
					row.class ~= "face_appendix_select" then
				all_accepted = false
				if not blocking_face then blocking_face = face.id end
			end
			face_rows_out[#face_rows_out + 1] = row
		end
		tier_mark("scan4_face")

		-- ----------------------------------------------------------
		-- The Whole tier, gated on every face accepted -- face_simple_select
		-- on the fast path or face_appendix_select through the window-guarded
		-- acceptance, whose winding region truth the row derivation carries
		-- (contracts 9.1, amended by 11.5-C).
		-- ----------------------------------------------------------
		if not all_accepted then
			whole_rows[1] = {class = "whole_not_evaluated",
				blocking_face = blocking_face}
		else
			-- The prepared tables come from the same constructors
			-- compile_impl's production Whole gate consumes (section 11);
			-- only the m cross-check below stays census-side.
			local footprint_rows = whole_footprint_rows(stage)
			local boundary_columns, water_rows = whole_water_rows(stage)
			local face_rows, face_indexes = whole_face_row_runs(composed_faces)
			local declared = whole_declared(stage, final_edges)

			-- Residue adoption (contracts 11.7-B, ring connectivity added by
			-- 11.9 family A) between face composition and the footprint
			-- proof, the same shared function the production Whole gate
			-- runs.  A rejected multi-face chain classifies
			-- residual_multi_face_reject below (its columns also stay
			-- uncovered, so the proof's own g keeps rejecting the seed);
			-- adopted chains are face region membership from here on.
			local ring_links = whole_ring_links(stage)
			local adoption = whole_adopt_residue({
				footprint_rows = footprint_rows, face_rows = face_rows,
				water_rows = water_rows, declared = declared,
				ring_links = ring_links})

			-- The m cross-check: at every interval's first column the
			-- run-derived decision is compared against the stage's own
			-- predicates -- the water mask fields planned_water reads
			-- (without its point cache) and the faces' point-in-polygon
			-- classes -- so the row-run normalization itself is measured,
			-- not trusted.  An adopted run inverts the face check: adoption
			-- is region membership for a column the polygon does NOT
			-- enclose, so the stage predicate must say strictly outside --
			-- anything else means the chain was not residue at all.
			local function check(z, x, water_owner, covering_faces)
				local point_key = x .. ":" .. z
				local predicate_owner = nil
				for bay_index = 1, #stage.bays do
					local context = stage.bay_context_by_id[
						stage.bays[bay_index].source.id]
					local raw = false
					local runs = context.raw_rows[z]
					if runs then
						for run_index = 1, #runs do
							if x >= runs[run_index].first and
									x <= runs[run_index].finish then
								raw = true break
							end
						end
					end
					if raw or context.fill[point_key] == true then
						if not boundary_columns[point_key] or
								context.aperture.included[point_key] then
							if predicate_owner then return false end
							predicate_owner = context.bay.source.id
						end
					end
				end
				if predicate_owner ~= water_owner then return false end
				if not water_owner then
					for face_index = 1, #covering_faces do
						local face_run = covering_faces[face_index]
						local class = exact.indexed_polygon_class(
							face_indexes[face_run.id], x, z)
						if face_run.adopted then
							if class >= 0 then return false end
						elseif class < 0 then
							return false
						end
					end
				end
				return true
			end

			local totals = census_whole_classify({
				footprint_rows = footprint_rows, face_rows = face_rows,
				water_rows = water_rows, declared = declared, check = check})
			-- The rejected chains of the adoption rule, loud by name in the
			-- interval rows (contracts 11.7-B: expected vacuous, occupancy
			-- measured, never absorbed).  Nothing is added when the family
			-- is empty, so a clean record keeps its exact bytes.
			if #adoption.rejected > 0 then
				local entry = {intervals = 0, columns = 0}
				for index = 1, #adoption.rejected do
					local chain = adoption.rejected[index]
					entry.intervals = entry.intervals + #chain.members
					entry.columns = entry.columns + chain.columns
					if not entry.witness then entry.witness = chain.witness end
				end
				totals.classes.residual_multi_face_reject = entry
			end
			whole_rows[1] = {class = "whole_evaluated",
				columns = totals.columns,
				planned_water_columns = totals.planned_water,
				dry_columns = totals.dry, g = totals.g, o = totals.o,
				r = totals.r, m = totals.m}
			local class_names = {}
			for class in pairs(totals.classes) do
				class_names[#class_names + 1] = class
			end
			table.sort(class_names)
			for index = 1, #class_names do
				local entry = totals.classes[class_names[index]]
				interval_rows[#interval_rows + 1] = {site = "footprint",
					class = class_names[index],
					interval_count = entry.intervals,
					column_count = entry.columns, witness = entry.witness}
			end
			-- The Whole-tier observation seam (the tier_mark precedent and
			-- the same telemetry-only contract, contracts 10.3 step 3):
			-- called once per evaluated Whole tier, after every row above is
			-- written, with the tier's own prepared tables and the
			-- composition context that produced them.  Every production
			-- caller leaves it nil and this branch never runs -- the
			-- unchanged worker-KAT digest is the proof -- and the return
			-- value is ignored.  Observers are read-only consumers by
			-- contract (diagnosis probes under tools/).
			if whole_observer then
				whole_observer({
					footprint_rows = footprint_rows,
					face_rows = face_rows,
					water_rows = water_rows,
					declared = declared,
					ring_links = ring_links,
					boundary_columns = boundary_columns,
					composed_faces = composed_faces,
					face_indexes = face_indexes,
					final_edges = final_edges,
					span_by_id = span_by_id,
					bank_points = bank_points,
					adoption = adoption,
					totals = totals})
			end
		end
		tier_mark("scan4_whole")

		-- ----------------------------------------------------------
		-- The excluded-fragment obligations (contracts 9.1): the
		-- nonselected maximal dry intervals of the transition edges and the
		-- selected-interval stations the joint terminals clipped off --
		-- compile_impl's exact fragment set -- each classified per station.
		-- Face ownership needs every face composed and simple; otherwise
		-- the fragment could not be measured and says so.
		-- ----------------------------------------------------------
		local fragments = {}
		for index = 1, #stage.provisional_edges do
			local edge = stage.provisional_edges[index]
			if stage.transitions_by_edge[edge.id] then
				local selected = result.scan2_selected[edge.id]
				if selected then
					local intervals = stage.maximal_dry_intervals(edge)
					for interval_index = 1, #intervals do
						local interval = intervals[interval_index]
						if interval.first ~= selected.interval.first or
								interval.finish ~= selected.interval.finish then
							for station_index = interval.first,
									interval.finish do
								fragments[#fragments + 1] = {edge = edge,
									station_index = station_index}
							end
						end
					end
					local span_first = selected.from_i or
						selected.interval.first
					local span_finish = selected.to_i or
						selected.interval.finish
					for station_index = selected.interval.first,
							span_first - 1 do
						fragments[#fragments + 1] = {edge = edge,
							station_index = station_index}
					end
					for station_index = span_finish + 1,
							selected.interval.finish do
						fragments[#fragments + 1] = {edge = edge,
							station_index = station_index}
					end
				end
			end
		end
		if #fragments > 0 then
			local faces_measurable = all_accepted and
				#composed_faces == #source.zone_faces
			local land_identity, bank_identity, terminal_identity = {}, {}, {}
			for edge_id, stations in pairs(final_edges) do
				for station_index = 1, #stations do
					local point_key = key(stations[station_index])
					land_identity[point_key] =
						(land_identity[point_key] or 0) + 1
				end
			end
			for _, points in pairs(bank_points) do
				for station_index = 1, #points do
					local point_key = key(points[station_index])
					bank_identity[point_key] =
						(bank_identity[point_key] or 0) + 1
				end
			end
			for _, terminal in pairs(tracer.terminal_cache) do
				if terminal.point then
					terminal_identity[key(terminal.point)] = true
				end
			end
			for index = 1, #fragments do
				local fragment = fragments[index]
				local point = fragment.edge.stations[fragment.station_index]
				local point_key = key(point)
				local row = {edge_id = fragment.edge.id,
					station = fragment.station_index,
					x = point.x, z = point.z,
					land_count = land_identity[point_key] or 0,
					bank_count = bank_identity[point_key] or 0,
					terminal_identity = terminal_identity[point_key] == true}
				if not faces_measurable then
					row.class = "fragment_not_evaluated"
				else
					local face_count = 0
					for face_index = 1, #composed_faces do
						if exact.polygon_class(point.x, point.z,
								composed_faces[face_index].polygon) >= 0 then
							face_count = face_count + 1
						end
					end
					row.face_count = face_count
					if row.land_count > 0 or row.terminal_identity then
						row.class = "fragment_identity_conflict_reject"
					else
						-- The compile-path owner rule
						-- (validate_excluded_fragment_evidence): a Bank
						-- boundary owns first; otherwise exactly one dry
						-- Face owns.
						local owner_count = row.bank_count > 0 and
							row.bank_count or face_count
						if owner_count == 1 then
							row.class = "fragment_owned_once_select"
						elseif owner_count == 0 then
							row.class = "fragment_unowned_reject"
						else
							row.class = "fragment_multi_owner_reject"
						end
					end
				end
				fragment_rows[#fragment_rows + 1] = row
			end
		end
		tier_mark("scan4_fragment")
		return result
	end

	-- The classified stage-reject vocabulary (analysis section 3-F9, plan
	-- section 6.4; decided 2026-08-17).  Section 3-F9 has always declared
	-- aperture interval malformation REJECTED -- "wrap, overlap, second run,
	-- dry station, boundary" -- but the deciding predicates live in
	-- build_scan_stage's aperture block, where M1 could only abort.  The
	-- first full-W starts proved the class occupied: three shards died
	-- deterministically on "has a wrapping or second aperture run" at
	-- roughly one seed in 285, so the six seed-dependent aperture-block
	-- failures below become recorded stage_reject rows and the scan
	-- continues with the next seed.
	--
	-- The boundary is drawn per fail site, not per message shape:
	--  * "mouth absent from the final/authored perimeter" stays a loud
	--    abort: Bay centrelines are no-jitter displacement sources, so the
	--    declared mouth sits on the final perimeter on every seed or the
	--    catalog is wrong -- a structural defect -- and the authored lookup
	--    is dominated by the canonical one, which runs first over the same
	--    point set.
	--  * "is not a maximal aperture run" stays a loud abort: 3-F9's
	--    "boundary stations passing it" is unreachable by construction --
	--    the expansion loops terminate exactly where the Bay predicate
	--    fails -- so a hit would be an evaluation-determinism fault, not a
	--    seed configuration.
	--  * everything outside the aperture block (S1 validity, notch
	--    ownership, roster shapes) is outside the vocabulary entirely: the
	--    classifier requires an aperture row id at the message head, and an
	--    unmatched failure is re-raised -- the M3 lesson, no blind pcall.
	--
	-- One row per seed: the block aborts at its first failing aperture in
	-- source order, so per-(site, class) occupancy counts are lower bounds
	-- conditioned on that order.  Ordered, first match wins, like the
	-- aperture and bank tables above; the class list is exported below and
	-- the worker refuses to run when it disagrees with the authority's copy.
	local stage_reject_by_fragment = {
		{" aperture is not nonwrapping", "aperture_canonical_wrap_reject"},
		{" aperture contains a dry station", "aperture_dry_station_reject"},
		{" overlaps bay_mouth_aperture:", "aperture_overlap_reject"},
		{" has a wrapping or second aperture run", "aperture_second_run_reject"},
		{" authored Bank aperture wraps", "aperture_authored_wrap_reject"},
		{" authored Bank aperture has a second run",
			"aperture_authored_second_run_reject"},
	}
	local stage_reject_classes = {}
	for index = 1, #stage_reject_by_fragment do
		stage_reject_classes[index] = stage_reject_by_fragment[index][2]
	end

	local function census_scan(seed, options)
		options = options or {}
		local tier_mark = options.tier_mark or tier_noop
		-- The pcall wraps stage construction only: a failure inside the scans
		-- happens on a stage that already exists and stays a loud abort.
		local built, stage = pcall(build_scan_stage, seed)
		if not built then
			local message = tostring(stage)
			-- fail_prefix carries no Lua pattern magic, checked where it is
			-- declared by its use in this anchor.
			local site = message:match(
				"^" .. fail_prefix .. "(bay_mouth_aperture:[%w_]+) ")
			local class = site and
				classify_message(stage_reject_by_fragment, message)
			if not class then error(stage, 0) end
			return {schema = census_scan_schema, seed = seed,
				stage_reject = {site = site, class = class, detail = message}}
		end
		tier_mark("stage")
		local result, selected_by_edge = census_scan1(stage, seed)
		tier_mark("scan1")
		-- One tracer for every remaining scan.  Scan-3a runs first so its Wing
		-- analysis fills the shared tail cache that Scan-2's completion tier
		-- would otherwise fill unobserved; the terminal cache is shared for the
		-- same reason, and neither scan changes what the other measures.  The
		-- land hook reads the table Scan-3b fills with the selected joint
		-- resolutions, so it answers nothing before Scan-3b ran and exactly
		-- the selected resolution afterwards -- which is what lets Scan-4's
		-- composition consume the compiler's own terminal seam.
		local land_transitions = {}
		local tracer = new_bank_tracer(stage, {
			land_transition = function(cache_key)
				return land_transitions[cache_key]
			end})
		census_scan3a(stage, result, tracer)
		tier_mark("scan3a")
		census_scan2(stage, result, selected_by_edge, tracer)
		tier_mark("scan2")
		census_scan3b(stage, result, tracer, land_transitions)
		tier_mark("scan3b")
		if options.scan4 then
			census_scan4(stage, result, tracer, tier_mark,
				options.scan4_whole_observer, options.scan4_face_observer)
		end
		return result
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
	partition.census_scan = census_scan
	partition.census_scan_schema = census_scan_schema
	-- The Scan-3b/4 classifier seams, exported for the synthetic gate KATs
	-- (contracts 9.4: no measured configuration reaches those branches, so
	-- only synthetic cases can pin them, and they must drive the same
	-- functions the scan runs).
	partition.census_scan3b_classify_events = census_scan3b_classify_events
	partition.census_face_classify = census_face_classify
	partition.census_whole_classify = census_whole_classify
	-- The section-11 seams: the ruled appendix window (pinned in the census
	-- authority; the worker refuses to run when the copies disagree), the
	-- shared residue-adoption rule and the face row derivation, exported so
	-- the synthetic gate KATs drive the same functions the scan and the
	-- production Whole gate run.
	partition.face_appendix_window = FACE_APPENDIX_WINDOW
	partition.census_whole_adopt_residue = whole_adopt_residue
	partition.census_whole_face_row_runs = whole_face_row_runs
	partition.census_whole_ring_links = whole_ring_links
	partition.joint_tuple_less_compile = joint_tuple_less_compile
	partition.joint_tuple_less_census = joint_tuple_less_census
	partition.census_stage_reject_classes = stage_reject_classes
	partition.classify_junction_pair = classify_junction_pair
	partition.pair_clearance = pair_clearance
	partition.extreme_scalar_records = boundary.extreme_scalar_records
	partition.new_extreme_scalar_session = boundary.new_extreme_scalar_session
	partition.s1_source_projection = boundary.s1_source_projection
	partition.s1_source_checksum = boundary.s1_source_checksum
	-- Re-exported so an S1-scope consumer can name the projection schema without
	-- instantiating a second boundary. Provenance only; no compiled geometry.
	partition.s1_source_projection_schema = boundary.PROJECTION_SCHEMA
	partition.bay_owner = bay_owner
	partition.validate_bay_payload = validate_bay_payload
	partition.coast_source = coast_source
	partition.coast_consider = coast_consider
	partition.validate_coast_payload = validate_coast_payload
	partition.validate_junction_pair = validate_junction_pair
	partition.select_attachment_station = select_attachment_station
	partition.select_incidence_interval = select_incidence_interval
	partition.select_control_subsequence = select_control_subsequence
	partition.validate_transition_dry_flags = validate_transition_dry_flags
	partition.validate_excluded_fragment_evidence =
		validate_excluded_fragment_evidence
	partition.select_aperture_transition = select_aperture_transition
	partition.aperture_tail_water_side = aperture_tail_water_side
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
