-- Dump the WP40 functional feature of every column of a box, for the renderer.
--
--     luajit feature_map.lua <repo> <seed> <cx> <cz> <half> <out.tsv>
--
-- One row per column: x, z, functional kind, functional feature, terrain y and
-- whether water stands on it. That is enough to draw where a road IS, which is
-- the whole question this lane answers.
--
-- Plain Lua 5.1 (LuaJIT for the eight-second WP40 construction).

local repo, seed = assert(arg[1]), assert(arg[2])
local cx, cz, half = tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
local out_path = assert(arg[6])
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = dofile(wp40 .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local rows = {"# centre " .. cx .. "," .. cz .. " half " .. half ..
	" seed " .. seed .. "\n", "x\tz\tkind\tfeature\tterrain\twater\n"}
for z = cz - half, cz + half do
	for x = cx - half, cx + half do
		local kind, _, feature = height.functional_surface_values_at(x, z)
		local terrain_y = height.terrain_height_at(x, z)
		local water_y = height.water_surface_at(x, z)
		local wet = (type(water_y) == "number" and water_y > terrain_y) and 1 or 0
		rows[#rows + 1] = table.concat({x, z, tostring(kind), tostring(feature),
			terrain_y, wet}, "\t") .. "\n"
	end
end
local file = assert(io.open(out_path, "wb"))
assert(file:write(table.concat(rows)))
assert(file:close())
io.write("feature map written: ", out_path, "\n")
