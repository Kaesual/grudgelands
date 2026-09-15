-- Per-start ring bands: how many columns the claim rule and the vegetation rule
-- exclude, and how many of them can host a biome decoration at all (the
-- planner's dry-start-grade support test).
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
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
-- host_claim is the planner's OLD decoration-host predicate (`not excluded`
-- against the full claim rule); host_vegetation is the new one.
file:write("start\tband\tcolumns\tclaim_excluded\tveg_excluded\t" ..
	"host_claim\thost_vegetation\n")
local bands = {{0, 63, "pad_0_63"}, {64, 73, "apron_64_73"},
	{74, 127, "blend_74_127"}, {128, 160, "outside_128_160"}}
for anchor_index = 1, 6 do
	local anchor = src.anchors[anchor_index]
	local id = anchor.id
	for _, band in ipairs(bands) do
		local columns, claim, veg, host_claim, host_veg = 0, 0, 0, 0, 0
		for z = anchor.position.z - band[2], anchor.position.z + band[2] do
			for x = anchor.position.x - band[2], anchor.position.x + band[2] do
				local chebyshev = math.max(math.abs(x - anchor.position.x),
					math.abs(z - anchor.position.z))
				if chebyshev >= band[1] and chebyshev <= band[2] then
					columns = columns + 1
					local claim_blocked =
						horizontal.static_exclusion_values_at(x, z) ~= nil
					if claim_blocked then claim = claim + 1 end
					local veg_blocked = horizontal.static_exclusion_values_at(x, z,
						"vegetation") ~= nil
					if veg_blocked then veg = veg + 1 end
					local kind, _, feature = height.functional_surface_values_at(x, z)
					-- The planner hosts a decoration on a column whose functional
					-- surface is nil, or is this start's own dry grade and not
					-- excluded. Both exclusion answers are applied to the second case
					-- so the old and the new predicate are measured in one pass.
					local start_grade = kind == "land_grade" and feature == id
					if kind == nil or (start_grade and not claim_blocked) then
						host_claim = host_claim + 1
					end
					if kind == nil or (start_grade and not veg_blocked) then
						host_veg = host_veg + 1
					end
				end
			end
		end
		file:write(table.concat({id, band[3], columns, claim, veg, host_claim, host_veg},
			"\t"), "\n")
	end
end
assert(file:close())
print("band_probe\tok\t" .. output)
