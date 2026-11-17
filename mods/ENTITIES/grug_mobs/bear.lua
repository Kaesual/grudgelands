-- Bear / Plaguehide Bear (docs/design/biomes_mobs.md §3.1, forest pair).
-- Verb: "territorial (guards radius, short chase)" — that is not a helper in
-- verbs.lua but the aggro field _grug_leash_range (aggro.lua): a bear gives
-- up after 20 nodes instead of the default 40, so leaving its patch is
-- enough. Day mob, aggressive speed.
--
-- Elite variant "Elder Bear" (§3.1: elite ×1.4 scale): rolled once per fresh
-- spawn on the definition's activation path (elder_roll below), no second
-- registration and no extra texture (wp6_model_notes §0.4 — elites are a
-- runtime tint + scale).

local ELDER_CHANCE = 10 -- 1 in 10 spawns is an Elder (elite tier)

-- The Elder roll (Round 81, ruling 6: it ran only as the retired ABM rows'
-- on_spawn until then). It runs in the definition's after_activate, so every
-- spawner's fresh entity of this name rolls, whoever adds it. Fresh means no
-- staticdata: a reactivated bear brings its saved fields back and never
-- rolls again, and neither does a spawn that hands its own staticdata (a
-- named rare). Before the first tick, so grug_mobs.set_tier only records
-- the tier and ensure_init applies level, elite multipliers, ×1.4 scale,
-- gold tint and nametag together; `description` (levels.lua tag_text reads
-- it) is set first, so the first nametag already says "Elite Elder Bear".
-- Both are plain fields and persist in staticdata. A sub-type copies this
-- definition (subtypes.lua) but never rolls: the name test keeps its
-- authored tier and name its own.
local function elder_roll(name, elder_name)
	return function(self, staticdata)
		if self.name ~= name or (staticdata ~= nil and staticdata ~= "") or
				math.random(ELDER_CHANCE) ~= 1 then
			return
		end
		self.description = elder_name
		grug_mobs.set_tier(self, "elite")
	end
end

local function bear_def(name, description, elder_name, texture)
	return {
		after_activate = elder_roll(name, elder_name),
		description = description,
		_grug_voice = "beast",
		clock = "day",
		type = "monster",
		-- Territorial: short leash instead of the default 40 nodes
		-- (aggro.lua, combat_stats.md §4).
		_grug_leash_range = 20,
		-- HP/damage/XP/armor: engine-owned (levels.lua). Outer ring and
		-- coasts mean L25-60 — the heaviest normal mob of the forest pair.

		reach = 3,
		attack_type = "dogfight",
		attack_players = true,
		group_attack = true,
		pathfinding = 1,

		walk_velocity = 1,
		run_velocity = 4.6, -- aggressive-mob speed (§0)
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
		fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
		view_range = 12, -- territorial: notices you late, then commits

		visual = "mesh",
		mesh = "grug_mobs_bear.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): this mesh is exported small (3.78
		-- units = 0.38 nodes at size 1), so the upstream 3.0 is the value
		-- that fits the collisionbox — 1.13 rendered nodes against a 1.39
		-- box (wp6_model_notes §1.5).
		visual_size = {x = 3, y = 3},
		collisionbox = {-0.7, -0.01, -0.7, 0.7, 1.39, 0.7},
		-- Rotated selection box = measured mesh bounds (Round 28, tools/r28_a3).
		selectionbox = {-0.7, -0.05, -1.1, 0.7, 1.15, 1, rotate = true},
		makes_footstep_sound = true,

		-- wp6_model_notes §1.5: no punch clip — reuse the walk range at run
		-- speed (§0.2).
		animation = {
			speed_normal = 25, speed_run = 50,
			stand_start = 0, stand_end = 0,
			walk_start = 0, walk_end = 40,
			run_start = 0, run_end = 40,
			punch_start = 0, punch_end = 40, punch_speed = 50,
		},

		-- Bear table (§3.2): shared verbatim with the Plaguehide Bear here
		-- and later with the Jungle Ape (T6).
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
			{name = "grug_mobs:heavy_leather", chance = 2, min = 1, max = 1},
			{name = "grug_mobs:bear_claw", chance = 4, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Bear — grug_deep_forest (Accord)
--

grug_mobs.register_mob("grug_mobs:bear",
	bear_def("grug_mobs:bear", "Bear", "Elder Bear", "grug_mobs_bear.png"))

--
-- Plaguehide Bear — grug_bone_forest (Throng)
--

grug_mobs.register_mob("grug_mobs:plaguehide_bear",
	bear_def("grug_mobs:plaguehide_bear", "Plaguehide Bear", "Elder Plaguehide Bear",
		"grug_mobs_bear_plaguehide.png"))
