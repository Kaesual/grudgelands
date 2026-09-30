-- Round 27 wall fixes: a vertical section through a capital's city edge as
-- the shipped writer builds it on a seed's final ground (LuaJIT, no engine).
--
--   luajit tools/r26_capitals/section.lua <repo> <seed> <capital> <x0> <z0> <x1> <z1> <out.tsv>
--
-- Walks the straight line of columns from (x0, z0) to (x1, z1) and writes one
-- line per column: `i x z ground water road` then `y:name` for every edge
-- cell (air included), for tools/r26_capitals/section.py.
local repo, seed, key = arg[1], arg[2], arg[3]
local x0, z0, x1, z1 = tonumber(arg[4]), tonumber(arg[5]), tonumber(arg[6]), tonumber(arg[7])
local out_path = arg[8]
assert(out_path, "usage: section.lua <repo> <seed> <capital> <x0> <z0> <x1> <z1> <out.tsv>")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local W = dofile(here .. "/world.lua")(repo)
local blueprint = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_capital_blueprint.lua")
local run = W.plan(seed)
local texts = W.planner.split(run.text .. "\n")
local plan = run.plans[key]
local id = plan.anchor.id
local L = W.planner.deserialize(texts[id])
local S = run.session
local edge = blueprint.source(key, L, texts[id]).overlay.make({x = L.anchor.x, z = L.anchor.z})
local n = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
local out = assert(io.open(out_path, "w"))
local function column(x, z)
	local t = S.terrain_height_at(x, z)
	local wy = S.water_surface_at(x, z)
	if wy and wy <= t then wy = nil end
	return t, wy, S.road_column_at(x, z) == "surface"
end
for i = 0, n do
	local x = math.floor(x0 + (x1 - x0) * i / math.max(n, 1) + 0.5)
	local z = math.floor(z0 + (z1 - z0) * i / math.max(n, 1) + 0.5)
	local t, wy, road = column(x, z)
	local cells = edge.cells({min_x = x, max_x = x, min_z = z, max_z = z}, column)
	local parts = {i, x, z, t, wy or "-", road and 1 or 0}
	for _, c in ipairs(cells) do parts[#parts + 1] = c.y .. ":" .. c.name end
	out:write(table.concat(parts, "\t"), "\n")
end
out:close()
