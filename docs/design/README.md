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
| `world.md` | Canonical names, two continents & ring difficulty, destructibility, ocean zones, capitals, outposts & apex bosses, housing isles, travel/Home Stone, races, settlements | **decided** (2026-08-07, housing rework; 2026-08-06 continent redesign) |
| `combat_stats.md` | Attributes, player formulas, HP/damage curves, armor mitigation & resolution order, mob tiers & con colors, threat system, recovery, offhand & carried light | **decided** (2026-08-07: armor mitigation; 2026-08-06 base) |
| `items_crafting.md` | Full items/loot/crafting spec: tome chain, tier catalogs, race-exclusive recipes, loot zones, quality/enchant rolls, level requirements, vendor bracket catalogs, upgrades, prices | **decided** (2026-08-07: bracket rotation, armor/weapon rounding rules, prices; vendor brackets + `grug_req_level` scope; 2026-08-06 base) — feeds WP5/WP7/WP10/WP22 |
| `inventory_equipment.md` | Character screen (sfinv pages), equipment slots incl. the armor-class/character-class binding, bags, and the 3×3 crafting model (recipe unlock + workbench proximity) | **decided** (2026-08-07: armor classes; 2026-08-06 base) — feeds WP15/WP10/WP14 |
| `classes.md` | Class kits: resources, damage pipeline, GCD & soft target lock, MVP abilities (skill trees follow with WP11) | **decided** (2026-08-06) |
| `economy.md` | Currency structure & display rule, price bands, 25 % buy-back, income streams, sinks (housing depth ladder, repair, respec), moving vendor floor | **decided** (2026-08-07: buy-back rate, display rule, storage ceiling; housing sink + vendor brackets; 2026-08-06 base); price tables: `items_crafting.md` §8 |
| `professions.md` | Profession structure, MVP roster, gathering split, leatherworker supply mechanic, vendor floor | **decided** (2026-08-06); recipes/materials: `items_crafting.md`; biome catalog: `biomes_mobs.md` |
| `progression.md` | Leveling pace, reward cadence (talent points/capstones), death rules, quest structure | **partial** (2026-08-06): pace/cadence/death decided; quest structure open (before WP8/WP9) |
| `story.md` | Main-quest premise (the Nether darkness), mirrored faction questlines, `min_level` gates, environmental storytelling | **decided** (2026-08-06) — premise only; quest content with WP8/WP9 |
| `guilds.md` | Guilds as ownership & access layer: founding, fixed roles, guild bank (one account + terminals), mining claims, isle access, guild chat | **decided** (2026-08-07: housing left the guild, bank respecced) — deliberately no guild levels/perks/wars |
| `biomes_mobs.md` | Full biome & mob catalog: 17 biome registrations, patch/settlement model, mob rosters, spawn params, race woods, material matrix | **decided** (2026-08-06) — biome layer built in WP18, mob rosters feed WP6 |
