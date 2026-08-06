-- Equipment slots as player-inventory lists (size 1 each). Items declare
-- their slot via group (dispatch-via-groups convention), e.g. a helmet
-- carries `groups = {wob_equip_head = 1}`. The trinket slots are reserved:
-- fully functional, but no trinket items exist before post-MVP.

wob_inventory.equipment_slots = {
	{list = "wob_head", group = "wob_equip_head", label = "Head"},
	{list = "wob_chest", group = "wob_equip_chest", label = "Chest"},
	{list = "wob_legs", group = "wob_equip_legs", label = "Legs"},
	{list = "wob_feet", group = "wob_equip_feet", label = "Feet"},
	{list = "wob_offhand", group = "wob_equip_offhand", label = "Offhand"},
	{list = "wob_trinket1", group = "wob_equip_trinket", label = "Trinket"},
	{list = "wob_trinket2", group = "wob_equip_trinket", label = "Trinket"},
}

local slot_group = {}
for _, slot in ipairs(wob_inventory.equipment_slots) do
	slot_group[slot.list] = slot.group
end

function wob_inventory.is_equipment_list(listname)
	return slot_group[listname] ~= nil
end

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for _, slot in ipairs(wob_inventory.equipment_slots) do
		inv:set_size(slot.list, 1)
	end
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
		wob_classes.apply_stats(player)
		wob_inventory.refresh(player)
	end
end)
