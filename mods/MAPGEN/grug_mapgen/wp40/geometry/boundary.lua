-- Private WP40 T2 stage-S1 boundary materialization.  It owns the whole per
-- record R7 displacement stage: canonical station metadata, normals, raw and
-- damped scalars, local envelope clipping, the record-wide topology ceiling
-- scan, component conversion, the sole final canonical 8-connected reraster,
-- the r7_fixed_closure resolver, the four junction_departure records, and the
-- perimeters.  Nothing downstream of S1 -- bay water, notch fill, aperture and
-- span classes, terminal resolutions, R18 intervals, R19 joint tuples, bank
-- materialization, faces, Whole or relief -- lives here.
--
-- The extreme selector consumes exactly this stage (`SEL [S1 only]` in
-- docs/research/wp40-t2-degeneracy-completeness.md section 6.1), so the module
-- also publishes the closed canonical projection of the Source surface S1
-- reads.  A pool authority pinned to that projection plus these bytes survives
-- every later-stage geometry correction, which whole-file Source pins do not.
--
-- Diagnostics keep the historical `WP40 geometry partition:` prefix: the
-- retained failure provenance in tools/wp40/fixtures/t2_extreme_e0 and the
-- partition harness bind that exact text, and this extraction is a relocation,
-- not a behaviour change.

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

