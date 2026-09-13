core.register_on_mods_loaded(function()
 core.after(0,function()
  local failed = false
  core.log("action","HYDROLOGY_SMOKE start")
  core.emerge_area({x=-1632,y=64,z=-2272},{x=-1473,y=64,z=-2113},function(pos,action,remaining)
   if action ~= core.EMERGE_GENERATED and action ~= core.EMERGE_FROM_MEMORY then
    failed = true
    core.log("action","HYDROLOGY_SMOKE failed action=" .. tostring(action))
   end
   if remaining==0 and not failed then
    core.log("action","HYDROLOGY_SMOKE PASS"); core.request_shutdown("smoke complete",false,0)
   end
  end)
 end)
end)
