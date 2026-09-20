-- Bounded actual R5 planner + adapter on two thin owner slices, synthetic native
-- stone/soil/ore input. This is not engine-native v7 or a full R7 content census.
local repo=assert(arg[1]);local dir=repo..'/mods/MAPGEN/grug_mapgen/wp40'
local common=dofile(repo..'/tools/wp40/r6/common.lua')
local fixtures=dofile(repo..'/tools/wp40/r6/fixtures.lua')(repo,common,common.new_sha256())
local deps={source=dofile(dir..'/source/simple_map.lua'),raw_sha256=common.new_sha256(),
 coupled_grade=dofile(dir..'/coupled_grade.lua')()}
for name,file in pairs({zones_factory='zones',planner_factory='planner',adapter_factory='map_adapter',
 manifest_module='mapgen_manifest',allocator_factory='counting_allocator',schemas='schemas',
 canonical='canonical',deterministic='deterministic',index128='index128',horizontal_factory='simple_map',
 height_factory='height'})do deps[name]=dofile(dir..'/'..file..'.lua')end
local contract,cids=fixtures.new_content_contract()
local function filled(n,v)local a={};for i=1,n do a[i]=v end;return a end
local hm=filled(6400,24)
local _,source,planner,adapter=dofile(dir..'/r5.lua')(deps).new_runtime(
 '15140735923413111218',1,fixtures.r5_manifest(),contract.r5,fixtures.context(hm))
local ore
for _,name in ipairs(contract.content_names)do
 if contract.classify(cids[name],0)==10 then ore=name;break end
end
assert(ore,'fixture must include a real ore class')
local names={'default:stone','default:dirt_with_grass',ore}
local _,replace=dofile(dir..'/map_adapter.lua')
for _,name in ipairs(names)do
 local class=contract.classify(assert(cids[name]),0)
 assert(replace(1,class,0,0,1,2)==1,'terrain clear must cut '..name)
end
for _,p in ipairs({{-415,-2720},{-485,-2575}})do
 local minp={x=math.floor((p[1]+32)/80)*80-32,y=2,z=math.floor((p[2]+32)/80)*80-32}
 local maxp={x=minp.x+79,y=24,z=minp.z+79}
 local volume=112*55*112;local data=filled(volume,cids['default:stone'])
 local function index(x,y,z)return (z-(minp.z-16))*112*55+(y+14)*112+x-(minp.x-16)+1 end
 for i,name in ipairs(names)do for y=2,24 do data[index(p[1]+i-2,y,p[2])]=cids[name] end end
 local vm,_,observer=dofile(repo..'/tools/wp40/simple_map_r5_vm.lua').new({minp=minp,maxp=maxp,
  data=data,param2=filled(volume,0),light=filled(volume,0),heightmap=hm,
  content_contract=contract.r5,water_level=1,ignore_cid=65535,verify_inactive_tail=false})
 local plan=planner:plan_slice(minp,maxp)
 local result=adapter:apply(vm,minp,maxp,plan,plan.generation,'offline_fixture')
 local snapshot=observer.snapshot()
 for i,name in ipairs(names)do
  local x=p[1]+i-2;local _,_,_,_,_,height=source.column_values_at(x,p[2])
  assert(height<=5,'reported beach needle survived')
  for y=math.max(2,height+1),24 do assert(snapshot.data[index(x,y,p[2])]==0,
   'actual writer preserved '..name..' at '..x..','..y..','..p[2])end
  print('beach_writer',x,p[2],name,height,'cleared_to_24',result)
 end
end
print('PASS actual planner+adapter: two23-layer owner slices, six stone/soil/ore columns')
