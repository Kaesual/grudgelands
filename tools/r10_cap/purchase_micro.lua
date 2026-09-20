-- Actual villager click -> dedicated dialog -> purchase state/money/item path.
return function(repo)
 local names={'core','grug_mounts','grug_mobs','grug_core','grug_factions',
  'grug_classes','grug_xp','grug_money','grug_jobs','mobs','ItemStack'}
 local saved={};for _,n in ipairs(names) do saved[n]=rawget(_G,n) end
 local ok,result=pcall(function()
	local Stack = {}
	Stack.__index = Stack
	function Stack:get_name() return self.name end
	function Stack:get_wear() return self.wear or 0 end
	function Stack:add_wear(amount) self.wear = (self.wear or 0) + amount end
	function Stack:get_meta()
		local owner = self
		return {
			set_string = function(_, key, value) owner.meta[key] = value end,
			get_string = function(_, key) return owner.meta[key] or "" end,
		}
	end
	function Stack:is_empty() return self.name == "" end
	function Stack:copy()
		local out = setmetatable({name = self.name, wear = self.wear or 0,
			meta = {}}, Stack)
		for key, value in pairs(self.meta) do out.meta[key] = value end
		return out
	end

	function ItemStack(value)
		if getmetatable(value) == Stack then return value:copy() end
		local name = tostring(value or ""):match("^(%S*)") or ""
		return setmetatable({name = name, wear = 0, meta = {}}, Stack)
	end

	local Inventory = {}
	Inventory.__index = Inventory
	function Inventory:get_lists() return {main = self.main} end
	function Inventory:get_size(name) return #(self[name] or {}) end
	function Inventory:get_stack(name, index)
		return (self[name][index] or ItemStack("")):copy()
	end
	function Inventory:set_stack(name, index, stack) self[name][index] = ItemStack(stack) end
	function Inventory:room_for_item(name)
		for index = 1, #self[name] do
			if self[name][index]:is_empty() then return true end
		end
		return false
	end
	function Inventory:add_item(name, stack)
		for index = 1, #self[name] do
			if self[name][index]:is_empty() then
				self[name][index] = ItemStack(stack)
				return ItemStack("")
			end
		end
		return ItemStack(stack)
	end


  local callbacks,mobdefs,shown={},{},{}
  core={registered_items={},formspec_escape=tostring,
   register_on_player_receive_fields=function(fn) callbacks[#callbacks+1]=fn end,
   register_on_joinplayer=function() end,register_on_leaveplayer=function() end,
   register_on_dieplayer=function() end,register_chatcommand=function() end,
   register_on_mods_loaded=function() end,register_allow_player_inventory_action=function() end,
   register_on_player_inventory_action=function() end,
   register_craftitem=function(n,d) core.registered_items[n]=d end,
   show_formspec=function(_,name,text) shown={name,text} end,
   chat_send_player=function() end,log=function() end}
  grug_mobs={register_start_socket_role=function() end,noncombatant=function(d) return d end}
  mobs={register_mob=function(_,name,def) mobdefs[name]=def end}
  grug_core={start_identities=function() return {{race_id='human',faction_id='accord'}} end,
   settlement_sockets_at=function() return {{id='riding',role='riding_trainer',
    pos={x=0,y=1,z=0}}} end}
  grug_factions={get_faction=function() return 'accord' end,
   register_on_faction_chosen=function() end}
  grug_classes={get_race=function() return 'human' end,
   register_on_race_chosen=function() end}
  grug_xp={get_level=function(p) return p.level end}
  local values={};local pm={get_int=function(_,k) return values[k] or 0 end,
   set_int=function(_,k,v) values[k]=v end,get_string=function(_,k) return values[k] or '' end,
   set_string=function(_,k,v) values[k]=v end}
  local inventory=setmetatable({main={ItemStack(''),ItemStack('')}},Inventory)
  local player={level=60,is_player=function() return true end,
   get_player_name=function() return 'buyer' end,get_hp=function() return 100 end,
   get_pos=function() return {x=0,y=1,z=0} end,get_meta=function() return pm end,
   get_inventory=function() return inventory end}
  dofile(repo..'/mods/PLAYER/grug_money/init.lua')
  grug_mounts={}
  for _,file in ipairs({'catalog','state','items','trainer'}) do
   dofile(repo..'/mods/PLAYER/grug_mounts/'..file..'.lua')
  end
  dofile(repo..'/mods/ENTITIES/grug_mobs/start_villagers.lua')
  local npc={_grug_start='highcourt',_grug_socket='riding',_grug_socket_role='riding_trainer',
   object={get_pos=player.get_pos}}
  local click=assert(mobdefs['grug_mobs:villager_human']).on_rightclick
  local function buy(tier)
   click(npc,player);assert(shown[1]:find('grug_mounts:riding:',1,true)==1)
   callbacks[1](player,shown[1],{['buy_'..tier]=true})
  end
  grug_money.add(player,200000);local initial=grug_money.get(player)
  buy(2);assert(grug_money.get(player)==initial and not grug_mounts.owns_tier(player,2))
  player.level=1;buy(1);assert(grug_money.get(player)==initial)
  player.level=60
  inventory:set_stack('main',1,'test:full');inventory:set_stack('main',2,'test:full')
  buy(1);assert(grug_money.get(player)==initial and not grug_mounts.owns_tier(player,1))
  inventory:set_stack('main',1,'');inventory:set_stack('main',2,'')
  grug_money.take(player,initial);buy(1);assert(not grug_mounts.owns_tier(player,1))
  grug_money.add(player,initial)
  local spent=0
  for tier=1,4 do
   buy(tier);spent=spent+grug_mounts.PRICES[tier]
   assert(grug_mounts.owns_tier(player,tier) and grug_money.get(player)==initial-spent)
   buy(tier);assert(grug_money.get(player)==initial-spent)
  end
  for index,tier in ipairs({2,4}) do
   local stack=inventory:get_stack('main',index)
   assert(stack:get_name()==grug_mounts.TIERS[tier].item)
   assert(stack:get_meta():get_string('grug_mounts:owner')=='buyer')
   local def=assert(core.registered_items[stack:get_name()]);local toggled=0
   grug_mounts.toggle=function() toggled=toggled+1 end
   def.on_use(stack,player);assert(toggled==1)
   stack:get_meta():set_string('grug_mounts:owner','other')
   def.on_use(stack,player);assert(toggled==1)
   assert(def.on_drop(stack,player)==stack)
  end
  -- Same actual villager click routes every profession to its own UI, without
  -- Riding buttons or the removed generic trainer-hook extension.
  grug_jobs={}
  dofile(repo..'/mods/PLAYER/grug_jobs/registry.lua')
  dofile(repo..'/mods/PLAYER/grug_jobs/state.lua')
  dofile(repo..'/mods/PLAYER/grug_jobs/trainers.lua')
  assert(grug_jobs.register_trainer_hook==nil)
  npc._grug_socket_role='trainer'
  for profession in pairs(grug_jobs.PROFESSIONS) do
   npc._grug_profession=profession;click(npc,player)
   assert(shown[1]=='grug_jobs:trainer' and not shown[2]:find('Riding',1,true))
   callbacks[2](player,shown[1],{buy_1=true})
   assert(grug_money.get(player)==initial-spent)
  end
  return 'cap_purchase_chain\tclick+state+money+owner+profession_separation\tPASS\n'
 end)
 for _,n in ipairs(names) do rawset(_G,n,saved[n]) end
 if not ok then error(result,0) end
 return result
end
