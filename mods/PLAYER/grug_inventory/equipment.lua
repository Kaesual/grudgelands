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
--
-- `listname` is optional and is passed straight through to the hook consumers
-- (see grug_core.register_on_equipment_change): the one equipment list that
-- changed, or nil for "unknown / more than one". The CACHES are always dropped
-- wholesale regardless -- two table writes are cheaper than a caller who names
-- one list and quietly wrote two.
function grug_inventory.equipment_changed(player, listname)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	armor_cache[name] = nil
	slot_cache[name] = nil
	grug_core.notify_equipment_change(player, listname)
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
-- ONE channel for every equip refusal (armor rank, two-handed rule, and
-- whatever WP5 adds), not one budget per rule: a drag is a single gesture, and
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

--
-- The two-handed rule (combat_stats.md §7, weapon-slot design B4).
--
-- One rule, one sentence: two occupied hands must add up to at most two. That
-- covers "a two-handed weapon needs an empty offhand" and "the offhand needs
-- the weapon slot empty or one-handed" at once, so both live in the one
-- group-filtered allow_put below rather than in two places that could drift.
--
-- REFUSAL, not repair: the alternative shape -- let the equip through and clear
-- the other slot from an equipment-change consumer -- is both more expensive
-- and more dangerous. A consumer that WRITES equipment re-enters the notifier,
-- which is exactly the recursion its guard exists for, and it would silently
-- move a player's torch out from under them. allow_put refuses before anything
-- moves, and refusing is the only shape that can explain itself at the moment
-- the player asks for the thing.
--
-- WHY THE MESSAGE SPELLS OUT THE TORCH (WP14): with this rule live, carrying
-- a light source costs a greataxe or staff user their weapon (§7 puts the
-- moving light radius in the offhand). §7 wants that to be a decision, not a
-- surprise, so a bare "you cannot do that" would be a bug in the design, not
-- just in the UX. grug_gear says the same thing a second time in the item
-- description, for players who never hit the refusal at all.
--

-- Hand count of an item. Anything that does not declare `_grug_hands` is
-- one-handed -- that default is what keeps the rule additive: torches, shields
-- and every future offhand item need no field at all to be legal.
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
-- built. Cheap insurance: no shipped item carries both hand groups today, but
-- the slot is family-agnostic by design (B3) and WP14 adds offhand items.
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

-- What the OTHER hand is called, for the refusal text.
local HAND_LABEL = {[WEAPON_LIST] = "weapon slot", [OFFHAND_LIST] = "offhand"}

-- true = the hands are free enough for this, false = refused (and the player
-- has been told why, throttled).
--
-- The rule is one sentence in both directions -- two occupied hands must add up
-- to at most two -- so it is tested that way rather than per target slot: the
-- incoming item may be the two-handed one, or the one already in the other hand
-- may be, and BOTH refuse (B4 says both directions). Testing only the incoming
-- stack on the way into the weapon slot would let a 1H sword join a 2H item
-- sitting in the offhand. Unconstructible today (nothing carries
-- grug_equip_offhand at all, and no item carries both hand groups), which is
-- exactly why it has to be written down rather than discovered by WP14.
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
		-- WP14: both texts promise a torch's light in the offhand, which no item
		-- delivers yet (nothing carries grug_equip_offhand, so neither branch of
		-- this rule can fire at all today). Re-read them when WP14 ships the
		-- shields and the carried light source.
		local msg
		if incoming_2h then
			msg = piece_name(stack) .. " is two-handed and needs an empty " ..
				HAND_LABEL[other_list] .. " — take " .. piece_name(other) ..
				" out first. A two-handed weapon and an offhand item (a torch's" ..
				" light, a shield) are a choice between the two, never both."
		else
			msg = piece_name(other) .. " is two-handed and leaves no hand free" ..
				" for " .. piece_name(stack) .. " — carrying a torch (or a" ..
				" shield) costs you the two-handed weapon. Equip a one-handed" ..
				" weapon to keep both."
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
		if core.get_item_group(stack:get_name(), group) == 0 then
			return 0
		end
		-- NB deliberately NO grug_req_level check anywhere in this callback:
		-- the item-level requirement is WP5's (it owns the meta key), see
		-- inventory_equipment.md §2. It belongs HERE, next to the group test,
		-- not in the armor branch below -- it gates EVERY equipment list, and
		-- for the weapon slot it is the ONLY gate (B3: weapon families are
		-- class flavor, not a power ladder, so there is no class check).
		if is_armor_list[to_list] then
			local rank = core.get_item_group(stack:get_name(), "grug_armor_class")
			if rank > 0 and rank > grug_classes.get_armor_rank(player) then
				warn_armor_class(player, rank)
				return 0
			end
		elseif to_list == WEAPON_LIST or to_list == OFFHAND_LIST then
			-- The two-handed rule, both directions (B4). Armor lists and hand
			-- lists are disjoint, hence the elseif: no equip pays for both
			-- checks. NB the rank gate above stays armor-lists-only, and there
			-- is no class gate on the weapon slot at all (B3) — a Mage may
			-- equip a greataxe and simply gains nothing from it.
			if not allow_hands(player, inventory, to_list, stack, action, info) then
				return 0
			end
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

-- Equipment changed: recompute stats (gear stats land with WP5 — the hook
-- is already the right place) and refresh an open character page.
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
-- "Once ever" is exactly why the flag must only ever be spent on a character
-- that can ACT on the hint. The naive version — fire five seconds after join
-- whenever the slot is empty — burns it on the worst possible case: a
-- brand-new character is still inside the faction → race → class formspec
-- chain at t = 5 s (grug_factions/init.lua:215-228 opens the first one at
-- t = 1 s), and the starter `default:sword_stone` is only granted inside
-- grug_factions.set_faction, so at that moment the character owns no weapon at
-- all. It would be told to equip something it does not have, while reading a
-- dialog, and would then never be told again — D2 risk 6 with the mitigation
-- switched off.
--
-- So the hint RE-ARMS instead of firing, and only goes out when all three of
-- these hold:
--   1. character creation is finished (a class is set — the last step of the
--      chain, and the point at which the formspecs are closed for good),
--   2. the weapon slot is empty,
--   3. the character actually OWNS something it could put in there.
-- Anything else leaves the meta flag untouched, so the next trigger tries
-- again. Triggers are join and "class chosen"; between them they cover the
-- fresh character (fires shortly after it picks its class, with the starter
-- sword already in the bag) and every existing one (fires on the next join).
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
	core.chat_send_player(name, core.colorize("#ffd100",
		"You have no weapon equipped. Open your inventory and put a weapon " ..
		"into the Weapon slot on the Character screen — your skills take " ..
		"their damage and their look from it."))
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
