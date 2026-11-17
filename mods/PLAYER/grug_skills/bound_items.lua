local function bound(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_bound_skill") > 0
end

-- Skills (ability representations) live on the hotbar only (Round 44, spec
-- ui-crafting-rework-plan.md ruling 8): main[1..8], and on the inactive
-- hotbar layout's hidden list, which only a switch fills (Round 50;
-- grug_inventory/hotbars.lua refuses every inventory action on it). The
-- one-copy check (`carried`) leaves that list out, so a skill may lie once
-- on each layout. The retired mount items are aliases of "" since Round 81
-- (grug_mounts/items.lua), so every bound item is a skill.

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
	local id = stack:get_name():match("^grug_abilities:(.+)$")
	return id ~= nil and grug_abilities.is_unlocked(player, id)
end

grug_skills.is_entitled = entitled

-- Whether the player carries `itemname` in main, craft or an owned bag (the
-- shown layout's side, not the inactive layout).
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
local function player_action(player, action, inventory, info)
	if action == "move" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if not bound(stack) then return end
		if not owned_list(info.from_list) or not entitled(player, stack) or
				not hotbar_slot(info.to_list, info.to_index) then return 0 end
	elseif action == "put" and bound(info.stack) then
		if not owns_inventory(player, inventory) or not entitled(player, info.stack) then
			return 0
		end
		local name = info.stack:get_name()
		if inventory:get_stack(info.listname, info.index):get_name() == name then return end
		if not hotbar_slot(info.listname, info.index) or
				carried(inventory, name) then return 0 end
	end
end

-- A rule of grug_inventory's bound-item seam (grug_inventory/bound.lua):
-- node inventories refuse a skill, detached inventories refuse
-- it on a put (from their creation on, Round 81, audit C3-03) except this
-- mod's own catalogs (`grug_skills_<player>`, page.lua), where dragging a
-- skill back removes it.
grug_inventory.register_bound_rule({group = "grug_bound_skill",
	player_action = player_action, detached_exempt = "^grug_skills_"})

-- grug_jobs (a dependency, through grug_mounts) replaces the stations'
-- allow callbacks in its own mods-loaded step, after grug_inventory's walk:
-- walking again now wraps those. A closure of its own, so the callback is
-- this mod's (core.callback_origins is keyed by the function).
core.register_on_mods_loaded(function() grug_inventory.guard_bound_destinations() end)
