--
-- Behavior-verb helper library (docs/design/biomes_mobs.md §3.1: "one
-- behavior verb per mob family", combat_stats.md §3).
--
-- Nothing here registers a mob. Every helper takes a mob DEF and installs
-- itself into that def's own callback fields (do_custom / custom_attack)
-- BEFORE the def is handed to grug_mobs.register_mob — which then wraps
-- do_custom/do_punch once more with the level/aggro/telegraph machinery.
-- That ordering is the contract:
--
--     local def = { ... }
--     grug_mobs.pack_hunter(def, {})        -- verbs first
--     grug_mobs.register_mob("grug_mobs:wolf", def)
--
-- Calling a helper after register_mob does nothing (mobs_redo copied the
-- def fields into the entity prototype already, api.lua:3200ff).
--
-- Which family uses what (biomes_mobs §3.1):
--   slow_player .......... Giant Spider ("webs": 40% slow for 3 s)
--   poison_player ........ Serpent ("poisons": 1 dmg / 2 s for 6 s)
--   melee_rider .......... the delivery vehicle for both of the above
--   pack_hunter .......... Wolf / Blightfang Wolf / Hyena / Raptor
--   stalker .............. Panther ("stalks": silent approach + pounce) and
--                          all three Boars ("charges": the same impulse,
--                          flattened into a horizontal rush — see boar.lua)
--   ambusher ............. Crocodile ("lurks still, burst on approach")
--   damage_aura .......... Bog Ooze ("engulfs": touch-damage aura)
--   camp_swarm ........... Mirefolk ("swarms": camp group aggro, all rush)
--   register_simple_arrow  Skeleton Archer/Raider, Stone/Mesa Golem
--   _grug_leash_range .... Bear / Jungle Ape ("territorial", aggro.lua)
--
-- All entity-side countdowns live in `self.temp` and tick inside do_custom
-- — never core.after, a mob can die or unload mid-timer (levels.lua note).
-- core.after IS used for the two PLAYER-side effects, where the entity
-- cannot help: those re-fetch the player BY NAME on every callback.
--

--
-- Shared internals
--

-- Chains `fn` behind whatever do_custom the def already has. mobs_redo
-- treats a do_custom return of exactly `false` as "skip the rest of
-- on_step" (api.lua:3137), so an earlier link vetoing the step wins and
-- `fn` is not run at all.
local function chain_do_custom(def, fn)
	local prev = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		local r
		if prev then
			r = prev(self, dtime, moveresult)
			if r == false then
				return false
			end
		end
		local r2 = fn(self, dtime, moveresult)
		if r2 ~= nil then
			return r2
		end
		return r
	end
end

-- Per-entity 1 Hz (or `interval` Hz) gate on a self.temp accumulator.
-- Returns true on the ticks where the caller should do its work.
local function due(self, key, dtime, interval)
	self.temp = self.temp or {}
	local acc = (self.temp[key] or 0) + dtime
	if acc < (interval or 1) then
		self.temp[key] = acc
		return false
	end
	self.temp[key] = 0
	return true
end

-- Players within `range` of `pos`, as a list of ObjectRefs.
-- Deliberately core.get_connected_players() + a distance test instead of
-- core.get_objects_inside_radius(): every consumer here targets PLAYERS
-- only, and the player list needs no map query at all. On a small server
-- this is a handful of vector subtractions per second per mob.
local function players_near(pos, range)
	local out, n = {}, 0
	local players = core.get_connected_players()
	for i = 1, #players do
		local p = players[i]
		local pp = p:get_pos()
		if pp and vector.distance(pp, pos) <= range then
			n = n + 1
			out[n] = p
		end
	end
	return out, n
end

--
-- Player status effects (mob -> player)
--

--
-- OWNERSHIP CLAIM for player physics_override.speed
--
-- This file and grug_abilities/kits.lua (PvP Frost Nova / Hamstring) are
-- the ONLY writers of a player's speed multiplier in the game. They are
-- two independent owners today: each keeps its own name-keyed record and
-- each restores to speed = 1 when its own effect ends, so an overlapping
-- mob web + player snare can end early (the first restore lifts both).
-- Both windows are <= 7 s and the overlap needs a spider and a PvP caster
-- on the same victim at the same moment, so this is an accepted MVP
-- caveat, NOT an unnoticed bug — the fix is one shared owner in grug_core
-- and it is deliberately out of scope for WP6-T3 (it would rewrite the
-- staged root->slow chain in grug_abilities).
--
-- We only ever write `speed`; `jump` is left alone, so a mob web can never
-- lift a PvP jump root (set_physics_override is a partial update,
-- l_object.cpp:1900ff).
--

-- player name -> {factor = n, expiry = mono seconds, gen = n}
local player_slows = {}

-- player name -> generation counter for RUNNING poison chains (see
-- grug_mobs.poison_player). Same ownership hygiene as the slow's `gen` above,
-- one level up: a poison is a chain of core.after callbacks that only knows
-- the victim by NAME, so after a relog it would happily keep ticking on the
-- fresh session. Bumping the counter on leaveplayer orphans every in-flight
-- chain for that name — i.e. logging out dispels poison.
local poison_gen = {}

-- Slow a player to `factor` (0.6 = 40% slower) for `duration` seconds.
-- Stacking mirrors grug_mobs.slow's mob-side semantics: the STRONGER
-- factor and the LONGER remaining duration win, so a second, weaker web
-- can never lift a stronger snare or cut it short.
--
-- The restore runs on core.after with a generation counter: only the
-- callback whose generation is still the current one restores, so a
-- re-application silently orphans the older timer. The player is re-fetched
-- BY NAME and nil-checked — an ObjectRef captured here would be invalid
-- after a relog.
function grug_mobs.slow_player(player, duration, factor)
	if not player or not core.is_player(player) then
		return
	end
	local name = player:get_player_name()
	local now = grug_core.mono_time()
	local rec = player_slows[name]
	if rec and rec.expiry > now then
		factor = math.min(rec.factor, factor)
		duration = math.max(rec.expiry - now, duration)
	end
	local gen = ((rec and rec.gen) or 0) + 1
	player_slows[name] = {factor = factor, expiry = now + duration, gen = gen}
	player:set_physics_override({speed = factor})
	core.after(duration, function()
		local cur = player_slows[name]
		-- Superseded (stronger/longer slow), or cleared by leave/join:
		-- that owner restores, not us. Prevents the double restore that
		-- would otherwise fire after a relog inside the window.
		if not cur or cur.gen ~= gen then
			return
		end
		player_slows[name] = nil
		local p = core.get_player_by_name(name)
		if not p then
			return
		end
		p:set_physics_override({speed = 1})
	end)
end

-- A relog inside a slow window must leave neither a permanently slowed
-- player nor a stale timer that later restores over a fresh effect.
-- Physics overrides are not persisted by the engine, so the join reset is
-- a cheap belt-and-braces write; dropping the record first invalidates any
-- in-flight core.after (generation mismatch above).
core.register_on_joinplayer(function(player)
	player_slows[player:get_player_name()] = nil
	player:set_physics_override({speed = 1})
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	player_slows[name] = nil
	-- Cancel every running poison chain for this name (see poison_gen).
	poison_gen[name] = (poison_gen[name] or 0) + 1
end)

-- Damage-over-time on a player (Serpent: total_ticks 3, interval 2,
-- dmg_per_tick 1 = 1 dmg / 2 s for 6 s).
--
-- Damage path: player:set_hp(hp - dmg, {type = "set_hp", from = "mod"}),
-- NOT a punch. Verified against grug_core/combat.lua's central hp-change
-- modifier (combat.lua:442ff):
--   * the dodge roll only fires for reason.type == "punch" — a DoT tick
--     must not be dodgeable, so set_hp is exactly right;
--   * absorb shields soak EVERY source, so a Power Word: Shield does eat
--     poison ticks. Intended (that is what a shield is for);
--   * armor groups are bypassed entirely — poison ignores armor by design.
-- Each tick also marks the victim in combat, so a DoT keeps regen locked.
--
-- Every application runs its own independent chain: a second bite adds a
-- second DoT rather than refreshing one. Deliberate — serpent bites are
-- rare, and per-source stacks are the readable behavior.
function grug_mobs.poison_player(player, total_ticks, interval, dmg_per_tick)
	if not player or not core.is_player(player) then
		return
	end
	local name = player:get_player_name()
	local left = total_ticks
	-- Snapshot the victim's poison generation; leaveplayer bumps it, so a
	-- chain started before a relog stops on its next tick instead of eating
	-- into the fresh session (a name-keyed core.after chain cannot tell the
	-- two apart on its own — get_player_by_name happily returns the new
	-- ObjectRef).
	local gen = poison_gen[name] or 0
	local tick
	tick = function()
		if (poison_gen[name] or 0) ~= gen then
			return -- superseded: the victim logged out, this chain is void
		end
		local p = core.get_player_by_name(name)
		if not p then
			return -- left the server
		end
		local hp = p:get_hp()
		if hp <= 0 then
			return -- already dead: stop the chain
		end
		p:set_hp(hp - dmg_per_tick, {type = "set_hp", from = "mod"})
		grug_core.mark_in_combat(p)
		left = left - 1
		if left > 0 then
			core.after(interval, tick)
		end
	end
	core.after(interval, tick)
end

--
-- On-hit rider
--

-- Installs a custom_attack that runs `fn(self, target_player)` on every
-- landed melee swing and then returns TRUE, which is mobs_redo's contract
-- for "carry on with the normal melee damage" (api.lua:2366; the Kraken
-- shows the same pattern). Used for the web slow and the serpent poison.
--
-- NB mobs_redo calls this as `self:custom_attack(self, p)`, so the callback
-- receives (self, self, pos) — the useful target is self.attack, exactly as
-- kraken.lua notes. Riders on players only; mob-vs-mob melee gets no rider.
function grug_mobs.melee_rider(def, fn)
	local prev = def.custom_attack
	def.custom_attack = function(self, ...)
		if prev then
			-- An earlier link that returns exactly `false` is vetoing the
			-- swing (mobs_redo: `if not self.custom_attack or
			-- self:custom_attack(self, p) then` — a falsy return skips the
			-- melee damage entirely). Swallowing that and returning true
			-- regardless would let a rider silently re-enable an attack the
			-- def deliberately suppressed, and would run `fn` on a swing that
			-- never landed.
			local r = prev(self, ...)
			if r == false then
				return false
			end
		end
		local target = self.attack
		if target and core.is_player(target) then
			fn(self, target)
		end
		return true
	end
end

--
-- Pack behavior (Wolf / Hyena / Raptor: "hunts in packs; flees low,
-- returns with pack")
--
-- opts (all optional):
--   flee_hp     0.2  — flee below this fraction of max HP
--   flee_time   4    — seconds of running (mobs_redo counts runaway_timer
--                      down by 1 per do_states call, and do_states runs at
--                      1 Hz outside of combat — so this is ~seconds)
--   cooldown    15   — seconds before the same mob may flee again, so a
--                      wounded wolf fights on instead of stutter-fleeing
--   alert_range nil  — defaults to the mob's view_range
--
function grug_mobs.pack_hunter(def, opts)
	opts = opts or {}
	local flee_hp = opts.flee_hp or 0.2
	local flee_time = opts.flee_time or 4
	local cooldown = opts.cooldown or 15
	chain_do_custom(def, function(self, dtime)
		if not due(self, "grug_pack_acc", dtime, 1) then
			return
		end
		if self.state ~= "attack" then
			return
		end
		local target = self.attack
		if not target or not target:get_pos() then
			return
		end
		local hp_max = self.hp_max or 0
		if hp_max <= 0 or (self.health or 0) > hp_max * flee_hp then
			return
		end
		local now = grug_core.mono_time()
		if (self.temp.grug_pack_flee_until or 0) > now then
			return
		end
		self.temp.grug_pack_flee_until = now + cooldown
		-- "returns with pack": before running, call every idle mob of the
		-- same kind in view onto the attacker. Same shape as mobs_redo's own
		-- group alert (api.lua:2779ff) — do_attack on the current target.
		local pos = self.object and self.object:get_pos()
		local range = opts.alert_range or self.view_range or 10
		if pos then
			local objs = core.get_objects_inside_radius(pos, range)
			for i = 1, #objs do
				local ent = objs[i]:get_luaentity()
				if ent and ent._cmi_is_mob and ent ~= self
						and ent.name == self.name
						and ent.state ~= "attack" and ent.state ~= "runaway"
						and type(ent.do_attack) == "function" then
					ent:do_attack(target)
				end
			end
		end
		-- ...then break off, exactly like mobs_redo's punch-flee: yaw away
		-- (rot = 3 rad ~ opposite direction) and hand over to the "runaway"
		-- state, which owns the movement from here (api.lua:2107ff).
		local tpos = target:get_pos()
		if tpos then
			self:yaw_to_pos(tpos, 3, 4)
		end
		self.state = "runaway"
		self.runaway_timer = flee_time
		self.following = nil
	end)
end

--
-- Stalk (Panther: "silent approach, pounce burst")
--
-- The SILENT half is a def decision, not code: mobs_redo plays
-- sounds.war_cry on 90% of all target acquisitions (api.lua:220) and we
-- must not patch do_attack, so a stalker's def simply leaves
-- `sounds.war_cry` unset — then mob_sound() returns immediately
-- (api.lua:196) and the approach is silent. Roster tasks own that.
--
-- The POUNCE half is here: while closing on a target between min_dist and
-- max_dist with line of sight, throw the mob at it once per cooldown.
--
-- opts: min_dist 4, max_dist 8, cooldown 6, speed 8 (horizontal impulse),
--       up 4 (vertical impulse)
function grug_mobs.stalker(def, opts)
	opts = opts or {}
	local min_dist = opts.min_dist or 4
	local max_dist = opts.max_dist or 8
	local cooldown = opts.cooldown or 6
	local speed = opts.speed or 8
	local up = opts.up or 4
	chain_do_custom(def, function(self, dtime)
		if not due(self, "grug_stalk_acc", dtime, 1) then
			return
		end
		if self.state ~= "attack" or not self.attack then
			return
		end
		local now = grug_core.mono_time()
		if (self.temp.grug_pounce_until or 0) > now then
			return
		end
		local pos = self.object and self.object:get_pos()
		local tpos = self.attack:get_pos()
		if not pos or not tpos then
			return
		end
		local dist = vector.distance(pos, tpos)
		if dist < min_dist or dist > max_dist then
			return
		end
		-- Eye-level ray: a pounce over a fence or into a wall is not a
		-- pounce, it is a face-plant.
		if not core.line_of_sight(vector.offset(pos, 0, 1, 0),
				vector.offset(tpos, 0, 1, 0)) then
			return
		end
		self.temp.grug_pounce_until = now + cooldown
		local dir = vector.direction(pos, tpos)
		self.object:add_velocity(vector.new(dir.x * speed, up, dir.z * speed))
	end)
end

--
-- Ambush (Crocodile: "lurks still, burst on approach")
--
-- Only the stand/release toggle lives here; the actual burst is roster-side
-- numbers (small view_range + high run_velocity).
--
-- mobs_redo's `order = "stand"` is a hard halt: set_velocity() zeroes the
-- mob outright while it is set (api.lua:333), and the "stand" state stops
-- picking random walks (api.lua:2043). Target ACQUISITION is unaffected —
-- general_attack never looks at `order` — so the lurking croc still sees
-- players. That also means the order MUST be released the moment a target
-- is acquired, otherwise the mob would freeze mid-attack; that release is
-- checked on every step (two comparisons), only the re-arming is throttled.
--
-- opts: trigger_range 6
function grug_mobs.ambusher(def, opts)
	opts = opts or {}
	local trigger_range = opts.trigger_range or 6
	chain_do_custom(def, function(self, dtime)
		if self.state == "attack" and self.attack then
			if self.order == "stand" then
				self.order = "" -- burst: hand movement back to do_states
			end
			return
		end
		if not due(self, "grug_ambush_acc", dtime, 1) then
			return
		end
		local pos = self.object and self.object:get_pos()
		if not pos then
			return
		end
		local _, count = players_near(pos, trigger_range)
		self.order = count > 0 and "" or "stand"
	end)
end

--
-- Camp swarm (Mirefolk: "swarms — camp group aggro, all rush at once")
--
-- The pack_hunter alert, re-keyed: pack_hunter calls its neighbours when it
-- flees at low HP, this one calls them the moment ONE camp member acquires a
-- player, and it only calls members of the SAME camp (plain-field
-- `_grug_camp_pos`, set by camps.lua) instead of every same-name mob in
-- view. A mirefolk camp therefore comes at you as a camp, while the camp
-- across the swamp keeps fishing.
--
-- Fires ONCE per attack episode: `temp.grug_swarm_called` is set on the
-- alert and cleared as soon as the mob leaves the attack state, so an
-- ongoing fight costs one state comparison per second and not one radius
-- scan. self.temp is runtime-only (never serialized), so a reloaded mob
-- simply re-alerts on its next pull, which is harmless.
--
-- opts: range 20 (§3.1 "camp group aggro"), interval 1
function grug_mobs.camp_swarm(def, opts)
	opts = opts or {}
	local range = opts.range or 20
	local interval = opts.interval or 1
	-- Camp identity. Positions come back from staticdata as plain tables
	-- without the vector metatable, so `==` would be silently false
	-- (luanti-lua.md rule 7) — compare the components. Two camp-less mobs
	-- count as one group: a hand-placed mirefolk (no camp) still swarms with
	-- its neighbours, which is the readable behaviour.
	local function same_camp(a, b)
		if not a or not b then
			return a == nil and b == nil
		end
		return a.x == b.x and a.y == b.y and a.z == b.z
	end
	chain_do_custom(def, function(self, dtime)
		if not due(self, "grug_swarm_acc", dtime, interval) then
			return
		end
		self.temp = self.temp or {}
		if self.state ~= "attack" then
			self.temp.grug_swarm_called = nil
			return
		end
		if self.temp.grug_swarm_called then
			return
		end
		local target = self.attack
		if not target or not core.is_player(target) or not target:get_pos() then
			return
		end
		local pos = self.object and self.object:get_pos()
		if not pos then
			return
		end
		self.temp.grug_swarm_called = true
		local camp = self._grug_camp_pos
		local objs = core.get_objects_inside_radius(pos, range)
		for i = 1, #objs do
			local ent = objs[i]:get_luaentity()
			if ent and ent._cmi_is_mob and ent ~= self
					and ent.name == self.name
					and ent.state ~= "attack" and ent.state ~= "runaway"
					and same_camp(ent._grug_camp_pos, camp)
					and type(ent.do_attack) == "function" then
				ent:do_attack(target)
			end
		end
	end)
end

--
-- Aura (Bog Ooze: "engulfs" — touch damage)
--
-- opts: radius 2, damage 2, interval 1
--
-- Damage goes through object:punch from the MOB, so armor groups, the
-- dodge roll and absorb shields all apply exactly as for a melee swing.
--
-- Budget: one players_near() scan per second per active ooze — no map
-- query at all (see players_near), just a distance test per connected
-- player. Oozes are a swamp-only family with a low active_object_count, so
-- this is a rounding error even with a dozen of them loaded.
function grug_mobs.damage_aura(def, opts)
	opts = opts or {}
	local radius = opts.radius or 2
	local damage = opts.damage or 2
	local interval = opts.interval or 1
	chain_do_custom(def, function(self, dtime)
		if not due(self, "grug_aura_acc", dtime, interval) then
			return
		end
		local pos = self.object and self.object:get_pos()
		if not pos then
			return
		end
		local victims = players_near(pos, radius)
		for i = 1, #victims do
			victims[i]:punch(self.object, 1.0, {
				full_punch_interval = 1.0,
				damage_groups = {fleshy = damage},
			}, nil)
		end
	end)
end

--
-- Generic arrow (Skeleton Archer/Raider, Stone/Mesa Golem)
--

-- Stamp the SHOOTER's current damage onto a freshly created arrow. Meant to
-- be used as the def's `arrow_override` (mobs_redo calls it as
-- `self.arrow_override(ent, self)`, api.lua:2431), which is the only hook
-- that sees both the arrow entity and the mob. Damage therefore comes from
-- the level engine's `mob.damage` (levels.lua) at FIRE time — an arrow def
-- never carries a hand-written number.
function grug_mobs.stamp_arrow_damage(ent, mob)
	if not ent then
		return
	end
	ent._grug_damage = mob and mob.damage or nil
end

-- opts: texture (sprite, required), velocity (default 14), size, glow,
--       tail (bool -> particle trail), tail_texture, lifetime,
--       damage (fallback only, when no shooter stamped one)
function grug_mobs.register_simple_arrow(name, opts)
	local fallback = opts.damage or 1
	local function hit(self, obj)
		local dmg = self._grug_damage or fallback
		obj:punch(self.object, 1.0, {
			full_punch_interval = 1.0,
			damage_groups = {fleshy = dmg},
		}, nil)
	end
	mobs:register_arrow(name, {
		visual = "sprite",
		visual_size = opts.size or {x = 0.5, y = 0.5},
		textures = {opts.texture},
		velocity = opts.velocity or 14,
		glow = opts.glow,
		lifetime = opts.lifetime,
		-- mobs_redo wants tail == 1, not a boolean (api.lua:3787).
		tail = opts.tail and 1 or nil,
		tail_texture = opts.tail_texture or opts.texture,
		hit_player = hit,
		hit_mob = hit,
		-- Expire on terrain: a no-op on purpose. mobs_redo's arrow on_step
		-- removes the entity after ANY collision (api.lua:3863) and the
		-- only thing hit_node adds on top is the "drop the arrow as an
		-- item" roll (api.lua:3831) — which we do not want, `drop` stays
		-- unset. Keeping the hook makes the intent explicit and gives the
		-- roster tasks a place to put an impact effect later.
		hit_node = function(self, pos, node)
		end,
	})
end

--
-- "grazes" — PASSIVE PREY (biomes_mobs.md §3.0, decided 2026-08-08)
--
-- The large grazers (Stag, Gaunt Stag, Zebra, Mountain Ram) and the Carrion
-- Crow: ordinary mobs in every mechanical respect — level from the field, HP
-- and XP from the formulas, leather drops kept — with exactly one behavioural
-- difference from the aggressive families: **they never attack on sight, but
-- they fight back when attacked.**
--
-- mobs_redo ALREADY EXPRESSES THIS, so nothing here is a new aggro system;
-- the helper only sets the four fields that say it, in one place, with the
-- reasons attached (api.lua line numbers against our vendored copy):
--
--   * `passive = false` is what makes retaliation exist at all. on_punch's
--     tail (api.lua:2979) reads `if not self.passive ... then self:do_attack(
--     hitter)` and additionally alerts same-name mobs with group_attack —
--     a `passive = true` mob has no code path that can ever hit back.
--   * `attack_players = false` is what removes aggro on sight. It is read in
--     exactly ONE place, general_attack's candidate filter (api.lua:1787),
--     which is the on-sight acquisition loop; nothing in the attack STATE
--     consults it. So a prey animal never picks a target itself, and the
--     target do_punch hands it is unaffected. `attack_npcs` goes with it
--     (default true) so faction NPCs are not hunted either; attack_animals
--     and attack_monsters are already false by default (api.lua:169-172).
--   * `runaway` must be OFF. It is not merely redundant with retaliation,
--     the two collide: on_punch's runaway block (api.lua:2967) sets
--     `state = "runaway"` a dozen lines BEFORE the retaliation block resets
--     it to "" and calls do_attack — so the flee would be overwritten every
--     time and the field would only ever survive as a lie in the def. A
--     grazer that fights back does not flee.
--   * `attack_type` must be SET, and this is the field the first cut of the
--     verb forgot (WP36 review, HIGH). `passive = false` is necessary but
--     not sufficient: it buys the mob a `state = "attack"` and an
--     `self.attack` reference, and the attack STATE MACHINE is what turns
--     those into a fight. do_states' attack branch (api.lua:2214-2588)
--     dispatches on exactly three predicates — `"explode"` (:2277),
--     `"dogfight"`/`"dogshoot"` (:2360), `"shoot"`/`"dogshoot"` (:2539) —
--     with NO else, and mobs.mob_class carries no default (api.lua:120-178),
--     so an unset attack_type matched nothing. The retaliating grazer then:
--     dealt no damage (the punch at api.lua:2530 lives inside the dogfight
--     branch), played no "punch" clip (api.lua:2519, same branch), issued no
--     set_velocity at all — falling() only writes the y axis (api.lua:2640),
--     so it coasted on the knockback of api.lua:2951 in a straight line —
--     and was locked out of wander/stand as well, because on_step calls
--     do_states LIVE while `state == "attack"` (api.lua:3366) and
--     general_attack early-returns on it (api.lua:1769). Net effect: being
--     prey made a grazer strictly EASIER to kill than the 3 s `runaway`
--     flee it replaced, which is the exact inverse of §3.0's intent.
--     Two more systems read the field as "can this thing fight at all" and
--     were therefore no-ops on prey: the threat-driven target switch
--     (grug_core/combat.lua:182) and the Taunt ability (grug_abilities/
--     kits.lua:303).
--     `dogfight` is the melee family and the right one here: prey has no
--     `arrow`, so `shoot`/`dogshoot` would fire nothing, and `explode` is
--     the creeper family. The dogfight branch needs `reach` (3, the
--     mob_class default), `punch_interval` (1, api.lua:3534),
--     `damage_group` (nil -> "fleshy", api.lua:2528) and `self.damage`,
--     which levels.lua's apply_stats already sets from the field formula —
--     all four are in place, so this is one field and no new tuning.
--     Written as `def.attack_type or "dogfight"` so a def may still choose
--     its own; none of the five does today.
--
-- What this does NOT do is let prey INITIATE. Target acquisition on sight
-- lives in general_attack alone, and `attack_players = false` removes every
-- player candidate there before an attack_type is ever consulted (the field
-- is not read in that function at all). The other do_attack callers are all
-- provocation: on_punch's own retaliation, the group alert (api.lua:2997 —
-- needs `group_attack`, which no prey def sets), threat/taunt (both only
-- reachable once the mob has been hit), and our pack/swarm verbs (not
-- applied to prey). See `no_acquire` in init.lua/aggro.lua, which turns the
-- resulting guaranteed-empty scan off entirely.
--
-- The critters keep `passive = true` + `runaway = true` (rabbit.lua) — that
-- is the OTHER class of §3.0 and the reason this helper exists as its own
-- named verb instead of as "the animal default".
--
function grug_mobs.passive_prey(def)
	def.passive = false
	def.attack_players = false
	def.attack_npcs = false
	def.runaway = false
	def.attack_type = def.attack_type or "dogfight"
	return def
end
