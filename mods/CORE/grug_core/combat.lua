-- Protection specialization preserves the top-tank target without refinement.
grug_core.PROTECTION_ARMOR_MULTIPLIER = 1.65

-- Damage pipeline & combat state (docs/design/classes.md §2,
-- combat_stats.md §2/§4). Ability damage and heals run through the helpers
-- here so crit/dodge rolls and threat live in one place. WP6 replaced the
-- WP4 threat stubs with the real threat table below.

--
-- Stat accessors. Stubs so grug_core stays free of player-mod dependencies;
-- grug_classes overrides them at load time (same pattern as
-- grug_core.get_player_faction).
--

function grug_core.get_crit_chance(player)
	return 0
end

function grug_core.get_dodge_chance(player)
	return 0
end

-- Player level without a reverse dependency on grug_xp. The XP mod replaces
-- this stub after it loads, like the class and faction accessors around it.
function grug_core.get_player_level(player)
	return 1
end

-- Mounted combat stays a Core-side query so the ability mod does not need a
-- reverse dependency on grug_mounts.  The rider marker is live runtime state:
-- an arbitrary attachment, a stale object or somebody else's mount is not a
-- mounted player.
-- Combat notices (this refusal, "You dodge!") go to the message feed in grey,
-- never to chat; each keeps one keyed line that a repeat refreshes.
local mounted_refusal_notice = {}

function grug_core.player_has_live_mount(player)
	if not (player and player.get_attach) then return false end
	local object = player:get_attach()
	if not object or not object.is_valid or not object:is_valid() then
		return false
	end
	local entity = object:get_luaentity()
	return entity ~= nil and entity._grug_rider == player
end

function grug_core.refuse_mounted_attack(player)
	if not grug_core.player_has_live_mount(player) then return false end
	local name = player:get_player_name()
	local object = player:get_attach()
	local now = core.get_us_time()
	local notice = mounted_refusal_notice[name]
	if not notice or notice.object ~= object or now - notice.at >= 1000000 then
		grug_core.feed(player, "combat", "Dismount before attacking.", "combat:mounted")
		mounted_refusal_notice[name] = {object = object, at = now}
	end
	return true
end

core.register_on_leaveplayer(function(player)
	mounted_refusal_notice[player:get_player_name()] = nil
end)

-- Shared minimum-level decision for every item-backed gate. Gear, food and
-- future potions/elixirs all publish `_grug_ilvl`; callers own only their
-- context-specific refusal text.
function grug_core.can_use_item_level(player, item)
	local item_name = item
	if type(item) ~= "string" then
		item_name = item and item.get_name and item:get_name() or ""
	end
	local definition = core.registered_items[item_name]
	local required = definition and (definition._grug_req_level or definition._grug_ilvl)
	if type(required) ~= "number" or required <= 0 then
		return true, nil, grug_core.get_player_level(player)
	end
	required = math.floor(required)
	local current = grug_core.get_player_level(player)
	return current >= required, required, current
end

