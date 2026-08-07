-- Skeleton Raider (docs/design/biomes_mobs.md §3.1, war-coast row: "plus
-- Skeleton Raider (dogshoot, night — battlefield dead; skeleton table +
-- heavy cloth 1/3)").
--
-- The war coast's own undead: same mesh as the Skeleton Archer, own grimy
-- texture (wp6_model_notes §1.3), same verb and — per §3.2's "swamp/beach/
-- boar/zombie/bandit/skeleton | identical biomes both sides | identical" —
-- the same skeleton drop rows, plus the heavy cloth of the battlefield.
--
-- The arrow entity `grug_mobs:arrow_entity` and the level-scaled damage
-- stamp are REUSED from skeleton_archer.lua (which registers them and which
-- init.lua loads first) — the two archers must not have two projectiles.

local raider = {
	description = "Skeleton Raider",
	type = "monster",
	-- The war coast is not its own biome (§1.2 / §8.1), so the zone does all
	-- of the gating and every node of the row below is allowed. Unlike
	-- skeleton_archer.lua no _grug_spawn_check is needed: that family lives
	-- in the outer ring AND on the war coast and therefore needs a per-ROW
	-- rule; this one is war-coast-only.
	_grug_spawn_zones = {"war_coast"},
	-- HP/damage/XP/armor: engine-owned (levels.lua). The war-coast cap of
	-- grug_core.mob_level_at keeps this family at 20-30 — which is also why
	-- the two Captain Bonerattle rares (rares.lua) are ~L28.

	reach = 2,
	attack_type = "dogshoot",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	-- Ranged loadout, identical to skeleton_archer.lua: dogshoot_switch = 1
	-- opens in the RANGED phase and mobs_redo then alternates
	-- dogshoot_count_max seconds of shooting with dogshoot_count2_max seconds
	-- of melee (10 vs 3 = "mostly ranged"); a target inside `reach` forces
	-- melee regardless (api.lua:2249).
	arrow = "grug_mobs:arrow_entity",
	arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5,
	-- Aim lift for this mesh (see skeleton_archer.lua): without it every shot
	-- lands at the target's feet.
	shoot_offset = 1.5,
	dogshoot_switch = 1,
	dogshoot_count_max = 10,
	dogshoot_count2_max = 3,

	-- §3.1 speed column of the skeleton family: "4.0 walk". An archer keeps
	-- its distance rather than sprinting, so walk and run are the same value
	-- (skeleton_archer.lua does exactly this).
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
		"grug_mobs_skeleton_raider.png",
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

	-- Skeleton table (§3.1/§3.2) — the first three rows are byte-identical
	-- to skeleton_archer.lua's on purpose (bone 1/1 x1-2, linen scrap 1/2,
	-- arrows 1/3) — plus the war-coast heavy cloth 1/3 of the §3.1 row (§6
	-- lists "war-coast raiders" as a heavy-cloth source).
	drops = {
		{name = "grug_mobs:bone", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:arrow", chance = 3, min = 1, max = 1},
		{name = "grug_mobs:heavy_cloth", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- No daylight burn: the design gates the skeleton by spawn time only
	-- (§3.1 "night"), it does not ask for an undead sun weakness
	-- (skeleton_archer.lua takes the same line).
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:skeleton_raider", raider)

-- §4 has no own Skeleton Raider row; it is the war-coast half of the
-- skeleton family, so the numbers are the Skeleton Archer's
-- (interval 20 / chance 2000 / aoc 3 / max light 5) — §3.1 "night" gives the
-- light gate and day_toggle = false.
--
-- Nodes: the six settled tops of §1.3 (the war coast wears whichever settled
-- biome its band has) PLUS sand, because the ocean mask puts the actual
-- strait-facing beach inside the war-coast zone (§1.5) and a battlefield
-- shore without its dead would be odd. ONE row, so blight_dirt can be listed
-- here without a second ABM doubling up on it.
mobs:spawn({
	name = "grug_mobs:skeleton_raider",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:blight_dirt", -- grug_blight
		"default:sand", -- the war-coast beach band (§1.5)
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
