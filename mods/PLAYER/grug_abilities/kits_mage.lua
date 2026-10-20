-- The Mage's kit (Round 53, round K: round53-plan.md §4 MAGE; the trees in
-- grug_classes/talent_graph_mage.lua), dofiled from kits.lua with its shared
-- helpers (K).
--
-- Numbers are the balance calculator's frozen ones (plan §3 "Numbers"), in
-- D: the untalented Fiery Spark hit, spell_base + Int/10 before the level
-- scalar (deal_ability_damage scales it once). A family key damage_pct
-- ("damage_pct:fire" is Fire Mastery) is a percentage of the skill's
-- untalented damage, applied once to its whole coefficient; the class keys
-- named *_unit_add hold coefficients of D. Ground areas (Meteor, Fire Rain,
-- Winter Field) anchor with grug_core.area (skill-inventory.md §3a) and
-- land once after a fixed delay; Ice Nova and Ice Wave hit once around the
-- caster. Every area filter is valid_target (K.target_filter), which carries
-- the PvP flag. Area hits and Fireball's splash pass `no_crit` (the
-- calculator models them without crits); the direct projectile hits may
-- crit.
return function(K)
local mob_ent, effective_number = K.mob_ent, K.effective_number
local spell_damage_value, fx, facing = K.spell_damage_value, K.fx, K.facing
local family_bonus, target_filter = K.family_bonus, K.target_filter
local area = grug_core.area

--
-- Mage (mana)
--

-- D: the untalented Spark hit before the level scalar (the calculator's
-- unit, mage.md).
local function unit(user)
	return grug_abilities.spell_base(user) + grug_classes.get_spell_power_bonus(user)
end

-- `coef` D of `def`'s damage for this player: its damage_pct family keys
-- once over the whole coefficient, then the status spell damage.
local function damage(user, def, coef)
	return spell_damage_value(user, coef * unit(user) *
		(1 + family_bonus(user, def, "damage_pct") / 100))
end

local function bonus(user, key)
	return grug_classes.get_talent_bonus(user, key)
end

-- An area's radius and a status's duration with their family keys.
local function radius(user, def, base)
	return base + family_bonus(user, def, "radius_add")
end
local function duration(user, def, base)
	return base + family_bonus(user, def, "duration_add")
end

-- A slow on one target: a player through a named move modifier (the same
-- name refreshes), a mob through grug_mobs (the stronger factor and the
-- longer time win).
local function slow(obj, name, pct, seconds)
	if obj:is_player() then
		if obj:get_hp() > 0 then
			grug_core.set_move_modifier(obj, name, {speed = -pct / 100}, seconds)
		end
	else
		local ent = mob_ent(obj)
		if ent and (ent.health or 0) > 0 and obj:get_pos() then
			grug_mobs.slow(ent, seconds, 1 - pct / 100)
		end
	end
end

-- The projectiles. Each flies at the crosshair target of the cast (homing,
-- grug_projectiles) and settles once; the sprites follow the picked cards
-- (tools/r52_pfx: Fiery Spark 0.45, Cold Spark the spark in frost, Flame
-- Lance 0.6 white-hot at 35 m/s). Flights last at most about a second, so
-- active_limit bounds stale shots per owner like the shipped Fireball's.
local function sprite(size, tint)
	return {
		is_visible = true,
		visual = "sprite",
		textures = {"mobs_fire_particle.png" ..
			(tint and ("^[colorize:" .. tint .. ":200") or "")},
		visual_size = {x = size, y = size},
		glow = 12,
	}
end

-- One direct hit of a projectile: its impact effect, then the damage that
-- data snapshotted at launch; `on_accepted(critical)` after an accepted hit.
local function direct_hit(effect, owner, target, data, point, attacker_level, on_accepted)
	-- The effect first: a lethal hit may remove the target synchronously.
	fx(effect, {target = target:get_pos() or point})
	grug_core.deal_ability_damage(owner, target, data.damage,
		{attacker_level = attacker_level, action_id = data.action_id,
			on_accepted = on_accepted})
