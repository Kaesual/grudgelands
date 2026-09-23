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
local backing, callbacks, pending, micros, dispatches = {}, {}, nil, 0, 0
local columns, notifications, in_callback = 0, 0, false
local serial = 0
local serials = {}
local function clone(value)
	if type(value)~="table" then return value end
	local c={} for k,v in pairs(value) do c[k]=clone(v) end return c
end
local function boot(mode)
	callbacks={}; pending=nil
	local api = {}
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
		check(not pending,"one inflight")
		check(not in_callback,"no callback reentry")
		dispatches=dispatches+1;pending={lo=a,hi=b,fn=fn}
	end
	local game={start_identities=function() return ids end}
	local env=setmetatable({core=api,grug_core=game,
 grug_mapgen={wp40={production_enabled=true,preparation_source=source}}},{__index=_G})
	local loader=assert(loadfile(repo .. "/mods/CORE/grug_core/starts_preload.lua"))
	local native_emerge=api.emerge_area
	setfenv(loader,env);loader();callbacks.init()
	check(api.emerge_area==native_emerge,"preparation never replaces native emergence")
	game.register_on_preparation_progress(function() notifications=notifications+1 end)
	return game, api
end
local function settle(kind)
	local request=pending;pending=nil
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
		request.fn(p,kind=="cancel" and 0 or kind=="error" and 1 or kind=="memory" and 2 or kind=="disk" and 3 or 4,#positions-i)
	end
	in_callback=false
end
source={identity="unused-starts-source",tile_bounds=function() error("starts must not select surfaces") end,
 column_bounds=function() error("starts must not scan columns") end}
local game=boot("starts")
check(not game.world_preparation_status().ready,"initial gate")
callbacks.step(0.2);check(dispatches==1,"first request")
settle("duplicate")
check(game.world_preparation_status().completed==0,"duplicates cannot advance")
callbacks.step(5);settle("cancel")
check(game.world_preparation_status().completed==0,"cancel cannot advance")
callbacks.step(5);settle("error")
check(game.world_preparation_status().failed,"bounded retry")
callbacks.step(100);check(not pending,"stopped failure")
check(game.request_starts_preload(),"explicit retry accepted")
check(not game.world_preparation_status().failed,"explicit retry clears failed")
game=boot("full")
check(game.world_preparation_status().mode=="starts","mode immutable")
callbacks.step(0.2);settle("success")
check(game.world_preparation_status().completed==1,"successful prefix")
check(not pending,"callback never dispatches")
callbacks.stop();callbacks.step(1);check(not pending,"late shutdown guard")
game=boot("starts")
check(game.world_preparation_status().completed==1,"cursor resumes")
for i=2,18 do
 callbacks.step(0.2);settle(i%2==0 and "memory" or "disk")
 if i==2 then check(game.world_preparation_status().eta_seconds==nil,"initial ETA estimating") end
 if i==4 then check(game.world_preparation_status().eta_seconds~=nil,"timed ETA") end
end
check(game.world_preparation_status().ready,"complete gate")
check(game.start_ready("race1") and not game.start_ready("unknown"),"race gate")
local before=dispatches
game=boot("full");callbacks.step(0.2)
check(game.world_preparation_status().ready and dispatches==before,"complete restart skips")
backing={}
source=synthetic(function() return 20 end)
local column_bounds=source.column_bounds
source.column_bounds=function(x,z)
 columns=columns+1;micros=micros+1
 return column_bounds(x,z)
end
game=boot("full")
notifications=0
local ticks=0
repeat ticks=ticks+1;callbacks.step(0.02) until pending or ticks==200
check(pending,"bounded selection dispatch")
check(columns==82*82,"every surface column visited exactly once")
check(ticks==1,"full preparation budget completes inexpensive selection in one step")
check(notifications==0,"UI cadence independent from work cadence")
for i=1,20 do callbacks.step(0.02) end
check(pending and columns==82*82,"pending emerge prevents more scan or dispatch")
check(notifications==1,"coalesced initial UI update")
callbacks.stop();settle("success");callbacks.step(1)
check(not pending,"shutdown settling cannot dispatch")
check(game.world_preparation_status().completed==1,"shutdown success persisted")
-- A costly source yields at the full-preparation time budget. Stopping a partial
-- selection persists no selected interval; restart deterministically resamples.
backing={};columns=0
source=synthetic(function() return 20 end)
column_bounds=source.column_bounds
source.column_bounds=function(x,z)
 columns=columns+1;micros=micros+500
 return column_bounds(x,z)
end
game=boot("full");callbacks.step(0.02)
check(columns==80 and not pending,"slow source yields at forty milliseconds")
callbacks.stop();callbacks.step(1)
check(columns==80,"prompt stop during partial selection")
game=boot("starts");callbacks.step(0.02)
check(columns==160 and not pending,"partial selection restarts safely")
-- Flat clock still has a strict count ceiling, even with larger source reach.
backing={};columns=0
source={identity="wide-fixture",tile_bounds=function() return 20,0,0 end,
 column_bounds=function() columns=columns+1;return 0,0 end}
game=boot("full");callbacks.step(0.02)
check(columns==8192 and not pending,"coarse clock hard cap")
callbacks.step(0.02)
check(columns==120*120 and pending,"coarse clock coverage completes")
callbacks.stop();settle("cancel");callbacks.step(10)
check(not pending and not game.world_preparation_status().ready,"shutdown cancellation stays incomplete")
backing={}
source=synthetic(function(x) return x==-3953 and -60 or 180 end)
game=boot("full")
local function dispatch_next()
 for i=1,100 do callbacks.step(0.2);if pending then return end end
 error("no dispatch")
end
dispatch_next();local first_y=pending.lo.y;settle("success")
check(game.world_preparation_status().completed==0,"partial tile not complete")
check(game.world_preparation_status().total==8811,"full single plan")
check(game.starts_ready()==0,"full does not prematurely release starts")
-- Restart preserves selected interval and inner progress without resampling.
source.column_bounds=function() error("resolved tile must not resample") end
game=boot("starts");dispatch_next()
check(pending.lo.y==first_y+80,"inner chunk persisted")
settle("cancel");callbacks.step(5)
check(pending.lo.y==first_y+80,"failed inner chunk retries unchanged")
settle("success")
while game.world_preparation_status().completed==0 do dispatch_next();settle("success") end
check(game.world_preparation_status().completed==1,"tile finishes after every Y chunk")
source.identity="changed-authority"
check(not pcall(function() boot("full") end),"authority mismatch refused")
-- A completed full world stays inert, including after restart. Seed only the
-- final tile of a current-format plan rather than generating the whole world.
source=synthetic(function() return 20 end)
local final_plan=plan.new("full",geometry,ids)
final_plan.cursor=final_plan.total-1
final_plan.authority=source.identity
serial=serial+1;serials[tostring(serial)]=clone(final_plan)
backing={world_preparation=tostring(serial)}
local api
game,api=boot("full")
dispatch_next();settle("success")
check(game.world_preparation_status().ready,"last full tile releases gate")
source.tile_bounds=function() error("ready full world must not select surfaces") end
source.column_bounds=function() error("ready full world must not scan columns") end
local function check_ready_idle_and_cave()
 local dispatch_before=dispatches
 for i=1,100 do callbacks.step(0.09) end
 check(dispatches==dispatch_before and not pending,"ready full world remains idle")
 local cave_callbacks=0
 api.emerge_area({x=0,y=-4096,z=0},{x=15,y=-4081,z=15},function(_,action,remaining)
  check(action==api.EMERGE_GENERATED and remaining==0,"external cave callback unchanged")
  cave_callbacks=cave_callbacks+1
 end)
 check(pending.lo.y==-4096 and pending.hi.y==-4081,"external cave coordinates unchanged")
 callbacks.step(0.09)
 check(dispatches==dispatch_before+1,"external cave request is sole dispatch")
 settle("success")
 for i=1,100 do callbacks.step(0.09) end
 check(cave_callbacks==1 and dispatches==dispatch_before+1 and not pending,
  "external cave emergence cannot restart preparation")
 check(game.world_preparation_status().ready and
  game.world_preparation_status().completed==8811,"cave emergence preserves ready prefix")
end
check_ready_idle_and_cave()
game,api=boot("full")
check_ready_idle_and_cave()
return "r18-preparation: tiles=8811 coverage budget cadence pending stop resume retry mode-lock authority ready-idle external-cave=ok\n"
end
