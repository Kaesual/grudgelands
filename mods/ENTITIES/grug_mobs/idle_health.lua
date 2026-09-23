-- Full-health reset for living combat actors after a genuinely quiet period.
--
-- HP sampling is deliberate: punches, abilities, node damage and bespoke
-- damage-over-time paths do not share one settlement callback. Observing the
-- authoritative health field in the existing one-second mob cadence covers
-- every source without adding hooks to each producer.

local QUIET_TIME = 30
local boss_activity = {}

local function encounter_id(self)
	return self and (self._grug_boss_id or self._grug_boss_summon
		or self._grug_royal_summon)
end

function grug_mobs.touch_boss_activity(self, now)
	local id = encounter_id(self)
	local at = now or grug_core.mono_time()
	if id and (boss_activity[id] == nil or at > boss_activity[id]) then
		boss_activity[id] = at
	end
end

function grug_mobs.boss_recently_active(self, now, quiet_time)
	local at = boss_activity[encounter_id(self)]
	return at ~= nil and (now or grug_core.mono_time()) - at < quiet_time
end

function grug_mobs.clear_boss_activity(id)
	if id then boss_activity[id] = nil end
end

local function boss_action_active(self)
	local temp = self.temp
	return temp and (temp.grug_royal_cast
		or (temp.grug_dragon and temp.grug_dragon.action)) ~= nil
end

local function calm(self)
	return not self.attack
		and (self.state == "stand" or self.state == "walk")
		and not (self.temp and self.temp.grug_evading)
		and not boss_action_active(self)
end

function grug_mobs.idle_health_tick(self)
	self.temp = self.temp or {}
	local temp = self.temp
	local now = grug_core.mono_time()
	local health = self.health or 0
	local previous = temp.grug_idle_health

	-- Runtime-only by design. A newly activated actor must first demonstrate a
	-- complete quiet window; an unload/reload can never become an instant heal.
	if previous == nil then
		temp.grug_idle_health = health
		temp.grug_idle_busy_at = now
		-- Activation itself gives this actor its local grace. Only a real combat
		-- signal is shared, so loading one calm group member cannot delay all of
		-- its companions; an already-attacking first sample still closes the
		-- group boundary immediately.
		if not calm(self) then
			temp.grug_idle_activity_at = now
			grug_mobs.touch_boss_activity(self, now)
		end
		return false
	end

	local took_damage = health < previous
	temp.grug_idle_health = health
	local active_now = took_damage or not calm(self)
	if active_now then
		temp.grug_idle_busy_at = now
		temp.grug_idle_activity_at = now
	end

	-- Encounter activity is shared without object scans. Keep touching it for
	-- the whole local quiet window, including the first tick after a boss id is
	-- installed by a bespoke callback later in the preceding wrapper tick.
	local locally_busy = now - (temp.grug_idle_busy_at or now) < QUIET_TIME
	local activity_at = temp.grug_idle_activity_at
	if activity_at and now - activity_at < QUIET_TIME then
		-- Passing the original activity time lets a boss id installed one
		-- callback late join its group without extending thirty seconds of local
		-- quiet into sixty seconds of shared quiet. Activation grace and a
		-- completed heal are local eligibility only, never shared combat.
		grug_mobs.touch_boss_activity(self, activity_at)
	end
	if grug_mobs.boss_recently_active(self, now, QUIET_TIME) then
		return false
	end

	local hp_max = self.hp_max
	if health <= 0 or not hp_max or hp_max <= 0 or health >= hp_max
			or not calm(self) or locally_busy then
		return false
	end

	-- Use the established reset transaction: besides healing, it clears the
	-- target, threat, loot tag and transient boss action while synchronizing
	-- mobs_redo's health bookkeeping. The positive-health guard above prevents
	-- this path from ever resurrecting a dying actor.
	grug_mobs.leash_reset(self)
	temp.grug_idle_health = self.health or health
	temp.grug_idle_busy_at = now
	return true
end
