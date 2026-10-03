grug_alchemy.TIER_LEVELS = {1, 11, 21, 31, 41, 51}
grug_alchemy.POTION_PERCENT = 30
grug_alchemy.POTION_COOLDOWN = 60
grug_alchemy.GREATER_COOLDOWN = 45
grug_alchemy.ELIXIR_DURATION = 900

local function equipment_bonus(player)
	local inventory = player:get_inventory()
	local count = 0
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		if count >= 2 then break end
		local stack = inventory:get_stack(slot.list, 1)
		if core.get_item_group(stack:get_name(), "grug_apothecary") > 0 then
			count = count + 1
		end
	end
	return count
end

grug_alchemy.apothecary_bonus = equipment_bonus

local function consume(itemstack, player)
	itemstack:take_item(1)
	core.sound_play("grug_alchemy_drink", {
		to_player = player:get_player_name(),
	}, true)
	return itemstack
end

local function instant_potion_amount(player, maximum)
	local amount = maximum * grug_alchemy.POTION_PERCENT / 100
	if grug_core.trinket_instant_potion then
		amount = grug_core.trinket_instant_potion(player, amount)
	end
	return math.max(1, math.floor(amount + 0.5))
end

-- Refusals go to the message feed (grug_core/feed.lua), never to chat; one
-- keyed line that a repeated click refreshes.
local function refuse(player, text)
	grug_core.feed(player, "notice", text, "potion")
end

local function player_ready(itemstack, player)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 then return false end
	local allowed, required = grug_core.can_use_item_level(player, itemstack)
	if not allowed then
		refuse(player, "Requires level " .. required .. ".")
		return false
	end
	local left = grug_traders.potion_cooldown_left(player)
	if left > 0 then
		refuse(player, "You cannot drink another potion for " .. left .. " s.")
		return false
	end
	return true
end

local function potion_use(kind, cooldown)
	return function(itemstack, player)
		if not player_ready(itemstack, player) then return end
		if kind == "health" then
			local maximum = grug_classes.get_max_hp(player)
			if player:get_hp() >= maximum then
				refuse(player, "You are already at full health.")
				return
			end
			local amount = instant_potion_amount(player, maximum)
			grug_core.heal_player(player, player, amount, {no_crit = true})
		else
			local maximum = grug_classes.get_max_mana(player)
			if maximum <= 0 then
				refuse(player, "Mana potions have no effect without a mana pool.")
				return
			end
			-- Deliberately consume at full mana: the ruling removes the
			-- full-resource refusal from the mana half.
			grug_abilities.restore_mana(player,
				instant_potion_amount(player, maximum))
		end
		grug_traders.start_potion_cooldown(player, cooldown)
		return consume(itemstack, player)
	end
end

local function utility_use(kind, duration)
	return function(itemstack, player)
		if not player_ready(itemstack, player) then return end
		local effective_duration = duration
		if duration > 0 then
			effective_duration = duration * (1 + equipment_bonus(player) * 0.10)
		end
		local accepted = true
		if kind == "antivenom" then
			accepted = grug_mobs.clear_poison(player)
			if not accepted then
				refuse(player, "You are not poisoned.")
				return
			end
		elseif kind == "swiftness" then
			grug_core.set_move_modifier(player, "alchemy_swiftness", {speed = 0.10},
				effective_duration)
			grug_core.set_status(player, "alchemy_swiftness", {
				label = "Swiftness Draught", duration = effective_duration,
			})
		elseif kind == "cave" then
			grug_core.set_night_vision(player, grug_core.NIGHT_VISION_RATIO)
			grug_core.set_status(player, "alchemy_cave", {
				label = "Cave Draught", duration = effective_duration,
				on_expire = function(target)
					grug_core.set_night_vision(target, nil)
				end,
			})
		end
		grug_traders.start_potion_cooldown(player, grug_alchemy.POTION_COOLDOWN)
		return consume(itemstack, player)
	end
end

-- The elixir family's status picture (grug_core/status_icons.lua), keyed by
-- the elixir's special kind or else its modifier.
local ELIXIR_VARIANT = {
	hp_pool_percent = "vigor",
	mana_pool_percent = "focus",
	crit_percent = "precision",
	armor = "stoneskin",
	deepwater = "deepwater",
}

-- The Effects tab detail line: the value actually granted (with the
-- equipment bonus), not the recipe's base value.
local ELIXIR_DETAIL = {
	hp_pool_percent = "+%d%% maximum HP",
	mana_pool_percent = "+%d%% maximum Mana",
	crit_percent = "+%d Crit",
	armor = "+%d%% armor",
}
local function elixir_detail(definition, modifiers)
	if definition.kind == "deepwater" then
		return "Water breathing"
	end
	local pattern = ELIXIR_DETAIL[definition.modifier]
	local value = modifiers[definition.modifier]
	return pattern and value and pattern:format(value) or ""
end

local function elixir_use(definition)
	return function(itemstack, player)
		if not player or not player.is_player or not player:is_player() or
				player:get_hp() <= 0 then return end
		local allowed, required = grug_core.can_use_item_level(player, itemstack)
		if not allowed then
			refuse(player, "Requires level " .. required .. ".")
			return
		end
		local pieces = equipment_bonus(player)
		local duration = definition.duration * (1 + pieces * 0.10)
		local modifiers = {}
		if definition.modifier then
			modifiers[definition.modifier] = definition.value + pieces
		end
		local status = {
			label = definition.label, duration = duration, modifiers = modifiers,
			variant = ELIXIR_VARIANT[definition.kind or definition.modifier],
			detail = elixir_detail(definition, modifiers),
		}
		if definition.kind == "deepwater" then
			local function refill_breath(target)
				local properties = target:get_properties()
				target:set_breath(properties.breath_max or 10)
			end
			status.interval = 1
			status.on_tick = refill_breath
			refill_breath(player)
		end
		grug_core.set_status(player, "elixir", status)
		return consume(itemstack, player)
	end
end

function grug_alchemy.register_consumable(id, definition)
	local groups = {grug_potion = 1}
	if definition.family == "potion" then groups.grug_potion_instant = 1
	else groups.grug_elixir = 1 end
	core.register_craftitem("grug_alchemy:" .. id, {
		description = definition.description,
		inventory_image = definition.image or
			"grug_traders_item_potion_healing_weak.png^[colorize:" ..
			(definition.color or "#55AA55") .. ":90",
		stack_max = 20,
		groups = groups,
		_grug_ilvl = grug_alchemy.TIER_LEVELS[definition.tier],
		on_use = definition.on_use,
	})
end

grug_alchemy.potion_use = potion_use
grug_alchemy.utility_use = utility_use
grug_alchemy.elixir_use = elixir_use

local function clear_visual(player)
	grug_core.set_night_vision(player, nil)
end

core.register_on_dieplayer(clear_visual)
