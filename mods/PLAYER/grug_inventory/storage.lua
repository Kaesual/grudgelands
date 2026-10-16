-- Inventory logic of the one-inventory view (Round 44 lane IH, spec
-- ui-crafting-rework-plan.md §2.2-2.5, §3.2): the give helper every item
-- source uses, the fit check, the sort, the potion belt and the bag
-- redistribution plan bags.lua runs. Loaded from bags.lua; draws nothing.
--
-- The data model stays `main` (hotbar 1..8, then 24 slots) plus one content
-- list per equipped bag, and the inactive hotbar layout (below). Items
-- arrive in one order: `main[9..]`, the bags in slot order, the hotbar last,
-- so a hotbar slot freed for a skill stays free; never the inactive layout.
-- Arrows go to a Scout's quiver first.

local HOTBAR = 8
grug_inventory.HOTBAR_SIZE = HOTBAR
grug_inventory.POTION_BELT = "grug_potion_belt"
grug_inventory.POTION_BELT_SIZE = 4
local BELT = grug_inventory.POTION_BELT

-- The two hotbar layouts (Round 50 rulings 1-3, hotbars.lua): the visible
-- hotbar is always main[1..8]; the other layout's eight stacks wait in the
-- player list HOTBAR_STORE, which no form draws. Player meta
-- HOTBAR_LAYOUT_KEY names the layout on main[1..8], "A" or "B" (missing:
-- "A", so every character starts on A with B empty).
grug_inventory.HOTBAR_STORE = "grug_hotbar_store"
grug_inventory.HOTBAR_LAYOUT_KEY = "grug_inventory:hotbar_layout"

function grug_inventory.active_hotbar(player)
	return player:get_meta():get_string(grug_inventory.HOTBAR_LAYOUT_KEY) == "B" and
		"B" or "A"
end

