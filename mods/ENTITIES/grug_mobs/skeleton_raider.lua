-- Skeleton Raider (docs/design/biomes_mobs.md §3.1, war-coast row: "plus
-- Skeleton Raider (dogshoot, night — battlefield dead; skeleton table +
-- heavy cloth 1/3)").
--
-- The war coast's own undead: same mesh as the Skeleton Archer, own grimy
-- texture (wp6_model_notes §1.3), same verb and — per §3.2's "swamp/beach/
-- boar/zombie/bandit/skeleton | identical biomes both sides | identical" —
-- the same skeleton drop rows, plus the heavy cloth of the battlefield.
--
-- The arrow entity `grug_mobs:arrow_entity` and the level-scaled damage
-- stamp are REUSED from skeleton_archer.lua (which registers them and which
-- init.lua loads first) — the two archers must not have two projectiles.

-- A fresh definition each call: Auditor Nemm (below) is built on the same body.
local function raider_def(description)
	return {
		description = description,
		_grug_voice = "skeleton",
		clock = "night",
		type = "monster",
		-- The war coast is not its own biome (§1.2 / §8.1), so the zone does all
		-- of the gating and every node of the row below is allowed. Unlike
		-- skeleton_archer.lua no _grug_spawn_check is needed: that family lives
		-- in the outer ring AND on the war coast and therefore needs a per-ROW
		-- rule; this one is war-coast-only.
		_grug_spawn_domains = {"contested"},
		-- HP/damage/XP/armor: engine-owned (levels.lua). The war-coast cap of
		-- grug_zones.mob_level_at keeps this family at 20-30 — which is also why
		-- the two Captain Bonerattle rares (rares.lua) are ~L28.

		reach = 3,
		attack_type = "dogshoot",
		attack_players = true,
		group_attack = true,
		pathfinding = 1,

		-- Ranged loadout, identical to skeleton_archer.lua: dogshoot_switch = 1
		-- opens in the RANGED mode, which follows the distance since Round 78
		-- (golem.lua; the count fields are no longer read).
		arrow = "grug_mobs:arrow_entity",
		arrow_override = grug_mobs.stamp_arrow_damage,
		shoot_interval = 2.5,
		-- Aim lift for this mesh (see skeleton_archer.lua): without it every shot
		-- lands at the target's feet.
		shoot_offset = 1.5,
		dogshoot_switch = 1,
		dogshoot_count_max = 10,
		dogshoot_count2_max = 3,

		-- §3.1 speed column of the skeleton family: 4.0 in combat, a calm walk
		-- while roaming (Round 24 ruling 20; skeleton_archer.lua does the same).
		walk_velocity = 1,
		run_velocity = 4.0,
		_grug_soft_deaggro = false,
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
		fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
		view_range = 16, -- it shoots; it needs to see further than a brawler

		visual = "mesh",
		mesh = "grug_mobs_skeleton.b3d",
		-- THREE texture slots (wp6_model_notes §0.3): 1 = armour (blank),
		-- 2 = bones, 3 = wielded item: the archer's bow (skeleton_archer.lua).
		textures = {{
			"grug_mobs_blank.png",
			"grug_mobs_skeleton_raider.png",
			"grug_gear_bow_wood.png",
		}},
		-- Mesh scale rule (boar.lua): 20.1 units = 2.01 nodes at size 1 against
		-- the 1.98 box; upstream uses 1.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3},
		-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
		selectionbox = {-0.5, -0.05, -0.7, 0.55, 2.05, 0.7, rotate = true},
		makes_footstep_sound = true,

		-- wp6_model_notes §1.3: no melee clip — `punch` reuses the shoot range.
		animation = {
			stand_start = 0, stand_end = 40, stand_speed = 15,
			walk_start = 40, walk_end = 60, walk_speed = 15,
			run_start = 40, run_end = 60, run_speed = 30,
			shoot_start = 70, shoot_end = 90, shoot_speed = 15,
			punch_start = 70, punch_end = 90, punch_speed = 15,
		},

		-- Skeleton table (§3.1/§3.2) — the first two rows are byte-identical
		-- to skeleton_archer.lua's on purpose (bone 1/1, linen scrap 1/2; the
		-- sell-only arrow bundle no longer drops, Round 46 ruling 12) — plus the
		-- war-coast heavy cloth 1/3 of the §3.1 row (§6 lists "war-coast raiders"
		-- as a heavy-cloth source).
		drops = {
			{name = "grug_mobs:bone", chance = 1, min = 1, max = 1},
			{name = "grug_mobs:linen_scrap", chance = 2, min = 1, max = 1},
			{name = "grug_mobs:heavy_cloth", chance = 3, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		-- No daylight burn: the design gates the skeleton by spawn time only
		-- (§3.1 "night"), it does not ask for an undead sun weakness
		-- (skeleton_archer.lua takes the same line).
		light_damage = 0,
	}
end

grug_mobs.register_mob("grug_mobs:skeleton_raider", raider_def("Skeleton Raider"))

--
-- Auditor Nemm (Round 72): the boss of The Second Shift, the level 40-69 Expedition
-- (docs/planning/round72-second-shift.md), on the Skeleton Raider's body, bow and
-- attacks: no adds, no phases, no new look, no spawn row. grug_expeditions places it by
-- its template's boss marker, as an elite at the run's level (the elite's wind-up comes
-- with the tier); the HP factor (tools/r72_shift/balance.py) and one signature set it
-- apart. Every MARK_EVERY seconds of a fight it marks its current target's floor
-- position once, and the floor trap's ring and hit fall there (grug_expeditions
-- traps.lua through grug_mobs.expedition_mark): one position, one delayed hit. Its reset
-- or death takes a pending hit back. It stands in its court until someone comes, sees
-- the whole court, and drops nothing: the reward room pays.
--
local nemm = raider_def("Auditor Nemm")
nemm.clock = "any"
nemm._grug_spawn_domains = nil
-- x14 since Round 73 BOSSHP (the user, 2026-11-10; it was x20).
nemm._grug_hp_scale = 14
nemm.walk_chance = 0
nemm.view_range = 20
nemm.drops = {}

