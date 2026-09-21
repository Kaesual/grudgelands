-- Original scenery definitions. Textures are reused from shipped dependencies;
-- no source node callbacks, harvest groups, inventories or recipes are copied.
return function(engine)
	local tiles = {
		dwarf="default_copper_block.png", human="default_brick.png",
		elf="default_meselamp.png^[colorize:#ff7a2e:25",
		undead="default_stone_brick.png", orc="default_desert_cobble.png",
		troll="default_clay.png",
	}
	for race,texture in pairs(tiles) do
		engine.register_node("grug_mapgen:poi_display_"..race, {
			description="Camp Display", tiles={texture},
			is_ground_content=false, diggable=false, drop="",
			buildable_to=false, floodable=false,
			groups={not_in_creative_inventory=1},
		})
	end
end
