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
-- What stays behind: punching a mob with a wielded pick or a bare hand
-- (E5). E5 justified leaving it alone with "strictly worse than the skill --
-- no crit", and that is FALSE. The WP6 cadence patch it keeps hands it both
-- of the Strike's numbers: mods/ENTITIES/mobs/api.lua:2749-2756 adds
-- grug_core.get_melee_bonus(hitter) to the fleshy group on every ACCEPTED
-- swing, and api.lua:2789-2791 rolls grug_core.melee_crit on the result. An
-- accepted swing then reaches grug_mobs' do_punch wrapper
-- (grug_mobs/init.lua:352 -> grug_core.run_player_hit_mob), which adds the
-- base threat (= damage) and fires the hit hook in this mod's init.lua:1165 --
-- and that hook sets the soft target lock and grants the +12 rage, because
-- grug_core.in_ability_punch is false on this path. So a hotbar weapon swung
-- with the dig key at one of our mobs deals FULL weapon damage + Str + crit
-- and generates rage, threat and a target lock, exactly like the Strike.
--
-- What it actually lacks is the source and the convenience: the damage comes
-- from the WIELDED stack rather than the weapon slot, which is exactly B1's
-- "single, fixed source" being bypassed; it wears that stack (the Strike
-- punches with punch_attack_uses = 0); it carries no ability threat
-- multiplier; and it cannot swing at the lock -- the player has to keep the
-- mob pointed, with no range/LOS test and no auto-repeat.
--
-- docs/design/combat_stats.md §2 records the same split.
--
-- E5 read the path as "not a bypass worth defending against". Whatever that is
-- worth for the path in isolation, it is false of the two running AT ONCE: the
-- ability item only disables punching while it is SELECTED, so a hotbar switch
-- used to leave both swinging. The defence is one shared swing clock, in
-- strike_swing below.
--
-- SCOPE OF THAT DEFENCE, exactly (review MEDIUM A): it covers MOB targets and
-- nothing else. `grug_core.accept_melee_swing` has two callers -- strike_swing
-- below and the cadence gate in mods/ENTITIES/mobs/api.lua:2712, which is a
-- mobs_redo `on_punch` and is therefore only reached when the thing punched is
-- a mob (and only a grug_mobs-registered one at that:
-- `grug_mobs.registered_cadence[self.name]`). A punch on a PLAYER goes through
-- PlayerSAO::punch -> on_punchplayer (src/server/player_sao.cpp:457-480) and
-- never touches the clock at all. So against another player the held-button
-- path is still ungated and DOES stack with the Strike: measured over 30 s at
-- dtime 0.09, Strike alone 180 damage, Strike plus a held dig with a fleshy-25
-- hotbar weapon 930 (5.17x); with equal weapons a clean ~2x.
--
-- That raw PvP melee path is the documented carry-over of combat_stats.md §2
-- ("PvP melee still runs the engine's raw tflp scaling"), and E6's claim that
-- the Strike closes it holds only for the damage the STRIKE deals -- it does
-- not remove the second stream. Closing it for real means porting the cadence
-- model to player punches (a `core.register_on_punchplayer` that returns true
-- to suppress the engine's damage, doc/lua_api.md:6589), which is the PvP work
-- package's job: it needs its own hostility/dodge/threat decisions, and it
-- would inherit the clock defect below. Do not read the shared clock as a PvP
-- guarantee.
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

-- The shared melee clock is WINNER-TAKES-ALL BY REQUESTED INTERVAL, and the
-- Strike is the side that loses (review MEDIUM B). `accept_melee_swing`
-- (mods/CORE/grug_core/combat.lua:521-530) stores a timestamp and NOTHING
-- ELSE: the acceptance threshold is whatever the current caller asks for, so
-- whoever asks with the SHORTER interval stamps the clock often enough that
-- the slower asker is refused forever. Measured over 30 s at dtime 0.09, on a
-- mob, with a greataxe (fpi 1.4) in the slot: Strike alone 198 damage; the
-- same greataxe plus a held BARE-HAND dig 77 (0.39x); plus a held steel pick
-- (fpi 1.0) 159 (0.80x). The design says the equipped weapon is the single
-- source of damage (B1); the clock says the fastest thing the player touched
-- is -- and the loss is silent, which is the worse half.
--
-- This cannot be fixed from grug_abilities: the clock's shape is grug_core's.
-- The fix belongs there and is small -- remember the accepted swing's own
-- interval alongside its time and refuse on `max(requested, accepted)`, so the
-- slot weapon's cadence governs and the carry-over path is the one that
-- starves. Until then the loop simply retries, and what this file CAN do is
-- refuse to lose the damage silently: `note_starved` below says so once.
local clock_block = {} -- player name -> {since = us time, warned = us time}

-- How long a refusal streak has to last before the player is told, as a
-- multiple of the weapon's own swing time (so a greataxe is not nagged for
-- missing one 2 s swing), and how rarely the message may repeat.
local STARVE_WARN_AFTER = 2
local STARVE_WARN_EVERY = 10

