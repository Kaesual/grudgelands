-- Crocodile (docs/design/biomes_mobs.md §3.1, grug_swamp).
--
-- Verb: "ambushes (lurks still/in water, burst on approach)" —
-- grug_mobs.ambusher (verbs.lua) installs the stand/release toggle; the
-- BURST half is the def's own numbers, and the verbs.lua header says so
-- explicitly ("the actual burst is roster-side: small view_range + high
-- run_velocity"). Hence the deliberately short view_range 6 below: the croc
-- lies motionless until something is almost on top of it and only then
-- accelerates to 4.4. A normal 12-16 view_range would turn the ambush into
-- an ordinary charge from across the swamp.
--
-- WATER DECISION (the one deviation from §3.1's speed column "4.4 (5.0 in
-- water)") — read api.lua before "fixing" this:
--   * mobs_redo has exactly ONE amphibious knob, `fly = true` + `fly_in =
--     {water}`, which is what upstream animalworld uses. It is NOT usable
--     for a land+water mob here: follow_flop (api.lua:1931ff) puts a `fly`
--     mob into the "flop" state whenever flight_check() fails, i.e. whenever
--     it is NOT standing in its medium — a water-flying crocodile would flop
--     helplessly on every river bank (api.lua:1936: velocity {0, -5, 0},
--     stand animation, no movement).
--   * A per-medium speed swap would need a custom do_custom tick that reads
--     self.standing_in and rewrites walk/run_velocity — and that collides
--     head-on with the root/slow engine (levels.lua tick_speed_effects owns
--     walk_velocity/run_velocity and restores them from _grug_speed_base).
--     Two owners of the same two fields is exactly the bug class the WP6
--     notes warn about.
--   * MVP therefore: ONE speed, 4.4 on land and in water, plus `floats` so
--     the mob swims at the surface instead of sinking (api.lua:2464). The
--     5.0-in-water bonus is dropped, NOT postponed silently — a later WP can
--     add it once one owner for the speed fields exists.
--
-- The upstream `fly 400-500` swim clip is therefore unused and left out of
-- the animation table below: without `fly = true` mobs_redo never selects it.

local crocodile = {
	description = "Crocodile",
	type = "monster",
	-- §4 row zones: "outer". The swamp is a low-terrain pocket biome of the
	-- outer ring (§1.2 row 13).
	_grug_spawn_zones = {"outer"},
	-- HP/damage/XP/armor: engine-owned (levels.lua). The swamp sits in the
	-- outer ring, so the field gives L25-45 (§1.2 "25-45").

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	-- Solitary ambusher: no pack verb, so no group_attack (§3 "group_attack
	-- per verb"), same reading as eagle.lua/golem.lua.
	group_attack = false,
	pathfinding = 1,

	-- §3.1 speed column: 4.4 (aggressive baseline, §0). See the water note in
	-- the header for the missing 5.0.
	walk_velocity = 1,
	run_velocity = 4.4,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 4,
	-- Ambush range, see the header. grug_mobs.ambusher re-arms the "stand"
	-- order at the same 6 nodes, so seeing a player and bursting coincide.
	view_range = 6,
	-- Explicit although `true` is mobs_redo's own default (api.lua:148): this
	-- is the field that keeps the croc swimming at the surface of a swamp
	-- pool instead of walking along its floor, so it must not be lost in a
	-- later cleanup.
	floats = 1,

	visual = "mesh",
	mesh = "grug_mobs_crocodile.b3d",
	textures = {{"grug_mobs_crocodile.png"}},
	-- Mesh scale rule (boar.lua): 3.65 units high / 38.6 long = 0.36 x 3.86
	-- nodes at size 1 (wp6_model_notes §2.6); upstream uses 1 and the box
	-- below is upstream's. A crocodile is long, not tall — the box only has
	-- to cover the body, the tail may stick out of it.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.6, -0.01, -0.6, 0.6, 0.95, 0.6},
	makes_footstep_sound = true,

	-- wp6_model_notes §2.6: no run range -> run = walk range at a higher
	-- speed (§0.2 rule); `fly` (the swim loop) is unused, see the header.
	animation = {
		speed_normal = 75,
		stand_start = 0, stand_end = 100,
		walk_start = 250, walk_end = 350,
		run_start = 250, run_end = 350, run_speed = 110,
		punch_start = 100, punch_end = 200,
	},

	-- §3.1 swamp row: scaled hide 1/1 [leather], meat, croc tooth 1/3.
	drops = {
		{name = "grug_mobs:scaled_hide", chance = 1, min = 1, max = 1},
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:croc_tooth", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.ambusher(crocodile, {trigger_range = 6})
grug_mobs.register_mob("grug_mobs:crocodile", crocodile)

-- §4 row "Crocodile | mud, water at mud | 20 | 1800 | 3 | any | outer".
--
-- DEVIATION, spelled out: only `mud` is registered as a spawn node, "water
-- at mud" is not. Two reasons, both mechanical:
--   * an ABM's `neighbors` list is an OR set ("at least one of these is
--     adjacent"), so it cannot express "must be next to water" together with
--     anything else — adding {"default:water_source", "air"} would be a
--     no-op, because every walkable top node has air above it;
--   * registering the row on `default:water_source` instead would put a 20 s
--     ABM on every ocean node in the world, which is exactly the candidate-
--     set explosion §4's performance note tells us to avoid.
-- The behaviour the design wants is delivered anyway: `floats` (above) lets
-- the croc swim, and grug_swamp's own pools (grug_mapgen decorations.lua,
-- reed pools on mud) sit inside the mud patch it spawns on.
--
-- "any light" = no min_light/max_light and no day_toggle: 24 h (§3.1).
mobs:spawn({
	name = "grug_mobs:crocodile",
	nodes = {"grug_nodes:mud"}, -- grug_swamp
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