-- Class-neutral level pool. Player HP, caster mana, healing and absorbs all
-- derive from this same rounded curve (combat_stats.md sections 1-2). Keeping
-- it in Core also lets the damage and pressure fits use the exact same bytes.
function grug_core.base_pool(level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
end

-- The baseline one-handed weapon and primary melee attribute at a level.
-- This is a FIT REFERENCE, not an equipped item lookup: own-level baseline
-- gear plus the Warrior's automatic Strength growth defines the eight-second
-- same-level normal-mob row. Real gear and attributes remain the numerator.
function grug_core.baseline_weapon_damage(level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	return math.floor(4 + 0.35 * level + 0.5)
end

-- The Strength term keeps its fraction like live melee damage since Round 33
-- (grug_classes.get_melee_bonus), so same-level damage meets the fit exactly
-- (Round 34 ruling 6). Public as "a base hit" before the scalar: level-proof
-- talent values are percentages of it (grug_classes/talents.lua, Round 35).
function grug_core.baseline_melee_total(level)
	local strength = 10 + 3 * (level - 1)
	return grug_core.baseline_weapon_damage(level) + strength / 10
end

-- Damage-only level fit. Support values and percentage consumables have
-- already derived an absolute amount from a current-level pool and therefore
-- bypass this multiplier through scale_player_value below. Applying this fit
-- to such an amount would square the level progression.
function grug_core.level_scale(level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	return grug_core.base_pool(level) / (8 * grug_core.baseline_melee_total(level))
end

-- Higher-level mobs resist players who are more than five levels below them:
-- -10 percentage points per further level, with a 10% floor.
function grug_core.level_malus(player_level, mob_level)
	local excess = math.floor(tonumber(mob_level) or 1)
		- (math.floor(tonumber(player_level) or 1) + 5)
	if excess <= 0 then
		return 1
	end
	return math.max(0.1, 1 - 0.1 * excess)
end

-- Support and consumable amounts arrive here after deriving their absolute
-- value from a current-level HP/base pool. This identity seam is deliberately
-- retained so heal_player/add_absorb keep their stable structure while making
-- a second level multiplication impossible.
function grug_core.scale_player_value(player, amount)
	return math.max(0, amount or 0)
end

-- Player damage adds the target-level malus after the shared level scalar.
-- The one final floor keeps multiplication order from creating two rounding
-- losses. Players have no mob level and therefore receive no malus.
function grug_core.scale_player_damage(player, target, amount)
	local mult = grug_core.level_scale(grug_core.get_player_level(player))
	if target and not target:is_player() then
		local ent = target:get_luaentity()
		if ent and ent._grug_level then
			mult = mult * grug_core.level_malus(
				grug_core.get_player_level(player), ent._grug_level)
		end
	end
	amount = amount or 0
	if amount <= 0 then
		return 0
	end
	return math.max(1, math.floor(amount * mult))
end

-- Same-level raw mob pressure is fitted to 27 seconds against the neutral
-- pool before class factor, dodge, armor, absorb or healing. The mob's own
-- HP/damage curves remain untouched; this is player-side intake scaling.
function grug_core.mob_pressure_scale(level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	local mob_damage = 2 + 0.3 * level + 0.005 * level * level
	-- HP changes settle as integer points. Target the largest whole hit that
	-- still leaves at least 27 neutral-pool hits; the tiny subtraction keeps
	-- ceil(raw * scale) on that integer in both supported interpreters.
	local fitted_hit = math.max(1,
		math.floor(grug_core.base_pool(level) / 27))
	return (fitted_hit - 0.000001) / mob_damage
end

-- Compact integer display shared by mob nametags and the Target Frame.
-- Four-digit values keep one truncated decimal; five digits and above round
-- to the nearest thousand. Truncating 9999 to 9.9k preserves the 10k boundary.
function grug_core.format_k(value)
	local number = tonumber(value) or 0
	local sign = number < 0 and "-" or ""
	number = math.floor(math.abs(number) + 0.5)
	if number < 1000 then
		return sign .. tostring(number)
	end
	if number < 10000 then
		return sign .. string.format("%.1fk", math.floor(number / 100) / 10)
	end
	return sign .. tostring(math.floor(number / 1000 + 0.5)) .. "k"
end

-- Raw player armor rating. grug_inventory overrides this stub after equipment
-- and quality load; Core owns only the attacker-level reduction curve.
function grug_core.get_armor_rating(player)
	return 0
end

-- Equipment consumers share the non-destructive broken sentinel. Eligibility
-- remains owned by the caller, so ability-token wear bars never enter here.
function grug_core.equipment_is_broken(stack)
	return stack and stack.get_wear and stack:get_wear() >= 65535 or false
end

function grug_core.armor_k(attacker_level)
	local level = math.max(1, tonumber(attacker_level) or 1)
	return 20 + 0.5 * math.min(level, 60) +
		8.5 * math.max(level - 60, 0)
end

function grug_core.armor_reduction(raw_rating, attacker_level, cap)
	local rating = math.max(0, tonumber(raw_rating) or 0)
	if rating <= 0 then return 0 end
	local reduction = rating / (rating + grug_core.armor_k(attacker_level))
	return math.min(tonumber(cap) or 0.70, reduction)
end

-- PvP melee applies armor itself (custom type below) and floors once after
-- it; without a reduction the damage passes unrounded.
function grug_core.apply_player_armor(player, damage, attacker_level)
	local reduction = grug_core.armor_reduction(
		grug_core.get_armor_rating(player), attacker_level, 0.70)
	if reduction > 0 then
		return math.ceil(damage * (1 - reduction))
	end
	return damage
end

-- Official PlayerHPChangeReason.custom_type for damage on which the caller
-- already applied the helper above. The central modifier skips ONLY armor for
-- this reason; dodge, combat marking, absorbs and later callbacks still run.
grug_core.ARMOR_APPLIED_CUSTOM_TYPE = "grug_core:player_armor_applied"

--
-- The equipment seam (weapon-slot design C4). grug_abilities needs to know
-- what is in the two hand slots and when it changes; grug_inventory owns the
-- slots. Neither depends on the other, so the contract lives here.
--
-- get_equipped_weapon/get_equipped_offhand are STUBS returning nil (same
-- pattern as get_armor_rating above) -- nil means "empty slot", and an empty
-- slot has no fallback to the wielded item (B1): the connected skills carry no
-- item and hit for the bare-handed baseline. grug_inventory overrides both
-- with a per-player cached read.
--
-- The returned ItemStack is the CALLER'S OWN COPY. grug_inventory caches the
-- slot contents, but every read hands out a fresh ItemStack, so a consumer may
-- read its meta, wear it, re-roll it -- nothing it does can poison the cache.
-- The flip side is the rule that buys that safety: a modified copy is NOT
-- equipped until it is written back into the list AND
-- grug_inventory.equipment_changed is called (WP22's durability, WP5's affix
-- re-roll). Writing back without that leaves the cache reporting the old item.
--

function grug_core.get_equipped_weapon(player)
	return nil
end

function grug_core.get_equipped_offhand(player)
	return nil
end

-- The item Strike and every melee skill swing (Round 28 ruling 25): the
-- Scout's Melee slot (its offhand), everyone else's Weapon slot. Same stub
-- pattern; nil = bare hand.
function grug_core.get_melee_weapon(player)
	return grug_core.get_equipped_weapon(player)
end

-- The hit sound of a player's melee swing (Round 34 S1b): the grug_sounds
-- event of the equipped melee weapon's kind, the bare hand's punch without
-- one. Swords and battle axes cut, daggers cut lighter; staffs and wands
-- strike blunt.
local HIT_SOUNDS = {sword = "hit_blade", dagger = "hit_dagger",
	greataxe = "hit_blade", staff = "hit_blunt", wand = "hit_blunt"}

function grug_core.melee_hit_sound(player)
	local weapon = grug_core.get_melee_weapon(player)
	local def = weapon and not weapon:is_empty() and weapon:get_definition()
	return def and HIT_SOUNDS[def._grug_weapon_family] or "hit_fist"
end

-- Fired whenever a player's equipment MAY have changed: an equip/swap through
-- the character screen, a server-side write to one of the lists (the
-- class-change unequip), and (re-)join.
--
--     func(player, listname)
--
-- `listname` is the ONE equipment list that changed, or **nil** for "unknown,
-- assume everything moved" (join, a class-change unequip touching several
-- slots, any caller that cannot name a single list). It exists so a consumer
-- can bail out early: the ability-skin sync (T2) only cares about
-- grug_weapon/grug_offhand and must not walk 32 `main` stacks every time a
-- trinket is dragged. A consumer that ignores the argument stays correct.
--
-- Consumers must be idempotent and cheap -- this is what rewrites the ability
-- item skins, and every inventory write re-sends the list to the client.
local equipment_change_callbacks = {}

function grug_core.register_on_equipment_change(func)
	table.insert(equipment_change_callbacks, func)
end

--
-- Re-entrancy. A consumer MAY write equipment itself, and the seam's own
-- contract then obliges it to announce that write through
-- grug_inventory.equipment_changed, which lands back here. Without a guard that
-- is unbounded recursion inside an inventory-action callback, i.e. a C stack
-- overflow and a dead server.
--
-- NOTHING does it today -- the two-handed rule (B4) chose refusal over repair,
-- precisely so that no consumer has to write equipment to enforce a slot rule.
-- The writers this is waiting for are the ones that cannot refuse: WP22's
-- durability (a swing wears the equipped weapon and writes the stack back),
-- WP5's affix re-roll. WP11's respec is NOT one of them any more: ruling 20
-- (2026-09-16, skill_trees.md §1.4/§3.10) removed class changing from the
-- game, so a respec re-spends talents and never unequips anything.
-- grug_inventory's class-restriction unequip already writes lists exactly that
-- way; it just does it from outside the callback loop, so it never re-enters.
--
-- (The ENGINE cannot recurse into this: InvRef:set_stack only flags the
-- inventory modified, and the player_inventory_On* callbacks are reachable
-- solely from a client inventory-action packet --
-- src/inventorymanager.cpp:150-185. The recursion risk is purely mod-side.)
--
-- The guard coalesces instead of just dropping: a nested notification sets
-- `pending`, and the loop is re-run ONCE after the outer pass, so consumers
-- that already ran before the 2H rule cleared the offhand still see the final
-- state. Bounded at two passes by construction; a consumer that notifies
-- unconditionally is a bug and says so in the log, once per server run.
--
-- Keyed PER PLAYER, not by a single flag: a consumer that reacts to A's equip
-- by writing B's equipment (a future party/aura effect) must not have B's
-- notification swallowed and charged to A's second pass.
--
-- Consumers are called UNWRAPPED, like every other hook in this game
-- (grug_xp, grug_money, grug_classes, the threat table below): an error in a
-- registered callback is a mod bug and has to be loud. It also means the guard
-- cannot leak -- a Lua error inside an engine callback takes the server down
-- with it, so there is no "next call" left to block.
local notifying = {} -- player name -> true while its callback loop runs
local notify_pending = {} -- player name -> nested reason; false means unspecified/mixed
local notify_reason = {} -- player name -> reason, false means unspecified/mixed
local warned_unconditional = false

local function run_equipment_callbacks(player, listname)
	local name = player:get_player_name()
	for _, func in ipairs(equipment_change_callbacks) do
		func(player, listname, notify_reason[name] or nil)
	end
end

-- Internal: grug_inventory fires this from grug_inventory.equipment_changed,
-- after it dropped its caches, so a callback already reads the NEW equipment.
function grug_core.notify_equipment_change(player, listname, reason)
	local name = player:get_player_name()
	if notifying[name] then
		local nested_reason = reason or false
		if notify_pending[name] == nil then
			notify_pending[name] = nested_reason
		elseif notify_pending[name] ~= nested_reason then
			notify_pending[name] = false
		end
		if notify_reason[name] ~= nested_reason then
			notify_reason[name] = false
		end
		return
	end
	notifying[name] = true
	notify_reason[name] = reason or false
	run_equipment_callbacks(player, listname)
	if notify_pending[name] ~= nil then
		local pending_reason = notify_pending[name] or nil
		notify_pending[name] = nil
		-- Second and final pass: whatever a consumer changed from inside the
		-- first one is now visible to all of them. `nil` because the nested
		-- write is by definition a different list than the one that started it.
		notify_reason[name] = pending_reason or false
		run_equipment_callbacks(player, nil)
		if notify_pending[name] ~= nil and not warned_unconditional then
			warned_unconditional = true
			core.log("warning", "[grug_core] an on_equipment_change consumer " ..
				"calls equipment_changed unconditionally -- the notification " ..
				"is capped at two passes, fix the consumer")
		end
		notify_pending[name] = nil
	end
	notifying[name] = nil
	notify_pending[name] = nil
	notify_reason[name] = nil
end

-- Flat weapon-damage bonus from Strength (combat_stats.md §2:
-- melee damage = weapon damage + Str/10, the fraction included). Consumed by the
-- native melee patch in mobs/api.lua on_punch.
function grug_core.get_melee_bonus(player)
	return 0
end

-- Race passive lookup (world.md §7); grug_classes overrides this with the
-- real registry accessor. Returns the perk value or nil.
function grug_core.get_race_perk(player, key)
	return nil
end

-- Summed talent bonus for one effect key (skill_trees.md §3.2, WP11);
-- grug_classes/talents.lua overrides this with the real accessor, exactly as
-- it does for get_race_perk above. 0 means "no talent touches this".
function grug_core.get_talent_bonus(player, key)
	return 0
end

--
-- Combat state (combat_stats.md §5 "Combat state"). Shared definition for
-- resource regen and decay, recovery, eating, mounting and travel. A player
-- is in combat while EITHER
--   * at least one live, active grug mob is ENGAGED with them (mob combat), or
--   * the timer runs: 5 s after PvP hits and every hit whose source is not
--     a tracked grug mob (other entities, scorched ground), 10 s after PvP
--     contact (pvp-plan ruling 8, armed by grug_pvp through mark_in_combat).
-- A mob hit never arms the timer, so mob combat ends in the very step the
-- last engaged mob dies, resets, gives up its fight or leaves the active
-- world. Death clears both halves; a dead player cannot be re-marked.
--

grug_core.COMBAT_TIMEOUT = 5
grug_core.PVP_COMBAT_TIMEOUT = 10

-- Monotonic seconds since server start. ONE clock for every combat timer
-- shared between grug_core and grug_mobs (taunt force window, leash contact
-- timer): core.get_us_time() is unaffected by the day/night cycle and by
-- time-of-day changes, unlike core.get_gametime(). The only deliberate
-- gametime user is the player drop tag (grug_mobs), which must survive an
-- unload — see the note there.
function grug_core.mono_time()
	return core.get_us_time() / 1e6
end

local combat_until = {} -- player name -> us time the combat timer runs out

-- Engagement edges (player name, mob luaentity), kept in two event-driven
-- indexes that always change together:
--   mob_ent.temp.grug_engaged = {[player_name] = true}  (runtime only: temp
--                               is never serialized, api.lua clean_staticdata)
--   engaged_mobs[player_name] = {[mob_ent] = true}      (weak keys)
-- in_combat only asks `next(engaged_mobs[name])`, so it stays O(1) however
-- often the HUD and the regen ticks ask. Nothing ever scans objects for it.
--
-- An edge is CREATED by an accepted player hit on the mob
-- (run_player_hit_mob), by every threat gain (add_threat: damage, heal threat,
-- tank bonus), by taunt, and by a hit the mob or its projectile lands on the
-- player (mark_player_hit) -- the last one covers a mob that attacks a player
-- who never touched it and therefore holds no threat entry for them.
-- All edges of a mob are DROPPED by disengage_mob -- the mob's death boundary
-- (grug_mobs.settle_mob_death), on_deactivate (explicit removal and unload)
-- and clear_threat (leash reset, evade). One edge goes by disengage_target
-- (stop_attack: the mob gave up that player) and by the 1 Hz
-- prune_engagement backstop (grug_mobs.leash_tick: a mob that stayed
-- targetless for two ticks, or a player who left a fight that goes on
-- without them) -- and all of a player's edges by their death or leave.
-- Plain target ACQUISITION (mobs_redo do_attack: sight aggro, group alert)
-- deliberately creates no edge: combat starts with the first hit or threat
-- gain (dealt or received damage), so a merely chased player may still mount.
-- The weak keys are only a last-resort backstop against a missed removal
-- hook: a collected luaentity can never pin a player in combat.
local engaged_mobs = {}
local WEAK_KEYS = {__mode = "k"}

-- `seconds` defaults to COMBAT_TIMEOUT; a shorter mark never cuts a longer
-- running timer short (a dodged PvP hit inside the 10 s PvP combat).
function grug_core.mark_in_combat(player, seconds)
	-- Dead players stay out of combat: death cleared the state, and a killing
	-- blow's own bookkeeping (a DoT tick, an after-punch mark) must not re-arm
	-- it. get_hp() is 0 from the lethal set_hp until the respawn.
	if not core.is_player(player) or player:get_hp() <= 0 then
		return
	end
	local name = player:get_player_name()
	local until_us = core.get_us_time() +
		(seconds or grug_core.COMBAT_TIMEOUT) * 1e6
	if until_us > (combat_until[name] or 0) then
		combat_until[name] = until_us
	end
end

-- A mob whose lifecycle hooks drop its edges: every mob registered through
-- grug_mobs.register_mob (the same gate as its death settlement).
function grug_core.is_tracked_mob(mob_ent)
	return mob_ent ~= nil and mob_ent.object ~= nil and grug_mobs ~= nil
		and grug_mobs.registered_cadence ~= nil
		and grug_mobs.registered_cadence[mob_ent.name] == true
end

-- Record that `mob_ent` and `player` are fighting. An untracked entity falls
-- back to the 5 s timer, so no damage source is silently ignored. A dying or
-- already removed mob creates nothing (its death boundary has run): the
-- killing blow's after-punch bonus threat must not re-engage.
function grug_core.engage_mob(mob_ent, player)
	if not core.is_player(player) or player:get_hp() <= 0 then
		return
	end
	if not grug_core.is_tracked_mob(mob_ent) then
		grug_core.mark_in_combat(player)
		return
	end
	if mob_ent.state == "die" or (mob_ent.health or 1) <= 0
			or not mob_ent.object:get_pos() then
		return
	end
	mob_ent.temp = mob_ent.temp or {}
	local edges = mob_ent.temp.grug_engaged
	if not edges then
		edges = {}
		mob_ent.temp.grug_engaged = edges
		mob_ent.temp.grug_engage_idle = nil -- a fresh fight, see prune_engagement
	end
	local name = player:get_player_name()
	if edges[name] then
		return
	end
	edges[name] = true
	local set = engaged_mobs[name]
	if not set then
		set = setmetatable({}, WEAK_KEYS)
		engaged_mobs[name] = set
	end
	set[mob_ent] = true
end

-- Drop every edge of one mob. Idempotent; O(players engaged with it).
function grug_core.disengage_mob(mob_ent)
	local temp = mob_ent and mob_ent.temp
	local edges = temp and temp.grug_engaged
	if not edges then
		return
	end
	temp.grug_engaged = nil
	temp.grug_engage_idle = nil
	for name in pairs(edges) do
		local set = engaged_mobs[name]
		if set then
			set[mob_ent] = nil
			if next(set) == nil then
				engaged_mobs[name] = nil
			end
		end
	end
end

-- Drop ONE edge; keeps both indexes in step. `edges` is the mob's own table.
local function drop_edge(mob_ent, edges, name)
	edges[name] = nil
	local set = engaged_mobs[name]
	if set then
		set[mob_ent] = nil
		if next(set) == nil then
			engaged_mobs[name] = nil
		end
	end
	if next(edges) == nil then
		mob_ent.temp.grug_engaged = nil
		mob_ent.temp.grug_engage_idle = nil
	end
end

-- The mob gives up ONE player: stop_attack on its current target (grug_mobs'
-- class wrapper). Only that player's edge goes -- in a group fight the healer
-- and the damage dealers stay engaged while the mob picks its next target; a
-- solo fight still ends at once. Whatever the mob no longer fights is left to
-- prune_engagement (a mob that stays targetless drops everyone within two
-- ticks). Leash reset and evade go through clear_threat, which drops all.
function grug_core.disengage_target(mob_ent, target)
	local edges = mob_ent and mob_ent.temp and mob_ent.temp.grug_engaged
	if not edges or not core.is_player(target) then
		return
	end
	local name = target:get_player_name()
	if edges[name] then
		drop_edge(mob_ent, edges, name)
	end
end

-- Drop the timer and every edge of one player. O(mobs engaged with them).
local function clear_combat(player)
	local name = player:get_player_name()
	combat_until[name] = nil
	local set = engaged_mobs[name]
	if not set then
		return
	end
	engaged_mobs[name] = nil
	for mob_ent in pairs(set) do
		local edges = mob_ent.temp and mob_ent.temp.grug_engaged
		if edges then
			edges[name] = nil
			if next(edges) == nil then
				mob_ent.temp.grug_engaged = nil
			end
		end
	end
end

-- Classify one hit (landed or dodged) on a player by its source object. A
-- tracked mob, or a projectile carrying its shooter (`_grug_source`, stamped
-- by grug_mobs.stamp_arrow_damage), engages; a player (PvP) or any other
-- source arms the timer. A projectile whose shooter is gone (dead or
-- unloaded) holds no fight.
function grug_core.mark_player_hit(player, source)
	local ent = source and not source:is_player() and source:get_luaentity()
	if ent then
		local shooter = ent._grug_source
		if shooter then
			local shooter_ent = shooter:get_luaentity()
			if shooter_ent then
				grug_core.engage_mob(shooter_ent, player)
			end
			return
		end
		grug_core.engage_mob(ent, player)
		return
	end
	grug_core.mark_in_combat(player)
end

function grug_core.in_combat(player)
	local name = player:get_player_name()
	local set = engaged_mobs[name]
	if set and next(set) ~= nil then
		return true
	end
	local t = combat_until[name]
	return t ~= nil and core.get_us_time() < t
end

-- Death ends combat at once (user ruling 2026-09-28) and the respawned player
-- starts out of combat. Threat entries stay on the mobs -- valid_target
-- already ignores a dead player -- but no edge survives. After the respawn a
-- new hit, a new threat gain, or a threat-driven target switch onto the
-- player (check_switch, possible when they respawn within 40 m of a mob that
-- still holds their old threat) puts them back into combat.
core.register_on_dieplayer(clear_combat)
core.register_on_leaveplayer(clear_combat)

--
-- Threat table (combat_stats §4). Mobs pick their target by threat, not by
-- proximity.
--
-- Storage: `mob_ent.temp.grug_threat = {[player_name] = amount}`.
-- `temp` is mobs_redo's runtime-only store (never serialized into
-- staticdata, api.lua clean_staticdata:2817) — RUNTIME ONLY BY DESIGN: a mob
-- that gets deactivated (player left the area, server restart) legitimately
-- forgets who annoyed it, exactly like the leash reset does. Player refs are
-- stored as NAMES and re-fetched, never as ObjectRefs.
--
-- Two more runtime keys live in the same table and are shared with
-- grug_mobs' leash (aggro.lua):
--   temp.grug_forced_until  — mono_time until which taunt suppresses
--                             hysteresis target switches
--   temp.grug_last_contact  — mono_time of the last player contact; written
--                             here (player hit the mob, taunt, our own
--                             target switch), read by the leash
--

grug_core.THREAT_SWITCH_FACTOR = 1.2 -- hysteresis: >120% of the target's threat
grug_core.THREAT_RANGE = 40 -- m; threat entries further out cannot pull the mob
grug_core.HEAL_THREAT_RANGE = 30 -- m (combat_stats §4)
grug_core.HEAL_THREAT_FACTOR = 0.5
grug_core.TAUNT_FORCE_TIME = 3 -- s of forced target after a taunt

local function threat_table(mob_ent)
	mob_ent.temp = mob_ent.temp or {}
	mob_ent.temp.grug_threat = mob_ent.temp.grug_threat or {}
	return mob_ent.temp.grug_threat
end

-- Is this threat entry a legal target right now? Connected, alive and inside
-- the mob's threat reality (40 m ~ the leash radius, so a stale entry from
-- across the map can never yank a mob around). Returns the ObjectRef.
-- A mob's own acquisition veto (grug_mobs init.lua `_grug_target_veto`: a
-- dragon ignores players outside its arena) also rules out threat, taunt and
-- forced switches, so none of them can hand such a player back.
local function vetoed(mob_ent, player)
	return mob_ent._grug_target_veto ~= nil and
		mob_ent._grug_target_veto(mob_ent, player) == true
