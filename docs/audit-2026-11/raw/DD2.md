# DD2 — Design documents, combat and character, against the code

- Finder model: claude-opus-5-5
- Files read in full: (in progress)
- Summary: (in progress)

## Findings (draft, in progress)

- combat_stats.md §3 "Speed" (l.555-564): "every melee attacker has run_velocity at least 4.6 ... including retaliating passive prey"; code: Lava Flan 3.4 (`mods/ENTITIES/grug_mobs/lava_flan.lua:8`, monster, dogfight), Frog 3.4 (`frog.lua:37`), Tortoise 2 (`tortoise.lua:35`), Shore Crab 3.4 (`shore_crab.lua:29`); biomes_mobs.md documents frog/tortoise/crab speeds, so combat_stats is stale.
- combat_stats.md §3 "Reach" (l.577-579): "every ordinary explicit mob reach is 3 m" (Kraken 4, villagers 0); code has reach 2 on stingray, frog, glowwing, ember wisp, tortoise, night_families wisp, three zero_asset_variants, shark 4, dragon 6.
- combat_stats.md TTK table (l.832-854) vs "Global non-player damage scale" (l.1603-1613): pressure fit (combat.lua:182-192) targets unscaled damage; actual mob damage is ×1.5 by default (levels.lua:127-141); raw TTD band 25-30 s holds only at scale 1.0.
- combat_stats.md §6 l.1549-1551 "no extra damage modifier for high-level mobs" vs §2 l.121-125 level malus (combat.lua:143-150).
- dead: `combat_mana_regen_add` (grug_abilities/init.lua:147-161) no producer; `crit_cap_override`, `crit_chance_add_window`, `dodge_chance_window` (grug_classes/stats.lua:146,153,162) no producer; status `dodge_percent` (stats.lua:155) rejected by status.lua MODIFIER_KEYS:22-28.
