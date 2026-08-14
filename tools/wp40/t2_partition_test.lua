local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-partition%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local sha_cache, sha_counter = {}, 0
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	file = assert(io.open(output, "rb"))
	local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close()) assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")

local old_arg = arg
arg = {repo}
dofile(repo .. "/tools/wp43/materials_test.lua")
arg = old_arg
local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
local projection = handoff.project(grug_materials)
local function projection_keys(rows)
	local result = {}
	for index = 1, #rows do
		result[index] = rows[index].key or rows[index]._projection_key
	end
	return result
end
local vocabulary = {resource_keys = projection_keys(projection.resources),
	resource_rows = projection.resources,
	cultural_keys = projection_keys(projection.cultural_materials),
	wood_keys = projection_keys(projection.signature_woods)}

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

-- M1: products are rejected before binary64 can erase a determinant of one.
assert(exact.cross(1, 0, 0, 1) == 1)
expect_error("exact Lua integer range", function()
	exact.cross(134217728, 134217729, 134217729, 134217730,
		"near-one determinant")
end)
expect_error("exact Lua integer range", function()
	exact.segment_distance(2147483647, 2147483647,
		{x = -2147483648, z = -2147483648}, {x = 2147483647, z = 2147483646})
end)
expect_error("exact Lua integer range", function()
	exact.bay_segment(2147483647, 2147483647,
		{x = -2147483648, z = 0, half_width = 360},
		{x = 2147483647, z = 1, half_width = 280}, 0)
end)
expect_error("exact Lua integer range", function()
	exact.ellipse_member(0, 0, {x = 0, z = 0},
		{radius_x = 100000000, radius_z = 100000000})
end)

-- R9 distance branches and unequal positive rationals remain exact before the
-- payload-level owner/component/segment tie hierarchy is exercised below.
local endpoint_n, endpoint_d = exact.segment_distance(-1, 0,
	{x = 0, z = 0}, {x = 1, z = 0})
local body_n, body_d = exact.segment_distance(1, 0,
	{x = 0, z = 0}, {x = 1, z = 1})
assert(endpoint_n == 1 and endpoint_d == 1 and body_n == 1 and body_d == 2 and
	exact.rational_compare(body_n, body_d, endpoint_n, endpoint_d) < 0)

