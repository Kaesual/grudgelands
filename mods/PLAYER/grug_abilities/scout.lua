-- Scout bow and melee abilities (docs/design/scout.md).

local ARROW_PROJECTILE = "scout_arrow"
local ARROW_SPEED = 40
local DRAW_STEP = 0.05
local draws = {}
local draw_wear_steps = {}
local pending_control = {}
local next_action = 0
local DRAW_STAGE_SOURCE = {
	["grug_gear_bow_wood.png"] = "",
	["grug_gear_bow_lebethron.png"] = "^[colorize:#5f7040:90",
	["grug_gear_bow_birch.png"] = "^[hsl:0:-20:16",
	["grug_gear_bow_mallorn.png"] = "^[colorize:#d4b34c:70",
	["grug_gear_bow_alder.png"] = "^[colorize:#9b442f:75",
}

player_api.register_control_animation_override(function(player, controls)
	if not draws[player:get_player_name()] then return end
	if controls.up or controls.down or controls.left or controls.right then
		return "walk"
	end
	return "stand"
end)

local function action_id(player, ability)
	next_action = next_action + 1
	return player:get_player_name() .. ":" .. ability .. ":" .. next_action
end

local function repair_receipt(player, id)
	local repair = rawget(_G, "grug_repair")
	return repair and repair.capture_action(player, id) or id
end

local function cancel_receipt(player, receipt)
	local repair = rawget(_G, "grug_repair")
	if repair then repair.cancel_action(player, receipt) end
end

local function equipped_bow(player)
	local stack = grug_core.get_equipped_weapon(player)
	if not stack or not grug_inventory.is_bow(stack) or
			grug_core.equipment_is_broken(stack) then
		return nil
	end
	return stack
end

local function arrow_damage(player)
	local stack = equipped_bow(player)
	if not stack then return nil end
	local caps = stack:get_tool_capabilities() or {}
	local groups = caps.damage_groups or {}
	return math.max(0, tonumber(groups.fleshy) or 0)
		+ grug_classes.get_ranged_bonus(player)
end

local function apply_root(target, duration)
	if target:is_player() then
		grug_core.set_root(target, duration)
	else
		local ent = target:get_luaentity()
		if ent then grug_mobs.root(ent, duration) end
	end
end

local function apply_slow(target, duration, factor)
	if target:is_player() then
		grug_core.set_move_modifier(target, "scout_snare", {
			speed = factor - 1,
		}, duration)
	else
		local ent = target:get_luaentity()
		if ent then grug_mobs.slow(ent, duration, factor) end
	end
end

grug_core.register_on_settled_outgoing_action(function(player, action_id, kind)
	if kind ~= "damage" then return end
	local per_player = pending_control[player:get_player_name()]
	local pending = per_player and per_player[action_id]
	if not pending then return end
	per_player[action_id] = nil
	if pending.slow then apply_slow(pending.target, pending.slow, 0.5) end
	if pending.root then apply_root(pending.target, pending.root) end
end)

grug_projectiles.register(ARROW_PROJECTILE, {
	speed = ARROW_SPEED,
	max_distance = 25,
	active_limit = 8,
	orient_to_velocity = true,
	properties = {
		is_visible = true,
		visual = "mesh",
		mesh = "grug_projectiles_arrow.obj",
		textures = {"grug_projectiles_arrow.png"},
		visual_size = {x = -1, y = 1},
	},
	on_hit = function(owner, target, data, point, attacker_level)
		local damage = data.damage
		if data.longshot and vector.distance(data.origin, point) > 25 then
			damage = damage + 4
		end
		local name = owner:get_player_name()
		local per_player = pending_control[name]
		if not per_player then
			per_player = {}
			pending_control[name] = per_player
		end
		if data.slow or data.root then
			per_player[data.action_id] = {
				target = target, slow = data.slow, root = data.root,
			}
		end
		grug_core.deal_ability_damage(owner, target, damage, {
			attacker_level = attacker_level,
			action_id = data.action_id,
		})
		-- Settlement is synchronous inside deal_ability_damage. Anything still
		-- pending was dodged, absorbed or refused by PvP/mobs callbacks.
		per_player[data.action_id] = nil
	end,
})

