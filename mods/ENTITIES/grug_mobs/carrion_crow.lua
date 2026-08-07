-- Carrion Crow (docs/design/biomes_mobs.md §3.1, war-coast row: "plus
-- Skeleton Raider (…) and Carrion Crow (flees, feather)").
--
-- Same mesh, same scale, same animation table and the same critter/flier
-- reading as gull.lua — read that file's header for the flight decision and
-- for the beach/war-coast geography note; only the texture, the spawn nodes
-- and the zone list differ. The two are deliberately NOT one def factory in
-- one file: they are different families in different biome groups of §3.1
-- (beach/strait vs. war coast) and only happen to share an animalia mesh
-- (wp6_model_notes §3.2: "grug_mobs_gull.b3d … also serves the Carrion
-- Crow").

local crow = {
	description = "Carrion Crow",
	type = "animal",
	passive = true,
	runaway = true,
	-- The war coast is NOT its own biome (§1.2 / §8.1): it uses the local
	-- band's settled biome plus a battlefield decoration set. So there is no
	-- signature node to spawn on that would confine this mob — the ZONE does
	-- all of the gating, and the node list below is simply "all six settled
	-- tops". Unlike skeleton_archer.lua no _grug_spawn_check is needed: that
	-- family also spawns in the outer ring and therefore needs a per-ROW
	-- rule, while every row of this file is war-coast-only.
	_grug_spawn_zones = {"war_coast"},
	-- Level: engine-owned (levels.lua); the war-coast cap of
	-- grug_core.mob_level_at keeps it at 20-30.

	-- Flier (gull.lua header).
	fly = true,
	fly_in = "air",
	jump = false,
	fall_damage = 0,
	fear_height = 0,

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	stepheight = 1.1,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_gull.b3d",
	textures = {{"grug_mobs_crow.png"}},
	-- wp6_model_notes §3.2, identical to gull.lua.
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.2, 0, -0.2, 0.2, 0.4, 0.2},
	makes_footstep_sound = false,

	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 110, walk_end = 130, walk_speed = 40,
		run_start = 140, run_end = 160, run_speed = 50,
		fly_start = 140, fly_end = 160, fly_speed = 40,
	},

	-- §3.1 war-coast row: "Carrion Crow (flees, feather)".
	drops = {
		{name = "grug_mobs:feather", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:carrion_crow", crow)

-- §4 has NO carrion-crow row — these numbers are DERIVED from the Gull row,
-- the only other flying critter in the catalog (interval 20 / chance 2500 /
-- aoc 2 / min light 10), exactly as parrot.lua did for the jungle edge.
-- T10's calibration pass owns them.
--
-- Nodes: all six settled tops of §1.3 — the war coast wears whichever
-- settled biome its band has, so a crow must be able to appear on any of
-- them. blight_dirt is included here (unlike zombie.lua/skeleton_archer.lua,
-- where it carries its own row): this mob has exactly one row, so there is
-- no second ABM that could double up on it.
mobs:spawn({
	name = "grug_mobs:carrion_crow",
	-- ALL land tops, not just the settled ones. The war coast is not its own
	-- biome, so whatever the local band's voronoi produces at |z| 100..300 is
	-- what a war-coast traveller walks on — and that includes wild patches
	-- (§1.4). §4's "settled tops, blight_dirt" left grug_deep_forest,
	-- grug_bone_forest, grug_crags(+snowy), grug_badlands and grug_swamp
	-- war-coast strips without ANY daytime mob. This family is war_coast-
	-- exclusive by _grug_spawn_zones, so a wider node list cannot leak into
	-- another cell — the zone does all of the gating either way.
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:blight_dirt", -- grug_blight
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"grug_nodes:dirt_with_bone_litter", -- grug_bone_forest
		"grug_nodes:mesa_clay", -- grug_badlands
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
		"grug_nodes:mud", -- grug_swamp
		-- No `default:sand`: the war-coast beach is the Gull's day slot
		-- (gull.lua, zones strait/war_coast/coast) and already covered.
	},
	min_light = 10,
	interval = 20,
	chance = 2500,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
})
