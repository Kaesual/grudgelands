-- The Priest's kit (docs/design/classes.md §5), dofiled from kits.lua with
-- its shared helpers (K).
return function(K)
local current_enemy_target, effective_number = K.current_enemy_target, K.effective_number
local effective_support_number = K.effective_support_number
local spell_damage_value, support_value = K.spell_damage_value, K.support_value
local talent_rank_value, fx = K.talent_rank_value, K.fx

--
-- Priest (mana)
--

-- Recompense's internal cooldown: player name -> next us time it may grant.
local RECOMPENSE_ICD = 6
local recompense_ready = {}

grug_abilities.register_ability({
	id = "smite",
	class = "priest",
	name = "Smite",
	kind = "cast",
	target_kind = "hostile",
	description = "Smites an enemy up to 20 m away; damage scales with your " ..
		"level and your staff or wand.",
	values = function(user, assume_shielded)
		local damage = (grug_abilities.spell_base(user)
			+ grug_classes.get_spell_power_bonus(user)) * 1.5
			+ grug_classes.get_talent_bonus(user, "smite_damage_add")
		if assume_shielded == nil then
			assume_shielded = grug_core.get_absorb(user) > 0
		end
		if assume_shielded then
			damage = damage + grug_classes.get_talent_bonus(user,
				"smite_damage_while_shielded_add")
		end
		return {damage = spell_damage_value(user, damage)}
	end,
	description_for = function(user, def)
		local unshielded = effective_number(user,
			def.values(user, false).damage)
		local shielded = effective_number(user,
			def.values(user, true).damage)
		local suffix = ""
		if shielded > unshielded then
			suffix = (" (+%d while shielded)"):format(shielded - unshielded)
		end
		return ("Smites an enemy up to 20 m away for %d damage%s,\n" ..
			"from your level and your staff or wand."):format(unshielded, suffix)
	end,
	color = "#ffd97a",
	cost = {mana_percent = 5},
	cooldown = 2,
	cooldown_talent = "smite_cooldown_sub", -- Swift Word (skill_trees.md §2.6)
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		-- No projectile: the holy fall on the target (replaces the beam).
		fx("smite", {target = target:get_pos()})
		-- Sharpened Word, and Warded Wrath while an absorb is up
		-- (skill_trees.md §2.6). Recompense's absorb has a 6 s internal
		-- cooldown (Round 35): refreshed on every Smite it outlasted the damage
		-- of two same-level mobs.
		local absorb = grug_classes.get_talent_bonus(user, "smite_absorb")
		grug_core.deal_ability_damage(user, target, def.values(user).damage, {
			on_accepted = function(_, _, action_id)
				local name = user:get_player_name()
				local now = core.get_us_time()
				if absorb > 0 and now >= (recompense_ready[name] or 0) then
					recompense_ready[name] = now + RECOMPENSE_ICD * 1e6
					grug_core.add_absorb(user, "recompense", support_value(user, absorb),
						15, user, action_id)
				end
			end,
		})
		return true
	end,
})

