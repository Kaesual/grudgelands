-- Round 75 static household and city furnishings.
--
-- All forms use authored nodeboxes or code-generated meshes and media already
-- shipped by the game. Mesh material groups give each visible component its
-- own complete UV mapping instead of stretching one node face across it.
-- They intentionally provide no inventories, formspecs, timers or interaction
-- callbacks beyond surface-restricted placement.
-- Facedir 0 presents a wall object's deliberate front toward local -Z;
-- facedir 1/2/3 rotate that front toward -X/+Z/+X respectively. Placement is
-- restricted to the surface named by `_grug_decor_mount`; it never uses 6d
-- facedir rotation.

local wood = "grug_decor_xdecor_xdecor_wood.png"
local pale_wood = "default_aspen_wood.png"
local wicker = "default_acacia_wood.png"
local ceramic = "default_clay.png"
local pottery = "default_clay_brick.png"
local paper = "default_paper.png"
local book = "default_book.png"
local stone = "default_stone.png"
local iron = "default_steel_block.png"
local ore = "default_mineral_iron.png"
local gems = "default_obsidian_glass.png^[colorize:#6ac8d8:110"
local glass = "default_glass.png^[colorize:#5d9b83:100"
local leaf = "default_leaves.png"
local herb = "grug_gathering_sunleaf_plant.png"
local rope = "grug_decor_xdecor_xdecor_rope.png"
local cloth = "grug_decor_cottages_cottages_wool.png"
local leather = "default_tree.png^[colorize:#8b5a36:90"
local fur = "default_aspen_tree.png^[colorize:#6b625d:80"
local wax = "default_clay.png^[colorize:#f1d78a:100"
local flame = "default_mese_block.png^[colorize:#ff8a24:150"
local ember = "default_coal_block.png^[colorize:#7d2418:100"
local fire_flame = "default_clay.png^[colorize:#e96525:185"
local fire_glow = "default_clay.png^[colorize:#ffd07a:150"

local red_cloth = cloth .. "^[colorize:#8d2f32:150"
local green_cloth = cloth .. "^[colorize:#355f3e:150"
local blue_cloth = cloth .. "^[colorize:#294c70:150"
local dark_cloth = cloth .. "^[colorize:#4b392d:130"

local sounds = {
	wood = default.node_sound_wood_defaults(),
	stone = default.node_sound_stone_defaults(),
	metal = default.node_sound_metal_defaults(),
	soft = default.node_sound_defaults(),
}

local groups = {
	wood = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2},
	stone = {cracky = 3, oddly_breakable_by_hand = 2},
	metal = {cracky = 2},
	soft = {snappy = 3, oddly_breakable_by_hand = 2, flammable = 3},
}

local function box(fixed)
	return {type = "fixed", fixed = fixed}
end

local function horizontal_facedir(placer)
	local direction = placer and placer:get_look_dir()
	if not direction then return 0 end
	return core.dir_to_facedir(direction, false) % 4
end

local function full_support_face(definition, dx, dy, dz)
	local node_box = definition.node_box
	if not node_box or node_box.type ~= "fixed" then
		return definition.drawtype == nil or definition.drawtype == "normal"
	end
	local fixed = node_box.fixed
	local boxes = type(fixed[1]) == "number" and {fixed} or fixed
	for _, one in ipairs(boxes) do
		-- Some shipped nodeboxes retain upstream's reversed coordinate pairs.
		-- Normalize them before testing the support face. The small top tolerance
		-- admits the two full-width table tops at y=0.48 and y=0.4375, while a
		-- stair or slab still fails either the full-width or height requirement.
		local x1, x2 = math.min(one[1], one[4]), math.max(one[1], one[4])
		local y1, y2 = math.min(one[2], one[5]), math.max(one[2], one[5])
		local z1, z2 = math.min(one[3], one[6]), math.max(one[3], one[6])
		if dy == -1 and y2 >= 0.4375 and x1 <= -0.5 and x2 >= 0.5
				and z1 <= -0.5 and z2 >= 0.5 then
			return true
		elseif dy == 1 and y1 == -0.5 and x1 <= -0.5 and x2 >= 0.5
				and z1 <= -0.5 and z2 >= 0.5 then
			return true
		elseif dx == -1 and x2 == 0.5 and y1 <= -0.5 and y2 >= 0.5
				and z1 <= -0.5 and z2 >= 0.5 then
			return true
		elseif dx == 1 and x1 == -0.5 and y1 <= -0.5 and y2 >= 0.5
				and z1 <= -0.5 and z2 >= 0.5 then
			return true
		elseif dz == -1 and z2 == 0.5 and x1 <= -0.5 and x2 >= 0.5
				and y1 <= -0.5 and y2 >= 0.5 then
			return true
		elseif dz == 1 and z1 == -0.5 and x1 <= -0.5 and x2 >= 0.5
				and y1 <= -0.5 and y2 >= 0.5 then
			return true
		end
	end
	return false
