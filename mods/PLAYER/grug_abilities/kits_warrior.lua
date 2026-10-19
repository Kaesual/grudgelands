-- The Warrior's kit (docs/design/classes.md §3), dofiled from kits.lua with
-- its shared helpers (K).
return function(K)
local mob_ent, current_enemy_target = K.mob_ent, K.current_enemy_target
local effective_number, fx, facing = K.effective_number, K.fx, K.facing

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	kind = "cast",
	target_kind = "hostile",
	description = "Dash to an enemy up to 12 m away; damage scales with your level\n" ..
		"generating 15 rage and stunning eligible targets for 1.5 s.",
	-- 12 % of a base hit before the damage scalar (Round 35): the former flat
	-- 3 was exactly that at level 30 and faded with every level above it.
	values = function(user)
		return {damage = 0.12 * grug_core.baseline_melee_total(
			math.max(1, math.min(60, grug_core.get_player_level(user))))}
	end,
	description_for = function(user, def)
		return ("Dash to an enemy up to 12 m away, dealing %d damage\n" ..
			"generating 15 rage and stunning eligible targets for 1.5 s."):format(
				effective_number(user, def.values(user).damage))
	end,
	color = "#e8c85a",
	cost = {},
	cooldown = 10,
	-- Onset (skill_trees.md §2.2). The field names the effect key; the read
	-- itself is grug_abilities.effective_cooldown, because `cooldown` here is
	-- evaluated once at load time with no player in scope (§3.2).
	cooldown_talent = "charge_cooldown_sub",
	range = 12,
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

-- The rage dump (kit tuning 2026-08-06): no own cooldown — at the rage
-- income of the day a cooldown left the Warrior permanently rage-capped.
-- Ruling 25 (2026-09-16) lowered that income to 8 per landed swing, so
-- this now procs about every fourth swing rather than every other one; since
-- Round 46 the grant scales with the weapon's swing interval, so that is
-- about every 3 s with every weapon.
grug_abilities.register_ability({
	id = "mighty_blow",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your melee bonus. Rides along on a landed swing whenever you have the rage.",
	color = "#c84a32",
	cost = {rage = 25},
	-- Melee at 3 m, so the elf's +5 m ability range does not apply (E7). This
	-- was a PRE-EXISTING bug, not something the weapon slot introduced: the
	-- perk was written as "+5 m on every ability" and gave elves an 8 m reach on
	-- a hit that is supposed to be within arm's length. The flag is all it
	-- takes -- grug_abilities.get_range honours it, and sync_kit derives the
	-- stack's `range` meta from get_range, so the engine's pointing reach and
	-- the target-lock fallback move together.
	melee = true,
	range = 3,
	-- The proc REPLACES the plain hit (classes.md §3): floor(weapon x 1.5) +
	-- melee bonus, x3 threat. No charge timer -- the rage cost IS the limiter
	-- (about every fourth sword swing at the ruling-25 income of +8 per
	-- landed hit, about every 3 s with any weapon since Round 46; it was
	-- every other swing at the old +12).
	proc_swing = function(user, target, ctx)
		local tpos = target:get_pos() -- before the punch (lethal invalidates refs)
		-- Heavy Hand (skill_trees.md §2.2): +0.1 weapon-damage multiplier per
		-- rank; 1.5 exactly without it. Broadstroke's cleave is lane X3's.
		local mult = 1.5 + grug_classes.get_talent_bonus(user,
			"mighty_blow_multiplier_add")
		local damage = math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus
		return damage, 3, function(action_id)
			fx("mighty_blow", {caster = user:get_pos(), target = tpos, dir = facing(user)})
			if grug_classes.get_talent_bonus(user, "mighty_blow_cleave") > 0 then
				for _, obj in ipairs(core.get_objects_inside_radius(tpos, 3)) do
					if obj ~= target and grug_abilities.valid_target(user, obj, "hostile") then
						grug_core.deal_ability_damage(user, obj,
							math.floor(damage / 2), {threat_mult = 3, action_id = action_id})
					end
				end
			end
			if grug_classes.try_trigger_talent_window(user, "ruination", 15, 60) then
				grug_core.proc_flash(user, "ruination")
			end
		end
	end,
})

