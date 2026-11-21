-- Tortoise (Round 51, sea plan rulings S10 and S15; biomes_mobs.md "Round 51
-- water families"): the neutral water beast of sea shores and lakes. It bites
-- back when attacked and gives normal XP and fish loot (S14).
--
-- An AMPHIBIAN, not a swimmer: like the crocodile it floats and has no `fly`
-- (crocodile.lua's water note: a `fly` mob flops helplessly on every bank), so
-- it walks on land, swims at the surface and, once struck, follows its
-- attacker through the water and up the bank (Round 34: every floating
-- non-flier swims after its target, mobs/api.lua grug_may_wade). In water it
-- holds one height with its feet half a node under the surface, its shell
-- just breaking it (Round 51 FM, mobs/api.lua grug_float_hold); the model has
-- no swim clip, so it paddles with its walk clip.
--
-- Not to be kited (Round 84 WATER, round84-plan.md ruling 3): struck from
-- range, it answers with a ball of mud (normal ranged damage for its level,
-- grug_mobs.stamp_arrow_damage) that slows by 45 % for 3 s through the one
-- mob-slow slot (grug_mobs.slow_player: no stacking with a web or a hex).
-- Its shot range, 33, lies just beyond the longest player range (31: bow
-- skills 25, Long View +3, the elf passive +3; measured eye to body, where
-- the mob measures feet to feet). Close in it bites (dogshoot by distance,
-- mobs/api.lua grug_dogshoot_mode). It runs 3 on land and 3.75 in water
-- (`_grug_water_speed_factor`, mobs/api.lua grug_liquid_speed), and stays
-- neutral: view range 8, it never picks a target itself; a hit from any
-- distance makes the attacker its target (on_punch), and the 45-node give-up
-- distance keeps it. The shot reuses the bite clip (no shoot clip in the
-- model) and is silent.
--
-- What spawns is the family's six sub-types by drop tier (data/subtypes.json,
-- tortoise_t1 .. tortoise_t6, names per slot in data/names.json); this
-- registration is their base, so all six (the Pond Terrapin of the start
-- lakes too) shoot back. Spawning by water band is Round 51 MOBS step M2.
--
-- Port of animalworld's tortoise (MIT code and media, LICENSE-media.md §3):
-- its model and texture; the behaviour is ours. No sounds until the user
-- picks them (Round 51 plan §5). The mud ball's sprite is our own
-- (tools/r84_water/gen_mud_texture.py, LICENSE-media.md "Tortoise mud
-- ball").

local MUD_SLOW_SECONDS = 3
local MUD_SLOW_FACTOR = 0.55

local function mud_hit(self, object)
	local damage = self._grug_damage or grug_mobs.scale_attack_damage(1)
	object:punch(self.object, 1.0, {
		full_punch_interval = 1.0, damage_groups = {fleshy = damage},
	}, nil)
	if core.is_player(object) then
		grug_mobs.slow_player(object, MUD_SLOW_SECONDS, MUD_SLOW_FACTOR)
	end
end

grug_mobs.register_homing_arrow("grug_mobs:tortoise_mud", {
	label = "a ball of mud",
	visual = "sprite", visual_size = {x = 0.4, y = 0.4},
	textures = {"grug_mobs_tortoise_mud.png"},
	velocity = 12,
	impact = "#6b5636", -- mud flecks
	hit_player = mud_hit, hit_mob = mud_hit,
	hit_node = function(self, pos, node) end,
})

local tortoise = {
	description = "Tortoise",
	_grug_voice = false,
	clock = "any",
	type = "animal",
	-- HP/damage/XP/armor: engine-owned (levels.lua).
	reach = 2,
	attack_type = "dogshoot",
	dogshoot_switch = 1,
	arrow = "grug_mobs:tortoise_mud", arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5, shoot_offset = 0.5,
	_grug_shot_range = 33,
	group_attack = false,
	pathfinding = 1,

	walk_velocity = 0.5,
	run_velocity = 3,
	_grug_water_speed_factor = 1.25,
	jump = false,
	jump_height = 0,
	-- 1.1, not 1: the engine steps an object up only when its bottom plus
	-- stepheight lies strictly above the obstacle's top (shore_crab.lua).
	stepheight = 1.1,
	fear_height = 2,
	view_range = 8,
	-- Swims at the surface instead of walking along the bed (crocodile.lua),
	-- at one height as an amphibian (Round 51 FM, init.lua register_mob).
	floats = true,
	_grug_amphibian = true,

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
	-- bite 300-400; no run range, so run = walk at a higher speed, and no
	-- shoot range, so the shot plays the bite. The second stand clip
	-- (100-200) and the die clip are left out.
	animation = {
		speed_normal = 30,
		stand_start = 1, stand_end = 100,
		walk_start = 200, walk_end = 300,
		run_start = 200, run_end = 300, run_speed = 60,
		punch_start = 300, punch_end = 400, punch_speed = 60,
		shoot_start = 300, shoot_end = 400, shoot_speed = 60,
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
