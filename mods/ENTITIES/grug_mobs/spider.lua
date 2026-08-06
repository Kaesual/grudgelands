-- Giant Spider / Bonelurker Spider (docs/design/biomes_mobs.md §3.1, forest
-- pair; the jungle tint is T6 and the cave rows come with T7).
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
		fear_height = 4,
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
-- side; rainforest litter belongs to T6's jungle tint.
mobs:spawn({
	name = "grug_mobs:giant_spider",
	nodes = {"grug_nodes:dirt_with_forest_litter"}, -- grug_deep_forest
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

mobs:spawn({
	name = "grug_mobs:pale_spider",
	nodes = {"grug_nodes:dirt_with_bone_litter"}, -- grug_bone_forest
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 1800,
	active_object_count = 4,
	min_height = 0,
	max_height = 200,
})
