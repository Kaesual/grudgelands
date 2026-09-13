-- Saved-world cleanup for the retired natural-ore respawn placeholder.
--
-- world.md R4 says that natural resources never regenerate. Older worlds may
-- still contain this node, with an active timer and arbitrary legacy metadata,
-- so keep the registration long enough to remove those exact placeholders.

local DEPLETED = "grug_nodes:depleted_vein"

local function remove_depleted(pos)
	if core.get_node(pos).name == DEPLETED then
		core.remove_node(pos)
	end
	return false
end

core.register_node(DEPLETED, {
	description = "Depleted Vein (Legacy)",
	is_ground_content = false,
	tiles = {"default_stone.png^grug_nodes_depleted_vein.png"},
	groups = {cracky = 3, grug_depleted = 1,
		not_in_creative_inventory = 1},
	drop = "",
	sounds = default.node_sound_stone_defaults(),
	on_timer = remove_depleted,
})

core.register_lbm({
	name = "grug_nodes:remove_legacy_depleted_vein",
	nodenames = {DEPLETED},
	run_at_every_load = false,
	action = remove_depleted,
})
