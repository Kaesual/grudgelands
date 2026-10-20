-- The Warrior's kit (docs/design/classes.md §3; round53-plan.md §4 WARRIOR,
-- docs/planning/class-redesign/warrior.md under skill-inventory.md §4.2),
-- dofiled from kits.lua with its shared helpers (K). Strike and Charge are
-- the starters; everything else comes from the Bulwark and Ruin graph
-- (grug_classes talent_graph_warrior.lua), whose class keys name their
-- consumers here.
--
-- Units: S is a Strike hit before the one scaling pass, the weapon's damage
-- plus the melee bonus (a swing's ctx); pool shares are % of the base pool
-- times the support factor (K.support_value); armor is a share of the
-- level's armor constant (grug_core.armor_k) as raw rating points.
return function(K)
local mob_ent, current_enemy_target = K.mob_ent, K.current_enemy_target
local effective_number, effective_support_number = K.effective_number,
	K.effective_support_number
local support_value, family_bonus = K.support_value, K.family_bonus
local target_filter, fx, facing = K.target_filter, K.fx, K.facing

-- Self casts occupy the warrior for 0.35 s on both clocks (warrior.md §2,
-- skill-inventory.md §3 item 7): no cast and no swing inside it, and the
-- swing timer is kept, not reset (strike_delay never shortens it).
local SELF_CAST = 0.35

local function bonus(user, key)
	return grug_classes.get_talent_bonus(user, key)
end

-- S with the equipped melee weapon now, for the tooltips (the swing itself
-- reads its own ctx).
local function strike_unit(user)
	local damage = grug_abilities.swing_stats(user)
	return damage + grug_classes.get_melee_bonus(user)
end

local function percent(coef)
	return ("%g"):format(math.floor(coef * 100 + 0.5))
end

-- Ruination's window (below): +15 % on every swing while it is open.
local RUINATION_MULT = 1.15

--
-- Charge (starter). The dash and its arrival (damage, rage, the 0.75 s stun,
-- Halt's slow, Reach the Fight's rage) are charge.lua's.
--
grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	kind = "cast",
	target_kind = "hostile",
	description = "Dash to an enemy up to 12 m away; damage scales with your level\n" ..
		"generating 15 rage and stunning eligible targets for 0.75 s.",
	-- 12 % of a base hit before the damage scalar (Round 35): the former flat
	-- 3 was exactly that at level 30 and faded with every level above it.
	values = function(user)
		return {damage = 0.12 * grug_core.baseline_melee_total(
			math.max(1, math.min(60, grug_core.get_player_level(user)))),
			rage = 15 + bonus(user, "charge_rage_add"),
			slow = bonus(user, "charge_slow_percent")}
	end,
	description_for = function(user, def)
		local v = def.values(user)
		local text = ("Dash to an enemy up to 12 m away, dealing %d damage\n" ..
			"generating %d rage and stunning eligible targets for 0.75 s."):format(
				effective_number(user, v.damage), v.rage)
		if v.slow > 0 then
			text = text .. ("\nThen slows them by %d%% for 2 s."):format(v.slow)
		end
		return text
	end,
	color = "#e8c85a",
	cost = {},
	-- Onset is the family key cooldown_sub:charge (effective_cooldown).
	cooldown = 10,
	range = 12,
	-- The calculator's occupied time (round53-plan.md K9: on both sides).
	occupied_cast = 0.75,
	occupied_swing = 0.75,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		-- Room is checked with the real player box (blink.lua); a target in
		-- a one-node gap must not pull the caster into the terrain beside it.
		-- A false return costs neither rage nor cooldown (try_cast).
		local props = user:get_properties()
		local tbox = target:get_properties().collisionbox
		local tpos = target:get_pos()
		local dest = grug_abilities.charge_destination(user:get_pos(),
			props.eye_height or 1.47,
			props.collisionbox or {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			vector.offset(tpos, 0, tbox and tbox[2] or 0, 0))
		if not dest then
			return false, "Not enough room at target."
		end
		-- The dash (charge.lua): damage, stun, rage and the dust ring land on
		-- arrival within reach; a dash that ends short is a miss, and the
		-- cooldown is spent either way.
		return grug_abilities.charge_dash(user, target, dest, def)
	end,
})

