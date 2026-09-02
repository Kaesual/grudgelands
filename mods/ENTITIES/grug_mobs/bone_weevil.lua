-- Bone Weevil (docs/design/biomes_mobs.md §3.0, the 2026-08-08 critter
-- round: "Bone Weevil (bone forest + blight, the 'creepy' biomes, day)").
--
-- Verb "flees (critter)" — native mobs_redo behaviour (animal + passive +
-- runaway), same shape as rabbit.lua. Shares its mesh with the Cave Crawler
-- (cave_crawler.lua), which carries the model notes.
--
-- ONE ENTITY NAME, TWO BIOME TINTS — and that combination is deliberate.
-- `active_object_count` is counted per entity NAME inside a 128-node sphere
-- (wp6_spawn_budget.md §1), so two registrations would be two independent
-- budgets in a pair of cells that are already the world's night peak
-- neighbourhood. One name keeps ONE budget of 2 for the whole family, while
-- the two spawn rows below still hand out the tint that belongs to the biome
-- the mob actually stood on:
--
--   bone forest (bone litter) -> bleached bone-pale
--   blight (blight_dirt)      -> sickly blight green
--
-- The stamp goes through `on_spawn`, which mobs_redo calls with the fresh
-- luaentity right after add_entity (api.lua:3677ff) — i.e. after
-- mob_activate picked a random texture from the list and before the first
-- do_custom tick, so nothing else has read it yet. `base_texture` is a plain
-- field and therefore survives unload/reload in staticdata; mob_activate
-- re-applies it (`if not self.base_texture then ... random`) instead of
-- re-rolling. Deliberately NOT two entity names, and deliberately not a
-- random tint either — "same loot, different look" is per biome (§3.2).

local weevil = {
	description = "Bone Weevil",
	type = "animal",
	passive = true,
	runaway = true,
	-- No _grug_spawn_domains: both of its node whitelists below are single-
	-- continent Throng band tops (bone forest, blight), so the NODE does all
	-- of the gating and the ring is irrelevant — this critter belongs to the
	-- creepy biomes wherever a patch of them lands (§4's "role is not ring").
	-- THE critter tier (levels.lua, §3.0): level 1, 1 HP, 10 XP flat, no fall
	-- damage, never elite or rare, never telegraphs.
	_grug_tier = "critter",

	walk_velocity = 1.5,
	run_velocity = 3.4, -- critter speed (§0)
	jump = true,
	stepheight = 1.1,
	fear_height = 3,
	view_range = 8,

	visual = "mesh",
	mesh = "grug_mobs_cave_crawler.b3d",
	-- Two variants; the spawn rows below stamp the right one. The list is
	-- also the fallback: a hand-placed weevil (mobs:add_mob) with no on_spawn
	-- gets one of the two at random rather than no texture at all.
	textures = {
		{"grug_mobs_bone_weevil.png"},
		{"grug_mobs_bone_weevil_blight.png"},
	},
	visual_size = {x = 3, y = 3},
	collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.44, 0.4},
	makes_footstep_sound = false,

	-- Frames read out of grug_mobs_cave_crawler.b3d: 7 keyed joints, 147
	-- keys, real range 1..21 (cave_crawler.lua).
	animation = {
		stand_start = 1, stand_end = 20, stand_speed = 15,
		walk_start = 1, walk_end = 20, walk_speed = 25,
		run_start = 1, run_end = 20, run_speed = 50,
	},

	-- FOOD ONLY (§3.0).
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:bone_weevil", weevil)

-- Stamps one of the two variants onto a freshly spawned weevil. The two
-- writes mirror exactly what mobs_redo's own `def.texture` path does
-- (api.lua:3700-3703): the field for persistence, the property for the
-- client. mobs_redo calls on_spawn as `on_spawn(luaentity, pos)` and the
-- entity is nil when core.add_entity failed (zombie.lua's blight row uses
-- the same guard).
local function stamp(texture)
	return function(ent)
		if not ent or not ent.object then
			return
		end
		local list = {texture}
		ent.base_texture = list
		ent.object:set_properties({textures = list})
	end
end

-- §3.0's numbers for the four new critters: interval 20 / chance 2200 /
-- aoc 2, day (`min_light 10`; §4 prints the decided post-0.75 value 1650 —
-- see cave_bat.lua). TWO ROWS, ONE BUDGET — mobs_redo counts the
-- cap per entity name, so bone forest and blight share the same 2 the way
-- the Skeleton Archer's two node lists share theirs (§4).
--
-- Budget effect, per wp6_spawn_budget.md §2.2 (day column only — this is a
-- day mob, so no night cell moves):
--   bone forest  inner 8->10, outer 10->12, coast 2->4, war_coast 2->4
--   blight       core 12->14, inner 12->14, outer 2->4, coast 2->4,
--                war_coast 6->8
-- The world day peak is 16 (meadows/savanna/deep-forest inner); the highest
-- cell touched here reaches 14. Nothing moves the peak.
mobs:spawn({
	name = "grug_mobs:bone_weevil",
	nodes = {"grug_nodes:dirt_with_bone_litter"}, -- grug_bone_forest
	min_light = 10,
	interval = 20,
	chance = 2200,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
	on_spawn = stamp("grug_mobs_bone_weevil.png"),
})

mobs:spawn({
	name = "grug_mobs:bone_weevil",
	nodes = {"grug_nodes:blight_dirt"}, -- grug_blight
	min_light = 10,
	interval = 20,
	chance = 2200,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
	on_spawn = stamp("grug_mobs_bone_weevil_blight.png"),
})