end

-- Shared by these nodes and by the coordinator's static art clones. A wall
-- node's local +Z back aligns with the clicked support; floor/table nodes stay
-- upright above it and ceiling nodes stay upright below it.
function grug_decor.place_furnishing(itemstack, placer, pointed_thing)
	local clicked = grug_core.node_rightclick(itemstack, placer, pointed_thing)
	if clicked then return clicked end
	if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
	local under, above = pointed_thing.under, pointed_thing.above
	if not under or not above then return itemstack end
	local support = core.get_node_or_nil(under)
	local support_def = support and core.registered_nodes[support.name]
	if not support_def or support_def.buildable_to or support_def.walkable == false then
		return itemstack
	end
	local definition = core.registered_nodes[itemstack:get_name()]
	local mount = definition and definition._grug_decor_mount
	local dx, dy, dz = under.x - above.x, under.y - above.y, under.z - above.z
	if not full_support_face(support_def, dx, dy, dz) then return itemstack end
	local param2
	if mount == "floor" or mount == "table" then
		if dx ~= 0 or dy ~= -1 or dz ~= 0 then return itemstack end
		param2 = horizontal_facedir(placer)
	elseif mount == "wall" then
		if dy ~= 0 or math.abs(dx) + math.abs(dz) ~= 1 then return itemstack end
		param2 = core.dir_to_facedir({x = dx, y = 0, z = dz}, false) % 4
	elseif mount == "ceiling" then
		if dx ~= 0 or dy ~= 1 or dz ~= 0 then return itemstack end
		param2 = horizontal_facedir(placer)
	else
		return itemstack
	end
	return core.item_place(itemstack, placer, pointed_thing, param2)
end

local function register(row)
	local material = row.material or "wood"
	local node_box = box(row.boxes)
	core.register_node("grug_decor:" .. row.id, {
		description = row.description,
		drawtype = row.mesh and "mesh" or "nodebox",
		mesh = row.mesh,
		tiles = row.tiles or {row.texture or wood},
		use_texture_alpha = row.alpha,
		paramtype = "light",
		paramtype2 = "facedir",
		on_place = grug_decor.place_furnishing,
		sunlight_propagates = true,
		is_ground_content = false,
		walkable = row.walkable == true,
		node_box = node_box,
		selection_box = node_box,
		collision_box = row.walkable and node_box or nil,
		light_source = row.light,
		groups = groups[material],
		sounds = sounds[material],
		_grug_decor_family = row.family,
		_grug_decor_mount = row.mount,
	})
end

