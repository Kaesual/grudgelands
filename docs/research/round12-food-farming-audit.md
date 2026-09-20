# Food, Creative Inventory, and Farming Audit

Date: 2026-09-20  
Scope: read-only audit of the current repository. This document proposes no new rules and changes no runtime code.

## Conclusions

1. Source inspection found no food-specific exclusion bug in the Creative **All** tab; this is not a GUI reproduction. It takes the complete `registered_items` table, excludes only entries whose `not_in_creative_inventory` group is exactly `1`, and requires a non-empty description (`mods/BASE/creative/inventory.lua:9-20,254`). All current edible registrations have descriptions and none sets that exclusion group. The page displays only 32 entries at a time and sorts the complete mixed catalog by item ID when there is no search (`mods/BASE/creative/inventory.lua:102-124,157-182`). Searching for `food` is not a reliable food filter because most dish names and descriptions do not contain that word.
2. Food content is already materially larger than the playtest impression: **47 edible item registrations** currently pass through `grug_food.register_item`. The Cooking mod itself supplies **40 craftitems**: 15 plant/ingredient items, 18 finished dishes, 6 inedible raw assemblies, and Bread. Of these, **29 are edible** (10 raw plants, 18 dishes, Bread). The other edible registrations are 13 existing meat/fish/default items and 5 gathering plants.
3. There are exactly **six Caster dishes**, one per tier. They already restore out-of-combat mana over time. T3-T6 additionally raise maximum mana while the food status is active. These are food sustain effects, distinct from ordinary class mana regeneration and from instant mana potions.
4. Farming has **17 complete crop families**, each with a separate seed, four timed world stages, wet-soil pause/resume, and mature/immature drops. Every family is currently a single world node. Corn is not three nodes high.
5. A three-node corn implementation exists in the pinned **Lord of the Test** reference. The pinned VoxeLibre checkout contains no corn/maize crop. `x_farming` contains corn and supplied our four selected corn textures, but its current corn is also one node with `visual_scale = 2.0` at stages 6-10. Lord of the Test is the reference that constructs the crop into two and then three stacked nodes.

## Creative inventory and current food population

### All-tab behavior

The cache predicate is only:

- `groups.not_in_creative_inventory ~= 1`
- a non-empty `description`

Evidence: `mods/BASE/creative/inventory.lua:9-20`. The **All** page passes `minetest.registered_items` directly (`:254`). The visible inventory is 8 x 4 slots and paginates (`:157-182`). With no search, matching gives every item the same score and the secondary sort key is the registered item name (`:64-72,102-120`). This disperses food among the entire catalog.

The food registration copies existing groups, then adds `grug_food`, tier, kind, and role groups; it does not hide the item (`mods/ITEMS/grug_food/init.lua:274-310`). The Cooking registrations likewise give every craftitem a description (`mods/ITEMS/grug_cooking/init.lua:47-60,169-178,228-240,253-259`). Therefore the current code predicts that every food below is present in **All**.

Potential UX defect rather than content/filter defect: there is no food tab or food-role search vocabulary, and the visible first line is an ordinary item name. `Food` appears in neither the dish name nor the generated description; the generated tooltip says `Restores`, `Regenerates`, and `Requires` (`mods/ITEMS/grug_food/init.lua:168-194`). A player browsing rather than knowing names can reasonably conclude there are only a few foods.

### Exact edible catalog: 47

**13 pre-existing/default/mob/fishing foods** registered in `CURRENT_FOODS` (`mods/ITEMS/grug_food/init.lua:313-333`):

- T1 raw: Apple, Blueberries, Raw Meat, Raw Meat Block, Raw Fish.
- T1 dishes: Cooked Meat, Cooked Meat Block, Cooked Fish.
- Tiered raw fish: Silver Trout (T2), Mire Carp (T3), Frostfin (T4), Ember Eel (T5), Storm Tuna (T6).

