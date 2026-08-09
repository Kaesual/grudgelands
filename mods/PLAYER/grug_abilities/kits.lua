-- The MVP class kits (docs/design/classes.md §3–§5). Numbers live in the
-- design doc — change them there first.

--
-- Targeting helpers. The ability item's `range` limits pointed_thing, so
-- cast functions can rely on it for the pointed path; the soft-target-lock
-- fallback re-checks range explicitly (grug_abilities.get_range).
--

local function mob_ent(obj)
	if obj:is_player() then
		return nil
	end
	local ent = obj:get_luaentity()
	return (ent and ent._cmi_is_mob) and ent or nil
end

-- Is obj a valid enemy for user right now? (mob not of the own faction /
-- hostile living player)
local function valid_enemy(user, obj)
	if obj:is_player() then
		return grug_factions.hostile(user, obj) and obj:get_hp() > 0
	end
	local ent = mob_ent(obj)
	if not ent or (ent.health or 0) <= 0 then
		return false
	end
	return not (ent._grug_faction and
		ent._grug_faction == grug_factions.get_faction(user))
end

local function valid_ally(user, obj)
	return obj:is_player() and obj ~= user
		and grug_factions.same_faction(user, obj)
		and obj:get_hp() > 0
end

local function in_lock_range(user, obj, def)
	return vector.distance(user:get_pos(), obj:get_pos())
		<= grug_abilities.get_range(user, def)
end

-- Eye-to-body line of sight — the pointed path gets this for free from
-- the engine raycast; the lock fallback must check it itself, otherwise
-- ranged abilities could be spammed through walls at a locked target.
local function lock_los(user, obj)
	local eye = user:get_pos()
	eye.y = eye.y + (user:get_properties().eye_height or 1.5)
	return core.line_of_sight(eye, vector.offset(obj:get_pos(), 0, 1, 0))
end

-- Attackable target: the pointed object if valid (locks it), otherwise the
-- soft-locked enemy target if still valid, in range and in line of sight.
local function enemy_target(user, pointed, def)
	if pointed and pointed.type == "object" and pointed.ref
			and valid_enemy(user, pointed.ref) then
		grug_abilities.set_target(user, pointed.ref, false)
		return pointed.ref
	end
	local obj = grug_abilities.get_target(user, false)
	if obj and valid_enemy(user, obj)
			and in_lock_range(user, obj, def) and lock_los(user, obj) then
		grug_abilities.set_target(user, obj, false) -- refresh the lock
		return obj
	end
	return nil
end

-- Friendly target for heals: pointed ally (locks it), otherwise the
-- soft-locked ally if still valid and in range — this is what makes
-- healing moving allies workable — otherwise self. Deliberately no LOS
-- check on the fallback: healing the ally who just kited around a tree
-- is the point of the lock.
local function heal_target(user, pointed, def)
	if pointed and pointed.type == "object" and pointed.ref
			and valid_ally(user, pointed.ref) then
		grug_abilities.set_target(user, pointed.ref, true)
		return pointed.ref
	end
	local obj = grug_abilities.get_target(user, true)
	if obj and valid_ally(user, obj)
			and in_lock_range(user, obj, def) then
		grug_abilities.set_target(user, obj, true) -- refresh the lock
		return obj
	end
	return user
end

--
-- Particle helpers (existing textures only; own effects are Phase 3).
--

local function beam(user, target, texture)
	local from = user:get_pos()
	from.y = from.y + (user:get_properties().eye_height or 1.5)
	local to = vector.offset(target:get_pos(), 0, 1, 0)
	local dist = vector.distance(from, to)
	local steps = math.max(2, math.floor(dist * 2))
	local dir = vector.direction(from, to)
	for i = 1, steps do
		core.add_particle({
			pos = vector.add(from, vector.multiply(dir, i * dist / steps)),
			velocity = vector.new(0, 0, 0),
			expirationtime = 0.25,
			size = 2.5,
			texture = texture,
			glow = 12,
		})
	end
