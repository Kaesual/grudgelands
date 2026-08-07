-- Boar: aggressive daytime mob of the safe core and inner ring (WoW
-- memory: the first quest mobs). Weak, but combative.

grug_mobs.register_mob("grug_mobs:boar", {
	description = "Boar",
	type = "monster",
	_grug_spawn_zones = {"core", "inner"},
	-- HP/damage/XP and armor come from the level engine (levels.lua):
	-- core/inner ring means level 1-10, i.e. 20-65 HP, 2-6 damage.

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive-mob speed (combat_stats.md §3): faster than the player's
	-- 4.0, so running away is a decision, not a reflex.
	run_velocity = 4.4,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	-- CLIFF RULE for aggressive ground mobs (decided in T10; every aggressive
	-- family in grug_mobs points back here, critters keep 3).
	--
	-- fear_height is BOTH the drop a mob refuses to walk off (is_at_cliff,
	-- api.lua:931) and — whenever it is non-zero — the max_drop handed to
	-- core.find_path (api.lua smart_mobs). At 4 a chaser stops dead at any
	-- ledge a player can simply hop down, which is the cheapest terrain
	-- exploit there is and exactly what AGENTS.md "Mobs" forbids ("dangerous
	-- mobs must not fail at terrain, otherwise they are not dangerous").
	-- 6 is the free value: mobs_redo charges fall damage only above SIX nodes
	-- (api.lua:2476, `if d > 6 then damage = d - 6`), so a chaser now follows
	-- every drop that costs a player HP while costing itself nothing, and it
	-- still refuses the deep falls that would hurt. It also lengthens the
	-- downward ray of is_at_cliff, so lava/danger detection below a ledge gets
	-- STRICTLY better. Not raised to 8: that would trade real HP for two more
	-- nodes of reach and start dropping mobs into pits they cannot climb out
	-- of (stepheight 1.1 is the only way back up).
	fear_height = 6,
	view_range = 10, -- starter mob at the village belt: sees you at melee range

	visual = "mesh",
	mesh = "grug_mobs_boar.b3d",
	textures = {
		{"grug_mobs_boar.png^[multiply:#9a7a5a", "grug_mobs_blank.png"},
	},
	-- MESH SCALE RULE (decided in T5, docs/research/assets/wp6_model_notes.md
	-- §0.1): visual_size is whatever makes the RENDERED mesh match its own
	-- collisionbox — in practice the upstream def's value. The mesh measures
	-- 8.0 model units = 0.80 nodes at size 1, which is the 0.86 box below, so
	-- the correct value is 1. The shipped 2.5 rendered a 2-node boar around a
	-- 0.86-node hitbox (WP1 leftover, flagged by the model notes); every mob
	-- registered from T5 on follows the rule.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.86, 0.45},
	makes_footstep_sound = true,

	animation = {
		stand_start = 0, stand_end = 0,
		walk_start = 0, walk_end = 40, walk_speed = 60,
		run_start = 0, run_end = 40, run_speed = 90,
		punch_start = 0, punch_end = 40, punch_speed = 90,
	},

	-- Boar table (biomes_mobs.md §3.1): meat 1/1 x1-2, light leather 1/2
	-- [leather], tusk 1/3. Shared verbatim by the two tint variants
	-- (boar_variants.lua) — §3.2 makes the boar table identical everywhere.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:light_leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:boar_tusk", chance = 3, min = 1, max = 2},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
})

-- Spawns on the signature top nodes of the SETTLED biomes (biomes.lua,
-- docs/design/biomes_mobs.md §4: the whitelist IS the biome gating), so
-- every low-level area of both continents has day mobs. The zone gating
-- above keeps boars in the core and inner ring, out of the higher-level
-- outer ring and coasts.
--
-- FOUR tops, not six: the blight (Plague Boar) and the jungle edge (Jungle
-- Boar) belong to the tint variants in boar_variants.lua now. §4 budgets one
-- row per ENTITY NAME (mobs_redo counts the active-object cap per name), so
-- each of the three boars gets the full interval 20 / chance 1500 / aoc 5 —
-- and no biome ever carries more than one of them.
mobs:spawn({
	name = "grug_mobs:boar",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
	},
	min_light = 10,
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})
