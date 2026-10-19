-- Sharks (Round 51, sea plan rulings S11 to S14; biomes_mobs.md "Round 51
-- water families"): one shark, two fixed-level world slots.
--
--   Bay Shark      level 30, normal: the deep middle of the four bays, which
--                  may be deadly for new players (S12).
--   Abyssal Shark  level 70, elite: the open sea next to the Kraken, a seldom
--                  spawn (S13); 1.8 x the Bay Shark's size, which the elite
--                  x1.4 (levels.lua) makes about 2.5 x.
--
-- Unlike the Kraken, a deterrent that pays nothing, both are content: normal
-- XP for their level and tier, fish loot (S14). Both are PURE SWIMMERS
-- (swimmer.lua) with the ordinary leash, so a shark acquires no player out of
-- the water and off a boat, and a target that leaves the water resets it
-- (S11, aggro.lua swimmer_reset). `_grug_fixed_level`: one name, one level
-- everywhere (sea plan §5 item 3, world slots in data/names.json; the water
-- authority in spawn_policy.lua). Each spawns from its own water row below
-- (Round 51 MOBS M2), with its band as the row's spawn check.
--
-- Port of animalworld's shark (MIT code and media, LICENSE-media.md §3): its
-- model and texture; the behaviour is ours. No sounds until the user picks
-- them (Round 51 plan §5).

-- The water bands of the two rows (grug_zones.water_query_at): the Bay
-- Shark in the deep middle of a bay (S12), BAY_MIDDLE nodes or more from dry
-- land and BAY_DEPTH or more deep; the Abyssal Shark in the open sea (S13).
local BAY_MIDDLE = 40
local BAY_DEPTH = 16

local function in_bay_middle(pos)
	local class, _, _, distance, depth = grug_zones.water_query_at(pos.x, pos.z)
	return class == "bay" and (distance or 0) >= BAY_MIDDLE and (depth or 0) >= BAY_DEPTH
end

local function in_open_sea(pos)
	return grug_zones.water_query_at(pos.x, pos.z) == "open_sea"
end
grug_mobs.shark_bands = {bay_middle = in_bay_middle, open_sea = in_open_sea,
	BAY_MIDDLE = BAY_MIDDLE, BAY_DEPTH = BAY_DEPTH}

-- The shared definition; `fields` are the slot's own (its fixed level and
-- tier first, as tools/r38_names/inventory.py reads them from the call),
-- `size` scales the model and both boxes.
local function shark_def(description, fields, size)
	local def = {
		description = description,
		_grug_voice = false,
		clock = "any",
		type = "monster",
		-- HP/damage/XP/armor: engine-owned (levels.lua) from the fixed level.
		reach = 3,
		attack_type = "dogfight",
		attack_players = true,
		group_attack = false,
		pathfinding = 1,

		-- Swims (swimmer.lua): fly + a single fly_in node, no climbing.
		fly = true,
		fly_in = "default:water_source",
		_grug_swimmer = true,
		stepheight = 0,
		floats = true,
		jump = false,
		fear_height = 0,
		walk_velocity = 1.5,
		run_velocity = 4,
		view_range = 12,

		visual = "mesh",
		mesh = "grug_mobs_shark.b3d",
		-- grug_mobs_shark.b3d is 13 meshes = 13 material slots on one PNG.
		textures = {grug_mobs.atlas_textures("grug_mobs_shark.png", 13)},
		-- Mesh scale rule (boar.lua): 1.6 x 3.5 x 1.25 nodes at size 1, as
		-- upstream. The box is the body; nose and tail stick out of it.
		visual_size = {x = size, y = size},
		collisionbox = {-0.7 * size, -0.01 * size, -0.7 * size,
			0.7 * size, 1.2 * size, 0.7 * size},
		-- Rotated selection box = measured mesh bounds (tools/r28_a3).
		selectionbox = {-0.85 * size, 0, -2.15 * size,
			0.9 * size, 1.25 * size, 1.4 * size, rotate = true},
		makes_footstep_sound = false,

		-- Keys 1..200 (LICENSE-media.md §8): the swim loop 1-100 (upstream's
		-- one-frame stand is a frozen fish; it swims slowly instead), the
		-- bite 100-200.
		animation = {
			speed_normal = 60,
			stand_start = 1, stand_end = 100, stand_speed = 30,
			walk_start = 1, walk_end = 100,
			run_start = 1, run_end = 100, run_speed = 100,
			fly_start = 1, fly_end = 100,
			punch_start = 100, punch_end = 200, punch_speed = 100,
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
	for key, value in pairs(fields) do
		def[key] = value
	end
	return def
end

-- Fish of the level's band (grug_fishing's band fish, catch.lua): band 3
-- for L30. Static drops: a fixed-level mob has one band.
grug_mobs.register_mob("grug_mobs:bay_shark", shark_def("Bay Shark", {
	_grug_fixed_level = 30,
	_grug_tier = "normal",
	_grug_spawn_check = in_bay_middle,
	drops = {
		{name = "grug_fishing:mire_carp", chance = 1, min = 1, max = 2},
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},
}, 1))

-- Band 6 for L70; an elite's catch is three times a normal's (the Reef
-- Lurker's rule, shore_crab.lua). Oversized: knock-back off (false, not 0:
-- mobs_redo only tests truthiness, kraken.lua).
grug_mobs.register_mob("grug_mobs:abyssal_shark", shark_def("Abyssal Shark", {
	_grug_fixed_level = 70,
	_grug_tier = "elite",
	_grug_spawn_check = in_open_sea,
	knock_back = false,
	reach = 4,
	run_velocity = 5,
	view_range = 16,
	drops = {
		{name = "grug_fishing:storm_tuna", chance = 1, min = 3, max = 6},
		{name = "mobs:meat_raw", chance = 1, min = 3, max = 3},
	},
}, 1.8))

-- The rows (the merged water ABM, spawn_abms.lua). Like the Kraken, both
-- appear at the surface (water touching air; mobs_redo spawns one node
-- above the matched node) and dive (swimmer.lua): the Bay Shark at the
-- Kraken's rate, the Abyssal Shark a seldom spawn at a third of it. Every
-- water row keeps its top at or above y 0 (a lower top would join the
-- underground ABM).
mobs:spawn({
	name = "grug_mobs:bay_shark",
	nodes = {"default:water_source"},
	neighbors = {"air"},
	interval = 60,
	chance = 12000,
	active_object_count = 1,
	min_height = -10,
	max_height = 4,
})
mobs:spawn({
	name = "grug_mobs:abyssal_shark",
	nodes = {"default:water_source"},
	neighbors = {"air"},
	interval = 60,
	chance = 36000,
	active_object_count = 1,
	min_height = -10,
	max_height = 4,
})
