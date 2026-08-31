-- Zebra (docs/design/biomes_mobs.md §3.1, savanna extras: "Zebra — flees,
-- meat x2 + leather 1/2 [leather]").
--
-- Verb "grazes" — PASSIVE PREY since WP36 (§3.0), same shape as stag.lua:
-- no aggro on sight, fights back when attacked, keeps level/HP/XP from the
-- field and formulas and keeps its leather. §3.2 puts it on the shared STAG
-- table together with Stag and Gaunt Stag ("Stag, Zebra-mirror | Gaunt Stag,
-- Zebra"), so the drops below are byte-identical to stag.lua's.
--
-- No _grug_min_level: the family row of §4 (the stag row) carries none and
-- the Accord mirror (stag.lua) carries none either. The savanna inner ring
-- hands out L10-25 through the field anyway.

local zebra = {
	description = "Zebra",
	type = "animal",
	-- Stats engine-owned (levels.lua), normal tier.

	walk_velocity = 1.5,
	run_velocity = 3.4, -- grazer speed (§0)
	-- wp6_model_notes §2.2: upstream sets jump = false and stepheight 2 —
	-- a zebra walks up slopes instead of hopping.
	jump = false,
	stepheight = 2,
	fear_height = 3,
	view_range = 14, -- open savanna: it sees you coming
	-- Ground prey chases up to 45 m since WP36 — see stag.lua for the full
	-- reasoning. A* only runs from the attack branch, i.e. only after a punch.
	pathfinding = 1,

	visual = "mesh",
	mesh = "grug_mobs_zebra.b3d",
	-- grug_mobs_zebra.b3d is 12 cubes = 12 material slots on one atlas PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_zebra.png", 12)},
	-- Mesh scale rule (boar.lua): 17.46 units = 1.75 nodes at size 1 against
	-- the 1.4 box; upstream (animalworld) has no visual_size, i.e. 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 1.4, 0.5},
	makes_footstep_sound = true,

	-- wp6_model_notes §2.2. `stand1` is mobs_redo's second idle clip — it
	-- picks randomly between stand and stand1. No punch clip on this mesh —
	-- set_animation simply keeps the current one (stag.lua's note).
	animation = {
		speed_normal = 30,
		stand_start = 0, stand_end = 50,
		stand1_start = 50, stand1_end = 100,
		walk_start = 100, walk_end = 200, walk_speed = 70,
		run_start = 100, run_end = 200, run_speed = 90,
	},

	-- Stag table (§3.2), identical to stag.lua.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

-- Verb before registration (verbs.lua contract).
grug_mobs.passive_prey(zebra)

grug_mobs.register_mob("grug_mobs:zebra", zebra)

-- §4 row "Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry
-- grass | 20 | 1800 | 3 | min 10 | inner, outer" — the Zebra's share of that
-- family row is the savanna top. T5's stag.lua already put the Gaunt Stag on
-- dry grass too; both rows carry the family numbers, which is correct because
-- mobs_redo counts active_object_count per registered entity name.
mobs:spawn({
	name = "grug_mobs:zebra",
	nodes = {"default:dry_dirt_with_dry_grass"}, -- grug_savanna
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
