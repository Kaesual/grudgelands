-- Shared current crop appearance; no registrations or gameplay dependencies.
-- A fresh fragment per call prevents FARM and wild-node definitions sharing tables.
return function(key, stage, sounds)
 assert(type(key) == "string" and stage % 1 == 0 and stage >= 1 and stage <= 4)
	local is_salt = key == "salt_crust"
	local tile = "grug_farming_" .. key .. "_" .. stage .. ".png"
	local tiles = {tile}
	local drawtype = "plantlike"
	local visual_scale = 0.55 + stage * 0.15
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
 return {
  drawtype = drawtype, tiles = tiles, inventory_image = tile, wield_image = tile,
  visual_scale = visual_scale, node_box = node_box, paramtype = "light",
  sunlight_propagates = true, walkable = false, buildable_to = true,
  is_ground_content = false, floodable = true,
  selection_box = {type = "fixed", fixed = {-0.35, -0.5, -0.35,
   0.35, -0.3 + stage * 0.16, 0.35}}, sounds = sounds,
 }
end
