return function(repo)
-- Portable bounded scheduler fixture; default runner is LuaJIT.

local plan = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
local function check(value, message) assert(value, message) end
local ids = {}
for i=1,6 do ids[i]={race_id="race"..i,anchor={x=0,y=0,z=0}} end
local geometry = {x=5,y=5,z=5}
local full = plan.new("full",geometry,ids)
check(full.total==8811,"horizontal tile count")
local function synthetic(height)
 return {identity="fixture-v1",tile_bounds=function() return 1,math.huge,-math.huge end,
 column_bounds=function(x,z) local h=height(x,z);return h-1,h+3 end}
end
local source=synthetic(function() return 20 end)
local function resolve(p,src)
 local scan=plan.begin(p,src)
 local ticks=0
 repeat ticks=ticks+1 until plan.scan(p,scan,src,512)
 return ticks
end
check(resolve(full,source)>1,"bounded incremental scan")
local lo,hi=plan.unit(full,1)
check(lo.x==-3952 and lo.y==-32 and lo.z==-3552,"negative alignment")
check(hi.y==47,"flat local envelope")
check(plan.complete(full) and full.cursor==1,"completed tile")
full.cursor=full.total-1;resolve(full,source);lo,hi=plan.unit(full,full.total)
check(hi.x==3967 and hi.z==3567,"positive extent")
local peak=plan.new("full",geometry,ids)
resolve(peak,synthetic(function(x,z) return x==-3911 and z==-3521 and 210 or 20 end))
check(peak.selection.y_max==208 and peak.selection.y_min==-32,"single column peak")
local cliff=plan.new("full",geometry,ids)
resolve(cliff,synthetic(function(x) return x==-3953 and -60 or 180 end))
check(cliff.selection.y_min==-112 and cliff.selection.y_max==128,"outside boundary cliff")
local rectangular=plan.new("full",{x=4,y=3,z=2},ids)
resolve(rectangular,source)
local rectangular_lo,rectangular_hi=plan.unit(rectangular,1)
local _, rectangular_count=plan.expected(rectangular_lo,rectangular_hi)
check(rectangular_count==24,"noncubic grid")
-- Select the tile intersecting the shared start, preserving every readiness Y.
local startplan=plan.new("full",geometry,ids)
local nx=(startplan.bounds.max.x-startplan.bounds.min.x)/80+1
startplan.cursor=math.floor((0-startplan.bounds.min.z)/80)*nx+math.floor((0-startplan.bounds.min.x)/80)
resolve(startplan,source)
check(startplan.selection.y_min<=-32 and startplan.selection.y_max>=48,"full start readiness")
-- Selection batching cannot change coverage, including visible coastal water,
-- a one-column peak and start envelopes crossing tile edges.
for _, height in ipairs({function() return 20 end,
 function(x,z) return x==-3911 and z==-3521 and 210 or 20 end,
 function(x) return x==-3953 and -60 or 180 end,
 function(x) return x%3==0 and -70 or 2 end}) do
 local a,b=plan.new("full",geometry,ids),plan.new("full",geometry,ids)
 local src=synthetic(height)
 resolve(a,src)
 local scan=plan.begin(b,src)
 while not plan.scan(b,scan,src,16) do end
 for _,field in ipairs({"x","z","y_min","y_max","index","inner"}) do
  check(a.selection[field]==b.selection[field],"batch-independent "..field)
 end
end
local starts = plan.new("starts",geometry,ids)
check(starts.total==18,"deduplicated starts")
local backing, callbacks, requests, micros, dispatches = {}, {}, {}, 0, 0
local columns, notifications, in_callback = 0, 0, false
local serial, serials = 0, {}
local function clone(value)
 if type(value)~="table" then return value end
 local c={} for k,v in pairs(value) do c[k]=clone(v) end return c
end
local function saved()
 return clone(serials[backing.world_preparation])
end
local function seed(p)
 serial=serial+1;serials[tostring(serial)]=clone(p)
 backing={world_preparation=tostring(serial)}