end

local function valid_target(mob_ent, name)
	local player = core.get_player_by_name(name)
	if not player or not player:is_player() or player:get_hp() <= 0 or
			vetoed(mob_ent, player) then
		return nil
	end
	local mpos = mob_ent.object and mob_ent.object:get_pos()
	local ppos = player:get_pos()
	if not mpos or not ppos then
		return nil
	end
	if not (grug_mobs and grug_mobs.damage_pursuit
			and grug_mobs.damage_pursuit(mob_ent))
			and vector.distance(mpos, ppos) > grug_core.THREAT_RANGE then
		return nil
	end
	return player
end

-- Highest threat amount on the table (validity is not checked — the taunt
-- needs the raw top so it cannot be undercut by an out-of-range rival).
local function top_amount(threat)
	local top = 0
	for _, amount in pairs(threat) do
		if amount > top then
			top = amount
		end
	end
	return top
end

-- Minimum game time between two target re-evaluations of ONE mob. add_threat
-- is called from every player punch AND from every ability hit, so a tank
-- spamming a 3-hit combo on a pack of five mobs runs check_switch fifteen
-- times inside a few frames — each one a loop over the threat table with a
-- get_player_by_name + a distance test per entry, all to reach the same
-- verdict. Threat itself still accumulates on EVERY hit (that is exact); only
-- the question "does the target change?" is asked at most four times a second
-- per mob. A quarter of a second is far below the perceptible switch latency
-- and far below the 1 s leash tick.
local SWITCH_INTERVAL = 0.25

