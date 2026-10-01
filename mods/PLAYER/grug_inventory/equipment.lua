-- Equipment slots as player-inventory lists (size 1 each). Items declare
-- their slot via group (dispatch-via-groups convention), e.g. a helmet
-- carries `groups = {grug_equip_head = 1}`. The two hand slots are the
-- exception: what they take depends on the class (HAND_RULES below).

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

-- The two "hands" lists. The item in a hand slot is the single fixed source
-- of damage and appearance for the skills that read it (weapon-slot design
-- B1) -- there is deliberately NO fallback to the wielded item, so an empty
-- slot means the connected skills carry no item and hit for the bare-handed
-- baseline. Which skills read which slot depends on the class (HAND_RULES).
local WEAPON_LIST = "grug_weapon"
local OFFHAND_LIST = "grug_offhand"

--
-- The hand slots per class (Round 28 ruling 25). The two lists keep their
-- names; what each one accepts, what the Character page calls it, its ghost
-- image and which one swings for Strike and every melee skill depend on the
-- class:
--   * Warrior: a weapon of its families in Weapon, a shield in the offhand
--     (only Warriors may equip shields).
--   * Mage and Priest: a weapon of their families in Weapon, a spellbook in
--     the "Caster offhand".
--   * Scout: a bow in Weapon, shown as "Ranged", and a sword or dagger in the
--     offhand, shown as "Melee". Bow skills read Ranged, Strike, Opening and
--     every other melee skill read Melee.
-- Why: the Scout has two kinds of skills, and one weapon slot made its melee
-- skills swing with the bow. A visible per-class offhand makes each slot's
-- purpose obvious, and both slot items always count toward stats for every
-- class (grug_quality sums every equipment slot).
--
-- `families` narrows the class's weapon families (grug_gear permissions) for
-- that slot; `group` is the item group an offhand piece must carry instead.
-- `melee` names the list the melee skills swing (default: Weapon). `hint` is
-- the refusal sentence for an item that belongs elsewhere.
--
local DIM = "^[multiply:#666666"
local SWORD_GHOST = "grug_gear_item_sword_steel.png" .. DIM
local STAFF_GHOST = "grug_gear_item_staff_steel.png" .. DIM
local CASTER_RULES = {
	weapon = {label = "Weapon", ghost = STAFF_GHOST},
	offhand = {label = "Caster offhand", group = "grug_spellbook",
		ghost = "grug_gear_spellbook.png" .. DIM,
		hint = "the Caster offhand holds a spellbook"},
}
grug_inventory.HAND_RULES = {
	warrior = {
		weapon = {label = "Weapon", ghost = SWORD_GHOST},
		offhand = {label = "Shield", group = "grug_shield",
			ghost = "grug_gear_shield_steel.png" .. DIM,
			hint = "the Shield slot holds a shield"},
	},
	mage = CASTER_RULES,
	priest = CASTER_RULES,
	scout = {
		weapon = {label = "Ranged", families = {bow = true},
			ghost = "grug_gear_bow_wood.png" .. DIM,
			hint = "the Ranged slot holds a bow; a sword or dagger goes into " ..
				"the Melee slot"},
		offhand = {label = "Melee", families = {sword = true, dagger = true},
			ghost = SWORD_GHOST,
			hint = "the Melee slot holds a sword or dagger; a bow goes into " ..
				"the Ranged slot"},
		melee = OFFHAND_LIST,
	},
}
local HAND_RULES = grug_inventory.HAND_RULES

local function hand_rule(class_id, list)
	local rules = HAND_RULES[class_id]
	if not rules then return nil end
	if list == WEAPON_LIST then return rules.weapon end
	if list == OFFHAND_LIST then return rules.offhand end
	return nil
end

-- Does the hand `list` take `stack` for a character of `class_id`? Item
-- identity only; the level gate and the two-handed rule need the player and
-- the other hand and are checked in the allow callback below. A character
-- without a class takes nothing into its hands.
function grug_inventory.hand_accepts(class_id, list, stack)
	local rule = hand_rule(class_id, list)
	if not rule or not stack or stack:is_empty() then
		return false
	end
	local name = stack:get_name()
	if rule.group then
		return core.get_item_group(name, rule.group) > 0
	end
	if core.get_item_group(name, "grug_equip_weapon") == 0 or
			not grug_gear.class_can_use_weapon(class_id, stack) then
		return false
	end
	return rule.families == nil or
		rule.families[grug_gear.weapon_family(stack)] == true
end

-- The Character page's name and ghost image of a slot for this class; nil
-- for a slot whose look does not depend on the class.
function grug_inventory.slot_label(class_id, list)
	local rule = hand_rule(class_id, list)
	return rule and rule.label or nil
end

function grug_inventory.slot_ghost(class_id, list)
	local rule = hand_rule(class_id, list)
	return rule and rule.ghost or nil