-- The dust trail of a Charge dash (charge.lua): dust kicked up along the
-- ground from `from` to `to` (feet positions) over `duration` seconds, an
-- unattached spawner of at most 1 s (the helper caps the time, so for a dash
-- longer than 1 s the dust would run ahead of the warrior: call it per piece
-- of at most 1 s). The dash plays it per run segment and its arrival ring
-- on arrival.
function grug_abilities.charge_dust(from, to, duration)
	fx("charge_dust", {from = vector.offset(from, 0, 0.1, 0),
		to = vector.offset(to, 0, 0.1, 0), time = duration})
end

--
-- Bulwark.
--

-- Retort (B1) replaces Strike in place: an ordinary swing at the weapon's
-- cadence that a hostile hit which took health readies (the window
-- "retort", 4 s, one charge, 6 s ICD) for +0.25 S (Measured Answer +0.05
-- per rank); a landed readied Retort heals flat (Recover). Its readiness
-- lives only in the window and the swing callback below, never in a charge
-- or a cost: a refused basic attack has no fallback (K8), so a held LMB must
-- always swing.
local RETORT_WINDOW, RETORT_ICD, RETORT_BONUS = 4, 6, 0.25

local function retort_bonus(user)
	return RETORT_BONUS + bonus(user, "retort_bonus_add")
end

local function retort_heal(user)
	local heal = bonus(user, "retort_heal_percent")
	return heal > 0 and support_value(user, heal) or 0
end

local function retort_values(user)
	return {bonus = retort_bonus(user), heal = retort_heal(user)}
end

grug_abilities.register_ability({
	id = "retort",
	class = "warrior",
	name = "Retort",
	kind = "swing",
	target_kind = "hostile",
	talent_gated = true,
	talent = "bulwark_retort",
	transforms = "strike",
	description = "A full melee swing with your equipped weapon. A hostile hit that " ..
		"takes your health readies the next Retort within 4 s for extra damage " ..
		"(at most every 6 s).",
	values = retort_values,
	description_for = function(user, def)
		local v = def.values(user)
		local rage = ("%.1f"):format(grug_abilities.swing_rage(user))
		local text = ("A full melee swing with your equipped weapon; generates %s rage " ..
			"when it lands.\nA hostile hit that takes your health readies the next " ..
			"Retort within 4 s: +%s%% of a Strike hit (%d damage); at most every 6 s."):format(
				(rage:gsub("%.0$", "")), percent(v.bonus),
				effective_number(user, v.bonus * strike_unit(user)))
		if v.heal > 0 then
			text = text .. ("\nA readied Retort that lands heals you for %d."):format(
				effective_support_number(v.heal))
		end
		return text
	end,
	color = "#c4ccd6",
	cost = {},
	melee = true,
	range = 3,
})

-- A hostile hit that took health (the settled-hit hook: not dodged, not
-- fully absorbed, not lethal) readies Retort.
grug_core.register_on_settled_incoming_hit(function(player, amount, reason)
	if grug_classes.talent_rank(player, "bulwark_retort") > 0 and
			reason.object ~= player and
			grug_classes.open_window(player, "retort",
				{duration = RETORT_WINDOW, icd = RETORT_ICD, label = "Retort"}) then
		grug_core.proc_flash(player, "retort")
	end
end)

-- Hold Ground (B4): a shield of 12 % of the base pool for 5 s (Layered
-- Guard adds), no immunity; recasting replaces its own shield.
grug_abilities.register_ability({
	id = "hold_ground", class = "warrior", talent_gated = true, talent = "bulwark_hold_ground",
	kind = "cast", target_kind = "self", name = "Hold Ground",
	description = "Spend 25 rage for a shield that absorbs damage for 5 s.",
	color = "#c89b55", cost = {rage = 25}, cooldown = 24, range = 4,
	occupied_cast = SELF_CAST, occupied_swing = SELF_CAST,
	values = function(user)
		return {absorb = support_value(user, 12 + bonus(user, "hold_ground_absorb_add")),
			duration = 5}
	end,
	description_for = function(user, def)
		local v = def.values(user)
		return ("Spend 25 rage for a shield that absorbs %d damage for %g s."):format(
			effective_support_number(v.absorb), v.duration)
	end,
	cast = function(user, pointed, def)
		local v = def.values(user)
		grug_core.add_absorb(user, "hold_ground", v.absorb, v.duration, user, {})
		fx("hold_ground", {caster = user:get_pos()})
		return true
	end,
})

