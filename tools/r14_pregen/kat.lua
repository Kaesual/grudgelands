-- Portable bounded scheduler fixture; default runner is LuaJIT.
local repo = arg[1] or "."
local plan = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
local function check(value, message) assert(value, message) end
local ids = {}
for i=1,6 do ids[i]={race_id="race"..i,anchor={x=0,y=0,z=0}} end
local geometry = {x=5,y=5,z=5}
local full = plan.new("full",geometry,ids)
check(full.total==70488,"full count")
local lo,hi=plan.unit(full,1)
check(lo.x==-3952 and lo.y==-112 and lo.z==-3552,"negative alignment")
lo,hi=plan.unit(full,full.total)
check(hi.x==3967 and hi.y==527 and hi.z==3567,"positive extent")
local rectangular=plan.new("full",{x=4,y=3,z=2},ids,
 {x_min=-33,x_max=40,y_min=-30,y_max=30,z_min=-20,z_max=20})
local rectangular_lo,rectangular_hi=plan.unit(rectangular,1)
local _, rectangular_count=plan.expected(rectangular_lo,rectangular_hi)
check(rectangular_lo.x==-96 and rectangular_lo.y==-64 and rectangular_lo.z==-48 and rectangular_count==24,"noncubic grid")
local starts = plan.new("starts",geometry,ids)
check(starts.total==18,"deduplicated starts")
local backing, callbacks, pending, micros, dispatches = {}, {}, nil, 0, 0
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
	api.get_us_time=function() micros=micros+1000000;return micros end
	api.register_on_mods_loaded=function(fn) callbacks.init=fn end
	api.register_on_shutdown=function(fn) callbacks.stop=fn end
	api.register_globalstep=function(fn) callbacks.step=fn end
	api.EMERGE_GENERATED=4;api.EMERGE_FROM_MEMORY=2;api.EMERGE_FROM_DISK=3
	api.EMERGE_CANCELLED=0;api.EMERGE_ERRORED=1
	api.emerge_area=function(a,b,fn)
		check(not pending,"one inflight")
		dispatches=dispatches+1;pending={lo=a,hi=b,fn=fn}
	end
	local game={start_identities=function() return ids end}
	local env=setmetatable({core=api,grug_core=game},{__index=_G})
	local loader=assert(loadfile(repo .. "/mods/CORE/grug_core/starts_preload.lua"))
	setfenv(loader,env);loader();callbacks.init()
	return game
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
	for i,p in ipairs(positions) do
		if kind=="duplicate" then p=positions[1] end
		request.fn(p,kind=="cancel" and 0 or kind=="memory" and 2 or kind=="disk" and 3 or 4,#positions-i)
	end
end
local game=boot("starts")
check(not game.world_preparation_status().ready,"initial gate")
callbacks.step(0.2);check(dispatches==1,"first request")
settle("duplicate")
check(game.world_preparation_status().completed==0,"duplicates cannot advance")
callbacks.step(5);settle("cancel")
check(game.world_preparation_status().completed==0,"cancel cannot advance")
callbacks.step(5);settle("duplicate")
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
game=boot("full");callbacks.step(0.2);settle("success")
check(game.world_preparation_status().total==70488,"full single plan")
check(game.starts_ready()==0,"full does not prematurely release starts")
print("r14-pregen: full=70488 starts-dedup=18 cursor-resume=ok duplicates=ok cancel=ok retry=ok mode=immutable")
