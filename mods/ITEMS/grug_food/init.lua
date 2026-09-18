-- Food v2 (Round 7, 2026-09-18). Tier numbers and dish effects are data so
-- Round 8 can replace the proposal table without changing consumption code.

grug_food = {}

grug_food.DURATION = 180
grug_food.INTERVAL = 5

grug_food.TIERS = {
	[1] = {instant_hp = 5, min_level = 1, dishes = {
		hp = {regen = {hp = 2}, modifiers = {}},
		mana = {regen = {mana = 2}, modifiers = {}},
		hybrid = {regen = {hp = 1, mana = 1}, modifiers = {}},
	}},
	[2] = {instant_hp = 15, min_level = 10, dishes = {
		hp = {regen = {hp = 3}, modifiers = {}},
		mana = {regen = {mana = 3}, modifiers = {}},
		hybrid = {regen = {hp = 1.5, mana = 1.5}, modifiers = {}},
	}},
	[3] = {instant_hp = 40, min_level = 20, dishes = {
		hp = {regen = {hp = 3}, modifiers = {hp_pool_percent = 2}},
		mana = {regen = {mana = 3}, modifiers = {mana_pool_percent = 2}},
		hybrid = {regen = {hp = 1.5, mana = 1.5}, modifiers = {
			hp_pool_percent = 1, mana_pool_percent = 1,
		}},
	}},
	[4] = {instant_hp = 90, min_level = 30, dishes = {
		hp = {regen = {hp = 4}, modifiers = {hp_pool_percent = 4}},
		mana = {regen = {mana = 4}, modifiers = {mana_pool_percent = 4}},
		hybrid = {regen = {hp = 2, mana = 2}, modifiers = {
			hp_pool_percent = 2, mana_pool_percent = 2,
		}},
	}},
	[5] = {instant_hp = 180, min_level = 40, dishes = {
		hp = {regen = {hp = 4}, modifiers = {hp_pool_percent = 6}},
		mana = {regen = {mana = 4}, modifiers = {mana_pool_percent = 6}},
		hybrid = {regen = {hp = 2, mana = 2}, modifiers = {crit_percent = 1}},
	}},
	[6] = {instant_hp = 300, min_level = 50, dishes = {
		hp = {regen = {hp = 5}, modifiers = {hp_pool_percent = 8}},
		mana = {regen = {mana = 5}, modifiers = {mana_pool_percent = 8}},
		hybrid = {regen = {hp = 2.5, mana = 2.5}, modifiers = {crit_percent = 1}},
	}},
}

grug_food.converted = {}

-- An instant heal deferred by combat outlives the timed food status. Keeping
-- it here also makes replacement explicit: one player has at most one unpaid
-- serving, and a newer serving overwrites it.
local pending_instant = {} -- player name -> fixed HP amount
local instant_check_accumulator = 0
local INSTANT_CHECK_INTERVAL = 1

local function number_text(value)
	return ("%g"):format(value)
end

function grug_food.tick_amount(maximum, percent)
	maximum = math.max(0, tonumber(maximum) or 0)
	percent = math.max(0, tonumber(percent) or 0)
	return math.max(1, math.floor(maximum * percent / 100))
end

function grug_food.effect_for(tier, kind, role)
	local tier_def = grug_food.TIERS[tier]
	if not tier_def then
		return nil
	end
	if kind == "raw" and (role == "hp" or role == "mana") then
		return {regen = {[role] = 1}, modifiers = {}}
	end
	if kind == "dish" then
		return tier_def.dishes[role]
	end
	return nil
end

local function restore_health_percent(player, percent)
	local maximum = grug_classes.get_max_hp(player)
	local hp = player:get_hp()
	if hp <= 0 then
		return 0
	end
	local amount = grug_food.tick_amount(maximum, percent)
	local restored = math.min(amount, math.max(0, maximum - hp))
	if restored > 0 then
		player:set_hp(hp + restored)
	end
	return restored
end

