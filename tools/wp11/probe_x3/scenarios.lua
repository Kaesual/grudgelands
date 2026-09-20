assert(jit, "native probe requires LuaJIT")
local checks = 0
local function check(ok, message)
	assert(ok, "WP11X3 FAIL " .. message)
	checks = checks + 1
	core.log("action", "WP11X3 CHECK " .. message)
end
local function eq(a, b, message)
	check(a == b, message .. ": " .. tostring(a) .. " != " .. tostring(b))
end
local original = {}
local function adapter(owner, key, fn)
	original[#original + 1] = {owner, key, owner[key]}
	owner[key] = fn
end
local now = core.get_us_time()
local players, objects, ray = {}, {}, {}
local live_player = core.get_player_by_name
adapter(core, "get_us_time", function() return now end)
adapter(core, "get_player_by_name", function(name) return players[name] or live_player(name) end)
adapter(core, "is_player", function(p) return p and p.is_player and p:is_player() end)
adapter(core, "get_objects_inside_radius", function(pos, radius)
	local found = {}
	for _, obj in ipairs(objects) do
		if vector.distance(pos, obj:get_pos()) <= radius then found[#found + 1] = obj end
	end
	return found
end)
adapter(core, "raycast", function()
	local n = 0
	local function next_hit() n = n + 1; return ray[n] end
	return setmetatable({next = next_hit}, {__call = next_hit})
end)
local node_lookup = core.get_node_or_nil
adapter(core, "get_node_or_nil", function(pos)
	if pos._probe then return {name = "default:stone"} end
	return node_lookup(pos)
end)
-- Deterministic rolls; the real crit/dodge accessors still run. Individual
-- scenarios force a critical by returning zero instead of replacing stats.
local roll = 0.99
adapter(math, "random", function(a, b)
	if a then return b and a or 1 end
	return roll
end)
local serial = 0
local function player(class, tree, ranks, initial_mana)
	serial = serial + 1
	local name = "x3_probe_" .. serial
	local meta = ItemStack("default:stick"):get_meta()
	meta:set_string("grug_classes:class", class)
	meta:set_string("grug_factions:faction", "accord")
	meta:set_int("grug_xp:xp", grug_xp.xp_for_level(60))
	local points = {}
	if tree then
		for id, def in pairs(grug_classes.registered_talents) do
			if def.tree == tree then points[id] = def.ranks end
		end
	end
	for id, rank in pairs(ranks or {}) do points[id] = rank end
	meta:set_string("grug_classes:talents", grug_classes.serialize_talents(points))
	local inv = core.create_detached_inventory(name, {})
	for _, list in ipairs({"main", "grug_weapon", "grug_offhand", "grug_head", "grug_chest", "grug_legs", "grug_feet", "grug_skills", "craft", "craftpreview", "craftresult"}) do
		inv:set_size(list, list == "main" and 32 or list == "grug_skills" and 32 or 1)
	end
	local p = {name = name, meta = meta, inv = inv, hp = 100, props = {hp_max = 100, eye_height = 1.5}, pos = vector.new(0, 0, 0), physics = {speed=1,jump=1,gravity=1}, wield = 1}
	function p:is_player() return true end
	function p:get_luaentity() return nil end
	-- No native scene object: presentation carriers must not attach to adapters.
	function p:is_valid() return false end
	function p:get_player_name() return self.name end
	function p:get_meta() return self.meta end
	function p:get_inventory() return self.inv end
	function p:get_hp() return self.hp end
	function p:get_properties() return self.props end
	function p:set_properties(t) for k,v in pairs(t) do self.props[k]=v end end
	function p:get_pos() return self.pos end
	function p:set_pos(v) self.pos = vector.new(v) end
	function p:get_look_dir() return vector.new(0,0,1) end
	function p:get_look_horizontal() return 0 end
	function p:get_eye_offset() return vector.new(0,0,0) end
	function p:get_attach() return nil end
	function p:get_player_control() return {dig=self.dig or false} end
	function p:get_wield_index() return self.wield end
	function p:get_wielded_item() return self.inv:get_stack("main",self.wield) end
	function p:set_wielded_item(s) self.inv:set_stack("main",self.wield,s) end
	function p:get_physics_override() return self.physics end
	function p:set_physics_override(t) for k,v in pairs(t) do self.physics[k]=v end end
	function p:get_breath() return 10 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	function p:hud_set_flags() end
	function p:set_animation() end
	function p:set_local_animation() end
	function p:set_eye_offset() end
	function p:set_armor_groups() end
	function p:set_nametag_attributes() end
	function p:get_nametag_attributes() return {} end
	function p:get_velocity() return vector.new(0,0,0) end
	function p:set_hp(hp, reason)
		local change = core.registered_on_player_hpchange(self, hp-self.hp, reason or {type="set_hp"})
		self.hp = math.max(0,self.hp+change)
	end
	function p:punch(attacker, _, caps)
		if self.refused then return end
		self:set_hp(self.hp-caps.damage_groups.fleshy, {type="punch",object=attacker})
	end
	players[name] = p
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local owner=core.callback_origins[fn].mod
		if owner=="player_api" or owner=="grug_projectiles" then fn(p) end
	end
	grug_classes.apply_stats(p)
	p.hp = p.props.hp_max
	sfinv.get_or_create_context(p).page = "x3_probe:none"
	grug_abilities.restore_mana(p, initial_mana or 1e9)
	return p
end
local function mob(name, x, z, faction)
	local obj = {pos=vector.new(x or 0,1.5,z or 3), hp=100000, mode="accepted"}
	local ent = {name=name,_cmi_is_mob=true,_grug_faction=faction or "throng",object=obj,health=obj.hp,temp={},attack_type="dogfight",walk_velocity=2,run_velocity=4}
	function obj:is_player() return false end
	function obj:get_pos() return self.pos end
	function obj:get_hp() return self.hp end
	function obj:get_velocity() return vector.new(0,0,0) end
	function obj:set_velocity() end
	function obj:get_luaentity() return ent end
	function ent:do_attack(target) self.attack=target end
	function obj:punch(attacker, _, caps)
		self.attempts=(self.attempts or 0)+1
		if self.mode ~= "accepted" then return end
		local damage=caps.damage_groups.fleshy
		local token=grug_core.claim_authoritative_swing(attacker,self)
		local context=token and grug_core.prepare_native_melee(attacker,self,1,token)
		if context then damage=damage+(context.extra_damage or 0) end
		self.hp=self.hp-damage; ent.health=self.hp
		grug_core.run_player_hit_mob(attacker,ent,damage,damage,1)
		if context then
			grug_core.finish_native_melee(context,{landed=true,damage=damage,mob=ent,grant_rage=true})
		end
	end
	return obj
end
local function aim(obj, distance)
	ray={{type="object",ref=obj,intersection_point=vector.new(0,1.5,distance or obj.pos.z)}}
end
local function cast(p,id,target)
	if target then aim(target) end
	grug_abilities.try_cast(p,grug_abilities.registered[id],target and {type="object",ref=target})
end
local function advance(seconds) now=now+seconds*1e6 end
local weapon
for name, def in pairs(core.registered_items) do
	if def.type=="tool" and core.get_item_group(name,"grug_equip_weapon")>0 and grug_repair.eligible(ItemStack(name)) then weapon=name;break end
end
assert(weapon,"wear fixture weapon")
local function equip(p) p.inv:set_stack("grug_weapon",1,ItemStack(weapon)) end
local function wear(p) return p.inv:get_stack("grug_weapon",1):get_wear() end
local function modifier(p) return grug_core.absorb_modifier(p,"dodge_percent") end
local target=mob("probe:enemy")
objects={target}

-- Smite: real cost resolution, dispatcher, damage authority and repair.
local priest=player("priest","reckoning")
equip(priest)
local before=grug_abilities.get_mana(priest)
local cost=grug_abilities.mana_cost(priest,6)
cast(priest,"smite",target)
eq(before-grug_abilities.get_mana(priest),cost,"Recompense 6% cost")
check(grug_core.get_absorb(priest)>0,"accepted Smite grants Recompense")
eq(wear(priest),math.floor(65535/3000),"Smite plus absorb wears once")
local remaining=grug_abilities.get_mana(priest)
cast(priest,"smite",target)
eq(grug_abilities.get_mana(priest),remaining,"cooldown prevents second payment")
local rejected=player("priest","reckoning")
equip(rejected);target.mode="cancel"
cast(rejected,"smite",target)
eq(grug_core.get_absorb(rejected),0,"cancelled Smite grants no absorb")
eq(wear(rejected),0,"cancelled Smite spends no durability")
local plain=player("priest")
eq(grug_abilities.cost_for(plain,grug_abilities.registered.smite.cost,"smite").mana,grug_abilities.mana_cost(plain,5),"plain Smite 5%")
-- Drain accepts only settled positive damage, with shared identity.
local drain=player("priest","reckoning");equip(drain);drain.hp=100
local hp=drain.hp
cast(drain,"word_of_ruin",target)
eq(drain.hp,hp,"cancelled drain cannot heal")
check(not grug_classes.talent_window_active(drain,"last_word"),"cancelled drain cannot trigger Last Word")
advance(13);target.mode="accepted"
local old=target.hp
cast(drain,"word_of_ruin",target)
local dealt=old-target.hp
eq(drain.hp,hp+math.floor(dealt*1.5),"Last Word accepted prearmor 150% drain")
eq(wear(drain),math.floor(65535/3000),"drain damage and heal wear once")
advance(9)
eq(grug_classes.get_talent_bonus(drain,"drain_ratio_override"),0,"Last Word expires")
check(not grug_classes.try_trigger_talent_window(drain,"last_word",8,180),"Last Word ICD holds")

-- Turn Aside belongs to the target contribution, not the caster stats/window.
local healer=player("priest","mercy")
local tank=player("warrior")
cast(healer,"power_word_shield",tank)
eq(modifier(tank),20,"real rank 3 Turn Aside on Warrior")
eq(modifier(healer),0,"friendly shield gives caster no dodge")
check(grug_classes.get_dodge_chance(tank)<=0.30,"Turn Aside respects cap")
local shield=grug_core.get_absorb(tank)
local change=core.registered_on_player_hpchange(tank,-shield,{type="set_hp"})
eq(change,0,"shield absorbs exactly its remainder")
eq(modifier(tank),0,"consumed PWS removes Turn Aside")
advance(11);cast(healer,"power_word_shield",tank)
local plain_healer=player("priest")
cast(plain_healer,"power_word_shield",tank)
eq(modifier(tank),0,"untalented refresh removes Turn Aside")
advance(11);cast(healer,"power_word_shield",tank)
advance(25)
eq(modifier(tank),0,"expired contribution removes Turn Aside")
cast(healer,"power_word_shield",tank)
grug_classes.respec(healer)
eq(modifier(tank),0,"caster respec clears remote Turn Aside")

-- Independent Last Light, refresh/cap and earliest-expiry consumption.
local shielded=player("warrior")
grug_core.add_absorb(shielded,"last_light",100,120,shielded)
grug_core.add_absorb(shielded,"power_word_shield",60,15,shielded,nil,{dodge_percent=10})
eq(grug_core.get_absorb(shielded),160,"Last Light and PWS coexist")
grug_core.add_absorb(shielded,"power_word_shield",40,15,shielded,nil,{dodge_percent=10})
eq(grug_core.get_absorb(shielded),140,"same source refresh")
core.registered_on_player_hpchange(shielded,-40,{type="set_hp"})
eq(modifier(shielded),0,"earliest contribution consumed first")
eq(grug_core.get_absorb(shielded),100,"long Last Light survives")
grug_core.add_absorb(shielded,"glacial_ward",1e9,10,shielded)
eq(grug_core.get_absorb(shielded),shielded.props.hp_max,"total absorb cap")

-- Hold Ground and actual movement aggregate across respec/admin level drop.
local warrior=player("warrior","bulwark")
grug_abilities.add_rage(warrior,100)
cast(warrior,"hold_ground")
eq(grug_abilities.get_rage(warrior),75,"Hold Ground cost once")
check(grug_core.get_move_state(warrior).immune,"Hold Ground immunity")
eq(grug_core.get_absorb(warrior),grug_core.base_pool(60)*0.4,"Hold Ground neutral pool without spellpower")
check(not grug_core.set_root(warrior,5),"Hold Ground rejects root")
grug_classes.respec(warrior)
check(not grug_core.get_move_state(warrior).immune,"respec ends Hold Ground")
local dropped=player("warrior","bulwark")
grug_abilities.add_rage(dropped,100);cast(dropped,"hold_ground")
grug_classes.on_level_change_talents(dropped,60,10)
check(not grug_core.get_move_state(dropped).immune,"admin reset ends Hold Ground")

-- Cinderfall: real structured ray over engine-boundary intersections, not
-- enemy memory. Range and friendly/node contacts retain their exact point.
local mage=player("mage","ember")
local nearby=mob("probe:near",2.9,5)
local outside=mob("probe:outside",6.1,5)
objects={nearby,outside}
ray={{type="node",under={x=0,y=1,z=5,_probe=true},intersection_point=vector.new(0,1.5,5)}}
local nearhp,outhp=nearby.hp,outside.hp
cast(mage,"cinderfall")
check(nearby.hp<nearhp,"Cinderfall ground contact damages nearby hostile")
eq(outside.hp,outhp,"Cinderfall Ashfall rank3 radius excludes beyond6m")
advance(11)
local friend=mob("probe:friend",0,5,"accord")
aim(friend);nearhp=nearby.hp
cast(mage,"cinderfall")
check(nearby.hp<nearhp,"Cinderfall friendly first contact bursts")
advance(11);ray={};before=grug_abilities.get_mana(mage)
cast(mage,"cinderfall")
eq(grug_abilities.get_mana(mage),before,"empty Cinderfall costs nothing")

-- Frostbind current enemy authority, real root consumer and Rimebite damage.
local frost=player("mage","rime")
local rooted=player("warrior");rooted.meta:set_string("grug_factions:faction","throng");rooted.pos=vector.new(0,0,10)
objects={rooted};aim(rooted,10);hp=rooted.hp
cast(frost,"frost_nova")
check(grug_core.get_move_state(rooted).speed == 0.1,"Frostbind roots at distant hostile")
check(rooted.hp<hp,"Rimebite deals actual damage")
cast(frost,"glacial_ward")
check(grug_core.get_absorb(frost)>0,"Glacial Ward actual absorb")

-- Bellow controls every hostile in the ranked radius, excludes friends/outside.
local bellow=player("warrior","bulwark")
local within=mob("probe:bellow_in",0,9)
local far=mob("probe:bellow_out",0,11)
objects={within,far,friend}
cast(bellow,"taunt")
check(within:get_luaentity().attack==bellow,"Bellow taunts within10m")
check(far:get_luaentity().attack==nil,"Bellow excludes beyond10m")
check(friend:get_luaentity().attack==nil,"Bellow excludes friend")

-- Hearten through real friendly resolution/dispatcher/heal, one cost.
local mercy=player("priest","mercy")
local ally=player("warrior");ally.hp=1;ally.pos=vector.new(0,0,2)
local splash=player("mage");splash.hp=1;splash.pos=vector.new(0,0,4)
objects={ally,splash};before=grug_abilities.get_mana(mercy)
cast(mercy,"flash_heal",ally)
local amount=grug_abilities.registered.flash_heal.values(mercy).heal
eq(splash.hp,1+math.floor(amount*0.65),"Hearten 65% on other ally")
eq(before-grug_abilities.get_mana(mercy),grug_abilities.mana_cost(mercy,8),"Hearten single cost")

-- Timed hostile spell multiplier is applied to the complete formula; support
-- values remain independent. Test Cinderfall/Rimebite/Word plus Brand below.
local function spell_boost(p)
	grug_core.set_status(p,"probe_spell",{label="Probe",kind="buff",duration=100,
		modifiers={spell_damage_percent=50}})
end
local function scaled(p,raw,obj)
	return grug_core.scale_player_damage(p,obj,math.floor(raw*1.5+0.5))
end
local boosted=player("mage","ember");spell_boost(boosted)
local hit=mob("probe:boost",0,5);objects={hit};aim(hit,5)
old=hit.hp;cast(boosted,"cinderfall")
eq(old-hit.hp,scaled(boosted,9+grug_classes.get_spell_power_bonus(boosted),hit),"Cinderfall assembled spell multiplier")
local boosted_drain=player("priest","reckoning");spell_boost(boosted_drain)
old=hit.hp;cast(boosted_drain,"word_of_ruin",hit)
eq(old-hit.hp,scaled(boosted_drain,10+grug_classes.get_spell_power_bonus(boosted_drain),hit),"Word of Ruin assembled spell multiplier")
local boosted_frost=player("mage","rime");spell_boost(boosted_frost)
old=hit.hp;cast(boosted_frost,"frost_nova",hit)
eq(old-hit.hp,scaled(boosted_frost,5+math.floor(grug_classes.get_spell_power_bonus(boosted_frost)/2),hit),"Rimebite assembled spell multiplier")
local ward_value=grug_abilities.registered.glacial_ward.values(boosted_frost).absorb
cast(boosted_frost,"glacial_ward")
eq(grug_core.get_absorb(boosted_frost),ward_value,"spell potion never multiplies absorb")

-- Native projectile lifecycle and actual on_hit closure, with the same engine
-- ray adapter used above. No registration-table or on_hit stub is involved.
local spawned
local add_entity=core.add_entity
adapter(core,"add_entity",function(pos,name,data)
	if name == "grug_visuals:wield" then return nil end
	local obj=add_entity(pos,name,data)
	if name=="grug_projectiles:projectile" then spawned=obj end
	return obj
end)
local function fire(p,victim)
	spawned=nil
	cast(p,"fireball")
	assert(spawned,"native fireball spawned")
	local ent=spawned:get_luaentity()
	aim(victim,3)
	spawned:set_pos(vector.new(0,1.5,4))
	ent:on_step(0.2)
	return ent
end
for rank=1,3 do
	local brand=player("mage","ember",{brand=rank,whitehot=0})
	spell_boost(brand);equip(brand)
	local primary=mob("probe:fireprimary",0,3)
	local inside=mob("probe:fireinside",1.99,3)
	local beyond=mob("probe:firebeyond",2.01,3)
	objects={primary,inside,beyond}
	local ihp,bhp=inside.hp,beyond.hp
	before=grug_abilities.get_mana(brand)
	local projectile=fire(brand,primary)
	eq(before-grug_abilities.get_mana(brand),grug_abilities.mana_cost(brand,6),"Brand cost rank"..rank)
	eq(ihp-inside.hp,scaled(brand,rank+1+math.floor(grug_classes.get_spell_power_bonus(brand)/2),inside),"Brand formula rank"..rank)
	eq(beyond.hp,bhp,"Brand fixed2m rank"..rank)
	eq(wear(brand),math.floor(65535/3000),"Brand primary+splash one wear rank"..rank)
	local settled_hp=inside.hp
	projectile:on_step(0.2)
	eq(inside.hp,settled_hp,"projectile repeat settlement inert")
end
local hot=player("mage","ember");equip(hot)
local cancelled=mob("probe:cancel_fire");cancelled.mode="cancel";objects={cancelled};roll=0
fire(hot,cancelled)
check(not grug_classes.talent_window_active(hot,"whitehot"),"cancelled Fireball crit cannot trigger Whitehot")
advance(1.1);cancelled.mode="accepted"
fire(hot,cancelled)
check(grug_classes.talent_window_active(hot,"whitehot"),"accepted Fireball crit triggers Whitehot")
eq(grug_abilities.cost_for(hot,grug_abilities.registered.fireball.cost,"fireball").mana,grug_abilities.mana_cost(hot,3),"Whitehot cost snapshot3%")
advance(8.1)
check(not grug_classes.talent_window_active(hot,"whitehot"),"Whitehot expiry")
eq(grug_abilities.cost_for(hot,grug_abilities.registered.fireball.cost,"fireball").mana,grug_abilities.mana_cost(hot,6),"Whitehot cost restores6%")
check(not grug_classes.try_trigger_talent_window(hot,"whitehot",8,120),"Whitehot ICD after expiry")
roll=0.99

-- Real held-clock dispatcher and accepted primary context feed the cleave.
local connected={}
adapter(core,"get_connected_players",function() return connected end)
local function ability_step(dt)
	for _,fn in ipairs(core.registered_globalsteps) do
		if core.callback_origins[fn].mod=="grug_abilities" then fn(dt) end
	end
end
local function swing(p,id,victim)
	p.inv:set_stack("main",1,ItemStack("grug_abilities:"..id));p.wield=1;p.dig=true
	connected={p};aim(victim,2)
	ability_step(0.05)
	connected={};p.dig=false
end
local cleaver=player("warrior","ruin");equip(cleaver)
local first=mob("probe:cleave",0,2)
local second=mob("probe:secondary",1,2)
local refused=mob("probe:secondary_refused",2,2);refused.mode="cancel"
objects={first,second,refused};grug_abilities.add_rage(cleaver,100)
local second_before=second.hp
core.registered_chatcommands.combatdebug.func(cleaver.name,"on")
swing(cleaver,"mighty_blow",first)
check((first.attempts or 0)>0,"held clock attempts primary")
check(second.hp<second_before,"Broadstroke real accepted swing cleaves")
eq(wear(cleaver),math.floor(65535/3000),"Broadstroke accepted+refused targets wear once")
eq(grug_abilities.get_rage(cleaver),87,"Mighty Blow one cost plus talented swing rage")
check(grug_classes.talent_window_active(cleaver,"ruination"),"Ruination accepted primary trigger")
grug_core.set_status(cleaver,"probe_crit",{label="Probe",kind="buff",duration=100,modifiers={crit_percent=60}})
eq(grug_classes.get_crit_chance(cleaver),0.5,"Ruination raises crit cap50%")
advance(10.1)
eq(grug_classes.get_crit_chance(cleaver),0.3,"Ruination restores crit cap30%")
check(not grug_classes.try_trigger_talent_window(cleaver,"ruination",10,120),"Ruination ICD after expiry")

local ham=player("warrior","ruin");equip(ham);grug_abilities.add_rage(ham,100)
local snared=mob("probe:hamstring",0,2);objects={snared}
swing(ham,"hamstring",snared)
check((snared:get_luaentity()._grug_root_left or 0)>0,"Tendon Cut roots accepted swing")
check(not grug_classes.talent_trigger_ready(ham,"tendon_cut",12),"Tendon Cut ICD independent of charge")

-- Cancellation boundaries on players: full absorb and dodge never grant the
-- accepted-only Priest effects; published prearmor damage is not acceptance.
local defender=player("warrior");defender.meta:set_string("grug_factions:faction","throng")
defender.pos=vector.new(0,0,3)
grug_core.add_absorb(defender,"probe_full",defender.props.hp_max,100,defender)
local pvper=player("priest","reckoning");pvper.hp=50;equip(pvper)
cast(pvper,"word_of_ruin",defender)
eq(pvper.hp,50,"fully absorbed Word cannot drain")
eq(wear(pvper),0,"full absorb cannot wear outgoing equipment")
check(not grug_classes.talent_window_active(pvper,"last_word"),"full absorb cannot start Last Word")
local dodged=player("priest","reckoning");roll=0
cast(dodged,"smite",defender)
eq(grug_core.get_absorb(dodged),0,"dodged Smite cannot shield")
roll=0.99

-- Caster-owned timed effects end on actual registered lifecycle callbacks.
local function lifecycle(kind,p)
	local list=kind=="death" and core.registered_on_dieplayers or core.registered_on_leaveplayers
	for _,fn in ipairs(list) do
		local owner=core.callback_origins[fn].mod
		if owner=="grug_classes" or owner=="grug_core" then fn(p) end
	end
end
for _,kind in ipairs({"death","leave"}) do
	local owner=player("priest","mercy");local recipient=player("mage")
	cast(owner,"power_word_shield",recipient)
	eq(modifier(recipient),20,kind.." lifecycle initial Turn Aside")
	lifecycle(kind,owner)
	eq(modifier(recipient),0,kind.." lifecycle clears remote Turn Aside")
	local held=player("warrior","bulwark");grug_abilities.add_rage(held,100);cast(held,"hold_ground")
	lifecycle(kind,held)
	check(not grug_core.get_move_state(held).immune,kind.." ends Hold Ground")
end

-- Dispatcher affordability refuses before damage and does not start cooldown.
local poor=player("priest","reckoning",nil,1)
local sink=mob("probe:mana_sink");sink.mode="cancel"
before=grug_abilities.get_mana(poor)
local attempts=sink.attempts
cast(poor,"smite",sink)
eq(grug_abilities.get_mana(poor),before,"insufficient Recompense mana unchanged")
eq(sink.attempts,attempts,"insufficient mana never punches")
check(grug_abilities.ready(poor,"smite"),"insufficient mana does not arm cooldown")

-- Plain Cinderfall radius and range; stale enemy memory has no authority.
local ember=player("mage","ember",{ashfall=0})
local center=mob("probe:center",0,8)
local edge=mob("probe:edge",2.99,8)
local beyond=mob("probe:edge_out",3.01,8)
objects={edge,beyond};grug_abilities.set_target(ember,target,false)
aim(center,8);local ehp,bhp=edge.hp,beyond.hp
core.registered_chatcommands.combatdebug.func(ember.name,"on")
cast(ember,"cinderfall")
check(edge.hp<ehp,"Cinderfall base3m inside boundary")
eq(beyond.hp,bhp,"Cinderfall base3m outside boundary")
advance(11);aim(center,21);before=grug_abilities.get_mana(ember)
cast(ember,"cinderfall")
eq(grug_abilities.get_mana(ember),before,"Cinderfall range21 refused")
check(grug_abilities.ready(ember,"cinderfall"),"out of range leaves cooldown ready")
core.registered_chatcommands.combatdebug.func(ember.name,"off")

-- Renew executes the actual production globalstep tick at all three ranks.
for rank=1,3 do
	local renewer=player("priest","mercy",{renew=rank,hearten=0})
	local recipient=player("mage");recipient.hp=1
	objects={};cast(renewer,"renew",recipient)
	local tick=math.floor(grug_abilities.registered.renew.values(renewer).heal)
	for _=1,4 do advance(3);ability_step(3) end
	eq(recipient.hp,1+4*tick,"Renew four real ticks rank"..rank)
	local ended=recipient.hp;advance(3);ability_step(3)
	eq(recipient.hp,ended,"Renew stops after12s rank"..rank)
end

-- Self Turn Aside is counted exactly once, while the ordinary dodge cap
-- remains authoritative even on a target whose raw total already exceeds it.
local selfshield=player("priest","mercy")
local raw=grug_classes.get_dodge_chance_raw(selfshield)
cast(selfshield,"power_word_shield")
check(math.abs(grug_classes.get_dodge_chance_raw(selfshield)-raw-0.20)<1e-9,
	"self Turn Aside counted once")
advance(24)
eq(modifier(selfshield),0,"Second Skin exact24s expiry")

-- Every refusal path uses the same acceptance seam, including a callback
-- reporting an unrelated target and nested damage on the same attacker.
local attribution=player("priest","reckoning")
local unrelated=mob("probe:unrelated")
local impostor=mob("probe:impostor")
function impostor:punch(attacker)
	grug_core.run_player_hit_mob(attacker,unrelated:get_luaentity(),10,10,1)
end
objects={};cast(attribution,"smite",impostor)
eq(grug_core.get_absorb(attribution),0,"unrelated mob callback cannot accept Smite")
local nested=mob("probe:nested")
local accepted_count=0
function nested:punch(attacker,_,caps)
	grug_core.deal_ability_damage(attacker,unrelated,1)
	grug_core.run_player_hit_mob(attacker,self:get_luaentity(),caps.damage_groups.fleshy,1,1)
end
grug_core.deal_ability_damage(attribution,nested,10,{on_accepted=function() accepted_count=accepted_count+1 end})
eq(accepted_count,1,"nested damage restores exact outer settlement")

-- Delivered Unbroken still adds its rating window from actual surviving HP
-- loss, and the ordinary universal armor cap remains 70%.
local unbroken=player("warrior","bulwark")
local maxhp=unbroken.props.hp_max
unbroken.hp=math.floor(maxhp*0.21)
core.registered_on_player_hpchange(unbroken,-math.ceil(maxhp*0.03),{type="punch",object=target})
check(grug_classes.talent_window_active(unbroken,"unbroken"),"Unbroken existing threshold retained")
check(grug_core.get_armor_rating(unbroken)>=15,"Unbroken existing rating window retained")
local scout=player("scout","veil")
cast(scout,"sidestep")
eq(grug_classes.get_dodge_chance(scout),0.30,"Scout Sidestep ordinary cap retained")
scout.hp=math.floor(scout.props.hp_max*0.31)
core.registered_on_player_hpchange(scout,-math.ceil(scout.props.hp_max*0.03),{type="punch",object=target})
check(grug_classes.get_dodge_chance(scout)>0.30,"Scout existing dodge override retained")

for i=#original,1,-1 do local row=original[i];row[1][row[2]]=row[3] end
core.log("action","WP11X3 RESULT PASS checks=" .. checks .. " runtime=" .. jit.version)
