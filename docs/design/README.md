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

## Planned documents

| File | Scope | Status |
|------|-------|--------|
| `world.md` | Geography, territory rings, destructibility, capitals, outposts, housing, races | **decided** (2026-08-06) |
| `combat_stats.md` | Attributes, skill points, HP/damage curves, mob tiers, threat system, recovery | **decided** (2026-08-06) |
| `items_crafting.md` | Quality tiers, enchant budgets, crafting/upgrades, loot sources | in progress → `TODO-design-items-crafting.md` (before WP5/WP7) |
| `classes.md` | Class kits: resources, MVP abilities (skill trees follow with WP11) | **decided** (2026-08-06) |
| `economy.md` | Currency structure, money-flow bands, trader rules, vendor floor | **decided** (2026-08-06); price numbers open in `TODO-design-items-crafting.md` §4 |
| `professions.md` | Profession structure, MVP roster, gathering split, vendor floor | **decided** (2026-08-06); recipes/materials open in items TODO; biome catalog: `biomes_mobs.md` |
| `progression.md` | Leveling pace, reward cadence, death rules, quest structure | **partial** (2026-08-06): pace/cadence/death decided; quest structure open (before WP8/WP9) |
| `biomes_mobs.md` | Full biome & mob catalog: 16 biomes, patch/settlement model, mob rosters, spawn params, race woods, material matrix | **decided** (2026-08-06) — implementation spec for WP18/WP6 |
