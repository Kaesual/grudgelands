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

-- Damage reduction from equipped armor, in PERCENT (0..60). 1 armor point =
-- 1% reduction, summed over the four armor slots and hard-capped at 60%
-- (items_crafting.md §3.1, combat_stats.md §2). grug_inventory overrides
-- this with the real accessor; grug_core itself must not know about
-- equipment slots or item fields.
function grug_core.get_armor_percent(player)
	return 0
end

--
-- The equipment seam (weapon-slot design C4). grug_abilities needs to know
-- what is in the two hand slots and when it changes; grug_inventory owns the
-- slots. Neither depends on the other, so the contract lives here.
--
-- get_equipped_weapon/get_equipped_offhand are STUBS returning nil (same
-- pattern as get_armor_percent above) -- nil means "empty slot", and an empty
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
-- WP5's affix re-roll, WP11's respec unequipping what the new class may not
-- wear. grug_inventory's class-change unequip already writes lists exactly that
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
local notify_pending = {} -- player name -> true when a nested call arrived
local warned_unconditional = false

local function run_equipment_callbacks(player, listname)
	for _, func in ipairs(equipment_change_callbacks) do
		func(player, listname)
	end
end

-- Internal: grug_inventory fires this from grug_inventory.equipment_changed,
-- after it dropped its caches, so a callback already reads the NEW equipment.
function grug_core.notify_equipment_change(player, listname)
	local name = player:get_player_name()
	if notifying[name] then
		notify_pending[name] = true
		return
	end
	notifying[name] = true
	run_equipment_callbacks(player, listname)
	if notify_pending[name] then
		notify_pending[name] = nil
		-- Second and final pass: whatever a consumer changed from inside the
		-- first one is now visible to all of them. `nil` because the nested
		-- write is by definition a different list than the one that started it.
		run_equipment_callbacks(player, nil)
		if notify_pending[name] and not warned_unconditional then
			warned_unconditional = true
			core.log("warning", "[grug_core] an on_equipment_change consumer " ..
				"calls equipment_changed unconditionally -- the notification " ..
				"is capped at two passes, fix the consumer")
		end
		notify_pending[name] = nil
	end
	notifying[name] = nil
end

-- Flat weapon-damage bonus from Strength (combat_stats.md §2:
-- melee damage = weapon damage + floor(Str/10)). Consumed by the
-- auto-attack patch in mobs/api.lua on_punch.
function grug_core.get_melee_bonus(player)
	return 0
end

-- Race passive lookup (world.md §7); grug_classes overrides this with the
-- real registry accessor. Returns the perk value or nil.
function grug_core.get_race_perk(player, key)
	return nil
end

--
-- Combat state: in combat = dealt or received damage in the last 5 s.
-- Shared definition for resource regen (WP4), recovery (combat_stats §5)
-- and mob leashing (WP6).
--

grug_core.COMBAT_TIMEOUT = 5

-- Monotonic seconds since server start. ONE clock for every combat timer
-- shared between grug_core and grug_mobs (taunt force window, leash contact
-- timer): core.get_us_time() is unaffected by the day/night cycle and by
-- time-of-day changes, unlike core.get_gametime(). The only deliberate
-- gametime user is the player drop tag (grug_mobs), which must survive an
-- unload — see the note there.
function grug_core.mono_time()
	return core.get_us_time() / 1e6
end

local last_combat = {} -- player name -> us timestamp of the last hit

function grug_core.mark_in_combat(player)
	last_combat[player:get_player_name()] = core.get_us_time()
end

function grug_core.in_combat(player)
	local t = last_combat[player:get_player_name()]
	return t ~= nil and
		(core.get_us_time() - t) < grug_core.COMBAT_TIMEOUT * 1e6
end

core.register_on_leaveplayer(function(player)
	last_combat[player:get_player_name()] = nil
end)

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
local function valid_target(mob_ent, name)
	local player = core.get_player_by_name(name)
	if not player or not player:is_player() or player:get_hp() <= 0 then
		return nil
	end
	local mpos = mob_ent.object and mob_ent.object:get_pos()
	local ppos = player:get_pos()
	if not mpos or not ppos then
		return nil
	end
	if vector.distance(mpos, ppos) > grug_core.THREAT_RANGE then
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
	-- respects (api.lua:2771ff), so re-check them here: threat must never
	-- turn a passive critter, a child or a fleeing mob into an attacker, and
	-- a mob without an attack_type cannot fight at all.
	if mob_ent.passive or mob_ent.child or not mob_ent.attack_type or
			mob_ent.state == "flop" or mob_ent.state == "runaway" then
		return
	end
	if (mob_ent.temp.grug_forced_until or 0) > now then
		return -- inside a taunt window: the target is locked
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
	if cur and core.is_player(cur) then
		local cur_name = cur:get_player_name()
		if cur_name == best_name then
			return
		end
		if best <= (threat[cur_name] or 0) * grug_core.THREAT_SWITCH_FACTOR then
			return
		end
	end
	-- force = true: overrides an existing target (mobs/api.lua:213).
	mob_ent:do_attack(best_obj, true)
	-- A fresh target means fresh contact — the leash clock restarts.
	mob_ent.temp.grug_last_contact = now
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

