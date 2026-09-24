-- Shared successful-action boundary; never shorten an existing melee deadline.
return function(progress)
	return function(player)
		local name, now = player:get_player_name(), core.get_us_time()
		local weapon = grug_core.get_equipped_weapon(player) or ItemStack("")
		local _, interval = grug_abilities.swing_stats(player, weapon)
		local rec = progress[name] or {weapon = ItemStack(weapon), next_due = 0}
		rec.next_due = math.max(rec.next_due, now + interval * 1000000)
		progress[name] = rec
	end
end
