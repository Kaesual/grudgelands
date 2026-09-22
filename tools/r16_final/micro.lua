-- One bounded final process per interpreter, isolated per-fixture globals.
local repo = arg[1] or "."
local fixtures = {
 "r16_mounts/lifecycle.lua", "r16_map/kat.lua", "r16_ui/food_hud.lua",
 "r16_progression/kat.lua", "r16_combat/control_kat.lua",
 "r16_surface/fixture.lua", "r16_surface/content_fixture.lua",
 -- Atmosphere fixture is added at its final reviewed handoff.
}

local host_loadfile, host_loadstring = loadfile, loadstring
for _,path in ipairs(fixtures) do
 local env={}
 for key,value in pairs(_G) do env[key]=value end
 for _,key in ipairs({"table","string","math","os","io","coroutine"}) do
  local isolated={};for k,v in pairs(_G[key]) do isolated[k]=v end;env[key]=isolated
 end
 env._G=env;env.arg={[0]=repo.."/tools/"..path,[1]=repo}
 env.loadfile=function(name)
  local fn,message=host_loadfile(name);if fn then setfenv(fn,env) end;return fn,message
 end
 env.loadstring=function(source,name)
  local fn,message=host_loadstring(source,name);if fn then setfenv(fn,env) end;return fn,message
 end
 env.dofile=function(name)return assert(env.loadfile(name))()end
 print("fixture="..path)
 local result=assert(env.loadfile(repo.."/tools/"..path))(repo)
 if type(result)=="function" then
  local canonical=result(repo);if canonical then io.write(canonical .. "\n") end
 end
 collectgarbage("collect")
end
print("round16-final-micro: PASS fixtures="..#fixtures)