end

grug_projectiles.register("fiery_spark", {
	speed = 20,
	sound_launch = "fireball_launch",
	sound_hit = "fireball_hit",
	max_distance = 20,
	active_limit = 8,
	properties = sprite(0.45),
	on_hit = function(owner, target, data, point, attacker_level)
		direct_hit("spark_hit", owner, target, data, point, attacker_level)
	end,
})

grug_projectiles.register("cold_spark", {
	speed = 20,
	sound_launch = "cold_spark_launch",
	sound_hit = "fireball_hit",
	max_distance = 20,
	active_limit = 8,
	properties = sprite(0.45, "#bfe8ff"),
	on_hit = function(owner, target, data, point, attacker_level)
		-- The chill on a settled hit: 12 % for 1.5 s, refreshed, never stacked.
		direct_hit("cold_spark_hit", owner, target, data, point, attacker_level,
			function() slow(target, "cold_spark_slow", 12, 1.5) end)
	end,
})

grug_projectiles.register("fireball", {
	speed = 20,
	sound_launch = "fireball_launch",
	sound_hit = "fireball_hit",
	max_distance = 20,
	active_limit = 4,
	properties = sprite(0.7),
	on_hit = function(owner, target, data, point, attacker_level)
		-- The impact point before a lethal hit can remove the target.
		local at = point or target:get_pos()
		direct_hit("fireball", owner, target, data, point, attacker_level)
		-- The splash: other enemies within 2 m of the impact, in its sight,
		-- never the primary target.
		if at and (data.splash_damage or 0) > 0 then
			local hostile = target_filter(owner, "hostile")
			for _, obj in ipairs(area.query(at, {radius = 2, band = 2,
					filter = function(obj) return obj ~= target and hostile(obj) end})) do
				grug_core.deal_ability_damage(owner, obj, data.splash_damage,
					{attacker_level = attacker_level, action_id = data.action_id,
						no_crit = true})
			end
		end
	end,
})

grug_projectiles.register("flame_lance", {
	speed = 35,
	sound_launch = "flame_lance_launch",
	sound_hit = "fireball_hit",
	max_distance = 20,
	active_limit = 4,
	properties = sprite(0.6, "#fff0c8"),
	on_hit = function(owner, target, data, point, attacker_level)
		direct_hit("flame_lance_hit", owner, target, data, point, attacker_level)
	end,
})

-- Launches `projectile` at the crosshair target of `def`'s cast with `data`
-- (damage snapshotted now) and the repair receipt of the action. False plus
-- the refusal when nothing launched (no target in range): nothing is paid.
local action_serial = 0
local function launch(user, def, projectile, data, trail)
	local origin = grug_core.combat_eye_pos(user)
	local direction = user:get_look_dir()
	if not origin or not direction then
		return false, "Cannot determine your aim."
	end
	action_serial = action_serial + 1
	local action_id = user:get_player_name() .. ":" .. def.id .. ":" ..
		tostring(action_serial)
	local repair = rawget(_G, "grug_repair")
	local receipt = repair and repair.capture_action(user, action_id)
	data.action_id = receipt or action_id
	if not grug_projectiles.spawn(projectile, {
			owner = user,
			origin = origin,
			direction = direction,
			max_distance = grug_abilities.get_range(user, def),
			data = data,
			trail = trail,
		}) then
		if repair then repair.cancel_action(user, action_id) end
		return false, "No hostile target in your crosshair."
	end
	return true
end

--
-- The starters: the basic attack Fiery Spark in Strike's place (registered
-- first, so it leads the class's hotbar, K7), then Ice Wave.
--

