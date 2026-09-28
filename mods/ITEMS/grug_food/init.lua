-- Food v2 (Round 7, 2026-09-18). Tier numbers and dish effects are data so
-- Round 8 can replace the proposal table without changing consumption code.

grug_food = {}

grug_food.DURATION = 300
grug_food.INTERVAL = 5

grug_food.TIERS = {
	[1] = {instant_hp = 5, min_level = 1, dishes = {
		hearty = {regen = {hp = 4}, modifiers = {}},
		caster = {regen = {hp = 4, mana = 4}, modifiers = {}},
		hunter = {regen = {hp = 4}, modifiers = {}},
	}},
	[2] = {instant_hp = 15, min_level = 11, dishes = {
		hearty = {regen = {hp = 5}, modifiers = {}},
		caster = {regen = {hp = 5, mana = 5}, modifiers = {}},
		hunter = {regen = {hp = 5}, modifiers = {}},
	}},
	[3] = {instant_hp = 40, min_level = 21, dishes = {
		hearty = {regen = {hp = 6}, modifiers = {hp_pool_percent = 2}},
		caster = {regen = {hp = 6, mana = 6},
			modifiers = {mana_pool_percent = 2}},
		hunter = {regen = {hp = 6}, modifiers = {hp_pool_percent = 2}},
	}},
	[4] = {instant_hp = 90, min_level = 31, dishes = {
		hearty = {regen = {hp = 7}, modifiers = {hp_pool_percent = 4}},
		caster = {regen = {hp = 7, mana = 7},
			modifiers = {mana_pool_percent = 4}},
		hunter = {regen = {hp = 7}, modifiers = {hp_pool_percent = 4}},
	}},
	[5] = {instant_hp = 180, min_level = 41, dishes = {
		hearty = {regen = {hp = 8}, modifiers = {hp_pool_percent = 6}},
		caster = {regen = {hp = 8, mana = 8},
			modifiers = {mana_pool_percent = 6}},
		hunter = {regen = {hp = 8}, modifiers = {crit_percent = 1}},
	}},
	[6] = {instant_hp = 300, min_level = 51, dishes = {
		hearty = {regen = {hp = 10}, modifiers = {hp_pool_percent = 8}},
		caster = {regen = {hp = 10, mana = 10},
			modifiers = {mana_pool_percent = 8}},
		hunter = {regen = {hp = 10}, modifiers = {crit_percent = 1}},
	}},
}

