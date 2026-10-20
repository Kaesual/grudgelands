-- The Priest's kit (round53-plan.md §4 PRIEST; class-redesign/skill-inventory.md
-- §4.3 and node-list.md Mercy and Reckoning), dofiled from kits.lua with its
-- shared helpers (K). The numbers are the balance calculator's frozen builds
-- (priest_mercy, priest_reckoning) with the untalented bases derived as the
-- full-build totals minus the full ranks (round53-plan.md §3):
--   Smite        free, 20 m, a 1 s cast interval, the spell unit (W + I)
--   Heal         25 % of the pool x Q, 10 % mana, 5 s, no crit
--   Shield       24 % x Q for 10 s, 9 % mana, 12 s
--   Mend         4 ticks of 7 % x Q every 3 s, 8 % mana, 12 s
--   Hearten      15 % x Q to you and up to 3 allies within 6 m, 14 % mana, 20 s
--   Haven        6 ticks of 7 % x Q every 2 s to you and up to 4 allies
--                within 8 m, 22 % mana, 60 s
--   Rebuke       1.8 units, 6 % mana, 6 s
--   Word of Ruin 1.6 units, heals you half the damage up to 6 % x Q, 10 % mana, 16 s
--   Censure      1.2 units to the 4 nearest within 3 m of a ground anchor
--                after 0.75 s, 12 % mana, 18 s
--   Final Word   2.8 units, 20 % mana, 60 s
-- Every cast occupies the next cast for 1 s, Heal, Hearten, Haven and Final
-- Word for 1.5 s (the calculator's occupied times; Smite occupies its own
-- interval). Support, its ticks and Word of Ruin's heal never crit.
--
-- The talents are the graph's (grug_classes talent_graph_priest.lua): the
-- class keys hold pool points or coefficients of the base hit, the family
-- keys (cost_pct, cooldown_sub, range_add, damage_pct, radius_add,
-- duration_add) are read by the shared cast path and by K.family_bonus.
return function(K)
local current_enemy_target, effective_number = K.current_enemy_target, K.effective_number
local effective_support_number = K.effective_support_number
local spell_damage_value, support_value = K.spell_damage_value, K.support_value
local fx, family_bonus, target_filter = K.fx, K.family_bonus, K.target_filter

local function bonus(user, key)
	return grug_classes.get_talent_bonus(user, key)
end

-- The Priest's spell unit before the level scalar: the spell base (level
-- and caster weapon, Round 46 ruling 10) plus spell power.
local function spell_unit(user)
	return grug_abilities.spell_base(user) + grug_classes.get_spell_power_bonus(user)
end

-- A talent's "+N of a base hit": the coefficient times the same-level base
-- hit (grug_core.baseline_melee_total), following the caster weapon like the
-- spell it adds to (Round 46: the spell base over an own-level weapon's, so an
-- own-level staff or wand keeps the number and no caster weapon halves it).
-- Levels clamp to 1-60, as every level-proof value.
local function base_hit_add(user, coefficient)
	if coefficient == 0 then
		return 0
	end
	local level = math.max(1, math.min(60, math.floor(grug_core.get_player_level(user))))
	return coefficient * grug_core.baseline_melee_total(level)
		* grug_abilities.spell_base(user) / grug_core.spell_base(level, level)
end

-- A hostile hit's raw damage before the level scalar: `coefficient` spell
-- units, Hard Faith's damage_pct on that untalented part, `add` (a base-hit
-- coefficient) on top, then timed spell-damage modifiers.
local function spell_hit(user, def, coefficient, add)
	local untalented = coefficient * spell_unit(user)
	return spell_damage_value(user, untalented * (1 + family_bonus(user, def, "damage_pct") / 100)
		+ base_hit_add(user, add))
end

-- Clear Conscience (M8): a committed Heal, Shield or Mend opens a 5 s window
-- that the next Smite spends; an 8 s internal cooldown from the opening.
local CLEAR_CONSCIENCE = {duration = 5, icd = 8}
local function clear_conscience(user)
	local add = bonus(user, "clear_conscience_add")
	if add > 0 and grug_classes.open_window(user, "clear_conscience", {
			duration = CLEAR_CONSCIENCE.duration, icd = CLEAR_CONSCIENCE.icd,
			value = add, label = "Clear Conscience"}) then
		grug_core.proc_flash(user, "clear_conscience")
	end
