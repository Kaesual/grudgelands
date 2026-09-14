-- Start pad edge witness. Per start:
--   * reference_y and spawn_y, which the jitter may not move;
--   * envelope_deviations: columns inside the half-open 128 square whose own
--     start grade is not exactly reference_y (must be 0);
--   * outer_grade: columns at Chebyshev 128..135 that the start fitting still
--     grades (must be 0 outside the frozen half-open envelope);
--   * the flat-edge profile: for each of the 4 x 127 perpendicular rays out of
--     the pad, the last offset in 63..127 that is still flat at reference_y,
--     reported as min/max/distinct plus a digest of the whole profile.
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
local reference_by_id = {}
for _, row in ipairs(height.quality_start_fitting_records()) do
	reference_by_id[row.id] = row.reference_y
end
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
file:write("start\treference_y\tspawn_y\tenvelope_deviations\touter_grade\t" ..
	"flat_min\tflat_max\tdistinct\tprofile_sha256\n")
for anchor_index = 1, 6 do
	local anchor = src.anchors[anchor_index]
	local ax, az = anchor.position.x, anchor.position.z
	local reference = assert(reference_by_id[anchor.id])
	local spawn = height.selected_anchor_3d_by_id(anchor.id).y
	local deviations, outer = 0, 0
	for z = az - 64, az + 63 do
		for x = ax - 64, ax + 63 do
			local kind, _, feature = height.functional_surface_values_at(x, z)
			if kind == "land_grade" and feature == anchor.id and
					height.terrain_height_at(x, z) ~= reference then
				deviations = deviations + 1
			end
		end
	end
	for z = az - 136, az + 136 do
		for x = ax - 136, ax + 136 do
			local chebyshev = math.max(math.abs(x - ax), math.abs(z - az))
			-- The fitting envelope is the half-open square [-128, 127]; a column
			-- past its positive edge may not be graded by this anchor any more.
			if chebyshev >= 129 and chebyshev <= 136 and x - ax >= -128 and
					z - az >= -128 then
				local _, _, feature = height.functional_surface_values_at(x, z)
				if feature == anchor.id then outer = outer + 1 end
			end
		end
	end
	local profile, minimum, maximum, distinct, distinct_count = {}, nil, nil, {}, 0
	for _, ray in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		for side = -63, 63 do
			local last = 63
			for offset = 64, 127 do
				local x = ax + ray[1] * offset + ray[2] * side
				local z = az + ray[2] * offset + ray[1] * side
				local kind, _, feature = height.functional_surface_values_at(x, z)
				if kind == "land_grade" and feature == anchor.id and
						height.terrain_height_at(x, z) == reference then
					last = offset
				else
					break
				end
			end
			profile[#profile + 1] = last
			minimum = minimum and math.min(minimum, last) or last
			maximum = math.max(maximum or last, last)
			if not distinct[last] then
				distinct[last] = true
				distinct_count = distinct_count + 1
			end
		end
	end
	file:write(table.concat({anchor.id, reference, spawn, deviations, outer,
		minimum, maximum, distinct_count,
		canonical.hex(raw_sha256(table.concat(profile, ",")))}, "\t"), "\n")
end
assert(file:close())
print("edge_probe\tok\t" .. output)
