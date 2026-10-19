-- Tortoise (Round 51, sea plan rulings S10 and S15; biomes_mobs.md "Round 51
-- water families"): the neutral water beast of sea shores and lakes. It bites
-- back when attacked and gives normal XP and fish loot (S14).
--
-- An AMPHIBIAN, not a swimmer: like the crocodile it floats and has no `fly`
-- (crocodile.lua's water note: a `fly` mob flops helplessly on every bank), so
-- it walks on land, swims at the surface and, once struck, follows its
-- attacker through the water and up the bank (Round 34: every floating
-- non-flier swims after its target, mobs/api.lua grug_may_wade). Slow on
-- purpose: a player can always walk away from it.
--
-- What spawns is the family's six sub-types by drop tier (data/subtypes.json,
-- tortoise_t1 .. tortoise_t6, names per slot in data/names.json); this
-- registration is their base. Spawning by water band is Round 51 MOBS step M2.
--
-- Port of animalworld's tortoise (MIT code and media, LICENSE-media.md §3):
-- its model and texture; the behaviour is ours. No sounds until the user
-- picks them (Round 51 plan §5).

local tortoise = {
	description = "Tortoise",
	_grug_voice = false,
	clock = "any",
	type = "animal",
	-- HP/damage/XP/armor: engine-owned (levels.lua).
	reach = 2,
	attack_type = "dogfight",
	group_attack = false,
	pathfinding = 1,

	walk_velocity = 0.5,
	run_velocity = 2,
	jump = false,
	jump_height = 0,
	-- 1.1, not 1: the engine steps an object up only when its bottom plus
	-- stepheight lies strictly above the obstacle's top (shore_crab.lua).
	stepheight = 1.1,
	fear_height = 2,
	view_range = 8,
	-- Swims at the surface instead of walking along the bed (crocodile.lua).
	floats = true,

	visual = "mesh",
	mesh = "grug_mobs_tortoise.b3d",
	-- grug_mobs_tortoise.b3d is 18 meshes = 18 material slots on one PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_tortoise.png", 18)},
	-- Mesh scale rule (boar.lua): 0.7 x 1.16 x 0.56 nodes at size 1. The
	-- base is 1.1 so that the NAMES draft's ladder (0.8 .. 1.45 of the model)
	-- fits the catalogue's sub-type sizes 0.75 .. 1.3 (biomes_mobs.md).
	visual_size = {x = 1.1, y = 1.1},
	collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.6, 0.4},
	-- Rotated selection box = measured mesh bounds (tools/r28_a3).
	selectionbox = {-0.4, 0, -0.7, 0.4, 0.65, 0.65, rotate = true},
	makes_footstep_sound = false,

	-- Keys 1..400 (LICENSE-media.md §8): stand 1-100, walk 200-300, the
	-- bite 300-400; no run range, so run = walk at a higher speed. The second
	-- stand clip (100-200) and the die clip are left out.
	animation = {
		speed_normal = 30,
		stand_start = 1, stand_end = 100,
		walk_start = 200, walk_end = 300,
		run_start = 200, run_end = 300, run_speed = 60,
		punch_start = 300, punch_end = 400, punch_speed = 60,
	},

	-- The fallback; the family table by band (data/drops.json `tortoise`)
	-- replaces it for every sub-type.
	drops = {
		{name = "grug_mobs:raw_fish", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:tortoise", tortoise)