end

local function burst(pos, texture, amount)
	core.add_particlespawner({
		amount = amount or 12,
		time = 0.2,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.5, 0, -0.5),
			max = vector.offset(pos, 0.5, 1, 0.5)},
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = texture,
		glow = 10,
	})
end

--
-- Root/slow effects (Frost Nova, Hamstring). Mobs: grug_mobs.root/slow —
-- restore runs as a reload-safe countdown inside the mob's do_custom (a
-- core.after timer here once persisted permanently-immobile mobs into the
-- world file). Players (PvP): a staged physics override — stages run in
-- sequence (e.g. root, then slow), a newer effect replaces the running one
-- via the token, and physics overrides reset on rejoin so a relog inside
-- the window cannot stick. MVP caveat: the override clobbers other speed
-- modifiers — fine while none exist.
--

local speed_fx = {} -- player name -> {speed = n, expiry = us} of the active stage

-- stages: list of {speed = n, jump = n, time = seconds}; restores to 1/1
-- after the last stage. A new effect replaces the running one UNLESS the
-- currently active stage is stronger (lower speed) — a Hamstring must not
-- lift an ally's Frost Nova root. Chain ownership is tracked by record
-- identity (not a counter), so orphaned core.after chains from before a
-- relog can never hijack a later effect.
local function apply_player_speed_stages(target, stages)
	local name = target:get_player_name()
	local active = speed_fx[name]
	if active and core.get_us_time() < active.expiry
			and active.speed < stages[1].speed then
		return -- a stronger snare stage is running; keep it
	end
	local rec = {}
	speed_fx[name] = rec
	local run
	run = function(i)
		local p = core.get_player_by_name(name)
		if not p or speed_fx[name] ~= rec then
			return -- left, or a newer effect took over
		end
		local stage = stages[i]
		if not stage then
			p:set_physics_override({speed = 1, jump = 1})
			speed_fx[name] = nil
			return
		end
		rec.speed = stage.speed
		rec.expiry = core.get_us_time() + stage.time * 1e6
		p:set_physics_override({speed = stage.speed, jump = stage.jump or 1})
		core.after(stage.time, function()
			run(i + 1)
		end)
	end
	run(1)
end

-- NB physics overrides are not persisted: a relog inside the window
-- clears the root/slow. Accepted MVP caveat — reconnecting takes longer
-- than any current effect (max 7 s), so it is no practical escape.
core.register_on_leaveplayer(function(player)
	speed_fx[player:get_player_name()] = nil
end)

