-- Authoritative LuaJIT-only R2 horizontal validation and artifact writer.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "artifact output path required")
assert(output == repo .. "/docs/research/wp40-simple-map-r2-artifact.tsv",
	"unexpected R2 artifact output path")

local ffi = assert(rawget(_G,"wp40_ffi"), "LuaJIT FFI injection required")
ffi.cdef[[
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function raw_sha256(data)
	assert(type(data) == "string", "SHA-256 input must be a string")
	assert(crypto.SHA256(data,#data,digest_buffer) ~= nil, "SHA-256 failed")
	return ffi.string(digest_buffer,32)
end
local function hex(bytes)
	return (bytes:gsub(".",function(byte) return ("%02x"):format(byte:byte()) end))
end
assert(hex(raw_sha256("")) ==
	"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(hex(raw_sha256("abc")) ==
	"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

local loaded = dofile(repo .. "/tools/wp40/simple_map_offline.lua")(
	repo,scratch,"0",raw_sha256)
local source, session = loaded.source, loaded.session
assert(loaded.module.validate_source(), "simple-map source validation failed")
assert(source.schema == "grug_wp40_simple_map_source_v2",
	"unexpected simple-map source schema")
assert(source.layout_id == "wp40-simple-map-v1d",
	"unexpected simple-map geometry layout id")
assert(source.layout_revision_id == "wp40-simple-map-v1e",
	"unexpected simple-map layout revision id")

local lines = {}
local function scalar(value)
	if type(value) == "boolean" then return value and "true" or "false" end
	if value == nil then return "-" end
	local result = tostring(value)
	assert(not result:find("[\t\r\n]"), "artifact scalar contains whitespace")
	return result
end
local function add(...)
	local values = {...}
	for index = 1, #values do values[index] = scalar(values[index]) end
	lines[#lines+1] = table.concat(values,"\t")
end
local function file_sha256(relative_path)
	local file=assert(io.open(repo .. "/" .. relative_path,"rb"))
	local bytes=assert(file:read("*a"))
	assert(file:close())
	return hex(raw_sha256(bytes))
end
local function sorted_keys(value)
	local keys = {}
	for key in pairs(value) do keys[#keys+1] = key end
	table.sort(keys)
	return keys
end
local function ensure(name, result)
	if result.ok then return end
	for index = 1, #result.violations do
		local row = result.violations[index]
		io.stderr:write(name," violation ",scalar(row.code)," ",
			scalar(row.subject or row.family)," ",scalar(row.count),"\n")
	end
	error(name .. " validation failed",0)
end
local function progress(name)
	io.write("r2\t",name,"\n")
	io.flush()
end

add("schema","grug_wp40_simple_map_r2_artifact_v2")
add("layout_id",source.layout_id)
add("layout_revision_id",source.layout_revision_id)
add("source_schema",source.schema)
add("seed","0")
local input_paths={
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
	"tools/wp40/simple_map_r2_contacts.lua",
	"tools/wp40/run_simple_map_r2.sh",
}
for index=1,#input_paths do
	add("input_sha256",input_paths[index],file_sha256(input_paths[index]))
end
add("canonical_kat_sha256",session.canonical_kat_digest())
local difficulty_lattice_sha256 = session.difficulty_lattice_digest()
assert(difficulty_lattice_sha256 ==
	"0ec24ea13e87afd8a769d326abbc4016a458a564d28c7315d9506158386af15d",
	"accepted V1d difficulty lattice differs")
add("difficulty_lattice_sha256",difficulty_lattice_sha256)
local migration_path =
	"docs/research/wp40-simple-map-v1e-anchor-migration.tsv"
local diagnosis_path =
	"docs/research/wp40-simple-map-v1e-baseline-diagnosis.tsv"
local migration_sha256 = file_sha256(migration_path)
local diagnosis_sha256 = file_sha256(diagnosis_path)
assert(migration_sha256 ==
	"1295af991c3896d44089511830f3727a284af98be0510d581ea89afe3f11c1fb",
	"V1e migration evidence SHA-256 differs")
assert(diagnosis_sha256 ==
	"1c7444c57fd1a95c11f37b46789ae29c21ab6532e1b4ac596675fc3086ec4bed",
	"V1e baseline diagnosis SHA-256 differs")
local migration_extractor_sha256 =
	file_sha256("tools/wp40/simple_map_v1e_anchor_migration.lua")
local diagnosis_tool_sha256 =
	file_sha256("tools/wp40/simple_map_v1e_baseline_diagnosis.lua")
assert(migration_extractor_sha256 ==
	"88eb31fb6a7e32d054314aed1dcd9d12a3197422daa9c2971d8f5abf78d548e1",
	"V1e migration extractor SHA-256 differs")
assert(diagnosis_tool_sha256 ==
	"dae67d15e59549cac6491532d148f7da7237f9f0a47a110da16a7f805e109479",
	"V1e baseline diagnosis tool SHA-256 differs")
add("evidence_sha256","anchor_migration_tsv",migration_sha256)
add("evidence_sha256","anchor_migration_extractor",migration_extractor_sha256)
add("evidence_sha256","baseline_diagnosis_tsv",diagnosis_sha256)
add("evidence_sha256","baseline_diagnosis_tool",diagnosis_tool_sha256)
local warp = session.warp_proof()
local warp_lines = {}
for _, key in ipairs({"cell","maximum","max_horizontal_x",
	"max_horizontal_z","max_vertical_x","max_vertical_z","min_x","max_x",
	"min_z","max_z","min_ix","max_ix","min_iz","max_iz"}) do
	add("warp",key,warp[key])
	warp_lines[#warp_lines + 1] =
		"warp\t" .. key .. "\t" .. tostring(warp[key]) .. "\n"
end
local warp_proof_sha256 = hex(raw_sha256(table.concat(warp_lines)))
assert(warp_proof_sha256 ==
	"c3f65198e1f46c1061f52d05743d5cb60a8b14609dcf8a1f78f1a634396e38ec",
	"accepted V1d warp proof differs")
add("warp_proof_sha256",warp_proof_sha256)

progress("metadata")
local metadata = dofile(repo .. "/tools/wp40/simple_map_r2_metadata.lua")(
	source,session)
ensure("metadata",metadata)
add("validator","metadata",metadata.schema or
	"grug_wp40_simple_map_r2_metadata_v1",metadata.ok,#metadata.violations)
for _, key in ipairs(sorted_keys(metadata.metrics.counts)) do
	add("metadata_count",key,metadata.metrics.counts[key])
end
for index=1,#metadata.coastal_cores do
	local row=metadata.coastal_cores[index]
	add("coastal_core",row.id,row.zone_numeric_id,row.min_x,row.max_x,
		row.min_z,row.max_z,row.inland_depth,row.frontage,
		row.bounding_nodes,row.shape_nodes,
		row.land_nodes,row.owner_nodes,row.exclusion_free_nodes,
		row.eligible_nodes,row.wholly_contained_reservation_centers)
end
local reflection = metadata.metrics.reflection_projection
add("reflection",reflection.family,reflection.elandor_records,
	reflection.kragmar_records,reflection.identical,reflection.first_difference_index)
local fixed_layout_lines = {}
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	local selection_mode = anchor.placement_mode == "authored_fixed" and
		"authored_fixed" or "frozen_layout"
	add("anchor_2d",anchor.id,anchor.zone_numeric_id,anchor.slot_id,
		anchor.template_id,selection_mode,anchor.approved_candidate_index,
		anchor.position.x,anchor.position.z)
	fixed_layout_lines[#fixed_layout_lines + 1] = table.concat({"anchor_2d",
		anchor.id,tostring(anchor.zone_numeric_id),anchor.slot_id,anchor.template_id,
		selection_mode,tostring(anchor.approved_candidate_index),
		tostring(anchor.position.x),tostring(anchor.position.z)},"\t") .. "\n"
end
for index = 1, #source.poi_spurs do
	local spur = source.poi_spurs[index]
	local point_lines = {}
	for point_index = 1, #spur.centreline do
		local point = spur.centreline[point_index]
		point_lines[point_index] = table.concat({"poi_spur_point",spur.id,
			tostring(point_index),tostring(point.x),tostring(point.z)},"\t") .. "\n"
	end
	local geometry_sha256 = hex(raw_sha256(table.concat(point_lines)))
	add("poi_spur_2d",spur.id,spur.anchor_id,#spur.centreline,geometry_sha256)
	fixed_layout_lines[#fixed_layout_lines + 1] = table.concat({"poi_spur_2d",
		spur.id,spur.anchor_id,tostring(#spur.centreline),geometry_sha256},"\t") .. "\n"
end
add("fixed_anchor_spur_roster_sha256",
	hex(raw_sha256(table.concat(fixed_layout_lines))))
local claim_recipe_counts, claim_id_lines = {}, {}
local claim_ids = {}
for index = 1, #source.claim_exclusions do
	local claim = source.claim_exclusions[index]
	assert(type(claim.id) == "string" and type(claim.recipe_id) == "string",
		"claim exclusion identity differs")
	assert(not claim_ids[claim.id], "duplicate claim exclusion identity")
	claim_ids[claim.id] = claim
	claim_recipe_counts[claim.recipe_id] =
		(claim_recipe_counts[claim.recipe_id] or 0) + 1
	claim_id_lines[#claim_id_lines + 1] = "claim_exclusion_id\t" .. claim.id .. "\n"
end
table.sort(claim_id_lines)
assert(#claim_id_lines == 314, "claim exclusion population differs")
for _, recipe_id in ipairs(sorted_keys(claim_recipe_counts)) do
	add("claim_exclusion_recipe_count",recipe_id,claim_recipe_counts[recipe_id])
end
for index = 1, #claim_id_lines do
	local id = claim_id_lines[index]:match("^claim_exclusion_id\t([^\n]+)\n$")
	add("claim_exclusion_id",id)
end
add("claim_exclusion_roster_sha256",
	hex(raw_sha256(table.concat(claim_id_lines))))
metadata = nil
collectgarbage("collect")

progress("cores")
local cores = dofile(repo .. "/tools/wp40/simple_map_r2_cores.lua")(
	source,session)
ensure("cores",cores)
add("validator","cores",cores.schema,cores.ok,#cores.violations)
for _, key in ipairs(sorted_keys(cores.metrics)) do
	add("core_metric",key,cores.metrics[key])
end
for index = 1, #cores.cores do
	local row = cores.cores[index]
	add("core",row.anchor_id,row.zone_numeric_id,row.kind,row.min_x,row.max_x,
		row.min_z,row.max_z,row.nodes,row.land_nodes,row.civic_water_nodes,
		row.underlying_power_disagreements,#row.route_exits,
		table.concat(row.route_exits,","))
end
cores = nil
collectgarbage("collect")

progress("water")
local water = dofile(repo .. "/tools/wp40/simple_map_r2_water.lua")(
	source,session)
ensure("water",water)
add("validator","water",water.schema,water.ok,#water.violations)
for index = 1, #water.metrics do
	add("water_metric",water.metrics[index].name,water.metrics[index].value)
end
for index = 1, #water.bays do
	local row = water.bays[index]
	add("bay",row.id,row.planned_nodes,row.deep_nodes,row.planned_components,
		row.head_reached,row.open_to_outer_ocean,row.deep_transition_edges,
		row.authored_minimum_width,row.realized_width_lower_bound,
		row.capital_aabb_clear,
		row.coastal_core_aabb_clear)
end
for index = 1, #water.channels do
	local row = water.channels[index]
	add("channel",row.id,row.polygon_nodes,row.active_channel_nodes,
		row.land_overlap_nodes,row.active_components,
		row.minimum_horizontal_gap_nodes,row.required_cross_section_nodes,
		row.other_water_mismatches,row.owner_mismatches)
end
for index=1,#water.hydrology do
	local row=water.hydrology[index]
	add("hydrology",row.id,row.wet,row.samples,row.active_samples,
		row.shadowed_samples,row.failures)
end
local interface_by_id={}
for index=1,#source.hydrology_interfaces do
	interface_by_id[source.hydrology_interfaces[index].id]=
		source.hydrology_interfaces[index]
end
local contact_roster_lines={}
for index=1,#water.hydrology_contacts do
	local row=water.hydrology_contacts[index]
	local first=row.edges[1]
	local upper_bounds,lower_bounds=row.upper_bounds,row.lower_bounds
	local values={"hydrology_contact",row.upper_id,row.lower_id,
		tostring(row.upper_offset),tostring(row.lower_offset),
		tostring(row.unequal),row.interface_id or "-",tostring(row.edge_count),
		tostring(row.upper_count),tostring(row.lower_count),
		tostring(upper_bounds.min_x),tostring(upper_bounds.max_x),
		tostring(upper_bounds.min_z),tostring(upper_bounds.max_z),
		tostring(lower_bounds.min_x),tostring(lower_bounds.max_x),
		tostring(lower_bounds.min_z),tostring(lower_bounds.max_z),
		tostring(first.upper_x),tostring(first.upper_z),
		tostring(first.lower_x),tostring(first.lower_z)}
	contact_roster_lines[#contact_roster_lines+1]=table.concat(values,"\t") .. "\n"
	add(unpack(values))
	local interface=row.interface_id and interface_by_id[row.interface_id] or nil
	if interface and interface.transition_scope_id ==
			"orthogonal_reach_contact_face_v1" then
		local edge_lines,upper_lines,lower_lines={},{},{}
		for edge_index=1,#row.edges do
			local edge=row.edges[edge_index]
			edge_lines[edge_index]=table.concat({"contact_edge",interface.id,
				tostring(edge.upper_x),tostring(edge.upper_z),
				tostring(edge.lower_x),tostring(edge.lower_z)},"\t") .. "\n"
		end
		for point_index=1,#row.upper_points do
			local point=row.upper_points[point_index]
			upper_lines[point_index]=table.concat({"contact_upper",interface.id,
				tostring(point.x),tostring(point.z)},"\t") .. "\n"
		end
		for point_index=1,#row.lower_points do
			local point=row.lower_points[point_index]
			lower_lines[point_index]=table.concat({"contact_lower",interface.id,
				tostring(point.x),tostring(point.z),
				tostring(point.face_mask)},"\t") .. "\n"
		end
		add("contact_face",interface.id,row.edge_count,row.upper_count,row.lower_count,
			row.upper_components,row.lower_components,row.path_surface_columns,
			row.path_corridor_columns,row.named_operation_columns,
			hex(raw_sha256(table.concat(edge_lines))),
			hex(raw_sha256(table.concat(upper_lines))),
			hex(raw_sha256(table.concat(lower_lines))))
		for fitting_index=1,#row.fitting_intersections do
			local fitting=row.fitting_intersections[fitting_index]
			add("contact_fitting",interface.id,fitting.anchor_id,
				fitting.upper_full,fitting.lower_full,
				fitting.upper_blend,fitting.lower_blend)
		end
		for hard_index=1,#row.hard_intersections do
			local hard=row.hard_intersections[hard_index]
			add("contact_hard",interface.id,hard.hard_id,hard.upper,hard.lower)
		end
	end
end
add("hydrology_contact_roster_sha256",
	hex(raw_sha256(table.concat(contact_roster_lines))))
for index=1,#water.crossings do
	local row=water.crossings[index]
	add("crossing",row.id,row.kind,row.on_centreline,row.in_corridor,
		row.authorized,row.hydrology_bound)
end
water = nil
collectgarbage("collect")

progress("routes")
local routes = dofile(repo .. "/tools/wp40/simple_map_r2_routes.lua")(
	source,session)
ensure("routes",routes)
add("validator","routes",routes.schema,routes.ok,#routes.violations)
for _, key in ipairs(sorted_keys(routes.metrics)) do
	local value = routes.metrics[key]
	if type(value) == "table" then
		for _, subkey in ipairs(sorted_keys(value)) do
			add("route_metric",key .. "." .. subkey,value[subkey])
		end
	else
		add("route_metric",key,value)
	end
end
local route_graph_lines = {}
for index = 1, #source.routes do
	local route = source.routes[index]
	route_graph_lines[index] = table.concat({"route_graph",route.id,
		tostring(route.zone_a),tostring(route.zone_b),route.station_a_id,
		route.station_b_id},"\t") .. "\n"
	add("route_graph",route.id,route.zone_a,route.zone_b,
		route.station_a_id,route.station_b_id)
end
add("route_graph_roster_sha256",
	hex(raw_sha256(table.concat(route_graph_lines))))
routes = nil
collectgarbage("collect")

progress("grid")
local grid = dofile(repo .. "/tools/wp40/simple_map_r2_grid.lua")(
	source,session)
ensure("grid",grid)
add("validator","grid",grid.schema,grid.ok,#grid.violations)
for index = 1, #grid.metrics do
	add("grid_metric",grid.metrics[index].name,grid.metrics[index].value)
end
for index = 1, #grid.land_components do
	local row = grid.land_components[index]
	add("land_component",index,row.nodes,row.min_x,row.max_x,row.min_z,row.max_z)
end
for index = 1, #grid.zone_components do
	local row = grid.zone_components[index]
	add("zone_component",row.zone_numeric_id,row.zone_id,row.components,
		row.land_nodes)
end
for index = 1, #grid.contacts do
	local row = grid.contacts[index]
	add("contact",row.zone_a,row.zone_b,row.routed,row.a_x,row.a_z,row.b_x,row.b_z)
end
grid = nil
collectgarbage("collect")

progress("contacts")
local migration_file = assert(io.open(repo .. "/" .. migration_path,"rb"))
local migration_bytes = assert(migration_file:read("*a"))
assert(migration_file:close())
local baseline_pairs = {count = 0}
local baseline_contact_digest
for line in migration_bytes:gmatch("([^\n]+)\n") do
	local digest_value = line:match("^contact_roster_sha256\t([0-9a-f]+)$")
	if digest_value then baseline_contact_digest = digest_value end
	local path_a, path_b = line:match("^contact\t([^\t]+)\t([^\t]+)\t")
	if path_a then
		local key = path_a .. "\t" .. path_b
		assert(not baseline_pairs[key], "duplicate baseline contact pair")
		baseline_pairs[key] = true
		baseline_pairs.count = baseline_pairs.count + 1
	end
end
assert(baseline_contact_digest ==
	"f1d060d85f726b3fdcaf9b48ff9e00d036b6b377a1d21d8bdc8b19d3f4d68d2c" and
	baseline_pairs.count == 533, "V1d baseline contact authority differs")
local contacts = dofile(repo .. "/tools/wp40/simple_map_r2_contacts.lua")(
	source,session,baseline_pairs)
ensure("contacts",contacts)
add("validator","contacts",contacts.schema,contacts.ok,#contacts.violations)
for _, key in ipairs(sorted_keys(contacts.metrics)) do
	add("contact_metric",key,contacts.metrics[key])
end
add("baseline_path_contact_roster_sha256",baseline_contact_digest)
add("path_contact_digest_encoding","sha256_of_exact_sorted_contact_tsv_rows_v1")
add("path_contact_surface_predicate","session_polyline_corridor_member")
add("path_contact_touch_predicate",
	"canonical_orthogonal_a_only_b_only_edges_v1")
add("path_contact_edge_orientation","endpoint_x_z_ascending_v1")
add("path_contact_witness_order","kind_ascii_then_x1_z1_x2_z2_v1")
local contact_lines = {}
for index = 1, #contacts.contacts do
	local row = contacts.contacts[index]
	local values = {"contact",row.path_a,row.path_b,row.overlap_count,
		row.touch_count,row.min_x,row.max_x,row.min_z,row.max_z,row.witness_kind,
		row.witness_x1,row.witness_z1,row.witness_x2,row.witness_z2}
	local scalars = {}
	for value_index = 1, #values do
		scalars[value_index] = scalar(values[value_index])
	end
	local canonical_line = table.concat(scalars,"\t")
	contact_lines[#contact_lines + 1] = canonical_line .. "\n"
	scalars[1] = "path_contact"
	lines[#lines + 1] = table.concat(scalars,"\t")
end
local final_contact_digest = hex(raw_sha256(table.concat(contact_lines)))
add("final_path_contact_roster_sha256",final_contact_digest)
contacts = nil
collectgarbage("collect")

progress("housing")
local housing_line_start = #lines + 1
local housing = dofile(repo .. "/tools/wp40/simple_map_r2_housing.lua")(
	source,session)
ensure("housing",housing)
add("validator","housing",housing.schema,housing.ok,#housing.violations)
for _, key in ipairs(sorted_keys(housing.metrics)) do
	add("housing_metric",key,housing.metrics[key])
end
for index = 1, #housing.masks do
	local row = housing.masks[index]
	add("housing_mask",row.id,row.zone_numeric_id,row.eligible_count,
		row.lattice.minimum,row.lattice.maximum,row.portfolio.minimum,
		row.portfolio.maximum,row.constructive_minimum,row.constructive_maximum,
		row.auditable_upper_bound,row.lattice.origin_count,row.lattice.sum,
		row.lattice.minimum_origin.x,row.lattice.minimum_origin.z,
		row.lattice.maximum_origin.x,row.lattice.maximum_origin.z,
		row.portfolio.minimum_order,row.portfolio.maximum_order)
	local lattice_lines = {}
	for origin_z = 0, 110 do
		for origin_x = 0, 110 do
			lattice_lines[#lattice_lines + 1] = table.concat({"housing_lattice",
				row.id,tostring(origin_x),tostring(origin_z),
				tostring(row.lattice.counts[origin_z + 1][origin_x + 1])},"\t") .. "\n"
		end
	end
	add("housing_lattice_sha256",row.id,
		hex(raw_sha256(table.concat(lattice_lines))))
	local upper_lines = {}
	for cell_index = 1, #row.upper_bound_partition.occupied_cells do
		local cell = row.upper_bound_partition.occupied_cells[cell_index]
		upper_lines[cell_index] = table.concat({"housing_upper_cell",row.id,
			tostring(cell.cell_x),tostring(cell.cell_z)},"\t") .. "\n"
	end
	add("housing_upper_partition_sha256",row.id,
		hex(raw_sha256(table.concat(upper_lines))))
	for order_index = 1, #row.portfolio.orders do
		local order = row.portfolio.orders[order_index]
		local placement_lines = {}
		for placement_index = 1, #order.placements do
			local point = order.placements[placement_index]
			placement_lines[placement_index] = table.concat({"housing_placement",
				row.id,order.id,tostring(placement_index),tostring(point.x),
				tostring(point.z)},"\t") .. "\n"
		end
		local first = order.placements[1]
		local last = order.placements[#order.placements]
		add("housing_order",row.id,order.id,order.kind,order.count,
			hex(raw_sha256(table.concat(placement_lines))),
			first and first.x,first and first.z,last and last.x,last and last.z)
	end
end
for index = 1, #housing.witnesses do
	local row = housing.witnesses[index]
	add("housing_witness",row.code,row.mask_id,row.count,row.order_id,
		row.origin_x,row.origin_z,row.cell_size)
end
local housing_result_lines = {}
for index = housing_line_start, #lines do
	housing_result_lines[#housing_result_lines + 1] = lines[index] .. "\n"
end
add("housing_result_sha256",hex(raw_sha256(table.concat(housing_result_lines))))
housing = nil
collectgarbage("collect")

local body = table.concat(lines,"\n") .. "\n"
local artifact_digest = hex(raw_sha256(body))
local bytes = body .. "artifact_sha256\t" .. artifact_digest .. "\n"
local temporary = scratch .. "/simple-map-r2-artifact.tsv"
local file = assert(io.open(temporary,"wb"))
assert(file:write(bytes))
assert(file:close())
file = assert(io.open(temporary,"rb"))
local verified = assert(file:read("*a"))
assert(file:close())
assert(verified == bytes, "R2 artifact write verification failed")
file = assert(io.open(output,"wb"))
assert(file:write(verified))
assert(file:close())

progress("complete")
print("artifact_sha256\t" .. artifact_digest)
