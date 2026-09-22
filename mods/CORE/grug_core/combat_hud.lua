-- Read the shared combat flag; HUD visibility does not own a second timer.
local shown, elapsed = {}, 0

core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.2 then return end
	elapsed = elapsed % 0.2
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local fighting = player:get_hp() > 0 and grug_core.in_combat(player)
		if fighting and not shown[name] then
			local definition = grug_core.hud_layout.text_element("combat", {
				text = "Combat", number = 0xff785a, z_index = 1,
			})
			definition.alignment.x = 1
			shown[name] = player:hud_add(definition)
		elseif not fighting and shown[name] then
			player:hud_remove(shown[name])
			shown[name] = nil
		end
	end
end)

core.register_on_leaveplayer(function(player)
	shown[player:get_player_name()] = nil
end)
