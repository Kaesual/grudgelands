-- Race passives (docs/design/world.md §7, WP19). Each race def carries a
-- `perks` table; consumers query single values via get_race_perk (also
-- exposed as the grug_core stub override, so mods below grug_classes in the
-- dependency graph can read perks too).
--
-- Perk keys in use:
--   fall_damage_mult        (dwarf 0.8)  — grug_core/combat.lua hp modifier
--   ooc_regen_mult          (troll 1.5)  — out-of-combat resource regen in
--                           grug_abilities; today this is MANA only (HP
--                           regen does not exist yet) — WP21's HP regen
--                           MUST consume the same perk
--   zombie_night_truce      (undead)     — zombies drop unprovoked undead
--                           targets at night (grug_mobs)
--   rage_per_hit_taken_bonus (orc 1)     — extra rage per hit taken
--                           (grug_abilities)
--   ability_range_bonus     (elf 5)      — added to every ability item's
--                           pointing/targeting range (grug_abilities)
--   quest_xp_mult           (human 1.1)  — via get_xp_bonus below; LATENT
--                           until quests exist (WP8 passes source="quest")

function grug_classes.get_race_perk(player, key)
	local def = grug_classes.get_race_def(player)
	local perks = def and def.perks
	if perks then
		return perks[key]
	end
	return nil
end

-- Stub override (same pattern as grug_core.get_crit_chance).
grug_core.get_race_perk = grug_classes.get_race_perk

-- XP multiplier for an XP source (e.g. "quest"). Consumed by
-- grug_xp.add_xp(player, amount, source); today nothing passes a source
-- yet — the human quest-XP passive becomes active with the quest
-- framework (WP8) for free.
function grug_classes.get_xp_bonus(player, source)
	if source == "quest" then
		return grug_classes.get_race_perk(player, "quest_xp_mult") or 1
	end
	return 1
end
