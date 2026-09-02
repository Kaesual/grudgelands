-- WP40 T2 whole-gap probe -- the bay-transition-simplicity package, step 3
-- (contracts section 10.3).  Diagnosis only: nothing here writes an artifact
-- row, and the one production touch it relies on is the telemetry-only
-- scan4_whole_observer seam (the tier_mark precedent; worker-KAT digest
-- unchanged is the proof it moved nothing).
--
-- Per seed it runs partition.census_scan with the Scan-4 tiers and captures
-- the Whole tier's own prepared row-run tables through the observer.  It then
-- (a) re-runs partition.census_whole_classify on those tables and requires
-- the g/o/r totals and every per-class interval row to reproduce the scan's
-- retained rows, (b) enumerates every interval itself with the same break
-- machinery and requires the same totals again -- two independent parity
-- proofs before any evidence is read -- and (c) reports every
-- whole_gap_reject interval with its abutting intervals and, per column
-- (the gap columns plus one abutter on each side), the full ownership
-- evidence: exact point-in-polygon class against all 38 composed faces,
-- covering face/water runs, declared seam owners, and every contributor
-- geometry holding the station (final edges, Bank traces, full perimeter
-- spans, perimeter rings, islands).  Excluded-fragment rows that reject are
-- dumped with the same per-column evidence.  Everything is echoed as TSV
-- for the record.
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

local function key_xz(x, z)
	return x .. ":" .. z
end

