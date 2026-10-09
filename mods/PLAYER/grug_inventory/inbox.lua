-- The shift-click inbox (Round 45 playtest PT5): shift-click from another
-- inventory (a chest, a furnace, a station, the creative inventory, the
-- crafting output area, the operation box) reaches `main` AND the bags.
--
-- Why a list of its own: a listring sends a shift-click into exactly ONE
-- list, and when that list is a full `main` the engine gives up before any
-- Lua callback runs (inventorymanager.cpp IMoveAction::apply, itemFits), so
-- the server could never route it on. The inbox is a one-slot player list
-- that no page draws and that is always empty, so the engine always asks its
-- allow callback, which accepts exactly what the give helper can place
-- (main[9..], the bags, the hotbar last; arrows into a Scout's quiver
-- first). The engine moves that many (an infinite source keeps its stack, the
-- source's own take callbacks run), and the on callback hands them out
-- through grug_inventory.give and empties the slot. Nothing fits: nothing
-- moves and a "No room" line says so.
--
-- The rings: every page with another inventory rings each of its lists as
-- [other list, inbox, main]; the first `main` decides where a shift-click
-- from `main` goes, as before. The Character page's own routing list
-- (equipment.lua SHIFT_LIST) is a different job and stays separate.
--
-- Bound skills, mounts and soulbound items never pass the inbox: the first
-- number an allow callback returns decides, and this one may run before their
-- guards (grug_skills/bound_items.lua, grug_housing/soulbound.lua). No ringed
-- source holds them anyway.
--
grug_inventory.INBOX_LIST = "grug_inbox"
local INBOX = grug_inventory.INBOX_LIST

local function carried_list(list)
	return list == "main" or list:match("^grug_bag%d_content$") ~= nil
end

local function guarded(stack)
	local name = stack:get_name()
	return core.get_item_group(name, "grug_bound_skill") > 0 or
		core.get_item_group(name, "grug_soulbound") > 0
end

-- Hand the inbox's content out: the give order, then the player's feet. The
-- allow callback admitted only what fits, so a leftover needs a callback that
-- filled the inventory in the same step; it is never lost.
local function empty_inbox(player, inventory)
	local stack = inventory:get_stack(INBOX, 1)
	if stack:is_empty() then return end
	inventory:set_stack(INBOX, 1, ItemStack(""))
	local leftover = grug_inventory.give(player, stack)
	if not leftover:is_empty() then
		core.log("warning", "[grug_inventory] inbox of " .. player:get_player_name() ..
			" did not fit; dropped at the player")
		core.add_item(player:get_pos(), leftover)
	end
end

-- Join: the list exists; a stray stack (a write that is not ours) goes out.
core.register_on_joinplayer(function(player)
	local inventory = player:get_inventory()
	inventory:set_size(INBOX, 1)
	empty_inbox(player, inventory)
end)

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	local stack
	if action == "move" then
		if info.from_list == INBOX then return 0 end
		if info.to_list ~= INBOX then return nil end
		-- A ring never sends the carried lists here; nothing to route.
		if carried_list(info.from_list) then return 0 end
		stack = inventory:get_stack(info.from_list, info.from_index)
		stack:set_count(math.min(info.count, stack:get_count()))
	elseif action == "put" then
		if info.listname ~= INBOX then return nil end
		stack = ItemStack(info.stack)
	else
		return info.listname == INBOX and 0 or nil
	end
	if stack:is_empty() or guarded(stack) then return 0 end
	local room = grug_inventory.room_for(player, stack)
	if room <= 0 then
		grug_core.feed(player, "notice", "No room in your inventory.", "inbox_room")
	end
	return room
end)

core.register_on_player_inventory_action(function(player, action, inventory, info)
	if (action == "put" and info.listname == INBOX) or
			(action == "move" and info.to_list == INBOX) then
		empty_inbox(player, inventory)
	end
end)
