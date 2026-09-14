-- world.md section 2 R1: an ordinary road stays claim-excluded. Around every
-- start, every column whose functional surface belongs to a route or a POI spur
-- must be inside a compiled claim exclusion. This counts the columns that are
-- not, per start and per Chebyshev band, and reports the worst offender so a
-- violation can be looked at on the map.
local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local src = dofile(directory .. "/source/simple_map.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(directory .. "/simple_map.lua")({source = src,
	schemas = dofile(directory .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local height = dofile(directory .. "/height.lua")({source = src,
	canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal, coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
}).new_runtime(seed)
local RADIUS = 400
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
file:write("start\tband\troad_columns\tunprotected\tworst_x\tworst_z\tfeature\n")
for anchor_index = 1, 6 do
	local anchor = src.anchors[anchor_index]
	local ax, az = anchor.position.x, anchor.position.z
	local bands = {{0, 127, "envelope_0_127"}, {128, 320, "approach_128_320"},
		{321, RADIUS, "beyond_321"}}
	local roads, bad, worst = {}, {}, {}
	for _, band in ipairs(bands) do roads[band[3]], bad[band[3]] = 0, 0 end
	for z = az - RADIUS, az + RADIUS do
		for x = ax - RADIUS, ax + RADIUS do
			local chebyshev = math.max(math.abs(x - ax), math.abs(z - az))
			local kind, _, feature = height.functional_surface_values_at(x, z)
			if kind == "land_grade" and type(feature) == "string" and
					(feature:match("^route_") or feature:match("^poi_spur_")) then
				local key
				for _, band in ipairs(bands) do
					if chebyshev >= band[1] and chebyshev <= band[2] then key = band[3] end
				end
				if key then
					roads[key] = roads[key] + 1
					if horizontal.static_exclusion_values_at(x, z) == nil then
						bad[key] = bad[key] + 1
						if not worst[key] then
							worst[key] = {x = x, z = z, feature = feature}
						end
					end
				end
			end
		end
	end
	for _, band in ipairs(bands) do
		local key = band[3]
		local row = worst[key]
		file:write(table.concat({anchor.id, key, roads[key], bad[key],
			row and row.x or "-", row and row.z or "-",
			row and row.feature or "-"}, "\t"), "\n")
	end
end
assert(file:close())
print("road_protection\tok\t" .. output)
