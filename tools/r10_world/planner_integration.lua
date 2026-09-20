-- LuaJIT development check: real source -> real R5 constructor -> plan_slice.
local repo = assert(arg[1])
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local fixtures = dofile(repo .. "/tools/wp40/r6/fixtures.lua")(repo, common, common.new_sha256())
local deps = {source = dofile(dir .. "/source/simple_map.lua"), raw_sha256 = common.new_sha256(),
	coupled_grade = dofile(dir .. "/coupled_grade.lua")()}
for name, filename in pairs({zones_factory = "zones", planner_factory = "planner",
	adapter_factory = "map_adapter", manifest_module = "mapgen_manifest",
	allocator_factory = "counting_allocator", schemas = "schemas", canonical = "canonical",
	deterministic = "deterministic", index128 = "index128", horizontal_factory = "simple_map",
	height_factory = "height"}) do deps[name] = dofile(dir .. "/" .. filename .. ".lua") end
local contract = fixtures.new_content_contract()
local zones, source, planner = dofile(dir .. "/r5.lua")(deps).new_runtime(
	"4151598227737528026", 1, fixtures.r5_manifest(), contract.r5,
	fixtures.context({}))
local _, _, zone, biome, _, terrain, _, _, _, kind = source.column_values_at(-71, -2458)
assert(zone == "elandor_dawnmere_fields" and biome == "grug_meadows" and terrain == 21 and kind == "land_grade")
local plan = planner:plan_slice({x = -72, y = -32, z = -2459}, {x = -70, y = 47, z = -2457})
assert(plan.run_count > 0 and plan.column_start[10] == plan.run_count + 1)
local first, last = plan.column_start[5], plan.column_start[6] - 1
local at_surface
for index = first, last do
	local base = (index - 1) * 9
	if plan.run_values[base + 1] <= terrain and plan.run_values[base + 2] >= terrain then
		at_surface = plan.run_values[base + 4]
	end
end
assert(at_surface, "real plan lost the reported surface")
local _, content = dofile(repo .. "/tools/wp40/quality/surface_fixture.lua")(repo)
local selector = content.new_surface_selector("4151598227737528026", source)
for _, p in ipairs({{-3160, -310}, {3235, -310}}) do
	local water, _, _, id, _, y, water_y = source.column_values_at(p[1], p[2])
	assert(water == "land" and id == "grug_beach" and source.primary_relief_at(p[1], p[2]) == "mountain")
	assert(source.coast_profile_at(p[1], p[2]) == nil, "island shaping exclusion changed")
	assert(source.coast_material_at(p[1], p[2]), "excluded island lost material-only shore query")
	local row = selector(id, p[1], p[2], water_y, y)
	assert(row.top == "default:stone" or row.top == "default:gravel", "real island selector returned sand")
	print("island", p[1], y, p[2], row.top, row.shore)
end
print("real_planner", "PASS", plan.run_count, "reported_surface_opcode", at_surface)
