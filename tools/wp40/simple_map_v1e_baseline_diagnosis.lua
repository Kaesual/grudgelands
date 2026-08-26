-- Reconstruct and diagnose the committed V1d seed-zero vertical baseline
-- through the final V1e horizontal evaluator and the production R3 height
-- diagnosis seam. No second height, projection, or winner evaluator lives here.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "diagnosis output path required")

assert(type(repo) == "string" and repo:sub(1, 1) == "/",
	"absolute repository root required")
assert(type(scratch) == "string" and
	scratch:match("^/tmp/grudgelands%-wp40%-simple%-map%.[A-Za-z0-9]+$"),
	"unsafe simple-map scratch directory")
assert(output == repo ..
	"/docs/research/wp40-simple-map-v1e-baseline-diagnosis.tsv",
	"unexpected diagnosis output path")
assert(type(rawget(_G, "jit")) == "table",
	"baseline diagnosis is LuaJIT-only")

local started = os.clock()
local SEED = "0"
local DIAGNOSIS_SCHEMA =
	"grug_wp40_simple_map_v1e_baseline_diagnosis_v1"
local SOURCE_SCHEMA = "grug_wp40_simple_map_source_v2"
local LAYOUT_ID = "wp40-simple-map-v1d"
local LAYOUT_REVISION_ID = "wp40-simple-map-v1e"
local SEMANTIC_BASE_COMMIT = "773387a54cdf"
local R3_CONTRACT_SHA256 =
	"e02b51a89d42deb2be71a3524df444390a06ad31bb3a5c6347919f777d6a16b8"
local OLD_R2_BODY_SHA256 =
	"73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b"
local OLD_R2_FILE_SHA256 =
	"02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339"
local INPUT_ROSTER_SHA256 =
	"76527c6885a7aa9252bcaf384954ceb48e22eb90aa0eb31b69f3a53ddb9a449c"
local MIGRATION_TSV_SHA256 =
	"1295af991c3896d44089511830f3727a284af98be0510d581ea89afe3f11c1fb"
local MIGRATION_BODY_SHA256 =
	"2001bd4b7af28570f9689e278d321a13adf92c68167c79dddace948fbdfa6859"
local EXTRACTOR_SHA256 =
	"88eb31fb6a7e32d054314aed1dcd9d12a3197422daa9c2971d8f5abf78d548e1"
local BASELINE_SOURCE_VIEW_SHA256 =
	"6057843ace1de096e07396b0fc60759dca6d8679c4e2607a07739a9b84bcc23c"
local MIGRATION_SCHEMA = "grug_wp40_simple_map_v1e_anchor_migration_v1"
local MAX_SAFE = 9007199254740991

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local function write_file(path, bytes)
	local file = assert(io.open(path, "wb"))
	assert(file:write(bytes))
	assert(file:close())
	assert(read_file(path) == bytes, "diagnosis write verification failed")
end

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(byte:byte())
	end))
end