--
-- Universal: the auto-attack (weapon-slot design E1-E8).
--
-- Auto-attack is an ORDINARY ability item. It has to be: an item with an
-- on_use disables punching entirely for as long as it is selected (the client
-- sends INTERACT_USE regardless of what is pointed at, game.cpp:2785-2789), so
-- with abilities in the hotbar there was no way for the weapon SLOT to feed a
-- held-button auto-attack. As a skill it reads the slot like every other one:
-- weapon damage, swing speed and skin all come from the equipped item, and
-- swapping the weapon changes all three without a relog.
--
-- Two melee streams exist, and WP38 (combat_stats.md §2 "Melee timing") made
-- them deliberately asymmetric:
--
-- The HELD-BUTTON path (any wielded tool, or a bare hand) runs through the
-- api.lua GRUG PATCH (mods/ENTITIES/mobs/api.lua on_punch). It deals
-- `weapon damage × clamp(tflp / full_punch_interval, 0, 1)` — while the dig
-- key is held the client sends one punch packet every 0.2 s, so each packet
-- deals a fifth of a swing, and grug_core's remainder accumulator carries
-- the fractions until they add up to a full hit point (the design doc
-- rejects every "minimum damage" alternative: with the button held, a
-- round-up floor would make spam strictly better, and worst exactly where
-- the numbers are smallest). On top of the proportion: the Strength bonus
-- (grug_core.get_melee_bonus), the crit roll (grug_core.melee_crit),
-- 12 × fraction rage per punch that LANDED, base threat and the soft target
-- lock, all through grug_mobs' do_punch wrapper
-- (grug_mobs/init.lua -> grug_core.run_player_hit_mob). What it still
-- lacks is the source and the convenience: the damage comes from the WIELDED
-- stack rather than the weapon slot, which is exactly B1's "single, fixed
-- source" being bypassed; it wears that stack (the Strike punches with
-- punch_attack_uses = 0); it carries no ability threat multiplier; and it
-- cannot swing at the lock — the player has to keep the mob pointed, with no
-- range/LOS test and no auto-repeat.
--
-- The swing LOOP is generic: it swings the SLOT weapon at FULL damage once
-- per the weapon's own full_punch_interval (E3's loop; arm_repeat carries
-- the fraction of a late step so the mean cadence is the interval exactly),
-- with the ability's range/LOS checks and the target lock (E4). What a
-- swing DOES is the live selected swing skill's business (classes.md §2b):
-- Strike is the plain hit; Mighty Blow and Hamstring ride along on a LANDED
-- swing as procs — one effect per swing, decided from the hotbar selection
-- read every swing, so a mid-fight switch re-arms the proc without
-- interrupting the loop. A click on a swing skill while the loop runs is
-- RE-ARM only (refresh_melee_target: refresh the lock, do not swing); a
-- second click stops. Cast skills are discrete — a cast runs and is done,
-- they never ride along.
--
-- What WP38 removed between them: the all-or-nothing cadence gate of
-- 2026-08-07 and the shared per-player melee clock of 2026-08-08. The clock
-- was WINNER-TAKES-ALL by requested interval — whoever asked with the
-- shorter interval stamped it often enough that the slower asker was
-- refused forever (a held bare-hand dig starved the greataxe Strike loop,
-- measured 0.39x over 30 s) — and it could not gate a punch on a PLAYER
-- at all, so against another player the held-button path stacked with the
-- Strike. The revision's answer is not a better clock: the two streams
-- cannot coexist structurally, and the loop follows the selected ability
-- item (classes.md §2b) — deleting the clock AND landing the one-stream
-- rule is THIS task. Melee damage is now the same formula in both streams,
-- and nothing is discarded.
--
-- docs/design/combat_stats.md §2 records the same split.
--

-- An empty weapon slot is an empty slot (B1): no fallback to whatever is in
-- the hand, and the swing is a fist (C2: an empty slot makes skills weak, never
-- uncastable).
--
-- "A fist" is not a number to pick — it is THIS game's hand item, and the
-- engine's own bare-handed punch reads exactly these capabilities. The
-- numbers are 0.9 / fleshy 1, and they come from ONE place: this game's own
-- `mods/BASE/default/tools.lua:8-19`, which overrides the hand item. The
-- engine itself supplies neither — builtin's hand
-- (reference_projects/luanti/builtin/game/register.lua:447-451) carries no
-- `tool_capabilities` at all, and the C++ fallback is full_punch_interval
-- **1.4** with an empty damage-group map (src/tool.h:60-72). So a hardcoded
-- 1.0 made an empty slot swing 11 % SLOWER through the Strike than the same
-- character punching bare-handed through the held-button path, for no reason
-- anyone could have found in a design doc — and reading the value is what
-- keeps the two paths equal if default's hand is ever re-tuned.
-- `ItemStack("")` is the hand: an empty stack resolves to the "" item
-- definition, which is what the engine hands a punch that carries no tool.
--
-- Read once after every mod has registered, not at load time: default's
-- override_item runs in BASE and we are in PLAYER, but the ordering is a mod
-- dependency we do not declare, so the values are simply not final yet here.
-- The literals below are the fallback if the hand ever loses its capabilities.
local bare_hand = {damage = 1, interval = 0.9}

