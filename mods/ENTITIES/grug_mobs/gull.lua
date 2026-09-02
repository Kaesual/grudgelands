-- Gull (docs/design/biomes_mobs.md §3.1, "grug_beach / strait": flees, day,
-- 3.4 fly, feather 1/1).
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua/parrot.lua, no helper from verbs.lua.
--
-- FLIGHT: `fly = true` + `fly_in = "air"`, the decision eagle.lua documents
-- in full (falling() bails out for fly mobs so the bird hovers instead of
-- sinking; flight_check() passes because a bird always stands in air;
-- fear_height/do_jump are inert). `pathfinding` stays unset — core.find_path
-- returns a WALKING path, which is not how this mob moves.
--
-- R7 authority: the surface policy authenticates logical biome `grug_beach`
-- directly. The sand node remains the narrower physical habitat, so inland
-- sand or foreign sand cannot enable the bird by itself.

local gull = {
	description = "Gull",
	type = "animal",
	passive = true,
	runaway = true,
	-- The universal beach/strait roster is independent of the named-zone mob
	-- families. Every logical `grug_beach` cell may host this sand-only
	-- critter, including inland lake and river shores authored as that biome.
	-- THE critter tier (levels.lua, biomes_mobs.md §3.0): level 1, 1 HP,
	-- 10 XP flat, no fall damage, never elite or rare, never telegraphs.
	-- This is also what settles the old level question in this file: the
	-- beach roster used to inherit whatever mob_level_at said (5 on the
	-- strait, 20-30 on the war coast, 45-60 on a flank coast), which made one
	-- and the same harmless bird a level-55 nametag. A critter is level 1
	-- everywhere now, by tier.
	_grug_tier = "critter",

	-- Flier (see the header): floats/fall_damage are inert while fly is set
	-- (falling() bails out first). fall_damage is not written here — the
	-- critter tier owns it, as `false` rather than the `0` §3.0 prints (0 is
	-- truthy in Lua; levels.lua header).
	fly = true,
	fly_in = "air",
	jump = false,
	fear_height = 0,

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	stepheight = 1.1,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_gull.b3d",
	textures = {{"grug_mobs_gull.png"}},
	-- Mesh scale rule (boar.lua): 0.72 units = 0.07 nodes at size 1 — animalia
	-- exports at 1/10 scale, so upstream's 10 (~0.72 nodes) is the value that
	-- matches the hitbox below (wp6_model_notes §3.2).
	visual_size = {x = 10, y = 10},
	collisionbox = {-0.2, 0, -0.2, 0.2, 0.4, 0.2},
	makes_footstep_sound = false,

	-- wp6_model_notes §3.2: real stand/walk/fly clips, no punch clip (a
	-- critter needs none). `run` is aliased onto the FLY range exactly as the
	-- note asks — that is the state a fleeing bird is in. Unlike parrot.lua
	-- the `walk` slot keeps its own clip here, because this mesh has a real
	-- walk animation (the parrot's upstream walk range is marked a
	-- placeholder).
	animation = {
		stand_start = 1, stand_end = 100, stand_speed = 30,
		walk_start = 110, walk_end = 130, walk_speed = 40,
		run_start = 140, run_end = 160, run_speed = 50,
		fly_start = 140, fly_end = 160, fly_speed = 40,
	},

	-- FOOD ONLY (§3.1: "meat 1/1 — food only"). The feather moved to the
	-- bird-of-prey table (§3.0/§6, eagle.lua) with the critter rework.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:gull", gull)

-- The historical §4 row supplied these spawn numbers; R7 replaces its radial
-- zone list with the exact logical-biome authority described above.
mobs:spawn({
	name = "grug_mobs:gull",
	nodes = {"default:sand"}, -- grug_beach (and the ocean-mask beach band)
	min_light = 10,
	interval = 20,
	chance = 2500,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
})

--
-- DEFERRED, on purpose: Shore Crab and Reef Lurker
--
-- biomes_mobs.md §8.3 (resolved decision points, 2026-08-06): "Shore Crab
-- deferred until a licensed model is sourced — the strait launches with Gull
-- only", and §7's asset table says the same ("no verified source yet (check
-- marinara / nssm in-repo)"). The Reef Lurker of §3.1 is the coast-zone
-- ELITE variant of that same crab (scale x1.6, armor 80, same table x3), so
-- it falls with it.
--
-- When a model arrives, both belong in this file and both rows already exist
-- in §4:
--   Shore Crab   | sand | 20 | 2200 | 3 | any | strait, war_coast, coast
--   Reef Lurker  | sand | 30 | 8000 | 1 | any | coast
-- Verb: "retaliates (pinches when punched)" — that is native mobs_redo
-- (`type = "animal"`, `passive = false`, no attack_players), no verbs.lua
-- helper needed. The elite is `_grug_tier = "elite"` (golem.lua pattern), not
-- a second texture (wp6_model_notes §0.4).
--