**5 gathering foods**, selected by `RAW_GATHERING_TIERS` while walking the gathering manifest (`mods/ITEMS/grug_food/init.lua:335-350`): Corn (T1), Melon (T1), Mushroom (T3), Potato (T1), Wild Cocoa (T6).

**10 raw Cooking plants**, derived from the 15-row plant table by `kind == "raw_food"` (`mods/ITEMS/grug_cooking/init.lua:6-37,47-60`): Wild Grain, Carrot, Cassava, Pumpkin, Blightberry, Sunberry, Jungle Berry, Frost Melon, Bamboo Shoot, Cave Cap. The remaining five Cooking plants are ingredients but intentionally not edible: Wild Onion, Fire Pepper, Sugar Cane, Salt Crust, Ember Moss.

**18 Cooking dishes**, three roles at each of six tiers (`mods/ITEMS/grug_cooking/init.lua:114-151,169-180`):

| Tier | Hearty | Caster | Hunter |
|---:|---|---|---|
| T1 | Hearty Stew | Sweetroot Mash | Corn-Crusted Fish |
| T2 | Pumpkin Stew | Berry Preserve | Fruit-Glazed Roast |
| T3 | Forager's Pot | Mushroom Skewer | Onion-Seared Steak |
| T4 | Marsh Roast | Marshbloom Chowder | Hunter's Feast |
| T5 | Kelp-Wrapped Roast | Stormkelp Broth | Salt-Crusted Fish |
| T6 | Grand Feast | Jungle Cocoa | Cocoa-Rubbed Game |

**1 additional Cooking dish:** Bread, T1 Hearty (`mods/ITEMS/grug_cooking/init.lua:253-261`).

This gives 13 + 5 + 10 + 18 + 1 = **47 edible registrations**. In addition, Cooking registers six explicitly inedible raw dish assemblies (`mods/ITEMS/grug_cooking/init.lua:213-250`). Thus the namespace's exact craftitem count is 15 plants + 18 dishes + 6 assemblies + Bread = **40**.

### Caster food: implemented behavior

The six Caster dishes are Sweetroot Mash, Berry Preserve, Mushroom Skewer, Marshbloom Chowder, Stormkelp Broth, and Jungle Cocoa (`mods/ITEMS/grug_cooking/init.lua:117-148`). They are implemented at every tier, including high tiers.

All food lasts 180 seconds and ticks every 5 seconds (`mods/ITEMS/grug_food/init.lua:6-7`). Caster effects per tick are:

| Tier | Minimum level | HP + mana per 5 s | Additional active modifier |
|---:|---:|---:|---:|
| T1 | 1 | 2% each | none |
| T2 | 11 | 2.5% each | none |
| T3 | 21 | 3% each | +2% maximum mana |
| T4 | 31 | 3.5% each | +4% maximum mana |
| T5 | 41 | 4% each | +6% maximum mana |
| T6 | 51 | 5% each | +8% maximum mana |

Evidence: `mods/ITEMS/grug_food/init.lua:9-44`. Mana restoration converts the percentage to an integer amount from current maximum mana and calls `grug_abilities.restore_mana` (`:59-63,106-113`). Food ticks skip both HP and mana regeneration while the player is in combat (`:196-215`); the maximum-mana modifier remains active because it belongs to the status record. A character without a mana pool cannot consume mana food (`:248-267`).

The requested “Caster Food that restores a lot of mana out of combat” therefore exists. The strongest current one, Jungle Cocoa, restores 5% maximum mana every 5 seconds for three minutes (up to 180% over the full duration if continuously missing mana), alongside the same HP recovery and +8% maximum mana. It is gated to level 51 and Cooking T6 by the ordinary item/profession rules. T1 Sweetroot Mash already gives 2% maximum mana every 5 seconds at level 1.

This is distinct from:

- baseline class mana regeneration, which is a continuous character system, specified as `1 + 0.15 x level` mana/s out of combat (`docs/design/combat_stats.md:822-827`);
- food's `mana_pool_percent`, which increases capacity rather than directly restoring mana (`docs/design/combat_stats.md:187-196`);
- mana potions, which restore 30% maximum mana instantly and use the shared potion cooldown (`docs/design/items_crafting.md:990-1009`).

