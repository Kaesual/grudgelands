-- Land Guard: solitary T6 elite. The elite tier supplies its telegraphed slam.

local guard = {
	description = "Bedrock Sentinel", clock = "any", type = "monster",
	_grug_voice = "giant",
	_grug_tier = "elite", _grug_spawn_domains = {"underground"},
	attack_type = "dogfight", attack_players = true, group_attack = false,
	reach = 3, pathfinding = 1, walk_velocity = 1.5, run_velocity = 4.6,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 8,
	view_range = 14,
	visual = "mesh", mesh = "grug_mobs_dungeon_master.b3d", glow = 2,
	textures = {{"grug_mobs_land_guard.png"},
		{"grug_mobs_land_guard2.png"}, {"grug_mobs_land_guard3.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -1.01, -0.5, 0.5, 1.6, 0.5},
	-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
	selectionbox = {-0.9, -1.05, -0.5, 0.9, 1.7, 0.65, rotate = true},
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 19, stand_speed = 15,
		walk_start = 20, walk_end = 35, walk_speed = 15,
		run_start = 20, run_end = 35, run_speed = 40,
		punch_start = 36, punch_end = 48, punch_speed = 20,
	},
	drops = {
		{name = "grug_mobs:heavy_leather", chance = 2, min = 1, max = 2},
		{name = "grug_materials:rough_diamond", chance = 4, min = 1, max = 1},
	},
	water_damage = 0, lava_damage = 6, light_damage = 0,
}

-- Duewarden (Round 72): the boss of The Last Mint, the level 60 Expedition
-- (docs/planning/round72-last-mint.md), on the Bedrock Sentinel's body, melee and
-- signalled frontal slam (the elite tier's): no adds, no phases, no new look, no spawn
-- row. grug_expeditions places it by its template's boss marker, as an elite at the
-- run's level; only the HP factor sets it apart (tools/r72_mint/balance.py). It stands
-- before the press until someone comes, and drops nothing: the reward room pays. Copied
-- before the Sentinel's registration, which writes into its table.
local duewarden = table.copy(guard)
duewarden.description = "Duewarden"
duewarden._grug_hp_scale = 14
duewarden.walk_chance = 0
duewarden.drops = {}

grug_mobs.register_mob("grug_mobs:land_guard", guard)
grug_mobs.register_mob("grug_mobs:duewarden", duewarden)
-- No spawn row since Round 46 (lane DP, WP audit E4): the Bedrock Sentinel
-- comes only with the depth pulse below y -1000 (depth_pulse.lua).
