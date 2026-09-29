-- Read the shared combat flag; HUD visibility does not own a second timer.
-- The combat state is an icon (Round 26 ruling 19: crossed swords on the gold
-- neutral frame) at the old "Combat" text's place right of the health bar,
-- vertically centred on it at hud_layout.COMBAT_ICON px.
local shown, elapsed = {}, 0
local TEXTURE = grug_core.status_icons.texture("in_combat")
local SCALE = grug_core.hud_layout.COMBAT_ICON / 64

core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.2 then return end
	elapsed = elapsed % 0.2
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local fighting = player:get_hp() > 0 and grug_core.in_combat(player)
		if fighting and not shown[name] then
			local definition = grug_core.hud_layout.image_element("combat", {
				text = TEXTURE, scale = {x = SCALE, y = SCALE}, z_index = 1,
			})
			-- Left edge on the anchor, like the text it replaces.
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