grug_abilities.register_ability({
	id = "heal",
	class = "priest",
	name = "Heal",
	kind = "cast",
	target_kind = "friendly",
	description = "Heals the pointed ally (or yourself); healing scales with your level.",
	values = function(user)
		return {
			heal = support_value(user, 25
				+ grug_classes.get_talent_bonus(user, "heal_add")),
		}
	end,
	description_for = function(user, def)
		return ("Heals the pointed ally (or yourself) for %d."):format(
			effective_support_number(def.values(user).heal))
	end,
	color = "#7ae08a",
	cost = {mana_percent = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Gentle Hand (skill_trees.md §2.5); Hearten's splash is lane X3's.
		local amount = def.values(user).heal
		local action_id = {}
		-- Effective support on a player in PvP combat is PvP contact for the
		-- healer (pvp-plan ruling 7b); valid_target already refused a flagged
		-- ally to an unflagged healer, the splash included (ruling 6).
		if grug_core.heal_player(user, target, amount,
				{action_id = action_id}) > 0 then
			grug_pvp.support_contact(user, target)
		end
		local splash = grug_classes.get_talent_bonus(user, "heal_splash")
		if splash > 0 then
			for _, obj in ipairs(core.get_objects_inside_radius(target:get_pos(), 8)) do
				if obj ~= target and grug_abilities.valid_target(user, obj, "friendly") then
					-- Hearten: four motes on each splashed ally.
					fx("heal_splash", {target = obj:get_pos()})
					if grug_core.heal_player(user, obj, math.floor(amount * splash / 100),
							{action_id = action_id}) > 0 then
						grug_pvp.support_contact(user, obj)
					end
				end
			end
		end
		fx("heal", {target = target:get_pos()})
		return true
	end,
})

-- Base-kit shield (kit tuning 2026-08-06, replaces Mend): an absorb
-- plays differently from a second heal and makes the Priest useful
-- BEFORE damage lands. The soak itself lives in grug_core's central hp
-- change modifier (grug_core.add_absorb).
grug_abilities.register_ability({
	id = "shield_spell",
	class = "priest",
	name = "Shield",
	kind = "cast",
	target_kind = "friendly",
	description = "Wraps the pointed ally (or yourself) in a magic shield;\n" ..
		"absorption scales with your level and lasts 15 s or until consumed.",
	values = function(user)
		return {
			absorb = support_value(user, 25
				+ grug_classes.get_talent_bonus(user, "shield_absorb_add")),
		}
	end,
	description_for = function(user, def)
		return ("Wraps the pointed ally (or yourself) in a magic shield that\n" ..
			"absorbs %d damage for 15 s or until consumed."):format(
				effective_support_number(def.values(user).absorb))
	end,
	color = "#e8e07a",
	cost = {mana_percent = 8},
	cooldown = 10,
	cooldown_talent = "shield_cooldown_sub", -- Second Skin (skill_trees.md §2.5)
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Warding Faith (skill_trees.md §2.5) adds base-pool points; Second
		-- Skin shortens the cooldown through cooldown_talent. Turn Aside's
		-- dodge window is lane X3's.
		if grug_core.add_absorb(target, "shield_spell", def.values(user).absorb,
				15, user, {},
				{dodge_percent = talent_rank_value(user, "turn_aside", "dodge_chance_window", 0)})
				> 0 then
			grug_pvp.support_contact(user, target)
		end
		fx("shield_spell", {target = target:get_pos()})
		return true
	end,
})

-- Active mends: target name -> {ticks, amount, healer}
local mends = {}

-- Talent-gated (kit tuning 2026-08-06): stays registered, but sync_kit
-- does not grant it — the Priest's Mercy tree unlocks it in WP11, where Mend
-- is the Balm chain's keystone (skill_trees.md §2.5). Its display name lives
-- on that keystone only, so a rename is one line in talents.lua.
grug_abilities.register_ability({
	id = "mend",
	class = "priest",
	name = grug_classes.registered_talents.mend.name,
	kind = "cast",
	target_kind = "friendly",
	talent_gated = true,
	description = "Heal over time on the pointed ally (or yourself); healing\n" ..
		"scales with your level every 3 s for 12 s.\nUnlocked via talents.",
	values = function(user)
		return {heal = support_value(user, 8
			+ grug_classes.get_talent_bonus(user, "mend_tick_add"))}
	end,
	description_for = function(user, def)
		return ("Heal the pointed ally (or yourself) for %d every 3 s for 12 s.\n" ..
			"Unlocked via talents."):format(
				effective_support_number(def.values(user).heal))
	end,
	color = "#3fae6a",
	cost = {mana_percent = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		mends[target:get_player_name()] = {
			ticks = 4,
			amount = def.values(user).heal,
			healer = user:get_player_name(),
			action_id = {},
		}
		if grug_core.set_status then
			grug_core.set_status(target, "mend", {
				label = def.name,
				duration = 12,
				kind = "buff",
			})
		end
		-- The cast is the application; the ticks are never contact (ruling 7b).
		grug_pvp.support_contact(user, target)
		fx("mend", {target = target:get_pos()})
		return true
	end,
})

local mend_acc = 0

core.register_globalstep(function(dtime)
	mend_acc = mend_acc + dtime
	if mend_acc < 3 then
		return
	end
	mend_acc = 0
	for name, mend in pairs(mends) do
		local target = core.get_player_by_name(name)
		if not target or target:get_hp() <= 0 then
			mends[name] = nil
			if target and grug_core.clear_status then
				grug_core.clear_status(target, "mend")
			end
		else
			local healer = core.get_player_by_name(mend.healer) or target
			grug_core.heal_player(healer, target, mend.amount,
				{action_id = mend.action_id})
			fx("mend", {target = target:get_pos()})
			mend.ticks = mend.ticks - 1
			if mend.ticks <= 0 then
				mends[name] = nil
				if grug_core.clear_status then
					grug_core.clear_status(target, "mend")
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	mends[player:get_player_name()] = nil
	recompense_ready[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	mends[player:get_player_name()] = nil
end)

grug_abilities.register_ability({
	id = "word_of_ruin", class = "priest", talent_gated = true,
	kind = "cast", target_kind = "hostile", name = "Word of Ruin",
	description = "Damage the aimed enemy and heal yourself from the damage.",
	color = "#a66bd4", cost = {mana_percent = 8}, cooldown = 12, range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then return false, "No hostile target in your crosshair." end
		fx("word_of_ruin", {caster = user:get_pos(), target = target:get_pos()})
		local damage = spell_damage_value(user,
			grug_classes.get_talent_bonus(user, "word_of_ruin_damage")
			+ grug_classes.get_spell_power_bonus(user))
		grug_core.deal_ability_damage(user, target, damage, {
			on_accepted = function(dealt, _, action_id)
				local properties = user:get_properties() or {}
				if user:get_hp() < (tonumber(properties.hp_max) or 0) * 0.25 and
						grug_classes.try_trigger_talent_window(user, "last_word", 12, 180) then
					grug_core.proc_flash(user, "last_word")
					-- The trigger also resets Word of Ruin's cooldown (Round 35).
					-- try_cast arms the cooldown after this cast returns, so the
					-- reset runs on the next server step.
					local name = user:get_player_name()
					core.after(0, function()
						local player = core.get_player_by_name(name)
						if player then
							grug_abilities.clear_cooldown(player, "word_of_ruin")
						end
					end)
				end
				local ratio = grug_classes.get_talent_bonus(user, "drain_ratio_override")
				if ratio <= 0 then ratio = 50 end
				grug_core.heal_player(user, user, math.floor(dealt * ratio / 100),
					{no_crit = true, action_id = action_id})
			end,
		})
		return true
	end,
})
end
