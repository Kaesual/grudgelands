wob_mobs = {}

--
-- Wrapper around mobs:register_mob with our extensions:
--   def._wob_xp_reward   — XP for the killer (player)
--   def._wob_faction     — faction id; the mob never attacks its own faction
--                          and is readable via wob_factions.get_object_faction
--   def._wob_spawn_zones — list of ring names (wob_core.zone_at) the mob may
--                          spawn in; nil = anywhere (WP6 replaces this with
--                          full level-tier gating)
--

local spawn_zones = {} -- mob name -> set of allowed zone names

-- mobs_redo's global hook for additional spawn checks (an empty stub
-- upstream; returning true BLOCKS the spawn).
function mobs:spawn_abm_check(pos, node, name)
	local zones = spawn_zones[name]
	if zones and not zones[wob_core.zone_at(pos)] then
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
-- Model: `_wob_speed_base` holds the original speeds while any effect is
-- active. A root (speed 0) runs first; a pending slow (base × factor)
-- only starts counting once the root has expired ("root, THEN slow").
--

local function save_speed_base(ent)
	if not ent._wob_speed_base then
		ent._wob_speed_base = {walk = ent.walk_velocity, run = ent.run_velocity}
	end
end

function wob_mobs.root(ent, duration)
	save_speed_base(ent)
	ent.walk_velocity = 0
	ent.run_velocity = 0
	ent._wob_root_left = math.max(ent._wob_root_left or 0, duration)
	local obj = ent.object
	local v = obj and obj:get_velocity()
	if v then
		obj:set_velocity(vector.new(0, v.y, 0))
	end
end

-- Slow to `factor` (e.g. 0.5 = half speed) for `duration` seconds. While
-- a root is active the slow is queued and its duration starts afterwards.
function wob_mobs.slow(ent, duration, factor)
	save_speed_base(ent)
	ent._wob_slow_factor = factor
	ent._wob_slow_left = math.max(ent._wob_slow_left or 0, duration)
	if (ent._wob_root_left or 0) <= 0 then
		ent.walk_velocity = ent._wob_speed_base.walk * factor
		ent.run_velocity = ent._wob_speed_base.run * factor
	end
end

local function tick_speed_effects(self, dtime)
	-- Migrate pre-WP19 saves that used the old `_wob_root` field.
	if self._wob_root then
		self._wob_speed_base = self._wob_speed_base or self._wob_root
		self._wob_root = nil
	end
	if not self._wob_speed_base then
		return
	end
	if (self._wob_root_left or 0) > 0 then
		self._wob_root_left = self._wob_root_left - dtime
		if self._wob_root_left > 0 then
			return
		end
		self._wob_root_left = nil
	end
	if (self._wob_slow_left or 0) > 0 then
		-- Re-applied every tick: idempotent field writes, self-heals mobs
		-- reactivated mid-slow from a save.
		local factor = self._wob_slow_factor or 0.5
		self.walk_velocity = self._wob_speed_base.walk * factor
		self.run_velocity = self._wob_speed_base.run * factor
		self._wob_slow_left = self._wob_slow_left - dtime
		if self._wob_slow_left > 0 then
			return
		end
	end
	-- All effects expired (or stale state from an old/broken save): restore.
	self.walk_velocity = self._wob_speed_base.walk
	self.run_velocity = self._wob_speed_base.run
	self._wob_speed_base = nil
	self._wob_root_left = nil
	self._wob_slow_left = nil
	self._wob_slow_factor = nil
end

-- Night window matching mobs_redo's day_toggle convention
-- (day = timeofday in (4500, 19500) of 24000).
function wob_mobs.is_night()
	local tod = core.get_timeofday()
	return tod <= 0.1875 or tod >= 0.8125
end

function wob_mobs.register_mob(name, def)
	local xp_reward = def._wob_xp_reward or 0
	local faction = def._wob_faction
	-- Race-perk key (world.md §7): players holding this perk are dropped
	-- as targets at night unless they provoked the mob (undead passive).
	local night_truce = def._wob_night_truce_perk

	if def._wob_spawn_zones then
		local set = {}
		for _, zone in ipairs(def._wob_spawn_zones) do
			set[zone] = true
		end
		spawn_zones[name] = set
	end

	-- Player punches (auto-attacks AND ability punches) pass through here:
	-- feeds combat marking + rage generation via wob_core. NB mobs_redo's
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
			self.temp.wob_provoked = self.temp.wob_provoked or {}
			self.temp.wob_provoked[hitter:get_player_name()] = true
			wob_core.run_player_hit_mob(hitter, self, damage or 0)
			self.temp = self.temp or {}
			if xp_reward > 0 and not self.temp.wob_xp_awarded and
					self.health - math.floor(damage or 0) <= 0 then
				self.temp.wob_xp_awarded = true
				wob_xp.add_xp(hitter, xp_reward)
				core.chat_send_player(hitter:get_player_name(),
					core.colorize("#aa66ff", "+" .. xp_reward .. " XP"))
			end
		end
		if old_do_punch then
			return old_do_punch(self, hitter, tflp, tool_capabilities, dir, damage)
		end
	end

	local old_do_custom = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		tick_speed_effects(self, dtime)
		-- Undead night truce: drop unprovoked truce-race player targets.
		-- (general_attack may briefly re-acquire; this runs every tick, so
		-- the mob never actually closes in — same pattern as the
		-- own-faction check below.)
		if night_truce and self.state == "attack" and self.attack
				and core.is_player(self.attack)
				and wob_mobs.is_night()
				and wob_core.get_race_perk(self.attack, night_truce)
				and not (self.temp and self.temp.wob_provoked
					and self.temp.wob_provoked[self.attack:get_player_name()]) then
			self:stop_attack()
		end
		if faction then
			-- Store the faction on the entity (every activation, first tick)
			-- so other systems can read it via get_object_faction.
			if not self._wob_faction then
				self._wob_faction = faction
			end
			-- Never attack the own faction (e.g. after provoking/group_attack).
			if self.state == "attack" and self.attack and
					wob_factions.get_object_faction(self.attack) == faction then
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
