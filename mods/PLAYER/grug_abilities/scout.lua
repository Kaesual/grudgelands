-- The Scout's kit (docs/design/scout.md; Round 53, round K: round53-plan.md
-- §4 "SCOUT", class-redesign/skill-inventory.md §4.4, node-list.md Quarry
-- and Veil). The bow draw is gone: every bow skill is an instant shot at the
-- crosshair target, and the action clock (init.lua occupied_cast and
-- occupied_swing) is the price of the heavy ones.
--
-- Units (class-redesign/scout.md §2): a bow skill's numbers are shares of R,
-- the bow's damage plus the Dexterity bonus; a blade skill's of M, the Melee
-- slot's weapon damage plus the melee bonus. Both are raw amounts: the one
-- level scalar of deal_ability_damage or the swing scales them once. The
-- talents read here are the graph's (talent_graph_scout.lua): the family keys
-- through grug_abilities.family_bonus (damage_pct by the "bow" and "blade"
-- tags; cost, cooldown and range the cast path applies itself) and the
-- class keys below, each a share of R or M per rank.

local ARROW_PROJECTILE = "scout_arrow"
-- The arrow's nominal speed in m/s, every shot alike (the shipped fixed-power
-- shots' speed; the draw's faster full-draw arrow is gone with the draw).
local ARROW_SPEED = 40
-- The skill-arrow trail's tint per shot (particle_effects.lua "skill_arrow",
-- tools/r52_pfx cards: Loose has none); Arrowfall's first arrow has its own.
local ARROW_TRAILS = {
	true_draw = {effect = "skill_arrow", color = "#f0e6b8"},
	snare_shot = {effect = "skill_arrow", color = "#79a65a"},
	split_shot = {effect = "skill_arrow", color = "#a8c86a"},
	arrowfall = {effect = "arrowfall_trail"},
}
-- Loose's held cadence (skill-inventory §4.4): 0.85 s, divided by the bow's
-- own attack-speed affix, never below 0.65 s.
local LOOSE_INTERVAL, LOOSE_FLOOR = 0.85, 0.65
local ARROWFALL_ARROWS = 4
local next_action = 0

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

-- The bow skills read the Weapon slot, the Scout's "Ranged" slot (Round 28
-- ruling 25); Strike, Bladecraft and every blade skill read its Melee slot
-- through grug_core.get_melee_weapon instead.
local function equipped_bow(player)
	local stack = grug_core.get_equipped_weapon(player)
	if not stack or not grug_inventory.is_bow(stack) or
			grug_core.equipment_is_broken(stack) then
		return nil
	end
	return stack
end

-- R: the bow's damage plus the Dexterity bonus, nil without a usable bow.
local function bow_unit(player)
	local stack = equipped_bow(player)
	if not stack then return nil end
	local caps = stack:get_tool_capabilities() or {}
	local groups = caps.damage_groups or {}
	return math.max(0, tonumber(groups.fleshy) or 0)
		+ grug_classes.get_ranged_bonus(player)
end

-- M: the Melee slot's weapon damage plus the melee bonus (the bare hand
-- without a weapon), the plain swing's untalented damage.
local function blade_unit(player)
	local damage = grug_abilities.swing_stats(player)
	return damage + grug_classes.get_melee_bonus(player)
end

-- A coefficient of the unit with its damage_pct (Bowcraft, Fine Edge: a
-- share of the untalented damage) and its flat talent add.
local function coefficient(player, def, base, add)
	return base * (1 + grug_abilities.family_bonus(player, def, "damage_pct") / 100)
		+ (add or 0)
end

-- The tooltip number: the raw amount at the player's level before crit.
local function shown(player, amount)
	return grug_core.scale_player_damage(player, nil, amount)
end

