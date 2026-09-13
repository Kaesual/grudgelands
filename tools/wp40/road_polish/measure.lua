-- LuaJIT-only full geometry witness; final portable parity uses the quality micro-KAT.
local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(directory .. "/source/simple_map.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(directory .. "/simple_map.lua")({source = source,
	schemas = dofile(directory .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local started = os.clock()
local height = dofile(directory .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal, coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
}).new(seed)
local evidence = height.artifact_evidence()
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\nconstruction_seconds\t", string.format("%.6f", os.clock() - started), "\n")
file:write("path\tnodes\tmax_cut\tmax_fill\tmax_step\tpins\tpin_digest\twater_bounds\twater_digest\n")
for _, row in ipairs(evidence.routes) do
	assert(row.maximum_step <= 1, "route step limit exceeded")
	file:write(table.concat({row.id, row.node_count, row.observed_max_cut,
		row.observed_max_fill, row.maximum_step, row.exact_pin_count,
		row.exact_pin_digest, row.water_lower_bound_run_count,
		row.lower_bound_digest}, "\t"), "\n")
end
for _, site in ipairs({{1580,1540}, {1315,1435}, {-1013,958}, {-225,901}, {-1837,-437}}) do
	local count, low, high = 0, nil, nil
	for z = site[2] - 32, site[2] + 32 do
		for x = site[1] - 32, site[1] + 32 do
			local kind, y, id = height.functional_surface_values_at(x,z)
			if kind == "land_grade" and id and (id:match("^route_") or id:match("^approach_")) then
				count, low, high = count + 1, math.min(low or y,y), math.max(high or y,y)
			end
		end
	end
	file:write(table.concat({"site",site[1],site[2],count,low or "none", high or "none"}, "\t"), "\n")
end
assert(file:close())
print("road_geometry_measure\tok\t" .. output)
