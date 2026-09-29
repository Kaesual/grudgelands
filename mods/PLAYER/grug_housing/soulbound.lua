-- Soulbound items (ruling 8): an item of group `grug_soulbound` lives only in
-- its holder's main inventory. It follows grug_skills/bound_items.lua (the
-- same three seams: player inventory actions, node inventories, detached
-- inventories) but with a stricter rule: skill and mount items may sit in
-- bags and need an entitlement, a soulbound item may sit nowhere but "main".
-- Chests, furnaces and stations, bags, the craft grid, equipment slots and
-- every detached inventory (trash, catalogues, workspaces) refuse it. Trades
-- never offer it (it has no sell price) and there is no mail. Death keeps the
-- whole inventory in this game, so the stone stays; dropping destroys it
-- (the item's on_drop, stone.lua).

local function soulbound(stack)
	return stack ~= nil and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_soulbound") > 0
end
grug_housing.is_soulbound = soulbound

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" then
		if info.to_list ~= "main" and
				soulbound(inventory:get_stack(info.from_list, info.from_index)) then
			return 0
		end
	elseif action == "put" then
		if soulbound(info.stack) and info.listname ~= "main" then return 0 end
	end
end)

local function wrap_node(name, def)
	if def._grug_soulbound_guard then return end
	local old_put, old_move = def.allow_metadata_inventory_put,
		def.allow_metadata_inventory_move
	core.override_item(name, {
		_grug_soulbound_guard = true,
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if soulbound(stack) then return 0 end
			if old_put then return old_put(pos, listname, index, stack, player) end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from_list, from_index,
				to_list, to_index, count, player)
			local stack = core.get_meta(pos):get_inventory():get_stack(from_list,
				from_index)
			if soulbound(stack) then return 0 end
			if old_move then
				return old_move(pos, from_list, from_index, to_list, to_index, count,
					player)
			end
			return count
		end,
	})
end

local function wrap_detached(callbacks)
	if callbacks._grug_soulbound_guard then return callbacks end
	local old_put, old_move = callbacks.allow_put, callbacks.allow_move
	callbacks.allow_put = function(inv, listname, index, stack, player)
		if soulbound(stack) then return 0 end
		if old_put then return old_put(inv, listname, index, stack, player) end
		return stack:get_count()
	end
	callbacks.allow_move = function(inv, from_list, from_index, to_list, to_index,
			count, player)
		if soulbound(inv:get_stack(from_list, from_index)) then return 0 end
		if old_move then
			return old_move(inv, from_list, from_index, to_list, to_index, count,
				player)
		end
		return count
	end
	callbacks._grug_soulbound_guard = true
	return callbacks
end

-- Detached inventories created from now on are wrapped at creation; those
-- created before this file ran are wrapped once every mod has loaded.
local create_detached = core.create_detached_inventory
function core.create_detached_inventory(name, callbacks, player_name)
	local copy = {}
	for key, value in pairs(callbacks or {}) do copy[key] = value end
	return create_detached(name, wrap_detached(copy), player_name)
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do wrap_node(name, def) end
	for _, callbacks in pairs(core.detached_inventories or {}) do
		wrap_detached(callbacks)
	end
end)
