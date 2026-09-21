-- Bounded real-consumer fixture: money notifications, cached Character form,
-- and talent controls under the shared legacy-inventory wrapper.
return function(repo)
 local env=setmetatable({}, {__index=_G})
 env._G=env
 local hooks={}
 local function noop() end
 local function load(path)
  local f=assert(loadfile(repo..'/'..path));setfenv(f,env);return f()
 end
 local balance,writes=0,0
 local player={}
 function player:is_player() return true end
 function player:get_player_name() return 'Viewer' end
 function player:get_meta() return {get_int=function()return balance end,set_int=function(_,_,v)balance=v end} end
 function player:get_properties() return {} end
 function player:hud_add() error('money must not allocate HUD') end
 function player:hud_change() error('money must not update HUD') end
 function player:get_inventory() return {get_size=function()return 0 end} end
 local pageid='grug_inventory:character'
 local context={page=pageid}
 env.core={formspec_escape=function(s)return tostring(s)end,
  register_chatcommand=noop,register_on_mods_loaded=function(fn)hooks[#hooks+1]=fn end,
  register_on_joinplayer=function(fn)fn(player)end,register_on_leaveplayer=noop,
  registered_items={}}
 local pool={final=100,base=100,class_factor=1,gear_percent=0,talent_percent=0,status_percent=0}
 local classes={registered_classes={priest={name='Priest',resource='mana'}},
  get_class=function()return 'priest'end,get_class_def=function()return {resource='mana'}end,
  get_pool_breakdown=function()return pool end,register_on_talents_changed=noop,
  get_crit_chance_raw=function()return .15 end,get_dodge_chance_raw=function()return .12 end,
  get_crit_chance=function()return .15 end,get_dodge_chance=function()return .12 end,
  get_talent_bonus=function()return 0 end,talent_points_total=function()return 30 end,
  talent_points_available=function()return 25 end,talent_points_spent=function()return 5 end,
  tree_points=function()return 5 end,talent_rank=function()return 0 end,
  can_spend_talent=function(_,id)return id=='mercy_1', 'Previous tier required'end,
  pool_talent_effect_key=function()return nil end,registered_talents={},talent_ids={}}
 local tree={id='mercy',name='Mercy',chains={'healing','utility'},talents={}}
 for i,chain in ipairs(tree.chains) do for tier=1,4 do
  local d={id='mercy_'..((i-1)*4+tier),class='priest',tree='mercy',chain=chain,
   tier=tier,name='A representative long talent name',description='A talent description.',ranks=3}
  tree.talents[#tree.talents+1]=d;classes.registered_talents[d.id]=d
  classes.talent_ids[#classes.talent_ids+1]=d.id
 end end
 classes.trees_of_class=function()return {tree,{id='reckoning',name='Reckoning'}}end
 env.grug_classes=classes
 env.grug_core={get_armor_rating=function()return 100 end,
  get_player_level=function()return 20 end,armor_reduction=function()return .2 end,
  register_on_equipment_change=noop,register_on_status_modifiers_changed=noop}
 env.grug_xp={register_on_level_change=noop,get_level=function()return 20 end}
 env.grug_inventory={equipment_slots={}}
 env.player_api={registered_models={}}
 local sf={pages={},pages_unordered={},contexts={Viewer=context},get_nav_fs=function()return ''end}
 function sf.register_page(name,def)def.name=name;sf.pages[name]=def;sf.pages_unordered[#sf.pages_unordered+1]=def end
 function sf.get_or_create_context()return context end
 function sf.get_page()return context.page end
 local cached
 function sf.set_player_inventory_formspec(p,c)
  writes=writes+1;cached=sf.pages[c.page]:get(p,c)
 end
 function sf.set_page(p,id)context.page=id;sf.set_player_inventory_formspec(p,context)end
 env.sfinv=sf
 load('mods/CORE/grug_core/hud_layout.lua')
 assert(not env.grug_core.hud_layout.rows.money)
 load('mods/PLAYER/grug_money/init.lua')
 load('mods/PLAYER/grug_inventory/ui.lua')
 load('mods/PLAYER/grug_inventory/pages.lua')
 load('mods/PLAYER/grug_classes/talents_ui.lua')
 local money=env.grug_money
 sf.set_player_inventory_formspec(player,context)
 assert(cached:find('Money: 0c',1,true))
 writes=0;money.set(player,10005)
 assert(writes==1 and cached:find('Money: 1g 0s 5c',1,true))
 money.set(player,10005);assert(writes==1,'unchanged balance rebuilt form')
 assert(money.take_with_inventory(player,5,{}));assert(writes==2 and cached:find('Money: 1g 0s 0c',1,true))
 assert(not money.take(player,10001));assert(writes==2)
 context.page='grug_classes:talents';money.add(player,5);assert(writes==2,'money navigated or refreshed another page')
 context.page=pageid;sf.set_player_inventory_formspec(player,context)
 assert(cached:find('Money: 1g 0s 5c',1,true))
 local talent=sf.pages['grug_classes:talents']:get(player,context)
 local listpos=assert(talent:find('list[current_player;main;',1,true))
 local realpos=assert(talent:find('real_coordinates[true]',1,true))
 assert(realpos>listpos,'real coordinates changed inventory slots')
 -- Actual button rectangles must be distinct, and content must precede the
 -- legacy inventory y=7.2 (spacing.Y = image size * 15/13, plus padding).
 local rectangles={}
 for x,y,w,h in talent:gmatch('button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);') do
  local r={tonumber(x),tonumber(y),tonumber(w),tonumber(h)}
  assert(r[2]+r[4]<7.2*15/13)
  for _,o in ipairs(rectangles) do
   assert(r[1]>=o[1]+o[3] or o[1]>=r[1]+r[3] or r[2]>=o[2]+o[4] or o[2]>=r[2]+r[4], 'overlapping talent buttons')
  end
  rectangles[#rectangles+1]=r
 end
 assert(#rectangles==4,'tree/respec/available-talent fixture missing')
 assert(talent:find('Crit 15.0/15.0%',1,true) and talent:find('Dodge 12.0/12.0%',1,true))
 context.grug_talent_respec_pending=true
 talent=sf.pages['grug_classes:talents']:get(player,context)
 assert(talent:find('grug_talent_respec_confirm',1,true) and talent:find('grug_talent_respec_cancel',1,true))
 return 'ui_character money=no-HUD event-refresh=pass atomic-payment=pass talents=real-content inventory=legacy\n'
end
