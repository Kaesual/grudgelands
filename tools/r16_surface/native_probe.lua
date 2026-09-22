-- Test-only mod in an immutable disposable snapshot. No production registration.
local count=0
local emerge=core.emerge_area
core.emerge_area=function(a,b,fn)
 count=count+1
 core.log("action","[r16_surface] dispatch="..count.." lo="..core.pos_to_string(a).." hi="..core.pos_to_string(b))
 emerge(a,b,function(p,action,left)
  fn(p,action,left)
  if left==0 then core.log("action","[r16_surface] settled status="..core.serialize(grug_core.world_preparation_status())) end
 end)
 -- Request normal shutdown after one successful request, while the second is active.
 if count==2 then
  core.after(0.01,function() core.request_shutdown("bounded surface stop/resume probe",false,0) end)
 end
end
core.register_on_mods_loaded(function()
 local authority=grug_mapgen.wp40
 local src=assert(authority.preparation_source)
 for _,p in ipairs({{-3952,-3552},{0,0},{-1700,-2500},{1600,1900},{2600,-1400}}) do
  local _,_,_,_,_,ground,water=authority.planner_source.column_values_at(p[1],p[2])
  local lo,hi=src.column_bounds(p[1],p[2])
  assert(lo<=math.max(ground,(water or ground)-8) and hi>=math.max(ground,water or ground))
  local radius=src.tile_bounds({x=p[1],z=p[2]},{x=p[1]+79,z=p[2]+79})
  core.log("action",string.format("[r16_surface] column=%d,%d ground=%d water=%s low=%d high=%d reach=%d",p[1],p[2],ground,tostring(water),lo,hi,radius))
 end
 core.log("action","[r16_surface] authority="..src.identity)
end)
core.register_on_shutdown(function()
 core.log("action","[r16_surface] shutdown requests="..count)
 assert(count<=2,"shutdown queued a third native request")
end)
core.after(40,function() core.request_shutdown("surface probe bounded stop limit",false,0) end)
