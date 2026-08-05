wob_mobs = {}

--
-- Wrapper um mobs:register_mob mit unseren Erweiterungen:
--   def._wob_xp_reward  — XP fuer den Killer (Spieler)
--   def._wob_faction    — Fraktions-ID; Mob greift eigene Fraktion nie an
--                         und ist fuer wob_factions.get_object_faction lesbar
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
			-- Fraktion am Entity hinterlegen (jede Aktivierung, erster Tick),
			-- damit andere Systeme sie via get_object_faction lesen koennen.
			if not self._wob_faction then
				self._wob_faction = faction
			end
			-- Eigene Fraktion nie angreifen (z. B. nach Verhetzen/group_attack).
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