end

-- The list whose item swings for Strike and every melee skill: the offhand
-- for a Scout, the Weapon slot for everyone else.
function grug_inventory.melee_list(player)
	local rules = HAND_RULES[grug_classes.get_class(player)]
	return rules and rules.melee or WEAPON_LIST
end

-- An ability's `slot` ("weapon", "offhand" or "melee") as an equipment list.
function grug_inventory.hand_list(player, slot)
	if slot == "melee" then
		return grug_inventory.melee_list(player)
	end
	return slot == "offhand" and OFFHAND_LIST or WEAPON_LIST
end

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

local OTHER_TRINKET_LIST = {
	grug_trinket1 = "grug_trinket2",
	grug_trinket2 = "grug_trinket1",
}

local function trinket_identity(stack)
	if not stack or stack:is_empty() then return nil end
	local def = core.registered_items[stack:get_name()]
	return def and def._grug_trinket_identity or nil
end

local function allow_unique_trinket(inventory, to_list, stack, action, info)
	local incoming = trinket_identity(stack)
	if not incoming then return true end
	local other_list = OTHER_TRINKET_LIST[to_list]
	local other = inventory:get_stack(other_list, 1)
	-- Moving the sole equipped stack between the two generic trinket slots
	-- vacates its source. It is not a second copy of the identity.
	if action == "move" and info.from_list == other_list and
			info.from_index == 1 and (info.count or 0) >= other:get_count() then
		return true
	end
	return trinket_identity(other) ~= incoming
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
-- SERVER-SIDE (the class-restriction unequip below, later WP14 shields)
-- bypasses the inventory action callbacks and must say so explicitly. WP11's
-- respec is NOT one of them: ruling 20 made it a full talent reset, and a
-- talent reset never unequips anything.
--
-- Cache and hook are deliberately NOT two separate public calls: they have the
-- same three call sites (the inventory action, a server-side list write, and
-- join), and a writer that remembered one and forgot the other would leave a
-- swapped weapon dealing the old damage until relog.
--
-- `listname` and `reason` are optional and pass through to hook consumers.
-- `reason = "durability_metadata"` identifies a same-stack wear/identity write;
-- consumers must still treat a broken-state transition as a concrete change.
-- (see grug_core.register_on_equipment_change): the one equipment list that
-- changed, or nil for "unknown / more than one". The CACHES are always dropped
-- wholesale regardless -- two table writes are cheaper than a caller who names
-- one list and quietly wrote two.
function grug_inventory.equipment_changed(player, listname, reason)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	armor_cache[name] = nil
	slot_cache[name] = nil
	grug_core.notify_equipment_change(player, listname, reason)
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
-- ... and at most this many DIFFERENT refusals inside one such window.
local WARN_BURST = 2
local WARN_COLOR = "#ff9955"

-- The allow callback fires repeatedly while a stack is dragged around, so the
-- refusal message has to be throttled per player or it spams the chat.
--
-- ONE channel for every equip refusal (armor rank, weapon level and two-handed
-- rule), not one budget per rule: a drag is a single gesture, and
-- per-rule budgets would just spam at N times the rate the moment the stack
-- crosses two slots on its way.
--
-- But a single channel keyed on TIME alone can swallow a refusal whole: an
-- armor-rank refusal followed within 2 s by a hands refusal used to produce
-- zero messages, and a silent refusal is strictly worse than a bare one (B4
-- makes "the refusal explains itself" a design requirement). So the channel
-- remembers WHICH refusals it already sent in the current window and lets a
-- different one through -- up to WARN_BURST of them, because two rules refusing
-- one gesture is a gesture, and a third distinct reason inside 2 s is spam.
--
-- The window is anchored at the first message and is NOT pushed forward by a
-- throttled attempt, so a held drag still ends up at one burst per 2 s.
local last_warn = {} -- player name -> {at = mono_time, sent = {reason}, n}

-- Returns the player name when this exact refusal may be sent, nil otherwise,
-- marking the send as it does so. `reason` is a cheap identity of the MESSAGE
-- (rule plus the item names it names), not of the rule: callers build the
-- message text only AFTER this returns a name, because the description lookups
-- behind these messages have no business running on every frame of a drag.
local function claim_warn(player, reason)
	local name = player:get_player_name()
	local now = grug_core.mono_time()
	local rec = last_warn[name]
	if not rec or now - rec.at >= WARN_INTERVAL then
		last_warn[name] = {at = now, sent = {[reason] = true}, n = 1}
		return name
	end
	if rec.sent[reason] or rec.n >= WARN_BURST then
		return nil
	end
	rec.sent[reason] = true
	rec.n = rec.n + 1
	return name
end