core.register_on_mods_loaded(function()
	local caps = ItemStack(""):get_tool_capabilities() or {}
	local damage = caps.damage_groups and caps.damage_groups.fleshy
	if type(damage) == "number" and damage >= 0 then
		bare_hand.damage = damage
	end
	local fpi = caps.full_punch_interval
	if type(fpi) == "number" and fpi > 0 then
		bare_hand.interval = fpi
	end
end)

-- What the equipped weapon is worth this swing: fleshy damage and swing time.
--
-- Read fresh on EVERY swing, never cached in the loop: unequipping mid-fight
-- drops to fist damage rather than stopping the attack, and swapping a
-- greataxe for a dagger changes the cadence from the next swing on (E3).
-- grug_inventory caches the slot itself, so this costs one ItemStack copy.
--
-- get_tool_capabilities() resolves the per-stack meta override before the item
-- definition, which is how WP5's rolled attack-speed affix will reach this
-- without a line of change here.
local function swing_stats(player)
	local stack = grug_core.get_equipped_weapon(player)
	if not stack or stack:is_empty() then
		return bare_hand.damage, bare_hand.interval
	end
	local caps = stack:get_tool_capabilities() or {}
	local damage = caps.damage_groups and caps.damage_groups.fleshy or 0
	local fpi = caps.full_punch_interval
	-- A non-positive interval would make the swing loop fire every step.
	-- Nothing equippable declares one -- but the interval comes out of item
	-- meta, and meta is data.
	if type(fpi) ~= "number" or fpi <= 0 then
		fpi = bare_hand.interval
	end
	return damage, fpi
end

