-- Compact real Core, mob adapter, aggro and vendored AI fixture.
return function(repo)
local old_arg=arg
arg={repo,"r16-fixture"}
local f=dofile(repo.."/tools/wp39/combat_integration_test.lua")
arg=old_arg
local function noop() end
local now=0
local function clock(n) now=n; f.set_time(n*1000000) end
local env
env=setmetatable({dofile=function() if env.grug_mobs then env.grug_mobs.install_spawn_clock_wrapper=noop end end},{__index=_G})
core.registered_entities={}
core.get_current_modname=function() return "grug_mobs" end
core.register_on_shutdown=noop
core.get_mod_storage=function() return {} end
mobs={mob_class={},register_mob=function(_,_,def) env.def=def end}
grug_core.zone_authority_installed=function() return true end
setfenv(assert(loadfile(repo.."/mods/ENTITIES/grug_mobs/init.lua")),env)()
grug_mobs=env.grug_mobs
local gm=grug_mobs
gm.register_spawn_role=noop; gm.register_level_cfg=noop
gm.install_flight_nudge=noop; gm.ensure_init=noop
gm.apply_disposition=function() return "aggressive" end
local captured={}
mobs.register_mob=function(_,name,def) captured[name]=def; core.registered_entities[name]={} end
local api_core=setmetatable({registered_aliases={},registered_nodes={air={groups={}}},registered_entities={},
 get_translator=function() return function(s) return s end end,
 formspec_escape=function(s) return s end, global_exists=function() return false end,
 get_modpath=function(name) if name=="mobs" then return repo.."/mods/ENTITIES/mobs" end end,
 check_player_privs=function() return false end,register_entity=noop,sound_play=noop,
 register_on_player_receive_fields=noop,register_chatcommand=noop,register_globalstep=noop,
 settings={get=function() return nil end,get_bool=function(_,k) return k=="enable_damage" end},
},{__index=core})
local api_env=setmetatable({core=api_core,minetest=api_core,grug_mobs=gm},{__index=_G})
setfenv(assert(loadfile(repo.."/mods/ENTITIES/mobs/api.lua")),api_env)()
dofile(repo.."/mods/ENTITIES/grug_mobs/aggro.lua")
local native=api_env.mobs.mob_class
local a=f.new_player("pursuer","mage","accord")
local b=f.new_player("rival","mage","accord")
function a:get_luaentity() return nil end
function b:get_luaentity() return nil end
local function mob()
 local obj=f.new_mob("test:ambient","throng")
 local e=obj.entity
 e.hp_max=100; e.type="monster"; e.state="stand"; e.sounds={}; e.path={}; e.standing_in="air"
 e.set_velocity=noop; e.set_animation=noop; e.mob_sound=noop; e.update_tag=noop
 e.do_attack=native.do_attack; e.stop_attack=native.stop_attack
 e._grug_home={x=0,y=1,z=3}
 gm.apply_aggro_fields(e,{damage_pursuit=true})
 return e,obj
end
-- Registration classification reaches the runtime through the real wrapper.
for i,row in ipairs({{nil,"monster",false,true},{"elite","monster",false,true},
 {"critter","animal",true,false},{"boss","monster",false,false},{nil,"npc",false,false},
 {"rare","monster",false,false}}) do
 local name="test:policy"..i
 gm.register_mob(name,{type=row[2],passive=row[3],attack_type="dogfight",_grug_tier=row[1]})
 assert(core.registered_entities[name]._grug_damage_pursuit_candidate==row[4])
 local e=mob(); captured[name].do_punch(e,nil,1,{},nil,0)
 assert(gm.damage_pursuit(e)==row[4],"registration policy "..i)
