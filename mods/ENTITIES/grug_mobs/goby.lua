-- Tide Goby (Round 51, sea plan rulings S10 and S14; biomes_mobs.md "Round 51
-- water families"): the sea's critter fish, as the Reed Angelfish is the
-- lakes'. Atmosphere anywhere in sea water; one Raw Fish per kill (fish loot,
-- critter fish included), no XP and no quality loot like every critter, and
-- never a kill target (quests.md Ruling 29). A world slot (data/names.json,
-- the water authority in spawn_policy.lua); its spawning is Round 51 MOBS
-- step M2.
--
-- Port of animalworld's goby (MIT code and media, LICENSE-media.md §3): its
-- model and texture; the behaviour is the Reed Angelfish's
-- (reed_angelfish.lua). Silent.

grug_mobs.register_mob("grug_mobs:goby", {
	description = "Tide Goby",
	_grug_voice = false,
	clock = "any",
	type = "animal",
	passive = true,
	runaway = false,
	_grug_tier = "critter",
	_grug_xp_reward = 0,
	_grug_no_quality_loot = true,

	-- Water-only movement guard and no climbing (swimmer.lua).
	fly = true,
	fly_in = "default:water_source",
	_grug_swimmer = true,
	stepheight = 0,
	floats = true,
	jump = false,
	fear_height = 0,
	walk_velocity = 0.8,
	run_velocity = 1.5,
	view_range = 5,

	visual = "mesh",
	mesh = "grug_mobs_goby.b3d",
	-- grug_mobs_goby.b3d is 12 meshes = 12 material slots on one PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_goby.png", 12)},
	-- Mesh scale rule (boar.lua): 0.16 x 0.39 x 0.2 nodes at size 1; 1.5
	-- makes it a hand-long fish next to the Reed Angelfish.
	visual_size = {x = 1.5, y = 1.5},
	collisionbox = {-0.15, -0.01, -0.15, 0.15, 0.3, 0.15},
	-- Rotated selection box = measured mesh bounds (tools/r28_a3).
	selectionbox = {-0.15, 0, -0.35, 0.15, 0.35, 0.3, rotate = true},
	makes_footstep_sound = false,

	-- Keys 1..200 (LICENSE-media.md §8): rest 1-100, swim 100-200.
	animation = {
		speed_normal = 100,
		stand_start = 1, stand_end = 100,
		walk_start = 100, walk_end = 200,
		run_start = 100, run_end = 200, run_speed = 160,
		fly_start = 100, fly_end = 200,
	},

	-- The standard fish, like the Reed Angelfish's.
	drops = {
		{name = "grug_mobs:raw_fish", chance = 1, min = 1, max = 1},
	},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
})
