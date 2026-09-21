-- Production fishing callbacks: finite bite window, cleanup and callback wear.
local repo = arg[1] or "."
local cb, players, entities, notifications, drops = {}, {}, {}, {}, 0
local water = true
local items = {['grug_mobs:raw_fish']={description='Raw Fish'}}
local function stack(name, wear)
 local s={name=name or '',wear=wear or 0}
 function s:get_name() return self.name end
 function s:is_empty() return self.name=='' end
 function s:add_wear(n) self.wear=self.wear+n end
 return s
end
local api={registered_items=items}
function api.get_current_modname() return 'grug_fishing' end
function api.get_modpath() return repo..'/mods/ITEMS/grug_fishing' end
function api.register_tool(n,d) items[n]=d end
function api.register_craftitem(n,d) items[n]=d end
function api.register_craft() end
function api.register_entity(n,d) cb.entity=d end
function api.register_globalstep(fn) cb.step=fn end
function api.register_on_leaveplayer(fn) cb.leave=fn end
function api.register_on_dieplayer(fn) cb.die=fn end
function api.register_on_shutdown(fn) cb.shutdown=fn end
function api.register_on_mods_loaded(fn) cb.loaded=fn end
function api.item_eat() return function() end end
function api.sound_play() end
function api.get_node() return {name=water and 'water' or 'air'} end
function api.get_item_group(n,g)
 if g=='water' and n=='water' then return 1 end
 return ((items[n] or {}).groups or {})[g] or 0
end
function api.get_player_by_name(n) return players[n] end
function api.add_item() drops=drops+1 end
function api.add_entity(pos)
 local object={pos=pos,live=true}
 function object:is_valid() return self.live end
 function object:remove() self.live=false end
 function object:move_to(p) self.pos=p end
 entities[#entities+1]=object;return object
end
local env=setmetatable({core=api,mobs={add_eatable=function() end},
 grug_core={mob_level_at=function() return 1 end},
 grug_abilities={notify=function(p,s) notifications[#notifications+1]=p.name..':'..s end},
 PcgRandom=function() return {next=function() return 0 end} end,
 ItemStack=function(s) return stack((s:match('^([^ ]+)'))) end,
 vector={distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end},
},{__index=_G})
local function load(path) local fn=assert(loadfile(path));setfenv(fn,env);return fn() end
env.dofile=load
load(repo..'/mods/ITEMS/grug_fishing/init.lua')
local function player(name)
 local p={name=name,pos={x=0,y=1,z=0},rod=stack('grug_fishing:rod'),caught=0,hp=20}
 function p:get_player_name() return self.name end
 function p:is_player() return true end
 function p:get_pos() return self.pos end
 function p:get_hp() return self.hp end
 function p:get_wielded_item() return stack(self.rod.name,self.rod.wear) end
 function p:get_inventory() return {add_item=function(_,_,s)
  if self.full then return s end self.caught=self.caught+1;return stack('') end} end
 players[name]=p;return p
end
local rod=items['grug_fishing:rod']
local function click(p,point)
 p.rod=rod.on_place(p:get_wielded_item(),p,point)
end
local target={type='node',under={x=1,y=0,z=0}}
local a,b=player('a'),player('b')
click(a,target);local first=entities[#entities]
assert(first.live and a.caught==0)
cb.step(3);assert(a.caught==0 and first.pos.y<0.5,'bite only signals')
click(a);assert(a.caught==1 and a.rod.wear>0 and not first.live,'reel commits returned wear')
assert(notifications[1]=='a:Caught: Raw Fish','focused HUD catch')
click(a);assert(a.caught==1,'repeat cannot claim')
local wear=a.rod.wear
click(a,target);click(a);assert(a.caught==1 and a.rod.wear==wear,'early reel free')
click(a,target);cb.step(3);cb.step(1.5)
assert(a.caught==1 and entities[#entities].live,'missed bite stays cast')
cb.step(3);click(a);assert(a.caught==2,'next bite can be caught')
click(a,target);click(b,target);cb.step(3)
click(a);click(b);assert(a.caught==3 and b.caught==1,'independent anglers')
a.full=true;click(a,target);cb.step(3);click(a);assert(drops==1,'full inventory retains catch as drop')
a.full=false
click(a,target);a.pos.x=30;cb.step(0.2);assert(not entities[#entities].live,'range cleanup');a.pos.x=0
click(a,target);a.rod=stack('');cb.step(0.2);assert(not entities[#entities].live,'wield cleanup');a.rod=stack('grug_fishing:rod')
click(a,target);water=false;cb.step(0.2);assert(not entities[#entities].live,'water cleanup');water=true
click(a,target);cb.leave(a);assert(not entities[#entities].live,'leave cleanup')
click(a,target);cb.die(a);assert(not entities[#entities].live,'death cleanup')
click(a,target);cb.shutdown();assert(not entities[#entities].live,'shutdown cleanup')
local count=#entities
click(a,{type='node',under={x=99,y=0,z=0}});assert(#entities==count,'range checked before cast')
-- Actual neutral HUD token behavior, extracted as one original source function
-- plus its public binding, rather than reimplementing the expiry algorithm.
local fh=assert(io.open(repo..'/mods/PLAYER/grug_abilities/init.lua','r'))
local source=fh:read('*a');fh:close()
local body=assert(source:match('(local function show_skill_name.-grug_abilities.notify = show_skill_name)'))
local timers, hud = {}, {token=0,id=7}
local output=''
function a:hud_change(_,_,s) output=s end
local notify_env=setmetatable({grug_abilities={},skillname_huds={a=hud},core={
 after=function(_,fn) timers[#timers+1]=fn end,get_player_by_name=function() return a end}}, {__index=_G})
local fn=assert(loadstring(body));setfenv(fn,notify_env);fn()
notify_env.grug_abilities.notify(a,'first');notify_env.grug_abilities.notify(a,'Caught: Raw Fish')
timers[1]();assert(output=='Caught: Raw Fish','stale expiry preserves newer message')
timers[2]();assert(output=='','newest message expires')
print('r14-fishing: bite-window=ok manual-reel=once catch-wear=returned multiplayer=ok cleanup=ok hud-token=ok')