end
mobs.spawn=noop
dofile(repo.."/mods/ENTITIES/grug_mobs/zombie.lua")
assert(core.registered_entities["grug_mobs:zombie"]._grug_damage_pursuit_candidate)
gm.compile_spawn_domains=noop
gm.camp_swarm=noop; gm.stalker=noop; gm.melee_rider=noop
gm.atlas_textures=function(texture) return {{texture}} end
gm.bandit_def=function() return {type="monster",attack_type="dogfight",animation={}} end
dofile(repo.."/mods/ENTITIES/grug_mobs/night_families.lua")
dofile(repo.."/mods/ENTITIES/grug_mobs/zero_asset_variants.lua")
for _,name in ipairs({"goblin_raider","goblin_slinger","goblin_hound","sun_dried_husk"}) do
 assert(core.registered_entities["grug_mobs:"..name]._grug_damage_pursuit_candidate,name)
end
local e,obj=mob()
for _,key in ipairs({"_grug_camp_pos","_grug_rare_id","_grug_boss_id","_grug_royal_summon","_grug_boss_summon","_grug_patrol_route","_grug_no_leash"}) do
 e[key]=true; assert(not gm.damage_pursuit(e),key); e[key]=nil
end
clock(0); e:do_attack(a); assert(e.temp.grug_damage_at==0)
for t=1,60 do
 clock(t); obj.position.x=t*100
 if t%10==0 then gm.received_pursuit_damage(e,a,1) end
 gm.leash_tick(e,1)
 assert(e.attack==a and not e.temp.grug_evading,"sustained pull "..t)
end
-- Temporary pack flight cannot pause expiry or reset/heal on a fresh hit.
local flight=mob(); clock(60); flight:do_attack(a); flight.state="runaway"; flight.attack=nil; flight.health=20
clock(61); gm.received_pursuit_damage(flight,a,1); gm.leash_tick(flight,1); assert(flight.health==20)
clock(76); gm.leash_tick(flight,1); assert(flight.health==100)
clock(60)
-- Real threat validation retains a distant current target and candidate.
grug_core.add_threat(e,a,10); grug_core.add_threat(e,b,30)
grug_core.recheck_switch(e); assert(e.attack==b)
clock(74); grug_core.taunt(e,a); e:do_attack(a,true); gm.received_pursuit_damage(e,a,0)
gm.leash_tick(e,1); assert(e.attack==a)
clock(75); gm.leash_tick(e,1)
assert(not e.attack and e.health==100 and e.temp.grug_evading and not e.temp.grug_threat)
assert(not e._grug_player_tag and not e.temp.grug_damage_at)
local snapped=0
gm.walk_toward=noop
gm.place_on_ground=function(o,p) snapped=snapped+1; o.position=vector.new(p) end
clock(116); gm.leash_tick(e,1); assert(snapped==1 and not e.temp.grug_evading)
-- Reacquisition during a blocked return cannot restart the fallback deadline.
e,obj=mob(); clock(120); e:do_attack(a); obj.position.x=100
clock(135); gm.leash_tick(e,1)
local return_started=e.temp.grug_evading.started
for t=136,175 do
 clock(t); e:do_attack(a); gm.leash_tick(e,1)
 assert(e.temp.grug_evading.started==return_started)
 assert(not e.temp.grug_damage_at)