local function note_starved(user, def, fpi)
	local name = user:get_player_name()
	local now = core.get_us_time()
	local rec = clock_block[name]
	if not rec then
		clock_block[name] = {since = now, warned = 0}
		return
	end
	if (now - rec.since) / 1e6 < STARVE_WARN_AFTER * fpi then
		return
	end
	if rec.warned ~= 0 and (now - rec.warned) / 1e6 < STARVE_WARN_EVERY then
		return
	end
	rec.warned = now
	grug_abilities.flash(user,
		"Your held attack is taking " .. def.name .. "'s swings.")
end

core.register_on_leaveplayer(function(player)
	clock_block[player:get_player_name()] = nil
end)

-- One swing. Returns the cooldown it earned (the weapon's swing time) so the
-- caller can arm the timer, `false` for "not this step, but do not stop", or
-- nil plus the reason it stopped.
--
-- The target is resolved through the SAME helper the class kits use, so
-- "target dead", "out of range" and "out of line of sight" are one test and
-- the soft target lock (8 s) is refreshed by every swing. `pointed` is the
-- click's own target on the first cast and nil for every repeat afterwards --
-- from then on the lock IS the target. It is resolved BEFORE the swing clock is
-- consulted, so those stop conditions stay live even while the clock is held by
-- the other melee path.
local function strike_swing(user, pointed, def)
	local target = enemy_target(user, pointed, def)
	if not target then
		return nil, "No target."
	end
	local weapon_damage, fpi = swing_stats(user)
	-- ONE melee clock per player, shared with the held-button punch path
	-- (grug_core.accept_melee_swing, consumed by the cadence gate in
	-- mods/ENTITIES/mobs/api.lua:2706ff) -- review HIGH 2.
	--
	-- E5 left the old path alone because a hotbar weapon swung that way is
	-- "strictly worse than the skill" -- an assessment the section header above
	-- corrects (it crits, it generates rage and it takes the target lock).
	-- Whatever it is worth in isolation, it is false when both run at
	-- once: A2 only stops a player punching while the ABILITY item is
	-- selected, so switching the hotbar to a pick and holding dig left the
	-- Strike loop swinging the equipment-slot weapon at full damage next to it
	-- -- two damage streams, ~1.9x the DPS and doubled rage income, against
	-- B1's "the slot item is the single, fixed source of damage". Sharing the
	-- clock makes the two mutually exclusive AGAINST A MOB. It does nothing
	-- against a player target -- see the scope note at the top of this section
	-- (review MEDIUM A) -- and it costs a slow weapon its damage rather than
	-- splitting the difference (review MEDIUM B, above note_starved).
	--
	-- Consumed AFTER the target check, so a swing into thin air does not burn
	-- the clock, and before the damage, so a refused swing costs nothing at all.
	if not grug_core.accept_melee_swing(user, fpi) then
		note_starved(user, def, fpi)
		return false
	end
	clock_block[user:get_player_name()] = nil
	-- combat_stats.md §2: melee damage = weapon damage + floor(Str/10).
	-- deal_ability_damage rolls the crit (x1.5), pre-rolls a player target's
	-- dodge, does the friendly-fire check, marks combat and reports threat --
	-- threat multiplier 1, Taunt keeps its x3.
	local amount = weapon_damage + grug_classes.get_melee_bonus(user)
	-- The luaentity is captured BEFORE the punch: a lethal ability punch
	-- removes an animation-less mob synchronously and invalidates the
	-- ObjectRef, but the Lua table (and its `health`) stays readable.
	local ent = mob_ent(target)
	local hp_before = target_hp(target, ent)
	grug_core.deal_ability_damage(user, target, amount)
	if target_hp(target, ent) < hp_before then
		-- classes.md §1's +12 per melee hit DEALT. It has to happen here:
		-- grug_core's hit hook skips ability punches on purpose (see the note
		-- in init.lua). Gated on hit points that actually came off, never on
		-- the swing being attempted -- see target_hp above for the three ways
		-- a swing lands for nothing.
		grug_abilities.add_rage(user, 12)
	end
	-- Deliberately NO particle burst of its own, unlike the class abilities:
	-- the punch already runs mobs_redo's hit sound and blood effect, and this
	-- one fires every 0.7-1.4 s for as long as a fight lasts. Crits keep their
	-- burst (grug_core rolls it), which is what makes a crit readable.
	return fpi
