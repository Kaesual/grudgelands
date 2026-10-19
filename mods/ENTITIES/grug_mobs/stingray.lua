-- Stingray (Round 51, sea plan rulings S10, S11 and S14; biomes_mobs.md
-- "Round 51 water families"): the hostile pure swimmer of the shelf, the
-- coastal belt, the bay rims and the dragon channels. Normal XP and fish
-- loot.
--
-- A PURE SWIMMER (swimmer.lua, like the Kraken and the Reed Angelfish): it
-- never leaves the sea water, and it never fights from the water what stands
-- on land (S10, S11): it acquires no player out of the water and off a boat,
-- and a target that leaves the water resets it -- it forgets the fight, heals
-- to full and swims back to its spawn point in deeper water (aggro.lua
-- swimmer_reset). Spawning away from land, by water band, is Round 51 MOBS
-- step M2.
--
-- What spawns is the family's sub-types by drop tier (data/subtypes.json,
-- stingray_t1 .. t4 and t6; no tier-5 water holds it); this registration is
-- their base.
--
-- Port of animalworld's stingray (MIT code and media, LICENSE-media.md §3):
-- its model and texture; the behaviour is ours. No sounds until the user
-- picks them (Round 51 plan §5).

local stingray = {
	description = "Stingray",
	_grug_voice = false,
	clock = "any",
	type = "monster",
	-- HP/damage/XP/armor: engine-owned (levels.lua).
	reach = 2,
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
	walk_velocity = 1,
	run_velocity = 3.5,
	view_range = 10,

	visual = "mesh",
	mesh = "grug_mobs_stingray.b3d",
	-- grug_mobs_stingray.b3d is 14 meshes = 14 material slots on one PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_stingray.png", 14)},
	-- Mesh scale rule (boar.lua): 1.6 x 2.3 x 0.4 nodes (tail included) at
	-- size 1. The base is 1.15 so that the NAMES draft's ladder (0.8 .. 1.5
	-- of the model) fits the catalogue's sub-type sizes 0.75 .. 1.3
	-- (biomes_mobs.md). The box is the flat body; the tail may stick out.
	visual_size = {x = 1.15, y = 1.15},
	collisionbox = {-0.8, -0.01, -0.8, 0.8, 0.45, 0.8},
	-- Rotated selection box = measured mesh bounds (tools/r28_a3).
	selectionbox = {-0.95, -0.1, -1.7, 0.95, 0.5, 0.95, rotate = true},
	makes_footstep_sound = false,

	-- Keys 1..300 (the ANIM chunk says 199; LICENSE-media.md §8): rest
	-- 1-100, swim 100-200, the sting 200-300.
	animation = {
		speed_normal = 60,
		stand_start = 1, stand_end = 100,
		walk_start = 100, walk_end = 200,
		run_start = 100, run_end = 200, run_speed = 100,
		fly_start = 100, fly_end = 200,
		punch_start = 200, punch_end = 300, punch_speed = 100,
	},

	-- The fallback; the family table by band (data/drops.json `stingray`)
	-- replaces it for every sub-type.
	drops = {
		{name = "grug_mobs:raw_fish", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:stingray", stingray)
