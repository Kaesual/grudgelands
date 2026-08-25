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

add("schema","grug_wp40_simple_map_r2_artifact_v1")
add("layout_id",source.layout_id)
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
	"tools/wp40/run_simple_map_r2.sh",
}
for index=1,#input_paths do
	add("input_sha256",input_paths[index],file_sha256(input_paths[index]))
end
add("canonical_kat_sha256",session.canonical_kat_digest())
add("difficulty_lattice_sha256",session.difficulty_lattice_digest())
local warp = session.warp_proof()
for _, key in ipairs({"cell","maximum","max_horizontal_x",
	"max_horizontal_z","max_vertical_x","max_vertical_z","min_x","max_x",
	"min_z","max_z","min_ix","max_ix","min_iz","max_iz"}) do
	add("warp",key,warp[key])
end

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

progress("housing")
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
		row.auditable_upper_bound)
	for order_index = 1, #row.portfolio.orders do
		local order = row.portfolio.orders[order_index]
		add("housing_order",row.id,order.id,order.kind,order.count)
	end
end
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
