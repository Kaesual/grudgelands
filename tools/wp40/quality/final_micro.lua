-- One final compact process per interpreter; never a seed fleet.
local repo = assert(arg[1], "repository root required")
local jit_info = rawget(_G, "jit")
io.stderr:write(_VERSION, "\t", jit_info and jit_info.version or "PUC", "\n")
io.write("schema\tgrug_round10_integrated_final_micro_v2\n")
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
	"tools/r8_map_a/kat.lua",
	"tools/r10_world/cave_boundary_fixture.lua",
	"tools/r10_world/material_salt_fixture.lua",
	"tools/r9_perf/cache_fixture.lua",
	"tools/r9_perf/lighting_fixture.lua",
	"tools/r9_farm/farming_kat.lua",
	"tools/r10_farm/final_micro.lua",
}) do
	io.write((dofile(repo .. "/" .. relative)(repo)))
	collectgarbage("collect")
end
dofile(repo .. "/tools/wp40/r7/anchor_activation_kat.lua")
assert(loadfile(repo .. "/tools/wp40/quality_geometry_micro_kat.lua"))(repo)
io.write(dofile(repo .. "/tools/wp40/r7/micro_kat.lua")(repo))

io.write("wp13_integration\t", dofile(repo .. "/tools/wp13/integration_fixture.lua")(repo), "\n")

-- Integration replacements use the current shared modules and CAP-updated
-- trainer/station fixtures. Each returned fixture restores its own stubs.
local function run(relative, options)
	local result = assert(dofile(repo .. "/" .. relative))(repo, options)
	if result then io.write(result) end
	collectgarbage("collect")
end
for _, relative in ipairs({
	"tools/r8_prof/framework_kat.lua",
	"tools/r8_prof/geometry_kat.lua",
	"tools/r8_prof/scaling_kat.lua",
	"tools/r8_prof/trainer_sockets_kat.lua",
	"tools/r9_prof/blacksmith_kat.lua",
	"tools/r9_prof/leatherworker_kat.lua",
	"tools/r9_prof/tailor_kat.lua",
	"tools/r9_prof/woodcarver_kat.lua",
	"tools/r9_prof/goldsmith_kat.lua",
	"tools/r9_prof/stations_kat.lua",
	"tools/r9_ench/quality_kat.lua",
	"tools/wp13/gear_catalogue_kat.lua",
	"tools/r10_equip/base_recipes_kat.lua",
	"tools/r10_equip/profession_contract_kat.lua",
	"tools/r10_equip/vendor_rotation_kat.lua",
	"tools/r10_cap/geometry_micro.lua",
	"tools/r10_cap/services_micro.lua",
	"tools/r10_cap/purchase_micro.lua",
	"tools/r10_cap/furnace_micro.lua",
	"tools/wp13/character_visuals_kat.lua",
	"tools/r10_art/mount_icon_kat.lua",
	"tools/r10_art/art_kat.lua",
	"tools/r10_gameplay/cliff_kat.lua",
	"tools/r6_food_buffs/kat.lua",
	"tools/r8_mob1/bosses_kat.lua",
}) do run(relative) end
-- The full mount binary/asset audit belongs to LuaJIT development only.
run("tools/r9_mounts/mounts_kat.lua", {compact = true})
run("tools/r10_gameplay/potion_kat.lua")
-- This standalone fixture reads arg[1], prints its canonical output and leaves
-- globals installed. It must stay last; do not append returned fixtures below.
dofile(repo .. "/tools/wp39/combat_integration_test.lua")
