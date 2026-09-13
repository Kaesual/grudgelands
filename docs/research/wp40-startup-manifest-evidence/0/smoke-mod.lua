core.register_on_mods_loaded(function()
 core.after(0, function()
  core.log("action", "STARTUP_SMOKE authority_loaded seed=" .. core.get_mapgen_setting("seed"))
  core.emerge_area({x=-1800,y=48,z=-2550}, {x=-1800,y=48,z=-2550}, function(pos, action, remaining)
   assert(action == core.EMERGE_GENERATED or action == core.EMERGE_FROM_MEMORY, "unexpected fresh-world emerge result: " .. tostring(action))
   if remaining == 0 then
    core.log("action", "STARTUP_SMOKE PASS generated")
    core.request_shutdown("startup smoke complete", false, 0)
   end
  end)
 end)
end)
