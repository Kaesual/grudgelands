-- Equipment slots as player-inventory lists (size 1 each). Items declare
-- their slot via group (dispatch-via-groups convention), e.g. a helmet
-- carries `groups = {grug_equip_head = 1}`. The trinket slots are reserved:
-- fully functional, but no trinket items exist before post-MVP.

grug_inventory.equipment_slots = {
	{list = "grug_head", group = "grug_equip_head", label = "Head"},
	{list = "grug_chest", group = "grug_equip_chest", label = "Chest"},
	{list = "grug_legs", group = "grug_equip_legs", label = "Legs"},
	{list = "grug_feet", group = "grug_equip_feet", label = "Feet"},
	{list = "grug_weapon", group = "grug_equip_weapon", label = "Weapon"},
	{list = "grug_offhand", group = "grug_equip_offhand", label = "Offhand"},
	{list = "grug_trinket1", group = "grug_equip_trinket", label = "Trinket"},
	{list = "grug_trinket2", group = "grug_equip_trinket", label = "Trinket"},
}

-- The two "hands" lists. The item in the WEAPON slot is the single fixed
-- source of damage and appearance for every sword-type skill, the offhand
-- item the same for shield-type skills (weapon-slot design B1) -- there is
-- deliberately NO fallback to the wielded item, so an empty slot means the
-- connected skills carry no item and hit for the bare-handed baseline.
-- Family-agnostic on purpose: the slot holds whatever carries
-- `grug_equip_weapon`, which is how the future bow family joins without a
-- second slot (B3).
local WEAPON_LIST = "grug_weapon"
local OFFHAND_LIST = "grug_offhand"

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
-- Equipment caches (see grug_inventory.get_equipped_armor and
-- get_equipped_weapon at the bottom). Declared up here because both the join
-- hook and the equipment-action hook below maintain them.
--
local armor_cache = {} -- player name -> summed armor points of the 4 slots
local slot_cache = {} -- player name -> {[list] = ItemStack or false}

-- ONE call for "an equipment list was written": it drops every cache and
-- fires the equipment-change hook, in that order, so a callback already reads
-- the new state. Public because anything that writes an equipment list
-- SERVER-SIDE (the class-change unequip below, later WP11 respec / WP14
-- shields) bypasses the inventory action callbacks and must say so explicitly.
--
-- Cache and hook are deliberately NOT two separate public calls: they have the
-- same three call sites (the inventory action, a server-side list write, and
-- join), and a writer that remembered one and forgot the other would leave a
-- swapped weapon dealing the old damage until relog.
function grug_inventory.equipment_changed(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	armor_cache[name] = nil
	slot_cache[name] = nil
	grug_core.notify_equipment_change(player)
end

-- WP7 name, kept because AGENTS.md and the WP7 armor pipeline document it.
-- It now drops the weapon/offhand caches and notifies as well -- strictly more
-- than it used to do, and never less.
grug_inventory.invalidate_armor = grug_inventory.equipment_changed

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		inv:set_size(slot.list, 1)
	end
	-- Fresh session, fresh caches: the lists are loaded at this point.
	grug_inventory.equipment_changed(player)
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
	slot_cache[name] = nil
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
		-- Before apply_stats/refresh: those may read the armor total or the
		-- equipped weapon, and neither must answer from a stale cache. This is
		-- also where the equipment-change hook fires for a normal equip/swap
		-- (see grug_inventory.equipment_changed).
		grug_inventory.equipment_changed(player)
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
-- server-side write via grug_inventory.equipment_changed, and (re-)join.
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

--
-- The two hand slots (weapon-slot design B1/C4). Returns the ItemStack in the
-- slot, or nil when it is empty — an empty slot is an empty slot, there is no
-- fallback to the wielded item.
--
-- READ-ONLY for callers: this hands out the CACHED stack, not a copy (same
-- contract as grug_core.outpost_anchors). A caller that needs to modify it
-- must copy it first; writing through it would silently poison the cache.
--
-- CACHED PER PLAYER for the same reason the armor total is: the consumer is
-- the melee path, which reads the weapon once per swing (and, with the
-- auto-attack skill, continuously while a player is in combat) for a value
-- that only changes when the slot changes. The cache is dropped from the same
-- three places as the armor total — the equipment inventory action above, a
-- server-side write via grug_inventory.equipment_changed, and (re-)join.
-- `false` is the "slot is empty" entry, so an empty slot is cached too rather
-- than recomputed on every read.
--
local function cached_slot_item(player, list)
	if not player or not player.is_player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local slots = slot_cache[name]
	if not slots then
		slots = {}
		slot_cache[name] = slots
	end
	local entry = slots[list]
	if entry == nil then
		local inv = player:get_inventory()
		local stack = inv and inv:get_stack(list, 1)
		entry = (stack and not stack:is_empty()) and stack or false
		slots[list] = entry
	end
	if entry == false then
		return nil
	end
	return entry
end

function grug_inventory.get_equipped_weapon(player)
	return cached_slot_item(player, WEAPON_LIST)
end

function grug_inventory.get_equipped_offhand(player)
	return cached_slot_item(player, OFFHAND_LIST)
end

-- Wire the real value into grug_core's damage pipeline (stub override, same
-- pattern as grug_classes' crit/dodge accessors). Hard cap 60% — endgame
-- plate plus shield reaches it, vendor gear never does. (grug_core clamps a
-- second time in the consumer, so a future override cannot break the
-- invariant by forgetting this line.)
function grug_core.get_armor_percent(player)
	return math.min(60, grug_inventory.get_equipped_armor(player))
end

-- Same stub-override pattern for the two hand slots: grug_core publishes the
-- accessors so grug_abilities (skins, weapon damage) can read them without
-- depending on grug_inventory, and grug_inventory is what actually knows about
-- equipment lists.
function grug_core.get_equipped_weapon(player)
	return grug_inventory.get_equipped_weapon(player)
end

function grug_core.get_equipped_offhand(player)
	return grug_inventory.get_equipped_offhand(player)
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
	-- caches have to be dropped -- and the equipment-change hook fired --
	-- explicitly.
	grug_inventory.equipment_changed(player)
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

--
-- The weapon-slot join hint (weapon-slot design B6).
--
-- NO MIGRATION, deliberately: weapons stay perfectly valid `main` items and
-- the new slot starts empty, so nothing of anybody's is moved around behind
-- their back. The cost of that is real though — with B1's no-fallback rule an
-- existing character deals bare-hand damage until they equip — so a character
-- that has never seen the slot gets told about it once. Once ever, not once
-- per session: the flag lives in player meta, and a player who reads it and
-- decides to fight with their fists is not nagged again.
--
local WEAPON_HINT_KEY = "grug_weapon_hint"
local WEAPON_HINT_DELAY = 5 -- seconds, so it lands after the join/creation chatter

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_int(WEAPON_HINT_KEY) == 1 then
		return
	end
	local name = player:get_player_name()
	core.after(WEAPON_HINT_DELAY, function()
		local p = core.get_player_by_name(name)
		if not p then
			return
		end
		-- Re-checked here, not above: five seconds is long enough to equip
		-- something, and a player who already did needs no hint.
		if grug_inventory.get_equipped_weapon(p) then
			return
		end
		p:get_meta():set_int(WEAPON_HINT_KEY, 1)
		core.chat_send_player(name, core.colorize("#ffd100",
			"You have no weapon equipped. Open your inventory and put a weapon " ..
			"into the Weapon slot on the Character screen — your skills take " ..
			"their damage and their look from it."))
	end)
end)
