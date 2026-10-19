-- The land kit's props (Round 51 lane LK; land plan rulings 7-9, 12-14):
-- one node per prop of ARTL's prop set, from props_data.lua (written by
-- tools/r51_lk/gen_props.py from tools/r51_land/props), plus the stone
-- cairn of the trees' branch and twig shapes (ruling 13, variant B).
--
-- The world generator places them (wp40/kit_templates.lua) and the towns'
-- graveyards and bone finds use them (wp13/dressing.lua). Nobody needs
-- them as items: every block drops an ordinary default block (ruling 7:
-- cobblestone, stone, silver sandstone, wood, a stick), the bone pieces
-- drop nothing (as the bone pile always did), and none is in the creative
-- inventory. `grug_nodes:bone_pile` keeps its name as the set's scattered
-- long bones (ruling 9), so the town kits that name it keep working.

local S16 = 1 / 16
local data = dofile(core.get_modpath("grug_nodes") .. "/props_data.lua")

-- What a prop is made of, by what it drops: a bone piece (nothing), wood
-- (driftwood: wood or a stick) or stone (every other default block).
local function material(drop)
	if drop == "" then return "bone" end
	if drop == "default:wood" or drop == "default:stick" then return "wood" end
	return "stone"
end

for _, row in ipairs(data) do
	local boxes = {}
	for index, box in ipairs(row.boxes) do
		boxes[index] = {box[1] * S16, box[2] * S16, box[3] * S16,
			box[4] * S16, box[5] * S16, box[6] * S16}
	end
	local kind = material(row.drop)
	local def = {
		description = row.name,
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = boxes},
		tiles = row.tiles,
		use_texture_alpha = row.alpha and "clip" or "opaque",
		paramtype = "light",
		paramtype2 = row.rotate and "facedir" or nil,
		sunlight_propagates = true,
		is_ground_content = false,
		drop = row.drop,
	}
	if kind == "bone" then
		-- Low finds on the ground, like the bone pile before them: walked
		-- through, replaced by anything built there, washed away by water.
		def.walkable = false
		def.buildable_to = true
		def.floodable = true
		def.groups = {snappy = 3, attached_node = 1, not_in_creative_inventory = 1}
		def.sounds = default.node_sound_gravel_defaults()
	elseif kind == "wood" then
		def.groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2,
			not_in_creative_inventory = 1}
		def.sounds = default.node_sound_wood_defaults()
	else
		def.groups = {cracky = 3, not_in_creative_inventory = 1}
		def.sounds = default.node_sound_stone_defaults()
	end
	core.register_node(row.node, def)
end

-- Cairn, variant B (ruling 13): the trees' base, branch and twig shapes
-- (grug_trees/shapes.lua, Round 47 lane TA) in stone, stacked base,
-- branch, twig. They join each other, and the base and the twig the ground
-- below them; every piece drops cobblestone.
local function connected(h, reach)
	local function box(x1, y1, z1, x2, y2, z2)
		return {x1 * S16, y1 * S16, z1 * S16, x2 * S16, y2 * S16, z2 * S16}
	end
	return {
		type = "connected",
		fixed = box(-h, -h, -h, h, h, h),
		connect_top = box(-h, h, -h, h, 8, h),
		connect_bottom = box(-h, -8, -h, h, -h, h),
		connect_front = box(-h, -h, -reach, h, h, -h),
		connect_back = box(-h, -h, h, h, h, reach),
		connect_left = box(-reach, -h, -h, -h, h, h),
		connect_right = box(h, -h, -h, reach, h, h),
	}
end
local CAIRN = {"grug_nodes:cairn_base", "grug_nodes:cairn_branch", "grug_nodes:cairn_twig"}
local CAIRN_GROUND = {"default:stone", "default:gravel", "default:snowblock", "default:ice",
	"group:soil", "group:sand"}
for _, shape in ipairs({{"base", 6, 16, "Cairn Stone, Base"}, {"branch", 5, 8, "Cairn Stone"},
		{"twig", 3, 8, "Cairn Stone, Top"}}) do
	local connects = table.copy(CAIRN)
	if shape[1] ~= "branch" then
		for _, ground in ipairs(CAIRN_GROUND) do connects[#connects + 1] = ground end
	end
	core.register_node("grug_nodes:cairn_" .. shape[1], {
		description = shape[4],
		drawtype = "nodebox",
		node_box = connected(shape[2], shape[3]),
		connects_to = connects,
		tiles = {"default_stone.png"},
		paramtype = "light",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {cracky = 3, not_in_creative_inventory = 1},
		sounds = default.node_sound_stone_defaults(),
		drop = "default:cobble",
	})
end
