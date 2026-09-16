-- Bandit Archer (docs/design/biomes_mobs.md §3.1, settled-biome rows, added
-- 2026-09-16 for user ruling 3 of the mob-pressure round: "more ranged mobs,
-- with a larger view range than melee mobs, so ranged players and the Mage
-- take damage sooner").
--
-- Before this file the whole roster held FOUR registered ranged mobs out of
-- 43 -- skeleton archer, skeleton raider, stone golem and mesa golem, from
-- three definition sites. Every one of them lives in the outer ring or on the
-- war coast, so a player never met a ranged enemy below roughly level 25. The
-- bandit camp is the cheapest place to fix that: it already exists in the
-- INNER ring on both continents, it already has a respawn-slot mechanism, and
-- an archer beside the brawlers needs no new art at all -- the same
-- `character.b3d` people, the same skins, and the arrow entity the skeleton
-- archer already registers.
--
-- WHAT IT SHARES with grug_mobs:bandit, by construction rather than by
-- copying: `grug_mobs.bandit_def()` (bandit.lua) builds one shape and this
-- file edits the ranged fields on its own copy. Leash range, camp anchoring,
-- level source, mesh, skins, race roll, collision box, animation and the
-- level-dependent cloth drop are therefore the bandit's, always.
--
-- WHAT DIFFERS, and why each one:
--
--   attack_type  `dogshoot` -- the same verb the skeleton archer carries.
--                Ranged until the target is close, then melee; the switch is
--                mobs_redo's `dogswitch` plus the hard rule that a target
--                inside `reach` forces melee regardless (api.lua:2366).
--   view_range   16 instead of the bandit's 14. That is the rule ruling 3
--                asks for, now written down in biomes_mobs.md §3.1 and
--                combat_stats.md §3: a `dogshoot` family sees 16, a melee
--                family 10-14 by habitat. 16 is also the working CEILING for
--                a land mob -- combat_stats.md §4 gives up a chase at 45 m
--                and leashes at 40, and both rules need the mob to keep a
--                target it can no longer see.
--   velocities   4.0 walk and run, exactly as the skeleton archer: "an archer
--                keeps its distance rather than sprinting". It is the one
--                mob in the camp a player can outrun, which is the point --
--                you close on the archer or you eat arrows.
--   drops        the bandit's table plus arrows 1/3, the skeleton archer's
--                own arrow row. An archer carries arrows.
--
-- The arrow is `grug_mobs:arrow_entity`, registered by skeleton_archer.lua
-- and referenced BY NAME, so no second projectile entity and no second
-- texture enter the game. `arrow_override = grug_mobs.stamp_arrow_damage`
-- stamps the SHOOTER's level-scaled damage onto each arrow at fire time, so
-- an outer-ring camp's archer hits for its own level and the level engine
-- stays the single source of truth (verbs.lua).
--
-- NO mobs:spawn ROW, for the same reason the bandit has none: §4 gives this
-- family "no ABM -- camp anchor with respawn slots". Archers come out of the
-- camp's own 3-5 slots (camps.lua `variant`), so the roster gains a family
-- and the spawn budget gains nothing.
--
-- VISUALS: `weapon_family = "dagger"`, the bandit's. grug_gear has four
-- weapon families and no bow (`grug_gear/init.lua` WEAPONS; bows are
-- catalogued as Phase-2 work in items_crafting.md §9), so an archer holds its
-- sidearm until that family exists. Deliberate and cosmetic -- the arrow
-- itself is a real projectile entity and needs no held model.

local archer = grug_mobs.bandit_def("Bandit Archer")

archer.attack_type = "dogshoot"
archer.arrow = "grug_mobs:arrow_entity"
archer.arrow_override = grug_mobs.stamp_arrow_damage
archer.shoot_interval = 2.5
-- Aim lift: the arrow spawns at body centre, and `character.b3d` is 1.70
-- nodes tall (bandit.lua), so without it every shot lands at the target's
-- feet. The skeleton archer uses 1.5 for a 1.98-node mesh; 1.3 is the same
-- fraction of this one.
archer.shoot_offset = 1.3
-- dogshoot_switch = 1 starts in the RANGED phase; 10 s shooting against 3 s
-- of melee is "mostly ranged" (golem.lua documents the three knobs).
archer.dogshoot_switch = 1
archer.dogshoot_count_max = 10
archer.dogshoot_count2_max = 3

archer.walk_velocity = 4.0
archer.run_velocity = 4.0
archer.view_range = 16 -- it shoots; it needs to see further than a brawler

local bandit_drops = archer.drops
archer.drops = function(pos)
	local drops = bandit_drops(pos)
	drops[#drops + 1] = {name = "grug_mobs:arrow", chance = 3, min = 1, max = 1}
	return drops
end

grug_mobs.register_mob("grug_mobs:bandit_archer", archer)
