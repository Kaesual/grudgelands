-- Final-only contextual input fixture; native transaction seams are bounded spies.
return function(root)
	local function copy(t)
		if type(t) ~= "table" then return t end
		local c = {}; for k,v in pairs(t) do c[k] = copy(v) end; return c
	end
	local env = setmetatable({_G = false}, {__index = _G}); env._G = env
	env.table = setmetatable({copy = copy}, {__index = table})
	local time, hits, selected, slot, current, stunned = 0, {}, nil, 1, "skill", false
	local controls, casts, strikes, pickups, bows, food, digged, punched = {}, 0, 0, 0, 0, 0, 0, 0
	local food_begins, food_steps, food_ends, food_active = 0, 0, 0, false
	local next_strike, cast_ready, loaded = 0, true, {}
	local function point(x) return {x=x,y=0,z=0} end
	local v = {copy=copy,add=function(a,b) return point(a.x+b.x) end,
		multiply=function(a,b) return point(a.x*b) end,
		distance=function(a,b) return math.abs(a.x-b.x) end}
	env.vector = v
	local handcaps={groupcaps={crumbly={times={[3]=0.7},uses=0}}}
	env.ItemStack = function() return {get_tool_capabilities=function() return copy(handcaps) end} end
	local player = {
		get_player_name=function() return "hero" end,is_player=function() return true end,
		get_hp=function() return 100 end,get_player_control=function() return controls end,
		get_look_dir=function() return point(1) end,get_wield_index=function() return slot end,
		get_wielded_item=function() return {get_name=function() return current end} end,
	}
	local stone={groups={cracky=1},diggable=true,on_dig=function() digged=digged+1 end,
		on_punch=function() punched=punched+1 end}
	local soil={groups={crumbly=3},diggable=true,on_dig=stone.on_dig,on_punch=stone.on_punch}
	local torch={groups={dig_immediate=3},diggable=true,on_dig=stone.on_dig,on_punch=stone.on_punch}
	local node_name, protected = "soil", false
	local core={
		get_us_time=function() return time end,check_player_privs=function() return true end,
		get_node_or_nil=function() return {name=node_name} end,
		registered_nodes={soil=soil,stone=stone,torch=torch},
		registered_entities={["__builtin:item"]={on_punch=function() pickups=pickups+1 end}},
		get_meta=function() return {get_string=function() return "" end} end,
		is_protected=function() return protected end,
		get_item_group=function(name) return name=="food" and 1 or 0 end,
		get_dig_params=function(groups,caps)
			return {diggable=groups.crumbly==3 or (groups.dig_immediate and caps.groupcaps.dig_immediate)~=nil}
		end,
		register_on_mods_loaded=function(fn) loaded[#loaded+1]=fn end,
		register_on_dieplayer=function() end,register_on_leaveplayer=function() end,
		raycast=function()
			local i=0;return function() i=i+1;return hits[i] end
		end,
	}
	core.override_item=function(name,changes)
		if name=="" then handcaps=changes.tool_capabilities;return end
		for k,vv in pairs(changes) do core.registered_nodes[name][k]=vv end
	end
	env.core=core
	env.grug_core={combat_eye_pos=function() return point(0) end,
		is_stunned=function() return stunned end,player_has_live_mount=function() return false end,
		register_on_stun=function() end}
	local strike={id="strike",kind="swing",target_kind="hostile",range=3}
	local heal={id="heal",kind="cast",target_kind="friendly",range=20,repeat_policy="repeat"}
	local fire={id="fire",kind="cast",target_kind="hostile",range=20,repeat_policy="repeat"}
	local blink={id="blink",kind="cast",target_kind="self",range=0,repeat_policy="once"}
	local loose={id="loose",kind="cast",target_kind="hostile",range=25}
	local enemy={get_luaentity=function() return nil end}
	local ally={get_luaentity=function() return nil end}
	local Q={registered={strike=strike},is_unlocked=function() return true end,
		get_range=function(_,def) return def.range end,
		valid_target=function(_,target,kind) return target==enemy and kind=="hostile" or target==ally and kind=="friendly" end,
		try_cast=function() casts=casts+1;return true end,
		start_bow_draw=function() bows=bows+1;return true end,cancel_bow_draw=function() end}
	env.grug_abilities=Q
	env.grug_food={
		begin_hold=function() food_begins=food_begins+1;food_active=true end,
		step_hold=function() if food_active then food_steps=food_steps+1 end end,
		end_hold=function() if food_active then food_ends=food_ends+1;food_active=false end end,
		consume_held=function() food=food+1 end,
	}
	local fn=assert(loadfile(root.."/mods/PLAYER/grug_abilities/input.lua"));setfenv(fn,env)
	local input=fn()({selected=function() return selected end,
		can_cast=function(_,def) return def.kind=="cast" and cast_ready end,
		swing_ready=function() return true end,
		swing=function(_,def)
			if time>=next_strike and hits[1] and hits[1].intersection_point.x<=def.range then
				strikes=strikes+1;next_strike=time+1000000
			end
		end,
		delay_strike=function() next_strike=math.max(next_strike,time+1000000) end,
		within_hand_reach=function(_,pos) return pos.x<=4 end})
	for _,f in ipairs(loaded) do f() end
	assert(torch.groups.dig_immediate==2)
	local function node(x) return {type="node",under=point(x),intersection_point=point(x)} end
	local function object(o,x) return {type="object",ref=o,intersection_point=point(x)} end
	local function release() controls={};input.step(player);time=time+1000000 end
	selected=heal;hits={node(2)};controls={dig=true};input.press(player)
	time=time+100000;controls={};input.step(player);assert(casts==1 and digged==0)
	release();controls={dig=true};input.press(player)
	time=time+210000;input.step(player);controls={};input.step(player);assert(casts==1)
	-- Changed pending target discards the release intent.
	release();controls={dig=true};input.press(player);hits={node(3)};time=time+100000
	controls={};input.step(player);assert(casts==1)
	-- Native delegates run once; hand cannot mine stone, and protection wins.
	release();selected=strike;controls={dig=true};hits={node(2)}
	soil.on_punch(point(2),{name="soil"},player,hits[1]);assert(punched==1)
	soil.on_dig(point(2),{name="soil"},player);assert(digged==1)
	protected=true;soil.on_dig(point(2),{name="soil"},player);assert(digged==1);protected=false
	node_name="stone";stone.on_dig(point(2),{name="stone"},player);assert(digged==1);node_name="soil"
	-- Combat cast and fallback cannot land in the same decision/swing interval.
	release();selected=fire;hits={object(enemy,2)};controls={dig=true};input.press(player)
	assert(casts==2 and strikes==0);cast_ready=false;time=time+100000;input.step(player);assert(strikes==0)
	time=time+1000000;input.step(player);assert(strikes==1)
	hits={object(enemy,15)};time=time+1000000;input.step(player);assert(strikes==1)
	-- Friendly blocker never receives fallback Strike.
	hits={object(ally,2)};input.step(player);assert(strikes==1)
	-- Utility repeats once; enemy retargeting can still use melee Strike.
	release();selected=blink;cast_ready=true;hits={object(enemy,2)};controls={dig=true};input.press(player)
	local before=casts;time=time+2000000;input.step(player);assert(casts==before)
	-- Exactly one drop attempt per press, even when two native packets arrive.
	release();selected=strike;local drop={get_luaentity=function() return {name="__builtin:item"} end}
	hits={object(drop,2)};controls={dig=true};core.registered_entities["__builtin:item"].on_punch({},player)
	core.registered_entities["__builtin:item"].on_punch({},player);assert(pickups==1)
	-- RMB draw excludes LMB, and food consumes once after its threshold.
	release();selected=loose;hits={object(enemy,2)};controls={place=true,dig=true}
	local old_strikes=strikes;input.step(player);assert(bows==1 and strikes==old_strikes)
	release();selected=nil;current="food";input.step(player);release();hits={};controls={place=true}
	input.step(player);assert(food_begins==1 and food_steps>=1 and food_ends==0)
	local immediate_steps=food_steps
	time=time+1499999;input.step(player);assert(food==0 and food_steps==immediate_steps+1)
	time=time+1;input.step(player);input.step(player)
	assert(food==1 and food_ends==1 and not food_active)
	-- Slot changes/stun cancel an ambiguous release instead of casting it later.
	release();selected=heal;current="skill";input.step(player);release();hits={node(2)};controls={dig=true}
	input.step(player);before=casts;slot=2;input.step(player);controls={};input.step(player);assert(casts==before)
	controls={dig=true};input.step(player);stunned=true;input.step(player);stunned=false
	controls={};input.step(player);assert(casts==before)
	return "r20_input:arbitration+native-dig+combat+pickup+RMB+cancel:ok"
end
