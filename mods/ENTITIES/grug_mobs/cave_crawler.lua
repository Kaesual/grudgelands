-- Cave Crawler (docs/design/biomes_mobs.md §3.0, the 2026-08-08 critter
-- round: "Cave Bat and a cave crawler (both `underground` — the caves had no
-- critter at all)").
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua, no helper from verbs.lua. The upstream
-- mob this mesh comes from is a hostile burrowing monster; ours is not — the
-- name, the class and the behaviour are all ours, only the model is borrowed
-- (LICENSE-media.md §1).
--
-- Its mesh is shared with the Bone Weevil (bone_weevil.lua), the surface
-- half of the same asset — the same arrangement gull.lua and carrion_crow.lua
-- have. Two files, because they are two families in two biome groups.

local crawler = {
	description = "Cave Crawler",
	type = "animal",
	passive = true,
	runaway = true,
	_grug_spawn_zones = {"underground"},
	-- THE critter tier (levels.lua, biomes_mobs.md §3.0): level 1, 1 HP,
	-- 10 XP flat, no fall damage, never elite or rare, never telegraphs.
	-- HP/damage/XP/armor and fall_damage are engine-owned. Down here the
	-- level clamp is the point: mob_level_at's depth term would otherwise
	-- scale this with the shaft it lives in.
	_grug_tier = "critter",

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	jump = true,
	stepheight = 1.1,
	fear_height = 3,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_cave_crawler.b3d",
	textures = {{"grug_mobs_cave_crawler.png"}},
	-- ONE material slot (single TRIS buffer) — no atlas_textures() call.
	-- Scale rule (boar.lua): the mesh is 1.41 units tall and 2.0 wide, i.e.
	-- 0.14 x 0.20 nodes at visual_size 1 — far too small to see. Upstream
	-- draws it at 3 (0.42 nodes high), which is what the box below is sized
	-- against, and what we keep.
	visual_size = {x = 3, y = 3},
	collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.44, 0.4},
	makes_footstep_sound = false,

	-- FRAMES READ OUT OF THE .b3d (LICENSE-media.md §8's rule):
	-- grug_mobs_cave_crawler.b3d has 7 keyed joints, 147 keys, real frame
	-- range 1..21 — one crawl loop and nothing else. stand/walk/run all sit
	-- on it, at three speeds; no punch clip, and a critter needs none.
	animation = {
		stand_start = 1, stand_end = 20, stand_speed = 15,
		walk_start = 1, walk_end = 20, walk_speed = 25,
		run_start = 1, run_end = 20, run_speed = 50,
	},

	-- FOOD ONLY (§3.0).
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:cave_crawler", crawler)

-- THE ONE ROW IN THIS ROUND THAT IS NOT aoc 2, and the arithmetic is the
-- reason (biomes_mobs.md §3.0, wp6_spawn_budget.md §2.2):
--
--   underground today  Zombie 4 + Giant Spider 4 + one Golem 1  =  9 / 9
--   + Cave Bat 2                                                = 11 / 11
--   + Cave Crawler 2                                            = 13 / 13   <- one over
--   + Cave Crawler 1                                            = 12 / 12   <- ships
--
-- The night peak of the whole world is 12 (bone forest/outer), so a second
-- cave critter at the full 2 would have made the underground the new peak —
-- for two harmless 1 HP animals. `aoc` counts per entity NAME inside a
-- 128-node sphere, so the two cave critters are two independent budgets and
-- the sum is the cell's; there is no way to share one. Shipping the second at
-- 1 buys the cave its bug at zero cost to the ceiling. `chance` stays 2200,
-- so the smaller budget still fills at the same rate.
--
-- Row shape: the canonical cave row of zombie.lua (see cave_bat.lua).
mobs:spawn({
	name = "grug_mobs:cave_crawler",
	nodes = {"default:stone", "group:grug_stratum"},
	max_light = 5,
	interval = 20,
	chance = 2200,
	active_object_count = 1,
	min_height = -31000,
	max_height = -40,
})
