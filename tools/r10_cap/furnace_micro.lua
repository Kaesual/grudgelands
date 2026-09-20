-- Real default furnace + profession extraction chain at an authored public socket.
return function(repo)
 local globals={'core','default','ItemStack','grug_jobs','grug_core','grug_brewing',
  'grug_items','grug_xp','vector'}
 local saved={};for _,n in ipairs(globals) do saved[n]=rawget(_G,n) end
 local ok,result=pcall(function()
  ItemStack=function(value)
   if type(value)=='table' then value=value:to_string() end
   local text=tostring(value or '');local name=text:match('^(%S+)') or ''
   local count=tonumber(text:match(' (%d+)$')) or (name=='' and 0 or 1)
   local s={}
   function s:get_name() return name end
   function s:get_count() return count end
   function s:to_string() return name=='' and '' or name..' '..count end
   function s:is_empty() return count==0 end
   function s:take_item(n) count=math.max(0,count-(n or 1));if count==0 then name='' end;return self end
   return s
  end
  local function meta()
   local values,lists={},{};local inv={}
   function inv:get_size(n) return #(lists[n] or {}) end
   function inv:set_size(n,size) lists[n]={};for i=1,size do lists[n][i]=ItemStack('') end end
   function inv:get_list(n) return lists[n] end
   function inv:get_stack(n,i) return ItemStack((lists[n] or {})[i]) end
   function inv:set_stack(n,i,s) lists[n][i]=ItemStack(s) end
   function inv:is_empty(n) for _,s in ipairs(lists[n] or {}) do if not s:is_empty() then return false end end;return true end
   function inv:room_for_item() return true end
   function inv:add_item(n,s) if not ItemStack(s):is_empty() then self:set_stack(n,1,s) end;return ItemStack('') end
   local m={get_inventory=function() return inv end}
   function m:get_string(k) return tostring(values[k] or '') end
   function m:set_string(k,v) values[k]=v end
   function m:get_int(k) return tonumber(values[k]) or 0 end
   function m:set_int(k,v) values[k]=v end
   m.get_float=m.get_int;m.set_float=m.set_int
   return m
  end
  local at={x=10,y=20,z=30};local position={x=10,y=20,z=30}
  local node_name='default:furnace';local metadata=meta();local lbms,loaded={},{}
  local timer_starts=0;local protected=true
  core={registered_nodes={},registered_items={},registered_craft_predicts={},registered_on_crafts={},
   get_meta=function() return metadata end,
   get_node=function() return {name=node_name,param2=0} end,
   get_node_or_nil=function() return {name=node_name} end,
   swap_node=function(_,n) node_name=n.name end,
   is_protected=function() return protected end,
   register_node=function(n,d) core.registered_nodes[n]=d;core.registered_items[n]=d end,
   override_item=function(n,d) for k,v in pairs(d) do core.registered_nodes[n][k]=v end end,
   register_lbm=function(d) lbms[d.name]=d end,
   register_on_mods_loaded=function(f) loaded[#loaded+1]=f end,
   register_on_leaveplayer=function() end,
   register_craft=function() end,register_craft_predict=function(f) table.insert(core.registered_craft_predicts,f) end,
   register_on_craft=function(f) table.insert(core.registered_on_crafts,f) end,
   get_item_group=function() return 0 end,formspec_escape=tostring,
   get_node_timer=function() return {start=function() timer_starts=timer_starts+1 end,stop=function() end} end,
   sound_play=function() return 1 end,sound_fade=function() end,
   hash_node_position=function() return 1 end,after=function() end,
   chat_send_player=function() end,log=function() end}
  function core.get_craft_result(input)
   local stack=ItemStack(input.items and input.items[1]);local name=stack:get_name()
   local valid=(input.method=='cooking' and name=='test:raw') or
    (input.method=='fuel' and name=='test:fuel')
   local output=valid and input.method=='cooking' and 'test:dish' or ''
   if valid then stack:take_item() end
   return {time=valid and (input.method=='fuel' and 10 or 1) or 0,
    item=ItemStack(output),replacements={}}, {items={stack}}
  end
  default={get_translator=function(s) return s end,get_hotbar_bg=function() return '' end,
   node_sound_stone_defaults=function() return {} end,
   node_sound_metal_defaults=function() return {} end,
   node_sound_wood_defaults=function() return {} end,
   set_inventory_action_loggers=function() end,get_inventory_drops=function() end}
  grug_items=nil;grug_brewing=nil;grug_jobs={station_book_button=function() return '' end}
  vector={distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end}
  grug_xp={get_level=function() return 1 end}
  grug_core={settlement_socket_settlements=function() return {{key='highcourt'}} end,
   settlement_sockets_at=function() return {{role='public_station',tags={'furnace'},pos=at}} end}
  dofile(repo..'/mods/BASE/default/furnace.lua')
  dofile(repo..'/mods/PLAYER/grug_jobs/registry.lua')
  dofile(repo..'/mods/PLAYER/grug_jobs/state.lua')
  dofile(repo..'/mods/PLAYER/grug_jobs/stations.lua')
  local factory=dofile(repo..'/mods/PLAYER/grug_jobs/station_nodes.lua')
  factory.install_jobs(grug_jobs)
  for _,f in ipairs(loaded) do f() end
  local player={};local pm=meta()
  function player:is_player() return true end
  function player:get_player_name() return 'cook' end
  function player:get_hp() return 100 end
  function player:get_pos() return position end
  function player:get_meta() return pm end
  local activate=assert(lbms['grug_jobs:activate_public_hearths']).action
  activate(at);local inv=metadata:get_inventory()
  assert(inv:get_size('src')==1 and inv:get_size('fuel')==1 and inv:get_size('dst')==4)
  inv:set_stack('src',1,'test:raw');inv:set_stack('fuel',1,'test:fuel')
  activate(at);assert(inv:get_stack('src',1):get_name()=='test:raw')
  grug_jobs.register_ingredient_tier('test:raw',1)
  grug_jobs.register_recipe({profession='cooking',tier=1,station='furnace',
   inputs={'test:raw'},output='test:dish',hint='Cook'})
  local furnace=core.registered_nodes['default:furnace'];local raw=ItemStack('test:raw')
  assert(furnace.allow_metadata_inventory_put(at,'src',1,raw,player)==1)
  assert(furnace.allow_metadata_inventory_move(at,'src',1,'src',1,1,player)==1)
  assert(furnace.allow_metadata_inventory_put({x=11,y=20,z=30},'src',1,raw,player)==0)
  node_name='default:stone';assert(furnace.allow_metadata_inventory_put(at,'src',1,raw,player)==0)
  node_name='default:furnace';position={x=100,y=20,z=30}
  assert(furnace.allow_metadata_inventory_put(at,'src',1,raw,player)==0)
  protected=false;assert(furnace.allow_metadata_inventory_put(at,'src',1,raw,player)==0)
  protected=true;position={x=10,y=20,z=30};furnace.on_timer(at,2)
  assert(inv:get_stack('dst',1):get_name()=='test:dish')
  local dish=inv:get_stack('dst',1)
  assert(furnace.allow_metadata_inventory_take(at,'dst',1,dish,player)==0)
  assert(grug_jobs.learn(player,'cooking'))
  assert(furnace.allow_metadata_inventory_take(at,'dst',1,dish,player)==1)
  assert(furnace.allow_metadata_inventory_move(at,'dst',1,'src',1,1,player)==0)
  furnace.on_metadata_inventory_take(at,'dst',1,dish,player)
  assert(grug_jobs.crafts_in_tier(player,'cooking')==1 and timer_starts>0)
  assert(furnace.allow_metadata_inventory_take({x=11,y=20,z=30},'dst',1,dish,player)==0)
  return 'cap_public_furnace\tactivation+timer+acl+Cooking\tPASS\n'
 end)
 for _,n in ipairs(globals) do rawset(_G,n,saved[n]) end
 if not ok then error(result,0) end
 return result
end
