-- Food restoration (R9, 2026-09-17). This wrapper mod owns the behavior so
-- vendored/default registrations and the gathering catalog stay untouched.

grug_food = {}

grug_food.DURATION = 180
grug_food.INTERVAL = 10
grug_food.QUALITY = {
	raw = {percent = 2, label = "Raw"},
	cooked = {percent = 5, label = "Simply cooked"},
	well_cooked = {percent = 10, label = "Well cooked"},
}

grug_food.converted = {}

function grug_food.tick_amount(maximum, percent)
	maximum = math.max(0, tonumber(maximum) or 0)
	percent = math.max(0, tonumber(percent) or 0)
	return math.max(1, math.floor(maximum * percent / 100))
end

local function restore_health(player, percent)
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

local function restore_mana(player, percent)
	local maximum = grug_classes.get_max_mana(player)
	if maximum <= 0 then
		return 0
	end
	return grug_abilities.restore_mana(player,
		grug_food.tick_amount(maximum, percent))
end

local function start_food_status(player, resource, percent)
	grug_core.set_status(player, "food", {
		label = resource == "mana" and "Mana Food" or "Food",
		duration = grug_food.DURATION,
		kind = "buff",
		interval = grug_food.INTERVAL,
		on_tick = function(target)
			if grug_core.in_combat(target) then
				return
			end
			if resource == "mana" then
				restore_mana(target, percent)
			else
				restore_health(target, percent)
			end
		end,
	})
end

function grug_food.eat(itemstack, user, resource, quality)
	if not user or not user.is_player or not user:is_player() or
			user:get_hp() <= 0 then
		return itemstack
	end
	local quality_def = grug_food.QUALITY[quality]
	if not quality_def then
		return itemstack
	end
	if resource == "mana" then
		if grug_classes.get_max_mana(user) <= 0 then
			core.chat_send_player(user:get_player_name(),
				"Mana food has no effect without a mana pool.")
			return itemstack
		end
	elseif resource ~= "hp" then
		return itemstack
	end
	start_food_status(user, resource, quality_def.percent)
	itemstack:take_item(1)
	return itemstack
end

local function copied_groups(groups)
	local copy = {}
	for key, value in pairs(groups or {}) do
		copy[key] = value
	end
	return copy
end

function grug_food.register_item(item_name, resource, quality)
	local definition = core.registered_items[item_name]
	local quality_def = grug_food.QUALITY[quality]
	if not definition or (resource ~= "hp" and resource ~= "mana") or
			not quality_def then
		return false
	end
	local groups = copied_groups(definition.groups)
	groups.grug_food = 1
	groups.grug_food_quality = quality_def.percent
	groups[resource == "mana" and "grug_food_mana" or "grug_food_hp"] = 1
	local pool = resource == "mana" and "mana" or "HP"
	local tooltip = ("Restores %d %% %s every %d s for 3 min while out of combat.")
		:format(quality_def.percent, pool, grug_food.INTERVAL)
	core.override_item(item_name, {
		description = tostring(definition.description or item_name) .. "\n" .. tooltip,
		groups = groups,
		on_use = function(itemstack, user)
			return grug_food.eat(itemstack, user, resource, quality)
		end,
	})
	grug_food.converted[#grug_food.converted + 1] = {
		name = item_name,
		resource = resource,
		quality = quality,
		percent = quality_def.percent,
	}
	return true
end

local CURRENT_FOODS = {
	{"default:apple", "raw"},
	{"default:blueberries", "raw"},
	{"mobs:meat_raw", "raw"},
	{"mobs:meat", "cooked"},
	{"mobs:meatblock_raw", "raw"},
	{"mobs:meatblock", "cooked"},
	{"grug_mobs:raw_fish", "raw"},
	{"grug_fishing:cooked_fish", "cooked"},
}

for index = 1, #CURRENT_FOODS do
	local row = CURRENT_FOODS[index]
	assert(grug_food.register_item(row[1], "hp", row[2]),
		"grug_food: missing current food " .. row[1])
end

local gathering = grug_gathering.p9g_sources()
for index = 1, #gathering do
	local row = gathering[index]
	if row.harvest_kind == "food" or row.harvest_kind == "found_only_food" then
		local resource = row.raw_item == "grug_gathering:wild_cocoa"
			and "mana" or "hp"
		assert(grug_food.register_item(row.raw_item, resource, "raw"),
			"grug_food: missing gathering food " .. row.raw_item)
	end
end