local function launch(player, ability, count, fraction, effect, captured)
	if grug_core.refuse_mounted_attack and
			grug_core.refuse_mounted_attack(player) == true then
		if captured then cancel_receipt(player, captured) end
		return false, "You cannot attack while mounted."
	end
	local bow = equipped_bow(player)
	local base_damage = arrow_damage(player)
	if not bow or not base_damage then
		return false, "Equip a usable bow in your Weapon slot."
	end
	if grug_inventory.ammo_count(player) < count then
		return false, count == 1 and "You need an arrow." or
			"Twin Shot needs two arrows."
	end
	local origin = grug_core.combat_eye_pos(player)
	local direction = player:get_look_dir()
	if not origin or not direction or vector.length(direction) <= 0 then
		return false, "Cannot determine your aim."
	end
	local receipt = captured or repair_receipt(player, action_id(player, ability))
	local range = (effect.range or 25)
		+ (grug_classes.get_race_perk(player, "ability_range_bonus") or 0)
	local damage = math.floor((base_damage + (effect.damage_add or 0)) * fraction)
	local common = {
		origin = vector.new(origin),
		direction = vector.new(direction),
		speed = ARROW_SPEED * fraction,
		max_distance = range,
	}
	local launches = {}
	for index = 1, count do
		local shot_damage = damage
		if index == 2 then
			shot_damage = math.floor(damage * effect.second_percent / 100)
		end
		launches[index] = {
			owner = player,
			origin = common.origin,
			direction = common.direction,
			speed = common.speed,
			max_distance = common.max_distance,
			data = {
				damage = shot_damage,
				origin = common.origin,
				longshot = effect.longshot,
				slow = effect.slow,
				root = effect.root,
				action_id = receipt,
			},
		}
	end
	local spawned = grug_projectiles.spawn_batch(ARROW_PROJECTILE, launches,
		function()
			return grug_inventory.consume_ammo(player, count)
		end)
	if not spawned then
		cancel_receipt(player, receipt)
		return false, "The arrow could not be launched."
	end
	if effect.refund and math.random(1, 100) <= effect.refund then
		grug_inventory.refund_ammo(player, count)
	end
	return true
end

local function loose_effect(player, full_draw)
	local second = grug_classes.get_talent_bonus(player, "loose_second_arrow")
	local longshot = grug_classes.get_talent_bonus(player, "loose_range_add") > 0
	return {
		damage_add = grug_classes.get_talent_bonus(player, "loose_damage_add"),
		second_percent = second,
		range = longshot and 33 or 25,
		longshot = longshot,
		refund = grug_classes.get_talent_bonus(player, "arrow_refund_chance"),
		count = full_draw and second > 0 and 2 or 1,
	}
end

local function bow_identity(stack)
	if not stack or stack:is_empty() then return nil end
	local item_id = stack:get_meta():get_string("_grug_repair_item_id")
	return stack:get_name() .. "|" .. item_id
end

local function image_string(image)
	if type(image) == "table" then return image.name or "" end
	return image or ""
end

local function bow_wield_image(player)
	local bow = equipped_bow(player)
	if not bow then return "" end
	local meta = bow:get_meta()
	local image = meta:get_string("wield_image")
	local def = core.registered_items[bow:get_name()]
	if image == "" then image = image_string(def and def.wield_image) end
	if image == "" then image = meta:get_string("inventory_image") end
	if image == "" then image = image_string(def and def.inventory_image) end
	return image
end

