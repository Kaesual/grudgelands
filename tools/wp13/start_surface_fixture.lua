-- Bounded LuaJIT integration for dry-start biome surface restoration.

return function(repo)
	assert(type(repo) == "string", "repository root required")

local loader = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
local loaded = loader.new_internal("531802985935182545",
	loader.heightmap(-31007), false, true)
local source = loaded.planner_source
local anchor_x, anchor_z = -1800, -2550
assert(select(6, source.column_values_at(anchor_x, anchor_z)) == 25,
	"Hearthpine anchor height differs")
local surface_x, surface_z
for z = anchor_z - 42, anchor_z + 37 do
	for x = anchor_x - 63, anchor_x + 7 do
		if select(10, source.column_values_at(x, z)) == "land_grade" and
				select(12, source.column_values_at(x, z)) == "anchor_001" then
			surface_x, surface_z = x, z
			break
		end
	end
	if surface_x then break end
end
assert(surface_x, "Hearthpine fitting surface witness missing")
local terrain_y = select(6, source.column_values_at(surface_x, surface_z))
assert(loaded.horizontal.static_exclusion_values_at(anchor_x, anchor_z) ~= nil and
	loaded.horizontal.static_exclusion_values_at(surface_x, surface_z) ~= nil,
	"protected start core lost its decoration exclusion")
local protected_start_columns = 0
for z = anchor_z - 120, anchor_z + 120 do
	for x = anchor_x - 120, anchor_x + 120 do
		if select(10, source.column_values_at(x, z)) == "land_grade" and
				select(12, source.column_values_at(x, z)) == "anchor_001" then
			protected_start_columns = protected_start_columns + 1
			assert(loaded.horizontal.static_exclusion_values_at(x, z) ~= nil,
				"start fitting admitted a decoration candidate")
		end
	end
end
assert(protected_start_columns > 0, "start fitting exclusion witness missing")

local _, _, _, _, _, _, _, surface_kind, surface, _, _, p7_support =
	loaded.planner_fixture.column_values_at(surface_x, surface_z)
assert(surface_kind == 1 and surface and not p7_support,
	"protected dry start became a decoration candidate")
assert(loaded.settlement_fixture.analytic_p7_material_ref(
	surface_x, terrain_y, surface_z) == surface.top_ref)
for depth = 1, surface.filler_depth do
	assert(loaded.settlement_fixture.analytic_p7_material_ref(
		surface_x, terrain_y - depth, surface_z) == surface.filler_ref)
end

-- Other land grades retain their authored path/terrace surface semantics.
local capital_x, capital_z
for z = -1540, -1460 do
	for x = -40, 40 do
		if select(10, source.column_values_at(x, z)) == "land_grade" and
				select(12, source.column_values_at(x, z)) == "anchor_008" then
			capital_x, capital_z = x, z
			break
		end
	end
	if capital_x then break end
end
assert(capital_x, "capital grade control witness missing")
local capital_y = select(6, source.column_values_at(capital_x, capital_z))
assert(select(12, loaded.planner_fixture.column_values_at(capital_x,
	capital_z)) == false)
assert(loaded.settlement_fixture.analytic_p7_material_ref(
	capital_x, capital_y, capital_z) == nil)
local road_x, road_z
for z = anchor_z, anchor_z + 240 do
	local kind = select(10, source.column_values_at(anchor_x, z))
	local feature = select(12, source.column_values_at(anchor_x, z))
	if kind == "land_grade" and feature ~= "anchor_001" then
		road_x, road_z = anchor_x, z
		break
	end
end
assert(road_x, "Hearthpine road control witness missing")
local road_y = select(6, source.column_values_at(road_x, road_z))
assert(select(12, loaded.planner_fixture.column_values_at(road_x, road_z)) == false)
assert(loaded.settlement_fixture.analytic_p7_material_ref(
	road_x, road_y, road_z) == nil)

-- Exercise the actual retained planner and single settlement transaction for
-- the owner containing the start centre.
local actual = loader.new_public("531802985935182545",
	loader.heightmap(-31007), false)
local minp = {x = -1872, y = -32, z = -2592}
local maxp = {x = -1793, y = 47, z = -2513}
local plan, generation = actual.session.plan_slice(minp, maxp)
local volume = 112 * 112 * 112
local data, param2, light = {}, {}, {}
for index = 1, volume do data[index], param2[index], light[index] = 0, 0, 0 end
local vm, _, observer = loader.vm_module.new({minp = minp, maxp = maxp,
	data = data, param2 = param2, light = light,
	heightmap = loader.heightmap(-31007),
	content_contract = actual.content_contract, water_level = 1,
	ignore_cid = actual.content_contract.ignore_cid,
	verify_inactive_tail = false})