-- What the target has left, in HP -- the honest answer to "did that hit land"
-- (review HIGH 1), under one stated assumption: that nothing else writes the
-- target's health between the two samples. See the end of this comment.
--
-- `grug_core.deal_ability_damage` returns the INTENDED amount
-- (grug_core/combat.lua:628); it returns 0 only for its own two pre-rolls, the
-- friendly-fire refusal and the player dodge. It cannot know what the punch
-- actually applied, and three things routinely eat all of it AFTER it has
-- returned:
--   * a mob whose `do_punch` cancels the punch outright. Every vendor NPC in
--     every capital is one (grug_traders/vendors.lua: plain
--     mobs:register_mob + `do_punch = function() return true end`, which
--     api.lua:2807-2810 takes as "handled" and returns on, BEFORE the wear
--     block, the health subtraction and check_for_death) -- and vendors carry
--     no `_grug_faction`, so valid_enemy below happily accepts them. Gating
--     rage on the return value took a Warrior from 0 to 100 rage in ten
--     seconds on a shopkeeper who never lost a hit point. An evading mob
--     (grug_mobs/aggro.lua) cancels the same way.
--   * `immune_to` (api.lua:2769-2779), which OVERWRITES the damage with the
--     immunity value rather than scaling it.
--   * a player target with PvP off: PlayerSAO::punch returns immediately when
--     `enable_pvp` is false (player_sao.cpp:462-469) -- no hp change, and not
--     even an on_punchplayer callback.
-- HP before minus HP after sees all three, and it is the same measurement for
-- a mob and for a player. Mobs keep their hit points in `self.health` (the
-- object's own hp is not what mobs_redo subtracts), and that field survives the
-- entity removal of a lethal blow -- check_for_death never resets it -- so the
-- killing hit is still counted.
--
-- THE ASSUMPTION (review LOW G): "HP went down" is read as "our punch landed",
-- so a THIRD PARTY lowering the target's health inside the same punch would be
-- credited to us -- 12 rage for a swing that dealt nothing. The constructed
-- case is a mob that raises `self.health` above `hp_max` inside its own
-- `do_punch`, which check_for_death then clamps back down
-- (mods/ENTITIES/mobs/api.lua:855-856). It is not reachable in this game: the
-- only writers of mob health are grug_mobs/levels.lua:324, which sets `hp_max`
-- in the same call, and grug_mobs/aggro.lua:203, which runs outside the punch.
-- A future mob that heals or shields itself from `do_punch` would break the
-- reading, and the fix would be to compare against the damage the punch is
-- known to have applied rather than against a health delta.
local function target_hp(target, ent)
	if ent then
		return ent.health or 0
	end
	return target:get_hp()
end

-- One swing. Returns the cooldown it earned (the weapon's swing time) so the
-- caller can arm the timer, or nil plus the reason it stopped.
--
-- The target is resolved through the SAME helper the class kits use, so
-- "target dead", "out of range" and "out of line of sight" are one test and
-- the soft target lock (8 s) is refreshed by every swing. `pointed` is the
-- click's own target on the first cast and nil for every repeat afterwards —
-- from then on the lock IS the target. The lock profile is the Strike
-- definition's (all three swing skills share melee 4 m). The shared swing
-- clock is gone (WP38, combat_stats.md §2 — no punch is discarded, damage is
-- proportional), so there is no "declined" answer any more: the swing
-- happens whenever it has a target.
local strike_def -- assigned with the Strike definition below (the swing-range profile)

-- The swing skill the player currently has selected, or nil (Strike, a cast
-- skill, a non-ability item — all baseline). Read from the wielded item every
-- swing; kits.lua cannot see init.lua's item_defs, hence the accessor.
local function selected_swing_def(user)
	local d = grug_abilities.ability_of_item(user:get_wielded_item():get_name())
	return (d and d.kind == "swing" and d.proc_swing) and d or nil
end

local function melee_swing(user, pointed)
	local target = enemy_target(user, pointed, strike_def)
	if not target then
		return nil, "No target."
	end
	local weapon_damage, fpi = swing_stats(user)
	local melee_bonus = grug_classes.get_melee_bonus(user)
	local amount, tmult, post = weapon_damage + melee_bonus, 1, nil
	-- The SELECTED swing skill decides the proc (classes.md §2b: only the
	-- selected skill procs, one effect per swing). Read LIVE every swing -- a
	-- hotbar switch mid-fight re-arms the proc without interrupting the loop.
	-- Strike itself has no proc_swing: it IS the baseline. An unaffordable
	-- proc does not fire and does NOT consume the charge -- silently, by
	-- design (a warning per swing would be noise).
	local sel = selected_swing_def(user)
	local proc = sel and grug_abilities.charge_ready(user, sel)
		and grug_abilities.can_afford(user, sel.cost)
	if proc then
		amount, tmult, post = sel.proc_swing(user, target,
			{weapon_damage = weapon_damage, fpi = fpi, melee_bonus = melee_bonus})
	end
	-- The luaentity is captured BEFORE the punch: a lethal ability punch
	-- removes an animation-less mob synchronously and invalidates the
	-- ObjectRef, but the Lua table (and its `health`) stays readable.
	local ent = mob_ent(target)
	local hp_before = target_hp(target, ent)
	grug_core.deal_ability_damage(user, target, amount, {threat_mult = tmult})
	if target_hp(target, ent) < hp_before then
		if proc then
			grug_abilities.pay(user, sel.cost)
			grug_abilities.reset_charge(user, sel)
			if post then post() end
		end
		-- Rage: +12 per LANDED loop swing, whatever the selected skill -- the
		-- loop swing IS the Strike semantically (classes.md §1).
		grug_abilities.add_rage(user, 12)
	end
	return fpi
end

-- Working title kept from the design file. Deliberately a plain English verb,
-- not a Blizzard ability name. (Assigned, not re-declared: the forward
-- declaration above melee_swing is the upvalue it closes over.)
strike_def = {
	id = "strike",
	kind = "swing",
	universal = true, -- every class, and a character with no class yet (E1)
	name = "Strike",
	description = "Melee attack with your equipped weapon. Swings at your weapon's speed, generates 12 rage per landed hit. Cast again to stop.",
	-- Bone white, deliberately neutral (E8): the four class colours carry the
	-- ability identities and a fifth colour would compete with them. With an
	-- empty weapon slot the item falls back to this orb, which reads correctly
	-- as "you are punching with your fists".
	color = "#d9d3c0",
	cost = {}, -- no resource cost: it is what GENERATES the resource
	-- Melee, so the elf's +5 m ability range does not apply (E7) -- it would
	-- otherwise hand elves a 9 m sword.
	melee = true,
	range = 4,
}
grug_abilities.register_ability(strike_def)

-- init.lua's loop and try_cast call these (load-order: this file is dofile'd
-- from init.lua's tail, before any globalstep can fire).
grug_abilities.melee_swing = melee_swing

-- try_cast's re-arm click refreshes the lock WITHOUT swinging (classes.md
-- §2b: a click on another swing skill while the loop runs is re-arm only).
function grug_abilities.refresh_melee_target(user, pointed)
	enemy_target(user, pointed, strike_def)
end

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	kind = "cast",
	description = "Dash to an enemy up to 12 m away, dealing 3 damage\n" ..
		"and generating 15 rage.",
	color = "#e8c85a",
	cost = {},
	cooldown = 10,
	range = 12,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		local tpos = target:get_pos()
		local dir = vector.direction(tpos, user:get_pos())
		local dest = vector.add(tpos, vector.multiply(dir, 1.3))
		dest.y = tpos.y
		user:set_pos(dest)
		grug_abilities.add_rage(user, 15)
		grug_core.deal_ability_damage(user, target, 3, {threat_mult = 3})
		burst(tpos, "default_item_smoke.png", 8)
		return true
	end,
})