local function staged_bow_image(player, stage)
	local source = bow_wield_image(player)
	for base, family_tint in pairs(DRAW_STAGE_SOURCE) do
		if source:sub(1, #base) == base then
			return "grug_abilities_bow_draw_" .. stage .. ".png" ..
				family_tint .. source:sub(#base + 1)
		end
	end
	return source
end

local function reset_draw_stack(player)
	local source = bow_wield_image(player)
	local inv = player:get_inventory()
	for index, stack in ipairs(inv and inv:get_list("main") or {}) do
		if stack:get_name() == "grug_abilities:loose" then
			local meta = stack:get_meta()
			if stack:get_wear() ~= 0 or meta:get_string("wield_image") ~= source then
				stack:set_wear(0)
				meta:set_string("wield_image", source)
				inv:set_stack("main", index, stack)
			end
			return
		end
	end
end

local function clear_draw(player)
	local name = player:get_player_name()
	local rec = draws[name]
	if rec then cancel_receipt(player, rec.action_id) end
	draws[name] = nil
	draw_wear_steps[name] = nil
	reset_draw_stack(player)
end

local function set_draw_wear(player, fraction)
	local name = player:get_player_name()
	-- Ten visible charge states leave the lifecycle reset inside the prior
	-- eleven-write/action ceiling while the same writes also carry bow stages.
	local step = math.max(0, math.min(9, math.floor(fraction * 9)))
	if draw_wear_steps[name] == step then return end
	draw_wear_steps[name] = step
	local stage = step < 3 and 0 or (step < 6 and 1 or 2)
	local inv = player:get_inventory()
	for index, stack in ipairs(inv and inv:get_list("main") or {}) do
		if stack:get_name() == "grug_abilities:loose" then
			stack:set_wear(math.floor((9 - step) / 9 * 65534))
			stack:get_meta():set_string("wield_image",
				staged_bow_image(player, stage))
			inv:set_stack("main", index, stack)
			return
		end
	end
end

local function finish_draw_wear(player)
	reset_draw_stack(player)
	draw_wear_steps[player:get_player_name()] = nil
end

local function effective_draw_time(player)
	local base = math.max(0.1, 0.5 -
		grug_classes.get_talent_bonus(player, "draw_time_sub"))
	local items = rawget(_G, "grug_items")
	local totals = items and items.get_equipment_affix_totals and
		items.get_equipment_affix_totals(player) or {}
	local speed = math.max(0, tonumber(totals.attack_speed_percent) or 0)
	return base / (1 + speed / 100)
end

local function start_draw(player)
	if grug_core.is_stunned(player) then return false, "You are stunned." end
	local name = player:get_player_name()
	if draws[name] then return true end
	local bow = equipped_bow(player)
	if not bow then return false, "Equip a usable bow in your Weapon slot." end
	if grug_inventory.ammo_count(player) < 1 then
		return false, "You need an arrow."
	end
	local receipt = repair_receipt(player, action_id(player, "loose"))
	bow = equipped_bow(player)
	if not bow then
		cancel_receipt(player, receipt)
		return false, "Equip a usable bow in your Weapon slot."
	end
	draws[name] = {
		player = player,
		started = core.get_us_time(),
		bow_name = bow:get_name(),
		bow = bow_identity(bow),
		action_id = receipt,
	}
	set_draw_wear(player, 0)
	return true
end

local function release_draw(player, rec)
	if grug_core.is_stunned(player) then clear_draw(player); return end
	local bow = equipped_bow(player)
	if not bow or bow_identity(bow) ~= rec.bow then
		clear_draw(player)
		return
	end
	draws[player:get_player_name()] = nil
	if grug_core.refuse_mounted_attack and
			grug_core.refuse_mounted_attack(player) == true then
		cancel_receipt(player, rec.action_id)
		finish_draw_wear(player)
		return
	end
	local draw_time = effective_draw_time(player)
	local fraction = math.min(1,
		math.max(0, (core.get_us_time() - rec.started) / (draw_time * 1e6)))
	-- A press and release observed at the same monotonic timestamp has no
	-- impulse and therefore no projectile action or ammunition cost.
	if fraction <= 0 then
		cancel_receipt(player, rec.action_id)
		finish_draw_wear(player)
		return
	end
	local effect = loose_effect(player, fraction >= 1)
	local ok, err = launch(player, "loose", effect.count, fraction, effect,
		rec.action_id)
	finish_draw_wear(player)
	if not ok then grug_abilities.flash(player, err) end
end

local draw_accumulator = 0
core.register_globalstep(function(dtime)
	draw_accumulator = draw_accumulator + dtime
	if draw_accumulator < DRAW_STEP then return end
	draw_accumulator = draw_accumulator % DRAW_STEP
	for name, rec in pairs(draws) do
		local player = core.get_player_by_name(name)
		if not player or player ~= rec.player or player:get_hp() <= 0
				or grug_core.is_stunned(player) then
			clear_draw(rec.player)
		else
			local wield = player:get_wielded_item()
			local def = grug_abilities.registered.loose
			if not def or wield:get_name() ~= "grug_abilities:loose" or
					not equipped_bow(player) then
				clear_draw(player)
			elseif not player:get_player_control().dig then
				release_draw(player, rec)
			else
				local fraction = math.min(1, (core.get_us_time() - rec.started) /
					(effective_draw_time(player) * 1e6))
				set_draw_wear(player, fraction)
			end
		end
	end
end)

grug_core.register_on_stun(clear_draw)
core.register_on_dieplayer(clear_draw)
core.register_on_leaveplayer(function(player)
	clear_draw(player)
	pending_control[player:get_player_name()] = nil
end)

grug_core.register_on_equipment_change(function(player, listname, reason)
	if listname == nil or listname == "grug_weapon" then
		local rec = draws[player:get_player_name()]
		local bow = equipped_bow(player)
		if rec then
			if reason == "durability_metadata" and bow and
					bow:get_name() == rec.bow_name then
				-- REPAIR assigned identity or wear to the same usable bow. Keep
				-- the held clock, but refresh the release-time identity snapshot.
				rec.bow = bow_identity(bow)
			elseif not bow or bow_identity(bow) ~= rec.bow then
				clear_draw(player)
			end
		end
	end
end)

grug_abilities.register_ability({
	id = "loose", class = "scout", name = "Loose", kind = "cast",
	target_kind = "hostile", color = "#5fae5f", cost = {}, cooldown = 0,
	range = 25, range_talent = "loose_range_add",
	description = "Hold LMB to draw, then release along your current aim. " ..
		"Requires a visible hostile target within 25 m; draw scales damage.",
	cast = start_draw,
})

grug_abilities.register_ability({
	id = "snare_shot", class = "scout", name = "Snare Shot", kind = "cast",
	target_kind = "hostile", color = "#79a65a",
	cost = {mana_percent = 8}, cooldown = 12, range = 25,
	description = "Fires along your current aim and slows a landed target " ..
		"by 50% for 4 s.",
	cast = function(user)
		return launch(user, "snare_shot", 1, 1, {range = 25, slow = 4})
	end,
})

grug_abilities.register_ability({
	id = "sidestep", class = "scout", name = "Sidestep", kind = "cast",
	target_kind = "self", color = "#73b897", cost = {mana_percent = 10},
	cooldown = 30, cooldown_talent = "sidestep_cooldown_sub", range = 0,
	description = "Gain 15 percentage points of dodge for 4 s.",
	cast = function(user)
		grug_classes.start_sidestep(user)
		return true
	end,
})

grug_abilities.register_ability({
	id = "sprint", class = "scout", name = "Sprint", kind = "cast",
	target_kind = "self", color = "#c9b85d", cost = {mana_percent = 15},
	cooldown = 300, range = 0,
	description = "Move 50% faster for 10 s.",
	cast = function(user)
		grug_core.set_move_modifier(user, "scout_sprint", {speed = 0.50}, 10)
		grug_core.set_status(user, "scout_sprint", {
			label = "Sprint (+50% Speed)",
			duration = 10,
			kind = "buff",
			-- The movement aggregator remains the sole effect authority. An
			-- explicit removal hides this display on the next status refresh.
			value = function(player)
				if grug_core.get_move_modifier(player, "scout_sprint") then
					return nil
				end
				return false
			end,
		})
		return true
	end,
})

grug_abilities.register_ability({
	id = "pinning_shot", class = "scout", name = "Pinning Shot",
	kind = "cast", target_kind = "hostile", talent_gated = true,
	color = "#4f8f67", cost = {mana_percent = 12}, cooldown = 30, range = 25,
	description = "Fires along your current aim and roots a landed target.\n" ..
		"Unlocked via talents.",
	cast = function(user)
		local duration = grug_classes.get_talent_bonus(user, "pinning_root")
		return launch(user, "pinning_shot", 1, 1,
			{range = 25, root = duration})
	end,
})

local function behind_target(user, target)
	local from = target:get_pos()
	local to = user:get_pos()
	local yaw = target:is_player() and target:get_look_horizontal()
		or target:get_yaw()
	if not from or not to or type(yaw) ~= "number" then return false end
	local forward = core.yaw_to_dir(yaw)
	local toward_user = vector.direction(from, to)
	forward.y, toward_user.y = 0, 0
	return vector.dot(vector.normalize(forward),
		vector.normalize(toward_user)) < 0
end

grug_abilities.register_ability({
	id = "opening", class = "scout", name = "Opening", kind = "swing",
	target_kind = "hostile", talent_gated = true, color = "#876b49",
	cost = {mana_percent = 15}, charge = 12,
	charge_talent = "opening_charge_sub", melee = true, range = 3,
	description = "A charged main-hand swing from behind for increased " ..
		"weapon damage. Unlocked via talents.",
	proc_swing = function(user, target, ctx)
		if not behind_target(user, target) then return nil end
		local percent = grug_classes.get_talent_bonus(user,
			"opening_multiplier")
		return math.floor(ctx.weapon_damage * percent / 100)
			+ ctx.melee_bonus + ctx.melee_damage_add
	end,
})

grug_abilities.scout_draw_active = function(player)
	return draws[player:get_player_name()] ~= nil
end
