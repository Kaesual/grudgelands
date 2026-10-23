-- The nodes of the Miner's Guild lift rooms (Round 58 lane ROOMS;
-- wp40/guild_rooms.lua owns the shape, wp40/guild_room_writer.lua writes it).
-- Placeholder looks from shipped textures. Every one is non-ground-content
-- (a neighbouring chunk's caves, flooded caves and dungeons carve and flood
-- only ground content, so they never cut into a room), can never be dug or
-- blown up and drops nothing; the rooms are protected boxes besides.
--   room_fill        the open room and its exits: airlike, light passes, not
--                    walkable, so players and mobs move through it as through
--                    air; not floodable and not buildable_to, so no liquid
--                    flows into it and nothing is placed into it; never
--                    pointed at. Modelled on grug_mobs:rift_void without its
--                    liquid movement, damage and tint, so the travel path's
--                    `passable()` (grug_home/travel.lua) takes it.
--   room_floor       the floor under the room and its exits (a full normal
--                    node, as the travel path's safe arrival wants).
--   room_lamp        the four wall lamps (light 14; the look of default's Mese
--                    Lamp, a node the game's content curation removes).
--   room_mantle_t1 .. t6  the shell round the room, in the look of its
--                    tier's host rock (default:stone, the tier rocks).
--   room_plug_t1 .. t6    the blind end one node past each exit, outside the
--                    protected box: the host rock's look, dig groups (its
--                    tier's pick gate) and drop (Cobble), but non-ground-
--                    content, so no cave opens it; the only one of these
--                    nodes a player digs.
--
--   dofile(modpath .. "/guild_room_nodes.lua")(core, grug_materials)
return function(engine, materials)
	local R = dofile(engine.get_modpath("grug_mapgen") .. "/wp40/guild_rooms.lua")
	local NODES = R.NODES
	local function noop() end
	local stone_sounds = default.node_sound_stone_defaults()

	engine.register_node(NODES.fill, {
		description = "Guild Room Air",
		drawtype = "airlike",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = false,
		floodable = false,
		is_ground_content = false,
		drop = "",
		groups = {not_in_creative_inventory = 1},
		on_blast = noop,
	})

	engine.register_node(NODES.floor, {
		description = "Guild Room Floor",
		tiles = {"default_stone_block.png"},
		diggable = false,
		is_ground_content = false,
		drop = "",
		groups = {not_in_creative_inventory = 1},
		on_blast = noop,
		sounds = stone_sounds,
	})

	-- A light source spreads only with paramtype "light" (the engine's
	-- spreadLight skips a node whose light does not propagate).
	engine.register_node(NODES.lamp, {
		description = "Guild Room Lamp",
		drawtype = "glasslike",
		tiles = {"default_meselamp.png"},
		paramtype = "light",
		sunlight_propagates = true,
		light_source = 14,
		diggable = false,
		is_ground_content = false,
		drop = "",
		groups = {not_in_creative_inventory = 1},
		on_blast = noop,
		sounds = default.node_sound_glass_defaults(),
	})

	for tier = 1, R.TIERS do
		local host = engine.registered_nodes[materials.TIERS[tier].node]
		assert(type(host) == "table" and type(host.tiles) == "table",
			"guild room nodes: the tier " .. tier .. " host rock is not registered")
		local tiles = {}
		for index, tile in ipairs(host.tiles) do tiles[index] = tile end
		engine.register_node(NODES.mantle[tier], {
			description = "Guild Room Rock",
			tiles = tiles,
			diggable = false,
			is_ground_content = false,
			drop = "",
			groups = {not_in_creative_inventory = 1},
			on_blast = noop,
			sounds = stone_sounds,
		})
		-- The plug digs like its host rock: the host's groups (grug_stratum
		-- with them, which grug_materials' audit pairs with the pick gate
		-- `level`), but not grug_natural: it is no generated natural ground.
		local groups = {not_in_creative_inventory = 1}
		for group, value in pairs(host.groups or {}) do
			if group ~= "grug_natural" then groups[group] = value end
		end
		engine.register_node(NODES.plug[tier], {
			description = host.description,
			tiles = tiles,
			groups = groups,
			drop = host.drop or "default:cobble",
			is_ground_content = false,
			sounds = host.sounds or stone_sounds,
		})
	end
end
