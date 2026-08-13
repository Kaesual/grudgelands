# Game Design Docs

The **decided** game design — the living specification. Rules here (see
also AGENTS.md "Documentation layers"):

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
| [`world_zones.md`](world_zones.md) | Complete 38-zone macro-map: stable ids, independent race-region/territory/PvP fields, exact adjacency, relief and POI budgets, six starts/capitals, all level-31–60 ordinary zones contested, Holy Grounds, offshore dragons, housing masks, hybrid-v7 API, WP40 gate, exact WP41 transaction and bounded WP42 encounters. | **decided**; authoritative surface contract for WP9/WP12/WP13/WP17/WP23/WP31/WP33/WP40–WP42. |
| [`housing.md`](housing.md) | Open-world Claim Stones in ten level-11–30 zones; four radii; 101×101 reservation and exact AABB spacing; trust, Home Stone, stable ids, live/dormant/decay/recovery/reissue lifecycle, mutability boundaries, persistence and capacity audits. | **decided** (2026-08-12); implementation WP24, travel integration WP17. |
| [`combat_stats.md`](combat_stats.md) | Attributes and player formulas, equipped-slot weapon damage, crosshair-authoritative swings/casts/projectiles, armor resolution, geographic PvP seam, mob tiers and depth levels, threat, recovery, offhand and carried light. | **decided**; shipped combat portions remain labeled, WP41 owns the PvP transaction. |
| [`classes.md`](classes.md) | MVP resources and kits, universal Strike, current-ray hostile authority, independent swing charges, directional Fireball, ability-item appearance and deferred class work. | **decided**; skill trees follow with WP11. |
| [`progression.md`](progression.md) | Leveling pace, talent cadence, Claim Stone milestones, PvE death/respawn and named-zone quest gates. | **decided**; detailed quest catalogs land with WP8/WP9. |
| [`items_crafting.md`](items_crafting.md) | Full item, crafting and loot contract: mastery versus material tiers; Bronze→Abyssal Steel; exact natural pick depth plus separate harvest tier; G1/G2 and cultural resources; alloys; one-item-per-concept catalogs; professions, cultural finishes, target-race specials, affixes, loot and the Common-price axis with 5% buy-back. | **decided** (material/economy rebase 2026-08-12); implementation split across WP5/WP10/WP22/WP26–WP30/WP43/WP44. |
| [`inventory_equipment.md`](inventory_equipment.md) | Character screen, weapon/offhand and two trinket slots, hand count, separate cultural/PvP-special metadata channels, bags and 3×3 recipe/workbench rules. | **decided**; shipped slot mechanics and later item families are distinguished in the file. |
| [`professions.md`](professions.md) | Six material-cut professions, universal Cooking/First Aid, gathering ownership, cross-profession supply and vendor-floor rules; Goldsmith owns Quartz, regional gems, settings and both trinket slots. | **decided**; exact catalogs live in `items_crafting.md`. |
| [`economy.md`](economy.md) | Ledger currency, Common slot price axis, ceiling-rounded 5% buy-back, income measurement, repairs/services, Claim Stone upgrades/additional claims and mount earning-time targets. | **decided** (2026-08-12); WP44 replaces the shipped WP7 legacy price curve. |
| [`biomes_mobs.md`](biomes_mobs.md) | Final named-zone biome/mob/gathering inventory, three behavior classes, spawn budgets, signature woods and the complete universal/G1/G2/cultural supply map; current WP18/WP36 registrations remain a labeled migration baseline. | **content decided; target surface pending WP40**. |
| [`mounts.md`](mounts.md) | Universal riding at levels 15/30/45/60; exact land/flight speeds, income-priced purchases, owner-bound item plus ephemeral entity, damage dismount and authored Holy-Grounds/enemy/ocean restrictions. | **decided geography and lifecycle; not built**. |
| [`boats.md`](boats.md) | Water travel: always-craftable base boat, the shipwright's level-30 improved boat and its unlock, item/entity lifecycle, one player per boat and no mob passengers, pickup and 24-hour decay rules, 4/8 nodes per second, eject on any damage and the boat-facing summary of ocean danger. | **decided** (2026-08-13); implementation WP17, shipwright placement WP13, unblocks WP23. |
| [`story.md`](story.md) | Nether-darkness premise, parallel faction questlines, minimum-level gates, level-20 Housing Steward introduction, killable kings and environmental storytelling. | **decided premise and story frame**; quest catalogs land with WP8/WP9. |
