-- WP40 T2 face-ring probe -- the bay-transition-simplicity package, step 1
-- (contracts section 10.3).  Diagnosis only: production files are untouched
-- and nothing here writes an artifact row.
--
-- Per seed it runs partition.census_scan with the Scan-4 tiers, then
-- recomposes every face the scan classified face_non_simple_reject *outside*
-- the production path: transition shared edges from the selected joint
-- tuple's retained probe bytes, ordinary shared edges re-cut from an
-- independent boundary.materialize at the Scan-1 row's retained interval
-- bounds, Banks from the retained Scan-3a/3b traces, perimeter spans
-- from an independent boundary.materialize of the same seed, trimmed at the
-- adjacent Bank trace endpoints exactly where census_scan4's component_span
-- trims at the resolved terminals (the two agree whenever the scan's own
-- join checks passed, which face_non_simple_reject presupposes).  The
-- recomposed ring is cross-checked against the scan's own row --
-- partition.census_face_classify must reproduce the class and the station
-- count must match -- and then swept for every simplicity violation:
-- repeated stations and opposing cell diagonals, each reported with station
-- coordinates, incident segments and per-station contributors.  The full
-- ring is dumped as TSV for the record.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
local dump_dir = assert(arg[3], "dump directory required")
assert(arg[4], "at least one seed required")

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
local vocabulary = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local partition = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})
local boundary = new_boundary({canonical = canonical,
	deterministic = deterministic, exact = exact, raster = raster,
	raw_sha256 = raw_sha256, source = source,
	source_validator = source_validator, vocabulary = vocabulary})

local span_source_by_id = {}
for index = 1, #source.perimeter_spans do
	span_source_by_id[source.perimeter_spans[index].id] =
		source.perimeter_spans[index]
end
local arc_source_by_id = {}
for index = 1, #source.face_arcs do
	arc_source_by_id[source.face_arcs[index].id] = source.face_arcs[index]
end
local face_source_by_id = {}
for index = 1, #source.zone_faces do
	face_source_by_id[source.zone_faces[index].id] = source.zone_faces[index]
end