-- Accumulate threat for one player on one mob, then re-check the target.
-- Base threat (= damage dealt) is added in exactly ONE place, see
-- run_player_hit_mob below.
function grug_core.add_threat(mob_ent, player, amount)
	if not mob_ent or not mob_ent.object or not amount or amount <= 0 then
		return
	end
	if not player or not core.is_player(player) then
		return
	end
	local threat = threat_table(mob_ent)
	local name = player:get_player_name()
	threat[name] = (threat[name] or 0) + amount
	check_switch(mob_ent)
end

-- Drops the whole table (leash reset).
function grug_core.clear_threat(mob_ent)
	if mob_ent and mob_ent.temp then
		mob_ent.temp.grug_threat = nil
		mob_ent.temp.grug_forced_until = nil
	end
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
	local threat = amount * grug_core.HEAL_THREAT_FACTOR
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
			not core.is_player(player) then
		return
	end
	local threat = threat_table(mob_ent)
	local name = player:get_player_name()
	local want = top_amount(threat) * 1.1
	threat[name] = math.max(threat[name] or 0, want)
	local now = grug_core.mono_time()
	mob_ent.temp.grug_forced_until = now + grug_core.TAUNT_FORCE_TIME
	mob_ent.temp.grug_last_contact = now
end

--
-- Player hit mob hook: fired by grug_mobs' do_punch wrapper for every player
-- punch that reaches a mob (rage generation, combat marking, threat).
-- func(player, mob_ent, damage)
--

local hit_mob_callbacks = {}

function grug_core.register_on_player_hit_mob(func)
	table.insert(hit_mob_callbacks, func)
end

function grug_core.run_player_hit_mob(player, mob_ent, damage)
	grug_core.mark_in_combat(player)
	-- THE ONE base-threat site. Every player hit on a mob passes through
	-- here: auto-attacks go player -> object:punch -> grug_mobs' do_punch
	-- wrapper -> here, and ability damage goes deal_ability_damage ->
	-- object:punch -> the SAME wrapper -> here. Adding damage-as-threat in
	-- deal_ability_damage as well would double-count every ability hit;
	-- that call only adds the tank multiplier BONUS on top (see there).
	if mob_ent then
		grug_core.add_threat(mob_ent, player, damage or 0)
		-- Player contact for the leash (aggro.lua): being hit counts.
		mob_ent.temp = mob_ent.temp or {}
		mob_ent.temp.grug_last_contact = grug_core.mono_time()
	end
	for _, func in ipairs(hit_mob_callbacks) do
		func(player, mob_ent, damage)
	end
end

