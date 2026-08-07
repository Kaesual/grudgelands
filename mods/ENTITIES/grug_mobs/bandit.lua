-- Bandit (docs/design/biomes_mobs.md §3.1, settled-biome row: "Bandit (camp
-- humanoid; camps placed by §1.4, inner+outer, both continents) | defends
-- camp (leashes to camp, group) | 24 h | 4.4 | linen cloth 1/1 x1-2 (inner
-- camps) / heavy cloth (outer camps); copper coins").
--
-- NO mobs:spawn ROW — that is the design, not an omission: §4's row for this
-- family reads "Bandits / Mirefolk | **no ABM** — camp node timer respawns
-- 120-300 s, anchored to camp, 3-5 per camp". Every bandit in the world
-- comes out of a camp fire (camps.lua), which is also what gives it its
-- `_grug_home` and `_grug_camp_pos`.
--
-- MESH: `character.b3d`, the engine/MTG player model, referenced BY NAME.
-- Luanti's media namespace is FLAT — every mod's media is served under its
-- bare file name, so a mob in grug_mobs may point at a mesh that physically
-- lives in mods/BASE/player_api/models without copying it (wp6_model_notes
-- §5: "Do not copy it into grug_mobs; just reference mesh = 'character.b3d'").
-- grug_mobs declares player_api in mod.conf `depends` so the relationship is
-- visible in the dependency graph, even though media transfer would work
-- without it.
--
-- The verb "defends camp" is not a verbs.lua helper but two aggro fields:
-- `_grug_leash_range` (aggro.lua) plus the camp position that camps.lua
-- writes into `_grug_home` — together they ARE "leashes to camp". The
-- "group" half is mobs_redo's own group_attack.

local bandit = {
	description = "Bandit",
	type = "monster",
	-- No _grug_spawn_zones: that list only gates the spawn ABM
	-- (mobs:spawn_abm_check, init.lua) and this family has no ABM. Where
	-- bandit camps may stand is a WP13 settlement-pass decision (§3.1:
	-- inner+outer, both continents), enforced there, not here.
	--
	-- HP/damage/XP/armor: engine-owned (levels.lua) from the camp position,
	-- so an outer-ring camp is genuinely harder than an inner one — the same
	-- gradient the drop table below follows.

	-- Camp anchored (§4 "anchored to camp"): 25 nodes instead of the default
	-- 40, so a bandit chases you off its camp and then goes home to heal
	-- rather than following you across the ring (aggro.lua).
	_grug_leash_range = 25,

	reach = 2,
	attack_type = "dogfight",
	attack_players = true,
	group_attack = true, -- "(leashes to camp, group)"
	pathfinding = 1,

	walk_velocity = 1,
	run_velocity = 4.4, -- aggressive-mob speed (§0)
	jump = true,
	jump_height = 4,
	stepheight = 1.1,
	fear_height = 6, -- T10 cliff rule (boar.lua): follow the drops players take
	view_range = 14,

	visual = "mesh",
	mesh = "character.b3d",
	-- TWO texture sets, not two registrations: mobs_redo picks one at random
	-- per spawned mob (api.lua:2913, `def.textures[random(#def.textures)]`),
	-- which is exactly wp6_model_notes §5's "second skin so a camp is not
	-- four clones" — and it costs camps.lua nothing, it passes no texture.
	textures = {
		{"grug_mobs_bandit_1.png"},
		{"grug_mobs_bandit_2.png"},
	},
	-- The player's own geometry (wp6_model_notes §5, cross-checked against
	-- mods/BASE/player_api/init.lua): the mesh measures 17.0 units = 1.70
	-- nodes at size 1, and 1.70 is the player collisionbox height.
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
	makes_footstep_sound = true,

	-- Frame ranges from mods/BASE/player_api/init.lua via wp6_model_notes §5:
	-- stand 0-79, walk 168-187, mine 189-198 (used as the punch clip),
	-- walk_mine 200-219 and sit/lay are not wired up.
	animation = {
		stand_start = 0, stand_end = 79, stand_speed = 30,
		walk_start = 168, walk_end = 187, walk_speed = 30,
		run_start = 168, run_end = 187, run_speed = 45,
		punch_start = 189, punch_end = 198, punch_speed = 30,
	},

	-- LEVEL-DEPENDENT LOOT (§3.1: "linen cloth 1/1 x1-2 (inner camps) /
	-- heavy cloth (outer camps)"). mobs_redo supports a `drops` FUNCTION and
	-- calls it with the death position only (api.lua:696-699,
	-- `drops = self.drops(pos)`), which is all we need — grug_core.zone_at
	-- answers from the position.
	--
	-- ORDER MATTERS and it is the right way round: api.lua resolves the
	-- function FIRST (line 699) and only then hands the resulting list to the
	-- WP6 GRUG PATCH (line ~713 -> grug_mobs._item_drop_filter, aggro.lua).
	-- So the player-tag rule and the profession drop hooks see this list
	-- exactly as if it had been written literally in the def; a Leatherworker
	-- hook could multiply it, and an untagged bandit drops nothing at all.
	--
	-- Copper coins (the second half of the §3.1 row) are deferred to WP7:
	-- money is one integer in player meta (economy.md §1), there is no coin
	-- ITEM to drop yet.
	drops = function(pos)
		local zone = grug_core.zone_at(pos)
		-- "inner camps" vs. "outer camps" of §3.1, read against the
		-- _grug_spawn_zones vocabulary (§1.1): core/inner are the settled
		-- rings, everything further out (outer, coast, war_coast, strait,
		-- underground) gets the heavy cloth of the wilderness camps. §6 backs
		-- this: "Linen cloth | 10-30 | bandit camps", "Heavy cloth | 25-45 |
		-- outer bandit camps".
		local cloth = "grug_mobs:heavy_cloth"
		if zone == "core" or zone == "inner" then
			cloth = "grug_mobs:linen_cloth"
		end
		-- Static drop-list format (name/chance/min/max), because everything
		-- downstream — the filter, the hooks and mobs_redo's own roll — reads
		-- exactly that shape.
		return {
			{name = cloth, chance = 1, min = 1, max = 2},
		}
	end,

	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
}

grug_mobs.register_mob("grug_mobs:bandit", bandit)