local ffi = rawget(_G, "wp40_ffi")
assert(type(ffi) == "table", "injected LuaJIT FFI required")
ffi.cdef[[
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function raw_sha256(data)
	assert(type(data) == "string", "SHA-256 input must be bytes")
	assert(crypto.SHA256(data, #data, digest_buffer) ~= nil, "SHA-256 failed")
	return ffi.string(digest_buffer, 32)
end

local function digest(bytes)
	return hex(raw_sha256(bytes))
end

assert(digest("") ==
	"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(digest("abc") ==
	"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

local function safe_integer(value, label)
	assert(type(value) == "number" and value == value and
		value ~= math.huge and value ~= -math.huge and value % 1 == 0 and
		math.abs(value) <= MAX_SAFE, (label or "value") ..
		" is not a safe integer")
	return value
end

local function decimal(value, label)
	assert(type(value) == "string" and value:match("^-?[0-9]+$"),
		(label or "value") .. " is not canonical decimal text")
	local result = assert(tonumber(value), (label or "value") .. " is not numeric")
	safe_integer(result, label)
	assert(tostring(result) == value, (label or "value") ..
		" is not canonical decimal text")
	return result
end

local function scalar(value)
	if type(value) == "boolean" then return value and "true" or "false" end
	if value == nil then return "-" end
	if type(value) == "number" then safe_integer(value, "TSV number") end
	local result = tostring(value)
	assert(not result:find("[\t\r\n]"), "TSV scalar contains whitespace")
	return result
end

local function row(...)
	local count = select("#", ...)
	local values = {}
	for index = 1, count do values[index] = scalar(select(index, ...)) end
	return table.concat(values, "\t") .. "\n"
end

local function split_fields(line)
	local fields, start = {}, 1
	while true do
		local stop = line:find("\t", start, true)
		if not stop then
			fields[#fields + 1] = line:sub(start)
			return fields
		end
		fields[#fields + 1] = line:sub(start, stop - 1)
		start = stop + 1
	end
end

local migration_path = repo ..
	"/docs/research/wp40-simple-map-v1e-anchor-migration.tsv"
local migration_bytes = read_file(migration_path)
assert(digest(migration_bytes) == MIGRATION_TSV_SHA256,
	"committed migration TSV complete-file SHA-256 differs")
assert(not migration_bytes:find("\r", 1, true),
	"committed migration TSV contains CR bytes")
local migration_body, embedded_migration_body = migration_bytes:match(
	"^(.*\n)migration_body_sha256\t([0-9a-f]+)\n$")
assert(migration_body and embedded_migration_body == MIGRATION_BODY_SHA256,
	"committed migration TSV trailer differs")
assert(digest(migration_body) == MIGRATION_BODY_SHA256,
	"committed migration TSV body SHA-256 differs")

local metadata, counts = {}, {}
local input_rows, anchors, anchor_spurs, paths = {}, {}, {}, {}
local path_points = {}
local contact_count = 0
for line in migration_body:gmatch("([^\n]+)\n") do
	local fields = split_fields(line)
	local kind = fields[1]
	if kind == "input_sha256" then
		assert(#fields == 3 and fields[2] ~= "" and
			fields[3]:match("^[0-9a-f]+$") and #fields[3] == 64,
			"migration input row differs")
		input_rows[#input_rows + 1] = row(kind, fields[2], fields[3])
	elseif kind == "count" then
		assert(#fields == 3 and not counts[fields[2]],
			"migration count row differs")
		counts[fields[2]] = decimal(fields[3], "migration count")
	elseif kind == "anchor" then
		assert(#fields == 11, "migration anchor row differs")
		local index = decimal(fields[2], "migration anchor index")
		assert(not anchors[index], "duplicate migration anchor index")
		anchors[index] = {index = index, id = fields[3], zone_id = fields[4],
			zone_numeric_id = decimal(fields[5], "migration anchor zone"),
			slot_id = fields[6], template_id = fields[7], source_mode = fields[8],
			approved_candidate_index = decimal(fields[9],
				"migration approved provenance"),
			x = decimal(fields[10], "migration anchor x"),
			z = decimal(fields[11], "migration anchor z")}
	elseif kind == "anchor_spur" then
		assert(#fields == 5 and not anchor_spurs[fields[2]],
			"migration anchor-spur row differs")
		anchor_spurs[fields[2]] = {anchor_id = fields[2], path_id = fields[3],
			point_count = decimal(fields[4], "migration spur point count"),
			geometry_sha256 = fields[5]}
	elseif kind == "path" then
		assert(#fields == 8 and not paths[fields[2]],
			"migration path row differs")
		paths[fields[2]] = {id = fields[2], path_type = fields[3],
			class = fields[4], kind = fields[5],
			surface_width = decimal(fields[6], "migration path surface width"),
			point_count = decimal(fields[7], "migration path point count"),
			geometry_sha256 = fields[8]}
		path_points[fields[2]] = {}
	elseif kind == "path_point" then
		assert(#fields == 5 and path_points[fields[2]],
			"migration path-point owner differs")
		local points = path_points[fields[2]]
		local point_index = decimal(fields[3], "migration path point index")
		assert(not points[point_index], "duplicate migration path point")
		points[point_index] = {x = decimal(fields[4], "migration path x"),
			z = decimal(fields[5], "migration path z")}
	elseif kind == "contact" then
		assert(#fields == 14, "migration contact row differs")
		contact_count = contact_count + 1
	else
		assert(#fields == 2 and not metadata[kind],
			"migration metadata row differs: " .. tostring(kind))
		metadata[kind] = fields[2]
	end
end

local expected_metadata = {
	schema = MIGRATION_SCHEMA,
	seed = SEED,
	old_artifact_schema = "grug_wp40_simple_map_r2_artifact_v1",
	old_source_schema = "grug_wp40_simple_map_source_v1",
	layout_id = LAYOUT_ID,
	old_r2_body_sha256 = OLD_R2_BODY_SHA256,
	old_r2_file_sha256 = OLD_R2_FILE_SHA256,
	canonical_kat_sha256 =
		"0a945840673d3170ce545c3c12af1422dcd12da5398a88faaf39c42d5346056d",
	input_roster_sha256 = INPUT_ROSTER_SHA256,
	extractor_sha256 = EXTRACTOR_SHA256,
	digest_encoding = "sha256_of_exact_sorted_tsv_rows_v1",
	contact_surface_predicate = "v1d_session_polyline_corridor_member",
	contact_touch_predicate = "canonical_orthogonal_a_only_b_only_edges_v1",
	contact_edge_orientation = "endpoint_x_z_ascending_v1",
	contact_witness_order = "kind_ascii_then_x1_z1_x2_z2_v1",
	anchor_geometry_sha256 =
		"5b758ddb0c0257ee408432921626452dcb63cbb3d70d3f1050e9a42e28d6b37d",
	anchor_migration_sha256 =
		"45bbcf0c3b40ee5849cf575ab282eca373e6b5594a9c211a12b83fa02506af5c",
	path_source_view_sha256 =
		"410744f6ebe462c5f24df72ca3df0aca246e49049e01d096e099196e7810ec5d",
	baseline_source_view_sha256 = BASELINE_SOURCE_VIEW_SHA256,
	contact_roster_sha256 =
		"f1d060d85f726b3fdcaf9b48ff9e00d036b6b377a1d21d8bdc8b19d3f4d68d2c",
	migration_kat_sha256 =
		"f09e4ad13820959859716ca8ad0dc233e0310b744b2b130601bad56ca1fe8611",
}
for key, expected in pairs(expected_metadata) do
	assert(metadata[key] == expected, "migration metadata differs: " .. key)
end
local metadata_count = 0
for _ in pairs(metadata) do metadata_count = metadata_count + 1 end
local expected_metadata_count = 0
for _ in pairs(expected_metadata) do expected_metadata_count =
	expected_metadata_count + 1 end
assert(metadata_count == expected_metadata_count,
	"migration metadata contains an unexpected row")

local expected_counts = {input_sha256 = 14, anchors = 100,
	authored_fixed = 16, candidate_selected = 84,
	spur_bearing_migrated = 74, rare_no_spur_migrated = 10,
	land_routes = 57, poi_spurs = 74, island_routes = 8,
	selected_paths = 139, contact_pairs = 533,
	surface_columns_with_path_multiplicity = 417492}
for key, expected in pairs(expected_counts) do
	assert(counts[key] == expected, "migration count differs: " .. key)
end
local count_row_count = 0
for _ in pairs(counts) do count_row_count = count_row_count + 1 end
assert(count_row_count == 12, "migration count roster differs")
assert(#input_rows == 14 and contact_count == 533,
	"migration input/contact population differs")
table.sort(input_rows)
assert(digest(table.concat(input_rows)) == INPUT_ROSTER_SHA256,
	"migration input roster digest differs")
assert(digest(read_file(repo ..
	"/tools/wp40/simple_map_v1e_anchor_migration.lua")) == EXTRACTOR_SHA256,
	"migration extractor SHA-256 differs")

local anchor_lines, anchor_spur_lines = {}, {}
local authored_count, migrated_count, spur_count, no_spur_count = 0, 0, 0, 0
for index = 1, 100 do
	local anchor = assert(anchors[index], "migration anchor population has a hole")
	assert(anchor.id == ("anchor_%03d"):format(index),
		"migration anchor identity order differs")
	if anchor.source_mode == "authored_fixed" then
		authored_count = authored_count + 1
		assert(anchor.approved_candidate_index == 0,
			"authored migration provenance differs")
	elseif anchor.source_mode == "candidate_selected" then
		migrated_count = migrated_count + 1
		assert(anchor.approved_candidate_index >= 1 and
			anchor.approved_candidate_index <= 3,
			"migrated anchor provenance differs")
	else error("migration anchor source mode differs", 0) end
	anchor_lines[index] = row("anchor", anchor.index, anchor.id,
		anchor.zone_id, anchor.zone_numeric_id, anchor.slot_id,
		anchor.template_id, anchor.source_mode,
		anchor.approved_candidate_index, anchor.x, anchor.z)
	local spur = anchor_spurs[anchor.id]
	if spur then
		if spur.path_id == "-" then
			assert(index >= 91 and index <= 100 and spur.point_count == 0 and
				spur.geometry_sha256 == "-", "migration no-spur row differs")
			no_spur_count = no_spur_count + 1
		else
			assert(index >= 13 and index <= 86 and
				spur.path_id == ("poi_spur_%03d"):format(index),
				"migration spur identity differs")
			spur_count = spur_count + 1
		end
		anchor_spur_lines[#anchor_spur_lines + 1] = row("anchor_spur",
			spur.anchor_id, spur.path_id, spur.point_count, spur.geometry_sha256)
	elseif anchor.source_mode == "candidate_selected" then
		error("migrated anchor has no anchor-spur evidence", 0)
	end
end
assert(authored_count == 16 and migrated_count == 84 and spur_count == 74 and
	no_spur_count == 10 and #anchor_spur_lines == 84,
	"migration anchor/spur split differs")
table.sort(anchor_spur_lines)

local path_ids = {}
for id in pairs(paths) do path_ids[#path_ids + 1] = id end
table.sort(path_ids)
assert(#path_ids == 139, "migration selected-path population differs")
local path_lines = {}
local land_count, poi_count, island_count = 0, 0, 0
for index = 1, #path_ids do
	local path = paths[path_ids[index]]
	local points = path_points[path.id]
	assert(#points == path.point_count and path.point_count >= 2,
		"migration path-point population differs: " .. path.id)
	local point_lines = {}
	for point_index = 1, #points do
		assert(points[point_index], "migration path points have a hole")
		point_lines[point_index] = row("path_point", path.id, point_index,
			points[point_index].x, points[point_index].z)
	end
	assert(digest(table.concat(point_lines)) == path.geometry_sha256,
		"migration path geometry digest differs: " .. path.id)
	if path.path_type == "land_route" then land_count = land_count + 1
	elseif path.path_type == "poi_spur" then poi_count = poi_count + 1
	elseif path.path_type == "island_route" then island_count = island_count + 1
	else error("migration path type differs", 0) end
	path_lines[#path_lines + 1] = row("path", path.id, path.path_type,
		path.class, path.kind, path.surface_width, path.point_count,
		path.geometry_sha256)
	for point_index = 1, #point_lines do
		path_lines[#path_lines + 1] = point_lines[point_index]
	end
end
assert(land_count == 57 and poi_count == 74 and island_count == 8,
	"migration path-type population differs")
assert(digest(table.concat(anchor_lines)) ==
	expected_metadata.anchor_geometry_sha256,
	"reconstructed anchor geometry digest differs")
assert(digest(table.concat(anchor_lines) .. table.concat(anchor_spur_lines)) ==
	expected_metadata.anchor_migration_sha256,
	"reconstructed anchor migration digest differs")
assert(digest(table.concat(path_lines)) ==
	expected_metadata.path_source_view_sha256,
	"reconstructed path source-view digest differs")
assert(digest(table.concat(anchor_lines) .. table.concat(anchor_spur_lines) ..
	table.concat(path_lines)) == BASELINE_SOURCE_VIEW_SHA256,
	"reconstructed baseline source-view digest differs")

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do
		result[deep_copy(key, seen)] = deep_copy(child, seen)
	end
	return result
end

-- No executable map input is loaded before the committed migration authority
-- and its complete reconstructible source view have passed above.
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local final_source = dofile(directory .. "/source/simple_map.lua")
assert(final_source.schema == SOURCE_SCHEMA and
	final_source.layout_id == LAYOUT_ID and
	final_source.layout_revision_id == LAYOUT_REVISION_ID,
	"final V1e source identity differs")
local source = deep_copy(final_source)
assert(#source.anchors == 100, "final V1e anchor count differs")
for index = 1, #source.anchors do
	local current, baseline = source.anchors[index], anchors[index]
	local zone = source.zones[current.zone_numeric_id]
	local expected_mode = baseline.source_mode == "authored_fixed" and
		"authored_fixed" or "layout_fixed"
	assert(current.numeric_id == index and current.id == baseline.id and zone and
		zone.id == baseline.zone_id and
		current.zone_numeric_id == baseline.zone_numeric_id and
		current.slot_id == baseline.slot_id and
		current.template_id == baseline.template_id and
		current.placement_mode == expected_mode and
		current.approved_candidate_index == baseline.approved_candidate_index,
		"final V1e anchor identity/provenance differs: " .. baseline.id)
	current.position = {x = baseline.x, z = baseline.z}
end

local consumed_paths = {}
assert(#source.routes == 57, "final V1e land-route count differs")
for index = 1, #source.routes do
	local current = source.routes[index]
	local baseline = assert(paths[current.id], "migration land route is missing")
	assert(baseline.path_type == "land_route" and
		current.class == baseline.class and current.kind == baseline.kind and
		current.surface_width == baseline.surface_width,
		"final V1e land-route identity differs: " .. current.id)
	current.centreline = deep_copy(path_points[current.id])
	consumed_paths[current.id] = true
end
local anchor_by_id = {}
for index = 1, #source.anchors do
	anchor_by_id[source.anchors[index].id] = source.anchors[index]
end
local trail_templates = {bandit_home = true, bandit_frontier = true,
	mirefolk = true, clash = true}
assert(#source.poi_spurs == 74, "final V1e POI-spur count differs")
for index = 1, #source.poi_spurs do
	local current = source.poi_spurs[index]
	local baseline = assert(paths[current.id], "migration POI spur is missing")
	local anchor = assert(anchor_by_id[current.anchor_id],
		"final V1e POI-spur anchor is missing")
	local expected_class = trail_templates[anchor.template_id] and
		"trail" or "secondary"
	local expected_kind = expected_class == "trail" and "trail" or "road"
	local expected_width = expected_class == "trail" and 3 or 5
	assert(baseline.path_type == "poi_spur" and
		baseline.class == expected_class and baseline.kind == expected_kind and
		baseline.surface_width == expected_width and
		anchor_spurs[current.anchor_id] and
		anchor_spurs[current.anchor_id].path_id == current.id and
		type(current.centreline) == "table",
		"final V1e POI-spur identity differs: " .. current.id)
	current.centreline = deep_copy(path_points[current.id])
	consumed_paths[current.id] = true
end
assert(#source.island_routes == 8, "final V1e island-route count differs")
for index = 1, #source.island_routes do
	local current = source.island_routes[index]
	local baseline = assert(paths[current.id], "migration island route is missing")
	assert(baseline.path_type == "island_route" and
		baseline.class == "secondary" and baseline.kind == current.kind and
		baseline.surface_width == 5,
		"final V1e island-route identity differs: " .. current.id)
	current.centreline = deep_copy(path_points[current.id])
	consumed_paths[current.id] = true
end
local consumed_count = 0
for id in pairs(consumed_paths) do
	assert(paths[id], "final V1e consumed an unknown path")
	consumed_count = consumed_count + 1
end
assert(consumed_count == 139, "final V1e did not consume all baseline paths")

local schemas = dofile(directory .. "/schemas.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local horizontal_module = dofile(directory .. "/simple_map.lua")({
	source = source,
	schemas = schemas,
	canonical = canonical,
	deterministic = deterministic,
	raw_sha256 = raw_sha256,
})
assert(horizontal_module.validate_source(),
	"reconstructed baseline horizontal source validation failed")
local horizontal = horizontal_module.new(SEED)
local allowed_anchor_result = {x = true, z = true, anchor_id = true,
	selection_mode = true, approved_candidate_index = true}
for index = 1, #source.anchors do
	local selected = assert(horizontal.selected_anchor_by_id(source.anchors[index].id),
		"reconstructed baseline selected anchor is missing")
	local field_count = 0
	for key in pairs(selected) do
		assert(allowed_anchor_result[key],
			"selected anchor result has an unexpected field")
		field_count = field_count + 1
	end
	local expected_mode = source.anchors[index].placement_mode ==
		"authored_fixed" and "authored_fixed" or "frozen_layout"
	assert(field_count == 5 and selected.x == anchors[index].x and
		selected.z == anchors[index].z and selected.anchor_id == anchors[index].id and
		selected.selection_mode == expected_mode and
		selected.approved_candidate_index == anchors[index].approved_candidate_index,
		"reconstructed baseline selected anchor result differs")
end

local height_relative_path = "mods/MAPGEN/grug_mapgen/wp40/height.lua"
local source_relative_path =
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
local tool_relative_path =
	"tools/wp40/simple_map_v1e_baseline_diagnosis.lua"
local validator_relative_path = "tools/wp40/simple_map_r3_validate.lua"
local source_file_sha256 = digest(read_file(repo .. "/" .. source_relative_path))
local height_sha256 = digest(read_file(repo .. "/" .. height_relative_path))
local tool_sha256 = digest(read_file(repo .. "/" .. tool_relative_path))
local validator_sha256 = digest(read_file(repo .. "/" .. validator_relative_path))
local height_factory = dofile(repo .. "/" .. height_relative_path)
local height_module = height_factory({source = source, canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal})
if type(height_module.validate_source) == "function" then
	assert(height_module.validate_source(), "height source validation failed")
end
assert(type(height_module.new) == "function", "height module.new missing")
assert(type(height_module.diagnose_final_axis_violations) == "function",
	"height baseline diagnosis seam missing")
local witnesses = height_module.diagnose_final_axis_violations(SEED)

local validator_common = {}
validator_common.safe_integer = safe_integer
function validator_common.dense_count(value, label)
	assert(type(value) == "table", (label or "value") .. " is not an array")
	local count = #value
	for index = 1, count do
		assert(value[index] ~= nil, (label or "array") .. " has a hole")
	end
	for key in pairs(value) do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1 and
			key <= count, (label or "array") .. " is not dense")
	end
	return count
end
function validator_common.round_half_away(numerator, denominator)
	safe_integer(numerator, "round numerator")
	safe_integer(denominator, "round denominator")
	assert(denominator > 0, "round denominator is not positive")
	local sign = numerator < 0 and -1 or 1
	local magnitude = math.abs(numerator)
	local quotient = math.floor(magnitude / denominator)
	local remainder = magnitude - quotient * denominator
	if remainder * 2 >= denominator then quotient = quotient + 1 end
	return sign * quotient
end
function validator_common.raster_polyline(points)
	validator_common.dense_count(points, "diagnosis polyline")
	assert(#points >= 2, "diagnosis polyline is too short")
	local result = {}
	for segment = 1, #points - 1 do
		local a, b = points[segment], points[segment + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local steps = math.max(math.abs(dx), math.abs(dz))
		assert(steps > 0, "diagnosis polyline has a coincident segment")
		local first = segment == 1 and 0 or 1
		for step = first, steps do
			result[#result + 1] = {
				x = a.x + validator_common.round_half_away(dx * step, steps),
				z = a.z + validator_common.round_half_away(dz * step, steps),
			}
		end
	end
	return result
end
local validator = dofile(repo .. "/" .. validator_relative_path)(
	validator_common)
assert(type(validator.validate_baseline_axis_diagnosis) == "function",
	"baseline diagnosis validator missing")
local pair_rows = validator.validate_baseline_axis_diagnosis(witnesses, source)
assert(#witnesses == 40 and #pair_rows == 14,
	"baseline diagnosis exact 40/14 population differs")

-- All authority, reconstruction, implementation, and exact-population gates
-- have passed before the canonical output path is opened for writing.
local header_lines = {
	row("schema", DIAGNOSIS_SCHEMA),
	row("semantic_base_commit", SEMANTIC_BASE_COMMIT),
	row("r3_contract_sha256", R3_CONTRACT_SHA256),
	row("seed", SEED),
	row("old_r2_body_sha256", OLD_R2_BODY_SHA256),
	row("old_r2_file_sha256", OLD_R2_FILE_SHA256),
	row("input_roster_sha256", INPUT_ROSTER_SHA256),
	row("migration_tsv_sha256", MIGRATION_TSV_SHA256),
	row("baseline_source_view_sha256", BASELINE_SOURCE_VIEW_SHA256),
	row("source_schema", SOURCE_SCHEMA),
	row("layout_id", LAYOUT_ID),
	row("layout_revision_id", LAYOUT_REVISION_ID),
	row("source_file_sha256", source_file_sha256),
	row("height_sha256", height_sha256),
	row("diagnosis_tool_sha256", tool_sha256),
	row("validator_sha256", validator_sha256),
	row("digest_encoding", "sha256_of_exact_tsv_body_v1"),
	row("count", "unique_pairs", #pair_rows),
	row("count", "witness_rows", #witnesses),
}
local pair_lines = {}
for index = 1, #pair_rows do
	local pair = pair_rows[index]
	pair_lines[index] = row("pair", pair.pair_a, pair.pair_b,
		pair.witness_count)
end
local witness_lines = {}
for index = 1, #witnesses do
	local witness = witnesses[index]
	witness_lines[index] = row("witness", witness.losing_path_id,
		witness.losing_run, witness.from_x, witness.from_z, witness.from_y,
		witness.to_x, witness.to_z, witness.to_y, witness.absolute_step,
		witness.winner_path_id, witness.winner_run, witness.winner_x,
		witness.winner_z, witness.pair_a, witness.pair_b)
end
local body = table.concat(header_lines) .. table.concat(pair_lines) ..
	table.concat(witness_lines)
local body_sha256 = digest(body)
local bytes = body .. row("diagnosis_body_sha256", body_sha256)
write_file(output, bytes)
local file_sha256 = digest(read_file(output))

io.write("diagnosis_body_sha256\t", body_sha256, "\n")
io.write("diagnosis_file_sha256\t", file_sha256, "\n")
io.write("baseline_source_view_sha256\t", BASELINE_SOURCE_VIEW_SHA256, "\n")
io.write("source_file_sha256\t", source_file_sha256, "\n")
io.write("unique_pairs\t", #pair_rows, "\n")
io.write("witness_rows\t", #witnesses, "\n")
io.write("elapsed_cpu_seconds\t", ("%.3f"):format(os.clock() - started), "\n")
