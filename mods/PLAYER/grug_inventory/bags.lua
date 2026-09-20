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

local extra_bags = {
	{"bag_great", "Great Cloth Bag", 32, "grug_inventory_bag_large.png"},
	{"bag_leather_pouch", "Leather Pouch", 8, "grug_inventory_bag_small.png^[colorize:#6b4428:58"},
	{"bag_leather_satchel", "Leather Satchel", 16, "grug_inventory_bag_medium.png^[colorize:#6b4428:58"},
	{"bag_leather_pack", "Leather Pack", 24, "grug_inventory_bag_large.png^[colorize:#6b4428:58"},
	{"bag_leather_rucksack", "Leather Rucksack", 32, "grug_inventory_bag_large.png^[colorize:#6b4428:58"},
}
for _, row in ipairs(extra_bags) do
	core.register_craftitem("grug_inventory:" .. row[1], {
		description = row[2] .. " (" .. row[3] .. " slots)",
		inventory_image = row[4], stack_max = 1, groups = {bagslots = row[3]},
	})
end

grug_inventory.QUIVER_LIST = "grug_quiver_content"
core.register_craftitem("grug_inventory:quiver", {
	description = "Quiver (4 arrow stacks)",
	inventory_image = "grug_inventory_quiver.png^[resize:64x64",
	stack_max = 1, _grug_hands = 0, _grug_tier = 1,
	groups = {grug_equip_offhand = 1, grug_quiver = 1},
})

local function is_arrow(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_arrow") > 0
end

local function equipped_quiver(inventory)
	return core.get_item_group(inventory:get_stack("grug_offhand", 1):get_name(),
		"grug_quiver") > 0
end

local function quiver_arrow_count(inventory)
	local count = 0
	for _, stack in ipairs(inventory:get_list(grug_inventory.QUIVER_LIST) or {}) do
		if is_arrow(stack) then count = count + stack:get_count() end
	end
	return count
end

local function main_arrow_capacity(inventory, occupied_index)
	local capacity = 0
	local arrow_stack_max = ItemStack("grug_gear:arrow"):get_stack_max()
	for index, stack in ipairs(inventory:get_list("main") or {}) do
		if index ~= occupied_index then
			if stack:is_empty() then
				capacity = capacity + arrow_stack_max
			elseif is_arrow(stack) then
				capacity = capacity + math.max(0, stack:get_stack_max() - stack:get_count())
			end
		end
	end
	return capacity
end

local function usable_ammo_lists(inventory)
	local quiver = inventory:get_stack("grug_offhand", 1)
	if equipped_quiver(inventory) and quiver:get_wear() < 65535 then
		return {grug_inventory.QUIVER_LIST, "main"}
	end
	return {"main"}
end

function grug_inventory.ammo_count(player)
	local inv = player:get_inventory()
	local count = 0
	for _, list in ipairs(usable_ammo_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if is_arrow(stack) then count = count + stack:get_count() end
		end
	end
	return count
end

function grug_inventory.get_equipped_quiver(player)
	local inv = player and player:get_inventory()
	if not inv then return nil end
	local stack = inv:get_stack("grug_offhand", 1)
	if core.get_item_group(stack:get_name(), "grug_quiver") == 0 or
		stack:get_wear() >= 65535 then return nil end
	return ItemStack(stack)
end

function grug_inventory.is_bow(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_bow") > 0
end

-- One server-side transaction: quiver first, then main. No list is written
-- until the combined preflight has proved that the complete shot can settle.
function grug_inventory.consume_ammo(player, count)
	count = math.floor(tonumber(count) or 1)
	if count < 1 or grug_inventory.ammo_count(player) < count then return false end
	local inv = player:get_inventory()
	local left = count
	for _, list in ipairs(usable_ammo_lists(inv)) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			if left > 0 and is_arrow(stack) then
				local take = math.min(left, stack:get_count())
				stack:take_item(take)
				inv:set_stack(list, index, stack)
				left = left - take
			end
		end
	end
	return left == 0
end

-- Return one successful shot action's complete ammunition count. Prefer the
-- equipped quiver, then main; if both filled between launch and refund, place
-- the remainder at the player's feet instead of silently losing it.
function grug_inventory.refund_ammo(player, count)
	count = math.floor(tonumber(count) or 0)
	if count < 1 then return false end
	local inv = player and player:get_inventory()
	if not inv then return false end
	local leftover = ItemStack("grug_gear:arrow " .. count)
	if grug_inventory.get_equipped_quiver(player) then
		leftover = inv:add_item(grug_inventory.QUIVER_LIST, leftover)
	end
	if not leftover:is_empty() then
		leftover = inv:add_item("main", leftover)
	end
	if not leftover:is_empty() then
		core.add_item(player:get_pos(), leftover)
	end
	return true
end

--
-- List setup & rules
--

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	inv:set_size(grug_inventory.QUIVER_LIST, 4)
	for i = 1, grug_inventory.BAG_COUNT do
		inv:set_size(grug_inventory.bag_list(i), 1)
		local bag = inv:get_stack(grug_inventory.bag_list(i), 1)
		inv:set_size(grug_inventory.content_list(i),
			grug_inventory.bag_slots_of(bag))
	end
end)

local quiver_notice_at = {}
core.register_on_leaveplayer(function(player)
	quiver_notice_at[player:get_player_name()] = nil
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

	-- Removing a filled quiver is one transaction: all arrows must fit in main
	-- after the quiver move. The post-action callback performs the transfer.
	if from_list == "grug_offhand" and equipped_quiver(inventory) then
		local occupied = action == "move" and to_list == "main" and info.to_index or nil
		if main_arrow_capacity(inventory, occupied) < quiver_arrow_count(inventory) then
			local name = player:get_player_name()
			local now = core.get_us_time()
			if not quiver_notice_at[name] or now - quiver_notice_at[name] >= 2000000 then
				quiver_notice_at[name] = now
				core.chat_send_player(name,
					"Make room in your main inventory for all arrows before removing the quiver.")
			end
			return 0
		end
	end

	if to_list then
		if to_list == grug_inventory.QUIVER_LIST then
			if not equipped_quiver(inventory) or
				inventory:get_stack("grug_offhand", 1):get_wear() >= 65535 then return 0 end
			return is_arrow(stack) and (info.count or stack:get_count()) or 0
		end
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
	local removed_quiver = (action == "move" and info.from_list == "grug_offhand") or
		(action == "take" and info.listname == "grug_offhand")
	if removed_quiver and not equipped_quiver(inventory) then
		for index, stack in ipairs(inventory:get_list(grug_inventory.QUIVER_LIST) or {}) do
			if not stack:is_empty() then
				local leftover = inventory:add_item("main", stack)
				if not leftover:is_empty() then
					error("grug_inventory: quiver transfer violated its preflight", 0)
				end
				inventory:set_stack(grug_inventory.QUIVER_LIST, index, ItemStack(""))
			end
		end
		refresh = true
	end
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
