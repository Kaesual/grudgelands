-- Stag / Gaunt Stag (docs/design/biomes_mobs.md §3.1, forest pair).
--
-- Verb "grazes" — PASSIVE PREY since WP36 (§3.0): no aggro on sight, but it
-- fights back when attacked. It is NOT a critter: a stag is a large grazer,
-- so it keeps its level from the field, its HP and XP from the formulas and
-- its leather drop. That is what makes it worth the swing and what keeps the
-- leather tiers gated by a real fight rather than by travel.
-- grug_mobs.passive_prey (verbs.lua) carries the mobs_redo reasoning.
--
-- The Zebra (T6, savanna) is the Throng mirror on the very same stag drop
-- table (§3.2) and reuses the numbers below.

local function stag_def(description, texture)
	local def = {
		description = description,
		type = "animal",
		_grug_spawn_zones = {"inner", "outer"},
		-- Stats engine-owned (levels.lua) — normal tier, so level, HP, damage
		-- and XP all come from the field and the formulas.

		walk_velocity = 1.5,
		run_velocity = 3.4, -- grazer speed (§0's "critters 3.4" line)
		jump = true,
		stepheight = 1.1,
		fear_height = 3,
		view_range = 12,
		-- Ground prey chases up to 45 m since WP36 (§3.0 retaliation + the
		-- _grug_chase_range patch), so it needs the same A* every other mob
		-- that enters the attack state has: `core.find_path` runs only from
		-- the attack branch (api.lua:2442-2445), i.e. only after a player
		-- punch, so a grazing herd pays nothing. Without it the "worth the
		-- swing" of §3.0 is defeated by any 3-node ledge. §3's "all
		-- aggressive mobs: pathfinding = 1" does not cover prey (prey never
		-- initiates) — this is AGENTS.md's pathfinding quality criterion,
		-- applied to a mob that now fights. NOT given to the Carrion Crow:
		-- it is `fly = true`, and find_path is a ground search (eagle.lua).
		pathfinding = 1,

		visual = "mesh",
		mesh = "grug_mobs_stag.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua) with the caveat wp6_model_notes §3.1
		-- spells out: animalia exports at 1/10 scale (2.32 units = 0.23
		-- nodes at size 1) and its creatura hitbox (0.9) disagrees with the
		-- upstream visual_size 10 (= 2.32 rendered nodes). The notes say
		-- "start at 10 and shrink until the mesh matches the box": 8 puts
		-- the mesh incl. antlers at 1.86 nodes, and the box below is sized
		-- to that instead of to creatura's body-only 0.9.
		visual_size = {x = 8, y = 8},
		collisionbox = {-0.5, -0.01, -0.5, 0.5, 1.8, 0.5},
		makes_footstep_sound = true,

		-- wp6_model_notes §3.1 (creatura ranges translated). No punch clip on
		-- this mesh: mobs_redo's set_animation returns without a write when
		-- the requested clip is missing (api.lua:464), so a retaliating stag
		-- keeps its run animation instead of freezing — acceptable, and
		-- cheaper than inventing a clip the mesh does not have.
		animation = {
			stand_start = 1, stand_end = 59, stand_speed = 10,
			walk_start = 70, walk_end = 89, walk_speed = 30,
			run_start = 100, run_end = 119, run_speed = 40,
		},

		-- Stag table (§3.2): shared verbatim with the Gaunt Stag here and
		-- later with the Zebra (T6).
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
			{name = "mobs:leather", chance = 2, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
	-- Verb last, def first (verbs.lua contract): passive = false,
	-- attack_players/attack_npcs = false, runaway = false.
	return grug_mobs.passive_prey(def)
end

--
-- Stag — Accord: deep forest and the meadows it borders
--

grug_mobs.register_mob("grug_mobs:stag", stag_def("Stag", "grug_mobs_stag.png"))

-- §4 row "Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry
-- grass | 20 | 1800 | 3 | min 10 | inner, outer", split by continent side.
--
-- T10 correction: §4 prices these three names as ONE row of aoc 3, so each
-- top node may be claimed by exactly ONE of them. `dry_dirt_with_dry_grass`
-- belongs to the Zebra (§3.1 "Savanna extras … Zebra"); the Gaunt Stag used
-- to list it as well, which stacked 3 + 3 = 6 stag-family slots on the
-- savanna and pushed that biome's day sum to 19 against §4's ~14 cap
-- (docs/research/wp6_spawn_budget.md). The Gaunt Stag is the bone-forest
-- half of the forest pair (§3.1) and keeps bone litter only.
mobs:spawn({
	name = "grug_mobs:stag",
	nodes = {
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"default:dirt_with_grass", -- grug_meadows
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})

--
-- Gaunt Stag — Throng: bone forest
--

grug_mobs.register_mob("grug_mobs:gaunt_stag",
	stag_def("Gaunt Stag", "grug_mobs_stag_gaunt.png"))

mobs:spawn({
	name = "grug_mobs:gaunt_stag",
	-- Bone forest only — the savanna's stag-table slot is the Zebra's
	-- (zebra.lua, same drop table per §3.2). See the note above.
	nodes = {"grug_nodes:dirt_with_bone_litter"}, -- grug_bone_forest
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