-- Hysteresis check: switch only when the best VALID rival exceeds 120% of
-- the current target's threat (combat_stats §4 — no ping-pong).
-- `force` skips the throttle; only recheck_switch below passes it.
local function check_switch(mob_ent, force)
	local threat = mob_ent.temp and mob_ent.temp.grug_threat
	if not threat or type(mob_ent.do_attack) ~= "function" then
		return
	end
	-- Throttle (see above). Runtime-only keys in the same temp table the
	-- threat lives in, so they die with the mob's activation.
	local now = grug_core.mono_time()
	if not force and
			now - (mob_ent.temp.grug_switch_at or -math.huge) < SWITCH_INTERVAL then
		-- The throttle is LEADING EDGE, so a suppressed call is not
		-- necessarily a redundant one: the last hit of a burst is the one that
		-- carries the most threat, and it is exactly the hit that can push a
		-- rival past the 120 % hysteresis. Dropping it outright lost the switch
		-- until whenever the next hit happened to land — which for a finished
		-- cast sequence can be never. Park it instead; grug_mobs' 1 Hz mob tick
		-- drains the flag through recheck_switch (aggro.lua leash_tick).
		mob_ent.temp.grug_switch_pending = true
		return
	end
	mob_ent.temp.grug_switch_at = now
	mob_ent.temp.grug_switch_pending = nil
	if mob_ent.state == "die" or (mob_ent.health or 1) <= 0 then
		return
	end
	-- A FORCED do_attack skips the guards mobs_redo's own retaliation
	-- respects (api.lua:3506-3515), so re-check them here: threat must never
	-- turn a passive critter, a child or a fleeing mob into an attacker, and
	-- a mob without an attack_type cannot fight at all.
	if mob_ent.passive or mob_ent.child or not mob_ent.attack_type or
			mob_ent.state == "flop" or mob_ent.state == "runaway" then
		return
	end
	if (mob_ent.temp.grug_forced_until or 0) > now then
		mob_ent.temp.grug_switch_pending = true
		return -- retain the trailing check until the force window expires
	end
	local best_name, best, best_obj
	for name, amount in pairs(threat) do
		if not best or amount > best then
			local obj = valid_target(mob_ent, name)
			if obj then
				best_name, best, best_obj = name, amount, obj
			end
		end
	end
	if not best_obj then
		return
	end
	local cur = mob_ent.attack
	if cur and core.is_player(cur) and
			valid_target(mob_ent, cur:get_player_name()) then
		local cur_name = cur:get_player_name()
		if cur_name == best_name then
			return
		end
		if best <= (threat[cur_name] or 0) * grug_core.THREAT_SWITCH_FACTOR then
			return
		end
	end
	-- force = true: overrides an existing target (mobs/api.lua:265-296).
	mob_ent:do_attack(best_obj, true)
	-- A fresh target means fresh contact — the leash clock restarts.
	mob_ent.temp.grug_last_contact = now
	-- ... and the new target is in this fight again (combat state), even if
	-- prune_engagement had let them go while they were out of range.
	grug_core.engage_mob(mob_ent, best_obj)
end

-- Trailing edge of the throttle above: run the parked target check once,
-- ignoring the 0.25 s gate. Called once a second per mob from grug_mobs'
-- do_custom tick (aggro.lua leash_tick), which is where our per-mob 1 Hz
-- budget already lives — a mob with nothing parked pays one field read.
-- The flag is cleared HERE and not only inside check_switch, so a mob that
-- bails at check_switch's first guard (threat table cleared by a leash reset
-- in the meantime) does not keep a stale flag forever.
function grug_core.recheck_switch(mob_ent)
	if not mob_ent or not mob_ent.temp or not mob_ent.temp.grug_switch_pending then
		return
	end
	mob_ent.temp.grug_switch_pending = nil
	check_switch(mob_ent, true)
end

