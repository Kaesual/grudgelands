-- LuaJIT development fixture for natural-terrain start fitting.

local repo = assert(arg[1], "repository root required")
if arg[2] ~= nil then error("terrain fixture argument population differs", 0) end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

local seed = "531802985935182545"
local horizontal = horizontal_factory({source = source, schemas = schemas,
 canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local height = height_factory({source = source, canonical = canonical,
 deterministic = deterministic, raw_sha256 = raw_sha256,
 horizontal_session = horizontal, coupled_grade = coupled_grade}).new_runtime(seed)
for _, dz in ipairs({0, 50, 60, 63, 64, 65, 70, 80}) do
 io.write(dz, "\t", height.terrain_height_at(-1800, -2550 + dz), "\n")
end
