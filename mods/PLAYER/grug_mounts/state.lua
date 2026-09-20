local META_LAND = "grug_mounts:land_tier"
local META_FLIGHT = "grug_mounts:flight_tier"
local owned_changed = {}

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

function grug_mounts.owned_tier_ids(player)
	local ids = {}
	for tier_id = 1, 4 do
		if grug_mounts.owns_tier(player, tier_id) then ids[#ids + 1] = tier_id end
	end
	return ids
end

function grug_mounts.stack_for(player, tier_id)
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

function grug_mounts.register_on_owned_tiers_changed(func)
	owned_changed[#owned_changed + 1] = func
end

local function allowed_storage(listname)
	if listname == "main" then return true end
	for i = 1, grug_inventory.BAG_COUNT do
		if listname == grug_inventory.content_list(i) then return true end
	end
	return false
end

function grug_mounts.reconcile_items(player)
	local inv, have = player:get_inventory(), {}
	for listname, list in pairs(inv:get_lists()) do
		for index, stack in ipairs(list) do
			local def = core.registered_items[stack:get_name()]
			local tier_id = def and def._grug_mount_tier
			if tier_id then
				local owner = stack:get_meta():get_string("grug_mounts:owner")
				if not allowed_storage(listname) or owner ~= player:get_player_name() or
						not grug_mounts.owns_tier(player, tier_id) or have[tier_id] then
					inv:set_stack(listname, index, ItemStack(""))
				else
					have[tier_id] = true
					inv:set_stack(listname, index, grug_mounts.stack_for(player, tier_id))
				end
			end
		end
	end
	return true
end

local function prerequisite_met(player, tier_id)
	if tier_id == 1 then return grug_mounts.highest_owned(player, "land") == 0 end
	if tier_id == 2 then return grug_mounts.highest_owned(player, "land") == 1 end
	if tier_id == 3 then return grug_mounts.highest_owned(player, "land") >= 2 and grug_mounts.highest_owned(player, "flight") == 0 end
	if tier_id == 4 then return grug_mounts.highest_owned(player, "flight") == 3 end
	return false
end

function grug_mounts.purchase(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if not tier then return false, "Unknown riding tier." end
	if grug_xp.get_level(player) < tier.level then return false, ("Requires level %d."):format(tier.level) end
	if not prerequisite_met(player, tier_id) then
		if grug_mounts.owns_tier(player, tier_id) then return false, "You already own this riding tier." end
		return false, "Buy the preceding riding tier first."
	end
	if not grug_mounts.model_for(player, tier_id) then return false, "Choose a faction and race before buying a mount." end
	local price = grug_mounts.price_for_tier(tier_id)
	if not price then return false, "This tier is awaiting its measured trainer price." end
	if not grug_money.take(player, price) then return false, "You do not have enough money." end
	player:get_meta():set_int(meta_key(tier.mode), tier_id)
	for _, func in ipairs(owned_changed) do func(player) end
	return true, tier.name .. " learned. Open Inventory > Skills to use it."
end

core.register_on_joinplayer(function(player)
	core.after(0, function(name)
		local current = core.get_player_by_name(name)
		if current then grug_mounts.reconcile_items(current) end
	end, player:get_player_name())
end)
grug_classes.register_on_race_chosen(grug_mounts.reconcile_items)
grug_factions.register_on_faction_chosen(grug_mounts.reconcile_items)
