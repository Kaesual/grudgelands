-- The durability hints (Round 70, durability_repair.md "Wear presentation"):
-- two small permanent lines left of the HUD column, one while a broken item
-- is equipped, one while an equipped item is below 15 %. They follow the
-- equipment notifier and nothing else: a use reads the one slot it wore, any
-- other change reads the equipment slots, and an element exists only while
-- its hint shows. Which items count is grug_repair.eligible's answer.

local LOW_SHARE = 0.15
local HINTS = {
	broken = {upper = false, text = "Broken gear equipped", number = 0xff5a4a},
	low = {upper = true, text = "Gear almost broken", number = 0xffc23d},
}

-- player name -> {states = {list -> "broken" | "low"}, ids = {kind -> hud id}}
local rows = {}

-- A broken item is the broken hint alone: it is not also "almost broken".
local function state_of(stack)
	if not grug_repair.eligible(stack) then return nil end
	if grug_core.equipment_is_broken(stack) then return "broken" end
	local remaining, maximum = grug_repair.durability(stack)
	return remaining < LOW_SHARE * maximum and "low" or nil
end

local function draw(player, row)
	local wanted = {}
	for _, state in pairs(row.states) do wanted[state] = true end
	for kind, hint in pairs(HINTS) do
		if wanted[kind] and not row.ids[kind] then
			row.ids[kind] = player:hud_add(grug_core.hud_layout.gear_hint(hint.upper,
				{text = hint.text, number = hint.number, z_index = 1}))
		elseif row.ids[kind] and not wanted[kind] then
			player:hud_remove(row.ids[kind])
			row.ids[kind] = nil
		end
	end
end

grug_core.register_on_equipment_change(function(player, listname, reason)
	local name = player:get_player_name()
	local row = rows[name]
	if not row then
		row = {states = {}, ids = {}}
		rows[name] = row
	end
	local inv = player:get_inventory()
	if reason == "durability_metadata" and listname then
		-- One use on one slot: the common case stops at this comparison.
		local state = state_of(inv:get_stack(listname, 1))
		if state == row.states[listname] then return end
		row.states[listname] = state
	else
		row.states = {}
		for _, slot in ipairs(grug_inventory.equipment_slots) do
			row.states[slot.list] = state_of(inv:get_stack(slot.list, 1))
		end
	end
	draw(player, row)
end)

core.register_on_leaveplayer(function(player)
	rows[player:get_player_name()] = nil
end)