end

-- The single friendly target of Heal, Shield and Mend: the ally in the
-- crosshair, else yourself; a refusal names why.
local function support_target(user, pointed, def)
	local target, err = grug_abilities.resolve_friendly_target(user, pointed, def)
	if not target then
		return nil, err
	end
	if target:get_hp() <= 0 then
		return nil, "Target is dead."
	end
	return target
end

--
-- Priest (mana). The order is the catalogue row and the starter hotbar:
-- Smite (in Strike's place), Heal, then the talent skills.
--

-- Smite, the class basic attack (C9): it replaces Strike in place for every
-- Priest and shares its key. Steady Word and Sharpened Word are max-combined
-- (round53-plan.md §3), Clear Conscience's window adds once.
grug_abilities.register_ability({
	id = "smite",
	class = "priest",
	transforms = "strike",
	name = "Smite",
	kind = "cast",
	target_kind = "hostile",
	description = "Smites the enemy in your crosshair; free, once a second. Damage " ..
		"scales with your level and your staff or wand.",
	values = function(user, window)
		local add = math.max(bonus(user, "smite_steady_add"), bonus(user, "smite_sharpened_add"))
			+ (window or 0)
		return {damage = spell_hit(user, grug_abilities.registered.smite, 1, add)}
	end,
	description_for = function(user, def)
		return ("Smites the enemy in your crosshair for %d damage; free, once a second.\n" ..
			"Damage scales with your level and your staff or wand."):format(
				effective_number(user, def.values(user).damage))
	end,
	color = "#ffd97a",
	cost = {},
	cooldown = 0,
	cast_interval = 1,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local window = grug_classes.consume_window(user, "clear_conscience")
		fx("smite_hit", {target = target:get_pos()})
		grug_core.deal_ability_damage(user, target,
			def.values(user, window and window.value).damage, {action_id = {}})
		return true
	end,
})

grug_abilities.register_ability({
	id = "heal",
	class = "priest",
	name = "Heal",
	kind = "cast",
	target_kind = "friendly",
	tags = {"support"},
	description = "Heals the pointed ally (or yourself); healing scales with your level.",
	values = function(user)
		return {heal = support_value(user, 25 + bonus(user, "heal_share_add"))}
	end,
	description_for = function(user, def)
		return ("Heals the pointed ally (or yourself) for %d."):format(
			effective_support_number(def.values(user).heal))
	end,
	color = "#7ae08a",
	cost = {mana_percent = 10},
	cooldown = 5,
	occupied_cast = 1.5,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = support_target(user, pointed, def)
		if not target then
			return false, err
		end
		-- Effective support on a player in PvP combat is PvP contact for the
		-- healer (pvp-plan ruling 7b); valid_target already refused a flagged
		-- ally to an unflagged healer (ruling 6).
		if grug_core.heal_player(user, target, def.values(user).heal,
				{no_crit = true, action_id = {}}) > 0 then
			grug_pvp.support_contact(user, target)
		end
		fx("heal", {target = target:get_pos()})
		clear_conscience(user)
		return true
	end,
})

-- An absorb on one target (B6); the absorb id is per target, so any recast
-- replaces it, whoever cast it.
grug_abilities.register_ability({
	id = "shield_spell",
	class = "priest",
	talent_gated = true,
	talent = "mercy_shield",
	name = "Shield",
	kind = "cast",
	target_kind = "friendly",
	tags = {"support"},
	description = "Wraps the pointed ally (or yourself) in a shield that absorbs\n" ..
		"damage for 10 s; absorption scales with your level.",
	values = function(user)
		return {absorb = support_value(user, 24 + bonus(user, "shield_share_add"))}
	end,
	description_for = function(user, def)
		return ("Wraps the pointed ally (or yourself) in a shield that\n" ..
			"absorbs %d damage for 10 s or until consumed."):format(
				effective_support_number(def.values(user).absorb))
	end,
	color = "#e8e07a",
	cost = {mana_percent = 9},
	cooldown = 12,
	occupied_cast = 1,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = support_target(user, pointed, def)
		if not target then
			return false, err
		end
		if grug_core.add_absorb(target, "shield_spell", def.values(user).absorb,
				10, user, {}) > 0 then
			grug_pvp.support_contact(user, target)
		end
		fx("shield_spell", {target = target:get_pos()})
		clear_conscience(user)
		return true
	end,
})

-- A periodic status on the target (class plan C5, D1): four ticks, 3, 6, 9
-- and 12 s after the cast (the status pass fires a tick due at expiry). The
-- amount is the cast's snapshot; an offline healer's ticks heal as the
-- target itself. Re-casting refreshes duration, phase and amount; the status
-- system ends it on death and leave.
grug_abilities.register_ability({
	id = "mend",
	class = "priest",
	talent_gated = true,
	talent = "mercy_mend",
	name = "Mend",
	kind = "cast",
	target_kind = "friendly",
	tags = {"support"},
	description = "Heals the pointed ally (or yourself) every 3 s for 12 s;\n" ..
		"healing scales with your level.",
	values = function(user)
		return {heal = support_value(user, 7 + bonus(user, "mend_share_add"))}
	end,
	description_for = function(user, def)
		return ("Heals the pointed ally (or yourself) for %d every 3 s for 12 s."):format(
			effective_support_number(def.values(user).heal))
	end,
	color = "#3fae6a",
	cost = {mana_percent = 8},
	cooldown = 12,
	occupied_cast = 1,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = support_target(user, pointed, def)
		if not target then
			return false, err
		end
		local amount = def.values(user).heal
		local healer, action_id = user:get_player_name(), {}
		grug_core.set_status(target, "mend", {
			label = def.name,
			duration = 12,
			kind = "buff",
			interval = 3,
			on_tick = function(player)
				if player:get_hp() <= 0 then
					return
				end
				grug_core.heal_player(core.get_player_by_name(healer) or player,
					player, amount, {no_crit = true, action_id = action_id})
				fx("mend", {target = player:get_pos()})
			end,
		})
		-- The cast is the application; the ticks are never contact (ruling 7b).
		grug_pvp.support_contact(user, target)
		fx("mend", {target = target:get_pos()})
		clear_conscience(user)
		return true
	end,
})

-- The recipients of a self-centred group heal (skill-inventory.md §3 item
-- 3): you always, then the friendly players within `radius` (band ±3),
-- lowest health share first, `cap` in all (grug_core.area.group, filtered
-- through valid_target, which carries the PvP flag).
local function group_of(user, radius, cap)
	return grug_core.area.group(user, {radius = radius, cap = cap,
		eligible = target_filter(user, "friendly")})
end

grug_abilities.register_ability({
	id = "hearten",
	class = "priest",
	talent_gated = true,
	talent = "mercy_hearten",
	name = "Hearten",
	kind = "cast",
	target_kind = "self",
	tags = {"support"},
	description = "Heals you and up to 3 allies within 6 m, lowest health first;\n" ..
		"healing scales with your level.",
	values = function(user)
		return {heal = support_value(user, 15)}
	end,
	description_for = function(user, def)
		return ("Heals you and up to 3 allies within 6 m, lowest health first,\n" ..
			"for %d each."):format(effective_support_number(def.values(user).heal))
	end,
	color = "#ffe08a",
	cost = {mana_percent = 14},
	cooldown = 20,
	occupied_cast = 1.5,
	range = 6,
	cast = function(user, pointed, def)
		local amount, action_id = def.values(user).heal, {}
		fx("hearten", {caster = user:get_pos(), reach = 6})
		for _, player in ipairs(group_of(user, 6, 4)) do
			if grug_core.heal_player(user, player, amount,
					{no_crit = true, action_id = action_id}) > 0 then
				grug_pvp.support_contact(user, player)
			end
			fx("hearten_recipient", {target = player:get_pos()})
		end
		return true
	end,
})

-- The Mercy ultimate (M13): a `haven` heal over time on you and up to 4
-- allies within 8 m, its own status, so it stacks with Mend and keeps
-- ticking outside the circle. Lasting Haven lengthens it (duration_add:haven,
-- 2 s a tick).
local HAVEN_INTERVAL = 2
grug_abilities.register_ability({
	id = "haven",
	class = "priest",
	talent_gated = true,
	talent = "mercy_haven",
	name = "Haven",
	kind = "cast",
	target_kind = "self",
	tags = {"support"},
	description = "Gives you and up to 4 allies within 8 m a heal every 2 s;\n" ..
		"healing scales with your level.",
	values = function(user)
		local duration = 12 + family_bonus(user, grug_abilities.registered.haven, "duration_add")
		return {heal = support_value(user, 7), duration = duration,
			ticks = math.floor(duration / HAVEN_INTERVAL + 0.5)}
	end,
	description_for = function(user, def)
		local v = def.values(user)
		return ("Gives you and up to 4 allies within 8 m %d healing every 2 s,\n" ..
			"%d times."):format(effective_support_number(v.heal), v.ticks)
	end,
	color = "#fff0c8",
	cost = {mana_percent = 22},
	cooldown = 60,
	occupied_cast = 1.5,
	range = 8,
	cast = function(user, pointed, def)
		local v = def.values(user)
		local healer, action_id = user:get_player_name(), {}
		fx("haven", {caster = user:get_pos(), reach = 8})
		for _, player in ipairs(group_of(user, 8, 5)) do
			grug_core.set_status(player, "haven", {
				label = def.name,
				duration = v.duration,
				kind = "buff",
				interval = HAVEN_INTERVAL,
				on_tick = function(recipient)
					if recipient:get_hp() <= 0 then
						return
					end
					grug_core.heal_player(core.get_player_by_name(healer) or recipient,
						recipient, v.heal, {no_crit = true, action_id = action_id})
					fx("haven_tick", {target = recipient:get_pos()})
				end,
			})
			grug_pvp.support_contact(user, player)
		end
		return true
	end,
})

-- Where Rebuke's line starts: the priest's hand, a little below the eyes.
local function hand_of(user)
	local properties = user:get_properties() or {}
	return vector.offset(user:get_pos(), 0, (tonumber(properties.eye_height) or 1.47) - 0.3, 0)
end

grug_abilities.register_ability({
	id = "rebuke",
	class = "priest",
	talent_gated = true,
	talent = "reckoning_rebuke",
	name = "Rebuke",
	kind = "cast",
	target_kind = "hostile",
	tags = {"paid"},
	description = "An instant hit at the enemy in your crosshair; damage scales with\n" ..
		"your level and your staff or wand.",
	values = function(user)
		return {damage = spell_hit(user, grug_abilities.registered.rebuke, 1.8,
			bonus(user, "rebuke_add"))}
	end,
	description_for = function(user, def)
		return ("An instant hit at the enemy in your crosshair for %d damage."):format(
			effective_number(user, def.values(user).damage))
	end,
	color = "#ffd257",
	cost = {mana_percent = 6},
	cooldown = 6,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local pos = target:get_pos()
		fx("rebuke", {from = hand_of(user), to = grug_core.area.body_point(target, pos)})
		grug_core.deal_ability_damage(user, target, def.values(user).damage, {action_id = {}})
		return true
	end,
})

-- Word of Ruin heals the caster half the damage it dealt, at most its cap
-- (6 % of the pool x Q, Resolute Word's points on top): the pool cap only,
-- no receipt of the HP removed (skill-inventory.md §3 item 8). The damage is
-- the settled amount before the target's mitigation, as shipped.
grug_abilities.register_ability({
	id = "word_of_ruin",
	class = "priest",
	talent_gated = true,
	talent = "reckoning_word_of_ruin",
	name = "Word of Ruin",
	kind = "cast",
	target_kind = "hostile",
	tags = {"paid"},
	description = "Damages the aimed enemy and heals you for half the damage, up to\n" ..
		"a cap that scales with your level.",
	values = function(user)
		return {
			damage = spell_hit(user, grug_abilities.registered.word_of_ruin, 1.6, 0),
			cap = support_value(user, 6 + bonus(user, "word_of_ruin_cap_add")),
		}
	end,
	description_for = function(user, def)
		local v = def.values(user)
		return ("Damages the aimed enemy for %d and heals you for half the damage,\n" ..
			"at most %d."):format(effective_number(user, v.damage),
				effective_support_number(v.cap))
	end,
	color = "#a66bd4",
	cost = {mana_percent = 10},
	cooldown = 16,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		fx("word_of_ruin", {caster = user:get_pos(), target = target:get_pos()})
		local v = def.values(user)
		grug_core.deal_ability_damage(user, target, v.damage, {
			on_accepted = function(dealt, _, action_id)
				local heal = math.min(math.floor(dealt * 0.5), math.floor(v.cap))
				if heal > 0 then
					grug_core.heal_player(user, user, heal,
						{no_crit = true, action_id = action_id})
				end
			end,
		})
		return true
	end,
})

-- Censure (RK9): the ground anchor under the crosshair (skill-inventory.md
-- §3a, up to 16 m), a warning and a falling seal for 0.75 s, then one hit to
-- the 4 hostiles nearest the anchor within the radius (band ±3), and the
-- picked impact cue once at the anchor. "No ground found." refuses before
-- cost and cooldown. A self-kind offensive cast like Ice Nova, so a press at
-- open ground casts it (input.lua); its tooltip shows the pointing range
-- all the same (range_shown).
local CENSURE_DELAY, CENSURE_CAP = 0.75, 4
grug_abilities.register_ability({
	id = "censure",
	class = "priest",
	talent_gated = true,
	talent = "reckoning_censure",
	offensive = true,
	name = "Censure",
	kind = "cast",
	target_kind = "self",
	description = "Strikes the ground under your crosshair: after a short warning\n" ..
		"it hits the 4 nearest enemies around it.",
	values = function(user)
		local def = grug_abilities.registered.censure
		return {damage = spell_hit(user, def, 1.2, 0),
			radius = 3 + family_bonus(user, def, "radius_add")}
	end,
	description_for = function(user, def)
		local v = def.values(user)
		return ("Strikes the ground under your crosshair: after 0.75 s it hits\n" ..
			"the 4 nearest enemies within %g m for %d damage."):format(
				v.radius, effective_number(user, v.damage))
	end,
	color = "#ffd257",
	cost = {mana_percent = 12},
	cooldown = 18,
	occupied_cast = 1,
	range = 16,
	range_shown = true,
	cast = function(user, pointed, def)
		local area = grug_core.area
		local anchor, refusal = area.anchor(user, grug_abilities.get_range(user, def),
			{is_enemy = target_filter(user, "hostile")})
		if not anchor then
			return false, refusal
		end
		local v = def.values(user)
		return area.delayed(user, {
			anchor = anchor, delay = CENSURE_DELAY, radius = v.radius,
			warning = "censure_warning", fall = "censure_fall", burst = "censure_impact",
			impact = function(caster, at)
				grug_sounds.play("censure_impact", at)
				local action_id = {}
				for _, obj in ipairs(area.query(at, {radius = v.radius, cap = CENSURE_CAP,
						filter = target_filter(caster, "hostile")})) do
					-- Areas never crit (the calculator).
					grug_core.deal_ability_damage(caster, obj, v.damage,
						{action_id = action_id, no_crit = true})
				end
			end,
		})
	end,
})

-- The Reckoning ultimate (RK13): one instant heavy hit, 1.5 s occupied.
grug_abilities.register_ability({
	id = "final_word",
	class = "priest",
	talent_gated = true,
	talent = "reckoning_final_word",
	name = "Final Word",
	kind = "cast",
	target_kind = "hostile",
	tags = {"paid"},
	description = "A heavy instant hit at the enemy in your crosshair; damage scales\n" ..
		"with your level and your staff or wand.",
	values = function(user)
		return {damage = spell_hit(user, grug_abilities.registered.final_word, 2.8,
			bonus(user, "final_word_add"))}
	end,
	description_for = function(user, def)
		return ("A heavy instant hit at the enemy in your crosshair for %d damage."):format(
			effective_number(user, def.values(user).damage))
	end,
	color = "#fff6dd",
	cost = {mana_percent = 20},
	cooldown = 60,
	occupied_cast = 1.5,
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		fx("final_word", {target = target:get_pos()})
		grug_core.deal_ability_damage(user, target, def.values(user).damage, {action_id = {}})
		return true
	end,
})
end