-- First line of an item's description, i.e. the display name without the item
-- level and stat lines grug_gear appends. Used by the refusals below and by
-- the class-change unequip at the bottom.
local function piece_name(stack)
	local def = core.registered_items[stack:get_name()]
	local desc = (def and def.description) or stack:get_name()
	return (desc:gsub("\n.*", ""))
end

-- The message text is the class name plus the armor class, and a character's
-- class cannot change inside one throttle window -- so the rank alone is a
-- faithful identity for it, and a cheap one.
local function warn_armor_class(player, rank)
	local name = claim_warn(player, "armor:" .. rank)
	if not name then
		return
	end
	local class_def = grug_classes.get_class_def(player)
	core.chat_send_player(name, core.colorize(WARN_COLOR,
		"A " .. (class_def and class_def.name or "character without a class") ..
		" cannot wear " .. (ARMOR_CLASS_NAME[rank] or "that") .. " armor."))
end

local function warn_weapon_level(player, stack, label, required, current)
	local reason = "level:" .. stack:get_name() .. ":" .. required
	local name = claim_warn(player, reason)
	if not name then
		return
	end
	core.chat_send_player(name, core.colorize(WARN_COLOR,
		piece_name(stack) .. " requires level " .. required ..
		" for the " .. label .. " slot; you are level " .. current .. "."))
end

-- An item the hand slot does not take. Silent for anything that is not hand
-- equipment at all (an apple dragged across the slot); otherwise the refusal
-- says where the piece belongs, or which classes may use it.
local function warn_hand_item(player, list, stack)
	local itemname = stack:get_name()
	if core.get_item_group(itemname, "grug_equip_weapon") == 0 and
			core.get_item_group(itemname, "grug_equip_offhand") == 0 then
		return
	end
	local name = claim_warn(player, "hand:" .. list .. ":" .. itemname)
	if not name then
		return
	end
	local class_id = grug_classes.get_class(player)
	local rule = hand_rule(class_id, list)
	local msg
	if core.get_item_group(itemname, "grug_equip_weapon") > 0 and
			not grug_gear.class_can_use_weapon(class_id, stack) then
		msg = "Your class cannot equip " .. piece_name(stack) .. ". " ..
			grug_gear.usable_by(stack)
	elseif rule and rule.hint then
		msg = piece_name(stack) .. " does not fit here: " .. rule.hint .. "."
	else
		msg = "Your class cannot equip " .. piece_name(stack) .. " there."
	end
	core.chat_send_player(name, core.colorize(WARN_COLOR, msg))
end

--
-- The two-handed rule (combat_stats.md §7, weapon-slot design B4).
--
-- One rule, one sentence: two occupied hands must add up to at most two. That
-- covers "a two-handed weapon needs an empty offhand" and "the offhand needs
-- the weapon slot empty or one-handed" at once, so both live in the one
-- allow callback below rather than in two places that could drift. Since
-- Round 28 only the Battle Axe and the staff are two-handed; the bow is
-- one-handed, so a Scout's Ranged and Melee slots never collide.
--
-- REFUSAL, not repair: the alternative shape -- let the equip through and clear
-- the other slot from an equipment-change consumer -- is both more expensive
-- and more dangerous. A consumer that WRITES equipment re-enters the notifier,
-- which is exactly the recursion its guard exists for, and it would silently
-- move a player's shield out from under them. The allow callback refuses
-- before anything moves, and refusing is the only shape that can explain
-- itself at the moment the player asks for the thing.
--

-- Hand count of an item. Anything that does not declare `_grug_hands` is
-- one-handed -- that default is what keeps the rule additive: shields,
-- spellbooks and every future offhand item need no field at all to be legal.
-- Accepts an ItemStack or an item name.
function grug_inventory.hands_of(item)
	local itemname = item
	if type(item) ~= "string" then
		itemname = item and item:get_name() or ""
	end
	local def = core.registered_items[itemname]
	local hands = def and def._grug_hands
	if type(hands) == "number" and hands >= 2 then
		return 2
	end
	return 1
end

-- The stack in the OTHER hand slot AS THIS ACTION WOULD LEAVE IT. A move whose
-- source is that slot empties it, and refusing against a stack the same action
-- is about to remove is how "my staff can never leave the offhand" bugs are
-- built.
local function other_hand_stack(inventory, other_list, action, info)
	local stack = inventory:get_stack(other_list, 1)
	if stack:is_empty() then
		return stack
	end
	if action == "move" and info.from_list == other_list and
			info.from_index == 1 and (info.count or 0) >= stack:get_count() then
		return ItemStack("")
	end
	return stack
end

