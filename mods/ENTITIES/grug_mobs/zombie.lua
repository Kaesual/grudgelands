-- Zombie: night mob of the safe core, inner ring and war coast. Tougher
-- and stronger than the boar, burns in daylight.

grug_mobs.register_mob("grug_mobs:zombie", {
	description = "Buried Miner",
	_grug_voice = "undead",
	-- The spawn clock of its only row, the cave row below, which runs around
	-- the clock (light-driven). On the surface the recipes' zombie sub-types
	-- spawn from the spawn regions with their own clocks (Round 81 removed
	-- the base family's surface rows, ruling 6).
	clock = "any",
	type = "monster",
	-- "underground" is the T7 addition: §3.1's cave paragraph reuses Zombie,
	-- Giant Spider and Stone Golem below y -1 with the depth axis supplying
	-- the level.
	-- HP/damage/XP and armor come from the level engine (levels.lua); the
	-- floor keeps the zombie above the boar even in the safe core.
	_grug_min_level = 3,
	-- Undead race passive (world.md §7): the zombie family never attacks an
	-- Undead player on its own, day and night; a zombie the player attacked
	-- fights back. Every zombie sub-type copies this base def.
	_grug_truce_perk = "zombie_truce",
	-- Round 18: ordinary ambient undead share damage-sustained pursuit.

	reach = 3,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive melee speed (combat_stats.md §3).
	run_velocity = 4.6,
	jump = true,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 14,

	visual = "mesh",
	mesh = "grug_mobs_zombie.b3d",
	-- TWO material slots, in mesh-buffer order: 1 = armour overlay, 2 = skin
	-- (upstream mobs_mc/zombie.lua passes mobs_mc_empty.png first, same as
	-- boar.lua's saddle slot). A one-entry list put the skin on the armour.
	textures = {{"grug_mobs_blank.png", "grug_mobs_zombie.png"}},
	-- Mesh scale rule (see boar.lua): the mesh measures 18.0 model units =
	-- 1.80 nodes at size 1, i.e. exactly the 1.89 box below. The shipped 3
	-- drew a 5.4-node zombie around a player-sized hitbox.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.89, 0.3},
	-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
	selectionbox = {-0.45, -0.05, -0.3, 0.45, 1.8, 0.65, rotate = true},
	makes_footstep_sound = true,

	animation = {
		stand_start = 40, stand_end = 49, stand_speed = 2,
		walk_start = 0, walk_end = 39, walk_speed = 25,
		run_start = 0, run_end = 39, run_speed = 50,
		punch_start = 50, punch_end = 59, punch_speed = 20,
	},

	-- Zombie table (biomes_mobs.md §3.1): flesh 1/1, linen scrap 1/2,
	-- Iron Bar 1/10. The old upstream Steel Ingot represented furnace-smelted
	-- iron and migrated to this canonical processed id in WP43.
	drops = {
		{name = "grug_mobs:zombie_flesh", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "grug_materials:iron_bar", chance = 10, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- Burns on the surface during the day (classic night-mob feel).
	light_damage = 2,
	light_damage_min = 14,
	light_damage_max = 15,
})

--
-- CAVE ROW (WP6/T7) — biomes_mobs.md §3.1 "Caves (depth axis, WP6 note):
-- reuse Zombie, Giant Spider, Stone Golem with `underground` zone gating;
-- levels come from the depth term of `mob_level_at`. No cave-only families
-- in this catalog."
--
-- This block is the canonical comment for all three cave rows; spider.lua
-- and golem.lua point back here.
--
-- LEVEL: nothing to configure. grug_zones.mob_level_at takes
-- max(surface field, 1 + floor(-y/20)) for every y < 0 (combat_stats.md §3
-- "depth axis", grug_core/init.lua), so a zombie at y -400 comes out at L21
-- and one at y -1200 at L60 — the same engine-owned path every surface mob
-- uses, no _grug_fixed_level, no per-row tuning.
--
-- HEIGHTS: min_height -31000 / max_height -1 (grug_mobs.UNDERGROUND_TOP,
-- Round 46; -40 before) with the ZONE gate doing the real work. The two are
-- consistent, but read api.lua before touching them: mobs_redo calls
-- mobs:spawn_abm_check with the ABM's NODE position (api.lua spawn_action) and
-- only THEN moves the spawn position one node up (api.lua spawn_action), and the
-- min/max height comparison happens on that raised position
-- (api.lua spawn_action). So max_height -1 admits node y <= -2, and
-- spawn_policy.lua returns "underground" for exactly y < -1 — every node
-- this row can match is inside the zone, and nothing is silently thrown away
-- at the boundary. The row's on_spawn gets the underground sight and elite
-- roll (spawn_policy.lua prepare_spawn_row, underground_spawned).
--
-- WHY THE CAVE ROWS MATTER: every surface row in the roster carries
-- min_height 0 (§4), so before T7 the whole underground was empty. These
-- three rows are what makes the depth axis real content instead of a number
-- in a formula.
--
-- PERFORMANCE: `default:stone` sounds like "every node in the world", but
-- the ABM's implicit neighbour list is {"air"} (mobs_redo's default,
-- api.lua mobs:spawn), so only stone with air next to it — cave walls, ceilings
-- and floors — is ever a candidate. Solid rock costs nothing.
--
-- WHY THE mod.conf DEPENDENCY ON grug_materials IS *NOT* A LOAD-ORDER FIX:
-- an ABM's `nodenames` are resolved lazily, not at registration. The engine
-- rebuilds ABMHandler once per ABM interval inside ServerEnvironment::step
-- (serverenvironment.cpp:1024) and only there turns the strings into content
-- ids (blockmodifier.cpp:92, NodeDefManager::getIds) — long after every mod
-- has loaded. `group:grug_stratum` would therefore resolve with no dependency
-- at all. It is declared anyway, for the same reason grug_nodes already is:
-- it documents that these three cave rows are worthless without the mod that
-- defines the group, and it guarantees that mod is enabled.
--
mobs:spawn({
	name = "grug_mobs:zombie",
	-- group:grug_stratum is the tier-2..6 rock introduced by WP25; below -100
	-- no default:stone survives the mapgen strata, so on its own the node name
	-- would confine this row to -41..-100 and kill the whole depth axis. The
	-- performance argument above holds unchanged: the group is still only
	-- matched where the implicit {"air"} neighbour makes it a cave wall.
	nodes = {"default:stone", "group:grug_stratum"},
	-- Round 46 ruling 15: every underground row spawns up to light 7 (5
	-- before), so a torch (light 12) keeps only about five nodes clear.
	max_light = 7,
	-- No day_toggle: it is always night down there, and the light gate above
	-- already does the work. Setting day_toggle = false would additionally
	-- forbid cave spawns during the surface day, which is not the intent.
	interval = 20,
	chance = 1600,
	active_object_count = 4,
	min_height = -31000,
	max_height = -1,
})
