-- Shared successful-action boundary, the action clock's cast -> swing side
-- (D2): the next melee swing waits `def.occupied_swing` seconds, by default
-- ("weapon", or no def: the Scout's bow release) one interval of the current
-- melee weapon. Never shortens an existing melee deadline.
return function(progress)
	return function(player, def)
		local name, now = player:get_player_name(), core.get_us_time()
		local weapon = grug_core.get_melee_weapon(player) or ItemStack("")
		local seconds = def and def.occupied_swing
		if type(seconds) ~= "number" then
			local _, interval = grug_abilities.swing_stats(player, weapon)
			seconds = interval
		end
		local rec = progress[name] or {weapon = ItemStack(weapon), next_due = 0}
		rec.next_due = math.max(rec.next_due, now + seconds * 1000000)
		progress[name] = rec
	end
end
