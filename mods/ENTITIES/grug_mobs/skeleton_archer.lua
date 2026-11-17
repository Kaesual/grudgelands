-- Skeleton Archer (docs/design/biomes_mobs.md §3.1, forest pair: "bone
-- forest + war coast only"). Verb: dogshoot — mostly ranged, melee only when
-- something is already in its face.
--
-- The war-coast Skeleton Raider (same mesh, own texture) is T7's job; both
-- share the arrow entity registered here.

--
-- Projectile
--
-- Damage is NOT written here: grug_mobs.stamp_arrow_damage (verbs.lua) is
-- installed as the def's arrow_override below and stamps the SHOOTER's
-- level-scaled `damage` onto every arrow at fire time, so a level-50
-- skeleton's arrow hits for a level-50 mob's damage and the level engine
-- stays the single source of truth. The `damage` fallback of
-- register_simple_arrow is only used if an arrow ever flies without a
-- shooter, which cannot happen on this path.
grug_mobs.register_simple_arrow("grug_mobs:arrow_entity", {
	label = "an arrow",
	texture = "grug_mobs_arrow.png",
	velocity = 16,
	size = {x = 0.4, y = 0.4},
	lifetime = 4,
	impact = "#a08860", -- splinters (Round 40 PM)
})

--
-- Mob
--

local skeleton = {
	description = "Skeleton Archer",
	_grug_voice = "skeleton",
	clock = "night",
	type = "monster",
	-- HP/damage/XP/armor: engine-owned (levels.lua). The war-coast cap of
	-- grug_zones.mob_level_at keeps the coastal ones at 20-30, the bone
	-- forest ones scale to 60.

	reach = 3,
	attack_type = "dogshoot",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	-- Ranged loadout. dogshoot_switch = 1 starts in the RANGED mode; since
	-- Round 78 the mode follows the distance (golem.lua): a target close in
	-- is met in melee, which is the "melee when cornered" half.
	arrow = "grug_mobs:arrow_entity",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5,
	-- Aim lift, from the upstream skeleton def (VoxeLibre skeleton+stray.lua)
	-- for this exact mesh: the arrow spawns at body centre, so without it
	-- every shot lands at the target's feet.
	shoot_offset = 1.5,
	dogshoot_switch = 1,

	-- §3.1 speed column: 4.0 in combat, a calm walk while roaming (Round 24
	-- ruling 20; mobs_redo roams at walk_velocity and fights at
	-- run_velocity). No soft de-aggro, so a chase never drops below 4.0.
	walk_velocity = 1,
	run_velocity = 4.0,
	_grug_soft_deaggro = false,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 16, -- it shoots; it needs to see further than a brawler

	visual = "mesh",
	mesh = "grug_mobs_skeleton.b3d",
	-- THREE texture slots (wp6_model_notes §0.3): 1 = armour, 2 = bones,
	-- 3 = wielded item. Slot 1 stays blank (a missing slot would render
	-- untextured); slot 3 holds grug_gear's shipped starter bow (media are
	-- global; 0.53.1 ruling 9), as the upstream def puts its bow item there.
	-- The Skeleton Raider and the Frost Stray hold the same bow.
	textures = {{
		"grug_mobs_blank.png",
		"grug_mobs_skeleton.png",
		"grug_gear_bow_wood.png",
	}},
	-- Mesh scale rule (boar.lua): 20.1 units = 2.01 nodes at size 1 against
	-- the 1.98 box; upstream uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3},
	-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
	selectionbox = {-0.5, -0.05, -0.7, 0.55, 2.05, 0.7, rotate = true},
	makes_footstep_sound = true,

	-- wp6_model_notes §1.3: no melee clip — `punch` reuses the shoot range.
	animation = {
		stand_start = 0, stand_end = 40, stand_speed = 15,
		walk_start = 40, walk_end = 60, walk_speed = 15,
		run_start = 40, run_end = 60, run_speed = 30,
		shoot_start = 70, shoot_end = 90, shoot_speed = 15,
		punch_start = 70, punch_end = 90, punch_speed = 15,
	},

	-- Skeleton table (§3.1): bone 1/1, linen scrap 1/2. The sell-only arrow
	-- bundle no longer drops (Round 46 ruling 12; coin bags, aggro.lua).
	drops = {
		{name = "grug_mobs:bone", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- No daylight burn: the design gates the skeleton by spawn time only
	-- (§3.1 "night"), it does not ask for an undead sun weakness.
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:skeleton_archer", skeleton)
