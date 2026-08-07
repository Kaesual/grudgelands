-- Rabbit / Hare (docs/design/biomes_mobs.md §3.1 "Rabbit/Hare (tints)"):
-- the harmless day critter of the settled biomes. Verb "flees" — mobs_redo
-- covers it natively with type "animal" + passive + runaway, so no helper
-- from verbs.lua is involved.
--
-- Two registrations because the design wants two looks per continent, split
-- along the three Accord tops (Rabbit) and the three Throng tops (Hare).
-- §4 lists ONE row for the family; both rows below carry its numbers,
-- which is correct because mobs_redo counts active_object_count per
-- registered entity name and the two node whitelists never overlap.

local function rabbit_def(description, texture)
	return {
		description = description,
		type = "animal",
		-- Never attacks, runs when hurt or approached (mobs_redo runaway).
		passive = true,
		runaway = true,
		_grug_spawn_zones = {"core", "inner"},
		-- HP/damage/XP and armor are engine-owned (levels.lua). A critter
		-- has no damage of its own; the level engine still assigns one, it
		-- is simply never used because the mob never attacks.

		-- Critter speed (biomes_mobs §0: 3.4). No pathfinding: a fleeing
		-- rabbit takes the straight line away from the threat, and
		-- core.find_path per critter would be pure overhead.
		walk_velocity = 1.5,
		run_velocity = 3.4,
		jump = true,
		stepheight = 1.1,
		fear_height = 3,
		view_range = 8,

		visual = "mesh",
		mesh = "grug_mobs_rabbit.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): 4.77 units = 0.48 nodes at size 1,
		-- matching the 0.49 box; upstream uses 1 as well.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.49, 0.2},
		makes_footstep_sound = false,

		-- wp6_model_notes §1.1: stand is the single frame 0, no punch clip
		-- (critter). Frames 21-41 are the baby rabbit and stay unused.
		animation = {
			stand_start = 0, stand_end = 0,
			walk_start = 0, walk_end = 20, walk_speed = 20,
			run_start = 0, run_end = 20, run_speed = 30,
		},

		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
			{name = "grug_mobs:light_leather", chance = 3, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Rabbit — the three Accord settled tops
--

grug_mobs.register_mob("grug_mobs:rabbit",
	rabbit_def("Rabbit", "grug_mobs_rabbit.png"))

mobs:spawn({
	name = "grug_mobs:rabbit",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})

--
-- Hare — the three Throng settled tops
--

grug_mobs.register_mob("grug_mobs:hare",
	rabbit_def("Hare", "grug_mobs_hare_dust.png"))

mobs:spawn({
	name = "grug_mobs:hare",
	nodes = {
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"grug_nodes:blight_dirt", -- grug_blight
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
