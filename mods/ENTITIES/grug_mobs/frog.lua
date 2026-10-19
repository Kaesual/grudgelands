-- Frog (Round 51, sea plan rulings S10 and S14; biomes_mobs.md "Round 51
-- water families"): the hostile amphibian of lakes, rivers and swamp pools.
-- It hops after a player through the water and up the bank, and gives normal
-- XP and fish loot.
--
-- An AMPHIBIAN, not a swimmer, for the crocodile's reason (crocodile.lua's
-- water note: a `fly` mob flops on every bank): it floats and has no `fly`,
-- so it walks on land and swims at the surface, and it follows its target
-- through harmless water (Round 34, mobs/api.lua grug_may_wade). The
-- upstream swim clip (250-350) is therefore unused.
--
-- What spawns is the family's six sub-types by drop tier (data/subtypes.json,
-- frog_t1 .. frog_t6); this registration is their base. Spawning by water band
-- is Round 51 MOBS step M2.
--
-- Port of animalworld's frog (MIT code and media, LICENSE-media.md §3):
-- its model and texture; the behaviour is ours. The model has no bite clip,
-- so the frog bites with its walk frames (the NAMES lane's question 2, taken
-- as recommended). No sounds until the user picks them (Round 51 plan §5).

local frog = {
	description = "Frog",
	_grug_voice = false,
	clock = "any",
	type = "monster",
	-- HP/damage/XP/armor: engine-owned (levels.lua).
	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	-- Solitary: no pack verb, so no group alert.
	group_attack = false,
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 3.4,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 4,
	view_range = 8,
	-- Swims at the surface instead of walking along the bed (crocodile.lua).
	floats = true,

	visual = "mesh",
	mesh = "grug_mobs_frog.b3d",
	-- grug_mobs_frog.b3d is 17 meshes = 17 material slots on one PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_frog.png", 17)},
	-- Mesh scale rule (boar.lua): 0.55 x 0.45 x 0.27 nodes at size 1 is a
	-- frog too small to fight. The NAMES draft's ladder runs 1.6 .. 2.9 of the
	-- model (1.0 .. 1.8 of a 1.6 frog); the base is 2.16 so that ladder fits
	-- the catalogue's sub-type sizes 0.75 .. 1.3 (biomes_mobs.md).
	visual_size = {x = 2.16, y = 2.16},
	collisionbox = {-0.55, -0.01, -0.55, 0.55, 0.6, 0.55},
	-- Rotated selection box = measured mesh bounds (tools/r28_a3).
	selectionbox = {-0.6, 0, -0.55, 0.65, 0.6, 0.7, rotate = true},
	makes_footstep_sound = false,

	-- Keys 1..350 (LICENSE-media.md §8): stand 1-100, walk (a hop) 100-200;
	-- run and the bite reuse the hop.
	animation = {
		speed_normal = 100,
		stand_start = 1, stand_end = 100,
		walk_start = 100, walk_end = 200,
		run_start = 100, run_end = 200, run_speed = 150,
		punch_start = 100, punch_end = 200, punch_speed = 150,
	},

	-- The fallback; the family table by band (data/drops.json `frog`)
	-- replaces it for every sub-type.
	drops = {
		{name = "grug_mobs:raw_fish", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:frog", frog)
