-- Mountain Ram (docs/design/biomes_mobs.md §3.1, mountain pair).
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua/stag.lua, no helper from verbs.lua.
--
-- The Throng half of the §3.1 row ("Mountain Ram (Dust Hare)") already
-- shipped in T5: rabbit.lua registers grug_mobs:hare with the
-- grug_mobs_hare_dust.png skin. That is why the §4 "Ram | gravel | 20 | 2200
-- | 2 | min 10 | outer" row is RAM-ONLY and has no mesa_clay twin — the Dust
-- Hare rides the settled rabbit/hare row (settled tops, core+inner) instead.
--
-- Drop deviation from the shared critter table, spelled out by §3.1 itself:
-- "light leather 1/2 [leather] (ram: heavy leather 1/4)" — a mountain ram
-- yields the L25-60 hide, not the starter one (§6 lists rams under "heavy
-- leather" as well).

local ram = {
	description = "Mountain Ram",
	type = "animal",
	passive = true,
	runaway = true,
	_grug_spawn_zones = {"outer"},
	-- HP/damage/XP/armor: engine-owned (levels.lua).

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	jump = true,
	jump_height = 4, -- it lives on gravel slopes
	stepheight = 1.1,
	fear_height = 3,
	view_range = 10,

	visual = "mesh",
	mesh = "grug_mobs_ram.b3d",
	-- TWO texture slots (wp6_model_notes §0.3/§1.7): 1 = fleece, 2 = body and
	-- face. VoxeLibre colorises the fleece layer at runtime; our pre-baked
	-- grug_mobs_ram_fur.png replaces that, so both slots are plain files.
	textures = {{"grug_mobs_ram_fur.png", "grug_mobs_ram.png"}},
	-- Mesh scale rule (boar.lua): 12.6 units = 1.26 nodes at size 1, matching
	-- the box below; upstream uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 1.29, 0.45},
	makes_footstep_sound = true,

	-- wp6_model_notes §1.7: stand is the single frame 0, no punch clip
	-- (critter). Frames 81-161 are the lamb and stay unused.
	animation = {
		stand_start = 0, stand_end = 0,
		walk_start = 0, walk_end = 40, walk_speed = 30,
		run_start = 0, run_end = 40, run_speed = 40,
	},

	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "grug_mobs:heavy_leather", chance = 4, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:mountain_ram", ram)

-- §4 row "Ram | gravel | 20 | 2200 | 2 | min 10 | outer".
-- max_height 300 per §4's crags exception (the crags cuboid runs to y 79 and
-- the snowy sibling above it, §1.3) — and the snow top is exactly where the
-- Ram belongs, so `default:snowblock` is listed here too (eagle.lua carries
-- the full note on why no row had it).
mobs:spawn({
	name = "grug_mobs:mountain_ram",
	nodes = {
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
	},
	min_light = 10,
	interval = 20,
	chance = 2200,
	active_object_count = 2,
	min_height = 0,
	max_height = 300,
})
