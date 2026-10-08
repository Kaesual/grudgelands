-- The retired mount items (Round 44, ui-crafting-rework-plan.md ruling 9):
-- mounts and boats live in the quickbar (E, grug_quickbar), which works from
-- the purchase record (state.lua). Nothing hands these items out any more and
-- they do nothing when used; they stay registered so stacks an older version
-- handed out remain valid items until the 0.44.0 migration step removes them
-- offline. They keep the bound-skill group, so grug_skills keeps them out of
-- chests and other foreign inventories, and a drop still deletes them rather
-- than leaving them in the world.
local function delete_drop()
	return ItemStack("")
end

for tier_id = 1, #grug_mounts.TIERS do
	local tier = grug_mounts.TIERS[tier_id]
	core.register_craftitem(tier.item, {
		description = tier.name .. "\n" .. grug_mounts.QUICKBAR_TIP,
		inventory_image = tier.icon,
		stack_max = 1,
		groups = {grug_mount = tier_id, grug_bound_skill = 1, not_in_creative_inventory = 1},
		_grug_mount_tier = tier_id,
		on_drop = delete_drop,
	})
end
