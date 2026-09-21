-- One bounded final process per interpreter; isolated fixture globals.
local repo = arg[1] or "."
local fixtures = {
 "r14_quests/core_kat.lua", "r14_quests/participation_kat.lua",
 "r14_quests/visibility_kat.lua", "r14_parties/core_kat.lua",
 "r14_pregen/kat.lua", "r14_selection/kat.lua",
 "r14_fixes/flight_policy_kat.lua", "r14_fixes/profession_isolation_kat.lua",
 "r14_fishing/kat.lua", "r14_ui/ui_kat.lua",
 "r14_map/kat.lua", "r14_map/page_kat.lua", "r14_poi/poi_micro_kat.lua",
}
local host_loadfile, host_loadstring = loadfile, loadstring
for _, path in ipairs(fixtures) do
 local env = {}
 for key, value in pairs(_G) do env[key] = value end
 -- Helpers installed by a fixture must never leak to the next fixture.
 for _, key in ipairs({"table", "string", "math", "os", "io", "coroutine"}) do
  local isolated = {}; for k,v in pairs(_G[key]) do isolated[k] = v end
  env[key] = isolated
 end
 env._G = env
 env.arg = {[0] = repo .. "/tools/" .. path, [1] = repo}
 env.loadfile = function(name)
  local fn, message = host_loadfile(name)
  if fn then setfenv(fn, env) end
  return fn, message
 end
 env.loadstring = function(source, name)
  local fn, message = host_loadstring(source, name)
  if fn then setfenv(fn, env) end
  return fn, message
 end
 env.dofile = function(name) return assert(env.loadfile(name))() end
 print("fixture=" .. path)
 assert(env.loadfile(repo .. "/tools/" .. path))(repo)
 collectgarbage("collect")
end
print("round14-final-micro: PASS fixtures=" .. #fixtures)