local furnishings = {
	-- N06: low place settings. All tabletop shapes start at y=-0.5.
	{id = "plate_wood", description = "Wooden Plate", family = "N06", mount = "table",
		boxes = {{-0.28,-0.5,-0.28, 0.28,-0.47,0.28}, {-0.22,-0.47,-0.22, 0.22,-0.45,0.22}}},
	{id = "plate_ceramic", description = "Ceramic Plate", family = "N06", mount = "table",
		texture = ceramic, material = "stone",
		boxes = {{-0.29,-0.5,-0.29, 0.29,-0.47,0.29}, {-0.20,-0.47,-0.20, 0.20,-0.44,0.20}}},
	{id = "bowl_wood", description = "Wooden Bowl", family = "N06", mount = "table",
		boxes = {{-0.23,-0.5,-0.23, 0.23,-0.44,0.23}, {-0.18,-0.44,-0.18, 0.18,-0.34,0.18}}},
	{id = "bowl_ceramic", description = "Ceramic Bowl", family = "N06", mount = "table",
		texture = ceramic, material = "stone",
		boxes = {{-0.24,-0.5,-0.24, 0.24,-0.44,0.24}, {-0.19,-0.44,-0.19, 0.19,-0.31,0.19}}},

	-- N07: a stepped jug and a handled mug.
	{id = "jug", description = "Clay Jug", family = "N07", mount = "table",
		texture = pottery, material = "stone",
		boxes = {{-0.20,-0.5,-0.20,0.20,-0.20,0.20}, {-0.15,-0.20,-0.15,0.15,-0.08,0.15},
			{-0.08,-0.08,-0.08,0.08,0.10,0.08}, {0.08,-0.16,-0.05,0.25,0.03,0.05}}},
	{id = "mug", description = "Wooden Mug", family = "N07", mount = "table",
		boxes = {{-0.14,-0.5,-0.14,0.14,-0.23,0.14}, {0.12,-0.45,-0.08,0.25,-0.30,0.08}}},

	-- N08: serving silhouettes.
	{id = "bread_board", description = "Bread Board", family = "N08", mount = "table",
		mesh = "grug_decor_furnish_bread_board.obj", tiles = {wood, "grug_cooking_bread.png"},
		boxes = {{-0.37,-0.5,-0.26,0.37,-0.45,0.26}, {-0.25,-0.45,-0.15,-0.03,-0.32,0.15},
			{0.02,-0.45,-0.13,0.26,-0.34,0.13}}},
	{id = "meal_platter", description = "Meal Platter", family = "N08", mount = "table",
		mesh = "grug_decor_furnish_meal_platter.obj",
		tiles = {pale_wood, "grug_cooking_dish_salt_crusted_fish.png"},
		boxes = {{-0.36,-0.5,-0.25,0.36,-0.46,0.25}, {-0.23,-0.46,-0.12,0.22,-0.34,0.12},
			{-0.30,-0.43,-0.18,-0.22,-0.35,-0.10}, {0.22,-0.43,0.10,0.30,-0.35,0.18}}},

	-- N09: basket body plus distinct produce mounds.
	{id = "fruit_basket", description = "Fruit Basket", family = "N09", mount = "table",
		mesh = "grug_decor_furnish_fruit_basket.obj", tiles = {wicker, "default_apple.png"},
		boxes = {{-0.30,-0.5,-0.24,0.30,-0.42,0.24}, {-0.27,-0.42,-0.21,-0.19,-0.25,0.21},
			{0.19,-0.42,-0.21,0.27,-0.25,0.21}, {-0.19,-0.40,-0.16,0.19,-0.23,0.16}}},
	{id = "vegetable_basket", description = "Vegetable Basket", family = "N09", mount = "table",
		mesh = "grug_decor_furnish_vegetable_basket.obj", tiles = {wicker, "default_leaves.png"},
		boxes = {{-0.31,-0.5,-0.23,0.31,-0.42,0.23}, {-0.28,-0.42,-0.20,-0.20,-0.24,0.20},
			{0.20,-0.42,-0.20,0.28,-0.24,0.20}, {-0.20,-0.40,-0.15,0.20,-0.20,0.15}}},

	-- N10: closed and open sacks.
	{id = "sack_closed", description = "Closed Provision Sack", family = "N10", mount = "floor",
		texture = dark_cloth, material = "soft", walkable = true,
		boxes = {{-0.27,-0.5,-0.22,0.27,-0.12,0.22}, {-0.20,-0.12,-0.17,0.20,0.05,0.17},
			{-0.08,0.05,-0.08,0.08,0.15,0.08}}},
	{id = "sack_grain", description = "Open Grain Sack", family = "N10", mount = "floor",
		mesh = "grug_decor_furnish_sack_grain.obj", tiles = {dark_cloth, "default_dry_grass.png"},
		material = "soft", walkable = true,
		boxes = {{-0.29,-0.5,-0.24,0.29,-0.14,0.24}, {-0.25,-0.14,-0.20,0.25,0.02,0.20},
			{-0.20,0.02,-0.16,0.20,0.07,0.16}}},

	-- N11: open shallow crates with a clearly different top load.
	{id = "crate_vegetables", description = "Vegetable Crate", family = "N11", mount = "floor",
		mesh = "grug_decor_furnish_crate_vegetables.obj", tiles = {wood, leaf}, walkable = true,
		boxes = {{-0.42,-0.5,-0.34,0.42,-0.40,0.34}, {-0.42,-0.40,-0.34,-0.34,-0.16,0.34},
			{0.34,-0.40,-0.34,0.42,-0.16,0.34}, {-0.34,-0.36,-0.26,0.34,-0.18,0.26}}},
	{id = "crate_fish", description = "Fish Crate", family = "N11", mount = "floor",
		mesh = "grug_decor_furnish_crate_fish.obj",
		tiles = {wood, "grug_cooking_dish_salt_crusted_fish.png"}, walkable = true,
		boxes = {{-0.42,-0.5,-0.34,0.42,-0.40,0.34}, {-0.42,-0.40,-0.34,-0.34,-0.16,0.34},
			{0.34,-0.40,-0.34,0.42,-0.16,0.34}, {-0.31,-0.35,-0.16,0.31,-0.20,0.16}}},
	{id = "crate_meat", description = "Meat Crate", family = "N11", mount = "floor",
		mesh = "grug_decor_furnish_crate_meat.obj", tiles = {wood, "mobs_meat_raw.png"}, walkable = true,
		boxes = {{-0.42,-0.5,-0.34,0.42,-0.40,0.34}, {-0.42,-0.40,-0.34,-0.34,-0.16,0.34},
			{0.34,-0.40,-0.34,0.42,-0.16,0.34}, {-0.30,-0.36,-0.22,0.30,-0.19,0.22}}},
	{id = "crate_ore", description = "Ore Crate", family = "N11", mount = "floor",
		mesh = "grug_decor_furnish_crate_ore.obj", tiles = {wood, ore}, walkable = true,
		boxes = {{-0.42,-0.5,-0.34,0.42,-0.40,0.34}, {-0.42,-0.40,-0.34,-0.34,-0.16,0.34},
			{0.34,-0.40,-0.34,0.42,-0.16,0.34}, {-0.32,-0.37,-0.24,0.32,-0.17,0.24}}},

	-- N12: upright basket and low tray.
	{id = "wicker_basket", description = "Wicker Basket", family = "N12", mount = "floor",
		texture = wicker, walkable = true,
		boxes = {{-0.30,-0.5,-0.25,0.30,-0.42,0.25}, {-0.30,-0.42,-0.25,-0.23,-0.10,0.25},
			{0.23,-0.42,-0.25,0.30,-0.10,0.25}, {-0.23,-0.18,-0.25,0.23,-0.10,-0.18},
			{-0.23,-0.18,0.18,0.23,-0.10,0.25}, {-0.24,-0.10,-0.04,-0.18,0.22,0.04},
			{0.18,-0.10,-0.04,0.24,0.22,0.04}, {-0.18,0.16,-0.04,0.18,0.22,0.04}}},
	{id = "wicker_tray", description = "Wicker Tray", family = "N12", mount = "table",
		texture = wicker,
		boxes = {{-0.34,-0.5,-0.28,0.34,-0.46,0.28}, {-0.34,-0.46,-0.28,-0.28,-0.38,0.28},
			{0.28,-0.46,-0.28,0.34,-0.38,0.28}, {-0.28,-0.46,-0.28,0.28,-0.38,-0.22},
			{-0.28,-0.46,0.22,0.28,-0.38,0.28}}},

	-- N13-N17: reading, writing and alchemy groups.
	{id = "book_stack", description = "Stack of Books", family = "N13", mount = "table",
		texture = book, material = "soft",
		boxes = {{-0.30,-0.5,-0.22,0.24,-0.43,0.22}, {-0.24,-0.43,-0.20,0.30,-0.35,0.20},
			{-0.27,-0.35,-0.17,0.18,-0.28,0.17}}},
	{id = "book_open", description = "Open Book", family = "N14", mount = "table",
		texture = paper, material = "soft",
		boxes = {{-0.34,-0.5,-0.22,-0.02,-0.45,0.22}, {0.02,-0.5,-0.22,0.34,-0.45,0.22},
			{-0.03,-0.48,-0.23,0.03,-0.42,0.23}}},
	{id = "lectern", description = "Reading Lectern", family = "N14", mount = "floor",
		texture = pale_wood, walkable = true,
		boxes = {{-0.34,-0.5,-0.30,0.34,-0.40,0.30}, {-0.10,-0.40,-0.10,0.10,0.18,0.10},
			{-0.31,0.12,-0.20,0.31,0.20,0.20}, {-0.27,0.20,-0.12,0.27,0.29,0.18},
			{-0.31,0.18,0.16,0.31,0.34,0.24}}},
	{id = "writing_set", description = "Writing Set", family = "N15", mount = "table",
		texture = paper, material = "soft",
		boxes = {{-0.32,-0.5,-0.24,0.18,-0.47,0.24}, {0.21,-0.5,-0.10,0.34,-0.34,0.03},
			{0.08,-0.47,-0.03,0.30,-0.43,0.01}, {0.25,-0.34,-0.06,0.29,-0.10,-0.02}}},
	{id = "scroll", description = "Scroll", family = "N16", mount = "table",
		texture = paper, material = "soft",
		boxes = {{-0.31,-0.5,-0.16,0.31,-0.46,0.16}, {-0.36,-0.49,-0.20,-0.30,-0.41,0.20},
			{0.30,-0.49,-0.20,0.36,-0.41,0.20}}},
	{id = "scroll_bundle", description = "Bundle of Scrolls", family = "N16", mount = "table",
		texture = paper, material = "soft",
		boxes = {{-0.28,-0.5,-0.18,0.28,-0.42,-0.08}, {-0.24,-0.5,-0.04,0.30,-0.40,0.06},
			{-0.30,-0.5,0.08,0.22,-0.41,0.18}, {-0.04,-0.44,-0.20,0.04,-0.37,0.20}}},
	{id = "map_sheet", description = "Map Sheet", family = "N16", mount = "table",
		texture = "default_paper.png^[colorize:#b79a66:45", material = "soft",
		boxes = {{-0.42,-0.5,-0.34,0.42,-0.48,0.34}, {-0.35,-0.48,-0.27,-0.30,-0.46,0.28},
			{0.10,-0.48,-0.20,0.15,-0.46,0.23}}},
	{id = "alchemy_set", description = "Alchemy Flask Set", family = "N17", mount = "table",
		texture = glass, material = "stone", alpha = "blend",
		boxes = {{-0.30,-0.5,-0.14,-0.10,-0.28,0.06}, {-0.25,-0.28,-0.09,-0.15,-0.10,0.01},
			{-0.03,-0.5,-0.08,0.13,-0.20,0.08}, {0.02,-0.20,-0.04,0.08,0.02,0.04},
			{0.19,-0.5,-0.13,0.34,-0.34,0.02}, {0.22,-0.34,-0.10,0.31,-0.08,-0.01},
			{0.12,-0.5,0.13,0.34,-0.43,0.32}}},

	-- N18-N20: wall tools and material dishes. Wall fronts face -Z.
	{id = "herb_bundle", description = "Hanging Herb Bundle", family = "N18", mount = "wall",
		texture = herb, material = "soft", alpha = "clip",
		boxes = {{-0.04,0.20,0.43,0.04,0.43,0.48}, {-0.24,-0.25,0.42,-0.03,0.21,0.48},
			{0.03,-0.32,0.42,0.24,0.21,0.48}, {-0.27,-0.05,0.42,0.27,0.03,0.48}}},
	{id = "tool_board", description = "Tool Board", family = "N19", mount = "wall",
		mesh = "grug_decor_furnish_tool_board.obj", tiles = {wood, iron},
		boxes = {{-0.42,-0.35,0.43,0.42,0.35,0.49}, {-0.28,-0.24,0.36,-0.20,0.24,0.43},
			{-0.04,-0.17,0.36,0.04,0.27,0.43}, {0.17,-0.25,0.36,0.29,0.12,0.43},
			{0.12,0.12,0.36,0.34,0.20,0.43}}},
	{id = "material_ore", description = "Ore Material Dish", family = "N20", mount = "table",
		mesh = "grug_decor_furnish_material_ore.obj", tiles = {stone, ore}, material = "stone",
		boxes = {{-0.28,-0.5,-0.24,0.28,-0.45,0.24}, {-0.22,-0.45,-0.18,0.22,-0.35,0.18},
			{-0.17,-0.35,-0.12,0.00,-0.27,0.04}, {0.03,-0.35,-0.06,0.18,-0.25,0.12}}},
	{id = "material_metal", description = "Metal Material Dish", family = "N20", mount = "table",
		mesh = "grug_decor_furnish_material_metal.obj", tiles = {stone, iron}, material = "metal",
		boxes = {{-0.28,-0.5,-0.24,0.28,-0.45,0.24}, {-0.22,-0.45,-0.18,0.22,-0.35,0.18},
			{-0.18,-0.35,-0.10,0.18,-0.29,-0.02}, {-0.13,-0.35,0.04,0.15,-0.27,0.12}}},
	{id = "material_gems", description = "Gem Material Dish", family = "N20", mount = "table",
		mesh = "grug_decor_furnish_material_gems.obj", tiles = {stone, gems}, material = "stone",
		boxes = {{-0.28,-0.5,-0.24,0.28,-0.45,0.24}, {-0.22,-0.45,-0.18,0.22,-0.35,0.18},
			{-0.16,-0.35,-0.10,-0.04,-0.23,0.02}, {0.03,-0.35,-0.06,0.16,-0.20,0.07}}},

	-- N21-N24: textiles, hides, rope and wax goods.
	{id = "cloth_rolls", description = "Cloth Rolls", family = "N21", mount = "table",
		texture = blue_cloth, material = "soft",
		boxes = {{-0.31,-0.5,-0.18,0.31,-0.35,-0.04}, {-0.27,-0.5,0.03,0.35,-0.31,0.17},
			{-0.35,-0.49,-0.03,-0.29,-0.36,0.01}, {0.29,-0.49,-0.03,0.35,-0.36,0.01}}},
	{id = "yarn", description = "Yarn Spools", family = "N21", mount = "table",
		texture = red_cloth, material = "soft",
		boxes = {{-0.25,-0.5,-0.14,-0.09,-0.25,0.02}, {-0.29,-0.48,-0.17,-0.05,-0.43,0.05},
			{0.05,-0.5,-0.03,0.24,-0.30,0.16}, {0.01,-0.48,-0.07,0.28,-0.43,0.20}}},
	{id = "leather_bundle", description = "Leather Bundle", family = "N22", mount = "table",
		texture = leather, material = "soft",
		boxes = {{-0.34,-0.5,-0.24,0.30,-0.43,0.24}, {-0.27,-0.43,-0.20,0.35,-0.35,0.20},
			{-0.04,-0.45,-0.25,0.04,-0.32,0.25}}},
	{id = "fur_bundle", description = "Fur Bundle", family = "N22", mount = "table",
		texture = fur, material = "soft",
		boxes = {{-0.36,-0.5,-0.24,0.34,-0.41,0.24}, {-0.29,-0.41,-0.20,0.28,-0.30,0.20},
			{-0.18,-0.30,-0.16,0.22,-0.24,0.16}}},
	{id = "rope_coil", description = "Rope Coil", family = "N23", mount = "floor",
		texture = rope, material = "soft",
		boxes = {{-0.34,-0.5,-0.30,0.34,-0.44,0.30}, {-0.27,-0.44,-0.23,0.27,-0.37,0.23},
			{-0.18,-0.37,-0.15,0.18,-0.30,0.15}, {-0.07,-0.32,-0.07,0.07,-0.25,0.07}}},
	{id = "oar", description = "Wall Oar", family = "N23", mount = "wall",
		texture = pale_wood,
		boxes = {{-0.05,-0.42,0.43,0.05,0.31,0.49}, {-0.15,0.25,0.43,0.15,0.46,0.49},
			{-0.10,-0.46,0.43,0.10,-0.36,0.49}}},
	{id = "candle_bundle", description = "Bundle of Candles", family = "N24", mount = "table",
		texture = wax, material = "soft",
		boxes = {{-0.25,-0.5,-0.12,-0.13,-0.19,0.00}, {-0.06,-0.5,-0.06,0.06,-0.12,0.06},
			{0.13,-0.5,-0.01,0.25,-0.24,0.11}, {-0.28,-0.33,-0.16,0.28,-0.26,0.15}}},
	{id = "wax_bowl", description = "Bowl of Wax", family = "N24", mount = "table",
		texture = wax, material = "soft",
		boxes = {{-0.25,-0.5,-0.22,0.25,-0.45,0.22}, {-0.20,-0.45,-0.17,0.20,-0.34,0.17},
			{-0.14,-0.34,-0.11,0.14,-0.30,0.11}}},

	-- N25-N28: static light sources. There are no timers or particles.
	{id = "candle_group", description = "Lit Candle Group", family = "N25", mount = "table",
		mesh = "grug_decor_furnish_candle_group.obj", tiles = {wax, flame}, material = "soft", light = 9,
		boxes = {{-0.24,-0.5,-0.11,-0.12,-0.18,0.01}, {-0.04,-0.5,-0.05,0.08,-0.06,0.07},
			{0.15,-0.5,-0.01,0.27,-0.25,0.11}, {-0.22,-0.18,-0.09,-0.14,-0.10,-0.01},
			{-0.02,-0.06,-0.03,0.06,0.02,0.05}, {0.17,-0.25,0.01,0.25,-0.17,0.09}}},
	{id = "sconce_iron", description = "Iron Wall Sconce", family = "N26", mount = "wall",
		mesh = "grug_decor_furnish_sconce_iron.obj", tiles = {iron, wax, flame}, material = "metal", light = 11,
		boxes = {{-0.18,-0.15,0.43,0.18,0.25,0.49}, {-0.05,-0.08,0.18,0.05,0.02,0.45},
			{-0.13,-0.10,0.10,0.13,-0.04,0.24}, {-0.06,-0.04,0.10,0.06,0.24,0.20},
			{-0.04,0.24,0.12,0.04,0.34,0.18}}},
	{id = "sconce_wood", description = "Carved Wooden Sconce", family = "N26", mount = "wall",
		mesh = "grug_decor_furnish_sconce_wood.obj", tiles = {pale_wood, wax, flame}, light = 10,
		boxes = {{-0.16,-0.20,0.43,0.16,0.23,0.49}, {-0.07,-0.12,0.15,0.07,-0.02,0.45},
			{-0.15,-0.13,0.10,0.15,-0.05,0.21}, {-0.05,-0.05,0.11,0.05,0.20,0.19},
			{-0.035,0.20,0.13,0.035,0.30,0.18}}},
	{id = "chandelier", description = "Ring Chandelier", family = "N27", mount = "ceiling",
		mesh = "grug_decor_furnish_chandelier.obj", tiles = {iron, wax, flame}, material = "metal", light = 12,
		boxes = {{-0.04,0.25,-0.04,0.04,0.50,0.04}, {-0.35,0.05,-0.35,0.35,0.12,-0.28},
			{-0.35,0.05,0.28,0.35,0.12,0.35}, {-0.35,0.05,-0.28,-0.28,0.12,0.28},
			{0.28,0.05,-0.28,0.35,0.12,0.28}, {-0.31,0.10,-0.31,-0.27,0.31,-0.27},
			{0.27,0.10,-0.31,0.31,0.31,-0.27}, {-0.31,0.10,0.27,-0.27,0.31,0.31},
			{0.27,0.10,0.27,0.31,0.31,0.31}, {-0.305,0.31,-0.305,-0.275,0.39,-0.275},
			{0.275,0.31,-0.305,0.305,0.39,-0.275}, {-0.305,0.31,0.275,-0.275,0.39,0.305},
			{0.275,0.31,0.275,0.305,0.39,0.305}}},
	{id = "fire_basket", description = "Fire Basket", family = "N28", mount = "floor",
		mesh = "grug_decor_furnish_fire_basket.obj",
		tiles = {iron, ember, fire_flame, fire_glow}, material = "metal",
		walkable = true, light = 13,
		boxes = {{-0.31,-0.5,-0.31,0.31,-0.43,0.31}, {-0.28,-0.43,-0.28,-0.21,-0.12,0.28},
			{0.21,-0.43,-0.28,0.28,-0.12,0.28}, {-0.21,-0.43,-0.28,0.21,-0.12,-0.21},
			{-0.21,-0.43,0.21,0.21,-0.12,0.28},
			{-0.17,-0.43,-0.17,0.17,-0.34,0.17},
			{-0.11,-0.34,-0.08,-0.01,-0.13,0.03}, {-0.08,-0.13,-0.05,-0.03,0.08,0.00},
			{0.01,-0.34,-0.05,0.12,-0.19,0.07}, {0.04,-0.19,-0.02,0.09,-0.08,0.04},
			{-0.04,-0.34,0.06,0.05,-0.23,0.14}}},
	{id = "hearth", description = "Stone Hearth", family = "N28", mount = "floor",
		mesh = "grug_decor_furnish_hearth.obj",
		tiles = {stone, ember, fire_flame, fire_glow}, material = "stone",
		walkable = true, light = 12,
		boxes = {{-0.48,-0.5,-0.42,0.48,-0.39,0.48}, {-0.48,-0.39,0.27,-0.34,0.35,0.48},
			{0.34,-0.39,0.27,0.48,0.35,0.48}, {-0.48,0.35,0.27,0.48,0.48,0.48},
			{-0.33,-0.39,0.38,0.33,-0.28,0.48},
			{-0.23,-0.39,0.18,0.23,-0.32,0.38},
			{-0.13,-0.32,0.21,-0.03,-0.11,0.30}, {-0.10,-0.11,0.23,-0.06,0.10,0.28},
			{0.02,-0.32,0.22,0.13,-0.17,0.32}, {0.05,-0.17,0.24,0.10,0.03,0.29},
			{-0.04,-0.32,0.30,0.05,-0.20,0.38}}},

	-- N29: one-node rugs and runners, only 3/100 node thick.
	{id = "rug_red", description = "Red Rug", family = "N29", mount = "floor",
		mesh = "grug_decor_furnish_rug_red.obj", tiles = {red_cloth, dark_cloth},
		material = "soft", boxes = {-0.47,-0.5,-0.47,0.47,-0.47,0.47}},
	{id = "rug_green", description = "Green Rug", family = "N29", mount = "floor",
		mesh = "grug_decor_furnish_rug_green.obj", tiles = {green_cloth, dark_cloth},
		material = "soft", boxes = {-0.47,-0.5,-0.47,0.47,-0.47,0.47}},
	{id = "rug_blue", description = "Blue Rug", family = "N29", mount = "floor",
		mesh = "grug_decor_furnish_rug_blue.obj", tiles = {blue_cloth, dark_cloth},
		material = "soft", boxes = {-0.47,-0.5,-0.47,0.47,-0.47,0.47}},
	{id = "runner_red", description = "Red Runner", family = "N29", mount = "floor",
		mesh = "grug_decor_furnish_runner_red.obj", tiles = {red_cloth, dark_cloth},
		material = "soft", boxes = {-0.24,-0.5,-0.49,0.24,-0.47,0.49}},
	{id = "runner_blue", description = "Blue Runner", family = "N29", mount = "floor",
		mesh = "grug_decor_furnish_runner_blue.obj", tiles = {blue_cloth, dark_cloth},
		material = "soft", boxes = {-0.24,-0.5,-0.49,0.24,-0.47,0.49}},

	-- N30: wall shelf, empty and sparingly filled.
	{id = "wall_shelf", description = "Wall Shelf", family = "N30", mount = "wall",
		boxes = {{-0.43,-0.18,0.08,0.43,-0.11,0.48}, {-0.43,-0.50,0.42,-0.36,-0.11,0.49},
			{0.36,-0.50,0.42,0.43,-0.11,0.49}}},
	{id = "wall_shelf_filled", description = "Filled Wall Shelf", family = "N30", mount = "wall",
		mesh = "grug_decor_furnish_wall_shelf_filled.obj", tiles = {wood, book},
		boxes = {{-0.43,-0.18,0.08,0.43,-0.11,0.48}, {-0.43,-0.50,0.42,-0.36,-0.11,0.49},
			{0.36,-0.50,0.42,0.43,-0.11,0.49}, {-0.29,-0.11,0.27,-0.18,0.12,0.44},
			{-0.15,-0.11,0.27,-0.03,0.17,0.44}, {0.11,-0.11,0.25,0.29,-0.02,0.43}}},

	-- N31: floor planter and ceiling-hung plant.
	{id = "planter", description = "Green Planter", family = "N31", mount = "floor",
		mesh = "grug_decor_furnish_planter.obj", tiles = {pottery, leaf}, material = "stone",
		walkable = true, alpha = "clip",
		boxes = {{-0.31,-0.5,-0.31,0.31,-0.39,0.31}, {-0.27,-0.39,-0.27,0.27,-0.13,0.27},
			{-0.05,-0.13,-0.05,0.05,0.32,0.05}, {-0.28,0.02,-0.06,0.28,0.10,0.06},
			{-0.07,-0.02,-0.27,0.07,0.09,0.27}, {-0.20,0.12,-0.05,0.20,0.20,0.05}}},
	{id = "hanging_plant", description = "Hanging Plant", family = "N31", mount = "ceiling",
		mesh = "grug_decor_furnish_hanging_plant.obj", tiles = {wicker, leaf}, material = "soft", alpha = "clip",
		boxes = {{-0.03,0.27,-0.03,0.03,0.50,0.03}, {-0.25,-0.04,-0.25,0.25,0.04,0.25},
			{-0.20,-0.18,-0.20,0.20,-0.04,0.20}, {-0.04,-0.43,-0.04,0.04,-0.16,0.04},
			{-0.23,-0.34,-0.03,0.23,-0.27,0.03}, {-0.03,-0.30,-0.22,0.03,-0.23,0.22}}},

	-- N32: actual shipped hart/boar heraldry on the deliberate front face.
	{id = "tapestry_accord", description = "The Accord Heraldic Tapestry", family = "N32", mount = "wall",
		mesh = "grug_decor_furnish_tapestry_accord.obj",
		tiles = {blue_cloth, "grug_mapgen_faction_banner_accord.png"}, material = "soft", alpha = "clip",
		boxes = {{-0.21,-0.42,0.46,0.21,0.42,0.49}, {-0.44,0.38,0.43,0.44,0.47,0.50}}},
	{id = "tapestry_throng", description = "The Throng Heraldic Tapestry", family = "N32", mount = "wall",
		mesh = "grug_decor_furnish_tapestry_throng.obj",
		tiles = {red_cloth, "grug_mapgen_faction_banner_throng.png"}, material = "soft", alpha = "clip",
		boxes = {{-0.21,-0.42,0.46,0.21,0.42,0.49}, {-0.44,0.38,0.43,0.44,0.47,0.50}}},
}

