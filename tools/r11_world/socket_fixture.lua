-- Real parts rotation -> real settlement registry -> GAME waypoint lookup.
return function(repo)
 local dir=repo..'/mods/MAPGEN/grug_mapgen/wp13'
 local services=dofile(dir..'/capital_services.lua')
 local districts=dofile(dir..'/highcourt_districts.lua')(dir)
 local parts=dofile(dir..'/parts.lua');local bp
 for _,p in ipairs(districts.resolve())do
  if services.service('highcourt',p.id)=='riding' then bp=p.build();break end
 end
 assert(bp)
 local core_api={dir_to_yaw=function(d)return math.atan2(-d.x,d.z)end}
 local env=setmetatable({grug_core={},core=core_api,
  vector={new=function(x,y,z)return{x=x,y=y,z=z}end}},{__index=_G})
 local loader=assert(loadfile(repo..'/mods/CORE/grug_core/settlement_sockets.lua'))
 setfenv(loader,env);loader()
 local buffer=parts.buffer()
 for _,cell in ipairs(bp.cells)do buffer:put(cell.x,cell.y,cell.z,cell.name,cell.param2)end
 for rotation=0,3 do
  local moved=parts.stamp(parts.buffer(),{buffer=buffer,w=1,d=1,
   points={sockets=bp.landmarks.sockets}},13,27,-41,rotation)
  for _,s in ipairs(moved.sockets)do local x,z=parts.facedir_step(s.face);s.dir={x=x,z=z}end
  local id='fixture_capital_'..rotation
  env.grug_core.register_settlement_sockets(id,'human',{x=-500,y=72,z=901},moved.sockets)
  local rows=env.grug_core.settlement_sockets_at(id);local map={}
  for _,s in ipairs(rows)do map[s.id]=s end
  local checked=0
  for _,s in ipairs(rows)do if s.role=='mount_display' and tonumber(s.tags[1])<=2 then
   local a=assert(map[s.id..'_walk_a']);local b=assert(map[s.id..'_walk_b'])
   assert(a.spawn==false and b.spawn==false and a.pos.y==s.pos.y and b.pos.y==s.pos.y)
   assert(a.pos.y==100,'terrain-fitted absolute endpoint y lost')
   assert((a.pos.x-b.pos.x)^2+(a.pos.z-b.pos.z)^2==4)
   assert((a.pos.x-s.pos.x)^2+(a.pos.z-s.pos.z)^2==1)
   local mx,mz=(a.pos.x+b.pos.x)/2,(a.pos.z+b.pos.z)/2
   assert(mx==s.pos.x and mz==s.pos.z,'lane midpoint lost rotation')
   a.pos.y=-999
   for _,fresh in ipairs(env.grug_core.settlement_sockets_at(id))do
    if fresh.id==a.id then assert(fresh.pos.y==100,'registry leaked mutable position')end
   end
   checked=checked+1
  end end
  assert(checked==2)
 end
 return 'R11 sockets PASS: actual rotation and registry, four orientations, absolute terrain y, immutable lookup copies\n'
end
