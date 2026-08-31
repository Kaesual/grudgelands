-- Boar tints (docs/design/biomes_mobs.md §3.1, "Boar ... per-biome tint:
-- Plague Boar in blight, Jungle Boar east"). Same family, same verb
-- ("charges", the stalker impulse — see boar.lua), same drop table — only the
-- baked texture, the display name and the one biome top node differ.
--
-- The base Boar (boar.lua) lost those two tops in the same change, so every
-- settled biome carries exactly ONE boar. §4 budgets its calibration row per
-- ENTITY NAME (mobs_redo's active_object_count is counted per registered
-- name, api.lua count_mobs), which is why all three boars get the full
-- interval 20 / chance 1500 / aoc 5 without exceeding the per-biome budget.

-- One def shape for both variants; kept as a builder so the two
-- registrations cannot drift apart (§3.2: the boar table is identical
-- everywhere).
local function boar_def(description, texture)
	local def = {
		description = description,
		type = "monster",
		-- HP/damage/XP and armor come from the level engine (levels.lua):
		-- core/inner ring means level 1-10, i.e. 20-65 HP, 2-6 damage.

		reach = 2,
		attack_type = "dogfight",
		attack_players = true,
		group_attack = true,
		pathfinding = 1,

		walk_velocity = 1,
		-- Aggressive-mob speed (combat_stats.md §3, biomes_mobs §0).
		run_velocity = 4.4,
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
		fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
		view_range = 10,

		visual = "mesh",
		mesh = "grug_mobs_boar.b3d",
		-- Two texture slots (wp6_model_notes §0.3: body + saddle layer).
		textures = {{texture, "grug_mobs_blank.png"}},
		-- Mesh scale rule, see boar.lua: 8.0 units = 0.80 nodes at size 1.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.86, 0.45},
		makes_footstep_sound = true,

		-- No punch clip in the mesh — reuse the walk range at attack speed
		-- (wp6_model_notes §0.2), exactly as boar.lua does.
		animation = {
			stand_start = 0, stand_end = 0,
			walk_start = 0, walk_end = 40, walk_speed = 60,
			run_start = 0, run_end = 40, run_speed = 90,
			punch_start = 0, punch_end = 40, punch_speed = 90,
		},

		-- Boar table (§3.1) — byte-for-byte the base boar's table.
		drops = {
			{name = "mobs:meat_raw", chance = 1, min = 1, max = 2},
			{name = "grug_mobs:light_leather", chance = 2, min = 1, max = 1},
			{name = "grug_mobs:boar_tusk", chance = 3, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
	}
	-- Charges (§3.1) — byte-for-byte the base boar's verb, same reasoning and
	-- same numbers; see boar.lua. §3.2 keeps the family identical everywhere,
	-- so a tint variant charges exactly like the base boar.
	grug_mobs.stalker(def, {min_dist = 4, max_dist = 10, cooldown = 8,
		speed = 8, up = 1})
	return def
end

--
-- Plague Boar — grug_blight (Undead settled band, Throng west)
--

grug_mobs.register_mob("grug_mobs:plague_boar",
	boar_def("Plague Boar", "grug_mobs_boar_plague.png"))

mobs:spawn({
	name = "grug_mobs:plague_boar",
	nodes = {"grug_nodes:blight_dirt"}, -- grug_blight
	min_light = 10,
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})

--
-- Jungle Boar — grug_jungle_edge (Troll settled band, Throng east)
--
-- NB the rainforest litter also carries the Accord-side grug_jungle_fringe,
-- and the canopy litter carries the Throng grug_deep_jungle (§1.3), but those
-- are outer/coast biomes and the zone gate above (core, inner) keeps the
-- Jungle Boar out of them wherever they sit that far out.
--
-- The canopy litter is the §4 "core/inner day filler" slot for the deep
-- jungle: the wild deep-jungle cuboid starts at x 801, which the radial field
-- still reaches with zone `inner` up to |x| ~932, and the patch model (§1.4)
-- puts wild patches inside the settled rings anyway. The boar tint carries it
-- rather than plain grug_mobs:boar because §3.1 assigns the east band the
-- Jungle Boar. Deep jungle carries no CRITTER (same rule as the badlands,
-- §3.1), so the Hare's list is deliberately left alone.
--

grug_mobs.register_mob("grug_mobs:jungle_boar",
	boar_def("Jungle Boar", "grug_mobs_boar_jungle.png"))

mobs:spawn({
	name = "grug_mobs:jungle_boar",
	nodes = {
		"default:dirt_with_rainforest_litter", -- grug_jungle_edge
		"grug_nodes:dirt_with_canopy_litter", -- grug_deep_jungle patches
	},
	min_light = 10,
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})
