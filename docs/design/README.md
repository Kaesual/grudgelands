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
| [`crafting_equipment_revision.md`](crafting_equipment_revision.md) | Personal/shared workspaces, deterministic enchanting and tier-correct base recipes; links to equipment/wear owners. | **current rules**, implemented; broader loot/economy scope remains separate. |
| [`world.md`](world.md) | Canonical names, target named-zone geography, destructibility (incl. road and POI protection), tier rock and harvesting, ocean classes, capitals/kings, structures, dragons, housing integration, travel, races and settlements. Retired radial-map experiments are archived; current geometry uses the named-zone authority. | **decided**; feeds WP13/WP17/WP23/WP24/WP34/WP40. |
| [`world_zones.md`](world_zones.md) | Complete 38-zone macro-map: stable ids, independent race-region/territory/PvP fields, geometric adjacency, relief and POI budgets, six starts/capitals, all level-31–60 ordinary zones contested, shared mutable Battlegrounds, offshore dragons, hybrid-v7 API, Round 22 acceptance, exact WP41 transaction and bounded WP42 encounters. | **decided**; authoritative surface contract for WP9/WP12/WP13/WP17/WP23/WP31/WP33/WP40–WP42. |
| [`housing.md`](housing.md) | Claim Stones: one soulbound stone per player from the Housing Steward at level 20; a 101 × 101 column from y = −100 up in the own level-11–30 home zones; coal/charcoal upkeep as a "paid until" timestamp; empty-fuel destruction; Interact/Everything permissions and interaction protection; stone interface, character-page status and home-stone travel; relation to road and POI protection. | **decided** (Round 25, 2026-09-29); implementation WP24. |
| [`combat_stats.md`](combat_stats.md) | Shared HP/mana pool and damage fit, secondary attributes, equipped-slot weapon damage, crosshair-authoritative swings/casts/projectiles, armor resolution, geographic PvP seam, mob tiers and depth levels, threat, food/status recovery, offhand and carried light. | **decided**; shipped combat portions remain labeled, WP41 owns the PvP transaction. |
| [`classes.md`](classes.md) | MVP resources and kits, universal Strike, current-ray hostile authority, independent swing charges, targeted homing Fireball, ability-item appearance and deferred class work. | **decided**; skill trees follow with WP11. |
| [`progression.md`](progression.md) | Leveling pace, talent cadence, the level-20 Claim Stone, PvE death/respawn and named-zone quest gates. | **decided**; Round 28 sets the kill-equivalent XP curve; Round 29's 491 quests replace Round 20's 240; the broader WP9 story remains open. |
| [`items_crafting.md`](items_crafting.md) | Full item, crafting and loot contract: mastery versus material tiers; Bronze→Abyssal Steel; exact natural pick depth plus separate harvest tier; depth-tiered gems and regional cultural resources; alloys; one-item-per-concept catalogs; professions; starter/main-material Basics visibility; the six-tier raw-food and three-role dish model with fixed instant HP, five-minute buffs, five-second out-of-combat regeneration and active secondary bonuses; cultural finishes, target-race specials, affixes, loot and the Common-price axis with 5% buy-back. | **decided** (material/economy rebase 2026-08-12; food/discovery revision 2026-09-20); implementation split across WP5/WP10/WP22/WP26–WP30/WP43/WP44. |
| [`inventory_equipment.md`](inventory_equipment.md) | Shared inventory layout, Skills catalogue and bound representations, onboarding Help, Creative Food, Character screen, weapon/offhand and two trinket slots, hand count, separate cultural/PvP-special metadata channels, bags and 3×3 recipe/workbench rules. | **decided**; slot mechanics, the Round 11 item families and bounded REPAIR durability/service are delivered. |
| [`professions.md`](professions.md) | Seven material-cut primary professions, secondary Cooking and universal First Aid, gathering ownership, cross-profession supply and vendor-floor rules; Goldsmith owns Quartz, the depth-tiered gems, settings and both trinket slots; since Round 28 no profession needs another profession's product. | **decided**; exact catalogs live in `items_crafting.md`. |
| [`economy.md`](economy.md) | Ledger currency, Common slot price axis, ceiling-rounded 5% buy-back, income measurement, repairs/services, income-derived price rounding and mount earning-time targets; housing has no price. | **decided** (2026-08-12); WP44, a lighter pass (2026-09-29), delivered in Round 29: one price module, 5% buy-back, income-derived mount, boat and respec prices. |
| [`biomes_mobs.md`](biomes_mobs.md) | Final named-zone biome/mob/gathering inventory, three behavior classes, spawn budgets, signature woods and the complete universal/gem/cultural supply map; retired WP18/WP36 layout research is archived; the mixed spawn table retains explicit evidence limits. | **content decided**; WP40 shipped 2026-09-13; WP37 closed 2026-09-29 (only the two surface critters get ×0.75); Round 28 adds sub-types, loot by band and the spawn-region runtime; table values are not a current runtime census. |
| [`spawn_regions.md`](spawn_regions.md) | Rule-based spawn regions: a zone's recipe (belts by progress from the start to the exit, kinds per terrain type, camps, leaders) turned into regions on the zone's own terrain for any seed; the same builder in the game and the review renderer; quests reference kinds; directions for quest texts; one level truth; the border rule between zones; the compact maps and their world-folder cache. | **decided** (Round 28 S1, 2026-10-02); all 38 zones ship a recipe (Round 28 S2, W1); cache Round 30. |
| [`mounts.md`](mounts.md) | Universal riding at levels 15/30/45/60; exact land/flight speeds, income-priced purchases, individually recoverable purchased tiers at original speeds, owner-bound item plus ephemeral entity, damage dismount and contested-flight permission and enemy-safe/island/ocean restrictions. | **decided**; runtime and retained-tier Skills integration reviewed, GUI acceptance remains separate. |
| [`boats.md`](boats.md) | Water travel: boats are water mounts (owner-bound skill items, ephemeral entity, never left empty in the world), sold by the Shipwright at every capital stable (base boat L15, improved boat L30), summoned only in water, 4/8 nodes per second, removed when off the water, eject on any damage and the boat-facing summary of ocean danger; the pier and beach at each island landing. | **decided** (2026-08-13, revised 2026-10-02 by the WP17 travel plan); implemented Round 29 (WP17); the only access to the dragon islands; landings Round 30. |
| [`settlements.md`](settlements.md) | What a settlement is on the ground: the six race starts and their build envelopes, start preparation and start-area safety, the surroundings rules, the settlement NPC roster and guard targeting, and the capitals in the world -- core, district plots, avenues, envelope edges, fill ground, work sockets and profession shop vendors. | **decided** (2026-09-13 onward, extended per playtest round); implemented in WP13. |
| [`character_visuals.md`](character_visuals.md) | Race skins and the visual-only 0.85..1.12 stature for the six peoples, dedicated cloth/leather/metal armor art in four slots and six material tiers, the held weapon, and the one composition rule shared by players and humanoid NPCs. | **decided**; the base visual system and Round 11 gear-art expansion are delivered. |
| [`skill_trees.md`](skill_trees.md) | The WP11 talent design: two trees of two chains and twenty-eight ranks per class, one point every two levels, tier and hard-chain gating, keystones that add or replace a button, one reachable capstone, the sixty-four talents, the data model, the respec seam and the four implementation lanes. | **decided, revision 2** (2026-09-16); X1, X2, X4, Scout's complete trees and Round 11's targeted Ironbound/Unbroken armor slice are implemented; Round 12 completes the original-class X3 consumers; WP44 set the respec prices in Round 29 (lane E4). |
| [`scout.md`](scout.md) | The fourth class (Scout): mana, leather, bow/dagger/sword routes, a four-ability base kit, homing arrows, Sprint's bounded speed exception and stealth deferred whole to §8. | **decided** (2026-09-16); the Round 11 class, abilities, talents, starter kit and trader integration are delivered. |
| [`story.md`](story.md) | Nether-darkness premise, parallel faction questlines, minimum-level gates, the level-20 Housing Steward, killable kings and environmental storytelling. | **decided premise and story frame**; Round 20 expands starter/capital/regional journeys; levels 41–60 and the finale (V1, WP9) remain open. |
| [`farming.md`](farming.md) | Seventeen-family annual/regrowing/retained-base cultivation and vertical crop shapes, seven hoe lifetimes, halved wild-plant density, habitat-driven wild-plant and tree renewal near players, water-only buckets and the protected-water-flow prerequisite. | **decided** (2026-09-20); Round 11 foundation, Round 12 family iteration, Round 23 habitat renewal (2026-09-28). |
| [`durability_repair.md`](durability_repair.md) | Combat/tool wear, broken effects, city trainer service, atomic quotes and current purchase-price repair at at most 20%. | **decided** (2026-09-20); bounded WP22 implementation; repair at stations inside a claim built in Round 29 (E1). |
| [`quests.md`](quests.md) | Twenty-slot quest journal, kill/item/talk objectives, participation, rewards, markers and tracker; per-zone quest data with area, item-group and quest-drop objectives, repeatables, travel credit and load-time validation. | **decided**, Round 14; data and objectives Round 28; text placeholders, quest copper and the front bounty baseline Round 29. |
| [`home_travel.md`](home_travel.md) | Twelve faction-restricted innkeeper homes, immediate out-of-combat return, persistent 30-minute cooldown and death respawn; the own Claim Stone as alternative travel-home target. | **decided**, Round 17; waystone travel shares its travel path since Round 29 (`world.md` §6); Return home on the Character page since Round 30. |
| [`parties.md`](parties.md) | Persistent same-faction parties, inviter-bound invitations, management and health HUD. | **decided**, Round 14. |
| [`world_map.md`](world_map.md) | Cartographic atlas without fog, independent extensible markers and no travel unlock; map quality (normal/high) with readable relief; our own round minimap with quest, service, home and party markers in place of the native one; zone and town names under the minimap, on the Map tab and in an entry banner. | **decided**, Round 14; quality, relief and minimap Round 27 (WP50); zone and town names Round 28; refresh rates Round 30. |
| [`world_preparation.md`](world_preparation.md) | Immutable per-world full/starts mode, bounded chunk scheduling, shutdown/resume and waiting UI. | **decided**, Round 14. |

## Decision routing and evidence

[Round 18 routing](playtest_quality_revision.md) is a link index only; its
rules live in the topics above. Delivery and pending GUI checks live in
[project status](../STATUS.md), open work in [BACKLOG](../../BACKLOG.md).
The [documentation audit](../maintenance/documentation-round.md) records review
coverage and unresolved discrepancies. Approved future systems remain labeled;
“decided” alone never means “implemented”.

### Round 6 supporting records

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