local function new_boundary(dependencies)
	exact_dependencies(dependencies)
	local canonical = dependencies.canonical
	local deterministic = dependencies.deterministic
	local exact = dependencies.exact
	local raster = dependencies.raster
	local source = dependencies.source
	local boundary = {}

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

	local function copy_points(points)
		local result = {}
		for index = 1, dense(points, "points") do
			result[index] = {x = points[index].x, z = points[index].z}
		end
		return result
	end

	local function key(point)
		return point.x .. ":" .. point.z
	end

	local function reverse_points(points)
		local result = {}
		for index = #points, 1, -1 do
			result[#result + 1] = {x = points[index].x, z = points[index].z}
		end
		return result
	end

	local function closed_polygon(points)
		local polygon = copy_points(points)
		if #polygon == 0 then fail("empty closed polygon") end
		polygon[#polygon + 1] = {x = polygon[1].x, z = polygon[1].z}
		return polygon
	end

	local function polygon_index(points)
		local polygon = closed_polygon(points)
		return exact.polygon_index(polygon)
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

	-- Every authored coordinate that pins a boundary station to zero jitter.
	-- The result is deduplicated and lexicographically sorted, so it is exactly
	-- the semantic no-jitter input: which record kind contributed a column, and
	-- in what order, is invisible to displacement and to the projection below.
	local function collect_no_jitter_sources(source_value)
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
		add_polyline_collection(source_value.land_edges, "control")
		add_polyline_collection(source_value.perimeters, "polygon")
		add_polyline_collection(source_value.bays, "centreline")
		add_polyline_collection(source_value.islands, "polygon")
		add_polyline_collection(source_value.channels, "polygon")
		add_polyline_collection(source_value.routes, "centreline")
		add_polyline_collection(source_value.island_routes, "centreline")
		add_polyline_collection(source_value.hydrology, "centreline")
		add_polyline_collection(source_value.housing_masks, "polygon")
		for spur_index = 1, #source_value.poi_spurs do
			local paths = source_value.poi_spurs[spur_index].candidate_paths
			for path_index = 1, #paths do
				for point_index = 1, #paths[path_index] do
					add(paths[path_index][point_index])
				end
			end
		end
		for arc_index = 1, #source_value.face_arcs do
			for component_index = 1, #source_value.face_arcs[arc_index].authority_components do
				local component = source_value.face_arcs[arc_index].authority_components[component_index]
				if component.kind == "literal_arc" then
					for point_index = 1, #component.control do add(component.control[point_index]) end
				end
			end
		end
		for _, collection in ipairs({source_value.route_interfaces,
				source_value.island_route_interfaces}) do
			for index = 1, #collection do add(collection[index].position) end
		end
		for index = 1, #source_value.anchors do
			if source_value.anchors[index].placement_mode == "fixed" then
				add(source_value.anchors[index].position)
			end
		end
		local holy = source_value.constants.holy_grounds
		for _, x in ipairs({holy.min_x, holy.max_x}) do
			for _, z in ipairs({holy.min_z, holy.max_z}) do add({x = x, z = z}) end
		end
		for index = 1, #source_value.constants.holy_junction_x do
			local x = source_value.constants.holy_junction_x[index]
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

	-- The four checksum-covered junction_departure records.  Both the seed
	-- materialization and the S1 projection call this one resolver, so the
	-- pinned effective controls can never drift from the measured ones.
	local function resolve_departures(source_value, edge_source_by_id)
		local departure_by_edge, effective_control_by_edge, departure_points = {}, {}, {}
		if #source_value.junction_departures ~= 4 then
			fail("junction departure roster is not exactly four records")
		end
		for index = 1, #source_value.junction_departures do
			local departure = source_value.junction_departures[index]
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
			local frame = source_value.constants.mainland_frame
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
		return departure_by_edge, effective_control_by_edge, departure_points
	end

	local function resolve_no_jitter(source_value, departure_points)
		local no_jitter = collect_no_jitter_sources(source_value)
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
		return no_jitter
	end

	local function edge_source_index(source_value)
		local edge_source_by_id = {}
		for index = 1, #source_value.land_edges do
			edge_source_by_id[source_value.land_edges[index].id] =
				source_value.land_edges[index]
		end
		return edge_source_by_id
	end

	-- Sole seed-dependent R7 boundary materialization authority. Partition
	-- compilation and the extreme selector consume this same result; neither
	-- path may prepare effective controls, no-jitter sources, fixed closure, or
	-- displacement independently.
	local function materialize_boundary_seed(seed)
		deterministic.validate_seed(seed)
		source_validator()
		local edge_source_by_id = edge_source_index(source)
		local departure_by_edge, effective_control_by_edge, departure_points =
			resolve_departures(source, edge_source_by_id)
		local no_jitter = resolve_no_jitter(source, departure_points)
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
		return {edge_source_by_id = edge_source_by_id,
			departure_by_edge = departure_by_edge,
			perimeter_rows = perimeter_rows, perimeter_by_id = perimeter_by_id,
			island_rows = island_rows, island_by_id = island_by_id,
			provisional_edges = provisional_edges, edge_by_id = edge_by_id}
	end

	local function extreme_scalar_records(seed)
		local boundary_seed = materialize_boundary_seed(seed)
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
		for index = 1, #boundary_seed.perimeter_rows do
			append("perimeter", boundary_seed.perimeter_rows[index], index)
		end
		for index = 1, #boundary_seed.island_rows do
			append("island", boundary_seed.island_rows[index], index)
		end
		for index = 1, #boundary_seed.provisional_edges do
			append("land_edge", boundary_seed.provisional_edges[index],
				boundary_seed.provisional_edges[index].source.numeric_id)
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
		for child_key, child in pairs(value) do
			result[private_plain_copy(child_key, seen)] = private_plain_copy(child, seen)
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
		local isolated = new_boundary({canonical = canonical,
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

	-- ------------------------------------------------------------------
	-- S1 authority projection
	--
	-- The closed canonical value below is exactly the Source surface the code
	-- above reads.  Everything a later stage owns -- bay mouth apertures,
	-- closure wings, bank components, edge transitions, spans, attachments,
	-- face arcs as arc records, zone faces, relief, landmarks, templates -- is
	-- absent by construction, so adding or editing such a record cannot move
	-- this checksum.  Record collections whose S1 meaning is ordinal
	-- (perimeters, islands, land edges, junction departures) are encoded as
	-- ordered arrays; the no-jitter surface is encoded as the already sorted
	-- and deduplicated station set that displacement actually consumes, which
	-- is why a new record kind that contributes no new zero-jitter column is
	-- invisible here even though it is authored inside the same file.
	--
	-- Authority prose is deliberately NOT part of the projection.  No line of
	-- S1 reads geometry_policies, so amending its wording cannot move a scalar,
	-- and those policy records already carry their own frozen checksums inside
	-- validation/t2_source.lua.  Binding them here would have re-invalidated a
	-- measured pool at R16, R18 and R19, each of which rewrote the boundary
	-- displacement prose while leaving every S1 geometric input bit-identical.
	-- s1_policy_checksums below republishes those digests as provenance, using
	-- the same encoding as the production Stage-1 validator.
	-- ------------------------------------------------------------------

	local PROJECTION_SCHEMA = "grug_wp40_s1_boundary_projection_v1"
	local POLICY_NAMES = {"boundary_displacement", "route_raster",
		"geometry_extreme_selector"}

	local function text_node(value, label)
		if type(value) ~= "string" then fail(label .. " is not projectable text") end
		return canonical.text(value)
	end

	local function integer_node(value, label)
		if type(value) ~= "number" or value % 1 ~= 0 then
			fail(label .. " is not a projectable integer")
		end
		return canonical.signed(value)
	end

	local function point_node(point, label)
		if type(point) ~= "table" or getmetatable(point) ~= nil then
			fail(label .. " is not a projectable station")
		end
		return canonical.array({integer_node(point.x, label .. " x"),
			integer_node(point.z, label .. " z")})
	end

	local function points_node(points, label)
		local rows = {}
		for index = 1, dense(points, label) do
			rows[index] = point_node(points[index], label)
		end
		return canonical.array(rows)
	end

	local function field(name, value)
		return {canonical.text(name), value}
	end

	-- Authority text is projected structurally, not by file bytes: a policy
	-- table is a sorted name/value map, a policy array keeps its order.
	local function policy_node(value, label)
		local kind = type(value)
		if kind == "string" then return canonical.text(value) end
		if kind == "boolean" then return canonical.boolean(value) end
		if kind == "number" then return integer_node(value, label) end
		if kind ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a projectable policy value")
		end
		local count, named = 0, false
		for policy_key in pairs(value) do
			count = count + 1
			if type(policy_key) ~= "number" then named = true end
		end
		if not named then
			local rows = {}
			for index = 1, dense(value, label) do
				rows[index] = policy_node(value[index], label .. "[]")
			end
			return canonical.array(rows)
		end
		local rows, names = {}, {}
		for policy_key in pairs(value) do
			if type(policy_key) ~= "string" then
				fail(label .. " has a nonstring policy field")
			end
			names[#names + 1] = policy_key
		end
		table.sort(names)
		for index = 1, #names do
			rows[index] = field(names[index],
				policy_node(value[names[index]], label .. "." .. names[index]))
		end
		if count ~= #names then fail(label .. " mixes array and named policy fields") end
		return canonical.map(rows)
	end

	local function closure_node(row)
		local closure = row.r7_fixed_closure
		if closure == nil then return canonical.array({}) end
		if type(closure) ~= "table" or getmetatable(closure) ~= nil then
			fail(row.id .. " fixed closure is not projectable")
		end
		local refs = {}
		for index = 1, dense(closure.edge_refs, row.id .. " fixed closure refs") do
			local ref = closure.edge_refs[index]
			refs[index] = canonical.array({
				text_node(ref.edge_id, row.id .. " closure edge id"),
				text_node(ref.direction, row.id .. " closure direction")})
		end
		return canonical.array({text_node(closure.kind, row.id .. " closure kind"),
			canonical.array(refs)})
	end

	local function perimeter_node(row, index)
		return canonical.map({
			field("index", canonical.unsigned(index)),
			field("id", text_node(row.id, "perimeter id")),
			field("kind", text_node(row.kind, "perimeter kind")),
			field("orientation", text_node(row.orientation, "perimeter orientation")),
			field("noise_domain", text_node(row.noise_domain, "perimeter noise domain")),
			field("max_displacement",
				integer_node(row.max_displacement, "perimeter max displacement")),
			field("polygon", points_node(row.polygon, "perimeter polygon")),
			field("r7_fixed_closure", closure_node(row))})
	end

	local function island_node(row, index)
		return canonical.map({
			field("index", canonical.unsigned(index)),
			field("id", text_node(row.id, "island id")),
			field("orientation", text_node(row.orientation, "island orientation")),
			field("noise_domain", text_node(row.noise_domain, "island noise domain")),
			field("max_displacement",
				integer_node(row.max_displacement, "island max displacement")),
			field("center", point_node(row.center, "island center")),
			field("radius_x", integer_node(row.envelope.radius_x, "island radius x")),
			field("radius_z", integer_node(row.envelope.radius_z, "island radius z")),
			field("polygon", points_node(row.polygon, "island polygon"))})
	end

	local function land_edge_node(row, index, effective_control_by_edge)
		return canonical.map({
			field("index", canonical.unsigned(index)),
			field("id", text_node(row.id, "land edge id")),
			field("numeric_id", integer_node(row.numeric_id, "land edge numeric id")),
			field("noise_domain", text_node(row.noise_domain, "land edge noise domain")),
			field("max_displacement",
				integer_node(row.max_displacement, "land edge max displacement")),
			field("effective_control",
				points_node(effective_control_by_edge[row.id] or row.control,
					"land edge effective control"))})
	end

	local function departure_node(row, index)
		return canonical.map({
			field("index", canonical.unsigned(index)),
			field("id", text_node(row.id, "junction departure id")),
			field("edge_id", text_node(row.edge_id, "junction departure edge id")),
			field("edge_endpoint",
				text_node(row.edge_endpoint, "junction departure endpoint"))})
	end

	local function frame_node(frame)
		return canonical.map({
			field("min_x", integer_node(frame.min_x, "mainland frame min x")),
			field("max_x", integer_node(frame.max_x, "mainland frame max x")),
			field("min_z", integer_node(frame.min_z, "mainland frame min z")),
			field("max_z", integer_node(frame.max_z, "mainland frame max z"))})
	end

	local function s1_source_projection(source_value)
		source_value = source_value or source
		if type(source_value) ~= "table" or getmetatable(source_value) ~= nil then
			fail("S1 projection source is not a plain table")
		end
		local edge_source_by_id = edge_source_index(source_value)
		local _, effective_control_by_edge, departure_points =
			resolve_departures(source_value, edge_source_by_id)
		local perimeters, islands, land_edges, departures = {}, {}, {}, {}
		for index = 1, #source_value.perimeters do
			perimeters[index] = perimeter_node(source_value.perimeters[index], index)
		end
		for index = 1, #source_value.islands do
			islands[index] = island_node(source_value.islands[index], index)
		end
		for index = 1, #source_value.land_edges do
			land_edges[index] = land_edge_node(source_value.land_edges[index], index,
				effective_control_by_edge)
		end
		for index = 1, #source_value.junction_departures do
			departures[index] =
				departure_node(source_value.junction_departures[index], index)
		end
		return canonical.map({
			field("schema", canonical.text(PROJECTION_SCHEMA)),
			field("perimeters", canonical.array(perimeters)),
			field("islands", canonical.array(islands)),
			field("land_edges", canonical.array(land_edges)),
			field("junction_departures", canonical.array(departures)),
			field("mainland_frame", frame_node(source_value.constants.mainland_frame)),
			field("no_jitter_stations",
				points_node(resolve_no_jitter(source_value, departure_points),
					"no-jitter station"))})
	end

	local function s1_source_checksum(source_value)
		return canonical.hex(canonical.checksum(s1_source_projection(source_value),
			dependencies.raw_sha256))
	end

	-- Provenance only.  The encoding is the bare policy record, matching the
	-- production Stage-1 geometry-policy checksums bit for bit.
	local function s1_policy_checksums(source_value)
		source_value = source_value or source
		local policies = source_value.geometry_policies
		local result = {}
		for index = 1, #POLICY_NAMES do
			local name = POLICY_NAMES[index]
			result[name] = canonical.hex(canonical.checksum(
				policy_node(policies[name], name .. " policy"),
				dependencies.raw_sha256))
		end
		return result
	end

	boundary.materialize = materialize_boundary_seed
	boundary.extreme_scalar_records = extreme_scalar_records
	boundary.new_extreme_scalar_session = new_extreme_scalar_session
	boundary.no_jitter_stations = resolve_no_jitter
	boundary.PROJECTION_SCHEMA = PROJECTION_SCHEMA
	boundary.POLICY_NAMES = POLICY_NAMES
	boundary.s1_source_projection = s1_source_projection
	boundary.s1_source_checksum = s1_source_checksum
	boundary.s1_policy_checksums = s1_policy_checksums
	return boundary
end

return new_boundary