-- The control tool (kit tuning 2026-08-06): in an engine where mobs
-- outrun players, the snare is the Warrior's identity.
--
-- TALENT-GATED since ruling 19 (2026-09-16, skill_trees.md §2.2/§3.4): every
-- class starts with Strike plus three, so Hamstring leaves the Warrior's base
-- kit and returns as Ruin's new-skill keystone (talent `hamstring`): a
-- Warrior has it once that talent has a rank (grug_abilities.is_unlocked,
-- the same predicate that gates Mend).
grug_abilities.register_ability({
	id = "hamstring",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Hamstring",
	talent_gated = true,
	description = "A landed swing cripples: slows the enemy by 50% for 5 s. Charges over 6 s.\nUnlocked via talents.",
	color = "#a8324e",
	charge = 6,
	cost = {rage = 10},
	-- Melee at 3 m: same pre-existing elf-range bug as Mighty Blow above, same
	-- one-flag fix (E7).
	melee = true,
	range = 3,
	-- The swing lands as usual; the proc adds the slow (classes.md §3).
	-- `post` runs only on a LANDED swing, so a dodged Hamstring does not
	-- snare (the old cast's dealt > 0 gate).
	proc_swing = function(user, target, ctx)
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		return ctx.weapon_damage + ctx.melee_bonus, 3, function()
			local slow_time = 5 + grug_classes.get_talent_bonus(user,
				"hamstring_slow_add")
			local root_time = grug_classes.get_talent_bonus(user, "hamstring_root")
			if root_time > 0 and not grug_classes.talent_trigger_ready(user,
					"tendon_cut", 12) then root_time = 0 end
			if ent then
				if root_time > 0 then grug_mobs.root(ent, root_time) end
				grug_mobs.slow(ent, slow_time, 0.5)
			elseif target:get_hp() > 0 then
				if root_time > 0 then grug_core.set_root(target, root_time) end
				grug_core.set_move_modifier(target, "hamstring", {speed = -0.5},
					root_time + slow_time)
			end
			fx("hamstring", {target = tpos, dir = facing(user)})
		end
	end,
})

grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	kind = "cast",
	target_kind = "hostile",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	cooldown_talent = "taunt_cooldown_sub", -- Grudge (skill_trees.md §2.1)
	range = 8,
	cast = function(user, pointed, def)
		local radius = grug_classes.get_talent_bonus(user, "taunt_radius")
		if radius > 0 then
			local affected = false
			for _, obj in ipairs(core.get_objects_inside_radius(user:get_pos(), radius)) do
				if grug_abilities.valid_target(user, obj, "hostile") then
					local ent = mob_ent(obj)
					if ent and ent.attack_type and grug_core.taunt(ent, user) then
						ent:do_attack(user, true); affected = true
					end
				end
			end
			if affected then
				fx("bellow", {caster = user:get_pos(), reach = radius})
			end
			return affected, affected and nil or "No hostile target in range."
		end
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

grug_abilities.register_ability({
	id = "hold_ground", class = "warrior", talent_gated = true,
	kind = "cast", target_kind = "self", name = "Hold Ground",
	description = "Spend 25 rage to gain an absorb and root/slow immunity for 8 s.",
	color = "#c89b55", cost = {rage = 25}, cooldown = 60, range = 4,
	values = function(user)
		return {absorb = grug_core.base_pool(grug_core.get_player_level(user))
			* grug_classes.get_talent_bonus(user, "hold_ground_absorb") / 100}
	end,
	cast = function(user, pointed, def)
		grug_core.add_absorb(user, "hold_ground", def.values(user).absorb, 8,
			user, {})
		grug_core.set_move_immunity(user, 8)
		grug_classes.start_talent_window(user, "hold_ground", 8)
		fx("hold_ground", {caster = user:get_pos()})
		return true
	end,
})
end
