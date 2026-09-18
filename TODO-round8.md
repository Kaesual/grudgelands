# TODO — Round 8 (rough plan): Cooking and Alchemy v1, the mapgen iteration, the first mob wave

Rough plan agreed with the user on 2026-09-18; the detailed lane briefs are
written when [Round 7](TODO-round7.md) has delivered its three plans
(`plants-and-potions-reference.md`, `cooking-alchemy-plan.md`,
`mob-worlds-plan.md`) and the user has ruled on their decision lists.
**Goal of Round 8: Cooking and Alchemy exist in a first complete version, on
a world whose plants, soils and shores support them.**

## 1. Lanes (order = dependency order where it matters)

1. **R8-MAP Mapgen iteration.** Per-zone variety in ground blocks and
   cover: sand along water (with bamboo and sugar cane where the plan puts
   them), more than one soil per zone, the wild plants and crop soils of the
   cooking plan, sand as the furnace's glass input. Shores keep Round 6's
   bank rule (bank at `water_y`, functional edges exempt); the shore
   MATERIAL rule is part of this lane (the user found stone where sand
   belongs). WP40 contract updates, fixture digests move, engine validation
   with all six capitals and the six-start gate. This is the riskiest lane
   of the round and merges first so the profession lanes place items on the
   real world.
2. **R8-COOK Cooking v1.** Recipe book (player book plus station books,
   Round 5 R22), the three qualities on real dishes, all six tiers from the
   plan with role dishes, raw-vs-cooked rule, minimum levels, tooltips that
   state instant value, tick effects, duration and the in-combat rule.
   Builds on Round 7's Food v2 core.
3. **R8-ALCH Alchemy v1.** Alchemy station, potions (low tiers, instant,
   shared 60 s cooldown, in-combat monopoly), elixirs (high tiers, stat
   bonuses, no regeneration, stack with food), recipe book, minimum levels,
   herb and reagent gathering hooked to the mapgen lane's plants.
4. **R8-MOB1 Mob wave 1.** Day/night spawn clock with fallbacks, dragons on
   the two dragon islands (draconis) and the six kings with royal guards as
   boss tier, then the first family packages the user approved from the mob
   plan (surface first, then underground with the flying/ranged tendency),
   each family with its licence line in `LICENSE-media.md` and an animated
   mesh. Rolling: further packages as long as the round runs.
5. **R8-DOCS Documentation alignment** at the end, as in rounds 5 and 6.

## 2. Explicitly not in Round 8

Blacksmith, Tailor, Leatherworker, Goldsmith, enchant rolls (WP5), Scout,
Nether content (families reserved, not built), farming as a player activity
(WP32, Phase 2), housing (WP24), mounts (WP31).

## 3. After Round 8 (Round 9 and later, unordered)

Blacksmith/Tailor/Leatherworker refinement and WP5 enchant rolls with the
Round 6 slot budget; Goldsmith and trinkets; Scout with leather and bow;
WP44 measured prices replacing the respec and consumable placeholders;
X3 talents; the remaining POI roster of WP13; Nether.

## 4. Playtest 11 (after Round 8, fresh world)

Walk one start zone to its capital: shores, soils, plants; gather, cook and
eat one dish per tier that is reachable; brew a potion and an elixir; a night
in a zone with a new night family; a king fight with a group of one; the
buff list under food plus elixir.