-- Taunt (B7): one mob within 8 m attacks you for 3 s (grug_core.taunt).
grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	kind = "cast",
	target_kind = "hostile",
	talent_gated = true,
	talent = "bulwark_taunt",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	range = 8,
	occupied_cast = SELF_CAST,
	occupied_swing = SELF_CAST,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local ent = mob_ent(target)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		-- Threat part (combat_stats.md §4): sets the taunter to top×1.1 and
		-- suppresses hysteresis target switches for 3 s.
		if not grug_core.taunt(ent, user) then
			return false, "That target cannot be taunted now."
		end
		ent:do_attack(user, true)
		fx("taunt", {target = target:get_pos()})
		return true
	end,
})

-- Bellow (B9) replaces Taunt in place: every mob within 6 m around you, in
-- sight (area.query around the caster, filtered by valid_target), with
-- Taunt's cooldown key.
local BELLOW_RADIUS = 6
grug_abilities.register_ability({
	id = "bellow",
	class = "warrior",
	name = "Bellow",
	kind = "cast",
	target_kind = "self",
	talent_gated = true,
	talent = "bulwark_bellow",
	transforms = "taunt",
	description = "Forces every mob within 6 m around you to attack you.",
	color = "#c4ccd6",
	cost = {},
	cooldown = 8,
	range = BELLOW_RADIUS,
	occupied_cast = SELF_CAST,
	occupied_swing = SELF_CAST,
	cast = function(user)
		local hostile = target_filter(user, "hostile")
		local pos = user:get_pos()
		local affected = false
		for _, obj in ipairs(grug_core.area.query(pos, {radius = BELLOW_RADIUS,
				filter = function(obj)
					local ent = mob_ent(obj)
					return ent ~= nil and ent.attack_type ~= nil and hostile(obj)
				end})) do
			local ent = mob_ent(obj)
			if ent and grug_core.taunt(ent, user) then
				ent:do_attack(user, true)
				affected = true
			end
		end
		if not affected then
			return false, "No hostile target in range."
		end
		fx("bellow", {caster = pos, reach = BELLOW_RADIUS})
		return true
	end,
})

-- Unbroken (B12, the ultimate): for 8 s (Enduring Stand adds) +0.50 of the
-- level's armor constant as rating and a shield of 15 % of the base pool
-- that expires with it; no immunity.
local function unbroken_values(user)
	local level = math.max(1, math.min(60, grug_core.get_player_level(user)))
	return {armor = 0.5 * grug_core.armor_k(level),
		absorb = support_value(user, 15),
		duration = 8 + family_bonus(user, grug_abilities.registered.unbroken,
			"duration_add")}
end

grug_abilities.register_ability({
	id = "unbroken", class = "warrior", talent_gated = true, talent = "bulwark_unbroken",
	kind = "cast", target_kind = "self", name = "Unbroken",
	description = "Spend 25 rage: extra armor and a shield for 8 s.",
	color = "#d0a060", cost = {rage = 25}, cooldown = 60, range = 4,
	occupied_cast = SELF_CAST, occupied_swing = SELF_CAST,
	values = unbroken_values,
	description_for = function(user, def)
		local v = def.values(user)
		return ("Spend 25 rage: +%d armor and a shield that absorbs %d damage, " ..
			"both for %g s."):format(math.floor(v.armor + 0.5),
				effective_support_number(v.absorb), v.duration)
	end,
	cast = function(user, pointed, def)
		local v = def.values(user)
		grug_core.set_status(user, "unbroken", {duration = v.duration, label = "Unbroken",
			modifiers = {armor = v.armor}})
		grug_core.add_absorb(user, "unbroken", v.absorb, v.duration, user, {})
		fx("unbroken", {caster = user:get_pos()})
		return true
	end,
})

--
-- Ruin.
--

-- Mighty Blow's and Broadstroke's primary hit: 1.45 S, Heavy Hand's adds,
-- and Finisher's against a target below 30 % health before the swing.
local function health_share(target)
	local ent = mob_ent(target)
	local hp = ent and ent.health or target:get_hp()
	local max_hp = tonumber(target:get_properties().hp_max) or 0
	return max_hp > 0 and hp / max_hp or 1
end

