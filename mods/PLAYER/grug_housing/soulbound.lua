-- Soulbound items (ruling 8): an item of group `grug_soulbound` lives only in
-- its holder's carried inventory: the lists the give helper fills with
-- ordinary items, `main` (the hotbar included) and every bag's content list
-- (Round 49 ruling 3; `main` only before). Like grug_skills/bound_items.lua
-- it is a rule of grug_inventory's bound-item seam (bound.lua: player
-- inventory actions, node inventories, detached inventories). Chests,
-- furnaces and stations, the bag slots, the craft grid, equipment slots, the
-- quiver, the potion belt and every detached inventory (trash, catalogues,
-- workspaces) refuse it. Trades never offer it (it has no sell price) and it
-- cannot be mailed: a letter's attachments come only from the player list
-- grug_mail_out (grug_mail, Round 48), which the move and put rules below
-- refuse like every list that is not carried. Death keeps the whole
-- inventory in this game, so the stone stays; dropping destroys it (the
-- item's on_drop, stone.lua). The packed containers of a map reset (Round
-- 50, packed.lua) are soulbound too; dropping one is refused.

local function soulbound(stack)
	return stack ~= nil and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_soulbound") > 0
end

-- `main`, a bag's content list (grug_inventory.content_list) or the
-- inactive hotbar layout (grug_inventory.HOTBAR_STORE; Round 50 D3: a switch
-- carries the stone there, and grug_inventory's guard keeps every inventory
-- action out of it).
local function carried_list(list)
	return list == "main" or list:match("^grug_bag%d_content$") ~= nil or
		list == "grug_hotbar_store"
end

-- The player inventory's own actions: a soulbound stack moves or is put only
-- into a carried list. Node and detached inventories refuse it through
-- grug_inventory's bound-item seam (grug_inventory/bound.lua), a move inside
-- a detached inventory included. This mod does not depend on grug_inventory
-- (nothing promises it loads first), so the rule registers once every mod has loaded,
-- before any player can act.
local function player_action(player, action, inventory, info)
	if action == "move" then
		if not carried_list(info.to_list) and
				soulbound(inventory:get_stack(info.from_list, info.from_index)) then
			return 0
		end
	elseif action == "put" then
		if soulbound(info.stack) and not carried_list(info.listname) then return 0 end
	end
end

core.register_on_mods_loaded(function()
	grug_inventory.register_bound_rule({group = "grug_soulbound",
		player_action = player_action, detached_move = true})
end)
