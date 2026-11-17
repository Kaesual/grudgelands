-- Boar: neutral daytime mob of the safe core and inner ring. It does not
-- initiate combat, but retaliates through the central disposition policy.

local boar = {
	description = "Boar",
	_grug_voice = "boar",
	clock = "day",
	type = "monster",
	-- HP/damage/XP and armor come from the level engine (levels.lua):
	-- core/inner ring means level 1-10, i.e. 20-65 HP, 2-6 damage.

	reach = 3,
	attack_type = "dogfight",
	attack_players = false,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	-- Aggressive-mob speed (combat_stats.md §3): faster than the player's
	-- 4.0, so running away is a decision, not a reflex.
	run_velocity = 4.6,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	-- CLIFF RULE for aggressive ground mobs (decided in T10; every aggressive
	-- family in grug_mobs points back here, critters keep 3).
	--
	-- fear_height is BOTH the drop a mob refuses to walk off (is_at_cliff,
	-- api.lua is_at_cliff) and — whenever it is non-zero — the max_drop handed to
	-- core.find_path (mobs/grug_nav.lua nav.body since Round 42). At 4 a
	-- chaser stops dead at any ledge a player can simply hop down, which is
	-- the cheapest terrain exploit there is and exactly what module-guide.md
	-- forbids ("dangerous mobs must not fail at terrain, otherwise they are
	-- not dangerous").
	-- 6 is the free value: mobs_redo charges fall damage only above SIX nodes
	-- (api.lua falling, `if d > 6 then damage = d - 6`), so a chaser now follows
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
	-- Targeting is deliberately more forgiving than physical movement. The
	-- mesh's long axis follows yaw; `rotate` keeps this padded box on it.
	selectionbox = {-0.62, -0.06, -0.76, 0.62, 1.04, 0.76, rotate = true},
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
		{name = "grug_mobs:boar_tusk", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

-- Charges (biomes_mobs.md §3.1, the Boar's behavior verb): a horizontal rush
-- re-using the stalker impulse — a boar at mid-range lunges instead of jogging
-- the last ten metres. Same helper as the Panther's pounce (verbs.lua; the
-- name stays "stalker", it is the generic pounce impulse), tuned flat and
-- long: up = 1 is a shoulder-charge, not a leap, and 4..10 m is exactly the
-- window between "already biting you" and "still closing".
-- The three boar defs share these numbers; boar_variants.lua repeats the call
-- for the two tints because §3.2 keeps the family identical everywhere.
grug_mobs.stalker(boar, {min_dist = 4, max_dist = 10, cooldown = 8,
	speed = 8, up = 1})

grug_mobs.register_mob("grug_mobs:boar", boar)
