# Game Design Docs

The **decided** game design — the living specification. Rules here (see
also AGENTS.md "Documentation layers"):

The project is in **fresh-server development mode** (2026-09-13): there are no
earlier servers, worlds or player formats to support. Older migration wording
does not authorize compatibility code. Only the user's explicit release-mode
announcement changes this rule; see [AGENTS.md](../../AGENTS.md#fresh-server-development-mode).

- Only settled decisions: rules, numbers, formulas, lists. No open
  questions, no option discussions — those live in `TODO-<topic>.md` files
  in the repo root until decided, then get folded in here.
- BACKLOG WPs implement what is written here; when a doc changes,
  check ROADMAP/BACKLOG for impact.
- Keep documents short and factual; "why" belongs in a brief *Rationale*
  line where a decision is surprising.

## Documents

| File | Scope | Status |
|------|-------|--------|
| [`world.md`](world.md) | Canonical names, target named-zone geography, destructibility, natural depth and harvesting, ocean classes, capitals/kings, structures, dragons, housing integration, travel, races and settlements. The WP18 radial map appears only as a labeled running-code migration baseline. | **decided**; feeds WP13/WP17/WP23/WP24/WP34/WP40. |
| [`world_zones.md`](world_zones.md) | Complete 38-zone macro-map: stable ids, independent race-region/territory/PvP fields, exact adjacency, relief and POI budgets, six starts/capitals, all level-31–60 ordinary zones contested, shared mutable Battlegrounds, offshore dragons, housing masks, hybrid-v7 API, WP40 gate, exact WP41 transaction and bounded WP42 encounters. | **decided**; authoritative surface contract for WP9/WP12/WP13/WP17/WP23/WP31/WP33/WP40–WP42. |
| [`housing.md`](housing.md) | Open-world Claim Stones in ten level-11–30 zones; four radii; 101×101 reservation and exact AABB spacing; trust, Home Stone, stable ids, live/dormant/decay/recovery/reissue lifecycle, mutability boundaries, persistence and capacity audits. | **decided** (2026-08-12); implementation WP24, travel integration WP17. |
| [`combat_stats.md`](combat_stats.md) | Shared HP/mana pool and damage fit, secondary attributes, equipped-slot weapon damage, crosshair-authoritative swings/casts/projectiles, armor resolution, geographic PvP seam, mob tiers and depth levels, threat, food/status recovery, offhand and carried light. | **decided**; shipped combat portions remain labeled, WP41 owns the PvP transaction. |
| [`classes.md`](classes.md) | MVP resources and kits, universal Strike, current-ray hostile authority, independent swing charges, directional Fireball, ability-item appearance and deferred class work. | **decided**; skill trees follow with WP11. |
| [`progression.md`](progression.md) | Leveling pace, talent cadence, Claim Stone milestones, PvE death/respawn and named-zone quest gates. | **decided**; detailed quest catalogs land with WP8/WP9. |
| [`items_crafting.md`](items_crafting.md) | Full item, crafting and loot contract: mastery versus material tiers; Bronze→Abyssal Steel; exact natural pick depth plus separate harvest tier; G1/G2 and cultural resources; alloys; one-item-per-concept catalogs; professions; the six-tier raw-food and three-role dish model with fixed instant HP, five-second out-of-combat regeneration and active secondary bonuses; cultural finishes, target-race specials, affixes, loot and the Common-price axis with 5% buy-back. | **decided** (material/economy rebase 2026-08-12; food revision 2026-09-17); implementation split across WP5/WP10/WP22/WP26–WP30/WP43/WP44. |
| [`inventory_equipment.md`](inventory_equipment.md) | Character screen, weapon/offhand and two trinket slots, hand count, separate cultural/PvP-special metadata channels, bags and 3×3 recipe/workbench rules. | **decided**; shipped slot mechanics and later item families are distinguished in the file. |
| [`professions.md`](professions.md) | Seven material-cut primary professions, secondary Cooking and universal First Aid, gathering ownership, cross-profession supply and vendor-floor rules; Goldsmith owns Quartz, regional gems, settings and both trinket slots. | **decided**; exact catalogs live in `items_crafting.md`. |
| [`economy.md`](economy.md) | Ledger currency, Common slot price axis, ceiling-rounded 5% buy-back, income measurement, repairs/services, Claim Stone upgrades/additional claims and mount earning-time targets. | **decided** (2026-08-12); WP44 replaces the shipped WP7 legacy price curve. |
| [`biomes_mobs.md`](biomes_mobs.md) | Final named-zone biome/mob/gathering inventory, three behavior classes, spawn budgets, signature woods and the complete universal/G1/G2/cultural supply map; the retired WP18/WP36 ring tables in §1/§4 remain a labeled historical record. | **content decided**; WP40 shipped 2026-09-13, re-cutting §1/§4 onto the 38 named zones is outstanding. |
| [`mounts.md`](mounts.md) | Universal riding at levels 15/30/45/60; exact land/flight speeds, income-priced purchases, owner-bound item plus ephemeral entity, damage dismount and authored Battlegrounds/enemy/ocean restrictions. | **decided; reviewed Round-10 mount candidate staged for integration and GUI acceptance**. |
| [`boats.md`](boats.md) | Water travel: always-craftable base boat, the shipwright's level-30 improved boat and its unlock, item/entity lifecycle, one player per boat and no mob passengers, pickup and 24-hour decay rules, 4/8 nodes per second, eject on any damage and the boat-facing summary of ocean danger. | **decided** (2026-08-13); implementation WP17, shipwright placement WP13, unblocks WP23. |
| [`settlements.md`](settlements.md) | What a settlement is on the ground: the six race starts and their build envelopes, start preparation and start-area safety, the surroundings rules, the settlement NPC roster and guard targeting, and the capitals in the world -- core, district plots, avenues, envelope edges, fill ground, work sockets and profession shop vendors. | **decided** (2026-09-13 onward, extended per playtest round); implemented in WP13. |
| [`character_visuals.md`](character_visuals.md) | Race skins and the visual-only 0.85..1.12 stature for the six peoples, dedicated cloth/leather/metal armor art in four slots and six material tiers, the held weapon, and the one composition rule shared by players and humanoid NPCs. | **decided** (2026-09-14); implemented in WP13. |
| [`skill_trees.md`](skill_trees.md) | The WP11 talent design: two trees of two chains and twenty-eight ranks per class, one point every two levels, tier and hard-chain gating, keystones that add or replace a button, one reachable capstone, the sixty-four talents, the data model, the respec seam and the four implementation lanes. | **PROPOSAL, revision 2** (2026-09-16); X1, X2 and X4 are implemented, while X3's keystones, capstones and four new abilities remain open. |
| [`scout.md`](scout.md) | The fourth class (Scout): mana, leather, a four-ability base kit built only from shipped mechanics, the ballistic bow the game does not have yet, the conflicts its Sprint has with the mob-speed pillar, and stealth deferred whole to §8. | **PROPOSAL** (2026-09-16), the user's rulings 7/12/14/27 built in; implemented by WP-Scout, which is open. |
| [`story.md`](story.md) | Nether-darkness premise, parallel faction questlines, minimum-level gates, level-20 Housing Steward introduction, killable kings and environmental storytelling. | **decided premise and story frame**; quest catalogs land with WP8/WP9. |

## Round 6 supporting records

These research notes are evidence and implementation records, not design
authority:

- [balance before](../research/balance-r6-before.md) and
  [balance after](../research/balance-r6-after.md) record the measured pool,
  damage, TTK/TTD and endgame-headroom rebase.
- [start-level verification](../research/balance-r6-start-levels.md) and the
  [spawn-variance audit](../research/spawn-variance-audit.md) record the start
  bands and surrounding population checks.
- [reference-media candidates](../research/reference-media-candidates.md) is
  the provenance/suitability basis for later user decisions. It authorizes no
  import; every candidate remains individually decision-gated.
