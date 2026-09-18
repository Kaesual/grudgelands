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

local function consume(itemstack)
	itemstack:take_item(1)
	return itemstack
end

local function player_ready(itemstack, player)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 then return false end
	local allowed, required = grug_core.can_use_item_level(player, itemstack)
	if not allowed then
		core.chat_send_player(player:get_player_name(),
			"Requires level " .. required .. ".")
		return false
	end
	local left = grug_traders.potion_cooldown_left(player)
	if left > 0 then
		core.chat_send_player(player:get_player_name(),
			"You cannot drink another potion for " .. left .. " s.")
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
				core.chat_send_player(player:get_player_name(),
					"You are already at full health.")
				return
			end
			local amount = math.max(1,
				math.floor(maximum * grug_alchemy.POTION_PERCENT / 100 + 0.5))
			grug_core.heal_player(player, player, amount, {no_crit = true})
		else
			local maximum = grug_classes.get_max_mana(player)
			if maximum <= 0 then
				core.chat_send_player(player:get_player_name(),
					"Mana potions have no effect without a mana pool.")
				return
			end
			-- Deliberately consume at full mana: the ruling removes the
			-- full-resource refusal from the mana half.
			grug_abilities.restore_mana(player,
				math.max(1, math.floor(maximum * grug_alchemy.POTION_PERCENT / 100 + 0.5)))
		end
		grug_traders.start_potion_cooldown(player, cooldown)
		return consume(itemstack)
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
				core.chat_send_player(player:get_player_name(), "You are not poisoned.")
				return
			end
		elseif kind == "swiftness" then
			grug_core.set_move_modifier(player, "alchemy_swiftness", {speed = 0.10},
				effective_duration)
			grug_core.set_status(player, "alchemy_swiftness", {
				label = "Swiftness +10%", duration = effective_duration,
			})
		elseif kind == "cave" then
			player:override_day_night_ratio(0.45)
			grug_core.set_status(player, "alchemy_cave", {
				label = "Cave Draught", duration = effective_duration,
				on_expire = function(target) target:override_day_night_ratio(nil) end,
			})
		end
		grug_traders.start_potion_cooldown(player, grug_alchemy.POTION_COOLDOWN)
		return consume(itemstack)
	end
end

local function elixir_use(definition)
	return function(itemstack, player)
		if not player or not player.is_player or not player:is_player() or
				player:get_hp() <= 0 then return end
		local allowed, required = grug_core.can_use_item_level(player, itemstack)
		if not allowed then
			core.chat_send_player(player:get_player_name(),
				"Requires level " .. required .. ".")
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
		return consume(itemstack)
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
	if player and player.override_day_night_ratio then
		player:override_day_night_ratio(nil)
	end
end

core.register_on_dieplayer(clear_visual)
core.register_on_leaveplayer(clear_visual)
