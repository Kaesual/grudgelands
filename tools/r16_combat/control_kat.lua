-- Bounded real-code Round 16 combat scenarios; standalone engine doubles.
return function(repo)
local saved_arg = arg
arg = {repo, "r16-fixture"}
local f = dofile(repo .. "/tools/wp39/combat_integration_test.lua")
arg = saved_arg
local function noop() end
local t = 10000000
local function advance(seconds)
 t = t + seconds * 1e6; f.set_time(t)
 for _, step in ipairs(f.steps) do step(seconds) end
end
f.set_time(t)
local a = f.new_player("tank", "warrior", "accord")
local b = f.new_player("mage", "mage", "throng")
for _, player in ipairs({a,b}) do
 local meta = {}
 function player:get_meta() return {get_int=function(_,k) return meta[k] or 0 end,
 set_int=function(_,k,v) meta[k]=v end, get_string=function() return "" end} end
 function player:set_physics_override(v) self.physics = self.physics or {}; for k,x in pairs(v) do self.physics[k]=x end end
 function player:get_physics_override() return self.physics or {speed=1,jump=1,gravity=1} end
 for _, cb in ipairs(f.callbacks.join) do cb(player) end
 for _, cb in ipairs(f.class_callbacks) do cb(player, player.class_id) end
 f.connected[#f.connected+1]=player
end
local mob = f.new_mob("test", "throng")
local ent = mob.entity
-- The two distinct player records exercise the real threat ledger.
grug_core.add_threat(ent, a, 100)
assert(ent.attack == a)
grug_core.taunt(ent, a)
ent:do_attack(a, true)
t=t+300000; f.set_time(t)
grug_core.add_threat(ent, b, 200)
assert(ent.attack==a)
grug_core.recheck_switch(ent)
assert(ent.attack==a and ent.temp.grug_switch_pending)
t=t+3000000; f.set_time(t)
grug_core.recheck_switch(ent)
assert(ent.attack==b, "forced-window expiry must drain without another hit")
assert(math.abs(ent.temp.grug_threat.tank-110)<1e-9 and ent.temp.grug_threat.mage==200)
-- Invalid current targets cannot retain hysteresis protection.
a.hp=0; ent.attack=a; ent.temp.grug_threat.tank=1000
ent.temp.grug_switch_pending=true; grug_core.recheck_switch(ent); assert(ent.attack==b)
a.hp=40; grug_core.clear_threat(ent); assert(not ent.temp.grug_threat)
ent.attack=a; ent._grug_level=1
core.get_objects_inside_radius=function() return {mob} end
grug_core.add_threat(ent,a,100)
grug_core.add_heal_threat(b,a,20)
assert(ent.temp.grug_threat.mage==10,"effective healing threat belongs to the healer")
grug_core.add_threat(ent,b,110); grug_core.recheck_switch(ent)
assert(ent.attack==a,"exactly 120 percent must not switch")
grug_core.add_threat(ent,b,1); grug_core.recheck_switch(ent); assert(ent.attack==b)
core.get_objects_inside_radius=function() return {} end
grug_core.clear_threat(ent)
-- State lifetime, overlapping immunity/root/stun, and actual physics.
local particles=0
core.add_particlespawner=function(spec)
 if spec.texture:find("[fill:5x7",1,true) then particles=particles+1 end
end
grug_core.set_move_modifier(b,"web",{speed=-0.5},10)
assert(grug_core.set_root(b,4)); grug_core.mark_nova_root(b,4)
advance(0.3); assert(particles==1)
grug_core.set_stun(b,1.5)
assert(b.physics.speed*b.physics.speed_walk==0 and b.physics.jump==0 and b.physics.gravity==nil)
-- Engine LocalPlayer::accelerate horizontal clamp, node units; exercise
-- moving players at 200fps including the minimum slippery-node factor.
for _,case in ipairs({{"default",0.001},{"air",1},{"fast",0.001}}) do
 local base=case[1]=="air" and 3 or 10
 local increment=base*b.physics["acceleration_"..case[1]]*0.005*b.physics.speed*case[2]
 local vx,vz,vy=6,8,-12
 local length=math.sqrt(vx*vx+vz*vz)
 local reduction=math.min(length,increment)/length
 vx,vz=vx*(1-reduction),vz*(1-reduction)
 assert(vx==0 and vz==0)
 -- Engine air branch explicitly sets incV=0, unrelated to incH.
 if case[1]=="air" then assert(vy==-12 and b.physics.gravity==nil) end
end
grug_core.set_move_immunity(b,2)
assert(grug_core.is_stunned(b) and b.physics.speed*b.physics.speed_walk==0)
advance(1.6); assert(not grug_core.is_stunned(b) and b.physics.speed==1)
assert(particles==1,"immunity must stop root particles")
assert(b.physics.speed_walk==1 and b.physics.speed_fast==1 and b.physics.speed_climb==1
 and b.physics.speed_crouch==1 and b.physics.acceleration_air==1
 and b.physics.acceleration_default==1 and b.physics.acceleration_fast==1)
advance(0.5); assert(b.physics.speed*b.physics.speed_walk==0.5)
grug_core.clear_movement(b)
-- Cache and forced watchdog must compare the physical representation.
grug_core.set_root(b,4); grug_core.set_stun(b,1.5)
grug_core.hold_movement(b,"fixture")
b.physics.speed_fast=1; b.physics.acceleration_air=0
grug_core.hold_movement(b,"fixture")
assert(b.physics.speed_fast==0 and b.physics.acceleration_air>0 and b.physics.gravity==0)
grug_core.release_movement(b,"fixture")
assert(b.physics.gravity==1 and b.physics.speed_walk==0)
grug_core.clear_movement(b)
assert(b.physics.speed_walk==1 and b.physics.acceleration_air==1)
-- New casts stop before resource payment or projectile spawn.
local fireball=grug_abilities.registered.fireball
local count=#f.spawns; local mana=grug_abilities.get_mana(b)
grug_core.set_stun(b,1.5)
grug_abilities.try_cast(b,fireball,nil)
assert(#f.spawns==count and grug_abilities.get_mana(b)==mana)
advance(1.6)
grug_abilities.try_cast(b,fireball,nil); assert(#f.spawns==count+1)
-- Pending bow draws are canceled immediately, including a whole stun between ticks.
grug_inventory.is_bow=function(stack) return stack:get_name()=="test:weapon_a" end
grug_inventory.ammo_count=function() return 10 end
b.equipped_weapon=ItemStack("test:weapon_a")
b.inventory:set_stack("main",32,ItemStack("grug_abilities:loose")); b.wield=32; b.dig=true
assert(grug_abilities.registered.loose.cast(b))
local launches=#f.spawns
grug_core.set_stun(b,1.5); b.dig=false
advance(2)
assert(#f.spawns==launches,"stun must discard pending draw even when no step saw the stun")
assert(b.inventory:get_stack("main",32):get_wear()==0)
-- Pending swing click input is discarded; packets during stun cannot re-latch.
a.inventory:set_stack("main",32,ItemStack("grug_abilities:strike")); a.wield=32
assert(grug_core.handle_native_swing_input(a,mob))
grug_core.set_stun(a,1.5)
assert(grug_core.handle_native_swing_input(a,mob))
local punches=mob.punches
advance(2); assert(mob.punches==punches)
-- Load the complete real mob adapter, suppressing only unrelated content imports.
local env
env=setmetatable({dofile=function() if env.grug_mobs then env.grug_mobs.install_spawn_clock_wrapper=noop end end},{__index=_G})
core.get_current_modname=function() return "grug_mobs" end
core.register_on_shutdown=core.register_on_shutdown or noop
core.get_mod_storage=core.get_mod_storage or function() return {} end
mobs={mob_class={},register_mob=function(_,_,def) env.def=def end}
grug_core.zone_authority_installed=function() return true end
local chunk=assert(loadfile(repo.."/mods/ENTITIES/grug_mobs/init.lua")); setfenv(chunk,env); chunk()
grug_mobs=env.grug_mobs
-- Adapter dependencies are distinct packages, not copied control logic.
grug_mobs.register_spawn_role=noop; grug_mobs.install_flight_nudge=noop
local gm=grug_mobs
gm.is_noncombatant=function() return false end
gm.ensure_init=noop; gm.apply_aggro_fields=noop; gm.leash_tick=noop
function mob:get_velocity() return self.velocity or vector.new(1,-2,1) end
function mob:set_velocity(v) self.velocity=v end
function mob:get_properties() return {collisionbox={-0.4,0,-0.4,0.4,1.8,0.4}} end
function mob:punch(hitter,_,caps)
 if self.mode=="cancel" then return end
 local damage=caps.damage_groups.fleshy
 grug_core.run_player_hit_mob(hitter,ent,damage)
 ent.health=ent.health-math.floor(damage)
end
ent.health=100; ent.walk_velocity=1; ent.run_velocity=3
ent.temp.grug_tg_left=0.2; ent.temp.grug_telegraph=true
assert(gm.stun(ent,1.5)); assert(ent.walk_velocity==0 and mob.velocity.y==-2)
assert(not ent.temp.grug_tg_left and not ent.temp.grug_telegraph)
gm.slow(ent,3,0.5); gm.tick_speed_effects(ent,0.5)
assert(ent._grug_slow_left==2.5 and ent.run_velocity==0)
ent._grug_stun_left=0; gm.tick_speed_effects(ent,3); assert(ent.run_velocity==3)
ent._grug_boss_id="king:test"; assert(not gm.stun(ent,1.5))
ent._grug_boss_id="dragon:test"; assert(not gm.stun(ent,1.5)); ent._grug_boss_id=nil
-- Taunt cannot re-enter combat or mint a ledger during evade.
ent.temp.grug_evading=true; grug_core.clear_threat(ent)
assert(grug_core.taunt(ent,a)==false)
grug_core.add_threat(ent,a,20); assert(not ent.temp.grug_threat)
local taunts=mob.taunts
local taunt=grug_abilities.registered.taunt
f.queue_ray({f.pointed(mob,2)}); assert(taunt.cast(a,nil,taunt)==false)
assert(mob.taunts==taunts and not ent.temp.grug_threat)
ent.temp.grug_evading=nil
-- Charge keeps its current movement but only accepted hits apply control.
local charge=grug_abilities.registered.charge
f.queue_ray({f.pointed(mob,2)}); charge.cast(a,nil,charge)
assert(ent._grug_stun_left==1.5)
ent._grug_stun_left=nil; mob.mode="cancel"
f.queue_ray({f.pointed(mob,2)}); charge.cast(a,nil,charge)
assert(not ent._grug_stun_left); mob.mode="accepted"
-- Nova's quarter baseline, one talent addition, and accepted-root semantics.
local nova=grug_abilities.registered.frost_nova
assert(nova.values(b).damage==fireball.values(b).damage/4)
local original_bonus=grug_classes.get_talent_bonus
grug_classes.get_talent_bonus=function(_,key) return key=="control_damage_add" and 5 or 0 end
assert(nova.values(b).damage==fireball.values(b).damage/4+5)
grug_classes.get_talent_bonus=original_bonus
core.get_objects_inside_radius=function() return {mob} end
mob.faction="accord"; ent._grug_faction="accord"
local health=ent.health; nova.cast(b,nil,nova)
assert(ent.health<health and ent._grug_root_left==4 and ent._grug_nova_left==4)
ent._grug_root_left=nil; ent._grug_nova_left=nil; mob.mode="cancel"
nova.cast(b,nil,nova); assert(not ent._grug_root_left)
-- PvP accepted settlement is a real health-change boundary, rejection is inert.
core.get_objects_inside_radius=function() return {a} end
function a:punch(_,_,caps) if not self.refuse_punch then self.hp=self.hp-math.floor(caps.damage_groups.fleshy) end end
a.hp=40; nova.cast(b,nil,nova); assert(grug_core.get_move_state(a).rooted)
grug_core.clear_movement(a); a.refuse_punch=true
nova.cast(b,nil,nova); assert(not grug_core.get_move_state(a).rooted)
a.refuse_punch=false; grug_core.set_move_immunity(a,3)
nova.cast(b,nil,nova); assert(not grug_core.get_move_state(a).rooted)
for _, cb in ipairs(f.callbacks.die) do cb(a) end
assert(not grug_core.is_stunned(a) and grug_core.get_move_state(a).speed==1)
-- The real vendored on_step must stop pre-custom jumping and pending attacks,
-- including its knockback pause branch. Gravity and environmental ticks remain.
local api_core=setmetatable({
 registered_aliases={}, registered_nodes={air={groups={}}}, registered_entities={},
 get_translator=function() return function(text) return text end end,
 formspec_escape=function(text) return text end, global_exists=function() return false end,
 get_modpath=function() return nil end, check_player_privs=function() return false end,
 register_entity=noop, register_on_player_receive_fields=noop,
 register_chatcommand=noop, register_globalstep=noop,
 settings={get=function() return nil end,get_bool=function() return true end},
},{__index=core})
local api_env=setmetatable({core=api_core,minetest=api_core,grug_mobs=gm},{__index=_G})
local api=assert(loadfile(repo.."/mods/ENTITIES/mobs/api.lua")); setfenv(api,api_env); api()
local jumps, attacks, falls, customs=0,0,0,0
local native=setmetatable({object=mob,state="attack",health=100,temp={},
 node_timer=0,env_damage_timer=0,pause_timer=0,timer=0,timer1=0,
 walk_velocity=1,run_velocity=3,update_tag=noop,
 get_nodes=noop,is_at_cliff=function() return false end,mob_expire=function() return false end,
 do_jump=function() jumps=jumps+1 end,falling=function() falls=falls+1; return false end,
 do_env_damage=function() return false end,replace=noop,check_item_pickup=noop,
 do_custom=function(self,dt) customs=customs+1; gm.tick_speed_effects(self,dt) end,
 do_states=function() attacks=attacks+1; return false end,general_attack=noop,
 breeding=noop,follow_flop=noop,
}, {__index=api_env.mobs.mob_class})
gm.root(native,4); native._grug_nova_left=4
gm.stun(native,1.5); native.pause_timer=0.5
for _=1,5 do native:on_step(0.3,{}) end
assert(jumps==0 and attacks==0 and customs==0 and falls==5)
assert(math.abs(native._grug_root_left-2.5)<1e-9,"root must tick while stunned")
assert(native._grug_stun_left<1e-9)
-- The next native frame resumes one ordinary pass without a backlog.
native:on_step(0.01,{})
assert(attacks<=1 and native.timer<=0.01)
-- Load actual Ibex registration and assert the targeting box remains separate.
local captured={}
local family_env=setmetatable({grug_mobs=setmetatable({
 register_mob=function(name,def) captured[name]=def end,
 passive_prey=noop,melee_rider=noop,camp_swarm=noop,
}, {__index=gm}),mobs={spawn=noop}},{__index=_G})
local family=assert(loadfile(repo.."/mods/ENTITIES/grug_mobs/start_zone_families.lua")); setfenv(family,family_env); family()
local box=captured["grug_mobs:ibex"].selectionbox
assert(box[5]==1.8 and box.rotate==true)
-- The local head point remains in the oriented box at 0/90/180/270 yaw.
for _,yaw in ipairs({0,math.pi/2,math.pi,3*math.pi/2}) do
 local x,z=0.95*math.sin(yaw),0.95*math.cos(yaw)
 local lx,lz=x*math.cos(yaw)-z*math.sin(yaw),x*math.sin(yaw)+z*math.cos(yaw)
 assert(lx>=box[1] and lx<=box[4] and lz>=box[3] and lz<=box[6])
end
assert(captured["grug_mobs:ibex"].collisionbox[5]==0.5)
local scaled
local scale_object={get_properties=function() return {} end,
 set_properties=function(_,props) scaled=props end}
local scaled_mob={object=scale_object,base_size={x=1,y=1},base_selbox=box,
 base_colbox=captured["grug_mobs:ibex"].collisionbox}
api_env.mobs:scale_mob(scaled_mob,0.5,0.5,true)
assert(scaled.selectionbox.rotate and scaled_mob.base_selbox.rotate)
assert(scaled.selectionbox[6]==box[6]*0.5)
return "r16-combat\tthreat-expiry\tstun\tnova\tPASS\n"
end
