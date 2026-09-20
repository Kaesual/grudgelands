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
local points={{-50,-1500},{-49,-1500},{49,-1500},{50,-1500}, {0,-1550},{0,-1549}}
for _,p in ipairs(points) do
 local tuple={source.column_values_at(p[1],p[2])}
 local y=assert(tonumber(tuple[6]))
 local plan=planner:plan_slice({x=p[1],y=y-2,z=p[2]}, {x=p[1],y=y+3,z=p[2]})
 assert(plan.run_count>0 and plan.column_start[2]==plan.run_count+1)
 local covered=0
 for i=1,plan.run_count do
  local base=(i-1)*9
  covered=covered+plan.run_values[base+2]-plan.run_values[base+1]+1
 end
 assert(covered==6,"real planner lost a core/avenue boundary cell")
 print("capital_boundary_real_planner",p[1],p[2],y,plan.run_count)
end
