-- Portable production runtime fixture; invoked by the root's final parity pair.
return function(repo)
 local names={"core","vector","grug_core","grug_home","grug_factions","grug_mobs",
  "grug_mounts","grug_map","grug_parties","grug_jobs","grug_quests","sfinv","grug_zones"}
 local saved={};for _,name in ipairs(names) do saved[name]=rawget(_G,name) end
 local old_time=os.time
 local clock=10000
 os.time=function() return clock end
 local callbacks={join={},leave={},die={},fields={},respawn={},loaded={},step={}}
 local after,emerge={},{}
 local player,formname,formspec
 local function register(kind) return function(fn) callbacks[kind][#callbacks[kind]+1]=fn end end
 local function vnew(x,y,z)
  if type(x)=="table" then return {x=x.x,y=x.y,z=x.z} end
  return {x=x,y=y,z=z}
 end
 rawset(_G,"vector",{new=vnew,offset=function(p,x,y,z) return vnew(p.x+x,p.y+y,p.z+z) end,
  distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end})
 local ground_height=100
 local blocked=false
 rawset(_G,"core",{
  get_modpath=function(name) return repo.."/mods/PLAYER/"..name end,
  get_current_modname=function() return "grug_home" end,
  dir_to_yaw=function() return 0 end,load_area=function() end,
  register_on_joinplayer=register("join"),register_on_leaveplayer=register("leave"),
  register_on_dieplayer=register("die"),register_on_player_receive_fields=register("fields"),
  register_on_respawnplayer=register("respawn"),register_on_mods_loaded=register("loaded"),
  register_globalstep=register("step"),register_on_punchplayer=function() end,
  register_chatcommand=function() end,register_on_player_hpchange=function() end,
  global_exists=function(name) return rawget(_G,name)~=nil end,
  get_player_by_name=function() return player end,
  formspec_escape=function(s) return s end,chat_send_player=function() end,
  show_formspec=function(_,name,fs) formname,formspec=name,fs end,
  after=function(delay,fn) after[#after+1]={delay=delay,fn=fn} end,
  emerge_area=function(_,_,fn) emerge[#emerge+1]=fn end,
  EMERGE_CANCELLED=1,EMERGE_ERRORED=2,
  get_node_or_nil=function(pos)
   if blocked then return nil end
   return {name=pos.y<=ground_height and "floor" or "air"}
  end,
  registered_nodes={floor={walkable=true},air={walkable=false}},registered_entities={},
 })
 local generation,dismounts=0,0
 rawset(_G,"grug_core",{factions={accord={},throng={}},
  get_player_race=function() return player.race end,
  in_combat=function(p) assert(type(p)=="table");return p.combat end,
  invalidate_combat_identity=function() generation=generation+1 end,
  start_position=function() return vnew(0,101,0) end,
  zone_authority_installed=function() return true end})
 dofile(repo.."/mods/CORE/grug_core/settlement_sockets.lua")
 local defs=dofile(repo.."/mods/PLAYER/grug_home/locations.lua")
 for i,row in ipairs(defs) do
  grug_core.register_settlement_sockets(row.id,row.race,{x=i*100,y=100,z=0},
   {{id=row.socket,role="idle",x=0,y=1,z=0,dir={x=0,z=1}}})
 end
 rawset(_G,"grug_mobs",{register_start_socket_role=function(role,fn)
  assert(role=="innkeeper" and fn({}, {race_id="elf"})=="grug_mobs:villager_elf")
 end,dragon_map_markers=function() return {} end})
 rawset(_G,"grug_mounts",{dismount=function() dismounts=dismounts+1 end})
 -- Real faction registration also supplies the respawn callback being changed.
 dofile(repo.."/mods/PLAYER/grug_factions/init.lua")
 local data={["grug_factions:faction"]="accord"}
 local meta={get_string=function(_,key) return data[key] or "" end,
  set_string=function(_,key,value) data[key]=value end}
 local moves=0
 player={race="human",hp=20,pos=vnew(0,100,0),
  get_player_name=function() return "tester" end,is_player=function() return true end,
  get_meta=function() return meta end,get_hp=function(self) return self.hp end,
  get_pos=function(self) return self.pos end,set_pos=function(self,p) self.pos=vnew(p);moves=moves+1 end,
  get_velocity=function() return vnew(0,0,0) end,add_velocity=function() end,
  get_look_horizontal=function() return 0 end}
 local before_home={}
 for kind,list in pairs(callbacks) do before_home[kind]=#list end
 dofile(repo.."/mods/PLAYER/grug_home/init.lua")
 local home=grug_home
 assert(#home.locations()==12 and home.get(player).id=="dawnmere")
 local function deferred()
  local tasks=after;after={}
  for _,task in ipairs(tasks) do if task.delay==0 then task.fn() end end
 end
 local function finish(action)
  local fn=table.remove(emerge,1);assert(fn);fn(nil,action or 0,0);deferred()
 end
 local function event(kind)
  -- Faction tag lifecycle is outside this fixture; run every HOME handler.
  for i=before_home[kind]+1,#callbacks[kind] do callbacks[kind][i](player) end
 end
 local function fields(values,name)
  for _,fn in ipairs(callbacks.fields) do fn(player,name or formname,values) end
 end
 local function npc(id)
  local row=home.location(id)
  local e={_grug_start=id,_grug_socket=row.socket,_grug_socket_role="innkeeper"}
  e.object={get_pos=function() return row.pos end,get_luaentity=function() return e end}
  return e,row
 end
 local inn,row=npc("highcourt");player.pos=vnew(row.pos)
 assert(home.open_innkeeper(player,inn));assert(formspec:find("Set home here",1,true))
 fields({bind=true},"grug_home:innkeeper:bogus");assert(home.get(player).id=="dawnmere")
 fields({bind=true});assert(home.get(player).id=="highcourt")
 assert(formspec:find("This is your home",1,true))
 local enemy=npc("sunscar");assert(not home.open_innkeeper(player,enemy))
 player.combat=true;assert(not home.return_home(player));player.combat=false
 assert(home.return_home(player));assert(not home.return_home(player))
 finish(core.EMERGE_ERRORED);assert(moves==0 and home.remaining(player)==0)
 blocked=true;assert(home.return_home(player));finish();blocked=false;assert(moves==0)
 assert(home.return_home(player));finish();assert(moves==1 and home.remaining(player)==1800)
 assert(generation==1 and dismounts==1)
 clock=clock+10;assert(home.remaining(player)==1790)
 assert(not home.return_home(player))
 assert(callbacks.respawn[1](player));finish();assert(moves==3 and home.remaining(player)==1790)
 clock=clock+1800
 assert(home.return_home(player));home.cancel(player);finish();assert(moves==3)
 assert(home.return_home(player));player.combat=true;finish();player.combat=false;assert(moves==3)
 assert(home.return_home(player));player.hp=0;event("die");player.hp=20;finish();assert(moves==3)
 assert(home.return_home(player));data["grug_home:id"]="dawnmere";finish();assert(moves==3)
 assert(home.return_home(player));home.cancel(player);finish();assert(moves==3)
 -- A reconnect with the same player name is a different session.
 assert(home.return_home(player));event("leave")
 local replacement={};for k,v in pairs(player) do replacement[k]=v end
 player=replacement;event("join");finish();assert(moves==3)
 -- The same callback cannot commit twice, including before deferred completion.
 assert(home.return_home(player))
 local duplicate=table.remove(emerge,1);duplicate(nil,0,0);duplicate(nil,0,0);deferred()
 assert(moves==4 and home.remaining(player)==1800)
 clock=clock+1800
 -- Failed home respawn remains at the validated racial start, without charge.
 local before=moves
 assert(callbacks.respawn[1](player));assert(moves==before+1)
 local safe_wait=vnew(player.pos);finish(core.EMERGE_ERRORED)
 assert(moves==before+1 and vector.distance(player.pos,safe_wait)==0 and home.remaining(player)==0)
 -- Timeout releases the request, and a late emerge cannot teleport.
 assert(home.return_home(player));local tasks=after;after={}
 for _,task in ipairs(tasks) do if task.delay==30 then task.fn() end end
 assert(not home.is_pending(player));finish();assert(moves==before+1)
 -- Lost proximity after opening is reauthenticated on submit.
 player.pos=vnew(row.pos);assert(home.open_innkeeper(player,inn))
 player.pos=vnew(0,0,0);fields({bind=true});assert(home.get(player).id=="dawnmere")
 -- The persisted ID/deadline are sufficient across a fresh module session.
 data["grug_home:id"]="highcourt";data["grug_home:ready_at"]=tostring(clock+77)
 dofile(repo.."/mods/PLAYER/grug_home/travel.lua")
 assert(home.get(player).id=="highcourt" and home.remaining(player)==77)
 -- Actual atlas provider and Map page use the home registry.
 rawset(_G,"grug_map",{atlas=dofile(repo.."/mods/PLAYER/grug_map/atlas.lua")})
 rawset(_G,"grug_parties",{view=function() return nil end})
 rawset(_G,"grug_jobs",{PROFESSIONS={}})
 rawset(_G,"grug_quests",{registered_npcs={}})
 dofile(repo.."/mods/PLAYER/grug_map/providers.lua")
 local markers=grug_map.atlas.collect_markers(player)
 local count,selected=0,0
 for _,marker in ipairs(markers) do
  if marker.kind=="innkeeper" or marker.kind=="home" then count=count+1 end
  if marker.kind=="home" then selected=selected+1 end
 end
 assert(count==12 and selected==1)
 local page
 rawset(_G,"sfinv",{register_page=function(_,p) page=p end,
  make_formspec=function(_,_,fs) return fs end,contexts={},set_page=function() end})
 rawset(_G,"grug_zones",{at=function() return nil end})
 dofile(repo.."/mods/PLAYER/grug_map/page.lua")
 local fs=page.get(page,player,{})
 assert(fs:find("Return home: Highcourt (1:17)",1,true))
 assert(fs:find("grug_map_home",1,true))
 os.time=old_time
 for _,name in ipairs(names) do rawset(_G,name,saved[name]) end
 return "home-runtime\t12\tdefault-bind-auth-cooldown-emerge-stale-respawn-map\tPASS\n"
end
