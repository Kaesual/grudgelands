-- Native minimap policy. The client still owns its enable setting and V toggle;
-- the server only narrows the cycle to surface/off and chooses surface on join.
local MODES = {
	{type = "surface", size = 256},
	{type = "off"},
}

local function configure_player(player)
	-- Remote players use ObjectProperties markers. The local direction arrow is
	-- rendered separately by the client and therefore survives this property.
	player:set_properties({show_on_minimap = false})
	player:set_minimap_modes(MODES, 0)
end

core.register_on_mods_loaded(function()
	-- Entity definitions are the global marker authority. This changes only
	-- minimap dots; visual, nametag, pointability and observer state are intact.
	for _, definition in pairs(core.registered_entities) do
		definition.initial_properties = definition.initial_properties or {}
		definition.initial_properties.show_on_minimap = false
	end
end)

core.register_on_joinplayer(configure_player)
