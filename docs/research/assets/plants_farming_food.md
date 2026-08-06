# Research: Plants, Herbs, Farming & Food Mods

Researched 2026-08-06 via ContentDB / GitHub for Grudgelands (code GPLv3+;
media allowed: GPL-family, LGPL, MIT, Apache, CC0, CC BY, CC BY-SA — no NC/ND).

## Summary

There is a rich, license-clean ecosystem. **Farming Redo** and **x_farming** together
cover ~50 crop species plus dozens of food items with permissive licenses and no hard
dependencies — the best texture/code quarry for farming and cooking. **Herbs** (Clyde)
is a near-perfect Herbalism fit (15 flowers + 6 mushrooms as gatherable wild nodes).
**Ethereal NG** and **df_farming (dfcaverns)** add wild/underground flora flavor.
**Potions (X-DE)** provides a full brewing system + potion textures under GPL-3.0-or-later.
Main caveats: several mods hard-depend on minetest_game `default`/`flowers`/`vessels`
(we are standalone → port or stub), and a few packages leave the media license
undocumented per-file (⚠ verify before copying textures).

## Top 5 Recommendations

1. **Farming Redo** (TenPlus1) — HIGH. MIT code / CC-BY-SA-4.0 media, zero required deps, actively developed; biggest single source of crop + food textures and mature growth code (node-timer based, works while players away).
2. **x_farming** (SaKeL) — HIGH. LGPL-2.1-or-later / CC-BY-SA-4.0, self-contained; ~30 crops plus pies, crates, composter, bonemeal, scarecrow — great cooking/food breadth.
3. **Herbs** (Clyde) — HIGH. Exactly our Herbalism niche: 15 wild flowers + 6 mushrooms; GPL-3.0-only code (fine for a GPLv3+ project, result is GPLv3) / CC-BY-3.0 media.
4. **Ethereal NG** (TenPlus1) — MEDIUM-HIGH. MIT / CC-BY-SA-3.0; wild fruits, mushrooms, prepared dishes (mushroom soup, sushi); needs `default`+`flowers` → cherry-pick assets rather than depend.
5. **Potions** (X-DE) — MEDIUM-HIGH. GPL-3.0-or-later / CC-BY-SA-4.0; alchemy stand, brewing API, potion bottle textures — best starting point for the Alchemist profession.

## Candidate Table

