-- Serpent (docs/design/biomes_mobs.md §3.1, jungle group).
-- Verb: "poisons (hit applies 1 dmg/2 s, 6 s)" — grug_mobs.melee_rider +
-- grug_mobs.poison_player from verbs.lua, installed on the def BEFORE
-- register_mob (verbs.lua header contract), the same shape spider.lua uses
-- for its web slow.
--
-- Upstream (animalworld kobra) also has a poison PROJECTILE; T4 did not
-- import its sprite (wp6_model_notes §2.5) and the design's verb is a
-- melee-applied DoT anyway, so this stays a pure dogfight mob.
--
-- ONE registration for both continents (§8.4: the Accord jungle fringe
-- reuses the troll jungle nodes 1:1; §3.2 shares the jungle tables).

local POISON_TICKS = 3 -- x interval = 6 s total (§3.1)
local POISON_INTERVAL = 2 -- s between ticks
local POISON_DAMAGE = 1 -- hp per tick

local serpent = {
	description = "Serpent",
	type = "monster",
	-- HP/damage/XP/armor: engine-owned (levels.lua).

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = false, -- solitary ambusher, no pack verb
	pathfinding = 1,

	walk_velocity = 1.5,
	run_velocity = 4.4, -- aggressive-mob speed (§0)
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 10, -- low to the ground: it notices you late

	visual = "mesh",
	mesh = "grug_mobs_serpent.b3d",
	-- grug_mobs_serpent.b3d is 15 cubes = 15 material slots on one atlas PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_serpent.png", 15)},
	-- Mesh scale rule (boar.lua): 36.5 units = 3.65 nodes at size 1, which is
	-- why upstream (animalworld) scales this one DOWN to 0.3 (~1.1 rendered
	-- nodes) to match the box below. Copied verbatim.
	visual_size = {x = 0.3, y = 0.3},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = false,

	-- wp6_model_notes §2.5: no run range — walk at a higher speed (§0.2).
	animation = {
		speed_normal = 60,
		stand_start = 0, stand_end = 100,
		walk_start = 250, walk_end = 350,
		run_start = 250, run_end = 350, run_speed = 90,
		punch_start = 150, punch_end = 200,
	},

	-- §3.1 jungle row: scaled hide 1/2 [leather], venom sac 1/3.
	drops = {
		{name = "grug_mobs:scaled_hide", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:venom_sac", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.melee_rider(serpent, function(self, target)
	grug_mobs.poison_player(target, POISON_TICKS, POISON_INTERVAL, POISON_DAMAGE)
end)

grug_mobs.register_mob("grug_mobs:serpent", serpent)

-- §4 row "Serpent | rainforest litter, mud | 20 | 1800 | 4 | min 10 | outer,
-- coast". The mud top is grug_swamp, which the jungle bands border — §3.1
-- lists the serpent under the jungle group, the swamp pools are its second
-- home, and the zone gate keeps both in the outer/coast rings.
mobs:spawn({
	name = "grug_mobs:serpent",
	nodes = {
		"default:dirt_with_rainforest_litter", -- jungle edge / jungle fringe
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle (WP36 top)
		"grug_nodes:mud", -- grug_swamp
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})