-- M2: one minimum pass and two anchored directions handle a large cycle.
local cycle = {}
for index = 0, 19999 do cycle[#cycle + 1] = {x = index, z = index % 97} end
local reversed = {}
for index = #cycle, 1, -1 do reversed[#reversed + 1] = cycle[index] end
local canonical_cycle = raster.canonical_closed(cycle)
local canonical_reversed = raster.canonical_closed(reversed)
assert(#canonical_cycle == #cycle)
for index = 1, #canonical_cycle do
	assert(canonical_cycle[index].x == canonical_reversed[index].x and
		canonical_cycle[index].z == canonical_reversed[index].z)
end
local function raster_signature(points)
	local result = {}
	for index = 1, #points do
		result[index] = points[index].x .. ":" .. points[index].z
	end
	return table.concat(result, ",")
end
local major_tie = raster.segment({x = 0, z = 0}, {x = 4, z = 2})
assert(raster_signature(major_tie) == "0:0,1:1,2:1,3:2,4:2")
for _, fixture in ipairs({{0, 0, 4, 2}, {0, 0, 2, 4}, {0, 0, -2, 4},
	{0, 0, -4, 2}, {0, 0, -4, -2}, {0, 0, -2, -4},
	{0, 0, 2, -4}, {0, 0, 4, -2}, {0, 0, 4, 4}, {0, 0, -4, 4}}) do
	local forward_octant = raster.segment({x = fixture[1], z = fixture[2]},
		{x = fixture[3], z = fixture[4]})
	local backward_octant = raster.segment({x = fixture[3], z = fixture[4]},
		{x = fixture[1], z = fixture[2]})
	assert(#forward_octant == math.max(math.abs(fixture[3] - fixture[1]),
		math.abs(fixture[4] - fixture[2])) + 1)
	for index = 1, #forward_octant do
		local reverse_index = #backward_octant - index + 1
		assert(forward_octant[index].x == backward_octant[reverse_index].x and
			forward_octant[index].z == backward_octant[reverse_index].z)
	end
end
local joined = raster.final_raster({{x = 0, z = 0}, {x = 4, z = 2},
	{x = 6, z = -2}}, false)
local joint_count = 0
for index = 1, #joined do
	if joined[index].x == 4 and joined[index].z == 2 then joint_count = joint_count + 1 end
end
assert(joint_count == 1 and joined[1].x == 0 and joined[#joined].x == 6)
local seam = raster.final_raster({{x = 0, z = 0}, {x = 3, z = 0},
	{x = 3, z = 3}, {x = 0, z = 3}}, true)
assert(seam[1].x == 0 and seam[1].z == 0 and
	seam[#seam].x == 0 and seam[#seam].z == 1)

-- Indexed polygon lookup is candidate pruning around the same exact predicate.
local indexed_polygon = {{x = -5, z = -3}, {x = 4, z = -1},
	{x = 3, z = 4}, {x = -4, z = 3}, {x = -5, z = -3}}
local exact_index = exact.polygon_index(indexed_polygon)
for x = -7, 6 do for z = -5, 6 do
	assert(exact.indexed_polygon_class(exact_index, x, z) ==
		exact.polygon_class(x, z, indexed_polygon),
		"indexed/slow polygon classification divergence")
end end
assert(exact.indexed_polygon_class(exact_index, -5, -3) == 0 and
	exact.indexed_polygon_class(exact_index, -6, -4) == -1)
expect_error("no repeated terminal", function()
	exact.polygon_class(0, 0, {{x = 0, z = 0}, {x = 2, z = 0},
		{x = 0, z = 2}, {x = 1, z = 1}})
end)
expect_error("zero-length segment", function()
	exact.polygon_index({{x = 0, z = 0}, {x = 2, z = 0}, {x = 2, z = 0},
		{x = 0, z = 2}, {x = 0, z = 0}})
end)
expect_error("not dense", function()
	exact.signed_area2({{x = 0, z = 0}, {x = 2, z = 0}, {x = 0, z = 2},
		{x = 0, z = 0}, extra = true})
end)
expect_error("exact integer range", function()
	exact.polygon_simple({{x = 0, z = 0}, {x = 2147483648, z = 0},
		{x = 0, z = 2}, {x = 0, z = 0}})
end)

-- The four attached race-spine landward controls remain in their own Base Bay
-- at the complete symmetric radius-delta range.  They are ordinary opposite-
-- side clip inputs, not the attachment-side perimeter station A.
local attached_bay_endpoints = {{x = -1050, z = -2250}, {x = 950, z = -2250},
	{x = -970, z = 2260}, {x = 1020, z = 2250}}
for bay_index = 1, #source.bays do
	for _, delta in ipairs({-48, 0, 48}) do
		assert(exact.bay_member(attached_bay_endpoints[bay_index].x,
			attached_bay_endpoints[bay_index].z, source.bays[bay_index],
			{delta, delta, delta}), "attached Bay endpoint fixture drift")
	end
end

-- Wings are strict on both tapered sides and at J. The authored left/right
-- probes are inside on opposite signed sides; the synthetic equality witness
-- proves that a mathematically exact side is dry rather than rounded inward.
local wing_by_bay = {}
for index = 1, #source.bay_closure_wings do
	local wing = source.bay_closure_wings[index]
	wing_by_bay[wing.bay_id] = wing_by_bay[wing.bay_id] or {}
	wing_by_bay[wing.bay_id][#wing_by_bay[wing.bay_id] + 1] = wing
	local dx, dz = exact.vector(wing.head, wing.junction, "wing KAT")
	local left_dx = exact.safe_difference(wing.left_probe.x, wing.head.x,
		"wing left probe")
	local left_dz = exact.safe_difference(wing.left_probe.z, wing.head.z,
		"wing left probe")
	local right_dx = exact.safe_difference(wing.right_probe.x, wing.head.x,
		"wing right probe")
	local right_dz = exact.safe_difference(wing.right_probe.z, wing.head.z,
		"wing right probe")
	assert(exact.wing_member(wing.left_probe.x, wing.left_probe.z, wing) and
		exact.wing_member(wing.right_probe.x, wing.right_probe.z, wing) and
		exact.cross(dx, dz, left_dx, left_dz, "wing left side") > 0 and
		exact.cross(dx, dz, right_dx, right_dz, "wing right side") < 0 and
		not exact.wing_member(wing.junction.x, wing.junction.z, wing))
end
local equality_wing = {head = {x = 0, z = 0}, junction = {x = 4, z = 0},
	head_half_width = 2}
assert(exact.wing_member(0, 1, equality_wing) and
	not exact.wing_member(0, 2, equality_wing) and
	not exact.wing_member(4, 0, equality_wing))
for bay_index = 1, #source.bays do
	local wings = assert(wing_by_bay[source.bays[bay_index].id])
	assert(#wings == 2)
	local min_x = math.min(wings[1].head.x, wings[1].junction.x,
		wings[2].head.x, wings[2].junction.x) - 80
	local max_x = math.max(wings[1].head.x, wings[1].junction.x,
		wings[2].head.x, wings[2].junction.x) + 80
	local min_z = math.min(wings[1].head.z, wings[1].junction.z,
		wings[2].head.z, wings[2].junction.z) - 80
	local max_z = math.max(wings[1].head.z, wings[1].junction.z,
		wings[2].head.z, wings[2].junction.z) + 80
	for x = min_x, max_x do for z = min_z, max_z do
		if exact.wing_member(x, z, wings[1]) and
				exact.wing_member(x, z, wings[2]) and
				not exact.bay_member(x, z, source.bays[bay_index]) then
			error(source.bays[bay_index].id ..
				" closure wings overlap outside Base Bay")
		end
	end end
end

-- H1: exercise both open endpoint normals through the production path.
local no_jitter = {{x = 0, z = 0}, {x = 5, z = 2}}
local definition = {id = "open_endpoint_kat", kind = "land_edge",
	control = {{x = 0, z = 0}, {x = 5, z = 2}}, closed = false,
	noise_domain = "open_endpoint_kat", max_displacement = 0}
local forward = raster.displace(definition, "0", no_jitter)
definition.control = {{x = 5, z = 2}, {x = 0, z = 0}}
local backward = raster.displace(definition, "0", no_jitter)
assert(forward.scalar_samples[1].normal_x_q and
	forward.scalar_samples[#forward.scalar_samples].normal_x_q)
for index = 1, #forward.stations do
	local reverse_index = #backward.stations - index + 1
	assert(forward.stations[index].x == backward.stations[reverse_index].x and
		forward.stations[index].z == backward.stations[reverse_index].z)
end
expect_error("zero-length segment", function()
	raster.segment({x = 0, z = 0}, {x = 0, z = 0})
end)
local collapsed = raster.final_raster({{x = 0, z = 0}, {x = 0, z = 0},
	{x = 2, z = 1}}, false)
assert(#collapsed == 3 and collapsed[1].x == 0 and collapsed[1].z == 0 and
	collapsed[3].x == 2 and collapsed[3].z == 1)
local collapse_word = string.rep(string.char(0, 0, 128, 0), 8)
local collapse_raster = dofile(wp40 .. "/geometry/raster.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	raw_sha256 = function() return collapse_word end})
local production_collapse = collapse_raster.displace({id = "collapse_kat",
	kind = "land_edge", control = {{x = 0, z = 0}, {x = 300, z = 150}},
	closed = false, noise_domain = "collapse_kat", max_displacement = 64},
	"0", {{x = 10000, z = 10000}})
local found_collapse = false
for index = 2, #production_collapse.shifted_controls do
	local a, b = production_collapse.shifted_controls[index - 1],
		production_collapse.shifted_controls[index]
	if a.x == b.x and a.z == b.z then found_collapse = true break end
end
assert(found_collapse and #production_collapse.stations > 0,
	"production displacement collapse fixture drift")
local crossing_definition = {id = "x_cross_kat", kind = "land_edge",
	max_displacement = 0}
expect_error("X-cross", function()
	raster.validate_final(crossing_definition,
		{{x = 0, z = 0}, {x = 1, z = 1}, {x = 0, z = 1}, {x = 1, z = 0}},
		{{x = 0, z = 0}, {x = 1, z = 1}, {x = 0, z = 1}, {x = 1, z = 0}})
end)
expect_error("exits envelope", function()
	raster.validate_final({id = "envelope_kat", kind = "land_edge",
		max_displacement = 0}, {{x = 0, z = 0}},
		{{x = 0, z = 0}, {x = 1, z = 1}})
end)
local ccw = {{x = 0, z = 0}, {x = 1, z = 0}, {x = 1, z = 1},
	{x = 0, z = 1}}
local clockwise = {{x = 0, z = 0}, {x = 0, z = 1}, {x = 1, z = 1},
	{x = 1, z = 0}}
raster.validate_final({id = "ccw_kat", kind = "fixed", closed = true,
	orientation = "counterclockwise", max_displacement = 0}, ccw, ccw)
raster.validate_final({id = "clockwise_kat", kind = "fixed", closed = true,
	orientation = "clockwise", max_displacement = 0}, clockwise, clockwise)
expect_error("not CCW", function()
	raster.validate_final({id = "orientation_corruption", kind = "fixed",
		closed = true, orientation = "counterclockwise", max_displacement = 0},
		clockwise, clockwise)
end)

-- R10 scans every integer ceiling in descending order, including C=0.  A
-- later-valid candidate does not justify binary search or an early reject.
local attempted = {}
local ceiling, marker = raster.topology_ceiling(5, function(candidate)
	attempted[#attempted + 1] = candidate
	return candidate == 3 or candidate == 1, "C" .. candidate
end)
assert(ceiling == 3 and marker == "C3" and table.concat(attempted, ",") == "5,4,3")
attempted = {}
ceiling = raster.topology_ceiling(2, function(candidate)
	attempted[#attempted + 1] = candidate
	return candidate == 0, candidate
end)
assert(ceiling == 0 and table.concat(attempted, ",") == "2,1,0")
attempted = {}
ceiling = raster.topology_ceiling(7, function(candidate)
	attempted[#attempted + 1] = candidate return true, candidate
end)
assert(ceiling == 7 and #attempted == 1)
attempted = {}
ceiling = raster.topology_ceiling(48, function(candidate)
	attempted[#attempted + 1] = candidate return candidate == 41, candidate
end)
-- This is the committed local five-sample clamp fixture, not an assertion
-- about Seed 0's complete Elandor perimeter (whose other stations also
-- participate in its record-wide topology scan).
local local_peak = {39 * deterministic.Q, 40 * deterministic.Q,
	42 * deterministic.Q, 40 * deterministic.Q, 39 * deterministic.Q}
local clamped_peak = {}
for index = 1, #local_peak do
	clamped_peak[index] = deterministic.clamp(local_peak[index],
		-ceiling * deterministic.Q, ceiling * deterministic.Q) / deterministic.Q
end
assert(ceiling == 41 and table.concat(attempted, ",") ==
	"48,47,46,45,44,43,42,41" and table.concat(clamped_peak, ",") ==
	"39,40,41,40,39")
expect_error("C=0 base topology", function()
	raster.topology_ceiling(1, function() return false, "invalid base" end)
end)

local moving_definition = {id = "nonzero_open_reversal", kind = "land_edge",
	control = {{x = -300, z = -100}, {x = 300, z = 100}}, closed = false,
	noise_domain = "nonzero_open_reversal", max_displacement = 32}
local moving_forward = raster.displace(moving_definition, "0",
	{{x = 10000, z = 10000}})
moving_definition.control = {{x = 300, z = 100}, {x = -300, z = -100}}
local moving_backward = raster.displace(moving_definition, "0",
	{{x = 10000, z = 10000}})
local moving_nonzero = false
for index = 1, #moving_forward.scalar_samples do
	if moving_forward.scalar_samples[index].scalar_q ~= 0 then moving_nonzero = true end
end
assert(moving_nonzero and
	moving_forward.topology_ceiling_nodes == moving_backward.topology_ceiling_nodes)
for index = 1, #moving_forward.stations do
	local reverse_index = #moving_backward.stations - index + 1
	assert(moving_forward.stations[index].x == moving_backward.stations[reverse_index].x and
		moving_forward.stations[index].z == moving_backward.stations[reverse_index].z)
end

local closed_control = {{x = -400, z = -400}, {x = 400, z = -400},
	{x = 400, z = 400}, {x = -400, z = 400}}
local function moving_closed(control, orientation)
	return raster.displace({id = "closed_rotation_reversal", kind = "mainland_coast",
		control = control, closed = true, orientation = orientation,
		noise_domain = "closed_rotation_reversal", max_displacement = 16,
		envelope = source.constants.mainland_frame}, "0", {{x = 10000, z = 10000}})
end
local closed_forward = moving_closed(closed_control, "counterclockwise")
local closed_rotated = moving_closed({closed_control[3], closed_control[4],
	closed_control[1], closed_control[2]}, "counterclockwise")
local closed_reversed = moving_closed({closed_control[1], closed_control[4],
	closed_control[3], closed_control[2]}, "clockwise")
local canonical_forward = raster.canonical_closed(closed_forward.stations)
for _, result in ipairs({closed_rotated, closed_reversed}) do
	local canonical_result = raster.canonical_closed(result.stations)
	assert(result.topology_ceiling_nodes == closed_forward.topology_ceiling_nodes and
		#canonical_result == #canonical_forward)
	for index = 1, #canonical_forward do
		assert(canonical_result[index].x == canonical_forward[index].x and
			canonical_result[index].z == canonical_forward[index].z)
	end
end

local function geometry_signature(rows, field)
	local parts = {}
	for row_index = 1, #rows do
		parts[#parts + 1] = rows[row_index].id
		local points = rows[row_index][field]
		for point_index = 1, #points do
			parts[#parts + 1] = points[point_index].x .. ":" .. points[point_index].z
		end
	end
	return table.concat(parts, "\n")
end
local source_land_signature = geometry_signature(source.land_edges, "control")
local source_route_signature = geometry_signature(source.routes, "centreline")
local source_bytes_before = canonical.encode(
	source_validator.canonicalize_source(source, canonical))
local land_source_by_id, effective_land_control, derived_departure_by_edge = {}, {}, {}
for index = 1, #source.land_edges do
	land_source_by_id[source.land_edges[index].id] = source.land_edges[index]
end
assert(#source.junction_departures == 4)
for index = 1, #source.junction_departures do
	local departure = source.junction_departures[index]
	local edge = assert(land_source_by_id[departure.edge_id])
	assert(not effective_land_control[edge.id])
	local from = departure.edge_endpoint == "from"
	local junction_index = from and 1 or #edge.control
	local adjacent_index = from and 2 or #edge.control - 1
	local junction, adjacent = edge.control[junction_index], edge.control[adjacent_index]
	assert(junction.x ~= adjacent.x and junction.z ~= adjacent.z)
	local derived = {x = exact.safe_sum(junction.x,
		adjacent.x > junction.x and 1 or -1, departure.id .. " test x"),
		z = exact.safe_sum(junction.z, adjacent.z > junction.z and 1 or -1,
			departure.id .. " test z")}
	assert(math.abs(derived.x - junction.x) == 1 and
		math.abs(derived.z - junction.z) == 1)
	for control_index = 1, #edge.control do
		assert(edge.control[control_index].x ~= derived.x or
			edge.control[control_index].z ~= derived.z,
			"derived D already exists in original Source control")
	end
	local control = {}
	for control_index = 1, #edge.control do
		control[control_index] = {x = edge.control[control_index].x,
			z = edge.control[control_index].z}
	end
	if from then table.insert(control, 2, derived)
	else table.insert(control, #control, derived) end
	effective_land_control[edge.id] = control
	derived_departure_by_edge[edge.id] = {source = departure, point = derived}
end

local function deep_equal(a, b, seen)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	seen = seen or {}
	if seen[a] then return seen[a] == b end
	seen[a] = b
	for key, value in pairs(a) do
		if not deep_equal(value, b[key], seen) then return false end
	end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

local compiler = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	raster = raster, raw_sha256 = raw_sha256, source = source,
	source_validator = source_validator, vocabulary = vocabulary})
if arg[3] ~= nil then
	assert(arg[3] == "selected_stage2_blocked" and arg[4] == nil,
		"unknown T2 partition focused mode")
	do
		local fixture = dofile(repo ..
			"/tools/wp40/fixtures/t2_extreme_e0/selected_stage2_blocked.lua")
		local gate = dofile(repo ..
			"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua")
		local function closed(value, names, label)
			assert(type(value) == "table" and getmetatable(value) == nil, label)
			local allowed, count = {}, 0
			for index = 1, #names do allowed[names[index]] = true end
			for name in pairs(value) do assert(allowed[name], label .. " has an extra field")
				count = count + 1 end
			assert(count == #names, label .. " has a missing field")
		end
		closed(fixture, {"schema", "status", "scope", "stage2_status",
			"measurement_commit", "measurement_tree", "authority_dag_sha256",
			"conformance_commit", "conformance_tree", "conformance_dag_sha256",
			"artifact_sha256", "manifest_sha256", "candidate_rows_sha256",
			"interpreter_id", "interpreter_path", "interpreter_version",
			"interpreter_sha256", "source_checksum", "boundary_policy_checksum",
			"partition_sha256", "cases"},
			"selected Stage-2 blocker fixture")
		assert(fixture.schema == "grug_wp40_extreme_selected_stage2_blocked_v1" and
			fixture.status == "selected_stage2_blocked" and
			fixture.scope == "T2C_E0_SELECTED_STAGE2_NEGATIVE_WITNESS_ONLY" and
			fixture.stage2_status == "blocked_without_fallback" and #fixture.cases == 2 and
			fixture.measurement_commit == gate.measurement_commit and
			fixture.measurement_tree == gate.measurement_tree and
			fixture.authority_dag_sha256 == gate.authority_dag_sha256 and
			fixture.artifact_sha256 == gate.artifact_sha256 and
			fixture.manifest_sha256 == gate.manifest_sha256 and
			fixture.candidate_rows_sha256 == gate.candidate_rows_sha256 and
			fixture.source_checksum == source_validator.EXPECTED_SOURCE_CHECKSUM and
			fixture.boundary_policy_checksum ==
				source_validator.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM and
			fixture.partition_sha256 == gate.partition_sha256)
		local expected_provenance = {
			conformance_commit = "5a2fc0d49276b7cded481fb9758782af967e2b0a",
			conformance_tree = "0f81de16572753a5d1b34959b38168d47c592e41",
			conformance_dag_sha256 =
				"086855378ed15a5781d57335308f9ff62e6731e376c4cca8591bee4337478d6c",
			manifest_sha256 =
				"23b909d2b4d30ccffce3c09b9a1a987ffe1123136583fe409377a27fd0649a52",
			interpreter_id = "puc_lua51",
			interpreter_path = repo .. "/tools/bin/lua51",
			interpreter_version =
				"Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio",
			interpreter_sha256 =
				"a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f",
		}
		local function validate_provenance(value)
			for name, expected in pairs(expected_provenance) do
				assert(value[name] == expected,
					"selected Stage-2 blocker " .. name .. " changed")
			end
		end
		validate_provenance(fixture)
		for name in pairs(expected_provenance) do
			local corrupt = {}
			for field, value in pairs(fixture) do corrupt[field] = value end
			corrupt[name] = (corrupt[name]:sub(1, 1) == "0" and "1" or "0") ..
				corrupt[name]:sub(2)
			assert(not pcall(validate_provenance, corrupt),
				"selected Stage-2 blocker accepted corrupt " .. name)
		end
		local conformance_authority = dofile(repo ..
			"/tools/wp40/t2_extreme_conformance_authority.lua")({
				raw_sha256 = raw_sha256})
		assert(conformance_authority.validate_provenance(repo, scratch, {
			commit = fixture.conformance_commit, tree = fixture.conformance_tree}))
		assert(conformance_authority.capture_git(repo, scratch,
			fixture.conformance_commit).dag_sha256 == fixture.conformance_dag_sha256,
			"selected Stage-2 blocker conformance commit/DAG changed")
		local function read_evidence(path)
			local file = assert(io.open(path, "rb"))
			local bytes = assert(file:read("*a"))
			assert(file:close())
			return bytes
		end
		assert(raw_sha256(read_evidence(repo ..
			"/tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv")) ==
			from_hex(fixture.manifest_sha256),
			"selected Stage-2 blocker manifest bytes changed")
		assert(raw_sha256(read_evidence(fixture.interpreter_path)) ==
			from_hex(fixture.interpreter_sha256),
			"selected Stage-2 blocker PUC interpreter bytes changed")
		local function validate_cases(value)
			closed(value, {1, 2}, "selected Stage-2 blocker cases")
		end
		validate_cases(fixture.cases)
		for _, mutation in ipairs({"extra", "zero", "hole", "metatable"}) do
			local corrupt = {}
			for index, value in pairs(fixture.cases) do corrupt[index] = value end
			if mutation == "extra" then corrupt[3] = fixture.cases[1]
			elseif mutation == "zero" then corrupt[0] = fixture.cases[1]
			elseif mutation == "hole" then corrupt[2] = nil
			else setmetatable(corrupt, {}) end
			assert(not pcall(validate_cases, corrupt),
				"selected Stage-2 blocker accepted " .. mutation .. " cases")
		end
		local partition_file = assert(io.open(wp40 .. "/geometry/partition.lua", "rb"))
		local partition_bytes = assert(partition_file:read("*a"))
		assert(partition_file:close())
		assert(raw_sha256(partition_bytes) == from_hex(fixture.partition_sha256),
			"selected Stage-2 blocker partition pin changed")
		local expected_slots = {29, 30}
		for index = 1, #fixture.cases do
			local row = fixture.cases[index]
			local winner = assert(gate.winners[row.slot - 27])
			assert(winner.slot == row.slot and winner.candidate_index == row.candidate_index and
				winner.decimal == row.seed, "selected Stage-2 blocker is not an artifact winner")
			if row.kind == "invalid_aperture_bank_start" then
				closed(row, {"slot", "candidate_index", "seed", "kind", "bank_id",
					"aperture_id", "aperture_side", "transition_id", "diagnostic"},
					"selected aperture blocker")
				local bank
				for source_index = 1, #source.bay_bank_components do
					if source.bay_bank_components[source_index].id == row.bank_id then
						bank = source.bay_bank_components[source_index] break
					end
				end
				assert(bank and bank.start_terminal.kind == "aperture_dry" and
					bank.start_terminal.aperture_id == row.aperture_id and
					bank.start_terminal.side == row.aperture_side and
					bank.end_terminal.kind == "land_edge_transition" and
					"bay_edge_transition:" .. bank.end_terminal.edge_id .. ":" ..
						bank.end_terminal.edge_endpoint == row.transition_id)
			else
				assert(row.kind == "second_retained_land_run")
				closed(row, {"slot", "candidate_index", "seed", "kind", "edge_id",
					"transition_id", "attachment_id", "diagnostic"},
					"selected retained-run blocker")
				local transition, attachment
				for source_index = 1, #source.bay_edge_transitions do
					local value = source.bay_edge_transitions[source_index]
					if value.id == row.transition_id then transition = value break end
				end
				for source_index = 1, #source.perimeter_attachments do
					local value = source.perimeter_attachments[source_index]
					if value.id == row.attachment_id then attachment = value break end
				end
				assert(transition and transition.edge_id == row.edge_id and
					transition.edge_endpoint == "from" and attachment and
					attachment.edge_id == row.edge_id and attachment.edge_endpoint == "to" and
					attachment.retained_run == "prefix")
			end
			assert(row.slot == expected_slots[index] and type(row.seed) == "string" and
				type(row.candidate_index) == "number" and type(row.diagnostic) == "string")
			local ok, diagnostic = pcall(compiler.compile, row.seed)
			assert(not ok and tostring(diagnostic) == row.diagnostic,
				"selected Stage-2 blocker diagnostic changed: " .. tostring(diagnostic))
		end
		local corrupt = {}
		for name, value in pairs(fixture) do corrupt[name] = value end
		corrupt.extra = true
		local ok = pcall(closed, corrupt, {"schema", "status", "scope",
			"stage2_status", "measurement_commit", "measurement_tree",
			"authority_dag_sha256", "conformance_commit", "conformance_tree",
			"conformance_dag_sha256", "artifact_sha256", "manifest_sha256",
			"candidate_rows_sha256", "interpreter_id", "interpreter_path",
			"interpreter_version", "interpreter_sha256", "source_checksum",
			"boundary_policy_checksum", "partition_sha256", "cases"},
			"selected Stage-2 blocker fixture")
		assert(not ok, "selected Stage-2 blocker fixture accepted an extra field")
		print("WP40 T2 selected Stage-2 blockers reproduced exactly slots=29/30 " ..
			"status=blocked_without_fallback")
	end
	return
end
local compiled = compiler.compile("0")
local fresh_source = dofile(wp40 .. "/source/catalog.lua")
assert(deep_equal(source, fresh_source), "partition compiler mutated Source")
assert(source_bytes_before == canonical.encode(
	source_validator.canonicalize_source(source, canonical)) and
	source_bytes_before == canonical.encode(
		source_validator.canonicalize_source(fresh_source, canonical)),
	"partition compiler changed canonical whole-Source bytes")
assert(source_land_signature == geometry_signature(source.land_edges, "control") and
	source_route_signature == geometry_signature(source.routes, "centreline") and
	source_land_signature == geometry_signature(fresh_source.land_edges, "control") and
	source_route_signature == geometry_signature(fresh_source.routes, "centreline"))
assert(#compiled.families.land_boundaries == 61)
assert(#compiled.families.perimeters == 3)
assert(#compiled.families.bays == 4)
assert(#compiled.families.mouth_apertures == 4)
assert(#compiled.families.closure_wings == 8)
assert(#compiled.families.dry_faces == 38)
assert(#compiled.families.coast_shelf == 22)
assert(#compiled.families.islands == 2)
assert(#compiled.families.channels == 2)

-- Independently rebuild the checksum-declared no-jitter set and all 61
-- seed-selected R7/effective-control rasters.  These are the objects gated by
-- R13 before the later dry partition/attachment clip.
local independent_no_jitter, independent_no_jitter_seen = {}, {}
local function add_independent_no_jitter(point)
	if type(point) == "table" and type(point.x) == "number" and
			type(point.z) == "number" then
		local point_key = point.x .. ":" .. point.z
		if not independent_no_jitter_seen[point_key] then
			independent_no_jitter_seen[point_key] = true
			independent_no_jitter[#independent_no_jitter + 1] =
				{x = point.x, z = point.z}
		end
	end
end
local function add_independent_collection(collection, field)
	for index = 1, #collection do
		local values = collection[index][field]
		if values then
			for point_index = 1, #values do add_independent_no_jitter(values[point_index]) end
		end
	end
end
add_independent_collection(source.land_edges, "control")
add_independent_collection(source.perimeters, "polygon")
add_independent_collection(source.bays, "centreline")
add_independent_collection(source.islands, "polygon")
add_independent_collection(source.channels, "polygon")
add_independent_collection(source.routes, "centreline")
add_independent_collection(source.island_routes, "centreline")
add_independent_collection(source.hydrology, "centreline")
add_independent_collection(source.housing_masks, "polygon")
for spur_index = 1, #source.poi_spurs do
	for path_index = 1, #source.poi_spurs[spur_index].candidate_paths do
		local path = source.poi_spurs[spur_index].candidate_paths[path_index]
		for point_index = 1, #path do add_independent_no_jitter(path[point_index]) end
	end
end
for arc_index = 1, #source.face_arcs do
	for component_index = 1, #source.face_arcs[arc_index].authority_components do
		local component = source.face_arcs[arc_index].authority_components[component_index]
		if component.kind == "literal_arc" then
			for point_index = 1, #component.control do
				add_independent_no_jitter(component.control[point_index])
			end
		end
	end
end
for _, collection in ipairs({source.route_interfaces, source.island_route_interfaces}) do
	for index = 1, #collection do add_independent_no_jitter(collection[index].position) end
end
for index = 1, #source.anchors do
	if source.anchors[index].placement_mode == "fixed" then
		add_independent_no_jitter(source.anchors[index].position)
	end
end
local independent_holy = source.constants.holy_grounds
for _, x in ipairs({independent_holy.min_x, independent_holy.max_x}) do
	for _, z in ipairs({independent_holy.min_z, independent_holy.max_z}) do
		add_independent_no_jitter({x = x, z = z})
	end
end
for index = 1, #source.constants.holy_junction_x do
	local x = source.constants.holy_junction_x[index]
	add_independent_no_jitter({x = x, z = independent_holy.min_z})
	add_independent_no_jitter({x = x, z = independent_holy.max_z})
end
for _, departure in pairs(derived_departure_by_edge) do
	add_independent_no_jitter(departure.point)
end
table.sort(independent_no_jitter, function(a, b)
	return a.x < b.x or a.x == b.x and a.z < b.z
end)
local function materialize_selected_r7(seed)
	local by_edge_id = {}
	for index = 1, #source.land_edges do
		local edge = source.land_edges[index]
		by_edge_id[edge.id] = raster.displace({id = edge.id,
			kind = "land_edge", control = effective_land_control[edge.id] or edge.control,
			closed = false, noise_domain = edge.noise_domain,
			max_displacement = edge.max_displacement}, seed, independent_no_jitter)
	end
	return by_edge_id
end
local selected_r7_edge_by_id = materialize_selected_r7("0")

local function by_id(rows, id)
	for index = 1, #rows do if rows[index].id == id then return rows[index] end end
	error("missing compiled record " .. id)
end
local function signed_array(row, name)
	for index = 1, #row.signed_arrays do
		if row.signed_arrays[index].name == name then return row.signed_arrays[index].values end
	end
	error("missing signed array " .. name)
end
local function named_scalar(row, field, name)
	for index = 1, #row[field] do
		if row[field][index].name == name then return row[field][index].value end
	end
	error("missing " .. field .. " " .. name)
end
local function maybe_named_scalar(row, field, name)
	for index = 1, #row[field] do
		if row[field][index].name == name then return row[field][index].value end
	end
end
local function named_array_value(row, field, name)
	for index = 1, #row[field] do
		if row[field][index].name == name then return row[field][index].values end
	end
	error("missing " .. field .. " " .. name)
end

-- R12 materializes the 20 canonical Banks once in Bay payloads and every
-- incident dry face consumes an alias-free byte-identical defensive copy.
local function extract_bank_payload(compiled_value)
	local payload, expected_count = {}, 0
	for bay_index = 1, #compiled_value.families.bays do
	local bay = compiled_value.families.bays[bay_index]
	local ids = named_array_value(bay, "text_arrays", "bank_component_ids")
	local offsets = named_array_value(bay, "unsigned_arrays", "bank_station_offsets")
	local counts = named_array_value(bay, "unsigned_arrays", "bank_station_counts")
	local values = signed_array(bay, "bank_stations_xz")
	assert(#ids == 5 and #offsets == 5 and #counts == 5)
	local running = 0
	for index = 1, 5 do
		assert(offsets[index] == running and not payload[ids[index]])
		local part = {}
		for station = 1, counts[index] do
			local offset = (running + station - 1) * 2
			part[#part + 1] = values[offset + 1]
			part[#part + 1] = values[offset + 2]
			if station > 1 then
				assert(math.max(math.abs(part[#part - 1] - part[#part - 3]),
					math.abs(part[#part] - part[#part - 2])) == 1)
			end
		end
		payload[ids[index]] = part
		running = running + counts[index]
		expected_count = expected_count + 1
	end
	assert(#values == running * 2)
end
	return payload, expected_count
end
local bank_payload, expected_bank_count = extract_bank_payload(compiled)
assert(expected_bank_count == 20)
for index = 1, #source.bay_bank_components do
	assert(bank_payload[source.bay_bank_components[index].id])
end
local face_bank_uses = 0
for face_index = 1, #compiled.families.dry_faces do
	local face = compiled.families.dry_faces[face_index]
	local ids = named_array_value(face, "text_arrays", "bank_component_ids")
	local offsets = named_array_value(face, "unsigned_arrays", "bank_station_offsets")
	local counts = named_array_value(face, "unsigned_arrays", "bank_station_counts")
	local values = signed_array(face, "bank_stations_xz")
	local running = 0
	for index = 1, #ids do
		local expected = assert(bank_payload[ids[index]])
		assert(offsets[index] == running and #expected == counts[index] * 2)
		for value_index = 1, #expected do
			assert(values[running * 2 + value_index] == expected[value_index])
		end
		running = running + counts[index]
		face_bank_uses = face_bank_uses + 1
	end
	assert(#values == running * 2)
end
assert(face_bank_uses == 20)

-- A reverse consumer reverses only the frozen bytes; it never resolves or
-- traces a second shape.
for id, values in pairs(bank_payload) do
	local points = {}
	for index = 1, #values, 2 do
		points[#points + 1] = {x = values[index], z = values[index + 1]}
	end
	local reversed = compiler.reverse_materialized(points)
	assert(#reversed == #points)
	for index = 1, #points do
		assert(reversed[index].x == points[#points - index + 1].x and
			reversed[index].z == points[#points - index + 1].z, id)
	end
end

local function payload_bay_member(row, x, z)
	local centreline = named_array_value(row, "signed_arrays",
		"centreline_xz_width")
	local deltas = named_array_value(row, "signed_arrays", "station_radius_delta")
	local delta_offset = 0
	for segment_index = 1, #centreline / 3 - 1 do
		local offset = (segment_index - 1) * 3
		local a = {x = centreline[offset + 1], z = centreline[offset + 2],
			half_width = centreline[offset + 3]}
		local b = {x = centreline[offset + 4], z = centreline[offset + 5],
			half_width = centreline[offset + 6]}
		local stations = raster.segment(a, b)
		local nearest, nearest_distance
		for station_index = 1, #stations do
			local dx = exact.safe_difference(x, stations[station_index].x,
				"Bay payload projection")
			local dz = exact.safe_difference(z, stations[station_index].z,
				"Bay payload projection")
			local distance = exact.safe_sum(exact.safe_square(dx,
				"Bay payload projection"), exact.safe_square(dz,
				"Bay payload projection"), "Bay payload projection")
			if not nearest_distance or distance < nearest_distance then
				nearest, nearest_distance = station_index, distance
			end
		end
		if exact.bay_segment(x, z, a, b, deltas[delta_offset + nearest]) then
			return true
		end
		delta_offset = delta_offset + #stations
	end
	assert(delta_offset == #deltas)
	return false
end

-- Mouth payload remains canonical-only.  The authored Bank terminal order is
-- rederived here from Source plus the final canonical perimeter bytes, never
-- copied through the mouth-aperture family.
local mouth_field_roster = {
	text_values = {"bay_id", "perimeter_id"}, signed_values = {},
	unsigned_values = {"analytic_width", "finish", "first", "station_count"},
	boolean_values = {}, text_arrays = {}, signed_arrays = {"endpoints_xz"},
	unsigned_arrays = {}}
local function validate_mouth_field_roster(aperture)
	for _, field in ipairs({"text_values", "signed_values", "unsigned_values",
			"boolean_values", "text_arrays", "signed_arrays", "unsigned_arrays"}) do
		local expected = mouth_field_roster[field]
		if #aperture[field] ~= #expected then
			error("mouth aperture " .. field .. " roster changed")
		end
		for index = 1, #expected do
			if aperture[field][index].name ~= expected[index] then
				error("mouth aperture " .. field .. " roster changed")
			end
		end
	end
	return true
end
for index = 1, #compiled.families.mouth_apertures do
	assert(validate_mouth_field_roster(compiled.families.mouth_apertures[index]))
end
local function mouth_roster_corruption(field, name, value)
	local source_row = compiled.families.mouth_apertures[1]
	local corrupted = {}
	for key, row_value in pairs(source_row) do corrupted[key] = row_value end
	corrupted[field] = {}
	for index = 1, #source_row[field] do
		corrupted[field][index] = source_row[field][index]
	end
	corrupted[field][#corrupted[field] + 1] = {name = name, value = value,
		values = {value}}
	expect_error("mouth aperture " .. field .. " roster changed", function()
		validate_mouth_field_roster(corrupted)
	end)
end
mouth_roster_corruption("text_values", "bank_terminal_order", "authored")
mouth_roster_corruption("unsigned_values", "bank_first", 0)
mouth_roster_corruption("signed_arrays", "bank_dry_terminals_xz", 0)

local perimeter_source_by_id, bay_source_by_id = {}, {}
for index = 1, #source.perimeters do
	perimeter_source_by_id[source.perimeters[index].id] = source.perimeters[index]
end
for index = 1, #source.bays do bay_source_by_id[source.bays[index].id] = source.bays[index] end
local function final_authored_perimeter(payload, authored)
	local values = signed_array(payload, "stations_xz")
	local count = named_scalar(payload, "unsigned_values", "station_count")
	assert(#values == (count + 1) * 2 and values[1] == values[#values - 1] and
		values[2] == values[#values])
	local ring = {}
	for index = 1, count do
		ring[index] = {x = values[index * 2 - 1], z = values[index * 2]}
	end
	local closed = {}
	for index = 1, #ring do closed[index] = ring[index] end
	closed[#closed + 1] = {x = ring[1].x, z = ring[1].z}
	local area = exact.signed_area2(closed)
	local wants_positive = authored.orientation == "counterclockwise"
	assert(wants_positive or authored.orientation == "clockwise")
	if (area > 0) ~= wants_positive then
		local reversed = {}
		for index = #ring, 1, -1 do reversed[#reversed + 1] = ring[index] end
		ring = reversed
	end
	local anchor, anchor_count = nil, 0
	for index = 1, #ring do
		if ring[index].x == authored.polygon[1].x and
				ring[index].z == authored.polygon[1].z then
			anchor, anchor_count = index, anchor_count + 1
		end
	end
	assert(anchor_count == 1)
	local result = {}
	for offset = 0, #ring - 1 do
		local index = ((anchor + offset - 1) % #ring) + 1
		result[#result + 1] = {x = ring[index].x, z = ring[index].z}
	end
	return result
end

local function derive_authored_apertures(compiled_value)
	local result, divergences = {}, 0
	for index = 1, #source.bay_mouth_apertures do
	local authored = source.bay_mouth_apertures[index]
	local aperture = by_id(compiled_value.families.mouth_apertures, authored.id)
	local perimeter = by_id(compiled_value.families.perimeters, authored.perimeter_id)
	local perimeter_source = assert(perimeter_source_by_id[authored.perimeter_id])
	local authored_points = final_authored_perimeter(perimeter, perimeter_source)
	local bay_payload = by_id(compiled_value.families.bays, authored.bay_id)
	local bay_source = assert(bay_source_by_id[authored.bay_id])
	local mouth = bay_source.centreline[authored.mouth_sample_index]
	local mouth_index
	for station_index = 1, #authored_points do
		if authored_points[station_index].x == mouth.x and
				authored_points[station_index].z == mouth.z then mouth_index = station_index end
	end
	assert(mouth_index)
	local first, last = mouth_index, mouth_index
	while first > 1 and payload_bay_member(bay_payload,
			authored_points[first - 1].x, authored_points[first - 1].z) do first = first - 1 end
	while last < #authored_points and payload_bay_member(bay_payload,
			authored_points[last + 1].x, authored_points[last + 1].z) do last = last + 1 end
	assert(first > 2 and last < #authored_points - 1)
	for station_index = 1, #authored_points do
		if station_index < first or station_index > last then
			assert(not payload_bay_member(bay_payload, authored_points[station_index].x,
				authored_points[station_index].z))
		end
	end
	local derived = {before = {point = authored_points[first - 1],
		away = authored_points[first - 2]}, after = {point = authored_points[last + 1],
		away = authored_points[last + 2]}}
	result[authored.id] = derived
	local perimeter_values = signed_array(perimeter, "stations_xz")
	local canonical_first = named_scalar(aperture, "unsigned_values", "first")
	local canonical_finish = named_scalar(aperture, "unsigned_values", "finish")
	local canonical_dry = {perimeter_values[canonical_first * 2 - 1],
		perimeter_values[canonical_first * 2],
		perimeter_values[canonical_finish * 2 + 1],
		perimeter_values[canonical_finish * 2 + 2]}
	if derived.before.point.x ~= canonical_dry[1] or
			derived.before.point.z ~= canonical_dry[2] or
			derived.after.point.x ~= canonical_dry[3] or
			derived.after.point.z ~= canonical_dry[4] then
		divergences = divergences + 1
	end
end
	return result, divergences
end
local authored_aperture_by_id, aperture_order_divergences =
	derive_authored_apertures(compiled)
assert(aperture_order_divergences > 0)
for index = 1, #source.bay_bank_components do
	local bank = source.bay_bank_components[index]
	local values = assert(bank_payload[bank.id])
	for _, binding in ipairs({{terminal = bank.start_terminal, endpoint = "start"},
			{terminal = bank.end_terminal, endpoint = "finish"}}) do
		if binding.terminal.kind == "aperture_dry" then
			local derived = assert(authored_aperture_by_id[
				binding.terminal.aperture_id])[binding.terminal.side]
			local x_index = binding.endpoint == "start" and 1 or #values - 1
			assert(values[x_index] == derived.point.x and
				values[x_index + 1] == derived.point.z and
				math.max(math.abs(derived.away.x - derived.point.x),
					math.abs(derived.away.z - derived.point.z)) == 1)
		end
	end
end
local hearthpine = assert(bank_payload["bay_bank:elandor_west:hearthpine"])
local ew_authored = authored_aperture_by_id["bay_mouth_aperture:elandor_west"].before
assert(hearthpine[1] == ew_authored.point.x and hearthpine[2] == ew_authored.point.z)
-- Production stops at the first terminal-reachable successor and exports no
-- redundant branch truth graph.  This independently reviewed deep witness
-- freezes the two ordered admissible successors A/B as reachable; A must be
-- selected.  B then joins A's selected suffix at the immediately following
-- station, so the alternate reaches the same terminal without a second
-- production traversal.
local previous = {-1320, -2833}
local current = {-1319, -2832}
local successor_a = {-1319, -2831}
local successor_b = {-1320, -2831}
local convergence = {-1321, -2830}
local branch_index
for index = 1, #hearthpine - 8, 2 do
	if hearthpine[index] == previous[1] and hearthpine[index + 1] == previous[2] and
			hearthpine[index + 2] == current[1] and
			hearthpine[index + 3] == current[2] and
			hearthpine[index + 4] == successor_a[1] and
			hearthpine[index + 5] == successor_a[2] and
			hearthpine[index + 6] == successor_b[1] and
			hearthpine[index + 7] == successor_b[2] and
			hearthpine[index + 8] == convergence[1] and
			hearthpine[index + 9] == convergence[2] then
		branch_index = index
		break
	end
end
assert(branch_index and branch_index > 1,
	"R12 Hearthpine first-reachable deep branch changed")
local hearthpine_points = {}
for index = 1, #hearthpine, 2 do
	hearthpine_points[#hearthpine_points + 1] = hearthpine[index] .. ":" ..
		hearthpine[index + 1]
end
local hearthpine_bytes = table.concat(hearthpine_points, ",")
assert(#hearthpine_points == 728 and raw_sha256(hearthpine_bytes) ==
	from_hex("6b3e47c40a3288fb60f189c99685b316c994c4afb63c67973778d7aab82cdef9"),
	"R12 Hearthpine A-first selected path changed")

-- Rebuild the local predicates from Source plus normalized payload, rather
-- than accepting branch evidence produced by the compiler under test.
local function oracle_key(x, z) return x .. ":" .. z end
local function payload_points(record_value, array_name)
	local values = signed_array(record_value, array_name)
	local points = {}
	for index = 1, #values, 2 do
		points[#points + 1] = {x = values[index], z = values[index + 1]}
	end
	return points
end
local oracle_cardinal = {{x = 1, z = 0}, {x = 0, z = -1},
	{x = -1, z = 0}, {x = 0, z = 1}}
local function build_independent_oracle_world(compiled_value)
	local mainland_indices = {}
	for index = 1, 2 do
		mainland_indices[index] = exact.polygon_index(payload_points(
			compiled_value.families.perimeters[index], "stations_xz"))
	end
	local island_indices = {}
	for index = 1, #compiled_value.families.islands do
		island_indices[index] = exact.polygon_index(payload_points(
			compiled_value.families.islands[index], "stations_xz"))
	end
	local footprint_cache = {}
	local function oracle_footprint_class(x, z)
	local point_key = oracle_key(x, z)
	if footprint_cache[point_key] ~= nil then return footprint_cache[point_key] end
	for index = 1, 2 do
		local class = exact.indexed_polygon_class(mainland_indices[index], x, z)
		if class >= 0 then footprint_cache[point_key] = class return class end
	end
	local holy = source.constants.holy_grounds
	if x >= holy.min_x and x <= holy.max_x and z >= holy.min_z and z <= holy.max_z then
		footprint_cache[point_key] = 1
		return 1
	end
	for index = 1, #island_indices do
		local class = exact.indexed_polygon_class(island_indices[index], x, z)
		if class >= 0 then footprint_cache[point_key] = class return class end
	end
	footprint_cache[point_key] = -1
	return -1
end

	local bay_oracles, bay_oracle_by_id = {}, {}
	for bay_index = 1, #source.bays do
	local authored = source.bays[bay_index]
	local payload = by_id(compiled_value.families.bays, authored.id)
	local deltas = signed_array(payload, "station_radius_delta")
	local footprint_payload = by_id(compiled_value.families.perimeters,
		authored.perimeter_projection.perimeter_id)
	local oracle = {source = authored, segments = {}, wings = {}, aperture = {},
		boxes = {},
		perimeter_index = exact.polygon_index(payload_points(footprint_payload,
			"stations_xz")),
		base_cache = {}, water_cache = {}, candidate_cache = {}}
	local cursor = 1
	for segment_index = 1, #authored.centreline - 1 do
		local stations = raster.segment(authored.centreline[segment_index],
			authored.centreline[segment_index + 1])
		local segment_deltas = {}
		for station_index = 1, #stations do
			segment_deltas[station_index] = assert(deltas[cursor])
			cursor = cursor + 1
		end
		oracle.segments[segment_index] = {stations = stations,
			deltas = segment_deltas}
	end
	assert(cursor == #deltas + 1)
	for wing_index = 1, #source.bay_closure_wings do
		local wing = source.bay_closure_wings[wing_index]
		if wing.bay_id == authored.id then oracle.wings[#oracle.wings + 1] = wing end
	end
	for aperture_index = 1, #source.bay_mouth_apertures do
		local authored_aperture = source.bay_mouth_apertures[aperture_index]
		if authored_aperture.bay_id == authored.id then
			local aperture = by_id(compiled_value.families.mouth_apertures,
				authored_aperture.id)
			local perimeter = by_id(compiled_value.families.perimeters,
				authored_aperture.perimeter_id)
			local perimeter_values = signed_array(perimeter, "stations_xz")
			local first = named_scalar(aperture, "unsigned_values", "first")
			local count = named_scalar(aperture, "unsigned_values", "station_count")
			for offset = 0, count - 1 do
				local value_index = (first + offset) * 2 + 1
				oracle.aperture[oracle_key(perimeter_values[value_index],
					perimeter_values[value_index + 1])] = true
			end
		end
	end
	local min_x, max_x, min_z, max_z
	for segment_index = 1, #authored.centreline - 1 do
		local a, b = authored.centreline[segment_index],
			authored.centreline[segment_index + 1]
		local radius = math.max(a.half_width, b.half_width) +
			authored.max_displacement + 1
		local box = {min_x = math.min(a.x, b.x) - radius,
			max_x = math.max(a.x, b.x) + radius,
			min_z = math.min(a.z, b.z) - radius,
			max_z = math.max(a.z, b.z) + radius}
		oracle.boxes[#oracle.boxes + 1] = box
		min_x = min_x and math.min(min_x, box.min_x) or box.min_x
		max_x = max_x and math.max(max_x, box.max_x) or box.max_x
		min_z = min_z and math.min(min_z, box.min_z) or box.min_z
		max_z = max_z and math.max(max_z, box.max_z) or box.max_z
	end
	for wing_index = 1, #oracle.wings do
		local wing = oracle.wings[wing_index]
		local radius = wing.head_half_width + 1
		local box = {min_x = math.min(wing.head.x, wing.junction.x) - radius,
			max_x = math.max(wing.head.x, wing.junction.x) + radius,
			min_z = math.min(wing.head.z, wing.junction.z) - radius,
			max_z = math.max(wing.head.z, wing.junction.z) + radius}
		oracle.boxes[#oracle.boxes + 1] = box
		min_x = math.min(min_x, box.min_x)
		max_x = math.max(max_x, box.max_x)
		min_z = math.min(min_z, box.min_z)
		max_z = math.max(max_z, box.max_z)
	end
	oracle.bounds = {min_x = min_x, max_x = max_x, min_z = min_z, max_z = max_z}
	bay_oracles[#bay_oracles + 1] = oracle
	bay_oracle_by_id[authored.id] = oracle
end

	local function oracle_base_member(oracle, x, z)
	local point_key = oracle_key(x, z)
	if oracle.base_cache[point_key] ~= nil then return oracle.base_cache[point_key] end
	for segment_index = 1, #oracle.segments do
		local segment = oracle.segments[segment_index]
		local best_index, best_distance
		for station_index = 1, #segment.stations do
			local point = segment.stations[station_index]
			local dx, dz = point.x - x, point.z - z
			local distance = dx * dx + dz * dz
			if not best_distance or distance < best_distance then
				best_index, best_distance = station_index, distance
			end
		end
		if exact.bay_segment(x, z, oracle.source.centreline[segment_index],
				oracle.source.centreline[segment_index + 1],
				segment.deltas[best_index]) then
			oracle.base_cache[point_key] = true
			return true
		end
	end
	oracle.base_cache[point_key] = false
	return false
end

	local planned_cache = {}
	local function oracle_planned_water(x, z, perimeter_equality)
	local cache_key = oracle_key(x, z) .. (perimeter_equality and ":e" or ":i")
	if planned_cache[cache_key] ~= nil then return planned_cache[cache_key] end
	for oracle_index = 1, #bay_oracles do
		local oracle = bay_oracles[oracle_index]
		if oracle_base_member(oracle, x, z) and
				(not perimeter_equality or oracle.aperture[oracle_key(x, z)]) then
			planned_cache[cache_key] = true
			return true
		end
		if not perimeter_equality then
			for wing_index = 1, #oracle.wings do
				if exact.wing_member(x, z, oracle.wings[wing_index]) then
					planned_cache[cache_key] = true
					return true
				end
			end
		end
	end
	planned_cache[cache_key] = false
	return false
end

	local function oracle_bay_water(oracle, x, z)
	local point_key = oracle_key(x, z)
	if oracle.water_cache[point_key] ~= nil then return oracle.water_cache[point_key] end
	local class = oracle_footprint_class(x, z)
	local water = false
	if class >= 0 then
		if oracle_base_member(oracle, x, z) and
				(class > 0 or oracle.aperture[point_key]) then
			water = true
		elseif class > 0 then
			for wing_index = 1, #oracle.wings do
				if exact.wing_member(x, z, oracle.wings[wing_index]) then
					water = true
					break
				end
			end
		end
	end
	oracle.water_cache[point_key] = water
	return water
end

	local function oracle_candidate(oracle, x, z)
	local point_key = oracle_key(x, z)
	if oracle.candidate_cache[point_key] ~= nil then
		return oracle.candidate_cache[point_key]
	end
	local candidate = false
	for box_index = 1, #oracle.boxes do
		local box = oracle.boxes[box_index]
		if x >= box.min_x and x <= box.max_x and z >= box.min_z and z <= box.max_z then
			candidate = true
			break
		end
	end
	local own_water = false
	if candidate then
		for index = 1, 4 do
			local direction = oracle_cardinal[index]
			if oracle_bay_water(oracle, x + direction.x, z + direction.z) then
				own_water = true
				break
			end
		end
		local class = oracle_footprint_class(x, z)
		candidate = own_water and class >= 0 and
			not oracle_planned_water(x, z, class == 0)
	end
	if candidate then
		for index = 1, 4 do
			local direction = oracle_cardinal[index]
			local nx, nz = x + direction.x, z + direction.z
			local class = oracle_footprint_class(nx, nz)
			if class >= 0 and oracle_planned_water(nx, nz, class == 0) and
					not oracle_bay_water(oracle, nx, nz) then
				candidate = false
				break
			end
		end
	end
	oracle.candidate_cache[point_key] = candidate
	return candidate
end

	local function oracle_water_right(oracle, from, to)
	local dx, dz = to.x - from.x, to.z - from.z
	for index = 1, 4 do
		local direction = oracle_cardinal[index]
		if oracle_bay_water(oracle, from.x + direction.x, from.z + direction.z) and
				exact.cross(dx, dz, direction.x, direction.z,
					"test Bay-bank water side") < 0 then return true end
	end
	return false
end
	return {bay_oracles = bay_oracles, bay_oracle_by_id = bay_oracle_by_id,
		footprint_class = oracle_footprint_class, planned_water = oracle_planned_water,
		bay_water = oracle_bay_water, candidate = oracle_candidate,
		water_right = oracle_water_right}
end
local seed0_oracle_world = build_independent_oracle_world(compiled)
local bay_oracles = seed0_oracle_world.bay_oracles
local bay_oracle_by_id = seed0_oracle_world.bay_oracle_by_id
local function oracle_footprint_class(x, z)
	return seed0_oracle_world.footprint_class(x, z)
end
local function oracle_planned_water(x, z, perimeter_equality)
	return seed0_oracle_world.planned_water(x, z, perimeter_equality)
end
local function oracle_bay_water(oracle, x, z)
	return seed0_oracle_world.bay_water(oracle, x, z)
end
local function oracle_candidate(oracle, x, z)
	return seed0_oracle_world.candidate(oracle, x, z)
end
local function oracle_water_right(oracle, from, to)
	return seed0_oracle_world.water_right(oracle, from, to)
end

local oracle_clockwise = {{x = 1, z = 0}, {x = 1, z = -1},
	{x = 0, z = -1}, {x = -1, z = -1}, {x = -1, z = 0},
	{x = -1, z = 1}, {x = 0, z = 1}, {x = 1, z = 1}}
local function oracle_diagonal(a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	if math.abs(dx) ~= 1 or math.abs(dz) ~= 1 then return nil end
	return oracle_key(math.min(a.x, b.x), math.min(a.z, b.z)),
		dx == dz and 1 or -1
end

local r16_max = {seed0 = {}}
local trace_independent_banks_again
local independent_bank_by_id = (function()
local function oracle_point_less(a, b)
	return a.x < b.x or a.x == b.x and a.z < b.z
end
local function oracle_sequence_less(a, b)
	for index = 1, math.min(#a, #b) do
		if oracle_point_less(a[index], b[index]) then return true end
		if oracle_point_less(b[index], a[index]) then return false end
	end
	return #a < #b
end
local function oracle_wing_terms(wing, point)
	local vx = exact.safe_difference(wing.junction.x, wing.head.x,
		wing.id .. " test axis")
	local vz = exact.safe_difference(wing.junction.z, wing.head.z,
		wing.id .. " test axis")
	local px = exact.safe_difference(point.x, wing.head.x, wing.id .. " test point")
	local pz = exact.safe_difference(point.z, wing.head.z, wing.id .. " test point")
	local length = exact.safe_sum(exact.safe_square(vx, wing.id .. " test length"),
		exact.safe_square(vz, wing.id .. " test length"), wing.id .. " test length")
	return exact.dot(px, pz, vx, vz, wing.id .. " test projection"),
		exact.cross(vx, vz, px, pz, wing.id .. " test side"), length
end
local function oracle_wing_dry(x, z)
	local class = oracle_footprint_class(x, z)
	return class >= 0 and not oracle_planned_water(x, z, class == 0)
end
local function oracle_wing_water(wing, x, z)
	return oracle_footprint_class(x, z) > 0 and exact.wing_member(x, z, wing)
end
local function copy_oracle_points(points)
	local result = {}
	for index = 1, #points do
		result[index] = {x = points[index].x, z = points[index].z}
	end
	return result
end
local function oracle_tail_diagonals(path, diagonals)
	diagonals = diagonals or {}
	for index = 1, #path - 1 do
		local cell, slope = oracle_diagonal(path[index], path[index + 1])
		if cell then
			if diagonals[cell] and diagonals[cell] ~= slope then return nil end
			diagonals[cell] = slope
		end
	end
	return diagonals
end
local wing_oracle_by_id, wing_payload_by_id, wing_nonlex_fixture = {}, {}, nil
for wing_index = 1, #source.bay_closure_wings do
	local wing = source.bay_closure_wings[wing_index]
	local selected, candidates = {}, {negative = {}, positive = {}}
	local radius = wing.head_half_width
	local box = {min_x = math.min(wing.head.x, wing.junction.x) - radius,
		max_x = math.max(wing.head.x, wing.junction.x) + radius,
		min_z = math.min(wing.head.z, wing.junction.z) - radius,
		max_z = math.max(wing.head.z, wing.junction.z) + radius}
	for _, side in ipairs({"negative", "positive"}) do
		for x = box.min_x, box.max_x do
			for z = box.min_z, box.max_z do
				local own_neighbor = false
				for direction_index = 1, 4 do
					local direction = oracle_cardinal[direction_index]
					if oracle_wing_water(wing, x + direction.x, z + direction.z) then
						own_neighbor = true
						break
					end
				end
				if own_neighbor and oracle_wing_dry(x, z) then
					local point = {x = x, z = z}
					local projection, determinant, length = oracle_wing_terms(wing, point)
					local strict_side = side == "negative" and determinant < 0 or
						side == "positive" and determinant > 0
					if projection >= 0 and projection < length and strict_side then
						candidates[side][#candidates[side] + 1] =
							{point = point, projection = projection}
					end
				end
			end
		end
		table.sort(candidates[side], function(a, b)
			return a.projection > b.projection or a.projection == b.projection and
				oracle_point_less(a.point, b.point)
		end)
		assert(#candidates[side] > 0)
		selected[side] = candidates[side][1].point
	end
	local paths = {negative = {}, positive = {}}
	local function collect_wing_paths(side, path)
		local current = path[#path]
		if current.x == wing.junction.x and current.z == wing.junction.z then
			paths[side][#paths[side] + 1] = copy_oracle_points(path)
			return
		end
		local distance = math.max(math.abs(current.x - wing.junction.x),
			math.abs(current.z - wing.junction.z))
		local next_points = {}
		for dx = -1, 1 do for dz = -1, 1 do
			if dx ~= 0 or dz ~= 0 then
				local following = {x = current.x + dx, z = current.z + dz}
				local next_distance = math.max(math.abs(following.x - wing.junction.x),
					math.abs(following.z - wing.junction.z))
				local _, determinant = oracle_wing_terms(wing, following)
				local at_junction = following.x == wing.junction.x and
					following.z == wing.junction.z
				local strict_side = side == "negative" and determinant < 0 or
					side == "positive" and determinant > 0
				if next_distance == distance - 1 and oracle_wing_dry(following.x,
						following.z) and (at_junction or strict_side) then
					next_points[#next_points + 1] = following
				end
			end
		end end
		table.sort(next_points, oracle_point_less)
		for index = 1, #next_points do
			path[#path + 1] = next_points[index]
			collect_wing_paths(side, path)
			path[#path] = nil
		end
	end
	collect_wing_paths("negative", {{x = selected.negative.x, z = selected.negative.z}})
	collect_wing_paths("positive", {{x = selected.positive.x, z = selected.positive.z}})
	table.sort(paths.negative, oracle_sequence_less)
	table.sort(paths.positive, oracle_sequence_less)
	local valid_pairs = {}
	for negative_index = 1, #paths.negative do
		local negative = paths.negative[negative_index]
		local negative_diagonals = oracle_tail_diagonals(negative)
		if negative_diagonals then
			local negative_points = {}
			for index = 1, #negative - 1 do
				negative_points[oracle_key(negative[index].x, negative[index].z)] = true
			end
			for positive_index = 1, #paths.positive do
				local positive = paths.positive[positive_index]
				local valid = oracle_key(negative[#negative - 1].x,
					negative[#negative - 1].z) ~= oracle_key(positive[#positive - 1].x,
					positive[#positive - 1].z)
				local diagonals = {}
				for cell, slope in pairs(negative_diagonals) do diagonals[cell] = slope end
				for index = 1, #positive - 1 do
					if negative_points[oracle_key(positive[index].x, positive[index].z)] then
						valid = false
						break
					end
					local cell, slope = oracle_diagonal(positive[index], positive[index + 1])
					if cell and diagonals[cell] and diagonals[cell] ~= slope then
						valid = false
						break
					end
					if cell then diagonals[cell] = slope end
				end
				if valid then valid_pairs[#valid_pairs + 1] =
					{negative = negative, positive = positive} end
			end
		end
	end
	assert(#valid_pairs > 0)
	local function wedge_valid(negative, positive)
		local polygon = copy_oracle_points(negative)
		for index = #positive - 1, 1, -1 do
			polygon[#polygon + 1] = {x = positive[index].x, z = positive[index].z}
		end
		polygon[#polygon + 1] = {x = polygon[1].x, z = polygon[1].z}
		if exact.signed_area2(polygon) == 0 then return false, "zero area" end
		if not exact.polygon_simple(polygon) then return false, "not simple" end
		local radius = 1 + math.max(math.max(math.abs(negative[1].x - wing.junction.x),
			math.abs(negative[1].z - wing.junction.z)),
			math.max(math.abs(positive[1].x - wing.junction.x),
				math.abs(positive[1].z - wing.junction.z)))
		if radius > 5 then return false, "radius", radius end
		local exempt = {}
		for index = 1, #negative do
			exempt[oracle_key(negative[index].x, negative[index].z)] = true
		end
		for index = 1, #positive do
			exempt[oracle_key(positive[index].x, positive[index].z)] = true
		end
		local dry_columns = {}
		for x = wing.junction.x - radius, wing.junction.x + radius do
			for z = wing.junction.z - radius, wing.junction.z + radius do
				if exact.polygon_class(x, z, polygon) >= 0 and
						not exempt[oracle_key(x, z)] and not oracle_wing_water(wing, x, z) then
					dry_columns[#dry_columns + 1] = {x = x, z = z}
				end
			end
		end
		table.sort(dry_columns, function(a, b)
			return a.z < b.z or a.z == b.z and a.x < b.x
		end)
		if #dry_columns > 0 then return false, "nonwing column", radius, dry_columns end
		return true, nil, radius, dry_columns
	end
	local wedge_pairs, selected_raw_rank = {}, nil
	for pair_index = 1, #valid_pairs do
		local pair = valid_pairs[pair_index]
		local valid, _, wedge_radius = wedge_valid(pair.negative, pair.positive)
		if valid then
			pair.wedge_radius = wedge_radius
			wedge_pairs[#wedge_pairs + 1] = pair
			if not selected_raw_rank then selected_raw_rank = pair_index end
		end
	end
	assert(#wedge_pairs > 0)
	local wing_oracle = {wing = wing, negative_k = selected.negative,
		positive_k = selected.positive, negative_candidates = candidates.negative,
		positive_candidates = candidates.positive, negative = wedge_pairs[1].negative,
		positive = wedge_pairs[1].positive, valid_pairs = valid_pairs,
		wedge_valid_pairs = wedge_pairs, wedge_valid = wedge_valid,
		selected_raw_rank = selected_raw_rank, wedge_radius = wedge_pairs[1].wedge_radius}
	wing_oracle_by_id[wing.id] = wing_oracle
	if not wing_nonlex_fixture and #valid_pairs > 1 then wing_nonlex_fixture = wing_oracle end
end

local function wing_payload_points(payload, name)
	return payload_points(payload, name)
end
local function validate_wing_pair_structure(negative, positive)
	if #negative < 2 or #positive < 2 then error("Wing tail is short") end
	if negative[#negative - 1].x == positive[#positive - 1].x and
			negative[#negative - 1].z == positive[#positive - 1].z then
		error("Wing predecessors coincide")
	end
	local negative_seen = {}
	for index = 1, #negative - 1 do
		negative_seen[oracle_key(negative[index].x, negative[index].z)] = true
	end
	for index = 1, #positive - 1 do
		if negative_seen[oracle_key(positive[index].x, positive[index].z)] then
			error("Wing tails overlap")
		end
	end
	local diagonals = oracle_tail_diagonals(negative)
	if not diagonals or not oracle_tail_diagonals(positive, diagonals) then
		error("Wing tails X-cross")
	end
	return true
end
local function validate_wing_tail_geometry(wing, side, points)
	for index = 1, #points do
		local point = points[index]
		local _, determinant = oracle_wing_terms(wing, point)
		local at_junction = point.x == wing.junction.x and point.z == wing.junction.z
		if not at_junction and not (side == "negative" and determinant < 0 or
				side == "positive" and determinant > 0) then
			error("Wing tail leaves strict side")
		end
		if not oracle_wing_dry(point.x, point.z) then error("Wing tail is not dry") end
		if index > 1 then
			local previous = points[index - 1]
			local before = math.max(math.abs(previous.x - wing.junction.x),
				math.abs(previous.z - wing.junction.z))
			local after = math.max(math.abs(point.x - wing.junction.x),
				math.abs(point.z - wing.junction.z))
			if after ~= before - 1 then error("Wing tail distance does not decrease") end
		end
	end
	return true
end
local function validate_wing_payload_oracle(payload, expected)
	local wing = expected.wing
	if payload.numeric_id ~= wing.numeric_id or
			named_scalar(payload, "text_values", "bay_id") ~= wing.bay_id or
			named_scalar(payload, "text_values", "left_zone_id") ~= wing.left_zone_id or
			named_scalar(payload, "text_values", "right_zone_id") ~= wing.right_zone_id or
			named_scalar(payload, "text_values", "tie_zone_id") ~= wing.tie_zone_id then
		error("Wing owner projection changed")
	end
	if named_scalar(payload, "signed_values", "head_x") ~= wing.head.x or
			named_scalar(payload, "signed_values", "head_z") ~= wing.head.z or
			named_scalar(payload, "signed_values", "junction_x") ~= wing.junction.x or
			named_scalar(payload, "signed_values", "junction_z") ~= wing.junction.z then
		error("Wing head projection changed")
	end
	if named_scalar(payload, "unsigned_values", "head_half_width") ~=
			wing.head_half_width then error("Wing width projection changed") end
	local negative = wing_payload_points(payload, "negative_tail_xz")
	local positive = wing_payload_points(payload, "positive_tail_xz")
	validate_wing_pair_structure(negative, positive)
	for _, entry in ipairs({{side = "negative", points = negative},
			{side = "positive", points = positive}}) do
		validate_wing_tail_geometry(expected.wing, entry.side, entry.points)
	end
	local wedge_valid, wedge_reason = expected.wedge_valid(negative, positive)
	if not wedge_valid then error("Wing pair fails wedge validity: " .. wedge_reason) end
	local negative_k_x = named_scalar(payload, "signed_values", "negative_k_x")
	local negative_k_z = named_scalar(payload, "signed_values", "negative_k_z")
	local positive_k_x = named_scalar(payload, "signed_values", "positive_k_x")
	local positive_k_z = named_scalar(payload, "signed_values", "positive_k_z")
	if negative_k_x ~= expected.negative_k.x or negative_k_z ~= expected.negative_k.z or
			positive_k_x ~= expected.positive_k.x or positive_k_z ~= expected.positive_k.z then
		error("Wing K selection changed")
	end
	if #negative ~= named_scalar(payload, "unsigned_values",
			"negative_tail_station_count") or #positive ~= named_scalar(payload,
			"unsigned_values", "positive_tail_station_count") then
		error("Wing tail count changed")
	end
	for _, entry in ipairs({{actual = negative, wanted = expected.negative},
			{actual = positive, wanted = expected.positive}}) do
		if #entry.actual ~= #entry.wanted then error("Wing pair is not lexicographically selected") end
		for index = 1, #entry.actual do
			if entry.actual[index].x ~= entry.wanted[index].x or
					entry.actual[index].z ~= entry.wanted[index].z then
				error("Wing pair is not lexicographically selected")
			end
		end
	end
	return true
end

local expected_raw_pair_counts = {4,18,18,4,2,18,18,18}
local expected_wedge_pair_counts = {1,1,1,1,1,1,1,1}
local expected_wedge_raw_ranks = {1,10,2,1,2,17,9,17}
local expected_wedge_radii = {4,5,5,4,3,5,5,5}
local expected_old_dry = {"", "-402:-1901", "402:-1901", "", "-1399:1900",
	"-402:1899,-403:1900,-402:1900,-401:1900",
	"402:1899,401:1900,402:1900,403:1900",
	"1398:1899,1397:1900,1398:1900,1399:1900"}
local old_dry_total = 0
local function point_sequence_signature(points)
	local values = {}
	for index = 1, #points do values[index] = points[index].x .. ":" .. points[index].z end
	return table.concat(values, ",")
end
for wing_index = 1, #compiled.families.closure_wings do
	local payload = compiled.families.closure_wings[wing_index]
	local expected = assert(wing_oracle_by_id[payload.id])
	wing_payload_by_id[payload.id] = payload
	assert(validate_wing_payload_oracle(payload, expected))
	assert(expected.negative_candidates[1].point.x == expected.negative_k.x and
		expected.negative_candidates[1].point.z == expected.negative_k.z and
		expected.positive_candidates[1].point.x == expected.positive_k.x and
		expected.positive_candidates[1].point.z == expected.positive_k.z and
		#expected.valid_pairs == expected_raw_pair_counts[wing_index] and
		#expected.wedge_valid_pairs == expected_wedge_pair_counts[wing_index] and
		expected.selected_raw_rank == expected_wedge_raw_ranks[wing_index] and
		expected.wedge_radius == expected_wedge_radii[wing_index])
	local valid, reason, _, dry = expected.wedge_valid(
		expected.valid_pairs[1].negative, expected.valid_pairs[1].positive)
	local actual_signature = point_sequence_signature(dry or {})
	assert((valid and "" or reason) == (#expected_old_dry[wing_index] == 0 and "" or
		"nonwing column") and actual_signature == expected_old_dry[wing_index],
		"old structural-first Wing gap witness changed: " .. payload.id .. " " ..
			tostring(reason) .. " " .. actual_signature .. " expected " ..
			expected_old_dry[wing_index])
	old_dry_total = old_dry_total + #(dry or {})
end
assert(wing_nonlex_fixture and old_dry_total == 15)
do
	local fixture = wing_oracle_by_id[compiled.families.closure_wings[1].id]
	local j = fixture.wing.junction
	local valid, reason = fixture.wedge_valid({{x = 0, z = 0}, {x = 1, z = 0}},
		{{x = 2, z = 0}, {x = 1, z = 0}})
	assert(not valid and reason == "zero area")
	valid, reason = fixture.wedge_valid({{x = 0, z = 0}, {x = 3, z = 3},
		{x = 0, z = 3}}, {{x = 2, z = 0}, {x = 0, z = 3}})
	assert(not valid and reason == "not simple")
	valid, reason = fixture.wedge_valid({{x = j.x - 6, z = j.z},
		{x = j.x, z = j.z}}, {{x = j.x, z = j.z - 1}, {x = j.x, z = j.z}})
	assert(not valid and reason == "radius")
end

local wing_bank_use_count = 0
for bank_index = 1, #source.bay_bank_components do
	local bank = source.bay_bank_components[bank_index]
	local values = assert(bank_payload[bank.id])
	if bank.start_terminal.kind == "wing_junction_tail_side" then
		assert(bank.start_terminal.tail_side == "negative")
		local expected = wing_oracle_by_id[bank.start_terminal.wing_id].negative
		for index = 1, #expected do
			local value_index = (index - 1) * 2 + 1
			local point = expected[#expected - index + 1]
			assert(values[value_index] == point.x and values[value_index + 1] == point.z)
		end
		wing_bank_use_count = wing_bank_use_count + 1
	end
	if bank.end_terminal.kind == "wing_junction_tail_side" then
		assert(bank.end_terminal.tail_side == "positive")
		local expected = wing_oracle_by_id[bank.end_terminal.wing_id].positive
		local first_value = #values - #expected * 2 + 1
		for index = 1, #expected do
			local value_index = first_value + (index - 1) * 2
			assert(values[value_index] == expected[index].x and
				values[value_index + 1] == expected[index].z)
		end
		wing_bank_use_count = wing_bank_use_count + 1
	end
end
assert(wing_bank_use_count == 16)

local function wing_test_copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[wing_test_copy(key)] = wing_test_copy(child) end
	return result
end
local function set_wing_named_scalar(payload, field, name, value)
	for index = 1, #payload[field] do
		if payload[field][index].name == name then payload[field][index].value = value return end
	end
	error("missing Wing scalar " .. name)
end
local function set_wing_tail(payload, name, points)
	local values = {}
	for index = 1, #points do
		values[#values + 1] = points[index].x
		values[#values + 1] = points[index].z
	end
	for index = 1, #payload.signed_arrays do
		if payload.signed_arrays[index].name == name then
			payload.signed_arrays[index].values = values
			return
		end
	end
	error("missing Wing tail " .. name)
end
local wing_fixture = compiled.families.closure_wings[1]
local wing_expected = wing_oracle_by_id[wing_fixture.id]
expect_error("Wing owner projection changed", function()
	local corrupted = wing_test_copy(wing_fixture)
	set_wing_named_scalar(corrupted, "text_values", "left_zone_id", "front_broken_causeway")
	validate_wing_payload_oracle(corrupted, wing_expected)
end)
expect_error("Wing head projection changed", function()
	local corrupted = wing_test_copy(wing_fixture)
	set_wing_named_scalar(corrupted, "signed_values", "head_x",
		wing_expected.wing.head.x + 1)
	validate_wing_payload_oracle(corrupted, wing_expected)
end)
expect_error("Wing width projection changed", function()
	local corrupted = wing_test_copy(wing_fixture)
	set_wing_named_scalar(corrupted, "unsigned_values", "head_half_width",
		wing_expected.wing.head_half_width + 1)
	validate_wing_payload_oracle(corrupted, wing_expected)
end)
expect_error("Wing K selection changed", function()
	local corrupted = wing_test_copy(wing_fixture)
	set_wing_named_scalar(corrupted, "signed_values", "negative_k_x",
		wing_expected.negative_k.x + 1)
	validate_wing_payload_oracle(corrupted, wing_expected)
end)
expect_error("Wing tail leaves strict side", function()
	validate_wing_tail_geometry(wing_expected.wing, "negative",
		copy_oracle_points(wing_expected.positive))
end)
expect_error("Wing tail distance does not decrease", function()
	local corrupted = wing_test_copy(wing_fixture)
	local points = copy_oracle_points(wing_expected.negative)
	points[2] = {x = points[1].x, z = points[1].z}
	set_wing_tail(corrupted, "negative_tail_xz", points)
	validate_wing_payload_oracle(corrupted, wing_expected)
end)
expect_error("Wing tails overlap", function()
	local negative = copy_oracle_points(wing_expected.negative)
	local positive = copy_oracle_points(wing_expected.positive)
	positive[1] = {x = negative[1].x, z = negative[1].z}
	validate_wing_pair_structure(negative, positive)
end)
expect_error("Wing predecessors coincide", function()
	local negative = copy_oracle_points(wing_expected.negative)
	local positive = copy_oracle_points(wing_expected.positive)
	positive[#positive - 1] = {x = negative[#negative - 1].x,
		z = negative[#negative - 1].z}
	validate_wing_pair_structure(negative, positive)
end)
expect_error("Wing tails X-cross", function()
	local j = wing_expected.wing.junction
	validate_wing_pair_structure({{x = j.x - 2, z = j.z},
		{x = j.x - 1, z = j.z + 1}, {x = j.x, z = j.z}},
		{{x = j.x - 2, z = j.z + 1}, {x = j.x - 1, z = j.z},
			{x = j.x, z = j.z}})
end)
expect_error("fails wedge validity", function()
	local corrupted = wing_test_copy(wing_payload_by_id[wing_nonlex_fixture.wing.id])
	local alternate = wing_nonlex_fixture.valid_pairs[2]
	set_wing_tail(corrupted, "negative_tail_xz", alternate.negative)
	set_wing_tail(corrupted, "positive_tail_xz", alternate.positive)
	set_wing_named_scalar(corrupted, "unsigned_values", "negative_tail_station_count",
		#alternate.negative)
	set_wing_named_scalar(corrupted, "unsigned_values", "positive_tail_station_count",
		#alternate.positive)
	validate_wing_payload_oracle(corrupted, wing_nonlex_fixture)
end)
local old_structural_fixture
for index = 1, #source.bay_closure_wings do
	local expected = wing_oracle_by_id[source.bay_closure_wings[index].id]
	if expected.selected_raw_rank > 1 then old_structural_fixture = expected break end
end
assert(old_structural_fixture)
expect_error("fails wedge validity", function()
	local corrupted = wing_test_copy(wing_payload_by_id[old_structural_fixture.wing.id])
	local old_pair = old_structural_fixture.valid_pairs[1]
	set_wing_tail(corrupted, "negative_tail_xz", old_pair.negative)
	set_wing_tail(corrupted, "positive_tail_xz", old_pair.positive)
	set_wing_named_scalar(corrupted, "unsigned_values", "negative_tail_station_count",
		#old_pair.negative)
	set_wing_named_scalar(corrupted, "unsigned_values", "positive_tail_station_count",
		#old_pair.positive)
	validate_wing_payload_oracle(corrupted, old_structural_fixture)
end)

-- Independent all-20 R12 Bank oracle.  It resolves every terminal from Source
-- plus final AP/edge/Wing authorities, enforces exact finite caps and the fixed
-- first-terminal-reachable Moore rule, then compares the complete bytes.
local function extract_final_edge_points(compiled_value)
	local result = {}
	for edge_index = 1, #compiled_value.families.land_boundaries do
		local edge = compiled_value.families.land_boundaries[edge_index]
		result[edge.id] = payload_points(edge, "stations_xz")
	end
	return result
end
local final_edge_points_by_id = extract_final_edge_points(compiled)
local function count_bank_envelopes(oracle_world)
	local result = {}
	for bay_index = 1, #oracle_world.bay_oracles do
	local bay_oracle = oracle_world.bay_oracles[bay_index]
	local count = 0
	for x = bay_oracle.bounds.min_x, bay_oracle.bounds.max_x do
		for z = bay_oracle.bounds.min_z, bay_oracle.bounds.max_z do
			local in_union = false
			for box_index = 1, #bay_oracle.boxes do
				local box = bay_oracle.boxes[box_index]
				if x >= box.min_x and x <= box.max_x and z >= box.min_z and
						z <= box.max_z then in_union = true break end
			end
			if in_union and exact.indexed_polygon_class(bay_oracle.perimeter_index,
					x, z) >= 0 then count = exact.safe_sum(count, 1,
					bay_oracle.source.id .. " independent envelope count") end
		end
	end
	assert(count > 0)
	result[bay_oracle.source.id] = count
end
	return result
end
local bank_envelope_count = count_bank_envelopes(seed0_oracle_world)

local function resolve_bank_terminal(terminal, wing_authority, edge_points,
		authored_apertures)
	if terminal.kind == "aperture_dry" then
		local value = assert(authored_apertures[terminal.aperture_id])[terminal.side]
		return {point = {x = value.point.x, z = value.point.z},
			previous = {x = value.away.x, z = value.away.z}}
	elseif terminal.kind == "land_edge_transition" then
		local points = assert(edge_points[terminal.edge_id])
		local endpoint = terminal.edge_endpoint == "from" and 1 or #points
		local away = terminal.edge_endpoint == "from" and 2 or #points - 1
		return {point = {x = points[endpoint].x, z = points[endpoint].z},
			previous = {x = points[away].x, z = points[away].z}}
	elseif terminal.kind == "wing_junction_tail_side" then
		local value = assert(wing_authority[terminal.wing_id])
		return {point = {x = value.wing.junction.x, z = value.wing.junction.z},
			k = terminal.tail_side == "negative" and value.negative_k or value.positive_k,
			tail = terminal.tail_side == "negative" and value.negative or value.positive}
	end
	error("unknown independent Bank terminal")
end
local function bank_state_key(previous_point, current_point)
	return oracle_key(previous_point.x, previous_point.z) .. ">" ..
		oracle_key(current_point.x, current_point.z)
end
local function add_bank_diagonal(diagonals, a, b)
	local cell, slope = oracle_diagonal(a, b)
	if not cell then return nil end
	if diagonals[cell] and diagonals[cell] ~= slope then return false end
	if not diagonals[cell] then diagonals[cell] = slope return cell end
	return nil
end
local function independent_bank_successors(oracle_world, bay_oracle, previous_point,
		current_point, seen_states, seen_columns, diagonals)
	local back_x, back_z = previous_point.x - current_point.x,
		previous_point.z - current_point.z
	local back_index
	for index = 1, 8 do
		if oracle_clockwise[index].x == back_x and oracle_clockwise[index].z == back_z then
			back_index = index break
		end
	end
	assert(back_index)
	local result = {}
	for offset = 1, 8 do
		local direction_index = ((back_index - offset - 1) % 8) + 1
		local direction = oracle_clockwise[direction_index]
		local following = {x = current_point.x + direction.x,
			z = current_point.z + direction.z}
		local following_key = oracle_key(following.x, following.z)
		local directed_key = bank_state_key(current_point, following)
		local cell, slope = oracle_diagonal(current_point, following)
		if following_key ~= oracle_key(previous_point.x, previous_point.z) and
				not seen_states[directed_key] and not seen_columns[following_key] and
				(not cell or not diagonals[cell] or diagonals[cell] == slope) and
				oracle_world.candidate(bay_oracle, following.x, following.z) and
				oracle_world.water_right(bay_oracle, current_point, following) then
			result[#result + 1] = following
		end
	end
	return result
end
local function copy_bank_set(values)
	local result = {}
	for key, value in pairs(values) do result[key] = value end
	return result
end
local function independent_bank_reachable(oracle_world, bay_oracle, previous_point,
		current_point, target, base_states, base_columns, base_diagonals, envelope_count)
	local seen_states, seen_columns, diagonals = copy_bank_set(base_states),
		copy_bank_set(base_columns), copy_bank_set(base_diagonals)
	local first_state, first_column = bank_state_key(previous_point, current_point),
		oracle_key(current_point.x, current_point.z)
	if seen_states[first_state] or seen_columns[first_column] then return false end
	seen_states[first_state], seen_columns[first_column] = true, true
	local first_cell = add_bank_diagonal(diagonals, previous_point, current_point)
	if first_cell == false then return false end
	local stack = {{previous = previous_point, current = current_point,
		state = first_state, column = first_column, diagonal = first_cell}}
	local pushed = 1
	while #stack > 0 do
		assert(pushed <= envelope_count * 8 and #stack <= envelope_count)
		local frame = stack[#stack]
		if frame.current.x == target.x and frame.current.z == target.z then return true end
		if not frame.successors then
			frame.successors = independent_bank_successors(oracle_world, bay_oracle,
				frame.previous, frame.current, seen_states, seen_columns, diagonals)
			frame.next = 1
		end
		local following = frame.successors[frame.next]
		if following then
			frame.next = frame.next + 1
			local state, column = bank_state_key(frame.current, following),
				oracle_key(following.x, following.z)
			seen_states[state], seen_columns[column] = true, true
			local cell = add_bank_diagonal(diagonals, frame.current, following)
			assert(cell ~= false)
			stack[#stack + 1] = {previous = frame.current, current = following,
				state = state, column = column, diagonal = cell}
			pushed = pushed + 1
		else
			seen_states[frame.state], seen_columns[frame.column] = nil, nil
			if frame.diagonal then diagonals[frame.diagonal] = nil end
			stack[#stack] = nil
		end
	end
	return false
end
local function trace_independent_banks(oracle_world, wing_authority, edge_points,
		authored_apertures, envelope_counts, payload, compare_payload)
local bank_results = {}
for bank_index = 1, #source.bay_bank_components do
	local bank = source.bay_bank_components[bank_index]
	local bay_oracle = assert(oracle_world.bay_oracle_by_id[bank.bay_id])
	local start = resolve_bank_terminal(bank.start_terminal, wing_authority,
		edge_points, authored_apertures)
	local finish = resolve_bank_terminal(bank.end_terminal, wing_authority,
		edge_points, authored_apertures)
	local points, seen_states, seen_columns, diagonals = {}, {}, {}, {}
	local previous_point, current_point, target, suffix
	if bank.start_terminal.kind == "wing_junction_tail_side" then
		assert(bank.start_terminal.tail_side == "negative")
		for index = #start.tail, 1, -1 do
			local point = start.tail[index]
			points[#points + 1] = {x = point.x, z = point.z}
			seen_columns[oracle_key(point.x, point.z)] = true
			if #points > 1 then
				seen_states[bank_state_key(points[#points - 1], point)] = true
				assert(add_bank_diagonal(diagonals, points[#points - 1], point) ~= false)
			end
		end
		previous_point, current_point = points[#points - 1], points[#points]
	else
		previous_point = start.previous
		current_point = {x = start.point.x, z = start.point.z}
		points[1] = {x = current_point.x, z = current_point.z}
		seen_columns[oracle_key(current_point.x, current_point.z)] = true
		seen_states[bank_state_key(previous_point, current_point)] = true
	end
	if bank.end_terminal.kind == "wing_junction_tail_side" then
		assert(bank.end_terminal.tail_side == "positive")
		target, suffix = finish.k, finish.tail
	else
		target = finish.point
	end
	assert(math.max(math.abs(previous_point.x - current_point.x),
		math.abs(previous_point.z - current_point.z)) == 1 and
		oracle_world.candidate(bay_oracle, current_point.x, current_point.z) and
		oracle_world.candidate(bay_oracle, target.x, target.z))
	local main_steps, envelope_count = 0, envelope_counts[bank.bay_id]
	while current_point.x ~= target.x or current_point.z ~= target.z do
		local successors = independent_bank_successors(oracle_world, bay_oracle,
			previous_point, current_point, seen_states, seen_columns, diagonals)
		local following
		if #successors == 1 then
			following = successors[1]
		else
			for successor_index = 1, #successors do
				if independent_bank_reachable(oracle_world, bay_oracle, current_point,
						successors[successor_index], target, seen_states, seen_columns,
						diagonals, envelope_count) then
					following = successors[successor_index]
					break
				end
			end
		end
		assert(following, bank.id .. " independent trace cannot reach terminal")
		assert(add_bank_diagonal(diagonals, current_point, following) ~= false)
		seen_states[bank_state_key(current_point, following)] = true
		seen_columns[oracle_key(following.x, following.z)] = true
		points[#points + 1] = {x = following.x, z = following.z}
		previous_point, current_point = current_point, following
		main_steps = main_steps + 1
		assert(main_steps <= envelope_count - 1)
	end
	if suffix then
		for index = 2, #suffix do
			local following = suffix[index]
			assert(not seen_columns[oracle_key(following.x, following.z)] and
				add_bank_diagonal(diagonals, points[#points], following) ~= false)
			seen_columns[oracle_key(following.x, following.z)] = true
			points[#points + 1] = {x = following.x, z = following.z}
		end
	end
	if compare_payload then
		local payload_row = assert(payload[bank.id])
		assert(#payload_row == #points * 2)
		for index = 1, #points do
			assert(payload_row[index * 2 - 1] == points[index].x and
				payload_row[index * 2] == points[index].z,
				bank.id .. " Bank bytes changed")
		end
	end
	bank_results[bank.id] = points
end
assert(#source.bay_bank_components == 20)
return bank_results
end
trace_independent_banks_again = trace_independent_banks
local historical_wing_by_id = {}
for wing_id, expected in pairs(wing_oracle_by_id) do
	local old_pair = assert(expected.valid_pairs[1])
	historical_wing_by_id[wing_id] = {wing = expected.wing,
		negative_k = expected.negative_k, positive_k = expected.positive_k,
		negative = old_pair.negative, positive = old_pair.positive}
end
local bank_results = trace_independent_banks(seed0_oracle_world, wing_oracle_by_id,
	final_edge_points_by_id, authored_aperture_by_id, bank_envelope_count,
	bank_payload, true)
r16_max.seed0.wings = wing_oracle_by_id
r16_max.seed0.edges = final_edge_points_by_id
r16_max.seed0.apertures = authored_aperture_by_id
r16_max.seed0.envelopes = bank_envelope_count
r16_max.seed0.banks = bank_results
bank_results.__historical = trace_independent_banks(seed0_oracle_world,
	historical_wing_by_id, final_edge_points_by_id, authored_aperture_by_id,
	bank_envelope_count, bank_payload, false)

-- R16 turns the former fixed-slot-19 fatal into a positive full compile.  The
-- same parameterized Source/payload oracle is reused below; no Production Bank
-- classifier or resolver is called back from this proof.
local max_u64_seed = "18446744073709551615"
local max_u64_compiled = compiler.compile(max_u64_seed)
assert(#max_u64_compiled.families.land_boundaries == 61 and
	#max_u64_compiled.families.dry_faces == 38 and
	#max_u64_compiled.families.bays == 4)
local max_u64_world = build_independent_oracle_world(max_u64_compiled)
local max_u64_apertures = derive_authored_apertures(max_u64_compiled)
local max_u64_bank_payload, max_u64_bank_count =
	extract_bank_payload(max_u64_compiled)
assert(max_u64_bank_count == 20)
local function compiled_wing_authority(compiled_value)
	local result, wing_source_by_id = {}, {}
	for index = 1, #source.bay_closure_wings do
		wing_source_by_id[source.bay_closure_wings[index].id] =
			source.bay_closure_wings[index]
	end
	for index = 1, #compiled_value.families.closure_wings do
		local payload = compiled_value.families.closure_wings[index]
		local wing = assert(wing_source_by_id[payload.id])
		result[payload.id] = {wing = wing,
			negative_k = {x = named_scalar(payload, "signed_values", "negative_k_x"),
				z = named_scalar(payload, "signed_values", "negative_k_z")},
			positive_k = {x = named_scalar(payload, "signed_values", "positive_k_x"),
				z = named_scalar(payload, "signed_values", "positive_k_z")},
			negative = payload_points(payload, "negative_tail_xz"),
			positive = payload_points(payload, "positive_tail_xz")}
	end
	return result
end

local function independent_transition_expectations(oracle_world, r7_edges)
	local result, direct_count, elbow_count = {}, 0, 0
	for transition_index = 1, #source.bay_edge_transitions do
		local row = source.bay_edge_transitions[transition_index]
		local edge = assert(r7_edges[row.edge_id])
		local bay_oracle = assert(oracle_world.bay_oracle_by_id[row.bay_id])
		local retained = {}
		for station_index = 1, #edge.stations do
			local point = edge.stations[station_index]
			local class = oracle_world.footprint_class(point.x, point.z)
			if class >= 0 and not oracle_world.planned_water(point.x, point.z,
					class == 0) then retained[#retained + 1] = station_index end
		end
		assert(#retained > 0)
		for index = 2, #retained do assert(retained[index] == retained[index - 1] + 1) end
		local e_index = row.edge_endpoint == "from" and retained[1] or
			retained[#retained]
		local e = edge.stations[e_index]
		local expected = {source = row, e = {x = e.x, z = e.z}}
		if oracle_world.candidate(bay_oracle, e.x, e.z) then
			expected.mode = "direct"
			expected.point = {x = e.x, z = e.z}
			direct_count = direct_count + 1
		else
			local class = oracle_world.footprint_class(e.x, e.z)
			assert(class == 1 and not oracle_world.planned_water(e.x, e.z, false))
			for direction_index = 1, #oracle_cardinal do
				local direction = oracle_cardinal[direction_index]
				local x, z = e.x + direction.x, e.z + direction.z
				local neighbor_class = oracle_world.footprint_class(x, z)
				assert(neighbor_class < 0 or
					not oracle_world.planned_water(x, z, neighbor_class == 0))
			end
			local w_index = row.edge_endpoint == "from" and e_index - 1 or e_index + 1
			local w = assert(edge.stations[w_index])
			assert(math.abs(w.x - e.x) == 1 and math.abs(w.z - e.z) == 1 and
				oracle_world.bay_water(bay_oracle, w.x, w.z))
			for bay_id, other in pairs(oracle_world.bay_oracle_by_id) do
				if bay_id ~= row.bay_id then assert(not oracle_world.bay_water(other, w.x, w.z)) end
			end
			local elbows = {{x = w.x, z = e.z}, {x = e.x, z = w.z}}
			for elbow_index = 1, 2 do
				local elbow = elbows[elbow_index]
				assert(oracle_world.footprint_class(elbow.x, elbow.z) == 1 and
					not oracle_world.planned_water(elbow.x, elbow.z, false) and
					oracle_world.candidate(bay_oracle, elbow.x, elbow.z))
			end
			table.sort(elbows, function(a, b)
				return a.x < b.x or a.x == b.x and a.z < b.z
			end)
			expected.mode = "diagonal_elbow"
			expected.w = {x = w.x, z = w.z}
			expected.elbows = elbows
			expected.point = {x = elbows[1].x, z = elbows[1].z}
			elbow_count = elbow_count + 1
		end
		result[row.id] = expected
	end
	return result, direct_count, elbow_count
end

local function assert_transition_payload(compiled_value, expectations)
	local seen, count, by_terminal = {}, 0, {}
	for source_id, expected in pairs(expectations) do
		by_terminal["land_edge_transition:" .. expected.source.edge_id .. ":" ..
			expected.source.edge_endpoint] = {source_id = source_id, value = expected}
	end
	for edge_index = 1, #compiled_value.families.land_boundaries do
		local edge = compiled_value.families.land_boundaries[edge_index]
		local transition_count = maybe_named_scalar(edge, "unsigned_values",
			"bank_transition_count")
		if transition_count then
			local ids = named_array_value(edge, "text_arrays", "bank_transition_ids")
			local bays = named_array_value(edge, "text_arrays",
				"bank_transition_bay_ids")
			local endpoints = named_array_value(edge, "text_arrays",
				"bank_transition_endpoints")
			local positions = signed_array(edge, "bank_transition_xz")
			local offsets = named_array_value(edge, "unsigned_arrays",
				"bank_transition_offsets")
			local stations = payload_points(edge, "stations_xz")
			assert(#ids == transition_count and #bays == transition_count and
				#endpoints == transition_count and #positions == transition_count * 2 and
				#offsets == transition_count)
			for index = 1, transition_count do
				local binding = assert(by_terminal[ids[index]])
				local id, expected = binding.source_id, binding.value
				local exact_terminal_id = "land_edge_transition:" ..
					expected.source.edge_id .. ":" .. expected.source.edge_endpoint
				assert(ids[index] == exact_terminal_id and not seen[id] and
					bays[index] == expected.source.bay_id and
					endpoints[index] == expected.source.edge_endpoint and
					offsets[index] == 0 and positions[index * 2 - 1] == expected.point.x and
					positions[index * 2] == expected.point.z)
				local endpoint = endpoints[index] == "from" and 1 or #stations
				local away = endpoints[index] == "from" and 2 or #stations - 1
				assert(stations[endpoint].x == expected.point.x and
					stations[endpoint].z == expected.point.z)
				if expected.mode == "diagonal_elbow" then
					assert(stations[away].x == expected.e.x and stations[away].z == expected.e.z)
				end
				seen[id], count = true, count + 1
			end
		end
	end
	assert(count == 8)
end

-- C1 selected winners consume the same independent Bank/transition authority
-- as the retained Seed0/max-u64 proof.  Keep every helper lexical to this
-- closure: none of these names is a public test global or a second resolver.
r16_max.bank_transition_oracle = function(compiled_value, oracle_world,
		r7_edges, authored_apertures, payload)
	local edges = extract_final_edge_points(compiled_value)
	local envelopes = count_bank_envelopes(oracle_world)
	local wings = compiled_wing_authority(compiled_value)
	local banks = trace_independent_banks(oracle_world, wings, edges,
		authored_apertures, envelopes, payload, true)
	local transitions, direct, elbows = independent_transition_expectations(
		oracle_world, r7_edges)
	assert_transition_payload(compiled_value, transitions)
	return {edges = edges, envelopes = envelopes, wings = wings, banks = banks,
		transition_expectations = transitions, direct = direct, elbows = elbows}
end

local seed0_transition_expectations, seed0_direct, seed0_elbows =
	independent_transition_expectations(seed0_oracle_world, selected_r7_edge_by_id)
assert(seed0_direct == 8 and seed0_elbows == 0)
assert_transition_payload(compiled, seed0_transition_expectations)
local max_u64_selected_r7 = materialize_selected_r7(max_u64_seed)
local max_u64_authority = r16_max.bank_transition_oracle(max_u64_compiled,
	max_u64_world, max_u64_selected_r7, max_u64_apertures, max_u64_bank_payload)
local max_u64_transition_expectations = max_u64_authority.transition_expectations
local max_u64_direct, max_u64_elbows = max_u64_authority.direct,
	max_u64_authority.elbows
local max_u64_edges, max_u64_envelopes, max_u64_wings, max_u64_banks =
	max_u64_authority.edges, max_u64_authority.envelopes,
	max_u64_authority.wings, max_u64_authority.banks
assert(max_u64_direct == 7 and max_u64_elbows == 1)
local max_transition = assert(max_u64_transition_expectations[
	"bay_edge_transition:land_010:to"])
assert(max_transition.mode == "diagonal_elbow" and
	max_transition.e.x == -1140 and max_transition.e.z == 2241 and
	max_transition.w.x == -1139 and max_transition.w.z == 2242 and
	max_transition.elbows[1].x == -1140 and max_transition.elbows[1].z == 2242 and
	max_transition.elbows[2].x == -1139 and max_transition.elbows[2].z == 2241 and
	max_transition.point.x == -1140 and max_transition.point.z == 2242)
local max_kw = assert(max_u64_world.bay_oracle_by_id["bay_kragmar_west"])
local max_w_segment = assert(max_kw.segments[2])
local max_w_nearest, max_w_distance
for station_index = 1, #max_w_segment.stations do
	local station = max_w_segment.stations[station_index]
	local dx, dz = station.x - max_transition.w.x, station.z - max_transition.w.z
	local distance = dx * dx + dz * dz
	if not max_w_distance or distance < max_w_distance then
		max_w_nearest, max_w_distance = station_index, distance
	end
end
assert(max_w_nearest - 1 == 259 and max_w_segment.deltas[max_w_nearest] == -12)

local max_stillgrave = max_u64_banks["bay_bank:kragmar_west:stillgrave"]
local max_mournfen = max_u64_banks["bay_bank:kragmar_west:mournfen"]
assert(max_stillgrave[1].x == max_transition.point.x and
	max_stillgrave[1].z == max_transition.point.z and
	max_stillgrave[2].x == -1141 and max_stillgrave[2].z == 2242 and
	#max_mournfen == 453 and
	max_mournfen[#max_mournfen].x == max_transition.point.x and
	max_mournfen[#max_mournfen].z == max_transition.point.z)
local max_mournfen_tail = {{-1135,2237},{-1136,2238},{-1137,2239},
	{-1138,2240},{-1139,2241},{-1140,2242}}
for index = 1, #max_mournfen_tail do
	local actual = max_mournfen[#max_mournfen - #max_mournfen_tail + index]
	assert(actual.x == max_mournfen_tail[index][1] and
		actual.z == max_mournfen_tail[index][2])
end
print("WP40 T2 R16 max-u64 transitions direct/elbow=" .. max_u64_direct .. "/" ..
	max_u64_elbows .. " land_010:to E/W/T=" .. max_transition.e.x .. ":" ..
	max_transition.e.z .. "/" .. max_transition.w.x .. ":" ..
	max_transition.w.z .. "/" .. max_transition.point.x .. ":" ..
	max_transition.point.z)
r16_max.compiled = max_u64_compiled
r16_max.oracle_world = max_u64_world
r16_max.seed = max_u64_seed
r16_max.transition_expectations = max_u64_transition_expectations
r16_max.banks = max_u64_banks
r16_max.wings = max_u64_wings
r16_max.edges = max_u64_edges
r16_max.r7_edges = max_u64_selected_r7
r16_max.apertures = max_u64_apertures
r16_max.envelopes = max_u64_envelopes
return bank_results
end)()
local prefix = {}
for index = 1, branch_index + 3, 2 do
	prefix[#prefix + 1] = {x = hearthpine[index], z = hearthpine[index + 1]}
end
assert(prefix[#prefix - 1].x == previous[1] and
	prefix[#prefix - 1].z == previous[2] and prefix[#prefix].x == current[1] and
	prefix[#prefix].z == current[2])
local seen_columns, seen_states, seen_diagonals = {}, {}, {}
for index = 1, #prefix do
	seen_columns[oracle_key(prefix[index].x, prefix[index].z)] = true
	if index > 1 then
		seen_states[oracle_key(prefix[index - 1].x, prefix[index - 1].z) .. ">" ..
			oracle_key(prefix[index].x, prefix[index].z)] = true
		local cell, slope = oracle_diagonal(prefix[index - 1], prefix[index])
		if cell then assert(not seen_diagonals[cell] or seen_diagonals[cell] == slope)
			seen_diagonals[cell] = slope end
	end
end
local oracle = assert(bay_oracle_by_id["bay_elandor_west"])
local back_x, back_z = previous[1] - current[1], previous[2] - current[2]
local back_index
for index = 1, 8 do
	if oracle_clockwise[index].x == back_x and oracle_clockwise[index].z == back_z then
		back_index = index
		break
	end
end
assert(back_index)
local admissible = {}
for offset = 1, 8 do
	local direction_index = ((back_index - offset - 1) % 8) + 1
	local direction = oracle_clockwise[direction_index]
	local following = {x = current[1] + direction.x, z = current[2] + direction.z}
	local following_key = oracle_key(following.x, following.z)
	local directed_key = oracle_key(current[1], current[2]) .. ">" .. following_key
	local cell, slope = oracle_diagonal({x = current[1], z = current[2]}, following)
	if following_key ~= oracle_key(previous[1], previous[2]) and
			not seen_states[directed_key] and not seen_columns[following_key] and
			(not cell or not seen_diagonals[cell] or seen_diagonals[cell] == slope) and
			oracle_candidate(oracle, following.x, following.z) and
			oracle_water_right(oracle, {x = current[1], z = current[2]}, following) then
		admissible[#admissible + 1] = following
	end
end
assert(#admissible == 2 and admissible[1].x == successor_a[1] and
	admissible[1].z == successor_a[2] and admissible[2].x == successor_b[1] and
	admissible[2].z == successor_b[2],
	"R12 independent ordered admissible successors changed")

local selected_path, alternate_path = {}, {}
for index = 1, #hearthpine, 2 do
	selected_path[#selected_path + 1] = {x = hearthpine[index], z = hearthpine[index + 1]}
end
for index = 1, #prefix do
	alternate_path[#alternate_path + 1] = {x = prefix[index].x, z = prefix[index].z}
end
alternate_path[#alternate_path + 1] = {x = successor_b[1], z = successor_b[2]}
for index = branch_index + 8, #hearthpine, 2 do
	alternate_path[#alternate_path + 1] = {x = hearthpine[index],
		z = hearthpine[index + 1]}
end
local function validate_oracle_path(points, first_edge, label)
	local columns, diagonals = {}, {}
	for index = 1, #points do
		local point_key = oracle_key(points[index].x, points[index].z)
		assert(not columns[point_key], label .. " repeats a station")
		columns[point_key] = true
		if index > 1 then
			local from, to = points[index - 1], points[index]
			assert(math.max(math.abs(to.x - from.x), math.abs(to.z - from.z)) == 1,
				label .. " is not eight-connected")
			local cell, slope = oracle_diagonal(from, to)
			if cell then
				assert(not diagonals[cell] or diagonals[cell] == slope,
					label .. " X-crosses")
				diagonals[cell] = slope
			end
			if index - 1 >= first_edge then
				assert(oracle_candidate(oracle, to.x, to.z),
					label .. " leaves the candidate set")
				assert(oracle_water_right(oracle, from, to),
					label .. " loses water-right")
			end
		end
	end
end
validate_oracle_path(selected_path, #prefix, "selected A path")
validate_oracle_path(alternate_path, #prefix, "alternate B path")
assert(#alternate_path == #selected_path - 1 and
	alternate_path[#alternate_path].x == selected_path[#selected_path].x and
	alternate_path[#alternate_path].z == selected_path[#selected_path].z,
	"R12 alternate B path does not reach the declared terminal")

-- Targeted Bank corruptions exercise the independent predicates themselves.
-- The complete all-20 byte comparison above is necessary but is not used as a
-- substitute for these shape-preserving semantic rejection witnesses.
local function run_bank_corruption_kats()
	local calls = 0
	local selected, rank = compiler.select_first_reachable({"A", "B", "C"},
		function(_, index)
			calls = calls + 1
			if index == 1 then return false end
			if index == 2 then return true end
			error("later successor must not be evaluated")
		end)
	assert(selected == "B" and rank == 2 and calls == 2)
	selected, rank = compiler.select_first_reachable({"A", "B"}, function(_, index)
		if index == 1 then return true end
		error("later successor must not be evaluated")
	end)
	assert(selected == "A" and rank == 1)
	local function copy_points(points)
		local result = {}
		for index = 1, #points do
			result[index] = {x = points[index].x, z = points[index].z}
		end
		return result
	end
	local function foreign_contact(bay_oracle, point)
		for index = 1, 4 do
			local direction = oracle_cardinal[index]
			local x, z = point.x + direction.x, point.z + direction.z
			local class = oracle_footprint_class(x, z)
			if class >= 0 and oracle_planned_water(x, z, class == 0) and
					not oracle_bay_water(bay_oracle, x, z) then return true end
		end
		return false
	end
	local function validate_step(bay_oracle, from, to)
		if math.max(math.abs(to.x - from.x), math.abs(to.z - from.z)) ~= 1 then
			error("Bank step is not eight-connected")
		end
		if not oracle_water_right(bay_oracle, from, to) then
			error("Bank step loses water-right")
		end
		return true
	end
	local function validate_structure(points)
		local columns, diagonals = {}, {}
		for index = 1, #points do
			local point = points[index]
			local point_key = oracle_key(point.x, point.z)
			if columns[point_key] then error("Bank path repeats a station") end
			columns[point_key] = true
			if index > 1 then
				if math.max(math.abs(point.x - points[index - 1].x),
						math.abs(point.z - points[index - 1].z)) ~= 1 then
					error("Bank step is not eight-connected")
				end
				local cell, slope = oracle_diagonal(points[index - 1], point)
				if cell and diagonals[cell] and diagonals[cell] ~= slope then
					error("Bank path X-crosses")
				end
				if cell then diagonals[cell] = slope end
			end
		end
		return true
	end
	local function validate_station(bay_oracle, point)
		if foreign_contact(bay_oracle, point) then
			error("Bank path contacts foreign water")
		end
		if not oracle_candidate(bay_oracle, point.x, point.z) then
			error("Bank path leaves candidate set")
		end
		return true
	end
	local function validate_geometry(points)
		validate_structure(points)
		for index = 1, #points do
			validate_station(oracle, points[index])
			if index > 1 then validate_step(oracle, points[index - 1], points[index]) end
		end
		return true
	end
	local function validate_selected(points)
		if points[1].x ~= selected_path[1].x or points[1].z ~= selected_path[1].z or
				points[#points].x ~= selected_path[#selected_path].x or
				points[#points].z ~= selected_path[#selected_path].z then
			error("Bank terminal changed")
		end
		validate_geometry(points)
		if #points ~= #selected_path then error("Bank did not retain first reachable") end
		for index = 1, #points do
			if points[index].x ~= selected_path[index].x or
					points[index].z ~= selected_path[index].z then
				error("Bank did not retain first reachable")
			end
		end
		return true
	end
	assert(validate_selected(selected_path))
	expect_error("first reachable", function() validate_selected(alternate_path) end)
	expect_error("Bank terminal changed", function()
		local corrupted = copy_points(selected_path)
		corrupted[1], corrupted[#corrupted] = corrupted[#corrupted], corrupted[1]
		validate_selected(corrupted)
	end)
	expect_error("repeats a station", function()
		local corrupted = copy_points(selected_path)
		corrupted[10] = {x = corrupted[9].x, z = corrupted[9].z}
		validate_selected(corrupted)
	end)
	expect_error("leaves candidate set", function()
		validate_station(oracle, {x = 0, z = 0})
	end)
	local wrong_side
	for point_index = 1, #selected_path - 1 do
		local from = selected_path[point_index]
		for direction_index = 1, 8 do
			local direction = oracle_clockwise[direction_index]
			local candidate = {x = from.x + direction.x, z = from.z + direction.z}
			if oracle_candidate(oracle, candidate.x, candidate.z) and
					not oracle_water_right(oracle, from, candidate) then
				wrong_side = {from = from, to = candidate}
				break
			end
		end
		if wrong_side then break end
	end
	assert(wrong_side, "Bank water-side corruption fixture disappeared")
	expect_error("loses water-right", function()
		validate_step(oracle, wrong_side.from, wrong_side.to)
	end)
	local foreign, foreign_oracle
	for bay_index = 1, #bay_oracles do
		local candidate_oracle = bay_oracles[bay_index]
		for other_index = 1, #source.bays do
			if source.bays[other_index].id ~= candidate_oracle.source.id then
				for station_index = 1, #source.bays[other_index].centreline do
					local centre = source.bays[other_index].centreline[station_index]
					for direction_index = 1, 4 do
						local direction = oracle_cardinal[direction_index]
						local point = {x = centre.x - direction.x,
							z = centre.z - direction.z}
						if foreign_contact(candidate_oracle, point) then
							foreign, foreign_oracle = point, candidate_oracle
							break
						end
					end
					if foreign then break end
				end
			end
			if foreign then break end
		end
		if foreign then break end
	end
	assert(foreign, "Bank foreign-contact corruption fixture disappeared")
	expect_error("contacts foreign water", function()
		validate_station(foreign_oracle, foreign)
	end)
	expect_error("Bank path X-crosses", function()
		validate_structure({{x = -1321, z = -2832}, {x = -1320, z = -2831},
			{x = -1321, z = -2831}, {x = -1320, z = -2832}})
	end)
end
run_bank_corruption_kats()

-- Exactly eight edge transitions retain zero-offset endpoint identity.
local transition_ids, transition_count = {}, 0
for index = 1, #compiled.families.land_boundaries do
	local edge = compiled.families.land_boundaries[index]
	local count = maybe_named_scalar(edge, "unsigned_values", "bank_transition_count")
	if count then
		local ids = named_array_value(edge, "text_arrays", "bank_transition_ids")
		local endpoints = named_array_value(edge, "text_arrays", "bank_transition_endpoints")
		local positions = signed_array(edge, "bank_transition_xz")
		local offsets = named_array_value(edge, "unsigned_arrays", "bank_transition_offsets")
		local stations = signed_array(edge, "stations_xz")
		assert(#ids == count and #endpoints == count and #positions == count * 2 and
			#offsets == count)
		for transition_index = 1, count do
			assert(offsets[transition_index] == 0 and not transition_ids[ids[transition_index]])
			transition_ids[ids[transition_index]] = true
			local endpoint_offset = endpoints[transition_index] == "from" and 1 or
				#stations - 1
			assert(positions[transition_index * 2 - 1] == stations[endpoint_offset] and
				positions[transition_index * 2] == stations[endpoint_offset + 1])
			transition_count = transition_count + 1
		end
	end
end
assert(transition_count == 8)

-- The production-consumed R16 selector and assembly seam is closed,
-- fail-closed, alias-free, and reversal-identical.
do
local transition_e = {x = -1140, z = 2241}
local transition_w = {x = -1139, z = 2242}
local synthetic_raw_water = false
assert(not synthetic_raw_water and compiler.transition_water_owned(true, true) and
	not compiler.transition_water_owned(false, true) and
	not compiler.transition_water_owned(true, false),
	"R17 filled W was not consumed as final same-Bay water")
expect_error("water evidence", function()
	compiler.transition_water_owned(true, 1)
end)
local transition_fallback = {id = "synthetic transition", e = transition_e,
	direct_candidate = false, e_strict_dry = true, e_cardinal_water = false,
	w = transition_w, w_owned_by_bay = true, w_foreign_water = false,
	elbow_valid = {true, true}}
local transition_selected = compiler.select_edge_transition(transition_fallback)
assert(transition_selected.mode == "diagonal_elbow" and
	transition_selected.point.x == -1140 and transition_selected.point.z == 2242 and
	transition_selected.elbows[2].x == -1139 and
	transition_selected.elbows[2].z == 2241)
local transition_direct = compiler.select_edge_transition({id = "synthetic direct",
	e = transition_e, direct_candidate = true})
assert(transition_direct.mode == "direct" and
	transition_direct.point.x == transition_e.x and
	transition_direct.point.z == transition_e.z)
for _, mutate in ipairs({
	function(row) row.extra = true end,
	function(row) row.e_strict_dry = false end,
	function(row) row.e_cardinal_water = true end,
	function(row) row.w = {x = row.e.x + 2, z = row.e.z + 1} end,
	function(row) row.w_owned_by_bay = false end,
	function(row) row.w_foreign_water = true end,
	function(row) row.elbow_valid[1] = false end,
}) do
	local corrupted = {}
	for field, value in pairs(transition_fallback) do
		if field == "e" or field == "w" then
			corrupted[field] = {x = value.x, z = value.z}
		elseif field == "elbow_valid" then
			corrupted[field] = {value[1], value[2]}
		else corrupted[field] = value end
	end
	mutate(corrupted)
	expect_error("transition", function() compiler.select_edge_transition(corrupted) end)
end
expect_error("unknown field", function()
	compiler.select_edge_transition({id = "synthetic direct", e = transition_e,
		direct_candidate = true, extra = false})
end)
local retained_controls = {{x = -1142, z = 2241}, {x = -1141, z = 2241},
	{x = transition_e.x, z = transition_e.z}}
local retained_before = raster_signature(retained_controls)
local forward_controls = compiler.add_edge_transition_control(retained_controls,
	transition_selected, "to", transition_e)
assert(raster_signature(retained_controls) == retained_before,
	"transition assembly mutated caller controls")
expect_error("direct transition", function()
	compiler.add_edge_transition_control(retained_controls,
		{mode = "direct", point = {x = transition_e.x + 1, z = transition_e.z}},
		"to", transition_e)
end)
expect_error("unknown field", function()
	compiler.add_edge_transition_control(retained_controls,
		{mode = "direct", point = transition_e, extra = function() end}, "to",
		transition_e)
end)
for _, corrupt in ipairs({
	{mode = "diagonal_elbow", point = transition_selected.elbows[2],
		w = transition_selected.w, elbows = transition_selected.elbows},
	{mode = "diagonal_elbow", point = transition_selected.point,
		w = transition_selected.w,
		elbows = {transition_selected.elbows[2], transition_selected.elbows[1]}},
	{mode = "diagonal_elbow", point = transition_selected.point,
		w = {x = transition_selected.w.x + 1, z = transition_selected.w.z},
		elbows = transition_selected.elbows},
}) do
	expect_error("elbow transition", function()
		compiler.add_edge_transition_control(retained_controls, corrupt, "to",
			transition_e)
	end)
end
local forward_transition_raster = raster.final_raster(forward_controls, false)
local reversed_controls = compiler.reverse_materialized(retained_controls)
local backward_controls = compiler.add_edge_transition_control(reversed_controls,
	transition_selected, "from", transition_e)
local backward_transition_raster = raster.final_raster(backward_controls, false)
assert(#forward_transition_raster == #backward_transition_raster)
for index = 1, #forward_transition_raster do
	local reverse_index = #backward_transition_raster - index + 1
	assert(forward_transition_raster[index].x ==
		backward_transition_raster[reverse_index].x and
		forward_transition_raster[index].z ==
		backward_transition_raster[reverse_index].z)
end
expect_error("repeats station", function()
	local repeated = compiler.add_edge_transition_control({
		{x = transition_selected.point.x, z = transition_selected.point.z},
		{x = transition_e.x, z = transition_e.z}}, transition_selected, "to",
		transition_e)
	local final = raster.final_raster(repeated, false)
	raster.validate_final({id = "synthetic repeated transition", kind = "land_edge",
		closed = false, max_displacement = 2}, repeated, final)
end)
expect_error("X-cross", function()
	local crossed = {{x = 0, z = 0}, {x = 1, z = 1}, {x = 0, z = 1},
		{x = 1, z = 0}}
	raster.validate_final({id = "synthetic crossed transition", kind = "land_edge",
		closed = false, max_displacement = 2}, crossed, crossed)
end)
end

local expected_tail_counts = {{4,3},{4,5},{5,4},{3,4},{2,3},{5,4},{4,5},{5,4}}
for index = 1, 8 do
	local wing = compiled.families.closure_wings[index]
	assert(named_scalar(wing, "unsigned_values", "negative_tail_station_count") ==
		expected_tail_counts[index][1] and
		named_scalar(wing, "unsigned_values", "positive_tail_station_count") ==
		expected_tail_counts[index][2])
end

-- R13's seed-selected pre-partition pair predicate is independently
-- corruption-tested below; final dry-edge topology is completed by Banks.
local selected_r7_pair_count = 0
for junction_index = 1, #source.relief_junctions do
	local junction = source.relief_junctions[junction_index]
	for left_index = 1, #junction.incident_edge_ids - 1 do
		for right_index = left_index + 1, #junction.incident_edge_ids do
			assert(compiler.validate_junction_pair(junction.position,
				assert(selected_r7_edge_by_id[junction.incident_edge_ids[left_index]]).stations,
				assert(selected_r7_edge_by_id[junction.incident_edge_ids[right_index]]).stations,
				"independent selected R7 " .. junction.id))
			selected_r7_pair_count = selected_r7_pair_count + 1
		end
	end
end
assert(#source.land_edges == 61 and selected_r7_pair_count == 102)
assert(compiler.validate_junction_pair({x = 0, z = 0},
	{{x = 0, z = 0}, {x = 1, z = 0}, {x = 2, z = 1}},
	{{x = 0, z = 0}, {x = 0, z = 1}, {x = 1, z = 1}}, "pair KAT"))
expect_error("share a nonjunction station", function()
	compiler.validate_junction_pair({x = 0, z = 0},
		{{x = 0, z = 0}, {x = 1, z = 0}},
		{{x = 0, z = 0}, {x = 0, z = 1}, {x = 1, z = 0}}, "pair overlap KAT")
end)
expect_error("opposing diagonal X-cross", function()
	compiler.validate_junction_pair({x = 0, z = 0},
		{{x = 0, z = 0}, {x = 1, z = 0}, {x = 2, z = 1}},
		{{x = 0, z = 0}, {x = 0, z = 1}, {x = 1, z = 1}, {x = 2, z = 0}},
		"pair X KAT")
end)
local clipped_footprint = exact.polygon_index({{x = 0, z = 0}, {x = 6, z = 0},
	{x = 6, z = 2}, {x = 0, z = 2}, {x = 0, z = 0}})
local separated_boxes = {{min_x = 0, max_x = 1, min_z = -1, max_z = 3},
	{min_x = 5, max_x = 6, min_z = -1, max_z = 3}}
local envelope_count = compiler.count_trace_envelope(separated_boxes,
	clipped_footprint, "separated fixture")
local duplicate_boxes = {separated_boxes[1], separated_boxes[2], separated_boxes[1]}
assert(envelope_count == 12 and compiler.count_trace_envelope(duplicate_boxes,
	clipped_footprint, "dedup fixture") == envelope_count)
local enclosing_rectangle_clipped_count = 7 * 3
assert(enclosing_rectangle_clipped_count == 21 and
	enclosing_rectangle_clipped_count ~= envelope_count)
local trace_bounds = compiler.trace_bounds(envelope_count)
assert(trace_bounds.reachability_frames == 96 and trace_bounds.stack_depth == 12 and
	trace_bounds.main_steps == 11 and
	compiler.validate_trace_counters(trace_bounds, 96, 12, 11))
expect_error("frame cap exhausted", function()
	compiler.validate_trace_counters(trace_bounds, 97, 12, 11)
end)
expect_error("stack cap exhausted", function()
	compiler.validate_trace_counters(trace_bounds, 96, 13, 11)
end)
expect_error("main trace cap exhausted", function()
	compiler.validate_trace_counters(trace_bounds, 96, 12, 12)
end)
expect_error("exact Lua integer range", function()
	compiler.trace_bounds(exact.MAX_SAFE)
end)

-- M11: scalar samples are keyed pre-displacement geometry-source identities,
-- not an array aligned with rerastered or attachment-clipped final stations.
-- Ordinary records use literal Source controls; the four checksum-declared
-- departures use their derived effective control copy without mutating Source.
local function source_by_id(rows, id)
	for index = 1, #rows do if rows[index].id == id then return rows[index] end end
	error("missing source record " .. id)
end
local scalar_alignment_mismatch = false
for _, family in ipairs({
	{compiled.families.land_boundaries, source.land_edges, "control", false},
	{compiled.families.perimeters, source.perimeters, "polygon", true},
	{compiled.families.islands, source.islands, "polygon", true},
}) do
	for row_index = 1, #family[1] do
		local row = family[1][row_index]
		local authored = source_by_id(family[2], row.id)
		local control = family[2] == source.land_edges and
			(effective_land_control[authored.id] or authored[family[3]]) or
			authored[family[3]]
		local source_stations = raster.authored_stations(control, family[4])
		local sample_count = named_scalar(row, "unsigned_values", "scalar_sample_count")
		local final_count = named_scalar(row, "unsigned_values", "station_count")
		local ceiling_nodes = named_scalar(row, "unsigned_values",
			"topology_ceiling_nodes")
		local sample_xz = named_array_value(row, "signed_arrays", "scalar_sample_xz")
		local scalar_q = named_array_value(row, "signed_arrays", "scalar_q")
		local source_segment = named_array_value(row, "unsigned_arrays",
			"scalar_source_segment")
		local local_station = named_array_value(row, "unsigned_arrays",
			"scalar_local_station")
		assert(sample_count == #source_stations and #sample_xz == sample_count * 2 and
			#scalar_q == sample_count and #source_segment == sample_count and
			#local_station == sample_count and ceiling_nodes >= 0 and
			ceiling_nodes <= authored.max_displacement)
		if sample_count ~= final_count then scalar_alignment_mismatch = true end
		local expected, observed = {}, {}
		for station_index = 1, #source_stations do
			local station = source_stations[station_index]
			local identity = station.source_segment .. ":" .. station.local_station
			assert(not expected[identity])
			expected[identity] = station.x .. ":" .. station.z
		end
		for sample_index = 1, sample_count do
			local identity = source_segment[sample_index] .. ":" ..
				local_station[sample_index]
			assert(not observed[identity] and expected[identity] ==
				sample_xz[sample_index * 2 - 1] .. ":" .. sample_xz[sample_index * 2])
			observed[identity] = true
			exact.integer(scalar_q[sample_index], -exact.MAX_SAFE, exact.MAX_SAFE,
				"compiled scalar sample")
			assert(math.abs(scalar_q[sample_index]) <= ceiling_nodes * deterministic.Q)
		end
		for identity in pairs(expected) do assert(observed[identity]) end
		local departure = derived_departure_by_edge[row.id]
		if departure then
			local expected_identity
			for station_index = 1, #source_stations do
				if source_stations[station_index].x == departure.point.x and
						source_stations[station_index].z == departure.point.z then
					assert(not expected_identity, "D repeats in effective authored stations")
					expected_identity = source_stations[station_index].source_segment .. ":" ..
						source_stations[station_index].local_station
				end
			end
			assert(expected_identity, "D absent from effective authored stations")
			local compiled_matches = 0
			for sample_index = 1, sample_count do
				if sample_xz[sample_index * 2 - 1] == departure.point.x and
						sample_xz[sample_index * 2] == departure.point.z then
					compiled_matches = compiled_matches + 1
					assert(source_segment[sample_index] .. ":" ..
						local_station[sample_index] == expected_identity and
						scalar_q[sample_index] == 0)
				end
			end
			assert(compiled_matches == 1, "D is not one exact zero scalar sample")
			assert(named_scalar(row, "text_values", "junction_departure_id") ==
				departure.source.id and
				named_scalar(row, "text_values", "junction_departure_endpoint") ==
				departure.source.edge_endpoint and
				named_scalar(row, "signed_values", "junction_departure_x") ==
				departure.point.x and
				named_scalar(row, "signed_values", "junction_departure_z") ==
				departure.point.z and
				named_scalar(row, "unsigned_values", "effective_control_count") ==
				#effective_land_control[row.id])
		else
			assert(maybe_named_scalar(row, "text_values", "junction_departure_id") == nil)
		end
	end
end
assert(scalar_alignment_mismatch,
	"scalar samples accidentally imply alignment with final station arrays")

-- Mouth apertures are one maximal, nonwrapping half-open run in the exact
-- canonical perimeter order. Equality is Bay water only in that run; both
-- adjacent equality stations are outside the aperture and dry.
local expected_aperture_width = {720, 660, 640, 740}
local aperture_station_owner = {}
for aperture_index = 1, #compiled.families.mouth_apertures do
	local row = compiled.families.mouth_apertures[aperture_index]
	local bay_id = named_scalar(row, "text_values", "bay_id")
	local perimeter_id = named_scalar(row, "text_values", "perimeter_id")
	local bay = by_id(compiled.families.bays, bay_id)
	local perimeter = by_id(compiled.families.perimeters, perimeter_id)
	local perimeter_values = signed_array(perimeter, "stations_xz")
	local perimeter_count = named_scalar(perimeter, "unsigned_values", "station_count")
	local first = named_scalar(row, "unsigned_values", "first")
	local finish = named_scalar(row, "unsigned_values", "finish")
	local count = named_scalar(row, "unsigned_values", "station_count")
	assert(first > 0 and finish < perimeter_count and finish > first and
		count == finish - first and named_scalar(row, "unsigned_values",
			"analytic_width") == expected_aperture_width[aperture_index])
	local endpoints = signed_array(row, "endpoints_xz")
	assert(endpoints[1] == perimeter_values[first * 2 + 1] and
		endpoints[2] == perimeter_values[first * 2 + 2] and
		endpoints[3] == perimeter_values[finish * 2 - 1] and
		endpoints[4] == perimeter_values[finish * 2])
	for station_zero = first, finish - 1 do
		local coordinate = station_zero * 2 + 1
		local x, z = perimeter_values[coordinate], perimeter_values[coordinate + 1]
		assert(payload_bay_member(bay, x, z))
		local station_key = perimeter_id .. ":" .. station_zero
		assert(not aperture_station_owner[station_key])
		aperture_station_owner[station_key] = row.id
	end
	local before_coordinate = first * 2 - 1
	local excluded_coordinate = finish * 2 + 1
	assert(not payload_bay_member(bay, perimeter_values[before_coordinate],
		perimeter_values[before_coordinate + 1]) and
		not payload_bay_member(bay, perimeter_values[excluded_coordinate],
			perimeter_values[excluded_coordinate + 1]))
end

local function independent_segment_parts(displaced, control_count)
	local result = {}
	for segment_index = 0, control_count - 2 do
		local controls = {}
		for station_index = 1, #displaced.base_stations do
			local station = displaced.base_stations[station_index]
			if station.source_segment == segment_index or
					station.source_segment == segment_index - 1 and
					station.local_station == station.local_last then
				controls[#controls + 1] = displaced.shifted_controls[station.authored_order]
			end
		end
		if segment_index == control_count - 2 then
			controls[#controls + 1] = displaced.shifted_controls[1]
		end
		assert(#controls >= 2)
		result[segment_index + 1] = raster.final_raster(controls, false)
	end
	return result
end
local function independent_fixed_closure(authored)
	if not authored.r7_fixed_closure then return nil end
	local union, seen = {}, {}
	for ref_index = 1, #authored.r7_fixed_closure.edge_refs do
		local ref = authored.r7_fixed_closure.edge_refs[ref_index]
		local edge = assert(source_by_id(source.land_edges, ref.edge_id))
		assert(edge.max_displacement == 0)
		local part = raster.final_raster(edge.control, false)
		if ref.direction == "reverse" then
			local reversed = {}
			for index = #part, 1, -1 do
				reversed[#reversed + 1] = {x = part[index].x, z = part[index].z}
			end
			part = reversed
		else assert(ref.direction == "forward") end
		if #union > 0 then assert(union[#union].x == part[1].x and
			union[#union].z == part[1].z) end
		for point_index = 1, #part do
			local point = part[point_index]
			if #union == 0 or union[#union].x ~= point.x or union[#union].z ~= point.z then
				local key = oracle_key(point.x, point.z)
				assert(not seen[key]) seen[key] = true
				union[#union + 1] = {x = point.x, z = point.z}
			end
		end
	end
	assert(#union == 5001)
	return union
end
local function same_point_bytes(a, b)
	if #a ~= #b then return false end
	for index = 1, #a do
		if a[index].x ~= b[index].x or a[index].z ~= b[index].z then return false end
	end
	return true
end
local function closed_control_transform(points, offset, reverse_order)
	local count = #points
	if count > 1 and points[1].x == points[count].x and
			points[1].z == points[count].z then count = count - 1 end
	assert(count >= 3 and offset >= 0 and offset < count)
	local result = {}
	for step = 0, count - 1 do
		local source_index
		if reverse_order then
			source_index = (offset - step) % count + 1
		else
			source_index = (offset + step) % count + 1
		end
		result[#result + 1] = {x = points[source_index].x,
			z = points[source_index].z}
	end
	result[#result + 1] = {x = result[1].x, z = result[1].z}
	return result
end
local function scalar_bytes_by_point(displaced)
	local result = {}
	for index = 1, #displaced.scalar_samples do
		local sample = displaced.scalar_samples[index]
		result[oracle_key(sample.x, sample.z)] = sample.scalar_q
	end
	return result
end
local function assert_displacement_geometry_equal(left, right, label)
	local left_stations = raster.canonical_closed(left.stations)
	local right_stations = raster.canonical_closed(right.stations)
	assert(same_point_bytes(left_stations, right_stations),
		label .. " final canonical station bytes changed")
	local left_scalar, right_scalar = scalar_bytes_by_point(left),
		scalar_bytes_by_point(right)
	for key, value in pairs(left_scalar) do
		assert(right_scalar[key] == value, label .. " scalar byte changed at " .. key)
	end
	for key in pairs(right_scalar) do
		assert(left_scalar[key] ~= nil, label .. " gained scalar sample at " .. key)
	end
end
local independent_perimeter_by_id, legacy_perimeter_by_id = {}, {}
for index = 1, #source.perimeters do
	local authored = source.perimeters[index]
	local kind = authored.kind == "fixed_land_band" and "fixed" or "mainland_coast"
	local definition = {id = authored.id, kind = kind,
		control = authored.polygon, closed = true, orientation = authored.orientation,
		noise_domain = authored.noise_domain, max_displacement = authored.max_displacement,
		envelope = source.constants.mainland_frame}
	local closure = independent_fixed_closure(authored)
	local legacy
	if closure then
		legacy = raster.displace(definition, "0", independent_no_jitter)
		legacy.segment_parts = independent_segment_parts(legacy, #authored.polygon)
		legacy_perimeter_by_id[authored.id] = legacy
		definition.fixed_closure = closure
	end
	local displaced = raster.displace(definition, "0", independent_no_jitter)
	displaced.canonical_stations = raster.canonical_closed(displaced.stations)
	displaced.segment_parts = independent_segment_parts(displaced, #authored.polygon)
	if closure then
		for segment_index = 1, 26 do
			assert(same_point_bytes(displaced.segment_parts[segment_index],
				legacy.segment_parts[segment_index]),
				authored.id .. " H55 changed an ordinary coast segment")
		end
		assert(same_point_bytes(displaced.segment_parts[27], closure),
			authored.id .. " fixed closure output bytes changed")
		local scalar_by_key = {}
		for sample_index = 1, #displaced.scalar_samples do
			local sample = displaced.scalar_samples[sample_index]
			scalar_by_key[oracle_key(sample.x, sample.z)] = sample.scalar_q
		end
		for point_index = 1, #closure do
			assert(scalar_by_key[oracle_key(closure[point_index].x,
				closure[point_index].z)] == 0,
				authored.id .. " fixed closure scalar is nonzero")
		end
		assert(legacy.topology_ceiling_nodes == 3 and
			displaced.topology_ceiling_nodes == legacy.topology_ceiling_nodes,
			authored.id .. " H55 record-wide ceiling changed")
		for _, transform in ipairs({{offset = 8, reverse = false},
				{offset = 13, reverse = true}}) do
			local transformed = raster.displace({id = authored.id,
				kind = kind, control = closed_control_transform(authored.polygon,
					transform.offset, transform.reverse), closed = true,
				orientation = transform.reverse and
					(authored.orientation == "clockwise" and "counterclockwise" or
					"clockwise") or authored.orientation,
				noise_domain = authored.noise_domain,
				max_displacement = authored.max_displacement,
				fixed_closure = closure, envelope = source.constants.mainland_frame},
				"0", independent_no_jitter)
			assert(transformed.topology_ceiling_nodes == displaced.topology_ceiling_nodes)
			assert_displacement_geometry_equal(displaced, transformed,
				authored.id .. (transform.reverse and " reversed" or " rotated"))
			local tagged = 0
			for station_index = 1, #transformed.base_stations do
				if transformed.base_stations[station_index].fixed_closure then
					tagged = tagged + 1
				end
			end
			assert(tagged == #closure,
				authored.id .. " transformed fixed-closure endpoint tags changed")
		end
		print(("WP40 T2 H55 %s record-wide ceiling legacy/new=%d/%d"):format(
			authored.id, legacy.topology_ceiling_nodes,
			displaced.topology_ceiling_nodes))
	end
	displaced.canonical_indices = {}
	for station_index = 1, #displaced.canonical_stations do
		displaced.canonical_indices[oracle_key(displaced.canonical_stations[station_index].x,
			displaced.canonical_stations[station_index].z)] = station_index
	end
	local payload = by_id(compiled.families.perimeters, authored.id)
	local payload_values = signed_array(payload, "stations_xz")
	assert(#payload_values == (#displaced.canonical_stations + 1) * 2)
	for station_index = 1, #displaced.canonical_stations do
		assert(payload_values[station_index * 2 - 1] ==
			displaced.canonical_stations[station_index].x and
			payload_values[station_index * 2] ==
			displaced.canonical_stations[station_index].z)
	end
	independent_perimeter_by_id[authored.id] = displaced
end
local function materialize_independent_perimeters(seed, compiled_value)
	local result = {}
	for index = 1, #source.perimeters do
		local authored = source.perimeters[index]
		local definition = {id = authored.id,
			kind = authored.kind == "fixed_land_band" and "fixed" or "mainland_coast",
			control = authored.polygon, closed = true, orientation = authored.orientation,
			noise_domain = authored.noise_domain,
			max_displacement = authored.max_displacement,
			envelope = source.constants.mainland_frame,
			fixed_closure = independent_fixed_closure(authored)}
		local displaced = raster.displace(definition, seed, independent_no_jitter)
		displaced.canonical_stations = raster.canonical_closed(displaced.stations)
		displaced.canonical_indices = {}
		for station_index = 1, #displaced.canonical_stations do
			local point = displaced.canonical_stations[station_index]
			displaced.canonical_indices[oracle_key(point.x, point.z)] = station_index
		end
		displaced.segment_parts = independent_segment_parts(displaced, #authored.polygon)
		local payload = by_id(compiled_value.families.perimeters, authored.id)
		local values = signed_array(payload, "stations_xz")
		assert(#values == (#displaced.canonical_stations + 1) * 2)
		for station_index = 1, #displaced.canonical_stations do
			assert(values[station_index * 2 - 1] ==
				displaced.canonical_stations[station_index].x and
				values[station_index * 2] == displaced.canonical_stations[station_index].z)
		end
		result[authored.id] = displaced
	end
	return result
end
do
	local authored = source.perimeters[1]
	local closure = assert(independent_fixed_closure(authored))
	local definition = {id = "h55_corruption", kind = "mainland_coast",
		control = authored.polygon, closed = true, orientation = authored.orientation,
		noise_domain = authored.noise_domain, max_displacement = authored.max_displacement,
		fixed_closure = closure, envelope = source.constants.mainland_frame}
	expect_error("does not match one complete source segment", function()
		local corrupted = {}
		for index = 1, #closure do
			if index ~= math.floor(#closure / 2) then
				corrupted[#corrupted + 1] = {x = closure[index].x, z = closure[index].z}
			end
		end
		definition.fixed_closure = corrupted
		raster.displace(definition, "0", independent_no_jitter)
	end)
	expect_error("station array is not dense", function()
		local corrupted = {}
		for index = 1, #closure do corrupted[index] = closure[index] end
		corrupted.extra = true
		definition.fixed_closure = corrupted
		raster.displace(definition, "0", independent_no_jitter)
	end)
	expect_error("matches more than one source segment", function()
		local duplicate = {{x = 0, z = 0}, {x = 4, z = 0}, {x = 0, z = 0},
			{x = 4, z = 0}, {x = 0, z = 4}, {x = 0, z = 0}}
		raster.displace({id = "h55_duplicate", kind = "fixed", control = duplicate,
			closed = true, orientation = "counterclockwise", noise_domain = "fixed",
			max_displacement = 0, fixed_closure = raster.segment(duplicate[1], duplicate[2]),
			envelope = source.constants.mainland_frame}, "0", {})
	end)
end
local function derive_attachment_oracles(oracle_world, r7_edges, perimeters)
	local function independent_dry_land(point)
		local class = oracle_world.footprint_class(point.x, point.z)
		return class >= 0 and not oracle_world.planned_water(point.x, point.z, class == 0)
	end
	local result = {}
	for index = 1, #source.perimeter_attachments do
		local attachment = source.perimeter_attachments[index]
		local edge = assert(r7_edges[attachment.edge_id])
		local retained = {}
		for station_index = 1, #edge.stations do
			if independent_dry_land(edge.stations[station_index]) then
				retained[#retained + 1] = station_index
			end
		end
		assert(#retained > 0)
		for retained_index = 2, #retained do
			assert(retained[retained_index] == retained[retained_index - 1] + 1)
		end
		local e_index = attachment.retained_run == "suffix" and retained[1] or
			retained[#retained]
		local e = edge.stations[e_index]
		local perimeter = assert(perimeters[attachment.perimeter_id])
		local candidates = assert(perimeter.segment_parts[
			attachment.perimeter_segment_index])
		local best, best_distance, best_index
		for candidate_index = 1, #candidates do
			local candidate = candidates[candidate_index]
			local distance = math.max(math.abs(e.x - candidate.x),
				math.abs(e.z - candidate.z))
			local canonical_index = assert(perimeter.canonical_indices[
				oracle_key(candidate.x, candidate.z)])
			if not best or distance < best_distance or distance == best_distance and
					canonical_index < best_index then
				best, best_distance, best_index = candidate, distance, canonical_index
			end
		end
		assert(best and best_distance <= 1)
		local seam_best, seam_distance, seam_index = compiler.select_attachment_station(e,
			candidates, perimeter.canonical_indices)
		assert(seam_best.x == best.x and seam_best.z == best.z and
			seam_distance == best_distance and seam_index == best_index)
		local retained_controls = {}
		for control_index = 1, #edge.shifted_controls do
			if independent_dry_land(edge.shifted_controls[control_index]) then
				retained_controls[#retained_controls + 1] = control_index
			end
		end
		assert(#retained_controls > 0)
		for control_index = 2, #retained_controls do
			assert(retained_controls[control_index] ==
				retained_controls[control_index - 1] + 1)
		end
		local controls, opposite = {}, nil
		if attachment.edge_endpoint == "from" then
			assert(attachment.retained_run == "suffix")
			controls[1] = {x = best.x, z = best.z}
			for control_index = 1, #retained_controls do
				local point = edge.shifted_controls[retained_controls[control_index]]
				controls[#controls + 1] = {x = point.x, z = point.z}
			end
			opposite = edge.stations[retained[#retained]]
			controls[#controls + 1] = {x = opposite.x, z = opposite.z}
		else
			assert(attachment.edge_endpoint == "to" and
				attachment.retained_run == "prefix")
			opposite = edge.stations[retained[1]]
			controls[1] = {x = opposite.x, z = opposite.z}
			for control_index = 1, #retained_controls do
				local point = edge.shifted_controls[retained_controls[control_index]]
				controls[#controls + 1] = {x = point.x, z = point.z}
			end
			controls[#controls + 1] = {x = best.x, z = best.z}
		end
		local final = raster.final_raster(controls, false)
		result[attachment.id] = {e = {x = e.x, z = e.z},
			a = {x = best.x, z = best.z}, distance = best_distance,
			canonical_index = best_index, controls = controls, final = final,
			opposite = {x = opposite.x, z = opposite.z}}
	end
	return result
end
local attachment_oracle_by_id = derive_attachment_oracles(seed0_oracle_world,
	selected_r7_edge_by_id, independent_perimeter_by_id)

do
	local chosen, distance, index = compiler.select_attachment_station({x = 0, z = 0},
		{{x = 0, z = 1}, {x = 1, z = 0}}, {['0:1'] = 9, ['1:0'] = 3})
	assert(chosen.x == 1 and chosen.z == 0 and distance == 1 and index == 3)
	expect_error("distance exceeds one", function()
		compiler.select_attachment_station({x = 0, z = 0}, {{x = 2, z = 0}},
			{['2:0'] = 1})
	end)
end

-- Eight attachment records carry every later equality/span authority, while E
-- remains private selection evidence.  A is both the declared edge terminal
-- and the referenced canonical final-perimeter station.
local attachment_by_edge, attachment_count = {}, 0
for index = 1, #compiled.families.land_boundaries do
	local row = compiled.families.land_boundaries[index]
	local attachment_id = maybe_named_scalar(row, "text_values", "attachment_id")
	if attachment_id then
		attachment_count = attachment_count + 1
		attachment_by_edge[row.id] = row
		assert(maybe_named_scalar(row, "signed_values", "attachment_e_x") == nil and
			maybe_named_scalar(row, "signed_values", "attachment_e_z") == nil)
	end
end
assert(attachment_count == 8)
for index = 1, #source.perimeter_attachments do
	local authored = source.perimeter_attachments[index]
	local row = assert(attachment_by_edge[authored.edge_id])
	assert(named_scalar(row, "text_values", "attachment_id") == authored.id)
	assert(named_scalar(row, "text_values", "attachment_edge_endpoint") ==
		authored.edge_endpoint)
	assert(named_scalar(row, "text_values", "attachment_perimeter_id") ==
		authored.perimeter_id)
	assert(named_scalar(row, "text_values", "attachment_retained_run") ==
		authored.retained_run)
	assert(named_scalar(row, "text_values", "attachment_before_span_id") ==
		authored.canonical_before_span_id)
	assert(named_scalar(row, "text_values", "attachment_after_span_id") ==
		authored.canonical_after_span_id)
	assert(named_scalar(row, "unsigned_values",
		"attachment_perimeter_segment_index") ==
		authored.perimeter_segment_index - 1)
	local ax = named_scalar(row, "signed_values", "attachment_a_x")
	local az = named_scalar(row, "signed_values", "attachment_a_z")
	local edge_values = signed_array(row, "stations_xz")
	local expected = assert(attachment_oracle_by_id[authored.id])
	assert(ax == expected.a.x and az == expected.a.z and
		named_scalar(row, "unsigned_values", "attachment_canonical_index") ==
			expected.canonical_index - 1 and #edge_values == #expected.final * 2)
	for station_index = 1, #expected.final do
		assert(edge_values[station_index * 2 - 1] == expected.final[station_index].x and
			edge_values[station_index * 2] == expected.final[station_index].z)
	end
	local terminal_offset = authored.edge_endpoint == "from" and 1 or
		#edge_values - 1
	assert(edge_values[terminal_offset] == ax and edge_values[terminal_offset + 1] == az)
	local perimeter = by_id(compiled.families.perimeters, authored.perimeter_id)
	local perimeter_values = signed_array(perimeter, "stations_xz")
	local canonical_index = named_scalar(row, "unsigned_values",
		"attachment_canonical_index")
	assert(perimeter_values[canonical_index * 2 + 1] == ax and
		perimeter_values[canonical_index * 2 + 2] == az)
end

-- Shape-preserving payload corruptions must not escape the independent E -> A
-- reconstruction above.  This validator deliberately consumes Source plus the
-- independently rerasterized result, not Production's private selection state.
local function run_attachment_corruption_kats()
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[copy(key)] = copy(child) end
		return result
	end
	local function set_scalar(row, family, name, value)
		for index = 1, #row[family] do
			if row[family][index].name == name then
				row[family][index].value = value
				return
			end
		end
		error("missing Attachment scalar " .. name)
	end
	local function set_stations(row, points)
		local values = {}
		for index = 1, #points do
			values[#values + 1] = points[index].x
			values[#values + 1] = points[index].z
		end
		for index = 1, #row.signed_arrays do
			if row.signed_arrays[index].name == "stations_xz" then
				row.signed_arrays[index].values = values
				return
			end
		end
		error("missing Attachment stations")
	end
	local function validate(row, authored, expected)
		if named_scalar(row, "text_values", "attachment_id") ~= authored.id or
				named_scalar(row, "text_values", "attachment_edge_endpoint") ~=
				authored.edge_endpoint or named_scalar(row, "text_values",
				"attachment_perimeter_id") ~= authored.perimeter_id then
			error("Attachment identity changed")
		end
		if named_scalar(row, "text_values", "attachment_retained_run") ~=
				authored.retained_run then error("Attachment retained run changed") end
		if named_scalar(row, "unsigned_values",
				"attachment_perimeter_segment_index") ~=
				authored.perimeter_segment_index - 1 then
			error("Attachment perimeter segment changed")
		end
		if named_scalar(row, "signed_values", "attachment_a_x") ~= expected.a.x or
				named_scalar(row, "signed_values", "attachment_a_z") ~= expected.a.z or
				named_scalar(row, "unsigned_values", "attachment_canonical_index") ~=
				expected.canonical_index - 1 then error("Attachment A changed") end
		local values = signed_array(row, "stations_xz")
		if #values ~= #expected.final * 2 then error("Attachment reraster changed") end
		for index = 1, #expected.final do
			if values[index * 2 - 1] ~= expected.final[index].x or
					values[index * 2] ~= expected.final[index].z then
				error("Attachment reraster changed")
			end
		end
		return true
	end
	for index = 1, #source.perimeter_attachments do
		local authored = source.perimeter_attachments[index]
		assert(validate(assert(attachment_by_edge[authored.edge_id]), authored,
			assert(attachment_oracle_by_id[authored.id])))
	end
	local authored = source.perimeter_attachments[1]
	local expected = assert(attachment_oracle_by_id[authored.id])
	local original = assert(attachment_by_edge[authored.edge_id])
	expect_error("Attachment A changed", function()
		local row = copy(original)
		set_scalar(row, "signed_values", "attachment_a_x", expected.a.x + 1)
		validate(row, authored, expected)
	end)
	expect_error("Attachment perimeter segment changed", function()
		local row = copy(original)
		set_scalar(row, "unsigned_values", "attachment_perimeter_segment_index",
			authored.perimeter_segment_index)
		validate(row, authored, expected)
	end)
	expect_error("Attachment retained run changed", function()
		local row = copy(original)
		set_scalar(row, "text_values", "attachment_retained_run",
			authored.retained_run == "prefix" and "suffix" or "prefix")
		validate(row, authored, expected)
	end)
	expect_error("Attachment reraster changed", function()
		local row = copy(original)
		local changed = copy(expected.final)
		changed[math.floor(#changed / 2)].x = changed[math.floor(#changed / 2)].x + 1
		set_stations(row, changed)
		validate(row, authored, expected)
	end)
	local control_authored, control_expected, changed_raster
	for attachment_index = 1, #source.perimeter_attachments do
		local candidate_authored = source.perimeter_attachments[attachment_index]
		local candidate_expected = assert(attachment_oracle_by_id[candidate_authored.id])
		for control_index = 2, #candidate_expected.controls - 1 do
			local changed_controls = copy(candidate_expected.controls)
			table.remove(changed_controls, control_index)
			local candidate_raster = raster.final_raster(changed_controls, false)
			local differs = #candidate_raster ~= #candidate_expected.final
			if not differs then
				for index = 1, #candidate_raster do
					if candidate_raster[index].x ~= candidate_expected.final[index].x or
							candidate_raster[index].z ~= candidate_expected.final[index].z then
						differs = true
						break
					end
				end
			end
			if differs then
				control_authored, control_expected, changed_raster = candidate_authored,
					candidate_expected, candidate_raster
				break
			end
		end
		if changed_raster then break end
	end
	assert(changed_raster, "Attachment control-removal corruption was not discriminating")
	expect_error("Attachment reraster changed", function()
		local row = copy(assert(attachment_by_edge[control_authored.edge_id]))
		set_stations(row, changed_raster)
		validate(row, control_authored, control_expected)
	end)
end
run_attachment_corruption_kats()

local zone_numeric = {}
for index = 1, #source.zones do
	zone_numeric[source.zones[index].id] = source.zones[index].numeric_id
end
for bay_index = 1, #source.bays do
	local authored = source.bays[bay_index]
	local row = by_id(compiled.families.bays, authored.id)
	local shore = named_array_value(row, "text_arrays", "shore_zone_ids")
	local shore_numeric = named_array_value(row, "unsigned_arrays",
		"shore_zone_numeric_ids")
	assert(#shore == #authored.shore_zone_ids and #shore_numeric == #shore)
	for index = 1, #shore do
		assert(shore[index] == authored.shore_zone_ids[index] and
			shore_numeric[index] == zone_numeric[shore[index]])
	end
	local first = named_array_value(row, "unsigned_arrays",
		"owner_span_first_segments")
	local finish = named_array_value(row, "unsigned_arrays",
		"owner_span_last_segments")
	local left = named_array_value(row, "text_arrays", "owner_left_zone_ids")
	local right = named_array_value(row, "text_arrays", "owner_right_zone_ids")
	local left_numeric = named_array_value(row, "unsigned_arrays",
		"owner_left_zone_numeric_ids")
	local right_numeric = named_array_value(row, "unsigned_arrays",
		"owner_right_zone_numeric_ids")
	assert(#first == #authored.owner_spans and #finish == #first and
		#left == #first and #right == #first)
	for index = 1, #first do
		local span = authored.owner_spans[index]
		assert(first[index] == span.first_segment - 1 and
			finish[index] == span.last_segment - 1 and
			left[index] == span.left_zone_id and right[index] == span.right_zone_id and
			left_numeric[index] == zone_numeric[left[index]] and
			right_numeric[index] == zone_numeric[right[index]])
	end
end
local owner_bay = by_id(compiled.families.bays, "bay_elandor_west")
local owner = compiler.bay_owner(owner_bay, -957, -2766)
assert(owner.zone_id == "elandor_hearthpine_vale" and owner.side > 0)
owner = compiler.bay_owner(owner_bay, -923, -2774)
assert(owner.zone_id == "elandor_dawnmere_fields" and owner.side < 0)
owner = compiler.bay_owner(owner_bay, -940, -2770)
assert(owner.zone_id == "elandor_hearthpine_vale" and owner.side == 0)
local tied
owner, _, _, tied = compiler.bay_owner(owner_bay, -628, -2664)
assert(owner.zone_id == "elandor_dawnmere_fields" and
	owner.segment_index == 0 and tied)

local expected_coast_owners = {
	"elandor_stormvault_heights", "elandor_frostbarrow_shelf",
	"elandor_copperfell_foothills", "elandor_hearthpine_vale",
	"elandor_dawnmere_fields", "elandor_silverleaf_glades",
	"elandor_starbough_vale", "elandor_moonfall_wood",
	"elandor_glassroot_wilds", "kragmar_blackwind_rise",
	"kragmar_ossuary_reach", "kragmar_mournfen", "kragmar_stillgrave_hollow",
	"kragmar_sunscar_flats", "kragmar_kapok_cradle", "kragmar_raincall_basin",
	"kragmar_totemwater_reach", "kragmar_thunderroot_wilds",
	"front_gravesalt_escarpment", "front_skyglass_canopy",
	"front_wyrmglass_crown", "front_stormscale_summit",
}
local coast_roster = source.geometry_policies.world_partition.
	coast_source_allowed_component_ids
assert(#coast_roster == 22)
for index = 1, 22 do
	local row = compiled.families.coast_shelf[index]
	assert(row.id == coast_roster[index] and
		named_scalar(row, "text_values", "zone_id") == expected_coast_owners[index] and
		row.numeric_id == zone_numeric[expected_coast_owners[index]])
	if index <= 18 then
		assert(row.id:match("^perimeter_span:"))
	elseif index == 19 then assert(row.id == "face_arc:gravesalt:holy_west")
	elseif index == 20 then assert(row.id == "face_arc:skyglass:holy_east")
	elseif index == 21 then assert(row.id == "face_arc:wyrmglass:island")
	else assert(row.id == "face_arc:stormscale:island") end
	local values = signed_array(row, "stations_xz")
	local count = named_scalar(row, "unsigned_values", "station_count")
	local closed = named_scalar(row, "boolean_values", "closed")
	assert(closed == (index > 20) and #values == 2 * (count + (closed and 1 or 0)))
	for coordinate = 1, #values - 2, 2 do
		local dx = math.abs(values[coordinate + 2] - values[coordinate])
		local dz = math.abs(values[coordinate + 3] - values[coordinate + 1])
		assert(math.max(dx, dz) == 1)
	end
	if closed then
		assert(values[1] == values[#values - 1] and values[2] == values[#values])
	else
		assert(values[1] ~= values[#values - 1] or values[2] ~= values[#values])
	end
end
compiler.validate_coast_payload(compiled.families.coast_shelf)
for _, fixture in ipairs({
	{"zone_face:front_wyrmglass_crown", "face_arc:wyrmglass:island"},
	{"zone_face:front_stormscale_summit", "face_arc:stormscale:island"},
}) do
	local face_values = signed_array(by_id(compiled.families.dry_faces,
		fixture[1]), "polygon_xz")
	local coast_values = signed_array(by_id(compiled.families.coast_shelf,
		fixture[2]), "stations_xz")
	assert(#face_values == #coast_values)
	for index = 1, #face_values do assert(face_values[index] == coast_values[index]) end
	local polygon = {}
	for index = 1, #face_values, 2 do
		polygon[#polygon + 1] = {x = face_values[index], z = face_values[index + 1]}
	end
	assert(polygon[1].x == polygon[#polygon].x and
		polygon[1].z == polygon[#polygon].z and
		exact.signed_area2(polygon) > 0 and exact.polygon_simple(polygon))
end

for index = 21, 22 do
	local component = compiled.families.coast_shelf[index]
	local values = signed_array(component, "stations_xz")
	local selected, numerator, denominator = compiler.coast_source(
		compiled.families.coast_shelf, values[1], values[2])
	assert(selected.component_id == component.id and numerator == 0 and denominator == 1)
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	assert(not seen[value])
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do result[deep_copy(key, seen)] = deep_copy(child, seen) end
	return result
end

-- M56/H55/C1: reconstruct every final coast component from Source plus the
-- seed-parametric independent perimeter/Attachment authority.  The compiled
-- R9 evaluator is deliberately not involved in this geometry-byte oracle.
r16_max.coast_oracle = (function()
local function independent_attachment_points(perimeters, attachments)
	local result = {}
	for _, attachment in ipairs(source.perimeter_attachments) do
		local perimeter = assert(perimeters[attachment.perimeter_id])
		if not perimeter.canonical_stations then
			perimeter.canonical_stations = raster.canonical_closed(perimeter.stations)
		end
		if not perimeter.canonical_indices then
			perimeter.canonical_indices = {}
			for index = 1, #perimeter.canonical_stations do
				local point = perimeter.canonical_stations[index]
				perimeter.canonical_indices[oracle_key(point.x, point.z)] = index
			end
		end
		local e = assert(attachments[attachment.id]).e
		local candidates = assert(perimeter.segment_parts[
			attachment.perimeter_segment_index])
		local best, best_distance, best_index
		for index = 1, #candidates do
			local point = candidates[index]
			local distance = math.max(math.abs(e.x - point.x), math.abs(e.z - point.z))
			local canonical_index = assert(perimeter.canonical_indices[
				oracle_key(point.x, point.z)])
			if not best or distance < best_distance or distance == best_distance and
					canonical_index < best_index then
				best, best_distance, best_index = point, distance, canonical_index
			end
		end
		assert(best and best_distance <= 1)
		result[attachment.id] = {x = best.x, z = best.z}
	end
	return result
end
local function independent_span_rows(perimeters, attachment_points)
	local result = {}
	for _, span in ipairs(source.perimeter_spans) do
		local perimeter = assert(perimeters[span.perimeter_id])
		local function boundary_point(boundary)
			if boundary.kind == "perimeter_attachment" then
				return assert(attachment_points[boundary.attachment_id])
			end
			assert(boundary.kind == "perimeter_vertex" and
				boundary.perimeter_id == span.perimeter_id)
			return assert(assert(perimeter.segment_parts[boundary.index])[1])
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
			points[#points].z == last.z, span.id .. " independent span is absent")
		if span.face_direction == "reverse" then
			local reversed = {}
			for index = #points, 1, -1 do reversed[#reversed + 1] = points[index] end
			points = reversed
		else assert(span.face_direction == "forward") end
		result[span.id] = {id = span.id, zone_id = span.zone_id,
			closed = false, stations = points}
	end
	return result
end
local face_arc_by_id = {}
for _, arc in ipairs(source.face_arcs) do face_arc_by_id[arc.id] = arc end
local function build_independent_coast(seed, perimeters, attachments)
	local attachment_points = independent_attachment_points(perimeters, attachments)
	local spans = independent_span_rows(perimeters, attachment_points)
	local by_component_id = {}
	for id, row in pairs(spans) do by_component_id[id] = row end
	for _, id in ipairs({"face_arc:gravesalt:holy_west",
			"face_arc:skyglass:holy_east"}) do
		local arc = assert(face_arc_by_id[id])
		assert(#arc.authority_components == 1)
		local component = arc.authority_components[1]
		assert(component.kind == "literal_arc" and component.boundary_role == "fixed_holy")
		by_component_id[id] = {id = id, zone_id = arc.zone_id, closed = false,
			stations = raster.final_raster(component.control, false)}
	end
	for _, id in ipairs({"face_arc:wyrmglass:island",
			"face_arc:stormscale:island"}) do
		local arc = assert(face_arc_by_id[id])
		assert(#arc.authority_components == 1)
		local component = arc.authority_components[1]
		assert(component.kind == "literal_arc" and component.boundary_role == "island_coast")
		local island = assert(source_by_id(source.islands, component.source_ref))
		local displaced = raster.displace({id = island.id, kind = "island_coast",
			control = island.polygon, closed = true, orientation = island.orientation,
			noise_domain = island.noise_domain, max_displacement = island.max_displacement,
			envelope = {center = island.center, radius_x = island.envelope.radius_x,
				radius_z = island.envelope.radius_z}}, seed, independent_no_jitter)
		by_component_id[id] = {id = id, zone_id = arc.zone_id, closed = true,
			stations = displaced.stations}
	end
	local rows = {}
	for index = 1, #coast_roster do
		rows[index] = assert(by_component_id[coast_roster[index]])
	end
	return rows, spans, attachment_points
end
local independent_attachment_points_current = independent_attachment_points(
	independent_perimeter_by_id, attachment_oracle_by_id)
local independent_attachment_points_legacy = independent_attachment_points(
	legacy_perimeter_by_id, attachment_oracle_by_id)
for id, point in pairs(independent_attachment_points_current) do
	local expected = assert(attachment_oracle_by_id[id]).a
	local legacy = assert(independent_attachment_points_legacy[id])
	assert(point.x == expected.x and point.z == expected.z and
		legacy.x == point.x and legacy.z == point.z,
		id .. " H55 changed an independently selected Attachment A")
end
local independent_coast, independent_spans = build_independent_coast("0",
	independent_perimeter_by_id, attachment_oracle_by_id)
local legacy_spans = independent_span_rows(legacy_perimeter_by_id,
	independent_attachment_points_legacy)
for _, span in ipairs(source.perimeter_spans) do
	assert(same_point_bytes(assert(independent_spans[span.id]).stations,
		assert(legacy_spans[span.id]).stations),
		span.id .. " H55 changed final Coast bytes")
end
local function independent_coast_bytes(rows)
	local records = {}
	for index = 1, #rows do
		local row = rows[index]
		local points = {}
		for station_index = 1, #row.stations do
			points[station_index] = row.stations[station_index].x .. ":" ..
				row.stations[station_index].z
		end
		records[index] = table.concat({row.id, row.zone_id,
			row.closed and "1" or "0", #row.stations, table.concat(points, ",")}, ";")
	end
	return table.concat(records, "\n")
end
local function compiled_coast_bytes(payload)
	local records = {}
	for index = 1, #payload do
		local row = payload[index]
		local values = signed_array(row, "stations_xz")
		local closed = named_scalar(row, "boolean_values", "closed")
		local count = named_scalar(row, "unsigned_values", "station_count")
		local points = {}
		for coordinate = 1, count * 2, 2 do
			points[#points + 1] = values[coordinate] .. ":" .. values[coordinate + 1]
		end
		records[index] = table.concat({row.id,
			named_scalar(row, "text_values", "zone_id"), closed and "1" or "0",
			count, table.concat(points, ",")}, ";")
	end
	return table.concat(records, "\n")
end
local function validate_independent_coast(payload, expected)
	if #payload ~= #expected then error("independent Coast roster changed") end
	for index = 1, #expected do
		local actual, wanted = payload[index], expected[index]
		if actual.id ~= wanted.id or named_scalar(actual, "text_values", "zone_id") ~=
				wanted.zone_id or actual.numeric_id ~= zone_numeric[wanted.zone_id] or
				named_scalar(actual, "boolean_values", "closed") ~= wanted.closed or
				named_scalar(actual, "unsigned_values", "station_count") ~=
				#wanted.stations then error("independent Coast identity changed") end
		local values = signed_array(actual, "stations_xz")
		local expected_value_count = (#wanted.stations + (wanted.closed and 1 or 0)) * 2
		if #values ~= expected_value_count then error("independent Coast byte count changed") end
		for station_index = 1, #wanted.stations do
			if values[station_index * 2 - 1] ~= wanted.stations[station_index].x or
					values[station_index * 2] ~= wanted.stations[station_index].z then
				error("independent Coast station bytes changed")
			end
		end
		if wanted.closed and (values[#values - 1] ~= wanted.stations[1].x or
				values[#values] ~= wanted.stations[1].z) then
			error("independent Coast closure byte changed")
		end
	end
	return true
end
local function independent_coast_reduce(n, d)
	if n == 0 then return 0, 1 end
	local a, b = n, d
	while b ~= 0 do a, b = b, a % b end
	return n / a, d / a
end
local function independent_coast_segment_distance(x, z, a, b)
	local dx, dz, px, pz = b.x - a.x, b.z - a.z, x - a.x, z - a.z
	local length = dx * dx + dz * dz
	assert(length > 0)
	local projection = px * dx + pz * dz
	if projection <= 0 then return px * px + pz * pz, 1 end
	if projection >= length then
		local ex, ez = x - b.x, z - b.z
		return ex * ex + ez * ez, 1
	end
	local cross = dx * pz - dz * px
	return independent_coast_reduce(cross * cross, length)
end
local function independent_coast_compare(an, ad, bn, bd)
	local left, right = an * bd, bn * ad
	return left < right and -1 or left > right and 1 or 0
end
local function independent_coast_less(a, b)
	return a.zone_numeric < b.zone_numeric or
		a.zone_numeric == b.zone_numeric and (a.component_id < b.component_id or
			a.component_id == b.component_id and a.segment_index < b.segment_index)
end
local function independent_coast_source(rows, x, z)
	local best, best_n, best_d, ties
	for component_index = 1, #rows do
		local row = rows[component_index]
		local segment_count = row.closed and #row.stations or #row.stations - 1
		for segment_index = 1, segment_count do
			local a = row.stations[segment_index]
			local b = row.stations[segment_index == #row.stations and 1 or segment_index + 1]
			local n, d = independent_coast_segment_distance(x, z, a, b)
			local candidate = {zone_numeric = assert(zone_numeric[row.zone_id]),
				component_id = row.id, segment_index = segment_index - 1}
			local order = best and independent_coast_compare(n, d, best_n, best_d) or -1
			if order < 0 then
				best, best_n, best_d, ties = candidate, n, d, 1
			elseif order == 0 then
				ties = ties + 1
				if independent_coast_less(candidate, best) then best = candidate end
			end
		end
	end
	return best, best_n, best_d, ties
end
local function same_coast_source(a, b)
	return a.zone_numeric == b.zone_numeric and a.component_id == b.component_id and
		a.segment_index == b.segment_index
end
local function validate_independent_coast_evaluator(compiled_value, expected, oracle_world,
		label)
	local payload = compiled_value.families.coast_shelf
	local function compare_query(x, z)
		local wanted, wn, wd, wt = independent_coast_source(expected, x, z)
		local actual, an, ad, at = compiler.coast_source(payload, x, z)
		if not same_coast_source(actual, wanted) or an ~= wn or ad ~= wd or at ~= wt then
			error(label .. " independent Coast selection changed")
		end
		return wn, wd
	end
	for component_index = 1, #expected do
		local points = expected[component_index].stations
		local middle = math.max(1, math.floor(#points / 2))
		compare_query(points[1].x, points[1].z)
		compare_query(points[middle].x, points[middle].z)
		local next_point = points[middle == #points and 1 or middle + 1]
		local dx, dz = next_point.x - points[middle].x, next_point.z - points[middle].z
		compare_query(points[middle].x - dz * 2, points[middle].z + dx * 2)
	end
	local channels = {}
	for index = 1, #compiled_value.families.channels do
		channels[index] = payload_points(compiled_value.families.channels[index], "polygon_xz")
	end
	local function strict_exterior(x, z)
		if oracle_world.footprint_class(x, z) >= 0 then return false end
		for index = 1, #channels do
			if exact.polygon_class(x, z, channels[index]) >= 0 then return false end
		end
		return true
	end
	local fixture
	for component_index = 1, #expected do
		local points = expected[component_index].stations
		local segment_count = expected[component_index].closed and #points or #points - 1
		for segment_index = 1, segment_count do
			local a = points[segment_index]
			local b = points[segment_index == #points and 1 or segment_index + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			if math.abs(dx) + math.abs(dz) == 1 then
				for sign = -1, 1, 2 do
					local candidates, valid = {}, true
					for _, distance in ipairs({1, 80, 81}) do
						local point = {x = a.x - dz * distance * sign,
							z = a.z + dx * distance * sign, distance = distance}
						local _, n, d = independent_coast_source(expected, point.x, point.z)
						if not strict_exterior(point.x, point.z) or n ~= distance * distance or
								d ~= 1 then valid = false break end
						candidates[#candidates + 1] = point
					end
					if valid then fixture = candidates break end
				end
			end
			if fixture then break end
		end
		if fixture then break end
	end
	assert(fixture, label .. " exact exterior Coast 1/80/81 fixture disappeared")
	for index = 1, #fixture do
		local point = fixture[index]
		local n, d = compare_query(point.x, point.z)
		assert(n == point.distance * point.distance and d == 1 and
			compiler.shelf_from_distance(n, d) == (point.distance <= 80),
			label .. " exact exterior Coast class changed at d=" .. point.distance)
	end
	return fixture
end
assert(validate_independent_coast(compiled.families.coast_shelf, independent_coast))
local independent_coast_blob = independent_coast_bytes(independent_coast)
local compiled_coast_blob = compiled_coast_bytes(compiled.families.coast_shelf)
assert(compiled_coast_blob == independent_coast_blob)
local independent_coast_digest = raw_sha256(independent_coast_blob)
local independent_coast_digest_hex = (independent_coast_digest:gsub(".",
	function(byte) return ("%02x"):format(string.byte(byte)) end))
assert(independent_coast_digest ==
	from_hex("0309cd3f2d26705feeb1978ee6ca1903addd7f627bbff12ed816f0960d50e2ac"),
	"independent all-22 Coast digest changed: " .. independent_coast_digest_hex)
print("WP40 T2 M56 all-22 independent Coast SHA256 " ..
	"0309cd3f2d26705feeb1978ee6ca1903addd7f627bbff12ed816f0960d50e2ac")
validate_independent_coast_evaluator(compiled, independent_coast, seed0_oracle_world,
	"Seed0")
do
	local corrupted, found = deep_copy(compiled.families.coast_shelf), false
	for component_index = 1, #corrupted do
		local values = signed_array(corrupted[component_index], "stations_xz")
		local last_station = named_scalar(corrupted[component_index], "unsigned_values",
			"station_count")
		for station_index = 2, last_station - 1 do
			local coordinate = station_index * 2 - 1
			local ax, az = values[coordinate - 2], values[coordinate - 1]
			local bx, bz = values[coordinate], values[coordinate + 1]
			local cx, cz = values[coordinate + 2], values[coordinate + 3]
			for dx = -1, 1 do for dz = -1, 1 do
				local x, z = ax + dx, az + dz
				if not found and (x ~= bx or z ~= bz) and
						math.max(math.abs(x - ax), math.abs(z - az)) == 1 and
						math.max(math.abs(x - cx), math.abs(z - cz)) == 1 and
						(cx - ax) * (z - az) - (cz - az) * (x - ax) ~= 0 then
					local trial = deep_copy(corrupted)
					local trial_values = signed_array(trial[component_index], "stations_xz")
					trial_values[coordinate], trial_values[coordinate + 1] = x, z
					if pcall(compiler.validate_coast_payload, trial) then
						corrupted, found = trial, true
					end
				end
			end end
			if found then break end
		end
		if found then break end
	end
	assert(found, "independent Coast dogleg corruption fixture disappeared")
	expect_error("independent Coast station bytes changed", function()
		validate_independent_coast(corrupted, independent_coast)
	end)
end
return {build = build_independent_coast, bytes = independent_coast_bytes,
	compiled_bytes = compiled_coast_bytes, validate = validate_independent_coast,
	validate_evaluator = validate_independent_coast_evaluator}
end)()

local function run_partition_payload_projection_kats()
	local function validate_face(row, authored)
		if row.record_schema ~= "grug_wp40_dry_face_v1" or row.id ~= authored.id or
				row.numeric_id ~= zone_numeric[authored.zone_id] or
				named_scalar(row, "text_values", "zone_id") ~= authored.zone_id then
			error("dry Face owner projection changed")
		end
		local values = signed_array(row, "polygon_xz")
		if named_scalar(row, "unsigned_values", "station_count") ~= #values / 2 - 1 or
				values[1] ~= values[#values - 1] or values[2] ~= values[#values] then
			error("dry Face polygon projection changed")
		end
		return true
	end
	local function validate_island(row, authored, index)
		if row.record_schema ~= "grug_wp40_island_v1" or row.id ~= authored.id or
				row.numeric_id ~= index or named_scalar(row, "text_values", "zone_id") ~=
				authored.zone_id then error("Island owner projection changed") end
		local values = signed_array(row, "stations_xz")
		if named_scalar(row, "unsigned_values", "station_count") ~= #values / 2 - 1 or
				values[1] ~= values[#values - 1] or values[2] ~= values[#values] then
			error("Island polygon projection changed")
		end
		return true
	end
	local function validate_channel(row, authored, index)
		if row.record_schema ~= "grug_wp40_channel_v1" or row.id ~= authored.id or
				row.numeric_id ~= index then error("Channel id projection changed") end
		if named_scalar(row, "text_values", "island_id") ~= authored.island_id or
				named_scalar(row, "text_values", "mainland_zone_id") ~=
				authored.mainland_zone_id then error("Channel owner projection changed") end
		if named_scalar(row, "unsigned_values", "minimum_hard_width") ~=
				authored.minimum_hard_width or named_scalar(row, "unsigned_values",
				"warning_width") ~= authored.warning_width then
			error("Channel width projection changed")
		end
		local values = signed_array(row, "polygon_xz")
		if #values ~= #authored.polygon * 2 then error("Channel polygon projection changed") end
		for point_index = 1, #authored.polygon do
			if values[point_index * 2 - 1] ~= authored.polygon[point_index].x or
					values[point_index * 2] ~= authored.polygon[point_index].z then
				error("Channel polygon projection changed")
			end
		end
		return true
	end
	for index = 1, #source.zone_faces do
		assert(validate_face(compiled.families.dry_faces[index], source.zone_faces[index]))
	end
	for index = 1, #source.islands do
		assert(validate_island(compiled.families.islands[index], source.islands[index], index))
	end
	for index = 1, #source.channels do
		assert(validate_channel(compiled.families.channels[index], source.channels[index],
			index))
	end
	expect_error("dry Face owner projection changed", function()
		local row = deep_copy(compiled.families.dry_faces[1])
		row.numeric_id = row.numeric_id + 1
		validate_face(row, source.zone_faces[1])
	end)
	expect_error("Island owner projection changed", function()
		local row = deep_copy(compiled.families.islands[1])
		row.text_values[1].value = "front_broken_causeway"
		validate_island(row, source.islands[1], 1)
	end)
	expect_error("Channel id projection changed", function()
		local row = deep_copy(compiled.families.channels[1])
		row.id = "channel_broken"
		validate_channel(row, source.channels[1], 1)
	end)
	expect_error("Channel owner projection changed", function()
		local row = deep_copy(compiled.families.channels[1])
		row.text_values[1].value = "island_stormscale"
		validate_channel(row, source.channels[1], 1)
	end)
	expect_error("Channel width projection changed", function()
		local row = deep_copy(compiled.families.channels[1])
		row.unsigned_values[1].value = row.unsigned_values[1].value + 1
		validate_channel(row, source.channels[1], 1)
	end)
	expect_error("Channel polygon projection changed", function()
		local row = deep_copy(compiled.families.channels[1])
		row.signed_arrays[1].values[1] = row.signed_arrays[1].values[1] + 1
		validate_channel(row, source.channels[1], 1)
	end)
end
run_partition_payload_projection_kats()

local function run_final_edge_incidence_kats()
	local edge_points = {}
	for index = 1, #compiled.families.land_boundaries do
		local row = compiled.families.land_boundaries[index]
		edge_points[row.id] = payload_points(row, "stations_xz")
	end
	local function sequence_count(polygon, sequence)
		local count, first = 0, nil
		for start = 1, #polygon - #sequence + 1 do
			local equal = true
			for offset = 1, #sequence do
				if polygon[start + offset - 1].x ~= sequence[offset].x or
						polygon[start + offset - 1].z ~= sequence[offset].z then
					equal = false
					break
				end
			end
			if equal then count, first = count + 1, first or start end
		end
		return count, first
	end
	local function reversed(points)
		local result = {}
		for index = #points, 1, -1 do
			result[#result + 1] = {x = points[index].x, z = points[index].z}
		end
		return result
	end
	local function validate(faces)
		local face_by_id = {}
		for index = 1, #faces do
			if face_by_id[faces[index].id] then error("final Face record duplicated") end
			face_by_id[faces[index].id] = faces[index]
		end
		local incidence = {}
		for face_index = 1, #source.zone_faces do
			local authored = source.zone_faces[face_index]
			local row = face_by_id[authored.id]
			if not row then error("final Face record deleted") end
			local polygon = payload_points(row, "polygon_xz")
			for component_index = 1, #authored.cycle do
				local component = authored.cycle[component_index]
				if component.kind == "shared_edge" then
					local points = assert(edge_points[component.ref_id])
					local sequence = component.direction == "reverse" and reversed(points) or points
					local count = sequence_count(polygon, sequence)
					if count ~= 1 then error("final Edge incidence bytes changed") end
					local value = incidence[component.ref_id] or {forward = 0, reverse = 0}
					incidence[component.ref_id] = value
					value[component.direction] = value[component.direction] + 1
				end
			end
		end
		local count = 0
		for edge_id in pairs(edge_points) do
			local value = incidence[edge_id]
			if not value or value.forward ~= 1 or value.reverse ~= 1 then
				error("final Edge dual incidence changed")
			end
			count = count + 1
		end
		if count ~= 61 then error("final Edge incidence roster changed") end
		return true
	end
	assert(validate(compiled.families.dry_faces))
	expect_error("final Face record duplicated", function()
		local faces = deep_copy(compiled.families.dry_faces)
		faces[#faces + 1] = deep_copy(faces[1])
		validate(faces)
	end)
	expect_error("final Face record deleted", function()
		local faces = deep_copy(compiled.families.dry_faces)
		table.remove(faces, 1)
		validate(faces)
	end)
	expect_error("final Edge incidence bytes changed", function()
		local faces = deep_copy(compiled.families.dry_faces)
		local values = signed_array(faces[1], "polygon_xz")
		table.remove(values, 3)
		table.remove(values, 3)
		validate(faces)
	end)
	expect_error("final Edge incidence bytes changed", function()
		local faces = deep_copy(compiled.families.dry_faces)
		local values = signed_array(faces[1], "polygon_xz")
		for first = 1, math.floor(#values / 4) do
			local last, offset = #values - first * 2 + 1, first * 2 - 1
			values[offset], values[last] = values[last], values[offset]
			values[offset + 1], values[last + 1] = values[last + 1], values[offset + 1]
		end
		validate(faces)
	end)
end
run_final_edge_incidence_kats()

local function run_final_junction_category_kats()
	local actual = {}
	for index = 1, #compiled.families.land_boundaries do
		local row = compiled.families.land_boundaries[index]
		actual[row.id] = payload_points(row, "stations_xz")
	end
	local dissolved_ids = {['-1050:-2250'] = true, ['950:-2250'] = true,
		['1020:2250'] = true, ['-970:2260'] = true}
	local function point_key(point) return point.x .. ":" .. point.z end
	local function disjoint(left, right, label)
		local stations, diagonals = {}, {}
		for index = 1, #left do
			stations[point_key(left[index])] = true
			if index < #left then
				local cell, slope = oracle_diagonal(left[index], left[index + 1])
				if cell then diagonals[cell] = slope end
			end
		end
		for index = 1, #right do
			if stations[point_key(right[index])] then
				error(label .. " dissolved edges overlap")
			end
			if index < #right then
				local cell, slope = oracle_diagonal(right[index], right[index + 1])
				if cell and diagonals[cell] and diagonals[cell] ~= slope then
					error(label .. " dissolved edges X-cross")
				end
			end
		end
		return true
	end
	local function validate(points_by_id)
		local ordinary, ordinary_pairs, dissolved = 0, 0, 0
		for junction_index = 1, #source.relief_junctions do
			local junction = source.relief_junctions[junction_index]
			local at_endpoint = 0
			for edge_index = 1, #junction.incident_edge_ids do
				local points = assert(points_by_id[junction.incident_edge_ids[edge_index]])
				if point_key(points[1]) == point_key(junction.position) or
						point_key(points[#points]) == point_key(junction.position) then
					at_endpoint = at_endpoint + 1
				end
			end
			if at_endpoint == #junction.incident_edge_ids then
				if dissolved_ids[point_key(junction.position)] then
					error("dissolved junction unexpectedly retained")
				end
				ordinary = ordinary + 1
				for left_index = 1, #junction.incident_edge_ids - 1 do
					for right_index = left_index + 1, #junction.incident_edge_ids do
						compiler.validate_junction_pair(junction.position,
							points_by_id[junction.incident_edge_ids[left_index]],
							points_by_id[junction.incident_edge_ids[right_index]],
							"final ordinary " .. junction.id)
						ordinary_pairs = ordinary_pairs + 1
					end
				end
			elseif at_endpoint == 0 and #junction.incident_edge_ids == 2 then
				if not dissolved_ids[point_key(junction.position)] then
					error("undeclared junction dissolved")
				end
				disjoint(points_by_id[junction.incident_edge_ids[1]],
					points_by_id[junction.incident_edge_ids[2]], junction.id)
				dissolved = dissolved + 1
			else
				error("final junction is mixed")
			end
		end
		if ordinary ~= 34 or ordinary_pairs ~= 98 or dissolved ~= 4 then
			error("final junction category count changed")
		end
		return true
	end
	assert(validate(actual))
	local dissolved = source.relief_junctions[1]
	local mixed = {}
	for id, points in pairs(actual) do mixed[id] = points end
	local edge_id = dissolved.incident_edge_ids[1]
	mixed[edge_id] = {}
	for index = 1, #actual[edge_id] do mixed[edge_id][index] =
		{x = actual[edge_id][index].x, z = actual[edge_id][index].z} end
	mixed[edge_id][1] = {x = dissolved.position.x, z = dissolved.position.z}
	expect_error("final junction is mixed", function() validate(mixed) end)
	local ordinary = source.relief_junctions[3]
	local left = actual[ordinary.incident_edge_ids[1]]
	local right = actual[ordinary.incident_edge_ids[2]]
	expect_error("share a nonjunction station", function()
		local corrupted = {}
		for index = 1, #right do corrupted[index] = {x = right[index].x, z = right[index].z} end
		corrupted[2] = {x = left[2].x, z = left[2].z}
		compiler.validate_junction_pair(ordinary.position, left, corrupted,
			"final ordinary corruption")
	end)
end
run_final_junction_category_kats()

local function run_coast_oracle_kats()
	local function gcd(a, b)
		while b ~= 0 do a, b = b, a % b end
		return a
	end
	local function reduce(n, d)
		if n == 0 then return 0, 1 end
		local divisor = gcd(n, d)
		return n / divisor, d / divisor
	end
	local function distance(x, z, ax, az, bx, bz)
		local dx, dz, px, pz = bx - ax, bz - az, x - ax, z - az
		local length = dx * dx + dz * dz
		assert(length > 0)
		local projection = px * dx + pz * dz
		if projection <= 0 then return px * px + pz * pz, 1 end
		if projection >= length then
			local ex, ez = x - bx, z - bz
			return ex * ex + ez * ez, 1
		end
		local determinant = dx * pz - dz * px
		return reduce(determinant * determinant, length)
	end
	local function compare(an, ad, bn, bd)
		local left, right = an * bd, bn * ad
		return left < right and -1 or left > right and 1 or 0
	end
	local function candidate_less(a, b)
		return a.zone_numeric < b.zone_numeric or
			a.zone_numeric == b.zone_numeric and
				(a.component_id < b.component_id or
				a.component_id == b.component_id and a.segment_index < b.segment_index)
	end
	local function slow(payload, x, z)
		local best, best_n, best_d, ties
		for component_index = 1, #payload do
			local component = payload[component_index]
			local values = signed_array(component, "stations_xz")
			for coordinate = 1, #values - 2, 2 do
				local n, d = distance(x, z, values[coordinate], values[coordinate + 1],
					values[coordinate + 2], values[coordinate + 3])
				local candidate = {zone_numeric = component.numeric_id,
					component_id = component.id, segment_index = (coordinate - 1) / 2}
				local order = best and compare(n, d, best_n, best_d) or -1
				if order < 0 then
					best, best_n, best_d, ties = candidate, n, d, 1
				elseif order == 0 then
					ties = ties + 1
					if candidate_less(candidate, best) then best = candidate end
				end
			end
		end
		return best, best_n, best_d, ties
	end
	local function same(a, b)
		return a.zone_numeric == b.zone_numeric and a.component_id == b.component_id and
			a.segment_index == b.segment_index
	end
	local function compare_query(payload, x, z)
		local wanted, wn, wd, wt = slow(payload, x, z)
		local actual, an, ad, at = compiler.coast_source(payload, x, z)
		assert(same(actual, wanted) and an == wn and ad == wd and at == wt and
			gcd(an, ad) == 1)
		return wanted, wn, wd, wt
	end

	-- Every materialized component contributes real endpoint/body witnesses to
	-- the independent all-22 scan; the offset query prevents a distance-zero-only
	-- test from passing.
	for component_index = 1, #compiled.families.coast_shelf do
		local values = signed_array(compiled.families.coast_shelf[component_index],
			"stations_xz")
		local middle = math.floor((#values / 2 - 1) / 2) * 2 + 1
		if middle > #values - 2 then middle = #values - 2 end
		compare_query(compiled.families.coast_shelf, values[1], values[2])
		compare_query(compiled.families.coast_shelf, values[middle], values[middle + 1])
		local dx, dz = values[middle + 2] - values[middle],
			values[middle + 3] - values[middle + 1]
		compare_query(compiled.families.coast_shelf,
			values[middle] - dz * 2, values[middle + 1] + dx * 2)
	end
	local endpoint_n, endpoint_d = distance(-1, 2, 0, 0, 4, 0)
	local body_n, body_d = distance(1, 1, 0, 0, 2, 1)
	assert(endpoint_n == 5 and endpoint_d == 1 and body_n == 1 and body_d == 5 and
		compare(body_n, body_d, endpoint_n, endpoint_d) < 0)

	local best, n, d, ties = compiler.coast_consider(nil, nil, nil, nil,
		{zone_numeric = 10, component_id = "z", segment_index = 8}, 1, 5)
	best, n, d, ties = compiler.coast_consider(best, n, d, ties,
		{zone_numeric = 1, component_id = "a", segment_index = 1}, 1, 4)
	assert(best.zone_numeric == 10 and n == 1 and d == 5 and ties == 1)
	best, n, d, ties = compiler.coast_consider(best, n, d, ties,
		{zone_numeric = 5, component_id = "z", segment_index = 9}, 2, 10)
	assert(best.zone_numeric == 5 and ties == 2)
	best, n, d, ties = compiler.coast_consider(best, n, d, ties,
		{zone_numeric = 5, component_id = "a", segment_index = 9}, 3, 15)
	assert(best.component_id == "a" and best.segment_index == 9 and ties == 3)
	best, n, d, ties = compiler.coast_consider(best, n, d, ties,
		{zone_numeric = 5, component_id = "a", segment_index = 2}, 4, 20)
	assert(best.segment_index == 2 and ties == 4)

	-- Reversing a component keeps the payload structurally valid but changes its
	-- segment-index authority.  The independent expected selection must reject it.
	local fixture
	for component_index = 1, #compiled.families.coast_shelf do
		local component = compiled.families.coast_shelf[component_index]
		local values = signed_array(component, "stations_xz")
		local point_index = math.min(10, #values / 2 - 2)
		if point_index >= 3 then
			local coordinate = (point_index - 1) * 2 + 1
			local expected, en, ed, et = slow(compiled.families.coast_shelf,
				values[coordinate], values[coordinate + 1])
			if expected.component_id == component.id then
				fixture = {component_index = component_index, x = values[coordinate],
					z = values[coordinate + 1], expected = expected, n = en, d = ed,
					ties = et}
				break
			end
		end
	end
	assert(fixture, "coast selection-corruption fixture disappeared")
	local corrupted = deep_copy(compiled.families.coast_shelf)
	local values = signed_array(corrupted[fixture.component_index], "stations_xz")
	for first = 1, math.floor(#values / 4) do
		local last = #values - first * 2 + 1
		local offset = first * 2 - 1
		values[offset], values[last] = values[last], values[offset]
		values[offset + 1], values[last + 1] = values[last + 1], values[offset + 1]
	end
	compiler.validate_coast_payload(corrupted)
	expect_error("coast selection changed", function()
		local actual, an, ad, at = compiler.coast_source(corrupted, fixture.x, fixture.z)
		if not same(actual, fixture.expected) or an ~= fixture.n or ad ~= fixture.d or
				at ~= fixture.ties then error("coast selection changed") end
	end)
end
run_coast_oracle_kats()

local function run_classification_precedence_kats()
	local function key_xz(x, z) return x .. ":" .. z end
	local actual_mainlands, actual_islands, actual_faces, actual_channels = {}, {}, {}, {}
	for index = 1, 2 do actual_mainlands[index] = exact.polygon_index(payload_points(
		compiled.families.perimeters[index], "stations_xz")) end
	for index = 1, #compiled.families.islands do
		actual_islands[index] = exact.polygon_index(payload_points(
			compiled.families.islands[index], "stations_xz"))
	end
	for index = 1, #compiled.families.dry_faces do
		actual_faces[index] = exact.polygon_index(payload_points(
			compiled.families.dry_faces[index], "polygon_xz"))
	end
	for index = 1, #compiled.families.channels do
		actual_channels[index] = exact.polygon_index(payload_points(
			compiled.families.channels[index], "polygon_xz"))
	end
	local aperture_water = {}
	for index = 1, #compiled.families.mouth_apertures do
		local aperture = compiled.families.mouth_apertures[index]
		local perimeter = by_id(compiled.families.perimeters,
			named_scalar(aperture, "text_values", "perimeter_id"))
		local values = signed_array(perimeter, "stations_xz")
		local first = named_scalar(aperture, "unsigned_values", "first")
		local finish = named_scalar(aperture, "unsigned_values", "finish")
		for station = first, finish - 1 do
			local coordinate = station * 2 + 1
			aperture_water[key_xz(values[coordinate], values[coordinate + 1])] =
				named_scalar(aperture, "text_values", "bay_id")
		end
	end
	local actual_wings = {}
	for index = 1, #compiled.families.closure_wings do
		local row = compiled.families.closure_wings[index]
		actual_wings[index] = {row = row,
			head = {x = named_scalar(row, "signed_values", "head_x"),
				z = named_scalar(row, "signed_values", "head_z")},
			junction = {x = named_scalar(row, "signed_values", "junction_x"),
				z = named_scalar(row, "signed_values", "junction_z")},
			head_half_width = named_scalar(row, "unsigned_values", "head_half_width")}
	end
	local function footprint(x, z)
		for index = 1, #actual_mainlands do
			local class = exact.indexed_polygon_class(actual_mainlands[index], x, z)
			if class >= 0 then return "mainland", class, index end
		end
		local holy = source.constants.holy_grounds
		if x >= holy.min_x and x <= holy.max_x and z >= holy.min_z and z <= holy.max_z then
			return "holy", (x == holy.min_x or x == holy.max_x or z == holy.min_z or
				z == holy.max_z) and 0 or 1, 1
		end
		for index = 1, #actual_islands do
			local class = exact.indexed_polygon_class(actual_islands[index], x, z)
			if class >= 0 then return "island", class, index end
		end
		return nil, -1, nil
	end
	local function rational_compare(an, ad, bn, bd)
		local left, right = an * bd, bn * ad
		return left < right and -1 or left > right and 1 or 0
	end
	local function coast_distance(x, z)
		local best_n, best_d
		for component_index = 1, #compiled.families.coast_shelf do
			local values = signed_array(compiled.families.coast_shelf[component_index],
				"stations_xz")
			for coordinate = 1, #values - 2, 2 do
				local n, d = exact.segment_distance(x, z,
					{x = values[coordinate], z = values[coordinate + 1]},
					{x = values[coordinate + 2], z = values[coordinate + 3]})
				if not best_n or rational_compare(n, d, best_n, best_d) < 0 then
					best_n, best_d = n, d
				end
			end
		end
		return best_n, best_d
	end
	local function independent_reduce(n, d)
		if n == 0 then return 0, 1 end
		local a, b = n, d
		while b ~= 0 do a, b = b, a % b end
		return n / a, d / a
	end
	local function independent_segment_distance(x, z, ax, az, bx, bz)
		local dx, dz, px, pz = bx - ax, bz - az, x - ax, z - az
		local length = dx * dx + dz * dz
		assert(length > 0)
		local projection = px * dx + pz * dz
		if projection <= 0 then return px * px + pz * pz, 1 end
		if projection >= length then
			local ex, ez = x - bx, z - bz
			return ex * ex + ez * ez, 1
		end
		local cross = dx * pz - dz * px
		return independent_reduce(cross * cross, length)
	end
	local function independent_coast_distance(x, z)
		local best_n, best_d
		for component_index = 1, #compiled.families.coast_shelf do
			local values = signed_array(compiled.families.coast_shelf[component_index],
				"stations_xz")
			for coordinate = 1, #values - 2, 2 do
				local n, d = independent_segment_distance(x, z, values[coordinate],
					values[coordinate + 1], values[coordinate + 2], values[coordinate + 3])
				if not best_n or rational_compare(n, d, best_n, best_d) < 0 then
					best_n, best_d = n, d
				end
			end
		end
		return best_n, best_d
	end
	local function actual_classify(x, z)
		local footprint_kind, footprint_class = footprint(x, z)
		if footprint_kind == "mainland" then
			for index = 1, #compiled.families.bays do
				local bay = compiled.families.bays[index]
				if payload_bay_member(bay, x, z) and (footprint_class > 0 or
						aperture_water[key_xz(x, z)] == bay.id) then
					local owner = compiler.bay_owner(bay, x, z)
					local kind, selected = compiler.horizontal_precedence(owner.zone_id, nil,
						footprint_kind, nil, nil, false)
					return {kind = kind, owner = selected, source = bay.id}
				end
			end
			if footprint_class > 0 then
				for index = 1, #actual_wings do
					local wing = actual_wings[index]
					if exact.wing_member(x, z, wing) then
						local dx, dz = wing.junction.x - wing.head.x,
							wing.junction.z - wing.head.z
						local side = dx * (z - wing.head.z) - dz * (x - wing.head.x)
						local owner = side > 0 and named_scalar(wing.row, "text_values",
							"left_zone_id") or side < 0 and named_scalar(wing.row,
							"text_values", "right_zone_id") or named_scalar(wing.row,
							"text_values", "tie_zone_id")
						local kind, selected = compiler.horizontal_precedence(nil, owner,
							footprint_kind, nil, nil, false)
						return {kind = kind, owner = selected, source = wing.row.id}
					end
				end
			end
		end
		if footprint_kind then
			local owner, raw = nil, 0
			for index = 1, #actual_faces do
				if exact.indexed_polygon_class(actual_faces[index], x, z) >= 0 then
					raw = raw + 1
					local row = compiled.families.dry_faces[index]
					if not owner or row.numeric_id < owner.numeric then owner = {
						zone_id = named_scalar(row, "text_values", "zone_id"),
						numeric = row.numeric_id} end
				end
			end
			local kind, selected = compiler.horizontal_precedence(nil, nil,
				footprint_kind, owner and owner.zone_id or nil, nil, false)
			return {kind = kind, owner = selected, raw = raw,
				footprint = footprint_kind, equality = footprint_class == 0}
		end
		for index = 1, #actual_channels do
			if exact.indexed_polygon_class(actual_channels[index], x, z) >= 0 then
				local channel_id = compiled.families.channels[index].id
				local kind, selected = compiler.horizontal_precedence(nil, nil, nil, nil,
					channel_id, false)
				return {kind = kind, source = selected}
			end
		end
		local n, d = coast_distance(x, z)
		local kind = compiler.horizontal_precedence(nil, nil, nil, nil, nil,
			compiler.shelf_from_distance(n, d))
		return {kind = kind, distance_n = n, distance_d = d}
	end
	local function expected_bay_owner(authored, x, z)
		local best, best_n, best_d
		for segment_index = 1, #authored.centreline - 1 do
			local a, b = authored.centreline[segment_index], authored.centreline[segment_index + 1]
			local n, d = exact.segment_distance(x, z, a, b)
			local span
			for span_index = 1, #authored.owner_spans do
				local candidate = authored.owner_spans[span_index]
				if segment_index >= candidate.first_segment and
						segment_index <= candidate.last_segment then span = candidate break end
			end
			assert(span)
			local side = (b.x - a.x) * (z - a.z) - (b.z - a.z) * (x - a.x)
			local owner = side > 0 and span.left_zone_id or side < 0 and
				span.right_zone_id or zone_numeric[span.left_zone_id] <
				zone_numeric[span.right_zone_id] and span.left_zone_id or span.right_zone_id
			local candidate = {zone_id = owner, numeric = zone_numeric[owner]}
			local order = best and rational_compare(n, d, best_n, best_d) or -1
			if order < 0 or order == 0 and candidate.numeric < best.numeric then
				best, best_n, best_d = candidate, n, d
			end
		end
		return best.zone_id
	end
	local function expect_at(x, z, kind, owner, label)
		local actual = actual_classify(x, z)
		assert(actual.kind == kind and (owner == nil or actual.owner == owner),
			label .. " at " .. x .. ":" .. z .. " expected " .. kind .. "/" ..
				tostring(owner) .. " changed: " .. tostring(actual.kind) .. "/" ..
				tostring(actual.owner) .. " source=" .. tostring(actual.source) ..
				" raw=" .. tostring(actual.raw))
		return actual
	end
	local kind, owner = compiler.horizontal_precedence("base_owner", "wing_owner",
		"mainland", "dry_owner", "channel", true)
	assert(kind == "planned_water" and owner == "base_owner")
	kind, owner = compiler.horizontal_precedence(nil, "wing_owner", "mainland",
		"dry_owner", "channel", true)
	assert(kind == "planned_water" and owner == "wing_owner")
	for _, footprint_kind in ipairs({"mainland", "holy", "island"}) do
		kind, owner = compiler.horizontal_precedence(nil, nil, footprint_kind,
			"dry_owner", "channel", true)
		assert(kind == "land" and owner == "dry_owner")
	end
	kind, owner = compiler.horizontal_precedence(nil, nil, nil, nil, "channel", true)
	assert(kind == "immutable_dragon_channel" and owner == "channel")
	kind = compiler.horizontal_precedence(nil, nil, nil, nil, nil, true)
	assert(kind == "coastal_shelf")
	kind = compiler.horizontal_precedence(nil, nil, nil, nil, nil, false)
	assert(kind == "deep_ocean")
	assert(compiler.shelf_from_distance(1, 1) and
		compiler.shelf_from_distance(6400, 1) and
		not compiler.shelf_from_distance(6561, 1))
	expect_error("exact integer range", function() compiler.shelf_from_distance(1, 0) end)
	expect_error("closed footprint lacks a dry owner", function()
		compiler.horizontal_precedence(nil, nil, "island", nil, "channel", true)
	end)

	-- All four canonical aperture equalities retain Base ownership, and their
	-- immediate strict-exterior continuation begins ordinary shelf water.
	for index = 1, #compiled.families.mouth_apertures do
		local aperture = compiled.families.mouth_apertures[index]
		local perimeter = by_id(compiled.families.perimeters,
			named_scalar(aperture, "text_values", "perimeter_id"))
		local values = signed_array(perimeter, "stations_xz")
		local station = named_scalar(aperture, "unsigned_values", "first")
		local coordinate = station * 2 + 1
		local x, z = values[coordinate], values[coordinate + 1]
		local bay_id = named_scalar(aperture, "text_values", "bay_id")
		local authored = assert(bay_source_by_id[bay_id])
		expect_at(x, z, "planned_water", expected_bay_owner(authored, x, z),
			aperture.id .. " equality")
		local outside
		for direction_index = 1, 4 do
			local direction = oracle_cardinal[direction_index]
			if not footprint(x + direction.x, z + direction.z) then
				outside = {x = x + direction.x, z = z + direction.z}
				break
			end
		end
		assert(outside, aperture.id .. " lacks strict exterior neighbor")
		expect_at(outside.x, outside.z, "coastal_shelf", nil,
			aperture.id .. " outside shelf")
	end

	local attachment_keys, vertex_keys = {}, {}
	for index = 1, #source.perimeter_attachments do
		local attachment = source.perimeter_attachments[index]
		local expected = assert(attachment_oracle_by_id[attachment.id])
		attachment_keys[key_xz(expected.a.x, expected.a.z)] = true
		local edge = source_by_id(source.land_edges, attachment.edge_id)
		expect_at(expected.a.x, expected.a.z, "land", edge.tie_zone_id,
			attachment.id .. " equality")
	end
	for index = 1, #source.perimeter_spans do
		local span = source.perimeter_spans[index]
		for _, boundary in ipairs({span.start_boundary, span.end_boundary}) do
			if boundary.kind == "perimeter_vertex" then
				local boundary_key = boundary.perimeter_id .. ":" .. boundary.index
				local value = vertex_keys[boundary_key] or {perimeter_id = boundary.perimeter_id,
					index = boundary.index, zones = {}}
				vertex_keys[boundary_key] = value
				value.zones[#value.zones + 1] = span.zone_id
			end
		end
	end
	for _, vertex in pairs(vertex_keys) do
		if #vertex.zones >= 2 then
			local perimeter = assert(independent_perimeter_by_id[vertex.perimeter_id])
			local segment_part = assert(perimeter.segment_parts[vertex.index],
				vertex.perimeter_id .. " vertex lacks displaced segment " .. vertex.index)
			local point = assert(segment_part[1])
			assert(not attachment_keys[key_xz(point.x, point.z)])
			local bay_id = aperture_water[key_xz(point.x, point.z)]
			if bay_id then
				local authored = assert(bay_source_by_id[bay_id])
				expect_at(point.x, point.z, "planned_water",
					expected_bay_owner(authored, point.x, point.z),
					vertex.perimeter_id .. " aperture-overridden vertex " .. vertex.index)
			else
				local owner = vertex.zones[1]
				for index = 2, #vertex.zones do if zone_numeric[vertex.zones[index]] <
						zone_numeric[owner] then owner = vertex.zones[index] end end
				expect_at(point.x, point.z, "land", owner,
					vertex.perimeter_id .. " unattached vertex " .. vertex.index)
			end
		end
	end
	for index = 1, #source.perimeter_spans do
		local span = source.perimeter_spans[index]
		local component = by_id(compiled.families.coast_shelf, span.id)
		local values = signed_array(component, "stations_xz")
		local found
		for coordinate = 3, #values - 4, 2 do
			local x, z = values[coordinate], values[coordinate + 1]
			local point_key = key_xz(x, z)
			if not aperture_water[point_key] and not attachment_keys[point_key] then
				local classified = actual_classify(x, z)
				if classified.kind == "land" then found = {x = x, z = z} break end
			end
		end
		assert(found, span.id .. " lacks ordinary equality fixture")
		expect_at(found.x, found.z, "land", span.zone_id, span.id .. " equality")
	end
	for index = 1, #source.bays do
		local bay = source.bays[index]
		local point = bay.centreline[2]
		expect_at(point.x, point.z, "planned_water",
			expected_bay_owner(bay, point.x, point.z), bay.id .. " strict Base")
	end
	for index = 1, #source.bay_closure_wings do
		local wing = source.bay_closure_wings[index]
		expect_at(wing.left_probe.x, wing.left_probe.z, "planned_water",
			wing.left_zone_id, wing.id .. " left interior")
		expect_at(wing.right_probe.x, wing.right_probe.z, "planned_water",
			wing.right_zone_id, wing.id .. " right interior")
	end
	for index = 1, #compiled.families.dry_faces do
		local row, polygon_index = compiled.families.dry_faces[index], actual_faces[index]
		local points, found = payload_points(row, "polygon_xz"), nil
		for segment = 1, #points - 1 do
			local a, b = points[segment], points[segment + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local nx, nz = -dz, dx
			for distance = 1, 4 do
				local x, z = a.x + nx * distance, a.z + nz * distance
				if exact.indexed_polygon_class(polygon_index, x, z) > 0 then
					local classified = actual_classify(x, z)
					if classified.kind == "land" then found = {x = x, z = z} break end
				end
			end
			if found then break end
		end
		assert(found, row.id .. " lacks strict dry fixture")
		expect_at(found.x, found.z, "land", named_scalar(row, "text_values", "zone_id"),
			row.id .. " strict dry")
	end
	local holy = source.constants.holy_grounds
	for _, point in ipairs({{x = holy.min_x, z = 0}, {x = holy.max_x, z = 0}}) do
		local classified = expect_at(point.x, point.z, "land", nil, "Holy equality")
		assert(classified.footprint == "holy")
	end
	for index = 1, #compiled.families.islands do
		local values = signed_array(compiled.families.islands[index], "stations_xz")
		local classified = expect_at(values[1], values[2], "land",
			named_scalar(compiled.families.islands[index], "text_values", "zone_id"),
			compiled.families.islands[index].id .. " equality")
		assert(classified.footprint == "island")
	end
	for index = 1, #source.channels do
		local channel = source.channels[index]
		local center_x = (channel.polygon[1].x + channel.polygon[3].x) / 2
		local center_z = (channel.polygon[1].z + channel.polygon[3].z) / 2
		expect_at(center_x, center_z, "immutable_dragon_channel", nil,
			channel.id .. " strict exterior interior")
		local boundary, outside
		for point_index = 1, #channel.polygon - 1 do
			local a, b = channel.polygon[point_index], channel.polygon[point_index + 1]
			local point = {x = (a.x + b.x) / 2, z = (a.z + b.z) / 2}
			local dx, dz = b.x - a.x, b.z - a.z
			local ox = dz > 0 and 1 or dz < 0 and -1 or 0
			local oz = dx > 0 and -1 or dx < 0 and 1 or 0
			local candidate = {x = point.x + ox, z = point.z + oz}
			if not footprint(point.x, point.z) and not footprint(candidate.x,
					candidate.z) and exact.indexed_polygon_class(actual_channels[index],
					point.x, point.z) == 0 and exact.indexed_polygon_class(
					actual_channels[index], candidate.x, candidate.z) < 0 then
				boundary, outside = point, candidate
				break
			end
		end
		assert(boundary and outside)
		expect_at(boundary.x, boundary.z, "immutable_dragon_channel", nil,
			channel.id .. " strict exterior equality")
		local outside_class = actual_classify(outside.x, outside.z)
		local expected_n, expected_d = independent_coast_distance(outside.x, outside.z)
		local expected_kind = rational_compare(expected_n, expected_d, 6400, 1) <= 0 and
			"coastal_shelf" or "deep_ocean"
		assert(outside_class.kind == expected_kind and
			rational_compare(outside_class.distance_n, outside_class.distance_d,
				expected_n, expected_d) == 0,
			channel.id .. " outside boundary coast distance/class changed")
	end
	for _, point in ipairs({{x = holy.min_x, z = 0}, {x = holy.max_x, z = 0}}) do
		assert(actual_classify(point.x, point.z).kind == "land",
			"channel stole Holy/land overlap")
	end

	local distance_fixture
	for component_index = 1, #compiled.families.coast_shelf do
		local values = signed_array(compiled.families.coast_shelf[component_index],
			"stations_xz")
		for coordinate = 1, #values - 2, 40 do
			if coordinate % 2 == 0 then coordinate = coordinate + 1 end
			local x, z = values[coordinate], values[coordinate + 1]
			for direction_index = 1, 4 do
				local direction = oracle_cardinal[direction_index]
				local candidates = {{x = x + direction.x, z = z + direction.z, d = 1},
					{x = x + direction.x * 80, z = z + direction.z * 80, d = 80},
					{x = x + direction.x * 81, z = z + direction.z * 81, d = 81}}
				local valid = true
				for candidate_index = 1, #candidates do
					local candidate = candidates[candidate_index]
					if footprint(candidate.x, candidate.z) then valid = false break end
					local classified = actual_classify(candidate.x, candidate.z)
					local expected_kind = candidate.d <= 80 and "coastal_shelf" or "deep_ocean"
					if classified.kind ~= expected_kind or
							rational_compare(classified.distance_n, classified.distance_d,
								candidate.d * candidate.d, 1) ~= 0 then
						valid = false break
					end
				end
				if valid then distance_fixture = candidates break end
			end
			if distance_fixture then break end
		end
		if distance_fixture then break end
	end
	assert(distance_fixture, "exact shelf 1/80/81 fixture disappeared")
	for index = 1, #distance_fixture do
		local point = distance_fixture[index]
		local classified = expect_at(point.x, point.z,
			point.d <= 80 and "coastal_shelf" or
			"deep_ocean", nil, "exact exterior distance " .. point.d)
		local expected_n, expected_d = independent_coast_distance(point.x, point.z)
		assert(expected_n == point.d * point.d and expected_d == 1 and
			rational_compare(classified.distance_n, classified.distance_d,
				expected_n, expected_d) == 0 and
			compiler.shelf_from_distance(expected_n, expected_d) == (point.d <= 80),
			"exact exterior distance oracle changed at d=" .. point.d)
	end
	local shelf = distance_fixture[1]
	local coast_owner = compiler.coast_source(compiled.families.coast_shelf,
		shelf.x, shelf.z)
	assert(coast_owner and actual_classify(shelf.x, shelf.z).kind == "coastal_shelf",
		"coast dressing changed water membership")
end
run_classification_precedence_kats()

-- H38: normalize every closed final polygon into exact integer row runs, then
-- partition every footprint row at all run boundaries.  Each resulting
-- interval has one constant Base/Wing/Face membership tuple, so its length is
-- an exhaustive proof over the full finite footprint rather than a sample.
local run_exhaustive_partition_oracle = dofile(repo ..
	"/tools/wp40/t2_partition_oracle.lua")({canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256, raster = raster,
	source = source, exact = exact, compiler = compiler, by_id = by_id,
	signed_array = signed_array, named_scalar = named_scalar,
	named_array_value = named_array_value, deep_copy = deep_copy,
	expect_error = expect_error, oracle_cardinal = oracle_cardinal,
	payload_points = payload_points,
	trace_independent_banks_again = trace_independent_banks_again,
	same_point_bytes = same_point_bytes,
	independent_bank_by_id = independent_bank_by_id,
	attachment_oracle_by_id = attachment_oracle_by_id,
	authored_aperture_by_id = authored_aperture_by_id,
	bay_source_by_id = bay_source_by_id, zone_numeric = zone_numeric,
	source_by_id = source_by_id})
local exhaustive_partition_report = run_exhaustive_partition_oracle(
	compiled, "0", seed0_oracle_world, independent_perimeter_by_id,
	{mode = "seed0", bundle = r16_max.seed0})
do
	local max_u64_perimeters = materialize_independent_perimeters(
		assert(r16_max.seed), assert(r16_max.compiled))
	local max_u64_attachments = derive_attachment_oracles(r16_max.oracle_world,
		assert(r16_max.r7_edges), max_u64_perimeters)
	local max_u64_coast = r16_max.coast_oracle.build(r16_max.seed, max_u64_perimeters,
		max_u64_attachments)
	assert(r16_max.coast_oracle.validate(r16_max.compiled.families.coast_shelf,
		max_u64_coast))
	assert(r16_max.coast_oracle.compiled_bytes(r16_max.compiled.families.coast_shelf) ==
		r16_max.coast_oracle.bytes(max_u64_coast))
	r16_max.coast_oracle.validate_evaluator(r16_max.compiled, max_u64_coast,
		r16_max.oracle_world, "max-u64")
	local report = run_exhaustive_partition_oracle(r16_max.compiled,
		r16_max.seed, r16_max.oracle_world, max_u64_perimeters,
		{mode = "max_u64", bundle = r16_max})
	assert(report.g == 0 and report.o == 0 and report.r == 0 and report.m == 0,
		"R16 max-u64 whole-partition report changed")
	r16_max.whole_report = report
end

-- C1 selected-winner mode is injected only by the immutable PUC worker.  The
-- worker supplies no seed argument to this test: it derives one exact ranked
-- winner from the retained artifact and passes this closed in-memory request.
-- Seed0/max-u64 and selected workers therefore consume the same independent
-- Bank preparation and the same extracted exhaustive Whole oracle.
(function(selected_request)
	if not selected_request then return end
	assert(type(selected_request) == "table" and getmetatable(selected_request) == nil and
		type(selected_request.seed) == "string" and selected_request.result == nil)
	local selected_compiled = compiler.compile(selected_request.seed)
	local selected_world = build_independent_oracle_world(selected_compiled)
	local selected_apertures = derive_authored_apertures(selected_compiled)
	local selected_payload, selected_bank_count = extract_bank_payload(selected_compiled)
	assert(selected_bank_count == 20)
	local selected_r7 = materialize_selected_r7(selected_request.seed)
	local selected_authority = r16_max.bank_transition_oracle(
		selected_compiled, selected_world, selected_r7, selected_apertures,
		selected_payload)
	assert(selected_authority.direct + selected_authority.elbows == 8)
	local selected_perimeters = materialize_independent_perimeters(
		selected_request.seed, selected_compiled)
	local selected_attachments = derive_attachment_oracles(selected_world, selected_r7,
		selected_perimeters)
	local selected_coast = r16_max.coast_oracle.build(selected_request.seed,
		selected_perimeters, selected_attachments)
	assert(r16_max.coast_oracle.validate(selected_compiled.families.coast_shelf,
		selected_coast))
	assert(r16_max.coast_oracle.compiled_bytes(selected_compiled.families.coast_shelf) ==
		r16_max.coast_oracle.bytes(selected_coast))
	r16_max.coast_oracle.validate_evaluator(selected_compiled, selected_coast,
		selected_world, "selected winner")
	local selected_bundle = {wings = selected_authority.wings,
		edges = selected_authority.edges, apertures = selected_apertures,
		envelopes = selected_authority.envelopes,
		banks = selected_authority.banks,
		transition_expectations = selected_authority.transition_expectations,
		attachments = selected_attachments}
	local selected_report = run_exhaustive_partition_oracle(selected_compiled,
		selected_request.seed, selected_world, selected_perimeters,
		{mode = "selected", bundle = selected_bundle})
	selected_request.result = {compiled = selected_compiled, report = selected_report,
		transition_count = selected_authority.direct + selected_authority.elbows,
		bank_count = selected_bank_count, wing_count = #selected_compiled.families.closure_wings,
		coast_count = #selected_compiled.families.coast_shelf,
		face_count = #selected_compiled.families.dry_faces}
end)(rawget(_G, "WP40_T2_SELECTED_REQUEST"))

local function expect_coast_corruption(fragment, mutate)
	local payload = deep_copy(compiled.families.coast_shelf)
	mutate(payload)
	expect_error(fragment, function() compiler.validate_coast_payload(payload) end)
end
expect_coast_corruption("roster or schema", function(payload)
	payload[1], payload[2] = payload[2], payload[1]
end)
expect_coast_corruption("roster count", function(payload) table.remove(payload) end)
expect_coast_corruption("owner numeric", function(payload)
	payload[1].numeric_id = payload[1].numeric_id + 1
end)
expect_coast_corruption("owner zone", function(payload)
	payload[1].text_values[1].value = "front_broken_causeway"
end)
expect_coast_corruption("closure changed", function(payload)
	payload[21].boolean_values[1].value = false
end)
expect_coast_corruption("station count or closure", function(payload)
	payload[1].unsigned_values[2].value = payload[1].unsigned_values[2].value + 1
end)
expect_coast_corruption("not nonzero eight-connected", function(payload)
	local values = payload[1].signed_arrays[1].values
	values[3] = values[1] + 2
end)
expect_coast_corruption("station repeats", function(payload)
	local values = payload[1].signed_arrays[1].values
	values[3], values[4] = values[1], values[2]
end)
expect_coast_corruption("record shape", function(payload)
	payload[1].unsafe_callback = function() end
end)
local function expect_bay_corruption(fragment, mutate)
	local payload = deep_copy(owner_bay)
	mutate(payload)
	expect_error(fragment, function() compiler.validate_bay_payload(payload) end)
end
expect_bay_corruption("policy changed", function(payload)
	for index = 1, #payload.text_values do
		if payload.text_values[index].name == "owner_side_rule" then
			payload.text_values[index].value = "float_cross" return
		end
	end
end)
expect_bay_corruption("shore roster changed", function(payload)
	named_array_value(payload, "unsigned_arrays", "shore_zone_numeric_ids")[1] = 38
end)
expect_bay_corruption("centreline changed", function(payload)
	named_array_value(payload, "signed_arrays", "centreline_xz_width")[1] = -979
end)
expect_bay_corruption("owner spans changed", function(payload)
	named_array_value(payload, "unsigned_arrays", "owner_span_last_segments")[1] = 2
end)
expect_bay_corruption("Bay displacement delta", function(payload)
	named_array_value(payload, "signed_arrays", "station_radius_delta")[2] = 49
end)
expect_bay_corruption("Bank roster changed", function(payload)
	local ids = named_array_value(payload, "text_arrays", "bank_component_ids")
	ids[1], ids[2] = ids[2], ids[1]
end)
expect_bay_corruption("Bank roster changed", function(payload)
	named_array_value(payload, "unsigned_arrays", "bank_station_offsets")[2] = 0
end)
expect_bay_corruption("Bank is not eight-connected", function(payload)
	local values = named_array_value(payload, "signed_arrays", "bank_stations_xz")
	values[3] = values[1] + 2
end)
expect_bay_corruption("text_values count changed", function(payload)
	payload.text_values[#payload.text_values + 1] =
		{name = "unsafe_duplicate", value = "not canonical"}
end)
expect_bay_corruption("is not data-only", function(payload)
	payload.unsafe_callback = function() end
end)
expect_bay_corruption("cycle or mutable alias", function(payload)
	payload.attributes = payload.candidates
end)

local source_tables = {}
local function mark_source(value)
	if type(value) ~= "table" or source_tables[value] then return end
	source_tables[value] = true
	for key, child in pairs(value) do mark_source(key) mark_source(child) end
end
mark_source(source)
local function graph_plain(value, seen)
	local kind = type(value)
	assert(kind ~= "function" and kind ~= "userdata" and kind ~= "thread")
	if kind ~= "table" then return end
	assert(getmetatable(value) == nil)
	assert(not source_tables[value], "compiled result aliases Source")
	seen = seen or {}
	assert(not seen[value], "compiled result contains cycle or mutable alias")
	seen[value] = true
	for key, child in pairs(value) do graph_plain(key, seen) graph_plain(child, seen) end
end
graph_plain(compiled)

-- The focused slice is still private, but every emitted family already fits
-- the one production compiled-data canonicalizer without callbacks, inferred
-- scalar tags, aliases, metatables, or schema-side coercion.
local schemas = dofile(wp40 .. "/schemas.lua")
local compiled_schema = dofile(wp40 .. "/compiled_schema.lua")
local geometry = {}
for _, name in ipairs({"zones", "land_boundaries", "land_routes", "boat_routes",
	"perimeters", "bays", "mouth_apertures", "closure_wings", "dry_faces",
	"relief_fields", "templates", "anchors", "route_profiles", "hydrology",
	"coast_shelf", "islands", "channels", "hard_protection", "claim_exclusions",
	"housing_masks"}) do
	geometry[name] = compiled.families[name] or {}
end
local selectors = {logical_biomes = {}, nearest_features = {},
	housing_centers = {}}
local function empty_record(id)
	return {record_schema = "grug_wp40_partition_test_empty_v1", id = id,
		numeric_id = 0, text_values = {}, signed_values = {}, unsigned_values = {},
		boolean_values = {}, text_arrays = {}, signed_arrays = {}, unsigned_arrays = {},
		candidates = {}, attributes = {}}
end
local compiled_data = {schema = schemas.compiled,
	algorithm_schema = schemas.compiled_algorithm, full_seed = "0",
	geometry = geometry, selectors = selectors,
	spatial_index = {schema = schemas.index, cell_size = 128,
		min_cx = 0, max_cx = 0, min_cz = 0, max_cz = 0,
		layers = {}, candidates = {}, attributes = {}},
	coverage = {schema = schemas.coverage, geometry_volumes = {},
		resolver_interfaces = {}, pending = {t4 = {}, t6 = {}, t7 = {}}},
	release_fixtures = {seed_corpus = {}, extreme_slots = {},
		staging_seed = empty_record("staging_seed"),
		microcorpus_classes_1_9 = {},
		requester_trace = empty_record("requester_trace")}}
assert(compiled_schema.canonicalize_compiled(compiled_data, {}, canonical))
local ceiling_rows = compiled.families.land_boundaries[1].unsigned_values
local ceiling_row
for index = 1, #ceiling_rows do
	if ceiling_rows[index].name == "topology_ceiling_nodes" then
		ceiling_row = ceiling_rows[index] break
	end
end
assert(ceiling_row)
local saved_ceiling = ceiling_row.value
ceiling_row.value = -1
expect_error("unsigned", function()
	compiled_schema.canonicalize_compiled(compiled_data, {}, canonical)
end)
ceiling_row.value = saved_ceiling

print("WP40 T2 partition slice tests passed")