--
-- Dealing ability damage. Rolls the attacker's crit (×1.5) and — against
-- players — the target's dodge, then applies the result via object:punch
-- with a full punch interval (factor 1), so armor groups, knockback and
-- mob death handling (XP/loot via on_death) keep working.
-- opts: {threat_mult = n} extra threat factor (tank abilities ×3).
-- Returns the damage dealt (0 on dodge).
--

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
-- Auto-attack cadence (combat_stats.md §2, implemented 2026-08-07). Held
-- melee = auto-attack at weapon speed; every accepted swing lands at FULL
-- weapon damage, everything arriving faster is discarded whole.
--
-- Why the clock lives HERE and not in mobs_redo's `tflp`: with the dig
-- button held the client punches every `object_hit_delay` = 0.2 s
-- (engine `src/client/game_internal.h`) and the server resets its punch
-- timer on EVERY punch packet (`PlayerSAO::resetTimeFromLastPunch`,
-- `src/network/serverpackethandler.cpp` INTERACT_START_DIGGING) — so `tflp`
-- measures the time between CLIENT punches, never between hits that landed,
-- and it sits at ~0.2 s forever while the button is down. mobs_redo scaled
-- damage by `tflp / full_punch_interval`, which therefore collapsed to
-- 0.2/fpi and made every weapon below a bronze sword deal a permanent,
-- feedback-less 0 against an armor-100 mob (all feedback AND the health
-- subtraction sit behind mobs_redo's `damage >= 1`). Gating on `tflp` alone
-- would have dropped EVERY held punch instead. So: our own clock, per
-- player, in server time.
--

-- Tick slack: half a client punch step (0.2 s, see above). While the button
-- is held the punches this gate sees are spaced at MULTIPLES of 0.2 s from
-- the last accepted swing, so a weapon interval that is not a multiple of
-- 0.2 can only ever be served by the next tick at or past it — accepting
-- `interval` exactly would round every weapon UP. Subtracting half a step
-- rounds to the NEAREST tick instead: fpi 0.9 accepts the 0.8 s packet
-- (0.8 >= 0.9 - 0.1) for an effective 0.8 s cadence, while fpi 1.0 still
-- rejects it (0.8 < 0.9) and lands on 1.0 s. A multiplicative tolerance
-- cannot do this — 0.9 * 0.9 = 0.81 rejects the 0.8 s packet and the 0.9 s
-- weapon silently swings at 1.0 s.
local SWING_SLACK = 0.1

local last_swing = {} -- player name -> mono_time of the last accepted swing

-- Consumes the swing clock. true = accepted auto-attack (clock stamped),
-- false = the punch arrived too early and the caller must discard it
-- ENTIRELY (no damage, no wear, no sound, no threat — button spam does
-- nothing). `interval` is the weapon's full_punch_interval.
-- Per PLAYER, not per mob: attack speed is a property of the attacker, so
-- switching targets must not hand out a free swing.
function grug_core.accept_melee_swing(player, interval)
	local name = player:get_player_name()
	local now = grug_core.mono_time()
	local last = last_swing[name]
	if last and now - last < interval - SWING_SLACK then
		return false
	end
	last_swing[name] = now
	return true
end

core.register_on_leaveplayer(function(player)
	last_swing[player:get_player_name()] = nil
end)

-- Crit roll for a finished auto-attack (combat_stats.md §2): same ×1.5 and
-- the same particle burst as ability crits above — auto-attacks were the one
-- damage source that could never crit. `target` only supplies the particle
-- position. Returns the (possibly critical) damage.
--
-- The crit result is FLOORED, exactly like deal_ability_damage's, so the two
-- crit paths cannot disagree about what a ×1.5 on the same number is worth.
-- Only the crit branch floors — a non-crit hit is handed back untouched,
-- because the caller's damage is still mid-computation (mobs_redo's armor
-- scaling produces fractions on purpose and rounds at the very end).
function grug_core.melee_crit(player, damage, target)
	if damage <= 0 or math.random() >= grug_core.get_crit_chance(player) then
		return damage
	end
	local pos = target and target:get_pos()
	if pos then
		crit_particles(pos)
	end
	return math.floor(damage * 1.5)
end

