-- Final-only, isolated fixture for Round 20 combat presentation and reset audit.
return function(repo)
 local function noop() end
 local now, particles, defs = 0, {}, {}
 local env = setmetatable({}, {__index = _G})
 env._G = env
 env.vector = {
  new=function(x,y,z) return {x=x,y=y,z=z} end,
  offset=function(p,x,y,z) return {x=p.x+x,y=p.y+y,z=p.z+z} end,
  distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end,
 }
 env.core = {
  is_player=function(p) return p and p.player == true end,
  register_on_dieplayer=noop, register_on_joinplayer=noop,
  register_on_leaveplayer=noop, register_globalstep=noop,
  get_mod_storage=function() return {} end,
  get_modpath=function() return "unloaded" end,
  get_current_modname=function() return "grug_mobs" end,
  add_particlespawner=function(spec) particles[#particles+1]=spec end,
 }
 env.grug_core = {mono_time=function() return now end,
  zone_authority_installed=function() return true end, register_on_effective_heal=noop,
  clear_threat=function(s) s.temp.grug_threat=nil end, recheck_switch=noop}
 env.mobs = {mob_class={}, spawn=noop}
 env.dofile=function() env.grug_mobs.install_spawn_clock_wrapper=noop end
 local function load(path)
  local fn=assert(loadfile(repo.."/"..path)); setfenv(fn,env)(); return fn
 end
 load("mods/CORE/grug_core/movement.lua")
 load("mods/ENTITIES/grug_mobs/init.lua")
 local gm, gc = env.grug_mobs, env.grug_core
 local function object(player)
  local o={player=player, pos={x=0,y=0,z=0}, hp=100}
  function o:get_pos() return self.pos end
  function o:get_hp() return self.hp end
  function o:get_player_name() return "test" end
  function o:get_properties() return {collisionbox={-0.3,0,-0.3,0.3,1.7,0.3}} end
  function o:get_velocity() return {x=0,y=0,z=0} end
  function o:set_velocity(v) self.velocity=v end
  function o:set_physics_override(v) self.physics=v end
  return o
 end
 local player=object(true)
 assert(gc.set_stun(player,1.5) and gc.is_stunned(player))
 assert(#particles==1 and particles[1].amount==8 and particles[1].exptime.max==1.5)
 assert(particles[1].pos.min.y>1.7 and player.physics.speed_walk==0)
 player.hp=0; assert(not gc.set_stun(player,1.5) and #particles==1); player.hp=100
 local function actor()
  return {object=object(false),health=40,hp_max=100,state="stand",temp={},
   walk_velocity=1,run_velocity=4.6,stop_attack=function(s) s.attack=nil; s.state="stand" end,
   update_tag=noop}
 end
 local guard=actor()
 assert(gm.stun(guard,1.5) and #particles==2 and guard.run_velocity==0)
 guard._grug_boss_id="king:test"
 assert(not gm.stun(guard,1.5) and #particles==2)
 guard._grug_boss_id=nil; guard.health=0
 assert(not gm.stun(guard,1.5) and #particles==2)
 -- Real shared crab builder, both normal and elite presentations.
 gm.register_mob=function(name,def) defs[name]=def end; gm.passive_prey=noop
 load("mods/ENTITIES/grug_mobs/shore_crab.lua")
 for _,id in ipairs({"grug_mobs:shore_crab","grug_mobs:reef_lurker"}) do
  assert(not defs[id].animation.die_start and #defs[id].drops==2)
 end
 -- Audit the actual camp definition: no bandit self-heal/custom spell.
 load("mods/ENTITIES/grug_mobs/bandit.lua")
 local bandit=assert(defs["grug_mobs:bandit"])
 assert(bandit._grug_leash_range==25 and not bandit.do_custom)
 load("mods/ENTITIES/grug_mobs/aggro.lua")
 load("mods/ENTITIES/grug_mobs/idle_health.lua")
 local camp=actor()
 camp._grug_camp_pos={x=0,y=0,z=0}; camp._grug_home={x=0,y=0,z=0}
 camp._grug_leash_range=25; camp.attack=player; camp.state="attack"
 gm.walk_toward=noop
 -- Sustained incoming contact inside the post bounds never heals.
 for t=0,60 do
  now=t; camp.temp.grug_last_contact=t
  gm.leash_tick(camp,1)
  assert(camp.health==40)
 end
 -- A transient missing target starts quiet time, never an instant reset.
 camp.attack=nil; camp.state="stand"
 for t=61,70 do now=t; gm.leash_tick(camp,1); assert(camp.health==40) end
 camp.attack=player; camp.state="attack"; camp.temp.grug_last_contact=71
 now=71; gm.leash_tick(camp,1); assert(camp.health==40)
 -- Confirmed movement outside the preserved camp leash really resets.
 camp.object.pos.x=26; now=72; camp.temp.grug_last_contact=72
 gm.leash_tick(camp,1); assert(camp.health==100 and camp.temp.grug_evading)
 -- Targetless damage and death cannot be mistaken for a quiet heal.
 local idle=actor(); now=100; gm.idle_health_tick(idle)
 for t=110,150,10 do now=t; idle.health=idle.health-1; assert(not gm.idle_health_tick(idle)) end
 now=179; assert(not gm.idle_health_tick(idle))
 now=180; assert(gm.idle_health_tick(idle) and idle.health==100)
 idle.health=0; idle.state="die"; now=220; assert(not gm.idle_health_tick(idle))
 return "r20-combat:accepted-stun+crab+live-camp+quiet-reset:PASS"
end
