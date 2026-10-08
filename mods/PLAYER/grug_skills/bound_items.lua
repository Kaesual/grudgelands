local function bound(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_bound_skill") > 0
end

-- Skills (ability representations) live on the hotbar only (Round 44, spec
-- ui-crafting-rework-plan.md ruling 8): main[1..8]. Mount items keep the
-- older rule, `main` and the owned bag contents, until lane QB retires them.
local function ability(stack)
	return core.get_item_group(stack:get_name(), "grug_ability") > 0
end

local function hotbar_slot(listname, index)
	return listname == "main" and index >= 1 and index <= grug_inventory.HOTBAR_SIZE
end

local function owned_list(listname)
	if listname == "main" then return true end
	for i = 1, grug_inventory.BAG_COUNT do
		if listname == grug_inventory.content_list(i) then return true end
	end
	return false
end

local function owns_inventory(player, inventory)
	local location = inventory and inventory:get_location()
	return location and location.type == "player" and
		location.name == player:get_player_name()
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

-- Whether the player carries `itemname` in main, craft or an owned bag.
local function carried(inv, itemname)
	for _, listname in ipairs({"main", "craft"}) do
		if inv:contains_item(listname, itemname) then return true end
	end
	for i = 1, grug_inventory.BAG_COUNT do
		if inv:contains_item(grug_inventory.content_list(i), itemname) then return true end
	end
	return false
end

-- Moves inside the inventory: a skill only onto the hotbar (a stray skill in
-- main[9..] or a bag may still go there); the engine asks again with the two
-- sides swapped for a swap, so a swap that would push a skill off the hotbar
-- is refused too. Puts from another inventory (the catalog is the only one
-- holding skills) land a skill on a free hotbar slot, and only one copy: the
-- catalog's own entitlement check no longer looks at what the player carries.
-- A put onto a slot already holding the same skill is the catalog's swap
-- check for "drag it back to remove it" (page.lua): the catalog is an
-- infinite destination, so the engine undoes the swap and the dragged copy
-- is gone.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if not bound(stack) then return end
		if not owned_list(info.from_list) or not entitled(player, stack) then return 0 end
		if ability(stack) then
			if not hotbar_slot(info.to_list, info.to_index) then return 0 end
		elseif not owned_list(info.to_list) then
			return 0
		end
	elseif action == "put" and bound(info.stack) then
		if not owns_inventory(player, inventory) or not entitled(player, info.stack) then
			return 0
		end
		if ability(info.stack) then
			local name = info.stack:get_name()
			if inventory:get_stack(info.listname, info.index):get_name() == name then return end
			if not hotbar_slot(info.listname, info.index) or
					carried(inventory, name) then return 0 end
		elseif not owned_list(info.listname) then
			return 0
		end
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

-- Detached inventories appear at runtime; the page wraps new ones on every
-- render. Nodes are walked at load and at each join.
function grug_skills.guard_detached()
	for name, callbacks in pairs(core.detached_inventories or {}) do
		wrap_detached(name, callbacks)
	end
end

function grug_skills.guard_destinations()
	for name, def in pairs(core.registered_nodes) do wrap_node(name, def) end
	grug_skills.guard_detached()
end
core.register_on_mods_loaded(grug_skills.guard_destinations)
core.register_on_joinplayer(function() grug_skills.guard_destinations() end)