grug_food.converted = {}

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
		return {regen = {[role] = 2}, modifiers = {}}
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
			(" every %d s for %g min."):format(grug_food.INTERVAL,
				grug_food.DURATION / 60)
	end
	local bonuses = modifier_parts(effect.modifiers, true)
	if #bonuses > 0 then
		lines[#lines + 1] = "Grants " .. table.concat(bonuses, " and ") ..
			" while active."
	end
	lines[#lines + 1] = "Cannot eat in combat. Regeneration pauses in combat; other bonuses stay."
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
		restore_health_flat(player, tier_def.instant_hp)
	end
	return record
end

function grug_food.eat(itemstack, user, tier, kind, role)
	if not user or not user.is_player or not user:is_player() or
			user:get_hp() <= 0 then
		return itemstack
	end
	if grug_core.in_combat(user) then
		grug_abilities.notify(user, "Cannot eat while in combat.")
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

local held_foods = {}
local hold_feedback = {}

-- Eating feedback (user ruling 2026-09-28, modelled on VoxeLibre mcl_hunger
-- tick_eat_delay/eat_effects): the wielded item hides, the food image sits
-- large at the bottom centre behind every other HUD element and bobs on each
-- input step; crumbs fly from the head every 0.2 s for everyone nearby.
local EAT_STANCE, EAT_STANCE_FACTOR = "grug_food:eating", 0.35
local CRUMB_INTERVAL_US = 200000
local CRUMBS_PER_BURST = 10 -- 5-7 bursts per 1.5 s hold: 50-70 particles

function grug_food.is_food(item_name)
	return held_foods[item_name] ~= nil
end

local function tile_name(tile)
	if type(tile) == "table" then return tile.name or tile.image or "" end
	return type(tile) == "string" and tile or ""
end

-- HUD image and crumb texture: wield image, inventory image, else the node's
-- own tiles (meat blocks register tiles only).
local function food_images(definition)
	local wield = tile_name(definition and definition.wield_image)
	local inventory = tile_name(definition and definition.inventory_image)
	local tiles = definition and definition.tiles or {}
	local top, side = tile_name(tiles[1]), tile_name(tiles[3] or tiles[1])
	local hud = wield ~= "" and wield or inventory
	if hud == "" and top ~= "" then hud = core.inventorycube(top, side, side) end
	local crumb = inventory ~= "" and inventory or (wield ~= "" and wield or side)
	return hud, crumb
end

-- Texture modifiers inside [combine must be escaped (lua_api.md "Escaping").
local function escape_combine(texture)
	return (texture:gsub("\\", "\\\\"):gsub("%^", "\\^"):gsub(":", "\\:"))
end

local function crumb_burst(player, record)
	local pos = player:get_pos()
	if not pos or not record.crumbs then return end
	pos.y = pos.y + 1.5
	local velocity = player:get_velocity() or vector.zero()
	core.add_particlespawner({
		amount = CRUMBS_PER_BURST, time = 0.05,
		pos = pos,
		vel = {min = vector.offset(velocity, -1, 1, -1),
			max = vector.offset(velocity, 1, 2, 1)},
		acc = {min = vector.new(0, -9, 0), max = vector.new(0, -5, 0)},
		exptime = 1, size = {min = 1, max = 2},
		collisiondetection = true, vertical = false,
		texpool = record.crumbs,
	})
end

local function stop_hold_feedback(player)
	local name = player:get_player_name()
	local record = hold_feedback[name]
	if not record then return end
	grug_core.clear_move_stance(player, EAT_STANCE)
	if record.sound_handle then core.sound_stop(record.sound_handle) end
	if record.hud_id then player:hud_remove(record.hud_id) end
	if record.wielditem ~= nil then player:hud_set_flags({wielditem = record.wielditem}) end
	hold_feedback[name] = nil
end

-- A confirmed hold (contextual input, 200 ms after the press) starts eating.
-- In combat it refuses immediately with the existing notice: no visual, no
-- slowdown and no portion. Returns true while eating runs.
function grug_food.begin_hold(player)
	stop_hold_feedback(player)
	local stack = player:get_wielded_item()
	local item_name = stack:get_name()
	if not held_foods[item_name] then return false end
	if grug_core.in_combat(player) then
		grug_abilities.notify(player, "Cannot eat while in combat.")
		return false
	end
	local hud_image, crumb = food_images(core.registered_items[item_name])
	local flags = player:hud_get_flags()
	local record = {started = core.get_us_time(), next_crumbs = 0,
		wielditem = flags and flags.wielditem ~= false}
	player:hud_set_flags({wielditem = false})
	record.sound_handle = core.sound_play({name = "grug_food_eat", gain = 0.5}, {
		to_player = player:get_player_name(), loop = true,
	})
	if hud_image ~= "" then
		record.hud_id = player:hud_add({
			type = "image", position = {x = 0.5, y = 1},
			offset = {x = 0, y = -30}, text = hud_image,
			scale = {x = -25, y = -45}, alignment = {x = 0, y = -1},
			z_index = -200,
		})
	end
	if crumb ~= "" then
		local escaped = escape_combine(crumb)
		record.crumbs = {}
		for index = 0, 7 do
			record.crumbs[#record.crumbs + 1] = "[combine:3x3:" .. -index .. "," ..
				-index .. "=" .. escaped
		end
	end
	hold_feedback[player:get_player_name()] = record
	grug_core.set_move_stance(player, EAT_STANCE, EAT_STANCE_FACTOR)
	grug_food.step_hold(player)
	return true
end

function grug_food.step_hold(player)
	local record = hold_feedback[player:get_player_name()]
	if not record then return end
	local now = core.get_us_time()
	if record.hud_id then
		local t = (now - record.started) / 1e6
		player:hud_change(record.hud_id, "offset",
			{x = 0, y = 50 * math.sin(10 * t + math.random()) - 50})
	end
	if now >= record.next_crumbs then
		record.next_crumbs = now + CRUMB_INTERVAL_US
		crumb_burst(player, record)
	end
end

function grug_food.end_hold(player)
	stop_hold_feedback(player)
end

function grug_food.consume_held(player)
	local stack = player:get_wielded_item()
	local food = held_foods[stack:get_name()]
	if not food then return false end
	local before = stack:get_count()
	stack = grug_food.eat(stack, player, food.tier, food.kind, food.role)
	if stack:get_count() ~= before then player:set_wielded_item(stack) end
	return stack:get_count() ~= before
end

-- A short RMB click (released before the hold threshold) performs, on
-- release, what an ordinary right-click would have done at the thing the
-- press pointed at: the item's own placement/planting (which also runs a
-- pointed node's on_rightclick), or its secondary use followed by the
-- entity's own on_rightclick (`rightclick`, the unwrapped entity callback).
function grug_food.click(player, pointed, rightclick)
	local stack = player:get_wielded_item()
	local food = held_foods[stack:get_name()]
	if not food or not pointed then return false end
	local result
	if pointed.type == "node" then
		local item_name = stack:get_name()
		local before = {}
		for _, key in ipairs({"above", "under"}) do
			before[key] = pointed[key] and core.get_node(pointed[key]).name
		end
		local placed
		result, placed = food.place(stack, player, pointed)
		-- rotate_node returns no position; find the node this click placed.
		for _, key in ipairs({"above", "under"}) do
			local pos = pointed[key]
			if not placed and pos and before[key] ~= item_name and
					core.get_node(pos).name == item_name then
				placed = pos
			end
		end
		-- Builtin plays the place sound to everyone except the placer, whose
		-- client predicts it; a click on release has no prediction.
		local node_def = core.registered_nodes[item_name]
		local sound = node_def and node_def.sounds and node_def.sounds.place
		if placed and sound then
			core.sound_play(sound, {pos = placed, to_player = player:get_player_name()}, true)
		end
	elseif food.secondary then
		result = food.secondary(stack, player, pointed)
	end
	if result ~= nil then
		result = ItemStack(result)
		if player:get_wielded_item():to_string() ~= result:to_string() then
			player:set_wielded_item(result)
		end
	end
	if pointed.type == "object" and rightclick then
		local entity = pointed.ref and pointed.ref:get_luaentity()
		if entity then rightclick(entity, player) end
	end
	return true
end

core.register_on_leaveplayer(function(player)
	hold_feedback[player:get_player_name()] = nil
end)

function grug_food.register_item(item_name, tier, kind, role)
	local definition = core.registered_items[item_name]
	local tier_def = grug_food.TIERS[tier]
	local effect = grug_food.effect_for(tier, kind, role)
	if not definition or not tier_def or not effect then
		return false
	end
	-- The item's own placement/planting and secondary use, run by a click.
	held_foods[item_name] = {tier = tier, kind = kind, role = role,
		place = definition.on_place or core.item_place,
		secondary = definition.on_secondary_use}
	local groups = copied_groups(definition.groups)
	groups.grug_food = 1
	groups.grug_food_tier = tier
	groups["grug_food_" .. kind] = 1
	groups["grug_food_role_" .. role] = 1
	core.override_item(item_name, {
		description = tostring(definition.description or item_name) .. "\n" ..
			tooltip_for(tier, effect) .. "\nHold RMB for 1.5 s to eat one portion.",
		groups = groups,
		_grug_ilvl = tier_def.min_level,
		_grug_tier = tier,
		-- Food is a deliberate 1.5-second RMB hold, owned by contextual input.
		on_use = false,
		-- A click places on RELEASE, so the client must not predict a node on
		-- press (game.cpp nodePlacement) or on the engine's repeated place.
		node_placement_prediction = "",
		-- Native RMB calls only report the press to contextual input; it
		-- settles click versus hold and never lets a repeat place or interact.
		on_place = function(stack, player, pointed)
			if player and grug_abilities.input and
					grug_abilities.input.food_native(player, pointed) then
				-- A due held portion may already have changed the wield stack.
				return player:get_wielded_item()
			end
			return held_foods[item_name].place(stack, player, pointed) or stack
		end,
		on_secondary_use = function(stack, player, pointed)
			if player and grug_abilities.input and
					grug_abilities.input.food_native(player, pointed) then
				return player:get_wielded_item()
			end
			local secondary = held_foods[item_name].secondary
			return secondary and secondary(stack, player, pointed) or stack
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
	{"mobs:meat", 1, "dish", "hearty"},
	{"mobs:meatblock_raw", 1, "raw", "hp"},
	{"mobs:meatblock", 1, "dish", "hearty"},
	{"grug_mobs:raw_fish", 1, "raw", "hp"},
	{"grug_fishing:silver_trout", 2, "raw", "hp"},
	{"grug_fishing:mire_carp", 3, "raw", "hp"},
	{"grug_fishing:frostfin", 4, "raw", "hp"},
	{"grug_fishing:ember_eel", 5, "raw", "hp"},
	{"grug_fishing:storm_tuna", 6, "raw", "hp"},
	{"grug_fishing:cooked_fish", 1, "dish", "hearty"},
}

for index = 1, #CURRENT_FOODS do
	local row = CURRENT_FOODS[index]
	assert(grug_food.register_item(row[1], row[2], row[3], row[4]),
		"grug_food: missing current food " .. row[1])
end

grug_food.RAW_GATHERING_TIERS = {
	corn = 1,
	melon = 1,
	mushroom = 3,
	potato = 1,
	wild_cocoa = 6,
}

local gathering = grug_gathering.p9g_sources()
for index = 1, #gathering do
	local row = gathering[index]
	local tier = grug_food.RAW_GATHERING_TIERS[row.key]
	if tier then
		assert(grug_food.register_item(row.raw_item, tier, "raw", "hp"),
			"grug_food: missing gathering food " .. row.raw_item)
	end
end
