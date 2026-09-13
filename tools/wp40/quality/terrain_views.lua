-- Sample the real global terrain authority for reproducible geometry views.
local repo, output = assert(arg[1]), assert(arg[2])
local seed = arg[3] or "13191094842853985814"
local fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
	repo, seed, true)
local runtime = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua")(
	fixture.core, repo .. "/mods/MAPGEN/grug_mapgen/wp40",
	repo .. "/mods/BASE/default/schematics", fixture.projection, fixture.catalog)
local built = runtime.build_authority(fixture.native_identities)
local zones = built.zones_session
local file = assert(io.open(output, "w"))
file:write("site\tx\tz\ty\tbiome\twater\n")
for _, site in ipairs({
	{"dwarf_start", -1800, -2550, 384},
	{"dwarf_capital", -1800, -1500, 400},
	{"road", 1000, 1000, 160},
}) do
	for z = site[3] - site[4], site[3] + site[4], 4 do
		for x = site[2] - site[4], site[2] + site[4], 4 do
			file:write(site[1], "\t", x, "\t", z, "\t",
				zones.terrain_height_at(x, z), "\t", zones.biome_at(x, z) or "-",
				"\t", zones.water_class_at(x, z), "\n")
		end
	end
end
assert(file:close())
io.write("Terrain views sampled for seed ", seed, "\n")
