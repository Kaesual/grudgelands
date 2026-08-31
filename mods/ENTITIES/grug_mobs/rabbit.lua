-- Rabbit / Hare (docs/design/biomes_mobs.md §3.1 "Rabbit/Hare (tints)"):
-- the harmless day critter of the settled biomes. Verb "flees" — mobs_redo
-- covers it natively with type "animal" + passive + runaway, so no helper
-- from verbs.lua is involved.
--
-- Two registrations because the design wants two looks per continent, split
-- along the three Accord tops (Rabbit) and the three Throng tops (Hare).
-- §4 lists ONE row for the family; both rows below carry its numbers,
-- which is correct because mobs_redo counts active_object_count per
-- registered entity name and the two node whitelists never overlap.

local function rabbit_def(description, texture, territory)
	return {
		description = description,
		type = "animal",
		-- Never attacks, runs when hurt or approached (mobs_redo runaway).
		passive = true,
		runaway = true,
		-- CONTINENT GATE, same idiom and same reason as golem.lua's: the
		-- split above is normally node-derivable (the six settled tops are
		-- three per continent), but the core/inner filler below adds
		-- `grug_nodes:mud` and `default:sand` — and swamp and beach are
		-- registered ONCE for the whole world (§1.3), so those two nodes
		-- exist on BOTH continents. Without this check an Accord lake shore
		-- would carry Rabbit and Hare at the same time, i.e. both tints in
		-- one place. _grug_spawn_check is registered per mob NAME (init.lua)
		-- and ANDed with the zone gate; it is pure arithmetic on x/z and runs
		-- before the active-object scan (golem.lua documents the order).
		_grug_spawn_check = function(pos)
			return grug_zones.faction_at(pos) == territory
		end,
		-- THE critter tier (levels.lua, biomes_mobs.md §3.0): level 1, 1 HP,
		-- 10 XP flat, no fall damage, never elite or rare, never telegraphs.
		-- HP/damage/XP/armor AND fall_damage are engine-owned from here — the
		-- def must not restate any of them.
		_grug_tier = "critter",

		-- Critter speed (biomes_mobs §0: 3.4). No pathfinding: a fleeing
		-- rabbit takes the straight line away from the threat, and
		-- core.find_path per critter would be pure overhead.
		walk_velocity = 1.5,
		run_velocity = 3.4,
		jump = true,
		stepheight = 1.1,
		fear_height = 3,
		view_range = 8,

		visual = "mesh",
		mesh = "grug_mobs_rabbit.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): 4.77 units = 0.48 nodes at size 1,
		-- matching the 0.49 box; upstream uses 1 as well.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.49, 0.2},
		makes_footstep_sound = false,

		-- wp6_model_notes §1.1: stand is the single frame 0, no punch clip
		-- (critter). Frames 21-41 are the baby rabbit and stay unused.
		animation = {
			stand_start = 0, stand_end = 0,
			walk_start = 0, walk_end = 20, walk_speed = 20,
			run_start = 0, run_end = 20, run_speed = 30,
		},

		-- FOOD ONLY (§3.0/§3.1 "meat 1/1 — food only"): the light-leather
		-- roll is gone. A critter must never be worth farming, and a food
		-- item stops being one the moment the larder is full — a crafting
		-- material never does. §6's light-leather row lost rabbits/hares
		-- with this change and still has the Boar on both continents.
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Rabbit — the Accord tops (settled + the wild/universal ones that occur as
-- core/inner patches, boar.lua's "role is not ring" note). This row is the
-- CRITTER half of that filler; the Boar is the aggressive half.
--

grug_mobs.register_mob("grug_mobs:rabbit",
	rabbit_def("Rabbit", "grug_mobs_rabbit.png", "accord"))

mobs:spawn({
	name = "grug_mobs:rabbit",
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
		"grug_nodes:mud", -- grug_swamp
		"default:sand", -- grug_beach
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})

--
-- Hare — the Throng tops. Same filler idea as the Rabbit above, but with
-- ONLY the universal tops added: `grug_nodes:mesa_clay` is deliberately left
-- out because §3.1 states "the badlands therefore carry no critter — Hyena,
-- Vulture and Mesa Golem only". A badlands patch inside core/inner is
-- covered by the Boar (day) and the Zombie (night) instead, so the cell is
-- alive without contradicting that roster line. The bone forest needs no
-- filler either: its cuboid (x -1500..-750) never reaches core, and its
-- inner strip already carries Blightfang Wolf + Gaunt Stag.
--

grug_mobs.register_mob("grug_mobs:hare",
	rabbit_def("Hare", "grug_mobs_hare_dust.png", "throng"))

mobs:spawn({
	name = "grug_mobs:hare",
	nodes = {
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"grug_nodes:blight_dirt", -- grug_blight
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:mud", -- grug_swamp
		"default:sand", -- grug_beach
	},
	min_light = 10,
	interval = 20,
	chance = 1800,
	active_object_count = 3,
	min_height = 0,
	max_height = 200,
})
