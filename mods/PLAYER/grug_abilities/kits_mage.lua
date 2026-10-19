-- The Mage's kit (docs/design/classes.md §4), dofiled from kits.lua with its
-- shared helpers (K).
return function(K)
local mob_ent, debug_cast_ray = K.mob_ent, K.debug_cast_ray
local current_enemy_target, effective_number = K.current_enemy_target, K.effective_number
local spell_damage_value, support_value = K.spell_damage_value, K.support_value
local talent_rank_value, fx = K.talent_rank_value, K.fx

--
-- Mage (mana)
--

local fireball_action_serial = 0

grug_projectiles.register("fireball", {
	speed = 20,
	sound_launch = "fireball_launch",
	sound_hit = "fireball_hit",
	max_distance = 20,
	-- A flight lasts one second and the server accepts at most one cast per
	-- second. Eight leaves room for latency/session overlap while still bounding
	-- stale shots per owner/session independently of the cast cadence.
	active_limit = 8,
	properties = {
		is_visible = true,
		visual = "sprite",
		textures = {"mobs_fire_particle.png"},
		visual_size = {x = 0.7, y = 0.7},
		glow = 12,
	},
	on_hit = function(owner, target, data, point, attacker_level)
		-- The impact splash, before a lethal hit can remove the target.
		fx("fireball", {target = target:get_pos() or point})
		grug_core.deal_ability_damage(owner, target, data.damage,
			{attacker_level = attacker_level, action_id = data.action_id,
				on_accepted = function(_, critical)
					if not critical then return end
					if grug_classes.try_trigger_talent_window(owner,
							"whitehot", talent_rank_value(owner, "whitehot",
								"whitehot_window", 8), 60) then
						grug_core.proc_flash(owner, "whitehot")
					end
				end})
		local splash = data.splash or 0
		if splash > 0 then
			for _, obj in ipairs(core.get_objects_inside_radius(point, 2)) do
				if obj ~= target and grug_abilities.valid_target(owner, obj, "hostile") then
					grug_core.deal_ability_damage(owner, obj, data.splash_damage,
						{attacker_level = attacker_level, action_id = data.action_id})
				end
			end
		end
	end,
})

-- Bread-and-butter nuke (kit tuning 2026-08-06): pays with mana plus a
-- server-authoritative one-second cast cadence instead of a talent-visible
-- cooldown. Release locks the current crosshair target; enemy memory is never aim.
-- Tinder and Whitehot's window damage are level-proof talent amounts
-- (grug_classes.talent_level_amount); Whitehot's is 0 outside its window.
local function fireball_values(user)
	local window = grug_classes.get_talent_bonus(user, "whitehot_damage")
	return {
		damage = spell_damage_value(user,
			grug_abilities.spell_base(user)
			+ grug_classes.get_spell_power_bonus(user)
			+ grug_classes.get_talent_bonus(user, "fireball_damage_add") + window),
	}
end

grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	kind = "cast",
	target_kind = "hostile",
	description = "Hurls fire along your crosshair for up to 20 m;\n" ..
		"damage scales with your level and your staff or wand;\n" ..
		"requires a visible hostile target.",
	values = fireball_values,
	description_for = function(user, def)
		return ("Hurls fire along your crosshair for up to 20 m:\n" ..
			"%d damage, from your level and your staff or wand;\n" ..
			"requires a visible hostile target."):format(
				effective_number(user, def.values(user).damage))
	end,
	color = "#ff8833",
	cost = {mana_percent = 6},
	cooldown = 0,
	cast_interval = 1,
	range = 20,
	-- Far Cast (skill_trees.md §2.3) re-tunes a RANGE, so it cannot live in
	-- the field above: get_range reads this key per player, and sync_kit's
	-- per-stack `range` meta override follows it (§3.2).
	range_talent = "fireball_range_add",
	cast = function(user)
		local origin = grug_core.combat_eye_pos(user)
		local direction = user:get_look_dir()
		if not origin or not direction then
			return false, "Cannot determine your aim."
		end
		fireball_action_serial = fireball_action_serial + 1
		local action_id = user:get_player_name() .. ":fireball:" ..
			tostring(fireball_action_serial)
		local repair = rawget(_G, "grug_repair")
		local repair_receipt = repair and repair.capture_action(user, action_id)
		local spawned = grug_projectiles.spawn("fireball", {
			owner = user,
			origin = origin,
			direction = direction,
			max_distance = 20 + grug_classes.get_talent_bonus(user,
				"fireball_range_add")
				+ (grug_classes.get_race_perk(user, "ability_range_bonus") or 0),
			data = {
				-- Primary and Brand damage snapshot complete spell formulas at launch.
				damage = fireball_values(user).damage,
				splash = grug_classes.get_talent_bonus(user, "fireball_splash"),
				splash_damage = spell_damage_value(user, grug_classes.get_talent_bonus(user,
					"fireball_splash") + grug_classes.get_spell_power_bonus(user) / 2),
				action_id = repair_receipt or action_id,
			},
		})
		if not spawned then
			if repair then repair.cancel_action(user, action_id) end
			return false, "The fireball could not be launched."
		end
		local name = user:get_player_name()
		if grug_core.combat_debug_enabled(name)
				and grug_core.combat_debug_due(name, "cast:fireball", 0.1) then
			grug_core.combat_debug_log(name, "cast_fireball",
				"spawned direction=" .. tostring(direction.x) .. "," ..
				tostring(direction.y) .. "," .. tostring(direction.z))
		end
		return true
	end,
})

-- The rotation pivot (kit tuning 2026-08-06): kiting IS the Mage fantasy
-- here — root, make distance, keep nuking, re-nova when it is back up.
local function nova_values(user)
	local control = grug_classes.get_talent_bonus(user, "control_damage_add")
	local power = grug_classes.get_spell_power_bonus(user)
	return {damage = spell_damage_value(user,
		(grug_abilities.spell_base(user) + power) / 4
		+ control + (control > 0 and power / 2 or 0))}
end

grug_abilities.register_ability({
	id = "ice_nova", offensive = true,
	class = "mage",
	name = "Ice Nova",
	values = nova_values,
	kind = "cast",
	target_kind = "self",
	description = "Damages and roots enemies within 5 m for 4 s,\n" ..
		"then slows them by 50% for 3 s.",
	color = "#66b8ff",
	cost = {mana_percent = 10},
	cooldown = 12,
	range = 4,
	cast = function(user, pointed, def)
		local pos = user:get_pos()
		local ranged = grug_classes.get_talent_bonus(user, "ice_nova_ranged")
		if ranged > 0 then
			local target = current_enemy_target(user, {
				id = def.id, target_kind = "hostile", range = 20,
			})
			if not target then return false, "No hostile target in your crosshair." end
			pos = target:get_pos()
		end
		-- Deep Chill and Hoarfrost (skill_trees.md §2.4); 0 each without the
		-- talent, so the base 4 s root and 3 s slow remain exact.
		local root_time = 4 + grug_classes.get_talent_bonus(user,
			"ice_nova_root_add")
		local slow_time = 3 + grug_classes.get_talent_bonus(user,
			"ice_nova_slow_add")
		local radius = ranged > 0 and ranged or 5
		local action_id = {}
		for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
			if grug_abilities.valid_target(user, obj, "hostile") then
				-- Capture before lethal mob punches can synchronously remove the object.
				local ent = mob_ent(obj)
				grug_core.deal_ability_damage(user, obj, nova_values(user).damage, {
					action_id = action_id,
					on_accepted = function()
						if obj:is_player() then
							if obj:get_hp() <= 0 then return end
							if grug_core.set_root(obj, root_time) then
								grug_core.mark_nova_root(obj, root_time)
							end
							grug_core.set_move_modifier(obj, "ice_nova_slow",
								{speed = -0.5}, root_time + slow_time)
						elseif ent and (ent.health or 0) > 0 and obj:get_pos() then
							grug_mobs.root(ent, root_time)
							ent._grug_nova_left = math.max(ent._grug_nova_left or 0, root_time)
							grug_mobs.slow(ent, slow_time, 0.5)
						end
					end,
				})
			end
		end
		-- No blanket combat mark: every hit above marks through
		-- deal_ability_damage (timer for players, engagement for mobs), so a
		-- nova that kills the last mob leaves combat like any other kill.
		fx("ice_nova", {caster = pos, reach = radius})
		return true
	end,
})

