-- Final compact interpreter parity runner. Each lane owns an isolated environment.
local repo = arg[1] or "."
local receipts = {}
local function run(path)
 local env = {}
 for key, value in pairs(_G) do env[key] = value end
 -- Fixtures may install engine helpers on standard library tables.
 for _, name in ipairs({"table", "string", "math", "os", "io"}) do
  env[name] = {}
  for key, value in pairs(_G[name]) do env[name][key] = value end
 end
 env._G = env
 env.arg = {[1] = repo}
 env.print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
  receipts[#receipts + 1] = table.concat(parts, "\t")
 end
 env.loadfile = function(file)
  local fn, err = loadfile(file)
  if fn then setfenv(fn, env) end
  return fn, err
 end
 env.dofile = function(file) return assert(env.loadfile(file))() end
 local result = env.dofile(repo .. "/" .. path)
 if type(result) == "function" then result = result(repo) end
 if result ~= nil then receipts[#receipts + 1] = tostring(result) end
end
run("tools/r20/quests_micro.lua")
run("tools/r20_ux/micro.lua")
run("tools/r13_enchants/final_micro.lua")
run("tools/r20/combat_micro.lua")
run("tools/r20_input/friendly_micro.lua")
run("tools/r20_input/controls_micro.lua")
run("tools/r20_input/transactions_micro.lua")
for _, line in ipairs(receipts) do print(line) end
