grug_mobs = {}

-- Mod-wide persistence (AGENTS.md: fetch at load time). Currently only the
-- named-rare spawner writes here (rares.lua).
grug_mobs.storage = core.get_mod_storage()

--
-- Wrapper around mobs:register_mob with our extensions:
--   def._grug_xp_reward   — XP for the killer (player); OVERRIDES the level
--                          formula (levels.lua), normally left unset
--   def._grug_min_level   — level floor (default 1) and the fallback level
--                          where the level field has no value
--   def._grug_max_level   — level cap (default: the source cap, 60/70)
--   def._grug_fixed_level — hand-set level, bypasses the field and the cap
--   def._grug_level_source — "mob" (default, grug_core.mob_level_at) or
--                          "guard" (grug_core.guard_level_at)
--   def._grug_tier        — "normal" (default) | "elite" | "rare"
--   def._grug_faction     — faction id; the mob never attacks its own faction
--                          and is readable via grug_factions.get_object_faction
--   def._grug_spawn_zones — list of zone names (grug_core.zone_at: core,
--                          inner, outer, coast, war_coast, strait, ocean,
--                          underground) the mob may spawn in; nil = anywhere
--                          (WP6 replaces this with full level-tier gating)
--   def._grug_spawn_check — function(pos) -> true if the mob may spawn there;
--                          for gates the zone vocabulary cannot express (the
--                          Kraken's open sea is a sub-area of zone "ocean").
--                          nil = no extra check. Zones and check are ANDed.
--   def._grug_leash_range — per-def leash radius in nodes around the home
--                          position (default grug_mobs.LEASH_RANGE = 40);
--                          the "territorial" verb of bear/ape uses ~20
--   def._grug_no_leash    — true: never gives up a player chase and never
--                          resets/heals (zombie verb "never leashes"; mobs
--                          with a hand-rolled leash of their own: kraken)
--   def._grug_soft_deaggro — false: opt out of the 25 m walk-speed rule
--                          (GRUG PATCH in mobs/api.lua do_states)
--

local spawn_zones = {} -- mob name -> set of allowed zone names
local spawn_checks = {} -- mob name -> function(pos) -> allowed?

-- mobs_redo's global hook for additional spawn checks (an empty stub
-- upstream; returning true BLOCKS the spawn). A mob with neither zones nor
-- a check spawns wherever its mobs:spawn() row allows.
function mobs:spawn_abm_check(pos, node, name)
	local zones = spawn_zones[name]
	if zones and not zones[grug_core.zone_at(pos)] then
		return true
	end
	local check = spawn_checks[name]
	if check and not check(pos) then
		return true
	end
end

--
-- Root/slow support (Frost Nova, Hamstring): scales walk/run velocity,
-- restored by a countdown that ticks in do_custom. Deliberately NOT a
-- core.after timer: mobs_redo persists all plain entity fields in
-- staticdata, so a lost timer (relog/restart inside the effect window)
-- would save the mob permanently immobile. The countdown fields persist
-- WITH the mob and self-heal on the next active tick — including mobs
-- from old saves that carry effect state without a countdown.
--
-- Model: `_grug_speed_base` holds the original speeds while any effect is
-- active. A root (speed 0) runs first; a pending slow (base × factor)
-- only starts counting once the root has expired ("root, THEN slow").
--

local function save_speed_base(ent)
	if not ent._grug_speed_base then
		ent._grug_speed_base = {walk = ent.walk_velocity, run = ent.run_velocity}
	end
end

function grug_mobs.root(ent, duration)
	save_speed_base(ent)
	ent.walk_velocity = 0
	ent.run_velocity = 0
	ent._grug_root_left = math.max(ent._grug_root_left or 0, duration)
	local obj = ent.object
	local v = obj and obj:get_velocity()
	if v then
		obj:set_velocity(vector.new(0, v.y, 0))
	end
end

