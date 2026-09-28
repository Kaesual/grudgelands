return function(repo)
-- Portable full-column preparation fixture (Round 23, WP48); LuaJIT default.
-- Restores and extends the retired r19 scheduler fixture: plan geometry and
-- the full-column extent against an independent block-reach reference, the
-- scanner window and its memory bound, the two-request pipeline, ordered
-- prefix, retry, stop/resume, readiness, and the emerge-side air-chunk
-- classifier.
local plan = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
local function check(value, message) assert(value, message) end
local floor = math.floor
local ids = {}
for i=1,6 do ids[i]={race_id="race"..i,anchor={x=0,y=0,z=0}} end
local geometry = {x=5,y=5,z=5}
local OPTIONS = {generate_distance=10, flight_ceiling=600}
local SMALL = {x_min=-400,x_max=400,z_min=-400,z_max=400}
local function options(extra)
 local o={generate_distance=OPTIONS.generate_distance,flight_ceiling=OPTIONS.flight_ceiling}
 for k,v in pairs(extra or {}) do o[k]=v end
 return o
end

-- Geometry: whole-world tile count, generate reach, neighbourhood window.
local full = plan.new("full",geometry,ids,options())
check(full.total==8811 and full.counts.x==99 and full.counts.z==89,"horizontal tile count")
check(full.reach==176 and full.window.x==3 and full.window.z==3,"reach 176, window 3 at distance 10")
check(full.air_top==608,"flight ceiling plus headroom")
local near = plan.new("full",geometry,ids,options({generate_distance=5}))
check(near.reach==96 and near.window.x==2,"reach and window follow the distance")
local rect = plan.new("full",{x=4,y=3,z=2},ids,options({bounds=SMALL}))
check(rect.window.x==3 and rect.window.z==6,"window per horizontal axis")
check(not pcall(plan.new,"full",geometry,ids,{flight_ceiling=600}),"distance required")

local function synthetic(height, reach)
 return {identity="fixture-v2",tile_bounds=function() return reach or 1,math.huge,-math.huge end,
  column_bounds=function(x,z) local h=height(x,z);return h-1,h+3 end}
end
local function resolve(p,src,batch)
 local scanner=plan.scanner(p,p.cursor+1)
 local steps=0
 while not plan.select(p,scanner) do plan.scan(p,scanner,src,batch or 4096);steps=steps+1 end
 return steps,scanner
end
local function flat(h) return synthetic(function() return h end) end

-- Flat land at 20: bottom 19-176 -> chunk -192; top: flight 784 -> chunk 768.
local small=plan.new("full",geometry,ids,options({bounds=SMALL}))
check(small.total==121,"small region tiles")
small.cursor=60
check(resolve(small,flat(20))>1,"bounded incremental scan")
check(small.selection.y_min==-192 and small.selection.y_max==768,"flat column -192..847")
local lo,hi=plan.unit(small,61)
check(lo.y==-192 and hi.y==-113 and hi.x-lo.x==79,"first unit bottom-up")
-- Negative and positive alignment on the engine grid.
full.cursor=0;resolve(full,flat(20));lo=plan.unit(full,1)
check(lo.x==-3952 and lo.z==-3552,"negative alignment")
full.selection=nil;full.cursor=full.total-1;resolve(full,flat(20));lo,hi=plan.unit(full,full.total)
check(hi.x==3967 and hi.z==3567,"positive extent")

-- Neighbourhood: a narrow peak three tiles away raises the top; four do not.
-- A deep column three tiles away lowers the bottom.
local function one_column(px,pz,h,base)
 return synthetic(function(x,z) return (x==px and z==pz) and h or base end)
end
local function tile_origin(p,tx,tz) return p.bounds.min.x+tx*80,p.bounds.min.z+tz*80 end
local function select_tile(bounds_opts,src,tx,tz)
 local p=plan.new("full",geometry,ids,options(bounds_opts))
 p.cursor=tz*p.counts.x+tx
 resolve(p,src)
 return p.selection,p
