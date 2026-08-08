-- Jungle Lynx (docs/design/biomes_mobs.md §3.1, jungle group — the RAPTOR
-- slot).
--
-- DECISION (§8.2, resolved 2026-08-06): the Raptor family was conditional on
-- a clean per-file media license in paleotest. T4 checked the repo and found
-- a code-only GPL-3.0 LICENSE with no media statement at all (evidence in
-- LICENSE-media.md §7), so no paleotest media was imported and the decided
-- fallback applies: a big-cat retint on the animalworld mesh
-- (grug_mobs_panther.b3d + grug_mobs_jungle_lynx.png, wp6_model_notes §2.4).
-- It keeps the Raptor's ROLE unchanged — same "hunts in packs" verb, same
-- shared wolf drop table plus raptor claw, same §4 raptor row, same
-- jungle_edge-from-L10 placement. Only the name and the skin differ; the
-- claw item id stays grug_mobs:raptor_claw (registered in items.lua).
--
-- Verb: grug_mobs.pack_hunter from verbs.lua, installed BEFORE register_mob
-- (verbs.lua header contract), exactly like wolf.lua and hyena.lua.
--
-- ONE registration for both continents: §8.4 decided the Accord jungle fringe
-- reuses the troll jungle nodes 1:1, so `default:dirt_with_rainforest_litter`
-- is the top node on BOTH sides and a T5-style node split is impossible (and
-- unnecessary — §3.2 shares the jungle tables anyway).

local lynx = {
	description = "Jungle Lynx",
	type = "monster",
	_grug_spawn_zones = {"inner", "outer"},
	-- §3.1 "jungle_edge from L10": the settled inner jungle is where this
	-- family starts, so the floor keeps it from ever being a L1 pushover.
	_grug_min_level = 10,

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true,
	pathfinding = 1,

	walk_velocity = 1.5,
	run_velocity = 4.4, -- aggressive-mob speed (§0)
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 14,

	visual = "mesh",
	mesh = "grug_mobs_panther.b3d",
	-- grug_mobs_panther.b3d is 17 cubes = 17 material slots on one atlas PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_jungle_lynx.png", 17)},
	-- Mesh scale rule (boar.lua): 8.41 units = 0.84 nodes at size 1 against
	-- the 0.95 box; upstream (animalworld) uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = true,

	-- wp6_model_notes §2.4: no run range — walk at a higher speed (§0.2).
	animation = {
		speed_normal = 140,
		stand_start = 0, stand_end = 100, stand_speed = 50,
		walk_start = 100, walk_end = 200,
		run_start = 100, run_end = 200, run_speed = 200,
		punch_start = 250, punch_end = 350,
	},

	-- Wolf table (§3.2: "wolf table | Wolf | ... Raptor*"): meat and leather
	-- are byte-identical to wolf.lua/hyena.lua; the third slot is the
	-- family's own trophy — §3.1's raptor row spells out "raptor claw 1/3"
	-- where the wolf row has "fang 1/3" (same chance, same shape).
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:raptor_claw", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.pack_hunter(lynx, {})
grug_mobs.register_mob("grug_mobs:jungle_lynx", lynx)

-- §4 row "Raptor | rainforest litter | 20 | 1500 | 5 | min 10 | inner,
-- outer" — verbatim, the family only changed its skin.
mobs:spawn({
	name = "grug_mobs:jungle_lynx",
	-- grug_jungle_edge (inner) and grug_jungle_fringe (outer, Accord) use the
	-- rainforest litter; grug_deep_jungle got its own top in WP36 and needs
	-- naming separately or the Throng half of this family's habitat would
	-- vanish (§1.3/§1.5).
	nodes = {
		"default:dirt_with_rainforest_litter",
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle
	},
	min_light = 10,
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})
