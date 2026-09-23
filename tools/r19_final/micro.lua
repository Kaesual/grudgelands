-- One bounded final process per interpreter, isolated per-fixture globals.
local repo = arg[1] or "."
local fixtures = {}
for line in io.lines(repo .. "/tools/r19_final/fixtures.txt") do
 if line ~= "" and line:sub(1, 1) ~= "#" then
  fixtures[#fixtures + 1] = line
 end
end
assert(#fixtures > 0, "final fixture roster is empty")

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
print("round19-final-micro: PASS fixtures="..#fixtures)
