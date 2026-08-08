-- Bog Fowl (docs/design/biomes_mobs.md §3.0, the 2026-08-08 critter round:
-- "Bog Fowl (swamp, day)").
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua, no helper from verbs.lua.
--
-- The swamp is universal (§1.3: registered ONCE for the whole world), so this
-- is the one new critter both continents share, and it needs no continent
-- gate for the same reason the Crocodile and the Bog Ooze need none: `mud`
-- exists on both sides and the mob is the same on both sides. Contrast
-- rabbit.lua, whose _grug_spawn_check exists only because Rabbit and Hare are
-- a TINTED PAIR and mud/sand would otherwise carry both tints in one place.

local fowl = {
	description = "Bog Fowl",
	type = "animal",
	passive = true,
	runaway = true,
	-- No _grug_spawn_zones: `grug_nodes:mud` is the swamp signature top and
	-- nothing else, so the node whitelist alone confines this mob to the
	-- swamp — in whichever ring a swamp pocket happens to land (§4's "role is
	-- not ring"; the swamp reaches core, inner, outer, coast and war_coast).
	-- THE critter tier (levels.lua, §3.0): level 1, 1 HP, 10 XP flat, no fall
	-- damage, never elite or rare, never telegraphs.
	_grug_tier = "critter",

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	jump = true,
	stepheight = 1.1,
	fear_height = 3,
	view_range = 8,
	-- A swamp is half water, and mobs_redo's `floats` is what keeps a
	-- ground mob on the surface of a pool instead of walking the bottom
	-- (api.lua falling(): the liquid branch overrides the fall speed). It is
	-- mobs_redo's default anyway; it is written here because for THIS mob it
	-- is a design property, not an accident.
	floats = true,

	visual = "mesh",
	mesh = "grug_mobs_bog_fowl.b3d",
	textures = {{"grug_mobs_bog_fowl.png"}},
	-- ONE material slot (single TRIS buffer) — no atlas_textures() call.
	-- Scale rule (boar.lua): the mesh spans 0.06..6.63 model units in y, i.e.
	-- 0.66 nodes at visual_size 1, which is exactly what the 0.69 box below
	-- is sized against. Upstream draws it at 1 as well.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.69, 0.2},
	makes_footstep_sound = true,

	-- FRAMES READ OUT OF THE .b3d (LICENSE-media.md §8's rule):
	-- grug_mobs_bog_fowl.b3d has 11 keyed joints, 638 keys, real frame range
	-- 1..58. Upstream's clips inside that: a single-frame idle, a walk loop
	-- 0..20 and a wing flap 20..26 (the adult set; 31+ is the chick, unused —
	-- mobs_redo would only reach it via breeding, which we do not register).
	-- stand starts at the first REAL key, 1, not at upstream's 0.
	animation = {
		stand_start = 1, stand_end = 1,
		walk_start = 1, walk_end = 20, walk_speed = 25,
		run_start = 1, run_end = 20, run_speed = 50,
	},

	-- FOOD ONLY (§3.0). Explicitly NOT the feather its upstream drops: plain
	-- feather belongs to the bird-of-prey table now (§3.0/§6, eagle.lua), and
	-- a farmable feather bird in the swamp is exactly the loot-table problem
	-- the critter class was created to remove.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:bog_fowl", fowl)

-- §3.0's numbers for the four new critters: interval 20 / chance 2200 /
-- aoc 2, day (`min_light 10`; §4 prints the decided post-0.75 value 1650 —
-- see cave_bat.lua).
--
-- Budget effect, per wp6_spawn_budget.md §2.2 (day column only — day mob):
--   swamp core 8->10, inner 8->10, outer 10->12, coast 4->6, war_coast 2->4
-- The world day peak is 16 and the highest cell touched here reaches 12, so
-- nothing moves the peak. The swamp/coast cell keeps its documented
-- night-empty status (§1.5's third day-only exception): adding a DAY critter
-- cannot change a night column.
mobs:spawn({
	name = "grug_mobs:bog_fowl",
	nodes = {"grug_nodes:mud"}, -- grug_swamp
	min_light = 10,
	interval = 20,
	chance = 2200,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
})
