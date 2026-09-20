local blank = "grug_mobs_blank.png"

grug_mounts.WARNING_WIDTH = 48
grug_mounts.FLIGHT_CEILING = 600

-- WP44 replaces these coordinator placeholders with the measured 15 min,
-- 45 min, 2 h and 5 h income values.
grug_mounts.COORDINATOR_PLACEHOLDER_PRICES = {200, 1500, 24000, 100000}
grug_mounts.PRICES = grug_mounts.COORDINATOR_PLACEHOLDER_PRICES

grug_mounts.TIERS = {
	[1] = {id = 1, key = "apprentice", name = "Apprentice Riding",
		level = 15, mode = "land", speed = 6.4,
		item = "grug_mounts:apprentice_mount"},
	[2] = {id = 2, key = "journeyman", name = "Journeyman Riding",
		level = 30, mode = "land", speed = 8,
		item = "grug_mounts:journeyman_mount"},
	[3] = {id = 3, key = "expert", name = "Expert Riding",
		level = 45, mode = "flight", speed = 7,
		item = "grug_mounts:expert_mount"},
	[4] = {id = 4, key = "master", name = "Master Riding",
		level = 60, mode = "flight", speed = 10,
		item = "grug_mounts:master_mount"},
}

local function repeated(texture, count)
	local result = {}
	for index = 1, count do result[index] = texture end
	return result
end

local horse_animation = {
	stand = {1, 1, 25},
	move = {1, 40, 100},
}

local function horse(id, description, texture)
	return {
		id = id, description = description,
		mesh = "grug_mounts_horse.b3d",
		textures = {blank, texture, blank},
		icon = "grug_mounts_icon_" .. id .. ".png",
		visual_size = {x = 3, y = 3},
		collisionbox = {-0.7, -0.01, -0.7, 0.7, 1.59, 0.7},
		attach_y = 4.2, eye_y = 3,
		animation = horse_animation,
	}
end

