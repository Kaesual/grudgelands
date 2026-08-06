-- Race passives (docs/design/world.md §7, WP19). Each race def carries a
-- `perks` table; consumers query single values via get_race_perk (also
-- exposed as the wob_core stub override, so mods below wob_classes in the
-- dependency graph can read perks too).
--
-- Perk keys in use:
--   fall_damage_mult        (dwarf 0.8)  — wob_core/combat.lua hp modifier
--   ooc_regen_mult          (troll 1.5)  — out-of-combat resource regen in
--                           wob_abilities; today this is MANA only (HP
--                           regen does not exist yet) — WP21's HP regen
--                           MUST consume the same perk
--   zombie_night_truce      (undead)     — zombies drop unprovoked undead
--                           targets at night (wob_mobs)
--   rage_per_hit_taken_bonus (orc 1)     — extra rage per hit taken
--                           (wob_abilities)
--   ability_range_bonus     (elf 5)      — added to every ability item's
--                           pointing/targeting range (wob_abilities)
--   quest_xp_mult           (human 1.1)  — via get_xp_bonus below; LATENT
--                           until quests exist (WP8 passes source="quest")

function wob_classes.get_race_perk(player, key)
	local def = wob_classes.get_race_def(player)
	local perks = def and def.perks
	if perks then
		return perks[key]
	end
	return nil
end

-- Stub override (same pattern as wob_core.get_crit_chance).
wob_core.get_race_perk = wob_classes.get_race_perk

-- XP multiplier for an XP source (e.g. "quest"). Consumed by
-- wob_xp.add_xp(player, amount, source); today nothing passes a source
-- yet — the human quest-XP passive becomes active with the quest
-- framework (WP8) for free.
function wob_classes.get_xp_bonus(player, source)
	if source == "quest" then
		return wob_classes.get_race_perk(player, "quest_xp_mult") or 1
	end
	return 1
end
