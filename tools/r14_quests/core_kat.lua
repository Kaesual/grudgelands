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
 settlement_sockets_at=function() return {{id="elder",role="quest"}} end,
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
Q.register_npc("elder",{settlement="home",socket="elder"})
local function def(objectives) return {title="Test",description="Bring wood",npc="elder",faction="accord",objectives=objectives,rewards={xp=20,copper=5,items={"test:gift 2"}}} end
Q.register_quest("first",def({{type="kill",mob="test:boar",count=2,zone="home"},{type="item",item="test:wood",count=3}}))
Q.validate_registry()
local a,inv=player("a")
assert(Q.accept(a,"first")); assert(not Q.accept(a,"first"))
inv.lists.main[1]=ItemStack("test:wood 1"); inv.lists.bagcontent[1]=ItemStack("test:wood 2")
Q.credit_kill(a,{name="test:boar"},{x=0,z=0}); assert(Q.status(a,"first")=="active")
Q.credit_kill(a,{name="test:boar"},{x=0,z=0}); assert(Q.status(a,"first")=="ready")
assert(Q.marker_state(a,"elder")=="ready")
-- Live item loss changes readiness with no quest mutation.
inv.lists.bagcontent[1]=ItemStack(""); assert(Q.status(a,"first")=="active")
assert(not Q.turn_in(a,"first")); inv.lists.bagcontent[1]=ItemStack("test:wood 2")
assert(Q.turn_in(a,"first")); assert(a.xp==20 and a.money==5)
assert(not Q.turn_in(a,"first")); assert(Q.status(a,"first")=="completed")
local gifts=0; for _,l in ipairs({"main","bagcontent"}) do for _,s in ipairs(inv.lists[l]) do if s:get_name()=="test:gift" then gifts=gifts+s:get_count() end end end
assert(gifts==2)
Q.register_quest("full",def({{type="kill",mob="test:boar",count=1}}))
assert(Q.accept(a,"full")); Q.credit_kill(a,{name="test:boar"},{x=0,z=0})
for _,l in ipairs({"main","bagcontent"}) do for i=1,2 do inv.lists[l][i]=ItemStack("test:wood 99") end end
assert(not Q.turn_in(a,"full")); assert(a.xp==20)
assert(Q.abandon(a,"full")); assert(inv.lists.main[1]:get_count()==99)
assert(Q.accept(a,"full")); assert(Q.status(a,"full")=="active")
for i=1,20 do Q.register_quest("slot"..i,def({{type="kill",mob="test:boar",count=1}})) end
for i=1,19 do assert(Q.accept(a,"slot"..i)) end
assert(not Q.accept(a,"slot20")); assert(#Q.journal(a).quests==20)
assert(#Q.journal(a).tracked==3)
Q.set_hud_enabled(a,false); assert(not Q.journal(a).hud_enabled)
assert(Q.abandon(a,"slot1")); assert(Q.accept(a,"slot20"))
-- A second player has independent counters, money and one-time claims.
local b=player("b"); assert(Q.accept(b,"first")); assert(Q.status(b,"first")=="active")
assert(b.money==0 and b.xp==0)
-- Roll back earlier slot writes if an engine inventory write refuses.
local c,ci=player("c")
Q.register_quest("rollback",def({{type="item",item="test:wood",count=2}}))
assert(Q.accept(c,"rollback"))
ci.lists.main[1]=ItemStack("test:wood");ci.lists.main[2]=ItemStack("test:wood")
ci.fail="main2"
assert(not Q.turn_in(c,"rollback"));assert(ci.lists.main[1]:get_name()=="test:wood")
assert(c.money==0 and Q.status(c,"rollback")=="ready")
ci.fail=nil
local add=grug_money.add
local reentry=false
grug_money.add=function(p,n) add(p,n);reentry=Q.turn_in(p,"rollback") end
assert(Q.turn_in(c,"rollback"));assert(not reentry and c.money==5 and c.xp==20)
grug_money.add=add
local gated=def({{type="kill",mob="test:boar",count=1}})
gated.min_level=5;gated.prerequisites={"first"}
Q.register_quest("gated",gated)
assert(not Q.accept(b,"gated"))
-- Persisted player metadata is the sole authority after a simulated reconnect.
local saved=copy(c.data)
local reconnect=player("c");reconnect.data=saved
assert(Q.status(reconnect,"rollback")=="completed")
print("r14-quests-core: PASS bag hand-in, live readiness, one-time claim, reward space, abandon/reset, 20 slots, HUD persistence, player isolation")
