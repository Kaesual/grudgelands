local root=assert(arg[1],"repository root required")
local registered={}
local model={mesh="horse.b3d",textures={"horse.png"},visual_size={x=1,y=1},
 collisionbox={-0.5,0,-0.5,0.5,1,0.5},description="Horse",
 animation={stand={1,1,25},move={1,40,90}}}
local flyer={mesh="eagle.b3d",textures={"eagle.png"},visual_size={x=1,y=1},
 collisionbox={-1,0,-1,1,2,1},description="Eagle",
 animation={stand={1,100,60},move={150,250,100}}}

core={registered_items={sword={},chest={},jewel={}}}
function core.register_entity(name,def) registered[name]=def end
function core.dir_to_yaw(dir) return math.atan2(-dir.x,dir.z) end
function core.serialize(value) return value end
function core.deserialize(value) return value end
local sockets={
 {id="mount_1_walk_a",pos={x=0,y=10,z=-4}},
 {id="mount_1_walk_b",pos={x=0,y=10,z=-2}},
 {id="mount_2_walk_a",pos={x=5,y=10,z=-3}},
 {id="mount_2_walk_b",pos={x=5,y=10,z=-2}},
}
grug_core={settlement_sockets_at=function() return sockets end}
grug_mounts={MODELS={t1_accord=model,troll=model,expert_accord=flyer}}
grug_gear={weapon_item=function() return "sword" end,
 armor_item=function() return "chest" end,trinket_item=function() return "jewel" end}
grug_mobs={start_npc_claim=function() return true end,
 start_npc_deactivate=function() end,register_start_socket_role=function() end}

assert(loadfile(root.."/mods/ENTITIES/grug_mobs/capital_displays.lua"))()
local def=assert(registered["grug_mobs:capital_display"])
local function object(pos)
 local value={pos={x=pos.x,y=pos.y,z=pos.z}}
 function value:set_properties(props) self.properties=props end
 function value:set_armor_groups(groups) self.armor=groups end
 function value:get_pos() return {x=self.pos.x,y=self.pos.y,z=self.pos.z} end
 function value:set_pos(next) self.pos={x=next.x,y=next.y,z=next.z} end
 function value:set_animation(range,speed,blend,loop)
  self.animation={range=range,speed=speed,loop=loop}
 end
 function value:set_yaw(yaw) self.yaw=yaw end
 return value
end

local ground={object=object({x=0,y=10,z=0}),_grug_start="capital",
 _grug_socket="mount_1",_grug_socket_role="mount_display",
 _grug_display_race="human",_grug_display_tag="1",_grug_display_floor=9.5,
 _grug_face_yaw=0,_grug_placed_at=1}
grug_mobs.configure_capital_display(ground)
assert(ground._grug_display_walk_points and ground.object.animation.speed==25)
assert(math.abs(ground.object.pos.y-(9.52+0.01152582889405449))<1e-12 and
 math.abs(ground._grug_display_walk_points[1].y-ground.object.pos.y)<1e-12,
 "ground display did not use the full move-clip foot minimum")
ground._grug_display_pause=0
local floor_before=ground.object.pos.y
def.on_step(ground,0.1)
assert(math.abs(ground.object.pos.y-floor_before)<1e-12,"first walk jumped half a node")
assert(ground.object.pos.z<0 and ground.object.animation.speed==90,
 "ground display did not walk toward authored endpoint")
for _=1,80 do def.on_step(ground,0.1) end
assert(ground.object.pos.z==-4 and ground._grug_display_walk_target==2 and
 ground._grug_display_pause>0,"ground display did not pause and reverse in bounds")

local saved=def.get_staticdata(ground)
local restored={object=object(ground.object:get_pos())}
def.on_activate(restored,saved)
assert(math.abs(restored.object.pos.y-floor_before)<1e-12 and
 restored._grug_display_walk_target==ground._grug_display_walk_target,
 "current-version display reload changed floor or walk target")

local kezamba={object=object({x=5,y=10,z=-3}),_grug_start="capital",
 _grug_socket="mount_2",_grug_socket_role="mount_display",
 _grug_display_race="troll",_grug_display_tag="2",_grug_display_floor=9.5,
 _grug_face_yaw=0,_grug_placed_at=1}
grug_mobs.configure_capital_display(kezamba)
assert(kezamba._grug_display_walk_points[1].z==-3 and
 kezamba._grug_display_walk_points[2].z==-2,
 "Kezamba T2 display did not retain its shorter authored lane")
assert(math.abs(kezamba.object.pos.y-(9.52+0.058341372000002084))<1e-12,
 "Kezamba T2 display did not use the full move-clip foot minimum")

local air={object=object({x=5,y=10,z=0}),_grug_start="capital",
 _grug_socket="mount_3",_grug_socket_role="mount_display",
 _grug_display_race="human",_grug_display_tag="3",_grug_display_floor=9.5,
 _grug_face_yaw=0,_grug_placed_at=1}
grug_mobs.configure_capital_display(air)
assert(air._grug_display_walk_points==nil and air.object.animation.range.x==1 and
 air.object.animation.range.y==100 and air.object.animation.speed==60 and
 air.object.animation.loop==true,"flying display did not animate grounded in place")
local before=air.object:get_pos()
def.on_step(air,10)
assert(air.object.pos.x==before.x and air.object.pos.z==before.z,
 "flying display moved")

io.write("r11_display\tPASS\tground_walk=1\tpause=1\tmove_grounded=1\tkezamba_lane=1\tflyer_grounded=1\n")