-- Slow to `factor` (e.g. 0.5 = half speed) for `duration` seconds. While
-- a root is active the slow is queued and its duration starts afterwards.
-- Overlapping slows: the stronger factor and the longer remaining
-- duration win (a weaker re-application must not lift a stronger snare).
function grug_mobs.slow(ent, duration, factor)
	save_speed_base(ent)
	ent._grug_slow_factor = math.min(ent._grug_slow_factor or factor, factor)
	factor = ent._grug_slow_factor
	ent._grug_slow_left = math.max(ent._grug_slow_left or 0, duration)
	if (ent._grug_root_left or 0) <= 0 then
		ent.walk_velocity = ent._grug_speed_base.walk * factor
		ent.run_velocity = ent._grug_speed_base.run * factor
	end
end

local function tick_speed_effects(self, dtime)
	if not self._grug_speed_base then
		return
	end
	if (self._grug_root_left or 0) > 0 then
		self._grug_root_left = self._grug_root_left - dtime
		if self._grug_root_left > 0 then
			return
		end
		self._grug_root_left = nil
	end
	if (self._grug_slow_left or 0) > 0 then
		-- Re-applied every tick: idempotent field writes, self-heals mobs
		-- reactivated mid-slow from a save.
		local factor = self._grug_slow_factor or 0.5
		self.walk_velocity = self._grug_speed_base.walk * factor
		self.run_velocity = self._grug_speed_base.run * factor
		self._grug_slow_left = self._grug_slow_left - dtime
		if self._grug_slow_left > 0 then
			return
		end
	end
	-- All effects expired (or stale state from an old/broken save): restore.
	self.walk_velocity = self._grug_speed_base.walk
	self.run_velocity = self._grug_speed_base.run
	self._grug_speed_base = nil
	self._grug_root_left = nil
	self._grug_slow_left = nil
	self._grug_slow_factor = nil
end

-- Night window matching mobs_redo's day_toggle convention
-- (day = timeofday in (4500, 19500) of 24000).
function grug_mobs.is_night()
	local tod = core.get_timeofday()
	return tod <= 0.1875 or tod >= 0.8125
end

