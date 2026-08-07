-- Stone Golem / Mesa Golem (docs/design/biomes_mobs.md §3.1, mountain pair).
-- Verb: "hurls rocks (dogshoot)" — mostly ranged, melee when cornered, same
-- shape as skeleton_archer.lua.
--
-- The ONLY family in the catalog that ships as tier ELITE out of the box
-- (§3.1: "**elite** (armor 80, telegraphed slam)"). `_grug_tier = "elite"` in
-- the def is the whole implementation: levels.lua then owns armor 80, the
-- x3 HP / x1.8 damage / x4 XP multipliers, the x1.6 scale, the gold tint and
-- the "Elite " nametag prefix — and init.lua's do_custom wrapper starts
-- calling telegraph.lua for it, which IS the "telegraphed slam" of the design
-- row: 2 s wind-up (root + "!! " nametag + particle burst), then a x3 damage
-- frontal cone. NB the telegraph only arms in MELEE (telegraph.lua checks
-- reach * 2), so a golem keeping its distance never winds up into empty air —
-- the slam is the punishment for standing next to it, exactly as intended.

--
-- Projectile
--
-- Damage is stamped at FIRE time from the shooter's level-scaled `damage`
-- (grug_mobs.stamp_arrow_damage, installed as arrow_override below), so an
-- elite golem's rock hits for an elite golem's damage without a number in
-- this file. Slower than the skeleton's arrow (12 vs 16): a thrown boulder
-- should be dodgeable.
grug_mobs.register_simple_arrow("grug_mobs:rock_entity", {
	texture = "grug_mobs_rock.png",
	velocity = 12,
	size = {x = 0.5, y = 0.5},
	lifetime = 4,
})

-- Continent gate. Unlike every T5 family, the golem pair cannot be split by
-- its spawn nodes alone: §4 lists `default:stone` for both halves and bare
-- rock exists on both continents, so a node-only split would let Stone Golems
-- spawn in the badlands and Mesa Golems in the crags. _grug_spawn_check is
-- registered per mob NAME (init.lua) and ANDed with the zone gate, which is
-- exactly the granularity needed here.
local function on_continent(territory)
	return function(pos)
		return grug_core.territory_at(pos) == territory
	end
end

local function golem_def(description, texture)
	return {
		description = description,
		type = "monster",
		-- Elite by design (§3.1). Everything the tier implies is engine-owned
		-- (levels.lua): do NOT add armor/hp/damage here.
		_grug_tier = "elite",
		-- "outer, coast" is the surface half of the §4 row; "underground" is
		-- declared here (and not only in the row below) because
		-- _grug_spawn_zones is registered per mob NAME in init.lua — without
		-- it, T7's cave row would be rejected by spawn_abm_check. Same
		-- forward declaration spider.lua makes. Cave rows/tuning stay
		-- T7/T10's business.
		_grug_spawn_zones = {"outer", "coast", "underground"},

		reach = 2,
		attack_type = "dogshoot",
		attack_players = true,
		-- Solitary: golems do not gang up (§3 "group_attack per verb").
		group_attack = false,
		pathfinding = 1,

		-- Ranged loadout, same reading as skeleton_archer.lua:
		-- dogshoot_switch = 1 opens in the RANGED phase, then mobs_redo
		-- alternates dogshoot_count_max seconds of shooting with
		-- dogshoot_count2_max seconds of melee — 10 vs 3 is "mostly ranged",
		-- and a target inside `reach` forces melee regardless (api.lua:2249).
		arrow = "grug_mobs:rock_entity",
		arrow_override = grug_mobs.stamp_arrow_damage,
		shoot_interval = 3,
		-- Aim lift. mobs_redo spawns the projectile at the collisionbox
		-- midpoint (api.lua:2424) and aims at target_feet - 0.5 from
		-- self_origin + 0.5 (api.lua:2407). This mesh has a NEGATIVE-y box
		-- (see below), so the origin sits 1 node above the golem's feet and
		-- the aim vector points ~2 nodes DOWN for a target on the same
		-- ground: +2 cancels that and the rock flies flat into the torso.
		-- The correction is distance-independent (the same constant vec.y).
		shoot_offset = 2,
		dogshoot_switch = 1,
		dogshoot_count_max = 10,
		dogshoot_count2_max = 3,

		-- §3.1 speed column: 3.0. SPEC EXCEPTION, noted here on purpose —
		-- this is the one aggressive family below the 4.4 baseline of §0.
		-- It is deliberate: a golem is meant to be outrun, which is why it
		-- throws rocks. No _grug_soft_deaggro opt-out either — the 25 m rule
		-- drops a chaser to walk speed, and walk 1 vs run 3.0 is exactly the
		-- "you got away" the rule is for.
		walk_velocity = 1,
		run_velocity = 3.0,
		-- Upstream mobs_monster: it steps, it does not jump
		-- (wp6_model_notes §4.2).
		jump = false,
		stepheight = 1.1,
		-- The ONE aggressive family that does NOT get T10's cliff rule of 6
		-- (boar.lua). Two reasons, both specific to this def: it is `jump =
		-- false`, so stepheight 1.1 is its only way back UP and a deeper drop
		-- is a one-way trip into a pit where nothing can reach it; and it is
		-- `dogshoot` — a ledge is no exploit against a mob that answers by
		-- throwing rocks over it. 4 also keeps the max_drop it hands to
		-- core.find_path shallow enough that a non-jumper stays mobile.
		fear_height = 4,
		view_range = 14,

		visual = "mesh",
		mesh = "grug_mobs_stone_golem.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): 17.24 units = 1.72 nodes at size 1
		-- against the box below; upstream uses 1. The elite tier multiplies
		-- both by 1.6 at runtime (levels.lua), so this is the NORMAL-tier
		-- geometry and must stay that way.
		visual_size = {x = 1, y = 1},
		-- Negative y: the mesh spans -10.0..+7.24 units around its origin
		-- (wp6_model_notes §4.2). Do not "fix" this to a 0-based box.
		collisionbox = {-0.3, -1, -0.3, 0.3, 0.7, 0.3},
		makes_footstep_sound = true,

		-- wp6_model_notes §4.2 (mobs_monster ranges, native mobs_redo).
		animation = {
			speed_normal = 15, speed_run = 15,
			stand_start = 0, stand_end = 14,
			walk_start = 15, walk_end = 38,
			run_start = 40, run_end = 63, run_speed = 40,
			punch_start = 40, punch_end = 63,
			-- No dedicated throw clip on this mesh — the punch swing doubles
			-- as the shoot animation (§0.2 rule).
			shoot_start = 40, shoot_end = 63,
		},

		-- Golem table (§3.2): shared verbatim between Stone and Mesa Golem.
		-- "gem" is the design's working item name; default:diamond is the
		-- stand-in until items_crafting.md decides the real gem line.
		drops = {
			{name = "grug_mobs:stone_core", chance = 1, min = 1, max = 1},
			{name = "default:iron_lump", chance = 2, min = 1, max = 1},
			{name = "default:diamond", chance = 8, min = 1, max = 1},
		},

		water_damage = 0,
		-- 4 like every other family, deliberately NOT 0: mobs_redo's
		-- is_node_dangerous reads lava_damage to keep a mob away from lava
		-- (api.lua:899ff), and a lava-immune golem would happily park itself
		-- in a lava lake where nothing can reach it. Flavour loses to
		-- reachability here.
		lava_damage = 4,
		light_damage = 0,
	}
