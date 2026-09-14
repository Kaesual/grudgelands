-- The height session's frozen construction digests, for a before/after diff.
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
}).new(seed)
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
file:write("canonical_kat_digest\t", height.canonical_kat_digest(), "\n")
file:write("relief_lattice_digest\t", height.relief_lattice_digest(), "\n")
file:write("base_lattice_digest\t", height.base_lattice_digest(), "\n")
local metrics = height.metrics()
local keys = {}
for key in pairs(metrics) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
	file:write("metric.", key, "\t", tostring(metrics[key]), "\n")
end
assert(file:close())
print("digest_probe\tok\t" .. output)
