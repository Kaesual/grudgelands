-- Reproducible V1d seed-zero anchor/path migration evidence for the focused
-- WP40 V1e refresh. The accepted artifact and every bound input are verified
-- before the V1d source or evaluator is loaded.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "migration output path required")
local mode = assert(arg[4], "--full or --kat required")

assert(type(repo) == "string" and repo:sub(1, 1) == "/",
	"absolute repository root required")
assert(type(scratch) == "string" and
	scratch:match("^/tmp/grudgelands%-wp40%-simple%-map%.[A-Za-z0-9]+$"),
	"unsafe simple-map scratch directory")
assert(output == repo ..
	"/docs/research/wp40-simple-map-v1e-anchor-migration.tsv",
	"unexpected migration output path")
assert(mode == "--full" or mode == "--kat", "--full or --kat required")
if mode == "--full" then
	assert(type(rawget(_G, "jit")) == "table",
		"full migration extraction is LuaJIT-only")
end

local started = os.clock()
local OLD_FILE_SHA256 =
	"02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339"
local OLD_BODY_SHA256 =
	"73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b"
local OLD_KAT_SHA256 =
	"0a945840673d3170ce545c3c12af1422dcd12da5398a88faaf39c42d5346056d"
local OLD_ARTIFACT_SCHEMA = "grug_wp40_simple_map_r2_artifact_v1"
local OLD_SOURCE_SCHEMA = "grug_wp40_simple_map_source_v1"
local LAYOUT_ID = "wp40-simple-map-v1d"
local MIGRATION_SCHEMA = "grug_wp40_simple_map_v1e_anchor_migration_v1"
local KAT_SCHEMA = "grug_wp40_simple_map_v1e_anchor_migration_kat_v1"

local input_paths = {
	"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"tools/wp40/simple_map_offline.lua",
	"tools/wp40/simple_map_r2_test.lua",
	"tools/wp40/simple_map_r2_metadata.lua",
	"tools/wp40/simple_map_r2_cores.lua",
	"tools/wp40/simple_map_r2_water.lua",
	"tools/wp40/simple_map_r2_routes.lua",
	"tools/wp40/simple_map_r2_grid.lua",
	"tools/wp40/simple_map_r2_housing.lua",
	"tools/wp40/run_simple_map_r2.sh",
}

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(byte:byte())
	end))
end

local raw_sha256
local ffi = rawget(_G, "wp40_ffi")
if ffi ~= nil then
	assert(type(ffi) == "table", "injected LuaJIT FFI differs")
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest_buffer = ffi.new("unsigned char[32]")
	raw_sha256 = function(data)
		assert(type(data) == "string", "SHA-256 input must be a string")
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil,
			"SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
