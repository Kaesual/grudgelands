-- Carrion Crow (docs/design/biomes_mobs.md §3.1, war-coast row: "plus
-- Skeleton Raider (…) and Carrion Crow (flees, feather)").
--
-- DELIBERATELY NOT A CRITTER (§3.0, decided 2026-08-08). It shares the gull's
-- mesh and used to share its whole reading, but it carries two jobs no 1 HP
-- scenery animal can: it is the last plain-FEATHER source that is not a bird
-- of prey, and it is the ENTIRE daytime population of the war coast
-- (wp6_spawn_budget.md §2.2 — every war-coast cell is 2 by day, and that 2 is
-- this mob). So it becomes PASSIVE PREY instead: level from the field
-- (mob_level_at caps the war coast at 20-30), HP and XP from the formulas, no
-- aggro on sight, fights back when attacked. verbs.lua's passive_prey carries
-- the mobs_redo reasoning.
--
-- Three zero-cost consequences of being prey rather than scenery, all decided
-- in §3.0 and all applied below: it is drawn at visual_size 14 instead of 10
-- (~1.0 nodes tall — a target you can see and click), its collisionbox scales
-- with that by the same 1.4, and `punch` is aliased onto the fly clip so the
-- retaliation reads. No new asset, no new spawn row, no budget change.
--
-- Read gull.lua's header for the flight decision and the beach/war-coast
-- geography note. The two are deliberately NOT one def factory in one file:
-- they are different families in different biome groups of §3.1 (beach/strait
-- vs. war coast), they are now different behaviour classes of §3.0, and they
-- only happen to share an animalia mesh (wp6_model_notes §3.2:
-- "grug_mobs_gull.b3d … also serves the Carrion Crow").

local crow = {
	description = "Carrion Crow",
	type = "animal",
	-- The war coast is NOT its own biome (§1.2 / §8.1): it uses the local
	-- band's settled biome plus a battlefield decoration set. So there is no
	-- signature node to spawn on that would confine this mob — the ZONE does
	-- all of the gating, and the node list below is simply "all six settled
	-- tops". Unlike skeleton_archer.lua no _grug_spawn_check is needed: that
	-- family also spawns in the outer ring and therefore needs a per-ROW
	-- rule, while every row of this file is war-coast-only.
	_grug_spawn_domains = {"contested"},
	-- Level: engine-owned (levels.lua); the war-coast cap of
	-- grug_zones.mob_level_at keeps it at 20-30.

	-- Flier (gull.lua header). fall_damage stays at mobs_redo's default: prey
	-- is not a critter, and a flier's falling() bails out before the fall
	-- check anyway (api.lua:2594).
	-- `pathfinding` deliberately UNSET, unlike the four ground prey mobs that
	-- got it in WP36 (stag.lua): core.find_path is a ground search, and a
	-- flier answers terrain by flying over it — the same rule eagle.lua,
	-- gull.lua, parrot.lua and the kraken already follow.
	fly = true,
	fly_in = "air",
	jump = false,
	fear_height = 0,

	walk_velocity = 1.5,
	run_velocity = 3.4, -- §0's 3.4 line
	stepheight = 1.1,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_gull.b3d",
	textures = {{"grug_mobs_crow.png"}},
	-- NO LONGER identical to gull.lua (§3.0): the mesh is 0.73 model units
	-- tall, i.e. 0.073 nodes at visual_size 1 (wp6_model_notes §3.2's 1/10
	-- animalia export), so the gull's 10 renders a 0.73-node bird. A prey
	-- animal you are meant to hunt for its feather has to be findable and
	-- clickable, hence 14 = ~1.02 nodes tall, and the box is scaled by the
	-- same 1.4 so hitbox and mesh keep agreeing (0.4 -> 0.6 high, 0.2 -> 0.3
	-- wide). Zero asset cost: the same mesh and the same texture.
	visual_size = {x = 14, y = 14},
	collisionbox = {-0.3, 0, -0.3, 0.3, 0.6, 0.3},
	makes_footstep_sound = false,

	-- Frames verified against grug_mobs_gull.b3d itself, not against a def:
	-- 12 keyed joints, 1920 keys, real range 1..160 (LICENSE-media.md §8).
	-- `punch` is ALIASED onto the fly clip (§3.0's third crow change): the
	-- mesh has no attack animation, and a retaliating bird flapping at you
	-- reads better than one frozen mid-glide. Aliasing costs nothing — §0.2
	-- of wp6_model_notes is the same rule the eagle and the parrot follow.
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 110, walk_end = 130, walk_speed = 40,
		run_start = 140, run_end = 160, run_speed = 50,
		fly_start = 140, fly_end = 160, fly_speed = 40,
		punch_start = 140, punch_end = 160, punch_speed = 50,
	},

	-- §3.1 war-coast row: "Carrion Crow (flees, feather)". The feather SURVIVES
	-- here — §3.0/§6 move it off the CRITTERS (gull, parrot), and this mob is
	-- prey, not a critter. It is what makes the war coast worth walking by day.
	drops = {
		{name = "grug_mobs:feather", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

-- Verb before registration (verbs.lua contract): passive = false,
-- attack_players/attack_npcs = false, runaway = false.
grug_mobs.passive_prey(crow)

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
	-- exclusive by the common named-zone `war` palette; the additional
	-- contested-domain check authenticates the PvP status. The wider node list
	-- therefore cannot leak into another named zone.
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle (WP36 top)
		"grug_nodes:blight_dirt", -- grug_blight
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"grug_nodes:dirt_with_bone_litter", -- grug_bone_forest
		"grug_nodes:mesa_clay", -- grug_badlands
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
		"grug_nodes:mud", -- grug_swamp
		-- No `default:sand`: every authenticated grug_beach cell is the Gull's
		-- day slot and is already covered.
	},
	min_light = 10,
	interval = 20,
	chance = 2500,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
})