-- The bow's OWN attack-speed affix in percent (Round 28 ruling 25): the
-- blade beside it has its own swing clock, so the shot does not sum the
-- whole equipment's affixes.
local function bow_speed(bow)
	local items = rawget(_G, "grug_items")
	if not bow or not items or not items.get_affixes then
		return 0
	end
	local speed = 0
	for _, affix in ipairs(items.get_affixes(bow)) do
		if affix.stat == "attack_speed_percent" then
			speed = speed + (tonumber(affix.value) or 0)
		end
	end
	return math.max(0, speed)
end
grug_abilities.bow_speed = bow_speed

-- Loose's cast interval (init.lua's clock seam): the base without a player.
local function loose_interval(player)
	if not player then return LOOSE_INTERVAL end
	return math.max(LOOSE_FLOOR,
		LOOSE_INTERVAL / (1 + bow_speed(equipped_bow(player)) / 100))
end

local function apply_slow(target, duration, factor)
	if target:is_player() then
		if target:get_hp() <= 0 then return end
		grug_core.set_move_modifier(target, "scout_snare", {
			speed = factor - 1,
		}, duration)
	else
		local ent = target:get_luaentity()
		if ent and (ent.health or 0) > 0 then grug_mobs.slow(ent, duration, factor) end
	end
end

grug_projectiles.register(ARROW_PROJECTILE, {
	speed = ARROW_SPEED,
	sound_launch = "bow_shot",
	sound_hit = "arrow_hit",
	max_distance = 25,
	-- A held Loose fires at most every 0.65 s and Arrowfall four at once.
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
		local tpos = target:get_pos() or point
		if data.ability == "arrowfall" then
			-- Every arriving arrow of the volley thuds (the user's pick, the
			-- arrowfall_repeat note), its spread from the spec's pitch; the
			-- burst is the first arrow's.
			grug_sounds.play("arrowfall_impact", target)
			if data.first then
				grug_core.particles.play("arrowfall_impact", {target = tpos})
			end
		end
		grug_core.deal_ability_damage(owner, target, data.damage, {
			attacker_level = attacker_level,
			action_id = data.action_id,
			-- A landed arrow (no dodge, no refusal): Snare Shot's slow and its
			-- ring, True Draw's Follow the Line window.
			on_accepted = function()
				if data.slow then
					apply_slow(target, data.slow, data.slow_factor)
					grug_core.particles.play("snare_hit", {target = tpos})
				end
				if data.follow and data.follow > 0 and owner:get_hp() > 0 and
						grug_classes.open_window(owner, "follow_the_line",
							{duration = 3, value = data.follow, label = "Follow the Line"}) then
					grug_core.proc_flash(owner, "follow_the_line")
				end
			end,
		})
		-- Split Shot: up to 2 other hostiles within 3 m of the struck target
		-- take its smaller hit, nearest first, in sight of it, through the
		-- shared target check (round53-plan.md §3 PvP); no arrows of their own.
		if data.splash then
			local others = grug_core.area.query(tpos, {radius = 3, cap = 2,
				filter = function(obj)
					return obj ~= target and grug_abilities.valid_target(owner, obj, "hostile")
				end})
			for _, obj in ipairs(others) do
				local opos = obj:get_pos()
				if opos then
					grug_core.particles.play("split_shot_splinter", {
						from = vector.offset(tpos, 0, 1, 0), to = vector.offset(opos, 0, 1, 0)})
					-- An area hit: no crit, as the calculator models it.
					grug_core.deal_ability_damage(owner, obj, data.splash, {
						attacker_level = attacker_level, action_id = data.action_id,
						no_crit = true})
				end
			end
		end
	end,
})

