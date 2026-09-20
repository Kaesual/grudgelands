return function(repo)
 local defs, allow, changed = {}, {}, {}
 local messages, clock = {}, 1000000
 local Stack={}; Stack.__index=Stack
 function Stack:new(v) local n,c="",0;if type(v)=="string" then n,c=v:match("^(%S+)%s*(%d*)$");c=tonumber(c)or(n~=""and 1 or 0)elseif type(v)=="table" then n,c=v.n,v.c end;return setmetatable({n=n or"",c=c or 0},self)end
 function Stack:is_empty()return self.n==""or self.c==0 end
 function Stack:get_name()return self.n end
 function Stack:get_count()return self.c end
 function Stack:get_stack_max()return(defs[self.n]or{}).stack_max or 99 end
 function Stack:take_item(n)n=math.min(n,self.c);self.c=self.c-n;if self.c==0 then self.n=""end;return n end
 function Stack:get_definition()return defs[self.n]or{}end
 _G.ItemStack=function(v)return Stack:new(v)end
 _G.core={registered_items=defs,register_craftitem=function(n,d)defs[n]=d end,get_item_group=function(n,g)return((defs[n]or{}).groups or{})[g]or 0 end,register_on_joinplayer=function()end,register_on_leaveplayer=function()end,get_us_time=function()return clock end,chat_send_player=function(_,text)messages[#messages+1]=text end,register_allow_player_inventory_action=function(f)allow[#allow+1]=f end,register_on_player_inventory_action=function(f)changed[#changed+1]=f end}
 _G.grug_inventory={refresh=function()end}
 defs["grug_gear:arrow"]={stack_max=99,groups={grug_arrow=1}}
 dofile(repo.."/mods/PLAYER/grug_inventory/bags.lua")
 local Inv={};Inv.__index=Inv
 function Inv:new()return setmetatable({lists={main={},grug_offhand={ItemStack("grug_inventory:quiver")},grug_quiver_content={ItemStack("grug_gear:arrow 3"),ItemStack("grug_gear:arrow 2")}}},self)end
 function Inv:get_list(n)return self.lists[n]or{}end
 function Inv:get_stack(n,i)return ItemStack((self.lists[n]or{})[i]or"")end
 function Inv:set_stack(n,i,s)self.lists[n]=self.lists[n]or{};self.lists[n][i]=ItemStack(s)end
 function Inv:is_empty(n)for _,s in ipairs(self:get_list(n))do if not s:is_empty()then return false end end return true end
 function Inv:add_item(n,s)local list=self.lists[n];local left=ItemStack(s);for i=1,8 do local x=list[i]or ItemStack("");if x:is_empty()then list[i]=ItemStack(left);return ItemStack("")elseif x:get_name()==left:get_name()then local k=math.min(99-x.c,left.c);x.c=x.c+k;left.c=left.c-k;list[i]=x;if left.c==0 then return ItemStack("")end end end;return left end
 local inv=Inv:new();for i=1,8 do inv.lists.main[i]=ItemStack("")end
 local player={get_inventory=function()return inv end,get_player_name=function()return "archer" end}
 assert(grug_inventory.ammo_count(player)==5)
 assert(grug_inventory.consume_ammo(player,4)and grug_inventory.ammo_count(player)==1)
 inv.lists.main[1]=ItemStack("grug_gear:arrow 3")
 assert(grug_inventory.consume_ammo(player,3)and grug_inventory.ammo_count(player)==1)
 inv.lists.grug_quiver_content={ItemStack("grug_gear:arrow 40"),ItemStack("grug_gear:arrow 70")}
 local info={from_list="grug_offhand",from_index=1,to_list="main",to_index=2,count=1}
 assert(allow[1](player,"move",inv,info)==nil)
 inv.lists.main[2]=ItemStack("grug_inventory:quiver");inv.lists.grug_offhand[1]=ItemStack("")
 changed[1](player,"move",inv,info)
 assert(inv:is_empty("grug_quiver_content")and grug_inventory.ammo_count(player)==111)
 -- Full main inventory leaves every list untouched, including offhand.
 inv=Inv:new()
 for i=1,8 do inv.lists.main[i]=ItemStack("grug_gear:arrow 99")end
 local function snapshot()
  local rows={}
  for _,name in ipairs({"main","grug_offhand","grug_quiver_content"})do
   for i,stack in ipairs(inv:get_list(name))do rows[#rows+1]=name..":"..i..":"..stack:get_name()..":"..stack:get_count()end
  end
  return table.concat(rows,"|")
 end
 local before=snapshot()
 assert(allow[1](player,"move",inv,info)==0 and snapshot()==before)
 assert(#messages==1 and messages[1]:find("all arrows",1,true))
 assert(allow[1](player,"move",inv,info)==0 and #messages==1 and snapshot()==before)
 clock=clock+2000000
 assert(allow[1](player,"take",inv,{listname="grug_offhand",stack=ItemStack("grug_inventory:quiver")})==0)
 assert(#messages==2 and snapshot()==before)
 return "ammo\tquiver-first\tmain-fallback\tfilled-transfer\tfull-main-atomic-refusal\tthrottled-message\n"
end