-- The rage dump (kit tuning 2026-08-06): no own cooldown — at +12 rage
-- per auto-hit a cooldown left the Warrior permanently rage-capped.
grug_abilities.register_ability({
	id = "mighty_blow",
	kind = "swing",
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your melee bonus. Rides along on a landed swing whenever you have the rage.",
	color = "#c84a32",
	cost = {rage = 25},
	-- Melee at 4 m, so the elf's +5 m ability range does not apply (E7). This
	-- was a PRE-EXISTING bug, not something the weapon slot introduced: the
	-- perk was written as "+5 m on every ability" and gave elves a 9 m reach on
	-- a hit that is supposed to be within arm's length. The flag is all it
	-- takes -- grug_abilities.get_range honours it, and sync_kit derives the
	-- stack's `range` meta from get_range, so the engine's pointing reach and
	-- the target-lock fallback move together.
	melee = true,
	range = 4,
	-- The proc REPLACES the plain hit (classes.md §3): floor(weapon x 1.5) +
	-- melee bonus, x3 threat. No charge timer -- the rage cost IS the limiter
	-- (about every other swing at +12 rage per landed hit).
	proc_swing = function(user, target, ctx)
		local tpos = target:get_pos() -- before the punch (lethal invalidates refs)
		return math.floor(ctx.weapon_damage * 1.5) + ctx.melee_bonus, 3,
			function() burst(tpos, "mobs_blood.png", 6) end
	end,
})

-- The control tool (kit tuning 2026-08-06): in an engine where mobs
-- outrun players, the snare is the Warrior's identity.
grug_abilities.register_ability({
	id = "hamstring",
	kind = "swing",
	class = "warrior",
	name = "Hamstring",
	description = "A landed swing cripples: slows the enemy by 50% for 5 s. Charges over 6 s.",
	color = "#a8324e",
	charge = 6,
	cost = {rage = 10},
	-- Melee at 4 m: same pre-existing elf-range bug as Mighty Blow above, same
	-- one-flag fix (E7).
	melee = true,
	range = 4,
	-- The swing lands as usual; the proc adds the slow (classes.md §3).
	-- `post` runs only on a LANDED swing, so a dodged Hamstring does not
	-- snare (the old cast's dealt > 0 gate).
	proc_swing = function(user, target, ctx)
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		return ctx.weapon_damage + ctx.melee_bonus, 3, function()
			if ent then
				grug_mobs.slow(ent, 5, 0.5)
			elseif target:get_hp() > 0 then
				apply_player_speed_stages(target, {{speed = 0.5, time = 5}})
			end
			burst(tpos, "mobs_blood.png", 4)
		end
	end,
})

grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	kind = "cast",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	range = 8,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		local ent = mob_ent(target)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		ent:do_attack(user, true)
		-- Threat part (combat_stats.md §4): sets the taunter to top×1.1 and
		-- suppresses hysteresis target switches for 3 s.
		grug_core.taunt(ent, user)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#e07b39", 6)
		return true
	end,
})

