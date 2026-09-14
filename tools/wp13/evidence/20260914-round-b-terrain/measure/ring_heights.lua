-- Raw terrain height dump around every start, for a before/after column diff.
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
local out = {}
for anchor_index = 1, 6 do
	local anchor = src.anchors[anchor_index]
	local ax, az = anchor.position.x, anchor.position.z
	for z = az - 140, az + 140 do
		for x = ax - 140, ax + 140 do
			out[#out + 1] = anchor.id .. "\t" ..
				math.max(math.abs(x - ax), math.abs(z - az)) .. "\t" ..
				height.terrain_height_at(x, z) .. "\n"
			if #out >= 4096 then
				file:write(table.concat(out))
				out = {}
			end
		end
	end
end
file:write(table.concat(out))
assert(file:close())
print("height_dump\tok\t" .. output)
