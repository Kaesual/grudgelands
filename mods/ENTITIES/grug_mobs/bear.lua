-- Bear / Plaguehide Bear (docs/design/biomes_mobs.md §3.1, forest pair).
-- Verb: "territorial (guards radius, short chase)" — that is not a helper in
-- verbs.lua but the aggro field _grug_leash_range (aggro.lua): a bear gives
-- up after 20 nodes instead of the default 40, so leaving its patch is
-- enough. Day mob, aggressive speed.
--
-- Elite variant "Elder Bear" (§3.1: elite ×1.6 scale): rolled per spawn in
-- the mobs:spawn rows below, no second registration and no extra texture
-- (wp6_model_notes §0.4 — elites are a runtime tint + scale).

local ELDER_CHANCE = 10 -- 1 in 10 spawns is an Elder (elite tier)

local function bear_def(description, texture)
	return {
		description = description,
		type = "monster",
		_grug_spawn_zones = {"outer", "coast"},
		-- Territorial: short leash instead of the default 40 nodes
		-- (aggro.lua, combat_stats.md §4).
		_grug_leash_range = 20,
		-- HP/damage/XP/armor: engine-owned (levels.lua). Outer ring and
		-- coasts mean L25-60 — the heaviest normal mob of the forest pair.

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

-- Elder roll for a mobs:spawn row.
--
-- mobs_redo calls on_spawn(luaentity, pos) directly after core.add_entity
-- (api.lua:3686), i.e. AFTER on_activate but BEFORE the entity's first
-- on_step — so before grug_mobs.ensure_init has assigned a level. That is
-- exactly the case grug_mobs.set_tier documents: with no _grug_level yet it
-- only records the tier and returns, and ensure_init then applies level,
-- elite multipliers, ×1.6 scale, gold tint and nametag together on the first
-- tick. `description` is a plain entity field (levels.lua tag_text reads it)
-- and is set first, so the very first nametag already says "Elite Elder
-- Bear". Both fields are plain values and persist in staticdata.
local function elder_roll(elder_name)
	return function(ent)
		if not ent or math.random(ELDER_CHANCE) ~= 1 then
			return
		end
		ent.description = elder_name
		grug_mobs.set_tier(ent, "elite")
	end
end

--
-- Bear — grug_deep_forest (Accord)
--

grug_mobs.register_mob("grug_mobs:bear", bear_def("Bear", "grug_mobs_bear.png"))

-- §4 row "Bear/Plaguehide | forest litter, bone litter | 20 | 2800 | 2 |
-- min 10 | outer, coast", split by continent-side top node.
mobs:spawn({
	name = "grug_mobs:bear",
	nodes = {"grug_nodes:dirt_with_forest_litter"}, -- grug_deep_forest
	min_light = 10,
	interval = 20,
	chance = 2800,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
	on_spawn = elder_roll("Elder Bear"),
})

--
-- Plaguehide Bear — grug_bone_forest (Throng)
--

grug_mobs.register_mob("grug_mobs:plaguehide_bear",
	bear_def("Plaguehide Bear", "grug_mobs_bear_plaguehide.png"))

mobs:spawn({
	name = "grug_mobs:plaguehide_bear",
	nodes = {"grug_nodes:dirt_with_bone_litter"}, -- grug_bone_forest
	min_light = 10,
	interval = 20,
	chance = 2800,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
	on_spawn = elder_roll("Elder Plaguehide Bear"),
})