-- ---------------------------------------------------------------------
-- The probe's own interval enumeration: census_whole_classify's break
-- machinery verbatim, recording every interval with its covering runs and
-- its footprint run instead of aggregating.  Its per-class totals must
-- reproduce the scan's retained rows exactly or the seed's report aborts.
-- ---------------------------------------------------------------------
local function enumerate_intervals(view)
	local intervals = {}
	local class_totals = {}
	local function note(class, z, first, finish)
		local entry = class_totals[class]
		if not entry then
			entry = {intervals = 0, columns = 0}
			class_totals[class] = entry
		end
		entry.intervals = entry.intervals + 1
		entry.columns = entry.columns + (finish - first + 1)
		if not entry.witness then
			entry.witness = "z=" .. z .. ":x=" .. first .. ".." .. finish
		end
	end
	local zs = {}
	for z in pairs(view.footprint_rows) do zs[#zs + 1] = z end
	table.sort(zs)
	for z_index = 1, #zs do
		local z = zs[z_index]
		local footprint_runs = view.footprint_rows[z]
		local face_runs = view.face_rows[z] or {}
		local water_runs = view.water_rows[z] or {}
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
				local class
				if #covering_water >= 1 then
					class = #covering_water > 1 and
						"whole_undeclared_multiplicity_reject" or
						"whole_single_owner_select"
				elseif #covering_faces == 0 then
					class = "whole_gap_reject"
				elseif #covering_faces == 1 then
					class = "whole_single_owner_select"
				else
					-- The direct declared-seam check, then the 11.9
					-- family-C seam inheritance -- the classifier's rule
					-- mirrored (a boundary-boundary two-face column beside
					-- a same-pair declared column inherits), so the parity
					-- proof stays a proof after the 11.9 completion.
					local valid_all = true
					for x = first, finish do
						local owners = view.declared[key_xz(x, z)]
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
						if not valid and #covering_faces == 2 and
								covering_faces[1].class == 0 and
								covering_faces[2].class == 0 and
								covering_faces[1].zone_id ~=
									covering_faces[2].zone_id then
							local zone_a = covering_faces[1].zone_id
							local zone_b = covering_faces[2].zone_id
							local neighbours = {{x - 1, z}, {x + 1, z},
								{x, z - 1}, {x, z + 1}}
							for index = 1, 4 do
								local adjacent = view.declared[key_xz(
									neighbours[index][1], neighbours[index][2])]
								if adjacent and adjacent[zone_a] and
										adjacent[zone_b] then
									local exact_pair = true
									for owner in pairs(adjacent) do
										if owner ~= zone_a and
												owner ~= zone_b then
											exact_pair = false
											break
										end
									end
									if exact_pair then
										valid = true
										break
									end
								end
							end
						end
						if not valid then valid_all = false end
					end
					class = valid_all and "whole_declared_seam_select" or
						"whole_undeclared_multiplicity_reject"
				end
				note(class, z, first, finish)
				intervals[#intervals + 1] = {z = z, first = first,
					finish = finish, class = class, faces = covering_faces,
					water = covering_water, run_first = footprint_run.first,
					run_finish = footprint_run.finish}
			end
		end
	end
	return intervals, class_totals
end

-- ---------------------------------------------------------------------
-- Per-column ownership evidence.
-- ---------------------------------------------------------------------
local function contributors_at(x, z, view, materialized)
	local hits = {}
	for edge_id, stations in pairs(view.final_edges) do
		for index = 1, #stations do
			if stations[index].x == x and stations[index].z == z then
				hits[#hits + 1] = "edge:" .. edge_id .. "#" .. index
			end
		end
	end
	for bank_id, points in pairs(view.bank_points) do
		for index = 1, #points do
			if points[index].x == x and points[index].z == z then
				hits[#hits + 1] = "bank:" .. bank_id .. "#" .. index
			end
		end
	end
	for span_id, span in pairs(view.span_by_id) do
		if span.stations then
			for index = 1, #span.stations do
				if span.stations[index].x == x and
						span.stations[index].z == z then
					hits[#hits + 1] = "span:" .. span_id .. "#" .. index ..
						"(full)"
				end
			end
		end
	end
	for _, row in pairs(materialized.perimeter_by_id) do
		local station_index = row.lookup[key_xz(x, z)]
		if station_index then
			hits[#hits + 1] = "peri:" .. row.source.id .. "#" .. station_index
		end
	end
	for island_id, island in pairs(materialized.island_by_id) do
		for index = 1, #island.stations do
			if island.stations[index].x == x and
					island.stations[index].z == z then
				hits[#hits + 1] = "island:" .. tostring(island_id) ..
					"#" .. index
			end
		end
	end
	table.sort(hits)
	return hits
end

local function exact_face_hits(x, z, view)
	local hits = {}
	for index = 1, #view.composed_faces do
		local face = view.composed_faces[index]
		local class = exact.indexed_polygon_class(
			view.face_indexes[face.id], x, z)
		if class >= 0 then
			hits[#hits + 1] = face.id ..
				(class > 0 and "=inside" or "=boundary")
		end
	end
	table.sort(hits)
	return hits
end

local function runs_covering(runs, x, describe)
	local hits = {}
	if runs then
		for index = 1, #runs do
			local run = runs[index]
			if x >= run.first and x <= run.finish then
				hits[#hits + 1] = describe(run)
			end
		end
	end
	return hits
end

local function describe_face_run(run)
	return run.id .. "[" .. run.first .. ".." .. run.finish .. "]"
end

local function describe_water_run(run)
	return run.owner .. "[" .. run.first .. ".." .. run.finish .. "]"
end

local function join_or_dash(values)
	return #values > 0 and table.concat(values, " ") or "-"
end

local function column_evidence(x, z, view, materialized)
	local declared_owners = {}
	local owners = view.declared[key_xz(x, z)]
	if owners then
		for owner in pairs(owners) do
			declared_owners[#declared_owners + 1] = owner
		end
		table.sort(declared_owners)
	end
	return {
		exact_faces = exact_face_hits(x, z, view),
		face_runs = runs_covering(view.face_rows[z], x, describe_face_run),
		water_runs = runs_covering(view.water_rows[z], x, describe_water_run),
		declared = declared_owners,
		boundary_column = view.boundary_columns[key_xz(x, z)] == true,
		contributors = contributors_at(x, z, view, materialized),
	}
end

local function print_column(role, x, z, evidence)
	print("      col " .. x .. ":" .. z .. " (" .. role .. ")" ..
		(evidence.boundary_column and " [footprint-ring station]" or ""))
	print("        exact faces: " .. join_or_dash(evidence.exact_faces))
	print("        covering face runs: " .. join_or_dash(evidence.face_runs))
	print("        covering water runs: " ..
		join_or_dash(evidence.water_runs))
	print("        declared seam owners: " .. join_or_dash(evidence.declared))
	print("        contributor stations: " ..
		join_or_dash(evidence.contributors))
end

local function nearest_face_text(interval_list, position, direction)
	local this = interval_list[position]
	local walk = position + direction
	while interval_list[walk] and interval_list[walk].z == this.z and
			interval_list[walk].run_first == this.run_first do
		local candidate = interval_list[walk]
		if #candidate.faces > 0 then
			local parts = {}
			for index = 1, #candidate.faces do
				parts[#parts + 1] = describe_face_run(candidate.faces[index])
			end
			return candidate.class .. " x=" .. candidate.first .. ".." ..
				candidate.finish .. " {" .. join_or_dash(parts) .. "}" ..
				" distance=" .. (direction < 0 and
					(this.first - candidate.finish) or
					(candidate.first - this.finish))
		end
		walk = walk + direction
	end
	return "none within the footprint run"
end

local function neighbor_text(interval_list, position, direction)
	local neighbor = interval_list[position + direction]
	local this = interval_list[position]
	if neighbor and neighbor.z == this.z and
			neighbor.run_first == this.run_first then
		local parts = {}
		for index = 1, #neighbor.faces do
			parts[#parts + 1] = describe_face_run(neighbor.faces[index])
		end
		for index = 1, #neighbor.water do
			parts[#parts + 1] = "water:" .. describe_water_run(
				neighbor.water[index])
		end
		return neighbor.class .. " x=" .. neighbor.first .. ".." ..
			neighbor.finish .. " {" .. join_or_dash(parts) .. "}"
	end
	return "footprint-run edge (run x=" .. this.run_first .. ".." ..
		this.run_finish .. ")"
end

local function compare_class_tables(label, expected_rows, actual)
	-- expected_rows: the scan's retained interval rows; actual: a
	-- class -> {intervals, columns, witness} table.
	local failures = {}
	local expected_by_class = {}
	for index = 1, #expected_rows do
		local row = expected_rows[index]
		expected_by_class[row.class] = row
		local entry = actual[row.class]
		if not entry then
			failures[#failures + 1] = row.class .. " missing"
		elseif entry.intervals ~= row.interval_count or
				entry.columns ~= row.column_count or
				entry.witness ~= row.witness then
			failures[#failures + 1] = row.class .. " differs (" ..
				entry.intervals .. "/" .. entry.columns .. "/" ..
				tostring(entry.witness) .. " vs " .. row.interval_count ..
				"/" .. row.column_count .. "/" .. tostring(row.witness) .. ")"
		end
	end
	for class in pairs(actual) do
		if not expected_by_class[class] then
			failures[#failures + 1] = class .. " unexpected"
		end
	end
	if #failures == 0 then
		print("  cross-check " .. label .. ": OK")
		return true
	end
	print("  cross-check " .. label .. " MISMATCH: " ..
		table.concat(failures, "; "))
	return false
end

for argument_index = 4, #arg do
	local seed = arg[argument_index]
	local started = os.clock()
	print("== seed " .. seed .. " ==")
	local view
	local result = partition.census_scan(seed, {scan4 = true,
		scan4_whole_observer = function(v) view = v end})
	if result.stage_reject then
		print("  stage reject: " .. tostring(result.stage_reject.class) ..
			" at " .. tostring(result.stage_reject.site))
	elseif not view then
		local whole = result.scan4_wholes[1]
		print("  WHOLE TIER NOT EVALUATED: " ..
			(whole and tostring(whole.blocking_face) or "no whole row"))
	else
		local whole = result.scan4_wholes[1]
		print("  scan whole row: columns=" .. whole.columns ..
			" planned_water=" .. whole.planned_water_columns ..
			" dry=" .. whole.dry_columns .. " g=" .. whole.g ..
			" o=" .. whole.o .. " r=" .. whole.r .. " m=" .. whole.m)
		for index = 1, #result.scan4_whole_intervals do
			local row = result.scan4_whole_intervals[index]
			print("  scan interval row: " .. row.class .. " intervals=" ..
				row.interval_count .. " columns=" .. row.column_count ..
				" witness=" .. row.witness)
		end

		-- Parity proof 1: the exported classifier re-run on the observed
		-- tables (check absent, so m is out of scope) reproduces the rows.
		local rerun = partition.census_whole_classify({
			footprint_rows = view.footprint_rows,
			face_rows = view.face_rows, water_rows = view.water_rows,
			declared = view.declared})
		local rerun_ok = rerun.g == whole.g and rerun.o == whole.o and
			rerun.r == whole.r and rerun.columns == whole.columns
		if not rerun_ok then
			print("  cross-check classifier-rerun totals MISMATCH: g/o/r/" ..
				"columns " .. rerun.g .. "/" .. rerun.o .. "/" .. rerun.r ..
				"/" .. rerun.columns .. " vs " .. whole.g .. "/" .. whole.o ..
				"/" .. whole.r .. "/" .. whole.columns)
		end
		rerun_ok = compare_class_tables("classifier-rerun rows",
			result.scan4_whole_intervals, rerun.classes) and rerun_ok

		-- Parity proof 2: this probe's own enumeration.
		local intervals, class_totals = enumerate_intervals(view)
		local enumerate_ok = compare_class_tables("probe enumeration",
			result.scan4_whole_intervals, class_totals)

		if not (rerun_ok and enumerate_ok) then
			print("  PARITY FAILED: evidence below is unverified")
		end

		local materialized = boundary.materialize(seed)
		local dump_path = dump_dir .. "/gap-columns-" .. seed .. ".tsv"
		local dump = assert(io.open(dump_path, "wb"))
		dump:write("seed\tgap\trole\tx\tz\texact_faces\tface_runs\t" ..
			"water_runs\tdeclared\tboundary_column\tcontributors\n")
		local function dump_column(gap_number, role, x, z, evidence)
			dump:write(table.concat({seed, gap_number, role, x, z,
				join_or_dash(evidence.exact_faces),
				join_or_dash(evidence.face_runs),
				join_or_dash(evidence.water_runs),
				join_or_dash(evidence.declared),
				tostring(evidence.boundary_column),
				join_or_dash(evidence.contributors)}, "\t") .. "\n")
		end

		local gap_count = 0
		for position = 1, #intervals do
			local interval = intervals[position]
			if interval.class == "whole_gap_reject" then
				gap_count = gap_count + 1
				print("  GAP #" .. gap_count .. ": z=" .. interval.z ..
					" x=" .. interval.first .. ".." .. interval.finish ..
					" (" .. (interval.finish - interval.first + 1) ..
					" column" ..
					(interval.finish > interval.first and "s" or "") .. ")")
				print("    left:  " ..
					neighbor_text(intervals, position, -1))
				print("    right: " .. neighbor_text(intervals, position, 1))
				print("    nearest face left:  " ..
					nearest_face_text(intervals, position, -1))
				print("    nearest face right: " ..
					nearest_face_text(intervals, position, 1))
				for _, vertical in ipairs({{"z-1", interval.z - 1},
						{"z+1", interval.z + 1}}) do
					local faces, water = {}, {}
					for x = interval.first, interval.finish do
						for _, hit in ipairs(runs_covering(
								view.face_rows[vertical[2]], x,
								describe_face_run)) do
							faces[hit] = true
						end
						for _, hit in ipairs(runs_covering(
								view.water_rows[vertical[2]], x,
								describe_water_run)) do
							water[hit] = true
						end
					end
					local parts = {}
					for hit in pairs(faces) do parts[#parts + 1] = hit end
					for hit in pairs(water) do
						parts[#parts + 1] = "water:" .. hit
					end
					table.sort(parts)
					print("    over gap columns at " .. vertical[1] .. ": " ..
						join_or_dash(parts))
				end
				local evidence = column_evidence(interval.first - 1,
					interval.z, view, materialized)
				print_column("left abutter", interval.first - 1, interval.z,
					evidence)
				dump_column(gap_count, "left", interval.first - 1,
					interval.z, evidence)
				for x = interval.first, interval.finish do
					evidence = column_evidence(x, interval.z, view,
						materialized)
					print_column("GAP", x, interval.z, evidence)
					dump_column(gap_count, "gap", x, interval.z, evidence)
				end
				evidence = column_evidence(interval.finish + 1, interval.z,
					view, materialized)
				print_column("right abutter", interval.finish + 1,
					interval.z, evidence)
				dump_column(gap_count, "right", interval.finish + 1,
					interval.z, evidence)
			end
		end
		print("  gap intervals reported: " .. gap_count)

		-- Excluded-fragment obligations: every non-select row dumped with
		-- the same per-column evidence.
		local fragment_classes = {}
		for index = 1, #result.scan4_fragments do
			local row = result.scan4_fragments[index]
			fragment_classes[row.class] = (fragment_classes[row.class] or 0)
				+ 1
		end
		local class_names = {}
		for class in pairs(fragment_classes) do
			class_names[#class_names + 1] = class
		end
		table.sort(class_names)
		local histogram = {}
		for index = 1, #class_names do
			histogram[index] = class_names[index] .. "=" ..
				fragment_classes[class_names[index]]
		end
		print("  fragment rows: " .. #result.scan4_fragments ..
			(#histogram > 0 and (" (" .. table.concat(histogram, " ") .. ")")
				or ""))
		for index = 1, #result.scan4_fragments do
			local row = result.scan4_fragments[index]
			if row.class ~= "fragment_owned_once_select" then
				print("  FRAGMENT " .. row.class .. ": edge=" .. row.edge_id ..
					" station=" .. row.station .. " at " .. row.x .. ":" ..
					row.z .. " land_count=" .. row.land_count ..
					" bank_count=" .. row.bank_count ..
					" terminal_identity=" .. tostring(row.terminal_identity) ..
					" face_count=" .. tostring(row.face_count))
				local evidence = column_evidence(row.x, row.z, view,
					materialized)
				print_column("fragment", row.x, row.z, evidence)
				dump_column("fragment:" .. row.edge_id .. "#" .. row.station,
					"fragment", row.x, row.z, evidence)
			end
		end
		assert(dump:close())
		print("  columns dumped: " .. dump_path)
	end
	print("  seed CPU seconds: " .. string.format("%.1f", os.clock() - started))
end
