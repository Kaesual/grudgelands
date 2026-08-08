-- Giant Spider / Bonelurker Spider / Jungle Spider (docs/design/biomes_mobs.md
-- §3.1, forest pair + jungle group; the cave rows come with T7).
--
-- Verb "webs": every landed melee swing slows the victim to 60% speed for
-- 3 s. Delivered by grug_mobs.melee_rider + grug_mobs.slow_player (verbs.lua)
-- — installed on the def BEFORE register_mob, per the verbs.lua contract.

local WEB_SECONDS = 3
local WEB_FACTOR = 0.6 -- "40% slow" (§3.1)

local function spider_def(description, texture)
	return {
		description = description,
		type = "monster",
		-- Underground is already in the list although T5 registers no cave
		-- row: the zone vocabulary is per MOB, and T7's cave pass only adds
		-- the mobs:spawn row on stone. Without the zone here that row would
		-- be blocked by spawn_abm_check.
		_grug_spawn_zones = {"outer", "coast", "underground"},

		reach = 2,
		attack_type = "dogfight",
		attack_players = true,
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
		mesh = "grug_mobs_spider.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua) with the design's "GIANT Spider" on top
		-- (wp6_model_notes §4.1 asks T5 to scale it up): the mesh is 5.0
		-- units = 0.50 nodes at size 1 and matches the upstream box exactly,
		-- so 1.5 is applied to BOTH — model and collisionbox stay in sync.
		visual_size = {x = 1.5, y = 1.5},
		-- ⚠ Negative y: the mesh hangs below its origin (-5.0..0.0 units).
		-- Upstream {-0.7, -0.5, -0.7, 0.7, 0, 0.7} × 1.5. Do not "fix" this
		-- to a 0-based box or the spider sinks into the ground.
		collisionbox = {-1.05, -0.75, -1.05, 1.05, 0, 1.05},
		makes_footstep_sound = false,

		-- wp6_model_notes §4.1 (mobs_monster ranges, native mobs_redo).
		animation = {
			speed_normal = 15,
			stand_start = 0, stand_end = 0,
			walk_start = 1, walk_end = 21,
			run_start = 1, run_end = 21, run_speed = 30,
			punch_start = 25, punch_end = 45, punch_speed = 30,
		},

		-- Spider table (§3.2): shared verbatim by every spider tint.
		drops = {
			{name = "grug_mobs:spider_silk", chance = 1, min = 1, max = 2},
			{name = "grug_mobs:venom_gland", chance = 6, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

local function web_rider(self, target)
	grug_mobs.slow_player(target, WEB_SECONDS, WEB_FACTOR)
end

--
-- Giant Spider — grug_deep_forest (Accord)
--

local spider = spider_def("Giant Spider", "grug_mobs_spider.png")
grug_mobs.melee_rider(spider, web_rider)
grug_mobs.register_mob("grug_mobs:giant_spider", spider)

-- §4 row "Giant Spider (all) | forest litter, bone litter, rainforest litter
-- | 20 | 1800 | 4 | max 5 | outer, coast, underground", split by continent
-- side; rainforest litter belongs to the jungle tint at the end of this file.
--
-- The elf-forest and pine-hills tops are here for the same reason bear.lua
-- carries them: settled patches occur in the outer ring and on the coasts
-- (§1.4), where §4's role-based whitelists left them empty. The Bear is the
-- day half of that Accord outer/coast forest roster, this row the night half
-- — without it grug_elf_forest x outer/coast and grug_pine_hills x coast
-- would be lit-up by day and dead after dark.
mobs:spawn({
	name = "grug_mobs:giant_spider",
	nodes = {
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest patches
		"default:dirt_with_coniferous_litter", -- grug_pine_hills patches
		-- WP36, the night half of bear.lua's grug_meadows addition: read the
		-- note there — grug_meadows x coast had no mob at all after the
		-- centre band was extended to Z_MAX on 2026-08-08.
		"default:dirt_with_grass", -- grug_meadows patches
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})

--
-- Bonelurker Spider — grug_bone_forest (Throng)
--

local bonelurker = spider_def("Bonelurker Spider", "grug_mobs_spider_pale.png")
grug_mobs.melee_rider(bonelurker, web_rider)
grug_mobs.register_mob("grug_mobs:pale_spider", bonelurker)

-- blight_dirt: the night half of the Throng mirror (bear.lua's Plaguehide
-- note) — grug_blight patches in the outer ring and on the coasts.
-- dry_dirt_with_dry_grass: the night half of the WP36 grug_savanna x coast
-- repair, same note.
mobs:spawn({
	name = "grug_mobs:pale_spider",
	nodes = {
		"grug_nodes:dirt_with_bone_litter", -- grug_bone_forest
		"grug_nodes:blight_dirt", -- grug_blight patches
		"default:dry_dirt_with_dry_grass", -- grug_savanna patches
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})

--
-- Jungle Spider — grug_deep_jungle (Throng) and grug_jungle_fringe (Accord),
-- added with the jungle group (T6)
--
-- ONE registration for both continents, unlike the pair above: §3.2 puts
-- every spider tint on the same table anyway ("spider table | Giant Spider |
-- Giant Spider (tints)"). Same def factory, same drops, same §4 numbers: only
-- the texture and the spawn node change.
--
-- TWO node names since WP36. §8.4 binds grug_jungle_fringe to the TROLL
-- JUNGLE's nodes 1:1 — and the troll jungle is grug_jungle_edge, not
-- grug_deep_jungle, which got its own top that round (§1.3). So the fringe
-- still stands on rainforest litter while the Throng deep jungle stands on
-- canopy litter, and this row must name both or the Throng half of the
-- outer/coast NIGHT roster disappears.
--

local jungle_spider = spider_def("Jungle Spider", "grug_mobs_spider_jungle.png")
grug_mobs.melee_rider(jungle_spider, web_rider)
grug_mobs.register_mob("grug_mobs:jungle_spider", jungle_spider)

mobs:spawn({
	name = "grug_mobs:jungle_spider",
	nodes = {
		"default:dirt_with_rainforest_litter", -- grug_jungle_fringe (Accord)
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle (Throng)
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})

--
-- CAVE ROW (WP6/T7) — §3.1's cave paragraph, §4 zone column "outer, coast,
-- underground". Level, height math, day_toggle and the `default:stone`
-- performance question are all explained once at the cave row in zombie.lua;
-- read that block before changing anything here.
--
-- ONE cave row, and it belongs to grug_mobs:giant_spider (the base tint).
-- The pale and jungle tints stay surface families: their textures are biome
-- identity (bone forest, jungle), a cave has neither, and three cave rows
-- would triple the underground spider budget for no design reason — §3.1
-- says "reuse Giant Spider", singular. The zone list of spider_def already
-- carries "underground" (T5 forward declaration), so this row passes
-- spawn_abm_check for every tint that ever needs one.
--
-- The web verb applies underground exactly as above (melee_rider is
-- installed per def, not per row).
--
mobs:spawn({
	name = "grug_mobs:giant_spider",
	-- group:grug_stratum = the tier-2..6 rock (WP25). default:stone alone ends
	-- at -100 after the mapgen strata, which would leave this row firing in a
	-- 60-node sliver instead of the whole cave system.
	nodes = {"default:stone", "group:grug_stratum"},
	max_light = 5,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = -31000,
	max_height = -40,
})
