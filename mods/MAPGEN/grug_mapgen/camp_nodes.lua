-- Registered art pieces for the Round 63 mining camps. Pure registration:
-- camp placement and rotation belong to the map generator.
return function(engine, default, directory)
	local hidden = {not_in_creative_inventory = 1}
	local fixed = {
		diggable = false,
		is_ground_content = false,
		drop = "",
		on_blast = function() end,
	}
	local function finish(def)
		for key, value in pairs(fixed) do def[key] = value end
		def.groups = hidden
		return def
	end
	local function mesh(name, description, model, tiles, box, walkable, sounds)
		engine.register_node(name, finish({
			description = description,
			drawtype = "mesh",
			mesh = model,
			tiles = tiles,
			paramtype = "light",
			paramtype2 = "facedir",
			use_texture_alpha = "clip",
			walkable = walkable,
			selection_box = {type = "fixed", fixed = box},
			collision_box = {type = "fixed", fixed = box},
			sounds = sounds,
		}))
	end
	mesh("grug_mapgen:camp_canvas", "Camp Canvas", "grug_mapgen_camp_canvas.b3d",
		{"grug_mapgen_camp_canvas.png"}, {-0.5,-0.5,-0.5,0.5,0.5,0.5}, true,
		default.node_sound_leaves_defaults())
	for _, faction in ipairs({"accord", "throng"}) do
		mesh("grug_mapgen:camp_trim_" .. faction, "Camp Canvas Trim",
			"grug_mapgen_camp_canvas.b3d", {"grug_mapgen_camp_trim_" .. faction .. ".png"},
			{-0.5,-0.5,-0.5,0.5,0.5,0.5}, true, default.node_sound_leaves_defaults())
	end
	engine.register_node("grug_mapgen:camp_ridge", finish({
		description = "Camp Ridge",
		drawtype = "nodebox",
		tiles = {"grug_mapgen_camp_ridge.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		node_box = {type = "fixed", fixed = {-0.5,-0.5,-0.5,0.5,-0.38,0.5}},
		selection_box = {type = "fixed", fixed = {-0.5,-0.5,-0.5,0.5,-0.38,0.5}},
		sounds = default.node_sound_wood_defaults(),
	}))
	local palettes = dofile((directory or engine.get_modpath("grug_mapgen")) .. "/wp13/palette.lua")
	for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
		local palette = palettes.races[race]
		local material = palette.floor
		local material_def = assert(engine.registered_nodes[material],
			"camp wall material is not registered: " .. material)
		engine.register_node("grug_mapgen:camp_stockade_" .. race, finish({
			description = "Camp Stockade Panel",
			drawtype = "nodebox", tiles = material_def.tiles,
			paramtype = "light", paramtype2 = "facedir",
			node_box = {type = "fixed", fixed = {{-.5,-.5,-.18,.5,.5,.18},
				{-.5,-.42,-.28,.5,-.25,.28},{-.5,.25,-.28,.5,.42,.28}}},
			selection_box = {type = "fixed", fixed = {-0.5,-0.5,-0.28,0.5,0.5,0.28}},
			sounds = default.node_sound_wood_defaults(),
		}))
		engine.register_node("grug_mapgen:camp_wall_cap_" .. race, finish({
			description = "Camp Wall Cap",
			drawtype = "nodebox", tiles = material_def.tiles,
			paramtype = "light", paramtype2 = "facedir",
			node_box = {type = "fixed", fixed = {-.5,-.5,-.35,.5,-.28,.35}},
			selection_box = {type = "fixed", fixed = {-.5,-.5,-.35,.5,-.28,.35}},
			sounds = default.node_sound_wood_defaults(),
		}))
	end
	for _, faction in ipairs({"accord", "throng"}) do
		mesh("grug_mapgen:faction_banner_" .. faction, "Faction Banner",
			"grug_mapgen_faction_banner.b3d",
			{"grug_mapgen_faction_banner_" .. faction .. ".png", "default_wood.png",
				"default_steel_block.png^[colorize:#34404a:75"},
			{-0.65,-1.5,-0.61,0.65,0.72,0.1}, false, default.node_sound_leaves_defaults())
	end
end
