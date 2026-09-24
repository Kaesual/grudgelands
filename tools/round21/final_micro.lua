-- One compact final-byte PUC 5.1 / LuaJIT pair. No terrain constructor or VM.
local repo=assert(arg[1])
local receipts={"round21-final-v1"}
local function run(path)
 local env={}
 for k,v in pairs(_G) do env[k]=v end
 for _,name in ipairs({"table","string","math","os","io"}) do
  env[name]={};for k,v in pairs(_G[name]) do env[name][k]=v end
 end
 env._G=env;env.arg={repo}
 env.print=function(...)
  local row={};for i=1,select('#',...) do row[i]=tostring(select(i,...)) end
  receipts[#receipts+1]=table.concat(row,'\t')
 end
 env.loadfile=function(file)
  local fn,err=loadfile(file);if fn then setfenv(fn,env) end;return fn,err
 end
 env.dofile=function(file) return assert(env.loadfile(file))() end
 local result=env.dofile(repo..'/'..path)
 if type(result)=='function' then result=result(repo) end
 if result~=nil then receipts[#receipts+1]=tostring(result) end
end
for _,name in ipairs({'resources_micro','nature_micro','settlement_micro',
 'settlement_seam_micro','feedback_micro'}) do
 run('tools/round21/'..name..'.lua')
end
run('tools/wp40/planner_throughput/fixture.lua')
run('tools/wp40/planner_throughput/r5_fixture.lua')
for _,row in ipairs(receipts) do print(row) end
print('R21_FINAL_MICRO_PASS')
