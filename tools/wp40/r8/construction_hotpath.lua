-- Bounded construction/RSS probe for the full emerge runtime and the
-- main-environment authority-only runtime. Run each mode in a fresh LuaJIT
-- process; manifest and roster equality are the correctness gates.

local repo, mode = arg[1], arg[2]
if type(repo) ~= "string" or repo == "" or
		(mode ~= "full" and mode ~= "authority") then
	error("usage: construction_hotpath.lua REPO full|authority", 0)
end

local clock = os.clock
local fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
	repo, "0", true)
collectgarbage("collect")
local before_heap = collectgarbage("count") * 1024
local runtime = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua")(
	fixture.core, repo .. "/mods/MAPGEN/grug_mapgen/wp40",
	repo .. "/mods/BASE/default/schematics", fixture.projection,
	fixture.catalog)
local started = clock()
local built
if mode == "authority" then
	built = runtime.build_authority(fixture.native_identities)
else
	built = runtime.build(fixture.native_identities)
end
local seconds = clock() - started
collectgarbage("collect")
local after_heap = collectgarbage("count") * 1024
if type(built) ~= "table" or type(built.manifest) ~= "table" or
		type(built.anchor_roster) ~= "table" then
	error("construction result differs", 0)
end
if mode == "authority" then
	if built.session ~= nil or built.writer ~= nil then
		error("authority runtime retained writer state", 0)
	end
elseif type(built.session) ~= "table" or type(built.writer) ~= "table" then
	error("full runtime omitted writer state", 0)
end

io.write("schema\tgrug_wp40_r8_construction_hotpath_v1\n")
io.write("mode\t", mode, "\n")
io.write(string.format("construction_cpu_seconds\t%.6f\n", seconds))
io.write(string.format("baseline_heap_bytes\t%.0f\n", before_heap))
io.write(string.format("retained_heap_delta_bytes\t%.0f\n", after_heap - before_heap))
io.write(string.format("heap_bytes_after_collect\t%.0f\n", after_heap))
io.write("manifest_sha256\t", built.manifest.sha256, "\n")
io.write("anchor_roster_sha256\t", built.anchor_roster.sha256, "\n")
