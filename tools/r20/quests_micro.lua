local root = arg[1] or "."
local function copy(x)
 if type(x) ~= "table" then return x end
 local y = {}; for k,v in pairs(x) do y[k] = copy(v) end
 return setmetatable(y,getmetatable(x))
end
table.copy = copy
local S = {}; S.__index=S
function ItemStack(x)
 if type(x)=="table" then return copy(x) end
 local name,count = (x or ""):match("^(%S+)%s*(%d*)$")
 return setmetatable({name=name or "",count=name and (tonumber(count) or 1) or 0,meta=""},S)
end
function S:get_name() return self.count>0 and self.name or "" end
function S:get_count() return self.count end
function S:is_empty() return self.count==0 end
function S:equals(x) return self:get_name()==x:get_name() and self.count==x.count and self.meta==x.meta end
function S:take_item(n) self.count=self.count-math.min(n,self.count) end
function S:add_item(x)
 x=ItemStack(x)
 if x:is_empty() then return x end
 if self:is_empty() then self.name=x.name; self.meta=x.meta end
 if self.name==x.name and self.meta==x.meta then
 local n=math.min(99-self.count,x.count); self.count=self.count+n; x.count=x.count-n end
 return x
end
local store, players = {},{}
core={serialize=copy,deserialize=function(x) return type(x)=="table" and copy(x) or nil end,
 registered_items={["test:wood"]={},["test:gift"]={}},registered_entities={["test:boar"]={}},
 register_on_player_receive_fields=function(f) core.receive=f end,
 register_on_leaveplayer=function() end,register_entity=function(n,d) core.registered_entities[n]=d end,
 get_player_by_name=function(n) return players[n] end}
grug_quests={}
grug_inventory={BAG_COUNT=1,bag_list=function() return "bag" end,content_list=function() return "bagcontent" end,bag_slots_of=function(s) return s:is_empty() and 0 or 2 end}
grug_factions={get_faction=function(p) return p.faction end,same_faction=function() return false end}
grug_classes={get_race=function() return "human" end}
grug_xp={get_level=function(p) return p.level end,add_xp=function(p,n) p.xp=p.xp+n end}
grug_money={MAX=2147483647,get=function(p) return p.money end,add=function(p,n) p.money=p.money+n end}
grug_mobs={register_on_eligible_kill=function(f) grug_mobs.credit=f end}
grug_zones={id_at=function() return "home" end}
grug_core={settlement_socket_settlements=function() return {{key="home"}} end,
 settlement_sockets_at=function() return {{id="elder",role="quest"},{id="cook",role="quest"}} end,
 register_tag_visibility=function(f) grug_core.visibility=f end}
local function player(name)
 local p={name=name,level=1,faction="accord",xp=0,money=0,data={}}
 local inv={lists={main={ItemStack(""),ItemStack("")},bag={ItemStack("bag")},bagcontent={ItemStack(""),ItemStack("")}}}
 function inv:get_stack(l,i) return ItemStack(self.lists[l][i]) end
 function inv:get_list(l) return copy(self.lists[l]) end
 function inv:set_stack(l,i,s) if self.fail==l..i then return false end self.lists[l][i]=ItemStack(s); return true end
 function p:get_inventory() return inv end
 function p:get_player_name() return self.name end
 function p:get_meta() return {get_string=function(_,k) return p.data[k] or "" end,set_string=function(_,k,v) p.data[k]=v end} end
 players[name]=p; return p,inv
end
dofile(root.."/mods/PLAYER/grug_quests/registry.lua")
dofile(root.."/mods/PLAYER/grug_quests/state.lua")
dofile(root.."/mods/PLAYER/grug_quests/npc.lua")
local Q=grug_quests
Q.register_npc("elder",{settlement="home",socket="elder",title="Elder"})
Q.register_npc("cook",{settlement="home",socket="cook",title="Cook"})
local function quest(title, prerequisites, level)
 return {title=title,description="A local task",npc="elder",min_level=level or 1,
  prerequisites=prerequisites or {},objectives={{type="kill",mob="test:boar",count=1}},
  rewards={xp=20,copper=5}}
end
Q.register_quest("hunt",quest("Hunt"))
Q.register_quest("supply",quest("Supply"))
Q.register_quest("followup",quest("Follow-up",{"hunt"},5))
Q.register_quest("travel",{title="Meet the cook",description="Speak with the cook in town.",
 npc="elder",turnin_npc="cook",prerequisites={"hunt"},
 objectives={{type="talk",npc="cook",count=1}},rewards={xp=10,copper=2}})
