grug_mobs = {}

--
-- Wrapper around mobs:register_mob with our extensions:
--   def._grug_xp_reward   — XP for the killer (player)
--   def._grug_faction     — faction id; the mob never attacks its own faction
--                          and is readable via grug_factions.get_object_faction
--   def._grug_spawn_zones — list of zone names (grug_core.zone_at: core,
--                          inner, outer, coast, war_coast, strait, ocean,
--                          underground) the mob may spawn in; nil = anywhere
--                          (WP6 replaces this with full level-tier gating)
--

local spawn_zones = {} -- mob name -> set of allowed zone names

-- mobs_redo's global hook for additional spawn checks (an empty stub
-- upstream; returning true BLOCKS the spawn).
function mobs:spawn_abm_check(pos, node, name)
	local zones = spawn_zones[name]
	if zones and not zones[grug_core.zone_at(pos)] then
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
	local xp_reward = def._grug_xp_reward or 0
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

	-- Player punches (auto-attacks AND ability punches) pass through here:
	-- feeds combat marking + rage generation via grug_core. NB mobs_redo's
	-- do_punch handling cancels the punch on any truthy return — return nil
	-- when unconcerned.
	-- Kill credit/XP is ALSO detected here (lethal punch): both of
	-- mobs_redo's death hooks (on_death/on_die) skip the death animation,
	-- so we must not install one.
	local old_do_punch = def.do_punch
	def.do_punch = function(self, hitter, tflp, tool_capabilities, dir, damage)
		if hitter and hitter:is_player() then
			-- Provocation memory (runtime only, self.temp is never
			-- persisted): the undead night truce below excludes players
			-- who attacked this mob.
			self.temp = self.temp or {}
			self.temp.grug_provoked = self.temp.grug_provoked or {}
			self.temp.grug_provoked[hitter:get_player_name()] = true
			grug_core.run_player_hit_mob(hitter, self, damage or 0)
			self.temp = self.temp or {}
			if xp_reward > 0 and not self.temp.grug_xp_awarded and
					self.health - math.floor(damage or 0) <= 0 then
				self.temp.grug_xp_awarded = true
				grug_xp.add_xp(hitter, xp_reward)
				core.chat_send_player(hitter:get_player_name(),
					core.colorize("#aa66ff", "+" .. xp_reward .. " XP"))
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

	local old_do_custom = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		tick_speed_effects(self, dtime)
		if night_truce then
			-- Target-acquisition veto consumed by general_attack (GRUG PATCH
			-- in mobs/api.lua): the mob skips truce players and picks the
			-- next-closest viable target instead. A function field is never
			-- serialized into staticdata; do_custom runs before
			-- general_attack on every step, so it is back after each
			-- (re)activation in time.
			if not self._grug_ignore_player then
				self._grug_ignore_player = function(s, player)
					return truce_active(s, player)
				end
			end
			-- Belt and braces for acquisition paths that bypass
			-- general_attack (group_attack pile-ons, do_attack calls):
			-- drop unprovoked truce players again.
			if self.state == "attack" and self.attack
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
dofile(modpath .. "/items.lua")
dofile(modpath .. "/boar.lua")
dofile(modpath .. "/zombie.lua")
