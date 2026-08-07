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
| `world.md` | Canonical names, two continents & ring difficulty, destructibility incl. the **six rock strata** (R6), ocean zones, capitals, outposts & apex bosses, housing isles with the **six depth steps**, travel/Home Stone, races, settlements | **decided** (2026-08-07: rock strata + six depth steps, crafting rework; 2026-08-07 housing rework; 2026-08-06 continent redesign) |
| `combat_stats.md` | Attributes, player formulas, HP/damage curves, armor mitigation & resolution order, mob tiers & con colors, threat system, recovery, offhand & carried light | **decided** (2026-08-07: armor mitigation; 2026-08-06 base) |
| `items_crafting.md` | Full items/loot/crafting spec: **the two ladders** (T1–T6 material vs. the four mastery tiers), the **six-tier material ladder** with its ores, alloys, two-slot furnace and rock-strata digging gates, **one item per concept** (vendor catalog = base craft ladder, material-named), the **one recipe book per profession**, the six profession catalogs, race-exclusive recipes, loot zones, quality/enchant rolls, **refinement + prefix/suffix affixes and special variants** (§6b), level requirements, vendor bracket catalogs, upgrades, prices | **decided** (2026-08-07 crafting rework: §2/§3.0/§3.6a/§3.6b/§6b, six depth-step prices; 2026-08-07 bracket rotation, rounding rules, `grug_req_level` scope; 2026-08-06 base) — feeds WP5/WP7/WP10/WP22/WP25–WP30 |
| `inventory_equipment.md` | Character screen (sfinv pages), equipment slots incl. the armor-class/character-class binding and the **two trinket slots (the Goldsmith's, items in the MVP since 2026-08-08)**, bags in **four sizes across the four mastery tiers — 8/16/24/32**, and the 3×3 crafting model (recipe unlock + workbench proximity) | **decided** (2026-08-08: trinkets pulled into the MVP; 2026-08-07: huge bag + trinket ownership, crafting rework; 2026-08-07 armor classes; 2026-08-06 base) — feeds WP15/WP10/WP14 |
| `classes.md` | Class kits: resources, damage pipeline, GCD & soft target lock, MVP abilities (skill trees follow with WP11) | **decided** (2026-08-06) |
| `economy.md` | Currency structure & display rule, price bands, 25 % buy-back, income streams, sinks — now exactly two big ones: the **six-step housing depth ladder (≈ 1.9g, re-cut from 2.4g)** and the 5g guild founding fee, since the **continental mining claims were removed**; moving vendor floor | **decided** (2026-08-07: six depth steps + claim removal, crafting rework; 2026-08-07 buy-back rate, display rule, storage ceiling, housing sink; 2026-08-06 base); price tables: `items_crafting.md` §8 |
| `professions.md` | Profession structure, the **six material-cut professions** (Blacksmith, Leatherworker, Tailor, Woodcarver, Goldsmith, Alchemist — Herbalism merged into the Alchemist, Gem Hunter into the Goldsmith), the coverage/overlap proof, gathering split, cross-profession supply loops, vendor floor as "no vendor sells a refined or enchanted item" | **decided** (roster re-cut 2026-08-07; 2026-08-06 base); recipes/materials: `items_crafting.md`; biome catalog: `biomes_mobs.md` |
| `progression.md` | Leveling pace, reward cadence (talent points/capstones), death rules, quest structure | **partial** (2026-08-06): pace/cadence/death decided; quest structure open (before WP8/WP9) |
| `story.md` | Main-quest premise (the Nether darkness), mirrored faction questlines, `min_level` gates, environmental storytelling | **decided** (2026-08-06) — premise only; quest content with WP8/WP9 |
| `guilds.md` | Guilds as a **social & access layer**: founding (5g), fixed roles, guild bank (one account + terminals on members' isles), isle access, guild chat. **Continental mining claims removed 2026-08-07** — a guild owns no ground at all | **decided** (2026-08-07: claims removed; 2026-08-07 housing left the guild, bank respecced) — deliberately no guild levels/perks/wars |
| `biomes_mobs.md` | Full biome & mob catalog: 17 biome registrations, patch/settlement model, mob rosters, spawn params, race woods, material matrix, and the **herb split** — never-farmable healing herbs vs. farmable spices, plus the found-only cooking ingredients | **decided** (2026-08-07: herb/spice split + cooking supply check; 2026-08-06 base) — biome layer built in WP18, mob rosters feed WP6, plants feed WP33 |
| `mounts.md` | Riding as a universal skill on the four mastery tiers, bought never tamed (slow/fast land, slow/fast flying at 1s/8s/30s/60s ≈ 1g), the attachment model and why speed is entity velocity and never `physics_override.speed`, the open-sea **"Exhausted"** dismount anchored to `grug_core.open_sea_at`, the outright no-mount rule on housing isles, the **flying ban in enemy territory** (`grug_core.territory_at`, same 10 s grace) and the licence-checked reference implementations | **decided** (2026-08-08: enemy-territory flight ban; 2026-08-07 base) — **spec only, nothing built**; feeds WP31, open points in `TODO-design-crafting-rework.md` D12–D20 |
