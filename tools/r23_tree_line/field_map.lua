-- Writes a PGM of the forest field (and optionally the jitter) over a square
-- window: luajit field_map.lua <repo> <seed> <x0> <z0> <size> <out.pgm> [jitter]
local repo, seed = arg[1], arg[2]
local x0, z0, size, out, what = tonumber(arg[3]), tonumber(arg[4]),
	tonumber(arg[5]), arg[6], arg[7] or "forest"
local habitat = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/habitat_registry.lua")
local rule = habitat.vegetation_rule(seed, function() return "z" end)
local file = assert(io.open(out, "wb"))
file:write(("P5\n%d %d\n255\n"):format(size, size))
local bytes = {}
for z = z0, z0 + size - 1 do
	for x = x0, x0 + size - 1 do
		local v
		if what == "jitter" then
			v = (rule.jitter(x, z) + 15) * 255 / 30
		else
			v = math.min(255, rule.forest(x, z, "z") * 255 / (2.5 * 4096))
		end
		bytes[#bytes + 1] = string.char(math.floor(v))
	end
	file:write(table.concat(bytes))
	bytes = {}
end
file:close()