actual.session.apply_fixture(vm, minp, maxp, plan, generation)
local snapshot = observer.snapshot()
local emerged_min = {x = minp.x - 16, y = minp.y - 16, z = minp.z - 16}
local function cid_at(x, y, z)
	return snapshot.data[(z - emerged_min.z) * 112 * 112 +
		(y - emerged_min.y) * 112 + (x - emerged_min.x) + 1]
end
assert(cid_at(surface_x, terrain_y, surface_z) ==
	actual.content_contract.content_cids[surface.top_ref],
	"production P7 did not restore the start top")
for depth = 1, surface.filler_depth do
	assert(cid_at(surface_x, terrain_y - depth, surface_z) ==
		actual.content_contract.content_cids[surface.filler_ref],
		"production P7 did not restore start filler")
end
assert(cid_at(surface_x, terrain_y - surface.filler_depth - 1, surface_z) ~=
	actual.content_contract.content_cids[surface.filler_ref],
	"start restoration replaced substrate below biome filler")

-- Seed 8675309 puts anchor_004 at y=48, exactly one node above an owner's
-- y=47 ceiling. Its below-owner transaction sees filler opcode 21 without the
-- top opcode 22 and must still restore the biome filler.
local boundary_checked = loader.new_internal("8675309",
	loader.heightmap(-31007), false, true)
local boundary_source = boundary_checked.planner_source
local boundary = loader.new_public("8675309", loader.heightmap(-31007), false)
local boundary_x, boundary_z
for z = 2528, 2607 do
	for x = -1863, -1793 do
		if select(6, boundary_source.column_values_at(x, z)) == 48 and
				select(10, boundary_source.column_values_at(x, z)) == "land_grade" and
				select(12, boundary_source.column_values_at(x, z)) == "anchor_004" then
			boundary_x, boundary_z = x, z
			break
		end
	end
	if boundary_x then break end
end
assert(boundary_x, "filler-only owner witness missing")
local boundary_min = {x = -1872, y = -32, z = 2528}
local boundary_max = {x = -1793, y = 47, z = 2607}
local boundary_plan, boundary_generation = boundary.session.plan_slice(
	boundary_min, boundary_max)
local boundary_data, boundary_param2, boundary_light = {}, {}, {}
for index = 1, volume do
	boundary_data[index], boundary_param2[index], boundary_light[index] = 0, 0, 0
end
local boundary_vm, _, boundary_observer = loader.vm_module.new({
	minp = boundary_min, maxp = boundary_max, data = boundary_data,
	param2 = boundary_param2, light = boundary_light,
	heightmap = loader.heightmap(-31007),
	content_contract = boundary.content_contract, water_level = 1,
	ignore_cid = boundary.content_contract.ignore_cid,
	verify_inactive_tail = false})
boundary.session.apply_fixture(boundary_vm, boundary_min, boundary_max,
	boundary_plan, boundary_generation)
local boundary_snapshot = boundary_observer.snapshot()
local boundary_emerged = {x = boundary_min.x - 16, y = boundary_min.y - 16,
	z = boundary_min.z - 16}
local boundary_index = (boundary_z - boundary_emerged.z) * 112 * 112 +
	(47 - boundary_emerged.y) * 112 + (boundary_x - boundary_emerged.x) + 1
local boundary_column = (boundary_z - boundary_min.z) * 80 +
	(boundary_x - boundary_min.x) + 1
local boundary_base = (boundary_column - 1) * 12
assert(boundary_plan.column_values[boundary_base + 5] == 48,
	"filler-only terrain boundary differs")
local boundary_filler_ref = boundary_plan.column_values[boundary_base + 9]
assert(boundary_snapshot.data[boundary_index] ==
	boundary.content_contract.content_cids[boundary_filler_ref],
	"filler-only owner did not restore start filler")

return table.concat({"start_surface", surface_x, surface_z, terrain_y, surface.id,
	surface.top_ref, surface.filler_ref, surface.filler_depth,
	road_x, road_z, road_y, protected_start_columns, boundary_x, boundary_z,
	boundary_snapshot.calls.set_data}, "\t") .. "\n"
end