-- Engagement backstop, run once a second per mob that holds engagements
-- (grug_mobs.leash_tick; a mob without any pays one field test there).
-- A mob without a target on TWO consecutive ticks has left its fight: every
-- edge goes. That covers paths that bypass stop_attack (the death reset in
-- mobs_redo's check_for_death; a passive critter never takes a target) and
-- a group fight whose mob gave up its target and found no new one. One
-- tick of grace, because mobs_redo's
-- reacquisition (general_attack) also runs only once a second. A flopping
-- (stranded) mob counts as targetless; only the runaway state, bounded by
-- mobs_redo's runaway_timer, is exempt. A mob that is
-- still fighting keeps its current target, but forgets every other player
-- who is disconnected, dead or outside the 40 m threat radius: a player who
-- left a fight that goes on without them leaves combat. The radius applies
-- to ambient damage-pursuit mobs too (unlike valid_target): should such a
-- mob later switch to the far player by threat, check_switch re-engages them.
-- O(edges of this mob).
local function in_fight_range(mob_ent, name)
	local player = core.get_player_by_name(name)
	if not player or player:get_hp() <= 0 then
		return false
	end
	local mpos = mob_ent.object and mob_ent.object:get_pos()
	local ppos = player:get_pos()
	if not mpos or not ppos then
		return false
	end
	local dx, dy, dz = mpos.x - ppos.x, mpos.y - ppos.y, mpos.z - ppos.z
	return dx * dx + dy * dy + dz * dz <=
		grug_core.THREAT_RANGE * grug_core.THREAT_RANGE
end

function grug_core.prune_engagement(mob_ent)
	local temp = mob_ent.temp
	local edges = temp and temp.grug_engaged
	if not edges then
		return
	end
	local target = mob_ent.state ~= "flop" and mob_ent.attack or nil
	if not target then
		if mob_ent.state == "runaway" then
			temp.grug_engage_idle = nil
		elseif temp.grug_engage_idle then
			grug_core.disengage_mob(mob_ent)
		else
			temp.grug_engage_idle = true
		end
		return
	end
	temp.grug_engage_idle = nil
	local target_name = core.is_player(target) and target:get_player_name()
	for name in pairs(edges) do
		if name ~= target_name and not in_fight_range(mob_ent, name) then
			drop_edge(mob_ent, edges, name)
		end
	end
end

-- Accumulate threat for one player on one mob, then re-check the target.
-- Base threat (= damage dealt) is added in exactly ONE place, see
-- run_player_hit_mob below.
function grug_core.add_threat(mob_ent, player, amount)
	if not mob_ent or not mob_ent.object or not amount or amount <= 0
			or (mob_ent.temp and mob_ent.temp.grug_evading) then
		return
	end
	if not player or not core.is_player(player) or vetoed(mob_ent, player) then
		return
	end
	local threat = threat_table(mob_ent)
	local name = player:get_player_name()
	threat[name] = (threat[name] or 0) + amount
	-- Holding a threat entry is engagement (combat state above).
	grug_core.engage_mob(mob_ent, player)
	check_switch(mob_ent)
end

-- Drops the whole table (leash reset) and with it every engagement: a mob
-- that forgot everyone is fighting nobody.
function grug_core.clear_threat(mob_ent)
	if mob_ent and mob_ent.temp then
		mob_ent.temp.grug_threat = nil
		mob_ent.temp.grug_forced_until = nil
	end
	grug_core.disengage_mob(mob_ent)
end

-- Healing threat (combat_stats §4): 0.5×effective healing on the HEALER,
-- applied to every grug mob within 30 m of the healer that is currently
-- fighting the healer or the heal target. MVP group = healer + target; real
-- party membership arrives with WP20 (parties) and replaces this pair.
-- Event-driven get_objects_inside_radius is fine here: heals are rare
-- (ability casts), this is not a globalstep.
function grug_core.add_heal_threat(healer, target, amount)
	if not healer or not target or not amount or amount <= 0 then
		return
	end
	if not core.is_player(healer) then
		return
	end
	local pos = healer:get_pos()
	if not pos then
		return
	end
	local hname = healer:get_player_name()
	local tname = core.is_player(target) and target:get_player_name() or nil
	-- Quiet Steps (skill_trees.md §2.5) lowers the healer's own factor;
	-- 0 without the talent, so this is HEAL_THREAT_FACTOR exactly.
	local threat = amount * math.max(0, grug_core.HEAL_THREAT_FACTOR
		- grug_core.get_talent_bonus(healer, "heal_threat_factor_sub"))
	local objs = core.get_objects_inside_radius(pos, grug_core.HEAL_THREAT_RANGE)
	for n = 1, #objs do
		local ent = objs[n]:get_luaentity()
		-- _grug_level marks one of our mobs (levels.lua ensure_init).
		if ent and ent._grug_level and ent.attack and core.is_player(ent.attack) then
			local aname = ent.attack:get_player_name()
			if aname == hname or (tname and aname == tname) then
				grug_core.add_threat(ent, healer, threat)
			end
		end
	end
end

-- Taunt (combat_stats §4): sets the taunter to top×1.1 and locks the target
-- for 3 s against hysteresis switches. The forcing do_attack call itself
-- lives in the ability (grug_abilities/kits.lua) — this is the threat half.
function grug_core.taunt(mob_ent, player)
	if not mob_ent or not mob_ent.object or not player or
			not core.is_player(player) or
			(mob_ent.temp and mob_ent.temp.grug_evading) or vetoed(mob_ent, player) then
		return false
	end
	local threat = threat_table(mob_ent)
	local name = player:get_player_name()
	local want = top_amount(threat) * 1.1
	threat[name] = math.max(threat[name] or 0, want)
	local now = grug_core.mono_time()
	mob_ent.temp.grug_forced_until = now + grug_core.TAUNT_FORCE_TIME
	mob_ent.temp.grug_last_contact = now
	grug_core.engage_mob(mob_ent, player)
	return true
end

--
-- Player hit mob hook: fired by grug_mobs' accepted-player-hit seam after
-- do_punch/CMI accept (rage generation, combat marking, threat).
-- func(player, mob_ent, damage)
--

local hit_mob_callbacks = {}
local ability_action_id
local ability_settlement

function grug_core.register_on_player_hit_mob(func)
	table.insert(hit_mob_callbacks, func)
end

function grug_core.run_player_hit_mob(player, mob_ent, damage)
	-- Every accepted hit engages, a zero-damage one included (add_threat
	-- below engages only on positive threat).
	if mob_ent then
		grug_core.engage_mob(mob_ent, player)
	else
		grug_core.mark_in_combat(player)
	end
	-- THE ONE base-threat site. Every player hit on a mob passes through
	-- here: native swings go player -> object:punch -> grug_mobs' accepted
	-- hook -> here, and ability damage goes deal_ability_damage ->
	-- object:punch -> the SAME hook -> here. Adding damage-as-threat in
	-- deal_ability_damage as well would double-count every ability hit;
	-- that call only adds the tank multiplier BONUS on top (see there).
	-- Base threat stays the raw, possibly FRACTIONAL damage: threat is a
	-- sum, not an integer, so it accumulates fractionally just fine.
	if mob_ent then
		grug_core.add_threat(mob_ent, player, damage or 0)
		-- Player contact for the leash (aggro.lua): being hit counts.
		mob_ent.temp = mob_ent.temp or {}
		mob_ent.temp.grug_last_contact = grug_core.mono_time()
	end
	for _, func in ipairs(hit_mob_callbacks) do
		func(player, mob_ent, damage)
	end
	if grug_core.in_ability_punch and ability_settlement
			and ability_settlement.attacker == player
			and mob_ent and mob_ent.object == ability_settlement.target
			and (damage or 0) > 0 then
		ability_settlement.accepted = true
		grug_core.run_settled_outgoing_action(player, ability_action_id, "damage")
	end
end

--
-- Dealing ability damage. Rolls the attacker's crit (×2) and — against
-- players — the target's dodge, then applies the result via object:punch
-- with a full punch interval (factor 1), so armor groups, knockback and
-- mob death handling (XP/loot via on_death) keep working.
-- opts: {threat_mult = n} extra threat factor (tank abilities ×3).
-- Returns published pre-armor damage (0 on pre-punch refusal). Accepted-hit
-- effects use opts.on_accepted(amount, critical, action_id), called exactly
-- once after the matching mob acceptance or actual player HP loss.
--

-- A crit doubles damage and heals (item_tiers.md §1.0).
local CRIT_MULTIPLIER = 2

local function crit_particles(pos)
	core.add_particlespawner({
		amount = 8,
		time = 0.15,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.4, 0.6, -0.4),
			max = vector.offset(pos, 0.4, 1.4, 0.4)},
		vel = {min = vector.new(-1, 1, -1), max = vector.new(1, 3, 1)},
		exptime = {min = 0.3, max = 0.6},
		size = {min = 2, max = 3},
		texture = "default_item_smoke.png^[multiply:#ffd100",
	})
end

--
-- Player melee (combat_stats.md §2 "Melee timing"): every player hit, on a
-- mob or on a player, is one authoritative full swing (grug_abilities
-- attempt_swing) or an ability punch. Native tool and fist packets are input
-- only and deal nothing, so there is no partial-swing damage to carry.
--

-- Crit roll for a player melee punch (combat_stats.md §2): same ×2 and
-- the same particle burst as ability crits above — player melee was the one
-- damage source that could never crit. Resolution is deliberately pure so a
-- mobs_redo caller can defer the visual until do_punch and CMI accept.
--
-- Not floored here: the PvP handler floors once after armor and mobs_redo at
-- the health subtraction. Only the plain ×2 is rolled; the `damage <= 0`
-- guard below keeps an immunity-zeroed hit from rolling at all.
function grug_core.roll_melee_crit(player, damage)
	if damage <= 0 or math.random() >= grug_core.get_crit_chance(player) then
		return damage, 1, false
	end
	return damage * CRIT_MULTIPLIER, CRIT_MULTIPLIER, true
end

function grug_core.emit_melee_crit(pos)
	if pos then
		crit_particles(pos)
	end
