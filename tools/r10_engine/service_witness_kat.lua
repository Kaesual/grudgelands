-- Real-production-shape regression for the capital service witness.
-- LuaJIT development evidence only; the final PUC pair remains integration-owned.
return function(root, scratch)
 local service_path=root.."/mods/MAPGEN/grug_mapgen/wp13/capital_services.lua"
 local witness_path=root.."/tools/wp13/capital_probe/service_witness.lua"
 local services=assert(loadfile(service_path))()
 local station_nodes={forge="grug_jobs:forge",tailor_bench="grug_jobs:tailor_bench",
  brewing_stand="grug_brewing:brewing_stand",tanning_rack="grug_jobs:tanning_rack",
  carving_bench="grug_jobs:carving_bench",jewellers_bench="grug_jobs:jewellers_bench",
  furnace="default:furnace"}
 local models={}
 for _,id in ipairs({"t1_accord","human","expert_accord","master_accord"}) do
  models[id]={mesh=id..".b3d",textures={id..".png"},
   visual_size={x=1.45,y=1.55},collisionbox={-.8,-.4,-.8,.8,1.4,.8},
   description=id,animation={stand={10,20}}}
 end
 local gear={weapon="grug_gear:sword_bronze",armor="grug_gear:chest_metal_bronze",
  jewel="grug_gear:trinket_manawell_t1"}
 local relevant={trainer=true,riding_trainer=true,mount_display=true,gear_display=true}
 local function build(mutation)
  local plots,sockets,entities,nodes={}, {}, {}, {}
  local service_names={"forge","tailor","alchemist","leatherworker",
   "woodcarver","goldsmith","cooking","riding"}
  for index,name in ipairs(service_names) do
   local plot_id=assert(services.PLOTS.highcourt[name])
   local ox=(index-1)*40
   local local_sockets={}
   local buf={put=function() end,clear=function() end}
   local palette={node=function() return "default:stone" end}
   services.decorate("highcourt",plot_id,buf,palette,local_sockets)
   plots[#plots+1]={id=plot_id,x=ox,z=0,composition={
    reference={x=0,z=0},bounds={min={x=-15,y=-6,z=-15},max={x=15,y=24,z=15}}}}
   for _,source in ipairs(local_sockets) do
    local socket={}
    for k,v in pairs(source) do socket[k]=v end
    socket.id=plot_id.."/"..source.id -- exact r7_settlement projection contract
    socket.pos={x=ox+source.x,y=source.y,z=source.z}
    sockets[#sockets+1]=socket
    local p=socket.pos
    if socket.role=="public_station" then
     nodes[p.x..":"..p.y..":"..p.z]=station_nodes[socket.tags[1]]
    elseif relevant[socket.role] then
     nodes[p.x..":"..(p.y-1)..":"..p.z]="default:stone"
     nodes[p.x..":"..p.y..":"..p.z]="air"
     nodes[p.x..":"..(p.y+1)..":"..p.z]="air"
     local entity={_grug_start="highcourt",_grug_socket=socket.id,
      _grug_socket_role=socket.role,name="grug_mobs:villager_human",
      _grug_walker=false,_grug_profession=socket.profession}
     if socket.role=="riding_trainer" then entity._grug_npc_name="Riding Trainer" end
     local pos={x=p.x,y=p.y,z=p.z}
     local props={physical=true,pointable=true,collide_with_objects=true,
      collisionbox={-0.3,0,-0.3,0.3,1.7,0.3}}
     if socket.role=="mount_display" or socket.role=="gear_display" then
      entity.name="grug_mobs:capital_display";entity._grug_display_race="human"
      entity._grug_display_tag=socket.tags[1];entity._grug_display_floor=p.y-0.5
      props={physical=false,pointable=false,collide_with_objects=false,
       collisionbox={0,0,0,0,0,0}}
	     end
	     local object={}
	     function object:get_pos() return pos end
	     function object:set_pos(value) pos={x=value.x,y=value.y,z=value.z} end
	     function object:get_properties() return props end
	     function object:set_properties(values)
	      for k,v in pairs(values) do props[k]=v end
	      if values.visual_size then props.visual_size={x=values.visual_size.x+0.0000001,
	       y=values.visual_size.y-0.0000001} end
	      if values.collisionbox then props.collisionbox={}
	       for i,v in ipairs(values.collisionbox) do props.collisionbox[i]=v+0.0000001 end
	      end
	     end
	     local armor={}
	     function object:set_armor_groups(value) armor=value end
	     function object:get_armor_groups() return armor end
	     local animation={{x=1,y=1},15,0,true}
	     function object:set_animation(range,speed,blend,loop)
	      animation={{x=range.x+0.0000001,y=range.y-0.0000001},speed,blend,loop}
	     end
	     function object:get_animation() return animation[1],animation[2],animation[3],animation[4] end
	     function object:set_yaw() end
     function object:get_luaentity() return entity end
     entity.object=object;entities[#entities+1]=object
    end
   end
  end
  if mutation=="outside_socket" then
   sockets[#sockets+1]={id="retired_core/trainer",role="trainer",
    profession="tailor",pos={x=0,y=1,z=0}}
  elseif mutation=="unexpected_entity" then
   local entity={name="grug_mobs:villager_human",_grug_start="highcourt",
    _grug_socket="forge_house/unexpected",_grug_socket_role="trainer"}
   local object={get_pos=function() return {x=0,y=1,z=0} end,
    get_luaentity=function() return entity end};entity.object=object
   entities[#entities+1]=object
  end
  local unloaded_key
  if mutation=="unloaded_node" then
   for _,socket in ipairs(sockets) do if socket.role=="public_station" then
    unloaded_key=socket.pos.x..":"..socket.pos.y..":"..socket.pos.z;break end end
  end
  local registered={air={walkable=false},["default:stone"]={walkable=true}}
  for _,name in pairs(station_nodes) do registered[name]={walkable=true} end
	  local registered_items={[gear.weapon]={},[gear.armor]={},[gear.jewel]={}}
	  local core_mock={EMERGE_ERRORED=-1,EMERGE_CANCELLED=-2,
	   registered_nodes=registered,registered_items=registered_items}
  function core_mock.get_modpath(name)
   assert(name=="grug_wp13_capital_probe");return root.."/tools/wp13/capital_probe"
  end
  function core_mock.get_node_or_nil(p)
   local key=p.x..":"..p.y..":"..p.z
   if key==unloaded_key then return nil end
   return {name=nodes[key] or "air",param2=0}
  end
  function core_mock.get_node(p) return core_mock.get_node_or_nil(p) or {name="ignore"} end
  function core_mock.emerge_area(_,_,callback) callback(nil,0,0) end
  function core_mock.forceload_block() return true end
  function core_mock.forceload_free_block() end
  function core_mock.after(_,callback) callback() end
	  function core_mock.get_objects_in_area(minp,maxp)
   local out={}
   for _,object in ipairs(entities) do local p=object:get_pos()
    if p.x>=minp.x and p.x<=maxp.x and p.y>=minp.y and p.y<=maxp.y and
      p.z>=minp.z and p.z<=maxp.z then out[#out+1]=object end
   end
   return out
	  end
	  function core_mock.register_entity() end
	  _G.core=core_mock;_G.grug_zones={terrain_height_at=function() return 0 end}
	  _G.grug_core={settlement_sockets_at=function() return sockets end}
	  _G.grug_mounts={MODELS=models}
	  _G.grug_gear={weapon_item=function() return gear.weapon end,
	   armor_item=function() return gear.armor end,trinket_item=function() return gear.jewel end}
	  _G.grug_mobs={register_start_socket_role=function() end}
	  assert(loadfile(root.."/mods/ENTITIES/grug_mobs/capital_displays.lua"))()
	  for _,object in ipairs(entities) do local entity=object:get_luaentity()
	   if entity.name=="grug_mobs:capital_display" then
	    grug_mobs.configure_capital_display(entity)
	   end
	  end
	  if mutation=="wrong_race" or mutation=="display_intrinsic" or
	    mutation=="bad_float" then
	   for _,object in ipairs(entities) do local entity=object:get_luaentity()
	    if mutation=="wrong_race" and entity._grug_socket_role=="trainer" then
	     entity.name="grug_mobs:villager_orc";break
	    elseif mutation=="display_intrinsic" and
	      entity._grug_socket_role=="gear_display" then
	     object:get_properties().physical=true;break
	    elseif mutation=="bad_float" and
	      entity._grug_socket_role=="mount_display" then
	     object:get_properties().visual_size.x=1.46;break
	    end
	   end
	  end
  local failed
  local done=false
  local ok,err=pcall(function()
   local run=assert(loadfile(witness_path))()({key="highcourt",race="human",plots=plots,
    anchor={x=0,y=0,z=0},worldpath=scratch,wp13=root.."/mods/MAPGEN/grug_mapgen/wp13",
    fail=function(message) failed=message;error(message,0) end,log=function() end})
   run(function() done=true end)
  end)
  return ok,err or failed,done
 end
 local ok,err,done=build(nil);assert(ok and done,err)
 for _,case in ipairs({"outside_socket","unexpected_entity","unloaded_node",
   "wrong_race","display_intrinsic","bad_float"}) do
  local case_ok=build(case)
  assert(not case_ok,"service witness mutation survived: "..case)
 end
 return "service_witness_kat:v1:canonical_slash,float_roundtrip,outside_socket,unexpected_entity,unloaded_node,wrong_race,display_intrinsic,bad_float"
end