grug_abilities.register_ability({
	id = "fiery_spark",
	class = "mage",
	name = "Fiery Spark",
	kind = "cast",
	target_kind = "hostile",
	-- The Mage's basic attack: replaces the universal Strike in place.
	transforms = "strike",
	tags = {"fire"},
	description = "A free spark of fire at the enemy in your crosshair, up to 20 m;\n" ..
		"damage scales with your level and your staff or wand.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.fiery_spark, 1.0)}
	end,
	description_for = function(user, def)
		return ("A free spark of fire at the enemy in your crosshair, up to %g m:\n" ..
			"%d damage, from your level and your staff or wand."):format(
				grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage))
	end,
	color = "#ffb347",
	cost = {},
	cooldown = 0,
	cast_interval = 1,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		return launch(user, def, "fiery_spark", {damage = def.values(user, def).damage})
	end,
})

grug_abilities.register_ability({
	id = "ice_wave", offensive = true,
	class = "mage",
	name = "Ice Wave",
	kind = "cast",
	target_kind = "self",
	tags = {"frost"},
	description = "A wave of frost in front of you (5 m, 70 degrees)\n" ..
		"damages enemies and slows them by 50% for 3 s.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.ice_wave, 0.25)}
	end,
	description_for = function(user, def)
		return ("A wave of frost in front of you (%g m, 70 degrees):\n" ..
			"%d damage and a 50%% slow for 3 s."):format(
				radius(user, def, 5), effective_number(user, def.values(user, def).damage))
	end,
	color = "#9fd4ff",
	cost = {mana_percent = 8},
	cooldown = 12,
	occupied_cast = 1,
	range = 4,
	cast = function(user, pointed, def)
		local amount = def.values(user, def).damage
		local action_id = {}
		for _, obj in ipairs(area.cone(user, {radius = radius(user, def, 5), angle = 70,
				filter = target_filter(user, "hostile")})) do
			grug_core.deal_ability_damage(user, obj, amount, {action_id = action_id,
				no_crit = true,
				on_accepted = function() slow(obj, "ice_wave_slow", 50, 3) end})
		end
		fx("ice_wave", {caster = user:get_pos(), dir = facing(user)})
		return true
	end,
})

--
-- Ember (fire), talent-gated: Fireball, Flame Lance, Meteor, Fire Rain.
--

grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	kind = "cast",
	target_kind = "hostile",
	talent_gated = true, talent = "ember_fireball",
	tags = {"fire"},
	description = "Hurls a fireball at the enemy in your crosshair, up to 20 m;\n" ..
		"it also burns other enemies within 2 m of the impact.",
	-- Afterglow adds to the hit, Wide Ember to the splash (both in D);
	-- Fire Mastery raises both.
	values = function(user, def)
		def = def or grug_abilities.registered.fireball
		return {
			damage = damage(user, def, 1.60 + bonus(user, "fireball_unit_add")),
			splash = damage(user, def, 0.15 + bonus(user, "fireball_splash_unit_add")),
		}
	end,
	description_for = function(user, def)
		local values = def.values(user, def)
		return ("Hurls a fireball at the enemy in your crosshair, up to %g m:\n" ..
			"%d damage, and %d to other enemies within 2 m of the impact."):format(
				grug_abilities.get_range(user, def), effective_number(user, values.damage),
				effective_number(user, values.splash))
	end,
	color = "#ff8833",
	cost = {mana_percent = 6},
	cooldown = 5,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		local values = def.values(user, def)
		return launch(user, def, "fireball",
			{damage = values.damage, splash_damage = values.splash})
	end,
})

grug_abilities.register_ability({
	id = "flame_lance",
	class = "mage",
	name = "Flame Lance",
	kind = "cast",
	target_kind = "hostile",
	talent_gated = true, talent = "ember_flame_lance",
	tags = {"fire"},
	description = "An instant, heavy lance of fire at the enemy in your crosshair, up to 20 m.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.flame_lance, 2.20)}
	end,
	description_for = function(user, def)
		return ("An instant, heavy lance of fire at the enemy in your crosshair,\n" ..
			"up to %g m: %d damage."):format(grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage))
	end,
	color = "#fff0c8",
	cost = {mana_percent = 10},
	cooldown = 8,
	occupied_cast = 1.5,
	range = 20,
	cast = function(user, pointed, def)
		return launch(user, def, "flame_lance", {damage = def.values(user, def).damage},
			{effect = "flame_lance_trail"})
	end,
})

