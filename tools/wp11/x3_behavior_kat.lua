-- Focused executable WP11 X3 consumer probe. Loads the production kit file
-- under deterministic engine seams, then calls the real registered closures.
local root = assert(arg[1], "repository root required")
local now = 1000000
local objects = {}
local defs, damage, heals, absorbs, statuses = {}, {}, {}, {}, {}

vector = {
	new = function(x, y, z) return {x=x or 0,y=y or 0,z=z or 0} end,
	offset = function(p,x,y,z) return {x=p.x+x,y=p.y+y,z=p.z+z} end,
	add = function(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end,
	subtract = function(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end,
	multiply = function(a,n) return {x=a.x*n,y=a.y*n,z=a.z*n} end,
	distance = function() return 1 end,
	direction = function() return {x=1,y=0,z=0} end,
	round = function(p) return p end,
}

core = {
	get_us_time=function() return now end,
	get_objects_inside_radius=function() return objects end,
	add_particle=function() end, add_particlespawner=function() end,
	register_on_mods_loaded=function(fn) fn() end,
	register_globalstep=function() end, register_on_leaveplayer=function() end,
	register_on_dieplayer=function() end,
	get_player_by_name=function() return nil end,
	get_node_or_nil=function() return {name="air"} end,
	registered_nodes={air={walkable=false}},
	raycast=function() return {next=function() return nil end} end,
	colorize=function(_,s) return s end,
}

local ranks, bonuses, windows = {}, {}, {}
grug_classes = {
	get_talent_bonus=function(_, key) return bonuses[key] or 0 end,
	talent_rank=function(_, id) return ranks[id] or 0 end,
	get_spell_power_bonus=function() return 4 end,
	get_spell_damage_percent=function() return 0 end,
	get_class=function() return "warrior" end,
	get_class_def=function() return {resource="rage"} end,
	get_max_mana=function() return 100 end,
	talent_window_active=function(_, id) return windows[id] == true end,
	try_trigger_talent_window=function(_, id) windows[id]=true return true end,
	talent_trigger_ready=function() return true end,
}

grug_core = {
	base_pool=function() return 100 end, get_player_level=function() return 20 end,
	baseline_weapon_damage=function() return 10 end,
	scale_player_damage=function(_,_,n) return n end,
	combat_eye_pos=function() return {x=0,y=1,z=0} end,
	combat_ray=function() return {status="target",target=objects[1],range=20} end,
	combat_debug_enabled=function() return false end,
	mark_in_combat=function() end,
	deal_ability_damage=function(_, target, amount, opts)
		damage[#damage+1]={target=target,amount=amount,opts=opts}; return amount
	end,
	heal_player=function(_,target,amount,opts)
		heals[#heals+1]={target,amount,opts=opts}; return amount
	end,
	add_absorb=function(target,id,amount,duration)
		absorbs[#absorbs+1]={target,id,amount,duration}
	end,
	set_absorb=function(target,amount,duration)
		absorbs[#absorbs+1]={target,"power_word_shield",amount,duration}
	end,
	get_absorb=function() return 0 end,
	set_move_immunity=function(_,duration) statuses.immunity=duration end,
	set_move_modifier=function() end,
	set_status=function(_,id,def) statuses[id]=def end,
	clear_status=function() end,
	status_modifier_sum=function() return 0 end,
	taunt=function() end,
}

grug_abilities = {
	registered={},
	register_ability=function(def) defs[def.id]=def end,
	valid_target=function(user,obj,kind)
		return obj and (kind ~= "friendly" or obj.friendly == true)
	end,
	get_range=function(_,def) return def.range or 4 end,
	set_target=function() end, get_target=function() return nil end,
	add_rage=function() end, swing_rage=function() return 8 end,
	swing_stats=function() return 10,1 end,
}
grug_projectiles = {register=function() end,spawn=function() return true end}
local mob_slow, mob_root = 0, 0
grug_mobs = {slow=function(_,duration) mob_slow=duration end,
	root=function(_,duration) mob_root=duration end}

ItemStack=function() return {get_tool_capabilities=function()
	return {damage_groups={fleshy=1},full_punch_interval=0.9} end} end

local function player(name)
	local meta_values={}
	local meta={get_string=function(_,k) return meta_values[k] or "" end,
		set_string=function(_,k,v) meta_values[k]=v end}
	return {friendly=true,get_player_name=function() return name end,
		is_player=function() return true end,get_meta=function() return meta end,
		get_pos=function() return {x=0,y=0,z=0} end,
		get_properties=function() return {hp_max=100,eye_height=1.5} end,
		get_hp=function() return 20 end,get_look_dir=function() return {x=1,y=0,z=0} end}
end
local function mob(name)
	local ent={_cmi_is_mob=true,attack_type="dogfight",
		do_attack=function() end}
	return {name=name,is_player=function() return false end,
		get_luaentity=function() return ent end,get_pos=function() return {x=1,y=0,z=0} end,
		get_hp=function() return 100 end}
end

dofile(root .. "/mods/PLAYER/grug_abilities/kits.lua")
local user, enemy, ally, other = player("caster"), mob("enemy"), player("ally"), mob("other")

assert(defs.hold_ground.cost.rage==25 and defs.hold_ground.cooldown==60)
assert(defs.cinderfall.cost.mana_percent==12 and defs.cinderfall.cooldown==10)
assert(defs.glacial_ward.cost.mana_percent==10 and defs.glacial_ward.cooldown==30)
assert(defs.word_of_ruin.cost.mana_percent==8 and defs.word_of_ruin.cooldown==12)
assert(defs.hold_ground.talent_gated and defs.cinderfall.talent_gated and
	defs.glacial_ward.talent_gated and defs.word_of_ruin.talent_gated)

bonuses.hold_ground_absorb=20
assert(defs.hold_ground.cast(user,nil,defs.hold_ground))
assert(absorbs[#absorbs][2]=="hold_ground" and
	math.abs(absorbs[#absorbs][3]-20.8)<0.001)
assert(statuses.immunity==8)

objects={enemy,other}; bonuses.cinderfall_damage=7; bonuses.cinderfall_radius_add=2
damage={}; assert(defs.cinderfall.cast(user,nil,defs.cinderfall)); assert(#damage==2)
assert(damage[1].opts.action_id==damage[2].opts.action_id)
objects={}; damage={}; local ok=defs.cinderfall.cast(user,nil,defs.cinderfall)
assert(ok==false and #damage==0) -- refused aim settles nothing

bonuses.glacial_ward_absorb=15
assert(defs.glacial_ward.cast(user,nil,defs.glacial_ward))
assert(absorbs[#absorbs][2]=="glacial_ward" and absorbs[#absorbs][4]==10)

objects={enemy}; bonuses.word_of_ruin_damage=8; bonuses.drain_ratio_override=0
damage={}; heals={}; assert(defs.word_of_ruin.cast(user,nil,defs.word_of_ruin))
assert(damage[1].amount==12 and heals[1][2]==6)
assert(damage[1].opts.action_id==heals[1].opts.action_id)

objects={enemy,other}; bonuses.taunt_radius=6
assert(defs.taunt.cast(user,nil,defs.taunt))

objects={enemy,other}; bonuses.mighty_blow_cleave=3; ranks.ruination=1
damage={}; local amount, threat, post=defs.mighty_blow.proc_swing(user,enemy,
	{weapon_damage=10,melee_bonus=2}); assert(amount==17 and threat==3); post(); assert(#damage==1)
assert(windows.ruination)

bonuses.hamstring_slow_add=2; bonuses.hamstring_root=3
local _,_,ham_post=defs.hamstring.proc_swing(user,enemy,{weapon_damage=10,melee_bonus=2})
ham_post(); assert(mob_root==3 and mob_slow==7)

objects={enemy,other}; bonuses.fireball_splash=3
-- Projectile hit closure is captured through registration in the native probe;
-- source contract KAT covers its registration data path here.

objects={enemy,other}; bonuses.frost_nova_ranged=3; bonuses.control_damage_add=5
damage={}; assert(defs.frost_nova.cast(user,nil,defs.frost_nova)); assert(#damage==2)
assert(damage[1].opts.action_id==damage[2].opts.action_id)

objects={ally,player("ally2")}; bonuses.flash_heal_splash=65
heals={}; assert(defs.flash_heal.cast(user,{type="object",ref=ally},defs.flash_heal)); assert(#heals==2)
assert(heals[1].opts.action_id==heals[2].opts.action_id)

bonuses.smite_absorb=9; objects={enemy}; damage={}
assert(defs.smite.cast(user,nil,defs.smite)); assert(absorbs[#absorbs][2]=="recompense")

bonuses.dodge_chance_window=15; objects={ally}
assert(defs.power_word_shield.cast(user,{type="object",ref=ally},defs.power_word_shield))
assert(statuses.turn_aside.modifiers.dodge_percent==15)

-- Friendly fallback remains self when no pointed ally or memory exists.
statuses.renew=nil; assert(defs.renew.cast(user,nil,defs.renew)); assert(statuses.renew)

io.write("WP11 X3 behavior KAT: OK\n")
