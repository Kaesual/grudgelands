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
	texture = "grug_mobs_arrow.png",
	velocity = 16,
	size = {x = 0.4, y = 0.4},
	lifetime = 4,
})

--
-- Mob
--

local skeleton = {
	description = "Skeleton Archer",
	type = "monster",
	-- Zones: the bone forest sits in the outer ring, and the war coast is
	-- the second home of the battlefield dead. The node whitelist alone
	-- cannot separate the two spawn rows below — see the check.
	_grug_spawn_zones = {"outer", "war_coast"},
	-- §4 gives this family "bone litter, blight_dirt, settled tops (war
	-- coast)": the settled tops are allowed ONLY on the war coast, while
	-- bone litter and blight dirt are allowed in the outer ring as well.
	-- _grug_spawn_zones is registered per mob NAME (init.lua), so it cannot
	-- express a per-ROW zone list — this check does, by looking at the node
	-- the spawn ABM matched. mobs_redo calls spawn_abm_check with the ABM's
	-- node position, BEFORE it moves the spawn position one node up
	-- (api.lua:3573 vs 3616), so core.get_node(pos) is exactly that top node.
	_grug_spawn_check = function(pos)
		if grug_core.zone_at(pos) == "war_coast" then
			return true -- war coast: every listed top node is fine
		end
		local node = core.get_node(pos).name
		return node == "grug_nodes:dirt_with_bone_litter"
			or node == "grug_nodes:blight_dirt"
	end,
	-- HP/damage/XP/armor: engine-owned (levels.lua). The war-coast cap of
	-- grug_core.mob_level_at keeps the coastal ones at 20-30, the bone
	-- forest ones scale to 60.

	reach = 2,
	attack_type = "dogshoot",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	-- Ranged loadout. dogshoot_switch = 1 starts in the RANGED phase and
	-- mobs_redo alternates: dogshoot_count_max seconds shooting, then
	-- dogshoot_count2_max seconds of melee (api.lua dogswitch). 10 vs 3 is
	-- "mostly ranged"; independently of the timer mobs_redo forces melee
	-- whenever the target is within `reach` (api.lua:2249), which is the
	-- "melee when cornered" half.
	arrow = "grug_mobs:arrow_entity",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5,
	-- Aim lift, from the upstream skeleton def (VoxeLibre skeleton+stray.lua)
	-- for this exact mesh: the arrow spawns at body centre, so without it
	-- every shot lands at the target's feet.
	shoot_offset = 1.5,
	dogshoot_switch = 1,
	dogshoot_count_max = 10,
	dogshoot_count2_max = 3,

	-- §3.1 speed column: "4.0 walk". An archer keeps its distance rather
	-- than sprinting, so walk and run are the same value.
	walk_velocity = 4.0,
	run_velocity = 4.0,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 16, -- it shoots; it needs to see further than a brawler

	visual = "mesh",
	mesh = "grug_mobs_skeleton.b3d",
	-- THREE texture slots (wp6_model_notes §0.3): 1 = armour, 2 = bones,
	-- 3 = wielded item. 1 and 3 stay blank until a bow texture is sourced;
	-- a missing slot would render untextured.
	textures = {{
		"grug_mobs_blank.png",
		"grug_mobs_skeleton.png",
		"grug_mobs_blank.png",
	}},
	-- Mesh scale rule (boar.lua): 20.1 units = 2.01 nodes at size 1 against
	-- the 1.98 box; upstream uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3},
	makes_footstep_sound = true,

	-- wp6_model_notes §1.3: no melee clip — `punch` reuses the shoot range.
	animation = {
		stand_start = 0, stand_end = 40, stand_speed = 15,
		walk_start = 40, walk_end = 60, walk_speed = 15,
		run_start = 40, run_end = 60, run_speed = 30,
		shoot_start = 70, shoot_end = 90, shoot_speed = 15,
		punch_start = 70, punch_end = 90, punch_speed = 15,
	},

	-- Skeleton table (§3.1): bone 1/1, linen scrap 1/2, arrows 1/3.
	drops = {
		{name = "grug_mobs:bone", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:arrow", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- No daylight burn: the design gates the skeleton by spawn time only
	-- (§3.1 "night"), it does not ask for an undead sun weakness.
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:skeleton_archer", skeleton)

--
-- Spawns — §4 row: interval 20 / chance 2000 / aoc 3 / max light 5 /
-- zones outer + war_coast. Two rows because the node list has two different
-- zone rules (see _grug_spawn_check above); both rows share the aoc budget,
-- mobs_redo counts it per entity name.
--

-- Row A: the wild/undead tops. Allowed in the outer ring AND on the war
-- coast.
mobs:spawn({
	name = "grug_mobs:skeleton_archer",
	nodes = {
		"grug_nodes:dirt_with_bone_litter", -- grug_bone_forest
		"grug_nodes:blight_dirt", -- grug_blight
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})

-- Row B: the settled tops — the battlefield dead of the war coast. The
-- check rejects every one of these outside zone war_coast, so this row
-- cannot leak skeletons into inland village patches. blight_dirt is the
-- sixth settled top but already covered by row A (and would otherwise be
-- hit by two ABMs).
mobs:spawn({
	name = "grug_mobs:skeleton_archer",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