else
	local counter = 0
	raw_sha256 = function(data)
		assert(type(data) == "string", "SHA-256 input must be a string")
		counter = counter + 1
		local input = scratch .. "/migration-sha-" .. counter .. ".bin"
		local result = scratch .. "/migration-sha-" .. counter .. ".txt"
		local file = assert(io.open(input, "wb"))
		assert(file:write(data))
		assert(file:close())
		local ok, why, code = os.execute("sha256sum " .. input .. " > " .. result)
		assert(ok == 0 or ok == true and why == "exit" and code == 0,
			"sha256sum failed")
		local line = read_file(result)
		assert(os.remove(input))
		assert(os.remove(result))
		local digest = assert(line:match("^([0-9a-f]+)"),
			"sha256sum output differs")
		assert(#digest == 64, "sha256sum digest length differs")
		return (digest:gsub("..", function(pair)
			return string.char(assert(tonumber(pair, 16)))
		end))
	end
end

assert(hex(raw_sha256("")) ==
	"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(hex(raw_sha256("abc")) ==
	"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

local function digest(bytes)
	return hex(raw_sha256(bytes))
end

local function scalar(value)
	if type(value) == "boolean" then return value and "true" or "false" end
	if value == nil then return "-" end
	local result = tostring(value)
	assert(not result:find("[\t\r\n]"), "TSV scalar contains whitespace")
	return result
end

local function row(...)
	local values = {...}
	for index = 1, #values do values[index] = scalar(values[index]) end
	return table.concat(values, "\t") .. "\n"
end

local function split_fields(line)
	local fields = {}
	local start = 1
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

-- Authority verification. No dofile/loadfile call may precede the end of this
-- block.
local artifact_path = repo .. "/docs/research/wp40-simple-map-r2-artifact.tsv"
local artifact_bytes = read_file(artifact_path)
assert(digest(artifact_bytes) == OLD_FILE_SHA256,
	"accepted V1d R2 complete-file SHA-256 differs")
assert(not artifact_bytes:find("\r", 1, true),
	"accepted V1d R2 artifact contains CR bytes")
local artifact_body, trailer_digest = artifact_bytes:match(
	"^(.*\n)artifact_sha256\t([0-9a-f]+)\n$")
assert(artifact_body and trailer_digest,
	"accepted V1d R2 artifact trailer differs")
assert(trailer_digest == OLD_BODY_SHA256,
	"accepted V1d R2 embedded body SHA-256 differs")
assert(digest(artifact_body) == OLD_BODY_SHA256,
	"accepted V1d R2 body SHA-256 differs")

local artifact_schema, artifact_layout, artifact_seed, artifact_kat
local embedded_inputs = {}
local input_index = 0
for line in artifact_body:gmatch("([^\n]+)\n") do
	local fields = split_fields(line)
	if fields[1] == "schema" then
		assert(not artifact_schema and #fields == 2,
			"accepted artifact schema row differs")
		artifact_schema = fields[2]
	elseif fields[1] == "layout_id" then
		assert(not artifact_layout and #fields == 2,
			"accepted artifact layout row differs")
		artifact_layout = fields[2]
	elseif fields[1] == "seed" then
		assert(not artifact_seed and #fields == 2,
			"accepted artifact seed row differs")
		artifact_seed = fields[2]
	elseif fields[1] == "canonical_kat_sha256" then
		assert(not artifact_kat and #fields == 2,
			"accepted artifact KAT row differs")
		artifact_kat = fields[2]
	elseif fields[1] == "input_sha256" then
		assert(#fields == 3, "accepted artifact input row differs")
		input_index = input_index + 1
		assert(input_index <= #input_paths and
			fields[2] == input_paths[input_index],
			"accepted artifact input roster order differs")
		assert(not embedded_inputs[fields[2]],
			"accepted artifact input path is duplicated")
		assert(fields[3]:match("^[0-9a-f]+$") and #fields[3] == 64,
			"accepted artifact input digest differs")
		embedded_inputs[fields[2]] = fields[3]
	end
end
assert(artifact_schema == OLD_ARTIFACT_SCHEMA,
	"accepted artifact schema is not V1")
assert(artifact_layout == LAYOUT_ID,
	"accepted artifact layout id is not V1d")
assert(artifact_seed == "0", "accepted artifact seed is not zero")
assert(artifact_kat == OLD_KAT_SHA256,
	"accepted artifact canonical KAT row differs")
assert(input_index == 14 and input_index == #input_paths,
	"accepted artifact does not bind exactly 14 inputs")

local input_rows = {}
for index = 1, #input_paths do
	local relative_path = input_paths[index]
	local actual = digest(read_file(repo .. "/" .. relative_path))
	assert(actual == embedded_inputs[relative_path],
		"accepted V1d input SHA-256 differs: " .. relative_path)
	input_rows[#input_rows + 1] =
		row("input_sha256", relative_path, actual)
end
local sorted_input_rows = {}
for index = 1, #input_rows do sorted_input_rows[index] = input_rows[index] end
table.sort(sorted_input_rows)
local input_roster_sha256 = digest(table.concat(sorted_input_rows))
local extractor_relative_path =
	"tools/wp40/simple_map_v1e_anchor_migration.lua"
local extractor_sha256 = digest(read_file(repo .. "/" .. extractor_relative_path))

-- Only now may verified evaluator inputs be loaded.
local loaded = dofile(repo .. "/tools/wp40/simple_map_offline.lua")(
	repo, scratch, "0", raw_sha256)
local source, session = loaded.source, loaded.session
assert(source.schema == OLD_SOURCE_SCHEMA,
	"verified V1d source schema is not V1")
assert(source.layout_id == LAYOUT_ID,
	"verified V1d source layout id differs")
assert(loaded.module.validate_source(), "verified V1d source validation failed")
assert(session.canonical_kat_digest() == OLD_KAT_SHA256,
	"verified V1d seed-zero canonical KAT differs")

local function point_equal(a, b)
	return a and b and a.x == b.x and a.z == b.z
end

local anchor_lines = {}
local anchor_spur_lines = {}
local selected_by_anchor_id = {}
local authored_fixed_count = 0
local candidate_selected_count = 0
local spur_bearing_count = 0
local migrated_no_spur_count = 0
local spur_by_anchor_id = {}
for index = 1, #source.poi_spurs do
	local spur = source.poi_spurs[index]
	assert(not spur_by_anchor_id[spur.anchor_id], "duplicate POI spur anchor")
	spur_by_anchor_id[spur.anchor_id] = spur
end

assert(#source.anchors == 100, "V1d anchor count differs")
assert(#source.poi_spurs == 74, "V1d POI spur count differs")
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	local zone = assert(source.zones[anchor.zone_numeric_id],
		"anchor zone is missing")
	local selected = assert(session.selected_anchor_by_id(anchor.id),
		"selected anchor is missing")
	local source_mode, approved_index
	if anchor.placement_mode == "fixed" then
		authored_fixed_count = authored_fixed_count + 1
		source_mode = "authored_fixed"
		approved_index = 0
		assert(selected.candidate_index == 0 and
			point_equal(selected, anchor.position),
			"fixed anchor selection differs")
		assert(not spur_by_anchor_id[anchor.id],
			"authored-fixed anchor unexpectedly owns a POI spur")
	elseif anchor.placement_mode == "candidate_set" then
		candidate_selected_count = candidate_selected_count + 1
		source_mode = "candidate_selected"
		approved_index = selected.candidate_index
		assert(type(approved_index) == "number" and approved_index >= 1 and
			approved_index <= 3 and approved_index % 1 == 0,
			"candidate anchor selected index differs")
		assert(point_equal(selected, anchor.candidates[approved_index]),
			"candidate anchor selected position differs")
	else
		error("V1d anchor placement mode differs", 0)
	end
	selected_by_anchor_id[anchor.id] = {
		x = selected.x, z = selected.z, approved_index = approved_index,
		template_id = anchor.template_id,
	}
	anchor_lines[#anchor_lines + 1] = row("anchor", index, anchor.id,
		zone.id, anchor.zone_numeric_id, anchor.slot_id, anchor.template_id,
		source_mode, approved_index, selected.x, selected.z)
end
assert(authored_fixed_count == 16 and candidate_selected_count == 84,
	"V1d fixed/candidate-selected anchor split differs")

local trail_templates = {
	bandit_home = true, bandit_frontier = true, mirefolk = true, clash = true,
}
local paths = {}
local path_by_id = {}
local function copy_points(points)
	local result = {}
	for index = 1, #points do
		local point = points[index]
		assert(type(point.x) == "number" and point.x % 1 == 0 and
			type(point.z) == "number" and point.z % 1 == 0,
			"path point is not integral")
		result[index] = {x = point.x, z = point.z}
	end
	assert(#result >= 2, "path centreline is too short")
	return result
end
local function add_path(id, path_type, class, kind, surface_width, points)
	assert(type(id) == "string" and id ~= "" and not path_by_id[id],
		"path identity differs")
	assert(surface_width == 3 or surface_width == 5 or surface_width == 7,
		"path surface width differs")
	local path = {id = id, path_type = path_type, class = class, kind = kind,
		surface_width = surface_width, points = copy_points(points)}
	paths[#paths + 1] = path
	path_by_id[id] = path
	return path
end

assert(#source.routes == 57, "V1d land-route count differs")
for index = 1, #source.routes do
	local route = source.routes[index]
	add_path(route.id, "land_route", route.class, route.kind,
		route.surface_width, route.centreline)
end
for index = 1, #source.poi_spurs do
	local spur = source.poi_spurs[index]
	local selected = assert(selected_by_anchor_id[spur.anchor_id],
		"POI spur selected anchor is missing")
	assert(selected.approved_index >= 1 and selected.approved_index <= 3,
		"POI spur anchor is not migrated")
	local centreline = assert(spur.candidate_paths[selected.approved_index],
		"selected POI spur centreline is missing")
	assert(point_equal(centreline[1], selected),
		"selected POI spur does not begin at its anchor")
	local class = trail_templates[selected.template_id] and "trail" or "secondary"
	local width = class == "trail" and 3 or 5
	local path = add_path(spur.id, "poi_spur", class,
		class == "trail" and "trail" or "road", width, centreline)
	local point_rows = {}
	for point_index = 1, #path.points do
		local point = path.points[point_index]
		point_rows[#point_rows + 1] =
			row("path_point", spur.id, point_index, point.x, point.z)
	end
	anchor_spur_lines[#anchor_spur_lines + 1] = row("anchor_spur",
		spur.anchor_id, spur.id, #path.points, digest(table.concat(point_rows)))
	spur_bearing_count = spur_bearing_count + 1
end
assert(#source.island_routes == 8, "V1d island-route count differs")
for index = 1, #source.island_routes do
	local route = source.island_routes[index]
	add_path(route.id, "island_route", "secondary", route.kind, 5,
		route.centreline)
end

for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	if anchor.placement_mode == "candidate_set" and
			not spur_by_anchor_id[anchor.id] then
		assert(anchor.template_id == "rare_route",
			"migrated no-spur anchor is not a rare-route anchor")
		anchor_spur_lines[#anchor_spur_lines + 1] =
			row("anchor_spur", anchor.id, "-", 0, "-")
		migrated_no_spur_count = migrated_no_spur_count + 1
	end
end
assert(spur_bearing_count == 74 and migrated_no_spur_count == 10 and
	#anchor_spur_lines == 84,
	"V1d migrated spur/no-spur split differs")
assert(#paths == 139, "V1d selected path count differs")
table.sort(paths, function(a, b) return a.id < b.id end)
table.sort(anchor_spur_lines)

local path_lines = {}
for index = 1, #paths do
	local path = paths[index]
	local point_lines = {}
	for point_index = 1, #path.points do
		local point = path.points[point_index]
		point_lines[#point_lines + 1] = row("path_point", path.id,
			point_index, point.x, point.z)
	end
	local geometry_sha256 = digest(table.concat(point_lines))
	path_lines[#path_lines + 1] = row("path", path.id, path.path_type,
		path.class, path.kind, path.surface_width, #path.points,
		geometry_sha256)
	for point_index = 1, #point_lines do
		path_lines[#path_lines + 1] = point_lines[point_index]
	end
end

local anchor_geometry_sha256 = digest(table.concat(anchor_lines))
local anchor_migration_sha256 = digest(table.concat(anchor_lines) ..
	table.concat(anchor_spur_lines))
local path_source_view_sha256 = digest(table.concat(path_lines))
local baseline_source_view_sha256 = digest(table.concat(anchor_lines) ..
	table.concat(anchor_spur_lines) .. table.concat(path_lines))

local kat_lines = {
	row("schema", KAT_SCHEMA),
	row("seed", "0"),
	row("old_r2_body_sha256", OLD_BODY_SHA256),
	row("old_r2_file_sha256", OLD_FILE_SHA256),
	row("canonical_kat_sha256", OLD_KAT_SHA256),
	row("input_roster_sha256", input_roster_sha256),
	row("extractor_sha256", extractor_sha256),
	row("anchor_geometry_sha256", anchor_geometry_sha256),
	row("anchor_migration_sha256", anchor_migration_sha256),
	row("path_source_view_sha256", path_source_view_sha256),
	row("baseline_source_view_sha256", baseline_source_view_sha256),
	row("counts", authored_fixed_count, candidate_selected_count,
		spur_bearing_count, migrated_no_spur_count, #paths),
}
local migration_kat_sha256 = digest(table.concat(kat_lines))
if mode == "--kat" then
	io.write("migration_kat_sha256\t", migration_kat_sha256, "\n")
	io.write("baseline_source_view_sha256\t",
		baseline_source_view_sha256, "\n")
	io.write("elapsed_cpu_seconds\t", ("%.3f"):format(os.clock() - started), "\n")
	return
end

-- Full contact evidence uses only the verified evaluator's existing
-- polyline_corridor_member predicate. The local loops merely enumerate a
-- conservative integer bounding box and compare the resulting exact sets.
local SURFACE_OFFSET = 10000
local SURFACE_STRIDE = 32768
local function surface_key(x, z)
	return (x + SURFACE_OFFSET) * SURFACE_STRIDE + z + SURFACE_OFFSET
end

local total_surface_columns = 0
for index = 1, #paths do
	local path = paths[index]
	local expansion = math.floor(path.surface_width / 2) + 1
	local min_x, max_x, min_z, max_z
	for point_index = 1, #path.points do
		local point = path.points[point_index]
		min_x = math.min(min_x or point.x, point.x)
		max_x = math.max(max_x or point.x, point.x)
		min_z = math.min(min_z or point.z, point.z)
		max_z = math.max(max_z or point.z, point.z)
	end
	min_x, max_x = min_x - expansion, max_x + expansion
	min_z, max_z = min_z - expansion, max_z + expansion
	local set, xs, zs = {}, {}, {}
	local actual_min_x, actual_max_x, actual_min_z, actual_max_z
	for z = min_z, max_z do
		for x = min_x, max_x do
			if session.polyline_corridor_member(x, z, path.points,
					path.surface_width) then
				local key = surface_key(x, z)
				assert(not set[key], "surface enumeration duplicated a column")
				set[key] = true
				xs[#xs + 1] = x
				zs[#zs + 1] = z
				actual_min_x = math.min(actual_min_x or x, x)
				actual_max_x = math.max(actual_max_x or x, x)
				actual_min_z = math.min(actual_min_z or z, z)
				actual_max_z = math.max(actual_max_z or z, z)
			end
		end
	end
	assert(#xs > 0, "path surface is empty")
	path.surface = {set = set, xs = xs, zs = zs, count = #xs,
		min_x = actual_min_x, max_x = actual_max_x,
		min_z = actual_min_z, max_z = actual_max_z}
	total_surface_columns = total_surface_columns + #xs
end

local function tuple_less(a, b)
	if not b then return true end
	if a.kind ~= b.kind then return a.kind < b.kind end
	if a.x1 ~= b.x1 then return a.x1 < b.x1 end
	if a.z1 ~= b.z1 then return a.z1 < b.z1 end
	if a.x2 ~= b.x2 then return a.x2 < b.x2 end
	return a.z2 < b.z2
end

local directions = {{-1, 0}, {0, -1}, {0, 1}, {1, 0}}
local contact_lines = {}
local contact_pair_count = 0
for a_index = 1, #paths - 1 do
	local a = paths[a_index]
	for b_index = a_index + 1, #paths do
		local b = paths[b_index]
		local a_surface, b_surface = a.surface, b.surface
		if a_surface.min_x <= b_surface.max_x + 1 and
			a_surface.max_x + 1 >= b_surface.min_x and
			a_surface.min_z <= b_surface.max_z + 1 and
			a_surface.max_z + 1 >= b_surface.min_z then
			local scan, other = a_surface, b_surface
			if b_surface.count < a_surface.count then
				scan, other = b_surface, a_surface
			end
			local overlap_count, touch_count = 0, 0
			local bounds
			local first_witness
			local function include_endpoint(x, z)
				if not bounds then
					bounds = {min_x = x, max_x = x, min_z = z, max_z = z}
				else
					bounds.min_x = math.min(bounds.min_x, x)
					bounds.max_x = math.max(bounds.max_x, x)
					bounds.min_z = math.min(bounds.min_z, z)
					bounds.max_z = math.max(bounds.max_z, z)
				end
			end
			for point_index = 1, scan.count do
				local x, z = scan.xs[point_index], scan.zs[point_index]
				local key = surface_key(x, z)
				if other.set[key] then
					overlap_count = overlap_count + 1
					include_endpoint(x, z)
					local witness = {kind = "overlap", x1 = x, z1 = z,
						x2 = x, z2 = z}
					if tuple_less(witness, first_witness) then
						first_witness = witness
					end
				else
					for direction_index = 1, #directions do
						local direction = directions[direction_index]
						local nx, nz = x + direction[1], z + direction[2]
						local neighbor_key = surface_key(nx, nz)
						if other.set[neighbor_key] and not scan.set[neighbor_key] then
							touch_count = touch_count + 1
							include_endpoint(x, z)
							include_endpoint(nx, nz)
							local x1, z1, x2, z2 = x, z, nx, nz
							if x2 < x1 or x2 == x1 and z2 < z1 then
								x1, z1, x2, z2 = x2, z2, x1, z1
							end
							local witness = {kind = "touch", x1 = x1, z1 = z1,
								x2 = x2, z2 = z2}
							if tuple_less(witness, first_witness) then
								first_witness = witness
							end
						end
					end
				end
			end
			if overlap_count > 0 or touch_count > 0 then
				assert(bounds and first_witness, "contact evidence is incomplete")
				contact_pair_count = contact_pair_count + 1
				contact_lines[#contact_lines + 1] = row("contact", a.id, b.id,
					overlap_count, touch_count, bounds.min_x, bounds.max_x,
					bounds.min_z, bounds.max_z, first_witness.kind,
					first_witness.x1, first_witness.z1,
					first_witness.x2, first_witness.z2)
			end
		end
	end
end

local contact_roster_sha256 = digest(table.concat(contact_lines))
local header_lines = {
	row("schema", MIGRATION_SCHEMA),
	row("seed", "0"),
	row("old_artifact_schema", OLD_ARTIFACT_SCHEMA),
	row("old_source_schema", OLD_SOURCE_SCHEMA),
	row("layout_id", LAYOUT_ID),
	row("old_r2_body_sha256", OLD_BODY_SHA256),
	row("old_r2_file_sha256", OLD_FILE_SHA256),
	row("canonical_kat_sha256", OLD_KAT_SHA256),
	row("input_roster_sha256", input_roster_sha256),
	row("extractor_sha256", extractor_sha256),
	row("digest_encoding", "sha256_of_exact_sorted_tsv_rows_v1"),
	row("contact_surface_predicate", "v1d_session_polyline_corridor_member"),
	row("contact_touch_predicate",
		"canonical_orthogonal_a_only_b_only_edges_v1"),
	row("contact_edge_orientation", "endpoint_x_z_ascending_v1"),
	row("contact_witness_order", "kind_ascii_then_x1_z1_x2_z2_v1"),
	row("anchor_geometry_sha256", anchor_geometry_sha256),
	row("anchor_migration_sha256", anchor_migration_sha256),
	row("path_source_view_sha256", path_source_view_sha256),
	row("baseline_source_view_sha256", baseline_source_view_sha256),
	row("contact_roster_sha256", contact_roster_sha256),
	row("migration_kat_sha256", migration_kat_sha256),
	row("count", "input_sha256", #input_rows),
	row("count", "anchors", #anchor_lines),
	row("count", "authored_fixed", authored_fixed_count),
	row("count", "candidate_selected", candidate_selected_count),
	row("count", "spur_bearing_migrated", spur_bearing_count),
	row("count", "rare_no_spur_migrated", migrated_no_spur_count),
	row("count", "land_routes", #source.routes),
	row("count", "poi_spurs", #source.poi_spurs),
	row("count", "island_routes", #source.island_routes),
	row("count", "selected_paths", #paths),
	row("count", "contact_pairs", contact_pair_count),
	row("count", "surface_columns_with_path_multiplicity", total_surface_columns),
}
local body = table.concat(header_lines) .. table.concat(sorted_input_rows) ..
	table.concat(anchor_lines) .. table.concat(anchor_spur_lines) ..
	table.concat(path_lines) .. table.concat(contact_lines)
local body_sha256 = digest(body)
local bytes = body .. row("migration_body_sha256", body_sha256)
local file_sha256 = digest(bytes)

local temporary = scratch .. "/simple-map-v1e-anchor-migration.tsv"
local file = assert(io.open(temporary, "wb"))
assert(file:write(bytes))
assert(file:close())
assert(read_file(temporary) == bytes, "temporary migration write differs")
file = assert(io.open(output, "wb"))
assert(file:write(bytes))
assert(file:close())
assert(read_file(output) == bytes, "migration output write differs")
assert(digest(read_file(output)) == file_sha256,
	"migration output complete-file SHA-256 differs")

io.write("migration_body_sha256\t", body_sha256, "\n")
io.write("migration_file_sha256\t", file_sha256, "\n")
io.write("input_roster_sha256\t", input_roster_sha256, "\n")
io.write("baseline_source_view_sha256\t", baseline_source_view_sha256, "\n")
io.write("contact_roster_sha256\t", contact_roster_sha256, "\n")
io.write("contact_pairs\t", contact_pair_count, "\n")
io.write("surface_columns_with_path_multiplicity\t", total_surface_columns, "\n")
io.write("elapsed_cpu_seconds\t", ("%.3f"):format(os.clock() - started), "\n")
