-- Panther (docs/design/biomes_mobs.md §3.1, jungle group).
-- Verb: "stalks (silent approach, pounce burst)" — grug_mobs.stalker from
-- verbs.lua, installed on the def BEFORE register_mob (verbs.lua header
-- contract).
--
-- The SILENT half is a def decision, not code (verbs.lua header): mobs_redo
-- plays sounds.war_cry on 90% of all target acquisitions (api.lua:220) and we
-- must not patch do_attack, so a stalker's def simply carries no
-- sounds.war_cry — mob_sound() then returns immediately (api.lua:196). This
-- def has no `sounds` table at all, because WP6/T4 imported no audio (the
-- freesound-derived animalworld/mobs_mc files need per-file verification,
-- LICENSE-media.md header). So the panther is silent today for two reasons;
-- when the sound pass lands, THIS def must stay war_cry-less on purpose.
--
-- ONE registration for both continents: §8.4 has the Accord jungle fringe
-- reuse the troll jungle nodes 1:1, so the rainforest-litter top is the same
-- on both sides and §3.2 shares the jungle tables anyway.

local panther = {
	description = "Panther",
	type = "monster",
	_grug_spawn_zones = {"outer", "coast"},
	-- HP/damage/XP/armor: engine-owned (levels.lua). Outer ring plus the
	-- jungle coasts means L38-60, the heaviest normal jungle mob.

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	-- A stalker hunts alone: no pack verb, no group_attack (§3 "group_attack
	-- per verb").
	group_attack = false,
	pathfinding = 1,

	walk_velocity = 1.5,
	run_velocity = 4.6, -- "4.6 heartland" (§3.1 speed column)
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	-- Short sight on purpose: it must get CLOSE before the pounce window of
	-- grug_mobs.stalker (4-8 m) even opens.
	view_range = 12,

	visual = "mesh",
	mesh = "grug_mobs_panther.b3d",
	textures = {{"grug_mobs_panther.png"}},
	-- Mesh scale rule (boar.lua): 8.41 units = 0.84 nodes at size 1 against
	-- the 0.95 box; upstream (animalworld) uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = false, -- silent approach, also literally

	-- wp6_model_notes §2.4: no run range — walk at a higher speed (§0.2).
	animation = {
		speed_normal = 140,
		stand_start = 0, stand_end = 100, stand_speed = 50,
		walk_start = 100, walk_end = 200,
		run_start = 100, run_end = 200, run_speed = 200,
		punch_start = 250, punch_end = 350,
	},

	-- §3.1 jungle row: meat 1/1, leather 1/2 [leather], sleek pelt 1/4.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:sleek_pelt", chance = 4, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.stalker(panther, {})
grug_mobs.register_mob("grug_mobs:panther", panther)

-- §4 row "Panther | rainforest litter | 20 | 1800 | 4 | max 5 | outer,
-- coast". Night mob (§3.1): max_light 5 plus day_toggle = false, the same
-- pair spider.lua uses.
mobs:spawn({
	name = "grug_mobs:panther",
	nodes = {"default:dirt_with_rainforest_litter"},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})
