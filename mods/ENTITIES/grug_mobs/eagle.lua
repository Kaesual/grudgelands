-- Crag Eagle / Vulture (docs/design/biomes_mobs.md §3.1, mountain pair).
-- Verb: "dive-bombs (dogshoot swoop)".
--
-- FLIGHT DECISION (read api.lua before copying this):
--   * `fly = true` + `fly_in = "air"` is supported and is what the kraken
--     already uses (with water instead of air). Three api.lua facts make it
--     safe for an AIR flier:
--       - falling() bails out for fly mobs (api.lua:2458) and nothing else
--         writes acceleration, so the bird hovers instead of sinking;
--       - flight_check() compares self.standing_in against fly_in
--         (api.lua:544); for a bird that node is "air" wherever it is, so it
--         never enters the "flop" state;
--       - fear_height defaults to 0 for fly defs (api.lua:3284) and do_jump
--         returns early (api.lua:1106) — no cliff stops, no jumping.
--   * ATTACK: `dogfight`, NOT dogshoot. In the dogfight branch mobs_redo
--     gives flying mobs their own vertical tracking (api.lua:2253ff): while
--     the target is beyond reach it drives the y velocity toward the
--     target's level — down onto a player on the ground, back up afterwards.
--     Together with the heartland run speed 4.6 that IS the swoop, and it
--     costs no projectile entity, no rock/talon sprite and no
--     dogshoot_switch tuning. A `dogshoot` bird would need an arrow asset we
--     do not have (wp6_model_notes has no talon/feather projectile) for a
--     verb the design describes as a melee dive anyway.
--   * `pathfinding` is deliberately UNSET (the kraken, our other fly mob,
--     does the same): core.find_path returns a WALKING path over the ground,
--     which is not how this mob moves. Its terrain answer is the y tracking
--     above.
--
-- The two continents share one mesh; the Vulture is a baked dark retint
-- (wp6_model_notes §2.3). animalworld also ships a distinct Vulture.b3d if a
-- separate silhouette is ever wanted — that needs a LICENSE-media row.

local function eagle_def(description, texture)
	return {
		description = description,
		type = "monster",
		_grug_spawn_zones = {"outer", "coast"},
		-- HP/damage/XP/armor: engine-owned (levels.lua).

		reach = 2,
		attack_type = "dogfight",
		attack_players = true,
		-- Solitary hunter: no pack verb, so no group_attack (§3 "group_attack
		-- per verb").
		group_attack = false,

		-- Flier (see the header). floats/fall_damage are inert while fly is
		-- set but keep the def honest, exactly like kraken.lua.
		fly = true,
		fly_in = "air",
		jump = false,
		fall_damage = 0,
		fear_height = 0,

		-- §3.1 speed column: "4.6 heartland" — the fast tier, so a dive
		-- cannot simply be walked away from.
		walk_velocity = 2,
		run_velocity = 4.6,
		stepheight = 1.1,
		view_range = 16, -- a bird of prey spots you from far off

		visual = "mesh",
		mesh = "grug_mobs_eagle.b3d",
		-- grug_mobs_eagle.b3d is 18 cubes = 18 material slots on one atlas
		-- PNG; both skins (eagle, vulture) need the full count.
		textures = {grug_mobs.atlas_textures(texture, 18)},
		-- wp6_model_notes §2.3: 11.43 units = 1.14 nodes at size 1 (wings
		-- spread), upstream uses 1 and the box below is upstream's.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.5, 0.3},
		makes_footstep_sound = false,

		-- wp6_model_notes §2.3: there is NO walk/run range on this mesh, only
		-- `fly` — and mobs_redo's ground states still ask for walk/run, so
		-- both are aliased onto the fly loop (§0.2 rule).
		animation = {
			speed_normal = 100,
			stand_start = 0, stand_end = 100,
			walk_start = 150, walk_end = 250,
			run_start = 150, run_end = 250,
			fly_start = 150, fly_end = 250,
			punch_start = 250, punch_end = 350,
		},

		-- Bird-of-prey table (§3.2): shared verbatim between Crag Eagle and
		-- Vulture.
		drops = {
			{name = "grug_mobs:sharp_feather", chance = 1, min = 1, max = 2},
			{name = "mobs:meat_raw", chance = 2, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Crag Eagle — grug_crags (Accord)
--

grug_mobs.register_mob("grug_mobs:crag_eagle",
	eagle_def("Crag Eagle", "grug_mobs_eagle.png"))

-- §4 row "Crag Eagle/Vulture | gravel, mesa_clay | 20 | 2000 | 3 | min 10 |
-- outer, coast", split by continent-side top node.
-- max_height 300 instead of the usual 200: §4's note gives the crags rows
-- that exception, and the crags reach y 79 (biome cuboid, §1.3) with the
-- snowy sibling above.
-- SNOWBLOCK: grug_crags_snowy is the alpine sibling of the crags — same
-- cuboid, same climate point, snow top above y = 80 (§1.3). It was added in
-- WP18 and §4's table was never extended, so NO spawn row in the roster
-- listed `default:snowblock` and the whole snow cap of the dwarf west band
-- was mob-free. The three crags families carry it now. Zero budget impact:
-- snowblock only exists where gravel does not (y >= 80 vs the crags'
-- y_max = 79), so no cell gains a second row.
mobs:spawn({
	name = "grug_mobs:crag_eagle",
	nodes = {
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
	},
	min_light = 10,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 300,
})

--
-- Vulture — grug_badlands (Throng)
--

grug_mobs.register_mob("grug_mobs:vulture",
	eagle_def("Vulture", "grug_mobs_vulture.png"))

mobs:spawn({
	name = "grug_mobs:vulture",
	nodes = {"grug_nodes:mesa_clay"}, -- grug_badlands
	min_light = 10,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 300,
})