-- The v3 manifest's detached-shoulder admission stations, per seed, so the
-- report can flag them wherever they appear in a ring.
local admitted_by_seed = {}
do
	local path = repo .. "/tools/wp40/fixtures/t2_census/census-manifest-v3.tsv"
	local file = assert(io.open(path, "rb"))
	for line in file:lines() do
		local site, seed_text, x, z = line:match("^detached_shoulder_admission" ..
			"\t(%S+) seed=(%d+) station=(%-?%d+):(%-?%d+)$")
		if site then
			local rows = admitted_by_seed[seed_text] or {}
			admitted_by_seed[seed_text] = rows
			rows[#rows + 1] = {site = site, x = tonumber(x), z = tonumber(z)}
		end
	end
	file:close()
end

local function key(point)
	return point.x .. ":" .. point.z
end

-- append_dedup of partition.lua:202, the semantics compile_impl's and
-- census_scan4's final-edge assembly share: a consecutive duplicate never
-- enters a station run.
local function append_dedup(points, point)
	if #points == 0 or key(points[#points]) ~= key(point) then
		points[#points + 1] = {x = point.x, z = point.z}
	end
end

local function points_with_label(points, label)
	local rows, labels = {}, {}
	for index = 1, #points do
		rows[index] = {x = points[index].x, z = points[index].z,
			perimeter_index = points[index].perimeter_index}
		labels[index] = label
	end
	return {points = rows, labels = labels}
end

local function reverse_part(part)
	local rows, labels = {}, {}
	for index = #part.points, 1, -1 do
		rows[#rows + 1] = part.points[index]
		labels[#labels + 1] = part.labels[index]
	end
	return {points = rows, labels = labels}
end

-- append_points dedup semantics: a consecutive duplicate is suppressed; the
-- suppressed point's contributor is recorded on the join station.
local function append_part(target, part)
	for index = 1, #part.points do
		local point = part.points[index]
		local count = #target.points
		if count == 0 or target.points[count].x ~= point.x or
				target.points[count].z ~= point.z then
			target.points[count + 1] = point
			target.labels[count + 1] = part.labels[index]
		else
			target.labels[count] = target.labels[count] .. " =join= " ..
				part.labels[index]
		end
	end
end

-- The span collection of census_scan4 verbatim: boundary points from the
-- attachment A or the source polygon vertex, stations collected in
-- perimeter station order, reversed only for a declared reverse
-- face_direction.  perimeter_index is carried for the report.
local function span_full_stations(span, result, materialized)
	local perimeter = materialized.perimeter_by_id[span.perimeter_id]
	local function boundary_point(boundary)
		if boundary.kind == "perimeter_attachment" then
			for index = 1, #result.attachments do
				local row = result.attachments[index]
				if row.id == boundary.attachment_id then
					if not row.a then
						error(span.id .. " final endpoints are absent", 0)
					end
					return {x = row.a.x, z = row.a.z}
				end
			end
			error(span.id .. " attachment row is absent", 0)
		end
		return perimeter.source.polygon[boundary.index]
	end
	local first_point = boundary_point(span.start_boundary)
	local last_point = boundary_point(span.end_boundary)
	local points, collecting = {}, false
	for station_index = 1, #perimeter.stations do
		local point = perimeter.stations[station_index]
		if key(point) == key(first_point) then collecting = true end
		if collecting then
			points[#points + 1] = {x = point.x, z = point.z,
				perimeter_index = station_index}
		end
		if collecting and key(point) == key(last_point) then break end
	end
	if #points == 0 or key(points[#points]) ~= key(last_point) then
		error(span.id .. " final endpoints are absent", 0)
	end
	if span.face_direction == "reverse" then
		local reversed = {}
		for index = #points, 1, -1 do reversed[#reversed + 1] = points[index] end
		points = reversed
	end
	return points
end

-- component_span's terminal trim, with the resolved terminal points taken
-- from the adjacent Bank traces in the same arc (identical whenever the
-- scan's own arc join checks held).  First occurrence for the from
-- terminal, last occurrence for the to terminal, exactly as production
-- searches.
local function compose_arc(arc, result, materialized)
	local parts = {}
	for component_index = 1, #arc.authority_components do
		local component = arc.authority_components[component_index]
		if component.kind == "bay_bank" then
			local traced = result.scan3b_traces[component.ref_id] or
				result.scan3a_traces[component.ref_id]
			if not traced then
				error(component.ref_id .. " has no retained trace", 0)
			end
			parts[component_index] = points_with_label(traced,
				"bank:" .. component.ref_id)
		elseif component.kind == "perimeter_span" then
			parts[component_index] = {
				span = span_source_by_id[component.ref_id],
				component = component}
		elseif component.kind == "literal_arc" and
				component.boundary_role == "island_coast" then
			local island = materialized.island_by_id[component.source_ref]
			local points = {}
			for index = 1, #island.stations do
				points[index] = island.stations[index]
			end
			points[#points + 1] = {x = points[1].x, z = points[1].z}
			parts[component_index] = points_with_label(points,
				"island:" .. tostring(component.source_ref))
		elseif component.kind == "literal_arc" then
			parts[component_index] = points_with_label(
				raster.final_raster(component.control, false),
				"literal:" .. tostring(component.source_ref))
		else
			error("unsupported arc component kind " ..
				tostring(component.kind), 0)
		end
	end
	for component_index = 1, #arc.authority_components do
		local part = parts[component_index]
		if part.span then
			local stations = span_full_stations(part.span, result, materialized)
			local component = part.component
			local from_point, to_point
			if component.from_terminal ~= false then
				local previous = parts[component_index - 1]
				if not (previous and previous.points) then
					error(part.span.id ..
						" from terminal has no adjacent Bank trace", 0)
				end
				from_point = previous.points[#previous.points]
			end
			if component.to_terminal ~= false then
				local following = parts[component_index + 1]
				if not (following and following.points) then
					error(part.span.id ..
						" to terminal has no adjacent Bank trace", 0)
				end
				to_point = following.points[1]
			end
			local first_index, last_index
			for station_index = 1, #stations do
				if from_point and not first_index and
						key(stations[station_index]) == key(from_point) then
					first_index = station_index
				end
				if to_point and
						key(stations[station_index]) == key(to_point) then
					last_index = station_index
				end
			end
			if not from_point then first_index = 1 end
			if not to_point then last_index = #stations end
			if not first_index or not last_index or
					first_index > last_index then
				error(part.span.id .. " terminal-trimmed span is absent", 0)
			end
			local trimmed = {}
			for station_index = first_index, last_index do
				trimmed[#trimmed + 1] = stations[station_index]
			end
			parts[component_index] = points_with_label(trimmed,
				"span:" .. part.span.id)
		end
	end
	local merged = {points = {}, labels = {}}
	for component_index = 1, #parts do
		local part = parts[component_index]
		if #merged.points > 0 and
				key(merged.points[#merged.points]) ~= key(part.points[1]) then
			error(arc.id .. " authority components do not join at " ..
				key(merged.points[#merged.points]) .. " -> " ..
				key(part.points[1]), 0)
		end
		append_part(merged, part)
	end
	return merged
end

-- A face cycle's shared edge, projected from census_scan4's own final-edge
-- materialization (partition.lua:6231-6310).  A transition edge is the
-- selected joint tuple's retained probe bytes -- the only bytes that
-- materialize, source authority section 4.  An ordinary edge retains its
-- single maximal dry interval, which the Scan-1 row pins by station index
-- (class ordinary_interval_select, selected_first/selected_finish) and this
-- probe re-cuts from an independent boundary.materialize of the same seed,
-- the same independent-materialization route the perimeter spans take; the
-- station count of that independent edge is cross-checked against the scan
-- row before the cut, so a materialization that drifted aborts instead of
-- recomposing a different edge.  An attachment edge without a transition
-- would need production's A re-raster and is refused, not approximated.
local function final_edge_part(edge_id, result, materialized)
	local selected = result.scan2_selected[edge_id]
	if selected and selected.probe then
		return points_with_label(selected.probe, "edge:" .. edge_id)
	end
	local row
	for index = 1, #result.edges do
		if result.edges[index].id == edge_id then row = result.edges[index] end
	end
	if not row then
		error(edge_id .. " has no Scan-1 edge row", 0)
	end
	if row.kind ~= "ordinary" then
		error(edge_id .. " is kind " .. tostring(row.kind) ..
			" with no retained probe bytes (outside this probe)", 0)
	end
	if row.class ~= "ordinary_interval_select" or not row.selected_first or
			not row.selected_finish then
		error(edge_id .. " retained no ordinary interval (class " ..
			tostring(row.class) .. ")", 0)
	end
	local edge = materialized.edge_by_id[edge_id]
	if not edge then
		error(edge_id .. " is not a materialized provisional edge", 0)
	end
	if row.station_count ~= #edge.stations then
		error(edge_id .. " independent materialization has " ..
			#edge.stations .. " stations, the scan row has " ..
			tostring(row.station_count), 0)
	end
	local stations = {}
	for station_index = row.selected_first, row.selected_finish do
		append_dedup(stations, edge.stations[station_index])
	end
	return points_with_label(stations, "ordinary_edge:" .. edge_id)
end

local function compose_face(face, result, materialized)
	local ring = {points = {}, labels = {}}
	for cycle_index = 1, #face.cycle do
		local component = face.cycle[cycle_index]
		local part
		if component.kind == "shared_edge" then
			part = final_edge_part(component.ref_id, result, materialized)
		else
			local arc = arc_source_by_id[component.ref_id]
			if not arc then
				error(component.ref_id .. " is not a known face arc", 0)
			end
			part = compose_arc(arc, result, materialized)
		end
		if component.direction == "reverse" then part = reverse_part(part) end
		if #ring.points > 0 and
				key(ring.points[#ring.points]) ~= key(part.points[1]) then
			error(face.id .. " component graph does not join at " ..
				key(ring.points[#ring.points]) .. " -> " ..
				key(part.points[1]), 0)
		end
		append_part(ring, part)
	end
	return ring
end

local function station_annotations(point, materialized, admitted)
	local notes = {}
	for _, row in pairs(materialized.perimeter_by_id) do
		local station_index = row.lookup[key(point)]
		if station_index then
			notes[#notes + 1] = row.source.id .. "#" .. station_index
		end
	end
	if admitted then
		for index = 1, #admitted do
			if admitted[index].x == point.x and admitted[index].z == point.z then
				notes[#notes + 1] = "ADMITTED_SHOULDER_STATION[" ..
					admitted[index].site .. "]"
			end
		end
	end
	return #notes > 0 and (" {" .. table.concat(notes, " ") .. "}") or ""
end

local function print_window(ring, center, materialized, admitted)
	local first = math.max(1, center - 3)
	local last = math.min(#ring.points, center + 3)
	for index = first, last do
		local point = ring.points[index]
		local marker = index == center and " <<<" or ""
		print("      ring[" .. index .. "] " .. key(point) .. "  [" ..
			ring.labels[index] .. "]" ..
			station_annotations(point, materialized, admitted) .. marker)
	end
end

local function part_summary(ring)
	local rows = {}
	local first = 1
	local function base_label(label)
		return label:match("^([^ ]+)") or label
	end
	for index = 2, #ring.points + 1 do
		local done = index > #ring.points
		if done or base_label(ring.labels[index]) ~=
				base_label(ring.labels[first]) then
			rows[#rows + 1] = "    [" .. first .. ".." .. (index - 1) .. "] " ..
				base_label(ring.labels[first]) .. "  " ..
				key(ring.points[first]) .. " -> " ..
				key(ring.points[index - 1])
			first = index
		end
	end
	return rows
end

local function diagnose_face(seed, face_id, ring, materialized, scan_row)
	local admitted = admitted_by_seed[seed]
	print("  face " .. face_id)
	print("    scan row: class=" .. tostring(scan_row.class) ..
		" station_count=" .. tostring(scan_row.station_count) ..
		" detail=" .. tostring(scan_row.detail))
	local ok, class, detail = pcall(partition.census_face_classify, face_id,
		ring.points)
	if not ok then
		print("    RECOMPOSITION CROSS-CHECK ABORTED: " .. tostring(class))
		return
	end
	print("    recomposed: station_count=" .. #ring.points .. " class=" ..
		tostring(class) .. " detail=" .. tostring(detail))
	if class ~= scan_row.class or #ring.points ~= scan_row.station_count then
		print("    CROSS-CHECK MISMATCH: the recomposed ring does not " ..
			"reproduce the scan row; treat this face's report as unverified")
	end
	for _, row in ipairs(part_summary(ring)) do print(row) end
	local closed = key(ring.points[1]) == key(ring.points[#ring.points])
	print("    closed=" .. tostring(closed))
	local count = #ring.points
	local seen, duplicates = {}, {}
	for index = 1, count - 1 do
		local station_key = key(ring.points[index])
		if seen[station_key] then
			duplicates[#duplicates + 1] = {first = seen[station_key],
				second = index}
		else
			seen[station_key] = index
		end
	end
	local cells, crosses = {}, {}
	for index = 1, count - 1 do
		local a, b = ring.points[index], ring.points[index + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		if math.abs(dx) == 1 and math.abs(dz) == 1 then
			local cell_key = math.min(a.x, b.x) .. ":" .. math.min(a.z, b.z)
			local slope = dx == dz and 1 or -1
			local cell = cells[cell_key]
			if cell and cell.slope ~= slope then
				crosses[#crosses + 1] = {first = cell.index, second = index,
					cell = cell_key}
			end
			if not cell then cells[cell_key] = {index = index, slope = slope} end
		end
	end
	print("    repeated stations: " .. #duplicates ..
		"  opposing cell diagonals: " .. #crosses)
	for entry = 1, #duplicates do
		local violation = duplicates[entry]
		print("    REPEAT #" .. entry .. ": station " ..
			key(ring.points[violation.first]) .. " at ring[" ..
			violation.first .. "] and ring[" .. violation.second .. "]")
		print("      incident segments: [" .. (violation.first - 1) .. "->" ..
			violation.first .. "->" .. (violation.first + 1) .. "] vs [" ..
			(violation.second - 1) .. "->" .. violation.second .. "->" ..
			(violation.second + 1) .. "]")
		print_window(ring, violation.first, materialized, admitted)
		print("      --")
		print_window(ring, violation.second, materialized, admitted)
	end
	for entry = 1, #crosses do
		local violation = crosses[entry]
		print("    X-CROSS #" .. entry .. ": cell " .. violation.cell ..
			" segments [" .. violation.first .. "->" ..
			(violation.first + 1) .. "] vs [" .. violation.second .. "->" ..
			(violation.second + 1) .. "]")
		print_window(ring, violation.first, materialized, admitted)
		print("      --")
		print_window(ring, violation.second, materialized, admitted)
	end
	local dump_path = dump_dir .. "/face-ring-" .. seed .. "-" ..
		face_id:gsub("[^%w_]", "_") .. ".tsv"
	local dump = assert(io.open(dump_path, "wb"))
	dump:write("index\tx\tz\tcontributor\tannotations\n")
	for index = 1, count do
		local point = ring.points[index]
		dump:write(index .. "\t" .. point.x .. "\t" .. point.z .. "\t" ..
			ring.labels[index] .. "\t" ..
			station_annotations(point, materialized, admitted):gsub("^%s+", "")
			.. "\n")
	end
	assert(dump:close())
	print("    ring dumped: " .. dump_path)
end

for argument_index = 4, #arg do
	local seed = arg[argument_index]
	local started = os.clock()
	print("== seed " .. seed .. " ==")
	local admitted = admitted_by_seed[seed]
	if admitted then
		for index = 1, #admitted do
			print("  manifest admission: " .. admitted[index].site ..
				" station " .. admitted[index].x .. ":" .. admitted[index].z)
		end
	end
	local result = partition.census_scan(seed, {scan4 = true})
	if result.stage_reject then
		print("  stage reject: " .. tostring(result.stage_reject.class) ..
			" at " .. tostring(result.stage_reject.site))
	else
		local materialized = boundary.materialize(seed)
		local non_simple = 0
		for _, row in ipairs(result.scan4_faces) do
			if row.class ~= "face_simple_select" then
				print("  scan4 face row: " .. row.id .. " " .. row.class)
			end
			if row.class == "face_non_simple_reject" then
				non_simple = non_simple + 1
				local face = face_source_by_id[row.id]
				local ok, ring = pcall(compose_face, face, result, materialized)
				if ok then
					diagnose_face(seed, row.id, ring, materialized, row)
				else
					print("  face " .. row.id .. " RECOMPOSITION FAILED: " ..
						tostring(ring))
				end
			end
		end
		if non_simple == 0 then
			print("  no face_non_simple_reject rows for this seed")
		end
	end
	print("  seed CPU seconds: " .. string.format("%.1f", os.clock() - started))
end