end

--
-- Stone Golem — grug_crags (Accord)
--

local stone_golem = golem_def("Stone Golem", "grug_mobs_stone_golem.png")
stone_golem._grug_spawn_check = on_continent("accord")
grug_mobs.register_mob("grug_mobs:stone_golem", stone_golem)

-- §4 row "Stone/Mesa Golem (elite) | gravel, stone, mesa_clay | 30 | 9000 |
-- 1 | any | outer, coast, underground", split by continent-side top node;
-- default:stone is shared (bare crag/mesa rock) and therefore listed in both
-- rows, with the continent check above keeping each golem on its own side.
-- mobs_redo counts the aoc per entity NAME, so neither row can exceed 1
-- active golem.
-- "any light" = no min_light/max_light and no day_toggle: 24 h.
-- max_height 300 per §4's crags/golem exception; min_height 0 keeps this row
-- on the surface — the cave row (same nodes, negative heights) is T7's,
-- which is why the zone list above already allows "underground".
--
-- ABM CANDIDATE VOLUME (T10 sanity check, the same argument the cave rows
-- make in zombie.lua): `default:stone` between y 0 and 300 is not "the whole
-- world". mobs:spawn defaults the ABM's neighbour list to {"air"}
-- (api.lua:3729), so only stone with air beside it counts — on the surface
-- that is exposed bare rock, which the crags/badlands cuboids produce in
-- patches and the rest of the world barely at all. On top of that this row is
-- interval 30 / chance 9000 (the rarest in the roster) and gated to the outer
-- ring and one continent, and the check order in api.lua spends the cheap
-- tests first: active-object count, mob_active_limit, then our arithmetic
-- zone_at/territory_at check, and only afterwards the light/space/player
-- queries that actually touch the map.
mobs:spawn({
	name = "grug_mobs:stone_golem",
	nodes = {
		"default:gravel", -- grug_crags
		"default:stone", -- bare rock in the crags
	},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = 0,
	max_height = 300,
})

--
-- Mesa Golem — grug_badlands (Throng)
--

local mesa_golem = golem_def("Mesa Golem", "grug_mobs_mesa_golem.png")
mesa_golem._grug_spawn_check = on_continent("throng")
grug_mobs.register_mob("grug_mobs:mesa_golem", mesa_golem)

mobs:spawn({
	name = "grug_mobs:mesa_golem",
	nodes = {
		"grug_nodes:mesa_clay", -- grug_badlands
		"default:stone", -- bare rock in the badlands
	},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = 0,
	max_height = 300,
})

--
-- CAVE ROWS (WP6/T7) — §3.1's cave paragraph, §4 zone column "outer, coast,
-- underground". Level, height math, day_toggle and the `default:stone`
-- performance question are explained once at the cave row in zombie.lua.
--
-- TWO rows, one per golem, because the mesa/stone split by TERRITORY holds
-- underground too: caves under the Accord belong to the Stone Golem, caves
-- under the Throng to the Mesa Golem. That needs no new code — the per-name
-- _grug_spawn_check installed above (on_continent) is ANDed with the zone
-- gate by mobs:spawn_abm_check (init.lua) for every row of that mob, so both
-- rows below are already continent-gated. grug_core.territory_at works on
-- x/z only, so it answers the same underground as it does on the surface.
--
-- The elite tier travels with the def, so a cave golem is an elite golem —
-- and thanks to the depth axis a deep one is a HIGH-level elite. §4's row
-- numbers (interval 30 / chance 9000 / aoc 1, any light) are kept verbatim;
-- with aoc counted per entity name, surface and cave rows share the cap of 1
-- active golem per area, which is exactly what makes that number safe.
--
mobs:spawn({
	name = "grug_mobs:stone_golem",
	nodes = {"default:stone"},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = -31000,
	max_height = -40,
})

mobs:spawn({
	name = "grug_mobs:mesa_golem",
	nodes = {"default:stone"},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = -31000,
	max_height = -40,
})