local MARK_EVERY = 12

-- The signature's clock, while it fights a player: a reset (no target, the evade home)
-- or a death cancels a hit still pending.
nemm.do_custom = function(self, dtime)
	local t = self.temp
	local target = self.attack
	local fighting = t and not t.grug_evading and self.state == "attack" and (self.health or 0) > 0
		and target and core.is_player(target) and target:get_hp() > 0
	if not fighting then
		if t and t.grug_nemm_mark and grug_mobs.expedition_unmark then
			grug_mobs.expedition_unmark(t.grug_nemm_mark)
		end
		if t then t.grug_nemm_mark, t.grug_nemm_clock = nil, nil end
		return
	end
	t.grug_nemm_clock = (t.grug_nemm_clock or MARK_EVERY) - dtime
	if t.grug_nemm_clock > 0 then return end
	t.grug_nemm_clock = MARK_EVERY
	if grug_mobs.expedition_mark then
		t.grug_nemm_mark = grug_mobs.expedition_mark(self, target:get_pos())
	end
end

grug_mobs.register_mob("grug_mobs:auditor_nemm", nemm)

-- §4 has no own Skeleton Raider row; it is the war-coast half of the
-- skeleton family, so the numbers are the Skeleton Archer's
-- (interval 20 / chance 2000 / aoc 3 / max light 5) — §3.1 "night" gives the
-- light gate and day_toggle = false.
--
-- Nodes: the six settled tops of §1.3 (the war coast wears whichever settled
-- biome its band has) PLUS sand, because the ocean mask puts the actual
-- strait-facing beach inside the war-coast zone (§1.5) and a battlefield
-- shore without its dead would be odd. ONE row, so blight_dirt can be listed
-- here without a second ABM doubling up on it.
mobs:spawn({
	name = "grug_mobs:skeleton_raider",
	-- ALL land tops plus sand — the night counterpart of the Carrion Crow's
	-- list, and for the same reason (read that file's note): the war coast
	-- carries whatever the local band's voronoi produces, wild patches
	-- included. The common named-zone `war` palette plus the contested-domain
	-- check keeps the wider list out of every other named zone.
	nodes = {
		"default:dirt_with_grass", -- grug_meadows
		"default:dirt_with_coniferous_litter", -- grug_pine_hills
		"grug_nodes:dirt_with_silver_litter", -- grug_elf_forest
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle (WP36 top)
		"grug_nodes:blight_dirt", -- grug_blight
		"grug_nodes:dirt_with_forest_litter", -- grug_deep_forest
		"grug_nodes:dirt_with_bone_litter", -- grug_bone_forest
		"grug_nodes:mesa_clay", -- grug_badlands
		"default:gravel", -- grug_crags
		"default:snowblock", -- grug_crags_snowy
		"grug_nodes:mud", "grug_nodes:mud_dry", "grug_nodes:mud_mottled",
		"grug_nodes:mud_with_wet_grass", -- grug_swamp
		"default:sand", -- beach cells inside explicit war zones
	},
	max_light = 5,
	day_toggle = false,
	interval = 20,
	chance = 2000,
	active_object_count = 3,
	min_height = 0,
	max_height = 600,
})
