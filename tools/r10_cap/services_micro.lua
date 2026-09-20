-- Compact real callback fixture; no whole-capital population or engine needed.
return function(repo)
 local names={"core","grug_mounts","grug_mobs","grug_core","grug_factions",
  "grug_xp","grug_money","grug_gear","mobs"}
 local saved={};for _,n in ipairs(names) do saved[n]=rawget(_G,n) end
 local ok,result=pcall(function()
  local fields,leave,death,definitions,nodes={},nil,nil,{},{}
  local shown,purchases,roles={},0,{}
  local pos={x=0,y=1,z=0}
  local npcpos={x=0,y=1,z=0}
  local player={faction="accord",hp=100,level=60}
  function player:is_player() return true end
  function player:get_player_name() return "tester" end
  function player:get_pos() return pos end
  function player:get_hp() return self.hp end
  core={formspec_escape=function(s) return s end,
   register_on_player_receive_fields=function(fn) fields[#fields+1]=fn end,
   register_on_leaveplayer=function(fn) leave=fn end,
   register_on_dieplayer=function(fn) death=fn end,
   show_formspec=function(_,form,text) shown={form,text} end,
   chat_send_player=function() end,
   register_entity=function(n,d) definitions[n]=d end,
   register_node=function(n,d) nodes[n]=d end,
   register_globalstep=function() end,register_on_mods_loaded=function() end,
   log=function() end,
   registered_items={['real:sword']={},['real:chest']={},['real:jewel']={}},
   serialize=function(t) return t end,deserialize=function(t) return t end}
  grug_core={settlement_sockets_at=function(key)
   if key~="highcourt" then return {} end
   return {{id="stable/riding",role="riding_trainer",pos={x=0,y=1,z=0}}}
  end}
  grug_factions={get_faction=function(p) return p.faction end}
  grug_xp={get_level=function(p) return p.level end}
  grug_money={format=tostring}
  grug_mounts={TIERS={},price_for_tier=function() return 10 end,
   owns_tier=function() return false end,
   purchase=function(_,tier) purchases=purchases+1;return true,tostring(tier) end}
  for i=1,4 do grug_mounts.TIERS[i]={name="Tier"..i,level=i*15} end
  local claims,deactivations=0,0
  grug_mobs={storage={}}
  mobs={mob_class={},remove=function() error('display used mob removal') end}
  dofile(repo..'/mods/ENTITIES/grug_mobs/start_npcs.lua')
  local register=grug_mobs.register_start_socket_role
  grug_mobs.register_start_socket_role=function(role,fn) roles[role]=fn;register(role,fn) end
  local claim=grug_mobs.start_npc_claim
  grug_mobs.start_npc_claim=function(ent) claims=claims+1;return claim(ent) end
  local deactivate=grug_mobs.start_npc_deactivate
  grug_mobs.start_npc_deactivate=function(ent,removal)
   deactivations=deactivations+1;return deactivate(ent,removal)
  end
  local npc={_grug_start="highcourt",_grug_socket="stable/riding",
   _grug_socket_role="riding_trainer",object={get_pos=function() return npcpos end}}
  dofile(repo..'/mods/PLAYER/grug_mounts/trainer.lua')
  assert(grug_mounts.trainer_hook==nil and roles.riding_trainer)
  assert(grug_mounts.open_trainer(player,npc));local first=shown[1]
  assert(fields[1](player,first,{buy_1=true}));assert(purchases==1)
  fields[1](player,first,{buy_1=true,buy_2=true});assert(purchases==1)
  assert(grug_mounts.open_trainer(player,npc));local second=shown[1]
  fields[1](player,first,{buy_1=true});assert(purchases==1)
  pos={x=9,y=1,z=0};fields[1](player,second,{buy_1=true});assert(purchases==1)
  pos={x=0,y=1,z=0};player.faction="throng"
  assert(not grug_mounts.open_trainer(player,npc));player.faction="accord"
  npc._grug_start="dawnmere";assert(not grug_mounts.open_trainer(player,npc))
  npc._grug_start="highcourt";assert(grug_mounts.open_trainer(player,npc))
  fields[1](player,shown[1],{quit=true,buy_1=true});assert(purchases==1)
  assert(grug_mounts.open_trainer(player,npc));leave(player)
  fields[1](player,shown[1],{buy_1=true});assert(purchases==1)
  assert(grug_mounts.open_trainer(player,npc));death(player)
  fields[1](player,shown[1],{buy_1=true});assert(purchases==1)
  npcpos={x=4,y=1,z=0};assert(not grug_mounts.open_trainer(player,npc))
  npcpos={x=0,y=1,z=0};npc._grug_socket="forged"
  assert(not grug_mounts.open_trainer(player,npc))
  dofile(repo..'/mods/ITEMS/grug_decor/capital.lua')
  local count=0
  for _,d in pairs(nodes) do
   assert(d.drop=="" and d.diggable==false and not d.can_dig())
   assert(#d.on_blast()==0 and d.allow_metadata_inventory_take()==0 and
    d.allow_metadata_inventory_put()==0 and d.allow_metadata_inventory_move()==0)
   d.on_dig();d.on_punch();d.on_rightclick()
   for k in pairs(d.groups) do assert(k=="not_in_creative_inventory") end
   assert(not d.on_timer and not d.liquidtype);count=count+1
  end
  grug_gear={weapon_item=function() return 'real:sword' end,
   armor_item=function() return 'real:chest' end,
   trinket_item=function() return 'real:jewel' end}
  -- Load the actual appearance catalog; model selection uses the real twelve
  -- existing meshes/textures and exact race/tier mapping.
  dofile(repo..'/mods/PLAYER/grug_mounts/catalog.lua')
  dofile(repo..'/mods/ENTITIES/grug_mobs/capital_displays.lua')
  local def=assert(definitions['grug_mobs:capital_display'])
  assert(not def.on_step and not def.initial_properties.physical and
   not def.initial_properties.pointable)
  local appearances=0
  for _,race in ipairs({'human','dwarf','elf','orc','undead','troll'}) do
   for tier=1,4 do
    local props={};local animation
    local obj={set_properties=function(_,p) props=p end,
     set_armor_groups=function(_,a) assert(a.immortal==1) end,
     set_yaw=function() end,set_animation=function(_,a) animation=a end,
     get_pos=function(self) return not self.removed and {x=0,y=0,z=0} or nil end,
     remove=function(self) self.removed=true end}
    local ent=setmetatable({object=obj,_grug_socket_role='mount_display',
     _grug_display_race=race,_grug_display_tag=tostring(tier),
     _grug_start='highcourt',_grug_socket=race..'_mount'..tier,_grug_placed_at=1},
     {__index=def})
    grug_mobs.configure_capital_display(ent)
    assert(props.visual=='mesh' and props.mesh and #props.textures>0)
    assert(animation.x==animation.y)
    local snapshot=ent:get_staticdata();local restored=setmetatable({object=obj},{__index=def})
    restored:on_activate(snapshot)
    assert(restored._grug_display_tag==tostring(tier))
    local duplicate_obj={get_pos=obj.get_pos,remove=obj.remove,
     set_armor_groups=function() end}
    local duplicate=setmetatable({object=duplicate_obj},{__index=def})
    local duplicate_data={};for k,v in pairs(snapshot) do duplicate_data[k]=v end
    duplicate_data._grug_placed_at=2
    duplicate:on_activate(duplicate_data)
    assert(duplicate_obj.removed and not obj.removed,'display duplicate lease differs')
    restored:on_deactivate(false);assert(restored:on_punch()==true)
    restored:on_rightclick();restored:on_death();appearances=appearances+1
   end
  end
  for _,tag in ipairs({'weapon','armor','jewel'}) do
   local props
   local object={set_properties=function(_,p) props=p end,
    set_armor_groups=function() end,set_yaw=function() end,
    get_pos=function() return {x=0,y=0,z=0} end,remove=function() error('gear removed') end}
   local entity=setmetatable({object=object,_grug_socket_role='gear_display',
    _grug_display_tag=tag,_grug_start='highcourt',_grug_socket='gear_'..tag,
    _grug_placed_at=1},{__index=def})
   entity:on_activate(entity:get_staticdata())
   assert(props.visual=='wielditem' and core.registered_items[props.textures[1]])
   entity:on_deactivate(false)
  end
  local removed=false
  local malformed=setmetatable({object={set_armor_groups=function() end,
   remove=function() removed=true end}},{__index=def})
  malformed:on_activate({_grug_start='highcourt',_grug_socket='bad',
   _grug_placed_at=1,_grug_socket_role='mount_display',_grug_display_tag='5'})
  assert(removed)
  assert(claims==51 and deactivations==27)
  return 'cap_riding_acl\tPASS\ncap_inert_nodes\t'..count..
   '\ncap_display_reload\t'..appearances..'\n'
 end)
 for _,n in ipairs(names) do rawset(_G,n,saved[n]) end
 if not ok then error(result,0) end
 return result
end