Q.validate_registry()
local a=player("alice")
local function visible(p,id,npc)
 for _,row in ipairs(Q.npc_quests(p,npc or "elder")) do
  if row.id==id then return row end
 end
end
assert(visible(a,"hunt") and visible(a,"supply"))
assert(not visible(a,"followup") and not visible(a,"travel"))
assert(Q.accept(a,"hunt") and Q.accept(a,"supply"))
assert(not visible(a,"followup"),"acceptance must not reveal successors")
Q.credit_kill(a,{name="test:boar"},{x=0,z=0})
assert(Q.status(a,"hunt")=="ready" and Q.status(a,"supply")=="ready")
assert(not visible(a,"followup"),"objective completion is not turn-in")
assert(Q.turn_in(a,"hunt"))
local locked=assert(visible(a,"followup"))
assert(locked.status=="locked" and locked.reason:find("5",1,true))
assert(visible(a,"travel").status=="available")
assert(Q.accept(a,"travel"))
assert(Q.status(a,"travel")=="active")
assert(not Q.credit_conversation(a,"elder") and not Q.credit_conversation(a,"unknown"))
assert(Q.marker_state(a,"cook")=="active")
assert(Q.status(a,"travel")=="active","viewing marker must not complete travel")

-- Use the real dialog entry and receive-fields path to verify destination
-- reach, the ready update and replay-proof turn-in, not only the counter helper.
vector={distance=function(x,y)
 return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2)
end}
core.formspec_escape=function(x) return x end
core.show_formspec=function() end
core.close_formspec=function() end
grug_money.format=function(n) return tostring(n).."c" end
function a:is_player() return true end
function a:get_hp() return 20 end
function a:get_pos() return self.pos end
a.pos={x=0,y=0,z=0}
local object={valid=true,pos={x=20,y=0,z=0}}
function object:is_valid() return self.valid end
function object:get_pos() return self.pos end
local cook={object=object,_grug_start="home",_grug_socket="cook"}
assert(not Q.open_npc(a,cook))
assert(Q.status(a,"travel")=="active","remote NPC must not credit conversation")
object.pos.x=2
assert(Q.open_npc(a,cook))
assert(Q.status(a,"travel")=="ready")
assert(Q.marker_state(a,"cook")=="ready")
local row=Q.journal(a).quests
local found
for _,entry in ipairs(row) do
 if entry.id=="travel" then
  found=true
  assert(entry.objectives[1].type=="talk" and entry.objectives[1].npc=="cook")
 end
end
assert(found)
local xp,money=a.xp,a.money
object.pos.x=20
core.receive(a,"grug_quests:dialogue",{turnin=true})
assert(a.xp==xp and Q.status(a,"travel")=="ready")
object.pos.x=2
assert(Q.open_npc(a,cook))
core.receive(a,"grug_quests:dialogue",{turnin=true})
assert(Q.status(a,"travel")=="completed" and a.xp==xp+10 and a.money==money+2)
core.receive(a,"grug_quests:dialogue",{turnin=true})
assert(a.xp==xp+10 and a.money==money+2)
local saved=copy(a.data)
local reconnect=player("alice"); reconnect.data=saved
assert(Q.status(reconnect,"travel")=="completed")
local b=player("bob")
assert(not visible(b,"travel") and not visible(b,"followup"))

-- Reject combined errands disguised as travel and unknown destination IDs.
assert(not pcall(Q.register_quest,"mixed",{title="Bad",description="Bad",npc="elder",
 turnin_npc="cook",objectives={{type="talk",npc="cook",count=1},
 {type="kill",mob="test:boar",count=1}}}))
assert(not pcall(Q.register_quest,"wrong_destination",{title="Bad",description="Bad",npc="elder",
 objectives={{type="talk",npc="cook",count=1}}}))

-- Load both real presentation modules as part of the final portable fixture.
-- Dialogue/journal data above proves that the new objective carries its NPC.
sfinv={pages={},pages_unordered={},register_page=function(id,def) sfinv.pages[id]=def end,
 get_page=function() return "" end,make_formspec=function(_,_,fs) return fs end}
core.register_on_mods_loaded=function() end
core.register_on_joinplayer=function() end
core.register_on_player_inventory_action=function() end
core.register_globalstep=function() end
dofile(root.."/mods/PLAYER/grug_quests/ui.lua")
dofile(root.."/mods/PLAYER/grug_quests/hud.lua")
print("r20-quests: PASS parallel-hidden-level-lock-talk-distance-turnin-replay-persistence")