-- true = the hands are free enough for this, false = refused (and the player
-- has been told why, throttled). Tested in both directions: the incoming item
-- may be the two-handed one, or the one already in the other hand may be.
local function allow_hands(player, inventory, to_list, stack, action, info)
	local other_list = (to_list == WEAPON_LIST) and OFFHAND_LIST or WEAPON_LIST
	local other = other_hand_stack(inventory, other_list, action, info)
	if other:is_empty() then
		return true -- the other hand is free: nothing to cross-check
	end
	local incoming_2h = grug_inventory.hands_of(stack) >= 2
	local held_2h = grug_inventory.hands_of(other) >= 2
	if not incoming_2h and not held_2h then
		return true -- one hand each: they fit
	end
	-- Only item NAMES here, no description lookups: this runs on every frame of
	-- a drag, and the text below runs only when the throttle lets it.
	local reason = incoming_2h
		and ("hands:incoming:" .. stack:get_name() .. ":" .. other:get_name())
		or ("hands:held:" .. other:get_name() .. ":" .. stack:get_name())
	local name = claim_warn(player, reason)
	if name then
		local label = grug_inventory.slot_label(grug_classes.get_class(player),
			other_list) or "other hand"
		local msg
		if incoming_2h then
			msg = piece_name(stack) .. " is two-handed and needs an empty " ..
				label .. " slot — take " .. piece_name(other) .. " out first." ..
				" A two-handed weapon and an offhand item are a choice between" ..
				" the two, never both."
		else
			msg = piece_name(other) .. " is two-handed and leaves no hand free" ..
				" for " .. piece_name(stack) .. " — equip a one-handed weapon to" ..
				" carry both."
		end
		core.chat_send_player(name, core.colorize(WARN_COLOR, msg))
	end
	return false
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
		if to_list == WEAPON_LIST or to_list == OFFHAND_LIST then
			-- The hands follow the class rules (ruling 25), not one group.
			local class_id = grug_classes.get_class(player)
			if not grug_inventory.hand_accepts(class_id, to_list, stack) then
				warn_hand_item(player, to_list, stack)
				return 0
			end
			if core.get_item_group(stack:get_name(), "grug_equip_weapon") > 0 then
				local allowed, required, current =
					grug_core.can_use_item_level(player, stack)
				if not allowed then
					warn_weapon_level(player, stack,
						grug_inventory.slot_label(class_id, to_list) or "Weapon",
						required, current)
					return 0
				end
			end
		elseif core.get_item_group(stack:get_name(), group) == 0 then
			return 0
		end
		if is_armor_list[to_list] then
			local rank = core.get_item_group(stack:get_name(), "grug_armor_class")
			if rank > 0 and rank > grug_classes.get_armor_rank(player) then
				warn_armor_class(player, rank)
				return 0
			end
		elseif to_list == WEAPON_LIST or to_list == OFFHAND_LIST then
			-- The two-handed rule, both directions (B4). Armor lists and hand
			-- lists are disjoint, hence the elseif: no equip pays for both
			-- checks. The class slot rules were checked above.
			if not allow_hands(player, inventory, to_list, stack, action, info) then
				return 0
			end
		elseif OTHER_TRINKET_LIST[to_list] and
				not allow_unique_trinket(inventory, to_list, stack, action, info) then
			return 0
		end
		return 1 -- slots hold exactly one item
	end
	-- Not our list: return nil so later allow callbacks still run (the
	-- engine combines them with OR + short-circuit — a number here would
	-- swallow every other mod's check).
end)

-- Which equipment list did this action touch? Returns the list name, or false
-- when none was involved. `true` means "two DIFFERENT equipment lists" (a drag
-- straight from one slot into another), which the hook reports as nil =
-- "unknown, assume everything".
local function touched_equipment_list(action, info)
	if action ~= "move" then
		return slot_group[info.listname] and info.listname or false
	end
	local from = slot_group[info.from_list] and info.from_list
	local to = slot_group[info.to_list] and info.to_list
	if from and to then
		return (from == to) and from or true
	end
	return from or to or false
end

-- Equipment changed: the single notifier invalidates caches, recomputes
-- stats through its first consumer and refreshes the page through the one
-- pages.lua consumer. Do not duplicate either update after this call.
core.register_on_player_inventory_action(function(player, action, inventory, info)
	local touched = touched_equipment_list(action, info)
	if touched then
		-- `true` is the "two lists at once" marker, which the hook spells nil.
		local listname = (touched ~= true) and touched or nil
		-- Before apply_stats/refresh: those may read the armor total or the
		-- equipped weapon, and neither must answer from a stale cache. This is
		-- also where the equipment-change hook fires for a normal equip/swap
		-- (see grug_inventory.equipment_changed).
		grug_inventory.equipment_changed(player, listname)
	end
end)