--
-- Mage (mana)
--

-- Bread-and-butter nuke (kit tuning 2026-08-06): pays with mana instead
-- of a cooldown — 5 mana against a 240+ pool was free.
grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	kind = "cast",
	description = "Hurls fire at an enemy up to 20 m away:\n" ..
		"6 + spell power damage.",
	color = "#ff8833",
	cost = {mana = 8},
	cooldown = 0,
	range = 20,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		beam(user, target, "mobs_fire_particle.png")
		burst(target:get_pos(), "mobs_fire_particle.png")
		grug_core.deal_ability_damage(user, target,
			6 + grug_classes.get_spell_power_bonus(user))
		return true
	end,
})

-- The rotation pivot (kit tuning 2026-08-06): kiting IS the Mage fantasy
-- here — root, make distance, keep nuking, re-nova when it is back up.
grug_abilities.register_ability({
	id = "frost_nova",
	class = "mage",
	name = "Frost Nova",
	kind = "cast",
	description = "Roots all enemies within 5 m for 4 s,\n" ..
		"then slows them by 50% for 3 s.",
	color = "#66b8ff",
	cost = {mana = 10},
	cooldown = 12,
	range = 4,
	cast = function(user)
		local pos = user:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 5)) do
			if obj ~= user then
				if obj:is_player() then
					if grug_factions.hostile(user, obj) then
						apply_player_speed_stages(obj, {
							{speed = 0.1, jump = 0.3, time = 4},
							{speed = 0.5, time = 3},
						})
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				else
					local ent = mob_ent(obj)
					if ent and not (ent._grug_faction and
							ent._grug_faction == grug_factions.get_faction(user)) then
						grug_mobs.root(ent, 4)
						grug_mobs.slow(ent, 3, 0.5) -- queued: starts after the root
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				end
			end
		end
		burst(pos, "default_item_smoke.png^[multiply:#aaddff", 20)
		grug_core.mark_in_combat(user)
		return true
	end,
})

grug_abilities.register_ability({
	id = "blink",
	class = "mage",
	name = "Blink",
	kind = "cast",
	description = "Teleport up to 10 m in your look direction\n" ..
		"(blocked by walls).",
	color = "#b06aff",
	cost = {mana = 8},
	cooldown = 15,
	range = 4,
	cast = function(user)
		local eye_height = user:get_properties().eye_height or 1.5
		local from = user:get_pos()
		local eye = vector.offset(from, 0, eye_height, 0)
		local dir = user:get_look_dir()
		local dest_eye = vector.add(eye, vector.multiply(dir, 10))
		local ray = core.raycast(eye, dest_eye, false, false)
		local hit = ray:next()
		if hit and hit.type == "node" then
			dest_eye = vector.subtract(hit.intersection_point,
				vector.multiply(dir, 0.7))
		end
		-- Feet position; back off along the ray until there is room.
		local dest = vector.offset(dest_eye, 0, -eye_height, 0)
		for _ = 1, 12 do
			local feet = core.get_node_or_nil(vector.round(dest))
			local head = core.get_node_or_nil(vector.round(
				vector.offset(dest, 0, 1, 0)))
			local function free(node)
				if not node then
					return false
				end
				local ndef = core.registered_nodes[node.name]
				return ndef and not ndef.walkable
			end
			if free(feet) and free(head) then
				burst(from, "default_item_smoke.png^[multiply:#b06aff", 10)
				user:set_pos(dest)
				burst(dest, "default_item_smoke.png^[multiply:#b06aff", 10)
				return true
			end
			dest = vector.subtract(dest, vector.multiply(dir, 0.75))
			if vector.distance(dest, from) < 0.8 then
				break
			end
		end
		return false, "No room to blink."
	end,
})

