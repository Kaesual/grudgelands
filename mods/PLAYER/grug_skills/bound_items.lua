local function bound(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_bound_skill") > 0
end

local function owned_list(listname)
	if listname == "main" then return true end
	for i = 1, grug_inventory.BAG_COUNT do
		if listname == grug_inventory.content_list(i) then return true end
	end
	return false
end

local function entitled(player, stack)
	local name = stack:get_name()
	local id = name:match("^grug_abilities:(.+)$")
	if id then return grug_abilities.is_unlocked(player, id) end
	local def = core.registered_items[name]
	local tier = def and def._grug_mount_tier
	return tier and grug_mounts.owns_tier(player, tier) and
		stack:get_meta():get_string("grug_mounts:owner") == player:get_player_name()
end

grug_skills.is_entitled = entitled

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if bound(stack) and (not owned_list(info.from_list) or
				not owned_list(info.to_list) or not entitled(player, stack)) then return 0 end
	elseif action == "put" and bound(info.stack) then
		if inventory ~= player:get_inventory() or not owned_list(info.listname) or
				not entitled(player, info.stack) then return 0 end
	end
end)

local function wrap_node(name, def)
	if def._grug_bound_guard then return end
	local old_put, old_move = def.allow_metadata_inventory_put,
		def.allow_metadata_inventory_move
	core.override_item(name, {
		_grug_bound_guard = true,
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if bound(stack) then return 0 end
			if old_put then return old_put(pos, listname, index, stack, player) end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			local stack = core.get_meta(pos):get_inventory():get_stack(from_list, from_index)
			if bound(stack) then return 0 end
			if old_move then return old_move(pos, from_list, from_index, to_list, to_index, count, player) end
			return count
		end,
	})
end

local function wrap_detached(name, callbacks)
	if name:match("^grug_skills_") or callbacks._grug_bound_guard then return end
	local old_put = callbacks.allow_put
	callbacks.allow_put = function(inv, listname, index, stack, player)
		if bound(stack) then return 0 end
		if old_put then return old_put(inv, listname, index, stack, player) end
		return stack:get_count()
	end
	callbacks._grug_bound_guard = true
end

function grug_skills.guard_destinations()
	for name, def in pairs(core.registered_nodes) do wrap_node(name, def) end
	for name, callbacks in pairs(core.detached_inventories or {}) do
		wrap_detached(name, callbacks)
	end
end
core.register_on_mods_loaded(grug_skills.guard_destinations)
core.register_on_joinplayer(function() grug_skills.guard_destinations() end)
