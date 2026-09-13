-- One final compact process per interpreter; never a seed fleet.
local repo = assert(arg[1], "repository root required")
local jit_info = rawget(_G, "jit")
io.stderr:write(_VERSION, "\t", jit_info and jit_info.version or "PUC", "\n")
io.write("schema\tgrug_wp40_quality_final_micro_v1\n")
for _, relative in ipairs({
	"tools/wp40/tree_slices/fixture.lua",
	"tools/wp40/resource_rank/primitives.lua",
	"tools/wp40/resource_rank/fixture.lua",
	"tools/wp40/quality/surface_fixture.lua",
	"tools/wp40/quality/cover_fixture.lua",
	"tools/wp40/quality/cave_fixture.lua",
	"tools/wp40/quality/vendor_fixture.lua",
	"tools/wp43/fresh_server_fixture.lua",
}) do
	io.write((dofile(repo .. "/" .. relative)(repo)))
	collectgarbage("collect")
end
assert(loadfile(repo .. "/tools/wp40/quality_geometry_micro_kat.lua"))(repo)
io.write(dofile(repo .. "/tools/wp40/r7/micro_kat.lua")(repo))