--
-- Priest (mana)
--

grug_abilities.register_ability({
	id = "smite",
	class = "priest",
	name = "Smite",
	kind = "cast",
	description = "Smites an enemy up to 20 m away:\n" ..
		"4 + spell power damage.",
	color = "#ffd97a",
	cost = {mana = 4},
	cooldown = 2,
	range = 20,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		beam(user, target, "default_item_smoke.png^[multiply:#ffe9a0")
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0")
		grug_core.deal_ability_damage(user, target,
			4 + grug_classes.get_spell_power_bonus(user))
		return true
	end,
})

grug_abilities.register_ability({
	id = "flash_heal",
	class = "priest",
	name = "Flash Heal",
	kind = "cast",
	description = "Heals the pointed ally (or yourself) for\n" ..
		"8 + 2x spell power.",
	color = "#7ae08a",
	cost = {mana = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		grug_core.heal_player(user, target,
			8 + 2 * grug_classes.get_spell_power_bonus(user))
		burst(target:get_pos(), "mobs_heart_particle.png", 8)
		return true
	end,
})

-- Base-kit shield (kit tuning 2026-08-06, replaces Renew): an absorb
-- plays differently from a second heal and makes the Priest useful
-- BEFORE damage lands. The soak itself lives in grug_core's central hp
-- change modifier (grug_core.set_absorb).
grug_abilities.register_ability({
	id = "power_word_shield",
	class = "priest",
	name = "Power Word: Shield",
	kind = "cast",
	description = "Shields the pointed ally (or yourself): absorbs\n" ..
		"8 + 2x spell power damage for 15 s or until consumed.",
	color = "#e8e07a",
	cost = {mana = 8},
	cooldown = 10,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		grug_core.set_absorb(target,
			8 + 2 * grug_classes.get_spell_power_bonus(user), 15)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0", 8)
		return true
	end,
})

-- Active renews: target name -> {ticks, amount, healer}
local renews = {}

-- Talent-gated (kit tuning 2026-08-06): stays registered, but sync_kit
-- does not grant it — the Holy tree unlocks it in WP11.
grug_abilities.register_ability({
	id = "renew",
	class = "priest",
	name = "Renew",
	kind = "cast",
	talent_gated = true,
	description = "Heal over time on the pointed ally (or yourself):\n" ..
		"3 + spell power every 3 s for 12 s.\nUnlocked via talents.",
	color = "#3fae6a",
	cost = {mana = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		renews[target:get_player_name()] = {
			ticks = 4,
			amount = 3 + grug_classes.get_spell_power_bonus(user),
			healer = user:get_player_name(),
		}
		burst(target:get_pos(), "mobs_heart_particle.png", 5)
		return true
	end,
})

local renew_acc = 0

core.register_globalstep(function(dtime)
	renew_acc = renew_acc + dtime
	if renew_acc < 3 then
		return
	end
	renew_acc = 0
	for name, renew in pairs(renews) do
		local target = core.get_player_by_name(name)
		if not target or target:get_hp() <= 0 then
			renews[name] = nil
		else
			local healer = core.get_player_by_name(renew.healer) or target
			grug_core.heal_player(healer, target, renew.amount)
			burst(target:get_pos(), "mobs_heart_particle.png", 3)
			renew.ticks = renew.ticks - 1
			if renew.ticks <= 0 then
				renews[name] = nil
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	renews[player:get_player_name()] = nil
end)