end

-- Working title kept from the design file. Deliberately a plain English verb,
-- not a Blizzard ability name.
grug_abilities.register_ability({
	id = "strike",
	universal = true, -- every class, and a character with no class yet (E1)
	name = "Strike",
	description = "Attack your target with your equipped weapon and\n" ..
		"keep swinging at its speed. Cast again to stop.\n" ..
		"Generates 12 rage per hit.",
	-- Bone white, deliberately neutral (E8): the four class colours carry the
	-- ability identities and a fifth colour would compete with them. With an
	-- empty weapon slot the item falls back to this orb, which reads correctly
	-- as "you are punching with your fists".
	color = "#d9d3c0",
	cost = {}, -- no resource cost: it is what GENERATES the resource
	-- The real cadence is per cast, from the weapon (E2) -- `cooldown` is the
	-- registry's required floor value and stays 0 so a bare-handed swing is
	-- never blocked by a stale number.
	cooldown = 0,
	cooldown_for = function(user)
		local _, fpi = swing_stats(user)
		return fpi
	end,
	cooldown_text = "swings at your weapon's speed",
	-- No wear bar for this one (E2): its cooldown restarts every 0.7-1.4 s for
	-- as long as a player is in combat, and every wear write re-sends the whole
	-- inventory to the client.
	no_cooldown_display = true,
	-- Off the global cooldown in BOTH directions (E2): a 1 s GCD would cap a
	-- 0.7 s dagger, and a swing starting a GCD would lock the class kit out
	-- for as long as the player keeps attacking.
	off_gcd = true,
	-- Melee, so the elf's +5 m ability range does not apply (E7) -- it would
	-- otherwise hand elves a 9 m sword.
	melee = true,
	range = 4,
	repeat_swing = function(user, def)
		return strike_swing(user, nil, def)
	end,
	cast = function(user, pointed, def)
		-- A second cast never reaches this function: try_cast stops the
		-- running loop before its own gates (E3's "second cast").
		local fpi, err = strike_swing(user, pointed, def)
		if fpi == nil then
			return false, err
		end
		grug_abilities.start_repeat(user, def)
		if fpi == false then
			-- `false` means the shared melee clock is still held by a punch the
			-- player made with a WIELDED tool a moment ago. The toggle goes on
			-- either way -- but NOTHING SWUNG, so this cast earned no cooldown:
			-- the third return value overrides try_cast's cooldown_for() (review
			-- LOW D). Arming the full swing interval here made the refusal cost a
			-- whole extra swing -- measured with a greataxe on a free clock, the
			-- first swing landed at 1.44 s instead of 1.22 s -- and it made the
			-- comment's "the loop takes the next legal swing" false, because the
			-- loop waits on exactly this cooldown. With 0 nothing is stored, so
			-- the loop retries on the very next globalstep.
			return true, nil, 0
		end
		return true
	end,
})

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
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
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your\n" ..
		"melee bonus. Uses your equipped weapon.",
	color = "#c84a32",
	cost = {rage = 25},
	cooldown = 0,
	-- Melee at 4 m, so the elf's +5 m ability range does not apply (E7). This
	-- was a PRE-EXISTING bug, not something the weapon slot introduced: the
	-- perk was written as "+5 m on every ability" and gave elves a 9 m reach on
	-- a hit that is supposed to be within arm's length. The flag is all it
	-- takes -- grug_abilities.get_range honours it, and sync_kit derives the
	-- stack's `range` meta from get_range, so the engine's pointing reach and
	-- the target-lock fallback move together.
	melee = true,
	range = 4,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		-- The equipped weapon, and only that (B1, T4). This used to scan hotbar
		-- slots 1-8 for the strongest fleshy damage, because "the wielded item
		-- is this ability" and there was no slot to ask. There is now, and the
		-- slot is the SINGLE source: no fallback to the hand, no fallback to the
		-- pack. `swing_stats` is the same reader the Strike uses, so the two
		-- melee abilities can never disagree about what the player is holding --
		-- it resolves per-stack meta before the item definition, which is how
		-- WP5's rolled affixes will reach this for free.
		--
		-- Empty slot: `swing_stats` answers the hand's own fleshy damage (1),
		-- i.e. exactly what the old scan produced with no weapon in the hotbar,
		-- so an unarmed Mighty Blow is worth floor(1 * 1.5) + melee bonus as
		-- before -- weak, never uncastable (C2).
		local weapon_damage = swing_stats(user)
		local amount = math.floor(weapon_damage * 1.5)
			+ grug_classes.get_melee_bonus(user)
		-- Position BEFORE the damage: a lethal punch invalidates mob refs.
		local tpos = target:get_pos()
		grug_core.deal_ability_damage(user, target, amount, {threat_mult = 3})
		burst(tpos, "mobs_blood.png", 6)
		return true
	end,
})

-- The control tool (kit tuning 2026-08-06): in an engine where mobs
-- outrun players, the snare is the Warrior's identity.
grug_abilities.register_ability({
	id = "hamstring",
	class = "warrior",
	name = "Hamstring",
	description = "Cripples the enemy: 2 damage and 50% slow for 5 s.",
	color = "#a8324e",
	cost = {rage = 10},
	cooldown = 6,
	-- Melee at 4 m: same pre-existing elf-range bug as Mighty Blow above, same
	-- one-flag fix (E7).
	melee = true,
	range = 4,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		-- Capture BEFORE the damage: a lethal punch removes a mob without a
		-- die animation synchronously, invalidating the ObjectRef.
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		-- Damage first: a dodged Hamstring (player targets) must not snare.
		local dealt = grug_core.deal_ability_damage(user, target, 2,
			{threat_mult = 3})
		if dealt > 0 then
			if ent then
				grug_mobs.slow(ent, 5, 0.5) -- harmless no-op on a removed mob
			elseif target:get_hp() > 0 then
				apply_player_speed_stages(target, {{speed = 0.5, time = 5}})
			end
			burst(tpos, "mobs_blood.png", 4)
		end
		return true
	end,
})

grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
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
