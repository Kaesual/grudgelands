-- Bounded fixture for waiting UI and reconnect stasis; run with LuaJIT.
local repo = arg[1] or "."
local function check(value, message) assert(value, message) end
local cb, after, online, forms, holds = {}, {}, {}, {}, {}
local status = {mode="full",percent=27,ready=false,failed=false,eta_seconds=9900}
local spawn_calls, teleports, classes = 0, 0, 0
local api = {
 formspec_escape=function(s) return s end,
 show_formspec=function(name,form,text) forms[#forms+1]={name=name,form=form,text=text} end,
 close_formspec=function() end,
 register_globalstep=function(fn) cb.step=fn end,
 register_on_player_receive_fields=function(fn) cb.fields=fn end,
 register_on_joinplayer=function(fn) cb.join=fn end,
 register_on_newplayer=function(fn) cb.new=fn end,
 register_on_leaveplayer=function(fn) cb.leave=fn end,
 register_chatcommand=function() end,
 after=function(_,fn) after[#after+1]=fn end,
 get_player_by_name=function(name) return online[name] end,
 chat_send_player=function() end, colorize=function(_,s) return s end,
}
local game = {
 world_preparation_status=function() return status end,
 hold_movement=function(p) holds[p.name]=true end,
 release_movement=function(p) holds[p.name]=nil end,
 starts_ready=function() return status.ready and 6 or 0,6 end,
 starts_preload_failed=function() return status.failed end,
 register_on_preparation_progress=function(fn) cb.progress=fn end,
 request_starts_preload=function() status.failed=false end,
}
local factions = {
 get_faction=function(p) return p.faction end,
 register_on_faction_chosen=function(fn) cb.faction=fn end,
 prepare_spawn=function(_,fn) spawn_calls=spawn_calls+1; fn(nil,{x=1,y=2,z=3}); return true end,
}
local class_api = {
 get_race=function(p) return p.race end, get_class=function(p) return p.class end,
 registered_classes={warrior={id="warrior",name="Warrior"}}, class_ids={"warrior"},
 get_class_def=function() return {id="warrior",name="Warrior"} end,
 set_class=function(p,id) classes=classes+1;p.class=id;return true end,
}
local env=setmetatable({core=api,grug_core=game,grug_classes=class_api,
 grug_factions=factions},{__index=_G})
local loader=assert(loadfile(repo.."/mods/PLAYER/grug_classes/selection.lua"))
setfenv(loader,env);loader()
local function drain()
 while #after>0 do local queue=after;after={} for _,fn in ipairs(queue) do fn() end end
end
local function player(name,complete)
 local p={name=name,faction="accord",race="human",class=complete and "warrior" or nil,
 armor={fleshy=100},pos={x=900,y=20,z=800}}
 function p:get_player_name() return self.name end
 function p:get_velocity() return {x=0,y=0,z=0} end
 function p:add_velocity() end
 function p:get_armor_groups() return self.armor end
 function p:set_armor_groups(a) self.armor=a end
 function p:set_pos(pos) self.pos=pos;teleports=teleports+1 end
 function p:get_hp() return 20 end
 online[name]=p;return p
end
local veteran=player("returning",true)
cb.join(veteran);drain()
check(holds.returning and veteran.armor.immortal==1,"reconnect is held")
check(forms[#forms].text:find("Preparing the world: 27%%"),"full progress")
check(forms[#forms].text:find("2h 45m",1,true),"ETA")
local count=#forms;cb.progress();check(#forms==count,"unchanged progress sends no packet")
status.percent=28;cb.progress();check(#forms==count+1,"changed progress updates")
cb.fields(veteran,"grug_classes:loading",{quit=true});drain()
check(#forms==count+2,"closed form reopens")
cb.leave(veteran);veteran=player("returning",true);cb.join(veteran);drain()
status.ready=true;status.percent=100;cb.progress()
check(not holds.returning and veteran.armor.immortal==nil,"release restores armor")
check(teleports==0 and classes==0 and spawn_calls==0,"reconnect preserves position/identity")
check(not game.player_in_creation_stasis("returning"),"session removed")
local count2=#forms;cb.join(veteran);drain();check(#forms==count2,"ready reconnect ungated")
status={mode="starts",percent=0,ready=false,failed=false}
local novice=player("new",false);cb.new(novice);cb.join(novice);drain()
check(forms[#forms].form=="grug_classes:class","identity selection stays available")
cb.progress();check(forms[#forms].form=="grug_classes:class","progress does not replace selection")
cb.fields(novice,"grug_classes:class",{choose_warrior=true})
check(not novice.class and forms[#forms].text:find("starting areas",1,true),"creation waits on starts")
check(forms[#forms].text:find("Estimating",1,true),"ETA unknown")
status.failed=true;cb.progress();check(forms[#forms].text:find("Try again",1,true),"failure UI")
cb.fields(novice,"grug_classes:loading",{retry_spawn=true})
status.ready=true;status.percent=100;cb.progress();drain()
check(novice.class=="warrior" and classes==1 and teleports==1 and spawn_calls==1,"new creation commits once")
check(not holds.new and novice.armor.immortal==nil,"creation releases")
cb.progress();check(teleports==1 and classes==1,"later progress idempotent")
print("r14-selection: reconnect=preserved stasis=ok progress=deduplicated creation=once retry=ok")