The current design text explicitly says raw food regenerates HP only and mana comes only from Caster dishes (`docs/design/combat_stats.md:787-802`). This is implemented, not merely planned.

## Current farming implementation

### Population and lifecycle

`grug_farming` builds crops from all 15 `grug_cooking.PLANTS`, then adds Potato and Corn, and asserts that exact `15 + 2` population after mods load (`mods/ITEMS/grug_farming/init.lua:98-148,266-286`). The completion record confirms the 17-family population and the exhaustive test coverage (`docs/research/r10-farming-completion.md:9-15,32-37`).

Every crop has:

- one separate seed craftitem and four stage node names (`mods/ITEMS/grug_farming/init.lua:105-135,218-227`);
- one harvest item converting shapelessly to two seeds (`:228-232`);
- 200 seconds per stage, so a fresh stage-1 planting reaches stage 4 after three advances / 600 seconds under continuously wet soil (`:14-16,150-175`);
- growth only over `soil_wet`; elapsed partial progress pauses on dry soil and resumes when rewetted (`:37-61,63-81`);
- immature harvest (stages 1-3): exactly one seed and no food/harvest item (`:233-246`);
- mature harvest (stage 4): exactly one harvest item plus one seed (`:233-260`).

All 68 stage nodes are hidden from Creative, while the 17 seed items remain visible (`mods/ITEMS/grug_farming/init.lua:220-237`). This is intentional node hygiene and does not hide edible harvest items.

### Current world appearance

The crop appearance no longer reuses the inventory/harvest icon. All 17 families have four real stage textures; this was the purpose of the Round 10 art pass (`docs/research/r10-visuals.md:56-69`). The media ledger identifies the sources and treatment (`mods/ITEMS/grug_farming/LICENSE-media.md:3-18`).

Most families, including corn, still share one geometry policy: one `plantlike` node whose `visual_scale` rises from 0.70 through 1.15, with a stage-dependent selection box (`mods/ITEMS/grug_nodes/crop_visual.lua:3-10,29-36`). Salt Crust alone gets an authored nodebox silhouette (`:11-28`). Sugar Cane and Bamboo also remain single plantlike nodes; their upright appearance comes from texture plus scale, not vertical multi-node growth (`docs/research/r10-visuals.md:64-67`). Wild mapgen plants reuse the mature stage-4 visual but have independent one-drop harvesting and no farming lifecycle (`mods/MAPGEN/grug_mapgen/world_nodes.lua:1-23`).

Consequently, current corn is a one-node crop at all four stages. The player recollection that its world plant should be much taller is a valid presentation critique, but it does not describe the present implementation.

## Reference verification: VoxeLibre, x_farming, and Lord of the Test

The submodules are clean at their pinned commits: VoxeLibre `c2dbc520...`, Lord of the Test `f1641401...`, `x_farming` `ac5f69d5...`.

### VoxeLibre does not contain corn

No `corn` or `maize` crop occurs in the pinned VoxeLibre source. Its relevant farming set is wheat, carrots, potatoes, beetroot, melon/pumpkin stems, sweet berries, cocoa, bamboo, etc. The existing repository research correctly catalogs those crop families and does not claim corn (`docs/research/plants-and-potions-reference.md:353-367`). For example, premature VoxeLibre wheat drops seed only and mature wheat drops wheat plus seeds (`reference_projects/VoxeLibre/mods/ITEMS/mcl_farming/wheat.lua:27-60,72-106`). This supports the general immature-versus-mature harvest principle, not three-high corn.

### x_farming is the current corn art source, but not three-node corn

The local media ledger says our corn growth textures come from pinned `x_farming` (`mods/ITEMS/grug_farming/LICENSE-media.md:8-18`). `x_farming` registers ten corn stages (`reference_projects/x_farming/corn.lua:21-33`) and makes stages 6-10 visually tall through `visual_scale = 2.0` while they remain one node (`:50-88`). This is a strong source for a tall silhouette and more differentiated maturation, but not for a three-block plant.