| Mod | Author | Code lic. | Media lic. | Assets | Deps (required) | Status | Prio |
|---|---|---|---|---|---|---|---|
| [Farming Redo](https://content.luanti.org/packages/TenPlus1/farming/) | TenPlus1 | MIT | CC-BY-SA-4.0 | ~20 crops, many foods/tools | none | Active (2026-07) | High |
| [x_farming](https://content.luanti.org/packages/SaKeL/x_farming/) | SaKeL | LGPL-2.1-or-later | CC-BY-SA-4.0 | ~30 crops, pies, 40+ fish | none | Maint. only (2025-04) | High |
| [Herbs](https://content.luanti.org/packages/Clyde/herbs/) | Clyde | GPL-3.0-only | CC-BY-3.0 | 15 flowers, 6 mushrooms | default, flowers | Beta (2024-01) | High |
| [Ethereal NG](https://content.luanti.org/packages/TenPlus1/ethereal/) | TenPlus1 | MIT | CC-BY-SA-3.0 | wild fruits, mushrooms, dishes | default, flowers | Active (2026-08) | Med-High |
| [Potions](https://content.luanti.org/packages/X-DE1/potions/) | X-DE | GPL-3.0-or-later | CC-BY-SA-4.0 | brewing stand, potion API+textures | default, playereffects, playerphysics, vessels | Maint. only (2025-05) | Med-High |
| [dfcaverns / df_farming](https://content.luanti.org/packages/FaceDeer/dfcaverns/) | FaceDeer | MIT | ⚠ "various" per-file | cave fungi/crops (plump helmet, cave wheat, sweet pods…) | none | Active (2023-12) | Medium |
| [plantlife_modpack](https://content.luanti.org/packages/mt-mods/plantlife_modpack/) | mt-mods | LGPL-3.0-only | CC-BY-SA-4.0 | ferns, bushes, vines, 3d mushrooms, ground cover | biome_lib, default, flowers | Unknown (2026-06) | Medium |
| [Wine](https://content.luanti.org/packages/TenPlus1/wine/) | TenPlus1 | MIT | CC-BY-SA-4.0 | barrel fermentation, ~7 drinks | none | Updated 2026-06 | Medium |
| [cucina_vegana](https://content.luanti.org/packages/Clyde/cucina_vegana/) | Clyde | LGPL-3.0-only | ⚠ LGPL-3.0-only (single lic.) | plants/spices, many vegan dishes | default, dye, farming, vessels | Beta (2025-09) | Low-Med |
| [Cropocalypse](https://content.luanti.org/packages/Tarruvi/cropocalypse/) | Tarruvi | MIT | ⚠ not stated | 14 crops, 7 mushrooms, foods | default, farming, +4 | Stale (2023-01) | Low |
| [Haunted's Foods](https://content.luanti.org/packages/Haunted/haunteds_foods/) | Haunted | MIT | ⚠ not stated | meal/drink nodes | default, farming, vessels | Maint. only (2026-05) | Low |

## Per-Candidate Notes

### Farming Redo — TenPlus1 — https://codeberg.org/tenplus1/farming
Wheat, cotton, barley, oats, rice, corn, pumpkin, melon, beetroot, onion, garlic,
tomato, cucumber, coffee, cocoa etc., plus bread/baking and many meal recipes.
16px textures, MTG style. No required deps (has MineClone compat shims — good template
for our standalone game). Growth uses its own re-grow logic instead of pure ABMs —
worth studying for regrowth. License clean; actively developed.

### x_farming — SaKeL — https://bitbucket.org/minetest_gamers/x_farming
Adds what Farming Redo lacks: pies/cakes, crates, composter, bonemeal, scarecrow,
obsidian wart (a fantasy "herb" precedent), salt. LGPL-2.1-**or-later** → GPLv3-compatible
(would be ⚠ if it were 2.1-only… it is not). Self-contained; slightly larger/more modern
texture style in places.

### Herbs — Clyde — https://github.com/acmgit/herbs
15 flowers + 6 mushrooms registered as wild flower-like nodes — direct raw material for
Herbalism gathering. GPL-3.0-only code: compatible with our GPLv3+ code, but the combined
work then ships as GPLv3 (acceptable; not the GPLv2-only trap). Media CC-BY-3.0 (attribution
required). Small, easy to port away from `default`/`flowers`.

### Ethereal NG — TenPlus1 — https://codeberg.org/tenplus1/ethereal
Best source for *wild-growing* food flavor: wild onion, strawberry, lemon, olive, banana,
coconut, mushroom soup, sushi; also decoration-based biome flora registration to copy.
Depends on `default`+`flowers`, so treat as an asset/code quarry, not a dependency.
Media CC-BY-SA-3.0 (fine; keep attribution + share-alike per file).

### Potions — X-DE — https://github.com/X-DE1/potions/
Fork of Stakbox's s_potions. Three-layer design (potions_api / brewing / default potions)
maps well onto our Alchemist profession. GPL-3.0-**or-later** → fully compatible.
Requires MTG `default`, `vessels`, `playereffects`, `playerphysics` → porting work; the
API structure and bottle/stand textures are the valuable part.

### dfcaverns (df_farming) — FaceDeer — https://github.com/FaceDeer/dfcaverns
Great fantasy-flavored underground fungi/crops (plump helmets, cave wheat, quarry bush,
sweet pods) — ideal for cave herbalism zones. Code MIT. ⚠ Media: ContentDB sidebar says
"MIT" but repo license.txt says sounds/textures are "under various licenses" in per-folder
license.txt files — verify each texture before reuse.

### plantlife_modpack — mt-mods — https://github.com/mt-mods/plantlife_modpack
Ferns, bushes with berries, vines, water lilies, 3D mushrooms — good wilderness ambience.
Hard dependency on `biome_lib` (its own spawning engine, ABM-based) — we would instead
re-register the nodes with native `core.register_decoration`. LGPL-3.0-only code is
GPLv3-compatible.

### Wine — TenPlus1 — https://codeberg.org/tenplus1/wine
Barrel + fermentation timer pattern is a ready-made template for potion brewing
(input item → timed container → output bottle). MIT / CC-BY-SA-4.0, no required deps.

### Others
**cucina_vegana** (⚠ media apparently LGPL for textures — unusual but reusable; heavy MTG
deps), **Cropocalypse** and **Haunted's Foods** (⚠ no explicit media license on ContentDB —
ask author or skip textures). **s_potions_modpack** (Stakbox) is the upstream of Potions —
check if fork or original is healthier when we implement alchemy.

## Code Patterns to Reuse
- **Wild spawning:** native `core.register_decoration` (simple/schematic) as used by
  Ethereal — preferred over plantlife's `biome_lib` ABM spawning (perf, no extra dep).
- **Growth/regrowth:** Farming Redo's node-timer + light/soil check growth (catch-up when
  area unloaded); x_farming bonemeal for instant-grow.
- **Eating:** engine `core.item_eat`/`core.do_item_eat` hook — override `do_item_eat` to
  route food into our rest-recovery system; hbhunger/stamina (both MIT) show the pattern.
