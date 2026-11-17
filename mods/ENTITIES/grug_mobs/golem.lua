-- Stone Golem / Mesa Golem (docs/design/biomes_mobs.md §3.1, mountain pair).
-- Verb: "hurls rocks (dogshoot)" — mostly ranged, melee when cornered, same
-- shape as skeleton_archer.lua.
--
-- The ONLY family in the catalog that ships as tier ELITE out of the box
-- (§3.1: "**elite** (armor 80, telegraphed slam)"). `_grug_tier = "elite"` in
-- the def is the whole implementation: levels.lua then owns armor 80, the
-- x3 HP / x1.8 damage / x4 XP multipliers, the x1.4 scale, the gold tint and
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
-- this file. Slower than the skeleton's arrow (12 vs 16). A rock homes on its
-- target like every shot (combat_stats.md): only cover before the throw avoids it.
grug_mobs.register_simple_arrow("grug_mobs:rock_entity", {
	label = "a hurled rock",
	texture = "grug_mobs_rock.png",
	velocity = 12,
	size = {x = 0.5, y = 0.5},
	lifetime = 4,
	impact = "#8a8a8a", -- grey dust (Round 40 PM)
})

-- Race-region side gate for the cave rows below. The golem pair cannot be
-- split by its spawn nodes: both rows host on `default:stone` and the
-- stratum rock, which exist under both continents, so a node-only split would
-- let Stone Golems spawn under the badlands and Mesa Golems under the crags.
-- Contested zones have no political faction, so the stable cultural race
-- region supplies the side. _grug_spawn_check is registered per mob NAME
-- (init.lua) and ANDed with the spawn policy, which is exactly the
-- granularity needed here.

local function in_faction_region(faction_id)
	return function(pos)
		return grug_mobs.race_region_spawn_allows(faction_id, pos)
	end
end

