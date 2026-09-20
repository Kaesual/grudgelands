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

-- Luanti handles an object right-click by invoking the wielded item's
-- on_secondary_use first and the object's on_rightclick second
-- (serverpackethandler.cpp). Let interactive entities own that click so a
-- trainer/NPC cannot both open its UI and activate the held mount.
local function use_mount_secondary(itemstack, user, pointed_thing)
	if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
		local entity = pointed_thing.ref:get_luaentity()
		if entity and type(entity.on_rightclick) == "function" then
			return itemstack
		end
	end
	return use_mount(itemstack, user)
end

local function refuse_drop(itemstack, dropper)
	if dropper and dropper:is_player() then
		core.chat_send_player(dropper:get_player_name(),
			"Owner-bound mounts cannot be dropped.")
	end
	return itemstack
end

local function mount_stack(stack)
	return stack and core.get_item_group(stack:get_name(), "grug_mount") > 0
end

-- A take is the outbound half of a player-to-external inventory transfer.
-- Puts remain allowed so owner-bound stacks stranded by an interrupted move
-- can be recovered; the post-action reconciliation removes stale duplicates.
core.register_allow_player_inventory_action(function(_, action, _, info)
	if action == "take" and mount_stack(info.stack) then return 0 end
end)

core.register_on_player_inventory_action(function(player, action, _, info)
	if action == "put" and mount_stack(info.stack) then
		grug_mounts.reconcile_items(player)
	end
end)

for tier_id = 1, 4 do
	local tier = grug_mounts.TIERS[tier_id]
	core.register_craftitem(tier.item, {
		description = tier.name,
		inventory_image = ({"grug_mounts_icon_t1_accord.png",
			"grug_mounts_icon_human.png", "grug_mounts_icon_expert_accord.png",
			"grug_mounts_icon_master_accord.png"})[tier_id],
		stack_max = 1,
		groups = {grug_mount = tier_id, not_in_creative_inventory = 1},
		_grug_mount_tier = tier_id,
		on_use = use_mount,
		on_secondary_use = use_mount_secondary,
		on_drop = refuse_drop,
	})
end