end
local function boot(mode)
 callbacks={};requests={}
 local api={}
 api.get_modpath=function() return repo .. "/mods/CORE/grug_core" end
 api.get_mod_storage=function() return {
  get_string=function(_,k) return backing[k] or "" end,
  set_string=function(_,k,v) backing[k]=v end} end
 api.serialize=function(v) serial=serial+1;serials[tostring(serial)]=clone(v);return tostring(serial) end
 api.deserialize=function(v) return clone(serials[v]) end
 api.settings={get_bool=function() return mode=="full" end}
 api.log=function() end
 api.get_mapgen_chunksize=function() return geometry end
 api.get_mapgen_setting=function() return "v7" end
 api.get_us_time=function() return micros end
 api.register_on_mods_loaded=function(fn) callbacks.init=fn end
 api.register_on_shutdown=function(fn) callbacks.stop=fn end
 api.register_globalstep=function(fn) callbacks.step=fn end
 api.EMERGE_GENERATED=4;api.EMERGE_FROM_MEMORY=2;api.EMERGE_FROM_DISK=3
 api.EMERGE_CANCELLED=0;api.EMERGE_ERRORED=1
 api.emerge_area=function(a,b,fn)
  check(#requests<2,"bounded two native requests")
  check(not in_callback,"no callback dispatch")
  dispatches=dispatches+1;requests[#requests+1]={lo=clone(a),hi=clone(b),fn=fn}
 end
 local game={start_identities=function() return ids end}
 local env=setmetatable({core=api,grug_core=game,
  grug_mapgen={wp40={production_enabled=true,preparation_source=source}}},{__index=_G})
 local loader=assert(loadfile(repo .. "/mods/CORE/grug_core/starts_preload.lua"))
 local native_emerge=api.emerge_area
 setfenv(loader,env);loader();callbacks.init()
 check(api.emerge_area==native_emerge,"native emerge API untouched")
 game.register_on_preparation_progress(function() notifications=notifications+1 end)
 return game,api
end
local function step(dt)
 micros=micros+(dt or 0.09)*1000000
 callbacks.step(dt or 0.09)
end
local function settle(which,kind)
 local request=table.remove(requests,which or 1)
 check(request,"request exists")
 local positions={}
 for z=request.lo.z/16,(request.hi.z+1)/16-1 do
  for y=request.lo.y/16,(request.hi.y+1)/16-1 do
   for x=request.lo.x/16,(request.hi.x+1)/16-1 do
    positions[#positions+1]={x=x,y=y,z=z}
   end
  end
 end
 in_callback=true
 for i,p in ipairs(positions) do
  if kind=="duplicate" then p=positions[1] end
  if kind=="missing" and i==#positions then p={x=99999,y=0,z=0} end
  request.fn(p,kind=="cancel" and 0 or kind=="error" and 1 or kind=="memory" and 2 or kind=="disk" and 3 or 4,#positions-i)
 end
 in_callback=false
 return request
end
local function fill(n)
 for _=1,200 do if #requests>=n then return end;step() end
 error("queue did not fill")
end
source={identity="unused-starts-source",tile_bounds=function() error("starts must not select") end,
 column_bounds=function() error("starts must not scan") end}
local game=boot("starts")
check(not game.world_preparation_status().ready,"initial gate")
callbacks.step(0.001)
check(#requests==2,"no work interval throttling; starts pipeline fills")
settle(2,"disk")
check(saved().cursor==0,"out-of-order success cannot skip head")
step();check(#requests==1,"successful later row retains bounded slot")
settle(1,"duplicate")
check(saved().cursor==0,"duplicates cannot advance")
step(4.99);check(#requests==0,"five-second retry delay")
step(0.01);check(#requests==1,"head retries")
settle(1,"cancel");step(5);settle(1,"error")
check(game.world_preparation_status().failed,"three attempts stop")
step(100);check(#requests==0,"failure inert")
check(game.request_starts_preload(),"manual retry accepted")
step();settle(1,"memory")
check(saved().cursor==2,"successful later row commits after head retry")
check(#requests==0,"callbacks never refill")
check(game.world_preparation_status().eta_seconds==nil,"initial ETA estimating")
step();settle(1);settle(1)
check(saved().cursor==4 and game.world_preparation_status().eta_seconds~=nil,"wall-clock ETA samples")
game=boot("full")
check(game.world_preparation_status().mode=="starts" and saved().cursor==4,"mode and prefix resume")
while not game.world_preparation_status().ready do
 fill(1);settle(1, saved().cursor%2==0 and "memory" or "disk")
end
check(#requests==0 and saved().cursor==18,"all starts complete")
check(game.start_ready("race1") and not game.start_ready("unknown"),"race gate")
local before=dispatches
game=boot("full");step();check(dispatches==before,"completed starts restart inert")
-- Full mode scans ahead while one request is pending, with one shared per-step
-- count ceiling. It does not scan beyond the two-request queue capacity.
backing={};columns=0;notifications=0
source=synthetic(function() return 20 end)
local column_bounds=source.column_bounds
source.column_bounds=function(x,z) columns=columns+1;micros=micros+1;return column_bounds(x,z) end
game=boot("full");callbacks.step(0.001)
check(#requests==1 and columns==8180,"first scan plus bounded pending lookahead")
check(notifications==0,"UI cadence independent")
callbacks.step(0.001)
check(#requests==2 and columns==2*82*82,"second tile prepared during pending emerge")
check(saved().cursor==0 and saved().selection.index==1,"only current selection durable")
local second_lo=clone(requests[2].lo)
for _=1,20 do callbacks.step(0.02) end
check(columns==2*82*82 and #requests==2,"full queue performs no extra scan")
check(notifications==1,"notification coalescing")
settle(2)
check(saved().cursor==0,"later tile remains speculative")
callbacks.stop();settle(1);step()
check(saved().cursor==2 and #requests==0,"late successful callbacks persist contiguous prefix")
-- A gap at shutdown loses only speculative success, which loads/replays on restart.
backing={};game=boot("full");fill(2)
settle(2);callbacks.stop();settle(1,"cancel");step(10)
check(saved().cursor==0 and #requests==0,"cancelled head preserves prefix")
local columns_before=columns
game=boot("full");fill(2)
check(requests[2].lo.x==second_lo.x and requests[2].lo.z==second_lo.z,"lookahead replay coordinates")
check(columns-columns_before==82*82,"durable head reused; future selection recomputed")
settle(1);settle(1)
check(saved().cursor==2,"replayed prefix commits")
-- Slow source yields cooperatively even when the queue is empty. A shutdown
-- during an unresolved scan persists no speculative progress.
backing={};columns=0
source=synthetic(function() return 20 end);column_bounds=source.column_bounds
source.column_bounds=function(x,z) columns=columns+1;micros=micros+500;return column_bounds(x,z) end
game=boot("full");callbacks.step(0.001)
check(columns==208 and #requests==0,"100 ms budget checked after 16-column batch")
callbacks.stop();step();check(columns==208,"partial scan stop")
game=boot("starts");callbacks.step(0.001)
check(columns==416 and #requests==0,"partial selection restart recomputes")
-- Coarse timer still obeys the per-step count ceiling.
backing={};columns=0
source={identity="wide-fixture",tile_bounds=function() return 20,0,0 end,
 column_bounds=function() columns=columns+1;return 0,0 end}
game=boot("full");step();check(columns==8192 and #requests==0,"coarse-clock column cap")
step();check(columns==16384 and #requests==1,"count cap shared across tile boundary")
callbacks.stop();settle(1,"cancel");step(10)
check(#requests==0 and not game.world_preparation_status().ready,"shutdown cancellation inert")
-- Partial inner-tile cursor and selection are durable independently of the
-- speculative second request; a failing later request cannot skip its gap.
backing={}
source=synthetic(function(x) return x==-3953 and -60 or 180 end)
game=boot("full");fill(2)
local first_y=requests[1].lo.y
settle(2,"missing");settle(1)
check(saved().cursor==0 and saved().selection.inner==1,"partial tile cursor durable")
check(game.starts_ready()==0,"partial full preparation does not release starts")
local raw_column_bounds=source.column_bounds
source.column_bounds=function() error("persisted selected tile must not rescan") end
game=boot("starts");fill(2)
check(requests[1].lo.y==first_y+80,"resume exact inner chunk")
settle(1,"cancel");step(5)
check(requests[2].lo.y==first_y+80,"retry preserves inner coordinates")
settle(1,"memory");settle(1)
check(saved().cursor==0 and saved().selection.inner==3,"ordered inner gap drains")
source.column_bounds=raw_column_bounds
while game.world_preparation_status().completed==0 do fill(1);settle(1) end
check(saved().cursor==1,"all Y chunks required")
source.identity="changed-authority"
check(not pcall(function() boot("full") end),"authority mismatch refused")
-- Current-format last-tile seed proves all post-completion preparation work is
-- absent and an ordinary external deep-cave request keeps its native route.
source=synthetic(function() return 20 end)
local final_plan=plan.new("full",geometry,ids)
final_plan.cursor=final_plan.total-1;final_plan.authority=source.identity;seed(final_plan)
local api
game,api=boot("full");fill(1);settle(1)
check(game.world_preparation_status().ready and #requests==0,"last tile readiness")
source.tile_bounds=function() error("ready world must not select") end
source.column_bounds=function() error("ready world must not scan") end
local function idle_and_cave()
 local previous=dispatches
 for _=1,100 do step() end
 check(dispatches==previous and #requests==0,"ready world idle")
 local calls=0
 api.emerge_area({x=0,y=-4096,z=0},{x=15,y=-4081,z=15},function(_,action,remaining)
  check(action==4 and remaining==0,"external callback unchanged");calls=calls+1
 end)
 check(requests[1].lo.y==-4096 and requests[1].hi.y==-4081,"external cave coordinates unchanged")
 step();settle(1)
 for _=1,100 do step() end
 check(calls==1 and dispatches==previous+1 and #requests==0,"cave request cannot restart preparation")
 check(saved().cursor==8811 and game.world_preparation_status().ready,"ready prefix unchanged")
end
idle_and_cave();game,api=boot("full");idle_and_cave()
return "r19-preparation-fullspeed: coverage pipeline=2 ordered-prefix retry stop replay inner-resume budget mode authority ready-idle external-cave=ok\n"
end