--
-- Fractional melee remainder accumulator (combat_stats.md §2, WP38). The
-- proportional-damage revision accepts sub-1 swings, and flooring each
-- punch separately leaks the fraction forever — a 3-damage weapon at a 1 s
-- interval would deal 3 DPS instead of the proportional 3.75. So fractions
-- accumulate per player and are floored only when applied: the health
-- subtraction and the death check run on the accumulated INTEGER, never on
-- the raw fraction ("the rounding hole is closed by a remainder
-- accumulator, never by a minimum").
--
-- One accumulator per player, holding a target object id and a remainder
-- below 1; a punch on a DIFFERENT target resets the remainder to 0 first.
-- Switching targets forfeits at most 0.999 damage — deliberate (that is
-- what keeps this a single field instead of a per-target table) — so a
-- target-guard player slapping a row of rabbits hands each of them the same
-- full fresh accumulator, and nothing sharper than 1 HP is ever lost.
--
-- Target identity is `ObjectRef:get_guid()` (lua_api.md:9050): the player
-- name for players, a unique collision-free string for entities, stable
-- across reloads, so a remainder survives neither an object swap nor a mob
-- respawn.
--
-- Runtime-only by design. A stale entry costs at most 0.999 damage of the
-- NEXT punch, so a player who logs off mid-fight has no meaningful remainder
-- to collect — the entry is dropped on leave, like the swing clock above.
--
-- Consumed by the api.lua GRUG PATCH (#22) on the cadence path (the
-- accumulated integer doubles as the death-check gate there) and, later, by
-- the PvP melee path (same pipeline, combat_stats.md §2).
--

local melee_remainder = {} -- player name -> {target = guid, remainder = [0,1)}

-- Applies the fractional part of a melee hit against `target`. Returns the
-- integer damage to subtract from the target's health: `remainder +
-- raw_damage` floored, with the new remainder carried for the next punch.
-- A non-positive raw hit returns 0 WITHOUT touching state. `raw_damage` is
-- the mobs_redo damage after armor scaling and the crit roll.
function grug_core.apply_accumulated_melee(player, target, raw_damage)
	if raw_damage <= 0 then
		return 0
	end
	local name = player:get_player_name()
	local guid = target:get_guid()
	local entry = melee_remainder[name]
	if not entry or entry.target ~= guid then
		-- Different target: reset first (at most 0.999 damage forfeited).
		entry = {target = guid, remainder = 0}
		melee_remainder[name] = entry
	end
	local total = entry.remainder + raw_damage
	local applied = math.floor(total)
	entry.remainder = total - applied
	return applied
end

core.register_on_leaveplayer(function(player)
	melee_remainder[player:get_player_name()] = nil
end)

-- True while an ability punch is running — lets the rage-on-hit hook skip
-- ability hits (rage comes from auto-attacks only, classes.md §1) and the
-- central dodge modifier skip the roll (abilities pre-roll it below).
grug_core.in_ability_punch = false

function grug_core.deal_ability_damage(attacker, target, amount, opts)
	opts = opts or {}
	if target:is_player() then
		-- Friendly fire: defense in depth — the ability kits filter their
		-- targets already, but never let same-faction damage through here.
		if attacker:is_player() then
			local af = grug_core.get_player_faction(attacker:get_player_name())
			local tf = grug_core.get_player_faction(target:get_player_name())
			if af and tf and af == tf then
				return 0
			end
		end
		-- Dodge is pre-rolled here for ability punches so the return value
		-- and the threat report reflect what actually landed; the central
		-- modifier skips the roll while in_ability_punch is set.
		if math.random() < grug_core.get_dodge_chance(target) then
			core.chat_send_player(target:get_player_name(),
				core.colorize("#aaaaaa", "You dodge!"))
			grug_core.mark_in_combat(attacker)
			grug_core.mark_in_combat(target)
			return 0
		end
	end
	if math.random() < grug_core.get_crit_chance(attacker) then
		amount = math.floor(amount * 1.5)
		crit_particles(target:get_pos())
	end
	grug_core.mark_in_combat(attacker)
	-- pcall + flag restore: an error mid-punch must not leave the sticky
	-- flag set (that would silently kill rage generation server-wide).
	grug_core.in_ability_punch = true
	-- `punch_attack_uses = 0` is not cosmetic: mobs_redo's on_punch runs an
	-- UNGUARDED wear block (mods/ENTITIES/mobs/api.lua:2829-2850) that adds
	-- floor(fpi / 75 * 9000) wear to the WIELDED stack and writes it back with
	-- set_wielded_item -- and during a cast the wielded stack IS the ability
	-- tool. At fpi 1.4 that is 167, not 168: 1.4/75*9000 is 167.99999999999997
	-- in doubles (BACKLOG.md's WP35 row, T0, quotes 168/~390 -- measured,
	-- it is 167 and the tool breaks on cast 393). Abilities with a cooldown
	-- hid it by accident (the cooldown ticker overwrites the wear every step
	-- and zeroes it at the end); Mighty Blow has cooldown 0, so its own icon
	-- grew a wear bar and the tool broke after 393 landed hits, vanishing
	-- from the hotbar until a relog
	-- re-granted it. api.lua:2836-2838 reads exactly this field as "no wear",
	-- so one line switches the whole path off for every ability punch.
	local ok, err = pcall(target.punch, target, attacker, 1.4, {
		full_punch_interval = 1.4,
		punch_attack_uses = 0,
		damage_groups = {fleshy = amount},
	}, nil)
	grug_core.in_ability_punch = false
	if not ok then
		core.log("warning", "[grug_core] ability punch failed: " .. tostring(err))
		return 0
	end
	-- BONUS-ONLY threat site. The punch above already ran through grug_mobs'
	-- do_punch wrapper -> run_player_hit_mob, which added the base threat
	-- (= damage) exactly once. Adding `amount * threat_mult` here would
	-- double-count the base for every ability, so only the extra factor of a
	-- tank ability (×3 -> +2×damage) is added on top; ×1 adds nothing.
	local mult = opts.threat_mult or 1
	if mult ~= 1 then
		local ent = target:get_luaentity()
		if ent then
			grug_core.add_threat(ent, attacker, amount * (mult - 1))
		end
	end
	return amount
end

--
-- Healing a player. Rolls the healer's crit (×1.5), clamps to max HP and
-- reports heal threat. Returns the effective healing done.
--
-- opts.no_crit skips the crit roll for sources that must heal a FLAT amount:
-- consumables are specified as a percentage of max HP (items_crafting.md
-- §3.6 — the vendor's weak potion is exactly 15%), so letting the drinker's
-- crit chance multiply it would make the number in the tooltip a lie.
-- WP10's alchemy potions want the same flag.
--

function grug_core.heal_player(healer, target, amount, opts)
	opts = opts or {}
	local hp = target:get_hp()
	if hp <= 0 then
		return 0
	end
	if not opts.no_crit and math.random() < grug_core.get_crit_chance(healer) then
		amount = math.floor(amount * 1.5)
		crit_particles(target:get_pos())
	end
	local max_hp = target:get_properties().hp_max
	local effective = math.min(amount, max_hp - hp)
	if effective > 0 then
		target:set_hp(hp + effective)
		grug_core.add_heal_threat(healer, target, effective)
	end
	return effective
end

--
-- Absorb shields (Power Word: Shield, classes.md §5). One shield per
-- player; a new one replaces the old (no stacking). Soaked lazily by the
-- central hp change modifier below — no timer entity, the expiry is
-- checked whenever the shield would matter.
--

local absorbs = {} -- player name -> {amount = n, expiry = us time}

function grug_core.set_absorb(player, amount, duration)
	absorbs[player:get_player_name()] = {
		amount = amount,
		expiry = core.get_us_time() + duration * 1e6,
	}
end

-- Remaining absorb amount (0 when none/expired).
function grug_core.get_absorb(player)
	local name = player:get_player_name()
	local a = absorbs[name]
	if not a then
		return 0
	end
	if core.get_us_time() > a.expiry then
		absorbs[name] = nil
		return 0
	end
	return a.amount
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
-- Central damage modifier for players: dodge roll (mob melee, PvP) plus
-- combat marking, then equipped-armor mitigation (physical hits only), then
-- race mitigation (dwarf fall damage), then the absorb shield. Runs as an hp
-- change modifier so a dodge cancels the whole hit before armor/sounds, and
-- absorbs are consumed after mitigation but before HP.
--

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 then
		return hp_change
	end
	if reason.type == "punch" then
		grug_core.mark_in_combat(player)
		-- Ability punches pre-roll dodge in deal_ability_damage.
		if not grug_core.in_ability_punch and
				math.random() < grug_core.get_dodge_chance(player) then
			core.chat_send_player(player:get_player_name(),
				core.colorize("#aaaaaa", "You dodge!"))
			return 0
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
	-- math.ceil is deliberate: armor alone can never reduce a landed hit to
	-- 0 damage, however much of it a tank stacks.
	--
	-- The 60% clamp is applied HERE as well, not only in grug_inventory's
	-- override: this modifier is registered with `true` (it may raise HP), so
	-- an override that ever forgot the cap and returned pct > 100 would turn
	-- a punch into a heal. Cheap invariant, catastrophic failure mode
	-- (WP14's shields are already slated to extend that override).
	--
	-- (100 - pct) / 100, NOT (1 - pct / 100): the latter double-rounds,
	-- because 1 - pct/100 is not exactly representable as a double (e.g.
	-- pct 42, dmg 50 gave 30 instead of 29). -hp_change and pct are whole
	-- numbers and their product stays far inside the exact-integer range, so
	-- this division is exact whenever the true result is an integer.
	if reason.type == "punch" then
		local pct = math.min(60, grug_core.get_armor_percent(player) or 0)
		if pct > 0 then
			hp_change = -math.ceil(-hp_change * (100 - pct) / 100)
		end
	end
	-- Dwarf passive (world.md §7): -20% fall damage, before the absorb so
	-- the shield only soaks what would actually land.
	if reason.type == "fall" then
		local mult = grug_core.get_race_perk(player, "fall_damage_mult")
		if mult then
			hp_change = -math.floor(-hp_change * mult)
		end
	end
	-- Absorb shield soaks any remaining damage (all sources).
	if hp_change < 0 and grug_core.get_absorb(player) > 0 then
		local name = player:get_player_name()
		local a = absorbs[name]
		local soak = math.min(a.amount, -hp_change)
		a.amount = a.amount - soak
		hp_change = hp_change + soak
		absorb_particles(player:get_pos())
		if a.amount <= 0 then
			absorbs[name] = nil
		end
	end
	return hp_change
end, true)
