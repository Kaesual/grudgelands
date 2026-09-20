-- Bounded authored render entities. The existing settlement socket lease owns
-- population and reload deduplication. Ground mounts walk only between the two
-- authored spare sockets beside their home; flying mounts animate in place.
local FACTION={human="accord",dwarf="accord",elf="accord",
 orc="throng",undead="throng",troll="throng"}
local SAVED={"_grug_start","_grug_socket","_grug_placed_at","_grug_face_yaw",
 "_grug_socket_role","_grug_display_race","_grug_display_tag","_grug_display_floor",
 "_grug_display_walk_target","_grug_display_pause"}
local WALK_SPEED=0.6
local WALK_PAUSE=3
local WALK_STEP=0.1

-- Posed foot Y in nodes: catalog stand[1], full B3D skin, visual_size / BS.
-- Reproduced by tools/r10_cap/b3d_pose.py; never changes rideable mount physics.
local FOOT_Y={dwarf=-0.011460670,elf=-0.000000103,
 expert_accord=-0.160746604,expert_throng=0.636211494,
 human=-0.001113216,master_accord=-0.214328805,master_throng=0.890696092,
 orc=-0.006643265,t1_accord=-0.001113216,t1_throng=-0.001113216,
 troll=-0.016625724,undead=-0.018340415}

local function display_animation(self,name)
 if self._grug_display_anim==name then return end
 local clip=self._grug_display_model and self._grug_display_model.animation[name]
 if not clip then return end
 self.object:set_animation({x=clip[1],y=clip[2]},clip[3],0,true)
 self._grug_display_anim=name
end

local function walk_points(self,key)
 local sockets=grug_core.settlement_sockets_at(self._grug_start)
 local wanted={self._grug_socket.."_walk_a",self._grug_socket.."_walk_b"}
 local found={}
 for _,socket in ipairs(sockets) do
  if socket.id==wanted[1] then found[1]=socket.pos
  elseif socket.id==wanted[2] then found[2]=socket.pos end
 end
 if not found[1] or not found[2] then return nil end
 for index=1,2 do
  found[index]={x=found[index].x,
   y=found[index].y+0.02-assert(FOOT_Y[key]),z=found[index].z}
 end
 return found
end

local function valid_saved(data)
 if type(data)~="table" or type(data._grug_start)~="string" or
  type(data._grug_socket)~="string" or type(data._grug_placed_at)~="number" then
  return false
 end
 if data._grug_socket_role=="mount_display" then
  local tier=tonumber(data._grug_display_tag)
  return type(data._grug_display_floor)=="number" and
   FACTION[data._grug_display_race]~=nil and tier~=nil and
   tier>=1 and tier<=4 and tier==math.floor(tier)
 end
 return data._grug_socket_role=="gear_display" and
  (data._grug_display_tag=="weapon" or data._grug_display_tag=="armor" or
   data._grug_display_tag=="jewel")
end

function grug_mobs.configure_capital_display(self)
 if not self._grug_display_tag then return end
 if self._grug_socket_role=="mount_display" then
  local tier=tonumber(self._grug_display_tag)
  local faction=FACTION[self._grug_display_race]
  local key=tier==1 and "t1_"..faction or tier==2 and self._grug_display_race or
   (tier==3 and "expert_" or "master_")..faction
  local model=assert(grug_mounts.MODELS[key],"capital mount appearance missing")
  self.object:set_properties({visual="mesh",mesh=model.mesh,textures=model.textures,
   visual_size=model.visual_size,collisionbox=model.collisionbox,
   nametag=model.description})
  local pos=self.object:get_pos()
  pos.y=assert(self._grug_display_floor)+0.02-assert(FOOT_Y[key])
  self.object:set_pos(pos)
  self._grug_display_model=model
  self._grug_display_anim=nil
  self._grug_display_walk_points=tier<=2 and walk_points(self,key) or nil
  self._grug_display_walk_target=tonumber(self._grug_display_walk_target) or 1
  if self._grug_display_walk_target~=1 and self._grug_display_walk_target~=2 then
   self._grug_display_walk_target=1
  end
  self._grug_display_pause=math.max(0,tonumber(self._grug_display_pause) or WALK_PAUSE)
  display_animation(self,"stand")
 else
  local tag=self._grug_display_tag
  local item=tag=="weapon" and grug_gear.weapon_item("sword",1) or
   tag=="armor" and grug_gear.armor_item("chest","metal",1) or
   tag=="jewel" and grug_gear.trinket_item("manawell",1)
  assert(item and core.registered_items[item],"capital gear display item missing")
  self.object:set_properties({visual="wielditem",textures={item},
   visual_size={x=0.4,y=0.4},nametag=""})
 end
 self.object:set_armor_groups({immortal=1})
 self.object:set_yaw(self._grug_face_yaw or 0)
end

core.register_entity("grug_mobs:capital_display",{
 initial_properties={physical=false,collide_with_objects=false,pointable=false,
  visual="sprite",textures={"grug_mobs_blank.png"},visual_size={x=1,y=1},
  collisionbox={0,0,0,0,0,0},hp_max=1,static_save=true},
 _grug_capital_display=true,
 on_activate=function(self,staticdata)
  self.object:set_armor_groups({immortal=1})
  if staticdata and staticdata~="" then
   local data=core.deserialize(staticdata)
   if not valid_saved(data) then self.object:remove();return end
   for _,key in ipairs(SAVED) do self[key]=data[key] end
   if not grug_mobs.start_npc_claim(self) then return end
   grug_mobs.configure_capital_display(self)
  end
 end,
 get_staticdata=function(self)
  local data={}
  for _,key in ipairs(SAVED) do data[key]=self[key] end
  return core.serialize(data)
 end,
 on_step=function(self,dtime)
  local points=self._grug_display_walk_points
  if not points then return end
  self._grug_display_elapsed=(self._grug_display_elapsed or 0)+dtime
  if self._grug_display_elapsed<WALK_STEP then return end
  local elapsed=math.min(self._grug_display_elapsed,0.5)
  self._grug_display_elapsed=0
  if self._grug_display_pause>0 then
   self._grug_display_pause=math.max(0,self._grug_display_pause-elapsed)
   display_animation(self,"stand")
   return
  end
  local target=points[self._grug_display_walk_target]
  local pos=self.object:get_pos()
  if not pos or not target then return end
  local dx,dz=target.x-pos.x,target.z-pos.z
  local distance=math.sqrt(dx*dx+dz*dz)
  if distance<=0.05 then
   self.object:set_pos(target)
   self._grug_display_walk_target=self._grug_display_walk_target==1 and 2 or 1
   self._grug_display_pause=WALK_PAUSE
   display_animation(self,"stand")
   return
  end
  local amount=math.min(distance,WALK_SPEED*elapsed)
  self.object:set_pos({x=pos.x+dx/distance*amount,
   y=target.y,z=pos.z+dz/distance*amount})
  self.object:set_yaw(core.dir_to_yaw({x=dx,y=0,z=dz}))
  display_animation(self,"move")
 end,
 on_deactivate=function(self,removal)
  grug_mobs.start_npc_deactivate(self,removal)
 end,
 on_punch=function() return true end,
 on_rightclick=function() end,
 on_death=function() end,
})
for _,role in ipairs({"mount_display","gear_display"}) do
 grug_mobs.register_start_socket_role(role,function()
  return "grug_mobs:capital_display"
 end)
end
