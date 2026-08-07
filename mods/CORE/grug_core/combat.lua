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
local function check_switch(mob_ent)
	local threat = mob_ent.temp and mob_ent.temp.grug_threat
	if not threat or type(mob_ent.do_attack) ~= "function" then
		return
	end
	-- Throttle (see above). Runtime-only key in the same temp table the
	-- threat lives in, so it dies with the mob's activation.
	local now = grug_core.mono_time()
	if now - (mob_ent.temp.grug_switch_at or -math.huge) < SWITCH_INTERVAL then
		return
	end
	mob_ent.temp.grug_switch_at = now
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
	local ok, err = pcall(target.punch, target, attacker, 1.4, {
		full_punch_interval = 1.4,
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

function grug_core.heal_player(healer, target, amount)
	local hp = target:get_hp()
	if hp <= 0 then
		return 0
	end
	if math.random() < grug_core.get_crit_chance(healer) then
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
-- combat marking, then race mitigation (dwarf fall damage), then the
-- absorb shield. Runs as an hp change modifier so a dodge cancels the
-- whole hit before armor/sounds and absorbs are consumed before HP.
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
