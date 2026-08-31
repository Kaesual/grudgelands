-- Bog Ooze (docs/design/biomes_mobs.md §3.1, grug_swamp).
--
-- Verb: "engulfs (slow tank: touch damage aura)" — grug_mobs.damage_aura
-- (verbs.lua): every second, every player within 2 nodes takes a punch from
-- the ooze, so armor groups, the dodge roll and absorb shields all apply
-- exactly as for a melee swing.
--
-- AURA DAMAGE IS FLAT 2, NOT LEVEL-SCALED. Deliberate MVP simplification and
-- the one place in the roster where a damage number is written by hand: the
-- aura is a passive "do not hug the blob" tax, while the ooze's actual melee
-- IS level-scaled by the engine (levels.lua: damage = 2 + 0.4*L). A level-45
-- swamp ooze therefore hits for 20 in melee and adds 2/s to anyone standing
-- inside it. Making the aura scale too would need the verb to read the live
-- entity's `damage`, which is a verbs.lua change, not a roster change —
-- noted here so it is a decision, not an oversight.

local bog_ooze = {
	description = "Bog Ooze",
	type = "monster",
	-- §4 row zones: "outer" (swamp pockets, §1.2 row 13 -> L25-45).
	-- HP/damage/XP/armor: engine-owned (levels.lua).

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	-- A blob does not organise: no pack verb, no group_attack (§3
	-- "group_attack per verb").
	group_attack = false,
	pathfinding = 1,

	-- §3.1 speed column: 2.6. SPEC EXCEPTION against the 4.4 aggressive
	-- baseline of §0, noted here on purpose — the second one in the game
	-- after the golem's 3.0 (golem.lua). It is the whole point of the family:
	-- a "slow tank" whose damage comes from standing next to it, so walking
	-- away must work. No _grug_soft_deaggro opt-out either — the 25 m rule
	-- dropping a chaser to walk 1 is the intended "you got away".
	walk_velocity = 1,
	run_velocity = 2.6,
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 10,

	visual = "mesh",
	mesh = "grug_mobs_bog_ooze.b3d",
	-- TWO texture slots (wp6_model_notes §0.3: 1 = inner cube, 2 = outer
	-- shell) — upstream passes the same texture twice, and a missing slot
	-- would render untextured.
	textures = {{"grug_mobs_bog_ooze.png", "grug_mobs_bog_ooze.png"}},
	-- Mesh scale rule (boar.lua): 1.52 units = 0.15 nodes at size 1, so
	-- upstream's 12.5 (~1.9 nodes) is the value that matches the big-slime
	-- box below (wp6_model_notes §1.6). Upstream's `rotate = true` box flag
	-- is an mcl_mobs extension and is dropped — mobs_redo does not read it.
	visual_size = {x = 12.5, y = 12.5},
	collisionbox = {-1.02, -0.01, -1.02, 1.02, 2.03, 1.02},
	makes_footstep_sound = false,

	-- wp6_model_notes §1.6: one clip only; no punch range -> punch = walk
	-- range (§0.2 rule).
	animation = {
		speed_normal = 17,
		stand_start = 1, stand_end = 20,
		walk_start = 1, walk_end = 20,
		run_start = 1, run_end = 20,
		punch_start = 1, punch_end = 20,
	},

	-- §3.1 swamp row: "slime gel 1/1 x1-2 (alchemy reagent); vendor trash".
	-- The vendor trash is linen_scrap (items.lua, price 1) — the swamp has no
	-- own trash item and inventing one for a single mob is not worth an id.
	drops = {
		{name = "grug_mobs:slime_gel", chance = 1, min = 1, max = 2},
		{name = "grug_mobs:linen_scrap", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

-- Verb BEFORE register_mob (verbs.lua contract).
grug_mobs.damage_aura(bog_ooze, {radius = 2, damage = 2})
grug_mobs.register_mob("grug_mobs:bog_ooze", bog_ooze)

-- §4 row "Bog Ooze | mud | 20 | 2000 | 3 | any | outer".
-- "any light" = no min_light/max_light and no day_toggle: 24 h (§3.1).
mobs:spawn({
	name = "grug_mobs:bog_ooze",
	nodes = {"grug_nodes:mud"}, -- grug_swamp
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