--
-- Base armor rating of the four worn armor pieces (combat_stats.md §2
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
		if not stack:is_empty() and not grug_core.equipment_is_broken(stack) then
			local def = core.registered_items[stack:get_name()]
			local armor = def and def._grug_armor
			local gear = rawget(_G, "grug_gear")
			if gear and gear.describe_stack_base then
				local ilvl = stack:get_meta():get_int("grug_ilvl")
				if ilvl <= 0 then ilvl = def and def._grug_ilvl end
				local _, stats = gear.describe_stack_base(stack, ilvl)
				armor = stats.armor or armor
			end
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
-- The caller GETS A COPY and may do whatever it likes with it. The cache holds
-- the private original; every read constructs a fresh ItemStack from it, so
-- `w:add_wear(n)` (WP22 durability), `w:get_meta():set_*` (a WP5 affix
-- re-roll, a description tooltip) cannot desync the cache from the list.
--
-- The obvious alternative — handing out the cached stack, the way the armor
-- cache's rationale would suggest — was rejected deliberately: the armor total
-- is read once per punch TAKEN (~1200/s at the 100-player target), the weapon
-- once per swing MADE (~100/s, even with T3's auto-attack). One ItemStack
-- userdata per 10 ms does not buy a footgun whose failure mode is invisible:
-- a write through the shared stack goes through no tracked path at all, so no
-- invalidation site could ever detect it.
--
-- The rule that comes with the copy: to actually CHANGE the equipment, write
-- the modified stack back into the list and call
-- grug_inventory.equipment_changed(player, list).
--
-- Still CACHED PER PLAYER, because the expensive half is the inventory read,
-- not the copy: the consumer is the melee path, which reads the weapon once
-- per swing (and, with the auto-attack skill, continuously while a player is
-- in combat) for a value that only changes when the slot changes. The cache is
-- dropped from the same three places as the armor total — the equipment
-- inventory action above, a server-side write via
-- grug_inventory.equipment_changed, and (re-)join. `false` is the "slot is
-- empty" entry, so an empty slot is cached too rather than recomputed on every
-- read.
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
	-- ItemStack(<ItemStack>) is a real copy, metadata included
	-- (src/script/common/c_content.cpp:1411-1415 returns the stack BY VALUE).
	return ItemStack(entry)
end

-- Cosmetic accessors include broken equipment; callers receive owned copies.
function grug_inventory.get_cosmetic_weapon(player)
	return cached_slot_item(player, WEAPON_LIST)
end

function grug_inventory.get_cosmetic_offhand(player)
	return cached_slot_item(player, OFFHAND_LIST)
end

function grug_inventory.get_equipped_weapon(player)
	local stack = cached_slot_item(player, WEAPON_LIST)
	return stack and grug_gear.can_equip_weapon(player, stack) and
		not grug_core.equipment_is_broken(stack) and stack or nil
end

function grug_inventory.get_equipped_offhand(player)
	local stack = cached_slot_item(player, OFFHAND_LIST)
	return stack and not grug_core.equipment_is_broken(stack) and stack or nil
end

-- The item Strike and every melee skill swing (ruling 25): the Scout's Melee
-- slot, everyone else's Weapon slot. nil = bare hand.
function grug_inventory.get_melee_weapon(player)
	local stack = cached_slot_item(player, grug_inventory.melee_list(player))
	return stack and grug_gear.can_equip_weapon(player, stack) and
		not grug_core.equipment_is_broken(stack) and stack or nil
end

-- The cosmetic item behind an ability's `slot` ("weapon", "offhand" or
-- "melee"); broken equipment included, like the other cosmetic accessors.
function grug_inventory.get_cosmetic_hand(player, slot)
	return cached_slot_item(player, grug_inventory.hand_list(player, slot))
end

-- Base fallback until grug_quality adds shield and affix rating.
function grug_core.get_armor_rating(player)
	local base = grug_inventory.get_equipped_armor(player)
		+ grug_classes.get_talent_bonus(player, "armor_percent_add")
		+ grug_core.status_modifier_sum(player, "armor")
	local multiplier = grug_classes.talent_rank(player, "unbroken") > 0
		and grug_core.PROTECTION_ARMOR_MULTIPLIER or 1
	return base * multiplier + grug_classes.get_talent_bonus(player,
		"armor_rating_add_low_hp")
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

function grug_core.get_melee_weapon(player)
	return grug_inventory.get_melee_weapon(player)
end

--
-- Class restriction: take off what the character's class may not wear.
--
-- The rank gate above lives in allow_player_inventory_action, so it can only
-- ever refuse an EQUIP — armor already worn would survive a class change and
-- the filter would never fire again (warrior in full metal keeping 49%
-- physical reduction as a mage). Ruling 20 (2026-09-16, skill_trees.md §1.4)
-- removed class changing from the game entirely, admins included, so this
-- path has no caller left and the WP11 respec will NOT give it one: a respec
-- re-spends talents and never touches equipment. It is kept deliberately —
-- it is the guard that makes the rank rule true if anything ever writes an
-- equipment list directly.
--
-- grug_classes fires this after a class is written to meta, so
-- get_armor_rank already answers for that class.
--
-- (piece_name lives up with the refusal messages, which need the same thing.)

grug_classes.register_on_class_chosen(function(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local inv = player:get_inventory()
	if not inv then
		return
	end
	local rank = grug_classes.get_armor_rank(player)
	local class_id = grug_classes.get_class(player)
	local removed, stuck = {}, {}
	local restricted_lists = {WEAPON_LIST, OFFHAND_LIST}
	for _, list in ipairs(ARMOR_LISTS) do restricted_lists[#restricted_lists + 1] = list end
	for _, list in ipairs(restricted_lists) do
		local stack = inv:get_stack(list, 1)
		local hand = list == WEAPON_LIST or list == OFFHAND_LIST
		local disallowed = hand and
			not grug_inventory.hand_accepts(class_id, list, stack) or
			not hand and
			core.get_item_group(stack:get_name(), "grug_armor_class") > rank
		if not stack:is_empty() and disallowed then
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
	-- Server-side list writes bypass the inventory action callbacks. A class
	-- change not moving an item still reaches the hook once: derived
	-- stats and the Character page changed even if all worn gear remained
	-- legal. This is the sole Character-page refresh and equipment-derived
	-- stat update source; set_class's one heal-gain application is separate.
	grug_inventory.equipment_changed(player)
	if #removed == 0 and #stuck == 0 then
		return
	end
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
-- THE STARTER WEAPON (playtest round 2, 2026-09-15).
--
-- It used to be one line of grug_factions' faction kit: every character, of
-- every class, got a `default:sword_stone` in `main` at the moment it picked a
-- faction. Two things were wrong with that, and both are rulings now.
--
-- 1. **A Priest and a Mage start with a staff, a Warrior with a sword.** The
--    faction kit cannot express that, because a character has no class yet
--    when it chooses its faction -- the chain is faction -> race -> class. So
--    the weapon moved off the faction kit (which keeps the torches and the
--    apples) and onto the class, here.
-- 2. **It goes into the WEAPON SLOT, not into the bag.** With the no-fallback
--    rule (inventory_equipment.md §2) a weapon in `main` drives nothing at all:
--    no damage, no ability skin, nothing in the character's hand. A brand-new
--    character was therefore bare-handed and invisible-handed until it found
--    the Character screen. Writing the slot server-side and going through
--    `grug_inventory.equipment_changed` is what makes the ability skins
--    (grug_abilities) and the visible weapon (grug_visuals) follow -- it is the
--    same notification a manual equip fires.
--
-- Exactly once per character, tracked in player meta. Ruling 20 removed the
-- class change that used to make this matter (a Warrior could not become a
-- Mage and be handed a staff); the once-per-character rule stays because the
-- grant also runs on every join.
--
-- Two-handed: the starter staff IS two-handed (grug_gear), so the grant obeys
-- the same rule the equip filter does and refuses an occupied offhand rather
-- than creating a state the player could not have reached by hand.
--
-- The Scout (Round 28 ruling 25/26) gets its bow in Ranged, its Bronze Sword in
-- Melee and its starter arrows in the quiver.
--
local STARTER_WEAPON_KEY = "grug_starter_weapon"

-- Published, because it is content rather than mechanism: the audit below reads
-- it, and a
-- later class ships its own line here rather than a second table somewhere.
grug_inventory.STARTER_WEAPON = {
	warrior = grug_gear.STARTER_SWORD,
	mage = grug_gear.STARTER_STAFF,
	priest = grug_gear.STARTER_STAFF,
	scout = grug_gear.STARTER_BOW,
}
-- The offhand piece a class starts with, where it has one.
grug_inventory.STARTER_OFFHAND = {
	scout = grug_gear.STARTER_SWORD,
}
grug_inventory.STARTER_ARROWS = {
	scout = 200,
}
local CLASS_STARTER_WEAPON = grug_inventory.STARTER_WEAPON

-- Put `stack` into the hand `list` when the class rules and the other hand
-- allow it, or into `main` when the slot cannot take it. Returns "slot",
-- "main" or nil (nothing anywhere -- a full bag).
local function place_starter_item(player, inv, stack, list)
	local other_list = list == WEAPON_LIST and OFFHAND_LIST or WEAPON_LIST
	local other = inv:get_stack(other_list, 1)
	local free_hands = other:is_empty() or (grug_inventory.hands_of(stack) < 2 and
		grug_inventory.hands_of(other) < 2)
	if free_hands and inv:get_stack(list, 1):is_empty() and
			grug_inventory.hand_accepts(grug_classes.get_class(player), list, stack) then
		inv:set_stack(list, 1, stack)
		return "slot"
	end
	if inv:room_for_item("main", stack) then
		inv:add_item("main", stack)
		return "main"
	end
	return nil
end

local function item_label(itemname)
	local def = core.registered_items[itemname]
	return ((def and def.description) or itemname):gsub("\n.*", "")
end

grug_classes.register_on_class_chosen(function(player, class_id)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local meta = player:get_meta()
	if meta:get_int(STARTER_WEAPON_KEY) == 1 then
		return
	end
	local itemname = CLASS_STARTER_WEAPON[class_id]
	if not itemname or not core.registered_items[itemname] then
		return -- a class without a starter weapon stays armed for a later one
	end
	local inv = player:get_inventory()
	if not inv then
		return
	end
	-- The flag is spent only on a character that actually received something,
	-- for the same reason the join hint below re-arms: a full bag at character
	-- creation is not the player's fault.
	local where = place_starter_item(player, inv, ItemStack(itemname), WEAPON_LIST)
	if not where then
		return
	end
	meta:set_int(STARTER_WEAPON_KEY, 1)
	local name = player:get_player_name()
	local function say(item, list, placed)
		local label = grug_inventory.slot_label(class_id, list) or "Weapon"
		local where_text = placed == "slot"
			and (" is equipped in the " .. label .. " slot — your skills take " ..
				"their damage and their look from it.")
			or ((placed == "main" and " is in your inventory" or " lies at your feet") ..
				"; equip it in the " .. label .. " slot on the Character screen.")
		core.chat_send_player(name, core.colorize("#ffd100",
			"Your " .. item_label(item) .. where_text))
	end
	say(itemname, WEAPON_LIST, where)
	-- The class selection inventory is normally empty. Keep the fallbacks
	-- lossless nevertheless: a full inventory drops the owed starter item at
	-- the player instead of silently deleting it.
	local offhand = grug_inventory.STARTER_OFFHAND[class_id]
	if offhand and core.registered_items[offhand] then
		local placed = place_starter_item(player, inv, ItemStack(offhand), OFFHAND_LIST)
		if not placed then
			core.add_item(player:get_pos(), ItemStack(offhand))
		end
		say(offhand, OFFHAND_LIST, placed)
	end
	local arrows = grug_inventory.STARTER_ARROWS[class_id]
	if arrows then
		local leftover = grug_inventory.add_to_quiver(player,
			ItemStack("grug_gear:arrow " .. arrows))
		leftover = inv:add_item("main", leftover)
		if not leftover:is_empty() then
			core.add_item(player:get_pos(), leftover)
		end
	end
	-- Server-side equipment write: caches, stats, ability skins, the
	-- Character page and the visible weapon all hang off this one call.
	grug_inventory.equipment_changed(player)
end)

-- Startup audit, the grug_traders pattern: one action line when clean, a loud
-- error otherwise. Every failure it can find is a CONTENT failure that no test
-- outside the engine sees -- a class added without a starter weapon or hand
-- rules, a starter item whose item another mod curated away, or one the slot
-- rules would refuse the moment the grant above wrote it into the slot.
core.register_on_mods_loaded(function()
	local report, broken = {}, {}
	local function audit(class_id, itemname, list)
		if not core.registered_items[itemname] then
			broken[#broken + 1] = class_id .. "'s " .. itemname ..
				" is not a registered item"
		elseif not grug_inventory.hand_accepts(class_id, list, ItemStack(itemname)) then
			broken[#broken + 1] = class_id .. "'s " .. itemname ..
				" cannot go into the " .. list .. " slot"
		else
			report[#report + 1] = class_id .. "=" .. itemname ..
				(grug_inventory.hands_of(itemname) >= 2 and " (2H)" or "")
		end
	end
	for _, class_id in ipairs(grug_classes.class_ids) do
		local itemname = CLASS_STARTER_WEAPON[class_id]
		if not HAND_RULES[class_id] then
			broken[#broken + 1] = class_id .. " has no hand slot rules"
		elseif not itemname then
			broken[#broken + 1] = class_id .. " has no starter weapon"
		else
			audit(class_id, itemname, WEAPON_LIST)
			local offhand = grug_inventory.STARTER_OFFHAND[class_id]
			if offhand then audit(class_id, offhand, OFFHAND_LIST) end
		end
	end
	if #broken > 0 then
		table.sort(broken)
		core.log("error", "[grug_inventory] starter weapons: " ..
			table.concat(broken, "; "))
	end
	table.sort(report)
	core.log("action", "[grug_inventory] starter weapons: " ..
		table.concat(report, ", "))
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
-- SINCE PLAYTEST ROUND 2 A FRESH CHARACTER NEVER SEES IT: the class-keyed
-- grant above fills the weapon slot the moment the class is chosen, so
-- condition 2 below fails and the flag is never spent. The hint survives for
-- the case it was written for -- a character that has a slot-eligible weapon in
-- its bag and an empty slot, which is now reached by losing or unequipping one
-- rather than by being created.
--
-- "Once ever" is exactly why the flag must only ever be spent on a character
-- that can ACT on the hint. The naive version — fire five seconds after join
-- whenever the slot is empty — burns it on the worst possible case: a
-- brand-new character is still inside the faction → race → class formspec
-- chain at t = 5 s (grug_factions/init.lua opens the first one at t = 1 s) and
-- owns nothing at all. It would be told to equip something it does not have,
-- while reading a dialog, and would then never be told again — D2 risk 6 with
-- the mitigation switched off.
--
-- So the hint RE-ARMS instead of firing, and only goes out when all three of
-- these hold:
--   1. character creation is finished (a class is set — the last step of the
--      chain, and the point at which the formspecs are closed for good),
--   2. the weapon slot is empty,
--   3. the character actually OWNS something it could put in there.
-- Anything else leaves the meta flag untouched, so the next trigger tries
-- again. Triggers are join and "class chosen"; between them they cover every
-- character that owns a weapon it has not equipped.
-- A character that owns no weapon at all stays armed across sessions until it
-- buys one — which is the right moment for the advice anyway.
--
local WEAPON_HINT_KEY = "grug_weapon_hint"
local WEAPON_HINT_DELAY = 5 -- seconds, so it lands after the join/creation chatter

-- Condition 3. `main` only: bags are storage, the hint is about the item the
-- player is carrying around.
local function owns_slot_eligible_weapon(player)
	local inv = player:get_inventory()
	if not inv then
		return false
	end
	local weapon_group = slot_group[WEAPON_LIST]
	local list = inv:get_list("main") or {}
	for i = 1, #list do
		local stack = list[i]
		if not stack:is_empty() and
				core.get_item_group(stack:get_name(), weapon_group) > 0 then
			return true
		end
	end
	return false
end

local function try_weapon_hint(name)
	local player = core.get_player_by_name(name)
	if not player then
		return
	end
	-- The meta flag is re-read HERE, not only at the trigger: two triggers can
	-- be in flight at once (leave and rejoin inside the delay, or join
	-- immediately followed by the class pick), and without this re-read the
	-- hint is sent twice.
	local meta = player:get_meta()
	if meta:get_int(WEAPON_HINT_KEY) == 1 then
		return
	end
	if not grug_classes.get_class(player) then
		return -- still in character creation: stay armed
	end
	if grug_inventory.get_equipped_weapon(player) then
		return -- nothing to say, and the flag is not spent on saying it
	end
	if not owns_slot_eligible_weapon(player) then
		return -- nothing to equip yet: stay armed
	end
	meta:set_int(WEAPON_HINT_KEY, 1)
	local label = grug_inventory.slot_label(grug_classes.get_class(player),
		WEAPON_LIST) or "Weapon"
	core.chat_send_player(name, core.colorize("#ffd100",
		"You have no weapon equipped. Open your inventory and put a weapon " ..
		"into the " .. label .. " slot on the Character screen — your skills " ..
		"take their damage and their look from it."))
end

local function arm_weapon_hint(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	if player:get_meta():get_int(WEAPON_HINT_KEY) == 1 then
		return
	end
	local name = player:get_player_name()
	core.after(WEAPON_HINT_DELAY, function()
		try_weapon_hint(name)
	end)
end

core.register_on_joinplayer(arm_weapon_hint)

-- The other trigger: the fresh character, the moment it stops being fresh.
-- grug_classes fires this after the class is written to meta, so
-- grug_classes.get_class already answers inside the delayed check.
grug_classes.register_on_class_chosen(arm_weapon_hint)

-- A weapon carried on the hotbar is storage, not the combat authority. Watch
-- the player's ordinary use control without consuming it or changing any item
-- callback, damage path or equip state, and explain the intended route once
-- per press with a small anti-spam interval.
local raw_weapon_controls = {}
local RAW_WEAPON_HINT_INTERVAL = 3
local raw_weapon_elapsed = 0

core.register_globalstep(function(dtime)
	raw_weapon_elapsed = raw_weapon_elapsed + dtime
	if raw_weapon_elapsed < 0.1 then return end
	raw_weapon_elapsed = raw_weapon_elapsed % 0.1
	local now = grug_core.mono_time()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local row = raw_weapon_controls[name] or {pressed = false, warned = -1000}
		local pressed = player:get_player_control().dig == true
		local wielded = player:get_wielded_item()
		if pressed and not row.pressed and not wielded:is_empty() and
				core.get_item_group(wielded:get_name(), "grug_equip_weapon") > 0 and
				now - row.warned >= RAW_WEAPON_HINT_INTERVAL then
			core.chat_send_player(name, core.colorize("#ffd100",
				"Weapons work from the hand slots on the Character page. Equip " ..
				"this weapon there, then use a combat skill from your hotbar."))
			row.warned = now
		end
		row.pressed = pressed
		raw_weapon_controls[name] = row
	end
end)

core.register_on_leaveplayer(function(player)
	raw_weapon_controls[player:get_player_name()] = nil
end)
