-- Round 51 TERRAIN T2: a top-view raster of a few regions for the shots
-- (region_png.py turns it into images).
--
--   luajit tools/r51_terrain/region_dump.lua REPO SEED STEP OUT x0 z0 x1 z1 [...]
--
-- One line per column, north (high z) first: "x z class zone floor_y".
local repo, seed, step, out = arg[1], arg[2], tonumber(arg[3]), arg[4]
assert(repo and seed and step and out and arg[8],
	"usage: region_dump.lua REPO SEED STEP OUT x0 z0 x1 z1 [...]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local file = assert(io.open(out, "w"))
local i = 5
while arg[i] do
	local x0, z0, x1, z1 = tonumber(arg[i]), tonumber(arg[i + 1]), tonumber(arg[i + 2]),
		tonumber(arg[i + 3])
	file:write(("# region %d %d %d %d %d\n"):format(x0, z0, x1, z1, step))
	for z = z1, z0, -step do
		for x = x0, x1, step do
			file:write(("%d %d %s %s %d\n"):format(x, z, S.water_class_at(x, z),
				tostring(S.id_at(x, z)), S.terrain_height_at(x, z)))
		end
	end
	i = i + 4
end
file:close()