function grug_mobs.register_mob(name, def)
	-- Level/tier config + stat derivation (levels.lua); HP, damage and XP
	-- are engine-owned from here on, the def must not hand-set them.
	grug_mobs.register_level_cfg(name, def)
	-- Aggro config kept as an upvalue: mobs_redo does not copy custom def
	-- fields onto the entity, so the wrappers install them at runtime
	-- (grug_mobs.apply_aggro_fields, aggro.lua).
	local aggro_cfg = {
		no_leash = def._grug_no_leash,
		soft_deaggro = def._grug_soft_deaggro,
		leash_range = def._grug_leash_range,
	}
	local faction = def._grug_faction
	-- Race-perk key (world.md §7): players holding this perk are dropped
	-- as targets at night unless they provoked the mob (undead passive).
	local night_truce = def._grug_night_truce_perk

	if def._grug_spawn_zones then
		local set = {}
		for _, zone in ipairs(def._grug_spawn_zones) do
			set[zone] = true
		end
		spawn_zones[name] = set
	end
	if def._grug_spawn_check then
		spawn_checks[name] = def._grug_spawn_check
	end

	-- Player punches (auto-attacks AND ability punches) pass through here:
	-- feeds combat marking + rage generation via grug_core. NB mobs_redo's
	-- do_punch handling cancels the punch on any truthy return — return nil
	-- when unconcerned.
	-- Kill credit/XP is ALSO detected here (lethal punch): both of
	-- mobs_redo's death hooks (on_death/on_die) skip the death animation,
	-- so we must not install one.
	local old_do_punch = def.do_punch
	def.do_punch = function(self, hitter, tflp, tool_capabilities, dir, damage)
		-- A mob can be punched before its first do_custom tick, and the XP
		-- below needs its level: initialize here too (idempotent).
		grug_mobs.ensure_init(self)
		grug_mobs.apply_aggro_fields(self, aggro_cfg)
		if hitter and hitter:is_player() then
			-- Provocation memory (runtime only, self.temp is never
			-- persisted): the undead night truce below excludes players
			-- who attacked this mob.
			self.temp = self.temp or {}
			self.temp.grug_provoked = self.temp.grug_provoked or {}
			self.temp.grug_provoked[hitter:get_player_name()] = true
			-- Loot rights (combat_stats.md §3): every player hit renews the
			-- 60 s drop tag. Plain field -> survives unload (aggro.lua).
			grug_mobs.tag_player(self, hitter)
			-- Base threat + combat marking + rage; also refreshes the leash
			-- contact clock (grug_core/combat.lua).
			grug_core.run_player_hit_mob(hitter, self, damage or 0)
			-- Lethal? mobs_redo subtracts the damage right after this wrapper
			-- returns (api.lua:2698ff), so this is the earliest — and only —
			-- place where killer AND victim are both known.
			local lethal = self.health - math.floor(damage or 0) <= 0
			-- Named rare killed by a player: start its respawn timer
			-- (rares.lua). Deliberately OUTSIDE the XP branch below — the
			-- gray rule can zero the XP, the kill still counts.
			if lethal and self._grug_rare_id and
					not self.temp.grug_rare_death_sent then
				self.temp.grug_rare_death_sent = true
				grug_mobs.rare_killed(self._grug_rare_id)
			end
			local xp = grug_mobs.kill_xp(self)
			if xp > 0 and not self.temp.grug_xp_awarded and lethal then
				self.temp.grug_xp_awarded = true
				-- Gray rule (combat_stats.md §6): a mob at killer level - 10
				-- or below pays nothing, and says nothing.
				if (self._grug_level or 1) <= grug_xp.get_level(hitter) - 10 then
					xp = 0
				end
				if xp > 0 then
					grug_xp.add_xp(hitter, xp, "kill")
					core.chat_send_player(hitter:get_player_name(),
						core.colorize("#aa66ff", "+" .. xp .. " XP"))
				end
			end
		end
		if old_do_punch then
			return old_do_punch(self, hitter, tflp, tool_capabilities, dir, damage)
		end
	end

	-- Does the night truce currently protect this player from this mob?
	-- (truce perk race, night time, and the player has not provoked THIS mob)
	local function truce_active(self, player)
		return grug_mobs.is_night()
			and grug_core.get_race_perk(player, night_truce) ~= nil
			and not (self.temp and self.temp.grug_provoked
				and self.temp.grug_provoked[player:get_player_name()])
	end

	-- Faction-aware target acquisition (combat_stats.md §4, WP6): a faction
	-- mob never targets its OWN faction — and never targets factionless
	-- players either. Those are brand-new characters who have not chosen a
	-- side yet (still on the spawn platform); letting faction guards hunt
	-- them would be pure griefing. Monsters have no faction and are
	-- unaffected.
	local function faction_veto(player)
		if not faction then
			return false
		end
		local pf = grug_core.get_player_faction(player:get_player_name())
		return pf == nil or pf == faction
	end

	local old_do_custom = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		-- First-tick level/stat assignment + per-activation nametag hook.
		grug_mobs.ensure_init(self)
		-- Runs before do_states/general_attack in the same step (api.lua:
		-- 3137 vs. 3144/3156), so the aggro fields the api.lua patches read
		-- are always in place in time.
		grug_mobs.apply_aggro_fields(self, aggro_cfg)
		tick_speed_effects(self, dtime)
		grug_mobs.leash_tick(self, dtime)
		-- Elite/rare wind-up (telegraph.lua). Guarded here so a normal mob
		-- pays one field comparison per step and nothing else.
		if self._grug_tier and self._grug_tier ~= "normal" then
			grug_mobs.telegraph_tick(self, dtime)
		end
		-- Named-rare patrol (rares.lua); the flag only exists on the handful
		-- of mobs the rare spawner placed.
		if self._grug_rare_id then
			grug_mobs.rare_tick(self, dtime)
		end
		if night_truce or faction then
			-- ONE target-acquisition veto consumed by general_attack (GRUG
			-- PATCH in mobs/api.lua): the mob skips vetoed players and picks
			-- the next-closest viable target instead. A function field is
			-- never serialized into staticdata; do_custom runs before
			-- general_attack on every step, so it is back after each
			-- (re)activation in time.
			if not self._grug_ignore_player then
				self._grug_ignore_player = function(s, player)
					return (night_truce and truce_active(s, player))
						or faction_veto(player)
				end
			end
			-- Belt and braces for acquisition paths that bypass
			-- general_attack (group_attack pile-ons, do_attack calls):
			-- drop unprovoked truce players again.
			if night_truce and self.state == "attack" and self.attack
					and core.is_player(self.attack)
					and truce_active(self, self.attack) then
				self:stop_attack()
			end
		end
		if faction then
			-- Store the faction on the entity (every activation, first tick)
			-- so other systems can read it via get_object_faction.
			if not self._grug_faction then
				self._grug_faction = faction
			end
			-- Never attack the own faction (e.g. after provoking/group_attack).
			if self.state == "attack" and self.attack and
					grug_factions.get_object_faction(self.attack) == faction then
				self:stop_attack()
			end
		end
		if old_do_custom then
			return old_do_custom(self, dtime, moveresult)
		end
	end

	mobs:register_mob(name, def)
