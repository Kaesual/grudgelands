wob_mobs = {}

--
-- Wrapper around mobs:register_mob with our extensions:
--   def._wob_xp_reward  — XP for the killer (player)
--   def._wob_faction    — faction id; the mob never attacks its own faction
--                         and is readable via wob_factions.get_object_faction
--
function wob_mobs.register_mob(name, def)
	local xp_reward = def._wob_xp_reward or 0
	local faction = def._wob_faction

	local old_on_death = def.on_death
	def.on_death = function(self, killer)
		if xp_reward > 0 and killer and killer:is_player() then
			wob_xp.add_xp(killer, xp_reward)
			core.chat_send_player(killer:get_player_name(),
				core.colorize("#aa66ff", "+" .. xp_reward .. " XP"))
		end
		if old_on_death then
			return old_on_death(self, killer)
		end
	end

	if faction then
		local old_do_custom = def.do_custom
		def.do_custom = function(self, dtime, moveresult)
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
			if old_do_custom then
				return old_do_custom(self, dtime, moveresult)
			end
		end
	end

	mobs:register_mob(name, def)
end

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/items.lua")
dofile(modpath .. "/boar.lua")
dofile(modpath .. "/zombie.lua")
