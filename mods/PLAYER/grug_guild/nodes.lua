-- The Stonewright's nodes (Round 70, spec §5.3): the five ornamented stones
-- and the cells of the two machines behind him. The building templates place
-- them and the settlement content resolves its targets while grug_mapgen
-- loads, before this mod (`fail_content_manifest` in wp40/r7_content.lua), so
-- grug_mapgen's init.lua runs this file; hence the ":" of the names, as
-- grug_nodes registers the farm's soil.
--
--   dofile(core.get_modpath("grug_guild") .. "/nodes.lua")(core)
return function(engine)
	local path = engine.get_modpath("grug_guild")
	local catalog = dofile(path .. "/catalog.lua")

	-- The stones: cut stone like `default:stone_block`, a tier for the price
	-- rules (`_grug_tier`, economy.md §2), priced by their recipe.
	for _, row in ipairs(catalog.ORNAMENTED) do
		engine.register_node(":" .. row.output, {
			description = row.name,
			tiles = {"grug_guild_" .. row.id .. ".png"},
			is_ground_content = false,
			groups = {cracky = 2, stone = 1},
			sounds = default.node_sound_stone_defaults(),
			_grug_tier = row.tier,
		})
	end

	-- The machines: placed decoration in the six guild houses
	-- (tools/r58_halls/make_halls.py), one node per occupied cell with the
	-- picked boxes and faces (machines_data.lua, written by
	-- tools/r70_guild/make_machines.py). The furnace always burns: its four
	-- hearth cells animate and glow, and one cell of it is the furnace loop's
	-- emitter (grug_ambience/data.lua). Nothing to dig, nothing to blow up,
	-- like every world node of the guild.
	local NAMES = {grinder = "Stonewright's Grinder",
		furnace = "Stonewright's Smelting Furnace"}
	for _, cell in ipairs(dofile(path .. "/machines_data.lua")) do
		engine.register_node(":" .. cell.name, {
			description = NAMES[cell.machine],
			drawtype = "nodebox",
			tiles = cell.tiles,
			use_texture_alpha = "opaque",
			paramtype = "light",
			paramtype2 = "facedir",
			sunlight_propagates = true,
			light_source = cell.light_source,
			node_box = {type = "fixed", fixed = cell.node_box},
			collision_box = {type = "fixed", fixed = cell.node_box},
			selection_box = {type = "fixed", fixed = cell.node_box},
			groups = {not_in_creative_inventory = 1},
			diggable = false,
			is_ground_content = false,
			floodable = false,
			drop = "",
			on_blast = function() end,
			sounds = default.node_sound_stone_defaults(),
		})
	end
end
