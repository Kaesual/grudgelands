-- Bag system (LotT/inventory_plus pattern): 4 bag slots, each holding one
-- bag item whose `bagslots` group value sizes the matching content list.
-- Base inventory stays 32; bags only ever add slots.
--
-- Safety rules (a shrinking list would silently destroy items):
--  * a bag can only be removed/replaced while its contents are empty
--  * bags never go inside bags

grug_inventory.BAG_COUNT = 4

function grug_inventory.bag_list(i)
	return "grug_bag" .. i
end

function grug_inventory.content_list(i)
	return "grug_bag" .. i .. "_content"
end

local function bag_slot_index(listname)
	return tonumber(listname:match("^grug_bag(%d)$"))
end

local function content_index(listname)
	return tonumber(listname:match("^grug_bag(%d)_content$"))
end

function grug_inventory.bag_slots_of(stack)
	return core.get_item_group(stack:get_name(), "bagslots")
end

--
-- Bag items. Recipes deliberately do not exist yet: bags are Tailor
-- products (WP10) plus one vendor-sold small bag (WP7). Test via /give.
--

core.register_craftitem("grug_inventory:bag_small", {
	description = "Small Bag (8 slots)",
	inventory_image = "grug_inventory_bag_small.png",
	stack_max = 1,
	groups = {bagslots = 8},
})

core.register_craftitem("grug_inventory:bag_medium", {
	description = "Medium Bag (16 slots)",
	inventory_image = "grug_inventory_bag_medium.png",
	stack_max = 1,
	groups = {bagslots = 16},
})

core.register_craftitem("grug_inventory:bag_large", {
	description = "Large Bag (24 slots)",
	inventory_image = "grug_inventory_bag_large.png",
	stack_max = 1,
	groups = {bagslots = 24},
})

--
-- List setup & rules
--

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for i = 1, grug_inventory.BAG_COUNT do
		inv:set_size(grug_inventory.bag_list(i), 1)
		local bag = inv:get_stack(grug_inventory.bag_list(i), 1)
		inv:set_size(grug_inventory.content_list(i),
			grug_inventory.bag_slots_of(bag))
	end
end)

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	local from_list, to_list, stack
	if action == "move" then
		from_list = info.from_list
		to_list = info.to_list
		stack = inventory:get_stack(info.from_list, info.from_index)
	elseif action == "put" then
		to_list = info.listname
		stack = info.stack
	elseif action == "take" then
		from_list = info.listname
		stack = info.stack
	end

	-- Taking a bag out (or swapping it away) requires empty contents.
	local from_bag = from_list and bag_slot_index(from_list)
	if from_bag and not inventory:is_empty(grug_inventory.content_list(from_bag)) then
		return 0
	end

	if to_list then
		local to_bag = bag_slot_index(to_list)
		if to_bag then
			if grug_inventory.bag_slots_of(stack) == 0 then
				return 0 -- only bags fit into bag slots
			end
			-- Replacing an equipped bag also requires empty contents.
			local current = inventory:get_stack(to_list, 1)
			if not current:is_empty() and
					not inventory:is_empty(grug_inventory.content_list(to_bag)) then
				return 0
			end
			return 1
		end
		if content_index(to_list) and grug_inventory.bag_slots_of(stack) > 0 then
			return 0 -- no bags inside bags
		end
	end

	-- Not our concern: nil keeps the callback chain running (OR_SC).
end)

core.register_on_player_inventory_action(function(player, action, inventory, info)
	local touched_bags = {}
	-- Only BAG SLOT changes can alter a content list's size — moves inside
	-- a content list must not trigger the resize/refresh, or every item
	-- move re-sends the formspec and resets the client's drag state.
	local function note(listname)
		local i = listname and bag_slot_index(listname)
		if i then
			touched_bags[i] = true
		end
	end
	if action == "move" then
		note(info.from_list)
		note(info.to_list)
	else
		note(info.listname)
	end

	local refresh = false
	for i in pairs(touched_bags) do
		local bag = inventory:get_stack(grug_inventory.bag_list(i), 1)
		inventory:set_size(grug_inventory.content_list(i),
			grug_inventory.bag_slots_of(bag))
		refresh = true
	end
	if refresh then
		grug_inventory.refresh(player)
	end
end)
