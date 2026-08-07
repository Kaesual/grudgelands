-- Equipment slots as player-inventory lists (size 1 each). Items declare
-- their slot via group (dispatch-via-groups convention), e.g. a helmet
-- carries `groups = {grug_equip_head = 1}`. The trinket slots are reserved:
-- fully functional, but no trinket items exist before post-MVP.

grug_inventory.equipment_slots = {
	{list = "grug_head", group = "grug_equip_head", label = "Head"},
	{list = "grug_chest", group = "grug_equip_chest", label = "Chest"},
	{list = "grug_legs", group = "grug_equip_legs", label = "Legs"},
	{list = "grug_feet", group = "grug_equip_feet", label = "Feet"},
	{list = "grug_offhand", group = "grug_equip_offhand", label = "Offhand"},
	{list = "grug_trinket1", group = "grug_equip_trinket", label = "Trinket"},
	{list = "grug_trinket2", group = "grug_equip_trinket", label = "Trinket"},
}

local slot_group = {}
for _, slot in ipairs(grug_inventory.equipment_slots) do
	slot_group[slot.list] = slot.group
end

-- The armor-bearing slots. Offhand is excluded on purpose (shields and their
-- armor contribution are WP14) and so are the trinkets.
local ARMOR_LISTS = {"grug_head", "grug_chest", "grug_legs", "grug_feet"}

local is_armor_list = {}
for _, list in ipairs(ARMOR_LISTS) do
	is_armor_list[list] = true
end

function grug_inventory.is_equipment_list(listname)
	return slot_group[listname] ~= nil
end

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		inv:set_size(slot.list, 1)
	end
end)

--
-- Armor class gate (items_crafting.md §3.1, combat_stats.md §2). Ranks are
-- cloth 1 < leather 2 < metal 3; grug_classes.get_armor_rank says how high a
-- character may go. Items without the `grug_armor_class` group are
-- unaffected -- nothing else in the game carries it today.
--

local ARMOR_CLASS_NAME = {"cloth", "leather", "metal"}
local WARN_INTERVAL = 2 -- seconds

-- The allow callback fires repeatedly while a stack is dragged around, so the
-- refusal message has to be throttled per player or it spams the chat.
local last_warn = {}

local function warn_armor_class(player, rank)
	local name = player:get_player_name()
	local now = grug_core.mono_time()
	local last = last_warn[name]
	if last and now - last < WARN_INTERVAL then
		return
	end
	last_warn[name] = now
	local class_def = grug_classes.get_class_def(player)
	core.chat_send_player(name, core.colorize("#ff9955",
		"A " .. (class_def and class_def.name or "character without a class") ..
		" cannot wear " .. (ARMOR_CLASS_NAME[rank] or "that") .. " armor."))
end

core.register_on_leaveplayer(function(player)
	last_warn[player:get_player_name()] = nil
end)

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	local to_list, stack
	if action == "move" then
		to_list = info.to_list
		stack = inventory:get_stack(info.from_list, info.from_index)
	elseif action == "put" then
		to_list = info.listname
		stack = info.stack
	end
	local group = to_list and slot_group[to_list]
	if group then
		if core.get_item_group(stack:get_name(), group) == 0 then
			return 0
		end
		if is_armor_list[to_list] then
			-- NB deliberately NO grug_req_level check here: the item-level
			-- requirement is WP5's (it owns the meta key), see
			-- inventory_equipment.md §2.
			local rank = core.get_item_group(stack:get_name(), "grug_armor_class")
			if rank > 0 and rank > grug_classes.get_armor_rank(player) then
				warn_armor_class(player, rank)
				return 0
			end
		end
		return 1 -- slots hold exactly one item
	end
	-- Not our list: return nil so later allow callbacks still run (the
	-- engine combines them with OR + short-circuit — a number here would
	-- swallow every other mod's check).
end)

-- Equipment changed: recompute stats (gear stats land with WP5 — the hook
-- is already the right place) and refresh an open character page.
core.register_on_player_inventory_action(function(player, action, inventory, info)
	local touched = (action == "move" and
			(slot_group[info.from_list] or slot_group[info.to_list]))
		or (action ~= "move" and slot_group[info.listname])
	if touched then
		grug_classes.apply_stats(player)
		grug_inventory.refresh(player)
	end
end)

--
-- Armor points of everything currently worn (items_crafting.md §3.1: 1 point
-- = 1% damage reduction). Read off the ITEM DEFINITION: per-stack overrides
-- through item meta are WP5's business (rolled affixes), not WP7's.
--

function grug_inventory.get_equipped_armor(player)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	local inv = player:get_inventory()
	if not inv then
		return 0
	end
	local total = 0
	for _, list in ipairs(ARMOR_LISTS) do
		local stack = inv:get_stack(list, 1)
		if not stack:is_empty() then
			local def = core.registered_items[stack:get_name()]
			local armor = def and def._grug_armor
			if type(armor) == "number" and armor > 0 then
				total = total + armor
			end
		end
	end
	return total
end

-- Wire the real value into grug_core's damage pipeline (stub override, same
-- pattern as grug_classes' crit/dodge accessors). Hard cap 60% — endgame
-- plate plus shield reaches it, vendor gear never does.
function grug_core.get_armor_percent(player)
	return math.min(60, grug_inventory.get_equipped_armor(player))
end
