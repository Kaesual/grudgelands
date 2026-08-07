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

--
-- Armor total cache (see grug_inventory.get_equipped_armor at the bottom).
-- Declared up here because both the join hook and the equipment-action hook
-- below maintain it.
--
local armor_cache = {} -- player name -> summed armor points of the 4 slots

-- Forget the cached total; the next read recomputes it. Public because
-- anything that writes an equipment list SERVER-SIDE (the class-change
-- unequip below, later WP11 respec / WP14 shields) bypasses the inventory
-- action callbacks and must say so explicitly.
function grug_inventory.invalidate_armor(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	armor_cache[player:get_player_name()] = nil
end

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		inv:set_size(slot.list, 1)
	end
	-- Fresh session, fresh total: the lists are loaded at this point.
	grug_inventory.invalidate_armor(player)
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
	local name = player:get_player_name()
	last_warn[name] = nil
	armor_cache[name] = nil
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
		-- Before apply_stats/refresh: those may read the armor total, and it
		-- must not answer from a stale cache.
		grug_inventory.invalidate_armor(player)
		grug_classes.apply_stats(player)
		grug_inventory.refresh(player)
	end
end)

--
-- Armor points of everything currently worn (items_crafting.md §3.1: 1 point
-- = 1% damage reduction). Read off the ITEM DEFINITION: per-stack overrides
-- through item meta are WP5's business (rolled affixes), not WP7's.
--
-- CACHED PER PLAYER. The consumer is grug_core's hp-change modifier, i.e.
-- this runs once per punch TAKEN — at the 100-player design target that is
-- ~1200 fresh ItemStack userdata per second for a value that only changes
-- when an equipment slot changes. The cache is invalidated from the three
-- places that can change it: the equipment inventory action above, a
-- server-side write via grug_inventory.invalidate_armor, and (re-)join.
--

local function compute_equipped_armor(player)
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

function grug_inventory.get_equipped_armor(player)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	local name = player:get_player_name()
	local total = armor_cache[name]
	if not total then
		total = compute_equipped_armor(player)
		armor_cache[name] = total
	end
	return total
end

-- Wire the real value into grug_core's damage pipeline (stub override, same
-- pattern as grug_classes' crit/dodge accessors). Hard cap 60% — endgame
-- plate plus shield reaches it, vendor gear never does. (grug_core clamps a
-- second time in the consumer, so a future override cannot break the
-- invariant by forgetting this line.)
function grug_core.get_armor_percent(player)
	return math.min(60, grug_inventory.get_equipped_armor(player))
end

--
-- Class change: take off what the new class may not wear.
--
-- The rank gate above lives in allow_player_inventory_action, so it can only
-- ever refuse an EQUIP — armor already worn survives a class change and the
-- filter never fires again (warrior in full metal -> /class mage keeps 49%
-- physical reduction). Admin-only today, player-reachable with WP11's respec.
--
-- grug_classes fires this after the new class is written to meta, so
-- get_armor_rank already answers for the NEW class.
--
local function piece_name(stack)
	local def = core.registered_items[stack:get_name()]
	local desc = (def and def.description) or stack:get_name()
	return (desc:gsub("\n.*", ""))
end

grug_classes.register_on_class_chosen(function(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local inv = player:get_inventory()
	if not inv then
		return
	end
	local rank = grug_classes.get_armor_rank(player)
	local removed, stuck = {}, {}
	for _, list in ipairs(ARMOR_LISTS) do
		local stack = inv:get_stack(list, 1)
		if not stack:is_empty() and
				core.get_item_group(stack:get_name(), "grug_armor_class") > rank then
			local label = piece_name(stack)
			-- add_item first, then write the LEFTOVER back into the slot: the
			-- piece is either in `main` or still in the slot, never nowhere
			-- and never on the ground (a full bag must not cost gear).
			local leftover = inv:add_item("main", stack)
			inv:set_stack(list, 1, leftover)
			if leftover:is_empty() then
				removed[#removed + 1] = label
			else
				stuck[#stuck + 1] = label
			end
		end
	end
	if #removed == 0 and #stuck == 0 then
		return
	end
	-- Server-side list writes bypass the inventory action callbacks, so the
	-- armor cache has to be dropped explicitly.
	grug_inventory.invalidate_armor(player)
	grug_classes.apply_stats(player)
	grug_inventory.refresh(player)
	local name = player:get_player_name()
	if #removed > 0 then
		core.chat_send_player(name, core.colorize("#ff9955",
			"Your new class cannot wear " .. table.concat(removed, ", ") ..
			" — moved to your inventory."))
	end
	if #stuck > 0 then
		core.chat_send_player(name, core.colorize("#ff9955",
			"Your new class cannot wear " .. table.concat(stuck, ", ") ..
			", but your inventory is full — make room and take it off."))
	end
end)