end
clock(176); e:do_attack(a); gm.leash_tick(e,1)
assert(snapped==2 and not e.temp.grug_evading)
-- Timeout also returns home inside the historical 40m radius.
e,obj=mob(); clock(200); e:do_attack(a); obj.position.x=10
clock(215); gm.leash_tick(e,1); assert(e.temp.grug_evading)
obj.position=vector.new(e._grug_home); gm.leash_tick(e,1); assert(not e.temp.grug_evading)
-- Guard input sustains a mob-vs-NPC fight without adding a player tap.
local guard=f.new_mob("test:guard","accord")
guard.entity.type="npc"; guard.entity.attack_monsters=true; guard.entity._grug_drop_rule=true
e,obj=mob(); clock(300); e:do_attack(guard)
clock(314); gm.received_pursuit_damage(e,guard,5); gm.leash_tick(e,1)
clock(328); gm.leash_tick(e,1); assert(e.attack==guard and not e._grug_player_tag)
clock(329); gm.leash_tick(e,1); assert(not e.attack)
-- Death/unavailable target cannot keep a fight alive; dead mobs never heal.
e,obj=mob(); clock(400); e:do_attack(a); a.hp=0; gm.leash_tick(e,1); assert(not e.attack); a.hp=40
e,obj=mob(); e:do_attack(a); e.health=0; gm.leash_tick(e,1); assert(e.health==0)
-- Owner-bound pull keeps its existing distance leash.
e,obj=mob(); e._grug_camp_pos={}; e._grug_leash_range=25; e:do_attack(a)
gm.leash_tick(e,1); obj.position.x=30; gm.leash_tick(e,1); assert(not e.attack)
-- Real do_states with a target beyond 45m and overlong blocked LOS survives.
e,obj=mob(); clock(500); e:do_attack(a); obj.position.x=100
function obj:get_yaw() return 0 end
function obj:get_properties() return {collisionbox={-0.3,0,-0.3,0.3,1,0.3}} end
e.water_damage=0; e.lava_damage=0; e.fire_damage=0; e.reach=3; e.attack_type="fixture"; e.target_time_lost=30; e.attack_patience=18
api_core.line_of_sight=function() return false end
e.line_of_sight=function() return false end
native.do_states(e,1); assert(e.attack==a,"distance/LOS retained")
a.hp=0; native.do_states(e,1); assert(not e.attack,"dead target dropped"); a.hp=40
-- Real vendored damage settlement: canceled, immune and zero-rounded hits
-- must not refresh; accepted player ticks and NPC hits must refresh.
e,obj=mob(); e.passive=true; e.friendly_fire=true; e.immune_to={}; e.blood_amount=0
e.texture_mods=""; e.knock_back=false; e.order=""; e.owner=""; e.runaway=false
function obj:get_armor_groups() return {fleshy=100} end
function obj:get_properties() return {collisionbox={-0.3,0,-0.3,0.3,1,0.3},damage_texture_modifier=""} end
function obj:get_velocity() return nil end
e.check_for_death=function() return false end
e._grug_drop_rule=false
local caps={full_punch_interval=1,punch_attack_uses=0,damage_groups={fleshy=2},groupcaps={}}
local stack=ItemStack(""); stack.add_wear=noop
function a:get_wielded_item() return stack end
local hitter=newproxy(true)
getmetatable(hitter).__index=function(_,key)
 local v=a[key]
 if type(v)=="function" then return function(_,...) return v(a,...) end end
 return v
end
function guard:get_wielded_item() return stack end
function guard:set_wielded_item() end
function guard:get_player_name() return "" end
grug_core.in_ability_punch=true
clock(600); native.on_punch(e,hitter,1,caps,{x=1,y=0,z=0},2)
assert(e.health==98 and e.temp.grug_damage_at==600)
clock(601); e.do_punch=function() return true end
native.on_punch(e,hitter,1,caps,{x=1,y=0,z=0},2); assert(e.temp.grug_damage_at==600)
e.do_punch=nil
clock(601.5); e.immune_to={{"all",0}}
native.on_punch(e,hitter,1,caps,{x=1,y=0,z=0},2); assert(e.temp.grug_damage_at==600)
e.immune_to={}
clock(602); caps.damage_groups.fleshy=0.2
native.on_punch(e,hitter,1,caps,{x=1,y=0,z=0},0.2); assert(e.temp.grug_damage_at==600)
clock(603); caps.damage_groups.fleshy=2
native.on_punch(e,guard,1,caps,{x=1,y=0,z=0},2); assert(e.temp.grug_damage_at==603)
clock(604); e.friendly_fire=false; e.arrow=guard.entity.name
native.on_punch(e,guard,1,caps,{x=1,y=0,z=0},2); assert(e.temp.grug_damage_at==603)
grug_core.in_ability_punch=false
-- Normal activation discards temp; a fresh pursuit obtains a fresh grace clock.
e.temp={}; clock(700); gm.start_damage_pursuit(e); assert(e.temp.grug_damage_at==700)
return "r18_evade: policy=13 sustained=60 threat=far timeout=15 home=4 fallback=40 guard=pass settlement=pass target=pass"
end
