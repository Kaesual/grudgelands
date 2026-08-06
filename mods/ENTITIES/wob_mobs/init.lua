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
-- Root/snare support (Frost Nova etc.): zeroes walk/run velocity, restored
-- by a countdown that ticks in do_custom. Deliberately NOT a core.after
-- timer: mobs_redo persists all plain entity fields in staticdata, so a
-- lost timer (relog/restart inside the root window) would save the mob
-- permanently immobile. The countdown fields persist WITH the mob and
-- self-heal on the next active tick — including mobs from old saves that
-- carry root state without a countdown.
--

function wob_mobs.root(ent, duration)
	if not ent._wob_root then
		ent._wob_root = {walk = ent.walk_velocity, run = ent.run_velocity}
		ent.walk_velocity = 0
		ent.run_velocity = 0
	end
	ent._wob_root_left = duration
	local obj = ent.object
	local v = obj and obj:get_velocity()
	if v then
		obj:set_velocity(vector.new(0, v.y, 0))
	end
end

local function tick_root(self, dtime)
	if not self._wob_root then
		return
	end
	-- No countdown = stale state from an old/broken save: expires now.
	self._wob_root_left = (self._wob_root_left or 0) - dtime
	if self._wob_root_left <= 0 then
		self.walk_velocity = self._wob_root.walk
		self.run_velocity = self._wob_root.run
		self._wob_root = nil
		self._wob_root_left = nil
	end
end

function wob_mobs.register_mob(name, def)
	local xp_reward = def._wob_xp_reward or 0
	local faction = def._wob_faction

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
		tick_root(self, dtime)
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
