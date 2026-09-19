local META_LAND = "grug_mounts:land_tier"
local META_FLIGHT = "grug_mounts:flight_tier"

local item_mode = {}
for _, tier in pairs(grug_mounts.TIERS) do
	item_mode[tier.item] = tier.mode
end

local function meta_key(mode)
	return mode == "land" and META_LAND or META_FLIGHT
end

function grug_mounts.highest_owned(player, mode)
	if not player or not player.is_player or not player:is_player() then return 0 end
	return player:get_meta():get_int(meta_key(mode))
end

function grug_mounts.owns_tier(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	return tier ~= nil and grug_mounts.highest_owned(player, tier.mode) >= tier_id
end

local function stack_for(player, tier_id)
	local tier = assert(grug_mounts.TIERS[tier_id])
	local stack = ItemStack(tier.item)
	local model = grug_mounts.model_for(player, tier_id)
	if model then
		local meta = stack:get_meta()
		meta:set_string("grug_mounts:owner", player:get_player_name())
		meta:set_string("description", model.description .. "\n" .. tier.name ..
			(" — %d nodes/s"):format(tier.speed))
		meta:set_string("inventory_image", model.icon)
	end
	return stack
end

grug_mounts.stack_for = stack_for

local function sorted_lists(inventory)
	local names = {}
	for name in pairs(inventory:get_lists()) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		if names[index] == "main" then
			table.remove(names, index)
			table.insert(names, 1, "main")
			break
		end
	end
	return names
end

local function mode_slots(inventory, mode)
	local result = {}
	for _, listname in ipairs(sorted_lists(inventory)) do
		local size = inventory:get_size(listname)
		for index = 1, size do
			local stack = inventory:get_stack(listname, index)
			if item_mode[stack:get_name()] == mode then
				result[#result + 1] = {listname = listname, index = index}
			end
		end
	end
	return result
end

local function can_represent(player, mode, tier_id)
	local inventory = player:get_inventory()
	local slots = mode_slots(inventory, mode)
	if #slots > 0 then return true end
	return inventory:room_for_item("main", stack_for(player, tier_id))
end

local function sync_mode(player, mode)
	local tier_id = grug_mounts.highest_owned(player, mode)
	if tier_id == 0 then return true end
	local tier = grug_mounts.TIERS[tier_id]
	if not tier or tier.mode ~= mode then return false end
	local inventory = player:get_inventory()
	local slots = mode_slots(inventory, mode)
	local wanted = stack_for(player, tier_id)
	if #slots == 0 then
		if not inventory:room_for_item("main", wanted) then return false end
		inventory:add_item("main", wanted)
		return true
	end
	inventory:set_stack(slots[1].listname, slots[1].index, wanted)
	for index = 2, #slots do
		inventory:set_stack(slots[index].listname, slots[index].index, ItemStack(""))
	end
	return true
end

function grug_mounts.reconcile_items(player)
	return sync_mode(player, "land") and sync_mode(player, "flight")
end

local function prerequisite_met(player, tier_id)
	if tier_id == 1 then
		return grug_mounts.highest_owned(player, "land") == 0
	elseif tier_id == 2 then
		return grug_mounts.highest_owned(player, "land") == 1
	elseif tier_id == 3 then
		return grug_mounts.highest_owned(player, "land") >= 2 and
			grug_mounts.highest_owned(player, "flight") == 0
	elseif tier_id == 4 then
		return grug_mounts.highest_owned(player, "flight") == 3
	end
	return false
end

function grug_mounts.purchase(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if not tier then return false, "Unknown riding tier." end
	if grug_xp.get_level(player) < tier.level then
		return false, ("Requires level %d."):format(tier.level)
	end
	if not prerequisite_met(player, tier_id) then
		if grug_mounts.owns_tier(player, tier_id) then
			return false, "You already own this riding tier."
		end
		return false, "Buy the preceding riding tier first."
	end
	if not grug_mounts.model_for(player, tier_id) then
		return false, "Choose a faction and race before buying a mount."
	end
	local price = grug_mounts.price_for_tier(tier_id)
	if not price then
		return false, "This tier is awaiting its measured trainer price."
	end
	if not can_represent(player, tier.mode, tier_id) then
		return false, "Make room in your main inventory first."
	end
	if not grug_money.take(player, price) then
		return false, "You do not have enough money."
	end
	player:get_meta():set_int(meta_key(tier.mode), tier_id)
	assert(sync_mode(player, tier.mode), "validated mount-item swap failed")
	return true, tier.name .. " learned."
end

core.register_on_joinplayer(function(player)
	core.after(0, function(name)
		local current = core.get_player_by_name(name)
		if current then grug_mounts.reconcile_items(current) end
	end, player:get_player_name())
end)

grug_classes.register_on_race_chosen(function(player)
	grug_mounts.reconcile_items(player)
end)

grug_factions.register_on_faction_chosen(function(player)
	grug_mounts.reconcile_items(player)
end)