end

local native_melee_prepare
local native_melee_finish
local native_swing_input
local authoritative_swing

-- One optional consumer owns authoritative swing-skill procs. grug_core is below the
-- ability mod in the dependency graph, while vendored mobs_redo must not know
-- about grug_abilities; this seam lets both mob and PvP full swings use the
-- same two-phase accepted-hit transaction without a reverse dependency.
function grug_core.register_native_melee_handler(prepare, finish)
	assert(native_melee_prepare == nil and native_melee_finish == nil,
		"native melee handler already registered")
	assert(type(prepare) == "function" and type(finish) == "function",
		"native melee handler needs prepare and finish functions")
	native_melee_prepare = prepare
	native_melee_finish = finish
end

function grug_core.prepare_native_melee(player, target, token)
	if native_melee_prepare then
		return native_melee_prepare(player, target, token)
	end
	return nil
end

function grug_core.finish_native_melee(context, result)
	if context and native_melee_finish then
		return native_melee_finish(context, result or {})
	end
	return false
end

-- Swing ability items keep their native no-on_use object interaction so the
-- client still animates held LMB and builtin dropped items still receive
-- on_punch. Against combat objects, however, that packet is input/targeting
-- only: grug_abilities owns the authoritative soft-lock clock. This seam keeps
-- vendored mobs_redo below the player-mod dependency boundary.
function grug_core.register_native_swing_input_handler(handler)
	assert(native_swing_input == nil, "native swing input handler already registered")
	assert(type(handler) == "function", "native swing input handler must be a function")
	native_swing_input = handler
end

function grug_core.handle_native_swing_input(player, target)
	return native_swing_input and native_swing_input(player, target) or false
end

-- An authoritative swing is a synchronous exactly-once transaction. The
-- vendored mob/PvP entry must claim the opaque token for the exact attacker
-- and target before it can bypass native-input suppression. Once claimed, a
-- callback-triggered nested punch by the same attacker cannot claim again,
-- even when it targets the same ObjectRef.
function grug_core.begin_authoritative_swing(player, target, context)
	if authoritative_swing then
		return nil
	end
	local token = {
		player = player,
		target = target,
		claimed = false,
		context = context,
	}
	authoritative_swing = token
	return token
end

function grug_core.claim_authoritative_swing(player, target)
	local token = authoritative_swing
	if token and not token.claimed and token.player == player
			and token.target == target then
		token.claimed = true
		return token
	end
	return nil
end

function grug_core.authoritative_swing_active(player)
	return authoritative_swing ~= nil
		and (player == nil or authoritative_swing.player == player)
end

function grug_core.valid_authoritative_swing(token, player, target)
	return token ~= nil and token == authoritative_swing and token.claimed
		and token.player == player and token.target == target
end

function grug_core.get_authoritative_swing_context(token)
	if token == authoritative_swing and token.claimed then
		return token.context
	end
	return nil
end

function grug_core.end_authoritative_swing(token)
	if authoritative_swing == token then
		authoritative_swing = nil
		return true
	end
	return false
end

--
-- Knockback on players (Round 37 ruling 2.1.3, CMB-04). Builtin pushes every
-- punched player off the engine's pre-callback damage (builtin/game/
-- knockback.lua), and its on_punchplayer is registered before any mod's, so
-- it pushes before our callbacks refuse or suppress the punch. One override
-- therefore decides by the source, ahead of them:
--   * a player's melee pushes only as the authoritative swing at this exact
--     target, not yet claimed (builtin runs first), on a pair grug_pvp lets
--     harm each other -- PvP melee. A refused click, an ally, an unflagged
--     player, an ordinary tool or fist packet and a nested punch push nothing;
--   * a mob's hit pushes: its melee and area hits (the mob as hitter) and its
--     projectiles (arrows, hex bottles, dragon breath and side shots, the
--     projectile entity as hitter; user ruling 2026-10-06);
--   * a player's casts, arrows and all ability damage (`in_ability_punch`)
--     push nothing.
-- The wrappers around it keep their own zero: attached riders (player_api)
-- and the dragon's slam (grug_mobs boss_dragons.lua).
function grug_core.knockback_pushes(player, hitter)
	if grug_core.in_ability_punch or not hitter then
		return false
	end
	if hitter:is_player() then
		local token = authoritative_swing
		return token ~= nil and not token.claimed and token.player == hitter
			and token.target == player and grug_core.pvp_can_harm ~= nil
			and grug_core.pvp_can_harm(hitter, player) == true
	end
	-- Every other hitter is a mob or a mob's projectile.
	return true
end

local engine_knockback = core.calculate_knockback
if engine_knockback then
	function core.calculate_knockback(player, hitter, ...)
		if not grug_core.knockback_pushes(player, hitter) then
			return 0
		end
		return engine_knockback(player, hitter, ...)
	end
end

-- True while an ability punch is running — lets the rage-on-hit hook skip
-- ability hits (rage comes from authoritative melee swings only, classes.md §1) and the
-- central dodge modifier skip the roll (abilities pre-roll it below).
grug_core.in_ability_punch = false
local ability_attacker_level

-- The PvP seam (pvp-plan §4). grug_pvp installs both functions at load;
-- grug_core never depends on it, and without it enemy players stay hostile as
-- before. Every PvE path returns before either is asked.
--   pvp_can_harm(attacker, target)  -> bool, for a player pair: the impact
--     re-check below and the crosshair ray (combat_ray.lua) ask it;
--   pvp_hit_landed(attacker, target): hostile player damage landed on a
--     player (HP lost or absorb consumed), called from the central hp-change
--     modifier below -- the one place every PvP hit (swing, cast, area
--     effect, projectile) passes after dodge, armor and absorb.
grug_core.pvp_can_harm = nil
grug_core.pvp_hit_landed = nil

function grug_core.deal_ability_damage(attacker, target, amount, opts)
	opts = opts or {}
	-- Callers have already assembled base, gear and flat talent additions.
	-- Scale that complete value once, then apply the target-level malus.
	amount = grug_core.scale_player_damage(attacker, target, amount)
	if target:is_player() then
		-- Friendly fire: defense in depth — the ability kits filter their
		-- targets already, but never let same-faction damage through here.
		if attacker:is_player() then
			local af = grug_core.get_player_faction(attacker:get_player_name())
			local tf = grug_core.get_player_faction(target:get_player_name())
			if af and tf and af == tf then
				return 0
			end
			-- Impact re-check (pvp-plan ruling 5): a cast, area effect or
			-- projectile chosen while both were flagged may land after one of
			-- them lost the flag. No dodge roll, no combat mark, no cost here.
			if grug_core.pvp_can_harm and
					not grug_core.pvp_can_harm(attacker, target) then
				return 0
			end
		end
		-- Dodge is pre-rolled here for ability punches so the return value
		-- and the threat report reflect what actually landed; the central
		-- modifier skips the roll while in_ability_punch is set.
		if math.random() < grug_core.get_dodge_chance(target) then
			grug_core.feed(target, "combat", "You dodge!", "combat:dodge")
			grug_sounds.play("dodge", target)
			grug_core.mark_in_combat(attacker)
			grug_core.mark_player_hit(target, attacker)
			return 0
		end
	end
	local critical = math.random() < grug_core.get_crit_chance(attacker)
	if critical then
		amount = math.floor(amount * CRIT_MULTIPLIER)
		crit_particles(target:get_pos())
	end
	-- PvP and untracked targets arm the attacker's timer up front, as before.
	-- A tracked mob engages only when it ACCEPTS the hit (run_player_hit_mob),
	-- so a refused punch (an evading mob) starts no fight.
	if not grug_core.is_tracked_mob(target:get_luaentity()) then
		grug_core.mark_in_combat(attacker)
	end
	-- pcall + flag restore: an error mid-punch must not leave the sticky
	-- flag set (that would silently kill rage generation server-wide).
	local previous_punch, previous_action, previous_level, previous_settlement =
		grug_core.in_ability_punch, ability_action_id, ability_attacker_level, ability_settlement
	local settlement = {attacker = attacker, target = target}
	ability_settlement = settlement
	grug_core.in_ability_punch = true
	ability_action_id = opts.action_id or {}
	ability_attacker_level = opts.attacker_level or
		grug_core.get_player_level(attacker)
	-- `punch_attack_uses = 0` is not cosmetic: mobs_redo's on_punch runs an
	-- UNGUARDED wear block (mods/ENTITIES/mobs/api.lua:2927-3538) that adds
	-- floor(fpi / 75 * 9000) wear to the WIELDED stack and writes it back with
	-- set_wielded_item -- and during a cast the wielded stack IS the ability
	-- tool. At fpi 1.4 that is 167, not 168: 1.4/75*9000 is 167.99999999999997
	-- in doubles (BACKLOG.md's WP35 row, T0, quotes 168/~390 -- measured,
	-- it is 167 and the tool breaks on cast 393). Abilities with a cooldown
	-- hid it by accident (the cooldown ticker overwrites the wear every step
	-- and zeroes it at the end); Mighty Blow has cooldown 0, so its own icon
	-- grew a wear bar and the tool broke after 393 landed hits, vanishing
	-- from the hotbar until a relog
	-- re-granted it. api.lua:2927-3538 reads exactly this field as "no wear",
	-- so one line switches the whole path off for every ability punch.
	local hp_before = target:get_hp()
	local ok, err = pcall(target.punch, target, attacker, 1.4, {
		full_punch_interval = 1.4,
		punch_attack_uses = 0,
		damage_groups = {fleshy = amount},
	}, nil)
	local settled_action = ability_action_id
	ability_action_id = previous_action
	ability_attacker_level = previous_level
	ability_settlement = previous_settlement
	grug_core.in_ability_punch = previous_punch
	if not ok then
		core.log("warning", "[grug_core] ability punch failed: " .. tostring(err))
		return 0
	end
	if target:is_player() and target:get_hp() < hp_before then
		settlement.accepted = true
		grug_core.run_settled_outgoing_action(attacker, settled_action, "damage")
	end
	if settlement.accepted and opts.on_accepted then
		opts.on_accepted(amount, critical, settled_action)
	end
	-- BONUS-ONLY threat site. The punch above already ran through grug_mobs'
	-- accepted hit hook -> run_player_hit_mob, which added the base threat
	-- (= damage) exactly once. Adding `amount * threat_mult` here would
	-- double-count the base for every ability, so only the extra factor of a
	-- tank ability (×3 -> +2×damage) is added on top; ×1 adds nothing.
	local mult = opts.threat_mult or 1
	if settlement.accepted and mult ~= 1 then
		-- Affront (skill_trees.md §2.1) raises the TANK multiplier only: an
		-- ability that carries no multiplier stays at ×1 and adds nothing.
		-- This is the cast site; the swing site is grug_abilities/init.lua.
		mult = mult + grug_core.get_talent_bonus(attacker, "threat_mult_add")
		local ent = target:get_luaentity()
		if ent then
			grug_core.add_threat(ent, attacker, amount * (mult - 1))
		end
	end
	return amount
