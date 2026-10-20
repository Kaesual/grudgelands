-- Right-click picking (0.53.1 ruling 10): a blueberry bush with berries and
-- an apple are picked with right-click as well as dug with left-click.
-- Herbs, spices and wood stay left-click only.
--
-- A pick IS a dig: core.node_dig is the one dig path the node's own on_dig
-- reaches (grug_materials' wrapper over the builtin), so a pick checks
-- diggability and protection (with the protection hint) exactly as a dig
-- does, puts the same drops into the inventory, wears the wielded item as a
-- dig with it would, and runs after_dig_node (the bush stays as leaves with
-- its regrowth timer, a natural apple leaves its regrowth mark) and the
-- on_dignode callbacks. It skips only the left-click input gate in front of
-- on_dig (grug_abilities/input.lua), which decides whether a left-click on a
-- node is a dig or a cast; a right-click on a node with on_rightclick is an
-- interaction there, so no skill casts on the press.
local PICKABLE = {
	"default:apple",
	"default:blueberry_bush_leaves_with_berries",
}

local function pick(pos, node, clicker, itemstack)
	if not (clicker and clicker.is_player and clicker:is_player()) then
		return itemstack
	end
	core.node_dig(pos, node, clicker)
	-- An empty hand's drop may land in the wielded slot: hand back what is
	-- wielded now, never the stack from before the pick.
	return clicker:get_wielded_item()
end

for _, name in ipairs(PICKABLE) do
	core.override_item(name, {on_rightclick = pick})
end