end
local sel,p=select_tile({bounds=SMALL},flat(20),5,5)
local x0,z0=tile_origin(p,5,5)
sel=select_tile({bounds=SMALL},one_column(x0+3*80+7,z0-3*80+11,700,20),5,5)
check(sel.y_max==848,"peak three tiles away: 703+3+176 -> 848")
sel=select_tile({bounds=SMALL},one_column(x0+4*80+7,z0,700,20),5,5)
check(sel.y_max==768,"peak four tiles away ignored")
sel=select_tile({bounds=SMALL},one_column(x0-3*80,z0+3*80+79,-150,20),5,5)
check(sel.y_min==-352,"deep column three tiles away: -151-176 -> -352")
-- Edge tile: the window is clamped to the prepared bounds.
sel=select_tile({bounds=SMALL},flat(20),0,0)
check(sel.y_min==-192 and sel.y_max==768,"edge tile clamps its window")
-- Start readiness envelopes still apply over their tiles.
local startplan=plan.new("full",geometry,ids,options({bounds=SMALL}))
startplan.cursor=floor((0-startplan.bounds.min.z)/80)*startplan.counts.x+floor((0-startplan.bounds.min.x)/80)
resolve(startplan,flat(900))
check(startplan.selection.y_min<=-32,"start readiness bottom kept under high terrain")

-- Independent block-reach reference. For every column a player can stand in
-- (feet from low+1 to high+3) or fly over (feet up to 608), the engine may
-- generate blocks within 11 (distance + prediction) Chebyshev blocks of the
-- player's block. Every such block over the tile must be prepared.
local function block(v) return floor(v/16) end
local function hash(x,z)
 local v=(x*374761+z*668265)%1000003
 return (v*v)%1000003
end
local rough=function(x,z) return -60+hash(x,z)%240 end
local src=synthetic(rough)
for _,tile in ipairs({{0,0},{5,5},{10,3},{2,10},{10,10}}) do
 local s,pp=select_tile({bounds=SMALL},src,tile[1],tile[2])
 local tx0,tz0=tile_origin(pp,tile[1],tile[2])
 local bx0,bx1,bz0,bz1=block(tx0),block(tx0+79),block(tz0),block(tz0+79)
 local need_lo,need_hi=math.huge,-math.huge
 for z=math.max(pp.bounds.min.z,(bz0-11)*16),math.min(pp.bounds.max.z+79,(bz1+11)*16+15) do
  for x=math.max(pp.bounds.min.x,(bx0-11)*16),math.min(pp.bounds.max.x+79,(bx1+11)*16+15) do
   local low,high=src.column_bounds(x,z)
   need_lo=math.min(need_lo,(block(low+1)-11)*16)
   need_hi=math.max(need_hi,(block(math.max(high+3,608))+11)*16+15)
  end
 end
 check(s.y_min<=need_lo and s.y_max+79>=need_hi,"reference block reach covered "..tile[1]..","..tile[2])
 check(s.y_min>need_lo-80 and s.y_max<need_hi,"no chunk beyond the reference "..tile[1]..","..tile[2])
end

-- Batch size never changes a selection; the scanner keeps a bounded window.
for _,height in ipairs({function() return 20 end,rough,
 function(x) return x%3==0 and -70 or 2 end}) do
 local a=plan.new("full",geometry,ids,options({bounds=SMALL}))
 local b=plan.new("full",geometry,ids,options({bounds=SMALL}))
 local s=synthetic(height)
 local sa,sb=plan.scanner(a,1),plan.scanner(b,1)
 local most=0
 for index=1,a.total do
  while not plan.select(a,sa) do plan.scan(a,sa,s,4096) end
  while not plan.select(b,sb) do plan.scan(b,sb,s,16) end
  for _,field in ipairs({"x","z","y_min","y_max","index","inner"}) do
   check(a.selection[field]==b.selection[field],"batch-independent "..field)
  end
  local kept=0 for _ in pairs(sb.stats) do kept=kept+1 end
  most=math.max(most,kept)
  a.selection,b.selection=nil,nil;a.cursor,b.cursor=index,index
 end
 check(most<=(2*b.window.z+2)*b.counts.x,"scanner memory bounded by the window rows")