grug_abilities.register_ability({
	id = "blink", repeat_policy = "once",
	class = "mage",
	name = "Blink",
	kind = "cast",
	target_kind = "self",
	description = "Teleport up to 10 m in your look direction:\n" ..
		"onto the ground you aim at, or in front of a wall\n" ..
		"(one node up onto it if there is room).",
	color = "#b06aff",
	cost = {mana_percent = 8},
	cooldown = 15,
	cooldown_talent = "blink_cooldown_sub", -- Quick Step (skill_trees.md §2.4)
	range = 4,
	cast = function(user)
		local props = user:get_properties()
		local eye_height = props.eye_height or 1.47
		local box = props.collisionbox or {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
		local from = user:get_pos()
		-- Far Step (skill_trees.md §2.4); 10 m exactly without the talent.
		local distance = 10 + grug_classes.get_talent_bonus(user,
			"blink_distance_add")
		-- Targeting rules live in blink.lua (ground: stand on it; wall: in
		-- front, or one node up onto it; air: full distance). A false return
		-- costs neither mana nor cooldown (try_cast).
		local dest = grug_abilities.blink_destination(
			vector.offset(from, 0, eye_height, 0), user:get_look_dir(),
			distance, eye_height, box)
		if not dest then
			return false, "No room to blink."
		end
		grug_core.invalidate_combat_identity(user)
		user:set_pos(dest)
		fx("blink", {caster = from, target = dest})
		return true
	end,
})

grug_abilities.register_ability({
	id = "cinderfall", class = "mage", talent_gated = true,
	kind = "cast", target_kind = "hostile", name = "Cinderfall",
	description = "Burst at the first aimed contact, damaging hostiles around it.",
	color = "#d85b2d", cost = {mana_percent = 12}, cooldown = 10, range = 20,
	cast = function(user, pointed, def)
		local ray = grug_core.combat_ray(user, grug_abilities.get_range(user, def))
		debug_cast_ray(user, def, ray)
		local pos = ray.pointed and ray.pointed.intersection_point
		if not pos or not ray.distance or ray.distance > ray.range then
			return false, "No contact in your crosshair."
		end
		local damage = spell_damage_value(user,
			grug_classes.get_talent_bonus(user, "cinderfall_damage")
			+ grug_classes.get_spell_power_bonus(user))
		local radius = 3 + grug_classes.get_talent_bonus(user,
			"cinderfall_radius_add")
		local action_id = {}
		for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
			if grug_abilities.valid_target(user, obj, "hostile") then
				grug_core.deal_ability_damage(user, obj, damage,
					{action_id = action_id})
			end
		end
		fx("cinderfall", {target = pos, reach = radius})
		return true
	end,
})

grug_abilities.register_ability({
	id = "glacial_ward", class = "mage", talent_gated = true,
	kind = "cast", target_kind = "self", name = "Glacial Ward",
	description = "Surround yourself with an absorb raised by gear Intelligence for 10 s.",
	color = "#8bd8f0", cost = {mana_percent = 10}, cooldown = 30, range = 4,
	values = function(user)
		return {absorb = support_value(user,
			grug_classes.get_talent_bonus(user, "glacial_ward_absorb"))}
	end,
	cast = function(user, pointed, def)
		grug_core.add_absorb(user, "glacial_ward", def.values(user).absorb, 10,
			user, {})
		fx("glacial_ward", {caster = user:get_pos()})
		return true
	end,
})
end