local function restore_health_flat(player, amount)
	local maximum = grug_classes.get_max_hp(player)
	local hp = player:get_hp()
	if hp <= 0 then
		return 0
	end
	local restored = math.min(amount, math.max(0, maximum - hp))
	if restored > 0 then
		player:set_hp(hp + restored)
	end
	return restored
end

local function restore_mana(player, percent)
	local maximum = grug_classes.get_max_mana(player)
	if maximum <= 0 then
		return 0
	end
	return grug_abilities.restore_mana(player,
		grug_food.tick_amount(maximum, percent))
end

local function assign_instant(player, amount)
	local name = player:get_player_name()
	if grug_core.in_combat(player) then
		pending_instant[name] = amount
		return
	end
	pending_instant[name] = nil
	restore_health_flat(player, amount)
end

local function modifier_parts(modifiers, tooltip)
	local labels = {}
	local rows = {
		{"hp_pool_percent", "HP pool", "maximum HP"},
		{"mana_pool_percent", "Mana pool", "maximum Mana"},
		{"crit_percent", "Crit", "Crit"},
		{"armor", "armor", "armor"},
		{"spell_damage_percent", "spell damage", "spell damage"},
	}
	for index = 1, #rows do
		local value = modifiers[rows[index][1]]
		if value then
			if tooltip then
				labels[#labels + 1] = "+" .. number_text(value) .. "% " ..
					rows[index][3]
			else
				labels[#labels + 1] = "+" .. number_text(value) .. "% " ..
					rows[index][2]
			end
		end
	end
	return labels
end

function grug_food.status_label(effect)
	local regen = {}
	if effect.regen.hp then
		regen[#regen + 1] = "+" .. number_text(effect.regen.hp) .. "% HP"
	end
	if effect.regen.mana then
		regen[#regen + 1] = "+" .. number_text(effect.regen.mana) .. "% Mana"
	end
	if #regen > 0 then
		regen[#regen] = regen[#regen] .. "/" .. grug_food.INTERVAL .. "s"
	end
	local parts = regen
	local modifiers = modifier_parts(effect.modifiers, false)
	for index = 1, #modifiers do
		parts[#parts + 1] = modifiers[index]
	end
	return "Food " .. table.concat(parts, ", ")
end

local function tooltip_for(tier, effect)
	local tier_def = grug_food.TIERS[tier]
	local lines = {
		("Restores %d HP instantly."):format(tier_def.instant_hp),
	}
	local regen = {}
	if effect.regen.hp then
		regen[#regen + 1] = number_text(effect.regen.hp) .. "% of maximum HP"
	end
	if effect.regen.mana then
		regen[#regen + 1] = number_text(effect.regen.mana) .. "% of maximum Mana"
	end
	if #regen > 0 then
		lines[#lines + 1] = "Regenerates " .. table.concat(regen, " and ") ..
			(" every %d s for 3 min."):format(grug_food.INTERVAL)
	end
	local bonuses = modifier_parts(effect.modifiers, true)
	if #bonuses > 0 then
		lines[#lines + 1] = "Grants " .. table.concat(bonuses, " and ") ..
			" while active."
	end
	lines[#lines + 1] = "Instant heal and regeneration wait until you are out of combat; other bonuses stay."
	if tier_def.min_level > 1 then
		lines[#lines + 1] = "Requires level " .. tier_def.min_level .. "."
	end
	return table.concat(lines, "\n")
end

local function start_food_status(player, tier, effect)
	local tier_def = grug_food.TIERS[tier]
	local record = grug_core.set_status(player, "food", {
		label = grug_food.status_label(effect),
		duration = grug_food.DURATION,
		kind = "buff",
		interval = grug_food.INTERVAL,
		modifiers = effect.modifiers,
		on_tick = function(target)
			if grug_core.in_combat(target) then
				return
			end
			if effect.regen.hp then
				restore_health_percent(target, effect.regen.hp)
			end
			if effect.regen.mana then
				restore_mana(target, effect.regen.mana)
			end
		end,
	})
	if record then
		assign_instant(player, tier_def.instant_hp)
	end
	return record
end

local function clear_pending_instant(player)
	pending_instant[player:get_player_name()] = nil
end

core.register_on_dieplayer(clear_pending_instant)
core.register_on_leaveplayer(clear_pending_instant)

-- The status registry deliberately removes food and its modifiers at 180 s.
-- Check only players that still have an unpaid instant heal, so a long combat
-- can end later without extending the buff or scanning every connected player.
core.register_globalstep(function(dtime)
	instant_check_accumulator = instant_check_accumulator + dtime
	if instant_check_accumulator < INSTANT_CHECK_INTERVAL then
		return
	end
	instant_check_accumulator = instant_check_accumulator %
		INSTANT_CHECK_INTERVAL
	for name, amount in pairs(pending_instant) do
		local player = core.get_player_by_name(name)
		if player and player:get_hp() > 0 and not grug_core.in_combat(player) then
			pending_instant[name] = nil
			restore_health_flat(player, amount)
		end
	end
end)

function grug_food.eat(itemstack, user, tier, kind, role)
	if not user or not user.is_player or not user:is_player() or
			user:get_hp() <= 0 then
		return itemstack
	end
	local effect = grug_food.effect_for(tier, kind, role)
	if not effect then
		return itemstack
	end
	local allowed, required = grug_core.can_use_item_level(user, itemstack)
	if not allowed then
		core.chat_send_player(user:get_player_name(),
			"Requires level " .. required .. ".")
		return itemstack
	end
	if effect.regen.mana and grug_classes.get_max_mana(user) <= 0 then
		core.chat_send_player(user:get_player_name(),
			"Mana food has no effect without a mana pool.")
		return itemstack
	end
	if start_food_status(user, tier, effect) then
		itemstack:take_item(1)
	end
	return itemstack
end

local function copied_groups(groups)
	local copy = {}
	for key, value in pairs(groups or {}) do
		copy[key] = value
	end
	return copy
end

function grug_food.register_item(item_name, tier, kind, role)
	local definition = core.registered_items[item_name]
	local tier_def = grug_food.TIERS[tier]
	local effect = grug_food.effect_for(tier, kind, role)
	if not definition or not tier_def or not effect then
		return false
	end
	local groups = copied_groups(definition.groups)
	groups.grug_food = 1
	groups.grug_food_tier = tier
	groups["grug_food_" .. kind] = 1
	groups["grug_food_role_" .. role] = 1
	core.override_item(item_name, {
		description = tostring(definition.description or item_name) .. "\n" ..
			tooltip_for(tier, effect),
		groups = groups,
		_grug_ilvl = tier_def.min_level,
		on_use = function(itemstack, user)
			return grug_food.eat(itemstack, user, tier, kind, role)
		end,
	})
	grug_food.converted[#grug_food.converted + 1] = {
		name = item_name,
		tier = tier,
		kind = kind,
		role = role,
	}
	return true
end

local CURRENT_FOODS = {
	{"default:apple", 1, "raw", "hp"},
	{"default:blueberries", 1, "raw", "hp"},
	{"mobs:meat_raw", 1, "raw", "hp"},
	{"mobs:meat", 1, "dish", "hp"},
	{"mobs:meatblock_raw", 1, "raw", "hp"},
	{"mobs:meatblock", 1, "dish", "hp"},
	{"grug_mobs:raw_fish", 1, "raw", "hp"},
	{"grug_fishing:cooked_fish", 1, "dish", "hp"},
}

for index = 1, #CURRENT_FOODS do
	local row = CURRENT_FOODS[index]
	assert(grug_food.register_item(row[1], row[2], row[3], row[4]),
		"grug_food: missing current food " .. row[1])
end

local gathering = grug_gathering.p9g_sources()
for index = 1, #gathering do
	local row = gathering[index]
	if row.harvest_kind == "food" or row.harvest_kind == "found_only_food" then
		local role = row.raw_item == "grug_gathering:wild_cocoa"
			and "mana" or "hp"
		assert(grug_food.register_item(row.raw_item, row.tier or 1, "raw", role),
			"grug_food: missing gathering food " .. row.raw_item)
	end
end