end
-- A scanner started at any later tile (restart) selects the same range.
do
 local s=synthetic(rough)
 local a=plan.new("full",geometry,ids,options({bounds=SMALL}))
 local sa=plan.scanner(a,1)
 local expect={}
 for index=1,a.total do
  while not plan.select(a,sa) do plan.scan(a,sa,s,512) end
  expect[index]=a.selection.y_min..":"..a.selection.y_max
  a.selection=nil;a.cursor=index
 end
 for _,start in ipairs({2,45,60,121}) do
  local b=plan.new("full",geometry,ids,options({bounds=SMALL}))
  b.cursor=start-1
  resolve(b,s,300)
  check(b.selection.y_min..":"..b.selection.y_max==expect[start],"restart selection "..start)
 end
end

-- The production surface envelope: the real bed of sea, lake and river water
-- is the bottom-side surface (user ruling 2026-09-28); the top side keeps the
-- water surface. Tuple slots: 6 ground, 7 water, 11 functional, 16/17 falls.
do
 local envelope=dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/preparation_source.lua")
 local function tuple(x)
  if x==0 then return nil,nil,nil,nil,nil,-60,1 end -- deep sea
  if x==1 then return nil,nil,nil,nil,nil,12,20 end -- lake, bed 8 below
  if x==2 then return nil,nil,nil,nil,nil,5,9,nil,nil,nil,nil,nil,nil,nil,nil,9,-3 end -- fall
  return nil,nil,nil,nil,nil,20 -- land
 end
 local s=envelope({column_values_at=function(x) return tuple(x) end},
  {{rotations={{min_x=-2,max_x=2,min_y=-3,max_y=10,min_z=-2,max_z=2}}}},{},{},{},
  {copy_rows=function() return {} end},"fixture",function(b) return tostring(#b) end)
 local low,high=s.column_bounds(0,0)
 check(low==-62 and high==12,"deep seabed is the bottom surface, water surface the top")
 low,high=s.column_bounds(1,0)
 check(low==10 and high==31,"lake bed")
 low=s.column_bounds(2,0)
 check(low==-5,"lower fall below its bed")
 low,high=s.column_bounds(3,0)
 check(low==18 and high==31,"land")
 -- A seabed at -60 three tiles away lowers the tile's column: -62-176 -> -272.
 local function src(bed_x)
  return {identity="seabed",tile_bounds=function() return 1,math.huge,-math.huge end,
   column_bounds=function(x,z) return s.column_bounds((x==bed_x and z==0) and 0 or 3,0) end}
 end
 local sel=select_tile({bounds=SMALL},src(-250),5,5)
 check(sel.y_min==-272 and sel.y_max==768,"seabed three tiles away deepens the column")
 sel=select_tile({bounds=SMALL},src(-330),5,5)
 check(sel.y_min==-192,"seabed four tiles away does not")
end

local starts = plan.new("starts",geometry,ids)
check(starts.total==18,"deduplicated starts")

-- Emerge-side air-chunk classifier.
do
 local air=dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/air_chunks.lua")
 local calls=0
 local bounds={tile_bounds=function(a) return 4,math.huge,(a.x==-32 and a.z==-32) and 250 or -math.huge end,
  column_bounds=function(x,z) calls=calls+1;return 0,(x==-37 and z==10) and 180 or 30 end}
 local c=air(bounds,1)
 local sentinel={} for i=1,6400 do sentinel[i]=-31007 end
 local function hm() return sentinel end
 local function u(y,x,z,f)
  x,z=x or 48,z or 48
  return c.untouched({x=x,y=y,z=z},{x=x+79,y=y+79,z=z+79},f or hm)
 end
 check(not u(-32),"below water level stays on the full path")
 check(u(48),"native air above the envelope (30 + 16)")
 local before=calls
 check(u(128) and calls==before,"memoized per owner column")
 check(not u(128,-112,-32) and u(208,-112,-32),"neighbour peak 180 inside the reach")
 check(not u(208,-32,-32) and u(288,-32,-32),"box top 250 honoured")
 check(u(128,-32,-30),"peak one column beyond the reach does not count")
 check(not u(128,-33,-30),"peak at the reach edge counts")
 local stone={} for i=1,6400 do stone[i]=-31007 end
 stone[6400]=300
 check(not u(288,48,48,function() return stone end),"any native ground keeps the full path")
 check(not u(288,48,48,function() return nil end),"missing heightmap keeps the full path")
 for i=1,70 do u(208,48+80*i,48) end
 before=calls
 check(u(208) and calls>before,"memo is bounded and recomputes")
end

-- Scheduler: pipeline, prefix, retry, stop/resume, readiness.
local backing, callbacks, requests, micros, dispatches = {}, {}, {}, 0, 0
local columns, notifications, in_callback = 0, 0, false
local serial, serials = 0, {}
local source
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
local distance_setting="10"
local function boot(mode)
 callbacks={};requests={}
 local api={}
 api.get_modpath=function() return repo .. "/mods/CORE/grug_core" end
 api.get_mod_storage=function() return {
  get_string=function(_,k) return backing[k] or "" end,
  set_string=function(_,k,v) backing[k]=v end} end
 api.serialize=function(v) serial=serial+1;serials[tostring(serial)]=clone(v);return tostring(serial) end
 api.deserialize=function(v) return clone(serials[v]) end
 api.settings={get_bool=function() return mode=="full" end,
  get=function(_,k) if k=="max_block_generate_distance" then return distance_setting end end}
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
 local game={start_identities=function() return ids end,FLIGHT_CEILING=600}
 -- The scheduler plans the small region; everything else is production code.
 local function region_dofile(path)
  local module=dofile(path)
  if path:sub(-20)=="preparation_plan.lua" then module.bounds=SMALL end
  return module
 end
 local env=setmetatable({core=api,grug_core=game,dofile=region_dofile,
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
 for i,pos in ipairs(positions) do
  if kind=="duplicate" then pos=positions[1] end
  if kind=="missing" and i==#positions then pos={x=99999,y=0,z=0} end
  request.fn(pos,kind=="cancel" and 0 or kind=="error" and 1 or kind=="memory" and 2 or kind=="disk" and 3 or 4,#positions-i)
 end
 in_callback=false
 return request
end
local function fill(n)
 for _=1,2000 do if #requests>=n then return end;step() end
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

-- Full mode: the scanner runs ahead by the window before the first request,
-- inside the shared per-step column ceiling; the persisted plan binds the
-- generate reach and the flight ceiling.
local TILE=82*82 -- one tile plus its reach-1 halo
backing={};columns=0;notifications=0
source=synthetic(function() return 20 end)
local column_bounds=source.column_bounds
source.column_bounds=function(x,z) columns=columns+1;micros=micros+1;return column_bounds(x,z) end
game=boot("full")
check(saved().reach==176 and saved().air_top==608 and saved().order=="z-x-column-v2","persisted column geometry")
local steps=0
while #requests==0 do callbacks.step(0.001);steps=steps+1;check(columns<=steps*8192,"per-step ceiling") end
-- Tile 1 needs rows 0..3 and columns 0..3 of an 11-wide region: 37 tiles,
-- the last 16-column batch may spill into tile 38. Both requests belong to
-- the resolved column.
local WINDOW=37*TILE
check(#requests==2 and columns>=WINDOW and columns<WINDOW+16,"first selection scans its window only")
local scanned=columns
check(notifications==0,"UI cadence independent")
check(requests[1].lo.y==-192 and requests[1].hi.y==-113 and requests[2].lo.y==-112,"column bottom-up")
local unit_count=(saved().selection.y_max-saved().selection.y_min)/80+1
check(unit_count==13,"thirteen chunks in a flat column")
check(saved().cursor==0 and saved().selection.index==1,"only current selection durable")
for _=1,20 do callbacks.step(0.02) end
check(columns==scanned and #requests==2,"full queue performs no extra scan")
check(notifications==1,"notification coalescing")
settle(2)
check(saved().cursor==0 and saved().selection.inner==0,"later chunk remains speculative")
callbacks.stop();settle(1);step()
check(saved().selection.inner==2 and #requests==0,"late successful callbacks persist contiguous prefix")
-- Walk to the tile boundary: the next tile's window needs one more tile.
backing={};columns=0
game=boot("full")
for _=1,13 do fill(1);settle(1) end
check(saved().cursor==1,"all thirteen Y chunks complete the tile")
fill(1)
check(columns>=38*TILE and columns<38*TILE+16,"next tile scans one more window tile")
settle(1)
-- A gap at shutdown loses only speculative success, which reloads on restart.
backing={};game=boot("full");fill(2)
local second=clone(requests[2].lo)
settle(2);callbacks.stop();settle(1,"cancel");step(10)
check(saved().cursor==0 and saved().selection.inner==0 and #requests==0,"cancelled head preserves prefix")
columns=0
game=boot("full");fill(2)
check(requests[2].lo.y==second.y and requests[2].lo.x==second.x,"replay coordinates")
check(columns==0,"durable head selection needs no rescan")
settle(1);settle(1)
check(saved().selection.inner==2,"replayed prefix commits")
-- Partial inner progress survives a restart; resumed tiles reselect exactly.
backing={}
source=synthetic(rough);column_bounds=source.column_bounds
source.column_bounds=function(x,z) columns=columns+1;return column_bounds(x,z) end
game=boot("full")
for _=1,15 do fill(1);settle(1) end
local mid=saved()
check(mid.cursor==1 and mid.selection.inner>=1,"partial second tile")
local head_y=mid.selection.y_min+mid.selection.inner*80
game=boot("starts");fill(2)
check(requests[1].lo.y==head_y,"resume exact inner chunk")
settle(1,"cancel");step(5)
check(requests[2].lo.y==head_y,"retry preserves inner coordinates")
settle(2);settle(1)
check(saved().selection.inner==mid.selection.inner+2 or saved().cursor==2,"ordered inner gap drains")
while saved().cursor<3 do fill(1);settle(1) end
local resumed=saved()
local direct=plan.new("full",geometry,ids,options({bounds=SMALL}))
direct.cursor=3;resolve(direct,source)
fill(1)
check(requests[1].lo.y==direct.selection.y_min and requests[1].lo.x==direct.selection.x,
 "window rebuilt after restart selects the same column")
settle(1)
check(resumed.cursor==3,"ordered progress")
source.identity="changed-authority"
check(not pcall(function() boot("full") end),"authority mismatch refused")
-- A later generate-distance edit cannot reinterpret the saved plan.
source.identity="fixture-v2"
distance_setting="4"
game=boot("full")
check(saved().reach==176,"saved reach immutable")
distance_setting="10"
-- A completed world performs no preparation work; external deep-cave requests
-- keep their native route.
source=synthetic(function() return 20 end)
local final_plan=plan.new("full",geometry,ids,options({bounds=SMALL}))
final_plan.cursor=final_plan.total-1;final_plan.authority=source.identity;seed(final_plan)
local api
game,api=boot("full")
for _=1,13 do fill(1);settle(1) end
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
 check(saved().cursor==121 and game.world_preparation_status().ready,"ready prefix unchanged")
end
idle_and_cave();game,api=boot("full");idle_and_cave()
return "r23-full-column: geometry reach window reference-coverage seabed scanner-bound restart air-chunks pipeline=2 ordered-prefix retry stop replay inner-resume budget mode authority ready-idle external-cave=ok\n"
end
