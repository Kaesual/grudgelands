local root = arg[1] or "."
local players, events, heal = {}, {}, nil
local env = setmetatable({}, {__index = _G})
env.core = {is_player=function(p) return p and p:is_player() end,get_mod_storage=function() return {} end,
 get_modpath=function() return "roster" end,get_current_modname=function() return "grug_mobs" end,
 get_player_by_name=function(name) return players[name] end,
 chat_send_player=function() end,colorize=function(_,text) return text end}
env.mobs = {mob_class={}}
env.grug_core = {zone_authority_installed=function() return true end,
 register_on_effective_heal=function(callback) heal=callback end}
env.grug_factions = {same_faction=function() return false end}
env.grug_xp = {get_level=function(p) return p.level end,add_xp=function(p,xp) p.xp=p.xp+xp end}
env.dofile = function() env.grug_mobs.install_spawn_clock_wrapper=function() end end
local chunk=assert(loadfile(root.."/mods/ENTITIES/grug_mobs/init.lua")); setfenv(chunk,env); chunk()
local api=env.grug_mobs
api.kill_xp=function() return 20 end
local function player(name,x,level)
 local p={xp=0,level=level or 1}
 function p:is_player() return true end
 function p:get_player_name() return name end
 function p:get_pos() return {x=x,y=0,z=0} end
 players[name]=p; return p
end
local damage=player("damage",0)
local healer=player("healer",40)
local gray=player("gray",0,20)
local far=player("far",40.01)
local mob={name="test:mob",_grug_level=1,health=10}
mob.object={get_pos=function() return {x=0,y=0,z=0} end,get_luaentity=function() return mob end}
api.register_on_eligible_kill(function(p,entity,pos)
 assert(entity.temp.grug_xp_participants, "event must precede cleanup")
 events[#events+1]=p:get_player_name(); assert(pos.x==0)
end)
api.mark_xp_participant(mob,damage)
heal(healer,damage,0); assert(not mob.temp.grug_xp_participants.healer)
heal(healer,damage,1); assert(mob.temp.grug_xp_participants.healer)
api.mark_xp_participant(mob,gray); api.mark_xp_participant(mob,far)
assert(api.award_kill_xp(mob)); assert(not api.award_kill_xp(mob))
assert(table.concat(events,",")=="damage,gray,healer")
assert(damage.xp==6 and healer.xp==6 and gray.xp==0 and far.xp==0)
assert(not mob.temp.grug_xp_participants)
print("r14-quests-participation: PASS damage/effective-heal, exact 40m, gray event, unchanged split, once-before-cleanup")
