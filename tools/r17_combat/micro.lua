-- Portable bounded production fixture. Call returned function with repository root.
return function(repo)
	local function noop() end
	local function stub(t)
		return setmetatable(t or {}, {__index = function(_, key)
			if key:match('^register_') then return noop end
		end})
	end
	local env = setmetatable({}, {__index = _G})
	env._G = env
	local function load(path)
		local fn = assert(loadfile(repo .. '/' .. path)); setfenv(fn, env); return fn()
	end
	env.vector = {}
	local v = env.vector
	function v.new(x,y,z) if type(x)=='table' then return {x=x.x,y=x.y,z=x.z} end return {x=x or 0,y=y or 0,z=z or 0} end
	function v.add(a,b) return v.new(a.x+b.x,a.y+b.y,a.z+b.z) end
	function v.subtract(a,b) return v.new(a.x-b.x,a.y-b.y,a.z-b.z) end
	function v.multiply(a,b) return v.new(a.x*b,a.y*b,a.z*b) end
	function v.length(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
	function v.distance(a,b) return v.length(v.subtract(a,b)) end
	function v.normalize(a) local n=v.length(a); return n>0 and v.multiply(a,1/n) or v.new() end
	function v.offset(a,x,y,z) return v.add(a,v.new(x,y,z)) end
	function v.round(a) return v.new(math.floor(a.x+0.5),math.floor(a.y+0.5),math.floor(a.z+0.5)) end
	local callbacks, steps, online, entities, spawned, deferred = {}, {}, {}, {}, {}, {}
	local solid, setting, node_name, aim = false, '1.5', 'air', nil
	local core = stub({registered_entities=entities,registered_nodes={air={walkable=false},stone={walkable=true}},
		settings={get=function() return setting end},
		check_player_privs=function() return false end,log=noop, get_mod_storage=function() return {get_string=function() return '' end} end,
		get_player_by_name=function(n) return online[n] end,
		get_connected_players=function() local out={} for _,p in pairs(online) do out[#out+1]=p end return out end,
		get_node_or_nil=function() return {name=solid and 'stone' or node_name} end,
		is_player=function(o) return o and o:is_player() end,
		register_entity=function(n,d) entities[n]=d end,
		register_node=function(n,d) core.registered_nodes[n]=d end,
		register_globalstep=function(f) steps[#steps+1]=f end,
		serialize=function(x) return x end, deserialize=function(x) return x end,
		dir_to_yaw=function(d) return -math.atan2(d.x,d.z) end,
		after=function(_,f) deferred[#deferred+1]=f end,
		add_particle=noop,add_particlespawner=noop,chat_send_player=noop,
		get_us_time=function() return 1000000 end,
	})
	-- Lua local initializer closures cannot capture their own local binding.
	core.register_node=function(n,d) core.registered_nodes[n]=d end
	for _,event in ipairs({'joinplayer','leaveplayer','dieplayer','respawnplayer'}) do
		callbacks[event]={}
		core['register_on_'..event]=function(f) callbacks[event][#callbacks[event]+1]=f end
	end
	core.raycast=function()
		local used=false
		return function() if solid and not used then used=true; return {type='node',under=v.new()} end end
	end
	env.core=core
	local gc=stub({combat_debug_enabled=function() return false end,get_player_level=function() return 10 end,
		combat_eye_pos=function(o) return v.offset(o:get_pos(),0,1,0) end,
		combat_ray=function(_,range) if not solid and aim and v.distance(v.new(),aim:get_pos())<=range then return {status='target',target=aim} end return {status='aim_miss'} end,
		mark_in_combat=noop, set_move_modifier=noop, clear_move_modifier=noop,
	})
	env.grug_core=gc
	local function actor(name,x,player)
		local o={name=name,pos=v.new(x,0,0),velocity=v.new(),hp=100,hits=0}
		function o:is_player() return player end
		function o:get_player_name() return self.name end
		function o:get_pos() return not self.removed and self.pos end
		function o:set_pos(p) self.pos=v.new(p) end
		function o:get_velocity() return self.velocity end
		function o:get_properties() return {collisionbox={-0.3,0,-0.3,0.3,1.8,0.3}} end
		function o:get_hp() return self.hp end
		function o:set_hp(hp) self.hp=hp end
		function o:get_luaentity() return self.entity end
		function o:get_eye_offset() return v.new() end
		function o:get_look_dir() return v.new(1,0,0) end
		function o:punch(_,_,caps) self.hits=self.hits+1; self.last_damage=caps.damage_groups.fleshy end
		if player then online[name]=o else o.entity={object=o,health=100,_cmi_is_mob=true,temp={}} end
		return o
	end
	local function event(name,o) for _,f in ipairs(callbacks[name]) do f(o) end end
	core.add_entity=function(pos,name,payload)
		local def=assert(entities[name],name)
		local o=actor(name,pos.x,false); o.pos=v.new(pos)
		local e=setmetatable({object=o},{__index=def});o.entity=e
		function o:set_velocity(p) self.velocity=v.new(p) end
		function o:set_rotation(r) self.rotation=r end
		function o:set_properties(p) self.properties=p end
		function o:remove() self.removed=true; if def.on_deactivate then def.on_deactivate(e) end end
		if def.on_activate then def.on_activate(e,payload) end
		spawned[#spawned+1]=o
		return o
	end
	gc.get_player_faction=function(name) return name=='archer' and 'accord' or 'throng' end
	core.raycast=function(origin,_,objects)
		local i=0
		return function()
			i=i+1
			if i==1 and solid then return {type='node',under=v.new(),intersection_point=v.offset(origin,1,0,0)} end
			if (i==1 or i==2 and solid) and objects and aim then
				return {type='object',ref=aim,intersection_point=v.offset(aim:get_pos(),0,1,0)}
			end
		end
	end
	load('mods/CORE/grug_core/combat_ray.lua')
	load('mods/CORE/grug_core/homing.lua')
	load('mods/ENTITIES/grug_projectiles/init.lua')
	local owner=actor('archer',0,true); local target=actor('victim',10,true)
	event('joinplayer',owner);event('joinplayer',target);aim=target
	local impacts=0
	env.grug_projectiles.register('test',{speed=20,max_distance=20,active_limit=2,orient_to_velocity=true,
		on_hit=function(o,t) assert(o==owner and t==target);impacts=impacts+1 end})
	local params={owner=owner,origin=v.new(),direction=v.new(1,0,0)}
	local function shot() assert(env.grug_projectiles.spawn('test',params));return spawned[#spawned] end
	local function step(o,dt) entities['grug_projectiles:projectile'].on_step(o.entity,dt) end
	local p=shot();assert(p.rotation)
	solid=true;target.pos=v.new(30,0,0);target.velocity=v.new(40,0,0)
	step(p,0.5);step(p,0.5);assert(impacts==1 and p.removed,'moving target behind wall/out of range exactly once')
	local before=#spawned
	assert(not env.grug_projectiles.spawn('test',params) and #spawned==before,'initial wall rejects')
	solid=false;target.pos=v.new(10,0,0);target.velocity=v.new()
	aim=nil;assert(not env.grug_projectiles.spawn('test',params));aim=target
	p=shot();gc.invalidate_combat_identity(target);step(p,0.5);assert(impacts==1 and p.removed)
	p=shot();event('dieplayer',target);event('respawnplayer',target);step(p,0.5);assert(impacts==1)
	p=shot();target.pos=v.new(100,0,0);step(p,0.5);assert(impacts==1);target.pos=v.new(10,0,0)
	p=shot();online.victim=actor('victim',10,true);step(p,0.5);assert(impacts==1);online.victim=target
	local commits=0
	assert(not env.grug_projectiles.spawn_batch('test',{params,params,params},function() commits=commits+1;return true end))
	assert(commits==0,'batch must roll back before cost')
	assert(env.grug_projectiles.spawn_batch('test',{params,params},function() commits=commits+1;return true end))
	assert(commits==1);step(spawned[#spawned-1],0.5);step(spawned[#spawned],0.5);assert(impacts==3)
	assert(not env.grug_projectiles.spawn_batch('test',{params},function() return false end))
	step(spawned[#spawned],1);assert(impacts==3)

	-- Load real mob formula, all arrow definitions, fixed aura/poison/ground paths.
	local gm=stub({is_noncombatant=function(e) return e.noncombatant end,atlas_textures=function() return {} end,guard_definition=function() return {} end,register_mob=function(n,d) entities[n]=d end})
	env.grug_mobs=gm
	env.mobs={register_arrow=function(_,n,d)
		d.initial_properties={};entities[n]=d
	end,spawn=noop}
	env.default=setmetatable({}, {__index=function() return function() return {} end end})
	load('mods/ENTITIES/grug_mobs/levels.lua')
	local _,damage=gm.stats_for(10,'normal');assert(math.abs(damage-8.25)<1e-9)
	for _,invalid in ipairs({'-1','11','nan','invalid'}) do setting=invalid;load('mods/ENTITIES/grug_mobs/levels.lua');assert(gm.scale_attack_damage(2)==3) end
	setting='1.0';load('mods/ENTITIES/grug_mobs/levels.lua');local _,base=gm.stats_for(10,'normal');assert(base==5.5)
	setting='1.5';load('mods/ENTITIES/grug_mobs/levels.lua')
	load('mods/ENTITIES/grug_mobs/verbs.lua')
	load('mods/ENTITIES/grug_mobs/bog_witch.lua')
	load('mods/ENTITIES/grug_mobs/boss_dragons.lua')
	load('mods/ENTITIES/grug_mobs/bosses.lua')
	load('mods/ENTITIES/grug_mobs/oerkki.lua')
	load('mods/ENTITIES/grug_mobs/night_families.lua')
	gm.register_simple_arrow('fixture:arrow',{texture='arrow.png'})
	gm.register_simple_arrow('grug_mobs:arrow_entity',{texture='arrow.png'})
	local mob=actor('mob',0,false);mob.entity.attack=target;mob.entity.damage=damage;mob.entity.view_range=20
	p=core.add_entity(v.new(),'fixture:arrow');gm.stamp_arrow_damage(p.entity,mob.entity)
	target.pos=v.new(30,0,0);target.velocity=v.new(40,0,0);solid=true
	entities['fixture:arrow'].on_step(p.entity,0.8);entities['fixture:arrow'].on_step(p.entity,0.8)
	assert(target.hits==1 and target.last_damage==8.25,'mob missile scales once')
	target.pos=v.new(1,0,0);target.velocity=v.new();solid=false
	local king=mob.entity
	king.temp.grug_royal_cast={left=0,target=target,health=100};king.set_velocity=noop
	local count=#spawned
	entities['grug_mobs:king_elf'].do_custom(king,0.1)
	assert(#spawned==count+3,'royal volley launches')
	for i=count+1,#spawned do assert(spawned[i].entity._grug_lock.target==target) end
	function mob:set_velocity(vel) self.velocity=vel end
	king.temp.grug_dragon={mode='ground',primary=1,gust=1,action={kind='breath',left=0,target=target,
		snapshot=v.new(99,0,0),actor_name='victim'}}
	count=#spawned
	entities['grug_mobs:ice_dragon'].do_custom(king,0.1)
	assert(#spawned==count+3,'dragon breath launches against current target')
	for i=count+1,#spawned do assert(spawned[i].entity._grug_lock.target==target) end
	local locked=gc.homing_lock(owner,mob,v.new(),20)
	mob.entity.temp.grug_evading={};assert(not gc.homing_step(locked,0.1));mob.entity.temp.grug_evading=nil
	locked=gc.homing_lock(owner,mob,v.new(),20)
	mob.entity={health=100,object=mob};assert(not gc.homing_step(locked,0.1));mob.entity=king
	mob.entity._grug_noncombatant=true;aim=mob;assert(not env.grug_projectiles.spawn('test',params));aim=target;mob.entity._grug_noncombatant=nil
	local aura={};gm.damage_aura(aura,{damage=2});aura.do_custom(mob.entity,1);assert(target.last_damage==3)
	gm.poison_player(target,1,1,2);local f=table.remove(deferred,1);assert(f);local hp=target.hp;f();assert(target.hp==hp-3)
	node_name='grug_mobs:dragon_scorch';hp=target.hp
	for _,fstep in ipairs(steps) do fstep(1) end
	assert(target.hp==hp-3,'authored dragon scorch scaled')
	node_name='air'
	setting='1.0';load('mods/ENTITIES/grug_mobs/levels.lua')
	local base_aura={};gm.damage_aura(base_aura,{damage=2});base_aura.do_custom(mob.entity,1);assert(target.last_damage==2)
	gm.poison_player(target,1,1,2);f=table.remove(deferred,1);hp=target.hp;f();assert(target.hp==hp-2)
	node_name='grug_mobs:dragon_scorch';hp=target.hp
	for _,fstep in ipairs(steps) do fstep(1) end
	assert(target.hp==hp-2);node_name='air'
	setting='1.5';load('mods/ENTITIES/grug_mobs/levels.lua')

	-- Actual Scout batch transaction and Fireball cast callbacks.
	local abilities={};env.grug_abilities=stub({register_ability=function(d) abilities[d.id]=d end})
	env.player_api=stub()
	local bow={get_tool_capabilities=function() return {damage_groups={fleshy=10}} end}
	gc.get_equipped_weapon=function() return bow end;gc.equipment_is_broken=function() return false end
	gc.baseline_weapon_damage=function() return 10 end;gc.deal_ability_damage=function(_,t,d) t:punch(owner,1,{damage_groups={fleshy=d}}) end
	env.grug_classes=stub({get_race_perk=function() return 0 end,get_ranged_bonus=function() return 0 end,get_talent_bonus=function() return 0 end,
		get_spell_damage_percent=function() return 0 end,get_spell_power_bonus=function() return 0 end,talent_window_active=function() return false end})
	local ammo=4
	env.grug_inventory={is_bow=function() return true end,ammo_count=function() return ammo end,
		consume_ammo=function(_,n) if ammo<n then return false end ammo=ammo-n;return true end}
	load('mods/PLAYER/grug_abilities/scout.lua')
	load('mods/PLAYER/grug_abilities/kits.lua')
	aim=nil;assert(not abilities.snare_shot.cast(owner));assert(ammo==4)
	aim=target;assert(abilities.snare_shot.cast(owner));assert(ammo==3)
	assert(abilities.fireball.cast(owner))
	aim=nil;assert(not abilities.fireball.cast(owner))
	return 'r17_combat PASS homing lifecycle walls range batch actors scale scout fireball\n'
end
