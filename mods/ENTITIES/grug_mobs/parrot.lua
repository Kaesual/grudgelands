-- Parrot (docs/design/biomes_mobs.md §3.1, jungle group: "Parrot —
-- jungle_edge critter | flees | day | 3.4 | feather 1/1; meat 1/2").
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua, no helper from verbs.lua.
--
-- FLIGHT: `fly = true` + `fly_in = "air"`, the same decision eagle.lua
-- documents in full (falling() bails out for fly mobs so the bird hovers
-- instead of sinking; flight_check() passes because a bird always stands in
-- air; fear_height/do_jump are inert). wp6_model_notes §1.2 asks for exactly
-- this and for mapping walk/run onto the fly range, because the upstream walk
-- clip is a marked placeholder. `pathfinding` stays unset: core.find_path
-- returns a WALKING path, which is not how this mob moves (kraken.lua, our
-- other fly mob, omits it for the same reason) — and a fleeing critter takes
-- the straight line away from the threat anyway (rabbit.lua).

local parrot = {
	description = "Parrot",
	type = "animal",
	passive = true,
	runaway = true,
	-- §4 has NO parrot row. §3.1 files it as the jungle_edge critter, and
	-- grug_jungle_edge is the Troll SETTLED biome (core + inner, §1.2), so
	-- the ring gate is derived from that: core + inner, exactly like the
	-- other settled critters (rabbit.lua). WP6/T10 calibrates the numbers.
	_grug_spawn_zones = {"core", "inner"},
	-- §3.1 puts the jungle_edge families "from L10"; a critter has no combat
	-- role, so the floor is left off here (rabbit.lua carries none either)
	-- and the field decides.

	-- Flier (see the header): floats/fall_damage are inert while fly is set
	-- but keep the def honest, as in kraken.lua.
	fly = true,
	fly_in = "air",
	jump = false,
	fall_damage = 0,
	fear_height = 0,

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	stepheight = 1.1,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_parrot.b3d",
	textures = {{"grug_mobs_parrot.png"}},
	-- Mesh scale rule (boar.lua): 3.24 units = 0.32 nodes at size 1, which is
	-- why upstream (VoxeLibre) uses 3 (~0.97 nodes) to match the box below.
	visual_size = {x = 3, y = 3},
	collisionbox = {-0.25, -0.01, -0.25, 0.25, 0.89, 0.25},
	makes_footstep_sound = false,

	-- wp6_model_notes §1.2: the upstream walk range 0-20 is a placeholder
	-- ("TODO: actual walk animation"), so walk and run are aliased onto the
	-- fly loop 60-120 (§0.2 rule). No punch clip (critter).
	animation = {
		stand_start = 0, stand_end = 0, stand_speed = 50,
		walk_start = 60, walk_end = 120, walk_speed = 50,
		run_start = 60, run_end = 120, run_speed = 70,
		fly_start = 60, fly_end = 120, fly_speed = 50,
	},

	drops = {
		{name = "grug_mobs:feather", chance = 1, min = 1, max = 1},
		{name = "mobs:meat_raw", chance = 2, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:parrot", parrot)

-- No §4 row exists for the parrot — these numbers are DERIVED, deliberately
-- conservative, and T10's calibration pass owns them:
--   * nodes: the jungle_edge top (§1.3), same node the other jungle families
--     use; the zone gate above is what confines it to the settled ring.
--   * interval 20 = the table-wide value; chance 2500 and aoc 2 are copied
--     from the §4 Gull row, the only other flying critter in the catalog.
--   * min_light 10: day mob (§3.1).
mobs:spawn({
	name = "grug_mobs:parrot",
	nodes = {"default:dirt_with_rainforest_litter"}, -- grug_jungle_edge
	min_light = 10,
	interval = 20,
	chance = 2500,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
})