-- A ground area at the crosshair (§3a): the anchor now, `spec.delay` later
-- one impact on every enemy within the radius (area.query: a band of ±3
-- and sight from the anchor), with the picked impact cue once at the anchor.
-- No ground: the refusal, before cost and cooldown. The damage is the
-- cast's; `spec.on_hit(obj)` runs on each accepted hit.
local function ground_area(user, def, spec)
	local anchor, why = area.anchor(user, grug_abilities.get_range(user, def),
		{is_enemy = target_filter(user, "hostile")})
	if not anchor then
		return false, why
	end
	local reach = spec.radius
	local amount = def.values(user, def).damage
	return area.delayed(user, {
		anchor = anchor,
		delay = spec.delay,
		radius = reach,
		warning = spec.warning,
		fall = spec.fall,
		burst = spec.burst,
		impact = function(caster, at)
			grug_sounds.play(spec.sound, at)
			local action_id = {}
			for _, obj in ipairs(area.query(at, {radius = reach,
					filter = target_filter(caster, "hostile")})) do
				grug_core.deal_ability_damage(caster, obj, amount, {action_id = action_id,
					no_crit = true,
					on_accepted = spec.on_hit and function() spec.on_hit(obj) end})
			end
		end,
	})
end

grug_abilities.register_ability({
	id = "meteor", offensive = true,
	class = "mage",
	name = "Meteor",
	kind = "cast",
	target_kind = "self",
	talent_gated = true, talent = "ember_meteor",
	tags = {"fire"},
	description = "Calls a meteor onto the ground in your crosshair, up to 20 m:\n" ..
		"after 1.5 s it strikes every enemy within 3 m.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.meteor, 1.40)}
	end,
	description_for = function(user, def)
		return ("Calls a meteor onto the ground in your crosshair, up to %g m:\n" ..
			"after 1.5 s it deals %d damage to every enemy within %g m."):format(
				grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage), radius(user, def, 3))
	end,
	color = "#d85b2d",
	cost = {mana_percent = 14},
	cooldown = 18,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		return ground_area(user, def, {delay = 1.5, radius = radius(user, def, 3),
			fall = "meteor_fall", burst = "meteor_impact", sound = "meteor_impact"})
	end,
})

grug_abilities.register_ability({
	id = "fire_rain", offensive = true,
	class = "mage",
	name = "Fire Rain",
	kind = "cast",
	target_kind = "self",
	talent_gated = true, talent = "ember_fire_rain",
	tags = {"fire"},
	description = "Calls a shower of fire onto the ground in your crosshair, up to 20 m:\n" ..
		"after 1.5 s it strikes every enemy within 5 m.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.fire_rain, 2.50)}
	end,
	description_for = function(user, def)
		return ("Calls a shower of fire onto the ground in your crosshair, up to %g m:\n" ..
			"after 1.5 s it deals %d damage to every enemy within %g m."):format(
				grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage), radius(user, def, 5))
	end,
	color = "#ff5a1f",
	cost = {mana_percent = 22},
	cooldown = 60,
	occupied_cast = 1.5,
	range = 20,
	cast = function(user, pointed, def)
		return ground_area(user, def, {delay = 1.5, radius = radius(user, def, 5),
			fall = "fire_rain_fall", burst = "fire_rain_impact", sound = "fire_rain_impact"})
	end,
})

--
-- Rime (frost), talent-gated: Cold Spark, Blink, Rime Mantle, Ice Nova,
-- Winter Field.
--

