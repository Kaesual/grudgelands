-- Mirefolk (docs/design/biomes_mobs.md §3.1, grug_swamp row: "Mirefolk
-- (fish-folk humanoid, camps at swamp pools; the 'murloc memory') | swarms
-- (camp group aggro, all rush at once) | 24 h | 4.4 | linen cloth 1/2;
-- fish 1/1; shiny scale 1/4").
--
-- NO mobs:spawn ROW, same as bandit.lua: §4 puts this family on the camp
-- node timer ("Bandits / Mirefolk | **no ABM**"). WP13 places mirefolk camps
-- at swamp pools; camps.lua owns the respawn loop.
--
-- MESH: `character.b3d` by bare file name — the media namespace is flat, see
-- the long note in bandit.lua. The skin is our own CC0 work
-- (grug_mobs_mirefolk.png, LICENSE-media.md §6).
--
-- Verb "swarms": grug_mobs.camp_swarm (verbs.lua), installed BEFORE
-- register_mob per the verbs.lua contract.

local mirefolk = {
	description = "Mirefolk",
	type = "monster",
	-- No _grug_spawn_zones — no spawn ABM to gate (bandit.lua explains).
	-- HP/damage/XP/armor: engine-owned (levels.lua) from the camp position;
	-- the swamp sits in the outer ring, so L25-45 (§1.2 row 13).

	-- Camp anchored (§4 "anchored to camp"), same 25 nodes as the bandit:
	-- a mirefolk defends its pool, it does not emigrate.
	_grug_leash_range = 25,

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	-- mobs_redo's own group alert stays ON as the short-range half of the
	-- swarm (it reacts to being PUNCHED, within view_range); camp_swarm adds
	-- the design's long half — one acquisition pulls the whole camp within
	-- 20 m. The two do not fight: both end in do_attack on the same target.
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 4.4, -- aggressive-mob speed (§0)
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 12,

	visual = "mesh",
	mesh = "character.b3d",
	textures = {{"grug_mobs_mirefolk.png"}},
	-- "character.b3d small scale" (§3.1 model column). wp6_model_notes §5
	-- suggests ~0.8; 0.85 keeps the fish-folk clearly shorter than a player
	-- (1.70 -> 1.45 nodes) without shrinking it into critter territory. The
	-- collisionbox is the player box scaled by the SAME factor, so mesh and
	-- hitbox stay in sync (the mesh scale rule of boar.lua).
	visual_size = {x = 0.85, y = 0.85},
	collisionbox = {-0.255, 0.0, -0.255, 0.255, 1.445, 0.255},
	makes_footstep_sound = true,

	-- Frame ranges of character.b3d (wp6_model_notes §5), identical to
	-- bandit.lua.
	animation = {
		stand_start = 0, stand_end = 79, stand_speed = 30,
		walk_start = 168, walk_end = 187, walk_speed = 30,
		run_start = 168, run_end = 187, run_speed = 45,
		punch_start = 189, punch_end = 198, punch_speed = 30,
	},

	-- §3.1 swamp row. "fish" is grug_mobs:raw_fish (items.lua): mobs_redo
	-- ships meat but no fish, so §6's "meat/fish everywhere" needed one new
	-- item — registered as food, not as a crafting material.
	drops = {
		{name = "grug_mobs:linen_cloth", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:raw_fish", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:shiny_scale", chance = 4, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

-- Verb BEFORE register_mob (verbs.lua contract).
grug_mobs.camp_swarm(mirefolk, {range = 20})
grug_mobs.register_mob("grug_mobs:mirefolk", mirefolk)
