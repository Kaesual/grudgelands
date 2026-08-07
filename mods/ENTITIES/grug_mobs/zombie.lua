-- Zombie: night mob of the safe core, inner ring and war coast. Tougher
-- and stronger than the boar, burns in daylight.

grug_mobs.register_mob("grug_mobs:zombie", {
	description = "Zombie",
	type = "monster",
	-- "underground" is the T7 addition: §3.1's cave paragraph reuses Zombie,
	-- Giant Spider and Stone Golem below y -40 with the depth axis supplying
	-- the level. _grug_spawn_zones is registered per mob NAME (init.lua), so
	-- the cave row at the end of this file cannot add it per row — without
	-- the zone here spawn_abm_check would reject every cave spawn.
	_grug_spawn_zones = {"core", "inner", "war_coast", "underground"},
	-- HP/damage/XP and armor come from the level engine (levels.lua); the
	-- floor keeps the zombie above the boar even in the safe core.
	_grug_min_level = 3,
	-- Undead race passive (world.md §7): ignored at night unless provoked.
	_grug_night_truce_perk = "zombie_night_truce",
	-- Behavior verb (combat_stats.md §3): "zombies never leash" — once
	-- pulled it follows forever, never resets its threat and never heals up.
	-- Running away does not work; you have to lose it or kill it.
	_grug_no_leash = true,

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive-mob speed (combat_stats.md §3), a notch under the boar's
	-- 4.4 but still above the player's 4.0.
	run_velocity = 4.2,
	jump = true,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 14,

	visual = "mesh",
	mesh = "grug_mobs_zombie.b3d",
	textures = {{"grug_mobs_zombie.png"}},
	-- Mesh scale rule (see boar.lua): the mesh measures 18.0 model units =
	-- 1.80 nodes at size 1, i.e. exactly the 1.89 box below. The shipped 3
	-- drew a 5.4-node zombie around a player-sized hitbox.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.89, 0.3},
	makes_footstep_sound = true,

	animation = {
		stand_start = 40, stand_end = 49, stand_speed = 2,
		walk_start = 0, walk_end = 39, walk_speed = 25,
		run_start = 0, run_end = 39, run_speed = 50,
		punch_start = 50, punch_end = 59, punch_speed = 20,
	},

	-- Zombie table (biomes_mobs.md §3.1): flesh 1/1, linen scrap 1/2,
	-- steel ingot 1/10.
	drops = {
		{name = "grug_mobs:zombie_flesh", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
		{name = "default:steel_ingot", chance = 10, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	-- Burns on the surface during the day (classic night-mob feel).
	light_damage = 2,
	light_damage_min = 14,
	light_damage_max = 15,
})

-- At night on the settled biome tops (whitelist matches biomes.lua — see the
-- boar note); zone-gated like the boar. Bare stone is gone from the list: no
-- land biome has a stone surface any more.
--
-- §4 calibration row: interval 20 / chance 1600 / aoc 4, max light 5.
-- FIVE tops, not six: grug_nodes:blight_dirt has its own 24 h row below and
-- would otherwise be covered by two ABMs at night.
mobs:spawn({
	name = "grug_mobs:zombie",
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
	chance = 1600,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})

-- The blight identity (biomes_mobs.md §3.1 "in grug_blight: 24 h — Undead
-- identity", §4 light column "blight: any"): on grug_nodes:blight_dirt the
-- zombie spawns around the clock, so NO light gate and NO day_toggle.
-- Everything else is the same row — same aoc budget (mobs_redo counts the
-- cap per entity name, so both rows share it), same zone gating via
-- _grug_spawn_zones above (core, inner, war_coast).
--
-- The def's daylight burn would make a 24 h row pointless (spawn at noon,
-- die at noon), so a blight zombie is exempted from it: mobs_redo reads
-- `self.light_damage` per entity on every environment tick (api.lua:1056),
-- and a plain number field persists in staticdata — so this survives
-- unload/reload with the mob and touches nobody else's zombie.
mobs:spawn({
	name = "grug_mobs:zombie",
	nodes = {"grug_nodes:blight_dirt"}, -- grug_blight
	interval = 20,
	chance = 1600,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
	-- mobs_redo calls this as on_spawn(luaentity, pos) (api.lua:3686); the
	-- entity is nil if core.add_entity failed.
	on_spawn = function(ent)
		if ent then
			ent.light_damage = 0
		end
	end,
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
-- LEVEL: nothing to configure. grug_core.mob_level_at takes
-- max(surface field, 1 + floor(-y/20)) for every y < 0 (combat_stats.md §3
-- "depth axis", grug_core/init.lua), so a zombie at y -400 comes out at L21
-- and one at y -1200 at L60 — the same engine-owned path every surface mob
-- uses, no _grug_fixed_level, no per-row tuning.
--
-- HEIGHTS: min_height -31000 / max_height -40 with the ZONE gate doing the
-- real work. The two are consistent, but read api.lua before touching them:
-- mobs_redo calls mobs:spawn_abm_check with the ABM's NODE position
-- (api.lua:3573) and only THEN moves the spawn position one node up
-- (api.lua:3616), and the min/max height comparison happens on that raised
-- position (api.lua:3618). So max_height -40 admits node y <= -41, and
-- grug_core.zone_at returns "underground" for exactly y < -40 — every node
-- this row can match is inside the zone, and nothing is silently thrown away
-- at the boundary.
--
-- WHY THE CAVE ROWS MATTER: every surface row in the roster carries
-- min_height 0 (§4), so before T7 the whole underground was empty. These
-- three rows are what makes the depth axis real content instead of a number
-- in a formula.
--
-- PERFORMANCE: `default:stone` sounds like "every node in the world", but
-- the ABM's implicit neighbour list is {"air"} (mobs_redo's default,
-- api.lua:3729), so only stone with air next to it — cave walls, ceilings
-- and floors — is ever a candidate. Solid rock costs nothing.
--
mobs:spawn({
	name = "grug_mobs:zombie",
	nodes = {"default:stone"},
	max_light = 5,
	-- No day_toggle: it is always night down there, and the light gate above
	-- already does the work. Setting day_toggle = false would additionally
	-- forbid cave spawns during the surface day, which is not the intent.
	interval = 20,
	chance = 1600,
	active_object_count = 4,
	min_height = -31000,
	max_height = -40,
})