local function blow_coef(user, target)
	local coef = 1.45 + bonus(user, "mighty_blow_unit_add")
	local finisher = bonus(user, "finisher_unit_add")
	if finisher > 0 and target and health_share(target) < 0.3 then
		coef = coef + finisher
	end
	return coef
end

-- Relentless: rage off both forms' 25 (effective_cost, on the swing path
-- too).
local function blow_cost(player, def, cost)
	cost.rage = math.max(0, (cost.rage or 0) - bonus(player, "mighty_blow_cost_sub"))
	return cost
end

local function blow_description(user, def, extra)
	local coef = blow_coef(user)
	local text = ("A heavy melee hit for %s%% of a Strike hit (%d damage). Rides along " ..
		"on a landed swing whenever you have the rage."):format(percent(coef),
			effective_number(user, coef * strike_unit(user)))
	local finisher = bonus(user, "finisher_unit_add")
	if finisher > 0 then
		text = text .. ("\n+%s%% of a Strike hit against a target below 30%% health."):format(
			percent(finisher))
	end
	return extra and text .. "\n" .. extra or text
end

-- The rage dump: no own cooldown, the rage cost is the limiter (a proc
-- replaces one swing on the same cadence).
grug_abilities.register_ability({
	id = "mighty_blow",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Mighty Blow",
	talent_gated = true,
	talent = "ruin_mighty_blow",
	description = "A heavy melee hit: 145% of a Strike hit. Rides along on a landed swing whenever you have the rage.",
	description_for = function(user, def) return blow_description(user, def) end,
	color = "#c84a32",
	cost = {rage = 25},
	cost_adjust = blow_cost,
	-- Melee at 3 m, so the elf's +5 m ability range does not apply (E7).
	melee = true,
	range = 3,
	-- The proc REPLACES the plain hit (classes.md §3), x3 threat.
	proc_swing = function(user, target, ctx)
		local tpos = target:get_pos() -- before the punch (lethal invalidates refs)
		local damage = blow_coef(user, target) * (ctx.weapon_damage + ctx.melee_bonus)
		return damage, 3, function()
			fx("mighty_blow", {caster = user:get_pos(), target = tpos, dir = facing(user)})
		end
	end,
})

-- Broadstroke (U7) replaces Mighty Blow in place: the same primary hit, and
-- at most 2 other hostiles in a 100 degree, 3 m arc in front (area.cone,
-- nearest first, in sight, valid_target) take 0.35 S each (Follow Through
-- adds); they may crit and gain no rage (ability damage). Ruination's +15 %
-- reaches them too.
local BROAD_RADIUS, BROAD_ANGLE, BROAD_CAP, BROAD_SECONDARY = 3, 100, 2, 0.35

local function secondary_coef(user)
	return BROAD_SECONDARY + bonus(user, "broadstroke_secondary_add")
end

grug_abilities.register_ability({
	id = "broadstroke",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Broadstroke",
	talent_gated = true,
	talent = "ruin_broadstroke",
	transforms = "mighty_blow",
	description = "Mighty Blow's hit, and up to 2 others in a wide arc in front of you " ..
		"take 35% of a Strike hit.",
	description_for = function(user, def)
		local coef = secondary_coef(user)
		return blow_description(user, def, ("Up to %d others in a %d degree, %d m arc " ..
			"in front of you take %s%% of a Strike hit (%d damage)."):format(BROAD_CAP,
				BROAD_ANGLE, BROAD_RADIUS, percent(coef),
				effective_number(user, coef * strike_unit(user))))
	end,
	color = "#d8263a",
	cost = {rage = 25},
	cost_adjust = blow_cost,
	melee = true,
	range = 3,
	proc_swing = function(user, target, ctx)
		local tpos = target:get_pos()
		local unit = ctx.weapon_damage + ctx.melee_bonus
		local damage = blow_coef(user, target) * unit
		return damage, 3, function(action_id)
			fx("broadstroke", {caster = user:get_pos(), target = tpos, dir = facing(user)})
			local hostile = target_filter(user, "hostile")
			local others = grug_core.area.cone(user, {radius = BROAD_RADIUS,
				angle = BROAD_ANGLE, cap = BROAD_CAP,
				filter = function(obj) return obj ~= target and hostile(obj) end})
			if #others == 0 then
				return
			end
			local amount = secondary_coef(user) * unit
			if grug_classes.get_window(user, "ruination") then
				amount = amount * RUINATION_MULT
			end
			for _, obj in ipairs(others) do
				grug_core.deal_ability_damage(user, obj, amount,
					{threat_mult = 3, action_id = action_id})
			end
		end
	end,
})

