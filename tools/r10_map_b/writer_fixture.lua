-- Actual R6 private transaction; native air/support crosses the world tail and
-- its opcode/ref windows before the real final VM setters and run encoding.
return function(repo)
 local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
 local common=dofile(repo.."/tools/wp40/r6/common.lua")
 local sha=common.new_sha256()
 local content_set,api,projection=dofile(repo.."/tools/r10_map_b/content_fixture.lua")(repo)
 local contract=content_set.production
 local catalog=dofile(dir.."/world_content_catalog.lua")
 local hash=dofile(dir.."/r6_hash.lua")(sha)
 local function ref(name)
  for i,n in ipairs(contract.content_names) do if n==name then return i end end
  error("missing material "..name)
 end
 local surface={id="grug_meadows",top="default:dirt_with_grass",filler="default:dirt",
  shore="default:sand",bed="default:sand",dust="-",filler_depth=2,
  top_ref=ref("default:dirt_with_grass"),filler_ref=ref("default:dirt"),
  shore_ref=ref("default:sand"),bed_ref=ref("default:sand"),dust_ref=0}
 local content={content_contract=function() return contract end,surfaces=function() return {surface} end,
  new_surface_selector=function() return function() return surface end end,
  resources=function() return {} end,cultural=function() return {} end,decorations=function() return {} end,
  decoration_cover=function() return 1 end,content_ref=ref,wp43_projection=function() return projection end}
 local functional,foundation,protected=nil,false,false
 local source_query={column_values_at=function()
  return "land",1,"elandor_dawnmere_fields","grug_meadows","human",30,
   nil,nil,nil,functional,nil,nil,nil,nil,nil,nil,nil,nil,nil,foundation
 end,surface_cave_run_at=function() end,surface_cave_candidate_at_cell=function() end,
 surface_cave_cell_at=function() return 0,0 end,coast_profile_at=function() end,
 coast_material_at=function() end,primary_relief_at=function() end,landmark_excluded_at=function() return false end}
 local horizontal={static_exclusion_values_at=function() if protected then return 1,"guard" end end,
  housing_mask_id_at=function() end}
 local source={claim_exclusions={{id="guard",recipe_id="exclude_fixed_v1"}},routes={},hard_protection={},
  anchors={{id="remote",position={x=10000,z=10000}}},apex_sockets={},
  hydrology_profiles={},hydrology={},hydrology_interfaces={}}
 for i=1,24 do source.apex_sockets[i]={id="apex"..i,anchor_id="remote",offset={x=i,z=0}} end
 local allocator={new_array=function() return {} end,new_map=function() return {} end,
  seal_construction=function() end,enter_hotpath=function() end,leave_hotpath=function() end,
  metrics=function() return {hotpath_table_allocations=0,construction_sealed=true} end}
 function allocator.grow(_,values,_,old,new) for i=old+1,new do values[i]=0 end end
 function allocator.map_put(_,values,_,key,value) values[key]=value end
 local air=api.get_content_id("air")
 local function filled(n,v) local a={};for i=1,n do a[i]=v end;return a end
 local rows={}
 for _,case in ipairs({{"cave_cap",-200,"default:stone",5},{"ember_moss",-800,"grug_materials:emberrock",6}}) do
  local y=case[2]
  local minp,maxp={x=-32,y=y-4,z=-32},{x=47,y=y+3,z=47}
  local columns,starts,runs={}, {},{}
  for column=1,6400 do
   local cb,rb=(column-1)*12,(column-1)*9
   for field=1,12 do columns[cb+field]=0 end
   columns[cb+5],columns[cb+7],columns[cb+8]=30,2,surface.top_ref
   starts[column]=column
   runs[rb+1],runs[rb+2],runs[rb+3],runs[rb+4]=minp.y,maxp.y,11,27
   for field=5,9 do runs[rb+field]=0 end
  end
  starts[6401]=6401
  local identity={value={}}
  local plan={schema="grug_wp40_r6_refinement_plan_v1",construction_identity=identity.value,
   generation=1,valid=true,min_x=minp.x,min_y=minp.y,min_z=minp.z,max_x=maxp.x,max_y=maxp.y,max_z=maxp.z,
   r5_plan={column_start=starts,run_values=runs},r5_generation=1,column_values=columns,column_count=6400,
   candidate_cell_values={},candidate_cell_count=0,candidate_values={},candidate_count=0,stable_refs={"world"}}
  local world=dofile(dir.."/world_content.lua")(catalog,content_set.p9g,
   dofile(dir.."/habitat_registry.lua")).new({content=content,
   full_seed_string="4151598227737528026",zones_session={surface_mob_level_at=function() return 7 end}})
  world.bind(plan,1)
  local successor={settle=function(_,ctx)
   return {schema="grug_wp40_r7_successor_ledger_v1",p9g={},anchors={},hearthpine={},world_content=world.settle(ctx)}
  end}
  local writer,witness=dofile(dir.."/r6_settlement.lua").new({
   full_seed_string="4151598227737528026",r5_adapter={apply=function() return "native_preserved" end},
   content=content,templates={},hash=hash,horizontal=horizontal,planner_source=source_query,
   construction_identity=identity,cultural_registrations={},source=source,
   counting_allocator=allocator,successor_tail=successor,planner_stable_refs={"world"}})
  local volume=112*40*112
  local function run()
   local data=filled(volume,api.get_content_id(case[3]))
   for z=-48,63 do for x=-48,63 do
    data[(z+48)*112*40+(y-(minp.y-16))*112+x+49]=air
   end end
   local vm,_,observer=dofile(repo.."/tools/wp40/simple_map_r5_vm.lua").new({minp=minp,maxp=maxp,
    data=data,param2=filled(volume,0),light=filled(volume,0),heightmap=filled(6400,-31007),
    content_contract=contract,water_level=1,ignore_cid=contract.ignore_cid,verify_inactive_tail=false})
   writer:apply(vm,minp,maxp,plan,1,"fixture")
   local snapshot=observer.snapshot();local found={}
   for z=-32,47 do for x=-32,47 do
    local index=(z+48)*112*40+20*112+x+49
    if snapshot.data[index]==api.get_content_id("grug_mapgen:"..case[1].."_source") then
     found[#found+1]=x..","..y..","..z
     assert(snapshot.data[index-112]~=air,"source lost actual support")
    end
   end end
   assert(snapshot.calls.set_data==(#found>0 and 1 or 0) and snapshot.calls.set_param2_data==0,"private writer setter count changed: data="..snapshot.calls.set_data.." param2="..snapshot.calls.set_param2_data)
   assert(witness.last_ledger().world_content.counts[case[4]]==#found,"world ledger omitted writes")
   return found
  end
  local found=run();assert(#found>0,case[1].." actual writer emitted nothing")
  protected=true;assert(#run()==0,"protected cave plant");protected=false
  functional="route";assert(#run()==0,"functional cave plant");functional=nil
  foundation=true;assert(#run()==0,"foundation cave plant");foundation=false
  local replay=run();assert(table.concat(found,";")==table.concat(replay,";"),"writer replay changed")
  rows[#rows+1]=case[1].."\t"..#found.."\t"..table.concat(found,";")
 end
 return "world_writer\tPASS\n"..table.concat(rows,"\n").."\n"
end