-- Fires `count` arrows of `def` together at the crosshair target, which
-- each homes on (grug_projectiles): one receipt, the ammunition taken
-- atomically with the spawn. `shot` = {damage (raw, per arrow), slow and
-- slow_factor, follow, splash, refund (percent)}. Refusals spend nothing.
local function launch(player, def, count, shot)
	if grug_core.refuse_mounted_attack and
			grug_core.refuse_mounted_attack(player) == true then
		return false, "You cannot attack while mounted."
	end
	if not equipped_bow(player) then
		return false, "Equip a usable bow in your Ranged slot."
	end
	if grug_inventory.ammo_count(player) < count then
		return false, count == 1 and "You need an arrow." or
			(def.name .. " needs " .. count .. " arrows.")
	end
	local origin = grug_core.combat_eye_pos(player)
	local direction = player:get_look_dir()
	if not origin or not direction or vector.length(direction) <= 0 then
		return false, "Cannot determine your aim."
	end
	-- The aim authority of every targeted skill (kits.lua): a live, legal
	-- hostile under the crosshair within the skill's range (Long View and the
	-- race's bonus included).
	if not grug_abilities.aimed_target(player, def) then
		return false, "No hostile target in your crosshair."
	end
	local receipt = repair_receipt(player, action_id(player, def.id))
	local launches = {}
	for index = 1, count do
		launches[index] = {
			owner = player,
			origin = vector.new(origin),
			direction = vector.new(direction),
			speed = ARROW_SPEED,
			max_distance = grug_abilities.get_range(player, def),
			-- A volley trails once, on its first arrow; it sounds through the
			-- cast's own cue (try_cast plays cast_arrowfall, which this launch
			-- cue plays first and its 0.1 s interval then drops), so its arrows
			-- add no bow_shot.
			trail = index == 1 and ARROW_TRAILS[def.id] or nil,
			sound_launch = count > 1 and "cast_arrowfall" or nil,
			data = {
				damage = shot.damage,
				slow = shot.slow,
				slow_factor = shot.slow_factor,
				follow = shot.follow,
				splash = shot.splash,
				ability = def.id,
				first = index == 1,
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
	if shot.refund and shot.refund > 0 and math.random(1, 100) <= shot.refund then
		grug_inventory.refund_ammo(player, count)
	end
	return true
end

--
-- Quarry: the bow.
--

-- Loose (and Bladecraft's right-click shot): 0.95 R; Follow the Line's open
-- window adds its share (`window`, consumed by the shot).
local function loose_values(player, def, window)
	local unit = bow_unit(player) or 0
	return {damage = unit * coefficient(player, def, 0.95, window or 0)}
end

local function loose_shot(player, def)
	-- The window is read first and spent only by a shot that flew.
	local open = grug_classes.get_window(player, "follow_the_line")
	local ok, err = launch(player, def, 1, {
		damage = loose_values(player, def, open and open.value).damage,
		refund = grug_classes.get_talent_bonus(player, "arrow_refund_chance"),
	})
	if ok and open then grug_classes.consume_window(player, "follow_the_line") end
	return ok, err
end

grug_abilities.register_ability({
	id = "loose", class = "scout", name = "Loose", kind = "cast",
	target_kind = "hostile", color = "#5fae5f", cost = {}, cooldown = 0,
	-- The Scout's own basic attack (round53-plan.md K7): slot 1 of a new
	-- character's hotbar, before Strike.
	basic_attack = true,
	tags = {"bow"},
	range = 25,
	cast_interval = loose_interval,
	values = function(player, def) return loose_values(player, def) end,
	description = "Looses an arrow at a visible hostile target within 25 m; " ..
		"hold to keep shooting. With no arrow left, a foe in reach gets Strike.",
	description_for = function(player, def)
		return ("Looses an arrow at a visible hostile target within 25 m: " ..
			"%d damage; hold to keep shooting (every %g s). With no arrow left, " ..
			"a foe in reach gets Strike."):format(
				shown(player, def.values(player, def).damage),
				math.floor(loose_interval(player) * 100 + 0.5) / 100)
	end,
	cast = function(user, _, def)
		return loose_shot(user, def)
	end,
})

-- Sidestep and Sprint are starters, so they come before the talent-gated
-- skills (the file's order is the class's order: the catalogue row and the
-- starter hotbar, round53-plan.md K7).
grug_abilities.register_ability({
	id = "sidestep", class = "scout", name = "Sidestep", kind = "cast",
	target_kind = "self", color = "#73b897", cost = {mana_percent = 6},
	cooldown = 18, range = 0,
	occupied_cast = 0.25, occupied_swing = 0.25,
	description = "Gain 15 percentage points of dodge for 3 s.",
	description_for = function(player)
		if grug_classes.get_talent_bonus(player, "sidestep_frees") > 0 then
			return "Gain 15 percentage points of dodge for 3 s and shake off " ..
				"slows and roots."
		end
		return "Gain 15 percentage points of dodge for 3 s."
	end,
	cast = function(user)
		grug_classes.start_sidestep(user)
		grug_core.particles.play("sidestep", {caster = user:get_pos()})
		return true
	end,
})

grug_abilities.register_ability({
	id = "sprint", repeat_policy = "once", class = "scout", name = "Sprint", kind = "cast",
	target_kind = "self", color = "#c9b85d", cost = {mana_percent = 15},
	cooldown = 300, range = 0,
	description = "Move 50% faster for 10 s.",
	cast = function(user)
		grug_core.set_move_modifier(user, "scout_sprint", {speed = 0.50}, 10)
		grug_core.set_status(user, "scout_sprint", {
			label = "Sprint",
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
		grug_core.particles.play("sprint", {caster = user:get_pos(),
			dir = grug_core.particles.facing(user)})
		return true
	end,
})

-- True Draw (Q4): one heavy instant shot, 2.2 R plus Firm Aim; a landed
-- one opens Follow the Line (Q11) for the next Loose.
local function true_draw_values(player, def)
	local unit = bow_unit(player) or 0
	return {damage = unit * coefficient(player, def, 2.2,
		grug_classes.get_talent_bonus(player, "true_draw_add"))}
end

grug_abilities.register_ability({
	id = "true_draw", class = "scout", name = "True Draw", kind = "cast",
	target_kind = "hostile", talent_gated = true, talent = "quarry_true_draw",
	color = "#d8c46a", tags = {"bow"}, cost = {mana_percent = 6}, cooldown = 6,
	range = 25, occupied_cast = 1.35, occupied_swing = 1.35,
	values = true_draw_values,
	description = "An instant heavy shot at a visible hostile target; " ..
		"1 arrow. Unlocked via talents.",
	description_for = function(player, def)
		return ("An instant heavy shot at a visible hostile target: %d damage; " ..
			"1 arrow, then 1.35 s before your next action."):format(
				shown(player, def.values(player, def).damage))
	end,
	cast = function(user, _, def)
		return launch(user, def, 1, {
			damage = def.values(user, def).damage,
			-- Follow the Line's share of R, the window's value (loose_values).
			follow = grug_classes.get_talent_bonus(user, "follow_the_line_add"),
		})
	end,
})

-- Snare Shot (Q6): 0.45 R and a 35 % slow for 3 s on a landed hit.
grug_abilities.register_ability({
	id = "snare_shot", class = "scout", name = "Snare Shot", kind = "cast",
	target_kind = "hostile", talent_gated = true, talent = "quarry_snare_shot",
	color = "#79a65a", tags = {"bow"}, cost = {mana_percent = 5}, cooldown = 14,
	range = 25, occupied_cast = 0.85, occupied_swing = 0.85,
	values = function(player, def)
		return {damage = (bow_unit(player) or 0) * coefficient(player, def, 0.45)}
	end,
	description = "Fires at a visible hostile target and slows it by 35% for 3 s " ..
		"when it lands; 1 arrow. Unlocked via talents.",
	description_for = function(player, def)
		return ("Fires at a visible hostile target: %d damage, and a 35%% slow " ..
			"for 3 s when it lands; 1 arrow."):format(
				shown(player, def.values(player, def).damage))
	end,
	cast = function(user, _, def)
		return launch(user, def, 1, {damage = def.values(user, def).damage,
			slow = 3, slow_factor = 0.65})
	end,
})

-- Split Shot (Q8): 0.90 R on the target; up to 2 others within 3 m of it
-- take 0.55 R plus Broad Shot (Q9).
local function split_values(player, def)
	local unit = bow_unit(player) or 0
	return {damage = unit * coefficient(player, def, 0.90),
		splash = unit * coefficient(player, def, 0.55,
			grug_classes.get_talent_bonus(player, "split_shot_add"))}
end

grug_abilities.register_ability({
	id = "split_shot", class = "scout", name = "Split Shot", kind = "cast",
	target_kind = "hostile", talent_gated = true, talent = "quarry_split_shot",
	color = "#a8c86a", tags = {"bow"}, cost = {mana_percent = 8}, cooldown = 10,
	range = 25, occupied_cast = 1.0, occupied_swing = 1.0,
	values = split_values,
	description = "Fires at a visible hostile target; up to 2 others within 3 m " ..
		"of it take a smaller hit. 1 arrow. Unlocked via talents.",
	description_for = function(player, def)
		local v = def.values(player, def)
		return ("Fires at a visible hostile target: %d damage; up to 2 others " ..
			"within 3 m of it take %d. 1 arrow."):format(shown(player, v.damage),
				shown(player, v.splash))
	end,
	cast = function(user, _, def)
		local v = def.values(user, def)
		return launch(user, def, 1, {damage = v.damage, splash = v.splash})
	end,
})

-- Arrowfall (Q12, the Quarry ultimate): four arrows together at the
-- crosshair target, each 1.4 R plus Iron Hail (Q13), crits allowed; refused
-- with fewer than four arrows.
grug_abilities.register_ability({
	id = "arrowfall", class = "scout", name = "Arrowfall", kind = "cast",
	target_kind = "hostile", talent_gated = true, talent = "quarry_arrowfall",
	color = "#b89a68", tags = {"bow"}, cost = {mana_percent = 16}, cooldown = 60,
	range = 25, occupied_cast = 2.5, occupied_swing = 2.5,
	values = function(player, def)
		return {damage = (bow_unit(player) or 0) * coefficient(player, def, 1.4,
			grug_classes.get_talent_bonus(player, "arrowfall_add"))}
	end,
	description = "Four arrows at once at a visible hostile target; 4 arrows. " ..
		"Unlocked via talents.",
	description_for = function(player, def)
		return ("Four arrows at once at a visible hostile target, %d damage " ..
			"each; 4 arrows, then 2.5 s before your next action."):format(
				shown(player, def.values(player, def).damage))
	end,
	cast = function(user, _, def)
		return launch(user, def, ARROWFALL_ARROWS, {damage = def.values(user, def).damage})
	end,
})

--
-- Veil: the blade.
--

-- Bladecraft's right-click shot: the same Loose shot (Bowcraft, Quiver and
-- Follow the Line included) on Loose's cast interval, which a
-- transformation shares (its cooldown key), and on the action clock like
-- every cast. A plain table, never registered: input.lua hands it to
-- try_cast as the press's cast while Bladecraft is selected; its id is
-- Bladecraft's, so the unlock and class checks are Bladecraft's.
local bladecraft_shot = {
	id = "bladecraft", class = "scout", name = "Bladecraft", kind = "cast",
	target_kind = "hostile", cost = {}, cooldown = 0, cooldown_key = "loose",
	tags = {"bow"}, range = 25, cast_interval = loose_interval,
	occupied_cast = 0, occupied_swing = "weapon",
	cast = function(user)
		return loose_shot(user, grug_abilities.registered.loose)
	end,
}

grug_abilities.register_ability({
	id = "bladecraft", class = "scout", name = "Bladecraft", kind = "swing",
	target_kind = "hostile", talent_gated = true, talent = "veil_bladecraft",
	transforms = "loose", color = "#7a62b8", tags = {"blade"}, cost = {},
	melee = true, range = 3,
	secondary_cast = bladecraft_shot,
	description = "Left click swings your Melee-slot blade; right click looses " ..
		"an arrow at a visible hostile target. Both share one clock. " ..
		"Unlocked via talents.",
	description_for = function(player)
		local loose = grug_abilities.registered.loose
		return ("Left click swings your Melee-slot blade (%d damage); right " ..
			"click looses an arrow at a visible hostile target (%d damage). " ..
			"Both share one clock."):format(
				shown(player, blade_unit(player) * coefficient(player,
					grug_abilities.registered.bladecraft, 1)),
				shown(player, loose_values(player, loose).damage))
	end,
})

-- Opening's rear: the Scout is behind the target's facing (its back
-- half-plane).
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

-- Opening's share of M: 1.35 from the front; 1.80 from behind or in Parry's
-- window, which Turn the Blade (V10) raises further.
local function opening_coefficient(player, def, empowered, parried)
	if not empowered then
		return coefficient(player, def, 1.35)
	end
	return coefficient(player, def, 1.80, parried and
		grug_classes.get_talent_bonus(player, "opening_parry_add") or 0)
end

grug_abilities.register_ability({
	id = "opening", class = "scout", name = "Opening", kind = "swing",
	target_kind = "hostile", talent_gated = true, talent = "veil_opening",
	color = "#876b49", tags = {"blade"}, cost = {mana_percent = 5}, charge = 8,
	melee = true, range = 3,
	description = "A charged swing of your Melee-slot blade for heavier damage, " ..
		"heavier still from behind or in Parry's window. Unlocked via talents.",
	description_for = function(player, def)
		local unit = blade_unit(player)
		return ("A charged swing of your Melee-slot blade: %d damage, %d from " ..
			"behind or in Parry's window (which it spends)."):format(
				shown(player, unit * opening_coefficient(player, def, false)),
				shown(player, unit * opening_coefficient(player, def, true, true)))
	end,
	proc_swing = function(user, target, ctx)
		local parried = grug_classes.get_window(user, "parry") ~= nil
		local empowered = parried or behind_target(user, target)
		local def = grug_abilities.registered.opening
		local tpos = target:get_pos() -- before the punch (lethal invalidates refs)
		-- The window and the flash are the landed proc's post, never the
		-- preparation.
		return (ctx.weapon_damage + ctx.melee_bonus) *
			opening_coefficient(user, def, empowered, parried), nil, function()
				if parried then grug_classes.consume_window(user, "parry") end
				grug_core.particles.play("opening", {target = tpos})
			end
	end,
})

-- Parry (V6): a shield of 10 % of the base pool for 2 s and Opening's
-- window for 3 s, both longer by Held Guard (V7), at the cast (the user's
-- ruling: no hit detection).
grug_abilities.register_ability({
	id = "parry", class = "scout", name = "Parry", kind = "cast",
	target_kind = "self", talent_gated = true, talent = "veil_parry",
	color = "#c8cfe0", tags = {"blade"}, cost = {mana_percent = 4}, cooldown = 12,
	range = 0, occupied_cast = 0.5, occupied_swing = 0.5,
	values = function(player, def)
		local extra = grug_abilities.family_bonus(player, def, "duration_add")
		return {absorb = grug_core.base_pool(grug_core.get_player_level(player)) * 0.10,
			shield = 2 + extra, window = 3 + extra}
	end,
	description = "Raise a short shield and open Opening's window. " ..
		"Unlocked via talents.",
	description_for = function(player, def)
		local v = def.values(player, def)
		return ("Raise a shield of %d for %g s and open Opening's window for " ..
			"%g s."):format(math.floor(v.absorb), v.shield, v.window)
	end,
	cast = function(user, _, def)
		local v = def.values(user, def)
		grug_core.add_absorb(user, "parry", v.absorb, v.shield, user)
		grug_classes.open_window(user, "parry", {duration = v.window, label = "Parry"})
		grug_core.particles.play("parry", {caster = user:get_pos(),
			dir = grug_core.particles.facing(user)})
		return true
	end,
})

-- Flourish (V8): the 3 nearest hostiles in a 90 degree, 3 m cone in front
-- take 0.80 M plus Wide Edge (V9). It occupies the longer of 1 s and the
-- blade's interval.
local function flourish_occupied(player)
	if not player then return 1.0 end
	local _, interval = grug_abilities.swing_stats(player)
	return math.max(1.0, interval)
end

grug_abilities.register_ability({
	id = "flourish", offensive = true, class = "scout", name = "Flourish",
	kind = "cast", target_kind = "self", talent_gated = true, talent = "veil_flourish",
	color = "#b9a2e6", tags = {"blade"}, cost = {mana_percent = 8}, cooldown = 12,
	range = 3, occupied_cast = flourish_occupied, occupied_swing = flourish_occupied,
	values = function(player, def)
		return {damage = blade_unit(player) * coefficient(player, def, 0.80,
			grug_classes.get_talent_bonus(player, "flourish_add"))}
	end,
	description = "Sweep your blade across the 3 nearest enemies in front of you " ..
		"within 3 m. Unlocked via talents.",
	description_for = function(player, def)
		return ("Sweep your blade across the 3 nearest enemies in front of you " ..
			"within 3 m: %d damage each."):format(
				shown(player, def.values(player, def).damage))
	end,
	cast = function(user, _, def)
		local damage = def.values(user, def).damage
		local action = {}
		for _, obj in ipairs(grug_core.area.cone(user, {radius = 3, angle = 90, cap = 3,
				filter = grug_abilities.target_filter(user, "hostile")})) do
			-- An area hit: no crit (the calculator's model).
			grug_core.deal_ability_damage(user, obj, damage, {action_id = action, no_crit = true})
		end
		grug_core.particles.play("flourish", {caster = user:get_pos(),
			dir = grug_core.particles.facing(user)})
		return true
	end,
})

-- Close Dance (V12, the Veil ultimate): for 6 s every plain blade swing
-- adds 0.35 M plus Cutting Rhythm (V13), and a shield of 15 % of the base
-- pool holds as long.
grug_abilities.register_ability({
	id = "close_dance", class = "scout", name = "Close Dance", kind = "cast",
	target_kind = "self", talent_gated = true, talent = "veil_close_dance",
	color = "#5a4a9a", tags = {"blade"}, cost = {mana_percent = 14}, cooldown = 60,
	range = 0, occupied_cast = 0.25, occupied_swing = 0.25,
	values = function(player)
		return {absorb = grug_core.base_pool(grug_core.get_player_level(player)) * 0.15,
			add = 0.35 + grug_classes.get_talent_bonus(player, "close_dance_add")}
	end,
	description = "For 6 s your blade swings hit harder and a shield holds. " ..
		"Unlocked via talents.",
	description_for = function(player, def)
		local v = def.values(player, def)
		return ("For 6 s your blade swings deal %d more damage, and a shield of " ..
			"%d holds."):format(shown(player, blade_unit(player) * v.add),
				math.floor(v.absorb))
	end,
	cast = function(user, _, def)
		grug_core.add_absorb(user, "close_dance", def.values(user, def).absorb, 6, user)
		grug_classes.open_window(user, "close_dance", {duration = 6, label = "Close Dance"})
		grug_core.particles.play("close_dance", {caster = user:get_pos()})
		return true
	end,
})

-- Close Dance's window on every plain blade swing (init.lua's swing
-- callback): a swing of a blade-tagged skill (Strike, Bladecraft, an
-- uncharged Opening) that fires no proc.
local function blade_tagged(def)
	for _, tag in ipairs(def.tags or {}) do
		if tag == "blade" then return true end
	end
	return false
end

grug_abilities.register_on_swing(function(player, swing)
	if swing.proc or not blade_tagged(swing.def) or
			not grug_classes.get_window(player, "close_dance") then
		return nil
	end
	local add = 0.35 + grug_classes.get_talent_bonus(player, "close_dance_add")
	return {
		damage_add = (swing.weapon_damage + grug_classes.get_melee_bonus(player)) * add,
		on_landed = function(_, landed)
			local tpos = landed.target and landed.target:get_pos()
			if tpos then grug_core.particles.play("close_dance_swing", {target = tpos}) end
		end,
	}
end)
