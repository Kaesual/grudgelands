-- Bounded R21 integration: real runtime/manifest/planner, selected owners only.
-- LuaJIT only. No engine or whole-world generation. Final nodes use the existing
-- engine-shaped VM proxy; native cave/lighting behavior is not an engine claim.
local repo=assert(arg[1])
assert(type(jit)=='table','integration uses LuaJIT only')
local dir=repo..'/mods/MAPGEN/grug_mapgen/wp40'
local common=dofile(repo..'/tools/wp40/r6/common.lua')
local api,projection=dofile(repo..'/tools/r10_map_b/runtime_fixture.lua')(repo,'7354267267733045968')
-- The older fixture predates authored R20 scenery. Load the shipped definitions
-- and rebuild the deterministic registry, instead of inventing node semantics.
dofile(repo..'/mods/MAPGEN/grug_mapgen/poi_displays.lua')({register_node=function(name,def)
 api.registered_nodes[name]=def
end})
local names,cids={},{}
for name in pairs(api.registered_nodes) do names[#names+1]=name end
table.sort(names)
for i,name in ipairs(names) do cids[name]=i end
function api.get_content_id(name) return assert(cids[name],name) end
function api.get_name_from_content_id(cid) return names[cid] end
api.CONTENT_AIR=cids.air;api.CONTENT_IGNORE=cids.ignore
local real_dofile=dofile
local private,prepared,manifest_inputs,manifest_api
prepared={}
-- Observe real constructor inputs/outputs without replacing their behavior.
rawset(_G,'dofile',function(path)
 local module=real_dofile(path)
 if path==dir..'/r6.lua' then
  return function(deps)
   local result=module(deps)
   local original=result.new_runtime
   result.new_runtime=function(...)
    local a,b,c,d,e=original(...);private=e;return a,b,c,d,e
   end
   return result
  end
 elseif path==dir..'/r7_settlement.lua' then
  local original=module.prepare
  module.prepare=function(profile,...)
   local result=original(profile,...)
   prepared[#prepared+1]={profile=profile,prepared=result}
   return result
  end
 elseif path==dir..'/r7_manifest.lua' then
  return function(...)
   local result=module(...);manifest_api=result
   local original=result.new
   result.new=function(inputs)
    manifest_inputs=inputs
    return original(inputs)
   end
   return result
  end
 end
 return module
end)
local start=os.clock()
local factory=dofile(dir..'/r7_runtime.lua')(api,dir,repo..'/mods/BASE/default/schematics',
 projection,dofile(repo..'/mods/ITEMS/grug_gathering/catalog.lua'))
local ok,built=pcall(factory.build,dofile(dir..'/r7_native.lua').identities())
rawset(_G,'dofile',real_dofile)
if manifest_inputs then
 local g=manifest_api.graph_digest_for_evidence
 local i=manifest_inputs
 local frozen={schema='grug_wp40_r7_source_projection_v1',
  r6_catalog=g({surfaces=i.r6_manifest.surfaces,resources=i.r6_manifest.resources,
   cultural=i.r6_manifest.cultural,decorations=i.r6_manifest.decorations}),
  accepted_r6_content=g(i.accepted_r6_rows),decoded_templates=g(i.decoded_templates),
  wp43_projection=g(i.wp43_projection),production_semantics=i.production_content.semantic_digest,
  p9g_semantics=i.p9g_content.semantic_digest,world_rules=g(i.world_content_rules),
  native_noise=i.native_identities.noise_digest,native_allowlist=i.native_identities.native_digest,
  gathering=i.gathering_manifest.sha256,cultural=g(i.cultural_registrations),
  consumer_payload=g(i.consumer_payload)}
 local keys={};for key in pairs(frozen) do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys) do print('pin',key,frozen[key]) end
 print('pin','SOURCE_PROJECTION_SHA256',g(frozen))
end
assert(ok,built)
assert(private and private.planner_source)
print('manifest',built.manifest.sha256,'cpu',os.clock()-start)
-- Construct the actual preparation bounds from the same captured runtime data.
local prep=dofile(dir..'/preparation_source.lua')(private.planner_source,
 private.template_records,manifest_inputs.cultural_registrations,prepared,
 built.zones_session,built.anchor_roster,'r21-bounded',api.sha256)
for _,point in ipairs({{1800,1448},{2056,1499},{-1680,-2932}}) do
 local x,z=point[1],point[2]
 local _,_,_,_,_,ground,water=private.planner_source.column_values_at(x,z)
 local low,high=prep.column_bounds(x,z)
 assert(low<=math.max(ground,(water or ground)-8) and high>=math.max(ground,water or ground))
 print('preparation',x,z,ground,water or '-',low,high)
end
local vm_module=dofile(repo..'/tools/wp40/simple_map_r5_vm.lua')
local outputs={}
built.round21_prepared=prepared
built.round21_planner_source=private.planner_source
local owners=dofile(repo..'/tools/round21/settlement_integration.lua').owners(built)
assert(#owners<=4,'bounded owner budget exceeded')
for _,lo in ipairs(owners) do
 local hi={x=lo.x+79,y=lo.y+79,z=lo.z+79}
 local axis,volume=112,112*112*112
 local emin={x=lo.x-16,y=lo.y-16,z=lo.z-16}
 local data,p2,light,hm={},{},{},{}
 for i=1,volume do data[i]=built.content.production.ignore_cid;p2[i]=0;light[i]=0 end
 for i=1,6400 do hm[i]=-31007 end
 for z=lo.z,hi.z do for y=lo.y,hi.y do for x=lo.x,hi.x do
  data[(z-emin.z)*axis*axis+(y-emin.y)*axis+x-emin.x+1]=api.CONTENT_AIR
 end end end
 local vm,_,observer=vm_module.new({minp=lo,maxp=hi,data=data,param2=p2,light=light,
  heightmap=hm,content_contract=built.content.production,water_level=1,
  ignore_cid=built.content.production.ignore_cid,verify_inactive_tail=false})
 local plan,generation=built.session.plan_slice(lo,hi)
 local result=built.writer.apply(vm,lo,hi,plan,generation)
 local snapshot=observer.snapshot()
 outputs[#outputs+1]={min=lo,max=hi,snapshot=snapshot,result=result}
 print('owner',lo.x,lo.y,lo.z,'cpu',os.clock()-start)
end
local metrics=private.successor_tail:metrics()
-- Save only columns consumed by the walkability helper, allowing diagnosis and
-- helper corrections without reconstructing the runtime or generating owners.
local replay={}
for _,out in ipairs(outputs) do
 local s=out.snapshot
 local sparse={emin=s.emin,emax=s.emax,data={},param2={}}
 local axis,sy=s.emax.x-s.emin.x+1,s.emax.y-s.emin.y+1
 for _,case in ipairs(built.round21_settlement_cases) do
  for p=0,case.length do
   local x,z=case.x+p*case.dx,case.z+p*case.dz
   for y=math.floor(case.expected)-24,math.floor(case.expected)+26 do
    if x>=out.min.x and x<=out.max.x and z>=out.min.z and z<=out.max.z and y>=out.min.y and y<=out.max.y then
     local i=(z-s.emin.z)*axis*sy+(y-s.emin.y)*axis+x-s.emin.x+1
     sparse.data[i]=s.data[i];sparse.param2[i]=s.param2[i]
    end
   end
  end
 end
 replay[#replay+1]={min=out.min,max=out.max,snapshot=sparse}
end
local function literal(value)
 if type(value)=='table' then
  local rows={}
  for k,v in pairs(value) do rows[#rows+1]='['..literal(k)..']='..literal(v) end
  table.sort(rows);return '{'..table.concat(rows,',')..'}'
 elseif type(value)=='string' then return string.format('%q',value)
 elseif type(value)=='number' or type(value)=='boolean' then return tostring(value)
 else return 'nil' end
end
local defs={}
for name,def in pairs(api.registered_nodes) do defs[name]={walkable=def.walkable,liquidtype=def.liquidtype,groups={stair=(def.groups or {}).stair}} end
local file=assert(io.open(repo..'/tools/round21/evidence/settlement-replay.lua','w'))
file:write('return ',literal({outputs=replay,cases=built.round21_settlement_cases,metrics=metrics,names=names,definitions=defs}),'\n');file:close()
for key,row in pairs(metrics) do
 if type(row)=='table' then for _,finding in ipairs(row.approach_findings or {}) do print('approach_finding',key,literal(finding)) end end
end
dofile(repo..'/tools/round21/settlement_integration.lua').check(built,api,outputs,metrics)
print('R21_INTEGRATION_PASS','owners',#owners,'cpu',os.clock()-start)