-- Hamstring (U4): a full Strike hit that slows by 35 % for 3 s (Clean Cut
-- adds); charges over 8 s. `post` runs only on a LANDED swing, so a dodged
-- Hamstring does not snare.
local HAMSTRING_SLOW, HAMSTRING_TIME = 0.35, 3

grug_abilities.register_ability({
	id = "hamstring",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Hamstring",
	talent_gated = true,
	talent = "ruin_hamstring",
	description = "A landed swing cripples: slows the enemy by 35% for 3 s. Charges over 8 s.",
	description_for = function(user, def)
		return ("A landed swing cripples: slows the enemy by 35%% for %g s. " ..
			"Charges over 8 s."):format(HAMSTRING_TIME + family_bonus(user, def, "duration_add"))
	end,
	color = "#a8324e",
	charge = 8,
	cost = {rage = 10},
	-- Melee at 3 m: same elf-range rule as Mighty Blow above (E7).
	melee = true,
	range = 3,
	proc_swing = function(user, target, ctx)
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		return ctx.weapon_damage + ctx.melee_bonus, 3, function()
			local slow_time = HAMSTRING_TIME + family_bonus(user,
				grug_abilities.registered.hamstring, "duration_add")
			if ent then
				grug_mobs.slow(ent, slow_time, 1 - HAMSTRING_SLOW)
			elseif target:get_hp() > 0 then
				grug_core.set_move_modifier(target, "hamstring", {speed = -HAMSTRING_SLOW},
					slow_time)
			end
			fx("hamstring", {target = tpos, dir = facing(user)})
		end
	end,
})

-- Ruination (U12, the ultimate): for 8 s (Long Fury adds) every swing deals
-- +15 % (a multiplier on its raw damage, proc included) and each landed one
-- gives 2 more rage; the window "ruination" shows its status.
grug_abilities.register_ability({
	id = "ruination", class = "warrior", talent_gated = true, talent = "ruin_ruination",
	kind = "cast", target_kind = "self", name = "Ruination",
	description = "Spend 20 rage: for 8 s your swings deal 15% more damage and each " ..
		"landed swing gives 2 more rage.",
	description_for = function(user, def)
		return ("Spend 20 rage: for %g s your swings deal 15%% more damage and each " ..
			"landed swing gives 2 more rage."):format(8 + family_bonus(user, def, "duration_add"))
	end,
	color = "#e8402a", cost = {rage = 20}, cooldown = 60, range = 4,
	occupied_cast = SELF_CAST, occupied_swing = SELF_CAST,
	cast = function(user, pointed, def)
		if not grug_classes.open_window(user, "ruination", {label = "Ruination",
				duration = 8 + family_bonus(user, def, "duration_add")}) then
			return false, "Ruination cannot start now."
		end
		fx("ruination", {caster = user:get_pos()})
		return true
	end,
})

-- What the Warrior's windows add to a swing (the swing callback, once per
-- due swing of any player: two table reads when no window is open).
-- Ruination: every swing x1.15 and +2 rage when it lands. Retort: a readied
-- Retort swing x(1 + its bonus), which equals +bonus S on its plain swing;
-- landing consumes the window and heals (Recover, no crit).
grug_abilities.register_on_swing(function(player, swing)
	local ruination = grug_classes.get_window(player, "ruination")
	local retort = swing.def.id == "retort" and grug_classes.get_window(player, "retort")
	if not ruination and not retort then
		return nil
	end
	local tpos = swing.target and swing.target:get_pos()
	local mult = ruination and RUINATION_MULT or 1
	if retort then
		mult = mult * (1 + retort_bonus(player))
	end
	return {damage_mult = mult, rage_add = ruination and 2 or 0,
		on_landed = function(user)
			if retort and grug_classes.consume_window(user, "retort") then
				local heal = retort_heal(user)
				if heal > 0 then
					grug_core.heal_player(user, user, heal, {no_crit = true})
				end
				fx("retort_hit", {target = tpos})
			end
			if ruination then
				fx("ruination_swing", {target = tpos})
			end
		end}
end)
end
