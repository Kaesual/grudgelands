-- Shared current crop appearance; no registrations or gameplay dependencies.
-- A fresh fragment per call prevents FARM and wild-node definitions sharing tables.
local SHAPES = {
	wild_grain = "grain", carrot = "root", cassava = "tall_bush",
	wild_onion = "root", fire_pepper = "bush", pumpkin = "ground_fruit",
	blightberry = "bush", sunberry = "bush", jungle_berry = "wide_bush",
	frost_melon = "ground_fruit", sugar_cane = "cane",
	bamboo_shoot = "bamboo", cave_cap = "mushroom", salt_crust = "salt",
	ember_moss = "mat", potato = "root", corn = "corn",
}

local BOUNDS = {
	grain = {{.22,.18},{.28,.36},{.34,.60},{.40,.86}},
	root = {{.18,.10},{.25,.22},{.32,.36},{.38,.50}},
	tall_bush = {{.22,.22},{.30,.43},{.38,.68},{.46,.94}},
	bush = {{.24,.18},{.34,.36},{.42,.58},{.48,.78}},
	wide_bush = {{.28,.16},{.38,.34},{.48,.55},{.50,.72}},
	ground_fruit = {{.20,.10},{.32,.20},{.43,.34},{.49,.48}},
	cane = {{.12,.30},{.14,.48},{.16,.68},{.18,.88}},
	bamboo = {{.14,.24},{.18,.42},{.22,.68},{.28,.92}},
	mushroom = {{.18,.10},{.28,.20},{.38,.34},{.46,.50}},
	mat = {{.25,.04},{.34,.09},{.43,.15},{.49,.22}},
	corn = {{.16,.25},{.22,.52},{.29,.76},{.36,.96}},
}

return function(key, stage, sounds, context)
 assert(type(key) == "string" and stage % 1 == 0 and stage >= 1 and stage <= 4)
	local shape = SHAPES[key]
	assert(shape, "grug_nodes: unknown crop visual " .. key)
	local is_salt = shape == "salt"
	local segment = type(context) == "table" and context.segment or nil
	local mode = type(context) == "table" and context.mode or context
	local tile = "grug_farming_" .. key .. "_" .. stage ..
		(key == "corn" and segment and stage >= 3 and
			("_segment_" .. segment) or "") .. ".png"
	local tiles = {tile}
	local drawtype = "plantlike"
	local visual_scale = mode == "wild" and 1.15 or 1
	local node_box
	if is_salt then
		drawtype = "nodebox"
		visual_scale = 1
		tiles = {{name = tile, animation = {type = "vertical_frames",
		aspect_w = 16, aspect_h = 16, length = 2}},
		"grug_farming_salt_crust_bottom.png",
		"grug_farming_salt_crust_" .. stage .. "_side.png"}
		local boxes = {
		{{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5}},
		{{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5}},
		{{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5},
			{-0.0625, -0.5, -0.0625, 0.0625, -0.25, 0.0625}},
		{{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5},
			{-0.1875, -0.375, -0.1875, 0.1875, -0.25, 0.1875},
			{-0.0625, -0.25, -0.0625, 0.0625, -0.125, 0.0625}},
		}
		node_box = {type = "fixed", fixed = boxes[stage]}
	end
	local bounds = BOUNDS[shape] and BOUNDS[shape][stage]
	local selection = bounds and {-bounds[1], -0.5, -bounds[1], bounds[1],
		-0.5 + bounds[2], bounds[1]} or {-0.35, -0.5, -0.35, 0.35, 0.34, 0.35}
	 return {
  drawtype = drawtype, tiles = tiles, inventory_image = tile, wield_image = tile,
  visual_scale = visual_scale, node_box = node_box, paramtype = "light",
  sunlight_propagates = true, walkable = false, buildable_to = true,
  is_ground_content = false, floodable = true,
	  selection_box = {type = "fixed", fixed = selection}, sounds = sounds,
	 }
end
