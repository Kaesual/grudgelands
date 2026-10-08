-- Bag system (LotT/inventory_plus pattern): 4 bag slots, each holding one
-- bag item whose `bagslots` group value sizes the matching content list.
-- Base inventory stays 32; bags only ever add slots.
--
-- Bag rules (spec ui-crafting-rework-plan.md §2.3; a shrinking list would
-- silently destroy items, set_size truncates):
--  * a bag may sit inside another bag, never in its own content list (an
--    unequipped bag is always empty: the contents belong to the slot)
--  * swapping to an equal or larger bag keeps the contents
--  * taking a bag out, or swapping to a smaller one, moves the contents that
--    no longer fit to main[9..], the other bags and the hotbar, or is
--    refused when they do not fit there (storage.lua plan_bag_resize)
--  * a move between two bag slots needs both bags empty

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

--
-- The Scout's quiver (Round 28 ruling 26). One slot beside the equipment
-- slots holds up to quiver_capacity() arrows; there is no quiver item.
--
-- Why: arrows are the Scout's ammunition, and a slot of its own keeps them
-- out of the bags without an item to craft first. Shots draw from the quiver
-- first, then from `main` and the bags.
--
-- The arrows live in QUIVER_LIST, QUIVER_STACKS ordinary stacks of up to the
-- arrow's stack_max (100) each, but the Character page draws only its first
-- cell. normalize_quiver keeps that cell holding min(total, 100), so clicking
-- it takes up to 100 arrows as one stack; a label beside it shows the total,
-- and above 100 an overlay on the cell shows it too (pages.lua, Round 41).
-- Arrows come in by drag, shift-click and pickup. A drag onto the full
-- visible cell cannot be an engine move (the engine would swap the stacks),
-- so every move INTO the quiver is applied by absorb_into_quiver from the
-- allow callback, which then refuses the engine's own move. There is no item
-- drop on death, so the quiver keeps its arrows like the equipped items do.
--
grug_inventory.QUIVER_LIST = "grug_quiver_content"
grug_inventory.QUIVER_STACKS = 5
local QUIVER_LIST = grug_inventory.QUIVER_LIST
local QUIVER_STACKS = grug_inventory.QUIVER_STACKS
local ARROW = "grug_gear:arrow"

