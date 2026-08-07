-- Wolf / Blightfang Wolf (docs/design/biomes_mobs.md §3.1, forest pair).
-- Verb: "hunts in packs; flees low, returns with pack" — grug_mobs.pack_hunter
-- from verbs.lua, installed on the def BEFORE register_mob (verbs.lua header
-- contract).
--
-- §3.1 also puts wolves into "inner pine-hills/meadows patches from L10",
-- which is what _grug_min_level does: the level field would hand out L10-ish
-- values in the inner ring anyway, the floor guarantees it and keeps a wolf
-- from ever being a level-1 pushover.

local function wolf_def(description, texture)
	return {
		description = description,
		type = "monster",
		_grug_spawn_zones = {"inner", "outer"},
		-- Level floor per §3.1 ("from L10"); everything derived from it is
		-- engine-owned (levels.lua) — no hp/damage/xp/armor here.
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
		mesh = "grug_mobs_wolf.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): 9.27 units = 0.93 nodes at size 1
		-- against the 0.84 box; upstream uses 1.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.84, 0.3},
		makes_footstep_sound = true,

		-- wp6_model_notes §1.4: stand is one frame, there is no punch clip —
		-- reuse the walk range at run speed (§0.2).
		animation = {
			stand_start = 0, stand_end = 0,
			walk_start = 0, walk_end = 40, walk_speed = 50,
			run_start = 0, run_end = 40, run_speed = 100,
			punch_start = 0, punch_end = 40, punch_speed = 100,
		},

		-- Wolf table (§3.2): shared verbatim with the Blightfang Wolf here
		-- and later with Hyena and Jungle Lynx (T6).
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
			{name = "mobs:leather", chance = 2, min = 1, max = 1},
			{name = "grug_mobs:fang", chance = 3, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Wolf — Accord side: pine hills, meadows and the deep forest
--

local wolf = wolf_def("Wolf", "grug_mobs_wolf.png")
grug_mobs.pack_hunter(wolf, {})
grug_mobs.register_mob("grug_mobs:wolf", wolf)

-- §4 row "Wolf/Blightfang | coniferous litter, forest litter, bone litter,
-- grass | 20 | 1500 | 5 | any | inner, outer", split along the continent
-- border: bone litter is the Throng bone forest and belongs to the
-- Blightfang below, the other three tops are Accord.
-- "any light" = no min_light/max_light and no day_toggle: 24 h.
mobs:spawn({
	name = "grug_mobs:wolf",
	nodes = {
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"default:dirt_with_grass", -- grug_meadows
	},
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})

--
-- Blightfang Wolf — Throng side: the bone forest
--

local blightfang = wolf_def("Blightfang Wolf", "grug_mobs_wolf_blightfang.png")
grug_mobs.pack_hunter(blightfang, {})
grug_mobs.register_mob("grug_mobs:blightfang_wolf", blightfang)

mobs:spawn({
	name = "grug_mobs:blightfang_wolf",
	nodes = {"grug_nodes:dirt_with_bone_litter"}, -- grug_bone_forest
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})
