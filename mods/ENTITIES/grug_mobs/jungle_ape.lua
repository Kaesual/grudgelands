-- Jungle Ape (docs/design/biomes_mobs.md §3.1, jungle group) — the jungle
-- mirror of the Bear: same "territorial" verb, same shared BEAR drop table
-- (§3.2 "bear table | Bear/Elder Bear | Plaguehide Bear, Jungle Ape/
-- Silverback"), plus its own ape-hair trophy.
--
-- Verb "territorial": not a helper in verbs.lua but the aggro field
-- _grug_leash_range (aggro.lua) — an ape gives up after 20 nodes instead of
-- the default 40, so leaving its patch is enough. Identical to bear.lua.
--
-- Elite variant "Silverback" (§3.1, ×1.6 scale): rolled per spawn in the
-- mobs:spawn row below, no second registration and no extra texture
-- (wp6_model_notes §0.4 — elites are a runtime tint + scale).
--
-- ONE registration for both continents (§8.4: the Accord jungle fringe reuses
-- the troll jungle nodes 1:1; §3.2 shares the jungle tables).

local SILVERBACK_CHANCE = 10 -- 1 in 10 spawns is a Silverback (elite tier)

local ape = {
	description = "Jungle Ape",
	type = "monster",
	_grug_spawn_zones = {"outer", "coast"},
	-- Territorial: short leash instead of the default 40 nodes (aggro.lua,
	-- combat_stats.md §4) — the same value bear.lua uses.
	_grug_leash_range = 20,
	-- HP/damage/XP/armor: engine-owned (levels.lua).

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true, -- as bear.lua; troop animals pile on
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 4.4, -- aggressive-mob speed (§0)
	-- wp6_model_notes §2.7: upstream gives this mesh stepheight 3 and
	-- jump_height 8 — an ape climbs terrain a bear cannot.
	jump = true,
	jump_height = 8,
	stepheight = 3,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 12, -- territorial: notices you late, then commits

	visual = "mesh",
	mesh = "grug_mobs_jungle_ape.b3d",
	textures = {{"grug_mobs_jungle_ape.png"}},
	-- Mesh scale rule (boar.lua): 8.58 units = 0.86 nodes at size 1 and
	-- upstream (animalworld) uses 1 — but the design wants the monkey mesh
	-- "upscaled" into an ape (§3.1 model column), and wp6_model_notes §2.7
	-- asks T6 for >= 1.5. 1.5 puts the mesh at 1.29 rendered nodes; the box
	-- is scaled with it so model and collisionbox stay in sync (the same rule
	-- spider.lua applied to the Giant Spider).
	visual_size = {x = 1.5, y = 1.5},
	collisionbox = {-0.75, -0.01, -0.75, 0.75, 1.43, 0.75},
	makes_footstep_sound = true,

	-- wp6_model_notes §2.7: stand does NOT start at 0 on this mesh, and no
	-- run range exists — walk at a higher speed (§0.2). `shoot` is upstream's
	-- dung-throwing clip whose projectile was not imported, so it stays
	-- unmapped.
	animation = {
		speed_normal = 100,
		stand_start = 350, stand_end = 450, stand_speed = 75,
		walk_start = 0, walk_end = 100,
		run_start = 0, run_end = 100, run_speed = 150,
		punch_start = 100, punch_end = 200,
	},

	-- Bear table (§3.2), identical to bear.lua, plus the ape-hair trophy of
	-- the §3.1 jungle row ("meat x2; heavy leather 1/2; ape hair 1/4").
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 2, max = 2},
		{name = "grug_mobs:heavy_leather", chance = 2, min = 1, max = 1},
		{name = "grug_mobs:ape_hair", chance = 4, min = 1, max = 1},
	},

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:jungle_ape", ape)

-- Silverback roll, identical in shape to bear.lua's elder_roll: mobs_redo
-- calls on_spawn(luaentity, pos) right after core.add_entity (api.lua:3686),
-- i.e. AFTER on_activate but BEFORE the first on_step — so before
-- grug_mobs.ensure_init has assigned a level. grug_mobs.set_tier documents
-- exactly that case: with no _grug_level yet it only records the tier, and
-- ensure_init then applies level, elite multipliers, x1.6 scale, gold tint
-- and nametag together on the first tick. `description` is a plain entity
-- field (levels.lua tag_text reads it) and is set first, so the very first
-- nametag already says "Elite Silverback". Both fields persist in staticdata.
local function silverback_roll(ent)
	if not ent or math.random(SILVERBACK_CHANCE) ~= 1 then
		return
	end
	ent.description = "Silverback"
	grug_mobs.set_tier(ent, "elite")
end

-- §4 row "Jungle Ape | rainforest litter | 20 | 2800 | 2 | min 10 | outer,
-- coast".
mobs:spawn({
	name = "grug_mobs:jungle_ape",
	nodes = {"default:dirt_with_rainforest_litter"},
	min_light = 10,
	interval = 20,
	chance = 2800,
	active_object_count = 2,
	min_height = 0,
	max_height = 200,
	on_spawn = silverback_roll,
})