-- The lists a player keeps items in: `main` and each equipped bag's content
-- list, in bag slot order. Readers that count or take items walk these.
-- The quiver, the potion belt, the equipment slots and the inactive hotbar
-- layout are not among them.
function grug_inventory.carried_lists(inv)
	local lists = {"main"}
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		if inv:get_size(list) > 0 then lists[#lists + 1] = list end
	end
	return lists
end

-- The lists a consumer counts and takes items from (Round 50 ruling 3):
-- carried_lists, then the inactive hotbar layout last. Counting and taking
-- walk the same lists, so a count never promises what the take cannot find.
-- Nothing ever gives into the inactive layout (it is not in the give order
-- below), and a vendor's sell list leaves it out (carried_lists).
function grug_inventory.consume_lists(inv)
	local lists = grug_inventory.carried_lists(inv)
	if inv:get_size(grug_inventory.HOTBAR_STORE) > 0 then
		lists[#lists + 1] = grug_inventory.HOTBAR_STORE
	end
	return lists
end

-- Every slot of the give order as {list, index}: main[9..], each bag's
-- content list, then the hotbar. `skip_list` leaves one list out and
-- `skip_list`/`skip_index` one slot (the bag rules, below).
local function ordered_slots(inv, skip_list, skip_slot)
	local slots = {}
	local function add(list, from, to)
		if list == skip_list then return end
		for index = from, to do
			if not (skip_slot and skip_slot.list == list and skip_slot.index == index) then
				slots[#slots + 1] = {list = list, index = index}
			end
		end
	end
	local size = inv:get_size("main")
	add("main", HOTBAR + 1, size)
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		add(list, 1, inv:get_size(list))
	end
	add("main", 1, math.min(HOTBAR, size))
	return slots
end

function grug_inventory.slot_order(inv)
	return ordered_slots(inv)
end

-- The cells of `slots` with a working copy of each stack (one get_list per
-- list, not one get_stack per slot; get_list already returns copies).
-- `given` (fits) maps a list name to stacks that stand in for that list;
-- they are copied, never written.
local function cells_of(inv, slots, given)
	local lists, cells = {}, {}
	for _, slot in ipairs(slots) do
		local list = lists[slot.list]
		if not list then
			local stand_in = given and given[slot.list]
			if stand_in then
				list = {}
				for index, stack in pairs(stand_in) do list[index] = ItemStack(stack) end
			else
				list = inv:get_list(slot.list) or {}
			end
			lists[slot.list] = list
		end
		cells[#cells + 1] = {list = slot.list, index = slot.index,
			stack = list[slot.index] or ItemStack("")}
	end
	return cells
end

-- Put `stack` into the cells: partial stacks of the same item first (the
-- whole order, hotbar included: merging takes no free slot), then empty
-- cells in order. Returns the leftover; touched cells are marked.
local function fill(cells, stack)
	for pass = 1, 2 do
		for _, cell in ipairs(cells) do
			if stack:is_empty() then return stack end
			if cell.stack:is_empty() == (pass == 2) then
				local before = cell.stack:get_count()
				stack = cell.stack:add_item(stack)
				if cell.stack:get_count() ~= before then cell.changed = true end
			end
		end
	end
	return stack
end

local function commit(inv, cells)
	for _, cell in ipairs(cells) do
		if cell.changed then inv:set_stack(cell.list, cell.index, cell.stack) end
	end
end

local function is_arrow(stack)
	return core.get_item_group(stack:get_name(), "grug_arrow") > 0
end

-- The one way items enter a player's inventory (spec §2.4): returns the
-- leftover, which the caller drops, refuses, queues or keeps as before.
-- Every stack gets the weapon-tooltip setup an engine pickup or craft gives
-- it (grug_gear.initialize_weapon_tooltip, cheap for anything but gear).
-- `skip_quiver` leaves the quiver out (arrows shift-clicked out of it).
function grug_inventory.give(player, stack, skip_quiver)
	stack = ItemStack(stack)
	local inv = player and player:get_inventory()
	if stack:is_empty() or not inv then return stack end
	grug_gear.initialize_weapon_tooltip(stack, player)
	if not skip_quiver then
		stack = grug_inventory.add_to_quiver(player, stack)
	end
	if stack:is_empty() then return stack end
	local cells = cells_of(inv, ordered_slots(inv))
	stack = fill(cells, stack)
	commit(inv, cells)
	return stack
end

-- Would `stacks` (a list of stacks or item strings, or one stack) all fit,
-- given in this order? Same order and rules as give, partial stacks counted;
-- changes nothing. `lists` (optional) maps list names to stacks that stand
-- in for those lists: the inventory as it would be after a change not yet
-- made (grug_jobs' start check: after the ingredients are taken).
function grug_inventory.fits(player, stacks, lists)
	local inv = player and player:get_inventory()
	if not inv then return false end
	if type(stacks) ~= "table" then stacks = {stacks} end
	local quiver_room = grug_inventory.has_quiver(player) and
		grug_inventory.quiver_capacity() - grug_inventory.quiver_count(player) or 0
	local cells = cells_of(inv, ordered_slots(inv), lists)
	for _, item in ipairs(stacks) do
		local stack = ItemStack(item)
		if quiver_room > 0 and not stack:is_empty() and is_arrow(stack) then
			local into = math.min(quiver_room, stack:get_count())
			quiver_room = quiver_room - into
			stack:take_item(into)
		end
		if not stack:is_empty() and not fill(cells, stack):is_empty() then
			return false
		end
	end
	return true
end

-- How many of `stack` would give take right now (the quiver, then the
-- order, partial stacks counted)? Changes nothing. The shift-click inbox
-- (inbox.lua) admits exactly this many.
function grug_inventory.room_for(player, stack)
	stack = ItemStack(stack)
	local inv = player and player:get_inventory()
	if not inv or stack:is_empty() then return 0 end
	local count = stack:get_count()
	if is_arrow(stack) and grug_inventory.has_quiver(player) then
		local room = grug_inventory.quiver_capacity() - grug_inventory.quiver_count(player)
		if room > 0 then stack:take_item(math.min(room, count)) end
	end
	if stack:is_empty() then return count end
	return count - fill(cells_of(inv, ordered_slots(inv)), stack):get_count()
end

--
-- Bag redistribution (spec §2.3). Bag slot `i` changes from its current
-- content size to `new_size` (0: the bag leaves). The stacks beyond
-- `new_size` are the overflow: they fill the cells the smaller bag keeps,
-- then main[9..], the other bags and the hotbar -- never the bag's own list
-- beyond its new size, never `landing` (the slot the leaving bag lands in).
-- Returns the cells to commit, or nil when the overflow does not fit.
--
function grug_inventory.plan_bag_resize(inv, i, new_size, landing)
	local list = grug_inventory.content_list(i)
	local stacks = inv:get_list(list) or {}
	local own = {}
	for index = 1, math.min(new_size, #stacks) do
		own[#own + 1] = {list = list, index = index, stack = ItemStack(stacks[index])}
	end
	local others = cells_of(inv, ordered_slots(inv, list, landing))
	for index = new_size + 1, #stacks do
		local rest = ItemStack(stacks[index])
		if not rest:is_empty() then
			rest = fill(others, fill(own, rest))
			if not rest:is_empty() then return nil end
		end
	end
	for _, cell in ipairs(others) do own[#own + 1] = cell end
	return own
end

-- Apply a bag slot's new size: the overflow moves (plan_bag_resize) before
-- set_size truncates the list. The allow callback proved the fit in the same
-- server step; should it fail anyway, the overflow lands at the player's
-- feet rather than being lost.
function grug_inventory.apply_bag_resize(player, inv, i, new_size)
	local list = grug_inventory.content_list(i)
	local old_size = inv:get_size(list)
	if new_size < old_size then
		local cells = grug_inventory.plan_bag_resize(inv, i, new_size)
		if cells then
			commit(inv, cells)
		else
			core.log("warning", "[grug_inventory] bag contents of " ..
				player:get_player_name() .. " did not fit; dropped at the player")
			for index = new_size + 1, old_size do
				local stack = inv:get_stack(list, index)
				if not stack:is_empty() then core.add_item(player:get_pos(), stack) end
			end
		end
	end
	inv:set_size(list, new_size)
end

--
-- The sort (spec §2.5, §3.2): main[9..] and the bags as one sequence, the
-- hotbar untouched. Weapons (offhands included), trinkets, armour,
-- consumables (arrows, food, potions), then the rest; inside a category the
-- higher tier first, then the name, then the higher quality. Stacks merge
-- only when name, wear and metadata are identical; the occupied slots come
-- first, the free ones contiguous at the end.
--

local ARMOUR = {"grug_equip_head", "grug_equip_chest", "grug_equip_legs", "grug_equip_feet"}

-- Category, then a rank inside it (consumables: arrows, food, potions).
local function category_of(groups)
	if (groups.grug_equip_weapon or 0) > 0 or (groups.grug_equip_offhand or 0) > 0 then
		return 1, 0
	end
	if (groups.grug_equip_trinket or 0) > 0 then return 2, 0 end
	for _, group in ipairs(ARMOUR) do
		if (groups[group] or 0) > 0 then return 3, 0 end
	end
	if (groups.grug_arrow or 0) > 0 then return 4, 1 end
	if (groups.grug_food or 0) > 0 then return 4, 2 end
	if (groups.grug_potion or 0) > 0 then return 4, 3 end
	return 5, 0
end

-- Tier: the gear bracket, the food tier, else the item level's tier
-- (ceil(ilvl / 10), grug_quality's rule); 0 for items without one.
local function tier_of(stack, def)
	local bracket = tonumber(def._grug_bracket)
	if bracket then return bracket end
	local food = def.groups and tonumber(def.groups.grug_food_tier)
	if food then return food end
	local ilvl = stack:get_meta():get_int("grug_ilvl")
	if ilvl <= 0 then ilvl = tonumber(def._grug_ilvl) or 0 end
	return ilvl > 0 and math.ceil(ilvl / 10) or 0
end

-- The definition's name (not the rolled one), so equal base items group
-- before their quality orders them.
local function name_of(stack, def)
	local text = core.strip_colors(def.description or stack:get_name())
	return (text:match("^[^\n]*") or ""):lower()
end

local function quality_of(stack, def)
	local quality = stack:get_meta():get_int("grug_quality")
	if quality < 1 then quality = tonumber(def._grug_quality) or 1 end
	return quality
end

-- Name, wear and metadata without the count: equal identities merge.
local function identity_of(stack)
	local one = ItemStack(stack)
	one:set_count(1)
	return one:to_string()
end

local function sort_key(stack, position)
	local def = stack:get_definition() or {}
	local category, rank = category_of(def.groups or {})
	return {category = category, rank = rank, tier = tier_of(stack, def),
		name = name_of(stack, def), quality = quality_of(stack, def),
		identity = identity_of(stack), position = position}
end

local function before(a, b)
	local ka, kb = a.key, b.key
	if ka.category ~= kb.category then return ka.category < kb.category end
	if ka.rank ~= kb.rank then return ka.rank < kb.rank end
	if ka.tier ~= kb.tier then return ka.tier > kb.tier end
	if ka.name ~= kb.name then return ka.name < kb.name end
	if ka.quality ~= kb.quality then return ka.quality > kb.quality end
	if ka.identity ~= kb.identity then return ka.identity < kb.identity end
	return ka.position < kb.position
end

-- Soulbound and bound items (the Claim Stone, skill and mount items) are
-- never left over by a sort into smaller sizes: the mail cannot carry them.
local function guarded(stack)
	local name = stack:get_name()
	return core.get_item_group(name, "grug_soulbound") > 0 or
		core.get_item_group(name, "grug_bound_skill") > 0
end

-- Sort the player's main[9..] and bags; true when any slot changed. Writes
-- only the slots that change, so at most the five lists are resent once.
--
-- `sizes` (optional; the migration step 0.48.0, grug_core/migrations.lua)
-- maps a bag's content list to a smaller target size: the sort then lays
-- every stack of main[9..] and the bags, the cells beyond the targets
-- included, out into main[9..] and each bag's first `size` cells. What does
-- not fit is the end of the order (the rest category, low tiers last),
-- except guarded stacks, which take their cells first; those leftovers fill
-- the cells beyond the targets, in order, and are returned as a second
-- value, a list of {list, index, stack}. The caller takes them out and then
-- shrinks the lists; this function never calls set_size. A size above a
-- list's current one counts as the current one. Without `sizes` (the Sort
-- button) the targets are the current sizes and nothing is left over.
function grug_inventory.sort(player, sizes)
	local inv = player and player:get_inventory()
	if not inv then return false, {} end
	local slots, beyond, entries = {}, {}, {}
	for _, slot in ipairs(ordered_slots(inv)) do
		if not (slot.list == "main" and slot.index <= HOTBAR) then
			local size = sizes and sizes[slot.list]
			if size and slot.index > size then
				beyond[#beyond + 1] = slot
			else
				slots[#slots + 1] = slot
			end
		end
	end
	local cells, rest = cells_of(inv, slots), cells_of(inv, beyond)
	local position = 0
	for _, group in ipairs({cells, rest}) do
		for _, cell in ipairs(group) do
			position = position + 1
			if not cell.stack:is_empty() then
				entries[#entries + 1] = {stack = ItemStack(cell.stack),
					key = sort_key(cell.stack, position)}
			end
		end
	end
	table.sort(entries, before)
	-- Merge neighbours of one identity (the order puts them side by side).
	local merged = {}
	for _, entry in ipairs(entries) do
		local last = merged[#merged]
		local stack = entry.stack
		if last and last.key.identity == entry.key.identity then
			stack = last.stack:add_item(stack)
		end
		if not stack:is_empty() then
			merged[#merged + 1] = {stack = stack, key = entry.key}
		end
	end
	-- More stacks than target cells: the last unguarded ones are left over.
	local leftovers = {}
	local excess = #merged - #cells
	for index = #merged, 1, -1 do
		if excess <= 0 then break end
		if not guarded(merged[index].stack) then
			table.insert(leftovers, 1, table.remove(merged, index))
			excess = excess - 1
		end
	end
	-- Only guarded stacks beyond the targets (never with four bags of the
	-- smallest size: main[9..] alone has 24 cells): they stay beyond too.
	while #merged > #cells do
		table.insert(leftovers, 1, table.remove(merged))
	end
	local changed, left = false, {}
	local function place(cell, wanted)
		if cell.stack:to_string() ~= wanted:to_string() then
			inv:set_stack(cell.list, cell.index, wanted)
			changed = true
		end
	end
	for index, cell in ipairs(cells) do
		place(cell, merged[index] and merged[index].stack or ItemStack(""))
	end
	for index, cell in ipairs(rest) do
		local wanted = leftovers[index] and leftovers[index].stack or ItemStack("")
		place(cell, wanted)
		if not wanted:is_empty() then
			left[#left + 1] = {list = cell.list, index = cell.index, stack = ItemStack(wanted)}
		end
	end
	return changed, left
end

--
-- The potion belt (spec §2.9, §3.5): four slots for potions and elixirs
-- (group grug_potion; alchemy mixtures are not in it). Filled in the
-- Inventory tab, used from the quickbar. Created for every player at join;
-- set_size leaves an existing list as it is.
--
function grug_inventory.belt_accepts(stack)
	return stack ~= nil and not stack:is_empty() and
		core.get_item_group(stack:get_name(), "grug_potion") > 0
end

core.register_on_joinplayer(function(player)
	player:get_inventory():set_size(BELT, grug_inventory.POTION_BELT_SIZE)
end)

core.register_allow_player_inventory_action(function(_, action, inventory, info)
	local stack
	if action == "move" and info.to_list == BELT then
		stack = inventory:get_stack(info.from_list, info.from_index)
	elseif action == "put" and info.listname == BELT then
		stack = info.stack
	else
		return nil
	end
	if not grug_inventory.belt_accepts(stack) then return 0 end
end)

--
-- Acquisition boundaries the engine owns: item pickup and dug node drops
-- (builtin adds both to `main`, builtin/game/item.lua).
--
core.register_on_item_pickup(function(itemstack, picker)
	if not picker or not picker.is_player or not picker:is_player() then
		return nil
	end
	return grug_inventory.give(picker, itemstack)
end)

-- A creative player keeps the creative mod's own handling (it chains to
-- builtin's); everyone else digs through the give helper, the leftover
-- dropped beside the node as builtin does.
local previous_handle_node_drops = core.handle_node_drops
function core.handle_node_drops(pos, drops, digger)
	if not digger or not digger.is_player or not digger:is_player() or
			core.is_creative_enabled(digger:get_player_name()) then
		return previous_handle_node_drops(pos, drops, digger)
	end
	for _, item in pairs(drops) do
		local left = grug_inventory.give(digger, item)
		if not left:is_empty() then
			core.add_item(vector.offset(pos, math.random() / 2 - 0.25,
				math.random() / 2 - 0.25, math.random() / 2 - 0.25), left)
		end
	end
end
