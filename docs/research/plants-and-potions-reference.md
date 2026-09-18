# Plants and Potions Reference Survey

Researched 2026-09-18 for Round 7 lane R7-REF. This is evidence for the
Round 8 Cooking and Alchemy plan, not a design decision and not permission to
import an asset. The user still decides whether either candidate becomes a
reference submodule. No candidate code or media has been added to Grudgelands.

## 1. Scope, snapshots and reading key

The two candidates were shallow-cloned into `/tmp/r7-ref/<name>` on
2026-09-18. VoxeLibre and minetest_game were read from the initialized,
read-only main-checkout reference projects; the SHAs below are also the pins
recorded by this worktree.

| Key | Project and upstream | Inspected commit | Commit date |
|---|---|---|---|
| F | [TenPlus1/farming](https://codeberg.org/tenplus1/farming.git) | `1a918c7ae3778c3406ad91de6b83a174facad8f0` | 2026-09-07 |
| X | [minetest_gamers/x_farming](https://bitbucket.org/minetest_gamers/x_farming.git) | `ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84` | 2026-09-11 |
| V | VoxeLibre | `c2dbc520ff4e1637072d33b06c3a2404e0f08df7` | 2026-06-11 |
| M | minetest_game | `b5243f3e42410ae3ca85ead795149406fa654538` | 2026-06-28 |

Citations use `key:path:line`. Candidate citations resolve in the temporary
clones at the commits above; V and M citations resolve under
`reference_projects/VoxeLibre/` and `reference_projects/minetest_game/` after
submodule initialization. Counts are measured from those exact trees. Asset
inventories larger than 250 rows are summarized by directory, as requested.

The licence verdicts apply the project policy in
[`licensing.md`](licensing.md): no NC or ND; missing licence or per-file
attribution is a finding, not an inferred grant. “Compatible” below means
legally usable in the GPL-3.0 combined game while retaining the original
notice and, for CC BY/CC BY-SA, author, source, exact licence and modification
record in the destination mod's `LICENSE-media.md`.

## 2. Licence verification

### 2.1 `farming`

The repository's `license.txt` starts with the MIT grant:

> “Permission is hereby granted, free of charge, to any person obtaining a
> copy of this software and associated documentation files (the ‘Software’),
> to deal in the Software without restriction” (`F:license.txt:5-8`)

and requires:

> “The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.” (`F:license.txt:12-13`)

The media section is a per-file or glob attribution ledger beginning at
`F:license.txt:24`. It includes CC0, CC BY 3.0, CC BY-SA 3.0/4.0 and MIT rows,
all acceptable with their stated duties. It also says, verbatim:

> “Textures by SG7997 (CC-BY-NC-SA 3.0):” (`F:license.txt:228`)

and assigns that non-commercial licence to `farming_chapathi.png`,
`farming_gulab_jamun.png`, `farming_kitkat.png`, `farming_laddu.png` and
`farming_samosa.png` (`F:license.txt:229-233`). These five files fail the
project's no-NC rule.

There is a second unresolved block:

> “Copyright (C) 2021-2022: Atlante - AFL-1.1”
>
> “License for code: AFL-1.1” (`F:license.txt:246-247`)

followed by bare `farming_asparagus*`, `farming_eggplant*`,
`farming_spinach*`, and `farming_ginger*` patterns (`F:license.txt:259-262`).
It does not say whether the patterns identify Lua, textures, or both, and the
repository has no second licence file. AFL-1.1 is not cleared by the current
project matrix. This is an ambiguity, not a compatibility assumption.

| File class | Measured files | Licence evidence | Verdict |
|---|---:|---|---|
| Code | 54 Lua files | MIT generally; ambiguous AFL-1.1 block for four named crop families | **Not fully cleared.** Ordinary MIT code is compatible, but do not copy the four ambiguous families until the author/file mapping and AFL compatibility are resolved. |
| Textures | 485 PNG (`textures/` 464, `alt_textures/` 21) plus root `screenshot.jpg` | Per-file/glob mixed CC0, CC BY, CC BY-SA, MIT; five explicit CC-BY-NC-SA-3.0 files; screenshot has no row | **Mixed.** Most rows are compatible with attribution/SA, five named textures are prohibited, screenshot is uncleared. |
| Models | 0 | No files | Nothing to clear. |
| Sounds | 0 | No files | Nothing to clear. |

**Candidate-level result:** code **and** media are not fully verified under the
R7-REF acceptance rule. A future reference submodule could still be useful for
reading, but no asset sweep may treat the project as wholly cleared. Any import
would need a positive allow-list that excludes the five NC files, the
unattributed screenshot, and the ambiguous AFL crop families.

### 2.2 `x_farming`

The repository includes the complete LGPL 2.1 text and an explicit project
declaration:

> “GNU Lesser General Public License v2.1 or later (see included LICENSE
> file)” (`X:LICENSE.txt:457-459`)

Its README repeats:

> “Source Code: LGPL-2.1-or-later”
>
> “Media (Textures, Models, Sounds): CC-BY-SA-4.0”
> (`X:README.md:435-438`)

The detailed ledger assigns the main texture set to:

> “CC-BY-SA-4.0, by SaKeL” (`X:LICENSE.txt:461-465`)

and contains named exception rows for derived CC BY-SA 3.0 textures
(`X:LICENSE.txt:648-654`), 140 sounds under CC0 or CC BY 3.0/4.0 beginning
at `X:LICENSE.txt:1051`, and the runtime models under:

> “CC-BY-SA-4.0, by SaKeL” (`X:LICENSE.txt:1329-1333`)

No NC or ND string occurs in the licence ledger. A basename audit found all
578 in-game texture PNGs, all 140 OGGs, all 23 OBJ files and the single B3D in
the per-file ledger. Naming is not complete attribution, however: only 59 OGG
entries have a concrete original URL. The other 81 cite only the Freesound
homepage; 31 of those 81 are CC BY and therefore lack the exact source needed
by this project's attribution policy. Examples are the two CC-BY-3.0 entries
at `X:LICENSE.txt:1053-1059` and the CC0/CC-BY groups at
`X:LICENSE.txt:1090-1106`. All 81 are excluded from import until their original
URLs are recorded.

The five root screenshots, 19 Blender source files, two XCF source files and
12 runtime MTS schematics are not assigned any per-file row. The schematic
tree contains Christmas trees, cocoa jungle trees, kiwi and pine-nut trees,
large cacti, ice fishing and salt decoration. The only README schematic match
is an unrelated API example (`X:README.md:384`), while the licence inventory
ends with its model list (`X:LICENSE.txt:1329-1362`). The project-level media
declaration is evidence of a CC-BY-SA-4.0 grant, but the missing per-file
author/source mapping remains a project-policy finding; those 38 files should
not be harvested until it is supplied.

| File class | Measured files | Licence evidence | Verdict |
|---|---:|---|---|
| Code | 51 Lua files | LGPL-2.1-or-later | **Compatible.** Preserve copyright and LGPL notice; copied/derived code can be conveyed under GPLv3 under the policy matrix. |
| Textures | 578 content PNG + 5 root screenshot PNG + 2 XCF sources | All 578 content PNGs named; compatible CC BY-SA 4.0/3.0 rows. Screenshots and XCF sources lack per-file rows. | **Runtime textures compatible; source/screenshot gap.** Attribute every selected row and do not import the seven unlisted files without clarification. |
| Models | 23 OBJ + 1 animated B3D + 19 Blender sources | Every runtime OBJ/B3D named CC-BY-SA-4.0 by SaKeL; Blender sources absent from per-file table | **Runtime models compatible; Blender files need clarification.** The B3D contains `ANIM`, `BONE` and `KEYS` chunks. |
| Sounds | 140 OGG | All have an author/licence grouping, but only 59 have a concrete original URL; 81 cite only `https://freesound.org`, including 31 CC BY files | **59 source-resolved sounds are clear. The other 81 are excluded from import** until exact original URLs are recorded; the CC BY subset cannot satisfy attribution without them. |
| Schematics | 12 MTS | No per-file licence/author/source row in `LICENSE.txt` or `README.md` | **Not per-file-cleared; exclude all 12 from import** until attribution is supplied. |

**Candidate-level result:** there is no NC/ND blocker, and the code, 578 content
textures, 23 OBJ models, one animated B3D and 59 source-resolved sounds are
cleared. The 38 files absent from the per-file ledger (five screenshots, 19
Blender sources, two XCF sources and 12 MTS schematics) and the 81 sounds with
homepage-only source citations are not cleared for import. Under a strict
whole-repository “code AND media verified” criterion, `x_farming` therefore is
not fully verified. It remains the stronger *read-only reference-submodule*
candidate for mechanics and positively allow-listed assets; that recommendation
does not convert the excluded classes into importable media.

### 2.3 VoxeLibre selected plant and potion modules

VoxeLibre states:

> “you can redistribute it and/or modify it under the terms of the GNU
> General Public License … either version 3 … or (at your option) any later
> version.” (`V:LEGAL.md:14-17`)

For media it states both:

> “No non-free licenses are used anywhere.” (`V:LEGAL.md:38-40`)

and the default/fallback rules: Pixel Perfection by XSSheep, CC BY-SA 4.0
(`V:LEGAL.md:42-48`), otherwise CC BY-SA 3.0 (`V:LEGAL.md:66-68`). Selected
mod-local notices remain authoritative exceptions. In particular,
`mcl_bamboo` says “License for code: GPLv3” and “License for images / textures:
CC-BY-SA except where noted” (`V:mods/ITEMS/mcl_bamboo/README.md:8-12`). That
local CC-BY-SA row omits a version, so a bamboo asset import needs an exact
version check even though it contains no NC/ND restriction. Other useful
local exceptions are `mcl_potions` (“Code: MIT License”, “Sounds: CC0” at
`V:mods/ITEMS/mcl_potions/README.txt:1-5`) and `mcl_farming`'s CC-BY-SA-4
notice for source and graphics (`V:mods/ITEMS/mcl_farming/README.txt:23-25`).
The latter may instead use VoxeLibre's explicit GPLv3 dual-licence choice
(`V:LEGAL.md:25-28`).

| File class | Selected-module inventory | Verdict |
|---|---:|---|
| Code | `mcl_farming`, `mcl_potions`, `mcl_brewing`, `mcl_flowers`, `mcl_mushrooms`, `mcl_cocoas`, `mcl_bamboo` | **Compatible:** GPL-3.0-or-later/game licence or compatible mod-local licence. Preserve mod-local notices. |
| Textures | 167 central PNGs with those prefixes, including `mcl_core_sugar.png` | **Compatible with per-file provenance work:** chiefly CC BY-SA 4.0/3.0 defaults. Bamboo's unspecified CC-BY-SA version is a finding to resolve before import. |
| Models | 3 flower OBJ + 3 cocoa OBJ | **Compatible under the documented media defaults**, with exact author/source row required on import. These are static meshes, not animation candidates. |
| Sounds | 4 potion OGG + 1 brewing OGG | **Compatible:** potion sounds are explicitly CC0; the brewing sound follows the documented media default. Record the exact source row on import. |

### 2.4 minetest_game `farming`, `flowers`, and relevant `default`

The farming licence says “The MIT License (MIT)” and identifies its
copyright holders (`M:mods/farming/license.txt:1-7`); its textures are CC BY
3.0 and CC BY-SA 3.0 (`M:mods/farming/license.txt:29-36`, `:65-67`). Flowers
uses MIT code (`M:mods/flowers/license.txt:1-6`) and CC BY-SA 3.0 textures
(`M:mods/flowers/license.txt:28-35`). Relevant `default` code is expressly
“either version 2.1 … or (at your option) any later version”
(`M:mods/default/license.txt:4-10`), while its media ledger uses CC BY-SA 3.0,
CC BY 3.0 and CC0 (`M:mods/default/license.txt:18-22`, `:87-95`, `:124-138`).

| File class | Relevant inventory | Verdict |
|---|---:|---|
| Code | farming + flowers MIT; default LGPL-2.1-or-later | **Compatible.** Preserve notices. |
| Textures | farming 37 PNG; flowers 12 PNG; relevant default plant textures within its ledger | **Compatible** under CC BY/CC BY-SA/CC0 with exact attribution and SA retained. |
| Models | No crop/flower model required; relevant default tree OBJ files are outside the narrow crop/flower set | **Compatible if selected and individually attributed; otherwise not part of this survey's harvest.** |
| Sounds | No farming/flowers sounds; default environmental sounds are outside the narrow set | Nothing needed for the crop/flower comparison. |

## 3. `farming` content and mechanics

### Crops

The API discovers numbered stages, runs node timers, requires wet soil by
default, applies configurable light limits, and can advance multiple elapsed
stages using a Poisson draw (`F:init.lua:163-231`, `:324-406`). Water within
three nodes turns fields wet; dry empty fields eventually revert
(`F:soil.lua:143-190`).

| Seed → stages → harvest | Growth and soil rules | Licence class |
|---|---|---|
| Explicit seeds: wheat, cotton, barley, hemp, mint, rice, sunflower → numbered plants → crop/fibre/seed drops | Generally wet tilled soil (`soil=3`), configured light range; wheat/cotton use the common registration API | MIT code; mixed compatible CC textures, per `F:license.txt`; check the selected filenames |
| Self-planting 8-stage crops: carrot, chili, corn, grapes, melon, pineapple, pumpkin, strawberry, tomato, vanilla | Harvest item is also planting item; melon/pumpkin have fruit-specific behaviour; most also register wild decoration | MIT code; mixed compatible texture rows |
| 7-stage pepper and soy; 6-stage cabbage | Same timer/light/wet-soil core | MIT code; mixed compatible texture rows |
| 5-stage artichoke, beans, beetroot, coffee, garlic, lettuce, onion, peas, rye and oat | Beans additionally require a bean pole (`F:crops/beans.lua:74-130`) | MIT code except the general asset caveats |
| 4-stage blackberry, blueberry, cocoa, cucumber, potato, raspberry, rhubarb; 3-stage parsley | Cocoa is a separate pod/tree-side pattern; berries and vegetables double as food | MIT code; mixed compatible texture rows |
| 4/5-stage eggplant, ginger, spinach, asparagus families | Same mechanics, but the licence file's AFL-1.1 block does not map code versus textures clearly | **Uncleared AFL-1.1 ambiguity** |
| Kiwi sapling/tree → kiwi fruit | Schematic/tree growth rather than numbered crop stages | MIT code; kiwi textures CC BY-SA 3.0/4.0 rows (`F:license.txt:31-38`) |

### Wild plants

| Plants | Placement mechanics | Licence class |
|---|---|---|
| About 31 crop files also register simple decorations, including most vegetables, berries, coffee, cotton, melon/pumpkin, pineapple and sunflower | Per-crop `place_on`, noise/fill, height and optional biome lists; examples are artichoke at y=1..13 (`F:crops/artichoke.lua:90-105`) and beans at y=18..38 (`F:crops/beans.lua:237-249`) | MIT code; selected textures retain their individual CC/MIT class |
| Wheat/oats from grass; crop seeds as rare grass drops | Overrides grass drops rather than placing mature crop patches (`F:grass.lua:9-73`) | MIT code; compatible attributed textures |
| Cocoa, rice, barley, rye/oat | No generic simple-decoration row in their crop file; their acquisition/growing path differs or depends on integrations | MIT code; mixed compatible textures |

The biome names and soil nodes are tightly coupled to minetest_game,
Mineclonia and optional `ebiomes`; the useful idea is the registration shape,
not copying its placement table into the custom Grudgelands mapgen.

### Cooked foods and dishes

The repository supplies a broad recipe catalog rather than a station or buff
system. Effects are immediate `item_eat` HP/hunger values, which conflicts
with Round 7's food model.

| Inputs → output | Existing effect/model | Licence class |
|---|---|---|
| Flour → bread; rice flour → rice bread; multigrain flour → multigrain bread; bread slice → toast | Furnace cooking, fixed `item_eat` values (`F:item_recipes.lua:67-90`, `:1110-1117`, `:1497-1504`) | MIT code; individually attributed textures |
| Potato → baked potato; corn → corn cob; tofu → cooked tofu; sunflower seed → toasted seed | Furnace cooking (`F:item_recipes.lua:243-250`, `:1158-1165`, `:1550-1565`) | MIT code; individually attributed textures |
| Tomato + bowl → tomato soup; peas + bowl → pea soup; onions + bowl + pot → onion soup | Shaped crafting, instant eat (`F:item_recipes.lua:393-401`, `:935-955`) | MIT code; individually attributed textures |
| Pasta + cheese + bowl → mac and cheese; pasta + tomato + garlic + saucepan → spaghetti | Shaped crafting (`F:item_recipes.lua:687-704`) | MIT code; individually attributed textures |
| Bread + meat + cheese + tomato + cucumber + onion + lettuce → burger; vegetables + oil + bowl → salad | Shaped/shapeless crafting (`F:item_recipes.lua:730-750`) | MIT code; burger texture CC0; salad CC BY-SA 4.0 (`F:license.txt:59-60`, `:192-196`) |
| Rice + peas + chicken + pepper + bowl → paella; cabbage + garlic + onion + meat + flour + salt → gyoza | Multi-ingredient dishes (`F:item_recipes.lua:787-795`, `:881-889`) | MIT code; texture row must be checked; gyoza is CC0 (`F:license.txt:217-219`) |
| Chapathi, gulab jamun, KitKat, laddu, samosa | Immediate food items | **Textures prohibited: CC-BY-NC-SA-3.0** (`F:license.txt:228-233`) |

### Potion and brewing mechanics

| Station / ingredients / effects | Durations and stacking | Licence class |
|---|---|---|
| No potion or brewing system. `hoe_bomb` uses a thrown-object helper but tills soil; it is not an alchemy model (`F:hoes.lua:264-297`). | None | MIT code |

### Animated and textured assets

| Asset group | Measured contents | Licence class |
|---|---:|---|
| `textures/` | 464 PNG: crop stages, harvest items, dishes, soils and tools | Mixed CC0, CC BY 3.0, CC BY-SA 3.0/4.0, MIT, five prohibited NC files, and ambiguous AFL family patterns |
| `alt_textures/` | 21 PNG variants | Mixed; use only a positively matched ledger row |
| Root screenshot | 1 JPG | **No per-file attribution found; do not import** |
| Models / sounds | none | N/A |

**Harvest verdict:** harvest the *catalog ideas* (wide crop selection, grouped
ingredient recipe syntax, elapsed-time crop timer, wet/dry soil loop) after an
independent implementation. Do not wholesale-harvest assets or code. VoxeLibre
already covers the essential wheat/carrot/potato/beetroot/melon/pumpkin/cocoa
growth loops and a stronger effect engine; `farming` adds breadth—grains,
vegetables, berries and dishes—not potion mechanics. The NC textures and AFL
ambiguity make it the weaker submodule candidate unless the user wants it as a
read-only breadth reference with a strict deny-list.

## 4. `x_farming` content and mechanics

### Crops

Seeds germinate on soil, later stages require wet soil and a configured light
range, and the generic API registers stage timers (`X:api.lua:896-972`,
`:1220-1441`). Bonemeal, watering and sickles provide explicit acceleration
and harvest/replant seams (`X:README.md:194-230`).

| Seed → stages → harvest | Growth and soil rules | Licence class |
|---|---|---|
| carrot, potato, beetroot, melon, pumpkin, barley, rice, stevia, cotton → 8 stages → crop plus seed; melon/pumpkin stem grows adjacent fruit | Wet soil; sunlight/light range; fruit stems remain and regrow | LGPL-2.1-or-later code; runtime textures compatible CC BY-SA 4.0/3.0 |
| corn seed → 10 stages → corn cob | Wet soil; can roast/pop/mill after harvest | Same |
| coffee seed → 5 stages → coffee beans | Wet soil; savanna placement | Same |
| soybean seed → 7 stages → soybeans | Wet soil | Same |
| strawberry seed → 4 stages → berries | Wet soil; forest/taiga placement | Same |
| cocoa bean → 3 side-mounted stages → cocoa beans | Jungle trunks, not farmland (`X:README.md:95-108`) | Same |
| obsidian wart → 6 stages → wart | Wet obsidian soil; designed for darkness | Same |

### Wild plants

| Plants | Placement mechanics | Licence class |
|---|---|---|
| Carrot, melon, soybean | Grassland biome decorations | LGPL code; compatible attributed textures |
| Kiwi, coffee, stevia, barley/cotton | Savanna decorations | Same |
| Strawberry and pine-nut tree | Coniferous/taiga and compatible forest decorations | Same |
| Dragon-fruit cactus, corn, pumpkin | Desert/sandstone-desert decorations | Same |
| Cocoa/jungle tree and salt pans | Rainforest/jungle trunk; rainforest-swamp or savanna-shore salt | Same |
| Potato/beetroot; obsidian wart | Cold desert/tundra; deep below -1000 respectively | Same |

The project's own summary enumerates these biome bindings at
`X:README.md:325-336`. This is a useful candidate catalog but cannot be copied
unchanged because Grudgelands uses logical biome/zone projection rather than
those engine biome names.

### Cooked foods and dishes

| Inputs → output | Existing effect/model | Licence class |
|---|---|---|
| Raw food on lit rustic stove → normal engine cooking output, up to six visible items | Node timer reads `cooking` recipes and drops finished items (`X:stove.lua:396-471`, `:597-673`, `:715-794`) | LGPL code; textures are ledger-cleared, but use a stove sound only if it is among the 59 entries with a concrete source URL |
| Fish/kelp/fruit on solar rack → dried fish/nori/fruit | Six visible items, advances only in direct sunlight (`X:drying_rack.lua:25-52`, `:413-541`) | LGPL code; only positively cleared runtime textures/models may be imported; the MTS and incomplete-source sound findings remain excluded |
| Fish + baked potato + salt + carrot → fish stew; potato/fish/melon → three bowls | Immediate hunger/heal, bowl returned | LGPL code; models/textures CC-BY-SA-4.0 |
| Corn + heat/flour → roasted cob, popcorn, cornbread, tortilla | Immediate hunger/heal | Same |
| Rice + fish/seaweed → sushi maki/nigiri; soybean → raw soymilk → cooked soymilk | Immediate hunger/heal and vessel return | Same |
| Strawberry/melon/kiwi/cocoa/honey → fruit bowl, jam, covered strawberry, pies, chocolate donut | Immediate hunger/heal | Same |
| Raw/cooked fish species | Some cooked fish grant speed, jump, water breathing, night vision, feather fall or regeneration for roughly 15–60 s (`X:ice_fishing.lua:486-730`) | LGPL code; fish media ledger rows must be selected individually |

The full food table is already compactly documented at `X:README.md:277-321`;
repeating every fish and dish here would exceed the useful scope. Its direct
HP/hunger values are reference data only, not Round 8 balance.

### Potion and brewing mechanics

| Station / ingredients / effects | Durations and stacking | Licence class |
|---|---|---|
| No general potion station or recipe graph. Coffee and edible fish attach utility effects; bandages heal; honey cures poison. | Custom fish effects replace an active effect of the same key before applying a new timer (`X:fish_effects.lua:198-237`); integrations delegate to `mcl_potions` where present (`:180-197`, `:239-382`). | LGPL-2.1-or-later code |

This is not an Alchemy template. Its useful seam is capability-based status
integration; its food-granted combat buffs conflict with the Round 7 split
unless re-authored into Grudgelands food/elixir categories.

### Animated and textured assets

| Asset group | Measured contents | Licence class |
|---|---:|---|
| Runtime textures | 578 content PNG, including seven named animated textures (stove top/front, ice-fishing top variants, Christmas leaves, candle flame, bee wings) | All 578 named in compatible CC BY-SA 4.0/3.0 rows; five additional root screenshots lack per-file rows |
| Runtime models | 23 OBJ and one `x_farming_snowman.b3d` | Named CC-BY-SA-4.0 by SaKeL; B3D contains animation/bone/key chunks |
| Model/image sources | 19 `.blend`, 2 `.xcf` | Project-level media declaration exists, but no per-file attribution rows: **do not import until clarified** |
| Schematics | 12 `.mts` for trees, cactus, cocoa, ice fishing and salt decoration | No per-file licence/author/source row: **do not import until clarified** |
| Sounds | 140 OGG for bees, tools, appliances, materials and ambience | 59 have a concrete original URL and are clear with their CC0/CC BY duties; 81 have only a Freesound-homepage citation and are **excluded from import** |

**Harvest verdict:** recommend `x_farming` as the one new reference submodule
if the user wants one. Harvest mechanics concepts for a six-slot visible stove,
sun-dependent drying, irrigation feedback, harvest-and-replant sickles and
biome-bound crop acquisition; selectively harvest only runtime media with an
exact ledger row. VoxeLibre already covers core crops, cocoa, bonemeal and the
full potion effect/brewing engine, so `x_farming` adds no fundamental potion
architecture. It does add cooking-station presentation, crop breadth, 59
source-resolved sounds and food models. The 38 unlisted files and 81
homepage-only sounds remain excluded. Do not use its compatibility
migrations/aliases: the project is in fresh-server mode.

## 5. VoxeLibre content and mechanics

### Crops

| Seed → stages → harvest | Growth and soil rules | Licence class |
|---|---|---|
| wheat seed → 8 stages → wheat + seeds | Farmland, sunlight, faster on hydrated soil (`V:mods/ITEMS/mcl_farming/wheat.lua:9-67`) | GPL-3.0-or-later code; CC BY-SA media defaults |
| carrot/potato item → 8 logical stages → crop; beetroot seed → 4 stages → beetroot + seeds | Farmland, sunlight, hydrated speed bonus (`V:mods/ITEMS/mcl_farming/carrots.lua:20-100`, `potatoes.lua:22-105`, `beetroot.lua:7-61`) | Same |
| melon/pumpkin seed → 8-stage stem → adjacent fruit | Mature stem persists; light and hydrated farmland (`V:mods/ITEMS/mcl_farming/melon.lua:8-116`, `pumpkin.lua:15-86`) | Same |
| sweet berries → 4 bush stages → berries | Dirt/podzol/moss/farmland set (`V:mods/ITEMS/mcl_farming/sweet_berry.lua:3-40`) | Same |
| cocoa bean → 3 side-mounted pod stages → beans | Jungle-tree side; ABM and bonemeal growth (`V:mods/ITEMS/mcl_cocoas/init.lua:53-164`) | GPL code; CC BY-SA media defaults |
| bamboo shoot → vertical stalk | Top-only natural growth, light gate, one or two segments with bonemeal (`V:mods/ITEMS/mcl_bamboo/globals.lua:99-155`) | GPLv3 code; media CC-BY-SA version needs exact confirmation |

Farmland hydration is already a clean reference for water/rain, wet/dry
transitions and decay (`V:mods/ITEMS/mcl_farming/soil.lua:3-89`).

### Wild plants

| Plants | Placement mechanics | Licence class |
|---|---|---|
| Small/tall flowers and clover | Soil/light placement checks; biome-sensitive bonemeal tables (`V:mods/ITEMS/mcl_flowers/init.lua:26-35`, `bonemealing.lua:46-88`) | GPL code; CC BY-SA media defaults |
| Red/brown mushrooms | Spread in darkness with density cap; podzol/mycelium exceptions; uproot in light (`V:mods/ITEMS/mcl_mushrooms/small.lua:13-19`, `:56-60`, `:148-207`) | GPL code; CC BY-SA media defaults |
| Cocoa and bamboo | Growth mechanics are local; world placement belongs to the wider VoxeLibre biome/mapgen stack | GPL code; compatible media with bamboo version caveat |

### Cooked foods and dishes

| Inputs → output | Existing effect/model | Licence class |
|---|---|---|
| Wheat → bread; potato → baked potato; beetroot + bowl → soup; pumpkin + sugar/egg → pie; cocoa + wheat → cookies | Three wheat craft directly into bread; there is no flour stage (`V:mods/ITEMS/mcl_farming/wheat.lua:118-123`). Minecraft-like crafting/furnace recipes and hunger/saturation effects; no Cooking profession or tier book | GPL code; CC BY-SA media defaults |
| Red + brown mushroom + bowl → mushroom stew; suspicious stew variants elsewhere | Immediate food/status model | GPL code; CC BY-SA media defaults |

VoxeLibre is useful for crop and food registration patterns, but its food
numbers and hunger model are not compatible with R7.1–R7.4.

### Potion and brewing mechanics

| Station / ingredients / effects | Durations and stacking | Licence class |
|---|---|---|
| Brewing stand: one ingredient, fuel, up to three bottles; flaming powder fuel | Node timer transforms valid ingredient+bottle pairs and consumes material/fuel (`V:mods/ITEMS/mcl_brewing/init.lua:76-195`, `:262-265`) | GPL-3.0-or-later code; CC BY-SA media defaults |
| Base liquids plus ingredients → healing/harming, speed/slowness, leap, poison, regeneration, invisibility, water breathing, fire resistance, strength/weakness, slow fall and more | Instant and timed effects with potency/extended variants; splash, lingering and tipped-arrow forms (`V:mods/ITEMS/mcl_potions/potions.lua:399-798`) | MIT or global GPLv3 code; CC BY-SA textures and CC0 sounds |
| Redstone-like ingredient extends duration; glowstone dust increases potency; fermented spider eye inverts; gunpowder/dragon breath change delivery | Potency and extension are mutually replaced in metadata (`V:mods/ITEMS/mcl_potions/init.lua:520-624`) | GPL code |
| Registered status-effect engine | Same effect type refreshes to the greater remaining/new duration if the new factor is at least as strong; weaker factor is refused (`V:mods/ITEMS/mcl_potions/functions.lua:1805-1856`). Different registered effects coexist. | GPL code |

This is the most complete potion reference already available. Round 8 should
reuse concepts—registry, effect lifecycle, ingredient transform graph and
station timer—not its Minecraft recipe graph or balance.

### Animated and textured assets

| Asset group | Measured contents | Licence class |
|---|---:|---|
| Central textures for selected prefixes | 167 PNG: 38 farming, 49 potions, 12 brewing, 35 flowers, 4 mushrooms, 3 cocoa, 25 bamboo, 1 sugar | Pixel Perfection/default CC BY-SA 4.0/3.0 plus exceptions; bamboo version ambiguity must be resolved per selected file |
| Models | 3 flower OBJ + 3 cocoa-stage OBJ | Static; compatible CC BY-SA defaults with exact provenance row |
| Sounds | 4 potion + 1 brewing OGG | Compatible CC BY-SA defaults with exact provenance row |

**Harvest verdict:** harvest mechanics selectively: hydrated crop timing,
stem-adjacent fruit, cocoa/bamboo growth, mushroom ecology, potion effect
registry, transform graph and three-bottle station lifecycle. This is already
the authoritative breadth reference for potions; neither candidate adds a
better general brewing model. Assets may be considered individually, but
VoxeLibre's Minecraft visual language is less suitable than original
Grudgelands art, and every import still needs a destination attribution row.

## 6. minetest_game content and mechanics

### Crops

| Seed → stages → harvest | Growth and soil rules | Licence class |
|---|---|---|
| wheat seed → 8 stages → wheat + seeds | Common `register_plant`; node timers call `grow_plant` (`M:mods/farming/api.lua:198-260`, `:332-385`) | MIT code; CC BY 3.0 textures |
| cotton seed → 8 stages → cotton + seeds | Same | MIT code; CC BY 3.0/CC BY-SA 3.0 textures |
| Hoe dirt/dry dirt/desert sand → dry field → wet field | Water within three nodes hydrates; unloaded-neighbour guard prevents false drying (`M:mods/farming/nodes.lua:180-223`) | MIT code; CC BY/CC BY-SA textures |

### Wild plants

| Plants | Placement mechanics | Licence class |
|---|---|---|
| Wild cotton | Farming decoration/seed source | MIT code; attributed CC texture |
| Rose, tulip, dandelions, geranium, viola, chrysanthemum | Simple decorations on grass with noise/height rules | MIT code; CC BY-SA 3.0 textures |
| Brown/red mushrooms | Biome decorations on grass/litter; separate placement bands | MIT code; CC BY-SA 3.0 textures |
| Waterlily | Water-level decoration in swamp/shore biomes (`M:mods/flowers/mapgen.lua:132-147`) | MIT code; CC BY-SA 3.0 textures |
| Apple, blueberry bush, papyrus, cactus and kelp from `default` | Schematics/simple decorations in the base mapgen rather than a crop API | LGPL-2.1-or-later code; mixed compatible default media ledger |

### Cooked foods and dishes

| Inputs → output | Existing effect/model | Licence class |
|---|---|---|
| Wheat → flour → bread | Craft/furnace chain, immediate eat | MIT code; CC BY 3.0 textures |
| Apple/blueberry/mushroom base items | Raw immediate food; no dish or role-food ladder | LGPL/MIT code; compatible attributed textures |

### Potion and brewing mechanics

| Station / ingredients / effects | Durations and stacking | Licence class |
|---|---|---|
| None in farming/flowers/default | None | N/A |

### Animated and textured assets

| Asset group | Measured contents | Licence class |
|---|---:|---|
| farming textures | 37 PNG (two 8-stage crops, seed/harvest, soil and hoes) | CC BY 3.0 / CC BY-SA 3.0 |
| flowers textures | 12 PNG | CC BY-SA 3.0 |
| relevant default plant assets | 94 filenames matching tree/bush/apple/berry/cactus/papyrus/grass/fern/mushroom/kelp/coral, including schematics | Mixed CC BY-SA 3.0, CC BY 3.0, CC0 under the per-file ledger; select individually |
| farming/flowers models and sounds | none | N/A |

**Harvest verdict:** harvest almost nothing new. The small crop API and
hydration loop are useful as a simplicity baseline, and its restrained flower
placement is a good mapgen reference. Grudgelands and VoxeLibre already cover
the mechanics; the assets are familiar low-resolution baseline art rather than
a distinctive Round 8 set. minetest_game has no potion contribution.

## 7. What this means for Round 8

### Required mapgen and world inputs

Round 8 needs explicit inputs from the map projection, not candidate biome-name
lookups:

- **Farm soil contract.** Define which current top nodes a hoe can convert to
  dry claim farmland, the wet counterpart, hydration radius/source rules and
  whether rain matters. `world.md:749-760` already permits only `[food]` crops
  and `[spice Tn]` plants in claims; healing herbs and found-only foods must
  fail closed. Candidate aliases and migration LBMs are out of scope in
  fresh-server mode.
- **Crop set.** Current farmable inputs are potato, corn, berries, melon and
  the three spice tiers; apples are tree produce. Mushrooms, wild cocoa and
  rock salt remain found-only (`biomes_mobs.md:788-856`). Round 8 must not turn
  a broad candidate crop catalog on wholesale without first assigning each
  addition to a cooking tier, zone/band and claim permission.
- **Shore material.** Reeds/papyrus, sugar cane and any future bamboo need a
  deterministic dry-bank predicate adjacent to water and an allowed substrate.
  Current beaches and ocean use `default:sand` while swamps use mud/dirt and
  the stormkelp predicate deliberately crosses logical biomes
  (`biomes_mobs.md:713-715`, `:829-834`). “Place on sand in biome X” is not
  enough for the current logical-biome projection.
- **Wild placement manifest.** Preserve the decided separation: foods and
  spices are universal gathering; healing herbs are Alchemist-only and never
  farmable. The existing exact opportunities already cover potato, corn,
  berries, mushrooms, melon, the six herb/spice plants, wild cocoa and rock
  salt (`biomes_mobs.md:772-813`). Any flower, reed, bamboo or new crop becomes
  a named manifest row with logical-biome/zone eligibility, density and
  substrate—not an independent ABM decoration guess.
- **Station inputs.** Cooking needs heat/fuel or the decided workstation path;
  Alchemy needs vial supply, recipe-book tier and station inventory contract.
  `x_farming`'s stove/drying rack are presentation references; VoxeLibre's
  fuel + ingredient + bottle stand is the stronger lifecycle reference.

### Conflicts and required design updates

The R7 rulings intentionally supersede several still-written rules. Round 8
must update the decided documents before or with implementation:

| Current text | Conflict with R7.1–R7.4 | Required Round 8 handling |
|---|---|---|
| `items_crafting.md:1064-1067`, `:1188-1214` says food never heals instantly, ticks every 10 s and uses raw/simply/well-cooked percentages | R7.1 requires fixed instant HP by tier, 180 s buffs ticking every 5 s, raw food at 1% HP/5 s; R7.2 adds role bonuses | Replace the old R9 food model and its current-item mapping with the approved six-tier table. Candidate `item_eat` values are not an oracle. |
| `items_crafting.md:1073-1078` says 30% instant potions and flat +2/+4/+6 attribute elixirs | R7.3 proposes 15% HP/mana potions, short utility potions and stronger tiered percentage/stat elixirs | The Cooking/Alchemy plan must return exact numbers for user ruling, then update the table. VoxeLibre supplies lifecycle ideas only. |
| `items_crafting.md:1057-1061`, `:2501-2505` allows one elixir and one food buff to coexist and shares a 60 s instant-potion clock | This agrees with R7.3 except food may now modify the same property and stack additively with the elixir | Keep category coexistence; explicitly state same-property stacking and replacement within each category. |
| `professions.md:17-24`, `:34-38`, `:56` makes Cooking universal and Alchemist the exclusive healing-herb gatherer | Consistent with R7.8 and the current plant split | No structural conflict. Add minimum consumable level enforcement from R7.4 to the item/recipe presentation contract. |
| `biomes_mobs.md:667-715`, `:788-856` fixes farmable, found-only, herb and spice identities | Candidate catalogs contain many unassigned crops and turn cocoa/mushrooms into growable items | Current design wins. New crops require explicit decisions; wild cocoa, mushrooms and rock salt stay non-farmable. |
| `world.md:749-760` confines claim farming to foods/spices | Compatible with the crop proposal | Preserve this protection rule and add only approved plant IDs/groups. |

## 8. Recommendation to the user

- **Add `x_farming` as a reference submodule** if Round 8 wants a durable
  read-only source for cooking presentation, crop breadth and selectively
  reusable media. Its code, 578 content textures, 23 OBJ models, one animated
  B3D and 59 source-resolved sounds are cleared. Its 38 unlisted files (19
  Blender sources, two XCFs, five screenshots and 12 MTS schematics) plus 81
  homepage-only sounds are not cleared for import. Thus it does **not** satisfy
  a whole-repository “code AND media verified” import criterion; the qualified
  submodule recommendation is for reading and a positive asset allow-list.
- **Do not add `farming` yet** under the lane's “code AND media verified”
  criterion. It contains five explicit NC textures, an unattributed screenshot
  and an ambiguous AFL-1.1 block. Its useful crop/recipe concepts are captured
  in this note and largely overlap VoxeLibre/minetest_game mechanics.
- **Use VoxeLibre for potion architecture.** Neither candidate adds a general
  brewing system. Implement Grudgelands' tier, cooldown, combat and stacking
  rules independently around the existing `grug_core.status` seam.