for _, row in ipairs(furnishings) do
	register(row)
end

-- Static silhouettes for city armouries. These are source props for city_*
-- no-drop clones and deliberately have no catalogue rows or display behavior.
register({
	id = "display_armor",
	description = "Static Armor Display",
	family = "N02",
	mount = "floor",
	material = "metal",
	mesh = "grug_decor_furnish_display_armor.obj",
	tiles = {wood, iron},
	walkable = true,
	boxes = {
		{-0.32,-0.5,-0.25,0.32,-0.42,0.25},
		{-0.07,-0.42,-0.07,0.07,0.16,0.07},
		{-0.29,-0.12,-0.11,0.29,0.21,0.11},
		{-0.23,0.15,-0.13,0.23,0.38,0.13},
		{-0.17,0.38,-0.14,0.17,0.50,0.14},
	},
})

register({
	id = "display_weapon",
	description = "Static Weapon Display",
	family = "N05",
	mount = "floor",
	material = "metal",
	mesh = "grug_decor_furnish_display_weapon.obj",
	tiles = {wood, iron},
	walkable = true,
	boxes = {
		{-0.36,-0.5,-0.25,0.36,-0.42,0.25},
		{-0.30,-0.42,0.17,-0.22,0.35,0.25},
		{0.22,-0.42,0.17,0.30,0.35,0.25},
		{-0.30,0.26,0.17,0.30,0.35,0.25},
		{-0.34,-0.03,0.10,0.34,0.04,0.17},
		{-0.04,-0.34,0.07,0.04,0.40,0.14},
		{-0.18,-0.01,0.04,0.18,0.08,0.17},
	},
})
