-- A right-click on a node reaches only the wielded item's on_place (the
-- engine's INTERACT_PLACE); builtin core.item_place forwards it to the
-- pointed node's on_rightclick, but an item with its own on_place (seeds,
-- buckets, the fishing rod) must do that itself (Round 37, ITM-03). Called
-- first in such an on_place: unless the player sneaks, a node with an
-- on_rightclick (doors, chests, stations, regrowing crops) takes the click,
-- and the result is the stack to return; nil means the item's own use runs.
function grug_core.node_rightclick(itemstack, placer, pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" or not placer or
			not placer.get_player_control then
		return nil
	end
	local control = placer:get_player_control()
	if control and control.sneak then return nil end
	local pos = pointed_thing.under
	local node = pos and core.get_node_or_nil(pos)
	local definition = node and core.registered_nodes[node.name]
	if not definition or not definition.on_rightclick then return nil end
	return definition.on_rightclick(pos, node, placer, itemstack, pointed_thing) or
		itemstack
end