grug_abilities.register_ability({
	id = "cold_spark",
	class = "mage",
	name = "Cold Spark",
	kind = "cast",
	target_kind = "hostile",
	-- Replaces Fiery Spark in place on both layouts and shares its clock.
	transforms = "fiery_spark",
	talent_gated = true, talent = "rime_cold_spark",
	tags = {"frost"},
	description = "A free spark of frost at the enemy in your crosshair, up to 20 m;\n" ..
		"it slows by 12% for 1.5 s.",
	-- Keen Cold adds to every hit; Cold Shock's window (`shock`, read at the
	-- launch that spends it) to the next one.
	values = function(user, def, shock)
		return {damage = damage(user, def or grug_abilities.registered.cold_spark,
			1.0 + bonus(user, "cold_spark_unit_add") + (shock or 0))}
	end,
	description_for = function(user, def)
		return ("A free spark of frost at the enemy in your crosshair, up to %g m:\n" ..
			"%d damage and a 12%% slow for 1.5 s."):format(grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage))
	end,
	color = "#bfe8ff",
	cost = {},
	cooldown = 0,
	cast_interval = 1,
	occupied_cast = 1,
	range = 20,
	cast = function(user, pointed, def)
		-- Cold Shock: the open window adds its value to this spark and closes.
		local shock = grug_classes.get_window(user, "cold_shock")
		local ok, why = launch(user, def, "cold_spark",
			{damage = def.values(user, def, shock and shock.value).damage})
		if ok and shock then
			grug_classes.consume_window(user, "cold_shock")
		end
		return ok, why
	end,
})