end

--
-- Healing a player. Rolls the healer's crit (×2), clamps to max HP and
-- reports heal threat. Returns the effective healing done.
--
-- opts.no_crit skips only the crit roll. Ability and consumable amounts arrive
-- already derived from their current-level pool; scale_player_value deliberately
-- preserves them instead of applying the damage-only level fit.
--

local effective_heal_callbacks = {}

function grug_core.register_on_effective_heal(func)
	table.insert(effective_heal_callbacks, func)
end

function grug_core.heal_player(healer, target, amount, opts)
	opts = opts or {}
	local hp = target:get_hp()
	if hp <= 0 then
		return 0
	end
	-- Ability heals arrive with percentage-point talent additions included.
	-- Consumables arrive with their max-HP-derived amount. The support seam is
	-- retained but is an identity for both.
	amount = math.floor(grug_core.scale_player_value(healer, amount))
	if grug_core.trinket_outgoing_heal then
		amount = math.floor(grug_core.trinket_outgoing_heal(healer, amount))
	end
	if not opts.no_crit and math.random() < grug_core.get_crit_chance(healer) then
		amount = math.floor(amount * CRIT_MULTIPLIER)
		crit_particles(target:get_pos())
	end
	local max_hp = target:get_properties().hp_max
	local effective = math.min(amount, max_hp - hp)
	if effective > 0 then
		target:set_hp(hp + effective)
		grug_core.add_heal_threat(healer, target, effective)
		for i = 1, #effective_heal_callbacks do
			effective_heal_callbacks[i](healer, target, effective)
		end
		if opts.action_id and healer and healer:is_player() and
				grug_core.in_combat(healer) then
			grug_core.run_settled_outgoing_action(healer, opts.action_id, "heal")
		end
	end
	return effective
end

--
-- Named absorb contributions (skill_trees.md §3.11): independent lifetimes,
-- same-source refresh, capped at maximum HP and consumed shortest-lived first.
-- Contribution modifiers expire with their owner; no parallel status timer.
--

local absorbs = {} -- player name -> source id -> {amount = n, expiry = us time}
local effective_absorb_callbacks = {}

function grug_core.register_on_effective_absorb(func)
	table.insert(effective_absorb_callbacks, func)
end

-- Durability/action consumers subscribe here. `action_id` must be unique for
-- that player's live session and reused across every result of one action.
-- Damage owners publish explicitly; heal_player/add_absorb publish only when
-- their caller supplies that shared identity. Consumers deduplicate it, so an
-- aura may report several effective targets without multiplying action wear.
local settled_outgoing_callbacks = {}

function grug_core.register_on_settled_outgoing_action(func)
	table.insert(settled_outgoing_callbacks, func)
end

function grug_core.run_settled_outgoing_action(player, action_id, kind)
	if not player or not action_id then return end
	for index = 1, #settled_outgoing_callbacks do
		settled_outgoing_callbacks[index](player, action_id, kind)
	end
end

-- Incoming settlement is centralized after all hp-change modifiers. A full
-- dodge/absorb produces zero and a lethal hit is excluded by contract.
local settled_incoming_callbacks = {}

function grug_core.register_on_settled_incoming_hit(func)
	table.insert(settled_incoming_callbacks, func)
end

function grug_core.add_absorb(player, id, amount, duration, source, action_id, modifiers)
	amount = grug_core.scale_player_value(source or player, amount)
	local expiry = core.get_us_time() + duration * 1e6
	local name = player:get_player_name()
	absorbs[name] = absorbs[name] or {}
	local existing = 0
	for current_id, entry in pairs(absorbs[name]) do
		if current_id ~= id and entry.expiry > core.get_us_time() then
			existing = existing + entry.amount
		end
	end
	local properties = player:get_properties() or {}
	amount = math.max(0, math.min(amount,
		(tonumber(properties.hp_max) or amount) - existing))
	if amount <= 0 then
		absorbs[name][id] = nil
		return 0
	end
	absorbs[name][id] = {
		amount = amount,
		expiry = expiry,
		modifiers = modifiers,
		source = source and source:get_player_name(),
	}
	local status_expiry = expiry
	for _, entry in pairs(absorbs[name]) do
		status_expiry = math.max(status_expiry, entry.expiry)
	end
	for index = 1, #effective_absorb_callbacks do
		effective_absorb_callbacks[index](source or player, player, amount)
	end
	local owner = source or player
	if amount > 0 and action_id and owner:is_player() and
			grug_core.in_combat(owner) then
		grug_core.run_settled_outgoing_action(owner, action_id, "absorb")
	end
	if grug_core.set_status then
		grug_core.set_status(player, "shield", {
			label = "Shield",
			expiry_us = status_expiry,
			value = function(target)
				local remaining = grug_core.get_absorb(target)
				return remaining > 0 and remaining or false
			end,
			kind = "buff",
		})
	end
	return amount
end

function grug_core.absorb_modifier(player, key)
	grug_core.get_absorb(player)
	local total = 0
	for _, entry in pairs(absorbs[player:get_player_name()] or {}) do
		total = total + (entry.modifiers and entry.modifiers[key] or 0)
	end
	return total
end

-- Respec/death/leave remove caster-owned talent modifiers, including shields
-- on another class. The underlying absorb retains its independent lifetime.
function grug_core.clear_absorb_modifiers(source)
	local name = source:get_player_name()
	for _, entries in pairs(absorbs) do
		for _, entry in pairs(entries) do
			if entry.source == name then entry.modifiers = nil end
		end
	end
end

-- Remaining absorb amount (0 when none/expired).
function grug_core.get_absorb(player)
	local name = player:get_player_name()
	local entries = absorbs[name]
	if not entries then
		if grug_core.clear_status then
			grug_core.clear_status(player, "shield")
		end
		return 0
	end
	local total, t = 0, core.get_us_time()
	for id, entry in pairs(entries) do
		if t >= entry.expiry or entry.amount <= 0 then
			entries[id] = nil
		else
			total = total + entry.amount
		end
	end
	if total <= 0 then
		absorbs[name] = nil
		if grug_core.clear_status then
			grug_core.clear_status(player, "shield")
		end
	end
	return total
end

