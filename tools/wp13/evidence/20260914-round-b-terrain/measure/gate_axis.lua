-- Start-approach probe: road columns on the gate axis around every start.
local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local src = dofile(directory .. "/source/simple_map.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(directory .. "/simple_map.lua")({source = src,
	schemas = dofile(directory .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local started = os.clock()
local height = dofile(directory .. "/height.lua")({source = src,
	canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal, coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
}).new_runtime(seed)
local build_seconds = os.clock() - started
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\nconstruction_seconds\t",
	string.format("%.3f", build_seconds), "\n")

-- Gate direction: Elandor starts open toward +z, Kragmar starts toward -z.
local starts = {
	{key = "hearthpine", anchor = "anchor_001", x = -1800, z = -2550, s = 1},
	{key = "dawnmere", anchor = "anchor_002", x = 0, z = -2550, s = 1},
	{key = "silverleaf", anchor = "anchor_003", x = 1800, z = -2550, s = 1},
	{key = "stillgrave", anchor = "anchor_004", x = -1800, z = 2550, s = -1},
	{key = "sunscar", anchor = "anchor_005", x = 0, z = 2550, s = -1},
	{key = "kapok", anchor = "anchor_006", x = 1800, z = 2550, s = -1},
}
local function is_road(feature_id)
	return type(feature_id) == "string" and
		(feature_id:match("^route_") ~= nil or feature_id:match("^poi_spur_") ~= nil)
end
file:write("start\tanchor\trow_offset\tmin_x\tmax_x\tcount\tholes\tfeature\n")
for _, row in ipairs(starts) do
	for offset = 56, 160, 8 do
		local z = row.z + row.s * offset
		local min_x, max_x, count, feature = nil, nil, 0, "-"
		for x = row.x - 150, row.x + 150 do
			local kind, _, feature_id = height.functional_surface_values_at(x, z)
			if kind == "land_grade" and is_road(feature_id) then
				count = count + 1
				min_x = min_x and math.min(min_x, x) or x
				max_x = math.max(max_x or x, x)
				feature = feature_id
			end
		end
		local holes = (min_x and (max_x - min_x + 1 - count)) or 0
		file:write(table.concat({row.key, row.anchor, offset,
			tostring(min_x and min_x - row.x), tostring(max_x and max_x - row.x),
			count, holes, feature}, "\t"), "\n")
	end
end
assert(file:close())
print("start_approach_probe\tok\t" .. output)
