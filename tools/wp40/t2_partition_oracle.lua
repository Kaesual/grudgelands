-- Shared, test-only exhaustive partition oracle. Production compilation does
-- not load this module; both the retained Seed0/max-u64 regression and C1
-- selected-winner workers consume this one implementation.
return function(dependencies)
	assert(type(dependencies) == "table")
	local canonical = assert(dependencies.canonical)
	local deterministic = assert(dependencies.deterministic)
	local raw_sha256 = assert(dependencies.raw_sha256)
	local raster = assert(dependencies.raster)
	local source = assert(dependencies.source)
	local exact = assert(dependencies.exact)
	local compiler = assert(dependencies.compiler)
	local by_id = assert(dependencies.by_id)
	local signed_array = assert(dependencies.signed_array)
	local named_scalar = assert(dependencies.named_scalar)
	local named_array_value = assert(dependencies.named_array_value)
	local deep_copy = assert(dependencies.deep_copy)
	local expect_error = assert(dependencies.expect_error)
	local oracle_cardinal = assert(dependencies.oracle_cardinal)
	local payload_points = assert(dependencies.payload_points)
	local trace_independent_banks_again = assert(dependencies.trace_independent_banks_again)
	local same_point_bytes = assert(dependencies.same_point_bytes)
	local independent_bank_by_id = assert(dependencies.independent_bank_by_id)
	local attachment_oracle_by_id = assert(dependencies.attachment_oracle_by_id)
	local authored_aperture_by_id = assert(dependencies.authored_aperture_by_id)
	local bay_source_by_id = assert(dependencies.bay_source_by_id)
	local zone_numeric = assert(dependencies.zone_numeric)
	local source_by_id = assert(dependencies.source_by_id)
	local function run_exhaustive_partition_oracle(compiled_value, seed, oracle_world,
			perimeter_map, profile)
		assert(type(profile) == "table" and type(profile.mode) == "string",
			"partition oracle profile is missing")
		local focused_seed0 = profile.mode == "seed0"
		local focused_max_u64 = profile.mode == "max_u64"
		assert(focused_seed0 or focused_max_u64 or profile.mode == "selected",
			"partition oracle profile mode changed")
		local compiled = compiled_value
		local bay_oracles = oracle_world.bay_oracles
		local independent_perimeter_by_id = perimeter_map
		local function point_key(x, z) return x .. ":" .. z end
		local independent_bay_deltas = {}
		local function expected_bay_delta_values(authored)
			local expected = {}
			for segment_index = 1, #authored.centreline - 1 do
				local stations = raster.segment(authored.centreline[segment_index],
					authored.centreline[segment_index + 1])
				local noise = {schema = "grug_wp40_geometry_source_v1", seed = seed,
					domain = authored.noise_domain, feature = "", octaves = {
						{period = 256, amplitude_numerator = 2, amplitude_denominator = 3},
						{period = 512, amplitude_numerator = 1, amplitude_denominator = 3}}}
				for station_index = 1, #stations do
					local point = stations[station_index]
					local noise_q = deterministic.clamp(deterministic.value_noise_2d(canonical,
						raw_sha256, noise, point.x, point.z), -65536, 65536)
					local distance = math.min(station_index - 1, #stations - station_index)
					local taper_q = deterministic.smootherstep(deterministic.qfrom_ratio(
						math.min(distance, 96), 96))
					expected[#expected + 1] = deterministic.qround(deterministic.qmul(
						deterministic.qmul(noise_q, authored.max_displacement * 65536),
						taper_q))
				end
			end
			return expected
		end
		local function validate_bay_deltas(payload, authored, expected)
			local actual = signed_array(payload, "station_radius_delta")
			if #actual ~= #expected then error("Bay deterministic delta count changed") end
			for index = 1, #expected do
				if actual[index] ~= expected[index] then
					error("Bay deterministic delta bytes changed")
				end
			end
			return true
		end
		for bay_index = 1, #source.bays do
			local authored = source.bays[bay_index]
			local expected = expected_bay_delta_values(authored)
			independent_bay_deltas[authored.id] = expected
			assert(validate_bay_deltas(by_id(compiled.families.bays, authored.id),
				authored, expected))
		end
		if focused_seed0 then
			local authored = source.bays[1]
			local corrupted = deep_copy(by_id(compiled.families.bays, authored.id))
			local deltas = signed_array(corrupted, "station_radius_delta")
			local changed
			for index = 2, #deltas - 1 do
				if deltas[index] > -authored.max_displacement and
						deltas[index] < authored.max_displacement then
					deltas[index] = deltas[index] + (deltas[index] < authored.max_displacement and
						1 or -1)
					changed = true break
				end
			end
			assert(changed)
			expect_error("Bay deterministic delta bytes changed", function()
				validate_bay_deltas(corrupted, authored, independent_bay_deltas[authored.id])
			end)
		end
		local function append_run(rows, z, run)
			local row = rows[z]
			if not row then row = {} rows[z] = row end
			row[#row + 1] = run
		end
		-- The winding row normalization (contracts 11.5-C): the class between
		-- consecutive boundary columns of a row is constant for EVERY closed
		-- eight-connected ring, simple or not -- an edge is a unit step, so
		-- any edge meeting an integer row does so at a station of that row --
		-- and the winding membership of exact.indexed_polygon_class requires
		-- closure only.  `repeat_tolerant` is set exactly for a dry face the
		-- two-tier acceptance below admitted with appendixes: the zero-width
		-- appendix column appears twice on the ring and once in its row.  On
		-- every other polygon a repeated column stays the loud failure.
		local function polygon_row_runs(points, repeat_tolerant)
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
						assert(repeat_tolerant,
							"simple dense polygon repeats a row boundary point")
					else
						if previous and x > previous + 1 then
							local first, finish = previous + 1, x - 1
							if exact.indexed_polygon_class(polygon_index, first, z) > 0 then
								runs[#runs + 1] = {first = first, finish = finish, class = 1}
							end
						end
						runs[#runs + 1] = {first = x, finish = x, class = 0}
						previous = x
					end
				end
				table.sort(runs, function(a, b) return a.first < b.first end)
				result[z] = runs
			end
			return result
		end
		-- The oracle's independent copy of the section-11.5-C two-tier
		-- acceptance as completed by the 11.9 ruling: a dry-face ring with
		-- repeated stations is admitted only when every repeat is a
		-- join-local, LOCALLY NON-CROSSING self-touch -- each condition
		-- failing by its own name; the ratified zero-width predicate (no
		-- cardinal 4-neighbour strictly interior by winding) records the
		-- touch form, filament appendix against pinch, instead of gating
		-- it.  W = 12 is the ruled window (the section-11.10
		-- complete-distribution maximum, pin lineage 8 -> 11 -> 12),
		-- pinned with its measurement provenance in
		-- t2_census_authority.lua; partition.lua owns the production copy
		-- and the census worker bridges the two.  `join_keys` comes from
		-- what the oracle independently knows of the composition: the
		-- payload's shared-edge and Bank station endpoints (every part
		-- boundary is a join; a subset of joins only makes the guard
		-- stricter).  Returns the filament (appendix) and pinch station
		-- counts, both zero on a simple ring.
		local FACE_APPENDIX_WINDOW = 12
		local touch_direction_index = {
			["1:0"] = 0, ["1:1"] = 1, ["0:1"] = 2, ["-1:1"] = 3,
			["-1:0"] = 4, ["-1:-1"] = 5, ["0:-1"] = 6, ["1:-1"] = 7}
		local function face_appendix_acceptance(id, polygon, join_keys)
			local seen, repeated_keys, repeats = {}, {}, {}
			for index = 1, #polygon - 1 do
				local station_key = point_key(polygon[index].x, polygon[index].z)
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
			end
			if #repeated_keys == 0 then return 0, 0 end
			local appendix_count, pinch_count = 0, 0
			local ring_count = #polygon - 1
			local join_indices = {}
			for index = 1, ring_count do
				if join_keys[point_key(polygon[index].x, polygon[index].z)] then
					join_indices[#join_indices + 1] = index
				end
			end
			local polygon_index = exact.polygon_index(polygon)
			for order = 1, #repeated_keys do
				local station_key = repeated_keys[order]
				local entry = repeats[station_key]
				assert(#entry <= 2, id ..
					" appendix station repeated more than twice at " .. station_key)
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
				assert(anchored, id .. " has a non-join-local repeat at " ..
					station_key)
				-- Locally non-crossing (contracts 11.9): the repeated
				-- station splits the ring into two loops, and the touch
				-- crosses exactly when the loops' edge-end pairs --
				-- (out1, in2) against (out2, in1) -- interleave in the
				-- cyclic order of the four incident ring edges.  The loop
				-- pairing, not the pass pairing, is the operationalization
				-- (measured on the 11.9 family-C dip shape, whose passes
				-- interleave while its loops occupy disjoint sectors); a
				-- coincident loop-end direction is a shared edge --
				-- overlap, not a crossing -- and a degenerate
				-- both-ends-one-direction loop cannot separate the other.
				local station = polygon[entry[1]]
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
				assert(not (a1 ~= a2 and b1 ~= b2 and
						(strictly_between(a1, b1, a2) and
							strictly_between(a2, b2, a1) or
						strictly_between(a1, b2, a2) and
							strictly_between(a2, b1, a1))),
					id .. " has a crossing repeat at " .. station_key)
				-- The touch form, recorded: zero width -- no cardinal
				-- 4-neighbour strictly interior by winding (straight
				-- corridor stations have both laterals strictly outside;
				-- the measured W-112 dawnmere L-turn mouth has boundary
				-- neighbours on both axes and still no interior beside it)
				-- -- is a filament appendix; strict interior beside the
				-- touch is a pinch.
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
			return appendix_count, pinch_count
		end
		local function merge_membership_runs(runs)
			if not runs or #runs == 0 then return {} end
			table.sort(runs, function(a, b)
				return a.first < b.first or a.first == b.first and a.finish < b.finish
			end)
			local result = {{first = runs[1].first, finish = runs[1].finish}}
			for index = 2, #runs do
				local run, previous = runs[index], result[#result]
				if run.first <= previous.finish + 1 then
					if run.finish > previous.finish then previous.finish = run.finish end
				else
					result[#result + 1] = {first = run.first, finish = run.finish}
				end
			end
			return result
		end
		local function containing_run(runs, x)
			if not runs then return nil end
			for index = 1, #runs do
				local run = runs[index]
				if x < run.first then return nil end
				if x <= run.finish then return run end
			end
			return nil
		end
	
		local footprint_components, footprint_rows = {}, {}
		for index = 1, #compiled.families.perimeters do
			footprint_components[#footprint_components + 1] = {
				kind = index <= 2 and "mainland" or "holy",
				rows = polygon_row_runs(payload_points(compiled.families.perimeters[index],
					"stations_xz"))}
		end
		for index = 1, #compiled.families.islands do
			footprint_components[#footprint_components + 1] = {kind = "island",
				rows = polygon_row_runs(payload_points(compiled.families.islands[index],
					"stations_xz"))}
		end
		for component_index = 1, #footprint_components do
			for z, runs in pairs(footprint_components[component_index].rows) do
				local row = footprint_rows[z]
				if not row then row = {} footprint_rows[z] = row end
				for index = 1, #runs do row[#row + 1] = runs[index] end
			end
		end
		for z, runs in pairs(footprint_rows) do
			footprint_rows[z] = merge_membership_runs(runs)
		end
		local function footprint_class(x, z)
			for index = 1, #footprint_components do
				local run = containing_run(footprint_components[index].rows[z], x)
				if run then return footprint_components[index].kind, run.class end
			end
			return nil, -1
		end
		local function source_bay_owner(authored, x, z)
			local best, best_n, best_d, tied
			for segment_index = 1, #authored.centreline - 1 do
				local a, b = authored.centreline[segment_index],
					authored.centreline[segment_index + 1]
				local n, d = exact.segment_distance(x, z, a, b)
				local span
				for span_index = 1, #authored.owner_spans do
					local candidate = authored.owner_spans[span_index]
					if segment_index >= candidate.first_segment and
							segment_index <= candidate.last_segment then
						span = candidate break
					end
				end
				assert(span)
				local dx, dz = exact.vector(a, b, "independent Bay owner segment")
				local px = exact.safe_difference(x, a.x, "independent Bay owner query")
				local pz = exact.safe_difference(z, a.z, "independent Bay owner query")
				local side = exact.cross(dx, dz, px, pz, "independent Bay owner side")
				local owner = side > 0 and span.left_zone_id or side < 0 and
					span.right_zone_id or zone_numeric[span.left_zone_id] <
					zone_numeric[span.right_zone_id] and span.left_zone_id or
					span.right_zone_id
				local candidate = {zone_id = owner, zone_numeric = zone_numeric[owner],
					segment_index = segment_index - 1, side = side}
				local order = best and exact.rational_compare(n, d, best_n, best_d) or -1
				if order < 0 then
					best, best_n, best_d, tied = candidate, n, d, false
				elseif order == 0 then
					tied = true
					if candidate.zone_numeric < best.zone_numeric then best = candidate end
				end
			end
			assert(best)
			return best.zone_id, best, best_n, best_d, tied
		end
		local prepared_payload_owner = {}
		for bay_index = 1, #source.bays do
			local authored = source.bays[bay_index]
			local payload = by_id(compiled.families.bays, authored.id)
			compiler.validate_bay_payload(payload)
			local centreline_values = signed_array(payload, "centreline_xz_width")
			local centreline = {}
			for offset = 1, #centreline_values, 3 do
				centreline[#centreline + 1] = {x = centreline_values[offset],
					z = centreline_values[offset + 1],
					half_width = centreline_values[offset + 2]}
			end
			local first = named_array_value(payload, "unsigned_arrays",
				"owner_span_first_segments")
			local finish = named_array_value(payload, "unsigned_arrays",
				"owner_span_last_segments")
			local left = named_array_value(payload, "text_arrays", "owner_left_zone_ids")
			local right = named_array_value(payload, "text_arrays", "owner_right_zone_ids")
			local left_numeric = named_array_value(payload, "unsigned_arrays",
				"owner_left_zone_numeric_ids")
			local right_numeric = named_array_value(payload, "unsigned_arrays",
				"owner_right_zone_numeric_ids")
			prepared_payload_owner[authored.id] = function(x, z)
				local best, best_n, best_d, best_numeric
				for segment_index = 1, #centreline - 1 do
					local a, b = centreline[segment_index], centreline[segment_index + 1]
					local n, d = exact.segment_distance(x, z, a, b)
					local span_index
					for index = 1, #first do
						if segment_index - 1 >= first[index] and
								segment_index - 1 <= finish[index] then
							span_index = index break
						end
					end
					assert(span_index)
					local side = (b.x - a.x) * (z - a.z) -
						(b.z - a.z) * (x - a.x)
					local owner, numeric
					if side > 0 then owner, numeric = left[span_index], left_numeric[span_index]
					elseif side < 0 then owner, numeric = right[span_index], right_numeric[span_index]
					elseif left_numeric[span_index] < right_numeric[span_index] then
						owner, numeric = left[span_index], left_numeric[span_index]
					else owner, numeric = right[span_index], right_numeric[span_index] end
					local order = best and exact.rational_compare(n, d, best_n, best_d) or -1
					if order < 0 or order == 0 and numeric < best_numeric then
						best, best_numeric, best_n, best_d = owner, numeric, n, d
					end
				end
				return assert(best)
			end
		end
	
		-- Dry-face regions through the two-tier acceptance: a ring with
		-- repeated stations must qualify as window-guarded appendixes
		-- (contracts 11.5-C) before the winding row derivation admits it.
		-- The join anchors the oracle can independently name: the ring
		-- terminal, the payload's shared-edge station endpoints (the cycle
		-- joins) and the payload's per-face Bank station endpoints (the
		-- arc-internal joins the measured family lives at).
		local face_edge_points = {}
		for index = 1, #compiled.families.land_boundaries do
			local row = compiled.families.land_boundaries[index]
			face_edge_points[row.id] = payload_points(row, "stations_xz")
		end
		local function face_join_keys(face, polygon)
			local join_keys = {[point_key(polygon[1].x, polygon[1].z)] = true}
			local authored = by_id(source.zone_faces, face.id)
			for _, component in ipairs(authored.cycle) do
				if component.kind == "shared_edge" then
					local points = assert(face_edge_points[component.ref_id])
					join_keys[point_key(points[1].x, points[1].z)] = true
					join_keys[point_key(points[#points].x, points[#points].z)] = true
				end
			end
			local offsets = named_array_value(face, "unsigned_arrays",
				"bank_station_offsets")
			local counts = named_array_value(face, "unsigned_arrays",
				"bank_station_counts")
			local stations = signed_array(face, "bank_stations_xz")
			for bank_index = 1, #offsets do
				local first = offsets[bank_index] * 2
				local last = first + (counts[bank_index] - 1) * 2
				join_keys[point_key(stations[first + 1], stations[first + 2])] = true
				join_keys[point_key(stations[last + 1], stations[last + 2])] = true
			end
			return join_keys
		end
		local face_rows = {}
		for index = 1, #compiled.families.dry_faces do
			local face = compiled.families.dry_faces[index]
			local polygon = payload_points(face, "polygon_xz")
			local distinct = {}
			local repeated = false
			for point_index = 1, #polygon - 1 do
				local station_key = point_key(polygon[point_index].x,
					polygon[point_index].z)
				if distinct[station_key] then repeated = true break end
				distinct[station_key] = true
			end
			local appendix, pinch = 0, 0
			if repeated then
				appendix, pinch = face_appendix_acceptance(face.id, polygon,
					face_join_keys(face, polygon))
			end
			local rows = polygon_row_runs(polygon, appendix + pinch > 0)
			for z, runs in pairs(rows) do
				for run_index = 1, #runs do
					local run = runs[run_index]
					append_run(face_rows, z, {first = run.first, finish = run.finish,
						class = run.class, numeric = face.numeric_id,
						zone_id = named_scalar(face, "text_values", "zone_id"), id = face.id})
				end
			end
		end
	
		-- For a fixed integer row, squared distance to a centreline station is a
		-- line after removing the common x^2 term.  This exact lower envelope gives
		-- the same nearest-station/lower-index tie as the slow squared-distance
		-- oracle without multiplying the whole-footprint cost by station count.
		local function ceil_division(numerator, denominator)
			assert(denominator > 0)
			return -math.floor(-numerator / denominator)
		end
		local function nearest_schedule(stations, z)
			local lines = {}
			for index = 1, #stations do
				local point = stations[index]
				local dz = z - point.z
				lines[#lines + 1] = {m = -2 * point.x,
					b = point.x * point.x + dz * dz, index = index}
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
				local line = unique[index]
				local start = -2147483648
				while #hull > 0 do
					local previous = hull[#hull]
					local numerator = line.b - previous.b
					local denominator = previous.m - line.m
					assert(denominator > 0)
					if line.index < previous.index then
						start = ceil_division(numerator, denominator)
					else
						start = math.floor(numerator / denominator) + 1
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
		local function schedule_owner(schedule, x, cursor)
			while cursor < #schedule and schedule[cursor + 1].start <= x do
				cursor = cursor + 1
			end
			return schedule[cursor].index, cursor
		end
		local function slow_nearest_station(stations, x, z)
			local selected, distance
			for station_index = 1, #stations do
				local point = stations[station_index]
				local dx, dz = x - point.x, z - point.z
				local candidate = dx * dx + dz * dz
				if not distance or candidate < distance then
					selected, distance = station_index, candidate
				end
			end
			return selected
		end
		local schedule_certified_intervals = 0
		local function certify_schedule(stations, z, schedule, min_x, max_x)
			for index = 1, #schedule do
				local first = math.max(min_x, schedule[index].start)
				local finish = math.min(max_x, index < #schedule and
					schedule[index + 1].start - 1 or max_x)
				if first <= finish then
					assert(schedule[index].index == slow_nearest_station(stations, first, z) and
						schedule[index].index == slow_nearest_station(stations, finish, z),
						"Bay row-envelope interval certification changed")
					schedule_certified_intervals = schedule_certified_intervals + 1
				end
			end
		end
		-- Bind the acceleration to the reviewed divergent witness.  The exhaustive
		-- row scan below additionally certifies both integer endpoints of every
		-- clipped lower-envelope interval against the slow squared-distance oracle.
		for oracle_index = 1, #bay_oracles do
			local oracle = bay_oracles[oracle_index]
			for segment_index = 1, #oracle.segments do
				local segment = oracle.segments[segment_index]
				for _, query in ipairs({oracle.source.centreline[segment_index],
					oracle.source.centreline[segment_index + 1], {x = -1376, z = -2846}}) do
					local schedule = nearest_schedule(segment.stations, query.z)
					local fast = schedule_owner(schedule, query.x, 1)
					local slow = slow_nearest_station(segment.stations, query.x, query.z)
					assert(fast == slow, "Bay row-envelope nearest station changed")
				end
			end
		end
	
		local water_rows, expected_water_rows = {}, {}
		local base_counts, base_total = {}, 0
		local function append_feature_point(rows, z, x, feature, state)
			local row = rows[z]
			if not row then row = {} rows[z] = row end
			local previous = row[#row]
			if previous and previous.finish + 1 == x and previous.kind == feature.kind and
					previous.id == feature.id and previous.owner == feature.owner then
				previous.finish = x
			else
				row[#row + 1] = {first = x, finish = x, kind = feature.kind,
					id = feature.id, owner = feature.owner}
			end
			state.count = state.count + 1
		end
		local water_state = {count = 0}
		for oracle_index = 1, #bay_oracles do
			local oracle = bay_oracles[oracle_index]
			local payload_owner = assert(prepared_payload_owner[oracle.source.id])
			local boxes, min_x, max_x, min_z, max_z = {}, nil, nil, nil, nil
			for segment_index = 1, #oracle.segments do
				local a, b = oracle.source.centreline[segment_index],
					oracle.source.centreline[segment_index + 1]
				local radius = math.max(a.half_width, b.half_width) +
					oracle.source.max_displacement + 1
				local box = {min_x = math.min(a.x, b.x) - radius,
					max_x = math.max(a.x, b.x) + radius,
					min_z = math.min(a.z, b.z) - radius,
					max_z = math.max(a.z, b.z) + radius}
				boxes[segment_index] = box
				min_x = min_x and math.min(min_x, box.min_x) or box.min_x
				max_x = max_x and math.max(max_x, box.max_x) or box.max_x
				min_z = min_z and math.min(min_z, box.min_z) or box.min_z
				max_z = max_z and math.max(max_z, box.max_z) or box.max_z
			end
			for z = min_z, max_z do
				local schedules, cursors = {}, {}
				for segment_index = 1, #oracle.segments do
					schedules[segment_index] = nearest_schedule(
						oracle.segments[segment_index].stations, z)
					cursors[segment_index] = 1
					local box = boxes[segment_index]
					if z >= box.min_z and z <= box.max_z then
						certify_schedule(oracle.segments[segment_index].stations, z,
							schedules[segment_index], box.min_x, box.max_x)
					end
				end
				for x = min_x, max_x do
					local member = false
					for segment_index = 1, #oracle.segments do
						local station_index
						station_index, cursors[segment_index] = schedule_owner(
							schedules[segment_index], x, cursors[segment_index])
						local box = boxes[segment_index]
						if x >= box.min_x and x <= box.max_x and z >= box.min_z and
								z <= box.max_z and exact.bay_segment(x, z,
								oracle.source.centreline[segment_index],
								oracle.source.centreline[segment_index + 1],
								oracle.segments[segment_index].deltas[station_index]) then
							member = true
							break
						end
					end
					if member then
						local footprint_kind, class = footprint_class(x, z)
						if footprint_kind == "mainland" and (class > 0 or
								oracle.aperture[point_key(x, z)]) then
							local expected_owner = source_bay_owner(oracle.source, x, z)
							local actual_owner = payload_owner(x, z)
							assert(actual_owner == expected_owner,
								"exhaustive Base owner projection changed")
							append_feature_point(water_rows, z, x, {kind = "base",
								id = oracle.source.id, owner = actual_owner}, water_state)
							append_feature_point(expected_water_rows, z, x, {kind = "base",
								id = oracle.source.id, owner = expected_owner}, water_state)
							base_counts[oracle.source.id] =
								(base_counts[oracle.source.id] or 0) + 1
							base_total = base_total + 1
						end
					end
				end
			end
		end
		assert(base_total > 0 and base_counts.bay_elandor_west > 0 and
			base_counts.bay_elandor_east > 0 and base_counts.bay_kragmar_west > 0 and
			base_counts.bay_kragmar_east > 0, "final-delta Base scan is empty")
		for wing_index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[wing_index]
			local radius = wing.head_half_width + 1
			for z = math.min(wing.head.z, wing.junction.z) - radius,
					math.max(wing.head.z, wing.junction.z) + radius do
				for x = math.min(wing.head.x, wing.junction.x) - radius,
						math.max(wing.head.x, wing.junction.x) + radius do
					local footprint_kind, class = footprint_class(x, z)
					if footprint_kind == "mainland" and class > 0 and
							exact.wing_member(x, z, wing) then
						local determinant = (wing.junction.x - wing.head.x) *
							(z - wing.head.z) - (wing.junction.z - wing.head.z) *
							(x - wing.head.x)
						local owner = determinant > 0 and wing.left_zone_id or
							determinant < 0 and wing.right_zone_id or wing.tie_zone_id
						append_feature_point(water_rows, z, x, {kind = "wing", id = wing.id,
							owner = owner}, water_state)
						append_feature_point(expected_water_rows, z, x, {kind = "wing",
							id = wing.id, owner = owner}, water_state)
					end
				end
			end
		end
	
		local declared = {}
		local function declare(x, z, owner)
			local key = point_key(x, z)
			local owners = declared[key]
			if not owners then owners = {} declared[key] = owners end
			owners[owner] = true
		end
		for edge_index = 1, #compiled.families.land_boundaries do
			local edge = compiled.families.land_boundaries[edge_index]
			local zone_a = named_scalar(edge, "text_values", "zone_a")
			local zone_b = named_scalar(edge, "text_values", "zone_b")
			local values = signed_array(edge, "stations_xz")
			for coordinate = 1, #values, 2 do
				declare(values[coordinate], values[coordinate + 1], zone_a)
				declare(values[coordinate], values[coordinate + 1], zone_b)
			end
		end
		for _, vertex in pairs((function()
			local vertices = {}
			for span_index = 1, #source.perimeter_spans do
				local span = source.perimeter_spans[span_index]
				for _, boundary in ipairs({span.start_boundary, span.end_boundary}) do
					if boundary.kind == "perimeter_vertex" then
						local key = boundary.perimeter_id .. ":" .. boundary.index
						local row = vertices[key] or {perimeter_id = boundary.perimeter_id,
							index = boundary.index, owners = {}}
						vertices[key] = row row.owners[span.zone_id] = true
					end
				end
			end
			return vertices
		end)()) do
			local perimeter = assert(independent_perimeter_by_id[vertex.perimeter_id])
			local point = assert(assert(perimeter.segment_parts[vertex.index])[1])
			for owner in pairs(vertex.owners) do declare(point.x, point.z, owner) end
		end
	
		local function active_runs(rows, z, x)
			local active = {}
			for index = 1, #(rows[z] or {}) do
				local run = rows[z][index]
				if x >= run.first and x <= run.finish then active[#active + 1] = run end
			end
			return active
		end
		local function evaluate(current_faces, current_water, expected_water)
			expected_water = expected_water or expected_water_rows
			local result = {columns = 0, planned_water = 0, dry = 0,
				g = 0, o = 0, r = 0, m = 0, gap_witnesses = {}}
			for z, footprint_runs in pairs(footprint_rows) do
				local faces, water = current_faces[z] or {}, current_water[z] or {}
				local expected = expected_water[z] or {}
				for footprint_index = 1, #footprint_runs do
					local footprint_run = footprint_runs[footprint_index]
					local breaks = {footprint_run.first, footprint_run.finish + 1}
					for _, collection in ipairs({faces, water, expected}) do
						for index = 1, #collection do
							local run = collection[index]
							if run.finish >= footprint_run.first and
									run.first <= footprint_run.finish then
								breaks[#breaks + 1] = math.max(run.first, footprint_run.first)
								breaks[#breaks + 1] = math.min(run.finish,
									footprint_run.finish) + 1
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
						local active_faces = active_runs(current_faces, z, first)
						local active_water = active_runs(current_water, z, first)
						local expected_active = active_runs(expected_water, z, first)
						local base_count, wing_count = 0, 0
						for water_index = 1, #active_water do
							if active_water[water_index].kind == "base" then
								base_count = base_count + 1
							else wing_count = wing_count + 1 end
						end
						local function selected_feature(active)
							local selected
							for active_index = 1, #active do
								if active[active_index].kind == "base" and
									(not selected or selected.kind ~= "base") then
									selected = active[active_index]
								elseif not selected then selected = active[active_index] end
							end
							return selected
						end
						local selected, expected_selected = selected_feature(active_water),
							selected_feature(expected_active)
						if (selected == nil) ~= (expected_selected == nil) or selected and
								(selected.kind ~= expected_selected.kind or
								selected.id ~= expected_selected.id or
								selected.owner ~= expected_selected.owner) then
							result.m = result.m + length
						end
						result.columns = result.columns + length
						if base_count > 0 or wing_count > 0 then
							result.planned_water = result.planned_water + length
							if base_count > 1 or base_count == 0 and wing_count > 1 then
								result.o = result.o + length
							end
						else
							result.dry = result.dry + length
							if #active_faces == 0 then
								result.g = result.g + length
								if #result.gap_witnesses < 16 then
									result.gap_witnesses[#result.gap_witnesses + 1] = {
										x = first, z = z, length = length}
								end
							elseif #active_faces > 1 then
								-- The direct declared-seam check, then the
								-- 11.9 family-C seam inheritance (the
								-- oracle's independent copy of the
								-- classifier's rule): a column claimed by
								-- exactly two faces, both as boundary
								-- (class 0), cardinally adjacent to a
								-- declared-seam column of the identical
								-- zone pair, inherits that declaration;
								-- everything else counts r.
								local function inherits_seam(x)
									if #active_faces ~= 2 then return false end
									if active_faces[1].class ~= 0 or
											active_faces[2].class ~= 0 then
										return false
									end
									local zone_a = active_faces[1].zone_id
									local zone_b = active_faces[2].zone_id
									if zone_a == zone_b then return false end
									local neighbours = {{x - 1, z}, {x + 1, z},
										{x, z - 1}, {x, z + 1}}
									for index = 1, 4 do
										local owners = declared[point_key(
											neighbours[index][1],
											neighbours[index][2])]
										if owners and owners[zone_a] and
												owners[zone_b] then
											local exact_pair = true
											for owner in pairs(owners) do
												if owner ~= zone_a and
														owner ~= zone_b then
													exact_pair = false
													break
												end
											end
											if exact_pair then return true end
										end
									end
									return false
								end
								for x = first, finish do
									local owners = declared[point_key(x, z)]
									local valid = owners ~= nil
									local seen = {}
									for face_index = 1, #active_faces do
										local owner = active_faces[face_index].zone_id
										if seen[owner] or not owners or not owners[owner] then
											valid = false
										end
										seen[owner] = true
									end
									if valid then
										for owner in pairs(owners) do
											if not seen[owner] then valid = false break end
										end
									end
									if not valid and inherits_seam(x) then
										valid = true
									end
									if not valid then result.r = result.r + 1 end
								end
							end
						end
					end
				end
			end
			return result
		end
		-- H15 authority diagnostic only: enumerate the raw, single-cell Bay-mask
		-- notches without feeding the result back into Production.  The candidate
		-- set is complete because every 3-of-4 cardinal pattern has a horizontal
		-- Bay-water neighbor, hence appears beside a row-run endpoint.
		local wing_bay_by_id = {}
		for wing_index = 1, #source.bay_closure_wings do
			local wing = source.bay_closure_wings[wing_index]
			wing_bay_by_id[wing.id] = wing.bay_id
		end
		local function run_bay_id(run)
			return run.kind == "base" and run.id or wing_bay_by_id[run.id]
		end
		local function point_bay_water(bay_id, x, z)
			local active = active_runs(water_rows, z, x)
			for index = 1, #active do
				if run_bay_id(active[index]) == bay_id then return true end
			end
			return false
		end
		local notch_by_bay, notch_list, notch_owner_by_key = {}, {}, {}
		for bay_index = 1, #source.bays do
			local bay_id = source.bays[bay_index].id
			local candidates = {}
			for z, runs in pairs(water_rows) do
				for run_index = 1, #runs do
					local run = runs[run_index]
					if run_bay_id(run) == bay_id then
						candidates[point_key(run.first - 1, z)] = {x = run.first - 1, z = z}
						candidates[point_key(run.finish + 1, z)] = {x = run.finish + 1, z = z}
					end
				end
			end
			local selected, selected_map = {}, {}
			for _, point in pairs(candidates) do
				local footprint_kind, class = footprint_class(point.x, point.z)
				if footprint_kind == "mainland" and class == 1 and
						#active_runs(water_rows, point.z, point.x) == 0 then
					local water_count, dry_neighbor = 0, nil
					for direction_index = 1, #oracle_cardinal do
						local direction = oracle_cardinal[direction_index]
						local nx, nz = point.x + direction.x, point.z + direction.z
						if point_bay_water(bay_id, nx, nz) then
							water_count = water_count + 1
						else
							dry_neighbor = {x = nx, z = nz}
						end
					end
					local dry_kind, dry_class = dry_neighbor and
						footprint_class(dry_neighbor.x, dry_neighbor.z) or nil, nil
					if dry_neighbor then
						_, dry_class = footprint_class(dry_neighbor.x, dry_neighbor.z)
					end
					local diagonals_water = true
					for _, direction in ipairs({{x = 1, z = 1}, {x = 1, z = -1},
							{x = -1, z = 1}, {x = -1, z = -1}}) do
						if not point_bay_water(bay_id, point.x + direction.x,
								point.z + direction.z) then diagonals_water = false break end
					end
					if water_count == 3 and dry_kind == "mainland" and dry_class == 1 and
							#active_runs(water_rows, dry_neighbor.z, dry_neighbor.x) == 0 and
							diagonals_water then
						local water_neighbors = {}
						for direction_index = 1, #oracle_cardinal do
							local direction = oracle_cardinal[direction_index]
							local nx, nz = point.x + direction.x, point.z + direction.z
							if point_bay_water(bay_id, nx, nz) then
								water_neighbors[#water_neighbors + 1] = {x = nx, z = nz}
							end
						end
						for _, direction in ipairs({{x = 1, z = 1}, {x = 1, z = -1},
								{x = -1, z = 1}, {x = -1, z = -1}}) do
							water_neighbors[#water_neighbors + 1] = {
								x = point.x + direction.x, z = point.z + direction.z}
						end
						assert(#water_neighbors == 7)
						for neighbor_index = 1, #water_neighbors do
							local neighbor = water_neighbors[neighbor_index]
							local active = active_runs(water_rows, neighbor.z, neighbor.x)
							assert(#active == 1 and run_bay_id(active[1]) == bay_id,
								"H15 notch water neighbor is not uniquely owned by its Bay")
						end
						local row = {x = point.x, z = point.z, bay_id = bay_id,
							dry_neighbor = dry_neighbor}
						local key = point_key(point.x, point.z)
						assert(not notch_owner_by_key[key],
							"H15 notch was selected by more than one Bay")
						notch_owner_by_key[key] = bay_id
						selected[#selected + 1], notch_list[#notch_list + 1] = row, row
						selected_map[key] = true
					end
				end
			end
			table.sort(selected, function(a, b)
				return a.x < b.x or a.x == b.x and a.z < b.z
			end)
			notch_by_bay[bay_id] = selected_map
			local evidence = {}
			for index = 1, #selected do
				evidence[#evidence + 1] = selected[index].x .. ":" .. selected[index].z ..
					">" .. selected[index].dry_neighbor.x .. ":" ..
					selected[index].dry_neighbor.z
			end
			local bay_payload = by_id(compiled.families.bays, bay_id)
			local function validate_fill_projection(payload)
				compiler.validate_bay_payload(payload)
				assert(payload.record_schema == "grug_wp40_bay_v2",
					"R17 Bay notch projection schema changed")
				assert(named_scalar(payload, "text_values", "notch_fill_policy_id") ==
					source.geometry_policies.world_partition.bay_notch_fill_policy_id)
				local count = named_scalar(payload, "unsigned_values", "notch_fill_count")
				local values = signed_array(payload, "notch_fill_xz")
				if count ~= #selected or #values ~= #selected * 2 then
					error("R17 Bay notch projection count changed")
				end
				for index = 1, #selected do
					if values[index * 2 - 1] ~= selected[index].x or
							values[index * 2] ~= selected[index].z then
						error("R17 Bay notch projection bytes changed")
					end
				end
				return true
			end
			assert(validate_fill_projection(bay_payload))
			local expected_fill_count = #selected
			if focused_seed0 then
				expected_fill_count = 0
			elseif focused_max_u64 and (bay_id == "bay_elandor_west" or
					bay_id == "bay_elandor_east" or bay_id == "bay_kragmar_west") then
				expected_fill_count = 1
			elseif focused_max_u64 then
				expected_fill_count = 0
			end
			assert(#selected == expected_fill_count,
				"R17 per-Bay notch projection count changed")
			if not focused_seed0 and #selected > 0 then
				local original_policy = source.geometry_policies.world_partition.
					bay_notch_fill_policy_id
				local original_x, original_z = selected[1].x, selected[1].z
				local corrupted = deep_copy(bay_payload)
				for row_index = 1, #corrupted.unsigned_values do
					if corrupted.unsigned_values[row_index].name == "notch_fill_count" then
						corrupted.unsigned_values[row_index].value =
							corrupted.unsigned_values[row_index].value + 1
					end
				end
				expect_error("notch fill count", function()
					compiler.validate_bay_payload(corrupted)
				end)
				corrupted = deep_copy(bay_payload)
				local values = named_array_value(corrupted, "signed_arrays", "notch_fill_xz")
				values[1] = values[1] + 1
				expect_error("projection bytes", function() validate_fill_projection(corrupted) end)
				corrupted = deep_copy(bay_payload)
				for row_index = 1, #corrupted.text_values do
					if corrupted.text_values[row_index].name == "notch_fill_policy_id" then
						corrupted.text_values[row_index].value = "corrupt"
					end
				end
				expect_error("owner policy", function()
					compiler.validate_bay_payload(corrupted)
				end)
				corrupted = deep_copy(bay_payload)
				local reversed = named_array_value(corrupted, "signed_arrays",
					"notch_fill_xz")
				reversed[3], reversed[4] = reversed[1] - 1, reversed[2]
				for row_index = 1, #corrupted.unsigned_values do
					if corrupted.unsigned_values[row_index].name == "notch_fill_count" then
						corrupted.unsigned_values[row_index].value = 2
					end
				end
				expect_error("not canonical", function()
					compiler.validate_bay_payload(corrupted)
				end)
				assert(source.geometry_policies.world_partition.bay_notch_fill_policy_id ==
					original_policy and selected[1].x == original_x and
					selected[1].z == original_z and
					signed_array(bay_payload, "notch_fill_xz")[1] == original_x,
					"R17 Bay notch projection aliases Source or a copied payload")
			end
			print("WP40 T2 H15 raw notches seed=" .. seed .. " " .. bay_id .. "=" ..
				#selected .. (#evidence > 0 and " [" .. table.concat(evidence, ",") .. "]" or ""))
		end
		local raw_report = evaluate(face_rows, water_rows, expected_water_rows)
		local report
		do
			local simulated_water = deep_copy(water_rows)
			for index = 1, #notch_list do
				local notch = notch_list[index]
				append_run(simulated_water, notch.z, {first = notch.x, finish = notch.x,
					kind = "base", id = notch.bay_id,
					owner = source_bay_owner(assert((function()
						for bay_index = 1, #source.bays do
							if source.bays[bay_index].id == notch.bay_id then
								return source.bays[bay_index]
							end
						end
					end)()), notch.x, notch.z)})
			end
			local simulated = evaluate(face_rows, simulated_water, simulated_water)
			local any_notch = {}
			for index = 1, #notch_list do
				any_notch[point_key(notch_list[index].x, notch_list[index].z)] = true
			end
			local patched_world = {bay_oracles = oracle_world.bay_oracles,
				bay_oracle_by_id = oracle_world.bay_oracle_by_id,
				footprint_class = oracle_world.footprint_class}
			patched_world.planned_water = function(x, z, equality)
				if not equality and any_notch[point_key(x, z)] then return true end
				return oracle_world.planned_water(x, z, equality)
			end
			patched_world.bay_water = function(oracle, x, z)
				if assert(notch_by_bay[oracle.source.id])[point_key(x, z)] then return true end
				return oracle_world.bay_water(oracle, x, z)
			end
			patched_world.candidate = function(oracle, x, z)
				local in_bounds = false
				for box_index = 1, #oracle.boxes do
					local box = oracle.boxes[box_index]
					if x >= box.min_x and x <= box.max_x and z >= box.min_z and
							z <= box.max_z then in_bounds = true break end
				end
				if not in_bounds then return false end
				local own_water = false
				for direction_index = 1, #oracle_cardinal do
					local direction = oracle_cardinal[direction_index]
					if patched_world.bay_water(oracle, x + direction.x, z + direction.z) then
						own_water = true break
					end
				end
				local class = patched_world.footprint_class(x, z)
				if not own_water or class < 0 or patched_world.planned_water(x, z,
						class == 0) then return false end
				for direction_index = 1, #oracle_cardinal do
					local direction = oracle_cardinal[direction_index]
					local nx, nz = x + direction.x, z + direction.z
					local neighbor_class = patched_world.footprint_class(nx, nz)
					if neighbor_class >= 0 and patched_world.planned_water(nx, nz,
							neighbor_class == 0) and not patched_world.bay_water(oracle,
							nx, nz) then return false end
				end
				return true
			end
			patched_world.water_right = function(oracle, from, to)
				local dx, dz = to.x - from.x, to.z - from.z
				for direction_index = 1, #oracle_cardinal do
					local direction = oracle_cardinal[direction_index]
					if patched_world.bay_water(oracle, from.x + direction.x,
							from.z + direction.z) and exact.cross(dx, dz, direction.x,
							direction.z, "H15 simulated water side") < 0 then return true end
				end
				return false
			end
			local bundle = assert(profile.bundle, "partition oracle bundle is missing")
			local wings, edges, apertures, envelopes, current_banks =
				assert(bundle.wings), assert(bundle.edges), assert(bundle.apertures),
				assert(bundle.envelopes), assert(bundle.banks)
			local trace_ok, simulated_banks = pcall(trace_independent_banks_again,
				patched_world, wings, edges, apertures, envelopes, {}, false)
			assert(trace_ok, "R17 final-mask independent Bank trace failed: " ..
				tostring(simulated_banks))
			local bank_drift = 0
			for bank_index = 1, #source.bay_bank_components do
				local id = source.bay_bank_components[bank_index].id
				if not same_point_bytes(assert(current_banks[id]),
						assert(simulated_banks[id])) then bank_drift = bank_drift + 1 end
			end
			assert(bank_drift == 0, "R17 final-mask Bank bytes changed")
			if focused_seed0 then
				assert(#notch_list == 0 and raw_report.g == 0,
					"Seed0 raw Bay-notch baseline changed")
			elseif focused_max_u64 then
				local expected = {["-775:-2349"] = "bay_elandor_west",
					["887:-2036"] = "bay_elandor_east",
					["-1121:2220"] = "bay_kragmar_west"}
				assert(#notch_list == 3 and raw_report.g == 3,
					"max-u64 raw Bay-notch baseline changed")
				for index = 1, #notch_list do
					local notch = notch_list[index]
					local point_key = notch.x .. ":" .. notch.z
					assert(expected[point_key] == notch.bay_id,
						"max-u64 raw Bay-notch identity changed")
					local authored
					for bay_index = 1, #source.bays do
						if source.bays[bay_index].id == notch.bay_id then
							authored = source.bays[bay_index] break
						end
					end
					assert(authored)
					local expected_id, expected_owner, expected_n, expected_d, expected_tied =
						source_bay_owner(authored, notch.x, notch.z)
					local actual_owner, actual_n, actual_d, actual_tied = compiler.bay_owner(
						by_id(compiled.families.bays, notch.bay_id), notch.x, notch.z)
					assert(actual_owner.zone_id == expected_id and
						actual_owner.zone_numeric == expected_owner.zone_numeric and
						actual_owner.segment_index == expected_owner.segment_index and
						actual_owner.side == expected_owner.side and
						exact.rational_compare(actual_n, actual_d, expected_n, expected_d) == 0 and
						actual_tied == expected_tied,
						"R17 filled Bay owner projection changed")
					expected[point_key] = nil
				end
				assert(next(expected) == nil, "max-u64 raw Bay-notch roster is incomplete")
			else
				assert(simulated.g == 0 and simulated.o == 0 and simulated.r == 0 and
					simulated.m == 0, "selected final-mask partition changed")
			end
			report = simulated
			water_rows = simulated_water
			expected_water_rows = deep_copy(simulated_water)
			print(("WP40 T2 H15 simulated seed=%s cells=%d g/o/r/m=%d/%d/%d/%d " ..
				"Bank_drift=%d trace=%s"):format(seed, #notch_list, simulated.g,
				simulated.o, simulated.r, simulated.m, bank_drift,
				"ok"))
		end
		if focused_seed0 then
			assert(report.columns == 30312952, "closed footprint column count changed: " ..
				report.columns)
		else
			assert(report.columns > 0, "closed footprint scan is empty")
		end
		local gap_text = {}
		for index = 1, #report.gap_witnesses do
			local witness = report.gap_witnesses[index]
			gap_text[#gap_text + 1] = witness.x .. ":" .. witness.z .. "+" .. witness.length
			local footprint_kind, footprint_boundary = footprint_class(witness.x, witness.z)
			local water = active_runs(water_rows, witness.z, witness.x)
			local nonnegative, nearest_id, nearest_distance = {}, nil, nil
			for face_index = 1, #compiled.families.dry_faces do
				local face = compiled.families.dry_faces[face_index]
				local points = payload_points(face, "polygon_xz")
				local class = exact.polygon_class(witness.x, witness.z, points)
				if class >= 0 then
					nonnegative[#nonnegative + 1] = face.id .. "=" .. class
				end
				for point_index = 1, #points - 1 do
					local point = points[point_index]
					local distance = math.max(math.abs(point.x - witness.x),
						math.abs(point.z - witness.z))
					if not nearest_distance or distance < nearest_distance or
							distance == nearest_distance and face.id < nearest_id then
						nearest_id, nearest_distance = face.id, distance
					end
				end
			end
			local neighbors = {}
			for dz = -1, 1 do
				for dx = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local active = active_runs(face_rows, witness.z + dz, witness.x + dx)
						local ids = {}
						for active_index = 1, #active do ids[#ids + 1] = active[active_index].id end
						local active_water = active_runs(water_rows, witness.z + dz,
							witness.x + dx)
						local water_ids = {}
						for active_index = 1, #active_water do
							water_ids[#water_ids + 1] = active_water[active_index].id
						end
						neighbors[#neighbors + 1] = dx .. ":" .. dz .. "=" ..
							(#ids > 0 and table.concat(ids, "+") or "none") .. "/" ..
							(#water_ids > 0 and table.concat(water_ids, "+") or "dry")
					end
				end
			end
			local nearest_transition, nearest_transition_distance
			local nearest_bank, nearest_bank_distance
			if not focused_seed0 then
				for id, transition in pairs(assert(profile.bundle.transition_expectations)) do
					for _, point in ipairs({transition.e, transition.point, transition.w}) do
						if point then
							local distance = math.max(math.abs(point.x - witness.x),
								math.abs(point.z - witness.z))
							if not nearest_transition_distance or distance < nearest_transition_distance then
								nearest_transition = id .. "/" .. transition.mode .. "@" ..
									point.x .. ":" .. point.z
								nearest_transition_distance = distance
							end
						end
					end
				end
				for id, points in pairs(assert(profile.bundle.banks)) do
					for point_index = 1, #points do
						local point = points[point_index]
						local distance = math.max(math.abs(point.x - witness.x),
							math.abs(point.z - witness.z))
						if not nearest_bank_distance or distance < nearest_bank_distance then
							nearest_bank = id .. "[" .. point_index .. "]@" ..
								point.x .. ":" .. point.z
							nearest_bank_distance = distance
						end
					end
				end
			end
			print(("WP40 T2 R16 gap %d:%d footprint=%s/%d water=%d " ..
				"faces_nonnegative=%s nearest=%s@%d transition=%s@%s bank=%s@%s " ..
				"neighbors=%s"):format(
				witness.x, witness.z, tostring(footprint_kind), footprint_boundary,
				#water, #nonnegative > 0 and table.concat(nonnegative, "+") or "none",
				nearest_id, nearest_distance, tostring(nearest_transition),
				tostring(nearest_transition_distance), tostring(nearest_bank),
				tostring(nearest_bank_distance), table.concat(neighbors, ",")))
		end
		assert(report.g == 0 and report.o == 0 and report.r == 0 and report.m == 0,
			("whole footprint changed g=%d/o=%d/r=%d/m=%d gap_runs=%s"):format(report.g,
				report.o, report.r, report.m, #gap_text > 0 and
				table.concat(gap_text, ",") or "none"))
		assert(report.planned_water > 0 and report.dry > 0 and
			report.planned_water + report.dry == report.columns)
		report.base_total = base_total
		report.schedule_intervals = schedule_certified_intervals
		if profile.mode == "selected" then
			-- Selected winners retain the complete equality partition proof.  Its
			-- Attachment coordinates are independently re-derived for this seed and
			-- carried in the private oracle bundle; no Seed0 coordinate is reused.
			local attachments = assert(profile.bundle.attachments,
				"selected Attachment oracle is missing")
			local aperture_owner, attachment_owner, span_owner = {}, {}, {}
			for index = 1, #compiled.families.mouth_apertures do
				local aperture = compiled.families.mouth_apertures[index]
				local perimeter = by_id(compiled.families.perimeters,
					named_scalar(aperture, "text_values", "perimeter_id"))
				local values = signed_array(perimeter, "stations_xz")
				local first = named_scalar(aperture, "unsigned_values", "first")
				local finish = named_scalar(aperture, "unsigned_values", "finish")
				local bay_id = named_scalar(aperture, "text_values", "bay_id")
				for station = first, finish - 1 do
					local coordinate = station * 2 + 1
					local key = point_key(values[coordinate], values[coordinate + 1])
					assert(not aperture_owner[key], "selected mouth apertures overlap")
					aperture_owner[key] = bay_id
				end
			end
			for index = 1, #source.perimeter_attachments do
				local attachment = source.perimeter_attachments[index]
				local expected = assert(attachments[attachment.id])
				local edge = assert(source_by_id(source.land_edges, attachment.edge_id))
				attachment_owner[point_key(expected.a.x, expected.a.z)] = edge.tie_zone_id
			end
			local function add_span_owner(point, owner)
				local key = point_key(point.x, point.z)
				if not span_owner[key] or zone_numeric[owner] < zone_numeric[span_owner[key]] then
					span_owner[key] = owner
				end
			end
			for index = 1, #source.perimeter_spans do
				local span = source.perimeter_spans[index]
				local perimeter = assert(independent_perimeter_by_id[span.perimeter_id])
				local function boundary_point(boundary)
					if boundary.kind == "perimeter_attachment" then
						return assert(attachments[boundary.attachment_id]).a
					end
					assert(boundary.kind == "perimeter_vertex" and
						boundary.perimeter_id == span.perimeter_id)
					return assert(source_by_id(source.perimeters,
						boundary.perimeter_id).polygon[boundary.index])
				end
				local first, last = boundary_point(span.start_boundary),
					boundary_point(span.end_boundary)
				local collecting, found = false, false
				for station_index = 1, #perimeter.stations do
					local point = perimeter.stations[station_index]
					if point.x == first.x and point.z == first.z then collecting = true end
					if collecting then add_span_owner(point, span.zone_id) end
					if collecting and point.x == last.x and point.z == last.z then
						found = true break
					end
				end
				assert(found, span.id .. " selected equality span is absent")
			end
			local function selected_at(x, z)
				local water = active_runs(water_rows, z, x)
				local selected_water
				for index = 1, #water do
					if water[index].kind == "base" and
							(not selected_water or selected_water.kind ~= "base") then
						selected_water = water[index]
					elseif not selected_water then selected_water = water[index] end
				end
				if selected_water then return "planned_water", selected_water.owner end
				local faces = active_runs(face_rows, z, x)
				local selected
				for index = 1, #faces do
					if not selected or faces[index].numeric < selected.numeric then
						selected = faces[index]
					end
				end
				if selected then return "land", selected.zone_id end
				return "missing", nil
			end
			local mismatch, aperture_count, attachment_count, dry_count = 0, 0, 0, 0
			for perimeter_index = 1, 2 do
				local perimeter = compiled.families.perimeters[perimeter_index]
				local values = signed_array(perimeter, "stations_xz")
				local count = named_scalar(perimeter, "unsigned_values", "station_count")
				for station = 0, count - 1 do
					local coordinate = station * 2 + 1
					local x, z = values[coordinate], values[coordinate + 1]
					local key = point_key(x, z)
					local actual_kind, actual_owner = selected_at(x, z)
					local bay_id = aperture_owner[key]
					local expected_kind, expected_owner
					if bay_id then
						expected_kind = "planned_water"
						expected_owner = source_bay_owner(assert(bay_source_by_id[bay_id]), x, z)
						aperture_count = aperture_count + 1
					else
						expected_kind = "land"
						expected_owner = attachment_owner[key] or span_owner[key]
						if attachment_owner[key] then attachment_count = attachment_count + 1 end
						if not expected_owner then
							local owners = assert(declared[key],
								"selected final perimeter differs from fixed edge union")
							for owner in pairs(owners) do
								if not expected_owner or zone_numeric[owner] <
										zone_numeric[expected_owner] then expected_owner = owner end
							end
						end
						dry_count = dry_count + 1
					end
					if actual_kind ~= expected_kind or actual_owner ~= expected_owner then
						mismatch = mismatch + 1
					end
				end
			end
			local declared_aperture_count = 0
			for _ in pairs(aperture_owner) do
				declared_aperture_count = declared_aperture_count + 1
			end
			assert(mismatch == 0 and aperture_count == declared_aperture_count and
				attachment_count == 8 and dry_count > 0,
				"selected exhaustive perimeter equality precedence changed")
			report.perimeter_aperture = aperture_count
			report.perimeter_attachment = attachment_count
			report.perimeter_dry = dry_count
		end
		if not focused_seed0 then
			print(("WP40 T2 %s whole-footprint passed: columns=%d Base=%d " ..
				"planned=%d dry=%d g=%d/o=%d/r=%d/m=%d schedule_intervals=%d"):format(
				profile.mode, report.columns, base_total, report.planned_water, report.dry,
				report.g, report.o, report.r, report.m, schedule_certified_intervals))
			return report
		end
	
		-- M57: replay the pre-R15 structural-first tail choice through the same
		-- independent all-20 Bank tracer, substitute the resulting Bank bytes into
		-- the affected Source Face cycles, and require the exhaustive gate to expose
		-- exactly the fifteen reviewed dry gaps.  Changing only Wing payload fields
		-- would not exercise final partition membership and is intentionally absent.
		local function run_historical_partition_regression()
			local historical_banks = assert(independent_bank_by_id.__historical)
			local changed_banks = {}
			for _, bank in ipairs(source.bay_bank_components) do
				local current, historical = assert(independent_bank_by_id[bank.id]),
					assert(historical_banks[bank.id])
				if not same_point_bytes(current, historical) then changed_banks[bank.id] = true end
			end
			local changed_count = 0
			for _ in pairs(changed_banks) do changed_count = changed_count + 1 end
			assert(changed_count > 0)
	
			local span_points = {}
			for _, span in ipairs(source.perimeter_spans) do
				local perimeter = assert(independent_perimeter_by_id[span.perimeter_id])
				local function boundary_point(boundary)
					if boundary.kind == "perimeter_attachment" then
						return assert(attachment_oracle_by_id[boundary.attachment_id]).a
					end
					return assert(source_by_id(source.perimeters,
						boundary.perimeter_id).polygon[boundary.index])
				end
				local first, last = boundary_point(span.start_boundary),
					boundary_point(span.end_boundary)
				local points, collecting = {}, false
				for station_index = 1, #perimeter.stations do
					local point = perimeter.stations[station_index]
					if point.x == first.x and point.z == first.z then collecting = true end
					if collecting then points[#points + 1] = {x = point.x, z = point.z} end
					if collecting and point.x == last.x and point.z == last.z then break end
				end
				assert(#points > 1 and points[#points].x == last.x and
					points[#points].z == last.z)
				if span.face_direction == "reverse" then
					local reversed = {}
					for index = #points, 1, -1 do reversed[#reversed + 1] = points[index] end
					points = reversed
				end
				span_points[span.id] = points
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
			local historical_arcs, affected_arcs = {}, {}
			local function terminal_point(terminal)
				assert(terminal.kind == "aperture_dry")
				return assert(authored_aperture_by_id[terminal.aperture_id])[
					terminal.side].point
			end
			for _, arc in ipairs(source.face_arcs) do
				local points, affected, complete = {}, false, true
				for _, component in ipairs(arc.authority_components) do
					local part
					if component.kind == "perimeter_span" then
						local full = assert(span_points[component.ref_id])
						local first = component.from_terminal ~= false and
							terminal_point(component.from_terminal) or full[1]
						local last = component.to_terminal ~= false and
							terminal_point(component.to_terminal) or full[#full]
						local first_index, last_index
						for index = 1, #full do
							if not first_index and full[index].x == first.x and
									full[index].z == first.z then first_index = index end
							if full[index].x == last.x and full[index].z == last.z then
								last_index = index
							end
						end
						assert(first_index and last_index and first_index <= last_index)
						part = {}
						for index = first_index, last_index do
							part[#part + 1] = full[index]
						end
					elseif component.kind == "bay_bank" then
						part = assert(historical_banks[component.ref_id])
						affected = affected or changed_banks[component.ref_id] == true
					else
						part, complete = nil, false
					end
					if part then
						if #points > 0 then assert(points[#points].x == part[1].x and
							points[#points].z == part[1].z, arc.id .. " historical join changed") end
						append_points(points, part)
					end
				end
				if complete then historical_arcs[arc.id] = points end
				if affected then affected_arcs[arc.id] = true end
			end
			local edge_points = {}
			for _, row in ipairs(compiled.families.land_boundaries) do
				edge_points[row.id] = payload_points(row, "stations_xz")
			end
			local historical_face_rows = deep_copy(face_rows)
			local affected_faces = 0
			for _, face in ipairs(source.zone_faces) do
				local affected = false
				for _, component in ipairs(face.cycle) do
					if component.kind ~= "shared_edge" and affected_arcs[component.ref_id] then
						affected = true break
					end
				end
				if affected then
					affected_faces = affected_faces + 1
					local polygon, cycle_join_keys = {}, {}
					for _, component in ipairs(face.cycle) do
						local part = component.kind == "shared_edge" and
							assert(edge_points[component.ref_id]) or
							assert(historical_arcs[component.ref_id])
						if component.direction == "reverse" then part = reverse_points(part) end
						if #polygon > 0 then assert(polygon[#polygon].x == part[1].x and
							polygon[#polygon].z == part[1].z,
							face.id .. " historical cycle join changed") end
						if #polygon > 0 then
							cycle_join_keys[point_key(part[1].x, part[1].z)] = true
						end
						append_points(polygon, part)
					end
					cycle_join_keys[point_key(polygon[1].x, polygon[1].z)] = true
					-- The historical ring rides the same two-tier acceptance
					-- as the payload ring (contracts 11.5-C, completed by
					-- 11.9): simple stays the fast path, a window-guarded
					-- touch family is admitted, anything else keeps failing
					-- here by name.
					local historical_appendix, historical_pinch = 0, 0
					if not exact.polygon_simple(polygon) then
						historical_appendix, historical_pinch =
							face_appendix_acceptance(face.id, polygon,
								cycle_join_keys)
						assert(historical_appendix + historical_pinch > 0,
							face.id .. " historical cycle topology changed")
					end
					assert(polygon[1].x == polygon[#polygon].x and
						polygon[1].z == polygon[#polygon].z and
						exact.signed_area2(polygon) > 0,
						face.id .. " historical cycle topology changed")
					for z, runs in pairs(historical_face_rows) do
						local kept = {}
						for index = 1, #runs do
							if runs[index].id ~= face.id then kept[#kept + 1] = runs[index] end
						end
						historical_face_rows[z] = kept
					end
					local rows = polygon_row_runs(polygon,
						historical_appendix + historical_pinch > 0)
					for z, runs in pairs(rows) do
						for index = 1, #runs do
							local run = runs[index]
							append_run(historical_face_rows, z, {first = run.first,
								finish = run.finish, class = run.class,
								numeric = zone_numeric[face.zone_id], zone_id = face.zone_id,
								id = face.id})
						end
					end
				end
			end
			assert(affected_faces > 0)
			local historical = evaluate(historical_face_rows, water_rows,
				expected_water_rows)
			assert(historical.g == 15 and historical.o == 0 and historical.r == 0 and
				historical.m == 0, ("historical structural-first partition changed " ..
					"g=%d/o=%d/r=%d/m=%d"):format(historical.g, historical.o,
					historical.r, historical.m))
			local gaps = {{-402,-1901},{402,-1901},{-1399,1900},
				{-402,1899},{-403,1900},{-402,1900},{-401,1900},
				{402,1899},{401,1900},{402,1900},{403,1900},
				{1398,1899},{1397,1900},{1398,1900},{1399,1900}}
			for _, point in ipairs(gaps) do
				assert(#active_runs(water_rows, point[2], point[1]) == 0 and
					#active_runs(historical_face_rows, point[2], point[1]) == 0 and
					#active_runs(face_rows, point[2], point[1]) == 1,
					"historical structural-first gap witness changed")
			end
		end
		run_historical_partition_regression()
	
		local aperture_owner, attachment_owner, span_owner = {}, {}, {}
		for index = 1, #compiled.families.mouth_apertures do
			local aperture = compiled.families.mouth_apertures[index]
			local perimeter = by_id(compiled.families.perimeters,
				named_scalar(aperture, "text_values", "perimeter_id"))
			local values = signed_array(perimeter, "stations_xz")
			local first = named_scalar(aperture, "unsigned_values", "first")
			local finish = named_scalar(aperture, "unsigned_values", "finish")
			local bay_id = named_scalar(aperture, "text_values", "bay_id")
			for station = first, finish - 1 do
				local coordinate = station * 2 + 1
				local key = point_key(values[coordinate], values[coordinate + 1])
				assert(not aperture_owner[key], "mouth apertures overlap")
				aperture_owner[key] = bay_id
			end
		end
		for index = 1, #source.perimeter_attachments do
			local attachment = source.perimeter_attachments[index]
			local expected = assert(attachment_oracle_by_id[attachment.id])
			local edge = assert(source_by_id(source.land_edges, attachment.edge_id))
			attachment_owner[point_key(expected.a.x, expected.a.z)] = edge.tie_zone_id
		end
		local function add_span_owner(point, owner)
			local key = point_key(point.x, point.z)
			if not span_owner[key] or zone_numeric[owner] < zone_numeric[span_owner[key]] then
				span_owner[key] = owner
			end
		end
		for index = 1, #source.perimeter_spans do
			local span = source.perimeter_spans[index]
			local perimeter = assert(independent_perimeter_by_id[span.perimeter_id])
			local function boundary_point(boundary)
				if boundary.kind == "perimeter_attachment" then
					return assert(attachment_oracle_by_id[boundary.attachment_id]).a
				end
				assert(boundary.kind == "perimeter_vertex" and
					boundary.perimeter_id == span.perimeter_id)
				return assert(source_by_id(source.perimeters,
					boundary.perimeter_id).polygon[boundary.index])
			end
			local first, last = boundary_point(span.start_boundary),
				boundary_point(span.end_boundary)
			local collecting, found = false, false
			for station_index = 1, #perimeter.stations do
				local point = perimeter.stations[station_index]
				if point.x == first.x and point.z == first.z then collecting = true end
				if collecting then add_span_owner(point, span.zone_id) end
				if collecting and point.x == last.x and point.z == last.z then
					found = true break
				end
			end
			assert(found, span.id .. " equality span is absent from independent perimeter")
		end
		local function selected_at(rows, x, z)
			local water = active_runs(water_rows, z, x)
			local selected_water
			for index = 1, #water do
				if water[index].kind == "base" and
						(not selected_water or selected_water.kind ~= "base") then
					selected_water = water[index]
				elseif not selected_water then selected_water = water[index] end
			end
			if selected_water then return "planned_water", selected_water.owner end
			local faces = active_runs(rows, z, x)
			local selected
			for index = 1, #faces do
				if not selected or faces[index].numeric < selected.numeric then
					selected = faces[index]
				end
			end
			if selected then return "land", selected.zone_id end
			return "missing", nil
		end
		local equality_fixture
		local equality_first_mismatch
		local function perimeter_equality_mismatches(rows)
			local mismatches, aperture_count, attachment_count, dry_count = 0, 0, 0, 0
			for perimeter_index = 1, 2 do
				local perimeter = compiled.families.perimeters[perimeter_index]
				local values = signed_array(perimeter, "stations_xz")
				local count = named_scalar(perimeter, "unsigned_values", "station_count")
				for station = 0, count - 1 do
					local coordinate = station * 2 + 1
					local x, z = values[coordinate], values[coordinate + 1]
					local key = point_key(x, z)
					local kind, actual_owner = selected_at(rows, x, z)
					local bay_id = aperture_owner[key]
					local expected_kind, expected_owner
					if bay_id then
						expected_kind = "planned_water"
						expected_owner = source_bay_owner(assert(bay_source_by_id[bay_id]), x, z)
						aperture_count = aperture_count + 1
					else
						expected_kind = "land"
						expected_owner = attachment_owner[key] or span_owner[key]
						if attachment_owner[key] then attachment_count = attachment_count + 1 end
						if not expected_owner then
							local owners = assert(declared[key],
								"final perimeter closure is not byte-identical to its fixed " ..
								"ordered edge union at " .. key)
							for owner in pairs(owners) do
								if not expected_owner or zone_numeric[owner] <
										zone_numeric[expected_owner] then expected_owner = owner end
							end
						end
						dry_count = dry_count + 1
						if not equality_fixture and not attachment_owner[key] and span_owner[key] then
							equality_fixture = {x = x, z = z, owner = expected_owner}
						end
					end
					if kind ~= expected_kind or actual_owner ~= expected_owner then
						mismatches = mismatches + 1
						if not equality_first_mismatch then
							equality_first_mismatch = {x = x, z = z, kind = kind,
								actual = actual_owner, expected_kind = expected_kind,
								expected = expected_owner, aperture = bay_id,
								attachment = attachment_owner[key], span = span_owner[key]}
						end
					end
				end
			end
			return mismatches, aperture_count, attachment_count, dry_count
		end
		local equality_mismatches, aperture_count, attachment_count, dry_count =
			perimeter_equality_mismatches(face_rows)
		local declared_aperture_count = 0
		for _ in pairs(aperture_owner) do declared_aperture_count = declared_aperture_count + 1 end
		assert(equality_mismatches == 0 and aperture_count == declared_aperture_count and
			attachment_count == 8 and dry_count > 0 and equality_fixture,
			("exhaustive perimeter equality precedence changed " ..
				"m=%d ap=%d/%d at=%d dry=%d fixture=%s first=%s:%s %s/%s -> %s/%s"):format(
				equality_mismatches, aperture_count, declared_aperture_count,
				attachment_count, dry_count, tostring(equality_fixture ~= nil),
				equality_first_mismatch and equality_first_mismatch.x or "nil",
				equality_first_mismatch and equality_first_mismatch.z or "nil",
				equality_first_mismatch and tostring(equality_first_mismatch.kind) or "nil",
				equality_first_mismatch and tostring(equality_first_mismatch.actual) or "nil",
				equality_first_mismatch and tostring(equality_first_mismatch.expected_kind) or "nil",
				equality_first_mismatch and tostring(equality_first_mismatch.expected) or "nil"))
		local wrong_owner_faces = deep_copy(face_rows)
		local target_runs = assert(wrong_owner_faces[equality_fixture.z])
		local replaced = false
		for index = 1, #target_runs do
			local run = target_runs[index]
			if equality_fixture.x >= run.first and equality_fixture.x <= run.finish and
					run.zone_id == equality_fixture.owner then
				table.remove(target_runs, index)
				if run.first < equality_fixture.x then
					local left = deep_copy(run) left.finish = equality_fixture.x - 1
					target_runs[#target_runs + 1] = left
				end
				if equality_fixture.x < run.finish then
					local right = deep_copy(run) right.first = equality_fixture.x + 1
					target_runs[#target_runs + 1] = right
				end
				local wrong = deep_copy(run)
				wrong.first, wrong.finish = equality_fixture.x, equality_fixture.x
				wrong.zone_id = equality_fixture.owner == source.zones[1].id and
					source.zones[2].id or source.zones[1].id
				wrong.numeric = zone_numeric[wrong.zone_id]
				target_runs[#target_runs + 1] = wrong
				replaced = true break
			end
		end
		assert(replaced and perimeter_equality_mismatches(wrong_owner_faces) > 0,
			"perimeter equality gate accepted a shape-preserving wrong owner")
	
		-- The same exhaustive gate must reject coherent missing/duplicate Face
		-- membership and a changed final water owner, not merely malformed records.
		local missing_faces = deep_copy(face_rows)
		for z, runs in pairs(missing_faces) do
			local kept = {}
			for index = 1, #runs do
				if runs[index].numeric ~= compiled.families.dry_faces[1].numeric_id then
					kept[#kept + 1] = runs[index]
				end
			end
			missing_faces[z] = kept
		end
		local missing = evaluate(missing_faces, water_rows, expected_water_rows)
		assert(missing.g > 0, "whole footprint accepted a deleted Face")
		local duplicate_faces = deep_copy(face_rows)
		local duplicate_row = assert(duplicate_faces[equality_fixture.z])
		local duplicated
		for index = 1, #duplicate_row do
			local run = duplicate_row[index]
			if equality_fixture.x >= run.first and equality_fixture.x <= run.finish and
					run.zone_id == equality_fixture.owner then
				local copy = deep_copy(run)
				copy.first, copy.finish = equality_fixture.x, equality_fixture.x
				duplicate_row[#duplicate_row + 1] = copy
				duplicated = true break
			end
		end
		assert(duplicated)
		local duplicate = evaluate(duplicate_faces, water_rows, expected_water_rows)
		assert(duplicate.r > 0, "whole footprint accepted a duplicate Face")
		local changed_water = deep_copy(water_rows)
		local changed
		for _, runs in pairs(changed_water) do
			for index = 1, #runs do
				if runs[index].kind == "base" then
					runs[index].owner = "corrupt_water_owner"
					changed = true break
				end
			end
			if changed then break end
		end
		assert(changed)
		local water_corruption = evaluate(face_rows, changed_water, expected_water_rows)
		assert(water_corruption.m > 0,
			"whole footprint accepted a water precedence corruption")
		print(("WP40 T2 partition focused Seed0 whole-footprint passed: " ..
			"columns=%d Base=%d (%d/%d/%d/%d) planned=%d dry=%d " ..
			"g=%d/o=%d/r=%d/m=%d perimeter AP/attachment/dry=%d/%d/%d " ..
			"schedule_intervals=%d"):format(report.columns, base_total,
			base_counts.bay_elandor_west, base_counts.bay_elandor_east,
			base_counts.bay_kragmar_west, base_counts.bay_kragmar_east,
			report.planned_water, report.dry, report.g, report.o, report.r, report.m,
			aperture_count, attachment_count, dry_count, schedule_certified_intervals))
		return report
	end
	
	return run_exhaustive_partition_oracle
end