-- Turn Aside's dodge rides on the shield that carries it (kits.lua Shield),
-- so its status icon lives exactly as long as a live absorb entry
-- still holds a dodge modifier: consumed, expired and respec-cleared shields
-- all end it (Round 26 ruling 18).
if grug_core.register_status_source then
	grug_core.register_status_source(function(player)
		if not absorbs[player:get_player_name()] or
				grug_core.get_absorb(player) <= 0 then
			return nil
		end
		local expiry
		for _, entry in pairs(absorbs[player:get_player_name()] or {}) do
			if entry.modifiers and (entry.modifiers.dodge_percent or 0) > 0 then
				expiry = math.max(expiry or 0, entry.expiry)
			end
		end
		return expiry and {{id = "talent_turn_aside", expiry_us = expiry}} or nil
	end)
end

local function absorb_particles(pos)
	core.add_particlespawner({
		amount = 6,
		time = 0.15,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.4, 0.4, -0.4),
			max = vector.offset(pos, 0.4, 1.4, 0.4)},
		vel = {min = vector.new(-1, 0, -1), max = vector.new(1, 2, 1)},
		exptime = {min = 0.2, max = 0.5},
		size = {min = 1.5, max = 2.5},
		texture = "default_item_smoke.png^[multiply:#ffe9a0",
	})
end

core.register_on_dieplayer(function(player)
	absorbs[player:get_player_name()] = nil
end)

core.register_on_leaveplayer(function(player)
	absorbs[player:get_player_name()] = nil
end)

--
-- Central damage modifier for players: punch combat marking and dodge,
-- same-level-fitted mob pressure, equipped-armor mitigation for physical hits
-- that have not already applied it, pool scaling of fall and lava damage with
-- race mitigation for dwarf fall damage, then the absorb shield (never for
-- fall, lava or drowning). Runs as an hp-change modifier so a dodge cancels
-- the whole committed hit and absorbs are consumed after mitigation but
-- before HP. Pool shares live in environment_damage.lua.
--

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 then
		return hp_change
	end
	-- Drowning is dealt once per second by environment_damage.lua as a share
	-- of the pool. The engine's own flat drown tick (every 2 s) is cancelled
	-- so it never adds to that; breath depletion stays the engine's.
	if reason.type == "drown" and reason.from == "engine" then
		return 0
	end
	if reason.type == "punch" then
		-- Before the dodge roll: a dodged swing is still an attack.
		grug_core.mark_player_hit(player, reason.object)
		-- Ability punches pre-roll dodge in deal_ability_damage.
		if not grug_core.in_ability_punch and
				math.random() < grug_core.get_dodge_chance(player) then
			grug_core.feed(player, "combat", "You dodge!", "combat:dodge")
			grug_sounds.play("dodge", player)
			return 0
		end
	end
	-- Mob definitions keep their fixed damage curve. The player-side pressure
	-- fit turns that raw curve into the 27-second neutral-pool TTD anchor. PvP
	-- never enters this branch, and foreign entities without a Grudgelands level
	-- keep their native damage unchanged.
	if reason.type == "punch" and reason.object and
			not reason.object:is_player() then
		local entity = reason.object:get_luaentity()
		local pressure_level = entity and
			(entity._grug_attacker_level or entity._grug_level) or nil
		if pressure_level then
			hp_change = -math.max(1, math.ceil(-hp_change *
				grug_core.mob_pressure_scale(pressure_level)))
		end
	end
	-- Equipped armor (items_crafting.md §3.1): PHYSICAL mitigation only.
	-- There is no damage-type system in this game, so `reason.type ==
	-- "punch"` is the whole definition of physical: fall damage has its own
	-- race perk right below, and drowning/lava/starvation must never be
	-- reduced by a breastplate. Runs after the dodge roll (a dodge already
	-- cancelled the hit) and before the absorb shield, so the shield soaks
	-- what armor let through -- shield points are worth full damage, not
	-- pre-mitigation damage.
	-- apply_player_armor owns the clamp and rounding formula. PvP melee
	-- applies that formula to its full swing itself; its official
	-- custom_type skips only this duplicate armor step. Dodge above,
	-- absorb below and later hp callbacks still run normally.
	if reason.type == "punch" and
			reason.custom_type ~= grug_core.ARMOR_APPLIED_CUSTOM_TYPE then
		local attacker_level
		if grug_core.in_ability_punch then
			attacker_level = ability_attacker_level
		elseif reason.object and reason.object:is_player() then
			attacker_level = grug_core.get_player_level(reason.object)
		elseif reason.object then
			local entity = reason.object:get_luaentity()
			attacker_level = entity and
				(entity._grug_attacker_level or entity._grug_level) or nil
		end
		if attacker_level then
			hp_change = -grug_core.apply_player_armor(
				player, -hp_change, attacker_level)
		end
	end
	-- Scale the engine's native impact result to the current pool. The native
	-- scale's 20 damage is one full pool; sufficiently severe impacts remain
	-- lethal because this deliberately has no 100% cap.
	if reason.type == "fall" then
		local properties = player:get_properties() or {}
		local max_hp = tonumber(properties.hp_max) or 0
		if max_hp > 0 then
			hp_change = -math.ceil(max_hp * -hp_change / 20)
		end
		-- Dwarf passive (world.md §7): -20%.
		local mult = grug_core.get_race_perk(player, "fall_damage_mult")
		if mult then
			hp_change = -math.max(1, math.ceil(-hp_change * mult))
		end
	end
	-- Lava (Round 24 ruling 24): the engine's once-per-second node-damage tick
	-- keeps its cadence, but its flat damage_per_second is REPLACED by 20% of
	-- the actual pool. The engine takes the strongest damaging node among the
	-- body points, so several lava nodes still make one hit per second.
	if grug_core.is_engine_lava_damage(reason) then
		local properties = player:get_properties() or {}
		local max_hp = tonumber(properties.hp_max) or 0
		if max_hp > 0 then
			hp_change = -grug_core.lava_damage(max_hp)
		end
	elseif reason.type == "node_damage" then
		-- The same for a pool-damage node (Round 36, the rift's void).
		local properties = player:get_properties() or {}
		local share = grug_core.node_pool_damage(reason,
			tonumber(properties.hp_max) or 0)
		if share and share > 0 then hp_change = -share end
	end
	-- Absorb shield soaks the remaining damage of every source except fall,
	-- lava and drowning (ruling 24).
	local absorbed = false
	if hp_change < 0 and not grug_core.bypasses_absorb(reason) and
			grug_core.get_absorb(player) > 0 then
		absorbed = true
		local name = player:get_player_name()
		local entries = absorbs[name]
		local ordered = {}
		for id, entry in pairs(entries) do ordered[#ordered + 1] = {id, entry} end
		table.sort(ordered, function(a, b)
			if a[2].expiry == b[2].expiry then return a[1] < b[1] end
			return a[2].expiry < b[2].expiry
		end)
		local remaining = -hp_change
		for index = 1, #ordered do
			local id, entry = ordered[index][1], ordered[index][2]
			local soak = math.min(entry.amount, remaining)
			entry.amount = entry.amount - soak
			remaining = remaining - soak
			if entry.amount <= 0 then entries[id] = nil end
			if remaining <= 0 then break end
		end
		hp_change = -remaining
		absorb_particles(player:get_pos())
		-- The shield's clang marks a hit (melee, ability, projectile), not a
		-- damage-over-time tick.
		if reason.type == "punch" then grug_sounds.play("block", player) end
		if next(entries) == nil then absorbs[name] = nil end
	end
	-- PvP contact (pvp-plan ruling 7a): a player's hit that cost HP or absorb.
	-- A dodge returned above; a mob's hit has no player object.
	if (hp_change < 0 or absorbed) and reason.type == "punch" and
			grug_core.pvp_hit_landed and reason.object and
			reason.object ~= player and reason.object:is_player() then
		grug_core.pvp_hit_landed(reason.object, player)
	end
	-- A player's melee hit on a player sounds by weapon kind, like a hit on a
	-- mob (mobs_redo's on_punch); an ability punch plays its own cue.
	if hp_change < 0 and reason.type == "punch" and not grug_core.in_ability_punch and
			reason.object and reason.object ~= player and reason.object:is_player() then
		grug_sounds.play(grug_core.melee_hit_sound(reason.object), player)
	end
	return hp_change
end, true)

-- Non-modifier callbacks receive the final change after dodge, armor and
-- absorption. The engine has not stored it yet, so the consumer predicts the
-- post-hit HP and can reject lethal hits without reviving the player.
core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" and
			player:get_hp() + hp_change > 0 then
		for index = 1, #settled_incoming_callbacks do
			settled_incoming_callbacks[index](player, -hp_change, reason)
		end
	end
	if grug_core.trinket_after_hit then grug_core.trinket_after_hit(player, hp_change, reason) end
end, false)