### Lord of the Test owns the actual three-node reference

Lord of the Test starts corn as one node with empty premature drops (`reference_projects/Lord-of-the-Test/mods/lottfarming/corn.lua:1-69`). Growth from its second base stage adds a second node (`:179-200`), and the next transition writes base, middle, and top nodes (`:202-225`). The mature upper arrangements yield corn and seeds probabilistically (`:92-113,125-146`). This matches the remembered multi-height behavior more closely, although its exact drop policy is not “immature always returns seeds”: its early nodes use `drop = ""`, so breaking them returns nothing. Our present policy is more forgiving and deterministic: every immature stage returns one seed.

TenPlus1's separately pinned `farming` mod also has corn, but its changelog explicitly says corn was changed to single nodes; current stages are one-node registrations, with `visual_scale = 1.9` at stage 6 (`reference_projects/farming/crops/corn.lua:24-99`, `reference_projects/farming/README.md:258`).

## Bounded recommendation for a next farming iteration

A presentation-focused crop pass makes sense, provided it preserves the current 17-family catalog, wet-soil timing, acquisition, and deterministic drops. The current mechanics are coherent; the weak point is that almost every species shares the same one-node shape and generic scale curve.

Recommended bounded package:

1. Create a per-family visual profile table consumed by `grug_nodes.crop_visual`: draw type, stage heights/selection boxes, scale, and optional stacked-node layout. Keep the existing four logical stages and 200-second timing.
2. Audit the 17 stage strips at enlarged size and in-world. Fix cases where the crop silhouette does not read as the harvested plant. Reuse the already licensed/pinned stage assets where possible; the current ledger already clears `x_farming` stages for most families, goblins mushrooms, and local papyrus-derived cane/bamboo.
3. Give only naturally tall/special families bespoke topology: corn first; then consider sugar cane and bamboo as vertical growers, pumpkin/frost melon as ground fruit or stem-like silhouettes, berries as bushes, cave cap as mushroom, and salt crust as the already-special nodebox. Ordinary roots/grain can remain one node.
4. For corn, choose between a visually tall one-node crop (lowest risk, based on `x_farming`'s scale pattern) and a true multi-node crop (better world readability, based conceptually on Lord of the Test). If using true multi-node growth, define atomic placement/removal, protection checks for every occupied node, blocked-headroom behavior, timer ownership, orphan cleanup for current-version persistence, and what happens when a middle/top segment is dug. Those are required correctness work, not extra agronomy.
5. Preserve the present harvest contract unless the user explicitly changes it: stages 1-3 return one seed; stage 4 returns one crop plus one seed. It already matches the stated player expectation more closely than Lord of the Test and prevents accidental loss from being punitive.
6. Add a focused visual acceptance sheet and a short in-engine walk-through checklist for all 17 crops at stages 1 and 4. Avoid adding fertilizer, seasons, light calculations, random yield, pests, crossbreeding, or new crop families in this pass.

For scope, I would implement tall one-node corn first if the next round is already carrying UI, interaction, recipe-book, and art work. A full multi-node crop framework is feasible, but it creates meaningful lifecycle/protection edge cases and deserves its own bounded farming package rather than being slipped into a general polish round.

## Suggested disposition for the user's questions

- **Creative / food report:** report as discoverability/presentation, not an All-tab omission. The catalog contains 47 edible items, including six complete Caster dishes and high-tier food.
- **Caster food:** already implemented. Improve discoverability with a food filter/tab or consistent searchable role text/icons; no new recovery mechanic is required to meet the stated need.
- **Crop behavior:** agree with a further visual iteration. The general principle “growing plant should read differently from harvested inventory item” is already partly delivered through 68 stage textures, but geometry remains generic.
- **Corn reference correction:** cite Lord of the Test for true three-node corn, `x_farming` for the current tall single-node art/silhouette pattern, and VoxeLibre for mature/immature crop lifecycle patterns. Do not attribute corn itself to VoxeLibre.