local function golem_def(description, texture)
	return {
		description = description,
		_grug_voice = "elemental",
		clock = "any",
		type = "monster",
		-- Elite by design (§3.1). Everything the tier implies is engine-owned
		-- (levels.lua): do NOT add armor/hp/damage here.
		_grug_tier = "elite",

		reach = 3,
		attack_type = "dogshoot",
		attack_players = true,
		-- Solitary: golems do not gang up (§3 "group_attack per verb").
		group_attack = false,
		pathfinding = 1,

		-- Ranged loadout, same reading as skeleton_archer.lua:
		-- dogshoot_switch = 1 opens in the RANGED mode; since Round 78 the mode
		-- follows the distance (mobs/api.lua grug_dogshoot_mode: melee inside
		-- 4 nodes edge to edge, ranged beyond 6, the mode kept between).
		arrow = "grug_mobs:rock_entity",
		arrow_override = grug_mobs.stamp_arrow_damage,
		shoot_interval = 3,
		-- Aim lift. mobs_redo spawns the projectile at the collisionbox
		-- midpoint (api.lua do_states) and aims at target_feet - 0.5 from
		-- self_origin + 0.5 (api.lua do_states). This mesh has a NEGATIVE-y box
		-- (see below), so the origin sits 1 node above the golem's feet and
		-- the aim vector points ~2 nodes DOWN for a target on the same
		-- ground: +2 cancels that and the rock flies flat into the torso.
		-- The correction is distance-independent (the same constant vec.y).
		shoot_offset = 2,
		dogshoot_switch = 1,

		-- Ranged golems retain their rock attack, but their contact run now uses
		-- the same 4.6 floor as every melee-capable attacker. The 25 m soft
		-- de-aggro still drops a distant chaser to walk speed.
		walk_velocity = 1,
		run_velocity = 4.6,
		-- Upstream mobs_monster: it steps, it does not jump
		-- (wp6_model_notes §4.2).
		jump = false,
		stepheight = 1.1,
		-- Exception to T10's cliff rule of 6 (boar.lua). The original note
		-- here leaned on `jump = false`, which is NOT a real argument:
		-- mobs_redo never reads a `jump` field (do_jump gates on
		-- jump_height/stepheight and on the node in front), so the field above
		-- is inert documentation, and this def carries the same default
		-- jump_height 4 as everything else. The reasons that DO hold are:
		--   * a dogshoot mob searches only to regain sight of its target and in
		--     in melee (Round 49 NAV2; before, never), so the
		--     "fear_height doubles as find_path's max_drop" half of the cliff
		--     rule matters little to it — 4 vs 6 only keeps its short detours
		--     off deeper drops, and is_at_cliff stops it there;
		--   * and the cliff rule exists to close a terrain EXPLOIT, which a
		--     ranged elite does not have: a player on a ledge above a golem is
		--     in its firing line, not out of its reach. Keeping it out of deep
		--     pits it would have to step-climb back out of (stepheight 1.1) is
		--     worth more than two nodes of chase.
		fear_height = 4,
		-- 14 -> 16 (2026-09-16, user ruling 3): a `dogshoot` family sees 16
		-- and a melee family 10-14 by habitat, and the golem was the one
		-- ranged mob in the roster that did not follow its own rule -- the
		-- skeleton archer and raider already carry 16 with that reason in
		-- their comments (biomes_mobs.md §3.1, combat_stats.md §3). 16 is the
		-- ceiling for a land mob, not a step toward more: the 45 m chase
		-- give-up and the 40 m leash of combat_stats.md §4 both need the mob
		-- to keep a target it can no longer see.
		view_range = 16,

		visual = "mesh",
		mesh = "grug_mobs_stone_golem.b3d",
		textures = {{texture}},
		-- Mesh scale rule (boar.lua): 17.24 units = 1.72 nodes at size 1
		-- against the box below; upstream uses 1. The elite tier multiplies
		-- both by 1.4 at runtime (levels.lua), so this is the NORMAL-tier
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
		-- The sell-only stone core no longer drops (Round 46 ruling 12).
		drops = {
			{name = "default:iron_lump", chance = 2, min = 1, max = 1},
			{name = "grug_materials:rough_citrine", chance = 8, min = 1, max = 1},
		},

		water_damage = 0,
		-- 4 like every other family, deliberately NOT 0: mobs_redo's
		-- is_node_dangerous reads lava_damage to keep a mob away from lava
		-- (api.lua is_node_dangerous), and a lava-immune golem would happily park itself
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
stone_golem._grug_spawn_check = in_faction_region("accord")
grug_mobs.register_mob("grug_mobs:stone_golem", stone_golem)

--
-- Mesa Golem — grug_badlands (Throng)
--

local mesa_golem = golem_def("Mesa Golem", "grug_mobs_mesa_golem.png")
mesa_golem._grug_spawn_check = in_faction_region("throng")
grug_mobs.register_mob("grug_mobs:mesa_golem", mesa_golem)

--
-- Flintback (Round 71): the boss of The Stilled Seam, the level 20 Expedition
-- (docs/planning/round71-l20-description.md), on the Stone Golem's body and
-- attacks: no adds, no phases, no new look, no spawn row. grug_expeditions places
-- it by its template's boss marker, as an elite at the run's level; only the HP
-- factor sets it apart (tools/r71_l20/balance.py). It stands on the working face
-- until someone comes, and drops nothing: the reward room pays.
--

local flintback = golem_def("Flintback", "grug_mobs_stone_golem.png")
flintback._grug_hp_scale = 8
flintback.walk_chance = 0
flintback.drops = {}
grug_mobs.register_mob("grug_mobs:flintback", flintback)

--
-- CAVE ROWS (WP6/T7) — §3.1's cave paragraph, §4 zone column "outer, coast,
-- underground"; the golems' only spawn rows since Round 81 (their surface
-- rows went with ruling 6). Level, height math, day_toggle and the `default:stone`
-- performance question are explained once at the cave row in zombie.lua.
--
-- TWO rows, one per golem, because the mesa/stone split by TERRITORY holds
-- underground too: caves under the Accord belong to the Stone Golem, caves
-- under the Throng to the Mesa Golem. That needs no new code — the per-name
-- _grug_spawn_check installed above (in_faction_region) is ANDed with the zone
-- gate by mobs:spawn_abm_check (init.lua) for every row of that mob, so both
-- rows below are already side-gated by grug_zones.race_region_at.
-- x/z only, so it answers the same underground as it does on the surface.
--
-- The elite tier travels with the def, so a cave golem is an elite golem —
-- and thanks to the depth axis a deep one is a HIGH-level elite. §4's row
-- numbers (interval 30 / chance 9000 / aoc 1, any light) are kept verbatim;
-- aoc is counted per entity name, so one active golem of each name per area.
--
mobs:spawn({
	name = "grug_mobs:stone_golem",
	-- group:grug_stratum is the tier-2..6 rock (WP25): below -100 there is no
	-- default:stone left, so without the group this row would only ever fire
	-- between -2 and -100 and the depth axis of combat_stats.md §3 would be
	-- dead. default:stone stays for the tier-1 band above -100. No light
	-- gate (any light) and an elite: spawn_policy.lua refuses it underground
	-- below the elite floor (Round 46).
	nodes = {"default:stone", "group:grug_stratum"},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = -31000,
	max_height = -1,
})

mobs:spawn({
	name = "grug_mobs:mesa_golem",
	-- Same reason as the stone golem row above: the deep half of the cave
	-- system is stratum rock, not default:stone.
	nodes = {"default:stone", "group:grug_stratum"},
	interval = 30,
	chance = 9000,
	active_object_count = 1,
	min_height = -31000,
	max_height = -1,
})
