-- Hyena (docs/design/biomes_mobs.md §3.1: mountain pair row "Hyena — savanna
-- + badlands (Throng's wolf-mirror, wolf drop table)", plus the savanna
-- extras block "Hyena (above, from L10)").
--
-- Verb: "hunts in packs" — grug_mobs.pack_hunter from verbs.lua, installed on
-- the def BEFORE register_mob (verbs.lua header contract), exactly like
-- wolf.lua. The drop table below is the shared WOLF table of §3.2 and is
-- byte-identical to wolf.lua's — do not "improve" one without the other.
--
-- Throng-only family: both of its spawn tops (savanna dry grass, badlands
-- mesa clay) exist only on the Kragmar side, so no continent check is needed.

local hyena = {
	description = "Hyena",
	type = "monster",
	-- Level floor per §3.1 ("from L10"), same reasoning as wolf.lua: the
	-- field hands out L10-ish values in the inner ring anyway, the floor
	-- guarantees it. Everything derived is engine-owned (levels.lua).
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
	mesh = "grug_mobs_hyena.b3d",
	-- grug_mobs_hyena.b3d is 16 cubes = 16 material slots on one atlas PNG.
	textures = {grug_mobs.atlas_textures("grug_mobs_hyena.png", 16)},
	-- Mesh scale rule (boar.lua): 8.89 units = 0.89 nodes at size 1, matching
	-- the box below; upstream (animalworld, already a mobs_redo def) uses 1.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5},
	makes_footstep_sound = true,

	-- wp6_model_notes §2.1: no run range — walk at a higher speed (§0.2).
	-- The upstream die range overlaps punch; transcribed as-is is upstream's
	-- own data, and we leave die_* out entirely (mobs_redo then just removes
	-- the corpse).
	animation = {
		speed_normal = 75,
		stand_start = 0, stand_end = 100,
		walk_start = 150, walk_end = 250,
		run_start = 150, run_end = 250, run_speed = 150,
		punch_start = 250, punch_end = 350,
	},

	-- Wolf table (§3.2), identical to wolf.lua.
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
		{name = "mobs:leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:fang", chance = 3, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.pack_hunter(hyena, {})
grug_mobs.register_mob("grug_mobs:hyena", hyena)

-- §4 row "Hyena | dry grass, mesa_clay | 20 | 1500 | 5 | any | inner, outer".
-- "any light" = no min_light/max_light and no day_toggle: 24 h (§3.1).
mobs:spawn({
	name = "grug_mobs:hyena",
	nodes = {
		"default:dry_dirt_with_dry_grass", -- grug_savanna
		"grug_nodes:mesa_clay", -- grug_badlands
	},
	interval = 20,
	chance = 1500,
	active_object_count = 5,
	min_height = 0,
	max_height = 200,
})
