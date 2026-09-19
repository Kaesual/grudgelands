local function use_mount(itemstack, user)
	if not user or not user.is_player or not user:is_player() then return itemstack end
	local definition = core.registered_items[itemstack:get_name()]
	local tier_id = definition and definition._grug_mount_tier
	local bound_owner = itemstack:get_meta():get_string("grug_mounts:owner")
	if bound_owner ~= user:get_player_name() or not tier_id or
			not grug_mounts.owns_tier(user, tier_id) then
		core.chat_send_player(user:get_player_name(),
			"That mount is not bound to this character.")
		return itemstack
	end
	grug_mounts.toggle(user, tier_id)
	return itemstack
end

local function refuse_drop(itemstack, dropper)
	if dropper and dropper:is_player() then
		core.chat_send_player(dropper:get_player_name(),
			"Owner-bound mounts cannot be dropped.")
	end
	return itemstack
end

for tier_id = 1, 4 do
	local tier = grug_mounts.TIERS[tier_id]
	core.register_craftitem(tier.item, {
		description = tier.name,
		inventory_image = tier.mode == "land" and "grug_mounts_horse_brown.png" or
			"grug_mobs_eagle.png",
		stack_max = 1,
		groups = {grug_mount = tier_id, not_in_creative_inventory = 1},
		_grug_mount_tier = tier_id,
		on_use = use_mount,
		on_secondary_use = use_mount,
		on_drop = refuse_drop,
	})
end
