-- Final-only real Scout release/cadence and real food callback-stack regressions.
return function(root)
	local function noop() end
	local env = setmetatable({}, {__index = _G}); env._G = env
	local function load(path)
		local fn = assert(loadfile(root .. "/" .. path))
		setfenv(fn, env)
		return fn()
	end
	local Stack = {}; Stack.__index = Stack
	local function stack(name, count)
		return setmetatable({name=name, count=count or 1}, Stack)
	end
	function Stack:get_name() return self.count > 0 and self.name or "" end
	function Stack:get_count() return self.count end
	function Stack:is_empty() return self.count == 0 end
	function Stack:take_item(n) self.count = math.max(0, self.count - n) end
	function Stack:get_meta() return {get_string=function() return "" end} end
	function Stack:get_tool_capabilities() return {damage_groups={fleshy=10}} end
	env.ItemStack = function(s)
		if type(s) == "table" then return stack(s.name, s.count) end
		return stack(s, s == "" and 0 or 1)
	end
	local now, tick, projectiles, ammo, succeed = 0, nil, 0, 10, true
	local wield, bow = stack("grug_abilities:loose"), stack("test:bow")
	local control = {place=true, dig=true}
	local player = {
		get_player_name=function() return "scout" end,
		get_hp=function() return 50 end, set_hp=noop, is_player=function() return true end,
		get_wielded_item=function() return env.ItemStack(wield) end,
		set_wielded_item=function(_, s) wield=env.ItemStack(s) end,
		get_inventory=function() return {get_list=function() return {} end} end,
		get_player_control=function() return control end,
		get_look_dir=function() return {x=1,y=0,z=0} end,
	}
	local defs = setmetatable({}, {__index=function(t,k)
		local d={description=k,groups={}}; rawset(t,k,d); return d
	end})
	env.core = {get_us_time=function() return now end,
		register_globalstep=function(f) tick=f end,
		register_on_dieplayer=noop,register_on_leaveplayer=noop,
		get_player_by_name=function() return player end,registered_items=defs,
		override_item=function(name, changes)
			for k,v in pairs(changes) do defs[name][k]=v end
		end, sound_play=noop,chat_send_player=noop,
	}
	env.grug_core = {get_equipped_weapon=function() return bow end,
		equipment_is_broken=function() return false end,
		is_stunned=function() return false end,
		combat_eye_pos=function() return {x=0,y=0,z=0} end,
		register_on_settled_outgoing_action=noop,register_on_stun=noop,
		register_on_equipment_change=noop,in_combat=function() return false end,
		can_use_item_level=function() return true end,set_status=function() return {} end}
	env.grug_classes = {get_talent_bonus=function() return 0 end,
		get_race_perk=function() return 0 end,get_ranged_bonus=function() return 0 end,
		get_max_hp=function() return 100 end}
	env.grug_inventory = {is_bow=function() return true end,
		ammo_count=function() return ammo end,
		consume_ammo=function(_, n) ammo=ammo-n; return true end}
	env.player_api = {register_control_animation_override=noop}
	env.vector = {new=function(v) return {x=v.x,y=v.y,z=v.z} end,
		length=function() return 1 end}
	env.grug_projectiles = {register=noop,spawn_batch=function(_, batch, consume)
		if not succeed then return false end
		assert(consume()); projectiles=projectiles+#batch; return true
	end}
	local A = {registered={},flash=noop,swing_stats=function() return 10, 1 end}
	env.grug_abilities=A
	A.register_ability=function(def) A.registered[def.id]=def end
	local progress={}
	A.delay_strike=load("mods/PLAYER/grug_abilities/strike_delay.lua")(progress)
	load("mods/PLAYER/grug_abilities/scout.lua")
	assert(A.start_bow_draw(player))
	now=500000; control.place=false; tick(0.05)
	assert(projectiles==1 and ammo==9 and progress.scout.next_due==1500000)
	-- The real shared cadence prevents a Strike at the next 100 ms sample.
	-- Full init.lua melee damage is covered separately; this checks its deadline.
	now=600000; assert(now < progress.scout.next_due)
	now=1500000; assert(now >= progress.scout.next_due)
	progress.scout.next_due=5000000; A.delay_strike(player)
	assert(progress.scout.next_due==5000000) -- Later deadlines survive.
	control.place=true; assert(A.start_bow_draw(player))
	now=2000000; control.place=false; succeed=false; tick(0.05)
	assert(projectiles==1 and ammo==9 and progress.scout.next_due==5000000)

	-- Engine callbacks receive a copy and overwrite wield with the return value.
	-- Reproduce that boundary, including the last portion and a planting delegate.
	env.grug_gathering={p9g_sources=function() return {} end}
	local delegated, due = 0, true
	defs["test:food"]={description="Test food",groups={},on_place=function(s)
		delegated=delegated+1
		s:take_item(1) -- A real placement callback can change the refreshed copy.
		return s
	end}
	load("mods/ITEMS/grug_food/init.lua")
	local F=env.grug_food
	assert(F.register_item("test:food",1,"raw","hp"))
	A.input={right_action=function(p) if due then F.consume_held(p) end end,
		interaction=noop}
	for _, callback in ipairs({"on_place","on_secondary_use"}) do
		for _, count in ipairs({1,3}) do
			wield=stack("mobs:meat_raw",count)
			local incoming=player:get_wielded_item()
			local returned=defs["mobs:meat_raw"][callback](incoming,player,{type="nothing"})
			player:set_wielded_item(returned)
			assert(wield.count==count-1 and incoming.count==count)
		end
	end
	wield=stack("test:food",3)
	local returned=defs["test:food"].on_place(player:get_wielded_item(),player,{type="nothing"})
	player:set_wielded_item(returned)
	assert(wield.count==1 and delegated==1) -- Eat once, delegate once; no resurrection.
	due=false; wield=stack("test:food",3)
	returned=defs["test:food"].on_place(player:get_wielded_item(),player,{type="nothing"})
	player:set_wielded_item(returned)
	assert(wield.count==2 and delegated==2) -- Ordinary placement stays intact.
	return "r20_input:real-loose-delay+food-callback-stack:ok"
end