end

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/levels.lua")
dofile(modpath .. "/aggro.lua")
dofile(modpath .. "/verbs.lua")
dofile(modpath .. "/telegraph.lua")
dofile(modpath .. "/patrol.lua")
dofile(modpath .. "/target_frame.lua")
dofile(modpath .. "/items.lua")
dofile(modpath .. "/boar.lua")
dofile(modpath .. "/zombie.lua")
-- Settled + forest-pair roster (biomes_mobs.md §3.1, WP6/T5).
dofile(modpath .. "/boar_variants.lua")
dofile(modpath .. "/rabbit.lua")
dofile(modpath .. "/wolf.lua")
dofile(modpath .. "/bear.lua")
dofile(modpath .. "/stag.lua")
dofile(modpath .. "/spider.lua")
dofile(modpath .. "/skeleton_archer.lua")
-- Mountain pair, savanna extras and jungle group (biomes_mobs.md §3.1,
-- WP6/T6).
dofile(modpath .. "/eagle.lua")
dofile(modpath .. "/golem.lua")
dofile(modpath .. "/ram.lua")
dofile(modpath .. "/hyena.lua")
dofile(modpath .. "/zebra.lua")
dofile(modpath .. "/jungle_lynx.lua")
dofile(modpath .. "/panther.lua")
dofile(modpath .. "/serpent.lua")
dofile(modpath .. "/jungle_ape.lua")
dofile(modpath .. "/parrot.lua")
dofile(modpath .. "/kraken.lua")
-- Swamp, shore and war coast + the humanoid camp mechanism
-- (biomes_mobs.md §3.1/§4, WP6/T7). skeleton_raider.lua reuses the arrow
-- entity registered by skeleton_archer.lua above, so it must come after it;
-- camps.lua registers the camp TYPES and therefore comes after the two camp
-- families it names.
dofile(modpath .. "/crocodile.lua")
dofile(modpath .. "/bog_ooze.lua")
dofile(modpath .. "/gull.lua")
dofile(modpath .. "/carrion_crow.lua")
dofile(modpath .. "/skeleton_raider.lua")
dofile(modpath .. "/bandit.lua")
dofile(modpath .. "/mirefolk.lua")
-- Faction guards + military outposts (world.md §4, WP6/T8): guard.lua must
-- come before camps.lua, which names the two guard mobs in its camp types.
dofile(modpath .. "/guard.lua")
dofile(modpath .. "/camps.lua")
-- After the mob files: a rare spec names an already registered mob.
dofile(modpath .. "/rares.lua")