grug_abilities.register_ability({
	id = "blink", repeat_policy = "once",
	class = "mage",
	name = "Blink",
	kind = "cast",
	target_kind = "self",
	talent_gated = true, talent = "rime_blink",
	tags = {"frost"},
	description = "Teleport up to 10 m in your look direction:\n" ..
		"onto the ground you aim at, or in front of a wall\n" ..
		"(one node up onto it if there is room).",
	color = "#b06aff",
	cost = {mana_percent = 8},
	cooldown = 20,
	range = 4,
	cast = function(user)
		local props = user:get_properties()
		local eye_height = props.eye_height or 1.47
		local box = props.collisionbox or {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
		local from = user:get_pos()
		-- Targeting rules live in blink.lua (ground: stand on it; wall: in
		-- front, or one node up onto it; air: full distance). A false return
		-- costs neither mana nor cooldown (try_cast).
		local dest = grug_abilities.blink_destination(
			vector.offset(from, 0, eye_height, 0), user:get_look_dir(),
			10, eye_height, box)
		if not dest then
			return false, "No room to blink."
		end
		grug_core.invalidate_combat_identity(user)
		user:set_pos(dest)
		fx("blink", {caster = from, target = dest})
		return true
	end,
})

-- Rime Mantle: an armor status (K x armor_k at the player's level, the
-- shared armor curve; Thick Ice adds K) and a shield of 12 % of the base
-- pool, for the same time (Lasting Armor lengthens both). The shield shows
-- as the one `shield` status (add_absorb).
grug_abilities.register_ability({
	id = "rime_mantle", repeat_policy = "once",
	class = "mage",
	name = "Rime Mantle",
	kind = "cast",
	target_kind = "self",
	talent_gated = true, talent = "rime_rime_mantle",
	tags = {"frost"},
	description = "Wraps you in rime: extra armor and a shield for 6 s.",
	values = function(user, def)
		def = def or grug_abilities.registered.rime_mantle
		local level = grug_core.get_player_level(user)
		return {
			armor = (0.20 + bonus(user, "rime_mantle_armor_add")) * grug_core.armor_k(level),
			absorb = grug_core.base_pool(level) * 0.12,
			duration = duration(user, def, 6),
		}
	end,
	description_for = function(user, def)
		local values = def.values(user, def)
		return ("Wraps you in rime for %g s:\n+%d armor and a shield of %d."):format(
			values.duration, math.floor(values.armor + 0.5), math.floor(values.absorb))
	end,
	color = "#8bd8f0",
	cost = {mana_percent = 10},
	cooldown = 24,
	occupied_cast = 0.3,
	range = 4,
	cast = function(user, pointed, def)
		local values = def.values(user, def)
		grug_core.set_status(user, "rime_mantle", {label = "Rime Mantle",
			duration = values.duration, modifiers = {armor = values.armor}})
		grug_core.add_absorb(user, "rime_mantle", values.absorb, values.duration, user)
		-- The picked card keeps Glacial Ward's effect (HOOKS Q1).
		fx("glacial_ward", {caster = user:get_pos()})
		return true
	end,
})

grug_abilities.register_ability({
	id = "ice_nova", offensive = true,
	class = "mage",
	name = "Ice Nova",
	kind = "cast",
	target_kind = "self",
	-- Replaces Ice Wave in place and shares its cooldown.
	transforms = "ice_wave",
	talent_gated = true, talent = "rime_ice_nova",
	tags = {"frost"},
	description = "Damages enemies within 5 m around you and roots them for 2.5 s.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.ice_nova, 0.65)}
	end,
	description_for = function(user, def)
		return ("Damages enemies within %g m around you for %d\n" ..
			"and roots them for 2.5 s."):format(radius(user, def, 5),
				effective_number(user, def.values(user, def).damage))
	end,
	color = "#66b8ff",
	cost = {mana_percent = 10},
	cooldown = 18,
	occupied_cast = 1,
	range = 4,
	cast = function(user, pointed, def)
		local pos = user:get_pos()
		local reach = radius(user, def, 5)
		local amount = def.values(user, def).damage
		local root_time = 2.5
		-- Cold Shock: a Nova that hits an enemy readies the next Cold Spark
		-- (4 s, one charge; the Nova's cooldown spaces the windows).
		local shock = bonus(user, "cold_shock_unit_add")
		local readied = false
		local action_id = {}
		for _, obj in ipairs(area.query(pos, {radius = reach,
				filter = target_filter(user, "hostile")})) do
			-- Capture before lethal mob punches can synchronously remove the object.
			local ent = mob_ent(obj)
			grug_core.deal_ability_damage(user, obj, amount, {
				action_id = action_id,
				no_crit = true,
				on_accepted = function()
					if obj:is_player() then
						if obj:get_hp() > 0 and grug_core.set_root(obj, root_time) then
							grug_core.mark_nova_root(obj, root_time)
						end
					elseif ent and (ent.health or 0) > 0 and obj:get_pos() then
						grug_mobs.root(ent, root_time)
						ent._grug_nova_left = math.max(ent._grug_nova_left or 0, root_time)
					end
					if shock > 0 and not readied then
						readied = grug_classes.open_window(user, "cold_shock",
							{duration = 4, value = shock, label = "Cold Shock"})
						if readied then grug_core.proc_flash(user, "cold_shock") end
					end
				end,
			})
		end
		fx("ice_nova", {caster = pos, reach = reach})
		return true
	end,
})

grug_abilities.register_ability({
	id = "winter_field", offensive = true,
	class = "mage",
	name = "Winter Field",
	kind = "cast",
	target_kind = "self",
	talent_gated = true, talent = "rime_winter_field",
	tags = {"frost"},
	description = "Freezes the ground in your crosshair, up to 15 m: after 1 s\n" ..
		"every enemy within 4 m is struck and slowed by 40% for 5 s.",
	values = function(user, def)
		return {damage = damage(user, def or grug_abilities.registered.winter_field, 1.0)}
	end,
	description_for = function(user, def)
		return ("Freezes the ground in your crosshair, up to %g m: after 1 s\n" ..
			"%d damage and a 40%% slow for 5 s to every enemy within %g m."):format(
				grug_abilities.get_range(user, def),
				effective_number(user, def.values(user, def).damage), radius(user, def, 4))
	end,
	color = "#dff4ff",
	cost = {mana_percent = 18},
	cooldown = 60,
	occupied_cast = 1.5,
	range = 15,
	cast = function(user, pointed, def)
		return ground_area(user, def, {delay = 1, radius = radius(user, def, 4),
			warning = "winter_field_warning", fall = "winter_field_fall",
			burst = "winter_field_impact", sound = "winter_field_impact",
			on_hit = function(obj) slow(obj, "winter_field_slow", 40, 5) end})
	end,
})
end
