-- Focused engine-free fixture for the WP40 visual-quality height revision.

local repo, scratch = ...
assert(type(repo) == "string" and repo:sub(1, 1) == "/",
	"absolute repository root required")
assert(type(scratch) == "string" and
	scratch:match("^/tmp/grudgelands%-wp40%-quality%.[A-Za-z0-9]+$"),
	"safe scratch directory required")

local sha_counter, sha_cache = 0, {}
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
	assert(file:write(data))
	assert(file:close())
	local ok, why, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(ok == 0 or ok == true and why == "exit" and code == 0,
		"sha256sum failed")
	file = assert(io.open(output, "rb"))
	local line = assert(file:read("*l"))
	assert(file:close())
	assert(os.remove(input))
	assert(os.remove(output))
	local digest = from_hex(assert(line:match("^([0-9a-f]+)")))
	assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(directory .. "/source/simple_map.lua")
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
assert(horizontal_module.validate_source())

local seeds = {}
for index = 3, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"0", "13191094842853985814"} end
local capital_ids = {
	"anchor_007", "anchor_008", "anchor_009",
	"anchor_010", "anchor_011", "anchor_012",
}
local road_points = {
	{1000, 1000}, {968, 1000}, {1032, 1000},
	{1000, 968}, {1000, 1032},
}

for seed_index = 1, #seeds do
	local seed = seeds[seed_index]
	local horizontal = horizontal_module.new(seed)
	local height_module = dofile(directory .. "/height.lua")({
		source = source,
		canonical = canonical,
		deterministic = deterministic,
		raw_sha256 = raw_sha256,
		horizontal_session = horizontal,
		coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
	})
	local height = height_module.new_runtime_checked(seed)
	local quality = height.quality_geometry_records()
	assert(#quality == 6)
	io.write("seed\t", seed, "\n")
	for capital_index = 1, #capital_ids do
		local anchor = assert(height.selected_anchor_3d_by_id(
			capital_ids[capital_index]))
		local row = quality[capital_index]
		assert(row.id == anchor.id and row.reference_y == anchor.y)
		local distinct = {}
		for z = anchor.z - 256, anchor.z + 255, 16 do
			for x = anchor.x - 256, anchor.x + 255, 16 do
				distinct[height.terrain_height_at(x, z)] = true
			end
		end
		local distinct_count = 0
		for _ in pairs(distinct) do distinct_count = distinct_count + 1 end
		assert(distinct_count >= 4, "capital envelope remained visually flat")
		for z = anchor.z - 48, anchor.z + 47 do
			for x = anchor.x - 48, anchor.x + 47 do
				local water_class = horizontal.classification_values_at(x, z)
				local _, _, feature_id = height.functional_surface_values_at(x, z)
				if water_class == "land" and feature_id == anchor.id then
					assert(height.terrain_height_at(x, z) == anchor.y,
						"dry civic core is not flat")
				end
			end
		end
		io.write("capital\t", row.id, "\t", row.reference_y, "\t",
			row.reference_rule, "\t", row.feasible_lower_y, "\t",
			row.lower_witness_x, ",", row.lower_witness_z, "\t",
			row.feasible_upper_y, "\t", row.upper_witness_x, ",",
			row.upper_witness_z, "\t", row.limit_excess, "\t",
			distinct_count, "\n")
	end
	local road_min, road_max
	local first_pass = {}
	for point_index = 1, #road_points do
		local point = road_points[point_index]
		local value = height.terrain_height_at(point[1], point[2])
		first_pass[point_index] = value
		road_min = road_min and math.min(road_min, value) or value
		road_max = road_max and math.max(road_max, value) or value
	end
	for point_index = #road_points, 1, -1 do
		local point = road_points[point_index]
		assert(height.terrain_height_at(point[1], point[2]) ==
			first_pass[point_index], "query order changed height")
	end
	assert(road_max - road_min <= 2,
		"user road probe still has a terrain wall")
	io.write("road_probe\t", road_min, "\t", road_max, "\n")
end

io.write("quality_geometry_fixture\tok\n")
