-- Cave Bat (docs/design/biomes_mobs.md §3.0, the 2026-08-08 critter round:
-- "Cave Bat and a cave crawler (both `underground` — the caves had no critter
-- at all)").
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua/gull.lua, no helper from verbs.lua.
--
-- WHY THE CAVES GET CRITTERS AT ALL: before this round the underground cell
-- was Zombie + Giant Spider + one Golem and nothing else — every single thing
-- that moves down there wants the player dead. A critter is scenery with a
-- use (§3.0), and a cave with bats in it reads as a place rather than as a
-- corridor of ambushes. It costs the player nothing: 1 HP, 10 XP, meat.
--
-- FLIGHT: `fly = true` + `fly_in = "air"`, the decision eagle.lua documents
-- in full (falling() bails out for fly mobs so the bat hovers instead of
-- sinking; flight_check() passes because it always stands in air;
-- fear_height/do_jump are inert). `pathfinding` stays unset — core.find_path
-- returns a WALKING path, which is not how this mob moves.

local bat = {
	description = "Cave Bat",
	type = "animal",
	passive = true,
	runaway = true,
	_grug_spawn_domains = {"underground"},
	-- THE critter tier (levels.lua, biomes_mobs.md §3.0): level 1, 1 HP,
	-- 10 XP flat, no fall damage, never elite or rare, never telegraphs.
	-- HP/damage/XP/armor and fall_damage are engine-owned — the def must not
	-- restate any of them. It is also what keeps this mob harmless at depth:
	-- mob_level_at's depth term would otherwise hand a bat at y -1200 level
	-- 60, i.e. 315 HP of flapping nothing.
	_grug_tier = "critter",

	-- Flier (see the header).
	fly = true,
	fly_in = "air",
	jump = false,
	fear_height = 0,

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	stepheight = 1.1,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_cave_bat.b3d",
	textures = {{"grug_mobs_cave_bat.png"}},
	-- ONE material slot on this mesh (a single TRIS buffer), so no
	-- atlas_textures() call — the list is one entry, as upstream has it.
	-- Scale rule (boar.lua): 10 model units = 1 node, and this mesh is 4.15
	-- units tall around a raised origin; upstream draws it at visual_size 1
	-- against exactly the box below, which is what we keep.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.25, -0.01, -0.25, 0.25, 0.89, 0.25},
	makes_footstep_sound = false,

	-- FRAMES READ OUT OF THE .b3d, not out of mobs_mc/bat.lua (the rule
	-- LICENSE-media.md §8 exists for — the Kraken shipped a frozen animation
	-- because a def was copied from upstream instead of measured):
	-- grug_mobs_cave_bat.b3d has 7 keyed joints, 567 keys, real frame range
	-- 1..81. Upstream's clips are the flight loop 0..40 and a death 40..80;
	-- we take the flight loop (starting at the first real key, 1) for
	-- stand/walk/run/fly and skip the death clip — mobs_redo plays no death
	-- animation for our mobs (init.lua: both death hooks skip it).
	animation = {
		stand_start = 1, stand_end = 40, stand_speed = 80,
		walk_start = 1, walk_end = 40, walk_speed = 80,
		run_start = 1, run_end = 40, run_speed = 80,
		fly_start = 1, fly_end = 40, fly_speed = 80,
	},

	-- FOOD ONLY (§3.0). No leather, no guano, no crafting ingredient.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:cave_bat", bat)

-- §3.0's numbers for the four new critters: interval 20 / chance 2200 /
-- aoc 2. §4's table prints **2200** for this row too, and that is not an
-- accident of the unimplemented 0.75 pass: this is an `underground`-ONLY
-- row, and §4's header excludes every row that reaches the caves from the
-- surface-density multiplier, because cave pressure is the §4.1 depth
-- pulse's to own. So this number must NOT be multiplied by WP37 — doing so
-- would refill the underground cell (calibrated to exactly 12/12, the night
-- peak) a third faster. Same for cave_crawler.lua; the two SURFACE critters
-- (bone_weevil.lua, bog_fowl.lua) are the ones §4 prints at 1650.
-- This is the FIRST of the two cave rows and the one that keeps the
-- full aoc 2; the Cave Crawler ships at 1 so the cell lands exactly on the
-- night peak instead of one over it (cave_crawler.lua carries the
-- arithmetic).
--
-- The node list, the heights and the light gate are the canonical cave row
-- zombie.lua documents in full — read that comment before touching any of
-- them. In short: `group:grug_stratum` is mandatory next to `default:stone`
-- (WP25 replaced all rock below -100), max_height -40 is exactly the
-- boundary the stable spawn policy calls `underground`, and `max_light 5` without
-- `day_toggle` means "dark, whatever the surface clock says" — which is why
-- this row counts in the day AND the night column of the budget audit.
mobs:spawn({
	name = "grug_mobs:cave_bat",
	nodes = {"default:stone", "group:grug_stratum"},
	max_light = 5,
	interval = 20,
	chance = 2200,
	active_object_count = 2,
	min_height = -31000,
	max_height = -40,
})
