-- One final compact process per interpreter; never a seed fleet.
local repo = assert(arg[1], "repository root required")
local jit_info = rawget(_G, "jit")
io.stderr:write(_VERSION, "\t", jit_info and jit_info.version or "PUC", "\n")
io.write("schema\tgrug_wp40_quality_final_micro_v1\n")
for _, relative in ipairs({
	"tools/wp40/tree_slices/fixture.lua",
	"tools/wp40/quality/gravewood_fixture.lua",
	"tools/wp40/quality/banner_fixture.lua",
	"tools/wp40/quality/gravewood_writer_fixture.lua",
	"tools/wp40/quality/flight_fixture.lua",
	"tools/wp40/quality/coupled_grade_oracle.lua",
	"tools/wp40/resource_sampling/primitives.lua",
	"tools/wp40/resource_sampling/sampler_fixture.lua",
	"tools/wp40/resource_sampling/writer_fixture.lua",
	"tools/wp40/quality/surface_fixture.lua",
	"tools/wp40/quality/cover_fixture.lua",
	"tools/wp40/quality/junction_micro.lua",
	"tools/wp40/quality/cave_fixture.lua",
	"tools/wp40/planner_throughput/fixture.lua",
	"tools/wp40/planner_throughput/r5_fixture.lua",
	"tools/wp40/quality/vendor_fixture.lua",
	"tools/wp43/fresh_server_fixture.lua",
	"tools/wp13/blueprint_kat.lua",
	"tools/r6_shore/kat.lua",
	"tools/r7_level_bands/kat.lua",
}) do
	io.write((dofile(repo .. "/" .. relative)(repo)))
	collectgarbage("collect")
end
dofile(repo .. "/tools/wp40/r7/anchor_activation_kat.lua")
assert(loadfile(repo .. "/tools/wp40/quality_geometry_micro_kat.lua"))(repo)
io.write(dofile(repo .. "/tools/wp40/r7/micro_kat.lua")(repo))

io.write("wp13_integration\t", dofile(repo .. "/tools/wp13/integration_fixture.lua")(repo), "\n")
