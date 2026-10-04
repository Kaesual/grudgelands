grug_alchemy.TIER_LEVELS = {1, 11, 21, 31, 41, 51}

local function consume(itemstack, player)
	itemstack:take_item(1)
	grug_sounds.play("potion_drink", player)
	return itemstack
end

-- A potion restores its fixed amount; an instant-potion trinket scales it.
local function instant_potion_amount(player, amount)
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

local function potion_use(kind, amount)
	return function(itemstack, player)
		if not player_ready(itemstack, player) then return end
		if kind == "health" then
			if player:get_hp() >= grug_classes.get_max_hp(player) then
				refuse(player, "You are already at full health.")
				return
			end
			grug_core.heal_player(player, player,
				instant_potion_amount(player, amount), {no_crit = true})
		else
			if grug_classes.get_max_mana(player) <= 0 then
				refuse(player, "Mana potions have no effect without a mana pool.")
				return
			end
			-- Deliberately consume at full mana: the ruling removes the
			-- full-resource refusal from the mana half.
			grug_abilities.restore_mana(player,
				instant_potion_amount(player, amount))
		end
		grug_traders.start_potion_cooldown(player)
		return consume(itemstack, player)
	end
end

local function utility_use(kind, duration)
	return function(itemstack, player)
		if not player_ready(itemstack, player) then return end
		local accepted = true
		if kind == "antivenom" then
			accepted = grug_mobs.clear_poison(player)
			if not accepted then
				refuse(player, "You are not poisoned.")
				return
			end
		elseif kind == "swiftness" then
			grug_core.set_move_modifier(player, "alchemy_swiftness", {speed = 0.10},
				duration)
			grug_core.set_status(player, "alchemy_swiftness", {
				label = "Swiftness Draught", duration = duration,
			})
		elseif kind == "cave" then
			grug_core.set_night_vision(player, grug_core.NIGHT_VISION_RATIO)
			grug_core.set_status(player, "alchemy_cave", {
				label = "Cave Draught", duration = duration,
				on_expire = function(target)
					grug_core.set_night_vision(target, nil)
				end,
			})
		end
		grug_traders.start_potion_cooldown(player)
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

-- The Effects tab detail line: the value the elixir grants.
local ELIXIR_DETAIL = {
	hp_pool_percent = "+%.1f%% maximum HP",
	mana_pool_percent = "+%.1f%% maximum Mana",
	crit_percent = "+%.1f Crit",
	armor = "+%.1f armor rating",
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
		local modifiers = {}
		if definition.modifier then
			modifiers[definition.modifier] = definition.value
		end
		local status = {
			label = definition.label, duration = definition.duration,
			modifiers = modifiers,
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