local function is_arrow(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_arrow") > 0
end

function grug_inventory.quiver_capacity()
	return QUIVER_STACKS * ItemStack(ARROW):get_stack_max()
end

-- Only the Scout has a quiver slot.
function grug_inventory.has_quiver(player)
	return grug_classes.get_class(player) == "scout"
end

-- Stack counts for `total` arrows over `size` cells of `stack_max`: cell 1
-- first, so the one visible cell is full whenever there are 100 arrows.
function grug_inventory.quiver_layout(total, stack_max, size)
	local counts = {}
	for index = 1, size do
		local count = math.max(0, math.min(stack_max, total))
		counts[index] = count
		total = total - count
	end
	return counts
end

local function quiver_total(inventory)
	local count = 0
	for _, stack in ipairs(inventory:get_list(QUIVER_LIST) or {}) do
		if is_arrow(stack) then count = count + stack:get_count() end
	end
	return count
end

-- Rewrite the quiver into its layout, writing only the cells that change.
-- Arrows are the only items that may enter, so the content is one total per
-- arrow item -- with the one arrow item there is, one total.
local function normalize_quiver(inventory)
	local totals, order = {}, {}
	for _, stack in ipairs(inventory:get_list(QUIVER_LIST) or {}) do
		if not stack:is_empty() then
			local name = stack:get_name()
			if not totals[name] then
				order[#order + 1] = name
				totals[name] = 0
			end
			totals[name] = totals[name] + stack:get_count()
		end
	end
	local size = inventory:get_size(QUIVER_LIST)
	local wanted, index = {}, 1
	for _, name in ipairs(order) do
		local counts = grug_inventory.quiver_layout(totals[name],
			ItemStack(name):get_stack_max(), size - index + 1)
		for _, count in ipairs(counts) do
			if count > 0 then
				wanted[index] = name .. " " .. count
				index = index + 1
			end
		end
	end
	for cell = 1, size do
		local target = ItemStack(wanted[cell] or "")
		if inventory:get_stack(QUIVER_LIST, cell):to_string() ~= target:to_string() then
			inventory:set_stack(QUIVER_LIST, cell, target)
		end
	end
end

-- The Character page's Stats tab prints the total beside the slot, so a
-- changed quiver re-renders a cached Stats tab (pages.lua). Nothing else is
-- re-sent.
local function quiver_changed(player, inventory)
	normalize_quiver(inventory)
	if grug_inventory.refresh_character_tab then
		grug_inventory.refresh_character_tab(player, "stats")
	end
end

function grug_inventory.quiver_count(player)
	local inv = player and player:get_inventory()
	return inv and quiver_total(inv) or 0
end

-- Put arrows into the Scout's quiver as far as it has room. Returns the
-- leftover (all of it for a non-Scout or a non-arrow).
function grug_inventory.add_to_quiver(player, stack)
	stack = ItemStack(stack)
	local inv = player and player:get_inventory()
	if not inv or not is_arrow(stack) or not grug_inventory.has_quiver(player) then
		return stack
	end
	local room = grug_inventory.quiver_capacity() - quiver_total(inv)
	local count = math.min(room, stack:get_count())
	if count <= 0 then
		return stack
	end
	-- Counts, not take_item: a stack taken to zero loses its name, and a later
	-- set_count would then leave a nameless stack behind.
	local moving = ItemStack(stack)
	moving:set_count(count)
	local accepted = count - inv:add_item(QUIVER_LIST, moving):get_count()
	stack:set_count(stack:get_count() - accepted)
	quiver_changed(player, inv)
	return stack
end

-- A move into the quiver: up to `count` arrows of the source stack go in,
-- applied here rather than by the engine (see above).
local function absorb_into_quiver(player, inventory, from_list, from_index, count)
	local source = inventory:get_stack(from_list, from_index)
	if not is_arrow(source) then
		return
	end
	local moving = ItemStack(source)
	moving:set_count(math.min(count, source:get_count()))
	local accepted = moving:get_count() -
		grug_inventory.add_to_quiver(player, moving):get_count()
	if accepted <= 0 then
		return -- a full quiver: nothing changes hands
	end
	source:set_count(source:get_count() - accepted)
	inventory:set_stack(from_list, from_index, source)
end

-- Arrows shoot from the quiver first, then from `main` and every bag, so
-- sorted or overflowed arrows in a bag still count (Round 44).
local function usable_ammo_lists(player)
	local lists = grug_inventory.carried_lists(player:get_inventory())
	if grug_inventory.has_quiver(player) then
		table.insert(lists, 1, QUIVER_LIST)
	end
	return lists
end

function grug_inventory.ammo_count(player)
	local inv = player:get_inventory()
	local count = 0
	for _, list in ipairs(usable_ammo_lists(player)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if is_arrow(stack) then count = count + stack:get_count() end
		end
	end
	return count
end

function grug_inventory.is_bow(stack)
	return stack and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_bow") > 0
end

-- One server-side transaction: quiver first, then main and the bags. No list is written
-- until the combined preflight has proved that the complete shot can settle.
function grug_inventory.consume_ammo(player, count)
	count = math.floor(tonumber(count) or 1)
	if count < 1 or grug_inventory.ammo_count(player) < count then return false end
	local inv = player:get_inventory()
	local left = count
	local from_quiver = false
	for _, list in ipairs(usable_ammo_lists(player)) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			if left > 0 and is_arrow(stack) then
				local take = math.min(left, stack:get_count())
				stack:take_item(take)
				inv:set_stack(list, index, stack)
				left = left - take
				from_quiver = from_quiver or list == QUIVER_LIST
			end
		end
	end
	if from_quiver then
		quiver_changed(player, inv)
	end
	return left == 0
end

-- Return one successful shot action's complete ammunition count through the
-- give helper (quiver first); if everything filled between launch and
-- refund, place the remainder at the player's feet instead of losing it.
-- Picked-up arrows take the same way (storage.lua's pickup handler).
function grug_inventory.refund_ammo(player, count)
	count = math.floor(tonumber(count) or 0)
	if count < 1 then return false end
	local inv = player and player:get_inventory()
	if not inv then return false end
	local leftover = grug_inventory.give(player, ItemStack(ARROW .. " " .. count))
	if not leftover:is_empty() then
		core.add_item(player:get_pos(), leftover)
	end
	return true
end

-- Would moving `stack` onto `dest` be a swap? The engine swaps when nothing of
-- the stack fits. A move out of the quiver never swaps: arrows would enter
-- the quiver past absorb_into_quiver.
local function would_swap(dest, stack)
	if dest:is_empty() then
		return false
	end
	return ItemStack(dest):add_item(stack):get_count() == stack:get_count()
end

-- May bag slot `i`'s contents shrink to `new_size` (0: the bag leaves)?
-- Counted without the bag's own list and without `landing`, the slot the
-- leaving bag lands in. A refusal is one keyed feed line.
local function bag_contents_fit(player, inventory, i, new_size, landing)
	if inventory:get_size(grug_inventory.content_list(i)) <= new_size or
			grug_inventory.plan_bag_resize(inventory, i, new_size, landing) then
		return true
	end
	grug_core.feed(player, "notice",
		"No room for the bag's contents: make space in your inventory first.",
		"bag_contents")
	return false
end

--
-- List setup & rules
--

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	inv:set_size(QUIVER_LIST, QUIVER_STACKS)
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

	local from_bag = from_list and bag_slot_index(from_list)
	local to_bag = to_list and bag_slot_index(to_list)
	if from_bag and to_bag then
		-- Between two bag slots: only empty bags (the contents belong to
		-- the slot, so they would not follow the bag).
		if not inventory:is_empty(grug_inventory.content_list(from_bag)) or
				not inventory:is_empty(grug_inventory.content_list(to_bag)) then
			return 0
		end
	elseif from_bag then
		-- A bag leaves its slot (drag, drop, into another inventory), or a
		-- swap replaces it with the bag lying on the target slot. Never
		-- into its own content list.
		if to_list and content_index(to_list) == from_bag then
			return 0
		end
		local new_size, landing = 0, nil
		if action == "move" then
			local incoming = inventory:get_stack(to_list, info.to_index)
			if would_swap(incoming, stack) then
				new_size = grug_inventory.bag_slots_of(incoming)
				if new_size == 0 then
					return 0 -- only a bag may take the slot
				end
			end
			landing = {list = to_list, index = info.to_index}
		end
		if not bag_contents_fit(player, inventory, from_bag, new_size, landing) then
			return 0
		end
	end

	if to_list == QUIVER_LIST then
		if not grug_inventory.has_quiver(player) or not is_arrow(stack) then
			return 0
		end
		if action == "put" then
			-- From another inventory: the engine's own add, as far as the
			-- quiver and the target cell have room.
			local room = grug_inventory.quiver_capacity() - quiver_total(inventory)
			local cell = inventory:get_stack(QUIVER_LIST, info.index)
			if not cell:is_empty() and cell:get_name() ~= stack:get_name() then
				return 0
			end
			return math.max(0, math.min(stack:get_count(), room,
				stack:get_stack_max() - cell:get_count()))
		end
		if from_list ~= QUIVER_LIST then
			absorb_into_quiver(player, inventory, from_list, info.from_index,
				info.count or stack:get_count())
		end
		return 0
	end
	if from_list == QUIVER_LIST and action == "move" and
			would_swap(inventory:get_stack(to_list, info.to_index), stack) then
		return 0
	end

	if to_bag then
		local new_size = grug_inventory.bag_slots_of(stack)
		if new_size == 0 then
			return 0 -- only bags fit into bag slots
		end
		if from_list and content_index(from_list) == to_bag then
			return 0 -- the old bag would land in its own content list
		end
		-- Replacing an equipped bag: a smaller one moves the overflow.
		local current = inventory:get_stack(to_list, 1)
		if not from_bag and not current:is_empty() and
				not bag_contents_fit(player, inventory, to_bag, new_size) then
			return 0
		end
		return 1
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

	-- Arrows taken out of the quiver: refill its visible cell.
	if (action == "move" and info.from_list == QUIVER_LIST) or
			(action ~= "move" and info.listname == QUIVER_LIST) then
		quiver_changed(player, inventory)
	end

	-- The overflow of a removed or smaller bag moves before the list
	-- shrinks, in this one callback (storage.lua apply_bag_resize).
	local refresh = false
	for i in pairs(touched_bags) do
		local bag = inventory:get_stack(grug_inventory.bag_list(i), 1)
		grug_inventory.apply_bag_resize(player, inventory, i,
			grug_inventory.bag_slots_of(bag))
		refresh = true
	end
	if refresh then
		grug_inventory.refresh(player)
	end
end)

dofile(core.get_modpath(core.get_current_modname()) .. "/storage.lua")