grug_mounts.MODELS = {
	t1_accord = horse("t1_accord", "Accord Courser",
		"grug_mounts_horse_white.png^[multiply:#91b5ee"),
	t1_throng = horse("t1_throng", "Throng Courser",
		"grug_mounts_horse_brown.png^[multiply:#c87575"),
	human = horse("human", "Highcourt Charger",
		"grug_mounts_horse_white.png^[multiply:#ead7a0"),
	dwarf = {
		id = "dwarf", description = "Frostbarrow Ibex",
		mesh = "grug_mobs_ibex.b3d",
		textures = {"grug_mobs_ibex.png^[multiply:#d8c49d"},
		icon = "grug_mounts_icon_dwarf.png",
		visual_size = {x = 1.45, y = 1.45},
		collisionbox = {-0.58, -0.01, -0.58, 0.58, 1.45, 0.58},
		attach_y = 8.5, eye_y = 3,
		animation = {stand = {1, 100, 30}, move = {200, 300, 80}},
	},
	elf = {
		id = "elf", description = "Silverleaf Stag",
		mesh = "grug_mobs_stag.b3d", textures = {"grug_mobs_stag.png"},
		icon = "grug_mounts_icon_elf.png",
		visual_size = {x = 8, y = 8},
		collisionbox = {-0.55, -0.01, -0.55, 0.55, 1.8, 0.55},
		-- Attachment offsets inherit parent scale: 1.9 * 8 / 10 = 1.52 nodes.
		attach_y = 1.9, eye_y = 3,
		animation = {stand = {1, 59, 10}, move = {100, 119, 40}},
	},
	orc = {
		id = "orc", description = "Gor Drazhak War Boar",
		mesh = "grug_mobs_boar.b3d",
		textures = {"grug_mobs_boar.png^[multiply:#9a6047", blank},
		icon = "grug_mounts_icon_orc.png",
		visual_size = {x = 1.55, y = 1.55},
		collisionbox = {-0.7, -0.01, -0.7, 0.7, 1.34, 0.7},
		attach_y = 8.2, eye_y = 3,
		animation = {stand = {1, 1, 25}, move = {1, 40, 90}},
	},
	undead = {
		id = "undead", description = "Nhal Veyr Grave Wolf",
		mesh = "grug_mobs_wolf.b3d",
		textures = {"grug_mobs_wolf_blightfang.png^[multiply:#b3a6ca"},
		icon = "grug_mounts_icon_undead.png",
		visual_size = {x = 1.7, y = 1.7},
		collisionbox = {-0.55, -0.01, -0.55, 0.55, 1.43, 0.55},
		attach_y = 8.4, eye_y = 3,
		animation = {stand = {1, 1, 25}, move = {1, 40, 100}},
	},
	troll = {
		id = "troll", description = "Kezamba Tiger",
		mesh = "grug_mounts_tiger.b3d",
		textures = {"grug_mounts_tiger.png^[multiply:#d69a52"},
		icon = "grug_mounts_icon_troll.png",
		visual_size = {x = 1.45, y = 1.45},
		collisionbox = {-0.68, -0.01, -0.68, 0.68, 1.38, 0.68},
		attach_y = 8.2, eye_y = 3,
		animation = {stand = {1, 100, 30}, move = {100, 200, 100}},
	},
	expert_accord = {
		id = "expert_accord", description = "Accord Eagle",
		mesh = "grug_mobs_eagle.b3d",
		textures = repeated("grug_mobs_eagle.png^[multiply:#9eb9dc", 18),
		icon = "grug_mounts_icon_expert_accord.png",
		visual_size = {x = 3, y = 3},
		collisionbox = {-0.9, -0.1, -0.9, 0.9, 1.5, 0.9},
		attach_y = 6.2, eye_y = 3,
		animation = {stand = {1, 100, 60}, move = {150, 250, 100}},
	},
	master_accord = {
		id = "master_accord", description = "Steller's Sea Eagle",
		mesh = "grug_mobs_eagle.b3d",
		textures = repeated("grug_mobs_eagle.png^[multiply:#eee3b6", 18),
		icon = "grug_mounts_icon_master_accord.png",
		visual_size = {x = 4, y = 4},
		collisionbox = {-1.15, -0.1, -1.15, 1.15, 1.9, 1.15},
		attach_y = 6.4, eye_y = 3,
		animation = {stand = {1, 100, 70}, move = {150, 250, 110}},
	},
	expert_throng = {
		id = "expert_throng", description = "Throng Cave Bat",
		mesh = "grug_mobs_cave_bat.b3d",
		textures = {"grug_mobs_cave_bat.png^[multiply:#856f8e"},
		icon = "grug_mounts_icon_expert_throng.png",
		visual_size = {x = 3, y = 3},
		collisionbox = {-0.85, -0.1, -0.85, 0.85, 1.55, 0.85},
		attach_y = 6.4, eye_y = 3,
		animation = {stand = {1, 40, 70}, move = {1, 40, 100}},
	},
	master_throng = {
		id = "master_throng", description = "Giant Blood Bat",
		mesh = "grug_mobs_cave_bat.b3d",
		textures = {"grug_mobs_cave_bat.png^[multiply:#7d3549"},
		icon = "grug_mounts_icon_master_throng.png",
		visual_size = {x = 4.2, y = 4.2},
		collisionbox = {-1.15, -0.1, -1.15, 1.15, 2.05, 1.15},
		attach_y = 6.8, eye_y = 3,
		animation = {stand = {1, 40, 75}, move = {1, 40, 110}},
	},
}

-- Selection geometry is deliberately taller than collision geometry.  The
-- mount remains the physical body, while its pointable box also covers an
-- ordinary full-height player rendered above the model-specific seat.
local RIDER_RENDER_HEIGHT = 1.8
local RIDER_HALF_WIDTH = 0.6
for _, model in pairs(grug_mounts.MODELS) do
	local box = model.collisionbox
	local seat_y = model.attach_y * model.visual_size.y / 10
	model.selectionbox = {
		math.min(box[1], -RIDER_HALF_WIDTH), box[2],
		math.min(box[3], -RIDER_HALF_WIDTH),
		math.max(box[4], RIDER_HALF_WIDTH),
		math.max(box[5], seat_y + RIDER_RENDER_HEIGHT),
		math.max(box[6], RIDER_HALF_WIDTH),
	}
end

function grug_mounts.model_for(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if not tier then return nil end
	local faction = grug_factions.get_faction(player)
	if tier_id == 1 then
		return grug_mounts.MODELS["t1_" .. tostring(faction)]
	elseif tier_id == 2 then
		return grug_mounts.MODELS[grug_classes.get_race(player)]
	elseif tier_id == 3 or tier_id == 4 then
		local prefix = tier_id == 3 and "expert_" or "master_"
		return grug_mounts.MODELS[prefix .. tostring(faction)]
	end
	return nil
end

function grug_mounts.price_for_tier(tier_id)
	local price = grug_mounts.PRICES[tier_id]
	if type(price) ~= "number" or price <= 0 or price % 1 ~= 0 then
		return nil
	end
	return price
end
